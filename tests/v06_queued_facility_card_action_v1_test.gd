extends SceneTree

const BINDING := preload(
	"res://scripts/cards/v06/queued_facility_card_action_v1.gd"
)
const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")

var _checks := 0
var _failures: Array[String] = []
var _started_usec := 0


func _init() -> void:
	_started_usec = Time.get_ticks_usec()
	call_deferred("_run")


func _run() -> void:
	var input := _valid_input()
	var sealed := BINDING.build(input)
	_test_valid_build(input, sealed)
	_test_detachment(input, sealed)
	_test_exact_fields(sealed)
	_test_identity_and_fixed_values()
	_test_nested_contracts()
	_test_hostile_values(sealed)
	_test_fingerprint_tampering(sealed)
	_finish()


func _test_valid_build(input: Dictionary, sealed: Dictionary) -> void:
	_expect(not sealed.is_empty(), "canonical facility binding builds")
	_expect(
		bool(BINDING.validation_report(sealed).get("valid", false)),
		"canonical facility binding validates"
	)
	_expect(
		WIRE.exact_fields(sealed, BINDING.FIELDS),
		"sealed binding exposes only the frozen top-level fields"
	)
	_expect(
		str(sealed.get("binding_fingerprint", ""))
			== WIRE.fingerprint(sealed, "binding_fingerprint")
			and BINDING.binding_fingerprint(sealed)
				== str(sealed.get("binding_fingerprint", "")),
		"build seals one canonical SemanticWire fingerprint"
	)
	_expect(
		BINDING.build(input.duplicate(true)) == sealed,
		"repeated builds are deterministic"
	)
	var no_asset_input := _valid_input()
	var no_asset := no_asset_input.get("asset_reservation") as Dictionary
	no_asset["required"] = false
	no_asset["reservation_id"] = ""
	no_asset_input["asset_reservation"] = no_asset
	_expect(
		not BINDING.build(no_asset_input).is_empty(),
		"asset-free actions retain an attested reservation fingerprint"
	)


func _test_detachment(input: Dictionary, sealed: Dictionary) -> void:
	var built_target := sealed.get("prebound_target") as Dictionary
	var input_target := input.get("prebound_target") as Dictionary
	input_target["region_id"] = "region.changed"
	_expect(
		str(built_target.get("region_id", "")) == "region.alpha"
			and bool(BINDING.validation_report(sealed).get("valid", false)),
		"build output is deeply detached from caller input"
	)
	var copy := BINDING.detached_copy(sealed)
	(copy.get("card_escrow") as Dictionary)["escrow_id"] = "escrow.changed"
	_expect(
		str((sealed.get("card_escrow") as Dictionary).get("escrow_id", ""))
			== "escrow.facility.001"
			and BINDING.detached_copy(sealed) == sealed,
		"detached_copy returns independent nested data"
	)
	_expect(
		BINDING.detached_copy({}).is_empty()
			and BINDING.binding_fingerprint({}).is_empty(),
		"invalid values expose neither copies nor fingerprints"
	)


func _test_exact_fields(sealed: Dictionary) -> void:
	for field_variant in BINDING.BUILD_FIELDS:
		var missing := _valid_input()
		missing.erase(str(field_variant))
		_expect(
			BINDING.build(missing).is_empty(),
			"build rejects missing field: %s" % field_variant
		)
	var caller_sealed := _valid_input()
	caller_sealed["binding_fingerprint"] = "a".repeat(64)
	_expect(
		BINDING.build(caller_sealed).is_empty(),
		"caller cannot inject binding_fingerprint"
	)
	var unknown := _valid_input()
	unknown["payload"] = {}
	_expect(BINDING.build(unknown).is_empty(), "build rejects unknown top-level fields")
	var unknown_sealed := sealed.duplicate(true)
	unknown_sealed["payload"] = {}
	_expect(
		not bool(BINDING.validation_report(unknown_sealed).get("valid", false)),
		"validation rejects unknown top-level fields"
	)


