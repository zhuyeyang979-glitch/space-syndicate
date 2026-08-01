extends SceneTree

const CORE := preload("res://scripts/v07_semantic/v07_solar_victory_core.gd")
const FORGED_FINGERPRINT := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

var _checks := 0
var _failures: Array[String] = []


class TestVictoryAuthorityPort extends RefCounted:
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

	func victory_current_source_revision_v1(capability: RefCounted) -> int:
		return _current_source_revision if capability == _capability else -1

	func victory_lookup_issued_proof_v1(
		proof_id: String,
		proof_fingerprint: String,
		capability: RefCounted
	) -> Dictionary:
		if capability != _capability or not _issued_proofs.has(proof_id):
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
			for item in value as Array:
				array_result.append(_canonicalize_value(item))
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


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_solar_facility_contract_and_exact_replay()
	_test_trusted_qualification_and_boundary_proofs()
	_test_external_authority_capability_and_source_identity()
	_test_all_intent_collisions_and_restored_replay()
	_test_wrong_entrypoint_exact_replay_rejected()
	_test_strict_state_receipt_and_save_validation()
	_test_coordinated_ledger_and_wire_attacks()
	_test_checkpoint_lineage_and_settlement_barrier()
	_test_recursive_projection_and_save_privacy()
	_finish()


func _test_solar_facility_contract_and_exact_replay() -> void:
	var contract := CORE.interface_contract_v2()
	_expect(
		str(contract.get("ruleset_id", "")) == "v0.7.1"
			and int(contract.get("save_section_version", 0)) == 4
			and int(contract.get("solar_multiplier_application_count_per_channel", 0)) == 1
			and not bool(contract.get("production_runtime_connected", true)),
		"solar/victory publishes the detached V0.7.1 interface contract"
	)
	var dark := CORE.create_state(false, 1, "match.solar.contract")
	var sunlit := CORE.create_state(true, 1, "match.solar.sunlit")
	_expect(CORE.is_valid_state(dark) and CORE.is_valid_state(sunlit), "solar genesis states validate")
	_expect(is_equal_approx(CORE.solar_multiplier(false), 1.0), "dark multiplier is 1.0")
	_expect(is_equal_approx(CORE.solar_multiplier(true), 2.0), "sunlit multiplier is 2.0")

	var protected := {
		"card_supply": 12,
		"card_price": 7,
		"track_color": "energy",
	}
	var evaluated := CORE.evaluate_facility_work_rates(
		sunlit,
		{
			"factory_production_rate": 3.0,
			"market_demand_or_consumption_rate": 4.5,
			"warehouse_ingress_throughput": 5,
			"warehouse_egress_throughput": 6.25,
		},
		protected
	)
	var rates := evaluated.get("facility_work_rates", {}) as Dictionary
	_expect(is_equal_approx(float(rates.get("factory_production_rate", 0.0)), 6.0), "sunlight doubles factory work rate")
	_expect(is_equal_approx(float(rates.get("market_demand_or_consumption_rate", 0.0)), 9.0), "sunlight doubles market demand work rate")
	_expect(is_equal_approx(float(rates.get("warehouse_ingress_throughput", 0.0)), 10.0), "sunlight doubles warehouse ingress")
	_expect(is_equal_approx(float(rates.get("warehouse_egress_throughput", 0.0)), 12.5), "sunlight doubles warehouse egress")
	_expect(evaluated.get("protected_card_facts") == protected, "solar evaluation preserves protected card facts")
	_expect(CORE.evaluate_facility_work_rates(sunlit, {"card_price": 7}, protected).is_empty(), "solar rejects non-facility work-rate channels")

	var intent := _solar_intent(dark, "intent.solar.contract", true, 7)
	var committed := CORE.apply_solar_intent(dark, intent)
	var state := committed.get("state", {}) as Dictionary
	var receipt := committed.get("receipt", {}) as Dictionary
	_expect(CORE.is_valid_state(state), "solar transition produces a valid strict state")
	_expect(str(receipt.get("reason_code", "")) == "solar_state_committed", "solar transition emits a typed receipt")
	_expect(not str(receipt.get("intent_fingerprint", "")).is_empty(), "solar receipt persists the Intent fingerprint")
	_expect(CORE.apply_solar_intent(state, intent).get("receipt") == receipt, "identical solar replay returns the exact receipt")
	_expect(CORE.state_fingerprint(CORE.apply_solar_intent(state, intent).get("state", {}) as Dictionary) == CORE.state_fingerprint(state), "identical solar replay has zero mutation")


