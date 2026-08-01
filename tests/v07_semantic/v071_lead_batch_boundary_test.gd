extends SceneTree

const CORE := preload("res://scripts/v07_semantic/v07_unified_card_track_core.gd")
const BATCH_CORE := preload("res://scripts/v07_semantic/v07_asset_batch_core.gd")
const ROSTER := ["player.alpha", "player.beta", "player.gamma", "player.delta"]
const FIXED_SEED := 900626424

var _checks := 0
var _failures: Array[String] = []


class TestTimeAuthority extends RefCounted:
	var _attestations: Dictionary = {}

	func issue(attestation_id: String, observed_at_ms: int) -> Dictionary:
		var attestation := CORE.sealed_copy({
			"schema_version": BATCH_CORE.SCHEMA_VERSION,
			"interface_id": BATCH_CORE.TIME_ATTESTATION_INTERFACE_ID,
			"attestation_id": attestation_id,
			"observed_at_ms": observed_at_ms,
		}, "attestation_fingerprint")
		_attestations[attestation_id] = attestation
		return attestation.duplicate(true)

	func authoritative_time_attestation_v1(attestation_id: String) -> Dictionary:
		return (
			_attestations.get(attestation_id, {}) as Dictionary
		).duplicate(true)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_contract_and_color_boundary_independence()
	_test_completed_batch_ordering_and_candidate_a_cursors()
	_test_save_restore_and_receipt_exact_once()
	_finish()


func _test_contract_and_color_boundary_independence() -> void:
	var core := CORE.new(ROSTER, FIXED_SEED)
	var contract := core.interface_contract_v1() as Dictionary
	_expect(
		str(contract.get("completed_card_batch_boundary_action_id", ""))
			== CORE.ACTION_COMMIT_BATCH_BOUNDARY
			and (contract.get("state_type_ids", []) as Array).has(
				CORE.BATCH_BOUNDARY_STATE_ID
			)
			and str(contract.get("lead_advance_unit", ""))
				== "completed_card_batch"
			and str(contract.get("color_cycle_advance_unit", ""))
				== "completed_card_batch"
			and int(contract.get("completed_batch_receipt_schema_version", 0))
				== BATCH_CORE.SCHEMA_VERSION
			and int(contract.get("default_lead_tenure_batches", 0)) == 1
			and contract.get("lead_advance_implicit_in_color_commit") == false,
		"contract separates batch and color boundaries under Candidate A one-batch tenure"
	)
	var initial_lead := _lead_id(core)
	var color_intent := core.build_intent_v1(
		"request.v071.color.only",
		"system",
		CORE.ACTION_COMMIT_COLOR_CYCLE,
		{}
	)
	var color_receipt := core.apply_intent_v1(color_intent) as Dictionary
	var boundary := _boundary_state(core)
	_expect(
		bool(color_receipt.get("accepted", false))
			and _lead_id(core) == initial_lead
			and int(boundary.get("completed_batch_count", -1)) == 0
			and int(boundary.get("lead_batch_cursor", -1)) == 0,
		"a color-only commit never advances lead or completed-batch state"
	)


func _test_completed_batch_ordering_and_candidate_a_cursors() -> void:
	var core := CORE.new(
		ROSTER,
		FIXED_SEED,
		{"lead_tenure_batches": 1, "color_cycle_batches": 6}
	)
	for sequence in range(1, 6):
		var receipt := _commit_batch(
			core,
			"request.v071.batch.%02d" % sequence,
			_completed_batch_receipt(sequence)
		)
		_expect(
			bool(receipt.get("accepted", false))
				and not bool((receipt.get("public_facts", {}) as Dictionary).get(
					"color_cycle_committed",
					true
				)),
			"Candidate A batch %d advances lead without an early color commit | reason=%s" % [
				sequence,
				str(receipt.get("reason_code", "missing")),
			]
		)
	var before_sixth := _authority_state(core)
	var outgoing_lead := str(
		(before_sixth.get("hidden_lead_cycle_state", {}) as Dictionary).get(
			"current_lead_id",
			""
		)
	)
	var ordinary_actor := ROSTER[0] if ROSTER[0] != outgoing_lead else ROSTER[1]
	_apply_stance(core, "request.v071.outgoing.lead", outgoing_lead, "life", "energy")
	_apply_stance(
		core,
		"request.v071.outgoing.ordinary",
		ordinary_actor,
		"industry",
		"technology"
	)
	var sixth_receipt := _commit_batch(
		core,
		"request.v071.batch.06",
		_completed_batch_receipt(6)
	)
	var after_sixth := _authority_state(core)
	var boundary := after_sixth.get("batch_boundary_state", {}) as Dictionary
	var weights := (
		after_sixth.get("color_cycle_state", {}) as Dictionary
	).get("distribution_weight_units", {}) as Dictionary
	_expect(
		bool(sixth_receipt.get("accepted", false))
			and bool((sixth_receipt.get("public_facts", {}) as Dictionary).get(
				"color_cycle_committed",
				false
			))
			and bool((sixth_receipt.get("public_facts", {}) as Dictionary).get(
				"lead_advanced",
				false
			)),
		"the sixth completed batch commits both scheduled boundaries"
	)
	_expect(
		int(weights.get("life", 0)) == 13600
			and int(weights.get("energy", 0)) == 6400
			and int(weights.get("industry", 0)) == 11800
			and int(weights.get("technology", 0)) == 8200,
		"color weighting uses the outgoing lead before lead advancement"
	)
	_expect(
		_lead_id(core) != outgoing_lead
			and int(boundary.get("completed_batch_count", -1)) == 6
			and int(boundary.get("lead_batch_cursor", -1)) == 0
			and int(boundary.get("color_cycle_batch_cursor", -1)) == 0,
		"Candidate A lead advances after color commit and both cursors reset"
	)


