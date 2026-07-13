extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"
const CARD_PRESENTATION_SCENE := "res://scenes/runtime/CardPresentationRuntimeService.tscn"
const TABLE_VIEWMODEL_SCENE := "res://scenes/runtime/GameTableViewModelRuntimeService.tscn"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(MAIN_SCENE) as PackedScene
	_expect(packed != null, "main scene loads")
	var main := packed.instantiate() as Control if packed != null else null
	_expect(main != null, "main scene instantiates")
	if main == null:
		_finish()
		return
	var presentation := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardPresentationRuntimeService")
	var table_viewmodel := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameTableViewModelRuntimeService")
	_expect(presentation != null and presentation.scene_file_path == CARD_PRESENTATION_SCENE, "CardPresentationRuntimeService is statically composed")
	_expect(table_viewmodel != null and table_viewmodel.scene_file_path == TABLE_VIEWMODEL_SCENE, "GameTableViewModelRuntimeService is statically composed")
	_expect(presentation != null and presentation.has_method("compose_card") and presentation.has_method("compose_hand_card") and presentation.has_method("compose_resolution"), "card presentation service exposes its public API")
	if presentation != null:
		var resolution_variant: Variant = presentation.call("compose_resolution", {
			"card": {"card_name": "城市融资1", "display_name": "城市融资I", "skill": {"name": "城市融资1", "kind": "city_revenue_boost"}},
			"seconds_left": 1.0,
			"display_duration": 3.0,
			"resolved": true,
			"target_facts": {"district_name": "测试区域"},
		})
		var resolution: Dictionary = resolution_variant if resolution_variant is Dictionary else {}
		var presentation_debug: Dictionary = presentation.call("debug_snapshot")
		_expect(_is_pure_data(resolution) and str(resolution.get("animation_text", "")) != "" and str(resolution.get("target_text", "")).contains("测试区域"), "resolution cinematic presentation is composed as pure ViewModel data")
		_expect(bool(presentation_debug.get("owns_resolution_presentation", false)), "card presentation service declares resolution presentation ownership")
	_expect(table_viewmodel != null and table_viewmodel.has_method("compose_table") and table_viewmodel.has_method("compose_card_surfaces") and table_viewmodel.has_method("compose_resolution_overlay_badges"), "table ViewModel service exposes its public API")
	if table_viewmodel != null:
		var overlay_badges_variant: Variant = table_viewmodel.call("compose_resolution_overlay_badges", {"entry":{"is_viewer_card":true, "winning_bid":40, "tip_paid":true}, "requirement_text":"条件：区域GDP份额≥10%", "is_contract":true, "contract_state":"pending", "current_queue_count":1})
		var overlay_badges: Array = overlay_badges_variant if overlay_badges_variant is Array else []
		_expect(not overlay_badges.is_empty() and _is_pure_data(overlay_badges) and str((overlay_badges[0] as Dictionary).get("text", "")) == "我的展示牌", "resolution-overlay badges are composed as privacy-safe ViewModel data")
	var test_bgm := main.get_node_or_null("RuntimeServices/TableAudioHost/NightPatrolTableBgm") as AudioStreamPlayer
	if test_bgm != null:
		test_bgm.stream = null
	main.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(main)
	await process_frame
	await process_frame
	main.set("configured_player_count", 4)
	main.set("configured_ai_player_count", 3)
	main.call("_new_game")
	await process_frame
	var snapshot_variant: Variant = main.call("_runtime_table_snapshot")
	var snapshot: Dictionary = snapshot_variant if snapshot_variant is Dictionary else {}
	_expect(not snapshot.is_empty() and _is_pure_data(snapshot), "runtime table snapshot is non-empty pure data")
	var player_board: Dictionary = snapshot.get("player_board", {}) if snapshot.get("player_board", {}) is Dictionary else {}
	var hand_cards: Array = player_board.get("hand_cards", []) if player_board.get("hand_cards", []) is Array else []
	_expect(not hand_cards.is_empty(), "real first-run hand is composed by the service")
	if not hand_cards.is_empty() and hand_cards[0] is Dictionary:
		var first_card := hand_cards[0] as Dictionary
		_expect(first_card.has("use_case") and first_card.has("play_state") and first_card.has("drop_label"), "hand card includes presentation and play-state fields")
		var actions: Array = first_card.get("actions", []) if first_card.get("actions", []) is Array else []
		_expect(_has_action_prefix(actions, "play_"), "hand card preserves the existing play_<slot> action id")
	var inspector: Dictionary = snapshot.get("right_inspector", {}) if snapshot.get("right_inspector", {}) is Dictionary else {}
	var deep_links: Array = inspector.get("deep_links", []) if inspector.get("deep_links", []) is Array else []
	_expect(_has_action_id(deep_links, "detail_region") and _has_action_id(deep_links, "detail_cards"), "RightInspector fallback precedence and deep links remain compatible")
	var card_track: Array = snapshot.get("card_track", []) if snapshot.get("card_track", []) is Array else []
	_expect(_is_pure_data(card_track) and not _contains_forbidden_key(card_track), "public card track remains pure and privacy-safe")
	var source := FileAccess.get_file_as_string("res://scripts/main.gd")
	for retired_name in ["_card_theme_color", "_card_use_case_text_for_skill", "_card_rule_facts", "_runtime_hand_card_snapshots", "_runtime_card_track_snapshot_source", "_runtime_right_inspector_snapshot_source", "_card_resolution_animation_text", "_card_resolution_target_text", "_card_resolution_effect_style"]:
		_expect(not source.contains("func %s(" % retired_name), "%s remains deleted from main.gd" % retired_name)
	_expect(not source.contains("TableSnapshotScript"), "main.gd no longer owns TableSnapshot normalization")
	var audio_players: Array[AudioStreamPlayer] = []
	for player_variant in main.find_children("*", "AudioStreamPlayer", true, false):
		var player := player_variant as AudioStreamPlayer
		if player != null:
			player.stop()
			audio_players.append(player)
	await create_timer(0.2).timeout
	for player in audio_players:
		if is_instance_valid(player):
			player.stream = null
			player.free()
	main.set("table_bgm_player", null)
	main.set("table_sfx_players", {})
	main.queue_free()
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	packed = null
	_finish()


func _has_action_id(actions: Array, action_id: String) -> bool:
	for action_variant in actions:
		if action_variant is Dictionary and str((action_variant as Dictionary).get("id", "")) == action_id:
			return true
	return false


func _has_action_prefix(actions: Array, prefix: String) -> bool:
	for action_variant in actions:
		if action_variant is Dictionary and str((action_variant as Dictionary).get("id", "")).begins_with(prefix):
			return true
	return false


func _contains_forbidden_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant in value.keys():
			if str(key_variant) in ["hidden_owner", "owner_player_index", "private_hand", "private_discard", "private_target", "ai_private_plan"]:
				return true
			if _contains_forbidden_key(value[key_variant]):
				return true
	elif value is Array:
		for item in value:
			if _contains_forbidden_key(item):
				return true
	return false


func _is_pure_data(value: Variant) -> bool:
	if value is Callable or typeof(value) == TYPE_OBJECT:
		return false
	if value is Dictionary:
		for key_variant in value.keys():
			if not _is_pure_data(key_variant) or not _is_pure_data(value[key_variant]):
				return false
	elif value is Array:
		for item in value:
			if not _is_pure_data(item):
				return false
	return true


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("CARD PRESENTATION VIEWMODEL: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("CARD PRESENTATION VIEWMODEL PASS")
		quit(0)
		return
	print("CARD PRESENTATION VIEWMODEL FAIL: %d" % failures.size())
	quit(1)
