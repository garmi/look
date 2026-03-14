import SwiftData
import SwiftUI

struct TrialLabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyTrial.createdAt, order: .reverse) private var trials: [DailyTrial]

    @State private var rating = 3
    @State private var whatWorked = ""
    @State private var friction = ""
    @State private var nextImprovement = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Log Today's Trial") {
                    Picker("Score", selection: $rating) {
                        ForEach(1...5, id: \.self) { score in
                            Text("\(score)/5").tag(score)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextField("What worked today?", text: $whatWorked)
                    TextField("Where did friction happen?", text: $friction)
                    TextField("One improvement for tomorrow", text: $nextImprovement)

                    Button("Save Trial Log") {
                        saveTrial()
                    }
                    .disabled(
                        whatWorked.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            friction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            nextImprovement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }

                Section("Recent Trial Logs") {
                    if trials.isEmpty {
                        Text("No trial logs yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(trials.prefix(30))) { trial in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Score: \(trial.rating)/5")
                                        .font(.caption.bold())
                                    Spacer()
                                    Text(trial.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text("Worked: \(trial.whatWorked)")
                                    .font(.subheadline)
                                Text("Friction: \(trial.friction)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Text("Next: \(trial.nextImprovement)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Trials")
        }
    }

    private func saveTrial() {
        let entry = DailyTrial(
            rating: rating,
            whatWorked: whatWorked.trimmingCharacters(in: .whitespacesAndNewlines),
            friction: friction.trimmingCharacters(in: .whitespacesAndNewlines),
            nextImprovement: nextImprovement.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        modelContext.insert(entry)
        try? modelContext.save()

        whatWorked = ""
        friction = ""
        nextImprovement = ""
        rating = 3
    }
}
