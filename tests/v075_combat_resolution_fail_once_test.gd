extends SceneTree

var _runtime_script: Script
var _checkpoint_script: Script
var _batch_core_script: Script
var _asset_core_script: Script
var _facility_core_script: Script
var _damage_intent_script: Script
var _checks := 0
var _failures: Array[String] = []


class ResolutionCombatOwner extends Node:
	var checkpoint_script: Script
	var facility_intent: Dictionary = {}
	var invalid_asset_state_once := false
	var rollback_count := 0
	var begin_receipt_count := 0
	var resolve_count := 0
	var completion_count := 0
	var lineage_id := "fake.combat.resolution.fail.once"
	var revision := 1
	var initialized := false
	var phase := "idle"
	var active_initialization_ownership_token := ""
	var completed_initialization_cleanup_results_by_token: Dictionary = {}
	var failed_initialization_cleanup_count := 0
	var batch_id := ""
	var military_locks: Dictionary = {}
	var processed_missions: Dictionary = {}
	var processed_receipt_keys: Dictionary = {}
	var receipt_journal: Array = []


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


	func cleanup_failed_initialization(context: Dictionary) -> Dictionary:
		failed_initialization_cleanup_count += 1
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
		var result := {
			"schema": "V075FailedInitializationCleanupResultV1",
			"accepted": accepted,
			"reason_code": (
				"combat_failed_initialization_cleaned"
				if accepted
				else "fake_initialization_transaction_mismatch"
			),
			"failed_cleanup_stage": "" if accepted else "transaction_ownership",
			"cleanup_invocation_count": failed_initialization_cleanup_count,
			"already_clean": duplicate,
			"external_state_mutation_count": 0,
			"cleanup_owned_state_only": true,
		}
		for field_name in [
			"remaining_binding_count",
			"remaining_subscription_count",
			"remaining_private_skill_count",
			"remaining_instant_sequence_count",
			"remaining_military_mission_count",
			"remaining_receipt_count",
			"remaining_ai_binding_count",
			"remaining_player_projection_binding_count",
			"remaining_telemetry_binding_count",
			"remaining_state_entry_count",
		]:
			result[field_name] = 0
		return result

	func initialize(
		_players: Array,
		_map: Dictionary,
		_semantics: Dictionary = {}
	) -> Dictionary:
		initialized = true
		phase = "ready"
		return {"accepted": true, "reason_code": "fake_initialized"}


	func begin_batch(
		next_batch_id: String,
		_batch_index: int,
		_assets: Dictionary,
		_facilities: Array
	) -> Dictionary:
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


	func preview_monster_card_action(request: Dictionary) -> Dictionary:
		return prebind_monster_card_action(request)


	func validate_monster_prebound_action(action: Dictionary) -> Dictionary:
		return {"valid": not action.is_empty(), "errors": []}


	func resolve_monster_card_action(_action: Dictionary) -> Dictionary:
		return {
			"accepted": true,
			"reason_code": "fake_monster_resolved",
			"receipt": {},
		}


	func build_military_lock(
		binding: Dictionary,
		_facilities: Array
	) -> Dictionary:
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


	func preview_military_lock(
		binding: Dictionary,
		public_facilities: Array
	) -> Dictionary:
		var locked := binding.duplicate(true)
		var targets: Array = []
		for facility_variant in public_facilities:
			var facility := facility_variant as Dictionary
			if (
				str(facility.get("region_id", ""))
					!= str(binding.get("target_region_id", ""))
				or str(facility.get("owner_player_id", ""))
					== str(binding.get("owner_player_id", ""))
			):
				continue
			targets.append({
				"target_facility_id": str(facility.get("facility_id", "")),
				"expected_generation": int(facility.get("facility_generation", 0)),
			})
		locked["locked_facility_targets"] = targets
		locked["region_strike_damage_budget"] = 1
		var envelope := military_target_envelope(locked)
		return {
			"accepted": not envelope.is_empty(),
			"reason_code": "fake_military_previewed",
			"locked_mission": locked,
			"target_envelope": envelope,
			"state_mutation_count": 0,
		}


	func commit_military_lock(locked_mission: Dictionary) -> Dictionary:
		var mission_id := str(locked_mission.get("mission_id", ""))
		if mission_id.is_empty() or military_locks.has(mission_id):
			return {"accepted": false, "reason_code": "fake_mission_lock_invalid"}
		military_locks[mission_id] = locked_mission.duplicate(true)
		revision += 1
		return {
			"accepted": true,
			"reason_code": "fake_military_locked",
			"locked_mission": locked_mission.duplicate(true),
			"target_envelope": military_target_envelope(locked_mission),
		}


	func military_target_envelope(locked_mission: Dictionary) -> Dictionary:
		var facility_ids: Array[String] = []
		var generations := {}
		for target_variant in locked_mission.get("locked_facility_targets", []) as Array:
			var target := target_variant as Dictionary
			var facility_id := str(target.get("target_facility_id", ""))
			facility_ids.append(facility_id)
			generations[facility_id] = int(target.get("expected_generation", 0))
		facility_ids.sort()
		if facility_ids.is_empty():
			return {}
		var envelope := {
			"schema_version": "1.0.0",
			"contract_id": "v075.military.target_envelope.v1",
			"task_kind": str(locked_mission.get("task_kind", "")),
			"public_information_fingerprint": "",
			"envelope_fingerprint": "",
			"target_region_id": str(locked_mission.get("target_region_id", "")),
			"expected_region_revision": int(locked_mission.get("target_region_revision", -1)),
			"locked_enemy_facility_ids": facility_ids,
			"facility_generations": generations,
			"region_damage_budget": int(locked_mission.get("region_strike_damage_budget", 0)),
		}
		var public_payload := envelope.duplicate(true)
		public_payload.erase("public_information_fingerprint")
		public_payload.erase("envelope_fingerprint")
		envelope["public_information_fingerprint"] = _candidate_hash(public_payload)
		var fingerprint_payload := envelope.duplicate(true)
		fingerprint_payload.erase("envelope_fingerprint")
		envelope["envelope_fingerprint"] = _candidate_hash(fingerprint_payload)
		return envelope


	func _candidate_hash(value: Variant) -> String:
		return _candidate_canonical_json(value).sha256_text().to_lower()


	func _candidate_canonical_json(value: Variant) -> String:
		if value is Dictionary:
			var source := value as Dictionary
			var keys: Array[String] = []
			for key_variant in source.keys():
				keys.append(str(key_variant))
			keys.sort()
			var pairs: Array[String] = []
			for key in keys:
				pairs.append("%s:%s" % [
					JSON.stringify(key),
					_candidate_canonical_json(source.get(key)),
				])
			return "{%s}" % ",".join(pairs)
		if value is Array:
			var rows: Array[String] = []
			for child in value as Array:
				rows.append(_candidate_canonical_json(child))
			return "[%s]" % ",".join(rows)
		return JSON.stringify(value)


	func resolve_military_action(
		mission_id: String,
		_facilities: Array
	) -> Dictionary:
		resolve_count += 1
		if processed_missions.has(mission_id):
			return {
				"accepted": true,
				"reason_code": "fake_military_exact_once_replay",
				"replayed": true,
				"receipt": (
					processed_missions.get(mission_id, {}) as Dictionary
				).duplicate(true),
				"facility_damage_intents": [],
			}
		var receipt := {
			"outcome": "resolved",
			"task_kind": "assault_region",
			"reason_code": "fake_military_resolved",
			"combat_receipt_id": "combat.receipt.resolution.fail.once",
			"public_effect_id": "effect.military.resolution.fail.once",
		}
		processed_missions[mission_id] = receipt.duplicate(true)
		processed_receipt_keys[
			str(receipt.get("combat_receipt_id", ""))
		] = true
		revision += 1
		return {
			"accepted": true,
			"reason_code": "fake_military_resolved",
			"replayed": false,
			"receipt": receipt,
			"facility_damage_intents": [facility_intent.duplicate(true)],
			"monster_damage_receipts": [],
		}


	func begin_public_receipt(receipt_id: String) -> Dictionary:
		begin_receipt_count += 1
		phase = "public_resolution_between_receipts"
		revision += 1
		return {
			"accepted": true,
			"reason_code": "fake_receipt_started",
			"receipt_id": receipt_id,
		}


	func complete_public_receipt(
		receipt_id: String,
		assets: Dictionary,
		_facilities: Array
	) -> Dictionary:
		completion_count += 1
		phase = "public_resolution_between_receipts"
		revision += 1
		if invalid_asset_state_once:
			invalid_asset_state_once = false
			return {
				"accepted": true,
				"reason_code": "injected_asset_state_failure",
				"receipt_id": receipt_id,
				"asset_state": {"invalid": true},
				"facility_damage_intents": [],
				"public_results": [],
			}
		return {
			"accepted": true,
			"reason_code": "fake_receipt_completed",
			"receipt_id": receipt_id,
			"asset_state": assets.duplicate(true),
			"facility_damage_intents": [],
			"public_results": [],
		}


	func request_private_skill(
		_request: Dictionary,
		assets: Dictionary,
		_facilities: Array
	) -> Dictionary:
		return {
			"accepted": false,
			"reason_code": "fake_private_skill_unused",
			"asset_state": assets.duplicate(true),
		}


	func resolve_private_skill_safe_boundary(
		assets: Dictionary,
		_facilities: Array
	) -> Dictionary:
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


	func projection_authority_for_viewer(
		viewer_id: String,
		private_facts: Dictionary = {}
	) -> Dictionary:
		return {
			"phase": phase,
			"public_monsters": [],
			"private_skill_zones_by_player": {viewer_id: []},
			"private_player_facts_by_player": {
				viewer_id: private_facts.duplicate(true),
			},
		}


	func capture_checkpoint(checkpoint_id: String) -> Dictionary:
		if checkpoint_script == null:
			return {}
		return checkpoint_script.call(
			"capture_combat",
			checkpoint_id,
			_state()
		) as Dictionary


	func rollback_checkpoint(checkpoint: Dictionary) -> Dictionary:
		rollback_count += 1
		if checkpoint_script == null:
			return {
				"rolled_back": false,
				"reason_code": "fake_checkpoint_script_missing",
			}
		var result := checkpoint_script.call(
			"rollback",
			_state(),
			checkpoint
		) as Dictionary
		if bool(result.get("rolled_back", false)):
			_restore(result.get("state", {}) as Dictionary)
		return result


	func debug_snapshot() -> Dictionary:
		return {
			"initialized": initialized,
			"phase": phase,
			"revision": revision,
			"combat_runtime_owner_count": 1,
			"combat_state_writer_count": 1,
			"military_lock_count": military_locks.size(),
			"processed_mission_count": processed_missions.size(),
			"processed_receipt_key_count": processed_receipt_keys.size(),
			"begin_receipt_count": begin_receipt_count,
			"resolve_count": resolve_count,
			"completion_count": completion_count,
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
			"processed_receipt_keys": processed_receipt_keys.duplicate(true),
		}


	func _restore(state: Dictionary) -> void:
		lineage_id = str(state.get("lineage_id", lineage_id))
		revision = int(state.get("revision", revision))
		receipt_journal = (
			state.get("receipt_journal", []) as Array
		).duplicate(true)
		phase = str(state.get("phase", phase))
		batch_id = str(state.get("batch_id", batch_id))
		military_locks = (
			state.get("military_locks", {}) as Dictionary
		).duplicate(true)
		processed_missions = (
			state.get("processed_missions", {}) as Dictionary
		).duplicate(true)
		processed_receipt_keys = (
			state.get("processed_receipt_keys", {}) as Dictionary
		).duplicate(true)


