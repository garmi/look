import SwiftData
import SwiftUI

struct DashboardView: View {
    @Query(sort: \QuestionEntry.createdAt, order: .reverse) private var questions: [QuestionEntry]
    @Query(sort: \DailyTrial.createdAt, order: .reverse) private var trials: [DailyTrial]
    @Query private var profiles: [UserProfile]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(greetingText)
                        .font(.title2.bold())

                    Text("Personal POC mode: capture every question, test workflows daily, and improve weekly.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        StatCard(title: "Questions", value: "\(questions.count)", subtitle: "Total captured")
                        StatCard(title: "Trials", value: "\(trials.count)", subtitle: "Daily logs")
                    }

                    StatCard(
                        title: "Last Trial Score",
                        value: trials.first.map { "\($0.rating)/5" } ?? "N/A",
                        subtitle: trials.first.map { relativeDate($0.createdAt) } ?? "Add your first trial today"
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Safety Guardrail")
                            .font(.headline)
                        Text("LOOK POC provides education and workflow support only. Always confirm clinical decisions with your doctor.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            }
            .navigationTitle("LOOK POC")
        }
    }

    private var greetingText: String {
        guard let profile = profiles.first else { return "Welcome" }
        if profile.name.isEmpty {
            return "Welcome (\(profile.stage.rawValue))"
        }
        return "Welcome, \(profile.name)"
    }

    private func relativeDate(_ date: Date) -> String {
        date.formatted(.relative(presentation: .named))
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(value)
                .font(.title3.bold())
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
