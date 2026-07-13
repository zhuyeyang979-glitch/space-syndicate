@tool
extends Control
class_name RuntimeCardAuthoringWorkspace

signal resource_open_requested(resource_path: String)

@onready var pack_option: OptionButton = %AuthoringPackOption
@onready var family_search: LineEdit = %AuthoringFamilySearch
@onready var family_list: ItemList = %AuthoringFamilyList
@onready var card_list: ItemList = %AuthoringCardList
@onready var selection_label: Label = %AuthoringSelectionLabel
@onready var resource_path_label: Label = %AuthoringResourcePathLabel
@onready var card_summary_label: Label = %AuthoringCardSummaryLabel
@onready var rules_text_label: Label = %AuthoringRulesTextLabel
@onready var validation_output: RichTextLabel = %AuthoringValidationOutput
@onready var review_output: RichTextLabel = %AuthoringReviewOutput
@onready var status_label: Label = %AuthoringWorkspaceStatusLabel
@onready var open_button: Button = %OpenSelectedCardResourceButton
@onready var validate_button: Button = %ValidateSelectedCardButton
@onready var baseline_button: Button = %CaptureAuthoringBaselineButton
@onready var review_button: Button = %BuildAuthoringReviewButton
@onready var validate_catalog_button: Button = %ValidateWholeCatalogButton

var _service := CardRuntimeAuthoringService.new()
var _index: Dictionary = {}
var _visible_families: Array = []
var _selected_family: Dictionary = {}
var _selected_card: Dictionary = {}


func _ready() -> void:
	_connect_signals()
	refresh_index()


func refresh_index() -> Dictionary:
	var configured := _service.configure()
	_index = _service.authoring_index()
	if not bool(configured.get("configured", false)) or not bool(_index.get("valid", false)):
		_set_status("Catalog Resource could not be loaded.")
		return _index
	_populate_packs()
	_filter_families()
	_set_status("%d packs | %d families | %d authored cards" % [int(_index.get("pack_count", 0)), int(_index.get("family_count", 0)), int(_index.get("card_count", 0))])
	return _index.duplicate(true)


func select_family(family_id: String) -> Dictionary:
	for family_variant in _index.get("families", []):
		var family: Dictionary = family_variant if family_variant is Dictionary else {}
		if str(family.get("family_id", "")) != family_id:
			continue
		_selected_family = family.duplicate(true)
		_populate_cards()
		return _selected_family.duplicate(true)
	return {}


func select_card(card_id: String) -> Dictionary:
	for card_variant in _index.get("cards", []):
		var card: Dictionary = card_variant if card_variant is Dictionary else {}
		if str(card.get("card_id", "")) != card_id:
			continue
		_selected_card = card.duplicate(true)
		_update_detail()
		return _selected_card.duplicate(true)
	return {}


func validate_selected() -> Dictionary:
	var report: Dictionary
	if not _selected_card.is_empty():
		report = _service.validate_card_id(str(_selected_card.get("card_id", "")))
	elif not _selected_family.is_empty():
		report = _service.validate_family_id(str(_selected_family.get("family_id", "")))
	else:
		report = _service.validate_catalog()
	_show_validation(report)
	return report.duplicate(true)


func validate_catalog() -> Dictionary:
	var report := _service.validate_catalog()
	_show_validation(report)
	return report.duplicate(true)


func capture_baseline() -> Dictionary:
	var result := _service.capture_baseline()
	_set_status("Baseline captured under user://" if bool(result.get("captured", false)) else "Baseline capture failed: %s" % str(result.get("error", "unknown")))
	return result.duplicate(true)


func build_change_review() -> Dictionary:
	var review := _service.build_change_review(true)
	_show_review(review)
	_set_status("Review %s | %d changed | %d added | %d removed" % [str(review.get("review_status", "unknown")), int(review.get("changed_count", 0)), int(review.get("added_count", 0)), int(review.get("removed_count", 0))])
	return review.duplicate(true)


func open_selected_resource() -> String:
	var path := str(_selected_family.get("resource_path", ""))
	if path.is_empty():
		path = CardRuntimeAuthoringService.CATALOG_PATH
	resource_open_requested.emit(path)
	print("RuntimeCardAuthoringWorkspace resource: %s" % path)
	_set_status("Resource path printed for editor/MCP: %s" % path)
	return path


func authoring_index() -> Dictionary:
	return _index.duplicate(true)


func output_dir() -> String:
	return _service.output_dir()


func debug_snapshot() -> Dictionary:
	return {
		"workspace_ready": bool(_index.get("valid", false)),
		"pack_count": int(_index.get("pack_count", 0)),
		"family_count": int(_index.get("family_count", 0)),
		"card_count": int(_index.get("card_count", 0)),
		"selected_family_id": str(_selected_family.get("family_id", "")),
		"selected_card_id": str(_selected_card.get("card_id", "")),
		"selected_resource_path": str(_selected_family.get("resource_path", "")),
		"output_dir": _service.output_dir(),
		"inspector_authoring_enabled": true,
		"runtime_owner_unchanged": "CardRuntimeCatalogService",
	}


func _connect_signals() -> void:
	pack_option.item_selected.connect(_on_pack_selected)
	family_search.text_changed.connect(_on_search_changed)
	family_list.item_selected.connect(_on_family_selected)
	card_list.item_selected.connect(_on_card_selected)
	open_button.pressed.connect(open_selected_resource)
	validate_button.pressed.connect(validate_selected)
	baseline_button.pressed.connect(capture_baseline)
	review_button.pressed.connect(build_change_review)
	validate_catalog_button.pressed.connect(validate_catalog)


