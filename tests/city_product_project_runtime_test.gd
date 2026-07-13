extends SceneTree

const PROJECT_STATE := preload("res://scripts/economy/city_product_project_state.gd")
const PROJECT_BRIDGE := preload("res://scripts/economy/city_product_project_bridge.gd")
const REQUIREMENT_POLICY := preload("res://scripts/cards/card_play_requirement_policy.gd")
const TEMPLATE_PACK_PATH := "res://resources/economy/core_city_development_pack.tres"
const CONTROLLER_SCENE_PATH := "res://scenes/runtime/CityDevelopmentRuntimeController.tscn"
const RULESET_BRIDGE_SCENE_PATH := "res://scenes/runtime/RulesetRuntimeBridge.tscn"
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const ROUNDTRIP_PATH := "user://space_syndicate_design_qa/city_product_project_runtime_test.save"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_template_pack()
	_check_runtime_controller_cutover()
	_check_share_math_and_control()
	_check_legacy_migration()
	_check_gdp_allocation_and_privacy()
	_check_destroyed_district_stops_project_gdp()
	_check_save_load_roundtrip()
	if _failures.is_empty():
		print("City product project runtime test passed.")
	else:
		push_error("City product project runtime test failed:\n- " + "\n- ".join(_failures))
	quit(_failures.size())


func _check_template_pack() -> void:
	var pack: Resource = load(TEMPLATE_PACK_PATH)
	_expect(pack != null and pack.has_method("definitions_for_products"), "city development template pack loads as an Inspector resource")
	if pack == null:
		return
	var definitions: Dictionary = pack.call("definitions_for_products", ["活体芯片"])
	_expect(definitions.size() == 12, "one product expands to three directions across four ranks")
	var rank_one_directions := {}
	for definition_variant in definitions.values():
		var definition: Dictionary = definition_variant as Dictionary
		_expect(str(definition.get("kind", "")) == "city_development", "generated development card uses city_development runtime kind")
		_expect((definition.get("allowed_terrains", []) as Array).has("land"), "generated development cards support land districts")
		if int(definition.get("rank", 0)) == 1:
			rank_one_directions[str(definition.get("project_direction", ""))] = true
			var requirement: Dictionary = REQUIREMENT_POLICY.requirement_for(str(definition.get("name", "")), definition)
			_expect(int(requirement.get("required_share_percent", -1)) == 0 and int(definition.get("play_flow_required", -1)) == 0, "rank I development cards require no existing GDP share or legacy product flow")
	_expect(rank_one_directions.has("production") and rank_one_directions.has("demand") and rank_one_directions.has("commerce"), "rank I templates cover production, demand, and commerce")


func _check_runtime_controller_cutover() -> void:
	var controller_packed := load(CONTROLLER_SCENE_PATH) as PackedScene
	var bridge_packed := load(RULESET_BRIDGE_SCENE_PATH) as PackedScene
	_expect(controller_packed != null and bridge_packed != null, "city development controller and Ruleset bridge scenes load")
	if controller_packed == null or bridge_packed == null:
		return
	var controller := controller_packed.instantiate()
	var bridge := bridge_packed.instantiate()
	_expect(controller != null and controller.has_method("evaluate_development_request") and controller.has_method("record_project_opened") and controller.has_method("record_project_resolved"), "CityDevelopmentRuntimeController exposes cutover APIs")
	if controller == null or bridge == null:
		if controller != null:
			controller.free()
		if bridge != null:
			bridge.free()
		return
	controller.call("configure", bridge.call("debug_snapshot"))
	var direct_result: Dictionary = controller.call("evaluate_development_request", {
		"source_kind": "direct_city_build",
		"action_id": "build_city",
		"district_index": 2,
	})
	_expect(not bool(direct_result.get("allowed", true)) and str(direct_result.get("disabled_reason", "")).contains("不能直接建城"), "legacy direct build request is rejected with the v0.4 reason")
	var incomplete_result: Dictionary = controller.call("evaluate_development_request", {
		"source_kind": "city_development_card",
		"district_index": 2,
	})
	_expect(not bool(incomplete_result.get("allowed", true)) and str(incomplete_result.get("disabled_reason", "")).contains("绑定商品"), "development card requires a product project binding")
	var legal_request := {
		"source_kind": "city_development_card",
		"action_id": "play_city_development_card",
		"district_index": 2,
		"product_id": "活体芯片",
		"project_direction": "production",
		"project_id": "2:活体芯片:production",
	}
	var legal_result: Dictionary = controller.call("evaluate_development_request", legal_request)
	_expect(bool(legal_result.get("allowed", false)), "a real development card with district, product, direction, and project identity is accepted")
	controller.call("record_project_opened", legal_request.merged({"created_city_surface": true}, true))
	controller.call("record_project_resolved", legal_request.merged({
		"created_city_surface": true,
		"current_gdp": 37,
		"own_share_percent": 50.0,
	}, true))
	var controller_snapshot: Dictionary = controller.call("debug_snapshot")
	_expect(bool(controller_snapshot.get("controller_ready", false)) and int(controller_snapshot.get("project_count", 0)) == 1 and str((((controller_snapshot.get("projects", []) as Array)[0]) as Dictionary).get("state", "")) == "resolved", "valid product project opens and resolves through the controller lifecycle")
	_expect(not _contains_runtime_object(controller_snapshot) and not controller_snapshot.has("owner") and not controller_snapshot.has("player_index"), "controller privacy snapshot remains pure data without owner identity")
	var main_packed := load(MAIN_SCENE_PATH) as PackedScene
	var main := main_packed.instantiate() if main_packed != null else null
	_expect(main != null, "main scene instantiates for direct-action emission check")
	if main != null:
		main.set("players", [{"cash": 10, "slots": []}])
		main.set("districts", [])
		main.set("selected_district", -1)
		var quick_actions: Array = main.call("_runtime_player_board_quick_actions", 0)
		var quick_ids: Array[String] = []
		for action_variant in quick_actions:
			quick_ids.append(str((action_variant as Dictionary).get("id", "")))
		_expect(not quick_ids.has("build") and not quick_ids.has("build_city"), "direct build action is not emitted by the runtime PlayerBoard bridge")
		main.free()
	controller.free()
	bridge.free()


