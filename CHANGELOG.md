# Changelog

All notable changes to this repository are documented here.

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
