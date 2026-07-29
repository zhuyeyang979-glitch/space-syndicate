extends SceneTree

const BASE_MAIN_SHA := "eef2465fcf61111b888581e1f6d209a5665c9407"
const BASE_MAIN_PHYSICAL_LINES := 5664
const BASE_MAIN_METHOD_COUNT := 440
const BASE_MAIN_TOP_LEVEL_VARIABLE_COUNT := 46
const BASE_MAIN_CONSTANT_COUNT := 44

const MAIN_PATH := "res://scripts/main.gd"
const GAME_SCREEN_SCENE_PATH := "res://scenes/ui/GameScreen.tscn"
const PLAYER_CARD_DOCK_SCENE_PATH := "res://scenes/ui/table/PlayerCardDock.tscn"

# Six primary product surfaces. Public feedback also has a separate expandable
# history scene below; it remains one typed responsibility family, not a second
# public-log owner.
const PRIMARY_SURFACE_SCENES := {
	"PlayerRosterPanel": "res://scenes/ui/table/PlayerRosterPanel.tscn",
	"PlayerInspectionPopup": "res://scenes/ui/table/PlayerInspectionPopup.tscn",
	"RegionSupplyPopup": "res://scenes/ui/table/RegionSupplyPopup.tscn",
	"CompactCurrentActionSurface": "res://scenes/ui/table/CompactCurrentActionSurface.tscn",
	"NonBlockingToastSurface": "res://scenes/ui/table/NonBlockingToastSurface.tscn",
	"ContextDetailDrawer": "res://scenes/ui/table/ContextDetailDrawer.tscn",
}
const EXPANDABLE_HISTORY_SCENE_PATH := "res://scenes/ui/table/ExpandablePublicHistorySurface.tscn"

const LEGACY_RIGHT_INSPECTOR_FILES := [
	"res://scenes/ui/RightInspector.tscn",
	"res://scripts/ui/right_inspector.gd",
	"res://scripts/viewmodels/right_inspector_snapshot.gd",
]
const LEGACY_SEAT_FILES := [
	"res://scenes/ui/planet_table/RoleSeatLayerHost.tscn",
	"res://scripts/ui/planet_table/role_seat_layer_host.gd",
	"res://scripts/ui/planet_table/role_seat_fallback.gd",
	"res://scripts/ui/planet_seat_layout.gd",
	"res://scripts/viewmodels/public_player_seat_snapshot.gd",
	"res://scripts/runtime/player_seat_public_source_service.gd",
	"res://scenes/runtime/PlayerSeatPublicSourceService.tscn",
]
const LEGACY_SEAT_POSITION_TOKENS := [
	"left_high",
	"left_mid_high",
	"left_mid",
	"left_mid_low",
	"left_low",
	"right_high",
	"right_mid_high",
	"right_mid",
	"right_mid_low",
	"right_low",
]
const LEGACY_SEAT_LAYOUT_TOKENS := [
	"LEFT_COLUMN_POSITIONS",
	"RIGHT_COLUMN_POSITIONS",
	"SIDE_SEAT_POSITIONS",
	"ORBIT_DECORATION_POSITIONS",
]
const LEGACY_ORBIT_PIP_TOKENS := [
	"SEAT_DECORATION_ANGLES",
	"seat_decoration_visibility",
	"set_seat_decoration_visibility",
	"orbit pips",
]
const MAIN_CONTEXTUAL_FORBIDDEN_TOKENS := [
	"PlayerRosterPanel",
	"PlayerInspectionPopup",
	"RegionSupplyPopup",
	"CompactCurrentActionSurface",
	"NonBlockingToastSurface",
	"ExpandablePublicHistorySurface",
	"ContextDetailDrawer",
	"TableInteractionModeV1",
	"public_player_roster",
	"player_inspection",
	"region_supply_popup",
	"current_action_context",
	"public_feedback_projection",
	"context_detail_projection",
	"table_interaction_mode",
]

var _checks := 0
var _failures: Array[String] = []
var _metrics := {}


func _init() -> void:
	if OS.get_cmdline_user_args().has("--parse-only"):
		print("ALPHA04B_LEGACY_RETIREMENT_AND_ARCHITECTURE_TEST|status=PARSE_ONLY_PASS")
		quit(0)
		return
	call_deferred("_run")


