-- =============================================================================
-- PLAN（ドライラン）: 作成・変更・削除される予定のオブジェクトを確認する
--   呼び出し側で事前に実行しておくこと:
--     ALTER GIT REPOSITORY DCM_SBX_ADMIN_DB.GIT.DCM_SBX_REPO FETCH;
--     USE ROLE DCM_SBX_ADMIN_ROLE;  USE WAREHOUSE SANDBOX_WH;
--   実行: EXECUTE IMMEDIATE FROM '@DCM_SBX_ADMIN_DB.GIT.DCM_SBX_REPO/branches/main/scripts/plan.sql';
-- =============================================================================
EXECUTE DCM PROJECT DCM_SBX_ADMIN_DB.PROJECTS.DCM_SBX_PROJECT
    PLAN
    USING CONFIGURATION DEV
    FROM '@DCM_SBX_ADMIN_DB.GIT.DCM_SBX_REPO/branches/main/';
