import Foundation

actor ConversationStore {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager: FileManager
    private let storageDirectoryName: String
    private let storageFileName: String
    private let explicitStorageURL: URL?

    init(
        fileManager: FileManager = .default,
        storageDirectoryName: String = "ConversationHistory",
        storageFileName: String = "threads.json",
        storageURL: URL? = nil
    ) {
        self.fileManager = fileManager
        self.storageDirectoryName = storageDirectoryName
        self.storageFileName = storageFileName
        self.explicitStorageURL = storageURL

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func loadThreads() -> [ConversationThread] {
        guard let fileURL = storageURL() else {
            return []
        }

        guard let data = try? Data(contentsOf: fileURL) else {
            return []
        }

        if let document = try? decoder.decode(ConversationHistoryDocument.self, from: data) {
            return normalized(document.threads)
        }

        // Backward compatibility for the first raw-array format.
        if let legacyThreads = try? decoder.decode([ConversationThread].self, from: data) {
            let threads = normalized(legacyThreads)
            saveThreads(threads)
            return threads
        }

        return []
    }

    func saveThreads(_ threads: [ConversationThread]) {
        guard let fileURL = storageURL() else { return }

        do {
            let parentDirectory = fileURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: parentDirectory, withIntermediateDirectories: true, attributes: nil)
            try markStorageDirectoryExcludedFromBackup(parentDirectory)

            let document = ConversationHistoryDocument(threads: normalized(threads))
            let data = try encoder.encode(document)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            #if DEBUG
            print("ConversationStore save failed: \(error)")
            #endif
        }
    }

    func appendThread(_ thread: ConversationThread) {
        var threads = loadThreads()
        threads.insert(thread, at: 0)
        saveThreads(threads)
    }

    func deleteAllThreads() {
        guard let fileURL = storageURL(), fileManager.fileExists(atPath: fileURL.path) else {
            return
        }

        do {
            try fileManager.removeItem(at: fileURL)
        } catch {
            #if DEBUG
            print("ConversationStore delete failed: \(error)")
            #endif
        }
    }

    private func storageURL() -> URL? {
        if let explicitStorageURL {
            return explicitStorageURL
        }

        guard let directory = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else {
            return nil
        }

        return directory
            .appendingPathComponent(storageDirectoryName, isDirectory: true)
            .appendingPathComponent(storageFileName, isDirectory: false)
    }

    private func normalized(_ threads: [ConversationThread]) -> [ConversationThread] {
        threads
            .filter(\.hasTranscript)
            .sorted { $0.startedAt > $1.startedAt }
    }

    private func markStorageDirectoryExcludedFromBackup(_ url: URL) throws {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true

        var mutableURL = url
        try mutableURL.setResourceValues(values)
    }
}
