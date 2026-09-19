# Changelog

All notable changes to this repository are documented here.

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
