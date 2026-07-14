# Agent B Handoff — VS06-B6 Cross-Owner Monster Upgrade

Date: 2026-07-15  
Status: owner lifecycle and focused evidence complete; production profile/cap providers still need narrow integration.

## Scope completed

- The existing `MonsterRuntimeController` remains the sole roster, UID, selection, owner, and starter-marker authority.
- A starter family collision now returns `starter_monster_family_reserved`, `prepared=false`, `card_consumed=false`, and an actor-private reselect payload. It does not name or identify the player who already reserved that family.
- Once the acting player's starter state is `summoned`, an ordinary same-family monster card targets the single active global monster of that family, including a rival-owned monster.
- Reinforcement preserves UID, slot, `owner_actor_id_v06`, legacy owner index/control, reveal/clue state, and owner-damage cash attribution.
- New rank is `max(current + 1, card rank)`, clamped at IV. Upgrade heals to the authoritative next-rank max HP and adds the catalog duration extension to remaining time instead of resetting elapsed time.
- The target owner's authoritative rule snapshot controls the rank cap. Supported fields are `monster_binding_rank_cap`, `primary_monster_rank_limit`, and `base_primary_monster_rank_limit`. If all are absent, only the base Rank II cap is accepted. Request cap fields are ignored.
- Non-empty bound-skill patches are routed with `bound_skill_recipient_actor_id` set to the current monster owner. The acting player receives no control, binding slot, skill, role-cash patch, or upgrade discount.
- Prepare/commit/rollback/finalize, transaction replay, save/load, and pre/postimage validation reuse the existing owner journal. Save validation rejects duplicate active v0.6 family rows.
- Public snapshot/receipt projection continues to omit actor IDs, true/hidden owner, player index, cash, hands, AI plans, rule fingerprints, and cap provenance.

Normative overlay: `docs/monster_cross_owner_upgrade_v06_contract.md`.

## Files changed in this task

- `scripts/runtime/monster_runtime_controller.gd`
- `scripts/cards/v06/units/monster_card_owner_port_v06.gd`
- `tests/monster_cross_owner_upgrade_v06_test.gd` (new)
- `tests/monster_deploy_atomic_lifecycle_v06_test.gd` (stale catalog/profile assertions updated)
- `tests/monster_card_real_owner_integration_v06_test.gd` (stale capability/catalog assertions updated)
- `tests/monster_runtime_v06_privacy_test.gd` (catalog payload fixture updated)
- `docs/monster_cross_owner_upgrade_v06_contract.md` (new)
- `reports/coordination/agent_b_vs06_cross_owner_monster_upgrade_handoff.md` (new)

`scripts/runtime/monster_runtime_world_bridge.gd` was already modified in the shared tree before VS06-B6 and was not edited by this task. The large aggregate Monster controller diff also contains earlier accepted first-summon work; no earlier or other-agent changes were rolled back.

## Public/narrow API

No second transaction API was added. Production continues to call:

- `monster_runtime_capabilities_v06()` / `unit_card_runtime_capabilities_v06("monster")`
- `unit_card_snapshot_v06("monster")` for public UID/family/rank/actor-revision targeting facts
- `prepare_unit_card_intent_v06(intent)`
- `commit_unit_card_intent_v06(prepared)`
- `rollback_unit_card_intent_v06(receipt)`
- `finalize_unit_card_intent_v06(receipt)`
- `unit_card_save_data_v06("monster")` / `apply_unit_card_save_data_v06(...)`

Capability scope now reports `rank_1_starter_first_summon_and_same_family_upgrade`, and `upgrade_duration_policy_ready=true` with `monster_upgrade_adds_remaining_time`.

The existing rule snapshot is the narrow cap port. Future production providers should include one authoritative primary-rank-cap field in `monster_deploy_rule_snapshot_v06(actor_id)`; the client must never send or calculate the cap.

