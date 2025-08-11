-- ad-hoc задачи Задача номер 1 

WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- Выведем объявления без выбросов:
filter_data AS 
	(SELECT *
	FROM real_estate.flats
	WHERE id IN (SELECT * FROM filtered_id) 
),
-- Объявления без выбросов в advertisement
filter_advert AS (
	SELECT * 
	FROM real_estate.advertisement
	WHERE id IN (SELECT * FROM filtered_id)
),
-- Все объявления распределим по продолжительности публикации объявления
flats_categories AS (
SELECT 
    fd.*,
    fa.last_price,
    CASE WHEN fd.city_id = '6X8I' THEN 'Санкт-Петербург' -- присвоение категорий Санкт-Петербург и ЛенОбл
    ELSE 'ЛенОбл'
    END AS region,
    CASE
    	WHEN days_exposition <= 30  THEN 'до месяца' -- присвоение категорий по продолжительности размещения объявления
    	WHEN days_exposition > 30 AND days_exposition <= 90 THEN 'до квартала'
    	WHEN days_exposition > 90 AND days_exposition <= 180 THEN 'до полугода'
    ELSE 'более полугода'
    END AS activity_category,
    fa.last_price / fd.total_area AS sq_meter_price,
    t.type
FROM filter_data fd
JOIN filter_advert fa ON fa.id = fd.id
JOIN real_estate.TYPE t ON t.type_id = fd.type_id
WHERE t.type = 'город' AND days_exposition IS NOT NULL
),
-- общее кол-во объявлений по региону
region_total AS (
    SELECT 
        region,
        COUNT(id) AS total_flats
    FROM flats_categories
    GROUP BY region
),
ad_hoc_1 AS (SELECT 
    fc.region,
    activity_category,
    COUNT(id) AS count_flats,
    ROUND(AVG(sq_meter_price)::NUMERIC, 2) AS avg_meter_price,
    ROUND(AVG(total_area)::NUMERIC, 2) AS avg_total_area,
    PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY rooms) AS rooms_median,
    PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY balcony) AS balcony_median,
    PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY floor) AS floor_median,
    ROUND(count(id)::NUMERIC * 100 / total_flats, 2) AS flats_share
FROM flats_categories fc
JOIN region_total rt ON rt.region = fc.region
GROUP BY fc.region, activity_category, rt.total_flats
ORDER BY fc.region DESC, CASE activity_category
        WHEN 'до месяца' THEN 1
        WHEN 'до квартала' THEN 2
        WHEN 'до полугода' THEN 3
        WHEN 'более полугода' THEN 4
    END
)
--+-----------------+-------------------+-------------+-----------------+----------------+--------------+----------------+--------------+-------------+
--|     region      | activity_category | count_flats | avg_meter_price | avg_total_area | rooms_median | balcony_median | floor_median | flats_share |
--+-----------------+-------------------+-------------+-----------------+----------------+--------------+----------------+--------------+-------------+
--| Санкт-Петербург | до месяца         |        2168 |       110568.88 |          54.38 |            2 |            1.0 |            5 |       19.29 |
--| Санкт-Петербург | до квартала       |        3236 |       111573.24 |          56.71 |            2 |            1.0 |            5 |       28.79 |
--| Санкт-Петербург | до полугода       |        2254 |       111938.92 |          60.55 |            2 |            1.0 |            5 |       20.06 |
--| Санкт-Петербург | более полугода    |        3581 |       115457.22 |          66.15 |            2 |            1.0 |            5 |       31.86 |
--| ЛенОбл          | до месяца         |         397 |        73275.25 |          48.72 |            2 |            1.0 |            4 |       14.38 |
--| ЛенОбл          | до квартала       |         917 |        67573.43 |          50.88 |            2 |            1.0 |            3 |       33.22 |
--| ЛенОбл          | до полугода       |         556 |        69846.39 |          51.83 |            2 |            1.0 |            3 |       20.14 |
--| ЛенОбл          | более полугода    |         890 |        68297.22 |          55.41 |            2 |            1.0 |            3 |       32.25 |
--+-----------------+-------------------+-------------+-----------------+----------------+--------------+----------------+--------------+-------------+


-- AD HOC 2

WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- Выведем объявления без выбросов:
filter_data AS 
	(SELECT *
	FROM real_estate.flats
	WHERE id IN (SELECT * FROM filtered_id) 
),
-- Объявления без выбросов в advertisement
filter_advert AS (
	SELECT * 
	FROM real_estate.advertisement
	WHERE id IN (SELECT * FROM filtered_id)
),
expo_info AS (
SELECT  -- создаем общие данные по месяцам, когда объявления былыи опубликованы, исключая 2014 и 2019 годы, так как они неполные
  	COUNT(fa.id) AS start_count,
	EXTRACT( MONTH FROM first_day_exposition::date) AS month_start,
	ROUND(AVG(last_price::numeric / total_area::numeric), 2) AS avg_start_meter_price,
	ROUND(AVG(total_area::numeric),2) AS avg_start_total_area
FROM filter_advert fa
JOIN filter_data fd ON fd.id = fa.id
JOIN real_estate.TYPE t ON t.type_id = fd.type_id
WHERE EXTRACT( YEAR FROM first_day_exposition) NOT IN (2014,2019) AND  t.type = 'город'
GROUP BY month_start
),
sales_info AS (
SELECT  -- создаем общие данные по месяцам, когда объявления былыи сняты с публикации, исключая 2014 и 2019 годы, так как они неполные
	COUNT(fa.id) AS end_count,
	EXTRACT( MONTH FROM first_day_exposition::date + days_exposition * (INTERVAL '1 day')) AS month_end,
	ROUND(AVG(last_price::numeric / total_area::numeric), 2) AS avg_end_meter_price,
	ROUND(AVG(total_area::numeric),2) AS avg_end_total_area
FROM filter_advert fa
JOIN filter_data fd ON fd.id = fa.id
JOIN real_estate.TYPE t ON t.type_id = fd.type_id
WHERE EXTRACT( YEAR FROM first_day_exposition) NOT IN (2014,2019) AND  t.type = 'город' AND days_exposition IS NOT NULL
GROUP BY month_end
)
SELECT  -- Создаем общую таблицу для сравнения данных начала публикации объявлений до конца публикации по месяцам
month_start AS month,
    start_count,
    avg_start_meter_price,
    avg_start_total_area,
    RANK() OVER(ORDER BY start_count DESC) AS start_rank,
    end_count,
    avg_end_meter_price,
    avg_end_total_area,
    RANK() OVER(ORDER BY end_count DESC) AS end_rank
FROM expo_info ei
FULL JOIN sales_info si ON si.month_end = ei.month_start
ORDER BY MONTH
--+-------+-------------+-----------------------+----------------------+------------+-----------+---------------------+--------------------+----------+
--| month | start_count | avg_start_meter_price | avg_start_total_area | start_rank | end_count | avg_end_meter_price | avg_end_total_area | end_rank |
--+-------+-------------+-----------------------+----------------------+------------+-----------+---------------------+--------------------+----------+
--|     1 |         735 |             106106.24 |                59.16 |         12 |      1225 |           104947.31 |              57.53 |        4 |
--|     2 |        1369 |             103058.51 |                60.10 |          3 |      1048 |           103883.72 |              61.12 |        9 |
--|     3 |        1119 |             102429.95 |                60.00 |          8 |      1071 |           106832.40 |              60.37 |        8 |
--|     4 |        1021 |             102632.41 |                60.60 |         10 |      1031 |           102444.24 |              59.22 |       10 |
--|     5 |         891 |             102465.12 |                59.19 |         11 |       729 |            99724.07 |              57.78 |       12 |
--|     6 |        1224 |             104802.15 |                58.37 |          5 |       771 |           101863.69 |              59.82 |       11 |
--|     7 |        1149 |             104488.96 |                60.42 |          7 |      1108 |           102290.72 |              58.54 |        7 |
--|     8 |        1166 |             107034.70 |                58.99 |          6 |      1137 |           100036.51 |              56.83 |        6 |
--|     9 |        1341 |             107563.12 |                61.04 |          4 |      1238 |           104070.07 |              57.49 |        3 |
--|    10 |        1437 |             104065.11 |                59.43 |          2 |      1360 |           104317.33 |              58.86 |        1 |
--|    11 |        1569 |             105048.80 |                59.58 |          1 |      1301 |           103791.36 |              56.71 |        2 |
--|    12 |        1024 |             104775.39 |                58.84 |          9 |      1175 |           105504.52 |              59.26 |        5 |
--+-------+-------------+-----------------------+----------------------+------------+-----------+---------------------+--------------------+----------+



--AD_HOC 3 

WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- Выведем объявления без выбросов:
filter_data AS 
	(SELECT *
	FROM real_estate.flats
	WHERE id IN (SELECT * FROM filtered_id) 
),
-- Объявления без выбросов в advertisement
filter_advert AS (
	SELECT * 
	FROM real_estate.advertisement
	WHERE id IN (SELECT * FROM filtered_id)
),
total_details AS ( -- находим общие значения для квартир вне Санкт-Петербурга
SELECT fd.id,
    city,
    TYPE,
    first_day_exposition,
    days_exposition,
    last_price,
    total_area,
    ROUND(last_price::numeric / total_area::NUMERIC, 2) AS sq_meter_price,
    rooms,
    balcony,
    floor
FROM filter_data fd
JOIN filter_advert fa ON fd.id = fa.id
JOIN real_estate.type t ON fd.type_id = t.type_id
JOIN real_estate.city c ON c.city_id = fd.city_id
WHERE city <> 'Санкт-Петербург'
)
SELECT
    city,
    STRING_AGG(DISTINCT type, ', ') AS union_type,
    COUNT(id) AS total_flats,
    ROUND(COUNT(days_exposition)::NUMERIC * 100 / COUNT(id)::NUMERIC , 2) AS sales_share,
    ROUND(AVG(sq_meter_price), 2) AS avg_sq_meter_price,
    ROUND(AVG(total_area)::numeric, 2) AS avg_total_area,
    ROUND(AVG(days_exposition)::numeric,2 ) AS avg_days_exposition,
    ROUND(AVG(rooms)::NUMERIC, 2) AS avg_rooms,
    ROUND(AVG(balcony)::NUMERIC, 2) AS avg_balcony,
    PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY rooms) AS rooms_median,
    PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY balcony) AS balcony_median,
    PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY floor) AS floor_median
FROM total_details
GROUP BY city
ORDER BY total_flats DESC
LIMIT 15
--
--+-----------------+----------------+--------------+-------------+--------------------+----------------+---------------------+-----------+-------------+--------------+----------------+---------------+
--|      city       |    union_type  |  total_flats | sales_share | avg_sq_meter_price | avg_total_area | avg_days_exposition | avg_rooms | avg_balcony | rooms_median | balcony_median |  floor_median |
--+-----------------+----------------+--------------+-------------+--------------------+----------------+---------------------+-----------+-------------+--------------+----------------+---------------+
--| Мурино          | город, посёлок |          568 |       93.66 |           85968.38 |          43.86 |              149.21 |      1.38 |        1.29 |            1 |            1.0 |            10 |
--| Кудрово         | город, деревня |          463 |       93.74 |           95420.47 |          46.20 |              160.63 |      1.43 |        1.29 |            1 |            1.0 |             9 |
--| Шушары          | посёлок        |          404 |       92.57 |           78831.93 |          53.93 |              152.04 |      1.78 |        1.03 |            2 |            1.0 |             5 |
--| Всеволожск      | город          |          356 |       85.67 |           69052.79 |          55.83 |              190.11 |      1.88 |        1.23 |            2 |            1.0 |             4 |
--| Парголово       | посёлок        |          311 |       92.60 |           90272.96 |          51.34 |              156.21 |      1.59 |        1.24 |            1 |            1.0 |            12 |
--| Пушкин          | город          |          278 |       83.09 |          104158.94 |          59.74 |              196.57 |      1.94 |        0.88 |            2 |            1.0 |             3 |
--| Гатчина         | город          |          228 |       89.04 |           69004.74 |          51.02 |              188.11 |      1.89 |        1.03 |            2 |            1.0 |             3 |
--| Колпино         | город          |          227 |       92.07 |           75211.73 |          52.55 |              147.01 |      2.05 |        1.00 |            2 |            1.0 |             4 |
--| Выборг          | город          |          192 |       87.50 |           58669.99 |          56.76 |              182.33 |      2.11 |        0.64 |            2 |            0.0 |             3 |
--| Петергоф        | город          |          154 |       88.31 |           85412.48 |          51.77 |              196.57 |      1.93 |        0.99 |            2 |            1.0 |             3 |
--| Сестрорецк      | город          |          149 |       89.93 |          103848.09 |          62.45 |              214.81 |      1.98 |        1.17 |            2 |            1.0 |             4 |
--| Красное Село    | город          |          136 |       89.71 |           71972.28 |          53.20 |              205.81 |      2.01 |        0.81 |            2 |            1.0 |             3 |
--| Новое Девяткино | деревня        |          120 |       88.33 |           76879.07 |          50.52 |              175.65 |      1.59 |        1.09 |            1 |            1.0 |             6 |
--| Сертолово       | город          |          117 |       86.32 |           69566.26 |          53.62 |              173.58 |      1.85 |        0.96 |            2 |            1.0 |             3 |
--| Бугры           | посёлок        |          104 |       87.50 |           80968.41 |          47.35 |              155.90 |      1.53 |        1.38 |            1 |            2.0 |             6 |
--+-----------------+----------------+--------------+-------------+--------------------+----------------+---------------------+-----------+-------------+--------------+----------------+---------------+






    
    
    
    
    
    
