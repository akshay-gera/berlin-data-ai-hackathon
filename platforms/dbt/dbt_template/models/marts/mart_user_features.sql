-- User-level feature table for audience segmentation (Challenge 5)
-- Grain: one row per user_id
-- Feed this into clustering / segment labelling
-- Depends on: mart_events_wide

with base_agg as (

    select
        user_id,

        -- volume signals
        count(*)                                                                            as total_events,
        count(distinct session_id)                                                          as total_sessions,
        count(distinct event_date)                                                          as days_active,
        count(case when event = 'page_view' then 1 end)                                    as total_page_views,

        -- clickout signals (purchase intent)
        count(case when se_category = 'clickout' then 1 end)                               as total_clickouts,
        count(case when se_category = 'clickout' and se_action = 'flatrate' then 1 end)    as clickouts_flatrate,
        count(case when se_category = 'clickout' and se_action = 'free' then 1 end)        as clickouts_free,
        count(case when se_category = 'clickout' and se_action = 'ads' then 1 end)         as clickouts_ads,
        count(case when se_category = 'clickout' and se_action = 'rent' then 1 end)        as clickouts_rent,
        count(case when se_category = 'clickout' and se_action = 'buy' then 1 end)         as clickouts_buy,

        -- engagement ratios
        round(
            count(case when se_category = 'clickout' then 1 end)::float / nullif(count(*), 0),
        4)                                                                                  as clickout_rate,
        round(
            count(*)::float / nullif(count(distinct session_id), 0),
        2)                                                                                  as avg_events_per_session,

        -- content preferences
        count(distinct content_id)                                                          as unique_titles_viewed,
        count(case when content_type = 'movie' then 1 end)                                 as movie_events,
        count(case when content_type in ('show', 'season', 'episode') then 1 end)          as show_events,
        round(
            count(case when content_type = 'movie' then 1 end)::float
            / nullif(count(case when content_type is not null then 1 end), 0),
        4)                                                                                  as movie_share,

        -- curation signals (watchlist / seenlist / likes)
        count(case when se_category = 'watchlist_add' then 1 end)                          as watchlist_adds,
        count(case when se_category = 'seenlist_add' then 1 end)                           as seenlist_adds,
        count(case when se_category = 'likelist_add' then 1 end)                           as likelist_adds,
        count(case when se_category = 'dislikelist_add' then 1 end)                        as dislikelist_adds,

        -- search behaviour
        count(case when search_query is not null then 1 end)                               as search_events,

        -- trailer engagement
        count(case when se_category = 'youtube_started' then 1 end)                       as trailer_plays,

        -- login status (proxy for account quality)
        max(case when login_id is not null then 1 else 0 end)                              as is_logged_in_user,

        -- recency
        max(event_date)                                                                     as last_active_date,
        min(event_date)                                                                     as first_active_date

    from {{ ref('mart_events_wide') }}
    group by user_id

),

-- Top device per user (most frequent)
top_device as (
    select user_id, device_class as primary_device
    from (
        select user_id, device_class, count(*) as cnt
        from {{ ref('mart_events_wide') }}
        where device_class is not null
        group by user_id, device_class
    )
    qualify row_number() over (partition by user_id order by cnt desc) = 1
),

-- Top streaming provider per user (by clickout count)
top_provider as (
    select user_id, provider_name as top_provider
    from (
        select user_id, provider_name, count(*) as cnt
        from {{ ref('mart_events_wide') }}
        where se_category = 'clickout' and provider_name is not null
        group by user_id, provider_name
    )
    qualify row_number() over (partition by user_id order by cnt desc) = 1
),

-- Top genre per user (by event count on content pages)
top_genre as (
    select user_id, primary_genre as top_genre
    from (
        select user_id, primary_genre, count(*) as cnt
        from {{ ref('mart_events_wide') }}
        where primary_genre is not null
        group by user_id, primary_genre
    )
    qualify row_number() over (partition by user_id order by cnt desc) = 1
),

-- Top locale per user
top_locale as (
    select user_id, locale as primary_locale
    from (
        select user_id, locale, count(*) as cnt
        from {{ ref('mart_events_wide') }}
        where locale is not null
        group by user_id, locale
    )
    qualify row_number() over (partition by user_id order by cnt desc) = 1

)

select
    b.*,
    d.primary_device,
    prov.top_provider,
    g.top_genre,
    l.primary_locale

from base_agg b
left join top_device   d    using (user_id)
left join top_provider prov using (user_id)
left join top_genre    g    using (user_id)
left join top_locale   l    using (user_id)
