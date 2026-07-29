@tool
extends Control
class_name SpaceSyndicateContextDetailDrawer

signal close_requested(reason_id: String)
signal navigation_intent_requested(intent: Dictionary)

const PROJECTION := preload("res://scripts/presentation/context_detail_projection_v1.gd")
const PERFORMANCE_SAMPLE_LIMIT := 128
const CLOSED_CONTEXT_KINDS := [
	"normal_card",
	"commodity_card",
	"public_track",
	"region_facility",
	"commodity_source",
	"public_event",
]

@onready var backdrop: ColorRect = %ContextDetailBackdrop
@onready var close_button: Button = %ContextDetailCloseButton
@onready var kind_label: Label = %ContextDetailKind
@onready var title_label: Label = %ContextDetailTitle
@onready var subtitle_label: Label = %ContextDetailSubtitle
@onready var identity_label: Label = %ContextDetailIdentity
@onready var status_label: Label = %ContextDetailStatus
@onready var body_label: Label = %ContextDetailBody
@onready var keyword_label: Label = %ContextDetailKeywords
@onready var navigation_row: HFlowContainer = %ContextDetailNavigationRow

var _projection: Dictionary = {}
var _bound_viewer_index := -1
var _bound_authorization_revision := 0
var _source_revision := -1
var _last_signature := ""
var _apply_count := 0
var _reject_count := 0
var _duplicate_count := 0
var _stale_count := 0
var _conflict_count := 0
var _close_count := 0
var _navigation_nodes: Dictionary = {}
var _render_usec_samples: Array[int] = []


func _ready() -> void:
	if not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)
	if not backdrop.gui_input.is_connected(_on_backdrop_gui_input):
		backdrop.gui_input.connect(_on_backdrop_gui_input)
	set_process_unhandled_key_input(visible)


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
			or str(value.get("context_kind", "")) not in CLOSED_CONTEXT_KINDS \
			or not PROJECTION.matches_viewer_authorization(
				value,
				_bound_viewer_index,
				_bound_authorization_revision
			):
		_reject_count += 1
		return false
	var next_revision := int(value.get("source_revision", -1))
	var next_signature := str(value.get("projection_fingerprint", ""))
	if _source_revision >= 0 and next_revision < _source_revision:
		_stale_count += 1
		return false
	if next_signature == _last_signature:
		_duplicate_count += 1
		return true
	if _source_revision >= 0 and next_revision == _source_revision:
		_conflict_count += 1
		return false
	_projection = PROJECTION.detached_copy(value)
	_source_revision = next_revision
	_last_signature = next_signature
	_render_projection()
	_record_performance_sample(Time.get_ticks_usec() - render_started_usec)
	_apply_count += 1
	show_drawer()
	return true


func clear_projection() -> void:
	_projection = {}
	_source_revision = -1
	_last_signature = ""
	if is_node_ready():
		_clear_navigation_nodes()
		hide_drawer()


func show_drawer() -> bool:
	if _projection.is_empty():
		return false
	visible = true
	set_process_unhandled_key_input(true)
	close_button.grab_focus.call_deferred()
	return true


func hide_drawer() -> void:
	visible = false
	set_process_unhandled_key_input(false)


func close_drawer(reason_id: String = "close_button") -> void:
	if not visible:
		return
	_close_count += 1
	hide_drawer()
	close_requested.emit(reason_id)


func debug_snapshot() -> Dictionary:
	return {
		"viewer_index": _bound_viewer_index,
		"authorization_revision": _bound_authorization_revision,
		"source_revision": _source_revision,
		"projection_fingerprint": _last_signature,
		"context_id": str(_projection.get("context_id", "")),
		"context_kind": str(_projection.get("context_kind", "")),
		"visibility_scope": str(_projection.get("visibility_scope", "")),
		"closed_context_kinds": CLOSED_CONTEXT_KINDS.duplicate(),
		"apply_count": _apply_count,
		"reject_count": _reject_count,
		"duplicate_count": _duplicate_count,
		"stale_count": _stale_count,
		"conflict_count": _conflict_count,
		"close_count": _close_count,
		"visible": visible,
		"navigation_count": _navigation_nodes.size(),
		"body_label_instance_id": body_label.get_instance_id() if body_label != null else 0,
		"render_p95_ms": _p95_milliseconds(),
		"render_sample_count": _render_usec_samples.size(),
		"read_only": true,
		"accepts_card_submission": false,
		"owns_detail_source": false,
		"mutates_gameplay": false,
	}


