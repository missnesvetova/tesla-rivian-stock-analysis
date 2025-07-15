### Создание базовых таблиц для хранения данных по котировкам Tesla и Rivian

ALTER TABLE stock_quotes_2 RENAME TO stock_quotes_tesla
select * from stock_quotes_tesla
order by date desc

CREATE TABLE stock_quotes_rivian (
    date DATE PRIMARY KEY,
    open NUMERIC(10,2),
    high NUMERIC(10,2),
    low NUMERIC(10,2),
    close NUMERIC(10,2),
    volume BIGINT
);

### Таблицы для хранения данных по динамике дневного процентного изменения цен акций Tesla и Rivian


CREATE OR REPLACE VIEW tesla_price_change_pct AS
WITH base_returns AS (
    SELECT
        date,
        close AS tesla_close,
        LAG(close) OVER (ORDER BY date) AS prev_tesla_close,
        (close - LAG(close) OVER (ORDER BY date)) / LAG(close) OVER (ORDER BY date) AS tesla_daily_return
    FROM stock_quotes_tesla
    WHERE date_part('year', date) >= 2020
)

SELECT
    date,
    tesla_close,
    prev_tesla_close,
    tesla_daily_return,
   COALESCE(
    ROUND(
        STDDEV_SAMP(tesla_daily_return) OVER (
            ORDER BY date
            ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
        )::numeric, 6
    ), 0
) AS tesla_volatility_30d,
    'tesla' AS company_name
FROM base_returns;

CREATE OR REPLACE VIEW rivian_price_change_pct AS
WITH base2_returns AS (
    SELECT
        date,
        close AS rivian_close,
        LAG(close) OVER (ORDER BY date) AS prev_rivian_close,
        (close - LAG(close) OVER (ORDER BY date)) / LAG(close) OVER (ORDER BY date) AS rivian_daily_return
    FROM stock_quotes_rivian
    WHERE date_part('year', date) >= 2020
)

SELECT
    date,
    rivian_close,
    prev_rivian_close,
    rivian_daily_return,
    COALESCE(
    ROUND(
        STDDEV_SAMP(rivian_daily_return) OVER (
            ORDER BY date
            ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
        )::numeric, 6
    ), 0
) AS rivian_volatility_30d,
    'rivian' AS company_name
FROM base2_returns

CREATE OR REPLACE VIEW dim_calendar AS
SELECT generate_series(
    '2010-06-29'::date,
    CURRENT_DATE,
    '1 day'::interval
)::date AS date;

### Итоговое общее представление

CREATE OR REPLACE VIEW for_bi AS
SELECT 
    dc.date, 
    rivian_close,
    tesla_close,
    ra.rivian_daily_return,
    ta.tesla_daily_return,
	rivian_volatility_30d,
	tesla_volatility_30d
FROM dim_calendar dc
LEFT JOIN rivian_price_change_pct ra ON dc.date = ra.date
LEFT JOIN tesla_price_change_pct ta ON dc.date = ta.date
WHERE date_part('year', dc.date) >= 2020
ORDER BY dc.date DESC;

select * from for_bi
order by date desc