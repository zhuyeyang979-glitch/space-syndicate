extends SceneTree

const MANIFEST_PATH := "res://docs/migration/v07_atomic_cutover_manifest.json"
const MARKDOWN_PATH := "res://docs/migration/v07_atomic_cutover_manifest.md"
const BASELINE_SHA := "794ccf010e661a4750efca20a4e0d2a5839b7f2b"
const DOMAIN_IDS := [
	"ruleset_identity",
	"new_game_setup",
	"free_starter_deck",
	"personal_dbg",
	"optional_merge",
	"unified_track",
	"track_replacement_lock",
	"six_color_asset",
	"submission_window",
	"prebound_target",
	"full_asset_reservation",
	"fixed_hidden_round_robin",
	"facility_contention",
	"solar_efficiency",
	"ai_observation_decision",
	"player_projection",
	"victory_macro_round_gate",
	"final_settlement",
	"commercial_art_presentation",
]
const DOMAIN_FIELDS := [
	"domain_id",
	"status",
	"production_owner",
	"legacy_status",
	"save_owner_declared",
	"rng_owner_declared",
	"ai_adapter_connected",
	"player_adapter_connected",
	"ui_surface_connected",
	"rollback_boundary_declared",
]
const LEGACY_COUNT_FIELDS := [
	"v06_rule_owner_count",
	"v06_ai_policy_count",
	"v06_player_projection_count",
	"v06_card_supply_count",
	"v06_resolution_order_count",
	"v06_asset_refresh_count",
	"v06_public_bid_reference_count",
	"v06_auction_timer_reference_count",
	"v06_region_supply_purchase_surface_count",
	"v06_right_permanent_panel_count",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manifest := _load_json(MANIFEST_PATH)
	if not manifest.is_empty():
		_test_identity(manifest)
		_test_sample_boundary(manifest)
		_test_domains(manifest)
		_test_legacy_disconnect(manifest)
	_test_markdown()
	_finish()


func _test_identity(manifest: Dictionary) -> void:
	_expect(int(manifest.get("schema_version", 0)) == 5, "schema version is 5")
	_expect(
		str(manifest.get("manifest_id", ""))
			== "space_syndicate.v073.atomic_cutover_manifest"
			and str(manifest.get("constitution_id", ""))
				== "space_syndicate.v073.complete"
			and str(manifest.get("baseline_sha", "")) == BASELINE_SHA,
		"manifest identity and baseline are exact"
	)
	_expect(
		str(manifest.get("status", "")) == "V073_SAMPLE_PRODUCTION_CONNECTED"
			and str(manifest.get("current_production_runtime_ruleset", ""))
				== "v0.7.3"
			and bool(manifest.get("production_cutover_authorized", false))
			and bool(manifest.get("production_scene_change", false))
			and bool(manifest.get("main_change", false)),
		"V0.7.3 production cutover is explicit"
	)
	_expect(
		str(manifest.get("main_scene", "")) == "res://scenes/main.tscn"
			and str(manifest.get("runtime_composition", ""))
				== "res://scenes/runtime/V073RuntimeComposition.tscn"
			and str(manifest.get("player_surface", ""))
				== "res://scenes/ui/V073SampleGameScreen.tscn",
		"production scene bindings are exact"
	)


func _test_sample_boundary(manifest: Dictionary) -> void:
	_expect(
		str(manifest.get("sample_mode_id", "")) == "NEW_V073_GAME"
			and bool(manifest.get("new_game_only", false))
			and not bool(manifest.get("save_resume_enabled", true))
			and not bool(manifest.get("save_adapter_connected", true)),
		"sample is new-game-only with persistence detached"
	)
	for field in [
		"v06_save_file_delete_count",
		"v06_save_file_overwrite_count",
		"v073_v06_save_apply_count",
		"v073_save_dual_write_count",
	]:
		_expect(int(manifest.get(field, -1)) == 0, "%s is zero" % field)
	_expect(
		not bool(manifest.get("dual_write_allowed", true))
			and int(manifest.get("v073_dual_write_count", -1)) == 0
			and int(manifest.get("v073_legacy_fallback_count", -1)) == 0
			and int(manifest.get("v073_mixed_ruleset_state_count", -1)) == 0
			and int(manifest.get("v073_v06_runtime_mutation_count", -1)) == 0,
		"dual write, fallback, mixed rules, and V0.6 mutation are zero"
	)


func _test_domains(manifest: Dictionary) -> void:
	_expect(
		int(manifest.get("domain_count", 0)) == DOMAIN_IDS.size()
			and int(manifest.get("v073_production_connection_count", 0))
				== DOMAIN_IDS.size()
			and manifest.get("required_domain_ids") == DOMAIN_IDS,
		"all nineteen required domains are connected"
	)
	var domains_variant: Variant = manifest.get("domains")
	_expect(domains_variant is Array, "domains is an array")
	if not domains_variant is Array:
		return
	var domains := domains_variant as Array
	_expect(domains.size() == DOMAIN_IDS.size(), "domain entry count is nineteen")
	var seen: Array[String] = []
	for index in range(domains.size()):
		var domain_variant: Variant = domains[index]
		_expect(domain_variant is Dictionary, "domain %d is an object" % index)
		if not domain_variant is Dictionary:
			continue
		var domain := domain_variant as Dictionary
		var domain_id := str(domain.get("domain_id", ""))
		_expect(_same_string_set(domain.keys(), DOMAIN_FIELDS), "%s fields are exact" % domain_id)
		_expect(
			index < DOMAIN_IDS.size() and domain_id == DOMAIN_IDS[index]
				and not seen.has(domain_id),
			"domain %d identity and order are exact" % index
		)
		seen.append(domain_id)
		_expect(
			str(domain.get("status", "")) == "connected"
				and str(domain.get("legacy_status", "")) == "disconnected",
			"%s is connected with legacy disconnected" % domain_id
		)
		for field in [
			"production_owner",
			"save_owner_declared",
			"rng_owner_declared",
			"rollback_boundary_declared",
		]:
			_expect(not str(domain.get(field, "")).strip_edges().is_empty(), "%s declares %s" % [domain_id, field])
		for field in ["ai_adapter_connected", "player_adapter_connected", "ui_surface_connected"]:
			_expect(domain.get(field) is bool, "%s declares boolean %s" % [domain_id, field])
	_expect(seen == DOMAIN_IDS, "domain set has no omission or invention")
	_expect(_domain_flag(domains, "ai_observation_decision", "ai_adapter_connected"), "AI adapter domain is connected")
	_expect(_domain_flag(domains, "player_projection", "player_adapter_connected"), "player adapter domain is connected")
	_expect(_domain_flag(domains, "commercial_art_presentation", "ui_surface_connected"), "commercial art UI domain is connected")


func _test_legacy_disconnect(manifest: Dictionary) -> void:
	var counts := manifest.get("legacy_production_paths", {}) as Dictionary
	_expect(_same_string_set(counts.keys(), LEGACY_COUNT_FIELDS), "legacy count fields are exact")
	for field in LEGACY_COUNT_FIELDS:
		_expect(int(counts.get(field, -1)) == 0, "%s is zero" % field)


func _test_markdown() -> void:
	_expect(FileAccess.file_exists(MARKDOWN_PATH), "Markdown companion exists")
	var markdown := FileAccess.get_file_as_string(MARKDOWN_PATH)
	for token in [
		"STATUS=V073_SAMPLE_PRODUCTION_CONNECTED",
		"CURRENT_PRODUCTION_RUNTIME_RULESET=V0.7.3",
		"PRODUCTION_CUTOVER_AUTHORIZED=true",
		"NEW_GAME_ONLY=true",
		"SAVE_RESUME_ENABLED=false",
		"V073_ATOMIC_CUTOVER_DOMAIN_COUNT=19",
		"V073_CONNECTED_DOMAIN_COUNT=19",
		"V073_DUAL_WRITE_COUNT=0",
		"V073_LEGACY_FALLBACK_COUNT=0",
	]:
		_expect(markdown.contains(token), "Markdown declares %s" % token)


func _domain_flag(domains: Array, domain_id: String, field: String) -> bool:
	for domain_variant in domains:
		if domain_variant is Dictionary:
			var domain := domain_variant as Dictionary
			if str(domain.get("domain_id", "")) == domain_id:
				return bool(domain.get(field, false))
	return false


func _load_json(path: String) -> Dictionary:
	_expect(FileAccess.file_exists(path), "%s exists" % path)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_expect(parsed is Dictionary, "%s parses as a JSON object" % path)
	return parsed as Dictionary if parsed is Dictionary else {}


func _same_string_set(actual: Array, expected: Array) -> bool:
	var left: Array[String] = []
	var right: Array[String] = []
	for value in actual:
		left.append(str(value))
	for value in expected:
		right.append(str(value))
	left.sort()
	right.sort()
	return left == right


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	var passed := _failures.is_empty()
	print("V073_ATOMIC_CUTOVER_MANIFEST|status=%s|checks=%d|failures=%d|connected=19|dual_write=0|legacy_fallback=0|details=%s" % [
		"PASS" if passed else "FAIL",
		_checks,
		_failures.size(),
		JSON.stringify(_failures),
	])
	quit(0 if passed else 1)
