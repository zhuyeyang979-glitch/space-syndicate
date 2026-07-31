extends SceneTree

const TrackCore := preload("res://scripts/v07_semantic/v07_unified_card_track_core.gd")
const AcquisitionPort := preload(
	"res://scripts/v07_semantic/v07_track_acquisition_authority_port.gd"
)

const ROSTER := ["player.alpha", "player.beta", "player.gamma", "player.delta"]
const FIXED_SEED := 900626424

var _checks := 0
var _failures: Array[String] = []
var _fixture_sequence := 0


class ParticipantFixture extends RefCounted:
	var authority_id: String
	var authority_state: Dictionary
	var prepare_calls := 0
	var commit_calls := 0
	var abort_calls := 0
	var rollback_calls := 0
	var reject_prepare := false
	var reject_commit := false
	var reject_rollback := false
	var commit_role_override := ""
	var mutate_track_core: RefCounted = null
	var mutation_request_id := ""
	var last_track_receipt: Dictionary = {}

	func _init(value: String) -> void:
		authority_id = value
		authority_state = {
			"authority_id": value,
			"reservations": {},
			"commits": {},
			"allocator_cursor": 0,
			"journal": [],
		}

	func acquisition_authority_id_v1() -> String:
		return authority_id

	func capture_checkpoint_v1() -> Dictionary:
		return authority_state.duplicate(true)

	func prepare_acquisition_v1(request: Dictionary) -> Variant:
		prepare_calls += 1
		var reservation_id := "reservation.%s.%04d" % [
			str(request.get("participant_role", "")),
			int(authority_state.get("allocator_cursor", 0)),
		]
		authority_state["allocator_cursor"] = (
			int(authority_state.get("allocator_cursor", 0)) + 1
		)
		(authority_state.get("reservations", {}) as Dictionary)[reservation_id] = (
			request.duplicate(true)
		)
		(authority_state.get("journal", []) as Array).append({
			"operation": "prepare",
			"reservation_id": reservation_id,
		})
		if reject_prepare:
			return _bound_receipt(request, reservation_id, {
				"accepted": false,
				"reason_code": "injected_prepare_reject",
			})
		return _bound_receipt(request, reservation_id, {
			"accepted": true,
			"reason_code": "participant_prepared",
		})

	func commit_prepared_acquisition_v1(
		reservation_id: String,
		track_receipt: Dictionary
	) -> Variant:
		commit_calls += 1
		last_track_receipt = track_receipt.duplicate(true)
		var request := (
			authority_state.get("reservations", {}) as Dictionary
		).get(reservation_id, {}) as Dictionary
		(authority_state.get("journal", []) as Array).append({
			"operation": "commit",
			"reservation_id": reservation_id,
		})
		if reject_commit:
			if mutate_track_core != null:
				var mutation_intent: Dictionary = mutate_track_core.call(
					"build_intent_v1",
					mutation_request_id,
					"system",
					TrackCore.ACTION_ADVANCE_TRACK,
					{"steps": 1}
				)
				mutate_track_core.call("apply_intent_v1", mutation_intent)
			return _bound_receipt(request, reservation_id, {
				"accepted": false,
				"reason_code": "injected_commit_reject",
				"track_receipt_fingerprint": str(
					track_receipt.get("receipt_fingerprint", "")
				),
			}, true)
		if request.is_empty():
			return {"accepted": false, "reason_code": "reservation_missing"}
		var commits := authority_state.get("commits", {}) as Dictionary
		if commits.has(reservation_id):
			return (commits.get(reservation_id, {}) as Dictionary).duplicate(true)
		var result := _bound_receipt(request, reservation_id, {
			"accepted": true,
			"reason_code": "participant_committed",
			"track_receipt_fingerprint": str(
				track_receipt.get("receipt_fingerprint", "")
			),
		}, true)
		commits[reservation_id] = result
		authority_state["commits"] = commits
		return result.duplicate(true)

	func abort_prepared_acquisition_v1(
		reservation_id: String,
		_reason_code: String
	) -> Dictionary:
		abort_calls += 1
		var request := (
			authority_state.get("reservations", {}) as Dictionary
		).get(reservation_id, {}) as Dictionary
		(authority_state.get("reservations", {}) as Dictionary).erase(reservation_id)
		return _bound_receipt(request, reservation_id, {
			"accepted": true,
			"reason_code": "participant_aborted",
		})

	func rollback_v1(checkpoint: Dictionary) -> Dictionary:
		rollback_calls += 1
		if reject_rollback:
			return {"accepted": false, "reason_code": "injected_rollback_reject"}
		authority_state = checkpoint.duplicate(true)
		return {"accepted": true, "reason_code": "participant_rolled_back"}

	func _bound_receipt(
		request: Dictionary,
		reservation_id: String,
		fields: Dictionary,
		allow_role_override: bool = false
	) -> Dictionary:
		var unsealed := fields.duplicate(true)
		unsealed["transaction_id"] = str(request.get("transaction_id", ""))
		unsealed["reservation_id"] = reservation_id
		unsealed["authority_id"] = authority_id
		unsealed["participant_role"] = commit_role_override \
			if allow_role_override and not commit_role_override.is_empty() \
			else str(request.get("participant_role", ""))
		return TrackCore.sealed_copy(unsealed, "receipt_fingerprint")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_contract_and_direct_gate()
	_test_normal_prepare_abort_and_success()
	_test_commodity_prepare_abort_and_success()
	_test_prepare_rejection_matrix()
	_test_stale_and_authority_mismatch_matrix()
	_test_commit_failure_transaction_rollback_matrix()
	_test_rollback_failure_recovery_and_retry_block()
	_test_object_identity_and_receipt_binding()
	_test_half_commit_save_and_restored_exact_replay()
	_test_pure_nonproduction_boundary()
	_finish()


