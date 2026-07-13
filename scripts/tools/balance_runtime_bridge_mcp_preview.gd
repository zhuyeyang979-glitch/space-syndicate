extends Control
class_name BalanceRuntimeBridgeMcpPreview

const BridgeScript := preload("res://scripts/balance/balance_runtime_parameter_bridge.gd")
const BENCH_SCENE_PATH := "res://scenes/tools/BalanceRuntimeBridgeBench.tscn"

@onready var status_label: Label = %BalanceRuntimeBridgeStatusLabel
@onready var summary_label: Label = %BalanceRuntimeBridgeSummaryLabel
@onready var default_runtime_label: Label = %BalanceRuntimeBridgeDefaultRuntimeLabel
@onready var json_runtime_label: Label = %BalanceRuntimeBridgeJsonRuntimeTargetsLabel
@onready var resource_runtime_label: Label = %BalanceRuntimeBridgeResourceRuntimeTargetsLabel
@onready var json_price_label: Label = %BalanceRuntimeBridgeJsonPriceCurveLabel
@onready var resource_price_label: Label = %BalanceRuntimeBridgeResourcePriceCurveLabel
@onready var parity_label: Label = %BalanceRuntimeBridgeParityBody
@onready var dry_run_label: Label = %BalanceRuntimeBridgeDryRunSampleLabel
@onready var json_mode_button: Button = %BalanceRuntimeBridgeJsonModeButton
@onready var resource_mode_button: Button = %BalanceRuntimeBridgeResourceModeButton
@onready var auto_safe_mode_button: Button = %BalanceRuntimeBridgeAutoSafeModeButton
@onready var print_summary_button: Button = %BalanceRuntimeBridgePrintSummaryButton
@onready var run_bench_button: Button = %BalanceRuntimeBridgeRunBenchButton

var _bridge: RefCounted = BridgeScript.new()
var _selected_source_mode := "json_current"
var _comparison: Dictionary = {}


func _ready() -> void:
	_connect_controls()
	apply_source_mode(_selected_source_mode)


func source_modes() -> Array[String]:
	var modes_variant: Variant = _bridge.call("source_modes")
	var result: Array[String] = []
	if modes_variant is Array:
		for mode_variant in modes_variant:
			result.append(str(mode_variant))
	return result


func selected_source_mode() -> String:
	return _selected_source_mode


func current_comparison() -> Dictionary:
	return _comparison.duplicate(true)


func bridge_summary() -> Dictionary:
	var summary_variant: Variant = _bridge.call("bridge_summary", _selected_source_mode)
	return summary_variant if summary_variant is Dictionary else {}


func apply_source_mode(source_mode: String) -> bool:
	if not source_modes().has(source_mode):
		return false
	_selected_source_mode = source_mode
	var comparison_variant: Variant = _bridge.call("compare_sources")
	_comparison = comparison_variant if comparison_variant is Dictionary else {}
	_render()
	return true


func print_current_summary() -> void:
	print("BalanceRuntimeBridge summary %s: %s" % [_selected_source_mode, JSON.stringify(bridge_summary())])
	_set_status("Printed bridge summary for %s" % _selected_source_mode)


func print_bench_path() -> void:
	print("BalanceRuntimeBridge bench: %s" % BENCH_SCENE_PATH)
	_set_status("Bench scene: %s" % BENCH_SCENE_PATH)


func _connect_controls() -> void:
	_connect_button(json_mode_button, "_on_json_mode_pressed")
	_connect_button(resource_mode_button, "_on_resource_mode_pressed")
	_connect_button(auto_safe_mode_button, "_on_auto_safe_mode_pressed")
	_connect_button(print_summary_button, "print_current_summary")
	_connect_button(run_bench_button, "print_bench_path")


func _render() -> void:
	var summary: Dictionary = bridge_summary()
	var runtime_summary: Dictionary = summary.get("runtime_summary", {}) if summary.get("runtime_summary", {}) is Dictionary else {}
	var price_summary: Dictionary = summary.get("price_curve_summary", {}) if summary.get("price_curve_summary", {}) is Dictionary else {}
	var json_runtime_summary: Dictionary = _comparison.get("json_runtime_summary", {}) if _comparison.get("json_runtime_summary", {}) is Dictionary else {}
	var resource_runtime_summary: Dictionary = _comparison.get("resource_runtime_summary", {}) if _comparison.get("resource_runtime_summary", {}) is Dictionary else {}
	var json_price_summary: Dictionary = _comparison.get("json_price_curve_summary", {}) if _comparison.get("json_price_curve_summary", {}) is Dictionary else {}
	var resource_price_summary: Dictionary = _comparison.get("resource_price_curve_summary", {}) if _comparison.get("resource_price_curve_summary", {}) is Dictionary else {}
	summary_label.text = "Selected source: %s | Runtime start $%d | Price types %d | Default remains %s" % [
		_selected_source_mode,
		int(runtime_summary.get("starting_cash", 0)),
		int(price_summary.get("base_type_count", 0)),
		str(summary.get("default_source_mode", "")),
	]
	default_runtime_label.text = "Runtime default: %s | json_current_is_default=%s | Resource mode is explicit QA/dev only." % [
		str(_comparison.get("default_source_mode", "")),
		str(_comparison.get("json_current_is_default", false)),
	]
	json_runtime_label.text = "JSON Runtime Targets\n%s" % JSON.stringify(json_runtime_summary, "\t")
	resource_runtime_label.text = "Resource Runtime Targets\n%s" % JSON.stringify(resource_runtime_summary, "\t")
	json_price_label.text = "JSON Price Curve\n%s" % JSON.stringify(json_price_summary, "\t")
	resource_price_label.text = "Resource Price Curve\n%s" % JSON.stringify(resource_price_summary, "\t")
	parity_label.text = "runtime_targets_parity=%s\nprice_curve_parity=%s\nall_parity=%s\npure_data_checked=%s\nauto_safe runtime=%s price_curve=%s" % [
		str(_comparison.get("runtime_targets_parity", false)),
		str(_comparison.get("price_curve_parity", false)),
		str(_comparison.get("all_parity", false)),
		str(_comparison.get("pure_data_checked", false)),
		str(_comparison.get("auto_safe_runtime_source", "")),
		str(_comparison.get("auto_safe_price_curve_source", "")),
	]
	dry_run_label.text = "Dry-run sample\nmode=%s\nruntime=%s\nprice_curve=%s" % [
		_selected_source_mode,
		JSON.stringify(runtime_summary, "\t"),
		JSON.stringify(price_summary, "\t"),
	]
	_set_status("Balance Runtime Bridge selected %s | all_parity=%s" % [_selected_source_mode, str(_comparison.get("all_parity", false))])


func _connect_button(button: Button, method_name: String) -> void:
	if button == null:
		return
	var callback := Callable(self, method_name)
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)


func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text


func _on_json_mode_pressed() -> void:
	apply_source_mode("json_current")


func _on_resource_mode_pressed() -> void:
	apply_source_mode("resource_profile")


func _on_auto_safe_mode_pressed() -> void:
	apply_source_mode("auto_safe")
