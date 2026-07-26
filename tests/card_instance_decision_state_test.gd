extends SceneTree

const STATE := preload(
	"res://scripts/cards/semantic/card_instance_decision_state_v1.gd"
)
const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const AI_INPUT := preload(
	"res://scripts/runtime/ai_card_semantic_projection_input_v1.gd"
)

const BUILD_KEYS := [
	"schema_version",
	"instance_id",
	"card_id",
	"source_kind",
	"visibility_scope_id",
	"viewer_ref",
	"session_id",
	"session_revision",
	"source_revision",
	"source_slot",
	"queued",
	"locked",
	"cooldown_remaining_microseconds",
]
const STATE_KEYS := [
	"schema_version",
	"instance_id",
	"card_id",
	"source_kind",
	"visibility_scope_id",
	"viewer_ref",
	"session_id",
	"session_revision",
	"source_revision",
	"source_slot",
	"instance_revision",
	"queued",
	"locked",
	"cooldown_remaining_microseconds",
	"state_fingerprint",
]
const AI_KEYS := [
	"schema_version",
	"instance_id",
	"card_id",
	"source_slot",
	"instance_revision",
	"queued",
	"locked",
	"cooldown_remaining_seconds",
]
const INJECTION_KEYS := [
	"card_record",
	"static_record",
	"world_state",
	"ai_memory",
	"ui_payload",
	"hidden_owner",
	"cash_cents",
]

var _checks := 0
var _failures: Array[String] = []
var _started_usec := 0


func _init() -> void:
	_started_usec = Time.get_ticks_usec()
	call_deferred("_run")


func _run() -> void:
	var input := _valid_input()
	var state := STATE.build(input)
	_test_valid_contract(input, state)
	_test_binding_and_detachment(state)
	_test_availability_and_adapter()
	_test_exact_fields(state)
	_test_ids(state)
	_test_cooldowns(state)
	_test_key_injection(state)
	_test_object_injection(state)
	_test_tampering(state)
	_finish()


func _test_valid_contract(input: Dictionary, state: Dictionary) -> void:
	_expect(STATE.BUILD_FIELDS == BUILD_KEYS, "build field contract is exact")
	_expect(STATE.FIELDS == STATE_KEYS, "sealed field contract is exact")
	_expect(
		state.keys() == STATE_KEYS and WIRE.exact_fields(state, STATE_KEYS),
		"build emits exact ordered state keys"
	)
	_expect(
		bool(STATE.validate(state).get("valid", false))
			and STATE.validation_error(state).is_empty(),
		"canonical state validates"
	)
	_expect(
		str(state.get("instance_id", "")) == "fixture:semantic:active:01"
			and str(state.get("session_id", ""))
				== "session:semantic:decision:01",
		"raw colon runtime IDs are preserved"
	)
	_expect(
		state.get("viewer_ref") == input.get("viewer_ref")
			and state.get("session_revision") == input.get("session_revision")
			and state.get("source_revision") == input.get("source_revision")
			and state.get("source_slot") == input.get("source_slot"),
		"viewer, session, and source bindings are preserved"
	)
	var revision_input := state.duplicate(true)
	revision_input.erase("instance_revision")
	revision_input.erase("state_fingerprint")
	_expect(
		str(state.get("instance_revision", ""))
			== WIRE.fingerprint(revision_input),
		"instance revision fingerprints every build field"
	)
	_expect(
		str(state.get("state_fingerprint", ""))
			== WIRE.fingerprint(state, "state_fingerprint"),
		"state fingerprint seals the instance revision"
	)
	var repeated := STATE.build(input.duplicate(true))
	var reordered := STATE.build(_reverse_key_order(input))
	_expect(
		state == repeated and state == reordered,
		"build and both fingerprints are deterministic"
	)
	_expect(
		STATE.build(revision_input) == state,
		"owner-derived fingerprints rebuild identically"
	)