func _test_contract_and_direct_gate() -> void:
	var fixture := _fixture("normal_card", "contract")
	var core := fixture.get("core") as RefCounted
	var port := fixture.get("port") as RefCounted
	var intent := fixture.get("intent", {}) as Dictionary
	var contract: Dictionary = port.call("acquisition_port_contract_v1")
	_expect(
		core is RefCounted
			and port is RefCounted
			and not core.has_method("add_child")
			and not port.has_method("add_child"),
		"Track and acquisition port are pure RefCounted authorities"
	)
	_expect(
		TrackCore.is_pure_data(contract)
			and str(contract.get("interface_id", "")) == AcquisitionPort.INTERFACE_ID
			and contract.get("caller_supplied_receipts_trusted") == false
			and contract.get("transaction_owned_rollback_required") == true
			and contract.get("production_runtime_connected") == false,
		"port contract freezes direct authority, rollback, and nonproduction boundaries"
	)
	var before := core.call("core_authority_v1") as Dictionary
	var direct: Dictionary = core.call("apply_intent_v1", intent)
	_expect(
		not bool(direct.get("accepted", true))
			and str(direct.get("reason_code", ""))
				== "acquisition_authority_port_required"
			and core.call("core_authority_v1") == before,
		"caller cannot mutate Track by sending a fully sealed acquisition intent directly"
	)
	var proposal_result: Dictionary = core.call(
		"prepare_visible_acquisition_v1",
		intent
	)
	var proposal := proposal_result.get("proposal", {}) as Dictionary
	_expect(
		bool(proposal_result.get("accepted", false))
			and TrackCore.is_pure_data(proposal)
			and proposal.get("cash_reservation_required") == true
			and proposal.get("asset_reservation_required") == false
			and not _contains_key_recursive(proposal, "current_lead_id")
			and not _contains_key_recursive(proposal, "path_origin_index"),
		"read-only proposal carries participant needs without hidden-lead facts"
	)


