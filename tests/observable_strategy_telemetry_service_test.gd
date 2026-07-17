extends SceneTree

const POLICY_SCRIPT := preload("res://scripts/runtime/public_match_receipt_envelope_policy_v06.gd")
const SERVICE_SCRIPT := preload("res://scripts/runtime/observable_strategy_telemetry_service.gd")
const SERVICE_PATH := "res://scripts/runtime/observable_strategy_telemetry_service.gd"
const FORBIDDEN_OUTPUT_KEYS := [
	"player", "player_id", "player_index", "seat", "seat_id", "actor", "actor_id", "profile", "profile_id",
	"card_id", "target", "bid", "weights", "scores", "reasons", "candidates", "plans", "learning", "owner",
	"hand", "discard", "cash", "cash_cents", "fingerprint",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	_run()


func _run() -> void:
	_case_six_actorless_tendencies()
	_case_exact_once_and_immutable_ingest()
	_case_out_of_order_determinism()
	_case_invalid_and_recursive_private_input()
	_case_overflow_marks_incomplete_without_eviction()
	_case_pure_non_owner_boundary()
	print("OBSERVABLE_STRATEGY_TELEMETRY_SERVICE_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()
	])
	quit(_failures.size())


func _case_six_actorless_tendencies() -> void:
	var service: RefCounted = SERVICE_SCRIPT.new()
	for receipt_variant: Variant in _six_receipts():
		_expect(bool((service.call("ingest_public_receipt", receipt_variant) as Dictionary).get("accepted", false)), "legal public receipt is ingested")
	var snapshot := service.call("aggregate_snapshot") as Dictionary
	var tendencies: Array = snapshot.get("tendencies", []) as Array
	_expect(str(snapshot.get("observation_kind", "")) == "OBSERVED_TENDENCY", "aggregate has one explicit observed tendency kind")
	_expect(str(snapshot.get("anonymity_scope", "")) == "match_public_aggregate", "aggregate is scoped to the anonymous match total")
	_expect(tendencies.size() == 6 and int(snapshot.get("accepted_receipt_count", 0)) == 6, "aggregate exposes six fixed tendency rows from six receipts")
	for index in range(tendencies.size()):
		var row := tendencies[index] as Dictionary
		_expect(str(row.get("tendency_id", "")) == str(POLICY_SCRIPT.TENDENCY_IDS[index]), "tendency row %d follows contract order" % index)
		_expect(int(row.get("observed_event_count", 0)) == 1, "tendency row %d records one public observation" % index)
	var leaks: Array[String] = []
	_collect_forbidden_output(snapshot, "aggregate", leaks)
	_expect(leaks.is_empty(), "aggregate is actorless and contains no forbidden identity/private fields: %s" % [leaks])
	_expect(not JSON.stringify(snapshot).contains("PRIVATE_SENTINEL"), "aggregate contains no private sentinel")


func _case_exact_once_and_immutable_ingest() -> void:
	var service: RefCounted = SERVICE_SCRIPT.new()
	var candidate := _receipt(1, "public_facility_committed", "facility_built", {"gdp_cents_per_minute_delta": 100})
	var first := service.call("ingest_public_receipt", candidate) as Dictionary
	(candidate["typed_deltas"] as Dictionary)["gdp_cents_per_minute_delta"] = 9999
	var duplicate := _receipt(1, "public_facility_committed", "facility_built", {"gdp_cents_per_minute_delta": 100})
	var duplicate_result := service.call("ingest_public_receipt", duplicate) as Dictionary
	var snapshot := service.call("aggregate_snapshot") as Dictionary
	var city := (snapshot.get("tendencies", []) as Array)[0] as Dictionary
	_expect(bool(first.get("accepted", false)) and bool(duplicate_result.get("accepted", false)) and bool(duplicate_result.get("duplicate", false)), "same immutable receipt id is exact-once idempotent")
	_expect(int(snapshot.get("accepted_receipt_count", 0)) == 1 and int(snapshot.get("duplicate_receipt_count", 0)) == 1, "duplicate receipt never increments evidence count")
	_expect(int((city.get("typed_delta_totals", {}) as Dictionary).get("gdp_cents_per_minute_delta", 0)) == 100, "stored evidence is detached from caller mutation")
	var conflict := _receipt(1, "public_facility_committed", "facility_built", {"gdp_cents_per_minute_delta": 101})
	var conflict_result := service.call("ingest_public_receipt", conflict) as Dictionary
	_expect(not bool(conflict_result.get("accepted", true)) and str(conflict_result.get("failure_code", "")) == "receipt_id_conflict", "same receipt id with changed body fails closed")


