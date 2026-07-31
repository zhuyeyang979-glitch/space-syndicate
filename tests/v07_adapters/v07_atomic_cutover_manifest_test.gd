extends SceneTree

const MANIFEST_PATH := "res://docs/migration/v07_atomic_cutover_manifest.json"
const MARKDOWN_PATH := "res://docs/migration/v07_atomic_cutover_manifest.md"
const BASELINE_SHA := "2e38764791cb37cdc45b2eb0836957f550822dd5"

const TOP_LEVEL_KEYS := [
	"schema_version",
	"manifest_id",
	"lane",
	"status",
	"baseline_sha",
	"current_production_runtime_ruleset",
	"target_development_ruleset",
	"canonical_adapter_implementation_status",
	"adapter_implementation_paths",
	"production_cutover_authorized",
	"production_scene_change",
	"main_change",
	"dual_write_allowed",
	"V06_SAVE_TO_V07_DIRECT_LOAD",
	"v06_save_rejection_reason",
	"allowed_session_entrypoints",
	"source_contracts",
	"domain_count",
	"required_domain_ids",
	"domain_entry_required_fields",
	"domains",
]
const DOMAIN_KEYS := [
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
const REQUIRED_DOMAIN_IDS := [
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
const ADAPTER_IMPLEMENTATION_PATHS := [
	"scripts/v07_adapters/v07_canonical_data_codec.gd",
	"scripts/v07_adapters/v07_canonical_save_adapter.gd",
	"scripts/v07_adapters/v07_canonical_rng_adapter.gd",
	"scripts/v07_adapters/v07_canonical_ai_observation_adapter.gd",
	"scripts/v07_adapters/v07_canonical_player_projection_adapter.gd",
]
const SOURCE_CONTRACTS := [
	"docs/rules/v07_game_constitution.json",
	"docs/semantic/v07_three_wing_domain_registry.json",
	"docs/save/v07_save_schema.json",
	"docs/save/v07_restore_dependency_graph.json",
	"docs/save/v07_rng_ownership.json",
]
const EXPECTED_BINDINGS := {
	"unified_card_track": {
		"core_port": "v07.unified_track.core_authority.v1",
		"ai_port": "v07.unified_track.ai_observation.v1",
		"player_port": "v07.unified_track.player_projection.v1",
		"save_adapter": "V07CanonicalSaveAdapter#unified_card_track_cycle",
		"rng_stream": [
			"unified_track_type_draw",
			"unified_track_color_draw",
			"unified_track_normal_card_draw",
			"unified_track_commodity_draw",
			"initial_hidden_lead_order",
		],
	},
	"normal_dbg_deck": {
		"core_port": "v07.personal_dbg.core_authority.v1#normal_dbg_deck",
		"ai_port": "v07.personal_dbg.ai_observation.v1#normal_dbg_deck",
		"player_port": "v07.personal_dbg.player_projection.v1#normal_dbg_deck",
		"save_adapter": "V07CanonicalSaveAdapter#personal_dbg_and_merge.normal_dbg_deck",
		"rng_stream": ["starter_deck_shuffle", "normal_deck_reshuffle_by_player"],
	},
	"normal_card_merge": {
		"core_port": "v07.personal_dbg.core_authority.v1#normal_card_merge",
		"ai_port": "v07.personal_dbg.ai_observation.v1#normal_card_merge",
		"player_port": "v07.personal_dbg.player_projection.v1#normal_card_merge",
		"save_adapter": "V07CanonicalSaveAdapter#personal_dbg_and_merge.normal_card_merge",
		"rng_stream": "NONE",
	},
	"commodity_inventory_merge": {
		"core_port": "v07.personal_dbg.core_authority.v1#commodity_inventory_merge",
		"ai_port": "v07.personal_dbg.ai_observation.v1#commodity_inventory_merge",
		"player_port": "v07.personal_dbg.player_projection.v1#commodity_inventory_merge",
		"save_adapter": "V07CanonicalSaveAdapter#personal_dbg_and_merge.commodity_inventory_merge",
		"rng_stream": "NONE",
	},
	"six_color_assets": {
		"core_port": "v07.six_color_assets.core_authority.v1",
		"ai_port": "v07.six_color_assets.ai_observation.v1",
		"player_port": "v07.six_color_assets.player_projection.v1",
		"save_adapter": "V07CanonicalSaveAdapter#six_color_assets_and_reservations.assets",
		"rng_stream": "NONE",
	},
	"card_batch": {
		"core_port": "v07.card_batch.core_authority.v1#card_batch",
		"ai_port": "v07.card_batch.ai_observation.v1#card_batch",
		"player_port": "v07.card_batch.player_projection.v1#card_batch",
		"save_adapter": "V07CanonicalSaveAdapter#card_batch_and_anonymous_resolution.card_batch",
		"rng_stream": "NONE",
	},
	"asset_reservation": {
		"core_port": "v07.six_color_assets.core_authority.v1#asset_reservation",
		"ai_port": "v07.six_color_assets.ai_observation.v1#asset_reservation",
		"player_port": "v07.six_color_assets.player_projection.v1#asset_reservation",
		"save_adapter": "V07CanonicalSaveAdapter#six_color_assets_and_reservations.reservations",
		"rng_stream": "NONE",
	},
	"anonymous_resolution": {
		"core_port": "v07.card_batch.core_authority.v1#anonymous_resolution",
		"ai_port": "v07.card_batch.ai_observation.v1#anonymous_resolution",
		"player_port": "v07.card_batch.player_projection.v1#anonymous_resolution",
		"save_adapter": "V07CanonicalSaveAdapter#card_batch_and_anonymous_resolution.anonymous_resolution",
		"rng_stream": "NONE",
	},
	"solar_efficiency": {
		"core_port": "v07.solar_victory.core_authority.v1#solar_facility_efficiency_state_v1",
		"ai_port": "v07.solar_victory.ai_observation.v1#solar",
		"player_port": "v07.solar_victory.player_projection.v1#solar",
		"save_adapter": "V07CanonicalSaveAdapter#solar_facility_and_macro_victory.solar",
		"rng_stream": "NONE",
	},
	"macro_round_victory_gate": {
		"core_port": "v07.solar_victory.core_authority.v1#macro_round_victory_gate_state_v1",
		"ai_port": "v07.solar_victory.ai_observation.v1#victory_gate",
		"player_port": "v07.solar_victory.player_projection.v1#victory_gate",
		"save_adapter": "V07CanonicalSaveAdapter#solar_facility_and_macro_victory.victory_gate",
		"rng_stream": "NONE",
	},
}

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manifest := _load_json(MANIFEST_PATH, "atomic cutover manifest")
	if not manifest.is_empty():
		_test_top_level(manifest)
		_test_domains(manifest)
		_test_no_restore_dag_aliases()
	_test_markdown()
	_finish()


func _test_top_level(manifest: Dictionary) -> void:
	_expect(_same_key_set(manifest, TOP_LEVEL_KEYS), "manifest top-level keys are exact")
	_expect(
		int(manifest.get("schema_version", 0)) == 1
			and str(manifest.get("manifest_id", ""))
				== "space_syndicate.v07.atomic_cutover_manifest.v1"
			and str(manifest.get("lane", "")) == "B"
			and str(manifest.get("baseline_sha", "")) == BASELINE_SHA,
		"manifest identity, lane, and merged-kernel baseline are exact"
	)
	_expect(
		str(manifest.get("status", "")) == "DETACHED_ADAPTER_PREFLIGHT_READY"
			and str(manifest.get("canonical_adapter_implementation_status", ""))
				== "IMPLEMENTED_DETACHED_NOT_CONNECTED"
			and _is_false(manifest.get("production_cutover_authorized")),
		"implemented adapters remain detached and unauthorized for production cutover"
	)
	_expect(
		str(manifest.get("current_production_runtime_ruleset", "")) == "v0.6"
			and str(manifest.get("target_development_ruleset", "")) == "v0.7",
		"production remains V0.6 while V0.7 is the target"
	)
	_expect(
		_is_false(manifest.get("production_scene_change"))
			and _is_false(manifest.get("main_change"))
			and _is_false(manifest.get("dual_write_allowed")),
		"production scene, Main, and dual-write flags remain false"
	)
	_expect(
		_is_false(manifest.get("V06_SAVE_TO_V07_DIRECT_LOAD"))
			and str(manifest.get("v06_save_rejection_reason", ""))
				== "v06_save_backup_required"
			and _same_string_array(
				manifest.get("allowed_session_entrypoints"), ["NEW_V07_GAME"]
			),
		"V0.6 Save fails closed and NEW_V07_GAME is the only entrypoint"
	)
	_expect(
		_same_string_array(
			manifest.get("adapter_implementation_paths"), ADAPTER_IMPLEMENTATION_PATHS
		),
		"manifest inventories all five detached adapter implementation files"
	)
	for path in ADAPTER_IMPLEMENTATION_PATHS:
		_expect(FileAccess.file_exists("res://" + path), "adapter exists: %s" % path)
	_expect(
		_same_string_array(manifest.get("source_contracts"), SOURCE_CONTRACTS),
		"source contracts are exact and ordered"
	)
	for path in SOURCE_CONTRACTS:
		_expect(FileAccess.file_exists("res://" + path), "source contract exists: %s" % path)
	_expect(
		int(manifest.get("domain_count", 0)) == REQUIRED_DOMAIN_IDS.size()
			and _same_string_array(
				manifest.get("required_domain_ids"), REQUIRED_DOMAIN_IDS
			)
			and _same_string_array(
				manifest.get("domain_entry_required_fields"), DOMAIN_KEYS
			),
		"manifest declares the exact ten gameplay domains and exact fields"
	)


func _test_domains(manifest: Dictionary) -> void:
	var domains_variant: Variant = manifest.get("domains")
	_expect(domains_variant is Array, "domains is an array")
	if not domains_variant is Array:
		return
	var domains := domains_variant as Array
	_expect(domains.size() == REQUIRED_DOMAIN_IDS.size(), "domains has ten entries")
	var seen: Array[String] = []
	for index in domains.size():
		var domain_variant: Variant = domains[index]
		_expect(domain_variant is Dictionary, "domain %d is an object" % (index + 1))
		if not domain_variant is Dictionary:
			continue
		var domain := domain_variant as Dictionary
		var domain_id := str(domain.get("domain_id", ""))
		_expect(_same_key_set(domain, DOMAIN_KEYS), "%s fields are exact" % domain_id)
		_expect(
			index < REQUIRED_DOMAIN_IDS.size()
				and domain_id == REQUIRED_DOMAIN_IDS[index]
				and not seen.has(domain_id),
			"domain %d identity and order are exact" % (index + 1)
		)
		seen.append(domain_id)
		_test_domain_fields(domain_id, domain)
	_expect(seen == REQUIRED_DOMAIN_IDS, "domain set has no omission or invention")


func _test_domain_fields(domain_id: String, domain: Dictionary) -> void:
	for field in [
		"v06_current_owner",
		"v07_target_owner",
		"core_port",
		"ai_port",
		"player_port",
		"save_adapter",
		"pre_cutover_gate",
		"cutover_step",
		"rollback_step",
		"old_path_deletion_gate",
	]:
		_expect(
			domain.get(field) is String and not str(domain.get(field)).strip_edges().is_empty(),
			"%s has nonempty %s" % [domain_id, field]
		)
	var rng_value: Variant = domain.get("rng_stream")
	_expect(
		(rng_value is String and not str(rng_value).strip_edges().is_empty())
			or _nonempty_string_array(rng_value),
		"%s has an explicit RNG mapping" % domain_id
	)
	_expect(
		str(domain.get("pre_cutover_gate", "")).begins_with("PASS: ")
			and str(domain.get("cutover_step", "")).begins_with("APPLY: ")
			and str(domain.get("rollback_step", "")).begins_with("ROLLBACK: ")
			and str(domain.get("old_path_deletion_gate", "")).begins_with(
				"DELETE AFTER COMMIT: "
			),
		"%s declares explicit gate, apply, rollback, and deletion semantics" % domain_id
	)
	var expected := EXPECTED_BINDINGS.get(domain_id, {}) as Dictionary
	for field in ["core_port", "ai_port", "player_port", "save_adapter", "rng_stream"]:
		_expect(
			domain.get(field) == expected.get(field),
			"%s %s mapping is exact" % [domain_id, field]
		)
	_expect(
		_is_false(domain.get("production_scene_change"))
			and _is_false(domain.get("main_change"))
			and _is_false(domain.get("dual_write_allowed")),
		"%s has no production scene, Main, or dual-write authorization" % domain_id
	)


func _test_no_restore_dag_aliases() -> void:
	var source := FileAccess.get_file_as_string(MANIFEST_PATH)
	for alias in [
		"restore_order",
		"section_id",
		"depends_on",
		"save_port",
		"rng_port",
		"old_authority_deletion_gate",
	]:
		_expect(
			not source.contains("\"%s\"" % alias),
			"manifest contains no retired restore-DAG field %s" % alias
		)
	for old_domain in [
		"envelope_identity",
		"rng_stream_states",
		"atomic_restore_commit",
	]:
		_expect(
			not source.contains("\"domain_id\": \"%s\"" % old_domain),
			"manifest contains no restore-DAG domain %s" % old_domain
		)


func _test_markdown() -> void:
	_expect(FileAccess.file_exists(MARKDOWN_PATH), "Markdown companion exists")
	var markdown := FileAccess.get_file_as_string(MARKDOWN_PATH)
	_expect(not markdown.is_empty(), "Markdown companion is nonempty")
	for token in [
		"LANE=B",
		"STATUS=DETACHED_ADAPTER_PREFLIGHT_READY",
		"CANONICAL_ADAPTER_IMPLEMENTATION_STATUS=IMPLEMENTED_DETACHED_NOT_CONNECTED",
		"CURRENT_PRODUCTION_RUNTIME_RULESET=V0.6",
		"PRODUCTION_CUTOVER_AUTHORIZED=false",
		"V06_SAVE_TO_V07_DIRECT_LOAD=false",
		"V06_SAVE_REJECTION_REASON=v06_save_backup_required",
		"ALLOWED_SESSION_ENTRYPOINTS=[NEW_V07_GAME]",
		"PRODUCTION_SCENE_CHANGE=false",
		"MAIN_CHANGE=false",
		"DUAL_WRITE_ALLOWED=false",
	]:
		_expect(markdown.contains(token), "Markdown declares %s" % token)
	_expect(
		not markdown.contains("V06_SAVE_TO_V07_DIRECT_LOAD=true")
			and not markdown.contains("DUAL_WRITE_ALLOWED=true"),
		"Markdown contains no direct-load or dual-write authorization"
	)
	for index in REQUIRED_DOMAIN_IDS.size():
		var heading := "## %d. %s" % [index + 1, REQUIRED_DOMAIN_IDS[index]]
		var next_heading := (
			"## %d. %s" % [index + 2, REQUIRED_DOMAIN_IDS[index + 1]]
			if index + 1 < REQUIRED_DOMAIN_IDS.size()
			else "## Acceptance Gate"
		)
		var start := markdown.find(heading)
		var finish := markdown.find(next_heading, start + heading.length())
		_expect(
			start >= 0 and markdown.count(heading) == 1,
			"%s has one Markdown section" % REQUIRED_DOMAIN_IDS[index]
		)
		if start < 0 or finish <= start:
			continue
		var section := markdown.substr(start, finish - start)
		for label in [
			"**V0.6 current owner:**",
			"**V0.7 target owner:**",
			"**Core port:**",
			"**AI port:**",
			"**Player port:**",
			"**Save adapter:**",
			"**Pre-cutover gate:**",
			"**Cutover step:**",
			"**Rollback step:**",
			"**Old-path deletion gate:**",
			"**Task scope:**",
		]:
			_expect(
				section.contains(label),
				"%s Markdown includes %s" % [REQUIRED_DOMAIN_IDS[index], label]
			)
		_expect(
			(section.contains("**RNG stream:**")
				or section.contains("**RNG streams:**"))
				and section.contains("production_scene_change=false")
				and section.contains("main_change=false")
				and section.contains("dual_write_allowed=false"),
			"%s Markdown includes RNG and all false scope flags"
				% REQUIRED_DOMAIN_IDS[index]
		)


func _load_json(path: String, label: String) -> Dictionary:
	_expect(FileAccess.file_exists(path), "%s exists" % label)
	if not FileAccess.file_exists(path):
		return {}
	var source := FileAccess.get_file_as_string(path)
	var parser := JSON.new()
	var error := parser.parse(source)
	_expect(
		error == OK,
		"%s is strict JSON%s" % [
			label,
			" at line %d: %s" % [parser.get_error_line(), parser.get_error_message()]
				if error != OK else "",
		]
	)
	if error != OK:
		return {}
	_expect(parser.data is Dictionary, "%s root is an object" % label)
	return parser.data as Dictionary if parser.data is Dictionary else {}


func _same_key_set(value: Dictionary, expected: Array) -> bool:
	return _same_string_set(value.keys(), expected)


func _same_string_set(actual_variant: Variant, expected_variant: Variant) -> bool:
	if not actual_variant is Array or not expected_variant is Array:
		return false
	var actual: Array[String] = []
	for value in actual_variant as Array:
		actual.append(str(value))
	var expected: Array[String] = []
	for value in expected_variant as Array:
		expected.append(str(value))
	actual.sort()
	expected.sort()
	return actual == expected


func _same_string_array(actual_variant: Variant, expected_variant: Variant) -> bool:
	if not actual_variant is Array or not expected_variant is Array:
		return false
	var actual := actual_variant as Array
	var expected := expected_variant as Array
	if actual.size() != expected.size():
		return false
	for index in actual.size():
		if str(actual[index]) != str(expected[index]):
			return false
	return true


func _nonempty_string_array(value: Variant) -> bool:
	if not value is Array or (value as Array).is_empty():
		return false
	for entry in value as Array:
		if not entry is String or str(entry).strip_edges().is_empty():
			return false
	return true


func _is_false(value: Variant) -> bool:
	return value is bool and not bool(value)


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print(
			"V07_ATOMIC_CUTOVER_MANIFEST|status=PASS|checks=%d|domains=10|entry=NEW_V07_GAME"
			% _checks
		)
		print("V07_ATOMIC_CUTOVER_MANIFEST_READY | status=PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("V07_ATOMIC_CUTOVER_MANIFEST: %s" % failure)
	print(
		"V07_ATOMIC_CUTOVER_MANIFEST|status=FAIL|checks=%d|failures=%d"
		% [_checks, _failures.size()]
	)
	quit(1)