func _test_binding_and_detachment(baseline: Dictionary) -> void:
	var binding_cases: Array[Dictionary] = [
		{
			"id": "viewer_ref",
			"field": "viewer_ref",
			"value": {
				"schema_version": 1,
				"actor_ref_id": "actor.ai.two",
				"actor_index": 4,
			},
		},
		{
			"id": "session_id",
			"field": "session_id",
			"value": "session:semantic:decision:02",
		},
		{"id": "session_revision", "field": "session_revision", "value": 18},
		{"id": "source_revision", "field": "source_revision", "value": "b".repeat(64)},
		{"id": "source_slot", "field": "source_slot", "value": 8},
	]
	for case_variant in binding_cases:
		var test_case := case_variant as Dictionary
		var changed_input := _valid_input()
		var field := str(test_case.get("field", ""))
		changed_input[field] = test_case.get("value")
		var changed := STATE.build(changed_input)
		_expect(
			not changed.is_empty()
				and changed.get(field) == test_case.get("value")
				and changed.get("instance_revision")
					!= baseline.get("instance_revision")
				and changed.get("state_fingerprint")
					!= baseline.get("state_fingerprint"),
			"binding changes both fingerprints: %s" % test_case.get("id", "")
		)

	for scope_case in [
		{"field": "source_kind", "value": "public_rack"},
		{"field": "visibility_scope_id", "value": "public"},
	]:
		var bad_scope := _valid_input()
		bad_scope[str(scope_case.get("field", ""))] = scope_case.get("value")
		_expect(STATE.build(bad_scope).is_empty(), "foreign source scope rejects")

	var mutable_input := _valid_input()
	var detached := STATE.build(mutable_input)
	(mutable_input.get("viewer_ref") as Dictionary)["actor_ref_id"] = "actor.changed"
	mutable_input["session_id"] = "session:changed"
	_expect(
		str((detached.get("viewer_ref") as Dictionary).get("actor_ref_id", ""))
			== "actor.ai.one"
			and str(detached.get("session_id", ""))
				== "session:semantic:decision:01"
			and bool(STATE.validate(detached).get("valid", false)),
		"build output is deeply detached from caller input"
	)
	var separately_built := STATE.build(_valid_input())
	(detached.get("viewer_ref") as Dictionary)["actor_index"] = 99
	_expect(
		int((separately_built.get("viewer_ref") as Dictionary).get(
			"actor_index", -1
		)) == 2
			and bool(STATE.validate(separately_built).get("valid", false)),
		"separate build results do not share nested viewer data"
	)


func _test_availability_and_adapter() -> void:
	var cases: Array[Dictionary] = [
		{"id": "available", "queued": false, "locked": false, "cooldown": 0, "available": true},
		{"id": "queued", "queued": true, "locked": false, "cooldown": 0, "available": false},
		{"id": "locked", "queued": false, "locked": true, "cooldown": 0, "available": false},
		{"id": "cooldown", "queued": false, "locked": false, "cooldown": 1, "available": false},
	]
	for case_variant in cases:
		var test_case := case_variant as Dictionary
		var input := _valid_input()
		input["queued"] = test_case.get("queued")
		input["locked"] = test_case.get("locked")
		input["cooldown_remaining_microseconds"] = test_case.get("cooldown")
		var state := STATE.build(input)
		var projection := STATE.to_ai_projection_input(state)
		var expected_available := bool(test_case.get("available", false))
		_expect(
			not state.is_empty()
				and STATE.is_available(state) == expected_available
				and AI_INPUT.instance_is_available(projection)
					== expected_available,
			"availability agrees across adapter: %s" % test_case.get("id", "")
		)

	for adapter_case in [
		{"microseconds": 0, "seconds": 0.0},
		{"microseconds": 1, "seconds": 0.000001},
		{"microseconds": 250001, "seconds": 0.250001},
	]:
		var input := _valid_input()
		input["cooldown_remaining_microseconds"] = adapter_case.get(
			"microseconds"
		)
		var state := STATE.build(input)
		var projection := STATE.to_ai_projection_input(state)
		_expect(
			projection.keys() == AI_KEYS
				and AI_INPUT.instance_state_error(projection).is_empty()
				and str(projection.get("instance_id", ""))
					== str(state.get("instance_id", ""))
				and projection.get("instance_revision")
					== state.get("instance_revision")
				and is_equal_approx(
					float(projection.get("cooldown_remaining_seconds", -1.0)),
					float(adapter_case.get("seconds", -1.0))
				),
			"microseconds convert through exact compatibility input: %s"
				% adapter_case.get("microseconds")
		)


func _test_exact_fields(valid_state: Dictionary) -> void:
	for field_variant in BUILD_KEYS:
		var missing_input := _valid_input()
		missing_input.erase(str(field_variant))
		_expect(
			STATE.build(missing_input).is_empty(),
			"build rejects missing field: %s" % field_variant
		)
	for field_variant in STATE_KEYS:
		var missing_state := valid_state.duplicate(true)
		missing_state.erase(str(field_variant))
		_expect_invalid(
			missing_state,
			"card_instance_decision_state.fields_invalid",
			"validate rejects missing field: %s" % field_variant
		)
	var unknown_input := _valid_input()
	unknown_input["unexpected"] = 1
	_expect(STATE.build(unknown_input).is_empty(), "build rejects unknown field")
	var unknown_state := valid_state.duplicate(true)
	unknown_state["unexpected"] = 1
	_expect_invalid(
		unknown_state,
		"card_instance_decision_state.fields_invalid",
		"validate rejects unknown field"
	)
	for owner_field in ["instance_revision", "state_fingerprint"]:
		var caller_sealed := _valid_input()
		caller_sealed[owner_field] = "f".repeat(64)
		_expect(
			STATE.build(caller_sealed).is_empty(),
			"caller cannot inject owner-derived field: %s" % owner_field
		)


