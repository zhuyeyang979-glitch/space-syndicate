extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const COORDINATOR_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator"
const SAVE_PATH := COORDINATOR_PATH + "/GameSessionRuntimeController/GameSaveRuntimeCoordinator"
const QA_SAVE_PATH := "user://test_runs/monster_codex_public_source_service.save"

var _checks := 0
var _failures: Array[String] = []
var _main: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup_save()
	_main = MAIN_SCENE.instantiate()
	var save := _main.get_node_or_null(SAVE_PATH)
	_expect(save != null and bool(save.call("set_qa_default_save_path_override", QA_SAVE_PATH)), "qa save override is installed before tree entry")
	root.add_child(_main)
	await process_frame
	var coordinator := _main.get_node_or_null(COORDINATOR_PATH)
	var service := coordinator.get_node_or_null("MonsterCodexPublicSourceService") if coordinator != null else null
	_expect(service != null and bool((service.call("debug_snapshot") as Dictionary).get("service_ready", false)), "scene-owned monster public source is configured")
	if service != null:
		var count := int(service.call("public_catalog_count"))
		_expect(count == 8, "public monster catalog keeps eight canonical entries")
		var source := service.call("compose_detail_source", 0, true) as Dictionary
		var snapshot := service.call("compose_snapshot", 0, true) as Dictionary
		var browser := service.call("compose_browser_source", {"start_index": 0, "end_index": count, "selected_index": 0, "columns": 4, "can_page": false, "page_label": "第1/1页"}) as Dictionary
		_expect(bool(source.get("valid", false)) and not snapshot.is_empty(), "real owner detail source and snapshot compose")
		_expect((browser.get("entries", []) as Array).size() == count and int(browser.get("selected_index", -1)) == 0, "browser source contains the canonical public catalog")
		_expect(_is_pure_data(source) and _is_pure_data(snapshot) and _is_pure_data(browser), "source browser and snapshot are pure data")
		_expect(not _contains_private_key(source) and not _contains_private_key(snapshot) and not _contains_private_key(browser), "public source excludes private owner target player and AI fields")
		_expect(str(service.call("stable_item_id_at", 0)) == "monster:0" and int(service.call("index_for_stable_item_id", "monster:0")) == 0, "stable public monster IDs round trip")
		var invalid := service.call("compose_detail_source", 99999, false) as Dictionary
		_expect(invalid.is_empty() or not bool(invalid.get("valid", true)), "invalid public monster index fails closed")
		var debug := service.call("debug_snapshot") as Dictionary
		_expect(not bool(debug.get("reads_world_bridge", true)) and not bool(debug.get("reads_roster", true)) and not bool(debug.get("reads_private_targeting", true)) and not bool(debug.get("owns_save_state", true)), "source is public read-only and non-owning")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	_expect(not main_source.contains("func _bestiary_codex_browser_snapshot(") and not main_source.contains("func _bestiary_codex_public_snapshot("), "retired Main bestiary source wrappers remain absent")
	_main.queue_free()
	_main = null
	await process_frame
	_cleanup_save()
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


func _contains_private_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant: Variant in value:
			var key := str(key_variant).to_lower()
			if key in ["owner", "owner_id", "hidden_owner", "private_target", "actual_target", "target_weight", "player_index", "cash", "hand", "discard", "ai_score"]:
				return true
			if _contains_private_key(value[key_variant]):
				return true
	elif value is Array:
		for item_variant: Variant in value:
			if _contains_private_key(item_variant):
				return true
	return false


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(label)
	push_error("MONSTER CODEX PUBLIC SOURCE: %s" % label)


func _cleanup_save() -> void:
	for path in [QA_SAVE_PATH, QA_SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("MONSTER_CODEX_PUBLIC_SOURCE_SERVICE_TEST|status=%s|checks=%d|failures=%d|labels=%s" % [status, _checks, _failures.size(), _failures])
	quit(0 if _failures.is_empty() else 1)
