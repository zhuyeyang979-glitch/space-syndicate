extends SceneTree

const INVENTORY_SCENE := preload("res://scenes/runtime/CommodityCardInventoryRuntimeController.tscn")
const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")

class StatePortFixture:
	extends Node

	var saved := {"state_version": 1, "ruleset_id": "v0.6", "journal": {}, "next_reservation_sequence": 1}
	var checkpoint := _checkpoint()

	func actor_player_indices() -> Dictionary: return {}
	func register_player(_actor_id: String, _state: Dictionary) -> Dictionary: return {"configured": true}
	func read_player(_actor_id: String) -> Dictionary: return {"found": false}
	func reserve_transaction(_transaction_id: String, _intent_hash: String, _expected: Dictionary, _actors: Array) -> Dictionary: return {"reserved": false}
	func prepare_reserved_mutations(_reservation: Dictionary, _mutations: Dictionary) -> Dictionary: return {"prepared": false}
	func commit_reserved(_reservation: Dictionary, _receipt: Dictionary = {}) -> Dictionary: return {"committed": false}
	func abort_reserved(_reservation: Dictionary) -> Dictionary: return {"aborted": true}
	func to_save_data() -> Dictionary: return saved.duplicate(true)
	func preflight_save_data(data: Dictionary) -> Dictionary:
		return {"accepted": data.get("journal") is Dictionary, "normalized_state": data.duplicate(true), "reason_code": "fixture_state_valid"}
	func apply_save_data(data: Dictionary) -> Dictionary:
		saved = data.duplicate(true)
		return {"applied": true}
	func checkpoint_status() -> Dictionary: return {"can_checkpoint": true}
	func capture_runtime_checkpoint() -> Dictionary: return checkpoint.duplicate(true)
	func restore_runtime_checkpoint(data: Dictionary) -> Dictionary:
		checkpoint = data.duplicate(true)
		return {"applied": true}
	func reset_state() -> void: pass
	func _checkpoint() -> Dictionary:
		return {
			"schema_version": 1,
			"reservations": {},
			"prepared_mutations": {},
			"player_locks": {},
			"inflight_transactions": {},
			"journal": {},
			"reservation_results": {},
			"bankruptcy_estate_journal": {},
			"next_reservation_sequence": 1,
			"reserve_count": 0,
			"commit_count": 0,
			"abort_count": 0,
			"reject_count": 0,
			"last_reason_code": "",
		}


class FlowFixture:
	extends Node
	func install_commodity(_request: Dictionary) -> Dictionary: return {}
	func finalize_commodity_installation(_receipt: Dictionary) -> Dictionary: return {}
	func rollback_commodity_installation(_transaction_id: String) -> Dictionary: return {}
	func card_effect_candidates_snapshot(_request: Dictionary = {}) -> Dictionary: return {}
	func prepare_card_effect_batch(_request: Dictionary) -> Dictionary: return {}
	func commit_card_effect_batch(_request: Dictionary) -> Dictionary: return {}
	func rollback_card_effect_batch(_request: Dictionary) -> Dictionary: return {}
	func finalize_card_effect_batch(_request: Dictionary) -> Dictionary: return {}


class InfrastructureFixture:
	extends Node
	func facilities_snapshot() -> Array: return []
	func region_snapshot(_region_id: String) -> Dictionary: return {}
	func apply_facility_action(_request: Dictionary) -> Dictionary: return {}
	func rollback_facility_action(_request: Dictionary) -> Dictionary: return {}
	func finalize_facility_action(_request: Dictionary) -> Dictionary: return {}
	func facility_action_checkpoint_status() -> Dictionary: return {"can_checkpoint": true}
	func facility_rollback_atomic_ready() -> bool: return true


