extends Node
class_name V074ApplicationFlow

signal projection_changed(snapshot: Dictionary)
signal receipt_ready(receipt: Dictionary)
signal final_settlement_presented(settlement: Dictionary)
signal runtime_fault_presented(receipt: Dictionary)
signal public_resolution_ready(receipt: Dictionary)
signal playtest_observation_ready(receipt: Dictionary)

const RULESET_ID := "v0.7.4"
const SAMPLE_MODE_ID := "NEW_V074_GAME"
const DEFAULT_SEED := 900626424

@onready var _ruleset_owner: Node = %V074RulesetRuntimeOwner
@onready var _runtime_owner: Node = %V074RuntimeOwner

var _intent_sequence := 0
var _session_sequence := 0
var _last_receipt: Dictionary = {}


func _ready() -> void:
	_runtime_owner.connect("state_changed", _on_runtime_state_changed)
	_runtime_owner.connect(
		"final_settlement_committed",
		_on_final_settlement_committed
	)
	_runtime_owner.connect("runtime_fault", _on_runtime_fault)
	_runtime_owner.connect(
		"resolution_presented",
		_on_public_resolution_presented
	)
	_runtime_owner.connect(
		"playtest_observation_ready",
		_on_playtest_observation_ready
	)


func submit_intent(intent: Dictionary) -> Dictionary:
	var intent_id := str(intent.get("intent_id", "")).strip_edges()
	var intent_kind := str(intent.get("intent_kind", "")).strip_edges()
	var parameters := intent.get("parameters", {}) as Dictionary
	if intent_id.is_empty() or intent_kind.is_empty():
		return _publish_receipt(_reject(
			intent_id,
			intent_kind,
			"typed_intent_identity_invalid"
		))
	var result: Dictionary
	match intent_kind:
		"map.preview":
			result = _preview_map(parameters)
		"new_game.start":
			result = _start_new_game(parameters)
		"track.acquire":
			result = _runtime_owner.call(
				"acquire_track_item",
				_runtime_owner.call("local_player_id"),
				str(parameters.get("source_instance_id", ""))
			) as Dictionary
		"track.set_stance":
			result = _runtime_owner.call(
				"set_track_stance",
				_runtime_owner.call("local_player_id"),
				str(parameters.get("increase_color", "")),
				str(parameters.get("decrease_color", ""))
			) as Dictionary
		"card.queue":
			result = _runtime_owner.call(
				"queue_card_action",
				_runtime_owner.call("local_player_id"),
				str(parameters.get("card_instance_id", "")),
				str(parameters.get("target_slot_id", "")),
				(parameters.get("target_binding", {}) as Dictionary)
			) as Dictionary
		"queue.reorder":
			result = _runtime_owner.call(
				"reorder_queued_action",
				_runtime_owner.call("local_player_id"),
				int(parameters.get("from_index", -1)),
				int(parameters.get("to_index", -1))
			) as Dictionary
		"queue.remove":
			result = _runtime_owner.call(
				"remove_queued_action",
				_runtime_owner.call("local_player_id"),
				str(parameters.get("action_id", ""))
			) as Dictionary
		"submission.lock":
			result = _runtime_owner.call(
				"lock_player_submission",
				_runtime_owner.call("local_player_id")
			) as Dictionary
		"merge.normal":
			result = _runtime_owner.call(
				"merge_normal_pair",
				_runtime_owner.call("local_player_id"),
				str(parameters.get("left_instance_id", "")),
				str(parameters.get("right_instance_id", ""))
			) as Dictionary
		"maintenance.finish":
			result = _runtime_owner.call(
				"finish_maintenance",
				_runtime_owner.call("local_player_id")
			) as Dictionary
		"sample.accelerate":
			result = _runtime_owner.call(
				"run_accelerated_until_settled",
				int(parameters.get("max_steps", 2000))
			) as Dictionary
		"persistence.save":
			result = _ruleset_owner.call("request_save", intent_id) as Dictionary
		"persistence.continue":
			result = _ruleset_owner.call("request_load", intent_id) as Dictionary
		_:
			result = _reject(
				intent_id,
				intent_kind,
				"typed_intent_kind_unsupported"
			)
	return _publish_receipt(_bind_receipt(intent_id, intent_kind, result))


