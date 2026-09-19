# Browser Kitty Apps

Browser Kittyで公開している各アプリを、独立したGitHub Repositoryのまま一元管理するためのRegistryです。

このRepositoryはmonorepoではありません。各アプリのソースコード・Release・GitHub Pagesは従来どおり各Repositoryで管理し、ここではアプリ一覧、公開情報、実行条件、今後のRepository Health Checkに必要なメタデータを管理します。

## v0.4.0

v0.4.0 adds publication and version-consistency checks on top of the Registry, Repository Inventory, and Repository Quality checks. GitHub Pages URLs are checked without downloading the full standalone HTML, and registry versions are compared with each repository's `app.config.json`, latest GitHub Release when present, and Git tag refs.

- `apps.json` — Browser Kitty application registry
- `categories.json` — category definitions
- `schema/apps.schema.json` — registry JSON Schema
- `schema/repository-inventory.schema.json` — repository inventory JSON Schema
- `schema/repository-quality.schema.json` — repository quality JSON Schema
- `schema/repository-pages.schema.json` — GitHub Pages report JSON Schema
- `schema/repository-releases.schema.json` — release/version report JSON Schema
- `scripts/check-registry.ps1` — registry validation
- `scripts/check-powershell.ps1` — PowerShell syntax / strict UTF-8 preflight
- `scripts/check-repositories.ps1` — repository existence / visibility / archive / default branch / latest Release inventory
- `scripts/check-assets.ps1` — README / LICENSE / app.config / favicon / screenshot quality check
- `scripts/check-pages.ps1` — published Pages reachability and response check
- `scripts/check-releases.ps1` — registry / app.config / Release / tag version consistency check
- `.github/workflows/repository-health.yml` — scheduled and on-change health checks
- `reports/README.md` — generated report behavior
- `standards/BROWSER_KITTY_GUIDE.md` — Browser Kitty shared guide

The registry currently contains 11 representative applications. Full migration is planned by v0.7.0.

## Registry

