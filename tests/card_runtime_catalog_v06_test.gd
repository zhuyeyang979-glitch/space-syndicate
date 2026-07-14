extends SceneTree

const CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v06.tres"
const ASSET_IDS := ["life", "energy", "industry", "technology", "commerce", "shipping"]
const FACILITY_KINDS := ["factory", "market", "road", "port", "spaceport", "warehouse"]
const FACILITY_FAMILY_IDS := [
	"facility.factory.life", "facility.market.life",
	"facility.factory.energy", "facility.market.energy",
	"facility.factory.industry", "facility.market.industry",
	"facility.factory.technology", "facility.market.technology",
	"facility.factory.commerce", "facility.market.commerce",
	"facility.factory.shipping", "facility.market.shipping",
	"facility.road", "facility.seaport", "facility.spaceport", "facility.orbital_warehouse",
]

var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := load(CATALOG_PATH) as CardRuntimeCatalogV06Resource
	_expect(catalog != null, "v0.6 card catalog resource loads")
	if catalog == null:
		_finish()
		return
	var report := catalog.reload()
	_expect(bool(report.get("valid", false)), "v0.6 catalog passes structural validation: %s" % JSON.stringify(report.get("errors", [])))
	_expect(int(report.get("card_count", 0)) == 348, "v0.6 named seed contains 348 explicit ranked cards")
	_expect(int(report.get("family_count", 0)) == 87, "v0.6 named seed contains 87 complete families")
	_expect(int(report.get("player_text_leak_count", -1)) == 0, "player text contains no machine or developer field leaks")
	_expect(int(report.get("effect_review_pending_count", -1)) == 132, "132 facility/unit/direct-interaction ranks remain explicitly queued for effect confirmation")
	var categories: Dictionary = report.get("category_counts", {}) if report.get("category_counts", {}) is Dictionary else {}
	_expect(categories == {"commodity": 184, "facility": 64, "supply_demand": 8, "monster": 32, "military": 28, "interaction": 12, "organization": 20}, "category counts match the 87-family seed")

	var snapshot := catalog.catalog_snapshot()
	var metadata: Dictionary = snapshot.get("metadata", {}) if snapshot.get("metadata", {}) is Dictionary else {}
	var blockers: Array = metadata.get("release_blockers", []) if metadata.get("release_blockers", []) is Array else []
	_expect(blockers.has("commodity_industry_family_counts_not_equal_11_each"), "unequal six-color commodity counts remain a visible release blocker")
	_expect(int(metadata.get("future_balanced_ranked_card_count", 0)) == 428, "catalog records the 428-card future balanced target without inventing unnamed goods")

	_verify_acquisition_and_inventory(catalog)
	_verify_facility_bootstrap_and_gradient(catalog)
	_verify_confirmed_gradients(catalog)
	_verify_representative_cards(catalog)
	_finish()


func _verify_acquisition_and_inventory(catalog: CardRuntimeCatalogV06Resource) -> void:
	_expect(catalog.cards_for_acquisition("commodity_belt_free").size() == 184, "all 184 commodity ranks are belt-acquired and free")
	_expect(catalog.cards_for_acquisition("dynamic_market_cash").size() == 132, "132 non-monster ranks use the cash market")
	_expect(catalog.cards_for_acquisition("starter_or_dynamic_market_cash").size() == 32, "all 32 monster ranks support starter or market acquisition")
	for card_id in catalog.card_ids():
		var card := catalog.card_snapshot(card_id)
		var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
		var developer: Dictionary = card.get("developer", {}) if card.get("developer", {}) is Dictionary else {}
		_expect(str(machine.get("merge_policy", "")) == "manual_same_family_same_rank_or_auto_once_when_full", "%s declares the v0.6 merge policy" % card_id)
		_expect(bool(machine.get("counts_toward_hand_limit", false)), "%s counts toward the ordinary five-card hand" % card_id)
		_expect(str(machine.get("resolution_policy", "")) == "reject_before_consume_if_unowned", "%s cannot be consumed by an unowned effect" % card_id)
		_expect(str(developer.get("art_key", "")).strip_edges() != "", "%s has an explicit art indirection key" % card_id)


