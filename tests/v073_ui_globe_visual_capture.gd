extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"

var _player_count := 4
var _seed := 900626424
var _state := "base"
var _output_path := "res://reports/ui/v073c1/after/production-base.png"
var _capture_size := Vector2i(1600, 960)
var _freeze_time := false
var _previous_time_scale := 1.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_parse_arguments()
	_previous_time_scale = Engine.time_scale
	if _freeze_time:
		Engine.time_scale = 0.0
	root.content_scale_size = _capture_size
	root.size = _capture_size
	var packed := load(MAIN_SCENE) as PackedScene
	if packed == null:
		_fail("main_scene_load_failed")
		return
	var application := packed.instantiate()
	root.add_child(application)
	for _frame in range(4):
		await process_frame
	var flow := application.get_node_or_null("V073RuntimeComposition")
	var screen := application.get_node_or_null("V073SampleGameScreen") as Control
	if flow == null or screen == null:
		_fail("production_composition_missing")
		return
	var intent := flow.call("issue_intent", "new_game.start", {
		"player_count": _player_count,
		"seed": _seed,
	}) as Dictionary
	var receipt := flow.call("submit_intent", intent) as Dictionary
	if not bool(receipt.get("accepted", false)):
		_fail("new_game_start_rejected")
		return
	screen.call("apply_snapshot", flow.call("local_snapshot") as Dictionary)
	for _frame in range(6):
		await process_frame
	await _prepare_state(flow, screen)
	for _frame in range(8):
		await process_frame
	screen.call("_update_acceptance_state")
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("viewport_image_empty")
		return
	if image.get_size() != _capture_size:
		image.resize(_capture_size.x, _capture_size.y, Image.INTERPOLATE_LANCZOS)
	var absolute_path := ProjectSettings.globalize_path(_output_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if image.save_png(absolute_path) != OK:
		_fail("image_save_failed")
		return
	var acceptance := screen.get("acceptance_state") as Dictionary
	print("V073_UI_GLOBE_VISUAL_CAPTURE|status=PASS|state=%s|players=%d|seed=%d|width=%d|height=%d|regions=%d|major_overlap=%d|interactive_occlusion=%d|output=%s" % [
		_state,
		_player_count,
		_seed,
		_capture_size.x,
		_capture_size.y,
		int(acceptance.get("procedural_region_count", 0)),
		int(acceptance.get("unintended_major_panel_intersection_count", -1)),
		int(acceptance.get("interactive_control_occlusion_count", -1)),
		_output_path,
	])
	Engine.time_scale = _previous_time_scale
	application.queue_free()
	await process_frame
	quit(0)


func _prepare_state(flow: Node, screen: Control) -> void:
	var coach := screen.get_node_or_null("V073PlaytestCoachMarks")
	var marker := screen.find_child("V073PlaytestMarkerPanel", true, false)
	if _state != "coach" and coach != null:
		coach.call("_skip_all")
		screen.call("_refresh_playtest_context")
	if marker != null:
		marker.call("set_temporarily_hidden", true)
	match _state:
		"selected":
			_select_first_card(flow, screen)
		"rotation":
			_rotate_map(screen)
		"zoom":
			_zoom_map(screen, 5)
		"focus":
			_focus_first_visible_region(screen)
		"popup":
			screen.call("_on_planet_district_selected", 0)
		"marker":
			if marker != null:
				marker.call("set_temporarily_hidden", false)
				var reopen := marker.find_child("MarkerReopen", true, false) as Button
				if reopen != null:
					reopen.pressed.emit()
		"marker_collapsed":
			if marker != null:
				marker.call("set_temporarily_hidden", false)
		"queue5":
			await _queue_five_actions(flow, screen)
		"facilities":
			var accelerate := flow.call("issue_intent", "sample.accelerate", {"max_steps": 2000}) as Dictionary
			flow.call("submit_intent", accelerate)
			screen.call("apply_snapshot", flow.call("local_snapshot") as Dictionary)
			_hide_terminal_overlays(screen)
		"hover":
			var cards := screen.find_children("*", "V073SampleCardButton", true, false)
			if not cards.is_empty():
				(cards[0] as Control).notification(Control.NOTIFICATION_MOUSE_ENTER)
		"coach":
			pass
		_:
			pass


func _select_first_card(flow: Node, screen: Control) -> bool:
	var snapshot := flow.call("local_snapshot") as Dictionary
	var hand := (((snapshot.get("personal_dbg", {}) as Dictionary).get("facts", {}) as Dictionary).get("hand", []) as Array)
	if hand.is_empty():
		return false
	screen.call("_on_hand_card_activated", hand[0] as Dictionary)
	return true


func _queue_five_actions(flow: Node, screen: Control) -> void:
	var queued_ids := {}
	for _slot in range(5):
		var snapshot := flow.call("local_snapshot") as Dictionary
		var hand := (((snapshot.get("personal_dbg", {}) as Dictionary).get("facts", {}) as Dictionary).get("hand", []) as Array)
		var selected: Dictionary = {}
		var target_region := ""
		for card_variant in hand:
			var card := card_variant as Dictionary
			var card_id := str(card.get("instance_id", ""))
			if queued_ids.has(card_id):
				continue
			for option_variant in snapshot.get("legal_actions", []) as Array:
				var option := option_variant as Dictionary
				if str(option.get("card_instance_id", "")) == card_id:
					selected = card
					target_region = str(option.get("target_region_id", ""))
					break
			if not selected.is_empty():
				break
		if selected.is_empty():
			return
		queued_ids[str(selected.get("instance_id", ""))] = true
		screen.call("_on_hand_card_activated", selected)
		var region_index := _region_index(target_region)
		if region_index < 0:
			return
		screen.call("_on_planet_district_selected", region_index)
		for _frame in range(2):
			await process_frame


func _rotate_map(screen: Control) -> void:
	var map := _embedded_map(screen)
	if map == null:
		return
	var start := Vector2(map.size.x * 0.46, map.size.y * 0.54)
	var finish := start + Vector2(map.size.x * 0.16, -map.size.y * 0.08)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = start
	press.global_position = start
	press.pressed = true
	map.call("_gui_input", press)
	var motion := InputEventMouseMotion.new()
	motion.position = finish
	motion.global_position = finish
	motion.relative = finish - start
	motion.screen_relative = motion.relative
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	map.call("_gui_input", motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = finish
	release.global_position = finish
	release.pressed = false
	map.call("_gui_input", release)


func _zoom_map(screen: Control, steps: int) -> void:
	var map := _embedded_map(screen)
	if map == null:
		return
	for _index in range(steps):
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_WHEEL_UP
		event.position = map.size * 0.5
		event.global_position = event.position
		event.pressed = true
		map.call("_gui_input", event)


func _focus_first_visible_region(screen: Control) -> void:
	var map := _embedded_map(screen)
	if map == null:
		return
	for index in range(6):
		var position := map.call("get_district_control_position", index) as Vector2
		if position.x >= 0.0:
			map.call("focus_district", index, false)
			return


func _embedded_map(screen: Control) -> Control:
	var board := screen.find_child("PlanetBoard", true, false)
	if board == null:
		return null
	return board.call("get_embedded_map_view") as Control


func _hide_terminal_overlays(screen: Control) -> void:
	var settlement := screen.find_child("SettlementOverlay", true, false) as Control
	if settlement != null:
		settlement.visible = false
	var questionnaire := screen.get_node_or_null("V073PlaytestQuestionnaire")
	if questionnaire != null:
		var root_control := questionnaire.get_node_or_null("QuestionnaireRoot") as Control
		if root_control != null:
			root_control.visible = false


func _region_index(region_id: String) -> int:
	return [
		"region.alpha",
		"region.beta",
		"region.gamma",
		"region.delta",
		"region.epsilon",
		"region.zeta",
	].find(region_id)


func _parse_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--players="):
			_player_count = clampi(int(argument.trim_prefix("--players=")), 3, 8)
		elif argument.begins_with("--seed="):
			_seed = int(argument.trim_prefix("--seed="))
		elif argument.begins_with("--state="):
			_state = argument.trim_prefix("--state=")
		elif argument.begins_with("--output="):
			_output_path = argument.trim_prefix("--output=")
		elif argument.begins_with("--width="):
			_capture_size.x = maxi(640, int(argument.trim_prefix("--width=")))
		elif argument.begins_with("--height="):
			_capture_size.y = maxi(480, int(argument.trim_prefix("--height=")))
		elif argument == "--freeze-time":
			_freeze_time = true


func _fail(reason: String) -> void:
	push_error("V073_UI_GLOBE_VISUAL_CAPTURE|status=FAIL|reason=%s" % reason)
	quit(1)
