extends RefCounted
class_name V07TrackAcquisitionAuthorityPort

const TrackCore := preload("res://scripts/v07_semantic/v07_unified_card_track_core.gd")

const SCHEMA_VERSION := 2
const RULESET_ID := "v0.7.2"
const DOMAIN_ID := "unified_card_track"
const INTERFACE_ID := "v072.unified_track.acquisition_authority_port.v3"
const PARTICIPANT_REQUEST_INTERFACE_ID := (
	"v072.unified_track.acquisition_participant_request.v3"
)
const COMPOSITE_RECEIPT_INTERFACE_ID := (
	"v072.unified_track.acquisition_composite_receipt.v3"
)
const RECEIPT_JOURNAL_INTERFACE_ID := (
	"v072.unified_track.acquisition_receipt_journal.v3"
)
const ROLLBACK_RECOVERY_INTERFACE_ID := (
	"v072.unified_track.acquisition_rollback_recovery.v3"
)

const PARTICIPANT_ROLES := ["cash", "personal_discard", "commodity_slot"]
const PARTICIPANT_METHODS := [
	"acquisition_authority_id_v1",
	"prepare_acquisition_v1",
	"commit_prepared_acquisition_v1",
	"abort_prepared_acquisition_v1",
	"capture_checkpoint_v1",
	"rollback_v1",
]
const COMPOSITE_RECEIPT_FIELDS := [
	"schema_version",
	"interface_id",
	"ruleset_id",
	"domain_id",
	"transaction_id",
	"request_id",
	"intent_fingerprint",
	"action_id",
	"accepted",
	"reason_code",
	"source_revision",
	"result_revision",
	"destination_zone",
	"track_receipt",
	"participant_commits",
	"external_participants_finalized",
	"receipt_fingerprint",
]
const PARTICIPANT_RECEIPT_BINDING_FIELDS := [
	"accepted",
	"reason_code",
	"transaction_id",
	"reservation_id",
	"authority_id",
	"participant_role",
	"receipt_fingerprint",
]
const PARTICIPANT_COMMIT_FIELDS := [
	"transaction_id",
	"request_id",
	"participant_role",
	"authority_id",
	"reservation_id",
	"participant_receipt_fingerprint",
	"finalize_count",
]
const RECEIPT_JOURNAL_FIELDS := [
	"schema_version",
	"interface_id",
	"ruleset_id",
	"domain_id",
	"match_instance_id",
	"authority_binding_fingerprint",
	"composite_receipts",
	"journal_fingerprint",
]
const RECOVERY_HANDLE_FIELDS := [
	"schema_version",
	"interface_id",
	"ruleset_id",
	"domain_id",
	"transaction_id",
	"request_id",
	"intent_fingerprint",
	"status",
	"failure_reason_code",
	"track_rollback_required",
	"failed_components",
	"recovery_attempt_count",
	"recovery_fingerprint",
]

var _track_authority: RefCounted = null
var _participants: Dictionary = {}
var _track_instance_id := 0
var _participant_bindings: Dictionary = {}
var _transactions: Dictionary = {}
var _transaction_receipts: Dictionary = {}
var _request_transactions: Dictionary = {}
var _transaction_history: Dictionary = {}
var _configured := false


func _init(
	track_authority: RefCounted = null,
	participants: Dictionary = {}
) -> void:
	if track_authority != null:
		configure_v1(track_authority, participants)


func configure_v1(
	track_authority: RefCounted,
	participants: Dictionary
) -> Dictionary:
	if _configured:
		return _result(false, "acquisition_port_already_configured")
	if track_authority == null:
		return _result(false, "track_authority_missing")
	for method_name in [
		"bind_acquisition_authority_port_v1",
		"prepare_visible_acquisition_v1",
		"register_prepared_acquisition_transaction_v1",
		"abort_prepared_acquisition_transaction_v1",
		"commit_prepared_acquisition_v1",
		"rollback_acquisition_transaction_v1",
		"finalize_acquisition_transaction_v1",
		"acquisition_transaction_status_v1",
		"authoritative_receipt_v1",
		"core_authority_v1",
	]:
		if not track_authority.has_method(method_name):
			return _result(false, "track_authority_contract_invalid")
	if not _same_string_set(participants.keys(), PARTICIPANT_ROLES):
		return _result(false, "participant_role_set_invalid")
	var accepted_participants: Dictionary = {}
	var participant_bindings: Dictionary = {}
	for role in PARTICIPANT_ROLES:
		var participant_variant: Variant = participants.get(role)
		if not (participant_variant is RefCounted):
			return _result(false, "participant_missing.%s" % role)
		var participant := participant_variant as RefCounted
		for method_name in PARTICIPANT_METHODS:
			if not participant.has_method(method_name):
				return _result(false, "participant_contract_invalid.%s" % role)
		var authority_id_variant: Variant = participant.call(
			"acquisition_authority_id_v1"
		)
		if not _is_stable_id(authority_id_variant) \
			or str(authority_id_variant) == "authority.none":
			return _result(false, "participant_authority_id_invalid.%s" % role)
		accepted_participants[role] = participant
		participant_bindings[role] = {
			"instance_id": participant.get_instance_id(),
			"authority_id": str(authority_id_variant),
		}
	_track_authority = track_authority
	_track_instance_id = track_authority.get_instance_id()
	_participants = accepted_participants
	_participant_bindings = participant_bindings
	var binding_variant: Variant = track_authority.call(
		"bind_acquisition_authority_port_v1",
		self
	)
	if not (binding_variant is Dictionary) \
		or not bool((binding_variant as Dictionary).get("accepted", false)):
		_track_authority = null
		_track_instance_id = 0
		_participants = {}
		_participant_bindings = {}
		return _result(false, "track_authority_port_binding_rejected")
	_configured = true
	return _result(true, "acquisition_port_configured")