class FailingDbgOwner extends RefCounted:
	const BINDING_SCHEMA_ID := "v07.personal_dbg.authoritative_card_action_binding.v1"
	const BINDING_LIFECYCLE_ID := "v075.combat.queue_resolve_personal_discard"
	const BINDING_FIELDS := [
		"schema_id",
		"schema_version",
		"authority_domain_id",
		"authority_lineage_fingerprint",
		"owner_player_id",
		"card_instance_id",
		"card_definition_id",
		"immutable_identity_fingerprint",
		"authoritative_zone",
		"zone_revision",
		"lifecycle_evidence_fingerprint",
		"expected_action_lifecycle",
		"binding_fingerprint",
	]
	var card: Dictionary
	var owner_id := ""
	var authority_state: Dictionary = {
		"batch_index": 0,
		"lock_count": 0,
		"play_count": 0,
	}
	var hand: Array = []
	var committed_escrow: Array = []
	var discard: Array = []
	var fail_play_once := false
	var failure_zone_mutation_count := 0
	var apply_count := 0
	var play_apply_count := 0
	var rollback_count := 0


	func _init(card_value: Dictionary, owner_value: String) -> void:
		card = card_value.duplicate(true)
		card["locked"] = false
		owner_id = owner_value
		hand = [card.duplicate(true)]


	func authoritative_card_action_binding_v1(
		actor_id: String,
		card_instance_id: String,
		expected_lifecycle: String
	) -> Dictionary:
		if (
			actor_id != owner_id
			or card_instance_id != str(card.get("instance_id", ""))
			or expected_lifecycle != BINDING_LIFECYCLE_ID
		):
			return {}
		var authoritative_zone := ""
		var live_card: Dictionary = {}
		for zone_name in ["hand", "committed_escrow"]:
			var zone := hand if zone_name == "hand" else committed_escrow
			var index := _card_index(zone, card_instance_id)
			if index < 0:
				continue
			authoritative_zone = zone_name
			live_card = (zone[index] as Dictionary).duplicate(true)
			break
		if (
			live_card.is_empty()
			or (
				authoritative_zone == "hand"
				and bool(live_card.get("locked", false))
			)
			or (
				authoritative_zone == "committed_escrow"
				and not bool(live_card.get("locked", false))
			)
		):
			return {}
		var authority_lineage := JSON.stringify({
			"authority": "faithful.fail.once.dbg",
			"owner": owner_id,
		}).sha256_text()
		var immutable_identity := JSON.stringify({
			"authority_lineage": authority_lineage,
			"owner": owner_id,
			"card_instance_id": card_instance_id,
			"card_definition_id": str(live_card.get("definition_id", "")),
		}).sha256_text()
		var lifecycle_evidence := JSON.stringify({
			"immutable_identity": immutable_identity,
			"zone": authoritative_zone,
			"zone_revision": 1,
			"expected_lifecycle": expected_lifecycle,
		}).sha256_text()
		var binding := {
			"schema_id": BINDING_SCHEMA_ID,
			"schema_version": 1,
			"authority_domain_id": "v07.personal_dbg",
			"authority_lineage_fingerprint": authority_lineage,
			"owner_player_id": owner_id,
			"card_instance_id": card_instance_id,
			"card_definition_id": str(live_card.get("definition_id", "")),
			"immutable_identity_fingerprint": immutable_identity,
			"authoritative_zone": authoritative_zone,
			"zone_revision": 1,
			"lifecycle_evidence_fingerprint": lifecycle_evidence,
			"expected_action_lifecycle": expected_lifecycle,
		}
		binding["binding_fingerprint"] = JSON.stringify(binding).sha256_text()
		return binding


	func validate_card_action_binding_v1(
		actor_id: String,
		candidate: Dictionary,
		expected_lifecycle: String
	) -> Dictionary:
		var canonical := authoritative_card_action_binding_v1(
			actor_id,
			str(candidate.get("card_instance_id", "")),
			expected_lifecycle
		)
		var exact_shape := candidate.size() == BINDING_FIELDS.size()
		for field_name in BINDING_FIELDS:
			exact_shape = exact_shape and candidate.has(field_name)
		var accepted := (
			exact_shape
			and not canonical.is_empty()
			and candidate == canonical
		)
		return {
			"accepted": accepted,
			"reason_code": "none" if accepted else "fake_card_binding_invalid",
			"binding": canonical.duplicate(true) if accepted else {},
		}


	func player_projection(actor_id: String) -> Dictionary:
		return {
			"visibility_scope": "viewer_private",
			"viewer_id": actor_id,
			"facts": {
				"hand": hand.duplicate(true),
				"committed_escrow": committed_escrow.duplicate(true),
				"discard": discard.duplicate(true),
				"deck": [],
				"eligible_merge_pairs": [],
			},
		}


	func core_authority_snapshot() -> Dictionary:
		return {"state": authority_state.duplicate(true)}


	func create_authority_intent(
		intent_id: String,
		action_kind: String,
		payload: Dictionary
	) -> Dictionary:
		return {
			"intent_id": intent_id,
			"action_kind": action_kind,
			"payload": payload.duplicate(true),
			"accepted": true,
		}


	func create_intent(
		intent_id: String,
		actor_id: String,
		action_kind: String,
		payload: Dictionary
	) -> Dictionary:
		return {
			"intent_id": intent_id,
			"actor_id": actor_id,
			"action_kind": action_kind,
			"payload": payload.duplicate(true),
			"accepted": true,
		}


	func apply_intent(intent: Dictionary) -> Dictionary:
		apply_count += 1
		var intent_id := str(intent.get("intent_id", ""))
		var action_kind := str(intent.get("action_kind", ""))
		var payload := intent.get("payload", {}) as Dictionary
		var card_instance_id := str(payload.get("instance_id", ""))
		if action_kind == "reserve_card_submission":
			var reserved := _move_card(
				hand,
				committed_escrow,
				card_instance_id,
				true
			)
			return {
				"success": reserved,
				"reason_code": "card_reserved_in_committed_escrow"
					if reserved
					else "card_reservation_not_in_hand",
			}
		if action_kind == "release_card_submission":
			var released := _move_card(
				committed_escrow,
				hand,
				card_instance_id,
				false
			)
			return {
				"success": released,
				"reason_code": "card_released_from_escrow_to_hand"
					if released
					else "card_release_not_in_committed_escrow",
			}
		if action_kind == "play_card" or intent_id.begins_with("intent.play."):
			play_apply_count += 1
			authority_state["play_count"] = int(
				authority_state.get("play_count", 0)
			) + 1
			if fail_play_once:
				fail_play_once = false
				var staged_failure_write := _move_card(
					committed_escrow,
					discard,
					card_instance_id,
					false
				)
				if staged_failure_write:
					failure_zone_mutation_count += 1
				return {
					"success": false,
					"reason_code": "injected_dbg_failure",
				}
			var played := _move_card(
				committed_escrow,
				discard,
				card_instance_id,
				false
			)
			return {
				"success": played,
				"reason_code": "card_resolved_from_escrow_to_discard"
					if played
					else "play_card_not_in_authoritative_source_zone",
			}
		else:
			authority_state["lock_count"] = int(
				authority_state.get("lock_count", 0)
			) + 1
		return {"success": true, "reason_code": "fake_dbg_committed"}


	func _card_index(zone: Array, card_instance_id: String) -> int:
		for index in range(zone.size()):
			if str((zone[index] as Dictionary).get("instance_id", "")) == card_instance_id:
				return index
		return -1


	func _move_card(
		source: Array,
		destination: Array,
		card_instance_id: String,
		locked: bool
	) -> bool:
		var index := _card_index(source, card_instance_id)
		if index < 0:
			return false
		var moved := (source[index] as Dictionary).duplicate(true)
		source.remove_at(index)
		moved["locked"] = locked
		destination.append(moved)
		return true


	func capture_checkpoint_v1() -> Dictionary:
		return {
			"authority_state": authority_state.duplicate(true),
			"hand": hand.duplicate(true),
			"committed_escrow": committed_escrow.duplicate(true),
			"discard": discard.duplicate(true),
		}


	func rollback_v1(checkpoint: Dictionary) -> Dictionary:
		rollback_count += 1
		authority_state = (
			checkpoint.get("authority_state", {}) as Dictionary
		).duplicate(true)
		hand = (checkpoint.get("hand", []) as Array).duplicate(true)
		committed_escrow = (
			checkpoint.get("committed_escrow", []) as Array
		).duplicate(true)
		discard = (checkpoint.get("discard", []) as Array).duplicate(true)
		return {"accepted": true, "reason_code": "fake_dbg_rolled_back"}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_runtime_script = load(
		"res://scripts/v075_runtime/v075_runtime_owner.gd"
	) as Script
	_checkpoint_script = load(
		"res://scripts/v075/combat/v075_combat_checkpoint_v1.gd"
	) as Script
	_batch_core_script = load(
		"res://scripts/v075/runtime/v075_public_action_batch_core.gd"
	) as Script
	_asset_core_script = load(
		"res://scripts/v07_semantic/v07_asset_batch_core.gd"
	) as Script
	_facility_core_script = load(
		"res://scripts/v074/facility/v074_facility_runtime_core.gd"
	) as Script
	_damage_intent_script = load(
		"res://scripts/v075/combat/facility_combat_damage_intent_v1.gd"
	) as Script
	if (
		_runtime_script == null
		or _checkpoint_script == null
		or _batch_core_script == null
		or _asset_core_script == null
		or _facility_core_script == null
		or _damage_intent_script == null
	):
		_expect(false, "resolution rollback dependencies are available")
		_finish()
		return
	_test_asset_failure_rolls_back_once()
	_test_dbg_failure_rolls_back_once()
	_finish()


