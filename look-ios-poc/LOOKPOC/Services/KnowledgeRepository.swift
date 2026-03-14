import Foundation

struct KnowledgeArticle: Identifiable {
    let id: UUID = UUID()
    let title: String
    let pillar: String
    let language: LanguageChoice
}

struct DoctorContact: Identifiable {
    let id: UUID = UUID()
    let name: String
    let city: CityChoice
    let specialty: String
    let languages: [LanguageChoice]
    let notes: String
}

struct CommunityGroup: Identifiable {
    let id: UUID = UUID()
    let name: String
    let focus: String
}

enum KnowledgeRepository {
    static let articles: [KnowledgeArticle] = [
        .init(title: "Missed tacrolimus dose: what to do next", pillar: "Long-term Management", language: .english),
        .init(title: "CKD Stage 4: realistic next 24 months", pillar: "Prognosis", language: .english),
        .init(title: "How to ask the right questions in first nephrologist visit", pillar: "Investigation", language: .english),
        .init(title: "Ayushman Bharat transplant access checklist", pillar: "Access & Navigation", language: .hindi),
        .init(title: "Dialysis to transplant transition: practical steps", pillar: "Access & Navigation", language: .telugu)
    ]

    static let doctors: [DoctorContact] = [
        .init(
            name: "Dr. S. Rao",
            city: .bengaluru,
            specialty: "Nephrology",
            languages: [.english, .kannada, .hindi],
            notes: "Strong follow-up discipline, clear medication plans."
        ),
        .init(
            name: "Dr. V. Reddy",
            city: .hyderabad,
            specialty: "Transplant Surgery",
            languages: [.english, .telugu, .hindi],
            notes: "Good for complex transplant candidacy discussions."
        )
    ]

    static let communityGroups: [CommunityGroup] = [
        .init(name: "LOOK Bengaluru", focus: "City-level support and hospital navigation"),
        .init(name: "LOOK Hyderabad", focus: "City-level support and affordability options"),
        .init(name: "LOOK Caregivers", focus: "Family support and decision making"),
        .init(name: "LOOK Kannada", focus: "Kannada language support"),
        .init(name: "LOOK Telugu", focus: "Telugu language support")
    ]
}
