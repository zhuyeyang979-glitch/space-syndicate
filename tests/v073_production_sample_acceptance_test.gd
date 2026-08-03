extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"
const PLAYER_COUNTS := [3, 4, 6, 8]
const COLORS := ["life", "energy", "industry", "technology", "commerce", "shipping"]
const MAX_STEPS := 2000

var _checks := 0
var _failures: Array[String] = []
var _application: Node
var _completed_counts: Array[int] = []
var _fizzle_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(MAIN_SCENE) as PackedScene
	_expect(packed != null, "production main scene loads")
	if packed == null:
		_finish()
		return
	_application = packed.instantiate()
	root.add_child(_application)
	await process_frame
	await process_frame
	var flow := _application.get_node_or_null("V073RuntimeComposition")
	var screen := _application.get_node_or_null("V073SampleGameScreen")
	_expect(flow != null, "V073 runtime composition is reachable from main")
	_expect(screen != null, "V073 player surface is reachable from main")
	if flow == null or screen == null:
		_finish()
		return
	var projection_callback := Callable(_application, "_on_projection_changed")
	if flow.is_connected("projection_changed", projection_callback):
		flow.disconnect("projection_changed", projection_callback)
	_test_main_composition(flow, screen)
	_test_persistence_boundary(flow, screen)
	for player_count in PLAYER_COUNTS:
		await _run_player_count(flow, screen, player_count)
	_expect(_completed_counts == PLAYER_COUNTS, "3/4/6/8 player simulations all complete")
	_expect(_fizzle_count > 0, "production simulations exercise facility contention Fizzle")
	_application.queue_free()
	await process_frame
	_finish()


func _test_main_composition(flow: Node, screen: Node) -> void:
	var source := FileAccess.get_file_as_string(MAIN_SCENE)
	_expect(not source.contains("scripts/main.gd"), "main scene does not attach legacy main.gd")
	for retired in [
		"GameRuntimeCoordinator",
		"V06SaveOwnerRegistry",
		"CommoditySushiTrack",
		"RegionSupply",
		"PublicBid",
		"AuctionTimer",
	]:
		_expect(not source.contains(retired), "main scene excludes %s" % retired)
	var debug := flow.call("debug_snapshot") as Dictionary
	_expect(str(debug.get("ruleset_id", "")) == "v0.7.3", "composition ruleset is V0.7.3")
	_expect(int(debug.get("ruleset_owner_count", 0)) == 1, "composition has one ruleset owner")
	_expect(int(debug.get("gameplay_owner_count", 0)) == 1, "composition has one gameplay owner")
	for field in [
		"v06_production_rule_owner_count",
		"v06_production_ai_policy_count",
		"v06_production_player_projection_count",
		"v06_production_card_supply_count",
		"v06_production_resolution_order_count",
		"v06_production_asset_refresh_count",
		"v06_public_bid_production_reference_count",
		"v06_auction_timer_production_reference_count",
		"v06_region_supply_purchase_surface_count",
		"v06_right_permanent_panel_count",
		"dual_write_count",
		"legacy_fallback_count",
		"mixed_ruleset_state_count",
	]:
		_expect(int(debug.get(field, -1)) == 0, "%s is zero" % field)
	var save_button := screen.find_child("SaveButton", true, false) as Button
	var continue_button := screen.find_child("ContinueButton", true, false) as Button
	_expect(save_button != null and save_button.disabled, "Save is visible and disabled")
	_expect(continue_button != null and continue_button.disabled, "Continue is visible and disabled")


func _test_persistence_boundary(flow: Node, _screen: Node) -> void:
	var save_intent := flow.call("issue_intent", "persistence.save", {}) as Dictionary
	var save_receipt := flow.call("submit_intent", save_intent) as Dictionary
	_expect(not bool(save_receipt.get("accepted", true)), "Save request fails closed")
	_expect(str(save_receipt.get("reason_code", "")) == "v073_sample_save_disabled", "Save rejection is typed")
	_expect(int(save_receipt.get("file_access_count", -1)) == 0, "Save rejection performs no file access")
	var load_intent := flow.call("issue_intent", "persistence.continue", {}) as Dictionary
	var load_receipt := flow.call("submit_intent", load_intent) as Dictionary
	_expect(not bool(load_receipt.get("accepted", true)), "Continue request fails closed")
	_expect(str(load_receipt.get("reason_code", "")) == "v073_sample_continue_disabled", "Continue rejection is typed")
	_expect(int(load_receipt.get("file_access_count", -1)) == 0, "Continue rejection performs no file access")


