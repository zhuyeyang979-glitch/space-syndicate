@tool
extends PanelContainer
class_name SpaceSyndicateExpandablePublicHistorySurface

signal navigation_intent_requested(intent: Dictionary)
signal expansion_changed(expanded: bool)

const PROJECTION := preload("res://scripts/presentation/public_feedback_projection_v1.gd")
const PERFORMANCE_SAMPLE_LIMIT := 128

@onready var title_label: Label = %PublicHistoryTitle
@onready var toggle_button: Button = %PublicHistoryToggle
@onready var body: VBoxContainer = %PublicHistoryBody
@onready var entries_label: RichTextLabel = %PublicHistoryEntries
@onready var latest_link_button: Button = %PublicHistoryLatestLink

var _entries: Array[Dictionary] = []
var _bound_viewer_index := -1
var _bound_authorization_revision := 0
var _latest_revision := -1
var _last_signature := ""
var _expanded := false
var _apply_count := 0
var _reject_count := 0
var _private_reject_count := 0
var _duplicate_count := 0
var _stale_count := 0
var _conflict_count := 0
var _render_usec_samples: Array[int] = []


func _ready() -> void:
	if not toggle_button.pressed.is_connected(_on_toggle_pressed):
		toggle_button.pressed.connect(_on_toggle_pressed)
	if not latest_link_button.pressed.is_connected(_on_latest_link_pressed):
		latest_link_button.pressed.connect(_on_latest_link_pressed)
	_sync_expansion()


func bind_viewer(viewer_index: int, authorization_revision: int) -> void:
	if viewer_index == _bound_viewer_index \
			and authorization_revision == _bound_authorization_revision:
		return
	_bound_viewer_index = viewer_index
	_bound_authorization_revision = authorization_revision
	clear_history()


func apply_projections(values: Array) -> bool:
	var render_started_usec := Time.get_ticks_usec()
	if values.is_empty():
		_reject_count += 1
		return false
	var next_entries: Array[Dictionary] = []
	var receipt_ids: Dictionary = {}
	var next_revision := -1
	var signature_parts: Array[String] = []
	var previous_revision := -1
	for value_variant in values:
		if not (value_variant is Dictionary):
			_reject_count += 1
			return false
		var value := value_variant as Dictionary
		if not bool(PROJECTION.validation_report(value).get("valid", false)) \
				or not PROJECTION.matches_viewer_authorization(
					value,
					_bound_viewer_index,
					_bound_authorization_revision
				):
			_reject_count += 1
			return false
		if str(value.get("public_or_viewer_private", "")) != PROJECTION.VISIBILITY_PUBLIC:
			_reject_count += 1
			_private_reject_count += 1
			return false
		var entry_revision := int(value.get("revision", -1))
		if previous_revision > entry_revision:
			_reject_count += 1
			return false
		previous_revision = entry_revision
		next_revision = maxi(next_revision, entry_revision)
		var receipt_id := str(value.get("receipt_id", ""))
		if receipt_ids.has(receipt_id):
			_reject_count += 1
			return false
		receipt_ids[receipt_id] = true
		signature_parts.append(str(value.get("projection_fingerprint", "")))
		next_entries.append(PROJECTION.detached_copy(value))
	var next_signature := "|".join(signature_parts)
	if _latest_revision >= 0 and next_revision < _latest_revision:
		_stale_count += 1
		return false
	if next_signature == _last_signature:
		_duplicate_count += 1
		return true
	if _latest_revision >= 0 and next_revision == _latest_revision:
		_conflict_count += 1
		return false
	_entries = next_entries
	_latest_revision = next_revision
	_last_signature = next_signature
	_render_history()
	_record_performance_sample(Time.get_ticks_usec() - render_started_usec)
	_apply_count += 1
	return true


func apply_projection(value: Dictionary) -> bool:
	return apply_projections([value])


