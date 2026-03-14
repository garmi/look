import Foundation
import SwiftData

@Model
final class SyncSettings {
    @Attribute(.unique) var id: String
    var workspaceID: String
    var supabaseURL: String
    var anonKey: String
    var autoSyncEnabled: Bool
    var lastSyncAt: Date?
    var lastSyncMessage: String

    init(
        id: String = "default",
        workspaceID: String = UUID().uuidString.lowercased(),
        supabaseURL: String = "",
        anonKey: String = "",
        autoSyncEnabled: Bool = false,
        lastSyncAt: Date? = nil,
        lastSyncMessage: String = "Not synced yet."
    ) {
        self.id = id
        self.workspaceID = workspaceID
        self.supabaseURL = supabaseURL
        self.anonKey = anonKey
        self.autoSyncEnabled = autoSyncEnabled
        self.lastSyncAt = lastSyncAt
        self.lastSyncMessage = lastSyncMessage
    }

    var isConfigured: Bool {
        !workspaceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !supabaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !anonKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
