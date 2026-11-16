# Kemanaya

Personal iOS app that answers "Kemana ya uangku?" — tracks expenses (Kebutuhan / Keinginan) and income, with pinned subcategory cards for fast logging.

## Read first
- `documents/DECISIONS.md` — every decision (D-NNN). It is the spec. Follow it; any change needs the user's approval and a new D-entry.
- `documents/PROGRESS.md` — phases, current status, log. Resume from the first unchecked item.

## Your role: orchestrator
- Delegate implementation, review and QA to subagents with a self-contained brief (relevant D-IDs, files, completion criterion). One at a time; two in parallel only under D-030.
- You run every verification build yourself and own the quality gate (D-032): zero warnings · tests green · screenshots reviewed in light / dark / AX-XL on iOS 26.5 + iOS 18.6 simulators.
- The user writes all CI/DevOps files (`.github/`, `.swiftlint.yml`, scripts). Teach, explain trade-offs, review their work; leave authoring to them.

## Build & run
- Xcode MCP first (`xcode` server → `xcrun mcpbridge`, from `.mcp.json`; Xcode must be open with MCP enabled). Fallback `xcodebuild` / `xcrun simctl` / `xcrun devicectl` only for what the MCP lacks — log why in DECISIONS.
- Simulators: `iPhone 17 Pro` (iOS 26.5), `iPhone 16 Pro` (iOS 18.6); phase close also `iPhone SE (3rd generation)` (18.3) and `iPhone Duo` (27.1).
- Real devices: iPhone 15 and iPhone XR, free Personal Team — builds expire every 7 days.

## Code rules
- SwiftUI + SwiftData + `@Observable`, no third-party dependencies. Pure logic and models in the local package `KemanayaCore` with Swift Testing; app target = views, design system, wiring (D-026, D-036).
- Min iOS 18. Liquid Glass only through the design-system glass modifier, which falls back to material on iOS 18 (D-025).
- Money is `Int64` rupiah (D-016). Strings in String Catalogs, Indonesian first (D-023).
- Brand tokens and the "never celebrate spending" guardrail: D-022.

## Git
- Work on a branch per phase (`feat/…`, `fix/…`, `chore/…`); push the branch and open a PR with `gh`. The user reviews and merges. `main` receives changes only through merged PRs (D-034).
- Before each commit, inspect the staged diff for personal data and screenshots (D-037).
- Update `documents/PROGRESS.md` when a task starts and finishes; commit once per finished task group with an imperative summary.
