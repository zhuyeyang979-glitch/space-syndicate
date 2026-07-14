extends SceneTree

const CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v06.tres"
const PROFILE_PATH := "res://resources/rules/space_syndicate_ruleset_v06.tres"
const TRANSACTION_SERVICE_SCRIPT := preload("res://scripts/cards/v06/card_flow_transaction_service_v06.gd")
const STATE_ADAPTER_SCRIPT := preload("res://scripts/cards/v06/production/card_player_state_production_adapter_v06.gd")
const ASSET_CONTROLLER_SCRIPT := preload("res://scripts/runtime/player_mana_runtime_controller.gd")
const INFRASTRUCTURE_SCRIPT := preload("res://scripts/runtime/region_infrastructure_runtime_controller.gd")
const COMMODITY_FLOW_SCRIPT := preload("res://scripts/runtime/commodity_flow_runtime_controller.gd")
const FACILITY_ADAPTER_SCRIPT := preload("res://scripts/cards/v06/effects/facility_card_effect_adapter_v06.gd")
const COMMODITY_ADAPTER_SCRIPT := preload("res://scripts/cards/v06/effects/commodity_card_effect_adapter_v06.gd")
const EFFECT_ROUTER_SCRIPT := preload("res://scripts/cards/v06/production/core_economic_card_effect_router_v06.gd")
const ASSET_IDS: Array[String] = ["life", "energy", "industry", "technology", "commerce", "shipping"]

var _checks := 0
var _failures: Array[String] = []


class TestWorld:
	extends Node
	var players: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := load(CATALOG_PATH) as CardRuntimeCatalogV06Resource
	var profile := load(PROFILE_PATH) as SpaceSyndicateRulesetProfileV06
	_expect(catalog != null and bool(catalog.reload().get("valid", false)), "真实 v0.6 卡牌目录可用")
	_expect(profile != null, "真实 v0.6 规则配置可用")
	if catalog == null or profile == null:
		_finish()
		return
	var profile_snapshot := profile.debug_snapshot()
	_verify_belt_race_merge_and_full_hand_reject(catalog, profile_snapshot)
	_verify_market_refresh_and_continuous_purchase(catalog, profile_snapshot)
	_verify_real_facility_and_commodity_play(catalog, profile_snapshot)
	_verify_missing_effect_owner_fails_closed(catalog, profile_snapshot)
	_finish()


