extends Node
class_name V073SampleApplicationFlow

signal projection_changed(snapshot: Dictionary)
signal receipt_ready(receipt: Dictionary)
signal final_settlement_presented(settlement: Dictionary)
signal runtime_fault_presented(receipt: Dictionary)
signal public_resolution_ready(receipt: Dictionary)
signal playtest_observation_ready(receipt: Dictionary)
# MCP_FINALIZE

const RULESET_ID := "v0.7.3"
const SAMPLE_MODE_ID := "NEW_V073_GAME"
const DEFAULT_SEED := 730045
const HUMAN_BASELINE := preload(
	"res://scripts/playtest/v073_human_baseline_profile.gd"
)

@onready var _ruleset_owner: Node = %V073RulesetRuntimeOwner
@onready var _runtime_owner: Node = %V073SampleRuntimeOwner

var _intent_sequence := 0
var _session_sequence := 0
var _last_receipt: Dictionary = {}


func _ready() -> void:
	_runtime_owner.state_changed.connect(_on_runtime_state_changed)
	_runtime_owner.final_settlement_committed.connect(
		_on_final_settlement_committed
	)
	_runtime_owner.runtime_fault.connect(_on_runtime_fault)
	_runtime_owner.resolution_presented.connect(_on_public_resolution_presented)
	_runtime_owner.playtest_observation_ready.connect(
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
		"new_game.start":
			result = _start_new_game(parameters)
		"track.acquire":
			result = _runtime_owner.acquire_track_item(
				_runtime_owner.local_player_id(),
				str(parameters.get("source_instance_id", ""))
			)
		"track.set_stance":
			result = _runtime_owner.set_track_stance(
				_runtime_owner.local_player_id(),
				str(parameters.get("increase_color", "")),
				str(parameters.get("decrease_color", ""))
			)
		"card.queue":
			result = _runtime_owner.queue_card_action(
				_runtime_owner.local_player_id(),
				str(parameters.get("card_instance_id", "")),
				str(parameters.get("target_slot_id", ""))
			)
		"queue.reorder":
			result = _runtime_owner.reorder_queued_action(
				_runtime_owner.local_player_id(),
				int(parameters.get("from_index", -1)),
				int(parameters.get("to_index", -1))
			)
		"queue.remove":
			result = _runtime_owner.remove_queued_action(
				_runtime_owner.local_player_id(),
				str(parameters.get("action_id", ""))
			)
		"submission.lock":
			result = _runtime_owner.lock_player_submission(
				_runtime_owner.local_player_id()
			)
		"merge.normal":
			result = _runtime_owner.merge_normal_pair(
				_runtime_owner.local_player_id(),
				str(parameters.get("left_instance_id", "")),
				str(parameters.get("right_instance_id", ""))
			)
		"maintenance.finish":
			result = _runtime_owner.finish_maintenance(
				_runtime_owner.local_player_id()
			)
		"sample.accelerate":
			result = _runtime_owner.run_accelerated_until_settled(
				int(parameters.get("max_steps", 2000))
			)
		"persistence.save":
			result = _ruleset_owner.request_save(intent_id)
		"persistence.continue":
			result = _ruleset_owner.request_load(intent_id)
		_:
			result = _reject(intent_id, intent_kind, "typed_intent_kind_unsupported")
	return _publish_receipt(_bind_receipt(intent_id, intent_kind, result))


func issue_intent(intent_kind: String, parameters: Dictionary = {}) -> Dictionary:
	_intent_sequence += 1
	return {
		"schema": "V073SampleApplicationIntentV1",
		"intent_id": "intent.v073.sample.%06d" % _intent_sequence,
		"intent_kind": intent_kind,
		"ruleset_id": RULESET_ID,
		"parameters": parameters.duplicate(true),
	}


func local_snapshot() -> Dictionary:
	if _runtime_owner.local_player_id().is_empty():
		return {}
	return _runtime_owner.player_snapshot(_runtime_owner.local_player_id())


func identity_snapshot() -> Dictionary:
	return _ruleset_owner.identity_snapshot()


func capability_snapshot() -> Dictionary:
	return _ruleset_owner.capability_snapshot()


func debug_snapshot() -> Dictionary:
	return {
		"schema": "V073RuntimeCompositionDebugV1",
		"ruleset_id": RULESET_ID,
		"sample_mode_id": SAMPLE_MODE_ID,
		"current_production_runtime_ruleset": RULESET_ID,
		"ruleset_owner_count": 1,
		"gameplay_owner_count": 1,
		"player_adapter_connected": bool(
			_runtime_owner.debug_snapshot().get("player_adapter_connected", false)
		),
		"ai_adapter_connected": bool(
			_runtime_owner.debug_snapshot().get("ai_adapter_connected", false)
		),
		"v06_production_rule_owner_count": 0,
		"v06_production_ai_policy_count": 0,
		"v06_production_player_projection_count": 0,
		"v06_production_card_supply_count": 0,
		"v06_production_resolution_order_count": 0,
		"v06_production_asset_refresh_count": 0,
		"v06_public_bid_production_reference_count": 0,
		"v06_auction_timer_production_reference_count": 0,
		"v06_region_supply_purchase_surface_count": 0,
		"v06_right_permanent_panel_count": 0,
		"dual_write_count": 0,
		"legacy_fallback_count": 0,
		"mixed_ruleset_state_count": 0,
		"save_adapter_connected": false,
		"save_resume_enabled": false,
		"ruleset": _ruleset_owner.debug_snapshot(),
		"runtime": _runtime_owner.debug_snapshot(),
		"last_receipt": _last_receipt.duplicate(true),
	}


func _start_new_game(parameters: Dictionary) -> Dictionary:
	var player_count := int(parameters.get("player_count", 4))
	var seed_value := int(parameters.get("seed", DEFAULT_SEED))
	_session_sequence += 1
	var session_id := "session.v073.sample.%06d" % _session_sequence
	var activation: Dictionary = _ruleset_owner.activate_for_new_game(
		session_id,
		player_count,
		1
	)
	if not bool(activation.get("accepted", false)):
		return activation
	var started: Dictionary = _runtime_owner.start_new_game(
		player_count,
		seed_value,
		false,
		false
	)
	if not bool(started.get("accepted", false)):
		return started
	return {
		"accepted": true,
		"reason_code": "v073_new_game_application_flow_committed",
		"ruleset_id": RULESET_ID,
		"sample_mode_id": SAMPLE_MODE_ID,
		"player_count": player_count,
		"local_human_count": 1,
		"ai_player_count": player_count - 1,
		"session_id": session_id,
		"match_id": str(started.get("match_id", "")),
		"seed": seed_value,
		"balance_profile_id": HUMAN_BASELINE.PROFILE_ID,
		"balance_profile_fingerprint": HUMAN_BASELINE.PROFILE_FINGERPRINT,
	}


func _bind_receipt(
	intent_id: String,
	intent_kind: String,
	result: Dictionary
) -> Dictionary:
	var receipt := result.duplicate(true)
	receipt["schema"] = "V073SampleApplicationReceiptV1"
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
		"schema": "V073SampleApplicationReceiptV1",
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
