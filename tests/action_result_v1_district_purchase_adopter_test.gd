extends SceneTree

const ACTION_RESULT_SCRIPT := preload("res://scripts/runtime/action_result_v1.gd")
const PRESENTATION_SERVICE_SCRIPT := preload("res://scripts/runtime/action_result_presentation_service.gd")
const MAIN_SCENE := preload("res://scenes/main.tscn")
const QA_SAVE_PATH := "user://test_runs/action_result_v1_district_purchase_adopter.save"
const PRIVATE_SENTINELS := [
	"ARV1_RIVAL_CASH_SENTINEL",
	"ARV1_RIVAL_HAND_SENTINEL",
	"ARV1_HIDDEN_OWNER_SENTINEL",
	"ARV1_AI_WEIGHT_SENTINEL",
	"ARV1_PRIVATE_QUOTE_SENTINEL",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_projection_contract()
	await _test_real_production_adopter()
	_test_main_helper_retirement()
	_finish()


func _test_projection_contract() -> void:
	var service := PRESENTATION_SERVICE_SCRIPT.new() as Node
	service.call("configure", {})
	var schema: Array = service.call("public_field_schema")
	var success: Dictionary = service.call("compose", {
		"schema_version": 1,
		"action_id": "district_card_purchase",
		"action_family": "card_market",
		"public_receipt": {"event_code": "anonymous_purchase_committed", "district_index": 7, "price_cash": 202},
	})
	_expect(bool(success.get("success", false)) and str(success.get("failure_code", "")) == "", "public anonymous-purchase receipt projects one success ActionResult")
	_expect(_same_string_set(success.keys(), schema), "purchase success exposes only the strict ActionResult v1 field schema")
	_expect(success.get("affected_entity_ids", []) == ["district:7"] and str(success.get("focus_target", "")) == "district_supply", "purchase success focuses the public source district without actor identity")
	_expect(str(success.get("relevant_cost", "")) == "¥202" and str(success.get("consequence", "")).contains("支付¥202"), "purchase success explains the public locked price and committed consequence")
	_expect(_required_copy_present(success) and not _contains_private_value(success), "purchase success contains complete decision copy and no private fact")

	var failure_cases := [
		["v06_card_runtime_not_ready", "purchase_market_unavailable"],
		["market_listing_changed", "purchase_listing_changed"],
		["source_item_unavailable", "purchase_source_unavailable"],
		["market_quote_binding_mismatch", "purchase_terms_unavailable"],
		["cash_insufficient", "purchase_funds_unavailable"],
		["inventory_commit_failed", "purchase_inventory_unavailable"],
		["state_port_commit_failed", "purchase_conflict"],
	]
	for case_variant in failure_cases:
		var case: Array = case_variant as Array
		var failure: Dictionary = service.call("compose", {
			"schema_version": 1,
			"action_id": "district_card_purchase",
			"action_family": "card_market",
			"failure_code": str(case[0]),
		})
		_expect(not bool(failure.get("success", true)) and str(failure.get("failure_code", "")) == str(case[1]), "%s maps to stable public failure %s" % [case[0], case[1]])
		_expect(_same_string_set(failure.keys(), schema) and failure.get("affected_entity_ids", []) == [], "purchase failure keeps the strict schema and claims no committed entity")
		_expect(_required_copy_present(failure) and not _contains_private_value(failure), "purchase failure remains decision-complete and privacy-safe")

	for forbidden_patch in [
		{"cash": 999999},
		{"hand": ["ARV1_RIVAL_HAND_SENTINEL"]},
		{"owner": "ARV1_HIDDEN_OWNER_SENTINEL"},
		{"ai_weight": "ARV1_AI_WEIGHT_SENTINEL"},
		{"quote_id": "ARV1_PRIVATE_QUOTE_SENTINEL"},
		{"quote_fingerprint": "ARV1_PRIVATE_QUOTE_SENTINEL"},
	]:
		var unsafe := {
			"schema_version": 1,
			"action_id": "district_card_purchase",
			"action_family": "card_market",
			"failure_code": "market_listing_changed",
		}
		for key_variant in forbidden_patch.keys():
			unsafe[key_variant] = forbidden_patch[key_variant]
		var rejected: Dictionary = service.call("compose", unsafe)
		_expect(str(rejected.get("failure_code", "")) == "unsafe_source" and not _contains_private_value(rejected), "private purchase source fails closed without echoing private input")

	var overbroad_receipt: Dictionary = service.call("compose", {
		"schema_version": 1,
		"action_id": "district_card_purchase",
		"action_family": "card_market",
		"public_receipt": {
			"event_code": "anonymous_purchase_committed",
			"district_index": 7,
			"price_cash": 202,
			"card_id": "PRIVATE_CARD",
		},
	})
	_expect(str(overbroad_receipt.get("failure_code", "")) == "unsafe_source", "success projection rejects receipt fields beyond event code and public district")
	service.free()


func _test_real_production_adopter() -> void:
	var main := MAIN_SCENE.instantiate()
	main.process_mode = Node.PROCESS_MODE_DISABLED
	var save := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController/GameSaveRuntimeCoordinator")
	_expect(save != null and bool(save.call("set_qa_default_save_path_override", QA_SAVE_PATH)), "production fixture isolates its save path")
	root.add_child(main)
	await _wait_frames(3)
	main.call("_start_scenario_from_menu", "first_table")
	await _wait_frames(4)

	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	var screen := main.get("runtime_game_screen") as Control
	_expect(coordinator != null and screen != null, "real Main composes Coordinator and GameScreen for the purchase action")
	if coordinator == null or screen == null:
		main.queue_free()
		await process_frame
		return
	var players: Array = main.get("players") if main.get("players") is Array else []
	var actor_id := str((players[0] as Dictionary).get("actor_id", "player.0")) if not players.is_empty() and players[0] is Dictionary else "player.0"
	var market: Dictionary = coordinator.call("v06_first_table_facility_market_snapshot", actor_id)
	var listing: Dictionary = market.get("listing", {}) if market.get("listing", {}) is Dictionary else {}
	var card: Dictionary = listing.get("card", {}) if listing.get("card", {}) is Dictionary else {}
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	var card_id := str(machine.get("card_id", ""))
	_expect(bool(market.get("ready", false)) and not card_id.is_empty(), "production owner exposes one ready regional rank-I facility listing")

	var owner_before: Dictionary = coordinator.call("v06_card_player_snapshot", actor_id)
	var quote: Dictionary = market.get("quote", {}) if market.get("quote", {}) is Dictionary else {}
	_expect(str(quote.get("availability_kind", "")) == "sunlit" and bool(quote.get("confirmable", false)), "authored first-table source has one player-bound confirmable quote before the purchase action")
	var expected_price := int(quote.get("final_price", -1))
	var market_revision_before := int((market.get("market", {}) as Dictionary).get("revision", -1)) if market.get("market", {}) is Dictionary else -1
	var failure_before: Dictionary = coordinator.call("execute_v06_facility_purchase_action", actor_id, "%s:stale" % card_id)
	var owner_after_failure: Dictionary = coordinator.call("v06_card_player_snapshot", actor_id)
	var market_after_failure: Dictionary = coordinator.call("v06_first_table_facility_market_snapshot", actor_id)
	_expect(str(failure_before.get("failure_code", "")) == "purchase_listing_changed" and not bool(failure_before.get("success", true)), "production action projects an owner listing mismatch as structured failure")
	_expect(owner_after_failure == owner_before and int(((market_after_failure.get("market", {}) as Dictionary).get("revision", -2))) == market_revision_before, "failed production action leaves owner player and market revisions unchanged")

	var players_before_private_probe: Array = (main.get("players") as Array).duplicate(true) if main.get("players") is Array else []
	var private_probe_players := players_before_private_probe.duplicate(true)
	if private_probe_players.size() > 1 and private_probe_players[1] is Dictionary:
		var rival := (private_probe_players[1] as Dictionary).duplicate(true)
		rival["cash"] = int(rival.get("cash", 0)) + 997
		rival["private_hand_probe"] = "ARV1_RIVAL_HAND_SENTINEL"
		rival["hidden_owner"] = "ARV1_HIDDEN_OWNER_SENTINEL"
		rival["ai_weight"] = "ARV1_AI_WEIGHT_SENTINEL"
		private_probe_players[1] = rival
		main.set("players", private_probe_players)
	var failure_after_private_change: Dictionary = coordinator.call("execute_v06_facility_purchase_action", actor_id, "%s:stale" % card_id)
	_expect(failure_after_private_change == failure_before and not _contains_private_value(failure_after_private_change), "rival cash, hand, owner and AI weight cannot influence or enter the public failure projection")
	main.set("players", players_before_private_probe)

	main.call("_on_district_supply_action_requested", "district_supply_purchase_card", {"card_name": card_id})
	await _wait_frames(3)
	var owner_after_success: Dictionary = coordinator.call("v06_card_player_snapshot", actor_id)
	var market_after_success: Dictionary = coordinator.call("v06_first_table_facility_market_snapshot", actor_id)
	var next_listing: Dictionary = market_after_success.get("listing", {}) if market_after_success.get("listing", {}) is Dictionary else {}
	var next_card: Dictionary = next_listing.get("card", {}) if next_listing.get("card", {}) is Dictionary else {}
	var next_machine: Dictionary = next_card.get("machine", {}) if next_card.get("machine", {}) is Dictionary else {}
	var feedback: Dictionary = screen.call("get_runtime_player_feedback_snapshot")
	_expect(int(owner_after_success.get("revision", -1)) == int(owner_before.get("revision", -1)) + 1, "real UI purchase commits the authoritative player revision exactly once")
	_expect(int(((market_after_success.get("market", {}) as Dictionary).get("revision", -1))) == market_revision_before + 1, "real UI purchase commits the authoritative market revision exactly once")
	_expect(_inventory_count(owner_after_success) == _inventory_count(owner_before) + 1, "real UI purchase atomically adds one ordinary facility card")
	_expect(int(owner_after_success.get("card_purchase_count", -1)) == int(owner_before.get("card_purchase_count", 0)) + 1, "real UI purchase advances the authoritative purchase count exactly once")
	_expect(int(owner_after_success.get("total_card_spend", -1)) == int(owner_before.get("total_card_spend", 0)) + expected_price, "real UI purchase records the locked public price in the authoritative spend ledger")
	_expect(str(next_machine.get("card_id", "")) != card_id and str(next_machine.get("category_id", "")) == "facility" and int(next_machine.get("rank", 0)) == 1, "successful purchase rotates the public market to a different legal rank-I facility")
	_expect(str(feedback.get("action_id", "")) == "district_card_purchase" and str(feedback.get("state", "")) == "resolved", "real GameScreen receives structured purchase success feedback")
	_expect(not _contains_private_value(feedback) and not str(feedback).contains("quote_id") and not str(feedback).contains("quote_fingerprint"), "visible purchase feedback omits rival facts and private quote binding")

	main.queue_free()
	await process_frame


func _test_main_helper_retirement() -> void:
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	_expect(not main_source.contains("func _purchase_v06_first_table_facility_card(") and not main_source.contains("_purchase_v06_first_table_facility_card("), "old Main facility-purchase helper has zero definitions and references")
	for retired_copy in [
		"城市设施牌市场已经刷新，请重新选择。",
		"已购买一张I级城市设施牌；现金¥-",
		"城市设施牌未购买：",
	]:
		_expect(not main_source.contains(retired_copy), "old ambiguous Main purchase copy is physically deleted: %s" % retired_copy)
	_expect(main_source.contains("execute_v06_facility_purchase_action") and main_source.contains("district_card_purchase"), "Main dispatch consumes the Coordinator ActionResult directly without a replacement wrapper")
	_expect(coordinator_source.contains("public_receipt") and coordinator_source.contains("anonymous_purchase_committed") and coordinator_source.contains("compose_action_result_v1(action_source)"), "Coordinator projects only the owner public receipt or failure code after atomic purchase")


func _inventory_count(player: Dictionary) -> int:
	var inventory: Dictionary = player.get("inventory", {}) if player.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	var count := 0
	for slot_variant in slots:
		if slot_variant is Dictionary and not (slot_variant as Dictionary).is_empty():
			count += 1
	return count


func _required_copy_present(result: Dictionary) -> bool:
	for key in ["title", "explanation", "consequence", "suggested_action", "focus_target", "relevant_cost", "relevant_requirement"]:
		if str(result.get(key, "")).strip_edges().is_empty():
			return false
	return true


func _same_string_set(left: Array, right: Array) -> bool:
	var left_strings: Array[String] = []
	var right_strings: Array[String] = []
	for value in left:
		left_strings.append(str(value))
	for value in right:
		right_strings.append(str(value))
	left_strings.sort()
	right_strings.sort()
	return left_strings == right_strings


func _contains_private_value(value: Variant) -> bool:
	var serialized := var_to_str(value)
	for sentinel in PRIVATE_SENTINELS:
		if serialized.contains(sentinel):
			return true
	for token in ["quote_id", "quote_fingerprint", "owner_player_index", "ai_weight"]:
		if serialized.to_lower().contains(token):
			return true
	return false


func _wait_frames(count: int) -> void:
	for _frame in range(maxi(1, count)):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error("ACTION RESULT PURCHASE ADOPTER: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("ACTION_RESULT_V1_DISTRICT_PURCHASE_ADOPTER_TEST|status=PASS|checks=%d" % _checks)
		quit(0)
		return
	push_error("ActionResult district-purchase adopter failed:\n- %s" % "\n- ".join(_failures))
	quit(1)
