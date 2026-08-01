extends SceneTree

const CATALOG_PATH := (
	"res://resources/presentation/alpha01_card_illustration_catalog.tres"
)
const PLAYER_ADAPTER_PATH := (
	"res://scripts/v07_adapters/v07_canonical_player_projection_adapter.gd"
)
const AI_ADAPTER_PATH := (
	"res://scripts/v07_adapters/v07_canonical_ai_observation_adapter.gd"
)
const SAVE_ADAPTER_PATH := (
	"res://scripts/v07_adapters/v07_canonical_save_adapter.gd"
)
const MANIFEST_PATH := "res://docs/migration/v07_atomic_cutover_manifest.json"
const CORE_ROOT := "res://scripts/v07_semantic"

const REQUIRED_STABLE_ASSET_KEYS := [
	"icon.asset.life",
	"icon.asset.energy",
	"icon.asset.industry",
	"icon.asset.technology",
	"icon.asset.commerce",
	"icon.asset.shipping",
	"card.frame.normal",
	"card.frame.commodity",
	"card.frame.bound_action",
	"card.back.normal",
	"card.badge.starter",
	"model.facility.factory.base",
	"model.facility.market.base",
	"model.facility.warehouse.base",
	"model.facility.starport.base",
	"model.monster.life",
	"model.monster.energy",
	"model.monster.industry",
	"model.monster.technology",
	"model.monster.commerce",
	"model.monster.shipping",
	"model.military.tier1",
	"model.military.tier2",
	"model.military.tier3",
	"model.military.tier4",
	"model.shipping.route_marker",
	"model.shipping.convoy",
	"model.shipping.starport_showcase",
	"font.body.zh",
	"font.body.ja",
	"font.display",
	"audio.card.lock",
	"audio.card.merge",
	"audio.asset.refresh",
]

const PLAYER_PROJECTION_ASSET_KEYS := [
	"icon.asset.life",
	"icon.asset.energy",
	"icon.asset.industry",
	"icon.asset.technology",
	"icon.asset.commerce",
	"icon.asset.shipping",
	"card.frame.normal",
	"card.frame.commodity",
	"card.frame.bound_action",
	"card.back.normal",
	"card.badge.starter",
]

const FORBIDDEN_RAW_ASSET_TOKENS := [
	"res://assets/",
	"res://third_party/",
	"assets/third_party/",
	"third_party/",
	"third-party/",
	"kenney_",
	"quaternius",
	"ambientcg",
	"game-icons",
	"game_icons",
	"naejimer",
	"notosans",
	"noto sans",
	"oxanium",
	".png",
	".jpg",
	".jpeg",
	".webp",
	".svg",
	".ogg",
	".wav",
	".mp3",
	".glb",
	".gltf",
	".fbx",
	".obj",
	".dae",
	".ttf",
	".otf",
	".hdr",
	".exr",
]

const FORBIDDEN_PLAYER_PROJECTION_FIELDS := [
	"resource_path",
	"third_party_path",
	"original_filename",
	"download_filename",
	"author",
	"license",
	"license_path",
]

var _checks := 0
var _failures: Array[String] = []
var _catalog_keys: Array[String] = []
var _scanned_boundary_files := 0


func _init() -> void:
	if OS.get_cmdline_user_args().has("--parse-only"):
		print("V07_COMMERCIAL_ART_ASSET_KEY_COMPATIBILITY | status=PARSE_ONLY_PASS")
		quit(0)
		return
	call_deferred("_run")


func _run() -> void:
	_test_presentation_catalog_contract()
	_test_player_projection_asset_key_boundary()
	_test_cutover_manifest_asset_key_boundary()
	_test_core_ai_save_raw_asset_boundary()
	_finish()


