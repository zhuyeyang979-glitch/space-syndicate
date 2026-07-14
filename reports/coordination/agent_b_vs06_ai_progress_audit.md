# VS06-B4 AI progression read-only audit

Audit date: 2026-07-14 (Asia/Tokyo)  
Scope: source and existing evidence only. No runtime file was edited and no Godot/test command was run.

## Outcome

The first deterministic Stage 6 failure belongs to the **AI policy / vertical-slice integration boundary**, not to CommodityFlow:

- `TomorrowPlayableVerticalSliceBench._stage_ai_progress()` calls `_auto_expand_rival_syndicates(true)` behind `has_method()` and substitutes `0` when it is absent (`scripts/tools/tomorrow_playable_vertical_slice_bench.gd:453-475`).
- The current `AiRuntimeController` has no `_auto_expand_rival_syndicates` definition. The working-tree removal also deleted its old city-target helpers; the removed compatibility implementation was a constant-zero no-op, not a production builder.
- Therefore `built == 0` is guaranteed before cash, income, facility availability, or Stage 5 CommodityFlow output can matter. Stage 6 will remain red after Stage 5 turns green unless this contract is replaced.

`business_actions == 0` is then a downstream result of having no active city, rather than evidence that the AI ran out of income:

- `_rival_business_candidates_for_player()` only creates candidates inside `_active_city_indices_for_player()` (`scripts/runtime/ai_runtime_controller.gd:1458-1477`). With zero cities, additional cash cannot create a candidate.
- `_auto_rival_business_actions()` has a cash gate, but it is reached before candidate selection and is not the decisive observed gate here (`scripts/runtime/ai_runtime_controller.gd:1596-1612`). The configured baseline is `STARTING_CASH = 2000` versus `RIVAL_BUSINESS_ACTION_COST = 90` (`scripts/main.gd:109,133`); first summon is an authoritative free starter instance.
- `_ai_income_source_count()` is currently only another spelling of “AI seat has at least one legacy active city” (`scripts/tools/tomorrow_playable_vertical_slice_bench.gd:997-1002`). It does not inspect Sale Receipts, GDP, facilities, inventory, or cashflow, so `ai_income_source_count == 0` is not independent income evidence.

The latest manifest is consistent with this diagnosis: Stage 5 has zero receipts/cash/GDP, while Stage 6 still completes two first summons and two follow-up card actions with an idle queue (`reports/playability/tomorrow_vertical_slice/coordinator_runtime_manifest.json:115-142`).

## Normal scheduling versus the force helper

### Normal scheduling

1. Main advances the AI clock through `GameRuntimeCoordinator.tick_ai()` (`scripts/main.gd:1056-1058`).
2. Coordinator forwards to `AiRuntimeController.tick()` (`scripts/runtime/game_runtime_coordinator.gd:1472-1475`).
3. `tick()` calls `_update_ai_decisions()` (`scripts/runtime/ai_runtime_controller.gd:108-111`).
4. The normal card timer calls `_auto_ai_card_decisions(false)`, which invokes `_ai_execute_card_turn()` for each AI seat (`scripts/runtime/ai_runtime_controller.gd:8072-8089,7408-7416`).
5. No normal scheduler call for city/facility expansion exists in the current controller.

Legacy anonymous business pressure is on a separate clock: `ProductMarketRuntimeController.market_tick()` calls the main cycle callback (`scripts/runtime/product_market_runtime_controller.gd:613-626`), and main then invokes `_auto_rival_business_actions(false)` (`scripts/main.gd:1856-1859`). This path does not bootstrap a city.

### Vertical-slice force path

Stage 6 bypasses timers and probability, but otherwise calls the same AI card decision entry:

- first summon: `_ai_execute_card_turn(player_index, true)` (`scripts/tools/tomorrow_playable_vertical_slice_bench.gd:458-467`);
- attempted expansion: missing `_auto_expand_rival_syndicates(true)`, converted to `0` (`:474`);
- legacy business pressure: `_auto_rival_business_actions(true)` (`:475`);
- follow-up purchase/play: the same `_ai_execute_card_turn(..., true)` (`:477-488`).

