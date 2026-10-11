{#
  create_team(team): 1 チーム分のリソースを定義する
    WH / FR ロール（WH 権限） / ANALYTICS DB（SILVER・GOLD） / DB ロール / 役割ロール
  役割ロール（DEVELOPER / VIEWER）は SYSADMIN に継承させる
  ※ マクロファイルにはマクロ以外を書けないため、説明は Jinja コメントで書く
#}
{% macro create_team(team) %}
{% set wh = 'DCM_SBX_' ~ team ~ '_WH' ~ env_suffix %}
{% set db = 'DCM_SBX_' ~ team ~ '_ANALYTICS_DB' ~ env_suffix %}
{% set fr_operate = 'DCM_SBX_FR_WH_' ~ team ~ '_OPERATE' ~ env_suffix %}
{% set fr_use = 'DCM_SBX_FR_WH_' ~ team ~ '_USE' ~ env_suffix %}
{% set developer = 'DCM_SBX_' ~ team ~ '_DEVELOPER_ROLE' ~ env_suffix %}
{% set viewer = 'DCM_SBX_' ~ team ~ '_VIEWER_ROLE' ~ env_suffix %}

-- ---- ウェアハウス ----------------------------------------------------------
define warehouse {{wh}}
with
    warehouse_size = '{{wh_size}}'
    auto_suspend = {{wh_auto_suspend}}
    auto_resume = TRUE
    initially_suspended = TRUE
    statement_timeout_in_seconds = {{wh_statement_timeout}}
    comment = '{{team}} 用ウェアハウス';

define role {{fr_operate}} comment = '{{wh}} の USAGE + OPERATE';
define role {{fr_use}}     comment = '{{wh}} の USAGE のみ';

grant usage, operate on warehouse {{wh}} to role {{fr_operate}};
grant usage          on warehouse {{wh}} to role {{fr_use}};

-- ---- ANALYTICS DB（スキーマまで） -------------------------------------------
define database {{db}}
    comment = '{{team}} の加工（Silver）とマート（Gold）の置き場';

define schema {{db}}.SILVER comment = 'Silver: RAW をクレンジング・紐づけしたデータ';
define schema {{db}}.GOLD   comment = 'Gold: 業務指標を集計したマート';

-- ---- DB ロール（スキーマごとに WRITE / READ） --------------------------------
{% for layer in ['SILVER', 'GOLD'] %}
define database role {{db}}.{{layer}}_WRITE comment = '{{layer}} の読み書き';
define database role {{db}}.{{layer}}_READ  comment = '{{layer}} の読み取り';

grant usage, create table, create view on schema {{db}}.{{layer}} to database role {{db}}.{{layer}}_WRITE;
grant inherited select, insert, update, delete, truncate on all tables in schema {{db}}.{{layer}} to database role {{db}}.{{layer}}_WRITE;
grant inherited select on all views in schema {{db}}.{{layer}} to database role {{db}}.{{layer}}_WRITE;

grant usage on schema {{db}}.{{layer}} to database role {{db}}.{{layer}}_READ;
grant inherited select on all tables in schema {{db}}.{{layer}} to database role {{db}}.{{layer}}_READ;
grant inherited select on all views  in schema {{db}}.{{layer}} to database role {{db}}.{{layer}}_READ;
{% endfor %}

-- ---- 役割ロール ------------------------------------------------------------
define role {{developer}} comment = '{{team}} の開発者（ANALYTICS 読み書き / RAW 読み取り）';
define role {{viewer}}    comment = '{{team}} の閲覧者（ANALYTICS / RAW 読み取り）';

grant database role {{db}}.SILVER_WRITE                to role {{developer}};
grant database role {{db}}.GOLD_WRITE                  to role {{developer}};
grant database role DCM_SBX_RAW_DB{{env_suffix}}.COVID19_READ     to role {{developer}};
grant role {{fr_operate}}                              to role {{developer}};

grant database role {{db}}.SILVER_READ                 to role {{viewer}};
grant database role {{db}}.GOLD_READ                   to role {{viewer}};
grant database role DCM_SBX_RAW_DB{{env_suffix}}.COVID19_READ     to role {{viewer}};
grant role {{fr_use}}                                  to role {{viewer}};

grant role {{developer}} to role SYSADMIN;
grant role {{viewer}}    to role SYSADMIN;
{% endmacro %}
