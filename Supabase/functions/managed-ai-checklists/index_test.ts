import { managedAIHandler } from "./index.ts";

function assert(condition: boolean, message: string): void {
  if (!condition) throw new Error(message);
}

const operationID = "d6e9c3c0-944a-4d0d-8c85-8597d165537e";
const storedResponse = {
  draft: { title: "Family Trip", items: ["Passport"] },
  sources: [],
  did_search: false,
};
const configuredValues = {
  APPLE_ENVIRONMENT: "Sandbox",
  MANAGED_AI_PROVIDER_BASE_URL: "https://provider.example.com/v1",
  MANAGED_AI_PROVIDER_API_KEY: "test-provider-key",
  MANAGED_AI_PROVIDER_MODEL: "test-model",
  VERIFICATION_SERVICE_URL: "https://verifier.example.com/verify",
  VERIFICATION_SERVICE_SHARED_SECRET: "test-verifier-secret",
  SUPABASE_URL: "https://supabase.example.com",
  SUPABASE_SECRET_KEY: "test-supabase-secret",
};

Deno.test("replays a completed managed operation without calling the provider again", async () => {
  await withManagedAIEnvironment(async () => {
    let reserveCount = 0;
    let providerCallCount = 0;
    globalThis.fetch = async (input, init) => {
      const request = new Request(input, init);
      const url = new URL(request.url);

      if (url.hostname === "verifier.example.com") {
        return Response.json({
          original_transaction_id: "original-transaction-id",
          environment: "Sandbox",
        });
      }
      if (url.pathname.endsWith("/reserve_managed_ai_operation")) {
        reserveCount += 1;
        return Response.json([
          reserveCount === 1
            ? {
              operation_state: "reserved",
              effective_time_zone: "Asia/Shanghai",
              calendar_month: "2026-07-01",
              stored_response: null,
            }
            : {
              operation_state: "completed",
              effective_time_zone: "Asia/Shanghai",
              calendar_month: "2026-07-01",
              stored_response: storedResponse,
            },
        ]);
      }
      if (url.pathname.endsWith("/complete_managed_ai_operation")) {
        return Response.json(storedResponse);
      }
      if (url.hostname === "provider.example.com") {
        providerCallCount += 1;
        return Response.json({
          choices: [{ message: { content: JSON.stringify(storedResponse.draft) } }],
        });
      }
      throw new Error(`Unexpected request: ${request.method} ${request.url}`);
    };

    const firstResponse = await managedAIHandler(managedRequest());
    const secondResponse = await managedAIHandler(managedRequest());

    assert(firstResponse.status === 200, "the first operation must complete");
    assert(secondResponse.status === 200, "the completed operation must replay");
    assert(providerCallCount === 1, "a completed operation must not call the provider again");
    assert(
      JSON.stringify(await secondResponse.json()) === JSON.stringify(storedResponse),
      "the replay must return the stored draft",
    );
  });
});

Deno.test("releases an aborted managed operation without completing it", async () => {
  await withManagedAIEnvironment(async () => {
    const abortController = new AbortController();
    let releaseCallCount = 0;
    let providerRequestStarted: (() => void) | undefined;
    const providerStarted = new Promise<void>((resolve) => {
      providerRequestStarted = resolve;
    });
    globalThis.fetch = async (input, init) => {
      const request = new Request(input, init);
      const url = new URL(request.url);

      if (url.hostname === "verifier.example.com") {
        return Response.json({
          original_transaction_id: "original-transaction-id",
          environment: "Sandbox",
        });
      }
      if (url.pathname.endsWith("/reserve_managed_ai_operation")) {
        return Response.json([{
          operation_state: "reserved",
          effective_time_zone: "Asia/Shanghai",
          calendar_month: "2026-07-01",
          stored_response: null,
        }]);
      }
      if (url.pathname.endsWith("/complete_managed_ai_operation")) {
        return Response.json(storedResponse);
      }
      if (url.pathname.endsWith("/release_managed_ai_operation")) {
        releaseCallCount += 1;
        return Response.json(null);
      }
      if (url.hostname === "provider.example.com") {
        providerRequestStarted?.();
        return await new Promise<Response>((resolve, reject) => {
          const timeoutID = setTimeout(
            () => resolve(Response.json({
              choices: [{ message: { content: JSON.stringify(storedResponse.draft) } }],
            })),
            25,
          );
          request.signal.addEventListener(
            "abort",
            () => {
              clearTimeout(timeoutID);
              reject(new DOMException("Request aborted", "AbortError"));
            },
            { once: true },
          );
        });
      }
      throw new Error(`Unexpected request: ${request.method} ${request.url}`);
    };

    const responsePromise = managedAIHandler(managedRequest(abortController.signal));
    await providerStarted;
    abortController.abort();
    const response = await responsePromise;

    assert(response.status === 503, "an aborted operation must not return a draft");
    assert(releaseCallCount === 1, "an aborted operation must release its reservation");
  });
});