func _populate_packs() -> void:
	pack_option.clear()
	for pack_variant in _index.get("packs", []):
		var pack: Dictionary = pack_variant if pack_variant is Dictionary else {}
		pack_option.add_item(str(pack.get("display_name", pack.get("pack_id", "Pack"))))
		pack_option.set_item_metadata(pack_option.item_count - 1, str(pack.get("pack_id", "")))
	if pack_option.item_count > 0:
		pack_option.select(0)


func _filter_families() -> void:
	_visible_families.clear()
	family_list.clear()
	var selected_pack := str(pack_option.get_item_metadata(pack_option.selected)) if pack_option.item_count > 0 and pack_option.selected >= 0 else ""
	var query := family_search.text.strip_edges().to_lower()
	for family_variant in _index.get("families", []):
		var family: Dictionary = family_variant if family_variant is Dictionary else {}
		if not selected_pack.is_empty() and str(family.get("pack_id", "")) != selected_pack:
			continue
		if not query.is_empty() and not str(family.get("family_id", "")).to_lower().contains(query):
			continue
		_visible_families.append(family.duplicate(true))
		family_list.add_item("%s  [%d]" % [str(family.get("family_id", "")), int(family.get("rank_count", 0))])
	if not _visible_families.is_empty():
		family_list.select(0)
		_selected_family = (_visible_families[0] as Dictionary).duplicate(true)
		_populate_cards()
	else:
		_selected_family.clear()
		_selected_card.clear()
		card_list.clear()
		_update_detail()


func _populate_cards() -> void:
	card_list.clear()
	_selected_card.clear()
	for card_id_variant in _selected_family.get("card_ids", []):
		var card_id := str(card_id_variant)
		for card_variant in _index.get("cards", []):
			var card: Dictionary = card_variant if card_variant is Dictionary else {}
			if str(card.get("card_id", "")) != card_id:
				continue
			card_list.add_item("%s   %s" % [card_id, str(card.get("kind", ""))])
			card_list.set_item_metadata(card_list.item_count - 1, card_id)
			break
	if card_list.item_count > 0:
		card_list.select(0)
		select_card(str(card_list.get_item_metadata(0)))
	else:
		_update_detail()


func _update_detail() -> void:
	var family_id := str(_selected_family.get("family_id", "No family selected"))
	var card_id := str(_selected_card.get("card_id", "No card selected"))
	selection_label.text = "%s / %s" % [family_id, card_id]
	resource_path_label.text = str(_selected_family.get("resource_path", CardRuntimeAuthoringService.CATALOG_PATH))
	if _selected_card.is_empty():
		card_summary_label.text = "Select an authored rank to inspect its typed definition."
		rules_text_label.text = ""
		return
	card_summary_label.text = "Kind %s   Rank %d   Purchase %d\nPack %s   Hash %s" % [
		str(_selected_card.get("kind", "")),
		int(_selected_card.get("rank", 0)),
		int(_selected_card.get("purchase_cost", 0)),
		str(_selected_card.get("pack_id", "")),
		str(_selected_card.get("definition_hash", "")).left(16),
	]
	rules_text_label.text = str(_selected_card.get("rules_text", ""))


func _show_validation(report: Dictionary) -> void:
	var lines: Array[String] = []
	lines.append("[color=%s][b]%s[/b][/color]  %d checks  %d errors  %d warnings" % ["#64d8cb" if bool(report.get("valid", false)) else "#ff7b72", "VALID" if bool(report.get("valid", false)) else "BLOCKED", (report.get("checks", []) as Array).size(), int(report.get("error_count", 0)), int(report.get("warning_count", 0))])
	for error_variant in report.get("errors", []):
		var error: Dictionary = error_variant if error_variant is Dictionary else {}
		lines.append("[color=#ff9b91]• %s[/color]  %s" % [str(error.get("check_id", "error")), str(error.get("message", ""))])
	for warning_variant in report.get("warnings", []):
		var warning: Dictionary = warning_variant if warning_variant is Dictionary else {}
		lines.append("[color=#f2c66d]• %s[/color]  %s" % [str(warning.get("check_id", "warning")), str(warning.get("message", ""))])
	validation_output.text = "\n".join(lines)


func _show_review(review: Dictionary) -> void:
	var lines: Array[String] = [
		"[b]%s[/b]" % str(review.get("review_status", "unknown")),
		"Changed %d   Added %d   Removed %d" % [int(review.get("changed_count", 0)), int(review.get("added_count", 0)), int(review.get("removed_count", 0))],
		"Baseline %s   Validation %s" % ["available" if bool(review.get("baseline_available", false)) else "hash-only", "passed" if bool((review.get("validation", {}) as Dictionary).get("valid", false)) else "blocked"],
	]
	for family_id in review.get("affected_families", []):
		lines.append("• %s" % str(family_id))
	review_output.text = "\n".join(lines)


func _on_pack_selected(_index_value: int) -> void:
	_filter_families()


func _on_search_changed(_value: String) -> void:
	_filter_families()


func _on_family_selected(index_value: int) -> void:
	if index_value < 0 or index_value >= _visible_families.size():
		return
	_selected_family = (_visible_families[index_value] as Dictionary).duplicate(true)
	_populate_cards()


func _on_card_selected(index_value: int) -> void:
	if index_value < 0 or index_value >= card_list.item_count:
		return
	select_card(str(card_list.get_item_metadata(index_value)))


func _set_status(message: String) -> void:
	if status_label != null:
		status_label.text = message
