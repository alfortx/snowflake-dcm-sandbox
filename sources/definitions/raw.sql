-- =============================================================================
-- RAW 層: COVID-19 Data Lake（公開 S3 バケット、認証不要）を参照する
-- データはロードしない。外部テーブルは DCM 非対応のため、ステージを直接 SELECT するビューで代替する
-- =============================================================================

define database DCM_SBX_RAW_DB{{env_suffix}}
    comment = 'DCM Sandbox: COVID-19 Data Lake の Raw データ参照用';

define schema DCM_SBX_RAW_DB{{env_suffix}}.COVID19
    comment = 'COVID-19 時系列データ（公開 S3 を直接参照）';

define file format DCM_SBX_RAW_DB{{env_suffix}}.COVID19.CSV_FORMAT
    type = CSV
    skip_header = 1
    field_optionally_enclosed_by = '"'
    null_if = ('', 'NA', 'NULL')
    comment = 'CSV format for COVID-19 Data Lake';

-- -----------------------------------------------------------------------------
-- 外部ステージ（公開バケットのため STORAGE_INTEGRATION / CREDENTIALS なし）
-- -----------------------------------------------------------------------------
define stage DCM_SBX_RAW_DB{{env_suffix}}.COVID19.COVID19_S3_STAGE
    url = 's3://covid19-lake/enigma-jhu-timeseries/csv/'
    file_format = (format_name = 'DCM_SBX_RAW_DB{{env_suffix}}.COVID19.CSV_FORMAT')
    comment = 'JHU COVID-19 timeseries';

define stage DCM_SBX_RAW_DB{{env_suffix}}.COVID19.COVID19_WORLD_TESTING_STAGE
    url = 's3://covid19-lake/rearc-covid-19-world-cases-deaths-testing/csv/'
    file_format = (format_name = 'DCM_SBX_RAW_DB{{env_suffix}}.COVID19.CSV_FORMAT')
    comment = 'COVID-19 world cases, deaths, testing, vaccination';

define stage DCM_SBX_RAW_DB{{env_suffix}}.COVID19.COVID19_NYT_USA_STAGE
    url = 's3://covid19-lake/rearc-covid-19-nyt-data-in-usa/csv/us-states/'
    file_format = (format_name = 'DCM_SBX_RAW_DB{{env_suffix}}.COVID19.CSV_FORMAT')
    comment = 'NYTimes US state-level COVID-19 (2020-01 to 2022-06)';

-- -----------------------------------------------------------------------------
-- ビュー（外部テーブルの代替。$N = CSV の N 列目）
-- -----------------------------------------------------------------------------
define view DCM_SBX_RAW_DB{{env_suffix}}.COVID19.JHU_TIMESERIES
    comment = 'JHU COVID-19 時系列データ（ステージ直接参照）'
as
select
    try_to_number($1::varchar)   as UID,
    try_to_number($2::varchar)   as FIPS,
    $3::varchar                  as ISO2,
    $4::varchar                  as ISO3,
    try_to_number($5::varchar)   as CODE3,
    $6::varchar                  as ADMIN2,
    try_to_double($7::varchar)   as LATITUDE,
    try_to_double($8::varchar)   as LONGITUDE,
    $9::varchar                  as PROVINCE_STATE,
    $10::varchar                 as COUNTRY_REGION,
    try_to_date($11::varchar)    as DATE,
    try_to_number($12::varchar)  as CONFIRMED,
    try_to_number($13::varchar)  as DEATHS,
    try_to_number($14::varchar)  as RECOVERED
from @DCM_SBX_RAW_DB{{env_suffix}}.COVID19.COVID19_S3_STAGE
    (file_format => 'DCM_SBX_RAW_DB{{env_suffix}}.COVID19.CSV_FORMAT', pattern => '.*[.]csv');

define view DCM_SBX_RAW_DB{{env_suffix}}.COVID19.COVID19_WORLD_TESTING
    comment = 'COVID-19 world testing, vaccination, hospital data（ステージ直接参照）'
as
select
    $1::varchar                  as ISO_CODE,
    $2::varchar                  as CONTINENT,
    $3::varchar                  as LOCATION,
    try_to_date($4::varchar)     as DATE,
    try_to_number($5::varchar)   as TOTAL_CASES,
    try_to_number($6::varchar)   as NEW_CASES,
    try_to_double($7::varchar)   as NEW_CASES_SMOOTHED,
    try_to_number($8::varchar)   as TOTAL_DEATHS,
    try_to_number($9::varchar)   as NEW_DEATHS,
    try_to_double($10::varchar)  as NEW_DEATHS_SMOOTHED,
    try_to_number($26::varchar)  as NEW_TESTS,
    try_to_number($27::varchar)  as TOTAL_TESTS,
    try_to_double($32::varchar)  as POSITIVE_RATE,
    try_to_number($35::varchar)  as TOTAL_VACCINATIONS,
    try_to_number($36::varchar)  as PEOPLE_VACCINATED,
    try_to_number($37::varchar)  as PEOPLE_FULLY_VACCINATED,
    try_to_number($38::varchar)  as TOTAL_BOOSTERS,
    try_to_number($18::varchar)  as ICU_PATIENTS,
    try_to_number($20::varchar)  as HOSP_PATIENTS,
    try_to_double($59::varchar)  as HOSPITAL_BEDS_PER_THOUSAND,
    try_to_number($47::varchar)  as POPULATION,
    try_to_double($48::varchar)  as POPULATION_DENSITY,
    try_to_double($49::varchar)  as MEDIAN_AGE,
    try_to_double($50::varchar)  as AGED_65_OLDER,
    try_to_double($51::varchar)  as AGED_70_OLDER,
    try_to_double($52::varchar)  as GDP_PER_CAPITA,
    try_to_double($55::varchar)  as DIABETES_PREVALENCE,
    try_to_double($54::varchar)  as CARDIOVASC_DEATH_RATE,
    try_to_double($60::varchar)  as LIFE_EXPECTANCY,
    try_to_double($61::varchar)  as HUMAN_DEVELOPMENT_INDEX
from @DCM_SBX_RAW_DB{{env_suffix}}.COVID19.COVID19_WORLD_TESTING_STAGE
    (file_format => 'DCM_SBX_RAW_DB{{env_suffix}}.COVID19.CSV_FORMAT', pattern => '.*[.]csv');

define view DCM_SBX_RAW_DB{{env_suffix}}.COVID19.NYT_USA_STATES
    comment = 'NYTimes 米国州別 COVID-19 累積データ（ステージ直接参照）'
as
select
    try_to_date($1::varchar)     as DATE,
    $2::varchar                  as STATE,
    try_to_number($3::varchar)   as FIPS,
    try_to_number($4::varchar)   as CASES,
    try_to_number($5::varchar)   as DEATHS
from @DCM_SBX_RAW_DB{{env_suffix}}.COVID19.COVID19_NYT_USA_STAGE
    (file_format => 'DCM_SBX_RAW_DB{{env_suffix}}.COVID19.CSV_FORMAT', pattern => '.*[.]csv');
