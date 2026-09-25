# Browser Kitty Repository Health

[Live Repository Health](https://github.com/ttomohisa/browser-kitty-apps/actions/workflows/repository-health.yml) · [App catalog](CATALOG.md) · [Browser Kitty](https://browser-kitty.com/)

> This file is generated from `reports/repository-status.json`. A committed copy is a snapshot; the GitHub Actions Job Summary is the live view.

Last checked: **2026-09-25T04:16:36Z**

## Overall

**WARN — no blocking failures, follow-up items remain**

| Status | Apps |
|---|---:|
| PASS | 44 |
| WARN | 31 |
| FAIL | 0 |

Registered apps: **75**  
Warnings: **52**  
Failures: **0**  
Global issues: **0**

## Blocking problems

No blocking application failures were detected.

## Warnings by reason

| Count | Reason | Code |
|---:|---|---|
| 29 | English screenshot missing | `screenshot_en_missing` |
| 6 | Legacy app config missing | `legacy_app_config_missing` |
| 4 | Default / Japanese screenshot missing | `screenshot_missing` |
| 3 | Legacy runtime metadata unavailable | `legacy_app_config_unavailable` |
| 2 | Build output metadata incomplete | `build_output_unknown` |
| 2 | Favicon missing | `favicon_missing` |
| 2 | Runtime network policy metadata incomplete | `runtime_network_policy_unknown` |
| 1 | Registered version tag missing | `registered_version_tag_missing` |
| 1 | Registry / app.config version mismatch | `app_config_version_mismatch` |
| 1 | Registry / latest release version mismatch | `release_version_mismatch` |
| 1 | WASM dependency is not declared in registry metadata | `wasm_dependency_not_declared` |

## Apps needing attention

| Status | App | Inventory | Quality | Pages | Release | Runtime | Issues | Reasons |
|---|---|---|---|---|---|---|---:|---|
| WARN | Archive Explorer | PASS | WARN | PASS | PASS | PASS | 1 | English screenshot missing |
| WARN | Developer Toolbox | PASS | WARN | PASS | PASS | PASS | 1 | English screenshot missing |
| WARN | Device Check | PASS | WARN | PASS | PASS | PASS | 1 | English screenshot missing |
| WARN | Engineering Calculator | PASS | WARN | PASS | PASS | PASS | 1 | English screenshot missing |
| WARN | Face Redactor | PASS | WARN | PASS | PASS | PASS | 1 | English screenshot missing |
| WARN | FFmpeg Filter Builder | PASS | PASS | PASS | WARN | PASS | 3 | Registry / app.config version mismatch; Registry / latest release version mismatch; Registered version tag missing |
| WARN | Gesture Presentation | PASS | WARN | PASS | PASS | PASS | 3 | Favicon missing; Default / Japanese screenshot missing; English screenshot missing |
| WARN | JSON / YAML / CSV Viewer | PASS | WARN | PASS | PASS | PASS | 1 | English screenshot missing |
| WARN | Lossless Video Cutter | PASS | WARN | PASS | PASS | PASS | 1 | English screenshot missing |
| WARN | Markdown Preview Lab | PASS | WARN | PASS | PASS | PASS | 1 | English screenshot missing |
| WARN | Media Inspector | PASS | WARN | PASS | PASS | WARN | 2 | English screenshot missing; WASM dependency is not declared in registry metadata |
| WARN | Music Practice Kit | PASS | WARN | PASS | PASS | WARN | 3 | English screenshot missing; Build output metadata incomplete; Runtime network policy metadata incomplete |
| WARN | Office Image Extractor | PASS | WARN | PASS | PASS | PASS | 1 | English screenshot missing |
| WARN | Optical File | PASS | WARN | PASS | PASS | PASS | 1 | English screenshot missing |
| WARN | Parquet Viewer | PASS | WARN | PASS | WARN | WARN | 5 | Legacy app config missing; Default / Japanese screenshot missing; English screenshot missing; Legacy runtime metadata unavailable |
| WARN | PDF Compare | PASS | WARN | PASS | PASS | PASS | 1 | English screenshot missing |
| WARN | PDF Organizer | PASS | WARN | PASS | WARN | WARN | 4 | Legacy app config missing; English screenshot missing; Legacy runtime metadata unavailable |
| WARN | Photo Privacy Inspector | PASS | WARN | PASS | PASS | PASS | 1 | English screenshot missing |
| WARN | Pocket Level | PASS | WARN | PASS | PASS | PASS | 1 | English screenshot missing |
| WARN | Pocket Teleprompter | PASS | WARN | PASS | PASS | PASS | 1 | English screenshot missing |
| WARN | Pomodoro Timer | PASS | WARN | PASS | PASS | PASS | 1 | English screenshot missing |
| WARN | Pop-up Face Check-in | PASS | WARN | PASS | PASS | PASS | 1 | English screenshot missing |
| WARN | QR Reader | PASS | WARN | PASS | PASS | PASS | 1 | English screenshot missing |
| WARN | Same Spot Diff | PASS | WARN | PASS | PASS | PASS | 1 | English screenshot missing |
| WARN | Signal Screen | PASS | WARN | PASS | PASS | PASS | 1 | English screenshot missing |
| WARN | Smart Image Sorter | PASS | WARN | PASS | PASS | PASS | 1 | Default / Japanese screenshot missing |
| WARN | Temporary Links | PASS | WARN | PASS | WARN | WARN | 4 | Legacy app config missing; English screenshot missing; Legacy runtime metadata unavailable |
| WARN | Text Inspector | PASS | WARN | PASS | PASS | WARN | 3 | English screenshot missing; Build output metadata incomplete; Runtime network policy metadata incomplete |
| WARN | Video Contact Sheet | PASS | WARN | PASS | PASS | PASS | 1 | English screenshot missing |
| WARN | Video Face Redactor | PASS | WARN | PASS | PASS | PASS | 1 | English screenshot missing |
| WARN | Way Back | PASS | WARN | PASS | PASS | PASS | 3 | Favicon missing; Default / Japanese screenshot missing; English screenshot missing |

## Status meanings

- **PASS** — no issue was detected by the current checks.
- **WARN** — non-blocking repository hygiene, legacy migration, or metadata debt needs follow-up.
- **FAIL** — a blocking publication, repository, or runtime problem needs attention.

The detailed machine-readable report remains `reports/repository-status.json`; the detailed source-oriented Markdown report remains `reports/repository-status.md`.
