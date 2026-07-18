extends Control
class_name RegionCodexPublicSourceBench

signal bench_finished(exit_code: int)

const SOURCE_SERVICE_SCENE := preload("res://scenes/runtime/RegionCodexPublicSourceService.tscn")
const REGION_BRIDGE_SCENE := preload("res://scenes/runtime/RegionInfrastructureWorldBridge.tscn")
const MONSTER_SCENE := preload("res://scenes/runtime/MonsterRuntimeController.tscn")
const MONSTER_BRIDGE_SCENE := preload("res://scenes/runtime/MonsterRuntimeWorldBridge.tscn")
const CATALOG_SCENE := preload("res://scenes/runtime/CardRuntimeCatalogService.tscn")
const SNAPSHOT_SCENE := preload("res://scenes/runtime/CodexPublicSnapshotService.tscn")
const SURFACE_SCENE := preload("res://scenes/ui/CodexCompendiumSurface.tscn")
const ADAPTER_SCRIPT := preload("res://scripts/runtime/region_codex_public_source_adapter.gd")
const REGION_FIELDS := ["available", "card_ids", "city", "contract_version", "demands", "destroyed", "economic_focus_label", "facilities", "hp_now", "hp_total", "index", "name", "neighbor_indices", "products", "public_clue", "reason_code", "region_id", "terrain", "terrain_label", "total"]
const CITY_FIELDS := ["active", "last_income", "level", "present"]
const FACILITY_FIELDS := ["facility_type", "industry_id", "owner_kind", "owner_player_index", "rank"]
const PRIVATE_SENTINELS := ["PRIVATE_SENTINEL", "SECRET_SENTINEL", "CASH_SENTINEL", "HAND_SENTINEL", "DISCARD_SENTINEL", "OWNER_SENTINEL", "AI_PLAN_SENTINEL", "DO_NOT_LEAK"]

@export var auto_run := true

@onready var status_label: Label = %StatusLabel
@onready var summary_label: Label = %SummaryLabel
@onready var results_text: RichTextLabel = %ResultsText
@onready var surface_host: VBoxContainer = %SurfaceHost

var bench_complete := false
var bench_status := "RUNNING"
var bench_check_count := 0
var bench_failure_count := 0
var bench_failed_cases := ""
var _checks := 0
var _failures: Array[String] = []
var _results: Array[String] = []
var _world: RegionWorld
var _session_state: WorldSessionState
var _region_bridge: Node
var _monster_bridge: Node
var _monster: Node
var _catalog: Node
var _weather: PublicWeather
var _route: PublicRoute
var _snapshot: Node
var _service: Node
var _surface: Control


class PublicWeather:
	extends Node
	var call_count := 0
	func district_summary(_region_index: int) -> String:
		call_count += 1
		return "公开晴朗"


class PublicRoute:
	extends Node
	var call_count := 0
	func route_load_for_legacy_region(_region_index: int) -> int:
		call_count += 1
		return 2