func _run() -> void:
	var all_sources := _all_sources()
	var production_sources := _production_sources()
	_test_right_inspector_retirement(production_sources, all_sources)
	_test_legacy_seat_retirement(production_sources)
	_test_new_surface_scenes()
	_test_production_scene_composition()
	_test_card_action_surface_uniqueness(production_sources)
	_test_main_budget_and_ownership()
	_finish()


func _test_right_inspector_retirement(
	production_sources: Dictionary,
	all_sources: Dictionary
) -> void:
	var scene_sources := _sources_with_extension(production_sources, "tscn")
	var node_count := _token_count(scene_sources, "[node name=\"RightInspector\"")
	var scroll_node_count := _token_count(scene_sources, "[node name=\"RightInspectorScroll\"")
	var scene_file_count := int(FileAccess.file_exists(LEGACY_RIGHT_INSPECTOR_FILES[0]))
	var script_file_count := int(FileAccess.file_exists(LEGACY_RIGHT_INSPECTOR_FILES[1]))
	var snapshot_file_count := int(FileAccess.file_exists(LEGACY_RIGHT_INSPECTOR_FILES[2]))
	var preload_reference_count := _token_count(all_sources, "RightInspector.tscn") \
		+ _token_count(all_sources, "right_inspector.gd")
	var script_reference_count := _token_count(all_sources, "SpaceSyndicateRightInspector") \
		+ _token_count(all_sources, "right_inspector.gd")
	var dynamic_call_count := _token_count(all_sources, "right_inspector.call(")
	var signal_connection_count := _line_count_with_all(all_sources, ["right_inspector", ".connect("])
	var snapshot_field_count := _right_inspector_snapshot_field_count(all_sources) + snapshot_file_count
	var fallback_count := _line_count_with_all_any(
		all_sources,
		["right_inspector"],
		["fallback", "get(\"right_inspector\"", "get(\"inspector\"", "_restore_right_inspector", "has_method"]
	)
	var all_reference_count := _token_count(all_sources, "right_inspector") \
		+ _token_count(all_sources, "RightInspector")
	_metrics.merge({
		"right_inspector_node_count": node_count,
		"right_inspector_scroll_node_count": scroll_node_count,
		"right_inspector_scene_file_count": scene_file_count,
		"right_inspector_script_file_count": script_file_count,
		"right_inspector_preload_reference_count": preload_reference_count,
		"right_inspector_script_reference_count": script_reference_count,
		"right_inspector_dynamic_call_count": dynamic_call_count,
		"right_inspector_signal_connection_count": signal_connection_count,
		"right_inspector_snapshot_field_count": snapshot_field_count,
		"right_inspector_fallback_count": fallback_count,
		"right_inspector_all_production_reference_count": all_reference_count,
	})
	_expect(node_count == 0, "production RightInspector node count is zero")
	_expect(scroll_node_count == 0, "production RightInspectorScroll node count is zero")
	_expect(scene_file_count == 0, "RightInspector scene is physically deleted")
	_expect(script_file_count == 0, "RightInspector script is physically deleted")
	_expect(snapshot_file_count == 0, "RightInspector-only snapshot script is physically deleted")
	_expect(preload_reference_count == 0, "RightInspector scene/script preload references are zero")
	_expect(script_reference_count == 0, "RightInspector script/class references are zero")
	_expect(dynamic_call_count == 0, "RightInspector dynamic calls are zero")
	_expect(signal_connection_count == 0, "RightInspector signal connections are zero")
	_expect(snapshot_field_count == 0, "RightInspector snapshot fields and owners are zero")
	_expect(fallback_count == 0, "RightInspector fallback paths are zero")
	_expect(all_reference_count == 0, "all production RightInspector symbol references are zero")


