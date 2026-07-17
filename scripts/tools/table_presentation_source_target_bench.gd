extends Node

const SCREENSHOT_PATH := "res://docs/ui_qa/table_presentation/table_presentation_production.png"

class PresentationLoopLifecyclePort extends RuntimeLifecyclePort:
	func is_ready() -> bool: return true
	func session_is_finished() -> bool: return false
	func session_is_paused() -> bool: return false
	func synchronize_forced_decisions() -> Dictionary: return {"synchronized": true}
	func blocks_global_time() -> bool: return true

class PresentationLoopMonsterPort extends RuntimeMonsterPort:
	func is_ready() -> bool: return true
	func tick_wagers(_delta_seconds: float) -> void: pass

class PresentationLoopCardPort extends RuntimeCardPort:
	func is_ready() -> bool: return true

class PresentationLoopEconomyPort extends RuntimeEconomyPort:
	func is_ready() -> bool: return true

class PresentationLoopActorPort extends RuntimeActorPort:
	func is_ready() -> bool: return true

class PresentationLoopVictoryPort extends RuntimeVictoryPort:
	func is_ready() -> bool: return true

class PresentationLoopPort extends RuntimePresentationPort:
	var coordinator: GameRuntimeCoordinator
	func is_ready() -> bool: return true
	func advance_visual_cues(_delta_seconds: float) -> Dictionary: return {}
	func advance_table_presentation(real_delta_seconds: float) -> Array[TablePresentationApplyReceipt]:
		return coordinator.advance_table_presentation(real_delta_seconds)

class PresentationLoopPorts extends RuntimeWorldPorts:
	func _init(coordinator: GameRuntimeCoordinator) -> void:
		lifecycle = PresentationLoopLifecyclePort.new()
		lifecycle.name = "RuntimeLifecyclePort"; add_child(lifecycle)
		card = PresentationLoopCardPort.new()
		card.name = "RuntimeCardPort"; add_child(card)
		economy = PresentationLoopEconomyPort.new()
		economy.name = "RuntimeEconomyPort"; add_child(economy)
		actors = PresentationLoopActorPort.new()
		actors.name = "RuntimeActorPort"; add_child(actors)
		monster = PresentationLoopMonsterPort.new()
		monster.name = "RuntimeMonsterPort"; add_child(monster)
		presentation = PresentationLoopPort.new()
		presentation.name = "RuntimePresentationPort"; add_child(presentation)
		(presentation as PresentationLoopPort).coordinator = coordinator
		victory = PresentationLoopVictoryPort.new()
		victory.name = "RuntimeVictoryPort"; add_child(victory)
	func is_ready() -> bool: return true

@export var auto_run := true

var checks := 0
var failures: Array[String] = []


func _ready() -> void:
	if auto_run:
		call_deferred("run_bench")


