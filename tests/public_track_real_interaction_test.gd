extends SceneTree

const GAME_SCREEN_SCENE := preload("res://scenes/ui/GameScreen.tscn")
const INTEL_DOSSIER_SCENE := preload("res://scenes/ui/IntelDossierBoard.tscn")
const RESOLUTION_ID := 515151
const PRIVATE_SENTINEL := "hidden_owner::PRIVATE_TRACK_SENTINEL"
const CAPTURE_DIR := "user://public_track_real_interaction"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var screen := GAME_SCREEN_SCENE.instantiate() as Control
	_expect(screen != null, "real GameScreen instantiates for PublicTrack interaction")
	if screen == null:
		_finish()
		return
	root.add_child(screen)
	await _wait_frames(4)

	# A stale private hand focus must not win after the public track is clicked.
	screen.call("_on_card_selected", {
		"name": PRIVATE_SENTINEL,
		"effect": PRIVATE_SENTINEL,
		"cash": PRIVATE_SENTINEL,
		"hand": [PRIVATE_SENTINEL],
	})
	screen.call("apply_state", _table_state(false, "queue_alias_%d" % RESOLUTION_ID, "候补"))
	await _wait_frames(4)

	var public_track := screen.find_child("PublicTrack", true, false) as Control
	var slot := screen.find_child("PublicTrackSlot", true, false) as Control
	var slot_label := screen.find_child("PublicTrackSlotLabel", true, false) as Control
	var inspector := screen.find_child("RightInspector", true, false) as Control
	_expect(public_track != null and slot != null and slot_label != null, "real PublicTrack renders a clickable scene slot")
	_expect(inspector != null, "real GameScreen keeps the RightInspector mounted")
	if public_track == null or slot == null or slot_label == null or inspector == null:
		_dispose(screen)
		_finish()
		return

	var selected_entries: Array[Dictionary] = []
	var action_ids: Array[String] = []
	public_track.connect("track_entry_selected", func(entry: Dictionary) -> void:
		selected_entries.append(entry.duplicate(true))
	)
	screen.connect("action_requested", func(action_id: String) -> void:
		action_ids.append(action_id)
	)

	_expect(slot.mouse_filter == Control.MOUSE_FILTER_STOP, "PublicTrack slot root owns pointer input")
	_expect(_all_control_descendants_ignore_mouse(slot), "PublicTrack slot labels and decoration do not intercept real clicks")
	await _click_control(slot_label)
	await _wait_frames(3)
	var real_click_selected := selected_entries.size() == 1
	_expect(real_click_selected, "real viewport click on PublicTrack label selects its slot")

	var select_action_id := "track_select_%d" % RESOLUTION_ID
	var intel_action_id := "track_intel_%d" % RESOLUTION_ID
	_expect(action_ids.count(select_action_id) == 1, "PublicTrack selection emits one derived track_select action through GameScreen")
	_expect(
		not selected_entries.is_empty()
		and int(selected_entries[0].get("resolution_id", -1)) == RESOLUTION_ID
		and _entry_is_public(selected_entries[0]),
		"PublicTrack selection signal preserves the public resolution_id and recursively excludes private fields"
	)
	var inspector_text := _node_tree_text(inspector)
	var initial_inspector_resolution_id := -1
	if inspector.has_method("focused_track_resolution_id"):
		initial_inspector_resolution_id = int(inspector.call("focused_track_resolution_id"))
	_expect(initial_inspector_resolution_id == RESOLUTION_ID, "clicked PublicTrack entry focuses the same resolution_id in RightInspector")
	_expect(
		inspector_text.contains("牌轨详情")
		and inspector_text.contains("选中竞猜")
		and inspector_text.contains("线索档案")
		and inspector_text.contains("卡牌详情"),
		"clicked PublicTrack entry exposes selected detail, guess, dossier, and card-detail actions"
	)
	_expect(not inspector_text.contains(PRIVATE_SENTINEL), "RightInspector never renders private hand or hidden owner sentinels")

	# The authoritative entry may move lanes and change its UI id; resolution_id is stable.
	screen.call("apply_state", _table_state(true, "active_alias_%d" % RESOLUTION_ID, "当前展示"))
	await _wait_frames(4)
	inspector = screen.find_child("RightInspector", true, false) as Control
	inspector_text = _node_tree_text(inspector)
	var focused_resolution_id := -1
	if inspector != null and inspector.has_method("focused_track_resolution_id"):
		focused_resolution_id = int(inspector.call("focused_track_resolution_id"))
	_expect(focused_resolution_id == RESOLUTION_ID, "same resolution_id restores selected RightInspector focus after resync")
	_expect(
		inspector_text.contains("牌轨详情") and inspector_text.contains("线索档案"),
		"same resolution_id retains selected detail and dossier affordance after resync"
	)
	_expect(not inspector_text.contains(PRIVATE_SENTINEL), "resynced RightInspector keeps nested private track values out of public text")
	var selected_marker := screen.find_child("PublicTrackSlotSelected", true, false) as Control
	_expect(selected_marker != null and selected_marker.visible, "same resolution_id keeps the PublicTrack selected marker visible")
	var dossier_button := _find_visible_button(inspector, "线索档案")
	_expect(dossier_button != null, "selected RightInspector exposes a visible Intel Dossier action")
	if dossier_button != null:
		await _click_control(dossier_button)
		await _wait_frames(2)
		_expect(action_ids.count(intel_action_id) == 1, "selected detail emits one focused track_intel action")

	await _capture("public_track_selected.png")
	_dispose(screen)
	await _wait_frames(2)
	await _verify_dossier_focus()
	_finish()


