import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = UsageStore()
    private let popover = NSPopover()
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private let dot = GlowDotView(frame: NSRect(x: 0, y: 0, width: GlowDotView.size, height: GlowDotView.size))
    /// Horizontal offset of the dot from the button's center; follows the label image's width.
    private var dotOffset: NSLayoutConstraint!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.target = self
        statusItem.button?.imagePosition = .imageOnly
        if let button = statusItem.button {
            // The label image leaves its leading space empty; the animated dot sits over it.
            button.addSubview(dot)
            dot.translatesAutoresizingMaskIntoConstraints = false
            dotOffset = dot.centerXAnchor.constraint(equalTo: button.centerXAnchor)
            NSLayoutConstraint.activate([
                dotOffset,
                dot.centerYAnchor.constraint(equalTo: button.centerYAnchor),
                dot.widthAnchor.constraint(equalToConstant: GlowDotView.size),
                dot.heightAnchor.constraint(equalToConstant: GlowDotView.size),
            ])
        }

        popover.behavior = .transient
        let hosting = NSHostingController(rootView: UsageView(store: store))
        // Let the popover own resizing; otherwise SwiftUI grows the window upward off the top of the screen.
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting

        // Pause the dot's animation on battery or with Reduce Motion, and resume when that changes.
        PowerSource.startObserving()
        NotificationCenter.default.addObserver(
            self, selector: #selector(animationConditionsChanged), name: PowerSource.didChange, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(animationConditionsChanged),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)

        store.onUpdate = { [weak self] in self?.updateButton() }
        updateButton()
        refresh()
        // Keep the glow current between clicks.
        timer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        // The timer doesn't fire while asleep, so catch up right away on wake.
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
    }

    @objc private func animationConditionsChanged() {
        dot.refreshAnimation()
    }

    @objc private func didWake() {
        usageLog.notice("Woke from sleep, refreshing")
        refresh()
    }

    private func refresh() {
        Task { await store.refresh() }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            refresh()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func updateButton() {
        guard let button = statusItem.button else { return }
        let limits = store.usage?.allLimits ?? []
        let session = limits.first { $0.kind == "session" }?.percent
        let weekly = limits.first { $0.kind == "weekly_all" }?.percent
        let image = StatusImage.make(session: session, weekly: weekly)
        button.image = image
        // The image is centered in the button, so its leading dot space starts half its width left of center.
        dotOffset.constant = StatusImage.dotSpace / 2 - image.size.width / 2
        // Dot color follows the highest limit, including per-model weekly ones not shown in the bar.
        dot.setLevel(UsageLevel(store.peak))
        button.setAccessibilityLabel(session.map { s in
            "Claude usage: session \(Int(s.rounded()))%" + (weekly.map { ", weekly \(Int($0.rounded()))%" } ?? "")
        } ?? "Claude usage")
        button.toolTip = store.error ?? "Claude usage"
    }
}
