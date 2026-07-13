extends Control
class_name BalanceModelResourceSandbox

const AdapterScript := preload("res://scripts/balance/balance_parameter_model_adapter.gd")
const CasesScript := preload("res://scripts/tools/balance_model_resource_sandbox_cases.gd")
const BENCH_SCENE_PATH := "res://scenes/tools/BalanceModelResourceSandboxBench.tscn"

@onready var case_list: ItemList = %BalanceSandboxCaseList
@onready var resource_summary_label: Label = %BalanceSandboxResourceSummaryLabel
@onready var json_source_label: Label = %BalanceSandboxJsonSourceLabel
@onready var input_body_label: Label = %BalanceSandboxInputBody
@onready var runtime_output_label: Label = %BalanceSandboxRuntimeOutputBody
@onready var resource_output_label: Label = %BalanceSandboxResourceOutputBody
@onready var parity_body_label: Label = %BalanceSandboxParityBody
@onready var status_label: Label = %BalanceSandboxStatusLabel
@onready var print_case_button: Button = %BalanceSandboxPrintCaseButton
@onready var print_record_button: Button = %BalanceSandboxPrintRecordButton
@onready var run_bench_button: Button = %BalanceSandboxRunBenchButton

var _adapter: RefCounted = AdapterScript.new()
var _cases_source: RefCounted = CasesScript.new()
var _cases: Array = []
var _current_case_id := ""
var _current_record: Dictionary = {}


func _ready() -> void:
	var cases_variant: Variant = _cases_source.call("cases")
	_cases = cases_variant if cases_variant is Array else []
	_connect_controls()
	_populate_cases()
	if not _cases.is_empty():
		var first_case: Dictionary = _cases[0] if _cases[0] is Dictionary else {}
		apply_case(str(first_case.get("case_id", "")))


func sandbox_cases() -> Array:
	return _duplicate_array(_cases)


func current_case_id() -> String:
	return _current_case_id


func current_record() -> Dictionary:
	return _current_record.duplicate(true)


func sandbox_summary() -> Dictionary:
	var runtime_targets: Dictionary = _adapter.call("runtime_targets")
	var price_curve: Dictionary = _adapter.call("price_curve")
	var base_by_type: Dictionary = price_curve.get("base_by_type", {}) if price_curve.get("base_by_type", {}) is Dictionary else {}
	var weights: Dictionary = price_curve.get("weights", {}) if price_curve.get("weights", {}) is Dictionary else {}
	return {
		"profile_resource": "res://resources/balance/balance_parameter_profile_v1.tres",
		"runtime_json": "res://data/balance/runtime_balance_targets.json",
		"price_curve_json": "res://data/balance/price_curve_v1.json",
		"runtime_version": str(runtime_targets.get("version", "")),
		"starting_cash": int(runtime_targets.get("starting_cash", 0)),
		"city_build_cost": int(runtime_targets.get("city_build_cost", 0)),
		"price_type_count": base_by_type.size(),
		"price_weight_count": weights.size(),
	}


func apply_case(case_id: String) -> bool:
	var case_variant: Variant = _cases_source.call("case", case_id)
	var case_data: Dictionary = case_variant if case_variant is Dictionary else {}
	if case_data.is_empty():
		return false
	_current_case_id = case_id
	var record_variant: Variant = _adapter.call("sample_outputs_for_case", case_data)
	_current_record = record_variant if record_variant is Dictionary else {}
	_render_case(case_data, _current_record)
	_select_case_button(case_id)
	return not _current_record.is_empty()


func print_current_case() -> void:
	var case_variant: Variant = _cases_source.call("case", _current_case_id)
	var case_data: Dictionary = case_variant if case_variant is Dictionary else {}
	print("BalanceModelResourceSandbox case %s: %s" % [_current_case_id, JSON.stringify(case_data)])
	_set_status("Printed case: %s" % _current_case_id)


func print_current_record() -> void:
	print("BalanceModelResourceSandbox record %s: %s" % [_current_case_id, JSON.stringify(_current_record)])
	_set_status("Printed record: %s" % _current_case_id)


func print_bench_path() -> void:
	print("BalanceModelResourceSandbox bench: %s" % BENCH_SCENE_PATH)
	_set_status("Bench scene: %s" % BENCH_SCENE_PATH)


func _connect_controls() -> void:
	if case_list != null and not case_list.item_selected.is_connected(_on_case_selected):
		case_list.item_selected.connect(_on_case_selected)
	_connect_button(print_case_button, "print_current_case")
	_connect_button(print_record_button, "print_current_record")
	_connect_button(run_bench_button, "print_bench_path")


func _populate_cases() -> void:
	case_list.clear()
	for case_variant in _cases:
		var case_data: Dictionary = case_variant if case_variant is Dictionary else {}
		case_list.add_item("%s | %s" % [str(case_data.get("category", "")), str(case_data.get("case_id", ""))])
		case_list.set_item_metadata(case_list.item_count - 1, str(case_data.get("case_id", "")))


func _render_case(case_data: Dictionary, record: Dictionary) -> void:
	var summary: Dictionary = sandbox_summary()
	var model_paths_variant: Variant = _adapter.call("model_script_paths")
	var model_paths: Array = model_paths_variant if model_paths_variant is Array else []
	resource_summary_label.text = "Profile: %s\nRuntime: %s | starting cash $%d | city build $%d\nPrice curve: %d types / %d weights" % [
		str(summary.get("profile_resource", "")),
		str(summary.get("runtime_version", "")),
		int(summary.get("starting_cash", 0)),
		int(summary.get("city_build_cost", 0)),
		int(summary.get("price_type_count", 0)),
		int(summary.get("price_weight_count", 0)),
	]
	json_source_label.text = "JSON anchors:\n%s\n%s\nModel scripts:\n%s" % [
		str(summary.get("runtime_json", "")),
		str(summary.get("price_curve_json", "")),
		"\n".join(model_paths),
	]
	input_body_label.text = JSON.stringify(case_data.get("input", {}), "\t")
	runtime_output_label.text = JSON.stringify(record.get("runtime_model_output", {}), "\t")
	resource_output_label.text = JSON.stringify(record.get("resource_profile_output", {}), "\t")
	parity_body_label.text = "case: %s\ncategory: %s\ninput=%s runtime=%s resource=%s json=%s parity=%s passed=%s\n%s" % [
		str(record.get("case_id", "")),
		str(record.get("category", "")),
		str(record.get("input_checked", false)),
		str(record.get("runtime_model_checked", false)),
		str(record.get("resource_profile_checked", false)),
		str(record.get("json_anchor_checked", false)),
		str(record.get("parity_checked", false)),
		str(record.get("passed", false)),
		str(record.get("notes", "")),
	]
	_set_status("Selected %s | passed=%s" % [str(record.get("case_id", "")), str(record.get("passed", false))])


func _select_case_button(case_id: String) -> void:
	for index in case_list.item_count:
		if str(case_list.get_item_metadata(index)) == case_id:
			case_list.select(index)
			return


func _connect_button(button: Button, method_name: String) -> void:
	if button == null:
		return
	var callback := Callable(self, method_name)
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)


func _on_case_selected(index: int) -> void:
	if index < 0 or index >= case_list.item_count:
		return
	apply_case(str(case_list.get_item_metadata(index)))


func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text


func _duplicate_array(source: Array) -> Array:
	var result: Array = []
	for value in source:
		if value is Dictionary:
			result.append((value as Dictionary).duplicate(true))
		elif value is Array:
			result.append(_duplicate_array(value))
		else:
			result.append(value)
	return result
