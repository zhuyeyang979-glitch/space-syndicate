# P1 Full-run typed rack driver validation (`c986e5a`)

Date: 2026-07-22 (Asia/Tokyo)

## Verdict

PASS for the requested regional-rack driver boundary. The fixed-seed scripted
player now uses the production four-seat composition and the same presentation
chain as a human:

1. `SpaceSyndicateGameScreen.request_district_selection` emits a typed
   `TableSelectionIntent`;
2. `request_district_supply_open` emits a typed `DistrictSupplyActionIntent`;
3. the formal `DistrictSupplyViewerQueryPort.snapshot_for_viewer` supplies the
   same viewer-authorized rack snapshot rendered by the Drawer;
4. the Drawer quote action enters GameScreen's normal signal handler, which
   constructs the typed quote intent;
5. `request_selected_district_supply_purchase` submits the locked quote through
   the typed purchase intent;
6. accepted `DistrictSupplyActionReceipt` values, not UI text or guessed state,
   establish the rack/quote/purchase milestones.

The driver does not call a private Main method, submit directly to an owner,
write cash/hand/rack state, inspect future supply order, or add a QA gameplay
owner. No production file changed.

## Fresh audit findings

The previous report was not treated as current evidence. On fresh
`origin/main` (`c986e5a`) the production typed query/action ports and public
GameScreen select/open/purchase methods exist. No production API integration
request is required.

The inherited driver still read the Drawer's `debug_snapshot`, emitted the raw
PlanetMap `district_selected` signal, and treated purchase like any raw Drawer
action. This made the boundary less trustworthy than the production types now
available. Those three paths were replaced by the formal viewer query and
typed GameScreen requests. Quote remains on the real Drawer signal because that
is the actual human entrypoint; GameScreen immediately converts it to a typed
intent.

## Deterministic run

Seed index: `0`

Seed: `900626424`

Formal 180-second bounded run arguments:

`--seed-index=0 --observation-seconds=180 --max-wall-seconds=210`

Result:

- `time_to_first_rack`: `0.380 s`
- `time_to_first_quote`: `21.805 s`
- `time_to_first_purchase`: `22.129 s`
- actions attempted/progressed: `26 / 26`
- invalid actions: `0`
- typed receipt rejection: `0`
- non-finite public facts: `0`
- first accepted purchase: real locked-quote commit through GameScreen and
  `DistrictSupplyActionPort`

A separate 60-second isolated seed-0 run reproduced the same first chain and
phase order:

- `time_to_first_rack`: `0.373 s`
- `time_to_first_quote`: `21.837 s`
- `time_to_first_purchase`: `22.155 s`
- actions attempted/progressed: `17 / 17`
- invalid actions: `0`

Wall time is scheduling-sensitive; the seed, first rack/quote/purchase order,
accepted receipt kinds, visible listing path, and zero-invalid result reproduced.

## Activated Alpha content rerun

After the Alpha 0.1 runtime manifest was merged, the same bounded seed-0 run
was repeated on integration head `07c104c87ff6effec711ce9fe26748f8366550c4`.
The selected 28-card regional pool was active and exposed several real Rank-I
factory and market listings, so the earlier uncurated-pool hypothesis is now
closed.

- `time_to_first_rack`: `0.382 s`
- `time_to_first_quote`: `22.105 s`
- `time_to_first_purchase`: `22.434 s`
- actions attempted/progressed: `26 / 26`
- invalid actions: `0`
- typed receipt rejection: `0`
- non-finite public facts: `0`
- terminal status: `incomplete`
- terminal reason: `observation_window_elapsed_before_settlement`
- world time observed: `49.725 s`
- owned facilities: `0`
- controlled regions: `0`
- top-three GDP/min: `0 / 108`

## First real failure

The regional rack, quote, and purchase path is not the blocker. The first
purchase is accepted through the production typed receipt, and the following
public hand projection briefly reports `play.hand.hand_0.` instead of a
playable `facility_v06` surface. The driver therefore cannot select the bought
facility through the same player-facing hand action used by a human and
continues rotating racks. No facility is installed and no GDP receipt can be
produced.

This is the first real Alpha P0/P1 boundary to repair. The fix must preserve the
existing private-viewer authorization and make the purchased card's stable
catalog identity, facility kind, eligibility, and typed play action survive the
private hand projection. It must not add a QA-only play path or submit directly
to a gameplay owner.

## Verification

- `full_run_quality_driver_contract_test.gd`: PASS, `93/93`
- `full_run_observation_window_policy_test.gd`: PASS, `8/8`
- `full_run_facility_acquisition_policy_test.gd`: PASS, `12/12`
- `district_supply_surface_query_cutover_test.gd`: PASS, `38/38`
- `district_supply_action_port_cutover_test.gd`: PASS, `55/55`
- `main_runtime_composition_test.gd`: PASS
- `smoke_test.gd --check-only`: PASS, exit `0`
- formal Driver run: Godot `4.7.stable`, isolated APPDATA/LOCALAPPDATA, no
  default `user://` access
- independent Godot MCP scene run: `res://scenes/main.tscn` started and stopped
  successfully under Godot `4.7.stable`; no script/runtime error was reported
  for this change (only existing repository warnings and Unicode NUL warnings)

Known unrelated baseline signals were not repaired here:

- `player_facing_privacy_boundary_test.gd` calls retired Main setup method
  `_open_new_game_setup_menu` and stalls; this is existing P4 test debt.
- `card_market_public_quote_player_privacy_test.gd` currently fails two
  baseline assertions. The Driver's own public-output privacy contract and the
  district-supply query/action privacy gates pass.
