--!jinja
-- =============================================================================
-- クリーンナップ
--   env => 'DEV' / 'PRD' : その環境の DCM 管理オブジェクトを PURGE し、プロジェクトを削除する
--   env => 'ALL'         : DEV・PRD 両方を上記のとおり削除し、DCM 管理ロール等も削除する
--   Git 統合（API Integration / DCM_SBX_ADMIN_DB.GIT のリポジトリ）は残す
--   実行: ACCOUNTADMIN
--     EXECUTE IMMEDIATE FROM '@DCM_SBX_ADMIN_DB.GIT.DCM_SBX_REPO/branches/main/scripts/cleanup.sql'
--       USING (env => 'ALL');
-- =============================================================================
{% set envs = ['DEV', 'PRD'] if env == 'ALL' else [env] %}

{% for e in envs %}
-- {{ e }}: DCM 管理オブジェクト（DB / WH / ロール / GRANT）をすべて削除し、プロジェクトも削除する
EXECUTE DCM PROJECT DCM_SBX_ADMIN_DB.PROJECTS.DCM_SBX_PROJECT_{{ e }} PURGE;
DROP DCM PROJECT IF EXISTS DCM_SBX_ADMIN_DB.PROJECTS.DCM_SBX_PROJECT_{{ e }};
{% endfor %}

{% if env == 'ALL' %}
-- DCM 管理ロールとプロジェクト置き場を削除する
DROP SCHEMA IF EXISTS DCM_SBX_ADMIN_DB.PROJECTS;
DROP DATABASE ROLE IF EXISTS DCM_SBX_ADMIN_DB.DCM_ADMIN;
DROP ROLE IF EXISTS DCM_SBX_ADMIN_ROLE;

-- Git 統合まで完全に削除する場合（通常は実行しない）
-- DROP DATABASE IF EXISTS DCM_SBX_ADMIN_DB;
-- DROP INTEGRATION IF EXISTS DCM_SBX_GIT_API_INTEGRATION;
{% endif %}
