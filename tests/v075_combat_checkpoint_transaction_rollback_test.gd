extends SceneTree

var _runtime_script: Script
var _combat_script: Script
var _checkpoint_script: Script
var _batch_core_script: Script
var _facility_core_script: Script
var _damage_intent_script: Script
var _checks := 0
var _failures: Array[String] = []


class BeginBatchFailRuntime extends V075RuntimeOwner:
    func _facility_lock_batch(
        _batch_id: String,
        _player_ids: Array,
        _hidden_order: Array,
        _player_local_queues: Dictionary,
        _facility_slots: Array
    ) -> Dictionary:
        return {}

class FailingCompletionCombatOwner extends Node:
    var checkpoint_script: Script
    var facility_intent: Dictionary = {}
    var fail_completion_once := true
    var lineage_id := "fake.combat.mixed"
    var revision := 1
    var initialized := false
    var phase := "idle"
    var batch_id := ""
    var military_locks: Dictionary = {}
    var processed_missions: Dictionary = {}
    var processed_receipt_keys: Dictionary = {}
    var receipt_journal: Array = []
    var rollback_count := 0
    var completion_count := 0
    var fail_initialize := false
    var failed_initialize_reset_count := 0
    var active_initialization_ownership_token := ""
    var completed_initialization_cleanup_results_by_token: Dictionary = {}

    func _init(checkpoint: Script = null) -> void:
        checkpoint_script = checkpoint

    func begin_initialization_transaction(context: Dictionary) -> Dictionary:
        var transaction_id := str(context.get("ownership_token", ""))
        var accepted := (
            not transaction_id.is_empty()
            and active_initialization_ownership_token.is_empty()
            and not completed_initialization_cleanup_results_by_token.has(transaction_id)
        )
        if accepted:
            active_initialization_ownership_token = transaction_id
        return {
            "schema": "V075CombatInitializationTransactionReceiptV1",
            "accepted": accepted,
            "reason_code": (
                "fake_initialization_transaction_bound"
                if accepted
                else "fake_initialization_transaction_rejected"
            ),
        }
    func initialize(_players: Array, _map: Dictionary, _semantics: Dictionary = {}) -> Dictionary:
        if fail_initialize:
            return {"accepted": false, "reason_code": "injected_initialize_failure"}
        initialized = true
        phase = "ready"
        return {"accepted": true, "reason_code": "fake_initialized"}

    func cleanup_failed_initialization(context: Dictionary) -> Dictionary:
        failed_initialize_reset_count += 1
        var transaction_id := str(context.get("ownership_token", ""))
        var duplicate := completed_initialization_cleanup_results_by_token.has(transaction_id)
        var accepted := duplicate or (
            not transaction_id.is_empty()
            and transaction_id == active_initialization_ownership_token
        )
        if accepted and not duplicate:
            initialized = false
            phase = "idle"
            batch_id = ""
            military_locks.clear()
            processed_missions.clear()
            processed_receipt_keys.clear()
            receipt_journal.clear()
            active_initialization_ownership_token = ""
            completed_initialization_cleanup_results_by_token[transaction_id] = true
        var residuals := _failed_initialization_residuals()
        var result := {
            "schema": "V075FailedInitializationCleanupResultV1",
            "accepted": accepted,
            "reason_code": (
                "combat_failed_initialization_cleaned"
                if accepted
                else "fake_initialization_transaction_mismatch"
            ),
            "failed_cleanup_stage": "" if accepted else "transaction_ownership",
            "cleanup_invocation_count": failed_initialize_reset_count,
            "already_clean": duplicate,
            "external_state_mutation_count": 0,
            "cleanup_owned_state_only": true,
        }
        for field_name in residuals:
            result[field_name] = residuals.get(field_name)
        return result
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
        return {"accepted": true, "action": request.duplicate(true)}

    func resolve_monster_card_action(_action: Dictionary) -> Dictionary:
        return {"accepted": true, "receipt": {}}

    func build_military_lock(binding: Dictionary, _facilities: Array) -> Dictionary:
        var mission_id := str(binding.get("mission_id", ""))
        if mission_id.is_empty():
            return {"accepted": false, "reason_code": "fake_mission_id_missing"}
        military_locks[mission_id] = binding.duplicate(true)
        revision += 1
        return {"accepted": true, "locked_mission": binding.duplicate(true)}

    func resolve_military_action(mission_id: String, _facilities: Array) -> Dictionary:
        if processed_missions.has(mission_id):
            return {
                "accepted": true,
                "reason_code": "fake_military_exact_once_replay",
                "replayed": true,
                "receipt": (processed_missions.get(mission_id, {}) as Dictionary).duplicate(true),
                "facility_damage_intents": [],
            }
        var receipt := {
            "outcome": "resolved",
            "task_kind": "assault_region",
            "reason_code": "fake_military_resolved",
            "combat_receipt_id": "combat.receipt.mixed.001",
        }
        processed_missions[mission_id] = receipt.duplicate(true)
        processed_receipt_keys[str(receipt.get("combat_receipt_id", ""))] = true
        revision += 1
        return {
            "accepted": true,
            "reason_code": "fake_military_resolved",
            "replayed": false,
            "receipt": receipt,
            "facility_damage_intents": [facility_intent.duplicate(true)],
            "monster_damage_receipts": [],
        }

    func begin_public_receipt(_receipt_id: String) -> Dictionary:
        phase = "public_resolution_between_receipts"
        revision += 1
        return {"accepted": true, "reason_code": "fake_receipt_started"}

    func complete_public_receipt(
        _receipt_id: String,
        assets: Dictionary,
        _facilities: Array
    ) -> Dictionary:
        completion_count += 1
        phase = "public_resolution_between_receipts"
        revision += 1
        if fail_completion_once:
            fail_completion_once = false
            return {"accepted": false, "reason_code": "injected_completion_failure"}
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
        return {"accepted": true, "reason_code": "fake_autonomy_resolved", "facility_damage_intents": []}

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
            "initialized": initialized,
            "phase": phase,
            "military_lock_count": military_locks.size(),
            "processed_mission_count": processed_missions.size(),
            "processed_receipt_key_count": processed_receipt_keys.size(),
            "completion_count": completion_count,
            "rollback_count": rollback_count,
            "failed_initialization_residuals": (
                _failed_initialization_residuals()
            ),
        }

    func _failed_initialization_residuals() -> Dictionary:
        var remaining_binding_count := 1 if initialized else 0
        var remaining_instant_sequence_count := (
            processed_receipt_keys.size()
            + (1 if not batch_id.is_empty() else 0)
        )
        var remaining_military_mission_count := (
            military_locks.size()
            + processed_missions.size()
        )
        var remaining_receipt_count := receipt_journal.size()
        var remaining_state_entry_count := (
            remaining_binding_count
            + remaining_instant_sequence_count
            + remaining_military_mission_count
            + remaining_receipt_count
            + (1 if phase != "idle" else 0)
        )
        return {
            "remaining_binding_count": remaining_binding_count,
            "remaining_subscription_count": 0,
            "remaining_private_skill_count": 0,
            "remaining_instant_sequence_count": (
                remaining_instant_sequence_count
            ),
            "remaining_military_mission_count": (
                remaining_military_mission_count
            ),
            "remaining_receipt_count": remaining_receipt_count,
            "remaining_ai_binding_count": 0,
            "remaining_player_projection_binding_count": 0,
            "remaining_telemetry_binding_count": 0,
            "remaining_state_entry_count": remaining_state_entry_count,
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
            "processed_receipt_keys": processed_receipt_keys.duplicate(true),
        }

    func _restore(state: Dictionary) -> void:
        lineage_id = str(state.get("lineage_id", lineage_id))
        revision = int(state.get("revision", revision))
        receipt_journal = (state.get("receipt_journal", []) as Array).duplicate(true)
        phase = str(state.get("phase", phase))
        batch_id = str(state.get("batch_id", batch_id))
        military_locks = (state.get("military_locks", {}) as Dictionary).duplicate(true)
        processed_missions = (state.get("processed_missions", {}) as Dictionary).duplicate(true)
        processed_receipt_keys = (state.get("processed_receipt_keys", {}) as Dictionary).duplicate(true)


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    _runtime_script = load("res://scripts/v075_runtime/v075_runtime_owner.gd") as Script
    _combat_script = load("res://scripts/v075/runtime/v075_combat_runtime_owner.gd") as Script
    _checkpoint_script = load("res://scripts/v075/combat/v075_combat_checkpoint_v1.gd") as Script
    _batch_core_script = load("res://scripts/v075/runtime/v075_public_action_batch_core.gd") as Script
    _facility_core_script = load("res://scripts/v074/facility/v074_facility_runtime_core.gd") as Script
    _damage_intent_script = load("res://scripts/v075/combat/facility_combat_damage_intent_v1.gd") as Script
    if (
        _runtime_script == null
        or _combat_script == null
        or _checkpoint_script == null
        or _batch_core_script == null
        or _facility_core_script == null
        or _damage_intent_script == null
    ):
        _expect(false, "V075 rollback dependencies are available")
        _finish()
        return
    _test_mixed_public_batch_failure_and_retry()
    _test_failed_start_is_atomic_and_lock_fails_closed()
    _test_parent_begin_batch_rejection_is_atomic()
    _test_terminal_combat_quiescence()
    _finish()


