extends SceneTree

const UNIFIED_CORE := preload(
	"res://scripts/v07_semantic/v07_unified_card_track_core.gd"
)
const ACQUISITION_PORT := preload(
	"res://scripts/v07_semantic/v07_track_acquisition_authority_port.gd"
)
const DBG_CORE := preload("res://scripts/v07_semantic/v07_dbg_deck_core.gd")
const ASSET_BATCH_CORE := preload(
	"res://scripts/v07_semantic/v07_asset_batch_core.gd"
)
const SOLAR_VICTORY_CORE := preload(
	"res://scripts/v07_semantic/v07_solar_victory_core.gd"
)

const DOMAIN_REGISTRY_PATH := (
	"res://docs/semantic/v07_three_wing_domain_registry.json"
)
const SAVE_SCHEMA_PATH := "res://docs/save/v07_save_schema.json"
const RESTORE_GRAPH_PATH := "res://docs/save/v07_restore_dependency_graph.json"
const RNG_OWNERSHIP_PATH := "res://docs/save/v07_rng_ownership.json"


class TrustedTimeAttestationAuthority:
	extends RefCounted

	var _ledger: Dictionary = {}

	func commit_attestation(attestation: Dictionary) -> void:
		_ledger[str(attestation.get("attestation_id", ""))] = (
			attestation.duplicate(true)
		)

	func authoritative_time_attestation_v1(attestation_id: String) -> Dictionary:
		if not _ledger.has(attestation_id):
			return {}
		return (_ledger.get(attestation_id) as Dictionary).duplicate(true)


class ReferenceAcquisitionParticipant:
	extends RefCounted

	var authority_id: String
	var state: Dictionary

	func _init(value: String) -> void:
		authority_id = value
		state = {"reservations": {}, "commits": {}}

	func acquisition_authority_id_v1() -> String:
		return authority_id

	func capture_checkpoint_v1() -> Dictionary:
		return state.duplicate(true)

	func prepare_acquisition_v1(request: Dictionary) -> Dictionary:
		var reservation_id := "reservation.%s.%s" % [
			str(request.get("participant_role", "")),
			str(request.get("transaction_id", "")).sha256_text().left(16),
		]
		(state.get("reservations") as Dictionary)[reservation_id] = (
			request.duplicate(true)
		)
		return _receipt({
			"accepted": true,
			"reason_code": "participant_prepared",
			"transaction_id": str(request.get("transaction_id", "")),
			"reservation_id": reservation_id,
			"authority_id": authority_id,
			"participant_role": str(request.get("participant_role", "")),
		})

	func commit_prepared_acquisition_v1(
		reservation_id: String,
		track_receipt: Dictionary
	) -> Dictionary:
		var commits := state.get("commits") as Dictionary
		if commits.has(reservation_id):
			return (commits.get(reservation_id) as Dictionary).duplicate(true)
		var request := (
			state.get("reservations") as Dictionary
		).get(reservation_id, {}) as Dictionary
		if request.is_empty():
			return {"accepted": false, "reason_code": "reservation_missing"}
		var result := _receipt({
			"accepted": true,
			"reason_code": "participant_committed",
			"transaction_id": str(request.get("transaction_id", "")),
			"reservation_id": reservation_id,
			"authority_id": authority_id,
			"participant_role": str(request.get("participant_role", "")),
			"track_receipt_fingerprint": str(
				track_receipt.get("receipt_fingerprint", "")
			),
		})
		commits[reservation_id] = result
		return result.duplicate(true)

	func abort_prepared_acquisition_v1(
		reservation_id: String,
		_reason_code: String
	) -> Dictionary:
		var request := (
			state.get("reservations") as Dictionary
		).get(reservation_id, {}) as Dictionary
		(state.get("reservations") as Dictionary).erase(reservation_id)
		return _receipt({
			"accepted": true,
			"reason_code": "participant_aborted",
			"transaction_id": str(request.get("transaction_id", "")),
			"reservation_id": reservation_id,
			"authority_id": authority_id,
			"participant_role": str(request.get("participant_role", "")),
		})

	func rollback_v1(checkpoint: Dictionary) -> Dictionary:
		state = checkpoint.duplicate(true)
		return {"accepted": true, "reason_code": "participant_rolled_back"}

	func _receipt(unsealed: Dictionary) -> Dictionary:
		return UNIFIED_CORE.sealed_copy(unsealed, "receipt_fingerprint")


class TestVictoryAuthorityPort:
	extends RefCounted

	var _authority_id: String
	var _source_authority_id: String
	var _issuer_instance_id: String
	var _capability: RefCounted
	var _current_source_revision: int
	var _issued_proofs: Dictionary = {}

	func _init(
		issuer_instance_id: String,
		capability: RefCounted,
		current_source_revision: int = 0,
		authority_id: String = V07SolarVictoryCore.TRUSTED_AUTHORITY_ID,
		source_authority_id: String = V07SolarVictoryCore.TRUSTED_SOURCE_AUTHORITY_ID
	) -> void:
		_issuer_instance_id = issuer_instance_id
		_capability = capability
		_current_source_revision = current_source_revision
		_authority_id = authority_id
		_source_authority_id = source_authority_id

	func capability() -> RefCounted:
		return _capability

	func set_current_source_revision(revision: int) -> void:
		_current_source_revision = revision

	func victory_authority_identity_v1() -> Dictionary:
		return {
			"authority_id": _authority_id,
			"source_authority_id": _source_authority_id,
			"issuer_instance_id": _issuer_instance_id,
		}

	func victory_capability_identity_v1() -> RefCounted:
		return _capability

	func victory_current_source_revision_v1(capability_value: RefCounted) -> int:
		return _current_source_revision if capability_value == _capability else -1

	func victory_lookup_issued_proof_v1(
		proof_id: String,
		proof_fingerprint: String,
		capability_value: RefCounted
	) -> Dictionary:
		if capability_value != _capability or not _issued_proofs.has(proof_id):
			return {}
		var proof := _issued_proofs.get(proof_id, {}) as Dictionary
		return proof.duplicate(true) \
			if str(proof.get("proof_fingerprint", "")) == proof_fingerprint \
			else {}

	func issue_qualification_proof(
		proof_id: String,
		match_instance_id: String,
		genesis_fingerprint: String,
		expected_core_revision: int,
		source_revision: int,
		macro_round_index: int,
		condition_id: String,
		qualifies: bool
	) -> Dictionary:
		return _record_proof({
			"schema_version": V07SolarVictoryCore.SCHEMA_VERSION,
			"authority_id": _authority_id,
			"source_authority_id": _source_authority_id,
			"issuer_instance_id": _issuer_instance_id,
			"proof_id": proof_id,
			"proof_kind_id": V07SolarVictoryCore.PROOF_KIND_QUALIFICATION,
			"match_instance_id": match_instance_id,
			"genesis_fingerprint": genesis_fingerprint,
			"expected_core_revision": expected_core_revision,
			"source_revision": source_revision,
			"macro_round_index": macro_round_index,
			"condition_id": condition_id,
			"qualifies": qualifies,
		})

	func issue_boundary_proof(
		proof_id: String,
		match_instance_id: String,
		genesis_fingerprint: String,
		expected_core_revision: int,
		source_revision: int,
		macro_round_index: int,
		condition_id: String,
		qualification_proof_id: String,
		qualification_proof_fingerprint: String,
		boundary: Dictionary,
		revalidation_passed: bool,
		final_settlement_id: String
	) -> Dictionary:
		return _record_proof({
			"schema_version": V07SolarVictoryCore.SCHEMA_VERSION,
			"authority_id": _authority_id,
			"source_authority_id": _source_authority_id,
			"issuer_instance_id": _issuer_instance_id,
			"proof_id": proof_id,
			"proof_kind_id": V07SolarVictoryCore.PROOF_KIND_BOUNDARY,
			"match_instance_id": match_instance_id,
			"genesis_fingerprint": genesis_fingerprint,
			"expected_core_revision": expected_core_revision,
			"source_revision": source_revision,
			"macro_round_index": macro_round_index,
			"condition_id": condition_id,
			"qualification_proof_id": qualification_proof_id,
			"qualification_proof_fingerprint": qualification_proof_fingerprint,
			"boundary": boundary.duplicate(true),
			"revalidation_passed": revalidation_passed,
			"final_settlement_id": final_settlement_id,
		})

	func _record_proof(unsealed: Dictionary) -> Dictionary:
		var proof := unsealed.duplicate(true)
		proof["proof_fingerprint"] = _fingerprint(proof)
		var proof_id := str(proof.get("proof_id", ""))
		if _issued_proofs.has(proof_id):
			var existing := _issued_proofs.get(proof_id, {}) as Dictionary
			return existing.duplicate(true) if existing == proof else {}
		_issued_proofs[proof_id] = proof.duplicate(true)
		return proof.duplicate(true)

	static func _fingerprint(value: Variant) -> String:
		return JSON.stringify(_canonicalize_value(value)).sha256_text().to_lower()

	static func _canonicalize_value(value: Variant) -> Variant:
		if value is Array:
			var array_result: Array = []
			for item_variant in value as Array:
				array_result.append(_canonicalize_value(item_variant))
			return array_result
		if value is Dictionary:
			var keys: Array[String] = []
			for key_variant in (value as Dictionary).keys():
				keys.append(str(key_variant))
			keys.sort()
			var dictionary_result := {}
			for key in keys:
				dictionary_result[key] = _canonicalize_value(
					(value as Dictionary).get(key)
				)
			return dictionary_result
		return value


