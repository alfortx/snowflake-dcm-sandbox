# snowflake-dcm-sandbox

Snowflake **DCM Projects** の検証用プロジェクトです。RAW 層（COVID-19 公開データ）と、チーム別の ANALYTICS 層・ウェアハウス・ロールを `DEFINE` 文と Jinja で宣言的に管理します。

## DCM が作るオブジェクト

`prefix = DCM_SBX`、`teams = [T1, T2, T3]`（`manifest.yml` の DEV 構成）の場合の展開結果です。

### 共通（RAW 層）

| 種類 | 名前 | 内容 |
|---|---|---|
| Database | `DCM_SBX_RAW_DB` | |
| Schema | `DCM_SBX_RAW_DB.COVID19` | |
| File format | `COVID19.CSV_FORMAT` | CSV、skip_header=1、null_if=('', 'NA', 'NULL') |
| Stage（外部） | `COVID19_S3_STAGE` / `COVID19_WORLD_TESTING_STAGE` / `COVID19_NYT_USA_STAGE` | `s3://covid19-lake/...`（公開バケット、認証なし） |
| View | `JHU_TIMESERIES` / `COVID19_WORLD_TESTING` / `NYT_USA_STATES` | ステージを直接 SELECT（データはロードしない） |
| Database role | `DCM_SBX_RAW_DB.COVID19_READ` | スキーマ USAGE、INHERITED SELECT（views / tables） |

> 外部テーブルは DCM の対象外のため、ステージを直接参照するビューで代替しています。

### チームごと（`Tx` = T1 / T2 / T3）

| 種類 | 名前 | 内容 |
|---|---|---|
| Warehouse | `DCM_SBX_Tx_WH` | X-Small、auto_suspend=60、初期停止、statement timeout 180 秒 |
| Role | `DCM_SBX_FR_WH_Tx_OPERATE` / `DCM_SBX_FR_WH_Tx_USE` | WH の USAGE+OPERATE ／ USAGE |
| Database | `DCM_SBX_Tx_ANALYTICS_DB` | スキーマ `SILVER` / `GOLD` |
| Database role | `SILVER_WRITE` / `GOLD_WRITE` | USAGE、CREATE TABLE / VIEW、INHERITED SELECT・DML |
| Database role | `SILVER_READ` / `GOLD_READ` | USAGE、INHERITED SELECT |
| Role | `DCM_SBX_Tx_DEVELOPER_ROLE` | ANALYTICS 読み書き + RAW 読み取り + WH 操作 |
| Role | `DCM_SBX_Tx_VIEWER_ROLE` | ANALYTICS / RAW 読み取り + WH 利用 |

### ロール階層

```text
SYSADMIN
├── DCM_SBX_Tx_DEVELOPER_ROLE
│   ├── DCM_SBX_Tx_ANALYTICS_DB.SILVER_WRITE
│   ├── DCM_SBX_Tx_ANALYTICS_DB.GOLD_WRITE
│   ├── DCM_SBX_RAW_DB.COVID19_READ
│   └── DCM_SBX_FR_WH_Tx_OPERATE
└── DCM_SBX_Tx_VIEWER_ROLE
    ├── DCM_SBX_Tx_ANALYTICS_DB.SILVER_READ
    ├── DCM_SBX_Tx_ANALYTICS_DB.GOLD_READ
    ├── DCM_SBX_RAW_DB.COVID19_READ
    └── DCM_SBX_FR_WH_Tx_USE
```

### DCM 管理外（`scripts/setup.sql` で作成）

| 種類 | 名前 | 目的 |
|---|---|---|
| Role | `DCM_SBX_ADMIN_ROLE` | DCM プロジェクトのオーナー（SYSADMIN に継承） |
| API integration | `DCM_SBX_GIT_API_INTEGRATION` | このリポジトリを Snowflake から読む |
| Database / Schema | `DCM_SBX_ADMIN_DB.GIT` / `.PROJECTS` | Git リポジトリ・DCM プロジェクトの置き場 |
| Git repository | `DCM_SBX_ADMIN_DB.GIT.DCM_SBX_REPO` | このリポジトリのクローン |
| Database role | `DCM_SBX_ADMIN_DB.DCM_ADMIN` | リポジトリ READ、CREATE DCM PROJECT |
| DCM project | `DCM_SBX_ADMIN_DB.PROJECTS.DCM_SBX_PROJECT` | |

## ファイル構成

```text
manifest.yml                    # ターゲット・テンプレート変数（prefix / WH 設定 / teams）
sources/definitions/raw.sql     # RAW 層
sources/definitions/raw_access.sql
sources/definitions/teams.sql   # teams をループして create_team() を呼ぶ
sources/macros/team.sql         # create_team(team): 1 チーム分の定義
scripts/setup.sql               # 事前準備（ACCOUNTADMIN）
scripts/plan.sql / deploy.sql   # PLAN / DEPLOY
scripts/cleanup.sql             # PURGE と後片付け（Git 統合は残す）
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
EXECUTE IMMEDIATE FROM '@DCM_SBX_ADMIN_DB.GIT.DCM_SBX_REPO/branches/main/scripts/plan.sql';
EXECUTE IMMEDIATE FROM '@DCM_SBX_ADMIN_DB.GIT.DCM_SBX_REPO/branches/main/scripts/deploy.sql';

-- 3. クリーンナップ
USE ROLE ACCOUNTADMIN;
EXECUTE IMMEDIATE FROM '@DCM_SBX_ADMIN_DB.GIT.DCM_SBX_REPO/branches/main/scripts/cleanup.sql';
```
