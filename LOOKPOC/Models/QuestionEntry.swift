import Foundation
import SwiftData

@Model
final class QuestionEntry {
    @Attribute(.unique) var id: UUID
    var question: String
    var createdAt: Date
    var updatedAt: Date
    var categoryRaw: String
    var aiSummary: String
    var recommendation: String
    var safetyNote: String
    var escalateToHuman: Bool
    var resolved: Bool
    var userNotes: String

    init(
        id: UUID = UUID(),
        question: String,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        category: TriageCategory,
        aiSummary: String,
        recommendation: String,
        safetyNote: String,
        escalateToHuman: Bool
    ) {
        self.id = id
        self.question = question
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.categoryRaw = category.rawValue
        self.aiSummary = aiSummary
        self.recommendation = recommendation
        self.safetyNote = safetyNote
        self.escalateToHuman = escalateToHuman
        self.resolved = false
        self.userNotes = ""
    }

    var category: TriageCategory {
        get { TriageCategory(rawValue: categoryRaw) ?? .general }
        set { categoryRaw = newValue.rawValue }
    }
}
