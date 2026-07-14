extends Control
class_name MonsterRegionPublicAttractionV06Bench

signal bench_finished(exit_code: int)

const CONTROLLER_SCENE := preload("res://scenes/runtime/MonsterRuntimeController.tscn")
const WORLD_BRIDGE_SCENE := preload("res://scenes/runtime/MonsterRuntimeWorldBridge.tscn")
const CATALOG_SCENE := preload("res://scenes/runtime/CardRuntimeCatalogService.tscn")
const TOP_LEVEL_FIELDS := ["available", "contract_version", "entries", "reason_code", "region_index"]
const ENTRY_FIELDS := ["factor_codes", "name", "ordinal", "reason"]
const FACTOR_CODES := ["distance", "city", "competition", "warehouse", "resource", "miasma", "other_monster"]
const FORBIDDEN_REASON_FRAGMENTS := ["权重", "%", "+", "numerator", "total", "概率", "rng", "target", "lure", "uid", "owner", "fingerprint", "binding", "现金", "手牌", "ai_", "private"]

@export var auto_run := true

@onready var status_label: Label = %StatusLabel
@onready var summary_label: Label = %SummaryLabel
@onready var results_text: RichTextLabel = %ResultsText

var bench_complete := false
var bench_status := "RUNNING"
var bench_check_count := 0
var bench_failure_count := 0
var bench_failed_cases := ""
var _checks := 0
var _failures: Array[String] = []
var _results: Array[String] = []
var _world: AttractionWorld
var _bridge: MonsterRuntimeWorldBridge
var _owner: MonsterRuntimeController
var _catalog: CardRuntimeCatalogService


class AttractionWorld:
	extends Node

	var players: Array = []
	var districts: Array = []
	var game_time := 0.0
	var selected_player := 0
	var selected_district := 0
	var rng := RandomNumberGenerator.new()

	func _init() -> void:
		rng.seed = 240715
		reset_public_facts()

	func reset_public_facts() -> void:
		players = [
			{"cash": 300, "hand": ["secret-human"], "discard": ["secret-discard"], "city_guesses": {"region": "secret-guess"}},
			{"cash": 900, "hand": ["secret-rival"], "ai_private_plan": "secret-route", "ai_score": 999},
		]
		districts = [{
			"name": "晨谷区",
			"destroyed": false,
			"miasma": false,
			"center": Vector2.ZERO,
			"products": [],
			"demands": [],
			"city": {},
		}]
		selected_player = 0
		selected_district = 0

	func _district_city(index: int) -> Dictionary:
		if index < 0 or index >= districts.size() or not (districts[index] is Dictionary):
			return {}
		var district := districts[index] as Dictionary
		return (district.get("city", {}) as Dictionary).duplicate(true) if district.get("city", {}) is Dictionary else {}

	func _city_is_active(city: Dictionary) -> bool:
		return bool(city.get("active", false)) and not bool(city.get("destroyed", false))

	func _city_warehouse_stockpile_pressure(city: Dictionary) -> int:
		return maxi(0, int(city.get("warehouse_pressure", 0)))

	func _entity_distance_to_district(actor: Dictionary, index: int) -> float:
		if index < 0 or index >= districts.size() or not (districts[index] is Dictionary):
			return INF
		var district := districts[index] as Dictionary
		var actor_position: Vector2 = actor.get("world_position", Vector2.ZERO)
		var district_position: Vector2 = district.get("center", Vector2.ZERO)
		return actor_position.distance_to(district_position)

	func _weight_part_total(parts: Dictionary) -> int:
		var total := 0
		for value_variant: Variant in parts.values():
			total += maxi(0, int(value_variant))
		return total

	func _weighted_pick_index(weights: Array) -> int:
		var total := 0
		for weight_variant: Variant in weights:
			total += maxi(0, int(weight_variant))
		if total <= 0:
			return -1
		var ticket := rng.randi_range(1, total)
		var running := 0
		for index in range(weights.size()):
			running += maxi(0, int(weights[index]))
			if ticket <= running:
				return index
		return weights.size() - 1

	func _route_network_routes_for_product(_product_name: String) -> Array:
		return []


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_suite")


