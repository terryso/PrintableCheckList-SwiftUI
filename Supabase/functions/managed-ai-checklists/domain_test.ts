import {
  normalizeDraft,
  parseManagedAIRequest,
  RequestValidationError,
} from "./domain.ts";

function assert(condition: boolean, message: string): void {
  if (!condition) throw new Error(message);
}

Deno.test("parses the app's managed-operation contract", () => {
  const request = parseManagedAIRequest({
    operation_id: "d6e9c3c0-944a-4d0d-8c85-8597d165537e",
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
  });

  assert(
    request.operationID === "d6e9c3c0-944a-4d0d-8c85-8597d165537e",
    "operation ID must survive parsing",
  );
  assert(
    request.checklistRequest.searchMode === "automatic",
    "search mode must survive parsing",
  );
});

Deno.test("rejects malformed operation IDs before entitlement work", () => {
  let didThrow = false;
  try {
    parseManagedAIRequest({
      operation_id: "not-a-uuid",
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
    });
  } catch (error) {
    didThrow = error instanceof RequestValidationError;
  }
  assert(didThrow, "malformed operation ID must be rejected");
});

Deno.test("normalizes a generated draft without counting duplicate items", () => {
  const draft = normalizeDraft(
    { title: "Ignored", items: ["- Passport", "passport", "  Charger  "] },
    "supplement",
    "Family Trip",
  );

  assert(
    draft.title === "Family Trip",
    "supplements retain the existing title",
  );
  assert(draft.items.length === 2, "duplicates must be removed");
  assert(draft.items[0] === "Passport", "prefixes must be normalized");
});
