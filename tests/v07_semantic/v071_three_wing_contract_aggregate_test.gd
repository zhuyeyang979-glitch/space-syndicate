extends SceneTree

const TrackCore := preload(
	"res://scripts/v07_semantic/v07_unified_card_track_core.gd"
)
const DbgCore := preload("res://scripts/v07_semantic/v07_dbg_deck_core.gd")
const AssetBatchCore := preload(
	"res://scripts/v07_semantic/v07_asset_batch_core.gd"
)
const SolarVictoryCore := preload(
	"res://scripts/v07_semantic/v07_solar_victory_core.gd"
)

const REGISTRY_PATH := "res://docs/semantic/v071_three_wing_domain_registry.json"
const SAVE_SCHEMA_PATH := "res://docs/save/v071_save_schema.json"
const RESTORE_GRAPH_PATH := "res://docs/save/v071_restore_dependency_graph.json"
const RNG_OWNERSHIP_PATH := "res://docs/save/v071_rng_ownership.json"
const RULESET_ID := "v0.7.1"
const PROFILE_ID := "V071_CANDIDATE_A_FAST"
const PROFILE_FINGERPRINT := (
	"8d8de8d406ca2f7d5123ecc951a606a0a08b56282bc3d6a40e0cd4d5ff50f19a"
)

