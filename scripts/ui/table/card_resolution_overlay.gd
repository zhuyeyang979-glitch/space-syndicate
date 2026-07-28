@tool
extends ColorRect
class_name SpaceSyndicateCardResolutionOverlay

const PROJECTION := preload("res://scripts/presentation/card_resolution_overlay_projection_v1.gd")

@onready var title_label: Label = %CardResolutionTitleLabel
@onready var status_label: Label = %CardResolutionStatusLabel
@onready var badge_box: HBoxContainer = %CardResolutionBadgeBox
@onready var art: Control = %CardResolutionArt
@onready var body_label: Label = %CardResolutionBodyLabel

var _source_revision := -1
var _projection_fingerprint := ""
var _apply_count := 0
var _duplicate_count := 0
var _stale_count := 0
var _conflict_count := 0
var _reject_count := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func apply_projection(value: Dictionary) -> bool:
	if not bool(PROJECTION.validation_report(value).get("valid", false)):
		_reject_count += 1
		visible = false
		return false
	var next_revision := int(value.get("source_revision", -1))
	var fingerprint := str(value.get("projection_fingerprint", ""))
	if _source_revision >= 0 and next_revision < _source_revision:
		_stale_count += 1
		return false
	if fingerprint == _projection_fingerprint:
		_duplicate_count += 1
		return true
	if _source_revision >= 0 and next_revision == _source_revision:
		_conflict_count += 1
		return false
	_source_revision = next_revision
	_projection_fingerprint = fingerprint
	visible = bool(value.get("visible", false))
	if not visible:
		_apply_count += 1
		return true
	title_label.text = str(value.get("title", "牌桌结算"))
	status_label.text = str(value.get("status_text", "展示中"))
	body_label.text = str(value.get("body_text", "当前牌公开展示。"))
	body_label.tooltip_text = body_label.text
	_render_badges(value.get("badge_labels", []) as Array)
	var accent := Color(str(value.get("accent_hex", "#fb7185")))
	if art != null and art.has_method("set_card"):
		art.call(
			"set_card",
			title_label.text,
			str(value.get("card_kind", "")),
			str(value.get("card_tags", "")),
			accent,
			maxi(1, int(value.get("rank", 1))),
			true,
			str(value.get("art_stats", ""))
		)
	_apply_count += 1
	return true


func clear_projection() -> void:
	_source_revision = -1
	_projection_fingerprint = ""
	visible = false
	_render_badges([])


func debug_snapshot() -> Dictionary:
	return {
		"source_revision": _source_revision,
		"apply_count": _apply_count,
		"duplicate_count": _duplicate_count,
		"stale_count": _stale_count,
		"conflict_count": _conflict_count,
		"reject_count": _reject_count,
		"visible": visible,
		"typed_projection_only": true,
		"mutates_gameplay": false,
		"accepts_gameplay_input": false,
	}


func _render_badges(labels: Array) -> void:
	for child in badge_box.get_children():
		badge_box.remove_child(child)
		child.queue_free()
	badge_box.visible = not labels.is_empty()
	for label_variant in labels.slice(0, 4):
		var chip := Label.new()
		chip.text = str(label_variant)
		chip.add_theme_color_override("font_color", Color("#fde68a"))
		badge_box.add_child(chip)