func is_configured() -> bool:
	return _configured and _track_authority != null


func acquisition_port_contract_v1() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"interface_id": INTERFACE_ID,
		"ruleset_id": RULESET_ID,
		"domain_id": DOMAIN_ID,
		"participant_roles": PARTICIPANT_ROLES.duplicate(),
		"caller_supplied_receipts_trusted": false,
		"transaction_owned_rollback_required": true,
		"receipt_journal_capture_apply_supported": true,
		"object_identity_pinned_until_port_replacement": true,
		"production_runtime_connected": false,
	}


func track_authority_v1() -> RefCounted:
	return _track_authority


func prepare_v1(track_intent: Dictionary) -> Dictionary:
	if not is_configured():
		return _prepare_result(false, "acquisition_port_not_configured")
	var integrity_error := _configuration_integrity_error()
	if not integrity_error.is_empty():
		return _prepare_result(false, integrity_error)
	var request_id := str(track_intent.get("request_id", ""))
	var intent_fingerprint := str(track_intent.get("intent_fingerprint", ""))
	if _request_transactions.has(request_id):
		var existing_transaction_id := str(_request_transactions.get(request_id, ""))
		if _transaction_receipts.has(existing_transaction_id):
			var receipt := _transaction_receipts.get(
				existing_transaction_id, {}
			) as Dictionary
			if str(receipt.get("intent_fingerprint", "")) == intent_fingerprint:
				return {
					"accepted": true,
					"prepared": false,
					"already_committed": true,
					"reason_code": "acquisition_already_committed",
					"transaction_id": existing_transaction_id,
					"proposal": {},
				}
			return _prepare_result(false, "request_id_collision")
		if _transactions.has(existing_transaction_id):
			var existing := _transactions.get(existing_transaction_id, {}) as Dictionary
			if str(existing.get("intent_fingerprint", "")) == intent_fingerprint:
				if str(existing.get("status", "")) == "rollback_failed":
					return _rollback_failure_result(existing)
				return _public_prepared_result(existing)
		return _prepare_result(false, "request_id_collision")

	var prepared_variant: Variant = _track_authority.call(
		"prepare_visible_acquisition_v1",
		track_intent
	)
	if not (prepared_variant is Dictionary):
		return _prepare_result(false, "track_prepare_contract_invalid")
	var prepared := prepared_variant as Dictionary
	if not bool(prepared.get("accepted", false)):
		return _prepare_result(false, str(prepared.get(
			"reason_code", "track_prepare_rejected"
		)))
	var proposal_variant: Variant = prepared.get("proposal")
	if not (proposal_variant is Dictionary):
		return _prepare_result(false, "track_proposal_missing")
	var proposal := (proposal_variant as Dictionary).duplicate(true)
	var transaction_id := _transaction_id(intent_fingerprint)
	if _transactions.has(transaction_id) \
		or _transaction_receipts.has(transaction_id):
		return _prepare_result(false, "transaction_id_collision")
	var requirements_variant: Variant = proposal.get("participant_requirements")
	if not (requirements_variant is Array):
		return _prepare_result(false, "participant_requirements_invalid")
	var requirements := requirements_variant as Array
	var authority_error := _participant_authority_error(requirements)
	if not authority_error.is_empty():
		return _prepare_result(false, authority_error)
	var checkpoint_result := _capture_participant_checkpoints(requirements)
	if not bool(checkpoint_result.get("accepted", false)):
		return _prepare_result(false, str(checkpoint_result.get(
			"reason_code", "participant_checkpoint_failed"
		)))

	var transaction := {
		"transaction_id": transaction_id,
		"request_id": request_id,
		"intent_fingerprint": intent_fingerprint,
		"intent": track_intent.duplicate(true),
		"proposal": proposal,
		"status": "preparing",
		"track_transaction_mode": "none",
		"track_rollback_complete": false,
		"rollback_failure_reason": "",
		"rollback_failed_components": [],
		"rollback_completed_components": [],
		"recovery_attempt_count": 0,
		"participant_checkpoints": checkpoint_result.get("checkpoints", {}),
		"prepared_rows": [],
	}
	for requirement_variant in requirements:
		var requirement := requirement_variant as Dictionary
		var role := str(requirement.get("participant_role", ""))
		var participant := _participants.get(role) as RefCounted
		var participant_request := _participant_request(
			transaction_id,
			proposal,
			requirement
		)
		var prepare_result_variant: Variant = participant.call(
			"prepare_acquisition_v1",
			participant_request
		)
		if not (prepare_result_variant is Dictionary):
			var wrong_type_rollback := _rollback_transaction(
				transaction,
				"participant_prepare_wrong_type.%s" % role
			)
			if not bool(wrong_type_rollback.get("accepted", false)):
				return _rollback_failure_result(transaction)
			return _prepare_result(false, "participant_prepare_wrong_type.%s" % role)
		var prepare_result := prepare_result_variant as Dictionary
		var prepare_receipt_error := _participant_receipt_binding_error(
			prepare_result,
			transaction_id,
			role,
			str(requirement.get("authority_id", "")),
			""
		)
		if not prepare_receipt_error.is_empty():
			var invalid_receipt_rollback := _rollback_transaction(
				transaction,
				"participant_prepare_receipt_invalid.%s.%s" % [
					role,
					prepare_receipt_error,
				]
			)
			if not bool(invalid_receipt_rollback.get("accepted", false)):
				return _rollback_failure_result(transaction)
			return _prepare_result(
				false,
				"participant_prepare_receipt_invalid.%s.%s" % [
					role,
					prepare_receipt_error,
				]
			)
		var reservation_id := str(prepare_result.get("reservation_id", ""))
		(transaction.get("prepared_rows", []) as Array).append({
			"participant_role": role,
			"authority_id": str(requirement.get("authority_id", "")),
			"reservation_id": reservation_id,
			"participant": participant,
		})
		if not bool(prepare_result.get("accepted", false)):
			var rejected_rollback := _rollback_transaction(
				transaction,
				str(prepare_result.get("reason_code", "participant_prepare_rejected"))
			)
			if not bool(rejected_rollback.get("accepted", false)):
				return _rollback_failure_result(transaction)
			return _prepare_result(false, "participant_prepare_rejected.%s.%s" % [
				role,
				str(prepare_result.get("reason_code", "unknown")),
			])

	var revalidated_variant: Variant = _track_authority.call(
		"prepare_visible_acquisition_v1",
		track_intent
	)
	if not (revalidated_variant is Dictionary) \
		or not bool((revalidated_variant as Dictionary).get("accepted", false)) \
		or (revalidated_variant as Dictionary).get("proposal", {}) != proposal:
		var stale_rollback := _rollback_transaction(
			transaction,
			"track_prepare_became_stale"
		)
		if not bool(stale_rollback.get("accepted", false)):
			return _rollback_failure_result(transaction)
		return _prepare_result(false, "track_prepare_became_stale")
	transaction["status"] = "prepared"
	_transactions[transaction_id] = transaction
	_request_transactions[request_id] = transaction_id
	var registration_variant: Variant = _track_authority.call(
		"register_prepared_acquisition_transaction_v1",
		transaction_id,
		self
	)
	if not _operation_accepted(registration_variant):
		var registration_rollback := _rollback_transaction(
			transaction,
			"track_prepared_registration_failed"
		)
		if not bool(registration_rollback.get("accepted", false)):
			return _rollback_failure_result(transaction)
		return _prepare_result(false, "track_prepared_registration_failed")
	transaction["track_transaction_mode"] = "prepared"
	_transactions[transaction_id] = transaction
	return _public_prepared_result(transaction)


