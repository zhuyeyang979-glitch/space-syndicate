extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const QA_SAVE_PATH := "user://test_runs/human_region_supply_purchase_cutover_v06.save"
const FIXED_SEED := 6071601

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_source_cutover()
	await _verify_real_main_purchase()
	_finish()


func _verify_source_cutover() -> void:
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var coordinator_source := FileAccess.get_file_as_string(
		"res://scripts/runtime/game_runtime_coordinator.gd"
	)
	var inventory_source := FileAccess.get_file_as_string(
		"res://scripts/runtime/commodity_card_inventory_runtime_controller.gd"
	)
	var card_flow_source := FileAccess.get_file_as_string(
		"res://scripts/cards/v06/card_flow_transaction_service_v06.gd"
	)
	var purchase_source := _function_source(
		main_source,
		"_buy_card_for_player_from_district"
	)
	_expect(
		not purchase_source.is_empty()
			and purchase_source.contains("purchase_region_supply_card")
			and purchase_source.contains("v06_card_player_snapshot")
			and purchase_source.contains("_district_supply_listing")
			and not purchase_source.contains("plan_district_purchase_settlement")
			and not purchase_source.contains("commit_district_purchase_with_region_supply"),
		"human purchase entry uses only the production RegionSupply CardFlow facade"
	)
	_expect(
		not main_source.contains("func _district_purchase_settlement_request(")
			and not coordinator_source.contains(
				"func commit_district_purchase_with_region_supply("
			),
		"legacy district settlement request and temporary bridge are physically deleted"
	)
	for legacy_facade in [
		"card_exists",
		"card_definition",
		"card_rank",
		"card_family_id",
	]:
		_expect(
			not _function_source(coordinator_source, legacy_facade).contains(
				"v06_card_definition"
			),
			"legacy %s facade remains schema-pure" % legacy_facade
		)
	_expect(
		_function_source(
			coordinator_source,
			"configure_region_supply_from_world"
		).contains("_v06_region_supply_market_card_ids")
			and not _function_source(
				main_source,
				"_district_supply_card_source"
			).contains("coordinator.card_definition(")
			and not main_source.contains(
				"func _v06_first_table_facility_supply_source("
			)
			and not main_source.contains("func _preview_v06_facility_card("),
		"active RegionSupply uses one stable v0.6 catalog without a side facility rack"
	)
	var role_bonus_source := _function_source(
		main_source,
		"_grant_role_bonus_card_on_purchase"
	)
	_expect(
		role_bonus_source.contains("grant_v06_runtime_card")
			and role_bonus_source.contains("source_transaction_id")
			and not role_bonus_source.contains("_acquire_card_for_player")
			and coordinator_source.contains("func grant_v06_runtime_card(")
			and inventory_source.contains("func grant_card(")
			and card_flow_source.contains("func grant_card("),
		"role bonus acquisition uses the same v0.6 CardFlow inventory owner"
	)


