extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const COORDINATOR_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator"
const SAVE_COORDINATOR_PATH := COORDINATOR_PATH + "/GameSessionRuntimeController/GameSaveRuntimeCoordinator"
const QA_SAVE_PATH := "user://test_runs/monster_codex_public_visibility_contract.save"
const FORBIDDEN_FIELDS := [
	"rank_iv_probability_summary", "rank_iv_probability_shift", "probability", "probability_tooltip",
	"i_open", "i_destroyed", "iv_open", "iv_destroyed", "weight", "weights", "target_weight",
	"target_weights", "rng", "rng_state", "actual_target", "committed_target", "preselected_target",
	"owner", "owner_id", "owner_index", "hidden_owner", "player_index", "cash", "hand", "discard", "ai_score",
]

var _checks := 0
var _failures: Array[String] = []
var _main: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_main = MAIN_SCENE.instantiate()
	_cleanup_test_save()
	var save := _main.get_node_or_null(SAVE_COORDINATOR_PATH)
	_expect(save != null and bool(save.call("set_qa_default_save_path_override", QA_SAVE_PATH)), "focused gate uses isolated save path")
	root.add_child(_main)
	await process_frame
	var coordinator := _main.get_node_or_null(COORDINATOR_PATH)
	var monster := coordinator.get_node_or_null("MonsterRuntimeController") if coordinator != null else null
	var source_service := coordinator.get_node_or_null("MonsterCodexPublicSourceService") if coordinator != null else null
	_expect(monster != null and monster.has_method("monster_codex_public_catalog_source_v06"), "monster owner exposes public catalog API")
	_expect(source_service != null and source_service.has_method("compose_detail_source"), "scene-owned public source is present")
	if monster != null and source_service != null and coordinator != null:
		var owner_source := monster.call("monster_codex_public_catalog_source_v06", 0) as Dictionary
		var public_source := source_service.call("compose_detail_source", 0, true) as Dictionary
		var final_snapshot := coordinator.call("monster_codex_public_detail_snapshot", 0, true) as Dictionary
		_expect(bool(owner_source.get("valid", false)) and bool(public_source.get("valid", false)) and not final_snapshot.is_empty(), "owner source and final public page compose")
		_expect(not _contains_forbidden_field(owner_source), "monster owner public catalog excludes probability, target, RNG and owner fields")
		_expect(not _contains_forbidden_field(public_source) and not _contains_forbidden_field(final_snapshot), "source and UI projections preserve the strict visibility boundary")
		var detail := final_snapshot.get("detail", {}) as Dictionary
		var actions := detail.get("actions", []) as Array
		_expect(not actions.is_empty() and str((actions[0] as Dictionary).get("disclosure", "")) == "公开效果｜权重隐藏", "action cards explain the boundary without raw probability")
		_expect(not _contains_percent_literal(actions), "action cards expose no probability percentages")
		var invalid := monster.call("monster_codex_public_catalog_source_v06", 99999) as Dictionary
		_expect(not bool(invalid.get("valid", true)) and str(invalid.get("reason_code", "")) == "monster_catalog_index_invalid", "invalid catalog index fails closed")
	_main.queue_free()
	_main = null
	await process_frame
	await process_frame
	_cleanup_test_save()
	_finish()


func _contains_forbidden_field(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant: Variant in value:
			var key := str(key_variant).to_lower()
			if FORBIDDEN_FIELDS.has(key) or key.contains("numerator") or key.contains("denominator"):
				return true
			if _contains_forbidden_field(value[key_variant]):
				return true
	elif value is Array:
		for item_variant: Variant in value:
			if _contains_forbidden_field(item_variant):
				return true
	return false


func _contains_percent_literal(value: Variant) -> bool:
	if value is String or value is StringName:
		var text := str(value)
		for index in range(text.length()):
			if text[index] == "%" and index > 0 and str(text[index - 1]).is_valid_int():
				return true
	elif value is Dictionary:
		for key_variant: Variant in value:
			if _contains_percent_literal(value[key_variant]):
				return true
	elif value is Array:
		for item_variant: Variant in value:
			if _contains_percent_literal(item_variant):
				return true
	return false


func _cleanup_test_save() -> void:
	var absolute_path := ProjectSettings.globalize_path(QA_SAVE_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(label)
	push_error("MONSTER_CODEX_PUBLIC_VISIBILITY_CONTRACT: %s" % label)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("MONSTER_CODEX_PUBLIC_VISIBILITY_CONTRACT|status=%s|checks=%d|failures=%d|details=%s" % [status, _checks, _failures.size(), JSON.stringify(_failures)])
	quit(0 if _failures.is_empty() else 1)