func commit_v1(transaction_id: String) -> Dictionary:
	var integrity_error := _configuration_integrity_error()
	if not integrity_error.is_empty():
		return _commit_failure(transaction_id, integrity_error)
	if _transaction_receipts.has(transaction_id):
		return (
			_transaction_receipts.get(transaction_id, {}) as Dictionary
		).duplicate(true)
	if not _transactions.has(transaction_id):
		return _commit_failure(transaction_id, "acquisition_transaction_not_prepared")
	var transaction := _transactions.get(transaction_id, {}) as Dictionary
	if str(transaction.get("status", "")) == "rollback_failed":
		return _rollback_failure_result(transaction)
	if str(transaction.get("status", "")) != "prepared":
		return _commit_failure(transaction_id, "acquisition_transaction_not_prepared")

	var track_receipt_variant: Variant = _track_authority.call(
		"commit_prepared_acquisition_v1",
		transaction_id,
		self
	)
	if not (track_receipt_variant is Dictionary):
		var wrong_type_rollback := _rollback_transaction(
			transaction,
			"track_commit_wrong_type"
		)
		if not bool(wrong_type_rollback.get("accepted", false)):
			return _rollback_failure_result(transaction)
		return _commit_failure(transaction_id, "track_commit_wrong_type")
	var track_receipt := track_receipt_variant as Dictionary
	if not bool(track_receipt.get("accepted", false)):
		var rejected_rollback := _rollback_transaction(
			transaction,
			str(track_receipt.get("reason_code", "track_commit_rejected"))
		)
		if not bool(rejected_rollback.get("accepted", false)):
			return _rollback_failure_result(transaction)
		return _commit_failure(transaction_id, str(track_receipt.get(
			"reason_code", "track_commit_rejected"
		)))
	transaction["status"] = "track_committed"
	transaction["track_transaction_mode"] = "committed"
	transaction["track_rollback_complete"] = false
	_transactions[transaction_id] = transaction
	var authoritative_variant: Variant = _track_authority.call(
		"authoritative_receipt_v1",
		str(transaction.get("request_id", ""))
	)
	if not (authoritative_variant is Dictionary) \
		or authoritative_variant != track_receipt:
		var mismatch_rollback := _rollback_transaction(
			transaction,
			"authoritative_track_receipt_mismatch"
		)
		if not bool(mismatch_rollback.get("accepted", false)):
			return _rollback_failure_result(transaction)
		return _commit_failure(
			transaction_id,
			"authoritative_track_receipt_mismatch"
		)
	var participant_commits: Array = []
	for row_variant in transaction.get("prepared_rows", []) as Array:
		var row := row_variant as Dictionary
		var participant := row.get("participant") as RefCounted
		var commit_result_variant: Variant = participant.call(
			"commit_prepared_acquisition_v1",
			str(row.get("reservation_id", "")),
			track_receipt.duplicate(true)
		)
		var commit_receipt_error := "wrong_type"
		if commit_result_variant is Dictionary:
			commit_receipt_error = _participant_receipt_binding_error(
				commit_result_variant as Dictionary,
				transaction_id,
				str(row.get("participant_role", "")),
				str(row.get("authority_id", "")),
				str(row.get("reservation_id", ""))
			)
			if commit_receipt_error.is_empty() \
				and str((commit_result_variant as Dictionary).get(
					"track_receipt_fingerprint", ""
				)) != str(track_receipt.get("receipt_fingerprint", "")):
				commit_receipt_error = "track_receipt_fingerprint_mismatch"
		if not commit_receipt_error.is_empty() \
			or not bool((commit_result_variant as Dictionary).get("accepted", false)):
			var reason_code := "participant_commit_rejected.%s" % str(
				row.get("participant_role", "")
			)
			if not commit_receipt_error.is_empty():
				reason_code = "participant_commit_receipt_invalid.%s.%s" % [
					str(row.get("participant_role", "")),
					commit_receipt_error,
				]
			var commit_rollback := _rollback_transaction(transaction, reason_code)
			if not bool(commit_rollback.get("accepted", false)):
				return _rollback_failure_result(transaction)
			return _commit_failure(transaction_id, reason_code)
		var commit_result := commit_result_variant as Dictionary
		participant_commits.append({
			"transaction_id": transaction_id,
			"request_id": str(transaction.get("request_id", "")),
			"participant_role": str(row.get("participant_role", "")),
			"authority_id": str(row.get("authority_id", "")),
			"reservation_id": str(row.get("reservation_id", "")),
			"participant_receipt_fingerprint": TrackCore.fingerprint(commit_result),
			"finalize_count": 1,
		})

	var finalize_variant: Variant = _track_authority.call(
		"finalize_acquisition_transaction_v1",
		transaction_id,
		self
	)
	if not (finalize_variant is Dictionary) \
		or not bool((finalize_variant as Dictionary).get("accepted", false)):
		var finalize_rollback := _rollback_transaction(
			transaction,
			"track_finalize_rejected"
		)
		if not bool(finalize_rollback.get("accepted", false)):
			return _rollback_failure_result(transaction)
		return _commit_failure(transaction_id, "track_finalize_rejected")
	var composite_receipt := TrackCore.sealed_copy({
		"schema_version": SCHEMA_VERSION,
		"interface_id": COMPOSITE_RECEIPT_INTERFACE_ID,
		"ruleset_id": RULESET_ID,
		"domain_id": DOMAIN_ID,
		"transaction_id": transaction_id,
		"request_id": str(transaction.get("request_id", "")),
		"intent_fingerprint": str(transaction.get("intent_fingerprint", "")),
		"action_id": str(track_receipt.get("action_id", "")),
		"accepted": true,
		"reason_code": "acquisition_committed",
		"source_revision": int(track_receipt.get("source_revision", 0)),
		"result_revision": int(track_receipt.get("result_revision", 0)),
		"destination_zone": str(track_receipt.get("destination_zone", "")),
		"track_receipt": track_receipt.duplicate(true),
		"participant_commits": participant_commits,
		"external_participants_finalized": true,
	}, "receipt_fingerprint")
	if not _composite_receipt_valid(composite_receipt):
		return _commit_failure(transaction_id, "composite_receipt_invalid")
	_transactions.erase(transaction_id)
	_transaction_receipts[transaction_id] = composite_receipt
	_transaction_history[transaction_id] = _terminal_transaction_record(
		transaction,
		"committed",
		"acquisition_committed"
	)
	return composite_receipt.duplicate(true)


