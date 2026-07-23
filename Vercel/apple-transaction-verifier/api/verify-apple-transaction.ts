import {
  AppStoreServerAPIClient,
  Environment,
  SignedDataVerifier,
  VerificationException,
} from "@apple/app-store-server-library";
import { Buffer } from "node:buffer";
import { createHmac, timingSafeEqual } from "node:crypto";
import type { IncomingHttpHeaders } from "node:http";

const bundleID = "com.wehack.PrintableCheckList";
const productID = "com.wehack.PrintableCheckList.pro";

type AppStoreEnvironmentName = "Sandbox" | "Production";

type VercelRequest = {
  method?: string;
  body?: unknown;
  headers: IncomingHttpHeaders;
};

type VercelResponse = {
  setHeader(name: string, value: string): void;
  status(code: number): VercelResponse;
  json(value: unknown): void;
};

type RuntimeConfiguration = {
  environmentName: AppStoreEnvironmentName;
  environment: Environment;
  appAppleID?: number;
  appleRootCAs: Buffer[];
  enableOnlineChecks: boolean;
  sharedSecret: string;
  serverAPIKey: string;
  serverAPIKeyID: string;
  serverAPIIssuerID: string;
};

class PublicError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
  ) {
    super(code);
  }
}

export default async function handler(
  request: VercelRequest,
  response: VercelResponse,
): Promise<void> {
  response.setHeader("Cache-Control", "no-store");

  if (request.method !== "POST") {
    response.status(405).json({ code: "method_not_allowed" });
    return;
  }

  try {
    const transactionJWS = transactionJWSFromBody(request.body);
    const configuration = loadRuntimeConfiguration();
    verifyCallerSignature(
      headerValue(request.headers["x-managed-ai-verifier-signature"]),
      transactionJWS,
      configuration.sharedSecret,
    );

    const verifier = new SignedDataVerifier(
      configuration.appleRootCAs,
      configuration.enableOnlineChecks,
      configuration.environment,
      bundleID,
      configuration.appAppleID,
    );

    let submittedTransaction: {
      transactionId?: string;
      originalTransactionId?: string;
      productId?: string;
      revocationDate?: number;
    };
    try {
      submittedTransaction = await verifier.verifyAndDecodeTransaction(
        transactionJWS,
      );
    } catch (error) {
      if (error instanceof VerificationException) {
        throw new PublicError(403, "entitlement_invalid");
      }
      throw new PublicError(503, "entitlement_verification_unavailable");
    }

    assertEligibleTransaction(submittedTransaction);
    const transactionID = requiredTransactionID(
      submittedTransaction.transactionId,
    );
    const originalTransactionID = requiredTransactionID(
      submittedTransaction.originalTransactionId,
    );

    const apiClient = new AppStoreServerAPIClient(
      configuration.serverAPIKey,
      configuration.serverAPIKeyID,
      configuration.serverAPIIssuerID,
      bundleID,
      configuration.environment,
    );
    let currentTransaction: typeof submittedTransaction;
    try {
      const currentInfo = await apiClient.getTransactionInfo(transactionID);
      if (!currentInfo.signedTransactionInfo) {
        throw new Error("Apple omitted signedTransactionInfo");
      }
      currentTransaction = await verifier.verifyAndDecodeTransaction(
        currentInfo.signedTransactionInfo,
      );
    } catch (error) {
      if (error instanceof VerificationException) {
        throw new PublicError(403, "entitlement_invalid");
      }
      throw new PublicError(503, "entitlement_lookup_unavailable");
    }

    assertEligibleTransaction(currentTransaction);
    if (
      currentTransaction.transactionId !== transactionID ||
      currentTransaction.originalTransactionId !== originalTransactionID
    ) {
      throw new PublicError(403, "entitlement_ineligible");
    }

    response.status(200).json({
      original_transaction_id: originalTransactionID,
      environment: configuration.environmentName,
    });
  } catch (error) {
    if (!(error instanceof PublicError)) {
      console.error("apple-transaction-verifier failed", {
        category: error instanceof Error ? error.name : "unknown",
      });
    }
    const publicError = error instanceof PublicError
      ? error
      : new PublicError(503, "verifier_unavailable");
    response.status(publicError.status).json({ code: publicError.code });
  }
}

