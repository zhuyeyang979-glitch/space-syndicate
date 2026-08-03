class_name V07SolarVictoryCore
extends RefCounted

const SCHEMA_VERSION := 2
const SAVE_SECTION_VERSION := 5
const RULESET_ID := "v0.7.2"
const SAVE_SECTION_ID := "solar_facility_and_macro_victory"
const CHECKPOINT_SCHEMA_ID := "v072.solar_victory.checkpoint.v3"
const TRUSTED_AUTHORITY_ID := "v072.victory.trusted_authority.reference"
const TRUSTED_SOURCE_AUTHORITY_ID := "v072.victory.source_authority.reference"
const BALANCE_PROFILE_ID := "V072_STARTER_FREE_FAST"
const BALANCE_PROFILE_FINGERPRINT := (
	"b8f684ab92b06fa44671c38d041ff08b9c1ea7c2950b094705e19192f0a70f48"
)
const CORE_INTERFACE_ID := "v072.solar_victory.core_authority.v3"
const AI_INTERFACE_ID := "v072.solar_victory.ai_observation.v3"
const PLAYER_INTERFACE_ID := "v072.solar_victory.player_projection.v3"
const INTENT_INTERFACE_ID := "v072.solar_victory.intent.v3"
const RECEIPT_INTERFACE_ID := "v072.solar_victory.authoritative_receipt.v3"
const SAVE_INTERFACE_ID := "v072.solar_victory.save_state.v3"

const AUTHORITY_IDENTITY_METHOD := "victory_authority_identity_v1"
const CAPABILITY_IDENTITY_METHOD := "victory_capability_identity_v1"
const CURRENT_SOURCE_REVISION_METHOD := "victory_current_source_revision_v1"
const PROOF_LOOKUP_METHOD := "victory_lookup_issued_proof_v1"
const AUTHORITY_IDENTITY_FIELDS := [
	"authority_id",
	"source_authority_id",
	"issuer_instance_id",
]

const INTENT_KIND_SOLAR := "set_solar_phase"
const INTENT_KIND_QUALIFICATION := "submit_victory_qualification"
const INTENT_KIND_REVALIDATION := "revalidate_victory_at_macro_round_boundary"
const INTENT_KIND_IDS := [
	INTENT_KIND_SOLAR,
	INTENT_KIND_QUALIFICATION,
	INTENT_KIND_REVALIDATION,
]

const PROOF_KIND_QUALIFICATION := "victory_qualification"
const PROOF_KIND_BOUNDARY := "victory_boundary_revalidation"

const SOLAR_FACILITY_EFFICIENCY_STATE_ID := "V072SolarFacilityEfficiencyState"
const MACRO_ROUND_VICTORY_GATE_STATE_ID := "V072MacroRoundVictoryGateState"

const SUNLIT_MULTIPLIER := 2.0
const DARK_MULTIPLIER := 1.0
const SOLAR_SOURCE_ID := "core_sun_or_world_owner"

const WORK_RATE_CHANNELS := [
	"factory_production_rate",
	"market_demand_or_consumption_rate",
	"warehouse_ingress_throughput",
	"warehouse_egress_throughput",
]

const SOLAR_NON_EFFECTS := [
	"card_supply",
	"track_color",
	"track_card_kind_ratio",
	"card_price",
	"card_purchase_legality",
	"facility_hp",
	"facility_level",
	"facility_slots",
	"construction_price",
	"warehouse_capacity",
	"current_inventory",
	"monster_attack",
	"military_power",
	"asset_cap",
]

const BOUNDARY_REQUIREMENTS := [
	"submission_window_locked",
	"batch_complete",
	"asset_refresh_complete",
	"hand_maintenance_complete",
	"macro_round_complete",
	"every_player_led_once",
]

const SOLAR_FACILITY_EFFICIENCY_STATE_FIELDS := [
	"state_id",
	"schema_version",
	"ruleset_id",
	"source_revision",
	"source_core_fingerprint",
	"sunlit",
	"solar_phase_id",
	"work_rate_multiplier",
	"solar_source_id",
	"solar_source_revision",
	"work_rate_channels",
	"non_effects",
]

const MACRO_ROUND_VICTORY_GATE_STATE_FIELDS := [
	"state_id",
	"schema_version",
	"ruleset_id",
	"source_revision",
	"source_core_fingerprint",
	"macro_round_index",
	"pending",
	"pending_condition_id",
	"pending_trigger_intent_id",
	"pending_trigger_revision",
	"boundary_requirements",
	"final_settlement_committed",
	"final_settlement_id",
	"final_settlement_receipt_id",
	"final_settlement_count",
	"processed_intent_ids",
	"receipt_ledger",
]

const STATE_FIELDS := [
	"schema_version",
	"ruleset_id",
	"balance_profile_id",
	"balance_profile_fingerprint",
	"match_instance_id",
	"genesis_fingerprint",
	"genesis_solar_sunlit",
	"genesis_macro_round_index",
	"revision",
	"solar",
	"victory_gate",
	"processed_intent_ids",
	"receipt_ledger",
]

const SOLAR_FIELDS := [
	"sunlit",
	"work_rate_multiplier",
	"source_id",
	"source_revision",
]

const VICTORY_FIELDS := [
	"macro_round_index",
	"pending",
	"pending_condition_id",
	"pending_trigger_intent_id",
	"pending_trigger_revision",
	"pending_qualification_proof_id",
	"pending_qualification_proof_fingerprint",
	"pending_qualification_authority_id",
	"pending_qualification_source_authority_id",
	"pending_qualification_issuer_instance_id",
	"pending_qualification_source_revision",
	"final_settlement_committed",
	"final_settlement_id",
	"final_settlement_receipt_id",
	"final_settlement_count",
]

const SOLAR_INTENT_FIELDS := [
	"schema_version",
	"intent_id",
	"intent_kind_id",
	"expected_revision",
	"sunlit",
	"source_revision",
]

const QUALIFICATION_INTENT_FIELDS := [
	"schema_version",
	"intent_id",
	"intent_kind_id",
	"expected_revision",
	"condition_id",
	"proof_id",
	"proof_fingerprint",
]

const REVALIDATION_INTENT_FIELDS := [
	"schema_version",
	"intent_id",
	"intent_kind_id",
	"expected_revision",
	"condition_id",
	"macro_round_index",
	"proof_id",
	"proof_fingerprint",
]

const RECEIPT_FIELDS := [
	"schema_version",
	"ruleset_id",
	"receipt_id",
	"intent_id",
	"intent_kind_id",
	"intent_fingerprint",
	"intent_payload",
	"predecessor_receipt_fingerprint",
	"source_state_fingerprint",
	"accepted",
	"committed",
	"reason_code",
	"state_revision_before",
	"state_revision_after",
	"victory_pending",
	"final_settlement_committed",
	"final_settlement_id",
	"final_settlement_count",
	"condition_id",
	"proof_id",
	"proof_fingerprint",
	"proof_authority_id",
	"proof_source_authority_id",
	"proof_issuer_instance_id",
	"proof_source_revision",
	"result_state_fingerprint",
	"receipt_fingerprint",
]

const SAVE_STATE_FIELDS := [
	"schema_version",
	"section_id",
	"section_version",
	"ruleset_id",
	"source_state_fingerprint",
	"state",
	"save_fingerprint",
]

const CHECKPOINT_FIELDS := [
	"schema_version",
	"schema_id",
	"ruleset_id",
	"match_instance_id",
	"genesis_fingerprint",
	"source_revision",
	"source_state_fingerprint",
	"authority_state",
	"checkpoint_fingerprint",
]

const QUALIFICATION_PROOF_FIELDS := [
	"schema_version",
	"authority_id",
	"source_authority_id",
	"issuer_instance_id",
	"proof_id",
	"proof_kind_id",
	"match_instance_id",
	"genesis_fingerprint",
	"expected_core_revision",
	"source_revision",
	"macro_round_index",
	"condition_id",
	"qualifies",
	"proof_fingerprint",
]

const BOUNDARY_PROOF_FIELDS := [
	"schema_version",
	"authority_id",
	"source_authority_id",
	"issuer_instance_id",
	"proof_id",
	"proof_kind_id",
	"match_instance_id",
	"genesis_fingerprint",
	"expected_core_revision",
	"source_revision",
	"macro_round_index",
	"condition_id",
	"qualification_proof_id",
	"qualification_proof_fingerprint",
	"boundary",
	"revalidation_passed",
	"final_settlement_id",
	"proof_fingerprint",
]


static func interface_contract_v2() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"ruleset_id": RULESET_ID,
		"save_section_version": SAVE_SECTION_VERSION,
		"balance_profile_id": BALANCE_PROFILE_ID,
		"balance_profile_fingerprint": BALANCE_PROFILE_FINGERPRINT,
		"interfaces": {
			"core": CORE_INTERFACE_ID,
			"ai_observation": AI_INTERFACE_ID,
			"player_projection": PLAYER_INTERFACE_ID,
			"intent": INTENT_INTERFACE_ID,
			"authoritative_receipt": RECEIPT_INTERFACE_ID,
			"save_state": SAVE_INTERFACE_ID,
		},
		"solar_multiplier_application_count_per_channel": 1,
		"production_runtime_connected": false,
	}


