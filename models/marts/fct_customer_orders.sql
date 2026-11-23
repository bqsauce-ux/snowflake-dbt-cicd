
{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='customer_id',
        on_schema_change='sync_all_columns'
    )
}}

WITH customers AS (

    SELECT *
    FROM {{ ref('stg_customers') }}

),

orders AS (

    SELECT *
    FROM {{ ref('stg_orders') }}

),

customer_orders AS (

    SELECT
        c.customer_id,
        c.first_name,
        c.last_name,
        c.email,
        c.country,

        COUNT(o.order_id) AS total_orders,

        SUM(
            CASE
                WHEN o.order_status = 'COMPLETED'
                THEN o.order_amount
                ELSE 0
            END
        ) AS total_completed_revenue,

        MAX(o.order_date) AS last_order_date

    FROM customers c

    LEFT JOIN orders o
        ON c.customer_id = o.customer_id

    GROUP BY
        c.customer_id,
        c.first_name,
        c.last_name,
        c.email,
        c.country

)

SELECT *
FROM customer_orders

{% if is_incremental() %}

WHERE customer_id IN (

    SELECT DISTINCT customer_id
    FROM {{ ref('stg_orders') }}
    WHERE order_date >= (
        SELECT COALESCE(
            DATEADD(day, -3, MAX(last_order_date)),
            '1900-01-01'::DATE
        )
        FROM {{ this }}
    )

)

{% endif %}

