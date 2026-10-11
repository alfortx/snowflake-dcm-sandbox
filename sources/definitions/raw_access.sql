-- =============================================================================
-- RAW 層のアクセスロール（読み取りのみ。各チームの DEVELOPER / VIEWER が継承）
-- =============================================================================

define database role {{prefix}}_RAW_DB.COVID19_READ
    comment = 'COVID19 スキーマの読み取り';

grant usage on schema {{prefix}}_RAW_DB.COVID19 to database role {{prefix}}_RAW_DB.COVID19_READ;

-- INHERITED grant: 今ある／今後できるビュー・テーブルすべてに SELECT（FUTURE grant の後継）
grant inherited select on all views  in schema {{prefix}}_RAW_DB.COVID19 to database role {{prefix}}_RAW_DB.COVID19_READ;
grant inherited select on all tables in schema {{prefix}}_RAW_DB.COVID19 to database role {{prefix}}_RAW_DB.COVID19_READ;