func run_bench() -> Dictionary:
	checks = 0
	failures.clear()
	var coordinator := get_node_or_null("GameRuntimeCoordinator") as GameRuntimeCoordinator
	var game_screen := get_node_or_null("GameScreen") as SpaceSyndicateGameScreen
	_check(coordinator != null, "production coordinator exists")
	_check(game_screen != null, "production GameScreen exists")
	if coordinator == null or game_screen == null:
		return _finish()
	var runtime_loop := coordinator.get_node_or_null("RuntimeLoop") as RuntimeLoop
	if runtime_loop != null:
		runtime_loop.set_process(false)
	_configure_presentation_dependencies(coordinator)
	var catalog := coordinator.card_runtime_catalog_service()
	var card_ids := catalog.ordered_card_ids()
	var card_id := str(card_ids[0]) if not card_ids.is_empty() else ""
	var skill := catalog.definition(card_id) if not card_id.is_empty() else {}
	coordinator.world_session_state().replace_players([
		{"name": "本地", "is_ai": false, "cash": 1250, "slots": [skill]},
		{"name": "AI", "is_ai": true, "cash": 987654, "slots": [{"name": "秘密手牌"}], "ai_plan": "SECRET_ROUTE"},
	], true)
	coordinator.world_session_state().replace_districts([
		{"region_id": "a", "name": "甲", "center": Vector2(80, 80), "city": {"owner": 0, "active": true, "level": 1}},
		{"region_id": "b", "name": "乙", "center": Vector2(240, 80), "city": {"owner": 1, "active": true, "level": 1}},
	], true)
	coordinator.world_session_state().configure_world_geometry(640.0, 360.0)
	coordinator.table_selection_state().restore({
		"selected_player": 0,
		"inspected_player": 0,
		"selected_district": 0,
		"selected_trade_product": "crystal",
		"selected_card_resolution_id": 61,
		"selected_hand_slot": 0,
		"selected_map_layer_focus": "route",
	})
	_configure_rack_and_track(coordinator, card_id, skill)
	await get_tree().process_frame

	var source := coordinator.get_node_or_null("TablePresentationSourceOwner") as TablePresentationSourceOwner
	var port := coordinator.get_node_or_null("TablePresentationRefreshPort") as TablePresentationRefreshPort
	var scheduler := coordinator.get_node_or_null("TablePresentationRefreshScheduler") as TablePresentationRefreshScheduler
	var developer_target := coordinator.get_node_or_null("DeveloperBalancePresentationTarget") as DeveloperBalancePresentationTarget
	_check(source != null and port != null and scheduler != null, "scene-owned source, port and cadence owner are composed")
	_check(developer_target != null, "developer-only target is composed")
	if source == null or port == null or scheduler == null or developer_target == null:
		return _finish()

	var live := coordinator.request_table_presentation_refresh(&"live", &"bench")
	_check(live.applied and live.kind == &"live", "live receipt applies exactly once")
	var map_receipt := coordinator.request_table_presentation_refresh(&"map", &"bench")
	_check(map_receipt.applied and map_receipt.kind == &"map", "map receipt applies exactly once")
	var full := coordinator.request_table_presentation_refresh(&"full", &"bench")
	_check(full.applied and full.kind == &"full", "full receipt applies exactly once")
	var before_developer: Dictionary = source.debug_snapshot()
	var disabled := coordinator.request_table_presentation_refresh(&"developer", &"bench_disabled")
	_check(not disabled.applied, "disabled developer target does not enter production refresh path")
	developer_target.enabled = true
	var release_gate := coordinator.request_table_presentation_refresh(&"developer", &"bench_env_disabled")
	_check(not release_gate.applied, "developer target requires the explicit environment gate")
	OS.set_environment(DeveloperBalancePresentationTarget.DEVELOPER_PRESENTATION_ENV, "1")
	var enabled := coordinator.request_table_presentation_refresh(&"developer", &"bench_enabled")
	_check(enabled.applied, "enabled developer target consumes only developer snapshot")
	OS.set_environment(DeveloperBalancePresentationTarget.DEVELOPER_PRESENTATION_ENV, "")
	var table := game_screen.current_ui_data
	var player_board: Dictionary = table.get("player_board", {}) if table.get("player_board", {}) is Dictionary else {}
	var hand_cards: Array = player_board.get("hand_cards", []) if player_board.get("hand_cards", []) is Array else []
	var right_inspector: Dictionary = table.get("right_inspector", {}) if table.get("right_inspector", {}) is Dictionary else {}
	_check(hand_cards.size() == 1 and str((hand_cards[0] as Dictionary).get("id", "")) == "hand_0", "production Bench renders the real CardPresentation hand")
	_check(not hand_cards.is_empty() and not ((hand_cards[0] as Dictionary).get("actions", []) as Array).is_empty(), "production Bench exposes the real play action")
	_check(not (player_board.get("quick_actions", []) as Array).is_empty(), "production Bench exposes rack, buy and play quick actions")
	_check(not (right_inspector.get("actions", []) as Array).is_empty(), "production Bench exposes selected card or district inspector actions")
	_check(not (table.get("card_track", []) as Array).is_empty(), "production Bench renders real history/current/next card-track content")

	var target_debug := game_screen.presentation_target_debug_snapshot()
	var planet_debug := game_screen.presentation_planet_target().map_presentation_target_debug_snapshot()
	var source_debug := source.debug_snapshot()
	var build_counts: Dictionary = source_debug.get("snapshot_build_count_by_kind", {})
	_check(int(target_debug.get("live_target_count", 0)) == 1, "live target apply count is one")
	_check(int(target_debug.get("full_target_count", 0)) == 1, "full target apply count is one")
	_check(int(planet_debug.get("apply_count", 0)) == 1, "map target apply count is one")
	_check(bool(planet_debug.get("fullscreen_target_bound", false)), "same map target binds embedded and fullscreen planet views")
	_check(int(build_counts.get("live", 0)) == 1, "live snapshot build count is one")
	_check(int(build_counts.get("map", 0)) == 1, "map snapshot build count is one")
	_check(int(build_counts.get("full", 0)) == 1, "full snapshot build count is one")
	_check(int(build_counts.get("developer", 0)) == int((before_developer.get("snapshot_build_count_by_kind", {}) as Dictionary).get("developer", 0)) + 3, "developer receipts do not build unrelated snapshots")
	var query_ports := coordinator.table_presentation_query_ports()
	var log_count_before := coordinator.presentation_recent_public_log_entries(16).size()
	var victory_receipt := query_ports.capture_victory_advance({"public_snapshot": {"state": "qualification", "victory_rule": {"required_region_count": 2}}})
	var victory_port_debug := port.debug_snapshot()
	var victory_apply_counts: Dictionary = victory_port_debug.get("apply_count_by_kind", {})
	_check(victory_receipt != null and victory_receipt.is_valid(), "victory change produces a visibility-safe typed receipt")
	_check(coordinator.presentation_recent_public_log_entries(16).size() == log_count_before + 1, "victory public log applies exactly once")
	_check(int(victory_apply_counts.get("live", 0)) == 2 and int(victory_apply_counts.get("full", 0)) == 2, "victory immediate refresh applies live then full exactly once")
	_check(not JSON.stringify(victory_receipt.to_dictionary()).contains("987654") and not JSON.stringify(victory_receipt.to_dictionary()).contains("秘密手牌"), "victory receipt contains no private player state")

	var duplicate_source_counts := (source.debug_snapshot().get("snapshot_build_count_by_kind", {}) as Dictionary).duplicate(true)
	var duplicate_receipt := scheduler.immediate_typed(&"live")
	var first_duplicate_candidate := port.apply_refresh_receipt(duplicate_receipt)
	var rejected_duplicate := port.apply_refresh_receipt(duplicate_receipt)
	_check(first_duplicate_candidate.applied, "fresh typed receipt applies")
	_check(not rejected_duplicate.applied and rejected_duplicate.reason_code == "presentation_receipt_duplicate", "duplicate typed receipt is rejected")
	_check(int((source.debug_snapshot().get("snapshot_build_count_by_kind", {}) as Dictionary).get("live", 0)) == int(duplicate_source_counts.get("live", 0)) + 1, "duplicate rejection does not rebuild snapshot")
	var stale := TablePresentationRefreshReceipt.new()
	stale.receipt_id = "bench-stale"
	stale.sequence = duplicate_receipt.sequence - 1
	stale.kind = &"map"
	stale.source_revision = duplicate_receipt.source_revision
	var stale_result := port.apply_refresh_receipt(stale)
	_check(not stale_result.applied and stale_result.reason_code == "presentation_receipt_stale", "stale typed receipt is rejected")
	var card_presentation_port := coordinator.get_node_or_null("CardResolutionPresentationPort") as CardResolutionPresentationPort
	_check(card_presentation_port != null, "typed card-resolution presentation port is composed")
	if card_presentation_port != null:
		card_presentation_port.publish_public_event({
			"event_id": "bench-card-visual",
			"event_kind": "card_aftermath",
			"resolution_id": 72,
			"card_name": card_id,
			"status": "resolved",
			"summary": "公开卡牌完成结算。",
			"district_index": 0,
		})
		var visual_apply := coordinator.request_table_presentation_refresh(&"live", &"bench_card_visual")
		var visual_layer_snapshot: Dictionary = game_screen.visual_event_layer.get_visual_event_snapshot() if game_screen.visual_event_layer != null else {}
		_check(visual_apply.applied and (visual_layer_snapshot.get("events", []) as Array).size() == 1, "public card visual reaches VisualEventLayer exactly once")
		coordinator.request_table_presentation_refresh(&"full", &"bench_card_visual_followup")
		var followup_visual_snapshot: Dictionary = game_screen.visual_event_layer.get_visual_event_snapshot() if game_screen.visual_event_layer != null else {}
		_check((followup_visual_snapshot.get("events", []) as Array).size() == 1, "follow-up refresh does not replay a consumed card visual")

	var own_json := JSON.stringify(coordinator.presentation_private_world_projection(0, 0).to_dictionary())
	var public_json := JSON.stringify(coordinator.presentation_public_world_projection().to_dictionary())
	var live_json := JSON.stringify(source.build_live_snapshot(scheduler.immediate_typed(&"live")).to_dictionary())
	var public_log_before_feedback := coordinator.presentation_recent_public_log_entries(32).size()
	var private_feedback := coordinator.record_legacy_viewer_feedback("资金不足：当前只有¥1250；私人目标已取消。")
	var full_with_feedback_json := JSON.stringify(source.build_full_snapshot(scheduler.immediate_typed(&"full")).to_dictionary())
	_check(own_json.contains("1250"), "current viewer private projection contains own legal cash")
	_check(not public_json.contains("987654") and not public_json.contains("秘密手牌") and not public_json.contains("SECRET_ROUTE"), "public source omits opponent private state")
	_check(not live_json.contains("987654") and not live_json.contains("秘密手牌") and not live_json.contains("SECRET_ROUTE"), "live snapshot omits opponent private state")
	_check(bool(private_feedback.get("applied", false)) and full_with_feedback_json.contains("私人目标已取消"), "legacy local feedback enters only the authorized viewer full snapshot")
	_check(coordinator.presentation_recent_public_log_entries(32).size() == public_log_before_feedback and not live_json.contains("私人目标已取消"), "viewer-private feedback never enters public or live presentation")
	var unauthorized_snapshot := source.build_live_snapshot(scheduler.immediate_typed(&"live"))
	unauthorized_snapshot.authorization_revision += 1
	var target_apply_before := int(game_screen.presentation_target_debug_snapshot().get("live_target_count", 0))
	game_screen.apply_live_presentation(unauthorized_snapshot)
	_check(int(game_screen.presentation_target_debug_snapshot().get("live_target_count", 0)) == target_apply_before, "GameScreen rejects a snapshot with the wrong authorization revision")
	var port_debug := port.debug_snapshot()
	_check(int(port_debug.get("duplicate_receipt_count", 0)) == 1, "duplicate diagnostic count is exact")
	_check(int(port_debug.get("stale_receipt_count", 0)) == 1, "stale diagnostic count is exact")
	_check(int(port_debug.get("main_fallback_count", -1)) == 0 and not bool(port_debug.get("references_main", true)), "refresh port has no Main fallback")
	_check(not bool(source_debug.get("owns_refresh_cadence", true)) and not bool(source_debug.get("owns_gameplay_state", true)), "source owns neither cadence nor gameplay state")
	_check(runtime_loop != null, "production RuntimeLoop is available for presentation regression")
	if runtime_loop != null:
		var loop_ports := PresentationLoopPorts.new(coordinator)
		var loop_phases := _bind_loop_to_phases(runtime_loop, loop_ports)
		scheduler.reset_table_cadence()
		scheduler.request_immediate(&"live")
		var loop_build_before := int((source.debug_snapshot().get("snapshot_build_count_by_kind", {}) as Dictionary).get("live", 0))
		var loop_apply_before := int(game_screen.presentation_target_debug_snapshot().get("live_target_count", 0))
		var loop_receipt := runtime_loop.advance_frame_for_test(0.0)
		_check(str(loop_receipt.get("path", "")) == "global_blocked", "RuntimeLoop uses the frozen global-block presentation path")
		_check(int((source.debug_snapshot().get("snapshot_build_count_by_kind", {}) as Dictionary).get("live", 0)) == loop_build_before + 1, "one RuntimeLoop cadence receipt builds one live snapshot")
		_check(int(game_screen.presentation_target_debug_snapshot().get("live_target_count", 0)) == loop_apply_before + 1, "one RuntimeLoop cadence receipt applies the live target once")
		loop_phases.queue_free()
		loop_ports.free()
	await get_tree().process_frame
	_check(_save_production_screenshot(), "production GameScreen screenshot is captured without a Main presentation path")
	return _finish()


