extends SceneTree

const OWNER := preload("res://scripts/runtime/card_inventory_save_owner.gd")
const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")

class ChildFixture:
	extends Node

	var child_id := ""
	var value := 1
	var fail_restore_once := false

	func _init(id: String) -> void:
		child_id = id

	func checkpoint_status() -> Dictionary:
		return {"can_checkpoint": true}

	func to_save_data() -> Dictionary:
		if child_id == "district_purchase":
			return {"district_purchase_runtime": {"schema_version": 3, "next_quote_sequence": 10, "sessions": [], "fixture_value": value}}
		return {"state_version": 2, "ruleset_id": "v0.6", "fixture_value": value}

	func preflight_save_data(data: Dictionary) -> Dictionary:
		return {"accepted": WIRE.is_closed_data(data), "normalized_state": data.duplicate(true), "reason_code": "fixture_save_valid"}

	func apply_save_data(data: Dictionary) -> Dictionary:
		value = int((data.get("district_purchase_runtime", {}) as Dictionary).get("fixture_value", value)) \
				if child_id == "district_purchase" else int(data.get("fixture_value", value))
		return {"applied": true}

	func capture_runtime_checkpoint() -> Dictionary:
		return {"captured": true, "schema_version": 2, "child_id": child_id, "value": value}

	func preflight_runtime_checkpoint(checkpoint: Dictionary) -> Dictionary:
		return {"accepted": int(checkpoint.get("schema_version", 0)) == 2 and checkpoint.get("value") is int, "reason_code": "fixture_checkpoint_valid"}

	func restore_runtime_checkpoint(checkpoint: Dictionary) -> Dictionary:
		if fail_restore_once:
			fail_restore_once = false
			return {"applied": false, "restored": false, "reason_code": "fixture_restore_failed"}
		value = int(checkpoint.get("value", value))
		return {"applied": true, "restored": true}


var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var commodity := ChildFixture.new("commodity_card_inventory")
	var product := ChildFixture.new("product_market")
	var district := ChildFixture.new("district_purchase")
	var owner := OWNER.new() as CardInventorySaveOwner
	root.add_child(commodity)
	root.add_child(product)
	root.add_child(district)
	root.add_child(owner)
	owner.configure_dependencies(commodity, product, district)

	var save_v4 := owner.to_save_data()
	_expect(int(save_v4.get("schema_version", 0)) == 4 and WIRE.is_closed_data(save_v4), "composite Card Inventory Save v4 is closed")
	var legacy_v3 := save_v4.duplicate(true)
	legacy_v3["schema_version"] = 3
	var legacy_preflight := owner.preflight_save_data(legacy_v3)
	_expect(not bool(legacy_preflight.get("accepted", true)) \
			and str(legacy_preflight.get("reason_code", "")) == "card_inventory_v3_closed_wire_upgrade_requires_backup" \
			and bool(legacy_preflight.get("requires_backup", false)), "Card Inventory v3 fails closed with backup reason")

	var checkpoint_a := owner.capture_runtime_checkpoint()
	_expect(int(checkpoint_a.get("schema_version", 0)) == 2 and WIRE.is_closed_data(checkpoint_a) \
			and str(checkpoint_a.get("checkpoint_fingerprint", "")).length() == 64, "composite checkpoint v2 is sealed closed data")
	var children := checkpoint_a.get("children", {}) as Dictionary
	var wrappers_valid := true
	for child_id in ["commodity_card_inventory", "product_market", "district_purchase"]:
		var wrapper := children.get(child_id, {}) as Dictionary
		wrappers_valid = wrappers_valid and str(wrapper.get("checkpoint_mode", "")) == "closed_runtime_checkpoint" \
				and int(wrapper.get("checkpoint_schema_version", 0)) == 2 \
				and str(wrapper.get("state_fingerprint", "")).length() == 64
	_expect(wrappers_valid, "every child wrapper binds mode, version, and fingerprint")

	commodity.value = 11
	product.value = 12
	district.value = 13
	var restore := owner.restore_runtime_checkpoint(checkpoint_a)
	_expect(bool(restore.get("restored", false)) and owner.capture_runtime_checkpoint() == checkpoint_a, "composite checkpoint A equals B after restore")

	for stage in ["commodity_after", "product_market_after", "district_purchase_after"]:
		var target_save := owner.to_save_data()
		commodity.value += 10
		product.value += 20
		district.value += 30
		var live_checkpoint := owner.capture_runtime_checkpoint()
		owner.arm_test_fault_once(stage)
		var failed := owner.apply_save_data(target_save)
		_expect(not bool(failed.get("applied", true)) and bool(failed.get("rollback_complete", false)), "%s triggers complete rollback" % stage)
		_expect(owner.capture_runtime_checkpoint() == live_checkpoint and not bool(owner.debug_snapshot().get("fault_armed", true)), "%s restores children and owner counters exactly" % stage)

	var restore_target := owner.capture_runtime_checkpoint()
	commodity.value += 1
	product.value += 1
	district.value += 1
	var before_late_failure := owner.capture_runtime_checkpoint()
	product.fail_restore_once = true
	var late_failure := owner.restore_runtime_checkpoint(restore_target)
	_expect(not bool(late_failure.get("restored", true)) and bool(late_failure.get("rollback_complete", false)), "late child restore failure reports complete composite rollback")
	_expect(owner.capture_runtime_checkpoint() == before_late_failure, "late child restore failure leaves the live composite state exact")

	owner.queue_free()
	commodity.queue_free()
	product.queue_free()
	district.queue_free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition: _failures.append(message)


func _finish() -> void:
	print("CARD_INVENTORY_SAVE_V4_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	if not _failures.is_empty(): push_error("Card Inventory Save v4 failures:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)
