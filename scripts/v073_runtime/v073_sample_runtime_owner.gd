extends Node
class_name V073SampleRuntimeOwner

const TRACK_CORE := preload("res://scripts/v07_semantic/v07_unified_card_track_core.gd")
const TRACK_ACQUISITION_PORT := preload(
	"res://scripts/v07_semantic/v07_track_acquisition_authority_port.gd"
)
const DBG_CORE := preload("res://scripts/v07_semantic/v07_dbg_deck_core.gd")
const ASSET_BATCH_CORE := preload("res://scripts/v07_semantic/v07_asset_batch_core.gd")
const FACILITY_CORE := preload(
	"res://scripts/v07_semantic/v073_fixed_order_facility_contention_core.gd"
)
const SOLAR_VICTORY_CORE := preload(
	"res://scripts/v07_semantic/v07_solar_victory_core.gd"
)
const PLAYER_ADAPTER := preload(
	"res://scripts/v07_adapters/v07_canonical_player_projection_adapter.gd"
)
const AI_ADAPTER := preload(
	"res://scripts/v07_adapters/v07_canonical_ai_observation_adapter.gd"
)

const RULESET_ID := "v0.7.3"
const SAMPLE_MODE_ID := "NEW_V073_GAME"
const LOCAL_PLAYER_ID := "player.local"
const COLORS := ["life", "energy", "industry", "technology", "commerce", "shipping"]
const REGION_IDS := [
	"region.alpha",
	"region.beta",
	"region.gamma",
	"region.delta",
	"region.epsilon",
	"region.zeta",
]
const SUBMISSION_WINDOW_MSEC := 30000
const MAX_ACTIONS_PER_PLAYER := 5
const DEFAULT_MATCH_SEED := 730045
const PUBLIC_PROGRESS_PER_PLAYER_TARGET := 2

signal match_started(snapshot: Dictionary)
signal state_changed(snapshot: Dictionary)
signal action_queued(receipt: Dictionary)
signal submission_locked(receipt: Dictionary)
signal resolution_presented(receipt: Dictionary)
signal playtest_observation_ready(receipt: Dictionary)
signal final_settlement_committed(settlement: Dictionary)
signal runtime_fault(receipt: Dictionary)


class TrustedTimeAuthority extends RefCounted:
	var _ledger: Dictionary = {}
	var _sequence := 0

	func issue(observed_at_ms: int) -> Dictionary:
		_sequence += 1
		var attestation := {
			"schema_version": 1,
			"interface_id": ASSET_BATCH_CORE.TIME_ATTESTATION_INTERFACE_ID,
			"attestation_id": "time.v073.sample.%06d" % _sequence,
			"observed_at_ms": observed_at_ms,
		}
		attestation["attestation_fingerprint"] = ASSET_BATCH_CORE._fingerprint(attestation)
		_ledger[str(attestation.get("attestation_id", ""))] = attestation.duplicate(true)
		return attestation

	func authoritative_time_attestation_v1(attestation_id: String) -> Dictionary:
		if not _ledger.has(attestation_id):
			return {}
		return (_ledger.get(attestation_id, {}) as Dictionary).duplicate(true)


class CashParticipant extends RefCounted:
	var _authority_id: String
	var _credits := 24
	var _reservations: Dictionary = {}
	var _commits: Dictionary = {}
	var _cursor := 0

	func _init(actor_id: String) -> void:
		_authority_id = "v073.fixed_purchase.%s" % actor_id

	func acquisition_authority_id_v1() -> String:
		return _authority_id

	func capture_checkpoint_v1() -> Dictionary:
		return {
			"credits": _credits,
			"reservations": _reservations.duplicate(true),
			"commits": _commits.duplicate(true),
			"cursor": _cursor,
		}

	func prepare_acquisition_v1(request: Dictionary) -> Dictionary:
		var role := str(request.get("participant_role", ""))
		var reservation_id := "reservation.cash.%04d" % _cursor
		_cursor += 1
		if role != "cash":
			return _receipt(request, reservation_id, false, "cash_role_invalid")
		if _credits <= 0:
			return _receipt(request, reservation_id, false, "fixed_purchase_credit_unavailable")
		_reservations[reservation_id] = request.duplicate(true)
		return _receipt(request, reservation_id, true, "participant_prepared")

	func commit_prepared_acquisition_v1(
		reservation_id: String,
		track_receipt: Dictionary
	) -> Dictionary:
		if _commits.has(reservation_id):
			return (_commits.get(reservation_id, {}) as Dictionary).duplicate(true)
		var request := _reservations.get(reservation_id, {}) as Dictionary
		if request.is_empty():
			return {"accepted": false, "reason_code": "reservation_missing"}
		_credits -= 1
		var receipt := _receipt(
			request,
			reservation_id,
			true,
			"participant_committed",
			str(track_receipt.get("receipt_fingerprint", ""))
		)
		_commits[reservation_id] = receipt.duplicate(true)
		return receipt

	func abort_prepared_acquisition_v1(
		reservation_id: String,
		_reason_code: String
	) -> Dictionary:
		var request := _reservations.get(reservation_id, {}) as Dictionary
		_reservations.erase(reservation_id)
		return _receipt(request, reservation_id, true, "participant_aborted")

	func rollback_v1(checkpoint: Dictionary) -> Dictionary:
		_credits = int(checkpoint.get("credits", 0))
		_reservations = (checkpoint.get("reservations", {}) as Dictionary).duplicate(true)
		_commits = (checkpoint.get("commits", {}) as Dictionary).duplicate(true)
		_cursor = int(checkpoint.get("cursor", 0))
		return {"accepted": true, "reason_code": "participant_rolled_back"}

	func debug_snapshot() -> Dictionary:
		return {
			"authority_id": acquisition_authority_id_v1(),
			"credits": _credits,
			"reservation_count": _reservations.size(),
			"commit_count": _commits.size(),
		}

	func _receipt(
		request: Dictionary,
		reservation_id: String,
		accepted: bool,
		reason_code: String,
		track_receipt_fingerprint: String = ""
	) -> Dictionary:
		var value := {
			"accepted": accepted,
			"reason_code": reason_code,
			"transaction_id": str(request.get("transaction_id", "")),
			"reservation_id": reservation_id,
			"authority_id": acquisition_authority_id_v1(),
			"participant_role": str(request.get("participant_role", "cash")),
		}
		if not track_receipt_fingerprint.is_empty():
			value["track_receipt_fingerprint"] = track_receipt_fingerprint
		return TRACK_CORE.sealed_copy(value, "receipt_fingerprint")


class PersonalDiscardParticipant extends RefCounted:
	var _actor_id: String
	var _authority_id: String
	var _dbg: RefCounted
	var _reservations: Dictionary = {}
	var _commits: Dictionary = {}
	var _cursor := 0

	func _init(actor_id: String, dbg: RefCounted) -> void:
		_actor_id = actor_id
		_authority_id = "v073.personal_discard.%s" % actor_id
		_dbg = dbg

	func acquisition_authority_id_v1() -> String:
		return _authority_id

	func capture_checkpoint_v1() -> Dictionary:
		if _dbg == null:
			return {}
		var core_checkpoint_variant: Variant = _dbg.call("capture_checkpoint")
		if not (core_checkpoint_variant is Dictionary):
			return {}
		return {
			"core_checkpoint": (core_checkpoint_variant as Dictionary).duplicate(true),
			"reservations": _reservations.duplicate(true),
			"commits": _commits.duplicate(true),
			"cursor": _cursor,
		}

	func prepare_acquisition_v1(request: Dictionary) -> Dictionary:
		var reservation_id := "reservation.personal_discard.%s.%06d" % [
			_actor_id,
			_cursor,
		]
		_cursor += 1
		var reason := _request_reason(request)
		if not reason.is_empty():
			return _receipt(request, reservation_id, false, reason)
		_reservations[reservation_id] = request.duplicate(true)
		return _receipt(request, reservation_id, true, "participant_prepared")

	func commit_prepared_acquisition_v1(
		reservation_id: String,
		track_receipt: Dictionary
	) -> Dictionary:
		if _commits.has(reservation_id):
			return (_commits.get(reservation_id, {}) as Dictionary).duplicate(true)
		var request := _reservations.get(reservation_id, {}) as Dictionary
		if request.is_empty() or _dbg == null:
			return _receipt(request, reservation_id, false, "reservation_missing")
		var source := request.get("source_identity", {}) as Dictionary
		var definition_id := str(source.get("source_definition_id", ""))
		var card_spec := DBG_CORE.card_definition(definition_id)
		if card_spec.is_empty():
			return _receipt(
				request,
				reservation_id,
				false,
				"purchased_card_definition_missing"
			)
		var purchase_receipt_id := str(track_receipt.get("receipt_id", ""))
		if purchase_receipt_id.is_empty():
			return _receipt(
				request,
				reservation_id,
				false,
				"track_purchase_receipt_missing"
			)
		var internal_request_id := "request.dbg.purchase.%s" % (
			reservation_id.sha256_text().left(24)
		)
		var intent_variant: Variant = _dbg.call(
			"create_authority_intent",
			internal_request_id,
			DBG_CORE.ACTION_ACCEPT_PURCHASE,
			{
				"purchase_receipt_id": purchase_receipt_id,
				"card_spec": card_spec,
			}
		)
		if not (intent_variant is Dictionary):
			return _receipt(
				request,
				reservation_id,
				false,
				"purchase_intent_contract_invalid"
			)
		var dbg_receipt_variant: Variant = _dbg.call(
			"apply_intent",
			intent_variant as Dictionary
		)
		if not (dbg_receipt_variant is Dictionary) or not bool(
			(dbg_receipt_variant as Dictionary).get("success", false)
		):
			return _receipt(
				request,
				reservation_id,
				false,
				"personal_discard_commit_failed"
			)
		var result := _receipt(
			request,
			reservation_id,
			true,
			"participant_committed",
			str(track_receipt.get("receipt_fingerprint", ""))
		)
		_reservations.erase(reservation_id)
		_commits[reservation_id] = result.duplicate(true)
		return result

	func abort_prepared_acquisition_v1(
		reservation_id: String,
		_reason_code: String
	) -> Dictionary:
		var request := _reservations.get(reservation_id, {}) as Dictionary
		_reservations.erase(reservation_id)
		return _receipt(request, reservation_id, true, "participant_aborted")

	func rollback_v1(checkpoint: Dictionary) -> Dictionary:
		if _dbg == null or not (checkpoint.get("core_checkpoint") is Dictionary):
			return {"accepted": false, "reason_code": "checkpoint_invalid"}
		var rolled_back_variant: Variant = _dbg.call(
			"rollback_to_checkpoint",
			checkpoint.get("core_checkpoint", {}) as Dictionary
		)
		if not (rolled_back_variant is Dictionary) or not bool(
			(rolled_back_variant as Dictionary).get("rolled_back", false)
		):
			return {"accepted": false, "reason_code": "core_rollback_failed"}
		_reservations = (
			checkpoint.get("reservations", {}) as Dictionary
		).duplicate(true)
		_commits = (checkpoint.get("commits", {}) as Dictionary).duplicate(true)
		_cursor = int(checkpoint.get("cursor", 0))
		return {"accepted": true, "reason_code": "participant_rolled_back"}

	func _request_reason(request: Dictionary) -> String:
		if str(request.get("participant_role", "")) != "personal_discard":
			return "personal_discard_role_invalid"
		if str(request.get("authority_id", "")) != _authority_id:
			return "personal_discard_authority_invalid"
		if str(request.get("actor_id", "")) != _actor_id:
			return "personal_discard_actor_invalid"
		if str(request.get("action_id", "")) 				!= TRACK_CORE.ACTION_PURCHASE_VISIBLE_NORMAL_CARD:
			return "personal_discard_action_invalid"
		if str(request.get("destination_zone", "")) != "personal_discard" 				or str(request.get("reservation_kind", "")) 					!= "destination_capacity":
			return "personal_discard_destination_invalid"
		if str(request.get("request_fingerprint", "")) != TRACK_CORE.fingerprint(
			request,
			"request_fingerprint"
		):
			return "personal_discard_request_fingerprint_invalid"
		var source := request.get("source_identity", {}) as Dictionary
		if str(source.get("source_kind", "")) != "normal_card" 				or DBG_CORE.card_definition(
					str(source.get("source_definition_id", ""))
				).is_empty():
			return "personal_discard_source_invalid"
		return ""

	func _receipt(
		request: Dictionary,
		reservation_id: String,
		accepted: bool,
		reason_code: String,
		track_receipt_fingerprint: String = ""
	) -> Dictionary:
		var value := {
			"accepted": accepted,
			"reason_code": reason_code,
			"transaction_id": str(request.get("transaction_id", "")),
			"reservation_id": reservation_id,
			"authority_id": acquisition_authority_id_v1(),
			"participant_role": "personal_discard",
		}
		if not track_receipt_fingerprint.is_empty():
			value["track_receipt_fingerprint"] = track_receipt_fingerprint
		return TRACK_CORE.sealed_copy(value, "receipt_fingerprint")


