extends SceneTree

const POLICY_SCRIPT := preload("res://scripts/runtime/public_match_receipt_envelope_policy_v06.gd")
const POLICY_PATH := "res://scripts/runtime/public_match_receipt_envelope_policy_v06.gd"

var _checks := 0
var _failures: Array[String] = []
var _policy: RefCounted = POLICY_SCRIPT.new()


func _init() -> void:
	_run()


func _run() -> void:
	_case_six_public_event_contracts()
	_case_strict_schema_and_typed_deltas()
	_case_recursive_privacy_rejection()
	_case_canonical_copy_and_sources()
	_case_pure_non_owner_boundary()
	print("PUBLIC_MATCH_RECEIPT_ENVELOPE_POLICY_V06_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()
	])
	quit(_failures.size())


func _case_six_public_event_contracts() -> void:
	var events := [
		["city_development_committed", "city_built", "city_growth"],
		["market_position_resolved", "market_gain_realized", "finance_speculation"],
		["public_interaction_resolved", "public_pressure_applied", "direct_interaction"],
		["monster_pressure_resolved", "monster_damage_avoided", "monster_pressure"],
		["route_contract_resolved", "route_income_realized", "contract_route"],
		["public_inference_resolved", "public_inference_rewarded", "intelligence_supply"],
	]
	for index in range(events.size()):
		var event := events[index] as Array
		var result := _policy.call("validate_and_seal", _receipt(index + 1, str(event[0]), str(event[1]))) as Dictionary
		_expect(bool(result.get("accepted", false)), "event %s has a legal public envelope" % str(event[0]))
		_expect(POLICY_SCRIPT.tendency_id_for_event_kind(str(event[0])) == str(event[2]), "event %s maps to one fixed tendency" % str(event[0]))
	var contract := _policy.call("contract_snapshot") as Dictionary
	_expect(contract.get("tendency_ids", []) == POLICY_SCRIPT.TENDENCY_IDS, "contract exposes six deterministic tendency ids")
	_expect((contract.get("typed_delta_ids", []) as Array).size() == 7, "contract exposes exactly seven typed public deltas")


func _case_strict_schema_and_typed_deltas() -> void:
	var wrong_schema := _receipt(1, "city_development_committed", "city_built")
	wrong_schema["schema_version"] = "v0.6.public-match-receipt.999"
	_expect(_failure_code(wrong_schema) == "schema_version", "wrong schema version fails closed")
	var unknown_field := _receipt(1, "city_development_committed", "city_built")
	unknown_field["notes"] = "public"
	_expect(_failure_code(unknown_field) == "receipt_fields", "unknown top-level field fails exact allowlist")
	var unknown_event := _receipt(1, "unknown_event", "city_built")
	_expect(_failure_code(unknown_event) == "event_kind", "unknown event kind fails closed")
	var wrong_outcome := _receipt(1, "city_development_committed", "route_income_realized")
	_expect(_failure_code(wrong_outcome) == "public_outcome_code", "outcome must belong to its event kind")
	var unknown_delta := _receipt(1, "city_development_committed", "city_built")
	unknown_delta["typed_deltas"] = {"cash": 99}
	_expect(_failure_code(unknown_delta) == "forbidden_or_non_data_input", "cash-like delta is rejected before allowlisting")
	var narrative_delta := _receipt(1, "city_development_committed", "city_built")
	narrative_delta["typed_deltas"] = {"story": "great move"}
	_expect(_failure_code(narrative_delta) == "typed_delta_key", "free-form narrative delta is rejected")
	var float_delta := _receipt(1, "city_development_committed", "city_built")
	float_delta["typed_deltas"] = {"gdp_cents_per_minute_delta": 1.5}
	_expect(_failure_code(float_delta) == "typed_delta_value", "public deltas require bounded integer units")