const CONTRACT_SURFACES := [
	"CoreAuthorityV1",
	"AiObservationV1",
	"PlayerProjectionV1",
	"IntentV1",
	"AuthoritativeReceiptV1",
	"SaveStateV1",
]
const DOMAIN_IDS := [
	"unified_card_track_cycle",
	"personal_dbg_and_merge",
	"six_color_assets_and_reservations",
	"card_batch_and_anonymous_resolution",
	"solar_facility_and_macro_victory",
]
const EXPECTED_CONTRACT_IDS := {
	"unified_card_track_cycle": {
		"CoreAuthorityV1": "v07.unified_track.core_authority.v1",
		"AiObservationV1": "v07.unified_track.ai_observation.v1",
		"PlayerProjectionV1": "v07.unified_track.player_projection.v1",
		"IntentV1": "v07.unified_track.intent.v1",
		"AuthoritativeReceiptV1": "v07.unified_track.authoritative_receipt.v1",
		"SaveStateV1": "v07.unified_track.save_state.v1",
	},
	"personal_dbg_and_merge": {
		"CoreAuthorityV1": "v07.personal_dbg.core_authority.v1",
		"AiObservationV1": "v07.personal_dbg.ai_observation.v1",
		"PlayerProjectionV1": "v07.personal_dbg.player_projection.v1",
		"IntentV1": "v07.personal_dbg.intent.v1",
		"AuthoritativeReceiptV1": "v07.personal_dbg.authoritative_receipt.v1",
		"SaveStateV1": "v07.personal_dbg.save_state.v1",
	},
	"six_color_assets_and_reservations": {
		"CoreAuthorityV1": "v07.six_color_assets.core_authority.v1",
		"AiObservationV1": "v07.six_color_assets.ai_observation.v1",
		"PlayerProjectionV1": "v07.six_color_assets.player_projection.v1",
		"IntentV1": "v07.six_color_assets.intent.v1",
		"AuthoritativeReceiptV1": "v07.six_color_assets.authoritative_receipt.v1",
		"SaveStateV1": "v07.six_color_assets.save_state.v1",
	},
	"card_batch_and_anonymous_resolution": {
		"CoreAuthorityV1": "v07.card_batch.core_authority.v1",
		"AiObservationV1": "v07.card_batch.ai_observation.v1",
		"PlayerProjectionV1": "v07.card_batch.player_projection.v1",
		"IntentV1": "v07.card_batch.intent.v1",
		"AuthoritativeReceiptV1": "v07.card_batch.authoritative_receipt.v1",
		"SaveStateV1": "v07.card_batch.save_state.v1",
	},
	"solar_facility_and_macro_victory": {
		"CoreAuthorityV1": "v07.solar_victory.core_authority.v1",
		"AiObservationV1": "v07.solar_victory.ai_observation.v1",
		"PlayerProjectionV1": "v07.solar_victory.player_projection.v1",
		"IntentV1": "v07.solar_victory.intent.v1",
		"AuthoritativeReceiptV1": "v07.solar_victory.authoritative_receipt.v1",
		"SaveStateV1": "v07.solar_victory.save_state.v1",
	},
}
const EXPECTED_ENTRYPOINTS := {
	"unified_card_track_cycle": {
		"CoreAuthorityV1": ["core_authority_v1"],
		"AiObservationV1": ["ai_observation_v1"],
		"PlayerProjectionV1": ["player_projection_v1"],
		"IntentV1": ["build_intent_v1", "apply_intent_v1"],
		"AuthoritativeReceiptV1": [
			"apply_intent_v1", "authoritative_receipt_v1",
		],
		"SaveStateV1": ["save_state_v1", "restore_save_state_v1"],
	},
	"personal_dbg_and_merge": {
		"CoreAuthorityV1": ["core_authority_snapshot"],
		"AiObservationV1": ["ai_observation"],
		"PlayerProjectionV1": ["player_projection"],
		"IntentV1": ["create_intent", "apply_intent"],
		"AuthoritativeReceiptV1": ["apply_intent"],
		"SaveStateV1": ["to_save_state", "apply_save_state"],
	},
	"six_color_assets_and_reservations": {
		"CoreAuthorityV1": ["asset_core_authority"],
		"AiObservationV1": ["asset_ai_observation"],
		"PlayerProjectionV1": ["asset_player_projection"],
		"IntentV1": ["asset_intent_adapter"],
		"AuthoritativeReceiptV1": ["asset_receipt_adapter"],
		"SaveStateV1": [
			"to_asset_save_state",
			"restore_domain_save_state",
			"restore_domain_save_pair",
		],
	},
	"card_batch_and_anonymous_resolution": {
		"CoreAuthorityV1": ["batch_core_authority"],
		"AiObservationV1": ["batch_ai_observation"],
		"PlayerProjectionV1": ["batch_player_projection"],
		"IntentV1": ["batch_intent_adapter"],
		"AuthoritativeReceiptV1": ["batch_receipt_adapter"],
		"SaveStateV1": [
			"to_batch_save_state",
			"restore_domain_save_state",
			"restore_domain_save_pair",
		],
	},
	"solar_facility_and_macro_victory": {
		"CoreAuthorityV1": [
			"checkpoint",
			"solar_facility_efficiency_state_v1",
			"macro_round_victory_gate_state_v1",
		],
		"AiObservationV1": ["ai_observation"],
		"PlayerProjectionV1": ["player_projection"],
		"IntentV1": [
			"apply_solar_intent",
			"submit_victory_qualification",
			"revalidate_victory_at_boundary",
		],
		"AuthoritativeReceiptV1": [
			"apply_solar_intent",
			"submit_victory_qualification",
			"revalidate_victory_at_boundary",
		],
		"SaveStateV1": ["to_save_state", "from_save_state"],
	},
}
const EXPECTED_INTENT_KINDS := {
	"unified_card_track_cycle": [
		"color_cycle.set_stance",
		"color_cycle.commit_boundary",
		"unified_track.advance",
		"claim_visible_commodity",
		"purchase_visible_normal_card",
	],
	"personal_dbg_and_merge": [
		"play_card",
		"accept_purchase",
		"complete_batch",
		"merge_cards",
		"accept_commodity_track_claim",
		"merge_commodities",
		"end_maintenance",
	],
	"six_color_assets_and_reservations": ["lock_player_queue"],
	"card_batch_and_anonymous_resolution": ["lock_player_queue"],
	"solar_facility_and_macro_victory": [
		"set_solar_phase",
		"submit_victory_qualification",
		"revalidate_victory_at_macro_round_boundary",
	],
}
const EXPECTED_CANONICAL_SAVE_SECTIONS := {
	"unified_card_track_cycle": {
		"section_version": 2,
		"semantic_owner": "v07.unified_track.core_authority.v1",
		"registry_save_contract_id": "v07.unified_track.save_state.v1",
		"privacy": "core_private",
		"local_adapter_field_key": "exact_top_level_fields",
		"required_fields": [
			"schema_version",
			"interface_id",
			"ruleset_id",
			"domain_id",
			"state_version",
			"source_revision",
			"source_core_fingerprint",
			"authority_state",
			"save_fingerprint",
		],
		"field_contracts": {
			"schema_version": 1,
			"interface_id": "v07.unified_track.save_state.v1",
			"ruleset_id": "v0.7",
			"domain_id": "unified_card_track",
			"state_version": 2,
			"source_revision": "positive_integer_equal_to_authority_state_revision",
			"source_core_fingerprint": "sha256_of_canonical_authority_state",
			"authority_state": "exact_closed_V07UnifiedCardTrackCore_state",
			"save_fingerprint": "sha256_of_exact_local_adapter_payload_excluding_save_fingerprint",
		},
	},
	"personal_dbg_and_merge": {
		"section_version": 1,
		"semantic_owner": "v07.personal_dbg.core_authority.v1",
		"registry_save_contract_id": "v07.personal_dbg.save_state.v1",
		"privacy": "player_private_partitioned",
		"local_adapter_field_key": "exact_top_level_fields",
		"required_fields": [
			"schema_id",
			"schema_version",
			"domain_id",
			"privacy_scope",
			"typed_state_contracts",
			"state",
			"document_section",
			"state_fingerprint",
			"core_fingerprint",
		],
		"field_contracts": {
			"schema_id": "v07.personal_dbg.save_state.v1",
			"schema_version": 1,
			"domain_id": "v07.personal_dbg",
			"privacy_scope": "authority_secret",
			"typed_state_contracts": "exact_personal_DBG_typed_state_contract_map",
			"state": "exact_closed_V07DbgDeckCore_state_for_one_player",
			"document_section": "exact_derived_personal_dbg_and_merge_document_section",
			"state_fingerprint": "sha256_of_exact_state",
			"core_fingerprint": "sha256_binding_state_and_typed_contracts",
		},
	},
	"six_color_assets_and_reservations": {
		"section_version": 1,
		"semantic_owner": "v07.six_color_assets.core_authority.v1",
		"registry_save_contract_id": "v07.six_color_assets.save_state.v1",
		"privacy": "player_private_partitioned",
		"local_adapter_field_key": "current_exact_top_level_fields",
		"required_fields": [
			"schema_version",
			"contract_id",
			"section_id",
			"ruleset_id",
			"state_revision",
			"per_player_assets_by_color",
			"per_player_fixed_point_remainders",
			"gdp_cycle_snapshot",
			"per_action_reservations",
			"reservation_journal",
			"asset_refresh_revision",
			"shared_batch_id",
			"shared_lineage_fingerprint",
			"shared_authority_state",
			"save_fingerprint",
		],
		"canonical_required_fields": [
			"schema_version",
			"contract_id",
			"section_id",
			"ruleset_id",
			"shared_batch_id",
			"shared_lineage_fingerprint",
			"state_revision",
			"per_player_assets_by_color",
			"per_player_fixed_point_remainders",
			"gdp_cycle_snapshot",
			"per_action_reservations",
			"reservation_journal",
			"asset_refresh_revision",
			"shared_authority_state",
			"save_fingerprint",
		],
		"field_contracts": {
			"schema_version": 1,
			"contract_id": "v07.six_color_assets.save_state.v1",
			"section_id": "six_color_assets_and_reservations",
			"ruleset_id": "v0.7",
			"state_revision": "nonnegative_integer_equal_to_paired_batch_state_revision",
			"per_player_assets_by_color": "exact_player_id_map_of_closed_six_color_integer_maps",
			"per_player_fixed_point_remainders": "exact_player_id_map_of_closed_six_color_milli_maps",
			"gdp_cycle_snapshot": "exact_player_id_map_of_frozen_gdp_milli_values",
			"per_action_reservations": "exact_player_id_map_of_action_id_to_six_color_cost",
			"reservation_journal": "exact_player_id_map_of_action_result_records",
			"asset_refresh_revision": "nonnegative_integer",
			"shared_batch_id": "stable_identity_equal_to_shared_authority_state_batch_id_and_paired_batch_section",
			"shared_lineage_fingerprint": "sha256_equal_to_shared_authority_state_lineage_and_paired_batch_section",
			"shared_authority_state": "exact_closed_V07AssetBatchCore_state_equal_to_paired_batch_section",
			"save_fingerprint": "sha256_of_exact_split_adapter_payload_excluding_save_fingerprint",
		},
	},
	"card_batch_and_anonymous_resolution": {
		"section_version": 1,
		"semantic_owner": "v07.card_batch.core_authority.v1",
		"registry_save_contract_id": "v07.card_batch.save_state.v1",
		"privacy": "core_private_owner_bindings",
		"local_adapter_field_key": "current_exact_top_level_fields",
		"required_fields": [
			"schema_version",
			"contract_id",
			"section_id",
			"ruleset_id",
			"state_revision",
			"submission_window_state",
			"player_local_queues",
			"prebound_targets",
			"private_owner_bindings",
			"anonymous_global_queue",
			"round_robin_cursor",
			"resolution_journal",
			"processed_intent_ids",
			"intent_receipt_ledger",
			"shared_batch_id",
			"shared_lineage_fingerprint",
			"shared_authority_state",
			"save_fingerprint",
		],
		"canonical_required_fields": [
			"schema_version",
			"contract_id",
			"section_id",
			"ruleset_id",
			"shared_batch_id",
			"shared_lineage_fingerprint",
			"state_revision",
			"submission_window_state",
			"player_local_queues",
			"prebound_targets",
			"private_owner_bindings",
			"anonymous_global_queue",
			"round_robin_cursor",
			"resolution_journal",
			"processed_intent_ids",
			"intent_receipt_ledger",
			"shared_authority_state",
			"save_fingerprint",
		],
		"field_contracts": {
			"schema_version": 1,
			"contract_id": "v07.card_batch.save_state.v1",
			"section_id": "card_batch_and_anonymous_resolution",
			"ruleset_id": "v0.7",
			"state_revision": "nonnegative_integer_equal_to_paired_asset_state_revision",
			"submission_window_state": {
				"exact_fields": [
					"opened_at_ms",
					"deadline_ms",
					"status",
					"one_shot",
					"locked_player_count",
					"time_observation_watermark_ms",
					"submission_hidden_lead_order",
					"frozen_hidden_lead_order",
				],
				"duration_milliseconds": 30000,
				"one_shot": true,
			},
			"player_local_queues": "exact_player_id_map_of_locked_local_action_arrays",
			"prebound_targets": "exact_action_id_map_of_complete_target_bindings",
			"private_owner_bindings": "exact_action_id_to_player_id_map",
			"anonymous_global_queue": "ordered_owner_redacted_public_action_rows",
			"round_robin_cursor": "nonnegative_resolution_cursor",
			"resolution_journal": "exact_player_id_map_of_action_result_records",
			"processed_intent_ids": "ordered_unique_seen_intent_ids",
			"intent_receipt_ledger": "exact_intent_id_map_of_closed_intent_receipt_lineage_rows",
			"shared_batch_id": "stable_identity_equal_to_shared_authority_state_batch_id_and_paired_asset_section",
			"shared_lineage_fingerprint": "sha256_equal_to_shared_authority_state_lineage_and_paired_asset_section",
			"shared_authority_state": "exact_closed_V07AssetBatchCore_state_equal_to_paired_asset_section",
			"save_fingerprint": "sha256_of_exact_split_adapter_payload_excluding_save_fingerprint",
		},
	},
	"solar_facility_and_macro_victory": {
		"section_version": 3,
		"semantic_owner": "v07.solar_victory.core_authority.v1",
		"registry_save_contract_id": "v07.solar_victory.save_state.v1",
		"privacy": "core_private",
		"local_adapter_field_key": "exact_top_level_fields",
		"required_fields": [
			"schema_version",
			"section_id",
			"section_version",
			"ruleset_id",
			"source_state_fingerprint",
			"state",
			"save_fingerprint",
		],
		"field_contracts": {
			"schema_version": 1,
			"section_id": "solar_facility_and_macro_victory",
			"section_version": 3,
			"ruleset_id": "v0.7",
			"source_state_fingerprint": "sha256_of_exact_decoded_authority_state",
			"state": "exact_closed_state_with_all_integers_strictly_tagged_on_wire",
			"save_fingerprint": "sha256_of_exact_save_payload_excluding_save_fingerprint",
		},
	},
}
const EXPECTED_RESTORE_NODES := [
	{
		"node_id": "envelope_identity",
		"section_id": "envelope",
		"depends_on": [],
	},
	{
		"node_id": "rng_stream_states",
		"section_id": "rng_stream_states",
		"depends_on": ["envelope_identity"],
	},
	{
		"node_id": "personal_dbg_and_merge",
		"section_id": "personal_dbg_and_merge",
		"depends_on": ["envelope_identity", "rng_stream_states"],
	},
	{
		"node_id": "hidden_lead_cycle",
		"section_id": "unified_card_track_cycle.authority_state.hidden_lead_cycle_state",
		"depends_on": ["envelope_identity", "rng_stream_states"],
	},
	{
		"node_id": "unified_card_track_cycle",
		"section_id": "unified_card_track_cycle",
		"depends_on": [
			"envelope_identity",
			"rng_stream_states",
			"personal_dbg_and_merge",
			"hidden_lead_cycle",
		],
	},
	{
		"node_id": "six_color_assets_and_reservations",
		"section_id": "six_color_assets_and_reservations",
		"depends_on": ["envelope_identity"],
	},
	{
		"node_id": "card_batch_and_anonymous_resolution",
		"section_id": "card_batch_and_anonymous_resolution",
		"depends_on": [
			"envelope_identity",
			"personal_dbg_and_merge",
			"hidden_lead_cycle",
			"unified_card_track_cycle",
			"six_color_assets_and_reservations",
		],
	},
	{
		"node_id": "solar_facility_state",
		"section_id": "solar_facility_and_macro_victory.state.solar",
		"depends_on": ["envelope_identity"],
	},
	{
		"node_id": "macro_round_victory_gate",
		"section_id": "solar_facility_and_macro_victory.state.victory_gate",
		"depends_on": [
			"envelope_identity",
			"hidden_lead_cycle",
			"card_batch_and_anonymous_resolution",
			"solar_facility_state",
		],
	},
	{
		"node_id": "atomic_restore_commit",
		"section_id": "transaction",
		"depends_on": [
			"rng_stream_states",
			"personal_dbg_and_merge",
			"hidden_lead_cycle",
			"unified_card_track_cycle",
			"six_color_assets_and_reservations",
			"card_batch_and_anonymous_resolution",
			"solar_facility_state",
			"macro_round_victory_gate",
		],
	},
]
const EXPECTED_RNG_STREAM_MAPPING := {
	"starter_deck_shuffle": {
		"authoritative_owner_id": "v07.personal_dbg.core_authority.v1",
		"save_section_id": "personal_dbg_and_merge",
		"state_profile_id": "dbg_tagged_sha256_counter_v1",
		"privacy": "core_private_seed_cursor_and_order",
	},
	"normal_deck_reshuffle_by_player": {
		"authoritative_owner_id": "v07.personal_dbg.core_authority.v1",
		"save_section_id": "personal_dbg_and_merge",
		"state_profile_id": "dbg_tagged_sha256_counter_v1",
		"privacy": "owner_core_private_seed_cursor_and_order",
	},
	"unified_track_type_draw": {
		"authoritative_owner_id": "v07.unified_track.core_authority.v1",
		"save_section_id": "unified_card_track_cycle",
		"state_profile_id": "unified_park_miller_embedded_v1",
		"privacy": "core_private_rng_state_bag_cursor_and_future_kind",
	},
	"unified_track_color_draw": {
		"authoritative_owner_id": "v07.unified_track.core_authority.v1",
		"save_section_id": "unified_card_track_cycle",
		"state_profile_id": "unified_park_miller_embedded_v1",
		"privacy": "core_private_rng_state_bag_cursor_and_future_color",
	},
	"unified_track_normal_card_draw": {
		"authoritative_owner_id": "v07.unified_track.core_authority.v1",
		"save_section_id": "unified_card_track_cycle",
		"state_profile_id": "unified_park_miller_embedded_v1",
		"privacy": "core_private_rng_state_bag_cursor_and_future_normal_card",
	},
	"unified_track_commodity_draw": {
		"authoritative_owner_id": "v07.unified_track.core_authority.v1",
		"save_section_id": "unified_card_track_cycle",
		"state_profile_id": "unified_park_miller_embedded_v1",
		"privacy": "core_private_rng_state_bag_cursor_and_future_commodity_card",
	},
	"initial_hidden_lead_order": {
		"authoritative_owner_id": "v07.unified_track.core_authority.v1",
		"save_section_id": "unified_card_track_cycle",
		"state_profile_id": "unified_park_miller_embedded_v1",
		"privacy": "core_private_rng_state_and_hidden_order",
	},
}
const REQUIRED_RNG_STREAM_IDS := [
	"starter_deck_shuffle",
	"normal_deck_reshuffle_by_player",
	"unified_track_type_draw",
	"unified_track_color_draw",
	"unified_track_normal_card_draw",
	"unified_track_commodity_draw",
	"initial_hidden_lead_order",
]
const CORE_SOURCE_PATHS := [
	"res://scripts/v07_semantic/v07_unified_card_track_core.gd",
	"res://scripts/v07_semantic/v07_track_acquisition_authority_port.gd",
	"res://scripts/v07_semantic/v07_dbg_deck_core.gd",
	"res://scripts/v07_semantic/v07_asset_batch_core.gd",
	"res://scripts/v07_semantic/v07_solar_victory_core.gd",
]
const ASSERTION_CATEGORIES := [
	"V07_CORE",
	"V07_AI",
	"V07_PLAYER",
	"V07_SAVE",
	"V07_RNG",
	"V07_PRIVACY",
]
const ROSTER := ["player.alpha", "player.beta", "player.gamma"]
const FIXED_SEED := 900626424

