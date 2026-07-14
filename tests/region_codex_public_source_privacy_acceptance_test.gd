extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const COORDINATOR_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator"
const PUBLIC_CLUE := "PUBLIC_REGION_AFTERMATH_SANITIZED_V06"
const PRIVATE_SENTINELS := [
	"REGION_PRIVATE_HAND_A",
	"REGION_PRIVATE_HAND_B",
	"REGION_PRIVATE_DISCARD_A",
	"REGION_PRIVATE_DISCARD_B",
	"REGION_PRIVATE_CITY_OWNER_A",
	"REGION_PRIVATE_CITY_OWNER_B",
	"REGION_PRIVATE_MONSTER_OWNER_A",
	"REGION_PRIVATE_MONSTER_OWNER_B",
	"REGION_PRIVATE_AI_PLAN_A",
	"REGION_PRIVATE_AI_PLAN_B",
]

var _checks := 0
var _failures: Array[String] = []
var _main: Node
var _coordinator: Node
var _monster_owner: Node
var _district_index := -1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	_expect(packed != null, "production_main_scene_loads")
	if packed == null:
		_finish()
		return
	_main = packed.instantiate()
	root.size = Vector2i(1600, 960)
	root.add_child(_main)
	await _wait_frames(4)
	_main.set("configured_player_count", 3)
	_main.set("configured_ai_player_count", 2)
	_main.set("configured_roguelike_depth", 1)
	_main.set("configured_role_indices", [0, 1, 2])
	_main.set("configured_starter_monster_indices", [0, 1, 2])
	_main.call("_new_game")
	_main.set("time_scale", 0.0)
	await _wait_frames(8)

	_coordinator = _main.get_node_or_null(COORDINATOR_PATH)
	_monster_owner = _main.get("monster_runtime_controller") as Node
	var districts: Array = _main.get("districts") if _main.get("districts") is Array else []
	var players: Array = _main.get("players") if _main.get("players") is Array else []
	_district_index = _first_live_district(districts)
	_expect(_coordinator != null and _coordinator.has_method("compose_codex_region_snapshot"), "production_coordinator_region_composition_reachable")
	_expect(_monster_owner != null, "production_monster_owner_reachable")
	_expect(_district_index >= 0 and players.size() >= 3, "three_player_active_region_fixture_reachable")
	if _coordinator == null or _monster_owner == null or _district_index < 0 or players.size() < 3:
		await _dispose_main()
		_finish()
		return

	_test_cross_viewer_private_state_invariance()
	_test_sanitized_public_clue_delta()
	_test_monster_reason_privacy_boundary()
	_test_future_region_attraction_owner_api()
	_test_private_intel_callers_remain_owned()

	await _dispose_main()
	_finish()


func _test_cross_viewer_private_state_invariance() -> void:
	var source_changes: Array[String] = []
	var snapshot_changes: Array[String] = []
	var sentinel_leaks: Array[String] = []
	for mutation_id in ["selected_player", "city_guesses", "exact_cash", "hand_discard", "hidden_city_owner", "hidden_monster_owner", "ai_private_plan"]:
		_reset_private_fixture()
		var baseline_source := _region_source()
		var baseline_snapshot := _region_snapshot(baseline_source)
		_apply_private_mutation(mutation_id)
		var changed_source := _region_source()
		var changed_snapshot := _region_snapshot(changed_source)
		if _canonical_text(baseline_source) != _canonical_text(changed_source):
			source_changes.append(mutation_id)
		if _canonical_text(baseline_snapshot) != _canonical_text(changed_snapshot):
			snapshot_changes.append(mutation_id)
		_collect_string_sentinel_paths(baseline_source, "baseline.%s.source" % mutation_id, sentinel_leaks)
		_collect_string_sentinel_paths(baseline_snapshot, "baseline.%s.snapshot" % mutation_id, sentinel_leaks)
		_collect_string_sentinel_paths(changed_source, "changed.%s.source" % mutation_id, sentinel_leaks)
		_collect_string_sentinel_paths(changed_snapshot, "changed.%s.snapshot" % mutation_id, sentinel_leaks)
	_expect(source_changes.is_empty(), "region_public_source_private_state_invariance|changed=%s" % [source_changes])
	_expect(snapshot_changes.is_empty(), "region_public_snapshot_private_state_invariance|changed=%s" % [snapshot_changes])
	_expect(sentinel_leaks.is_empty(), "region_public_recursive_string_sentinel_scan|leaks=%s" % [sentinel_leaks])


