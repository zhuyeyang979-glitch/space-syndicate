extends Node

const OUTPUT_PATH := "res://data/cards/card_runtime_catalog_v06.json"
const PRODUCT_CATALOG_PATH := "res://resources/content/product_industry_catalog_v05.tres"
const CATALOG_RESOURCE_PATH := "res://resources/cards/runtime/card_runtime_catalog_v06.tres"
const RANK_LABELS := ["", "I", "II", "III", "IV"]
const PRODUCT_RATE := [0, 10, 20, 40, 80]
const FACILITY_CASH := [0, 4, 7, 11, 16]
# Rank-I city development is the economy bootstrap: it still costs cash to
# acquire, but it must be playable before the first city can generate colored
# GDP assets. Higher ranks keep the escalating asset commitment.
const FACILITY_ASSET_COST := [0, 0, 2, 4, 7]
const FACILITY_HP_CONTRIBUTION := [0, 100, 200, 300, 400]
const FACTORY_MARKET_CAPACITY := [0, 40, 80, 140, 220]
const TRANSIT_THROUGHPUT := [0, 50, 100, 175, 275]
const TRANSIT_SPEED_MULTIPLIER := [0.0, 1.0, 1.2, 1.45, 1.75]
const WAREHOUSE_STORAGE := [0, 200, 400, 700, 1100]
const SUPPLY_CASH := [0, 5, 8, 12, 17]
const SUPPLY_ASSET_COST := [0, 2, 3, 5, 8]
const UNIT_CASH := [0, 6, 10, 15, 21]
const UNIT_ASSET_COST := [0, 2, 4, 6, 9]
const INTERACTION_CASH := [0, 5, 8, 12, 17]
const INTERACTION_ASSET_COST := [0, 2, 3, 5, 8]
const ORGANIZATION_SLOT_LIMIT := 3

const PRODUCT_SLUGS := [
	"star_dew_berry", "lunar_soil_grape", "spore_silk", "photosynthetic_gel", "orbital_bonsai", "frost_crown_sugar", "deep_sea_fungal_mat", "twilight_cheese", "polar_mint", "stardust_bread", "sleepwalking_mushroom",
	"magnetic_core_durian", "comet_tail_citrus", "ring_crystal_battery", "solar_scale", "seabed_black_oil", "antimatter_tea", "static_honey", "plasma_rice", "volcanic_tomato", "tidal_plasma",
	"gravity_ceramic", "iris_mineral_powder", "gravity_cotton", "titanium_shell_clam", "meteorite_sauce", "dark_reef_coral",
	"living_chip", "aurora_salt", "trajectory_ink", "offshore_crystal",
	"quantum_melon", "pulse_coffee", "vacuum_cocoa", "ion_spice", "dream_fragrance", "zero_point_beverage", "mica_toy", "storm_pearl", "equatorial_vanilla",
	"star_whale_canning", "starfin_school", "blue_tide_algae", "giant_kelp_fiber", "night_sailing_banana", "satellite_nut",
]

const INDUSTRY_NAMES := {
	"life": "生命",
	"energy": "能源",
	"industry": "工业",
	"technology": "科技",
	"commerce": "商贸",
	"shipping": "航运",
	"generic": "通用",
}

const INDUSTRY_ACCENTS := {
	"life": "#22c55e",
	"energy": "#f97316",
	"industry": "#94a3b8",
	"technology": "#38bdf8",
	"commerce": "#c084fc",
	"shipping": "#06b6d4",
	"generic": "#fde68a",
}

var _cards: Array[Dictionary] = []


func _ready() -> void:
	call_deferred("_build")


func _build() -> void:
	var product_catalog := load(PRODUCT_CATALOG_PATH) as ProductIndustryCatalogResource
	if product_catalog == null or product_catalog.products.size() != PRODUCT_SLUGS.size():
		_log("build", "E_PRODUCT_CATALOG", {"products": product_catalog.products.size() if product_catalog != null else -1, "slugs": PRODUCT_SLUGS.size()})
		set_meta("build_exit_code", 1)
		return
	_cards.clear()
	_build_commodity_cards(product_catalog)
	_build_facility_cards()
	_build_supply_demand_cards()
	_build_monster_cards()
	_build_military_cards()
	_build_interaction_cards()
	_build_organization_cards()
	var catalog := {
		"schema_version": "v0.6",
		"catalog_id": "space_syndicate.card_runtime_catalog.v06",
		"catalog_status": "complete_named_seed_playtest",
		"generated_at": "2026-07-15",
		"ruleset_id": "space_syndicate_v06",
		"cards": _cards,
		"metadata": {
			"named_family_count": 87,
			"explicit_ranked_card_count": 348,
			"future_balanced_family_count": 107,
			"future_balanced_ranked_card_count": 428,
			"organization_family_count": 5,
			"organization_ranked_card_count": 20,
			"commodity_family_counts": {"life": 11, "energy": 10, "industry": 6, "technology": 4, "commerce": 9, "shipping": 6},
			"release_blockers": [
				"commodity_industry_family_counts_not_equal_11_each",
				"runtime_acquisition_merge_play_resolution_wiring_pending",
				"organization_installation_runtime_wiring_pending",
			],
			"balance_policy": "All cash and asset values outside commodity-free play are provisional flow-test values pending effect review.",
		},
	}
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		_log("build", "E_OUTPUT_OPEN", {"path": OUTPUT_PATH})
		set_meta("build_exit_code", 1)
		return
	file.store_string(JSON.stringify(catalog, "\t", false) + "\n")
	file.close()
	var catalog_resource := load(CATALOG_RESOURCE_PATH) as CardRuntimeCatalogV06Resource
	var report: Dictionary = catalog_resource.reload() if catalog_resource != null else {"valid": false, "errors": ["catalog_resource_load_failed"]}
	var valid := bool(report.get("valid", false))
	_log("build", "OK" if valid else "E_VALIDATION", {
		"cards": report.get("card_count", 0),
		"families": report.get("family_count", 0),
		"categories": JSON.stringify(report.get("category_counts", {})),
		"effect_review_pending": report.get("effect_review_pending_count", 0),
		"errors": JSON.stringify(report.get("errors", [])),
		"output": OUTPUT_PATH,
	})
	set_meta("build_exit_code", 0 if valid else 1)
	_log("awaiting_mcp_stop", "OK" if valid else "E_VALIDATION", {"detail": "v0.6 卡牌目录构建完成，等待 Godot MCP 停止项目。"})


