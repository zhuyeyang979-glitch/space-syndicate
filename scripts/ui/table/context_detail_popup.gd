@tool
extends PanelContainer
class_name SpaceSyndicateContextDetailPopup

signal closed
signal action_requested(action_id: String)
signal application_intent_requested(intent: IntelApplicationIntent)

const PROJECTION_FIELDS: Array[String] = [
	"schema_version",
	"source_revision",
	"viewer_index",
	"authorization_revision",
	"visibility_scope",
	"context_kind",
	"context_id",
	"title",
	"subtitle",
	"body",
	"chips",
	"actions",
	"deep_links",
]
const VALID_CONTEXT_KINDS := ["hand_card", "commodity_card", "bound_action", "public_track", "public_commodity", "region"]
const VALID_VISIBILITY_SCOPES := ["public", "viewer_private"]
const ACTION_FIELDS: Array[String] = ["id", "label", "disabled", "tooltip", "application_intent"]

@onready var title_label: Label = %DetailTitle
@onready var subtitle_label: Label = %DetailSubtitle
@onready var body_label: Label = %DetailBody
@onready var chip_row: HFlowContainer = %DetailChips
@onready var action_row: HFlowContainer = %DetailActions
@onready var deep_link_row: HFlowContainer = %DetailDeepLinks
@onready var close_button: Button = %DetailClose

var _projection: Dictionary = {}
var _bound_viewer_index := -1
var _bound_authorization_revision := 0
var _apply_count := 0
var _reject_count := 0


func _ready() -> void:
	close_button.pressed.connect(close_popup)
	set_process_unhandled_key_input(true)
	visible = false


func apply_projection(projection: Dictionary) -> bool:
	if not _valid_projection(projection):
		_reject_count += 1
		return false
	_projection = projection.duplicate(true)
	title_label.text = str(projection.get("title", "详情"))
	subtitle_label.text = str(projection.get("subtitle", ""))
	subtitle_label.visible = not subtitle_label.text.is_empty()
	body_label.text = str(projection.get("body", ""))
	body_label.tooltip_text = body_label.text
	_render_chips(projection.get("chips", []) as Array)
	_render_action_entries(action_row, projection.get("actions", []) as Array, false)
	_render_action_entries(deep_link_row, projection.get("deep_links", []) as Array, true)
	visible = true
	_apply_count += 1
	close_button.grab_focus()
	return true


func bind_viewer(viewer_index: int, authorization_revision: int) -> void:
	if viewer_index == _bound_viewer_index and authorization_revision == _bound_authorization_revision:
		return
	_bound_viewer_index = viewer_index
	_bound_authorization_revision = authorization_revision
	_projection = {}
	visible = false


func close_popup() -> void:
	visible = false
	closed.emit()


func debug_snapshot() -> Dictionary:
	return {
		"visible": visible,
		"context_kind": str(_projection.get("context_kind", "")),
		"context_id": str(_projection.get("context_id", "")),
		"visibility_scope": str(_projection.get("visibility_scope", "")),
		"viewer_index": _bound_viewer_index,
		"authorization_revision": _bound_authorization_revision,
		"apply_count": _apply_count,
		"reject_count": _reject_count,
		"action_entry_count": action_row.get_child_count(),
		"deep_link_entry_count": deep_link_row.get_child_count(),
		"mutates_gameplay": false,
	}


