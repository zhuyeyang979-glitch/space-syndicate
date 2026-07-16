extends SceneTree

var _checks := 0
var _failures: Array[String] = []


class RegionSupplyPolicyFixture:
	extends RefCounted

	const SCHEMA_REVISION := 1
	const MODULUS := 2147483647
	const MULTIPLIER := 48271
	const REGION_IDS := ["region.alpha", "region.beta", "region.gamma"]
	const SLOT_IDS := ["slot.0", "slot.1", "slot.2", "slot.3"]
	const UI_EVENTS := ["open", "close", "hover", "scroll", "reopen"]

	var _cards: Array = []
	var _state: Dictionary = {}


	func _init(gameplay_seed: int, _player_context: Dictionary = {}) -> void:
		_cards = _card_definitions()
		_state = {
			"region_supply_schema_revision": SCHEMA_REVISION,
			"gameplay_seed": gameplay_seed,
			"public_revision": 0,
			"regions": {},
			"global_unique_card_states": {},
			"applied_transactions": {},
		}
		var unique_states: Dictionary = {}
		for card_variant in _cards:
			var card: Dictionary = card_variant
			if str(card.get("unique_scope", "none")) == "global":
				unique_states[str(card.get("card_id", ""))] = {"state": "available"}
		_state["global_unique_card_states"] = unique_states
		var regions: Dictionary = {}
		for region_id_variant in REGION_IDS:
			var region_id := str(region_id_variant)
			var shuffled := _shuffled_card_ids(gameplay_seed, region_id, 0)
			var slots: Array = []
			for slot_id_variant in SLOT_IDS:
				slots.append({"slot_id": str(slot_id_variant), "card_id": ""})
			regions[region_id] = {
				"region_id": region_id,
				"slots": slots,
				"bag_order": shuffled.get("order", []),
				"bag_cursor": 0,
				"bag_epoch": 0,
				"rng_state": int(shuffled.get("rng_state", 0)),
				"refresh_sequence": 0,
			}
		_state["regions"] = regions
		for region_id_variant in REGION_IDS:
			var region_id := str(region_id_variant)
			for slot_id_variant in SLOT_IDS:
				var slot_id := str(slot_id_variant)
				_set_slot_card(region_id, slot_id, _draw_next(region_id, slot_id))
		_state["public_revision"] = 1


	func public_snapshot() -> Dictionary:
		var public_regions: Array = []
		var regions: Dictionary = _state.get("regions", {})
		for region_id_variant in REGION_IDS:
			var region_id := str(region_id_variant)
			var region: Dictionary = regions.get(region_id, {})
			var public_slots: Array = []
			for slot_variant in region.get("slots", []):
				var slot: Dictionary = slot_variant
				var card_id := str(slot.get("card_id", ""))
				var definition := _card_definition(card_id)
				public_slots.append({
					"slot_id": str(slot.get("slot_id", "")),
					"card_id": card_id,
					"family_id": str(definition.get("family_id", "")),
					"display_name": str(definition.get("display_name", card_id)),
					"purchase_condition": str(definition.get("purchase_condition", "")),
				})
			public_regions.append({
				"region_id": region_id,
				"refresh_sequence": int(region.get("refresh_sequence", 0)),
				"slots": public_slots,
			})
		return {
			"visibility_scope": "public",
			"public_snapshot": true,
			"public_revision": int(_state.get("public_revision", 0)),
			"regions": public_regions,
		}


	func state_snapshot() -> Dictionary:
		return _state.duplicate(true)


	func restore(snapshot: Dictionary) -> bool:
		if int(snapshot.get("region_supply_schema_revision", -1)) != SCHEMA_REVISION:
			return false
		if not (snapshot.get("regions", null) is Dictionary):
			return false
		_state = snapshot.duplicate(true)
		return true


	func purchase_and_refill(region_id: String, slot_id: String, transaction_id: String) -> Dictionary:
		var applied_transactions: Dictionary = _state.get("applied_transactions", {})
		if applied_transactions.has(transaction_id):
			var duplicate_result: Dictionary = applied_transactions[transaction_id].duplicate(true)
			duplicate_result["applied"] = false
			duplicate_result["duplicate"] = true
			return duplicate_result
		var regions: Dictionary = _state.get("regions", {})
		if not regions.has(region_id):
			return {"applied": false, "duplicate": false, "reason_code": "region_missing"}
		var region: Dictionary = regions[region_id]
		var slots: Array = region.get("slots", [])
		var slot_index := -1
		var purchased_card_id := ""
		for index in range(slots.size()):
			var slot: Dictionary = slots[index]
			if str(slot.get("slot_id", "")) == slot_id:
				slot_index = index
				purchased_card_id = str(slot.get("card_id", ""))
				break
		if slot_index < 0 or purchased_card_id.is_empty():
			return {"applied": false, "duplicate": false, "reason_code": "listing_missing"}
		if str(_card_definition(purchased_card_id).get("unique_scope", "none")) == "global":
			var unique_states: Dictionary = _state.get("global_unique_card_states", {})
			unique_states[purchased_card_id] = {"state": "purchased", "transaction_id": transaction_id}
			_state["global_unique_card_states"] = unique_states
		var replacement_card_id := _draw_next(region_id, slot_id)
		regions = _state.get("regions", {})
		region = regions[region_id]
		slots = region.get("slots", [])
		var replacement_slot: Dictionary = slots[slot_index]
		replacement_slot["card_id"] = replacement_card_id
		slots[slot_index] = replacement_slot
		region["slots"] = slots
		region["refresh_sequence"] = int(region.get("refresh_sequence", 0)) + 1
		regions[region_id] = region
		_state["regions"] = regions
		_state["public_revision"] = int(_state.get("public_revision", 0)) + 1
		var result := {
			"applied": true,
			"duplicate": false,
			"transaction_id": transaction_id,
			"region_id": region_id,
			"slot_id": slot_id,
			"purchased_card_id": purchased_card_id,
			"replacement_card_id": replacement_card_id,
			"refresh_sequence": int(region.get("refresh_sequence", 0)),
			"public_revision": int(_state.get("public_revision", 0)),
		}
		applied_transactions = _state.get("applied_transactions", {})
		applied_transactions[transaction_id] = result.duplicate(true)
		_state["applied_transactions"] = applied_transactions
		return result


	func apply_ui_event(event_id: String) -> Dictionary:
		return {
			"handled": UI_EVENTS.has(event_id),
			"event_id": event_id,
			"public_snapshot": public_snapshot(),
		}


	func _draw_next(region_id: String, slot_id: String) -> String:
		for _attempt in range(128):
			var regions: Dictionary = _state.get("regions", {})
			var region: Dictionary = regions.get(region_id, {})
			var order: Array = region.get("bag_order", [])
			var cursor := int(region.get("bag_cursor", 0))
			if cursor >= order.size():
				var epoch := int(region.get("bag_epoch", 0)) + 1
				var shuffled := _shuffled_card_ids(int(_state.get("gameplay_seed", 0)), region_id, epoch)
				order = shuffled.get("order", [])
				cursor = 0
				region["bag_order"] = order
				region["bag_cursor"] = cursor
				region["bag_epoch"] = epoch
				region["rng_state"] = int(shuffled.get("rng_state", 0))
			if order.is_empty():
				return ""
			var card_id := str(order[cursor])
			region["bag_cursor"] = cursor + 1
			regions[region_id] = region
			_state["regions"] = regions
			if str(_card_definition(card_id).get("unique_scope", "none")) != "global":
				return card_id
			var unique_states: Dictionary = _state.get("global_unique_card_states", {})
			var unique_state: Dictionary = unique_states.get(card_id, {"state": "available"})
			if str(unique_state.get("state", "available")) != "available":
				continue
			unique_states[card_id] = {
				"state": "listed",
				"region_id": region_id,
				"slot_id": slot_id,
			}
			_state["global_unique_card_states"] = unique_states
			return card_id
		return ""


	func _set_slot_card(region_id: String, slot_id: String, card_id: String) -> void:
		var regions: Dictionary = _state.get("regions", {})
		var region: Dictionary = regions.get(region_id, {})
		var slots: Array = region.get("slots", [])
		for index in range(slots.size()):
			var slot: Dictionary = slots[index]
			if str(slot.get("slot_id", "")) != slot_id:
				continue
			slot["card_id"] = card_id
			slots[index] = slot
			break
		region["slots"] = slots
		regions[region_id] = region
		_state["regions"] = regions


	func _shuffled_card_ids(gameplay_seed: int, region_id: String, epoch: int) -> Dictionary:
		var ids: Array[String] = []
		for card_variant in _cards:
			ids.append(str((card_variant as Dictionary).get("card_id", "")))
		ids.sort()
		var rng_state := _stable_seed("%d|region_supply_v06|%s|%d" % [gameplay_seed, region_id, epoch])
		for index in range(ids.size() - 1, 0, -1):
			rng_state = int((rng_state * MULTIPLIER) % MODULUS)
			var swap_index := rng_state % (index + 1)
			var held := ids[index]
			ids[index] = ids[swap_index]
			ids[swap_index] = held
		return {"order": ids, "rng_state": rng_state}


	func _stable_seed(text: String) -> int:
		var value := 216613626
		for index in range(text.length()):
			value = int((value * 16777619 + text.unicode_at(index)) % MODULUS)
		return maxi(1, value)


	func _card_definition(card_id: String) -> Dictionary:
		for card_variant in _cards:
			var card: Dictionary = card_variant
			if str(card.get("card_id", "")) == card_id:
				return card
		return {}


	func _card_definitions() -> Array:
		return [
			_card("card.counter.signal", "counter", "信号反制"),
			_card("card.development.city", "development", "城市发展"),
			_card("card.facility.factory", "factory", "通用工厂"),
			_card("card.facility.market", "market", "公共市场"),
			_card("card.military.patrol", "military", "巡逻军"),
			_card("card.monster.echo", "monster", "回声怪兽"),
			_card("card.organization.guild", "organization", "行会组织"),
			_card("card.route.airport", "airport", "空港"),
			_card("card.route.port", "port", "码头"),
			_card("card.route.road", "road", "道路"),
			_card("card.strategy.trade", "strategy", "贸易策略"),
			_card("card.unique.relic", "relic", "唯一遗物", "global"),
			_card("card.warehouse.cold", "warehouse", "冷藏仓库"),
		]


	func _card(card_id: String, family_id: String, display_name: String, unique_scope := "none") -> Dictionary:
		return {
			"card_id": card_id,
			"family_id": family_id,
			"display_name": display_name,
			"region_supply_weight": 1,
			"unique_scope": unique_scope,
			"purchase_condition": "公开购买条件；当前资源不足时仍可挂牌",
		}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_same_seed_replay()
	_check_seed_variation_and_category_order()
	_check_unified_slot_pool()
	_check_single_slot_refill_and_no_category_phase()
	_check_ui_and_player_context_isolation()
	_check_save_roundtrip_and_exact_once()
	_check_unique_card_and_public_privacy()
	print("REGION_SUPPLY_POLICY_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	quit(_failures.size())


func _check_same_seed_replay() -> void:
	var left := RegionSupplyPolicyFixture.new(7301)
	var right := RegionSupplyPolicyFixture.new(7301)
	_expect(left.public_snapshot() == right.public_snapshot(), "same seed produces the same normalized initial region racks")
	for step in range(3):
		var transaction_id := "tx.replay.%d" % step
		var slot_id := "slot.%d" % step
		var left_result := left.purchase_and_refill("region.alpha", slot_id, transaction_id)
		var right_result := right.purchase_and_refill("region.alpha", slot_id, transaction_id)
		_expect(left_result == right_result and left.public_snapshot() == right.public_snapshot(), "same seed and purchase sequence replay refill %d exactly" % (step + 1))


func _check_seed_variation_and_category_order() -> void:
	var baseline := RegionSupplyPolicyFixture.new(7301).public_snapshot()
	var different_seed_found := false
	for seed in range(7302, 7360):
		if RegionSupplyPolicyFixture.new(seed).public_snapshot() != baseline:
			different_seed_found = true
			break
	_expect(different_seed_found, "different gameplay seeds produce an auditable different rack sequence")
	var market_first_seed := -1
	var factory_first_seed := -1
	for seed in range(1, 512):
		var region := _public_region(RegionSupplyPolicyFixture.new(seed).public_snapshot(), "region.alpha")
		var order: Array[String] = []
		for slot_variant in region.get("slots", []):
			order.append(str((slot_variant as Dictionary).get("card_id", "")))
		var market_index := order.find("card.facility.market")
		var factory_index := order.find("card.facility.factory")
		if market_index >= 0 and factory_index >= 0:
			if market_index < factory_index and market_first_seed < 0:
				market_first_seed = seed
			if factory_index < market_index and factory_first_seed < 0:
				factory_first_seed = seed
		if market_first_seed >= 0 and factory_first_seed >= 0:
			break
	_expect(market_first_seed >= 0, "a deterministic seed allows market before factory")
	_expect(factory_first_seed >= 0, "a deterministic seed allows factory before market")


func _check_unified_slot_pool() -> void:
	var families_by_slot: Array = [{}, {}, {}, {}]
	for seed in range(1, 97):
		var region := _public_region(RegionSupplyPolicyFixture.new(seed).public_snapshot(), "region.alpha")
		var slots: Array = region.get("slots", [])
		for slot_index in range(mini(slots.size(), families_by_slot.size())):
			var family_id := str((slots[slot_index] as Dictionary).get("family_id", ""))
			(families_by_slot[slot_index] as Dictionary)[family_id] = true
	for slot_index in range(families_by_slot.size()):
		_expect((families_by_slot[slot_index] as Dictionary).size() >= 3, "slot %d is occupied by multiple unified-pool families across seeds" % slot_index)
	var private_state := RegionSupplyPolicyFixture.new(44).state_snapshot()
	for retired_key in [
		"city_development_guarantee_card",
		"monster_guarantee_card",
		"factory_guarantee_slot",
		"market_unlock_phase",
		"next_category",
	]:
		_expect(not _variant_has_key(private_state, retired_key), "policy fixture has no retired %s branch" % retired_key)


func _check_single_slot_refill_and_no_category_phase() -> void:
	var seed := 901
	var left := RegionSupplyPolicyFixture.new(seed)
	var right := RegionSupplyPolicyFixture.new(seed)
	var slots := (_public_region(left.public_snapshot(), "region.alpha").get("slots", []) as Array)
	var left_slot_id := str((slots[0] as Dictionary).get("slot_id", ""))
	var right_slot_id := str((slots[1] as Dictionary).get("slot_id", ""))
	var left_family := str((slots[0] as Dictionary).get("family_id", ""))
	var right_family := str((slots[1] as Dictionary).get("family_id", ""))
	var left_result := left.purchase_and_refill("region.alpha", left_slot_id, "tx.no_phase")
	var right_result := right.purchase_and_refill("region.alpha", right_slot_id, "tx.no_phase")
	_expect(left_family != right_family, "no-category-phase fixture removes two different previous families")
	_expect(str(left_result.get("replacement_card_id", "")) == str(right_result.get("replacement_card_id", "")), "next draw depends on bag state rather than the removed card category")
	var single := RegionSupplyPolicyFixture.new(1701)
	var before_snapshot := single.public_snapshot()
	var before_region := _public_region(before_snapshot, "region.beta")
	var before_slots: Array = before_region.get("slots", [])
	var target_slot_id := str((before_slots[2] as Dictionary).get("slot_id", ""))
	var result := single.purchase_and_refill("region.beta", target_slot_id, "tx.single_slot")
	var after_snapshot := single.public_snapshot()
	var after_region := _public_region(after_snapshot, "region.beta")
	var after_slots: Array = after_region.get("slots", [])
	var changed_slots := 0
	for index in range(before_slots.size()):
		if str((before_slots[index] as Dictionary).get("card_id", "")) != str((after_slots[index] as Dictionary).get("card_id", "")):
			changed_slots += 1
	_expect(bool(result.get("applied", false)) and changed_slots == 1, "purchase refills only the purchased slot")
	_expect(int(after_region.get("refresh_sequence", 0)) == int(before_region.get("refresh_sequence", 0)) + 1 and int(after_snapshot.get("public_revision", 0)) == int(before_snapshot.get("public_revision", 0)) + 1, "single-slot refill advances only its region sequence and the public revision")


func _check_ui_and_player_context_isolation() -> void:
	var fixture := RegionSupplyPolicyFixture.new(2222)
	var before := fixture.state_snapshot()
	for event_id in ["open", "close", "hover", "scroll", "reopen"]:
		var result := fixture.apply_ui_event(event_id)
		_expect(bool(result.get("handled", false)), "UI event %s is recognized as presentation-only" % event_id)
	_expect(fixture.state_snapshot() == before, "open/close/hover/scroll/reopen do not advance rack, bag, RNG, or revision")
	var poor := RegionSupplyPolicyFixture.new(3333, {"cash": 0, "facilities": [], "hand": []})
	var rich := RegionSupplyPolicyFixture.new(3333, {"cash": 999999, "facilities": ["factory"], "hand": ["card"]})
	_expect(poor.public_snapshot() == rich.public_snapshot(), "current cash, assets, and hand do not filter the legal listing pool")


func _check_save_roundtrip_and_exact_once() -> void:
	var control := RegionSupplyPolicyFixture.new(4444)
	control.purchase_and_refill("region.alpha", "slot.0", "tx.before_save")
	var saved := control.state_snapshot()
	var restored := RegionSupplyPolicyFixture.new(1)
	_expect(restored.restore(saved), "versioned region supply fixture state restores")
	_expect(restored.state_snapshot() == saved and restored.public_snapshot() == control.public_snapshot(), "save/load preserves slots, bag cursor, unique state, sequences, and revision")
	var control_result := control.purchase_and_refill("region.alpha", "slot.1", "tx.after_save")
	var restored_result := restored.purchase_and_refill("region.alpha", "slot.1", "tx.after_save")
	_expect(control_result == restored_result and restored.state_snapshot() == control.state_snapshot(), "the next refill after load matches the uninterrupted control")
	var before_duplicate := restored.state_snapshot()
	var duplicate_result := restored.purchase_and_refill("region.alpha", "slot.1", "tx.after_save")
	_expect(bool(duplicate_result.get("duplicate", false)) and not bool(duplicate_result.get("applied", true)) and restored.state_snapshot() == before_duplicate, "reapplying a transaction does not purchase or refill twice")


func _check_unique_card_and_public_privacy() -> void:
	var saw_unique_listing := false
	var never_duplicated := true
	var public_snapshot: Dictionary = {}
	for seed in range(1, 256):
		var fixture := RegionSupplyPolicyFixture.new(seed)
		var snapshot := fixture.public_snapshot()
		var unique_count := _public_card_count(snapshot, "card.unique.relic")
		never_duplicated = never_duplicated and unique_count <= 1
		if unique_count == 1:
			saw_unique_listing = true
			public_snapshot = snapshot
			break
	_expect(saw_unique_listing and never_duplicated, "a global unique card may list once but never in two regions")
	for forbidden_key in [
		"bag_order",
		"bag_cursor",
		"bag_epoch",
		"rng_state",
		"gameplay_seed",
		"global_unique_card_states",
		"applied_transactions",
		"ai_plan",
		"player_cash",
	]:
		_expect(not _variant_has_key(public_snapshot, forbidden_key), "public rack snapshot hides %s" % forbidden_key)
	_expect(_is_data_only(public_snapshot), "public rack snapshot stays pure data")


func _public_region(snapshot: Dictionary, region_id: String) -> Dictionary:
	for region_variant in snapshot.get("regions", []):
		if region_variant is Dictionary and str((region_variant as Dictionary).get("region_id", "")) == region_id:
			return (region_variant as Dictionary).duplicate(true)
	return {}


func _public_card_count(snapshot: Dictionary, card_id: String) -> int:
	var count := 0
	for region_variant in snapshot.get("regions", []):
		if not (region_variant is Dictionary):
			continue
		for slot_variant in (region_variant as Dictionary).get("slots", []):
			if slot_variant is Dictionary and str((slot_variant as Dictionary).get("card_id", "")) == card_id:
				count += 1
	return count


func _variant_has_key(value: Variant, key: String) -> bool:
	if value is Dictionary:
		for entry_key in (value as Dictionary).keys():
			if str(entry_key) == key or _variant_has_key((value as Dictionary)[entry_key], key):
				return true
	elif value is Array:
		for entry in value:
			if _variant_has_key(entry, key):
				return true
	return false


func _is_data_only(value: Variant) -> bool:
	if value is Object or value is Callable:
		return false
	if value is Dictionary:
		for key in (value as Dictionary).keys():
			if not _is_data_only(key) or not _is_data_only((value as Dictionary)[key]):
				return false
	elif value is Array:
		for item in value:
			if not _is_data_only(item):
				return false
	return true


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)