func _build_commodity_cards(product_catalog: ProductIndustryCatalogResource) -> void:
	for index in range(product_catalog.products.size()):
		var product := product_catalog.products[index]
		var slug := str(PRODUCT_SLUGS[index])
		var family_id := "commodity.%s" % slug
		var industry_id := str(product.industry_id)
		var display_name := str(product.display_name)
		for rank in range(1, 5):
			var rate := int(PRODUCT_RATE[rank])
			var art_key := "procedural.commodity.%s" % industry_id
			if slug == "ring_crystal_battery" and rank == 1:
				art_key = "commodity.ring_crystal_battery.rank_1"
			_add_card(
				family_id, rank, "commodity", industry_id, "commodity_belt_free", 0, _assets("generic", 0),
				"install_commodity_rate", "same_industry_factory_or_market",
				{"product_id": str(product.product_id), "industry_id": industry_id, "rate_per_minute": rate, "valid_facility_kinds": ["factory", "market"], "persistence": "until_facility_destroyed"},
				{
					"name": display_name,
					"type": "商品牌",
					"industry": _industry_name(industry_id),
					"cost": "免费",
					"timing": "普通出牌窗口",
					"target": "一座同色工厂或市场",
					"short_effect": "永久增加 %d 单位/分钟的生产或需求。" % rate,
					"effect": "将这张牌安装到一座同色工厂或市场，为%s永久增加 %d 单位/分钟的基础生产率或需求率。" % [display_name, rate],
					"duration": "永久；设施被摧毁时终止",
					"visibility": "安装位置、数量和所有者公开",
					"next_step": "选择同色工厂或市场",
				},
				{"effect_review_status": "rule_confirmed", "runtime_owner": "commodity_flow_runtime_controller", "art_key": art_key, "balance_status": "rule_confirmed"}
			)


func _build_facility_cards() -> void:
	var specs: Array[Dictionary] = []
	for industry_id in ["life", "energy", "industry", "technology", "commerce", "shipping"]:
		specs.append({"slug": "factory.%s" % industry_id, "name": "%s工厂" % _industry_name(industry_id), "kind": "factory", "industry": industry_id})
		specs.append({"slug": "market.%s" % industry_id, "name": "%s市场" % _industry_name(industry_id), "kind": "market", "industry": industry_id})
	specs.append_array([
		{"slug": "road", "name": "道路", "kind": "road", "industry": "generic"},
		{"slug": "seaport", "name": "码头", "kind": "port", "industry": "generic"},
		{"slug": "spaceport", "name": "空港", "kind": "spaceport", "industry": "generic"},
		{"slug": "orbital_warehouse", "name": "轨道仓库", "kind": "warehouse", "industry": "generic"},
	])
	for spec in specs:
		var family_id := "facility.%s" % str(spec.slug)
		var industry_id := str(spec.industry)
		var facility_name := str(spec.name)
		for rank in range(1, 5):
			var art_key := "procedural.facility.%s" % str(spec.kind)
			if str(spec.kind) == "warehouse" and rank == 1:
				art_key = "facility.orbital_warehouse.rank_1"
			var facility_payload := _facility_payload(str(spec.kind), industry_id, rank)
			var facility_effect_text := _facility_effect_text(str(spec.kind), facility_name, rank, facility_payload)
			_add_card(
				family_id, rank, "facility", industry_id, "dynamic_market_cash", int(FACILITY_CASH[rank]), _assets(industry_id, int(FACILITY_ASSET_COST[rank])),
				"build_upgrade_or_repair_facility", "region_unique_facility_slot",
				facility_payload,
				{
					"name": facility_name,
					"type": "公共设施牌",
					"industry": _industry_name(industry_id),
					"cost": _paid_cost_text(int(FACILITY_CASH[rank]), industry_id, int(FACILITY_ASSET_COST[rank])),
					"timing": "普通出牌窗口",
					"target": "一个可建设、发展中或废墟区域的%s唯一槽位" % facility_name,
					"short_effect": "空槽建造；高阶牌升级；同级或低阶牌修复。",
					"effect": facility_effect_text,
					"duration": "持续至区域共享生命归零",
					"visibility": "设施所有权、等级、能力和租金公开",
					"next_step": "选择目标区域与设施槽",
				},
				{"effect_review_status": "rent_rate_review_pending", "runtime_owner": "region_infrastructure_runtime_controller", "art_key": art_key, "balance_status": "provisional_flow_test"}
			)