static func create_state(
	sunlit: bool = false,
	macro_round_index: int = 1,
	match_instance_id: String = "match.reference"
) -> Dictionary:
	if macro_round_index < 1 or not _is_stable_id(match_instance_id):
		return {}
	var state := {
		"schema_version": SCHEMA_VERSION,
		"ruleset_id": RULESET_ID,
		"balance_profile_id": BALANCE_PROFILE_ID,
		"balance_profile_fingerprint": BALANCE_PROFILE_FINGERPRINT,
		"match_instance_id": match_instance_id,
		"genesis_fingerprint": "",
		"genesis_solar_sunlit": sunlit,
		"genesis_macro_round_index": macro_round_index,
		"revision": 0,
		"solar": {
			"sunlit": sunlit,
			"work_rate_multiplier": solar_multiplier(sunlit),
			"source_id": SOLAR_SOURCE_ID,
			"source_revision": 0,
		},
		"victory_gate": {
			"macro_round_index": macro_round_index,
			"pending": false,
			"pending_condition_id": "",
			"pending_trigger_intent_id": "",
			"pending_trigger_revision": -1,
			"pending_qualification_proof_id": "",
			"pending_qualification_proof_fingerprint": "",
			"pending_qualification_authority_id": "",
			"pending_qualification_source_authority_id": "",
			"pending_qualification_issuer_instance_id": "",
			"pending_qualification_source_revision": -1,
			"final_settlement_committed": false,
			"final_settlement_id": "",
			"final_settlement_receipt_id": "",
			"final_settlement_count": 0,
		},
		"processed_intent_ids": [],
		"receipt_ledger": {},
	}
	state["genesis_fingerprint"] = _genesis_fingerprint_for_state(state)
	return state if is_valid_state(state) else {}


static func solar_multiplier(sunlit: bool) -> float:
	return SUNLIT_MULTIPLIER if sunlit else DARK_MULTIPLIER


static func solar_facility_efficiency_state_v1(state: Dictionary) -> Dictionary:
	if not is_valid_state(state):
		return {}
	var solar := state.get("solar", {}) as Dictionary
	return {
		"state_id": SOLAR_FACILITY_EFFICIENCY_STATE_ID,
		"schema_version": SCHEMA_VERSION,
		"ruleset_id": RULESET_ID,
		"source_revision": int(state.get("revision", 0)),
		"source_core_fingerprint": state_fingerprint(state),
		"sunlit": bool(solar.get("sunlit", false)),
		"solar_phase_id": _solar_phase_id(state),
		"work_rate_multiplier": float(
			solar.get("work_rate_multiplier", DARK_MULTIPLIER)
		),
		"solar_source_id": str(solar.get("source_id", "")),
		"solar_source_revision": int(solar.get("source_revision", 0)),
		"work_rate_channels": WORK_RATE_CHANNELS.duplicate(),
		"non_effects": SOLAR_NON_EFFECTS.duplicate(),
	}


static func macro_round_victory_gate_state_v1(state: Dictionary) -> Dictionary:
	if not is_valid_state(state):
		return {}
	var gate := state.get("victory_gate", {}) as Dictionary
	return {
		"state_id": MACRO_ROUND_VICTORY_GATE_STATE_ID,
		"schema_version": SCHEMA_VERSION,
		"ruleset_id": RULESET_ID,
		"source_revision": int(state.get("revision", 0)),
		"source_core_fingerprint": state_fingerprint(state),
		"macro_round_index": int(gate.get("macro_round_index", 0)),
		"pending": bool(gate.get("pending", false)),
		"pending_condition_id": str(gate.get("pending_condition_id", "")),
		"pending_trigger_intent_id": str(
			gate.get("pending_trigger_intent_id", "")
		),
		"pending_trigger_revision": int(
			gate.get("pending_trigger_revision", -1)
		),
		"boundary_requirements": BOUNDARY_REQUIREMENTS.duplicate(),
		"final_settlement_committed": bool(
			gate.get("final_settlement_committed", false)
		),
		"final_settlement_id": str(gate.get("final_settlement_id", "")),
		"final_settlement_receipt_id": str(
			gate.get("final_settlement_receipt_id", "")
		),
		"final_settlement_count": int(gate.get("final_settlement_count", 0)),
		"processed_intent_ids": (
			state.get("processed_intent_ids", []) as Array
		).duplicate(true),
		"receipt_ledger": (
			state.get("receipt_ledger", {}) as Dictionary
		).duplicate(true),
	}


static func evaluate_facility_work_rates(
	state: Dictionary,
	base_work_rates: Dictionary,
	protected_card_facts: Dictionary
) -> Dictionary:
	if not is_valid_state(state):
		return {}
	if base_work_rates.is_empty() or not _is_pure_data(protected_card_facts):
		return {}
	var effective_rates: Dictionary = {}
	var multiplier := float((state.get("solar", {}) as Dictionary).get(
		"work_rate_multiplier", DARK_MULTIPLIER
	))
	for channel_variant in base_work_rates.keys():
		if not (channel_variant is String):
			return {}
		var channel_id := str(channel_variant)
		if not WORK_RATE_CHANNELS.has(channel_id):
			return {}
		var base_rate: Variant = base_work_rates.get(channel_id)
		if not _is_nonnegative_finite_number(base_rate):
			return {}
		effective_rates[channel_id] = float(base_rate) * multiplier
	return {
		"schema_version": SCHEMA_VERSION,
		"ruleset_id": RULESET_ID,
		"solar_phase_id": _solar_phase_id(state),
		"work_rate_multiplier": multiplier,
		"facility_work_rates": effective_rates,
		"protected_card_facts": protected_card_facts.duplicate(true),
	}


static func apply_solar_intent(state: Dictionary, intent: Dictionary) -> Dictionary:
	if not is_valid_state(state):
		return {}
	if str(intent.get("intent_kind_id", "")) != INTENT_KIND_SOLAR:
		return _reject(state, intent, "solar_intent_invalid")
	var existing := _existing_intent_outcome(state, intent)
	if bool(existing.get("handled", false)):
		return existing.get("outcome", {}) as Dictionary
	if not _valid_solar_intent(intent):
		return _reject(state, intent, "solar_intent_invalid")
	if int(intent.get("expected_revision", -1)) != int(state.get("revision", -1)):
		return _reject(state, intent, "state_revision_mismatch")
	if bool((state.get("victory_gate", {}) as Dictionary).get(
		"final_settlement_committed", false
	)):
		return _reject(state, intent, "final_settlement_already_committed")
	var solar := state.get("solar", {}) as Dictionary
	if int(intent.get("source_revision", -1)) <= int(solar.get("source_revision", -1)):
		return _reject(state, intent, "solar_source_revision_not_advanced")

	var next_state := state.duplicate(true)
	var next_solar := next_state.get("solar", {}) as Dictionary
	var next_sunlit := bool(intent.get("sunlit", false))
	next_solar["sunlit"] = next_sunlit
	next_solar["work_rate_multiplier"] = solar_multiplier(next_sunlit)
	next_solar["source_revision"] = int(intent.get("source_revision", 0))
	next_state["revision"] = int(state.get("revision", 0)) + 1
	var receipt := _make_receipt(
		state,
		next_state,
		intent,
		true,
		true,
		"solar_state_committed",
		{}
	)
	_record_receipt(next_state, str(intent.get("intent_id", "")), receipt)
	return _outcome(next_state, receipt) if is_valid_state(next_state) else {}


static func submit_victory_qualification(
	state: Dictionary,
	intent: Dictionary,
	authority_port: Variant = null,
	authority_capability: Variant = null
) -> Dictionary:
	if not is_valid_state(state):
		return {}
	if str(intent.get("intent_kind_id", "")) != INTENT_KIND_QUALIFICATION:
		return _reject(state, intent, "victory_qualification_intent_invalid")
	var port_context := _authority_port_context(
		authority_port,
		authority_capability
	)
	if not bool(port_context.get("valid", false)):
		return _reject(
			state,
			intent,
			str(port_context.get("reason_code", "trusted_victory_authority_required"))
		)
	var existing := _existing_intent_outcome(state, intent)
	if bool(existing.get("handled", false)):
		var existing_outcome := existing.get("outcome", {}) as Dictionary
		var existing_receipt := existing_outcome.get("receipt", {}) as Dictionary
		if bool(existing_receipt.get("committed", false)) \
				and not _receipt_issuer_matches_port(existing_receipt, port_context):
			return _reject(state, intent, "qualification_proof_issuer_mismatch")
		return existing_outcome
	if not _valid_qualification_intent(intent):
		return _reject(state, intent, "victory_qualification_intent_invalid")
	if int(intent.get("expected_revision", -1)) != int(state.get("revision", -1)):
		return _reject(state, intent, "state_revision_mismatch")
	var gate := state.get("victory_gate", {}) as Dictionary
	if bool(gate.get("final_settlement_committed", false)):
		return _reject(state, intent, "final_settlement_already_committed")
	var proof_variant: Variant = authority_port.call(
		PROOF_LOOKUP_METHOD,
		str(intent.get("proof_id", "")),
		str(intent.get("proof_fingerprint", "")),
		authority_capability
	)
	var proof := proof_variant as Dictionary if proof_variant is Dictionary else {}
	if proof.is_empty():
		return _reject(state, intent, "qualification_proof_unbound_or_forged")
	var proof_error := _qualification_proof_binding_error(
		proof,
		state,
		intent,
		port_context
	)
	if not proof_error.is_empty():
		return _reject(state, intent, proof_error, proof)

	var next_state := state.duplicate(true)
	var next_gate := next_state.get("victory_gate", {}) as Dictionary
	var qualifies := bool(proof.get("qualifies", false))
	var reason_code := "victory_qualification_not_met"
	if qualifies and not bool(next_gate.get("pending", false)):
		next_gate["pending"] = true
		next_gate["pending_condition_id"] = str(intent.get("condition_id", ""))
		next_gate["pending_trigger_intent_id"] = str(intent.get("intent_id", ""))
		next_gate["pending_trigger_revision"] = int(state.get("revision", 0)) + 1
		next_gate["pending_qualification_proof_id"] = str(proof.get("proof_id", ""))
		next_gate["pending_qualification_proof_fingerprint"] = str(
			proof.get("proof_fingerprint", "")
		)
		next_gate["pending_qualification_authority_id"] = str(
			proof.get("authority_id", "")
		)
		next_gate["pending_qualification_source_authority_id"] = str(
			proof.get("source_authority_id", "")
		)
		next_gate["pending_qualification_issuer_instance_id"] = str(
			proof.get("issuer_instance_id", "")
		)
		next_gate["pending_qualification_source_revision"] = int(
			proof.get("source_revision", -1)
		)
		reason_code = "victory_pending_until_macro_round_boundary"
	elif qualifies:
		reason_code = "existing_victory_pending_preserved"
	next_state["revision"] = int(state.get("revision", 0)) + 1
	var receipt := _make_receipt(
		state,
		next_state,
		intent,
		true,
		true,
		reason_code,
		proof
	)
	_record_receipt(next_state, str(intent.get("intent_id", "")), receipt)
	return _outcome(next_state, receipt) if is_valid_state(next_state) else {}


