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

    var body: some View {
        Group {
            switch appState.screen {
            case .home:
                HomeScreen()
            case .conversation:
                ConversationScreen()
            }
        }
    }
}
