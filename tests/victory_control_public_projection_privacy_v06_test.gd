extends SceneTree

const CONTROLLER_SCENE_PATH := "res://scenes/runtime/VictoryControlRuntimeController.tscn"
const POST_SETTLEMENT_CHECKPOINT := "post_world_settlement"
const PLAYER_ZERO_AVAILABLE := 91234000
const PLAYER_ZERO_ESCROW := 567
const PLAYER_ZERO_CASH := PLAYER_ZERO_AVAILABLE + PLAYER_ZERO_ESCROW
const PLAYER_ONE_AVAILABLE := 81234000
const PLAYER_ONE_ESCROW := 321
const PLAYER_ONE_CASH := PLAYER_ONE_AVAILABLE + PLAYER_ONE_ESCROW
const PLAYER_ZERO_PRIVATE_CARD := "private.card.player_zero"
const PLAYER_ONE_PRIVATE_CARD := "private.card.player_one"
const FORBIDDEN_PUBLIC_KEYS := [
	"cash",
	"cash_cents",
	"available",
	"available_cents",
	"escrow",
	"escrow_cents",
	"economic_assets",
	"audit_assets",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_public_audit_projection()
	_test_public_outcome_projection_preserves_internal_cash()
	_test_save_load_requires_fresh_audit_facts()
	_finish()


func _test_public_audit_projection() -> void:
	var controller := _new_controller("public audit projection")
	if controller == null:
		return
	var world := _world_snapshot()
	controller.call("advance_world_effective", 10.0, world)
	var public: Dictionary = controller.call("public_snapshot", -1)
	_expect(str(public.get("state", "")) == "audit", "eligible player enters the public audit")
	_expect(not (public.get("audit_entries", []) as Array).is_empty(), "public audit retains public qualification entries")
	_expect(str(public.get("cash_visibility", "")) == "public_audit" and (public.get("audit_revealed_player_indices", []) as Array) == [0], "owner publishes an explicit stable audit cash allowlist")
	var audit_entry: Dictionary = (public.get("audit_entries", []) as Array)[0] as Dictionary
	_expect(int(audit_entry.get("player_index", -1)) == 0 and typeof(audit_entry.get("cash_ledger_cents", null)) == TYPE_INT and int(audit_entry.get("cash_ledger_cents", -1)) == PLAYER_ZERO_CASH, "authorized audit entry publishes canonical exact cash")
	_expect(not _contains_exact_value(public, PLAYER_ONE_CASH), "non-audit seat exact cash remains hidden")
	var public_key_paths: Array[String] = []
	_collect_forbidden_key_paths(public, "public", public_key_paths)
	_expect(public_key_paths.is_empty(), "public audit recursively omits non-cash economic asset keys: %s" % [public_key_paths])
	var public_sentinel_paths: Array[String] = []
	_collect_exact_value_paths(public, [PLAYER_ZERO_AVAILABLE, PLAYER_ZERO_ESCROW, PLAYER_ONE_AVAILABLE, PLAYER_ONE_ESCROW, PLAYER_ONE_CASH, PLAYER_ZERO_PRIVATE_CARD, PLAYER_ONE_PRIVATE_CARD], "public", public_sentinel_paths)
	_expect(public_sentinel_paths.is_empty(), "public audit contains no unauthorized cash, asset, or hand sentinel: %s" % [public_sentinel_paths])
	var unauthorized_cash_paths: Array[String] = []
	_collect_unauthorized_cash_paths(public, [0], "public", unauthorized_cash_paths)
	_expect(unauthorized_cash_paths.is_empty(), "every exact cash field is bound to the owner audit allowlist: %s" % [unauthorized_cash_paths])
	_expect(_is_pure_data(public), "public audit projection is pure data")
	_expect(public == controller.call("public_snapshot", 0), "viewer argument does not turn the public projection into a private view")
	_expect(not public.has("own_economic_assets") and not public.has("own_candidate"), "anonymous public projection has no viewer-private envelope")
	var forged := public.duplicate(true)
	forged["audit_revealed_player_indices"] = [0, 1]
	(forged.get("audit_entries", []) as Array).append({"player_index": 1, "cash_visibility": "public_audit", "cash_ledger_cents": PLAYER_ONE_CASH})
	_expect(controller.call("public_snapshot") == public, "mutating a returned projection cannot forge owner authorization")

	var private_zero: Dictionary = controller.call("private_snapshot", 0)
	var own_assets: Dictionary = private_zero.get("own_economic_assets", {}) if private_zero.get("own_economic_assets", {}) is Dictionary else {}
	_expect(int(own_assets.get("available_cents", -1)) == PLAYER_ZERO_AVAILABLE and int(own_assets.get("escrow_cents", -1)) == PLAYER_ZERO_ESCROW and int(own_assets.get("cash_ledger_cents", -1)) == PLAYER_ZERO_CASH, "viewer-private snapshot exposes exact cash only in own_economic_assets")
	_expect(_contains_exact_value(own_assets, PLAYER_ZERO_PRIVATE_CARD), "viewer-private snapshot retains the viewer's own hand asset")
	_expect(not _contains_exact_value(private_zero, PLAYER_ONE_PRIVATE_CARD) and not _contains_exact_value(private_zero, PLAYER_ONE_CASH), "viewer-private snapshot never includes another seat's exact assets")
	var private_money_paths: Array[String] = []
	_collect_forbidden_key_paths(private_zero, "private", private_money_paths)
	var misplaced_private_paths := private_money_paths.filter(func(path: String) -> bool: return not path.begins_with("private.own_economic_assets."))
	_expect(misplaced_private_paths.is_empty(), "exact own assets appear only under own_economic_assets: %s" % [misplaced_private_paths])
	_expect(_is_pure_data(private_zero), "viewer-private projection remains pure data")
	controller.call("advance_world_effective", 120.0, world)
	var finalized: Dictionary = controller.call("public_snapshot")
	var public_receipt: Dictionary = finalized.get("outcome_receipt", {}) if finalized.get("outcome_receipt", {}) is Dictionary else {}
	var final_rankings: Array = public_receipt.get("rankings", []) if public_receipt.get("rankings", []) is Array else []
	_expect(str(finalized.get("state", "")) == "resolved" and str(finalized.get("cash_visibility", "")) == "public_audit" and (finalized.get("audit_revealed_player_indices", []) as Array) == [0], "normal finalized audit preserves only the authoritative cash allowlist")
	_expect(final_rankings.size() == 1 and int((final_rankings[0] as Dictionary).get("cash_ledger_cents", -1)) == PLAYER_ZERO_CASH, "finalized public ranking includes canonical cash only for the audited finalist")
	controller.free()


func _test_public_outcome_projection_preserves_internal_cash() -> void:
	var controller := _new_controller("public outcome projection")
	if controller == null:
		return
	var world := _world_snapshot()
	world["irreversible_planet_destruction_triggered"] = true
	world["scenario_allows_cash_fallback"] = true
	var resolved: Dictionary = controller.call("resolve_special_outcome", "planet_destroyed", world)
	var internal: Dictionary = controller.call("outcome_receipt")
	var internal_rankings: Array = internal.get("rankings", []) if internal.get("rankings", []) is Array else []
	_expect(not resolved.is_empty() and resolved == internal, "special outcome returns the authoritative internal receipt")
	_expect(internal_rankings.size() == 2 and int((internal_rankings[0] as Dictionary).get("cash_ledger_cents", -1)) == PLAYER_ZERO_CASH and int((internal_rankings[1] as Dictionary).get("cash_ledger_cents", -1)) == PLAYER_ONE_CASH, "internal rankings retain exact cash and cash tie-break order")
	_expect((internal.get("winner_player_indices", []) as Array) == [0] and (internal.get("comparison_order", []) as Array) == ["cash_ledger_cents"], "internal cash-only special outcome semantics remain unchanged")
	var save_payload: Dictionary = controller.call("to_save_data")
	var saved_domain: Dictionary = save_payload.get("victory_control_runtime", {}) if save_payload.get("victory_control_runtime", {}) is Dictionary else {}
	_expect(saved_domain.get("outcome_receipt", {}) == internal, "save data retains the authoritative exact internal receipt")

	var internal_before_projection := internal.duplicate(true)
	var public: Dictionary = controller.call("public_snapshot", -1)
	var public_receipt: Dictionary = public.get("outcome_receipt", {}) if public.get("outcome_receipt", {}) is Dictionary else {}
	var public_key_paths: Array[String] = []
	_collect_forbidden_key_paths(public, "public", public_key_paths)
	var public_cash_paths: Array[String] = []
	_collect_key_paths(public, "cash_ledger_cents", "public", public_cash_paths)
	_expect(public_key_paths.is_empty() and public_cash_paths.is_empty(), "non-audit outcome recursively omits cash fields and private asset envelopes: %s %s" % [public_key_paths, public_cash_paths])
	var public_sentinel_paths: Array[String] = []
	_collect_exact_value_paths(public, [PLAYER_ZERO_AVAILABLE, PLAYER_ZERO_ESCROW, PLAYER_ZERO_CASH, PLAYER_ONE_AVAILABLE, PLAYER_ONE_ESCROW, PLAYER_ONE_CASH, PLAYER_ZERO_PRIVATE_CARD, PLAYER_ONE_PRIVATE_CARD], "public", public_sentinel_paths)
	_expect(public_sentinel_paths.is_empty(), "public outcome contains no renamed exact-cash or private-hand sentinel: %s" % [public_sentinel_paths])
	var public_rankings: Array = public_receipt.get("rankings", []) if public_receipt.get("rankings", []) is Array else []
	_expect(public_rankings.size() == 2 and int((public_rankings[0] as Dictionary).get("player_index", -1)) == 0 and bool((public_rankings[0] as Dictionary).get("winner", false)), "public outcome preserves ranking order and winner without exact cash")
	_expect(public_receipt.get("comparison_order", []) == ["cash_ledger_cents"], "public outcome may name the published tie-break rule without exposing values")
	_expect(controller.call("outcome_receipt") == internal_before_projection, "building the public projection never mutates the internal outcome receipt")
	_expect(_is_pure_data(public), "public outcome projection is pure data")
	controller.free()


func _test_save_load_requires_fresh_audit_facts() -> void:
	var source := _new_controller("audit save source")
	var target := _new_controller("audit save target")
	if source == null or target == null:
		return
	var source_world := _world_snapshot()
	source.call("advance_world_effective", 10.0, source_world)
	var saved: Dictionary = source.call("to_save_data")
	var target_world := _world_snapshot()
	(target_world["players"][0] as Dictionary)["cash_ledger_cents"] = 77777777
	target.call("advance_world_effective", 10.0, target_world)
	var applied: Dictionary = target.call("apply_save_data", saved)
	_expect(bool(applied.get("applied", false)), "valid audit save applies atomically")
	var immediately_after_load: Dictionary = target.call("public_snapshot")
	_expect(not immediately_after_load.has("cash_visibility") and not immediately_after_load.has("audit_revealed_player_indices"), "load clears stale audit authorization until fresh world facts arrive")
	var stale_cash_paths: Array[String] = []
	_collect_key_paths(immediately_after_load, "cash_ledger_cents", "public", stale_cash_paths)
	_expect(stale_cash_paths.is_empty() and not _contains_exact_value(immediately_after_load, 77777777), "previous runtime cash cache cannot leak after load")
	target.call("advance_world_effective", 0.0, source_world)
	var refreshed: Dictionary = target.call("public_snapshot")
	_expect(str(refreshed.get("cash_visibility", "")) == "public_audit" and (refreshed.get("audit_revealed_player_indices", []) as Array) == [0], "fresh authoritative world facts restore the saved audit authorization")
	_expect(_contains_exact_value(refreshed, PLAYER_ZERO_CASH), "fresh candidate cash is used after load")
	var before_invalid: Dictionary = target.call("to_save_data")
	var invalid := saved.duplicate(true)
	(invalid["victory_control_runtime"] as Dictionary)["audit_roster"] = [0, 0]
	var invalid_result: Dictionary = target.call("apply_save_data", invalid)
	_expect(not bool(invalid_result.get("applied", true)) and target.call("to_save_data") == before_invalid, "duplicate audit roster fails closed before mutation")
	source.free()
	target.free()


func _new_controller(label: String) -> Node:
	var packed := load(CONTROLLER_SCENE_PATH) as PackedScene
	_expect(packed != null, "%s scene loads" % label)
	if packed == null:
		return null
	var controller := packed.instantiate()
	_expect(controller != null, "%s scene instantiates" % label)
	if controller == null:
		return null
	root.add_child(controller)
	var configured: Dictionary = controller.call("configure")
	_expect(bool(configured.get("configured", false)), "%s configures from v0.6 resources" % label)
	if not bool(configured.get("configured", false)):
		controller.free()
		return null
	return controller


func _world_snapshot() -> Dictionary:
	return {
		"schema_version": "v0.6.victory-world.2",
		"players": [
			{
				"player_index": 0,
				"eliminated": false,
				"cash_ledger_cents": PLAYER_ZERO_CASH,
				"audit_assets": _private_assets(PLAYER_ZERO_AVAILABLE, PLAYER_ZERO_ESCROW, PLAYER_ZERO_CASH, PLAYER_ZERO_PRIVATE_CARD),
			},
			{
				"player_index": 1,
				"eliminated": false,
				"cash_ledger_cents": PLAYER_ONE_CASH,
				"audit_assets": _private_assets(PLAYER_ONE_AVAILABLE, PLAYER_ONE_ESCROW, PLAYER_ONE_CASH, PLAYER_ONE_PRIVATE_CARD),
			},
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


func _private_assets(available_cents: int, escrow_cents: int, cash_ledger_cents: int, card_id: String) -> Dictionary:
	return {
		"available_cents": available_cents,
		"escrow_cents": escrow_cents,
		"cash_ledger_cents": cash_ledger_cents,
		"ordinary_hand": [{"card_id": card_id}],
		"facilities": [],
		"installations": [],
		"commodity_inventory": [],
		"color_gdp": {},
		"units": [],
		"contracts": [],
		"financial_positions": [],
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


func _collect_forbidden_key_paths(value: Variant, path: String, result: Array[String]) -> void:
	if value is Dictionary:
		for key_variant in value.keys():
			var key := str(key_variant)
			var child_path := "%s.%s" % [path, key]
			if FORBIDDEN_PUBLIC_KEYS.has(key.to_lower()):
				result.append(child_path)
			_collect_forbidden_key_paths(value[key_variant], child_path, result)
	elif value is Array:
		for index in range(value.size()):
			_collect_forbidden_key_paths(value[index], "%s[%d]" % [path, index], result)


func _collect_key_paths(value: Variant, target_key: String, path: String, result: Array[String]) -> void:
	if value is Dictionary:
		for key_variant in value.keys():
			var child_path := "%s.%s" % [path, str(key_variant)]
			if str(key_variant) == target_key:
				result.append(child_path)
			_collect_key_paths(value[key_variant], target_key, child_path, result)
	elif value is Array:
		for index in range(value.size()):
			_collect_key_paths(value[index], target_key, "%s[%d]" % [path, index], result)


func _collect_unauthorized_cash_paths(value: Variant, authorized: Array, path: String, result: Array[String]) -> void:
	if value is Dictionary:
		var row: Dictionary = value
		if row.has("cash_ledger_cents"):
			var player_variant: Variant = row.get("player_index", null)
			var cash_variant: Variant = row.get("cash_ledger_cents", null)
			if typeof(player_variant) != TYPE_INT or not authorized.has(int(player_variant)) or typeof(cash_variant) != TYPE_INT or str(row.get("cash_visibility", "")) != "public_audit":
				result.append(path)
		for key_variant in row.keys():
			_collect_unauthorized_cash_paths(row[key_variant], authorized, "%s.%s" % [path, str(key_variant)], result)
	elif value is Array:
		for index in range(value.size()):
			_collect_unauthorized_cash_paths(value[index], authorized, "%s[%d]" % [path, index], result)


func _collect_exact_value_paths(value: Variant, sentinels: Array, path: String, result: Array[String]) -> void:
	if value is Dictionary:
		for key_variant in value.keys():
			_collect_exact_value_paths(value[key_variant], sentinels, "%s.%s" % [path, str(key_variant)], result)
	elif value is Array:
		for index in range(value.size()):
			_collect_exact_value_paths(value[index], sentinels, "%s[%d]" % [path, index], result)
	elif sentinels.has(value):
		result.append(path)


func _contains_exact_value(value: Variant, target: Variant) -> bool:
	var paths: Array[String] = []
	_collect_exact_value_paths(value, [target], "value", paths)
	return not paths.is_empty()


func _is_pure_data(value: Variant) -> bool:
	if value is Object or value is Callable:
		return false
	if value is Dictionary:
		for key_variant in value.keys():
			if not _is_pure_data(key_variant) or not _is_pure_data(value[key_variant]):
				return false
	elif value is Array:
		for item_variant in value:
			if not _is_pure_data(item_variant):
				return false
	return true


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	print("VICTORY_CONTROL_PUBLIC_PROJECTION_PRIVACY_V06_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(_failures.size())
