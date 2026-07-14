# Tomorrow Vertical Slice — Coordinator Red/Green Board

Updated: 2026-07-14 22:28 JST. This board records authoritative evidence, not intended behavior.

| Required player path | Current evidence | Status | Next proof |
|---|---|---:|---|
| Godot 4.7 launches `scenes/main.tscn` | Project parse/load passed; the isolated vertical slice instantiated the real production main scene | Green | Repeat after the recursion fix |
| Main menu opens new-match setup | Isolated vertical-slice stage `main_menu_new_run_setup` passed | Green | Headed click-through |
| One human + two AI enter the table | Isolated stage `new_match_one_human_two_ai` passed against real seat creation and post-seat v0.6 binding | Green | Headed click-through |
| Human performs starter-monster first summon | Real command reaches Coordinator and Monster owner, then loops through `main rule snapshot -> private snapshot -> WorldBridge -> main` until stack overflow | Red | B adds a world-independent starter-state snapshot; A consumes it in main; rerun full slice |
| Human creates one city/facility | Rank-I catalog, CardFlow, RegionInfrastructure and facility production gates pass independently; full stage is presently downstream of the first-summon stack corruption | Yellow | Rerun repaired full slice and require cash -4, assets unchanged, one facility, replay exact-once |
| Realtime city/GDP income changes state | Commodity/core production tests pass independently; full stage currently fails after the stack overflow | Yellow | Rerun after P0 recursion closure |
| Human inspects regional supply and buys one card | Production facade is wired and the repaired Gate now uses the canonical v0.6 market instead of `_claim_district_card` | Yellow | Full stage pass plus headed drawer interaction |
| Human plays one legal card | Core CardFlow integration passes `65/65`; full production stage is not yet green | Yellow | Full stage pass and headed card play |
| Two AI seats continue acting | AI reaches the same starter summon path and reproduces the same recursion, proving the shared entry but blocking progress | Red | Rerun after B/A snapshot fix; then classify the next AI failure |
| Victory countdown reaches settlement/recap | Controller exists, but current full stage is a downstream failure and is not valid evidence | Red | Full slice must reach victory and visible recap without prior corruption |
| Hidden information remains private | Privacy stage was reached after engine stack corruption, so its failure is not independently actionable | Yellow | Rerun clean process, then recursive player-facing leak scan |
| Save/test data is isolated | Full run used isolated `APPDATA`/`LOCALAPPDATA`; QA save stage passed and default player data was untouched | Green | Preserve isolation in all later runs |
| Headed human flow works at 1600x960 | Not run for this slice | Red | One second-monitor click-through and screenshots |

## Current first actionable blocker

The isolated full run exited `9` with a reproducible stack overflow. The cycle is:

```text
main.monster_deploy_rule_snapshot_v06
  -> MonsterRuntimeController.monster_private_snapshot_v06
  -> MonsterRuntimeController._monster_card_rule_snapshot_v06
  -> MonsterRuntimeWorldBridge.monster_deploy_rule_snapshot_v06
  -> main.monster_deploy_rule_snapshot_v06
```

Agent B owns the pure Monster starter-state snapshot; Agent A owns the single main call-site cutover. Later stage failures remain unclassified until this first corruption is removed.

Central focused evidence before the full run: catalog `2806/2806`, CardFlow policy `37/37`, transaction `69/69`, core adapters `34/34`, production economy `65/65`, RegionInfrastructure `70/70`, facility unlock `64/64`, Monster lifecycle `51/51`. The legacy `main_runtime_composition_test` separately exposed 22 stale owner assertions and is being migrated without restoring retired owners.

## Centralized validation sequence

The coordinator, not each Agent, will execute this sequence after all hot files parse:

1. Godot 4.7 project parse/load.
2. Changed-owner focused tests: facility, monster first summon, production composition.
3. `tomorrow_playable_vertical_slice_test.gd` with isolated save state.
4. Player-facing privacy/leak gate.
5. Existing check-only smoke or the smallest full regression required by the actual changed owners.
6. Second-monitor headed path at 1600x960 and final screenshots.

Long duplicate logs are not copied into Agent handoffs. Only command, result, first actionable failure, and artifact path are retained.

## Evidence-backed deletion status

- Removed after zero-reference/replacement proof: `scenes/runtime/CommodityCardInventoryWorldBridge.tscn`. Production uses `CardPlayerStateProductionAdapterV06`, and the focused gate explicitly requires the old bridge to be absent.
- Do not yet delete legacy GameScreen/LayoutDemo, CityDevelopment, CityTradeNetwork, GDP/Economy shells, IndustryCapacity, save handshake, or FirstTable compatibility helpers. They still have production/test consumers or their replacement production dispatch is incomplete.