var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var state_port := StatePortFixture.new()
	var flow := FlowFixture.new()
	var infrastructure := InfrastructureFixture.new()
	var controller := INVENTORY_SCENE.instantiate() as CommodityCardInventoryRuntimeController
	root.add_child(state_port)
	root.add_child(flow)
	root.add_child(infrastructure)
	root.add_child(controller)
	await process_frame
	var configured := controller.configure({"ruleset_id": "v0.6"}, state_port, flow, infrastructure)
	_expect(bool(configured.get("configured", false)), "real Commodity controller configures with narrow owners")
	var card: Dictionary = controller.catalog().call("card_snapshot", "commodity.star_dew_berry.rank_1")
	var belt := controller.configure_belt(7, [{
		"item_id": "belt:closed-v2",
		"card": card,
		"claimable": true,
		"visible_actor_ids": ["player.0"],
	}])
	_expect(bool(belt.get("configured", false)) and not card.is_empty(), "real card catalog creates nontrivial belt state")

	var save_a := controller.to_save_data()
	_expect(int(save_a.get("state_version", 0)) == 2 and WIRE.is_closed_data(save_a) and _raw_float_count(save_a) == 0, "Commodity Save v2 closes all real card floats")
	var checkpoint_a := controller.capture_runtime_checkpoint()
	_expect(int(checkpoint_a.get("schema_version", 0)) == 2 and WIRE.is_closed_data(checkpoint_a) and _raw_float_count(checkpoint_a) == 0, "Commodity checkpoint v2 closes all real card floats")
	_expect(_f64_tag_count(save_a) > 0 and _f64_tag_count(checkpoint_a) > 0, "Commodity Save and checkpoint use the shared F64 tag")

	controller.configure_belt(8, [])
	var restore := controller.restore_runtime_checkpoint(checkpoint_a)
	_expect(bool(restore.get("restored", false)) and controller.capture_runtime_checkpoint() == checkpoint_a, "Commodity checkpoint A equals B after restore")
	controller.configure_belt(9, [])
	var apply := controller.apply_save_data(save_a)
	_expect(bool(apply.get("applied", false)) and controller.to_save_data() == save_a, "Commodity Save A equals B after apply")

	var before_invalid := controller.capture_runtime_checkpoint()
	var tampered := checkpoint_a.duplicate(true)
	var replaced := _replace_first_f64_with_raw(tampered)
	var invalid := controller.restore_runtime_checkpoint(tampered)
	_expect(replaced and not bool(invalid.get("restored", true)) and controller.capture_runtime_checkpoint() == before_invalid, "raw nested float checkpoint fails before mutation")

	controller.queue_free()
	state_port.queue_free()
	flow.queue_free()
	infrastructure.queue_free()
	await process_frame
	_finish()


func _replace_first_f64_with_raw(value: Variant) -> bool:
	if value is Array:
		var array := value as Array
		for index in range(array.size()):
			if _is_f64_tag(array[index]):
				array[index] = 1.25
				return true
			if _replace_first_f64_with_raw(array[index]):
				return true
	if value is Dictionary:
		var dictionary := value as Dictionary
		for key_variant in dictionary.keys():
			if _is_f64_tag(dictionary.get(key_variant)):
				dictionary[key_variant] = 1.25
				return true
			if _replace_first_f64_with_raw(dictionary.get(key_variant)):
				return true
	return false


func _is_f64_tag(value: Variant) -> bool:
	return value is Dictionary and str((value as Dictionary).get("codec", "")) == "f64_bits_hex_v1"


func _f64_tag_count(value: Variant) -> int:
	if _is_f64_tag(value):
		return 1
	if value is Array:
		var count := 0
		for item in value as Array: count += _f64_tag_count(item)
		return count
	if value is Dictionary:
		var count := 0
		for item in (value as Dictionary).values(): count += _f64_tag_count(item)
		return count
	return 0


func _raw_float_count(value: Variant) -> int:
	if value is float: return 1
	if value is Array:
		var count := 0
		for item in value as Array: count += _raw_float_count(item)
		return count
	if value is Dictionary:
		var count := 0
		for item in (value as Dictionary).values(): count += _raw_float_count(item)
		return count
	return 0


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition: _failures.append(message)


func _finish() -> void:
	print("COMMODITY_CARD_INVENTORY_CLOSED_CHECKPOINT_V2_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	if not _failures.is_empty(): push_error("Commodity closed checkpoint v2 failures:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)
