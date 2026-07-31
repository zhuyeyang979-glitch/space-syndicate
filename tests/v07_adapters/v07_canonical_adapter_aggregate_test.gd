extends SceneTree

const ADAPTER_ROOT := "res://scripts/v07_adapters"
const TEST_ROOT := "res://tests/v07_adapters"
const BASELINE_REVISION := "2e38764791cb37cdc45b2eb0836957f550822dd5"
const MANIFEST_SEARCH_ROOTS := [
	ADAPTER_ROOT,
	"res://docs/migration",
	"res://docs/save",
	"res://docs/semantic",
]
const READINESS_ORDER := ["save", "rng", "ai", "player", "manifest"]
const READINESS_OUTPUT_MARKERS := {
	"save": "V07_CANONICAL_SAVE_ADAPTER_READY",
	"rng": "V07_CANONICAL_RNG_ADAPTER_READY",
	"ai": "V07_CANONICAL_AI_OBSERVATION_ADAPTER_READY",
	"player": "V07_CANONICAL_PLAYER_PROJECTION_ADAPTER_READY",
	"manifest": "V07_ATOMIC_CUTOVER_MANIFEST_READY",
}
const GAMEPLAY_DOMAIN_IDS := [
	"unified_card_track",
	"normal_dbg_deck",
	"normal_card_merge",
	"commodity_inventory_merge",
	"six_color_assets",
	"card_batch",
	"asset_reservation",
	"anonymous_resolution",
	"solar_efficiency",
	"macro_round_victory_gate",
]
const GAMEPLAY_DOMAIN_FIELDS := [
	"domain_id",
	"v06_current_owner",
	"v07_target_owner",
	"core_port",
	"ai_port",
	"player_port",
	"save_adapter",
	"rng_stream",
	"pre_cutover_gate",
	"cutover_step",
	"rollback_step",
	"old_path_deletion_gate",
	"production_scene_change",
	"main_change",
	"dual_write_allowed",
]

var _checks := 0
var _failures: Array[String] = []
var _marker_results: Dictionary = {}


func _init() -> void:
	if OS.get_cmdline_user_args().has("--parse-only"):
		print("V07_CANONICAL_ADAPTER_AGGREGATE_TEST | status=PARSE_ONLY_PASS")
		quit(0)
		return
	call_deferred("_run")


func _run() -> void:
	var adapter_scripts := _discover_adapter_scripts()
	var manifest_paths := _discover_manifest_paths()
	_expect(not adapter_scripts.is_empty(),
		"aggregate discovers scripts/v07_adapters implementations")
	_expect(manifest_paths.size() == 1,
		"aggregate discovers exactly one V0.7 adapter manifest")

	var manifest: Dictionary = {}
	if manifest_paths.size() == 1:
		manifest = _load_manifest(manifest_paths[0])
	if not manifest.is_empty():
		_test_manifest_inventory(manifest, adapter_scripts)

	for category in READINESS_ORDER:
		var focused_marker_ready := _focused_gate_declares_pass(category)
		_expect(focused_marker_ready,
			"%s focused gate declares its executable PASS marker"
				% category.to_upper())
		var contract_ready := _manifest_preflight_ready(manifest) \
			if category == "manifest" \
			else _adapter_category_ready(category, adapter_scripts)
		_expect(contract_ready,
			"%s direct readiness contract is green" % category.to_upper())
		_marker_results[category] = focused_marker_ready and contract_ready
	_finish()


func _test_manifest_inventory(
	manifest: Dictionary,
	adapter_scripts: Array[String]
) -> bool:
	var manifest_identity_ready := (
		str(manifest.get("manifest_id", ""))
			== "space_syndicate.v07.atomic_cutover_manifest.v1"
		and str(manifest.get("target_development_ruleset", "")) == "v0.7"
	)
	_expect(manifest_identity_ready,
		"atomic cutover manifest identity and target ruleset are exact")
	var gameplay_domains_ready := _manifest_gameplay_domains_ready(manifest)
	_expect(gameplay_domains_ready,
		"manifest has the exact 10 gameplay IDs and exact per-domain fields")
	var inventory_ready := not adapter_scripts.is_empty()
	return manifest_identity_ready and gameplay_domains_ready and inventory_ready


