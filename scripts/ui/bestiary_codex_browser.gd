extends VBoxContainer
class_name SpaceSyndicateBestiaryCodexBrowser

signal page_step_requested(delta: int)
signal entry_preview_requested(catalog_index: int)
signal entry_detail_requested(catalog_index: int)

const SUMMARY_CARD_SCENE := preload("res://scenes/ui/codex/CodexBrowserSummaryCard.tscn")
const THUMBNAIL_CARD_SCENE := preload("res://scenes/ui/codex/BestiaryCodexThumbnailCard.tscn")

@onready var previous_button: Button = %BestiaryBrowserPreviousButton
@onready var next_button: Button = %BestiaryBrowserNextButton
@onready var page_label: Label = %BestiaryBrowserPageLabel
@onready var overview_host: HFlowContainer = %BestiaryBrowserOverviewHost
@onready var thumbnail_grid: GridContainer = %BestiaryBrowserThumbnailGrid
@onready var preview_detail: Control = %BestiaryBrowserPreviewDetail

var _rendered_indices: Array[int] = []
var _selected_index := -1
var _thumbnail_cards_by_index: Dictionary = {}
var _full_rebuild_count := 0
var _preview_apply_count := 0
var _preview_rejected_count := 0
var _preview_request_count := 0
var _detail_request_count := 0


func _ready() -> void:
	previous_button.pressed.connect(func() -> void: page_step_requested.emit(-1))
	next_button.pressed.connect(func() -> void: page_step_requested.emit(1))


func set_browser(data: Dictionary) -> void:
	_full_rebuild_count += 1
	_selected_index = int(data.get("selected_index", -1))
	thumbnail_grid.columns = maxi(1, int(data.get("columns", 3)))
	page_label.text = str(data.get("page_label", "第1/1页"))
	previous_button.disabled = not bool(data.get("can_page", false))
	next_button.disabled = not bool(data.get("can_page", false))
	_render_summaries(data.get("summaries", []) as Array)
	_render_entries(data.get("entries", []) as Array)
	var preview_variant: Variant = data.get("preview", {})
	if preview_detail != null and preview_detail.has_method("set_monster") and preview_variant is Dictionary:
		preview_detail.call("set_monster", preview_variant as Dictionary)


func apply_monster_preview(data: Dictionary) -> bool:
	var selected_index := int(data.get("selected_index", -1))
	var entries_variant: Variant = data.get("entries", [])
	var preview_variant: Variant = data.get("preview", {})
	if selected_index < 0 or not _thumbnail_cards_by_index.has(selected_index) or not (entries_variant is Array) or not (preview_variant is Dictionary):
		_preview_rejected_count += 1
		return false
	var entries := entries_variant as Array
	if entries.size() != _rendered_indices.size():
		_preview_rejected_count += 1
		return false
	var seen: Dictionary = {}
	for entry_variant: Variant in entries:
		if not (entry_variant is Dictionary):
			_preview_rejected_count += 1
			return false
		var entry := entry_variant as Dictionary
		var catalog_index := int(entry.get("catalog_index", -1))
		var card := _thumbnail_cards_by_index.get(catalog_index) as Control
		if catalog_index < 0 or card == null or seen.has(catalog_index):
			_preview_rejected_count += 1
			return false
		seen[catalog_index] = true
		card.call("set_entry", entry.duplicate(true))
	if seen.size() != _thumbnail_cards_by_index.size():
		_preview_rejected_count += 1
		return false
	_selected_index = selected_index
	preview_detail.call("set_monster", (preview_variant as Dictionary).duplicate(true))
	_preview_apply_count += 1
	return true


func debug_snapshot() -> Dictionary:
	var thumbnail_instance_ids: Dictionary = {}
	for index_variant: Variant in _thumbnail_cards_by_index:
		var card := _thumbnail_cards_by_index[index_variant] as Control
		if card != null:
			thumbnail_instance_ids[int(index_variant)] = card.get_instance_id()
	return {
		"selected_index": _selected_index,
		"rendered_indices": _rendered_indices.duplicate(),
		"page_label": page_label.text,
		"columns": thumbnail_grid.columns,
		"thumbnail_instance_ids": thumbnail_instance_ids,
		"full_rebuild_count": _full_rebuild_count,
		"preview_apply_count": _preview_apply_count,
		"preview_rejected_count": _preview_rejected_count,
		"preview_request_count": _preview_request_count,
		"detail_request_count": _detail_request_count,
	}


func _render_summaries(summaries: Array) -> void:
	_clear_children(overview_host)
	for summary_variant: Variant in summaries:
		if not (summary_variant is Dictionary):
			continue
		var card := SUMMARY_CARD_SCENE.instantiate() as Control
		if card == null:
			continue
		card.name = "CodexBrowserSummaryCard_%d" % overview_host.get_child_count()
		overview_host.add_child(card)
		card.call("set_summary", summary_variant as Dictionary)


func _render_entries(entries: Array) -> void:
	_clear_children(thumbnail_grid)
	_rendered_indices.clear()
	_thumbnail_cards_by_index.clear()
	for entry_variant: Variant in entries:
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		var card := THUMBNAIL_CARD_SCENE.instantiate() as Control
		if card == null:
			continue
		var catalog_index := int(entry.get("catalog_index", -1))
		card.name = "BestiaryThumbnail_%d" % catalog_index
		thumbnail_grid.add_child(card)
		card.call("set_entry", entry)
		card.connect("preview_requested", Callable(self, "_on_thumbnail_preview_requested"))
		card.connect("detail_requested", Callable(self, "_on_thumbnail_detail_requested"))
		_rendered_indices.append(catalog_index)
		_thumbnail_cards_by_index[catalog_index] = card


func _on_thumbnail_preview_requested(catalog_index: int) -> void:
	_preview_request_count += 1
	entry_preview_requested.emit(catalog_index)


func _on_thumbnail_detail_requested(catalog_index: int) -> void:
	_detail_request_count += 1
	entry_detail_requested.emit(catalog_index)


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