The existing cross-owner side-effect stage receives private developer/machine fields including acting actor, target unit, rank before/after, and `bound_skill_recipient_actor_id`. These fields must not be copied into public receipts.

## Focused evidence

Godot: `4.7.stable.official.5b4e0cb0f`; isolated temporary `APPDATA`/`LOCALAPPDATA`; no default `user://`, editor, MCP, headed run, full smoke, commit, or push.

1. `godot --headless --path . --script res://tests/monster_cross_owner_upgrade_v06_test.gd`
   - PASS: `checks=24 failures=0`
   - Covers rival I→II, owner/control/cash-attribution preservation, bound skill recipient, starter private reselect, base II, authoritative III/IV, forged request cap, wrong actor/target/transaction, rollback/replay/save-load, and public privacy.
2. `godot --headless --path . --script res://tests/monster_deploy_atomic_lifecycle_v06_test.gd`
   - PASS: `checks=61 failures=0`
   - Confirms the previously shipped first-summon lifecycle remains green.

Suggested coordinator-only integration commands:

- `godot --headless --path . --script res://tests/monster_card_real_owner_integration_v06_test.gd`
- `godot --headless --path . --script res://tests/monster_runtime_v06_privacy_test.gd`
- the isolated vertical-slice CardFlow replay/save suite after the production providers below are wired.

## Production dependencies and risks

1. `scripts/main.gd::monster_deploy_profile_snapshot_v06` currently rejects Rank II-IV. The owner therefore fails closed before roster mutation in the actual composition until the profile owner exposes authoritative Rank II-IV HP/movement/skill patches. Agent B did not edit `main.gd`.
2. The current production binding-rule snapshot does not expose an organization-derived monster rank cap. Production safely permits only I→II through the base fallback; III/IV remain unavailable until the organization/rule owner provides the cap field and revision/fingerprint.
3. Production bound-skill inventory is still a real atomic dependency. A non-empty upgrade skill patch requires prepare/commit/rollback/finalize/exact-once/checkpoint/save-load. Missing capability returns `monster_cross_owner_atomicity_unavailable` before the roster call.
4. CardFlow/Inventory still owns card and cost consumption. Coordinator acceptance must verify a failed private starter reselect or cap check leaves the runtime card in hand, and that one finalized reinforcement consumes exactly one card transaction.
5. Legacy direct monster write paths can still create non-v0.6 rows. The new v0.6 path detects duplicate active families and fails closed, but global retirement of legacy writers remains the integration owner's responsibility.

## Lessons for other agents

- **Invariant:** target owner, not acting player, is the authority for rank permission, skill recipient, control, and damage-cash attribution.
- **Failed approach:** accepting a client/request rank cap or selecting the acting player's rule snapshot for a rival target would permit forged Rank III/IV upgrades.
- **Stable API:** the existing combined `deploy_or_upgrade_monster` intent and owner lifecycle are sufficient; the operation is derived and journal-bound at prepare.
- **Test oracle:** compare UID/owner/owner index/roster count before and after, inspect the cross-owner skill recipient, and independently scan the public snapshot recursively.
- **Integration trap:** method availability is not production readiness; the current main profile provider is Rank-I-only even though the Monster owner lifecycle supports upgrades.
- **Reusable pattern:** bind both acting-owner and target-owner rule fingerprints plus the full roster pre/postimage, then compensate side-effect participants before swapping the roster preimage on rollback.
- **Stale evidence:** `monster_upgrade_duration_policy_conflict` and `upgrade_target_owned_same_family` are obsolete. Current catalog fields use additive remaining time, any-owner same-family targeting, no ownership transfer, existing-owner skill recipient, private starter reselect, and target-owner rank-cap enforcement.
- **Next dependency:** the profile/rule/skill-inventory owners must provide Rank II-IV profiles, authoritative organization cap fields, and atomic skill grants before Coordinator can claim end-to-end production reinforcement.
