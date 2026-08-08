extends Node
class_name V075ApplicationFlow

signal projection_changed(snapshot: Dictionary)
signal receipt_ready(receipt: Dictionary)
signal owner_private_receipt_ready(receipt: Dictionary)
signal final_settlement_presented(settlement: Dictionary)
signal runtime_fault_presented(receipt: Dictionary)
signal public_resolution_ready(receipt: Dictionary)
signal playtest_observation_ready(receipt: Dictionary)

const RULESET_ID := "v0.7.5"
const SAMPLE_MODE_ID := "NEW_V075_GAME"
const DEFAULT_SEED := 900626424
const CUTOVER_DOMAIN_COUNT := 29
const PRIVATE_SKILL_INTENT_KIND := "combat.monster_private_skill.request"

@onready var _ruleset_owner: Node = %V075RulesetRuntimeOwner
@onready var _runtime_owner: Node = %V075RuntimeOwner
@onready var _combat_owner: Node = %V075CombatRuntimeOwner
@onready var _combat_telemetry: Node = %V075CombatTelemetryService

var _intent_sequence := 0
var _session_sequence := 0
var _last_receipt: Dictionary = {}
var _composition_ready := false
var _private_skill_issue_count := 0
var _private_skill_submit_count := 0
var _private_skill_owner_receipt_count := 0


func _ready() -> void:
	var telemetry_binding := _runtime_owner.call(
		"bind_combat_telemetry_service",
		_combat_telemetry
	) as Dictionary
	var combat_binding := _runtime_owner.call(
		"bind_combat_owner",
		_combat_owner
	) as Dictionary
	if (
		not bool(telemetry_binding.get("accepted", false))
		or not bool(combat_binding.get("accepted", false))
	):
		push_error("V075 runtime composition binding failed")
		return
	_runtime_owner.state_changed.connect(_on_runtime_state_changed)
	_runtime_owner.final_settlement_committed.connect(
		_on_final_settlement_committed
	)
	_runtime_owner.runtime_fault.connect(_on_runtime_fault)
	_runtime_owner.resolution_presented.connect(
		_on_public_resolution_presented
	)
	_runtime_owner.playtest_observation_ready.connect(
		_on_playtest_observation_ready
	)
	_composition_ready = true


func submit_intent(intent: Dictionary) -> Dictionary:
	var intent_id := str(intent.get("intent_id", "")).strip_edges()
	var intent_kind := str(intent.get("intent_kind", "")).strip_edges()
	var parameters := intent.get("parameters", {}) as Dictionary
	if intent_id.is_empty() or intent_kind.is_empty():
		return _publish_intent_rejection(
			intent_id,
			intent_kind,
			parameters,
			"typed_intent_identity_invalid"
		)
	if not _composition_ready:
		return _publish_intent_rejection(
			intent_id,
			intent_kind,
			parameters,
			"v075_runtime_composition_not_ready"
		)
	var actor_id := str(_runtime_owner.call("local_player_id"))
	var result: Dictionary
	match intent_kind:
		"map.preview":
			result = _preview_map(parameters)
		"new_game.start":
			result = _start_new_game(parameters)
		"track.acquire":
			result = _runtime_owner.call(
				"acquire_track_item",
				actor_id,
				str(parameters.get("source_instance_id", ""))
			) as Dictionary
		"track.set_stance":
			result = _runtime_owner.call(
				"set_track_stance",
				actor_id,
				str(parameters.get("increase_color", "")),
				str(parameters.get("decrease_color", ""))
			) as Dictionary
		"card.queue":
			result = _runtime_owner.call(
				"queue_card_action",
				actor_id,
				str(parameters.get("card_instance_id", "")),
				str(parameters.get("target_slot_id", "")),
				parameters.get("target_binding", {}) as Dictionary
			) as Dictionary
		"queue.reorder":
			result = _runtime_owner.call(
				"reorder_queued_action",
				actor_id,
				int(parameters.get("from_index", -1)),
				int(parameters.get("to_index", -1))
			) as Dictionary
		"queue.remove":
			result = _runtime_owner.call(
				"remove_queued_action",
				actor_id,
				str(parameters.get("action_id", ""))
			) as Dictionary
		"submission.lock":
			result = _runtime_owner.call(
				"lock_player_submission",
				actor_id
			) as Dictionary
		"merge.normal":
			result = _runtime_owner.call(
				"merge_normal_pair",
				actor_id,
				str(parameters.get("left_instance_id", "")),
				str(parameters.get("right_instance_id", ""))
			) as Dictionary
		"maintenance.finish":
			result = _runtime_owner.call(
				"finish_maintenance",
				actor_id
			) as Dictionary
		"sample.accelerate":
			result = _runtime_owner.call(
				"run_accelerated_until_settled",
				int(parameters.get("max_steps", 2000))
			) as Dictionary
		PRIVATE_SKILL_INTENT_KIND:
			_private_skill_submit_count += 1
			result = _runtime_owner.call(
				"request_private_monster_skill",
				actor_id,
				parameters
			) as Dictionary
		"combat.military_mission.select":
			result = _runtime_owner.call(
				"queue_selected_military_mission",
				actor_id,
				str(parameters.get("task_kind", "")),
				parameters
			) as Dictionary
		"persistence.save":
			result = _ruleset_owner.call(
				"request_save",
				intent_id
			) as Dictionary
		"persistence.continue":
			result = _ruleset_owner.call(
				"request_load",
				intent_id
			) as Dictionary
		_:
			result = _reject(
				intent_id,
				intent_kind,
				"typed_intent_kind_unsupported"
			)
	if intent_kind == PRIVATE_SKILL_INTENT_KIND:
		return _publish_owner_private_receipt(
			_bind_owner_private_skill_receipt(
				intent_id,
				intent_kind,
				actor_id,
				parameters,
				result
			)
		)
	return _publish_receipt(_bind_receipt(intent_id, intent_kind, result))


