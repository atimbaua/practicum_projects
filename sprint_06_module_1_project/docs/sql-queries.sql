/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 * 
 * Автор: Панов А.В.
 * Дата: 17.11.2025
*/

-- Задача 1: Время активности объявлений
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
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
stats_categories AS (
    SELECT
        CASE
            WHEN a.days_exposition <= 30 THEN '1-30 days'
            WHEN a.days_exposition <= 90 THEN '31-90 days'
            WHEN a.days_exposition <= 180 THEN '91-180 days'
            WHEN a.days_exposition > 180 THEN '181+ days'
        ELSE 'non category'
        END AS exposition_category,
        CASE
            WHEN f.city_id = '6X8I' THEN 'Санкт-Петербург'
        ELSE 'Ленинградская область'
        END AS city_category,
        f.id,
        a.last_price,
        f.total_area,
        f.rooms,
        f.balcony,
        f.floor,
        f.floors_total,
        f.ceiling_height,
        f.airports_nearest,
        f.parks_around3000,
        f.ponds_around3000,
        f.is_apartment,
        f.open_plan
    FROM real_estate.flats f
    JOIN real_estate.advertisement a ON f.id = a.id
    WHERE f.id IN (SELECT * FROM filtered_id)
        AND (a.first_day_exposition BETWEEN '2015-01-01' AND '2018-12-31')
        AND f.type_id = 'F8EM'
)
SELECT
    exposition_category,
    city_category,
    COUNT(id) adv_count,
    SUM(COUNT(id)) OVER (PARTITION BY city_category) total_city_count,
    ROUND(100 * (COUNT(id) / SUM(COUNT(id)) OVER (PARTITION BY city_category)), 1) adv_by_region,
    ROUND(AVG(last_price::numeric / total_area::numeric), 0) avg_m2_price,
    ROUND(AVG(total_area::numeric), 0) avg_total_area,
    ROUND(AVG(rooms::numeric), 0) avg_rooms,
    ROUND(AVG(balcony::numeric), 0) avg_balcony,
    ROUND(AVG(floor::numeric), 0) avg_floor,
    ROUND(AVG(floors_total::numeric), 0) avg_floors_total,
    ROUND(AVG(ceiling_height::numeric), 0) avg_ceiling_height,
    ROUND((SUM(CASE WHEN is_apartment = 1 THEN 1 ELSE 0 END)::numeric / COUNT(id)) * 100, 1) apartment_percent,
    ROUND((SUM(CASE WHEN open_plan = 1 THEN 1 ELSE 0 END)::numeric / COUNT(id)) * 100, 1) open_plan_percent,
    ROUND(AVG(airports_nearest::numeric), 0) avg_airports_nearest,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY parks_around3000) med_parks,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY ponds_around3000) med_ponds
FROM stats_categories
GROUP BY exposition_category, city_category
ORDER BY city_category, COUNT(id) DESC;

-- Задача 2: Сезонность объявлений
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
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
 pub_months AS (
    SELECT EXTRACT(MONTH FROM a.first_day_exposition) AS pub_month,
           COUNT(*) AS pub_count,
           ROUND(AVG(a.last_price / f.total_area)::numeric, 0) pub_avg_sqm_price,
           ROUND(AVG(f.total_area)::numeric, 0) pub_avg_total_area
    FROM real_estate.advertisement a
    JOIN real_estate.flats f ON a.id = f.id
    WHERE (EXTRACT(YEAR FROM a.first_day_exposition) BETWEEN 2015 AND 2018)
    		AND f.type_id = 'F8EM' AND f.id IN (SELECT * FROM filtered_id)
    GROUP BY pub_month
),
removal_months AS (
    SELECT EXTRACT(MONTH FROM a.first_day_exposition + a.days_exposition::integer) AS removal_month,
           COUNT(*) AS removal_count,
           ROUND(AVG(a.last_price / f.total_area)::numeric, 0) removal_avg_sqm_price,
           ROUND(AVG(f.total_area)::numeric, 0) removal_avg_total_area
    FROM real_estate.advertisement a
    JOIN real_estate.flats f ON a.id = f.id
    WHERE (EXTRACT(YEAR FROM a.first_day_exposition + a.days_exposition::integer) BETWEEN 2015 AND 2018)
    		AND f.type_id = 'F8EM' AND f.id IN (SELECT * FROM filtered_id)
    GROUP BY removal_month
)
SELECT
	CASE pub_month
        WHEN 1 THEN 'Январь'
        WHEN 2 THEN 'Февраль'
        WHEN 3 THEN 'Март'
        WHEN 4 THEN 'Апрель'
        WHEN 5 THEN 'Май'
        WHEN 6 THEN 'Июнь'
        WHEN 7 THEN 'Июль'
        WHEN 8 THEN 'Август'
        WHEN 9 THEN 'Сентябрь'
        WHEN 10 THEN 'Октябрь'
        WHEN 11 THEN 'Ноябрь'
        WHEN 12 THEN 'Декабрь'
    END AS pub_month_name,
       pub_count,
       RANK() OVER(ORDER BY pub_count DESC) rank_pub_count,
       SUM(pub_count) OVER () AS total_pub_count,
       ROUND(100*(pub_count / SUM(pub_count) OVER ()), 1) part_pub_of_total,
       pub_avg_sqm_price,
       pub_avg_total_area,
    CASE removal_month
        WHEN 1 THEN 'Январь'
        WHEN 2 THEN 'Февраль'
        WHEN 3 THEN 'Март'
        WHEN 4 THEN 'Апрель'
        WHEN 5 THEN 'Май'
        WHEN 6 THEN 'Июнь'
        WHEN 7 THEN 'Июль'
        WHEN 8 THEN 'Август'
        WHEN 9 THEN 'Сентябрь'
        WHEN 10 THEN 'Октябрь'
        WHEN 11 THEN 'Ноябрь'
        WHEN 12 THEN 'Декабрь'
    END AS removal_month_name,
       removal_count,
       RANK() OVER(ORDER BY removal_count DESC) rank_removal_count,
       SUM(removal_count) OVER () AS total_removal_count,
       ROUND(100*(removal_count / SUM(removal_count) OVER ()), 1) part_removal_of_total,
       removal_avg_sqm_price,
       removal_avg_total_area
FROM pub_months
FULL JOIN removal_months ON pub_months.pub_month = removal_months.removal_month;
