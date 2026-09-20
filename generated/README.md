# Generated public data

Files in this directory are derived from the registry and are not edited by hand.

`apps.public.json` is the build-time public export for the private Browser Kitty website repository. Regenerate it with:

```powershell
./scripts/generate-public-export.ps1
```

CI verifies that the committed export matches `apps.json` and `categories.json`:

```powershell
./scripts/generate-public-export.ps1 -Check
```

The Browser Kitty website should consume this file at build time and publish its own static output. Browser Kitty pages and tools should not add a runtime dependency on this repository.