func _test_normal_prepare_abort_and_success() -> void:
	var aborted := _fixture("normal_card", "normal.abort")
	var abort_core := aborted.get("core") as RefCounted
	var abort_port := aborted.get("port") as RefCounted
	var abort_before := abort_core.call("core_authority_v1") as Dictionary
	var participant_before := _participant_states(aborted)
	var prepared: Dictionary = abort_port.call(
		"prepare_v1",
		aborted.get("intent", {}) as Dictionary
	)
	var transaction_id := str(prepared.get("transaction_id", ""))
	var cash := aborted.get("cash") as ParticipantFixture
	var discard := aborted.get("personal_discard") as ParticipantFixture
	var commodity := aborted.get("commodity_slot") as ParticipantFixture
	_expect(
		bool(prepared.get("accepted", false))
			and cash.prepare_calls == 1
			and discard.prepare_calls == 1
			and commodity.prepare_calls == 0
			and abort_core.call("core_authority_v1") == abort_before,
		"normal prepare reserves cash and personal discard before any Track mutation"
	)
	var abort_result: Dictionary = abort_port.call(
		"abort_v1",
		transaction_id,
		"injected_precommit_abort"
	)
	_expect(
		bool(abort_result.get("accepted", false))
			and abort_core.call("core_authority_v1") == abort_before
			and _participant_states(aborted) == participant_before
			and abort_port.call("receipt_v1", transaction_id).is_empty(),
		"explicit abort restores Track, reservation allocators, and participant journals"
	)
	_expect(
		cash.abort_calls == 1
			and discard.abort_calls == 1
			and cash.rollback_calls == 1
			and discard.rollback_calls == 1
			and commodity.abort_calls == 0,
		"normal abort touches exactly its two prepared participants"
	)

	var success := _fixture("normal_card", "normal.success")
	var core := success.get("core") as RefCounted
	var port := success.get("port") as RefCounted
	var intent := success.get("intent", {}) as Dictionary
	var composite: Dictionary = port.call("transact_v1", intent)
	var committed := core.call("core_authority_v1") as Dictionary
	var track_receipt := composite.get("track_receipt", {}) as Dictionary
	cash = success.get("cash") as ParticipantFixture
	discard = success.get("personal_discard") as ParticipantFixture
	commodity = success.get("commodity_slot") as ParticipantFixture
	_expect(
		_composite_green(composite, 2)
			and str(composite.get("destination_zone", "")) == "personal_discard"
			and track_receipt == core.call(
				"authoritative_receipt_v1",
				str(intent.get("request_id", ""))
			),
		"normal commit emits a composite receipt from the Track authority's own receipt"
	)
	_expect(
		cash.prepare_calls == 1
			and discard.prepare_calls == 1
			and cash.commit_calls == 1
			and discard.commit_calls == 1
			and commodity.prepare_calls == 0
			and commodity.commit_calls == 0,
		"normal commit finalizes cash and discard exactly once and never calls assets or commodity"
	)
	_expect(
		cash.last_track_receipt == track_receipt
			and discard.last_track_receipt == track_receipt,
		"participants receive the receipt fetched directly from Track authority"
	)
	var duplicate: Dictionary = port.call("transact_v1", intent)
	_expect(
		duplicate == composite
			and core.call("core_authority_v1") == committed
			and cash.prepare_calls == 1
			and discard.prepare_calls == 1
			and cash.commit_calls == 1
			and discard.commit_calls == 1,
		"normal transaction replay returns the same composite receipt exact-once"
	)
	var committed_transaction_id := str(composite.get("transaction_id", ""))
	_expect(
		not bool(port.call(
			"abort_v1",
			committed_transaction_id,
			"late_abort"
		).get("accepted", true))
			and core.call("core_authority_v1") == committed,
		"a caller cannot reopen an externally finalized acquisition"
	)


func _test_commodity_prepare_abort_and_success() -> void:
	var aborted := _fixture("commodity_card", "commodity.abort")
	var core := aborted.get("core") as RefCounted
	var port := aborted.get("port") as RefCounted
	var before := core.call("core_authority_v1") as Dictionary
	var participant_before := _participant_states(aborted)
	var prepared: Dictionary = port.call(
		"prepare_v1",
		aborted.get("intent", {}) as Dictionary
	)
	var cash := aborted.get("cash") as ParticipantFixture
	var discard := aborted.get("personal_discard") as ParticipantFixture
	var commodity := aborted.get("commodity_slot") as ParticipantFixture
	var proposal := prepared.get("proposal", {}) as Dictionary
	_expect(
		bool(prepared.get("accepted", false))
			and proposal.get("cash_reservation_required") == false
			and proposal.get("asset_reservation_required") == false
			and cash.prepare_calls == 0
			and discard.prepare_calls == 0
			and commodity.prepare_calls == 1
			and core.call("core_authority_v1") == before,
		"commodity prepare reserves only one commodity slot with no cash or assets"
	)
	_expect(
		bool(port.call(
			"abort_v1",
			str(prepared.get("transaction_id", "")),
			"commodity_abort"
		).get("accepted", false))
			and core.call("core_authority_v1") == before
			and _participant_states(aborted) == participant_before,
		"commodity abort is byte-identical across Track, allocator, and journal"
	)

	var success := _fixture("commodity_card", "commodity.success")
	core = success.get("core") as RefCounted
	port = success.get("port") as RefCounted
	var intent := success.get("intent", {}) as Dictionary
	var composite: Dictionary = port.call("transact_v1", intent)
	var track_receipt := composite.get("track_receipt", {}) as Dictionary
	var cash_delta := track_receipt.get("cash_delta", {}) as Dictionary
	cash = success.get("cash") as ParticipantFixture
	discard = success.get("personal_discard") as ParticipantFixture
	commodity = success.get("commodity_slot") as ParticipantFixture
	_expect(
		_composite_green(composite, 1)
			and str(composite.get("destination_zone", "")) == "commodity_inventory"
			and str(cash_delta.get("amount_decimal", "")) == "0"
			and str(cash_delta.get("external_authority_id", "")) == "authority.none",
		"commodity composite receipt preserves zero-cash constitutional semantics"
	)
	_expect(
		cash.prepare_calls == 0
			and discard.prepare_calls == 0
			and commodity.prepare_calls == 1
			and commodity.commit_calls == 1
			and commodity.last_track_receipt == track_receipt,
		"commodity success finalizes its slot once from the authoritative Track receipt"
	)


