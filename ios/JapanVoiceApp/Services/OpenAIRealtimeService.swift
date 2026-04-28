import AVFAudio
import Foundation
import OSLog

final class OpenAIRealtimeService: NSObject, RealtimeService {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.example.JapanVoiceApp",
        category: "OpenAIRealtimeService"
    )
    private let audioSession = AVAudioSession.sharedInstance()
    private let audioFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 24_000, channels: 1, interleaved: true)!

    private var eventHandler: @Sendable (RealtimeServiceEvent) -> Void = { _ in }
    private var transport: RealtimeWebSocketTransport?
    private var audioEngine = AVAudioEngine()
    private var audioConverter: AVAudioConverter?
    private var isPaused = false
    private var currentSessionId: String?
    private var activeSpeaker: ActiveSpeaker = .localUser

    private struct DirectionalConfig {
        let instructions: String
        let inputLanguageCode: String
    }

    private func directionalConfig(for speaker: ActiveSpeaker) -> DirectionalConfig {
        switch speaker {
        case .localUser:
            return DirectionalConfig(
                instructions: """
                You are a live interpreter for a shared phone screen between an English speaker and a Japanese speaker.
                The current speaker is the English speaker. The next utterance is in English.
                Output ONLY natural, polite Japanese suitable for in-person travel conversation.
                Text only. No notes, labels, romaji, or commentary.
                """,
                inputLanguageCode: "en"
            )
        case .conversationPartner:
            return DirectionalConfig(
                instructions: """
                You are a live interpreter for a shared phone screen between an English speaker and a Japanese speaker.
                The current speaker is the Japanese speaker. The next utterance is in Japanese.
                Output ONLY natural, polite English suitable for in-person travel conversation.
                Text only. No notes, labels, or commentary.
                """,
                inputLanguageCode: "ja"
            )
        }
    }

    func setEventHandler(_ handler: @escaping @Sendable (RealtimeServiceEvent) -> Void) {
        eventHandler = handler
    }

    func connect(using bootstrap: RealtimeBootstrap, activeSpeaker: ActiveSpeaker) async throws {
        await disconnect()

        let permissionGranted = await requestRecordPermission()
        guard permissionGranted else {
            throw RealtimeServiceConnectError.microphonePermissionDenied
        }

        do {
            try configureAudioSession()
        } catch {
            throw RealtimeServiceConnectError.audioSessionConfigurationFailed(error.localizedDescription)
        }

        currentSessionId = bootstrap.session.id
        isPaused = false
        self.activeSpeaker = activeSpeaker

        let transport = RealtimeWebSocketTransport(bootstrap: bootstrap) { [weak self] event in
            guard let self else { return }
            Task { [weak self] in
                await MainActor.run {
                    self?.handleTransportEvent(event)
                }
            }
        }

        self.transport = transport

        do {
            try await transport.connect()
            let config = directionalConfig(for: activeSpeaker)
            await transport.configureSession(
                instructions: config.instructions,
                outputModalities: ["text"],
                inputLanguageCode: config.inputLanguageCode
            )
            try startAudioCapture()
            logger.log("Realtime service connected for session \(bootstrap.session.id, privacy: .public) with speaker \(activeSpeaker.rawValue, privacy: .public)")
        } catch {
            self.transport = nil
            currentSessionId = nil
            throw RealtimeServiceConnectError.websocketSetupFailed(error.localizedDescription)
        }
    }

    func setActiveSpeaker(_ speaker: ActiveSpeaker) async {
        guard activeSpeaker != speaker else { return }
        activeSpeaker = speaker

        guard let transport else { return }

        await transport.cancelResponse()
        await transport.commitInputBuffer()

        let config = directionalConfig(for: speaker)
        await transport.configureSession(
            instructions: config.instructions,
            outputModalities: ["text"],
            inputLanguageCode: config.inputLanguageCode
        )
        logger.log("Realtime active speaker set to \(speaker.rawValue, privacy: .public) for session \(self.currentSessionId ?? "unknown", privacy: .public)")
    }

    func pause() async {
        guard !isPaused else { return }
        isPaused = true
        stopAudioCapture()
        await transport?.commitInputBuffer()
        await transport?.cancelResponse()
        logger.log("Realtime audio paused for session \(self.currentSessionId ?? "unknown", privacy: .public)")
    }

    func resume() async throws {
        guard isPaused else { return }
        isPaused = false

        do {
            try configureAudioSession()
            try startAudioCapture()
            logger.log("Realtime audio resumed for session \(self.currentSessionId ?? "unknown", privacy: .public)")
        } catch {
            throw RealtimeServiceConnectError.audioSessionConfigurationFailed(error.localizedDescription)
        }
    }

    func disconnect() async {
        stopAudioCapture()
        await transport?.close(userInitiated: true)
        transport = nil
        currentSessionId = nil
        isPaused = false

        do {
            try audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            logger.error("Failed to deactivate audio session: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func configureAudioSession() throws {
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.allowBluetooth, .defaultToSpeaker])
        try audioSession.setPreferredSampleRate(24_000)
        try audioSession.setPreferredIOBufferDuration(0.02)
        try audioSession.setActive(true)
    }

    private func requestRecordPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            audioSession.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func startAudioCapture() throws {
        stopAudioCapture()

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)

        guard let converter = AVAudioConverter(from: inputFormat, to: audioFormat) else {
            throw RealtimeServiceConnectError.audioSessionConfigurationFailed("Could not create audio converter.")
        }

        audioConverter = converter
        audioEngine.prepare()

        inputNode.installTap(onBus: 0, bufferSize: 2_048, format: inputFormat) { [weak self] buffer, _ in
            guard let self, !self.isPaused, let transport = self.transport else {
                return
            }

            do {
                let data = try self.convert(buffer: buffer, using: converter)
                guard !data.isEmpty else {
                    return
                }

                Task {
                    await transport.sendAudioChunk(data)
                }
            } catch {
                self.logger.error("Audio conversion failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        do {
            try audioEngine.start()
        } catch {
            stopAudioCapture()
            throw error
        }
    }

    private func stopAudioCapture() {
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        audioEngine.reset()
        audioConverter = nil
    }

    private func convert(buffer: AVAudioPCMBuffer, using converter: AVAudioConverter) throws -> Data {
        let ratio = audioFormat.sampleRate / buffer.format.sampleRate
        let estimatedFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1

        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: estimatedFrameCapacity) else {
            return Data()
        }

        var conversionError: NSError?
        let status = converter.convert(to: convertedBuffer, error: &conversionError) { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        if status == .error {
            throw conversionError ?? RealtimeServiceConnectError.audioSessionConfigurationFailed("Audio conversion failed.")
        }

        guard let mData = convertedBuffer.audioBufferList.pointee.mBuffers.mData else {
            return Data()
        }

        let byteCount = Int(convertedBuffer.audioBufferList.pointee.mBuffers.mDataByteSize)
        return Data(bytes: mData, count: byteCount)
    }

    @MainActor
    private func handleTransportEvent(_ event: RealtimeWebSocketTransport.TransportEvent) {
        switch event {
        case .sessionCreated(let sessionId):
            currentSessionId = sessionId
            eventHandler(.sessionReady(sessionId))
        case .inputTranscriptChanged(let text):
            eventHandler(.inputTranscriptChanged(text))
        case .inputTranscriptFinalized(let text):
            eventHandler(.inputTranscriptFinalized(text))
        case .outputTextChanged(let text):
            eventHandler(.outputTextChanged(text))
        case .outputTextFinalized(let text):
            eventHandler(.outputTextFinalized(text))
        case .transportLost(let message):
            logger.error("Realtime transport lost for session \(self.currentSessionId ?? "unknown", privacy: .public): \(message, privacy: .public)")
            eventHandler(.transportLost(message))
        }
    }
}

