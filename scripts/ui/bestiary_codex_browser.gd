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


func _ready() -> void:
	previous_button.pressed.connect(func() -> void: page_step_requested.emit(-1))
	next_button.pressed.connect(func() -> void: page_step_requested.emit(1))


func set_browser(data: Dictionary) -> void:
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


func debug_snapshot() -> Dictionary:
	return {"selected_index": _selected_index, "rendered_indices": _rendered_indices.duplicate(), "page_label": page_label.text, "columns": thumbnail_grid.columns}


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
		card.connect("preview_requested", func(index: int) -> void: entry_preview_requested.emit(index))
		card.connect("detail_requested", func(index: int) -> void: entry_detail_requested.emit(index))
		_rendered_indices.append(catalog_index)


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
