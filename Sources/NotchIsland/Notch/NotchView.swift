import SwiftUI

struct NotchView: View {
    let notchSize: CGSize

    @Environment(BatteryMonitor.self) private var battery
    @Environment(NowPlayingMonitor.self) private var nowPlaying
    @Environment(ShelfModel.self) private var shelf
    @Environment(HUDModel.self) private var hud
    @Environment(PanelController.self) private var controller

    @AppStorage(Settings.Key.openOnHover) private var openOnHover = Settings.Default.openOnHover
    @AppStorage(Settings.Key.hoverDelay) private var hoverDelay = Settings.Default.hoverDelay
    @AppStorage(Settings.Key.haptics) private var haptics = Settings.Default.haptics
    @AppStorage(Settings.Key.swipeGestures) private var swipeGestures = Settings.Default.swipeGestures
    @AppStorage(Settings.Key.activityCharging) private var activityCharging = Settings.Default.activityCharging
    @AppStorage(Settings.Key.activityNowPlaying) private var activityNowPlaying = Settings.Default.activityNowPlaying
    @AppStorage(Settings.Key.transparentCollapsed) private var transparentCollapsed = Settings.Default.transparentCollapsed
    @AppStorage(Settings.Key.showPet) private var showPet = Settings.Default.showPet

    @State private var isExpanded = false
    @State private var isHovering = false
    @State private var isDropTargeted = false
    @State private var showCharging = false
    @State private var collapseTask: Task<Void, Never>?
    @State private var openTask: Task<Void, Never>?
    @State private var chargingTask: Task<Void, Never>?

    /// Small info shown on both sides of the notch while collapsed
    private enum Activity: Equatable { case none, hud, charging, nowPlaying }

    private var activity: Activity {
        if hud.event != nil { return .hud }
        if showCharging && activityCharging { return .charging }
        if activityNowPlaying && nowPlaying.isPlaying && nowPlaying.hasMedia { return .nowPlaying }
        return .none
    }

    // Opens with a slight bounce, closes without one (same approach as boring.notch)
    private static let openSpring = Animation.spring(response: 0.42, dampingFraction: 0.8)
    private static let closeSpring = Animation.spring(response: 0.45, dampingFraction: 1.0)

    private var topRadius: CGFloat { isExpanded ? 14 : 6 }
    private var bottomRadius: CGFloat { isExpanded ? 28 : 12 }
    private var activityWidth: CGFloat {
        if let event = hud.event, activity == .hud { return HUDActivity.sideWidth(for: event) }
        return notchSize.height + 8
    }

    /// The cat is not part of the notch: it sits on its own just outside the right edge, with no background
    private static let petSize: CGFloat = 24
    private static let petGap: CGFloat = 6

    /// Shown while collapsed; it never covers the expanded island
    private var petVisible: Bool { showPet && !isExpanded }

    private var petMood: PetMood {
        if battery.hasBattery && battery.level <= 20 && !battery.isPluggedIn { return .tired }
        if nowPlaying.isPlaying && nowPlaying.hasMedia { return .dancing }
        if battery.isCharging { return .happy }
        return .idle
    }

    /// Size of the notch shape: the notch plus the activity wings (symmetric). The pet is not included.
    private var size: CGSize {
        if isExpanded { return NotchGeometry.expandedSize }
        let base = notchSize.width + topRadius * 2
        let width = activity == .none ? base : base + activityWidth * 2
        return CGSize(width: width, height: notchSize.height)
    }

    /// What the window has to cover: the shape, plus room for the pet outside it (kept symmetric around the notch)
    private var windowSize: CGSize {
        guard petVisible else { return size }
        return CGSize(width: size.width + 2 * (Self.petSize + Self.petGap), height: size.height)
    }