func _test_mixed_public_batch_failure_and_retry() -> void:
    var runtime := _runtime_with_fake_combat()
    var combat := runtime.get_meta("combat") as FailingCompletionCombatOwner
    var fixture := _mixed_batch_fixture(runtime)
    var batch_state := fixture.get("state", {}) as Dictionary
    var facility := fixture.get("facility", {}) as Dictionary
    var intent := _damage_intent_script.call(
        "build",
        "effect.rollback.mixed",
        str(facility.get("facility_id", "")),
        int(facility.get("facility_generation", 0)),
        1,
        "military_region_assault",
        "combat.receipt.mixed.001"
    ) as Dictionary
    combat.facility_intent = intent.duplicate(true)
    _expect(not intent.is_empty(), "mixed fixture builds a typed facility damage intent")
    _expect(
        int((batch_state.get("authority_queue", []) as Array).size()) == 2,
        "mixed fixture contains combat and ordinary public queue entries"
    )
    var queue_before := (batch_state.get("authority_queue", []) as Array).duplicate(true)
    var anonymous_before := (batch_state.get("anonymous_global_queue", []) as Array).duplicate(true)
    var cursor_before := int(batch_state.get("resolution_cursor", -1))
    var runtime_before := _runtime_ownership_snapshot(runtime, "player.local")
    var first_resolution := _batch_core_script.call("resolve_next", batch_state) as Dictionary
    _expect(bool(first_resolution.get("accepted", false)), "mixed batch exposes a first resolution receipt")
    var first_receipt := first_resolution.get("receipt", {}) as Dictionary
    _expect(
        str(first_receipt.get("action_domain", "")) == "military",
        "combat action is first in the frozen anonymous order"
    )
    var next_state := first_resolution.get("state", {}) as Dictionary
    var next_before := next_state.duplicate(true)
    var failed := runtime.call(
        "_resolve_combat_public_action",
        first_receipt,
        next_state
    ) as Dictionary
    _expect(not bool(failed.get("accepted", false)), "injected public receipt failure rejects the combat action")
    _expect(
        str(failed.get("reason_code", "")) == "injected_completion_failure",
        "mixed batch preserves the downstream receipt failure reason"
    )
    _expect(combat.rollback_count == 1, "combat owner rolls back one failed public receipt")
    _expect(
        combat.state_snapshot().get("military_locks", {}) == {},
        "Combat military ledger is restored after public failure"
    )
    _expect(
        (runtime.get("_facility_damage_bridge_state") as Dictionary).is_empty()
            and (runtime.get("_processed_facility_damage_intents") as Dictionary).is_empty(),
        "facility bridge and processed intent ledgers have no partial commit"
    )
    var debug_after_failure := runtime.call("debug_snapshot") as Dictionary
    _expect(
        int(debug_after_failure.get("facility_damage_bridge_receipt_count", -1)) == 0
            and int(debug_after_failure.get("facility_combat_damage_receipt_count", -1)) == 0,
        "facility bridge counters roll back to their checkpoint"
    )
    _expect(
        batch_state.get("authority_queue", []) == queue_before
            and batch_state.get("anonymous_global_queue", []) == anonymous_before
            and int(batch_state.get("resolution_cursor", -1)) == cursor_before,
        "failed combat leaves queue cursor and anonymous order untouched"
    )
    _expect(next_state == next_before, "failed combat does not mutate the projected next batch state")
    _expect(
        _runtime_ownership_snapshot(runtime, "player.local") == runtime_before,
        "failed combat does not debit assets or move DBG ownership"
    )

    var retry_resolution := _batch_core_script.call("resolve_next", batch_state) as Dictionary
    var retry_receipt := retry_resolution.get("receipt", {}) as Dictionary
    _expect(
        str(retry_receipt.get("action_id", "")) == str(first_receipt.get("action_id", ""))
            and str(retry_receipt.get("anonymous_action_id", "")) == str(first_receipt.get("anonymous_action_id", "")),
        "retry replays the same anonymous action identity"
    )
    var retried := runtime.call(
        "_resolve_combat_public_action",
        retry_receipt,
        retry_resolution.get("state", {}) as Dictionary
    ) as Dictionary
    _expect(bool(retried.get("accepted", false)), "same combat receipt succeeds after rollback")
    _expect(
        int((runtime.get("_processed_facility_damage_intents") as Dictionary).size()) == 1
            and int((runtime.get("_facility_damage_bridge_state") as Dictionary).get("receipt_journal", {}).size()) == 1,
        "successful retry commits exactly one facility intent"
    )
    var committed_batch := retry_resolution.get("state", {}) as Dictionary
    var following := _batch_core_script.call("resolve_next", committed_batch) as Dictionary
    _expect(bool(following.get("accepted", false)), "following mixed queue entry remains available")
    _expect(
        str((following.get("receipt", {}) as Dictionary).get("action_id", "")) != str(first_receipt.get("action_id", ""))
            and int(committed_batch.get("resolution_cursor", -1)) == 1,
        "queue cursor advances once and does not duplicate the combat action"
    )
    _dispose(runtime)