class AcquisitionParticipantRouter extends RefCounted:
	var _role: String
	var _authority_id: String
	var _delegated_authority_id := ""
	var _participants_by_actor: Dictionary = {}
	var _reservation_bindings: Dictionary = {}
	var _reservation_sequence := 0

	func _init(role: String) -> void:
		_role = role
		_authority_id = "v073.acquisition_router.%s" % role

	func register_actor(actor_id: String, participant: RefCounted) -> bool:
		if actor_id.is_empty() or participant == null or _participants_by_actor.has(actor_id):
			return false
		for method_name in [
			"acquisition_authority_id_v1",
			"capture_checkpoint_v1",
			"prepare_acquisition_v1",
			"commit_prepared_acquisition_v1",
			"abort_prepared_acquisition_v1",
			"rollback_v1",
		]:
			if not participant.has_method(method_name):
				return false
		var participant_authority_id := str(
			participant.call("acquisition_authority_id_v1")
		)
		if participant_authority_id.is_empty():
			return false
		if _role == "commodity_slot":
			if _delegated_authority_id.is_empty():
				_delegated_authority_id = participant_authority_id
			elif _delegated_authority_id != participant_authority_id:
				return false
		_participants_by_actor[actor_id] = participant
		return true

	func acquisition_authority_id_v1() -> String:
		if _role == "commodity_slot" and not _delegated_authority_id.is_empty():
			return _delegated_authority_id
		return _authority_id

	func capture_checkpoint_v1() -> Dictionary:
		var delegates := {}
		for actor_id_variant in _participants_by_actor.keys():
			var actor_id := str(actor_id_variant)
			var participant := _participants_by_actor.get(actor_id) as RefCounted
			var checkpoint_variant: Variant = participant.call("capture_checkpoint_v1")
			if not (checkpoint_variant is Dictionary):
				return {}
			delegates[actor_id] = (checkpoint_variant as Dictionary).duplicate(true)
		return {
			"delegates": delegates,
			"reservation_bindings": _reservation_bindings.duplicate(true),
			"reservation_sequence": _reservation_sequence,
		}

	func prepare_acquisition_v1(request: Dictionary) -> Dictionary:
		var actor_id := str(request.get("actor_id", ""))
		var participant := _participants_by_actor.get(actor_id) as RefCounted
		_reservation_sequence += 1
		var router_reservation_id := "reservation.router.%s.%06d" % [
			_role,
			_reservation_sequence,
		]
		if participant == null:
			return _receipt(
				request,
				router_reservation_id,
				false,
				"acquisition_actor_not_registered"
			)
		var delegated_request := request.duplicate(true)
		delegated_request["authority_id"] = str(
			participant.call("acquisition_authority_id_v1")
		)
		delegated_request["request_fingerprint"] = TRACK_CORE.fingerprint(
			delegated_request,
			"request_fingerprint"
		)
		var delegated_variant: Variant = participant.call(
			"prepare_acquisition_v1",
			delegated_request
		)
		if not (delegated_variant is Dictionary):
			return _receipt(
				request,
				router_reservation_id,
				false,
				"delegate_prepare_contract_invalid"
			)
		var delegated := delegated_variant as Dictionary
		_reservation_bindings[router_reservation_id] = {
			"actor_id": actor_id,
			"delegate_reservation_id": str(
				delegated.get("reservation_id", "")
			),
			"request": request.duplicate(true),
		}
		if not bool(delegated.get("accepted", false)):
			return _receipt(
				request,
				router_reservation_id,
				false,
				str(delegated.get("reason_code", "delegate_prepare_rejected"))
			)
		return _receipt(
			request,
			router_reservation_id,
			true,
			"participant_prepared"
		)

	func commit_prepared_acquisition_v1(
		reservation_id: String,
		track_receipt: Dictionary
	) -> Dictionary:
		var binding := _reservation_bindings.get(reservation_id, {}) as Dictionary
		var request := binding.get("request", {}) as Dictionary
		var actor_id := str(binding.get("actor_id", ""))
		var participant := _participants_by_actor.get(actor_id) as RefCounted
		if binding.is_empty() or participant == null:
			return _receipt(request, reservation_id, false, "reservation_missing")
		var delegated_variant: Variant = participant.call(
			"commit_prepared_acquisition_v1",
			str(binding.get("delegate_reservation_id", "")),
			track_receipt
		)
		if not (delegated_variant is Dictionary):
			return _receipt(
				request,
				reservation_id,
				false,
				"delegate_commit_contract_invalid"
			)
		var delegated := delegated_variant as Dictionary
		return _receipt(
			request,
			reservation_id,
			bool(delegated.get("accepted", false)),
			str(delegated.get("reason_code", "delegate_commit_rejected")),
			str(track_receipt.get("receipt_fingerprint", ""))
		)

	func abort_prepared_acquisition_v1(
		reservation_id: String,
		reason_code: String
	) -> Dictionary:
		var binding := _reservation_bindings.get(reservation_id, {}) as Dictionary
		var request := binding.get("request", {}) as Dictionary
		var actor_id := str(binding.get("actor_id", ""))
		var participant := _participants_by_actor.get(actor_id) as RefCounted
		if not binding.is_empty() and participant != null:
			participant.call(
				"abort_prepared_acquisition_v1",
				str(binding.get("delegate_reservation_id", "")),
				reason_code
			)
		_reservation_bindings.erase(reservation_id)
		return _receipt(request, reservation_id, true, "participant_aborted")

	func rollback_v1(checkpoint: Dictionary) -> Dictionary:
		var delegates := checkpoint.get("delegates", {}) as Dictionary
		for actor_id_variant in delegates.keys():
			var actor_id := str(actor_id_variant)
			var participant := _participants_by_actor.get(actor_id) as RefCounted
			if participant == null:
				return {"accepted": false, "reason_code": "rollback_actor_missing"}
			var rolled_back_variant: Variant = participant.call(
				"rollback_v1",
				delegates.get(actor_id, {}) as Dictionary
			)
			if not (rolled_back_variant is Dictionary) 					or not bool((rolled_back_variant as Dictionary).get(
						"accepted",
						false
					)):
				return {
					"accepted": false,
					"reason_code": "delegate_rollback_failed",
				}
		_reservation_bindings = (
			checkpoint.get("reservation_bindings", {}) as Dictionary
		).duplicate(true)
		_reservation_sequence = int(checkpoint.get("reservation_sequence", 0))
		return {"accepted": true, "reason_code": "participant_rolled_back"}

	func _receipt(
		request: Dictionary,
		reservation_id: String,
		accepted: bool,
		reason_code: String,
		track_receipt_fingerprint: String = ""
	) -> Dictionary:
		var value := {
			"accepted": accepted,
			"reason_code": reason_code,
			"transaction_id": str(request.get("transaction_id", "")),
			"reservation_id": reservation_id,
			"authority_id": acquisition_authority_id_v1(),
			"participant_role": _role,
		}
		if not track_receipt_fingerprint.is_empty():
			value["track_receipt_fingerprint"] = track_receipt_fingerprint
		return TRACK_CORE.sealed_copy(value, "receipt_fingerprint")