static func revalidate_victory_at_boundary(
	state: Dictionary,
	intent: Dictionary,
	authority_port: Variant = null,
	authority_capability: Variant = null
) -> Dictionary:
	if not is_valid_state(state):
		return {}
	if str(intent.get("intent_kind_id", "")) != INTENT_KIND_REVALIDATION:
		return _reject(state, intent, "victory_revalidation_intent_invalid")
	var port_context := _authority_port_context(
		authority_port,
		authority_capability
	)
	if not bool(port_context.get("valid", false)):
		return _reject(
			state,
			intent,
			str(port_context.get("reason_code", "trusted_victory_authority_required"))
		)
	var existing := _existing_intent_outcome(state, intent)
	if bool(existing.get("handled", false)):
		var existing_outcome := existing.get("outcome", {}) as Dictionary
		var existing_receipt := existing_outcome.get("receipt", {}) as Dictionary
		if bool(existing_receipt.get("committed", false)) \
				and not _receipt_issuer_matches_port(existing_receipt, port_context):
			return _reject(state, intent, "boundary_proof_issuer_mismatch")
		return existing_outcome
	if not _valid_revalidation_intent(intent):
		return _reject(state, intent, "victory_revalidation_intent_invalid")
	if int(intent.get("expected_revision", -1)) != int(state.get("revision", -1)):
		return _reject(state, intent, "state_revision_mismatch")

	var gate := state.get("victory_gate", {}) as Dictionary
	if bool(gate.get("final_settlement_committed", false)):
		return _reject(state, intent, "final_settlement_already_committed")
	if not bool(gate.get("pending", false)):
		return _reject(state, intent, "victory_not_pending")
	if str(intent.get("condition_id", "")) != str(gate.get("pending_condition_id", "")):
		return _reject(state, intent, "pending_condition_mismatch")
	if int(intent.get("macro_round_index", -1)) != int(gate.get("macro_round_index", -1)):
		return _reject(state, intent, "macro_round_index_mismatch")
	var proof_variant: Variant = authority_port.call(
		PROOF_LOOKUP_METHOD,
		str(intent.get("proof_id", "")),
		str(intent.get("proof_fingerprint", "")),
		authority_capability
	)
	var proof := proof_variant as Dictionary if proof_variant is Dictionary else {}
	if proof.is_empty():
		return _reject(state, intent, "boundary_proof_unbound_or_forged")
	var proof_error := _boundary_proof_binding_error(
		proof,
		state,
		intent,
		port_context
	)
	if not proof_error.is_empty():
		return _reject(state, intent, proof_error, proof)
	if not _all_boundary_requirements_met(proof.get("boundary", {}) as Dictionary):
		return _reject(state, intent, "macro_round_boundary_incomplete", proof)

	var next_state := state.duplicate(true)
	var next_gate := next_state.get("victory_gate", {}) as Dictionary
	var revalidation_passed := bool(proof.get("revalidation_passed", false))
	next_gate["pending"] = false
	next_gate["pending_condition_id"] = ""
	next_gate["pending_trigger_intent_id"] = ""
	next_gate["pending_trigger_revision"] = -1
	next_gate["pending_qualification_proof_id"] = ""
	next_gate["pending_qualification_proof_fingerprint"] = ""
	next_gate["pending_qualification_authority_id"] = ""
	next_gate["pending_qualification_source_authority_id"] = ""
	next_gate["pending_qualification_issuer_instance_id"] = ""
	next_gate["pending_qualification_source_revision"] = -1
	var reason_code := "victory_revalidation_failed_pending_cleared"
	if revalidation_passed:
		next_gate["final_settlement_committed"] = true
		next_gate["final_settlement_id"] = str(proof.get("final_settlement_id", ""))
		next_gate["final_settlement_receipt_id"] = _receipt_id_for_intent(
			str(intent.get("intent_id", "")),
			_intent_fingerprint(intent)
		)
		next_gate["final_settlement_count"] = 1
		reason_code = "final_settlement_committed_exact_once"
	next_state["revision"] = int(state.get("revision", 0)) + 1
	var receipt := _make_receipt(
		state,
		next_state,
		intent,
		true,
		true,
		reason_code,
		proof
	)
	_record_receipt(next_state, str(intent.get("intent_id", "")), receipt)
	return _outcome(next_state, receipt) if is_valid_state(next_state) else {}


static func checkpoint(state: Dictionary) -> Dictionary:
	if not is_valid_state(state):
		return {}
	var checkpoint_state := {
		"schema_version": SCHEMA_VERSION,
		"schema_id": CHECKPOINT_SCHEMA_ID,
		"ruleset_id": RULESET_ID,
		"match_instance_id": str(state.get("match_instance_id", "")),
		"genesis_fingerprint": str(state.get("genesis_fingerprint", "")),
		"source_revision": int(state.get("revision", 0)),
		"source_state_fingerprint": state_fingerprint(state),
		"authority_state": state.duplicate(true),
	}
	checkpoint_state["checkpoint_fingerprint"] = _data_fingerprint(checkpoint_state)
	return checkpoint_state


static func rollback_detailed(
	current_state: Dictionary,
	checkpoint_state: Dictionary
) -> Dictionary:
	if not is_valid_state(current_state):
		return {"rolled_back": false, "reason_code": "current_state_invalid", "state": {}}
	var checkpoint_error := _checkpoint_error(checkpoint_state)
	if not checkpoint_error.is_empty():
		return {
			"rolled_back": false,
			"reason_code": checkpoint_error,
			"state": current_state.duplicate(true),
		}
	var candidate := checkpoint_state.get("authority_state", {}) as Dictionary
	if str(candidate.get("match_instance_id", "")) \
			!= str(current_state.get("match_instance_id", "")) \
			or str(candidate.get("genesis_fingerprint", "")) \
				!= str(current_state.get("genesis_fingerprint", "")):
		return {
			"rolled_back": false,
			"reason_code": "checkpoint_lineage_mismatch",
			"state": current_state.duplicate(true),
		}
	if int(candidate.get("revision", -1)) > int(current_state.get("revision", -1)):
		return {
			"rolled_back": false,
			"reason_code": "checkpoint_from_future",
			"state": current_state.duplicate(true),
		}
	var current_gate := current_state.get("victory_gate", {}) as Dictionary
	if bool(current_gate.get("final_settlement_committed", false)) \
			and state_fingerprint(candidate) != state_fingerprint(current_state):
		return {
			"rolled_back": false,
			"reason_code": "rollback_crosses_final_settlement",
			"state": current_state.duplicate(true),
		}
	if not _receipt_lineage_is_prefix(candidate, current_state):
		return {
			"rolled_back": false,
			"reason_code": "checkpoint_not_current_lineage",
			"state": current_state.duplicate(true),
		}
	if int(candidate.get("revision", -1)) == int(current_state.get("revision", -1)) \
			and state_fingerprint(candidate) != state_fingerprint(current_state):
		return {
			"rolled_back": false,
			"reason_code": "checkpoint_divergent_same_revision",
			"state": current_state.duplicate(true),
		}
	return {
		"rolled_back": true,
		"reason_code": "checkpoint_restored",
		"state": candidate.duplicate(true),
	}


static func rollback(current_state: Dictionary, checkpoint_state: Dictionary) -> Dictionary:
	return rollback_detailed(current_state, checkpoint_state).get("state", {}) as Dictionary


static func to_save_state(state: Dictionary) -> Dictionary:
	if not is_valid_state(state):
		return {}
	var save_state := {
		"schema_version": SCHEMA_VERSION,
		"section_id": SAVE_SECTION_ID,
		"section_version": SAVE_SECTION_VERSION,
		"ruleset_id": RULESET_ID,
		"source_state_fingerprint": state_fingerprint(state),
		"state": _encode_wire_int64(state),
	}
	save_state["save_fingerprint"] = _data_fingerprint(save_state)
	return save_state


static func from_save_state(save_state: Dictionary) -> Dictionary:
	if not _has_exact_keys(save_state, SAVE_STATE_FIELDS):
		return {}
	if not _wire_integer_equals(save_state.get("schema_version"), SCHEMA_VERSION):
		return {}
	if str(save_state.get("section_id", "")) != SAVE_SECTION_ID:
		return {}
	if not _wire_integer_equals(
		save_state.get("section_version"), SAVE_SECTION_VERSION
	):
		return {}
	if str(save_state.get("ruleset_id", "")) != RULESET_ID:
		return {}
	var normalized_save := save_state.duplicate(true)
	normalized_save["schema_version"] = SCHEMA_VERSION
	normalized_save["section_version"] = SAVE_SECTION_VERSION
	if not _is_fingerprint(save_state.get("source_state_fingerprint")) \
			or not _is_fingerprint(save_state.get("save_fingerprint")) \
			or str(save_state.get("save_fingerprint", "")) \
				!= _data_fingerprint(normalized_save, "save_fingerprint"):
		return {}
	var decoded := _decode_wire_int64(save_state.get("state"))
	if not bool(decoded.get("valid", false)):
		return {}
	if not (decoded.get("value") is Dictionary):
		return {}
	var state := decoded.get("value", {}) as Dictionary
	if not is_valid_state(state) \
			or state_fingerprint(state) \
				!= str(save_state.get("source_state_fingerprint", "")):
		return {}
	return state.duplicate(true)