func _facility_payload(facility_kind: String, industry_id: String, rank: int) -> Dictionary:
	var payload := {
		"facility_kind": facility_kind,
		"industry_id": "" if industry_id == "generic" else industry_id,
		"card_rank": rank,
		"operation_policy": "empty_build_higher_rank_upgrade_same_or_lower_repair",
		"allowed_region_states": ["active", "undeveloped", "ruined"],
		"shared_hp_profile": "equal_contribution_by_rank",
		"shared_hp_contribution": int(FACILITY_HP_CONTRIBUTION[rank]),
		"rent_enabled": true,
		"rent_rate_profile": "pending_first_playtest_table",
	}
	match facility_kind:
		"factory":
			payload["production_capacity_units_per_minute"] = int(FACTORY_MARKET_CAPACITY[rank])
		"market":
			payload["demand_capacity_units_per_minute"] = int(FACTORY_MARKET_CAPACITY[rank])
		"road", "port", "spaceport":
			payload["throughput_units_per_minute"] = int(TRANSIT_THROUGHPUT[rank])
			payload["speed_multiplier"] = float(TRANSIT_SPEED_MULTIPLIER[rank])
		"warehouse":
			payload["storage_capacity_units"] = int(WAREHOUSE_STORAGE[rank])
			payload["inbound_throughput_units_per_minute"] = int(TRANSIT_THROUGHPUT[rank])
			payload["outbound_throughput_units_per_minute"] = int(TRANSIT_THROUGHPUT[rank])
	return payload


func _facility_effect_text(facility_kind: String, facility_name: String, rank: int, payload: Dictionary) -> String:
	var capability := ""
	match facility_kind:
		"factory":
			capability = "基础生产容量 %d 单位/分钟" % int(payload.get("production_capacity_units_per_minute", 0))
		"market":
			capability = "基础需求容量 %d 单位/分钟" % int(payload.get("demand_capacity_units_per_minute", 0))
		"road", "port", "spaceport":
			capability = "吞吐 %d 单位/分钟，速度倍率 %.2f" % [int(payload.get("throughput_units_per_minute", 0)), float(payload.get("speed_multiplier", 1.0))]
		"warehouse":
			capability = "库存上限 %d，入库/出库吞吐各 %d 单位/分钟" % [int(payload.get("storage_capacity_units", 0)), int(payload.get("inbound_throughput_units_per_minute", 0))]
	return "在空槽建造 %s 级%s，提供%s。其他玩家实际使用时向所有者付租；牌面等级高于现有设施时升级至牌面等级，同级或更低等级牌则修复区域共享生命池。废墟区域允许通过本次建造恢复。" % [RANK_LABELS[rank], facility_name, capability]


func _build_supply_demand_cards() -> void:
	var specs: Array[Dictionary] = [
		{"family": "supply_demand.remote_sea_order", "name": "远洋采购令", "industry": "shipping", "effect": "global_order_budget", "target_kind": "global_matching_goods", "target": "全图符合条件的商品", "unit_key": "budget_units", "route": "sea", "distance": "remote_gt_2", "verb": "额外消费", "art": "supply_demand.remote_sea_order.rank_1"},
		{"family": "supply_demand.near_land_supply", "name": "近地供货潮", "industry": "industry", "effect": "global_supply_spawn", "target_kind": "global_matching_factories", "target": "全图符合条件的工厂", "unit_key": "spawn_units", "route": "land", "distance": "near_lte_2", "verb": "产生", "art": "supply_demand.near_land_supply.rank_1"},
	]
	for spec in specs:
		for rank in range(1, 5):
			var units := 20 * int(pow(2, rank - 1))
			var payload := {
				str(spec.unit_key): units,
				"required_route_tag": str(spec.route),
				"route_tag_match_mode": "any_segment_in_multimodal_route",
				"distance_rule": str(spec.distance),
				"allocation_basis": "matching_product_gdp_share_30s",
				"requires_positive_owner_matching_product_gdp": true,
				"uses_real_route_capacity": true,
				"requires_real_market_or_factory_nodes": true,
			}
			if str(spec.effect) == "global_order_budget":
				payload["may_exceed_persistent_demand"] = true
				payload["requires_real_market_node"] = true
			else:
				payload["creates_one_time_physical_goods"] = true
				payload["is_permanent_installation"] = false
				payload["requires_legal_production_factory"] = true
			_add_card(
				str(spec.family), rank, "supply_demand", str(spec.industry), "dynamic_market_cash", int(SUPPLY_CASH[rank]), _assets(str(spec.industry), int(SUPPLY_ASSET_COST[rank])),
				str(spec.effect), str(spec.target_kind), payload,
				{
					"name": str(spec.name),
					"type": "条件式供需牌",
					"industry": "多色",
					"cost": _paid_cost_text(int(SUPPLY_CASH[rank]), str(spec.industry), int(SUPPLY_ASSET_COST[rank])),
					"timing": "普通出牌窗口",
					"target": str(spec.target),
					"short_effect": "%s %d 单位符合路线与距离条件的商品。" % [str(spec.verb), units],
					"effect": "%s %d 单位一次性预算，只匹配指定运输方式和距离条件；按匹配商品最近 30 秒 GDP 份额分配，并通过真实节点、合法路线和容量结算。" % [str(spec.verb), units],
					"duration": "一次性结算",
					"visibility": "牌面条件与结算回执公开",
					"next_step": "确认提交并查看匹配预览",
				},
				{"effect_review_status": "rule_confirmed", "runtime_owner": "global_supply_demand_runtime_service", "art_key": str(spec.art) if rank == 1 else "procedural.supply_demand", "balance_status": "provisional_flow_test"}
			)


