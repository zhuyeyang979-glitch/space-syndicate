extends SceneTree

const SESSION_DRIVER := preload("res://tests/support/production_session_start_driver.gd")
const PROJECTION := preload("res://scripts/presentation/player_card_dock_projection_v1.gd")
const INTENT := preload("res://scripts/semantic/game_action_intent_v1.gd")

const QA_SAVE_PATH := "user://test_runs/alpha04_player_card_dock_invariants.save"
const TASK_PRODUCTION_SOURCES: Array[String] = [
	"res://scenes/runtime/presentation/PlayerCardDockViewerQueryPort.tscn",
	"res://scenes/ui/table/CardDockActionFeedback.tscn",
	"res://scenes/ui/table/PlayerCardDock.tscn",
	"res://scenes/ui/table/TopCommoditySushiTrack.tscn",
	"res://scenes/ui/table/TopCommoditySushiTrackItem.tscn",
	"res://scripts/presentation/card_illustration_catalog.gd",
	"res://scripts/presentation/card_illustration_catalog_resource.gd",
	"res://scripts/presentation/player_card_dock_projection_service.gd",
	"res://scripts/presentation/player_card_dock_projection_v1.gd",
	"res://scripts/presentation/player_card_dock_viewer_query_port.gd",
	"res://scripts/runtime/commodity_sushi_track_claim_request.gd",
	"res://scripts/runtime/commodity_sushi_track_runtime_service.gd",
	"res://scripts/ui/table/card_dock_action_feedback.gd",
	"res://scripts/ui/table/player_card_dock.gd",
	"res://scripts/ui/table/top_commodity_sushi_track.gd",
	"res://scripts/ui/table/top_commodity_sushi_track_item.gd",
]
const SAVE_OR_RNG_OWNER_TOKENS: Array[String] = [
	"RandomNumberGenerator.new(",
	"RunRngService.new(",
	"randf(",
	"randi(",
	"randf_range(",
	"randi_range(",
	"func to_save_data",
	"func apply_save_data",
	"func apply_save_data",
	"save_section",
	"register_save",
	"FileAccess.open(",
	"ConfigFile.new(",
]
const NEW_MAIN_CALL_TOKENS: Array[String] = [
	"/root/Main",
	"get_tree().current_scene",
	"main_instance.call(",
	"main_instance.get(",
	"main_instance.set(",
	"Main.call(",
	"Main.get(",
	"Main.set(",
]

var _checks := 0
var _failures: Array[String] = []
var _new_save_owner_count := 0
var _new_rng_owner_count := 0
var _new_rng_draw_count := 0
var _new_main_call_count := 0
var _duplicate_submission_entry_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_qa_save()
	_test_worktree_diff_invariants()
	_test_static_privacy_and_action_routes()
	await _test_runtime_query_invariants()
	_remove_qa_save()
	_finish()


func _test_worktree_diff_invariants() -> void:
	for path in ["scripts/main.gd", "scenes/main.tscn", "project.godot"]:
		var result := _git(["diff", "--quiet", "HEAD", "--", path])
		_expect(int(result.get("exit_code", -1)) == 0, "%s has no Alpha 0.4-A diff" % path)

	var diff_result := _git([
		"diff", "HEAD", "--unified=0", "--", ".",
		":(exclude)tests/**", ":(exclude)docs/**",
	])
	_expect(int(diff_result.get("exit_code", -1)) == 0, "production diff is readable through git")
	var added_lines := _added_diff_lines(str(diff_result.get("output", "")))
	_new_save_owner_count = _line_token_count(added_lines, [
		"class_name Save", "save_owner", "save_section", "register_save",
		"func to_save_data", "func apply_save_data", "FileAccess.open(", "ConfigFile.new(",
	])
	_new_rng_owner_count = _line_token_count(added_lines, [
		"RandomNumberGenerator.new(", "RunRngService.new(",
	])
	_new_rng_draw_count = _line_token_count(added_lines, [
		"randf(", "randi(", "randf_range(", "randi_range(", "rng.draw", "rng.next", "rng.rand",
	])
	_new_main_call_count = _line_token_count(added_lines, NEW_MAIN_CALL_TOKENS)
	_expect(_new_save_owner_count == 0, "task diff adds no Save owner, section or file-write entry")
	_expect(_new_rng_owner_count == 0, "task diff adds no RNG owner")
	_expect(_new_rng_draw_count == 0, "task diff adds no RNG draw point")
	_expect(_new_main_call_count == 0, "task diff adds no Main lookup or dynamic call")

	var source_token_hits := 0
	for path in TASK_PRODUCTION_SOURCES:
		var source := FileAccess.get_file_as_string(path)
		_expect(not source.is_empty(), "%s is readable" % path)
		for token in SAVE_OR_RNG_OWNER_TOKENS:
			source_token_hits += source.count(token)
	_expect(source_token_hits == 0, "new Dock, claim and art surfaces own no Save or RNG API")