func _case_recursive_privacy_rejection() -> void:
	for forbidden_key in ["player_index", "seat_id", "actor_id", "profile_id", "card_id", "target", "bid", "weights", "scores", "reasons", "candidates", "plans", "learning", "owner", "hand", "discard", "cash_cents", "private_fingerprint"]:
		var candidate := _receipt(2, "market_position_resolved", "market_gain_realized")
		candidate["metadata"] = {"nested": {forbidden_key: "PRIVATE_SENTINEL"}}
		_expect(_failure_code(candidate) == "forbidden_or_non_data_input", "recursive private key %s is rejected" % forbidden_key)
	var private_source := _receipt(2, "market_position_resolved", "market_gain_realized")
	private_source["source_receipt_ids"] = ["pub.private.sentinel"]
	_expect(_failure_code(private_source) == "forbidden_or_non_data_input", "private sentinel cannot hide inside a source receipt id")
	var object_value := _receipt(2, "market_position_resolved", "market_gain_realized")
	object_value["typed_deltas"] = {"route_income_cents_delta": POLICY_SCRIPT.new()}
	_expect(_failure_code(object_value) == "forbidden_or_non_data_input", "runtime object cannot enter a public receipt")


func _case_canonical_copy_and_sources() -> void:
	var candidate := _receipt(7, "route_contract_resolved", "route_income_realized")
	candidate["source_receipt_ids"] = ["pub.source.z", "pub.source.a"]
	candidate["typed_deltas"] = {"route_income_cents_delta": 175, "gdp_cents_per_minute_delta": 12}
	var result := _policy.call("validate_and_seal", candidate) as Dictionary
	var sealed := (result.get("receipt", {}) as Dictionary).duplicate(true)
	(candidate["source_receipt_ids"] as Array)[0] = "pub.source.changed"
	(candidate["typed_deltas"] as Dictionary)["route_income_cents_delta"] = 9999
	_expect(bool(result.get("accepted", false)), "valid receipt seals successfully")
	_expect(sealed.get("source_receipt_ids", []) == ["pub.source.a", "pub.source.z"], "source receipt ids canonicalize deterministically")
	_expect(int((sealed.get("typed_deltas", {}) as Dictionary).get("route_income_cents_delta", 0)) == 175, "sealed receipt is detached from caller mutation")
	var self_source := _receipt(7, "route_contract_resolved", "route_income_realized")
	self_source["source_receipt_ids"] = [str(self_source.get("receipt_id", ""))]
	_expect(_failure_code(self_source) == "source_receipt_id", "receipt cannot cite itself")
	var duplicate_source := _receipt(7, "route_contract_resolved", "route_income_realized")
	duplicate_source["source_receipt_ids"] = ["pub.source.a", "pub.source.a"]
	_expect(_failure_code(duplicate_source) == "source_receipt_id", "duplicate source ids fail closed")


func _case_pure_non_owner_boundary() -> void:
	var source := FileAccess.get_file_as_string(POLICY_PATH)
	_expect(source.contains("extends RefCounted") and not source.contains("extends Node"), "policy is pure RefCounted, not a scene owner")
	for forbidden_token in ["func to_save_data(", "func apply_save_data(", "FileAccess.open", "DirAccess", "HTTPClient", "WorldBridge", "GameRuntimeCoordinator", "Main."]:
		_expect(not source.contains(forbidden_token), "policy source omits owner/runtime token %s" % forbidden_token)
	var result := _policy.call("validate_and_seal", _receipt(9, "public_inference_resolved", "public_clue_revealed")) as Dictionary
	_expect(_is_pure_data(result), "validation result is detached pure data")


func _receipt(sequence: int, event_kind: String, outcome_code: String) -> Dictionary:
	return {
		"schema_version": POLICY_SCRIPT.SCHEMA_VERSION,
		"receipt_id": "pub.match.%04d" % sequence,
		"sequence": sequence,
		"world_effective_us": sequence * 1_000_000,
		"turn_marker": sequence / 2,
		"event_kind": event_kind,
		"public_outcome_code": outcome_code,
		"typed_deltas": {"gdp_cents_per_minute_delta": sequence},
		"source_receipt_ids": [],
	}


func _failure_code(candidate: Variant) -> String:
	return str((_policy.call("validate_and_seal", candidate) as Dictionary).get("failure_code", ""))


func _is_pure_data(value: Variant) -> bool:
	if value is Callable or typeof(value) == TYPE_OBJECT:
		return false
	if value is Dictionary:
		for key_variant: Variant in value as Dictionary:
			if not _is_pure_data((value as Dictionary)[key_variant]):
				return false
	elif value is Array:
		for entry_variant: Variant in value as Array:
			if not _is_pure_data(entry_variant):
				return false
	return true


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(label)
	push_error("PUBLIC MATCH RECEIPT POLICY: %s" % label)
