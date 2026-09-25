# Browser Kitty Apps

[English](README.md)

[![Browser Kitty](https://img.shields.io/badge/Browser%20Kitty-open-16624F?style=flat-square)](https://browser-kitty.com/)
[![Repository health](https://github.com/ttomohisa/browser-kitty-apps/actions/workflows/repository-health.yml/badge.svg)](https://github.com/ttomohisa/browser-kitty-apps/actions/workflows/repository-health.yml)
[![Registry version](https://img.shields.io/badge/registry-v1.1.0-16624F?style=flat-square)](VERSION)
[![GitHub stars](https://img.shields.io/github/stars/ttomohisa/browser-kitty-apps?style=flat-square)](https://github.com/ttomohisa/browser-kitty-apps/stargazers)
[![License: MIT](https://img.shields.io/badge/license-MIT-16624F?style=flat-square)](LICENSE)

**Browser Kitty** は、ブラウザだけで使える小さなツールを公開するWebサイトです。登録やインストールは不要で、各ツールはドキュメントに記載した範囲で、ユーザーのファイルやデータをできるだけ端末内で処理する構成にしています。

### [Browser Kittyを開く →](https://browser-kitty.com/)

[アプリ一覧](CATALOG.md) · [Healthスナップショット](STATUS.md) · [最新Health](https://github.com/ttomohisa/browser-kitty-apps/actions/workflows/repository-health.yml) · [改善要望](https://github.com/ttomohisa/browser-kitty-apps/issues)

このRepositoryは、Browser Kittyの公開 **アプリ台帳・Health Check・フィードバック窓口** です。各アプリのソースコードは従来どおり個別のPublic Repositoryで管理します。このRepositoryはmonorepoではなく、Browser Kittyのブラウザ実行時の依存先でもありません。

## 改善要望・アイデア

個別アプリのRepositoryを探してから要望を書く必要はありません。まずこのRepositoryにIssueを作成してもらえれば、必要に応じて適切な場所へ振り分けます。

| やりたいこと | リンク |
|---|---|
| 既存ツールを改善してほしい | [機能改善要望](https://github.com/ttomohisa/browser-kitty-apps/issues/new?template=feature_request.yml) |
| 新しいブラウザツールを提案したい | [新ツール案](https://github.com/ttomohisa/browser-kitty-apps/issues/new?template=new_tool.yml) |
| 不具合を報告したい | [不具合報告](https://github.com/ttomohisa/browser-kitty-apps/issues/new?template=problem_report.yml) |
| 既存の要望を見たい | [Issues](https://github.com/ttomohisa/browser-kitty-apps/issues) |
| ツールを使いたい | [browser-kitty.com](https://browser-kitty.com/) |

### Starについて

Browser Kittyが役に立った場合、このRepositoryにStarを付けてもらえると、プロジェクトへの関心を知る手掛かりになります。StarやIssueへのリアクションも、今後どのツールや改善を進めるか検討する際の参考にします。

## このRepositoryで管理するもの

アプリ本体のソースコードの正本は、それぞれの個別Repositoryです。この親Repositoryでは、Browser Kitty全体を横断して必要になる情報を管理します。

- `apps.json` — Browser Kittyアプリ台帳
- `categories.json` — 共通カテゴリ定義
- `generated/apps.public.json` — Browser Kitty本体がビルド時に使う公開用export
- Repository / assets / GitHub Pages / release / runtimeの横断チェック
- Repository Health Report
- Release Readiness Check

現在のProduction baselineは **75アプリ / 7カテゴリ** です。

```text
browser-kitty.com
       ↑
       | ビルド時に取り込み
generated/apps.public.json
       ↑
apps.json + categories.json
       |
       +---- Repository Health ----> htmlapps-* repositories
```

Browser Kitty本体は、公開exportをビルド時に取り込みます。ブラウザからこのRegistryへ実行時fetchする構成にはしません。

## Repositoryの役割

| Repository | 役割 |
|---|---|
| `browser-kitty` | Private / Browser Kitty本体 |
| `browser-kitty-apps` | Public / Registry・Health Check・自動化・フィードバック窓口 |
| `htmlapps-template` | Public / アプリ共通テンプレート |
| `htmlapps-*` | Public / 各アプリのソースコード |

## Contributing

フィードバック、ドキュメント修正、Registryの修正、自動化の改善を歓迎します。詳しくは [CONTRIBUTING.md](CONTRIBUTING.md) を参照してください。

個別アプリそのものの実装変更は、通常は対象の`htmlapps-*` Repositoryで行います。どのRepositoryか分からない場合は、このRepositoryにIssueを作成して問題ありません。

セキュリティに関する報告は [SECURITY.md](SECURITY.md) に従ってください。公開Issueへ個人情報、機密ファイル、パスワード、APIキーなどを添付しないでください。

## Registryの例

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
  }
}
```

完全なSchemaと運用ポリシーは [REGISTRY_SPEC.md](REGISTRY_SPEC.md) を参照してください。

## ローカル検証

PowerShell 7で実行します。

```powershell
./scripts/check-powershell.ps1
./scripts/check-registry.ps1
./scripts/generate-public-export.ps1 -Check
./scripts/check-release-candidate.ps1
```

Repository横断Health Checkは個別にも実行できます。

```powershell
./scripts/check-repositories.ps1
./scripts/check-assets.ps1
./scripts/check-pages.ps1
./scripts/check-releases.ps1
./scripts/check-runtime.ps1
./scripts/generate-report.ps1
```

GitHub Actionsでも同じ系統の検証を実行します。`WARN`は既存資産の整備TODOなどを可視化しつつWorkflowを止めません。blockingな`FAIL`がある場合はRepository Healthを失敗させます。

## Browser Kitty公開用export

`generated/apps.public.json`には、公開済みアプリのうちBrowser Kitty本体で利用できる公開項目だけを含めます。`apps.json`と`categories.json`から生成する派生ファイルなので、直接編集しません。

Registryを変更した場合は次を実行します。

```powershell
./scripts/generate-public-export.ps1
./scripts/generate-public-export.ps1 -Check
```

## ドキュメント

| ドキュメント | 内容 |
|---|---|
| [OPERATIONS.md](OPERATIONS.md) | Production運用・保守 |
| [REGISTRY_SPEC.md](REGISTRY_SPEC.md) | Registry Schema・運用ポリシー |
| [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md) | Release Readiness Checklist |
| [reports/README.md](reports/README.md) | Health Reportの仕様 |
| [standards/BROWSER_KITTY_GUIDE.md](standards/BROWSER_KITTY_GUIDE.md) | Browser Kitty共通ガイド |
| [CATALOG.md](CATALOG.md) | 人間向けアプリ一覧 |
| [STATUS.md](STATUS.md) | 人間向けRepository Healthスナップショット |
| [CHANGELOG.md](CHANGELOG.md) | Version履歴 |

## v1.1.0

v1.1.0では、RegistryとRepository Healthを人がそのまま読める表示を追加しました。`CATALOG.md`はRegistryから決定的に生成するアプリ一覧、`STATUS.md`はHealthスナップショットです。Repository Health実行時には同じ人間向けStatusを再生成し、GitHub ActionsのJob Summaryにも直接表示します。詳細は [CHANGELOG.md](CHANGELOG.md) を参照してください。

## License

MIT Licenseです。詳細は [LICENSE](LICENSE) を参照してください。
