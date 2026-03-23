-- Event-level wide table: T1 events + content metadata + provider info
-- Grain: one row per deduplicated event (~9.2M rows after bot filter)
-- Bots filtered, deduped via rid
-- Use this in Lightdash to explore raw behaviour

select
    -- dedup key
    e.rid,

    -- user & session identity
    e.user_id,
    e.login_id,
    e.session_id,
    e.session_idx,

    -- timestamps
    e.collector_tstamp,
    e.derived_tstamp,
    date(e.collector_tstamp)                        as event_date,
    hour(e.collector_tstamp)                        as event_hour,

    -- event classification
    e.event,
    e.se_category,
    e.se_action,
    e.se_label,
    e.se_property,

    -- geography
    e.geo_country,
    e.geo_region_name,
    e.geo_city,

    -- parsed context fields
    e.cc_page_type:pageType::text                   as page_type,
    e.cc_page_type:appLocale::text                  as locale,
    e.cc_yauaa:deviceClass::text                    as device_class,
    e.cc_yauaa:agentName::text                      as browser_name,
    e.app_id,
    e.platform,

    -- content identity
    e.cc_title:jwEntityId::text                     as content_id,
    e.cc_title:objectType::text                     as content_type,
    e.cc_title:seasonNumber::int                    as season_number,
    e.cc_title:episodeNumber::int                   as episode_number,

    -- search
    e.cc_search:searchEntry::text                   as search_query,

    -- provider / clickout
    e.cc_clickout:providerId::number                as provider_id,
    p.clear_name                                    as provider_name,
    p.technical_name                                as provider_slug,
    p.monetization_types                            as provider_monetization_types,

    -- content metadata (from OBJECTS — null when event has no content context)
    o.title                                         as content_title,
    o.object_type                                   as content_object_type,
    o.release_year,
    o.runtime,
    o.original_language,
    o.imdb_score,
    o.genre_tmdb[0]::text                           as primary_genre,
    o.seasons                                       as show_seasons,
    o.short_description                             as content_description

from {{ ref('base_events_t1') }} e

left join {{ source('jw_shared', 'OBJECTS') }} o
    on e.cc_title:jwEntityId::text = o.object_id

left join {{ source('jw_shared', 'PACKAGES') }} p
    on e.cc_clickout:providerId::number = p.id

where
    e.cc_yauaa:deviceClass::text not in ('Robot', 'Spy', 'Hacker')

qualify
    row_number() over (partition by e.rid order by e.collector_tstamp) = 1
