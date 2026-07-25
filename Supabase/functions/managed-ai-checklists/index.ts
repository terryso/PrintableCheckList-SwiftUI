import { createClient } from "npm:@supabase/supabase-js@2.110.8";
import {
  ManagedAIDraft,
  ManagedAIRequest,
  managedSystemPrompt,
  normalizeDraft,
  parseManagedAIRequest,
  RequestValidationError,
} from "./domain.ts";

const corsHeaders = {
  "Access-Control-Allow-Headers": "content-type, idempotency-key",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type AppStoreEnvironmentName = "Sandbox" | "Production";
type VerifiedEntitlement = {
  originalTransactionID: string;
  environment: AppStoreEnvironmentName;
};
type Reservation = {
  operation_state: "reserved" | "completed" | "in_progress";
  effective_time_zone: string;
  calendar_month: string;
  stored_response: unknown | null;
};
type ManagedAIResponse = {
  draft: ManagedAIDraft;
  sources: [];
  did_search: false;
};
type RuntimeConfiguration = {
  environmentName: AppStoreEnvironmentName;
  verifierURL: URL;
  verifierSharedSecret: string;
  providerBaseURL: URL;
  providerAPIKey: string;
  providerModel: string;
};

class PublicError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
  ) {
    super(code);
  }
}

export async function managedAIHandler(request: Request): Promise<Response> {
  if (request.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return errorResponse(new PublicError(405, "method_not_allowed"));
  }

  let operationID: string | undefined;
  let supabase: ReturnType<typeof createAdminClient> | undefined;
  try {
    const payload = await readPayload(request);
    operationID = payload.operationID;

    if (request.headers.get("Idempotency-Key") !== operationID) {
      throw new PublicError(400, "idempotency_key_mismatch");
    }
    if (payload.checklistRequest.searchMode === "always") {
      throw new PublicError(422, "managed_web_search_unavailable");
    }

    const configuration = loadRuntimeConfiguration();
    const entitlement = await verifyEntitlement(
      payload.storeKitTransactionJWS,
      configuration,
    );
    supabase = createAdminClient();

    const reservation = await reserveOperation(
      supabase,
      entitlement,
      payload.operationID,
      payload.timeZoneIdentifier,
    );
    if (reservation.operation_state === "completed") {
      return jsonResponse(requireStoredResponse(reservation.stored_response));
    }
    if (reservation.operation_state === "in_progress") {
      throw new PublicError(409, "operation_in_progress");
    }

    try {
      throwIfAborted(request.signal);
      const response = await generateChecklist(
        payload,
        configuration,
        request.signal,
      );
      throwIfAborted(request.signal);
      const storedResponse = await completeOperation(
        supabase,
        payload.operationID,
        response,
      );
      throwIfAborted(request.signal);
      return jsonResponse(requireStoredResponse(storedResponse));
    } catch (error) {
      const wasCancelled = request.signal.aborted || isAbortError(error);
      await releaseOperation(
        supabase,
        payload.operationID,
        wasCancelled ? "operation_cancelled" : failureCode(error),
      );
      if (wasCancelled) {
        throw new PublicError(503, "operation_cancelled");
      }
      throw error;
    }
  } catch (error) {
    // Do not log a request body, JWS, topic, or provider credential.
    if (
      !(error instanceof PublicError) &&
      !(error instanceof RequestValidationError)
    ) {
      console.error("managed-ai-checklists failed", {
        operationID: operationID ?? "unparsed",
        category: error instanceof Error ? error.name : "unknown",
      });
    }
    return errorResponse(error);
  }
}

if (import.meta.main) {
  Deno.serve(managedAIHandler);
}

async function readPayload(request: Request): Promise<ManagedAIRequest> {
  const body = await request.text();
  if (body.length > 48_000) {
    throw new PublicError(413, "request_too_large");
  }

  try {
    return parseManagedAIRequest(JSON.parse(body));
  } catch (error) {
    if (
      error instanceof RequestValidationError || error instanceof SyntaxError
    ) {
      throw new PublicError(400, "invalid_request");
    }
    throw error;
  }
}

