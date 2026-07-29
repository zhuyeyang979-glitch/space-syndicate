@tool
extends PanelContainer
class_name SpaceSyndicateNonBlockingToastSurface

signal dismissed(receipt_id: String, reason_id: String)
signal navigation_intent_requested(intent: Dictionary)

const PROJECTION := preload("res://scripts/presentation/public_feedback_projection_v1.gd")
const PERFORMANCE_SAMPLE_LIMIT := 128

@onready var severity_label: Label = %ToastSeverity
@onready var message_label: Label = %ToastMessage
@onready var history_link_button: Button = %ToastHistoryLink
@onready var dismiss_button: Button = %ToastDismissButton
@onready var lifetime_timer: Timer = %ToastLifetimeTimer

var _projection: Dictionary = {}
var _bound_viewer_index := -1
var _bound_authorization_revision := 0
var _revision := -1
var _last_signature := ""
var _apply_count := 0
var _reject_count := 0
var _duplicate_count := 0
var _stale_count := 0
var _conflict_count := 0
var _dismiss_count := 0
var _render_usec_samples: Array[int] = []


func _ready() -> void:
	if not dismiss_button.pressed.is_connected(_on_dismiss_pressed):
		dismiss_button.pressed.connect(_on_dismiss_pressed)
	if not history_link_button.pressed.is_connected(_on_history_link_pressed):
		history_link_button.pressed.connect(_on_history_link_pressed)
	if not lifetime_timer.timeout.is_connected(_on_lifetime_timeout):
		lifetime_timer.timeout.connect(_on_lifetime_timeout)
	set_process_unhandled_key_input(visible)
	if _projection.is_empty():
		visible = false


func bind_viewer(viewer_index: int, authorization_revision: int) -> void:
	if viewer_index == _bound_viewer_index \
			and authorization_revision == _bound_authorization_revision:
		return
	_bound_viewer_index = viewer_index
	_bound_authorization_revision = authorization_revision
	clear_projection()


func apply_projection(value: Dictionary) -> bool:
	var render_started_usec := Time.get_ticks_usec()
	if not bool(PROJECTION.validation_report(value).get("valid", false)) \
			or not PROJECTION.matches_viewer_authorization(
				value,
				_bound_viewer_index,
				_bound_authorization_revision
			):
		_reject_count += 1
		return false
	var next_revision := int(value.get("revision", -1))
	var next_signature := str(value.get("projection_fingerprint", ""))
	if _revision >= 0 and next_revision < _revision:
		_stale_count += 1
		return false
	if next_signature == _last_signature:
		_duplicate_count += 1
		return true
	if _revision >= 0 and next_revision == _revision:
		_conflict_count += 1
		return false
	_projection = PROJECTION.detached_copy(value)
	_revision = next_revision
	_last_signature = next_signature
	_render_projection()
	_record_performance_sample(Time.get_ticks_usec() - render_started_usec)
	_apply_count += 1
	visible = true
	set_process_unhandled_key_input(true)
	lifetime_timer.start(_lifetime_seconds())
	return true


func clear_projection() -> void:
	_projection = {}
	_revision = -1
	_last_signature = ""
	if not is_node_ready():
		return
	lifetime_timer.stop()
	visible = false
	set_process_unhandled_key_input(false)
	severity_label.text = "消息"
	message_label.text = ""
	history_link_button.visible = false
	history_link_button.disabled = true


func dismiss(reason_id: String = "dismiss_button") -> void:
	if not visible:
		return
	var receipt_id := str(_projection.get("receipt_id", ""))
	_dismiss_count += 1
	lifetime_timer.stop()
	visible = false
	set_process_unhandled_key_input(false)
	dismissed.emit(receipt_id, reason_id)