func _test_prepare_rejection_matrix() -> void:
	for row in [
		{"kind": "normal_card", "role": "cash"},
		{"kind": "normal_card", "role": "personal_discard"},
		{"kind": "commodity_card", "role": "commodity_slot"},
	]:
		var role := str(row.get("role", ""))
		var fixture := _fixture(
			str(row.get("kind", "")),
			"prepare.reject.%s" % role
		)
		var participant := fixture.get(role) as ParticipantFixture
		participant.reject_prepare = true
		var core := fixture.get("core") as RefCounted
		var port := fixture.get("port") as RefCounted
		var track_before := core.call("core_authority_v1") as Dictionary
		var participant_before := _participant_states(fixture)
		var result: Dictionary = port.call(
			"transact_v1",
			fixture.get("intent", {}) as Dictionary
		)
		_expect(
			not bool(result.get("accepted", true))
				and str(result.get("reason_code", "")).begins_with(
					"participant_prepare_rejected.%s" % role
				)
				and core.call("core_authority_v1") == track_before
				and _participant_states(fixture) == participant_before,
			"%s prepare rejection restores Track, RNG, allocator, and journal" % role
		)
		_expect(
			participant.prepare_calls == 1
				and participant.rollback_calls == 1,
			"%s prepare rejection executes its transaction rollback" % role
		)


func _test_stale_and_authority_mismatch_matrix() -> void:
	var stale_before_prepare := _fixture("normal_card", "stale.before.prepare")
	var core := stale_before_prepare.get("core") as RefCounted
	var port := stale_before_prepare.get("port") as RefCounted
	_advance_once(core, "request.port.stale.before.prepare.advance")
	var after_advance := core.call("core_authority_v1") as Dictionary
	var stale_result: Dictionary = port.call(
		"transact_v1",
		stale_before_prepare.get("intent", {}) as Dictionary
	)
	_expect(
		not bool(stale_result.get("accepted", true))
			and str(stale_result.get("reason_code", "")) == "source_state_stale"
			and core.call("core_authority_v1") == after_advance
			and (stale_before_prepare.get("cash") as ParticipantFixture).prepare_calls == 0
			and (stale_before_prepare.get(
				"personal_discard"
			) as ParticipantFixture).prepare_calls == 0,
		"stale source before prepare rejects without participant or Track mutation"
	)

	var stale_after_prepare := _fixture("commodity_card", "stale.after.prepare")
	core = stale_after_prepare.get("core") as RefCounted
	port = stale_after_prepare.get("port") as RefCounted
	var participant_before := _participant_states(stale_after_prepare)
	var prepared: Dictionary = port.call(
		"prepare_v1",
		stale_after_prepare.get("intent", {}) as Dictionary
	)
	_advance_once(core, "request.port.stale.after.prepare.advance")
	after_advance = core.call("core_authority_v1") as Dictionary
	var stale_commit: Dictionary = port.call(
		"commit_v1",
		str(prepared.get("transaction_id", ""))
	)
	_expect(
		not bool(stale_commit.get("accepted", true))
			and str(stale_commit.get("reason_code", "")) == "source_state_stale"
			and core.call("core_authority_v1") == after_advance
			and _participant_states(stale_after_prepare) == participant_before,
		"stale source after prepare preserves the intervening Track lineage and releases reservations"
	)

	var mismatch := _fixture("normal_card", "authority.mismatch")
	var mismatched_cash := mismatch.get("cash") as ParticipantFixture
	mismatched_cash.authority_id = "authority.cash.different"
	core = mismatch.get("core") as RefCounted
	port = mismatch.get("port") as RefCounted
	var mismatch_before := core.call("core_authority_v1") as Dictionary
	var mismatch_result: Dictionary = port.call(
		"transact_v1",
		mismatch.get("intent", {}) as Dictionary
	)
	_expect(
		not bool(mismatch_result.get("accepted", true))
			and str(mismatch_result.get("reason_code", ""))
				== "participant_authority_id_changed.cash"
			and core.call("core_authority_v1") == mismatch_before
			and mismatched_cash.prepare_calls == 0,
		"caller authorization cannot redirect a trusted participant authority"
	)