func _test_sanitized_public_clue_delta() -> void:
	_reset_private_fixture()
	var before_source := _region_source()
	var before_snapshot := _region_snapshot(before_source)
	var districts: Array = _main.get("districts")
	var district := (districts[_district_index] as Dictionary).duplicate(true)
	var city := (district.get("city", {}) as Dictionary).duplicate(true)
	city["last_public_clue"] = PUBLIC_CLUE
	district["city"] = city
	districts[_district_index] = district
	_main.set("districts", districts)
	var after_source := _region_source()
	var after_snapshot := _region_snapshot(after_source)
	var source_paths: Array[String] = []
	var snapshot_paths: Array[String] = []
	_collect_changed_paths(before_source, after_source, "source", source_paths)
	_collect_changed_paths(before_snapshot, after_snapshot, "snapshot", snapshot_paths)
	_expect(str(after_source.get("public_clue", "")) == PUBLIC_CLUE, "sanitized_public_clue_reaches_source")
	_expect(_value_at_path(after_snapshot, ["detail", "clues", 3, "body"]) == PUBLIC_CLUE, "sanitized_public_clue_reaches_final_snapshot")
	_expect(source_paths == ["source.public_clue"], "sanitized_public_clue_source_allowlisted_delta|paths=%s" % [source_paths])
	_expect(snapshot_paths == ["snapshot.detail.clues[3].body"], "sanitized_public_clue_snapshot_allowlisted_delta|paths=%s" % [snapshot_paths])


func _test_monster_reason_privacy_boundary() -> void:
	_reset_private_fixture()
	var source := _region_source()
	var snapshot := _region_snapshot(source)
	var entries: Array = source.get("monster_entries", []) if source.get("monster_entries", []) is Array else []
	_expect(not entries.is_empty(), "production_region_monster_entry_reachable")
	var reason_text := ""
	for entry_variant in entries:
		if entry_variant is Dictionary:
			reason_text += "\n" + str((entry_variant as Dictionary).get("reason", ""))
	reason_text += "\n" + str(_value_at_path(snapshot, ["detail", "clues", 2, "body"]))
	var evidence := _private_reason_evidence(reason_text)
	_expect(evidence.is_empty(), "region_monster_reason_public_schema_safe|evidence=%s" % [evidence])


func _test_future_region_attraction_owner_api() -> void:
	var owner_api_present := _monster_owner != null and _monster_owner.has_method("region_attraction_public_snapshot_v06")
	_expect(owner_api_present, "region_attraction_public_owner_api_missing")


func _test_private_intel_callers_remain_owned() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/main.gd")
	for caller_name in ["_economy_city_income_entries", "_economy_warehouse_risk_entries", "_intel_city_guess_entries"]:
		var caller_source := _function_source(source, caller_name)
		_expect(caller_source.contains("_city_intel_hint_for_player("), "viewer_private_intel_caller_retained|caller=%s" % caller_name)


