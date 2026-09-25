# Browser Kitty Apps Operations

This document defines the steady-state operating procedure for the production `browser-kitty-apps` registry.

The registry coordinates metadata and health checks. It does not replace child repositories, automatically edit application code, or become a runtime dependency of Browser Kitty.

## Source of truth

- Application implementation and application-specific release state: each child application repository.
- Registry metadata used for cross-application operations: `apps.json`.
- Categories: `categories.json`.
- Browser Kitty-wide engineering rules: `standards/BROWSER_KITTY_GUIDE.md`.
- Browser Kitty website implementation: the separate private Browser Kitty repository.
- Browser Kitty build-time application feed: `generated/apps.public.json`, generated from this registry.

## Normal change flow

For a registry-only change:

1. Update `apps.json` and/or `categories.json`.
2. If public application data changed, regenerate the public export:

   ```powershell
   ./scripts/generate-public-export.ps1
   ```

3. Run local static checks with PowerShell 7:

   ```powershell
   ./scripts/check-powershell.ps1
   ./scripts/check-registry.ps1
   ./scripts/generate-public-export.ps1 -Check
   ./scripts/test-generate-report.ps1
   ./scripts/check-release-candidate.ps1
   ```

4. Push the change and require both GitHub Actions workflows to pass:
   - `Validate registry`
   - `Repository health`
5. Inspect the Repository Health artifact when WARNs or unexpected changes appear.

Do not manually edit `generated/apps.public.json`. It is derived data.

## Adding an application

Before adding a new Browser Kitty application, confirm its public repository and current application metadata. Prefer the application's `app.config.json` when available.

Add the application to `apps.json` with:

- unique `id`
- unique `repository`
- valid category
- explicit lifecycle `status`
- Browser Kitty publication state and slug
- current application version
- canonical public Pages URL
- explicit runtime capability flags
- `repositoryProfile: standard` for current template-era repositories

Use `repositoryProfile: legacy` only for an already-published older repository that genuinely lacks the standard metadata contract. Legacy is a migration state, not the default for new applications.

After editing the registry, regenerate the public export and run the normal change flow above.

## Updating an application

When an application version, public URL, runtime requirement, or publication status changes:

1. Verify the child repository first.
2. Update only the mirrored registry fields that changed.
3. Regenerate the public export if a public field changed.
4. Run the static checks and Repository Health.

The parent registry must not automatically bump versions or rewrite child repositories.

## Health policy

Repository Health combines five source checks:

- repository inventory
- repository quality
- GitHub Pages
- release/version consistency
- standalone/runtime metadata

The final states are:

- `PASS` — no detected issue.
- `WARN` — non-blocking hygiene, legacy-migration, or consistency debt that remains visible for follow-up.
- `FAIL` — a blocking problem such as a missing repository, broken published Pages URL, required standard metadata missing, or a hard runtime/standalone contradiction.

Production policy requires **0 FAIL**. WARNs are not silently suppressed and should be reduced when the relevant child repository is next maintained.

GitHub Pages probes use bounded retries only for transient request failures and HTTP `408`, `425`, `429`, `500`, `502`, `503`, and `504`. The default is three attempts with a short linear backoff. Persistent responses such as `404` are not retried and remain blocking for published applications. This prevents a momentary hosting-side `503` from becoming a false production outage while preserving real failure detection.

## Scheduled checks

`.github/workflows/repository-health.yml` runs on registry/runtime/checker changes, release-version changes, manual dispatch, and the scheduled cron. Documentation-only changes are handled by `Validate registry` and do not trigger a second full scan of all child repositories. The health workflow collects all source reports even when an individual source check reports an error, then uses the consolidated health report as the final health result.

Generated reports are uploaded as the `browser-kitty-repository-health` Actions artifact and are not committed to the repository.

## Public export

`generated/apps.public.json` is the stable build-time feed for the private Browser Kitty website repository.

Browser Kitty should consume this file during its build and publish its own static output. Browser pages and tools must not fetch this registry at browser runtime.

The export intentionally omits internal repository-profile, build-path, hosting-header, and health-report details.

## GitHub authentication

Public child repositories are checked anonymously where practical. Repository Inventory prefers the owner-batched GitHub REST API. If that request is unavailable or rate-limited, it falls back to `git ls-remote --symref` for each public child repository so existence and default-branch checks can continue. REST-only metadata is recorded as unavailable with a warning rather than converted into false application failures.

`BROWSER_KITTY_GITHUB_TOKEN` remains optional. Configure it when complete cross-repository REST metadata is desired reliably or if anonymous API quota pressure becomes frequent; the fallback keeps core health monitoring functional without requiring a secret.

Do not place tokens, credentials, private Browser Kitty repository contents, or user data in this public registry.

## Legacy repositories

Legacy repositories remain registered when they are real published Browser Kitty applications but do not yet implement the standard metadata contract.

When a legacy repository is modernized:

1. Add/verify current `app.config.json` and template-era repository metadata in the child repository.
2. Confirm Pages and standalone behavior.
3. Change `repositoryProfile` from `legacy` to `standard` in `apps.json`.
4. Regenerate the public export if public fields changed.
5. Run Repository Health and confirm no new blocking failure.

## Repository releases

The parent registry uses Semantic Versioning.

- Patch: checker fixes, metadata corrections, documentation fixes, or other backward-compatible production maintenance.
- Minor: backward-compatible registry/schema/export capabilities.
- Major: intentionally incompatible registry or public-export contract changes.

For every parent-repository release:

1. Update `VERSION`.
2. Add the matching top section to `README.md` and `CHANGELOG.md`.
3. Update the current version in `REGISTRY_SPEC.md`.
4. Regenerate public data if required.
5. Run the release-readiness gate locally.
6. Require both GitHub Actions workflows to pass.
7. Release only with 0 blocking FAILs.

The historical script/report names `check-release-candidate.ps1` and `release-candidate.*` are retained for compatibility; from v1.0.0 onward they serve as the general release-readiness gate.

## Incident handling

If Repository Health reports a new FAIL:

1. Read `reports/repository-status.md` from the workflow artifact.
2. Identify the source check and exact issue code/message.
3. Verify whether the child application is actually unavailable or whether the registry metadata is stale.
4. Fix the source of truth first:
   - child repository for application/deployment problems
   - `apps.json` for stale parent metadata
   - checker logic only when the check itself is incorrect
5. Do not downgrade a real outage to WARN merely to make CI green.
6. Rerun Repository Health after the fix.
