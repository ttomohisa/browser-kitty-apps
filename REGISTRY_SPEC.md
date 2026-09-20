# Browser Kitty Apps Registry Specification

Version: 1.0.0 production

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
- v0.4.0 — GitHub Pages / Release (implemented)
- v0.5.0 — Standalone / Runtime Metadata (implemented)
- v0.6.0 — Repository Health Report (implemented)
- v0.6.2 — Empty-collection binding fix / report smoke test (implemented)
- v0.7.2 — Face Redactor Pages correction (implemented)
- v0.7.1 — Full Registry health-policy calibration (implemented)
- v0.7.0 — Full Registry / scalable health checks (implemented)
- v0.8.0 — Browser Kitty Export (implemented)
- v0.9.0 — Release Candidate (implemented)
- v1.0.0 — Production Registry (implemented)



## v1.0.0 production contract

v1.0.0 promotes the registry to the production operating baseline. `apps.json` is the parent registry metadata source, while each child repository remains the source of truth for its application implementation and application-specific release. `generated/apps.public.json` is the stable build-time export for the private Browser Kitty website repository and must not be fetched by tools at browser runtime.

Production readiness requires the registry/export contracts to validate, all published applications to remain in a release lifecycle state, complete live health coverage, and **0 blocking FAILs**. Repository-hygiene and legacy-migration WARNs may remain when they are explicitly represented in Repository Health; they are follow-up work rather than false outages. The historical `check-release-candidate.ps1` and `release-candidate.*` names are retained for compatibility and serve as the general release-readiness gate from v1.0.0 onward.

`OPERATIONS.md` defines the steady-state add/update flow, scheduled-health handling, legacy migration, authentication, release policy, and incident response. Production changes continue to follow Semantic Versioning. The parent registry must not automatically rewrite child repositories or the private Browser Kitty website repository.

## v0.9.0 implementation note

The Release Candidate milestone adds `VERSION`, `RELEASE_CHECKLIST.md`, `schema/release-candidate.schema.json`, and `scripts/check-release-candidate.ps1`. The RC gate verifies release-version consistency across repository documentation, required release files, registry/public-export coverage, published lifecycle state, and—when run by Repository Health—the consolidated live health report.

RC policy is intentionally strict about blocking failures without converting repository-hygiene debt into false outages: a candidate requires **0 FAIL**, while existing non-blocking WARNs remain visible in the RC JSON/Markdown output. `Validate registry` runs the static RC gate; `Repository health` runs it again with `-RequireHealthReport` and publishes the resulting RC reports with the health artifact.

## v0.2.0 implementation note

`check-repositories.ps1` implements the Repository Inventory milestone without changing the responsibility of individual application repositories. The script reads `apps.json`, queries the GitHub REST API, and writes a generated inventory containing repository existence, visibility, archive state, default branch, and latest Release metadata. Missing or inaccessible repositories fail the check; absence of a GitHub Release is recorded but is not treated as a failure. v0.4.0 consumes this inventory for release/version consistency checks.


### Authentication note

The inventory does not rely on the built-in Actions `GITHUB_TOKEN` for child-repository reads because that token is scoped to the repository containing the workflow. Public child repositories are read anonymously by default. A dedicated `BROWSER_KITTY_GITHUB_TOKEN` secret may be configured later when the registry grows enough that anonymous API rate limits become a practical constraint.






## v0.6.1 implementation note

PowerShell mandatory collection parameters reject an empty collection unless the parameter explicitly allows it. The initial v0.6.0 report generator passed an empty `List[object]` for `GlobalIssues` on the normal all-clear path, which caused parameter binding to fail before report generation. v0.6.1 adds `[AllowEmptyCollection()]` to collection parameters that legitimately receive empty collections.

A new `test-generate-report.ps1` smoke test constructs five all-PASS source reports with empty warning/issue arrays, runs `generate-report.ps1`, and asserts `overallStatus=PASS`, zero global issues, and complete application coverage.


## v0.6.0 implementation note

