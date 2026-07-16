extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"
const QA_SAVE_PATH := "user://test_runs/vs06_production_dispatch_replay.save"

var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(MAIN_SCENE) as PackedScene
	_expect(packed != null, "main scene loads")
	if packed == null:
		_finish()
		return
	var main := packed.instantiate()
	var save := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController/GameSaveRuntimeCoordinator")
	_expect(save != null and save.has_method("set_qa_default_save_path_override"), "QA save override is available before main enters the tree")
	if save == null or not save.has_method("set_qa_default_save_path_override"):
		main.free()
		_finish()
		return
	_expect(bool(save.call("set_qa_default_save_path_override", QA_SAVE_PATH)), "QA save path is isolated")
	root.add_child(main)
	await _wait_frames(8)

	main.set("configured_player_count", 3)
	main.set("configured_ai_player_count", 2)
	main.set("configured_roguelike_depth", 1)
	main.set("configured_role_indices", [0, 1, 2])
	main.set("configured_starter_monster_indices", [0, 1, 2])
	main.call("_open_new_game_setup_menu")
	await _wait_frames(2)
	main.call("_on_new_game_setup_action_requested", "setup_start")
	await _wait_frames(10)

	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	_expect(coordinator != null and coordinator.has_method("play_v06_runtime_card"), "production Coordinator exposes the v0.6 dispatch")
	if coordinator == null:
		main.queue_free()
		await process_frame
		_finish()
		return
	var inventory: Object = coordinator.call("commodity_card_inventory_runtime_controller")
	var monster: Object = coordinator.call("monster_runtime_controller")
	var infrastructure: Object = coordinator.call("region_infrastructure_runtime_controller")
	_expect(inventory != null and monster != null and infrastructure != null, "production card, monster, and infrastructure owners are composed")

	await _check_monster_dispatch(main, coordinator, inventory, monster)
	await _check_facility_dispatch(main, coordinator, inventory, infrastructure)

	main.queue_free()
	await process_frame
	_finish()