static func ai_observation(state: Dictionary) -> Dictionary:
	if not is_valid_state(state):
		return {}
	var gate := state.get("victory_gate", {}) as Dictionary
	return {
		"schema_version": SCHEMA_VERSION,
		"ruleset_id": RULESET_ID,
		"observation_id": AI_INTERFACE_ID,
		"solar_phase_id": _solar_phase_id(state),
		"facility_work_rate_multiplier": float(
			(state.get("solar", {}) as Dictionary).get(
				"work_rate_multiplier", DARK_MULTIPLIER
			)
		),
		"victory_pending": bool(gate.get("pending", false)),
		"macro_round_index": int(gate.get("macro_round_index", 0)),
		"final_settlement_committed": bool(
			gate.get("final_settlement_committed", false)
		),
	}


static func player_projection(state: Dictionary) -> Dictionary:
	if not is_valid_state(state):
		return {}
	var gate := state.get("victory_gate", {}) as Dictionary
	return {
		"schema_version": SCHEMA_VERSION,
		"ruleset_id": RULESET_ID,
		"projection_id": PLAYER_INTERFACE_ID,
		"visibility_scope_id": "public",
		"solar_phase_id": _solar_phase_id(state),
		"facility_work_rate_multiplier": float(
			(state.get("solar", {}) as Dictionary).get(
				"work_rate_multiplier", DARK_MULTIPLIER
			)
		),
		"victory_pending": bool(gate.get("pending", false)),
		"macro_round_index": int(gate.get("macro_round_index", 0)),
		"final_settlement_committed": bool(
			gate.get("final_settlement_committed", false)
		),
	}


static func is_valid_state(state: Dictionary) -> bool:
	if not _has_exact_keys(state, STATE_FIELDS):
		return false
	if not (state.get("schema_version") is int) \
			or int(state.get("schema_version", -1)) != SCHEMA_VERSION:
		return false
	if str(state.get("ruleset_id", "")) != RULESET_ID:
		return false
	if str(state.get("balance_profile_id", "")) != BALANCE_PROFILE_ID \
			or str(state.get("balance_profile_fingerprint", "")) \
				!= BALANCE_PROFILE_FINGERPRINT:
		return false
	if not _is_stable_id(state.get("match_instance_id")) \
			or not _is_fingerprint(state.get("genesis_fingerprint")):
		return false
	if not (state.get("genesis_solar_sunlit") is bool) \
			or not (state.get("genesis_macro_round_index") is int) \
			or int(state.get("genesis_macro_round_index", 0)) < 1:
		return false
	if not (state.get("revision") is int) or int(state.get("revision", -1)) < 0:
		return false
	if not (state.get("solar") is Dictionary):
		return false
	if not (state.get("victory_gate") is Dictionary):
		return false
	if not (state.get("processed_intent_ids") is Array):
		return false
	if not (state.get("receipt_ledger") is Dictionary):
		return false
	if not _valid_solar_state(state.get("solar", {}) as Dictionary):
		return false
	if not _valid_victory_state(state.get("victory_gate", {}) as Dictionary):
		return false
	var processed_ids := state.get("processed_intent_ids", []) as Array
	var ledger := state.get("receipt_ledger", {}) as Dictionary
	if processed_ids.size() != ledger.size() \
			or processed_ids.size() != int(state.get("revision", -1)):
		return false
	var seen: Dictionary = {}
	for index in range(processed_ids.size()):
		var intent_id_variant: Variant = processed_ids[index]
		if not (intent_id_variant is String):
			return false
		var intent_id := str(intent_id_variant)
		if not _is_stable_id(intent_id) or seen.has(intent_id) or not ledger.has(intent_id):
			return false
		if not (ledger.get(intent_id) is Dictionary):
			return false
		seen[intent_id] = true
	if str(state.get("genesis_fingerprint", "")) \
			!= _genesis_fingerprint_for_state(state):
		return false
	if not _journal_matches_victory_gate(state):
		return false
	return _is_pure_data(state)


static func state_fingerprint(state: Dictionary) -> String:
	if not is_valid_state(state):
		return ""
	return JSON.stringify(_canonicalize(state)).sha256_text()


static func _valid_solar_state(solar: Dictionary) -> bool:
	if not _has_exact_keys(solar, SOLAR_FIELDS):
		return false
	if not (solar.get("sunlit") is bool):
		return false
	if not _is_nonnegative_finite_number(solar.get("work_rate_multiplier")):
		return false
	if not is_equal_approx(
		float(solar.get("work_rate_multiplier", 0.0)),
		solar_multiplier(bool(solar.get("sunlit", false)))
	):
		return false
	return (
		str(solar.get("source_id", "")) == SOLAR_SOURCE_ID
		and solar.get("source_revision") is int
		and int(solar.get("source_revision", -1)) >= 0
	)


static func _valid_victory_state(gate: Dictionary) -> bool:
	if not _has_exact_keys(gate, VICTORY_FIELDS):
		return false
	if not (gate.get("macro_round_index") is int):
		return false
	if int(gate.get("macro_round_index", 0)) < 1:
		return false
	if not (gate.get("pending") is bool):
		return false
	if not (gate.get("final_settlement_committed") is bool):
		return false
	if not (gate.get("final_settlement_count") is int):
		return false
	if not (gate.get("pending_trigger_revision") is int) \
			or not (gate.get("pending_qualification_source_revision") is int):
		return false
	var pending := bool(gate.get("pending", false))
	if pending:
		if not _is_stable_id(gate.get("pending_condition_id")):
			return false
		if not _is_stable_id(gate.get("pending_trigger_intent_id")):
			return false
		if int(gate.get("pending_trigger_revision", -1)) < 1:
			return false
		if not _is_stable_id(gate.get("pending_qualification_proof_id")) \
				or not _is_fingerprint(
					gate.get("pending_qualification_proof_fingerprint")
				) \
				or str(gate.get("pending_qualification_authority_id", "")) \
					!= TRUSTED_AUTHORITY_ID \
				or str(gate.get("pending_qualification_source_authority_id", "")) \
					!= TRUSTED_SOURCE_AUTHORITY_ID \
				or not _is_stable_id(
					gate.get("pending_qualification_issuer_instance_id")
				) \
				or not (gate.get("pending_qualification_source_revision") is int) \
				or int(gate.get("pending_qualification_source_revision", -1)) < 0:
			return false
	else:
		if not str(gate.get("pending_condition_id", "")).is_empty():
			return false
		if not str(gate.get("pending_trigger_intent_id", "")).is_empty():
			return false
		if int(gate.get("pending_trigger_revision", -1)) != -1:
			return false
		if not str(gate.get("pending_qualification_proof_id", "")).is_empty() \
				or not str(gate.get(
					"pending_qualification_proof_fingerprint", ""
				)).is_empty() \
				or not str(gate.get(
					"pending_qualification_authority_id", ""
				)).is_empty() \
				or not str(gate.get(
					"pending_qualification_source_authority_id", ""
				)).is_empty() \
				or not str(gate.get(
					"pending_qualification_issuer_instance_id", ""
				)).is_empty() \
				or int(gate.get("pending_qualification_source_revision", -2)) != -1:
			return false
	var settled := bool(gate.get("final_settlement_committed", false))
	if settled:
		return (
			int(gate.get("final_settlement_count", 0)) == 1
			and _is_stable_id(gate.get("final_settlement_id"))
			and _is_stable_id(gate.get("final_settlement_receipt_id"))
			and not pending
		)
	return (
		int(gate.get("final_settlement_count", -1)) == 0
		and str(gate.get("final_settlement_id", "")).is_empty()
		and str(gate.get("final_settlement_receipt_id", "")).is_empty()
	)


static func _valid_solar_intent(intent: Dictionary) -> bool:
	return (
		_has_exact_keys(intent, SOLAR_INTENT_FIELDS)
		and intent.get("schema_version") is int
		and int(intent.get("schema_version", -1)) == SCHEMA_VERSION
		and str(intent.get("intent_kind_id", "")) == INTENT_KIND_SOLAR
		and _valid_intent_identity(intent)
		and intent.get("sunlit") is bool
		and intent.get("source_revision") is int
		and int(intent.get("source_revision", -1)) >= 0
	)


static func _valid_qualification_intent(intent: Dictionary) -> bool:
	return (
		_has_exact_keys(intent, QUALIFICATION_INTENT_FIELDS)
		and intent.get("schema_version") is int
		and int(intent.get("schema_version", -1)) == SCHEMA_VERSION
		and str(intent.get("intent_kind_id", "")) == INTENT_KIND_QUALIFICATION
		and _valid_intent_identity(intent)
		and _is_stable_id(intent.get("condition_id"))
		and _is_stable_id(intent.get("proof_id"))
		and _is_fingerprint(intent.get("proof_fingerprint"))
	)


static func _valid_revalidation_intent(intent: Dictionary) -> bool:
	if not _has_exact_keys(intent, REVALIDATION_INTENT_FIELDS):
		return false
	if not (intent.get("schema_version") is int) \
			or int(intent.get("schema_version", -1)) != SCHEMA_VERSION:
		return false
	if str(intent.get("intent_kind_id", "")) != INTENT_KIND_REVALIDATION:
		return false
	if not _valid_intent_identity(intent):
		return false
	if not _is_stable_id(intent.get("condition_id")):
		return false
	if not (intent.get("macro_round_index") is int):
		return false
	if int(intent.get("macro_round_index", 0)) < 1:
		return false
	if not _is_stable_id(intent.get("proof_id")):
		return false
	return _is_fingerprint(intent.get("proof_fingerprint"))


static func _valid_intent_identity(intent: Dictionary) -> bool:
	return (
		_is_stable_id(intent.get("intent_id"))
		and intent.get("expected_revision") is int
		and int(intent.get("expected_revision", -1)) >= 0
	)