function loadRuntimeConfiguration(): RuntimeConfiguration {
  const environmentName = requiredEnvironment(
    "APPLE_ENVIRONMENT",
  ) as AppStoreEnvironmentName;
  if (environmentName !== "Sandbox" && environmentName !== "Production") {
    throw new Error("APPLE_ENVIRONMENT must be Sandbox or Production");
  }

  const providerBaseURL = validProviderBaseURL(
    requiredEnvironment("MANAGED_AI_PROVIDER_BASE_URL"),
  );

  return {
    environmentName,
    verifierURL: validVerifierURL(
      requiredEnvironment("VERIFICATION_SERVICE_URL"),
    ),
    verifierSharedSecret: requiredEnvironment(
      "VERIFICATION_SERVICE_SHARED_SECRET",
    ),
    providerBaseURL,
    providerAPIKey: requiredEnvironment("MANAGED_AI_PROVIDER_API_KEY"),
    providerModel: requiredEnvironment("MANAGED_AI_PROVIDER_MODEL"),
  };
}

async function verifyEntitlement(
  transactionJWS: string,
  configuration: RuntimeConfiguration,
): Promise<VerifiedEntitlement> {
  const signature = await verificationSignature(
    configuration.verifierSharedSecret,
    transactionJWS,
  );

  let response: Response;
  try {
    response = await fetch(configuration.verifierURL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Managed-AI-Verifier-Signature": signature,
      },
      body: JSON.stringify({ storekit_transaction_jws: transactionJWS }),
    });
  } catch {
    throw new PublicError(503, "entitlement_verification_unavailable");
  }

  if (!response.ok) {
    if (response.status === 403) {
      throw new PublicError(403, "entitlement_invalid");
    }
    if (response.status === 401) {
      throw new PublicError(503, "entitlement_verifier_unauthorized");
    }
    throw new PublicError(503, "entitlement_verification_unavailable");
  }

  let verified: { original_transaction_id?: unknown; environment?: unknown };
  try {
    verified = await response.json();
  } catch {
    throw new PublicError(503, "entitlement_verification_unavailable");
  }

  if (verified.environment !== configuration.environmentName) {
    throw new PublicError(403, "entitlement_invalid");
  }

  return {
    originalTransactionID: requiredTransactionField(
      verified.original_transaction_id,
      "original_transaction_id",
      "entitlement_invalid",
    ),
    environment: configuration.environmentName,
  };
}

