extends PanelContainer
class_name V073PlaytestMarkerPanel
# MCP_FINALIZE

signal marker_requested(marker_type: String, note: String)

const COLLAPSED_SIZE := Vector2(82.0, 34.0)
const EXPANDED_SIZE := Vector2(292.0, 34.0)
const SAFE_MARGIN := 12.0

@onready var _row: HBoxContainer = %MarkerRow
@onready var _reopen_button: Button = %MarkerReopen
@onready var _note: LineEdit = %MarkerNote

var _last_viewport_size := Vector2(1600.0, 960.0)
var _last_layout_mode := "REGULAR_DESKTOP"
var _top_inset := 92.0


func _ready() -> void:
	%ConfusedButton.pressed.connect(_emit_marker.bind("confused"))
	%FrustratedButton.pressed.connect(_emit_marker.bind("frustrated"))
	%FunButton.pressed.connect(_emit_marker.bind("fun"))
	%MarkerClose.pressed.connect(_set_collapsed.bind(true))
	_reopen_button.pressed.connect(_set_collapsed.bind(false))
	_set_collapsed(true)


func apply_safe_layout(
	viewport_size: Vector2,
	layout_mode: String,
	top_inset: float = 92.0
) -> void:
	_last_viewport_size = viewport_size
	_last_layout_mode = layout_mode
	_top_inset = maxf(SAFE_MARGIN, top_inset)
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	var desired_size := COLLAPSED_SIZE if not _row.visible else EXPANDED_SIZE
	custom_minimum_size = desired_size
	size = desired_size
	position = Vector2(
		SAFE_MARGIN,
		minf(_top_inset, maxf(SAFE_MARGIN, viewport_size.y - desired_size.y - SAFE_MARGIN))
	)
	z_index = 80


func set_temporarily_hidden(hidden: bool) -> void:
	visible = not hidden


func debug_snapshot() -> Dictionary:
	var offscreen := not Rect2(Vector2.ZERO, _last_viewport_size).grow(1.0).encloses(get_global_rect())
	return {
		"gameplay_mutation_count": 0,
		"collapsed": not _row.visible,
		"marker_types": ["confused", "frustrated", "fun"],
		"layout_mode": _last_layout_mode,
		"header_width_consumption": 0 if not (get_parent() is Container) else int(size.x),
		"offscreen": offscreen,
		"offscreen_count": 1 if offscreen else 0,
		"primary_input_block_count": 0,
	}


func _emit_marker(marker_type: String) -> void:
	marker_requested.emit(marker_type, _clean_note(_note.text))
	_note.clear()


func _set_collapsed(collapsed: bool) -> void:
	_row.visible = not collapsed
	_reopen_button.visible = collapsed
	call_deferred("_refresh_safe_layout")


func _refresh_safe_layout() -> void:
	apply_safe_layout(_last_viewport_size, _last_layout_mode, _top_inset)


func _clean_note(value: String) -> String:
	var clean := ""
	for character in value:
		var code := character.unicode_at(0)
		if code >= 32 and code != 127:
			clean += character
	return clean.left(280)