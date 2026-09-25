# Browser Kitty Apps

[日本語](README.ja.md)

[![Browser Kitty](https://img.shields.io/badge/Browser%20Kitty-open-16624F?style=flat-square)](https://browser-kitty.com/)
[![Repository health](https://github.com/ttomohisa/browser-kitty-apps/actions/workflows/repository-health.yml/badge.svg)](https://github.com/ttomohisa/browser-kitty-apps/actions/workflows/repository-health.yml)
[![Registry version](https://img.shields.io/badge/registry-v1.0.2-16624F?style=flat-square)](VERSION)
[![GitHub stars](https://img.shields.io/github/stars/ttomohisa/browser-kitty-apps?style=flat-square)](https://github.com/ttomohisa/browser-kitty-apps/stargazers)
[![License: MIT](https://img.shields.io/badge/license-MIT-16624F?style=flat-square)](LICENSE)

**Browser Kitty** is a collection of small tools that run in the browser. No account or installation is required. Tools are designed to process user files and data locally whenever their documented behavior allows it.

### [Open Browser Kitty →](https://browser-kitty.com/)

This repository is the public **app registry, health-check hub, and feedback entry point** for Browser Kitty. Each application remains in its own public repository; this repository is not a monorepo and is not a runtime dependency of the website.

## Feedback and ideas

You do not need to find the individual app repository before sending feedback. Start here and the issue can be routed to the right place if needed.

| I want to… | Link |
|---|---|
| Improve an existing tool | [Feature request](https://github.com/ttomohisa/browser-kitty-apps/issues/new?template=feature_request.yml) |
| Suggest a new browser tool | [New tool idea](https://github.com/ttomohisa/browser-kitty-apps/issues/new?template=new_tool.yml) |
| Report something broken | [Problem report](https://github.com/ttomohisa/browser-kitty-apps/issues/new?template=problem_report.yml) |
| See existing requests | [Issues](https://github.com/ttomohisa/browser-kitty-apps/issues) |
| Use the tools | [browser-kitty.com](https://browser-kitty.com/) |

### Star this repository

If Browser Kitty is useful to you, starring this repository is a simple way to show interest in the project. Stars and issue reactions are also useful signals when deciding which tools or improvements to work on next.

## What this repository manages

The source of truth for application code is each individual app repository. This parent repository manages the cross-app information needed by Browser Kitty:

- `apps.json` — application registry
- `categories.json` — shared category definitions
- `generated/apps.public.json` — deterministic build-time export for the Browser Kitty website
- repository inventory, asset, Pages, release, and runtime checks
- consolidated health reports
- release-readiness checks

Current production baseline: **75 published applications across 7 categories**.

```text
browser-kitty.com
       ↑
       | build-time data
generated/apps.public.json
       ↑
apps.json + categories.json
       |
       +---- repository health checks ----> htmlapps-* repositories
```

The Browser Kitty website consumes the public export at build time. Browser clients do not fetch this registry at runtime.

## Repository roles

| Repository | Role |
|---|---|
| `browser-kitty` | Private Browser Kitty website source |
| `browser-kitty-apps` | Public registry, health checks, automation, and feedback hub |
| `htmlapps-template` | Public application template |
| `htmlapps-*` | Public source repositories for individual applications |

## Contributing

Feedback, documentation fixes, registry corrections, and automation improvements are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

For changes to an individual application's implementation, the corresponding app repository is normally the best place for the code change. If you only know the Browser Kitty tool name, opening an issue here is fine.

Security-related reports should follow [SECURITY.md](SECURITY.md). Do not attach private or sensitive files to a public issue.

## Registry example

```json
{
  "id": "ffmpeg-filter-builder",
  "name": "FFmpeg Filter Builder",
  "nameJa": "FFmpeg Filter Builder",
  "repository": "ttomohisa/htmlapps-ffmpeg-filter-builder",
  "category": "video",
  "status": "stable",
  "browserKitty": {
    "published": true,
    "slug": "ffmpeg-filter-builder"
  },
  "release": {
    "version": "1.1.0"
  },
  "pages": {
    "url": "https://ttomohisa.github.io/htmlapps-ffmpeg-filter-builder/mt/"
  }
}
```

See [REGISTRY_SPEC.md](REGISTRY_SPEC.md) for the complete schema and policy.

## Local validation

PowerShell 7 is used for repository validation:

```powershell
./scripts/check-powershell.ps1
./scripts/check-registry.ps1
./scripts/generate-public-export.ps1 -Check
./scripts/check-release-candidate.ps1
```

Cross-repository health checks can also be run individually:

```powershell
./scripts/check-repositories.ps1
./scripts/check-assets.ps1
./scripts/check-pages.ps1
./scripts/check-releases.ps1
./scripts/check-runtime.ps1
./scripts/generate-report.ps1
```

GitHub Actions runs the same checks on changes and on the scheduled health workflow. `WARN` keeps maintenance debt visible without blocking the workflow; a blocking `FAIL` makes Repository Health fail.

## Public export

`generated/apps.public.json` contains only published, website-safe registry fields. It is derived from `apps.json` and `categories.json` and must not be edited manually.

After changing registry data:

```powershell
./scripts/generate-public-export.ps1
./scripts/generate-public-export.ps1 -Check
```

## Documentation

| Document | Purpose |
|---|---|
| [OPERATIONS.md](OPERATIONS.md) | Production operation and maintenance |
| [REGISTRY_SPEC.md](REGISTRY_SPEC.md) | Registry schema and policies |
| [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md) | Release-readiness checklist |
| [reports/README.md](reports/README.md) | Health report behavior |
| [standards/BROWSER_KITTY_GUIDE.md](standards/BROWSER_KITTY_GUIDE.md) | Shared Browser Kitty app guidance |
| [CHANGELOG.md](CHANGELOG.md) | Version history |

## v1.0.2

v1.0.2 keeps Repository Health available when GitHub's anonymous REST API quota is exhausted by falling back to public Git repository probes for repository existence and default-branch discovery. Documentation-only changes are handled by the lightweight validation workflow instead of triggering a full 75-repository health scan. See [CHANGELOG.md](CHANGELOG.md) for the full release history.

## License

MIT License. See [LICENSE](LICENSE).