func _test_terminal_combat_quiescence() -> void:
    var runtime := _runtime_with_fake_combat()
    var actual := _combat_script.new() as Node
    root.add_child(actual)
    var initialized := actual.call(
        "initialize",
        runtime.call("player_ids"),
        runtime.call("map_genesis_receipt"),
        {}
    ) as Dictionary
    _expect(bool(initialized.get("accepted", false)), "real Combat owner initializes for terminal probe")
    if bool(initialized.get("accepted", false)):
        actual.call("begin_batch", "batch.terminal.probe", 0, runtime.get("_asset_state"), [])
        var terminal := actual.call("set_phase", "victory_pending") as Dictionary
        _expect(bool(terminal.get("accepted", false)), "real Combat owner enters terminal pending phase")
        var request := actual.call(
            "request_private_skill",
            {
                "request_id": "request.terminal.probe",
                "owner_player_id": "player.local",
                "source_instance_id": "missing.source",
                "source_generation": 1,
                "skill_definition_id": "missing.skill",
                "target_request": {},
            },
            runtime.get("_asset_state"),
            []
        ) as Dictionary
        _expect(
            not bool(request.get("accepted", false))
                and str(request.get("reason_code", "")) == "private_skill_request_phase_invalid",
            "terminal Combat owner rejects new private combat requests"
        )
    actual.queue_free()
    _dispose(runtime)


