extends Control
class_name SpaceSyndicateSceneizationAuditMcpPreview

const RegistryScript = preload("res://scripts/tools/sceneization_audit_registry.gd")

@onready var category_list: ItemList = %SceneizationAuditCategoryList
@onready var record_list: ItemList = %SceneizationAuditRecordList
@onready var detail_title_label: Label = %SceneizationAuditDetailTitle
@onready var detail_body_label: Label = %SceneizationAuditDetailBody
@onready var status_label: Label = %SceneizationAuditStatusLabel
@onready var summary_label: Label = %SceneizationAuditSummaryLabel

var _registry: RefCounted = RegistryScript.new()
var _statuses: Array[String] = []
var _visible_records: Array = []
var _selected_record: Dictionary = {}


func _ready() -> void:
	_connect_lists()
	refresh_audit()


func audit_records() -> Array:
	return _registry.call("records") if _registry != null else []


func audit_summary() -> Dictionary:
	var summary_variant: Variant = _registry.call("summary") if _registry != null else {}
	return summary_variant if summary_variant is Dictionary else {}


func selected_record() -> Dictionary:
	return _selected_record.duplicate(true)


func select_category(status: String) -> bool:
	for index in range(_statuses.size()):
		if _statuses[index] != status:
			continue
		if category_list != null:
			category_list.select(index)
		_show_status(status)
		_set_status("Audit status: %s" % status)
		return true
	return false


func select_record(id: String) -> bool:
	var records_variant: Variant = _registry.call("records") if _registry != null else []
	var records: Array = records_variant if records_variant is Array else []
	for record_variant in records:
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		if str(record.get("id", "")) != id:
			continue
		var status := str(record.get("sceneization_status", ""))
		select_category(status)
		for index in range(_visible_records.size()):
			var visible_record: Dictionary = _visible_records[index] if _visible_records[index] is Dictionary else {}
			if str(visible_record.get("id", "")) == id:
				if record_list != null:
					record_list.select(index)
				_select_record(visible_record)
				return true
	return false


func refresh_audit() -> void:
	if _registry == null:
		_set_status("Audit registry missing")
		return
	var statuses_variant: Variant = _registry.call("status_ids")
	_statuses.clear()
	if statuses_variant is Array:
		for status_variant in statuses_variant:
			_statuses.append(str(status_variant))
	_populate_statuses()
	_update_summary()
	if not _statuses.is_empty():
		if category_list != null:
			category_list.select(0)
		_show_status(_statuses[0])
	_set_status("Audit refreshed: %d records" % audit_records().size())


func _connect_lists() -> void:
	if category_list != null:
		var category_callback := Callable(self, "_on_category_selected")
		if not category_list.item_selected.is_connected(category_callback):
			category_list.item_selected.connect(category_callback)
	if record_list != null:
		var record_callback := Callable(self, "_on_record_selected")
		if not record_list.item_selected.is_connected(record_callback):
			record_list.item_selected.connect(record_callback)


func _populate_statuses() -> void:
	if category_list == null:
		return
	category_list.clear()
	for status in _statuses:
		category_list.add_item(_status_label(status))


func _show_status(status: String) -> void:
	_visible_records.clear()
	if record_list != null:
		record_list.clear()
	var records_variant: Variant = _registry.call("records_for_status", status) if _registry != null else []
	var records: Array = records_variant if records_variant is Array else []
	for record_variant in records:
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		_visible_records.append(record.duplicate(true))
		if record_list != null:
			record_list.add_item("%s  P%s" % [str(record.get("display_name", record.get("id", ""))), str(record.get("priority", "-"))])
	if not _visible_records.is_empty():
		if record_list != null:
			record_list.select(0)
		_select_record(_visible_records[0])
	else:
		_select_record({})


func _select_record(record: Dictionary) -> void:
	_selected_record = record.duplicate(true)
	if _selected_record.is_empty():
		if detail_title_label != null:
			detail_title_label.text = "No audit record"
		if detail_body_label != null:
			detail_body_label.text = ""
		return
	if detail_title_label != null:
		detail_title_label.text = str(_selected_record.get("display_name", _selected_record.get("id", "")))
	if detail_body_label != null:
		detail_body_label.text = "id: %s\nstatus: %s\ncategory: %s\nscene: %s\nscript: %s\nnext: %s\nrisk: %s\nmcp: %s" % [
			str(_selected_record.get("id", "")),
			str(_selected_record.get("sceneization_status", "")),
			str(_selected_record.get("category", "")),
			str(_selected_record.get("current_scene_path", "")),
			str(_selected_record.get("source_script_path", "")),
			str(_selected_record.get("next_step", "")),
			str(_selected_record.get("risk_notes", "")),
			str(_selected_record.get("mcp_notes", "")),
		]


func _update_summary() -> void:
	if summary_label == null:
		return
	var summary := audit_summary()
	var counts: Dictionary = summary.get("counts", {}) if summary.get("counts", {}) is Dictionary else {}
	summary_label.text = "Total %d | full %d | partial %d | legacy %d | draw %d" % [
		int(summary.get("total", 0)),
		int(counts.get("full", 0)),
		int(counts.get("partial", 0)),
		int(counts.get("legacy_runtime", 0)),
		int(counts.get("draw_script", 0)),
	]


func _status_label(status: String) -> String:
	match status:
		"full":
			return "Fully Sceneized"
		"partial":
			return "Partially Sceneized"
		"legacy_runtime":
			return "Legacy Runtime UI"
		"draw_script":
			return "Draw Script Surfaces"
	return status


func _on_category_selected(index: int) -> void:
	if index < 0 or index >= _statuses.size():
		return
	_show_status(_statuses[index])
	_set_status("Audit status: %s" % _statuses[index])


func _on_record_selected(index: int) -> void:
	if index < 0 or index >= _visible_records.size():
		return
	var record: Dictionary = _visible_records[index] if _visible_records[index] is Dictionary else {}
	_select_record(record)
	_set_status("Audit record: %s" % str(record.get("id", "")))


func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text