func abort_v1(transaction_id: String, reason_code: String) -> Dictionary:
	var integrity_error := _configuration_integrity_error()
	if not integrity_error.is_empty():
		return _result(false, integrity_error, transaction_id)
	if _transaction_receipts.has(transaction_id):
		return _result(false, "acquisition_transaction_already_committed", transaction_id)
	if not _transactions.has(transaction_id):
		return _result(false, "acquisition_transaction_not_prepared", transaction_id)
	var transaction := _transactions.get(transaction_id, {}) as Dictionary
	if str(transaction.get("status", "")) == "rollback_failed":
		return _rollback_failure_result(transaction)
	if str(transaction.get("status", "")) != "prepared":
		return _result(false, "acquisition_transaction_not_abortable", transaction_id)
	var rollback_result := _rollback_transaction(transaction, reason_code)
	if not bool(rollback_result.get("accepted", false)):
		return _rollback_failure_result(transaction)
	return _result(
		true,
		"acquisition_transaction_aborted",
		transaction_id
	)


func receipt_v1(transaction_id: String) -> Dictionary:
	if not _transaction_receipts.has(transaction_id):
		return {}
	return (
		_transaction_receipts.get(transaction_id, {}) as Dictionary
	).duplicate(true)


func recovery_v1(transaction_id: String) -> Dictionary:
	if not _transactions.has(transaction_id):
		return {}
	var transaction := _transactions.get(transaction_id, {}) as Dictionary
	if str(transaction.get("status", "")) != "rollback_failed":
		return {}
	return _recovery_handle(transaction)


func recover_rollback_v1(transaction_id: String) -> Dictionary:
	var integrity_error := _configuration_integrity_error()
	if not integrity_error.is_empty():
		return _commit_failure(transaction_id, integrity_error)
	if not _transactions.has(transaction_id):
		return _commit_failure(transaction_id, "rollback_recovery_not_found")
	var transaction := _transactions.get(transaction_id, {}) as Dictionary
	if str(transaction.get("status", "")) != "rollback_failed":
		return _commit_failure(transaction_id, "rollback_recovery_not_required")
	var result := _rollback_transaction(
		transaction,
		str(transaction.get("rollback_failure_reason", "rollback_recovery"))
	)
	if not bool(result.get("accepted", false)):
		return _rollback_failure_result(transaction)
	return {
		"accepted": true,
		"reason_code": "rollback_recovered",
		"transaction_id": transaction_id,
		"terminal_record": (
			_transaction_history.get(transaction_id, {}) as Dictionary
		).duplicate(true),
	}


func transaction_status_v1(transaction_id: String) -> Dictionary:
	if _transactions.has(transaction_id):
		var transaction := _transactions.get(transaction_id, {}) as Dictionary
		if str(transaction.get("status", "")) == "rollback_failed":
			return _recovery_handle(transaction)
		return {
			"transaction_id": transaction_id,
			"request_id": str(transaction.get("request_id", "")),
			"status": str(transaction.get("status", "")),
		}
	if _transaction_history.has(transaction_id):
		return (
			_transaction_history.get(transaction_id, {}) as Dictionary
		).duplicate(true)
	return {}


