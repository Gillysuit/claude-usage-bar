import AppKit

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var usage: UsageResponse?
    @Published private(set) var plan: String?
    @Published private(set) var error: String?
    @Published private(set) var updatedAt: Date?
    @Published private(set) var isLoading = false
    /// Non-error status shown in gray, e.g. when rate limited but older data is still on screen.
    @Published private(set) var notice: String?
    /// Fetches before this are skipped: 60s after a success, or the server's Retry-After after a 429.
    @Published private(set) var nextAllowedFetch: Date?

    /// The endpoint's rate limit is shared with Claude Code itself, so never ask more than once a minute.
    static let minInterval: TimeInterval = 60

    var onUpdate: (() -> Void)?

    /// Highest percent across all limits; drives the menu bar color.
    var peak: Double? { usage?.allLimits.map(\.percent).max() }

    func refresh() async {
        guard !isLoading else { return }
        if let next = nextAllowedFetch, next > Date() { return }
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
            notice = nil
            nextAllowedFetch = Date().addingTimeInterval(Self.minInterval)
        } catch UsageError.rateLimited(let retryAfter) {
            let next = Date().addingTimeInterval(max(retryAfter ?? 0, Self.minInterval))
            nextAllowedFetch = next
            error = nil
            notice = updatedAt.map { "Rate limited, showing data from \(shortTime($0))" }
                ?? "Rate limited, retrying after \(shortTime(next))"
        } catch {
            self.error = error.localizedDescription
        }
    }
}

func shortTime(_ date: Date) -> String {
    date.formatted(date: .omitted, time: .shortened)
}

/// green↔teal under 33%, yellow↔orange under 80%, red↔purple at 80%+.
enum UsageLevel {
    case unknown, low, mid, high

    init(_ percent: Double?) {
        guard let percent else { self = .unknown; return }
        switch percent {
        case ..<33: self = .low
        case ..<80: self = .mid
        default: self = .high
        }
    }

    /// The two colors the lava-lamp dot drifts between; bars use them as a gradient.
    var colors: (NSColor, NSColor) {
        switch self {
        case .unknown: return (.systemGray, .systemGray)
        case .low: return (.systemGreen, .systemTeal)
        case .mid: return (.systemYellow, .systemOrange)
        case .high: return (.systemRed, .systemPurple)
        }
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
