# Browser Kitty Apps Registry Specification

Version: 0.3.1 current / 1.0.0 target

## Purpose

`browser-kitty-apps` is the parent registry and operational inventory for Browser Kitty applications. It does not replace the individual application repositories and is not a monorepo.

The repository has four responsibilities:

1. Registry — keep machine-readable metadata for Browser Kitty applications.
2. Health checks — detect missing or inconsistent repository/publication state.
3. Automation — generate reports and data that can later be consumed by Browser Kitty.
4. Inventory — provide one place to see which applications exist and how they are published.

## Source of truth

- Application source code and current implementation: each application repository.
- Application registry metadata: `apps.json`.
- Browser Kitty-wide engineering and release rules: `standards/BROWSER_KITTY_GUIDE.md`.
- Browser Kitty website source: the separate private Browser Kitty repository.

The registry may mirror an application's current version or publication URL, but it must not become the source of truth for that application's code.

## Non-goals

- Moving application code into this repository.
- Git submodules for every application.
- Runtime shared JavaScript/CSS served from this repository.
- Automatic release or version changes in child repositories.
- Automatic writes to the private Browser Kitty website repository.

## Registry lifecycle

`development` → `rc` → `stable` → `maintenance` → `archived`

Not every application must pass through every state.

## Roadmap

- v0.1.0 — Registry Foundation
- v0.2.0 — Repository Inventory (implemented)
- v0.3.0 — Assets / Repository Quality (implemented)
- v0.3.1 — PowerShell CI parser hardening (implemented)
- v0.4.0 — GitHub Pages / Release
- v0.5.0 — Standalone / Runtime Metadata
- v0.6.0 — Repository Health Report
- v0.7.0 — Full Registry
- v0.8.0 — Browser Kitty Export
- v0.9.0 — Release Candidate
- v1.0.0 — Production Registry


## v0.2.0 implementation note

`check-repositories.ps1` implements the Repository Inventory milestone without changing the responsibility of individual application repositories. The script reads `apps.json`, queries the GitHub REST API, and writes a generated inventory containing repository existence, visibility, archive state, default branch, and latest Release metadata. Missing or inaccessible repositories fail the check; absence of a GitHub Release is recorded but is not treated as a failure at this stage. GitHub Pages reachability and Release version comparison remain scheduled for v0.4.0.


### Authentication note

The inventory does not rely on the built-in Actions `GITHUB_TOKEN` for child-repository reads because that token is scoped to the repository containing the workflow. Public child repositories are read anonymously by default. A dedicated `BROWSER_KITTY_GITHUB_TOKEN` secret may be configured later when the registry grows enough that anonymous API rate limits become a practical constraint.


## v0.3.1 implementation note

v0.3.1 is a CI reliability patch. PowerShell string interpolation in the GitHub API error path now delimits `${statusCode}` before a literal colon, avoiding a parser error on PowerShell 7. `check-powershell.ps1` was added as a syntax and strict UTF-8 preflight and is run before registry/inventory/quality checks in both workflows.


## v0.3.0 implementation note

`check-assets.ps1` implements the Repository Quality milestone. It consumes the generated v0.2.0 inventory for repository/default-branch information, then reads each default-branch Git tree through the GitHub REST API and produces `reports/repository-quality.json`. This avoids repeating repository metadata calls and keeps cross-repository API use predictable as the registry grows.

The quality policy follows the current Browser Kitty repository conventions rather than assuming Node is mandatory. `README.md`, `LICENSE`, `app.config.json`, and `assets/favicon.svg` are core requirements. `assets/screenshot.png` and `assets/screenshot-en.png` are required for published stable/maintenance applications and produce warnings during development/RC. `package.json` is recorded only as informational because the current `htmlapps-template` does not require it.

Repository quality has three states:

- `PASS` — required files are present and no quality warning was detected.
- `WARN` — the repository can continue through development, but a release-oriented item should be addressed or the Git tree result was truncated.
- `FAIL` — a required core/release file is missing or repository file inspection could not be completed.

GitHub Pages reachability and Release version comparison are intentionally left for v0.4.0.
