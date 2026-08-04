extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"
const CAPTURE_SIZE := Vector2i(1366, 768)
const OUTPUT_PATH := (
	"res://reports/ui/v073_human_playtest/1366x768_questionnaire.png"
)

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.content_scale_size = CAPTURE_SIZE
	root.size = CAPTURE_SIZE
	var packed := load(MAIN_SCENE) as PackedScene
	if packed == null:
		_fail("main_scene_load_failed")
		return
	var application := packed.instantiate()
	root.add_child(application)
	for _frame in range(4):
		await process_frame
	var flow := application.get_node_or_null("V073RuntimeComposition")
	var screen := application.get_node_or_null("V073SampleGameScreen")
	if flow == null or screen == null:
		_fail("production_composition_missing")
		return
	var start_intent := flow.call(
		"issue_intent",
		"new_game.start",
		{"player_count": 4, "seed": 900626424}
	) as Dictionary
	var started := flow.call("submit_intent", start_intent) as Dictionary
	if not bool(started.get("accepted", false)):
		_fail("new_game_start_rejected")
		return
	var accelerate_intent := flow.call(
		"issue_intent",
		"sample.accelerate",
		{"max_steps": 2000}
	) as Dictionary
	var completed := flow.call(
		"submit_intent",
		accelerate_intent
	) as Dictionary
	if not bool(completed.get("accepted", false)):
		_fail("sanity_match_not_settled")
		return
	for _frame in range(3):
		await process_frame
	var acceptance := screen.get("acceptance_state") as Dictionary
	if int(acceptance.get("final_settlement_count", 0)) != 1:
		_fail("final_settlement_count_not_one")
		return
	var close_button := screen.find_child(
		"SettlementClose", true, false
	) as Button
	if close_button == null:
		_fail("settlement_close_missing")
		return
	close_button.pressed.emit()
	for _frame in range(4):
		await process_frame
	var questionnaire := screen.get_node_or_null(
		"V073PlaytestQuestionnaire"
	)
	var questionnaire_root := screen.find_child(
		"QuestionnaireRoot", true, false
	) as Control
	var scroll := screen.find_child(
		"QuestionScroll", true, false
	) as ScrollContainer
	var submit := screen.find_child(
		"QuestionnaireSubmit", true, false
	) as Button
	var skip := screen.find_child(
		"QuestionnaireSkip", true, false
	) as Button
	if questionnaire == null or questionnaire_root == null or not questionnaire_root.visible:
		_fail("questionnaire_not_visible")
		return
	if scroll == null or submit == null or skip == null:
		_fail("questionnaire_controls_missing")
		return
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(CAPTURE_SIZE))
	if not viewport_rect.encloses(submit.get_global_rect()) or not viewport_rect.encloses(skip.get_global_rect()):
		_fail("questionnaire_footer_out_of_bounds")
		return
	var scrollbar := scroll.get_v_scroll_bar()
	if scrollbar == null or scrollbar.max_value <= scrollbar.page:
		_fail("questionnaire_not_scrollable")
		return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("viewport_image_empty")
		return
	if image.get_size() != CAPTURE_SIZE:
		image.resize(
			CAPTURE_SIZE.x,
			CAPTURE_SIZE.y,
			Image.INTERPOLATE_LANCZOS
		)
	var absolute_path := ProjectSettings.globalize_path(OUTPUT_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var save_error := image.save_png(absolute_path)
	if save_error != OK:
		_fail("image_save_failed_%d" % save_error)
		return
	print(
		"V073_PLAYTEST_QUESTIONNAIRE_CAPTURE|status=PASS|width=%d|height=%d|scroll_max=%.1f|scroll_page=%.1f|final_settlement_count=1|output=%s"
		% [
			CAPTURE_SIZE.x,
			CAPTURE_SIZE.y,
			scrollbar.max_value,
			scrollbar.page,
			OUTPUT_PATH,
		]
	)
	application.queue_free()
	await process_frame
	quit(0)


func _fail(reason_code: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(
		"V073_PLAYTEST_QUESTIONNAIRE_CAPTURE|status=FAIL|reason=%s"
		% reason_code
	)
	quit(1)