static func _valid_boundary(boundary: Dictionary) -> bool:
	if not _has_exact_keys(boundary, BOUNDARY_REQUIREMENTS):
		return false
	for field_variant in BOUNDARY_REQUIREMENTS:
		if not (boundary.get(str(field_variant)) is bool):
			return false
	return true


static func _all_boundary_requirements_met(boundary: Dictionary) -> bool:
	if not _valid_boundary(boundary):
		return false
	for field_variant in BOUNDARY_REQUIREMENTS:
		if not bool(boundary.get(str(field_variant), false)):
			return false
	return true


static func _authority_port_context(
	authority_port: Variant,
	authority_capability: Variant
) -> Dictionary:
	if not (authority_port is RefCounted):
		return {"valid": false, "reason_code": "trusted_victory_authority_required"}
	if not (authority_capability is RefCounted):
		return {"valid": false, "reason_code": "trusted_victory_capability_required"}
	for method_name in [
		AUTHORITY_IDENTITY_METHOD,
		CAPABILITY_IDENTITY_METHOD,
		CURRENT_SOURCE_REVISION_METHOD,
		PROOF_LOOKUP_METHOD,
	]:
		if not authority_port.has_method(method_name):
			return {"valid": false, "reason_code": "trusted_victory_authority_required"}
	var identity_variant: Variant = authority_port.call(AUTHORITY_IDENTITY_METHOD)
	if not (identity_variant is Dictionary):
		return {
			"valid": false,
			"reason_code": "trusted_victory_authority_identity_invalid",
		}
	var identity := identity_variant as Dictionary
	if not _is_pure_data(identity) \
			or not _has_exact_keys(identity, AUTHORITY_IDENTITY_FIELDS) \
			or str(identity.get("authority_id", "")) != TRUSTED_AUTHORITY_ID \
			or str(identity.get("source_authority_id", "")) \
				!= TRUSTED_SOURCE_AUTHORITY_ID \
			or not _is_stable_id(identity.get("issuer_instance_id")):
		return {
			"valid": false,
			"reason_code": "trusted_victory_authority_identity_invalid",
		}
	var provisioned_capability: Variant = authority_port.call(
		CAPABILITY_IDENTITY_METHOD
	)
	if not (provisioned_capability is RefCounted) \
			or provisioned_capability != authority_capability:
		return {"valid": false, "reason_code": "trusted_victory_capability_required"}
	var source_revision: Variant = authority_port.call(
		CURRENT_SOURCE_REVISION_METHOD,
		authority_capability
	)
	if not _is_nonnegative_integer(source_revision):
		return {
			"valid": false,
			"reason_code": "trusted_victory_source_revision_invalid",
		}
	return {
		"valid": true,
		"reason_code": "trusted_victory_authority_bound",
		"authority_id": identity.get("authority_id"),
		"source_authority_id": identity.get("source_authority_id"),
		"issuer_instance_id": identity.get("issuer_instance_id"),
		"current_source_revision": source_revision,
	}


static func _receipt_issuer_matches_port(
	receipt: Dictionary,
	port_context: Dictionary
) -> bool:
	return (
		str(receipt.get("proof_authority_id", ""))
			== str(port_context.get("authority_id", ""))
		and str(receipt.get("proof_source_authority_id", ""))
			== str(port_context.get("source_authority_id", ""))
		and str(receipt.get("proof_issuer_instance_id", ""))
			== str(port_context.get("issuer_instance_id", ""))
	)


static func _valid_qualification_proof_shape(proof: Dictionary) -> bool:
	if not _is_pure_data(proof) \
			or not _has_exact_keys(proof, QUALIFICATION_PROOF_FIELDS):
		return false
	if not (proof.get("schema_version") is int) \
			or int(proof.get("schema_version", -1)) != SCHEMA_VERSION \
			or str(proof.get("authority_id", "")) != TRUSTED_AUTHORITY_ID \
			or str(proof.get("source_authority_id", "")) \
				!= TRUSTED_SOURCE_AUTHORITY_ID \
			or not _is_stable_id(proof.get("issuer_instance_id")) \
			or not _is_stable_id(proof.get("proof_id")) \
			or str(proof.get("proof_kind_id", "")) != PROOF_KIND_QUALIFICATION \
			or not _is_stable_id(proof.get("match_instance_id")) \
			or not _is_fingerprint(proof.get("genesis_fingerprint")) \
			or not _is_nonnegative_integer(proof.get("expected_core_revision")) \
			or not _is_nonnegative_integer(proof.get("source_revision")) \
			or not _is_positive_integer(proof.get("macro_round_index")) \
			or not _is_stable_id(proof.get("condition_id")) \
			or not (proof.get("qualifies") is bool):
		return false
	return _is_fingerprint(proof.get("proof_fingerprint")) \
		and str(proof.get("proof_fingerprint", "")) \
			== _data_fingerprint(proof, "proof_fingerprint")


static func _valid_boundary_proof_shape(proof: Dictionary) -> bool:
	if not _is_pure_data(proof) or not _has_exact_keys(proof, BOUNDARY_PROOF_FIELDS):
		return false
	if not (proof.get("schema_version") is int) \
			or int(proof.get("schema_version", -1)) != SCHEMA_VERSION \
			or str(proof.get("authority_id", "")) != TRUSTED_AUTHORITY_ID \
			or str(proof.get("source_authority_id", "")) \
				!= TRUSTED_SOURCE_AUTHORITY_ID \
			or not _is_stable_id(proof.get("issuer_instance_id")) \
			or not _is_stable_id(proof.get("proof_id")) \
			or str(proof.get("proof_kind_id", "")) != PROOF_KIND_BOUNDARY \
			or not _is_stable_id(proof.get("match_instance_id")) \
			or not _is_fingerprint(proof.get("genesis_fingerprint")) \
			or not _is_nonnegative_integer(proof.get("expected_core_revision")) \
			or not _is_nonnegative_integer(proof.get("source_revision")) \
			or not _is_positive_integer(proof.get("macro_round_index")) \
			or not _is_stable_id(proof.get("condition_id")) \
			or not _is_stable_id(proof.get("qualification_proof_id")) \
			or not _is_fingerprint(proof.get("qualification_proof_fingerprint")) \
			or not (proof.get("boundary") is Dictionary) \
			or not _valid_boundary(proof.get("boundary", {}) as Dictionary) \
			or not (proof.get("revalidation_passed") is bool):
		return false
	var settlement_id := str(proof.get("final_settlement_id", ""))
	if bool(proof.get("revalidation_passed", false)):
		if not _is_stable_id(settlement_id):
			return false
	elif not settlement_id.is_empty():
		return false
	return _is_fingerprint(proof.get("proof_fingerprint")) \
		and str(proof.get("proof_fingerprint", "")) \
			== _data_fingerprint(proof, "proof_fingerprint")


static func _qualification_proof_binding_error(
	proof: Dictionary,
	state: Dictionary,
	intent: Dictionary,
	port_context: Dictionary
) -> String:
	if not _valid_qualification_proof_shape(proof):
		return "qualification_proof_invalid"
	if str(proof.get("proof_id", "")) != str(intent.get("proof_id", "")) \
			or str(proof.get("proof_fingerprint", "")) \
				!= str(intent.get("proof_fingerprint", "")):
		return "qualification_proof_identity_mismatch"
	if str(proof.get("authority_id", "")) \
			!= str(port_context.get("authority_id", "")) \
			or str(proof.get("source_authority_id", "")) \
				!= str(port_context.get("source_authority_id", "")) \
			or str(proof.get("issuer_instance_id", "")) \
				!= str(port_context.get("issuer_instance_id", "")):
		return "qualification_proof_issuer_mismatch"
	if str(proof.get("match_instance_id", "")) \
			!= str(state.get("match_instance_id", "")) \
			or str(proof.get("genesis_fingerprint", "")) \
				!= str(state.get("genesis_fingerprint", "")):
		return "qualification_proof_lineage_mismatch"
	if int(proof.get("expected_core_revision", -1)) \
			!= int(state.get("revision", -1)):
		return "qualification_proof_revision_mismatch"
	if int(proof.get("source_revision", -1)) \
			!= int(port_context.get("current_source_revision", -2)):
		return "qualification_proof_source_revision_mismatch"
	var gate := state.get("victory_gate", {}) as Dictionary
	if int(proof.get("macro_round_index", -1)) \
			!= int(gate.get("macro_round_index", -1)) \
			or str(proof.get("condition_id", "")) \
				!= str(intent.get("condition_id", "")):
		return "qualification_proof_facts_mismatch"
	return ""


