extends SceneTree

var _runtime_script: Script
var _checkpoint_script: Script
var _checks := 0
var _failures: Array[String] = []


class FakeCombatOwner extends Node:
    var checkpoint_script: Script
    var lineage_id := "fake.combat.submission"
    var revision := 1
    var phase := "ready"
    var batch_id := ""
    var military_locks: Dictionary = {}
    var processed_missions: Dictionary = {}
    var receipt_journal: Array = []
    var rollback_count := 0

    func _init(checkpoint: Script = null) -> void:
        checkpoint_script = checkpoint

    func initialize(_players: Array, _map: Dictionary, _semantics: Dictionary = {}) -> Dictionary:
        phase = "ready"
        return {"accepted": true, "reason_code": "fake_initialized"}

    func begin_batch(next_batch_id: String, _batch_index: int, _assets: Dictionary, _facilities: Array) -> Dictionary:
        batch_id = next_batch_id
        phase = "batch_active"
        revision += 1
        return {"accepted": true, "reason_code": "fake_batch_started"}

    func set_phase(next_phase: String) -> Dictionary:
        phase = next_phase
        revision += 1
        return {"accepted": true, "reason_code": "fake_phase_updated"}

    func prebind_monster_card_action(request: Dictionary) -> Dictionary:
        return {
            "accepted": true,
            "reason_code": "fake_monster_prebound",
            "action": request.duplicate(true),
        }

    func resolve_monster_card_action(_action: Dictionary) -> Dictionary:
        return {"accepted": true, "reason_code": "fake_monster_resolved", "receipt": {}}

    func build_military_lock(binding: Dictionary, _facilities: Array) -> Dictionary:
        var mission_id := str(binding.get("mission_id", ""))
        if mission_id.is_empty():
            return {"accepted": false, "reason_code": "fake_mission_id_missing"}
        military_locks[mission_id] = binding.duplicate(true)
        revision += 1
        return {
            "accepted": true,
            "reason_code": "fake_military_locked",
            "locked_mission": binding.duplicate(true),
        }

    func resolve_military_action(_mission_id: String, _facilities: Array) -> Dictionary:
        return {"accepted": true, "reason_code": "fake_military_resolved", "receipt": {}}

    func begin_public_receipt(_receipt_id: String) -> Dictionary:
        return {"accepted": true, "reason_code": "fake_receipt_started"}

    func complete_public_receipt(
        _receipt_id: String,
        assets: Dictionary,
        _facilities: Array
    ) -> Dictionary:
        return {
            "accepted": true,
            "reason_code": "fake_receipt_completed",
            "asset_state": assets.duplicate(true),
            "facility_damage_intents": [],
            "public_results": [],
        }

    func request_private_skill(_request: Dictionary, assets: Dictionary, _facilities: Array) -> Dictionary:
        return {"accepted": false, "reason_code": "fake_private_skill_unused", "asset_state": assets.duplicate(true)}

    func resolve_private_skill_safe_boundary(assets: Dictionary, _facilities: Array) -> Dictionary:
        return {
            "accepted": true,
            "reason_code": "fake_skill_boundary_empty",
            "asset_state": assets.duplicate(true),
            "facility_damage_intents": [],
            "public_results": [],
        }

    func plan_autonomy(_facilities: Array) -> Dictionary:
        return {"accepted": true, "reason_code": "fake_autonomy_planned"}

    func resolve_autonomy(_facilities: Array) -> Dictionary:
        return {
            "accepted": true,
            "reason_code": "fake_autonomy_resolved",
            "facility_damage_intents": [],
        }

    func public_monsters() -> Array:
        return []

    func owner_private_skill_zone(_owner_id: String) -> Array:
        return []

    func projection_authority_for_viewer(viewer_id: String, private_facts: Dictionary = {}) -> Dictionary:
        return {
            "phase": phase,
            "public_monsters": [],
            "private_skill_zones_by_player": {viewer_id: []},
            "private_player_facts_by_player": {viewer_id: private_facts.duplicate(true)},
        }

    func capture_checkpoint(checkpoint_id: String) -> Dictionary:
        if checkpoint_script == null:
            return {}
        return checkpoint_script.call("capture_combat", checkpoint_id, _state()) as Dictionary

    func rollback_checkpoint(checkpoint: Dictionary) -> Dictionary:
        rollback_count += 1
        if checkpoint_script == null:
            return {"rolled_back": false, "reason_code": "fake_checkpoint_script_missing"}
        var result := checkpoint_script.call("rollback", _state(), checkpoint) as Dictionary
        if bool(result.get("rolled_back", false)):
            _restore(result.get("state", {}) as Dictionary)
        return result

    func debug_snapshot() -> Dictionary:
        return {
            "military_lock_count": military_locks.size(),
            "processed_mission_count": processed_missions.size(),
            "rollback_count": rollback_count,
        }

    func state_snapshot() -> Dictionary:
        return _state()

    func _state() -> Dictionary:
        return {
            "lineage_id": lineage_id,
            "revision": revision,
            "receipt_journal": receipt_journal.duplicate(true),
            "phase": phase,
            "batch_id": batch_id,
            "military_locks": military_locks.duplicate(true),
            "processed_missions": processed_missions.duplicate(true),
        }

    func _restore(state: Dictionary) -> void:
        lineage_id = str(state.get("lineage_id", lineage_id))
        revision = int(state.get("revision", revision))
        receipt_journal = (state.get("receipt_journal", []) as Array).duplicate(true)
        phase = str(state.get("phase", phase))
        batch_id = str(state.get("batch_id", batch_id))
        military_locks = (state.get("military_locks", {}) as Dictionary).duplicate(true)
        processed_missions = (state.get("processed_missions", {}) as Dictionary).duplicate(true)


