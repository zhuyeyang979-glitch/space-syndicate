extends Control
class_name MilitaryRuntimeCharacterizationBench

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const AI_CONTROLLER_SCRIPT_PATH := "res://scripts/runtime/ai_runtime_controller.gd"
const INVENTORY_SERVICE_SCRIPT_PATH := "res://scripts/runtime/card_inventory_runtime_service.gd"
const MONSTER_CONTROLLER_SCRIPT_PATH := "res://scripts/runtime/monster_runtime_controller.gd"
const MILITARY_CONTROLLER_SCENE_PATH := "res://scenes/runtime/MilitaryRuntimeController.tscn"
const MILITARY_CONTROLLER_SCRIPT_PATH := "res://scripts/runtime/military_runtime_controller.gd"
const MILITARY_WORLD_BRIDGE_SCENE_PATH := "res://scenes/runtime/MilitaryRuntimeWorldBridge.tscn"
const MILITARY_WORLD_BRIDGE_SCRIPT_PATH := "res://scripts/runtime/military_runtime_world_bridge.gd"
const COORDINATOR_SCENE_PATH := "res://scenes/runtime/GameRuntimeCoordinator.tscn"
const CITY_FIXTURES := preload("res://tests/helpers/city_world_fixture_factory.gd")
const OUTPUT_DIR := "user://space_syndicate_design_qa/military_runtime_characterization/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/military_runtime_hard_cutover_sprint_47.png"
const RULESET_ID := "v0.4"
const CASE_COUNT := 50
const FIXED_SEED := 460046
const SPRINT_46_MAIN_SHA256 := "22b6579f07eea66a8905ad2ec075b68de1c6d4ad2150a933d44c059164db7c25"
const SPRINT_46_MAIN_METRICS := {"total_lines": 29118, "nonblank_lines": 26073, "function_count": 1472, "top_level_variable_count": 155, "constant_count": 242}
const MILITARY_FAMILIES := [
	{"base": "行星防卫军", "type": "defense", "domain": "mixed", "deploy": "any"},
	{"base": "制空战斗机", "type": "fighter", "domain": "air", "deploy": "any"},
	{"base": "轨道轰炸机", "type": "bomber", "domain": "air", "deploy": "any"},
	{"base": "重装坦克", "type": "tank", "domain": "land", "deploy": "land"},
	{"base": "导弹阵地", "type": "missile", "domain": "land", "deploy": "land"},
	{"base": "潜航舰队", "type": "submarine", "domain": "sea", "deploy": "ocean"},
	{"base": "星海战舰", "type": "warship", "domain": "sea", "deploy": "ocean"},
]
const DELETION_CANDIDATES := [
	"_military_unit_movement_speed_mps", "_military_unit_type_label", "_military_unit_type_glyph",
	"_military_unit_motif", "_military_unit_color", "_military_domain_label",
	"_military_deploy_terrain_label", "_can_deploy_military_card_at_district",
	"_military_unit_terrain_move_multiplier", "_military_unit_mobility_summary",
	"_military_unit_gdp_pressure", "_military_unit_gdp_pressure_seconds",
	"_apply_military_gdp_pressure", "_military_unit_duration", "_military_unit_range",
	"_military_unit_move", "_military_unit_damage", "_military_unit_hp",
	"_military_unit_index_by_uid", "_owned_active_military_unit_index",
	"_owned_active_military_unit_count", "_oldest_owned_military_unit_index",
	"_invalidate_bound_military_commands", "_military_command_label",
	"_make_military_command_skill", "_military_command_order", "_grant_bound_military_commands",
	"_refresh_military_unit_from_skill", "_summon_military_unit_from_card",
	"_remove_military_unit", "_update_military_units", "_player_military_control_limit",
	"_active_military_unit_for_player", "_player_visible_military_count", "_trigger_military_command",
]

@export var auto_run := true

@onready var runtime_main_host: Control = %RuntimeMainHost
@onready var summary_label: Label = %SummaryLabel
@onready var status_label: Label = %StatusLabel
@onready var ownership_text: RichTextLabel = %OwnershipText
@onready var cases_text: RichTextLabel = %CasesText

var _runtime_main: Control
var _monster_controller: Node
var _military_controller: MilitaryRuntimeController
var _ai_controller: Node
var _inventory_service: Node
var _product_market_controller: Node
var _baseline_players: Array = []
var _baseline_districts: Array = []
var _baseline_product_market: Dictionary = {}
var _records: Array = []
var _failures: Array[String] = []
var _main_source := ""
var _ai_source := ""
var _inventory_source := ""
var _monster_source := ""
var _military_source := ""
var _coordinator_source := ""


func _ready() -> void:
	print("MilitaryRuntimeCharacterizationBench ready: auto_run=%s editor_hint=%s" % [auto_run, Engine.is_editor_hint()])
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_characterization_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func screenshot_path() -> String:
	return SCREENSHOT_PATH


func characterization_cases() -> Array:
	return [
		"military_call_graph_complete",
		"seven_real_military_families_exist",
		"rank_i_to_iv_progression",
		"unit_creation_shape_and_uid",
		"default_and_role_bonus_control_limit",
		"first_deploy_success",
		"duplicate_family_refresh_or_upgrade_order",
		"control_limit_rejects_atomically",
		"air_land_sea_deployment_rules",
		"terrain_movement_multiplier",
		"movement_starts_linear_not_teleport",
		"movement_arrival_commits_position",
		"duration_decrements_realtime",
		"duration_expiry_removes_unit",
		"removal_resequences_units",
		"bound_commands_granted",
		"fixed_commands_do_not_consume_normal_hand_limit",
		"command_order_and_labels",
		"command_cooldown_blocks_reuse",
		"move_command_causes_no_implicit_damage",
		"guard_command_behavior",
		"gdp_pressure_applies_once",
		"gdp_pressure_duration_and_expiry",
		"strike_district_is_explicit",
		"strike_route_is_explicit",
		"attack_monster_routes_to_monster_controller",
		"monster_damage_applies_exactly_once",
		"invalid_or_down_monster_target_is_atomic",
		"command_binding_invalidated_on_unit_exit",
		"player_and_ai_share_world_execution_route",
		"ai_remains_decision_owner_only",
		"card_inventory_remains_command_slot_owner",
		"current_save_shape",
		"legacy_save_defaults",
		"public_event_boundary",
		"private_owner_and_ai_plan_not_exposed",
		"sprint47_deletion_candidates_complete",
		"controller_scene_composition",
		"controller_api_contract",
		"coordinator_static_composition",
		"roster_owner_cutover",
		"lifecycle_owner_cutover",
		"movement_owner_cutover",
		"command_owner_cutover",
		"inventory_invalidation_routes_once",
		"monster_damage_routes_once",
		"save_owner_cutover",
		"ai_controller_binding",
		"pure_debug_snapshot",
		"main_legacy_military_absent",
	]


func build_characterization_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id_variant in characterization_cases():
		records.append(_record(str(case_id_variant), false, false, "preview"))
	return {
		"suite": "military-runtime-hard-cutover-v04",
		"ruleset_id": RULESET_ID,
		"runtime_owner": MILITARY_CONTROLLER_SCRIPT_PATH,
		"runtime_cutover_enabled": true,
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"case_count": CASE_COUNT,
		"record_count": records.size(),
		"observed_count": 0,
		"aligned_count": 0,
		"needs_design_decision_count": 0,
		"sprint46_main_sha256": SPRINT_46_MAIN_SHA256,
		"sprint46_main_metrics": SPRINT_46_MAIN_METRICS.duplicate(true),
		"records": records,
	}