func _verify_belt_race_merge_and_full_hand_reject(
	catalog: CardRuntimeCatalogV06Resource,
	profile_snapshot: Dictionary
) -> void:
	var ring := _card(catalog, "commodity.ring_crystal_battery.rank_1", "a:ring:1")
	var full_hand := [
		ring,
		_card(catalog, "commodity.star_dew_berry.rank_1", "a:star-dew:1"),
		_card(catalog, "commodity.lunar_soil_grape.rank_1", "a:lunar-soil:1"),
		_card(catalog, "commodity.spore_silk.rank_1", "a:spore-silk:1"),
		_card(catalog, "commodity.photosynthetic_gel.rank_1", "a:gel:1"),
	]
	var fixture := _production_fixture(
		catalog,
		profile_snapshot,
		[
			{"actor_id": "A", "cash": 10, "cash_cents": 1000, "slots": full_hand},
			{"actor_id": "B", "cash": 10, "cash_cents": 1000, "slots": []},
		],
		{0: _assets(0), 1: _assets(0)}
	)
	var service: Object = fixture.get("service")
	_expect(bool(service.call("register_player", "A", {}).get("configured", false)), "履带测试玩家 A 绑定生产 owner")
	_expect(bool(service.call("register_player", "B", {}).get("configured", false)), "履带测试玩家 B 绑定生产 owner")
	var configured: Dictionary = service.call("configure_belt", 7, [{
		"item_id": "belt-ring-race",
		"card": catalog.card_snapshot("commodity.ring_crystal_battery.rank_1"),
		"visible_actor_ids": ["A", "B"],
	}])
	_expect(bool(configured.get("configured", false)), "真实商品牌可进入履带牌源")
	var a_revision := int((service.call("player_snapshot", "A") as Dictionary).get("revision", -1))
	var b_revision := int((service.call("player_snapshot", "B") as Dictionary).get("revision", -1))
	var claimed: Dictionary = service.call("claim_belt_card", "A", "belt-ring-race", a_revision, 7, "tx-prod-belt-a")
	_expect(bool(claimed.get("committed", false)), "双玩家竞争时第一名玩家取得履带商品")
	var a_after: Dictionary = service.call("player_snapshot", "A")
	_expect(_card_count(a_after) == 5, "满手领取同名同级牌后仍保持五张")
	_expect(_family_rank_count(a_after, "commodity.ring_crystal_battery", 2) == 1, "满手同名同级商品自动合成为 II 级")
	var lost: Dictionary = service.call("claim_belt_card", "B", "belt-ring-race", b_revision, 7, "tx-prod-belt-b")
	_expect(not bool(lost.get("committed", true)) and str(lost.get("reason_code", "")) == "source_revision_changed", "第二名玩家不能重复取得同一履带 item")
	_expect(_card_count(service.call("player_snapshot", "B") as Dictionary) == 0, "履带竞争失败不污染另一名玩家的手牌")
	var replay: Dictionary = service.call("claim_belt_card", "A", "belt-ring-race", a_revision, 7, "tx-prod-belt-a")
	_expect(bool(replay.get("idempotent_replay", false)) and int((service.call("belt_snapshot") as Dictionary).get("revision", -1)) == 8, "履带成功交易重放不重复取牌")

	var different := catalog.card_snapshot("commodity.orbital_bonsai.rank_1")
	_expect(not different.is_empty(), "用于满手拒绝的不同商品存在")
	service.call("configure_belt", 20, [{
		"item_id": "belt-different-full",
		"card": different,
		"visible_actor_ids": ["A"],
	}])
	var before_reject := service.call("player_snapshot", "A") as Dictionary
	var rejected: Dictionary = service.call(
		"claim_belt_card",
		"A",
		"belt-different-full",
		int(before_reject.get("revision", -1)),
		20,
		"tx-prod-belt-full-reject"
	)
	_expect(not bool(rejected.get("committed", true)) and str(rejected.get("reason_code", "")) == "hand_full_no_matching_merge", "满手领取不同商品安全拒绝")
	_expect(_same_player_resources(before_reject, service.call("player_snapshot", "A") as Dictionary), "满手拒绝不扣牌、现金或资产")
	_expect((service.call("belt_snapshot") as Dictionary).get("items", {}).has("belt-different-full"), "满手拒绝不会误删履带 item")
	_cleanup_fixture(fixture)