func _case_out_of_order_determinism() -> void:
	var ordered: RefCounted = SERVICE_SCRIPT.new()
	var shuffled: RefCounted = SERVICE_SCRIPT.new()
	var receipts := _six_receipts()
	for receipt_variant: Variant in receipts:
		ordered.call("ingest_public_receipt", receipt_variant)
	for index in [5, 1, 4, 0, 3, 2]:
		shuffled.call("ingest_public_receipt", (receipts[index] as Dictionary).duplicate(true))
	_expect(ordered.call("aggregate_snapshot") == shuffled.call("aggregate_snapshot"), "out-of-order ingestion produces a byte-stable sequence aggregate")
	var sequence_conflict := _receipt(6, "public_facility_committed", "facility_upgraded", {"controlled_regions_delta": 1})
	sequence_conflict["receipt_id"] = "pub.match.sequence-conflict"
	var conflict_result := shuffled.call("ingest_public_receipt", sequence_conflict) as Dictionary
	_expect(not bool(conflict_result.get("accepted", true)) and str(conflict_result.get("failure_code", "")) == "sequence_conflict", "different receipt ids cannot claim the same sequence")


func _case_invalid_and_recursive_private_input() -> void:
	var service: RefCounted = SERVICE_SCRIPT.new()
	var unknown := _receipt(10, "unknown_event", "unknown_outcome", {})
	var unknown_result := service.call("ingest_public_receipt", unknown) as Dictionary
	_expect(not bool(unknown_result.get("accepted", true)) and str(unknown_result.get("failure_code", "")) == "event_kind", "unknown event is rejected by the envelope policy")
	var private_candidate := _receipt(11, "public_inference_resolved", "public_clue_revealed", {"inference_reward_cents_delta": 25})
	private_candidate["metadata"] = {"nested": {"owner": "PRIVATE_SENTINEL"}}
	var private_result := service.call("ingest_public_receipt", private_candidate) as Dictionary
	_expect(not bool(private_result.get("accepted", true)) and str(private_result.get("failure_code", "")) == "forbidden_or_non_data_input", "recursive private sentinel is rejected before aggregation")
	var snapshot := service.call("aggregate_snapshot") as Dictionary
	_expect(bool(snapshot.get("evidence_incomplete", false)) and int(snapshot.get("rejected_receipt_count", 0)) == 2, "rejected evidence is explicit rather than silently ignored")
	_expect(int(snapshot.get("accepted_receipt_count", -1)) == 0, "invalid evidence never enters aggregate history")


func _case_overflow_marks_incomplete_without_eviction() -> void:
	var service: RefCounted = SERVICE_SCRIPT.new()
	_expect(bool(service.call("configure_receipt_capacity", 2)), "test service accepts a bounded capacity")
	var first := _receipt(1, "public_facility_committed", "facility_built", {"gdp_cents_per_minute_delta": 10})
	var second := _receipt(2, "route_contract_resolved", "route_income_realized", {"route_income_cents_delta": 20})
	var third := _receipt(3, "monster_pressure_resolved", "monster_damage_avoided", {"monster_damage_avoided_cents_delta": 30})
	service.call("ingest_public_receipt", first)
	service.call("ingest_public_receipt", second)
	var before_overflow := service.call("aggregate_snapshot") as Dictionary
	var overflow_result := service.call("ingest_public_receipt", third) as Dictionary
	var after_overflow := service.call("aggregate_snapshot") as Dictionary
	_expect(not bool(overflow_result.get("accepted", true)) and str(overflow_result.get("failure_code", "")) == "evidence_capacity_exceeded", "capacity overflow rejects the new receipt explicitly")
	_expect(bool(after_overflow.get("evidence_incomplete", false)) and int(after_overflow.get("overflow_count", 0)) == 1, "overflow marks evidence incomplete")
	_expect(int(after_overflow.get("accepted_receipt_count", 0)) == 2, "overflow never evicts retained history")
	_expect((before_overflow.get("tendencies", []) as Array) == (after_overflow.get("tendencies", []) as Array), "retained aggregate rows remain byte-identical after overflow")