func clear_history() -> void:
	_entries.clear()
	_latest_revision = -1
	_last_signature = ""
	if not is_node_ready():
		return
	entries_label.text = "暂无公共记录。"
	title_label.text = "公共历史 · 0"
	latest_link_button.visible = false
	latest_link_button.disabled = true


func set_expanded(expanded: bool) -> void:
	if _expanded == expanded:
		return
	_expanded = expanded
	_sync_expansion()
	expansion_changed.emit(_expanded)


func debug_snapshot() -> Dictionary:
	return {
		"viewer_index": _bound_viewer_index,
		"authorization_revision": _bound_authorization_revision,
		"latest_revision": _latest_revision,
		"history_signature": _last_signature,
		"entry_count": _entries.size(),
		"expanded": _expanded,
		"apply_count": _apply_count,
		"reject_count": _reject_count,
		"private_reject_count": _private_reject_count,
		"duplicate_count": _duplicate_count,
		"stale_count": _stale_count,
		"conflict_count": _conflict_count,
		"entries_label_instance_id": entries_label.get_instance_id() if entries_label != null else 0,
		"render_p95_ms": _p95_milliseconds(),
		"render_sample_count": _render_usec_samples.size(),
		"accepts_public_only": true,
		"accepts_viewer_private": false,
		"owns_public_log": false,
		"persists_history": false,
		"mutates_gameplay": false,
	}


func _render_history() -> void:
	title_label.text = "公共历史 · %d" % _entries.size()
	var lines: Array[String] = []
	for entry in _entries:
		lines.append("%s  %s" % [_severity_symbol(str(entry.get("severity", ""))), _entry_text(entry)])
	entries_label.text = "\n".join(lines) if not lines.is_empty() else "暂无公共记录。"
	var latest_link := _latest_history_link()
	latest_link_button.visible = not latest_link.is_empty()
	latest_link_button.disabled = latest_link.is_empty()
	latest_link_button.text = str(latest_link.get("label", "查看最新记录"))


func _entry_text(entry: Dictionary) -> String:
	var token := str(entry.get("message_token", "feedback"))
	var arguments := entry.get("arguments", {}) as Dictionary
	if arguments.is_empty():
		return token
	var keys: Array = arguments.keys()
	keys.sort()
	var parts: Array[String] = []
	for key_variant in keys:
		parts.append("%s=%s" % [str(key_variant), str(arguments.get(key_variant))])
	return "%s｜%s" % [token, " · ".join(parts)]


func _severity_symbol(severity: String) -> String:
	return {
		PROJECTION.SEVERITY_SUCCESS: "✓",
		PROJECTION.SEVERITY_WARNING: "!",
		PROJECTION.SEVERITY_FAILURE: "×",
		PROJECTION.SEVERITY_INFORMATIONAL: "·",
	}.get(severity, "·") as String


func _latest_history_link() -> Dictionary:
	for index in range(_entries.size() - 1, -1, -1):
		var history_link := _entries[index].get("history_link", {}) as Dictionary
		if not history_link.is_empty():
			return history_link.duplicate(true)
	return {}


func _on_latest_link_pressed() -> void:
	var history_link := _latest_history_link()
	var intent: Variant = history_link.get("navigation_intent", {})
	if intent is Dictionary and not (intent as Dictionary).is_empty():
		navigation_intent_requested.emit((intent as Dictionary).duplicate(true))


func _on_toggle_pressed() -> void:
	set_expanded(not _expanded)


func _sync_expansion() -> void:
	if not is_node_ready():
		return
	body.visible = _expanded
	toggle_button.text = "收起" if _expanded else "展开"
	set_process_unhandled_key_input(_expanded)


func _unhandled_key_input(event: InputEvent) -> void:
	if not _expanded or event == null or not event.is_action_pressed("ui_cancel"):
		return
	var key_event := event as InputEventKey
	if key_event != null and key_event.echo:
		return
	set_expanded(false)
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