func capture_receipt_journal_v1() -> Dictionary:
	if not is_configured() \
		or not _configuration_integrity_error().is_empty() \
		or not _transactions.is_empty():
		return {}
	var track_status_variant: Variant = _track_authority.call(
		"acquisition_transaction_status_v1"
	)
	if not (track_status_variant is Dictionary) \
		or not bool((track_status_variant as Dictionary).get("quiescent", false)):
		return {}
	var transaction_ids: Array[String] = []
	for transaction_id_variant in _transaction_receipts.keys():
		transaction_ids.append(str(transaction_id_variant))
	transaction_ids.sort()
	var receipts: Array = []
	for transaction_id in transaction_ids:
		receipts.append((
			_transaction_receipts.get(transaction_id, {}) as Dictionary
		).duplicate(true))
	var authority := _track_authority.call("core_authority_v1") as Dictionary
	var state := authority.get("authority_state", {}) as Dictionary
	return TrackCore.sealed_copy({
		"schema_version": SCHEMA_VERSION,
		"interface_id": RECEIPT_JOURNAL_INTERFACE_ID,
		"ruleset_id": RULESET_ID,
		"domain_id": DOMAIN_ID,
		"match_instance_id": str(state.get("match_instance_id", "")),
		"authority_binding_fingerprint": _authority_binding_fingerprint(),
		"composite_receipts": receipts,
	}, "journal_fingerprint")


func apply_receipt_journal_v1(journal: Dictionary) -> Dictionary:
	if not is_configured():
		return _result(false, "acquisition_port_not_configured")
	var integrity_error := _configuration_integrity_error()
	if not integrity_error.is_empty():
		return _result(false, integrity_error)
	if not _transactions.is_empty() \
		or not _transaction_receipts.is_empty() \
		or not _request_transactions.is_empty():
		return _result(false, "receipt_journal_target_not_empty")
	var journal_error := _receipt_journal_error(journal)
	if not journal_error.is_empty():
		return _result(false, journal_error)
	var authority := _track_authority.call("core_authority_v1") as Dictionary
	var state := authority.get("authority_state", {}) as Dictionary
	if str(journal.get("match_instance_id", "")) \
			!= str(state.get("match_instance_id", "")):
		return _result(false, "receipt_journal_match_lineage_mismatch")
	if str(journal.get("authority_binding_fingerprint", "")) \
			!= _authority_binding_fingerprint():
		return _result(false, "receipt_journal_authority_binding_mismatch")
	var candidate_receipts: Dictionary = {}
	var candidate_requests: Dictionary = {}
	var candidate_history: Dictionary = {}
	for receipt_variant in journal.get("composite_receipts", []) as Array:
		if not (receipt_variant is Dictionary):
			return _result(false, "receipt_journal_receipt_wrong_type")
		var receipt := receipt_variant as Dictionary
		var receipt_error := _restored_composite_receipt_error(receipt)
		if not receipt_error.is_empty():
			return _result(false, "receipt_journal_receipt_invalid.%s" % receipt_error)
		var transaction_id := str(receipt.get("transaction_id", ""))
		var request_id := str(receipt.get("request_id", ""))
		if candidate_receipts.has(transaction_id) \
			or candidate_requests.has(request_id):
			return _result(false, "receipt_journal_identity_duplicate")
		candidate_receipts[transaction_id] = receipt.duplicate(true)
		candidate_requests[request_id] = transaction_id
		candidate_history[transaction_id] = {
			"transaction_id": transaction_id,
			"request_id": request_id,
			"status": "committed",
			"reason_code": "receipt_journal_restored",
		}
	_transaction_receipts = candidate_receipts
	_request_transactions = candidate_requests
	_transaction_history = candidate_history
	return {
		"accepted": true,
		"reason_code": "receipt_journal_restored",
		"transaction_id": "",
		"receipt_count": candidate_receipts.size(),
	}


func transact_v1(track_intent: Dictionary) -> Dictionary:
	var prepared := prepare_v1(track_intent)
	if not bool(prepared.get("accepted", false)):
		return prepared
	var transaction_id := str(prepared.get("transaction_id", ""))
	if bool(prepared.get("already_committed", false)):
		return receipt_v1(transaction_id)
	return commit_v1(transaction_id)


func _track_commit_context_v1(
	transaction_id: String,
	track_authority: RefCounted
) -> Dictionary:
	if not _configuration_integrity_error().is_empty() \
		or track_authority == null \
		or track_authority != _track_authority \
		or not _transactions.has(transaction_id):
		return {}
	var transaction := _transactions.get(transaction_id, {}) as Dictionary
	if str(transaction.get("status", "")) != "prepared":
		return {}
	var prepared_roles: Array = []
	for row_variant in transaction.get("prepared_rows", []) as Array:
		prepared_roles.append(str((row_variant as Dictionary).get(
			"participant_role", ""
		)))
	return {
		"intent": (transaction.get("intent", {}) as Dictionary).duplicate(true),
		"proposal": (transaction.get("proposal", {}) as Dictionary).duplicate(true),
		"all_required_participants_prepared": true,
		"prepared_participant_roles": prepared_roles,
	}


func _capture_participant_checkpoints(requirements: Array) -> Dictionary:
	var checkpoints: Dictionary = {}
	for requirement_variant in requirements:
		var role := str((requirement_variant as Dictionary).get(
			"participant_role", ""
		))
		var participant := _participants.get(role) as RefCounted
		var participant_key := str(participant.get_instance_id())
		if checkpoints.has(participant_key):
			continue
		var checkpoint_variant: Variant = participant.call("capture_checkpoint_v1")
		if not (checkpoint_variant is Dictionary) \
			or not TrackCore.is_pure_data(checkpoint_variant):
			return {
				"accepted": false,
				"reason_code": "participant_checkpoint_invalid.%s" % role,
				"checkpoints": {},
			}
		checkpoints[participant_key] = {
			"participant": participant,
			"checkpoint": (checkpoint_variant as Dictionary).duplicate(true),
		}
	return {
		"accepted": true,
		"reason_code": "participant_checkpoints_captured",
		"checkpoints": checkpoints,
	}


