-- Steam Games Analytics
-- Примеры SQL-запросов к steam_games.db

-- 1. Самые распространённые жанры
SELECT
    g.genre_name,
    COUNT(DISTINCT gg.appid) AS games_count
FROM game_genres gg
JOIN genres g
    ON gg.genre_id = g.genre_id
GROUP BY g.genre_name
ORDER BY games_count DESC
LIMIT 10;

-- 2. Средняя цена платных игр по жанрам
SELECT
    g.genre_name,
    COUNT(DISTINCT gs.appid) AS paid_games_count,
    ROUND(AVG(gs.price), 2) AS avg_price
FROM games gs
JOIN game_genres gg
    ON gs.appid = gg.appid
JOIN genres g
    ON gg.genre_id = g.genre_id
WHERE gs.is_free = 0
  AND gs.price IS NOT NULL
GROUP BY g.genre_name
ORDER BY avg_price DESC;

-- 3. Бесплатные и платные игры
SELECT
    CASE
        WHEN is_free = 1 THEN 'free'
        ELSE 'paid'
    END AS game_type,
    COUNT(*) AS games_count,
    ROUND(AVG(recommendations), 2) AS avg_recommendations
FROM games
GROUP BY is_free;

-- 4. Разработчики с наибольшим числом игр
SELECT
    d.developer_name,
    COUNT(DISTINCT gd.appid) AS games_count
FROM game_developers gd
JOIN developers d
    ON gd.developer_id = d.developer_id
GROUP BY d.developer_name
ORDER BY games_count DESC
LIMIT 10;

-- 5. Топ-3 самых дорогих платных игр в каждом жанре
WITH ranked_games AS (
    SELECT
        g.genre_name,
        gs.name,
        gs.price,
        DENSE_RANK() OVER (
            PARTITION BY g.genre_name
            ORDER BY gs.price DESC
        ) AS price_rank
    FROM games gs
    JOIN game_genres gg
        ON gs.appid = gg.appid
    JOIN genres g
        ON gg.genre_id = g.genre_id
    WHERE gs.is_free = 0
      AND gs.price IS NOT NULL
)
SELECT
    genre_name,
    name,
    price,
    price_rank
FROM ranked_games
WHERE price_rank <= 3
ORDER BY genre_name, price_rank, name;

-- 6. Игры дороже средней цены по своему жанру
WITH genre_avg AS (
    SELECT
        g.genre_id,
        AVG(gs.price) AS avg_genre_price
    FROM games gs
    JOIN game_genres gg
        ON gs.appid = gg.appid
    JOIN genres g
        ON gg.genre_id = g.genre_id
    WHERE gs.is_free = 0
      AND gs.price IS NOT NULL
    GROUP BY g.genre_id
)
SELECT
    g.genre_name,
    gs.name,
    gs.price,
    ROUND(ga.avg_genre_price, 2) AS avg_genre_price
FROM games gs
JOIN game_genres gg
    ON gs.appid = gg.appid
JOIN genres g
    ON gg.genre_id = g.genre_id
JOIN genre_avg ga
    ON g.genre_id = ga.genre_id
WHERE gs.is_free = 0
  AND gs.price IS NOT NULL
  AND gs.price > ga.avg_genre_price
ORDER BY g.genre_name, gs.price DESC;