func _test_save_restore_and_receipt_exact_once() -> void:
	var core := CORE.new(
		ROSTER,
		FIXED_SEED,
		{"lead_tenure_batches": 1, "color_cycle_batches": 6}
	)
	for sequence in range(1, 4):
		_commit_batch(
			core,
			"request.v071.parity.%02d" % sequence,
			_completed_batch_receipt(100 + sequence)
		)
	var save := core.save_state_v1() as Dictionary
	var saved_boundary := (
		(save.get("authority_state", {}) as Dictionary).get(
			"batch_boundary_state",
			{}
		) as Dictionary
	)
	_expect(
		int(saved_boundary.get("completed_batch_count", -1)) == 3
			and int(saved_boundary.get("lead_batch_cursor", -1)) == 0
			and int(saved_boundary.get("color_cycle_batch_cursor", -1)) == 3,
		"SaveState carries completed count and both independent cursors"
	)
	var restored := CORE.new()
	var restore_result := restored.restore_save_state_v1(save) as Dictionary
	_expect(
		bool(restore_result.get("accepted", false))
			and restored.core_authority_v1() == core.core_authority_v1(),
		"restore reproduces exact lead, macro-round, direction, and batch cursors"
	)

	var next_completed_receipt := _completed_batch_receipt(104)
	var original_receipt := _commit_batch(
		core,
		"request.v071.parity.04",
		next_completed_receipt
	)
	var restored_receipt := _commit_batch(
		restored,
		"request.v071.parity.04",
		next_completed_receipt
	)
	_expect(
		original_receipt == restored_receipt
			and core.core_authority_v1() == restored.core_authority_v1(),
		"restored Core produces the exact same next boundary receipt and state"
	)
	var before_duplicate := restored.core_authority_v1() as Dictionary
	var duplicate_intent := restored.build_intent_v1(
		"request.v071.parity.duplicate",
		"system",
		CORE.ACTION_COMMIT_BATCH_BOUNDARY,
		{"completed_batch_receipt": next_completed_receipt}
	)
	var duplicate_receipt := restored.apply_intent_v1(duplicate_intent) as Dictionary
	_expect(
		not bool(duplicate_receipt.get("accepted", true))
			and str(duplicate_receipt.get("reason_code", ""))
				== "completed_batch_receipt_already_committed"
			and restored.core_authority_v1() == before_duplicate,
		"a restored Core cannot advance twice from one completed batch Receipt"
	)

	var forged_save := save.duplicate(true)
	var forged_state := forged_save.get("authority_state", {}) as Dictionary
	var forged_boundary := forged_state.get("batch_boundary_state", {}) as Dictionary
	forged_boundary["lead_batch_cursor"] = 1
	forged_save["source_core_fingerprint"] = CORE.fingerprint(forged_state)
	forged_save["save_fingerprint"] = CORE.fingerprint(forged_save, "save_fingerprint")
	var rejected := CORE.new()
	_expect(
		not bool(rejected.restore_save_state_v1(forged_save).get("accepted", true)),
		"restore fails closed when a saved batch cursor breaks completed-count lineage"
	)

	var forged_lead_save := save.duplicate(true)
	var forged_lead_state := (
		forged_lead_save.get("authority_state", {}) as Dictionary
	)
	var forged_hidden := (
		forged_lead_state.get("hidden_lead_cycle_state", {}) as Dictionary
	)
	var fixed_order := (
		forged_hidden.get("fixed_order", []) as Array
	).duplicate(true)
	forged_hidden["macro_round_number"] = 1
	forged_hidden["direction"] = "forward"
	forged_hidden["round_order"] = fixed_order
	forged_hidden["lead_cursor"] = 0
	forged_hidden["current_lead_id"] = str(fixed_order[0])
	forged_hidden["completed_lead_ids"] = []
	forged_lead_save["source_core_fingerprint"] = CORE.fingerprint(
		forged_lead_state
	)
	forged_lead_save["save_fingerprint"] = CORE.fingerprint(
		forged_lead_save,
		"save_fingerprint"
	)
	var lead_rejected := CORE.new()
	_expect(
		not bool(
			lead_rejected.restore_save_state_v1(forged_lead_save).get(
				"accepted",
				true
			)
		),
		"restore fails closed when hidden lead progress disagrees with completed batches"
	)


