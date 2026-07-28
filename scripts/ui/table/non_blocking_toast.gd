@tool
extends PanelContainer
class_name SpaceSyndicateNonBlockingToast

const VALID_TONES := ["info", "success", "warning", "error"]

@onready var message_label: Label = %ToastMessage
@onready var dismiss_timer: Timer = %DismissTimer

var _show_count := 0
var _reject_count := 0
var _last_message := ""
var _last_tone := "info"


func _ready() -> void:
	dismiss_timer.timeout.connect(hide_toast)
	visible = false


func show_toast(message: String, tone: String = "info", duration_seconds: float = 3.0) -> bool:
	var normalized := message.replace("\n", " ").strip_edges()
	var normalized_tone := tone.strip_edges().to_lower()
	if normalized.is_empty() or normalized.length() > 320 \
			or normalized_tone not in VALID_TONES \
			or duration_seconds < 0.5 or duration_seconds > 12.0:
		_reject_count += 1
		return false
	_last_message = normalized
	_last_tone = normalized_tone
	message_label.text = normalized
	message_label.tooltip_text = normalized
	message_label.add_theme_color_override("font_color", _tone_color(normalized_tone))
	visible = true
	dismiss_timer.start(duration_seconds)
	_show_count += 1
	return true


func hide_toast() -> void:
	dismiss_timer.stop()
	visible = false


func debug_snapshot() -> Dictionary:
	return {
		"visible": visible,
		"show_count": _show_count,
		"reject_count": _reject_count,
		"last_message": _last_message,
		"last_tone": _last_tone,
		"mutates_gameplay": false,
	}


func _tone_color(tone: String) -> Color:
	return {
		"info": Color("#bfdbfe"),
		"success": Color("#86efac"),
		"warning": Color("#fde68a"),
		"error": Color("#fca5a5"),
	}.get(tone, Color("#bfdbfe")) as Color
