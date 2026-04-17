import Foundation

enum ActiveSpeaker: String, CaseIterable, Sendable {
    case localUser
    case conversationPartner
}

enum ConnectionState: Equatable, Sendable {
    case idle
    case bootstrapping
    case ready
    case paused
    case failed(String)
}

struct ConversationSession: Sendable {
    var activeSpeaker: ActiveSpeaker = .localUser
    var connectionState: ConnectionState = .idle
    var statusMessage: String = "Select a speaker to drive translation direction."

    var directionLabel: String {
        switch activeSpeaker {
        case .localUser:
            return "EN → JA"
        case .conversationPartner:
            return "JA → EN"
        }
    }
}