var _checks := 0
var _failures: Array[String] = []
var _active_category := "V07_CORE"
var _category_totals: Dictionary = {}
var _category_failures: Dictionary = {}
var _timed_asset_batch_core := ASSET_BATCH_CORE.new()
var _time_authority := TrustedTimeAttestationAuthority.new()
var _time_attestation_sequence := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var registry := _load_json(DOMAIN_REGISTRY_PATH)
	var save_schema := _load_json(SAVE_SCHEMA_PATH)
	var restore_graph := _load_json(RESTORE_GRAPH_PATH)
	var rng_ownership := _load_json(RNG_OWNERSHIP_PATH)
	if registry.is_empty() or save_schema.is_empty() \
			or restore_graph.is_empty() or rng_ownership.is_empty():
		_finish()
		return

	_set_category("V07_CORE")
	var time_binding: Dictionary = (
		_timed_asset_batch_core.bind_time_attestation_authority(_time_authority)
	)
	_expect(
		bool(time_binding.get("bound", false)),
		"asset/batch aggregate fixture binds trusted time authority"
	)
	_test_five_logical_core_loads()
	_test_registry_contract_matrix(registry)
	_set_category("V07_CORE")
	var invocations := {
		DOMAIN_IDS[0]: _invoke_unified_track_contracts(),
		DOMAIN_IDS[1]: _invoke_dbg_contracts(),
		DOMAIN_IDS[2]: _invoke_asset_contracts(),
		DOMAIN_IDS[3]: _invoke_batch_contracts(),
		DOMAIN_IDS[4]: _invoke_solar_victory_contracts(),
	}
	_test_every_surface_exact(registry, invocations)
	_set_category("V07_CORE")
	_test_intent_kinds_and_executability(registry)
	_set_category("V07_PRIVACY")
	_test_ai_player_same_source_and_privacy(registry, invocations)
	_set_category("V07_SAVE")
	_test_domain_local_save_roundtrips(registry, invocations)
	_test_save_schema_contract(save_schema, invocations)
	_test_asset_batch_shared_save_pair()
	_test_port_quiescence(registry, save_schema, restore_graph, invocations)
	_test_restore_graph_contract(restore_graph)
	_set_category("V07_RNG")
	_test_rng_ownership_contract(rng_ownership)
	_set_category("V07_CORE")
	_test_no_v06_or_main_connection(
		registry, save_schema, restore_graph, rng_ownership
	)
	_finish()


func _test_five_logical_core_loads() -> void:
	var logical_core_loads := [
		{"domain_id": DOMAIN_IDS[0], "script": UNIFIED_CORE},
		{"domain_id": DOMAIN_IDS[1], "script": DBG_CORE},
		{"domain_id": DOMAIN_IDS[2], "script": ASSET_BATCH_CORE},
		{"domain_id": DOMAIN_IDS[3], "script": ASSET_BATCH_CORE},
		{"domain_id": DOMAIN_IDS[4], "script": SOLAR_VICTORY_CORE},
	]
	_expect(logical_core_loads.size() == 5, "five logical V0.7 Core domains load")
	for row_variant in logical_core_loads:
		var row := row_variant as Dictionary
		var script := row.get("script") as Script
		var probe: Variant = script.new()
		_expect(
			probe is RefCounted and not (probe is Node),
			"%s loads as a non-Node pure Core" % row.get("domain_id", "")
		)
		probe = null
	var asset_batch_contract := ASSET_BATCH_CORE.contract_snapshot()
	var state_ids := asset_batch_contract.get("state_contract_ids", []) as Array
	_expect(
		state_ids.has("V07SixColorAssetState")
			and state_ids.has("V07CardBatchState"),
		"shared implementation exposes distinct asset and batch states"
	)
	var solar_state := SOLAR_VICTORY_CORE.create_state(false, 1)
	_expect(
		str(SOLAR_VICTORY_CORE.solar_facility_efficiency_state_v1(
			solar_state
		).get("state_id", "")) == "V07SolarFacilityEfficiencyState"
			and str(SOLAR_VICTORY_CORE.macro_round_victory_gate_state_v1(
				solar_state
			).get("state_id", "")) == "V07MacroRoundVictoryGateState",
		"solar/victory exposes both explicit authority state contracts"
	)


func _test_registry_contract_matrix(registry: Dictionary) -> void:
	_expect(
		str(registry.get("registry_id", ""))
			== "space_syndicate.v07.three_wing_domain_registry",
		"domain registry identity is exact"
	)
	_expect(
		str(registry.get("surface_execution_status", ""))
			== "PURE_REFERENCE_EXECUTABLE",
		"registry defines one executable surface status"
	)
	var boundary := registry.get("save_contract_boundary", {}) as Dictionary
	_expect(
		str(boundary.get("domain_local_save_state_roundtrip_status", ""))
			== "PURE_REFERENCE_IMPLEMENTED"
			and int(boundary.get("domain_local_save_state_roundtrip_count", 0)) == 5,
		"five domain-local SaveState roundtrips are declared implemented"
	)
	_expect(
		str(boundary.get("canonical_envelope_contract", "")) == SAVE_SCHEMA_PATH
			and str(boundary.get("canonical_envelope_adapter_status", ""))
				== "NOT_IMPLEMENTED"
			and int(boundary.get(
				"canonical_envelope_production_connection_count", -1
			)) == 0,
		"canonical envelope remains a future unwired cutover contract"
	)

	var domains := registry.get("domains", []) as Array
	_expect(domains.size() == 5, "domain registry contains exactly five domains")
	var observed_ids: Array[String] = []
	var executable_surface_count := 0
	for domain_variant in domains:
		var domain := domain_variant as Dictionary
		var domain_id := str(domain.get("domain_id", ""))
		observed_ids.append(domain_id)
		_expect(
			str(domain.get("implementation_status", ""))
				== "PURE_REFERENCE_IMPLEMENTED",
			"%s is marked pure-reference implemented" % domain_id
		)
		_expect(
			FileAccess.file_exists(str(domain.get("implementation_file", "")))
				and FileAccess.file_exists(str(domain.get("focused_test", ""))),
			"%s implementation and focused-test paths exist" % domain_id
		)
		var contracts := domain.get("contracts", {}) as Dictionary
		_expect(
			_same_string_set(contracts.keys(), CONTRACT_SURFACES),
			"%s declares exactly six contract surfaces" % domain_id
		)
		var expected_ids := EXPECTED_CONTRACT_IDS.get(domain_id, {}) as Dictionary
		var expected_entrypoints := (
			EXPECTED_ENTRYPOINTS.get(domain_id, {}) as Dictionary
		)
		for surface in CONTRACT_SURFACES:
			_set_category(_category_for_surface(surface))
			var contract := contracts.get(surface, {}) as Dictionary
			var contract_id := str(contract.get("contract_id", ""))
			_expect(
				contract_id == str(expected_ids.get(surface, "")),
				"%s %s contract ID is exact" % [domain_id, surface]
			)
			_expect(
				str(contract.get("execution_status", ""))
					== "PURE_REFERENCE_EXECUTABLE",
				"%s %s is executable" % [domain_id, surface]
			)
			if str(contract.get("execution_status", "")) \
					== "PURE_REFERENCE_EXECUTABLE":
				executable_surface_count += 1
			_expect(
				_same_string_array(
					contract.get("implementation_entrypoints", []) as Array,
					expected_entrypoints.get(surface, []) as Array
				),
				"%s %s entrypoints are exact" % [domain_id, surface]
			)
			var identity := contract.get("wire_identity", {}) as Dictionary
			_expect(
				str(identity.get("value", "")) == contract_id
					and ["embedded", "registry_declared"].has(
						str(identity.get("mode", ""))
					),
				"%s %s wire identity mode is explicit" % [domain_id, surface]
			)
			_expect(
				not (contract.get("exact_fields", []) as Array).is_empty()
					or not (contract.get(
						"exact_fields_by_intent_kind", {}
					) as Dictionary).is_empty(),
				"%s %s exact field shape is declared" % [domain_id, surface]
			)
		_set_category("V07_PRIVACY")
		for projection_surface in ["AiObservationV1", "PlayerProjectionV1"]:
			_expect(
				not ((contracts.get(projection_surface, {}) as Dictionary).get(
					"forbidden_fields", []
				) as Array).is_empty(),
				"%s %s privacy denylist is explicit"
					% [domain_id, projection_surface]
			)
		_set_category("V07_SAVE")
		var local_roundtrip := (
			(contracts.get("SaveStateV1", {}) as Dictionary).get(
				"local_roundtrip", {}
			) as Dictionary
		)
		_expect(
			str(local_roundtrip.get("status", ""))
				== "PURE_REFERENCE_IMPLEMENTED"
				and not str(local_roundtrip.get("capture_entrypoint", "")).is_empty()
				and not str(local_roundtrip.get("restore_entrypoint", "")).is_empty()
				and not str(local_roundtrip.get("recapture_entrypoint", "")).is_empty(),
			"%s local Save roundtrip entrypoints are complete" % domain_id
		)
	_set_category("V07_CORE")
	_expect(
		_same_string_set(observed_ids, DOMAIN_IDS),
		"registry domain IDs match the five frozen logical Cores"
	)
	_expect(executable_surface_count == 30, "all thirty surfaces are executable")
	_expect(
		not bool(registry.get("global_three_layer_complete", true))
			and not bool(registry.get("v07_production_cutover_complete", true)),
		"reference contracts do not claim global or production cutover completion"
	)
	_set_category("V07_CORE")