func _test_presentation_catalog_contract() -> void:
	var source := FileAccess.get_file_as_string(CATALOG_PATH)
	_expect(not source.is_empty(), "existing Presentation Asset Catalog is readable")
	if source.is_empty():
		return
	_expect(
		source.contains(
			'stable_asset_schema_version = "commercial.presentation_assets.v1"'
		),
		"existing Catalog owns the commercial stable-key schema"
	)
	var catalog_script_source := FileAccess.get_file_as_string(
		"res://scripts/presentation/card_illustration_catalog_resource.gd"
	)
	_expect(
		not catalog_script_source.is_empty()
			and catalog_script_source.contains(
				"func resource_for_asset_key(asset_key: StringName) -> Resource:"
			)
			and catalog_script_source.contains(
				"func has_asset_key(asset_key: StringName) -> bool:"
			),
		"existing Catalog exposes the canonical stable-key resolver API"
	)
	_catalog_keys = _packed_string_assignment(source, "stable_asset_keys")
	var stable_kinds := _packed_string_assignment(source, "stable_asset_kinds")
	var stable_scopes := _packed_string_assignment(source, "stable_asset_scopes")
	var stable_resource_count := _resource_array_assignment_count(
		source,
		"stable_asset_resources"
	)
	_expect(
		not _catalog_keys.is_empty(),
		"existing Catalog exposes a nonempty typed stable_asset_keys array"
	)
	_expect(
		stable_kinds.size() == _catalog_keys.size()
			and stable_scopes.size() == _catalog_keys.size()
			and stable_resource_count == _catalog_keys.size(),
		"existing Catalog stable key, resource, kind, and scope rows are parallel"
	)
	_expect(
		_unique_sorted(_catalog_keys).size() == _catalog_keys.size(),
		"existing Catalog stable keys are unique"
	)
	_expect(
		_unique_sorted(_string_array(REQUIRED_STABLE_ASSET_KEYS)).size()
			== REQUIRED_STABLE_ASSET_KEYS.size(),
		"focused commercial compatibility contract has no duplicate keys"
	)
	for key_variant in REQUIRED_STABLE_ASSET_KEYS:
		var asset_key := str(key_variant)
		_expect(
			_catalog_keys.has(asset_key),
			"Catalog registers required stable key: %s" % asset_key
		)
		_expect(
			_catalog_keys.count(asset_key) == 1,
			"Catalog owns required stable key exactly once: %s" % asset_key
		)


func _test_player_projection_asset_key_boundary() -> void:
	var source := FileAccess.get_file_as_string(PLAYER_ADAPTER_PATH)
	_expect(not source.is_empty(), "Player projection adapter source is readable")
	var script := load(PLAYER_ADAPTER_PATH) as Script
	_expect(script != null, "Player projection adapter loads as a Script")
	if source.is_empty():
		return
	var code := _without_comments(source)
	var contract_variant: Variant = (
		script.call("presentation_asset_contract") if script != null else []
	)
	var projected_contract_keys := _asset_contract_keys(contract_variant)
	_expect(
		_asset_contract_is_key_only(contract_variant)
			and code.contains('"asset_key"'),
		"Player projection publishes a runtime key-only presentation contract"
	)
	for key_variant in PLAYER_PROJECTION_ASSET_KEYS:
		var asset_key := str(key_variant)
		_expect(
			projected_contract_keys.has(asset_key)
				and _contains_quoted_literal(code, asset_key),
			"Player projection declares semantic asset_key: %s" % asset_key
		)
		_expect(
			_catalog_keys.has(asset_key),
			"Player projection asset_key is owned by the existing Catalog: %s"
				% asset_key
		)
	var projected_literals := projected_contract_keys
	_expect(
		not projected_literals.is_empty(),
		"Player projection declares a nonempty semantic asset-key contract"
	)
	for asset_key in projected_literals:
		_expect(
			_catalog_keys.has(asset_key),
			"Player projection literal resolves through the existing Catalog: %s"
				% asset_key
		)
	var raw_tokens := _present_tokens(code, FORBIDDEN_RAW_ASSET_TOKENS)
	_expect(
		raw_tokens.is_empty(),
		"Player projection contains no third-party raw path or filename: %s"
			% str(raw_tokens)
	)
	var forbidden_fields: Array[String] = []
	for field_variant in FORBIDDEN_PLAYER_PROJECTION_FIELDS:
		var field := str(field_variant)
		if _contains_quoted_literal(code, field):
			forbidden_fields.append(field)
	_expect(
		forbidden_fields.is_empty(),
		"Player projection exposes no vendor, license, or resource-path field: %s"
			% str(forbidden_fields)
	)