    var body: some View {
        let shape = NotchShape(topRadius: topRadius, bottomRadius: bottomRadius)

        ZStack(alignment: .top) {
            // Experimental: transparent while collapsed; the black fades in as it expands (opacity animates with the spring)
            shape.fill(.black.opacity(isExpanded || !transparentCollapsed ? 1 : 0))

            if isExpanded {
                ExpandedView(notchHeight: notchSize.height, isDropTargeted: isDropTargeted)
                    .padding(.horizontal, topRadius + 18)
                    .padding(.bottom, 14)
                    .transition(.opacity)
            } else if activity != .none {
                collapsedActivity
                    // Without the black background, a soft shadow keeps it readable on light menu bars
                    .shadow(color: .black.opacity(transparentCollapsed ? 0.55 : 0), radius: 2)
                    .padding(.horizontal, topRadius + 6)
                    .frame(height: notchSize.height)
                    .transition(.opacity)
            }
        }
        .frame(width: size.width, height: size.height)
        .contentShape(shape)
        // The cat stands outside the notch, just past its right edge, and follows that edge as it widens
        .overlay(alignment: .trailing) {
            if petVisible {
                PetView(mood: petMood)
                    .frame(width: Self.petSize, height: Self.petSize)
                    .offset(x: Self.petSize + Self.petGap)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        // Hover comes from the controller: the window is click-through except over the interactive part
        .onChange(of: controller.isPointerInside) { _, inside in
            isHovering = inside
            updateExpansion()
        }
        .onChange(of: windowSize) { reportLayout() }
        .onChange(of: isExpanded) { reportLayout() }
        .onAppear { reportLayout() }
        #if DEBUG
        .task {
            // Test hook: `NotchIsland --demo-expand` opens at 2s and closes at 5s
            guard CommandLine.arguments.contains("--demo-expand") else { return }
            try? await Task.sleep(for: .seconds(2)); openNow()
            try? await Task.sleep(for: .seconds(3)); closeNow()
        }
        #endif
        // Dragging a file onto the notch expands it; dropping adds it to the shelf
        .onDrop(of: ShelfModel.acceptedTypes, isTargeted: $isDropTargeted) { providers in
            shelf.add(from: providers)
            return true
        }
        .onChange(of: isDropTargeted) { updateExpansion() }
        .onChange(of: battery.isPluggedIn) { _, pluggedIn in
            if pluggedIn { flashChargingActivity() }
        }
        .onTapGesture { openNow() }
        .onReceive(NotificationCenter.default.publisher(for: .notchSwipe)) { note in
            guard swipeGestures, isHovering else { return }
            if note.userInfo?[Notification.Name.notchSwipeDownKey] as? Bool == true { openNow() } else { closeNow() }
        }
        .animation(Self.openSpring, value: activity)
        .animation(Self.openSpring, value: petVisible)
        .contextMenu {
            Button("Settings…") { SettingsWindowController.shared.show() }
                .keyboardShortcut(",", modifiers: .command)
            #if DEBUG
            Menu("Demo (debug)") {
                Button("Volume") { hud.show(.volume(muted: false), value: 0.6) }
                Button("Brightness") { hud.show(.brightness, value: 0.8) }
                Button("AirPods") { hud.show(.device(name: "AirPods Pro", connected: true)) }
                Button("Charging") { flashChargingActivity() }
            }
            #endif
            Divider()
            Button("Quit NotchIsland") { NSApp.terminate(nil) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// [left wing]  notch  [right wing]
    @ViewBuilder
    private var collapsedActivity: some View {
        HStack(spacing: 0) {
            if activity != .none {
                Group {
                    switch activity {
                    case .hud: if let event = hud.event { HUDActivity.Leading(event: event) }
                    case .charging: ChargingActivity.Leading()
                    case .nowPlaying: NowPlayingActivity.Leading()
                    case .none: EmptyView()
                    }
                }
                .frame(width: activityWidth, alignment: .leading)
            }

            Spacer(minLength: 0)

            if activity != .none {
                Group {
                    switch activity {
                    case .hud: if let event = hud.event { HUDActivity.Trailing(event: event) }
                    case .charging: ChargingActivity.Trailing()
                    case .nowPlaying: NowPlayingActivity.Trailing()
                    case .none: EmptyView()
                    }
                }
                .frame(width: activityWidth, alignment: .trailing)
            }

        }
    }

    private func updateExpansion() {
        collapseTask?.cancel()
        openTask?.cancel()

        if isDropTargeted {
            openNow()
        } else if isHovering {
            // Hovering only opens when enabled in Settings; click, drag and swipe always work.
            // The pointer must stay for the delay, so passing over the notch on the way to the menu bar does not trigger it.
            guard openOnHover, !isExpanded else { return }
            openTask = Task {
                try? await Task.sleep(for: .seconds(hoverDelay))
                guard !Task.isCancelled else { return }
                openNow()
            }
        } else {
            // Short delay so brushing past the edge does not make it flicker open/closed
            collapseTask = Task {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                closeNow()
            }
        }
    }

    private func reportLayout() {
        controller.contentSizeChanged(windowSize, isExpanded: isExpanded)
    }

    private func closeNow() {
        guard isExpanded else { return }
        withAnimation(Self.closeSpring) { isExpanded = false }
    }

    private func openNow() {
        openTask?.cancel()
        guard !isExpanded else { return }
        controller.prepareToExpand()   // make the window big enough before the shape starts growing
        withAnimation(Self.openSpring) { isExpanded = true }
        if haptics { NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default) }
    }

    private func flashChargingActivity() {
        chargingTask?.cancel()
        showCharging = true
        chargingTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            showCharging = false
        }
    }
}