func _reset_private_fixture() -> void:
	_main.set("selected_player", 0)
	_main.set("selected_district", _district_index)
	var players: Array = _main.get("players")
	for player_index in range(players.size()):
		var player := (players[player_index] as Dictionary).duplicate(true)
		player["cash"] = 900000 + player_index
		player["cash_cents"] = (900000 + player_index) * 100
		player["slots"] = [{"name": "REGION_PRIVATE_HAND_A", "kind": "private_test"}]
		player["private_discard"] = ["REGION_PRIVATE_DISCARD_A"]
		player["city_guesses"] = {}
		player["ai_private_plan"] = "REGION_PRIVATE_AI_PLAN_A"
		player["ai_memory"] = {"private_plan": "REGION_PRIVATE_AI_PLAN_A"}
		players[player_index] = player
	_main.set("players", players)

	var districts: Array = _main.get("districts")
	var district := (districts[_district_index] as Dictionary).duplicate(true)
	district["city"] = {
		"active": true,
		"owner": 2,
		"hidden_owner": "REGION_PRIVATE_CITY_OWNER_A",
		"level": 1,
		"last_income": 100,
		"products": [],
		"demands": [],
		"competition_matches": 0,
		"public_clues": [],
		"last_public_clue": "",
	}
	districts[_district_index] = district
	_main.set("districts", districts)

	var actor_variant: Variant = _monster_owner.call("_make_auto_monster", 0, 0, _district_index, 2, 1)
	var actor: Dictionary = actor_variant if actor_variant is Dictionary else {}
	actor["hidden_owner"] = "REGION_PRIVATE_MONSTER_OWNER_A"
	actor["owner_actor_id_v06"] = "REGION_PRIVATE_MONSTER_OWNER_A"
	_monster_owner.set("auto_monsters", [actor])


func _apply_private_mutation(mutation_id: String) -> void:
	match mutation_id:
		"selected_player":
			_main.set("selected_player", 1)
		"city_guesses":
			var players: Array = _main.get("players")
			var player := (players[0] as Dictionary).duplicate(true)
			player["city_guesses"] = {_district_index: 1}
			players[0] = player
			_main.set("players", players)
		"exact_cash":
			var players: Array = _main.get("players")
			var player := (players[0] as Dictionary).duplicate(true)
			player["cash"] = 987654321
			player["cash_cents"] = 98765432100
			players[0] = player
			_main.set("players", players)
		"hand_discard":
			var players: Array = _main.get("players")
			var player := (players[0] as Dictionary).duplicate(true)
			player["slots"] = [{"name": "REGION_PRIVATE_HAND_B", "kind": "private_test"}]
			player["private_discard"] = ["REGION_PRIVATE_DISCARD_B"]
			players[0] = player
			_main.set("players", players)
		"hidden_city_owner":
			var districts: Array = _main.get("districts")
			var district := (districts[_district_index] as Dictionary).duplicate(true)
			var city := (district.get("city", {}) as Dictionary).duplicate(true)
			city["owner"] = 0
			city["hidden_owner"] = "REGION_PRIVATE_CITY_OWNER_B"
			district["city"] = city
			districts[_district_index] = district
			_main.set("districts", districts)
		"hidden_monster_owner":
			var actors: Array = _monster_owner.get("auto_monsters")
			var actor := (actors[0] as Dictionary).duplicate(true)
			actor["owner"] = 0
			actor["hidden_owner"] = "REGION_PRIVATE_MONSTER_OWNER_B"
			actor["owner_actor_id_v06"] = "REGION_PRIVATE_MONSTER_OWNER_B"
			actors[0] = actor
			_monster_owner.set("auto_monsters", actors)
		"ai_private_plan":
			var players: Array = _main.get("players")
			var player := (players[0] as Dictionary).duplicate(true)
			player["ai_private_plan"] = "REGION_PRIVATE_AI_PLAN_B"
			player["ai_memory"] = {"private_plan": "REGION_PRIVATE_AI_PLAN_B"}
			players[0] = player
			_main.set("players", players)


func _region_source() -> Dictionary:
	var value: Variant = _main.call("_region_codex_public_source_snapshot", _district_index)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _region_snapshot(source: Dictionary) -> Dictionary:
	var value: Variant = _coordinator.call("compose_codex_region_snapshot", source)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _private_reason_evidence(text: String) -> Array[String]:
	var lowered := text.to_lower()
	var evidence: Array[String] = []
	for fragment in ["权重", "%", "numerator", "total", "概率", "rng", "actual", "committed", "target"]:
		if lowered.contains(fragment):
			evidence.append(fragment)
	var plus_pattern := RegEx.new()
	plus_pattern.compile("\\+[0-9]+")
	if plus_pattern.search(text) != null:
		evidence.append("+N")
	var ratio_pattern := RegEx.new()
	ratio_pattern.compile("[0-9]+\\s*/\\s*[0-9]+")
	if ratio_pattern.search(text) != null:
		evidence.append("numerator/total")
	return evidence