`apps.json` の1アプリは次のような構造です。

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
  },
  "runtime": {
    "standalone": true,
    "standalonePath": "dist/index.mt.html",
    "localProcessing": true,
    "networkAccess": false,
    "crossOriginIsolated": true,
    "requiresWasm": true,
    "requiresWorker": true,
    "requiresWebGPU": false,
    "requiresWebCodecs": false
  }
}
```

## Initial applications

| App | Version | Category | Repository |
|---|---:|---|---|
| PPTX Diff | 1.0.0 | Presentation | `htmlapps-pptx-diff` |
| PDF Review Notes | 1.0.0 | PDF | `htmlapps-pdf-review-notes` |
| Data Pipeline Builder | 1.0.0 | Data | `htmlapps-data-pipeline-builder` |
| FFmpeg Filter Builder | 1.1.0 | Video | `htmlapps-ffmpeg-filter-builder` |
| Planner Refill Maker | 1.0.0 | Print | `htmlapps-planner-refill-maker` |
| Label Sheet Maker | 1.0.0 | Print | `htmlapps-label-sheet-maker` |
| NFC Tap Log | 1.0.0 | Utility | `htmlapps-nfc-tap-log` |
| Pass-the-Phone Vote | 1.0.0 | Utility | `htmlapps-pass-the-phone-vote` |
| PPTX Version Control | 1.1.2 | Presentation | `htmlapps-pptx-version-control` |
| Image Counter | 1.0.0 | Image | `htmlapps-image-counter` |
| Local Video Compressor | 1.3.1 | Video | `htmlapps-video-compressor` |

The initial versions above were read from the current `app.config.json` files in the corresponding repositories when v0.1.0 was prepared.

## Validate locally

PowerShell 7で実行します。

```powershell
./scripts/check-registry.ps1
```

検証内容:

- JSON構文
- JSON Schema
- アプリID重複
- Repository重複
- Semantic Versioning
- 未定義カテゴリ
- GitHub Pages URL形式
- 公開アプリのslug
- Standalone HTML path
- `crossOriginIsolated`を記録した場合のhosting設定との整合性

## Repository inventory

PowerShell 7からGitHub APIへアクセスし、`apps.json`に登録した各Repositoryの現在状態を取得できます。

```powershell
./scripts/check-repositories.ps1
```

`BROWSER_KITTY_GITHUB_TOKEN` が設定されている場合はBearer tokenとして使用し、未設定の場合はGitHubの公開APIへ匿名アクセスします。tokenそのものは出力しません。Actions標準の`GITHUB_TOKEN`は親Repository内のリソースに限定されるため、子Repository横断Inventoryの認証には使用しません。

既定の出力先:

```text
reports/repository-inventory.json
```

取得内容:

- Repositoryの存在
- Public / Private
- Archived
- Default branch
- Repository URL
- `pushed_at` / `updated_at`
- Latest Releaseの有無・取得状態・基本情報

Repositoryが見つからない、またはRepository lookup自体に失敗した場合はexit code 1とします。Private / Archiveの状態不整合はwarningとしてInventoryへ残します。Latest Releaseが存在しない404は`releaseLookupStatus: none`として正常に記録します。一方、Release APIの認証・rate limit・サーバーエラーなどで取得自体に失敗した場合は`error`としてCIを失敗させます。

GitHub Actionsでは `repository-health.yml` がPush・定期実行・手動実行に対応します。現在の11Repoは匿名APIでも必要リクエスト数が小さいためそのまま動作します。登録数が増えてAPI rate limitが問題になる場合は、必要な公開Repositoryを読める専用tokenをRepository Secret `BROWSER_KITTY_GITHUB_TOKEN` として任意設定します。

## Repository quality

Repository Inventoryを生成したあと、次を実行します。

```powershell
./scripts/check-assets.ps1
```

既定の出力先:

```text
reports/repository-quality.json
```

判定は `PASS / WARN / FAIL` の3段階です。

**必須ファイル:**

- `README.md`
- `LICENSE`
- `app.config.json`
- `assets/favicon.svg`

これらが欠けた場合は `FAIL` です。

`assets/screenshot.png` と `assets/screenshot-en.png` は、Browser Kittyへ公開済みの `stable` / `maintenance` アプリではリリース品質要件として扱い、欠けた場合は `FAIL` とします。`development` / `rc` ではリリース前に追加すべき項目として `WARN` に留めます。

`package.json` は存在確認だけ行います。現在の `htmlapps-template` はNode/package.jsonを必須としていないため、存在しなくても警告・失敗にはしません。

`check-assets.ps1` は `reports/repository-inventory.json` のdefault branch情報を再利用し、同じRepository metadataを重複取得しません。これにより横断チェック時のGitHub API消費を抑えます。

## GitHub Pages

公開URLは次で確認します。

```powershell
./scripts/check-pages.ps1
```

既定の出力先は `reports/repository-pages.json` です。公開済みアプリはredirect後にHTTP 2xxへ到達することを必須とします。巨大な単一HTMLを毎回取得しないよう、通常は`HEAD`だけを送り、サーバーが`HEAD`を拒否した場合だけheaders-onlyの`GET`へフォールバックします。HTML以外のContent-Typeで成功した場合は`WARN`です。

## Release / version consistency

```powershell
./scripts/check-releases.ps1
```

既定の出力先は `reports/repository-releases.json` です。次を横断確認します。

- `apps.json` の `release.version`
- default branchの `app.config.json` version
- Latest GitHub Release tag（存在する場合）
- Git tag refs（存在する場合）

GitHub Releaseやtagそのものは必須ではありません。存在する場合にだけRegistry版との不一致を`WARN`として検出します。tagは `1.2.3` と `v1.2.3` を同じversionとして扱います。GitHub API取得失敗や `app.config.json` の取得・解析失敗は`FAIL`です。

GitHub ActionsではInventory / Quality / Pages / Releaseの4 JSONを14日間Artifact保存します。各JSONは専用Schemaで検証します。

## Add an application

1. `categories.json` に対象カテゴリがあることを確認します。
2. `apps.json` にアプリを追加します。
3. `./scripts/check-registry.ps1` を実行します。
4. Pull Request / PushのGitHub Actionsが成功することを確認します。

`generated/` のような将来の生成物をRegistryの一次情報として手編集する設計にはしません。

## Repository roles

```text
browser-kitty              Private / Browser Kitty Web site
browser-kitty-apps         Public / Registry, health checks, automation
htmlapps-template          Public / application template
htmlapps-*                 Public / individual applications
```

## Roadmap

詳細は [`REGISTRY_SPEC.md`](REGISTRY_SPEC.md) を参照してください。

- v0.2.0 — Repository Inventory ✅
- v0.3.0 — Assets / Repository Quality ✅
- v0.4.0 — GitHub Pages / Release ✅
- v0.5.0 — Standalone / Runtime Metadata
- v0.6.0 — Repository Health Report
- v0.7.0 — Full Registry
- v0.8.0 — Browser Kitty Export
- v0.9.0 — Release Candidate
- v1.0.0 — Production Registry

## License

MIT License. See [`LICENSE`](LICENSE).
