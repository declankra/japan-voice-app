import SwiftUI

struct ConversationHistoryListSection: View {
    let threads: [ConversationThread]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Conversation history")
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(AppTheme.tertiaryText)

            ZStack(alignment: .top) {
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(threads) { thread in
                            NavigationLink(value: thread) {
                                HistoryThreadRow(thread: thread)
                            }
                            .buttonStyle(.plain)

                            if thread.id != threads.last?.id {
                                Rectangle()
                                    .fill(AppTheme.divider)
                                    .frame(height: 1)
                                    .padding(.vertical, 2)
                            }
                        }
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 32)
                }

                ConversationScrollBlurOverlay()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 224)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AppTheme.statusCapsuleDark)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(AppTheme.statusBorder, lineWidth: 1)
                    )
            )
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
            .overlay(alignment: .top) {
                ConversationScrollBlurOverlay()
            }
        }
        .navigationTitle(thread.startedAt.formatted(.dateTime.month(.abbreviated).day()))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var transcriptHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(thread.startedAt.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(AppTheme.primaryText)
                .tracking(-0.8)

            Text(thread.startedAt.formatted(.dateTime.hour().minute()) + " - " + thread.endedAt.formatted(.dateTime.hour().minute()))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)

            Text("\(thread.turns.count) turns")
                .font(.system(size: 12, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(AppTheme.tertiaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 18)
    }
}

private struct HistoryThreadRow: View {
    let thread: ConversationThread

    var body: some View {
        Text(thread.startedAt.formatted(Self.dateFormatter))
            .font(.system(size: 22, weight: .regular))
            .foregroundStyle(AppTheme.secondaryText)
            .tracking(-0.4)
            .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
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
        VStack(alignment: turn.speaker == .localUser ? .leading : .trailing, spacing: 10) {
            Text(turn.speaker == .localUser ? "You spoke" : "Other person spoke")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(AppTheme.tertiaryText)
                .frame(maxWidth: .infinity, alignment: turn.speaker == .localUser ? .leading : .trailing)

            VStack(alignment: turn.speaker == .localUser ? .leading : .trailing, spacing: 8) {
                Text(turn.sourceText)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText.opacity(0.92))
                    .multilineTextAlignment(turn.speaker == .localUser ? .leading : .trailing)
                    .frame(maxWidth: .infinity, alignment: turn.speaker == .localUser ? .leading : .trailing)

                Text(turn.translatedText)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(turn.speaker == .localUser ? .leading : .trailing)
                    .frame(maxWidth: .infinity, alignment: turn.speaker == .localUser ? .leading : .trailing)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AppTheme.statusCapsuleDark)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(AppTheme.statusBorder, lineWidth: 1)
                    )
            )
        }
    }
}

private struct ConversationScrollBlurOverlay: View {
    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .frame(height: 56)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: 0.4),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [
                        AppTheme.appBackground.opacity(0.95),
                        AppTheme.appBackground.opacity(0.75),
                        AppTheme.appBackground.opacity(0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .allowsHitTesting(false)
    }
}
