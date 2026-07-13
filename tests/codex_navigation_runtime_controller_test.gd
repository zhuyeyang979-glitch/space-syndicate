extends SceneTree

const CONTROLLER_SCENE := "res://scenes/runtime/CodexNavigationRuntimeController.tscn"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(CONTROLLER_SCENE) as PackedScene
	_expect(packed != null, "controller scene loads")
	var controller := packed.instantiate() if packed != null else null
	_expect(controller != null, "controller scene instantiates")
	if controller == null:
		_finish()
		return
	root.add_child(controller)
	controller.call("configure", {})
	var defaults: Dictionary = controller.call("navigation_snapshot")
	_expect(str(defaults.get("catalog_mode", "invalid")) == "" and str(defaults.get("return_target", "")) == "main", "controller exposes stable defaults")
	controller.call("update_domain", "monster", {"selected_index": 4, "page_index": 2, "show_detail": true, "preview_index": 3})
	controller.call("update_domain", "card", {"selected_index": 7, "filter_id": "finance", "page_index": 1, "show_detail": true, "preview_id": "轨道融资1"})
	controller.call("update_domain", "product", {"selected_index": 2, "page_index": 1, "show_detail": true, "preview_index": 2})
	var state: Dictionary = controller.call("navigation_snapshot")
	_expect(int((state.get("monster", {}) as Dictionary).get("preview_index", -1)) == 3, "monster navigation updates")
	_expect(str((state.get("card", {}) as Dictionary).get("preview_id", "")) == "轨道融资1", "card navigation updates")
	_expect(int((state.get("product", {}) as Dictionary).get("selected_index", -1)) == 2, "product navigation updates")
	_expect(int(controller.call("page_count", 17, 6)) == 3 and int(controller.call("page_for_index", 13, 17, 6)) == 2 and int(controller.call("first_index_on_page", 2, 17, 6)) == 12, "pagination helpers preserve deterministic boundaries")
	var legacy: Dictionary = controller.call("to_legacy_save_snapshot")
	controller.call("reset_navigation")
	controller.call("apply_legacy_save_snapshot", legacy)
	_expect(controller.call("to_legacy_save_snapshot") == legacy, "legacy v1 navigation state round-trips")
	_expect(_is_pure_data(controller.call("debug_snapshot")), "controller debug snapshot is pure data")
	controller.queue_free()
	await process_frame
	_finish()


func _is_pure_data(value: Variant) -> bool:
	if value is Callable or typeof(value) == TYPE_OBJECT:
		return false
	if value is Dictionary:
		for key_variant: Variant in value:
			if not _is_pure_data(key_variant) or not _is_pure_data(value[key_variant]):
				return false
	elif value is Array:
		for item_variant: Variant in value:
			if not _is_pure_data(item_variant):
				return false
	return true


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("CODEX NAVIGATION CONTROLLER: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("CODEX NAVIGATION CONTROLLER PASS")
		quit(0)
		return
	print("CODEX NAVIGATION CONTROLLER FAIL: %d" % failures.size())
	quit(1)
