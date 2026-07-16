extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const QA_SAVE_PATH := "user://test_runs/action_result_v1_facility_play_adopter.save"
const MAIN_SOURCE_PATH := "res://scripts/main.gd"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_qa_save()
	var main_source := FileAccess.get_file_as_string(MAIN_SOURCE_PATH)
	_expect(main_source.contains('coordinator.call(\n\t\t\t"execute_v06_facility_play_action"'), "Main delegates facility play through the public Coordinator action port")
	_expect(not main_source.contains('has_method("execute_v06_facility_play_action")'), "Main has no legacy fallback when the mandatory facility action port is unavailable")
	var main := MAIN_SCENE.instantiate()
	main.process_mode = Node.PROCESS_MODE_DISABLED
	var save := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController/GameSaveRuntimeCoordinator")
	_expect(save != null and bool(save.call("set_qa_default_save_path_override", QA_SAVE_PATH)), "production fixture isolates its save path")
	root.add_child(main)
	await _wait_frames(3)
	main.call("_start_scenario_from_menu", "first_table")
	await _wait_frames(4)
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	_expect(coordinator != null and coordinator.has_method("execute_v06_facility_play_action"), "Coordinator exposes the public facility-play ActionResult port")
	if coordinator == null:
		await _finish(main)
		return
	var binding: Dictionary = coordinator.call("refresh_v06_production_player_bindings", main)
	_expect(bool(binding.get("ai_v06_economy_port_ready", false)), "production card, facility and CommodityFlow owners are bound")
	var identity: Dictionary = coordinator.call("actor_id_for_player_index", 0)
	var actor_id := str(identity.get("actor_id", ""))
	var source_before: Dictionary = coordinator.call("economic_source_snapshot", actor_id)
	var market_before := _first_available_market(coordinator, actor_id)
	var listing: Dictionary = market_before.get("listing", {}) if market_before.get("listing", {}) is Dictionary else {}
	var player_before: Dictionary = coordinator.call("player_snapshot", actor_id)
	var purchase: Dictionary = coordinator.call(
		"purchase_rank_i_facility",
		actor_id,
		str(listing.get("item_id", "")),
		"action-result-v1:facility-purchase",
		int(market_before.get("revision", -1)),
		int(player_before.get("revision", -1)),
		int(source_before.get("revision", -1))
	)
	_expect(bool(purchase.get("committed", false)), "fixture purchases one canonical rank-I facility through the real owner")
	var player_after_purchase: Dictionary = coordinator.call("player_snapshot", actor_id)
	var cards: Array = player_after_purchase.get("cards", []) if player_after_purchase.get("cards", []) is Array else []
	var card: Dictionary = cards[0] if not cards.is_empty() and cards[0] is Dictionary else {}
	var target_region_id := str(listing.get("target_region_id", ""))
	var card_id := str(card.get("card_id", ""))
	var infrastructure: Object = coordinator.call("region_infrastructure_runtime_controller")
	var flow: Object = coordinator.call("commodity_flow_runtime_controller")
	var facilities_before := (infrastructure.call("facilities_snapshot", false) as Array).size()
	var installations_before := (flow.call("installations_snapshot", false) as Array).size()

	var wrong_card_result: Dictionary = coordinator.call("execute_v06_facility_play_action", actor_id, "card.missing", target_region_id)
	_expect(not bool(wrong_card_result.get("success", true)) and str(wrong_card_result.get("failure_code", "")) == "facility_play_card_changed", "a stale public card identity fails closed instead of playing another slot")
	var invalid_target_result: Dictionary = coordinator.call("execute_v06_facility_play_action", actor_id, card_id, "region.missing")
	_expect(not bool(invalid_target_result.get("success", true)) and str(invalid_target_result.get("failure_code", "")) == "facility_play_target_unavailable", "invalid region returns a concrete target failure")
	_expect((infrastructure.call("facilities_snapshot", false) as Array).size() == facilities_before and (flow.call("installations_snapshot", false) as Array).size() == installations_before, "all rejected attempts preserve both authoritative owners")

	var success: Dictionary = coordinator.call("execute_v06_facility_play_action", actor_id, card_id, target_region_id)
	_expect(bool(success.get("success", false)) and str(success.get("failure_code", "")) == "", "facility play projects one successful ActionResult")
	_expect(success.keys().size() == 14 and str(success.get("action_id", "")) == "facility_card_play" and str(success.get("action_family", "")) == "card_play", "public result uses the exact ActionResultV1 schema")
	_expect(not _contains_private_key_or_value(success), "public result contains no actor, slot, hand, cash, owner or transaction binding")
	_expect((infrastructure.call("facilities_snapshot", false) as Array).size() == facilities_before + 1 and (flow.call("installations_snapshot", false) as Array).size() == installations_before + 1, "success creates exactly one facility and one production installation")
	var source_after: Dictionary = coordinator.call("economic_source_snapshot", actor_id)
	_expect(bool(source_after.get("has_source", false)) and bool(source_after.get("bootstrap_finalized", false)) and not str(source_after.get("lineage_transaction_id", "")).is_empty(), "economic source derives finalized lineage from the existing owner journal")
	var expansion_source: Dictionary = coordinator.call("economic_source_snapshot", actor_id)
	var expansion_market := _first_available_market(coordinator, actor_id)
	var expansion_listing: Dictionary = expansion_market.get("listing", {}) if expansion_market.get("listing", {}) is Dictionary else {}
	var first_card: Dictionary = coordinator.call("v06_card_definition", str(listing.get("card_id", "")))
	var first_machine: Dictionary = first_card.get("machine", {}) if first_card.get("machine", {}) is Dictionary else {}
	var first_payload: Dictionary = first_machine.get("effect_payload", {}) if first_machine.get("effect_payload", {}) is Dictionary else {}
	var expansion_listing_card: Dictionary = coordinator.call("v06_card_definition", str(expansion_listing.get("card_id", "")))
	var expansion_listing_machine: Dictionary = expansion_listing_card.get("machine", {}) if expansion_listing_card.get("machine", {}) is Dictionary else {}
	var expansion_listing_payload: Dictionary = expansion_listing_machine.get("effect_payload", {}) if expansion_listing_machine.get("effect_payload", {}) is Dictionary else {}
	_expect(
		str(expansion_listing_payload.get("industry_id", expansion_listing_machine.get("industry_id", ""))) == str(first_payload.get("industry_id", first_machine.get("industry_id", "")))
			and str(expansion_listing_payload.get("facility_kind", "")) != str(first_payload.get("facility_kind", "")),
		"first-table market rotates from a Rank-I facility to the same-industry complementary facility (%s/%s/%s -> %s/%s/%s)" % [
			str(first_machine.get("card_id", "")),
			str(first_payload.get("industry_id", first_machine.get("industry_id", ""))),
			str(first_payload.get("facility_kind", "")),
			str(expansion_listing_machine.get("card_id", "")),
			str(expansion_listing_payload.get("industry_id", expansion_listing_machine.get("industry_id", ""))),
			str(expansion_listing_payload.get("facility_kind", "")),
		]
	)
	var expansion_player_before: Dictionary = coordinator.call("player_snapshot", actor_id)
	var expansion_purchase: Dictionary = coordinator.call(
		"purchase_rank_i_facility",
		actor_id,
		str(expansion_listing.get("item_id", "")),
		"action-result-v1:facility-expansion-purchase",
		int(expansion_market.get("revision", -1)),
		int(expansion_player_before.get("revision", -1)),
		int(expansion_source.get("revision", -1))
	)
	_expect(bool(expansion_purchase.get("committed", false)), "an established player can explicitly purchase a second facility while AI bootstrap remains one-shot")
	var expansion_player: Dictionary = coordinator.call("player_snapshot", actor_id)
	var expansion_cards: Array = expansion_player.get("cards", []) if expansion_player.get("cards", []) is Array else []
	var expansion_card: Dictionary = expansion_cards[0] if not expansion_cards.is_empty() and expansion_cards[0] is Dictionary else {}
	var expansion_card_id := str(expansion_card.get("card_id", ""))
	var expansion_result: Dictionary = coordinator.call("execute_v06_facility_play_action", actor_id, expansion_card_id, str(expansion_listing.get("target_region_id", "")))
	_expect(bool(expansion_result.get("success", false)), "PlayerBoard GDP expansion reuses the same public ActionResult and authoritative facility owners")
	_expect(
		(infrastructure.call("facilities_snapshot", false) as Array).size() == facilities_before + 2
			and (flow.call("installations_snapshot", false) as Array).size() == installations_before + 1,
		"same-industry market expansion adds one facility while the factory remains the sole player production installation"
	)
	var receipts_before: Array = coordinator.call("commodity_flow_recent_receipts", 0)
	var last_flow: Dictionary = {}
	for second in range(1, 9):
		last_flow = coordinator.call("advance_commodity_flow", 1.0, {
			"game_time": 120.0 + float(second),
			"player_count": 3,
		})
	var receipts_after: Array = coordinator.call("commodity_flow_recent_receipts", 0)
	_expect(bool(last_flow.get("advanced", false)) and bool((last_flow.get("bankruptcy_checkpoint", {}) as Dictionary).get("finalized", false)), "Coordinator advances the source through sale settlement and the bankruptcy checkpoint")
	_expect(receipts_after.size() > receipts_before.size(), "the first public GDP source produces at least one real Sale Receipt")
	var victory_tick: Dictionary = coordinator.call("advance_victory_control", 1.0, {})
	var own_victory: Dictionary = coordinator.call("victory_control_private_snapshot", 0)
	var own_candidate: Dictionary = own_victory.get("own_candidate", {}) if own_victory.get("own_candidate", {}) is Dictionary else {}
	_expect(bool(victory_tick.get("valid", false)) and int(own_candidate.get("controlled_region_count", 0)) >= 1 and int(own_candidate.get("top_k_gdp_per_minute", 0)) > 0, "Sale Receipt GDP gives the scripted player one real controlled region in VictoryControl")
	var runtime_screen := main.get_node_or_null("RuntimeGameScreen")
	_expect(runtime_screen != null and bool(runtime_screen.call("present_action_result", success)), "real GameScreen consumes the public result")
	var feedback: Dictionary = runtime_screen.call("get_runtime_player_feedback_snapshot") if runtime_screen != null else {}
	_expect(str(feedback.get("action_id", "")) == "facility_card_play" and str(feedback.get("state", "")) == "resolved", "real PlayerBoard feedback reports the committed facility action")
	await _finish(main)