func _build_monster_cards() -> void:
	var specs: Array[Dictionary] = [
		{"slug": "spore_tide_emperor", "name": "孢雾海皇", "industry": "life"},
		{"slug": "sand_armor_rover", "name": "砂铠陆行兽", "industry": "industry"},
		{"slug": "meteor_sentinel", "name": "流星哨兵", "industry": "energy"},
		{"slug": "prism_blade_colossus", "name": "棱刃重甲", "industry": "commerce"},
		{"slug": "oasis_repairer", "name": "绿洲修复体", "industry": "life"},
		{"slug": "flame_ring_proto_star", "name": "焰环幼星", "industry": "energy"},
		{"slug": "blue_edge_knight", "name": "蓝锋骑士", "industry": "technology"},
		{"slug": "mirror_hunter", "name": "镜像猎兵", "industry": "technology"},
	]
	for spec in specs:
		for rank in range(1, 5):
			var family_id := "unit.monster.%s" % str(spec.slug)
			var art_key := family_id + ".rank_%d" % rank if str(spec.slug) == "spore_tide_emperor" and rank == 1 else "monster_body.%s" % str(spec.slug)
			_add_card(
				family_id, rank, "monster", str(spec.industry), "starter_or_dynamic_market_cash", int(UNIT_CASH[rank]), _assets(str(spec.industry), int(UNIT_ASSET_COST[rank])),
				"deploy_or_upgrade_monster", "region_or_existing_same_family_monster",
				{"monster_family_id": str(spec.slug), "card_rank": rank, "same_name_upgrade_extend_seconds": 60, "refresh_total_presence_time": false, "presence_time_policy": "add_to_remaining_time", "heal_to_full_on_upgrade": true, "rank4_repeat_behavior": "heal_to_full_and_extend_60_seconds", "upgrade_target_same_family_any_owner": true, "ownership_transfer_on_upgrade": false, "bound_skill_recipient": "existing_monster_owner", "starter_conflict_policy": "private_reselect", "upgrade_respects_target_owner_rank_cap": true, "unit_profile_owns_stats": true},
				{
					"name": str(spec.name),
					"type": "怪兽单位牌",
					"industry": _industry_name(str(spec.industry)),
					"cost": _paid_cost_text(int(UNIT_CASH[rank]), str(spec.industry), int(UNIT_ASSET_COST[rank])),
					"timing": "普通出牌窗口",
					"target": "合法部署区域或场上同名怪兽",
					"short_effect": "部署%s；或强化场上同名怪兽，不改变归属。" % str(spec.name),
					"effect": "在合法区域部署 %s 级%s；若场上已有同名怪兽，则强化它并额外延长 60 秒，不改变归属，绑定技能仍归现有主人。起始召唤冲突时私下重选。" % [RANK_LABELS[rank], str(spec.name)],
					"duration": "按单位档案持续；同名升级额外增加 60 秒",
					"visibility": "单位归属、等级、位置和公开行为规则公开",
					"next_step": "选择合法区域或场上同名怪兽",
				},
				{"effect_review_status": "unit_profile_review_pending", "runtime_owner": "monster_runtime_controller", "art_key": art_key, "balance_status": "provisional_flow_test"}
			)


func _build_military_cards() -> void:
	var specs: Array[Dictionary] = [
		{"slug": "planetary_defense_force", "name": "行星防卫军", "industry": "industry"},
		{"slug": "air_superiority_fighter", "name": "制空战斗机", "industry": "industry"},
		{"slug": "orbital_bomber", "name": "轨道轰炸机", "industry": "energy"},
		{"slug": "heavy_tank", "name": "重装坦克", "industry": "industry"},
		{"slug": "missile_emplacement", "name": "导弹阵地", "industry": "technology"},
		{"slug": "submarine_fleet", "name": "潜航舰队", "industry": "technology"},
		{"slug": "star_ocean_battleship", "name": "星海战舰", "industry": "energy"},
	]
	for spec in specs:
		for rank in range(1, 5):
			var family_id := "unit.military.%s" % str(spec.slug)
			_add_card(
				family_id, rank, "military", str(spec.industry), "dynamic_market_cash", int(UNIT_CASH[rank]), _assets(str(spec.industry), int(UNIT_ASSET_COST[rank])),
				"deploy_or_upgrade_military", "region_or_owned_same_family_military",
				{"military_family_id": str(spec.slug), "card_rank": rank, "unit_profile_owns_stats": true, "region_damage_requires_explicit_unit_action": true, "bound_actions_excluded_from_hand_limit": true, "bound_actions_require_assets": true, "bound_action_profile_review_pending": true},
				{
					"name": str(spec.name),
					"type": "军队单位牌",
					"industry": _industry_name(str(spec.industry)),
					"cost": _paid_cost_text(int(UNIT_CASH[rank]), str(spec.industry), int(UNIT_ASSET_COST[rank])),
					"timing": "普通出牌窗口",
					"target": "单位档案允许的合法部署区域",
					"short_effect": "部署或升级 %s 级%s。" % [RANK_LABELS[rank], str(spec.name)],
					"effect": "在合法区域部署 %s 级%s；其移动、攻击、地形和区域伤害权限由公开单位档案决定。" % [RANK_LABELS[rank], str(spec.name)],
					"duration": "持续至单位被摧毁或撤离",
					"visibility": "单位归属、等级、位置和公开数值公开",
					"next_step": "选择合法部署区域",
				},
				{"effect_review_status": "unit_profile_review_pending", "runtime_owner": "military_runtime_controller", "art_key": "procedural.military.%s" % str(spec.slug), "balance_status": "provisional_flow_test"}
			)