func _test_commit_failure_transaction_rollback_matrix() -> void:
	for row in [
		{"kind": "normal_card", "role": "cash"},
		{"kind": "normal_card", "role": "personal_discard"},
		{"kind": "commodity_card", "role": "commodity_slot"},
	]:
		var role := str(row.get("role", ""))
		var fixture := _fixture(
			str(row.get("kind", "")),
			"commit.reject.%s" % role
		)
		var participant := fixture.get(role) as ParticipantFixture
		participant.reject_commit = true
		var core := fixture.get("core") as RefCounted
		var port := fixture.get("port") as RefCounted
		var intent := fixture.get("intent", {}) as Dictionary
		var track_before := core.call("core_authority_v1") as Dictionary
		var participant_before := _participant_states(fixture)
		var result: Dictionary = port.call("transact_v1", intent)
		_expect(
			not bool(result.get("accepted", true))
				and str(result.get("reason_code", ""))
					== "participant_commit_rejected.%s" % role
				and core.call("core_authority_v1") == track_before
				and _participant_states(fixture) == participant_before,
			"%s finalize failure rolls back Track, RNG, allocator, journal, and reservations" % role
		)
		_expect(
			participant.commit_calls == 1
				and participant.rollback_calls == 1,
			"%s injected finalize failure uses transaction-owned rollback" % role
		)
		participant.reject_commit = false
		var retry: Dictionary = port.call("transact_v1", intent)
		_expect(
			bool(retry.get("accepted", false))
				and retry.get("external_participants_finalized") == true,
			"%s rolled-back request can retry from its byte-identical source" % role
		)


func _test_rollback_failure_recovery_and_retry_block() -> void:
	var participant_failure := _fixture("normal_card", "rollback.failure.participant")
	var participant_core := participant_failure.get("core") as RefCounted
	var participant_port := participant_failure.get("port") as RefCounted
	var participant_intent := participant_failure.get("intent", {}) as Dictionary
	var participant_before := participant_core.call("core_authority_v1") as Dictionary
	var discard := participant_failure.get("personal_discard") as ParticipantFixture
	discard.reject_commit = true
	discard.reject_rollback = true
	var failed: Dictionary = participant_port.call("transact_v1", participant_intent)
	var transaction_id := str(failed.get("transaction_id", ""))
	var recovery := failed.get("recovery_handle", {}) as Dictionary
	_expect(
		not bool(failed.get("accepted", true))
			and str(failed.get("reason_code", "")) == "rollback_failed"
			and TrackCore.is_pure_data(recovery)
			and str(recovery.get("status", "")) == "rollback_failed"
			and (recovery.get("failed_components", []) as Array).size() == 1
			and participant_core.call("core_authority_v1") == participant_before,
		"participant rollback failure retains a pure deterministic recovery handle"
	)
	var duplicate: Dictionary = participant_port.call(
		"transact_v1",
		participant_intent
	)
	_expect(
		duplicate == failed
			and discard.prepare_calls == 1
			and discard.commit_calls == 1,
		"rollback-failed transaction blocks duplicate retry without losing identity"
	)
	discard.reject_rollback = false
	discard.reject_commit = false
	var recovered: Dictionary = participant_port.call(
		"recover_rollback_v1",
		transaction_id
	)
	var terminal: Dictionary = participant_port.call(
		"transaction_status_v1",
		transaction_id
	)
	_expect(
		bool(recovered.get("accepted", false))
			and str(terminal.get("status", "")) == "rolled_back"
			and str(terminal.get("transaction_id", "")) == transaction_id,
		"explicit recovery retries only failed rollback components and retains terminal identity"
	)

	var track_failure := _fixture("commodity_card", "rollback.failure.track")
	var track_core := track_failure.get("core") as RefCounted
	var track_port := track_failure.get("port") as RefCounted
	var commodity := track_failure.get("commodity_slot") as ParticipantFixture
	commodity.reject_commit = true
	commodity.mutate_track_core = track_core
	commodity.mutation_request_id = "request.rollback.failure.track.diverge"
	var track_failed: Dictionary = track_port.call(
		"transact_v1",
		track_failure.get("intent", {}) as Dictionary
	)
	var track_recovery := track_failed.get("recovery_handle", {}) as Dictionary
	_expect(
		str(track_failed.get("reason_code", "")) == "rollback_failed"
			and (track_recovery.get("failed_components", []) as Array).has(
				"track_rollback"
			)
			and track_core.call("save_state_v1").is_empty(),
		"Track rollback lineage failure remains active, recoverable, and Save-blocking"
	)
	var track_duplicate: Dictionary = track_port.call(
		"transact_v1",
		track_failure.get("intent", {}) as Dictionary
	)
	_expect(
		track_duplicate == track_failed,
		"Track rollback failure returns the same handle on duplicate replay"
	)