func _test_static_privacy_and_action_routes() -> void:
	var screen_scene := _source("res://scenes/ui/GameScreen.tscn")
	var board_scene := _source("res://scenes/ui/PlayerBoard.tscn")
	var main_scene := _source("res://scenes/main.tscn")
	var screen_source := _source("res://scripts/ui/game_screen.gd")
	var board_source := _source("res://scripts/ui/player_board.gd")
	var inspector_source := _source("res://scripts/ui/right_inspector.gd")
	var dock_source := _source("res://scripts/ui/table/player_card_dock.gd")
	var dock_query_source := _source("res://scripts/presentation/player_card_dock_viewer_query_port.gd")
	var track_source := _source("res://scripts/ui/table/top_commodity_sushi_track.gd")
	var track_item_source := _source("res://scripts/ui/table/top_commodity_sushi_track_item.gd")
	var track_item_scene := _source("res://scenes/ui/table/TopCommoditySushiTrackItem.tscn")

	_expect(screen_scene.count("PlayerCardDock.tscn") == 1, "production GameScreen has one PlayerCardDock")
	_expect(not board_scene.contains("HandRack.tscn") and not board_scene.contains("PlayerHandTableau"), "production PlayerBoard has no legacy HandRack surface")
	_expect(not board_source.contains("hand_rack") and not board_source.contains("signal card_selected") \
		and not board_source.contains("func set_hand_cards"), "PlayerBoard has no legacy card selection or submission bridge")
	_expect(screen_source.count("player_card_dock.game_action_offer_requested.connect") == 1 \
		and dock_source.count("game_action_offer_requested.emit") == 1, "Dock card actions have one UI signal route")
	_expect(screen_source.count("game_action_intent_requested.emit(intent)") == 1 \
		and main_scene.count("signal=\"game_action_intent_requested\"") == 1, "card offers enter one typed Action Spine connection")
	_expect(not dock_source.contains("submit_intent") and not dock_source.contains("CommodityCardInventoryRuntimeController") \
		and not dock_source.contains("/root/Main"), "Dock performs no gameplay mutation or direct submission")

	_expect(not inspector_source.contains("commodity_claim_selected") \
		and inspector_source.contains("\"actions\": []"), "RightInspector commodity details are read-only")
	_expect(screen_source.contains("func _retire_right_inspector_card_actions(") \
		and screen_source.contains("read_only_details[\"actions\"] = []") \
		and not screen_source.contains("func _card_game_action_entry("), "RightInspector cannot retain a Dock card-play offer")
	_expect(not screen_source.contains("player_board.has_signal(\"card_selected\")") \
		and not screen_source.contains("func _on_card_drag_released"), "GameScreen has no HandRack card submission fallback")

	_expect(track_item_scene.count("type=\"Button\"") == 0 \
		and track_item_source.count("claim_requested.emit(item_snapshot())") == 1, "commodity source card has no claim Button and emits one claim signal")
	_expect(track_source.count("claim_requested.emit(current_item)") == 1 \
		and screen_source.count("commodity_claim_requested.emit(request)") == 1 \
		and main_scene.count("signal=\"commodity_claim_requested\"") == 1, "commodity claim has one scene-to-application-flow route")
	_duplicate_submission_entry_count = maxi(
		0,
		dock_source.count("game_action_offer_requested.emit") - 1
	) + maxi(
		0,
		screen_source.count("commodity_claim_requested.emit(request)") - 1
	)
	_expect(_duplicate_submission_entry_count == 0, "no duplicate card or commodity submission emitter exists")

	_expect(dock_query_source.contains("can_view_private_subject(viewer_index, viewer_index)") \
		and dock_query_source.contains("private_world_projection(viewer_index, viewer_index)"), "Dock query binds private reads to the same authorized viewer")
	for key in [
		"rival_hand", "rival_commodity_inventory", "future_track_sequence", "future_rack",
		"hidden_owner", "true_owner", "anonymous_true_player", "private_target_player_binding",
		"ai_plan", "ai_score", "rng_state",
	]:
		_expect(PROJECTION.FORBIDDEN_KEYS.has(key), "projection denylist contains %s" % key)