actor RealtimeWebSocketTransport {
    enum TransportEvent: Sendable {
        case sessionCreated(String)
        case inputTranscriptChanged(String)
        case inputTranscriptFinalized(String)
        case outputTextChanged(String)
        case outputTextFinalized(String)
        case transportLost(String)
    }

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.example.JapanVoiceApp",
        category: "RealtimeWebSocketTransport"
    )
    private let bootstrap: RealtimeBootstrap
    private let handler: @Sendable (TransportEvent) -> Void
    private let session = URLSession(configuration: .ephemeral)

    private var webSocket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var closedByClient = false
    private var inputTranscriptBuffer = ""
    private var outputTextBuffer = ""

    init(
        bootstrap: RealtimeBootstrap,
        handler: @escaping @Sendable (TransportEvent) -> Void
    ) {
        self.bootstrap = bootstrap
        self.handler = handler
    }

    func connect() async throws {
        var request = URLRequest(url: bootstrap.websocketURL)
        request.timeoutInterval = 15
        request.setValue("Bearer \(bootstrap.value)", forHTTPHeaderField: "Authorization")

        let webSocket = session.webSocketTask(with: request)
        self.webSocket = webSocket
        closedByClient = false
        webSocket.resume()
        receiveTask = Task {
            await receiveLoop()
        }
    }

    func sendAudioChunk(_ data: Data) async {
        await send(event: [
            "type": "input_audio_buffer.append",
            "audio": data.base64EncodedString()
        ])
    }

    func configureSession(instructions: String, outputModalities: [String], inputLanguageCode: String) async {
        await send(event: [
            "type": "session.update",
            "session": [
                // Realtime requires the session type on update payloads, even when
                // the session was originally created from a preconfigured client secret.
                "type": "realtime",
                "instructions": instructions,
                "output_modalities": outputModalities,
                "tracing": NSNull(),
                "audio": [
                    "input": [
                        "transcription": [
                            "model": "gpt-4o-mini-transcribe",
                            "language": inputLanguageCode
                        ],
                        "turn_detection": [
                            "type": "server_vad",
                            "create_response": true,
                            "interrupt_response": true,
                            "prefix_padding_ms": 300,
                            "silence_duration_ms": 500
                        ]
                    ]
                ]
            ]
        ])
    }

    func commitInputBuffer() async {
        await send(event: [
            "type": "input_audio_buffer.commit"
        ])
    }

    func cancelResponse() async {
        await send(event: [
            "type": "response.cancel"
        ])
    }

    func close(userInitiated: Bool) async {
        closedByClient = userInitiated
        receiveTask?.cancel()
        receiveTask = nil
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
    }

    private func send(event: [String: Any]) async {
        guard let webSocket else { return }

        do {
            let data = try JSONSerialization.data(withJSONObject: event)
            guard let payload = String(data: data, encoding: .utf8) else { return }
            try await webSocket.send(.string(payload))
        } catch {
            logger.error("Failed to send realtime event: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func receiveLoop() async {
        guard let webSocket else { return }

        while !Task.isCancelled {
            do {
                let message = try await webSocket.receive()

                switch message {
                case .string(let payload):
                    handle(message: payload)
                case .data(let payload):
                    if let text = String(data: payload, encoding: .utf8) {
                        handle(message: text)
                    }
                @unknown default:
                    break
                }
            } catch {
                guard !closedByClient else { break }
                handler(.transportLost(error.localizedDescription))
                break
            }
        }
    }

    private func handle(message: String) {
        guard
            let data = message.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let type = json["type"] as? String
        else {
            return
        }

        switch type {
        case "session.created":
            let session = json["session"] as? [String: Any]
            let sessionId = session?["id"] as? String ?? bootstrap.session.id
            handler(.sessionCreated(sessionId))

        case "conversation.item.input_audio_transcription.delta":
            let delta = json["delta"] as? String ?? ""
            inputTranscriptBuffer.append(delta)
            handler(.inputTranscriptChanged(inputTranscriptBuffer))

        case "conversation.item.input_audio_transcription.completed":
            let transcript = json["transcript"] as? String ?? inputTranscriptBuffer
            if !transcript.isEmpty {
                handler(.inputTranscriptFinalized(transcript))
            }
            inputTranscriptBuffer = ""

        case "response.output_text.delta":
            let delta = json["delta"] as? String ?? ""
            outputTextBuffer.append(delta)
            handler(.outputTextChanged(outputTextBuffer))

        case "response.output_text.done":
            let text = json["text"] as? String ?? outputTextBuffer
            if !text.isEmpty {
                handler(.outputTextFinalized(text))
            }
            outputTextBuffer = ""

        case "response.done":
            outputTextBuffer = ""

        case "error":
            let error = json["error"] as? [String: Any]
            let message = error?["message"] as? String ?? "Realtime connection failed."
            handler(.transportLost(message))

        default:
            break
        }
    }
}