func _test_trusted_qualification_and_boundary_proofs() -> void:
	var fixture := _pending_fixture("match.proof.bound", "victory.proof.bound")
	var pending := fixture.get("state", {}) as Dictionary
	var authority = fixture.get("authority")
	_expect(CORE.is_valid_state(pending), "issued qualification proof creates a valid pending state")
	_expect(bool((pending.get("victory_gate", {}) as Dictionary).get("pending", false)), "trusted qualification proof enters pending")

	var unbound_state := CORE.create_state(false, 1, "match.proof.unbound")
	var issuing_authority := TestVictoryAuthorityPort.new(
		"issuer.proof.primary",
		RefCounted.new()
	)
	var wrong_authority := TestVictoryAuthorityPort.new(
		"issuer.proof.other",
		RefCounted.new()
	)
	var unbound_proof := _issue_qualification(
		issuing_authority,
		unbound_state,
		"proof.qualification.unbound",
		"victory.proof.unbound",
		true,
		10
	)
	var unbound_intent := _qualification_intent(
		unbound_state,
		"intent.qualification.unbound",
		"victory.proof.unbound",
		unbound_proof
	)
	var unbound := _submit_qualification(unbound_state, unbound_intent, wrong_authority)
	_expect(str((unbound.get("receipt", {}) as Dictionary).get("reason_code", "")) == "qualification_proof_unbound_or_forged", "qualification proof must be present in the supplied authority port")
	_expect(CORE.state_fingerprint(unbound.get("state", {}) as Dictionary) == CORE.state_fingerprint(unbound_state), "unbound qualification proof has zero mutation")

	var forged_intent := unbound_intent.duplicate(true)
	forged_intent["proof_fingerprint"] = FORGED_FINGERPRINT
	var forged := _submit_qualification(unbound_state, forged_intent, issuing_authority)
	_expect(str((forged.get("receipt", {}) as Dictionary).get("reason_code", "")) == "qualification_proof_unbound_or_forged", "forged qualification fingerprint is rejected")
	_expect(CORE.state_fingerprint(forged.get("state", {}) as Dictionary) == CORE.state_fingerprint(unbound_state), "forged qualification proof has zero mutation")

	var stale_proof := _issue_qualification(
		issuing_authority,
		unbound_state,
		"proof.qualification.stale",
		"victory.proof.stale",
		true,
		11,
		int(unbound_state.get("revision", 0)) + 1
	)
	var stale_intent := _qualification_intent(
		unbound_state,
		"intent.qualification.stale-proof",
		"victory.proof.stale",
		stale_proof
	)
	var stale := _submit_qualification(unbound_state, stale_intent, issuing_authority)
	_expect(str((stale.get("receipt", {}) as Dictionary).get("reason_code", "")) == "qualification_proof_revision_mismatch", "qualification proof binds the exact Core revision")

	var incomplete_boundary := _complete_boundary()
	incomplete_boundary["hand_maintenance_complete"] = false
	var incomplete_proof := _issue_boundary(
		authority,
		pending,
		"proof.boundary.incomplete",
		incomplete_boundary,
		true,
		"settlement.proof.incomplete",
		20
	)
	var incomplete_intent := _revalidation_intent(
		pending,
		"intent.boundary.incomplete",
		"victory.proof.bound",
		incomplete_proof
	)
	var incomplete := _revalidate(pending, incomplete_intent, authority)
	_expect(str((incomplete.get("receipt", {}) as Dictionary).get("reason_code", "")) == "macro_round_boundary_incomplete", "trusted proof with an incomplete boundary cannot settle")
	_expect(CORE.state_fingerprint(incomplete.get("state", {}) as Dictionary) == CORE.state_fingerprint(pending), "incomplete trusted boundary has zero mutation")

	var complete_proof := _issue_boundary(
		authority,
		pending,
		"proof.boundary.complete",
		_complete_boundary(),
		true,
		"final_settlement.proof.bound",
		21
	)
	var complete_intent := _revalidation_intent(
		pending,
		"intent.boundary.complete",
		"victory.proof.bound",
		complete_proof
	)
	var caller_boolean_injection := complete_intent.duplicate(true)
	caller_boolean_injection["revalidation_passed"] = true
	caller_boolean_injection["intent_id"] = "intent.boundary.caller-boolean"
	var injected := _revalidate(pending, caller_boolean_injection, authority)
	_expect(str((injected.get("receipt", {}) as Dictionary).get("reason_code", "")) == "victory_revalidation_intent_invalid", "revalidation Intent cannot carry caller-authored truth booleans")

	var other_authority := TestVictoryAuthorityPort.new(
		"issuer.boundary.other",
		RefCounted.new()
	)
	var unbound_boundary := _revalidate(pending, complete_intent, other_authority)
	_expect(str((unbound_boundary.get("receipt", {}) as Dictionary).get("reason_code", "")) == "boundary_proof_unbound_or_forged", "boundary proof must be issued by the supplied authority port")
	var forged_boundary_intent := complete_intent.duplicate(true)
	forged_boundary_intent["proof_fingerprint"] = FORGED_FINGERPRINT
	var forged_boundary := _revalidate(
		pending,
		forged_boundary_intent,
		authority
	)
	_expect(str((forged_boundary.get("receipt", {}) as Dictionary).get("reason_code", "")) == "boundary_proof_unbound_or_forged", "forged boundary proof fingerprint is rejected")
	var settled_outcome := _revalidate(pending, complete_intent, authority)
	var settled := settled_outcome.get("state", {}) as Dictionary
	_expect(bool((settled.get("victory_gate", {}) as Dictionary).get("final_settlement_committed", false)), "bound qualification and complete boundary proof commit FinalSettlement")
	_expect(int((settled.get("victory_gate", {}) as Dictionary).get("final_settlement_count", 0)) == 1, "trusted settlement commits exactly once")

	var failed_fixture := _pending_fixture("match.proof.failed", "victory.proof.failed")
	var failed_pending := failed_fixture.get("state", {}) as Dictionary
	var failed_authority = failed_fixture.get("authority")
	var failed_proof := _issue_boundary(
		failed_authority,
		failed_pending,
		"proof.boundary.failed",
		_complete_boundary(),
		false,
		"",
		30
	)
	var failed := _revalidate(
		failed_pending,
		_revalidation_intent(
			failed_pending,
			"intent.boundary.failed",
			"victory.proof.failed",
			failed_proof
		),
		failed_authority
	)
	var failed_gate := (failed.get("state", {}) as Dictionary).get("victory_gate", {}) as Dictionary
	_expect(not bool(failed_gate.get("pending", true)) and not bool(failed_gate.get("final_settlement_committed", true)), "trusted failed revalidation clears pending and continues")