func _test_runtime_query_invariants() -> void:
	var start: Dictionary = await SESSION_DRIVER.start_configured_session(
		self,
		{
			"player_count": 3,
			"ai_player_count": 2,
			"challenge_depth": 1,
			"role_indices": [0, 1, 2],
			"starter_monster_indices": [0, 1, 2],
		},
		QA_SAVE_PATH,
		"alpha04-player-card-dock-invariants"
	)
	var app_root := start.get("main_root") as Node
	var coordinator := start.get("coordinator") as GameRuntimeCoordinator
	_expect(bool(start.get("started", false)) and app_root != null and coordinator != null, "real three-seat production session starts")
	if app_root == null or coordinator == null:
		await _cleanup(app_root)
		return
	coordinator.pause_session()
	await process_frame

	var screen := app_root.find_child("RuntimeGameScreen", true, false) as SpaceSyndicateGameScreen
	var query := coordinator.get_node_or_null("PlayerCardDockViewerQueryPort") as PlayerCardDockViewerQueryPort
	var query_ports := coordinator.get_node_or_null("TablePresentationQueryPorts") as TablePresentationQueryPorts
	var rng := coordinator.run_rng_service()
	var inventory := coordinator.commodity_card_inventory_runtime_controller()
	var save_coordinator := start.get("save_coordinator") as GameSaveRuntimeCoordinator
	_expect(screen != null and query != null and query_ports != null and rng != null \
		and inventory != null and save_coordinator != null, "production privacy, Save and RNG audit dependencies exist")
	if screen == null or query == null or query_ports == null or rng == null \
			or inventory == null or save_coordinator == null:
		await _cleanup(app_root)
		return

	var context := query_ports.viewer_context()
	var actor_binding := coordinator.actor_id_for_player_index(0)
	var actor_id := str(actor_binding.get("actor_id", ""))
	var world := coordinator.world_session_state()
	# Prime the existing v0.6 adapter's observed fingerprint before taking the
	# zero-mutation baseline; this metadata initialization is owned by the
	# authoritative adapter, not by the presentation query under test.
	var card_authority_before := JSON.stringify(coordinator.v06_card_player_snapshot(actor_id))
	var commodity_authority_before := JSON.stringify(inventory.player_snapshot(actor_id))
	var world_before_data := {
		"players": world.players.duplicate(true),
		"districts": world.districts.duplicate(true),
	}
	var world_before := JSON.stringify(world_before_data)
	var rng_before := JSON.stringify(rng.debug_snapshot())
	var save_before := JSON.stringify(save_coordinator.call("operation_snapshot"))

	var projection := query.snapshot_for_viewer(0, context.authorization_revision)
	var denied_rival := query.snapshot_for_viewer(1, context.authorization_revision)
	var query_debug := query.debug_snapshot()
	var dock := screen.find_child("PlayerCardDock", true, false) as SpaceSyndicatePlayerCardDock
	var dock_debug := dock.debug_snapshot() if dock != null else {}
	var track := screen.find_child("TopCommoditySushiTrack", true, false)
	var track_debug: Dictionary = track.call("debug_snapshot") if track != null and track.has_method("debug_snapshot") else {}
	var player_board_projection: Dictionary = screen.current_ui_data.get("player_board", {}) \
		if screen.current_ui_data.get("player_board", {}) is Dictionary else {}
	var inspector_projection: Dictionary = screen.current_ui_data.get("right_inspector", {}) \
		if screen.current_ui_data.get("right_inspector", {}) is Dictionary else {}
	var legacy_card_action_entries := _count_action_id(player_board_projection, "play") \
		+ _count_semantic_action_offers(inspector_projection, INTENT.ACTION_CARD_PLAY)
	_duplicate_submission_entry_count += legacy_card_action_entries

	_expect(bool(PROJECTION.validation_report(projection).get("valid", false)) \
		and PROJECTION.matches_viewer_authorization(projection, 0, context.authorization_revision), "real Dock query returns only the authorized viewer projection")
	_expect(denied_rival.is_empty(), "human viewer cannot query a rival private Dock")
	_expect(not _contains_any_key_recursive(projection, PROJECTION.FORBIDDEN_KEYS), "real projection contains no rival hand, rival commodity, future track or hidden-owner key")
	_expect(bool(query_debug.get("viewer_authorized_only", false)) \
		and not bool(query_debug.get("mutates_gameplay", true)) \
		and not bool(query_debug.get("stores_card_state", true)) \
		and not bool(query_debug.get("consumes_rng", true)) \
		and not bool(query_debug.get("references_main", true)), "viewer query is a zero-mutation, zero-state, zero-RNG, no-Main port")
	_expect(not bool(dock_debug.get("mutates_gameplay", true)) \
		and not bool(dock_debug.get("reads_world_state", true)) \
		and int(dock_debug.get("action_entry_count", 0)) == 1, "production Dock owns presentation and one signal only")
	_expect(int(track_debug.get("direct_inventory_mutation_count", -1)) == 0 \
		and int(track_debug.get("direct_track_mutation_count", -1)) == 0 \
		and int(track_debug.get("claim_button_count", -1)) == 0, "commodity source UI has no direct mutation or hidden claim button")
	_expect(legacy_card_action_entries == 0, "PlayerBoard and RightInspector expose no duplicate card-play offer")

	var right_inspector := screen.find_child("RightInspector", true, false) as SpaceSyndicateRightInspector
	if right_inspector != null:
		right_inspector.show_public_commodity({
			"public_name": "审计商品",
			"public_supply_pressure": 1,
			"public_demand_pressure": 1,
			"public_market_price": 1,
			"public_market_trend": 0,
			"claimable": true,
			"public_claim_disabled_reason": "",
			"commodity_slot_id": "slot.audit",
			"public_short_effect": "审计只读详情",
			"public_industry": "life",
		})
	await process_frame
	var inspector_actions := right_inspector.get_node_or_null("InspectorRows/CurrentActionPanel") as SpaceSyndicateActionDock \
		if right_inspector != null else null
	_expect(inspector_actions != null and inspector_actions.actions_signature == var_to_str([]), "runtime RightInspector exposes no commodity claim action")
	_expect(screen.find_child("HandRack", true, false) == null \
		and screen.find_children("PlayerCardDock", "", true, false).size() == 1, "runtime table has one Dock and no legacy HandRack")

	var world_after_data := {
		"players": world.players.duplicate(true),
		"districts": world.districts.duplicate(true),
	}
	var world_after := JSON.stringify(world_after_data)
	if world_after != world_before:
		print("ALPHA04_INVARIANT_WORLD_DELTA|%s" % _first_difference(world_before_data, world_after_data))
	_expect(world_after == world_before, "UI and query inspection mutate no world gameplay state")
	_expect(JSON.stringify(coordinator.v06_card_player_snapshot(actor_id)) == card_authority_before, "UI and query inspection mutate no normal-card authority")
	_expect(JSON.stringify(inventory.player_snapshot(actor_id)) == commodity_authority_before, "UI and query inspection mutate no commodity inventory authority")
	_expect(JSON.stringify(rng.debug_snapshot()) == rng_before, "UI and query inspection consume zero RNG draws")
	_expect(JSON.stringify(save_coordinator.call("operation_snapshot")) == save_before, "UI and query inspection perform no Save operation")

	await _cleanup(app_root)


