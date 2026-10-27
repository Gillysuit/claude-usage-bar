import Foundation
import os

/// Local-only troubleshooting log in macOS's unified log (see "Troubleshooting" in the README).
/// Keyed to the running app's bundle ID, so it works for any build. Never log the token.
let usageLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "claude-usage-bar", category: "usage")