`generate-report.ps1` consolidates the inventory, quality, Pages, release/version, and runtime reports into `reports/repository-status.json` and `reports/repository-status.md`. The JSON report is validated by `schema/repository-health.schema.json`; the Markdown report is designed for direct inspection in CI artifacts.

Each application receives one final `PASS / WARN / FAIL` result plus the five component states. Source issue objects retain their originating check, code, message, and optional path so the final report remains actionable rather than reducing failures to a single count. If a required source report is missing or cannot be parsed, the source is marked unavailable, affected per-app checks become `UNKNOWN`, and the consolidated result becomes `FAIL`.

The Repository Health workflow treats the five lower-level checks as collectors by using `continue-on-error`. This prevents an early repository failure from hiding Pages, release, or runtime results for the remaining applications. The consolidated report step is the final CI gate: warnings are visible but do not fail the job; any application failure or global source-report failure returns exit code 1. Report upload runs with `if: always()` so diagnostics are retained even on failed health runs.

## v0.5.0 implementation note

`check-runtime.ps1` validates runtime declarations without turning source-code heuristics into a source of truth. Every registered app must explicitly declare `crossOriginIsolated`, `requiresWasm`, `requiresWorker`, `requiresWebGPU`, and `requiresWebCodecs`. The checker compares `runtime.standalonePath` with build outputs exposed by `app.config.json`, checks `networkAccess=false` against `build.blockRuntimeNetwork=true`, and validates COOP / COEP / CORP declarations for cross-origin-isolated apps.

When `dependencies.json` exists, WASM and worker assets are treated as supporting evidence. A manifest that clearly contains a WASM/worker asset while the registry declares the corresponding capability as false produces a warning. The reverse is intentionally not treated as an error, because an application may embed or generate runtime assets through a different build path. This keeps the registry fact-based and avoids unreliable inference from arbitrary source strings.

The Repository Health workflow now produces five schema-validated reports: inventory, quality, Pages, release/version, and runtime metadata. Runtime validation reuses the release report's `app.config.json` build metadata and reads optional dependency manifests through public raw content so the same per-repository REST API data is not fetched twice.

## v0.4.0 implementation note

`check-pages.ps1` checks the `pages.url` registered for every application. Published applications must resolve through redirects to HTTP 2xx. The checker uses `HttpClient` with `ResponseHeadersRead`: `HEAD` is preferred and a headers-only `GET` is used only when a server returns 405/501. This avoids downloading large standalone HTML files during scheduled health checks. Successful non-HTML content types are reported as `WARN`.

`check-releases.ps1` consumes `repository-inventory.json` and compares the registry version with the default branch's `app.config.json`. It also compares the latest GitHub Release tag when a Release exists and checks Git tag refs for a tag matching the registered version. `1.2.3` and `v1.2.3` are equivalent. Browser Kitty does not require every app repository to create GitHub Releases or tags, so absence is valid; an existing version mismatch is `WARN`, while lookup/parse failures are `FAIL`.

The Repository Health workflow now produces four schema-validated reports: inventory, quality, Pages, and release/version consistency. All four are uploaded together as a 14-day workflow artifact.

## v0.3.1 implementation note

v0.3.1 is a CI reliability patch. PowerShell string interpolation in the GitHub API error path now delimits `${statusCode}` before a literal colon, avoiding a parser error on PowerShell 7. `check-powershell.ps1` was added as a syntax and strict UTF-8 preflight and is run before registry/inventory/quality checks in both workflows.


## v0.3.0 implementation note

`check-assets.ps1` implements the Repository Quality milestone. It consumes the generated v0.2.0 inventory for repository/default-branch information, then reads each default-branch Git tree through the GitHub REST API and produces `reports/repository-quality.json`. This avoids repeating repository metadata calls and keeps cross-repository API use predictable as the registry grows.

The quality policy follows the current Browser Kitty repository conventions rather than assuming Node is mandatory. `README.md`, `LICENSE`, and a standard-profile `app.config.json` are blocking requirements. `assets/favicon.svg`, `assets/screenshot.png`, and `assets/screenshot-en.png` are release-hygiene assets; missing files are reported as WARN so historical cleanup debt does not masquerade as an application outage. `package.json` is recorded only as informational because the current `htmlapps-template` does not require it.

