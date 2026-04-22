import Foundation

struct Pet: Identifiable, Codable, Hashable {
    var id: UUID
    var userId: UUID?
    var name: String
    var species: PetSpecies
    var breed: String
    var birthDate: Date?
    var sex: PetSex
    var color: String
    var weight: Double
    var microchipNumber: String
    var notes: String
    var createdAt: Date?

    // Synced to Supabase Storage
    var photoUrl: String? = nil

    // Local-only cache (not synced to Supabase DB)
    var photoData: Data? = nil

    // Related data (loaded separately)
    var vaccines: [Vaccine] = []
    var antiparasitics: [Antiparasitic] = []
    var medicalRecords: [MedicalRecord] = []
    var weightHistory: [WeightEntry] = []

    enum CodingKeys: String, CodingKey {
        case id, name, species, breed, sex, color, weight, notes
        case userId = "user_id"
        case birthDate = "birth_date"
        case microchipNumber = "microchip_number"
        case photoUrl = "photo_url"
        case createdAt = "created_at"
    }

    init(
        id: UUID = UUID(),
        name: String,
        species: PetSpecies = .dog,
        breed: String = "",
        birthDate: Date? = nil,
        sex: PetSex = .unknown,
        color: String = "",
        weight: Double = 0,
        microchipNumber: String = "",
        photoData: Data? = nil,
        photoUrl: String? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.species = species
        self.breed = breed
        self.birthDate = birthDate
        self.sex = sex
        self.color = color
        self.weight = weight
        self.microchipNumber = microchipNumber
        self.photoData = photoData
        self.photoUrl = photoUrl
        self.notes = notes
        self.createdAt = Date()
    }

    var age: String {
        guard let birthDate else { return "Sin datos" }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: birthDate, to: Date())
        if let years = components.year, years > 0 {
            return "\(years) año\(years == 1 ? "" : "s")"
        } else if let months = components.month {
            return "\(months) mes\(months == 1 ? "" : "es")"
        }
        return "Recién nacido"
    }

    var nextVaccine: Vaccine? {
        vaccines
            .filter { ($0.nextDoseDate ?? .distantPast) > Date() }
            .sorted { ($0.nextDoseDate ?? .distantFuture) < ($1.nextDoseDate ?? .distantFuture) }
            .first
    }

    var nextAntiparasitic: Antiparasitic? {
        antiparasitics
            .filter { ($0.nextApplicationDate ?? .distantPast) > Date() }
            .sorted { ($0.nextApplicationDate ?? .distantFuture) < ($1.nextApplicationDate ?? .distantFuture) }
            .first
    }

    // Hashable: use only id for equality
    static func == (lhs: Pet, rhs: Pet) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum PetSpecies: String, Codable, CaseIterable {
    case dog = "Perro"
    case cat = "Gato"
    case bird = "Ave"
    case rabbit = "Conejo"
    case hamster = "Hámster"
    case reptile = "Reptil"
    case other = "Otro"

    var icon: String {
        switch self {
        case .dog: return "dog.fill"
        case .cat: return "cat.fill"
        case .bird: return "bird.fill"
        case .rabbit: return "rabbit.fill"
        case .hamster: return "hare.fill"
        case .reptile: return "lizard.fill"
        case .other: return "pawprint.fill"
        }
    }

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = PetSpecies(rawValue: value) ?? .other
    }
}

enum PetSex: String, Codable, CaseIterable {
    case male = "Macho"
    case female = "Hembra"
    case unknown = "Desconocido"

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = PetSex(rawValue: value) ?? .unknown
    }
}
