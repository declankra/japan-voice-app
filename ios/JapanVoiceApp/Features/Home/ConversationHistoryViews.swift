import SwiftUI

struct ConversationHistoryListSection: View {
    let threads: [ConversationThread]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Conversation history")
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(AppTheme.tertiaryText)

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(threads) { thread in
                        NavigationLink(value: thread) {
                            HistoryThreadRow(thread: thread)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 224)
        }
    }
}

struct ConversationTranscriptDetailScreen: View {
    let thread: ConversationThread

    var body: some View {
        ZStack {
            AppTheme.appBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    transcriptHeader

                    LazyVStack(spacing: 24) {
                        ForEach(thread.turns) { turn in
                            TranscriptTurnRow(turn: turn)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(thread.startedAt.formatted(.dateTime.month(.abbreviated).day()))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var transcriptHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(thread.startedAt.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .tracking(-0.4)

            Text(thread.startedAt.formatted(.dateTime.hour().minute()) + " – " + thread.endedAt.formatted(.dateTime.hour().minute()))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)

            Text("\(thread.turns.count) turns")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(AppTheme.tertiaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
    }
}

private struct HistoryThreadRow: View {
    let thread: ConversationThread

    var body: some View {
        Text(thread.startedAt.formatted(Self.dateFormatter))
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(AppTheme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .padding(.vertical, 12)
    }

    private static let dateFormatter: Date.FormatStyle = .dateTime
        .month(.abbreviated)
        .day()
        .hour(.defaultDigits(amPM: .abbreviated))
        .minute()
}

private struct TranscriptTurnRow: View {
    let turn: ConversationTurn

    var body: some View {
        let isLocal = turn.speaker == .localUser
        let horizontal: HorizontalAlignment = isLocal ? .leading : .trailing
        let frameAlignment: Alignment = isLocal ? .leading : .trailing
        let textAlignment: TextAlignment = isLocal ? .leading : .trailing

        VStack(alignment: horizontal, spacing: 8) {
            Text(isLocal ? "You spoke" : "Other person spoke")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(AppTheme.tertiaryText)
                .frame(maxWidth: .infinity, alignment: frameAlignment)

            Text(turn.sourceText)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(AppTheme.primaryText.opacity(0.92))
                .multilineTextAlignment(textAlignment)
                .frame(maxWidth: .infinity, alignment: frameAlignment)

            Text(turn.translatedText)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(textAlignment)
                .frame(maxWidth: .infinity, alignment: frameAlignment)
        }
    }
}
