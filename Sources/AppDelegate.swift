import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = UsageStore()
    private let popover = NSPopover()
    private var statusItem: NSStatusItem!
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.target = self
        statusItem.button?.imagePosition = .imageOnly

        popover.behavior = .transient
        let hosting = NSHostingController(rootView: UsageView(store: store))
        // Let the popover own resizing; otherwise SwiftUI grows the window upward off the top of the screen.
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting

        store.onUpdate = { [weak self] in self?.updateButton() }
        updateButton()
        refresh()
        // Keep the glow current between clicks.
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
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
        // Dot color follows the highest limit, including per-model weekly ones not shown in the bar.
        button.image = StatusImage.make(color: usageColor(store.peak), session: session, weekly: weekly)
        button.setAccessibilityLabel(session.map { s in
            "Claude usage: session \(Int(s.rounded()))%" + (weekly.map { ", weekly \(Int($0.rounded()))%" } ?? "")
        } ?? "Claude usage")
        button.toolTip = store.error ?? "Claude usage"
    }
}
