# Contributing to Browser Kitty Apps

Thanks for helping improve Browser Kitty.

This repository is both the public registry for Browser Kitty applications and a common entry point for feedback. You do not need to know which individual app repository owns a feature before opening an issue here.

## Choose the right place

- **Feature request for an existing tool:** open a [Feature request](https://github.com/ttomohisa/browser-kitty-apps/issues/new?template=feature_request.yml).
- **Idea for a new tool:** open a [New tool idea](https://github.com/ttomohisa/browser-kitty-apps/issues/new?template=new_tool.yml).
- **Something is broken:** open a [Problem report](https://github.com/ttomohisa/browser-kitty-apps/issues/new?template=problem_report.yml).
- **Registry, documentation, health-check, or automation change:** a pull request to this repository is appropriate.
- **Implementation change to one specific app:** the app's own `htmlapps-*` repository is usually the best place for the code change.

If you are unsure, open the issue here. It can be routed later.

## Before opening an issue

Please include the Browser Kitty tool name or URL when the request is about a specific tool. Describe the task you want to complete and what currently gets in the way. Screenshots are useful when they do not contain private information.

Do not upload confidential documents, personal data, passwords, API keys, or other sensitive files to a public issue.

Security-related reports should follow [SECURITY.md](SECURITY.md).

## Pull requests

Keep pull requests focused. For registry changes:

1. Edit `apps.json` and/or `categories.json`.
2. Do not edit `generated/apps.public.json` by hand.
3. Regenerate the public export.
4. Run the validation scripts.

```powershell
./scripts/check-powershell.ps1
./scripts/check-registry.ps1
./scripts/generate-public-export.ps1
./scripts/generate-public-export.ps1 -Check
./scripts/check-release-candidate.ps1
```

For documentation-only changes, keep the existing release version unless the repository itself is being released.

## Browser Kitty principles

Contributions should preserve the Browser Kitty operating model:

- tools should work in the browser without account registration or installation where practical
- user files and data should be processed locally unless a tool explicitly documents otherwise
- runtime external dependencies should be minimized, especially for standalone HTML builds
- mobile usability matters alongside desktop usability
- privacy claims should describe actual behavior rather than overstate it

See [standards/BROWSER_KITTY_GUIDE.md](standards/BROWSER_KITTY_GUIDE.md) for the shared implementation guidance.
