import Combine
import Foundation
import Security

enum LLMProviderPreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case glm
    case openAI
    case deepSeek
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .glm: "GLM"
        case .openAI: "OpenAI"
        case .deepSeek: "DeepSeek"
        case .custom: String(localized: "Custom")
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .glm: "https://open.bigmodel.cn/api/paas/v4"
        case .openAI: "https://api.openai.com/v1"
        case .deepSeek: "https://api.deepseek.com"
        case .custom: ""
        }
    }

    var defaultModel: String {
        switch self {
        case .glm: "glm-4.7-flash"
        case .openAI: "gpt-5-mini"
        case .deepSeek: "deepseek-v4-flash"
        case .custom: ""
        }
    }
}

struct LLMConfiguration: Codable, Equatable, Sendable {
    var provider: LLMProviderPreset
    var baseURL: String
    var model: String

    static let `default` = LLMConfiguration(
        provider: .glm,
        baseURL: LLMProviderPreset.glm.defaultBaseURL,
        model: LLMProviderPreset.glm.defaultModel
    )

    func applyingPreset(_ preset: LLMProviderPreset) -> LLMConfiguration {
        LLMConfiguration(
            provider: preset,
            baseURL: preset.defaultBaseURL,
            model: preset.defaultModel
        )
    }
}

enum LLMConfigurationError: LocalizedError, Equatable {
    case invalidURL
    case missingModel
    case missingAPIKey
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            String(localized: "Enter a valid HTTPS Base URL without a username or password.")
        case .missingModel:
            String(localized: "Enter a model name.")
        case .missingAPIKey:
            String(localized: "Enter an API Key.")
        case .keychain:
            String(localized: "The API Key could not be saved securely.")
        }
    }
}

enum LLMEndpointBuilder {
    static func chatCompletionsURL(from value: String) throws -> URL {
        var components = try validatedComponents(from: value)
        var path = components.path
        while path.hasSuffix("/chat/completions/chat/completions") {
            path.removeLast("/chat/completions".count)
        }
        path = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if !path.hasSuffix("chat/completions") {
            path += path.isEmpty ? "chat/completions" : "/chat/completions"
        }
        components.path = "/" + path
        guard let url = components.url else {
            throw LLMConfigurationError.invalidURL
        }
        return url
    }

    static func normalizedBaseURLString(from value: String) throws -> String {
        var components = try validatedComponents(from: value)
        var path = components.path
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        while path.hasSuffix("chat/completions") {
            path.removeLast("chat/completions".count)
            path = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        components.path = path.isEmpty ? "" : "/" + path
        guard var result = components.url?.absoluteString else {
            throw LLMConfigurationError.invalidURL
        }
        while result.hasSuffix("/") {
            result.removeLast()
        }
        return result
    }

    static func host(from value: String) throws -> String {
        let components = try validatedComponents(from: value)
        guard let host = components.host?.lowercased() else {
            throw LLMConfigurationError.invalidURL
        }
        return host
    }

    private static func validatedComponents(from value: String) throws -> URLComponents {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            var components = URLComponents(string: trimmed),
            components.scheme?.lowercased() == "https",
            let host = components.host,
            !host.isEmpty,
            components.user == nil,
            components.password == nil,
            components.query == nil,
            components.fragment == nil
        else {
            throw LLMConfigurationError.invalidURL
        }
        components.scheme = "https"
        return components
    }
}

protocol LLMCredentialStore {
    func apiKey() throws -> String?
    func saveAPIKey(_ apiKey: String) throws
    func deleteAPIKey() throws
}

final class KeychainLLMCredentialStore: LLMCredentialStore {
    private let service: String
    private let account: String

    init(
        service: String = "com.wehack.PrintableCheckList.llm",
        account: String = "userConfiguredAPIKey"
    ) {
        self.service = service
        self.account = account
    }

    func apiKey() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw LLMConfigurationError.keychain(status)
        }
        guard
            let data = item as? Data,
            let value = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return value
    }

    func saveAPIKey(_ apiKey: String) throws {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw LLMConfigurationError.missingAPIKey }
        let data = Data(trimmed.utf8)
        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw LLMConfigurationError.keychain(updateStatus)
        }

        var item = baseQuery
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let addStatus = SecItemAdd(item as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw LLMConfigurationError.keychain(addStatus)
        }
    }

    func deleteAPIKey() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw LLMConfigurationError.keychain(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

@MainActor
final class LLMConfigurationStore: ObservableObject {
    @Published private(set) var configuration: LLMConfiguration
    @Published private(set) var hasAPIKey: Bool

    private let userDefaults: UserDefaults
    private let credentialStore: any LLMCredentialStore
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        userDefaults: UserDefaults = .standard,
        credentialStore: any LLMCredentialStore = KeychainLLMCredentialStore()
    ) {
        self.userDefaults = userDefaults
        self.credentialStore = credentialStore
        if
            let data = userDefaults.data(forKey: Self.configurationKey),
            let saved = try? decoder.decode(LLMConfiguration.self, from: data)
        {
            configuration = saved
        } else {
            configuration = .default
        }
        hasAPIKey = ((try? credentialStore.apiKey()) ?? nil)?.isEmpty == false
    }

    var isConfigured: Bool {
        hasAPIKey
            && !configuration.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (try? LLMEndpointBuilder.host(from: configuration.baseURL)) != nil
    }

    var targetHost: String? {
        try? LLMEndpointBuilder.host(from: configuration.baseURL)
    }

    func save(configuration newConfiguration: LLMConfiguration, apiKey: String?) throws {
        let normalizedModel = newConfiguration.model
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedModel.isEmpty else { throw LLMConfigurationError.missingModel }
        let normalizedBaseURL = try LLMEndpointBuilder.normalizedBaseURLString(
            from: newConfiguration.baseURL
        )
        if let apiKey, !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            try credentialStore.saveAPIKey(apiKey)
        }

        guard let storedKey = try credentialStore.apiKey(), !storedKey.isEmpty else {
            throw LLMConfigurationError.missingAPIKey
        }

        configuration = LLMConfiguration(
            provider: newConfiguration.provider,
            baseURL: normalizedBaseURL,
            model: normalizedModel
        )
        try persistConfiguration()
        hasAPIKey = true
    }

    func deleteConfiguration() throws {
        try credentialStore.deleteAPIKey()
        userDefaults.removeObject(forKey: Self.configurationKey)
        configuration = .default
        hasAPIKey = false
    }

    func apiKeyForRequest() throws -> String {
        guard let key = try credentialStore.apiKey(), !key.isEmpty else {
            throw LLMConfigurationError.missingAPIKey
        }
        return key
    }

    private func persistConfiguration() throws {
        userDefaults.set(try encoder.encode(configuration), forKey: Self.configurationKey)
    }

    static let configurationKey = "llmConfiguration"
}

#if DEBUG
final class InMemoryLLMCredentialStore: LLMCredentialStore {
    private var value: String?

    init(apiKey: String? = nil) {
        value = apiKey
    }

    func apiKey() throws -> String? { value }
    func saveAPIKey(_ apiKey: String) throws { value = apiKey }
    func deleteAPIKey() throws { value = nil }
}
#endif
