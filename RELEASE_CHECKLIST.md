# Browser Kitty Apps Release Checklist

This checklist is for the parent `browser-kitty-apps` registry. Individual application UI/UX release checks remain the responsibility of each application repository and the Browser Kitty Guide.

## Release Candidate gate

Run on PowerShell 7:

```powershell
./scripts/check-powershell.ps1
./scripts/check-registry.ps1
./scripts/generate-public-export.ps1 -Check
./scripts/test-generate-report.ps1
./scripts/check-release-candidate.ps1
```

The scheduled / on-change Repository Health workflow additionally runs:

```powershell
./scripts/check-release-candidate.ps1 -RequireHealthReport
```

A release candidate is acceptable when the RC report has **0 FAIL**. WARN items are allowed only when they are non-blocking repository-hygiene or legacy-migration debt already represented by Repository Health. WARNs must remain visible in the generated report; they are not silently suppressed.

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
- `REGISTRY_SPEC.md` current version matches `VERSION`.
- `LICENSE`, `README.md`, `CHANGELOG.md`, `REGISTRY_SPEC.md`, schemas, workflows, scripts, and generated export are present.

## CI

- `Validate registry` passes.
- `Repository health` passes.
- RC reports are uploaded with Repository Health artifacts.
- PowerShell parser / UTF-8 preflight passes for every `.ps1` file.
- Health-report smoke test passes.

## v1.0.0 promotion

For v1.0.0, update `VERSION`, the top README version section, `CHANGELOG.md`, and `REGISTRY_SPEC.md`, regenerate the public export if registry data changed, then run both GitHub Actions workflows. Promote only with 0 blocking FAILs. Existing non-blocking WARNs may remain when they are explicitly visible in Repository Health and do not indicate a broken published application.