func _test_external_authority_capability_and_source_identity() -> void:
	var core_source := FileAccess.get_file_as_string(
		"res://scripts/v07_semantic/v07_solar_victory_core.gd"
	)
	_expect(
		not core_source.contains("create_trusted_authority_port")
			and not core_source.contains("class TrustedVictoryBoundaryAuthorityPort"),
		"Core exposes no trusted-authority constructor or fixture class"
	)
	var state := CORE.create_state(false, 1, "match.external.authority")
	var authority := TestVictoryAuthorityPort.new(
		"issuer.external.primary",
		RefCounted.new(),
		10
	)
	var proof := _issue_qualification(
		authority,
		state,
		"proof.external.qualification",
		"victory.external.authority",
		true,
		10
	)
	var intent := _qualification_intent(
		state,
		"intent.external.qualification",
		"victory.external.authority",
		proof
	)
	var wrong_capability := CORE.submit_victory_qualification(
		state,
		intent,
		authority,
		RefCounted.new()
	)
	_expect(
		str((wrong_capability.get("receipt", {}) as Dictionary).get(
			"reason_code", ""
		)) == "trusted_victory_capability_required",
		"qualification requires the exact provisioned capability object"
	)
	var narrow_port_required := CORE.submit_victory_qualification(
		state,
		intent,
		RefCounted.new(),
		RefCounted.new()
	)
	_expect(
		str((narrow_port_required.get("receipt", {}) as Dictionary).get(
			"reason_code", ""
		)) == "trusted_victory_authority_required",
		"duck-typed absence of the narrow lookup contract fails closed"
	)

	var bad_authority := TestVictoryAuthorityPort.new(
		"issuer.external.bad-authority",
		RefCounted.new(),
		10,
		"v07.victory.untrusted",
		CORE.TRUSTED_SOURCE_AUTHORITY_ID
	)
	var bad_authority_proof := _issue_qualification(
		bad_authority,
		state,
		"proof.external.bad-authority",
		"victory.external.authority",
		true,
		10
	)
	var bad_authority_outcome := _submit_qualification(
		state,
		_qualification_intent(
			state,
			"intent.external.bad-authority",
			"victory.external.authority",
			bad_authority_proof
		),
		bad_authority
	)
	_expect(
		str((bad_authority_outcome.get("receipt", {}) as Dictionary).get(
			"reason_code", ""
		)) == "trusted_victory_authority_identity_invalid",
		"authority_id must equal the canonical trusted authority identity"
	)
	var bad_source := TestVictoryAuthorityPort.new(
		"issuer.external.bad-source",
		RefCounted.new(),
		10,
		CORE.TRUSTED_AUTHORITY_ID,
		"v07.victory.untrusted-source"
	)
	var bad_source_proof := _issue_qualification(
		bad_source,
		state,
		"proof.external.bad-source",
		"victory.external.authority",
		true,
		10
	)
	var bad_source_outcome := _submit_qualification(
		state,
		_qualification_intent(
			state,
			"intent.external.bad-source",
			"victory.external.authority",
			bad_source_proof
		),
		bad_source
	)
	_expect(
		str((bad_source_outcome.get("receipt", {}) as Dictionary).get(
			"reason_code", ""
		)) == "trusted_victory_authority_identity_invalid",
		"source_authority_id must equal the canonical proof-source identity"
	)

	for mismatch in [
		{"label": "stale", "proof_revision": 9, "reported_revision": 10},
		{"label": "future", "proof_revision": 11, "reported_revision": 10},
	]:
		var mismatch_proof := _issue_qualification(
			authority,
			state,
			"proof.external.%s-source" % mismatch.get("label"),
			"victory.external.authority",
			true,
			int(mismatch.get("proof_revision")),
			-1,
			int(mismatch.get("reported_revision"))
		)
		var mismatch_outcome := _submit_qualification(
			state,
			_qualification_intent(
				state,
				"intent.external.%s-source" % mismatch.get("label"),
				"victory.external.authority",
				mismatch_proof
			),
			authority
		)
		_expect(
			str((mismatch_outcome.get("receipt", {}) as Dictionary).get(
				"reason_code", ""
			)) == "qualification_proof_source_revision_mismatch",
			"qualification rejects %s source revision against the port" % mismatch.get("label")
		)

	authority.set_current_source_revision(10)
	var pending_outcome := _submit_qualification(state, intent, authority)
	var pending := pending_outcome.get("state", {}) as Dictionary
	var pending_gate := pending.get("victory_gate", {}) as Dictionary
	_expect(
		pending_gate.get("pending_qualification_authority_id")
			== CORE.TRUSTED_AUTHORITY_ID
			and pending_gate.get("pending_qualification_source_authority_id")
				== CORE.TRUSTED_SOURCE_AUTHORITY_ID
			and pending_gate.get("pending_qualification_issuer_instance_id")
				== "issuer.external.primary"
			and int(pending_gate.get("pending_qualification_source_revision", -1)) == 10,
		"pending qualification persists exact issuer, source identity, and revision"
	)

	var cross_issuer := TestVictoryAuthorityPort.new(
		"issuer.external.cross",
		RefCounted.new(),
		20
	)
	var cross_proof := _issue_boundary(
		cross_issuer,
		pending,
		"proof.external.cross-issuer",
		_complete_boundary(),
		true,
		"settlement.external.cross-issuer",
		20
	)
	var cross_outcome := _revalidate(
		pending,
		_revalidation_intent(
			pending,
			"intent.external.cross-issuer",
			"victory.external.authority",
			cross_proof
		),
		cross_issuer
	)
	_expect(
		str((cross_outcome.get("receipt", {}) as Dictionary).get(
			"reason_code", ""
		)) == "boundary_proof_qualification_binding_mismatch",
		"a different logical issuer cannot reissue the pending boundary proof"
	)
	for mismatch in [
		{"label": "stale", "proof_revision": 19, "reported_revision": 20},
		{"label": "future", "proof_revision": 21, "reported_revision": 20},
	]:
		var mismatch_proof := _issue_boundary(
			authority,
			pending,
			"proof.external.boundary-%s" % mismatch.get("label"),
			_complete_boundary(),
			true,
			"settlement.external.boundary-%s" % mismatch.get("label"),
			int(mismatch.get("proof_revision")),
			int(mismatch.get("reported_revision"))
		)
		var mismatch_outcome := _revalidate(
			pending,
			_revalidation_intent(
				pending,
				"intent.external.boundary-%s" % mismatch.get("label"),
				"victory.external.authority",
				mismatch_proof
			),
			authority
		)
		_expect(
			str((mismatch_outcome.get("receipt", {}) as Dictionary).get(
				"reason_code", ""
			)) == "boundary_proof_source_revision_mismatch",
			"boundary rejects %s source revision against the port" % mismatch.get("label")
		)

	var restored_pending := _save_restore_state(pending)
	var exact_boundary_proof := _issue_boundary(
		authority,
		restored_pending,
		"proof.external.boundary-exact",
		_complete_boundary(),
		true,
		"settlement.external.exact",
		20
	)
	var exact_boundary := _revalidate(
		restored_pending,
		_revalidation_intent(
			restored_pending,
			"intent.external.boundary-exact",
			"victory.external.authority",
			exact_boundary_proof
		),
		authority
	)
	_expect(
		bool(((exact_boundary.get("state", {}) as Dictionary).get(
			"victory_gate", {}
		) as Dictionary).get("final_settlement_committed", false)),
		"same issuer and exact port-reported source revision settle after Save restore"
	)


