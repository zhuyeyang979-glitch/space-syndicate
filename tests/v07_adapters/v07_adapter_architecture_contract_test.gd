extends SceneTree

const ADAPTER_ROOT := "res://scripts/v07_adapters"
const BASELINE_REVISION := "95aca23eb0d1f572025776902519f494ee3778d4"
const DECLARED_DETACHED_WRITE_PREFIXES := [
	"scripts/v07_adapters/",
	"scripts/v07_semantic/",
	"scripts/v071_simulation/",
	"scenes/tools/V071RuleConsistencyReview.tscn",
]

const MANIFEST_SEARCH_ROOTS := [
	ADAPTER_ROOT,
	"res://docs/migration",
	"res://docs/save",
	"res://docs/semantic",
]
const ADAPTER_ALLOWED_RESOURCE_PREFIXES := [
	"res://scripts/v07_adapters/",
	"res://scripts/v07_semantic/",
	"res://scripts/semantic/",
	"res://docs/migration/",
	"res://docs/save/",
	"res://docs/semantic/",
	"res://docs/rules/",
]
const FORBIDDEN_RESOURCE_PREFIXES := [
	"res://scripts/main.gd",
	"res://scenes/",
	"res://scripts/runtime/",
	"res://scripts/ai/",
	"res://scripts/ui/",
]
const FORBIDDEN_SOURCE_TOKENS := [
	"extends node",
	"extends control",
	"extends canvasitem",
	"extends scenetree",
	"nodepath",
	"packedscene",
	"get_tree(",
	"get_node(",
	"add_child(",
	"remove_child(",
	"queue_free(",
	".connect(",
	"v06saveownerregistry",
	"v06_save_owner_registry",
	"gameruntimecoordinator",
]
const PRODUCTION_CONNECTION_KEYS := [
	"v071_production_connection_count",
	"v07_production_runtime_connection_count",
	"production_runtime_connection_count",
	"production_connection_count",
]
const DUAL_WRITE_KEYS := [
	"v06_and_v07_dual_write",
	"dual_write_enabled",
	"dual_write_allowed",
	"dual_write",
]
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
	"v071_target_owner",
	"core_port",
	"ai_port",
	"player_port",
	"save_adapter",
	"rng_stream",
	"required_asset_keys",
	"required_player_projection",
	"required_ai_observation",
	"required_save_adapter",
	"required_rng_stream",
	"production_scene_target",
	"old_surface_deletion_gate",
	"rollback_surface",
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


func _init() -> void:
	if OS.get_cmdline_user_args().has("--parse-only"):
		print("V07_ADAPTER_ARCHITECTURE_CONTRACT_TEST | status=PARSE_ONLY_PASS")
		quit(0)
		return
	call_deferred("_run")


func _run() -> void:
	var adapter_scripts := _discover_adapter_scripts()
	var manifest_paths := _discover_manifest_paths()
	_expect(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(ADAPTER_ROOT)),
		"scripts/v07_adapters exists")
	_expect(not adapter_scripts.is_empty(),
		"scripts/v07_adapters contains discoverable GDScript adapters")
	_expect(manifest_paths.size() == 1,
		"exactly one V0.7 canonical adapter manifest is discoverable")

	var manifest: Dictionary = {}
	if manifest_paths.size() == 1:
		manifest = _load_manifest(manifest_paths[0])
	if not manifest.is_empty():
		_test_manifest_inventory(manifest, adapter_scripts)
		_test_manifest_detachment(manifest)

	var adapter_class_names: Array[String] = []
	for path in adapter_scripts:
		_test_adapter_script(path, adapter_class_names)
	_test_zero_production_references(adapter_class_names)
	_test_declared_production_change_scope()
	_finish()


func _test_manifest_inventory(
	manifest: Dictionary,
	_adapter_scripts: Array[String]
) -> void:
	_expect(
		str(manifest.get("manifest_id", ""))
			== "space_syndicate.v071.atomic_cutover_manifest"
			and str(manifest.get("baseline_sha", "")) == BASELINE_REVISION,
		"manifest identity and declared production baseline are exact"
	)
	_test_manifest_gameplay_domains(manifest)