static func _boundary_proof_binding_error(
	proof: Dictionary,
	state: Dictionary,
	intent: Dictionary,
	port_context: Dictionary
) -> String:
	if not _valid_boundary_proof_shape(proof):
		return "boundary_proof_invalid"
	if str(proof.get("proof_id", "")) != str(intent.get("proof_id", "")) \
			or str(proof.get("proof_fingerprint", "")) \
				!= str(intent.get("proof_fingerprint", "")):
		return "boundary_proof_identity_mismatch"
	if str(proof.get("authority_id", "")) \
			!= str(port_context.get("authority_id", "")) \
			or str(proof.get("source_authority_id", "")) \
				!= str(port_context.get("source_authority_id", "")) \
			or str(proof.get("issuer_instance_id", "")) \
				!= str(port_context.get("issuer_instance_id", "")):
		return "boundary_proof_issuer_mismatch"
	if str(proof.get("match_instance_id", "")) \
			!= str(state.get("match_instance_id", "")) \
			or str(proof.get("genesis_fingerprint", "")) \
				!= str(state.get("genesis_fingerprint", "")):
		return "boundary_proof_lineage_mismatch"
	if int(proof.get("expected_core_revision", -1)) \
			!= int(state.get("revision", -1)):
		return "boundary_proof_revision_mismatch"
	if int(proof.get("source_revision", -1)) \
			!= int(port_context.get("current_source_revision", -2)):
		return "boundary_proof_source_revision_mismatch"
	var gate := state.get("victory_gate", {}) as Dictionary
	if int(proof.get("macro_round_index", -1)) \
			!= int(gate.get("macro_round_index", -1)) \
			or int(proof.get("macro_round_index", -1)) \
				!= int(intent.get("macro_round_index", -1)) \
			or str(proof.get("condition_id", "")) \
				!= str(gate.get("pending_condition_id", "")) \
			or str(proof.get("condition_id", "")) \
				!= str(intent.get("condition_id", "")):
		return "boundary_proof_facts_mismatch"
	if str(proof.get("qualification_proof_id", "")) \
			!= str(gate.get("pending_qualification_proof_id", "")) \
			or str(proof.get("qualification_proof_fingerprint", "")) \
				!= str(gate.get("pending_qualification_proof_fingerprint", "")) \
			or str(proof.get("authority_id", "")) \
				!= str(gate.get("pending_qualification_authority_id", "")) \
			or str(proof.get("source_authority_id", "")) \
				!= str(gate.get("pending_qualification_source_authority_id", "")) \
			or str(proof.get("issuer_instance_id", "")) \
				!= str(gate.get("pending_qualification_issuer_instance_id", "")) \
			or int(proof.get("source_revision", -1)) \
				< int(gate.get("pending_qualification_source_revision", -1)):
		return "boundary_proof_qualification_binding_mismatch"
	return ""


static func _valid_committed_receipt(
	receipt: Dictionary,
	intent_id: String,
	sequence_index: int,
	expected_predecessor_receipt_fingerprint: String,
	expected_source_state_fingerprint: String
) -> bool:
	if not _is_pure_data(receipt) or not _has_exact_keys(receipt, RECEIPT_FIELDS):
		return false
	if not (receipt.get("schema_version") is int) \
			or int(receipt.get("schema_version", -1)) != SCHEMA_VERSION \
			or str(receipt.get("ruleset_id", "")) != RULESET_ID \
			or str(receipt.get("intent_id", "")) != intent_id \
			or str(receipt.get("intent_kind_id", "")) not in INTENT_KIND_IDS \
			or not _is_fingerprint(receipt.get("intent_fingerprint")) \
			or not (receipt.get("intent_payload") is Dictionary) \
			or str(receipt.get("predecessor_receipt_fingerprint", "")) \
				!= expected_predecessor_receipt_fingerprint \
			or str(receipt.get("source_state_fingerprint", "")) \
				!= expected_source_state_fingerprint \
			or receipt.get("accepted") != true \
			or receipt.get("committed") != true \
			or not (receipt.get("state_revision_before") is int) \
			or int(receipt.get("state_revision_before", -1)) != sequence_index \
			or not (receipt.get("state_revision_after") is int) \
			or int(receipt.get("state_revision_after", -1)) != sequence_index + 1 \
			or not (receipt.get("victory_pending") is bool) \
			or not (receipt.get("final_settlement_committed") is bool) \
			or not (receipt.get("final_settlement_count") is int) \
			or not (receipt.get("condition_id") is String) \
			or not (receipt.get("proof_id") is String) \
			or not (receipt.get("proof_fingerprint") is String) \
			or not (receipt.get("proof_authority_id") is String) \
			or not (receipt.get("proof_source_authority_id") is String) \
			or not (receipt.get("proof_issuer_instance_id") is String) \
			or not (receipt.get("proof_source_revision") is int) \
			or not _is_fingerprint(receipt.get("result_state_fingerprint")):
		return false
	var intent_payload := receipt.get("intent_payload", {}) as Dictionary
	var kind := str(receipt.get("intent_kind_id", ""))
	if str(intent_payload.get("intent_id", "")) != intent_id \
			or str(intent_payload.get("intent_kind_id", "")) != kind \
			or not (intent_payload.get("expected_revision") is int) \
			or int(intent_payload.get("expected_revision", -1)) != sequence_index \
			or _intent_fingerprint(intent_payload) \
				!= str(receipt.get("intent_fingerprint", "")):
		return false
	if kind == INTENT_KIND_SOLAR and not _valid_solar_intent(intent_payload):
		return false
	if kind == INTENT_KIND_QUALIFICATION \
			and not _valid_qualification_intent(intent_payload):
		return false
	if kind == INTENT_KIND_REVALIDATION \
			and not _valid_revalidation_intent(intent_payload):
		return false
	if str(receipt.get("receipt_id", "")) != _receipt_id_for_intent(
		intent_id,
		str(receipt.get("intent_fingerprint", ""))
	):
		return false
	if not _is_fingerprint(receipt.get("receipt_fingerprint")) \
			or str(receipt.get("receipt_fingerprint", "")) \
				!= _data_fingerprint(receipt, "receipt_fingerprint"):
		return false
	var reason := str(receipt.get("reason_code", ""))
	if kind == INTENT_KIND_SOLAR:
		if reason != "solar_state_committed" \
				or not str(receipt.get("condition_id", "")).is_empty() \
				or not str(receipt.get("proof_id", "")).is_empty() \
				or not str(receipt.get("proof_fingerprint", "")).is_empty() \
				or not str(receipt.get("proof_authority_id", "")).is_empty() \
				or not str(receipt.get("proof_source_authority_id", "")).is_empty() \
				or not str(receipt.get("proof_issuer_instance_id", "")).is_empty() \
				or int(receipt.get("proof_source_revision", -2)) != -1:
			return false
	else:
		if not _is_stable_id(receipt.get("condition_id")) \
				or not _is_stable_id(receipt.get("proof_id")) \
				or not _is_fingerprint(receipt.get("proof_fingerprint")) \
				or str(receipt.get("proof_authority_id", "")) \
					!= TRUSTED_AUTHORITY_ID \
				or str(receipt.get("proof_source_authority_id", "")) \
					!= TRUSTED_SOURCE_AUTHORITY_ID \
				or not _is_stable_id(receipt.get("proof_issuer_instance_id")) \
				or not _is_nonnegative_integer(receipt.get("proof_source_revision")):
			return false
		if kind == INTENT_KIND_QUALIFICATION and reason not in [
			"victory_qualification_not_met",
			"victory_pending_until_macro_round_boundary",
			"existing_victory_pending_preserved",
		]:
			return false
		if kind == INTENT_KIND_REVALIDATION and reason not in [
			"victory_revalidation_failed_pending_cleared",
			"final_settlement_committed_exact_once",
		]:
			return false
	var settlement_receipt := reason == "final_settlement_committed_exact_once"
	if settlement_receipt:
		return (
			receipt.get("final_settlement_committed") == true
			and _is_stable_id(receipt.get("final_settlement_id"))
			and int(receipt.get("final_settlement_count", 0)) == 1
		)
	return (
		receipt.get("final_settlement_committed") == false
		and str(receipt.get("final_settlement_id", "")).is_empty()
		and int(receipt.get("final_settlement_count", -1)) == 0
	)


