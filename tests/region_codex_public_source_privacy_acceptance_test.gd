extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const COORDINATOR_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator"
const SOURCE_SERVICE_NAME := "RegionCodexPublicSourceService"
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
var _source_service: Node
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
	_expect(await _start_formal_session(), "formal_setup_application_path_starts_session")
	await _wait_frames(4)

	_coordinator = _main.get_node_or_null(COORDINATOR_PATH) as GameRuntimeCoordinator
	_source_service = _coordinator.get_node_or_null(SOURCE_SERVICE_NAME) if _coordinator != null else null
	_monster_owner = _coordinator.get_node_or_null("MonsterRuntimeController") if _coordinator != null else null
	var world: WorldSessionState = (_coordinator as GameRuntimeCoordinator).world_session_state() if _coordinator != null else null
	var districts: Array = world.districts if world != null else []
	var players: Array = world.players if world != null else []
	_main.process_mode = Node.PROCESS_MODE_DISABLED
	_district_index = _first_live_district(districts)
	_expect(_coordinator != null and _coordinator.has_method("region_codex_public_snapshot"), "production_coordinator_region_composition_reachable")
	_expect(_source_service != null and _source_service.has_method("compose_source"), "production_region_public_source_service_reachable")
	_expect(_monster_owner != null, "production_monster_owner_reachable")
	_expect(_district_index >= 0 and players.size() >= 3, "three_player_active_region_fixture_reachable")
	if _coordinator == null or _source_service == null or _monster_owner == null or _district_index < 0 or players.size() < 3:
		await _dispose_main()
		_finish()
		return

	_test_cross_viewer_private_state_invariance()
	_test_sanitized_public_clue_delta()
	_test_monster_reason_privacy_boundary()
	_test_expired_monster_peer_factor_exclusion()
	_test_future_region_attraction_owner_api()
	_test_current_intel_query_owner_boundary()

	await _dispose_main()
	_finish()


