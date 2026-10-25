# Claude Usage Bar

A tiny macOS menu bar app that shows your Claude plan usage — the same numbers as `/usage` in Claude Code.

The menu bar shows a glowing dot with your current **Session** and **Weekly** percentages stacked beside it. Click it for the full breakdown:

- Current session, weekly (all models) and any per-model weekly limits, each with a bar and reset time
- This week's usage split by surface (Claude Code, Chats, Cowork, …)
- Extra usage spend and whether it's on

The dot color follows whichever limit is highest:

| Usage | Color |
|---|---|
| under 33% | green |
| 33–65% | yellow |
| 66–79% | orange |
| 80%+ | red |

It refreshes on launch, every 5 minutes, and whenever you open it.

## Requirements

- macOS 14+
- Xcode command line tools (`xcode-select --install`)
- Claude Code installed and logged in with a Claude subscription (`claude`, then `/login`)

## Build and install

```bash
./build.sh --install
```

This builds `ClaudeUsage.app`, copies it to `~/Applications`, and launches it. Run `./build.sh` alone to just build into `build/`.

### Launch at login

Create `~/Library/LaunchAgents/com.gil.claude-usage-bar.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.gil.claude-usage-bar</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/open</string>
    <string>/Users/YOU/Applications/ClaudeUsage.app</string>
  </array>
  <key>RunAtLoad</key><true/>
</dict>
</plist>
```

Then load it:

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.gil.claude-usage-bar.plist
```

## How it works

It reads the OAuth token Claude Code stores in your login keychain (`Claude Code-credentials`, via `/usr/bin/security`, so there's no keychain prompt) and calls the same usage endpoint `/usage` uses. It never refreshes or writes the token — if it has expired, run any `claude` command and it'll pick up the new one.

This endpoint isn't a documented public API, so a Claude Code update could change it and break the app.
