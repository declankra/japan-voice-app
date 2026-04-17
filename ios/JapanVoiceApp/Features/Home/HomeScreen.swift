import SwiftUI

struct HomeScreen: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.backgroundStart, AppTheme.backgroundEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Text("Japan Voice")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                Text("Split-screen realtime conversation scaffold for one active speaker at a time.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.82))
                    .padding(.horizontal, 32)

                Button {
                    appState.startConversation()
                } label: {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 96))
                        .foregroundStyle(AppTheme.accent)
                }
                .buttonStyle(.plain)

                Text("Start Conversation")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Text("Worker bootstrap is stubbed. Audio and translation are intentionally not wired yet.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 28)
            }
        }
    }
}
