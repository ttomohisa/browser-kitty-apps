# Browser Kitty Repository Health

[Live Repository Health](https://github.com/ttomohisa/browser-kitty-apps/actions/workflows/repository-health.yml) · [App catalog](CATALOG.md) · [Browser Kitty](https://browser-kitty.com/)

> This is a committed **snapshot** of Repository Health. For the latest result, open the live workflow above. Each health run regenerates this human-readable view and publishes it in the GitHub Actions Job Summary and workflow artifact.

Last checked: **2026-09-25T03:53:51.5757181+00:00**  
Source: successful Repository Health run **#25**

## Overall

**WARN — no blocking failures**

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

No blocking application failures were detected in this snapshot.

## Warnings by reason

| Count | Reason | Code |
|---:|---|---|
| 29 | English screenshot missing | `screenshot_en_missing` |
| 6 | Legacy app config missing | `legacy_app_config_missing` |
| 4 | Default / Japanese screenshot missing | `screenshot_missing` |
| 3 | Legacy runtime metadata unavailable | `legacy_app_config_unavailable` |
| 2 | Build output metadata incomplete | `build_output_unknown` |
| 2 | Runtime network policy metadata incomplete | `runtime_network_policy_unknown` |
| 2 | Favicon missing | `favicon_missing` |
| 1 | Registry / app.config version mismatch | `app_config_version_mismatch` |
| 1 | Registry / latest release version mismatch | `release_version_mismatch` |
| 1 | Registered version tag missing | `registered_version_tag_missing` |
| 1 | WASM dependency is not declared in registry metadata | `wasm_dependency_not_declared` |

## Apps needing attention

| App | Issues |
|---|---:|
| Archive Explorer | 1 |
| JSON / YAML / CSV Viewer | 1 |
| Parquet Viewer | 5 |
| Text Inspector | 3 |
| Face Redactor | 1 |
| Photo Privacy Inspector | 1 |
| Smart Image Sorter | 1 |
| Office Image Extractor | 1 |
| PDF Compare | 1 |
| PDF Organizer | 4 |
| Gesture Presentation | 3 |
| Developer Toolbox | 1 |
| Device Check | 1 |
| Engineering Calculator | 1 |
| FFmpeg Filter Builder | 3 |
| Markdown Preview Lab | 1 |
| Music Practice Kit | 3 |
| Optical File | 1 |
| Pocket Level | 1 |
| Pocket Teleprompter | 1 |
| Pomodoro Timer | 1 |
| Pop-up Face Check-in | 1 |
| QR Reader | 1 |
| Same Spot Diff | 1 |
| Signal Screen | 1 |
| Temporary Links | 4 |
| Way Back | 3 |
| Lossless Video Cutter | 1 |
| Media Inspector | 2 |
| Video Contact Sheet | 1 |
| Video Face Redactor | 1 |

## Status meanings

- **PASS** — no issue was detected by the current checks.
- **WARN** — non-blocking repository hygiene, legacy migration, or metadata debt needs follow-up.
- **FAIL** — a blocking publication, repository, or runtime problem needs attention.

The detailed machine-readable report remains `reports/repository-status.json`; the existing detailed Markdown report remains `reports/repository-status.md`.