func _build_interaction_cards() -> void:
	for rank in range(1, 5):
		var dismantle_payload := {"hand_discard_count": [0, 1, 1, 1, 2][rank], "hand_lock_seconds": [0, 0, 10, 18, 20][rank], "target_cash_penalty": [0, 0, 0, 80, 120][rank], "direct_player_interaction": true, "counterable": true}
		_add_interaction_card("interaction.starlink_dismantle", "星链拆解", rank, "player_hand_disrupt", "opponent_discardable_hand", dismantle_payload, "拆除对手的普通手牌，并随等级增加封锁压力。", "game_icon_breaking_chain", "legacy_effect_review_pending")
		var traction_payload := {"hand_steal_count": [0, 1, 1, 1, 2][rank], "hand_lock_seconds": [0, 0, 8, 15, 18][rank], "steal_fail_cash": [0, 60, 90, 140, 220][rank], "direct_player_interaction": true, "counterable": true}
		_add_interaction_card("interaction.shadow_warehouse_traction", "影仓牵引", rank, "player_hand_steal", "opponent_discardable_hand", traction_payload, "牵取对手的普通手牌；无法接收时按牌面执行失败补偿。", "game_icon_robber_hand", "legacy_effect_review_pending")
		var veto_payload := {"counter_strength": rank, "response_depth": 1, "counter_window_seconds": 5.0, "refund_cash": [0, 0, 40, 90, 160][rank], "private_trace_count": [0, 0, 0, 1, 2][rank], "target_scope": "direct_player_interaction"}
		_add_interaction_card("interaction.phase_veto", "相位否决", rank, "card_counter", "incoming_direct_player_interaction", veto_payload, "反制一张直接针对你的玩家互动牌；本牌不能再次被反制。", "interaction.phase_veto.rank_1" if rank == 1 else "game_icon_cancel", "rule_confirmed")


func _build_organization_cards() -> void:
	_build_asset_conversion_organization()
	_build_action_bandwidth_organization()
	_build_hand_capacity_organization()
	_build_monster_binding_organization()
	_build_military_command_organization()


func _build_asset_conversion_organization() -> void:
	var purchase_cash := [0, 6, 10, 15, 21]
	var asset_cost := [0, 3, 5, 8, 12]
	var gdp_min := [0, 0, 30, 60, 100]
	var positive_colors := [0, 1, 2, 2, 3]
	var bonus_bp := [0, 500, 1000, 1500, 2000]
	var cap_milli_per_second := [0, 50, 100, 150, 200]
	for rank in range(1, 5):
		var payload := _organization_base_payload("organization.starport_clearinghouse", "asset_conversion", rank, int(gdp_min[rank]), int(positive_colors[rank]), {
			"asset_conversion_bonus_bp": int(bonus_bp[rank]),
			"asset_conversion_bonus_cap_milli_per_second": int(cap_milli_per_second[rank]),
			"scope": "same_color_gdp_only",
			"anti_snowball_cap": {"kind": "asset_conversion_bonus_milli_per_second", "value": int(cap_milli_per_second[rank])},
		})
		_add_organization_card(
			"organization.starport_clearinghouse", "星港清算所", rank, "generic", int(purchase_cash[rank]), int(asset_cost[rank]), payload,
			"同色 GDP 转化资产的效率 +%d%%，每秒额外转化最多 %.2f 资产。" % [int(bonus_bp[rank]) / 100, float(cap_milli_per_second[rank]) / 1000.0],
			"procedural.organization.asset_conversion"
		)


func _build_action_bandwidth_organization() -> void:
	var purchase_cash := [0, 7, 11, 16, 22]
	var asset_cost := [0, 4, 7, 11, 16]
	var gdp_min := [0, 0, 36, 72, 108]
	var positive_colors := [0, 1, 2, 2, 3]
	var surcharge := [0, 4, 3, 2, 1]
	for rank in range(1, 5):
		var payload := _organization_base_payload("organization.quantum_agenda_network", "action_bandwidth", rank, int(gdp_min[rank]), int(positive_colors[rank]), {
			"ordinary_submission_bonus": 1,
			"extra_submission_asset_surcharge": int(surcharge[rank]),
			"ordinary_submission_hard_cap": 3,
			"burst_window_period": 3 if rank == 4 else 0,
			"burst_submission_bonus": 1 if rank == 4 else 0,
			"burst_submission_surcharge": 4 if rank == 4 else 0,
			"window_start_snapshot_required": true,
			"response_cards_ignore_ordinary_submission_limit": true,
			"public_same_source_aura": "organization_action_bandwidth",
			"anti_snowball_cap": {"kind": "ordinary_submissions_per_window", "value": 3},
		})
		var effect_text := "每个出牌窗口可多提交 1 张普通牌；额外牌支付 %d 通用资产，窗口上限 3 张。" % int(surcharge[rank])
		if rank == 4:
			effect_text += "每第 3 个窗口还可再提交 1 张，额外支付 4 通用资产。"
		_add_organization_card(
			"organization.quantum_agenda_network", "量子议程网", rank, "generic", int(purchase_cash[rank]), int(asset_cost[rank]), payload,
			effect_text, "procedural.organization.action_bandwidth"
		)


