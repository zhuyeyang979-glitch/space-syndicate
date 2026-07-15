extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"
const MONSTER_CONTROLLER_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/MonsterRuntimeController"
const SAVE_COORDINATOR_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController/GameSaveRuntimeCoordinator"
const QA_SAVE_PATH := "user://test_runs/monster_codex_public_probability_contract.save"

var _checks := 0
var _failures: Array[String] = []
var _main: Node
var _monster: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(MAIN_SCENE) as PackedScene
	_expect(packed != null, "main_scene_loads")
	if packed == null:
		_finish()
		return
	_main = packed.instantiate()
	_cleanup_test_save()
	var save := _main.get_node_or_null(SAVE_COORDINATOR_PATH)
	_expect(save != null and save.has_method("set_qa_default_save_path_override"), "qa_save_override_available_before_tree_entry")
	if save == null or not save.has_method("set_qa_default_save_path_override"):
		_main.free()
		_main = null
		_finish()
		return
	_expect(bool(save.call("set_qa_default_save_path_override", QA_SAVE_PATH)), "focused_gate_uses_isolated_qa_save_path")
	root.add_child(_main)
	await process_frame
	if _main.has_method("_new_game"):
		_main.set("configured_player_count", 4)
		_main.set("configured_ai_player_count", 3)
		_main.call("_new_game")
	await process_frame
	_monster = _main.get_node_or_null(MONSTER_CONTROLLER_PATH)
	_test_public_catalog_probability_api()
	await _cleanup()
	_finish()


func _test_public_catalog_probability_api() -> void:
	_expect(_monster != null and _monster.has_method("monster_codex_public_catalog_source_v06"), "monster_owner_exposes_public_catalog_probability_api")
	if _monster == null or not _monster.has_method("monster_codex_public_catalog_source_v06"):
		return
	var source: Dictionary = _public_source(0)
	_expect(bool(source.get("valid", false)), "public_catalog_source_valid")
	_expect(_source_has_probability_contract(source), "public_source_exposes_i_iv_open_destroyed_probability_progression")
	_expect(_public_probability_fields_have_no_raw_weight(source), "public_probability_fields_hide_raw_weight_parts")
	var invalid: Dictionary = _public_source(99999)
	_expect(not bool(invalid.get("valid", true)) and str(invalid.get("reason_code", "")) == "monster_catalog_index_invalid", "invalid_catalog_index_fails_closed")


func _public_source(catalog_index: int) -> Dictionary:
	var value: Variant = _monster.call("monster_codex_public_catalog_source_v06", catalog_index)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _source_has_probability_contract(source: Dictionary) -> bool:
	var actions := _array(source.get("actions", []))
	if actions.is_empty():
		return false
	var has_i_to_iv_progression := false
	var has_destroyed_progression := false
	for action_variant in actions:
		if not (action_variant is Dictionary):
			continue
		var action := action_variant as Dictionary
		var i_open := _percent_value(action.get("i_open", ""))
		var i_destroyed := _percent_value(action.get("i_destroyed", ""))
		var iv_open := _percent_value(action.get("iv_open", ""))
		var iv_destroyed := _percent_value(action.get("iv_destroyed", ""))
		if i_open < 0 or i_destroyed < 0 or iv_open < 0 or iv_destroyed < 0:
			return false
		var tooltip := str(action.get("probability_tooltip", ""))
		if not (tooltip.contains("I开局") and tooltip.contains("I破坏后") and tooltip.contains("IV开局") and tooltip.contains("IV破坏后")):
			return false
		has_i_to_iv_progression = has_i_to_iv_progression or iv_open != i_open
		has_destroyed_progression = has_destroyed_progression or i_destroyed != i_open or iv_destroyed != iv_open
	return has_i_to_iv_progression and has_destroyed_progression


func _public_probability_fields_have_no_raw_weight(source: Dictionary) -> bool:
	var fields := [
		str(source.get("rank_iv_probability_summary", "")),
		str((source.get("ecology", {}) as Dictionary).get("rank_iv_probability_shift", "")),
	]
	for action_variant in _array(source.get("actions", [])):
		if action_variant is Dictionary:
			fields.append(str((action_variant as Dictionary).get("probability_tooltip", "")))
	for text in fields:
		if _text_has_raw_weight(str(text)):
			return false
	return true


func _percent_value(value: Variant) -> int:
	var text := str(value).strip_edges()
	if not text.ends_with("%"):
		return -1
	text = text.trim_suffix("%").strip_edges()
	if not text.is_valid_int():
		return -1
	var percent := int(text)
	return percent if percent >= 0 and percent <= 100 else -1


func _text_has_raw_weight(text: String) -> bool:
	var lower := text.to_lower()
	for token in ["weight", "raw_weight", "weight_delta", "numerator", "denominator", "total_weight", "rng", "actual_target", "committed_target"]:
		if lower.contains(token):
			return true
	return text.contains("权重") or text.contains("分子") or text.contains("分母") or text.contains("随机票")


func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if value is Array else []


func _cleanup() -> void:
	if _main != null:
		_main.queue_free()
	_main = null
	_monster = null
	await process_frame
	await process_frame
	_cleanup_test_save()


func _cleanup_test_save() -> void:
	var absolute_path := ProjectSettings.globalize_path(QA_SAVE_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(label)
	push_error("MONSTER_CODEX_PUBLIC_PROBABILITY_CONTRACT: %s" % label)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("MONSTER_CODEX_PUBLIC_PROBABILITY_CONTRACT|status=%s|checks=%d|failures=%d|details=%s" % [status, _checks, _failures.size(), JSON.stringify(_failures)])
	quit(0 if _failures.is_empty() else 1)
