# Browser Kitty Apps Registry Specification

Version: 0.1.0 foundation / 1.0.0 target

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
- v0.2.0 — Repository Inventory
- v0.3.0 — Assets / Repository Quality
- v0.4.0 — GitHub Pages / Release
- v0.5.0 — Standalone / Runtime Metadata
- v0.6.0 — Repository Health Report
- v0.7.0 — Full Registry
- v0.8.0 — Browser Kitty Export
- v0.9.0 — Release Candidate
- v1.0.0 — Production Registry