func _check_share_math_and_control() -> void:
	var project := PROJECT_STATE.create_project(2, "活体芯片", "production", 0, 1, 10)
	project = PROJECT_STATE.contribute(project, 1, 1, 11)
	var shares: Dictionary = project.get("share_basis_points_by_player", {})
	_expect(int(shares.get("0", 0)) == 5000 and int(shares.get("1", 0)) == 5000, "equal contributions create equal hidden shares")
	_expect(int(project.get("controller_player_index", -1)) == 0, "earliest contributor controls an equal-share project")
	project = PROJECT_STATE.contribute(project, 1, 1, 12)
	shares = project.get("share_basis_points_by_player", {})
	_expect(_dictionary_int_total(shares) == 10000, "project shares always total exactly 10000 basis points")
	_expect(int(shares.get("1", 0)) > int(shares.get("0", 0)) and int(project.get("controller_player_index", -1)) == 1, "highest contributor becomes project controller")


func _check_legacy_migration() -> void:
	var legacy_city := {
		"owner": 2,
		"active": true,
		"products": [{"name": "轨迹墨水", "level": 2}],
		"demands": ["等离子米"],
	}
	var migrated: Dictionary = PROJECT_BRIDGE.migrate_legacy_city(legacy_city, 4, 20)
	var projects: Array = migrated.get("projects", [])
	_expect(projects.size() == 2, "legacy products and demands migrate to project records")
	for project_variant in projects:
		var project: Dictionary = project_variant as Dictionary
		var shares: Dictionary = project.get("share_basis_points_by_player", {})
		_expect(int(shares.get("2", 0)) == 10000, "legacy city preserves 100 percent of each project for its old owner")
	var development := {
		"product_id": "轨迹墨水",
		"project_direction": "production",
		"contribution_units": 2,
	}
	migrated = PROJECT_BRIDGE.apply_development(migrated, 4, 1, development, 30)
	var matched_project := _find_project(migrated.get("projects", []) as Array, "轨迹墨水", "production")
	_expect(not matched_project.is_empty() and int((matched_project.get("contribution_by_player", {}) as Dictionary).get("1", 0)) == 2, "development contribution strengthens the matching real project")


func _check_gdp_allocation_and_privacy() -> void:
	var first := PROJECT_STATE.create_project(1, "活体芯片", "production", 0, 1, 1)
	var second := PROJECT_STATE.create_project(1, "等离子米", "demand", 1, 1, 2)
	second = PROJECT_STATE.contribute(second, 0, 1, 3)
	var assigned_city: Dictionary = PROJECT_BRIDGE.assign_city_gdp({"projects": [first, second]}, 101)
	var assigned: Array = assigned_city.get("projects", []) as Array
	var by_player: Dictionary = PROJECT_STATE.gdp_by_player(assigned)
	var city_project_gdp := 0
	for project_variant in assigned:
		city_project_gdp += int((project_variant as Dictionary).get("current_gdp", 0))
	_expect(city_project_gdp == 101, "city total GDP is the exact sum of its active product projects")
	_expect(_dictionary_int_total(by_player) == 101, "urbanization shares and realtime income allocation preserve the exact city GDP total")
	var public_snapshot: Dictionary = PROJECT_STATE.public_snapshot(assigned[1] as Dictionary)
	_expect(not public_snapshot.has("controller_player_index") and not public_snapshot.has("contribution_by_player") and not public_snapshot.has("share_basis_points_by_player"), "public project snapshot hides controller and all contribution shares")
	var private_snapshot: Dictionary = PROJECT_STATE.private_snapshot(assigned[1] as Dictionary, 0)
	_expect(private_snapshot.has("own_share_percent") and private_snapshot.has("own_contribution") and private_snapshot.has("is_controller"), "private snapshot exposes only the current player's own project facts")
	_expect(not private_snapshot.has("contribution_by_player") and not private_snapshot.has("share_basis_points_by_player"), "private snapshot still omits other players' contribution tables")
	_expect(not _contains_runtime_object(public_snapshot) and not _contains_runtime_object(private_snapshot), "project UI snapshots remain pure data")