func _collect_string_sentinel_paths(value: Variant, path: String, result: Array[String]) -> void:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key_text := str(key_variant)
			_check_string_sentinel(key_text, "%s.<key:%s>" % [path, key_text], result)
			_collect_string_sentinel_paths((value as Dictionary)[key_variant], "%s.%s" % [path, key_text], result)
	elif value is Array:
		for index in range((value as Array).size()):
			_collect_string_sentinel_paths((value as Array)[index], "%s[%d]" % [path, index], result)
	elif value is String or value is StringName:
		_check_string_sentinel(str(value), path, result)


func _check_string_sentinel(text: String, path: String, result: Array[String]) -> void:
	for sentinel in PRIVATE_SENTINELS:
		if text.contains(sentinel):
			result.append("%s:%s" % [path, sentinel])


func _canonical_text(value: Variant) -> String:
	if value is Dictionary:
		var pieces: Array[String] = []
		for key_variant in (value as Dictionary).keys():
			pieces.append("%s:%s" % [var_to_str(key_variant), _canonical_text((value as Dictionary)[key_variant])])
		pieces.sort()
		return "{%s}" % ",".join(pieces)
	if value is Array:
		var pieces: Array[String] = []
		for item_variant in value:
			pieces.append(_canonical_text(item_variant))
		return "[%s]" % ",".join(pieces)
	if value is Color:
		return "Color(%s)" % (value as Color).to_html(true)
	return var_to_str(value)


func _collect_changed_paths(before: Variant, after: Variant, path: String, result: Array[String]) -> void:
	if typeof(before) != typeof(after):
		result.append(path)
		return
	if before is Dictionary:
		var keys: Array = (before as Dictionary).keys()
		for key_variant in (after as Dictionary).keys():
			if not keys.has(key_variant):
				keys.append(key_variant)
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		for key_variant in keys:
			var child_path := "%s.%s" % [path, str(key_variant)]
			if not (before as Dictionary).has(key_variant) or not (after as Dictionary).has(key_variant):
				result.append(child_path)
			else:
				_collect_changed_paths((before as Dictionary)[key_variant], (after as Dictionary)[key_variant], child_path, result)
		return
	if before is Array:
		if (before as Array).size() != (after as Array).size():
			result.append("%s.size" % path)
			return
		for index in range((before as Array).size()):
			_collect_changed_paths((before as Array)[index], (after as Array)[index], "%s[%d]" % [path, index], result)
		return
	if before != after:
		result.append(path)


func _value_at_path(value: Variant, path: Array) -> Variant:
	var current: Variant = value
	for segment in path:
		if segment is int and current is Array and segment >= 0 and segment < (current as Array).size():
			current = (current as Array)[segment]
		elif segment is String and current is Dictionary and (current as Dictionary).has(segment):
			current = (current as Dictionary)[segment]
		else:
			return null
	return current


func _function_source(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start < 0:
		return ""
	var next := source.find("\nfunc ", start + 1)
	return source.substr(start) if next < 0 else source.substr(start, next - start)


func _first_live_district(districts: Array) -> int:
	for index in range(districts.size()):
		if districts[index] is Dictionary and not bool((districts[index] as Dictionary).get("destroyed", false)):
			return index
	return -1


func _wait_frames(count: int) -> void:
	for _index in range(maxi(1, count)):
		await process_frame


func _dispose_main() -> void:
	if _main == null:
		return
	for audio_variant in _main.find_children("*", "AudioStreamPlayer", true, false):
		var audio := audio_variant as AudioStreamPlayer
		if audio != null:
			audio.stop()
			audio.stream = null
	_main.queue_free()
	_main = null
	await _wait_frames(3)


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(label)
	push_error("REGION_CODEX_PUBLIC_SOURCE_PRIVACY_ACCEPTANCE: %s" % label)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("REGION_CODEX_PUBLIC_SOURCE_PRIVACY_ACCEPTANCE|status=%s|checks=%d|failures=%d" % [status, _checks, _failures.size()])
	for failure in _failures:
		print("REGION_CODEX_PUBLIC_SOURCE_PRIVACY_ACCEPTANCE|failure=%s" % failure)
	quit(_failures.size())
