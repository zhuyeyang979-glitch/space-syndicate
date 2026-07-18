extends SceneTree

const CONTROLLER_SCENE := "res://scenes/runtime/CodexNavigationRuntimeController.tscn"
const REQUEST_SCRIPT := preload("res://scripts/runtime/codex_open_request.gd")

var _checks := 0
var _failures: Array[String] = []
var _revision := 0
var _controller: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(CONTROLLER_SCENE) as PackedScene
	_expect(packed != null, "controller_scene_loads")
	if packed == null:
		_finish()
		return
	_controller = packed.instantiate()
	root.add_child(_controller)
	_controller.call("configure", {})

	_expect(_apply("compendium", "hub", "hub", -1, "", "intel", {"origin": "intel"}), "external_hub_request_is_accepted")
	_expect(_external_target() == "intel" and _stack_depth() == 0, "external_target_is_owned_separately_from_empty_history")
	_expect(_apply("monster", "browser", "catalog", 0, "", "compendium", {"origin": "compendium", "push_current": true}), "hub_to_monster_browser_is_accepted")
	_expect(_stack_depth() == 1 and _external_target() == "intel", "hub_to_browser_pushes_hub_without_overwriting_external_target")

	var before_preview := _debug()
	_expect(_apply("monster", "preview", "monster:0", 0, "", "main", {"origin": "monster"}), "monster_preview_is_accepted")
	var after_preview := _debug()
	_expect(_stack_depth() == 1 and int(after_preview.get("history_push_count", -1)) == int(before_preview.get("history_push_count", -2)) and int(after_preview.get("history_pop_count", -1)) == int(before_preview.get("history_pop_count", -2)), "preview_does_not_push_or_pop")
	_expect(_external_target() == "intel" and str((_controller.call("navigation_snapshot") as Dictionary).get("current_view", "")) == "browser", "preview_preserves_external_target_and_browser_view")

	_expect(_apply("monster", "detail", "monster:0", 0, "", "main", {"origin": "monster", "push_current": true}), "browser_to_monster_detail_is_accepted")
	_expect(_stack_depth() == 2, "browser_to_detail_pushes_complete_browser_frame")
	var before_repeat := _debug()
	_expect(_apply("monster", "detail", "monster:0", 0, "", "main", {"origin": "monster", "push_current": true}), "repeated_detail_request_is_idempotently_accepted")
	var after_repeat := _debug()
	_expect(_stack_depth() == 2 and int(after_repeat.get("history_push_count", -1)) == int(before_repeat.get("history_push_count", -2)) and int(after_repeat.get("history_duplicate_count", 0)) == int(before_repeat.get("history_duplicate_count", 0)) + 1, "repeated_detail_does_not_duplicate_frame")

	_expect(_apply("card", "detail", "monster-card:0", 3, "all", "main", {"origin": "monster", "push_current": true}), "monster_detail_to_card_detail_is_accepted")
	_expect(_stack_depth() == 3 and _external_target() == "intel", "monster_to_card_pushes_monster_detail_once")

	var forged := _request("card", "browser", "catalog", 99, "all", "intel", {"origin": "compendium", "pop_stack": true})
	_expect(not bool(_controller.call("apply_request", forged, _resolved("catalog", 99, 0, "all")).get("accepted", false)), "forged_pop_request_fails_closed")
	_expect(_stack_depth() == 3, "forged_pop_does_not_consume_history")

	_expect(_apply_back(), "card_detail_back_is_accepted")
	_expect(_mode_is("monster", "detail", "monster:0") and _stack_depth() == 2, "card_detail_back_restores_monster_detail")
	_expect(_apply_back(), "monster_detail_back_is_accepted")
	_expect(_mode_is("monster", "browser", "monster:0") and _stack_depth() == 1, "monster_detail_back_restores_complete_monster_browser")
	_expect(_apply_back(), "monster_browser_back_is_accepted")
	_expect(_mode_is("compendium", "hub", "hub") and _stack_depth() == 0, "monster_browser_back_restores_hub")
	var external_spec: Dictionary = _controller.call("back_request_spec")
	_expect(str(external_spec.get("kind", "")) == "return" and str(external_spec.get("target", "")) == "intel", "hub_back_routes_to_original_external_target")

	var final_debug := _debug()
	_expect(int(final_debug.get("history_push_count", -1)) == 3 and int(final_debug.get("history_pop_count", -1)) == 3, "history_push_pop_counts_are_exact_once")
	_expect((final_debug.get("history_frames", []) as Array).is_empty() and _is_pure_data(final_debug), "history_and_debug_snapshots_are_pure_data")
	var invalid_private := {"domain": "monster", "view": "detail", "stable_item_id": "monster:0", "selected_index": 0, "page_index": 0, "filter_id": "", "cash": 99}
	_expect(not bool((_controller.call("history_frame_validation_report", invalid_private) as Dictionary).get("valid", true)), "frame_with_private_extra_key_fails_closed")
	var invalid_object := {"domain": "monster", "view": "detail", "stable_item_id": Node.new(), "selected_index": 0, "page_index": 0, "filter_id": ""}
	_expect(not bool((_controller.call("history_frame_validation_report", invalid_object) as Dictionary).get("valid", true)), "frame_with_object_fails_closed")
	(invalid_object["stable_item_id"] as Node).free()
	_expect((_controller.call("to_legacy_save_snapshot") as Dictionary).size() == 12, "legacy_save_schema_remains_unchanged")

	_controller.queue_free()
	await process_frame
	_finish()


