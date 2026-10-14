--!jinja
-- =============================================================================
-- DEPLOY: 定義どおりにオブジェクトを作成・変更・削除する（先に plan.sql で差分を確認すること）
--   呼び出し側で事前に実行しておくこと:
--     ALTER GIT REPOSITORY DCM_SBX_ADMIN_DB.GIT.DCM_SBX_REPO FETCH;
--     USE ROLE DCM_SBX_ADMIN_ROLE;  USE WAREHOUSE DCM_SBX_ADMIN_WH;
--   実行: EXECUTE IMMEDIATE FROM '@DCM_SBX_ADMIN_DB.GIT.DCM_SBX_REPO/branches/main/scripts/deploy.sql'
--           USING (env => 'DEV');   -- または 'PRD'
-- =============================================================================
EXECUTE DCM PROJECT DCM_SBX_ADMIN_DB.PROJECTS.DCM_SBX_PROJECT_{{ env }}
    DEPLOY AS "deploy from main"
    USING CONFIGURATION {{ env }}
    FROM '@DCM_SBX_ADMIN_DB.GIT.DCM_SBX_REPO/branches/main/';