func _git(arguments: Array[String]) -> Dictionary:
	var packed := PackedStringArray(["-C", ProjectSettings.globalize_path("res://")])
	for argument in arguments:
		packed.append(argument)
	var output: Array = []
	var exit_code := OS.execute("git", packed, output, true)
	var combined := ""
	for chunk in output:
		combined += str(chunk)
	return {"exit_code": exit_code, "output": combined}


func _added_diff_lines(diff_text: String) -> Array[String]:
	var result: Array[String] = []
	for line in diff_text.split("\n"):
		if line.begins_with("+") and not line.begins_with("+++"):
			result.append(line.substr(1))
	return result


func _line_token_count(lines: Array[String], tokens: Array[String]) -> int:
	var count := 0
	for line in lines:
		for token in tokens:
			count += line.count(token)
	return count


func _contains_any_key_recursive(value: Variant, forbidden: Array) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if forbidden.has(str(key_variant)):
				return true
			if _contains_any_key_recursive((value as Dictionary).get(key_variant), forbidden):
				return true
	elif value is Array:
		for item in value as Array:
			if _contains_any_key_recursive(item, forbidden):
				return true
	return false


func _count_semantic_action_offers(value: Variant, semantic_action_id: String) -> int:
	var count := 0
	if value is Dictionary:
		var dictionary := value as Dictionary
		var offer: Variant = dictionary.get("game_action_offer", {})
		if offer is Dictionary and str((offer as Dictionary).get("semantic_action_id", "")) == semantic_action_id:
			count += 1
		for nested in dictionary.values():
			count += _count_semantic_action_offers(nested, semantic_action_id)
	elif value is Array:
		for nested in value as Array:
			count += _count_semantic_action_offers(nested, semantic_action_id)
	return count


