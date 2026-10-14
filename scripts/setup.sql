-- =============================================================================
-- DCM Sandbox セットアップ
--   DCM 管理ロール / Git 統合 / DCM プロジェクトを作成する
--   実行: ACCOUNTADMIN（ローカルのクローンから snow sql -f で実行。Git 統合がまだ無いため）
--   前提: なし（既存のロール・WH を使わず、必要なものはすべてここで作る）
--   IF NOT EXISTS で何度実行しても同じ状態になる
-- =============================================================================
USE ROLE ACCOUNTADMIN;

-- -----------------------------------------------------------------------------
-- 0. アカウント設定: INHERITED grant（GRANT INHERITED ... ON ALL ...）を有効化する
--    既に ENABLED なら何も変わらない。cleanup.sql では戻さない
-- -----------------------------------------------------------------------------
ALTER ACCOUNT SET FEATURE_RBAC_INHERITED_GRANTS = 'ENABLED';

-- -----------------------------------------------------------------------------
-- 1. DCM 管理ロール（DCM プロジェクトのオーナー。DCM が作る全オブジェクトを所有する）
-- -----------------------------------------------------------------------------
CREATE ROLE IF NOT EXISTS DCM_SBX_ADMIN_ROLE
    COMMENT = 'DCM Sandbox: DCM プロジェクトのオーナー（PLAN / DEPLOY / PURGE 実行ロール）';
GRANT ROLE DCM_SBX_ADMIN_ROLE TO ROLE SYSADMIN;

-- DCM が WH / DB / ロールを作り、INHERITED grant を張るための権限
-- （INHERITED grant は MANAGE GRANTS が必須。コンテナの所有者であるだけでは足りない）
GRANT CREATE DATABASE, CREATE WAREHOUSE, CREATE ROLE, MANAGE GRANTS ON ACCOUNT TO ROLE DCM_SBX_ADMIN_ROLE;

-- -----------------------------------------------------------------------------
-- 2. Git 統合（目的: DCM プロジェクトのソースを公開 GitHub リポジトリから取得する）
--    公開リポジトリのため Secret（認証情報）は不要
-- -----------------------------------------------------------------------------
CREATE API INTEGRATION IF NOT EXISTS DCM_SBX_GIT_API_INTEGRATION
    API_PROVIDER = git_https_api
    API_ALLOWED_PREFIXES = ('https://github.com/alfortx/snowflake-dcm-sandbox.git')  -- 末尾 .git まで含めないと ORIGIN と一致しない
    ENABLED = TRUE
    COMMENT = 'DCM Sandbox: DCM プロジェクトのソース（公開 GitHub リポジトリ）を取得するための Git 連携';
GRANT USAGE ON INTEGRATION DCM_SBX_GIT_API_INTEGRATION TO ROLE SYSADMIN;
-- Snowsight で DCM_SBX_ADMIN_ROLE のまま Git ワークスペースを作るとき、この Integration を選べるようにする
GRANT USAGE ON INTEGRATION DCM_SBX_GIT_API_INTEGRATION TO ROLE DCM_SBX_ADMIN_ROLE;

USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS DCM_SBX_ADMIN_DB
    COMMENT = 'DCM Sandbox: Git リポジトリと DCM プロジェクトの置き場';
CREATE SCHEMA IF NOT EXISTS DCM_SBX_ADMIN_DB.GIT
    COMMENT = 'Git リポジトリ（DCM ソース取得用）';
CREATE SCHEMA IF NOT EXISTS DCM_SBX_ADMIN_DB.PROJECTS
    COMMENT = 'DCM プロジェクト';

CREATE GIT REPOSITORY IF NOT EXISTS DCM_SBX_ADMIN_DB.GIT.DCM_SBX_REPO
    API_INTEGRATION = DCM_SBX_GIT_API_INTEGRATION
    ORIGIN = 'https://github.com/alfortx/snowflake-dcm-sandbox.git'
    COMMENT = 'DCM Sandbox: DCM プロジェクトのソース（manifest.yml / sources / scripts）';

-- -----------------------------------------------------------------------------
-- 3. DB ロール（DB スコープの権限はデータベースロールに持たせ、DCM 管理ロールが継承する）
-- -----------------------------------------------------------------------------
CREATE DATABASE ROLE IF NOT EXISTS DCM_SBX_ADMIN_DB.DCM_ADMIN
    COMMENT = 'Git リポジトリの読み取りと DCM プロジェクトの作成';
GRANT USAGE ON SCHEMA DCM_SBX_ADMIN_DB.GIT                      TO DATABASE ROLE DCM_SBX_ADMIN_DB.DCM_ADMIN;
GRANT USAGE ON SCHEMA DCM_SBX_ADMIN_DB.PROJECTS                 TO DATABASE ROLE DCM_SBX_ADMIN_DB.DCM_ADMIN;
GRANT READ ON GIT REPOSITORY DCM_SBX_ADMIN_DB.GIT.DCM_SBX_REPO  TO DATABASE ROLE DCM_SBX_ADMIN_DB.DCM_ADMIN;
GRANT CREATE DCM PROJECT ON SCHEMA DCM_SBX_ADMIN_DB.PROJECTS    TO DATABASE ROLE DCM_SBX_ADMIN_DB.DCM_ADMIN;
GRANT DATABASE ROLE DCM_SBX_ADMIN_DB.DCM_ADMIN TO ROLE DCM_SBX_ADMIN_ROLE;

-- -----------------------------------------------------------------------------
-- 4. PLAN / DEPLOY 用のウェアハウスと DCM プロジェクト（環境ごとに 1 つ）
--    いずれもオーナー = DCM_SBX_ADMIN_ROLE
-- -----------------------------------------------------------------------------
USE ROLE DCM_SBX_ADMIN_ROLE;
CREATE WAREHOUSE IF NOT EXISTS DCM_SBX_ADMIN_WH
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'DCM Sandbox: PLAN / DEPLOY 実行用';
CREATE DCM PROJECT IF NOT EXISTS DCM_SBX_ADMIN_DB.PROJECTS.DCM_SBX_PROJECT_DEV
    COMMENT = 'DCM Sandbox (DEV): RAW（COVID19）と チーム別 ANALYTICS / WH / ロールを管理';
CREATE DCM PROJECT IF NOT EXISTS DCM_SBX_ADMIN_DB.PROJECTS.DCM_SBX_PROJECT_PRD
    COMMENT = 'DCM Sandbox (PRD): RAW（COVID19）と チーム別 ANALYTICS / WH / ロールを管理';

SHOW DCM PROJECTS IN SCHEMA DCM_SBX_ADMIN_DB.PROJECTS;