func _verify_facility_bootstrap_and_gradient(catalog: CardRuntimeCatalogV06Resource) -> void:
	var expected_cash := [4, 7, 11, 16]
	var expected_assets := [0, 2, 4, 7]
	var families := {}
	var facility_card_count := 0
	for card_id in catalog.card_ids():
		var card := catalog.card_snapshot(card_id)
		var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
		if str(machine.get("category_id", "")) != "facility":
			continue
		facility_card_count += 1
		families[str(machine.get("family_id", ""))] = true
	_expect(facility_card_count == 64, "the catalog contains four ranks for each of the 16 facility families")
	_expect(families.size() == 16, "the facility bootstrap rule covers exactly 16 facility families")
	var actual_families: Array = families.keys()
	var expected_families: Array = FACILITY_FAMILY_IDS.duplicate()
	actual_families.sort()
	expected_families.sort()
	_expect(actual_families == expected_families, "the facility gradient applies to the exact 16 authoritative families")

	for family_variant in families.keys():
		var family_id := str(family_variant)
		var previous_payload := {}
		for rank in range(1, 5):
			var card_id := "%s.rank_%d" % [family_id, rank]
			var card := catalog.card_snapshot(card_id)
			_expect(not card.is_empty(), "%s exists for the complete facility ladder" % card_id)
			if card.is_empty():
				continue
			var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
			var player: Dictionary = card.get("player", {}) if card.get("player", {}) is Dictionary else {}
			var payload: Dictionary = machine.get("effect_payload", {}) if machine.get("effect_payload", {}) is Dictionary else {}
			var industry_id := str(machine.get("industry_id", ""))
			var facility_kind := str(payload.get("facility_kind", ""))
			var expected_asset_key := industry_id if ASSET_IDS.has(industry_id) else "generic"
			var asset_cost: Dictionary = machine.get("asset_cost", {}) if machine.get("asset_cost", {}) is Dictionary else {}

			_expect(FACILITY_KINDS.has(facility_kind), "%s uses a field-driven facility kind" % card_id)
			_expect(int(machine.get("purchase_cash", -1)) == expected_cash[rank - 1], "%s uses the facility cash ladder" % card_id)
			_expect(_asset_total(asset_cost) == expected_assets[rank - 1], "%s uses the facility asset ladder" % card_id)
			_expect(int(asset_cost.get(expected_asset_key, -1)) == expected_assets[rank - 1], "%s charges the matching color or generic asset type" % card_id)
			for asset_id in ASSET_IDS + ["generic"]:
				if asset_id == expected_asset_key:
					continue
				_expect(int(asset_cost.get(asset_id, -1)) == 0, "%s does not charge an unrelated asset type" % card_id)

			var is_colored := facility_kind == "factory" or facility_kind == "market"
			_expect((is_colored and ASSET_IDS.has(industry_id)) or (not is_colored and industry_id == "generic"), "%s facility type and machine industry agree" % card_id)
			_expect(str(payload.get("industry_id", "")) == (industry_id if is_colored else ""), "%s runtime payload preserves the facility color contract" % card_id)
			var player_cost := str(player.get("cost", ""))
			_expect(player_cost.contains("现金 %d" % expected_cash[rank - 1]), "%s player text shows its cash price" % card_id)
			if rank == 1:
				_expect(player_cost.contains("打出免费") and not player_cost.contains("资产"), "%s states free play without claiming an asset requirement" % card_id)
			else:
				_expect(player_cost.contains("打出 %d" % expected_assets[rank - 1]) and player_cost.contains("资产"), "%s player text shows its higher-rank asset commitment" % card_id)

			if not previous_payload.is_empty():
				_expect(int(payload.get("shared_hp_contribution", 0)) > int(previous_payload.get("shared_hp_contribution", 0)), "%s shared HP strictly increases by rank" % family_id)
				for capacity_key in _facility_capacity_keys(facility_kind):
					_expect(float(payload.get(capacity_key, 0.0)) > float(previous_payload.get(capacity_key, 0.0)), "%s %s strictly increases by rank" % [family_id, capacity_key])
			previous_payload = payload.duplicate(true)

	var commodity_count := 0
	for card_id in catalog.card_ids():
		var card := catalog.card_snapshot(card_id)
		var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
		if str(machine.get("category_id", "")) != "commodity":
			continue
		commodity_count += 1
		var player: Dictionary = card.get("player", {}) if card.get("player", {}) is Dictionary else {}
		_expect(int(machine.get("purchase_cash", -1)) == 0 and _asset_total(machine.get("asset_cost", {})) == 0, "%s remains free to acquire and play" % card_id)
		_expect(str(player.get("cost", "")) == "免费", "%s keeps the commodity-free player text" % card_id)
	_expect(commodity_count == 184, "the commodity-free invariant covers all 184 commodity cards")


