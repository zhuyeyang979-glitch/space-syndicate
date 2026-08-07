# V0.7.5 UI Presentation Audit From Resume

```text
AUDIT_ID=v075.ui.presentation.audit.from.resume.v1
AUDIT_DATE=2026-08-07
TASK_ID=ALPHA_0_5_C2_V075_MONSTER_AUTONOMY_PRIVATE_INSTANT_SKILLS_AND_MILITARY_ASSAULT_MISSIONS_PRODUCTION_CUTOVER
LANE=C
OWNED_FILES=[reports/handoffs/v075_ui_presentation_audit_from_resume.md]
READ_ONLY_DEPENDENCIES=[scripts/ui/v075/v075_monster_private_skill_dock.gd,scripts/ui/v075/v075_military_mission_panel.gd,scripts/ui/v075/v075_combat_player_surface.gd,scripts/ui/v075/v075_sample_game_screen.gd,scripts/v075/player/v075_combat_projection_adapter.gd,current_v075_tests]
EXPECTED_OUTPUT=read_only_ui_audit
CODE_EDIT_COUNT=0
MCP_RUN_COUNT=0
PROHIBITED_SUITES_RUN_BY_THIS_LANE=0
CURRENT_TASK_STATUS_INHERITED=PARTIAL
PRODUCTION_INTEGRATION_SAFE=false
SUCCESSOR_START_AUTHORIZED=false
```

## Scope and preservation

This is a read-only audit of the private monster skill dock, military mission
panel, V0.7.5 combat player surface, production wrapper, projection adapter,
and the current focused UI/projection tests. The only file created by this
lane is this report. No Godot code, scene, resource, shader, test, UID file,
branch, commit, stash, reset, MCP session, or prohibited suite was changed or
started.

The existing V0.7.5 worktree and branch were preserved:

```text
WORKTREE=space-syndicate-v075-monster-military-combat-bd0af5c
BRANCH=codex/v075-monster-military-combat-bd0af5c
HEAD=a4a06b96d39b20a94418c4a1c02c74e6af17b9c6
BASE_MAIN_SHA=bd0af5c99c5267cdbe7d66c01034f80db4d704fd
CURRENT_TASK_NO_RESET=true
CURRENT_TASK_NEW_USER_FILES_PRESERVED=true
```

The current-task status remains `PARTIAL`; this report does not authorize the
V0.7.6 successor. The existing forward-compatibility audit already records
that the current V0.7.5 military public queue and independent region polygon
renderer must be marked as successor-migration work, not silently promoted to
the V0.7.6 final contract.

## Mode and authority snapshot

```text
CURRENT_MONSTER_SKILL_EXECUTION_MODE=private_instant_serial
CURRENT_MILITARY_EXECUTION_MODE=normal_public_batch
CURRENT_DIRECT_ATTACK_EXECUTION_MODE=not_present_in_v075_ui_or_runtime
CURRENT_REGION_PARTITION_AUTHORITY=V074MapGenesisCore_and_geodesic_microgrid
CURRENT_REGION_RENDERING_MODE=independent_per_region_projected_polygon_fill
CURRENT_REGION_PRESENTATION_GAP_COUNT=unmeasured
CURRENT_REGION_PRESENTATION_OVERLAP_COUNT=unmeasured
```

The monster skill mode matches the frozen V0.7.5 contract. The military mode
also matches the historical V0.7.5 constitution: military cards are ordinary
anonymous public-batch actions (`docs/rules/v075_game_constitution.md:172-196`)
and the UI hard-codes `normal_public_batch` in
`scripts/ui/v075/v075_sample_game_screen.gd:12-17`. That path is therefore a
V0.7.5 behavior fact, not evidence of a private intervention lane. It must be
treated as `superseded_by_v076_direct_intervention` in the successor handoff;
this lane added no new public-queue code.

## Findings

### F1: duplicate outward private-skill submission surface (P0)

The local button-to-surface chain has one connection at each UI layer:

- `v075_monster_private_skill_dock.gd:171-177` connects each generated button
  once.
- `v075_monster_private_skill_dock.gd:398-409` emits one
  `private_target_selection_requested` signal per press.
- `v075_combat_player_surface.gd:64-72` connects the dock once and
  `v075_combat_player_surface.gd:551-560` forwards once.

