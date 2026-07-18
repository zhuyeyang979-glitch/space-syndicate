extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"
const COORDINATOR_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator"
const SAVE_COORDINATOR_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController/GameSaveRuntimeCoordinator"
const QA_SAVE_PATH := "user://test_runs/role_codex_public_contract.save"
const STARTER_ROLE_FIELDS := [
	"starter_monster_index",
	"starter_monster_name",
	"starter_monster_card",
	"starter_hp_bonus",
	"starter_duration_bonus",
	"starter_move_multiplier",
	"starter_fixed_skill_bonus",
]
const PRIVATE_KEYS := [
	"cash",
	"hand",
	"slots",
	"discard",
	"private_discard",
	"owner",
	"hidden_owner",
	"city_guesses",
	"ai_private_plan",
	"private_plan",
	"starter_monster_card",
]

var _checks := 0
var _failures: Array[String] = []
var _main: Node
var _coordinator: Node
var _diagnostics: Node


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
	_coordinator = _main.get_node_or_null(COORDINATOR_PATH)
	_diagnostics = _coordinator.call("gameplay_balance_diagnostics_service") if _coordinator != null and _coordinator.has_method("gameplay_balance_diagnostics_service") else null
	_test_role_codex_public_owner_contract()
	_test_random_role_resolution_without_run_state_wrapper()
	await _cleanup()
	_finish()


func _test_role_codex_public_owner_contract() -> void:
	_expect(_coordinator != null and _coordinator.has_method("role_codex_public_snapshot"), "coordinator_exposes scene-owned role Codex public source")
	_expect(_diagnostics != null and _diagnostics.has_method("role_balance_audit"), "diagnostics_owner_exposes_role_balance_audit")
	if _coordinator == null or _diagnostics == null:
		return
	var role_count := int(_main.call("_player_role_catalog_size"))
	_expect(role_count == 24, "role_catalog_exactly_24")
	var source_service := _coordinator.get_node_or_null("RoleCodexPublicSourceService")
	_expect(source_service != null and bool((source_service.call("debug_snapshot") as Dictionary).get("uses_role_catalog_public_projection", false)), "role Codex consumes RoleCatalog public projection")
	var audit: Dictionary = _diagnostics.call("role_balance_audit")
	_expect(int(audit.get("role_count", 0)) == role_count, "diagnostics_role_count_matches_catalog")
	_expect(_array(audit.get("duplicate_names", [])).is_empty(), "diagnostics_reports_no_duplicate_roles")
	_expect(_array(audit.get("missing_budget_roles", [])).is_empty(), "diagnostics_reports_no_missing_budget_roles")
	_expect(_array(audit.get("missing_positive_roles", [])).is_empty(), "diagnostics_reports_no_missing_positive_roles")
	var names := {}
	var saw_supply := false
	var saw_intel := false
	var saw_control := false
	for role_index in range(role_count):
		var role := _main.call("_make_player_role_card", 0, role_index) as Dictionary
		var role_name := str(role.get("name", ""))
		_expect(role_name != "" and not names.has(role_name), "role_%02d_has_unique_public_name" % role_index)
		names[role_name] = true
		_expect(str(role.get("species", "")) != "" and str(role.get("passive", "")) != "", "role_%02d_has_public_species_and_passive" % role_index)
		_expect(_starter_field_paths(role).is_empty(), "role_%02d_has_no_starter_monster_fingerprints|paths=%s" % [role_index, _starter_field_paths(role)])
		_expect(int(role.get("balance_budget", 0)) > 0 and not _array(role.get("balance_drivers", [])).is_empty() and not _array(role.get("balance_tags", [])).is_empty(), "role_%02d_has_balance_metadata_from_diagnostics" % role_index)
		var snapshot := _compose_role_snapshot(role, role_index, role_count)
		_expect(_role_snapshot_shape_ok(snapshot, role_name), "role_%02d_public_snapshot_shape" % role_index)
		_expect(_private_key_paths(snapshot).is_empty(), "role_%02d_public_snapshot_has_no_private_keys|paths=%s" % [role_index, _private_key_paths(snapshot)])
		var tags := _array(role.get("balance_tags", []))
		saw_supply = saw_supply or tags.has("supply")
		saw_intel = saw_intel or tags.has("intel")
		saw_control = saw_control or tags.has("monster") or tags.has("military") or tags.has("counter")
	_expect(names.size() == role_count, "all_public_role_names_are_distinct")
	_expect(saw_supply and saw_intel and saw_control, "role_catalog_keeps_supply_intel_and_control_routes")
	var rejected := _coordinator.call("role_codex_public_snapshot", 0, {"hidden_owner": "DO_NOT_LEAK"}) as Dictionary
	_expect(rejected.is_empty(), "private presentation input fails closed")
	_expect(not FileAccess.get_file_as_string("res://scripts/main.gd").contains("func _role_codex_public_source_snapshot("), "retired Main role source helper is physically absent")


