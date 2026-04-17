import Observation
import SwiftUI

@MainActor
@Observable
final class AppState {
    enum Screen {
        case home
        case conversation
    }

    var screen: Screen = .home
    var session = ConversationSession()
    var lastBootstrap: RealtimeBootstrap?

    @ObservationIgnored
    private let workerClient = WorkerClient(baseURL: URL(string: "http://127.0.0.1:8787")!)

    @ObservationIgnored
    private let realtimeService: any RealtimeService = NoopRealtimeService()

    func startConversation() {
        session = ConversationSession(connectionState: .bootstrapping)
        screen = .conversation

        Task {
            await bootstrapRealtime()
        }
    }

    func endConversation() {
        screen = .home
        session = ConversationSession()
        lastBootstrap = nil

        Task {
            await realtimeService.disconnect()
        }
    }

    func selectSpeaker(_ speaker: ActiveSpeaker) {
        session.activeSpeaker = speaker
    }

    func togglePause() {
        switch session.connectionState {
        case .ready:
            session.connectionState = .paused
            Task { await realtimeService.pause() }
        case .paused:
            session.connectionState = .ready
            Task { await realtimeService.resume() }
        case .idle, .bootstrapping, .failed:
            break
        }
    }

    private func bootstrapRealtime() async {
        do {
            let bootstrap = try await workerClient.fetchRealtimeBootstrap()
            lastBootstrap = bootstrap
            session.connectionState = .ready
            session.statusMessage = "Stub session ready for future OpenAI Realtime wiring."
            try await realtimeService.connect(using: bootstrap)
        } catch {
            session.connectionState = .failed(error.localizedDescription)
            session.statusMessage = "Worker bootstrap failed."
        }
    }
}
