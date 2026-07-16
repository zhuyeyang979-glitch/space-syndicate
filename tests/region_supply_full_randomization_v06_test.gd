extends SceneTree

const ControllerScript := preload("res://scripts/runtime/region_supply_runtime_controller.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_seed_determinism_and_diversity()
	_verify_no_category_guarantees()
	_verify_public_reads_do_not_refresh_or_leak_bags()
	_verify_single_slot_atomic_refill()
	_verify_save_roundtrip_preserves_next_draw()
	_verify_global_unique_is_not_redealt()
	_finish()


func _verify_seed_determinism_and_diversity() -> void:
	var left := _controller(606120)
	var right := _controller(606120)
	var left_snapshot := left.public_rack_snapshot()
	var right_snapshot := right.public_rack_snapshot()
	_expect(_fingerprint(left_snapshot) == _fingerprint(right_snapshot), "相同 gameplay seed 产生相同区域牌架")

	var different_found := false
	for seed_value in range(606121, 606151):
		var other := _controller(seed_value)
		if _fingerprint(other.public_rack_snapshot()) != _fingerprint(left_snapshot):
			different_found = true
			other.free()
			break
		other.free()
	_expect(different_found, "不同 gameplay seed 能产生不同公开牌序")
	left.free()
	right.free()


func _verify_no_category_guarantees() -> void:
	var market_first_found := false
	var factory_first_found := false
	var other_first_found := false
	for seed_value in range(1, 301):
		var controller := _controller(seed_value)
		var first_type := _slot_type(controller.public_rack_snapshot("region.alpha"), 0)
		market_first_found = market_first_found or first_type == "facility_market"
		factory_first_found = factory_first_found or first_type == "facility_factory"
		other_first_found = other_first_found or first_type in [
			"route",
			"warehouse",
			"monster",
			"military",
			"organization",
			"interaction",
		]
		controller.free()
		if market_first_found and factory_first_found and other_first_found:
			break
	_expect(market_first_found, "随机牌架允许市场先于工厂出现")
	_expect(factory_first_found, "随机牌架允许工厂先于市场出现")
	_expect(other_first_found, "随机牌架允许交通、仓库、单位或组织牌占据首槽")

	var controller := _controller(91)
	var public_text := JSON.stringify(controller.public_rack_snapshot())
	_expect(not public_text.contains("guarantee") and not public_text.contains("stage"), "公开牌架没有保证槽或类别阶段字段")
	_expect(not public_text.contains("commodity.free"), "顶部免费商品牌不会进入普通区域牌架")
	_expect(not public_text.contains("factory.rank_2"), "非 I 级牌不会作为基础区域挂牌")
	_expect(not public_text.contains("retired.card"), "退役牌不会进入区域挂牌")
	controller.free()


func _verify_public_reads_do_not_refresh_or_leak_bags() -> void:
	var controller := _controller(404)
	var before_save := controller.to_save_data()
	var first := controller.public_rack_snapshot("region.alpha")
	var second := controller.public_rack_snapshot("region.alpha")
	var after_save := controller.to_save_data()
	_expect(_fingerprint(first) == _fingerprint(second), "重复打开或读取同一区域不会刷新牌架")
	_expect(_fingerprint(before_save) == _fingerprint(after_save), "公开读取不会推进 RNG、牌袋或刷新序号")
	var public_text := JSON.stringify(controller.public_rack_snapshot())
	for forbidden in ["bags_by_region", "rng_state_by_region", "pending_transactions", "terminal_transactions", "future"]:
		_expect(not public_text.contains(forbidden), "公开牌架不泄漏内部字段 %s" % forbidden)
	var debug := controller.debug_snapshot()
	_expect(bool(debug.get("public_snapshot_exposes_future_bag", true)) == false, "debug contract 明确公开快照不暴露未来牌袋")
	controller.free()


func _verify_single_slot_atomic_refill() -> void:
	var controller := _controller(5150)
	var before := controller.public_rack_snapshot("region.alpha")
	var before_slots := _slots(before)
	var target: Dictionary = before_slots[1]
	var prepared := controller.prepare_slot_refill(
		"region.alpha",
		1,
		str(target.get("item_id", "")),
		str(target.get("supply_revision", "")),
		"tx.single-slot"
	)
	_expect(bool(prepared.get("prepared", false)), "单槽补牌可先 prepare 且不立即改写牌架")
	_expect(_fingerprint(before) == _fingerprint(controller.public_rack_snapshot("region.alpha")), "prepare 阶段牌架零副作用")
	var committed := controller.commit_slot_refill("tx.single-slot")
	_expect(bool(committed.get("committed", false)), "单槽补牌 commit 成功")
	var after_slots := _slots(controller.public_rack_snapshot("region.alpha"))
	_expect(before_slots.size() == after_slots.size(), "购买后区域槽位数量保持不变")
	for index in range(before_slots.size()):
		if index == 1:
			_expect(str((before_slots[index] as Dictionary).get("item_id", "")) != str((after_slots[index] as Dictionary).get("item_id", "")), "只替换被购买的槽位")
		else:
			_expect(_fingerprint(before_slots[index]) == _fingerprint(after_slots[index]), "未购买槽位 %d 保持不变" % index)
	var finalized := controller.finalize_slot_refill("tx.single-slot")
	var replay := controller.finalize_slot_refill("tx.single-slot")
	_expect(bool(finalized.get("finalized", false)) and bool(replay.get("replayed", false)), "finalize 与 exact-once replay 稳定")

	var rollback_before := controller.public_rack_snapshot("region.alpha")
	var rollback_slots := _slots(rollback_before)
	var rollback_target: Dictionary = rollback_slots[2]
	controller.prepare_slot_refill(
		"region.alpha",
		2,
		str(rollback_target.get("item_id", "")),
		str(rollback_target.get("supply_revision", "")),
		"tx.rollback"
	)
	controller.commit_slot_refill("tx.rollback")
	var rolled_back := controller.rollback_slot_refill("tx.rollback")
	_expect(bool(rolled_back.get("rolled_back", false)), "已提交补牌可精确 rollback")
	_expect(_fingerprint(rollback_before) == _fingerprint(controller.public_rack_snapshot("region.alpha")), "rollback 恢复购买前完整公开牌架")
	controller.free()


func _verify_save_roundtrip_preserves_next_draw() -> void:
	var source := _controller(8080)
	var source_slots := _slots(source.public_rack_snapshot("region.beta"))
	var first_target: Dictionary = source_slots[0]
	source.prepare_slot_refill(
		"region.beta",
		0,
		str(first_target.get("item_id", "")),
		str(first_target.get("supply_revision", "")),
		"tx.before-save"
	)
	source.commit_slot_refill("tx.before-save")
	source.finalize_slot_refill("tx.before-save")
	var save := source.to_save_data()

	var restored: RegionSupplyRuntimeController = ControllerScript.new()
	root.add_child(restored)
	var applied := restored.apply_save_data(save)
	_expect(bool(applied.get("applied", false)), "区域牌架 save 可事务性恢复")
	_expect(_fingerprint(source.public_rack_snapshot()) == _fingerprint(restored.public_rack_snapshot()), "读档后全部当前牌位完全一致")

	var next_source_target: Dictionary = _slots(source.public_rack_snapshot("region.beta"))[1]
	var next_restored_target: Dictionary = _slots(restored.public_rack_snapshot("region.beta"))[1]
	var source_plan := source.prepare_slot_refill(
		"region.beta",
		1,
		str(next_source_target.get("item_id", "")),
		str(next_source_target.get("supply_revision", "")),
		"tx.next-draw"
	)
	var restored_plan := restored.prepare_slot_refill(
		"region.beta",
		1,
		str(next_restored_target.get("item_id", "")),
		str(next_restored_target.get("supply_revision", "")),
		"tx.next-draw"
	)
	_expect(
		_fingerprint(source_plan.get("next_listing", {})) == _fingerprint(restored_plan.get("next_listing", {})),
		"读档后下一张牌与原运行完全一致"
	)
	source.free()
	restored.free()


func _verify_global_unique_is_not_redealt() -> void:
	var controller := _controller(7331)
	var seen_unique := 0
	for row_variant in (controller.public_rack_snapshot().get("regions", []) as Array):
		for listing_variant in ((row_variant as Dictionary).get("slots", []) as Array):
			var listing: Dictionary = listing_variant
			if str(listing.get("card_id", "")) == "unique.relic":
				seen_unique += 1
	_expect(seen_unique <= 1, "全局唯一牌在所有区域初始牌架中最多出现一次")
	for step in range(20):
		var snapshot := controller.public_rack_snapshot("region.alpha")
		var slots := _slots(snapshot)
		var slot_index := step % slots.size()
		var listing: Dictionary = slots[slot_index]
		if listing.is_empty():
			continue
		var tx := "tx.unique.%d" % step
		var prepared := controller.prepare_slot_refill(
			"region.alpha",
			slot_index,
			str(listing.get("item_id", "")),
			str(listing.get("supply_revision", "")),
			tx
		)
		if not bool(prepared.get("prepared", false)):
			continue
		controller.commit_slot_refill(tx)
		controller.finalize_slot_refill(tx)
	var unique_after := 0
	for row_variant in (controller.public_rack_snapshot().get("regions", []) as Array):
		for listing_variant in ((row_variant as Dictionary).get("slots", []) as Array):
			if str((listing_variant as Dictionary).get("card_id", "")) == "unique.relic":
				unique_after += 1
	_expect(unique_after <= 1, "全局唯一牌被拿走后不会重新进入后续牌袋")
	controller.free()


func _controller(seed_value: int) -> RegionSupplyRuntimeController:
	var controller: RegionSupplyRuntimeController = ControllerScript.new()
	root.add_child(controller)
	var configured := controller.configure(seed_value, _regions(), _cards(), 4)
	_expect(bool(configured.get("configured", false)), "fixture 区域牌架可配置")
	return controller


func _regions() -> Array:
	return [
		{"region_id": "region.beta", "region_index": 1, "display_name": "贝塔海岸", "terrain": "ocean", "active": true},
		{"region_id": "region.alpha", "region_index": 0, "display_name": "阿尔法平原", "terrain": "land", "active": true},
		{"region_id": "region.ruin", "region_index": 2, "display_name": "废墟", "terrain": "land", "active": true, "destroyed": true},
	]


func _cards() -> Array:
	return [
		_card("facility.factory", "facility_factory", 12),
		_card("facility.market", "facility_market", 12),
		_card("route.road", "route", 8),
		_card("facility.warehouse", "warehouse", 9),
		_card("unit.monster", "monster", 14),
		_card("unit.military", "military", 10),
		_card("organization.network", "organization", 11),
		_card("interaction.signal", "interaction", 7),
		_card("expensive.but.legal", "organization", 999, {"currently_affordable": false}),
		_card("unique.relic", "interaction", 20, {"global_unique": true, "unique_key": "unique.relic"}),
		_card("ocean.port", "route", 9, {"legal_region_ids": ["region.beta"]}),
		_card("land.transit", "route", 9, {"allowed_terrain": ["land"]}),
		_card("commodity.free", "commodity", 0, {"is_commodity": true}),
		_card("factory.rank_2", "facility_factory", 12, {"rank": "II"}),
		_card("retired.card", "organization", 1, {"retired": true}),
		_card("invalid.target", "interaction", 1, {"potential_target_exists": false}),
	]


func _card(card_id: String, card_type: String, price_cash: int, extra: Dictionary = {}) -> Dictionary:
	var row := {
		"card_id": card_id,
		"family_id": card_id,
		"card_type": card_type,
		"rank": "I",
		"display_name": card_id,
		"price_cash": price_cash,
		"target_type": "region",
		"effect_text": "fixture",
		"enabled": true,
		"valid": true,
		"potential_target_exists": true,
		"region_supply_weight": 1,
	}
	row.merge(extra, true)
	return row


func _slot_type(snapshot: Dictionary, slot_index: int) -> String:
	var slots := _slots(snapshot)
	if slot_index < 0 or slot_index >= slots.size():
		return ""
	var listing: Dictionary = slots[slot_index]
	var card: Dictionary = listing.get("card", {}) if listing.get("card", {}) is Dictionary else {}
	return str(card.get("card_type", ""))


func _slots(snapshot: Dictionary) -> Array:
	var regions: Array = snapshot.get("regions", []) if snapshot.get("regions", []) is Array else []
	if regions.is_empty():
		return []
	return ((regions[0] as Dictionary).get("slots", []) as Array).duplicate(true)


func _fingerprint(value: Variant) -> String:
	return JSON.stringify(value, "", true)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	print("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("REGION_SUPPLY_FULL_RANDOMIZATION_V06_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	print("REGION_SUPPLY_FULL_RANDOMIZATION_V06_TEST|status=FAIL|checks=%d|failures=%d|details=%s" % [
		_checks,
		_failures.size(),
		JSON.stringify(_failures),
	])
	quit(1)