The production wrapper then exposes two outward intent signals for the same
dictionary. `_issue_combat_intent()` emits the canonical inherited
`application_intent_requested` at
`v075_sample_game_screen.gd:647-676`; the private handler additionally emits
`combat_private_skill_intent_requested` at `:605-620`. The production
bootstrap consumes the first signal at
`scripts/v075_runtime/v075_application_bootstrap.gd:20-34`. The specialized
signal is not currently connected by production composition, but it remains a
second submission-shaped surface with no dedupe contract. The military handler
has the same pattern at `:623-645`.

Therefore the evidence is:

```text
ONE_BUTTON_TO_DOCK_EMISSION=true
ONE_DOCK_TO_SURFACE_FORWARD=true
CURRENT_PRODUCTION_SUBMIT_CONSUMER_COUNT=1
DUPLICATE_OUTBOUND_INTENT_SURFACE=true
RUNTIME_DOUBLE_SUBMIT_OBSERVED_BY_THIS_AUDIT=false
UI_EXACT_ONCE_PROVEN=false
```

The current wrapper test only listens to `application_intent_requested` and
manually emits the surface signal (`tests/v075_sample_game_screen_wrapper_test.gd:109-143`).
It does not connect both outward signals or press a real skill button, so it
cannot detect a future second consumer or a duplicate submission.

Proposed fix:

1. Make one typed `V075MonsterPrivateSkillRequestV1` the only value submitted
   through `application_intent_requested`.
2. Remove the specialized signal, or rename it to an observation/diagnostic
   signal that is emitted after the canonical submission and is forbidden from
   calling `submit_intent`.
3. Add a UI boundary assertion that a single button activation creates one
   `intent_id`, one application-flow submission, and one runtime request. Test
   both signal connection counts and an actual button press.
4. Apply the same single-route rule to military selection so the later direct
   lane cannot inherit two UI submission paths.

### F2: target contract is displayed and submitted as the wrong shape (P0)

The production authoring contract is a dictionary, not the short display
string used by the UI. For example,
`data/v075/v075_combat_active_catalog.json:59,73,87,101` uses
`{"target_kind":"enemy_public_facility"}` or
`{"target_kind":"enemy_facilities_in_public_region"}`. The core requires a
dictionary with a stable `target_kind` at
`scripts/v075/monster/v075_monster_private_skill_core.gd:2752-2757`.

The projection adapter preserves that dictionary in the owner projection
(`scripts/v075/player/v075_combat_projection_adapter.gd:25-35,252-270`), but
the dock repeatedly coerces it to a string:
`v075_monster_private_skill_dock.gd:175-176,228-232,316-324`. A real catalog
contract consequently does not match `TARGET_LABELS` and renders the generic
fallback `指定目标`; the emitted signal carries only that string and no target
identity (`:398-409`). The bench's abbreviated string fixtures hide this
problem (`scripts/tools/v075/v075_combat_player_surface_bench.gd:191-245`).

The wrapper passes only `target_contract` and execution mode into the intent
(`v075_sample_game_screen.gd:605-612`). It does not pass a facility ID,
region ID, monster source ID, or generation. Runtime target resolution accepts
those explicit fields at `scripts/v075_runtime/v075_runtime_owner.gd:3654-3693`,
but falls back to tracked/first public targets when they are absent. That is
not a UI target selection or a prebound target.

There is also a latent region/facility collision in the fallback API:
`v075_runtime_owner.gd:3654-3659` gives `target_facility_id` precedence over
`target_region_id` without first constraining the field by the authored
`target_kind`. A facility ID can therefore be treated as a region ID if a
caller supplies the wrong field. Facility damage itself requires an exact
`target_facility_id` (`scripts/v075/combat/facility_combat_damage_intent_v1.gd:13-23,78-90`).

Proposed fix:

1. Normalize the private projection to expose `target_kind` as a display-safe
   scalar while retaining the full contract only in the owner-private DTO.
2. Add owner-only legal target options with stable identity and generation.
   The binding must use exactly one of:
   `target_facility_id`, `target_region_id`,
   `target_monster_source_instance_id`, or the source ID for `self_source`.
3. Change the UI signal to carry a typed `target_binding` dictionary (or an
   immutable option ID resolved by the owner), not a stringified contract.
4. Make the runtime reject a field whose type does not match the authored
   target kind before reserving assets. Human UI requests must not silently
   fall back to the first facility/region; AI may use the same deterministic
   legal-option resolver explicitly.
5. Add separate tests for a single-facility target and a region-budget target,
   asserting that a facility ID can never appear in `target_region_id` and that
   the exact selected ID/generation reaches the authority.

### F3: military buttons lose card and target identity (P0)

