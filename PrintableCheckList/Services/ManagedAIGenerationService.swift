import Foundation

enum AIGenerationRoute: String, CaseIterable, Identifiable {
    case managed
    case byok

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .managed:
            String(localized: "Managed AI")
        case .byok:
            String(localized: "Use Your Own API Key")
        }
    }
}

struct ManagedAIServiceConfiguration: Equatable, Sendable {
    private let baseURL: URL?

    init(baseURL: URL?) {
        self.baseURL = baseURL
    }

    static func fromBundle(_ bundle: Bundle = .main) -> ManagedAIServiceConfiguration {
        guard
            let rawValue = bundle.object(forInfoDictionaryKey: "MANAGED_AI_SERVICE_URL") as? String,
            let baseURL = validatedBaseURL(rawValue)
        else {
            return ManagedAIServiceConfiguration(baseURL: nil)
        }
        return ManagedAIServiceConfiguration(baseURL: baseURL)
    }

    var isConfigured: Bool {
        baseURL != nil
    }

    var generationEndpoint: URL? {
        baseURL?.appendingPathComponent("managed-ai-checklists")
    }

    private static func validatedBaseURL(_ rawValue: String) -> URL? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.contains("$(") else { return nil }
        guard
            let components = URLComponents(string: value),
            components.scheme?.lowercased() == "https",
            let host = components.host,
            !host.isEmpty,
            components.user == nil,
            components.password == nil,
            components.query == nil,
            components.fragment == nil
        else {
            return nil
        }
        return components.url
    }
}

/// Sends one user-initiated managed AI operation to the product-owned service.
/// The service, not this client, must verify the StoreKit JWS, bind the original
/// transaction to an opaque account, set the account IANA time zone on its first
/// managed operation, and atomically reserve/commit/release monthly allowance.
final class ManagedAIChecklistGenerator: ChecklistGenerating {
    private let endpoint: URL
    private let entitlementJWS: String
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder: JSONDecoder