func _test_all_intent_collisions_and_restored_replay() -> void:
	var solar_initial := CORE.create_state(false, 1, "match.collision.solar")
	var solar_intent := _solar_intent(solar_initial, "intent.collision.solar", true, 1)
	var solar_outcome := CORE.apply_solar_intent(solar_initial, solar_intent)
	var solar_state := solar_outcome.get("state", {}) as Dictionary
	var solar_receipt := solar_outcome.get("receipt", {}) as Dictionary
	var solar_substitute := _solar_intent(solar_state, "intent.collision.solar", false, 2)
	_assert_collision(
		CORE.apply_solar_intent(solar_state, solar_substitute),
		solar_state,
		"solar payload collision"
	)
	var cross_authority := TestVictoryAuthorityPort.new(
		"issuer.collision.cross-kind",
		RefCounted.new()
	)
	var cross_proof := _issue_qualification(
		cross_authority,
		solar_state,
		"proof.collision.cross-kind",
		"victory.collision.cross-kind",
		true,
		2
	)
	_assert_collision(
		_submit_qualification(
			solar_state,
			_qualification_intent(
				solar_state,
				"intent.collision.solar",
				"victory.collision.cross-kind",
				cross_proof
			),
			cross_authority
		),
		solar_state,
		"cross-kind collision"
	)
	var solar_restored := _save_restore_state(solar_state)
	var solar_replay := CORE.apply_solar_intent(solar_restored, solar_intent)
	_expect(solar_replay.get("receipt") == solar_receipt, "restored solar replay returns the exact original receipt")
	_expect(CORE.state_fingerprint(solar_replay.get("state", {}) as Dictionary) == CORE.state_fingerprint(solar_restored), "restored solar replay has zero mutation")
	_assert_collision(
		CORE.apply_solar_intent(solar_restored, solar_substitute),
		solar_restored,
		"restored solar payload collision"
	)

	var qualification_initial := CORE.create_state(false, 1, "match.collision.qualification")
	var qualification_authority := TestVictoryAuthorityPort.new(
		"issuer.collision.qualification",
		RefCounted.new()
	)
	var qualification_proof := _issue_qualification(
		qualification_authority,
		qualification_initial,
		"proof.collision.qualification.original",
		"victory.collision.qualification",
		true,
		10
	)
	var qualification_intent := _qualification_intent(
		qualification_initial,
		"intent.collision.qualification",
		"victory.collision.qualification",
		qualification_proof
	)
	var qualification_outcome := _submit_qualification(
		qualification_initial,
		qualification_intent,
		qualification_authority
	)
	var qualification_state := qualification_outcome.get("state", {}) as Dictionary
	var qualification_receipt := qualification_outcome.get("receipt", {}) as Dictionary
	var substitute_proof := _issue_qualification(
		qualification_authority,
		qualification_state,
		"proof.collision.qualification.substitute",
		"victory.collision.substitute",
		false,
		11
	)
	_assert_collision(
		_submit_qualification(
			qualification_state,
			_qualification_intent(
				qualification_state,
				"intent.collision.qualification",
				"victory.collision.substitute",
				substitute_proof
			),
			qualification_authority
		),
		qualification_state,
		"qualification payload collision"
	)
	var qualification_restored := _save_restore_state(qualification_state)
	var qualification_replay := _submit_qualification(
		qualification_restored,
		qualification_intent,
		qualification_authority
	)
	_expect(qualification_replay.get("receipt") == qualification_receipt, "restored qualification replay returns the exact original receipt")
	_expect(CORE.state_fingerprint(qualification_replay.get("state", {}) as Dictionary) == CORE.state_fingerprint(qualification_restored), "restored qualification replay has zero mutation")
	_assert_collision(
		_submit_qualification(
			qualification_restored,
			_qualification_intent(
				qualification_restored,
				"intent.collision.qualification",
				"victory.collision.substitute",
				substitute_proof
			),
			qualification_authority
		),
		qualification_restored,
		"restored qualification payload collision"
	)

	var fixture := _pending_fixture("match.collision.revalidation", "victory.collision.revalidation")
	var revalidation_pending := fixture.get("state", {}) as Dictionary
	var revalidation_authority = fixture.get("authority")
	var revalidation_proof := _issue_boundary(
		revalidation_authority,
		revalidation_pending,
		"proof.collision.revalidation.original",
		_complete_boundary(),
		true,
		"final_settlement.collision.original",
		20
	)
	var revalidation_intent := _revalidation_intent(
		revalidation_pending,
		"intent.collision.revalidation",
		"victory.collision.revalidation",
		revalidation_proof
	)
	var revalidation_outcome := _revalidate(
		revalidation_pending,
		revalidation_intent,
		revalidation_authority
	)
	var revalidation_state := revalidation_outcome.get("state", {}) as Dictionary
	var revalidation_receipt := revalidation_outcome.get("receipt", {}) as Dictionary
	var alternate_proof := _issue_boundary(
		revalidation_authority,
		revalidation_pending,
		"proof.collision.revalidation.substitute",
		_complete_boundary(),
		false,
		"",
		21
	)
	var revalidation_substitute := _revalidation_intent(
		revalidation_state,
		"intent.collision.revalidation",
		"victory.collision.revalidation",
		alternate_proof
	)
	_assert_collision(
		_revalidate(
			revalidation_state,
			revalidation_substitute,
			revalidation_authority
		),
		revalidation_state,
		"revalidation payload collision"
	)
	var revalidation_restored := _save_restore_state(revalidation_state)
	var revalidation_replay := _revalidate(
		revalidation_restored,
		revalidation_intent,
		revalidation_authority
	)
	_expect(revalidation_replay.get("receipt") == revalidation_receipt, "restored revalidation replay returns the exact original receipt")
	_expect(CORE.state_fingerprint(revalidation_replay.get("state", {}) as Dictionary) == CORE.state_fingerprint(revalidation_restored), "restored revalidation replay has zero mutation")
	_assert_collision(
		_revalidate(
			revalidation_restored,
			revalidation_substitute,
			revalidation_authority
		),
		revalidation_restored,
		"restored revalidation payload collision"
	)


func _test_wrong_entrypoint_exact_replay_rejected() -> void:
	var solar_initial := CORE.create_state(false, 1, "match.wrong-entry.solar")
	var solar_intent := _solar_intent(
		solar_initial,
		"intent.wrong-entry.solar",
		true,
		1
	)
	var solar_state := CORE.apply_solar_intent(
		solar_initial,
		solar_intent
	).get("state", {}) as Dictionary

	var qualification_fixture := _pending_fixture(
		"match.wrong-entry.qualification",
		"victory.wrong-entry.qualification"
	)
	var qualification_state := qualification_fixture.get("state", {}) as Dictionary
	var qualification_intent := qualification_fixture.get(
		"qualification_intent", {}
	) as Dictionary

	var revalidation_fixture := _pending_fixture(
		"match.wrong-entry.revalidation",
		"victory.wrong-entry.revalidation"
	)
	var revalidation_pending := revalidation_fixture.get("state", {}) as Dictionary
	var revalidation_authority = revalidation_fixture.get("authority")
	var revalidation_proof := _issue_boundary(
		revalidation_authority,
		revalidation_pending,
		"proof.wrong-entry.revalidation",
		_complete_boundary(),
		true,
		"settlement.wrong-entry.revalidation",
		2
	)
	var revalidation_intent := _revalidation_intent(
		revalidation_pending,
		"intent.wrong-entry.revalidation",
		"victory.wrong-entry.revalidation",
		revalidation_proof
	)
	var revalidation_state := _revalidate(
		revalidation_pending,
		revalidation_intent,
		revalidation_authority
	).get("state", {}) as Dictionary

	var cases := [
		{
			"label": "solar through qualification",
			"state": solar_state,
			"intent": solar_intent,
			"entrypoint": "qualification",
			"reason": "victory_qualification_intent_invalid",
		},
		{
			"label": "solar through revalidation",
			"state": solar_state,
			"intent": solar_intent,
			"entrypoint": "revalidation",
			"reason": "victory_revalidation_intent_invalid",
		},
		{
			"label": "qualification through solar",
			"state": qualification_state,
			"intent": qualification_intent,
			"entrypoint": "solar",
			"reason": "solar_intent_invalid",
		},
		{
			"label": "qualification through revalidation",
			"state": qualification_state,
			"intent": qualification_intent,
			"entrypoint": "revalidation",
			"reason": "victory_revalidation_intent_invalid",
		},
		{
			"label": "revalidation through solar",
			"state": revalidation_state,
			"intent": revalidation_intent,
			"entrypoint": "solar",
			"reason": "solar_intent_invalid",
		},
		{
			"label": "revalidation through qualification",
			"state": revalidation_state,
			"intent": revalidation_intent,
			"entrypoint": "qualification",
			"reason": "victory_qualification_intent_invalid",
		},
	]
	for case_variant in cases:
		var case := case_variant as Dictionary
		for restored in [false, true]:
			var source_state := case.get("state", {}) as Dictionary
			var tested_state := _save_restore_state(source_state) \
				if restored else source_state
			var outcome := _invoke_entrypoint(
				str(case.get("entrypoint", "")),
				tested_state,
				case.get("intent", {}) as Dictionary
			)
			var receipt := outcome.get("receipt", {}) as Dictionary
			var phase := "after Save" if restored else "before Save"
			_expect(
				str(receipt.get("reason_code", "")) == str(case.get("reason", "")),
				"%s is rejected by the wrong entrypoint %s" % [case.get("label"), phase]
			)
			_expect(
				receipt.get("accepted") == false and receipt.get("committed") == false,
				"%s does not replay a foreign committed receipt %s" % [case.get("label"), phase]
			)
			_expect(
				CORE.state_fingerprint(outcome.get("state", {}) as Dictionary)
					== CORE.state_fingerprint(tested_state),
				"%s has zero mutation %s" % [case.get("label"), phase]
			)


