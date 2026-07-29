extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"
const CARD_PRESENTATION_SCENE := "res://scenes/runtime/CardPresentationRuntimeService.tscn"
const TABLE_VIEWMODEL_SCENE := "res://scenes/runtime/GameTableViewModelRuntimeService.tscn"
const TABLE_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/table_snapshot.gd")
const CURRENT_ACTION_CONTEXT := preload("res://scripts/presentation/current_action_context_projection_v1.gd")
const CONTEXT_DETAIL := preload("res://scripts/presentation/context_detail_projection_v1.gd")

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
		var overlay_badges_variant: Variant = table_viewmodel.call("compose_resolution_overlay_badges", {"entry":{"is_viewer_card":true, "winning_bid":40, "tip_paid":true}, "requirement_text":"条件：区域GDP份额≥10%", "current_queue_count":1})
		var overlay_badges: Array = overlay_badges_variant if overlay_badges_variant is Array else []
		_expect(not overlay_badges.is_empty() and _is_pure_data(overlay_badges) and str((overlay_badges[0] as Dictionary).get("text", "")) == "我的展示牌", "resolution-overlay badges are composed as privacy-safe ViewModel data")
	var test_bgm := main.get_node_or_null("RuntimeServices/TableAudioHost/NightPatrolTableBgm") as AudioStreamPlayer
	if test_bgm != null:
		test_bgm.stream = null
	main.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(main)
	await process_frame
	await process_frame
	var services := main.get_node_or_null("RuntimeServices")
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	var draft := services.get_node_or_null("NewGameSetupDraftService") as NewGameSetupDraftService \
		if services != null else null
	var transaction := services.get_node_or_null("SessionStartTransactionCoordinator") as SessionStartTransactionCoordinator \
		if services != null else null
	var session := coordinator.get_node_or_null("GameSessionRuntimeController") as GameSessionRuntimeController \
		if coordinator != null else null
	_expect(draft != null and transaction != null and session != null, "atomic session-start composition is available")
	if draft != null and transaction != null and session != null:
		draft.reset_to_defaults()
		var request := SessionStartRequest.create(
			"card-presentation-viewmodel-runtime",
			draft.draft_snapshot(),
			session.session_start_revision(),
			"focused_test"
		)
		var start_receipt := transaction.start_session(request)
		_expect(start_receipt != null and start_receipt.applied, "real first-run table starts through the atomic session transaction")
	await process_frame
	var runtime_screen := main.get_node_or_null("RuntimeGameScreen") as Control
	_expect(runtime_screen != null and runtime_screen.has_method("apply_state"), "current RuntimeGameScreen public presentation surface exists")
	var current_ui_data: Dictionary = {}
	if runtime_screen != null:
		var current_variant: Variant = runtime_screen.get("current_ui_data")
		current_ui_data = (current_variant as Dictionary).duplicate(true) if current_variant is Dictionary else {}
	var snapshot: Dictionary = TABLE_SNAPSHOT_SCRIPT.new().apply_dictionary(current_ui_data).to_ui_dictionary()
	_expect(not snapshot.is_empty() and _is_pure_data(snapshot), "runtime table snapshot is non-empty pure data")
	var player_card_dock: Dictionary = snapshot.get("player_card_dock", {}) \
		if snapshot.get("player_card_dock", {}) is Dictionary else {}
	var normal_cards: Array = player_card_dock.get("normal_cards", []) \
		if player_card_dock.get("normal_cards", []) is Array else []
	_expect(not normal_cards.is_empty(), "real first-run normal hand is composed into the typed Player Card Dock")
	if not normal_cards.is_empty() and normal_cards[0] is Dictionary:
		var first_card := normal_cards[0] as Dictionary
		_expect(first_card.has("slot_id") and first_card.has("play_state") \
			and first_card.has("disabled_reason_text"), "normal card includes typed slot, presentation legality, and readable failure fields")
		var offer: Dictionary = first_card.get("game_action_offer", {}) \
			if first_card.get("game_action_offer", {}) is Dictionary else {}
		_expect(bool(GameActionOfferV1.validation_report(offer).get("valid", false)) \
			and str(offer.get("semantic_action_id", "")) == GameActionIntentV1.ACTION_CARD_PLAY, "normal card preserves the formal Action Spine offer")
	var current_action: Dictionary = snapshot.get("current_action_context", {}) \
		if snapshot.get("current_action_context", {}) is Dictionary else {}
	var context_detail: Dictionary = snapshot.get("context_detail", {}) \
		if snapshot.get("context_detail", {}) is Dictionary else {}
	_expect(snapshot.has("current_action_context") \
		and (current_action.is_empty() or bool(CURRENT_ACTION_CONTEXT.validation_report(current_action).get("valid", false))) \
		and not JSON.stringify(current_action.get("game_action_offers", [])).contains(GameActionIntentV1.ACTION_CARD_PLAY), "typed current-action context fails closed and cannot duplicate Dock card play")
	_expect(snapshot.has("context_detail") \
		and (context_detail.is_empty() or bool(CONTEXT_DETAIL.validation_report(context_detail).get("valid", false))) \
		and not context_detail.has("actions") and _is_pure_data(context_detail), "typed context detail is read-only and fails closed without a selected object")
	var card_track: Array = snapshot.get("card_track", []) if snapshot.get("card_track", []) is Array else []
	_expect(_is_pure_data(card_track) and not _contains_forbidden_key(card_track), "public card track remains pure and privacy-safe")
	var source := FileAccess.get_file_as_string("res://scripts/main.gd")
	for retired_name in ["_card_theme_color", "_card_use_case_text_for_skill", "_card_rule_facts", "_runtime_hand_card_snapshots", "_runtime_card_track_snapshot_source", "_card_resolution_animation_text", "_card_resolution_target_text", "_card_resolution_effect_style"]:
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
		print("CARD_PRESENTATION_VIEWMODEL_RUNTIME_TEST|status=PASS|failures=0")
		quit(0)
		return
	print("CARD_PRESENTATION_VIEWMODEL_RUNTIME_TEST|status=FAIL|failures=%d" % failures.size())
	quit(1)
