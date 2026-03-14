import Foundation
import SwiftData

enum PatientStage: String, Codable, CaseIterable, Identifiable {
    case ckd = "CKD"
    case dialysis = "Dialysis"
    case awaitingTransplant = "Awaiting Transplant"
    case postTransplant = "Post Transplant"
    case caregiver = "Caregiver"

    var id: String { rawValue }
}

enum CityChoice: String, Codable, CaseIterable, Identifiable {
    case bengaluru = "Bengaluru"
    case hyderabad = "Hyderabad"
    case other = "Other"

    var id: String { rawValue }
}

enum LanguageChoice: String, Codable, CaseIterable, Identifiable {
    case english = "English"
    case kannada = "Kannada"
    case telugu = "Telugu"
    case hindi = "Hindi"

    var id: String { rawValue }
}

@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID
    var name: String
    var stageRaw: String
    var cityRaw: String
    var languageRaw: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String = "",
        stage: PatientStage = .ckd,
        city: CityChoice = .bengaluru,
        language: LanguageChoice = .english,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.stageRaw = stage.rawValue
        self.cityRaw = city.rawValue
        self.languageRaw = language.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var stage: PatientStage {
        get { PatientStage(rawValue: stageRaw) ?? .ckd }
        set {
            stageRaw = newValue.rawValue
            updatedAt = .now
        }
    }

    var city: CityChoice {
        get { CityChoice(rawValue: cityRaw) ?? .bengaluru }
        set {
            cityRaw = newValue.rawValue
            updatedAt = .now
        }
    }

    var language: LanguageChoice {
        get { LanguageChoice(rawValue: languageRaw) ?? .english }
        set {
            languageRaw = newValue.rawValue
            updatedAt = .now
        }
    }
}
