extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"

var _player_count := 4
var _show_region_popup := false
var _output_path := "res://reports/ui/v073_sample_dev/production-capture.png"
var _capture_size := Vector2i(1600, 960)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_parse_arguments()
	print("V073_PRODUCTION_VISUAL_CAPTURE|stage=arguments_parsed|players=%d|width=%d|height=%d" % [
		_player_count,
		_capture_size.x,
		_capture_size.y,
	])
	root.content_scale_size = _capture_size
	root.size = _capture_size
	print("V073_PRODUCTION_VISUAL_CAPTURE|stage=main_load_started")
	var packed := load(MAIN_SCENE) as PackedScene
	print("V073_PRODUCTION_VISUAL_CAPTURE|stage=main_load_completed")
	if packed == null:
		_fail("main_scene_load_failed")
		return
	var application := packed.instantiate()
	print("V073_PRODUCTION_VISUAL_CAPTURE|stage=main_instantiated")
	root.add_child(application)
	print("V073_PRODUCTION_VISUAL_CAPTURE|stage=main_added")
	for _frame in range(4):
		await process_frame
	print("V073_PRODUCTION_VISUAL_CAPTURE|stage=warmup_completed")
	var flow := application.get_node_or_null("V073RuntimeComposition")
	var screen := application.get_node_or_null("V073SampleGameScreen")
	if flow == null or screen == null:
		_fail("production_composition_missing")
		return
	var intent := flow.call("issue_intent", "new_game.start", {
		"player_count": _player_count,
		"seed": 730045 + _player_count,
	}) as Dictionary
	var receipt := flow.call("submit_intent", intent) as Dictionary
	if not bool(receipt.get("accepted", false)):
		_fail("new_game_start_rejected")
		return
	print("V073_PRODUCTION_VISUAL_CAPTURE|stage=new_game_started")
	for _frame in range(8):
		await process_frame
	print("V073_PRODUCTION_VISUAL_CAPTURE|stage=production_frames_completed")
	if _show_region_popup:
		screen.call("_show_region_popup", "region.alpha")
		for _frame in range(3):
			await process_frame
		print("V073_PRODUCTION_VISUAL_CAPTURE|stage=popup_presented")
	await RenderingServer.frame_post_draw
	print("V073_PRODUCTION_VISUAL_CAPTURE|stage=frame_drawn")
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("viewport_image_empty")
		return
	var source_size := image.get_size()
	if source_size != _capture_size:
		image.resize(
			_capture_size.x,
			_capture_size.y,
			Image.INTERPOLATE_LANCZOS
		)
	var absolute_path := ProjectSettings.globalize_path(_output_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var save_error := image.save_png(absolute_path)
	if save_error != OK:
		_fail("image_save_failed_%d" % save_error)
		return
	var acceptance := screen.get("acceptance_state") as Dictionary
	print("V073_PRODUCTION_VISUAL_CAPTURE|status=PASS|players=%d|width=%d|height=%d|source_width=%d|source_height=%d|popup=%s|runtime_frames=%d|output=%s" % [
		_player_count,
		image.get_width(),
		image.get_height(),
		source_size.x,
		source_size.y,
		str(_show_region_popup).to_lower(),
		int(acceptance.get("runtime_frames", 0)),
		_output_path,
	])
	application.queue_free()
	await process_frame
	quit(0)


func _parse_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--players="):
			_player_count = clampi(int(argument.trim_prefix("--players=")), 3, 8)
		elif argument.begins_with("--popup="):
			_show_region_popup = argument.trim_prefix("--popup=").to_lower() == "true"
		elif argument.begins_with("--output="):
			_output_path = argument.trim_prefix("--output=")
		elif argument.begins_with("--width="):
			_capture_size.x = maxi(640, int(argument.trim_prefix("--width=")))
		elif argument.begins_with("--height="):
			_capture_size.y = maxi(480, int(argument.trim_prefix("--height=")))


func _fail(reason_code: String) -> void:
	push_error("V073_PRODUCTION_VISUAL_CAPTURE|status=FAIL|reason=%s" % reason_code)
	quit(1)
