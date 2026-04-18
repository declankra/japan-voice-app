import SwiftUI

struct HomeScreen: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            AppTheme.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 72)

                Text("Japan Voice")
                    .font(.system(size: 44, weight: .medium, design: .default))
                    .foregroundStyle(AppTheme.primaryText)
                    .tracking(-1.4)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                Button {
                    appState.startConversation()
                } label: {
                    ZStack {
                        Circle()
                            .stroke(AppTheme.controlFill, lineWidth: 3)
                            .frame(width: 148, height: 148)

                        Image(systemName: "waveform")
                            .font(.system(size: 42, weight: .medium))
                            .foregroundStyle(AppTheme.controlFill)
                    }
                    .frame(width: 180, height: 180)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Start conversation")
                .accessibilityHint("Opens the shared translation surface.")

                Spacer()

                VStack(spacing: 10) {
                    Text("Tap to begin")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(AppTheme.primaryText)

                    Text("Live bilingual conversation, routed through a minimal shared surface.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(AppTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 36)
                }
                .padding(.bottom, 34)
            }
            .padding(.horizontal, 28)
        }
    }
}