func _manifest_preflight_ready(manifest: Dictionary) -> bool:
	if manifest.is_empty():
		return false
	var ready: bool = str(manifest.get("manifest_id", "")) \
			== "space_syndicate.v07.atomic_cutover_manifest.v1" \
		and str(manifest.get("baseline_sha", "")) == BASELINE_REVISION \
		and str(manifest.get("target_development_ruleset", "")) == "v0.7" \
		and str(manifest.get("status", "")) \
			== "DETACHED_ADAPTER_PREFLIGHT_READY" \
		and str(manifest.get("canonical_adapter_implementation_status", "")) \
			== "IMPLEMENTED_DETACHED_NOT_CONNECTED" \
		and not bool(manifest.get("production_cutover_authorized", true)) \
		and not bool(manifest.get("production_scene_change", true)) \
		and not bool(manifest.get("main_change", true)) \
		and not bool(manifest.get("dual_write_allowed", true)) \
		and manifest.get("V06_SAVE_TO_V07_DIRECT_LOAD") is bool \
		and not bool(manifest.get("V06_SAVE_TO_V07_DIRECT_LOAD")) \
		and manifest.get("allowed_session_entrypoints") == ["NEW_V07_GAME"]
	return ready and _manifest_gameplay_domains_ready(manifest)


func _manifest_gameplay_domains_ready(manifest: Dictionary) -> bool:
	if int(manifest.get("domain_count", 0)) != GAMEPLAY_DOMAIN_IDS.size() \
			or not _same_string_array(
				manifest.get("required_domain_ids"), GAMEPLAY_DOMAIN_IDS
			) \
			or not _same_string_array(
				manifest.get("domain_entry_required_fields"),
				GAMEPLAY_DOMAIN_FIELDS
			):
		return false
	var domains_variant: Variant = manifest.get("domains")
	if not domains_variant is Array:
		return false
	var domains := domains_variant as Array
	if domains.size() != GAMEPLAY_DOMAIN_IDS.size():
		return false
	var seen: Array[String] = []
	for index in range(domains.size()):
		if not domains[index] is Dictionary:
			return false
		var domain := domains[index] as Dictionary
		var domain_id := str(domain.get("domain_id", ""))
		if not _same_string_set(domain.keys(), GAMEPLAY_DOMAIN_FIELDS) \
				or domain_id != GAMEPLAY_DOMAIN_IDS[index] \
				or seen.has(domain_id):
			return false
		seen.append(domain_id)
		for field in [
			"v06_current_owner",
			"v07_target_owner",
			"core_port",
			"ai_port",
			"player_port",
			"save_adapter",
			"rng_stream",
			"pre_cutover_gate",
			"cutover_step",
			"rollback_step",
			"old_path_deletion_gate",
		]:
			if not _manifest_field_nonempty(domain.get(field)):
				return false
		if not domain.get("production_scene_change") is bool \
				or bool(domain.get("production_scene_change")) \
				or not domain.get("main_change") is bool \
				or bool(domain.get("main_change")) \
				or not domain.get("dual_write_allowed") is bool \
				or bool(domain.get("dual_write_allowed")):
			return false
	return seen == GAMEPLAY_DOMAIN_IDS


func _adapter_category_ready(
	category: String,
	adapter_scripts: Array[String]
) -> bool:
	var backing_scripts := _backing_scripts(category, adapter_scripts)
	_expect(backing_scripts.size() == 1,
		"%s readiness has exactly one discovered adapter implementation"
			% category.to_upper())
	if backing_scripts.size() != 1:
		return false
	var path := backing_scripts[0]
	var script := load(path) as Script
	var pure := script != null \
		and script.get_instance_base_type() == &"RefCounted"
	_expect(pure, "%s adapter is a RefCounted: %s"
		% [category.to_upper(), path])
	if not pure:
		return false
	var constants := script.get_script_constant_map()
	var methods := _script_method_names(script)
	match category:
		"save":
			return _save_contract_ready(script, constants, methods)
		"rng":
			return _rng_contract_ready(script, constants, methods)
		"ai":
			return _ai_contract_ready(script, constants, methods)
		"player":
			return _player_contract_ready(script, constants, methods)
	return false


func _save_contract_ready(
	script: Script,
	constants: Dictionary,
	methods: Array[String]
) -> bool:
	var required_methods := [
		"capture_new_v07_game",
		"preflight_restore",
		"preflight_envelope",
		"preflight_restore_plan",
		"capture_restore_checkpoint",
		"exact_roundtrip",
		"adapter_contract",
	]
	if not _has_methods(methods, required_methods):
		return false
	var contract_variant: Variant = script.call("adapter_contract")
	if not contract_variant is Dictionary:
		return false
	var contract := contract_variant as Dictionary
	return constants.get("RULESET_ID") == "v0.7" \
		and contract.get("ruleset_id") == "v0.7" \
		and contract.get("source_kinds_allowed") == ["NEW_V07_GAME"] \
		and contract.get("v06_direct_resume_allowed") == false \
		and contract.get("section_count") == 5 \
		and contract.get("all_preflight_before_apply") == true \
		and contract.get("detached_restore_only") == true \
		and contract.get("checkpoint_before_apply") == true \
		and contract.get("reverse_order_rollback") == true \
		and contract.get("production_runtime_connected") == false


