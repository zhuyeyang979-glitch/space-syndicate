# VFX Event Language

Visual events are UI-only semantic messages. They may be sourced from Scenario Lab fixtures, runtime public events, or local showcase data. They must not run rules, reveal private state, or mutate game state.

Required event language:

- `card_hover_glow`: hand card/object glow.
- `card_pickup`: card separates from rack.
- `card_drag_valid`: valid target highlight.
- `card_drag_invalid`: invalid target highlight and short reason.
- `card_play_flyout`: card motion from rack to target/public track.
- `card_reveal_flash`: anonymous/public-track reveal flash.
- `target_arrow`: drag or play targeting line.
- `monster_spawn_pulse`: monster arrival in a region.
- `monster_move_trail`: source-to-destination trail.
- `monster_attack_windup`: anticipation before hit.
- `monster_attack_impact`: impact circle and screen-safe shake language.
- `city_damage_crack`: city crack/red edge.
- `route_damage_spark`: route line damage cue.
- `military_fire_line`: shot/beam to impact point.
- `cash_gain_float`: resource gain/loss float.
- `gdp_delta_float`: GDP delta float.
- `final_countdown_pulse`: finale warning pulse.

Reduced motion mode renders the same events as static markers and labels.
