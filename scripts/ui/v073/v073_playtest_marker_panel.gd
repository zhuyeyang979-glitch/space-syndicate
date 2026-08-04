extends PanelContainer
class_name V073PlaytestMarkerPanel
# MCP_FINALIZE

signal marker_requested(marker_type: String, note: String)

@onready var _row: HBoxContainer = %MarkerRow
@onready var _reopen_button: Button = %MarkerReopen
@onready var _note: LineEdit = %MarkerNote


func _ready() -> void:
	%ConfusedButton.pressed.connect(_emit_marker.bind("confused"))
	%FrustratedButton.pressed.connect(_emit_marker.bind("frustrated"))
	%FunButton.pressed.connect(_emit_marker.bind("fun"))
	%MarkerClose.pressed.connect(_set_collapsed.bind(true))
	_reopen_button.pressed.connect(_set_collapsed.bind(false))
	_reopen_button.visible = false


func debug_snapshot() -> Dictionary:
	return {
		"gameplay_mutation_count": 0,
		"collapsed": not _row.visible,
		"marker_types": ["confused", "frustrated", "fun"],
	}


func _emit_marker(marker_type: String) -> void:
	marker_requested.emit(marker_type, _clean_note(_note.text))
	_note.clear()


func _set_collapsed(collapsed: bool) -> void:
	_row.visible = not collapsed
	_reopen_button.visible = collapsed


func _clean_note(value: String) -> String:
	var clean := ""
	for character in value:
		var code := character.unicode_at(0)
		if code >= 32 and code != 127:
			clean += character
	return clean.left(280)
