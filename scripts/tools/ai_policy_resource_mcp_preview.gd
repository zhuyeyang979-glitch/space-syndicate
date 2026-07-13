extends Control
class_name AiPolicyResourceMcpPreview

const RegistryScript := preload("res://scripts/ai/ai_policy_resource_registry.gd")
const BENCH_SCENE_PATH := "res://scenes/tools/AiPolicyResourceBench.tscn"

@onready var category_list: ItemList = %AiPolicyResourceCategoryList
@onready var record_list: ItemList = %AiPolicyResourceRecordList
@onready var title_label: Label = %AiPolicyResourceDetailTitle
@onready var body_label: Label = %AiPolicyResourceDetailBody
@onready var status_label: Label = %AiPolicyResourceStatusLabel
@onready var summary_label: Label = %AiPolicyResourceSummaryLabel
@onready var runtime_owner_label: Label = %AiPolicyRuntimeOwnerLabel
@onready var open_resource_button: Button = %AiPolicyOpenResourceButton
@onready var print_payload_button: Button = %AiPolicyPrintPayloadButton
@onready var run_bench_button: Button = %AiPolicyRunBenchButton

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
			var category := str(record.get("category", ""))
			if category != "" and category != _selected_category:
				_selected_category = category
				_select_category_item(category)
				_populate_records()
			_select_record(record)
			_select_record_item(case_id)
			return true
	return false


func refresh_resources() -> void:
	_records = _registry.validation_records()
	_populate_categories()
	_populate_records()
	_update_summary()


func open_current_resource() -> void:
	var path := str(_selected_record.get("resource_path", _registry.PROFILE_RESOURCE_PATH))
	print("AiPolicyResource open resource: %s" % path)
	_set_status("Resource path: %s" % path)


func print_selected_payload() -> void:
	var payload := _registry.policy_resource_payload()
	print("AiPolicyResource payload: %s" % JSON.stringify(payload))
	_set_status("Printed Inspector policy payload")


func run_related_bench() -> void:
	print("AiPolicyResource bench: %s" % BENCH_SCENE_PATH)
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
	if not categories.is_empty():
		category_list.select(selected_index)
		_selected_category = categories[selected_index]


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


func _select_category_item(category: String) -> void:
	for index in category_list.item_count:
		if category_list.get_item_text(index) == category:
			category_list.select(index)
			category_list.ensure_current_is_visible()
			return


func _select_record_item(case_id: String) -> void:
	for index in record_list.item_count:
		if str(record_list.get_item_metadata(index)) == case_id:
			record_list.select(index)
			record_list.ensure_current_is_visible()
			return


func _select_record(record: Dictionary) -> void:
	_selected_record = record.duplicate(true)
	title_label.text = "%s / %s" % [str(record.get("category", "")), str(record.get("case_id", ""))]
	body_label.text = "Resource: %s\nRuntime source: %s\nInspector visible: %s\nRuntime parity: %s\nPersonality parity: %s\nRuntime owner checked: %s\nPure data: %s\nPassed: %s\n\n%s" % [
		str(record.get("resource_path", "")),
		str(record.get("source_path", "")),
		str(record.get("inspector_visible", false)),
		str(record.get("main_parity_checked", false)),
		str(record.get("personality_checked", false)),
		str(record.get("runtime_owner_checked", false)),
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
	summary_label.text = "AI Policy Resources: %d/%d passed | %d tunables | %d personalities | %d groups" % [
		passed,
		_records.size(),
		int(summary.get("tunable_count", 0)),
		int(summary.get("personality_count", 0)),
		int(summary.get("group_count", 0)),
	]
	runtime_owner_label.text = "Runtime owner: %s | Resource cutover: %s" % [
		str(summary.get("runtime_owner_script", "")),
		"ENABLED" if bool(summary.get("runtime_cutover_enabled", false)) else "disabled (QA / Inspector only)",
	]


func _connect_button(button: Button, method_name: String) -> void:
	if button == null:
		return
	var callback := Callable(self, method_name)
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)


func _on_category_selected(index: int) -> void:
	if index >= 0 and index < category_list.item_count:
		select_category(category_list.get_item_text(index))


func _on_record_selected(index: int) -> void:
	if index >= 0 and index < record_list.item_count:
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
