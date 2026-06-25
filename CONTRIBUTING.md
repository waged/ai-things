# Contributing to AI-Things

Thanks for your interest! AI-Things is a native macOS SwiftUI front-end for the
[Claude Code](https://claude.com/claude-code) CLI.

## Getting set up

1. Install [XcodeGen](https://github.com/yonyz/XcodeGen): `brew install xcodegen`
2. Generate the project: `xcodegen generate`
3. Open `AIThings.xcodeproj` and run (⌘R), or build from the CLI:
   ```bash
   xcodebuild -project AIThings.xcodeproj -scheme AIThings -configuration Debug \
     -destination 'platform=macOS' build
   ```

The `.xcodeproj` is generated and git-ignored — edit `project.yml` for project
settings, never the generated project file.

## Project layout

- `Sources/AIThings/App` — entry point + `AppModel` (the view model)
- `Sources/AIThings/Models` — plain data types
- `Sources/AIThings/Services` — git, shell, Claude CLI, persistence, attachments
- `Sources/AIThings/Views` — SwiftUI views (one component per file)
- `Sources/AIThings/Branding` / `Support` — logo + theme

## Guidelines

- Keep components small; one view per file.
- All blocking work (shell, git, AI) stays off the main thread via `async/await`.
- Match the surrounding style. Comment only where it clarifies intent.
- A new AI backend = a type conforming to `AIProvider` (see `ClaudeCodeProvider`).
- Run a build before opening a PR.

## Reporting issues

Open an issue with: macOS version, `claude --version`, repro steps, and what you
expected vs. what happened.
