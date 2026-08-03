extends SceneTree

const MANIFEST_PATH := "res://docs/migration/v07_atomic_cutover_manifest.json"
const MAIN_SCENE := "res://scenes/main.tscn"
const RUNTIME_SCENE := "res://scenes/runtime/V073RuntimeComposition.tscn"
const PLAYER_SCENE := "res://scenes/ui/V073SampleGameScreen.tscn"
const RUNTIME_SCRIPT := "res://scripts/v073_runtime/v073_sample_runtime_owner.gd"
const BOOTSTRAP_SCRIPT := "res://scripts/v073_runtime/v073_sample_application_bootstrap.gd"
const ADAPTER_PATHS := [
	"res://scripts/v07_adapters/v07_canonical_data_codec.gd",
	"res://scripts/v07_adapters/v07_canonical_save_adapter.gd",
	"res://scripts/v07_adapters/v07_canonical_rng_adapter.gd",
	"res://scripts/v07_adapters/v07_canonical_ai_observation_adapter.gd",
	"res://scripts/v07_adapters/v07_canonical_player_projection_adapter.gd",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	if OS.get_cmdline_user_args().has("--parse-only"):
		print("V07_ADAPTER_ARCHITECTURE_CONTRACT_TEST | status=PARSE_ONLY_PASS")
		quit(0)
		return
	call_deferred("_run")


func _run() -> void:
	_test_adapter_purity()
	_test_manifest()
	_test_production_composition()
	_finish()


func _test_adapter_purity() -> void:
	for path in ADAPTER_PATHS:
		_expect(FileAccess.file_exists(path), "adapter exists: %s" % path)
		var script := load(path) as Script
		_expect(script != null, "adapter loads: %s" % path)
		if script != null:
			_expect(script.get_instance_base_type() == &"RefCounted", "adapter remains pure RefCounted: %s" % path)
		var source := FileAccess.get_file_as_string(path).to_lower()
		for token in ["extends node", "extends control", "get_tree(", "add_child(", "scripts/main.gd"]:
			_expect(not source.contains(token), "%s excludes production ownership token %s" % [path, token])


func _test_manifest() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	_expect(parsed is Dictionary, "atomic cutover manifest parses")
	if not parsed is Dictionary:
		return
	var manifest := parsed as Dictionary
	_expect(int(manifest.get("schema_version", 0)) == 5, "manifest schema is production v5")
	_expect(str(manifest.get("status", "")) == "V073_SAMPLE_PRODUCTION_CONNECTED", "manifest is production-connected")
	_expect(str(manifest.get("current_production_runtime_ruleset", "")) == "v0.7.3", "production ruleset is V0.7.3")
	_expect(bool(manifest.get("production_cutover_authorized", false)), "production cutover is authorized")
	_expect(int(manifest.get("domain_count", 0)) == 19, "manifest has nineteen domains")
	_expect(int(manifest.get("v073_production_connection_count", 0)) == 19, "all domains are connected")
	for field in [
		"v073_dual_write_count",
		"v073_legacy_fallback_count",
		"v073_mixed_ruleset_state_count",
		"v073_v06_runtime_mutation_count",
		"v06_save_file_delete_count",
		"v06_save_file_overwrite_count",
		"v073_v06_save_apply_count",
		"v073_save_dual_write_count",
	]:
		_expect(int(manifest.get(field, -1)) == 0, "%s is zero" % field)
	_expect(bool(manifest.get("new_game_only", false)), "sample is new-game-only")
	_expect(not bool(manifest.get("save_resume_enabled", true)), "Save/Continue is disabled")
	_expect(not bool(manifest.get("save_adapter_connected", true)), "Save adapter remains detached")


func _test_production_composition() -> void:
	for path in [MAIN_SCENE, RUNTIME_SCENE, PLAYER_SCENE, RUNTIME_SCRIPT, BOOTSTRAP_SCRIPT]:
		_expect(FileAccess.file_exists(path), "production composition path exists: %s" % path)
	var main_source := FileAccess.get_file_as_string(MAIN_SCENE)
	_expect(main_source.contains("V073RuntimeComposition.tscn"), "main connects V0.7.3 runtime composition")
	_expect(main_source.contains("V073SampleGameScreen.tscn"), "main connects V0.7.3 player surface")
	for token in [
		"scripts/main.gd",
		"GameRuntimeCoordinator",
		"V06SaveOwnerRegistry",
		"CommoditySushiTrack",
		"RegionSupply",
		"PublicBid",
		"AuctionTimer",
	]:
		_expect(not main_source.contains(token), "main excludes legacy production token %s" % token)
	var runtime_source := FileAccess.get_file_as_string(RUNTIME_SCRIPT)
	_expect(runtime_source.contains("v07_canonical_ai_observation_adapter.gd"), "runtime connects canonical AI adapter")
	_expect(runtime_source.contains("v07_canonical_player_projection_adapter.gd"), "runtime connects canonical player adapter")
	_expect(not runtime_source.contains("v07_canonical_save_adapter.gd"), "runtime does not connect Save adapter")
	_expect(not runtime_source.contains("scripts/main.gd"), "runtime has no Main dependency")
	var bootstrap_source := FileAccess.get_file_as_string(BOOTSTRAP_SCRIPT)
	_expect(bootstrap_source.count("\n") + 1 <= 120, "application bootstrap remains at most 120 lines")
	for token in ["DBG_CORE", "TRACK_CORE", "ASSET_BATCH_CORE", "FACILITY_CORE", "SOLAR_VICTORY_CORE"]:
		_expect(not bootstrap_source.contains(token), "bootstrap owns no gameplay domain token %s" % token)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	var passed := _failures.is_empty()
	print("V073_PRODUCTION_ADAPTER_ARCHITECTURE|status=%s|passed=%d|total=%d|details=%s" % [
		"PASS" if passed else "FAIL", _checks - _failures.size(), _checks, JSON.stringify(_failures)
	])
	print("V07_ADAPTER_ARCHITECTURE_CONTRACT_TEST | status=%s" % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