func run_suite() -> void:
	_reset_bench_state()
	_build_runtime()
	_check("owner_scene_identity", _owner != null and _owner.scene_file_path == "res://scenes/runtime/MonsterRuntimeController.tscn" and _owner.has_method("region_attraction_public_snapshot_v06"))
	_check("fail_closed", _fail_closed_contract())
	_seed_single_live_actor()
	var baseline := _snapshot()
	_check("schema_allowlist", _schema_is_exact(baseline))
	_check("private_fact_invariance", _private_fact_invariance(baseline))
	_check("public_factor_projection", _public_factor_projection())
	_check("lifecycle_exclusion", _lifecycle_exclusion())
	_check("expired_and_down_peers_do_not_project_other_monster", _expired_and_down_peers_do_not_project_other_monster())
	_seed_single_live_actor()
	_check("reason_is_non_numeric", _reason_is_non_numeric(_snapshot()))
	_check("rng_and_targeting_unchanged", _rng_and_targeting_unchanged())
	_check("save_contract_unchanged", _save_contract_unchanged())
	_check("single_owner_instance", get_tree().get_nodes_in_group("monster_region_public_attraction_owner").size() == 1)
	_finish_bench()


func debug_snapshot() -> Dictionary:
	return {
		"bench_complete": bench_complete,
		"status": bench_status,
		"check_count": bench_check_count,
		"failure_count": bench_failure_count,
		"failed_cases": bench_failed_cases,
		"owner_scene": _owner.scene_file_path if _owner != null else "",
		"owner_api_present": _owner != null and _owner.has_method("region_attraction_public_snapshot_v06"),
	}


func _reset_bench_state() -> void:
	for child in get_children():
		if child is AttractionWorld or child is MonsterRuntimeController or child is MonsterRuntimeWorldBridge or child is CardRuntimeCatalogService:
			remove_child(child)
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
	_world = AttractionWorld.new()
	add_child(_world)
	_bridge = WORLD_BRIDGE_SCENE.instantiate() as MonsterRuntimeWorldBridge
	add_child(_bridge)
	_bridge.bind_world(_world)
	_catalog = CATALOG_SCENE.instantiate() as CardRuntimeCatalogService
	add_child(_catalog)
	_catalog.configure({"ruleset_id": "v0.4"})
	_owner = CONTROLLER_SCENE.instantiate() as MonsterRuntimeController
	_owner.add_to_group("monster_region_public_attraction_owner")
	add_child(_owner)
	_owner.set_world_bridge(_bridge)
	_owner.set_card_runtime_catalog_service(_catalog)
	_owner.configure({"ruleset_id": "v0.4"})


func _actor(name: String = "孢雾海皇", slot: int = 0, position: int = 0, world_position: Vector2 = Vector2.ZERO) -> Dictionary:
	return {
		"uid": slot + 91,
		"slot": slot,
		"name": name,
		"position": position,
		"world_position": world_position,
		"down": false,
		"remaining_time": 45.0,
		"resource_focus": [],
		"owner": 0,
		"owner_actor_id_v06": "secret-owner",
		"owner_clue": "secret-clue",
		"owner_revealed": false,
		"binding_fingerprint": "secret-binding",
		"lure_target_district": 0,
		"lure_source": "secret-lure",
		"ai_private_plan": "secret-plan",
		"ai_score": 777,
	}


func _seed_single_live_actor() -> void:
	_world.reset_public_facts()
	_owner.auto_monsters = [_actor()]


func _snapshot(region_index: int = 0) -> Dictionary:
	return _owner.region_attraction_public_snapshot_v06(region_index) if _owner != null else {}


func _fail_closed_contract() -> bool:
	var orphan := CONTROLLER_SCENE.instantiate() as MonsterRuntimeController
	add_child(orphan)
	var unavailable := orphan.region_attraction_public_snapshot_v06(0)
	remove_child(orphan)
	orphan.queue_free()
	var invalid := _snapshot(-1)
	return not bool(unavailable.get("available", true)) and (unavailable.get("entries", []) as Array).is_empty() and not bool(invalid.get("available", true)) and (invalid.get("entries", []) as Array).is_empty() and _schema_is_exact(unavailable) and _schema_is_exact(invalid)