func _facility_capacity_keys(facility_kind: String) -> Array[String]:
	match facility_kind:
		"factory":
			return ["production_capacity_units_per_minute"]
		"market":
			return ["demand_capacity_units_per_minute"]
		"road", "port", "spaceport":
			return ["throughput_units_per_minute", "speed_multiplier"]
		"warehouse":
			return ["storage_capacity_units", "inbound_throughput_units_per_minute", "outbound_throughput_units_per_minute"]
	return []


func _verify_confirmed_gradients(catalog: CardRuntimeCatalogV06Resource) -> void:
	var expected_product_rates := [10, 20, 40, 80]
	var expected_order_units := [20, 40, 80, 160]
	var expected_factory_capacity := [40, 80, 140, 220]
	var expected_transit := [50, 100, 175, 275]
	var expected_warehouse := [200, 400, 700, 1100]
	for rank in range(1, 5):
		var product_payload := _payload(catalog, "commodity.ring_crystal_battery.rank_%d" % rank)
		_expect(int(product_payload.get("rate_per_minute", 0)) == expected_product_rates[rank - 1], "commodity rate ladder is explicit at rank %d" % rank)
		var order_payload := _payload(catalog, "supply_demand.remote_sea_order.rank_%d" % rank)
		_expect(int(order_payload.get("budget_units", 0)) == expected_order_units[rank - 1], "order budget ladder is explicit at rank %d" % rank)
		var supply_payload := _payload(catalog, "supply_demand.near_land_supply.rank_%d" % rank)
		_expect(int(supply_payload.get("spawn_units", 0)) == expected_order_units[rank - 1], "supply spawn ladder is explicit at rank %d" % rank)
		var factory_payload := _payload(catalog, "facility.factory.energy.rank_%d" % rank)
		_expect(int(factory_payload.get("production_capacity_units_per_minute", 0)) == expected_factory_capacity[rank - 1], "factory capacity ladder is explicit at rank %d" % rank)
		var road_payload := _payload(catalog, "facility.road.rank_%d" % rank)
		_expect(int(road_payload.get("throughput_units_per_minute", 0)) == expected_transit[rank - 1], "transit throughput ladder is explicit at rank %d" % rank)
		var warehouse_payload := _payload(catalog, "facility.orbital_warehouse.rank_%d" % rank)
		_expect(int(warehouse_payload.get("storage_capacity_units", 0)) == expected_warehouse[rank - 1], "warehouse storage ladder is explicit at rank %d" % rank)
		_expect(int(warehouse_payload.get("shared_hp_contribution", 0)) == rank * 100, "facility shared-HP contribution is explicit at rank %d" % rank)
	var port_payload := _payload(catalog, "facility.seaport.rank_1")
	_expect(str(port_payload.get("facility_kind", "")) == "port", "seaport card maps to the runtime port facility kind")
	_expect((port_payload.get("allowed_region_states", []) as Array).has("ruined"), "facility cards can rebuild a ruined region")


