import SwiftData
import SwiftUI

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \QuestionEntry.createdAt, order: .reverse) private var questions: [QuestionEntry]
    @Query(sort: \DailyTrial.createdAt, order: .reverse) private var trials: [DailyTrial]
    @Query(sort: \DailyHealthLog.dayKey, order: .reverse) private var healthLogs: [DailyHealthLog]
    @AppStorage("look.demoPersonaPickerSeen") private var demoPersonaPickerSeen = false
    @State private var showPersonaPicker = false

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
            handleInitialLaunch()
        }
        .sheet(isPresented: $showPersonaPicker) {
            DemoPersonaPickerView(
                onSelect: { preset in
                    DemoPersonaSeeder.seed(
                        preset: preset,
                        modelContext: modelContext,
                        profiles: profiles
                    )
                    demoPersonaPickerSeen = true
                    showPersonaPicker = false
                },
                onSkip: {
                    demoPersonaPickerSeen = true
                    seedProfileIfNeeded()
                    showPersonaPicker = false
                }
            )
            .presentationDetents([.large])
        }
    }

    private func seedProfileIfNeeded() {
        guard profiles.isEmpty else { return }
        modelContext.insert(UserProfile())
        try? modelContext.save()
    }

    private func handleInitialLaunch() {
        let needsSelection = DemoPersonaSeeder.requiresSelection(
            questions: questions,
            trials: trials,
            healthLogs: healthLogs
        )

        if needsSelection && !demoPersonaPickerSeen {
            showPersonaPicker = true
        } else {
            seedProfileIfNeeded()
        }
    }
}

private struct DemoPersonaPickerView: View {
    let onSelect: (DemoPersonaPreset) -> Void
    let onSkip: () -> Void

    @State private var selectedPreset: DemoPersonaPreset = .aarav

    private let journeys = DemoPersonaLibrary.journeys

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.gray.opacity(0.25))
                .frame(width: 42, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Choose a demo journey")
                        .font(.custom("DM Serif Display", size: 28))
                        .foregroundStyle(Color(red: 0.11, green: 0.11, blue: 0.18))

                    Text("Start with a seeded patient so you can compare different patterns immediately, or skip and begin with an empty profile.")
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(Color(red: 0.71, green: 0.66, blue: 0.60))
                        .lineSpacing(3)

                    ForEach(journeys) { journey in
                        Button {
                            selectedPreset = journey.preset
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(journey.name)
                                        .font(.custom("DM Serif Display", size: 18))
                                        .foregroundStyle(Color(red: 0.11, green: 0.11, blue: 0.18))
                                    Spacer()
                                    if selectedPreset == journey.preset {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color(red: 0.00, green: 0.48, blue: 0.48))
                                    }
                                }

                                Text("\(journey.ageLabel) · \(journey.stage.rawValue) · \(journey.city.rawValue)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color(red: 0.00, green: 0.48, blue: 0.48))

                                Text(journey.headline)
                                    .font(.system(size: 12, weight: .light))
                                    .foregroundStyle(Color(red: 0.71, green: 0.66, blue: 0.60))
                                    .lineSpacing(3)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(selectedPreset == journey.preset ? Color.white : Color(red: 0.98, green: 0.97, blue: 0.95))
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(selectedPreset == journey.preset ? Color(red: 0.00, green: 0.48, blue: 0.48).opacity(0.45) : Color.black.opacity(0.05), lineWidth: 0.8)
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }

            VStack(spacing: 10) {
                Button {
                    onSelect(selectedPreset)
                } label: {
                    Text("Start with \(DemoPersonaLibrary.journey(for: selectedPreset).name)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(red: 0.11, green: 0.11, blue: 0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button("Skip demo setup") {
                    onSkip()
                }
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(Color(red: 0.71, green: 0.66, blue: 0.60))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .background(Color(red: 0.98, green: 0.98, blue: 0.97))
    }
}