func _test_asset_failure_rolls_back_once() -> void:
	var fixture := _new_locked_runtime()
	if fixture.is_empty():
		return
	var runtime := fixture.get("runtime") as Node
	var combat := fixture.get("combat") as ResolutionCombatOwner
	var dbg := fixture.get("dbg") as FailingDbgOwner
	var before := _transaction_snapshot(runtime, combat, dbg)
	var runtime_error_before := int(runtime.get("_runtime_error_count"))
	combat.invalid_asset_state_once = true

	var failed := runtime.call("resolve_next_action") as Dictionary
	_expect(
		not bool(failed.get("accepted", false))
			and str(failed.get("reason_code", "")) == "asset_resolution_failed",
		"asset settlement failure is returned through the resolution boundary"
	)
	_expect(
		combat.rollback_count == 1
			and dbg.rollback_count == 1,
		"asset failure invokes Combat and DBG rollback exactly once"
	)
	_expect(
		combat.resolve_count == 1
			and combat.completion_count == 1
			and not combat.invalid_asset_state_once,
		"asset failure is injected once after Combat has staged its receipt"
	)
	_expect(
		_transaction_snapshot(runtime, combat, dbg) == before,
		"asset failure restores runtime, facility, asset, history, telemetry, and presentation state"
	)
	_expect(
		str(runtime.get("_phase")) == "failed"
			and int(runtime.get("_runtime_error_count")) == runtime_error_before + 1,
		"asset failure leaves only one explicit runtime fault envelope"
	)
	_dispose(runtime)