func _test_strict_state_receipt_and_save_validation() -> void:
	var initial := CORE.create_state(false, 1, "match.strict.save")
	_expect(
		str(initial.get("ruleset_id", "")) == "v0.7.1"
			and str(initial.get("balance_profile_id", ""))
				== "V071_CANDIDATE_A_FAST"
			and str(initial.get("balance_profile_fingerprint", ""))
				== CORE.BALANCE_PROFILE_FINGERPRINT,
		"solar/victory state binds the approved V0.7.1 balance profile"
	)
	var state := CORE.apply_solar_intent(
		initial,
		_solar_intent(initial, "intent.strict.save", true, 9007199254740993)
	).get("state", {}) as Dictionary
	_expect(CORE.is_valid_state(state), "nontrivial state validates before adversarial mutation")

	var erased := state.duplicate(true)
	erased["processed_intent_ids"] = []
	erased["receipt_ledger"] = {}
	_expect(not CORE.is_valid_state(erased), "nonzero revision cannot erase both exact-once ledgers")
	_expect(CORE.to_save_state(erased).is_empty(), "Save capture rejects erased exact-once ledgers")

	var intent_id := str((state.get("processed_intent_ids", []) as Array)[0])
	var wrong_kind := state.duplicate(true)
	var wrong_kind_receipt := (wrong_kind.get("receipt_ledger", {}) as Dictionary).get(intent_id, {}) as Dictionary
	wrong_kind_receipt["intent_kind_id"] = CORE.INTENT_KIND_QUALIFICATION
	wrong_kind_receipt["receipt_fingerprint"] = _fingerprint_without(wrong_kind_receipt, "receipt_fingerprint")
	_expect(not CORE.is_valid_state(wrong_kind), "receipt kind substitution fails strict validation")

	var wrong_revision := state.duplicate(true)
	var wrong_revision_receipt := (wrong_revision.get("receipt_ledger", {}) as Dictionary).get(intent_id, {}) as Dictionary
	wrong_revision_receipt["state_revision_after"] = 2
	wrong_revision_receipt["receipt_fingerprint"] = _fingerprint_without(wrong_revision_receipt, "receipt_fingerprint")
	_expect(not CORE.is_valid_state(wrong_revision), "receipt revision gap fails strict validation")

	var save := CORE.to_save_state(state)
	var restored := _save_restore_state(state)
	_expect(CORE.state_fingerprint(restored) == CORE.state_fingerprint(state), "strict Save roundtrip preserves exact state")
	_expect(int((restored.get("solar", {}) as Dictionary).get("source_revision", 0)) == 9007199254740993, "tagged Int64 preserves a wide authority source revision")

	var forged_save := save.duplicate(true)
	var encoded_state := forged_save.get("state", {}) as Dictionary
	encoded_state["processed_intent_ids"] = []
	encoded_state["receipt_ledger"] = {}
	forged_save["save_fingerprint"] = _fingerprint_without(forged_save, "save_fingerprint")
	_expect(CORE.from_save_state(forged_save).is_empty(), "validly resealed Save cannot erase nonzero-revision ledgers")

	var truncated := save.duplicate(true)
	truncated.erase("source_state_fingerprint")
	_expect(CORE.from_save_state(truncated).is_empty(), "Save requires its exact source-state fingerprint field")
	var wrong_section := save.duplicate(true)
	wrong_section["section_version"] = 3
	wrong_section["save_fingerprint"] = _fingerprint_without(wrong_section, "save_fingerprint")
	_expect(CORE.from_save_state(wrong_section).is_empty(), "historical V0.7 section version fails closed under V0.7.1")

	var wrong_profile := state.duplicate(true)
	wrong_profile["balance_profile_fingerprint"] = FORGED_FINGERPRINT
	_expect(
		not CORE.is_valid_state(wrong_profile)
			and CORE.from_save_state(_resealed_save_from_state(wrong_profile)).is_empty(),
		"wrong V0.7.1 balance-profile fingerprint fails before restore"
	)
	var historical_v07 := state.duplicate(true)
	historical_v07["schema_version"] = 1
	historical_v07["ruleset_id"] = "v0.7"
	_expect(
		CORE.from_save_state(_resealed_save_from_state(historical_v07)).is_empty(),
		"V0.7 detached state is never silently interpreted as V0.7.1"
	)