The force helper is therefore not deadlocked; it is calling a removed expansion contract. Reintroducing the old zero-return compatibility function would only hide the cause and still fail `built > 0`.

## AI economy dispatch gap

The shared v0.6 economic owners are present, but the AI does not currently generate a v0.6 facility purchase/play intent:

- Coordinator exposes the canonical facility listing, market purchase, player snapshot, and card play facades (`scripts/runtime/game_runtime_coordinator.gd:918-1009,1067-1115`).
- AI purchase candidates enumerate only legacy `districts[*].card_choices` and buy through `_buy_card_for_player_from_district()` (`scripts/runtime/ai_runtime_controller.gd:6978-7008,7337-7349`). No AI caller references the v0.6 facility market facade.
- AI has no injected v0.6 inventory/CardFlow action port (`scripts/runtime/ai_runtime_controller.gd:10-23,31-72`). `AiRuntimeWorldBridge.route_intent()` would not substitute for it: main accepts only `ai_runtime_noop` and rejects other routed intents (`scripts/runtime/ai_runtime_world_bridge.gd:50-62`; `scripts/main.gd:1885-1890`).
- The existing `business_actions` route is also legacy market pressure: candidates include `price_pump` and `route_sabotage`, but main only applies `price_pump` (`scripts/runtime/ai_runtime_controller.gd:1474-1583`; `scripts/main.gd:12605-12644`). It is not a CardFlow facility transaction and should not be treated as the missing v0.6 bootstrap.

Active-city counting is additionally a legacy compatibility projection. `RouteNetworkRuntimeController.active_region_legacy_indices()` requires `legacy_city_active` (`scripts/runtime/route_network_runtime_controller.gd:103-116`), and the bridge derives that flag exclusively from `district.city` (`scripts/runtime/route_network_world_bridge.gd:29-49`). A finalized v0.6 facility is therefore not, by itself, proof that `_player_active_city_count()` will rise.

## First-summon ownership verdict

Both AI first summons did use the shared production Inventory/CardFlow/Monster owner path; they were not legacy roster writes.

The current call chain is:

```text
canonical v0.6 starter definition
  -> main seeds the starter instance in the seat hand
  -> post-seat production player binding
  -> AiRuntimeController._ai_execute_card_turn
  -> main._queue_skill_resolution (v0.6 interception)
  -> GameRuntimeCoordinator.play_v06_runtime_card
  -> CommodityCardInventoryRuntimeController.play_core_card
  -> CardFlowTransactionService
  -> MonsterCardEffectAdapterV06
  -> MonsterRuntimeController
```

Source evidence:

- Main creates the starter from `v06_starter_monster_card_by_name()`, marks only that instance with `starter_entitlement`, and seeds it into `players[*].slots` (`scripts/main.gd:10831-10849,10335-10381`). It then binds those real seats into production state (`scripts/main.gd:10384-10394`).
- AI play selection calls `_queue_skill_resolution()` only after a valid candidate succeeds (`scripts/runtime/ai_runtime_controller.gd:7274-7294,7337-7341`).
- Main intercepts nested v0.6 cards before the legacy resolution queue (`scripts/main.gd:18672-18687`) and calls the Coordinator facade (`scripts/main.gd:10515-10559`).
- Coordinator binds the transaction to the authoritative inventory slot and routes Monster effects through `inventory.play_core_card(...)` (`scripts/runtime/game_runtime_coordinator.gd:1067-1115`).
- The Stage 6 ownership oracle uses `MonsterRuntimeController.monster_private_snapshot_v06()` (`scripts/tools/tomorrow_playable_vertical_slice_bench.gd:468-473`). That snapshot returns owned units only from the v0.6 starter marker/actor binding; an unmarked or ambiguous legacy roster returns `legacy_unknown`/unavailable rather than an owned unit (`scripts/runtime/monster_runtime_controller.gd:541-620`). Observing `summon_results=[play,play]` and `owned_ai_monster_seats=2` is therefore production-owner evidence.