func _test_object_identity_and_receipt_binding() -> void:
	var replacement_fixture := _fixture("normal_card", "identity.replacement")
	var replacement_port := replacement_fixture.get("port") as RefCounted
	var same_id_replacement := ParticipantFixture.new("authority.cash.test")
	replacement_port.set("_participants", {
		"cash": same_id_replacement,
		"personal_discard": replacement_fixture.get("personal_discard"),
		"commodity_slot": replacement_fixture.get("commodity_slot"),
	})
	var replacement_result: Dictionary = replacement_port.call(
		"prepare_v1",
		replacement_fixture.get("intent", {}) as Dictionary
	)
	_expect(
		not bool(replacement_result.get("accepted", true))
			and str(replacement_result.get("reason_code", ""))
				== "participant_object_replaced.cash"
			and same_id_replacement.prepare_calls == 0,
		"same-authority-ID participant object replacement is rejected before use"
	)

	var binding_fixture := _fixture("normal_card", "receipt.binding")
	var binding_core := binding_fixture.get("core") as RefCounted
	var binding_port := binding_fixture.get("port") as RefCounted
	var binding_before := binding_core.call("core_authority_v1") as Dictionary
	var prepared: Dictionary = binding_port.call(
		"prepare_v1",
		binding_fixture.get("intent", {}) as Dictionary
	)
	(binding_fixture.get("cash") as ParticipantFixture).commit_role_override = (
		"personal_discard"
	)
	var binding_result: Dictionary = binding_port.call(
		"commit_v1",
		str(prepared.get("transaction_id", ""))
	)
	_expect(
		not bool(binding_result.get("accepted", true))
			and str(binding_result.get("reason_code", "")).begins_with(
				"participant_commit_receipt_invalid.cash.participant_role_mismatch"
			)
			and binding_core.call("core_authority_v1") == binding_before,
		"fully resealed participant receipt with wrong role binding fails atomically"
	)