func _test_coordinated_ledger_and_wire_attacks() -> void:
	var initial := CORE.create_state(false, 1, "match.ledger.attacks")
	var first_intent := _solar_intent(
		initial,
		"intent.ledger.attack.first",
		true,
		1
	)
	var state := CORE.apply_solar_intent(initial, first_intent).get(
		"state", {}
	) as Dictionary
	var first_id := str((state.get("processed_intent_ids", []) as Array)[0])

	var false_outcome := state.duplicate(true)
	var false_receipt := (
		false_outcome.get("receipt_ledger", {}) as Dictionary
	).get(first_id, {}) as Dictionary
	false_receipt["victory_pending"] = true
	_reseal_receipt(false_receipt)
	_expect(
		not CORE.is_valid_state(false_outcome),
		"receipt outcome booleans cannot contradict the replayed gate"
	)
	_expect(
		CORE.from_save_state(_resealed_save_from_state(false_outcome)).is_empty(),
		"coordinated Save reseal cannot inject a false receipt outcome"
	)

	var pending_fixture := _pending_fixture(
		"match.ledger.coordinated",
		"victory.ledger.coordinated"
	)
	var pending := pending_fixture.get("state", {}) as Dictionary
	var after_pending_solar := CORE.apply_solar_intent(
		pending,
		_solar_intent(
			pending,
			"intent.ledger.coordinated.solar",
			true,
			1
		)
	).get("state", {}) as Dictionary
	var coordinated := after_pending_solar.duplicate(true)
	var coordinated_ids := coordinated.get("processed_intent_ids", []) as Array
	var coordinated_ledger := coordinated.get("receipt_ledger", {}) as Dictionary
	var qualification_id := str(coordinated_ids[0])
	var following_id := str(coordinated_ids[1])
	var qualification_receipt := coordinated_ledger.get(
		qualification_id, {}
	) as Dictionary
	qualification_receipt["reason_code"] = "existing_victory_pending_preserved"
	_reseal_receipt(qualification_receipt)
	var following_receipt := coordinated_ledger.get(following_id, {}) as Dictionary
	following_receipt["predecessor_receipt_fingerprint"] = qualification_receipt.get(
		"receipt_fingerprint"
	)
	_reseal_receipt(following_receipt)
	_expect(
		not CORE.is_valid_state(coordinated),
		"ledger replay rejects a coordinated allowed-reason substitution and repaired hash chain"
	)
	_expect(
		CORE.from_save_state(_resealed_save_from_state(coordinated)).is_empty(),
		"Save restore rejects a coordinated receipt, successor, state, and envelope reseal"
	)

	var broken_chain := after_pending_solar.duplicate(true)
	var broken_ids := broken_chain.get("processed_intent_ids", []) as Array
	var broken_second := (
		broken_chain.get("receipt_ledger", {}) as Dictionary
	).get(str(broken_ids[1]), {}) as Dictionary
	broken_second["source_state_fingerprint"] = FORGED_FINGERPRINT
	_reseal_receipt(broken_second)
	_expect(not CORE.is_valid_state(broken_chain), "receipt source-state chain rejects substitution")

	var raw_state_version := state.duplicate(true)
	raw_state_version["schema_version"] = 1.0
	_expect(not CORE.is_valid_state(raw_state_version), "decoded state schema_version requires a true int")
	_expect(CORE.to_save_state(raw_state_version).is_empty(), "Save capture rejects raw-float state integers")
	var raw_receipt_revision := state.duplicate(true)
	var raw_receipt := (
		raw_receipt_revision.get("receipt_ledger", {}) as Dictionary
	).get(first_id, {}) as Dictionary
	raw_receipt["state_revision_before"] = 0.0
	_reseal_receipt(raw_receipt)
	_expect(not CORE.is_valid_state(raw_receipt_revision), "receipt revisions require true ints")

	var canonical_save := CORE.to_save_state(state)
	var raw_float_save := canonical_save.duplicate(true)
	(raw_float_save.get("state", {}) as Dictionary)["schema_version"] = 1.0
	_reseal_save(raw_float_save)
	_expect(CORE.from_save_state(raw_float_save).is_empty(), "Save restore rejects raw-float tagged state integers")
	var raw_receipt_save := canonical_save.duplicate(true)
	var encoded_state := raw_receipt_save.get("state", {}) as Dictionary
	var encoded_ledger := encoded_state.get("receipt_ledger", {}) as Dictionary
	(encoded_ledger.get(first_id, {}) as Dictionary)["state_revision_before"] = 0.0
	_reseal_save(raw_receipt_save)
	_expect(CORE.from_save_state(raw_receipt_save).is_empty(), "Save restore rejects raw-float receipt integers")

	var malformed_tags := [
		{"type": "int64", "decimal": "01"},
		{"type": "int64", "decimal": "+1"},
		{"type": "int32", "decimal": "1"},
		{"type": "int64", "decimal": "1", "extra": true},
		{"type": "int64", "decimal": "999999999999999999999999999999"},
	]
	for index in range(malformed_tags.size()):
		var malformed := canonical_save.duplicate(true)
		(malformed.get("state", {}) as Dictionary)["revision"] = (
			malformed_tags[index] as Dictionary
		).duplicate(true)
		_reseal_save(malformed)
		_expect(
			CORE.from_save_state(malformed).is_empty(),
			"Save restore rejects malformed or noncanonical tagged Int64 case %d" % index
		)


func _test_checkpoint_lineage_and_settlement_barrier() -> void:
	var initial := CORE.create_state(false, 2, "match.rollback.primary")
	var ancestor := CORE.checkpoint(initial)
	var branch_a := CORE.apply_solar_intent(
		initial,
		_solar_intent(initial, "intent.rollback.a", true, 1)
	).get("state", {}) as Dictionary
	var branch_b := CORE.apply_solar_intent(
		initial,
		_solar_intent(initial, "intent.rollback.b", true, 1)
	).get("state", {}) as Dictionary
	var ancestor_result := CORE.rollback_detailed(branch_a, ancestor)
	_expect(bool(ancestor_result.get("rolled_back", false)), "rollback accepts an exact receipt-prefix ancestor")
	_expect(CORE.state_fingerprint(ancestor_result.get("state", {}) as Dictionary) == CORE.state_fingerprint(initial), "ancestor rollback restores the exact checkpoint")

	var future := CORE.rollback_detailed(initial, CORE.checkpoint(branch_a))
	_expect(str(future.get("reason_code", "")) == "checkpoint_from_future", "rollback rejects a future checkpoint")
	_expect(CORE.state_fingerprint(future.get("state", {}) as Dictionary) == CORE.state_fingerprint(initial), "future checkpoint rejection has zero mutation")

	var divergent := CORE.rollback_detailed(branch_a, CORE.checkpoint(branch_b))
	_expect(str(divergent.get("reason_code", "")) == "checkpoint_not_current_lineage", "rollback rejects a same-match divergent receipt branch")
	_expect(CORE.state_fingerprint(divergent.get("state", {}) as Dictionary) == CORE.state_fingerprint(branch_a), "divergent checkpoint rejection has zero mutation")

	var foreign := CORE.create_state(false, 2, "match.rollback.foreign")
	var foreign_result := CORE.rollback_detailed(branch_a, CORE.checkpoint(foreign))
	_expect(str(foreign_result.get("reason_code", "")) == "checkpoint_lineage_mismatch", "rollback rejects a different match_instance_id")
	var different_genesis := CORE.create_state(true, 2, "match.rollback.primary")
	var genesis_result := CORE.rollback_detailed(branch_a, CORE.checkpoint(different_genesis))
	_expect(str(genesis_result.get("reason_code", "")) == "checkpoint_lineage_mismatch", "rollback rejects the same match ID with a different genesis")

	var fixture := _pending_fixture("match.rollback.settlement", "victory.rollback.settlement")
	var pending := fixture.get("state", {}) as Dictionary
	var authority = fixture.get("authority")
	var before_settlement := CORE.checkpoint(pending)
	var proof := _issue_boundary(
		authority,
		pending,
		"proof.rollback.settlement",
		_complete_boundary(),
		true,
		"final_settlement.rollback.barrier",
		50
	)
	var settled := _revalidate(
		pending,
		_revalidation_intent(
			pending,
			"intent.rollback.settlement",
			"victory.rollback.settlement",
			proof
		),
		authority
	).get("state", {}) as Dictionary
	var forbidden := CORE.rollback_detailed(settled, before_settlement)
	_expect(str(forbidden.get("reason_code", "")) == "rollback_crosses_final_settlement", "rollback cannot cross an already committed FinalSettlement")
	_expect(CORE.state_fingerprint(forbidden.get("state", {}) as Dictionary) == CORE.state_fingerprint(settled), "FinalSettlement rollback rejection has zero mutation")


