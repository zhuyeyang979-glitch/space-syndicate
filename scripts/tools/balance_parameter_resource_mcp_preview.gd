extends Control
class_name BalanceParameterResourceMcpPreview

const RegistryScript := preload("res://scripts/balance/balance_parameter_resource_registry.gd")
const BENCH_SCENE_PATH := "res://scenes/tools/BalanceParameterResourceBench.tscn"

@onready var category_list: ItemList = %BalanceParameterResourceCategoryList
@onready var record_list: ItemList = %BalanceParameterResourceRecordList
@onready var title_label: Label = %BalanceParameterResourceDetailTitle
@onready var body_label: Label = %BalanceParameterResourceDetailBody
@onready var status_label: Label = %BalanceParameterResourceStatusLabel
@onready var summary_label: Label = %BalanceParameterResourceSummaryLabel
@onready var open_resource_button: Button = %BalanceParameterOpenResourceButton
@onready var print_payload_button: Button = %BalanceParameterPrintPayloadButton
@onready var run_bench_button: Button = %BalanceParameterRunBenchButton

var _registry := RegistryScript.new()
var _records: Array = []
var _selected_record: Dictionary = {}
var _selected_category := "Profile"


func _ready() -> void:
	refresh_resources()
	_connect_controls()


func resource_records() -> Array:
	return _duplicate_records(_registry.validation_records())


func resource_summary() -> Dictionary:
	return _registry.profile_summary()


func selected_record() -> Dictionary:
	return _selected_record.duplicate(true)


func select_category(category: String) -> bool:
	if not _registry.categories().has(category):
		return false
	_selected_category = category
	_populate_records()
	return true


func select_record(case_id: String) -> bool:
	for record_variant in _records:
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		if str(record.get("case_id", "")) == case_id:
			_select_record(record)
			return true
	return false


func refresh_resources() -> void:
	_records = _registry.validation_records()
	_populate_categories()
	_populate_records()
	_update_summary()


func open_current_resource() -> void:
	var path := str(_selected_record.get("resource_path", ""))
	print("BalanceParameterResource open resource: %s" % path)
	_set_status("Resource path: %s" % path)


func print_selected_payload() -> void:
	var case_id := str(_selected_record.get("case_id", ""))
	var payload := {}
	if case_id.begins_with("price_curve"):
		payload = _registry.price_curve_resource_payload()
	elif case_id.begins_with("runtime"):
		payload = _registry.runtime_resource_payload()
	else:
		payload = _registry.profile_summary()
	print("BalanceParameterResource payload %s: %s" % [case_id, JSON.stringify(payload)])
	_set_status("Printed payload for %s" % case_id)


func run_related_bench() -> void:
	print("BalanceParameterResource bench: %s" % BENCH_SCENE_PATH)
	_set_status("Bench scene: %s" % BENCH_SCENE_PATH)


func _connect_controls() -> void:
	if category_list != null and not category_list.item_selected.is_connected(_on_category_selected):
		category_list.item_selected.connect(_on_category_selected)
	if record_list != null and not record_list.item_selected.is_connected(_on_record_selected):
		record_list.item_selected.connect(_on_record_selected)
	_connect_button(open_resource_button, "open_current_resource")
	_connect_button(print_payload_button, "print_selected_payload")
	_connect_button(run_bench_button, "run_related_bench")


func _populate_categories() -> void:
	category_list.clear()
	var categories: Array[String] = _registry.categories()
	for category in categories:
		category_list.add_item(category)
	var selected_index := maxi(0, categories.find(_selected_category))
	if categories.size() > 0:
		category_list.select(selected_index)
		_selected_category = str(categories[selected_index])


func _populate_records() -> void:
	record_list.clear()
	var first_case_id := ""
	for record_variant in _records:
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		if str(record.get("category", "")) != _selected_category:
			continue
		var status := "PASS" if bool(record.get("passed", false)) else "FAIL"
		record_list.add_item("%s | %s" % [status, str(record.get("case_id", ""))])
		record_list.set_item_metadata(record_list.item_count - 1, str(record.get("case_id", "")))
		if first_case_id == "":
			first_case_id = str(record.get("case_id", ""))
	if first_case_id != "":
		record_list.select(0)
		select_record(first_case_id)


func _select_record(record: Dictionary) -> void:
	_selected_record = record.duplicate(true)
	title_label.text = "%s / %s" % [str(record.get("category", "")), str(record.get("case_id", ""))]
	body_label.text = "Resource: %s\nJSON: %s\nInspector visible: %s\nJSON parity: %s\nModel compatibility: %s\nPure data: %s\nPassed: %s\n\n%s" % [
		str(record.get("resource_path", "")),
		str(record.get("json_path", "")),
		str(record.get("inspector_visible", false)),
		str(record.get("json_parity_checked", false)),
		str(record.get("model_compatibility_checked", false)),
		str(record.get("pure_data_checked", false)),
		str(record.get("passed", false)),
		str(record.get("notes", "")),
	]
	_set_status("Selected %s" % str(record.get("case_id", "")))


func _update_summary() -> void:
	var passed := 0
	for record_variant in _records:
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		if bool(record.get("passed", false)):
			passed += 1
	var summary := _registry.profile_summary()
	summary_label.text = "Balance Parameter Resources: %d/%d passed | start $%d | price types %d | weights %d" % [
		passed,
		_records.size(),
		int(summary.get("starting_cash", 0)),
		int(summary.get("price_type_count", 0)),
		int(summary.get("price_weight_count", 0)),
	]


func _connect_button(button: Button, method_name: String) -> void:
	if button == null:
		return
	var callable := Callable(self, method_name)
	if not button.pressed.is_connected(callable):
		button.pressed.connect(callable)


func _on_category_selected(index: int) -> void:
	if index < 0 or index >= category_list.item_count:
		return
	select_category(category_list.get_item_text(index))


func _on_record_selected(index: int) -> void:
	if index < 0 or index >= record_list.item_count:
		return
	select_record(str(record_list.get_item_metadata(index)))


func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text


func _duplicate_records(source: Array) -> Array:
	var result: Array = []
	for record_variant in source:
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		result.append(record.duplicate(true))
	return result