func _verify_real_main_purchase() -> void:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	_expect(packed != null, "real main scene loads")
	if packed == null:
		return
	var main := packed.instantiate()
	var save := main.get_node_or_null(
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController/GameSaveRuntimeCoordinator"
	)
	_expect(
		save != null
			and bool(save.call("set_qa_default_save_path_override", QA_SAVE_PATH)),
		"real main uses an isolated QA save path"
	)
	var rng_variant: Variant = main.get("rng")
	if rng_variant is RandomNumberGenerator:
		(rng_variant as RandomNumberGenerator).seed = FIXED_SEED
	root.add_child(main)
	await _wait_frames(8)
	main.set("configured_player_count", 3)
	main.set("configured_ai_player_count", 2)
	main.set("configured_roguelike_depth", 1)
	main.set("configured_role_indices", [0, 1, 2])
	main.set("configured_starter_monster_indices", [0, 1, 2])
	main.call("_new_game")
	await _wait_frames(10)
	main.set_process(false)

	var coordinator := main.get_node_or_null(
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator"
	)
	_expect(coordinator != null, "production GameRuntimeCoordinator is composed")
	if coordinator == null:
		main.queue_free()
		await process_frame
		return
	var rack_snapshot: Dictionary = coordinator.call(
		"region_supply_public_rack"
	)
	var active_card_ids := _active_supply_card_ids(rack_snapshot)
	_expect(
		not active_card_ids.is_empty(),
		"real new game exposes non-empty active RegionSupply listings"
	)
	var stable_catalog_only := not active_card_ids.is_empty()
	for card_id_variant in active_card_ids:
		var card_id := str(card_id_variant)
		stable_catalog_only = stable_catalog_only \
			and _is_stable_v06_id(card_id) \
			and not (
				coordinator.call("v06_card_definition", card_id) as Dictionary
			).is_empty()
	_expect(
		stable_catalog_only,
		"every active RegionSupply listing uses an ASCII stable v0.6 catalog id"
	)
	var inventory: Object = coordinator.call(
		"commodity_card_inventory_runtime_controller"
	)
	_expect(inventory != null, "production card inventory transaction owner is composed")
	if inventory == null:
		main.queue_free()
		await process_frame
		return

	var choice := _find_purchasable_listing(main, coordinator)
	_expect(not choice.is_empty(), "one real public RegionSupply listing is purchasable")
	if choice.is_empty():
		main.queue_free()
		await process_frame
		return
	var district_index := int(choice.get("district_index", -1))
	var listing: Dictionary = choice.get("listing", {}) as Dictionary
	var actor_id := str(choice.get("actor_id", ""))
	var before_player: Dictionary = coordinator.call(
		"v06_card_player_snapshot",
		actor_id
	)
	var before_inventory: Dictionary = before_player.get(
		"inventory",
		{}
	) as Dictionary
	var before_rack := _region_slots(
		coordinator.call(
			"region_supply_public_rack",
			str(listing.get("source_region_id", ""))
		) as Dictionary
	)
	var other_slots_before := _other_slots_json(
		before_rack,
		int(listing.get("slot_index", -1))
	)
	var settlement_before: Dictionary = coordinator.call(
		"district_purchase_settlement_debug"
	)
	var journal_before: Dictionary = inventory.call("transaction_journal_snapshot")

	var bought := bool(main.call(
		"_buy_card_for_player_from_district",
		0,
		district_index,
		str(listing.get("card_id", "")),
		false,
		true,
		-1,
		""
	))
	var after_player: Dictionary = coordinator.call(
		"v06_card_player_snapshot",
		actor_id
	)
	var journal: Dictionary = inventory.call("transaction_journal_snapshot")
	var terminal := _new_region_purchase_terminal(
		journal_before,
		journal,
		str(listing.get("card_id", ""))
	)
	var terminal_result: Dictionary = terminal.get("result", {}) \
		if terminal.get("result", {}) is Dictionary else {}
	var after_rack := _region_slots(
		coordinator.call(
			"region_supply_public_rack",
			str(listing.get("source_region_id", ""))
		) as Dictionary
	)
	var settlement_after: Dictionary = coordinator.call(
		"district_purchase_settlement_debug"
	)
	if not bought or not bool(terminal_result.get("committed", false)):
		print(
			"HUMAN_REGION_SUPPLY_PURCHASE_CUTOVER_V06_DIAG|choice=%s|before_player=%s|terminal=%s|journal_keys=%s|logs=%s"
			% [
				JSON.stringify(choice),
				JSON.stringify(before_player),
				JSON.stringify(terminal),
				JSON.stringify(journal.keys()),
				JSON.stringify(main.get("log_lines")),
			]
		)

	_expect(
		bought
			and bool(terminal_result.get("committed", false))
			and str(terminal_result.get("operation", ""))
				== "region_supply_purchase",
		"real human entry commits through the canonical region supply transaction"
	)
	_expect(
		int(after_player.get("cash", -1))
				== int(before_player.get("cash", -1))
					- int(terminal_result.get("cash_debit", -1))
			and int(after_player.get("card_purchase_count", -1))
				== int(before_player.get("card_purchase_count", 0)) + 1,
		"cash and purchase count mutate exactly once in the production player-state owner"
	)
	_expect(
		str(CardFlowPolicyV06.new().inventory_fingerprint(
			after_player.get("inventory", {}) as Dictionary
		)) != str(CardFlowPolicyV06.new().inventory_fingerprint(before_inventory)),
		"the production inventory changes through CardFlow"
	)
	var slot_index := int(listing.get("slot_index", -1))
	_expect(
		slot_index >= 0
			and slot_index < after_rack.size()
			and str((after_rack[slot_index] as Dictionary).get("item_id", ""))
				!= str(listing.get("item_id", "")),
		"the purchased RegionSupply slot alone is refilled"
	)
	_expect(
		_other_slots_json(after_rack, slot_index) == other_slots_before,
		"unselected RegionSupply slots remain unchanged"
	)
	_expect(
		int(settlement_after.get("committed_count", -1))
			== int(settlement_before.get("committed_count", -1)),
		"legacy DistrictPurchaseSettlement commits stay unused"
	)
	var public_text := JSON.stringify(terminal_result.get("public_receipt", {}))
	_expect(
		not public_text.contains(actor_id)
			and not public_text.contains(str(listing.get("card_id", "")))
			and not public_text.contains("price_cash")
			and not public_text.contains("quote_fingerprint"),
		"the committed public receipt keeps buyer, card, price and quote private"
	)

	var cash_after := int(after_player.get("cash", -1))
	var purchase_count_after := int(after_player.get("card_purchase_count", -1))
	var replayed := bool(main.call(
		"_buy_card_for_player_from_district",
		0,
		district_index,
		str(listing.get("card_id", "")),
		true,
		true,
		-1,
		""
	))
	var final_player: Dictionary = coordinator.call(
		"v06_card_player_snapshot",
		actor_id
	)
	_expect(
		not replayed
			and int(final_player.get("cash", -2)) == cash_after
			and int(final_player.get("card_purchase_count", -2))
				== purchase_count_after,
		"a consumed listing cannot be charged or received twice through main"
	)

	main.queue_free()
	await process_frame