func issue_intent(
	intent_kind: String,
	parameters: Dictionary = {}
) -> Dictionary:
	_intent_sequence += 1
	return {
		"schema": "V074ApplicationIntentV1",
		"intent_id": "intent.v074.sample.%06d" % _intent_sequence,
		"intent_kind": intent_kind,
		"ruleset_id": RULESET_ID,
		"parameters": parameters.duplicate(true),
	}


func local_snapshot() -> Dictionary:
	var local_player_id := str(_runtime_owner.call("local_player_id"))
	if local_player_id.is_empty():
		return {}
	return _runtime_owner.call(
		"player_snapshot",
		local_player_id
	) as Dictionary


func planet_map_view_payload(
	selected_card_instance_id: String = "",
	selected_region_id: String = ""
) -> Dictionary:
	return _runtime_owner.call(
		"planet_map_view_payload",
		_runtime_owner.call("local_player_id"),
		selected_card_instance_id,
		selected_region_id
	) as Dictionary


func region_popup(region_id: String) -> Dictionary:
	return _runtime_owner.call("region_popup", region_id) as Dictionary


func resolve_map_target(
	card_instance_id: String,
	region_id: String,
	facility_type: String,
	industry_id: String,
	action_mode: String
) -> Dictionary:
	return _runtime_owner.call(
		"resolve_map_target",
		card_instance_id,
		region_id,
		facility_type,
		industry_id,
		action_mode
	) as Dictionary


func identity_snapshot() -> Dictionary:
	return _ruleset_owner.call("identity_snapshot") as Dictionary


func capability_snapshot() -> Dictionary:
	return _ruleset_owner.call("capability_snapshot") as Dictionary


func debug_snapshot() -> Dictionary:
	var runtime_debug := _runtime_owner.call("debug_snapshot") as Dictionary
	return {
		"schema": "V074RuntimeCompositionDebugV1",
		"ruleset_id": RULESET_ID,
		"sample_mode_id": SAMPLE_MODE_ID,
		"current_production_runtime_ruleset": RULESET_ID,
		"ruleset_owner_count": 1,
		"gameplay_owner_count": 1,
		"map_genesis_owner_count": int(
			runtime_debug.get("map_genesis_owner_count", 0)
		),
		"map_genesis_rng_owner_count": int(
			runtime_debug.get("map_genesis_rng_owner_count", 0)
		),
		"player_adapter_connected": bool(
			runtime_debug.get("player_adapter_connected", false)
		),
		"ai_adapter_connected": bool(
			runtime_debug.get("ai_adapter_connected", false)
		),
		"v06_production_rule_owner_count": 0,
		"v06_production_ai_policy_count": 0,
		"dual_write_count": 0,
		"map_dual_write_count": 0,
		"warehouse_dual_write_count": 0,
		"legacy_fallback_count": 0,
		"fixed_six_region_fallback_count": 0,
		"factory_market_only_fallback_count": 0,
		"mixed_ruleset_state_count": 0,
		"save_adapter_connected": false,
		"save_resume_enabled": false,
		"cutover_domain_count": 15,
		"connected_domain_count": int(
			runtime_debug.get("connected_domain_count", 0)
		),
		"ruleset": _ruleset_owner.call("debug_snapshot"),
		"runtime": runtime_debug,
		"last_receipt": _last_receipt.duplicate(true),
	}


func _preview_map(parameters: Dictionary) -> Dictionary:
	var normalized := _ruleset_owner.call(
		"normalize_map_request",
		_map_request_from_parameters(parameters)
	) as Dictionary
	if not bool(normalized.get("accepted", false)):
		return normalized
	var map_request := normalized.get("request", {}) as Dictionary
	var preview := _runtime_owner.call(
		"preview_map",
		map_request
	) as Dictionary
	if not bool(preview.get("accepted", false)):
		return preview
	return {
		"accepted": true,
		"reason_code": "v074_map_preview_generated",
		"ruleset_id": RULESET_ID,
		"map_request": map_request.duplicate(true),
		"map_genesis_receipt": (
			preview.get("map_genesis_receipt", {}) as Dictionary
		).duplicate(true),
	}