func _test_half_commit_save_and_restored_exact_replay() -> void:
	var prepared_fixture := _fixture("normal_card", "save.prepared")
	var prepared_core := prepared_fixture.get("core") as RefCounted
	var prepared_port := prepared_fixture.get("port") as RefCounted
	var prepared: Dictionary = prepared_port.call(
		"prepare_v1",
		prepared_fixture.get("intent", {}) as Dictionary
	)
	_expect(
		bool(prepared.get("accepted", false))
			and prepared_core.call("save_state_v1").is_empty()
			and prepared_port.call("capture_receipt_journal_v1").is_empty(),
		"prepared external reservations block both Track Save and port journal capture"
	)
	prepared_port.call(
		"abort_v1",
		str(prepared.get("transaction_id", "")),
		"save_prepared_cleanup"
	)
	_expect(
		not prepared_core.call("save_state_v1").is_empty(),
		"quiescent rollback reopens Track Save capture"
	)

	var half_fixture := _fixture("commodity_card", "save.track_committed")
	var half_core := half_fixture.get("core") as RefCounted
	var half_port := half_fixture.get("port") as RefCounted
	var half_prepared: Dictionary = half_port.call(
		"prepare_v1",
		half_fixture.get("intent", {}) as Dictionary
	)
	var half_track_receipt: Dictionary = half_core.call(
		"commit_prepared_acquisition_v1",
		str(half_prepared.get("transaction_id", "")),
		half_port
	)
	_expect(
		bool(half_track_receipt.get("accepted", false))
			and half_core.call("save_state_v1").is_empty(),
		"Track-committed but participant-unfinalized transaction cannot be saved"
	)

	var success := _fixture("normal_card", "save.replay")
	var source_core := success.get("core") as RefCounted
	var source_port := success.get("port") as RefCounted
	var source_intent := success.get("intent", {}) as Dictionary
	var composite: Dictionary = source_port.call("transact_v1", source_intent)
	var save: Dictionary = source_core.call("save_state_v1")
	var journal: Dictionary = source_port.call("capture_receipt_journal_v1")
	_expect(
		bool(composite.get("accepted", false))
			and not save.is_empty()
			and TrackCore.is_pure_data(journal)
			and (journal.get("composite_receipts", []) as Array).size() == 1,
		"quiescent committed state captures Track Save plus pure composite journal"
	)
	var restored_core := TrackCore.new()
	var restore_result: Dictionary = restored_core.restore_save_state_v1(save)
	var restored_cash := ParticipantFixture.new("authority.cash.test")
	var restored_discard := ParticipantFixture.new("authority.personal_discard.test")
	var restored_commodity := ParticipantFixture.new("authority.commodity_slot.test")
	var restored_port := AcquisitionPort.new(restored_core, {
		"cash": restored_cash,
		"personal_discard": restored_discard,
		"commodity_slot": restored_commodity,
	})
	var journal_restore: Dictionary = restored_port.apply_receipt_journal_v1(journal)
	var replay: Dictionary = restored_port.transact_v1(source_intent)
	_expect(
		bool(restore_result.get("accepted", false))
			and bool(journal_restore.get("accepted", false))
			and replay == composite
			and restored_cash.prepare_calls == 0
			and restored_discard.prepare_calls == 0,
		"restored Track and pure port journal return the exact composite receipt without refinalization"
	)


func _test_pure_nonproduction_boundary() -> void:
	var port_source := FileAccess.get_file_as_string(
		"res://scripts/v07_semantic/v07_track_acquisition_authority_port.gd"
	)
	var core_source := FileAccess.get_file_as_string(
		"res://scripts/v07_semantic/v07_unified_card_track_core.gd"
	)
	for source_row in [
		{"name": "Track", "source": core_source},
		{"name": "port", "source": port_source},
	]:
		var source := str(source_row.get("source", ""))
		_expect(
			source.contains("extends RefCounted")
				and not source.contains("extends Node")
				and not source.contains("scripts/runtime/")
				and not source.contains("v06_")
				and not source.contains("main.gd"),
			"%s source remains RefCounted and disconnected from production runtime" % str(
				source_row.get("name", "")
			)
		)
	_expect(
		not port_source.contains("v07_dbg_deck_core")
			and not port_source.contains("track_claim_receipt")
			and port_source.contains("prepare_acquisition_v1")
			and port_source.contains("commit_prepared_acquisition_v1"),
		"port depends only on generic participant methods and has no DBG circular trust"
	)