func issue_intent(intent_kind: String, parameters: Dictionary = {}) -> Dictionary:
	_intent_sequence += 1
	if intent_kind == PRIVATE_SKILL_INTENT_KIND:
		_private_skill_issue_count += 1
	return {
		"schema": "V075ApplicationIntentV1",
		"intent_id": "intent.v075.sample.%06d" % _intent_sequence,
		"intent_kind": intent_kind,
		"ruleset_id": RULESET_ID,
		"parameters": parameters.duplicate(true),
	}


func local_snapshot() -> Dictionary:
	var actor_id := str(_runtime_owner.call("local_player_id"))
	return (
		_runtime_owner.call("player_snapshot", actor_id) as Dictionary
		if not actor_id.is_empty()
		else {}
	)


func planet_map_view_payload(
	selected_card_instance_id := "",
	selected_region_id := ""
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


func combat_presentation_consumer() -> Node:
	return _runtime_owner.call("combat_presentation_consumer") as Node


func debug_snapshot() -> Dictionary:
	var runtime_debug := _runtime_owner.call("debug_snapshot") as Dictionary
	var telemetry_debug := _combat_telemetry.call(
		"debug_snapshot"
	) as Dictionary
	return {
		"schema": "V075RuntimeCompositionDebugV1",
		"ruleset_id": RULESET_ID,
		"sample_mode_id": SAMPLE_MODE_ID,
		"current_production_runtime_ruleset": RULESET_ID,
		"composition_ready": _composition_ready,
		"ruleset_owner_count": 1,
		"gameplay_owner_count": 1,
		"combat_runtime_owner_count": int(
			runtime_debug.get("combat_runtime_owner_count", 0)
		),
		"combat_state_writer_count": int(
			runtime_debug.get("combat_state_writer_count", 0)
		),
		"combat_telemetry_service_count": 1,
		"combat_telemetry_gameplay_owner_count": int(
			telemetry_debug.get("gameplay_owner_count", -1)
		),
		"v06_production_rule_owner_count": 0,
		"old_monster_controller_production_reachable_count": 0,
		"old_military_controller_production_reachable_count": 0,
		"combat_dual_write_count": 0,
		"combat_legacy_fallback_count": 0,
		"mixed_ruleset_state_count": 0,
		"save_adapter_connected": false,
		"save_resume_enabled": false,
		"cutover_domain_count": CUTOVER_DOMAIN_COUNT,
		"connected_domain_count": int(
			runtime_debug.get("connected_domain_count", 0)
		),
		"ruleset": _ruleset_owner.call("debug_snapshot"),
		"runtime": runtime_debug,
		"combat_telemetry": telemetry_debug,
		"last_receipt": _last_receipt.duplicate(true),
		"private_skill_issue_count": _private_skill_issue_count,
		"private_skill_submit_count": _private_skill_submit_count,
		"private_skill_owner_receipt_count": (
			_private_skill_owner_receipt_count
		),
	}


func _preview_map(parameters: Dictionary) -> Dictionary:
	var normalized := _ruleset_owner.call(
		"normalize_map_request",
		_map_request_from_parameters(parameters)
	) as Dictionary
	if not bool(normalized.get("accepted", false)):
		return normalized
	var map_request := normalized.get("request", {}) as Dictionary
	var preview := _runtime_owner.call("preview_map", map_request) as Dictionary
	if not bool(preview.get("accepted", false)):
		return preview
	return {
		"accepted": true,
		"reason_code": "v075_map_preview_generated",
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
	var session_id := "session.v075.sample.%06d" % _session_sequence
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
		"reason_code": "v075_new_game_application_flow_committed",
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
		"combat_balance_profile_id": str(
			started.get("combat_balance_profile_id", "")
		),
		"combat_balance_profile_fingerprint": str(
			started.get("combat_balance_profile_fingerprint", "")
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
	receipt["schema"] = "V075ApplicationReceiptV1"
	receipt["intent_id"] = intent_id
	receipt["intent_kind"] = intent_kind
	receipt["ruleset_id"] = RULESET_ID
	return receipt


func _publish_receipt(receipt: Dictionary) -> Dictionary:
	_last_receipt = receipt.duplicate(true)
	receipt_ready.emit(receipt.duplicate(true))
	return receipt


func _publish_intent_rejection(
	intent_id: String,
	intent_kind: String,
	parameters: Dictionary,
	reason_code: String
) -> Dictionary:
	var rejection := _reject(intent_id, intent_kind, reason_code)
	if intent_kind == PRIVATE_SKILL_INTENT_KIND:
		return _publish_owner_private_receipt(
			_bind_owner_private_skill_receipt(
				intent_id,
				intent_kind,
				"",
				parameters,
				rejection
			)
		)
	return _publish_receipt(rejection)


func _bind_owner_private_skill_receipt(
	intent_id: String,
	intent_kind: String,
	actor_id: String,
	parameters: Dictionary,
	result: Dictionary
) -> Dictionary:
	var accepted := bool(result.get("accepted", false))
	return {
		"schema": "V075OwnerPrivateApplicationReceiptV1",
		"accepted": accepted,
		"reason_code": str(result.get(
			"reason_code",
			"private_skill_request_rejected"
		)),
		"event_kind": (
			"monster_private_skill_requested"
			if accepted
			else "monster_private_skill_request_rejected"
		),
		"combat_channel": "private_instant_serial",
		"receipt_scope": "owner_private",
		"request_status": "accepted" if accepted else "rejected",
		"owner_player_id": actor_id,
		"source_instance_id": str(parameters.get(
			"source_instance_id",
			""
		)),
		"skill_definition_id": str(parameters.get(
			"skill_definition_id",
			""
		)),
		"intent_id": intent_id,
		"intent_kind": intent_kind,
		"ruleset_id": RULESET_ID,
	}


func _publish_owner_private_receipt(receipt: Dictionary) -> Dictionary:
	_private_skill_owner_receipt_count += 1
	_last_receipt = {
		"schema": "V075ApplicationReceiptRedactionV1",
		"accepted": bool(receipt.get("accepted", false)),
		"receipt_scope": "owner_private_redacted",
		"ruleset_id": RULESET_ID,
	}
	owner_private_receipt_ready.emit(receipt.duplicate(true))
	return receipt


func _reject(
	intent_id: String,
	intent_kind: String,
	reason_code: String
) -> Dictionary:
	return {
		"schema": "V075ApplicationReceiptV1",
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
