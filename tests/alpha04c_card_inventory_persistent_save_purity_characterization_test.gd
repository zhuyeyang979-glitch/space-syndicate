extends SceneTree

const OWNER_SCRIPT := preload("res://scripts/runtime/card_inventory_save_owner.gd")
const PRODUCT_MARKET_SCRIPT := preload("res://scripts/runtime/product_market_runtime_controller.gd")
const INSPECTOR := preload("res://scripts/tools/card_inventory_checkpoint_purity_inspector_v1.gd")


class ClosedSaveChildFixture:
	extends Node

	var state: Dictionary

	func _init(initial_state: Dictionary) -> void:
		state = initial_state.duplicate(true)

	func to_save_data() -> Dictionary:
		return state.duplicate(true)

	func preflight_save_data(data: Dictionary) -> Dictionary:
		return {
			"accepted": true,
			"reason_code": "fixture_save_valid",
			"normalized_state": data.duplicate(true),
		}

	func apply_save_data(data: Dictionary) -> Dictionary:
		state = data.duplicate(true)
		return {"applied": true, "reason_code": "fixture_save_applied"}


var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var owner := OWNER_SCRIPT.new() as CardInventorySaveOwner
	var product_market := PRODUCT_MARKET_SCRIPT.new() as ProductMarketRuntimeController
	var commodity := ClosedSaveChildFixture.new({"schema_version": 1, "belt": []})
	var district := ClosedSaveChildFixture.new({"district_purchase_runtime": {
		"schema_version": 3,
		"next_quote_sequence": 1,
		"sessions": [],
	}})
	root.add_child(owner)
	root.add_child(product_market)
	root.add_child(commodity)
	root.add_child(district)
	product_market.product_market = {
		"fixture.product": {
			"base_price": 10,
			"price": 10,
			"trend": 2,
			"growth_multiplier": 1.25,
			"futures_positions": [],
		},
	}
	product_market.market_timer = 8.5
	var configured := owner.configure_dependencies(commodity, product_market, district)
	_expect(bool(configured.get("configured", false)), "real Card Inventory Save owner accepts the focused child composition")
	var save_payload := owner.to_save_data()
	_expect(int(save_payload.get("schema_version", 0)) == 3, "real Card Inventory owner emits persistent schema v3")
	_expect(save_payload.has("commodity_card_inventory") and save_payload.has("product_market") \
		and save_payload.has("district_purchase"), "schema v3 envelope contains all three children")
	var report := INSPECTOR.inspect(save_payload, {
		"commodity_card_inventory": "to_save_data",
		"product_market": "to_save_data",
		"district_purchase": "to_save_data",
	})
	_expect(bool(report.get("payload_pure_data", false)), "current V7 owner codec accepts the finite-float Save payload")
	_expect(not bool(report.get("strict_closed_data", true)), "strict SemanticWire contract rejects the persistent Save payload")
	_expect(int(report.get("strict_non_closed_leaf_count", 0)) == 2, "persistent Save exposes the two focused strict float defects")
	var strict_leaves := report.get("strict_non_closed_leaves", []) as Array
	var first_strict: Dictionary = strict_leaves[0] as Dictionary if not strict_leaves.is_empty() else {}
	var strict_paths: Array[String] = []
	for leaf_variant in strict_leaves:
		strict_paths.append(str((leaf_variant as Dictionary).get("json_path", "")))
	_expect(str(first_strict.get("source_child_id", "")) == "product_market", "persistent defect belongs to Product Market")
	_expect(str(first_strict.get("variant_type", "")) == "float", "first persistent Save defect is a float")
	_expect(str(first_strict.get("source_capture_method", "")) == "to_save_data", "persistent defect identifies its real capture method")
	_expect(strict_paths.any(func(path: String) -> bool: return path.ends_with(".growth_multiplier")), "growth multiplier float is attested")
	_expect(strict_paths.any(func(path: String) -> bool: return path.ends_with(".market_timer")), "market timer float is attested")
	print("CARD_INVENTORY_PERSISTENT_SAVE_PURITY_CHARACTERIZATION|%s" % JSON.stringify({
		"card_inventory_save_schema_version": int(save_payload.get("schema_version", 0)),
		"checkpoint_leaf_count": int(report.get("checkpoint_leaf_count", 0)),
		"v7_owner_codec_pure_data": bool(report.get("payload_pure_data", false)),
		"strict_closed_data": bool(report.get("strict_closed_data", false)),
		"strict_non_closed_leaf_count": int(report.get("strict_non_closed_leaf_count", 0)),
		"first_strict_non_closed_child_id": str(first_strict.get("source_child_id", "")),
		"first_strict_non_closed_path": str(first_strict.get("json_path", "")),
		"first_strict_non_closed_variant_type": str(first_strict.get("variant_type", "")),
		"first_strict_non_closed_reason": str(first_strict.get("strict_reason_code", "")),
		"first_strict_non_closed_capture_method": str(first_strict.get("source_capture_method", "")),
		"strict_non_closed_type_counts": report.get("strict_non_closed_type_counts", {}),
	}))
	owner.queue_free()
	product_market.queue_free()
	commodity.queue_free()
	district.queue_free()
	await process_frame
	print("ALPHA04C_CARD_INVENTORY_PERSISTENT_SAVE_PURITY_CHARACTERIZATION_TEST|status=%s|checks=11|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_failures.size(),
	])
	if not _failures.is_empty():
		push_error("Persistent Save purity characterization failed:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
