import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \QuestionEntry.createdAt, order: .reverse) private var questions: [QuestionEntry]
    @Query(sort: \DailyTrial.createdAt, order: .reverse) private var trials: [DailyTrial]
    @Query(sort: \DailyHealthLog.dayKey, order: .reverse) private var healthLogs: [DailyHealthLog]
    @Query private var syncSettingsList: [SyncSettings]

    @State private var syncInProgress = false
    @State private var syncFeedback = ""

    var body: some View {
        NavigationStack {
            List {
                if let profile = profiles.first {
                    Section("Your Context") {
                        TextField(
                            "Name (optional)",
                            text: Binding(
                                get: { profile.name },
                                set: { newValue in
                                    profile.name = newValue
                                    profile.updatedAt = .now
                                    try? modelContext.save()
                                }
                            )
                        )

                        Picker(
                            "Stage",
                            selection: Binding(
                                get: { profile.stage },
                                set: { newValue in
                                    profile.stage = newValue
                                    try? modelContext.save()
                                }
                            )
                        ) {
                            ForEach(PatientStage.allCases) { stage in
                                Text(stage.rawValue).tag(stage)
                            }
                        }

                        Picker(
                            "City",
                            selection: Binding(
                                get: { profile.city },
                                set: { newValue in
                                    profile.city = newValue
                                    try? modelContext.save()
                                }
                            )
                        ) {
                            ForEach(CityChoice.allCases) { city in
                                Text(city.rawValue).tag(city)
                            }
                        }

                        Picker(
                            "Language",
                            selection: Binding(
                                get: { profile.language },
                                set: { newValue in
                                    profile.language = newValue
                                    try? modelContext.save()
                                }
                            )
                        ) {
                            ForEach(LanguageChoice.allCases) { language in
                                Text(language.rawValue).tag(language)
                            }
                        }
                    }

                    if let syncSettings = syncSettings {
                        Section {
                            TextField(
                                "Supabase URL",
                                text: Binding(
                                    get: { syncSettings.supabaseURL },
                                    set: { newValue in
                                        syncSettings.supabaseURL = newValue
                                        try? modelContext.save()
                                    }
                                )
                            )
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                            TextField(
                                "Supabase anon key",
                                text: Binding(
                                    get: { syncSettings.anonKey },
                                    set: { newValue in
                                        syncSettings.anonKey = newValue
                                        try? modelContext.save()
                                    }
                                )
                            )
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                            TextField(
                                "Shared workspace ID",
                                text: Binding(
                                    get: { syncSettings.workspaceID },
                                    set: { newValue in
                                        syncSettings.workspaceID = newValue
                                        try? modelContext.save()
                                    }
                                )
                            )
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                            Toggle(
                                "Auto-sync ready",
                                isOn: Binding(
                                    get: { syncSettings.autoSyncEnabled },
                                    set: { newValue in
                                        syncSettings.autoSyncEnabled = newValue
                                        try? modelContext.save()
                                    }
                                )
                            )

                            Button("Generate New Workspace ID") {
                                syncSettings.workspaceID = UUID().uuidString.lowercased()
                                try? modelContext.save()
                            }

                            Button(syncInProgress ? "Syncing..." : "Sync Now") {
                                Task {
                                    await runSync(with: syncSettings)
                                }
                            }
                            .disabled(syncInProgress || !syncSettings.isConfigured)

                            if let lastSyncAt = syncSettings.lastSyncAt {
                                Text("Last sync: \(lastSyncAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            Text(syncFeedback.isEmpty ? syncSettings.lastSyncMessage : syncFeedback)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } header: {
                            Text("Cloud Sync")
                        } footer: {
                            Text("Use the same Supabase URL, anon key, and workspace ID on both Mac and iPhone to sync one shared POC workspace.")
                        }
                    }

                    Section("Safety") {
                        Text("This POC is for educational guidance, workflow trials, and self-tracking. It is not medical advice.")
                            .font(.footnote)
                        Text("For urgent symptoms, use emergency care immediately.")
                            .font(.footnote)
                    }
                } else {
                    Text("Preparing profile...")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Profile")
            .onAppear {
                seedDefaultsIfNeeded()
            }
        }
    }

    private var syncSettings: SyncSettings? {
        syncSettingsList.first
    }

    private func seedDefaultsIfNeeded() {
        if profiles.isEmpty {
            modelContext.insert(UserProfile())
        }

        if syncSettingsList.isEmpty {
            modelContext.insert(SyncSettings())
        }

        try? modelContext.save()
    }

    @MainActor
    private func runSync(with settings: SyncSettings) async {
        syncInProgress = true
        syncFeedback = ""

        do {
            let result = try await SupabaseSyncService.sync(
                modelContext: modelContext,
                settings: settings,
                profiles: profiles,
                questions: questions,
                trials: trials,
                healthLogs: healthLogs
            )
            syncFeedback = result.message
        } catch {
            syncFeedback = error.localizedDescription
        }

        syncInProgress = false
    }
}