Repository quality has three states:

- `PASS` — required files are present and no quality warning was detected.
- `WARN` — the repository can continue through development, but a release-oriented item should be addressed or the Git tree result was truncated.
- `FAIL` — a required core/release file is missing or repository file inspection could not be completed.

GitHub Pages reachability and Release/version consistency are implemented in v0.4.0.

## v0.6.2 smoke-test execution note

The health-report smoke test must not assume `$LASTEXITCODE` exists after invoking another PowerShell script. Under strict mode, a successful PowerShell script that does not run a native command may leave `$LASTEXITCODE` unset. The smoke test therefore captures `$?` immediately after invoking `generate-report.ps1`.

The Repository Health workflow gives the smoke step `continue-on-error` only to preserve diagnostics: Inventory, Quality, Pages, Release/version, Runtime, the consolidated report, and artifact upload still run. A final enforcement step checks `steps.health-report-smoke.outcome` and fails the job when the smoke test failed. The Validate Registry workflow continues to fail immediately on a smoke-test failure.




## v0.8.0 Browser Kitty Export

`generated/apps.public.json` is the stable, build-time data contract between this public registry and the separate private Browser Kitty website repository. It is generated from `apps.json` and `categories.json`; it is never an independent source of truth.

The export includes only applications with `browserKitty.published=true`. Public fields are intentionally limited to identity, names, slug, category, lifecycle status, version, application URL, source repository URL, and runtime/privacy capability declarations that Browser Kitty may need to render factual UI. Repository migration state, build paths, hosting headers, template metadata, and health findings remain internal to registry operations and are not exported.

The output deliberately omits timestamps so identical registry inputs produce byte-stable JSON. Category and app ordering follows the source registry order. Breaking changes to the public shape require a `schemaVersion` change and a corresponding update to `schema/public-apps.schema.json`.

`generate-public-export.ps1` writes the committed export, while `generate-public-export.ps1 -Check` regenerates the expected content in memory and fails when the committed file is missing or stale. Validate Registry runs this check on changes to registry, schema, scripts, or generated output.

Browser Kitty should consume this export at build time and emit its own static pages. The public website and individual tools must not fetch this registry during browser runtime; this preserves Browser Kitty's no-unnecessary-runtime-dependency principle.

## v0.7.2 Pages deployment correction

The Full Registry keeps published GitHub Pages reachability as a blocking check. Face Redactor uses the canonical repository-root Pages URL because its standard deployment publishes `dist/index.html` as the site root. A missing or disabled Pages deployment remains `FAIL`; the registry must not hide it by weakening the check.

## v0.7.1 Health gate calibration

The first live 75-app health run showed that repository hygiene debt and application availability must be separated. The consolidated CI gate therefore treats missing `assets/favicon.svg`, `assets/screenshot.png`, and `assets/screenshot-en.png` as `WARN`. Missing `README.md`, `LICENSE`, a standard-profile `app.config.json`, unavailable repositories, published Pages failures, and hard runtime contradictions remain `FAIL`.

Runtime dependency inspection accepts all dependency-manifest layouts already present in Browser Kitty: an `assets` array, a single `asset` object, or a `files` array. Dependency evidence is advisory metadata evidence; the Registry remains the explicit source for capability flags.

## v0.7.0 Full Registry notes

The registry now distinguishes `repositoryProfile: standard` from `repositoryProfile: legacy`. Standard repositories are expected to provide `app.config.json`; legacy repositories may omit it while migration remains pending. Legacy omission is a warning, not a repository-unavailable failure.

Full-registry health checks must remain usable without exhausting GitHub's unauthenticated REST quota. Repository metadata is therefore fetched in owner-sized pages, asset presence is checked through throttled raw-file HEAD requests, and release/tag inspection is separated from repository inventory. Templates, builder repositories, shared cores, and duplicate repository aliases are not application entries.
