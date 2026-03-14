import SwiftData
import SwiftUI

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Home", systemImage: "house")
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
            seedProfileIfNeeded()
        }
    }

    private func seedProfileIfNeeded() {
        guard profiles.isEmpty else { return }
        modelContext.insert(UserProfile())
        try? modelContext.save()
    }
}
