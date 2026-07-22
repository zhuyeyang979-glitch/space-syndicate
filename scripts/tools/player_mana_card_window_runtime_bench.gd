extends Control

const OUTPUT_DIR := "user://space_syndicate_design_qa/player_mana_card_window/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/player_mana_card_window_ss06_04.png"
const RULESET_V06_PROFILE := preload("res://resources/rules/space_syndicate_ruleset_v06.tres")
const MANA_SCENE := preload("res://scenes/runtime/PlayerManaRuntimeController.tscn")
const QUEUE_SCRIPT := preload("res://scripts/runtime/card_resolution_queue_runtime_service.gd")
const ELIGIBILITY_SCRIPT := preload("res://scripts/runtime/card_play_eligibility_runtime_service.gd")
const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")

@onready var status_label: Label = %Status
@onready var summary_label: RichTextLabel = %Summary

var _records: Array = []
var _failures := 0
var _mana: PlayerManaRuntimeController
var _queue: CardResolutionQueueRuntimeService
var _eligibility: CardPlayEligibilityRuntimeService


func _ready() -> void:
	call_deferred("_run_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func run_cases_preview() -> Array:
	return [
		"profile_and_scene_composition", "initial_private_pools", "recovery_exact_rate",
		"fractional_recovery_remainder", "per_color_cap", "no_natural_decay",
		"color_isolation", "player_isolation", "fixed_color_payment", "dual_color_payment",
		"generic_deterministic_allocation", "generic_preferred_allocation", "insufficient_atomic",
		"reservation_hides_availability", "consume_exact_once", "release_exact_once",
		"save_load_round_trip", "public_privacy_boundary", "pure_data_snapshots",
		"eligibility_free_commodity", "eligibility_asset_allowed", "eligibility_asset_rejected",
		"queue_v06_configuration", "queue_accepts_one_ordinary_card", "queue_rejects_second_without_capability",
		"queue_lock_rejects_submission", "queue_rotating_seat_order", "queue_asset_receipt_only",
		"legacy_capacity_owner_absent", "legacy_priority_bid_owner_absent",
		"commodity_flow_observer_boundary", "coordinator_static_composition",
	]


func build_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id_variant in run_cases_preview():
		records.append({"case_id": str(case_id_variant), "category": "preview", "passed": false, "notes": "Not executed", "evidence": {}})
	return {"suite_id": "ss06_04_player_mana_card_window", "records": records}


func _run_suite() -> void:
	_mana = MANA_SCENE.instantiate() as PlayerManaRuntimeController
	_queue = QUEUE_SCRIPT.new() as CardResolutionQueueRuntimeService
	_eligibility = ELIGIBILITY_SCRIPT.new() as CardPlayEligibilityRuntimeService
	add_child(_mana)
	add_child(_queue)
	add_child(_eligibility)
	var configured := _mana.configure(RULESET_V06_PROFILE.debug_snapshot())
	_queue.configure(_queue_config())
	_eligibility.configure(_queue_config())
	_check("profile_and_scene_composition", "composition", bool(configured.get("configured", false)) and str(configured.get("ruleset_id", "")) == "v0.6", configured)
	_run_recovery_cases()
	_run_transaction_cases()
	_run_eligibility_cases()
	_run_queue_cases()
	_run_ownership_cases()
	_finish_suite()


func _run_recovery_cases() -> void:
	_mana.reset_state(2)
	var initial := _mana.private_snapshot(0)
	_check("initial_private_pools", "recovery", _all_asset_values(_dictionary(initial.get("assets", {})), 0) and not initial.has("generic"), {"assets": initial.get("assets", {}), "private": true})
	var exact := _mana.advance(1000, 1.0, {"0": _flow_row({"life": 100})})
	var after_exact := _mana.availability_snapshot(0)
	_check("recovery_exact_rate", "recovery", bool(exact.get("advanced", false)) and int(_dictionary(after_exact.get("assets", {})).get("life", -1)) == 1, {"life_assets": _dictionary(after_exact.get("assets", {})).get("life", -1), "gdp_per_minute": 100, "seconds": 1})
	_mana.reset_state(1)
	_mana.advance(1000, 1.0, {"0": _flow_row({"life": 50})})
	var half := _mana.availability_snapshot(0)
	_mana.advance(1000, 2.0, {"0": _flow_row({"life": 50})})
	var whole := _mana.availability_snapshot(0)
	_check("fractional_recovery_remainder", "recovery", int(_dictionary(half.get("assets", {})).get("life", -1)) == 0 and int(_dictionary(whole.get("assets", {})).get("life", -1)) == 1, {"after_one_second": _dictionary(half.get("assets", {})).get("life", -1), "after_two_seconds": _dictionary(whole.get("assets", {})).get("life", -1)})
	_seed_pools({"0": _asset_milliunits({"life": 99})})
	_mana.advance(2000, 4.0, {"0": _flow_row({"life": 100})})
	var capped := _mana.availability_snapshot(0)
	_check("per_color_cap", "recovery", int(_dictionary(capped.get("assets", {})).get("life", -1)) == 100, {"life_assets": _dictionary(capped.get("assets", {})).get("life", -1), "maximum": 100})
	_seed_pools({"0": _asset_milliunits({"energy": 7})})
	_mana.advance(1000, 5.0, {"0": _flow_row({})})
	var no_decay := _mana.availability_snapshot(0)
	_check("no_natural_decay", "recovery", int(_dictionary(no_decay.get("assets", {})).get("energy", -1)) == 7, {"energy_assets": _dictionary(no_decay.get("assets", {})).get("energy", -1)})
	_mana.reset_state(2)
	_mana.advance(1000, 6.0, {"0": _flow_row({"technology": 100}), "1": _flow_row({"shipping": 200})})
	var player_zero := _dictionary(_mana.availability_snapshot(0).get("assets", {}))
	var player_one := _dictionary(_mana.availability_snapshot(1).get("assets", {}))
	_check("color_isolation", "recovery", int(player_zero.get("technology", 0)) == 1 and int(player_zero.get("shipping", 0)) == 0, {"player_zero": player_zero})
	_check("player_isolation", "recovery", int(player_one.get("shipping", 0)) == 2 and int(player_one.get("technology", 0)) == 0, {"player_one": player_one})


func _run_transaction_cases() -> void:
	_seed_pools({"0": _asset_milliunits({"life": 5, "energy": 5, "industry": 5, "technology": 5, "commerce": 5, "shipping": 5})})
	var fixed := _mana.plan_reservation(_request("fixed", {"life": 2}))
	_check("fixed_color_payment", "payment", bool(fixed.get("accepted", false)) and int(_dictionary(fixed.get("asset_debit", {})).get("life", 0)) == 2, {"debit": fixed.get("asset_debit", {})})
	var dual := _mana.plan_reservation(_request("dual", {"energy": 1, "technology": 2}))
	_check("dual_color_payment", "payment", bool(dual.get("accepted", false)) and int(_dictionary(dual.get("asset_debit", {})).get("energy", 0)) == 1 and int(_dictionary(dual.get("asset_debit", {})).get("technology", 0)) == 2, {"debit": dual.get("asset_debit", {})})
	_seed_pools({"0": _asset_milliunits({"life": 2, "energy": 5, "industry": 5})})
	var generic := _mana.plan_reservation(_request("generic", {"generic": 4}))
	_check("generic_deterministic_allocation", "payment", bool(generic.get("accepted", false)) and int(_dictionary(generic.get("asset_debit", {})).get("energy", 0)) == 4, {"debit": generic.get("asset_debit", {}), "tie_break": "stable_asset_order"})
	var preferred_request := _request("preferred", {"generic": 2})
	preferred_request["generic_asset_allocation"] = {"shipping": 2}
	_seed_pools({"0": _asset_milliunits({"shipping": 3, "life": 8})})
	var preferred := _mana.plan_reservation(preferred_request)
	_check("generic_preferred_allocation", "payment", bool(preferred.get("accepted", false)) and int(_dictionary(preferred.get("asset_debit", {})).get("shipping", 0)) == 2, {"debit": preferred.get("asset_debit", {})})
	_seed_pools({"0": _asset_milliunits({"life": 1})})
	var insufficient := _mana.plan_reservation(_request("insufficient", {"life": 2}))
	_check("insufficient_atomic", "payment", not bool(insufficient.get("accepted", false)) and int(_mana.debug_snapshot().get("reservation_count", -1)) == 0 and int(_dictionary(_mana.availability_snapshot(0).get("assets", {})).get("life", -1)) == 1, {"reason": insufficient.get("reason", ""), "reservation_count": _mana.debug_snapshot().get("reservation_count", -1)})
	_seed_pools({"0": _asset_milliunits({"commerce": 5})})
	var consume_plan := _mana.plan_reservation(_request("consume", {"commerce": 2}))
	var consume_commit := _mana.commit_reservation(consume_plan)
	var while_reserved := _mana.availability_snapshot(0)
	_check("reservation_hides_availability", "transaction", bool(consume_commit.get("authorized", false)) and int(_dictionary(while_reserved.get("assets", {})).get("commerce", -1)) == 3, {"available": _dictionary(while_reserved.get("assets", {})).get("commerce", -1), "transaction_id": consume_commit.get("transaction_id", "")})
	var consumed := _mana.consume_reservation("consume", {"resolved": true})
	var consumed_again := _mana.consume_reservation("consume", {"resolved": true})
	_check("consume_exact_once", "transaction", str(consumed.get("outcome", "")) == "consumed" and bool(consumed_again.get("duplicate", false)) and int(_dictionary(_mana.availability_snapshot(0).get("assets", {})).get("commerce", -1)) == 3, {"first": consumed.get("outcome", ""), "duplicate": consumed_again.get("duplicate", false)})
	_seed_pools({"0": _asset_milliunits({"shipping": 4})})
	var release_plan := _mana.plan_reservation(_request("release", {"shipping": 3}))
	_mana.commit_reservation(release_plan)
	var released := _mana.release_reservation("release", "effect_failed")
	var released_again := _mana.release_reservation("release", "effect_failed")
	_check("release_exact_once", "transaction", str(released.get("outcome", "")) == "released" and bool(released_again.get("duplicate", false)) and int(_dictionary(_mana.availability_snapshot(0).get("assets", {})).get("shipping", -1)) == 4, {"first": released.get("outcome", ""), "duplicate": released_again.get("duplicate", false)})
	_seed_pools({"0": _asset_milliunits({"industry": 6})})
	var save_plan := _mana.plan_reservation(_request("save-reservation", {"industry": 2}))
	_mana.commit_reservation(save_plan)
	var save_data := _mana.to_save_data()
	_mana.reset_state()
	var applied := _mana.apply_save_data(save_data)
	_check("save_load_round_trip", "save", bool(applied.get("applied", false)) and int(_dictionary(_mana.availability_snapshot(0).get("assets", {})).get("industry", -1)) == 4 and int(_mana.debug_snapshot().get("reservation_count", -1)) == 1, {"available_industry": _dictionary(_mana.availability_snapshot(0).get("assets", {})).get("industry", -1), "reservation_count": _mana.debug_snapshot().get("reservation_count", -1)})
	var public := _mana.public_snapshot()
	_check("public_privacy_boundary", "privacy", bool(public.get("asset_balances_private", false)) and not public.has("assets") and not public.has("pools_by_player"), public)
	_check("pure_data_snapshots", "privacy", _is_pure_data(_mana.private_snapshot(0)) and _is_pure_data(public) and _is_pure_data(save_data), {"private": true, "public": true, "save": true})


func _run_eligibility_cases() -> void:
	_seed_pools({"0": _asset_milliunits({"life": 3, "technology": 1})})
	var facts := _eligibility_facts()
	facts["player_mana"] = _mana.availability_snapshot(0)
	var commodity := _eligibility.evaluate_play({"evaluation_mode": "rule", "skill": {"name": "commodity.card", "schema_version": "v0.6", "kind": "commodity", "asset_cost": {"life": 0, "energy": 0, "industry": 0, "technology": 0, "commerce": 0, "shipping": 0, "generic": 0}}}, facts)
	_check("eligibility_free_commodity", "eligibility", bool(commodity.get("allowed", false)) and _all_zero(_dictionary(commodity.get("asset_cost", {}))), {"reason": commodity.get("reason_code", ""), "asset_cost": commodity.get("asset_cost", {})})
	var allowed := _eligibility.evaluate_play({"evaluation_mode": "rule", "skill": {"name": "technology.action", "schema_version": "v0.6", "kind": "intel", "asset_cost": {"life": 0, "energy": 0, "industry": 0, "technology": 1, "commerce": 0, "shipping": 0, "generic": 2}}}, facts)
	_check("eligibility_asset_allowed", "eligibility", bool(allowed.get("allowed", false)) and str(_dictionary(allowed.get("asset_status", {})).get("authoritative_allocation_owner", "")) == "PlayerManaRuntimeController", {"reason": allowed.get("reason_code", ""), "asset_status": allowed.get("asset_status", {})})
	var rejected := _eligibility.evaluate_play({"evaluation_mode": "rule", "skill": {"name": "shipping.action", "schema_version": "v0.6", "kind": "intel", "asset_cost": {"life": 0, "energy": 0, "industry": 0, "technology": 0, "commerce": 0, "shipping": 1, "generic": 0}}}, facts)
	_check("eligibility_asset_rejected", "eligibility", not bool(rejected.get("allowed", true)) and str(rejected.get("reason_code", "")) == "asset_insufficient", {"reason": rejected.get("reason_code", ""), "args": rejected.get("reason_args", {})})


func _run_queue_cases() -> void:
	_queue.reset_state()
	var queue_debug := _queue.debug_snapshot()
	_check("queue_v06_configuration", "queue", bool(queue_debug.get("service_ready", false)) and str(queue_debug.get("ruleset_id", "")) == "v0.6", queue_debug)
	var first_plan := _queue.plan_submission(_queue_request(0, 0), _queue_facts(false, 45.0, 2))
	var first_commit := _queue.commit_submission(first_plan, _queue_commit_receipt())
	_check("queue_accepts_one_ordinary_card", "queue", bool(first_commit.get("committed", false)) and _queue.current_queue().size() == 1, {"queue_count": _queue.current_queue().size()})
	var second_request := _queue_request(0, 1)
	second_request["group_card_limit"] = 3
	second_request["max_cards"] = 3
	var second := _queue.plan_submission(second_request, _queue_facts(false, 44.0, 2))
	_check("queue_rejects_second_without_capability", "queue", not bool(second.get("accepted", true)) and str(second.get("reason", "")) == "group_full" and int(second.get("card_limit", -1)) == 1, {"reason": second.get("reason", ""), "card_limit": second.get("card_limit", -1)})
	var locked := _queue.plan_submission(_queue_request(1, 0), _queue_facts(true, 1.0, 2))
	_check("queue_lock_rejects_submission", "queue", not bool(locked.get("accepted", true)) and str(locked.get("reason", "")) == "active_resolution", {"reason": locked.get("reason", "")})
	_queue.reset_state()
	for player_index in [2, 0, 1]:
		var plan := _queue.plan_submission(_queue_request(player_index, 0), _queue_facts(false, 45.0, 2))
		_queue.commit_submission(plan, _queue_commit_receipt())
	var ordered_players: Array = []
	for entry_variant in _queue.current_queue():
		ordered_players.append(int((entry_variant as Dictionary).get("player_index", -1)))
	_check("queue_rotating_seat_order", "queue", ordered_players == [0, 1, 2], {"reference_player": 2, "ordered_players": ordered_players})
	var entry := _queue.current_queue()[0] as Dictionary
	_check("queue_asset_receipt_only", "queue", entry.has("asset_reservation_id") and not entry.has("capacity_reservation") and not entry.has("priority_bid_cents"), {"entry_keys": entry.keys()})


func _run_ownership_cases() -> void:
	var queue_source := FileAccess.get_file_as_string("res://scripts/runtime/card_resolution_queue_runtime_service.gd")
	var commodity_source := FileAccess.get_file_as_string("res://scripts/runtime/commodity_flow_runtime_controller.gd")
	_check("legacy_capacity_owner_absent", "ownership", queue_source.find("_capacity_preflight") < 0 and queue_source.find("capacity_reservations_by_group") < 0, {"queue_source_checked": true})
	_check("legacy_priority_bid_owner_absent", "ownership", queue_source.find("set_group_priority_bid_cents") < 0 and queue_source.find("public_wager_pool_receipt") < 0, {"queue_source_checked": true})
	_check("commodity_flow_observer_boundary", "ownership", commodity_source.find("asset_recovery_observation_only") >= 0 and commodity_source.find("mana_gdp_per_minute_divisor") < 0 and commodity_source.find("mana_per_color_maximum") < 0, {"commodity_source_checked": true})
	var coordinator := COORDINATOR_SCENE.instantiate()
	var mana_node := coordinator.get_node_or_null("PlayerManaRuntimeController")
	_check("coordinator_static_composition", "composition", mana_node != null and mana_node is PlayerManaRuntimeController, {"node_path": "PlayerManaRuntimeController", "static_instance": mana_node != null})
	coordinator.queue_free()


func _finish_suite() -> void:
	var manifest := {
		"suite_id": "ss06_04_player_mana_card_window",
		"ruleset_id": "v0.6",
		"record_count": _records.size(),
		"passed_count": _records.size() - _failures,
		"failed_count": _failures,
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"records": _records.duplicate(true),
	}
	_write_outputs(manifest)
	var passed := _records.size() - _failures
	status_label.text = "%d/%d passed" % [passed, _records.size()]
	status_label.modulate = Color("#67e8a4") if _failures == 0 else Color("#fb7185")
	summary_label.text = "[b]Six private asset pools[/b]\nRecovery: commodity GDP/min / 100 per second, cap 100, no decay.\nCommitment: reserve on submit; consume on resolved effect; release on failure or skip.\nWindow: 30 seconds = 20 planning + 5 public bid + 5 lock; opening sequences 0-2 use 45/35/5/5; one ordinary card unless an authoritative capability raises the limit.\n\nManifest: %s\nReport: %s" % [MANIFEST_PATH, REPORT_PATH]
	set_meta("bench_exit_code", 0 if _failures == 0 else 1)
	set_meta("passed_count", passed)
	set_meta("record_count", _records.size())
	print("PLAYER_MANA_CARD_WINDOW_BENCH|passed=%d|total=%d|manifest=%s|report=%s|screenshot=%s" % [passed, _records.size(), MANIFEST_PATH, REPORT_PATH, SCREENSHOT_PATH])


func _check(case_id: String, category: String, passed: bool, evidence: Dictionary) -> void:
	if not passed:
		_failures += 1
	_records.append({"case_id": case_id, "category": category, "passed": passed, "notes": "passed" if passed else "check failed", "evidence": evidence.duplicate(true)})
	print("PLAYER_MANA_CARD_WINDOW_CASE|case=%s|passed=%s" % [case_id, str(passed)])


func _write_outputs(manifest: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var manifest_file := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if manifest_file != null:
		manifest_file.store_string(JSON.stringify(manifest, "  "))
	var report_file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if report_file == null:
		return
	var lines: Array[String] = [
		"# SS06-04 Player Mana & Card Window Runtime Gate", "", "- Ruleset: `v0.6`",
		"- Result: `%d/%d`" % [int(manifest.get("passed_count", 0)), int(manifest.get("record_count", 0))],
		"- Player-facing term: `六色资产`", "- Runtime owner: `PlayerManaRuntimeController`", "",
		"| Case | Category | Passed |", "|---|---|---|",
	]
	for record_variant in _records:
		var record := record_variant as Dictionary
		lines.append("| `%s` | %s | %s |" % [str(record.get("case_id", "")), str(record.get("category", "")), "yes" if bool(record.get("passed", false)) else "no"])
	report_file.store_string("\n".join(lines) + "\n")


func _queue_config() -> Dictionary:
	return {"ruleset_id": "v0.6", "card_group": RULESET_V06_PROFILE.card_group_rules(), "mana": RULESET_V06_PROFILE.mana_rules(), "capabilities": RULESET_V06_PROFILE.capability_rules()}


func _request(transaction_id: String, asset_cost: Dictionary) -> Dictionary:
	return {"transaction_id": transaction_id, "player_index": 0, "asset_cost": asset_cost.duplicate(true)}


func _queue_request(player_index: int, slot_index: int) -> Dictionary:
	return {"player_index": player_index, "slot_index": slot_index, "group_card_limit": 1, "available_cash_cents": 0, "skill": {"name": "bench.card.%d.%d" % [player_index, slot_index], "kind": "bench", "schema_version": "v0.6", "asset_cost": {}}}


func _queue_facts(batch_locked: bool, timer: float, reference_player: int) -> Dictionary:
	return {"player_count": 3, "counter_window_active": false, "batch_locked": batch_locked, "simultaneous_timer": timer, "lock_duration": 5.0, "public_bid_duration": 5.0, "window_sequence": 0, "reference_player": reference_player}


func _queue_commit_receipt() -> Dictionary:
	return {"authorized": true, "inventory_committed": true, "play_cost_authorized": true, "financial_margin_authorized": true, "asset_authorized": true}


func _eligibility_facts() -> Dictionary:
	return {"player_valid": true, "player_eliminated": false, "player_cash": 0, "player_count": 4, "monster_count": 0, "selected_district": 0, "selected_district_destroyed": false, "best_share_district": 0, "share_basis_points_by_district": {"0": 0}}


func _seed_pools(rows: Dictionary) -> void:
	var save_data := _mana.to_save_data()
	save_data["pools_by_player"] = rows.duplicate(true)
	var remainders := {}
	for player_key_variant in rows.keys():
		remainders[str(player_key_variant)] = _empty_asset_values()
	save_data["recovery_remainders_by_player"] = remainders
	save_data["reservations"] = {}
	save_data["terminal_receipts"] = {}
	_mana.apply_save_data(save_data)


func _flow_row(values: Dictionary) -> Dictionary:
	var colors := {}
	for asset_id_variant in PlayerManaRuntimeController.ASSET_IDS:
		var asset_id := str(asset_id_variant)
		colors[asset_id] = {"gdp_per_minute": maxi(0, int(values.get(asset_id, 0)))}
	return {"colors": colors}


func _asset_milliunits(values: Dictionary) -> Dictionary:
	var result := _empty_asset_values()
	for asset_id_variant in values.keys():
		result[str(asset_id_variant)] = maxi(0, int(values.get(asset_id_variant, 0))) * PlayerManaRuntimeController.MILLIASSET_SCALE
	return result


func _empty_asset_values() -> Dictionary:
	var result := {}
	for asset_id_variant in PlayerManaRuntimeController.ASSET_IDS:
		result[str(asset_id_variant)] = 0
	return result


func _all_asset_values(values: Dictionary, expected: int) -> bool:
	for asset_id_variant in PlayerManaRuntimeController.ASSET_IDS:
		if int(values.get(str(asset_id_variant), -1)) != expected:
			return false
	return true


func _all_zero(values: Dictionary) -> bool:
	for value_variant in values.values():
		if int(value_variant) != 0:
			return false
	return true


func _all_committed(results: Array) -> bool:
	for result_variant in results:
		if not (result_variant is Dictionary) or not bool((result_variant as Dictionary).get("committed", false)):
			return false
	return true


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _is_pure_data(value: Variant) -> bool:
	if value is Callable or typeof(value) == TYPE_OBJECT:
		return false
	if value is Dictionary:
		for key_variant in value.keys():
			if not _is_pure_data(key_variant) or not _is_pure_data(value[key_variant]):
				return false
	elif value is Array:
		for item in value:
			if not _is_pure_data(item):
				return false
	return true