func _test_ids(valid_state: Dictionary) -> void:
	var invalid_runtime_ids: Array[String] = [
		"",
		" leading",
		"runtime" + String.chr(31) + "id",
		"runtime." + String.chr(233),
		"x".repeat(513),
	]
	for field in ["instance_id", "session_id"]:
		for index in range(invalid_runtime_ids.size()):
			var invalid_id := invalid_runtime_ids[index]
			var input := _valid_input()
			input[field] = invalid_id
			_expect(
				STATE.build(input).is_empty(),
				"build rejects %s runtime ID %d" % [field, index]
			)
			var invalid_state := valid_state.duplicate(true)
			invalid_state[field] = invalid_id
			_resign_state(invalid_state)
			_expect_invalid(
				invalid_state,
				"card_instance_decision_state.runtime_id_invalid",
				"validate rejects %s runtime ID %d" % [field, index]
			)

	for index in range(4):
		var invalid_stable_id := invalid_runtime_ids[index]
		var card_input := _valid_input()
		card_input["card_id"] = invalid_stable_id
		_expect(
			STATE.build(card_input).is_empty(),
			"card stable ID rejects empty/control/non-ASCII %d" % index
		)
		var viewer_input := _valid_input()
		(viewer_input.get("viewer_ref") as Dictionary)["actor_ref_id"] = (
			invalid_stable_id
		)
		_expect(
			STATE.build(viewer_input).is_empty(),
			"viewer stable ID rejects empty/control/non-ASCII %d" % index
		)
	var colon_card := _valid_input()
	colon_card["card_id"] = "card:colon"
	_expect(
		STATE.build(colon_card).is_empty(),
		"colon remains exclusive to opaque runtime IDs"
	)


func _test_cooldowns(valid_state: Dictionary) -> void:
	var maximum_input := _valid_input()
	maximum_input["cooldown_remaining_microseconds"] = WIRE.MAX_SAFE_INTEGER
	var maximum_state := STATE.build(maximum_input)
	_expect(
		not maximum_state.is_empty() and not STATE.is_available(maximum_state),
		"maximum safe integer cooldown is valid and unavailable"
	)
	var invalid_values: Array = [
		-1,
		WIRE.MAX_SAFE_INTEGER + 1,
		-WIRE.MAX_SAFE_INTEGER - 1,
		0.0,
	]
	for index in range(invalid_values.size()):
		var input := _valid_input()
		input["cooldown_remaining_microseconds"] = invalid_values[index]
		_expect(
			STATE.build(input).is_empty(),
			"negative, non-safe, or float cooldown rejects: %d" % index
		)
		var invalid_state := valid_state.duplicate(true)
		invalid_state["cooldown_remaining_microseconds"] = invalid_values[index]
		if WIRE.is_closed_data(invalid_state):
			_resign_state(invalid_state)
		_expect(
			not bool(STATE.validate(invalid_state).get("valid", true)),
			"invalid cooldown cannot validate: %d" % index
		)

	var nonfinite_values: Array[float] = [NAN, INF, -INF]
	for index in range(nonfinite_values.size()):
		var nonfinite_input := _valid_input()
		nonfinite_input["cooldown_remaining_microseconds"] = (
			nonfinite_values[index]
		)
		var nonfinite_state := valid_state.duplicate(true)
		nonfinite_state["cooldown_remaining_microseconds"] = (
			nonfinite_values[index]
		)
		_expect(
			not WIRE.is_closed_data(nonfinite_input)
				and WIRE.fingerprint(nonfinite_input).is_empty()
				and STATE.build(nonfinite_input).is_empty()
				and STATE.to_ai_projection_input(nonfinite_state).is_empty(),
			"nonfinite cooldown is impossible closed data: %d" % index
		)
		_expect_invalid(
			nonfinite_state,
			"card_instance_decision_state.not_closed_data",
			"nonfinite state fails closed: %d" % index
		)


func _test_key_injection(valid_state: Dictionary) -> void:
	for injection_key in INJECTION_KEYS:
		var injected_input := _valid_input()
		injected_input[injection_key] = 7
		_expect(
			STATE.build(injected_input).is_empty(),
			"build rejects key injection: %s" % injection_key
		)
		var injected_state := valid_state.duplicate(true)
		injected_state[injection_key] = 7
		_expect_invalid(
			injected_state,
			"card_instance_decision_state.fields_invalid",
			"validate rejects key injection: %s" % injection_key
		)
		var nested_input := _valid_input()
		(nested_input.get("viewer_ref") as Dictionary)[injection_key] = 7
		_expect(
			STATE.build(nested_input).is_empty(),
			"viewer binding rejects nested key injection: %s" % injection_key
		)