func _render_projection() -> void:
	var context_kind := str(_projection.get("context_kind", ""))
	var content := _projection.get("content", {}) as Dictionary
	kind_label.text = _kind_title(context_kind)
	title_label.text = str(_projection.get("title", "详情"))
	subtitle_label.text = str(_projection.get("subtitle", ""))
	subtitle_label.visible = not subtitle_label.text.is_empty()
	identity_label.text = _identity_text(context_kind, content)
	status_label.text = _status_text(context_kind, content)
	status_label.visible = not status_label.text.is_empty()
	body_label.text = _body_text(context_kind, content)
	body_label.tooltip_text = body_label.text
	var keyword_tokens: Array = content.get("keyword_tokens", []) \
		if content.get("keyword_tokens", []) is Array else []
	keyword_label.text = "关键词｜%s" % " · ".join(keyword_tokens)
	keyword_label.visible = not keyword_tokens.is_empty()
	_render_navigation(_navigation_entries(content))


func _kind_title(context_kind: String) -> String:
	return {
		PROJECTION.KIND_NORMAL_CARD: "普通牌详情",
		PROJECTION.KIND_COMMODITY_CARD: "商品牌详情",
		PROJECTION.KIND_PUBLIC_TRACK: "公共轨道详情",
		PROJECTION.KIND_REGION_FACILITY: "区域设施详情",
		PROJECTION.KIND_COMMODITY_SOURCE: "商品源详情",
		PROJECTION.KIND_PUBLIC_EVENT: "公共事件详情",
	}.get(context_kind, "上下文详情") as String


func _identity_text(context_kind: String, content: Dictionary) -> String:
	match context_kind:
		PROJECTION.KIND_NORMAL_CARD:
			return "%s｜%s" % [
				str(content.get("card_semantic_id", "")),
				str(content.get("card_instance_id", "")),
			]
		PROJECTION.KIND_COMMODITY_CARD:
			return "%s｜L%d｜%s" % [
				str(content.get("commodity_id", "")),
				int(content.get("level", 1)),
				str(content.get("commodity_card_instance_id", "")),
			]
		PROJECTION.KIND_PUBLIC_TRACK:
			return "%s｜%s" % [
				str(content.get("resolution_id", "")),
				str(content.get("card_semantic_id", "")),
			]
		PROJECTION.KIND_REGION_FACILITY:
			return "%s｜%s" % [
				str(content.get("region_id", "")),
				str(content.get("facility_id", "")),
			]
		PROJECTION.KIND_COMMODITY_SOURCE:
			return "%s｜%s" % [
				str(content.get("commodity_id", "")),
				str(content.get("source_id", "")),
			]
		PROJECTION.KIND_PUBLIC_EVENT:
			return "%s｜%s" % [
				str(content.get("receipt_id", "")),
				str(content.get("reason_id", "")),
			]
	return str(_projection.get("context_id", ""))


func _status_text(context_kind: String, content: Dictionary) -> String:
	if context_kind in [
		PROJECTION.KIND_PUBLIC_TRACK,
		PROJECTION.KIND_REGION_FACILITY,
		PROJECTION.KIND_COMMODITY_SOURCE,
	]:
		return "公开状态｜%s" % str(content.get("public_status", ""))
	var disabled_reason := str(content.get("disabled_reason_text", ""))
	if not disabled_reason.is_empty():
		return "当前状态｜%s" % disabled_reason
	if context_kind == PROJECTION.KIND_PUBLIC_EVENT:
		return "消息｜%s" % str(content.get("message_token", ""))
	return ""


func _body_text(context_kind: String, content: Dictionary) -> String:
	var lines: Array[String] = []
	match context_kind:
		PROJECTION.KIND_NORMAL_CARD:
			_append_line(lines, "时机", content.get("timing_text", ""))
			_append_line(lines, "目标", content.get("target_text", ""))
			_append_line(lines, "效果", content.get("effect_text", ""))
			_append_line(lines, "持续", content.get("duration_text", ""))
			_append_line(lines, "可见性", content.get("visibility_text", ""))
		PROJECTION.KIND_COMMODITY_CARD:
			_append_line(lines, "单位", content.get("base_units", 0))
			_append_line(lines, "目标", content.get("target_text", ""))
			_append_line(lines, "效果", content.get("effect_text", ""))
			_append_line(lines, "来源", content.get("source_text", ""))
		PROJECTION.KIND_PUBLIC_TRACK, PROJECTION.KIND_REGION_FACILITY, PROJECTION.KIND_COMMODITY_SOURCE:
			_append_line(lines, "摘要", content.get("summary", ""))
			_append_line(lines, "详情", content.get("detail", ""))
		PROJECTION.KIND_PUBLIC_EVENT:
			_append_line(lines, "摘要", content.get("summary", ""))
			_append_line(lines, "详情", content.get("detail", ""))
			_append_line(lines, "参数", _arguments_text(content.get("arguments", {})))
	return "\n\n".join(lines) if not lines.is_empty() else "暂无更多公开详情。"