func _fixture(card_kind: String, suffix: String) -> Dictionary:
	_fixture_sequence += 1
	var core := TrackCore.new(
		ROSTER,
		FIXED_SEED,
		{"match_instance_id": "match.port.%03d.%s" % [
			_fixture_sequence,
			suffix,
		]}
	)
	var visible := _visible_item_of_kind(core, card_kind)
	_expect(not visible.is_empty(), "%s fixture exposes %s" % [suffix, card_kind])
	var actor_id := str(visible.get("actor_id", ""))
	var item := visible.get("item", {}) as Dictionary
	var source: Dictionary = core.visible_source_identity_v1(
		actor_id,
		str(item.get("instance_id", ""))
	)
	var is_commodity := card_kind == "commodity_card"
	var cash_authority_id := "authority.none" \
		if is_commodity else "authority.cash.test"
	var inventory_authority_id := "authority.commodity_slot.test" \
		if is_commodity else "authority.personal_discard.test"
	var authorization := TrackCore.seal_viewer_segment_authorization_v1({
		"schema_version": TrackCore.SCHEMA_VERSION,
		"capability_id": "capability.port.%03d.%s" % [_fixture_sequence, suffix],
		"authorization_id": "authorization.port.%03d.%s" % [
			_fixture_sequence,
			suffix,
		],
		"authorization_authority_id": "authority.port.test",
		"authorized_actor_id": actor_id,
		"authorized_source_identity_id": str(source.get("source_identity_id", "")),
		"authorized_source_instance_id": str(source.get("source_instance_id", "")),
		"authorized_segment_owner_id": actor_id,
		"source_track_revision": int(source.get("source_track_revision", 0)),
		"inventory_authority_id": inventory_authority_id,
		"cash_authority_id": cash_authority_id,
	})
	var intent := core.build_visible_acquisition_intent_v1(
		"request.port.%03d.%s" % [_fixture_sequence, suffix],
		actor_id,
		TrackCore.ACTION_CLAIM_VISIBLE_COMMODITY if is_commodity \
		else TrackCore.ACTION_PURCHASE_VISIBLE_NORMAL_CARD,
		source,
		authorization
	)
	var cash := ParticipantFixture.new("authority.cash.test")
	var personal_discard := ParticipantFixture.new(
		"authority.personal_discard.test"
	)
	var commodity_slot := ParticipantFixture.new("authority.commodity_slot.test")
	var port := AcquisitionPort.new(core, {
		"cash": cash,
		"personal_discard": personal_discard,
		"commodity_slot": commodity_slot,
	})
	_expect(port.is_configured(), "%s port binds trusted participant references" % suffix)
	return {
		"core": core,
		"port": port,
		"intent": intent,
		"cash": cash,
		"personal_discard": personal_discard,
		"commodity_slot": commodity_slot,
	}


func _visible_item_of_kind(core: RefCounted, card_kind: String) -> Dictionary:
	for actor_id in ROSTER:
		var projection: Dictionary = core.call("player_projection_v1", actor_id)
		var private_facts := projection.get("viewer_private_facts", {}) as Dictionary
		for item_variant in private_facts.get("own_segment_items", []) as Array:
			var item := item_variant as Dictionary
			if str(item.get("card_kind", "")) == card_kind:
				return {"actor_id": actor_id, "item": item.duplicate(true)}
	return {}


func _advance_once(core: RefCounted, request_id: String) -> void:
	var intent: Dictionary = core.call(
		"build_intent_v1",
		request_id,
		"system",
		TrackCore.ACTION_ADVANCE_TRACK,
		{"steps": 1}
	)
	var receipt: Dictionary = core.call("apply_intent_v1", intent)
	_expect(bool(receipt.get("accepted", false)), "%s advances Track" % request_id)


func _participant_states(fixture: Dictionary) -> Dictionary:
	return {
		"cash": (
			fixture.get("cash") as ParticipantFixture
		).authority_state.duplicate(true),
		"personal_discard": (
			fixture.get("personal_discard") as ParticipantFixture
		).authority_state.duplicate(true),
		"commodity_slot": (
			fixture.get("commodity_slot") as ParticipantFixture
		).authority_state.duplicate(true),
	}


func _composite_green(receipt: Dictionary, expected_participant_count: int) -> bool:
	return TrackCore.is_pure_data(receipt) \
		and bool(receipt.get("accepted", false)) \
		and str(receipt.get("interface_id", "")) \
			== AcquisitionPort.COMPOSITE_RECEIPT_INTERFACE_ID \
		and receipt.get("external_participants_finalized") == true \
		and (receipt.get("participant_commits", []) as Array).size() \
			== expected_participant_count \
		and str(receipt.get("receipt_fingerprint", "")) \
			== TrackCore.fingerprint(receipt, "receipt_fingerprint")


func _contains_key_recursive(value: Variant, needle: String) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant)
			if key == needle or key.contains(needle):
				return true
			if _contains_key_recursive((value as Dictionary).get(key_variant), needle):
				return true
	elif value is Array:
		for item in value as Array:
			if _contains_key_recursive(item, needle):
				return true
	return false


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	print("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print(
			"V07_TRACK_ACQUISITION_AUTHORITY_PORT_TEST|status=PASS|checks=%d|failures=0"
			% _checks
		)
		quit(0)
		return
	push_error(
		"V07 Track acquisition authority port test failed:\n- %s"
		% "\n- ".join(_failures)
	)
	print(
		"V07_TRACK_ACQUISITION_AUTHORITY_PORT_TEST|status=FAIL|checks=%d|failures=%d"
		% [_checks, _failures.size()]
	)
	quit(1)
