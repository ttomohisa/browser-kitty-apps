# Browser Kitty Apps

## v1.0.1

v1.0.1 hardens GitHub Pages health monitoring against transient platform responses. Pages checks now retry temporary HTTP statuses (`408`, `425`, `429`, `500`, `502`, `503`, `504`) and request exceptions up to three attempts with a short linear backoff. Persistent errors such as `404` remain blocking failures. The report records the attempt count and retry policy for diagnostics.

## v1.0.0

v1.0.0 is the **Production Registry** milestone. The repository now provides a stable 75-application registry, cross-repository health checks, deterministic Browser Kitty build-time export, and a release-readiness gate for ongoing production maintenance. The v0.9.0 candidate passed both GitHub Actions workflows with all 75 applications covered and **0 blocking FAILs**; non-blocking repository-hygiene and legacy-migration WARNs remain visible for follow-up.

Production operation is documented in [`OPERATIONS.md`](OPERATIONS.md). Individual application repositories remain the source of truth for application code and releases; this parent registry does not become a monorepo or a browser-runtime dependency.

## v0.9.0

v0.9.0 is the Release Candidate milestone. It adds a repository-level RC gate with explicit version consistency, required-file checks, published/export coverage checks, lifecycle checks, and optional integration with the latest consolidated Repository Health report. A release candidate passes with **0 blocking FAILs**; non-blocking WARNs remain visible in the generated RC report instead of being hidden.

## v0.8.0

v0.8.0 adds a deterministic public export for the private Browser Kitty website repository. `generated/apps.public.json` is derived only from `apps.json` and `categories.json`, contains published applications only, excludes repository-health/internal deployment fields, and is intended for **build-time** consumption so Browser Kitty does not gain a runtime dependency on this registry. CI verifies that the committed export is current.

## v0.7.2

v0.7.2 corrects the remaining Face Redactor Pages issue found by the first Full Registry health run. The registry now tracks the canonical GitHub Pages root URL that corresponds to `dist/index.html`; the Face Redactor repository itself must include the standard `deploy-pages.yml` workflow and have GitHub Pages set to **GitHub Actions**. No health rule is relaxed in this patch.

## v0.7.1

v0.7.1 calibrates the Full Registry health gate after the first 75-app live run. Missing screenshots and favicon files are now repository-hygiene warnings rather than CI-blocking failures; README, LICENSE, repository availability, standard `app.config.json`, Pages reachability, and hard runtime inconsistencies remain blocking. The release also fixes the Face Redactor Pages URL, accepts the dependency-manifest shapes already used across Browser Kitty (`assets`, single `asset`, and `files`), and corrects WASM / Worker capability declarations found by the first full scan.

## v0.7.0

v0.7.0 expands the registry from the representative 11 apps to a full 75-app inventory based on the current public Browser Kitty application repositories. Standard template-era repositories and three verified legacy repositories are distinguished with `repositoryProfile`. Repository inventory now batches GitHub metadata by owner so the full registry does not consume one REST request per app; asset checks use throttled `raw.githubusercontent.com` HEAD probes, and release/tag checks use the public release redirect plus `git ls-remote`.

Browser Kittyで公開している各アプリを、独立したGitHub Repositoryのまま一元管理するためのRegistryです。

このRepositoryはmonorepoではありません。各アプリのソースコード・Release・GitHub Pagesは従来どおり各Repositoryで管理し、ここではアプリ一覧、公開情報、実行条件、今後のRepository Health Checkに必要なメタデータを管理します。

## v0.6.2

v0.6.2 fixes the health-report smoke test under PowerShell StrictMode: a successful PowerShell script invocation can leave `$LASTEXITCODE` unset, so the test now checks `$?` immediately after `generate-report.ps1`. Repository Health also treats the smoke step as a collector and enforces its result after live checks and artifact upload, preventing a smoke-test regression from skipping all five source reports. v0.6.1 remains the empty-collection binding fix.