func _invoke_unified_track_contracts() -> Dictionary:
	var core := UNIFIED_CORE.new(ROSTER, FIXED_SEED)
	_expect(core.is_configured(), "unified-track aggregate fixture configures")
	var authority: Dictionary = core.core_authority_v1()
	var rng_before := _unified_rng_snapshot(authority)
	var ai: Dictionary = core.ai_observation_v1(ROSTER[0])
	var player: Dictionary = core.player_projection_v1(ROSTER[0])
	var intent: Dictionary = core.build_intent_v1(
		"request.aggregate.unified",
		ROSTER[0],
		UNIFIED_CORE.ACTION_SET_STANCE,
		{"increase_color": "life", "decrease_color": "energy"}
	)
	var applied_receipt: Dictionary = core.apply_intent_v1(intent)
	var receipt: Dictionary = core.authoritative_receipt_v1(
		"request.aggregate.unified"
	)
	_expect(receipt == applied_receipt, "unified receipt reads exact committed result")
	var acquisition_port := ACQUISITION_PORT.new()
	var port_configuration: Dictionary = acquisition_port.configure_v1(
		core,
		{
			"cash": ReferenceAcquisitionParticipant.new("authority.aggregate.cash"),
			"personal_discard": ReferenceAcquisitionParticipant.new(
				"authority.aggregate.personal-discard"
			),
			"commodity_slot": ReferenceAcquisitionParticipant.new(
				"authority.aggregate.commodity-slot"
			),
		}
	)
	_expect(
		bool(port_configuration.get("accepted", false))
			and acquisition_port.is_configured(),
		"unified aggregate fixture configures the trusted acquisition port"
	)
	var port_contract: Dictionary = acquisition_port.acquisition_port_contract_v1()
	var transaction_status: Dictionary = core.acquisition_transaction_status_v1()
	var receipt_journal: Dictionary = acquisition_port.capture_receipt_journal_v1()
	var source_save: Dictionary = core.save_state_v1()
	var rng_after := _unified_rng_snapshot(core.core_authority_v1())
	var restored_core := UNIFIED_CORE.new()
	var restore_result: Dictionary = restored_core.restore_save_state_v1(source_save)
	var recaptured: Dictionary = restored_core.save_state_v1()
	return {
		"surfaces": {
			"CoreAuthorityV1": authority,
			"AiObservationV1": ai,
			"PlayerProjectionV1": player,
			"IntentV1": intent,
			"AuthoritativeReceiptV1": receipt,
			"SaveStateV1": source_save,
		},
		"roundtrip": {
			"restore_ok": bool(restore_result.get("accepted", false)),
			"source": source_save,
			"recaptured": recaptured,
		},
		"rng_before": rng_before,
		"rng_after": rng_after,
		"rng_restored": _unified_rng_snapshot(restored_core.core_authority_v1()),
		"port_quiescence": {
			"configuration": port_configuration,
			"contract": port_contract,
			"transaction_status": transaction_status,
			"receipt_journal": receipt_journal,
		},
	}


func _invoke_dbg_contracts() -> Dictionary:
	var core := DBG_CORE.new()
	var initialized: Dictionary = core.initialize(ROSTER[0], FIXED_SEED)
	_expect(bool(initialized.get("initialized", false)), "DBG aggregate fixture initializes")
	var authority: Dictionary = core.core_authority_snapshot()
	var rng_before := _dbg_rng_snapshot(authority)
	var ai: Dictionary = core.ai_observation(ROSTER[0])
	var player: Dictionary = core.player_projection(ROSTER[0])
	var hand := (player.get("facts", {}) as Dictionary).get("hand", []) as Array
	_expect(not hand.is_empty(), "DBG owner projection supplies one legal play")
	var card_id := str((hand[0] as Dictionary).get("instance_id", ""))
	var intent: Dictionary = core.create_intent(
		"request.aggregate.dbg",
		ROSTER[0],
		DBG_CORE.ACTION_PLAY_CARD,
		{"instance_id": card_id}
	)
	var receipt: Dictionary = core.apply_intent(intent)
	var source_save: Dictionary = core.to_save_state()
	var acquisition_checkpoint: Dictionary = core.capture_checkpoint_v1()
	var rng_after := _dbg_rng_snapshot(core.core_authority_snapshot())
	var restored_core := DBG_CORE.new()
	var restore_result: Dictionary = restored_core.apply_save_state(source_save)
	var recaptured: Dictionary = restored_core.to_save_state()
	return {
		"surfaces": {
			"CoreAuthorityV1": authority,
			"AiObservationV1": ai,
			"PlayerProjectionV1": player,
			"IntentV1": intent,
			"AuthoritativeReceiptV1": receipt,
			"SaveStateV1": source_save,
		},
		"roundtrip": {
			"restore_ok": bool(restore_result.get("applied", false)),
			"source": source_save,
			"recaptured": recaptured,
		},
		"rng_before": rng_before,
		"rng_after": rng_after,
		"rng_restored": _dbg_rng_snapshot(restored_core.core_authority_snapshot()),
		"port_quiescence": acquisition_checkpoint,
	}


func _invoke_asset_contracts() -> Dictionary:
	var state := _create_asset_batch_state("batch.aggregate.assets", 1000)
	_expect(
		bool(ASSET_BATCH_CORE.validation_report(state).get("valid", false)),
		"asset aggregate fixture validates"
	)
	var authority: Dictionary = ASSET_BATCH_CORE.asset_core_authority(state)
	var ai: Dictionary = ASSET_BATCH_CORE.asset_ai_observation(state, ROSTER[0])
	var player: Dictionary = ASSET_BATCH_CORE.asset_player_projection(
		state, ROSTER[0]
	)
	var internal_intent: Dictionary = ASSET_BATCH_CORE.build_lock_intent(
		"intent.aggregate.assets",
		"batch.aggregate.assets",
		ROSTER[0],
		1100,
		[]
	)
	var intent: Dictionary = ASSET_BATCH_CORE.asset_intent_adapter(
		internal_intent,
		int(state.get("revision", 0)),
		int(authority.get("asset_refresh_revision", 0))
	)
	var outcome: Dictionary = _lock_player_queue(
		state, internal_intent, _zero_color_map(), 1100
	)
	var next_state := outcome.get("state", {}) as Dictionary
	var receipt: Dictionary = ASSET_BATCH_CORE.asset_receipt_adapter(
		outcome.get("receipt", {}) as Dictionary,
		internal_intent,
		state,
		next_state
	)
	var source_save: Dictionary = ASSET_BATCH_CORE.to_asset_save_state(next_state)
	var paired_save: Dictionary = ASSET_BATCH_CORE.to_batch_save_state(next_state)
	var domain_preflight: Dictionary = ASSET_BATCH_CORE.restore_domain_save_state(
		source_save, ASSET_BATCH_CORE.ASSET_SAVE_STATE_ID
	)
	var restore_result: Dictionary = ASSET_BATCH_CORE.restore_domain_save_pair(
		source_save, paired_save
	)
	var restored_state := restore_result.get("state", {}) as Dictionary
	var recaptured: Dictionary = ASSET_BATCH_CORE.to_asset_save_state(restored_state)
	return {
		"surfaces": {
			"CoreAuthorityV1": authority,
			"AiObservationV1": ai,
			"PlayerProjectionV1": player,
			"IntentV1": intent,
			"AuthoritativeReceiptV1": receipt,
			"SaveStateV1": source_save,
		},
		"roundtrip": {
			"restore_ok": bool(restore_result.get("restored", false)),
			"domain_preflight": domain_preflight,
			"source": source_save,
			"recaptured": recaptured,
		},
		"rng_before": {},
		"rng_after": {},
		"rng_restored": {},
	}


func _invoke_batch_contracts() -> Dictionary:
	var state := _create_asset_batch_state("batch.aggregate.queue", 2000)
	var target := ASSET_BATCH_CORE.build_target_binding(
		"binding.aggregate.queue", ["region.aggregate"], 1
	)
	var action := ASSET_BATCH_CORE.build_prebound_action(
		"action.aggregate.queue",
		"normal_card",
		"source.aggregate.queue",
		0,
		"card.aggregate.queue",
		target,
		"effect.aggregate.queue",
		_cost_map(1, 0, 0, 0, 0, 0, 0),
		_zero_color_map()
	)
	var internal_intent: Dictionary = ASSET_BATCH_CORE.build_lock_intent(
		"intent.aggregate.queue.alpha",
		"batch.aggregate.queue",
		ROSTER[0],
		2100,
		[action]
	)
	var intent: Dictionary = ASSET_BATCH_CORE.batch_intent_adapter(
		internal_intent, int(state.get("revision", 0))
	)
	var first: Dictionary = _lock_player_queue(
		state, internal_intent, _zero_color_map(), 2100
	)
	var first_state := first.get("state", {}) as Dictionary
	var receipt: Dictionary = ASSET_BATCH_CORE.batch_receipt_adapter(
		first.get("receipt", {}) as Dictionary,
		internal_intent,
		state,
		first_state
	)
	var second_intent := ASSET_BATCH_CORE.build_lock_intent(
		"intent.aggregate.queue.beta",
		"batch.aggregate.queue",
		ROSTER[1],
		2101,
		[]
	)
	state = (
		_lock_player_queue(
			first_state, second_intent, _zero_color_map(), 2101
		).get("state", {}) as Dictionary
	)
	_expect(
		str((state.get("window", {}) as Dictionary).get("status", ""))
			== "resolution_ready",
		"batch aggregate fixture reaches anonymous resolution"
	)
	var source_save: Dictionary = ASSET_BATCH_CORE.to_batch_save_state(state)
	var paired_save: Dictionary = ASSET_BATCH_CORE.to_asset_save_state(state)
	var domain_preflight: Dictionary = ASSET_BATCH_CORE.restore_domain_save_state(
		source_save, ASSET_BATCH_CORE.BATCH_SAVE_STATE_ID
	)
	var restore_result: Dictionary = ASSET_BATCH_CORE.restore_domain_save_pair(
		paired_save, source_save
	)
	var restored_state := restore_result.get("state", {}) as Dictionary
	var recaptured: Dictionary = ASSET_BATCH_CORE.to_batch_save_state(restored_state)
	return {
		"surfaces": {
			"CoreAuthorityV1": ASSET_BATCH_CORE.batch_core_authority(state),
			"AiObservationV1": ASSET_BATCH_CORE.batch_ai_observation(
				state, ROSTER[0]
			),
			"PlayerProjectionV1": ASSET_BATCH_CORE.batch_player_projection(
				state, ROSTER[0]
			),
			"IntentV1": intent,
			"AuthoritativeReceiptV1": receipt,
			"SaveStateV1": source_save,
		},
		"roundtrip": {
			"restore_ok": bool(restore_result.get("restored", false)),
			"domain_preflight": domain_preflight,
			"source": source_save,
			"recaptured": recaptured,
		},
		"rng_before": {},
		"rng_after": {},
		"rng_restored": {},
	}


func _invoke_solar_victory_contracts() -> Dictionary:
	var state := SOLAR_VICTORY_CORE.create_state(false, 1)
	_expect(SOLAR_VICTORY_CORE.is_valid_state(state), "solar/victory fixture validates")
	var checkpoint: Dictionary = SOLAR_VICTORY_CORE.checkpoint(state)
	_expect(not checkpoint.is_empty(), "solar/victory authority checkpoint is callable")
	var authority: Dictionary = state.duplicate(true)
	var ai: Dictionary = SOLAR_VICTORY_CORE.ai_observation(state)
	var player: Dictionary = SOLAR_VICTORY_CORE.player_projection(state)
	var intent := {
		"schema_version": 1,
		"intent_id": "intent.aggregate.solar",
		"intent_kind_id": "set_solar_phase",
		"expected_revision": 0,
		"sunlit": true,
		"source_revision": 1,
	}
	var outcome: Dictionary = SOLAR_VICTORY_CORE.apply_solar_intent(state, intent)
	var next_state := outcome.get("state", {}) as Dictionary
	var source_save: Dictionary = SOLAR_VICTORY_CORE.to_save_state(next_state)
	var restored_state: Dictionary = SOLAR_VICTORY_CORE.from_save_state(source_save)
	var recaptured: Dictionary = SOLAR_VICTORY_CORE.to_save_state(restored_state)
	return {
		"surfaces": {
			"CoreAuthorityV1": authority,
			"AiObservationV1": ai,
			"PlayerProjectionV1": player,
			"IntentV1": intent,
			"AuthoritativeReceiptV1": outcome.get("receipt", {}) as Dictionary,
			"SaveStateV1": source_save,
		},
		"roundtrip": {
			"restore_ok": SOLAR_VICTORY_CORE.is_valid_state(restored_state),
			"source": source_save,
			"recaptured": recaptured,
		},
		"rng_before": {},
		"rng_after": {},
		"rng_restored": {},
	}


func _test_every_surface_exact(
	registry: Dictionary,
	invocations: Dictionary
) -> void:
	for domain_id in DOMAIN_IDS:
		var domain := _registry_domain(registry, domain_id)
		var contracts := domain.get("contracts", {}) as Dictionary
		var fixture := invocations.get(domain_id, {}) as Dictionary
		var called := fixture.get("surfaces", {}) as Dictionary
		_set_category("V07_CORE")
		_expect(
			_same_string_set(called.keys(), CONTRACT_SURFACES),
			"%s invokes exactly six surfaces" % domain_id
		)
		for surface in CONTRACT_SURFACES:
			_set_category(_category_for_surface(surface))
			var contract := contracts.get(surface, {}) as Dictionary
			var value := called.get(surface, {}) as Dictionary
			_expect(
				_is_pure_data(value),
				"%s %s returns detached pure data" % [domain_id, surface]
			)
			var exact_fields := contract.get("exact_fields", []) as Array
			if exact_fields.is_empty():
				var kind_field := str(contract.get("intent_kind_field", ""))
				var kind := str(value.get(kind_field, ""))
				exact_fields = (
					contract.get("exact_fields_by_intent_kind", {}) as Dictionary
				).get(kind, []) as Array
			_expect(
				_same_string_set(value.keys(), exact_fields),
				"%s %s exact fields match registry" % [domain_id, surface]
			)
			var identity := contract.get("wire_identity", {}) as Dictionary
			if str(identity.get("mode", "")) == "embedded":
				var identity_field := str(identity.get("field", ""))
				_expect(
					str(value.get(identity_field, ""))
						== str(contract.get("contract_id", "")),
					"%s %s returned identity is exact" % [domain_id, surface]
				)
			else:
				_expect(
					str(identity.get("mode", "")) == "registry_declared"
						and identity.get("field") == null,
					"%s %s honestly declares non-embedded identity"
						% [domain_id, surface]
				)
			var discriminator := contract.get("wire_discriminator", {}) as Dictionary
			if not discriminator.is_empty():
				_expect(
					str(value.get(str(discriminator.get("field", "")), ""))
						== str(discriminator.get("value", "")),
					"%s %s wire discriminator is exact" % [domain_id, surface]
				)
			if [DOMAIN_IDS[2], DOMAIN_IDS[3]].has(domain_id):
				var report := ASSET_BATCH_CORE.domain_contract_validation_report(
					value, str(contract.get("contract_id", ""))
				)
				_expect(
					bool(report.get("valid", false)),
					"%s %s passes its domain validator" % [domain_id, surface]
				)
	_set_category("V07_CORE")