func _participant_authority_error(requirements: Array) -> String:
	var observed_roles: Array = []
	for requirement_variant in requirements:
		if not (requirement_variant is Dictionary):
			return "participant_requirement_wrong_type"
		var requirement := requirement_variant as Dictionary
		var role := str(requirement.get("participant_role", ""))
		if role not in PARTICIPANT_ROLES or observed_roles.has(role):
			return "participant_role_invalid"
		observed_roles.append(role)
		var participant := _participants.get(role) as RefCounted
		var observed_authority_id := str(participant.call(
			"acquisition_authority_id_v1"
		))
		if observed_authority_id != str(requirement.get("authority_id", "")):
			return "participant_authority_mismatch.%s" % role
	return ""


func _participant_request(
	transaction_id: String,
	proposal: Dictionary,
	requirement: Dictionary
) -> Dictionary:
	return TrackCore.sealed_copy({
		"schema_version": SCHEMA_VERSION,
		"interface_id": PARTICIPANT_REQUEST_INTERFACE_ID,
		"ruleset_id": RULESET_ID,
		"domain_id": DOMAIN_ID,
		"transaction_id": transaction_id,
		"participant_role": str(requirement.get("participant_role", "")),
		"authority_id": str(requirement.get("authority_id", "")),
		"reservation_kind": str(requirement.get("reservation_kind", "")),
		"request_id": str(proposal.get("request_id", "")),
		"actor_id": str(proposal.get("actor_id", "")),
		"action_id": str(proposal.get("action_id", "")),
		"source_identity": (
			proposal.get("source_identity", {}) as Dictionary
		).duplicate(true),
		"destination_zone": str(proposal.get("destination_zone", "")),
		"proposal_fingerprint": str(proposal.get("proposal_fingerprint", "")),
	}, "request_fingerprint")


func _rollback_participants_detailed(
	transaction: Dictionary,
	reason_code: String
) -> Array[String]:
	var failed_components: Array[String] = []
	var completed_components := (
		transaction.get("rollback_completed_components", []) as Array
	)
	var prepared_rows := (
		transaction.get("prepared_rows", []) as Array
	).duplicate()
	prepared_rows.reverse()
	for row_variant in prepared_rows:
		var row := row_variant as Dictionary
		var abort_component := "participant_abort.%s" % str(
			row.get("participant_role", "")
		)
		if completed_components.has(abort_component):
			continue
		var participant := row.get("participant") as RefCounted
		var abort_variant: Variant = participant.call(
			"abort_prepared_acquisition_v1",
			str(row.get("reservation_id", "")),
			reason_code
		)
		var abort_error := "wrong_type"
		if abort_variant is Dictionary:
			abort_error = _participant_receipt_binding_error(
				abort_variant as Dictionary,
				str(transaction.get("transaction_id", "")),
				str(row.get("participant_role", "")),
				str(row.get("authority_id", "")),
				str(row.get("reservation_id", ""))
			)
		if not abort_error.is_empty() \
			or not _operation_accepted(abort_variant):
			failed_components.append(abort_component)
		else:
			completed_components.append(abort_component)
	for checkpoint_key_variant in (
		transaction.get("participant_checkpoints", {}) as Dictionary
	).keys():
		var checkpoint_key := str(checkpoint_key_variant)
		var rollback_component := "participant_rollback.%s" % checkpoint_key
		if completed_components.has(rollback_component):
			continue
		var checkpoint_row := (
			transaction.get("participant_checkpoints", {}) as Dictionary
		).get(checkpoint_key, {}) as Dictionary
		var participant := checkpoint_row.get("participant") as RefCounted
		var rollback_variant: Variant = participant.call(
			"rollback_v1",
			(checkpoint_row.get("checkpoint", {}) as Dictionary).duplicate(true)
		)
		if not _operation_accepted(rollback_variant):
			failed_components.append(rollback_component)
		else:
			completed_components.append(rollback_component)
	transaction["rollback_completed_components"] = completed_components
	failed_components.sort()
	return failed_components


func _rollback_transaction(
	transaction_value: Dictionary,
	reason_code: String
) -> Dictionary:
	var transaction := transaction_value
	var transaction_id := str(transaction.get("transaction_id", ""))
	if _transactions.has(transaction_id):
		transaction = _transactions.get(transaction_id, {}) as Dictionary
	var request_id := str(transaction.get("request_id", ""))
	transaction["recovery_attempt_count"] = int(
		transaction.get("recovery_attempt_count", 0)
	) + 1
	var failed_components := _rollback_participants_detailed(transaction, reason_code)
	var track_mode := str(transaction.get("track_transaction_mode", "none"))
	if track_mode != "none" \
		and not bool(transaction.get("track_rollback_complete", false)):
		var track_method := "abort_prepared_acquisition_transaction_v1" \
			if track_mode == "prepared" \
			else "rollback_acquisition_transaction_v1"
		var track_result_variant: Variant = _track_authority.call(
			track_method,
			transaction_id,
			self
		)
		if _operation_accepted(track_result_variant):
			transaction["track_rollback_complete"] = true
		else:
			failed_components.append("track_%s" % (
				"prepared_abort" if track_mode == "prepared" else "rollback"
			))
	failed_components.sort()
	if failed_components.is_empty():
		transaction["status"] = "rolled_back"
		_transaction_history[transaction_id] = _terminal_transaction_record(
			transaction,
			"rolled_back",
			reason_code
		)
		_transactions.erase(transaction_id)
		_request_transactions.erase(request_id)
		return {
			"accepted": true,
			"reason_code": "transaction_rolled_back",
			"transaction_id": transaction_id,
		}
	transaction["status"] = "rollback_failed"
	transaction["rollback_failure_reason"] = reason_code
	transaction["rollback_failed_components"] = failed_components
	_transactions[transaction_id] = transaction
	_request_transactions[request_id] = transaction_id
	return {
		"accepted": false,
		"reason_code": "rollback_failed",
		"transaction_id": transaction_id,
		"recovery_handle": _recovery_handle(transaction),
	}