func _test_recursive_projection_and_save_privacy() -> void:
	var condition_sentinel := "private.condition.recursive.7f31"
	var fixture := _pending_fixture("match.privacy.recursive", condition_sentinel)
	var pending := fixture.get("state", {}) as Dictionary
	var authority = fixture.get("authority")
	var qualification_proof := fixture.get("qualification_proof", {}) as Dictionary
	var proof_id_sentinel := str(qualification_proof.get("proof_id", ""))
	var proof_fingerprint_sentinel := str(qualification_proof.get("proof_fingerprint", ""))
	var issuer_sentinel := str(qualification_proof.get("issuer_instance_id", ""))
	var ai := CORE.ai_observation(pending)
	var player := CORE.player_projection(pending)
	for projection_variant in [ai, player]:
		var projection := projection_variant as Dictionary
		for key in [
			"pending_condition_id",
			"pending_trigger_intent_id",
			"pending_qualification_proof_id",
			"pending_qualification_proof_fingerprint",
			"pending_qualification_authority_id",
			"pending_qualification_source_authority_id",
			"pending_qualification_issuer_instance_id",
			"processed_intent_ids",
			"receipt_ledger",
			"proof_authority_id",
			"proof_source_authority_id",
			"proof_issuer_instance_id",
			"intent_payload",
			"authority_port",
			"_issued_proofs",
		]:
			_expect(not _contains_exact_key(projection, key), "viewer projection recursively redacts %s" % key)
		for sentinel in [
			condition_sentinel,
			proof_id_sentinel,
			proof_fingerprint_sentinel,
			issuer_sentinel,
		]:
			_expect(not _contains_exact_value(projection, sentinel), "viewer projection recursively redacts private proof value")

	var boundary_proof := _issue_boundary(
		authority,
		pending,
		"proof.privacy.boundary",
		_complete_boundary(),
		true,
		"private.final.settlement.recursive",
		60
	)
	var settled := _revalidate(
		pending,
		_revalidation_intent(
			pending,
			"intent.privacy.boundary",
			condition_sentinel,
			boundary_proof
		),
		authority
	).get("state", {}) as Dictionary
	for projection_variant in [CORE.ai_observation(settled), CORE.player_projection(settled)]:
		var projection := projection_variant as Dictionary
		_expect(not _contains_exact_value(projection, "private.final.settlement.recursive"), "settled projection recursively redacts settlement identity")
		_expect(not _contains_exact_key(projection, "final_settlement_receipt_id"), "settled projection recursively redacts settlement receipt identity")

	var save := CORE.to_save_state(pending)
	_expect(authority is RefCounted and not is_instance_of(authority, Node), "trusted authority port is pure RefCounted and not Node")
	_expect(_is_pure_data(save), "Save contains pure data and no authority object")
	_expect(not _contains_exact_key(save, "authority_port") and not _contains_exact_key(save, "_issued_proofs"), "Save excludes the authority object and its proof repository")
	_expect(not _contains_exact_key(pending, "authority_id"), "Core state persists logical issuer fields without serializing the port object")
	_expect(
		_contains_exact_value(save, issuer_sentinel)
			and _contains_exact_value(save, CORE.TRUSTED_SOURCE_AUTHORITY_ID),
		"private Save persists logical issuer and source authority identity"
	)


func _pending_fixture(match_instance_id: String, condition_id: String) -> Dictionary:
	var state := CORE.create_state(false, 1, match_instance_id)
	var authority := TestVictoryAuthorityPort.new(
		"issuer.%s" % match_instance_id,
		RefCounted.new()
	)
	var proof := _issue_qualification(
		authority,
		state,
		"proof.qualification.%s" % condition_id,
		condition_id,
		true,
		1
	)
	var intent := _qualification_intent(
		state,
		"intent.qualification.%s" % condition_id,
		condition_id,
		proof
	)
	var outcome := _submit_qualification(state, intent, authority)
	return {
		"state": outcome.get("state", {}) as Dictionary,
		"authority": authority,
		"qualification_proof": proof,
		"qualification_intent": intent,
		"qualification_receipt": outcome.get("receipt", {}) as Dictionary,
	}


func _issue_qualification(
	authority,
	state: Dictionary,
	proof_id: String,
	condition_id: String,
	qualifies: bool,
	source_revision: int,
	expected_core_revision: int = -1,
	reported_source_revision: int = -1
) -> Dictionary:
	var gate := state.get("victory_gate", {}) as Dictionary
	authority.set_current_source_revision(
		source_revision if reported_source_revision < 0 else reported_source_revision
	)
	return authority.issue_qualification_proof(
		proof_id,
		str(state.get("match_instance_id", "")),
		str(state.get("genesis_fingerprint", "")),
		int(state.get("revision", 0)) if expected_core_revision < 0 else expected_core_revision,
		source_revision,
		int(gate.get("macro_round_index", 0)),
		condition_id,
		qualifies
	)


func _issue_boundary(
	authority,
	state: Dictionary,
	proof_id: String,
	boundary: Dictionary,
	revalidation_passed: bool,
	final_settlement_id: String,
	source_revision: int,
	reported_source_revision: int = -1
) -> Dictionary:
	var gate := state.get("victory_gate", {}) as Dictionary
	authority.set_current_source_revision(
		source_revision if reported_source_revision < 0 else reported_source_revision
	)
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


func _submit_qualification(
	state: Dictionary,
	intent: Dictionary,
	authority,
	capability: Variant = null
) -> Dictionary:
	var supplied_capability: Variant = capability
	if supplied_capability == null and authority != null \
			and authority.has_method("capability"):
		supplied_capability = authority.capability()
	return CORE.submit_victory_qualification(
		state,
		intent,
		authority,
		supplied_capability
	)


func _revalidate(
	state: Dictionary,
	intent: Dictionary,
	authority,
	capability: Variant = null
) -> Dictionary:
	var supplied_capability: Variant = capability
	if supplied_capability == null and authority != null \
			and authority.has_method("capability"):
		supplied_capability = authority.capability()
	return CORE.revalidate_victory_at_boundary(
		state,
		intent,
		authority,
		supplied_capability
	)