func _test_identity_and_fixed_values() -> void:
	for test_case in [
		{"field": "actor_kind_id", "value": "system"},
		{"field": "actor_id", "value": "player.3"},
		{"field": "card_instance_id", "value": "card.instance.other"},
		{"field": "facility_kind_id", "value": "orbital_elevator"},
		{"field": "rank", "value": 0},
		{"field": "rank", "value": 5},
		{"field": "local_action_index", "value": 1},
	]:
		var changed := _valid_input()
		changed[str(test_case.get("field", ""))] = test_case.get("value")
		_expect(
			BINDING.build(changed).is_empty(),
			"identity or fixed value rejects: %s=%s" % [
				test_case.get("field", ""),
				test_case.get("value"),
			]
		)
	for id_case in [
		{"field": "request_id", "value": "Request.Upper"},
		{"field": "session_id", "value": "Session.Upper"},
		{"field": "card_semantic_id", "value": "card..invalid"},
		{"field": "industry_id", "value": ""},
	]:
		var invalid_id := _valid_input()
		invalid_id[str(id_case.get("field", ""))] = id_case.get("value")
		_expect(
			BINDING.build(invalid_id).is_empty(),
			"SemanticWire stable ID rejects: %s" % id_case.get("field", "")
		)
	for integer_case in [
		{"field": "source_revision", "value": -1},
		{"field": "source_slot_index", "value": -1},
		{"field": "submitted_at_world_time", "value": -1},
		{"field": "queue_revision_at_commit", "value": WIRE.MAX_SAFE_INTEGER + 1},
	]:
		var invalid_integer := _valid_input()
		invalid_integer[str(integer_case.get("field", ""))] = integer_case.get("value")
		_expect(
			BINDING.build(invalid_integer).is_empty(),
			"safe nonnegative integer rejects: %s"
				% integer_case.get("field", "")
		)


func _test_nested_contracts() -> void:
	var cases := [
		{
			"section": "prebound_target",
			"field": "target_kind_id",
			"value": "region_any_slot",
		},
		{
			"section": "prebound_target",
			"field": "target_slot_generation",
			"value": -1,
		},
		{
			"section": "asset_reservation",
			"field": "owner_id",
			"value": "other_owner",
		},
		{
			"section": "asset_reservation",
			"field": "reservation_state_id",
			"value": "consumed",
		},
		{
			"section": "card_escrow",
			"field": "owner_id",
			"value": "inventory_mirror",
		},
		{
			"section": "card_escrow",
			"field": "state_id",
			"value": "pending",
		},
		{
			"section": "public_visibility",
			"field": "owner_visibility_id",
			"value": "public",
		},
		{
			"section": "public_visibility",
			"field": "card_visibility_id",
			"value": "private",
		},
	]
	for test_case in cases:
		var changed := _valid_input()
		var section_id := str(test_case.get("section", ""))
		var section := changed.get(section_id) as Dictionary
		section[str(test_case.get("field", ""))] = test_case.get("value")
		changed[section_id] = section
		_expect(
			BINDING.build(changed).is_empty(),
			"nested fixed value rejects: %s.%s" % [
				section_id,
				test_case.get("field", ""),
			]
		)

	for section_id in [
		"prebound_target",
		"asset_reservation",
		"card_escrow",
		"public_visibility",
	]:
		var unknown := _valid_input()
		var section := unknown.get(section_id) as Dictionary
		section["unexpected"] = "closed.but-forbidden"
		unknown[section_id] = section
		_expect(
			BINDING.build(unknown).is_empty(),
			"nested schema rejects unknown field: %s" % section_id
		)

	var required_without_id := _valid_input()
	(required_without_id.get("asset_reservation") as Dictionary)[
		"reservation_id"
	] = ""
	_expect(
		BINDING.build(required_without_id).is_empty(),
		"required reservation needs one stable ID"
	)
	var optional_with_id := _valid_input()
	var optional_reservation := optional_with_id.get(
		"asset_reservation"
	) as Dictionary
	optional_reservation["required"] = false
	optional_reservation["reservation_id"] = "mana.reservation.unexpected"
	_expect(
		BINDING.build(optional_with_id).is_empty(),
		"asset-free reservation requires an empty reservation ID"
	)


