import SwiftUI

struct ConversationScreen: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("conversation.hasSeenHandoffHint") private var hasSeenHandoffHint = false

    @State private var topDragProgress: CGFloat = 0
    @State private var bottomDragProgress: CGFloat = 0
    @State private var holdProgress: CGFloat = 0
    @State private var isHoldingExit = false
    @State private var transientMessage: String?
    @State private var transientTask: Task<Void, Never>?

    private let teleprompterLiveId = "teleprompter-live-output"
    private let handoffCommitThreshold: CGFloat = 0.4

    var body: some View {
        GeometryReader { proxy in
            let dividerHeight: CGFloat = 1
            let paneHeight = (proxy.size.height - dividerHeight) / 2
            let safeAreaInsets = proxy.safeAreaInsets
            let activeDragProgress = max(topDragProgress, bottomDragProgress)
            let handoffProgress = handoffVisualProgress(for: activeDragProgress)
            let isHandoffArmed = activeDragProgress >= handoffCommitThreshold

            ZStack {
                VStack(spacing: 0) {
                    speakerPane(
                        title: "Japanese reader",
                        speaker: .conversationPartner,
                        isFlipped: true,
                        size: CGSize(width: proxy.size.width, height: paneHeight),
                        dragProgress: topDragProgress,
                        contentInsets: paneContentInsets(isFlipped: true, safeAreaInsets: safeAreaInsets)
                    )

                    centerDivider(progress: handoffProgress, isArmed: isHandoffArmed)
                        .frame(height: dividerHeight)

                    speakerPane(
                        title: "English reader",
                        speaker: .localUser,
                        isFlipped: false,
                        size: CGSize(width: proxy.size.width, height: paneHeight),
                        dragProgress: bottomDragProgress,
                        contentInsets: paneContentInsets(isFlipped: false, safeAreaInsets: safeAreaInsets)
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
        ZStack {
            if shouldShowTransportStatus {
                transportStatus
                    .offset(y: AppTheme.transportStatusVerticalOffset)
            }

            transportControl
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    private var transportStatus: some View {
        VStack(spacing: 4) {
            Text(appState.session.directionLabel)
                .font(.system(size: 12, weight: .semibold))
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
    }

    private var transportControl: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: holdProgress)
                .stroke(
                    AppTheme.primaryText,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(
                    width: AppTheme.transportControlProgressDiameter,
                    height: AppTheme.transportControlProgressDiameter
                )
                .opacity(isHoldingExit ? 1 : 0)

            Circle()
                .fill(AppTheme.controlFill)
                .frame(
                    width: AppTheme.transportControlDiameter,
                    height: AppTheme.transportControlDiameter
                )
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.14), lineWidth: 1)
                )

            transportIcon
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
        .accessibilityAddTraits(.isButton)
    }

    private var displayedStatusMessage: String {
        if isHoldingExit {
            return "Release to cancel."
        }

        return transientMessage ?? appState.session.statusMessage
    }

    private var shouldShowTransportStatus: Bool {
        if isHoldingExit || transientMessage != nil {
            return true
        }

        switch appState.session.connectionState {
        case .ready:
            return false
        case .idle, .bootstrapping, .paused, .reconnecting(_), .failed(_):
            return true
        }
    }

    private var transportSymbolName: String {
        switch appState.session.connectionState {
        case .paused:
            return "play.fill"
        case .ready:
            return "waveform"
        case .reconnecting(_):
            return "arrow.clockwise"
        case .failed(_):
            return "xmark"
        case .idle, .bootstrapping:
            return "waveform"
        }
    }

    private var shouldAnimateLiveTransportIcon: Bool {
        appState.session.connectionState == .ready && !isHoldingExit && !reduceMotion
    }

    private var transportIcon: some View {
        Image(systemName: transportSymbolName)
            .font(.system(size: AppTheme.transportControlIconSize, weight: .medium))
            .foregroundStyle(Color.black)
            .symbolEffect(.pulse, options: .repeating, isActive: shouldAnimateLiveTransportIcon)
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

    @ViewBuilder
    private func speakerPane(
        title: String,
        speaker: ActiveSpeaker,
        isFlipped: Bool,
        size: CGSize,
        dragProgress: CGFloat,
        contentInsets: EdgeInsets
    ) -> some View {
        let isActive = appState.session.activeSpeaker == speaker
        let background = isActive ? AppTheme.activePane : AppTheme.inactivePane
        let primary = isActive ? AppTheme.activePaneText : AppTheme.inactivePaneText
        let secondary = isActive ? AppTheme.activePaneSecondaryText : AppTheme.inactivePaneSecondaryText
        let handoffSymbol = isFlipped ? "chevron.down" : "chevron.up"
        let alignment: HorizontalAlignment = isFlipped ? .trailing : .leading
        let textAlignment: TextAlignment = isFlipped ? .trailing : .leading

        let pane = ZStack {
            background

            VStack(alignment: alignment, spacing: 14) {
                surfaceContentBlock(
                    speaker: speaker,
                    isActive: isActive,
                    handoffSymbol: handoffSymbol,
                    dragProgress: dragProgress,
                    primary: primary,
                    secondary: secondary,
                    textAlignment: textAlignment,
                    alignment: alignment
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(contentInsets)
            .foregroundStyle(primary)
            .rotationEffect(isFlipped ? .degrees(180) : .zero)
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        .onTapGesture {
            hasSeenHandoffHint = true
            appState.selectSpeaker(oppositeSpeaker(for: appState.session.activeSpeaker))
        }

        Group {
            if isActive {
                pane.gesture(handoffGesture(for: speaker, isFlipped: isFlipped, height: size.height))
            } else {
                pane
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(isActive ? "Listening surface" : "Output surface"), \(speakerLanguage(for: speaker))")
        .accessibilityValue(isActive ? "Selected." : "Not selected.")
        .accessibilityHint("Double-tap to switch who the app listens for. Swipe \(isFlipped ? "down" : "up") from the active side to hand off.")
        .accessibilityAddTraits(isActive ? .isSelected : AccessibilityTraits())
    }

    private func paneContentInsets(isFlipped: Bool, safeAreaInsets: EdgeInsets) -> EdgeInsets {
        let horizontalInset: CGFloat = 24
        let verticalInset: CGFloat = 20
        let screenEdgeInset = max(
            verticalInset,
            (isFlipped ? safeAreaInsets.top : safeAreaInsets.bottom) + 12
        )

        // The upper pane is rotated 180°, so extra clearance for the screen edge
        // must be applied to the pre-rotation bottom inset.
        return EdgeInsets(
            top: verticalInset,
            leading: horizontalInset,
            bottom: screenEdgeInset,
            trailing: horizontalInset
        )
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
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
                        setDragProgress(0, for: speaker)
                    }
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

                guard normalized >= handoffCommitThreshold else {
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

    private func handoffVisualProgress(for dragProgress: CGFloat) -> CGFloat {
        min(max(dragProgress / handoffCommitThreshold, 0), 1)
    }

    private func centerDivider(progress: CGFloat, isArmed: Bool) -> some View {
        Rectangle()
            .fill(AppTheme.divider)
            .overlay {
                Capsule()
                    .fill(AppTheme.primaryText.opacity(progress * 0.46))
                    .frame(height: 1 + (progress * (isArmed ? 3.5 : 2.5)))
                    .shadow(
                        color: AppTheme.primaryText.opacity(isArmed ? 0.18 : 0),
                        radius: isArmed ? 5 : 0
                    )
            }
            .animation(.spring(response: 0.18, dampingFraction: 0.82), value: isArmed)
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

    private func listeningLabel(for speaker: ActiveSpeaker) -> String {
        speaker == .localUser ? "Listening" : "聞き取り中"
    }

    @ViewBuilder
    private func surfaceContentBlock(
        speaker: ActiveSpeaker,
        isActive: Bool,
        handoffSymbol: String,
        dragProgress: CGFloat,
        primary: Color,
        secondary: Color,
        textAlignment: TextAlignment,
        alignment: HorizontalAlignment
    ) -> some View {
        if isActive {
            activeInputBlock(
                speaker: speaker,
                handoffSymbol: handoffSymbol,
                dragProgress: dragProgress,
                primary: primary,
                secondary: secondary,
                textAlignment: textAlignment,
                alignment: alignment
            )
        } else {
            teleprompterBlock(
                speaker: speaker,
                primary: primary,
                textAlignment: textAlignment,
                alignment: alignment
            )
        }
    }

    @ViewBuilder
    private func activeInputBlock(
        speaker: ActiveSpeaker,
        handoffSymbol: String,
        dragProgress: CGFloat,
        primary: Color,
        secondary: Color,
        textAlignment: TextAlignment,
        alignment: HorizontalAlignment
    ) -> some View {
        let inputText = appState.session.inputText(for: speaker)
        let frameAlignment: Alignment = alignment == .trailing ? .bottomTrailing : .bottomLeading
        let textFrameAlignment: Alignment = textAlignment == .leading ? .leading : .trailing
        let handoffProgress = handoffVisualProgress(for: dragProgress)
        let isHandoffArmed = dragProgress >= handoffCommitThreshold
        let pullDistance: CGFloat = 26 * handoffProgress

        VStack(alignment: alignment, spacing: 12) {
            HStack(spacing: 8) {
                if !hasSeenHandoffHint {
                    Image(systemName: handoffSymbol)
                        .opacity(0.58 + (dragProgress * 0.42))
                }

                Text(listeningLabel(for: speaker))
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(secondary)
            .multilineTextAlignment(textAlignment)
            .frame(maxWidth: .infinity, alignment: textFrameAlignment)

            Text(inputText)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(primary.opacity(0.72))
                .multilineTextAlignment(textAlignment)
                .lineLimit(4)
                .minimumScaleFactor(0.62)
                .frame(maxWidth: .infinity, alignment: textFrameAlignment)

            Capsule()
                .fill(secondary.opacity(0.35 + (handoffProgress * 0.24)))
                .frame(width: 46 + (handoffProgress * 18), height: 3 + handoffProgress)
                .frame(maxWidth: .infinity, alignment: textFrameAlignment)
        }
        .opacity(0.58 + (handoffProgress * 0.14))
        .offset(y: -pullDistance)
        .animation(.spring(response: 0.18, dampingFraction: 0.82), value: isHandoffArmed)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: frameAlignment)
    }

    @ViewBuilder
    private func teleprompterBlock(
        speaker: ActiveSpeaker,
        primary: Color,
        textAlignment: TextAlignment,
        alignment: HorizontalAlignment
    ) -> some View {
        let committedLines = appState.session.outputLines(for: speaker)
        let liveOutputText = appState.session.liveOutputText(for: speaker)
        let latestCommittedLineID = committedLines.last?.id
        let hasAnyOutput = !committedLines.isEmpty || !liveOutputText.isEmpty
        let frameAlignment: Alignment = alignment == .trailing ? .bottomTrailing : .bottomLeading
        let textFrameAlignment: Alignment = textAlignment == .leading ? .leading : .trailing

        if !hasAnyOutput {
            idleTeleprompterBaselines(
                primary: primary,
                alignment: alignment,
                frameAlignment: frameAlignment,
                textFrameAlignment: textFrameAlignment
            )
        } else {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: alignment, spacing: 14) {
                        ForEach(Array(committedLines.enumerated()), id: \.element.id) { index, line in
                            let distanceFromLatest = CGFloat(committedLines.count - 1 - index)
                            let opacity = max(0.42, 1 - (distanceFromLatest * 0.14))

                            Text(line.text)
                                .font(.system(size: 24, weight: .regular))
                                .foregroundStyle(primary.opacity(opacity))
                                .multilineTextAlignment(textAlignment)
                                .lineLimit(3)
                                .minimumScaleFactor(0.78)
                                .frame(maxWidth: .infinity, alignment: textFrameAlignment)
                                .id(line.id)
                        }

                        if !liveOutputText.isEmpty {
                            Text(liveOutputText)
                                .font(.system(size: 42, weight: .semibold))
                                .foregroundStyle(primary)
                                .multilineTextAlignment(textAlignment)
                                .lineLimit(5)
                                .minimumScaleFactor(0.56)
                                .frame(maxWidth: .infinity, alignment: textFrameAlignment)
                                .id(teleprompterLiveId)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: textFrameAlignment)
                    .padding(.vertical, 4)
                }
                .defaultScrollAnchor(.bottom)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onChange(of: liveOutputText) { _, newValue in
                    guard !newValue.isEmpty else {
                        return
                    }

                    scrollTeleprompterToLatest(
                        proxy: proxy,
                        latestCommittedLineID: latestCommittedLineID,
                        hasLive: true
                    )
                }
                .onChange(of: committedLines.count) { oldCount, newCount in
                    guard newCount > oldCount else {
                        return
                    }

                    scrollTeleprompterToLatest(
                        proxy: proxy,
                        latestCommittedLineID: latestCommittedLineID,
                        hasLive: !liveOutputText.isEmpty
                    )
                }
            }
        }
    }

    private func idleTeleprompterBaselines(
        primary: Color,
        alignment: HorizontalAlignment,
        frameAlignment: Alignment,
        textFrameAlignment: Alignment
    ) -> some View {
        let widths: [CGFloat] = [220, 164, 112]

        return VStack(alignment: alignment, spacing: 12) {
            ForEach(widths.indices, id: \.self) { index in
                Capsule()
                    .fill(primary.opacity(0.10 - (Double(index) * 0.018)))
                    .frame(maxWidth: widths[index])
                    .frame(height: 2)
                    .frame(maxWidth: .infinity, alignment: textFrameAlignment)
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: frameAlignment)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func scrollTeleprompterToLatest(
        proxy: ScrollViewProxy,
        latestCommittedLineID: TeleprompterLine.ID?,
        hasLive: Bool
    ) {
        var transaction = Transaction()
        transaction.disablesAnimations = true

        withTransaction(transaction) {
            if hasLive {
                proxy.scrollTo(teleprompterLiveId, anchor: .bottom)
            } else if let latestCommittedLineID {
                proxy.scrollTo(latestCommittedLineID, anchor: .bottom)
            }
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