func _verify_dossier_focus() -> void:
	root.size = Vector2i(1280, 960)
	var dossier := INTEL_DOSSIER_SCENE.instantiate() as Control
	_expect(dossier != null, "real IntelDossierBoard instantiates for selected resolution focus")
	if dossier == null:
		return
	root.add_child(dossier)
	dossier.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dossier_actions: Array[String] = []
	dossier.connect("action_requested", func(action_id: String) -> void:
		dossier_actions.append(action_id)
	)
	dossier.call("set_dossier", _dossier_state())
	await _wait_frames(4)
	var focused_resolution_id := -1
	if dossier.has_method("focused_resolution_id"):
		focused_resolution_id = int(dossier.call("focused_resolution_id"))
	_expect(focused_resolution_id == RESOLUTION_ID, "IntelDossierBoard keeps the same focused resolution_id from public action data")
	var focused_clue := dossier.find_child("IntelDossierFocusedClueCard", true, false) as Control
	_expect(
		focused_clue != null and int(focused_clue.get_meta("resolution_id", -1)) == RESOLUTION_ID,
		"IntelDossier focuses the evidence card for the same inferred resolution_id"
	)
	var dossier_text := _node_tree_text(dossier)
	_expect(
		dossier_text.contains("已选牌轨证据链")
		and dossier_text.contains("回到牌轨")
		and dossier_text.contains("竞猜")
		and dossier_text.contains("卡牌详情"),
		"focused IntelDossier renders the selected evidence chain and return paths"
	)
	_expect(not dossier_text.contains(PRIVATE_SENTINEL), "IntelDossier never renders owner, cash, or hand sentinels")
	var guess_button := _find_visible_button(dossier, "竞猜")
	_expect(
		guess_button != null and int(guess_button.get_meta("resolution_id", -1)) == RESOLUTION_ID,
		"focused IntelDossier exposes the same-resolution guess path"
	)
	if guess_button != null:
		await _click_control(guess_button)
		await _wait_frames(2)
		_expect(dossier_actions.count("track_guess_%d" % RESOLUTION_ID) == 1, "IntelDossier guess path preserves the same resolution_id")
	await _capture("intel_dossier_focused.png")
	_dispose(dossier)
	await _wait_frames(2)