    init(
        configuration: ManagedAIServiceConfiguration,
        entitlementJWS: String,
        session: URLSession? = nil
    ) throws {
        guard let endpoint = configuration.generationEndpoint else {
            throw ChecklistGenerationError.managedServiceUnavailable
        }
        let trimmedJWS = entitlementJWS.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedJWS.isEmpty else {
            throw ProEntitlementError.notEntitled
        }

        self.endpoint = endpoint
        self.entitlementJWS = trimmedJWS
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 45
            configuration.timeoutIntervalForResource = 45
            configuration.urlCache = nil
            configuration.httpCookieStorage = nil
            configuration.urlCredentialStorage = nil
            configuration.httpShouldSetCookies = false
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            self.session = URLSession(configuration: configuration)
        }
    }

    func generate(request: ChecklistGenerationRequest) async throws -> ChecklistGenerationResult {
        try await generate(request: request, operationID: UUID())
    }

    func generate(
        request: ChecklistGenerationRequest,
        operationID: UUID
    ) async throws -> ChecklistGenerationResult {
        var shouldRetryNetworkFailure = true

        while true {
            do {
                return try await send(request: request, operationID: operationID)
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as URLError where shouldRetryNetworkFailure && error.code != .cancelled {
                shouldRetryNetworkFailure = false
                continue
            } catch let error as ChecklistGenerationError {
                throw error
            } catch let error as ProEntitlementError {
                throw error
            } catch let error as URLError where error.code == .timedOut {
                throw ChecklistGenerationError.timedOut
            } catch is URLError {
                throw ChecklistGenerationError.serviceUnavailable
            } catch {
                throw ChecklistGenerationError.serviceUnavailable
            }
        }
    }

    private func send(
        request: ChecklistGenerationRequest,
        operationID: UUID
    ) async throws -> ChecklistGenerationResult {
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 45
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(operationID.uuidString, forHTTPHeaderField: "Idempotency-Key")
        urlRequest.httpBody = try encoder.encode(
            ManagedAIRequestPayload(
                operationID: operationID,
                storeKitTransactionJWS: entitlementJWS,
                timeZoneIdentifier: TimeZone.current.identifier,
                checklistRequest: ManagedChecklistRequest(request)
            )
        )

        let (data, response) = try await session.data(for: urlRequest)
        try Task.checkCancellation()
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChecklistGenerationError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw mappedError(statusCode: httpResponse.statusCode, data: data)
        }

        let managedResponse = try decoder.decode(ManagedAIResponse.self, from: data)
        return ChecklistGenerationResult(
            draft: managedResponse.draft,
            sources: managedResponse.sources,
            didSearch: managedResponse.didSearch
        )
    }

    private func mappedError(statusCode: Int, data: Data) -> Error {
        if statusCode == 429 {
            return ChecklistGenerationError.managedMonthlyLimitReached
        }

        if let response = try? decoder.decode(ManagedAIErrorResponse.self, from: data) {
            switch response.code {
            case "monthly_limit_reached":
                return ChecklistGenerationError.managedMonthlyLimitReached
            case "operation_in_progress":
                return ChecklistGenerationError.managedOperationInProgress
            case "managed_web_search_unavailable":
                return ChecklistGenerationError.webSearchUnavailable
            case "entitlement_invalid":
                return ProEntitlementError.unverifiedTransaction
            case
                "entitlement_device_jws_invalid",
                "entitlement_device_ineligible",
                "entitlement_device_verification_unavailable",
                "entitlement_verifier_configuration_unavailable",
                "entitlement_lookup_unavailable",
                "entitlement_lookup_invalid",
                "entitlement_apple_jws_invalid",
                "entitlement_apple_transaction_ineligible",
                "entitlement_apple_verification_unavailable",
                "entitlement_transaction_mismatch":
                return ChecklistGenerationError.serviceUnavailable
            default:
                break
            }
        }

        switch statusCode {
        case 401:
            return ProEntitlementError.notEntitled
        case 403:
            return ProEntitlementError.unverifiedTransaction
        case 408, 504:
            return ChecklistGenerationError.timedOut
        default:
            return ChecklistGenerationError.serviceUnavailable
        }
    }

}

private struct ManagedAIRequestPayload: Encodable {
    let operationID: UUID
    let storeKitTransactionJWS: String
    let timeZoneIdentifier: String
    let checklistRequest: ManagedChecklistRequest

    enum CodingKeys: String, CodingKey {
        case operationID = "operation_id"
        case storeKitTransactionJWS = "storekit_transaction_jws"
        case timeZoneIdentifier = "time_zone"
        case checklistRequest = "checklist_request"
    }
}

private struct ManagedChecklistRequest: Encodable {
    let mode: String
    let topic: String
    let languageIdentifier: String
    let existingTitle: String?
    let existingItems: [String]
    let searchMode: String

    enum CodingKeys: String, CodingKey {
        case mode
        case topic
        case languageIdentifier = "language_identifier"
        case existingTitle = "existing_title"
        case existingItems = "existing_items"
        case searchMode = "search_mode"
    }

    init(_ request: ChecklistGenerationRequest) {
        switch request.mode {
        case .create:
            mode = "create"
        case .supplement:
            mode = "supplement"
        }
        topic = request.topic
        languageIdentifier = request.languageIdentifier
        existingTitle = request.existingTitle
        existingItems = request.existingItems
        searchMode = (request.searchModeOverride ?? .automatic).rawValue
    }
}

private struct ManagedAIResponse: Decodable {
    let draft: GeneratedChecklistDraft
    let sources: [ChecklistSource]
    let didSearch: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        draft = try container.decode(GeneratedChecklistDraft.self, forKey: .draft)
        sources = try container.decodeIfPresent([ChecklistSource].self, forKey: .sources) ?? []
        didSearch = try container.decodeIfPresent(Bool.self, forKey: .didSearch) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case draft, sources
        case didSearch = "did_search"
    }
}

private struct ManagedAIErrorResponse: Decodable {
    let code: String
}
