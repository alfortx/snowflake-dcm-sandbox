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
| Role | `DCM_SBX_ADMIN_ROLE` | DCM プロジェクトのオーナー（SYSADMIN に継承） |
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
scripts/cleanup.sql             # PURGE と後片付け（env => 'DEV' | 'PRD' | 'ALL'。Git 統合は残す）
```

## 実行方法

前提: アカウントで `FEATURE_RBAC_INHERITED_GRANTS = 'ENABLED'`、および WH 利用ロール `FR_WH_SANDBOX_USE` が存在すること。

```bash
# 1. セットアップ（ローカルのクローンから）
snow sql -c <connection> -f scripts/setup.sql
```

```sql
-- 2. PLAN → DEPLOY（Git 上のスクリプトを実行）
ALTER GIT REPOSITORY DCM_SBX_ADMIN_DB.GIT.DCM_SBX_REPO FETCH;
USE ROLE DCM_SBX_ADMIN_ROLE;
USE WAREHOUSE SANDBOX_WH;
EXECUTE IMMEDIATE FROM '@DCM_SBX_ADMIN_DB.GIT.DCM_SBX_REPO/branches/main/scripts/plan.sql'   USING (env => 'DEV');
EXECUTE IMMEDIATE FROM '@DCM_SBX_ADMIN_DB.GIT.DCM_SBX_REPO/branches/main/scripts/deploy.sql' USING (env => 'DEV');
-- PRD も同様に env => 'PRD'

-- 3. クリーンナップ
USE ROLE ACCOUNTADMIN;
-- env => 'DEV' / 'PRD' でその環境だけ、'ALL' で両環境 + DCM 管理ロールを削除
EXECUTE IMMEDIATE FROM '@DCM_SBX_ADMIN_DB.GIT.DCM_SBX_REPO/branches/main/scripts/cleanup.sql' USING (env => 'ALL');
```

> `env => 'DEV'` などで片方を削除済みの状態で `'ALL'` を流すと、存在しないプロジェクトへの PURGE でエラーになります。`scripts/setup.sql` を再実行してから `'ALL'` を流してください。
