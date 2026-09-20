# Changelog

## v0.8.0

### Added

- Added `generated/apps.public.json`, a deterministic public export for build-time consumption by the private Browser Kitty website repository.
- Added `schema/public-apps.schema.json` to define the exported data contract.
- Added `scripts/generate-public-export.ps1` with normal generation and `-Check` drift-detection modes.
- Added `generated/README.md` documenting generated-data ownership and build-time use.

### Changed

- Validate Registry now fails when the committed public export is missing or stale.
- Public export intentionally omits repository-profile, build-path, hosting-header, template, health-report, and generation-timestamp data.
- Documented that Browser Kitty consumes the export at build time rather than fetching the registry at browser runtime.

## v0.7.2

### Fixed

- Restored Face Redactor's canonical GitHub Pages URL to the repository root, matching the `dist/index.html` deployment produced by the standard Pages workflow.
- Kept Pages HTTP 404 as a blocking health failure; this patch does not downgrade or hide deployment outages.
- Documented that Face Redactor needs the standard GitHub Actions Pages deployment workflow and one-time Pages source configuration.

## v0.7.1

### Fixed

- Reclassified missing favicon and screenshot assets from `FAIL` to `WARN` so repository-hygiene debt does not block the full registry health gate.
- Corrected Face Redactor Pages URL to the repository's published `face-redactor.html` entry point.
- Updated runtime dependency inspection to accept `dependencies.json` entries using `assets`, single `asset`, or `files` layouts without StrictMode property errors.
- Updated runtime capability declarations found by the first 75-app scan: PDF Compare, Gesture Presentation, Presentation Remote, Large Print Tiler, Pop-up Face Check-in, Same Spot Diff, Lossless Video Cutter, Video Contact Sheet, and Video Face Redactor.

### Policy

- `README.md`, `LICENSE`, standard-profile `app.config.json`, repository availability, published Pages availability, and hard runtime contradictions remain blocking `FAIL`s.
- `assets/favicon.svg`, `assets/screenshot.png`, and `assets/screenshot-en.png` are tracked as non-blocking `WARN`s for gradual cleanup.

## v0.7.0

- Expanded `apps.json` from 11 representative apps to 75 registered Browser Kitty apps.
- Added explicit `repositoryProfile` (`standard` / `legacy`) to support older published repositories without `app.config.json`.
- Added verified legacy entries for PDF Organizer, Parquet Viewer, and Temporary Links.
- Excluded templates, WASM builders, shared cores, and duplicate legacy repository aliases from the application registry.
- Reworked repository inventory to fetch public repository metadata per owner instead of one REST request per app.
- Reworked asset checks to use throttled raw-file HEAD probes, avoiding GitHub REST API exhaustion at full-registry scale.
- Moved release lookup out of inventory; release/version checks now use the GitHub latest-release redirect and `git ls-remote` for tags.
- Normalized legacy two-component versions such as `1.0` to SemVer `1.0.0` for registry comparison.
- Added legacy handling to Release and Runtime checks so missing `app.config.json` is an explicit migration warning rather than a false hard failure.

All notable changes to this repository are documented here.

## [0.6.2] - 2026-09-20

### Fixed

- Replaced the smoke test's strict-mode-unsafe `$LASTEXITCODE` read with the immediate PowerShell `$?` command status after `generate-report.ps1`.
- Prevented a smoke-test regression in the Repository Health workflow from skipping all five live source checks and producing a secondary all-missing-source report.

### Changed

- Repository Health now lets the smoke step continue temporarily, runs live checks and uploads diagnostics, then enforces the smoke outcome as a final gate.
- Validate Registry remains fail-fast on the same smoke test.


## [0.6.1] - 2026-09-20

### Fixed

- Allowed empty mandatory collection parameters in `generate-report.ps1`, fixing the normal zero-global-issues / zero-app-issues path that previously failed PowerShell parameter binding.
- Applied the same empty-collection allowance to `check-assets.ps1` tree path sets for defensive consistency.

### Added

- Added `test-generate-report.ps1`, which builds all-PASS fixture reports with empty issue arrays and executes the consolidated report generator end-to-end.
- Added the health-report smoke test to both validation and repository-health workflows so binding/runtime regressions are caught before network-backed checks.

## [0.6.0] - 2026-09-20

### Added

- Added `generate-report.ps1` to consolidate Inventory, Quality, Pages, Release/version, and Runtime results.
- Added `repository-status.json` with per-application final health, component check states, issue counts, and source-preserving issue details.
- Added `repository-status.md` for a human-readable health summary in CI artifacts.
- Added `schema/repository-health.schema.json` for final report validation.
- Added explicit handling for missing or invalid source reports; affected checks become `UNKNOWN` and the final result fails safely.