func _test_object_injection(valid_state: Dictionary) -> void:
	var node := Node.new()
	var impure_cases: Array[Dictionary] = [
		{"id": "node", "value": node},
		{"id": "resource", "value": Resource.new()},
		{"id": "callable", "value": Callable(self, "_noop")},
	]
	for case_variant in impure_cases:
		var test_case := case_variant as Dictionary
		var injected_input := _valid_input()
		injected_input["injected"] = test_case.get("value")
		_expect(
			not WIRE.is_closed_data(injected_input)
				and STATE.build(injected_input).is_empty(),
			"build rejects object injection: %s" % test_case.get("id", "")
		)
		var injected_state := valid_state.duplicate(true)
		injected_state["injected"] = test_case.get("value")
		_expect_invalid(
			injected_state,
			"card_instance_decision_state.not_closed_data",
			"validate rejects object injection: %s" % test_case.get("id", "")
		)
	node.free()


func _test_tampering(valid_state: Dictionary) -> void:
	var stale_revision := valid_state.duplicate(true)
	stale_revision["instance_revision"] = _other_fingerprint(
		str(stale_revision.get("instance_revision", ""))
	)
	stale_revision["state_fingerprint"] = WIRE.fingerprint(
		stale_revision,
		"state_fingerprint"
	)
	_expect_invalid(
		stale_revision,
		"card_instance_decision_state.instance_revision_invalid",
		"tampered instance revision rejects after outer reseal"
	)
	var stale_payload := valid_state.duplicate(true)
	stale_payload["queued"] = true
	stale_payload["state_fingerprint"] = WIRE.fingerprint(
		stale_payload,
		"state_fingerprint"
	)
	_expect_invalid(
		stale_payload,
		"card_instance_decision_state.instance_revision_invalid",
		"payload tamper cannot preserve instance revision"
	)
	var stale_fingerprint := valid_state.duplicate(true)
	stale_fingerprint["state_fingerprint"] = _other_fingerprint(
		str(stale_fingerprint.get("state_fingerprint", ""))
	)
	_expect_invalid(
		stale_fingerprint,
		"card_instance_decision_state.fingerprint_invalid",
		"tampered state fingerprint rejects"
	)
	_expect(
		not STATE.is_available(stale_fingerprint)
			and STATE.to_ai_projection_input(stale_fingerprint).is_empty(),
		"tampered state cannot become available or reach AI"
	)


func _valid_input() -> Dictionary:
	return {
		"schema_version": 1,
		"instance_id": "fixture:semantic:active:01",
		"card_id": "commodity.star_dew_berry.rank_1",
		"source_kind": "own_hand",
		"visibility_scope_id": "actor_private",
		"viewer_ref": {
			"schema_version": 1,
			"actor_ref_id": "actor.ai.one",
			"actor_index": 2,
		},
		"session_id": "session:semantic:decision:01",
		"session_revision": 17,
		"source_revision": "a".repeat(64),
		"source_slot": 3,
		"queued": false,
		"locked": false,
		"cooldown_remaining_microseconds": 0,
	}


func _reverse_key_order(input: Dictionary) -> Dictionary:
	var reordered := {}
	for index in range(BUILD_KEYS.size() - 1, -1, -1):
		var field := str(BUILD_KEYS[index])
		reordered[field] = input.get(field)
	return reordered


func _resign_state(state: Dictionary) -> void:
	var revision_input := state.duplicate(true)
	revision_input.erase("instance_revision")
	revision_input.erase("state_fingerprint")
	state["instance_revision"] = WIRE.fingerprint(revision_input)
	state["state_fingerprint"] = WIRE.fingerprint(
		state,
		"state_fingerprint"
	)


func _other_fingerprint(current: String) -> String:
	var candidate := "f".repeat(64)
	return "e".repeat(64) if current == candidate else candidate


func _expect_invalid(
	state: Dictionary,
	expected_reason: String,
	failure_id: String
) -> void:
	var report := STATE.validate(state)
	_expect(
		not bool(report.get("valid", true))
			and str(report.get("reason_id", "")) == expected_reason
			and STATE.validation_error(state) == expected_reason,
		failure_id
	)


func _noop() -> void:
	pass


func _expect(condition: bool, failure_id: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(failure_id)


func _finish() -> void:
	var duration_ms := snappedf(
		float(Time.get_ticks_usec() - _started_usec) / 1000.0,
		0.001
	)
	_expect(duration_ms < 60000.0, "focused test stays below 60 seconds")
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print(
		"CARD_INSTANCE_DECISION_STATE_TEST_COMPLETE|status=%s|checks=%d|failures=%d|duration_ms=%.3f|details=%s"
		% [
			status,
			_checks,
			_failures.size(),
			duration_ms,
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)
