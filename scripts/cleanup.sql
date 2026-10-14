--!jinja
-- =============================================================================
-- クリーンナップ
--   env => 'DEV' / 'PRD' : その環境の DCM 管理オブジェクトを PURGE し、プロジェクトを削除する
--   env => 'ALL'         : DEV・PRD 両方を上記のとおり削除し、DCM 管理ロール・管理用 WH・Git 統合・DCM_SBX_ADMIN_DB も削除する
--                          （setup.sql 実行前の状態に戻る）
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
-- DCM 管理ロール、Git リポジトリ・プロジェクトの置き場（DB）、Git 統合を削除する
-- （このスクリプト自体は実行開始時に読み込み済みのため、リポジトリを含む DB を削除しても最後まで実行される）
DROP WAREHOUSE IF EXISTS DCM_SBX_ADMIN_WH;
DROP ROLE IF EXISTS DCM_SBX_ADMIN_ROLE;
DROP DATABASE IF EXISTS DCM_SBX_ADMIN_DB;
DROP INTEGRATION IF EXISTS DCM_SBX_GIT_API_INTEGRATION;
-- アカウント設定 FEATURE_RBAC_INHERITED_GRANTS は他の用途にも影響するため戻さない
-- 戻す場合: ALTER ACCOUNT UNSET FEATURE_RBAC_INHERITED_GRANTS;
{% endif %}
