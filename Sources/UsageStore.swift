import AppKit

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var usage: UsageResponse?
    @Published private(set) var plan: String?
    @Published private(set) var error: String?
    @Published private(set) var updatedAt: Date?
    @Published private(set) var isLoading = false

    var onUpdate: (() -> Void)?

    /// Highest percent across all limits; drives the menu bar color.
    var peak: Double? { usage?.allLimits.map(\.percent).max() }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer {
            isLoading = false
            onUpdate?()
        }
        do {
            let creds = try UsageClient.readCredentials()
            plan = creds.plan
            usage = try await UsageClient.fetch(token: creds.token)
            updatedAt = Date()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// green < 33, yellow < 66, orange 66–79, red 80+.
func usageColor(_ percent: Double?) -> NSColor {
    guard let percent else { return .systemGray }
    switch percent {
    case ..<33: return .systemGreen
    case ..<66: return .systemYellow
    case ..<80: return .systemOrange
    default: return .systemRed
    }
}

func resetText(_ date: Date?) -> String? {
    guard let date else { return nil }
    let seconds = date.timeIntervalSinceNow
    if seconds <= 0 { return "Resets now" }
    if seconds < 24 * 3600 {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        return h > 0 ? "Resets in \(h)h \(m)m" : "Resets in \(m)m"
    }
    let formatter = DateFormatter()
    formatter.dateFormat = "EEE MMM d, h:mm a"
    return "Resets \(formatter.string(from: date))"
}