func _test_hostile_values(sealed: Dictionary) -> void:
	var runtime_node := Node.new()
	var hostile_values: Array[Variant] = [
		runtime_node,
		RefCounted.new(),
		Resource.new(),
		Callable(self, "_run"),
		NAN,
		INF,
		-INF,
	]
	for index in range(hostile_values.size()):
		var hostile := _valid_input()
		hostile["source_revision"] = hostile_values[index]
		_expect(
			BINDING.build(hostile).is_empty(),
			"hostile value fails closed: %d" % index
		)
	var hostile_nested := _valid_input()
	(hostile_nested.get("prebound_target") as Dictionary)["region_id"] = runtime_node
	_expect(
		BINDING.build(hostile_nested).is_empty(),
		"hostile nested Object fails closed"
	)
	_expect(
		not bool(BINDING.validation_report(runtime_node).get("valid", false)),
		"non-Dictionary validation input fails closed"
	)
	runtime_node.free()
	_expect(
		bool(BINDING.validation_report(sealed).get("valid", false)),
		"hostile checks do not mutate the canonical binding"
	)


func _test_fingerprint_tampering(sealed: Dictionary) -> void:
	var changed := sealed.duplicate(true)
	changed["source_revision"] = int(changed.get("source_revision", 0)) + 1
	_expect(
		not bool(BINDING.validation_report(changed).get("valid", false))
			and BINDING.binding_fingerprint(changed).is_empty(),
		"top-level mutation invalidates the binding fingerprint"
	)
	var malformed := _valid_input()
	malformed["intent_fingerprint"] = "f".repeat(63)
	_expect(
		BINDING.build(malformed).is_empty(),
		"non-SHA-256 authority fingerprints reject"
	)
	var wrong_binding := sealed.duplicate(true)
	wrong_binding["binding_fingerprint"] = "0".repeat(64)
	_expect(
		not bool(BINDING.validation_report(wrong_binding).get("valid", false)),
		"caller-supplied binding fingerprint mismatch rejects"
	)


func _valid_input() -> Dictionary:
	return {
		"schema_version": 1,
		"binding_kind_id": "v06.queued-facility-card-action",
		"resolution_id": 1,
		"request_id": "request.facility.001",
		"intent_fingerprint": "1".repeat(64),
		"session_id": "session.alpha04c.001",
		"session_revision": 7,
		"session_identity_fingerprint": "2".repeat(64),
		"source_revision": 11,
		"actor_kind_id": "human",
		"actor_id": "player.2",
		"actor_player_index": 2,
		"card_instance_id": "card.instance.facility.001",
		"runtime_instance_id": "card.instance.facility.001",
		"card_semantic_id": "card.facility.factory.blue.rank-2",
		"hand_slot_id": "hand.slot.3",
		"source_slot_index": 3,
		"source_record_fingerprint": "3".repeat(64),
		"source_slot_fingerprint": "4".repeat(64),
		"facility_kind_id": "factory",
		"industry_id": "industry.blue",
		"rank": 2,
		"prebound_target": {
			"schema_version": 1,
			"target_kind_id": "region_unique_facility_slot",
			"region_id": "region.alpha",
			"region_revision": 5,
			"target_slot_id": "facility.slot.factory.blue.0",
			"target_slot_generation": 1,
			"target_state_fingerprint": "5".repeat(64),
		},
		"asset_reservation": {
			"schema_version": 1,
			"owner_id": "player_mana",
			"required": true,
			"reservation_id": "mana.reservation.facility.001",
			"reservation_state_id": "reserved",
			"reservation_fingerprint": "6".repeat(64),
		},
		"card_escrow": {
			"schema_version": 1,
			"owner_id": "world_session_state",
			"escrow_id": "escrow.facility.001",
			"state_id": "committed_resolution_escrow",
			"escrow_fingerprint": "7".repeat(64),
		},
		"submitted_at_world_time": 123456,
		"queue_revision_at_commit": 19,
		"local_action_index": 0,
		"public_visibility": {
			"schema_version": 1,
			"owner_visibility_id": "anonymous",
			"card_visibility_id": "public",
			"target_visibility_id": "public",
		},
	}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	var elapsed_ms := float(Time.get_ticks_usec() - _started_usec) / 1000.0
	print(
		"V06QueuedFacilityCardActionV1: %d checks / %d failures / %.2f ms"
			% [_checks, _failures.size(), elapsed_ms]
	)
	quit(0 if _failures.is_empty() else 1)
