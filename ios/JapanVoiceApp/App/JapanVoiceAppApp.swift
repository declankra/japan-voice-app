import AVFAudio
import SwiftUI

@main
struct JapanVoiceAppApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(appState)
        }
    }
}

private struct AppRootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch appState.screen {
            case .home:
                HomeScreen()
            case .conversation:
                ConversationScreen()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            appState.handleScenePhaseChange(newPhase)
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { notification in
            appState.handleAudioInterruption(notification)
        }
    }
}
