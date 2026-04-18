import Foundation

enum ActiveSpeaker: String, CaseIterable, Sendable {
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

struct ConversationSession: Sendable {
    var activeSpeaker: ActiveSpeaker = .localUser
    var connectionState: ConnectionState = .idle
    var statusMessage: String = "Ready when you are."
    var sessionId: String?
    var localPrimaryText: String = "Listening."
    var localSecondaryText: String = "English in."
    var partnerPrimaryText: String = "日本語."
    var partnerSecondaryText: String = "Translated output."

    init(
        activeSpeaker: ActiveSpeaker = .localUser,
        connectionState: ConnectionState = .idle,
        statusMessage: String = "Ready when you are."
    ) {
        self.activeSpeaker = activeSpeaker
        self.connectionState = connectionState
        self.statusMessage = statusMessage
        resetSurfaceCopy()
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
        resetSurfaceCopy()
    }

    mutating func applyInputTranscript(_ transcript: String) {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)

        switch activeSpeaker {
        case .localUser:
            localPrimaryText = trimmed.isEmpty ? "Listening." : trimmed
            localSecondaryText = "English in."
        case .conversationPartner:
            partnerPrimaryText = trimmed.isEmpty ? "聞いています。" : trimmed
            partnerSecondaryText = "Japanese in."
        }
    }

    mutating func applyTranslatedOutput(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        switch outputSpeaker {
        case .localUser:
            localPrimaryText = trimmed.isEmpty ? "English." : trimmed
            localSecondaryText = "Translated output."
        case .conversationPartner:
            partnerPrimaryText = trimmed.isEmpty ? "日本語." : trimmed
            partnerSecondaryText = "Translated output."
        }
    }

    mutating func resetSurfaceCopy() {
        switch activeSpeaker {
        case .localUser:
            localPrimaryText = "Listening."
            localSecondaryText = "English in."
            partnerPrimaryText = "日本語."
            partnerSecondaryText = "Translated output."
        case .conversationPartner:
            partnerPrimaryText = "聞いています。"
            partnerSecondaryText = "Japanese in."
            localPrimaryText = "English."
            localSecondaryText = "Translated output."
        }
    }
}