func _valid_projection(projection: Dictionary) -> bool:
	if not PlayerVisibleSurfacePolicy.is_safe_closed_data(projection) \
			or not PlayerVisibleSurfacePolicy.exact_fields(projection, PROJECTION_FIELDS) \
			or int(projection.get("schema_version", 0)) != 1 \
			or int(projection.get("source_revision", -1)) < 0 \
			or _bound_viewer_index < 0 \
			or _bound_authorization_revision <= 0 \
			or int(projection.get("viewer_index", -1)) != _bound_viewer_index \
			or int(projection.get("authorization_revision", 0)) != _bound_authorization_revision \
			or str(projection.get("visibility_scope", "")) not in VALID_VISIBILITY_SCOPES \
			or str(projection.get("context_kind", "")) not in VALID_CONTEXT_KINDS \
			or str(projection.get("context_id", "")).strip_edges().is_empty() \
			or str(projection.get("title", "")).strip_edges().is_empty() \
			or not (projection.get("chips", []) is Array):
		return false
	for chip_variant in projection.get("chips", []) as Array:
		if not (chip_variant is Dictionary):
			return false
		var chip := chip_variant as Dictionary
		if chip.keys().any(func(key: Variant) -> bool: return str(key) not in ["text", "tooltip", "accent"]):
			return false
	for key in ["actions", "deep_links"]:
		if not (projection.get(key, []) is Array):
			return false
		for entry_variant in projection.get(key, []) as Array:
			if not _valid_action_entry(entry_variant):
				return false
	return true


func _render_chips(chips: Array) -> void:
	for child in chip_row.get_children():
		chip_row.remove_child(child)
		child.queue_free()
	for chip_variant in chips.slice(0, 6):
		var chip := chip_variant as Dictionary
		var label := Label.new()
		label.text = PlayerVisibleSurfacePolicy.safe_text(chip.get("text"), "状态", 18)
		label.tooltip_text = str(chip.get("tooltip", label.text))
		var accent_variant: Variant = chip.get("accent", Color("#bfdbfe"))
		if accent_variant is Color:
			label.add_theme_color_override("font_color", accent_variant as Color)
		elif accent_variant is String and Color.html_is_valid(str(accent_variant)):
			label.add_theme_color_override("font_color", Color(str(accent_variant)))
		chip_row.add_child(label)


func _valid_action_entry(entry_variant: Variant) -> bool:
	if not (entry_variant is Dictionary):
		return false
	var entry := entry_variant as Dictionary
	if not PlayerVisibleSurfacePolicy.exact_fields(entry, ACTION_FIELDS) \
			or str(entry.get("id", "")).strip_edges().is_empty() \
			or str(entry.get("id", "")).length() > 120 \
			or str(entry.get("label", "")).strip_edges().is_empty() \
			or str(entry.get("label", "")).length() > 80 \
			or not (entry.get("disabled") is bool) \
			or not (entry.get("application_intent", {}) is Dictionary):
		return false
	var intent_data := entry.get("application_intent", {}) as Dictionary
	return intent_data.is_empty() or IntelApplicationIntent.from_dictionary(intent_data) != null


func _render_action_entries(parent: HFlowContainer, entries: Array, secondary: bool) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
	parent.visible = not entries.is_empty()
	for entry_variant in entries:
		var entry := entry_variant as Dictionary
		var button := Button.new()
		button.name = "ContextDeepLink" if secondary else "ContextAction"
		button.text = PlayerVisibleSurfacePolicy.safe_text(entry.get("label"), "查看详情", 20)
		button.tooltip_text = str(entry.get("tooltip", ""))
		button.disabled = bool(entry.get("disabled", false))
		button.focus_mode = Control.FOCUS_ALL
		button.custom_minimum_size = Vector2(88, 30)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var action_id := str(entry.get("id", ""))
		var intent_data := (entry.get("application_intent", {}) as Dictionary).duplicate(true)
		button.pressed.connect(_on_action_entry_pressed.bind(action_id, intent_data))
		parent.add_child(button)


func _on_action_entry_pressed(action_id: String, intent_data: Dictionary) -> void:
	if not intent_data.is_empty():
		var intent := IntelApplicationIntent.from_dictionary(intent_data)
		if intent != null and intent.is_valid():
			application_intent_requested.emit(intent)
		return
	action_requested.emit(action_id)


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_popup()
		get_viewport().set_input_as_handled()