func _configuration_integrity_error() -> String:
	if not _configured or _track_authority == null:
		return "acquisition_port_not_configured"
	if _track_authority.get_instance_id() != _track_instance_id:
		return "track_authority_object_replaced"
	for role in PARTICIPANT_ROLES:
		var participant_variant: Variant = _participants.get(role)
		var binding_variant: Variant = _participant_bindings.get(role)
		if not (participant_variant is RefCounted) \
			or not (binding_variant is Dictionary):
			return "participant_object_replaced.%s" % role
		var participant := participant_variant as RefCounted
		var binding := binding_variant as Dictionary
		if participant.get_instance_id() != int(binding.get("instance_id", -1)) \
			or not participant.has_method("acquisition_authority_id_v1"):
			return "participant_object_replaced.%s" % role
		if str(participant.call("acquisition_authority_id_v1")) \
				!= str(binding.get("authority_id", "")):
			return "participant_authority_id_changed.%s" % role
	return ""


static func _participant_receipt_binding_error(
	receipt: Dictionary,
	transaction_id: String,
	participant_role: String,
	authority_id: String,
	reservation_id: String
) -> String:
	if not TrackCore.is_pure_data(receipt):
		return "not_pure_data"
	for field_name in PARTICIPANT_RECEIPT_BINDING_FIELDS:
		if not receipt.has(field_name):
			return "field_missing.%s" % field_name
	if not (receipt.get("accepted") is bool) \
		or not _is_stable_id(receipt.get("reason_code")) \
		or not _is_stable_id(receipt.get("transaction_id")) \
		or not _is_stable_id(receipt.get("reservation_id")) \
		or not _is_stable_id(receipt.get("authority_id")) \
		or not _is_stable_id(receipt.get("participant_role")):
		return "identity_invalid"
	if str(receipt.get("transaction_id", "")) != transaction_id:
		return "transaction_id_mismatch"
	if str(receipt.get("participant_role", "")) != participant_role:
		return "participant_role_mismatch"
	if str(receipt.get("authority_id", "")) != authority_id:
		return "authority_id_mismatch"
	if not reservation_id.is_empty() \
		and str(receipt.get("reservation_id", "")) != reservation_id:
		return "reservation_id_mismatch"
	if str(receipt.get("receipt_fingerprint", "")) \
			!= TrackCore.fingerprint(receipt, "receipt_fingerprint"):
		return "fingerprint_invalid"
	return ""


func _recovery_handle(transaction: Dictionary) -> Dictionary:
	var failed_components := (
		transaction.get("rollback_failed_components", []) as Array
	).duplicate(true)
	failed_components.sort()
	return TrackCore.sealed_copy({
		"schema_version": SCHEMA_VERSION,
		"interface_id": ROLLBACK_RECOVERY_INTERFACE_ID,
		"ruleset_id": RULESET_ID,
		"domain_id": DOMAIN_ID,
		"transaction_id": str(transaction.get("transaction_id", "")),
		"request_id": str(transaction.get("request_id", "")),
		"intent_fingerprint": str(transaction.get("intent_fingerprint", "")),
		"status": "rollback_failed",
		"failure_reason_code": str(
			transaction.get("rollback_failure_reason", "rollback_failed")
		),
		"track_rollback_required": (
			str(transaction.get("track_transaction_mode", "none")) == "committed"
		),
		"failed_components": failed_components,
		"recovery_attempt_count": int(
			transaction.get("recovery_attempt_count", 0)
		),
	}, "recovery_fingerprint")


func _rollback_failure_result(transaction_value: Dictionary) -> Dictionary:
	var transaction := transaction_value
	var transaction_id := str(transaction.get("transaction_id", ""))
	if _transactions.has(transaction_id):
		transaction = _transactions.get(transaction_id, {}) as Dictionary
	return {
		"accepted": false,
		"reason_code": "rollback_failed",
		"transaction_id": transaction_id,
		"recovery_handle": _recovery_handle(transaction),
	}


static func _terminal_transaction_record(
	transaction: Dictionary,
	status: String,
	reason_code: String
) -> Dictionary:
	return {
		"transaction_id": str(transaction.get("transaction_id", "")),
		"request_id": str(transaction.get("request_id", "")),
		"intent_fingerprint": str(transaction.get("intent_fingerprint", "")),
		"status": status,
		"reason_code": reason_code,
	}


func _authority_binding_fingerprint() -> String:
	var rows: Array = []
	for role in PARTICIPANT_ROLES:
		var binding := _participant_bindings.get(role, {}) as Dictionary
		rows.append({
			"participant_role": role,
			"authority_id": str(binding.get("authority_id", "")),
		})
	return TrackCore.fingerprint({
		"track_interface_id": TrackCore.CORE_INTERFACE_ID,
		"participant_bindings": rows,
	})


func _receipt_journal_error(journal: Dictionary) -> String:
	if not TrackCore.is_pure_data(journal) \
		or not _exact_fields(journal, RECEIPT_JOURNAL_FIELDS):
		return "receipt_journal_fields_invalid"
	if journal.get("schema_version") != SCHEMA_VERSION \
		or str(journal.get("interface_id", "")) != RECEIPT_JOURNAL_INTERFACE_ID \
		or str(journal.get("ruleset_id", "")) != RULESET_ID \
		or str(journal.get("domain_id", "")) != DOMAIN_ID \
		or not _is_stable_id(journal.get("match_instance_id")) \
		or not (journal.get("composite_receipts") is Array):
		return "receipt_journal_header_invalid"
	if str(journal.get("journal_fingerprint", "")) \
			!= TrackCore.fingerprint(journal, "journal_fingerprint"):
		return "receipt_journal_fingerprint_invalid"
	return ""