func _start_new_game(parameters: Dictionary) -> Dictionary:
	var player_count := int(parameters.get("player_count", 4))
	var seed_value := int(parameters.get("seed", DEFAULT_SEED))
	var normalized := _ruleset_owner.call(
		"normalize_map_request",
		_map_request_from_parameters(parameters)
	) as Dictionary
	if not bool(normalized.get("accepted", false)):
		return normalized
	var map_request := normalized.get("request", {}) as Dictionary
	_session_sequence += 1
	var session_id := "session.v074.sample.%06d" % _session_sequence
	var activation := _ruleset_owner.call(
		"activate_for_new_game",
		session_id,
		player_count,
		1,
		map_request
	) as Dictionary
	if not bool(activation.get("accepted", false)):
		return activation
	var started := _runtime_owner.call(
		"start_new_game",
		player_count,
		seed_value,
		false,
		false,
		map_request
	) as Dictionary
	if not bool(started.get("accepted", false)):
		return started
	return {
		"accepted": true,
		"reason_code": "v074_new_game_application_flow_committed",
		"ruleset_id": RULESET_ID,
		"sample_mode_id": SAMPLE_MODE_ID,
		"player_count": player_count,
		"local_human_count": 1,
		"ai_player_count": player_count - 1,
		"session_id": session_id,
		"match_id": str(started.get("match_id", "")),
		"seed": seed_value,
		"map_seed": int(map_request.get("map_seed", 0)),
		"region_count": int(map_request.get("region_count", 0)),
		"geography_complexity": str(
			map_request.get("geography_complexity", "")
		),
		"land_ocean_profile": str(
			map_request.get("land_ocean_profile", "")
		),
		"map_fingerprint": str(started.get("map_fingerprint", "")),
		"balance_profile_id": str(
			started.get("balance_profile_id", "")
		),
		"balance_profile_fingerprint": str(
			started.get("balance_profile_fingerprint", "")
		),
	}


func _map_request_from_parameters(parameters: Dictionary) -> Dictionary:
	return {
		"map_seed": int(parameters.get(
			"map_seed",
			parameters.get("seed", DEFAULT_SEED)
		)),
		"region_count": int(parameters.get("region_count", 16)),
		"geography_complexity": str(
			parameters.get("geography_complexity", "STANDARD")
		),
		"land_ocean_profile": str(
			parameters.get("land_ocean_profile", "BALANCED")
		),
	}


func _bind_receipt(
	intent_id: String,
	intent_kind: String,
	result: Dictionary
) -> Dictionary:
	var receipt := result.duplicate(true)
	receipt["schema"] = "V074ApplicationReceiptV1"
	receipt["intent_id"] = intent_id
	receipt["intent_kind"] = intent_kind
	receipt["ruleset_id"] = RULESET_ID
	return receipt


func _publish_receipt(receipt: Dictionary) -> Dictionary:
	_last_receipt = receipt.duplicate(true)
	receipt_ready.emit(receipt.duplicate(true))
	return receipt


func _reject(
	intent_id: String,
	intent_kind: String,
	reason_code: String
) -> Dictionary:
	return {
		"schema": "V074ApplicationReceiptV1",
		"accepted": false,
		"reason_code": reason_code,
		"intent_id": intent_id,
		"intent_kind": intent_kind,
		"ruleset_id": RULESET_ID,
	}


func _on_runtime_state_changed(snapshot: Dictionary) -> void:
	projection_changed.emit(snapshot.duplicate(true))


func _on_final_settlement_committed(settlement: Dictionary) -> void:
	final_settlement_presented.emit(settlement.duplicate(true))


func _on_runtime_fault(receipt: Dictionary) -> void:
	runtime_fault_presented.emit(receipt.duplicate(true))


func _on_public_resolution_presented(receipt: Dictionary) -> void:
	public_resolution_ready.emit(receipt.duplicate(true))


func _on_playtest_observation_ready(receipt: Dictionary) -> void:
	playtest_observation_ready.emit(receipt.duplicate(true))
