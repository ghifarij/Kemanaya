# Kemanaya — Progress

Status keys: `[ ]` todo · `[~]` in progress · `[x]` done · `[!]` blocked.
Each phase is one branch + one PR (D-034) and passes the quality gate (D-032) before it is marked done.
Owner `user` = the user does it (Claude may teach/review); otherwise Claude/subagents.

## Phase 0 — Setup
- [x] Design interview (grilling) — all decisions in `DECISIONS.md` (2026-11-16)
- [x] Folder, `git init`, `CLAUDE.md`, `documents/`, `.mcp.json` (2026-11-16)
- [x] Initial commit on `main` (docs only) (2026-11-16)
- [ ] **user** — create public GitHub repo `kemanaya`, push `main`
- [ ] **user** — branch protection on `main` (require PR + passing CI)
- [ ] Local git guardrail hook blocking pushes to `main` (git-guardrails skill)
- [ ] Scaffold Xcode project: synchronized groups, `Kemanaya` / `KemanayaTests` / `KemanayaUITests`, local package `KemanayaCore` (D-036), `Config/Signing.xcconfig` + gitignored `Signing.local.xcconfig` (D-028), iOS 18.0 min, bundle id
- [ ] Verify clean build + empty test run via Xcode MCP on both simulators

## Phase 0.5 — CI (owner: user)
- [ ] **user** — check Xcode versions on GitHub macOS runner
- [ ] **user** — `.github/workflows/ci.yml`: SwiftLint → build → unit tests (Claude reviews)
- [ ] **user** — `.swiftlint.yml`

## Phase 1 — Spike: backup bookmark (D-019)
- [ ] Throwaway screen: pick folder → save bookmark → write file → relaunch → write again
- [ ] Verified on iPhone 15 (free signing)
- [ ] Verified on iPhone XR (iOS 18)
- [ ] Verified after delete + reinstall → restore works
- [ ] Record result in DECISIONS (confirm D-019 or switch to manual fallback)

## Phase 2 — Design system (D-021, D-022, D-025)
- [ ] Color tokens (light/dark/increased contrast, AA-checked)
- [ ] Typography (SF Pro Rounded Heavy amounts, monospaced digits)
- [ ] Glass modifier with iOS 18 fallback
- [ ] Components: subcategory card, amount text, split bar, keypad key

## Phase 3 — Domain & data
- [ ] SwiftData models: Subcategory, Transaction, MonthlyRollup, Budget/Settings (`#Index` on date)
- [ ] Seed data (D-008) + default pins (D-012)
- [ ] IDR formatting, month bucketing, aggregation services + Swift Testing

## Phase 4 — Add transaction (D-013)
- [ ] Rupiah keypad + quick chips, subcategory grid, optional note/date
- [ ] Edit / delete via swipe
- [ ] UI test for the add flow

## Phase 5 — Home (D-012, D-009, D-010)
- [ ] Pinned cards grid (tap = quick add, long-press menu)
- [ ] Month total, sisa + savings rate, Kebutuhan vs Keinginan split bar, budget progress
- [ ] Pin management

## Phase 6 — Breakdown & Trend (D-014)
## Phase 7 — History (13-month window, search, grouped by day)
## Phase 8 — Retention: rollup + purge + yearly recap (D-017)
## Phase 9 — Backup / restore / CSV export (D-019, D-020)
## Phase 10 — Settings: subcategory management, budgets, backup folder
## Phase 11 — Onboarding, Si Naya mascot, app icon, English localization, polish
## Phase 12 — Install on iPhone 15 and iPhone XR; 7-day re-sign routine

---

## Log
- **2026-11-16** — Grilling session complete (D-001…D-035). Next: Phase 0 in a new session (Fable) started from `~/Vibecoding/Kemanaya`.
