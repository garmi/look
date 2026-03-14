import Foundation
import SwiftData

@Model
final class DailyTrial {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var rating: Int
    var whatWorked: String
    var friction: String
    var nextImprovement: String

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        rating: Int,
        whatWorked: String,
        friction: String,
        nextImprovement: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.rating = rating
        self.whatWorked = whatWorked
        self.friction = friction
        self.nextImprovement = nextImprovement
    }
}