func _commit_batch(
	core: RefCounted,
	request_id: String,
	completed_receipt: Dictionary
) -> Dictionary:
	var intent := core.call(
		"build_intent_v1",
		request_id,
		"system",
		CORE.ACTION_COMMIT_BATCH_BOUNDARY,
		{"completed_batch_receipt": completed_receipt}
	) as Dictionary
	if intent.is_empty():
		print(
			"V071_LEAD_BATCH_BOUNDARY_TEST|intent_build_failed|receipt=%s"
			% JSON.stringify(completed_receipt)
		)
	return core.call("apply_intent_v1", intent) as Dictionary


func _apply_stance(
	core: RefCounted,
	request_id: String,
	actor_id: String,
	increase_color: String,
	decrease_color: String
) -> void:
	var intent := core.call(
		"build_intent_v1",
		request_id,
		actor_id,
		CORE.ACTION_SET_STANCE,
		{"increase_color": increase_color, "decrease_color": decrease_color}
	) as Dictionary
	var receipt := core.call("apply_intent_v1", intent) as Dictionary
	_expect(bool(receipt.get("accepted", false)), "%s commits" % request_id)


func _completed_batch_receipt(sequence: int) -> Dictionary:
	var batch_id := "batch.v071.%03d" % sequence
	var initial_assets: Dictionary = {}
	var completed_gdp: Dictionary = {}
	for actor_id in ROSTER:
		initial_assets[str(actor_id)] = _zero_color_map()
		completed_gdp[str(actor_id)] = _zero_color_map()
	var state := BATCH_CORE.create_state(
		batch_id,
		ROSTER,
		ROSTER,
		initial_assets
	) as Dictionary
	var authority := TestTimeAuthority.new()
	var batch_core := BATCH_CORE.new()
	batch_core.bind_time_attestation_authority(authority)
	var attestation := authority.issue("attestation.v071.%03d" % sequence, 30001)
	var closed := batch_core.close_expired_window(
		state,
		attestation,
		completed_gdp,
		ROSTER
	) as Dictionary
	var refreshed := BATCH_CORE.refresh_assets_after_batch(
		closed.get("state", {}) as Dictionary
	) as Dictionary
	return (refreshed.get("receipt", {}) as Dictionary).duplicate(true)


func _zero_color_map() -> Dictionary:
	return {
		"life": 0,
		"energy": 0,
		"industry": 0,
		"technology": 0,
		"commerce": 0,
		"shipping": 0,
	}


func _authority_state(core: RefCounted) -> Dictionary:
	return (
		(core.call("core_authority_v1") as Dictionary).get(
			"authority_state",
			{}
		) as Dictionary
	)


func _boundary_state(core: RefCounted) -> Dictionary:
	return _authority_state(core).get("batch_boundary_state", {}) as Dictionary


func _lead_id(core: RefCounted) -> String:
	return str(
		(_authority_state(core).get("hidden_lead_cycle_state", {}) as Dictionary).get(
			"current_lead_id",
			""
		)
	)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		print("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print(
			"V071_LEAD_BATCH_BOUNDARY_TEST|status=PASS|checks=%d|failures=0"
			% _checks
		)
		quit(0)
		return
	push_error("V0.7.1 lead boundary test failed:\n- %s" % "\n- ".join(_failures))
	print(
		"V071_LEAD_BATCH_BOUNDARY_TEST|status=FAIL|checks=%d|failures=%d"
		% [_checks, _failures.size()]
	)
	quit(1)
