extends PanelContainer
class_name V074VirtualizedTargetRail

signal region_popup_requested(dto: Dictionary)
signal target_binding_requested(binding: Dictionary)
signal typed_feedback_requested(reason_code: String)
signal collapsed_changed(collapsed: bool)

const Adapter := preload("res://scripts/v074/player/v074_player_map_projection_adapter.gd")
const PopupDto := preload("res://scripts/v074/player/v074_region_popup_dto_v1.gd")
const TargetBinding := preload("res://scripts/v074/player/v074_map_target_binding_v1.gd")

const ROW_POOL_SIZE := 10
const ROW_HEIGHT := 38.0
const ROW_SEPARATION := 4.0
const ROW_STRIDE := ROW_HEIGHT + ROW_SEPARATION

@onready var _toggle_button: Button = %ToggleButton
@onready var _title_label: Label = %TitleLabel
@onready var _count_label: Label = %CountLabel
@onready var _body: VBoxContainer = %Body
@onready var _search_input: LineEdit = %SearchInput
@onready var _scroll: ScrollContainer = %TargetScroll
@onready var _top_spacer: Control = %TopSpacer
@onready var _rows: VBoxContainer = %Rows
@onready var _bottom_spacer: Control = %BottomSpacer
@onready var _empty_label: Label = %EmptyLabel

var _projection: Dictionary = {}
var _region_popups: Dictionary = {}
var _all_entries: Array = []
var _filtered_entries: Array = []
var _row_pool: Array[Button] = []
var _selected_card_instance_id := ""
var _collapsed := true
var _focus_index := -1
var _window_start := 0
var _window_end := 0
var _refresh_count := 0
var _scroll_refresh_count := 0
var _activation_count := 0
var _last_region_popup_id := ""
var _last_binding_fingerprint := ""
var _last_reason_code := "rail_unbound"


func _ready() -> void:
	_toggle_button.pressed.connect(func() -> void:
		set_collapsed(not _collapsed)
	)
	_search_input.text_changed.connect(func(_value: String) -> void:
		_apply_filter()
	)
	_search_input.text_submitted.connect(func(_value: String) -> void:
		if not _filtered_entries.is_empty():
			_focus_index = maxi(0, _focus_index)
			_activate_filtered_index(_focus_index)
	)
	_scroll.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void:
		_scroll_refresh_count += 1
		_refresh_window()
	)
	resized.connect(_refresh_window)
	_build_row_pool()
	set_collapsed(true)
	_apply_filter()


func bind_projection(dto: Dictionary) -> bool:
	var report := Adapter.validation_report(dto)
	if not bool(report.get("valid", false)):
		_projection = {}
		_region_popups = {}
		_all_entries = []
		_last_reason_code = str(report.get("reason_code", "projection_invalid"))
		_apply_filter()
		return false
	_projection = dto.duplicate(true)
	_region_popups = (
		dto.get("region_popup_by_id", {}) as Dictionary
	).duplicate(true)
	_rebuild_source_entries()
	_last_reason_code = "projection_bound"
	return true


func set_selected_card(card_instance_id: String) -> void:
	if card_instance_id == _selected_card_instance_id:
		return
	_selected_card_instance_id = card_instance_id
	_rebuild_source_entries()


func selected_card_instance_id() -> String:
	return _selected_card_instance_id


func set_collapsed(value: bool) -> void:
	_collapsed = value
	_body.visible = not value
	_toggle_button.text = ">" if value else "v"
	_toggle_button.tooltip_text = "Open keyboard target list" if value else "Collapse keyboard target list"
	_title_label.text = "Target backup" if value else "Keyboard target backup"
	custom_minimum_size.y = 36.0 if value else 250.0
	collapsed_changed.emit(value)
	if not value:
		call_deferred("_refresh_window")


func is_collapsed() -> bool:
	return _collapsed


func set_search_text(value: String) -> void:
	_search_input.text = value
	_search_input.caret_column = value.length()
	_apply_filter()


func focus_search() -> void:
	if _collapsed:
		set_collapsed(false)
	_search_input.grab_focus()


func filtered_entry_count() -> int:
	return _filtered_entries.size()


func rendered_entry_count() -> int:
	var count := 0
	for button in _row_pool:
		if button.visible:
			count += 1
	return count