func _check_monster_dispatch(main: Node, coordinator: Node, inventory: Object, monster: Object) -> void:
	var players: Array = main.get("players") if main.get("players") is Array else []
	_expect(players.size() == 3, "three production seats exist")
	if players.is_empty():
		return
	var district := _first_playable_district(main)
	_expect(district >= 0, "starter district exists")
	if district < 0:
		return
	main.call("_select_district", district)
	var player: Dictionary = players[0] if players[0] is Dictionary else {}
	var slot_index := int(main.call("_first_starter_monster_slot", player))
	_expect(slot_index >= 0, "human starter card exists")
	if slot_index < 0:
		return
	var card := _card_at(player, slot_index)
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	var actor_id := _actor_id(player, 0)
	var canonical := coordinator.call("v06_card_definition", str(machine.get("card_id", ""))) as Dictionary
	var canonical_machine: Dictionary = canonical.get("machine", {}) if canonical.get("machine", {}) is Dictionary else {}
	var production_player := coordinator.call("v06_card_player_snapshot", actor_id) as Dictionary
	var production_card := _production_card_at(production_player, slot_index)
	var production_machine: Dictionary = production_card.get("machine", {}) if production_card.get("machine", {}) is Dictionary else {}
	_expect(_asset_total(canonical_machine.get("asset_cost", {})) == 2, "ordinary canonical rank-I monster keeps its two-asset cost")
	_expect(bool(machine.get("starter_entitlement", false)) and _asset_total(machine.get("asset_cost", {})) == 0, "main creates an explicit free starter entitlement instance")
	_expect(bool(production_machine.get("starter_entitlement", false)) and _asset_total(production_machine.get("asset_cost", {})) == 0, "ProductionAdapter and Inventory accept only the authoritative starter instance override")
	var instance_id := str(production_card.get("runtime_instance_id", "slot:%d" % slot_index))
	var transaction_id := "v06-play:%s:%s" % [actor_id, instance_id]
	var region_id := _selected_region_id(main, district)
	var request := {
		"actor_id": actor_id,
		"slot_index": slot_index,
		"transaction_id": transaction_id,
		"region_id": region_id,
		"game_time": float(main.get("game_time")),
	}
	var before_owner := monster.call("unit_card_snapshot_v06", "monster") as Dictionary
	var before_terminal := _monster_terminal_journal(monster)
	var submitted := bool(main.call("_queue_skill_resolution", 0, slot_index, -1))
	await _wait_frames(2)
	var terminal_result := _inventory_transaction_result(inventory, transaction_id)
	var first_reason := str(terminal_result.get("reason_code", "no_inventory_terminal"))
	print("VS06_DISPATCH_DIAGNOSTIC|route=monster|reason=%s|submitted=%s" % [first_reason, submitted])
	var after_owner := monster.call("unit_card_snapshot_v06", "monster") as Dictionary
	var after_terminal := _monster_terminal_journal(monster)
	var new_terminal_ids := _new_keys(before_terminal, after_terminal)
	var finalized_count := 0
	for terminal_id in new_terminal_ids:
		var row: Dictionary = after_terminal.get(terminal_id, {}) if after_terminal.get(terminal_id, {}) is Dictionary else {}
		var receipt: Dictionary = row.get("receipt", {}) if row.get("receipt", {}) is Dictionary else {}
		if str(row.get("stage", "")) == "finalized" and bool(receipt.get("finalized", false)):
			finalized_count += 1
	_expect(submitted and bool(terminal_result.get("committed", false)), "human starter commits through main queue and Coordinator: %s" % first_reason)
	_expect(int(after_owner.get("monster_count", -1)) == int(before_owner.get("monster_count", -1)) + 1, "human starter adds exactly one monster")
	_expect(new_terminal_ids.size() == 1 and finalized_count == 1, "human starter creates exactly one finalized Monster terminal")

	var player_after := coordinator.call("v06_card_player_snapshot", actor_id) as Dictionary
	var owner_after := (after_owner as Dictionary).duplicate(true)
	var replay: Dictionary = coordinator.call("play_v06_runtime_card", request)
	var player_replay := coordinator.call("v06_card_player_snapshot", actor_id) as Dictionary
	var owner_replay := monster.call("unit_card_snapshot_v06", "monster") as Dictionary
	_expect(bool(replay.get("committed", false)) and bool(replay.get("idempotent_replay", false)), "consumed monster card replays from the authoritative transaction journal")
	_expect(_same_data(player_after, player_replay) and _same_data(owner_after, owner_replay), "monster replay does not mutate player or roster state")
	_expect(str(replay.get("card_id", "")) == str(machine.get("card_id", "")), "monster replay preserves the authoritative card binding")

	var wrong_actor := request.duplicate(true)
	wrong_actor["actor_id"] = _actor_id(players[1] as Dictionary, 1)
	var wrong_slot := request.duplicate(true)
	wrong_slot["slot_index"] = slot_index + 1
	var wrong_target := request.duplicate(true)
	wrong_target["region_id"] = _different_region_id(main, region_id)
	var new_transaction := request.duplicate(true)
	new_transaction["transaction_id"] = "%s:fresh" % transaction_id
	_expect(not bool((coordinator.call("play_v06_runtime_card", wrong_actor) as Dictionary).get("committed", false)), "another actor cannot replay the monster transaction")
	_expect(not bool((coordinator.call("play_v06_runtime_card", wrong_slot) as Dictionary).get("committed", false)), "another slot cannot replay the monster transaction")
	_expect(not bool((coordinator.call("play_v06_runtime_card", wrong_target) as Dictionary).get("committed", false)), "another target cannot replay the monster transaction")
	_expect(not bool((coordinator.call("play_v06_runtime_card", new_transaction) as Dictionary).get("committed", false)), "a new transaction cannot replay a consumed monster card")


