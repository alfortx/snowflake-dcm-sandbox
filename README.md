# snowflake-dcm-sandbox

Snowflake **DCM Projects** の検証用プロジェクトです。RAW 層（COVID-19 公開データ）と、チーム別の ANALYTICS 層・ウェアハウス・ロールを `DEFINE` 文と Jinja で宣言的に管理します。

## DCM が作るオブジェクト

`teams = [T1, T2, T3]` の展開結果です。名前の末尾 `<ENV>` には環境の suffix（`_DEV` / `_PRD`）が付きます。
環境ごとに DCM プロジェクトを分け（`DCM_SBX_PROJECT_DEV` / `_PRD`）、同じ定義ファイルを並べてデプロイします。

### 共通（RAW 層）

| 種類 | 名前 | 内容 |
|---|---|---|
| Database | `DCM_SBX_RAW_DB<ENV>` | |
| Schema | `DCM_SBX_RAW_DB<ENV>.COVID19` | |
| File format | `COVID19.CSV_FORMAT` | CSV、skip_header=1、null_if=('', 'NA', 'NULL') |
| Stage（外部） | `COVID19_S3_STAGE` / `COVID19_WORLD_TESTING_STAGE` / `COVID19_NYT_USA_STAGE` | `s3://covid19-lake/...`（公開バケット、認証なし） |
| View | `JHU_TIMESERIES` / `COVID19_WORLD_TESTING` / `NYT_USA_STATES` | ステージを直接 SELECT（データはロードしない） |
| Database role | `DCM_SBX_RAW_DB<ENV>.COVID19_READ` | スキーマ USAGE、INHERITED SELECT（views / tables） |

> 外部テーブルは DCM の対象外のため、ステージを直接参照するビューで代替しています。

### チームごと（`Tx` = T1 / T2 / T3）

| 種類 | 名前 | 内容 |
|---|---|---|
| Warehouse | `DCM_SBX_Tx_WH<ENV>` | X-Small、auto_suspend=60、初期停止、statement timeout 180 秒 |
| Role | `DCM_SBX_FR_WH_Tx_OPERATE<ENV>` / `DCM_SBX_FR_WH_Tx_USE<ENV>` | WH の USAGE+OPERATE ／ USAGE |
| Database | `DCM_SBX_Tx_ANALYTICS_DB<ENV>` | スキーマ `SILVER` / `GOLD` |
| Database role | `SILVER_WRITE` / `GOLD_WRITE` | USAGE、CREATE TABLE / VIEW、INHERITED SELECT・DML |
| Database role | `SILVER_READ` / `GOLD_READ` | USAGE、INHERITED SELECT |
| Role | `DCM_SBX_Tx_DEVELOPER_ROLE<ENV>` | ANALYTICS 読み書き + RAW 読み取り + WH 操作 |
| Role | `DCM_SBX_Tx_VIEWER_ROLE<ENV>` | ANALYTICS / RAW 読み取り + WH 利用 |

### ロール階層

```text
SYSADMIN
├── DCM_SBX_Tx_DEVELOPER_ROLE<ENV>
│   ├── DCM_SBX_Tx_ANALYTICS_DB<ENV>.SILVER_WRITE
│   ├── DCM_SBX_Tx_ANALYTICS_DB<ENV>.GOLD_WRITE
│   ├── DCM_SBX_RAW_DB<ENV>.COVID19_READ
│   └── DCM_SBX_FR_WH_Tx_OPERATE<ENV>
└── DCM_SBX_Tx_VIEWER_ROLE<ENV>
    ├── DCM_SBX_Tx_ANALYTICS_DB<ENV>.SILVER_READ
    ├── DCM_SBX_Tx_ANALYTICS_DB<ENV>.GOLD_READ
    ├── DCM_SBX_RAW_DB<ENV>.COVID19_READ
    └── DCM_SBX_FR_WH_Tx_USE<ENV>
```

### DCM 管理外（`scripts/setup.sql` で作成）

| 種類 | 名前 | 目的 |
|---|---|---|
| Account parameter | `FEATURE_RBAC_INHERITED_GRANTS = ENABLED` | INHERITED grant の有効化（cleanup では戻さない） |
| Role | `DCM_SBX_ADMIN_ROLE` | DCM プロジェクトのオーナー（SYSADMIN に継承） |
| Warehouse | `DCM_SBX_ADMIN_WH` | PLAN / DEPLOY 実行用（X-Small、auto_suspend=60） |
| API integration | `DCM_SBX_GIT_API_INTEGRATION` | このリポジトリを Snowflake から読む |
| Database / Schema | `DCM_SBX_ADMIN_DB.GIT` / `.PROJECTS` | Git リポジトリ・DCM プロジェクトの置き場 |
| Git repository | `DCM_SBX_ADMIN_DB.GIT.DCM_SBX_REPO` | このリポジトリのクローン |
| Database role | `DCM_SBX_ADMIN_DB.DCM_ADMIN` | リポジトリ READ、CREATE DCM PROJECT |
| DCM project | `DCM_SBX_ADMIN_DB.PROJECTS.DCM_SBX_PROJECT_DEV` / `_PRD` | 環境ごとに 1 つ |

## ファイル構成

```text
manifest.yml                    # ターゲット（DEV / PRD）・テンプレート変数（env_suffix / WH 設定 / teams）
sources/definitions/raw.sql     # RAW 層
sources/definitions/raw_access.sql
sources/definitions/teams.sql   # teams をループして create_team() を呼ぶ
sources/macros/team.sql         # create_team(team): 1 チーム分の定義
scripts/setup.sql               # 事前準備（ACCOUNTADMIN）
scripts/plan.sql / deploy.sql   # PLAN / DEPLOY（USING (env => 'DEV' | 'PRD')）
scripts/cleanup.sql             # PURGE と後片付け（env => 'DEV' | 'PRD' | 'ALL'。ALL は Git 統合まで削除）
```

