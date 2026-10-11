-- =============================================================================
-- クリーンナップ: DCM が作った全オブジェクトと DCM 管理ロール・プロジェクトを削除する
--   Git 統合（API Integration / DCM_SBX_ADMIN_DB.GIT のリポジトリ）は残す
--   実行: ACCOUNTADMIN
--     EXECUTE IMMEDIATE FROM '@DCM_SBX_ADMIN_DB.GIT.DCM_SBX_REPO/branches/main/scripts/cleanup.sql';
-- =============================================================================

-- DCM 管理オブジェクト（DB / WH / ロール / GRANT）をすべて削除する。プロジェクト自体は残る
EXECUTE DCM PROJECT DCM_SBX_ADMIN_DB.PROJECTS.DCM_SBX_PROJECT PURGE;

DROP DCM PROJECT IF EXISTS DCM_SBX_ADMIN_DB.PROJECTS.DCM_SBX_PROJECT;
DROP SCHEMA IF EXISTS DCM_SBX_ADMIN_DB.PROJECTS;
DROP DATABASE ROLE IF EXISTS DCM_SBX_ADMIN_DB.DCM_ADMIN;
DROP ROLE IF EXISTS DCM_SBX_ADMIN_ROLE;

-- -----------------------------------------------------------------------------
-- Git 統合まで完全に削除する場合（通常は実行しない）
-- -----------------------------------------------------------------------------
-- DROP DATABASE IF EXISTS DCM_SBX_ADMIN_DB;
-- DROP INTEGRATION IF EXISTS DCM_SBX_GIT_API_INTEGRATION;