class RegionWorld:
	extends Node
	var districts: Array = []
	var players: Array = []
	var session_state: WorldSessionState
	var selected_player := 0
	var selected_district := 0
	var rng := RandomNumberGenerator.new()

	func _init() -> void:
		rng.seed = 150726
		reset()

	func reset() -> void:
		players = [
			{"cash": "CASH_SENTINEL", "hand": ["HAND_SENTINEL"], "discard": ["DISCARD_SENTINEL"], "city_guesses": {"region.000": "OWNER_SENTINEL"}},
			{"cash": 900, "ai_private_plan": "AI_PLAN_SENTINEL"},
		]
		selected_player = 0
		selected_district = 0
		districts = [
			{
				"region_id": "region.000", "name": "晨谷区", "terrain": "land", "terrain_label": "陆地",
				"economic_focus_label": "工业", "hp": 300, "damage": 40, "destroyed": false, "miasma": false,
				"center": Vector2.ZERO, "products": ["晶矿"], "demands": ["菌毯"], "neighbors": [1, 2],
				"card_choices": ["轨道融资1", "城市经营1"], "owner": "OWNER_SENTINEL",
				"city": {
					"active": true, "level": 2, "last_income": 180, "owner": "OWNER_SENTINEL", "owner_player_index": 0,
					"products": ["晶矿"], "demands": ["菌毯"],
					"facilities": [{"owner": "OWNER_SENTINEL"}], "warehouse_inventory": ["PRIVATE_SENTINEL"],
					"private_clue": "SECRET_SENTINEL", "last_public_clue": "",
					"public_clues": [{"time": 12.0, "kind": "公开余波", "products": ["晶矿"], "text": "匿名供应恢复", "private_plan": "DO_NOT_LEAK"}],
				},
			},
			{"region_id": "region.001", "name": "远港区", "terrain": "ocean", "terrain_label": "海域", "economic_focus_label": "航运", "hp": 100, "damage": 0, "destroyed": false, "miasma": false, "center": Vector2(3000, 0), "products": [], "demands": [], "neighbors": [0], "card_choices": [], "city": {}},
			{"region_id": "region.002", "name": "灰丘区", "terrain": "desert", "terrain_label": "荒漠", "economic_focus_label": "资源", "hp": 100, "damage": 0, "destroyed": false, "miasma": false, "center": Vector2(0, 3000), "products": [], "demands": [], "neighbors": [0], "card_choices": [], "city": {}},
		]
		_sync_session_state()

	func bind_session_state(state: WorldSessionState) -> void:
		session_state = state
		_sync_session_state()

	func _sync_session_state() -> void:
		if session_state == null:
			return
		session_state.replace_players(players)
		session_state.replace_districts(districts)

	func _district_supply_card_ids(index: int) -> Array:
		if index < 0 or index >= districts.size() or not (districts[index] is Dictionary):
			return []
		var choices_variant: Variant = (districts[index] as Dictionary).get("card_choices", [])
		return (choices_variant as Array).duplicate(true) if choices_variant is Array else []

	func _district_city(index: int) -> Dictionary:
		if index < 0 or index >= districts.size() or not (districts[index] is Dictionary):
			return {}
		var city_variant: Variant = (districts[index] as Dictionary).get("city", {})
		return city_variant as Dictionary if city_variant is Dictionary else {}

	func _city_is_active(city: Dictionary) -> bool:
		return not city.is_empty() and bool(city.get("active", false))

	func _city_warehouse_stockpile_pressure(_city: Dictionary) -> int:
		return 0

	func _city_product_names(city: Dictionary) -> Array:
		return (city.get("products", []) as Array).duplicate() if city.get("products", []) is Array else []

	func _city_demand_names(city: Dictionary) -> Array:
		return (city.get("demands", []) as Array).duplicate() if city.get("demands", []) is Array else []

	func _entity_distance_to_district(actor: Dictionary, index: int) -> float:
		if index < 0 or index >= districts.size():
			return INF
		return (actor.get("world_position", Vector2.ZERO) as Vector2).distance_to((districts[index] as Dictionary).get("center", Vector2.ZERO) as Vector2)

	func _weight_part_total(parts: Dictionary) -> int:
		var total := 0
		for value_variant: Variant in parts.values():
			total += maxi(0, int(value_variant))
		return total

	func _route_network_routes_for_product(_product_name: String) -> Array:
		return []


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_suite")


