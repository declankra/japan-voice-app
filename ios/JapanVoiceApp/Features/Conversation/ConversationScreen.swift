import SwiftUI

struct ConversationScreen: View {
    @Environment(AppState.self) private var appState
    @AppStorage("conversation.hasSeenHandoffHint") private var hasSeenHandoffHint = false

    @State private var topDragProgress: CGFloat = 0
    @State private var bottomDragProgress: CGFloat = 0
    @State private var holdProgress: CGFloat = 0
    @State private var isHoldingExit = false
    @State private var transientMessage: String?
    @State private var transientTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { proxy in
            let dividerHeight: CGFloat = 1
            let paneHeight = (proxy.size.height - dividerHeight) / 2

            ZStack {
                VStack(spacing: 0) {
                    speakerPane(
                        title: "Other Person",
                        subtitle: "Japanese speaker",
                        speaker: .conversationPartner,
                        isFlipped: true,
                        size: CGSize(width: proxy.size.width, height: paneHeight),
                        dragProgress: topDragProgress
                    )

                    Rectangle()
                        .fill(AppTheme.divider)
                        .frame(height: dividerHeight)

                    speakerPane(
                        title: "You",
                        subtitle: "English speaker",
                        speaker: .localUser,
                        isFlipped: false,
                        size: CGSize(width: proxy.size.width, height: paneHeight),
                        dragProgress: bottomDragProgress
                    )
                }
                .frame(width: proxy.size.width, height: proxy.size.height)

                centerOverlay
            }
            .background(AppTheme.appBackground)
        }
        .ignoresSafeArea()
        .onDisappear {
            transientTask?.cancel()
            transientTask = nil
        }
    }

    private var centerOverlay: some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text(appState.session.directionLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(AppTheme.primaryText.opacity(0.82))

                Text(displayedStatusMessage)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.statusCapsuleDark)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(AppTheme.statusBorder, lineWidth: 1)
                    )
            )

            ZStack {
                Circle()
                    .trim(from: 0, to: holdProgress)
                    .stroke(
                        AppTheme.primaryText,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 122, height: 122)
                    .opacity(isHoldingExit ? 1 : 0)

                Circle()
                    .fill(AppTheme.controlFill)
                    .frame(width: 108, height: 108)
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.14), lineWidth: 1)
                    )

                Image(systemName: transportSymbolName)
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(Color.black)
            }
            .contentShape(Circle())
            .scaleEffect(isHoldingExit ? 1.03 : 1)
            .animation(.easeOut(duration: 0.18), value: isHoldingExit)
            .onTapGesture {
                appState.togglePause()
            }
            .onLongPressGesture(
                minimumDuration: 1.5,
                maximumDistance: 36,
                pressing: { pressing in
                    isHoldingExit = pressing

                    if pressing {
                        withAnimation(.linear(duration: 1.5)) {
                            holdProgress = 1
                        }
                    } else {
                        withAnimation(.easeOut(duration: 0.18)) {
                            holdProgress = 0
                        }
                    }
                },
                perform: {
                    holdProgress = 0
                    isHoldingExit = false
                    appState.endConversation()
                }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(transportAccessibilityLabel)
            .accessibilityValue(transportAccessibilityValue)
            .accessibilityHint(transportAccessibilityHint)
        }
        .padding(.horizontal, 24)
    }

    private var displayedStatusMessage: String {
        if isHoldingExit {
            return "Release to cancel."
        }

        return transientMessage ?? appState.session.statusMessage
    }

    private var transportSymbolName: String {
        switch appState.session.connectionState {
        case .paused:
            return "play.fill"
        case .ready:
            return "pause.fill"
        case .reconnecting(_):
            return "arrow.clockwise"
        case .failed(_):
            return "xmark"
        case .idle, .bootstrapping:
            return "waveform"
        }
    }

    private var transportAccessibilityLabel: String {
        switch appState.session.connectionState {
        case .paused:
            return "Resume conversation"
        case .ready:
            return "Pause conversation"
        case .idle:
            return "Conversation unavailable"
        case .bootstrapping:
            return "Conversation connecting"
        case .reconnecting(_):
            return "Conversation reconnecting"
        case .failed(_):
            return "Conversation failed"
        }
    }

    private var transportAccessibilityValue: String {
        switch appState.session.connectionState {
        case .paused:
            return "Conversation is paused."
        case .ready:
            return "Conversation is running."
        case .idle:
            return "Conversation has not started."
        case .bootstrapping:
            return "Conversation is connecting."
        case .reconnecting(let attempt):
            return "Conversation is reconnecting. Attempt \(attempt)."
        case .failed(_):
            return appState.session.statusMessage
        }
    }

    private var transportAccessibilityHint: String {
        switch appState.session.connectionState {
        case .paused, .ready:
            return "Double-tap to pause or resume. Long press to end the conversation."
        case .idle:
            return "Start a conversation before using this control."
        case .bootstrapping:
            return "Wait for the shell to finish connecting."
        case .reconnecting(_):
            return "Wait for the shell to reconnect."
        case .failed(_):
            return "Return home and restart the shell."
        }
    }

    private func speakerPane(
        title: String,
        subtitle: String,
        speaker: ActiveSpeaker,
        isFlipped: Bool,
        size: CGSize,
        dragProgress: CGFloat
    ) -> some View {
        let isActive = appState.session.activeSpeaker == speaker
        let background = isActive ? AppTheme.activePane : AppTheme.inactivePane
        let primary = isActive ? AppTheme.activePaneText : AppTheme.inactivePaneText
        let secondary = isActive ? AppTheme.activePaneSecondaryText : AppTheme.inactivePaneSecondaryText
        let handoffSymbol = isFlipped ? "chevron.down" : "chevron.up"
        let alignment: HorizontalAlignment = isFlipped ? .trailing : .leading
        let textAlignment: TextAlignment = isFlipped ? .trailing : .leading

        return ZStack {
            background

            VStack(alignment: alignment, spacing: 12) {
                if isFlipped {
                    hintBadge(primary: primary, isActive: isActive, handoffSymbol: handoffSymbol, dragProgress: dragProgress)
                    Spacer(minLength: 0)
                    metadataBlock(title: title, subtitle: subtitle, secondary: secondary, alignment: alignment)
                    heroBlock(
                        speaker: speaker,
                        isActive: isActive,
                        secondary: secondary,
                        textAlignment: textAlignment,
                        alignment: alignment
                    )
                } else {
                    metadataBlock(title: title, subtitle: subtitle, secondary: secondary, alignment: alignment)
                    hintBadge(primary: primary, isActive: isActive, handoffSymbol: handoffSymbol, dragProgress: dragProgress)
                    Spacer(minLength: 0)
                    heroBlock(
                        speaker: speaker,
                        isActive: isActive,
                        secondary: secondary,
                        textAlignment: textAlignment,
                        alignment: alignment
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 28)
            .padding(.vertical, 26)
            .foregroundStyle(primary)
            .rotationEffect(isFlipped ? .degrees(180) : .zero)
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        .onTapGesture {
            appState.selectSpeaker(speaker)
        }
        .gesture(handoffGesture(for: speaker, isFlipped: isFlipped, height: size.height))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(isActive ? "Listening surface" : "Output surface"), \(speakerLanguage(for: speaker))")
        .accessibilityValue(isActive ? "Selected." : "Not selected.")
        .accessibilityHint("Double-tap to make \(title) active. Swipe \(isFlipped ? "down" : "up") to hand off.")
        .accessibilityAddTraits(isActive ? .isSelected : AccessibilityTraits())
    }

    private func handoffGesture(for speaker: ActiveSpeaker, isFlipped: Bool, height: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard appState.session.activeSpeaker == speaker else {
                    return
                }

                let normalized = normalizedProgress(for: value.translation.height, isFlipped: isFlipped, height: height)
                setDragProgress(normalized, for: speaker)
            }
            .onEnded { value in
                defer {
                    setDragProgress(0, for: speaker)
                }

                guard appState.session.activeSpeaker == speaker else {
                    return
                }

                switch appState.session.connectionState {
                case .bootstrapping:
                    showTransientMessage("Connecting…")
                    return
                case .reconnecting(_):
                    showTransientMessage("Reconnecting…")
                    return
                case .idle, .ready, .paused, .failed(_):
                    break
                }

                let normalized = normalizedProgress(for: value.translation.height, isFlipped: isFlipped, height: height)

                guard normalized >= 0.4 else {
                    return
                }

                hasSeenHandoffHint = true
                appState.selectSpeaker(oppositeSpeaker(for: speaker))
            }
    }

    private func normalizedProgress(for translationHeight: CGFloat, isFlipped: Bool, height: CGFloat) -> CGFloat {
        guard height > 0 else { return 0 }

        let distance = isFlipped ? translationHeight : -translationHeight
        return max(0, min(distance / height, 1))
    }

    private func setDragProgress(_ progress: CGFloat, for speaker: ActiveSpeaker) {
        if speaker == .conversationPartner {
            topDragProgress = progress
        } else {
            bottomDragProgress = progress
        }
    }

    private func oppositeSpeaker(for speaker: ActiveSpeaker) -> ActiveSpeaker {
        speaker == .localUser ? .conversationPartner : .localUser
    }

    private func speakerLanguage(for speaker: ActiveSpeaker) -> String {
        speaker == .localUser ? "English" : "Japanese"
    }

    private func primaryPaneCopy(for speaker: ActiveSpeaker, isActive: Bool) -> String {
        switch speaker {
        case .localUser:
            return appState.session.localPrimaryText
        case .conversationPartner:
            return appState.session.partnerPrimaryText
        }
    }

    private func secondaryPaneCopy(for speaker: ActiveSpeaker, isActive: Bool) -> String {
        switch speaker {
        case .localUser:
            return appState.session.localSecondaryText
        case .conversationPartner:
            return appState.session.partnerSecondaryText
        }
    }

    @ViewBuilder
    private func metadataBlock(
        title: String,
        subtitle: String,
        secondary: Color,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(secondary)

            Text(subtitle)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(secondary)
        }
    }

    @ViewBuilder
    private func heroBlock(
        speaker: ActiveSpeaker,
        isActive: Bool,
        secondary: Color,
        textAlignment: TextAlignment,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 10) {
            Text(primaryPaneCopy(for: speaker, isActive: isActive))
                .font(.system(size: 52, weight: .medium))
                .minimumScaleFactor(0.56)
                .lineLimit(2)
                .multilineTextAlignment(textAlignment)

            Text(secondaryPaneCopy(for: speaker, isActive: isActive))
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(secondary)
                .multilineTextAlignment(textAlignment)
        }
    }

    @ViewBuilder
    private func hintBadge(
        primary: Color,
        isActive: Bool,
        handoffSymbol: String,
        dragProgress: CGFloat
    ) -> some View {
        if isActive && !hasSeenHandoffHint {
            HStack(spacing: 8) {
                Image(systemName: handoffSymbol)
                Text("Swipe to hand off")
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(primary.opacity(0.82))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(AppTheme.statusCapsuleLight)
            )
            .overlay(
                Capsule()
                    .stroke(primary.opacity(0.12), lineWidth: 1)
            )
            .opacity(0.58 + (dragProgress * 0.42))
        }
    }

    private func showTransientMessage(_ message: String) {
        transientTask?.cancel()
        transientMessage = message

        transientTask = Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                transientMessage = nil
            }
        }
    }
}