func _build_hand_capacity_organization() -> void:
	var purchase_cash := [0, 5, 8, 12, 17]
	var asset_cost := [0, 2, 4, 6, 9]
	var gdp_min := [0, 0, 24, 54, 90]
	var positive_colors := [0, 1, 1, 2, 3]
	var hand_limit := [0, 6, 7, 8, 9]
	for rank in range(1, 5):
		var payload := _organization_base_payload("organization.deep_space_archive", "hand_capacity", rank, int(gdp_min[rank]), int(positive_colors[rank]), {
			"base_ordinary_hand_limit": 5,
			"ordinary_hand_limit": int(hand_limit[rank]),
			"ordinary_hand_limit_bonus": int(hand_limit[rank]) - 5,
			"absolute_hand_limit_cap": 9,
			"scope": "ordinary_hand_only",
			"anti_snowball_cap": {"kind": "ordinary_hand_limit", "value": 9},
		})
		_add_organization_card(
			"organization.deep_space_archive", "深空档案库", rank, "technology", int(purchase_cash[rank]), int(asset_cost[rank]), payload,
			"普通手牌上限提高到 %d 张；绑定技能牌不计入此上限。" % int(hand_limit[rank]),
			"procedural.organization.hand_capacity"
		)


func _build_monster_binding_organization() -> void:
	var purchase_cash := [0, 6, 10, 15, 21]
	var asset_cost := [0, 3, 5, 8, 12]
	var gdp_min := [0, 0, 42, 84, 132]
	var positive_colors := [0, 1, 2, 3, 3]
	var count_limit := [0, 1, 1, 2, 2]
	var primary_rank_limit := [0, 3, 4, 4, 4]
	var secondary_rank_limit := [0, 0, 0, 2, 4]
	for rank in range(1, 5):
		var payload := _organization_base_payload("organization.monster_liaison_charter", "monster_binding", rank, int(gdp_min[rank]), int(positive_colors[rank]), {
			"base_controlled_monster_count_limit": 1,
			"base_primary_monster_rank_limit": 2,
			"controlled_monster_count_limit": int(count_limit[rank]),
			"primary_monster_rank_limit": int(primary_rank_limit[rank]),
			"secondary_monster_rank_limit": int(secondary_rank_limit[rank]),
			"foreign_same_name_upgrade_must_respect_target_owner_limits": true,
			"foreign_upgrade_rank_limit_source": "target_current_owner_organization_snapshot",
			"foreign_upgrade_does_not_transfer_control": true,
			"anti_snowball_cap": {"kind": "controlled_monster_count", "value": 2},
		})
		_add_organization_card(
			"organization.monster_liaison_charter", "巨兽联络章程", rank, "life", int(purchase_cash[rank]), int(asset_cost[rank]), payload,
			_unit_control_effect_text("怪兽", int(count_limit[rank]), int(primary_rank_limit[rank]), int(secondary_rank_limit[rank])),
			"procedural.organization.monster_binding"
		)


func _build_military_command_organization() -> void:
	var purchase_cash := [0, 6, 10, 15, 21]
	var asset_cost := [0, 3, 5, 8, 12]
	var gdp_min := [0, 0, 42, 84, 132]
	var positive_colors := [0, 1, 2, 3, 3]
	var count_limit := [0, 1, 1, 2, 2]
	var primary_rank_limit := [0, 3, 4, 4, 4]
	var secondary_rank_limit := [0, 0, 0, 2, 4]
	for rank in range(1, 5):
		var payload := _organization_base_payload("organization.stellar_command_directorate", "military_command", rank, int(gdp_min[rank]), int(positive_colors[rank]), {
			"base_controlled_military_count_limit": 1,
			"base_primary_military_rank_limit": 2,
			"controlled_military_count_limit": int(count_limit[rank]),
			"primary_military_rank_limit": int(primary_rank_limit[rank]),
			"secondary_military_rank_limit": int(secondary_rank_limit[rank]),
			"anti_snowball_cap": {"kind": "controlled_military_count", "value": 2},
		})
		_add_organization_card(
			"organization.stellar_command_directorate", "星环统帅部", rank, "industry", int(purchase_cash[rank]), int(asset_cost[rank]), payload,
			_unit_control_effect_text("军队", int(count_limit[rank]), int(primary_rank_limit[rank]), int(secondary_rank_limit[rank])),
			"procedural.organization.military_command"
		)


func _organization_base_payload(family_id: String, axis: String, rank: int, required_gdp: int, required_colors: int, specific_fields: Dictionary) -> Dictionary:
	var payload := {
		"organization_axis": axis,
		"organization_family_id": family_id,
		"organization_rank": rank,
		"organization_slot_cost": 1,
		"organization_slot_limit": ORGANIZATION_SLOT_LIMIT,
		"install_policy": "upgrade_highest_rank_only",
		"stack_policy": "highest_rank_nonstacking",
		"replacement_requires_higher_rank": true,
		"equal_or_lower_rank_resolution": "reject_before_consume",
		"activation_window_offset": 1,
		"activation_snapshot_timing": "next_window_start",
		"persistence": "run",
		"required_own_gdp_min": required_gdp,
		"required_positive_gdp_color_count": required_colors,
		"public_clue_kind": "installed_organization_axis_aura",
		"counterplay_tags": _organization_counterplay_tags(axis),
		"direct_player_interaction": false,
		"counterable": false,
		"phase_veto_eligible": false,
		"ordinary_submission_cost": 1,
		"counts_as_normal_card_submission": true,
		"ai_effect_tags": ["self_engine", "organization", axis, "persistent_upgrade"],
	}
	for key in specific_fields.keys():
		payload[key] = specific_fields[key]
	return payload