func debug_snapshot() -> Dictionary:
	return {
		"schema": "V074VirtualizedTargetRailDebugV1",
		"projection_bound": not _projection.is_empty(),
		"region_count": int(_projection.get("region_count", 0)),
		"selected_card_instance_id": _selected_card_instance_id,
		"collapsed": _collapsed,
		"searchable": true,
		"collapsible": true,
		"virtualized": true,
		"secondary_to_globe": true,
		"planet_primary_target_selection_surface": true,
		"target_rail_primary_surface": false,
		"total_entry_count": _all_entries.size(),
		"filtered_entry_count": _filtered_entries.size(),
		"rendered_row_count": rendered_entry_count(),
		"row_pool_size": _row_pool.size(),
		"permanent_entry_button_count": _row_pool.size(),
		"window_start": _window_start,
		"window_end": _window_end,
		"refresh_count": _refresh_count,
		"scroll_refresh_count": _scroll_refresh_count,
		"activation_count": _activation_count,
		"last_region_popup_id": _last_region_popup_id,
		"last_binding_fingerprint": _last_binding_fingerprint,
		"last_reason_code": _last_reason_code,
		"runtime_owner_dependency_count": 0,
		"gameplay_mutation_count": 0,
		"rng_draw_count": 0,
		"header_width_consumption": 0,
	}


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.ctrl_pressed and key_event.keycode == KEY_F:
		focus_search()
		get_viewport().set_input_as_handled()
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus == null or not (focus == self or is_ancestor_of(focus)):
		return
	match key_event.keycode:
		KEY_DOWN:
			_move_focus(1)
			get_viewport().set_input_as_handled()
		KEY_UP:
			_move_focus(-1)
			get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER:
			if _focus_index >= 0:
				_activate_filtered_index(_focus_index)
				get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			set_collapsed(true)
			get_viewport().set_input_as_handled()


func _build_row_pool() -> void:
	for index in range(ROW_POOL_SIZE):
		var button := Button.new()
		button.name = "VirtualTargetRow%02d" % index
		button.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_ALL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.visible = false
		button.pressed.connect(_on_pool_button_pressed.bind(button))
		button.focus_entered.connect(_on_pool_button_focus_entered.bind(button))
		_rows.add_child(button)
		_row_pool.append(button)


func _rebuild_source_entries() -> void:
	if _projection.is_empty():
		_all_entries = []
	elif _selected_card_instance_id.is_empty():
		_all_entries = (
			_projection.get("target_rail_region_entries", []) as Array
		).duplicate(true)
	else:
		_all_entries = []
		for value in _projection.get("target_rail_target_entries", []) as Array:
			var entry := value as Dictionary
			if str(entry.get("card_instance_id", "")) == _selected_card_instance_id:
				_all_entries.append(entry.duplicate(true))
	_apply_filter()


func _apply_filter() -> void:
	_filtered_entries = []
	var query := _search_input.text.strip_edges().to_lower() if is_instance_valid(_search_input) else ""
	for value in _all_entries:
		var entry := value as Dictionary
		if query.is_empty() or str(entry.get("search_text", "")).to_lower().contains(query):
			_filtered_entries.append(entry.duplicate(true))
	_focus_index = 0 if not _filtered_entries.is_empty() else -1
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = 0
	_count_label.text = "%d" % _filtered_entries.size()
	_empty_label.visible = _filtered_entries.is_empty()
	_last_reason_code = "filter_applied"
	_refresh_window()


func _refresh_window() -> void:
	if not is_instance_valid(_scroll) or _row_pool.is_empty():
		return
	var visible_rows := clampi(
		int(ceil(maxf(_scroll.size.y, ROW_HEIGHT) / ROW_STRIDE)) + 2,
		4,
		ROW_POOL_SIZE
	)
	var first := maxi(0, int(floor(float(_scroll.scroll_vertical) / ROW_STRIDE)) - 1)
	var maximum_first := maxi(0, _filtered_entries.size() - visible_rows)
	first = mini(first, maximum_first)
	var last := mini(_filtered_entries.size(), first + visible_rows)
	_window_start = first
	_window_end = last
	_top_spacer.custom_minimum_size.y = float(first) * ROW_STRIDE
	_bottom_spacer.custom_minimum_size.y = float(_filtered_entries.size() - last) * ROW_STRIDE
	for pool_index in range(_row_pool.size()):
		var button := _row_pool[pool_index]
		var entry_index := first + pool_index
		if entry_index >= last:
			button.visible = false
			button.set_meta("entry_index", -1)
			continue
		var entry := _filtered_entries[entry_index] as Dictionary
		button.visible = true
		button.set_meta("entry_index", entry_index)
		button.text = _entry_label(entry)
		button.tooltip_text = _entry_tooltip(entry)
		button.disabled = false
	_refresh_count += 1


