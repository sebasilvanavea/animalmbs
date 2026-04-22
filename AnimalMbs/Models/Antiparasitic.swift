import Foundation

struct Antiparasitic: Identifiable, Codable, Hashable {
    var id: UUID
    var petId: UUID?
    var type: AntiparasiticType
    var productName: String
    var date: Date
    var nextApplicationDate: Date?
    var veterinarian: String
    var notes: String
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, type, date, veterinarian, notes
        case petId = "pet_id"
        case productName = "product_name"
        case nextApplicationDate = "next_application_date"
        case createdAt = "created_at"
    }

    init(
        id: UUID = UUID(),
        type: AntiparasiticType = .internal_,
        productName: String,
        date: Date = Date(),
        nextApplicationDate: Date? = nil,
        veterinarian: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.type = type
        self.productName = productName
        self.date = date
        self.nextApplicationDate = nextApplicationDate
        self.veterinarian = veterinarian
        self.notes = notes
    }

    var isOverdue: Bool {
        guard let nextApplicationDate else { return false }
        return nextApplicationDate < Date()
    }

    static func == (lhs: Antiparasitic, rhs: Antiparasitic) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum AntiparasiticType: String, Codable, CaseIterable {
    case internal_ = "Interno"
    case external_ = "Externo"
    case both = "Interno y Externo"

    var icon: String {
        switch self {
        case .internal_: return "pills.fill"
        case .external_: return "drop.fill"
        case .both: return "cross.vial.fill"
        }
    }

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = AntiparasiticType(rawValue: value) ?? .internal_
    }
}

enum CommonAntiparasitic: String, CaseIterable {
    // Internos
    case milbemax = "Milbemax"
    case drontal = "Drontal"
    case panacur = "Panacur"
    case endogard = "Endogard"

    // Externos
    case frontline = "Frontline"
    case nexgard = "NexGard"
    case bravecto = "Bravecto"
    case advantix = "Advantix"
    case revolution = "Revolution"
    case simparica = "Simparica"
}
