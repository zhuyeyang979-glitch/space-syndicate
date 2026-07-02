# Vertical Slice Showcase Spec

## Scope

`Hearthstone-grade Vertical Slice v1` is a deterministic 45-90 second commercial showcase for Space Syndicate. It does not replace Scenario Lab and does not modify scenario progression. It consumes Scenario Lab visual events when available; until then it uses `data/showcase/hearthstone_grade_sequence.json`.

## Scenario Lab Bridge

Codex A owns the commercial presentation surface. Codex B owns Scenario Lab fixtures, scenario navigation, coach copy, replay, and scenario progression. The bridge contract is intentionally narrow:

- Scenario Lab may provide `visual_events: Array[Dictionary]` with the same event vocabulary used by `VisualEventLayer`.
- `ShowcaseDirector.scenario_snapshot(id)` groups stages, event classes, and silent audio hooks for `first_table`, `monster_pressure`, `public_track_intro`, and `bid_practice`.
- `VerticalSliceShowcase.play_scenario(id)` starts the first stage of that segment, so future Scenario Browser entries can launch the same presentation layer without changing rules.
- `ScenarioLabShowcaseAdapter.normalize_payload(payload)` accepts Codex B payloads with `scenario_id`, `stage_id`, `coach_copy`, `visual_events`, `audio_hooks`, and optional public `targeting`.
- `VerticalSliceShowcase.play_scenario_payload(payload)` renders that payload through the same table, hand rack, target overlay, visual layer, and inspector used by local showcase stages.
- Hidden truth, opponent hand contents, true anonymous-card ownership, AI scoring, and private cash remain outside the bridge.
- Payloads containing keys such as `true_owner`, `opponent_private`, `private_cash`, `ai_score`, or `decision_sample` are marked unsafe and their visual events are not shown.

## Scenario Coverage

| Scenario | Required commercial proof |
| --- | --- |
| `first_table` | Board idle, card hover, valid/invalid targeting, card flyout, public reveal, resource floats, and balance preview. |
| `monster_pressure` | Monster spawn, movement trail, attack windup, impact, city crack, cash/GDP floats, and pressure-card balance preview. |
| `public_track_intro` | Anonymous reveal, route-damage spark, public-track highlight, bid pointer handoff, and hidden-info boundary copy. |
| `bid_practice` | BidBoard pointer, public anonymous card highlight, public bid labels, recommendation vocabulary, and final-countdown hook. |

## Sequence

| Time | Stage | Required visible behavior |
| ---: | --- | --- |
| 00:00 | board_idle | Planet table, public track, right inspector, resource strip, bid strip, and HandRack are all readable. |
| 00:03 | card_hover | First hand card lifts, glows, and right inspector previews full card explanation. |
| 00:06 | card_drag_valid | Card is held above the rack; target arrow points to a valid region with "松开出牌". |
| 00:08 | card_drag_invalid | Invalid region turns red with a short reason; card has invalid drop feedback. |
| 00:10 | card_play_frame_00 | Card begins flyout from hand toward map/public track. |
| 00:12 | card_play_frame_08 | Card crosses the board, target flashes, resources begin to float. |
| 00:15 | card_play_frame_16 | Card reveal flash lands on public track and right inspector logs the effect. |
| 00:18 | monster_spawn | Monster token drops into the threatened region with pulse color. |
| 00:23 | monster_move | Trail connects origin and destination; endpoint shakes/pulses. |
| 00:28 | monster_attack_frame_00 | Attack windup begins. |
| 00:31 | monster_attack_frame_12 | Impact reaches the city. |
| 00:35 | monster_attack_frame_24 | City damage crack, red edge, HP and GDP floats are visible. |
| 00:38 | public_track_reveal | Public track reveals anonymous card state without owner truth. |
| 00:40 | bid_highlight | BidBoard highlight points to the public card and uses public price labels only. |
| 00:45 | balance_report_preview | Balance preview shows price anomalies and first-table recommended cards. |

## Completion Gates

- `VerticalSliceShowcase.tscn` must load as an editor-visible scene.
- `showcase_director.gd` must play deterministic stages from JSON.
- `VisualEventLayer` must render at least ten event classes.
- `TargetingOverlay` must show valid and invalid target feedback.
- `AudioEventBus` must record silent audio hooks.
- `balance_report.md` must contain price-low Top 20, price-high Top 20, rank-gradient anomalies, and first-table recommendations.
- `showcase_frame_capture.gd` must save the required frame sequence.

## Hidden Information

The showcase may display anonymous card state, public bids, city damage, and public clues. It must not display true card owners, AI scores, rival private cash, hidden scenario truth, or opponent hand contents.
