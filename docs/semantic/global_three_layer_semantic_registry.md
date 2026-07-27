# Global Three-Layer Semantic Registry

This is the human-readable companion to
`docs/semantic/global_three_layer_semantic_registry.json`. The JSON file is the
single machine-readable authority; this document explains its current truth
state and must not be maintained as a competing registry.

## Version truth

- Current production runtime ruleset: **V0.6**
- Highest target development constitution: **V0.7**
- Full V0.7 runtime cutover: **false**
- Registered domains: **24**
- Core-ready domains: **18**
- Fully three-layer-ready domains: **1**
- Global three-layer semantics complete: **false**

Coverage means that every required registry field has an explicit value. It
does not mean that a domain is ready. A domain is `THREE_LAYER_READY` only when
its core authority, authorized AI interpretation, and authorized player
projection/intent path all operate on the same runtime facts.

## Completed vertical slice: player action routing

`player_action_routing` is the first production vertical slice that is marked
`THREE_LAYER_READY` and `CUTOVER_COMPLETE`.

```text
GameActionOfferV1
        ↓
GameActionIntentV1  ← human_click / human_drag / human_quick_action / ai_decision
        ↓
TablePlayerActionApplicationFlowController
        ↓
CardPlaySubmissionRuntimeController / CardGroupActionPort /
DistrictSupplyActionPort / other existing domain owners
        ↓
GameActionReceiptV1
```

The flow owns authorization, source-revision checks, bounded exact-once
request identity, routing, and refresh requests. It owns no card rules, world
state, RNG, Save data, AI policy, or player-facing copy authority.

The production cutover removes these responsibilities from `main.gd`:

- raw `action_requested`, `end_turn_requested`, and `card_drop_requested`
  consumption;
- `play_`, `district_`, and `group_order_` action-prefix dispatch;
- `Callable` execution from player-board action DTOs;
- card-drop `Vector2` interpretation as a gameplay input;
- card-group ready and reorder forwarding;
- the legacy Main card-play forwarding wrapper.

Human and AI card play now submit the same semantic action and reach the same
card-play command target. AI receipts do not cross the player-private feedback
signal. Screen coordinates remain inside GameScreen and become a stable public
region ID; the application flow and card submission owner revalidate the
authoritative district.

## Domain status matrix

