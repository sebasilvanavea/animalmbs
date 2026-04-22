import Foundation

/// Local photo storage for pet images plus cached user avatars.
final class PhotoStorage {
    static let shared = PhotoStorage()

    private let directory: URL

    private init() {
        directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("pet_photos")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func save(_ data: Data, petId: UUID) {
        let url = directory.appendingPathComponent("\(petId.uuidString).jpg")
        try? data.write(to: url)
    }

    func load(petId: UUID) -> Data? {
        let url = directory.appendingPathComponent("\(petId.uuidString).jpg")
        return try? Data(contentsOf: url)
    }

    func delete(petId: UUID) {
        let url = directory.appendingPathComponent("\(petId.uuidString).jpg")
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - User Profile Photo

    func saveUser(_ data: Data, userId: UUID) {
        let url = directory.appendingPathComponent("user_\(userId.uuidString).jpg")
        try? data.write(to: url)
    }

    func loadUser(userId: UUID) -> Data? {
        let url = directory.appendingPathComponent("user_\(userId.uuidString).jpg")
        return try? Data(contentsOf: url)
    }

    func deleteUser(userId: UUID) {
        let url = directory.appendingPathComponent("user_\(userId.uuidString).jpg")
        try? FileManager.default.removeItem(at: url)
    }
}