func _test_legacy_seat_retirement(sources: Dictionary) -> void:
	var scene_sources := _sources_with_extension(sources, "tscn")
	var role_host_nodes := _token_count(scene_sources, "[node name=\"RoleSeatLayerHost\"")
	var back_layer_nodes := _token_count(scene_sources, "[node name=\"BackSeatLayer\"")
	var front_layer_nodes := _token_count(scene_sources, "[node name=\"FrontSeatLayer\"")
	var role_host_refs := _token_count(sources, "RoleSeatLayerHost") \
		+ _token_count(sources, "role_seat_layer_host")
	var public_seat_snapshot_refs := _token_count(sources, "PublicPlayerSeatSnapshot") \
		+ _token_count(sources, "public_player_seat_snapshot")
	var public_seat_service_refs := _token_count(sources, "PlayerSeatPublicSourceService") \
		+ _token_count(sources, "player_seat_public_source_service")
	var seat_position_count := _token_count(sources, "seat_position")
	var old_position_count := 0
	for token in LEGACY_SEAT_POSITION_TOKENS:
		old_position_count += _token_count(sources, token)
	var left_right_layout_count := 0
	for token in LEGACY_SEAT_LAYOUT_TOKENS:
		left_right_layout_count += _token_count(sources, token)
	var seat_semantic_sources := _seat_semantic_sources(sources)
	var depth_group_count := _token_count(seat_semantic_sources, "depth_group")
	var mirror_h_count := _token_count(seat_semantic_sources, "mirror_h")
	var orbit_pip_count := 0
	for token in LEGACY_ORBIT_PIP_TOKENS:
		orbit_pip_count += _token_count(seat_semantic_sources, token)
	var legacy_file_count := 0
	for path in LEGACY_SEAT_FILES:
		legacy_file_count += int(FileAccess.file_exists(path))
	_metrics.merge({
		"role_seat_layer_host_node_count": role_host_nodes,
		"back_seat_layer_node_count": back_layer_nodes,
		"front_seat_layer_node_count": front_layer_nodes,
		"role_seat_layer_host_reference_count": role_host_refs,
		"public_seat_snapshot_reference_count": public_seat_snapshot_refs,
		"public_seat_service_reference_count": public_seat_service_refs,
		"public_seat_position_enum_count": seat_position_count,
		"legacy_orbit_player_position_count": old_position_count,
		"left_right_player_layout_count": left_right_layout_count,
		"legacy_seat_depth_group_count": depth_group_count,
		"legacy_seat_mirror_h_count": mirror_h_count,
		"visible_orbit_seat_pip_semantic_count": orbit_pip_count,
		"legacy_seat_file_count": legacy_file_count,
	})
	_expect(role_host_nodes == 0 and role_host_refs == 0, "RoleSeatLayerHost production nodes/references are zero")
	_expect(back_layer_nodes == 0, "BackSeatLayer production node count is zero")
	_expect(front_layer_nodes == 0, "FrontSeatLayer production node count is zero")
	_expect(public_seat_snapshot_refs == 0, "public seat snapshot references are zero")
	_expect(public_seat_service_refs == 0, "public seat source service references are zero")
	_expect(seat_position_count == 0, "public seat_position enum/field references are zero")
	_expect(old_position_count == 0, "legacy left/right orbit position ids are zero")
	_expect(left_right_layout_count == 0, "legacy left/right player layout definitions are zero")
	_expect(depth_group_count == 0, "legacy seat depth-group semantics are zero")
	_expect(mirror_h_count == 0, "legacy seat mirror semantics are zero")
	_expect(orbit_pip_count == 0, "visible orbit seat-pip semantics are zero")
	_expect(legacy_file_count == 0, "legacy seat host/layout/snapshot/service files are physically deleted")


func _test_new_surface_scenes() -> void:
	_expect(PRIMARY_SURFACE_SCENES.size() == 6, "exactly six primary contextual surface scenes are declared")
	var valid_primary_count := 0
	for root_name_variant in PRIMARY_SURFACE_SCENES.keys():
		var root_name := str(root_name_variant)
		var path := str(PRIMARY_SURFACE_SCENES[root_name_variant])
		if _scene_exists_and_has_root(path, root_name):
			valid_primary_count += 1
		else:
			_expect(false, "%s scene exists, loads and has the expected root" % root_name)
	_expect(valid_primary_count == PRIMARY_SURFACE_SCENES.size(), "all six primary contextual surface scenes load")
	_expect(
		_scene_exists_and_has_root(EXPANDABLE_HISTORY_SCENE_PATH, "ExpandablePublicHistorySurface"),
		"expandable public history support scene loads without creating a second log owner"
	)
	_metrics["primary_contextual_surface_scene_count"] = valid_primary_count