func run_suite() -> void:
	_reset_bench()
	_build_runtime()
	_check("bridge_schema_exact", _bridge_schema_exact())
	_check("active_city_without_public_clue", _active_city_without_public_clue())
	_check("bridge_viewer_private_invariant", _bridge_private_invariance())
	_check("bridge_scalar_arrays_fail_closed", _bridge_scalar_arrays_fail_closed())
	_check("adapter_forbidden_input_fail_closed", _adapter_forbidden_input_fail_closed())
	_check("source_and_formatter_pipeline", _source_and_formatter_pipeline())
	_check("source_and_final_viewer_invariant", _source_and_final_viewer_invariance())
	_check("public_clue_changes_only_clue_path", _public_clue_changes_only_clue_path())
	_check("monster_public_projection_only", _monster_public_projection_only())
	_check("service_bridge_api_is_narrow", _service_bridge_api_is_narrow())
	_check("architecture_and_save_boundary", _architecture_and_save_boundary())
	_check("scene_owner_is_unique", _scene_owner_is_unique())
	_check("real_region_surface_rendered", _real_region_surface_rendered())
	_finish_bench()


func debug_snapshot() -> Dictionary:
	return {
		"bench_complete": bench_complete,
		"status": bench_status,
		"check_count": bench_check_count,
		"failure_count": bench_failure_count,
		"failed_cases": bench_failed_cases,
		"surface_visible": _surface != null and _surface.visible,
	}


func _reset_bench() -> void:
	for child in get_children():
		if child == %Layout:
			continue
		remove_child(child)
		child.queue_free()
	for child in surface_host.get_children():
		surface_host.remove_child(child)
		child.queue_free()
	_checks = 0
	_failures.clear()
	_results.clear()
	bench_complete = false
	bench_status = "RUNNING"
	bench_check_count = 0
	bench_failure_count = 0
	bench_failed_cases = ""


func _build_runtime() -> void:
	_world = RegionWorld.new()
	add_child(_world)
	_session_state = WorldSessionState.new()
	add_child(_session_state)
	_world.bind_session_state(_session_state)
	_region_bridge = REGION_BRIDGE_SCENE.instantiate()
	add_child(_region_bridge)
	_region_bridge.call("bind_world", _world)
	_region_bridge.call("set_world_session_state", _session_state)
	_monster_bridge = MONSTER_BRIDGE_SCENE.instantiate()
	add_child(_monster_bridge)
	_monster_bridge.call("bind_world", _world)
	_monster_bridge.call("set_world_session_state", _session_state)
	_catalog = CATALOG_SCENE.instantiate()
	add_child(_catalog)
	_catalog.call("configure", {"ruleset_id": "v0.4"})
	_monster = MONSTER_SCENE.instantiate()
	add_child(_monster)
	_monster.call("set_world_bridge", _monster_bridge)
	_monster.call("set_card_runtime_catalog_service", _catalog)
	_monster.call("configure", {"ruleset_id": "v0.4"})
	_monster.set("auto_monsters", [{
		"uid": 99, "name": "孢雾海皇", "position": 1, "world_position": Vector2(2600, 0), "down": false,
		"remaining_time": 45.0, "resource_focus": ["晶矿"], "owner": "OWNER_SENTINEL",
		"owner_actor_id_v06": "SECRET_SENTINEL", "ai_private_plan": "AI_PLAN_SENTINEL",
	}])
	_weather = PublicWeather.new()
	add_child(_weather)
	_route = PublicRoute.new()
	add_child(_route)
	_snapshot = SNAPSHOT_SCENE.instantiate()
	add_child(_snapshot)
	_snapshot.call("configure", {})
	_service = SOURCE_SERVICE_SCENE.instantiate()
	add_child(_service)
	_service.call("configure", {"region_public_bridge": _region_bridge, "monster": _monster, "weather": _weather, "route": _route, "snapshot": _snapshot})
	_surface = SURFACE_SCENE.instantiate() as Control
	surface_host.add_child(_surface)


func _bridge_schema_exact() -> bool:
	var facts := _bridge_facts()
	var keys := facts.keys()
	keys.sort()
	var expected := REGION_FIELDS.duplicate()
	expected.sort()
	var city := facts.get("city", {}) as Dictionary
	var city_keys := city.keys()
	city_keys.sort()
	var facilities_valid := facts.get("facilities", []) is Array
	for facility_variant: Variant in facts.get("facilities", []) as Array:
		if not (facility_variant is Dictionary):
			facilities_valid = false
			break
		var facility_keys := (facility_variant as Dictionary).keys()
		facility_keys.sort()
		if facility_keys != FACILITY_FIELDS:
			facilities_valid = false
			break
	return keys == expected and city_keys == CITY_FIELDS and facilities_valid and bool(facts.get("available", false)) and str(facts.get("contract_version", "")) == "region_codex_public_facts_v06" and not _contains_sentinel(facts)


