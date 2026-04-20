import Foundation

struct ConversationTurn: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let speaker: ActiveSpeaker
    let sourceText: String
    let translatedText: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        speaker: ActiveSpeaker,
        sourceText: String,
        translatedText: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.speaker = speaker
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.createdAt = createdAt
    }
}

struct ConversationThread: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date
    let turns: [ConversationTurn]

    init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        turns: [ConversationTurn]
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.turns = turns.sorted { $0.createdAt < $1.createdAt }
    }

    var hasTranscript: Bool {
        !turns.isEmpty
    }
}

struct ConversationHistoryDocument: Codable, Hashable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let threads: [ConversationThread]

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        threads: [ConversationThread]
    ) {
        self.schemaVersion = schemaVersion
        self.threads = threads
    }
}
