import Foundation

enum ActiveSpeaker: String, CaseIterable, Sendable, Codable {
    case localUser
    case conversationPartner
}

enum SessionFailure: Equatable, Sendable {
    case appConfigurationMissing
    case workerSecretMismatch
    case workerUnavailable
    case bootstrapContractDrift
    case workerFailed
    case microphonePermissionDenied
    case audioSessionFailed
    case realtimeTransportFailed
    case reconnectExhausted
}

enum ConnectionState: Equatable, Sendable {
    case idle
    case bootstrapping
    case ready
    case paused
    case reconnecting(Int)
    case failed(SessionFailure)
}

struct TeleprompterLine: Identifiable, Hashable, Sendable {
    let id: UUID
    let text: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        text: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
    }
}

struct ConversationSession: Sendable {
    var activeSpeaker: ActiveSpeaker = .localUser
    var connectionState: ConnectionState = .idle
    var statusMessage: String = "Ready when you are."
    var sessionId: String?

    private(set) var localInputText: String = "Listening."
    private(set) var localInputSecondaryText: String = "English in."
    private(set) var partnerInputText: String = "聞いています。"
    private(set) var partnerInputSecondaryText: String = "Japanese in."
    private(set) var localOutputLines: [TeleprompterLine] = []
    private(set) var partnerOutputLines: [TeleprompterLine] = []
    private(set) var localLiveOutputText: String = ""
    private(set) var partnerLiveOutputText: String = ""

    init(
        activeSpeaker: ActiveSpeaker = .localUser,
        connectionState: ConnectionState = .idle,
        statusMessage: String = "Ready when you are."
    ) {
        self.activeSpeaker = activeSpeaker
        self.connectionState = connectionState
        self.statusMessage = statusMessage
        resetLiveSurfaceCopy()
    }

    var directionLabel: String {
        switch activeSpeaker {
        case .localUser:
            return "EN → JA"
        case .conversationPartner:
            return "JA → EN"
        }
    }

    var outputSpeaker: ActiveSpeaker {
        activeSpeaker == .localUser ? .conversationPartner : .localUser
    }

    mutating func selectSpeaker(_ speaker: ActiveSpeaker) {
        guard activeSpeaker != speaker else { return }
        activeSpeaker = speaker
        resetLiveSurfaceCopy()
    }

    mutating func resetForNewConversation() {
        sessionId = nil
        localOutputLines = []
        partnerOutputLines = []
        localLiveOutputText = ""
        partnerLiveOutputText = ""
        resetLiveSurfaceCopy()
    }

    mutating func updateInputTranscript(_ transcript: String, for speaker: ActiveSpeaker) {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)

        switch speaker {
        case .localUser:
            localInputText = trimmed.isEmpty ? "Listening." : trimmed
            localInputSecondaryText = "English in."
        case .conversationPartner:
            partnerInputText = trimmed.isEmpty ? "聞いています。" : trimmed
            partnerInputSecondaryText = "Japanese in."
        }
    }

    mutating func finalizeInputTranscript(_ transcript: String, for speaker: ActiveSpeaker) {
        updateInputTranscript(transcript, for: speaker)
    }

    mutating func clearInputTranscript(for speaker: ActiveSpeaker) {
        switch speaker {
        case .localUser:
            localInputText = "Listening."
            localInputSecondaryText = "English in."
        case .conversationPartner:
            partnerInputText = "聞いています。"
            partnerInputSecondaryText = "Japanese in."
        }
    }

    mutating func updateLiveOutput(_ text: String, for speaker: ActiveSpeaker) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        switch speaker {
        case .localUser:
            localLiveOutputText = trimmed
        case .conversationPartner:
            partnerLiveOutputText = trimmed
        }
    }

    mutating func commitOutput(_ text: String, for speaker: ActiveSpeaker) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        switch speaker {
        case .localUser:
            localOutputLines.append(TeleprompterLine(text: trimmed))
            localLiveOutputText = ""
        case .conversationPartner:
            partnerOutputLines.append(TeleprompterLine(text: trimmed))
            partnerLiveOutputText = ""
        }
    }

    mutating func clearLiveOutput(for speaker: ActiveSpeaker) {
        switch speaker {
        case .localUser:
            localLiveOutputText = ""
        case .conversationPartner:
            partnerLiveOutputText = ""
        }
    }

    func inputText(for speaker: ActiveSpeaker) -> String {
        switch speaker {
        case .localUser:
            return localInputText
        case .conversationPartner:
            return partnerInputText
        }
    }

    func inputSecondaryText(for speaker: ActiveSpeaker) -> String {
        switch speaker {
        case .localUser:
            return localInputSecondaryText
        case .conversationPartner:
            return partnerInputSecondaryText
        }
    }

    func outputLines(for speaker: ActiveSpeaker) -> [TeleprompterLine] {
        switch speaker {
        case .localUser:
            return localOutputLines
        case .conversationPartner:
            return partnerOutputLines
        }
    }

    func liveOutputText(for speaker: ActiveSpeaker) -> String {
        switch speaker {
        case .localUser:
            return localLiveOutputText
        case .conversationPartner:
            return partnerLiveOutputText
        }
    }

    private mutating func resetLiveSurfaceCopy() {
        clearInputTranscript(for: .localUser)
        clearInputTranscript(for: .conversationPartner)
        clearLiveOutput(for: .localUser)
        clearLiveOutput(for: .conversationPartner)
    }
}