- `apps.json` — Browser Kitty application registry
- `categories.json` — category definitions
- `schema/apps.schema.json` — registry JSON Schema
- `schema/repository-inventory.schema.json` — repository inventory JSON Schema
- `schema/repository-quality.schema.json` — repository quality JSON Schema
- `schema/repository-pages.schema.json` — GitHub Pages report JSON Schema
- `schema/repository-releases.schema.json` — release/version report JSON Schema
- `schema/repository-runtime.schema.json` — standalone/runtime report JSON Schema
- `schema/repository-health.schema.json` — consolidated health report JSON Schema
- `schema/public-apps.schema.json` — Browser Kitty public export JSON Schema
- `schema/release-candidate.schema.json` — backward-compatible release-readiness report JSON Schema
- `scripts/check-registry.ps1` — registry validation
- `scripts/check-powershell.ps1` — PowerShell syntax / strict UTF-8 preflight
- `scripts/check-repositories.ps1` — owner-batched repository existence / visibility / archive / default-branch inventory
- `scripts/check-assets.ps1` — README / LICENSE / app.config / favicon / screenshot quality check
- `scripts/check-pages.ps1` — published Pages reachability and response check
- `scripts/check-releases.ps1` — registry / app.config / Release / tag version consistency check
- `scripts/check-runtime.ps1` — standalone output, runtime network policy, isolation, WASM/Worker metadata consistency check
- `scripts/generate-report.ps1` — consolidate all repository checks into final JSON/Markdown health reports
- `scripts/test-generate-report.ps1` — smoke-test the consolidated report with empty issue collections
- `scripts/generate-public-export.ps1` — generate or verify the Browser Kitty public export
- `scripts/check-release-candidate.ps1` — release-readiness gate for version/docs/export/health readiness (historical filename retained)
- `generated/apps.public.json` — committed build-time export for the Browser Kitty website
- `VERSION` — repository release version used by the release-readiness gate
- `RELEASE_CHECKLIST.md` — production release checklist
- `.github/workflows/repository-health.yml` — scheduled and on-change health checks
- `OPERATIONS.md` — steady-state production operation and maintenance procedure
- `reports/README.md` — generated report behavior
- `standards/BROWSER_KITTY_GUIDE.md` — Browser Kitty shared guide

The production registry contains 75 applications in v1.0.1, including three explicitly marked legacy repositories.

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
./scripts/generate-public-export.ps1 -Check
./scripts/check-release-candidate.ps1
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

GitHub Actionsでは `repository-health.yml` がPush・定期実行・手動実行に対応します。Full RegistryではRepository metadataをowner単位でまとめて取得し、raw file / Pages / tag checksもREST API依存を抑えているため、75アプリでも匿名実行を前提にできます。GitHub API rate limitが実際に問題になる場合だけ、必要な公開Repositoryを読める専用tokenをRepository Secret `BROWSER_KITTY_GITHUB_TOKEN` として任意設定します。

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

**CIを止める必須ファイル:**

- `README.md`
- `LICENSE`
- standard Repository の `app.config.json`

これらが欠けた場合は `FAIL` です。legacy Repositoryの`app.config.json`不足は移行差分として`WARN`にします。

`assets/favicon.svg`、`assets/screenshot.png`、`assets/screenshot-en.png` はBrowser Kittyのリリース整備項目ですが、Full Registryでは既存アプリの整備負債と実行不能を分離するため、不足は `WARN` とします。Health CIを止めず、更新時に順次整備します。

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

GitHub Releaseやtagそのものは必須ではありません。存在する場合にだけRegistry版との不一致を`WARN`として検出します。tagは `1.2.3` と `v1.2.3` を同じversionとして扱います。GitHub API取得失敗や `app.config.json` の取得・解析失敗は`FAIL`です。`app.config.json` は公開Repoのraw contentから取得し、tag / Repository metadata用のREST API枠を消費しないようにしています。

GitHub ActionsではInventory / Quality / Pages / Release / Runtimeの5つのソースJSONに加え、統合後の`repository-status.json`と`repository-status.md`を14日間Artifact保存します。JSON出力はそれぞれ専用Schemaで検証します。

## Standalone / runtime metadata

```powershell
./scripts/check-runtime.ps1
```

既定の出力先は `reports/repository-runtime.json` です。各アプリのRuntime宣言を確認します。`app.config.json` のbuild情報は直前の `repository-releases.json` を再利用し、`dependencies.json` は公開Repoのraw contentから取得するため、同じGitHub REST API情報を二重取得しません。

確認内容:

- `standalonePath` が `app.config.json` の通常 / MT / self-extract build outputのいずれかと一致すること
- `networkAccess=false` のアプリで `build.blockRuntimeNetwork=true` になっていること
- `crossOriginIsolated=true` の場合にCOOP / COEP / CORPのhosting宣言が揃っていること
- `dependencies.json` にWASM/Worker assetがあるのにRegistry側のcapability flagがfalseになっていないこと