class PassThroughAssetCore extends RefCounted:
    func lock_player_queue(
        state: Dictionary,
        _intent: Dictionary,
        _gdp: Dictionary,
        _time: Dictionary,
        _hidden_order: Array
    ) -> Dictionary:
        return {
            "accepted": true,
            "reason_code": "fake_asset_lock_accepted",
            "state": state.duplicate(true),
        }


class FailingDbgOwner extends RefCounted:
    var mutation_count := 0
    var hand: Array = []

    func player_projection(actor_id: String) -> Dictionary:
        return {
            "visibility_scope": "viewer_private",
            "viewer_id": actor_id,
            "facts": {"hand": hand.duplicate(true)},
        }

    func core_authority_snapshot() -> Dictionary:
        return {"state": {"batch_index": 0}}

    func create_authority_intent(
        intent_id: String,
        _action_kind: String,
        _payload: Dictionary
    ) -> Dictionary:
        return {"intent_id": intent_id, "accepted": true}

    func apply_intent(_intent: Dictionary) -> Dictionary:
        mutation_count += 1
        return {"success": false, "reason_code": "injected_dbg_failure"}


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    _runtime_script = load("res://scripts/v075_runtime/v075_runtime_owner.gd") as Script
    _checkpoint_script = load("res://scripts/v075/combat/v075_combat_checkpoint_v1.gd") as Script
    if _runtime_script == null or _checkpoint_script == null:
        _expect(false, "V075 runtime/checkpoint dependency is available")
        _finish()
        return

    _test_combat_checkpoint_rolls_back_partial_military_lock()
    _test_cross_owner_submission_failure_contract()
    _finish()


func _test_combat_checkpoint_rolls_back_partial_military_lock() -> void:
    var runtime := _new_runtime()
    var combat := runtime.get_meta("combat") as FakeCombatOwner
    var actor := "player.local"
    var hand := _first_private_hand_card(runtime, actor)
    _expect(not hand.is_empty(), "submission fixture has a private card instance")
    if hand.is_empty():
        _dispose(runtime)
        return

    var first := _military_binding(hand, "action.rollback.first", "region.000")
    var second := _military_binding(hand, "action.rollback.invalid", "")
    var queues := (runtime.get("_queued_by_player") as Dictionary).duplicate(true)
    queues[actor] = [first, second]
    runtime.set("_queued_by_player", queues)

    var checkpoint_before := combat.capture_checkpoint("checkpoint.submission.before")
    var state_before := (checkpoint_before.get("state", {}) as Dictionary).duplicate(true)
    var runtime_before := _runtime_ownership_snapshot(runtime, actor)
    var failed := runtime.call("lock_player_submission", actor) as Dictionary
    _expect(not bool(failed.get("accepted", false)), "invalid later binding rejects submission lock")
    _expect(
        str(failed.get("reason_code", "")) == "prebound_action_build_failed",
        "submission failure identifies the failed prebind"
    )
    _expect(
        int(failed.get("local_action_index", -1)) == 1,
        "submission failure points at the second binding"
    )
    var checkpoint_after := combat.capture_checkpoint("checkpoint.submission.after")
    _expect(
        (checkpoint_after.get("state", {}) as Dictionary) == state_before,
        "Combat checkpoint restores the partial military lock exactly"
    )
    _expect(combat.rollback_count == 1, "failed submission invokes Combat rollback once")
    _expect(
        _runtime_ownership_snapshot(runtime, actor) == runtime_before,
        "failed submission preserves queue, assets, DBG ownership, and anonymous batch state"
    )

    queues = (runtime.get("_queued_by_player") as Dictionary).duplicate(true)
    queues[actor] = [first]
    runtime.set("_queued_by_player", queues)
    var retried := runtime.call("lock_player_submission", actor) as Dictionary
    _expect(bool(retried.get("accepted", false)), "valid submission retries after rollback")
    _expect(combat.military_locks.size() == 1, "retry creates one military lock")
    var committed_state := combat.state_snapshot()
    var duplicate := runtime.call("lock_player_submission", actor) as Dictionary
    _expect(
        bool(duplicate.get("accepted", false))
            and str(duplicate.get("reason_code", "")) == "submission_already_locked",
        "duplicate submission retry is exact-once"
    )
    _expect(combat.state_snapshot() == committed_state, "duplicate retry does not mutate Combat state")
    _dispose(runtime)


