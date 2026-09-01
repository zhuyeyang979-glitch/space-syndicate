# Space Syndicate Product Continuity Registry

GENERATED_FROM=SPACE_SYNDICATE_PRODUCT_CONTINUITY_REGISTRY.json


This is a generated index. The JSON file is the only continuity authority; existing Owner, reuse, green-ledger, Golden-scenario, and card-certification records remain their own authorities.

## Current identity

| Field | Value |
| --- | --- |
| Current version | v0.7.6 |
| Activation head | e372c105cb0e0727f07347bda215cf526f79f75a |
| Production entry | res://scenes/main.tscn |
| Product task interrupted | false |


## Registry counts

| Section | Count |
| --- | --- |
| versions | 4 |
| capabilities | 37 |
| product_surfaces | 33 |
| assets | 13 |
| current_work_items | 29 |
| future_backlog | 6 |
| retired_goals | 3 |
| cancelled_goals | 0 |


## Product surface reachability

| Surface | Current status | Production reachable | Path / evidence |
| --- | --- | --- | --- |
| surface.application_entry | INHERITED_PRODUCTION | true | project.godot -> scenes/main.tscn |
| surface.menu_root_lobby | ACTIVE_PRODUCTION | true | main.tscn -> V075SampleGameScreen/OverlayLayer/CommercialShellSurfaceLayer/MenuModalOverlay -> MenuLifecycleApplicationFlowController |
| surface.menu_overlay | ACTIVE_PRODUCTION | true | main.tscn -> V075SampleGameScreen/OverlayLayer/CommercialShellSurfaceLayer/MenuModalOverlay |
| surface.menu_quick_navigation | ACTIVE_PRODUCTION | true | MenuOverlay -> MenuQuickNavigation |
| surface.new_game_setup_lobby | PRESENT_NOT_PRODUCTION_REACHABLE | false | NewGameSetupPage legacy flow only |
| surface.new_game_setup_page | PRESENT_NOT_PRODUCTION_REACHABLE | false | SetupApplicationFlowController absent from current main closure |
| surface.embedded_start_overlay | INHERITED_PRODUCTION | true | main.tscn -> V075SampleGameScreen -> V074/V073 inherited inline OverlayLayer |
| surface.settings | ACTIVE_PRODUCTION | true | MenuRootLobby -> MenuLifecycleApplicationFlowController -> CommercialSettingsSurface |
| surface.save_continue | DEFERRED | false | new-game-only candidate |
| surface.rules | ACTIVE_PRODUCTION | true | MenuLifecycleApplicationFlowController -> RulesQuickReferenceBoard |
| surface.card_codex | ACTIVE_PRODUCTION | true | MenuOverlay -> CodexCompendiumSurface -> CardCodexBrowserPanel |
| surface.bestiary | ACTIVE_PRODUCTION | true | MenuOverlay -> CodexCompendiumSurface -> BestiaryCodexBrowser |
| surface.main_table | INHERITED_PRODUCTION | true | main.tscn -> V075SampleGameScreen |
| surface.planet_map | INHERITED_PRODUCTION | true | V075SampleGameScreen -> PlanetBoard -> PlanetMapView |
| surface.player_seats | INHERITED_PRODUCTION | true | V075RuntimeOwner roster projection |
| surface.shared_track | INHERITED_PRODUCTION | true | V075RuntimeOwner -> unified track -> V074 presentation |
| surface.general_hand | INHERITED_PRODUCTION | true | personal DBG facts -> V075 hand rail |
| surface.commodity_hand | INHERITED_PRODUCTION | true | commodity inventory facts -> dedicated commodity hand rail |
| surface.public_arrangement | ACTIVE_PRODUCTION | true | V075SampleGameScreen -> CentralPublicActionArrangement |
| surface.private_direct_action | ACTIVE_ISOLATED | true | V076 authorized input owner -> existing runtime adapter |
| surface.action_feed | INHERITED_PRODUCTION | true | V075SampleGameScreen action feed |
| surface.coach_marks | INHERITED_PRODUCTION | true | embedded V073 coach |
| surface.telemetry_feedback | INHERITED_PRODUCTION | true | V073 telemetry service bound by V075 bootstrap |
| surface.economy | INHERITED_PRODUCTION | true | V07 asset/economy owners consumed by runtime |
| surface.facilities | INHERITED_PRODUCTION | true | V074 facility runtime -> V075 runtime |
| surface.combat_observatory | ACTIVE_ISOLATED | true | V075 combat surface and presentation consumer |
| surface.ai | INHERITED_PRODUCTION | true | V075 RuntimeOwner AI policy |
| surface.victory | INHERITED_PRODUCTION | true | V075RuntimeOwner -> V07SolarVictoryCore |
| surface.audio | UNKNOWN_REQUIRES_AUDIT | false | dynamic/resource references not fully statically proven |
| surface.localization | ACTIVE_SUPPORT | true | project.godot translation pack |
| surface.accessibility | ACTIVE_SUPPORT | true | focusable production controls and semantic card labels |
| surface.export_build | ACTIVE_SUPPORT | true | project.godot and launcher |
| surface.developer_diagnostics | DIAGNOSTIC_ONLY | false | test/bench scripts only |


## Known gaps
- `gap.legacy_menu_reachability` — Historical menu/settings/codex/rules/credits surfaces are now reachable through the single CommercialShellSurfaceLayer; standalone NewGameSetupPage remains intentionally superseded by the inherited StartOverlay.
- `gap.natural_tail_handoff_4` — Default full-tail authority probe breaks at handoff 4; focused three-handoff proof remains separate.
- `gap.per_card_production_certification` — 348-card production/runtime/human certification remains incomplete.
- `gap.monster_32_card_mapping` — 32 monster catalog records lack exact production mapping proof.
- `gap.military_human_certification` — Military direct-action evidence is isolated; human and full production certification remain pending.
- `gap.human_candidate_4_pending` — Human Candidate 4 short retest and observer attestation have not been completed.
- `gap.save_resume_not_in_sample` — The current Alpha 0.7 candidate is new-game-only; Save/Continue is deferred to the separate recovery line.
- `gap.full_world_reproof_deferred` — Full 79 gates, 2,000 seed/replay reproof and full-world card proof are intentionally not rerun for this cross-domain UI candidate.
- `gap.dynamic_surface_audit` — Dynamic audio/resource reachability requires runtime evidence and remains UNKNOWN until audited.
- `gap.v076_reuse_history_metadata` — The current Reuse/Point-Inertia selftest is green, but full committed-history validation reports 445 failures, including 407 historical failures and at least 22 that have no correction path under the existing governance contract.