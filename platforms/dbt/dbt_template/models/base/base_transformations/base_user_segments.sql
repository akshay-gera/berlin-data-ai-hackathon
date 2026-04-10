select *
from {{ source('external_transformations', 'user_segments_v5') }}
