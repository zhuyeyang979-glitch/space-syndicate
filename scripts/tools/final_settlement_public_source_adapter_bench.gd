extends Node

const AUDITED_CASH_CENTS := 98765432100
const PRIVATE_CASH_CENTS := 12345678900

@onready var _adapter: Node = $FinalSettlementPublicSourceAdapter
@onready var _snapshot_service: Node = $FinalSettlementPublicSnapshotService


func _ready() -> void:
	var failures: Array[String] = []
	_snapshot_service.call("configure", {})
	var hidden_public := _victory_public_snapshot()
	var hidden_source := _adapter.call("compose_public_source", _facts(hidden_public)) as Dictionary
	if _contains_value(hidden_source, AUDITED_CASH_CENTS):
		failures.append("cash_without_visibility_was_exposed")

	var authorized_public := hidden_public.duplicate(true)
	authorized_public["cash_visibility"] = "public_audit"
	authorized_public["audit_revealed_player_indices"] = [0]
	authorized_public["audit_entries"] = [
		{"player_index": 0, "cash_ledger_cents": AUDITED_CASH_CENTS},
		{"player_index": 1, "cash_ledger_cents": PRIVATE_CASH_CENTS},
	]
	var authorized_source := _adapter.call("compose_public_source", _facts(authorized_public)) as Dictionary
	var authorized_log := _adapter.call("public_outcome_log_payload", authorized_public, {"0": "P1", "1": "P2"}) as Dictionary
	if not _contains_value(authorized_source, AUDITED_CASH_CENTS) or not _contains_value(authorized_log, "987654321.00"):
		failures.append("authorized_audit_cash_was_hidden")
	if _contains_value(authorized_source, PRIVATE_CASH_CENTS) or _contains_value(authorized_log, "123456789.00"):
		failures.append("non_audit_cash_was_exposed")
	var production_snapshot := _snapshot_service.call("compose", authorized_source) as Dictionary
	if str(authorized_source.get("cash_visibility", "")) != "public_audit" or authorized_source.get("audit_revealed_player_indices", []) != [0] or not _contains_value(production_snapshot, "987654321.00") or _contains_value(production_snapshot, "123456789.00"):
		failures.append("production_snapshot_service_did_not_preserve_authorized_projection")

	var forged_public := authorized_public.duplicate(true)
	forged_public.erase("cash_visibility")
	var forged_source := _adapter.call("compose_public_source", _facts(forged_public)) as Dictionary
	if _contains_value(forged_source, AUDITED_CASH_CENTS):
		failures.append("forged_cash_without_state_authorization_was_exposed")

	var status := "PASS" if failures.is_empty() else "FAIL"
	print("FINAL_SETTLEMENT_PUBLIC_SOURCE_ADAPTER_BENCH|status=%s|checks=5|failures=%d|notes=%s" % [status, failures.size(), JSON.stringify(failures)])
	if not failures.is_empty():
		push_error("FinalSettlementPublicSourceAdapter bench failed: %s" % [failures])


func _victory_public_snapshot() -> Dictionary:
	return {
		"state": "resolved",
		"victory_rule": {"required_top_k_gdp_per_minute": 72, "required_region_count": 2},
		"audit_entries": [],
		"outcome_receipt": {
			"outcome_id": "bench-outcome",
			"schema_version": "v0.6",
			"ruleset_id": "v0.6",
			"reason_code": "public_audit_complete",
			"winner_player_indices": [0],
			"co_victory": false,
			"comparison_order": ["top_k_gdp_per_minute", "controlled_region_count", "cash_ledger_cents"],
			"rankings": [
				{"player_index": 0, "top_k_gdp_per_minute": 120, "controlled_region_count": 3, "winner": true},
				{"player_index": 1, "top_k_gdp_per_minute": 90, "controlled_region_count": 2, "winner": false},
			],
		},
	}


func _facts(victory_public: Dictionary) -> Dictionary:
	return {
		"reason": "bench",
		"victory_public_snapshot": victory_public,
		"participant_public_facts": [
			{"player_index": 0, "name": "P1", "gdp_per_minute": 120},
			{"player_index": 1, "name": "P2", "gdp_per_minute": 90},
		],
		"map_facts": {},
	}


func _contains_value(value: Variant, needle: Variant) -> bool:
	if value is Dictionary:
		for child_variant in value.values():
			if _contains_value(child_variant, needle):
				return true
		return false
	if value is Array:
		for child_variant in value:
			if _contains_value(child_variant, needle):
				return true
		return false
	if value is String:
		return str(value).contains(str(needle))
	return typeof(value) == typeof(needle) and value == needle