func _active_city_without_public_clue() -> bool:
	_world.reset()
	var district := (_world.districts[0] as Dictionary).duplicate(true)
	var city := (district.get("city", {}) as Dictionary).duplicate(true)
	city["public_clues"] = []
	city["last_public_clue"] = ""
	district["city"] = city
	_world.districts[0] = district
	var facts := _bridge_facts()
	var source := _service.call("compose_source", 0) as Dictionary
	var snapshot := _service.call("compose_region", 0) as Dictionary
	return bool((facts.get("city", {}) as Dictionary).get("active", false)) and str(facts.get("public_clue", "")) == "暂无公开线索" and str(source.get("public_clue", "")) == "暂无公开线索" and not _contains_sentinel(snapshot)


func _bridge_private_invariance() -> bool:
	_world.reset()
	_seed_monster_private_owner("OWNER_SENTINEL")
	var baseline := _bridge_facts()
	_world.selected_player = 1
	_world.selected_district = 2
	_world.players = [{"cash": 1, "hand": ["PRIVATE_SENTINEL"], "discard": ["SECRET_SENTINEL"], "city_guesses": {"x": "DO_NOT_LEAK"}}, {"ai_private_plan": "AI_PLAN_SENTINEL"}]
	var district := (_world.districts[0] as Dictionary).duplicate(true)
	district["owner"] = "SECRET_SENTINEL"
	district["hidden_owner"] = "OWNER_SENTINEL"
	var city := (district.get("city", {}) as Dictionary).duplicate(true)
	city["owner"] = "SECRET_SENTINEL"
	city["owner_player_index"] = 7
	city["facilities"] = [{"owner": "PRIVATE_SENTINEL", "cash": "CASH_SENTINEL"}]
	city["warehouse_inventory"] = ["HAND_SENTINEL"]
	city["private_clue"] = "DO_NOT_LEAK"
	district["city"] = city
	_world.districts[0] = district
	_seed_monster_private_owner("SECRET_SENTINEL")
	var changed := _bridge_facts()
	return _canonical(baseline) == _canonical(changed) and not _contains_sentinel(changed)


func _bridge_scalar_arrays_fail_closed() -> bool:
	_world.reset()
	var district := (_world.districts[0] as Dictionary).duplicate(true)
	district["card_choices"] = [{"card_id": "PRIVATE_SENTINEL"}]
	_world.districts[0] = district
	var rejected := _bridge_facts()
	_world.reset()
	return not bool(rejected.get("available", true)) and str(rejected.get("reason_code", "")).contains("string_array_invalid") and (rejected.get("card_ids", []) as Array).is_empty()


func _adapter_forbidden_input_fail_closed() -> bool:
	_world.reset()
	_seed_monster_private_owner("OWNER_SENTINEL")
	var adapter: RefCounted = ADAPTER_SCRIPT.new()
	var region := _bridge_facts()
	var monster := _monster_facts()
	for forbidden_key in ["viewer_index", "player_index", "selected_player", "selected_district", "city_guesses", "cash", "hand", "discard", "owner", "hidden_owner", "private", "ai_plan", "target_plan", "developer", "raw_actor", "warehouse_inventory", "facility_owner"]:
		var nested := region.duplicate(true)
		var private_leaf := {}
		private_leaf[str(forbidden_key)] = "DO_NOT_LEAK"
		nested["extra"] = {"nested": private_leaf}
		if bool(adapter.call("accepts_public_input", nested)) or not (adapter.call("compose_source", nested, monster, "公开晴朗", 2) as Dictionary).is_empty():
			return false
	var sentinel := region.duplicate(true)
	sentinel["name"] = "PRIVATE_SENTINEL"
	return not bool(adapter.call("accepts_public_input", sentinel)) and (adapter.call("compose_source", sentinel, monster, "公开晴朗", 2) as Dictionary).is_empty()