`crossOriginIsolated` / `requiresWasm` / `requiresWorker` / `requiresWebGPU` / `requiresWebCodecs` はv0.5.0から全アプリで明示必須です。これは「コードを検索して自動推測した値」ではなく、Registryで管理する宣言値です。機械的に確認できない能力を無理にFAILへせず、Repository metadataと明確に矛盾する場合だけ警告または失敗にします。

## Repository Health Report
### Health report smoke test

`test-generate-report.ps1` runs a PASS fixture before the live repository checks. A successful PowerShell script invocation does not necessarily initialize `$LASTEXITCODE`, so the smoke test uses PowerShell's `$?` command status instead. This keeps the test compatible with `Set-StrictMode -Version Latest`.

In the Repository Health workflow, the smoke step uses `continue-on-error` so live Inventory / Quality / Pages / Release / Runtime checks and artifact upload still run. A final enforcement step fails the job if the smoke test itself failed. The lighter Validate Registry workflow keeps the smoke test fail-fast.


```powershell
./scripts/generate-report.ps1
```

既定では、先に生成された5つのレポートを統合します。

```text
reports/repository-inventory.json
reports/repository-quality.json
reports/repository-pages.json
reports/repository-releases.json
reports/repository-runtime.json
        ↓
reports/repository-status.json
reports/repository-status.md
```

アプリ単位で `PASS / WARN / FAIL` を決定し、Inventory / Quality / Pages / Release / Runtime の各状態を横断表示します。元レポートが欠落・破損している場合も黙って無視せず `UNKNOWN` として扱い、最終判定は `FAIL` になります。`WARN` だけならCIは成功し、`FAIL` が1件以上ある場合、または統合元レポート自体に重大な問題がある場合に最終ステップがexit code 1を返します。

GitHub Actionsでは各ソースチェックを結果収集として最後まで実行し、`generate-report.ps1`を唯一のRepository Health最終ゲートにします。これにより途中で1チェックが失敗しても、可能な限り他の結果と最終レポートをArtifactへ残せます。

## Browser Kitty public export

Browser Kitty本体向けの公開用データは次で生成します。

```powershell
./scripts/generate-public-export.ps1
```

生成先:

```text
generated/apps.public.json
```

公開exportは`browserKitty.published=true`のアプリだけを含み、現在は75アプリ・7カテゴリです。Browser Kitty本体で必要な次の情報だけを残します。

- アプリID / 日英名称 / slug / category
- lifecycle status / version
- GitHub Pages URL
- Repository名 / GitHub URL
- 完全ローカル処理・runtime capabilityの公開可能な宣言

一方、`repositoryProfile`、`standalonePath`、hosting header、template情報、Health Check結果などの運用内部情報はexportしません。`generatedAt`も持たせず、同じRegistry入力から同じJSONが生成される決定的な形式にしています。

CIでは次を実行し、`apps.json` / `categories.json`変更後に生成物を更新し忘れた場合は失敗します。

```powershell
./scripts/generate-public-export.ps1 -Check
```

Browser Kitty本体はこのJSONを**ビルド時入力**として取り込み、静的ページへ反映する想定です。ブラウザ実行時に`browser-kitty-apps`へfetchする構成にはせず、Browser Kittyのランタイム外部依存を増やしません。

`generated/apps.public.json`は派生生成物であり、一次情報ではありません。変更は必ず`apps.json` / `categories.json`へ行い、生成スクリプトで更新します。

## Add an application

1. `categories.json` に対象カテゴリがあることを確認します。
2. `apps.json` にアプリを追加します。
3. `./scripts/check-registry.ps1` を実行します。
4. Pull Request / PushのGitHub Actionsが成功することを確認します。

`generated/` はRegistryから作る派生データです。手編集せず、生成スクリプトで更新します。

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
- v0.5.0 — Standalone / Runtime Metadata ✅
- v0.6.0 — Repository Health Report ✅
- v0.6.2 — Empty-collection binding fix / health report smoke test ✅
- v0.7.2 — Face Redactor Pages correction ✅
- v0.7.1 — Full Registry health-policy calibration ✅
- v0.7.0 — Full Registry / scalable cross-repository checks ✅
- v0.8.0 — Browser Kitty Export ✅
- v0.9.0 — Release Candidate ✅
- v1.0.0 — Production Registry ✅
- v1.0.1 — Pages health retry hardening ✅

## License

MIT License. See [`LICENSE`](LICENSE).