func _append_line(lines: Array[String], label_text: String, value: Variant) -> void:
	var text := str(value).strip_edges()
	if text.is_empty() or text == "0":
		return
	lines.append("%s｜%s" % [label_text, text])


func _arguments_text(value_variant: Variant) -> String:
	var value: Dictionary = value_variant if value_variant is Dictionary else {}
	var keys: Array = value.keys()
	keys.sort()
	var parts: Array[String] = []
	for key_variant in keys:
		parts.append("%s=%s" % [str(key_variant), str(value.get(key_variant))])
	return " · ".join(parts)


func _navigation_entries(content: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for intent_variant in _projection.get("navigation_intents", []) as Array:
		result.append({
			"key": _navigation_key(intent_variant as Dictionary),
			"label": _navigation_label(intent_variant as Dictionary),
			"intent": (intent_variant as Dictionary).duplicate(true),
		})
	if str(_projection.get("context_kind", "")) == PROJECTION.KIND_PUBLIC_EVENT:
		var history_link := content.get("history_link", {}) as Dictionary
		if not history_link.is_empty():
			result.append({
				"key": "history:%s" % str(history_link.get("link_id", "")),
				"label": str(history_link.get("label", "查看记录")),
				"intent": (history_link.get("navigation_intent", {}) as Dictionary).duplicate(true),
			})
	return result


func _render_navigation(entries: Array[Dictionary]) -> void:
	var desired: Dictionary = {}
	for index in range(entries.size()):
		var entry := entries[index]
		var key := str(entry.get("key", ""))
		if key.is_empty():
			continue
		desired[key] = true
		var button := _navigation_nodes.get(key) as Button
		if button == null or not is_instance_valid(button):
			button = Button.new()
			button.name = "ContextDetailNavigationButton"
			button.focus_mode = Control.FOCUS_ALL
			button.pressed.connect(_on_navigation_pressed.bind(button))
			navigation_row.add_child(button)
			_navigation_nodes[key] = button
		button.text = str(entry.get("label", "查看"))
		button.tooltip_text = "只发出 typed navigation intent。"
		button.set_meta("context_detail_navigation_intent", (entry.get("intent", {}) as Dictionary).duplicate(true))
		navigation_row.move_child(button, mini(index, navigation_row.get_child_count() - 1))
	for key_variant in _navigation_nodes.keys():
		var key := str(key_variant)
		if desired.has(key):
			continue
		var button := _navigation_nodes.get(key) as Button
		_navigation_nodes.erase(key)
		if button != null and is_instance_valid(button):
			navigation_row.remove_child(button)
			button.queue_free()
	navigation_row.visible = not _navigation_nodes.is_empty()


func _navigation_key(intent: Dictionary) -> String:
	var request_id := str(intent.get("request_id", ""))
	if not request_id.is_empty():
		return "table:%s" % request_id
	return "intel:%s:%s:%s" % [
		str(intent.get("kind", "")),
		str(intent.get("focused_history_entry_id", "")),
		str(intent.get("focused_region_id", "")),
	]


func _navigation_label(intent: Dictionary) -> String:
	var action_kind := str(intent.get("action_kind", ""))
	if not action_kind.is_empty():
		return "查看 %s" % action_kind
	var kind := str(intent.get("kind", ""))
	return "查看详情" if kind.is_empty() else "查看 %s" % kind


func _on_navigation_pressed(button: Button) -> void:
	var intent: Variant = button.get_meta("context_detail_navigation_intent", {})
	if intent is Dictionary and not (intent as Dictionary).is_empty():
		navigation_intent_requested.emit((intent as Dictionary).duplicate(true))


func _clear_navigation_nodes() -> void:
	for button_variant in _navigation_nodes.values():
		var button := button_variant as Button
		if button != null and is_instance_valid(button):
			button.queue_free()
	_navigation_nodes.clear()


func _on_close_pressed() -> void:
	close_drawer("close_button")


func _on_backdrop_gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	close_drawer("outside_pointer")
	backdrop.accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or event == null or not event.is_action_pressed("ui_cancel"):
		return
	var key_event := event as InputEventKey
	if key_event != null and key_event.echo:
		return
	close_drawer("escape")
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