func _check_facility_dispatch(main: Node, coordinator: Node, inventory: Object, infrastructure: Object) -> void:
	var players: Array = main.get("players") if main.get("players") is Array else []
	if players.is_empty():
		return
	var actor_id := _actor_id(players[0] as Dictionary, 0)
	var surface := coordinator.call("v06_facility_market_snapshot", actor_id) as Dictionary
	var listing: Dictionary = surface.get("listing", {}) if surface.get("listing", {}) is Dictionary else {}
	var source_item_id := str(listing.get("item_id", ""))
	var purchase_id := "vs06-a5:facility-purchase:%s" % actor_id
	var purchase := coordinator.call("purchase_v06_facility_card", actor_id, source_item_id, purchase_id) as Dictionary
	_expect(bool(purchase.get("committed", false)), "canonical facility purchase commits")
	if not bool(purchase.get("committed", false)):
		return
	var card_id := str(purchase.get("card_id", ""))
	var player := coordinator.call("v06_card_player_snapshot", actor_id) as Dictionary
	var slot_index := _find_card_slot(player, card_id)
	var district := int(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district)
	var region_id := _selected_region_id(main, district)
	var transaction_id := "vs06-a5:facility-play:%s" % actor_id
	var request := {
		"actor_id": actor_id,
		"slot_index": slot_index,
		"transaction_id": transaction_id,
		"region_id": region_id,
		"game_time": float(main.get("game_time")),
	}
	var before_facilities: Array = infrastructure.call("facilities_snapshot", false)
	var play := coordinator.call("play_v06_runtime_card", request) as Dictionary
	var after_player := coordinator.call("v06_card_player_snapshot", actor_id) as Dictionary
	var after_facilities: Array = infrastructure.call("facilities_snapshot", false)
	_expect(bool(play.get("committed", false)) and bool((play.get("effect_finalization", {}) as Dictionary).get("finalized", false)), "facility play commits and finalizes")
	_expect(after_facilities.size() == before_facilities.size() + 1, "facility play builds exactly one facility")

	var replay := coordinator.call("play_v06_runtime_card", request) as Dictionary
	var replay_player := coordinator.call("v06_card_player_snapshot", actor_id) as Dictionary
	var replay_facilities: Array = infrastructure.call("facilities_snapshot", false)
	print("VS06_DISPATCH_DIAGNOSTIC|route=facility_replay|reason=%s" % str(replay.get("reason_code", "missing")))
	_expect(bool(replay.get("committed", false)) and bool(replay.get("idempotent_replay", false)), "consumed facility card replays from the authoritative transaction journal")
	_expect(_same_data(after_player, replay_player) and _same_data(after_facilities, replay_facilities), "facility replay does not mutate player or infrastructure state")

	var wrong_slot := request.duplicate(true)
	wrong_slot["slot_index"] = slot_index + 1
	var wrong_target := request.duplicate(true)
	wrong_target["region_id"] = _different_region_id(main, region_id)
	var wrong_actor := request.duplicate(true)
	wrong_actor["actor_id"] = _actor_id(players[1] as Dictionary, 1)
	_expect(not bool((coordinator.call("play_v06_runtime_card", wrong_slot) as Dictionary).get("committed", false)), "another slot cannot replay the facility transaction")
	_expect(not bool((coordinator.call("play_v06_runtime_card", wrong_target) as Dictionary).get("committed", false)), "another target cannot replay the facility transaction")
	_expect(not bool((coordinator.call("play_v06_runtime_card", wrong_actor) as Dictionary).get("committed", false)), "another actor cannot replay the facility transaction")
	_expect(bool(_inventory_transaction_result(inventory, transaction_id).get("committed", false)), "facility terminal remains owned by the Inventory/CardFlow journal")