func _asset_contract_keys(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	for entry_variant in value as Array:
		if entry_variant is Dictionary:
			result.append(str((entry_variant as Dictionary).get("asset_key", "")))
	return result


func _asset_contract_is_key_only(value: Variant) -> bool:
	if not value is Array or (value as Array).is_empty():
		return false
	for entry_variant in value as Array:
		if not entry_variant is Dictionary:
			return false
		var entry := entry_variant as Dictionary
		if entry.size() != 1 or not entry.has("asset_key") \
				or str(entry.get("asset_key", "")).is_empty():
			return false
	return true


func _test_core_ai_save_raw_asset_boundary() -> void:
	var paths: Array[String] = []
	_collect_gdscript_files(CORE_ROOT, paths)
	paths.append(AI_ADAPTER_PATH)
	paths.append(SAVE_ADAPTER_PATH)
	paths = _unique_sorted(paths)
	_expect(not paths.is_empty(), "Core/AI/Save boundary files are discoverable")
	_expect(paths.has(AI_ADAPTER_PATH), "canonical AI adapter is in the boundary scan")
	_expect(paths.has(SAVE_ADAPTER_PATH), "canonical Save adapter is in the boundary scan")
	var raw_reference_count := 0
	var presentation_key_reference_count := 0
	for path in paths:
		var source := FileAccess.get_file_as_string(path)
		_expect(not source.is_empty(), "%s is readable" % path)
		if source.is_empty():
			continue
		_scanned_boundary_files += 1
		var code := _without_comments(source)
		var raw_tokens := _present_tokens(code, FORBIDDEN_RAW_ASSET_TOKENS)
		raw_reference_count += raw_tokens.size()
		_expect(
			raw_tokens.is_empty(),
			"%s has zero third-party raw paths or filenames: %s"
				% [path, str(raw_tokens)]
		)
		var asset_key_literals := _catalog_literals(code)
		presentation_key_reference_count += asset_key_literals.size()
		_expect(
			asset_key_literals.is_empty(),
			"%s remains presentation-asset-key agnostic" % path
		)
	_expect(
		raw_reference_count == 0,
		"Core/AI/Save third-party raw path and filename reference count is zero"
	)
	_expect(
		presentation_key_reference_count == 0,
		"Core/AI/Save stable presentation asset-key reference count is zero"
	)


func _test_cutover_manifest_asset_key_boundary() -> void:
	var source := FileAccess.get_file_as_string(MANIFEST_PATH)
	var parsed: Variant = JSON.parse_string(source)
	_expect(parsed is Dictionary, "cutover manifest is strict JSON")
	if not parsed is Dictionary:
		return
	var domains_variant: Variant = (parsed as Dictionary).get("domains")
	_expect(domains_variant is Array, "cutover manifest exposes gameplay domains")
	if not domains_variant is Array:
		return
	var resolved_reference_count := 0
	var domain_map := {}
	for domain_variant in domains_variant as Array:
		if not domain_variant is Dictionary:
			continue
		var domain := domain_variant as Dictionary
		var domain_id := str(domain.get("domain_id", ""))
		domain_map[domain_id] = domain
		var keys_variant: Variant = domain.get("required_asset_keys")
		var keys := _string_array(keys_variant as Array) \
			if keys_variant is Array else [] as Array[String]
		var keys_ready := not keys.is_empty() \
			and _unique_sorted(keys).size() == keys.size()
		for asset_key in keys:
			keys_ready = keys_ready and _catalog_keys.has(asset_key) \
				and _present_tokens(asset_key, FORBIDDEN_RAW_ASSET_TOKENS).is_empty()
			if _catalog_keys.has(asset_key):
				resolved_reference_count += 1
		_expect(
			keys_ready,
			"%s resolves every required asset key through the existing Catalog"
				% domain_id
		)
	_expect(
		resolved_reference_count > 0,
		"cutover manifest has nonempty resolved presentation dependencies"
	)
	_expect(
		_domain_has_keys(domain_map, "unified_card_track", [
			"card.frame.normal", "card.frame.commodity", "ui.panel.primary",
		]) and _domain_has_keys(domain_map, "normal_dbg_deck", [
			"card.frame.normal", "card.back.normal", "icon.board.draw_pile",
			"icon.board.discard_pile", "icon.board.shuffle", "card.badge.starter",
		]),
		"track and DBG cutovers declare their complete card presentation foundation"
	)
	_expect(
		_domain_has_keys(domain_map, "six_color_assets", PLAYER_PROJECTION_ASSET_KEYS.slice(0, 6)),
		"six-color cutover declares all six stable icon keys"
	)
	var anonymous := domain_map.get("anonymous_resolution", {}) as Dictionary
	var anonymous_keys := _string_array(
		anonymous.get("required_asset_keys", []) as Array
	)
	var anonymous_key_text := "|".join(anonymous_keys).to_lower()
	_expect(
		not anonymous_key_text.contains("avatar")
			and not anonymous_key_text.contains("player_color")
			and not anonymous_key_text.contains("portrait"),
		"anonymous resolution declares no portrait or player-color ownership surface"
	)
	var solar := domain_map.get("solar_efficiency", {}) as Dictionary
	_expect(
		_domain_has_keys(domain_map, "solar_efficiency", [
			"shader.planet.body", "shader.planet.cloud",
			"shader.planet.atmosphere", "environment.night_sky_hdri_001",
		])
			and str(solar.get("old_surface_deletion_gate", "")).contains(
				"without becoming the sunlight owner"
			),
		"solar cutover consumes the opaque day/night presentation without moving Core ownership"
	)


func _domain_has_keys(domain_map: Dictionary, domain_id: String, required: Array) -> bool:
	var domain := domain_map.get(domain_id, {}) as Dictionary
	var keys_variant: Variant = domain.get("required_asset_keys")
	if not keys_variant is Array:
		return false
	var keys := _string_array(keys_variant as Array)
	for required_variant in required:
		if not keys.has(str(required_variant)):
			return false
	return true


func _collect_gdscript_files(root_path: String, result: Array[String]) -> void:
	var directory := DirAccess.open(root_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if not entry.begins_with("."):
			var path := root_path.path_join(entry)
			if directory.current_is_dir():
				_collect_gdscript_files(path, result)
			elif path.get_extension().to_lower() == "gd":
				result.append(path)
		entry = directory.get_next()
	directory.list_dir_end()


func _catalog_literals(source: String) -> Array[String]:
	var result: Array[String] = []
	for asset_key in _catalog_keys:
		if _contains_quoted_literal(source, asset_key):
			result.append(asset_key)
	return _unique_sorted(result)


func _packed_string_assignment(source: String, field_name: String) -> Array[String]:
	var prefix := "%s = PackedStringArray(" % field_name
	var line := _assignment_line(source, prefix)
	if line.is_empty() or not line.ends_with(")"):
		return []
	var encoded := "[%s]" % line.trim_prefix(prefix).trim_suffix(")")
	var parsed: Variant = JSON.parse_string(encoded)
	return _string_array(parsed as Array) if parsed is Array else []


func _resource_array_assignment_count(source: String, field_name: String) -> int:
	var prefix := "%s = Array[Resource]([" % field_name
	var line := _assignment_line(source, prefix)
	return line.count("ExtResource(") + line.count("SubResource(") \
		if not line.is_empty() else -1


func _assignment_line(source: String, prefix: String) -> String:
	for line_variant in source.split("\n"):
		var line := str(line_variant).strip_edges()
		if line.begins_with(prefix):
			return line
	return ""


func _contains_quoted_literal(source: String, value: String) -> bool:
	return source.contains('"%s"' % value) or source.contains("'%s'" % value)


func _present_tokens(source: String, tokens: Array) -> Array[String]:
	var lower_source := source.to_lower()
	var result: Array[String] = []
	for token_variant in tokens:
		var token := str(token_variant).to_lower()
		if lower_source.contains(token):
			result.append(token)
	return _unique_sorted(result)


func _without_comments(source: String) -> String:
	var lines: Array[String] = []
	for line_variant in source.split("\n"):
		var line := str(line_variant)
		var comment_index := line.find("#")
		lines.append(line.left(comment_index) if comment_index >= 0 else line)
	return "\n".join(lines)


func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result


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
	var passed := _checks - _failures.size()
	if _failures.is_empty():
		var success_summary := (
			(
				"V07_COMMERCIAL_ART_ASSET_KEY_COMPATIBILITY | "
				+ "passed=%d total=%d required_keys=%d player_keys=%d "
				+ "boundary_files=%d"
			)
			% [
				passed,
				_checks,
				REQUIRED_STABLE_ASSET_KEYS.size(),
				PLAYER_PROJECTION_ASSET_KEYS.size(),
				_scanned_boundary_files,
			]
		)
		print(success_summary)
		quit(0)
		return
	for failure in _failures:
		push_error("V07_COMMERCIAL_ART_ASSET_KEY_COMPATIBILITY | %s" % failure)
	var failure_summary := (
		(
			"V07_COMMERCIAL_ART_ASSET_KEY_COMPATIBILITY | "
			+ "passed=%d total=%d failures=%d required_keys=%d player_keys=%d "
			+ "boundary_files=%d"
		)
		% [
			passed,
			_checks,
			_failures.size(),
			REQUIRED_STABLE_ASSET_KEYS.size(),
			PLAYER_PROJECTION_ASSET_KEYS.size(),
			_scanned_boundary_files,
		]
	)
	push_error(failure_summary)
	quit(1)
