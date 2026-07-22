import Foundation
import Security
import XCTest
@testable import PrintableCheckList

private final class TestCredentialStore: LLMCredentialStore {
    var value: String?

    init(_ value: String? = nil) {
        self.value = value
    }

    func apiKey() throws -> String? { value }
    func saveAPIKey(_ apiKey: String) throws { value = apiKey }
    func deleteAPIKey() throws { value = nil }
}

private final class URLProtocolStub: URLProtocol {
    enum Behavior {
        case response(status: Int, data: Data)
        case failure(Error)
    }

    private static let lock = NSLock()
    private static var handler: ((URLRequest) throws -> Behavior)?

    static func setHandler(_ newHandler: @escaping (URLRequest) throws -> Behavior) {
        lock.lock()
        handler = newHandler
        lock.unlock()
    }

    static func clearHandler() {
        lock.lock()
        handler = nil
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        let currentHandler = Self.handler
        Self.lock.unlock()
        do {
            guard let currentHandler else {
                throw URLError(.unknown)
            }
            switch try currentHandler(request) {
            case .response(let status, let data):
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: status,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            case .failure(let error):
                client?.urlProtocol(self, didFailWithError: error)
            }
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

@MainActor
final class AIGenerationTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.clearHandler()
        super.tearDown()
    }

    func testProviderPresetsPreferGLMAndRemainEditable() {
        XCTAssertEqual(LLMConfiguration.default.provider, .glm)
        XCTAssertEqual(LLMConfiguration.default.baseURL, "https://open.bigmodel.cn/api/paas/v4")
        XCTAssertEqual(LLMConfiguration.default.model, "glm-4.7-flash")
        XCTAssertEqual(LLMProviderPreset.openAI.defaultModel, "gpt-5-mini")
        XCTAssertEqual(LLMProviderPreset.deepSeek.defaultBaseURL, "https://api.deepseek.com")
        XCTAssertEqual(LLMProviderPreset.custom.defaultBaseURL, "")
    }

    func testEndpointValidationAndNormalization() throws {
        XCTAssertEqual(
            try LLMEndpointBuilder.chatCompletionsURL(
                from: "https://open.bigmodel.cn/api/paas/v4/"
            ).absoluteString,
            "https://open.bigmodel.cn/api/paas/v4/chat/completions"
        )
        XCTAssertEqual(
            try LLMEndpointBuilder.chatCompletionsURL(
                from: "https://example.com/v1/chat/completions/chat/completions"
            ).absoluteString,
            "https://example.com/v1/chat/completions"
        )
        XCTAssertThrowsError(
            try LLMEndpointBuilder.chatCompletionsURL(from: "http://example.com/v1")
        )
        XCTAssertThrowsError(
            try LLMEndpointBuilder.chatCompletionsURL(from: "https://user:pass@example.com/v1")
        )
    }

    func testConfigurationStoresKeyOutsideUserDefaults() throws {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let credentials = TestCredentialStore()
        let store = LLMConfigurationStore(
            userDefaults: defaults,
            credentialStore: credentials
        )
        let secret = "secret-should-never-be-in-defaults"
        try store.save(configuration: .default, apiKey: secret)
        XCTAssertEqual(credentials.value, secret)
        XCTAssertFalse(
            String(data: defaults.data(forKey: LLMConfigurationStore.configurationKey)!, encoding: .utf8)!
                .contains(secret)
        )

        var changed = store.configuration
        changed.baseURL = "https://api.example.com/v1"
        try store.save(configuration: changed, apiKey: nil)
        XCTAssertEqual(store.configuration.baseURL, "https://api.example.com/v1")
    }

    func testKeychainCredentialRoundTrip() throws {
        let service = "com.wehack.PrintableCheckList.tests.\(UUID().uuidString)"
        let credentials = KeychainLLMCredentialStore(service: service, account: "test")
        defer { try? credentials.deleteAPIKey() }

        do {
            let initialValue = try credentials.apiKey()
            XCTAssertNil(initialValue)
            try credentials.saveAPIKey("first-key")
            XCTAssertEqual(try credentials.apiKey(), "first-key")
            try credentials.saveAPIKey("updated-key")
            XCTAssertEqual(try credentials.apiKey(), "updated-key")
            try credentials.deleteAPIKey()
            XCTAssertNil(try credentials.apiKey())
        } catch let LLMConfigurationError.keychain(status)
            where status == errSecMissingEntitlement
        {
            throw XCTSkip("Unsigned simulator tests do not have a Keychain entitlement.")
        }
    }

    func testNormalizerStripsPrefixesLimitsLengthAndDeduplicates() throws {
        let longItem = String(repeating: "字", count: 250)
        let extraItems = (0..<45).map { "Unique item \($0)" }
        let raw = GeneratedChecklistDraft(
            title: String(repeating: "T", count: 100),
            items: [
                "1. Passport",
                "☐ PASSPORT",
                "- Café",
                "CAFE",
                "  ",
                longItem,
            ] + extraItems
        )
        let normalized = try AIResultNormalizer.normalize(
            raw,
            mode: .create,
            existingTitle: nil,
            existingItems: []
        )
        XCTAssertEqual(normalized.title.count, 80)
        XCTAssertEqual(normalized.items.count, 40)
        XCTAssertEqual(normalized.items[0], "Passport")
        XCTAssertEqual(normalized.items[1], "Café")
        XCTAssertEqual(normalized.items[2].count, 200)
    }

    func testSupplementRemovesItemsAlreadyInChecklist() throws {
        let normalized = try AIResultNormalizer.normalize(
            GeneratedChecklistDraft(
                title: "Ignored",
                items: ["passport", "Portable charger", "portable charger"]
            ),
            mode: .supplement,
            existingTitle: "Travel",
            existingItems: ["Passport"]
        )
        XCTAssertEqual(normalized.title, "Travel")
        XCTAssertEqual(normalized.items, ["Portable charger"])
    }

    func testGLMRequestUsesBearerJSONModeAndOnlyFirstTwoHundredItems() async throws {
        let session = makeSession()
        URLProtocolStub.setHandler { request in
            XCTAssertEqual(
                request.url?.absoluteString,
                "https://open.bigmodel.cn/api/paas/v4/chat/completions"
            )
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer private-key")
            let body = try Self.bodyData(from: request)
            let text = try XCTUnwrap(String(data: body, encoding: .utf8))
            XCTAssertTrue(text.contains("\"response_format\""))
            XCTAssertTrue(text.contains("Item 199"))
            XCTAssertFalse(text.contains("Item 200"))
            return .response(status: 200, data: Self.successData)
        }
        let generator = try OpenAICompatibleChecklistGenerator(
            configuration: .default,
            apiKey: "private-key",
            session: session
        )
        let result = try await generator.generate(
            request: ChecklistGenerationRequest(
                mode: .supplement,
                topic: "Add missing items",
                languageIdentifier: "en",
                existingTitle: "Travel",
                existingItems: (0..<205).map { "Item \($0)" }
            )
        )
        XCTAssertEqual(result.items, ["Umbrella", "Power adapter"])
    }

    func testJSONModeRejectionRetriesOnceWithoutResponseFormat() async throws {
        let session = makeSession()
        var requests = 0
        URLProtocolStub.setHandler { request in
            requests += 1
            let body = try Self.bodyData(from: request)
            let text = try XCTUnwrap(String(data: body, encoding: .utf8))
            if requests == 1 {
                XCTAssertTrue(text.contains("response_format"))
                return .response(
                    status: 400,
                    data: Data("{\"error\":\"response_format is unsupported\"}".utf8)
                )
            }
            XCTAssertFalse(text.contains("response_format"))
            return .response(status: 200, data: Self.successData)
        }
        let generator = try OpenAICompatibleChecklistGenerator(
            configuration: .default,
            apiKey: "key",
            session: session
        )
        _ = try await generator.generate(request: Self.createRequest)
        XCTAssertEqual(requests, 2)
    }

    func testMarkdownJSONAndNetworkErrorsAreMappedWithoutLeakingKey() async throws {
        let session = makeSession()
        let fenced = """
        {"choices":[{"message":{"role":"assistant","content":"```json\\n{\\\"title\\\":\\\"Trip\\\",\\\"items\\\":[\\\"Umbrella\\\"]}\\n```"}}]}
        """
        URLProtocolStub.setHandler { _ in
            .response(status: 200, data: Data(fenced.utf8))
        }
        let secret = "never-show-this-key"
        let generator = try OpenAICompatibleChecklistGenerator(
            configuration: .default,
            apiKey: secret,
            session: session
        )
        let result = try await generator.generate(request: Self.createRequest)
        XCTAssertEqual(result.title, "Trip")

        for (status, expected) in [
            (401, ChecklistGenerationError.invalidAPIKey),
            (404, ChecklistGenerationError.modelNotFound),
            (429, ChecklistGenerationError.quotaExceeded),
            (503, ChecklistGenerationError.serviceUnavailable),
        ] {
            URLProtocolStub.setHandler { _ in
                .response(status: status, data: Data("{\"error\":\"failed\"}".utf8))
            }
            do {
                _ = try await generator.generate(request: Self.createRequest)
                XCTFail("Expected status \(status) to fail")
            } catch let error as ChecklistGenerationError {
                XCTAssertEqual(error, expected)
                XCTAssertFalse(error.localizedDescription.contains(secret))
            }
        }
    }

    func testTimeoutEmptyAndTruncatedResponses() async throws {
        let session = makeSession()
        let generator = try OpenAICompatibleChecklistGenerator(
            configuration: .default,
            apiKey: "key",
            session: session
        )

        URLProtocolStub.setHandler { _ in .failure(URLError(.timedOut)) }
        await assertGenerationError(.timedOut, generator: generator)

        URLProtocolStub.setHandler { _ in .response(status: 200, data: Data()) }
        await assertGenerationError(.invalidResponse, generator: generator)

        URLProtocolStub.setHandler { _ in
            .response(status: 200, data: Data("{\"choices\":[".utf8))
        }
        await assertGenerationError(.invalidResponse, generator: generator)
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: configuration)
    }

    private func assertGenerationError(
        _ expected: ChecklistGenerationError,
        generator: OpenAICompatibleChecklistGenerator
    ) async {
        do {
            _ = try await generator.generate(request: Self.createRequest)
            XCTFail("Expected generation to fail")
        } catch let error as ChecklistGenerationError {
            XCTAssertEqual(error, expected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private static let createRequest = ChecklistGenerationRequest(
        mode: .create,
        topic: "Travel",
        languageIdentifier: "en",
        existingTitle: nil,
        existingItems: []
    )

    private static let successData = Data(
        "{\"choices\":[{\"message\":{\"role\":\"assistant\",\"content\":\"{\\\"title\\\":\\\"Travel\\\",\\\"items\\\":[\\\"Umbrella\\\",\\\"Power adapter\\\"]}\"}}]}".utf8
    )

    private static func bodyData(from request: URLRequest) throws -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else {
            throw XCTSkip("The request did not contain an HTTP body.")
        }
        stream.open()
        defer { stream.close() }
        var result = Data()
        var buffer = [UInt8](repeating: 0, count: 4_096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count < 0 { throw stream.streamError ?? URLError(.cannotDecodeContentData) }
            if count == 0 { break }
            result.append(buffer, count: count)
        }
        return result
    }
}