async function verificationSignature(
  secret: string,
  message: string,
): Promise<string> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const bytes = new Uint8Array(
    await crypto.subtle.sign("HMAC", key, encoder.encode(message)),
  );
  const base64 = btoa(String.fromCharCode(...bytes));
  return base64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function createAdminClient() {
  const rawSecretKeys = Deno.env.get("SUPABASE_SECRET_KEYS");
  const secretKey = rawSecretKeys
    ? JSON.parse(rawSecretKeys).default
    : Deno.env.get("SUPABASE_SECRET_KEY") ??
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (typeof secretKey !== "string" || secretKey.length === 0) {
    throw new Error("Supabase secret key is not available to the function");
  }

  return createClient(requiredEnvironment("SUPABASE_URL"), secretKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

async function reserveOperation(
  supabase: ReturnType<typeof createAdminClient>,
  entitlement: VerifiedEntitlement,
  operationID: string,
  timeZoneIdentifier: string,
): Promise<Reservation> {
  const { data, error } = await supabase.rpc("reserve_managed_ai_operation", {
    p_original_transaction_id: entitlement.originalTransactionID,
    p_app_store_environment: entitlement.environment,
    p_operation_id: operationID,
    p_requested_time_zone: timeZoneIdentifier,
  });
  if (error) {
    if (error.message.includes("monthly_limit_reached")) {
      throw new PublicError(429, "monthly_limit_reached");
    }
    if (
      error.message.includes("invalid_time_zone") ||
      error.message.includes("operation_id_conflict")
    ) {
      throw new PublicError(400, "invalid_operation_context");
    }
    throw new PublicError(503, "usage_ledger_unavailable");
  }
  if (!Array.isArray(data) || data.length !== 1) {
    throw new PublicError(503, "usage_ledger_unavailable");
  }
  return data[0] as Reservation;
}

async function completeOperation(
  supabase: ReturnType<typeof createAdminClient>,
  operationID: string,
  response: ManagedAIResponse,
): Promise<unknown> {
  const { data, error } = await supabase.rpc("complete_managed_ai_operation", {
    p_operation_id: operationID,
    p_response: response,
  });
  if (error) {
    throw new PublicError(503, "usage_ledger_unavailable");
  }
  return data;
}

async function releaseOperation(
  supabase: ReturnType<typeof createAdminClient>,
  operationID: string,
  code: string,
): Promise<void> {
  const { error } = await supabase.rpc("release_managed_ai_operation", {
    p_operation_id: operationID,
    p_failure_code: code,
  });
  if (error) {
    throw new PublicError(503, "usage_ledger_unavailable");
  }
}

async function generateChecklist(
  request: ManagedAIRequest,
  configuration: RuntimeConfiguration,
  signal: AbortSignal,
): Promise<ManagedAIResponse> {
  const endpoint = new URL(
    "chat/completions",
    ensureTrailingSlash(configuration.providerBaseURL),
  );
  let responseFormatEnabled = true;

  for (let attempt = 0; attempt < 2; attempt += 1) {
    const response = await fetch(endpoint, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${configuration.providerAPIKey}`,
        "Content-Type": "application/json",
      },
      signal,
      body: JSON.stringify({
        model: configuration.providerModel,
        temperature: 0.2,
        response_format: responseFormatEnabled
          ? { type: "json_object" }
          : undefined,
        messages: [
          { role: "system", content: managedSystemPrompt(request) },
          {
            role: "user",
            content:
              `Create a checklist for this request:\n${request.checklistRequest.topic}`,
          },
        ],
      }),
    });

    if (!response.ok) {
      if (attempt === 0 && response.status === 400 && responseFormatEnabled) {
        responseFormatEnabled = false;
        continue;
      }
      if (
        attempt === 0 &&
        (response.status === 408 || response.status === 429 ||
          response.status >= 500)
      ) {
        continue;
      }
      throw new PublicError(503, "managed_provider_unavailable");
    }

    try {
      const providerResponse = await response.json();
      const content = chatCompletionContent(providerResponse);
      const draft = normalizeDraft(
        JSON.parse(content),
        request.checklistRequest.mode,
        request.checklistRequest.existingTitle,
      );
      return { draft, sources: [], did_search: false };
    } catch {
      if (attempt === 0) continue;
      throw new PublicError(503, "managed_provider_invalid_response");
    }
  }

  throw new PublicError(503, "managed_provider_unavailable");
}

function chatCompletionContent(value: unknown): string {
  const response = value as {
    choices?: Array<{ message?: { content?: unknown } }>;
  };
  const content = response.choices?.[0]?.message?.content;
  if (typeof content !== "string" || content.length === 0) {
    throw new Error("provider response did not contain message content");
  }
  return content.replace(/^```json\s*|\s*```$/g, "").trim();
}

function requireStoredResponse(value: unknown): ManagedAIResponse {
  const response = value as Partial<ManagedAIResponse> | null;
  if (
    !response || typeof response !== "object" || !response.draft ||
    response.did_search !== false
  ) {
    throw new PublicError(503, "stored_operation_invalid");
  }
  const draft = normalizeDraft(response.draft, "create", null);
  return { draft, sources: [], did_search: false };
}

function validProviderBaseURL(value: string): URL {
  const url = new URL(value);
  if (
    url.protocol !== "https:" || url.username || url.password || url.search ||
    url.hash
  ) {
    throw new Error(
      "MANAGED_AI_PROVIDER_BASE_URL must be an HTTPS base URL without credentials",
    );
  }
  return url;
}

function validVerifierURL(value: string): URL {
  const url = new URL(value);
  if (
    url.protocol !== "https:" || url.username || url.password || url.search ||
    url.hash
  ) {
    throw new Error(
      "VERIFICATION_SERVICE_URL must be an HTTPS URL without credentials, query, or fragment",
    );
  }
  return url;
}

function ensureTrailingSlash(url: URL): string {
  return url.href.endsWith("/") ? url.href : `${url.href}/`;
}

function requiredEnvironment(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`${name} is required`);
  return value;
}

function requiredTransactionField(
  value: unknown,
  name: string,
  invalidCode: string,
): string {
  if (typeof value !== "string" || value.length === 0) {
    throw new PublicError(403, invalidCode);
  }
  return value;
}

function failureCode(error: unknown): string {
  if (error instanceof PublicError) return error.code;
  if (isAbortError(error)) return "operation_cancelled";
  if (error instanceof RequestValidationError) {
    return "invalid_provider_response";
  }
  return "internal_failure";
}

function throwIfAborted(signal: AbortSignal): void {
  if (signal.aborted) {
    throw new PublicError(503, "operation_cancelled");
  }
}

function isAbortError(error: unknown): boolean {
  return error instanceof Error && error.name === "AbortError";
}

function errorResponse(error: unknown): Response {
  if (error instanceof PublicError) {
    return jsonResponse({ code: error.code }, error.status);
  }
  if (error instanceof RequestValidationError) {
    return jsonResponse({ code: "invalid_request" }, 400);
  }
  return jsonResponse({ code: "managed_service_unavailable" }, 503);
}

function jsonResponse(value: unknown, status = 200): Response {
  return Response.json(value, {
    status,
    headers: corsHeaders,
  });
}
