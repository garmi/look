import SwiftData
import SwiftUI
import UIKit

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \QuestionEntry.createdAt, order: .reverse) private var questions: [QuestionEntry]
    @Query(sort: \DailyTrial.createdAt, order: .reverse) private var trials: [DailyTrial]
    @Query(sort: \DailyHealthLog.dayKey, order: .reverse) private var healthLogs: [DailyHealthLog]
    @Query private var syncSettingsList: [SyncSettings]

    @State private var syncInProgress = false
    @State private var syncFeedback = ""
    @State private var clipboardFeedback = ""
    @State private var defaultsRefreshToken = UUID()
    @AppStorage("profile.caregiverName") private var caregiverName = ""
    @AppStorage("profile.caregiverRelation") private var caregiverRelation = ""
    @AppStorage("profile.caregiverContact") private var caregiverContact = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                LOOKNavBar(pageTitle: "Profile", showNotificationDot: false)

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

                        Section("Beta Launch") {
                            LabeledContent("Build") {
                                Text(appVersionLabel)
                            }

                            LabeledContent("Records ready") {
                                Text("\(questions.count + trials.count + healthLogs.count)")
                            }

                            LabeledContent("Cloud sync") {
                                Text(syncSettings?.isConfigured == true ? "Configured" : "Pending")
                                    .foregroundStyle(syncSettings?.isConfigured == true ? .green : .secondary)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Launch path")
                                    .font(.subheadline.weight(.medium))
                                Text("Host data on Supabase, distribute through TestFlight, track crashes with Sentry, and watch activation/retention in PostHog.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Weekly loop")
                                    .font(.subheadline.weight(.medium))
                                Text("Review crashes, uploads, morning check-ins, and medication confirmations every week. Ship one scoped improvement per cycle.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Section("Stage Roadmap") {
                            Text(roadmapSnapshot.title)
                                .font(.subheadline.weight(.medium))
                            Text(roadmapSnapshot.subtitle)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            ForEach(roadmapSnapshot.actions, id: \.self) { action in
                                Text("• \(action)")
                                    .font(.footnote)
                            }
                        }

                        Section {
                            TextField("Caregiver name", text: $caregiverName)
                            TextField("Relationship", text: $caregiverRelation)
                            TextField("Phone or WhatsApp", text: $caregiverContact)
                                .keyboardType(.phonePad)

                            Text(caregiverSnapshot.preview)
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Button("Copy caregiver update") {
                                copyToClipboard(caregiverSnapshot.copyText, successMessage: "Caregiver update copied.")
                            }
                            .disabled(caregiverSnapshot.copyText.isEmpty)

                            Button("Copy doctor visit pack") {
                                copyToClipboard(visitPackSnapshot.copyText, successMessage: "Doctor visit pack copied.")
                            }
                            .disabled(visitPackSnapshot.copyText.isEmpty)

                            if !clipboardFeedback.isEmpty {
                                Text(clipboardFeedback)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        } header: {
                            Text("Caregiver Sharing")
                        } footer: {
                            Text("Use this to send one consistent update to a trusted caregiver or share your next visit pack before an appointment.")
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
            }
            .navigationBarHidden(true)
            .onAppear {
                seedDefaultsIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
                defaultsRefreshToken = UUID()
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

    private var appVersionLabel: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "v\(version) (\(build))"
    }

    private var healthRecords: [StoredHealthRecord] {
        _ = defaultsRefreshToken
        return HealthRecordStore.loadRecords()
    }

    private var patternSnapshot: PatternSnapshot {
        PatternEngine.analyze(healthLogs: healthLogs, trials: trials)
    }

    private var roadmapSnapshot: StageRoadmapSnapshot {
        HealthRecordStore.roadmap(for: profiles.first?.stage ?? .ckd, risk: patternSnapshot.riskTier)
    }

    private var visitPackSnapshot: VisitPackSnapshot {
        HealthRecordStore.buildVisitPack(
            profile: profiles.first,
            questions: questions,
            trials: trials,
            healthLogs: healthLogs,
            pattern: patternSnapshot,
            records: healthRecords
        )
    }

    private var caregiverSnapshot: CaregiverUpdateSnapshot {
        let todayKey = dayKey(for: Date())
        let medsConfirmedToday = healthLogs.first(where: { $0.dayKey == todayKey })?.medicationConfirmedAt != nil
        return HealthRecordStore.buildCaregiverUpdate(
            profile: profiles.first,
            pattern: patternSnapshot,
            records: healthRecords,
            todayMedicationConfirmed: medsConfirmedToday
        )
    }

    private func copyToClipboard(_ text: String, successMessage: String) {
        guard !text.isEmpty else { return }
        let decorated = decoratedCopyText(text)
        UIPasteboard.general.string = decorated
        clipboardFeedback = successMessage
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            clipboardFeedback = ""
        }
    }

    private func decoratedCopyText(_ text: String) -> String {
        guard !caregiverName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
              !caregiverRelation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
              !caregiverContact.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return text
        }

        var lines = [text, "", "Caregiver contact"]
        if !caregiverName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("- Name: \(caregiverName.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
        if !caregiverRelation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("- Relation: \(caregiverRelation.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
        if !caregiverContact.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("- Contact: \(caregiverContact.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
        return lines.joined(separator: "\n")
    }

    private func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
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