func _verify_market_refresh_and_continuous_purchase(
	catalog: CardRuntimeCatalogV06Resource,
	profile_snapshot: Dictionary
) -> void:
	var fixture := _production_fixture(
		catalog,
		profile_snapshot,
		[{"actor_id": "A", "cash": 20, "cash_cents": 2000, "slots": []}],
		{0: _assets(0)}
	)
	var service: Object = fixture.get("service")
	service.call("register_player", "A", {})
	var warehouse := catalog.card_snapshot("facility.orbital_warehouse.rank_1")
	var road := catalog.card_snapshot("facility.road.rank_1")
	var seaport := catalog.card_snapshot("facility.seaport.rank_1")
	_expect(bool(service.call("configure_market", 3, {
		"item_id": "market-warehouse",
		"card": warehouse,
		"price_cash": 4,
	}).get("configured", false)), "动态市场使用真实设施牌 listing")
	var first_next := {"item_id": "market-road", "card": road, "price_cash": 3}
	var first_revision := int((service.call("player_snapshot", "A") as Dictionary).get("revision", -1))
	var first: Dictionary = service.call("purchase_market_card", "A", "market-warehouse", first_next, first_revision, 3, "tx-prod-market-1")
	_expect(bool(first.get("committed", false)) and int(first.get("cash_debit", -1)) == 4, "动态市场购买只扣一次成交价")
	_expect(int((service.call("player_snapshot", "A") as Dictionary).get("cash", -1)) == 16, "生产现金 owner 收到精确 -4 变化")
	var market_after_first: Dictionary = service.call("market_snapshot")
	_expect(int(market_after_first.get("revision", -1)) == 4 and str((market_after_first.get("listing", {}) as Dictionary).get("item_id", "")) == "market-road", "买走后 listing 在同一事务中立即刷新")
	var replay: Dictionary = service.call("purchase_market_card", "A", "market-warehouse", first_next, first_revision, 3, "tx-prod-market-1")
	_expect(bool(replay.get("idempotent_replay", false)) and int((service.call("player_snapshot", "A") as Dictionary).get("cash", -1)) == 16, "市场交易重放不重复扣款或刷新")

	var second_next := {"item_id": "market-seaport", "card": seaport, "price_cash": 2}
	var live_revision := int((service.call("player_snapshot", "A") as Dictionary).get("revision", -1))
	var stale: Dictionary = service.call("purchase_market_card", "A", "market-road", second_next, live_revision, 3, "tx-prod-market-stale")
	_expect(not bool(stale.get("committed", true)) and str(stale.get("reason_code", "")) == "source_revision_changed", "连续购买必须使用刷新后的 listing revision")
	_expect(int((service.call("player_snapshot", "A") as Dictionary).get("cash", -1)) == 16, "过期 listing revision 不扣现金")
	var second: Dictionary = service.call("purchase_market_card", "A", "market-road", second_next, live_revision, 4, "tx-prod-market-2")
	_expect(bool(second.get("committed", false)), "使用新 revision 可立即连续购买")
	_expect(int((service.call("player_snapshot", "A") as Dictionary).get("cash", -1)) == 13, "连续购买按第二张牌价格再扣一次")
	_expect(int((service.call("market_snapshot") as Dictionary).get("revision", -1)) == 5 and _card_count(service.call("player_snapshot", "A") as Dictionary) == 2, "连续购买得到两张真实牌并再次刷新市场")
	_cleanup_fixture(fixture)