The authoritative runtime creates fully prebound military options. Each option
has `option_id`, `card_instance_id`, `target_slot_id`, `task_kind`, and either
`target_region_id` or `target_monster_source_instance_id`
(`scripts/v075_runtime/v075_runtime_owner.gd:2428-2456`). The exact queue
lookup can validate all of those fields (`:2459-2485`).

The player projection discards that identity. Its military DTO contains only
`task_kind`, display text, icon key, and a boolean `enabled`
(`scripts/v075/player/v075_combat_projection_adapter.gd:289-328`). The panel
stores only those filtered rows and emits only `mission_selected(task_kind)`
(`scripts/ui/v075/v075_military_mission_panel.gd:4,49-61,116-126`). The wrapper
then submits only `task_kind` and `execution_mode`
(`scripts/ui/v075/v075_sample_game_screen.gd:623-640`).

This makes a button task-level rather than option-level. If the card instance
or target is absent, `queue_selected_military_mission()` may choose the first
military card found in the hand (`scripts/v075_runtime/v075_runtime_owner.gd:1126-1146`),
which defeats prebinding and can select a different card or target than the
player intended. Separately, the panel enables a task whenever any supplied
row says `enabled=true` (`v075_military_mission_panel.gd:91-103`); it does not
require a complete card/target identity. A malformed or stale row can thus
produce an apparently enabled control with no actionable identity.

Proposed fix:

1. Preserve the authoritative option DTO through the player projection:
   `option_id`, card instance/definition and generation, target slot, task
   kind, target ID/generation, launch binding, `enabled`, and a stable disabled
   reason.
2. Have the panel emit the selected option ID or full detached option, never
   only `task_kind`. If multiple cards/targets share a task kind, render a
   target/card choice rather than collapsing them into one button.
3. Enable a control only when the exact option is complete and still legal;
   missing identity must fail closed and must not call the runtime fallback.
4. Keep the two visible task kinds exactly as they are. Do not add Guard,
   Protect, a military skill dock, or a public-queue-specific animation surface.
5. Add a test that injects an `enabled=true` option without IDs and proves the
   control remains disabled and emits no intent; add a stale-generation test
   proving no retargeting.

For the current frozen V0.7.5 task, the selected option still enters the
ordinary public batch. The UI should obtain that mode from a typed capability,
not hard-code it in a way that blocks the successor's
`pending_v076_private_direct_intervention` migration.

### F4: normal rival filtering passes, but the UI boundary is not fail-closed (P1)

The normal projection path is good evidence:

- `V075CombatProjectionAdapter._project_owner_skill_sources()` selects only
  the viewer's own private zone (`:225-286`).
- `public_projection()` removes private skill and military options
  (`:132-139`).
- `tests/v075_combat_public_private_projection_test.gd:21-115` checks that a
  rival receives no skill cards or military command choices and that public
  fields omit costs, cooldowns, skill IDs, and future skill targets.
- The UI integration test checks the owner/rival dock visibility and public
  cue stripping (`tests/v075_ui_runtime_presentation_binding_integration_test.gd:279-356,362-425`).

However, the production surface enables the military panel with
`not viewer_id.is_empty()` rather than an owner authorization result
(`scripts/ui/v075/v075_combat_player_surface.gd:332-370`). The panel itself
accepts a caller-provided boolean and has no owner identity or capability
check (`v075_military_mission_panel.gd:17-20,49-61`). A rival projection with
injected military rows would therefore display/enable controls, even though a
normal adapter-generated rival projection happens to be empty. There is no
test for this hostile or stale DTO boundary.

The public V0.7.5 contract intentionally exposes the monster's preferred
color, tracked facility, and projected path (`docs/rules/v075_game_constitution.md:166-170`);
those fields are not counted as private skill-card leakage here. They must
remain distinct from an owner's pending skill target, which must never enter a
public projection or public presentation receipt.

Proposed fix:

1. Make private-surface visibility fail closed: require an owner-bound
   capability or an explicit `viewer_player_id == owner_player_id` check for
   both skill and military surfaces. A nonempty viewer ID alone is not enough.
2. Keep military option rows out of all public projections and reject rows
   whose owner/capability does not match before rendering.
3. Add a rival test that injects private skill fields, military rows, pending
   targets, costs, and cooldowns into the incoming DTO and asserts zero visible
   cards, zero enabled private controls, and zero emitted intents.

### F5: child-layout and asset-reserve overlap are not proven (P1)