func _test_cross_owner_submission_failure_contract() -> void:
    var runtime := _new_runtime()
    var actor := "player.local"
    var hand := _first_private_hand_card(runtime, actor)
    _expect(not hand.is_empty(), "cross-owner fixture has a private card instance")
    if hand.is_empty():
        _dispose(runtime)
        return
    var first := _military_binding(hand, "action.rollback.dbg", "region.000")
    var queues := (runtime.get("_queued_by_player") as Dictionary).duplicate(true)
    queues[actor] = [first]
    runtime.set("_queued_by_player", queues)
    runtime.set("_asset_core", PassThroughAssetCore.new())
    var failing_dbg := FailingDbgOwner.new()
    var original_projection := runtime.call("_dbg_projection", actor) as Dictionary
    failing_dbg.hand = (
        original_projection.get("facts", {}) as Dictionary
    ).get("hand", []) as Array
    var dbg_by_player := (runtime.get("_dbg_by_player") as Dictionary).duplicate(true)
    dbg_by_player[actor] = failing_dbg
    runtime.set("_dbg_by_player", dbg_by_player)
    var before := _runtime_ownership_snapshot(runtime, actor)
    var failed := runtime.call("lock_player_submission", actor) as Dictionary
    _expect(not bool(failed.get("accepted", false)), "downstream DBG failure rejects submission lock")
    _expect(
        str(failed.get("reason_code", "")) == "submission_checkpoint_unavailable",
        "missing rollback capability rejects before any ownership writer"
    )
    _expect(
        _runtime_ownership_snapshot(runtime, actor) == before,
        "submission failure rolls back asset and DBG ownership after downstream rejection"
    )
    _expect(
        failing_dbg.mutation_count == 0,
        "checkpoint preflight prevents an unrollbackable DBG mutation"
    )
    _dispose(runtime)


func _new_runtime() -> Node:
    var runtime := _runtime_script.new() as Node
    var combat := FakeCombatOwner.new(_checkpoint_script)
    runtime.set_meta("combat", combat)
    root.add_child(runtime)
    root.add_child(combat)
    var bound := runtime.call("bind_combat_owner", combat) as Dictionary
    _expect(bool(bound.get("accepted", false)), "runtime binds the isolated Combat owner")
    var started := runtime.call(
        "start_new_game",
        4,
        900626424,
        false,
        false,
        {
            "map_seed": 900626424,
            "region_count": 16,
            "geography_complexity": "STANDARD",
            "land_ocean_profile": "BALANCED",
        }
    ) as Dictionary
    _expect(bool(started.get("accepted", false)), "runtime starts the V075 submission fixture")
    return runtime


func _first_private_hand_card(runtime: Node, actor_id: String) -> Dictionary:
    var projection := runtime.call("_dbg_projection", actor_id) as Dictionary
    var facts := projection.get("facts", {}) as Dictionary
    for card_variant in facts.get("hand", []) as Array:
        var card := card_variant as Dictionary
        if not str(card.get("instance_id", "")).is_empty():
            return card.duplicate(true)
    return {}


func _military_binding(card: Dictionary, action_id: String, region_id: String) -> Dictionary:
    return {
        "actor_id": "player.local",
        "action_id": action_id,
        "card_instance_id": str(card.get("instance_id", "")),
        "card_definition_id": str(card.get("definition_id", "")),
        "target_slot_id": "combat.military.assault_region.%s" % region_id,
        "target_region_id": region_id,
        "target_source_instance_id": "",
        "target_monster_source_instance_id": "",
        "monster_card_mode": "",
        "task_kind": "assault_region",
        "action_domain": "military",
        "target_bound": true,
    }


func _runtime_ownership_snapshot(runtime: Node, actor_id: String) -> Dictionary:
    var dbg := runtime.get("_dbg_by_player") as Dictionary
    var actor_dbg: Variant = dbg.get(actor_id)
    var dbg_state := {}
    if actor_dbg != null and actor_dbg.has_method("core_authority_snapshot"):
        dbg_state = actor_dbg.call("core_authority_snapshot") as Dictionary
    return {
        "asset_state": (runtime.get("_asset_state") as Dictionary).duplicate(true),
        "dbg_state": dbg_state.duplicate(true),
        "queued_by_player": (runtime.get("_queued_by_player") as Dictionary).duplicate(true),
        "locked_by_player": (runtime.get("_locked_by_player") as Dictionary).duplicate(true),
        "facility_state": (runtime.get("_facility_state") as Dictionary).duplicate(true),
        "hidden_order": (runtime.get("_hidden_order") as Array).duplicate(),
        "phase": str(runtime.get("_phase")),
    }


func _dispose(runtime: Node) -> void:
    if is_instance_valid(runtime):
        runtime.queue_free()


func _expect(condition: bool, message: String) -> void:
    _checks += 1
    if not condition:
        _failures.append(message)
        push_error(message)


func _finish() -> void:
    print(
        "V075_COMBAT_SUBMISSION_ROLLBACK_TEST|%s"
        % JSON.stringify({
            "status": "PASS" if _failures.is_empty() else "FAIL",
            "passed": _checks - _failures.size(),
            "total": _checks,
            "failures": _failures,
        })
    )
    quit(0 if _failures.is_empty() else 1)