func _rng_contract_ready(
	script: Script,
	constants: Dictionary,
	methods: Array[String]
) -> bool:
	if not _has_methods(methods, [
		"adapter_contract", "capture_ledger", "preflight_ledger", "validate_ledger",
	]):
		return false
	var contract_variant: Variant = script.call("adapter_contract")
	if not contract_variant is Dictionary:
		return false
	var contract := contract_variant as Dictionary
	return constants.get("RULESET_ID") == "v0.7" \
		and contract.get("ruleset_id") == "v0.7" \
		and contract.get("logical_stream_id_count") == 7 \
		and contract.get("canonical_row_is_second_rng_authority") == false \
		and contract.get("draw_api_count") == 0 \
		and contract.get("production_runtime_connection_count") == 0


func _ai_contract_ready(
	script: Script,
	constants: Dictionary,
	methods: Array[String]
) -> bool:
	if constants.get("RULESET_ID") != "v0.7" \
			or constants.get("ADAPTER_ID") \
				!= "v07.canonical.ai_observation_adapter.v1" \
			or constants.get("OBSERVATION_ID") \
				!= "v07.canonical.ai_observation.v1" \
			or not _has_methods(methods, [
				"issue_capability",
				"bind_authorization",
				"adapt_ai_observation",
				"ai_observation",
				"validation_report",
				"debug_snapshot",
			]):
		return false
	var adapter: Variant = script.new()
	if adapter == null or not adapter.has_method("debug_snapshot"):
		return false
	var snapshot_variant: Variant = adapter.call("debug_snapshot")
	if not snapshot_variant is Dictionary:
		return false
	var snapshot := snapshot_variant as Dictionary
	return snapshot.get("adapter_id") == constants.get("ADAPTER_ID") \
		and snapshot.get("mutates_core") == false \
		and snapshot.get("consumes_rng") == false \
		and snapshot.get("stores_observation_payloads") == false \
		and snapshot.get("capability_is_observation_data") == false


func _player_contract_ready(
	script: Script,
	constants: Dictionary,
	methods: Array[String]
) -> bool:
	if constants.get("RULESET_ID") != "v0.7" \
			or constants.get("ADAPTER_ID") \
				!= "v07.canonical.player_projection_adapter.v1" \
			or not _has_methods(methods, [
				"issue_capability",
				"bind_authorization",
				"adapt_player_projection",
				"player_projection",
				"validation_report",
				"debug_snapshot",
			]):
		return false
	var adapter: Variant = script.new()
	if adapter == null or not adapter.has_method("debug_snapshot"):
		return false
	var snapshot_variant: Variant = adapter.call("debug_snapshot")
	if not snapshot_variant is Dictionary:
		return false
	var snapshot := snapshot_variant as Dictionary
	return snapshot.get("adapter_id") == constants.get("ADAPTER_ID") \
		and snapshot.get("mutates_core") == false \
		and snapshot.get("consumes_rng") == false \
		and snapshot.get("capability_is_projection_data") == false


func _script_method_names(script: Script) -> Array[String]:
	var result: Array[String] = []
	for record_variant in script.get_script_method_list():
		if record_variant is Dictionary:
			result.append(str((record_variant as Dictionary).get("name", "")))
	return _unique_sorted(result)


func _has_methods(actual: Array[String], expected: Array) -> bool:
	for method_variant in expected:
		if not actual.has(str(method_variant)):
			return false
	return true


func _focused_gate_declares_pass(category: String) -> bool:
	var test_paths: Array[String] = []
	_collect_files(TEST_ROOT, ["gd"], test_paths)
	var candidates: Array[String] = []
	for path in test_paths:
		var name := path.get_file().to_lower()
		if _focused_test_names_category(name, category):
			candidates.append(path)
	if candidates.size() != 1:
		return false
	var source := FileAccess.get_file_as_string(candidates[0]).to_lower()
	if category == "manifest":
		return source.contains("v07_atomic_cutover_manifest|status=pass")
	return source.contains("pass") \
		and source.contains("canonical") \
		and source.contains("adapter") \
		and _text_names_category(source, category)


func _focused_test_names_category(name: String, category: String) -> bool:
	match category:
		"save":
			return name == "v07_canonical_save_adapter_test.gd"
		"rng":
			return name == "v07_canonical_rng_adapter_test.gd"
		"ai":
			return name == "v07_canonical_ai_observation_adapter_test.gd"
		"player":
			return name == "v07_canonical_player_projection_adapter_test.gd"
		"manifest":
			return name == "v07_atomic_cutover_manifest_test.gd"
	return false


