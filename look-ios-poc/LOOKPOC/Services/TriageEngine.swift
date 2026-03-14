import Foundation

enum TriageCategory: String, Codable, CaseIterable, Identifiable {
    case urgentMedical = "Urgent Medical"
    case medication = "Medication"
    case emotional = "Emotional"
    case access = "Access & Navigation"
    case general = "General Guidance"

    var id: String { rawValue }
}

struct TriageResult {
    let category: TriageCategory
    let summary: String
    let recommendation: String
    let safetyNote: String
    let escalateToHuman: Bool
}

struct TriageEngine {
    func evaluate(question: String) -> TriageResult {
        let normalized = question.lowercased()

        if containsAny(
            in: normalized,
            keywords: ["chest pain", "can't breathe", "seizure", "faint", "unconscious", "bleeding", "suicidal", "overdose"]
        ) {
            return TriageResult(
                category: .urgentMedical,
                summary: "This question may indicate an emergency symptom or crisis.",
                recommendation: "Do not wait for app guidance. Call emergency services or go to the nearest ER now, then inform your transplant team.",
                safetyNote: "This app does not provide emergency medical advice.",
                escalateToHuman: true
            )
        }

        if containsAny(
            in: normalized,
            keywords: ["missed dose", "tacrolimus", "medicine", "immunosuppressant", "tablet", "dose", "side effect"]
        ) {
            return TriageResult(
                category: .medication,
                summary: "This appears to be a medication adherence or side-effect question.",
                recommendation: "Record exact medicine name, dose, and time; contact your nephrologist/transplant coordinator before changing anything.",
                safetyNote: "Never start, stop, or adjust transplant medication without doctor confirmation.",
                escalateToHuman: true
            )
        }

        if containsAny(
            in: normalized,
            keywords: ["afraid", "anxious", "depressed", "stressed", "panic", "hopeless", "alone", "fear"]
        ) {
            return TriageResult(
                category: .emotional,
                summary: "This looks like emotional support is needed along with medical guidance.",
                recommendation: "Use caregiver or peer group support and schedule a clinician discussion for persistent stress symptoms.",
                safetyNote: "If you feel unsafe, seek immediate in-person help.",
                escalateToHuman: false
            )
        }

        if containsAny(
            in: normalized,
            keywords: ["cost", "ayushman", "bpl", "hospital", "where", "doctor", "insurance", "dialysis center"]
        ) {
            return TriageResult(
                category: .access,
                summary: "This is likely an access or care-navigation question.",
                recommendation: "Use the local directory and shortlist 2 options by city, language, and affordability. Confirm latest details before visiting.",
                safetyNote: "Listings are guidance only; always verify directly with the hospital.",
                escalateToHuman: false
            )
        }

        return TriageResult(
            category: .general,
            summary: "This appears to be a general transplant-care question.",
            recommendation: "Review knowledge articles first, then prepare a short question list for your next doctor appointment.",
            safetyNote: "Educational guidance only, not a diagnosis.",
            escalateToHuman: false
        )
    }

    private func containsAny(in text: String, keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }
}