function loadRuntimeConfiguration(): RuntimeConfiguration {
  const environmentName = requiredEnvironment(
    "APPLE_ENVIRONMENT",
  ) as AppStoreEnvironmentName;
  const environment = environmentName === "Sandbox"
    ? Environment.SANDBOX
    : environmentName === "Production"
    ? Environment.PRODUCTION
    : undefined;
  if (environment === undefined) {
    throw new Error("APPLE_ENVIRONMENT must be Sandbox or Production");
  }

  const appAppleID = environmentName === "Production"
    ? positiveInteger(requiredEnvironment("APPLE_APP_ID"), "APPLE_APP_ID")
    : undefined;
  const appleRootCAs = requiredEnvironment("APPLE_ROOT_CA_DER_BASE64_LIST")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean)
    .map((value) => Buffer.from(value, "base64"));
  if (appleRootCAs.length === 0) {
    throw new Error("APPLE_ROOT_CA_DER_BASE64_LIST must contain a certificate");
  }

  return {
    environmentName,
    environment,
    appAppleID,
    appleRootCAs,
    enableOnlineChecks:
      requiredEnvironment("APPLE_ENABLE_ONLINE_CHECKS") === "true",
    sharedSecret: requiredEnvironment("VERIFIER_SHARED_SECRET"),
    serverAPIKey: decodedPrivateKey(
      requiredEnvironment("APPLE_SERVER_API_PRIVATE_KEY_BASE64"),
    ),
    serverAPIKeyID: requiredEnvironment("APPLE_SERVER_API_KEY_ID"),
    serverAPIIssuerID: requiredEnvironment("APPLE_SERVER_API_ISSUER_ID"),
  };
}

function assertEligibleTransaction(transaction: {
  productId?: string;
  revocationDate?: number;
}): void {
  if (
    transaction.productId !== productID ||
    transaction.revocationDate !== undefined
  ) {
    throw new PublicError(403, "entitlement_ineligible");
  }
}

function transactionJWSFromBody(value: unknown): string {
  const body = typeof value === "string" ? JSON.parse(value) : value;
  if (body === null || typeof body !== "object" || Array.isArray(body)) {
    throw new PublicError(400, "invalid_request");
  }
  const transactionJWS = (body as Record<string, unknown>)["storekit_transaction_jws"];
  if (
    typeof transactionJWS !== "string" ||
    transactionJWS.length === 0 ||
    transactionJWS.length > 24_000
  ) {
    throw new PublicError(400, "invalid_request");
  }
  return transactionJWS;
}

function verifyCallerSignature(
  signature: string | undefined,
  transactionJWS: string,
  sharedSecret: string,
): void {
  if (!signature) throw new PublicError(401, "verifier_unauthorized");
  const expected = createHmac("sha256", sharedSecret)
    .update(transactionJWS, "utf8")
    .digest("base64url");
  const actualBytes = Buffer.from(signature, "utf8");
  const expectedBytes = Buffer.from(expected, "utf8");
  if (
    actualBytes.length !== expectedBytes.length ||
    !timingSafeEqual(actualBytes, expectedBytes)
  ) {
    throw new PublicError(401, "verifier_unauthorized");
  }
}

function headerValue(value: string | string[] | undefined): string | undefined {
  return Array.isArray(value) ? undefined : value;
}

function requiredTransactionID(value: string | undefined): string {
  if (!value) throw new PublicError(403, "entitlement_ineligible");
  return value;
}

function requiredEnvironment(name: string): string {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`${name} is required`);
  return value;
}

function positiveInteger(value: string, name: string): number {
  const number = Number(value);
  if (!Number.isSafeInteger(number) || number <= 0) {
    throw new Error(`${name} must be a positive integer`);
  }
  return number;
}

function decodedPrivateKey(value: string): string {
  const decoded = Buffer.from(value, "base64").toString("utf8").trim();
  if (
    !decoded.startsWith("-----BEGIN PRIVATE KEY-----") ||
    !decoded.endsWith("-----END PRIVATE KEY-----")
  ) {
    throw new Error(
      "APPLE_SERVER_API_PRIVATE_KEY_BASE64 must contain a Base64-encoded PEM private key",
    );
  }
  return decoded;
}
