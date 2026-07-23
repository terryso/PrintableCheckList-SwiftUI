export type ManagedAIRequest = {
  operationID: string;
  storeKitTransactionJWS: string;
  timeZoneIdentifier: string;
  checklistRequest: {
    mode: "create" | "supplement";
    topic: string;
    languageIdentifier: string;
    existingTitle: string | null;
    existingItems: string[];
    searchMode: "off" | "automatic" | "always";
  };
};

export type ManagedAIDraft = {
  title: string;
  items: string[];
};

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export class RequestValidationError extends Error {}

export function parseManagedAIRequest(value: unknown): ManagedAIRequest {
  const body = record(value, "request body");
  const checklistRequest = record(body.checklist_request, "checklist_request");
  const operationID = string(body.operation_id, "operation_id", 36);

  if (!uuidPattern.test(operationID)) {
    throw new RequestValidationError("operation_id must be a UUID");
  }

  const mode = enumValue(
    checklistRequest.mode,
    ["create", "supplement"],
    "mode",
  );
  const searchMode = enumValue(
    checklistRequest.search_mode,
    ["off", "automatic", "always"],
    "search_mode",
  );
  const existingTitle = optionalString(
    checklistRequest.existing_title,
    "existing_title",
    80,
  );

  return {
    operationID,
    storeKitTransactionJWS: string(
      body.storekit_transaction_jws,
      "storekit_transaction_jws",
      24_000,
    ),
    timeZoneIdentifier: string(body.time_zone, "time_zone", 100),
    checklistRequest: {
      mode,
      topic: string(checklistRequest.topic, "topic", 1_000),
      languageIdentifier: string(
        checklistRequest.language_identifier,
        "language_identifier",
        100,
      ),
      existingTitle,
      existingItems: stringArray(
        checklistRequest.existing_items,
        "existing_items",
        200,
        200,
      ),
      searchMode,
    },
  };
}

export function normalizeDraft(
  value: unknown,
  mode: ManagedAIRequest["checklistRequest"]["mode"],
  existingTitle: string | null,
): ManagedAIDraft {
  const draft = record(value, "draft");
  const items = stringArray(draft.items, "draft.items", 40, 200)
    .map((item) => item.replace(/^[-*•\d.\s]+/, "").trim())
    .filter((item) => item.length > 0);
  const seenItems = new Set<string>();
  const deduplicatedItems = items.filter((item) => {
    const key = item.toLocaleLowerCase();
    if (seenItems.has(key)) return false;
    seenItems.add(key);
    return true;
  });

  if (deduplicatedItems.length === 0) {
    throw new RequestValidationError("draft must contain at least one item");
  }

  const title = mode === "supplement"
    ? (existingTitle?.trim() || "Checklist")
    : string(draft.title, "draft.title", 80);

  return { title, items: deduplicatedItems };
}

export function managedSystemPrompt(request: ManagedAIRequest): string {
  const supplementContext = request.checklistRequest.mode === "supplement"
    ? `Existing checklist title: ${
      request.checklistRequest.existingTitle ?? "Checklist"
    }\nExisting items:\n${request.checklistRequest.existingItems.join("\n")}`
    : "";

  return [
    "You generate concise, printable checklist drafts.",
    'Return JSON only, with exactly this shape: {"title": string, "items": string[]}.',
    "Use one independently checkable item per line. Do not include markdown, commentary, URLs, or claims of real-time research.",
    "Keep the title at 80 characters or fewer and return no more than 40 items.",
    `Write in the user's requested language: ${request.checklistRequest.languageIdentifier}.`,
    supplementContext,
  ].filter(Boolean).join("\n\n");
}

function record(value: unknown, field: string): Record<string, unknown> {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new RequestValidationError(`${field} must be an object`);
  }
  return value as Record<string, unknown>;
}

function string(value: unknown, field: string, maximumLength: number): string {
  if (typeof value !== "string") {
    throw new RequestValidationError(`${field} must be a string`);
  }
  const normalized = value.trim();
  if (normalized.length === 0 || normalized.length > maximumLength) {
    throw new RequestValidationError(`${field} has an invalid length`);
  }
  return normalized;
}

function optionalString(
  value: unknown,
  field: string,
  maximumLength: number,
): string | null {
  if (value === null || value === undefined) {
    return null;
  }
  return string(value, field, maximumLength);
}

function stringArray(
  value: unknown,
  field: string,
  maximumCount: number,
  maximumItemLength: number,
): string[] {
  if (!Array.isArray(value) || value.length > maximumCount) {
    throw new RequestValidationError(
      `${field} must contain at most ${maximumCount} strings`,
    );
  }
  return value.map((entry, index) =>
    string(entry, `${field}[${index}]`, maximumItemLength)
  );
}

function enumValue<T extends string>(
  value: unknown,
  allowed: readonly T[],
  field: string,
): T {
  if (typeof value !== "string" || !allowed.includes(value as T)) {
    throw new RequestValidationError(`${field} is invalid`);
  }
  return value as T;
}
