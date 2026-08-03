extends SceneTree

const TRACK := preload(
	"res://scripts/v07_semantic/v07_unified_card_track_core.gd"
)
const DBG := preload("res://scripts/v07_semantic/v07_dbg_deck_core.gd")
const ASSET_BATCH := preload(
	"res://scripts/v07_semantic/v07_asset_batch_core.gd"
)
const SOLAR := preload(
	"res://scripts/v07_semantic/v07_solar_victory_core.gd"
)
const SAVE_ADAPTER := preload(
	"res://scripts/v07_adapters/v07_canonical_save_adapter.gd"
)
const RNG_ADAPTER := preload(
	"res://scripts/v07_adapters/v07_canonical_rng_adapter.gd"
)

const SAVE_PATH := "res://docs/save/v071_save_schema.json"
const RNG_PATH := "res://docs/save/v071_rng_ownership.json"
const RESTORE_PATH := "res://docs/save/v071_restore_dependency_graph.json"
const MATRIX_PATH := (
	"res://docs/migration/v07_to_v071_contract_version_matrix.json"
)
const REGISTRY_PATH := (
	"res://docs/semantic/v071_three_wing_domain_registry.json"
)
const REQUIRED_MATRIX_FIELDS := [
	"domain_id",
	"v07_interface_id",
	"v071_interface_id",
	"v07_state_version",
	"v071_state_version",
	"shape_changed",
	"semantic_changed",
	"save_changed",
	"ai_changed",
	"player_changed",
	"migration_allowed",
	"failure_reason",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var save := _load_json(SAVE_PATH)
	var rng := _load_json(RNG_PATH)
	var restore := _load_json(RESTORE_PATH)
	var matrix := _load_json(MATRIX_PATH)
	var registry := _load_json(REGISTRY_PATH)
	_test_save_contract(save)
	_test_rng_contract(rng)
	_test_restore_graph(restore)
	_test_version_matrix(matrix)
	_test_semantic_registry(registry)
	_finish()


func _test_save_contract(save: Dictionary) -> void:
	_expect(
		str(save.get("save_schema_id", "")) == SAVE_ADAPTER.SAVE_SCHEMA_ID
			and str(save.get("constitution_id", ""))
				== SAVE_ADAPTER.CONSTITUTION_ID
			and str(save.get("ruleset_id", "")) == "v0.7.1"
			and int(save.get("canonical_adapter_schema_version", 0))
				== SAVE_ADAPTER.SCHEMA_VERSION,
		"Save document binds the canonical V0.7.1 adapter identity"
	)
	var profile := save.get("balance_profile", {}) as Dictionary
	_expect(
		str(profile.get("profile_id", ""))
			== SAVE_ADAPTER.BALANCE_PROFILE_ID
			and str(profile.get("profile_fingerprint", ""))
				== SAVE_ADAPTER.BALANCE_PROFILE_FINGERPRINT
			and bool(profile.get("required_in_envelope", false))
			and bool(profile.get("required_in_affected_domain_state", false))
			and str(profile.get("mismatch_policy", "")) == "fail_closed",
		"Save document requires the approved profile at envelope and domain scope"
	)
	var migration := save.get("migration_policy", {}) as Dictionary
	_expect(
		not bool(migration.get("v07_save_to_v071_direct_resume", true))
			and not bool(migration.get("v06_save_to_v071_direct_resume", true))
			and bool(migration.get("v06_save_backup_required", false))
			and str(migration.get("missing_new_field_policy", ""))
				== "fail_closed"
			and str(migration.get("implicit_default_policy", ""))
				== "forbidden",
		"old saves and missing V0.7.1 fields fail closed"
	)
	var sections := _index_by(save.get("sections", []) as Array, "section_id")
	_expect(
		sections.size() == 5
			and int((sections.get("unified_card_track_cycle", {}) as Dictionary)
				.get("section_version", 0)) == TRACK.STATE_VERSION
			and int((sections.get("personal_dbg_and_merge", {}) as Dictionary)
				.get("section_version", 0)) == DBG.STATE_VERSION
			and int((sections.get("six_color_assets_and_reservations", {}) as Dictionary)
				.get("section_version", 0)) == ASSET_BATCH.STATE_VERSION
			and int((sections.get("card_batch_and_anonymous_resolution", {}) as Dictionary)
				.get("section_version", 0)) == ASSET_BATCH.STATE_VERSION
			and int((sections.get("solar_facility_and_macro_victory", {}) as Dictionary)
				.get("section_version", 0)) == SOLAR.SAVE_SECTION_VERSION,
		"all five Save sections bind their exact V0.7.1 domain versions"
	)
	var unified := sections.get("unified_card_track_cycle", {}) as Dictionary
	var unified_fields := unified.get("required_state_fields", []) as Array
	var item_fields := unified.get("required_track_item_fields", []) as Array
	_expect(
		_has_all(unified_fields, [
			"completed_batch_count",
			"lead_batch_cursor",
			"color_cycle_batch_cursor",
			"scroll_sequence",
			"balance_profile_id",
			"balance_profile_fingerprint",
		]) and _has_all(item_fields, ["level", "claimable_from_scroll_sequence"]),
		"unified Save contract closes batch cursors and replacement eligibility"
	)
	var dbg := sections.get("personal_dbg_and_merge", {}) as Dictionary
	_expect(
		_has_all(dbg.get("required_state_fields", []) as Array, [
			"normal_deck_minimum_count_rule_version",
			"local_queue_state",
			"balance_profile_id",
			"balance_profile_fingerprint",
		]) and _has_all(
			dbg.get("required_commodity_fields", []) as Array,
			["available_from_batch_id"]
		) and _has_all(
			dbg.get("required_local_queue_state_fields", []) as Array,
			["batch_id", "locked"]
		),
		"DBG Save contract closes minimum deck and commodity batch timing"
	)


func _test_rng_contract(rng: Dictionary) -> void:
	_expect(
		str(rng.get("registry_id", "")) == SAVE_ADAPTER.RNG_REGISTRY_ID
			and str(rng.get("canonical_adapter_id", ""))
				== RNG_ADAPTER.ADAPTER_ID
			and str(rng.get("ruleset_id", "")) == RNG_ADAPTER.RULESET_ID
			and not bool(rng.get("canonical_ledger_is_second_rng_authority", true))
			and int(rng.get("draw_api_count_in_adapter", -1)) == 0,
		"RNG document is a detached parity ledger, never a second RNG authority"
	)
	var versions := rng.get("required_owner_versions", {}) as Dictionary
	_expect(
		int(versions.get("unified_card_track_state_version", 0))
			== TRACK.STATE_VERSION
			and int(versions.get("personal_dbg_state_version", 0))
				== DBG.STATE_VERSION,
		"RNG document pins unified state 4 and DBG state 2"
	)
	var streams := rng.get("logical_streams", []) as Array
	_expect(
		streams == RNG_ADAPTER.logical_stream_ids()
			and streams.size() == 7,
		"RNG document and adapter expose the same exact seven streams"
	)
	var restore := rng.get("restore_policy", {}) as Dictionary
	_expect(
		bool(restore.get("owner_state_is_authoritative", false))
			and bool(restore.get("ledger_row_must_equal_embedded_owner_state", false))
			and bool(restore.get("wrong_profile_fingerprint_rejected_before_rng_restore", false))
			and not bool(restore.get("adapter_may_seed_advance_or_draw", true)),
		"RNG restore remains owner-bound and profile-fail-closed"
	)


func _test_restore_graph(graph: Dictionary) -> void:
	_expect(
		str(graph.get("ruleset_id", "")) == "v0.7.1"
			and str(graph.get("save_schema_id", "")) == SAVE_ADAPTER.SAVE_SCHEMA_ID
			and not bool(graph.get("production_runtime_connected", true))
			and bool(graph.get("all_preflight_before_apply", false))
			and bool(graph.get("checkpoint_before_apply", false))
			and bool(graph.get("reverse_rollback_on_failure", false))
			and int(graph.get("atomic_commit_count", 0)) == 1,
		"restore graph remains all-preflight, rollback-safe, detached, and atomic"
	)
	var profile := graph.get("balance_profile_preflight", {}) as Dictionary
	_expect(
		str(profile.get("profile_id", "")) == SAVE_ADAPTER.BALANCE_PROFILE_ID
			and str(profile.get("profile_fingerprint", ""))
				== SAVE_ADAPTER.BALANCE_PROFILE_FINGERPRINT
			and str(profile.get("mismatch_policy", ""))
				== "fail_closed_before_rng_restore",
		"restore graph rejects the wrong profile before RNG restore"
	)
	var nodes := _index_by(graph.get("nodes", []) as Array, "node_id")
	_expect(
		nodes.keys() == SAVE_ADAPTER.restore_node_ids()
			and (nodes.get("atomic_restore_commit", {}) as Dictionary)
				.get("depends_on", []) == [
					"rng_stream_states",
					"personal_dbg_and_merge",
					"hidden_lead_cycle",
					"unified_card_track_cycle",
					"six_color_assets_and_reservations",
					"card_batch_and_anonymous_resolution",
					"solar_facility_state",
					"macro_round_victory_gate",
				],
		"restore document and canonical adapter expose the same ordered graph"
	)


func _test_version_matrix(matrix: Dictionary) -> void:
	_expect(
		str(matrix.get("source_ruleset_id", "")) == "v0.7"
			and str(matrix.get("target_ruleset_id", "")) == "v0.7.1"
			and str(matrix.get("target_constitution_id", ""))
				== SAVE_ADAPTER.CONSTITUTION_ID
			and not bool(matrix.get("production_runtime_connected", true))
			and not bool(matrix.get("v07_save_to_v071_direct_resume", true))
			and not bool(matrix.get("v06_save_to_v071_direct_resume", true)),
		"version matrix is detached and forbids both direct-resume paths"
	)
	var rows := matrix.get("contracts", []) as Array
	var ids: Dictionary = {}
	var rows_valid := rows.size() >= 13
	for row_variant in rows:
		if not (row_variant is Dictionary):
			rows_valid = false
			continue
		var row := row_variant as Dictionary
		if not _exact_fields(row, REQUIRED_MATRIX_FIELDS):
			rows_valid = false
		var domain_id := str(row.get("domain_id", ""))
		if domain_id.is_empty() or ids.has(domain_id):
			rows_valid = false
		ids[domain_id] = true
		if bool(row.get("migration_allowed", true)) \
				or str(row.get("failure_reason", "")).is_empty():
			rows_valid = false
	_expect(rows_valid, "version matrix has unique closed fail-closed rows")
	_expect(
		_has_all(ids.keys(), [
			"unified_track_core",
			"market_color_cycle",
			"hidden_lead_cycle",
			"personal_dbg",
			"commodity_inventory",
			"six_color_assets",
			"asset_cycle_snapshot",
			"card_batch",
			"anonymous_resolution",
			"ai_observation",
			"player_projection",
			"save_state",
			"canonical_rng_adapter",
			"canonical_adapter_manifest",
		]),
		"version matrix covers every required Core, projection, Save, and adapter domain"
	)


func _test_semantic_registry(registry: Dictionary) -> void:
	_expect(
		str(registry.get("registry_id", ""))
			== "space_syndicate.v071.three_wing_domain_registry"
			and str(registry.get("constitution_id", ""))
				== SAVE_ADAPTER.CONSTITUTION_ID
			and str(registry.get("ruleset_id", "")) == "v0.7.1"
			and int(registry.get("production_runtime_connection_count", -1)) == 0
			and int(registry.get("v06_mutation_count", -1)) == 0
			and int(registry.get("dual_write_count", -1)) == 0
			and not bool(registry.get("human_fun_proven", true))
			and bool(registry.get("human_test_required", false)),
		"semantic registry is the frozen detached V0.7.1 target"
	)
	var domains := _index_by(registry.get("domains", []) as Array, "domain_id")
	_expect(domains.size() == 5, "semantic registry has exactly five Core domains")
	var track := domains.get("unified_card_track_cycle", {}) as Dictionary
	var track_interfaces := track.get("interfaces", {}) as Dictionary
	var dbg := domains.get("personal_dbg_and_merge", {}) as Dictionary
	var dbg_interfaces := dbg.get("interfaces", {}) as Dictionary
	var asset := domains.get("six_color_assets", {}) as Dictionary
	var asset_interfaces := asset.get("interfaces", {}) as Dictionary
	var batch := domains.get(
		"card_batch_and_anonymous_resolution", {}
	) as Dictionary
	var batch_interfaces := batch.get("interfaces", {}) as Dictionary
	var solar := domains.get(
		"solar_facility_and_macro_victory", {}
	) as Dictionary
	var solar_interfaces := solar.get("interfaces", {}) as Dictionary
	_expect(
		int(track.get("state_version", 0)) == TRACK.STATE_VERSION
			and track_interfaces.get("core") == TRACK.CORE_INTERFACE_ID
			and track_interfaces.get("ai_observation") == TRACK.AI_INTERFACE_ID
			and track_interfaces.get("player_projection")
				== TRACK.PLAYER_INTERFACE_ID
			and track_interfaces.get("save_state") == TRACK.SAVE_INTERFACE_ID,
		"semantic registry binds every unified-track V0.7.1 interface"
	)
	_expect(
		int(dbg.get("state_version", 0)) == DBG.STATE_VERSION
			and dbg_interfaces.get("core") == DBG.CORE_AUTHORITY_SCHEMA_ID
			and dbg_interfaces.get("ai_observation") == DBG.AI_OBSERVATION_SCHEMA_ID
			and dbg_interfaces.get("player_projection")
				== DBG.PLAYER_PROJECTION_SCHEMA_ID
			and dbg_interfaces.get("save_state") == DBG.SAVE_SCHEMA_ID,
		"semantic registry binds every personal-DBG V0.7.1 interface"
	)
	_expect(
		int(asset.get("state_version", 0)) == ASSET_BATCH.STATE_VERSION
			and asset_interfaces.get("core")
				== ASSET_BATCH.ASSET_CORE_AUTHORITY_ID
			and asset_interfaces.get("save_state")
				== ASSET_BATCH.ASSET_SAVE_STATE_ID
			and int(batch.get("state_version", 0)) == ASSET_BATCH.STATE_VERSION
			and batch_interfaces.get("core")
				== ASSET_BATCH.BATCH_CORE_AUTHORITY_ID
			and batch_interfaces.get("save_state")
				== ASSET_BATCH.BATCH_SAVE_STATE_ID,
		"semantic registry binds asset and batch V0.7.1 contracts"
	)
	_expect(
		int(solar.get("state_version", 0)) == SOLAR.SCHEMA_VERSION
			and int(solar.get("save_section_version", 0))
				== SOLAR.SAVE_SECTION_VERSION
			and solar_interfaces.get("core") == SOLAR.CORE_INTERFACE_ID
			and solar_interfaces.get("save_state") == SOLAR.SAVE_INTERFACE_ID,
		"semantic registry binds solar/victory V0.7.1 contracts"
	)


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_expect(parsed is Dictionary, "strict JSON parses: %s" % path)
	return parsed as Dictionary if parsed is Dictionary else {}


func _index_by(rows: Array, field: String) -> Dictionary:
	var result: Dictionary = {}
	for row_variant in rows:
		if row_variant is Dictionary:
			var row := row_variant as Dictionary
			result[str(row.get(field, ""))] = row
	return result


func _has_all(actual: Array, required: Array) -> bool:
	for value in required:
		if not actual.has(value):
			return false
	return true


func _exact_fields(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for field in expected:
		if not value.has(field):
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error("V071_SAVE_RNG_CONTRACT: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("V071_SAVE_RNG_CONTRACT|status=pass|checks=%d" % _checks)
		quit(0)
		return
	print("V071_SAVE_RNG_CONTRACT|status=fail|checks=%d|failures=%d" % [
		_checks,
		_failures.size(),
	])
	quit(1)
