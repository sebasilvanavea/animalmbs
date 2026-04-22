import Foundation

struct MedicalRecord: Identifiable, Codable, Hashable {
    var id: UUID
    var petId: UUID?
    var date: Date
    var reason: String
    var diagnosis: String
    var treatment: String
    var veterinarian: String
    var clinicName: String
    var notes: String
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, date, reason, diagnosis, treatment, veterinarian, notes
        case petId = "pet_id"
        case clinicName = "clinic_name"
        case createdAt = "created_at"
    }

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        reason: String,
        diagnosis: String = "",
        treatment: String = "",
        veterinarian: String = "",
        clinicName: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.date = date
        self.reason = reason
        self.diagnosis = diagnosis
        self.treatment = treatment
        self.veterinarian = veterinarian
        self.clinicName = clinicName
        self.notes = notes
    }

    static func == (lhs: MedicalRecord, rhs: MedicalRecord) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