func _test_dbg_failure_rolls_back_once() -> void:
	var fixture := _new_locked_runtime()
	if fixture.is_empty():
		return
	var runtime := fixture.get("runtime") as Node
	var combat := fixture.get("combat") as ResolutionCombatOwner
	var dbg := fixture.get("dbg") as FailingDbgOwner
	var before := _transaction_snapshot(runtime, combat, dbg)
	var runtime_error_before := int(runtime.get("_runtime_error_count"))
	dbg.fail_play_once = true

	var failed := runtime.call("resolve_next_action") as Dictionary
	_expect(
		not bool(failed.get("accepted", false))
			and str(failed.get("reason_code", "")) == "dbg_card_resolution_failed",
		"DBG settlement failure is returned through the resolution boundary"
	)
	_expect(
		dbg.play_apply_count == 1
			and dbg.rollback_count == 1
			and combat.rollback_count == 1,
		"DBG failure rolls back the attempted card write and Combat exactly once"
	)
	_expect(
		not dbg.fail_play_once,
		"DBG failure injection is consumed once"
	)
	_expect(
		dbg.failure_zone_mutation_count == 1,
		"DBG failure mutates committed escrow before transactional rollback"
	)
	_expect(
		_transaction_snapshot(runtime, combat, dbg) == before,
		"DBG failure restores runtime, facility, asset, history, telemetry, and presentation state"
	)
	_expect(
		str(runtime.get("_phase")) == "failed"
			and int(runtime.get("_runtime_error_count")) == runtime_error_before + 1,
		"DBG failure leaves only one explicit runtime fault envelope"
	)
	_dispose(runtime)