func _restored_composite_receipt_error(receipt: Dictionary) -> String:
	if not _composite_receipt_valid(receipt):
		return "composite_contract_invalid"
	var transaction_id := str(receipt.get("transaction_id", ""))
	var request_id := str(receipt.get("request_id", ""))
	if transaction_id != _transaction_id(str(receipt.get("intent_fingerprint", ""))):
		return "transaction_identity_invalid"
	var track_receipt := receipt.get("track_receipt", {}) as Dictionary
	var authoritative_variant: Variant = _track_authority.call(
		"authoritative_receipt_v1",
		request_id
	)
	if not (authoritative_variant is Dictionary) \
		or authoritative_variant != track_receipt:
		return "track_receipt_not_authoritative"
	var expected_roles := ["commodity_slot"] \
		if str(receipt.get("action_id", "")) \
			== TrackCore.ACTION_CLAIM_VISIBLE_COMMODITY \
		else ["cash", "personal_discard"]
	var observed_roles: Array = []
	for row_variant in receipt.get("participant_commits", []) as Array:
		if not (row_variant is Dictionary):
			return "participant_commit_wrong_type"
		var row := row_variant as Dictionary
		if not _exact_fields(row, PARTICIPANT_COMMIT_FIELDS):
			return "participant_commit_fields_invalid"
		var role := str(row.get("participant_role", ""))
		var binding := _participant_bindings.get(role, {}) as Dictionary
		if str(row.get("transaction_id", "")) != transaction_id \
			or str(row.get("request_id", "")) != request_id \
			or str(row.get("authority_id", "")) \
				!= str(binding.get("authority_id", "")) \
			or not _is_stable_id(row.get("reservation_id")) \
			or not _is_fingerprint(row.get("participant_receipt_fingerprint")) \
			or int(row.get("finalize_count", 0)) != 1 \
			or observed_roles.has(role):
			return "participant_commit_binding_invalid"
		observed_roles.append(role)
	if not _same_string_set(observed_roles, expected_roles):
		return "participant_commit_role_set_invalid"
	return ""


func _public_prepared_result(transaction: Dictionary) -> Dictionary:
	return {
		"accepted": true,
		"prepared": true,
		"already_committed": false,
		"reason_code": "acquisition_participants_prepared",
		"transaction_id": str(transaction.get("transaction_id", "")),
		"proposal": (
			transaction.get("proposal", {}) as Dictionary
		).duplicate(true),
	}


static func _prepare_result(accepted: bool, reason_code: String) -> Dictionary:
	return {
		"accepted": accepted,
		"prepared": false,
		"already_committed": false,
		"reason_code": reason_code,
		"transaction_id": "",
		"proposal": {},
	}


static func _commit_failure(
	transaction_id: String,
	reason_code: String
) -> Dictionary:
	return {
		"accepted": false,
		"reason_code": reason_code,
		"transaction_id": transaction_id,
	}


static func _result(
	accepted: bool,
	reason_code: String,
	transaction_id: String = ""
) -> Dictionary:
	return {
		"accepted": accepted,
		"reason_code": reason_code,
		"transaction_id": transaction_id,
	}


static func _operation_accepted(result: Variant) -> bool:
	if not (result is Dictionary):
		return false
	var value := result as Dictionary
	return bool(value.get("accepted", false)) \
		or bool(value.get("rolled_back", false)) \
		or bool(value.get("aborted", false))


static func _composite_receipt_valid(receipt: Dictionary) -> bool:
	if not TrackCore.is_pure_data(receipt) \
		or not _exact_fields(receipt, COMPOSITE_RECEIPT_FIELDS):
		return false
	if receipt.get("schema_version") != SCHEMA_VERSION \
		or str(receipt.get("interface_id", "")) != COMPOSITE_RECEIPT_INTERFACE_ID \
		or str(receipt.get("ruleset_id", "")) != RULESET_ID \
		or str(receipt.get("domain_id", "")) != DOMAIN_ID \
		or receipt.get("accepted") != true \
		or receipt.get("external_participants_finalized") != true \
		or not (receipt.get("track_receipt") is Dictionary) \
		or not (receipt.get("participant_commits") is Array) \
		or str(receipt.get("receipt_fingerprint", "")) \
			!= TrackCore.fingerprint(receipt, "receipt_fingerprint"):
		return false
	for row_variant in receipt.get("participant_commits", []) as Array:
		if not (row_variant is Dictionary) \
			or not _exact_fields(row_variant as Dictionary, PARTICIPANT_COMMIT_FIELDS):
			return false
	return true


static func _exact_fields(value: Dictionary, fields: Array) -> bool:
	if value.size() != fields.size():
		return false
	for field_name in fields:
		if not value.has(field_name):
			return false
	return true


static func _same_string_set(first: Array, second: Array) -> bool:
	if first.size() != second.size():
		return false
	var left: Array[String] = []
	var right: Array[String] = []
	for value in first:
		left.append(str(value))
	for value in second:
		right.append(str(value))
	left.sort()
	right.sort()
	return left == right


static func _is_stable_id(value: Variant) -> bool:
	if not (value is String):
		return false
	var text := value as String
	if text.is_empty() or text.length() > 160:
		return false
	for index in range(text.length()):
		var code := text.unicode_at(index)
		if not (code >= 97 and code <= 122) \
			and not (code >= 48 and code <= 57) \
			and code not in [45, 46, 95]:
			return false
	return true


static func _is_fingerprint(value: Variant) -> bool:
	if not (value is String) or (value as String).length() != 64:
		return false
	for index in range((value as String).length()):
		var code := (value as String).unicode_at(index)
		if not ((code >= 48 and code <= 57) or (code >= 97 and code <= 102)):
			return false
	return true


static func _transaction_id(intent_fingerprint: String) -> String:
	return "transaction.track_acquisition.%s" % intent_fingerprint.left(32)