func _verify_real_facility_and_commodity_play(
	catalog: CardRuntimeCatalogV06Resource,
	profile_snapshot: Dictionary
) -> void:
	var factory_card := _card(catalog, "facility.factory.life.rank_1", "a:factory:life:1")
	var commodity_card := _card(catalog, "commodity.star_dew_berry.rank_1", "a:commodity:star-dew:1")
	var fixture := _production_fixture(
		catalog,
		profile_snapshot,
		[{"actor_id": "A", "cash": 20, "cash_cents": 2000, "slots": [factory_card, commodity_card]}],
		{0: _assets(0)}
	)
	var infrastructure = INFRASTRUCTURE_SCRIPT.new()
	var flow = COMMODITY_FLOW_SCRIPT.new()
	root.add_child(infrastructure)
	root.add_child(flow)
	_expect(bool(infrastructure.call("configure", profile_snapshot).get("configured", false)), "真实区域设施 owner 完成配置")
	_expect(bool(flow.call("configure", profile_snapshot).get("configured", false)), "真实商品流 owner 完成配置")
	_expect(bool(infrastructure.call("initialize_regions", [{
		"region_id": "region-alpha",
		"terrain_id": "temperate",
		"neighbor_region_ids": [],
		"legacy_index": 0,
	}]).get("initialized", false)), "真实区域设施 owner 初始化目标区域")
	var facility_adapter = FACILITY_ADAPTER_SCRIPT.new()
	var commodity_adapter = COMMODITY_ADAPTER_SCRIPT.new()
	_expect(bool(facility_adapter.configure(infrastructure, {"A": 0}).get("configured", false)), "设施效果 adapter 连接真实区域 owner")
	_expect(bool(commodity_adapter.configure(flow, infrastructure, {"A": 0}).get("configured", false)), "商品效果 adapter 连接真实设施与商品流 owner")
	var router = EFFECT_ROUTER_SCRIPT.new()
	var router_result: Dictionary = router.configure({
		"build_upgrade_or_repair_facility": facility_adapter,
		"install_commodity_rate": commodity_adapter,
	})
	_expect(bool(router_result.get("configured", false)) and (router.call("configured_effect_kinds") as Array).size() == 2, "核心经济效果 router 只转发到真实 owner adapters")
	var service: Object = fixture.get("service")
	service.call("register_player", "A", {})
	var before_factory := service.call("player_snapshot", "A") as Dictionary
	var facility_target := {
		"valid": true,
		"target_kind": "region_unique_facility_slot",
		"region_id": "region-alpha",
		"slot_id": "region-alpha::factory.life",
		"industry_id": "life",
	}
	var facility_play: Dictionary = service.call(
		"play_card",
		"A",
		0,
		facility_target,
		router,
		int(before_factory.get("revision", -1)),
		"tx-prod-build-factory"
	)
	_expect(bool(facility_play.get("committed", false)), "工厂牌通过生产状态、router 与真实设施 owner 完整结算")
	var after_factory := service.call("player_snapshot", "A") as Dictionary
	_expect(_card_count(after_factory) == 1 and _slot_is_empty(after_factory, 0), "真实建工厂后只消费指定设施牌")
	_expect(_six_color_debit_matches(before_factory, after_factory, {}), "一级工厂牌在六色资产全零时可结算，且不建立通用余额")
	var facilities: Array = infrastructure.call("facilities_snapshot", false)
	_expect(facilities.size() == 1, "真实区域 owner 只建立一座工厂")
	var facility: Dictionary = facilities[0] if not facilities.is_empty() else {}
	_expect(str(facility.get("facility_type", "")) == "factory" and str(facility.get("industry_id", "")) == "life" and int(facility.get("owner_player_index", -1)) == 0, "工厂产权、类型和产业色均来自服务端映射")
	var asset_after_factory := (fixture.get("asset_owner") as Object).call("availability_snapshot", 0) as Dictionary
	_expect(int((asset_after_factory.get("assets", {}) as Dictionary).get("life", -1)) == 0, "真实资产 owner 对一级工厂提交零资产 debit")
	var facility_replay: Dictionary = service.call("play_card", "A", 0, facility_target, router, int(before_factory.get("revision", -1)), "tx-prod-build-factory")
	_expect(bool(facility_replay.get("idempotent_replay", false)) and (infrastructure.call("facilities_snapshot", false) as Array).size() == 1, "工厂交易重放不重复建造或扣资产")
	_expect(int(((fixture.get("asset_owner") as Object).call("availability_snapshot", 0) as Dictionary).get("assets", {}).get("life", -1)) == 0, "工厂重放保持零资产余额不变")

	var commodity_target := {
		"valid": true,
		"target_kind": "same_industry_factory_or_market",
		"facility_id": str(facility.get("facility_id", "")),
		"direction": "production",
	}
	var commodity_revision := int(after_factory.get("revision", -1))
	var commodity_play: Dictionary = service.call("play_card", "A", 1, commodity_target, router, commodity_revision, "tx-prod-install-commodity")
	_expect(bool(commodity_play.get("committed", false)), "商品牌通过 router 安装到真实同色工厂")
	var after_commodity := service.call("player_snapshot", "A") as Dictionary
	_expect(_card_count(after_commodity) == 0, "商品安装成功后只消费对应商品牌")
	_expect(_six_color_debit_matches(after_factory, after_commodity, {}), "免费商品牌不扣除任何六色资产")
	var installations: Array = flow.call("installations_snapshot", false)
	_expect(installations.size() == 1, "真实商品流 owner 只建立一个永久安装")
	var installation: Dictionary = installations[0] if not installations.is_empty() else {}
	_expect(str(installation.get("commodity_id", "")) == "星露莓" and str(installation.get("color", "")) == "life" and str(installation.get("direction", "")) == "production", "商品安装的产品、产业色与生产方向正确")
	var commodity_replay: Dictionary = service.call("play_card", "A", 1, commodity_target, router, commodity_revision, "tx-prod-install-commodity")
	_expect(bool(commodity_replay.get("idempotent_replay", false)) and (flow.call("installations_snapshot", false) as Array).size() == 1, "商品安装重放不重复产生永久增益")
	_cleanup_fixture(fixture)
	infrastructure.free()
	flow.free()


