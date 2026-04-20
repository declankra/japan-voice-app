import Foundation

enum RealtimeServiceEvent: Sendable {
    case sessionReady(String)
    case inputTranscriptChanged(String)
    case inputTranscriptFinalized(String)
    case outputTextChanged(String)
    case outputTextFinalized(String)
    case transportLost(String)
}

enum RealtimeServiceConnectError: LocalizedError, Sendable {
    case microphonePermissionDenied
    case audioSessionConfigurationFailed(String)
    case websocketSetupFailed(String)

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone permission was denied."
        case .audioSessionConfigurationFailed(let details):
            return "Audio session setup failed. \(details)"
        case .websocketSetupFailed(let details):
            return "Realtime transport setup failed. \(details)"
        }
    }
}

protocol RealtimeService: AnyObject {
    func setEventHandler(_ handler: @escaping @Sendable (RealtimeServiceEvent) -> Void)
    func connect(using bootstrap: RealtimeBootstrap) async throws
    func pause() async
    func resume() async throws
    func disconnect() async
}

final class NoopRealtimeService: RealtimeService {
    func setEventHandler(_ handler: @escaping @Sendable (RealtimeServiceEvent) -> Void) {
        _ = handler
    }

    func connect(using bootstrap: RealtimeBootstrap) async throws {
        _ = bootstrap
    }

    func pause() async {}

    func resume() async throws {}

    func disconnect() async {}
}