func _find_purchasable_listing(main: Node, coordinator: Node) -> Dictionary:
	var players: Array = main.get("players") if main.get("players") is Array else []
	if players.is_empty() or not (players[0] is Dictionary):
		return {}
	var actor_id := str((players[0] as Dictionary).get("actor_id", "player.0"))
	var districts: Array = main.get("districts") if main.get("districts") is Array else []
	for district_index in range(districts.size()):
		var availability: Dictionary = coordinator.call(
			"card_market_listing_availability",
			district_index
		)
		if not bool(availability.get("purchasable", false)):
			continue
		var region_id := str(
			(districts[district_index] as Dictionary).get(
				"region_id",
				"region.%03d" % district_index
			)
		)
		var rack: Dictionary = coordinator.call(
			"region_supply_public_rack",
			region_id
		)
		for listing_variant in _region_slots(rack):
			if not (listing_variant is Dictionary):
				continue
			var listing: Dictionary = listing_variant
			var card_id := str(listing.get("card_id", ""))
			var preview: Dictionary = main.call(
				"_card_market_preview",
				card_id,
				district_index
			)
			if bool(preview.get("purchasable", preview.get("eligible", false))) \
					and int(preview.get("final_price", -1)) \
						<= int((players[0] as Dictionary).get("cash", 0)):
				return {
					"actor_id": actor_id,
					"district_index": district_index,
					"listing": listing.duplicate(true),
				}
	return {}


func _new_region_purchase_terminal(
	before: Dictionary,
	after: Dictionary,
	card_id: String
) -> Dictionary:
	var transaction_ids: Array = after.keys()
	transaction_ids.sort()
	for transaction_id_variant in transaction_ids:
		var transaction_id := str(transaction_id_variant)
		if before.has(transaction_id):
			continue
		var terminal: Dictionary = after.get(transaction_id_variant, {}) \
			if after.get(transaction_id_variant, {}) is Dictionary else {}
		var result: Dictionary = terminal.get("result", {}) \
			if terminal.get("result", {}) is Dictionary else {}
		if str(result.get("operation", "")) == "region_supply_purchase" \
				and str(result.get("card_id", "")) == card_id:
			return terminal.duplicate(true)
	return {}


func _region_slots(snapshot: Dictionary) -> Array:
	var regions: Array = snapshot.get("regions", []) \
		if snapshot.get("regions", []) is Array else []
	if regions.is_empty() or not (regions[0] is Dictionary):
		return []
	return ((regions[0] as Dictionary).get("slots", []) as Array).duplicate(true) \
		if (regions[0] as Dictionary).get("slots", []) is Array else []


func _active_supply_card_ids(snapshot: Dictionary) -> Array:
	var result: Array = []
	var regions: Array = snapshot.get("regions", []) \
		if snapshot.get("regions", []) is Array else []
	for region_variant in regions:
		if not (region_variant is Dictionary):
			continue
		var slots: Array = (region_variant as Dictionary).get("slots", []) \
			if (region_variant as Dictionary).get("slots", []) is Array else []
		for listing_variant in slots:
			if not (listing_variant is Dictionary):
				continue
			var card_id := str((listing_variant as Dictionary).get("card_id", ""))
			if not card_id.is_empty():
				result.append(card_id)
	return result


func _is_stable_v06_id(card_id: String) -> bool:
	if card_id.is_empty():
		return false
	var allowed := "abcdefghijklmnopqrstuvwxyz0123456789._-"
	for index in range(card_id.length()):
		if not allowed.contains(card_id.substr(index, 1)):
			return false
	return true


func _other_slots_json(slots: Array, excluded_slot: int) -> String:
	var rows: Array = []
	for slot_index in range(slots.size()):
		if slot_index == excluded_slot:
			continue
		rows.append((slots[slot_index] as Dictionary).duplicate(true) if slots[slot_index] is Dictionary else {})
	return JSON.stringify(rows)


func _function_source(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start < 0:
		return ""
	var finish := source.find("\nfunc ", start + 5)
	if finish < 0:
		finish = source.length()
	return source.substr(start, finish - start)


func _wait_frames(count: int) -> void:
	for _index in range(maxi(1, count)):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	print("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print(
			"HUMAN_REGION_SUPPLY_PURCHASE_CUTOVER_V06_TEST|status=PASS|checks=%d|failures=0"
			% _checks
		)
		quit(0)
		return
	print(
		"HUMAN_REGION_SUPPLY_PURCHASE_CUTOVER_V06_TEST|status=FAIL|checks=%d|failures=%d|details=%s"
		% [_checks, _failures.size(), JSON.stringify(_failures)]
	)
	quit(1)