static func _journal_matches_victory_gate(state: Dictionary) -> bool:
	var gate := state.get("victory_gate", {}) as Dictionary
	var ids := state.get("processed_intent_ids", []) as Array
	var ledger := state.get("receipt_ledger", {}) as Dictionary
	var expected_predecessor := str(state.get("genesis_fingerprint", ""))
	var expected_source := expected_predecessor
	var replay_solar := {
		"sunlit": bool(state.get("genesis_solar_sunlit", false)),
		"work_rate_multiplier": solar_multiplier(
			bool(state.get("genesis_solar_sunlit", false))
		),
		"source_id": SOLAR_SOURCE_ID,
		"source_revision": 0,
	}
	var replay_gate := {
		"macro_round_index": int(state.get("genesis_macro_round_index", 0)),
		"pending": false,
		"pending_condition_id": "",
		"pending_trigger_intent_id": "",
		"pending_trigger_revision": -1,
		"pending_qualification_proof_id": "",
		"pending_qualification_proof_fingerprint": "",
		"pending_qualification_authority_id": "",
		"pending_qualification_source_authority_id": "",
		"pending_qualification_issuer_instance_id": "",
		"pending_qualification_source_revision": -1,
		"final_settlement_committed": false,
		"final_settlement_id": "",
		"final_settlement_receipt_id": "",
		"final_settlement_count": 0,
	}

	for index in range(ids.size()):
		var intent_id := str(ids[index])
		var receipt := ledger.get(intent_id, {}) as Dictionary
		if not _valid_committed_receipt(
			receipt,
			intent_id,
			index,
			expected_predecessor,
			expected_source
		):
			return false
		if bool(replay_gate.get("final_settlement_committed", false)):
			return false
		var kind := str(receipt.get("intent_kind_id", ""))
		var reason := str(receipt.get("reason_code", ""))
		var intent_payload := receipt.get("intent_payload", {}) as Dictionary
		match kind:
			INTENT_KIND_SOLAR:
				var next_source_revision := int(
					intent_payload.get("source_revision", -1)
				)
				if next_source_revision <= int(replay_solar.get("source_revision", -1)):
					return false
				var next_sunlit := bool(intent_payload.get("sunlit", false))
				replay_solar["sunlit"] = next_sunlit
				replay_solar["work_rate_multiplier"] = solar_multiplier(next_sunlit)
				replay_solar["source_revision"] = next_source_revision
			INTENT_KIND_QUALIFICATION:
				if str(receipt.get("condition_id", "")) \
						!= str(intent_payload.get("condition_id", "")) \
						or str(receipt.get("proof_id", "")) \
							!= str(intent_payload.get("proof_id", "")) \
						or str(receipt.get("proof_fingerprint", "")) \
							!= str(intent_payload.get("proof_fingerprint", "")):
					return false
				match reason:
					"victory_pending_until_macro_round_boundary":
						if bool(replay_gate.get("pending", false)):
							return false
						replay_gate["pending"] = true
						replay_gate["pending_condition_id"] = str(
							receipt.get("condition_id", "")
						)
						replay_gate["pending_trigger_intent_id"] = intent_id
						replay_gate["pending_trigger_revision"] = index + 1
						replay_gate["pending_qualification_proof_id"] = str(
							receipt.get("proof_id", "")
						)
						replay_gate["pending_qualification_proof_fingerprint"] = str(
							receipt.get("proof_fingerprint", "")
						)
						replay_gate["pending_qualification_authority_id"] = str(
							receipt.get("proof_authority_id", "")
						)
						replay_gate["pending_qualification_source_authority_id"] = str(
							receipt.get("proof_source_authority_id", "")
						)
						replay_gate["pending_qualification_issuer_instance_id"] = str(
							receipt.get("proof_issuer_instance_id", "")
						)
						replay_gate["pending_qualification_source_revision"] = int(
							receipt.get("proof_source_revision", -1)
						)
					"existing_victory_pending_preserved":
						if not bool(replay_gate.get("pending", false)):
							return false
					"victory_qualification_not_met":
						pass
					_:
						return false
			INTENT_KIND_REVALIDATION:
				if not bool(replay_gate.get("pending", false)) \
						or str(receipt.get("condition_id", "")) \
							!= str(replay_gate.get("pending_condition_id", "")) \
						or str(receipt.get("condition_id", "")) \
							!= str(intent_payload.get("condition_id", "")) \
						or int(intent_payload.get("macro_round_index", -1)) \
							!= int(replay_gate.get("macro_round_index", -1)) \
						or str(receipt.get("proof_id", "")) \
							!= str(intent_payload.get("proof_id", "")) \
						or str(receipt.get("proof_fingerprint", "")) \
							!= str(intent_payload.get("proof_fingerprint", "")) \
						or str(receipt.get("proof_authority_id", "")) \
							!= str(replay_gate.get(
								"pending_qualification_authority_id", ""
							)) \
						or str(receipt.get("proof_source_authority_id", "")) \
							!= str(replay_gate.get(
								"pending_qualification_source_authority_id", ""
							)) \
						or str(receipt.get("proof_issuer_instance_id", "")) \
							!= str(replay_gate.get(
								"pending_qualification_issuer_instance_id", ""
							)) \
						or int(receipt.get("proof_source_revision", -1)) \
							< int(replay_gate.get(
								"pending_qualification_source_revision", -1
							)):
					return false
				replay_gate["pending"] = false
				replay_gate["pending_condition_id"] = ""
				replay_gate["pending_trigger_intent_id"] = ""
				replay_gate["pending_trigger_revision"] = -1
				replay_gate["pending_qualification_proof_id"] = ""
				replay_gate["pending_qualification_proof_fingerprint"] = ""
				replay_gate["pending_qualification_authority_id"] = ""
				replay_gate["pending_qualification_source_authority_id"] = ""
				replay_gate["pending_qualification_issuer_instance_id"] = ""
				replay_gate["pending_qualification_source_revision"] = -1
				if reason == "final_settlement_committed_exact_once":
					replay_gate["final_settlement_committed"] = true
					replay_gate["final_settlement_id"] = str(
						receipt.get("final_settlement_id", "")
					)
					replay_gate["final_settlement_receipt_id"] = str(
						receipt.get("receipt_id", "")
					)
					replay_gate["final_settlement_count"] = 1
			_:
				return false
		if bool(receipt.get("victory_pending", false)) \
				!= bool(replay_gate.get("pending", false)) \
				or bool(receipt.get("final_settlement_committed", false)) \
					!= bool(replay_gate.get("final_settlement_committed", false)) \
				or str(receipt.get("final_settlement_id", "")) \
					!= str(replay_gate.get("final_settlement_id", "")) \
				or int(receipt.get("final_settlement_count", -1)) \
					!= int(replay_gate.get("final_settlement_count", -2)):
			return false
		var replay_result_fingerprint := _business_state_fingerprint_for_components(
			state,
			index + 1,
			replay_solar,
			replay_gate
		)
		if str(receipt.get("result_state_fingerprint", "")) \
				!= replay_result_fingerprint:
			return false
		expected_predecessor = str(receipt.get("receipt_fingerprint", ""))
		expected_source = replay_result_fingerprint

	return (
		int(state.get("revision", -1)) == ids.size()
		and state.get("solar") == replay_solar
		and gate == replay_gate
	)


static func _checkpoint_error(checkpoint_state: Dictionary) -> String:
	if not _is_pure_data(checkpoint_state) \
			or not _has_exact_keys(checkpoint_state, CHECKPOINT_FIELDS):
		return "checkpoint_fields_invalid"
	if not (checkpoint_state.get("schema_version") is int) \
			or int(checkpoint_state.get("schema_version", -1)) != SCHEMA_VERSION \
			or str(checkpoint_state.get("schema_id", "")) != CHECKPOINT_SCHEMA_ID \
			or str(checkpoint_state.get("ruleset_id", "")) != RULESET_ID \
			or not _is_stable_id(checkpoint_state.get("match_instance_id")) \
			or not _is_fingerprint(checkpoint_state.get("genesis_fingerprint")) \
			or not _is_nonnegative_integer(checkpoint_state.get("source_revision")) \
			or not _is_fingerprint(checkpoint_state.get("source_state_fingerprint")):
		return "checkpoint_header_invalid"
	if not (checkpoint_state.get("authority_state") is Dictionary):
		return "checkpoint_state_invalid"
	var candidate := checkpoint_state.get("authority_state", {}) as Dictionary
	if not is_valid_state(candidate):
		return "checkpoint_state_invalid"
	if str(candidate.get("match_instance_id", "")) \
			!= str(checkpoint_state.get("match_instance_id", "")) \
			or str(candidate.get("genesis_fingerprint", "")) \
				!= str(checkpoint_state.get("genesis_fingerprint", "")) \
			or int(candidate.get("revision", -1)) \
				!= int(checkpoint_state.get("source_revision", -1)) \
			or state_fingerprint(candidate) \
				!= str(checkpoint_state.get("source_state_fingerprint", "")):
		return "checkpoint_source_binding_invalid"
	if not _is_fingerprint(checkpoint_state.get("checkpoint_fingerprint")) \
			or str(checkpoint_state.get("checkpoint_fingerprint", "")) \
				!= _data_fingerprint(checkpoint_state, "checkpoint_fingerprint"):
		return "checkpoint_fingerprint_invalid"
	return ""


static func _receipt_lineage_is_prefix(
	candidate: Dictionary,
	current: Dictionary
) -> bool:
	var candidate_ids := candidate.get("processed_intent_ids", []) as Array
	var current_ids := current.get("processed_intent_ids", []) as Array
	if candidate_ids.size() > current_ids.size():
		return false
	var candidate_ledger := candidate.get("receipt_ledger", {}) as Dictionary
	var current_ledger := current.get("receipt_ledger", {}) as Dictionary
	for index in range(candidate_ids.size()):
		var intent_id := str(candidate_ids[index])
		if intent_id != str(current_ids[index]) \
				or candidate_ledger.get(intent_id) != current_ledger.get(intent_id):
			return false
	return true


static func _existing_intent_outcome(
	state: Dictionary,
	intent: Dictionary
) -> Dictionary:
	var intent_id := str(intent.get("intent_id", ""))
	if intent_id.is_empty():
		return {"handled": false}
	var ledger := state.get("receipt_ledger", {}) as Dictionary
	if not ledger.has(intent_id):
		return {"handled": false}
	var existing := ledger.get(intent_id, {}) as Dictionary
	if str(existing.get("intent_fingerprint", "")) == _intent_fingerprint(intent):
		return {
			"handled": true,
			"outcome": _outcome(state, existing),
		}
	return {
		"handled": true,
		"outcome": _reject(state, intent, "intent_id_collision"),
	}


static func _record_receipt(
	state: Dictionary,
	intent_id: String,
	receipt: Dictionary
) -> void:
	(state.get("processed_intent_ids", []) as Array).append(intent_id)
	(state.get("receipt_ledger", {}) as Dictionary)[intent_id] = receipt.duplicate(true)


static func _reject(
	state: Dictionary,
	intent: Dictionary,
	reason_code: String,
	proof: Dictionary = {}
) -> Dictionary:
	return _outcome(
		state,
		_make_receipt(state, state, intent, false, false, reason_code, proof)
	)


static func _make_receipt(
	before_state: Dictionary,
	after_state: Dictionary,
	intent: Dictionary,
	accepted: bool,
	committed: bool,
	reason_code: String,
	proof: Dictionary
) -> Dictionary:
	var gate := after_state.get("victory_gate", {}) as Dictionary
	var intent_fingerprint := _intent_fingerprint(intent)
	if intent_fingerprint.is_empty():
		intent_fingerprint = _data_fingerprint({
			"invalid_intent_id": str(intent.get("intent_id", "invalid.intent")),
			"invalid_intent_kind_id": str(intent.get("intent_kind_id", "invalid.kind")),
		})
	var chain_context := _receipt_chain_context(before_state)
	var receipt := {
		"schema_version": SCHEMA_VERSION,
		"ruleset_id": RULESET_ID,
		"receipt_id": _receipt_id_for_intent(
			str(intent.get("intent_id", "invalid.intent")),
			intent_fingerprint
		),
		"intent_id": str(intent.get("intent_id", "")),
		"intent_kind_id": str(intent.get("intent_kind_id", "unknown")),
		"intent_fingerprint": intent_fingerprint,
		"intent_payload": intent.duplicate(true),
		"predecessor_receipt_fingerprint": chain_context.get(
			"predecessor_receipt_fingerprint",
			before_state.get("genesis_fingerprint", "")
		),
		"source_state_fingerprint": chain_context.get(
			"source_state_fingerprint",
			before_state.get("genesis_fingerprint", "")
		),
		"accepted": accepted,
		"committed": committed,
		"reason_code": reason_code,
		"state_revision_before": int(before_state.get("revision", -1)),
		"state_revision_after": int(after_state.get("revision", -1)),
		"victory_pending": bool(gate.get("pending", false)),
		"final_settlement_committed": bool(
			gate.get("final_settlement_committed", false)
		),
		"final_settlement_id": str(gate.get("final_settlement_id", "")),
		"final_settlement_count": int(gate.get("final_settlement_count", 0)),
		"condition_id": str(intent.get("condition_id", "")),
		"proof_id": str(proof.get("proof_id", "")),
		"proof_fingerprint": str(proof.get("proof_fingerprint", "")),
		"proof_authority_id": str(proof.get("authority_id", "")),
		"proof_source_authority_id": str(proof.get("source_authority_id", "")),
		"proof_issuer_instance_id": str(proof.get("issuer_instance_id", "")),
		"proof_source_revision": int(proof.get("source_revision", -1)),
		"result_state_fingerprint": _business_state_fingerprint(after_state),
	}
	receipt["receipt_fingerprint"] = _data_fingerprint(receipt)
	return receipt


