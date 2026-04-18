import Foundation
import OSLog

struct RealtimeBootstrap: Decodable, Sendable {
    struct Session: Decodable, Sendable {
        let id: String
        let model: String
        let instructions: String?
        let outputModalities: [String]?

        enum CodingKeys: String, CodingKey {
            case id
            case model
            case instructions
            case outputModalities = "output_modalities"
        }
    }

    let value: String
    let expiresAt: Int
    let session: Session

    enum CodingKeys: String, CodingKey {
        case value
        case expiresAt = "expires_at"
        case session
    }

    var websocketURL: URL {
        var components = URLComponents()
        components.scheme = "wss"
        components.host = "api.openai.com"
        components.path = "/v1/realtime"
        components.queryItems = [
            URLQueryItem(name: "model", value: session.model)
        ]
        return components.url!
    }

    func validated() throws -> RealtimeBootstrap {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw WorkerClientError.invalidBootstrapField("client secret")
        }

        guard !session.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw WorkerClientError.invalidBootstrapField("session id")
        }

        guard !session.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw WorkerClientError.invalidBootstrapField("model")
        }

        guard expiresAt > 0 else {
            throw WorkerClientError.invalidBootstrapField("expires_at")
        }

        return self
    }
}

enum WorkerConfiguration {
    static func resolvedBaseURL() throws -> URL {
        let configuredValue = Bundle.main.object(forInfoDictionaryKey: "JapanVoiceWorkerBaseURL") as? String
        let trimmed = configuredValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !trimmed.isEmpty else {
            throw WorkerClientError.missingConfiguration("JapanVoiceWorkerBaseURL")
        }

        guard let configuredURL = URL(string: trimmed),
              let scheme = configuredURL.scheme,
              ["http", "https"].contains(scheme.lowercased()) else {
            throw WorkerClientError.invalidConfiguration("JapanVoiceWorkerBaseURL must be a valid absolute URL.")
        }

        return configuredURL
    }

    static func resolvedAppSecret() throws -> String {
        let configuredValue = Bundle.main.object(forInfoDictionaryKey: "JapanVoiceAppSharedSecret") as? String
        let trimmed = configuredValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !trimmed.isEmpty else {
            throw WorkerClientError.missingConfiguration("JapanVoiceAppSharedSecret")
        }

        return trimmed
    }
}

actor WorkerClient {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.example.JapanVoiceApp",
        category: "WorkerClient"
    )
    private let baseURL: URL?
    private let session: URLSession

    init(baseURL: URL? = nil, session: URLSession? = nil) {
        self.baseURL = baseURL

        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 5
            configuration.timeoutIntervalForResource = 5
            configuration.waitsForConnectivity = false
            self.session = URLSession(configuration: configuration)
        }
    }

    func fetchRealtimeBootstrap() async throws -> RealtimeBootstrap {
        let resolvedBaseURL = if let baseURL {
            baseURL
        } else {
            try WorkerConfiguration.resolvedBaseURL()
        }
        let appSecret = try WorkerConfiguration.resolvedAppSecret()

        var request = URLRequest(url: resolvedBaseURL.appending(path: "ws-token"))
        request.httpMethod = "POST"
        request.timeoutInterval = 5
        request.setValue(appSecret, forHTTPHeaderField: "X-App-Secret")

        logger.log("Requesting realtime bootstrap from \(resolvedBaseURL.absoluteString, privacy: .public)")

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                throw WorkerClientError.timedOut
            case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .notConnectedToInternet:
                throw WorkerClientError.workerUnavailable
            default:
                throw WorkerClientError.transportFailure(error)
            }
        } catch {
            throw WorkerClientError.transportFailure(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WorkerClientError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200 ..< 300:
            break
        case 401:
            throw WorkerClientError.unauthorized
        case 500 ..< 600:
            throw WorkerClientError.serverFailure(httpResponse.statusCode)
        default:
            throw WorkerClientError.requestFailed(httpResponse.statusCode)
        }

        do {
            let bootstrap = try JSONDecoder().decode(RealtimeBootstrap.self, from: data)
            let validatedBootstrap = try bootstrap.validated()
            logger.log("Realtime bootstrap issued for session \(validatedBootstrap.session.id, privacy: .public)")
            return validatedBootstrap
        } catch let error as DecodingError {
            throw WorkerClientError.contractDrift("DecodingError: \(String(reflecting: error))")
        } catch let error as WorkerClientError {
            throw error
        } catch {
            throw WorkerClientError.contractDrift(error.localizedDescription)
        }
    }
}

enum WorkerClientError: LocalizedError {
    case invalidResponse
    case unauthorized
    case timedOut
    case workerUnavailable
    case serverFailure(Int)
    case requestFailed(Int)
    case invalidBootstrapField(String)
    case contractDrift(String)
    case missingConfiguration(String)
    case invalidConfiguration(String)
    case transportFailure(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Worker returned an invalid response."
        case .unauthorized:
            return "App and worker secrets do not match."
        case .timedOut:
            return "Worker request timed out."
        case .workerUnavailable:
            return "Worker is unreachable."
        case .serverFailure(let statusCode):
            return "Worker failed with status \(statusCode)."
        case .requestFailed(let statusCode):
            return "Worker request failed with status \(statusCode)."
        case .invalidBootstrapField(let field):
            return "Worker bootstrap is missing \(field)."
        case .contractDrift(let details):
            return "Worker bootstrap contract drifted. \(details)"
        case .missingConfiguration(let key):
            return "Missing app configuration for \(key)."
        case .invalidConfiguration(let details):
            return details
        case .transportFailure(let error):
            return "Worker transport failed. \(error.localizedDescription)"
        }
    }
}