`followup_actions=2` plus `queue_idle=true` also rules out a generic card-decision deadlock, but it does not prove those follow-ups were v0.6 economic cards: the current AI buy catalog remains legacy.

## Dependency graph and first failure owner

```text
Stage 5 (Agent A)
  finalized v0.6 facility -> CommodityFlow -> Sale Receipt / GDP / cash
                              [currently red; independent prerequisite]

Stage 6 Monster branch
  AI card decision -> production Inventory/CardFlow -> Monster owner
                                                [green for both AI seats]

Stage 6 economy branch
  force harness -> _auto_expand_rival_syndicates
                  [method absent -> built=0: FIRST FAILURE]
       -> no authoritative AI facility/city
       -> no active-city business candidates
       -> business_actions=0

Stage 6 measurement
  ai_income_source_count -> legacy active-city count
                         [not an income oracle]
```

First failure owner: **AI economic intent generation plus the Stage 6 harness contract**. It is not RegionInfrastructure, CardFlow, or CommodityFlow, because none of those owners is called by the missing expansion step.

## Smallest next task after Stage 5 is green

Proposed task: **VS06-B5 — one AI rank-I facility bootstrap through the existing production facade**.

Minimum behavior:

1. Add one structured AI action that selects a legal region and calls the same canonical v0.6 facility market purchase + `play_v06_runtime_card()` path used by Stage 4. It must never write `players.slots`, `district.city`, facilities, cash, or flow state directly.
2. Schedule that action from the normal AI card timer when an AI has no authoritative economic source; the forced test entry must call the same action with probability/cooldown bypass only.
3. Stop at one finalized rank-I facility for at least one AI seat. Do not revive `_auto_expand_rival_syndicates` as a legacy direct builder, and do not expand legacy anonymous business behavior in this task.
4. After A's Stage 5 contract is green, use authoritative facility/CommodityFlow receipts as the progress oracle. Do not use `_player_active_city_count()` as a synonym for income.

Allowed B write boundary:

- `scripts/runtime/ai_runtime_controller.gd`;
- one new narrow AI v0.6 card-action port/adapter under `scripts/runtime/` if dependency injection is required;
- one new focused AI bootstrap test and B handoff/report.

Required cross-owner wiring, not for B to edit unilaterally:

- Agent A/Coordinator owner: inject a narrow port exposing only `v06_first_table_facility_market_snapshot`, `purchase_v06_first_table_facility_card`, `v06_card_player_snapshot`, and `play_v06_runtime_card`; no new business owner or journal.
- Coordinator acceptance owner: replace the stale Stage 6 `_auto_expand_rival_syndicates` call and change the income counter to an authoritative facility/CommodityFlow check.
- Keep `scripts/main.gd`, CardFlow, CommodityFlow, RegionInfrastructure, UI, and the card catalog frozen for B.

Focused oracle:

- arrange two AI seats whose starter summons are already terminal in the production Monster owner;
- invoke the new forced AI bootstrap once;
- observe one canonical market-purchase transaction and one finalized facility-play transaction in the sole production journal;
- observe the facility in RegionInfrastructure with the AI actor as owner and no direct legacy-city mutation;
- replay the same transaction IDs and prove player, market, facility, and journal snapshots unchanged;
- after the Stage 5 prerequisite, advance isolated time and observe at least one AI-owned Sale Receipt plus positive authoritative GDP/cash delta;
- run one non-forced timer tick to prove normal scheduling uses the same action;
- leave the resolution queue idle and expose no private actor/hand/cash fields in public evidence.

This is sufficient for the current Stage 6 condition because `followup_actions` is already nonzero; legacy `business_actions` can remain deferred while the production facility/income path becomes authoritative.