func _test_manifest_gameplay_domains(manifest: Dictionary) -> void:
	var domain_ids_ready: bool = int(manifest.get("domain_count", 0)) \
		== GAMEPLAY_DOMAIN_IDS.size() and _same_string_array(
			manifest.get("required_domain_ids"), GAMEPLAY_DOMAIN_IDS
		)
	_expect(
		domain_ids_ready,
		"manifest declares the exact 10 gameplay domain IDs in canonical order"
	)
	var field_contract_ready: bool = _same_string_array(
		manifest.get("domain_entry_required_fields"),
		GAMEPLAY_DOMAIN_FIELDS
	)
	_expect(
		field_contract_ready,
		"manifest declares the exact gameplay-domain field contract without aliases"
	)
	if not domain_ids_ready or not field_contract_ready:
		return
	var domains_variant: Variant = manifest.get("domains")
	_expect(domains_variant is Array,
		"manifest gameplay domains are an array")
	if not domains_variant is Array:
		return
	var domains := domains_variant as Array
	_expect(domains.size() == GAMEPLAY_DOMAIN_IDS.size(),
		"manifest contains exactly 10 gameplay domain entries")
	var seen: Array[String] = []
	for index in range(domains.size()):
		var domain_variant: Variant = domains[index]
		_expect(domain_variant is Dictionary,
			"gameplay domain %d is an object" % (index + 1))
		if not domain_variant is Dictionary:
			continue
		var domain := domain_variant as Dictionary
		var domain_id := str(domain.get("domain_id", ""))
		_expect(_same_string_set(domain.keys(), GAMEPLAY_DOMAIN_FIELDS),
			"%s uses exactly the required gameplay-domain fields" % domain_id)
		_expect(
			index < GAMEPLAY_DOMAIN_IDS.size()
				and domain_id == GAMEPLAY_DOMAIN_IDS[index]
				and not seen.has(domain_id),
			"gameplay domain %d has the exact unique canonical ID" % (index + 1)
		)
		seen.append(domain_id)
		for field in [
			"v06_current_owner",
			"v071_target_owner",
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
			var binding_ready := _manifest_field_nonempty(domain.get(field))
			match field:
				"ai_port":
					binding_ready = binding_ready \
						and domain.get("required_ai_observation") == domain.get(field)
				"player_port":
					binding_ready = binding_ready \
						and domain.get("required_player_projection") == domain.get(field)
				"save_adapter":
					binding_ready = binding_ready \
						and domain.get("required_save_adapter") == domain.get(field)
				"rng_stream":
					binding_ready = binding_ready \
						and domain.get("required_rng_stream") == domain.get(field)
			_expect(binding_ready,
				"%s has nonempty %s" % [domain_id, field])
		_expect(
			_manifest_field_nonempty(domain.get("required_asset_keys"))
				and _manifest_field_nonempty(domain.get("production_scene_target"))
				and _manifest_field_nonempty(domain.get("old_surface_deletion_gate"))
				and _manifest_field_nonempty(domain.get("rollback_surface"))
				and str(domain.get("old_surface_deletion_gate", "")).begins_with(
					"DELETE SURFACE AFTER COMMIT: "
				)
				and str(domain.get("rollback_surface", "")).begins_with(
					"ROLLBACK SURFACE: "
				)
				and domain.get("production_scene_change") is bool
				and not bool(domain.get("production_scene_change"))
				and domain.get("main_change") is bool
				and not bool(domain.get("main_change"))
				and domain.get("dual_write_allowed") is bool
				and not bool(domain.get("dual_write_allowed")),
			"%s has strict false production/Main/dual-write flags" % domain_id
		)
	_expect(seen == GAMEPLAY_DOMAIN_IDS,
		"manifest gameplay domain set and order are exact")


func _test_manifest_detachment(manifest: Dictionary) -> void:
	var connection_values: Array = []
	_collect_values_for_keys(manifest, PRODUCTION_CONNECTION_KEYS, connection_values)
	for value in connection_values:
		_expect((value is int or value is float) and float(value) == 0.0,
			"every manifest production connection count is zero")
	_expect(
		str(manifest.get("status", "")) == "V071_DETACHED_ADAPTER_PREFLIGHT_READY"
			and str(manifest.get("canonical_adapter_implementation_status", ""))
				== "IMPLEMENTED_DETACHED_NOT_CONNECTED"
			and not bool(manifest.get("production_cutover_authorized", true))
			and not bool(manifest.get("production_scene_change", true))
			and not bool(manifest.get("main_change", true)),
		"implemented adapters remain detached with no production authorization or connection"
	)

	var dual_write_values: Array = []
	_collect_values_for_keys(manifest, DUAL_WRITE_KEYS, dual_write_values)
	_expect(not dual_write_values.is_empty(),
		"manifest explicitly declares the no-dual-write boundary")
	for value in dual_write_values:
		_expect(value is bool and not bool(value),
			"every manifest dual-write marker is false")


func _test_adapter_script(path: String, class_names: Array[String]) -> void:
	var source := FileAccess.get_file_as_string(path)
	_expect(not source.is_empty(), "%s is readable" % path)
	if source.is_empty():
		return
	var code := _without_comments(source)
	var lower_code := code.to_lower()
	_expect(_has_direct_refcounted_base(code),
		"%s directly extends RefCounted" % path)

	var resource := load(path)
	var script := resource as Script
	_expect(script != null, "%s loads as a Script" % path)
	if script != null:
		_expect(script.get_instance_base_type() == &"RefCounted",
			"%s has RefCounted as its engine base type" % path)

	for token in FORBIDDEN_SOURCE_TOKENS:
		_expect(not lower_code.contains(token),
			"%s excludes Node/production token %s" % [path, token])

	var resource_paths := _resource_paths(code)
	for resource_path in resource_paths:
		var lower_path := resource_path.to_lower()
		for forbidden_prefix in FORBIDDEN_RESOURCE_PREFIXES:
			_expect(not lower_path.begins_with(forbidden_prefix),
				"%s has no forbidden import/reference %s" % [path, resource_path])
		_expect(_starts_with_any(lower_path, ADAPTER_ALLOWED_RESOURCE_PREFIXES),
			"%s references only detached V0.7 adapter, Core, or contract resources: %s"
				% [path, resource_path])

	var declared_name := _declared_class_name(code)
	if not declared_name.is_empty():
		class_names.append(declared_name)


func _test_zero_production_references(adapter_class_names: Array[String]) -> void:
	var production_paths: Array[String] = []
	_collect_files("res://scripts", ["gd"], production_paths, [ADAPTER_ROOT])
	_collect_files("res://scenes", ["gd", "tscn"], production_paths)
	production_paths.append("res://project.godot")
	production_paths.sort()
	var adapter_root_reference_count := 0
	var adapter_class_reference_count := 0
	for path in production_paths:
		var source := FileAccess.get_file_as_string(path)
		adapter_root_reference_count += source.count("res://scripts/v07_adapters/")
		for declared_name in adapter_class_names:
			adapter_class_reference_count += source.count(declared_name)
	_expect(adapter_root_reference_count == 0,
		"production scripts/scenes/project have zero adapter-path connections")
	_expect(adapter_class_reference_count == 0,
		"production scripts/scenes/project have zero adapter class-name connections")


func _test_declared_production_change_scope() -> void:
	var diff_result := _git_paths(PackedStringArray([
		"diff", "--name-only", BASELINE_REVISION, "--",
		"scripts", "scenes", "project.godot",
	]))
	var untracked_result := _git_paths(PackedStringArray([
		"ls-files", "--others", "--exclude-standard", "--",
		"scripts", "scenes", "project.godot",
	]))
	_expect(bool(diff_result.get("ok", false)),
		"git can compare production files with the declared baseline")
	_expect(bool(untracked_result.get("ok", false)),
		"git can enumerate untracked production files")
	var changed_paths: Array[String] = []
	changed_paths.append_array(diff_result.get("paths", []) as Array[String])
	changed_paths.append_array(untracked_result.get("paths", []) as Array[String])
	changed_paths = _unique_sorted(changed_paths)
	for path in changed_paths:
		var declared_detached_path := false
		for prefix in DECLARED_DETACHED_WRITE_PREFIXES:
			if path.begins_with(prefix):
				declared_detached_path = true
				break
		_expect(
			declared_detached_path,
			"change stays inside declared detached implementation scope: %s" % path
		)


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


func _collect_files(
	root: String,
	extensions: Array,
	result: Array[String],
	excluded_roots: Array = []
) -> void:
	for excluded_root_variant in excluded_roots:
		var excluded_root := str(excluded_root_variant)
		if root == excluded_root or root.begins_with("%s/" % excluded_root):
			return
	var directory := DirAccess.open(root)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if not entry.begins_with("."):
			var path := root.path_join(entry)
			if directory.current_is_dir():
				_collect_files(path, extensions, result, excluded_roots)
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


func _collect_values_for_keys(
	value: Variant,
	keys: Array,
	result: Array
) -> void:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant).to_lower()
			var child: Variant = (value as Dictionary).get(key_variant)
			if keys.has(key):
				result.append(child)
			_collect_values_for_keys(child, keys, result)
	elif value is Array:
		for child in value as Array:
			_collect_values_for_keys(child, keys, result)


