extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const SAVE_COORDINATOR_NODE_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController/GameSaveRuntimeCoordinator"
const PRODUCT_MARKET_CONTROLLER_NODE_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ProductMarketRuntimeController"
const TEST_SAVE_PATH := "user://test_runs/product_market_owner_smoke_fixture.save"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup_save()
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	_expect(packed != null, "main scene loads")
	if packed == null:
		_finish()
		return
	var main := packed.instantiate()
	var save_coordinator := main.get_node_or_null(SAVE_COORDINATOR_NODE_PATH)
	var save_override_ready := save_coordinator != null \
		and save_coordinator.has_method("set_qa_default_save_path_override") \
		and bool(save_coordinator.call("set_qa_default_save_path_override", TEST_SAVE_PATH))
	_expect(save_override_ready, "fixture isolates the default save path")
	if not save_override_ready:
		main.free()
		_finish()
		return
	get_root().add_child(main)
	await process_frame
	await process_frame
	main.call("_new_game")
	await process_frame
	await process_frame

	var controller := main.get_node_or_null(PRODUCT_MARKET_CONTROLLER_NODE_PATH)
	_expect(controller != null, "ProductMarketRuntimeController is scene-owned")
	_expect(controller != null and controller.has_method("runtime_state_snapshot"), "owner exposes a runtime state snapshot")
	_expect(controller != null and controller.has_method("to_save_data") and controller.has_method("apply_save_data"), "owner exposes its narrow save contract")
	if controller != null:
		var state_variant: Variant = controller.call("runtime_state_snapshot")
		var state := (state_variant as Dictionary).duplicate(true) if state_variant is Dictionary else {}
		var market_variant: Variant = state.get("product_market", {})
		var market := (market_variant as Dictionary).duplicate(true) if market_variant is Dictionary else {}
		_expect(not market.is_empty(), "new game initializes the owner market")
		_expect(_market_has_prices(market), "owner market contains positive base and current prices")
		var saved_variant: Variant = controller.call("to_save_data")
		var saved := (saved_variant as Dictionary).duplicate(true) if saved_variant is Dictionary else {}
		_expect(saved.get("product_market", {}) is Dictionary, "owner save data contains the market section")
		if not market.is_empty() and not saved.is_empty():
			var product_id := str(market.keys()[0])
			var entry := (market.get(product_id, {}) as Dictionary).duplicate(true)
			var original_trend := int(entry.get("trend", 0))
			entry["trend"] = original_trend + 7
			market[product_id] = entry
			var replacement := saved.duplicate(true)
			replacement["product_market"] = market
			var applied_variant: Variant = controller.call("apply_save_data", replacement)
			var applied := (applied_variant as Dictionary).duplicate(true) if applied_variant is Dictionary else {}
			var applied_market := applied.get("product_market", {}) as Dictionary
			_expect(int((applied_market.get(product_id, {}) as Dictionary).get("trend", original_trend)) == original_trend + 7, "owner applies a test replacement without Main state")
			var restored_variant: Variant = controller.call("apply_save_data", saved)
			var restored := (restored_variant as Dictionary).duplicate(true) if restored_variant is Dictionary else {}
			var restored_market := restored.get("product_market", {}) as Dictionary
			_expect(int((restored_market.get(product_id, {}) as Dictionary).get("trend", original_trend + 7)) == original_trend, "owner restores the exact prior market")

	_expect(not _has_property(main, "product_market"), "Main has no legacy product_market state property")
	main.queue_free()
	await process_frame
	_cleanup_save()
	_finish()


func _market_has_prices(market: Dictionary) -> bool:
	for entry_variant in market.values():
		if entry_variant is Dictionary:
			var entry := entry_variant as Dictionary
			if int(entry.get("price", 0)) > 0 and int(entry.get("base_price", 0)) > 0:
				return true
	return false


func _has_property(target: Object, property_name: String) -> bool:
	for property_variant in target.get_property_list():
		var property := property_variant as Dictionary
		if str(property.get("name", "")) == property_name:
			return true
	return false


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _cleanup_save() -> void:
	var absolute_path := ProjectSettings.globalize_path(TEST_SAVE_PATH)
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(absolute_path)


func _finish() -> void:
	print("PRODUCT_MARKET_OWNER_SMOKE_FIXTURE|status=%s|checks=%d|failures=%d|labels=%s" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
		JSON.stringify(_failures),
	])
	quit(0 if _failures.is_empty() else 1)
