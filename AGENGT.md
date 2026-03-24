# AGENTS.md

## Project
This is a macOS menu bar stock watcher app built with SwiftUI.

## Current phase
UI-only prototype.

## Tech stack
- Swift
- SwiftUI
- MenuBarExtra
- async/await
- mock data only for now

## Constraints
- Do not implement real quote fetching yet.
- Do not add persistence, notifications, login item, or settings unless explicitly requested.
- Do not put business logic or networking directly in SwiftUI Views.
- Keep the architecture layered: Models / Providers / ViewModels / Views.
- Make only the minimum code changes required.

## Workflow
- First propose a plan.
- Then create the minimum runnable UI skeleton.
- Use mock quote data.
- Keep code readable and split by file.