func _count_action_id(value: Variant, action_id: String) -> int:
	var count := 0
	if value is Dictionary:
		var dictionary := value as Dictionary
		if str(dictionary.get("id", "")) == action_id:
			count += 1
		for nested in dictionary.values():
			count += _count_action_id(nested, action_id)
	elif value is Array:
		for nested in value as Array:
			count += _count_action_id(nested, action_id)
	return count


func _first_difference(before: Variant, after: Variant, path: String = "world") -> String:
	if typeof(before) != typeof(after):
		return "%s|type=%s->%s" % [path, type_string(typeof(before)), type_string(typeof(after))]
	if before is Dictionary:
		var before_dictionary := before as Dictionary
		var after_dictionary := after as Dictionary
		var keys: Array = before_dictionary.keys()
		for key_variant in after_dictionary.keys():
			if not keys.has(key_variant):
				keys.append(key_variant)
		keys.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
		for key_variant in keys:
			if not before_dictionary.has(key_variant) or not after_dictionary.has(key_variant):
				return "%s.%s|presence=%s->%s" % [
					path,
					str(key_variant),
					str(before_dictionary.has(key_variant)),
					str(after_dictionary.has(key_variant)),
				]
			var nested := _first_difference(
				before_dictionary.get(key_variant),
				after_dictionary.get(key_variant),
				"%s.%s" % [path, str(key_variant)]
			)
			if not nested.is_empty():
				return nested
		return ""
	if before is Array:
		var before_array := before as Array
		var after_array := after as Array
		if before_array.size() != after_array.size():
			return "%s|size=%d->%d" % [path, before_array.size(), after_array.size()]
		for index in range(before_array.size()):
			var nested := _first_difference(before_array[index], after_array[index], "%s[%d]" % [path, index])
			if not nested.is_empty():
				return nested
		return ""
	return "" if before == after else "%s|value=%s->%s" % [path, str(before), str(after)]


func _source(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _remove_qa_save() -> void:
	var absolute := ProjectSettings.globalize_path(QA_SAVE_PATH)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func _cleanup(app_root: Node) -> void:
	if app_root == null:
		return
	for node in app_root.find_children("*", "AudioStreamPlayer", true, false):
		(node as AudioStreamPlayer).stop()
	app_root.queue_free()
	await process_frame


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print(
		"ALPHA04_PLAYER_CARD_DOCK_INVARIANTS_TEST|status=%s|checks=%d|failures=%d|new_save_owner=%d|new_rng_owner=%d|new_rng_draw=%d|new_main_call=%d|duplicate_submission_entry=%d" % [
			status,
			_checks,
			_failures.size(),
			_new_save_owner_count,
			_new_rng_owner_count,
			_new_rng_draw_count,
			_new_main_call_count,
			_duplicate_submission_entry_count,
		]
	)
	for failure in _failures:
		push_error("ALPHA04_PLAYER_CARD_DOCK_INVARIANTS_TEST: %s" % failure)
	quit(0 if _failures.is_empty() else 1)
