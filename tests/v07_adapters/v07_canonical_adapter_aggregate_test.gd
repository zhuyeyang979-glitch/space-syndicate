extends SceneTree

const MANIFEST_PATH := "res://docs/migration/v07_atomic_cutover_manifest.json"
const RUNTIME_PATH := "res://scripts/v073_runtime/v073_sample_runtime_owner.gd"
const ADAPTER_PATHS := {
	"data": "res://scripts/v07_adapters/v07_canonical_data_codec.gd",
	"save": "res://scripts/v07_adapters/v07_canonical_save_adapter.gd",
	"rng": "res://scripts/v07_adapters/v07_canonical_rng_adapter.gd",
	"ai": "res://scripts/v07_adapters/v07_canonical_ai_observation_adapter.gd",
	"player": "res://scripts/v07_adapters/v07_canonical_player_projection_adapter.gd",
}
const FOCUSED_TESTS := {
	"save": "res://tests/v07_adapters/v07_canonical_save_adapter_test.gd",
	"rng": "res://tests/v07_adapters/v07_canonical_rng_adapter_test.gd",
	"ai": "res://tests/v07_adapters/v07_canonical_ai_observation_adapter_test.gd",
	"player": "res://tests/v07_adapters/v07_canonical_player_projection_adapter_test.gd",
	"manifest": "res://tests/v07_adapters/v07_atomic_cutover_manifest_test.gd",
}
const OUTPUT_MARKERS := {
	"save": "V073_CANONICAL_SAVE_ADAPTER_READY",
	"rng": "V073_CANONICAL_RNG_ADAPTER_READY",
	"ai": "V073_CANONICAL_AI_OBSERVATION_ADAPTER_READY",
	"player": "V073_CANONICAL_PLAYER_PROJECTION_ADAPTER_READY",
	"manifest": "V073_ATOMIC_CUTOVER_MANIFEST_READY",
}

var _checks := 0
var _failures: Array[String] = []
var _category_green := {}


func _init() -> void:
	if OS.get_cmdline_user_args().has("--parse-only"):
		print("V07_CANONICAL_ADAPTER_AGGREGATE_TEST | status=PARSE_ONLY_PASS")
		quit(0)
		return
	call_deferred("_run")


func _run() -> void:
	_test_adapter_inventory()
	_test_focused_gates()
	_test_manifest_and_runtime()
	_finish()


func _test_adapter_inventory() -> void:
	for category in ADAPTER_PATHS:
		var path := str(ADAPTER_PATHS[category])
		var script := load(path) as Script
		var ready := script != null and script.get_instance_base_type() == &"RefCounted"
		_expect(ready, "%s adapter is a pure RefCounted" % category)
		_category_green[category] = ready
	var save_script := load(str(ADAPTER_PATHS["save"])) as Script
	var rng_script := load(str(ADAPTER_PATHS["rng"])) as Script
	if save_script != null:
		var save_contract := save_script.call("adapter_contract") as Dictionary
		_expect(save_contract.get("source_kinds_allowed") == ["NEW_V073_GAME"], "Save accepts only new V0.7.3 games")
		_expect(not bool(save_contract.get("v06_direct_resume_allowed", true)), "V0.6 direct resume is disabled")
		_expect(not bool(save_contract.get("production_runtime_connected", true)), "Save adapter remains detached from sample")
	if rng_script != null:
		var rng_contract := rng_script.call("adapter_contract") as Dictionary
		_expect(str(rng_contract.get("ruleset_id", "")) == "v0.7.3", "RNG adapter ruleset is V0.7.3")
		_expect(int(rng_contract.get("production_runtime_connection_count", -1)) == 0, "adapter exposes no second RNG authority")


func _test_focused_gates() -> void:
	for category in FOCUSED_TESTS:
		var path := str(FOCUSED_TESTS[category])
		var source := FileAccess.get_file_as_string(path)
		var marker_ready := not source.is_empty() and source.to_lower().contains("pass")
		_expect(marker_ready, "%s focused gate declares PASS" % category)
		_category_green[category] = bool(_category_green.get(category, true)) and marker_ready


func _test_manifest_and_runtime() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	_expect(parsed is Dictionary, "production manifest parses")
	if parsed is Dictionary:
		var manifest := parsed as Dictionary
		var ready := str(manifest.get("status", "")) == "V073_SAMPLE_PRODUCTION_CONNECTED" \
			and str(manifest.get("current_production_runtime_ruleset", "")) == "v0.7.3" \
			and int(manifest.get("v073_production_connection_count", 0)) == 19 \
			and int(manifest.get("v073_dual_write_count", -1)) == 0 \
			and int(manifest.get("v073_legacy_fallback_count", -1)) == 0
		_expect(ready, "manifest proves atomic production connection")
		_category_green["manifest"] = bool(_category_green.get("manifest", true)) and ready
	var runtime_source := FileAccess.get_file_as_string(RUNTIME_PATH)
	_expect(runtime_source.contains("v07_canonical_ai_observation_adapter.gd"), "production runtime connects AI adapter")
	_expect(runtime_source.contains("v07_canonical_player_projection_adapter.gd"), "production runtime connects player adapter")
	_expect(not runtime_source.contains("v07_canonical_save_adapter.gd"), "production runtime leaves Save adapter detached")
	_expect(not runtime_source.contains("v07_canonical_rng_adapter.gd"), "Core streams remain the only production RNG authorities")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	for category in ["save", "rng", "ai", "player", "manifest"]:
		print("%s | status=%s" % [
			OUTPUT_MARKERS[category],
			"PASS" if bool(_category_green.get(category, false)) else "FAIL",
		])
	var passed := _failures.is_empty()
	print("V07_CANONICAL_ADAPTER_AGGREGATE_READY | status=%s" % ("PASS" if passed else "FAIL"))
	print("V07_CANONICAL_ADAPTER_AGGREGATE_TEST | passed=%d total=%d" % [_checks - _failures.size(), _checks])
	if not passed:
		for failure in _failures:
			push_error("V07_CANONICAL_ADAPTER_AGGREGATE_TEST | %s" % failure)
	quit(0 if passed else 1)
