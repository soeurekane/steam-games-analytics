-- Steam Games Analytics
-- Примеры запросов к artifacts/steam_games.db.
-- База создаётся выполнением notebooks/steam_games_portfolio.ipynb.

-- 1. Самые распространённые жанры
SELECT
    g.genre_name,
    COUNT(DISTINCT gg.appid) AS games_count
FROM game_genres AS gg
JOIN genres AS g USING (genre_id)
GROUP BY g.genre_name
ORDER BY games_count DESC, g.genre_name
LIMIT 10;

-- 2. Медианная USD-цена по жанрам минимум с 10 платными играми
WITH paid_games AS (
    SELECT
        g.genre_name,
        gs.appid,
        gs.price_usd
    FROM games AS gs
    JOIN game_genres AS gg USING (appid)
    JOIN genres AS g USING (genre_id)
    WHERE gs.is_free = 0
      AND gs.price_usd IS NOT NULL
      AND gs.price_currency = 'USD'
),
ranked AS (
    SELECT
        genre_name,
        price_usd,
        ROW_NUMBER() OVER (
            PARTITION BY genre_name
            ORDER BY price_usd
        ) AS row_number,
        COUNT(*) OVER (PARTITION BY genre_name) AS games_count
    FROM paid_games
)
SELECT
    genre_name,
    MAX(games_count) AS paid_games_count,
    ROUND(AVG(price_usd), 2) AS median_price_usd
FROM ranked
WHERE row_number IN ((games_count + 1) / 2, (games_count + 2) / 2)
GROUP BY genre_name
HAVING MAX(games_count) >= 10
ORDER BY median_price_usd DESC, genre_name;

-- 3. Медианное число рекомендаций: free-to-play и платные игры
WITH ranked AS (
    SELECT
        is_free,
        recommendations,
        ROW_NUMBER() OVER (
            PARTITION BY is_free
            ORDER BY recommendations
        ) AS row_number,
        COUNT(*) OVER (PARTITION BY is_free) AS games_count
    FROM games
    WHERE recommendations IS NOT NULL
)
SELECT
    CASE WHEN is_free = 1 THEN 'free' ELSE 'paid' END AS model,
    MAX(games_count) AS games_count,
    AVG(recommendations) AS median_recommendations
FROM ranked
WHERE row_number IN ((games_count + 1) / 2, (games_count + 2) / 2)
GROUP BY is_free
ORDER BY is_free;

-- 4. Три самых дорогих платных игры в каждом жанре
WITH ranked_games AS (
    SELECT
        g.genre_name,
        gs.name,
        gs.price_usd,
        DENSE_RANK() OVER (
            PARTITION BY g.genre_name
            ORDER BY gs.price_usd DESC
        ) AS price_rank
    FROM games AS gs
    JOIN game_genres AS gg USING (appid)
    JOIN genres AS g USING (genre_id)
    WHERE gs.is_free = 0
      AND gs.price_usd IS NOT NULL
      AND gs.price_currency = 'USD'
)
SELECT genre_name, name, price_usd, price_rank
FROM ranked_games
WHERE price_rank <= 3
ORDER BY genre_name, price_rank, name;

-- 5. Сравнение рекомендаций по периоду релиза и модели монетизации
WITH periodized AS (
    SELECT
        CASE
            WHEN release_year <= 2014 THEN '≤2014'
            WHEN release_year <= 2019 THEN '2015–2019'
            WHEN release_year <= 2023 THEN '2020–2023'
            ELSE '2024+'
        END AS release_period,
        CASE WHEN is_free = 1 THEN 'free' ELSE 'paid' END AS model,
        recommendations
    FROM games
    WHERE release_year IS NOT NULL
      AND recommendations IS NOT NULL
)
SELECT
    release_period,
    model,
    COUNT(*) AS games_count,
    ROUND(AVG(recommendations), 1) AS avg_recommendations
FROM periodized
GROUP BY release_period, model
ORDER BY
    CASE release_period
        WHEN '≤2014' THEN 1
        WHEN '2015–2019' THEN 2
        WHEN '2020–2023' THEN 3
        ELSE 4
    END,
    model;