func debug_snapshot() -> Dictionary:
	return {
		"viewer_index": _bound_viewer_index,
		"authorization_revision": _bound_authorization_revision,
		"revision": _revision,
		"projection_fingerprint": _last_signature,
		"receipt_id": str(_projection.get("receipt_id", "")),
		"public_or_viewer_private": str(_projection.get("public_or_viewer_private", "")),
		"severity": str(_projection.get("severity", "")),
		"apply_count": _apply_count,
		"reject_count": _reject_count,
		"duplicate_count": _duplicate_count,
		"stale_count": _stale_count,
		"conflict_count": _conflict_count,
		"dismiss_count": _dismiss_count,
		"visible": visible,
		"timer_running": lifetime_timer != null and not lifetime_timer.is_stopped(),
		"render_p95_ms": _p95_milliseconds(),
		"render_sample_count": _render_usec_samples.size(),
		"non_blocking": true,
		"persists_feedback": false,
		"forwards_viewer_private_to_public_history": false,
		"owns_public_log": false,
		"mutates_gameplay": false,
	}


func _render_projection() -> void:
	var severity := str(_projection.get("severity", PROJECTION.SEVERITY_INFORMATIONAL))
	severity_label.text = {
		PROJECTION.SEVERITY_SUCCESS: "成功",
		PROJECTION.SEVERITY_WARNING: "提醒",
		PROJECTION.SEVERITY_FAILURE: "未完成",
		PROJECTION.SEVERITY_INFORMATIONAL: "消息",
	}.get(severity, "消息") as String
	severity_label.add_theme_color_override("font_color", _severity_color(severity))
	message_label.text = _message_text(_projection)
	message_label.tooltip_text = message_label.text
	var history_link := _projection.get("history_link", {}) as Dictionary
	history_link_button.visible = not history_link.is_empty()
	history_link_button.disabled = history_link.is_empty()
	history_link_button.text = str(history_link.get("label", "查看记录"))


func _message_text(projection: Dictionary) -> String:
	var token := str(projection.get("message_token", "feedback"))
	var arguments := projection.get("arguments", {}) as Dictionary
	if arguments.is_empty():
		return token
	var keys: Array = arguments.keys()
	keys.sort()
	var parts: Array[String] = []
	for key_variant in keys:
		var key := str(key_variant)
		parts.append("%s=%s" % [key, str(arguments.get(key_variant))])
	return "%s｜%s" % [token, " · ".join(parts)]


func _lifetime_seconds() -> float:
	return 5.5 if str(_projection.get("public_or_viewer_private", "")) \
		== PROJECTION.VISIBILITY_VIEWER_PRIVATE else 4.5


func _severity_color(severity: String) -> Color:
	return {
		PROJECTION.SEVERITY_SUCCESS: Color("#86efac"),
		PROJECTION.SEVERITY_WARNING: Color("#fde68a"),
		PROJECTION.SEVERITY_FAILURE: Color("#fca5a5"),
		PROJECTION.SEVERITY_INFORMATIONAL: Color("#93c5fd"),
	}.get(severity, Color("#93c5fd")) as Color


func _on_history_link_pressed() -> void:
	var history_link := _projection.get("history_link", {}) as Dictionary
	var intent: Variant = history_link.get("navigation_intent", {})
	if intent is Dictionary and not (intent as Dictionary).is_empty():
		navigation_intent_requested.emit((intent as Dictionary).duplicate(true))


func _on_dismiss_pressed() -> void:
	dismiss("dismiss_button")


func _on_lifetime_timeout() -> void:
	dismiss("presentation_timeout")


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or event == null or not event.is_action_pressed("ui_cancel"):
		return
	var key_event := event as InputEventKey
	if key_event != null and key_event.echo:
		return
	dismiss("escape")
	get_viewport().set_input_as_handled()


func _record_performance_sample(elapsed_usec: int) -> void:
	_render_usec_samples.append(maxi(0, elapsed_usec))
	if _render_usec_samples.size() > PERFORMANCE_SAMPLE_LIMIT:
		_render_usec_samples.pop_front()


func _p95_milliseconds() -> float:
	if _render_usec_samples.is_empty():
		return 0.0
	var ordered: Array[int] = _render_usec_samples.duplicate()
	ordered.sort()
	var index := mini(ordered.size() - 1, ceili(float(ordered.size()) * 0.95) - 1)
	return float(ordered[index]) / 1000.0
