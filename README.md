# Browser Kitty Apps

Browser Kittyで公開している各アプリを、独立したGitHub Repositoryのまま一元管理するためのRegistryです。

このRepositoryはmonorepoではありません。各アプリのソースコード・Release・GitHub Pagesは従来どおり各Repositoryで管理し、ここではアプリ一覧、公開情報、実行条件、今後のRepository Health Checkに必要なメタデータを管理します。

## v0.1.0

最初のバージョンではRegistryのデータモデルと検証基盤を実装しています。

- `apps.json` — Browser KittyアプリのRegistry
- `categories.json` — カテゴリ定義
- `schema/apps.schema.json` — RegistryのJSON Schema
- `scripts/check-registry.ps1` — PowerShell 7による整合性確認
- `.github/workflows/validate-registry.yml` — Push / Pull Request時の自動検証
- `standards/BROWSER_KITTY_GUIDE.md` — Browser Kitty全体の共通ガイド

現在は代表11アプリを登録しています。全アプリの移行はv0.7.0までに段階的に行います。

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

この段階ではGitHub上のRepository、Release、Pages、Assetsへ実際にアクセスするHealth Checkはまだ行いません。これらはv0.2.0以降で追加します。

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

- v0.2.0 — Repository Inventory
- v0.3.0 — Assets / Repository Quality
- v0.4.0 — GitHub Pages / Release
- v0.5.0 — Standalone / Runtime Metadata
- v0.6.0 — Repository Health Report
- v0.7.0 — Full Registry
- v0.8.0 — Browser Kitty Export
- v0.9.0 — Release Candidate
- v1.0.0 — Production Registry

## License

MIT License. See [`LICENSE`](LICENSE).
