import Foundation

protocol RealtimeService {
    func connect(using bootstrap: RealtimeBootstrap) async throws
    func pause() async
    func resume() async
    func disconnect() async
}

struct NoopRealtimeService: RealtimeService {
    func connect(using bootstrap: RealtimeBootstrap) async throws {
        _ = bootstrap
    }

    func pause() async {}

    func resume() async {}

    func disconnect() async {}
}
