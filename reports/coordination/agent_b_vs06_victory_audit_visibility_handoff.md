# Agent B Handoff — VS06-B8 Victory Audit Visibility Owner

Date: 2026-07-15 (JST)  
Status: frozen; ready for coordinator integration validation  
MCP lease: released

## Outcome

`VictoryControlRuntimeController` remains the sole victory-state owner and now also owns the narrow public exact-cash authorization. It derives authorization only from its stable internal audit roster while state is `audit` or `resolved`, and only after every roster seat is bound to a fresh authoritative candidate snapshot.

The public contract is:

- authorized envelope: `cash_visibility="public_audit"` plus sorted unique `audit_revealed_player_indices`;
- authorized audit/rank row: integer `player_index`, `cash_visibility="public_audit"`, integer `cash_ledger_cents`;
- no authorization envelope and no exact cash before audit, for special winners without an audit roster, for invalid/stale rosters, or immediately after load before fresh world facts;
- available cash, escrow, hands, inventory, ownership truth and AI-private fields remain excluded recursively.

No victory formula, comparison order, countdown, Top-K rule, cash owner, settlement adapter/service, Coordinator or `main.gd` behavior was changed.

## Modified files

- `scripts/runtime/victory_control_runtime_controller.gd`
- `scenes/runtime/VictoryControlRuntimeController.tscn`
- `scripts/tools/victory_control_runtime_bench.gd` (updated stale audit-disclosure oracle)
- `tests/victory_control_public_projection_privacy_v06_test.gd`
- `scripts/tools/victory_audit_visibility_v06_bench.gd`
- `scenes/tools/VictoryAuditVisibilityV06Bench.tscn`
- `docs/victory_control_runtime_contract.md`
- this handoff

`victory_control_runtime_world_bridge.gd/.tscn` required no change: the bridge still supplies private authoritative world facts but does not decide visibility.

## Public APIs and state behavior

- `public_snapshot(viewer_index=-1)` emits the explicit public-audit envelope only when the owner roster and fresh candidate facts validate.
- `private_snapshot(viewer_index)` retains viewer-scoped exact assets; the public subsection follows the same audit allowlist.
- `outcome_receipt()` remains the exact internal receipt. `public_snapshot().outcome_receipt` is rebuilt and selectively adds exact cash only for owner-authorized audit seats.
- `to_save_data()` format stays schema 2.
- `apply_save_data(data)` now validates the complete envelope before one swap. It clears world-derived candidates/assets/rule/checkpoint/pause caches so a previous game cannot authorize cash after load. `advance_world_effective(0, fresh_world)` is sufficient to refresh authoritative facts without consuming countdown time.
- `debug_snapshot()` declares `owns_public_audit_roster`, `owns_public_audit_cash_authorization`, and `audit_cash_requires_fresh_world_facts`.

## Focused evidence

Command (isolated APPDATA/LOCALAPPDATA):

`Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/victory_control_public_projection_privacy_v06_test.gd`

Result: `PASS`, 47 checks, 0 failures. Covers pre-audit hiding, partial roster disclosure, non-roster hiding, repeated projection stability, caller forgery isolation, normal finalized audit, special winner non-bypass, internal receipt preservation, recursive privacy, save/load stale-cache closure and invalid duplicate-roster zero mutation.

## Godot MCP evidence

- `get_godot_version`: `4.7.stable.official.5b4e0cb0f`
- `get_project_info`: project `space-syndicate-sync`
- launched the real editor through MCP;
- ran `res://scenes/tools/VictoryAuditVisibilityV06Bench.tscn`;
- scene tree: `VictoryAuditVisibilityV06Bench` -> instantiated production `VictoryControlRuntimeController` from `res://scenes/runtime/VictoryControlRuntimeController.tscn`;
- bench result: `PASS`, 11 checks, owner `victory_control_v06`, state `audit`, authorized roster `[0]`;
- `get_debug_output`: `errors=[]`;
- `stop_project`: `finalErrors=[]`.

The first MCP run exposed a Bench-only mixed-type sentinel comparison. The project was stopped normally, the oracle was corrected to compare equal Variant types only, and the same real scene was rerun successfully. No production fallback was added.

## Known risks / coordinator checks

- The final-settlement adapter/service were intentionally not changed. Coordinator should run their existing focused integration suite to confirm they consume the new owner envelope end-to-end.
- Save envelope validation is stricter than the prior permissive loader. Corrupt or structurally incomplete schema-2 Victory payloads now fail closed instead of being normalized.
- A resolved special outcome with an empty audit roster intentionally stays cash-hidden even when cash selected the winner.

Suggested coordinator validation:

- existing Victory runtime suite/Bench;
- FinalSettlement public source adapter and snapshot service focused tests;
- isolated save/load and real settlement composition test.

## Lessons for other agents

- **Invariant:** visibility authorization must be owned by the domain that owns the authoritative roster; neither winner state nor possession of a private value grants publication rights.
- **Failed approach:** recursively stripping every `cash_ledger_cents` key was stale after the product rule changed; field-level allowlisting tied to a stable roster is required.
- **Stable API:** consumers should read only top-level `cash_visibility`, `audit_revealed_player_indices`, and authorized row-level `cash_ledger_cents`; do not inspect private snapshots.
- **Test oracle:** a recursive leak scanner plus distinct authorized/hidden cash sentinels proves both positive disclosure and negative privacy behavior.
- **Integration trap:** restoring roster state while retaining pre-load candidate caches can disclose a previous game’s cash. Clear derived facts and require a fresh owner snapshot.
- **Reusable pattern:** validate the full save envelope, construct next state in locals, then swap once; invalid data leaves before/after identical.
- **Stale evidence:** old Victory Bench wording expected an `economic_assets` public envelope and treated all exact cash as forbidden. That oracle was replaced; private assets remain forbidden.
- **Next dependency:** Coordinator/FinalSettlement integration must consume the owner envelope without introducing a second visibility policy or inferring authorization from `game_over`, rank, winner or cash presence.
