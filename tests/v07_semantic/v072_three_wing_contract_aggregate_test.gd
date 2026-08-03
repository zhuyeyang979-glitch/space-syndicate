extends SceneTree

const CARD_DEFINITIONS := preload(
	"res://scripts/v07_semantic/v072_card_definition_registry.gd"
)
const TRACK_CORE := preload(
	"res://scripts/v07_semantic/v07_unified_card_track_core.gd"
)
const DBG_CORE := preload("res://scripts/v07_semantic/v07_dbg_deck_core.gd")
const ASSET_BATCH_CORE := preload(
	"res://scripts/v07_semantic/v07_asset_batch_core.gd"
)
const SOLAR_CORE := preload(
	"res://scripts/v07_semantic/v07_solar_victory_core.gd"
)
const SAVE_ADAPTER := preload(
	"res://scripts/v07_adapters/v07_canonical_save_adapter.gd"
)
const RNG_ADAPTER := preload(
	"res://scripts/v07_adapters/v07_canonical_rng_adapter.gd"
)
const AI_ADAPTER := preload(
	"res://scripts/v07_adapters/v07_canonical_ai_observation_adapter.gd"
)
const PLAYER_ADAPTER := preload(
	"res://scripts/v07_adapters/v07_canonical_player_projection_adapter.gd"
)

const MATRIX_PATH := "res://docs/migration/v071_to_v072_contract_version_matrix.json"
const SAVE_PATH := "res://docs/save/v072_save_schema.json"
const RNG_PATH := "res://docs/save/v072_rng_ownership.json"
const RESTORE_PATH := "res://docs/save/v072_restore_dependency_graph.json"
const REGISTRY_PATH := "res://docs/semantic/v072_three_wing_domain_registry.json"
const MANIFEST_PATH := "res://docs/migration/v07_atomic_cutover_manifest.json"