func _has_direct_refcounted_base(source: String) -> bool:
	for line_variant in source.split("\n"):
		var line := str(line_variant).strip_edges()
		if line.begins_with("extends "):
			return line == "extends RefCounted"
	return false


func _declared_class_name(source: String) -> String:
	for line_variant in source.split("\n"):
		var line := str(line_variant).strip_edges()
		if line.begins_with("class_name "):
			return line.trim_prefix("class_name ").get_slice(" ", 0).strip_edges()
	return ""


func _resource_paths(source: String) -> Array[String]:
	var regex := RegEx.new()
	var compile_error := regex.compile("res://[^\\\"'\\r\\n)]+")
	if compile_error != OK:
		return []
	var result: Array[String] = []
	for match_result in regex.search_all(source):
		result.append(match_result.get_string())
	return _unique_sorted(result)


func _without_comments(source: String) -> String:
	var lines: Array[String] = []
	for line_variant in source.split("\n"):
		var line := str(line_variant)
		var comment_index := line.find("#")
		lines.append(line.left(comment_index) if comment_index >= 0 else line)
	return "\n".join(lines)


func _starts_with_any(value: String, prefixes: Array) -> bool:
	for prefix_variant in prefixes:
		if value.begins_with(str(prefix_variant).to_lower()):
			return true
	return false


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


func _git_paths(arguments: PackedStringArray) -> Dictionary:
	var output: Array = []
	var exit_code := OS.execute("git", arguments, output, true)
	var paths: Array[String] = []
	if exit_code == 0:
		for output_variant in output:
			for line_variant in str(output_variant).split("\n", false):
				var path := str(line_variant).strip_edges().replace("\\", "/")
				if not path.is_empty():
					paths.append(path)
	return {"ok": exit_code == 0, "paths": _unique_sorted(paths)}


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
	if _failures.is_empty():
		print("V07_ADAPTER_ARCHITECTURE_CONTRACT_TEST | passed=%d total=%d" \
			% [_checks, _checks])
		quit(0)
		return
	for failure in _failures:
		push_error("V07_ADAPTER_ARCHITECTURE_CONTRACT_TEST | %s" % failure)
	push_error("V07_ADAPTER_ARCHITECTURE_CONTRACT_TEST | passed=%d total=%d" \
		% [_checks - _failures.size(), _checks])
	quit(1)