func _apply(domain: String, view: String, item_id: String, index: int, filter_id: String, return_target: String, context: Dictionary) -> bool:
	var request := _request(domain, view, item_id, index, filter_id, return_target, context)
	return bool((_controller.call("apply_request", request, _resolved(item_id, index, 0, filter_id)) as Dictionary).get("accepted", false))


func _apply_back() -> bool:
	var spec: Dictionary = _controller.call("back_request_spec")
	if str(spec.get("kind", "")) != "navigation":
		return false
	var request := _request(str(spec.get("domain", "")), str(spec.get("view", "")), str(spec.get("stable_item_id", "")), int(spec.get("optional_index", -1)), str(spec.get("filter_id", "")), str(spec.get("return_target", "main")), spec.get("public_source_context", {}) as Dictionary)
	return bool((_controller.call("apply_request", request, _resolved(request.stable_item_id, request.optional_index, 0, request.filter_id)) as Dictionary).get("accepted", false))


func _request(domain: String, view: String, item_id: String, index: int, filter_id: String, return_target: String, context: Dictionary) -> RefCounted:
	_revision += 1
	var request: RefCounted = REQUEST_SCRIPT.new()
	request.set("domain", domain)
	request.set("view", view)
	request.set("stable_item_id", item_id)
	request.set("optional_index", index)
	request.set("filter_id", filter_id)
	request.set("return_target", return_target)
	request.set("request_revision", _revision)
	request.set("public_source_context", context.duplicate(true))
	return request


func _resolved(item_id: String, index: int, page: int, filter_id: String) -> Dictionary:
	var result := {"valid": true, "stable_item_id": item_id, "selected_index": index, "page_index": page}
	if not filter_id.is_empty():
		result["filter_id"] = filter_id
	return result


func _mode_is(domain: String, view: String, item_id: String) -> bool:
	var snapshot: Dictionary = _controller.call("navigation_snapshot")
	return str(snapshot.get("catalog_mode", "")) == domain and str(snapshot.get("current_view", "")) == view and str(snapshot.get("stable_item_id", "")) == item_id


func _external_target() -> String:
	return str((_controller.call("navigation_snapshot") as Dictionary).get("external_return_target", ""))


func _stack_depth() -> int:
	return int((_controller.call("navigation_snapshot") as Dictionary).get("stack_depth", -1))


func _debug() -> Dictionary:
	return _controller.call("debug_snapshot") as Dictionary


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


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(label)
	push_error("CODEX NAVIGATION BACKSTACK: %s" % label)


func _finish() -> void:
	if _failures.is_empty():
		print("CODEX_NAVIGATION_BACKSTACK_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	print("CODEX_NAVIGATION_BACKSTACK_TEST|status=FAIL|checks=%d|failures=%d|labels=%s" % [_checks, _failures.size(), _failures])
	quit(1)
