import Foundation
import IOKit.ps

/// Whether the Mac is on wall power, and a notification when the power source changes.
enum PowerSource {
    static let didChange = Notification.Name("PowerSourceDidChange")

    /// True on AC power, and on Macs with no battery at all.
    static var isOnAC: Bool {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        guard let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() else { return true }
        return (type as String) == kIOPMACPowerKey
    }

    /// Posts `didChange` on the main thread whenever IOKit reports a power change.
    /// That includes battery level ticks, so observers should compare state before acting.
    static func startObserving() {
        let source = IOPSNotificationCreateRunLoopSource({ _ in
            NotificationCenter.default.post(name: PowerSource.didChange, object: nil)
        }, nil).takeRetainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }
}