The outer combat layout test checks panel bounds and planet occlusion, but not
the actual child rectangles (`tests/v075_ui_runtime_presentation_binding_integration_test.gd:147-216`).
The surface test checks only the column count when wide/compact
(`tests/v075_combat_public_private_projection_test.gd:144-177`). It does not
measure child intersections, clipping, text containment, or the real asset
reserve lane.

There is a deterministic minimum-width warning in the scene sizes:

```text
private skill dock minimum width = 340
military panel minimum width     = 320
grid horizontal separation      = 8
two-column child minimum        = 668 (before outer margins)
surface root minimum width      = 640
combat panel maximum width      = 660
```

`V075CombatPlayerSurface.tscn:7-8,154-169` requests two columns at the wide
breakpoint, while the two child minimum widths cannot fit inside the nominal
surface/panel width after margins. This is a potential overflow/clipping or
neighbor overlap, not a proven pixel count; `PRESENTATION_GAP_COUNT` and
`PRESENTATION_OVERLAP_COUNT` remain unmeasured. The skill cards' horizontal
scroll overflow is intentional and must be distinguished from overflow out of
the scroll container.

The current UI has no asset reservation control or live reserved/unreserved
Pip projection. `track_and_asset_surfaces_untouched=true` in the layout DTO is
an assertion flag, not a rectangle audit. Consequently the required
`reserve-lane overlap` evidence is absent.

Proposed fix:

1. Make the column decision from measured available inner width: use two
   columns only when the two child minimum widths plus margins fit; otherwise
   stack one column. Do not use a viewport-only breakpoint.
2. Add a read-only geometry audit that instantiates the real scene and checks
   every visible child global rect at 480, 640, 660, 900, 1366, 1600, and
   1920-wide layouts. Assert no unintended pairwise intersection, no parent
   overflow, no clipped labels, and stable scroll-container containment.
3. Add a separate reserve-lane test with a real owner asset projection and a
   pending public reservation. Assert the Pip/reserve indicator does not
   overlap skill costs, military controls, or the shared track, and that the
   UI remains read-only.
4. Capture owner and rival production frames after the geometry gate; no mock
   surface or bench-only screenshot is sufficient for the cutover claim.

## Integration decision

```text
PRIVATE_SKILL_UI_INTEGRATION_SAFE=false
MILITARY_UI_INTEGRATION_SAFE=false
RIVAL_PRIVACY_NORMAL_PROJECTION_GREEN=true
RIVAL_PRIVACY_FAIL_CLOSED_GREEN=false
NO_GUARD_UI_GREEN=true
NO_BOUND_ACTION_UI_GREEN=true
PRIVATE_SKILL_SINGLE_SUBMISSION_PROVEN=false
PRIVATE_SKILL_TARGET_BINDING_GREEN=false
MILITARY_OPTION_IDENTITY_GREEN=false
UI_CHILD_OVERLAP_GREEN=false
ASSET_RESERVE_LANE_OVERLAP_PROVEN=false
PRODUCTION_CUTOVER_SAFE=false
```

The existing Lane F component/bench evidence is useful but explicitly does
not claim production cutover or a full main-scene acceptance. Integration is
safe only after F1-F3 are corrected, F4 is made fail-closed, and F5 is proven
with the real production scene. Until then, keep this report as a blocker
handoff and do not mark the V0.7.5 UI domain GREEN.

## Required follow-up evidence

```text
v075_ui_private_skill_single_submission_test=required
v075_ui_private_skill_target_binding_test=required
v075_ui_military_option_identity_test=required
v075_ui_rival_fail_closed_test=required
v075_ui_child_rect_collision_test=required
v075_ui_reserve_lane_overlap_test=required
MCP_PRODUCTION_MAIN_TSCN_UI_ACCEPTANCE=required_after_fixes
CURRENT_TASK_STATUS=PARTIAL
SUCCESSOR_START=FORBIDDEN_UNTIL_STAGE_A_GREEN_MERGED_TAGGED_AND_SYNCED
```

```text
STAGE_A_UI_HANDOFF_STATUS=BLOCKED_FOR_INTEGRATION
SUPERSEDES_NO_EXISTING_PROGRESS=true
MILITARY_PUBLIC_QUEUE_NEW_CODE_BY_THIS_LANE=0
DIRECT_ATTACK_PUBLIC_QUEUE_NEW_CODE_BY_THIS_LANE=0
INDEPENDENT_REGION_POLYGON_INFLATION_BY_THIS_LANE=0
SUPERSEDED_BY_V076_DIRECT_INTERVENTION=true
SUPERSEDED_BY_V076_EXACT_PARTITION=true
```
