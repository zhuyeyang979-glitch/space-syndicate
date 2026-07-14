# Agent B handoff — VS06-B7 organization monster binding

Status: frozen for C15 integration. MCP lease released.

## Result

The sole `MonsterRuntimeController` now consumes a narrow authoritative organization-cap provider for starter summon, ordinary summon, self-upgrade and cross-player same-family reinforcement. Missing or invalid provider facts resolve to the base 1-monster / primary Rank II limit and can never elevate permission.

Stable UID order assigns primary/secondary slots. The exact official gradients are enforced: base 1/II, organization I 1/III, II 1/IV, III 2 with IV+II, IV 2 with IV+IV. Reinforcement always queries the existing monster owner; ownership, control, cash attribution and skill recipient do not change.

Capability compression never deletes or demotes roster entries. Private owner rows derive `suspended_for_new_upgrade`; affected units reject new upgrades and new units cannot exceed current count/rank caps. Restoration is dynamic. Command suspension remains owned by the command runtime.

## Production API for C15

Configure once after authoritative owners/current window are mounted, and configure again after composition/load replacement:

```gdscript
monster_owner.configure_monster_binding_capability_provider_v06(provider)
```

Required provider methods:

```gdscript
current_monster_binding_window_snapshot_v06() -> Dictionary
monster_binding_caps(actor_id, window_sequence) -> Dictionary
monster_binding_caps_for_target_owner(actor_id, window_sequence) -> Dictionary
```

Optional hardening method:

```gdscript
validate_monster_binding_caps_v06(snapshot, for_target_owner) -> Dictionary
```

The delegate must be stateless and read the current window plus `PlayerOrganizationRuntimeController` directly. It must not accept request-supplied owner/window/cap fields or cache organization rows. C15 should not edit the Monster files.

## Files

- `scripts/runtime/monster_runtime_controller.gd`
- `tests/monster_organization_binding_provider_v06_test.gd` and generated `.uid`
- `tests/monster_cross_owner_upgrade_v06_test.gd`
- `tests/monster_deploy_atomic_lifecycle_v06_test.gd`
- `tests/monster_runtime_v06_privacy_test.gd`
- `docs/monster_organization_binding_provider_v06_contract.md`
- `scripts/tools/monster_organization_binding_v06_bench.gd` and generated `.uid`
- `scenes/tools/MonsterOrganizationBindingV06Bench.tscn`
- this handoff

`monster_runtime_world_bridge.gd` was already modified in the shared tree before B7; B7 did not edit it.

## Focused evidence

All console checks used Godot 4.7 and isolated `APPDATA`/`LOCALAPPDATA` paths.

| Check | Result |
|---|---|
| Controller `--check-only` parse | PASS, exit 0 |
| `monster_organization_binding_provider_v06_test.gd` | PASS, 25/25 |
| `monster_cross_owner_upgrade_v06_test.gd` | PASS, 24/24 |
| `monster_deploy_atomic_lifecycle_v06_test.gd` | PASS, 61/61 |
| `monster_runtime_v06_privacy_test.gd` | PASS, 31/31 |
| scoped `git diff --check` | PASS |

The new focused oracle covers missing/bad provider facts, wrong actor/window/kind, stale revision, illegal gradient, validator rejection, forged request cap, all four organization gradients, second-slot rank ceilings, target-owner reinforcement, prepare/commit cap change, dynamic downgrade/restore, save/load re-query and public privacy.

## Godot MCP evidence

- `get_godot_version`: `4.7.stable.official.5b4e0cb0f`.
- `get_project_info`: MCP helper reported an internal `godot --version` command failure; no project mutation occurred. The same project path was then opened and run successfully through MCP.
- `launch_editor`: opened `C:\Users\Administrator\Documents\New project\space-syndicate-sync`.
- `run_project`: `res://scenes/tools/MonsterOrganizationBindingV06Bench.tscn`.
- Scene/runtime proof: `/root/MonsterOrganizationBindingV06Bench/MonsterRuntimeController`; the node is an instance of the production `MonsterRuntimeController.tscn`; `configure_monster_binding_capability_provider_v06` returned configured; public privacy check passed.
- First run exposed two variable-shadow warnings. Both root causes were renamed, then the same MCP scene was rerun.
- Final output: `MONSTER_ORGANIZATION_BINDING_V06_BENCH|status=PASS|...|configure_api=true|public_privacy=true`.
- Final `get_debug_output`: `errors=[]`.
- Final `stop_project`: `finalErrors=[]`.
- MCP lease released.

## Save/privacy boundary

Save data contains no provider object and no external exact count/rank cap row. Pending lifecycle rows retain only the actor/query kind, window/revision and opaque binding fingerprint required for commit revalidation. Load requires provider reconfiguration; until then the base limit applies. Public snapshots expose neither organization identity nor exact cap/signature, hidden owner, opponent state or AI plan.

## Remaining integration/risk

- C15 still must supply the current authoritative window delegate and configure it after mount/load. Until then production intentionally stays at base 1×II.
- `PlayerOrganizationRuntimeController` has no separate monster-cap signature validator. The narrow C15 delegate is therefore a trusted production boundary; it should optionally implement the validator by re-querying the organization owner and comparing actor/window/revision/kind/terms.
- Suspension of monster commands is explicitly not implemented here; the future command owner must consume its own authoritative eligibility facts.
- No `main.gd`, Coordinator, CardFlow, queue, AI, UI, economy, military, organization owner, movement, combat or wager code was changed.

## Lessons for other agents

1. **Invariant:** Monster roster/UID/rank/hidden ownership and organization capability slots must remain in separate unique owners; only revisioned facts cross the port.
2. **Failed approach:** Treating legacy binding-rule cap fields as authority allowed request-adjacent facts to influence legality. They are now ignored for cap elevation.
3. **Stable API:** `configure_monster_binding_capability_provider_v06(provider)` is the only C15 wiring call; the three provider methods above are the stable narrow surface.
4. **Test oracle:** A valid cap is not “numbers in range”; it is actor + current window + owner revision + `monster_caps` kind + one exact official tuple, followed by commit-time re-query.
5. **Integration trap:** Configuring before the current-window source is mounted, or failing to reconfigure after load, silently and correctly yields base 1×II; do not diagnose that as a roster bug.
6. **Reusable pattern:** Store opaque prepare binding evidence, not an external capability copy; re-query at commit and derive downgrade suspension at read time.
7. **Stale evidence:** The privacy test's old `family`/`region` aliases were stale against the frozen `family_id`/`region_index` owner row. The oracle now checks the canonical fields plus the safe derived suspension fields.
8. **Next dependency:** C15 must provide the stateless current-window/organization delegate and run the unified composition/vertical-slice gate; command-owner suspension is a later separate dependency.