func _verify_missing_effect_owner_fails_closed(
	catalog: CardRuntimeCatalogV06Resource,
	profile_snapshot: Dictionary
) -> void:
	var fixture := _production_fixture(
		catalog,
		profile_snapshot,
		[{"actor_id": "A", "cash": 20, "cash_cents": 2000, "slots": [_card(catalog, "facility.factory.life.rank_1", "a:missing-owner:1")]}],
		{0: _assets(3)}
	)
	var service: Object = fixture.get("service")
	service.call("register_player", "A", {})
	var router = EFFECT_ROUTER_SCRIPT.new()
	_expect(not bool(router.configure({}).get("configured", true)), "缺少效果 owner 的 router 明确保持未配置")
	var before := service.call("player_snapshot", "A") as Dictionary
	var result: Dictionary = service.call("play_card", "A", 0, {
		"valid": true,
		"target_kind": "region_unique_facility_slot",
		"region_id": "region-missing-owner",
		"slot_id": "region-missing-owner::factory.life",
		"industry_id": "life",
	}, router, int(before.get("revision", -1)), "tx-prod-owner-missing")
	_expect(not bool(result.get("committed", true)) and str(result.get("reason_code", "")) == "effect_prepare_failed", "效果 owner 缺失时出牌 fail-closed")
	var after := service.call("player_snapshot", "A") as Dictionary
	_expect(_same_player_resources(before, after), "效果 owner 缺失时卡牌、现金、六色资产和 revision 全部不变")
	_expect(int(((fixture.get("asset_owner") as Object).call("availability_snapshot", 0) as Dictionary).get("assets", {}).get("life", -1)) == 3, "效果 owner 缺失不会留下资产预留或扣款")
	_cleanup_fixture(fixture)


func _production_fixture(
	catalog: CardRuntimeCatalogV06Resource,
	profile_snapshot: Dictionary,
	players: Array,
	balances_by_player: Dictionary
) -> Dictionary:
	var asset_owner = ASSET_CONTROLLER_SCRIPT.new()
	_expect(bool(asset_owner.call("configure", profile_snapshot).get("configured", false)), "生产资产 owner 完成配置")
	var pools: Dictionary = {}
	var remainders: Dictionary = {}
	for player_key_variant in balances_by_player.keys():
		var key := str(int(player_key_variant))
		var input_assets: Dictionary = balances_by_player.get(player_key_variant, {}) as Dictionary
		var pool_row: Dictionary = {}
		var remainder_row: Dictionary = {}
		for asset_id in ASSET_IDS:
			pool_row[asset_id] = int(input_assets.get(asset_id, 0)) * 1000
			remainder_row[asset_id] = 0
		pools[key] = pool_row
		remainders[key] = remainder_row
	var applied: Dictionary = asset_owner.call("apply_save_data", {
		"state_version": 1,
		"ruleset_id": "v0.6",
		"current_game_time": 0.0,
		"revision": 1,
		"pools_by_player": pools,
		"recovery_remainders_by_player": remainders,
		"reservations": {},
		"terminal_receipts": {},
	})
	_expect(bool(applied.get("applied", false)), "生产资产 owner 装载测试余额")
	var world := TestWorld.new()
	world.players = players.duplicate(true)
	var state_adapter = STATE_ADAPTER_SCRIPT.new()
	_expect(bool(state_adapter.call("configure", catalog, asset_owner).get("configured", false)), "生产玩家状态 adapter 连接真实资产 owner")
	_expect(bool(state_adapter.call("bind_world", world).get("bound", false)), "生产玩家状态 adapter 绑定唯一 players owner")
	var service = TRANSACTION_SERVICE_SCRIPT.new(catalog, state_adapter)
	return {
		"world": world,
		"asset_owner": asset_owner,
		"state_adapter": state_adapter,
		"service": service,
	}