func _card_at(player: Dictionary, slot_index: int) -> Dictionary:
	var slots: Array = player.get("slots", []) if player.get("slots", []) is Array else []
	if slot_index < 0 or slot_index >= slots.size() or not (slots[slot_index] is Dictionary):
		return {}
	return (slots[slot_index] as Dictionary).duplicate(true)


func _find_card_slot(player: Dictionary, card_id: String) -> int:
	var inventory: Dictionary = player.get("inventory", {}) if player.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	for slot_index in range(slots.size()):
		if not (slots[slot_index] is Dictionary):
			continue
		var machine: Dictionary = (slots[slot_index] as Dictionary).get("machine", {}) if (slots[slot_index] as Dictionary).get("machine", {}) is Dictionary else {}
		if str(machine.get("card_id", "")) == card_id:
			return slot_index
	return -1


func _production_card_at(player: Dictionary, slot_index: int) -> Dictionary:
	var inventory: Dictionary = player.get("inventory", {}) if player.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	if slot_index < 0 or slot_index >= slots.size() or not (slots[slot_index] is Dictionary):
		return {}
	return (slots[slot_index] as Dictionary).duplicate(true)


func _asset_total(value: Variant) -> int:
	if not (value is Dictionary):
		return -1
	var total := 0
	for amount_variant in (value as Dictionary).values():
		total += int(amount_variant)
	return total


func _inventory_transaction_result(inventory: Object, transaction_id: String) -> Dictionary:
	if inventory == null or not inventory.has_method("transaction_journal_snapshot"):
		return {}
	var journal := inventory.call("transaction_journal_snapshot") as Dictionary
	var row: Dictionary = journal.get(transaction_id, {}) if journal.get(transaction_id, {}) is Dictionary else {}
	return (row.get("result", {}) as Dictionary).duplicate(true) if row.get("result", {}) is Dictionary else {}


func _monster_terminal_journal(monster: Object) -> Dictionary:
	if monster == null or not monster.has_method("to_save_data"):
		return {}
	var data := monster.call("to_save_data") as Dictionary
	return (data.get("monster_card_atomic_terminal_journal", {}) as Dictionary).duplicate(true) if data.get("monster_card_atomic_terminal_journal", {}) is Dictionary else {}


func _new_keys(before: Dictionary, after: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key_variant in after.keys():
		var key := str(key_variant)
		if not before.has(key):
			result.append(key)
	result.sort()
	return result


func _actor_id(player: Dictionary, fallback_index: int) -> String:
	return str(player.get("actor_id", "player.%d" % fallback_index))


func _selected_region_id(main: Node, district: int) -> String:
	var districts: Array = main.get("districts") if main.get("districts") is Array else []
	if district < 0 or district >= districts.size() or not (districts[district] is Dictionary):
		return ""
	return str((districts[district] as Dictionary).get("region_id", "region.%03d" % district))


func _first_playable_district(main: Node) -> int:
	var districts: Array = main.get("districts") if main.get("districts") is Array else []
	for index in range(districts.size()):
		var district_data: Dictionary = districts[index] if districts[index] is Dictionary else {}
		if not bool(district_data.get("is_ocean", false)) and not str(district_data.get("region_id", "")).is_empty():
			return index
	return -1


func _different_region_id(main: Node, current_region_id: String) -> String:
	var districts: Array = main.get("districts") if main.get("districts") is Array else []
	for district_variant in districts:
		if not (district_variant is Dictionary):
			continue
		var candidate := str((district_variant as Dictionary).get("region_id", ""))
		if not candidate.is_empty() and candidate != current_region_id:
			return candidate
	return "%s:other" % current_region_id


func _same_data(first: Variant, second: Variant) -> bool:
	return JSON.stringify(first) == JSON.stringify(second)


func _wait_frames(count: int) -> void:
	for _index in range(maxi(0, count)):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	print("VS06_PRODUCTION_DISPATCH_REPLAY_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(_failures.size())