| Domain | Core | AI | Player | Main-free | Cutover | Next atomic boundary |
| --- | --- | --- | --- | --- | --- | --- |
| session_setup | CORE_READY | CONTRACT_ONLY | CORE_PLAYER_READY | CUTOVER_COMPLETE | CORE_PLAYER_READY | AI_SETUP_OBSERVATION_CONTRACT |
| runtime_lifecycle | CORE_READY | CONTRACT_ONLY | PASSIVE_PROJECTION_ONLY | CUTOVER_COMPLETE | CUTOVER_COMPLETE | NONE_RUNTIME_LOOP_STABLE |
| ordinary_cards | CORE_READY | CONTRACT_ONLY | CORE_PLAYER_READY | CUTOVER_COMPLETE | CORE_PLAYER_READY | AI_WORLD_TYPED_PORTS_AND_MAIN_BINDING_REMOVAL |
| card_group_resolution | CORE_READY | LEGACY_RAW | CORE_PLAYER_READY | CUTOVER_COMPLETE | CORE_PLAYER_READY | AI_WORLD_TYPED_PORTS_AND_MAIN_BINDING_REMOVAL |
| commodity_inventory | CONTRACT_ONLY | PASSIVE_PROJECTION_ONLY | PASSIVE_PROJECTION_ONLY | CUTOVER_COMPLETE | CONTRACT_ONLY | V07_COMMODITY_INVENTORY_CORE_OWNER_AND_SAVE_PREFLIGHT |
| commodity_sushi_track | CONTRACT_ONLY | PASSIVE_PROJECTION_ONLY | PASSIVE_PROJECTION_ONLY | CUTOVER_COMPLETE | CONTRACT_ONLY | V07_SHARED_COMMODITY_TRACK_CORE_OWNER |
| market_stance_cycle | CONTRACT_ONLY | PASSIVE_PROJECTION_ONLY | PASSIVE_PROJECTION_ONLY | CUTOVER_COMPLETE | CONTRACT_ONLY | V07_MARKET_STANCE_CYCLE_CORE_OWNER |
| economy_gdp | CORE_READY | CORE_AI_READY | CORE_PLAYER_READY | BLOCKED | CORE_AI_READY | AI_WORLD_TYPED_PORTS_AND_MAIN_BINDING_REMOVAL |
| product_market | CORE_READY | LEGACY_RAW | CORE_PLAYER_READY | BLOCKED | CORE_PLAYER_READY | AI_PRODUCT_MARKET_OBSERVATION_PORT |
| commodity_flow | CORE_READY | LEGACY_RAW | CORE_PLAYER_READY | BLOCKED | CORE_PLAYER_READY | AI_COMMODITY_FLOW_OBSERVATION_PORT |
| routes | CORE_READY | LEGACY_RAW | PASSIVE_PROJECTION_ONLY | BLOCKED | BLOCKED | AI_ROUTE_TYPED_OBSERVATION_AND_SAVE_OWNER_PREFLIGHT |
| regions_cities_facilities | CORE_READY | CORE_AI_READY | CORE_PLAYER_READY | BLOCKED | BLOCKED | AI_ACTOR_CITY_AUTHORIZATION_TYPED_PORT_MIGRATION_PREFLIGHT |
| monsters | CORE_READY | CORE_AI_READY | PASSIVE_PROJECTION_ONLY | BLOCKED | CORE_AI_READY | AI_MONSTER_OBSERVATION_PORT |
| military | CORE_READY | LEGACY_RAW | PASSIVE_PROJECTION_ONLY | BLOCKED | BLOCKED | MILITARY_COMMAND_COVERAGE_AND_SAVE_OWNER |
| weather | CORE_READY | CORE_AI_READY | CORE_PLAYER_READY | BLOCKED | CORE_PLAYER_READY | WEATHER_SHARED_GAME_ACTION_ADOPTION |
| intel_history_inference | CORE_READY | CONTRACT_ONLY | CORE_PLAYER_READY | BLOCKED | CORE_PLAYER_READY | AI_INTEL_INFERENCE_OBSERVATION_PORT |
| victory_audit | CORE_READY | LEGACY_RAW | CORE_PLAYER_READY | BLOCKED | CORE_PLAYER_READY | V07_COMPLETE_MACRO_ROUND_END_GATE_CORE_OWNER |
| final_settlement | CORE_READY | CONTRACT_ONLY | CORE_PLAYER_READY | CUTOVER_COMPLETE | CUTOVER_COMPLETE | P1_SAVE_RESUME_OWNER_COVERAGE |
| save_restore | BLOCKED | CONTRACT_ONLY | CONTRACT_ONLY | BLOCKED | BLOCKED | P1_SAVE_RESUME_OWNER_COVERAGE |
| rng_replay | CORE_READY | CONTRACT_ONLY | CONTRACT_ONLY | CUTOVER_COMPLETE | CORE_READY | NONE_REPLAY_DEFERRED_UNTIL_COMMAND_COVERAGE |
| table_presentation | CORE_READY | CONTRACT_ONLY | CORE_PLAYER_READY | CUTOVER_COMPLETE | CUTOVER_COMPLETE | NONE_PRESENTATION_SOURCE_TARGET_STABLE |
| player_action_routing | THREE_LAYER_READY | THREE_LAYER_READY | THREE_LAYER_READY | CUTOVER_COMPLETE | CUTOVER_COMPLETE | AI_WORLD_TYPED_PORTS_AND_MAIN_BINDING_REMOVAL |
| ai_observation_decision_action | CONTRACT_ONLY | LEGACY_RAW | CONTRACT_ONLY | BLOCKED | BLOCKED | AI_WORLD_TYPED_PORTS_AND_MAIN_BINDING_REMOVAL |
| application_navigation | CORE_READY | CONTRACT_ONLY | CORE_PLAYER_READY | CUTOVER_COMPLETE | CUTOVER_COMPLETE | NONE_APPLICATION_FLOW_STABLE |

## Remaining global blockers

- `bind_ai_world(self)` and broad AI world reads remain a separate P0 boundary.
- Production Save Owner coverage remains incomplete; Save/Resume is not ready.
- V0.7 shared commodity track, market stance cycle, independent commodity
  capacity, linear upgrades, and macro-round end gate remain contract/reference
  semantics rather than production authority.
- No replay, rollback, multiplayer synchronization, or second Save system has
  been introduced.

The next minimum boundary is
`AI_WORLD_TYPED_PORTS_AND_MAIN_BINDING_REMOVAL`. It must consume the action
spine established here rather than recreate it.
