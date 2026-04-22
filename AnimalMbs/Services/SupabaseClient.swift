import Foundation

/// Lightweight Supabase REST client using URLSession — zero external dependencies.
actor SupabaseClient {
    static let shared = SupabaseClient()

    private let baseURL = "https://ohhhwbjxciovjvvcsleu.supabase.co"
    private let apiKey = "sb_publishable_H6MEO6YSSuEWwVXAQO4otw_TyR4AuTr"

    private var accessToken: String?
    private var refreshToken: String?

    private let session = URLSession.shared

    private lazy var decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            // Try full ISO 8601 with fractional seconds
            if let date = ISO8601DateFormatter.withFractional.date(from: str) { return date }
            // Try ISO 8601 without fractional
            if let date = ISO8601DateFormatter.standard.date(from: str) { return date }
            // Try date-only "YYYY-MM-DD"
            if let date = DateFormatter.dateOnly.date(from: str) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(str)")
        }
        return d
    }()

    private lazy var encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(DateFormatter.dateOnly.string(from: date))
        }
        return e
    }()

    // MARK: - Auth

    struct AuthResponse: Codable {
        let accessToken: String
        let refreshToken: String
        let user: AuthUser

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case user
        }
    }

    struct AuthUser: Codable {
        let id: UUID
        let email: String?
        let userMetadata: UserMetadata?

        enum CodingKeys: String, CodingKey {
            case id
            case email
            case userMetadata = "user_metadata"
        }
    }

    struct UserMetadata: Codable {
        let avatarURL: String?

        enum CodingKeys: String, CodingKey {
            case avatarURL = "avatar_url"
        }
    }

    struct AuthError: Codable {
        let error: String?
        let errorDescription: String?
        let msg: String?

        enum CodingKeys: String, CodingKey {
            case error
            case errorDescription = "error_description"
            case msg
        }

        var message: String {
            errorDescription ?? msg ?? error ?? "Error desconocido"
        }
    }

    func signUp(email: String, password: String) async throws -> AuthResponse {
        let url = URL(string: "\(baseURL)/auth/v1/signup")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["email": email, "password": password])

        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        if statusCode >= 400 {
            if let authErr = try? JSONDecoder().decode(AuthError.self, from: data) {
                throw NSError(domain: "Auth", code: statusCode, userInfo: [NSLocalizedDescriptionKey: authErr.message])
            }
            throw NSError(domain: "Auth", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Error de registro (\(statusCode))"])
        }

        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        self.accessToken = authResponse.accessToken
        self.refreshToken = authResponse.refreshToken
        return authResponse
    }

    func signIn(email: String, password: String) async throws -> AuthResponse {
        let url = URL(string: "\(baseURL)/auth/v1/token?grant_type=password")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["email": email, "password": password])

        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        if statusCode >= 400 {
            if let authErr = try? JSONDecoder().decode(AuthError.self, from: data) {
                throw NSError(domain: "Auth", code: statusCode, userInfo: [NSLocalizedDescriptionKey: authErr.message])
            }
            throw NSError(domain: "Auth", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Credenciales inválidas"])
        }

        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        self.accessToken = authResponse.accessToken
        self.refreshToken = authResponse.refreshToken
        return authResponse
    }

    func refreshSession() async throws -> AuthResponse {
        guard let refreshToken else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "No hay sesión activa"])
        }

        let url = URL(string: "\(baseURL)/auth/v1/token?grant_type=refresh_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["refresh_token": refreshToken])

        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        if statusCode >= 400 {
            self.accessToken = nil
            self.refreshToken = nil
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Sesión expirada, inicia sesión de nuevo"])
        }

        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        self.accessToken = authResponse.accessToken
        self.refreshToken = authResponse.refreshToken
        return authResponse
    }

    func signOut() async {
        if let accessToken {
            let url = URL(string: "\(baseURL)/auth/v1/logout")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(apiKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            _ = try? await session.data(for: request)
        }
        self.accessToken = nil
        self.refreshToken = nil
    }

    func setSession(accessToken: String, refreshToken: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }

    var currentAccessToken: String? { accessToken }

    // MARK: - REST API

    func fetch<T: Decodable>(_ table: String, query: [String: String] = [:], order: String? = nil) async throws -> [T] {
        var components = URLComponents(string: "\(baseURL)/rest/v1/\(table)")!
        var queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        if let order {
            queryItems.append(URLQueryItem(name: "order", value: order))
        }
        queryItems.append(URLQueryItem(name: "select", value: "*"))
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        applyHeaders(&request)

        let (data, response) = try await performRequest(request)
        try checkResponse(response, data: data)
        return try decoder.decode([T].self, from: data)
    }

    func insert<T: Codable>(_ table: String, row: T) async throws -> T {
        let url = URL(string: "\(baseURL)/rest/v1/\(table)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyHeaders(&request)
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try encoder.encode(row)

        let (data, response) = try await performRequest(request)
        try checkResponse(response, data: data)
        let results = try decoder.decode([T].self, from: data)
        guard let first = results.first else {
            throw NSError(domain: "API", code: 500, userInfo: [NSLocalizedDescriptionKey: "No se recibió respuesta del servidor"])
        }
        return first
    }

    func update<T: Codable>(_ table: String, id: UUID, row: T) async throws -> T {
        var components = URLComponents(string: "\(baseURL)/rest/v1/\(table)")!
        components.queryItems = [URLQueryItem(name: "id", value: "eq.\(id.uuidString)")]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "PATCH"
        applyHeaders(&request)
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try encoder.encode(row)

        let (data, response) = try await performRequest(request)
        try checkResponse(response, data: data)
        let results = try decoder.decode([T].self, from: data)
        guard let first = results.first else {
            throw NSError(domain: "API", code: 500, userInfo: [NSLocalizedDescriptionKey: "No se recibió respuesta del servidor"])
        }
        return first
    }

    func delete(_ table: String, id: UUID) async throws {
        var components = URLComponents(string: "\(baseURL)/rest/v1/\(table)")!
        components.queryItems = [URLQueryItem(name: "id", value: "eq.\(id.uuidString)")]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "DELETE"
        applyHeaders(&request)

        let (data, response) = try await performRequest(request)
        try checkResponse(response, data: data)
    }

    // MARK: - Storage

    func uploadPhoto(_ data: Data, userId: UUID, petId: UUID) async throws -> String {
        let path = "\(userId.uuidString)/\(petId.uuidString).jpg"
        let url = URL(string: "\(baseURL)/storage/v1/object/pet-photos/\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "x-upsert")
        request.httpBody = data
        let (respData, response) = try await session.data(for: request)
        try checkResponse(response, data: respData)
        return cacheBustedPublicURL(bucket: "pet-photos", path: path)
    }

    func deletePhoto(userId: UUID, petId: UUID) async throws {
        let path = "\(userId.uuidString)/\(petId.uuidString).jpg"
        let url = URL(string: "\(baseURL)/storage/v1/object/pet-photos/\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (respData, response) = try await session.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if code != 404 { try checkResponse(response, data: respData) }
    }

    func uploadUserPhoto(_ data: Data, userId: UUID) async throws -> String {
        let path = "\(userId.uuidString).jpg"
        let url = URL(string: "\(baseURL)/storage/v1/object/user-photos/\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "x-upsert")
        request.httpBody = data
        let (respData, response) = try await session.data(for: request)
        try checkResponse(response, data: respData)
        return cacheBustedPublicURL(bucket: "user-photos", path: path)
    }

    func updateUserAvatar(url: String) async throws -> AuthUser {
        let endpoint = URL(string: "\(baseURL)/auth/v1/user")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "PUT"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "data": [
                "avatar_url": url
            ]
        ])

        let (data, response) = try await performRequest(request)
        try checkResponse(response, data: data)
        return try JSONDecoder().decode(AuthUser.self, from: data)
    }

    // MARK: - Private Helpers

    private func applyHeaders(_ request: inout URLRequest) {
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
    }

    private func cacheBustedPublicURL(bucket: String, path: String) -> String {
        let basePublicURL = "\(baseURL)/storage/v1/object/public/\(bucket)/\(path)"
        return "\(basePublicURL)?v=\(Int(Date().timeIntervalSince1970 * 1000))"
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        // Auto-refresh on 401
        if statusCode == 401, refreshToken != nil {
            _ = try await refreshSession()
            var retryRequest = request
            if let accessToken {
                retryRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            }
            return try await session.data(for: retryRequest)
        }

        return (data, response)
    }

    private func checkResponse(_ response: URLResponse, data: Data) throws {
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Error desconocido"
            throw NSError(domain: "API", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Error \(statusCode): \(message)"])
        }
    }
}

// MARK: - Date Formatters

private extension ISO8601DateFormatter {
    static let withFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static let standard: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}

private extension DateFormatter {
    static let dateOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()
}
