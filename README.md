<div align="center">

# :mailbox_with_mail: RSS Inbox

**A tiny, native status-bar RSS reader for macOS.**

Built with SwiftUI · SwiftData · macOS 15+

</div>

## Why

Most RSS readers want to be a whole app. RSS Inbox just lives in your status bar - a quiet unread indicator, a popover for skimming, and the system browser for actually reading.

No accounts. No sync. No subscriptions. Just feeds.

## Features

- 🗞️ **Status-bar native** — runs as `LSUIElement`, no Dock icon, no window clutter
- 🔵 **Unread badge** — the status icon shows a dot when there's something new
- 📥 **Frictionless popover** — `⌘`-friendly popover with feed tabs, per-feed unread counts, and a full-width clickable article row
- 🔄 **Background polling** — every 5, 15, 30, or 60 minutes (your call)
- 📂 **OPML import/export** — bring your feeds with you
- 🗑️ **Retention pruning** — keep the last 100 / 250 / 500 articles per feed, automatically
- 🚀 **Launch at login** — via `SMAppService`, the modern way
- 💾 **SwiftData persistence** — local-first, no cloud, no telemetry
- 🌗 **Vibrant blur** — `NSVisualEffectView` with proper rounded corners and a real drop shadow

## Screenshots

<div align="center">

<img src="metadata/Screenshot%202026-05-11%20at%2010.31.06.png" width="360" alt="RSS Inbox popover — light mode" />
&nbsp;&nbsp;
<img src="metadata/Screenshot%202026-05-11%20at%2010.31.00.png" width="360" alt="RSS Inbox popover — dark mode" />

</div>

## Requirements

- macOS **15.0** (Sequoia) or later
- Xcode **16** with Swift **5.10**

## Build

```bash
# 1. Generate the Xcode project
xcodegen generate

# 2. Build & run from Xcode (⌘R)
open RSSInbox.xcodeproj
```

Or build from the command line:

```bash
xcodebuild -scheme RSSInbox -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO build
```

## Test

```bash
xcodebuild test -scheme RSSInbox -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
```

The test suite covers OPML parsing, feed parsing (RSS 2.0 + Atom), the badge controller, and feed-poller integration (dedup, retention, network failure surfacing).

## Architecture

```
RSSInbox/
├── AppDelegate.swift          NSPanel-backed status bar UI
├── RSSInboxApp.swift          SwiftUI App entry point
├── Core/
│   ├── FeedParser.swift       RSS 2.0 + Atom → ParsedFeed
│   ├── OPMLParser.swift       OPML import / export
│   ├── FeedPoller.swift       @Observable @MainActor polling loop
│   └── BadgeController.swift  Unread-count → status-bar icon
├── Models/
│   ├── Feed.swift             @Model — title, url, lastFetched, fetchError
│   └── Article.swift          @Model — guid, title, summary, link, isRead
└── Views/
    ├── PopoverView.swift      Menu-bar popover
    ├── ArticleRowView.swift   Full-row clickable article cell
    ├── ReaderView.swift       (Optional) in-app reader
    └── PreferencesView.swift  Feeds + General tabs (SMAppService)
```

### Notable design choices

- **`NSPanel` instead of `NSPopover`** — borderless, non-activating, with manual positioning so the popover anchors to the status item across multi-monitor setups.
- **`maskImage` for rounded corners** — `NSVisualEffectView` ignores `layer.cornerRadius` during certain compositing passes; a 9-part stretchable mask image is the only reliable way to get rounded corners that survive redraws.
- **One `ModelContext` per logical owner** — the poller creates its own context per run; the views use the SwiftUI environment context. SwiftData merges via the shared `ModelContainer`.

## Configuration

User-facing settings live in `UserDefaults` and the Preferences window:

| Key                   | Type | Default | Description                 |
| --------------------- | ---- | ------- | --------------------------- |
| `pollIntervalMinutes` | Int  | `15`    | Background polling interval |
| `retentionLimit`      | Int  | `100`   | Max articles kept per feed  |

## License

[MIT](LICENSE) © Bartosz Szar