func _verify_representative_cards(catalog: CardRuntimeCatalogV06Resource) -> void:
	var ring := catalog.card_snapshot("commodity.ring_crystal_battery.rank_1")
	_expect(not ring.is_empty(), "locked Skin Lab ID for 环晶电池 I exists")
	var ring_machine: Dictionary = ring.get("machine", {}) if ring.get("machine", {}) is Dictionary else {}
	_expect(int(ring_machine.get("purchase_cash", -1)) == 0 and _asset_total(ring_machine.get("asset_cost", {})) == 0, "环晶电池 is free to acquire and play")
	var warehouse := catalog.card_snapshot("facility.orbital_warehouse.rank_1")
	_expect(not warehouse.is_empty(), "locked Skin Lab ID for 轨道仓库 I exists")
	var remote := catalog.card_snapshot("supply_demand.remote_sea_order.rank_1")
	_expect(not remote.is_empty(), "locked Skin Lab ID for 远洋采购令 I exists")
	var near_supply := catalog.card_snapshot("supply_demand.near_land_supply.rank_1")
	_expect(not near_supply.is_empty(), "locked Skin Lab ID for 近地供货潮 I exists")
	var monster_payload := _payload(catalog, "unit.monster.spore_tide_emperor.rank_1")
	_expect(int(monster_payload.get("same_name_upgrade_extend_seconds", 0)) == 60, "monster upgrade extends presence by 60 seconds")
	_expect(not bool(monster_payload.get("refresh_total_presence_time", true)), "monster upgrade does not refresh total presence time")
	_expect(bool(monster_payload.get("upgrade_target_same_family_any_owner", false)), "monster cards can reinforce the unique same-family monster regardless of owner")
	_expect(not bool(monster_payload.get("ownership_transfer_on_upgrade", true)), "reinforcing another owner's monster never transfers control")
	_expect(str(monster_payload.get("bound_skill_recipient", "")) == "existing_monster_owner", "reinforcement skills remain with the existing monster owner")
	_expect(str(monster_payload.get("starter_conflict_policy", "")) == "private_reselect", "starter same-name conflicts use private reselection")
	_expect(bool(monster_payload.get("upgrade_respects_target_owner_rank_cap", false)), "reinforcement respects the target owner's organization rank cap")
	_expect(not monster_payload.has("upgrade_target_owned_same_family"), "retired owner-only monster upgrade field is absent")
	var veto_payload := _payload(catalog, "interaction.phase_veto.rank_1")
	_expect(int(veto_payload.get("response_depth", 0)) == 1, "phase veto keeps the one-layer response rule")
	_expect(str(veto_payload.get("target_scope", "")) == "direct_player_interaction", "phase veto only targets direct player interaction")
	var organization := catalog.card_snapshot("organization.starport_clearinghouse.rank_1")
	_expect(not organization.is_empty(), "organization catalog exposes the starport clearinghouse ladder")
	var organization_machine: Dictionary = organization.get("machine", {}) if organization.get("machine", {}) is Dictionary else {}
	_expect(str(organization_machine.get("target_kind", "")) == "self_organization_slot", "organization cards only target the installer's organization slots")


func _payload(catalog: CardRuntimeCatalogV06Resource, card_id: String) -> Dictionary:
	var card := catalog.card_snapshot(card_id)
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	var value: Variant = machine.get("effect_payload", {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _asset_total(value: Variant) -> int:
	if not (value is Dictionary):
		return -1
	var total := 0
	for amount in (value as Dictionary).values():
		total += int(amount)
	return total


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	print("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("CARD_RUNTIME_CATALOG_V06_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	print("CARD_RUNTIME_CATALOG_V06_TEST|status=FAIL|checks=%d|failures=%d|details=%s" % [_checks, _failures.size(), JSON.stringify(_failures)])
	quit(1)