func _add_organization_card(family_id: String, display_name: String, rank: int, industry_id: String, purchase_cash: int, asset_cost: int, payload: Dictionary, effect_text: String, art_key: String) -> void:
	_add_card(
		family_id, rank, "organization", industry_id, "dynamic_market_cash", purchase_cash, _assets(industry_id, asset_cost),
		"install_organization_upgrade", "self_organization_slot", payload,
		{
			"name": display_name,
			"type": "组织牌",
			"industry": _industry_name(industry_id),
			"cost": _paid_cost_text(purchase_cash, industry_id, asset_cost),
			"timing": "普通出牌窗口；次窗生效",
			"target": "你的一个组织槽",
			"short_effect": effect_text,
			"effect": effect_text + " 同家族仅最高阶生效。",
			"duration": "本局常驻；更高阶同家族牌替换",
			"visibility": "组织名称、等级与效果光环公开",
			"next_step": "选择一个组织槽并确认安装",
		},
		{"effect_review_status": "rule_confirmed", "runtime_owner": "organization_runtime_owner_pending", "art_key": art_key, "balance_status": "provisional_first_playtest"}
	)


func _unit_control_effect_text(unit_label: String, count_limit: int, primary_rank_limit: int, secondary_rank_limit: int) -> String:
	if count_limit <= 1:
		return "可控制 1 只%s，最高 %s 级。" % [unit_label, RANK_LABELS[primary_rank_limit]]
	return "可控制 2 只%s：主力最高 %s 级，副位最高 %s 级。" % [unit_label, RANK_LABELS[primary_rank_limit], RANK_LABELS[secondary_rank_limit]]


func _organization_counterplay_tags(axis: String) -> Array[String]:
	match axis:
		"asset_conversion":
			return ["gdp_color_denial", "conversion_rate_cap", "economic_disruption"]
		"action_bandwidth":
			return ["asset_surcharge_pressure", "gdp_gate_denial", "public_window_aura"]
		"hand_capacity":
			return ["hand_disruption", "purchase_denial", "gdp_gate_denial"]
		"monster_binding":
			return ["monster_damage", "monster_duration_expiry", "gdp_gate_denial"]
		"military_command":
			return ["unit_destruction", "terrain_denial", "gdp_gate_denial"]
	return ["economic_disruption", "gdp_gate_denial"]


func _add_interaction_card(family_id: String, display_name: String, rank: int, effect_kind: String, target_kind: String, payload: Dictionary, effect_text: String, art_key: String, review_status: String) -> void:
	var detailed_effect := _interaction_effect_text(display_name, rank, payload, effect_text)
	_add_card(
		family_id, rank, "interaction", "technology", "dynamic_market_cash", int(INTERACTION_CASH[rank]), _assets("technology", int(INTERACTION_ASSET_COST[rank])), effect_kind, target_kind, payload,
		{
			"name": display_name,
			"type": "玩家互动与反制牌",
			"industry": "科技",
			"cost": _paid_cost_text(int(INTERACTION_CASH[rank]), "technology", int(INTERACTION_ASSET_COST[rank])),
			"timing": "普通出牌窗口" if effect_kind != "card_counter" else "合法响应窗口",
			"target": "一名对手及其可作用手牌" if effect_kind != "card_counter" else "一张直接针对你的玩家互动牌",
			"short_effect": detailed_effect,
			"effect": detailed_effect,
			"duration": "立即结算",
			"visibility": "目标和结果公开；秘密牌名只对合法查看者显示",
			"next_step": "选择目标并确认" if effect_kind != "card_counter" else "在响应窗口选择目标互动牌",
		},
		{"effect_review_status": review_status, "runtime_owner": "player_hand_interaction_runtime_service" if effect_kind != "card_counter" else "card_counter_runtime_service", "art_key": art_key, "balance_status": "provisional_flow_test", "legacy_v04_family": display_name}
	)


func _interaction_effect_text(display_name: String, _rank: int, payload: Dictionary, fallback: String) -> String:
	match display_name:
		"星链拆解":
			var text := "使目标随机弃置 %d 张可弃普通手牌" % int(payload.get("hand_discard_count", 0))
			if int(payload.get("hand_lock_seconds", 0)) > 0:
				text += "，并随机封锁 1 张 %d 秒" % int(payload.get("hand_lock_seconds", 0))
			if int(payload.get("target_cash_penalty", 0)) > 0:
				text += "，再支付 %d 现金重组成本" % int(payload.get("target_cash_penalty", 0))
			return text + "。"
		"影仓牵引":
			var text := "从目标随机牵取 %d 张可弃普通手牌" % int(payload.get("hand_steal_count", 0))
			if int(payload.get("hand_lock_seconds", 0)) > 0:
				text += "，并随机封锁目标 1 张牌 %d 秒" % int(payload.get("hand_lock_seconds", 0))
			text += "；接收失败时按牌面补偿 %d 现金。" % int(payload.get("steal_fail_cash", 0))
			return text
		"相位否决":
			var text := "反制一张直接针对你的玩家互动牌；本牌不能再次被反制"
			if int(payload.get("refund_cash", 0)) > 0:
				text += "，成功后返还 %d 现金" % int(payload.get("refund_cash", 0))
			if int(payload.get("private_trace_count", 0)) > 0:
				text += "，并获得 %d 条私人来源线索" % int(payload.get("private_trace_count", 0))
			return text + "。"
	return fallback


