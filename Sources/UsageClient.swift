import Foundation

// Same endpoint Claude Code's /usage reads, authed with the OAuth token Claude Code keeps in the keychain.

struct UsageResponse: Decodable {
    let limits: [UsageLimit]?
    let fiveHour: Window?
    let sevenDay: Window?
    let spend: Spend?
    let sevenDayBreakdown: Breakdown?

    struct Window: Decodable {
        let utilization: Double?
        let resetsAt: String?
    }

    struct Spend: Decodable {
        let used: Money?
        let limit: Money?
        let enabled: Bool?
        let disabledReason: String?
    }

    struct Money: Decodable {
        let amountMinor: Int
        let exponent: Int
        var value: Double { Double(amountMinor) / pow(10, Double(exponent)) }
    }

    struct Breakdown: Decodable {
        let rows: [Row]
        struct Row: Decodable {
            let displayName: String
            let percent: Double
        }
    }

    /// Structured limits when present, otherwise the older five_hour / seven_day fields.
    var allLimits: [UsageLimit] {
        if let limits, !limits.isEmpty { return limits }
        var out: [UsageLimit] = []
        if let w = fiveHour, let u = w.utilization {
            out.append(UsageLimit(kind: "session", percent: u, resetsAt: w.resetsAt, scope: nil))
        }
        if let w = sevenDay, let u = w.utilization {
            out.append(UsageLimit(kind: "weekly_all", percent: u, resetsAt: w.resetsAt, scope: nil))
        }
        return out
    }
}

struct UsageLimit: Decodable, Identifiable {
    let kind: String
    let percent: Double
    let resetsAt: String?
    let scope: Scope?

    struct Scope: Decodable { let model: Model? }
    struct Model: Decodable { let displayName: String? }

    var id: String { kind + (scope?.model?.displayName ?? "") }

    var title: String {
        switch kind {
        case "session": return "Current session"
        case "weekly_all": return "Weekly · all models"
        case "weekly_scoped": return "Weekly · \(scope?.model?.displayName ?? "scoped")"
        default: return kind.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    var resetDate: Date? { resetsAt.flatMap(parseISODate) }
}

struct Profile: Decodable {
    let organization: Organization?

    struct Organization: Decodable {
        let billingType: String?
        let subscriptionStatus: String?
        let subscriptionCreatedAt: String?
    }

    /// The API has no renewal date, so this is the next monthly anniversary of the subscription's start.
    /// It's wrong for annual billing, or if the billing day moved after the subscription started.
    var nextRenewal: Date? {
        guard let org = organization,
              org.billingType == "stripe_subscription", org.subscriptionStatus == "active",
              let start = org.subscriptionCreatedAt.flatMap(parseISODate)
        else { return nil }
        // Months are added to the start date each time so a 31st start comes back to the 31st after February.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        var months = 1
        while let date = calendar.date(byAdding: .month, value: months, to: start) {
            if date > Date() { return date }
            months += 1
        }
        return nil
    }
}

struct Credentials {
    let token: String
    let plan: String?
}

enum UsageError: LocalizedError {
    case noCredentials
    case expired
    case rateLimited(retryAfter: TimeInterval?)
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .noCredentials: return "No Claude Code login found in the keychain. Run `claude` and log in."
        case .expired: return "Token expired. Run any `claude` command to refresh it."
        case .rateLimited: return "Rate limited by the usage endpoint."
        case .http(let code): return "Usage request failed (HTTP \(code))."
        }
    }
}

enum UsageClient {
    private struct KeychainBlob: Decodable {
        let claudeAiOauth: OAuth
        struct OAuth: Decodable {
            let accessToken: String
            let subscriptionType: String?
        }
    }

    /// Shells out to `security` because that binary is already on the keychain item's ACL, so no access prompt.
    static func readCredentials() throws -> Credentials {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let blob = try? JSONDecoder().decode(KeychainBlob.self, from: data)
        else { throw UsageError.noCredentials }
        return Credentials(token: blob.claudeAiOauth.accessToken, plan: blob.claudeAiOauth.subscriptionType)
    }

    static func fetch(token: String) async throws -> UsageResponse {
        try await get("usage", token: token)
    }

    static func fetchProfile(token: String) async throws -> Profile {
        try await get("profile", token: token)
    }

    private static func get<T: Decodable>(_ path: String, token: String) async throws -> T {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/\(path)")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        let http = response as? HTTPURLResponse
        let status = http?.statusCode ?? 0
        if status == 401 { throw UsageError.expired }
        if status == 429 {
            // Retry-After can also be an HTTP date; only the seconds form is handled, else the caller's default applies.
            let retryAfter = http?.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            throw UsageError.rateLimited(retryAfter: retryAfter)
        }
        guard status == 200 else { throw UsageError.http(status) }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }
}

/// The API returns microsecond precision, which ISO8601DateFormatter can't parse, so drop the fraction.
func parseISODate(_ string: String) -> Date? {
    let trimmed = string.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
    return ISO8601DateFormatter().date(from: trimmed)
}