func _backing_scripts(
	category: String,
	adapter_scripts: Array[String]
) -> Array[String]:
	var result: Array[String] = []
	for path in adapter_scripts:
		if _adapter_script_names_category(path.get_file().to_lower(), category):
			result.append(path)
	return _unique_sorted(result)


func _adapter_script_names_category(name: String, category: String) -> bool:
	match category:
		"save":
			return name == "v07_canonical_save_adapter.gd"
		"rng":
			return name == "v07_canonical_rng_adapter.gd"
		"ai":
			return name == "v07_canonical_ai_observation_adapter.gd"
		"player":
			return name == "v07_canonical_player_projection_adapter.gd"
	return false


func _text_names_category(value: String, category: String) -> bool:
	match category:
		"save":
			return value.contains("save_adapter") \
				or value.contains("canonical_save") \
				or value.contains("save_state")
		"rng":
			return value.contains("rng_adapter") \
				or value.contains("canonical_rng") \
				or value.contains("rng_stream")
		"ai":
			return value.contains("ai_adapter") \
				or value.contains("ai_observation") \
				or value.contains("/ai_")
		"player":
			return value.contains("player_adapter") \
				or value.contains("player_projection") \
				or value.contains("/player_")
	return false


func _discover_adapter_scripts() -> Array[String]:
	var result: Array[String] = []
	_collect_files(ADAPTER_ROOT, ["gd"], result)
	return _unique_sorted(result)


func _discover_manifest_paths() -> Array[String]:
	var candidates: Array[String] = []
	for root in MANIFEST_SEARCH_ROOTS:
		var files: Array[String] = []
		_collect_files(root, ["json"], files)
		for path in files:
			var name := path.get_file().to_lower()
			if name == "v07_atomic_cutover_manifest.json" \
					or (name.contains("v07") and name.contains("adapter") \
					and name.contains("manifest")):
				candidates.append(path)
	return _unique_sorted(candidates)


func _collect_files(root: String, extensions: Array, result: Array[String]) -> void:
	var directory := DirAccess.open(root)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if not entry.begins_with("."):
			var path := root.path_join(entry)
			if directory.current_is_dir():
				_collect_files(path, extensions, result)
			elif extensions.has(path.get_extension().to_lower()):
				result.append(path)
		entry = directory.get_next()
	directory.list_dir_end()


func _load_manifest(path: String) -> Dictionary:
	var source := FileAccess.get_file_as_string(path)
	_expect(not source.is_empty(), "%s is readable" % path)
	var parsed: Variant = JSON.parse_string(source)
	_expect(parsed is Dictionary, "%s parses as a JSON object" % path)
	return parsed as Dictionary if parsed is Dictionary else {}


func _manifest_field_nonempty(value: Variant) -> bool:
	if value is String:
		return not str(value).strip_edges().is_empty()
	if value is Array:
		if (value as Array).is_empty():
			return false
		for entry in value as Array:
			if not entry is String or str(entry).strip_edges().is_empty():
				return false
		return true
	return false


func _same_string_set(left: Array, right: Array) -> bool:
	var left_values: Array[String] = []
	var right_values: Array[String] = []
	for value in left:
		left_values.append(str(value))
	for value in right:
		right_values.append(str(value))
	return _unique_sorted(left_values) == _unique_sorted(right_values)


func _same_string_array(actual_variant: Variant, expected: Array) -> bool:
	if not actual_variant is Array:
		return false
	var actual := actual_variant as Array
	if actual.size() != expected.size():
		return false
	for index in range(expected.size()):
		if str(actual[index]) != str(expected[index]):
			return false
	return true


func _unique_sorted(values: Array[String]) -> Array[String]:
	var seen := {}
	for value in values:
		seen[value] = true
	var result: Array[String] = []
	for value_variant in seen.keys():
		result.append(str(value_variant))
	result.sort()
	return result


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	for category in READINESS_ORDER:
		print("%s | status=%s" % [
			READINESS_OUTPUT_MARKERS.get(category, category.to_upper()),
			"PASS" if bool(_marker_results.get(category, false)) else "FAIL",
		])
	if _failures.is_empty():
		print("V07_CANONICAL_ADAPTER_AGGREGATE_READY | status=PASS")
		print("V07_CANONICAL_ADAPTER_AGGREGATE_TEST | passed=%d total=%d" \
			% [_checks, _checks])
		quit(0)
		return
	for failure in _failures:
		push_error("V07_CANONICAL_ADAPTER_AGGREGATE_TEST | %s" % failure)
	push_error("V07_CANONICAL_ADAPTER_AGGREGATE_TEST | passed=%d total=%d" \
		% [_checks - _failures.size(), _checks])
	quit(1)
