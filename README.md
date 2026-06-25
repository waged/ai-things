<div align="center">

# ◎ AI-Things

**A native macOS app for [Claude Code](https://claude.com/claude-code) — use it with buttons, chats, and Git tools instead of the terminal.**

_by [things-connect.net](https://things-connect.net) · MIT licensed_

</div>

---

AI-Things is a clean, terminal-style **graphical front-end for the `claude` CLI**.
Instead of typing `claude --dangerously-skip-permissions` in a terminal, you open
your project, type what you want, and watch Claude read, edit, and run things —
rendered as an organized, scrollable conversation with real Git controls on the side.

It runs the **real Claude Code CLI** under the hood, so it does real work in your
real project. Authentication uses your existing Claude Code login — **no API keys
are stored by this app.**

## Features

- **Real Claude Code, graphical** — streams Claude's replies and tool activity
  (Read / Edit / Bash / Grep …) live, in a readable transcript.
- **Project-aware** — pick a directory; Claude works inside it. Current Git branch
  and uncommitted-change status shown in the header and sidebar.
- **Multiple chats** — start, switch, **clear**, **archive**, and delete chats.
  Everything is **saved per project** and survives relaunch.
- **Git workflow buttons** — New Branch (with formatted names like `feature/login`),
  Commit, Push, Pull, Show Changes, Discard, Open in Finder / Xcode / Terminal.
- **Composer toggles** — *Make message clearer*, *Ask questions first*, *Direct mode*.
- **Quick modes** — Feature and Bug-fix shortcuts.
- **Paste & drag-drop** — text, images, files, and file-path references.
- **Keyboard shortcuts** — ⌘↩ send · ⌘K clear · ⌘L focus · ⌘O open · Esc cancel · ↑/↓ history.
- **Brand-aligned dark UI** — navy + steel-blue, high-contrast text, the
  things-connect ring-and-dot mark as the app icon.

## Requirements

- macOS 14.0+
- [Claude Code](https://claude.com/claude-code) installed and logged in (`claude` on your PATH)
- Xcode 15+ and [XcodeGen](https://github.com/yonyz/XcodeGen) (`brew install xcodegen`) to build

## Build & run

```bash
git clone <your-fork-url> ai-things && cd ai-things
xcodegen generate
open AIThings.xcodeproj      # then ⌘R  (scheme: AIThings)
```

Or from the command line:

```bash
xcodebuild -project AIThings.xcodeproj -scheme AIThings -configuration Debug \
  -destination 'platform=macOS' build
open ~/Library/Developer/Xcode/DerivedData/AIThings-*/Build/Products/Debug/"AI-Things.app"
```

> **Not sandboxed by design.** The app launches `claude`, `git`, and shell commands
> via `Process`, which the macOS App Sandbox blocks — so sandboxing is disabled.
> Review the code before distributing a signed build.

## How it works

```
You ─▶ InputComposer ─▶ AppModel ─▶ AIService ─▶ ClaudeCodeProvider
                                                      │
                                   claude -p --output-format stream-json
                                   --verbose [--resume <id>] [--dangerously-skip-permissions]
                                                      │
        TerminalChat  ◀── parsed text + tool events ──┘   (runs in your project dir)
```

The provider parses the CLI's streaming JSON into readable lines and keeps
context across turns with `--resume <session_id>`. Swap in another backend by
implementing the `AIProvider` protocol.

## Project layout

```
project.yml                 XcodeGen definition (edit this, not the .xcodeproj)
Resources/Assets.xcassets   app icon (brand ring-and-dot)
Sources/AIThings/
  App/        entry point + AppModel (view model)
  Models/     ChatMessage, ChatSession, GitBranch, AppSettings, …
  Services/   ClaudeCodeProvider, GitService, TerminalCommandService,
              ChatStore (persistence), ProjectDirectoryService, …
  Views/      MainAppView, HeaderBarView, SidebarView, TerminalChatView,
              InputComposerView, GitToolbarView, SettingsView, …
  Branding/   LogoView + BrandMark
  Support/    Theme
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Issues and PRs welcome.

## License

[MIT](LICENSE) © things-connect.net. Not affiliated with Anthropic; "Claude" and
"Claude Code" are trademarks of Anthropic.