## 実行方法

前提: ACCOUNTADMIN を使えるユーザーで実行すること。既存のロールや WH は使いません（必要なものは `setup.sql` がすべて作ります）。

> このリポジトリを fork して使う場合は、`scripts/setup.sql` の `API_ALLOWED_PREFIXES` と `ORIGIN`、Snowsight 手順のリポジトリ URL を自分のリポジトリに書き換えてください。
PLAN / DEPLOY は **CLI（SQL）** と **Snowsight（Git ワークスペース）** のどちらからでも実行できます。セットアップとクリーンナップは SQL のみです。

### 0. セットアップ（共通・ローカルのクローンから）

```bash
snow sql -c <connection> -f scripts/setup.sql
```

### A. CLI（SQL）から PLAN → DEPLOY

```sql
ALTER GIT REPOSITORY DCM_SBX_ADMIN_DB.GIT.DCM_SBX_REPO FETCH;
USE ROLE DCM_SBX_ADMIN_ROLE;
USE WAREHOUSE DCM_SBX_ADMIN_WH;
EXECUTE IMMEDIATE FROM '@DCM_SBX_ADMIN_DB.GIT.DCM_SBX_REPO/branches/main/scripts/plan.sql'   USING (env => 'DEV');
EXECUTE IMMEDIATE FROM '@DCM_SBX_ADMIN_DB.GIT.DCM_SBX_REPO/branches/main/scripts/deploy.sql' USING (env => 'DEV');
-- PRD も同様に env => 'PRD'
```

### B. Snowsight（Git ワークスペース）から PLAN → DEPLOY

1. ロールを `DCM_SBX_ADMIN_ROLE`、ウェアハウスを `DCM_SBX_ADMIN_WH` にする
2. **Projects » Workspaces » + » From Git repository**
   - Repository URL: `https://github.com/alfortx/snowflake-dcm-sandbox.git`
   - API integration: `DCM_SBX_GIT_API_INTEGRATION`
   - Authentication: **Public repository**（読み取り専用。ワークスペースから push はできない）
3. ワークスペース上で `manifest.yml` の `account_identifier`（2 か所）を自分のアカウント識別子に書き換えて保存する（commit 不要）
   - 値は `SELECT CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME();` で確認できる
   - プレースホルダのままだと「このターゲットは別のアカウントを使用しているため、ここで選択できません」となり target を選べない
4. 画面左下の「下部パネル」アイコンでパネルを開き、target に `DCM_SBX_DEV` か `DCM_SBX_PRD` を選ぶ（緑の表示になること）
5. 操作を **計画**（Plan）にして ▶ を押す。レンダリング済みの定義が `out/rendered/` に、結果が `out/compile_result.json` に出力される
6. 操作を **展開**（Deploy）にして ▶ を押す（Deployment alias は任意。デプロイ履歴に記録される）
7. デプロイ履歴は Catalog » Database Explorer » `DCM_SBX_ADMIN_DB` » `PROJECTS` » DCM project の Deployment History で見られる

> ワークスペースは**個人所有**（ロールではなくユーザーが所有）で、UI からのみ作成できます。クリーンナップの前に、ワークスペースの `⋯` » Delete で削除してください。

### CLI（SQL）と Snowsight の違い

| 観点 | CLI（`EXECUTE DCM PROJECT`） | Snowsight（Git ワークスペース） |
|---|---|---|
| 環境の指定 | プロジェクト名と `USING CONFIGURATION DEV` を SQL で明示する | manifest の `targets`（`DCM_SBX_DEV` / `DCM_SBX_PRD`）を選ぶ |
| `account_identifier` | 参照されない（プレースホルダのままで動く） | 今のアカウントと一致しないと target を選べない |
| ソース | Git リポジトリステージ `@…/branches/main/`（push 後に `FETCH` が必要） | ワークスペースの live 版 `snow://workspace/…/versions/live` |
| 未コミットの修正 | 反映されない（push 済みのブランチのみ） | 反映される（保存した時点の内容で実行） |
| 変数の上書き | `USING CONFIGURATION DEV (var => value)` | 「変数を上書き」トグル |
| PLAN の結果 | 結果セットに JSON（`changeset`）が返る | `out/` にレンダリング済み定義と `compile_result.json`。変更内容を画面に表示 |
| 実行ロール | 実行者が `USE ROLE` で選ぶ（プロジェクトのオーナー権限が必要） | 現在のロールで実行。target の `project_owner` がプロジェクトを所有していること |
| PURGE / DROP | 可能（`cleanup.sql`） | Purge はできない（Catalog からプロジェクトの Drop のみ） |
| 向いている用途 | スクリプト化・CI | 手動での確認・レビュー |

> 同じ DCM プロジェクトをどちらの経路から操作しても構いません。Snowsight でデプロイした後に CLI から PLAN すると、変更は 0 件になります。

### クリーンナップ（共通・SQL）

```sql
USE ROLE ACCOUNTADMIN;
-- env => 'DEV' / 'PRD' でその環境だけ、'ALL' で両環境 + DCM 管理ロール + 管理用 WH + Git 統合 + DCM_SBX_ADMIN_DB を削除（アカウント設定以外は setup 前の状態に戻る）
EXECUTE IMMEDIATE FROM '@DCM_SBX_ADMIN_DB.GIT.DCM_SBX_REPO/branches/main/scripts/cleanup.sql' USING (env => 'ALL');
```

> `env => 'DEV'` などで片方を削除済みの状態で `'ALL'` を流すと、存在しないプロジェクトへの PURGE でエラーになります。`scripts/setup.sql` を再実行してから `'ALL'` を流してください。