func _new_locked_runtime() -> Dictionary:
	var runtime := _runtime_script.new() as Node
	var combat := ResolutionCombatOwner.new(_checkpoint_script)
	runtime.set_meta("combat", combat)
	root.add_child(runtime)
	root.add_child(combat)
	var bound := runtime.call("bind_combat_owner", combat) as Dictionary
	_expect(
		bool(bound.get("accepted", false)),
		"runtime binds the isolated resolution Combat owner"
	)
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
	_expect(
		bool(started.get("accepted", false)),
		"runtime starts the resolution rollback fixture"
	)
	if not bool(started.get("accepted", false)):
		_dispose(runtime)
		return {}

	var local_id := str(runtime.get("_local_player_id"))
	var player_ids := runtime.call("player_ids") as Array
	if local_id.is_empty() or player_ids.is_empty():
		_expect(false, "resolution fixture exposes a local player and roster")
		_dispose(runtime)
		return {}

	var facility := _install_enemy_facility(runtime, local_id, player_ids)
	if facility.is_empty():
		_dispose(runtime)
		return {}
	combat.facility_intent = _damage_intent_script.call(
		"build",
		"effect.resolution.fail.once",
		str(facility.get("facility_id", "")),
		int(facility.get("facility_generation", 0)),
		1,
		"military_region_assault",
		"combat.receipt.resolution.fail.once"
	) as Dictionary
	_expect(
		not combat.facility_intent.is_empty(),
		"resolution fixture builds a typed facility damage intent"
	)

	# Lock empty rival queues first so the synthetic local combat card is only
	# visible while the final local submission crosses into resolution.
	for player_id_variant in player_ids:
		var player_id := str(player_id_variant)
		if player_id == local_id:
			continue
		var rival_lock := runtime.call(
			"lock_player_submission",
			player_id
		) as Dictionary
		_expect(
			bool(rival_lock.get("accepted", false)),
			"empty rival submission locks before the combat resolution fixture"
		)

	var dbg := FailingDbgOwner.new(_military_card(), local_id)
	var dbg_by_player := runtime.get("_dbg_by_player") as Dictionary
	dbg_by_player[local_id] = dbg
	runtime.call("_clear_v075_submission_caches")
	var card_action_binding := runtime.call(
		"_authoritative_card_action_binding",
		local_id,
		str(_military_card().get("instance_id", ""))
	) as Dictionary
	_expect(
		not card_action_binding.is_empty(),
		"resolution fixture uses a strict canonical DBG card binding"
	)
	var candidate: Dictionary = {}
	for option_variant in runtime.call("legal_card_actions", local_id) as Array:
		var option := option_variant as Dictionary
		if (
			str(option.get("action_domain", "")) == "military"
			and str(option.get("task_kind", "")) == "assault_region"
			and str(option.get("target_region_id", ""))
				== str(facility.get("region_id", ""))
		):
			candidate = option.duplicate(true)
			break
	_expect(not candidate.is_empty(), "resolution fixture acquires one typed military candidate")
	var queued := runtime.call(
		"queue_card_action",
		local_id,
		str(_military_card().get("instance_id", "")),
		str(candidate.get("target_slot_id", "")),
		candidate
	) as Dictionary
	_expect(bool(queued.get("accepted", false)), "resolution fixture queues the typed military candidate")

	var local_lock := runtime.call(
		"lock_player_submission",
		local_id
	) as Dictionary
	_expect(
		bool(local_lock.get("accepted", false)),
		"local combat card locks with a full resolution checkpoint"
	)
	_expect(
		str(runtime.get("_phase")) == "resolving",
		"all locked submissions enter the resolution phase"
	)
	if (
		not bool(local_lock.get("accepted", false))
		or str(runtime.get("_phase")) != "resolving"
	):
		_dispose(runtime)
		return {}
	return {"runtime": runtime, "combat": combat, "dbg": dbg}