func _test_failed_start_is_atomic_and_lock_fails_closed() -> void:
    var runtime := _runtime_script.new() as Node
    var combat := FailingCompletionCombatOwner.new(_checkpoint_script)
    combat.fail_initialize = true
    root.add_child(runtime)
    root.add_child(combat)
    runtime.set_meta("combat", combat)
    var bound := runtime.call("bind_combat_owner", combat) as Dictionary
    _expect(bool(bound.get("accepted", false)), "failed-start fixture binds Combat")
    var lock_before_start := runtime.call(
        "lock_player_submission",
        "player.local"
    ) as Dictionary
    _expect(
        not bool(lock_before_start.get("accepted", true))
            and str(lock_before_start.get("reason_code", ""))
                == "combat_runtime_unavailable",
        "submission lock fails closed while Combat is uninitialized"
    )
    var signal_counts := {
        "match_started": 0,
        "state_changed": 0,
        "runtime_fault": 0,
    }
    runtime.connect("match_started", func(_snapshot: Dictionary) -> void:
        signal_counts["match_started"] = int(
            signal_counts.get("match_started", 0)
        ) + 1
    )
    runtime.connect("state_changed", func(_snapshot: Dictionary) -> void:
        signal_counts["state_changed"] = int(
            signal_counts.get("state_changed", 0)
        ) + 1
    )
    runtime.connect("runtime_fault", func(_receipt: Dictionary) -> void:
        signal_counts["runtime_fault"] = int(
            signal_counts.get("runtime_fault", 0)
        ) + 1
    )
    var match_sequence_before := int(runtime.get("_match_sequence"))
    var failed := runtime.call(
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
    _expect(
        not bool(failed.get("accepted", true))
            and str(failed.get("reason_code", ""))
                == "combat_runtime_initialization_failed",
        "Combat initialization failure rejects the whole new-game transaction"
    )
    _expect(
        int(signal_counts.get("match_started", -1)) == 0
            and int(signal_counts.get("state_changed", -1)) == 0
            and int(signal_counts.get("runtime_fault", -1)) == 1,
        "failed start publishes no match or snapshot and exactly one fault"
    )
    _expect(
        (runtime.call("player_ids") as Array).is_empty()
            and (runtime.call("player_snapshot", "player.local") as Dictionary).is_empty()
            and int(runtime.get("_match_sequence")) == match_sequence_before,
        "failed start leaves no player snapshot and restores match sequence"
    )
    _expect(
        not bool(runtime.get("_combat_initialized"))
            and combat.failed_initialize_reset_count == 1,
        "failed start clears partial Combat state exactly once"
    )
    _dispose(runtime)


func _test_parent_begin_batch_rejection_is_atomic() -> void:
    var runtime := BeginBatchFailRuntime.new()
    var combat := FailingCompletionCombatOwner.new(_checkpoint_script)
    root.add_child(runtime)
    root.add_child(combat)
    var bound := runtime.call("bind_combat_owner", combat) as Dictionary
    _expect(
        bool(bound.get("accepted", false)),
        "begin-batch failure fixture binds Combat"
    )
    var signal_counts := {
        "match_started": 0,
        "state_changed": 0,
        "runtime_fault": 0,
    }
    runtime.connect("match_started", func(_snapshot: Dictionary) -> void:
        signal_counts["match_started"] = int(
            signal_counts.get("match_started", 0)
        ) + 1
    )
    runtime.connect("state_changed", func(_snapshot: Dictionary) -> void:
        signal_counts["state_changed"] = int(
            signal_counts.get("state_changed", 0)
        ) + 1
    )
    runtime.connect("runtime_fault", func(_receipt: Dictionary) -> void:
        signal_counts["runtime_fault"] = int(
            signal_counts.get("runtime_fault", 0)
        ) + 1
    )
    var match_sequence_before := int(runtime.get("_match_sequence"))
    var failed := runtime.call(
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
    _expect(
        not bool(failed.get("accepted", true))
            and str(failed.get("reason_code", ""))
                == "v075_new_game_initialization_failed",
        "plain inherited begin-batch rejection is one failed start"
    )
    _expect(
        (runtime.call("player_ids") as Array).is_empty()
            and (runtime.call("map_genesis_receipt") as Dictionary).is_empty()
            and str(runtime.get("_phase")) == "idle"
            and int(runtime.get("_match_sequence")) == match_sequence_before
            and not bool(runtime.get("_combat_initialized")),
        "plain inherited begin-batch rejection rolls back partial runtime state"
    )
    _expect(
        int(signal_counts.get("match_started", -1)) == 0
            and int(signal_counts.get("state_changed", -1)) == 0
            and int(signal_counts.get("runtime_fault", -1)) == 1
            and combat.failed_initialize_reset_count == 1,
        "plain begin-batch rejection publishes one fault and resets Combat"
    )
    runtime.queue_free()
    combat.queue_free()

func _runtime_with_fake_combat() -> Node:
    var runtime := _runtime_script.new() as Node
    var combat := FailingCompletionCombatOwner.new(_checkpoint_script)
    runtime.set_meta("combat", combat)
    root.add_child(runtime)
    root.add_child(combat)
    var bound := runtime.call("bind_combat_owner", combat) as Dictionary
    _expect(bool(bound.get("accepted", false)), "runtime binds the mixed-batch Combat owner")
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
    _expect(bool(started.get("accepted", false)), "runtime starts the mixed-batch fixture")
    return runtime


func _mixed_batch_fixture(runtime: Node) -> Dictionary:
    var occupied := _facility_core_script.call(
        "build_occupied_slot",
        "region.rollback.001",
        1,
        "warehouse",
        "shipping",
        1,
        "facility.rollback.001",
        1,
        "player.owner",
        1,
        0,
        0,
        "sunlit"
    ) as Dictionary
    var empty := _facility_core_script.call(
        "build_empty_slot",
        "region.rollback.002",
        1,
        "factory",
        "life",
        1
    ) as Dictionary
    var facility_action := _facility_core_script.call(
        "build_new_action",
        "action.facility.mixed.001",
        "card.facility.mixed.001",
        "player.ai.1",
        0,
        empty,
        _zero_assets(),
        "standard",
        1
    ) as Dictionary
    var card := _first_private_hand_card(runtime, "player.local")
    var card_action_binding := runtime.call(
        "_authoritative_card_action_binding",
        "player.local",
        str(card.get("instance_id", ""))
    ) as Dictionary
    _expect(
        not card.is_empty() and not card_action_binding.is_empty(),
        "mixed fixture uses a DBG-issued authoritative card binding"
    )
    var combat_action := {
        "action_id": "action.combat.mixed.001",
        "actor_id": "player.local",
        "local_action_index": 0,
        "action_domain": "military",
        "source_card_instance_id": str(card.get("instance_id", "")),
        "source_card_definition_id": str(card.get("definition_id", "")),
        "card_action_binding": card_action_binding.duplicate(true),
        "combat_binding": {"mission_id": "mission.mixed.001"},
    }
    var state := _batch_core_script.call(
        "lock_batch",
        "batch.rollback.mixed",
        ["player.local", "player.ai.1"],
        ["player.local", "player.ai.1"],
        {
            "player.local": [combat_action],
            "player.ai.1": [facility_action],
        },
        [occupied, empty]
    ) as Dictionary
    return {"state": state, "facility": occupied}


func _first_private_hand_card(runtime: Node, actor_id: String) -> Dictionary:
    var projection := runtime.call("_dbg_projection", actor_id) as Dictionary
    var facts := projection.get("facts", {}) as Dictionary
    for card_variant in facts.get("hand", []) as Array:
        if not (card_variant is Dictionary):
            continue
        var card := card_variant as Dictionary
        if not str(card.get("instance_id", "")).is_empty():
            return card.duplicate(true)
    return {}


func _runtime_ownership_snapshot(runtime: Node, actor_id: String) -> Dictionary:
    var dbg := runtime.get("_dbg_by_player") as Dictionary
    var actor_dbg: Variant = dbg.get(actor_id)
    var dbg_state := {}
    if actor_dbg != null and actor_dbg.has_method("core_authority_snapshot"):
        dbg_state = actor_dbg.call("core_authority_snapshot") as Dictionary
    return {
        "asset_state": (runtime.get("_asset_state") as Dictionary).duplicate(true),
        "dbg_state": dbg_state.duplicate(true),
        "phase": str(runtime.get("_phase")),
        "batch_id": str(runtime.get("_batch_id")),
    }


func _zero_assets() -> Dictionary:
    return {
        "life": 0,
        "energy": 0,
        "industry": 0,
        "technology": 0,
        "commerce": 0,
        "shipping": 0,
    }


func _dispose(runtime: Node) -> void:
    var combat: Node = null
    if is_instance_valid(runtime) and runtime.has_meta("combat"):
        combat = runtime.get_meta("combat") as Node
    if is_instance_valid(runtime):
        runtime.queue_free()
    if is_instance_valid(combat):
        combat.queue_free()


func _expect(condition: bool, message: String) -> void:
    _checks += 1
    if not condition:
        _failures.append(message)
        push_error(message)


func _finish() -> void:
    print(
        "V075_COMBAT_CHECKPOINT_TRANSACTION_ROLLBACK_TEST|%s"
        % JSON.stringify({
            "status": "PASS" if _failures.is_empty() else "FAIL",
            "passed": _checks - _failures.size(),
            "total": _checks,
            "failures": _failures,
        })
    )
    quit(0 if _failures.is_empty() else 1)