func _source_and_formatter_pipeline() -> bool:
	_world.reset()
	_seed_monster_private_owner("OWNER_SENTINEL")
	var source := _service.call("compose_source", 0) as Dictionary
	var final := _service.call("compose_region", 0) as Dictionary
	var detail := final.get("detail", {}) as Dictionary
	return bool(source.get("valid", false)) and str(source.get("name", "")) == "晨谷区" and int(source.get("card_count", -1)) == 2 and int(source.get("trade_route_load", -1)) == 2 and not source.has("selected") and not source.has("panic") and not detail.is_empty() and str(detail.get("title", "")).contains("晨谷区") and not _contains_sentinel(source) and not _contains_sentinel(final)


func _source_and_final_viewer_invariance() -> bool:
	_world.reset()
	_seed_monster_private_owner("OWNER_SENTINEL")
	var source_before := _service.call("compose_source", 0) as Dictionary
	var final_before := _service.call("compose_region", 0) as Dictionary
	_world.selected_player = 1
	_world.selected_district = 2
	_world.players[0] = {"cash": "CASH_SENTINEL", "hand": ["HAND_SENTINEL"], "discard": ["DISCARD_SENTINEL"], "city_guesses": {"region.000": "OWNER_SENTINEL"}}
	var district := (_world.districts[0] as Dictionary).duplicate(true)
	var city := (district.get("city", {}) as Dictionary).duplicate(true)
	city["owner"] = "OWNER_SENTINEL"
	city["owner_player_index"] = 9
	city["facilities"] = [{"owner": "SECRET_SENTINEL"}]
	city["warehouse_inventory"] = ["PRIVATE_SENTINEL"]
	district["city"] = city
	_world.districts[0] = district
	_seed_monster_private_owner("SECRET_SENTINEL")
	var source_after := _service.call("compose_source", 0) as Dictionary
	var final_after := _service.call("compose_region", 0) as Dictionary
	return _canonical(source_before) == _canonical(source_after) and _canonical(final_before) == _canonical(final_after) and not _contains_sentinel(source_after) and not _contains_sentinel(final_after)


func _public_clue_changes_only_clue_path() -> bool:
	_world.reset()
	_seed_monster_private_owner("OWNER_SENTINEL")
	var source_before := _service.call("compose_source", 0) as Dictionary
	var final_before := _service.call("compose_region", 0) as Dictionary
	var district := (_world.districts[0] as Dictionary).duplicate(true)
	var city := (district.get("city", {}) as Dictionary).duplicate(true)
	city["public_clues"] = [
		{"time": 12.0, "kind": "公开余波", "products": ["晶矿"], "text": "匿名供应恢复", "private_plan": "DO_NOT_LEAK"},
		{"time": 20.0, "kind": "公开余波", "products": ["菌毯"], "text": "公开运输恢复", "owner": "OWNER_SENTINEL"},
		{"time": 21.0, "kind": "公开余波", "products": ["菌毯"], "text": "DO_NOT_LEAK"},
		{"time": "malformed", "kind": "公开余波", "products": [{"owner": "OWNER_SENTINEL"}], "text": {"private": "DO_NOT_LEAK"}},
	]
	district["city"] = city
	_world.districts[0] = district
	var source_after := _service.call("compose_source", 0) as Dictionary
	var final_after := _service.call("compose_region", 0) as Dictionary
	var before_without := source_before.duplicate(true)
	var after_without := source_after.duplicate(true)
	before_without["public_clue"] = "<clue>"
	after_without["public_clue"] = "<clue>"
	var final_before_without := _mask_public_clue(final_before)
	var final_after_without := _mask_public_clue(final_after)
	return str(source_after.get("public_clue", "")).contains("公开运输恢复") and not _contains_sentinel(source_after) and _canonical(before_without) == _canonical(after_without) and _canonical(final_before_without) == _canonical(final_after_without)


