import Foundation

struct WeightEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var petId: UUID?
    var date: Date
    var weight: Double
    var notes: String
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, date, weight, notes
        case petId = "pet_id"
        case createdAt = "created_at"
    }

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        weight: Double,
        notes: String = ""
    ) {
        self.id = id
        self.date = date
        self.weight = weight
        self.notes = notes
    }

    static func == (lhs: WeightEntry, rhs: WeightEntry) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