func _check_destroyed_district_stops_project_gdp() -> void:
	var project := PROJECT_STATE.create_project(7, "轨迹墨水", "commerce", 0, 1, 40)
	var active_city := PROJECT_BRIDGE.assign_city_gdp({"projects": [project]}, 37)
	_expect(int(((active_city.get("projects", []) as Array)[0] as Dictionary).get("current_gdp", 0)) == 37, "an active district project receives city GDP")
	var destroyed_city := PROJECT_BRIDGE.assign_city_gdp(active_city, 0)
	var destroyed_projects: Array = destroyed_city.get("projects", []) as Array
	_expect(not destroyed_projects.is_empty() and int((destroyed_projects[0] as Dictionary).get("current_gdp", -1)) == 0, "a destroyed district zeroes project GDP and stops project income")
	_expect(_dictionary_int_total(destroyed_city.get("project_gdp_by_player", {}) as Dictionary) == 0, "a destroyed district allocates no project GDP to players")


func _check_save_load_roundtrip() -> void:
	var city := {
		"owner": 0,
		"active": true,
		"products": [],
		"demands": [],
		"projects": [],
	}
	city = PROJECT_BRIDGE.apply_development(city, 3, 0, {
		"product_id": "等离子米",
		"project_direction": "demand",
		"contribution_units": 2,
	}, 51)
	city = PROJECT_BRIDGE.apply_development(city, 3, 1, {
		"product_id": "等离子米",
		"project_direction": "demand",
		"contribution_units": 1,
	}, 52)
	city = PROJECT_BRIDGE.assign_city_gdp(city, 73)
	var state := {
		"city_product_project_sequence": 53,
		"districts": [{"destroyed": false, "city": city}],
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://space_syndicate_design_qa"))
	var writer := FileAccess.open(ROUNDTRIP_PATH, FileAccess.WRITE)
	_expect(writer != null, "project roundtrip save file opens")
	if writer == null:
		return
	writer.store_var(state, false)
	writer.close()
	var reader := FileAccess.open(ROUNDTRIP_PATH, FileAccess.READ)
	_expect(reader != null, "project roundtrip save file reopens")
	if reader == null:
		return
	var loaded_variant: Variant = reader.get_var(false)
	reader.close()
	var loaded: Dictionary = loaded_variant if loaded_variant is Dictionary else {}
	var loaded_districts: Array = loaded.get("districts", []) if loaded.get("districts", []) is Array else []
	var loaded_city: Dictionary = ((loaded_districts[0] as Dictionary).get("city", {}) as Dictionary) if not loaded_districts.is_empty() else {}
	var loaded_projects: Array = loaded_city.get("projects", []) if loaded_city.get("projects", []) is Array else []
	var loaded_project: Dictionary = loaded_projects[0] as Dictionary if not loaded_projects.is_empty() else {}
	_expect(int(loaded.get("city_product_project_sequence", 0)) == 53, "old save compatibility preserves the global project creation sequence without a version bump")
	_expect(str(loaded_project.get("project_id", "")) == "3:等离子米:demand" and int(loaded_project.get("created_order", -1)) == 51, "save/load roundtrip preserves project identity and creation order")
	_expect(int((loaded_project.get("contribution_by_player", {}) as Dictionary).get("0", 0)) == 2 and int((loaded_project.get("contribution_by_player", {}) as Dictionary).get("1", 0)) == 1, "save/load roundtrip preserves project contributions")
	_expect(_dictionary_int_total(loaded_project.get("share_basis_points_by_player", {}) as Dictionary) == 10000 and int(loaded_project.get("current_gdp", 0)) == 73, "save/load roundtrip preserves hidden shares and current project GDP")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ROUNDTRIP_PATH))


func _find_project(projects: Array, product_id: String, direction: String) -> Dictionary:
	for project_variant in projects:
		if not (project_variant is Dictionary):
			continue
		var project: Dictionary = project_variant as Dictionary
		if str(project.get("product_id", "")) == product_id and str(project.get("direction", "")) == direction:
			return project
	return {}


func _dictionary_int_total(values: Dictionary) -> int:
	var total := 0
	for value_variant in values.values():
		total += int(value_variant)
	return total


func _contains_runtime_object(value: Variant) -> bool:
	if value is Callable or value is Node or value is Object:
		return true
	if value is Dictionary:
		for nested_value in (value as Dictionary).values():
			if _contains_runtime_object(nested_value):
				return true
	if value is Array:
		for nested_value in value as Array:
			if _contains_runtime_object(nested_value):
				return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error(message)
