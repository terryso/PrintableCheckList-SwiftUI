import Foundation
import Supabase

protocol DeveloperSnapshotUploading: Sendable {
    func upload(_ projects: [ChecklistProject]) async throws
}

enum DeveloperSnapshotConfiguration: Equatable, Sendable {
    case disabled
    case supabase(url: URL, publishableKey: String)

    static func fromBundle(_ bundle: Bundle = .main) -> DeveloperSnapshotConfiguration {
        guard
            let rawURL = configuredValue(
                bundle.object(forInfoDictionaryKey: "SUPABASE_URL") as? String
            ),
            let url = URL(string: rawURL),
            let key = configuredValue(
                bundle.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String
            )
        else {
            return .disabled
        }
        return .supabase(url: url, publishableKey: key)
    }

    private static func configuredValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("$(") else { return nil }
        return trimmed
    }
}

enum DeveloperSnapshotUploaderFactory {
    static func make(
        configuration: DeveloperSnapshotConfiguration = .fromBundle()
    ) -> (any DeveloperSnapshotUploading)? {
        switch configuration {
        case .disabled:
            return nil
        case .supabase(let url, let publishableKey):
            return SupabaseDeveloperSnapshotUploader(
                url: url,
                publishableKey: publishableKey
            )
        }
    }
}

actor SupabaseDeveloperSnapshotUploader: DeveloperSnapshotUploading {
    private struct SnapshotUpsert: Encodable {
        let ownerID: UUID
        let payload: [ChecklistProject]
        let updatedAt: String

        enum CodingKeys: String, CodingKey {
            case ownerID = "owner_id"
            case payload
            case updatedAt = "updated_at"
        }
    }

    private let client: SupabaseClient

    init(url: URL, publishableKey: String) {
        client = SupabaseClient(supabaseURL: url, supabaseKey: publishableKey)
    }

    func upload(_ projects: [ChecklistProject]) async throws {
        let ownerID = try await authenticatedUserID()
        let snapshot = SnapshotUpsert(
            ownerID: ownerID,
            payload: projects,
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
        try await client
            .from("checklist_snapshots")
            .upsert(snapshot)
            .execute()
    }

    private func authenticatedUserID() async throws -> UUID {
        if let session = try? await client.auth.session {
            return session.user.id
        }
        return try await client.auth.signInAnonymously().user.id
    }
}
