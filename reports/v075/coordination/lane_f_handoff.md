# V0.7.5 Lane F Handoff

Status: GREEN_FOR_COORDINATOR_INTEGRATION

Lane F delivers DTO/dictionary-driven Combat AI, public/private player projection, new owner-only skill and military UI, receipt-driven presentation, telemetry allowlisting, and a real responsive Bench. It does not connect production hot files; the main Agent remains the sole writer for runtime composition and main.tscn.

## Ownership

- Owned: the user-assigned new Lane F directories, four focused tests, Bench pair, and these two handoff files.
- Read-only: V0.7.4 UI/runtime, commercial asset catalog, dynamic map/facility/asset/DBG public facts, old combat controllers, and all other Lane files.
- Hot files changed: 0.
- Existing V0.7.4/runtime files changed: 0.
- Push/new branch/new worktree: none.

## Delivered Contracts

V075CombatAIAdapter deterministically emits all four prebound monster-card modes, one owner-private instant-skill request, and only assault_region / assault_monster. It reads owner-private plus public facts, rejects opponent skill/cooldown/target variants and private warehouse inputs, stops at victory_pending and later terminal phases, and performs no RNG.

V075CombatProjectionAdapter exposes public monster identity, rank, HP, armor, preferred color, current/tracked region and facility, projected path, unlocked-skill count, and batch-use state. Only the owner receives skill definitions, costs, target contracts, cooldown details, and request eligibility. A downed source exposes no requestable skill even if an upstream READY state is stale.

The player surface contains a compact owner-only skill dock with READY/COOLDOWN/DISABLED states, repeated six-color cost pips, target type, cooldown, and ultimate marker. Its military panel has exactly 攻击地区 and 攻击怪兽; guard, bound-action, persistent-source, cooldown, and military-skill UI counts are zero. Wide mode uses two columns and compact mode stacks to one.

V075CombatPresentationConsumer turns allowlisted public Combat Receipts into stable-asset-key cues exactly once. Its fingerprint is independent of dictionary insertion order. It strips skill definitions, costs, cooldown details, future targets, and internal ordering; gameplay mutation, RNG draws, and Receipt delay remain zero.

V075CombatTelemetryContract accepts 19 combat event kinds through per-event payload allowlists. It stores no skill definitions/targets/cooldowns, private plans, warehouse stock, owner IDs, card/source instance IDs, or internal instant sequence.

## Verification

Focused tests:

- v075_combat_ai_test.gd: PASS 17/17
- v075_combat_public_private_projection_test.gd: PASS 32/32
- v075_combat_presentation_exact_once_test.gd: PASS 10/10
- v075_terminal_combat_quiescence_test.gd: PASS 7/7

Godot MCP Role A, port 7576, Godot 4.7-stable:

- Changed script validation: 12/12
- Changed scene load: 4/4
- Bench: res://scenes/tools/v075/V075CombatPlayerSurfaceBench.tscn
- Runtime bridge: ready, 120 FPS, 108 runtime nodes observed
- Runtime errors: 0
- Runtime warnings: 0
- Play mode stopped cleanly: true

After generated UID/import noise was removed, one role-local Godot editor relaunch crashed with native signal 11 while rebuilding the commercial-asset import cache. No Lane F scene was running and no MCP script call had started. The immediate second launch recovered, validated the final script with zero diagnostics, and exited with port 7576 released; this is editor cache-rebuild evidence, not a Combat runtime error.

Visual captures were produced through the live runtime bridge, inspected, and hashed before cleanup:

- Owner 1528x917: 9180fa670e18f3e417e776e2825f35d229ae9004fcafcdf7607231d7e806b27e
- Rival 1528x917: 1825d5d625004ef899b3ee03c07416ac36d52799b2bc95ea7e3c269145bcec45
- Rival public Receipt 1528x917: c2678c36d40341a9907409a413f55840653fea222ba7d5d35deca5a546bef14b

The PNGs are intentionally excluded from the atomic commit because the assigned report ownership permits only lane_f_handoff.json/.md. The Bench can reproduce them without fixtures or mock UI.

## Integration Ports

- V075CombatAIAdapter.enumerate_candidates(...) and choose_action(...)
- V075CombatProjectionAdapter.project_for_viewer(...)
- V075CombatPlayerSurface.apply_projection(...)
- private_target_selection_requested(source_instance_id, skill_definition_id, target_contract)
- military_mission_selected(task_kind)
- V075CombatPresentationConsumer.consume_receipt(...)
- presentation_cue_ready(cue)
- V075CombatTelemetryContract.record_event(...)

The coordinator must bind these adapters to typed Combat Runtime Owner ports, connect the new surface in the production scene, remove the old tactical-support placeholder in its owning hot file, and run the integrated main.tscn MCP sample match. Lane F does not claim production cutover, full-match acceptance, PR/merge, or release tagging.
