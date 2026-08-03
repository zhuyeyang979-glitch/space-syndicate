# V0.7.3 Atomic Production Cutover

STATUS=V073_SAMPLE_PRODUCTION_CONNECTED

CONSTITUTION_ID=space_syndicate.v073.complete
CURRENT_PRODUCTION_RUNTIME_RULESET=V0.7.3
SAMPLE_MODE_ID=NEW_V073_GAME

PRODUCTION_CUTOVER_AUTHORIZED=true
PRODUCTION_SCENE_CHANGE=true
MAIN_CHANGE=true

NEW_GAME_ONLY=true
SAVE_RESUME_ENABLED=false
SAVE_ADAPTER_CONNECTED=false

V073_ATOMIC_CUTOVER_DOMAIN_COUNT=19
V073_CONNECTED_DOMAIN_COUNT=19
V073_DUAL_WRITE_COUNT=0
V073_LEGACY_FALLBACK_COUNT=0
V073_MIXED_RULESET_STATE_COUNT=0

The production entry point is `res://scenes/main.tscn`. It instantiates only
`V073RuntimeComposition` and `V073SampleGameScreen`; the V0.6 coordinator,
commodity-only rail, regional card purchase surfaces, Save registry, public bid,
auction timer, and right permanent card panel are not reachable from this scene.

The V0.7.3 Save adapter remains detached. Save and Continue are visibly disabled,
V0.6 files are neither read nor written, and the sample accepts only a new game.

| Domain | Production owner | Legacy | Save owner | RNG owner | AI | Player | UI | Rollback boundary |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ruleset_identity | V073RulesetRuntimeOwner | disconnected | none, new game only | none | connected | connected | connected | frozen V0.6 main scene |
| new_game_setup | V073SampleApplicationFlow | disconnected | none, new game only | match seed | connected | connected | connected | abandon unpublished session |
| free_starter_deck | V07DbgDeckCore | disconnected | detached adapter | per-player starter shuffle | connected | connected | connected | discard candidate aggregate |
| personal_dbg | V07DbgDeckCore | disconnected | detached adapter | per-player reshuffle | connected | connected | connected | restore private checkpoint |
| optional_merge | V07DbgDeckCore | disconnected | detached adapter | none | connected | connected | connected | restore private checkpoint |
| unified_track | V07UnifiedCardTrackCore | disconnected | detached adapter | typed track streams | connected | connected | connected | rollback acquisition transaction |
| track_replacement_lock | V07UnifiedCardTrackCore | disconnected | detached adapter | typed track streams | connected | connected | connected | rollback before scroll publication |
| six_color_asset | V07AssetBatchCore | disconnected | detached adapter | none | connected | connected | connected | restore batch checkpoint |
| submission_window | V073SampleRuntimeOwner | disconnected | none, new game only | none | connected | connected | connected | single deadline auto-finalization |
| prebound_target | V073SampleRuntimeOwner | disconnected | detached adapter | none | connected | connected | connected | remove unlocked binding |
| full_asset_reservation | V07AssetBatchCore | disconnected | detached adapter | none | connected | connected | connected | restore reservation checkpoint |
| fixed_hidden_round_robin | V073FixedOrderFacilityContentionCore | disconnected | detached adapter | hidden lead order | connected | connected | connected | discard unpublished batch |
| facility_contention | V073FixedOrderFacilityContentionCore | disconnected | detached adapter | none | connected | connected | connected | typed Fizzle receipt |
| solar_efficiency | V07SolarVictoryCore | disconnected | detached adapter | none | connected | connected | connected | restore aggregate revision |
| ai_observation_decision | V07CanonicalAiObservationAdapter | disconnected | none, new game only | Core streams | connected | not applicable | not applicable | discard private plan |
| player_projection | V07CanonicalPlayerProjectionAdapter | disconnected | none, new game only | none | not applicable | connected | connected | drop detached projection |
| victory_macro_round_gate | V07SolarVictoryCore | disconnected | detached adapter | none | connected | connected | connected | hold pending qualification |
| final_settlement | V07SolarVictoryCore | disconnected | none, new game only | none | connected | connected | connected | exact-once commit and presentation |
| commercial_art_presentation | V073SampleGameScreen | disconnected | presentation only | presentation only | not applicable | connected | connected | replace presentation keys only |

The JSON companion is the machine-readable authority. Every domain is connected,
has its legacy path disconnected, and declares Save, RNG, adapter, UI, and rollback
ownership. No domain permits dual write or V0.6 fallback.