func _test_production_scene_composition() -> void:
	var packed := load(GAME_SCREEN_SCENE_PATH) as PackedScene
	_expect(packed != null, "production GameScreen scene loads")
	if packed == null:
		return
	var screen := packed.instantiate()
	_expect(screen != null, "production GameScreen instantiates without orphan NodePaths or connections")
	if screen == null:
		return
	var dock_count := screen.find_children("PlayerCardDock", "", true, false).size()
	_metrics["production_card_action_surface_count"] = dock_count
	_expect(screen.find_children("RightInspector", "", true, false).is_empty(), "instantiated GameScreen has no RightInspector")
	_expect(screen.find_children("RightInspectorScroll", "", true, false).is_empty(), "instantiated GameScreen has no RightInspectorScroll")
	_expect(screen.find_children("RoleSeatLayerHost", "", true, false).is_empty(), "instantiated GameScreen has no RoleSeatLayerHost")
	_expect(screen.find_children("BackSeatLayer", "", true, false).is_empty(), "instantiated GameScreen has no BackSeatLayer")
	_expect(screen.find_children("FrontSeatLayer", "", true, false).is_empty(), "instantiated GameScreen has no FrontSeatLayer")
	_expect(dock_count == 1, "instantiated GameScreen has exactly one PlayerCardDock card-action surface")
	screen.free()


func _test_card_action_surface_uniqueness(sources: Dictionary) -> void:
	var scene_sources := _sources_with_extension(sources, "tscn")
	var dock_scene_reference_count := _token_count(scene_sources, PLAYER_CARD_DOCK_SCENE_PATH.trim_prefix("res://"))
	var hand_rack_scene_reference_count := _token_count(scene_sources, "HandRack.tscn")
	var action_surface_source := FileAccess.get_file_as_string(
		"res://scripts/ui/table/compact_current_action_surface.gd"
	) if FileAccess.file_exists("res://scripts/ui/table/compact_current_action_surface.gd") else ""
	var typed_noncard_emitter_ready := action_surface_source.contains(
		"signal game_action_offer_requested(offer: Dictionary)"
	) and action_surface_source.count("game_action_offer_requested.emit(offer.duplicate(true))") == 1
	var card_play_filter_ready := action_surface_source.contains(
		"func _is_card_submission_offer(offer: Dictionary)"
	) and action_surface_source.contains("ACTION_INTENT.ACTION_CARD_PLAY") \
		and action_surface_source.contains("accepts_card_submission\": false") \
		and action_surface_source.contains("emits_card_action_offer\": false")
	var duplicate_action_offer_surface_count := hand_rack_scene_reference_count \
		+ int(not typed_noncard_emitter_ready or not card_play_filter_ready)
	_metrics["player_card_dock_scene_reference_count"] = dock_scene_reference_count
	_metrics["hand_rack_scene_reference_count"] = hand_rack_scene_reference_count
	_metrics["duplicate_action_offer_surface_count"] = duplicate_action_offer_surface_count
	_expect(dock_scene_reference_count == 1, "production scenes reference PlayerCardDock exactly once")
	_expect(hand_rack_scene_reference_count == 0, "production scenes have no legacy HandRack card-action surface")
	_expect(typed_noncard_emitter_ready, "CompactCurrentActionSurface emits one typed non-card offer route")
	_expect(card_play_filter_ready, "CompactCurrentActionSurface defensively rejects card-play offers")
	_expect(duplicate_action_offer_surface_count == 0, "no second card-play offer surface exists")


func _test_main_budget_and_ownership() -> void:
	var source := FileAccess.get_file_as_string(MAIN_PATH) if FileAccess.file_exists(MAIN_PATH) else ""
	_expect(not source.is_empty(), "main.gd is readable for the pinned architecture budget")
	var metrics := _main_metrics(source)
	_metrics["main_baseline_sha"] = BASE_MAIN_SHA
	_metrics["main_physical_lines"] = metrics.get("physical_lines", -1)
	_metrics["main_method_count"] = metrics.get("methods", -1)
	_metrics["main_top_level_variable_count"] = metrics.get("top_level_variables", -1)
	_metrics["main_constant_count"] = metrics.get("constants", -1)
	_expect(int(metrics.get("physical_lines", 0)) <= BASE_MAIN_PHYSICAL_LINES, "main.gd physical lines do not exceed the eef2465 hard baseline")
	_expect(int(metrics.get("methods", 0)) <= BASE_MAIN_METHOD_COUNT, "main.gd method count does not exceed the eef2465 hard baseline")
	_expect(int(metrics.get("top_level_variables", 0)) <= BASE_MAIN_TOP_LEVEL_VARIABLE_COUNT, "main.gd top-level variable count does not exceed the eef2465 hard baseline")
	_expect(int(metrics.get("constants", 0)) <= BASE_MAIN_CONSTANT_COUNT, "main.gd constant count does not exceed the eef2465 hard baseline")
	for token in MAIN_CONTEXTUAL_FORBIDDEN_TOKENS:
		_expect(not source.contains(token), "main.gd gains no contextual presentation ownership token: %s" % token)