func _run_player_count(flow: Node, screen: Node, player_count: int) -> void:
	var start_intent := flow.call("issue_intent", "new_game.start", {
		"player_count": player_count,
		"seed": 730045 + player_count * 1009,
	}) as Dictionary
	var started := flow.call("submit_intent", start_intent) as Dictionary
	_expect(bool(started.get("accepted", false)), "%dP new game starts" % player_count)
	if not bool(started.get("accepted", false)):
		return
	var runtime := flow.get_node_or_null("V073SampleRuntimeOwner")
	_expect(runtime != null, "%dP runtime owner is reachable" % player_count)
	if runtime == null:
		return
	var initial := flow.call("local_snapshot") as Dictionary
	_test_initial_state(initial, runtime, player_count)
	screen.call("apply_snapshot", initial)
	await process_frame
	_test_ai_privacy(runtime, player_count)
	print("V073_PRODUCTION_SAMPLE_ACCEPTANCE|stage=%dP_INITIAL_READY" % player_count)
	var accelerate_intent := flow.call("issue_intent", "sample.accelerate", {
		"max_steps": MAX_STEPS,
	}) as Dictionary
	var completed := flow.call("submit_intent", accelerate_intent) as Dictionary
	_expect(bool(completed.get("accepted", false)), "%dP accelerated legal match settles" % player_count)
	await process_frame
	var debug := flow.call("debug_snapshot") as Dictionary
	var runtime_debug := debug.get("runtime", {}) as Dictionary
	_test_completion(runtime_debug, player_count)
	var final_snapshot := flow.call("local_snapshot") as Dictionary
	screen.call("apply_snapshot", final_snapshot)
	await process_frame
	print("V073_PRODUCTION_SAMPLE_ACCEPTANCE|stage=%dP_SETTLED" % player_count)
	for row_variant in final_snapshot.get("public_history", []) as Array:
		if row_variant is Dictionary and str((row_variant as Dictionary).get("outcome_id", "")) == "facility_action_fizzled":
			_fizzle_count += 1
	var acceptance := screen.get("acceptance_state") as Dictionary
	_test_ui_acceptance(acceptance, player_count)
	if bool(completed.get("accepted", false)) and str(runtime_debug.get("phase", "")) == "settled":
		_completed_counts.append(player_count)


func _test_initial_state(snapshot: Dictionary, runtime: Node, player_count: int) -> void:
	_expect(str(snapshot.get("ruleset_id", "")) == "v0.7.3", "%dP snapshot ruleset is V0.7.3" % player_count)
	_expect((snapshot.get("roster", []) as Array).size() == player_count, "%dP roster is complete" % player_count)
	var all_track_kinds := {}
	for actor_index in range(player_count):
		var actor_id := "player.local" if actor_index == 0 else "player.ai.%d" % actor_index
		var actor_snapshot := runtime.call("player_snapshot", actor_id) as Dictionary
		var facts := (actor_snapshot.get("personal_dbg", {}) as Dictionary).get("facts", {}) as Dictionary
		_expect(int(facts.get("hand_count", -1)) == 5, "%s opens with five cards" % actor_id)
		_expect(int(facts.get("normal_deck_total_card_count", -1)) == 12, "%s owns twelve starter cards" % actor_id)
		var assets := actor_snapshot.get("six_color_assets", {}) as Dictionary
		var exact_assets := assets.get("own_exact_assets", {}) as Dictionary
		for color in COLORS:
			_expect(int(exact_assets.get(color, -1)) == 0, "%s %s starts at zero" % [actor_id, color])
		var track := actor_snapshot.get("unified_track", {}) as Dictionary
		var private_facts := track.get("viewer_private_facts", {}) as Dictionary
		for item_variant in private_facts.get("own_segment_items", []) as Array:
			if item_variant is Dictionary:
				all_track_kinds[str((item_variant as Dictionary).get("card_kind", ""))] = true
	_expect(all_track_kinds.has("normal_card"), "%dP unified track carries normal cards" % player_count)
	_expect(all_track_kinds.has("commodity_card"), "%dP unified track carries commodity cards" % player_count)


func _test_ai_privacy(runtime: Node, player_count: int) -> void:
	for actor_index in range(1, player_count):
		var actor_id := "player.ai.%d" % actor_index
		var observation := runtime.call("ai_observation", actor_id) as Dictionary
		_expect(not observation.is_empty(), "%s receives canonical observation" % actor_id)
		var canonical := observation.get("canonical_observation", {}) as Dictionary
		var dbg := canonical.get("personal_dbg", {}) as Dictionary
		var facts := dbg.get("facts", {}) as Dictionary
		for zone in ["hand", "discard"]:
			for card_variant in facts.get(zone, []) as Array:
				if card_variant is Dictionary:
					_expect(str((card_variant as Dictionary).get("instance_id", "")).begins_with("dbg.%s." % actor_id), "%s sees only its own %s" % [actor_id, zone])
		var encoded := JSON.stringify(observation)
		for rival_index in range(player_count):
			var rival_id := "player.local" if rival_index == 0 else "player.ai.%d" % rival_index
			if rival_id == actor_id:
				continue
			_expect(not encoded.contains("dbg.%s." % rival_id), "%s cannot read %s hand IDs" % [actor_id, rival_id])
			_expect(not encoded.contains("commodity.%s." % rival_id), "%s cannot read %s commodity IDs" % [actor_id, rival_id])