func run_characterization_suite() -> void:
	_records.clear()
	_failures.clear()
	_main_source = FileAccess.get_file_as_string(MAIN_SCRIPT_PATH)
	_ai_source = FileAccess.get_file_as_string(AI_CONTROLLER_SCRIPT_PATH)
	_inventory_source = FileAccess.get_file_as_string(INVENTORY_SERVICE_SCRIPT_PATH)
	_monster_source = FileAccess.get_file_as_string(MONSTER_CONTROLLER_SCRIPT_PATH)
	_military_source = FileAccess.get_file_as_string(MILITARY_CONTROLLER_SCRIPT_PATH)
	_coordinator_source = FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	_prepare_output_dir()
	if not await _ensure_runtime_main():
		push_error("MilitaryRuntimeCharacterizationBench could not instantiate real main.tscn")
		if DisplayServer.get_name() == "headless":
			get_tree().quit(1)
		return
	for case_id_variant in characterization_cases():
		var case_id := str(case_id_variant)
		_reset_fixture()
		var record := _run_case(case_id)
		record["pure_data_checked"] = _is_data_only(record) and not _contains_runtime_object(record)
		record["passed"] = bool(record.get("observed", false)) and bool(record.get("pure_data_checked", false))
		_records.append(record)
		if not bool(record.get("passed", false)):
			_failures.append("%s: %s" % [case_id, str(record.get("notes", "observation failed"))])
	var metrics := _main_metrics()
	var deletion_achieved := int(SPRINT_46_MAIN_METRICS.get("nonblank_lines", 0)) > int(metrics.get("nonblank_lines", 0)) and int(SPRINT_46_MAIN_METRICS.get("function_count", 0)) > int(metrics.get("function_count", 0))
	if not deletion_achieved:
		_failures.append("Sprint 47 did not reduce main.gd military ownership")
	var manifest := {
		"suite": "military-runtime-hard-cutover-v04",
		"ruleset_id": RULESET_ID,
		"runtime_owner": MILITARY_CONTROLLER_SCRIPT_PATH,
		"runtime_cutover_enabled": true,
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"case_count": CASE_COUNT,
		"record_count": _records.size(),
		"observed_count": _count_flag("observed"),
		"aligned_count": _count_flag("contract_aligned"),
		"needs_design_decision_count": _count_flag("needs_design_decision"),
		"passed_count": _count_flag("passed"),
		"sprint46_main_sha256": SPRINT_46_MAIN_SHA256,
		"current_main_sha256": _main_source.sha256_text(),
		"main_deletion_achieved": deletion_achieved,
		"main_metrics": metrics,
		"records": _records.duplicate(true),
	}
	_write_text(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text(REPORT_PATH, _markdown_report(manifest))
	_update_ui(manifest)
	await get_tree().process_frame
	await get_tree().process_frame
	_save_screenshot()
	print("MilitaryRuntimeCharacterizationBench manifest: %s" % MANIFEST_PATH)
	print("MilitaryRuntimeCharacterizationBench report: %s" % REPORT_PATH)
	print("MilitaryRuntimeCharacterizationBench screenshot: %s" % SCREENSHOT_PATH)
	print("MilitaryRuntimeCharacterizationBench observed: %d/%d" % [_count_flag("observed"), CASE_COUNT])
	print("MilitaryRuntimeCharacterizationBench aligned: %d/%d; design_decisions=%d" % [_count_flag("contract_aligned"), CASE_COUNT, _count_flag("needs_design_decision")])
	print("MilitaryRuntimeCharacterizationBench main deletion achieved: %s sha=%s" % [str(deletion_achieved), _main_source.sha256_text()])
	if not _failures.is_empty():
		push_error("MilitaryRuntimeCharacterizationBench failed:\n- %s" % "\n- ".join(_failures))
	if DisplayServer.get_name() == "headless":
		_release_runtime_main()
		for _frame in range(4):
			await get_tree().process_frame
		get_tree().quit(0 if _failures.is_empty() else 1)


func run_suite() -> void:
	run_characterization_suite()


func _run_case(case_id: String) -> Dictionary:
	match case_id:
		"military_call_graph_complete": return _case_call_graph()
		"seven_real_military_families_exist": return _case_families()
		"rank_i_to_iv_progression": return _case_rank_progression()
		"unit_creation_shape_and_uid": return _case_unit_shape()
		"default_and_role_bonus_control_limit": return _case_control_limits()
		"first_deploy_success": return _case_first_deploy()
		"duplicate_family_refresh_or_upgrade_order": return _case_duplicate_refresh()
		"control_limit_rejects_atomically": return _case_control_limit_observation()
		"air_land_sea_deployment_rules": return _case_deployment_rules()
		"terrain_movement_multiplier": return _case_terrain_multiplier()
		"movement_starts_linear_not_teleport": return _case_movement_start()
		"movement_arrival_commits_position": return _case_movement_arrival()
		"duration_decrements_realtime": return _case_duration_tick()
		"duration_expiry_removes_unit": return _case_duration_expiry()
		"removal_resequences_units": return _case_removal_resequence()
		"bound_commands_granted": return _case_commands_granted()
		"fixed_commands_do_not_consume_normal_hand_limit": return _case_fixed_hand_exemption()
		"command_order_and_labels": return _case_command_order()
		"command_cooldown_blocks_reuse": return _case_command_cooldown()
		"move_command_causes_no_implicit_damage": return _case_move_no_damage()
		"guard_command_behavior": return _case_guard()
		"gdp_pressure_applies_once": return _case_gdp_once()
		"gdp_pressure_duration_and_expiry": return _case_gdp_expiry()
		"strike_district_is_explicit": return _case_strike_district()
		"strike_route_is_explicit": return _case_strike_route()
		"attack_monster_routes_to_monster_controller": return _case_attack_monster_route()
		"monster_damage_applies_exactly_once": return _case_monster_damage_once()
		"invalid_or_down_monster_target_is_atomic": return _case_invalid_monster_atomic()
		"command_binding_invalidated_on_unit_exit": return _case_binding_invalidated()
		"player_and_ai_share_world_execution_route": return _case_player_ai_route()
		"ai_remains_decision_owner_only": return _case_ai_boundary()
		"card_inventory_remains_command_slot_owner": return _case_inventory_boundary()
		"current_save_shape": return _case_save_shape()
		"legacy_save_defaults": return _case_legacy_save()
		"public_event_boundary": return _case_public_events()
		"private_owner_and_ai_plan_not_exposed": return _case_privacy()
		"sprint47_deletion_candidates_complete": return _case_deletion_candidates()
		"controller_scene_composition": return _case_controller_scene_composition()
		"controller_api_contract": return _case_controller_api_contract()
		"coordinator_static_composition": return _case_coordinator_static_composition()
		"roster_owner_cutover": return _case_roster_owner_cutover()
		"lifecycle_owner_cutover": return _case_lifecycle_owner_cutover()
		"movement_owner_cutover": return _case_movement_owner_cutover()
		"command_owner_cutover": return _case_command_owner_cutover()
		"inventory_invalidation_routes_once": return _case_inventory_invalidation_routes_once()
		"monster_damage_routes_once": return _case_monster_damage_routes_once()
		"save_owner_cutover": return _case_save_owner_cutover()
		"ai_controller_binding": return _case_ai_controller_binding()
		"pure_debug_snapshot": return _case_pure_debug_snapshot()
		"main_legacy_military_absent": return _case_main_legacy_military_absent()
	return _record(case_id, false, false, "Unknown military characterization case.")


func _case_call_graph() -> Dictionary:
	var controller_functions := ["summon_from_card", "tick", "trigger_command", "remove_unit", "to_save_data", "apply_save_data", "debug_snapshot"]
	var missing: Array = []
	for function_name_variant in controller_functions:
		if not _military_source.contains("func %s(" % str(function_name_variant)):
			missing.append(str(function_name_variant))
	var observed := missing.is_empty() and _coordinator_source.contains("func military_runtime_controller(") and _coordinator_source.contains("func tick_military(") and _coordinator_source.contains("func military_to_save_data(")
	return _record("military_call_graph_complete", observed, observed, "MilitaryRuntimeController and Coordinator own the complete roster/lifecycle/command/save graph; missing=%s." % str(missing))


func _case_families() -> Dictionary:
	var found: Array[String] = []
	var observed := true
	for family_variant in MILITARY_FAMILIES:
		var family: Dictionary = family_variant
		var card_id := "%s1" % str(family.get("base", ""))
		var skill: Dictionary = _runtime_main.call("_make_skill", card_id)
		observed = observed and str(skill.get("kind", "")) == "military_force" and str(skill.get("military_type", "defense")) == str(family.get("type", "")) and str(skill.get("military_domain", "mixed")) == str(family.get("domain", ""))
		found.append(card_id)
	return _record("seven_real_military_families_exist", observed and found.size() == 7, observed and found.size() == 7, "All seven Rank I runtime families exist: %s." % ", ".join(found), {"card_id": "seven-families"})


func _case_rank_progression() -> Dictionary:
	var observed := true
	var card_count := 0
	for family_variant in MILITARY_FAMILIES:
		var family: Dictionary = family_variant
		var prior_hp := 0
		var prior_damage := 0
		var prior_duration := 0.0
		for rank in range(1, 5):
			var card_id := "%s%d" % [str(family.get("base", "")), rank]
			var skill: Dictionary = _runtime_main.call("_make_skill", card_id)
			var hp := int(skill.get("military_hp", 0))
			var damage := int(skill.get("military_damage", 0))
			var duration := float(skill.get("military_duration_seconds", 0.0))
			observed = observed and str(skill.get("kind", "")) == "military_force" and hp > 0 and damage > 0 and duration > 0.0
			if rank > 1:
				observed = observed and hp >= prior_hp and damage >= prior_damage and duration >= prior_duration
			prior_hp = hp
			prior_damage = damage
			prior_duration = duration
			card_count += 1
	return _record("rank_i_to_iv_progression", observed and card_count == 28, observed and card_count == 28, "Twenty-eight I-IV military assets load with non-decreasing HP, damage, and duration.", {"card_id": "I-IV"})


func _case_unit_shape() -> Dictionary:
	var district_index := _first_district("land")
	var deployed := _deploy("行星防卫军1", 0, district_index)
	var units := _units()
	var unit: Dictionary = units[0] if units.size() == 1 else {}
	var required := ["uid", "owner", "position", "world_position", "cooldown_left", "public_owner_revealed", "rank", "name", "source_card", "military_type", "military_domain", "movement_traits", "terrain_move_multiplier", "hp", "max_hp", "damage", "range", "move", "duration", "remaining_time"]
	var observed := deployed and units.size() == 1 and _military_controller.next_military_unit_uid == 2
	for key in required:
		observed = observed and unit.has(key)
	return _record("unit_creation_shape_and_uid", observed, observed, "First unit receives UID 1, advances next UID to 2, and carries the characterized state envelope.", {"card_id": "行星防卫军1", "unit_uid": int(unit.get("uid", 0)), "unit_count_delta": units.size()})


func _case_control_limits() -> Dictionary:
	_set_role(0, "")
	var default_limit := _military_controller.player_control_limit(0)
	var role_set := _set_role(1, "蜂巢防务议会")
	var bonus_limit := _military_controller.player_control_limit(1)
	var observed := default_limit == 1 and role_set and bonus_limit == 2
	return _record("default_and_role_bonus_control_limit", observed, observed, "Default military control is one; 蜂巢防务议会 raises it to two.")


func _case_first_deploy() -> Dictionary:
	_set_role(0, "")
	var district_index := _first_district("land")
	var before := _units().size()
	var deployed := _deploy("行星防卫军1", 0, district_index)
	var units := _units()
	var unit: Dictionary = units[0] if not units.is_empty() else {}
	var commands := _bound_commands(0, int(unit.get("uid", 0)))
	var observed := deployed and units.size() == before + 1 and int(unit.get("position", -1)) == district_index and commands.size() >= 1
	return _record("first_deploy_success", observed, observed, "A legal Rank I deployment creates one unit and grants its first private bound command.", {"card_id": "行星防卫军1", "unit_uid": int(unit.get("uid", 0)), "start_district": district_index, "unit_count_delta": units.size() - before, "inventory_checked": true})


func _case_duplicate_refresh() -> Dictionary:
	_set_role(0, "")
	var first_district := _first_district("land")
	var second_district := _different_district(first_district, "land")
	var first_ok := _deploy("行星防卫军1", 0, first_district)
	var first_units := _units()
	var uid := int((first_units[0] as Dictionary).get("uid", 0)) if not first_units.is_empty() else 0
	var old_commands := _bound_commands(0, uid).size()
	var second_ok := _deploy("行星防卫军2", 0, second_district)
	var units := _units()
	var unit: Dictionary = units[0] if units.size() == 1 else {}
	var invalidated := _invalidated_command_count(0)
	var new_commands := _bound_commands(0, uid).size()
	var observed := first_ok and second_ok and units.size() == 1 and int(unit.get("uid", 0)) == uid and int(unit.get("rank", 0)) == 2 and int(unit.get("position", -1)) == second_district and old_commands >= 1 and invalidated >= old_commands and new_commands >= 2
	return _record("duplicate_family_refresh_or_upgrade_order", observed, observed, "At the default cap, the oldest unit keeps its UID, refreshes to the new rank/location, invalidates old commands, then grants new commands.", {"card_id": "行星防卫军2", "unit_uid": uid, "start_district": first_district, "target_district": second_district, "inventory_checked": true})


func _case_control_limit_observation() -> Dictionary:
	var role_set := _set_role(0, "蜂巢防务议会")
	var d0 := _first_district("land")
	var d1 := _different_district(d0, "land")
	var d2 := _different_district(d1, "land", [d0])
	var first := _deploy("行星防卫军1", 0, d0)
	var second := _deploy("制空战斗机1", 0, d1)
	var before := _units().duplicate(true)
	var third := _deploy("轨道轰炸机1", 0, d2)
	var after := _units()
	var replacement_count := 0
	for unit_variant in after:
		if unit_variant is Dictionary and str((unit_variant as Dictionary).get("source_card", "")) == "轨道轰炸机1":
			replacement_count += 1
	var before_uids: Array[int] = []
	for unit_variant in before:
		before_uids.append(int((unit_variant as Dictionary).get("uid", 0)))
	var retained_uid := false
	for unit_variant in after:
		retained_uid = retained_uid or before_uids.has(int((unit_variant as Dictionary).get("uid", 0)))
	var refreshed_not_rejected := role_set and first and second and third and before.size() == 2 and after.size() == 2 and replacement_count == 1 and retained_uid
	return _record("control_limit_rejects_atomically", refreshed_not_rejected, refreshed_not_rejected, "Sprint 47 preserves the observed atomic replacement: reaching the cap refreshes the shortest-remaining unit instead of creating a third unit. role=%s first=%s second=%s third=%s before=%d after=%d replacements=%d" % [str(role_set), str(first), str(second), str(third), before.size(), after.size(), replacement_count], {"card_id": "轨道轰炸机1", "unit_count_delta": after.size() - before.size()})


func _case_deployment_rules() -> Dictionary:
	var land := _first_district("land")
	var ocean := _first_district("ocean")
	var fighter: Dictionary = _runtime_main.call("_make_skill", "制空战斗机1")
	var tank: Dictionary = _runtime_main.call("_make_skill", "重装坦克1")
	var submarine: Dictionary = _runtime_main.call("_make_skill", "潜航舰队1")
	var observed := _military_controller.can_deploy_at_district(fighter, land) and _military_controller.can_deploy_at_district(fighter, ocean) and _military_controller.can_deploy_at_district(tank, land) and not _military_controller.can_deploy_at_district(tank, ocean) and not _military_controller.can_deploy_at_district(submarine, land) and _military_controller.can_deploy_at_district(submarine, ocean)
	return _record("air_land_sea_deployment_rules", observed, observed, "Air deploys on land/ocean, land forces require land, and sea forces require ocean.")


func _case_terrain_multiplier() -> Dictionary:
	var land := _first_district("land")
	var ocean := _first_district("ocean")
	var fighter: Dictionary = _runtime_main.call("_make_skill", "制空战斗机1")
	var tank: Dictionary = _runtime_main.call("_make_skill", "重装坦克1")
	var submarine: Dictionary = _runtime_main.call("_make_skill", "潜航舰队1")
	var tank_land := _military_controller.terrain_move_multiplier(tank, land)
	var tank_ocean := _military_controller.terrain_move_multiplier(tank, ocean)
	var sub_land := _military_controller.terrain_move_multiplier(submarine, land)
	var sub_ocean := _military_controller.terrain_move_multiplier(submarine, ocean)
	var fighter_land := _military_controller.terrain_move_multiplier(fighter, land)
	var fighter_ocean := _military_controller.terrain_move_multiplier(fighter, ocean)
	var observed := tank_land > tank_ocean and sub_ocean > sub_land and fighter_land > 1.0 and fighter_ocean > 1.0
	return _record("terrain_movement_multiplier", observed, observed, "Terrain multipliers preserve tank-land, submarine-ocean, and fighter-cross-terrain identities.")


func _case_movement_start() -> Dictionary:
	var start := _first_district("land")
	var target := _different_district(start)
	var unit := _make_unit("制空战斗机2", 0, start, 46001)
	unit["remaining_time"] = 999.0
	_military_controller.replace_runtime_state([unit], 46002)
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = target
	var before: Vector2 = unit.get("world_position", Vector2.ZERO)
	var command := _military_controller.make_command_skill("move", 2, 46001, "制空战斗机2")
	var resolved := _military_controller.trigger_command(command, -1, 0)
	var after: Dictionary = _units()[0] if not _units().is_empty() else {}
	var target_position: Vector2 = _runtime_main.call("_district_center", target)
	var observed := resolved and after.has("linear_move_target_position") and int(after.get("position", -1)) == start and (after.get("world_position", Vector2.ZERO) as Vector2).distance_to(before) < 0.01 and (after.get("world_position", Vector2.ZERO) as Vector2).distance_to(target_position) > 0.5
	return _record("movement_starts_linear_not_teleport", observed, observed, "Move command stores a linear-motion target and leaves the unit at its start until realtime ticks advance it.", {"card_id": "制空战斗机2", "unit_uid": 46001, "command": "move", "start_district": start, "target_district": target})


func _case_movement_arrival() -> Dictionary:
	var start := _first_district("land")
	var target := _different_district(start)
	var unit := _make_unit("制空战斗机2", 0, start, 46002)
	unit["remaining_time"] = 999.0
	_military_controller.replace_runtime_state([unit], 46003)
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = target
	var command := _military_controller.make_command_skill("move", 2, 46002, "制空战斗机2")
	var resolved := _military_controller.trigger_command(command, -1, 0)
	var moving: Dictionary = _units()[0] if not _units().is_empty() else {}
	var target_position: Vector2 = moving.get("linear_move_target_position", Vector2.ZERO)
	var current_position: Vector2 = moving.get("world_position", Vector2.ZERO)
	var distance := float(_runtime_main.call("_wrapped_distance", current_position, target_position))
	var speed := maxf(1.0, float(moving.get("linear_move_speed_mps", 1.0)))
	_military_controller.tick(distance / speed + 0.2)
	var arrived: Dictionary = _units()[0] if not _units().is_empty() else {}
	var final_distance := float(_runtime_main.call("_wrapped_distance", arrived.get("world_position", Vector2.ZERO), _runtime_main.call("_district_center", target)))
	var committed_world_position := resolved and int(arrived.get("position", -1)) >= 0 and not arrived.has("linear_move_target_position") and final_distance <= 1.0
	var district_index_aligned := int(arrived.get("position", -1)) == target
	return _record("movement_arrival_commits_position", committed_world_position, district_index_aligned, "Observed: realtime movement reaches the requested world position and clears motion metadata, but geometry recomputes district=%d for requested target=%d (final_distance=%.3f). Sprint 47 must choose requested target identity versus polygon lookup identity." % [int(arrived.get("position", -1)), target, final_distance], {"card_id": "制空战斗机2", "unit_uid": 46002, "command": "move", "start_district": start, "target_district": target, "needs_design_decision": not district_index_aligned, "risk": "Overlapping or wrapped district polygons can make arrival position identity differ from the requested target district."})


func _case_duration_tick() -> Dictionary:
	var district_index := _first_district("land")
	var unit := _make_unit("重装坦克1", 0, district_index, 46003)
	unit["remaining_time"] = 10.0
	unit["cooldown_left"] = 4.0
	_military_controller.replace_runtime_state([unit], 46004)
	_military_controller.tick(2.0)
	var after: Dictionary = _units()[0] if not _units().is_empty() else {}
	var observed := is_equal_approx(float(after.get("remaining_time", -1.0)), 8.0) and is_equal_approx(float(after.get("cooldown_left", -1.0)), 2.0)
	return _record("duration_decrements_realtime", observed, observed, "Unit lifetime and command cooldown both decrement by scaled realtime delta.", {"card_id": "重装坦克1", "unit_uid": 46003, "duration_delta": -2.0, "cooldown_delta": -2.0})


func _case_duration_expiry() -> Dictionary:
	var district_index := _first_district("land")
	var unit := _make_unit("行星防卫军1", 0, district_index, 46004)
	unit["remaining_time"] = 0.1
	_military_controller.replace_runtime_state([unit], 46005)
	_military_controller.tick(0.2)
	var observed := _units().is_empty()
	return _record("duration_expiry_removes_unit", observed, observed, "A unit at zero remaining time leaves the roster in the same realtime tick.", {"card_id": "行星防卫军1", "unit_uid": 46004, "unit_count_delta": -1, "duration_delta": -0.1})


func _case_removal_resequence() -> Dictionary:
	var district_index := _first_district("land")
	_military_controller.replace_runtime_state([_make_unit("行星防卫军1", 0, district_index, 1), _make_unit("制空战斗机1", 1, district_index, 2), _make_unit("轨道轰炸机1", 2, district_index, 3)], 4)
	_military_controller.remove_unit(1, "characterization")
	var units := _units()
	var observed := units.size() == 2 and int((units[0] as Dictionary).get("uid", 0)) == 1 and int((units[1] as Dictionary).get("uid", 0)) == 3 and _military_controller.unit_index_by_uid(3) == 1
	return _record("removal_resequences_units", observed, observed, "Removing the middle unit compacts roster indices while preserving surviving UIDs.", {"unit_uid": 2, "unit_count_delta": -1})


func _case_commands_granted() -> Dictionary:
	var district_index := _first_district("land")
	var deployed := _deploy("轨道轰炸机4", 0, district_index)
	var unit: Dictionary = _units()[0] if not _units().is_empty() else {}
	var commands := _bound_commands(0, int(unit.get("uid", 0)))
	var command_ids: Array[String] = []
	for skill_variant in commands:
		command_ids.append(str((skill_variant as Dictionary).get("military_command", "")))
	var observed := deployed and command_ids == ["move", "guard", "strike_district", "attack_monster"]
	return _record("bound_commands_granted", observed, observed, "Rank IV grants four persistent commands in stable order, all bound to the unit UID.", {"card_id": "轨道轰炸机4", "unit_uid": int(unit.get("uid", 0)), "inventory_checked": true})


func _case_fixed_hand_exemption() -> Dictionary:
	var players: Array = ((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players
	var player: Dictionary = (players[0] as Dictionary).duplicate(true)
	var slots: Array = []
	for _index in range(5):
		slots.append(_runtime_main.call("_make_skill", "轨道融资1"))
	player["slots"] = slots
	players[0] = player
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
	var before := int(_runtime_main.call("_player_counted_hand_size", player))
	var granted := _military_controller.grant_bound_commands(0, 46005, 1, "行星防卫军1", 1)
	var after_player: Dictionary = (((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players as Array)[0]
	var after := int(_runtime_main.call("_player_counted_hand_size", after_player))
	var observed := before == 5 and granted.size() == 1 and after == 5 and (after_player.get("slots", []) as Array).size() == 6
	return _record("fixed_commands_do_not_consume_normal_hand_limit", observed, observed, "A fixed military command can be received at five ordinary cards and does not increase counted hand size.", {"card_id": "行星防卫军1", "unit_uid": 46005, "inventory_checked": true})


func _case_command_order() -> Dictionary:
	var order := _military_controller.command_order()
	var expected := ["move", "guard", "strike_district", "attack_monster"]
	var names: Array[String] = []
	for command_variant in order:
		var command := str(command_variant)
		var skill := _military_controller.make_command_skill(command, 2, 46006, "行星防卫军2")
		names.append(str(skill.get("name", "")))
	var observed := order == expected and names == ["军令·前进2", "军令·保卫区域2", "军令·摧毁区域2", "军令·攻击怪兽2"]
	return _record("command_order_and_labels", observed, observed, "Command order is move, guard, strike district, attack monster with stable labels.", {"unit_uid": 46006})


func _case_command_cooldown() -> Dictionary:
	var district_index := _first_district("land")
	var unit := _make_unit("行星防卫军2", 0, district_index, 46007)
	unit["range"] = 99999.0
	_military_controller.replace_runtime_state([unit], 46008)
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = district_index
	var command := _military_controller.make_command_skill("guard", 2, 46007, "行星防卫军2")
	var first := _military_controller.trigger_command(command, -1, 0)
	var cooldown := float((_units()[0] as Dictionary).get("cooldown_left", 0.0))
	var callouts_before := (_runtime_main.get("action_callouts") as Array).size()
	var second := _military_controller.trigger_command(command, -1, 0)
	var callouts_after := (_runtime_main.get("action_callouts") as Array).size()
	var observed := first and cooldown > 0.0 and not second and callouts_after == callouts_before
	return _record("command_cooldown_blocks_reuse", observed, observed, "A successful command starts cooldown; immediate reuse rejects without a second world event.", {"card_id": "行星防卫军2", "unit_uid": 46007, "command": "guard", "cooldown_delta": cooldown})


func _case_move_no_damage() -> Dictionary:
	var start := _first_district("land")
	var target := _different_district(start)
	var unit := _make_unit("制空战斗机2", 0, start, 46008)
	unit["remaining_time"] = 999.0
	_military_controller.replace_runtime_state([unit], 46009)
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = target
	var before_district: Dictionary = ((((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts as Array)[target] as Dictionary).duplicate(true)
	var command := _military_controller.make_command_skill("move", 2, 46008, "制空战斗机2")
	var resolved := _military_controller.trigger_command(command, -1, 0)
	var moving: Dictionary = _units()[0] if not _units().is_empty() else {}
	var distance := float(_runtime_main.call("_wrapped_distance", moving.get("world_position", Vector2.ZERO), moving.get("linear_move_target_position", Vector2.ZERO)))
	var speed := maxf(1.0, float(moving.get("linear_move_speed_mps", 1.0)))
	_military_controller.tick(distance / speed + 0.2)
	var after: Dictionary = (((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts as Array)[target]
	var observed := resolved and int(after.get("damage", 0)) == int(before_district.get("damage", 0)) and str(after.get("last_damage_source", "")) == str(before_district.get("last_damage_source", ""))
	return _record("move_command_causes_no_implicit_damage", observed, observed, "Move arrival may apply declared GDP pressure but never causes district or route strike damage.", {"card_id": "制空战斗机2", "unit_uid": 46008, "command": "move", "start_district": start, "target_district": target, "district_damage_delta": int(after.get("damage", 0)) - int(before_district.get("damage", 0))})


func _case_guard() -> Dictionary:
	var district_index := _prepare_city(0)
	var districts: Array = ((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts
	var district: Dictionary = (districts[district_index] as Dictionary).duplicate(true)
	district["damage"] = 4
	district["panic"] = 20
	var city: Dictionary = (district.get("city", {}) as Dictionary).duplicate(true)
	city["trade_route_damage"] = 3
	district["city"] = city
	districts[district_index] = district
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts
	var unit := _make_unit("行星防卫军3", 0, district_index, 46009)
	unit["range"] = 99999.0
	_military_controller.replace_runtime_state([unit], 46010)
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = district_index
	var command := _military_controller.make_command_skill("guard", 3, 46009, "行星防卫军3")
	var resolved := _military_controller.trigger_command(command, -1, 0)
	var after: Dictionary = (((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts as Array)[district_index]
	var after_city: Dictionary = after.get("city", {})
	var observed := resolved and int(after.get("damage", 0)) < 4 and int(after.get("panic", 0)) < 20 and int(after_city.get("trade_route_damage", 0)) < 3
	return _record("guard_command_behavior", observed, observed, "Guard explicitly repairs district and route pressure and reduces panic; it does not run autonomously.", {"card_id": "行星防卫军3", "unit_uid": 46009, "command": "guard", "target_district": district_index})


func _case_gdp_once() -> Dictionary:
	var district_index := _prepare_city(0)
	var unit := _make_unit("轨道轰炸机3", 0, district_index, 46010)
	var first: int = int(_military_controller.apply_gdp_pressure(unit, district_index, "strike_district", "anonymous-test"))
	var city_first: Dictionary = ((((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts as Array)[district_index] as Dictionary).get("city", {})
	var second: int = int(_military_controller.apply_gdp_pressure(unit, district_index, "strike_district", "anonymous-test"))
	var city_second: Dictionary = ((((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts as Array)[district_index] as Dictionary).get("city", {})
	var observed: bool = first > 0 and second == first and int(city_first.get("military_gdp_penalty", 0)) == first and int(city_second.get("military_gdp_penalty", 0)) == first and is_equal_approx(float(city_first.get("military_pressure_until", 0.0)), float(city_second.get("military_pressure_until", 0.0)))
	return _record("gdp_pressure_applies_once", observed, observed, "Repeated pressure uses max semantics rather than stacking the same penalty additively.", {"card_id": "轨道轰炸机3", "unit_uid": 46010, "command": "strike_district", "target_district": district_index, "gdp_pressure_delta": first})


func _case_gdp_expiry() -> Dictionary:
	var district_index := _prepare_city(0)
	var unit := _make_unit("制空战斗机1", 0, district_index, 46011)
	var pressure: int = int(_military_controller.apply_gdp_pressure(unit, district_index, "move", "anonymous-test"))
	var city: Dictionary = ((((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts as Array)[district_index] as Dictionary).get("city", {})
	var until := float(city.get("military_pressure_until", 0.0))
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).game_time = until + 0.1
	var market_controller := _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ProductMarketRuntimeController")
	if market_controller != null:
		market_controller.call("age_economic_boons", 0.1)
	var expired_city: Dictionary = ((((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts as Array)[district_index] as Dictionary).get("city", {})
	var observed: bool = pressure > 0 and until > 0.0 and int(expired_city.get("military_gdp_penalty", -1)) == 0 and str(expired_city.get("military_pressure_source", "x")) == ""
	return _record("gdp_pressure_duration_and_expiry", observed, observed, "Military GDP pressure records an absolute expiry and the existing economy aging pass clears penalty and source after it elapses.", {"card_id": "制空战斗机1", "unit_uid": 46011, "gdp_pressure_delta": pressure, "duration_delta": until})


func _case_strike_district() -> Dictionary:
	return _strike_case(false)


func _case_strike_route() -> Dictionary:
	return _strike_case(true)


func _strike_case(route_case: bool) -> Dictionary:
	var district_index := _prepare_city(1)
	var unit := _make_unit("轨道轰炸机3", 0, district_index, 46012 if not route_case else 46013)
	unit["range"] = 99999.0
	_military_controller.replace_runtime_state([unit], int(unit.get("uid", 0)) + 1)
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = district_index
	var before: Dictionary = ((((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts as Array)[district_index] as Dictionary).duplicate(true)
	var before_city: Dictionary = (before.get("city", {}) as Dictionary).duplicate(true)
	var command := _military_controller.make_command_skill("strike_district", 3, int(unit.get("uid", 0)), "轨道轰炸机3")
	var resolved := _military_controller.trigger_command(command, -1, 0)
	var after: Dictionary = (((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts as Array)[district_index]
	var after_city: Dictionary = after.get("city", {})
	var damage_delta := int(after.get("damage", 0)) - int(before.get("damage", 0))
	var route_delta := int(after_city.get("trade_route_damage", 0)) - int(before_city.get("trade_route_damage", 0))
	var observed := resolved and damage_delta == int(unit.get("damage", 0)) and route_delta == int(unit.get("military_strike_route_damage", 0))
	var case_id := "strike_route_is_explicit" if route_case else "strike_district_is_explicit"
	var note := "Explicit strike applies the declared route pressure exactly once alongside district damage." if route_case else "District damage changes only after the explicit strike command and equals unit damage."
	return _record(case_id, observed, observed, note, {"card_id": "轨道轰炸机3", "unit_uid": int(unit.get("uid", 0)), "command": "strike_district", "target_district": district_index, "district_damage_delta": damage_delta, "route_damage_delta": route_delta, "gdp_pressure_delta": int(after_city.get("military_gdp_penalty", 0))})


func _case_attack_monster_route() -> Dictionary:
	var result := _attack_monster_fixture(46014, false)
	var observed := bool(result.get("resolved", false)) and int(result.get("monster_damage", 0)) > 0 and _monster_controller != null and _monster_source.contains("func take_external_damage(") and _military_source.contains("_monster_runtime_controller.take_external_damage(target_slot, damage, source)") and not _military_source.contains("target_actor[\"hp\"]")
	return _record("attack_monster_routes_to_monster_controller", observed, observed, "Military validates and issues the attack command; MonsterRuntimeController owns armor/HP/down mutation.", {"card_id": "轨道轰炸机3", "unit_uid": 46014, "command": "attack_monster", "monster_damage_delta": int(result.get("monster_damage", 0)), "monster_controller_checked": true})


func _case_monster_damage_once() -> Dictionary:
	var result := _attack_monster_fixture(46015, false)
	var observed := bool(result.get("resolved", false)) and int(result.get("monster_damage", 0)) == int(result.get("unit_damage", -1))
	return _record("monster_damage_applies_exactly_once", observed, observed, "With zero armor, one military attack reduces monster HP by exactly one unit-damage amount.", {"card_id": "轨道轰炸机3", "unit_uid": 46015, "command": "attack_monster", "monster_damage_delta": int(result.get("monster_damage", 0)), "monster_controller_checked": true})


func _case_invalid_monster_atomic() -> Dictionary:
	var district_index := _first_district("land")
	var unit := _make_unit("轨道轰炸机3", 0, district_index, 46016)
	unit["range"] = 99999.0
	_military_controller.replace_runtime_state([unit], 46017)
	var actor: Dictionary = _monster_controller.call("_make_auto_monster", 0, 0, district_index, 2, 1)
	actor["world_position"] = unit.get("world_position", Vector2.ZERO)
	actor["down"] = true
	_monster_controller.set("auto_monsters", [actor])
	var hp_before := int(actor.get("hp", 0))
	var command := _military_controller.make_command_skill("attack_monster", 3, 46016, "轨道轰炸机3")
	var resolved := _military_controller.trigger_command(command, 0, 0)
	var after_unit: Dictionary = _units()[0]
	var after_actor: Dictionary = (_monster_controller.get("auto_monsters") as Array)[0]
	var observed := not resolved and is_zero_approx(float(after_unit.get("cooldown_left", 0.0))) and int(after_actor.get("hp", 0)) == hp_before
	return _record("invalid_or_down_monster_target_is_atomic", observed, observed, "Invalid/down monster rejection leaves unit cooldown and monster HP unchanged.", {"card_id": "轨道轰炸机3", "unit_uid": 46016, "command": "attack_monster", "monster_damage_delta": 0, "cooldown_delta": 0.0, "monster_controller_checked": true})


func _case_binding_invalidated() -> Dictionary:
	var district_index := _first_district("land")
	var deployed := _deploy("行星防卫军2", 0, district_index)
	var unit: Dictionary = _units()[0] if not _units().is_empty() else {}
	var uid := int(unit.get("uid", 0))
	var before := _bound_commands(0, uid).size()
	_military_controller.remove_unit(0, "characterization")
	var after_invalid := _invalidated_command_count(0)
	var observed := deployed and before >= 2 and _units().is_empty() and after_invalid >= before and _bound_commands(0, uid).is_empty()
	return _record("command_binding_invalidated_on_unit_exit", observed, observed, "Unit exit invalidates every bound command by clearing UID and applying an effectively permanent lock.", {"card_id": "行星防卫军2", "unit_uid": uid, "unit_count_delta": -1, "inventory_checked": true})


func _case_player_ai_route() -> Dictionary:
	var district_index := _prepare_city(0)
	var players: Array = ((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players
	var ai_player: Dictionary = (players[1] as Dictionary).duplicate(true)
	ai_player["is_ai"] = true
	players[1] = ai_player
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
	var player_unit := _make_unit("行星防卫军2", 0, district_index, 46017)
	var ai_unit := _make_unit("行星防卫军2", 1, district_index, 46018)
	player_unit["range"] = 99999.0
	ai_unit["range"] = 99999.0
	_military_controller.replace_runtime_state([player_unit, ai_unit], 46019)
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = district_index
	var player_command := _military_controller.make_command_skill("guard", 2, 46017, "行星防卫军2")
	var ai_command := _military_controller.make_command_skill("guard", 2, 46018, "行星防卫军2")
	var player_result := _military_controller.trigger_command(player_command, -1, 0)
	var ai_result := _military_controller.trigger_command(ai_command, -1, 1)
	var observed := player_result and ai_result and _military_source.count("func trigger_command(") == 1
	return _record("player_and_ai_share_world_execution_route", observed, observed, "Human and AI commands enter the same world mutation function; acting_player_index changes ownership validation, not the algorithm.", {"command": "guard", "ai_route_checked": true})


func _case_ai_boundary() -> Dictionary:
	var planning := _ai_source.contains("func _ai_military_command_plan(") and _ai_source.contains("func _ai_military_deploy_plan(")
	var no_world_owner := not _ai_source.contains("func _trigger_military_command(") and not _ai_source.contains("var next_military_unit_uid")
	var observed := _ai_controller != null and planning and no_world_owner and _military_source.contains("func trigger_command(") and not _main_source.contains("func _trigger_military_command(")
	return _record("ai_remains_decision_owner_only", observed, observed, "AiRuntimeController scores and selects military intents but owns neither roster UID nor world mutation.", {"ai_route_checked": true})


func _case_inventory_boundary() -> Dictionary:
	var coordinator := _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	var debug: Dictionary = coordinator.call("card_inventory_debug") if coordinator != null and coordinator.has_method("card_inventory_debug") else {}
	var source_boundary := _function_source(_military_source, "grant_bound_commands").contains("_acquire_inventory_skill_for_player") and _function_source(_inventory_source, "invalidate_bound_military_commands").contains("bound_military_uid")
	var granted := _military_controller.grant_bound_commands(0, 46019, 1, "行星防卫军1", 1)
	var observed := _inventory_service != null and bool(debug.get("service_authoritative", false)) and source_boundary and granted.size() == 1
	return _record("card_inventory_remains_command_slot_owner", observed, observed, "Military composes command definitions; CardInventoryRuntimeService remains the sole slot mutation owner.", {"card_id": "行星防卫军1", "unit_uid": 46019, "inventory_checked": true})


func _case_save_shape() -> Dictionary:
	var district_index := _first_district("land")
	var deployed := _deploy("行星防卫军1", 0, district_index)
	var state: Dictionary = _runtime_main.call("_capture_run_state")
	var saved_units: Array = state.get("military_units", []) if state.get("military_units", []) is Array else []
	var observed := deployed and state.has("military_units") and state.has("next_military_unit_uid") and saved_units.size() == 1 and int(state.get("next_military_unit_uid", 0)) == 2 and int((saved_units[0] as Dictionary).get("uid", 0)) == 1
	return _record("current_save_shape", observed, observed, "Current v1 envelope stores military_units and next_military_unit_uid without changing save version.", {"card_id": "行星防卫军1", "unit_uid": 1, "save_checked": true})


func _case_legacy_save() -> Dictionary:
	var state: Dictionary = _runtime_main.call("_capture_run_state")
	state.erase("military_units")
	state.erase("next_military_unit_uid")
	_military_controller.replace_runtime_state([_make_unit("行星防卫军1", 0, _first_district("land"), 99)], 100)
	var error := int(_runtime_main.call("_apply_run_state", state))
	var observed := error == OK and _units().is_empty() and _military_controller.next_military_unit_uid == 1
	return _record("legacy_save_defaults", observed, observed, "Missing legacy military keys restore to an empty roster and next UID 1.", {"save_checked": true})


func _case_public_events() -> Dictionary:
	var district_index := _first_district("land")
	var deployed := _deploy("行星防卫军1", 0, district_index)
	var callouts: Array = _runtime_main.get("action_callouts")
	var logs: Array = _runtime_main.get("log_lines")
	var public_text := JSON.stringify({"callouts": _plain_public_events(callouts), "logs": logs})
	var markers: Array = _runtime_main.call("_auto_monster_markers")
	var marker_safe := true
	for marker_variant in markers:
		if marker_variant is Dictionary and str((marker_variant as Dictionary).get("name", "")).begins_with("匿名"):
			marker_safe = marker_safe and not (marker_variant as Dictionary).has("owner") and not (marker_variant as Dictionary).has("player_index")
	var forbidden := ["hidden_owner", "private_owner", "private_target", "private_discard", "ai_private_plan"]
	var observed := deployed and public_text.contains("匿名") and marker_safe and not _contains_any(public_text.to_lower(), forbidden)
	return _record("public_event_boundary", observed, observed, "Deployment, map marker, command callout, and log use anonymous military identity and expose no private owner fields.", {"card_id": "行星防卫军1", "privacy_checked": true})


func _case_privacy() -> Dictionary:
	var district_index := _first_district("land")
	var deployed := _deploy("轨道轰炸机1", 0, district_index)
	var owner_view := _military_controller.visible_unit_count(0, 0)
	var rival_view := _military_controller.visible_unit_count(0, 1)
	var markers: Array = _runtime_main.call("_auto_monster_markers")
	var serialized := JSON.stringify(_plain_public_events(markers)).to_lower()
	var observed := deployed and owner_view == 1 and rival_view == 0 and not _contains_any(serialized, ["owner", "player_index", "private", "ai_plan", "target_player"])
	return _record("private_owner_and_ai_plan_not_exposed", observed, observed, "Owner can count its own unit; an unrevealed rival cannot. Public marker data carries no owner or AI-plan field.", {"card_id": "轨道轰炸机1", "privacy_checked": true, "ai_route_checked": true})


func _case_deletion_candidates() -> Dictionary:
	var remaining: Array[String] = []
	for function_name_variant in DELETION_CANDIDATES:
		var function_name := str(function_name_variant)
		if _main_source.contains("func %s(" % function_name):
			remaining.append(function_name)
	var state_absent := not _main_source.contains("var military_units := []") and not _main_source.contains("var next_military_unit_uid := 1")
	var constants_absent := not _main_source.contains("MILITARY_UNIT_DEFAULT_DURATION_SECONDS") and not _main_source.contains("MILITARY_UNIT_COMMAND_COOLDOWN_SECONDS")
	var observed := remaining.is_empty() and state_absent and constants_absent and DELETION_CANDIDATES.size() >= 30
	return _record("sprint47_deletion_candidates_complete", observed, observed, "Sprint 47 removed %d military functions plus roster/UID and four timing constants; remaining=%s." % [DELETION_CANDIDATES.size(), str(remaining)])


func _case_controller_scene_composition() -> Dictionary:
	var controller_scene := load(MILITARY_CONTROLLER_SCENE_PATH) as PackedScene
	var bridge_scene := load(MILITARY_WORLD_BRIDGE_SCENE_PATH) as PackedScene
	var observed := controller_scene != null and bridge_scene != null and _military_controller != null and _military_controller.get_script() != null
	return _record("controller_scene_composition", observed, observed, "MilitaryRuntimeController and its narrow WorldBridge are editable scene-owned runtime components.")


func _case_controller_api_contract() -> Dictionary:
	var required := ["configure", "reset_state", "tick", "roster_snapshot", "summon_from_card", "trigger_command", "remove_unit", "to_save_data", "apply_save_data", "debug_snapshot"]
	var missing: Array = []
	for method_name_variant in required:
		if _military_controller == null or not _military_controller.has_method(str(method_name_variant)):
			missing.append(str(method_name_variant))
	var observed := missing.is_empty()
	return _record("controller_api_contract", observed, observed, "Stable runtime API is present; missing=%s." % str(missing))


func _case_coordinator_static_composition() -> Dictionary:
	var scene_source := FileAccess.get_file_as_string(COORDINATOR_SCENE_PATH)
	var observed := scene_source.contains("MilitaryRuntimeController.tscn") and scene_source.contains("MilitaryRuntimeWorldBridge.tscn") and scene_source.contains("[node name=\"MilitaryRuntimeController\"") and scene_source.contains("[node name=\"MilitaryRuntimeWorldBridge\"")
	return _record("coordinator_static_composition", observed, observed, "GameRuntimeCoordinator statically owns both military runtime nodes.")


func _case_roster_owner_cutover() -> Dictionary:
	var observed := _military_source.contains("var military_units: Array = []") and _military_source.contains("var next_military_unit_uid := 1") and not _main_source.contains("var military_units := []") and not _main_source.contains("var next_military_unit_uid := 1")
	return _record("roster_owner_cutover", observed, observed, "Roster and UID state exist only in MilitaryRuntimeController.")


func _case_lifecycle_owner_cutover() -> Dictionary:
	var observed := _military_source.contains("func tick(") and _military_source.contains("func _update_units(") and _military_source.contains("func remove_unit(") and _coordinator_source.contains("func tick_military(") and not _main_source.contains("func _update_military_units(")
	return _record("lifecycle_owner_cutover", observed, observed, "Coordinator ticks the Controller; main has no lifecycle loop.")


func _case_movement_owner_cutover() -> Dictionary:
	var observed := _military_source.contains("func unit_movement_speed_mps(") and _military_source.contains("_start_entity_linear_motion") and _military_source.contains("_advance_entity_linear_motion") and not _main_source.contains("func _military_unit_movement_speed_mps(")
	return _record("movement_owner_cutover", observed, observed, "Terrain speed, linear movement start, arrival, and cooldown now share one Controller owner.")


func _case_command_owner_cutover() -> Dictionary:
	var observed := _military_source.contains("func make_command_skill(") and _military_source.contains("func grant_bound_commands(") and _military_source.contains("func trigger_command(") and not _main_source.contains("func _trigger_military_command(")
	return _record("command_owner_cutover", observed, observed, "Command definitions, grants, validation, and execution moved together.")


func _case_inventory_invalidation_routes_once() -> Dictionary:
	var controller_route := _military_source.count("invalidate_bound_military_commands") == 1 and _military_source.contains("_inventory_service.invalidate_bound_military_commands")
	var inventory_owner := _inventory_source.count("func invalidate_bound_military_commands(") == 1
	var observed := controller_route and inventory_owner and not _main_source.contains("func _invalidate_bound_military_commands(")
	return _record("inventory_invalidation_routes_once", observed, observed, "Unit exit asks the unique CardInventory owner to invalidate bound command slots exactly once.", {"inventory_checked": true})


func _case_monster_damage_routes_once() -> Dictionary:
	var observed := _military_source.count("take_external_damage(") == 1 and _monster_source.count("func take_external_damage(") == 1 and not _military_source.contains("actor[\"hp\"]")
	return _record("monster_damage_routes_once", observed, observed, "Military owns command execution while MonsterRuntimeController remains the only monster HP mutation owner.", {"monster_controller_checked": true})


func _case_save_owner_cutover() -> Dictionary:
	var observed := _military_source.contains("func to_save_data(") and _military_source.contains("func apply_save_data(") and _coordinator_source.contains("func military_to_save_data(") and _coordinator_source.contains("func apply_military_save_data(") and not _main_source.contains("\"military_units\": military_units")
	return _record("save_owner_cutover", observed, observed, "Controller owns current and legacy-default military save state while preserving v1 keys.", {"save_checked": true})


func _case_ai_controller_binding() -> Dictionary:
	var observed := _ai_source.contains("var _military_runtime_controller: MilitaryRuntimeController") and _ai_source.contains("func set_military_runtime_controller(") and _coordinator_source.contains("set_military_runtime_controller") and not _ai_source.contains("_world_value(&\"military_units\"")
	return _record("ai_controller_binding", observed, observed, "AI reads military facts from the Controller and remains decision-only.", {"ai_route_checked": true})


func _case_pure_debug_snapshot() -> Dictionary:
	var snapshot := _military_controller.debug_snapshot(-1)
	var serialized := JSON.stringify(snapshot).to_lower()
	var observed := _is_data_only(snapshot) and not _contains_runtime_object(snapshot) and not _contains_any(serialized, ["private_target", "private_discard", "ai_private_plan"])
	return _record("pure_debug_snapshot", observed, observed, "Debug snapshot is pure, public-safe data.", {"privacy_checked": true})


func _case_main_legacy_military_absent() -> Dictionary:
	var forbidden := ["var military_units := []", "var next_military_unit_uid := 1", "MILITARY_UNIT_DEFAULT_DURATION_SECONDS", "func _summon_military_unit_from_card(", "func _update_military_units(", "func _trigger_military_command(", "func _military_force_balance_report("]
	var remaining: Array = []
	for token_variant in forbidden:
		if _main_source.contains(str(token_variant)):
			remaining.append(str(token_variant))
	var observed := remaining.is_empty() and _main_source.contains("func _military_runtime_controller_node(")
	return _record("main_legacy_military_absent", observed, observed, "main.gd retains only its narrow military runtime adapter; legacy tokens=%s." % str(remaining))


func _ensure_runtime_main() -> bool:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		return false
	_runtime_main = packed.instantiate() as Control
	if _runtime_main == null:
		return false
	_runtime_main.name = "Main"
	_runtime_main.visible = false
	runtime_main_host.add_child(_runtime_main)
	_hide_runtime_canvas_layers()
	await get_tree().process_frame
	await get_tree().process_frame
	var runtime_coordinator := _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator
	var runtime_rng := runtime_coordinator.run_rng_service() if runtime_coordinator != null else null
	if runtime_rng != null:
		runtime_rng.seed = FIXED_SEED
	_runtime_main.call("_new_game")
	_hide_runtime_canvas_layers()
	await get_tree().process_frame
	await get_tree().process_frame
	_runtime_main.set_process(false)
	_monster_controller = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/MonsterRuntimeController")
	_military_controller = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/MilitaryRuntimeController") as MilitaryRuntimeController
	_ai_controller = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/AiRuntimeController")
	_inventory_service = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardInventoryRuntimeService")
	_product_market_controller = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ProductMarketRuntimeController")
	_baseline_players = (((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players as Array).duplicate(true)
	_baseline_districts = (((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts as Array).duplicate(true)
	_baseline_product_market = (_product_market_controller.call("to_save_data") as Dictionary).duplicate(true) if _product_market_controller != null else {}
	return _monster_controller != null and _military_controller != null and _ai_controller != null and _inventory_service != null and _product_market_controller != null and not _baseline_players.is_empty() and not _baseline_districts.is_empty()


func _reset_fixture() -> void:
	_runtime_main.set_process(false)
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = _baseline_players.duplicate(true)
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = _baseline_districts.duplicate(true)
	_product_market_controller.call("apply_save_data", _baseline_product_market.duplicate(true))
	_military_controller.reset_state()
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player = 0
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = _first_district("land")
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).game_time = 0.0
	_runtime_main.set("game_over", false)
	_runtime_main.set("movement_trails", [])
	_runtime_main.set("action_callouts", [])
	_runtime_main.set("map_event_effects", [])
	_runtime_main.set("log_lines", [])
	if _monster_controller.has_method("reset_state"):
		_monster_controller.call("reset_state")
	else:
		_monster_controller.set("auto_monsters", [])
	var players: Array = (((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players as Array).duplicate(true)
	for index in range(players.size()):
		var player: Dictionary = (players[index] as Dictionary).duplicate(true)
		player["slots"] = []
		player["cash"] = 5000
		player["eliminated"] = false
		player["is_ai"] = false
		player["action_cooldown"] = 0.0
		players[index] = player
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players


func _hide_runtime_canvas_layers() -> void:
	for node in _runtime_main.find_children("*", "CanvasLayer", true, false):
		if node is CanvasLayer:
			(node as CanvasLayer).visible = false


func _release_runtime_main() -> void:
	if _runtime_main != null and is_instance_valid(_runtime_main):
		for player_variant in _runtime_main.find_children("*", "AudioStreamPlayer", true, false):
			var audio := player_variant as AudioStreamPlayer
			if audio != null:
				audio.stop()
				audio.stream = null
		_runtime_main.queue_free()
	_runtime_main = null
	_monster_controller = null
	_military_controller = null
	_ai_controller = null
	_inventory_service = null


func _deploy(card_id: String, player_index: int, district_index: int) -> bool:
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player = player_index
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = district_index
	var skill: Dictionary = _runtime_main.call("_make_skill", card_id)
	return _military_controller.summon_from_card(player_index, skill)


func _make_unit(card_id: String, player_index: int, district_index: int, uid: int) -> Dictionary:
	var skill: Dictionary = _runtime_main.call("_make_skill", card_id)
	var unit := {
		"uid": uid,
		"owner": player_index,
		"position": district_index,
		"world_position": _runtime_main.call("_district_center", district_index),
		"cooldown_left": 0.0,
		"public_owner_revealed": false,
	}
	return _military_controller.refresh_unit_from_skill(unit, skill, district_index)


func _attack_monster_fixture(uid: int, down: bool) -> Dictionary:
	var district_index := _first_district("land")
	var unit := _make_unit("轨道轰炸机3", 0, district_index, uid)
	unit["range"] = 99999.0
	_military_controller.replace_runtime_state([unit], uid + 1)
	var actor: Dictionary = _monster_controller.call("_make_auto_monster", 0, 0, district_index, 2, 1)
	actor["world_position"] = unit.get("world_position", Vector2.ZERO)
	actor["armor"] = 0
	actor["hp"] = 50
	actor["max_hp"] = 50
	actor["down"] = down
	_monster_controller.set("auto_monsters", [actor])
	var hp_before := int(actor.get("hp", 0))
	var command := _military_controller.make_command_skill("attack_monster", 3, uid, "轨道轰炸机3")
	var resolved := _military_controller.trigger_command(command, 0, 0)
	var actors: Array = _monster_controller.get("auto_monsters")
	var after: Dictionary = actors[0] if not actors.is_empty() else {}
	return {"resolved": resolved, "monster_damage": hp_before - int(after.get("hp", hp_before)), "unit_damage": int(unit.get("damage", 0))}


func _prepare_city(owner_index: int) -> int:
	var district_index := _first_district("land")
	var city: Dictionary = CITY_FIXTURES.create_city_surface(_runtime_main, owner_index, district_index, "Military fixture")
	if city.is_empty():
		return -1
	return district_index


func _set_role(player_index: int, role_name: String) -> bool:
	var players: Array = (((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players as Array).duplicate(true)
	if player_index < 0 or player_index >= players.size():
		return false
	var player: Dictionary = (players[player_index] as Dictionary).duplicate(true)
	if role_name == "":
		player["role_card"] = {}
		players[player_index] = player
		((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
		return true
	for role_index in range(int(_runtime_main.call("_player_role_catalog_size"))):
		var role: Dictionary = _runtime_main.call("_make_player_role_card", player_index, role_index)
		if str(role.get("name", "")) == role_name:
			player["role_card"] = role
			players[player_index] = player
			((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
			return true
	return false


func _first_district(terrain: String = "") -> int:
	var districts: Array = ((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts if _runtime_main != null else _baseline_districts
	for index in range(districts.size()):
		var district: Dictionary = districts[index]
		if bool(district.get("destroyed", false)):
			continue
		if terrain == "" or str(district.get("terrain", "land")) == terrain:
			return index
	return 0


func _different_district(start_index: int, terrain: String = "", excluded: Array = []) -> int:
	var districts: Array = ((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts
	for index in range(districts.size()):
		if index == start_index or excluded.has(index):
			continue
		var district: Dictionary = districts[index]
		if bool(district.get("destroyed", false)):
			continue
		if terrain == "" or str(district.get("terrain", "land")) == terrain:
			return index
	return wrapi(start_index + 1, 0, districts.size())


func _units() -> Array:
	return _military_controller.roster_snapshot(true) if _military_controller != null else []


func _bound_commands(player_index: int, uid: int) -> Array:
	var result: Array = []
	var players: Array = ((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players
	if player_index < 0 or player_index >= players.size():
		return result
	for skill_variant in (players[player_index] as Dictionary).get("slots", []):
		if skill_variant is Dictionary and str((skill_variant as Dictionary).get("kind", "")) == "military_command" and int((skill_variant as Dictionary).get("bound_military_uid", 0)) == uid:
			result.append((skill_variant as Dictionary).duplicate(true))
	return result


func _invalidated_command_count(player_index: int) -> int:
	var count := 0
	var players: Array = ((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players
	if player_index < 0 or player_index >= players.size():
		return count
	for skill_variant in (players[player_index] as Dictionary).get("slots", []):
		if skill_variant is Dictionary and str((skill_variant as Dictionary).get("kind", "")) == "military_command" and int((skill_variant as Dictionary).get("bound_military_uid", 0)) == -1 and float((skill_variant as Dictionary).get("lock_left", 0.0)) >= 9999.0:
			count += 1
	return count


func _plain_public_events(values: Array) -> Array:
	var result: Array = []
	for value_variant in values:
		if not (value_variant is Dictionary):
			result.append(str(value_variant))
			continue
		var value: Dictionary = value_variant
		var entry := {}
		for key_variant in value.keys():
			var key := str(key_variant)
			var item: Variant = value[key_variant]
			if item == null or item is String or item is StringName or item is bool or item is int or item is float:
				entry[key] = item
		result.append(entry)
	return result


func _contains_any(text: String, tokens: Array) -> bool:
	for token_variant in tokens:
		if text.contains(str(token_variant).to_lower()):
			return true
	return false


func _function_source(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start < 0:
		return ""
	var next_function := source.find("\nfunc ", start + 5)
	return source.substr(start) if next_function < 0 else source.substr(start, next_function - start)


func _record(case_id: String, observed: bool, aligned: bool, notes: String, flags: Dictionary = {}) -> Dictionary:
	return {
		"case_id": case_id,
		"card_id": str(flags.get("card_id", "")),
		"unit_uid": int(flags.get("unit_uid", 0)),
		"command": str(flags.get("command", "")),
		"start_district": int(flags.get("start_district", -1)),
		"target_district": int(flags.get("target_district", -1)),
		"unit_count_delta": int(flags.get("unit_count_delta", 0)),
		"duration_delta": float(flags.get("duration_delta", 0.0)),
		"cooldown_delta": float(flags.get("cooldown_delta", 0.0)),
		"gdp_pressure_delta": int(flags.get("gdp_pressure_delta", 0)),
		"district_damage_delta": int(flags.get("district_damage_delta", 0)),
		"route_damage_delta": int(flags.get("route_damage_delta", 0)),
		"monster_damage_delta": int(flags.get("monster_damage_delta", 0)),
		"inventory_checked": bool(flags.get("inventory_checked", false)),
		"monster_controller_checked": bool(flags.get("monster_controller_checked", false)),
		"ai_route_checked": bool(flags.get("ai_route_checked", false)),
		"save_checked": bool(flags.get("save_checked", false)),
		"privacy_checked": bool(flags.get("privacy_checked", false)),
		"pure_data_checked": true,
		"observed": observed,
		"contract_aligned": aligned,
		"needs_design_decision": bool(flags.get("needs_design_decision", false)),
		"risk": str(flags.get("risk", "" if aligned else "Observed behavior differs from or is underspecified by the v0.4 contract.")),
		"passed": observed,
		"notes": notes,
	}


func _main_metrics() -> Dictionary:
	var lines := _main_source.split("\n")
	var total_lines := lines.size()
	if total_lines > 0 and str(lines[total_lines - 1]).is_empty():
		total_lines -= 1
	var nonblank := 0
	var functions := 0
	var variables := 0
	var constants := 0
	for line_variant in lines:
		var line := str(line_variant)
		if not line.strip_edges().is_empty():
			nonblank += 1
		if line.begins_with("func "):
			functions += 1
		elif line.begins_with("var "):
			variables += 1
		elif line.begins_with("const "):
			constants += 1
	return {"total_lines": total_lines, "nonblank_lines": nonblank, "function_count": functions, "top_level_variable_count": variables, "constant_count": constants}


func _count_flag(key: String) -> int:
	var count := 0
	for record_variant in _records:
		if record_variant is Dictionary and bool((record_variant as Dictionary).get(key, false)):
			count += 1
	return count


func _update_ui(manifest: Dictionary) -> void:
	var observed := int(manifest.get("observed_count", 0))
	var aligned := int(manifest.get("aligned_count", 0))
	var decisions := int(manifest.get("needs_design_decision_count", 0))
	summary_label.text = "Observed %d/%d | Aligned %d/%d | Design decisions %d" % [observed, CASE_COUNT, aligned, CASE_COUNT, decisions]
	status_label.text = "PASS" if _failures.is_empty() else "CUTOVER FAILURE"
	ownership_text.text = "[b]Current owner[/b]\nMilitaryRuntimeController roster + lifecycle + commands + save\n\n[b]External boundaries[/b]\nAI: intent selection only\nInventory: command slot mutation\nMonster: HP / armor / down state\n\n[b]Sprint 47[/b]\nLegacy main military engine deleted; no parallel fallback."
	var lines: Array[String] = []
	for record_variant in _records:
		var record: Dictionary = record_variant
		lines.append("%s %s | %s" % ["OK" if bool(record.get("observed", false)) else "FAIL", str(record.get("case_id", "")), "aligned" if bool(record.get("contract_aligned", false)) else "decision required"])
	cases_text.text = "\n".join(lines)


func _markdown_report(manifest: Dictionary) -> String:
	var lines: Array[String] = [
		"# Military Runtime Hard Cutover - Sprint 47",
		"",
		"Ruleset: `%s`" % RULESET_ID,
		"Runtime owner: `MilitaryRuntimeController`",
		"Observed: %d/%d" % [int(manifest.get("observed_count", 0)), CASE_COUNT],
		"Contract aligned: %d/%d" % [int(manifest.get("aligned_count", 0)), CASE_COUNT],
		"Design decisions: %d" % int(manifest.get("needs_design_decision_count", 0)),
		"Production main deletion achieved: `%s`" % str(manifest.get("main_deletion_achieved", false)),
		"",
		"## Ownership boundary",
		"",
		"- `MilitaryRuntimeController`: roster, UID, deployment/refresh, movement, duration, command execution, GDP/district/route orchestration, and save envelope.",
		"- `main.gd`: narrow world-fact adapter and existing shared world mutations only.",
		"- `AiRuntimeController`: decision and intent selection only.",
		"- `CardInventoryRuntimeService`: command-slot mutation only.",
		"- `MonsterRuntimeController`: monster armor, HP, down state, and monster save state.",
		"",
		"## Cases",
		"",
		"| Case | Card | Command | Observed | Aligned | Decision | Notes |",
		"| --- | --- | --- | --- | --- | --- | --- |",
	]
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant
		lines.append("| %s | %s | %s | %s | %s | %s | %s |" % [str(record.get("case_id", "")), str(record.get("card_id", "")), str(record.get("command", "")), str(record.get("observed", false)), str(record.get("contract_aligned", false)), str(record.get("needs_design_decision", false)), str(record.get("notes", "")).replace("|", "/")])
	return "\n".join(lines) + "\n"


func _prepare_output_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for file_name in ["manifest.json", "report.md"]:
		var path := OUTPUT_DIR + str(file_name)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failures.append("cannot write %s" % path)
		return
	file.store_string(content)
	file.close()


func _save_screenshot() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var image := get_viewport().get_texture().get_image()
	if image == null:
		_failures.append("viewport image unavailable")
		return
	var absolute_path := ProjectSettings.globalize_path(SCREENSHOT_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var error := image.save_png(absolute_path)
	if error != OK:
		_failures.append("screenshot save failed: %s" % error_string(error))


func _is_data_only(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item in value:
			if not _is_data_only(item):
				return false
		return true
	if value is Dictionary:
		for key in value.keys():
			if not _is_data_only(key) or not _is_data_only(value[key]):
				return false
		return true
	return false


func _contains_runtime_object(value: Variant) -> bool:
	if value is Callable or value is Object:
		return true
	if value is Array:
		for item in value:
			if _contains_runtime_object(item):
				return true
	if value is Dictionary:
		for key in value.keys():
			if _contains_runtime_object(key) or _contains_runtime_object(value[key]):
				return true
	return false
