# V0.7.5 Lane B Handoff

Status: GREEN

Base: `bd0af5c99c5267cdbe7d66c01034f80db4d704fd`

Branch: `codex/v075-lane-b-monster-source-bd0af5c`

## Delivered

- `V075MonsterSourceCore`: pure, deterministic, fingerprinted source/action/receipt/checkpoint contracts.
- `V075CharacterMonsterCapacityPort`: one base capacity (`1`) plus the typed `monster_control_capacity_modifier`; no role-name, player-index, or UI exception path.
- Four closed, explicit card modes: `DEPLOY_NEW`, `REFRESH_EXISTING`, `UPGRADE_EXISTING`, and `REPLACE_EXISTING`.
- Integer 25/50/75/100 percent refresh, downed recovery, full-heal upgrades, old cooldown preservation, new skill READY state, and withdrawn/no-reward replacement.
- Pure-data checkpoint capture, restore, and rollback with zero in-place mutation.

The card mode is frozen by `prebind_card_mode()`. `resolve_prebound_card()` can only execute that exact mode, card instance, target source/generation, region, and normalized definition snapshot. A changed target can fizzle, but the Core never auto-converts to another mode or retargets another monster.

## Integration Contract

Catalog authoring supplied to `normalize_definition()` needs four rank profiles and exactly four ordered skill IDs. Rank N unlocks the first N IDs. Existing skill-state dictionaries are preserved by ID during upgrade; newly unlocked skills become READY. A downed source first restores each DISABLED skill's saved READY/COOLDOWN state, then upgrades and fully heals.

Capacity changes enter through `apply_character_capacity_semantic()`. If capacity falls below the controlled count, existing active/downed sources remain untouched and further deployment is blocked until count is legal again.

Resolved monster cards report `card_destination=personal_discard` but perform no DBG writes. The integrating Runtime Owner must send that typed destination to the DBG owner.

## Verification

- Focused tests: 8/8 scripts, 55/55 assertions.
- MCP changed-script validation: 11/11.
- MCP Bench scene load: 1/1.
- `V075_MONSTER_SOURCE_CORE_BENCH`: PASS, 14 checks, 0 failures.
- MCP error log: 0 errors.
- MCP stopped normally: `stopped=true`, `port_open=false`.

No owned source references `MonsterRuntimeController`, `MilitaryRuntimeController`, legacy Main, `main.tscn`, or gameplay RNG.

## Workspace Note

The worktree was clean at start. The first Godot editor launch with the compatibility renderer crashed in an engine-level signal 11 during full asset import and generated unrelated `.import/.uid` noise. The stable Role B run used `forward_plus`. None of that unrelated import noise is staged; the coordinator should cherry-pick only the Lane B commit.
