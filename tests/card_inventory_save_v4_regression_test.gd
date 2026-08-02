extends SceneTree

const OWNER := preload("res://scripts/runtime/card_inventory_save_owner.gd")
const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")

class ChildFixture:
	extends Node

	var child_id := ""
	var value := 1

	func _init(id: String) -> void:
		child_id = id

	func checkpoint_status() -> Dictionary:
		return {"can_checkpoint": true}

	func to_save_data() -> Dictionary:
		if child_id == "district_purchase":
			return {"district_purchase_runtime": {"schema_version": 3, "next_quote_sequence": 10, "sessions": [], "fixture_value": value}}
		return {"state_version": 2, "ruleset_id": "v0.6", "fixture_value": value}

	func preflight_save_data(data: Dictionary) -> Dictionary:
		return {"accepted": WIRE.is_closed_data(data), "normalized_state": data.duplicate(true)}

	func apply_save_data(data: Dictionary) -> Dictionary:
		value = int((data.get("district_purchase_runtime", {}) as Dictionary).get("fixture_value", value)) \
				if child_id == "district_purchase" else int(data.get("fixture_value", value))
		return {"applied": true}

	func capture_runtime_checkpoint() -> Dictionary:
		return {"captured": true, "schema_version": 2, "child_id": child_id, "value": value}

	func preflight_runtime_checkpoint(checkpoint: Dictionary) -> Dictionary:
		return {"accepted": int(checkpoint.get("schema_version", 0)) == 2}

	func restore_runtime_checkpoint(checkpoint: Dictionary) -> Dictionary:
		value = int(checkpoint.get("value", value))
		return {"applied": true, "restored": true}


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
	var save_a := owner.to_save_data()
	commodity.value = 11
	product.value = 12
	district.value = 13
	var applied := owner.apply_save_data(save_a)
	var save_b := owner.to_save_data()
	var green := int(save_a.get("schema_version", -1)) == 4 \
			and WIRE.is_closed_data(save_a) \
			and bool(applied.get("applied", false)) \
			and save_a == save_b \
			and int(owner.capture_runtime_checkpoint().get("schema_version", -1)) == 2
	owner.queue_free()
	commodity.queue_free()
	product.queue_free()
	district.queue_free()
	print("CARD_INVENTORY_SAVE_V4_REGRESSION_TEST|status=%s|checks=5|failures=%d" % [
		"PASS" if green else "FAIL",
		0 if green else 1,
	])
	if not green:
		push_error("Card Inventory Save v4/checkpoint v2 regression failed")
	quit(0 if green else 1)