func _cleanup_fixture(fixture: Dictionary) -> void:
	var state_adapter: Variant = fixture.get("state_adapter")
	if state_adapter is Node and is_instance_valid(state_adapter):
		(state_adapter as Node).free()
	var world: Variant = fixture.get("world")
	if world is Node and is_instance_valid(world):
		(world as Node).free()
	var asset_owner: Variant = fixture.get("asset_owner")
	if asset_owner is Node and is_instance_valid(asset_owner):
		(asset_owner as Node).free()


func _card(catalog: CardRuntimeCatalogV06Resource, card_id: String, instance_id: String) -> Dictionary:
	var card := catalog.card_snapshot(card_id)
	card["runtime_instance_id"] = instance_id
	return card


func _assets(value: int) -> Dictionary:
	var result: Dictionary = {}
	for asset_id in ASSET_IDS:
		result[asset_id] = value
	return result


func _card_count(player_state: Dictionary) -> int:
	var inventory: Dictionary = player_state.get("inventory", {}) if player_state.get("inventory", {}) is Dictionary else {}
	var count := 0
	for slot_variant in inventory.get("slots", []) as Array:
		if slot_variant is Dictionary:
			count += 1
	return count


func _slot_is_empty(player_state: Dictionary, slot_index: int) -> bool:
	var inventory: Dictionary = player_state.get("inventory", {}) if player_state.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	return slot_index >= 0 and slot_index < slots.size() and not (slots[slot_index] is Dictionary)


func _family_rank_count(player_state: Dictionary, family_id: String, rank: int) -> int:
	var inventory: Dictionary = player_state.get("inventory", {}) if player_state.get("inventory", {}) is Dictionary else {}
	var count := 0
	for slot_variant in inventory.get("slots", []) as Array:
		if not (slot_variant is Dictionary):
			continue
		var machine: Dictionary = (slot_variant as Dictionary).get("machine", {}) if (slot_variant as Dictionary).get("machine", {}) is Dictionary else {}
		if str(machine.get("family_id", "")) == family_id and int(machine.get("rank", 0)) == rank:
			count += 1
	return count


func _same_player_resources(first: Dictionary, second: Dictionary) -> bool:
	return (
		int(first.get("revision", -1)) == int(second.get("revision", -2))
		and int(first.get("cash", -1)) == int(second.get("cash", -2))
		and JSON.stringify(first.get("assets", {})) == JSON.stringify(second.get("assets", {}))
		and JSON.stringify(first.get("inventory", {})) == JSON.stringify(second.get("inventory", {}))
	)


func _six_color_debit_matches(before: Dictionary, after: Dictionary, debit: Dictionary) -> bool:
	var before_assets: Dictionary = before.get("assets", {}) if before.get("assets", {}) is Dictionary else {}
	var after_assets: Dictionary = after.get("assets", {}) if after.get("assets", {}) is Dictionary else {}
	if after_assets.has("generic") or after_assets.size() != ASSET_IDS.size():
		return false
	for asset_id in ASSET_IDS:
		if int(after_assets.get(asset_id, -1)) != int(before_assets.get(asset_id, -1)) - int(debit.get(asset_id, 0)):
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	print("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("CORE_ECONOMY_PRODUCTION_INTEGRATION_V06_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	print("CORE_ECONOMY_PRODUCTION_INTEGRATION_V06_TEST|status=FAIL|checks=%d|failures=%d|details=%s" % [_checks, _failures.size(), JSON.stringify(_failures)])
	quit(1)