func _bind_loop_to_phases(loop: RuntimeLoop, ports: RuntimeWorldPorts) -> RuntimePhaseCoordinator:
	var packed := load("res://scenes/runtime/RuntimePhaseCoordinator.tscn") as PackedScene
	var phases := packed.instantiate() as RuntimePhaseCoordinator
	phases.lifecycle = phases.get_node("RuntimeLifecyclePhaseCoordinator") as RuntimeLifecyclePhaseCoordinator
	phases.command = phases.get_node("RuntimeCommandPhaseCoordinator") as RuntimeCommandPhaseCoordinator
	phases.simulation = phases.get_node("RuntimeSimulationPhaseCoordinator") as RuntimeSimulationPhaseCoordinator
	phases.resolution = phases.get_node("RuntimeResolutionPhaseCoordinator") as RuntimeResolutionPhaseCoordinator
	phases.state_commit = phases.get_node("RuntimeStateCommitCoordinator") as RuntimeStateCommitCoordinator
	phases.presentation_schedule = phases.get_node("RuntimePresentationScheduleCoordinator") as RuntimePresentationScheduleCoordinator
	phases.bind_ports(ports)
	loop.add_child(phases)
	loop.bind_phase_coordinator(phases)
	return phases


func _configure_presentation_dependencies(coordinator: GameRuntimeCoordinator) -> void:
	var card_presentation := coordinator.get_node_or_null("CardPresentationRuntimeService") as CardPresentationRuntimeService
	var table_viewmodel := coordinator.get_node_or_null("GameTableViewModelRuntimeService") as GameTableViewModelRuntimeService
	var eligibility := coordinator.get_node_or_null("CardPlayEligibilityRuntimeService") as CardPlayEligibilityRuntimeService
	var queue := coordinator.get_node_or_null("CardResolutionQueueRuntimeService") as CardResolutionQueueRuntimeService
	var history := coordinator.get_node_or_null("CardResolutionHistoryRuntimeService") as CardResolutionHistoryRuntimeService
	var resolution := coordinator.get_node_or_null("CardResolutionRuntimeController") as CardResolutionRuntimeController
	if card_presentation != null:
		card_presentation.configure({})
	if table_viewmodel != null:
		table_viewmodel.configure(card_presentation)
	if eligibility != null:
		eligibility.configure({"ruleset_id": "v0.6"})
	if queue != null:
		queue.configure({"ruleset_id": "v0.6", "card_group": preload("res://resources/rules/space_syndicate_ruleset_v06.tres").card_group_rules()})
	if history != null:
		history.configure({"history_limit": 24})
	if resolution != null:
		resolution.configure(preload("res://resources/rules/space_syndicate_ruleset_v06.tres").card_group_rules())


