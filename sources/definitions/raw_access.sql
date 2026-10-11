-- =============================================================================
-- RAW 層のアクセスロール（読み取りのみ。各チームの DEVELOPER / VIEWER が継承）
-- =============================================================================

define database role DCM_SBX_RAW_DB{{env_suffix}}.COVID19_READ
    comment = 'COVID19 スキーマの読み取り';

grant usage on schema DCM_SBX_RAW_DB{{env_suffix}}.COVID19 to database role DCM_SBX_RAW_DB{{env_suffix}}.COVID19_READ;

-- INHERITED grant: 今ある／今後できるビュー・テーブルすべてに SELECT（FUTURE grant の後継）
grant inherited select on all views  in schema DCM_SBX_RAW_DB{{env_suffix}}.COVID19 to database role DCM_SBX_RAW_DB{{env_suffix}}.COVID19_READ;
grant inherited select on all tables in schema DCM_SBX_RAW_DB{{env_suffix}}.COVID19 to database role DCM_SBX_RAW_DB{{env_suffix}}.COVID19_READ;