Deno.test("cancels after a provider reply before the operation can complete", async () => {
  await withManagedAIEnvironment(async () => {
    const abortController = new AbortController();
    let completeCallCount = 0;
    let releaseCallCount = 0;
    globalThis.fetch = async (input, init) => {
      const request = new Request(input, init);
      const url = new URL(request.url);

      if (url.hostname === "verifier.example.com") {
        return verifiedEntitlementResponse();
      }
      if (url.pathname.endsWith("/reserve_managed_ai_operation")) {
        return reservedOperationResponse();
      }
      if (url.pathname.endsWith("/complete_managed_ai_operation")) {
        completeCallCount += 1;
        return Response.json(storedResponse);
      }
      if (url.pathname.endsWith("/release_managed_ai_operation")) {
        releaseCallCount += 1;
        return Response.json(null);
      }
      if (url.hostname === "provider.example.com") {
        abortController.abort();
        return providerDraftResponse();
      }
      throw new Error(`Unexpected request: ${request.method} ${request.url}`);
    };

    const response = await managedAIHandler(managedRequest(abortController.signal));

    assert(response.status === 503, "a cancelled operation must not return a draft");
    assert(
      (await response.json()).code === "operation_cancelled",
      "the cancellation must be observable to the client",
    );
    assert(completeCallCount === 0, "a cancelled operation must not complete the ledger entry");
    assert(releaseCallCount === 1, "a cancelled operation must release its reservation");
  });
});

Deno.test("returns in-progress for a concurrent retry without calling the provider twice", async () => {
  await withManagedAIEnvironment(async () => {
    let reserveCallCount = 0;
    let providerCallCount = 0;
    let providerStartedResolve: (() => void) | undefined;
    const providerStarted = new Promise<void>((resolve) => {
      providerStartedResolve = resolve;
    });
    let providerResponseResolve: ((response: Response) => void) | undefined;
    const providerResponse = new Promise<Response>((resolve) => {
      providerResponseResolve = resolve;
    });

    globalThis.fetch = async (input, init) => {
      const request = new Request(input, init);
      const url = new URL(request.url);

      if (url.hostname === "verifier.example.com") {
        return verifiedEntitlementResponse();
      }
      if (url.pathname.endsWith("/reserve_managed_ai_operation")) {
        reserveCallCount += 1;
        return reserveCallCount === 1
          ? reservedOperationResponse()
          : Response.json([{
            operation_state: "in_progress",
            effective_time_zone: "Asia/Shanghai",
            calendar_month: "2026-07-01",
            stored_response: null,
          }]);
      }
      if (url.pathname.endsWith("/complete_managed_ai_operation")) {
        return Response.json(storedResponse);
      }
      if (url.hostname === "provider.example.com") {
        providerCallCount += 1;
        providerStartedResolve?.();
        return await providerResponse;
      }
      throw new Error(`Unexpected request: ${request.method} ${request.url}`);
    };

    const firstOperation = managedAIHandler(managedRequest());
    await providerStarted;
    const concurrentRetry = await managedAIHandler(managedRequest());

    assert(concurrentRetry.status === 409, "a concurrent retry must report in progress");
    assert(
      (await concurrentRetry.json()).code === "operation_in_progress",
      "the concurrent retry must have an observable in-progress state",
    );
    assert(providerCallCount === 1, "a concurrent retry must not call the provider again");

    providerResponseResolve?.(providerDraftResponse());
    const completedOperation = await firstOperation;
    assert(completedOperation.status === 200, "the original operation must finish normally");
  });
});

Deno.test("fails closed when the reservation cannot be released", async () => {
  await withManagedAIEnvironment(async () => {
    globalThis.fetch = async (input, init) => {
      const request = new Request(input, init);
      const url = new URL(request.url);

      if (url.hostname === "verifier.example.com") {
        return verifiedEntitlementResponse();
      }
      if (url.pathname.endsWith("/reserve_managed_ai_operation")) {
        return reservedOperationResponse();
      }
      if (url.pathname.endsWith("/release_managed_ai_operation")) {
        return Response.json({ message: "ledger unavailable" }, { status: 503 });
      }
      if (url.hostname === "provider.example.com") {
        return new Response(null, { status: 503 });
      }
      throw new Error(`Unexpected request: ${request.method} ${request.url}`);
    };

    const response = await managedAIHandler(managedRequest());

    assert(response.status === 503, "a release failure must fail closed");
    assert(
      (await response.json()).code === "usage_ledger_unavailable",
      "a release failure must not be reported as if the reservation were handled",
    );
  });
});

function managedRequest(signal?: AbortSignal): Request {
  return new Request("https://function.example.com/managed-ai-checklists", {
    method: "POST",
    signal,
    headers: {
      "Content-Type": "application/json",
      "Idempotency-Key": operationID,
    },
    body: JSON.stringify({
      operation_id: operationID,
      storekit_transaction_jws: "verified-jws",
      time_zone: "Asia/Shanghai",
      checklist_request: {
        mode: "create",
        topic: "Family trip",
        language_identifier: "en",
        existing_title: null,
        existing_items: [],
        search_mode: "automatic",
      },
    }),
  });
}

function reservedOperationResponse(): Response {
  return Response.json([{
    operation_state: "reserved",
    effective_time_zone: "Asia/Shanghai",
    calendar_month: "2026-07-01",
    stored_response: null,
  }]);
}

function verifiedEntitlementResponse(): Response {
  return Response.json({
    original_transaction_id: "original-transaction-id",
    environment: "Sandbox",
  });
}

function providerDraftResponse(): Response {
  return Response.json({
    choices: [{ message: { content: JSON.stringify(storedResponse.draft) } }],
  });
}

async function withManagedAIEnvironment(test: () => Promise<void>): Promise<void> {
  const originalFetch = globalThis.fetch;
  const priorValues = new Map(
    Object.keys(configuredValues).map((key) => [key, Deno.env.get(key)]),
  );

  try {
    for (const [key, value] of Object.entries(configuredValues)) {
      Deno.env.set(key, value);
    }
    await test();
  } finally {
    globalThis.fetch = originalFetch;
    for (const [key, value] of priorValues) {
      if (value === undefined) Deno.env.delete(key);
      else Deno.env.set(key, value);
    }
  }
}
