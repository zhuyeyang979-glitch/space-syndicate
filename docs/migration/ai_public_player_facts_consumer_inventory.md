# AI Public Player Facts Consumer Inventory

## Status

- Task: `AI_PUBLIC_PLAYER_FACTS_TYPED_PORT_MIGRATION`
- Parent: `P0-AI-WORLD-TYPED-PORTS-CUTOVER` remains `ACTIVE`.
- Rule authority: `GREEN`.
- Existing query port reused: `AiActorStatePort`.
- New public-player port: none.
- Unknown consumers: `0`.
- Persistence requirement: none; Save Registry remains unchanged.

## Authority

| Fact | Authority |
| --- | --- |
| Public seat identity and elimination state | `WorldSessionState` |
| Session identity and revision | `GameSessionRuntimeController` |
| Public role definition | `RoleCatalogRuntimeService` |
| AI scoring semantics | `AiRuntimeController` |
| Public Victory audit rows | `VictoryControlRuntimeController.public_snapshot()` |

`StandingsPublicQueryPort` is not an AI authority because it combines viewer-private state. Region, monster, military, market, hand, and Victory-private facts remain in their existing owners.

## Consumer Classification

| Consumer | Classification | Previous source | Typed source or disposition |
| --- | --- | --- | --- |
| `_typed_ai_player_indices` | ALREADY_TYPED_PUBLIC_IDENTITY | `AiActorStatePort` | Retained |
| `_player_is_ai` | ALREADY_TYPED_PUBLIC_IDENTITY | `AiActorStatePort` | Retained with strict roster validation |
| `_player_is_eliminated` | ALREADY_TYPED_PUBLIC_IDENTITY | `AiActorStatePort` | Retained; malformed or absent player fails closed |
| `_ai_player_count` | PUBLIC_PLAYER_FACT | AI index array | `AiActorStatePort.ai_player_count(true)` |
| `_ai_player_indices` | PUBLIC_PLAYER_FACT | AI index array | Active typed indices; eliminated seats excluded |
| `_ai_profile_for_config_index` | PUBLIC_PLAYER_FACT | public roster scan | `human_player_count(true)` |
| `_rival_build_player_order` | PUBLIC_PLAYER_FACT | typed AI indices | Retained; includes eliminated AI and preserves one RNG draw per seat |
| player count and bounds checks | PUBLIC_PLAYER_FACT | `players.size()` | `_public_player_count()` |
| `_player_role_card_for_index` | PUBLIC_PLAYER_FACT | Monster method-name bridge | `AiActorStatePort.public_role_definition()` |
| `_interaction_target_label` | PRESENTATION_ONLY | Main method-name call | `AiActorStatePort.public_target_label()` |
| card-play and city-guess target labels | PRESENTATION_ONLY | local `玩家N` formatting | typed target-label API |
| `_ai_direct_player_interaction_plan` identity loop | PUBLIC_PLAYER_FACT | whole `players` array | `public_active_target_rows()`; stable order, self and eliminated filtered |
| `_queue_skill_resolution` target revalidation | PUBLIC_PLAYER_FACT | previously trusted planned `target_player` | current `public_player_snapshot()` immediately before submit; absent, self, or eliminated fails closed |
| direct-player rival Victory input | VICTORY_PUBLIC_FACT | rival `private_snapshot` | public audit row when present, otherwise unknown/zero |
| direct-player rival city count | PUBLIC_REGION_FACT | hidden city Owner | Removed from score as `PRIVACY_CORRECTION` |
| direct-player rival monster count | PUBLIC_MONSTER_FACT | hidden monster Owner | Removed from score as `PRIVACY_CORRECTION` |
| `_ai_actor_private_receive_pressure` | ACTOR_PRIVATE_FACT | own mutable hand | Explicitly deferred to hand/inventory migration |
| `_ensure_player_runtime_defaults` | ACTOR_PRIVATE_FACT | mutable players | Deferred mutation path; not presented as public query |
| city inference candidates | ACTOR_CITY_INFERENCE | actor-scoped region query | Existing `AiRegionKnowledgeQueryPort`; only labels/count bounds migrated |
| own cash, cooldown, hand, discard | ACTOR_PRIVATE_FACT | mutable player record | Deferred typed domains |
| product, market, route consumers | PUBLIC_MARKET_FACT | domain controllers and bridge | Deferred |
| public region and facility facts | PUBLIC_REGION_FACT | public domain projections | Deferred; facility aggregate has no current AI consumer |
| anonymous monster facts | PUBLIC_MONSTER_FACT | Monster public projection | Deferred |
| own monster identity and capacity | ACTOR_PRIVATE_FACT | Monster private authority | Deferred |
| anonymous military facts | PUBLIC_MILITARY_FACT | Military public projection | Deferred |
| own military command state | ACTOR_PRIVATE_FACT | Military private authority | Deferred |
| live Victory rank and posture | VICTORY_PUBLIC_FACT | mixed own-private/public audit | Deferred to the Victory typed boundary |
| diagnostics and training vectors | DIAGNOSTIC_ONLY | mixed private domains | Deferred; not represented as public player facts |

## Main And Bridge Disposition

Deleted from `scripts/main.gd`:

- `MIN_PLAYER_COUNT`
- `MAX_PLAYER_COUNT`
- their AI constant-snapshot entries
- `_player_is_ai`
- `_human_player_count`
- `_interaction_target_label`

Retained because other production domains still consume them:

- `_player_name`
- `_player_is_eliminated`
- `AiRuntimeWorldBridge.call_world`
- `AiRuntimeController._call_world`
- the generic `players` bridge for deferred domains

After this cutover the AI controller contains 42 `_call_world` references, 27 `players` tokens, and 95 `districts` tokens. These counts describe remaining parent-P0 work and are not claimed green here.

## Privacy Decision

The former direct-player score read each rival's private Victory candidate, hidden city ownership, and hidden monster ownership. Exact parity with that score is forbidden. The migrated path uses the typed active public roster and an existing public Victory audit row only when that row is formally visible. Hidden city and monster pressure are zero. This is an intentional privacy correction; personality definitions, candidate tie order, action frequency, and RNG order are unchanged.

## QA Hardening

- The Coordinator creates and prebinds its single `AiActorStateCapability` from the parent `_enter_tree()` before the first child lifecycle callback. Hostile child attempts in both `_enter_tree()` and `_ready()` have accept count 0; ordinary wiring only reuses the formal instance.
- Public schema 1 authorizes the `eliminated` flag only. `eliminated_at` and `elimination_reason` remain WorldSession/private fixture data and have public leak count 0.
- AI revalidates any planned player target from the current typed public row immediately before calling `submit_card_play()`. Post-plan elimination, self, and missing targets fail closed with CardPlay submission delta 0.
- `CardPlaySubmissionRuntimeController`, `CardTargetChoice`, and `CardResolutionExecution` remain unchanged. Later target revalidation remains card-rule Owner work and is not claimed here.

## Evidence

- Focused test: `128/128 PASS`.
- Existing actor-state focused regression: `93/93 PASS`.
- City inference regression: `48/48 PASS`.
- Typed World Ports regression: `83/83 PASS`.
- Production Bench: `31/31 PASS`, privacy leaks 0, Main routes 0.
- Hostile early-bind accepts: 0; public elimination-detail leaks: 0; invalid-target CardPlay submission delta: 0.
- Main budget: 6461 to 6440 physical lines, 5436 to 5421 nonblank lines, 473 to 470 methods, 47 to 45 constants.
- Main fields, preloads, and production reference files are unchanged.