func _contains_private_key_or_value(value: Variant) -> bool:
	var text := JSON.stringify(value).to_lower()
	for token in ["actor_id", "player_index", "slot_index", "runtime_instance", "transaction_id", "cash", "hand", "owner", "ai_"]:
		if text.contains(token):
			return true
	return false


func _wait_frames(count: int) -> void:
	for _frame in range(count):
		await process_frame


func _first_available_market(coordinator: Node, actor_id: String) -> Dictionary:
	var surface_variant: Variant = coordinator.call("v06_facility_market_snapshot", actor_id)
	var surface: Dictionary = surface_variant if surface_variant is Dictionary else {}
	var listing: Dictionary = surface.get("listing", {}) if surface.get("listing", {}) is Dictionary else {}
	var district_index := int(listing.get("source_district_index", -1))
	var chosen_second := -1
	for second in range(0, 120, 5):
		coordinator.call("restore_world_effective_seconds", float(second))
		var availability_variant: Variant = coordinator.call("card_market_listing_availability", district_index)
		var availability: Dictionary = availability_variant if availability_variant is Dictionary else {}
		if str(availability.get("availability_kind", "")) == "sunlit":
			chosen_second = second
			break
	if chosen_second >= 0:
		coordinator.call("restore_world_effective_seconds", float(chosen_second + 120))
	var market_variant: Variant = coordinator.call("market_snapshot", actor_id)
	return (market_variant as Dictionary).duplicate(true) if market_variant is Dictionary else {}


func _remove_qa_save() -> void:
	var absolute := ProjectSettings.globalize_path(QA_SAVE_PATH)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish(main: Node) -> void:
	main.queue_free()
	await process_frame
	_remove_qa_save()
	print("ACTION_RESULT_V1_FACILITY_PLAY_ADOPTER_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(_failures.size())
