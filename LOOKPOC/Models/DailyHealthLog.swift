import Foundation
import SwiftData

enum CheckinStatus: String, Codable, CaseIterable, Identifiable {
    case allGood = "all_good"
    case unsure = "unsure"
    case help = "help"

    var id: String { rawValue }
}

@Model
final class DailyHealthLog {
    @Attribute(.unique) var dayKey: String
    var createdAt: Date
    var updatedAt: Date
    var medicationConfirmedAt: Date?
    var checkinCompletedAt: Date?
    var checkinStatusRaw: String?

    init(
        dayKey: String,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        medicationConfirmedAt: Date? = nil,
        checkinCompletedAt: Date? = nil,
        checkinStatus: CheckinStatus? = nil
    ) {
        self.dayKey = dayKey
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.medicationConfirmedAt = medicationConfirmedAt
        self.checkinCompletedAt = checkinCompletedAt
        self.checkinStatusRaw = checkinStatus?.rawValue
    }

    var checkinStatus: CheckinStatus? {
        get {
            guard let checkinStatusRaw else { return nil }
            return CheckinStatus(rawValue: checkinStatusRaw)
        }
        set {
            checkinStatusRaw = newValue?.rawValue
            updatedAt = .now
        }
    }
}