func _table_state(selected: bool, entry_id: String, state_text: String) -> Dictionary:
	var entry := {
		"id": entry_id,
		"resolution_id": RESOLUTION_ID,
		"card_name": "轨道融资 I",
		"label": "%s 轨道融资" % state_text,
		"slot": "Q1",
		"state": state_text,
		"kind": "active" if selected else "queue",
		"selected": selected,
		"owner_hint": "待猜",
		"cost": "¥80",
		"tooltip": "只显示公开的牌轨顺序、报价与余波。",
		"requirements": [
			{"text": "公开条件: 商品门槛"},
			{"text": PRIVATE_SENTINEL, "private_owner": PRIVATE_SENTINEL},
		],
		"actions": [{
			"id": "track_intel_%d" % RESOLUTION_ID,
			"label": "线索档案",
			"private_owner": PRIVATE_SENTINEL,
		}],
		"deep_links": [{
			"id": "track_open_轨道融资 I",
			"label": "卡牌详情",
			"hidden_owner": PRIVATE_SENTINEL,
		}],
		"logs": [{"text": "公开余波", "private_note": PRIVATE_SENTINEL}],
		"hidden_owner": PRIVATE_SENTINEL,
		"owner": PRIVATE_SENTINEL,
		"cash": PRIVATE_SENTINEL,
		"hand": [PRIVATE_SENTINEL],
	}
	return {
		"card_track": [entry],
		"card_resolution_track": {"entries": [entry]},
		"right_inspector": {
			"title": "区域详情",
			"why": "等待公开对象。",
			"district": {"title": "未选择", "summary": ""},
			"actions": [],
			"deep_links": [],
		},
		"player_board": {"hand_cards": []},
	}


func _dossier_state() -> Dictionary:
	return {
		"title": "情报侦探板",
		"chips": [{"text": "已选牌轨:轨道融资"}],
		"actions": [
			{"id": "track_return_%d" % RESOLUTION_ID, "label": "回到牌轨"},
			{"id": "track_guess_%d" % RESOLUTION_ID, "label": "竞猜"},
			{"id": "track_open_轨道融资 I", "label": "卡牌详情"},
		],
		"clues": [{
			"title": "已选牌轨证据链",
			"lines": ["出价记录｜¥80", "余波线索｜GDP跳变", "私人推理｜尚未押注"],
			"hidden_owner": PRIVATE_SENTINEL,
		}],
		"hidden_owner": PRIVATE_SENTINEL,
		"cash": PRIVATE_SENTINEL,
		"hand": [PRIVATE_SENTINEL],
	}


func _entry_is_public(entry: Dictionary) -> bool:
	return not _variant_contains_private_track_data(entry)


func _variant_contains_private_track_data(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant in value:
			var key := str(key_variant).to_lower()
			if key in ["owner", "owner_id", "owner_index", "player_index", "viewer_index", "cash", "cash_cents", "hand", "hand_size"] or key.begins_with("private_") or key.begins_with("hidden_"):
				return true
			if _variant_contains_private_track_data((value as Dictionary)[key_variant]):
				return true
	elif value is Array:
		for entry_variant in value:
			if _variant_contains_private_track_data(entry_variant):
				return true
	elif value is String:
		return value.contains(PRIVATE_SENTINEL)
	return false


func _all_control_descendants_ignore_mouse(node: Node) -> bool:
	for child in node.get_children():
		if child is Control and (child as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			return false
		if not _all_control_descendants_ignore_mouse(child):
			return false
	return true


func _click_control(control: Control) -> void:
	var position := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion, true)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		event.global_position = position
		root.push_input(event, true)
		await process_frame


func _find_visible_button(node: Node, text_fragment: String) -> Button:
	if node == null:
		return null
	for child in node.find_children("*", "Button", true, false):
		var button := child as Button
		if button != null and button.is_visible_in_tree() and button.text.contains(text_fragment):
			return button
	return null


func _node_tree_text(node: Node) -> String:
	if node == null:
		return ""
	var parts: Array[String] = []
	if node is Label:
		parts.append((node as Label).text)
	elif node is Button:
		parts.append((node as Button).text)
	for child in node.get_children():
		var child_text := _node_tree_text(child)
		if child_text != "":
			parts.append(child_text)
	return " ".join(parts)


func _capture(file_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var absolute_dir := ProjectSettings.globalize_path(CAPTURE_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var absolute_path := absolute_dir.path_join(file_name)
	var image := root.get_texture().get_image()
	var error := image.save_png(absolute_path)
	_expect(error == OK, "headed viewport screenshot saves: %s" % file_name)
	if error == OK:
		print("PUBLIC_TRACK_CAPTURE=%s" % absolute_path)


func _wait_frames(count: int) -> void:
	for _frame in range(maxi(1, count)):
		await process_frame


func _dispose(node: Node) -> void:
	if node != null and node.get_parent() != null:
		node.get_parent().remove_child(node)
	if node != null:
		node.queue_free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PublicTrack real interaction test passed.")
	else:
		push_error("PublicTrack real interaction test failed:\n- " + "\n- ".join(_failures))
	quit(_failures.size())