func _schema_is_exact(snapshot: Dictionary) -> bool:
	var top_keys := snapshot.keys()
	top_keys.sort()
	if top_keys != TOP_LEVEL_FIELDS or str(snapshot.get("contract_version", "")) != "monster_region_public_attraction_v06":
		return false
	for entry_variant: Variant in snapshot.get("entries", []) as Array:
		if not (entry_variant is Dictionary):
			return false
		var entry := entry_variant as Dictionary
		var entry_keys := entry.keys()
		entry_keys.sort()
		if entry_keys != ENTRY_FIELDS:
			return false
		var codes: Array = entry.get("factor_codes", []) if entry.get("factor_codes", []) is Array else []
		if codes.size() > 3:
			return false
		for code_variant: Variant in codes:
			if not FACTOR_CODES.has(str(code_variant)):
				return false
	return _recursive_private_sentinels(snapshot).is_empty()


func _private_fact_invariance(baseline: Dictionary) -> bool:
	var actor := (_owner.auto_monsters[0] as Dictionary).duplicate(true)
	actor["owner"] = 7
	actor["owner_actor_id_v06"] = "changed-owner"
	actor["owner_clue"] = "changed-clue"
	actor["owner_revealed"] = true
	actor["binding_fingerprint"] = "changed-binding"
	actor["lure_target_district"] = 99
	actor["lure_source"] = "changed-lure"
	actor["actor_id"] = "unknown-actor"
	actor["player_index"] = 6
	actor["nested_secret"] = {"hand": ["deep-secret"], "ai_plan": "deep-plan"}
	_owner.auto_monsters[0] = actor
	_world.players[0] = {"cash": 1, "hand": ["changed-hand"], "discard": ["changed-discard"], "city_guesses": {"region": "changed-guess"}}
	_world.players[1] = {"cash": 2, "ai_private_plan": "changed-ai-plan", "ai_score": -999}
	_world.selected_player = 7
	_world.selected_district = 8
	var changed := _snapshot()
	return JSON.stringify(baseline) == JSON.stringify(changed) and _recursive_private_sentinels(changed).is_empty()


func _public_factor_projection() -> bool:
	var projected_all := true
	_seed_single_live_actor()
	var actor := (_owner.auto_monsters[0] as Dictionary).duplicate(true)
	actor["world_position"] = Vector2.ZERO
	_owner.auto_monsters[0] = actor
	var distance_codes := _first_codes(_snapshot())
	projected_all = projected_all and distance_codes.has("distance")

	_seed_single_live_actor()
	actor = (_owner.auto_monsters[0] as Dictionary).duplicate(true)
	actor["world_position"] = Vector2(3000.0, 0.0)
	_owner.auto_monsters[0] = actor
	var district := (_world.districts[0] as Dictionary).duplicate(true)
	district["city"] = {"active": true, "products": []}
	_world.districts[0] = district
	var city_codes := _first_codes(_snapshot())
	projected_all = projected_all and city_codes.has("city")

	district = (_world.districts[0] as Dictionary).duplicate(true)
	district["city"] = {"active": true, "products": [], "competition_matches": 1}
	_world.districts[0] = district
	var competition_codes := _first_codes(_snapshot())
	projected_all = projected_all and competition_codes.has("competition")

	district = (_world.districts[0] as Dictionary).duplicate(true)
	district["city"] = {"active": true, "products": [], "warehouse_pressure": 120}
	_world.districts[0] = district
	var warehouse_codes := _first_codes(_snapshot())
	projected_all = projected_all and warehouse_codes.has("warehouse")

	_seed_single_live_actor()
	actor = (_owner.auto_monsters[0] as Dictionary).duplicate(true)
	actor["world_position"] = Vector2(3000.0, 0.0)
	actor["resource_focus"] = ["晶矿"]
	_owner.auto_monsters[0] = actor
	district = (_world.districts[0] as Dictionary).duplicate(true)
	district["products"] = ["晶矿"]
	_world.districts[0] = district
	var resource_codes := _first_codes(_snapshot())
	projected_all = projected_all and resource_codes.has("resource")

	district = (_world.districts[0] as Dictionary).duplicate(true)
	district["products"] = []
	district["miasma"] = true
	_world.districts[0] = district
	var miasma_codes := _first_codes(_snapshot())
	projected_all = projected_all and miasma_codes.has("miasma")

	_seed_single_live_actor()
	actor = (_owner.auto_monsters[0] as Dictionary).duplicate(true)
	actor["world_position"] = Vector2(3000.0, 0.0)
	actor["position"] = 4
	_owner.auto_monsters = [actor, _actor("流星哨兵", 1, 0, Vector2(3000.0, 0.0))]
	var other_monster_codes := _first_codes(_snapshot())
	projected_all = projected_all and other_monster_codes.has("other_monster")
	print("MONSTER_REGION_PUBLIC_ATTRACTION_FACTORS|distance=%s|city=%s|competition=%s|warehouse=%s|resource=%s|miasma=%s|other_monster=%s" % [distance_codes, city_codes, competition_codes, warehouse_codes, resource_codes, miasma_codes, other_monster_codes])
	return projected_all


