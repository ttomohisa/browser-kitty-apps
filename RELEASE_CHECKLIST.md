# Browser Kitty Apps Release Checklist

This checklist is for production releases of the parent `browser-kitty-apps` registry. Individual application UI/UX release checks remain the responsibility of each application repository and the Browser Kitty Guide.

## Release readiness gate

Run on PowerShell 7:

```powershell
./scripts/check-powershell.ps1
./scripts/check-registry.ps1
./scripts/generate-public-export.ps1 -Check
./scripts/generate-catalog.ps1 -Check
./scripts/test-generate-report.ps1
./scripts/check-release-candidate.ps1
```

The scheduled / on-change Repository Health workflow additionally runs:

```powershell
./scripts/check-release-candidate.ps1 -RequireHealthReport
```

The historical script/report names are retained for compatibility. From v1.0.0 onward this is the general production **release-readiness** gate. A release is acceptable when the report has **0 FAIL**. WARN items may remain only when they are non-blocking repository-hygiene or legacy-migration debt already represented by Repository Health. WARNs must remain visible; they are not silently suppressed.

## Registry

- `apps.json` matches its JSON Schema.
- App IDs and repositories are unique.
- Categories referenced by applications exist.
- Registered versions are valid Semantic Versions.
- Published applications have a Browser Kitty slug and HTTPS application URL.
- Published applications are `stable` or `maintenance`, not `development` / `rc`.
- Runtime capability flags are explicit.
- Cross-origin-isolated applications declare the required hosting metadata.

## Repository Health

- All registered repositories can be inventoried.
- No application has final health `FAIL`.
- Pages reachability has no blocking failure.
- Standard repositories have required repository metadata.
- Hard runtime / standalone contradictions have no blocking failure.
- WARN count and reasons are retained for follow-up.

## Human-readable views

- `CATALOG.md` is current and matches `apps.json` / `categories.json`.
- `STATUS.md` exists as an explicitly dated snapshot.
- Repository Health generates a fresh `STATUS.md` and publishes it in the Actions Job Summary.
- Human-readable views are derived outputs; they do not replace Registry or Health JSON sources of truth.

## Browser Kitty export

- `generated/apps.public.json` is current.
- Public export matches `schema/public-apps.schema.json`.
- Published application count matches the registry.
- Export does not include internal repository-profile, build-path, hosting-header, or health-report fields.
- Browser Kitty consumes the export at build time; browser runtime must not depend on this repository.

## Repository release metadata

- `VERSION` is the intended release version.
- The first version heading in `README.md` matches `VERSION`.
- The first release entry in `CHANGELOG.md` matches `VERSION`.
- `REGISTRY_SPEC.md` current production version matches `VERSION`.
- `LICENSE`, `README.md`, `README.ja.md`, `CATALOG.md`, `STATUS.md`, `CHANGELOG.md`, `REGISTRY_SPEC.md`, `OPERATIONS.md`, schemas, workflows, scripts, and generated export are present.

## CI

- `Validate registry` passes.
- `Repository health` passes.
- Release-readiness reports are uploaded with Repository Health artifacts.
- PowerShell parser / UTF-8 preflight passes for every `.ps1` file.
- Health-report smoke test passes.

## Production baseline

v1.0.0 establishes the production baseline with 75 registered/published applications and seven categories. Promotion requires complete Repository Health coverage and zero blocking FAILs. Existing non-blocking WARNs may remain when they are explicitly visible and do not indicate a broken published application.

## Subsequent releases

For each parent-registry release:

1. Update `VERSION`.
2. Add the matching top sections to `README.md` and `CHANGELOG.md`.
3. Update the current version in `REGISTRY_SPEC.md`.
4. Regenerate `generated/apps.public.json` if registry/public data changed.
5. Regenerate `CATALOG.md` when registry/category data changed and refresh the committed `STATUS.md` snapshot from a recent successful health run when practical.
6. Run the static release-readiness gate.
7. Require both GitHub Actions workflows to pass.
8. Release only with 0 blocking FAILs.

Use Semantic Versioning: patch for backward-compatible fixes/metadata corrections, minor for additive registry/schema/export capabilities, and major for intentional incompatible contract changes.