func _entry_label(entry: Dictionary) -> String:
	var terrain := "LAND" if str(entry.get("terrain_class", "")) == "land" else "OCEAN"
	var solar := "SUN" if bool(entry.get("sunlit", false)) else "DARK"
	if str(entry.get("entry_kind", "")) == "region_popup":
		return "%s  |  %s  |  %s" % [
			str(entry.get("display_name", entry.get("region_id", ""))),
			terrain,
			solar,
		]
	return "%s  |  %s / %s  |  %s" % [
		str(entry.get("display_name", entry.get("region_id", ""))),
		str(entry.get("facility_type", "")).to_upper(),
		str(entry.get("industry_id", "")).to_upper(),
		_mode_label(str(entry.get("facility_action_mode", ""))),
	]


func _entry_tooltip(entry: Dictionary) -> String:
	if str(entry.get("entry_kind", "")) == "region_popup":
		return "Open public Region Popup. Globe remains the primary map surface."
	return "Bind exact region + facility type + industry + action mode."


func _mode_label(mode: String) -> String:
	return {
		"BUILD_NEW": "BUILD",
		"UPGRADE_OWN": "UPGRADE",
		"REPAIR_OWN": "REPAIR",
	}.get(mode, mode)


func _on_pool_button_pressed(button: Button) -> void:
	_activate_filtered_index(int(button.get_meta("entry_index", -1)))


func _on_pool_button_focus_entered(button: Button) -> void:
	_focus_index = int(button.get_meta("entry_index", -1))


func _activate_filtered_index(index: int) -> void:
	if index < 0 or index >= _filtered_entries.size():
		_emit_feedback("target_rail_index_invalid")
		return
	var entry := _filtered_entries[index] as Dictionary
	match str(entry.get("entry_kind", "")):
		"region_popup":
			var region_id := str(entry.get("region_id", ""))
			var popup := _region_popups.get(region_id, {}) as Dictionary
			if not bool(PopupDto.validation_report(popup).get("valid", false)):
				_emit_feedback("region_popup_invalid")
				return
			_activation_count += 1
			_last_region_popup_id = region_id
			_last_reason_code = "region_popup_requested"
			region_popup_requested.emit(popup.duplicate(true))
		"target_binding":
			var binding := entry.get("binding", {}) as Dictionary
			if not bool(TargetBinding.validation_report(binding).get("valid", false)):
				_emit_feedback("target_binding_invalid")
				return
			_activation_count += 1
			_last_binding_fingerprint = str(binding.get("binding_fingerprint", ""))
			_last_reason_code = "target_binding_requested"
			target_binding_requested.emit(binding.duplicate(true))
		_:
			_emit_feedback("target_rail_entry_kind_invalid")


func _move_focus(direction: int) -> void:
	if _filtered_entries.is_empty():
		return
	_focus_index = clampi(_focus_index + direction, 0, _filtered_entries.size() - 1)
	var top := float(_focus_index) * ROW_STRIDE
	var bottom := top + ROW_HEIGHT
	if top < float(_scroll.scroll_vertical):
		_scroll.scroll_vertical = int(top)
	elif bottom > float(_scroll.scroll_vertical) + _scroll.size.y:
		_scroll.scroll_vertical = int(bottom - _scroll.size.y)
	_refresh_window()
	call_deferred("_focus_rendered_index", _focus_index)


func _focus_rendered_index(index: int) -> void:
	for button in _row_pool:
		if button.visible and int(button.get_meta("entry_index", -1)) == index:
			button.grab_focus()
			return


func _emit_feedback(reason_code: String) -> void:
	_last_reason_code = reason_code
	typed_feedback_requested.emit(reason_code)
