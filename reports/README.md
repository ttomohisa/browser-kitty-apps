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

Writes `reports/repository-releases.json`. It compares `apps.json` against each default branch's `app.config.json`, reuses Latest Release metadata from the inventory, and reads Git tag refs. `v1.2.3` and `1.2.3` are treated as equivalent tag forms.

A missing GitHub Release or a repository with no tags is valid. When Releases/tags exist, a version mismatch is reported as `WARN`; API/content lookup failures are `FAIL`.