func _monster_public_projection_only() -> bool:
	_world.reset()
	_seed_monster_private_owner("OWNER_SENTINEL")
	var owner_facts := _monster_facts()
	var source := _service.call("compose_source", 0) as Dictionary
	var entries := source.get("monster_entries", []) as Array
	if entries.is_empty() or _canonical(entries) != _canonical(owner_facts.get("entries", [])):
		return false
	for entry_variant: Variant in entries:
		var reason := str((entry_variant as Dictionary).get("reason", ""))
		if reason.is_empty() or _has_digit(reason):
			return false
		for forbidden in ["权重", "%", "+", "numerator", "total", "rng", "target", "private", "owner"]:
			if reason.to_lower().contains(forbidden):
				return false
	return true


func _service_bridge_api_is_narrow() -> bool:
	var source := FileAccess.get_file_as_string("res://scripts/runtime/region_codex_public_source_service.gd")
	return source.count("_region_public_bridge.call(") == 1 and source.contains("_region_public_bridge.call(\"region_codex_public_facts\"") and not source.contains("region_snapshot_for_legacy_index") and not source.contains("region_commodity_facts") and not source.contains("selected_region_commodity_facts")


func _architecture_and_save_boundary() -> bool:
	var adapter_source := FileAccess.get_file_as_string("res://scripts/runtime/region_codex_public_source_adapter.gd")
	var service_source := FileAccess.get_file_as_string("res://scripts/runtime/region_codex_public_source_service.gd")
	var bridge_source := FileAccess.get_file_as_string("res://scripts/runtime/region_infrastructure_world_bridge.gd")
	var adapter_clean := adapter_source.contains("extends RefCounted") and not adapter_source.contains("extends Node") and not adapter_source.contains("scripts/main.gd") and not adapter_source.contains("to_save_data") and not adapter_source.contains("apply_save_data")
	var service_clean := not service_source.contains("scripts/main.gd") and not service_source.contains("auto_monsters") and not service_source.contains("roster_snapshot") and not service_source.contains("_auto_monster_target") and not service_source.contains("to_save_data") and not service_source.contains("apply_save_data") and not service_source.contains("selected_player") and not service_source.contains("selected_district")
	var projection_start := bridge_source.find("func region_codex_public_facts")
	var projection_end := bridge_source.find("func region_commodity_facts", projection_start)
	var projection_source := bridge_source.substr(projection_start, projection_end - projection_start) if projection_start >= 0 and projection_end > projection_start else ""
	var bridge_clean := not projection_source.contains("selected_player") and not projection_source.contains("selected_district") and not projection_source.contains("players") and projection_source.contains("public_economy_snapshot") and projection_source.contains("owner_player_index") and not projection_source.contains("city_guesses") and not projection_source.contains("warehouse_inventory")
	return adapter_clean and service_clean and bridge_clean and not _service.has_method("to_save_data") and not _service.has_method("apply_save_data") and bool((_service.call("debug_snapshot") as Dictionary).get("commodity_flow_aggregate_omitted", false)) and bool((_service.call("debug_snapshot") as Dictionary).get("contract_aggregate_omitted", false))


func _scene_owner_is_unique() -> bool:
	var nodes := get_tree().get_nodes_in_group("region_codex_public_source_service")
	return nodes.size() == 1 and nodes[0] == _service and _service.scene_file_path == "res://scenes/runtime/RegionCodexPublicSourceService.tscn"