func _install_enemy_facility(
	runtime: Node,
	local_id: String,
	player_ids: Array
) -> Dictionary:
	var slots := (runtime.get("_facility_slots") as Array).duplicate(true)
	if slots.is_empty():
		_expect(false, "resolution fixture exposes facility slots")
		return {}
	var original := slots[0] as Dictionary
	var enemy_id := "player.enemy"
	for player_id_variant in player_ids:
		var candidate := str(player_id_variant)
		if candidate != local_id:
			enemy_id = candidate
			break
	var occupied := _facility_core_script.call(
		"build_occupied_slot",
		str(original.get("region_id", "")),
		int(original.get("region_revision", 0)),
		str(original.get("facility_type", "factory")),
		str(original.get("industry_id", "life")),
		int(original.get("slot_generation", 0)),
		"facility.resolution.fail.once",
		1,
		enemy_id,
		1,
		0,
		0,
		"sunlit"
	) as Dictionary
	_expect(
		not occupied.is_empty(),
		"resolution fixture creates one public enemy facility"
	)
	if occupied.is_empty():
		return {}
	for index in range(slots.size()):
		var slot := slots[index] as Dictionary
		if str(slot.get("slot_id", "")) == str(occupied.get("slot_id", "")):
			slots[index] = occupied.duplicate(true)
			break
	var replaced := _batch_core_script.call(
		"replace_facility_slots",
		runtime.get("_facility_state"),
		slots
	) as Dictionary
	_expect(
		not replaced.is_empty(),
		"resolution fixture keeps a valid facility batch after the enemy slot insert"
	)
	if replaced.is_empty():
		return {}
	runtime.set("_facility_state", replaced)
	runtime.call("_sync_facility_slots")
	return occupied