func _test_intent_kinds_and_executability(registry: Dictionary) -> void:
	for domain_id in DOMAIN_IDS:
		var domain := _registry_domain(registry, domain_id)
		var intent_contract := (
			(domain.get("contracts", {}) as Dictionary).get("IntentV1", {})
			as Dictionary
		)
		_expect(
			_same_string_array(
				intent_contract.get("intent_kinds", []) as Array,
				EXPECTED_INTENT_KINDS.get(domain_id, []) as Array
			),
			"%s Intent kinds are exact and ordered" % domain_id
		)
	_expect(
		_same_string_array(
			UNIFIED_CORE.ACTION_IDS, EXPECTED_INTENT_KINDS.get(DOMAIN_IDS[0], [])
		),
		"unified Intent kinds match executable Core constants"
	)
	_expect(
		_same_string_array(
			DBG_CORE.ACTION_KINDS, EXPECTED_INTENT_KINDS.get(DOMAIN_IDS[1], [])
		),
		"DBG Intent kinds match executable Core constants"
	)
	_test_solar_intent_shapes_and_exact_once(registry)


func _test_solar_intent_shapes_and_exact_once(registry: Dictionary) -> void:
	var intent_contract := (
		(_registry_domain(registry, DOMAIN_IDS[4]).get("contracts", {}) as Dictionary)
			.get("IntentV1", {}) as Dictionary
	)
	var shapes := intent_contract.get("exact_fields_by_intent_kind", {}) as Dictionary
	var solar_intent := {
		"schema_version": 1,
		"intent_id": "intent.aggregate.solar.shape",
		"intent_kind_id": "set_solar_phase",
		"expected_revision": 0,
		"sunlit": true,
		"source_revision": 1,
	}
	_expect(
		_same_string_set(
			solar_intent.keys(), shapes.get("set_solar_phase", []) as Array
		),
		"solar-phase Intent exact fields match registry"
	)
	var solar_outcome := SOLAR_VICTORY_CORE.apply_solar_intent(
		SOLAR_VICTORY_CORE.create_state(false, 1), solar_intent
	)
	_expect(
		bool((solar_outcome.get("receipt", {}) as Dictionary).get("accepted", false)),
		"solar-phase Intent executes"
	)

	var qualification_state := SOLAR_VICTORY_CORE.create_state(
		false, 1, "match.aggregate.victory"
	)
	var victory_authority := TestVictoryAuthorityPort.new(
		"issuer.aggregate.victory", RefCounted.new()
	)
	var qualification_proof := _issue_victory_qualification(
		victory_authority,
		qualification_state,
		"proof.aggregate.victory.qualify",
		"condition.aggregate.victory",
		true,
		1
	)
	var qualification_intent := _victory_qualification_intent(
		qualification_state,
		"intent.aggregate.victory.qualify",
		"condition.aggregate.victory",
		qualification_proof
	)
	_expect(
		_same_string_set(
			qualification_intent.keys(),
			shapes.get("submit_victory_qualification", []) as Array
		),
		"victory-qualification Intent exact fields match registry"
	)
	var qualification := _submit_victory_qualification(
		qualification_state, qualification_intent, victory_authority
	)
	var pending_state := qualification.get("state", {}) as Dictionary
	_expect(
		bool((qualification.get("receipt", {}) as Dictionary).get(
			"accepted", false
		))
			and bool((pending_state.get("victory_gate", {}) as Dictionary).get(
				"pending", false
			)),
		"trusted victory qualification executes and enters pending state"
	)
	var collision_proof := _issue_victory_qualification(
		victory_authority,
		qualification_state,
		"proof.aggregate.victory.qualify.collision",
		"condition.aggregate.victory",
		true,
		1
	)
	var qualification_collision_intent := _victory_qualification_intent(
		qualification_state,
		"intent.aggregate.victory.qualify",
		"condition.aggregate.victory",
		collision_proof
	)
	var qualification_collision := _submit_victory_qualification(
		pending_state, qualification_collision_intent, victory_authority
	)
	_expect(
		str((qualification_collision.get("receipt", {}) as Dictionary).get(
			"reason_code", ""
		)) == "intent_id_collision"
			and qualification_collision.get("state") == pending_state,
		"qualification rejects a different payload under one Intent ID"
	)

	var boundary := _complete_victory_boundary()
	var boundary_proof := _issue_victory_boundary(
		victory_authority,
		pending_state,
		"proof.aggregate.victory.revalidate",
		boundary,
		true,
		"settlement.aggregate.victory",
		2
	)
	var revalidation_intent := _victory_revalidation_intent(
		pending_state,
		"intent.aggregate.victory.revalidate",
		"condition.aggregate.victory",
		boundary_proof
	)
	_expect(
		_same_string_set(
			revalidation_intent.keys(),
			shapes.get(
				"revalidate_victory_at_macro_round_boundary", []
			) as Array
		),
		"victory-revalidation Intent exact fields match registry"
	)
	var revalidated := _revalidate_victory(
		pending_state, revalidation_intent, victory_authority
	)
	var committed_state := revalidated.get("state", {}) as Dictionary
	var committed_receipt := revalidated.get("receipt", {}) as Dictionary
	_expect(
		bool(committed_receipt.get("accepted", false))
			and bool(committed_receipt.get("final_settlement_committed", false))
			and int(committed_receipt.get("final_settlement_count", 0)) == 1,
		"macro-round revalidation commits FinalSettlement once"
	)
	var duplicate := _revalidate_victory(
		committed_state, revalidation_intent, victory_authority
	)
	_expect(
		duplicate.get("state") == committed_state
			and duplicate.get("receipt") == committed_receipt,
		"FinalSettlement duplicate Intent returns exact prior result"
	)
	var collision_intent := revalidation_intent.duplicate(true)
	collision_intent["proof_id"] = "proof.aggregate.victory.revalidate.collision"
	collision_intent["proof_fingerprint"] = (
		"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	)
	var collision := _revalidate_victory(
		committed_state, collision_intent, victory_authority
	)
	_expect(
		str((collision.get("receipt", {}) as Dictionary).get(
			"reason_code", ""
		)) == "intent_id_collision"
			and collision.get("state") == committed_state,
		"revalidation rejects a different payload under one Intent ID"
	)


func _test_ai_player_same_source_and_privacy(
	registry: Dictionary,
	invocations: Dictionary
) -> void:
	var unified := _surfaces(invocations, DOMAIN_IDS[0])
	var unified_ai := unified.get("AiObservationV1", {}) as Dictionary
	var unified_player := unified.get("PlayerProjectionV1", {}) as Dictionary
	var unified_ai_private := unified_ai.get("viewer_private_facts", {}) as Dictionary
	var unified_player_private := (
		unified_player.get("viewer_private_facts", {}) as Dictionary
	)
	_expect(
		unified_ai.get("source_revision") == unified_player.get("source_revision")
			and unified_ai.get("public_facts") == unified_player.get("public_facts"),
		"unified AI and Player derive from one Core revision and public facts"
	)
	_expect(
		_same_string_set(
			unified_ai_private.keys(),
			["own_segment_items", "own_pending_stance"]
		)
			and _same_string_set(
				unified_player_private.keys(),
				[
					"own_segment_items",
					"own_pending_stance",
					"self_lead_notice",
					"self_lead_notice_token",
				]
			),
		"unified Player alone receives private self-lead notice fields"
	)
	_expect(
		not unified_ai_private.has("self_lead_notice")
			and not unified_ai_private.has("self_lead_notice_token"),
		"unified AI never receives self-lead notice"
	)

	var dbg := _surfaces(invocations, DOMAIN_IDS[1])
	var dbg_ai := dbg.get("AiObservationV1", {}) as Dictionary
	var dbg_player := dbg.get("PlayerProjectionV1", {}) as Dictionary
	_expect(
		dbg_ai.get("core_fingerprint") == dbg_player.get("core_fingerprint")
			and dbg_ai.get("facts") == dbg_player.get("facts"),
		"DBG AI and Player project one owner-authorized Core snapshot"
	)
	var unauthorized_dbg := DBG_CORE.new()
	unauthorized_dbg.initialize(ROSTER[0], FIXED_SEED)
	_expect(
		unauthorized_dbg.ai_observation(ROSTER[1]).is_empty()
			and unauthorized_dbg.player_projection(ROSTER[1]).is_empty(),
		"DBG non-owner projections fail closed"
	)

	var assets := _surfaces(invocations, DOMAIN_IDS[2])
	var asset_ai := assets.get("AiObservationV1", {}) as Dictionary
	var asset_player := assets.get("PlayerProjectionV1", {}) as Dictionary
	for field in [
		"viewer_id",
		"state_revision",
		"own_exact_assets",
		"own_remainders",
		"own_reservations",
		"own_available_assets",
		"own_projected_refresh",
		"public_costs",
	]:
		_expect(
			asset_ai.get(field) == asset_player.get(field),
			"asset AI and Player share %s from one Core state" % field
		)
	_expect(
		not _contains_value(asset_ai, ROSTER[1])
			and not _contains_value(asset_player, ROSTER[1]),
		"asset projections exclude rival identity and private balances"
	)

	var batch := _surfaces(invocations, DOMAIN_IDS[3])
	var batch_ai := batch.get("AiObservationV1", {}) as Dictionary
	var batch_player := batch.get("PlayerProjectionV1", {}) as Dictionary
	for field in [
		"viewer_id",
		"state_revision",
		"own_local_queue",
		"own_prebound_targets",
		"own_reserved_costs",
		"anonymous_public_queue",
		"public_resolution_aftermath",
	]:
		_expect(
			batch_ai.get(field) == batch_player.get(field),
			"batch AI and Player share %s from one Core state" % field
		)
	_expect(
		not _contains_value(batch_ai, ROSTER[1])
			and not _contains_value(batch_player, ROSTER[1]),
		"batch projections hide rival and anonymous-queue owner identity"
	)

	var solar := _surfaces(invocations, DOMAIN_IDS[4])
	var solar_ai := solar.get("AiObservationV1", {}) as Dictionary
	var solar_player := solar.get("PlayerProjectionV1", {}) as Dictionary
	for field in [
		"solar_phase_id",
		"facility_work_rate_multiplier",
		"victory_pending",
		"macro_round_index",
		"final_settlement_committed",
	]:
		_expect(
			solar_ai.get(field) == solar_player.get(field),
			"solar/victory AI and Player share %s" % field
		)

	for domain_id in DOMAIN_IDS:
		var domain := _registry_domain(registry, domain_id)
		var contracts := domain.get("contracts", {}) as Dictionary
		var called := _surfaces(invocations, domain_id)
		for surface in ["AiObservationV1", "PlayerProjectionV1"]:
			var contract := contracts.get(surface, {}) as Dictionary
			var projection := called.get(surface, {}) as Dictionary
			for forbidden_variant in contract.get("forbidden_fields", []) as Array:
				_expect(
					not _contains_exact_key(projection, str(forbidden_variant)),
					"%s %s excludes %s"
						% [domain_id, surface, forbidden_variant]
				)


func _test_domain_local_save_roundtrips(
	registry: Dictionary,
	invocations: Dictionary
) -> void:
	for domain_id in DOMAIN_IDS:
		var fixture := invocations.get(domain_id, {}) as Dictionary
		var roundtrip := fixture.get("roundtrip", {}) as Dictionary
		var save_contract := (
			(_registry_domain(registry, domain_id).get("contracts", {}) as Dictionary)
				.get("SaveStateV1", {}) as Dictionary
		)
		var local_contract := save_contract.get("local_roundtrip", {}) as Dictionary
		_expect(
			str(local_contract.get("status", ""))
				== "PURE_REFERENCE_IMPLEMENTED",
			"%s registry marks local Save roundtrip implemented" % domain_id
		)
		_expect(
			bool(roundtrip.get("restore_ok", false)),
			"%s local Save restore succeeds" % domain_id
		)
		if [DOMAIN_IDS[2], DOMAIN_IDS[3]].has(domain_id):
			var domain_preflight := roundtrip.get(
				"domain_preflight", {}
			) as Dictionary
			_expect(
				bool(domain_preflight.get("preflight_valid", false))
					and not bool(domain_preflight.get("restored", true))
					and (domain_preflight.get("state", {}) as Dictionary).is_empty(),
				"%s individual Save restore is preflight-only" % domain_id
			)
		_expect(
			roundtrip.get("source") == roundtrip.get("recaptured"),
			"%s local Save capture/restore/recapture is exact" % domain_id
		)
		_expect(
			fixture.get("rng_before") == fixture.get("rng_after")
				and fixture.get("rng_after") == fixture.get("rng_restored"),
			"%s projection, Intent sample, Save, and restore advance no RNG"
				% domain_id
		)
		var domain := _registry_domain(registry, domain_id)
		if (domain.get("rng_stream_ids", []) as Array).is_empty():
			_expect(
				(fixture.get("rng_before", {}) as Dictionary).is_empty(),
				"%s remains a zero-RNG domain" % domain_id
			)


func _test_save_schema_contract(
	save_schema: Dictionary,
	invocations: Dictionary
) -> void:
	_expect(
		str(save_schema.get("save_schema_id", ""))
			== "space_syndicate.v07.semantic_save.v1",
		"canonical Save envelope identity is exact"
	)
	_expect(
		str(save_schema.get("status", ""))
			== "reference_contract_not_production_wired"
			and str(save_schema.get("canonical_envelope_adapter_status", ""))
				== "NOT_IMPLEMENTED"
			and int(save_schema.get(
				"v07_production_runtime_connection_count", -1
			)) == 0,
		"canonical Save envelope is explicitly unwired and not implemented"
	)
	var sections := save_schema.get("sections", []) as Array
	_expect(
		sections.size() == EXPECTED_CANONICAL_SAVE_SECTIONS.size(),
		"canonical Save envelope has exactly five sections"
	)
	var observed_section_ids: Array[String] = []
	for section_variant in sections:
		var section := section_variant as Dictionary
		var section_id := str(section.get("section_id", ""))
		observed_section_ids.append(section_id)
		var expected := (
			EXPECTED_CANONICAL_SAVE_SECTIONS.get(section_id, {}) as Dictionary
		)
		_expect(
			not expected.is_empty(),
			"canonical Save section %s is in the exact closed set" % section_id
		)
		_expect(
			int(section.get("section_version", -1))
				== int(expected.get("section_version", -2))
				and str(section.get("semantic_owner", ""))
					== str(expected.get("semantic_owner", ""))
				and str(section.get("registry_save_contract_id", ""))
					== str(expected.get("registry_save_contract_id", ""))
				and str(section.get("privacy", ""))
					== str(expected.get("privacy", "")),
			"canonical Save section %s metadata is exact" % section_id
		)
		var required := section.get("required_fields", []) as Array
		var expected_required := expected.get("required_fields", []) as Array
		_expect(
			_same_string_set(required, expected_required),
			"canonical Save section %s field set is exact" % section_id
		)
		var local_adapter := section.get("local_adapter", {}) as Dictionary
		var local_field_key := str(expected.get("local_adapter_field_key", ""))
		_expect(
			_same_string_set(
				local_adapter.get(local_field_key, []) as Array,
				required
			),
			"canonical Save section %s local-adapter field set is exact"
				% section_id
		)
		var field_contracts := section.get("field_contracts", {}) as Dictionary
		_expect(
			_same_string_set(field_contracts.keys(), required),
			"canonical Save section %s contracts every required field exactly once"
				% section_id
		)
		_expect(
			_same_json_contract(
				field_contracts, expected.get("field_contracts", {})
			),
			"canonical Save section %s field_contracts are exact" % section_id
		)
		var actual_save := (
			_surfaces(invocations, section_id).get("SaveStateV1", {}) as Dictionary
		)
		_expect(
			_same_string_set(actual_save.keys(), required),
			"canonical Save section %s matches current adapter payload exactly"
				% section_id
		)
		var expected_canonical := expected.get(
			"canonical_required_fields", []
		) as Array
		if not expected_canonical.is_empty():
			var canonical_required := section.get(
				"canonical_required_fields", []
			) as Array
			_expect(
				_same_string_set(canonical_required, expected_canonical),
				"canonical Save section %s future field set is exact" % section_id
			)
			var future_contracts := section.get(
				"future_required_field_contracts", {}
			) as Dictionary
			var all_contract_fields: Array = field_contracts.keys()
			all_contract_fields.append_array(future_contracts.keys())
			_expect(
				_same_string_set(all_contract_fields, canonical_required),
				"canonical Save section %s structurally contracts every future field"
					% section_id
			)
	_expect(
		_same_string_array(observed_section_ids, DOMAIN_IDS)
			and _same_string_set(
				observed_section_ids, EXPECTED_CANONICAL_SAVE_SECTIONS.keys()
			),
		"canonical Save section identity and order are exact"
	)
	_set_category("V07_PRIVACY")
	var privacy := save_schema.get("privacy_contract", {}) as Dictionary
	for field in [
		"personal_draw_pile_order",
		"personal_hand",
		"commodity_inventory",
		"exact_six_color_assets",
		"local_queue_owner_binding",
	]:
		_expect(
			(privacy.get("player_private_fields", []) as Array).has(field),
			"canonical Save privacy marks %s player-private" % field
		)
	for field in [
		"future_track_order",
		"supply_bag_order",
		"hidden_lead_order",
		"anonymous_queue_owner_bindings",
		"rng_seed_cursor_or_state",
	]:
		_expect(
			(privacy.get("core_private_fields", []) as Array).has(field),
			"canonical Save privacy marks %s Core-private" % field
		)
	_set_category("V07_SAVE")
	var tagged_int64 := (
		(save_schema.get("wire_types", {}) as Dictionary).get(
			"tagged_int64", {}
		) as Dictionary
	)
	_expect(
		_same_string_set(
			tagged_int64.get("required_fields", []) as Array,
			["type", "decimal"]
		),
		"canonical Save preserves tagged Int64 wire fields"
	)


func _test_asset_batch_shared_save_pair() -> void:
	var state := _create_asset_batch_state("batch.aggregate.shared.pair", 3000)
	_expect(
		bool(ASSET_BATCH_CORE.validation_report(state).get("valid", false)),
		"asset/batch shared-pair fixture validates"
	)
	var asset_save: Dictionary = ASSET_BATCH_CORE.to_asset_save_state(state)
	var batch_save: Dictionary = ASSET_BATCH_CORE.to_batch_save_state(state)
	_expect(
		_same_string_set(
			asset_save.keys(),
			[
				"schema_version",
				"contract_id",
				"section_id",
				"ruleset_id",
				"state_revision",
				"per_player_assets_by_color",
				"per_player_fixed_point_remainders",
				"gdp_cycle_snapshot",
				"per_action_reservations",
				"reservation_journal",
				"asset_refresh_revision",
				"shared_batch_id",
				"shared_lineage_fingerprint",
				"shared_authority_state",
				"save_fingerprint",
			]
		),
		"asset Save exposes the exact shared batch/lineage contract"
	)
	_expect(
		_same_string_set(
			batch_save.keys(),
			[
				"schema_version",
				"contract_id",
				"section_id",
				"ruleset_id",
				"state_revision",
				"submission_window_state",
				"player_local_queues",
				"prebound_targets",
				"private_owner_bindings",
				"anonymous_global_queue",
				"round_robin_cursor",
				"resolution_journal",
				"processed_intent_ids",
				"intent_receipt_ledger",
				"shared_batch_id",
				"shared_lineage_fingerprint",
				"shared_authority_state",
				"save_fingerprint",
			]
		),
		"batch Save exposes the exact shared batch/lineage contract"
	)
	_expect(
		asset_save.get("shared_batch_id") == batch_save.get("shared_batch_id")
			and asset_save.get("shared_batch_id") == state.get("batch_id"),
		"asset and batch Save share the exact authoritative batch identity"
	)
	_expect(
		asset_save.get("shared_lineage_fingerprint")
				== batch_save.get("shared_lineage_fingerprint")
			and asset_save.get("shared_lineage_fingerprint")
				== state.get("lineage_fingerprint"),
		"asset and batch Save share the exact authoritative lineage fingerprint"
	)
	_expect(
		asset_save.get("shared_authority_state")
				== batch_save.get("shared_authority_state")
			and asset_save.get("shared_authority_state") == state,
		"asset and batch Save carry one exact shared authority state"
	)
	_expect(
		asset_save.get("ruleset_id") == "v0.7"
			and batch_save.get("ruleset_id") == "v0.7",
		"asset and batch Save bind the exact V0.7 ruleset"
	)
	var asset_preflight: Dictionary = ASSET_BATCH_CORE.restore_domain_save_state(
		asset_save, ASSET_BATCH_CORE.ASSET_SAVE_STATE_ID
	)
	var batch_preflight: Dictionary = ASSET_BATCH_CORE.restore_domain_save_state(
		batch_save, ASSET_BATCH_CORE.BATCH_SAVE_STATE_ID
	)
	_expect(
		bool(asset_preflight.get("preflight_valid", false))
			and not bool(asset_preflight.get("restored", true))
			and (asset_preflight.get("state", {}) as Dictionary).is_empty()
			and bool(batch_preflight.get("preflight_valid", false))
			and not bool(batch_preflight.get("restored", true))
			and (batch_preflight.get("state", {}) as Dictionary).is_empty(),
		"individual asset and batch restore is strict preflight-only"
	)
	var pair_restore: Dictionary = ASSET_BATCH_CORE.restore_domain_save_pair(
		asset_save, batch_save
	)
	_expect(
		bool(pair_restore.get("restored", false))
			and pair_restore.get("state") == state,
		"asset and batch local split payloads restore as one exact shared pair"
	)


func _test_port_quiescence(
	registry: Dictionary,
	save_schema: Dictionary,
	restore_graph: Dictionary,
	invocations: Dictionary
) -> void:
	_set_category("V07_SAVE")
	var common := registry.get("common_invariants", {}) as Dictionary
	_expect(
		bool(common.get("domain_save_capture_requires_transactional_quiescence", false))
			and not bool(common.get(
				"transient_authority_port_objects_are_save_or_projection_data", true
			)),
		"registry requires quiescent Save capture and transient ports"
	)
	var unified_domain := _registry_domain(registry, DOMAIN_IDS[0])
	var port_spec := unified_domain.get(
		"transient_acquisition_authority_port", {}
	) as Dictionary
	_expect(
		str(port_spec.get("interface_id", ""))
			== "v07.unified_track.acquisition_authority_port.v1"
			and str(port_spec.get("implementation_file", ""))
				== "res://scripts/v07_semantic/v07_track_acquisition_authority_port.gd"
			and _same_string_array(
				port_spec.get("participant_roles", []) as Array,
				["cash", "personal_discard", "commodity_slot"]
			)
			and _same_string_array(
				port_spec.get("entrypoints", []) as Array,
				[
					"configure_v1",
					"prepare_v1",
					"commit_v1",
					"abort_v1",
					"receipt_v1",
					"recovery_v1",
					"recover_rollback_v1",
					"capture_receipt_journal_v1",
					"apply_receipt_journal_v1",
					"transact_v1",
				]
			),
		"registry acquisition-port API is exact"
	)
	var unified_port := (
		invocations.get(DOMAIN_IDS[0], {}) as Dictionary
	).get("port_quiescence", {}) as Dictionary
	var port_contract := unified_port.get("contract", {}) as Dictionary
	_expect(
		_same_string_set(
			port_contract.keys(),
			[
				"schema_version",
				"interface_id",
				"ruleset_id",
				"domain_id",
				"participant_roles",
				"caller_supplied_receipts_trusted",
				"transaction_owned_rollback_required",
				"receipt_journal_capture_apply_supported",
				"object_identity_pinned_until_port_replacement",
				"production_runtime_connected",
			]
		)
			and port_contract.get("interface_id") == port_spec.get("interface_id")
			and not bool(port_contract.get("production_runtime_connected", true)),
		"trusted acquisition port exposes the exact unwired contract"
	)
	var status := unified_port.get("transaction_status", {}) as Dictionary
	_expect(
		_same_string_set(
			status.keys(),
			["quiescent", "active_transaction_count", "transaction_rows"]
		)
			and bool(status.get("quiescent", false))
			and int(status.get("active_transaction_count", -1)) == 0
			and (status.get("transaction_rows", []) as Array).is_empty(),
		"unified acquisition port is quiescent before Save capture"
	)
	var journal := unified_port.get("receipt_journal", {}) as Dictionary
	_expect(
		_same_string_set(
			journal.keys(),
			port_spec.get("receipt_journal_exact_fields", []) as Array
		)
			and str(journal.get("interface_id", ""))
				== str(port_spec.get("receipt_journal_contract_id", ""))
			and (journal.get("composite_receipts", []) as Array).is_empty()
			and _is_pure_data(journal),
		"quiescent acquisition receipt journal is exact pure data"
	)
	var dbg_checkpoint := (
		invocations.get(DOMAIN_IDS[1], {}) as Dictionary
	).get("port_quiescence", {}) as Dictionary
	_expect(
		_same_string_set(
			dbg_checkpoint.keys(),
			[
				"schema_id",
				"schema_version",
				"authority_id",
				"core_checkpoint",
				"reservations",
				"commit_receipts",
				"checkpoint_fingerprint",
			]
		)
			and (dbg_checkpoint.get("reservations", {}) as Dictionary).is_empty()
			and (dbg_checkpoint.get("commit_receipts", {}) as Dictionary).is_empty(),
		"DBG acquisition participant is quiescent before Save capture"
	)
	var save_quiescence := (
		_save_section(save_schema, DOMAIN_IDS[0]).get(
			"transactional_quiescence", {}
		) as Dictionary
	)
	_expect(
		_same_string_set(
			save_quiescence.keys(),
			[
				"active_acquisition_transaction_count_must_equal",
				"half_committed_save_allowed",
				"port_receipt_journal_contract_id",
				"port_receipt_journal_pure_data_required",
				"transient_port_or_participant_objects_persisted",
			]
		)
			and int(save_quiescence.get(
				"active_acquisition_transaction_count_must_equal", -1
			)) == 0
			and not bool(save_quiescence.get("half_committed_save_allowed", true)),
		"canonical Save structurally requires acquisition-port quiescence"
	)
	var graph_invariants := restore_graph.get("graph_invariants", {}) as Dictionary
	_expect(
		bool(graph_invariants.get(
			"all_domain_transactions_quiescent_before_capture_and_restore", false
		))
			and not bool(graph_invariants.get(
				"unified_half_committed_acquisition_save_allowed", true
			))
			and not bool(graph_invariants.get(
				"asset_and_batch_single_section_apply_allowed", true
			))
			and bool(graph_invariants.get(
				"asset_and_batch_pair_preflight_required_before_apply", false
			)),
		"restore contract requires quiescent ports and paired apply"
	)
	var unbound: Dictionary = _timed_asset_batch_core.unbind_time_attestation_authority()
	_expect(
		not bool(unbound.get("bound", true))
			and str(unbound.get("reason_code", ""))
				== "time_attestation_authority_unbound",
		"trusted time-attestation port is released after aggregate actions"
	)

	_set_category("V07_PRIVACY")
	var solar_port_spec := _registry_domain(registry, DOMAIN_IDS[4]).get(
		"transient_victory_proof_port", {}
	) as Dictionary
	_expect(
		_same_string_array(
			solar_port_spec.get("required_methods", []) as Array,
			[
				"victory_authority_identity_v1",
				"victory_capability_identity_v1",
				"victory_current_source_revision_v1",
				"victory_lookup_issued_proof_v1",
			]
		)
			and not bool(solar_port_spec.get(
				"port_and_capability_objects_persisted", true
			))
			and not bool(solar_port_spec.get(
				"port_and_capability_objects_projected", true
			)),
		"victory proof port and opaque capability remain transient"
	)
	for domain_id in DOMAIN_IDS:
		var save := _surfaces(invocations, domain_id).get(
			"SaveStateV1", {}
		) as Dictionary
		for transient_key in [
			"acquisition_authority_port",
			"acquisition_participant_objects",
			"track_receipt_authority",
			"time_attestation_authority_port",
			"victory_proof_lookup_port",
			"authority_capability",
		]:
			_expect(
				not _contains_exact_key(save, transient_key),
				"%s Save excludes transient %s" % [domain_id, transient_key]
			)
	_set_category("V07_SAVE")


func _test_restore_graph_contract(restore_graph: Dictionary) -> void:
	_expect(
		str(restore_graph.get("status", ""))
			== "future_canonical_adapter_contract_NOT_IMPLEMENTED"
			and str(restore_graph.get(
				"canonical_restore_implementation_status", ""
			)) == "NOT_IMPLEMENTED"
			and int(restore_graph.get(
				"v07_production_runtime_connection_count", -1
			)) == 0,
		"canonical restore is a complete structural contract, not an implementation"
	)
	var implementation := (
		restore_graph.get("implementation_contract", {}) as Dictionary
	)
	_expect(
		not bool(implementation.get(
			"aggregate_canonical_envelope_adapter_exists", true
		))
			and not bool(implementation.get(
				"aggregate_transaction_coordinator_exists", true
			))
			and not bool(implementation.get(
				"graph_may_be_reported_executable_now", true
			)),
		"canonical restore contract cannot be reported executable"
	)
	_expect(
		_same_string_array(
			implementation.get("activation_blockers", []) as Array,
			[
				"canonical_five_section_envelope_adapter_not_implemented",
				"canonical_rng_ledger_adapter_not_implemented",
			]
		),
		"canonical restore activation blockers are exact"
	)
	var local_roundtrips := implementation.get(
		"local_domain_roundtrips", {}
	) as Dictionary
	_expect(
		_same_string_set(
			local_roundtrips.keys(),
			[
				"unified_card_track_cycle",
				"personal_dbg_and_merge",
				"asset_batch_paired_domain_save",
				"solar_facility_and_macro_victory",
			]
		)
			and str((local_roundtrips.get(
				"asset_batch_paired_domain_save", {}
			) as Dictionary).get("paired_apply_entrypoint", ""))
				== "V07AssetBatchCore.restore_domain_save_pair"
			and str((local_roundtrips.get(
				"asset_batch_paired_domain_save", {}
			) as Dictionary).get("split_asset_and_batch_rejoin_status", ""))
				== "IMPLEMENTED_PURE_REFERENCE",
		"local restore contracts are exact while canonical restore is absent"
	)
	var nodes := restore_graph.get("restore_nodes", []) as Array
	_expect(
		nodes.size() == EXPECTED_RESTORE_NODES.size(),
		"restore graph parses exactly ten ordered nodes"
	)
	var observed_ids: Array[String] = []
	var order_by_id: Dictionary = {}
	for index in nodes.size():
		var node_variant: Variant = nodes[index]
		var node := node_variant as Dictionary
		var expected := EXPECTED_RESTORE_NODES[index] as Dictionary
		var node_id := str(node.get("node_id", ""))
		var order := int(node.get("restore_order", 0))
		observed_ids.append(node_id)
		_expect(
			_same_string_set(
				node.keys(),
				[
					"restore_order",
					"node_id",
					"section_id",
					"binding_status",
					"depends_on",
					"preflight",
					"apply_operation_token",
					"checkpoint_operation_token",
					"rollback_operation_token",
					"privacy",
				]
			),
			"restore node %s has the exact contract shape" % node_id
		)
		var expected_binding_status := (
			"NOT_IMPLEMENTED_FUTURE_CANONICAL_ADAPTER_SUBSTATE"
			if [
				"hidden_lead_cycle",
				"solar_facility_state",
				"macro_round_victory_gate",
			].has(node_id)
			else "NOT_IMPLEMENTED_FUTURE_CANONICAL_ADAPTER"
		)
		_expect(
			str(node.get("binding_status", "")) == expected_binding_status,
			"restore node %s remains explicitly NOT_IMPLEMENTED" % node_id
		)
		_expect(
			node_id == str(expected.get("node_id", ""))
				and str(node.get("section_id", ""))
					== str(expected.get("section_id", "")),
			"restore node %d identity and section are exact" % (index + 1)
		)
		_expect(
			order == index + 1,
			"restore_order is contiguous at node %s" % node_id
		)
		_expect(
			_same_string_array(
				node.get("depends_on", []) as Array,
				expected.get("depends_on", []) as Array
			),
			"restore node %s dependency set and order are exact" % node_id
		)
		_expect(
			not order_by_id.has(node_id),
			"restore node %s appears exactly once" % node_id
		)
		order_by_id[node_id] = order
	_expect(
		_same_string_set(observed_ids, EXPECTED_RESTORE_NODES.map(
			func(row: Dictionary) -> String: return str(row.get("node_id", ""))
		)),
		"restore graph node set is exact"
	)
	for node_variant in nodes:
		var node := node_variant as Dictionary
		var node_id := str(node.get("node_id", ""))
		var node_order := int(order_by_id.get(node_id, 0))
		for dependency_variant in node.get("depends_on", []) as Array:
			var dependency_id := str(dependency_variant)
			_expect(
				order_by_id.has(dependency_id)
					and int(order_by_id.get(dependency_id, 0)) < node_order,
				"restore dependency %s has lower numeric order than %s"
					% [dependency_id, node_id]
			)
	var invariants := restore_graph.get("graph_invariants", {}) as Dictionary
	_expect(
		bool(invariants.get("directed_acyclic", false))
			and bool(invariants.get("all_sections_preflight_before_any_apply", false))
			and bool(invariants.get("rollback_reverse_apply_order", false))
			and int(invariants.get("restore_consumes_rng", -1)) == 0,
		"restore graph is atomic, acyclic, reversible, and RNG-neutral"
	)


func _test_rng_ownership_contract(rng_ownership: Dictionary) -> void:
	_expect(
		str(rng_ownership.get("status", ""))
			== "reference_contract_not_production_wired"
			and str(rng_ownership.get(
				"canonical_rng_ledger_adapter_status", ""
			)) == "NOT_IMPLEMENTED"
			and int(rng_ownership.get(
				"v07_production_runtime_connection_count", -1
			)) == 0,
		"canonical RNG ledger is explicitly unwired and not implemented"
	)
	var streams := rng_ownership.get("streams", []) as Array
	_expect(
		streams.size() == EXPECTED_RNG_STREAM_MAPPING.size()
			and int(rng_ownership.get("stream_count", 0))
				== EXPECTED_RNG_STREAM_MAPPING.size()
			and str(rng_ownership.get("stream_count_semantics", ""))
				== "logical_stream_id_count"
			and int(rng_ownership.get("logical_stream_id_count", 0)) == 7
			and str(rng_ownership.get(
				"concrete_stream_instance_count_formula", ""
			)) == "5 + (2 * roster_count)",
		"RNG ownership distinguishes seven logical streams from 5 + 2N instances"
	)
	var observed_ids: Array[String] = []
	var seen: Dictionary = {}
	for stream_variant in streams:
		var stream := stream_variant as Dictionary
		var stream_id := str(stream.get("stream_id", ""))
		observed_ids.append(stream_id)
		var expected := EXPECTED_RNG_STREAM_MAPPING.get(stream_id, {}) as Dictionary
		_expect(
			not expected.is_empty()
				and str(stream.get("authoritative_owner_id", ""))
					== str(expected.get("authoritative_owner_id", ""))
				and str(stream.get("save_section_id", ""))
					== str(expected.get("save_section_id", ""))
				and str(stream.get("state_profile_id", ""))
					== str(expected.get("state_profile_id", ""))
				and str(stream.get("privacy", ""))
					== str(expected.get("privacy", "")),
			"RNG stream %s owner/Save/profile/privacy mapping is exact" % stream_id
		)
		_expect(
			not seen.has(stream_id),
			"RNG stream %s appears exactly once" % stream_id
		)
		seen[stream_id] = true
		var forbidden := stream.get("forbidden_consumers", []) as Array
		_expect(
			forbidden.has("ai_observation")
				and forbidden.has("player_projection")
				and forbidden.has("ui")
				and forbidden.has("animation"),
			"RNG stream %s forbids projection and presentation draws" % stream_id
		)
		_expect(
			str(stream.get("privacy", "")).contains("private"),
			"RNG stream %s seed/cursor privacy is explicit" % stream_id
		)
	_expect(
		_same_string_array(observed_ids, REQUIRED_RNG_STREAM_IDS)
			and _same_string_set(
				observed_ids, EXPECTED_RNG_STREAM_MAPPING.keys()
			),
		"RNG stream IDs and order match the exact seven-stream mapping"
	)
	var ledger := rng_ownership.get("canonical_rng_ledger", {}) as Dictionary
	_expect(
		_same_string_set(
			ledger.get("row_required_fields", []) as Array,
			[
				"schema_version",
				"stream_id",
				"stream_instance_id",
				"state_profile_id",
				"authoritative_owner_id",
				"save_section_id",
				"state",
				"state_fingerprint",
			]
		),
		"future canonical RNG ledger row field set is exact"
	)
	_expect(
		str(ledger.get("status", ""))
			== "future_canonical_adapter_output_NOT_IMPLEMENTED"
			and not bool(ledger.get("canonical_row_is_second_rng_authority", true)),
		"future canonical RNG rows are not a second authority"
	)
	var profiles := rng_ownership.get("state_profiles", {}) as Dictionary
	_expect(
		_same_string_set(
			profiles.keys(),
			[
				"dbg_tagged_sha256_counter_v1",
				"unified_park_miller_embedded_v1",
			]
		),
		"RNG ownership declares exactly two wire/state profiles"
	)
	var dbg_profile := profiles.get(
		"dbg_tagged_sha256_counter_v1", {}
	) as Dictionary
	_expect(
		_same_string_set(
			dbg_profile.get("exact_state_fields", []) as Array,
			[
				"schema_version",
				"stream_id",
				"stream_instance_id",
				"authoritative_owner_id",
				"algorithm_id",
				"seed",
				"cursor",
				"stream_revision",
				"state_fingerprint",
			]
		)
			and str(dbg_profile.get("seed_type", "")) == "tagged_int64"
			and str(dbg_profile.get("cursor_type", ""))
				== "tagged_int64_nonnegative"
			and not bool(dbg_profile.get("cursor_default_allowed", true))
			and not bool(dbg_profile.get("cursor_reconstruction_allowed", true)),
		"DBG RNG profile has exact tagged counter state with no defaults"
	)
	var unified_profile := profiles.get(
		"unified_park_miller_embedded_v1", {}
	) as Dictionary
	_expect(
		_same_string_set(
			unified_profile.get(
				"exact_rng_state_fields_within_owning_state", []
			) as Array,
			["rng_state", "rng_draw_count"]
		)
			and int(unified_profile.get("owning_authority_state_version", 0)) == 2
			and int(unified_profile.get("rng_state_minimum", 0)) == 1
			and int(unified_profile.get("rng_state_maximum", 0)) == 2147483646
			and bool(unified_profile.get(
				"canonical_adapter_must_not_rewrite_or_reconstruct_rng_state", false
			)),
		"unified RNG profile preserves embedded Park-Miller state exactly"
	)
	var privacy := rng_ownership.get("privacy_contract", {}) as Dictionary
	for field in [
		"root_match_seed",
		"derived_stream_seed",
		"cursor",
		"future_draw_result",
		"personal_deck_order",
		"hidden_lead_order",
	]:
		_expect(
			(privacy.get("core_private_fields", []) as Array).has(field),
			"RNG privacy marks %s Core-private" % field
		)


func _test_no_v06_or_main_connection(
	registry: Dictionary,
	save_schema: Dictionary,
	restore_graph: Dictionary,
	rng_ownership: Dictionary
) -> void:
	_expect(
		int(registry.get("v07_production_runtime_connection_count", -1)) == 0
			and str(registry.get("v06_runtime_wiring", "")) == "forbidden",
		"domain registry has zero V0.6 production wiring"
	)
	var boundary := registry.get("save_contract_boundary", {}) as Dictionary
	_expect(
		str(boundary.get("canonical_envelope_adapter_status", ""))
			== "NOT_IMPLEMENTED"
			and int(boundary.get("v06_save_adapter_connection_count", -1)) == 0,
		"domain-local Save has no canonical or V0.6 adapter connection"
	)
	_expect(
		int(save_schema.get("v07_production_runtime_connection_count", -1)) == 0
			and not bool(save_schema.get("v06_save_owner_registry_connection", true))
			and not bool(save_schema.get("v06_save_direct_load_allowed", true)),
		"canonical Save contract has no V0.6 Registry or direct-load connection"
	)
	_expect(
		int(restore_graph.get("v07_production_runtime_connection_count", -1)) == 0
			and not bool(restore_graph.get("v06_registry_reuse_allowed", true))
			and not bool(restore_graph.get("v06_save_direct_restore_allowed", true)),
		"restore graph has no V0.6 production connection"
	)
	_expect(
		int(rng_ownership.get("v07_production_runtime_connection_count", -1)) == 0
			and not bool(rng_ownership.get("v06_rng_owner_reuse_allowed", true)),
		"RNG ownership has no V0.6 owner reuse"
	)
	var forbidden_source_tokens := [
		"extends Node",
		"res://scripts/main.gd",
		"res://scenes/main.tscn",
		"GameRuntimeCoordinator",
		"V06SaveOwnerRegistry",
		"res://scripts/runtime/",
		"get_tree(",
		"get_node(",
	]
	for path in CORE_SOURCE_PATHS:
		var source := FileAccess.get_file_as_string(path)
		_expect(source.contains("extends RefCounted"), "%s is a pure RefCounted" % path)
		for forbidden in forbidden_source_tokens:
			_expect(
				not source.contains(forbidden),
				"%s has no production dependency %s" % [path, forbidden]
			)


func _load_json(path: String) -> Dictionary:
	var source := FileAccess.get_file_as_string(path)
	_expect(not source.is_empty(), "%s is readable" % path)
	var parsed: Variant = JSON.parse_string(source)
	_expect(parsed is Dictionary, "%s parses as a JSON object" % path)
	return parsed as Dictionary if parsed is Dictionary else {}


func _registry_domain(registry: Dictionary, domain_id: String) -> Dictionary:
	for domain_variant in registry.get("domains", []) as Array:
		var domain := domain_variant as Dictionary
		if str(domain.get("domain_id", "")) == domain_id:
			return domain
	return {}


func _save_section(save_schema: Dictionary, section_id: String) -> Dictionary:
	for section_variant in save_schema.get("sections", []) as Array:
		var section := section_variant as Dictionary
		if str(section.get("section_id", "")) == section_id:
			return section
	return {}


func _surfaces(invocations: Dictionary, domain_id: String) -> Dictionary:
	return (
		(invocations.get(domain_id, {}) as Dictionary).get("surfaces", {})
		as Dictionary
	)


func _unified_rng_snapshot(authority: Dictionary) -> Dictionary:
	var state := authority.get("authority_state", {}) as Dictionary
	var color_cycle := state.get("color_cycle_state", {}) as Dictionary
	return {
		"unified_track_type_draw": _rng_cursor_record(
			state.get("type_supply_state", {}) as Dictionary
		),
		"unified_track_color_draw": _rng_cursor_record(
			color_cycle.get("color_supply_state", {}) as Dictionary
		),
		"unified_track_normal_card_draw": _rng_cursor_record(
			state.get("normal_supply_state", {}) as Dictionary
		),
		"unified_track_commodity_draw": _rng_cursor_record(
			state.get("commodity_supply_state", {}) as Dictionary
		),
		"initial_hidden_lead_order": _rng_cursor_record(
			state.get("hidden_lead_cycle_state", {}) as Dictionary
		),
	}


func _dbg_rng_snapshot(authority: Dictionary) -> Dictionary:
	var state := authority.get("state", {}) as Dictionary
	return {
		"starter_deck_shuffle": (
			state.get("starter_rng", {}) as Dictionary
		).duplicate(true),
		"normal_deck_reshuffle_by_player": (
			state.get("reshuffle_rng", {}) as Dictionary
		).duplicate(true),
	}


func _rng_cursor_record(stream: Dictionary) -> Dictionary:
	var result := {
		"stream_id": stream.get("stream_id"),
		"rng_state": stream.get("rng_state"),
		"rng_draw_count": stream.get("rng_draw_count"),
	}
	for field in ["cursor", "bag_cycle"]:
		if stream.has(field):
			result[field] = stream.get(field)
	return result


func _issue_time_attestation(observed_at_ms: int) -> Dictionary:
	_time_attestation_sequence += 1
	var attestation := {
		"schema_version": 1,
		"interface_id": ASSET_BATCH_CORE.TIME_ATTESTATION_INTERFACE_ID,
		"attestation_id": "time.aggregate.%06d" % _time_attestation_sequence,
		"observed_at_ms": observed_at_ms,
	}
	attestation["attestation_fingerprint"] = ASSET_BATCH_CORE._fingerprint(
		attestation
	)
	_time_authority.commit_attestation(attestation)
	return attestation


func _lock_player_queue(
	state: Dictionary,
	intent: Dictionary,
	completed_gdp_milli: Dictionary,
	observed_at_ms: int,
	authoritative_hidden_lead_order: Array = []
) -> Dictionary:
	return _timed_asset_batch_core.lock_player_queue(
		state,
		intent,
		completed_gdp_milli,
		_issue_time_attestation(observed_at_ms),
		authoritative_hidden_lead_order
	)


func _issue_victory_qualification(
	authority,
	state: Dictionary,
	proof_id: String,
	condition_id: String,
	qualifies: bool,
	source_revision: int
) -> Dictionary:
	var gate := state.get("victory_gate", {}) as Dictionary
	authority.set_current_source_revision(source_revision)
	return authority.issue_qualification_proof(
		proof_id,
		str(state.get("match_instance_id", "")),
		str(state.get("genesis_fingerprint", "")),
		int(state.get("revision", 0)),
		source_revision,
		int(gate.get("macro_round_index", 0)),
		condition_id,
		qualifies
	)


func _issue_victory_boundary(
	authority,
	state: Dictionary,
	proof_id: String,
	boundary: Dictionary,
	revalidation_passed: bool,
	final_settlement_id: String,
	source_revision: int
) -> Dictionary:
	var gate := state.get("victory_gate", {}) as Dictionary
	authority.set_current_source_revision(source_revision)
	return authority.issue_boundary_proof(
		proof_id,
		str(state.get("match_instance_id", "")),
		str(state.get("genesis_fingerprint", "")),
		int(state.get("revision", 0)),
		source_revision,
		int(gate.get("macro_round_index", 0)),
		str(gate.get("pending_condition_id", "")),
		str(gate.get("pending_qualification_proof_id", "")),
		str(gate.get("pending_qualification_proof_fingerprint", "")),
		boundary,
		revalidation_passed,
		final_settlement_id
	)


func _submit_victory_qualification(
	state: Dictionary,
	intent: Dictionary,
	authority: TestVictoryAuthorityPort
) -> Dictionary:
	return SOLAR_VICTORY_CORE.submit_victory_qualification(
		state, intent, authority, authority.capability()
	)


func _revalidate_victory(
	state: Dictionary,
	intent: Dictionary,
	authority: TestVictoryAuthorityPort
) -> Dictionary:
	return SOLAR_VICTORY_CORE.revalidate_victory_at_boundary(
		state, intent, authority, authority.capability()
	)


func _victory_qualification_intent(
	state: Dictionary,
	intent_id: String,
	condition_id: String,
	proof: Dictionary
) -> Dictionary:
	return {
		"schema_version": SOLAR_VICTORY_CORE.SCHEMA_VERSION,
		"intent_id": intent_id,
		"intent_kind_id": SOLAR_VICTORY_CORE.INTENT_KIND_QUALIFICATION,
		"expected_revision": int(state.get("revision", 0)),
		"condition_id": condition_id,
		"proof_id": str(proof.get("proof_id", "")),
		"proof_fingerprint": str(proof.get("proof_fingerprint", "")),
	}


func _victory_revalidation_intent(
	state: Dictionary,
	intent_id: String,
	condition_id: String,
	proof: Dictionary
) -> Dictionary:
	return {
		"schema_version": SOLAR_VICTORY_CORE.SCHEMA_VERSION,
		"intent_id": intent_id,
		"intent_kind_id": SOLAR_VICTORY_CORE.INTENT_KIND_REVALIDATION,
		"expected_revision": int(state.get("revision", 0)),
		"condition_id": condition_id,
		"macro_round_index": int(
			(state.get("victory_gate", {}) as Dictionary).get(
				"macro_round_index", 0
			)
		),
		"proof_id": str(proof.get("proof_id", "")),
		"proof_fingerprint": str(proof.get("proof_fingerprint", "")),
	}


func _complete_victory_boundary() -> Dictionary:
	var boundary: Dictionary = {}
	for requirement_variant in SOLAR_VICTORY_CORE.BOUNDARY_REQUIREMENTS:
		boundary[str(requirement_variant)] = true
	return boundary


func _create_asset_batch_state(batch_id: String, opened_at_ms: int) -> Dictionary:
	return ASSET_BATCH_CORE.create_state(
		batch_id,
		[ROSTER[0], ROSTER[1]],
		[ROSTER[1], ROSTER[0]],
		_assets_by_player(3),
		{},
		opened_at_ms,
		1000
	)


func _contains_exact_key(value: Variant, key: String) -> bool:
	if value is Dictionary:
		if (value as Dictionary).has(key):
			return true
		for nested_variant in (value as Dictionary).values():
			if _contains_exact_key(nested_variant, key):
				return true
	elif value is Array:
		for nested_variant in value as Array:
			if _contains_exact_key(nested_variant, key):
				return true
	return false


func _contains_value(value: Variant, expected: String) -> bool:
	if value is String:
		return str(value) == expected
	if value is Dictionary:
		for nested_variant in (value as Dictionary).values():
			if _contains_value(nested_variant, expected):
				return true
	elif value is Array:
		for nested_variant in value as Array:
			if _contains_value(nested_variant, expected):
				return true
	return false


func _is_pure_data(value: Variant, depth: int = 0) -> bool:
	if depth > 64:
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return true
		TYPE_FLOAT:
			return is_finite(float(value))
		TYPE_ARRAY:
			for item_variant in value as Array:
				if not _is_pure_data(item_variant, depth + 1):
					return false
			return true
		TYPE_DICTIONARY:
			for key_variant in (value as Dictionary).keys():
				if not (key_variant is String):
					return false
				if not _is_pure_data(
					(value as Dictionary).get(key_variant), depth + 1
				):
					return false
			return true
		_:
			return false


func _same_json_contract(left: Variant, right: Variant) -> bool:
	var left_type := typeof(left)
	var right_type := typeof(right)
	if [TYPE_INT, TYPE_FLOAT].has(left_type) \
			and [TYPE_INT, TYPE_FLOAT].has(right_type):
		return float(left) == float(right)
	if left_type != right_type:
		return false
	if left is Dictionary:
		var left_dict := left as Dictionary
		var right_dict := right as Dictionary
		if not _same_string_set(left_dict.keys(), right_dict.keys()):
			return false
		for key_variant in left_dict.keys():
			if not _same_json_contract(
				left_dict.get(key_variant), right_dict.get(key_variant)
			):
				return false
		return true
	if left is Array:
		var left_array := left as Array
		var right_array := right as Array
		if left_array.size() != right_array.size():
			return false
		for index in left_array.size():
			if not _same_json_contract(left_array[index], right_array[index]):
				return false
		return true
	return left == right


func _same_string_set(left: Array, right: Array) -> bool:
	var left_strings: Array[String] = []
	var right_strings: Array[String] = []
	for value in left:
		left_strings.append(str(value))
	for value in right:
		right_strings.append(str(value))
	left_strings.sort()
	right_strings.sort()
	return left_strings == right_strings


func _same_string_array(left: Array, right: Array) -> bool:
	if left.size() != right.size():
		return false
	for index in left.size():
		if str(left[index]) != str(right[index]):
			return false
	return true


func _set_category(category: String) -> void:
	_active_category = category if ASSERTION_CATEGORIES.has(category) else "V07_CORE"


func _category_for_surface(surface: String) -> String:
	match surface:
		"AiObservationV1":
			return "V07_AI"
		"PlayerProjectionV1":
			return "V07_PLAYER"
		"SaveStateV1":
			return "V07_SAVE"
		_:
			return "V07_CORE"


func _assets_by_player(amount: int) -> Dictionary:
	return {
		ROSTER[0]: _color_map(amount, amount, amount, amount, amount, amount),
		ROSTER[1]: _color_map(amount, amount, amount, amount, amount, amount),
	}


func _zero_color_map() -> Dictionary:
	return _color_map(0, 0, 0, 0, 0, 0)


func _color_map(
	life: int,
	energy: int,
	industry: int,
	technology: int,
	commerce: int,
	shipping: int
) -> Dictionary:
	return {
		"life": life,
		"energy": energy,
		"industry": industry,
		"technology": technology,
		"commerce": commerce,
		"shipping": shipping,
	}


func _cost_map(
	life: int,
	energy: int,
	industry: int,
	technology: int,
	commerce: int,
	shipping: int,
	any: int
) -> Dictionary:
	var result := _color_map(
		life, energy, industry, technology, commerce, shipping
	)
	result["any"] = any
	return result


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	_category_totals[_active_category] = int(
		_category_totals.get(_active_category, 0)
	) + 1
	if not condition:
		_category_failures[_active_category] = int(
			_category_failures.get(_active_category, 0)
		) + 1
		_failures.append("%s | %s" % [_active_category, label])


func _finish() -> void:
	for category in ASSERTION_CATEGORIES:
		var total := int(_category_totals.get(category, 0))
		var delta := int(_category_failures.get(category, 0))
		print(
			"%s | ratio=%d/%d delta=%d"
			% [category, total - delta, total, delta]
		)
	if _failures.is_empty():
		print(
			"V07_THREE_WING_CONTRACT_AGGREGATE_TEST | passed=%d total=%d"
			% [_checks, _checks]
		)
		quit(0)
		return
	for failure in _failures:
		push_error("V07_THREE_WING_CONTRACT_AGGREGATE_TEST | %s" % failure)
	print(
		"V07_THREE_WING_CONTRACT_AGGREGATE_TEST | passed=%d total=%d"
		% [_checks - _failures.size(), _checks]
	)
	quit(1)