func _case_pure_non_owner_boundary() -> void:
	var source := FileAccess.get_file_as_string(SERVICE_PATH)
	_expect(source.contains("extends RefCounted") and not source.contains("extends Node"), "telemetry reducer is pure RefCounted")
	for forbidden_token in ["func to_save_data(", "func apply_save_data(", "FileAccess.open", "DirAccess", "HTTPClient", "WorldBridge", "GameRuntimeCoordinator", "Main."]:
		_expect(not source.contains(forbidden_token), "telemetry source omits owner/runtime token %s" % forbidden_token)
	var service: RefCounted = SERVICE_SCRIPT.new()
	_expect(not service.has_method("to_save_data") and not service.has_method("apply_save_data") and not service.has_method("save") and not service.has_method("load"), "telemetry exposes no persistence API")


func _six_receipts() -> Array:
	return [
		_receipt(1, "public_facility_committed", "facility_built", {"gdp_cents_per_minute_delta": 120, "controlled_regions_delta": 1}),
		_receipt(2, "market_position_resolved", "market_gain_realized", {"weather_value_cents_delta": 40}),
		_receipt(3, "public_interaction_resolved", "public_pressure_applied", {"military_spend_cents_delta": 75}),
		_receipt(4, "monster_pressure_resolved", "monster_damage_avoided", {"monster_damage_avoided_cents_delta": 95}),
		_receipt(5, "route_contract_resolved", "route_income_realized", {"route_income_cents_delta": 130}),
		_receipt(6, "public_inference_resolved", "public_inference_rewarded", {"inference_reward_cents_delta": 55}),
	]


func _receipt(sequence: int, event_kind: String, outcome_code: String, deltas: Dictionary) -> Dictionary:
	return {
		"schema_version": POLICY_SCRIPT.SCHEMA_VERSION,
		"receipt_id": "pub.match.%04d" % sequence,
		"sequence": sequence,
		"world_effective_us": sequence * 1_000_000,
		"turn_marker": sequence / 2,
		"event_kind": event_kind,
		"public_outcome_code": outcome_code,
		"typed_deltas": deltas.duplicate(true),
		"source_receipt_ids": [],
	}


func _collect_forbidden_output(value: Variant, path: String, result: Array[String]) -> void:
	if value is Dictionary:
		for key_variant: Variant in value as Dictionary:
			var key := str(key_variant).to_lower()
			var child_path := "%s.%s" % [path, key]
			if FORBIDDEN_OUTPUT_KEYS.has(key) or key.begins_with("private_") or key.begins_with("hidden_") or key.begins_with("ai_"):
				result.append(child_path)
			_collect_forbidden_output((value as Dictionary)[key_variant], child_path, result)
	elif value is Array:
		for index in range((value as Array).size()):
			_collect_forbidden_output((value as Array)[index], "%s[%d]" % [path, index], result)
	elif value is String or value is StringName:
		var lowered := str(value).to_lower()
		for marker in ["private_sentinel", "player_", "seat_", "actor_", "owner_", "ai_plan", "ai_score"]:
			if lowered.contains(marker):
				result.append("%s:%s" % [path, marker])


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(label)
	push_error("OBSERVABLE STRATEGY TELEMETRY: %s" % label)