class VictoryAuthority extends RefCounted:
	var _capability := RefCounted.new()
	var _issuer_instance_id: String
	var _current_source_revision := 0
	var _issued_proofs: Dictionary = {}

	func _init(match_id: String) -> void:
		_issuer_instance_id = "issuer.%s" % match_id

	func capability() -> RefCounted:
		return _capability

	func set_current_source_revision(value: int) -> void:
		_current_source_revision = value

	func victory_authority_identity_v1() -> Dictionary:
		return {
			"authority_id": SOLAR_VICTORY_CORE.TRUSTED_AUTHORITY_ID,
			"source_authority_id": SOLAR_VICTORY_CORE.TRUSTED_SOURCE_AUTHORITY_ID,
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
		if str(proof.get("proof_fingerprint", "")) != proof_fingerprint:
			return {}
		return proof.duplicate(true)

	func issue_qualification(
		state: Dictionary,
		proof_id: String,
		condition_id: String,
		qualifies: bool,
		source_revision: int
	) -> Dictionary:
		set_current_source_revision(source_revision)
		return _record_proof({
			"schema_version": SOLAR_VICTORY_CORE.SCHEMA_VERSION,
			"authority_id": SOLAR_VICTORY_CORE.TRUSTED_AUTHORITY_ID,
			"source_authority_id": SOLAR_VICTORY_CORE.TRUSTED_SOURCE_AUTHORITY_ID,
			"issuer_instance_id": _issuer_instance_id,
			"proof_id": proof_id,
			"proof_kind_id": SOLAR_VICTORY_CORE.PROOF_KIND_QUALIFICATION,
			"match_instance_id": str(state.get("match_instance_id", "")),
			"genesis_fingerprint": str(state.get("genesis_fingerprint", "")),
			"expected_core_revision": int(state.get("revision", 0)),
			"source_revision": source_revision,
			"macro_round_index": int(
				(state.get("victory_gate", {}) as Dictionary).get("macro_round_index", 1)
			),
			"condition_id": condition_id,
			"qualifies": qualifies,
		})

	func issue_boundary(
		state: Dictionary,
		proof_id: String,
		boundary: Dictionary,
		revalidation_passed: bool,
		settlement_id: String,
		source_revision: int
	) -> Dictionary:
		set_current_source_revision(source_revision)
		var gate := state.get("victory_gate", {}) as Dictionary
		return _record_proof({
			"schema_version": SOLAR_VICTORY_CORE.SCHEMA_VERSION,
			"authority_id": SOLAR_VICTORY_CORE.TRUSTED_AUTHORITY_ID,
			"source_authority_id": SOLAR_VICTORY_CORE.TRUSTED_SOURCE_AUTHORITY_ID,
			"issuer_instance_id": _issuer_instance_id,
			"proof_id": proof_id,
			"proof_kind_id": SOLAR_VICTORY_CORE.PROOF_KIND_BOUNDARY,
			"match_instance_id": str(state.get("match_instance_id", "")),
			"genesis_fingerprint": str(state.get("genesis_fingerprint", "")),
			"expected_core_revision": int(state.get("revision", 0)),
			"source_revision": source_revision,
			"macro_round_index": int(gate.get("macro_round_index", 1)),
			"condition_id": str(gate.get("pending_condition_id", "")),
			"qualification_proof_id": str(
				gate.get("pending_qualification_proof_id", "")
			),
			"qualification_proof_fingerprint": str(
				gate.get("pending_qualification_proof_fingerprint", "")
			),
			"boundary": boundary.duplicate(true),
			"revalidation_passed": revalidation_passed,
			"final_settlement_id": settlement_id,
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
		return JSON.stringify(_canonicalize(value)).sha256_text().to_lower()

	static func _canonicalize(value: Variant) -> Variant:
		if value is Array:
			var array_value: Array = []
			for item in value as Array:
				array_value.append(_canonicalize(item))
			return array_value
		if value is Dictionary:
			var keys: Array[String] = []
			for key_variant in (value as Dictionary).keys():
				keys.append(str(key_variant))
			keys.sort()
			var dictionary_value := {}
			for key in keys:
				dictionary_value[key] = _canonicalize(
					(value as Dictionary).get(key)
				)
			return dictionary_value
		return value


var _track_core: RefCounted = null
var _asset_core: RefCounted = ASSET_BATCH_CORE.new()
var _time_authority := TrustedTimeAuthority.new()
var _victory_authority: VictoryAuthority = null
var _dbg_by_player: Dictionary = {}
var _cash_by_player: Dictionary = {}
var _track_port: RefCounted = null
var _acquisition_routers: Dictionary = {}
var _player_ids: Array[String] = []
var _local_player_id := LOCAL_PLAYER_ID
var _match_id := ""
var _seed := DEFAULT_MATCH_SEED
var _phase := "idle"
var _batch_number := 0
var _clock_msec := 0
var _opened_at_msec := 0
var _submission_deadline_msec := 0
var _hidden_order: Array[String] = []
var _asset_state: Dictionary = {}
var _asset_balances: Dictionary = {}
var _facility_state: Dictionary = {}
var _facility_slots: Array = []
var _solar_state: Dictionary = {}
var _region_sunlit: Dictionary = {}
var _queued_by_player: Dictionary = {}
var _locked_by_player: Dictionary = {}
var _maintenance_done: Dictionary = {}
var _public_history: Array = []
var _public_progress_points := 0
var _final_settlement: Dictionary = {}
var _automate_local_human := false
var _accelerated := false
var _ai_submission_started := false
var _runtime_error_count := 0
var _invalid_action_count := 0
var _invalid_action_reasons: Dictionary = {}
var _nonfinite_count := 0
var _hidden_info_violation_count := 0
var _dual_authority_count := 0
var _final_settlement_presentation_count := 0
var _final_settlement_public_log_count := 0
var _canonical_player_projection_count := 0
var _canonical_ai_observation_count := 0
var _adapter_failure_count := 0
var _projection_emit_coalesced := false
var _projection_emit_pending := false
var _match_sequence := 0


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	if _phase in ["idle", "settled", "failed"]:
		return
	var scaled_delta := delta * (30.0 if _accelerated else 1.0)
	_clock_msec += maxi(1, int(round(scaled_delta * 1000.0)))
	match _phase:
		"submission":
			_process_submission()
		"resolving":
			resolve_next_action()
		"maintenance":
			_process_maintenance()


func start_new_game(
	player_count: int = 4,
	seed_value: int = DEFAULT_MATCH_SEED,
	accelerated: bool = false,
	automate_local_human: bool = false
) -> Dictionary:
	if player_count < 3 or player_count > 8:
		return _reject("player_count_out_of_range")
	_reset_runtime()
	_match_sequence += 1
	_seed = seed_value
	_accelerated = accelerated
	_automate_local_human = automate_local_human
	_match_id = "match.v073.sample.%d.%d" % [absi(seed_value), _match_sequence]
	_player_ids.append(_local_player_id)
	for index in range(1, player_count):
		_player_ids.append("player.ai.%d" % index)

	_track_core = TRACK_CORE.new()
	var track_started := _track_core.call(
		"start_match",
		_player_ids,
		seed_value,
		{
			"balance_profile_id": TRACK_CORE.BALANCE_PROFILE_ID,
			"balance_profile_fingerprint": TRACK_CORE.BALANCE_PROFILE_FINGERPRINT,
			"normal_card_ratio_basis_points": 6000,
			"commodity_card_ratio_basis_points": 4000,
			"local_visible_slot_count": 5,
			"match_instance_id": _match_id,
		}
	) as Dictionary
	if not bool(track_started.get("accepted", false)):
		return _fail("track_start_rejected", track_started)

	_acquisition_routers = {
		"cash": AcquisitionParticipantRouter.new("cash"),
		"personal_discard": AcquisitionParticipantRouter.new("personal_discard"),
		"commodity_slot": AcquisitionParticipantRouter.new("commodity_slot"),
	}
	for index in range(_player_ids.size()):
		var player_id := _player_ids[index]
		var dbg := DBG_CORE.new()
		var initialized := dbg.call(
			"initialize",
			player_id,
			seed_value + (index + 1) * 104729
		) as Dictionary
		if not bool(initialized.get("initialized", false)):
			return _fail("dbg_start_rejected", initialized)
		var track_bound := dbg.call(
			"bind_unified_track_receipt_authority",
			_track_core
		) as Dictionary
		if not bool(track_bound.get("bound", false)):
			return _fail("dbg_track_authority_bind_failed", track_bound)
		_dbg_by_player[player_id] = dbg
		var cash := CashParticipant.new(player_id)
		var personal_discard := PersonalDiscardParticipant.new(player_id, dbg)
		_cash_by_player[player_id] = cash
		if not (
			_acquisition_routers.get("cash") as AcquisitionParticipantRouter
		).register_actor(player_id, cash) or not (
			_acquisition_routers.get("personal_discard") as AcquisitionParticipantRouter
		).register_actor(player_id, personal_discard) or not (
			_acquisition_routers.get("commodity_slot") as AcquisitionParticipantRouter
		).register_actor(player_id, dbg):
			return _fail("acquisition_actor_route_rejected", {"actor_id": player_id})
		_asset_balances[player_id] = _zero_colors()
	_track_port = TRACK_ACQUISITION_PORT.new()
	var configured := _track_port.call("configure_v1", _track_core, {
		"cash": _acquisition_routers.get("cash"),
		"personal_discard": _acquisition_routers.get("personal_discard"),
		"commodity_slot": _acquisition_routers.get("commodity_slot"),
	}) as Dictionary
	if not bool(configured.get("accepted", false)):
		return _fail("track_acquisition_port_rejected", configured)

	_asset_core = ASSET_BATCH_CORE.new()
	var time_bound := _asset_core.call(
		"bind_time_attestation_authority",
		_time_authority
	) as Dictionary
	if not bool(time_bound.get("bound", false)):
		return _fail("time_authority_bind_failed", time_bound)
	_facility_slots = _build_genesis_facility_slots()
	_solar_state = SOLAR_VICTORY_CORE.create_state(false, 1, _match_id)
	if _solar_state.is_empty():
		return _fail("solar_victory_start_rejected", {})
	_victory_authority = VictoryAuthority.new(_match_id)
	_initialize_region_solar()
	_begin_batch()
	if _phase == "failed":
		return _reject("v073_new_game_initialization_failed")
	var snapshot := player_snapshot(_local_player_id)
	if snapshot.is_empty():
		return _fail("canonical_player_projection_failed", {})
	match_started.emit(snapshot)
	state_changed.emit(snapshot)
	return {
		"accepted": true,
		"reason_code": "v073_new_game_started",
		"match_id": _match_id,
		"ruleset_id": RULESET_ID,
		"player_count": _player_ids.size(),
		"local_human_count": 1,
		"ai_player_count": _player_ids.size() - 1,
	}


func phase() -> String:
	return _phase


func player_ids() -> Array[String]:
	return _player_ids.duplicate()


func local_player_id() -> String:
	return _local_player_id


func submission_seconds_remaining() -> float:
	if _phase != "submission":
		return 0.0
	return maxf(0.0, float(_submission_deadline_msec - _clock_msec) / 1000.0)


func legal_card_actions(actor_id: String) -> Array:
	if _phase != "submission" or not _player_ids.has(actor_id):
		return []
	var projection := _dbg_projection(actor_id)
	var facts := projection.get("facts", {}) as Dictionary
	var result: Array = []
	for card_variant in facts.get("hand", []) as Array:
		var card := card_variant as Dictionary
		for slot_variant in _legal_slots_for_card(actor_id, card):
			var slot := slot_variant as Dictionary
			var card_instance_id := str(card.get("instance_id", ""))
			var slot_id := str(slot.get("slot_id", ""))
			result.append({
				"option_id": "option.%s.%s" % [
					card_instance_id.sha256_text().left(10),
					slot_id.sha256_text().left(10),
				],
				"actor_id": actor_id,
				"card_instance_id": card_instance_id,
				"card_definition_id": str(card.get("definition_id", "")),
				"card_origin_class": str(card.get("origin_class", "standard")),
				"primary_color": str(card.get("primary_color", "")),
				"target_slot_id": slot_id,
				"target_region_id": str(slot.get("region_id", "")),
				"facility_type": str(slot.get("facility_type", "")),
				"industry_id": str(slot.get("industry_id", "")),
				"facility_action_mode": _facility_mode(actor_id, slot),
				"region_revision": int(slot.get("region_revision", 0)),
				"slot_generation": int(slot.get("slot_generation", 0)),
				"occupancy": str(slot.get("occupancy", "")),
				"expected_facility_id": slot.get("facility_id"),
				"expected_facility_generation": slot.get("facility_generation"),
				"expected_owner_id": slot.get("owner_id"),
				"expected_rank": slot.get("rank"),
				"expected_damage_revision": slot.get("damage_revision"),
				"asset_cost": int(card.get("primary_asset_cost", 0)),
				"fizzle_policy_id": "FIZZLE_FULL_ASSET_REFUND",
				"source_revision": _batch_number,
			})
	return result


func queue_card_action(
	actor_id: String,
	card_instance_id: String,
	target_slot_id: String
) -> Dictionary:
	if _phase != "submission":
		return _reject_action("submission_window_not_open")
	if not _player_ids.has(actor_id) or bool(_locked_by_player.get(actor_id, false)):
		return _reject_action("actor_not_available")
	var queue := _queued_by_player.get(actor_id, []) as Array
	if queue.size() >= MAX_ACTIONS_PER_PLAYER:
		return _reject_action("local_queue_full")
	for row_variant in queue:
		if str((row_variant as Dictionary).get("card_instance_id", "")) == card_instance_id:
			return _reject_action("card_already_queued")
	var card := _card_in_hand(actor_id, card_instance_id)
	var slot := _slot_by_id(target_slot_id)
	if card.is_empty() or slot.is_empty():
		return _reject_action("card_or_target_missing")
	if not _legal_slot_for_card(actor_id, card, slot):
		return _reject_action("target_not_legal_for_card")
	var binding := {
		"actor_id": actor_id,
		"action_id": "action.%s.%s.%02d" % [
			_batch_id(),
			actor_id,
			queue.size(),
		],
		"card_instance_id": card_instance_id,
		"card_definition_id": str(card.get("definition_id", "")),
		"target_slot_id": target_slot_id,
		"target_region_id": str(slot.get("region_id", "")),
		"target_revision": int(slot.get("region_revision", 0)),
		"target_slot_generation": int(slot.get("slot_generation", 0)),
		"facility_action_mode": _facility_mode(actor_id, slot),
		"expected_facility_id": slot.get("facility_id"),
		"expected_facility_generation": slot.get("facility_generation"),
		"expected_owner_id": slot.get("owner_id"),
		"expected_rank": slot.get("rank"),
		"expected_damage_revision": slot.get("damage_revision"),
		"target_bound": true,
	}
	queue.append(binding)
	_queued_by_player[actor_id] = queue
	var receipt := {
		"accepted": true,
		"reason_code": "card_action_prebound",
		"actor_id": actor_id,
		"binding": binding.duplicate(true),
		"queue_size": queue.size(),
	}
	action_queued.emit(receipt)
	_emit_local_state()
	return receipt


func reorder_queued_action(actor_id: String, from_index: int, to_index: int) -> Dictionary:
	if _phase != "submission" or bool(_locked_by_player.get(actor_id, false)):
		return _reject_action("queue_order_locked")
	var queue := _queued_by_player.get(actor_id, []) as Array
	if from_index < 0 or from_index >= queue.size() or to_index < 0 or to_index >= queue.size():
		return _reject_action("queue_index_invalid")
	var row: Variant = queue.pop_at(from_index)
	queue.insert(to_index, row)
	_queued_by_player[actor_id] = queue
	_emit_local_state()
	return {
		"accepted": true,
		"reason_code": "local_action_order_changed_before_lock",
		"from_index": from_index,
		"to_index": to_index,
	}


func remove_queued_action(actor_id: String, action_id: String) -> Dictionary:
	if _phase != "submission" or bool(_locked_by_player.get(actor_id, false)):
		return _reject_action("queue_binding_locked")
	var queue := _queued_by_player.get(actor_id, []) as Array
	for index in range(queue.size()):
		if str((queue[index] as Dictionary).get("action_id", "")) == action_id:
			queue.remove_at(index)
			_queued_by_player[actor_id] = queue
			_emit_local_state()
			return {"accepted": true, "reason_code": "queued_action_removed"}
	return _reject_action("queued_action_missing")


func lock_player_submission(actor_id: String) -> Dictionary:
	if _phase != "submission" or not _player_ids.has(actor_id):
		return _reject_action("submission_window_not_open")
	if bool(_locked_by_player.get(actor_id, false)):
		return {
			"accepted": true,
			"reason_code": "submission_already_locked",
			"actor_id": actor_id,
		}
	var queue := _queued_by_player.get(actor_id, []) as Array
	var asset_actions: Array = []
	var facility_actions: Array = []
	for index in range(queue.size()):
		var binding := queue[index] as Dictionary
		var built := _build_bound_actions(actor_id, binding, index)
		if built.is_empty():
			return _reject_action("prebound_action_build_failed")
		asset_actions.append((built.get("asset_action", {}) as Dictionary).duplicate(true))
		facility_actions.append((built.get("facility_action", {}) as Dictionary).duplicate(true))
	var intent := ASSET_BATCH_CORE.build_lock_intent(
		"intent.lock.%s.%s" % [_batch_id(), actor_id],
		_batch_id(),
		actor_id,
		_clock_msec,
		asset_actions
	)
	if intent.is_empty():
		return _reject_action("asset_lock_intent_invalid")
	var locked := _asset_core.call(
		"lock_player_queue",
		_asset_state,
		intent,
		_completed_gdp_milli(actor_id),
		_time_authority.issue(_clock_msec),
		_hidden_order
	) as Dictionary
	if not bool(locked.get("accepted", false)):
		return _reject_action(str(locked.get("reason_code", "asset_lock_rejected")))
	var next_asset_state := (
		locked.get("state", {}) as Dictionary
	).duplicate(true)
	var stored_queue: Array = []
	for index in range(queue.size()):
		var stored := (queue[index] as Dictionary).duplicate(true)
		stored["asset_action"] = asset_actions[index]
		stored["facility_action"] = facility_actions[index]
		stored_queue.append(stored)
	var dbg := _dbg_by_player.get(actor_id) as RefCounted
	var dbg_state := dbg.call("core_authority_snapshot") as Dictionary
	var dbg_batch_id := int(
		(dbg_state.get("state", {}) as Dictionary).get("batch_index", 0)
	)
	var dbg_lock := dbg.call(
		"create_authority_intent",
		"intent.dbg.lock.%s.%s" % [_batch_id(), actor_id],
		DBG_CORE.ACTION_LOCK_LOCAL_QUEUE,
		{"batch_id": dbg_batch_id}
	) as Dictionary
	var dbg_receipt := dbg.call("apply_intent", dbg_lock) as Dictionary
	if not bool(dbg_receipt.get("success", false)):
		return _fail("dbg_queue_lock_failed", dbg_receipt)
	_asset_state = next_asset_state
	_locked_by_player[actor_id] = true
	_queued_by_player[actor_id] = stored_queue
	var receipt := {
		"accepted": true,
		"reason_code": "submission_locked_with_full_asset_reservation",
		"actor_id": actor_id,
		"action_count": asset_actions.size(),
	}
	submission_locked.emit(receipt)
	if _all_players_locked():
		_begin_resolution()
	else:
		_emit_local_state()
	return receipt


func _resolution_alignment_reason() -> String:
	if str(_asset_state.get("batch_id", "")) != str(_facility_state.get("batch_id", "")):
		return "resolution_batch_authority_mismatch"
	var asset_cursor := int(_asset_state.get("resolution_cursor", -1))
	var facility_cursor := int(_facility_state.get("resolution_cursor", -1))
	if asset_cursor != facility_cursor or asset_cursor < 0:
		return "resolution_cursor_authority_mismatch"
	var asset_queue := _asset_state.get("authority_queue", []) as Array
	var facility_queue := _facility_state.get("authority_queue", []) as Array
	if asset_queue.size() != facility_queue.size() 			or asset_cursor >= asset_queue.size():
		return "resolution_queue_authority_mismatch"
	var asset_entry := asset_queue[asset_cursor] as Dictionary
	var facility_entry := facility_queue[facility_cursor] as Dictionary
	if str(asset_entry.get("action_id", "")) 			!= str(facility_entry.get("action_id", "")) 			or str(asset_entry.get("actor_id", "")) 				!= str(facility_entry.get("actor_id", "")):
		return "resolution_action_authority_mismatch"
	return ""


func resolve_next_action() -> Dictionary:
	if _phase != "resolving":
		return _reject_action("resolution_not_active")
	var alignment_reason := _resolution_alignment_reason()
	if not alignment_reason.is_empty():
		_dual_authority_count += 1
		return _fail(alignment_reason, {
			"asset_cursor": int(_asset_state.get("resolution_cursor", -1)),
			"facility_cursor": int(_facility_state.get("resolution_cursor", -1)),
		})
	var facility_outcome := FACILITY_CORE.resolve_next(_facility_state)
	if not bool(facility_outcome.get("accepted", false)):
		return _fail("facility_resolution_failed", facility_outcome)
	var next_facility_state := (
		facility_outcome.get("state", {}) as Dictionary
	).duplicate(true)
	var facility_receipt := (
		facility_outcome.get("receipt", {}) as Dictionary
	).duplicate(true)
	var action_id := str(facility_receipt.get("action_id", ""))
	var actor_id := str(facility_receipt.get("actor_id", ""))
	var asset_outcome: Dictionary
	if str(facility_receipt.get("outcome_id", "")) == "facility_action_fizzled":
		asset_outcome = ASSET_BATCH_CORE.settle_invalid_target(
			_asset_state,
			action_id,
			str(facility_receipt.get("reason_code", "facility_target_invalid"))
		)
	else:
		asset_outcome = ASSET_BATCH_CORE.settle_next_action(
			_asset_state,
			action_id,
			"success"
		)
	if not bool(asset_outcome.get("accepted", false)):
		return _fail("asset_resolution_failed", asset_outcome)
	var next_asset_state := (
		asset_outcome.get("state", {}) as Dictionary
	).duplicate(true)
	var source_card_id := _source_card_id_for_action(actor_id, action_id)
	if not source_card_id.is_empty():
		var dbg := _dbg_by_player.get(actor_id) as RefCounted
		var play_intent := dbg.call(
			"create_intent",
			"intent.play.%s" % action_id,
			actor_id,
			DBG_CORE.ACTION_PLAY_CARD,
			{"instance_id": source_card_id}
		) as Dictionary
		var play_receipt := dbg.call("apply_intent", play_intent) as Dictionary
		if not bool(play_receipt.get("success", false)):
			return _fail("dbg_card_resolution_failed", play_receipt)
	_facility_state = next_facility_state
	_asset_state = next_asset_state
	_sync_facility_slots()
	if str(facility_receipt.get("outcome_id", "")) == "facility_action_resolved":
		_public_progress_points += 1
	var public_receipt := {
		"accepted": true,
		"anonymous_action_id": str(
			facility_receipt.get("anonymous_action_id", "")
		),
		"outcome_id": str(facility_receipt.get("outcome_id", "")),
		"reason_code": str(facility_receipt.get("reason_code", "")),
		"facility_created": bool(facility_receipt.get("facility_created", false)),
		"facility_upgraded": bool(facility_receipt.get("facility_upgraded", false)),
		"facility_repaired": bool(facility_receipt.get("facility_repaired", false)),
		"asset_reservation_released": bool(
			facility_receipt.get("asset_reservation_released", false)
		),
		"normal_card_destination": "discard",
		"action_slot_refunded": false,
	}
	_public_history.append(public_receipt.duplicate(true))
	resolution_presented.emit(public_receipt)
	if str(_facility_state.get("status", "")) == "resolved":
		_complete_batch_resolution()
	else:
		_emit_local_state()
	return public_receipt


func acquire_track_item(actor_id: String, source_instance_id: String) -> Dictionary:
	if _phase != "submission" or not _player_ids.has(actor_id):
		return _reject_action("track_acquisition_outside_submission")
	var projection := _track_core.call("player_projection_v1", actor_id) as Dictionary
	var private_facts := projection.get("viewer_private_facts", {}) as Dictionary
	var item: Dictionary = {}
	for item_variant in private_facts.get("own_segment_items", []) as Array:
		var candidate := item_variant as Dictionary
		if str(candidate.get("instance_id", "")) == source_instance_id:
			item = candidate.duplicate(true)
			break
	if item.is_empty() or not bool(item.get("claimable", false)):
		return _reject_action("track_item_not_claimable")
	var source := _track_core.call(
		"visible_source_identity_v1",
		actor_id,
		source_instance_id
	) as Dictionary
	var cash_router := (
		_acquisition_routers.get("cash") as AcquisitionParticipantRouter
	)
	var inventory_router := (
		_acquisition_routers.get(
			"commodity_slot"
				if str(item.get("card_kind", "")) == "commodity_card"
				else "personal_discard"
		) as AcquisitionParticipantRouter
	)
	var authorization := TRACK_CORE.seal_viewer_segment_authorization_v1({
		"schema_version": TRACK_CORE.SCHEMA_VERSION,
		"capability_id": "capability.v073.track.%s.%d" % [actor_id, _batch_number],
		"authorization_id": "authorization.v073.track.%s.%d" % [
			actor_id,
			_batch_number,
		],
		"authorization_authority_id": "v073.player_segment_authority",
		"authorized_actor_id": actor_id,
		"authorized_source_identity_id": str(source.get("source_identity_id", "")),
		"authorized_source_instance_id": source_instance_id,
		"authorized_segment_owner_id": actor_id,
		"source_track_revision": int(source.get("source_track_revision", 0)),
		"inventory_authority_id": inventory_router.acquisition_authority_id_v1(),
		"cash_authority_id": (
			"authority.none"
			if str(item.get("card_kind", "")) == "commodity_card"
			else cash_router.acquisition_authority_id_v1()
		),
	})
	var action_id := TRACK_CORE.ACTION_CLAIM_VISIBLE_COMMODITY \
		if str(item.get("card_kind", "")) == "commodity_card" \
		else TRACK_CORE.ACTION_PURCHASE_VISIBLE_NORMAL_CARD
	var request_id := "request.track.%s.%d.%s" % [
		actor_id,
		_batch_number,
		source_instance_id.sha256_text().left(12),
	]
	var intent := _track_core.call(
		"build_visible_acquisition_intent_v1",
		request_id,
		actor_id,
		action_id,
		source,
		authorization
	) as Dictionary
	if intent.is_empty():
		return _reject_action("track_intent_invalid")
	var port := _track_port
	var rebound := _track_core.call(
		"bind_acquisition_authority_port_v1",
		port
	) as Dictionary
	if not bool(rebound.get("accepted", false)):
		return _reject_action("track_port_rebind_failed")
	var prepared := port.call("prepare_v1", intent) as Dictionary
	if not bool(prepared.get("accepted", false)):
		return _reject_action(str(prepared.get("reason_code", "track_prepare_failed")))
	var transaction_id := str(prepared.get("transaction_id", ""))
	var committed := port.call("commit_v1", transaction_id) as Dictionary
	if not bool(committed.get("accepted", false)):
		return _reject_action(str(committed.get("reason_code", "track_commit_failed")))
	_public_history.append({
		"accepted": true,
		"outcome_id": "unified_track_acquisition",
		"reason_code": "commodity_claimed" \
			if action_id == TRACK_CORE.ACTION_CLAIM_VISIBLE_COMMODITY \
			else "normal_card_purchased_to_discard",
		"card_kind": str(item.get("card_kind", "")),
		"primary_color": str(item.get("primary_color", "")),
	})
	_emit_local_state()
	return {
		"accepted": true,
		"reason_code": "unified_track_acquisition_committed",
		"card_kind": str(item.get("card_kind", "")),
		"destination_zone": str(committed.get("destination_zone", "")),
	}


func merge_normal_pair(actor_id: String, left_id: String, right_id: String) -> Dictionary:
	if _phase != "maintenance":
		return _reject_action("merge_outside_maintenance")
	var dbg := _dbg_by_player.get(actor_id) as RefCounted
	if dbg == null:
		return _reject_action("actor_not_registered")
	var intent := dbg.call(
		"create_intent",
		"request.merge.%s.%d.%s" % [actor_id, _batch_number, left_id.left(8)],
		actor_id,
		DBG_CORE.ACTION_MERGE_CARDS,
		{"left_instance_id": left_id, "right_instance_id": right_id}
	) as Dictionary
	var receipt := dbg.call("apply_intent", intent) as Dictionary
	if not bool(receipt.get("success", false)):
		return _reject_action(str(receipt.get("reason_code", "merge_rejected")))
	_emit_local_state()
	return receipt


func finish_maintenance(actor_id: String) -> Dictionary:
	if _phase != "maintenance" or not _player_ids.has(actor_id):
		return _reject_action("maintenance_not_active")
	if bool(_maintenance_done.get(actor_id, false)):
		return {"accepted": true, "reason_code": "maintenance_already_finished"}
	var dbg := _dbg_by_player.get(actor_id) as RefCounted
	var intent := dbg.call(
		"create_intent",
		"intent.maintenance.end.%s.%d" % [actor_id, _batch_number],
		actor_id,
		DBG_CORE.ACTION_END_MAINTENANCE,
		{}
	) as Dictionary
	var receipt := dbg.call("apply_intent", intent) as Dictionary
	if not bool(receipt.get("success", false)):
		return _reject_action(str(receipt.get("reason_code", "maintenance_end_failed")))
	_maintenance_done[actor_id] = true
	if _all_maintenance_done():
		_finish_macro_boundary()
	else:
		_emit_local_state()
	return receipt


func set_track_stance(actor_id: String, increase_color: String, decrease_color: String) -> Dictionary:
	if _phase != "submission" or increase_color not in COLORS \
			or decrease_color not in COLORS or increase_color == decrease_color:
		return _reject_action("track_stance_invalid")
	var intent := _track_core.call(
		"build_intent_v1",
		"intent.stance.%s.%d" % [actor_id, _batch_number],
		actor_id,
		TRACK_CORE.ACTION_SET_STANCE,
		{"increase_color": increase_color, "decrease_color": decrease_color}
	) as Dictionary
	var receipt := _track_core.call("apply_intent_v1", intent) as Dictionary
	if not bool(receipt.get("accepted", false)):
		return _reject_action(str(receipt.get("reason_code", "stance_rejected")))
	_emit_local_state()
	return receipt


func _canonical_player_projection(viewer_id: String) -> Dictionary:
	var track_projection := _track_core.call(
		"player_projection_v1",
		viewer_id
	) as Dictionary
	var dbg_projection := _dbg_projection(viewer_id)
	var asset_projection := ASSET_BATCH_CORE.asset_player_projection(
		_asset_state,
		viewer_id
	)
	var batch_projection := ASSET_BATCH_CORE.batch_player_projection(
		_asset_state,
		viewer_id
	)
	var facility_projection := FACILITY_CORE.player_projection(
		_facility_state,
		viewer_id
	)
	var authorization_revision := maxi(1, _batch_number)
	var context := PLAYER_ADAPTER.build_authorization_context(
		_match_id,
		maxi(1, _match_sequence),
		viewer_id,
		authorization_revision,
		authorization_revision,
		track_projection,
		dbg_projection,
		asset_projection,
		batch_projection,
		facility_projection
	)
	if context.is_empty():
		_adapter_failure_count += 1
		return {}
	var capability := PLAYER_ADAPTER.issue_capability()
	var adapter := PLAYER_ADAPTER.new(capability)
	if not adapter.bind_authorization(capability, context):
		_adapter_failure_count += 1
		return {}
	var sources := {
		"unified_track": track_projection,
		"personal_dbg": dbg_projection,
		"six_color_assets": asset_projection,
		"card_batch": batch_projection,
		"facility_contention": facility_projection,
	}
	var projection := adapter.adapt_player_projection(capability, context, sources)
	if projection.is_empty():
		_adapter_failure_count += 1
		return {}
	_canonical_player_projection_count += 1
	return projection


func player_snapshot(viewer_id: String) -> Dictionary:
	if not _player_ids.has(viewer_id) or _track_core == null 			or _asset_state.is_empty() or _facility_state.is_empty():
		return {}
	var canonical := _canonical_player_projection(viewer_id)
	if canonical.is_empty():
		return {}
	return {
		"ruleset_id": RULESET_ID,
		"sample_mode_id": SAMPLE_MODE_ID,
		"match_id": _match_id,
		"match_started": not _match_id.is_empty(),
		"phase": _phase,
		"batch_number": _batch_number,
		"submission_seconds_remaining": submission_seconds_remaining(),
		"viewer_id": viewer_id,
		"local_player_id": _local_player_id,
		"roster": _public_roster(viewer_id),
		"unified_track": (
			canonical.get("unified_track", {}) as Dictionary
		).duplicate(true),
		"personal_dbg": (
			canonical.get("personal_dbg", {}) as Dictionary
		).duplicate(true),
		"six_color_assets": (
			canonical.get("six_color_assets", {}) as Dictionary
		).duplicate(true),
		"card_batch": (
			canonical.get("card_batch", {}) as Dictionary
		).duplicate(true),
		"facility_contention": (
			canonical.get("facility_contention", {}) as Dictionary
		).duplicate(true),
		"canonical_player_projection": canonical,
		"legal_actions": legal_card_actions(viewer_id),
		"region_solar": _region_solar_projection(),
		"queued_actions": (
			_queued_by_player.get(viewer_id, []) as Array
		).duplicate(true),
		"submission_locked": bool(_locked_by_player.get(viewer_id, false)),
		"maintenance_done": bool(_maintenance_done.get(viewer_id, false)),
		"public_history": _public_history.duplicate(true),
		"public_progress_points": _public_progress_points,
		"public_progress_target": _victory_target(),
		"special_actions": _special_actions_for_viewer(viewer_id),
		"final_settlement": _final_settlement.duplicate(true),
		"save_enabled": false,
		"continue_enabled": false,
		"save_notice": "V0.7.3样品暂不支持中途保存",
	}


func _canonical_ai_observation(actor_id: String) -> Dictionary:
	var targets_by_card := _legal_targets_by_card(actor_id)
	var dbg := _dbg_by_player.get(actor_id) as RefCounted
	var legal_input := dbg.call(
		"build_legal_target_input",
		actor_id,
		"v073.production.legal_target_authority",
		maxi(1, _batch_number),
		targets_by_card
	) as Dictionary
	var track_observation := _track_core.call(
		"ai_observation_v1",
		actor_id
	) as Dictionary
	var dbg_observation := dbg.call(
		"ai_observation",
		actor_id,
		legal_input
	) as Dictionary
	var asset_observation := ASSET_BATCH_CORE.asset_ai_observation(
		_asset_state,
		actor_id
	)
	var batch_observation := ASSET_BATCH_CORE.batch_ai_observation(
		_asset_state,
		actor_id
	)
	var facility_observation := FACILITY_CORE.ai_observation(
		_facility_state,
		actor_id
	)
	var solar_observation := SOLAR_VICTORY_CORE.ai_observation(_solar_state)
	var authorization_revision := maxi(1, _batch_number)
	var context := AI_ADAPTER.build_authorization_context(
		_match_id,
		maxi(1, _match_sequence),
		actor_id,
		authorization_revision,
		authorization_revision,
		track_observation,
		dbg_observation,
		asset_observation,
		batch_observation,
		facility_observation,
		solar_observation
	)
	if context.is_empty():
		_adapter_failure_count += 1
		return {}
	var capability := AI_ADAPTER.issue_capability()
	var adapter := AI_ADAPTER.new(capability)
	if not adapter.bind_authorization(capability, context):
		_adapter_failure_count += 1
		return {}
	var sources := {
		"unified_track": track_observation,
		"personal_dbg": dbg_observation,
		"six_color_assets": asset_observation,
		"card_batch": batch_observation,
		"facility_contention": facility_observation,
		"solar_victory": solar_observation,
	}
	var observation := adapter.adapt_ai_observation(capability, context, sources)
	if observation.is_empty():
		_adapter_failure_count += 1
		return {}
	_canonical_ai_observation_count += 1
	return observation


func ai_observation(actor_id: String) -> Dictionary:
	if not _player_ids.has(actor_id) or _track_core == null 			or _asset_state.is_empty() or _facility_state.is_empty():
		return {}
	var canonical := _canonical_ai_observation(actor_id)
	if canonical.is_empty():
		return {}
	return {
		"ruleset_id": RULESET_ID,
		"actor_id": actor_id,
		"phase": _phase,
		"batch_number": _batch_number,
		"canonical_observation": canonical,
		"legal_actions": legal_card_actions(actor_id),
		"public_roster": _public_roster(actor_id),
		"public_history": _public_history.duplicate(true),
		"self_is_local_human": actor_id == _local_player_id,
	}


func run_accelerated_until_settled(max_steps: int = 2000) -> Dictionary:
	if _match_id.is_empty():
		return _reject("match_not_started")
	_accelerated = true
	_automate_local_human = true
	var was_coalesced := _projection_emit_coalesced
	_projection_emit_coalesced = true
	var steps := 0
	while _phase not in ["settled", "failed"] and steps < max_steps:
		_process(0.25)
		steps += 1
	_projection_emit_coalesced = was_coalesced
	if _projection_emit_pending and not _projection_emit_coalesced:
		_projection_emit_pending = false
		_emit_local_state()
	return {
		"accepted": _phase == "settled",
		"reason_code": "sample_match_completed" if _phase == "settled" \
			else "sample_match_step_limit_reached",
		"steps": steps,
		"phase": _phase,
		"final_settlement": _final_settlement.duplicate(true),
		"debug": debug_snapshot(),
	}


func debug_snapshot() -> Dictionary:
	return {
		"ruleset_id": RULESET_ID,
		"match_id": _match_id,
		"phase": _phase,
		"batch_number": _batch_number,
		"player_count": _player_ids.size(),
		"local_human_count": 1 if not _player_ids.is_empty() else 0,
		"ai_player_count": maxi(0, _player_ids.size() - 1),
		"active_rule_owner_count": 1 if not _match_id.is_empty() else 0,
		"active_batch_owner_count": 1 if not _asset_state.is_empty() else 0,
		"dual_authority_count": _dual_authority_count,
		"v06_runtime_mutation_count": 0,
		"legacy_fallback_count": 0,
		"mixed_ruleset_state_count": 0,
		"save_write_count": 0,
		"invalid_action_count": _invalid_action_count,
		"invalid_action_reasons": _invalid_action_reasons.duplicate(true),
		"nonfinite_count": _nonfinite_count,
		"hidden_info_violation_count": _hidden_info_violation_count,
		"runtime_error_count": _runtime_error_count,
		"canonical_player_projection_count": _canonical_player_projection_count,
		"canonical_ai_observation_count": _canonical_ai_observation_count,
		"adapter_failure_count": _adapter_failure_count,
		"player_adapter_connected": _canonical_player_projection_count > 0,
		"ai_adapter_connected": _canonical_ai_observation_count > 0,
		"ai_v06_policy_fallback_count": 0,
		"public_progress_points": _public_progress_points,
		"public_progress_target": _victory_target(),
		"final_settlement_count": int(
			(_solar_state.get("victory_gate", {}) as Dictionary).get(
				"final_settlement_count",
				0
			)
		) if not _solar_state.is_empty() else 0,
		"final_settlement_presentation_count": _final_settlement_presentation_count,
		"final_settlement_public_log_count": _final_settlement_public_log_count,
		"duplicate_settlement_count": maxi(
			0,
			_final_settlement_presentation_count - 1
		),
		"track_validation": _track_core.call("validation_report_v1") \
			if _track_core != null else {},
		"asset_validation": ASSET_BATCH_CORE.validation_report(_asset_state) \
			if not _asset_state.is_empty() else {},
		"facility_validation": FACILITY_CORE.validation_report(_facility_state) \
			if not _facility_state.is_empty() else {},
		"solar_validation": SOLAR_VICTORY_CORE.is_valid_state(_solar_state),
	}


func _process_submission() -> void:
	if not _ai_submission_started:
		_ai_submission_started = true
		for actor_id in _player_ids:
			if actor_id == _local_player_id:
				continue
			var ai_receipt := _auto_queue_and_lock(actor_id)
			if not bool(ai_receipt.get("accepted", false)):
				_fail("ai_submission_failed", {
					"actor_id": actor_id,
					"receipt": ai_receipt,
				})
				return
	if _automate_local_human and not bool(
		_locked_by_player.get(_local_player_id, false)
	):
		var local_receipt := _auto_queue_and_lock(_local_player_id)
		if not bool(local_receipt.get("accepted", false)):
			_fail("automated_local_submission_failed", {
				"receipt": local_receipt,
			})
			return
	if _clock_msec < _submission_deadline_msec:
		return

	var observed_clock_msec := _clock_msec
	_clock_msec = _submission_deadline_msec
	for actor_id in _player_ids:
		if bool(_locked_by_player.get(actor_id, false)):
			continue
		var deadline_receipt := _auto_queue_and_lock(actor_id)
		if not bool(deadline_receipt.get("accepted", false)):
			_clock_msec = observed_clock_msec
			_fail("submission_deadline_autofinalize_failed", {
				"actor_id": actor_id,
				"receipt": deadline_receipt,
			})
			return
	_clock_msec = observed_clock_msec
	if _phase == "submission":
		_fail("submission_deadline_autofinalize_incomplete", {
			"unlocked_player_ids": _unlocked_player_ids(),
		})


func _process_maintenance() -> void:
	for actor_id in _player_ids:
		if actor_id == _local_player_id and not _automate_local_human:
			continue
		if not bool(_maintenance_done.get(actor_id, false)):
			_auto_maintenance(actor_id)


func _auto_queue_and_lock(actor_id: String) -> Dictionary:
	if bool(_locked_by_player.get(actor_id, false)):
		return {
			"accepted": true,
			"reason_code": "submission_already_locked",
			"actor_id": actor_id,
		}
	var queue := _queued_by_player.get(actor_id, []) as Array
	if queue.is_empty():
		var acquisition_receipt := _auto_acquire_track_item(actor_id)
		if not bool(acquisition_receipt.get("accepted", false)):
			return acquisition_receipt
		var legal: Array = []
		if actor_id == _local_player_id:
			legal = legal_card_actions(actor_id)
		else:
			var observation := ai_observation(actor_id)
			if observation.is_empty():
				return {
					"accepted": false,
					"reason_code": "canonical_ai_observation_failed",
					"actor_id": actor_id,
				}
			legal = (
				observation.get("legal_actions", []) as Array
			).duplicate(true)
		if not legal.is_empty():
			var preferred := legal[0] as Dictionary
			for option_variant in legal:
				var option := option_variant as Dictionary
				if str(option.get("region_id", "")) == REGION_IDS[0] \
						and str(option.get("industry_id", "")) == COLORS[0]:
					preferred = option
					break
			var queue_receipt := queue_card_action(
				actor_id,
				str(preferred.get("card_instance_id", "")),
				str(preferred.get("target_slot_id", ""))
			)
			if not bool(queue_receipt.get("accepted", false)):
				return queue_receipt
	return lock_player_submission(actor_id)


func _auto_acquire_track_item(actor_id: String) -> Dictionary:
	var track_projection := _track_core.call("player_projection_v1", actor_id) as Dictionary
	var private_facts := track_projection.get("viewer_private_facts", {}) as Dictionary
	for item_variant in private_facts.get("own_segment_items", []) as Array:
		var item := item_variant as Dictionary
		if not bool(item.get("claimable", false)):
			continue
		var acquired := acquire_track_item(actor_id, str(item.get("instance_id", "")))
		if bool(acquired.get("accepted", false)):
			return acquired
		return acquired
	return {
		"accepted": true,
		"reason_code": "no_claimable_track_item",
		"actor_id": actor_id,
	}


func _unlocked_player_ids() -> Array[String]:
	var result: Array[String] = []
	for actor_id in _player_ids:
		if not bool(_locked_by_player.get(actor_id, false)):
			result.append(actor_id)
	return result


func _auto_maintenance(actor_id: String) -> void:
	var dbg_projection := _dbg_projection(actor_id)
	var dbg_facts := dbg_projection.get("facts", {}) as Dictionary
	var pairs := dbg_facts.get("eligible_merge_pairs", []) as Array
	if not pairs.is_empty() and absi(actor_id.hash()) % 2 == 0:
		var pair := pairs[0] as Array
		if pair.size() == 2:
			merge_normal_pair(actor_id, str(pair[0]), str(pair[1]))
	finish_maintenance(actor_id)


func _begin_batch() -> void:
	_batch_number += 1
	_phase = "submission"
	_ai_submission_started = false
	_opened_at_msec = _clock_msec
	_submission_deadline_msec = _opened_at_msec + SUBMISSION_WINDOW_MSEC
	_hidden_order = _rotated_player_order(_batch_number - 1)
	_asset_state = ASSET_BATCH_CORE.create_state(
		_batch_id(),
		_player_ids,
		_hidden_order,
		_asset_balances,
		{},
		_opened_at_msec,
		ASSET_BATCH_CORE.DEFAULT_GDP_MILLI_PER_ASSET
	)
	if _asset_state.is_empty():
		_fail("asset_batch_start_rejected", {})
		return
	var idle_facility_queues := {}
	for preview_actor_id in _player_ids:
		idle_facility_queues[preview_actor_id] = []
	_facility_state = FACILITY_CORE.lock_batch(
		_batch_id(),
		_player_ids,
		_hidden_order,
		idle_facility_queues,
		_facility_slots
	)
	if _facility_state.is_empty():
		_fail("facility_batch_preview_rejected", {})
		return
	_queued_by_player = {}
	_locked_by_player = {}
	_maintenance_done = {}
	for actor_id in _player_ids:
		_queued_by_player[actor_id] = []
		_locked_by_player[actor_id] = false
		_maintenance_done[actor_id] = false
		var increase_index := posmod(actor_id.hash() + _batch_number, COLORS.size())
		var decrease_index := posmod(increase_index + 3, COLORS.size())
		if actor_id != _local_player_id or _automate_local_human:
			set_track_stance(actor_id, COLORS[increase_index], COLORS[decrease_index])
	_emit_local_state()


func _begin_resolution() -> void:
	var facility_queues := {}
	for actor_id in _player_ids:
		var rows: Array = []
		for binding_variant in _queued_by_player.get(actor_id, []) as Array:
			rows.append(
				((binding_variant as Dictionary).get("facility_action", {}) as Dictionary)
					.duplicate(true)
			)
		facility_queues[actor_id] = rows
	_facility_state = FACILITY_CORE.lock_batch(
		_batch_id(),
		_player_ids,
		_hidden_order,
		facility_queues,
		_facility_slots
	)
	if _facility_state.is_empty():
		_fail("facility_batch_lock_failed", {})
		return
	_phase = "resolving"
	if str(_facility_state.get("status", "")) == "resolved":
		_complete_batch_resolution()
	else:
		_emit_local_state()


func _complete_batch_resolution() -> void:
	var local_assets_before := _local_asset_balances()
	var refreshed := ASSET_BATCH_CORE.refresh_assets_after_batch(_asset_state)
	if not bool(refreshed.get("accepted", false)):
		_fail("asset_refresh_failed", refreshed)
		return
	_asset_state = (refreshed.get("state", {}) as Dictionary).duplicate(true)
	_sync_asset_balances()
	_emit_local_asset_refresh_observation(local_assets_before)
	var completion_receipt := (
		refreshed.get("receipt", {}) as Dictionary
	).duplicate(true)
	if completion_receipt.is_empty():
		_fail("asset_completion_receipt_missing", {})
		return
	var boundary_intent := _track_core.call(
		"build_intent_v1",
		"intent.track.batch_boundary.%d" % _batch_number,
		"system",
		TRACK_CORE.ACTION_COMMIT_BATCH_BOUNDARY,
		{"completed_batch_receipt": completion_receipt}
	) as Dictionary
	var boundary_receipt := _track_core.call(
		"apply_intent_v1",
		boundary_intent
	) as Dictionary
	if not bool(boundary_receipt.get("accepted", false)):
		_fail("track_batch_boundary_failed", boundary_receipt)
		return
	for actor_id in _player_ids:
		var dbg := _dbg_by_player.get(actor_id) as RefCounted
		var intent := dbg.call(
			"create_authority_intent",
			"intent.dbg.complete.%s.%d" % [actor_id, _batch_number],
			DBG_CORE.ACTION_COMPLETE_BATCH,
			{}
		) as Dictionary
		var receipt := dbg.call("apply_intent", intent) as Dictionary
		if not bool(receipt.get("success", false)):
			_fail("dbg_batch_completion_failed", receipt)
			return
	_update_region_solar()
	_phase = "maintenance"
	_emit_local_state()


func _local_asset_balances() -> Dictionary:
	if _asset_state.is_empty():
		return {}
	var players := _asset_state.get("players", {}) as Dictionary
	var local_player := players.get(_local_player_id, {}) as Dictionary
	return (
		local_player.get("assets", {}) as Dictionary
	).duplicate(true)


func _emit_local_asset_refresh_observation(before_assets: Dictionary) -> void:
	var players := _asset_state.get("players", {}) as Dictionary
	var local_player := players.get(_local_player_id, {}) as Dictionary
	var after_assets := local_player.get("assets", {}) as Dictionary
	var overflow := local_player.get("refresh_overflow", {}) as Dictionary
	var refresh_count := 0
	var overflow_total := 0
	var safe_overflow := {}
	for color in COLORS:
		refresh_count += maxi(
			0,
			int(after_assets.get(color, 0)) - int(before_assets.get(color, 0))
		)
		var overflow_count := maxi(0, int(overflow.get(color, 0)))
		safe_overflow[color] = overflow_count
		overflow_total += overflow_count
	playtest_observation_ready.emit({
		"schema": "V073PlaytestObservationReceiptV1",
		"event_type": "asset_refresh",
		"payload": {"count": refresh_count},
	})
	if overflow_total > 0:
		playtest_observation_ready.emit({
			"schema": "V073PlaytestObservationReceiptV1",
			"event_type": "asset_cap_overflow",
			"payload": {
				"count": overflow_total,
				"overflow_by_color": safe_overflow,
			},
		})


func _finish_macro_boundary() -> void:
	var qualifies := _public_progress_points >= _victory_target()
	var macro_round_complete := _batch_number >= _player_ids.size()
	if qualifies and macro_round_complete:
		_commit_victory()
		return
	var advance_intent := _track_core.call(
		"build_intent_v1",
		"intent.track.advance.%d" % _batch_number,
		"system",
		TRACK_CORE.ACTION_ADVANCE_TRACK,
		{"steps": 1}
	) as Dictionary
	var advanced := _track_core.call("apply_intent_v1", advance_intent) as Dictionary
	if not bool(advanced.get("accepted", false)):
		_fail("track_advance_failed", advanced)
		return
	_begin_batch()


func _commit_victory() -> void:
	var condition_id := "v073.public_facility_network_threshold"
	var source_revision := _public_progress_points
	var qualification_proof := _victory_authority.issue_qualification(
		_solar_state,
		"proof.qualification.%s" % _match_id,
		condition_id,
		true,
		source_revision
	)
	var qualification_intent := {
		"schema_version": SOLAR_VICTORY_CORE.SCHEMA_VERSION,
		"intent_id": "intent.victory.qualification.%s" % _match_id,
		"intent_kind_id": SOLAR_VICTORY_CORE.INTENT_KIND_QUALIFICATION,
		"expected_revision": int(_solar_state.get("revision", 0)),
		"condition_id": condition_id,
		"proof_id": str(qualification_proof.get("proof_id", "")),
		"proof_fingerprint": str(
			qualification_proof.get("proof_fingerprint", "")
		),
	}
	var pending := SOLAR_VICTORY_CORE.submit_victory_qualification(
		_solar_state,
		qualification_intent,
		_victory_authority,
		_victory_authority.capability()
	)
	if not bool((pending.get("receipt", {}) as Dictionary).get("committed", false)):
		_fail("victory_qualification_failed", pending)
		return
	_solar_state = (pending.get("state", {}) as Dictionary).duplicate(true)
	var settlement_id := "settlement.%s" % _match_id
	var boundary := {
		"submission_window_locked": true,
		"batch_complete": true,
		"asset_refresh_complete": true,
		"hand_maintenance_complete": true,
		"macro_round_complete": true,
		"every_player_led_once": _batch_number >= _player_ids.size(),
	}
	if not bool(boundary.get("every_player_led_once", false)):
		_begin_batch()
		return
	var boundary_proof := _victory_authority.issue_boundary(
		_solar_state,
		"proof.boundary.%s" % _match_id,
		boundary,
		true,
		settlement_id,
		source_revision + 1
	)
	var gate := _solar_state.get("victory_gate", {}) as Dictionary
	var boundary_intent := {
		"schema_version": SOLAR_VICTORY_CORE.SCHEMA_VERSION,
		"intent_id": "intent.victory.boundary.%s" % _match_id,
		"intent_kind_id": SOLAR_VICTORY_CORE.INTENT_KIND_REVALIDATION,
		"expected_revision": int(_solar_state.get("revision", 0)),
		"condition_id": str(gate.get("pending_condition_id", "")),
		"macro_round_index": int(gate.get("macro_round_index", 1)),
		"proof_id": str(boundary_proof.get("proof_id", "")),
		"proof_fingerprint": str(boundary_proof.get("proof_fingerprint", "")),
	}
	var settled := SOLAR_VICTORY_CORE.revalidate_victory_at_boundary(
		_solar_state,
		boundary_intent,
		_victory_authority,
		_victory_authority.capability()
	)
	var settled_receipt := settled.get("receipt", {}) as Dictionary
	if not bool(settled_receipt.get("committed", false)):
		_fail("victory_boundary_failed", settled)
		return
	_solar_state = (settled.get("state", {}) as Dictionary).duplicate(true)
	_final_settlement = _build_final_settlement(settlement_id)
	_phase = "settled"
	_final_settlement_presentation_count += 1
	_final_settlement_public_log_count += 1
	_public_history.append({
		"accepted": true,
		"outcome_id": "final_settlement",
		"reason_code": "final_settlement_committed_exact_once",
		"settlement_id": settlement_id,
	})
	final_settlement_committed.emit(_final_settlement.duplicate(true))
	_emit_local_state()


func _build_bound_actions(
	actor_id: String,
	binding: Dictionary,
	local_index: int
) -> Dictionary:
	var card := _card_in_hand(actor_id, str(binding.get("card_instance_id", "")))
	var slot := _slot_by_id(str(binding.get("target_slot_id", "")))
	if card.is_empty() or slot.is_empty() 			or not _legal_slot_for_card(actor_id, card, slot) 			or not _binding_matches_slot(binding, slot):
		return {}
	var action_id := str(binding.get("action_id", ""))
	var cost := _zero_colors()
	cost["any"] = 0
	var primary_color := str(card.get("primary_color", ""))
	if primary_color not in COLORS:
		return {}
	cost[primary_color] = int(card.get("primary_asset_cost", 0))
	var reserved_assets := _zero_colors()
	reserved_assets[primary_color] = int(card.get("primary_asset_cost", 0))
	var target_binding := ASSET_BATCH_CORE.build_target_binding(
		"binding.%s" % action_id,
		[str(slot.get("slot_id", ""))],
		int(slot.get("region_revision", 0))
	)
	var asset_action := ASSET_BATCH_CORE.build_prebound_action(
		action_id,
		"normal_card",
		str(card.get("instance_id", "")),
		local_index,
		str(card.get("definition_id", "")),
		target_binding,
		"facility.%s" % _facility_mode(actor_id, slot).to_lower(),
		cost,
		_zero_colors()
	)
	var facility_action: Dictionary
	match _facility_mode(actor_id, slot):
		"BUILD_NEW":
			facility_action = FACILITY_CORE.build_new_action(
				action_id,
				str(card.get("instance_id", "")),
				actor_id,
				local_index,
				slot,
				reserved_assets,
				str(card.get("origin_class", "standard"))
			)
		"UPGRADE_OWN":
			facility_action = FACILITY_CORE.build_upgrade_action(
				action_id,
				str(card.get("instance_id", "")),
				actor_id,
				local_index,
				slot,
				reserved_assets,
				str(card.get("origin_class", "standard"))
			)
		"REPAIR_OWN":
			facility_action = FACILITY_CORE.build_repair_action(
				action_id,
				str(card.get("instance_id", "")),
				actor_id,
				local_index,
				slot,
				reserved_assets,
				str(card.get("origin_class", "standard"))
			)
	if asset_action.is_empty() or facility_action.is_empty():
		return {}
	return {"asset_action": asset_action, "facility_action": facility_action}


func _binding_matches_slot(binding: Dictionary, slot: Dictionary) -> bool:
	return str(binding.get("target_region_id", "")) == str(slot.get("region_id", "")) 		and int(binding.get("target_revision", -1)) 			== int(slot.get("region_revision", -2)) 		and int(binding.get("target_slot_generation", -1)) 			== int(slot.get("slot_generation", -2)) 		and str(binding.get("facility_action_mode", "")) 			== _facility_mode(str(binding.get("actor_id", "")), slot) 		and binding.get("expected_facility_id") == slot.get("facility_id") 		and binding.get("expected_facility_generation") 			== slot.get("facility_generation") 		and binding.get("expected_owner_id") == slot.get("owner_id") 		and binding.get("expected_rank") == slot.get("rank") 		and binding.get("expected_damage_revision") 			== slot.get("damage_revision")


func _legal_slots_for_card(actor_id: String, card: Dictionary) -> Array:
	var result: Array = []
	for slot_variant in _facility_slots:
		var slot := slot_variant as Dictionary
		if _legal_slot_for_card(actor_id, card, slot):
			result.append(slot.duplicate(true))
	return result


func _legal_slot_for_card(
	actor_id: String,
	card: Dictionary,
	slot: Dictionary
) -> bool:
	if str(card.get("card_type", "")) != str(slot.get("facility_type", "")):
		return false
	if str(card.get("primary_color", "")) != str(slot.get("industry_id", "")):
		return false
	var occupancy := str(slot.get("occupancy", ""))
	if occupancy == "empty":
		return true
	if str(slot.get("owner_id", "")) != actor_id:
		return false
	return int(slot.get("damage_points", 0)) > 0 \
		or int(slot.get("rank", 0)) < FACILITY_CORE.MAX_FACILITY_RANK


func _facility_mode(actor_id: String, slot: Dictionary) -> String:
	if str(slot.get("occupancy", "")) == "empty":
		return "BUILD_NEW"
	if str(slot.get("owner_id", "")) != actor_id:
		return ""
	if int(slot.get("damage_points", 0)) > 0:
		return "REPAIR_OWN"
	if int(slot.get("rank", 0)) < FACILITY_CORE.MAX_FACILITY_RANK:
		return "UPGRADE_OWN"
	return ""


func _build_genesis_facility_slots() -> Array:
	var result: Array = []
	for region_id in REGION_IDS:
		for facility_type in FACILITY_CORE.FACILITY_TYPES:
			for industry_id in COLORS:
				result.append(FACILITY_CORE.build_empty_slot(
					region_id,
					0,
					facility_type,
					industry_id,
					0
				))
	return result


func _initialize_region_solar() -> void:
	_region_sunlit = {}
	for index in range(REGION_IDS.size()):
		_region_sunlit[REGION_IDS[index]] = index < 3


func _update_region_solar() -> void:
	for index in range(REGION_IDS.size()):
		_region_sunlit[REGION_IDS[index]] = posmod(index + _batch_number, 2) == 0
	var alpha_sunlit := bool(_region_sunlit.get(REGION_IDS[0], false))
	var intent := {
		"schema_version": SOLAR_VICTORY_CORE.SCHEMA_VERSION,
		"intent_id": "intent.solar.%d" % _batch_number,
		"intent_kind_id": SOLAR_VICTORY_CORE.INTENT_KIND_SOLAR,
		"expected_revision": int(_solar_state.get("revision", 0)),
		"sunlit": alpha_sunlit,
		"source_revision": _batch_number,
	}
	var outcome := SOLAR_VICTORY_CORE.apply_solar_intent(_solar_state, intent)
	if not outcome.is_empty():
		_solar_state = (outcome.get("state", {}) as Dictionary).duplicate(true)


func _completed_gdp_milli(actor_id: String) -> Dictionary:
	var result := _zero_colors()
	for slot_variant in _facility_slots:
		var slot := slot_variant as Dictionary
		if str(slot.get("occupancy", "")) != "occupied" \
				or str(slot.get("owner_id", "")) != actor_id:
			continue
		var color := str(slot.get("industry_id", ""))
		var region_id := str(slot.get("region_id", ""))
		var multiplier := SOLAR_VICTORY_CORE.solar_multiplier(
			bool(_region_sunlit.get(region_id, false))
		)
		result[color] = int(result.get(color, 0)) + int(round(1000.0 * multiplier))
	return result


func _sync_asset_balances() -> void:
	for actor_id in _player_ids:
		var projection := ASSET_BATCH_CORE.player_projection(_asset_state, actor_id)
		_asset_balances[actor_id] = (
			projection.get("own_assets", {}) as Dictionary
		).duplicate(true)


func _sync_facility_slots() -> void:
	var slots := _facility_state.get("facility_slots", {}) as Dictionary
	var ids: Array[String] = []
	for id_variant in slots.keys():
		ids.append(str(id_variant))
	ids.sort()
	_facility_slots = []
	for slot_id in ids:
		_facility_slots.append((slots.get(slot_id, {}) as Dictionary).duplicate(true))


func _asset_completion_receipt() -> Dictionary:
	for index in range((_asset_state.get("receipts", []) as Array).size() - 1, -1, -1):
		var receipt := (_asset_state.get("receipts", []) as Array)[index] as Dictionary
		if str(receipt.get("operation_id", "")) == "refresh_assets_after_batch":
			return receipt.duplicate(true)
	return {}


func _source_card_id_for_action(actor_id: String, action_id: String) -> String:
	for row_variant in _queued_by_player.get(actor_id, []) as Array:
		var row := row_variant as Dictionary
		if str(row.get("action_id", "")) == action_id:
			return str(row.get("card_instance_id", ""))
	return ""


func _card_in_hand(actor_id: String, card_instance_id: String) -> Dictionary:
	var facts := (_dbg_projection(actor_id).get("facts", {}) as Dictionary)
	for card_variant in facts.get("hand", []) as Array:
		var card := card_variant as Dictionary
		if str(card.get("instance_id", "")) == card_instance_id:
			return card.duplicate(true)
	return {}


func _dbg_projection(actor_id: String) -> Dictionary:
	var dbg := _dbg_by_player.get(actor_id) as RefCounted
	return dbg.call("player_projection", actor_id) as Dictionary if dbg != null else {}


func _slot_by_id(slot_id: String) -> Dictionary:
	for slot_variant in _facility_slots:
		var slot := slot_variant as Dictionary
		if str(slot.get("slot_id", "")) == slot_id:
			return slot.duplicate(true)
	return {}


func _legal_targets_by_card(actor_id: String) -> Dictionary:
	var result := {}
	var authority := (
		(_dbg_by_player.get(actor_id) as RefCounted).call("core_authority_snapshot")
	) as Dictionary
	var state := authority.get("state", {}) as Dictionary
	for zone_name in ["hand", "discard"]:
		for card_variant in state.get(zone_name, []) as Array:
			var card := card_variant as Dictionary
			var targets: Array[String] = []
			for slot_variant in _legal_slots_for_card(actor_id, card):
				targets.append(str((slot_variant as Dictionary).get("slot_id", "")))
			result[str(card.get("instance_id", ""))] = targets
	return result


func _public_facility_slots() -> Array:
	var result: Array = []
	for slot_variant in _facility_slots:
		var slot := slot_variant as Dictionary
		result.append({
			"slot_id": str(slot.get("slot_id", "")),
			"region_id": str(slot.get("region_id", "")),
			"facility_type": str(slot.get("facility_type", "")),
			"industry_id": str(slot.get("industry_id", "")),
			"occupancy": str(slot.get("occupancy", "")),
			"owner_id": str(slot.get("owner_id", "")),
			"rank": int(slot.get("rank", 0)),
			"damage_points": int(slot.get("damage_points", 0)),
		})
	return result


func _public_roster(viewer_id: String) -> Array:
	var result: Array = []
	for index in range(_player_ids.size()):
		var player_id := _player_ids[index]
		result.append({
			"player_id": player_id,
			"display_name": "指挥官" if player_id == _local_player_id \
				else "AI %d" % index,
			"public_order_index": index,
			"is_local_player": player_id == viewer_id,
			"is_ai": player_id != _local_player_id,
			"public_status": "active" if _phase != "settled" else "ready",
			"submission_lock_public_state": "locked" \
				if bool(_locked_by_player.get(player_id, false)) else "unlocked",
			"facility_count": _facility_count_for(player_id),
		})
	return result


func _facility_count_for(actor_id: String) -> int:
	var count := 0
	for slot_variant in _facility_slots:
		var slot := slot_variant as Dictionary
		if str(slot.get("occupancy", "")) == "occupied" \
				and str(slot.get("owner_id", "")) == actor_id:
			count += 1
	return count


func _region_solar_projection() -> Array:
	var result: Array = []
	for region_id in REGION_IDS:
		var sunlit := bool(_region_sunlit.get(region_id, false))
		result.append({
			"region_id": region_id,
			"sunlit": sunlit,
			"facility_efficiency_multiplier": SOLAR_VICTORY_CORE.solar_multiplier(sunlit),
			"unified_track_supply_affected": false,
		})
	return result


func _special_actions_for_viewer(viewer_id: String) -> Array:
	if _batch_number < 2:
		return []
	return [{
		"instance_id": "special.support.%s" % viewer_id,
		"kind": "special_action",
		"source": "army_or_monster",
		"counts_toward_normal_hand_limit": false,
		"submission_contract": "v073.prebound_target.full_reservation",
		"available": false,
	}]


func _build_final_settlement(settlement_id: String) -> Dictionary:
	var standings: Array = []
	for index in range(_player_ids.size()):
		var actor_id := _player_ids[index]
		var assets := _asset_balances.get(actor_id, {}) as Dictionary
		var asset_total := 0
		for color in COLORS:
			asset_total += int(assets.get(color, 0))
		standings.append({
			"player_id": actor_id,
			"display_name": "指挥官" if actor_id == _local_player_id \
				else "AI %d" % index,
			"facility_count": _facility_count_for(actor_id),
			"asset_total": asset_total,
			"public_order_index": index,
		})
	standings.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if int(left.get("facility_count", 0)) != int(right.get("facility_count", 0)):
			return int(left.get("facility_count", 0)) > int(right.get("facility_count", 0))
		if int(left.get("asset_total", 0)) != int(right.get("asset_total", 0)):
			return int(left.get("asset_total", 0)) > int(right.get("asset_total", 0))
		return int(left.get("public_order_index", 0)) < int(right.get("public_order_index", 0))
	)
	for index in range(standings.size()):
		(standings[index] as Dictionary)["rank"] = index + 1
	return {
		"ruleset_id": RULESET_ID,
		"settlement_id": settlement_id,
		"title": "Final Settlement",
		"winner_player_id": str((standings[0] as Dictionary).get("player_id", "")),
		"standings": standings,
		"public_progress_points": _public_progress_points,
		"batch_count": _batch_number,
		"settlement_count": 1,
		"presentation_count": 1,
		"public_log_count": 1,
	}


func _victory_target() -> int:
	return maxi(6, _player_ids.size() * PUBLIC_PROGRESS_PER_PLAYER_TARGET)


func _rotated_player_order(offset: int) -> Array[String]:
	var result: Array[String] = []
	for index in range(_player_ids.size()):
		result.append(_player_ids[posmod(index + offset, _player_ids.size())])
	return result


func _all_players_locked() -> bool:
	for actor_id in _player_ids:
		if not bool(_locked_by_player.get(actor_id, false)):
			return false
	return true


func _all_maintenance_done() -> bool:
	for actor_id in _player_ids:
		if not bool(_maintenance_done.get(actor_id, false)):
			return false
	return true


func _batch_id() -> String:
	return "batch.%s.%04d" % [_match_id, _batch_number]


func _zero_colors() -> Dictionary:
	return {
		"life": 0,
		"energy": 0,
		"industry": 0,
		"technology": 0,
		"commerce": 0,
		"shipping": 0,
	}


func _reset_runtime() -> void:
	_track_core = null
	_asset_core = ASSET_BATCH_CORE.new()
	_time_authority = TrustedTimeAuthority.new()
	_victory_authority = null
	_dbg_by_player = {}
	_cash_by_player = {}
	_track_port = null
	_acquisition_routers = {}
	_player_ids = []
	_match_id = ""
	_phase = "idle"
	_batch_number = 0
	_clock_msec = 0
	_opened_at_msec = 0
	_submission_deadline_msec = 0
	_hidden_order = []
	_asset_state = {}
	_asset_balances = {}
	_facility_state = {}
	_facility_slots = []
	_solar_state = {}
	_region_sunlit = {}
	_queued_by_player = {}
	_locked_by_player = {}
	_maintenance_done = {}
	_public_history = []
	_public_progress_points = 0
	_final_settlement = {}
	_ai_submission_started = false
	_runtime_error_count = 0
	_invalid_action_count = 0
	_invalid_action_reasons = {}
	_nonfinite_count = 0
	_hidden_info_violation_count = 0
	_dual_authority_count = 0
	_final_settlement_presentation_count = 0
	_final_settlement_public_log_count = 0
	_canonical_player_projection_count = 0
	_canonical_ai_observation_count = 0
	_adapter_failure_count = 0
	_projection_emit_coalesced = false
	_projection_emit_pending = false


func _emit_local_state() -> void:
	if _projection_emit_coalesced:
		_projection_emit_pending = true
		return
	if _player_ids.has(_local_player_id):
		state_changed.emit(player_snapshot(_local_player_id))


func _fail(reason_code: String, detail: Dictionary) -> Dictionary:
	_runtime_error_count += 1
	_phase = "failed"
	var receipt := {
		"accepted": false,
		"reason_code": reason_code,
		"detail": detail.duplicate(true),
	}
	runtime_fault.emit(receipt)
	return receipt


func _reject(reason_code: String) -> Dictionary:
	return {"accepted": false, "reason_code": reason_code}


func _reject_action(reason_code: String) -> Dictionary:
	_invalid_action_count += 1
	_invalid_action_reasons[reason_code] = int(
		_invalid_action_reasons.get(reason_code, 0)
	) + 1
	return {"accepted": false, "reason_code": reason_code}
