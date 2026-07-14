# v0.6 Organization Card Catalog Handoff

## Status

The data-only organization catalog is complete and frozen at focused-test scope.

- Godot: `4.7.stable.official.5b4e0cb0f`
- Catalog builder: `348` cards, `87` families, organization `20`, validation `errors=[]`
- Existing catalog gate: `PASS | checks=2894 | failures=0`
- Organization + global monster reinforcement gate: `PASS | checks=1613 | failures=0`
- Generated JSON SHA-256 on two consecutive isolated builds: `B59B73489D23578558D4A7688A03F50A3EF4D776CF528CD9EAFD0E1D2A0FCB40`
- Runtime wiring, full smoke, MCP, headed playtest, default `user://`, commit, push, and merge: not run

## Files Owned In This Task

- `scripts/tools/card_runtime_catalog_v06_builder.gd`
- `scripts/cards/card_runtime_catalog_v06_resource.gd`
- `resources/cards/runtime/card_runtime_catalog_v06.tres`
- `data/cards/card_runtime_catalog_v06.json` (builder-generated only)
- `tests/card_runtime_catalog_v06_test.gd`
- `tests/organization_card_catalog_v06_test.gd`
- `docs/organization_card_catalog_v06.md`
- this handoff

No `main.gd`, runtime business owner, PlayerMana, queue/UI scene, card window, ruleset validator, AI, Coordinator, rulebook, or other agent hot file was changed.

## Organization Category Contract

All twenty cards use:

```text
category_id=organization
effect_kind=install_organization_upgrade
target_kind=self_organization_slot
organization_slot_cost=1
organization_slot_limit=3
install_policy=upgrade_highest_rank_only
stack_policy=highest_rank_nonstacking
activation_window_offset=1
activation_snapshot_timing=next_window_start
persistence=run
direct_player_interaction=false
counterable=false
phase_veto_eligible=false
ordinary_submission_cost=1
counts_as_normal_card_submission=true
```

The card is in the ordinary hand before installation, consumes one ordinary submission, activates from the next shared window, and persists for the run. Same-family ranks do not stack; only a strictly higher rank replaces the current install, and equal/lower ranks reject before consumption. Organization cards expose public installation aura clues but are self-upgrades, not direct-player interaction, so Phase Veto does not apply.

Every payload also exposes `required_own_gdp_min`, `required_positive_gdp_color_count`, `counterplay_tags`, `anti_snowball_cap`, and `ai_effect_tags`. Player keywords include `组织 / 常驻 / 次窗生效` plus the family axis.

## Five I-IV Families

| Family ID | Player name | Axis | Rank ladder |
|---|---|---|---|
| `organization.starport_clearinghouse` | 星港清算所 | `asset_conversion` | same-color conversion +500/1000/1500/2000 bp, capped +50/100/150/200 milli-assets/s |
| `organization.quantum_agenda_network` | 量子议程网 | `action_bandwidth` | +1 ordinary submission, surcharge 4/3/2/1; hard cap 3; rank IV adds a paid every-third-window burst |
| `organization.deep_space_archive` | 深空档案库 | `hand_capacity` | ordinary hand limit 6/7/8/9, absolute cap 9 |
| `organization.monster_liaison_charter` | 巨兽联络章程 | `monster_binding` | 1×III, 1×IV, IV+II, 2×IV |
| `organization.stellar_command_directorate` | 星环统帅部 | `military_command` | 1×III, 1×IV, IV+II, 2×IV |

Exact cash, asset, GDP, color, cap, and control ladders are in `docs/organization_card_catalog_v06.md` and exhaustively asserted in the focused test.

The runtime field name for hand capacity is `ordinary_hand_limit`, not `effective_hand_limit`. Runtime consumers must use the final catalog field rather than introducing an alias.

## Global Same-Name Monster Reinforcement

All 32 monster ranks now target `region_or_existing_same_family_monster` and expose:

```text
upgrade_target_same_family_any_owner=true
ownership_transfer_on_upgrade=false
bound_skill_recipient=existing_monster_owner
starter_conflict_policy=private_reselect
upgrade_respects_target_owner_rank_cap=true
```

The retired `upgrade_target_owned_same_family` field is no longer generated. Player copy says that a same-name card may reinforce the monster already on the board without changing ownership; bound skills remain with that monster's current owner. Starter conflicts privately reselect. This task does not claim Monster runtime already enforces the new contract.

## Metadata And Release Truth

- Named catalog: `87` families / `348` ranked cards.
- Organization: `5` families / `20` ranked cards.
- Future balanced target: `107` families / `428` ranked cards, preserving the existing twenty-family commodity expansion reserve.
- `organization_installation_runtime_wiring_pending` remains an explicit release blocker.
- Each organization record keeps `implementation_status=catalog_ready_runtime_wiring_pending` and `runtime_owner=organization_runtime_owner_pending`; no production ownership is falsely claimed.

## Verification Commands

All commands used isolated temporary `APPDATA` and `LOCALAPPDATA`:

```powershell
godot --headless --path . --quit-after 2 res://scenes/tools/CardRuntimeCatalogV06Builder.tscn
godot --headless --path . --script res://tests/card_runtime_catalog_v06_test.gd
godot --headless --path . --script res://tests/organization_card_catalog_v06_test.gd
git diff --check
```

## Known Integration Dependency

`tests/asset_terminology_v06_test.gd` still hard-codes `328` outside this task's allowed file boundary. It must be changed to `348` by its owner before broad regression. Historical development-log and validation-report counts describe the earlier seed and were not rewritten as if their old evidence had covered the new cards.

## Lessons For Other Agents

- **Invariant:** an organization is a self-only persistent install; it is never routed through the direct-player-interaction or Phase Veto owner.
- **Failed approach:** increasing hand/unit/action limits without a shared slot limit and per-axis hard cap creates an unbounded snowball engine.
- **Stable API:** consume `effect_kind=install_organization_upgrade`, `target_kind=self_organization_slot`, and the exact payload keys above; do not infer behavior from Chinese names.
- **Test oracle:** exactly five complete I-IV ladders, twenty organization cards, three shared slots, next-window activation, and zero owner-only monster-upgrade fields.
- **Integration trap:** an action-bandwidth install resolved mid-window must not alter that same window; legality uses the window-start snapshot.
- **Reusable pattern:** ordinary-hand card → one normal submission → owner prepare/commit → next-window snapshot → run-persistent highest-rank projection.
- **Stale evidence:** a catalog record marked `rule_confirmed` proves field semantics only; it does not prove the production owner, save/load, replay, or UI is connected.
- **Next dependency:** the organization owner must atomically install/replace/save these upgrades, and Monster runtime must enforce global unique-family reinforcement while respecting the target owner's charter.
