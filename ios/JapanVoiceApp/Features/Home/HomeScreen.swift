import SwiftUI

struct HomeScreen: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            AppTheme.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Text("Japan Voice")
                    .font(.system(size: 44, weight: .medium, design: .default))
                    .foregroundStyle(AppTheme.primaryText)
                    .tracking(-1.4)
                    .accessibilityAddTraits(.isHeader)

                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.top, 68)
            .padding(.bottom, 30)

            VStack(spacing: 0) {
                Spacer()

                if appState.conversationHistory.isEmpty {
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
                } else {
                    ConversationHistoryListSection(threads: appState.conversationHistory)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 30)

            startConversationButton
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .ignoresSafeArea()
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var startConversationButton: some View {
        Button {
            appState.startConversation()
        } label: {
            ZStack {
                Circle()
                    .stroke(AppTheme.controlFill, lineWidth: 3)
                    .frame(
                        width: AppTheme.transportControlDiameter,
                        height: AppTheme.transportControlDiameter
                    )

                Image(systemName: "waveform")
                    .font(.system(size: AppTheme.transportControlIconSize, weight: .medium))
                    .foregroundStyle(AppTheme.controlFill)
            }
            .frame(
                width: AppTheme.transportControlHitDiameter,
                height: AppTheme.transportControlHitDiameter
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start conversation")
        .accessibilityHint("Opens the shared translation surface.")
    }
}