### Changed

- Repository Health source checks now use `continue-on-error` so one failure does not hide later diagnostics.
- The consolidated health report is now the final CI gate: warnings remain successful, while application/global failures return exit code 1.
- Workflow artifacts now include both consolidated JSON and Markdown reports.

## [0.5.0] - 2026-09-20

### Added

- Added standalone/runtime consistency checks and `repository-runtime.json` output.
- Added JSON Schema validation for the generated runtime report.
- Added explicit runtime capability flags for every registered application: cross-origin isolation, WASM, Worker, WebGPU, and WebCodecs.
- Added build-output matching between `runtime.standalonePath` and `app.config.json`, including multi-thread and self-extract outputs.
- Added runtime network-policy comparison with `build.blockRuntimeNetwork`.
- Added COOP / COEP / CORP declaration validation for cross-origin-isolated applications.
- Added optional `dependencies.json` evidence checks for WASM and Worker declarations.
- Added runtime report generation to the Repository Health workflow and workflow artifact.
- Reused `app.config.json` build metadata from the release report and raw public content for dependency manifests to avoid duplicate GitHub REST API calls.

### Changed

- Marked PDF Review Notes as requiring a Worker because its pinned PDF.js dependency includes the PDF worker asset.
- Marked Local Video Compressor as requiring both WASM and Worker based on its pinned FFmpeg runtime and current application source.
- Runtime capability fields are now required rather than optional, so `false` is distinguishable from missing metadata.

## [0.4.0] - 2026-09-20

### Added

- Added GitHub Pages reachability checks with redirect support and HTML content-type warnings.
- Added headers-only HTTP checking to avoid downloading large standalone HTML artifacts.
- Added registry / `app.config.json` / Latest Release / Git tag version consistency checks.
- Added tolerant version tag matching for `1.2.3` and `v1.2.3`.
- Added JSON Schemas for Pages and release/version reports.
- Added both new checks to the scheduled Repository Health workflow and workflow artifact.

### Changed

- Repository Health workflow now watches all files under `schema/**`.
- Missing GitHub Releases or tags are explicitly valid; mismatches are warnings rather than automatic mutations.

## [0.3.1] - 2026-09-20

### Fixed

- Fixed PowerShell parser errors in `check-repositories.ps1` and `check-assets.ps1` caused by a colon immediately following an interpolated variable name.

### Added

- Added `check-powershell.ps1` to parse every PowerShell script before repository checks run.
- Added strict UTF-8 validation for PowerShell scripts.
- Updated both GitHub Actions workflows so any change under `scripts/**` triggers validation.

## [0.3.0] - 2026-09-20

### Added

- Repository Quality Check with `PASS`, `WARN`, and `FAIL` results.
- Required-file checks for `README.md`, `LICENSE`, `app.config.json`, and `assets/favicon.svg`.
- Release screenshot checks for `assets/screenshot.png` and `assets/screenshot-en.png`.
- Status-aware screenshot policy: published stable/maintenance apps fail when release screenshots are missing; development/RC apps warn instead.
- Informational `package.json` detection without treating Node as a repository requirement.
- JSON Schema for generated repository quality reports.
- Repository tree lookup that reuses default-branch data from the v0.2.0 inventory to reduce duplicate GitHub API calls.
- Combined GitHub Actions artifact containing inventory and quality reports.

## [0.2.0] - 2026-09-20

### Added

- Repository Inventory script backed by the GitHub REST API.
- Repository existence, visibility, archive state, default branch, and latest Release discovery.
- JSON inventory output under `reports/repository-inventory.json`.
- JSON Schema validation for the generated repository inventory.
- GitHub Actions workflow for push, scheduled, and manual inventory runs.
- Optional dedicated `BROWSER_KITTY_GITHUB_TOKEN` support for cross-repository API rate limits without relying on the repository-scoped Actions token.
- Workflow artifact upload for generated inventory results.
- Warning detection for private repositories and registry/archive state mismatches.
- Reports documentation and generated-inventory ignore rule.

## [0.1.0] - 2026-09-18

### Added

- Initial Browser Kitty application registry in `apps.json`.
- Category definitions in `categories.json`.
- JSON Schema for registry structure and core field validation.
- PowerShell 7 registry validation script.
- GitHub Actions workflow for push, pull request, and manual validation.
- Initial registry entries for 11 existing Browser Kitty applications.
- Browser Kitty development guide under `standards/`.
