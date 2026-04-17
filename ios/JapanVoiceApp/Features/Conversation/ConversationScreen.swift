import SwiftUI

struct ConversationScreen: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                HStack(spacing: 0) {
                    speakerPane(
                        title: "You",
                        subtitle: "English speaker",
                        speaker: .localUser,
                        width: proxy.size.width / 2
                    )

                    speakerPane(
                        title: "Other Person",
                        subtitle: "Japanese speaker",
                        speaker: .conversationPartner,
                        width: proxy.size.width / 2
                    )
                }

                VStack(spacing: 18) {
                    Button {
                        appState.togglePause()
                    } label: {
                        Image(systemName: appState.session.connectionState == .paused ? "play.circle.fill" : "pause.circle.fill")
                            .font(.system(size: 68))
                            .foregroundStyle(.white)
                            .padding(18)
                            .background(.black.opacity(0.28), in: Circle())
                    }
                    .buttonStyle(.plain)

                    VStack(spacing: 6) {
                        Text(appState.session.directionLabel)
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text(appState.session.statusMessage)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.82))
                    }

                    Button("End Conversation") {
                        appState.endConversation()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
                }
                .padding(.horizontal, 28)
            }
        }
        .ignoresSafeArea()
    }

    private func speakerPane(title: String, subtitle: String, speaker: ActiveSpeaker, width: CGFloat) -> some View {
        let isActive = appState.session.activeSpeaker == speaker

        return Button {
            appState.selectSpeaker(speaker)
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.title2.weight(.semibold))

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(isActive ? "Listening…" : "Translated text will land here")
                    .font(.headline)
                    .foregroundStyle(isActive ? .secondary : .primary)

                Text(isActive ? "Tap the opposite side to flip translation direction." : "Placeholder transcript output surface.")
                    .font(.body)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(24)
            .frame(width: width, maxHeight: .infinity, alignment: .topLeading)
            .background(isActive ? AppTheme.inactivePanel : AppTheme.activePanel)
            .foregroundStyle(isActive ? Color.black.opacity(0.82) : .white)
        }
        .buttonStyle(.plain)
    }
}