func _add_card(family_id: String, rank: int, category_id: String, industry_id: String, acquisition_kind: String, purchase_cash: int, asset_cost: Dictionary, effect_kind: String, target_kind: String, effect_payload: Dictionary, player_fields: Dictionary, developer_fields: Dictionary) -> void:
	var player := player_fields.duplicate(true)
	player["rank"] = str(RANK_LABELS[rank])
	player["keywords"] = _keywords(category_id, industry_id, effect_payload)
	var machine := {
		"card_id": "%s.rank_%d" % [family_id, rank],
		"family_id": family_id,
		"rank": rank,
		"category_id": category_id,
		"industry_id": industry_id,
		"acquisition_kind": acquisition_kind,
		"purchase_cash": purchase_cash,
		"asset_cost": asset_cost,
		"counts_toward_hand_limit": true,
		"merge_policy": "manual_same_family_same_rank_or_auto_once_when_full",
		"maximum_rank": 4,
		"effect_kind": effect_kind,
		"target_kind": target_kind,
		"effect_payload": effect_payload.duplicate(true),
		"available_for_acquisition": true,
		"resolution_policy": "reject_before_consume_if_unowned",
	}
	var developer := developer_fields.duplicate(true)
	developer["implementation_status"] = "catalog_ready_runtime_wiring_pending"
	developer["source_rule"] = "res://docs/tabletop_rulebook_v06.md"
	_cards.append({"machine": machine, "player": player, "developer": developer})


func _assets(industry_id: String, amount: int) -> Dictionary:
	var result := {"life": 0, "energy": 0, "industry": 0, "technology": 0, "commerce": 0, "shipping": 0, "generic": 0}
	var target := industry_id if result.has(industry_id) else "generic"
	result[target] = amount
	return result


func _paid_cost_text(cash: int, industry_id: String, assets: int) -> String:
	if assets <= 0:
		return "现金 %d；打出免费" % cash
	return "现金 %d；打出 %d %s资产" % [cash, assets, _industry_name(industry_id)]


func _industry_name(industry_id: String) -> String:
	return str(INDUSTRY_NAMES.get(industry_id, "通用"))


func _keywords(category_id: String, industry_id: String, effect_payload: Dictionary = {}) -> Array[Dictionary]:
	var accent := str(INDUSTRY_ACCENTS.get(industry_id, INDUSTRY_ACCENTS.generic))
	var result: Array[Dictionary] = [
		{"text": _industry_name(industry_id), "tooltip": "这张牌的产业归属与资产颜色。", "accent": accent},
	]
	match category_id:
		"commodity":
			result.append({"text": "免费", "tooltip": "领取和打出均不支付现金或资产。", "accent": "#fde68a"})
			result.append({"text": "永久安装", "tooltip": "安装量持续存在，直至设施被摧毁。", "accent": "#67e8f9"})
		"facility":
			result.append({"text": "唯一设施", "tooltip": "每个区域的对应设施槽位唯一。", "accent": "#94a3b8"})
			result.append({"text": "升级/修复", "tooltip": "已有同类设施时升级；无法升级时修复共享生命。", "accent": "#86efac"})
		"supply_demand":
			result.append({"text": "全局匹配", "tooltip": "按牌面标签匹配全图商品。", "accent": "#c084fc"})
			result.append({"text": "GDP 分配", "tooltip": "按匹配商品近期 GDP 份额分配。", "accent": "#fde68a"})
		"monster":
			result.append({"text": "怪兽", "tooltip": "怪兽按照公开行为规则自动行动。", "accent": "#fb7185"})
			result.append({"text": "部署/升级", "tooltip": "空位部署，同名单位升级并延长在场时间。", "accent": "#f97316"})
		"military":
			result.append({"text": "军队", "tooltip": "单位能力由公开档案和绑定动作决定。", "accent": "#94a3b8"})
			result.append({"text": "部署/升级", "tooltip": "在合法区域部署或升级同名单位。", "accent": "#f97316"})
		"interaction":
			result.append({"text": "直接互动", "tooltip": "直接针对玩家的效果可以被相位否决响应。", "accent": "#c084fc"})
			result.append({"text": "可反制", "tooltip": "目标玩家可以在合法窗口响应。", "accent": "#38bdf8"})
		"organization":
			result.append({"text": "组织", "tooltip": "强化自己的长期经营能力，不直接作用于其他玩家。", "accent": "#fbbf24"})
			result.append({"text": "常驻", "tooltip": "安装后持续到本局结束；同家族仅最高阶生效。", "accent": "#a78bfa"})
			result.append({"text": "次窗生效", "tooltip": "当前窗口完成安装，下一个共同出牌窗口开始生效。", "accent": "#67e8f9"})
			result.append({"text": _organization_axis_label(str(effect_payload.get("organization_axis", ""))), "tooltip": "这张组织牌强化的经营轴。", "accent": "#f59e0b"})
	return result


func _organization_axis_label(axis: String) -> String:
	match axis:
		"asset_conversion":
			return "资产转化"
		"action_bandwidth":
			return "行动带宽"
		"hand_capacity":
			return "手牌容量"
		"monster_binding":
			return "怪兽联络"
		"military_command":
			return "军队统帅"
	return "组织强化"


func _log(event_name: String, code: String, fields: Dictionary) -> void:
	var parts: Array[String] = ["CARD_CATALOG_V06_BUILDER", "event=%s" % event_name, "code=%s" % code]
	var keys := fields.keys()
	keys.sort()
	for key in keys:
		parts.append("%s=%s" % [str(key), str(fields.get(key)).replace("|", "/").replace("\n", " ")])
	print("|".join(parts))