func _test_random_role_resolution_without_run_state_wrapper() -> void:
	var previous_player_count := int(_main.get("configured_player_count"))
	var previous_ai_count := int(_main.get("configured_ai_player_count"))
	var previous_role_indices := _array(_main.get("configured_role_indices")).duplicate(true)
	var seat_count := 8
	var random_config := [0]
	for _index in range(1, seat_count):
		random_config.append(-1)
	_main.set("configured_player_count", seat_count)
	_main.set("configured_ai_player_count", seat_count - 1)
	_main.set("configured_role_indices", random_config)
	_main.call("_ensure_configured_role_indices")
	var configured := _array(_main.get("configured_role_indices"))
	_expect(configured.size() >= seat_count and int(configured[1]) == -1 and int(configured[7]) == -1, "setup_keeps_random_role_placeholders_before_run")
	_main.call("_new_game")
	var players := _array(((_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
	var used := {}
	var resolved_ok := players.size() == seat_count
	for player_variant in players:
		var player := player_variant as Dictionary
		var role := player.get("role_card", {}) as Dictionary
		var role_index := int(role.get("role_index", -1))
		if role_index < 0 or used.has(role_index) or str(role.get("name", "")) == "随机角色":
			resolved_ok = false
			break
		used[role_index] = true
	_expect(resolved_ok and used.size() == seat_count, "random_ai_roles_resolve_to_unique_public_roles")
	_restore_role_setup(previous_player_count, previous_ai_count, previous_role_indices)
	_expect(int(_main.get("configured_player_count")) == previous_player_count and int(_main.get("configured_ai_player_count")) == previous_ai_count and _array(((_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).size() == previous_player_count, "setup_scalar_restore_rebuilds_original_run_without_global_save_wrapper")


func _compose_role_snapshot(role: Dictionary, index: int, total: int) -> Dictionary:
	var value: Variant = _coordinator.call("role_codex_public_snapshot", index, {
		"accent": Color("#38bdf8"),
		"kpi_columns": 2,
		"route_columns": 2,
		"face": {"name": str(role.get("name", "角色")), "effect": str(role.get("passive", "")), "type": "公开角色", "rank": str(role.get("species", "角色"))},
		"face_effect": str(role.get("passive", "")),
	})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _role_snapshot_shape_ok(snapshot: Dictionary, role_name: String) -> bool:
	var board := snapshot.get("board", {}) as Dictionary
	return str(snapshot.get("summary_text", "")).contains(role_name) \
		and str(snapshot.get("route_label", "")).strip_edges() != "" \
		and _array(board.get("chips", [])).size() >= 2 \
		and _array(board.get("kpis", [])).size() == 4 \
		and _array(board.get("routes", [])).size() >= 6


func _restore_role_setup(player_count: int, ai_count: int, role_indices: Array) -> void:
	_main.set("configured_player_count", player_count)
	_main.set("configured_ai_player_count", ai_count)
	_main.set("configured_role_indices", role_indices.duplicate(true))
	_main.call("_ensure_configured_role_indices")
	_main.call("_new_game")


func _starter_field_paths(value: Variant, path: String = "$") -> Array[String]:
	var result: Array[String] = []
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant)
			var child_path := "%s.%s" % [path, key]
			if STARTER_ROLE_FIELDS.has(key):
				result.append(child_path)
			result.append_array(_starter_field_paths((value as Dictionary)[key_variant], child_path))
	elif value is Array:
		for index in range((value as Array).size()):
			result.append_array(_starter_field_paths((value as Array)[index], "%s[%d]" % [path, index]))
	return result


func _private_key_paths(value: Variant, path: String = "$") -> Array[String]:
	var result: Array[String] = []
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant)
			var child_path := "%s.%s" % [path, key]
			if PRIVATE_KEYS.has(key):
				result.append(child_path)
			result.append_array(_private_key_paths((value as Dictionary)[key_variant], child_path))
	elif value is Array:
		for index in range((value as Array).size()):
			result.append_array(_private_key_paths((value as Array)[index], "%s[%d]" % [path, index]))
	return result


func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if value is Array else []


func _cleanup() -> void:
	if _main != null:
		_main.queue_free()
	_main = null
	_coordinator = null
	_diagnostics = null
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
	push_error("ROLE_CODEX_PUBLIC_CONTRACT: %s" % label)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("ROLE_CODEX_PUBLIC_CONTRACT|status=%s|checks=%d|failures=%d|details=%s" % [status, _checks, _failures.size(), JSON.stringify(_failures)])
	quit(0 if _failures.is_empty() else 1)
