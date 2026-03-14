import SwiftData
import SwiftUI

struct AskView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \QuestionEntry.createdAt, order: .reverse) private var history: [QuestionEntry]

    @State private var questionText = ""
    @State private var latestResult: TriageResult?

    private let triageEngine = TriageEngine()

    var body: some View {
        NavigationStack {
            List {
                Section("Ask a Question") {
                    TextEditor(text: $questionText)
                        .frame(minHeight: 110)
                        .overlay(alignment: .topLeading) {
                            if questionText.isEmpty {
                                Text("Type your question...")
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                            }
                        }

                    Button("Analyze and Save") {
                        submitQuestion()
                    }
                    .disabled(questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if let latestResult {
                    Section("Latest Result") {
                        VStack(alignment: .leading, spacing: 8) {
                            categoryPill(latestResult.category)
                            Text(latestResult.summary)
                            Text(latestResult.recommendation)
                                .font(.subheadline)
                            Text(latestResult.safetyNote)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Recent Questions") {
                    if history.isEmpty {
                        Text("No questions saved yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(history.prefix(20))) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    categoryPill(item.category)
                                    Spacer()
                                    Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(item.question)
                                    .font(.subheadline)
                                Text(item.recommendation)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Ask")
        }
    }

    private func submitQuestion() {
        let trimmed = questionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let result = triageEngine.evaluate(question: trimmed)
        let entry = QuestionEntry(
            question: trimmed,
            category: result.category,
            aiSummary: result.summary,
            recommendation: result.recommendation,
            safetyNote: result.safetyNote,
            escalateToHuman: result.escalateToHuman
        )
        modelContext.insert(entry)
        try? modelContext.save()

        latestResult = result
        questionText = ""
    }

    @ViewBuilder
    private func categoryPill(_ category: TriageCategory) -> some View {
        Text(category.rawValue)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(categoryColor(category).opacity(0.15))
            .foregroundStyle(categoryColor(category))
            .clipShape(Capsule())
    }

    private func categoryColor(_ category: TriageCategory) -> Color {
        switch category {
        case .urgentMedical: .red
        case .medication: .blue
        case .emotional: .purple
        case .access: .green
        case .general: .gray
        }
    }
}