func _production_sources() -> Dictionary:
	var result := _all_sources()
	for path_variant in result.keys().duplicate():
		if str(path_variant).contains("/tools/"):
			result.erase(path_variant)
	return result


func _all_sources() -> Dictionary:
	var paths: Array[String] = []
	_collect_files("res://scripts", paths)
	_collect_files("res://scenes", paths)
	paths.sort()
	var result := {}
	for path in paths:
		result[path] = FileAccess.get_file_as_string(path)
	return result


func _collect_files(root: String, result: Array[String]) -> void:
	var directory := DirAccess.open(root)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if not entry.begins_with("."):
			var path := root.path_join(entry)
			if directory.current_is_dir():
				_collect_files(path, result)
			elif path.get_extension() in ["gd", "tscn"]:
				result.append(path)
		entry = directory.get_next()
	directory.list_dir_end()


func _sources_with_extension(sources: Dictionary, extension: String) -> Dictionary:
	var result := {}
	for path_variant in sources.keys():
		var path := str(path_variant)
		if path.get_extension() == extension:
			result[path] = sources[path_variant]
	return result


func _seat_semantic_sources(sources: Dictionary) -> Dictionary:
	var result := {}
	for path_variant in sources.keys():
		var path := str(path_variant).to_lower()
		if path.contains("seat") or path.contains("planet_board") \
				or path.contains("planet_globe_backdrop"):
			result[path_variant] = sources[path_variant]
	return result


func _right_inspector_snapshot_field_count(sources: Dictionary) -> int:
	var count := 0
	for path_variant in sources.keys():
		var path := str(path_variant)
		if path.ends_with("table_snapshot.gd") \
				or path.ends_with("game_table_viewmodel_runtime_service.gd") \
				or path.ends_with("table_presentation_viewmodel_query.gd"):
			count += str(sources[path_variant]).count("right_inspector")
	return count


func _token_count(sources: Dictionary, token: String) -> int:
	var count := 0
	for source_variant in sources.values():
		count += str(source_variant).count(token)
	return count


func _line_count_with_all(sources: Dictionary, required_tokens: Array[String]) -> int:
	var count := 0
	for source_variant in sources.values():
		for line in str(source_variant).split("\n"):
			var matched := true
			for token in required_tokens:
				if not line.contains(token):
					matched = false
					break
			if matched:
				count += 1
	return count


func _line_count_with_all_any(
	sources: Dictionary,
	required_tokens: Array[String],
	any_tokens: Array[String]
) -> int:
	var count := 0
	for source_variant in sources.values():
		for line in str(source_variant).split("\n"):
			var required_match := true
			for token in required_tokens:
				if not line.contains(token):
					required_match = false
					break
			if not required_match:
				continue
			for token in any_tokens:
				if line.contains(token):
					count += 1
					break
	return count


func _scene_exists_and_has_root(path: String, expected_root_name: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var packed := load(path) as PackedScene
	if packed == null:
		return false
	var instance := packed.instantiate()
	if instance == null:
		return false
	var valid := instance.name == expected_root_name
	instance.free()
	return valid


func _main_metrics(source: String) -> Dictionary:
	var lines := source.split("\n", false)
	var methods := 0
	var variables := 0
	var constants := 0
	for line_variant in lines:
		var line := str(line_variant)
		if line.begins_with("func "):
			methods += 1
		elif line.begins_with("var "):
			variables += 1
		elif line.begins_with("const "):
			constants += 1
	return {
		"physical_lines": lines.size(),
		"methods": methods,
		"top_level_variables": variables,
		"constants": constants,
	}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print(
		"ALPHA04B_LEGACY_RETIREMENT_AND_ARCHITECTURE_TEST|status=%s|checks=%d|failures=%d|metrics=%s|terminal_owner_diff_audit=EXTERNAL" % [
			status,
			_checks,
			_failures.size(),
			JSON.stringify(_metrics),
		]
	)
	for failure in _failures:
		push_error("ALPHA04B_LEGACY_RETIREMENT_AND_ARCHITECTURE_TEST: %s" % failure)
	quit(0 if _failures.is_empty() else 1)