func _military_card() -> Dictionary:
	return {
		"instance_id": "card.resolution.fail.once.military",
		"definition_id": "military.planetary_defense_force.life.rank_1",
		"card_type": "military.planetary_defense_force",
		"primary_color": "life",
		"primary_asset_cost": 0,
		"secondary_asset_cost": 0,
		"any_asset_cost": 0,
		"origin_class": "standard",
		"level": 1,
		"rank": 1,
	}


func _transaction_snapshot(
	runtime: Node,
	combat: ResolutionCombatOwner,
	dbg: FailingDbgOwner
) -> Dictionary:
	var telemetry := runtime.get("_combat_telemetry_bridge") as Object
	var presentation := runtime.get("_combat_presentation_consumer") as Object
	return {
		"asset_state": (runtime.get("_asset_state") as Dictionary).duplicate(true),
		"asset_balances": (runtime.get("_asset_balances") as Dictionary).duplicate(true),
		"facility_state": (runtime.get("_facility_state") as Dictionary).duplicate(true),
		"facility_slots": (runtime.get("_facility_slots") as Array).duplicate(true),
		"queued_by_player": (runtime.get("_queued_by_player") as Dictionary).duplicate(true),
		"locked_by_player": (runtime.get("_locked_by_player") as Dictionary).duplicate(true),
		"public_history": (runtime.get("_public_history") as Array).duplicate(true),
		"public_progress_points": int(runtime.get("_public_progress_points")),
		"facility_damage_bridge_state": (
			(runtime.get("_facility_damage_bridge_state") as Dictionary).duplicate(true)
		),
		"processed_facility_damage_intents": (
			(runtime.get("_processed_facility_damage_intents") as Dictionary).duplicate(true)
		),
		"combat_public_history": (
			(runtime.get("_combat_public_history") as Array).duplicate(true)
		),
		"combat_public_receipt_count": int(runtime.get("_combat_public_receipt_count")),
		"combat_facility_damage_receipt_count": int(
			runtime.get("_combat_facility_damage_receipt_count")
		),
		"telemetry_debug": telemetry.call("debug_snapshot") as Dictionary,
		"telemetry_events": telemetry.call("recent_events", 100) as Array,
		"presentation_debug": presentation.call("debug_snapshot") as Dictionary,
		"presentation_cues": presentation.call("recent_cues", 100) as Array,
		"combat_state": combat.state_snapshot(),
		"dbg_state": dbg.authority_state.duplicate(true),
		"dbg_hand": dbg.hand.duplicate(true),
		"dbg_committed_escrow": dbg.committed_escrow.duplicate(true),
		"dbg_discard": dbg.discard.duplicate(true),
		"dbg_binding": dbg.authoritative_card_action_binding_v1(
			dbg.owner_id,
			str(dbg.card.get("instance_id", "")),
			FailingDbgOwner.BINDING_LIFECYCLE_ID
		),
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
		"V075_COMBAT_RESOLUTION_FAIL_ONCE_TEST|%s"
		% JSON.stringify({
			"status": "PASS" if _failures.is_empty() else "FAIL",
			"passed": _checks - _failures.size(),
			"total": _checks,
			"failures": _failures,
		})
	)
	quit(0 if _failures.is_empty() else 1)
