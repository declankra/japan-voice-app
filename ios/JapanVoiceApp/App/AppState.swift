import AVFAudio
import Observation
import OSLog
import SwiftUI

@MainActor
@Observable
final class AppState {
    enum Screen {
        case home
        case conversation
    }

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.example.JapanVoiceApp",
        category: "AppState"
    )
    private let reconnectDelays: [TimeInterval] = [0.5, 1, 2, 4, 10]

    var screen: Screen = .home
    var session = ConversationSession()
    var lastBootstrap: RealtimeBootstrap?
    var conversationHistory: [ConversationThread] = []

    @ObservationIgnored
    private let workerClient: WorkerClient

    @ObservationIgnored
    private let realtimeService: any RealtimeService

    @ObservationIgnored
    private let conversationStore: ConversationStore

    @ObservationIgnored
    private var bootstrapTask: Task<Void, Never>?

    @ObservationIgnored
    private var reconnectTask: Task<Void, Never>?

    @ObservationIgnored
    private var shouldReconnectOnForeground = false

    @ObservationIgnored
    private var shouldReconnectAfterInterruption = false

    @ObservationIgnored
    private var userPaused = false

    @ObservationIgnored
    private var conversationStartedAt: Date?

    @ObservationIgnored
    private var currentTurns: [ConversationTurn] = []

    @ObservationIgnored
    private var pendingTurnSpeaker: ActiveSpeaker?

    @ObservationIgnored
    private var pendingSourceTranscript = ""

    private var logSessionID: String {
        session.sessionId ?? lastBootstrap?.session.id ?? "pending"
    }

    init(
        workerClient: WorkerClient = WorkerClient(),
        realtimeService: (any RealtimeService)? = nil,
        conversationStore: ConversationStore = ConversationStore()
    ) {
        self.workerClient = workerClient
        self.conversationStore = conversationStore

        let service = realtimeService ?? OpenAIRealtimeService()
        self.realtimeService = service
        service.setEventHandler { [weak self] event in
            Task { [weak self] in
                await MainActor.run {
                    self?.handleRealtimeEvent(event)
                }
            }
        }

        Task { [weak self] in
            guard let self else { return }
            conversationHistory = await conversationStore.loadThreads()
        }
    }

    func startConversation() {
        guard screen == .home else {
            return
        }

        cancelPendingTasks()
        userPaused = false
        shouldReconnectOnForeground = false
        shouldReconnectAfterInterruption = false

        session = ConversationSession(
            connectionState: .bootstrapping,
            statusMessage: "Connecting…"
        )
        conversationStartedAt = .now
        currentTurns = []
        pendingTurnSpeaker = nil
        pendingSourceTranscript = ""
        screen = .conversation

        bootstrapTask = Task { [weak self] in
            guard let self else { return }
            await bootstrapRealtime()
        }
    }

    func endConversation() {
        finalizeCurrentThreadIfNeeded()
        cancelPendingTasks()
        userPaused = false
        shouldReconnectOnForeground = false
        shouldReconnectAfterInterruption = false
        lastBootstrap = nil
        screen = .home
        session = ConversationSession()
        conversationStartedAt = nil
        currentTurns = []
        pendingTurnSpeaker = nil
        pendingSourceTranscript = ""

        logger.log("Conversation ended for session \(self.logSessionID, privacy: .public)")

        Task {
            await realtimeService.disconnect()
        }
    }

    func selectSpeaker(_ speaker: ActiveSpeaker) {
        guard screen == .conversation else { return }
        session.selectSpeaker(speaker)
        logger.log("Speaker handoff selected for session \(self.logSessionID, privacy: .public): \(speaker.rawValue, privacy: .public)")
    }

    func togglePause() {
        guard screen == .conversation else { return }

        switch session.connectionState {
        case .ready:
            userPaused = true
            session.connectionState = .paused
            session.statusMessage = "Paused."
            logger.log("Conversation paused by user for session \(self.logSessionID, privacy: .public)")

            Task {
                await realtimeService.pause()
            }

        case .paused:
            userPaused = false
            session.statusMessage = "Resuming…"
            logger.log("Conversation resume requested for session \(self.logSessionID, privacy: .public)")

            Task { [weak self] in
                guard let self else { return }
                do {
                    try await realtimeService.resume()
                    guard screen == .conversation else { return }
                    session.connectionState = .ready
                    session.statusMessage = "Listening live."
                } catch {
                    await startReconnectCycle(reason: "Resuming…")
                }
            }

        case .idle, .bootstrapping, .reconnecting(_), .failed(_):
            break
        }
    }

    func handleScenePhaseChange(_ phase: ScenePhase) {
        guard screen == .conversation else { return }

        switch phase {
        case .background:
            guard shouldAutoPauseForBackground(session.connectionState) else {
                return
            }

            shouldReconnectOnForeground = !userPaused
            pauseForSystem(message: "Paused while the app is in the background.")

        case .active:
            guard shouldReconnectOnForeground, !userPaused else { return }
            shouldReconnectOnForeground = false

            Task { [weak self] in
                guard let self else { return }
                await startReconnectCycle(reason: "Resuming…")
            }

        case .inactive:
            break

        @unknown default:
            break
        }
    }

    func handleAudioInterruption(_ notification: Notification) {
        guard screen == .conversation else { return }
        guard let userInfo = notification.userInfo else { return }

        let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt ?? 0
        guard let interruptionType = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch interruptionType {
        case .began:
            shouldReconnectAfterInterruption = !userPaused
            pauseForSystem(message: "Paused for an audio interruption.")

        case .ended:
            let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)

            guard shouldReconnectAfterInterruption, options.contains(.shouldResume), !userPaused else {
                shouldReconnectAfterInterruption = false
                if session.connectionState == .paused {
                    session.statusMessage = "Paused after the interruption."
                }
                return
            }

            shouldReconnectAfterInterruption = false

            Task { [weak self] in
                guard let self else { return }
                await startReconnectCycle(reason: "Resuming…")
            }

        @unknown default:
            break
        }
    }

    private func bootstrapRealtime() async {
        logger.log("Bootstrapping realtime session from screen state with session \(self.logSessionID, privacy: .public)")

        do {
            let bootstrap = try await workerClient.fetchRealtimeBootstrap()
            guard !Task.isCancelled, screen == .conversation else {
                return
            }

            try await realtimeService.connect(using: bootstrap)
            guard !Task.isCancelled, screen == .conversation else {
                return
            }

            lastBootstrap = bootstrap
            session.sessionId = bootstrap.session.id
            session.connectionState = .ready
            session.statusMessage = "Listening live."
            logger.log("Realtime session ready with id \(bootstrap.session.id, privacy: .public)")
        } catch {
            guard !Task.isCancelled, screen == .conversation else {
                return
            }

            applyFailure(error)
        }
    }

    private func handleRealtimeEvent(_ event: RealtimeServiceEvent) {
        guard screen == .conversation else { return }

        switch event {
        case .sessionReady(let sessionId):
            session.sessionId = sessionId
            session.connectionState = .ready
            session.statusMessage = "Listening live."

        case .inputTranscriptChanged(let text):
            let currentSpeaker = pendingTurnSpeaker ?? session.activeSpeaker
            if pendingTurnSpeaker == nil, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                pendingTurnSpeaker = currentSpeaker
            }
            let speaker = pendingTurnSpeaker ?? currentSpeaker
            session.updateInputTranscript(text, for: speaker)

        case .inputTranscriptFinalized(let text):
            let speaker = pendingTurnSpeaker ?? session.activeSpeaker
            pendingTurnSpeaker = speaker
            pendingSourceTranscript = text.trimmingCharacters(in: .whitespacesAndNewlines)
            session.finalizeInputTranscript(text, for: speaker)

        case .outputTextChanged(let text):
            let outputSpeaker = outputSpeakerForCurrentTurn()
            session.updateLiveOutput(text, for: outputSpeaker)

        case .outputTextFinalized(let text):
            let outputSpeaker = outputSpeakerForCurrentTurn()
            session.commitOutput(text, for: outputSpeaker)
            session.clearInputTranscript(for: pendingTurnSpeaker ?? session.activeSpeaker)
            appendCompletedTurn(with: text, outputSpeaker: outputSpeaker)

        case .transportLost(let reason):
            guard !userPaused, session.connectionState != .paused else { return }

            logger.error("Realtime transport lost for session \(self.logSessionID, privacy: .public): \(reason, privacy: .public)")

            Task { [weak self] in
                guard let self else { return }
                await startReconnectCycle(reason: "Reconnecting…")
            }
        }
    }

    private func startReconnectCycle(reason: String) async {
        guard screen == .conversation, !userPaused else { return }

        bootstrapTask?.cancel()
        reconnectTask?.cancel()

        reconnectTask = Task { [weak self] in
            guard let self else { return }

            for (index, delay) in reconnectDelays.enumerated() {
                guard !Task.isCancelled, screen == .conversation, !userPaused else {
                    return
                }

                let attempt = index + 1
                session.connectionState = .reconnecting(attempt)
                session.statusMessage = attempt == 1 ? reason : "Reconnecting… (\(attempt)/\(reconnectDelays.count))"
                logger.log("Reconnect attempt \(attempt) scheduled for session \(self.logSessionID, privacy: .public) after \(delay, privacy: .public)s")

                do {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    let bootstrap = try await workerClient.fetchRealtimeBootstrap()
                    try await realtimeService.connect(using: bootstrap)

                    guard !Task.isCancelled, screen == .conversation else { return }

                    lastBootstrap = bootstrap
                    session.sessionId = bootstrap.session.id
                    session.connectionState = .ready
                    session.statusMessage = "Listening live."
                    logger.log("Reconnect succeeded for session \(bootstrap.session.id, privacy: .public) on attempt \(attempt)")
                    reconnectTask = nil
                    return
                } catch let workerError as WorkerClientError {
                    if case .unauthorized = workerError {
                        applyFailure(workerError)
                        reconnectTask = nil
                        return
                    }

                    if case .contractDrift = workerError {
                        applyFailure(workerError)
                        reconnectTask = nil
                        return
                    }
                } catch {
                    logger.error("Reconnect attempt \(attempt) failed for session \(self.logSessionID, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }

            applyFailure(SessionFailure.reconnectExhausted)
            reconnectTask = nil
        }
    }

    private func pauseForSystem(message: String) {
        cancelPendingTasks()
        session.connectionState = .paused
        session.statusMessage = message
        logger.log("System pause for session \(self.logSessionID, privacy: .public): \(message, privacy: .public)")

        Task {
            await realtimeService.disconnect()
        }
    }

    private func cancelPendingTasks() {
        bootstrapTask?.cancel()
        bootstrapTask = nil
        reconnectTask?.cancel()
        reconnectTask = nil
    }

    private func applyFailure(_ error: Error) {
        switch error {
        case let workerError as WorkerClientError:
            applyFailure(mapFailure(from: workerError))
        case let realtimeError as RealtimeServiceConnectError:
            switch realtimeError {
            case .microphonePermissionDenied:
                applyFailure(SessionFailure.microphonePermissionDenied)
            case .audioSessionConfigurationFailed(_):
                applyFailure(SessionFailure.audioSessionFailed)
            case .websocketSetupFailed(_):
                applyFailure(SessionFailure.realtimeTransportFailed)
            }
        default:
            applyFailure(SessionFailure.realtimeTransportFailed)
        }
    }

    private func applyFailure(_ failure: SessionFailure) {
        cancelPendingTasks()
        userPaused = false
        shouldReconnectOnForeground = false
        shouldReconnectAfterInterruption = false
        session.connectionState = .failed(failure)
        session.statusMessage = failureMessage(for: failure)
        logger.error("Conversation failed for session \(self.logSessionID, privacy: .public) with state \(String(describing: failure), privacy: .public)")

        Task {
            await realtimeService.disconnect()
        }
    }

    private func mapFailure(from error: WorkerClientError) -> SessionFailure {
        switch error {
        case .missingConfiguration(_), .invalidConfiguration(_):
            return .appConfigurationMissing
        case .unauthorized:
            return .workerSecretMismatch
        case .timedOut, .workerUnavailable, .transportFailure(_):
            return .workerUnavailable
        case .contractDrift, .invalidBootstrapField:
            return .bootstrapContractDrift
        case .serverFailure(_), .requestFailed(_), .invalidResponse:
            return .workerFailed
        }
    }

    private func failureMessage(for failure: SessionFailure) -> String {
        switch failure {
        case .appConfigurationMissing:
            return "Set the worker URL and shared secret in ios/Config/Local.xcconfig."
        case .workerSecretMismatch:
            return "App and worker secrets do not match."
        case .workerUnavailable:
            return "Worker unreachable."
        case .bootstrapContractDrift:
            return "Bootstrap contract drift detected."
        case .workerFailed:
            return "Worker failed."
        case .microphonePermissionDenied:
            return "Microphone access is required."
        case .audioSessionFailed:
            return "Audio session failed."
        case .realtimeTransportFailed:
            return "Realtime transport failed."
        case .reconnectExhausted:
            return "Connection lost. Restart the conversation."
        }
    }

    private func shouldAutoPauseForBackground(_ state: ConnectionState) -> Bool {
        switch state {
        case .ready, .bootstrapping, .reconnecting(_):
            return true
        case .idle, .paused, .failed(_):
            return false
        }
    }

    private func outputSpeakerForCurrentTurn() -> ActiveSpeaker {
        let speaker = pendingTurnSpeaker ?? session.activeSpeaker
        return speaker == .localUser ? .conversationPartner : .localUser
    }

    private func appendCompletedTurn(with translatedText: String, outputSpeaker: ActiveSpeaker) {
        let trimmedTranslation = translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranslation.isEmpty else { return }

        let turnSpeaker = pendingTurnSpeaker ?? (outputSpeaker == .localUser ? .conversationPartner : .localUser)
        let turn = ConversationTurn(
            speaker: turnSpeaker,
            sourceText: pendingSourceTranscript,
            translatedText: trimmedTranslation,
            createdAt: .now
        )

        currentTurns.append(turn)
        pendingTurnSpeaker = nil
        pendingSourceTranscript = ""
    }

    private func finalizeCurrentThreadIfNeeded() {
        guard !currentTurns.isEmpty else { return }

        let thread = ConversationThread(
            startedAt: conversationStartedAt ?? .now,
            endedAt: .now,
            turns: currentTurns
        )

        guard thread.hasTranscript else { return }

        conversationHistory.insert(thread, at: 0)

        Task { [thread, conversationStore] in
            await conversationStore.appendThread(thread)
        }
    }
}