static func _receipt_chain_context(state: Dictionary) -> Dictionary:
	var anchor := str(state.get("genesis_fingerprint", ""))
	var ids := state.get("processed_intent_ids", []) as Array
	if ids.is_empty():
		return {
			"predecessor_receipt_fingerprint": anchor,
			"source_state_fingerprint": anchor,
		}
	var last_id := str(ids[ids.size() - 1])
	var last_receipt := (
		state.get("receipt_ledger", {}) as Dictionary
	).get(last_id, {}) as Dictionary
	return {
		"predecessor_receipt_fingerprint": str(
			last_receipt.get("receipt_fingerprint", "")
		),
		"source_state_fingerprint": str(
			last_receipt.get("result_state_fingerprint", "")
		),
	}


static func _outcome(state: Dictionary, receipt: Dictionary) -> Dictionary:
	return {
		"state": state.duplicate(true),
		"receipt": receipt.duplicate(true),
	}


static func _solar_phase_id(state: Dictionary) -> String:
	return "sunlit" if bool(
		(state.get("solar", {}) as Dictionary).get("sunlit", false)
	) else "dark"


static func _is_nonnegative_finite_number(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	var number := float(value)
	return is_finite(number) and number >= 0.0


static func _is_nonnegative_integer(value: Variant) -> bool:
	return value is int and int(value) >= 0


static func _is_positive_integer(value: Variant) -> bool:
	return value is int and int(value) > 0


static func _is_stable_id(value: Variant) -> bool:
	if not (value is String):
		return false
	var identifier := str(value)
	if identifier.is_empty() or identifier.length() > 192:
		return false
	for index in range(identifier.length()):
		var code := identifier.unicode_at(index)
		var letter := (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
		var digit := code >= 48 and code <= 57
		var separator := code in [45, 46, 58, 95]
		if not letter and not digit and not separator:
			return false
	return true


static func _is_fingerprint(value: Variant) -> bool:
	if not (value is String) or str(value).length() != 64:
		return false
	for index in range(str(value).length()):
		var code := str(value).unicode_at(index)
		if not ((code >= 48 and code <= 57) or (code >= 97 and code <= 102)):
			return false
	return true


static func _data_fingerprint(value: Variant, omitted_field: String = "") -> String:
	var source: Variant = value
	if not omitted_field.is_empty():
		if not (value is Dictionary):
			return ""
		var copied := (value as Dictionary).duplicate(true)
		copied.erase(omitted_field)
		source = copied
	if not _is_pure_data(source):
		return ""
	return JSON.stringify(_canonicalize(source)).sha256_text().to_lower()


static func _intent_fingerprint(intent: Dictionary) -> String:
	return _data_fingerprint(intent)


static func _receipt_id_for_intent(intent_id: String, intent_fingerprint: String) -> String:
	return "receipt.%s" % (intent_id + ":" + intent_fingerprint).sha256_text().left(32)


static func _business_state_fingerprint(state: Dictionary) -> String:
	return _business_state_fingerprint_for_components(
		state,
		int(state.get("revision", -1)),
		state.get("solar", {}) as Dictionary,
		state.get("victory_gate", {}) as Dictionary
	)


static func _business_state_fingerprint_for_components(
	state: Dictionary,
	revision: int,
	solar: Dictionary,
	victory_gate: Dictionary
) -> String:
	return _data_fingerprint({
		"schema_version": state.get("schema_version"),
		"ruleset_id": state.get("ruleset_id"),
		"balance_profile_id": state.get("balance_profile_id"),
		"balance_profile_fingerprint": state.get("balance_profile_fingerprint"),
		"match_instance_id": state.get("match_instance_id"),
		"genesis_fingerprint": state.get("genesis_fingerprint"),
		"genesis_solar_sunlit": state.get("genesis_solar_sunlit"),
		"genesis_macro_round_index": state.get("genesis_macro_round_index"),
		"revision": revision,
		"solar": solar.duplicate(true),
		"victory_gate": victory_gate.duplicate(true),
	})


static func _genesis_fingerprint_for_state(state: Dictionary) -> String:
	return _data_fingerprint({
		"schema_version": state.get("schema_version"),
		"ruleset_id": state.get("ruleset_id"),
		"balance_profile_id": state.get("balance_profile_id"),
		"balance_profile_fingerprint": state.get("balance_profile_fingerprint"),
		"match_instance_id": state.get("match_instance_id"),
		"genesis_solar_sunlit": state.get("genesis_solar_sunlit"),
		"genesis_macro_round_index": state.get("genesis_macro_round_index"),
	})


static func _wire_integer_equals(value: Variant, expected: int) -> bool:
	if value is int:
		return int(value) == expected
	if value is float:
		return is_finite(float(value)) and float(value) == float(expected)
	return false


static func _has_exact_keys(record: Dictionary, expected_fields: Array) -> bool:
	var actual: Array[String] = []
	for key_variant in record.keys():
		if not (key_variant is String):
			return false
		actual.append(str(key_variant))
	actual.sort()
	var expected: Array[String] = []
	for field_variant in expected_fields:
		expected.append(str(field_variant))
	expected.sort()
	return actual == expected


static func _is_pure_data(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return true
		TYPE_FLOAT:
			return is_finite(float(value))
		TYPE_ARRAY:
			for item in value as Array:
				if not _is_pure_data(item):
					return false
			return true
		TYPE_DICTIONARY:
			for key_variant in (value as Dictionary).keys():
				if not (key_variant is String):
					return false
				if not _is_pure_data((value as Dictionary).get(key_variant)):
					return false
			return true
		_:
			return false


static func _canonicalize(value: Variant) -> Variant:
	if value is Array:
		var canonical_array: Array = []
		for item in value as Array:
			canonical_array.append(_canonicalize(item))
		return canonical_array
	if value is Dictionary:
		var keys: Array[String] = []
		for key_variant in (value as Dictionary).keys():
			keys.append(str(key_variant))
		keys.sort()
		var canonical_dictionary: Dictionary = {}
		for key in keys:
			canonical_dictionary[key] = _canonicalize(
				(value as Dictionary).get(key)
			)
		return canonical_dictionary
	return value


static func _encode_wire_int64(value: Variant) -> Variant:
	if value is int:
		return {
			"type": "int64",
			"decimal": str(value),
		}
	if value is Array:
		var encoded_array: Array = []
		for item in value as Array:
			encoded_array.append(_encode_wire_int64(item))
		return encoded_array
	if value is Dictionary:
		var encoded_dictionary: Dictionary = {}
		for key_variant in (value as Dictionary).keys():
			encoded_dictionary[str(key_variant)] = _encode_wire_int64(
				(value as Dictionary).get(key_variant)
			)
		return encoded_dictionary
	return value


static func _decode_wire_int64(value: Variant) -> Dictionary:
	if value is Dictionary:
		var record := value as Dictionary
		if record.has("type") or record.has("decimal"):
			if not _has_exact_keys(record, ["type", "decimal"]):
				return {"valid": false}
			if str(record.get("type", "")) != "int64":
				return {"valid": false}
			if not (record.get("decimal") is String):
				return {"valid": false}
			var decimal := str(record.get("decimal", ""))
			if not _canonical_int64_decimal(decimal):
				return {"valid": false}
			var parsed := decimal.to_int()
			return {"valid": true, "value": parsed}
		var decoded_dictionary: Dictionary = {}
		for key_variant in record.keys():
			if not (key_variant is String):
				return {"valid": false}
			var decoded_value := _decode_wire_int64(record.get(key_variant))
			if not bool(decoded_value.get("valid", false)):
				return {"valid": false}
			decoded_dictionary[str(key_variant)] = decoded_value.get("value")
		return {"valid": true, "value": decoded_dictionary}
	if value is Array:
		var decoded_array: Array = []
		for item in value as Array:
			var decoded_item := _decode_wire_int64(item)
			if not bool(decoded_item.get("valid", false)):
				return {"valid": false}
			decoded_array.append(decoded_item.get("value"))
		return {"valid": true, "value": decoded_array}
	if value is float:
		return {"valid": is_finite(float(value)), "value": value}
	if value is bool or value is String or value == null:
		return {"valid": true, "value": value}
	return {"valid": false}


static func _canonical_int64_decimal(decimal: String) -> bool:
	if decimal.is_empty():
		return false
	var negative := decimal.begins_with("-")
	var digits := decimal.substr(1) if negative else decimal
	if digits.is_empty() or (digits.length() > 1 and digits.begins_with("0")):
		return false
	if negative and digits == "0":
		return false
	for index in range(digits.length()):
		var code := digits.unicode_at(index)
		if code < 48 or code > 57:
			return false
	var limit := "9223372036854775808" if negative else "9223372036854775807"
	if digits.length() != limit.length():
		return digits.length() < limit.length()
	return digits <= limit
