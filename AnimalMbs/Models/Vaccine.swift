import Foundation

struct Vaccine: Identifiable, Codable, Hashable {
    var id: UUID
    var petId: UUID?
    var name: String
    var date: Date
    var nextDoseDate: Date?
    var veterinarian: String
    var clinicName: String
    var lotNumber: String
    var notes: String
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, date, veterinarian, notes
        case petId = "pet_id"
        case nextDoseDate = "next_dose_date"
        case clinicName = "clinic_name"
        case lotNumber = "lot_number"
        case createdAt = "created_at"
    }

    init(
        id: UUID = UUID(),
        name: String,
        date: Date = Date(),
        nextDoseDate: Date? = nil,
        veterinarian: String = "",
        clinicName: String = "",
        lotNumber: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.date = date
        self.nextDoseDate = nextDoseDate
        self.veterinarian = veterinarian
        self.clinicName = clinicName
        self.lotNumber = lotNumber
        self.notes = notes
    }

    var isOverdue: Bool {
        guard let nextDoseDate else { return false }
        return nextDoseDate < Date()
    }

    var statusColor: String {
        if isOverdue { return "red" }
        guard let nextDoseDate else { return "green" }
        let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: nextDoseDate).day ?? 0
        if daysUntil <= 7 { return "orange" }
        return "green"
    }

    static func == (lhs: Vaccine, rhs: Vaccine) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum CommonVaccine: String, CaseIterable {
    // Perros
    case parvovirus = "Parvovirus"
    case moquillo = "Moquillo (Distemper)"
    case hepatitis = "Hepatitis Infecciosa"
    case leptospirosis = "Leptospirosis"
    case rabia = "Rabia"
    case bordetella = "Bordetella (Tos de Perrera)"
    case sextuple = "Séxtuple"
    case octuple = "Óctuple"

    // Gatos
    case triplefelina = "Triple Felina"
    case leucemiaFelina = "Leucemia Felina"
    case rabiaFelina = "Rabia (Felina)"

    var defaultIntervalDays: Int {
        switch self {
        case .rabia, .rabiaFelina: return 365
        case .sextuple, .octuple: return 365
        case .triplefelina: return 365
        case .leucemiaFelina: return 365
        default: return 365
        }
    }
}
