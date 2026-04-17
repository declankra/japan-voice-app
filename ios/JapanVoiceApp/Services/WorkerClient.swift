import Foundation

struct RealtimeBootstrap: Decodable, Sendable {
    let sessionId: String
    let websocketURL: String
    let model: String
    let ephemeralToken: String
    let issuedAt: String
    let expiresAt: String
    let note: String
}

actor WorkerClient {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func fetchRealtimeBootstrap() async throws -> RealtimeBootstrap {
        var request = URLRequest(url: baseURL.appending(path: "ws-token"))
        request.httpMethod = "POST"

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WorkerClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw WorkerClientError.requestFailed(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(RealtimeBootstrap.self, from: data)
    }
}

enum WorkerClientError: LocalizedError {
    case invalidResponse
    case requestFailed(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Worker returned an invalid response."
        case .requestFailed(let statusCode):
            return "Worker request failed with status \(statusCode)."
        }
    }
}
