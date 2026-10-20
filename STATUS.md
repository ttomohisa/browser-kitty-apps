# Browser Kitty Repository Health

[Live Repository Health](https://github.com/ttomohisa/browser-kitty-apps/actions/workflows/repository-health.yml) · [App catalog](CATALOG.md) · [Browser Kitty](https://browser-kitty.com/)

> This file is generated from `reports/repository-status.json`. A committed copy is a snapshot; the GitHub Actions Job Summary is the live view.

Last checked: **2026-10-20T20:08:11.5782700+00:00**

## Overall

**WARN — no blocking failures, follow-up items remain**

| Status | Apps |
|---|---:|
| PASS | 101 |
| WARN | 4 |
| FAIL | 0 |

Registered apps: **105**  
Warnings: **6**  
Failures: **0**  
Global issues: **0**

## Blocking problems

No blocking application failures were detected.

## Warnings by reason

| Count | Reason | Code |
|---:|---|---|
| 3 | English screenshot missing | `screenshot_en_missing` |
| 1 | Default / Japanese screenshot missing | `screenshot_missing` |
| 1 | Registered version tag missing | `registered_version_tag_missing` |
| 1 | Registry / latest release version mismatch | `release_version_mismatch` |

## Apps needing attention

| Status | App | Inventory | Quality | Pages | Release | Runtime | Issues | Reasons |
|---|---|---|---|---|---|---|---:|---|
| WARN | Audio to MIDI | PASS | WARN | PASS | PASS | PASS | 1 | English screenshot missing |
| WARN | Best Shot Picker | PASS | WARN | PASS | PASS | PASS | 1 | English screenshot missing |
| WARN | FFmpeg Filter Builder | PASS | PASS | PASS | WARN | PASS | 2 | Registry / latest release version mismatch; Registered version tag missing |
| WARN | Pause & Tell | PASS | WARN | PASS | PASS | PASS | 2 | Default / Japanese screenshot missing; English screenshot missing |

## Status meanings

- **PASS** — no issue was detected by the current checks.
- **WARN** — non-blocking repository hygiene, legacy migration, or metadata debt needs follow-up.
- **FAIL** — a blocking publication, repository, or runtime problem needs attention.

The detailed machine-readable report remains `reports/repository-status.json`; the detailed source-oriented Markdown report remains `reports/repository-status.md`.
