# Space Syndicate Version History

GENERATED_FROM=SPACE_SYNDICATE_PRODUCT_CONTINUITY_REGISTRY.json


## Version lineage

| Version | Parent | Base commit | Final/current commit | Release status | Human play |
| --- | --- | --- | --- | --- | --- |
| v0.7.3 | ROOT | f49c86af20b6a65e9792aa87703154e853d4dc76 | f49c86af20b6a65e9792aa87703154e853d4dc76 | HISTORICAL_RELEASE | HISTORICAL_GREEN |
| v0.7.4 | v0.7.3 | f49c86af20b6a65e9792aa87703154e853d4dc76 | 915d8c2f966fdf3f578aafa6c89c626e2e37ae02 | HISTORICAL_RELEASE | HISTORICAL_GREEN |
| v0.7.5 | v0.7.4 | 915d8c2f966fdf3f578aafa6c89c626e2e37ae02 | 770d741f05964facda4afcbddcdeb3e7f40571d5 | BASELINE_PRODUCTION_CANDIDATE | BASELINE_HUMAN_EVIDENCE_INHERITED |
| v0.7.6 | v0.7.5 | 770d741f05964facda4afcbddcdeb3e7f40571d5 | OPEN | DRAFT_PR_CANDIDATE | HUMAN_RETEST_DEFERRED_NOT_GREEN |


## Version deltas

### VERSION_DELTA_V0_7_3

- Inherited: none
- Added: product.application.main_menu, product.application.new_game_setup, product.application.settings, product.application.codex_entry, product.application.rules_entry, product.application.credits_entry, product.application.exit, product.main_table, product.player_seats, product.shared_sushi_track, product.general_hand, product.commodity_hand, product.action_feed, product.coach_marks, product.card_catalog, product.asset_owner, product.victory.final_settlement, product.legacy_main_owner
- Changed: none
- Fixed: none separately registered; see changed
- Migrated: none separately registered; see inherited/changed
- Superseded: none
- Retired: none
- Cancelled goals: none
- Deferred: product.application.continue
- Known gaps: gap.save_resume_not_in_sample
- Delta metadata: none; fixed=none; verified existing=none; added/restored=none; restored=none

### VERSION_DELTA_V0_7_4

- Inherited: product.application.new_game_setup, product.application.exit, product.player_seats, product.general_hand, product.commodity_hand, product.action_feed, product.coach_marks, product.card_catalog, product.asset_owner, product.victory.final_settlement, product.legacy_main_owner
- Added: product.planet_map, product.facilities, product.warehouse, product.commodity_flow, product.v074.float_voronoi_authority
- Changed: product.shared_sushi_track, product.main_table
- Fixed: none separately registered; see changed
- Migrated: none separately registered; see inherited/changed
- Superseded: none
- Retired: none
- Cancelled goals: none
- Deferred: product.application.main_menu, product.application.settings, product.application.continue, product.application.codex_entry, product.application.rules_entry, product.application.credits_entry
- Known gaps: gap.legacy_menu_reachability
- Delta metadata: none; fixed=none; verified existing=none; added/restored=none; restored=none

### VERSION_DELTA_V0_7_5

- Inherited: product.application.new_game_setup, product.application.exit, product.main_table, product.planet_map, product.shared_sushi_track, product.general_hand, product.commodity_hand, product.coach_marks, product.card_catalog, product.asset_owner, product.facilities, product.warehouse, product.commodity_flow, product.v074.float_voronoi_authority
- Added: product.public_arrangement, product.monster, product.military, product.combat, product.ai, product.combat_observatory
- Changed: product.player_seats, product.action_feed, product.victory.final_settlement
- Fixed: none separately registered; see changed
- Migrated: none separately registered; see inherited/changed
- Superseded: none
- Retired: product.legacy_main_owner
- Cancelled goals: none
- Deferred: product.application.main_menu, product.application.settings, product.application.continue, product.application.codex_entry, product.application.rules_entry, product.application.credits_entry
- Known gaps: gap.legacy_menu_reachability, gap.per_card_production_certification
- Delta metadata: none; fixed=none; verified existing=none; added/restored=none; restored=none

### VERSION_DELTA_V0_7_6

- Inherited: product.application.exit, product.main_table, product.planet_map, product.player_seats, product.action_feed, product.monster, product.military, product.combat, product.ai, product.victory.final_settlement, product.card_catalog, product.asset_owner, product.facilities, product.warehouse, product.commodity_flow, product.combat_observatory
- Added: product.v076.deterministic_kernel, product.v076.half_edge_sphere, product.v076.monster_geodesic_move, product.v076.private_direct_action, product.v076.military_physical_eta, product.new_game_loading_feedback
- Changed: product.public_arrangement, product.general_hand, product.commodity_hand, product.shared_sushi_track, product.application.new_game_setup, product.coach_marks
- Fixed: none separately registered; see changed
- Migrated: none separately registered; see inherited/changed
- Superseded: product.v074.float_voronoi_authority
- Retired: product.legacy_main_owner
- Cancelled goals: none
- Deferred: product.application.main_menu, product.application.settings, product.application.continue, product.application.codex_entry, product.application.rules_entry, product.application.credits_entry, product.card_certification
- Known gaps: gap.legacy_menu_reachability, gap.natural_tail_handoff_4, gap.per_card_production_certification, gap.human_candidate_4_pending, gap.full_world_reproof_deferred, gap.v076_reuse_history_metadata
- Delta metadata: Submission Window Presentation; fixed=Hand Post-Queue Rendering — pending headed human confirmation; verified existing=Production Clock Liveness — existing single RuntimeOwner verified live; no clock rule repair; added/restored=Facility Map Visual Projection — restored fullscreen parity through the existing PlanetBoard fan-out; restored=Bottom Countdown Production Reachability — PRESENT_NOT_PRODUCTION_REACHABLE -> ACTIVE_PRODUCTION
