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

    private let teleprompterLiveId = "teleprompter-live-output"

    var body: some View {
        GeometryReader { proxy in
            let dividerHeight: CGFloat = 1
            let paneHeight = (proxy.size.height - dividerHeight) / 2
            let safeAreaInsets = proxy.safeAreaInsets

            ZStack {
                VStack(spacing: 0) {
                    speakerPane(
                        title: "Japanese Speaker",
                        speaker: .conversationPartner,
                        isFlipped: true,
                        size: CGSize(width: proxy.size.width, height: paneHeight),
                        dragProgress: topDragProgress,
                        contentInsets: paneContentInsets(isFlipped: true, safeAreaInsets: safeAreaInsets)
                    )

                    Rectangle()
                        .fill(AppTheme.divider)
                        .frame(height: dividerHeight)

                    speakerPane(
                        title: "English Speaker",
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
            transportStatus
                .offset(y: AppTheme.transportStatusVerticalOffset)

            transportControl
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    private var transportStatus: some View {
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

            Image(systemName: transportSymbolName)
                .font(.system(size: AppTheme.transportControlIconSize, weight: .medium))
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
                headerBlock(
                    title: title,
                    isActive: isActive,
                    primary: primary,
                    secondary: secondary,
                    handoffSymbol: handoffSymbol,
                    dragProgress: dragProgress,
                    alignment: alignment
                )

                surfaceContentBlock(
                    speaker: speaker,
                    isActive: isActive,
                    isFlipped: isFlipped,
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
            appState.selectSpeaker(speaker)
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
        .accessibilityHint("Double-tap to make \(title) active. Swipe \(isFlipped ? "down" : "up") to hand off.")
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

    @ViewBuilder
    private func headerBlock(
        title: String,
        isActive: Bool,
        primary: Color,
        secondary: Color,
        handoffSymbol: String,
        dragProgress: CGFloat,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(secondary)

            if isActive {
                hintBadge(
                    primary: primary,
                    isActive: isActive,
                    handoffSymbol: handoffSymbol,
                    dragProgress: dragProgress
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .trailing ? .trailing : .leading)
    }

    @ViewBuilder
    private func surfaceContentBlock(
        speaker: ActiveSpeaker,
        isActive: Bool,
        isFlipped: Bool,
        primary: Color,
        secondary: Color,
        textAlignment: TextAlignment,
        alignment: HorizontalAlignment
    ) -> some View {
        if isActive {
            activeInputBlock(
                speaker: speaker,
                isFlipped: isFlipped,
                secondary: secondary,
                textAlignment: textAlignment,
                alignment: alignment
            )
        } else {
            teleprompterBlock(
                speaker: speaker,
                isFlipped: isFlipped,
                primary: primary,
                secondary: secondary,
                textAlignment: textAlignment,
                alignment: alignment
            )
        }
    }

    @ViewBuilder
    private func activeInputBlock(
        speaker: ActiveSpeaker,
        isFlipped: Bool,
        secondary: Color,
        textAlignment: TextAlignment,
        alignment: HorizontalAlignment
    ) -> some View {
        let frameAlignment: Alignment = alignment == .trailing ? .bottomTrailing : .bottomLeading
        let textFrameAlignment: Alignment = textAlignment == .leading ? .leading : .trailing
        let readableEdgePadding = isFlipped ? 132.0 : 0

        VStack(alignment: alignment, spacing: 12) {
            Text(appState.session.inputText(for: speaker))
                .font(.system(size: 46, weight: .medium))
                .minimumScaleFactor(0.42)
                .lineLimit(6)
                .multilineTextAlignment(textAlignment)
                .frame(maxWidth: .infinity, alignment: textFrameAlignment)

            Text(appState.session.inputSecondaryText(for: speaker))
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(secondary)
                .multilineTextAlignment(textAlignment)
                .frame(maxWidth: .infinity, alignment: textFrameAlignment)
        }
        .padding(.bottom, readableEdgePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: frameAlignment)
    }

    @ViewBuilder
    private func teleprompterBlock(
        speaker: ActiveSpeaker,
        isFlipped: Bool,
        primary: Color,
        secondary: Color,
        textAlignment: TextAlignment,
        alignment: HorizontalAlignment
    ) -> some View {
        let committedLines = appState.session.outputLines(for: speaker)
        let liveOutputText = appState.session.liveOutputText(for: speaker)
        let latestCommittedLineID = committedLines.last?.id
        let hasAnyOutput = !committedLines.isEmpty || !liveOutputText.isEmpty
        let frameAlignment: Alignment = alignment == .trailing ? .bottomTrailing : .bottomLeading
        let textFrameAlignment: Alignment = textAlignment == .leading ? .leading : .trailing
        let readableEdgePadding = isFlipped ? 132.0 : 0

        if !hasAnyOutput {
            Text("Translation appears here.")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(secondary)
                .multilineTextAlignment(textAlignment)
                .padding(.bottom, readableEdgePadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: frameAlignment)
        } else {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: alignment, spacing: 14) {
                        ForEach(Array(committedLines.enumerated()), id: \.element.id) { index, line in
                            let distanceFromLatest = CGFloat(committedLines.count - 1 - index)
                            let opacity = max(0.5, 1 - (distanceFromLatest * 0.08))

                            Text(line.text)
                                .font(.system(size: 22, weight: .regular))
                                .foregroundStyle(primary.opacity(opacity))
                                .multilineTextAlignment(textAlignment)
                                .frame(maxWidth: .infinity, alignment: textFrameAlignment)
                                .id(line.id)
                        }

                        if !liveOutputText.isEmpty {
                            Text(liveOutputText)
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundStyle(primary)
                                .multilineTextAlignment(textAlignment)
                                .frame(maxWidth: .infinity, alignment: textFrameAlignment)
                                .id(teleprompterLiveId)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: textFrameAlignment)
                    .padding(.vertical, 4)
                    .padding(.bottom, readableEdgePadding)
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