func _real_region_surface_rendered() -> bool:
	_world.reset()
	_seed_monster_private_owner("OWNER_SENTINEL")
	var final := _service.call("compose_region", 0) as Dictionary
	var rendered := bool(_surface.call("set_page", {"mode": "region", "view": "detail", "detail": final.get("detail", {})}))
	var title := _surface.find_child("RegionCodexTileTitle", true, false) as Label
	return rendered and _surface.visible and title != null and title.text.contains("晨谷区") and bool((_surface.call("debug_snapshot") as Dictionary).get("contracts_ready", false))


func _bridge_facts() -> Dictionary:
	return _region_bridge.call("region_codex_public_facts", 0) as Dictionary


func _monster_facts() -> Dictionary:
	return _monster.call("region_attraction_public_snapshot_v06", 0) as Dictionary


func _seed_monster_private_owner(owner_value: String) -> void:
	_monster.set("auto_monsters", [{
		"uid": 99, "name": "孢雾海皇", "position": 1, "world_position": Vector2(2600, 0), "down": false,
		"remaining_time": 45.0, "resource_focus": ["晶矿"], "owner": owner_value,
		"owner_actor_id_v06": owner_value, "owner_clue": owner_value, "owner_revealed": false,
		"binding_fingerprint": owner_value, "lure_source": owner_value, "ai_private_plan": "AI_PLAN_SENTINEL",
	}])


func _mask_public_clue(snapshot: Dictionary) -> Dictionary:
	var result := snapshot.duplicate(true)
	var detail := result.get("detail", {}) as Dictionary
	var clues := detail.get("clues", []) as Array
	for index in range(clues.size()):
		if clues[index] is Dictionary and str((clues[index] as Dictionary).get("title", "")) == "公开事件":
			var entry := (clues[index] as Dictionary).duplicate(true)
			entry["body"] = "<clue>"
			clues[index] = entry
	detail["clues"] = clues
	result["detail"] = detail
	return result


func _canonical(value: Variant) -> String:
	return JSON.stringify(_canonical_value(value))


func _canonical_value(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		var keys := (value as Dictionary).keys()
		keys.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
		for key_variant: Variant in keys:
			result[str(key_variant)] = _canonical_value((value as Dictionary)[key_variant])
		return result
	if value is Array:
		var result: Array = []
		for entry_variant: Variant in value as Array:
			result.append(_canonical_value(entry_variant))
		return result
	if value is Color:
		return (value as Color).to_html(true)
	if value is Vector2:
		return [float((value as Vector2).x), float((value as Vector2).y)]
	return value


func _contains_sentinel(value: Variant) -> bool:
	var encoded := var_to_str(value).to_upper()
	for sentinel in PRIVATE_SENTINELS:
		if encoded.contains(sentinel):
			return true
	return false


func _has_digit(value: String) -> bool:
	var regex := RegEx.new()
	return regex.compile("[0-9]") == OK and regex.search(value) != null


func _check(case_id: String, passed: bool) -> void:
	_checks += 1
	_results.append("[color=#4ade80]PASS[/color] %s" % case_id if passed else "[color=#fb7185]FAIL[/color] %s" % case_id)
	if not passed:
		_failures.append(case_id)
	print("REGION_CODEX_PUBLIC_SOURCE_CASE|case=%s|passed=%s" % [case_id, str(passed)])


func _finish_bench() -> void:
	bench_complete = true
	bench_status = "PASS" if _failures.is_empty() else "FAIL"
	bench_check_count = _checks
	bench_failure_count = _failures.size()
	bench_failed_cases = ",".join(_failures)
	status_label.text = bench_status
	status_label.modulate = Color("#4ade80") if _failures.is_empty() else Color("#fb7185")
	summary_label.text = "%d/%d public-source checks passed" % [_checks - _failures.size(), _checks]
	results_text.text = "\n".join(_results)
	print("REGION_CODEX_PUBLIC_SOURCE_BENCH|status=%s|checks=%d|failures=%d|failed=%s" % [bench_status, _checks, _failures.size(), bench_failed_cases])
	bench_finished.emit(0 if _failures.is_empty() else 1)