func _invoke_entrypoint(
	entrypoint: String,
	state: Dictionary,
	intent: Dictionary
) -> Dictionary:
	match entrypoint:
		"solar":
			return CORE.apply_solar_intent(state, intent)
		"qualification":
			return CORE.submit_victory_qualification(state, intent, null, null)
		"revalidation":
			return CORE.revalidate_victory_at_boundary(state, intent, null, null)
	return {}


func _solar_intent(
	state: Dictionary,
	intent_id: String,
	sunlit: bool,
	source_revision: int
) -> Dictionary:
	return {
		"schema_version": CORE.SCHEMA_VERSION,
		"intent_id": intent_id,
		"intent_kind_id": CORE.INTENT_KIND_SOLAR,
		"expected_revision": int(state.get("revision", 0)),
		"sunlit": sunlit,
		"source_revision": source_revision,
	}


func _qualification_intent(
	state: Dictionary,
	intent_id: String,
	condition_id: String,
	proof: Dictionary
) -> Dictionary:
	return {
		"schema_version": CORE.SCHEMA_VERSION,
		"intent_id": intent_id,
		"intent_kind_id": CORE.INTENT_KIND_QUALIFICATION,
		"expected_revision": int(state.get("revision", 0)),
		"condition_id": condition_id,
		"proof_id": str(proof.get("proof_id", "")),
		"proof_fingerprint": str(proof.get("proof_fingerprint", "")),
	}


func _revalidation_intent(
	state: Dictionary,
	intent_id: String,
	condition_id: String,
	proof: Dictionary
) -> Dictionary:
	return {
		"schema_version": CORE.SCHEMA_VERSION,
		"intent_id": intent_id,
		"intent_kind_id": CORE.INTENT_KIND_REVALIDATION,
		"expected_revision": int(state.get("revision", 0)),
		"condition_id": condition_id,
		"macro_round_index": int(
			(state.get("victory_gate", {}) as Dictionary).get("macro_round_index", 0)
		),
		"proof_id": str(proof.get("proof_id", "")),
		"proof_fingerprint": str(proof.get("proof_fingerprint", "")),
	}


func _complete_boundary() -> Dictionary:
	return {
		"submission_window_locked": true,
		"batch_complete": true,
		"asset_refresh_complete": true,
		"hand_maintenance_complete": true,
		"macro_round_complete": true,
		"every_player_led_once": true,
	}


func _assert_collision(outcome: Dictionary, before: Dictionary, label: String) -> void:
	var receipt := outcome.get("receipt", {}) as Dictionary
	_expect(str(receipt.get("reason_code", "")) == "intent_id_collision", "%s returns an explicit collision receipt" % label)
	_expect(receipt.get("accepted") == false and receipt.get("committed") == false, "%s collision receipt is uncommitted" % label)
	_expect(CORE.state_fingerprint(outcome.get("state", {}) as Dictionary) == CORE.state_fingerprint(before), "%s has zero mutation" % label)


func _save_restore_state(state: Dictionary) -> Dictionary:
	var wire: Variant = JSON.parse_string(JSON.stringify(CORE.to_save_state(state)))
	return CORE.from_save_state(wire as Dictionary) if wire is Dictionary else {}


func _reseal_receipt(receipt: Dictionary) -> void:
	receipt["receipt_fingerprint"] = _fingerprint_without(
		receipt,
		"receipt_fingerprint"
	)


func _reseal_save(save_state: Dictionary) -> void:
	save_state["save_fingerprint"] = _fingerprint_without(
		save_state,
		"save_fingerprint"
	)


func _resealed_save_from_state(state: Dictionary) -> Dictionary:
	var save_state := {
		"schema_version": CORE.SCHEMA_VERSION,
		"section_id": CORE.SAVE_SECTION_ID,
		"section_version": CORE.SAVE_SECTION_VERSION,
		"ruleset_id": CORE.RULESET_ID,
		"source_state_fingerprint": _fingerprint_value(state),
		"state": _encode_wire_int64(state),
	}
	_reseal_save(save_state)
	return save_state


func _encode_wire_int64(value: Variant) -> Variant:
	if value is int:
		return {"type": "int64", "decimal": str(value)}
	if value is Array:
		var encoded_array: Array = []
		for item in value as Array:
			encoded_array.append(_encode_wire_int64(item))
		return encoded_array
	if value is Dictionary:
		var encoded_dictionary := {}
		for key_variant in (value as Dictionary).keys():
			encoded_dictionary[str(key_variant)] = _encode_wire_int64(
				(value as Dictionary).get(key_variant)
			)
		return encoded_dictionary
	return value


func _fingerprint_without(value: Dictionary, omitted_field: String) -> String:
	var copied := value.duplicate(true)
	copied.erase(omitted_field)
	return JSON.stringify(_canonicalize(copied)).sha256_text().to_lower()


func _fingerprint_value(value: Variant) -> String:
	return JSON.stringify(_canonicalize(value)).sha256_text().to_lower()


func _canonicalize(value: Variant) -> Variant:
	if value is Array:
		var array_result: Array = []
		for item_variant in value as Array:
			array_result.append(_canonicalize(item_variant))
		return array_result
	if value is Dictionary:
		var keys: Array[String] = []
		for key_variant in (value as Dictionary).keys():
			keys.append(str(key_variant))
		keys.sort()
		var dictionary_result: Dictionary = {}
		for key in keys:
			dictionary_result[key] = _canonicalize((value as Dictionary).get(key))
		return dictionary_result
	return value


func _contains_exact_key(value: Variant, target_key: String, depth: int = 0) -> bool:
	if depth > 64:
		return true
	if value is Array:
		for item_variant in value as Array:
			if _contains_exact_key(item_variant, target_key, depth + 1):
				return true
	elif value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if key_variant is String and str(key_variant) == target_key:
				return true
			if _contains_exact_key((value as Dictionary).get(key_variant), target_key, depth + 1):
				return true
	return false


func _contains_exact_value(value: Variant, sentinel: String, depth: int = 0) -> bool:
	if depth > 64:
		return true
	if value is String:
		return str(value) == sentinel
	if value is Array:
		for item_variant in value as Array:
			if _contains_exact_value(item_variant, sentinel, depth + 1):
				return true
	elif value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if _contains_exact_value((value as Dictionary).get(key_variant), sentinel, depth + 1):
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
				if not (key_variant is String) or not _is_pure_data((value as Dictionary).get(key_variant), depth + 1):
					return false
			return true
		_:
			return false


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("V07_SOLAR_VICTORY_CORE_TEST | passed=%d total=%d" % [_checks, _checks])
		quit(0)
		return
	for failure in _failures:
		push_error("V07_SOLAR_VICTORY_CORE_TEST | %s" % failure)
	print("V07_SOLAR_VICTORY_CORE_TEST | passed=%d total=%d" % [_checks - _failures.size(), _checks])
	quit(1)
