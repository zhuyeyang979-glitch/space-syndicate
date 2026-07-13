extends Control
class_name SystemResourceizationAuditMcpPreview

const RegistryScript := preload("res://scripts/tools/system_resourceization_audit_registry.gd")

@onready var category_list: ItemList = %SystemResourceizationCategoryList
@onready var record_list: ItemList = %SystemResourceizationRecordList
@onready var detail_title_label: Label = %SystemResourceizationDetailTitle
@onready var detail_body_label: Label = %SystemResourceizationDetailBody
@onready var status_label: Label = %SystemResourceizationStatusLabel
@onready var summary_label: Label = %SystemResourceizationSummaryLabel
@onready var open_current_button: Button = %SystemResourceizationOpenCurrentButton
@onready var run_related_button: Button = %SystemResourceizationRunRelatedBenchButton
@onready var print_record_button: Button = %SystemResourceizationPrintRecordButton
@onready var open_gate_button: Button = %SystemResourceizationOpenExistingGateButton

var _registry: RefCounted = RegistryScript.new()
var _categories: Array[String] = []
var _visible_records: Array = []
var _selected_record: Dictionary = {}


func _ready() -> void:
	_connect_controls()
	refresh_audit()


func audit_records() -> Array:
	return _registry.call("records") if _registry != null else []


func audit_summary() -> Dictionary:
	var summary_variant: Variant = _registry.call("summary") if _registry != null else {}
	return summary_variant if summary_variant is Dictionary else {}


func selected_record() -> Dictionary:
	return _selected_record.duplicate(true)


func select_category(category: String) -> bool:
	for index in range(_categories.size()):
		if _categories[index] != category:
			continue
		if category_list != null:
			category_list.select(index)
		_show_category(category)
		_set_status("System audit category: %s" % category)
		return true
	return false


func select_record(id: String) -> bool:
	var records_variant: Variant = _registry.call("records") if _registry != null else []
	var records: Array = records_variant if records_variant is Array else []
	for record_variant in records:
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		if str(record.get("id", "")) != id:
			continue
		var category := str(record.get("category", ""))
		select_category(category)
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
		_set_status("System audit registry missing")
		return
	var categories_variant: Variant = _registry.call("categories")
	_categories.clear()
	if categories_variant is Array:
		for category_variant in categories_variant:
			_categories.append(str(category_variant))
	_populate_categories()
	_update_summary()
	if not _categories.is_empty():
		if category_list != null:
			category_list.select(0)
		_show_category(_categories[0])
	_set_status("System audit refreshed: %d records" % audit_records().size())


func print_selected_record() -> void:
	print("SystemResourceizationAudit selected: %s" % JSON.stringify(_selected_record))
	_set_status("Printed audit record: %s" % str(_selected_record.get("id", "")))


func open_current_reference() -> void:
	var path := str(_selected_record.get("current_path", ""))
	print("SystemResourceizationAudit open current reference: %s" % path)
	_set_status("Current reference: %s" % path)


func run_related_bench() -> void:
	print("SystemResourceizationAudit related bench: res://scenes/tools/SystemResourceizationAuditBench.tscn")
	_set_status("Related bench: res://scenes/tools/SystemResourceizationAuditBench.tscn")


func open_existing_gate() -> void:
	var id := str(_selected_record.get("id", ""))
	var gate_path := "res://scenes/tools/SceneizationAuditMcpPreview.tscn"
	if id.contains("compendium"):
		gate_path = "res://scenes/tools/CompendiumContentRegistryBench.tscn"
	print("SystemResourceizationAudit existing gate: %s" % gate_path)
	_set_status("Existing gate: %s" % gate_path)


func _connect_controls() -> void:
	if category_list != null:
		var category_callback := Callable(self, "_on_category_selected")
		if not category_list.item_selected.is_connected(category_callback):
			category_list.item_selected.connect(category_callback)
	if record_list != null:
		var record_callback := Callable(self, "_on_record_selected")
		if not record_list.item_selected.is_connected(record_callback):
			record_list.item_selected.connect(record_callback)
	_connect_button(open_current_button, "open_current_reference")
	_connect_button(run_related_button, "run_related_bench")
	_connect_button(print_record_button, "print_selected_record")
	_connect_button(open_gate_button, "open_existing_gate")


func _populate_categories() -> void:
	if category_list == null:
		return
	category_list.clear()
	for category in _categories:
		category_list.add_item(category)


func _show_category(category: String) -> void:
	_visible_records.clear()
	if record_list != null:
		record_list.clear()
	var records_variant: Variant = _registry.call("records_for_category", category) if _registry != null else []
	var records: Array = records_variant if records_variant is Array else []
	for record_variant in records:
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		_visible_records.append(record.duplicate(true))
		if record_list != null:
			record_list.add_item("%s | %s" % [str(record.get("display_name", record.get("id", ""))), str(record.get("current_status", ""))])
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
			detail_title_label.text = "No system audit record"
		if detail_body_label != null:
			detail_body_label.text = ""
		return
	if detail_title_label != null:
		detail_title_label.text = str(_selected_record.get("display_name", _selected_record.get("id", "")))
	if detail_body_label != null:
		var functions_text := ", ".join(_string_array(_selected_record.get("key_functions", [])))
		var related_text := "\n".join(_string_array(_selected_record.get("related_paths", [])))
		detail_body_label.text = "id: %s\ncategory: %s\nstatus: %s\npath: %s\neditor: %s\nrisk: %s\nfunctions: %s\nrelated:\n%s\n\nnext: %s\nmcp: %s" % [
			str(_selected_record.get("id", "")),
			str(_selected_record.get("category", "")),
			str(_selected_record.get("current_status", "")),
			str(_selected_record.get("current_path", "")),
			str(_selected_record.get("editor_visibility", "")),
			str(_selected_record.get("risk_level", "")),
			functions_text,
			related_text,
			str(_selected_record.get("recommended_next_step", "")),
			str(_selected_record.get("mcp_notes", "")),
		]


func _update_summary() -> void:
	if summary_label == null:
		return
	var summary := audit_summary()
	var categories: Dictionary = summary.get("categories", {}) if summary.get("categories", {}) is Dictionary else {}
	var statuses: Dictionary = summary.get("statuses", {}) if summary.get("statuses", {}) is Dictionary else {}
	summary_label.text = "Total %d | Menu %d | Balance %d | AI %d | main.gd %d | Resource candidates %d" % [
		int(summary.get("total", 0)),
		int(categories.get("Main Menu", 0)),
		int(categories.get("Balance / Gradient", 0)),
		int(categories.get("AI / Monster AI", 0)),
		int(statuses.get("main_gd_runtime", 0)),
		int(statuses.get("candidate_resource", 0)),
	]


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result


func _connect_button(button: Button, method_name: String) -> void:
	if button == null:
		return
	var callback := Callable(self, method_name)
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)


func _on_category_selected(index: int) -> void:
	if index < 0 or index >= _categories.size():
		return
	_show_category(_categories[index])
	_set_status("System audit category: %s" % _categories[index])


func _on_record_selected(index: int) -> void:
	if index < 0 or index >= _visible_records.size():
		return
	var record: Dictionary = _visible_records[index] if _visible_records[index] is Dictionary else {}
	_select_record(record)
	_set_status("System audit record: %s" % str(record.get("id", "")))


func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text