func _test_completion(debug: Dictionary, player_count: int) -> void:
	_expect(str(debug.get("phase", "")) == "settled", "%dP reaches settled" % player_count)
	_expect(int(debug.get("player_count", 0)) == player_count, "%dP debug player count is exact" % player_count)
	_expect(int(debug.get("local_human_count", 0)) == 1, "%dP has one local human" % player_count)
	_expect(int(debug.get("ai_player_count", 0)) == player_count - 1, "%dP AI count is exact" % player_count)
	for field in [
		"invalid_action_count",
		"nonfinite_count",
		"hidden_info_violation_count",
		"dual_authority_count",
		"runtime_error_count",
		"adapter_failure_count",
		"v06_runtime_mutation_count",
		"legacy_fallback_count",
		"mixed_ruleset_state_count",
		"save_write_count",
	]:
		_expect(int(debug.get(field, -1)) == 0, "%dP %s is zero" % [player_count, field])
	_expect(bool(debug.get("player_adapter_connected", false)), "%dP player adapter is connected" % player_count)
	_expect(bool(debug.get("ai_adapter_connected", false)), "%dP AI adapter is connected" % player_count)
	_expect(int(debug.get("ai_v06_policy_fallback_count", -1)) == 0, "%dP has no V0.6 AI fallback" % player_count)
	_expect(int(debug.get("final_settlement_count", 0)) == 1, "%dP commits one settlement" % player_count)
	_expect(int(debug.get("final_settlement_presentation_count", 0)) == 1, "%dP presents one settlement" % player_count)
	_expect(int(debug.get("final_settlement_public_log_count", 0)) == 1, "%dP logs one settlement" % player_count)
	_expect(int(debug.get("duplicate_settlement_count", -1)) == 0, "%dP has no duplicate settlement" % player_count)
	_expect(bool(debug.get("solar_validation", false)), "%dP solar/victory state validates" % player_count)


func _test_ui_acceptance(acceptance: Dictionary, player_count: int) -> void:
	_expect(bool(acceptance.get("match_completed", false)), "%dP UI observes completion" % player_count)
	_expect(int(acceptance.get("player_count", 0)) == player_count, "%dP UI roster count is exact" % player_count)
	_expect(int(acceptance.get("initial_hand_count", 0)) == 5, "%dP UI shows a five-card hand" % player_count)
	_expect(not bool(acceptance.get("save_enabled", true)), "%dP UI keeps Save disabled" % player_count)
	_expect(not bool(acceptance.get("continue_enabled", true)), "%dP UI keeps Continue disabled" % player_count)
	_expect(bool(acceptance.get("single_unified_track", false)), "%dP UI has one unified track" % player_count)
	_expect(int(acceptance.get("right_permanent_panel_count", -1)) == 0, "%dP UI has no permanent right panel" % player_count)
	_expect(int(acceptance.get("outer_orbit_decoration_count", -1)) == 0, "%dP UI has no outer orbit decoration" % player_count)
	_expect(is_equal_approx(float(acceptance.get("planet_alpha", 0.0)), 1.0), "%dP planet is opaque" % player_count)
	_expect(bool(acceptance.get("backside_occluded", false)), "%dP planet backside is occluded" % player_count)
	_expect(int(acceptance.get("six_color_icon_coverage", 0)) == 6, "%dP UI has six asset icons" % player_count)
	_expect(int(acceptance.get("color_only_identification_count", -1)) == 0, "%dP UI never relies on color alone" % player_count)
	_expect(is_equal_approx(float(acceptance.get("normal_card_art_coverage", 0.0)), 1.0), "%dP normal card art coverage is complete" % player_count)
	_expect(is_equal_approx(float(acceptance.get("commodity_card_art_coverage", 0.0)), 1.0), "%dP commodity art coverage is complete" % player_count)
	_expect(bool(acceptance.get("special_action_visible", false)), "%dP special action is visible in Hand Dock" % player_count)
	_expect(not bool(acceptance.get("special_action_counts_toward_normal_limit", true)), "%dP special action does not consume normal hand limit" % player_count)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	var passed := _failures.is_empty()
	print("V073_PRODUCTION_SAMPLE_ACCEPTANCE|status=%s|checks=%d|failures=%d|players=%s|fizzles=%d|details=%s" % [
		"PASS" if passed else "FAIL",
		_checks,
		_failures.size(),
		JSON.stringify(_completed_counts),
		_fizzle_count,
		JSON.stringify(_failures),
	])
	quit(0 if passed else 1)
