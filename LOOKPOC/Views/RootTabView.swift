import SwiftData
import SwiftUI

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \QuestionEntry.createdAt, order: .reverse) private var questions: [QuestionEntry]
    @Query(sort: \DailyTrial.createdAt, order: .reverse) private var trials: [DailyTrial]
    @Query(sort: \DailyHealthLog.dayKey, order: .reverse) private var healthLogs: [DailyHealthLog]

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "waveform.path.ecg")
                }

            AskView()
                .tabItem {
                    Label("Ask", systemImage: "questionmark.bubble")
                }

            DirectoryView()
                .tabItem {
                    Label("Directory", systemImage: "list.bullet.clipboard")
                }

            TrialLabView()
                .tabItem {
                    Label("Trials", systemImage: "checklist")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
        }
        .onAppear {
            seedDemoDataIfNeeded()
            seedProfileIfNeeded()
        }
    }

    private func seedProfileIfNeeded() {
        guard profiles.isEmpty else { return }
        modelContext.insert(UserProfile())
        try? modelContext.save()
    }

    private func seedDemoDataIfNeeded() {
        DemoPersonaSeeder.seedIfNeeded(
            modelContext: modelContext,
            profiles: profiles,
            questions: questions,
            trials: trials,
            healthLogs: healthLogs
        )
    }
}