func _lifecycle_exclusion() -> bool:
	_seed_single_live_actor()
	var down := _actor("倒地兽", 0)
	down["down"] = true
	var expired := _actor("过期兽", 1)
	expired["remaining_time"] = 0.0
	var live := _actor("存活兽", 2)
	_owner.auto_monsters = [down, expired, live]
	var active := _snapshot()
	var entries: Array = active.get("entries", []) if active.get("entries", []) is Array else []
	var district := (_world.districts[0] as Dictionary).duplicate(true)
	district["destroyed"] = true
	_world.districts[0] = district
	var destroyed := _snapshot()
	return entries.size() == 1 and str((entries[0] as Dictionary).get("name", "")) == "存活兽" and int((entries[0] as Dictionary).get("ordinal", -1)) == 3 and (destroyed.get("entries", []) as Array).is_empty() and str(destroyed.get("reason_code", "")) == "monster_region_public_attraction_region_destroyed"


func _expired_and_down_peers_do_not_project_other_monster() -> bool:
	_seed_single_live_actor()
	var live := _actor("存活兽", 0, 0, Vector2.ZERO)
	_owner.auto_monsters = [live]
	if _first_codes(_snapshot()).has("other_monster"):
		return false
	live = _actor("存活兽", 0, 4, Vector2(3000.0, 0.0))
	var expired_peer := _actor("过期同区兽", 1, 0, Vector2.ZERO)
	expired_peer["remaining_time"] = 0.0
	var down_peer := _actor("倒地同区兽", 2, 0, Vector2.ZERO)
	down_peer["down"] = true
	_owner.auto_monsters = [live, expired_peer, down_peer]
	var without_live_peer := _snapshot()
	var entries: Array = without_live_peer.get("entries", []) if without_live_peer.get("entries", []) is Array else []
	if entries.size() != 1 or str((entries[0] as Dictionary).get("name", "")) != "存活兽":
		return false
	if _first_codes(without_live_peer).has("other_monster"):
		return false
	var live_peer := _actor("同区活兽", 3, 0, Vector2.ZERO)
	_owner.auto_monsters = [live, expired_peer, down_peer, live_peer]
	var with_live_peer := _snapshot()
	return _first_codes(with_live_peer).has("other_monster") and _reason_is_non_numeric(with_live_peer) and _recursive_private_sentinels(with_live_peer).is_empty()


func _reason_is_non_numeric(snapshot: Dictionary) -> bool:
	var digit_pattern := RegEx.new()
	if digit_pattern.compile("[0-9]") != OK:
		return false
	for entry_variant: Variant in snapshot.get("entries", []) as Array:
		var entry := entry_variant as Dictionary
		var reason := str(entry.get("reason", ""))
		if reason.is_empty() or digit_pattern.search(reason) != null:
			return false
		var lowered := reason.to_lower()
		for fragment in FORBIDDEN_REASON_FRAGMENTS:
			if lowered.contains(str(fragment).to_lower()):
				return false
	return true