const RULESET_ID := "v0.7.2"
const CONSTITUTION_ID := "space_syndicate.v072.complete"
const PROFILE_ID := "V072_STARTER_FREE_FAST"
const PROFILE_FINGERPRINT := (
	"b8f684ab92b06fa44671c38d041ff08b9c1ea7c2950b094705e19192f0a70f48"
)
const ROSTER := ["player.alpha", "player.beta", "player.gamma"]
const REQUIRED_MATRIX_DOMAINS := [
	"unified_track_core",
	"market_color_cycle",
	"hidden_lead_cycle",
	"card_definition_registry",
	"personal_dbg",
	"normal_hand",
	"normal_draw_pile",
	"normal_discard",
	"committed_escrow",
	"normal_merge",
	"six_color_assets",
	"balance_profile",
	"ai_observation",
	"player_projection",
	"save_state",
	"canonical_rng_adapter",
	"canonical_adapter_manifest",
]
const LOGICAL_RNG_STREAMS := [
	"starter_deck_shuffle",
	"normal_deck_reshuffle_by_player",
	"unified_track_type_draw",
	"unified_track_color_draw",
	"unified_track_normal_card_draw",
	"unified_track_commodity_draw",
	"initial_hidden_lead_order",
]
const RESTORE_NODE_ORDER := [
	"envelope_identity",
	"rng_stream_states",
	"personal_dbg_and_merge",
	"hidden_lead_cycle",
	"unified_card_track_cycle",
	"six_color_assets_and_reservations",
	"card_batch_and_anonymous_resolution",
	"solar_facility_state",
	"macro_round_victory_gate",
	"atomic_restore_commit",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_matrix(_load_json(MATRIX_PATH))
	_test_save(_load_json(SAVE_PATH))
	_test_rng(_load_json(RNG_PATH))
	_test_restore(_load_json(RESTORE_PATH))
	_test_registry(_load_json(REGISTRY_PATH))
	_test_executable_starter_contracts()
	_test_adapter_and_manifest_contracts()
	_finish()


func _test_matrix(matrix: Dictionary) -> void:
	_expect(
		matrix.get("matrix_id")
			== "space_syndicate.v071_to_v072.contract_version_matrix.v1"
			and matrix.get("source_ruleset_id") == "v0.7.1"
			and matrix.get("target_ruleset_id") == RULESET_ID
			and matrix.get("target_constitution_id") == CONSTITUTION_ID,
		"version matrix binds the frozen V0.7.1 to V0.7.2 amendment"
	)
	_expect(
		matrix.get("production_runtime_connected") == false
			and matrix.get("v071_save_to_v072_direct_resume") == false
			and matrix.get("v06_save_to_v072_direct_resume") == false,
		"version matrix remains detached and forbids both direct resumes"
	)
	var contracts := matrix.get("contracts", []) as Array
	var observed: Array[String] = []
	var rows_closed := contracts.size() == REQUIRED_MATRIX_DOMAINS.size()
	for row_variant in contracts:
		if not (row_variant is Dictionary):
			rows_closed = false
			continue
		var row := row_variant as Dictionary
		observed.append(str(row.get("domain_id", "")))
		rows_closed = rows_closed \
			and _has_exact_fields(row, [
				"domain_id", "v071_interface_id", "v072_interface_id",
				"v071_state_version", "v072_state_version", "shape_changed",
				"semantic_changed", "save_changed", "ai_changed",
				"player_changed", "migration_allowed", "failure_reason",
			]) \
			and row.get("migration_allowed") == false \
			and not str(row.get("failure_reason", "")).is_empty()
	_expect(
		rows_closed and _same_string_set(observed, REQUIRED_MATRIX_DOMAINS),
		"all 17 affected contracts are closed, versioned, and fail migration"
	)


func _test_save(schema: Dictionary) -> void:
	_expect(
		schema.get("save_schema_id") == "space_syndicate.v072.semantic_save.v2"
			and schema.get("constitution_id") == CONSTITUTION_ID
			and schema.get("ruleset_id") == RULESET_ID
			and schema.get("production_runtime_connected") == false,
		"Save schema is V0.7.2-only and detached"
	)
	var profile := schema.get("balance_profile", {}) as Dictionary
	_expect(
		profile.get("profile_id") == PROFILE_ID
			and profile.get("profile_fingerprint") == PROFILE_FINGERPRINT
			and profile.get("mismatch_policy") == "fail_closed_before_rng_restore",
		"Save preflight requires the exact Starter profile before RNG restore"
	)
	var migration := schema.get("migration_policy", {}) as Dictionary
	_expect(
		migration.get("v071_save_to_v072_direct_resume") == false
			and migration.get("v06_save_to_v072_direct_resume") == false
			and migration.get("v06_save_backup_required") == true
			and migration.get("implicit_default_policy") == "forbidden",
		"Save migration fails closed without silent Starter defaults"
	)
	_expect(
		_same_string_set(schema.get("card_identity_fields", []) as Array, [
			"card_definition_id", "card_instance_id", "origin_class",
			"asset_cost_profile", "level", "merge_family_id",
		])
			and schema.get("starter_identity_inferred_from_cost") == false,
		"Save preserves stable card identity and never infers Starter from cost"
	)
	var expected_sections := {
		"unified_card_track_cycle": [5, "v072.unified_track.save_state.v3"],
		"personal_dbg_and_merge": [3, "v072.personal_dbg.save_state.v3"],
		"six_color_assets_and_reservations": [3, "v072.six_color_assets.save_state.v3"],
		"card_batch_and_anonymous_resolution": [3, "v072.card_batch.save_state.v3"],
		"solar_facility_and_macro_victory": [5, "v072.solar_victory.save_state.v3"],
	}
	var sections := schema.get("sections", []) as Array
	var sections_ready := sections.size() == expected_sections.size()
	for row_variant in sections:
		var row := row_variant as Dictionary if row_variant is Dictionary else {}
		var expected := expected_sections.get(str(row.get("section_id", "")), []) as Array
		sections_ready = sections_ready and expected.size() == 2 \
			and row.get("section_version") == expected[0] \
			and row.get("interface_id") == expected[1]
	_expect(sections_ready, "all five V0.7.2 Save sections use exact new versions")


func _test_rng(registry: Dictionary) -> void:
	_expect(
		registry.get("registry_id") == "space_syndicate.v072.rng_ownership.v2"
			and registry.get("ruleset_id") == RULESET_ID
			and registry.get("production_runtime_connected") == false,
		"RNG registry is the detached V0.7.2 authority map"
	)
	_expect(
		registry.get("logical_streams") == LOGICAL_RNG_STREAMS
			and registry.get("new_rng_stream_count_from_v071") == 0
			and registry.get("starter_cost_rng_stream_count") == 0,
		"Starter bootstrap reuses seven streams and adds no cost RNG"
	)
	var versions := registry.get("required_owner_versions", {}) as Dictionary
	_expect(
		versions.get("unified_card_track_schema_version") == 2
			and versions.get("unified_card_track_state_version") == 5
			and versions.get("personal_dbg_schema_version") == 3
			and versions.get("personal_dbg_state_version") == 3,
		"RNG adapter binds the real, independently versioned owner schemas"
	)
	var policy := registry.get("restore_policy", {}) as Dictionary
	_expect(
		policy.get("owner_state_is_authoritative") == true
			and policy.get("adapter_may_seed_advance_or_draw") == false
			and policy.get("restore_advances_rng_draw_count") == 0,
		"canonical RNG rows remain non-authoritative and restore draws zero"
	)


func _test_restore(graph: Dictionary) -> void:
	_expect(
		graph.get("graph_id") == "space_syndicate.v072.detached_restore_graph.v2"
			and graph.get("save_schema_id") == "space_syndicate.v072.semantic_save.v2"
			and graph.get("production_runtime_connected") == false,
		"restore graph binds the detached V0.7.2 Save schema"
	)
	_expect(
		graph.get("all_preflight_before_apply") == true
			and graph.get("checkpoint_before_apply") == true
			and graph.get("reverse_rollback_on_failure") == true
			and graph.get("atomic_commit_count") == 1,
		"restore remains one checkpointed all-preflight atomic transaction"
	)
	var observed: Array[String] = []
	for node_variant in graph.get("nodes", []) as Array:
		if node_variant is Dictionary:
			observed.append(str((node_variant as Dictionary).get("node_id", "")))
	_expect(observed == RESTORE_NODE_ORDER, "restore graph keeps exact topological order")
	_expect(
		(graph.get("envelope_identity_preflight", []) as Array).has(
			"closed_card_definition_registry"
		)
			and (graph.get("envelope_identity_preflight", []) as Array).has(
				"starter_identity_not_inferred_from_cost"
			),
		"restore validates Starter identity before applying any owner"
	)


func _test_registry(registry: Dictionary) -> void:
	_expect(
		registry.get("registry_id") == "space_syndicate.v072.three_wing_domain_registry"
			and registry.get("constitution_id") == CONSTITUTION_ID
			and registry.get("ruleset_id") == RULESET_ID,
		"three-wing registry binds the frozen V0.7.2 constitution"
	)
	_expect(
		registry.get("current_production_runtime_ruleset") == "v0.6"
			and registry.get("production_runtime_connection_count") == 0
			and registry.get("v06_mutation_count") == 0
			and registry.get("dual_write_count") == 0,
		"three-wing registry has zero production connection, mutation, or dual write"
	)
	_expect(
		registry.get("balance_profile_id") == PROFILE_ID
			and registry.get("balance_profile_fingerprint") == PROFILE_FINGERPRINT
			and registry.get("human_fun_proven") == false
			and registry.get("human_test_required") == true,
		"registry freezes Starter profile while keeping human fun unproven"
	)
	var domains := registry.get("domains", []) as Array
	_expect(domains.size() == 5, "registry has exactly five detached semantic domains")
	var interfaces := {}
	for row_variant in domains:
		if row_variant is Dictionary:
			interfaces[str((row_variant as Dictionary).get("domain_id", ""))] = (
				row_variant as Dictionary
			).get("interfaces", {})
	_expect(
		(interfaces.get("unified_card_track_cycle", {}) as Dictionary).get("core")
			== TRACK_CORE.CORE_INTERFACE_ID
			and (interfaces.get("personal_dbg_and_merge", {}) as Dictionary).get("core")
				== DBG_CORE.CORE_AUTHORITY_SCHEMA_ID
			and (interfaces.get("personal_dbg_and_merge", {}) as Dictionary).get(
				"legal_target_input"
			) == DBG_CORE.LEGAL_TARGET_INPUT_INTERFACE_ID,
		"registry matches executable Track, DBG, and legal-target interfaces"
	)


func _test_executable_starter_contracts() -> void:
	var card_contract := CARD_DEFINITIONS.registry_contract()
	_expect(
		card_contract.get("starter_definition_count") == 12
			and card_contract.get("starter_creation_allowed_after_genesis") == false
			and card_contract.get("starter_track_spawn_allowed") == false
			and card_contract.get("starter_standard_l1_merge_allowed") == true
			and card_contract.get("starter_zero_cost_privilege_inherited") == false,
		"definition registry freezes 12 genesis-only free Starter cards"
	)
	var starters := CARD_DEFINITIONS.starter_definitions()
	var starter_rows_ready := starters.size() == 12
	for row_variant in starters:
		var row := row_variant as Dictionary
		starter_rows_ready = starter_rows_ready \
			and row.get("origin_class") == "starter_bootstrap" \
			and row.get("primary_asset_cost") == 0 \
			and row.get("starter_badge") == true \
			and row.get("track_spawn_allowed") == false \
			and not row.has("starter_badge_asset_key")
	_expect(starter_rows_ready, "Core Starter definitions are free and presentation-key agnostic")
	var track_ids := CARD_DEFINITIONS.track_spawn_definition_ids()
	var track_ready := track_ids.size() == 12
	for definition_id in track_ids:
		var row := CARD_DEFINITIONS.definition(str(definition_id))
		track_ready = track_ready \
			and row.get("origin_class") == "standard" \
			and row.get("level") == 1 \
			and row.get("primary_asset_cost") == 1 \
			and row.get("track_spawn_allowed") == true
	_expect(track_ready, "Track registry exposes only paid standard L1 definitions")

	var assets := ASSET_BATCH_CORE.create_genesis_state(
		"batch.v072.genesis",
		ROSTER,
		ROSTER,
		0,
		1000
	)
	var asset_snapshot := ASSET_BATCH_CORE.contract_snapshot()
	_expect(
		not assets.is_empty()
			and bool(ASSET_BATCH_CORE.validation_report(assets).get("valid", false))
			and asset_snapshot.get("initial_assets_per_color") == 0
			and asset_snapshot.get("initial_remainder_milli_per_color") == 0
			and asset_snapshot.get("asset_owner_created_at_genesis") == true,
		"six-color owner exists with zero balances and remainders at genesis"
	)

	var dbg := DBG_CORE.new()
	var started := dbg.initialize(ROSTER[0], 900626424)
	var player := dbg.player_projection(ROSTER[0])
	var player_facts := player.get("facts", {}) as Dictionary
	var targets := {}
	var target_index := 0
	for zone_name in ["hand", "discard"]:
		for card_variant in player_facts.get(zone_name, []) as Array:
			var instance_id := str((card_variant as Dictionary).get("instance_id", ""))
			targets[instance_id] = ["region.aggregate.%02d" % target_index]
			target_index += 1
	var legal_input := dbg.build_legal_target_input(
		ROSTER[0],
		"v072.map.legal_target_authority.detached",
		4,
		targets
	)
	var ai := dbg.ai_observation(ROSTER[0], legal_input)
	var ai_hand := (ai.get("facts", {}) as Dictionary).get("hand", []) as Array
	var ai_rows_ready := ai_hand.size() == 5
	for card_variant in ai_hand:
		var card := card_variant as Dictionary
		ai_rows_ready = ai_rows_ready \
			and card.has("definition_id") \
			and card.has("origin_class") \
			and card.has("asset_cost") \
			and card.has("merge_family_id") \
			and card.has("level") \
			and (card.get("legal_targets", []) as Array).size() == 1
	_expect(
		bool(started.get("initialized", false))
			and started.get("starter_card_instance_count") == 12
			and started.get("opening_hand_starter_card_count") == 5
			and started.get("opening_hand_asset_affordable_card_count") == 5
			and ai_rows_ready
			and DBG_CORE.projection_is_private_safe(ai),
		"DBG opens five affordable Starter cards and AI receives attested own-card legality"
	)
	_expect(
		dbg.ai_observation(ROSTER[0]).is_empty()
			and dbg.ai_observation(ROSTER[1], legal_input).is_empty()
			and dbg.player_projection(ROSTER[1]).is_empty(),
		"missing legality and rival viewers fail closed without hidden-card leakage"
	)
	_expect(
		DBG_CORE.validate_save_state({"ruleset_id": "v0.7.1"})
			== "save_state_fields_invalid",
		"V0.7.1 detached Save cannot silently resume as V0.7.2"
	)


func _test_adapter_and_manifest_contracts() -> void:
	var save_contract := SAVE_ADAPTER.adapter_contract()
	var rng_contract := RNG_ADAPTER.adapter_contract()
	_expect(
		save_contract.get("save_schema_id") == "space_syndicate.v072.semantic_save.v2"
			and save_contract.get("target_ruleset_id") == RULESET_ID
			and save_contract.get("v06_direct_resume_allowed") == false
			and save_contract.get("v07_direct_resume_allowed") == false
			and save_contract.get("v071_direct_resume_allowed") == false
			and save_contract.get("production_runtime_connected") == false,
		"canonical Save adapter targets V0.7.2 and rejects historical direct resume"
	)
	_expect(
		rng_contract.get("adapter_id") == "space_syndicate.v072.canonical_rng_adapter.v2"
			and rng_contract.get("target_ruleset_id") == RULESET_ID
			and rng_contract.get("v071_direct_resume_allowed") == false
			and rng_contract.get("draw_api_count") == 0
			and rng_contract.get("production_runtime_connection_count") == 0,
		"canonical RNG adapter targets V0.7.2 without becoming an owner"
	)
	_expect(
		AI_ADAPTER.ADAPTER_ID == "v072.canonical.ai_observation_adapter.v3"
			and PLAYER_ADAPTER.ADAPTER_ID
				== "v072.canonical.player_projection_adapter.v3"
			and PLAYER_ADAPTER.presentation_asset_contract().has({
				"asset_key": "card.badge.starter",
			}),
		"AI and Player adapters use V0.7.2 contracts and the stable Starter badge key"
	)
	var manifest := _load_json(MANIFEST_PATH)
	var domains := manifest.get("domains", []) as Array
	var no_dual_write := domains.size() == 10
	for row_variant in domains:
		no_dual_write = no_dual_write \
			and row_variant is Dictionary \
			and (row_variant as Dictionary).get("dual_write_allowed") == false
	_expect(
		manifest.get("manifest_id") == "space_syndicate.v072.atomic_cutover_manifest"
			and manifest.get("target_development_ruleset") == RULESET_ID
			and (manifest.get("required_v072_pre_cutover_gates", []) as Array).size() == 16
			and manifest.get("v072_production_connection_count") == 0
			and manifest.get("v072_v06_mutation_count") == 0
			and manifest.get("v072_dual_write_count") == 0
			and no_dual_write,
		"atomic manifest has 16 gates and zero production, V0.6, or dual-write effects"
	)


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


func _has_exact_fields(value: Dictionary, fields: Array) -> bool:
	if value.size() != fields.size():
		return false
	for field_variant in fields:
		if not value.has(str(field_variant)):
			return false
	return true


func _same_string_set(left: Array, right: Array) -> bool:
	var left_rows: Array[String] = []
	var right_rows: Array[String] = []
	for value in left:
		left_rows.append(str(value))
	for value in right:
		right_rows.append(str(value))
	left_rows.sort()
	right_rows.sort()
	return left_rows == right_rows


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print(
		"V072_THREE_WING_CONTRACT_AGGREGATE|status=%s|checks=%d|failures=%d"
			% [status, _checks, _failures.size()]
	)
	for failure in _failures:
		push_error("V072_THREE_WING_CONTRACT_AGGREGATE: %s" % failure)
	quit(0 if _failures.is_empty() else 1)