func _configure_rack_and_track(coordinator: GameRuntimeCoordinator, card_id: String, skill: Dictionary) -> void:
	var supply := coordinator.get_node_or_null("RegionSupplyRuntimeController") as RegionSupplyRuntimeController
	if supply != null:
		supply.configure(991, [
			{"region_id": "a", "region_index": 0, "display_name": "甲", "terrain": "land"},
			{"region_id": "b", "region_index": 1, "display_name": "乙", "terrain": "land"},
		], [{
			"card_id": card_id, "family_id": str(skill.get("family_id", card_id)), "card_type": str(skill.get("kind", "ordinary")),
			"rank": 1, "name": card_id, "display_name": str(skill.get("display_name", card_id)), "price_cash": 120,
			"effect_text": str(skill.get("text", "发展区域")), "requirement_text": str(skill.get("play_requirement_text", "条件：当前选区")),
			"potential_target_exists": true,
		}], 1)
	var queue := coordinator.get_node_or_null("CardResolutionQueueRuntimeService") as CardResolutionQueueRuntimeService
	var history := coordinator.get_node_or_null("CardResolutionHistoryRuntimeService") as CardResolutionHistoryRuntimeService
	if queue != null:
		queue.replace_state({
			"current_queue": [_track_entry(62, card_id, skill)],
			"active_entry": _track_entry(63, card_id, skill),
			"next_queue": [_track_entry(64, card_id, skill)],
			"resolution_sequence": 64,
			"last_group_window_sequence": 1,
		})
	if history != null:
		history.append_resolved(_track_entry(61, card_id, skill).merged({"resolved": true, "resolution_outcome": "resolved"}, true))


func _track_entry(resolution_id: int, card_id: String, skill: Dictionary) -> Dictionary:
	return {
		"resolution_id": resolution_id, "queued_order": resolution_id, "player_index": 0, "slot_index": 0,
		"skill": skill.merged({"name": card_id}, true), "selected_district": 0,
		"group_id": "bench-group", "group_order": 1, "group_size": 1, "group_position": 1,
		"aftermath_clue": "公开区域状态变化",
	}


func _finish() -> Dictionary:
	var result := {"passed": failures.is_empty(), "checks": checks, "failures": failures.duplicate()}
	print("TablePresentationSourceTargetBench: %s %d/%d" % ["PASS" if failures.is_empty() else "FAIL", checks - failures.size(), checks])
	if not failures.is_empty():
		push_error("TablePresentationSourceTargetBench failures:\n- " + "\n- ".join(failures))
	return result


func _save_production_screenshot() -> bool:
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return false
	var absolute_path := ProjectSettings.globalize_path(SCREENSHOT_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	return image.save_png(absolute_path) == OK


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