func _rng_and_targeting_unchanged() -> bool:
	_seed_single_live_actor()
	var rng_state_before := _world.rng.state
	var roster_before := var_to_str(_owner.auto_monsters)
	var candidates_before: Variant = _owner.call("_auto_monster_target_candidates", _owner.auto_monsters[0])
	var target_before := int(_owner.call("_weighted_auto_monster_target", _owner.auto_monsters[0]))
	var rng_state_after_target := _world.rng.state
	_world.rng.state = rng_state_before
	var snapshot := _snapshot()
	var snapshot_preserved_rng := _world.rng.state == rng_state_before
	var candidates_after: Variant = _owner.call("_auto_monster_target_candidates", _owner.auto_monsters[0])
	var target_after := int(_owner.call("_weighted_auto_monster_target", _owner.auto_monsters[0]))
	return not snapshot.is_empty() and snapshot_preserved_rng and target_after == target_before and _world.rng.state == rng_state_after_target and var_to_str(_owner.auto_monsters) == roster_before and var_to_str(candidates_before) == var_to_str(candidates_after)


func _save_contract_unchanged() -> bool:
	_seed_single_live_actor()
	var before := _owner.to_save_data()
	_snapshot()
	var after := _owner.to_save_data()
	return before.keys() == after.keys() and not JSON.stringify(after).contains("region_attraction") and not _owner.has_method("region_attraction_to_save_data_v06") and not _owner.has_method("apply_region_attraction_save_data_v06")


func _first_codes(snapshot: Dictionary) -> Array:
	var entries: Array = snapshot.get("entries", []) if snapshot.get("entries", []) is Array else []
	if entries.is_empty() or not (entries[0] is Dictionary):
		return []
	var entry := entries[0] as Dictionary
	return (entry.get("factor_codes", []) as Array).duplicate() if entry.get("factor_codes", []) is Array else []


func _recursive_private_sentinels(value: Variant, path: String = "root") -> Array[String]:
	var failures: Array[String] = []
	if value is Dictionary:
		for key_variant: Variant in value:
			var key := str(key_variant)
			var lowered := key.to_lower()
			for forbidden in ["owner", "actor_id", "player_index", "cash", "hand", "discard", "city_guesses", "binding", "lure", "ai_", "private", "uid", "fingerprint", "target"]:
				if lowered.contains(forbidden):
					failures.append("%s.%s" % [path, key])
			failures.append_array(_recursive_private_sentinels(value[key_variant], "%s.%s" % [path, key]))
	elif value is Array:
		for index in range((value as Array).size()):
			failures.append_array(_recursive_private_sentinels((value as Array)[index], "%s[%d]" % [path, index]))
	return failures


func _check(case_id: String, passed: bool) -> void:
	_checks += 1
	_results.append("[color=#4ade80]PASS[/color] %s" % case_id if passed else "[color=#fb7185]FAIL[/color] %s" % case_id)
	if not passed:
		_failures.append(case_id)
	print("MONSTER_REGION_PUBLIC_ATTRACTION_CASE|case=%s|passed=%s" % [case_id, str(passed)])


func _finish_bench() -> void:
	bench_complete = true
	bench_status = "PASS" if _failures.is_empty() else "FAIL"
	bench_check_count = _checks
	bench_failure_count = _failures.size()
	bench_failed_cases = ",".join(_failures)
	status_label.text = bench_status
	status_label.modulate = Color("#4ade80") if _failures.is_empty() else Color("#fb7185")
	summary_label.text = "%d/%d public-owner checks passed" % [_checks - _failures.size(), _checks]
	results_text.text = "\n".join(_results)
	print("MONSTER_REGION_PUBLIC_ATTRACTION_BENCH|status=%s|checks=%d|failures=%d|failed=%s" % [bench_status, _checks, _failures.size(), bench_failed_cases])
	bench_finished.emit(0 if _failures.is_empty() else 1)
