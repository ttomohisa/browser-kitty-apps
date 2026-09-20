# Reports

`reports/` contains generated output from Browser Kitty Apps registry checks. Generated JSON files are not committed; GitHub Actions uploads them as the `browser-kitty-repository-health` artifact.

## Repository inventory

```powershell
./scripts/check-repositories.ps1
```

Writes `reports/repository-inventory.json` with repository existence, visibility, archive state, default branch, and latest GitHub Release metadata. Public repositories work anonymously. `BROWSER_KITTY_GITHUB_TOKEN` is optional when a higher cross-repository API rate limit is needed.

## Repository quality

```powershell
./scripts/check-assets.ps1
```

Writes `reports/repository-quality.json`. It checks `README.md`, `LICENSE`, `app.config.json`, `assets/favicon.svg`, Japanese/default and English screenshots, plus informational `package.json` presence. The result is `PASS`, `WARN`, or `FAIL`.

## GitHub Pages

```powershell
./scripts/check-pages.ps1
```

Writes `reports/repository-pages.json`. Published applications must resolve through redirects to a 2xx HTTP response. The checker uses `HEAD` and falls back to a headers-only `GET` when the server rejects `HEAD`, avoiding full standalone HTML downloads. A successful non-HTML content type is reported as `WARN`.

## Release and version consistency

```powershell
./scripts/check-releases.ps1
```

Writes `reports/repository-releases.json`. It compares `apps.json` against each default branch's `app.config.json`, reuses Latest Release metadata from the inventory, and reads Git tag refs. `app.config.json` is fetched from public raw content so it does not consume another GitHub REST API request per app. `v1.2.3` and `1.2.3` are treated as equivalent tag forms.

A missing GitHub Release or a repository with no tags is valid. When Releases/tags exist, a version mismatch is reported as `WARN`; API/content lookup failures are `FAIL`.

## Standalone and runtime metadata

```powershell
./scripts/check-runtime.ps1
```

Writes `reports/repository-runtime.json`. It reuses `app.config.json` build metadata already recorded in `repository-releases.json` and, when present, reads `dependencies.json` from public raw content. This avoids duplicate GitHub REST API calls.

Checks include:

- `runtime.standalonePath` matches a declared build output (`output`, `multiThreadOutput`, or self-extract output).
- `runtime.networkAccess=false` is consistent with `build.blockRuntimeNetwork=true`.
- cross-origin-isolated apps declare COOP, COEP, and CORP hosting requirements.
- `dependencies.json` WebAssembly/worker assets do not contradict `requiresWasm` / `requiresWorker` flags.

The capability flags are declarations, not heuristic guesses. Absence of detectable evidence does not make a declared capability fail; the checker only flags contradictions it can support from repository metadata.