func _start_formal_session() -> bool:
	var flow := _main.get_node_or_null("RuntimeServices/ApplicationFlowPort") as ApplicationFlowPort
	if flow == null or not flow.submit_action("setup"):
		return false
	await _wait_frames(2)
	var start_button := _main.find_child("NewGameSetupStartButton", true, false) as Button
	if start_button == null or start_button.disabled:
		return false
	start_button.pressed.emit()
	await _wait_frames(8)
	return true


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
	var districts: Array = ((_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts
	var district := (districts[_district_index] as Dictionary).duplicate(true)
	var city := (district.get("city", {}) as Dictionary).duplicate(true)
	city["last_public_clue"] = PUBLIC_CLUE
	district["city"] = city
	districts[_district_index] = district
	((_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts
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


func _test_expired_monster_peer_factor_exclusion() -> void:
	var live_variant: Variant = _monster_owner.call("_make_auto_monster", 0, 0, _district_index, 0, 1)
	var peer_variant: Variant = _monster_owner.call("_make_auto_monster", 1, 1, _district_index, 1, 1)
	var live: Dictionary = live_variant if live_variant is Dictionary else {}
	var peer: Dictionary = peer_variant if peer_variant is Dictionary else {}
	# Keep the positive control focused on peer presence so unrelated resource
	# affinity cannot displace other_monster from the three public factor slots.
	live["resource_focus"] = []
	peer["resource_focus"] = []
	_monster_owner.set("auto_monsters", [live, peer])
	var live_peer_snapshot: Dictionary = _monster_owner.call("region_attraction_public_snapshot_v06", _district_index)
	var live_peer_entries: Array = live_peer_snapshot.get("entries", []) if live_peer_snapshot.get("entries", []) is Array else []
	var live_peer_codes: Array = []
	if not live_peer_entries.is_empty() and live_peer_entries[0] is Dictionary:
		live_peer_codes = (live_peer_entries[0] as Dictionary).get("factor_codes", []) as Array
	_expect(
		live_peer_entries.size() == 2 and live_peer_codes.has("other_monster"),
		"live_peer_contributes_other_monster_factor|entries=%d|codes=%s" % [live_peer_entries.size(), live_peer_codes]
	)

	peer["remaining_time"] = 0.0
	_monster_owner.set("auto_monsters", [live, peer])
	var expired_peer_snapshot: Dictionary = _monster_owner.call("region_attraction_public_snapshot_v06", _district_index)
	var expired_peer_entries: Array = expired_peer_snapshot.get("entries", []) if expired_peer_snapshot.get("entries", []) is Array else []
	var surviving_codes: Array = []
	if not expired_peer_entries.is_empty() and expired_peer_entries[0] is Dictionary:
		surviving_codes = (expired_peer_entries[0] as Dictionary).get("factor_codes", []) as Array
	_expect(
		expired_peer_entries.size() == 1 and not surviving_codes.has("other_monster"),
		"expired_peer_is_excluded_from_survivor_factor_codes|entries=%d|codes=%s" % [expired_peer_entries.size(), surviving_codes]
	)


func _test_future_region_attraction_owner_api() -> void:
	var owner_api_present := _monster_owner != null and _monster_owner.has_method("region_attraction_public_snapshot_v06")
	_expect(owner_api_present, "region_attraction_public_owner_api_missing")


func _test_current_intel_query_owner_boundary() -> void:
	_reset_private_fixture()
	var coordinator := _main.get_node_or_null(COORDINATOR_PATH) as GameRuntimeCoordinator
	var query := _main.get_node_or_null("RuntimeServices/IntelDossierViewerQueryPort") as IntelDossierViewerQueryPort
	var world := coordinator.world_session_state() if coordinator != null else null
	_expect(query != null and world != null, "scene_owned_intel_query_and_world_owner_reachable")
	if query == null or world == null:
		return
	var world_before := world.internal_snapshot()
	var region_id := world.region_id_for_district(_district_index)
	var snapshot := query.snapshot_for_authorized_viewer("", region_id)
	var encoded := JSON.stringify(snapshot)
	_expect(bool(snapshot.get("valid", false)) and snapshot.has("public_world_intel") and snapshot.has("own_private_city_or_facility_inference"), "scene_owned_intel_query_contract_reachable")
	_expect(world.internal_snapshot() == world_before, "scene_owned_intel_query_zero_world_mutation")
	var leaks: Array[String] = []
	_collect_string_sentinel_paths(snapshot, "intel_query", leaks)
	_expect(leaks.is_empty() and not encoded.contains("hidden_owner") and not encoded.contains("warehouse_inventory"), "scene_owned_intel_query_private_state_isolated|leaks=%s" % [leaks])
	var main_script := _main.get_script() as Script
	var main_source := main_script.get_source_code() if main_script != null else ""
	_expect(not main_source.is_empty() and not main_source.contains("func _intel_city_guess_entries(") and not main_source.contains("func _economy_warehouse_risk_entries("), "retired_main_private_intel_wrappers_absent")


func _reset_private_fixture() -> void:
	((_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player = 0
	((_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = _district_index
	var players: Array = ((_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players
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
	((_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players

	var districts: Array = ((_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts
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
	((_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts

	var actor_variant: Variant = _monster_owner.call("_make_auto_monster", 0, 0, _district_index, 2, 1)
	var actor: Dictionary = actor_variant if actor_variant is Dictionary else {}
	actor["hidden_owner"] = "REGION_PRIVATE_MONSTER_OWNER_A"
	actor["owner_actor_id_v06"] = "REGION_PRIVATE_MONSTER_OWNER_A"
	_monster_owner.set("auto_monsters", [actor])


func _apply_private_mutation(mutation_id: String) -> void:
	match mutation_id:
		"selected_player":
			((_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player = 1
		"city_guesses":
			var players: Array = ((_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players
			var player := (players[0] as Dictionary).duplicate(true)
			player["city_guesses"] = {_district_index: 1}
			players[0] = player
			((_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
		"exact_cash":
			var players: Array = ((_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players
			var player := (players[0] as Dictionary).duplicate(true)
			player["cash"] = 987654321
			player["cash_cents"] = 98765432100
			players[0] = player
			((_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
		"hand_discard":
			var players: Array = ((_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players
			var player := (players[0] as Dictionary).duplicate(true)
			player["slots"] = [{"name": "REGION_PRIVATE_HAND_B", "kind": "private_test"}]
			player["private_discard"] = ["REGION_PRIVATE_DISCARD_B"]
			players[0] = player
			((_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
		"hidden_city_owner":
			var districts: Array = ((_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts
			var district := (districts[_district_index] as Dictionary).duplicate(true)
			var city := (district.get("city", {}) as Dictionary).duplicate(true)
			city["owner"] = 0
			city["hidden_owner"] = "REGION_PRIVATE_CITY_OWNER_B"
			district["city"] = city
			districts[_district_index] = district
			((_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts
		"hidden_monster_owner":
			var actors: Array = _monster_owner.get("auto_monsters")
			var actor := (actors[0] as Dictionary).duplicate(true)
			actor["owner"] = 0
			actor["hidden_owner"] = "REGION_PRIVATE_MONSTER_OWNER_B"
			actor["owner_actor_id_v06"] = "REGION_PRIVATE_MONSTER_OWNER_B"
			actors[0] = actor
			_monster_owner.set("auto_monsters", actors)
		"ai_private_plan":
			var players: Array = ((_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players
			var player := (players[0] as Dictionary).duplicate(true)
			player["ai_private_plan"] = "REGION_PRIVATE_AI_PLAN_B"
			player["ai_memory"] = {"private_plan": "REGION_PRIVATE_AI_PLAN_B"}
			players[0] = player
			((_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players


func _region_source() -> Dictionary:
	var value: Variant = _source_service.call("compose_source", _district_index)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _region_snapshot(_source: Dictionary) -> Dictionary:
	var value: Variant = _coordinator.call("region_codex_public_snapshot", _district_index)
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
