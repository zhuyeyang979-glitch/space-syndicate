extends Node
class_name VictoryAuditVisibilityV06Bench

const POST_SETTLEMENT_CHECKPOINT := "post_world_settlement"
const AUTHORIZED_CASH_CENTS := 45678901
const HIDDEN_CASH_CENTS := 98765432

@onready var victory_owner: Node = %VictoryControlRuntimeController


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	call_deferred("_run_bench")


func _run_bench() -> void:
	var failures: Array[String] = []
	var configured: Dictionary = victory_owner.call("configure")
	_check(bool(configured.get("configured", false)), "production_owner_configured", failures)
	var world := _world_snapshot()
	var pre_audit: Dictionary = victory_owner.call("public_snapshot")
	_check(not pre_audit.has("cash_visibility"), "pre_audit_cash_hidden", failures)
	victory_owner.call("advance_world_effective", 10.0, world)
	var audit: Dictionary = victory_owner.call("public_snapshot")
	_check(str(audit.get("state", "")) == "audit", "audit_state_entered", failures)
	_check(str(audit.get("cash_visibility", "")) == "public_audit", "owner_authorizes_public_audit", failures)
	_check((audit.get("audit_revealed_player_indices", []) as Array) == [0], "stable_owner_roster", failures)
	_check(_authorized_cash(audit, 0) == AUTHORIZED_CASH_CENTS, "authorized_cash_is_canonical_int", failures)
	_check(not _contains_value(audit, HIDDEN_CASH_CENTS), "non_roster_cash_hidden", failures)
	_check(not _contains_forbidden_private_key(audit), "recursive_private_fields_hidden", failures)
	var saved: Dictionary = victory_owner.call("to_save_data")
	var applied: Dictionary = victory_owner.call("apply_save_data", saved)
	_check(bool(applied.get("applied", false)), "save_round_trip_applied", failures)
	var after_load: Dictionary = victory_owner.call("public_snapshot")
	_check(not after_load.has("cash_visibility") and not _contains_key(after_load, "cash_ledger_cents"), "load_clears_stale_cash_projection", failures)
	victory_owner.call("advance_world_effective", 0.0, world)
	var refreshed: Dictionary = victory_owner.call("public_snapshot")
	_check(_authorized_cash(refreshed, 0) == AUTHORIZED_CASH_CENTS, "fresh_world_facts_restore_authorization", failures)
	var debug: Dictionary = victory_owner.call("debug_snapshot")
	_check(bool(debug.get("owns_public_audit_roster", false)) and bool(debug.get("owns_public_audit_cash_authorization", false)), "production_owner_declares_visibility_capability", failures)
	print("VICTORY_AUDIT_VISIBILITY_V06_BENCH|status=%s|checks=11|failures=%d|owner=%s|state=%s|authorized=%s" % [
		"PASS" if failures.is_empty() else "FAIL",
		failures.size(),
		str(debug.get("controller_id", "")),
		str(refreshed.get("state", "")),
		JSON.stringify(refreshed.get("audit_revealed_player_indices", [])),
	])
	if not failures.is_empty():
		push_error("VictoryAuditVisibilityV06Bench failed: %s" % ", ".join(failures))


func _world_snapshot() -> Dictionary:
	return {
		"schema_version": "v0.6.victory-world.2",
		"players": [
			{"player_index": 0, "eliminated": false, "cash_ledger_cents": AUTHORIZED_CASH_CENTS, "audit_assets": {}},
			{"player_index": 1, "eliminated": false, "cash_ledger_cents": HIDDEN_CASH_CENTS, "audit_assets": {}},
		],
		"regions": [
			_region(0, 7200, {"0": 3600}),
			_region(1, 7200, {"0": 3600}),
			_region(2, 0, {}),
			_region(3, 0, {}),
			_region(4, 0, {}),
		],
		"clock_pause": {},
		"settlement_checkpoint": POST_SETTLEMENT_CHECKPOINT,
	}


func _region(index: int, gdp_cents: int, player_gdp: Dictionary) -> Dictionary:
	return {
		"region_id": "region.%04d" % index,
		"district_index": index,
		"lifecycle_state": "active",
		"destroyed": false,
		"region_gdp_per_minute_cents": gdp_cents,
		"player_gdp_by_index": player_gdp.duplicate(true),
	}


func _authorized_cash(snapshot: Dictionary, player_index: int) -> int:
	for entry_variant in snapshot.get("audit_entries", []):
		if entry_variant is Dictionary:
			var entry: Dictionary = entry_variant
			if int(entry.get("player_index", -1)) == player_index and typeof(entry.get("cash_ledger_cents", null)) == TYPE_INT and str(entry.get("cash_visibility", "")) == "public_audit":
				return int(entry.get("cash_ledger_cents", -1))
	return -1


func _contains_value(value: Variant, target: Variant) -> bool:
	if value is Dictionary:
		for child_variant in value.values():
			if _contains_value(child_variant, target):
				return true
	elif value is Array:
		for child_variant in value:
			if _contains_value(child_variant, target):
				return true
	else:
		return typeof(value) == typeof(target) and value == target
	return false


func _contains_key(value: Variant, target_key: String) -> bool:
	if value is Dictionary:
		for key_variant in value.keys():
			if str(key_variant) == target_key or _contains_key(value[key_variant], target_key):
				return true
	elif value is Array:
		for child_variant in value:
			if _contains_key(child_variant, target_key):
				return true
	return false


func _contains_forbidden_private_key(value: Variant) -> bool:
	for key in ["available_cents", "escrow_cents", "ordinary_hand", "discard", "owner_truth", "true_owner", "ai_private_plan"]:
		if _contains_key(value, key):
			return true
	return false


func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