const DOMAIN_ORDER := [
	"unified_card_track_cycle",
	"personal_dbg_and_merge",
	"six_color_assets",
	"card_batch_and_anonymous_resolution",
	"solar_facility_and_macro_victory",
]
const DOMAIN_SPECS := {
	"unified_card_track_cycle": {
		"implementation_file": "res://scripts/v07_semantic/v07_unified_card_track_core.gd",
		"state_version": 4,
		"interfaces": {
			"core": "v071.unified_track.core_authority.v2",
			"ai_observation": "v071.unified_track.ai_observation.v2",
			"player_projection": "v071.unified_track.player_projection.v2",
			"intent": "v071.unified_track.intent.v2",
			"authoritative_receipt": "v071.unified_track.authoritative_receipt.v2",
			"save_state": "v071.unified_track.save_state.v2",
		},
		"approved_closures": [
			"independent_completed_batch_lead_and_color_cursors",
			"outgoing_lead_color_weight_order",
			"next_scroll_replacement_lock",
			"level_one_only_track_supply",
			"soft_hidden_lead_publication",
			"ai_self_lead_private_parity",
		],
	},
	"personal_dbg_and_merge": {
		"implementation_file": "res://scripts/v07_semantic/v07_dbg_deck_core.gd",
		"state_version": 2,
		"interfaces": {
			"core": "v071.personal_dbg.core_authority.v2",
			"ai_observation": "v071.personal_dbg.ai_observation.v2",
			"player_projection": "v071.personal_dbg.player_projection.v2",
			"intent": "v071.personal_dbg.intent.v2",
			"authoritative_receipt": "v071.personal_dbg.authoritative_receipt.v2",
			"save_state": "v071.personal_dbg.save_state.v2",
		},
		"approved_closures": [
			"normal_deck_minimum_total_five",
			"commodity_available_from_batch_id",
			"saved_local_queue_lock",
		],
	},
	"six_color_assets": {
		"implementation_file": "res://scripts/v07_semantic/v07_asset_batch_core.gd",
		"state_version": 2,
		"interfaces": {
			"core": "v071.six_color_assets.core_authority.v2",
			"ai_observation": "v071.six_color_assets.ai_observation.v2",
			"player_projection": "v071.six_color_assets.player_projection.v2",
			"intent": "v071.six_color_assets.intent.v2",
			"authoritative_receipt": "v071.six_color_assets.authoritative_receipt.v2",
			"save_state": "v071.six_color_assets.save_state.v2",
		},
		"approved_closures": [
			"maximum_three_refresh_per_color_per_batch",
			"profile_bound_initial_assets_per_color_two",
		],
	},
	"card_batch_and_anonymous_resolution": {
		"implementation_file": "res://scripts/v07_semantic/v07_asset_batch_core.gd",
		"state_version": 2,
		"interfaces": {
			"core": "v071.card_batch.core_authority.v2",
			"ai_observation": "v071.card_batch.ai_observation.v2",
			"player_projection": "v071.card_batch.player_projection.v2",
			"intent": "v071.card_batch.intent.v2",
			"authoritative_receipt": "v071.card_batch.authoritative_receipt.v2",
			"save_state": "v071.card_batch.save_state.v2",
		},
		"approved_closures": [
			"closed_invalid_target_policy_set",
			"default_full_asset_refund",
			"fizzled_normal_card_to_discard",
			"action_slot_not_refunded",
			"owner_anonymous_public_causal_history",
		],
	},
	"solar_facility_and_macro_victory": {
		"implementation_file": "res://scripts/v07_semantic/v07_solar_victory_core.gd",
		"state_version": 2,
		"save_section_version": 4,
		"interfaces": {
			"core": "v071.solar_victory.core_authority.v2",
			"ai_observation": "v071.solar_victory.ai_observation.v2",
			"player_projection": "v071.solar_victory.player_projection.v2",
			"intent": "v071.solar_victory.intent.v2",
			"authoritative_receipt": "v071.solar_victory.authoritative_receipt.v2",
			"save_state": "v071.solar_victory.save_state.v2",
		},
		"approved_closures": [
			"single_solar_multiplier_application_per_work_rate_channel",
			"victory_pending_until_complete_macro_round",
		],
	},
}
const SECTION_SPECS := {
	"unified_card_track_cycle": [4, "v071.unified_track.save_state.v2"],
	"personal_dbg_and_merge": [2, "v071.personal_dbg.save_state.v2"],
	"six_color_assets_and_reservations": [2, "v071.six_color_assets.save_state.v2"],
	"card_batch_and_anonymous_resolution": [2, "v071.card_batch.save_state.v2"],
	"solar_facility_and_macro_victory": [4, "v071.solar_victory.save_state.v2"],
}
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
const LOGICAL_RNG_STREAMS := [
	"starter_deck_shuffle",
	"normal_deck_reshuffle_by_player",
	"unified_track_type_draw",
	"unified_track_color_draw",
	"unified_track_normal_card_draw",
	"unified_track_commodity_draw",
	"initial_hidden_lead_order",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var registry := _load_json(REGISTRY_PATH)
	var save_schema := _load_json(SAVE_SCHEMA_PATH)
	var restore_graph := _load_json(RESTORE_GRAPH_PATH)
	var rng_ownership := _load_json(RNG_OWNERSHIP_PATH)
	_test_registry(registry)
	_test_save_schema(save_schema)
	_test_restore_graph(restore_graph)
	_test_rng_ownership(rng_ownership)
	_test_executable_contracts()
	_finish()


func _test_registry(registry: Dictionary) -> void:
	_expect(
		str(registry.get("registry_id", ""))
			== "space_syndicate.v071.three_wing_domain_registry"
			and str(registry.get("constitution_id", ""))
				== "space_syndicate.v071.complete"
			and str(registry.get("ruleset_id", "")) == RULESET_ID,
		"registry binds the frozen V0.7.1 constitution"
	)
	_expect(
		str(registry.get("current_production_runtime_ruleset", "")) == "v0.6"
			and int(registry.get("production_runtime_connection_count", -1)) == 0
			and int(registry.get("v06_mutation_count", -1)) == 0
			and int(registry.get("dual_write_count", -1)) == 0,
		"registry remains detached from V0.6 production"
	)
	_expect(_profile_matches(registry), "registry freezes Candidate A profile identity")
	_expect(
		registry.get("human_fun_proven") == false
			and registry.get("human_test_required") == true,
		"registry keeps human fun unproven and human testing required"
	)
	var domains := registry.get("domains", []) as Array
	_expect(domains.size() == DOMAIN_ORDER.size(), "registry has exactly five domains")
	for index in range(DOMAIN_ORDER.size()):
		var domain_id := str(DOMAIN_ORDER[index])
		var actual := domains[index] as Dictionary if index < domains.size() \
			and domains[index] is Dictionary else {}
		var expected := DOMAIN_SPECS.get(domain_id, {}) as Dictionary
		var expected_keys := [
			"domain_id", "implementation_file", "state_version",
			"interfaces", "approved_closures",
		]
		if expected.has("save_section_version"):
			expected_keys.append("save_section_version")
		_expect(_same_string_set(actual.keys(), expected_keys), "%s fields are closed" % domain_id)
		_expect(
			str(actual.get("domain_id", "")) == domain_id
				and str(actual.get("implementation_file", ""))
					== str(expected.get("implementation_file", ""))
				and int(actual.get("state_version", 0))
					== int(expected.get("state_version", -1)),
			"%s identity and state version are exact" % domain_id
		)
		_expect(
			actual.get("interfaces") == expected.get("interfaces"),
			"%s six interfaces match the frozen V0.7.1 registry" % domain_id
		)
		_expect(
			actual.get("approved_closures") == expected.get("approved_closures"),
			"%s approved closures are exact" % domain_id
		)
		if expected.has("save_section_version"):
			_expect(
				actual.get("save_section_version") == expected.get("save_section_version"),
				"%s Save section version is exact" % domain_id
			)
	_expect(
		registry.get("canonical_adapters") == [
			"space_syndicate.v071.semantic_save.v1",
			"space_syndicate.v071.canonical_rng_adapter.v1",
			"v071.canonical.ai_observation_adapter.v2",
			"v071.canonical.player_projection_adapter.v2",
			"space_syndicate.v071.atomic_cutover_manifest",
		],
		"registry names all five detached canonical contracts"
	)


func _test_save_schema(schema: Dictionary) -> void:
	_expect(
		str(schema.get("save_schema_id", ""))
			== "space_syndicate.v071.semantic_save.v1"
			and str(schema.get("ruleset_id", "")) == RULESET_ID
			and schema.get("production_runtime_connected") == false,
		"Save schema is V0.7.1-only and detached"
	)
	var profile := schema.get("balance_profile", {}) as Dictionary
	_expect(
		str(profile.get("profile_id", "")) == PROFILE_ID
			and str(profile.get("profile_fingerprint", "")) == PROFILE_FINGERPRINT
			and profile.get("required_in_envelope") == true
			and str(profile.get("mismatch_policy", "")) == "fail_closed",
		"Save envelope requires exact Candidate A identity"
	)
	var migration := schema.get("migration_policy", {}) as Dictionary
	_expect(
		migration.get("v07_save_to_v071_direct_resume") == false
			and migration.get("v06_save_to_v071_direct_resume") == false
			and migration.get("v06_save_backup_required") == true
			and str(migration.get("missing_new_field_policy", "")) == "fail_closed"
			and str(migration.get("implicit_default_policy", "")) == "forbidden",
		"V0.7 and V0.6 Saves cannot silently resume as V0.7.1"
	)
	var sections := schema.get("sections", []) as Array
	_expect(sections.size() == SECTION_SPECS.size(), "Save schema has exactly five sections")
	var seen: Array[String] = []
	for section_variant in sections:
		var section := section_variant as Dictionary if section_variant is Dictionary else {}
		var section_id := str(section.get("section_id", ""))
		var spec := SECTION_SPECS.get(section_id, []) as Array
		_expect(not spec.is_empty() and not seen.has(section_id), "%s Save section is unique" % section_id)
		seen.append(section_id)
		if spec.is_empty():
			continue
		_expect(
			int(section.get("section_version", 0)) == int(spec[0])
				and str(section.get("interface_id", "")) == str(spec[1]),
			"%s Save version and interface are exact" % section_id
		)
		_expect(
			section.get("required_state_fields") is Array
				and not (section.get("required_state_fields") as Array).is_empty(),
			"%s declares required V0.7.1 state fields" % section_id
		)
	_expect(_same_string_set(seen, SECTION_SPECS.keys()), "all Save sections are covered once")
	_expect(
		(schema.get("required_restore_gates", []) as Array).size() == 8
			and (schema.get("required_restore_gates", []) as Array).has(
				"exact_balance_profile_fingerprint"
			)
			and (schema.get("required_restore_gates", []) as Array).has(
				"atomic_commit_after_all_preflight"
			),
		"Save schema declares profile and atomic-restore gates"
	)


func _test_restore_graph(graph: Dictionary) -> void:
	_expect(
		str(graph.get("graph_id", ""))
			== "space_syndicate.v071.detached_restore_graph.v1"
			and str(graph.get("ruleset_id", "")) == RULESET_ID
			and graph.get("production_runtime_connected") == false,
		"restore graph is exact and detached"
	)
	_expect(
		graph.get("all_preflight_before_apply") == true
			and graph.get("checkpoint_before_apply") == true
			and graph.get("reverse_rollback_on_failure") == true
			and int(graph.get("atomic_commit_count", 0)) == 1,
		"restore graph preflights, checkpoints, rolls back, and commits once"
	)
	var nodes := graph.get("nodes", []) as Array
	_expect(nodes.size() == RESTORE_NODE_ORDER.size(), "restore graph has ten exact nodes")
	var prior: Array[String] = []
	for index in range(RESTORE_NODE_ORDER.size()):
		var node := nodes[index] as Dictionary if index < nodes.size() \
			and nodes[index] is Dictionary else {}
		var node_id := str(node.get("node_id", ""))
		_expect(node_id == RESTORE_NODE_ORDER[index], "restore node %d identity is exact" % index)
		var dependencies := node.get("depends_on", []) as Array
		var dependencies_are_prior := true
		for dependency in dependencies:
			if not prior.has(str(dependency)):
				dependencies_are_prior = false
		_expect(dependencies_are_prior, "%s depends only on prior nodes" % node_id)
		prior.append(node_id)
	var profile := graph.get("balance_profile_preflight", {}) as Dictionary
	_expect(
		str(profile.get("profile_id", "")) == PROFILE_ID
			and str(profile.get("profile_fingerprint", "")) == PROFILE_FINGERPRINT
			and str(profile.get("mismatch_policy", ""))
				== "fail_closed_before_rng_restore",
		"restore rejects a wrong profile before RNG restore"
	)


func _test_rng_ownership(contract: Dictionary) -> void:
	_expect(
		str(contract.get("registry_id", ""))
			== "space_syndicate.v071.rng_ownership.v1"
			and str(contract.get("ruleset_id", "")) == RULESET_ID
			and contract.get("production_runtime_connected") == false,
		"RNG ownership contract is exact and detached"
	)
	_expect(
		contract.get("logical_streams") == LOGICAL_RNG_STREAMS
			and str(contract.get("canonical_adapter_id", ""))
				== "space_syndicate.v071.canonical_rng_adapter.v1"
			and contract.get("canonical_ledger_is_second_rng_authority") == false
			and int(contract.get("draw_api_count_in_adapter", -1)) == 0,
		"canonical RNG ledger has seven streams and no second authority"
	)
	var owner_versions := contract.get("required_owner_versions", {}) as Dictionary
	_expect(
		int(owner_versions.get("unified_card_track_state_version", 0)) == 4
			and int(owner_versions.get("personal_dbg_state_version", 0)) == 2,
		"RNG contract binds Track v4 and DBG v2 owner state"
	)
	var profiles := contract.get("state_profiles", []) as Array
	_expect(profiles.size() == 2, "RNG contract has exactly two state profiles")
	if profiles.size() == 2:
		_expect(
			str((profiles[0] as Dictionary).get("authoritative_owner_id", ""))
				== "v071.personal_dbg.core_authority.v2"
				and str((profiles[1] as Dictionary).get("authoritative_owner_id", ""))
					== "v071.unified_track.core_authority.v2",
			"RNG profiles bind the two exact V0.7.1 owners"
		)
	var policy := contract.get("restore_policy", {}) as Dictionary
	_expect(
		policy.get("owner_state_is_authoritative") == true
			and policy.get("ledger_row_must_equal_embedded_owner_state") == true
			and policy.get("wrong_profile_fingerprint_rejected_before_rng_restore") == true
			and policy.get("adapter_may_seed_advance_or_draw") == false,
		"RNG restore remains owner-bound and fail-closed"
	)


func _test_executable_contracts() -> void:
	var track_contract := TrackCore.new().interface_contract_v1()
	_expect(
		TrackCore.RULESET_ID == RULESET_ID
			and TrackCore.STATE_VERSION == 4
			and TrackCore.BALANCE_PROFILE_ID == PROFILE_ID
			and TrackCore.BALANCE_PROFILE_FINGERPRINT == PROFILE_FINGERPRINT,
		"Track Core binds V0.7.1 state v4 and Candidate A"
	)
	_expect(
		str(track_contract.get("lead_advance_unit", "")) == "completed_card_batch"
			and str(track_contract.get("color_cycle_advance_unit", ""))
				== "completed_card_batch"
			and int(track_contract.get("default_lead_tenure_batches", 0)) == 1
			and int(track_contract.get("default_color_cycle_batches", 0)) == 6,
		"Track Core advances lead and color on independent batch cursors"
	)
	_expect(
		TrackCore.TRACK_ITEM_LEVEL == 1
			and TrackCore.DEFAULT_NORMAL_RATIO_BASIS_POINTS == 6000
			and TrackCore.DEFAULT_COMMODITY_RATIO_BASIS_POINTS == 4000,
		"Track Core freezes L1-only 60/40 Candidate A supply"
	)

	var dbg_contract := DbgCore.three_wing_contract()
	_expect(DbgCore.validate_three_wing_contract(dbg_contract).is_empty(), "DBG three-wing contract validates")
	_expect(
		DbgCore.RULESET_ID == RULESET_ID
			and DbgCore.STATE_VERSION == 2
			and DbgCore.NORMAL_DECK_MINIMUM_TOTAL_CARD_COUNT == 5
			and str(dbg_contract.get("commodity_available_from_batch_field", ""))
				== "available_from_batch_id",
		"DBG v2 freezes minimum five and commodity batch availability"
	)

	var asset_contract := AssetBatchCore.contract_snapshot()
	_expect(
		AssetBatchCore.RULESET_ID == RULESET_ID
			and AssetBatchCore.STATE_VERSION == 2
			and AssetBatchCore.MAX_ASSET_REFRESH_PER_COLOR_PER_BATCH == 3
			and AssetBatchCore.DEFAULT_INVALID_TARGET_POLICY_ID
				== "FIZZLE_FULL_ASSET_REFUND",
		"Asset/Batch v2 freezes refresh cap and default fizzle refund"
	)
	_expect(
		asset_contract.get("core_authority") == [
			"v071.six_color_assets.core_authority.v2",
			"v071.card_batch.core_authority.v2",
		]
			and (AssetBatchCore.privacy_contract() as Dictionary).get(
				"owner_specific_timing_audio_animation_allowed"
			) == false,
		"Asset/Batch contract exposes both authorities without owner-specific cues"
	)

	var solar_contract := SolarVictoryCore.interface_contract_v2()
	_expect(
		SolarVictoryCore.RULESET_ID == RULESET_ID
			and SolarVictoryCore.SAVE_SECTION_VERSION == 4
			and SolarVictoryCore.BALANCE_PROFILE_ID == PROFILE_ID
			and int(solar_contract.get(
				"solar_multiplier_application_count_per_channel", 0
			)) == 1,
		"Solar/Victory v2 saves profile identity and applies solar once per channel"
	)
	_expect(
		solar_contract.get("production_runtime_connected") == false
			and (solar_contract.get("interfaces", {}) as Dictionary).get("save_state")
				== "v071.solar_victory.save_state.v2",
		"Solar/Victory contract remains detached with a V0.7.1 Save interface"
	)


func _profile_matches(value: Dictionary) -> bool:
	return str(value.get("balance_profile_id", "")) == PROFILE_ID \
		and str(value.get("balance_profile_fingerprint", "")) == PROFILE_FINGERPRINT


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_expect(parsed is Dictionary, "%s parses as a JSON object" % path)
	return parsed as Dictionary if parsed is Dictionary else {}


func _same_string_set(left: Array, right: Array) -> bool:
	if left.size() != right.size():
		return false
	var normalized_left: Array[String] = []
	var normalized_right: Array[String] = []
	for value in left:
		normalized_left.append(str(value))
	for value in right:
		normalized_right.append(str(value))
	normalized_left.sort()
	normalized_right.sort()
	return normalized_left == normalized_right


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print(
			"V071_THREE_WING_CONTRACT_AGGREGATE_TEST|status=PASS|checks=%d|failures=0"
				% _checks
		)
		quit(0)
		return
	for failure in _failures:
		push_error("V071_THREE_WING_CONTRACT_AGGREGATE_TEST|%s" % failure)
	push_error(
		"V071_THREE_WING_CONTRACT_AGGREGATE_TEST|status=FAIL|checks=%d|failures=%d"
			% [_checks, _failures.size()]
	)
	quit(1)
