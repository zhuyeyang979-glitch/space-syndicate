@tool
extends Node
class_name GameplayBalanceDiagnosticsWorldBridge

const MonsterCatalogV06 := preload("res://scripts/runtime/monster_catalog_v06.gd")

var _world: Node
var _table_selection_state: TableSelectionState
var _world_session_state: WorldSessionState
var _card_effect_router: CardEffectRuntimeRouter
var _card_catalog: CardRuntimeCatalogService
var _role_catalog: RoleCatalogRuntimeService
var _district_supply_query: DistrictSupplyRuntimeQueryPort
var _build_count := 0


func bind_world(world: Node) -> void:
	_world = world


func set_table_selection_state(state: TableSelectionState) -> void:
	_table_selection_state = state


func set_world_session_state(state: WorldSessionState) -> void:
	_world_session_state = state


func set_card_effect_router(router: CardEffectRuntimeRouter) -> void:
	_card_effect_router = router


func set_card_catalog_service(card_catalog: CardRuntimeCatalogService) -> void:
	_card_catalog = card_catalog


func set_role_catalog(role_catalog: RoleCatalogRuntimeService) -> void:
	_role_catalog = role_catalog


func set_district_supply_runtime_query_port(query: DistrictSupplyRuntimeQueryPort) -> void:
	_district_supply_query = query


func world_session_state() -> WorldSessionState:
	return _world_session_state


func table_selection_state() -> TableSelectionState:
	return _table_selection_state


func build_world_snapshot(sample_only := false) -> Dictionary:
	_build_count += 1
	if _world == null or not is_instance_valid(_world):
		return {"world_ready": false, "reason": "world_missing"}
	var coordinator := _coordinator()
	if coordinator == null:
		return {"world_ready": false, "reason": "coordinator_missing"}
	if _table_selection_state == null:
		return {"world_ready": false, "reason": "table_selection_state_missing"}
	if _card_catalog == null or not is_instance_valid(_card_catalog):
		return {"world_ready": false, "reason": "card_catalog_missing"}
	var selected_player: int = _table_selection_state.selected_player
	var cards := _card_facts(coordinator, selected_player, sample_only)
	var snapshot := {
		"world_ready": true,
		"sample_only": sample_only,
		"selected_player": selected_player,
		"selected_district": _table_selection_state.selected_district,
		"cards": cards,
		"roles": _role_facts(),
		"products": _product_facts(),
		"monsters": _monster_facts(coordinator),
		"districts": _district_facts(selected_player),
		"run_products": _world_array_call(&"_current_run_product_names"),
		"run_pool": _world_array_call(&"_current_run_card_pool"),
		"monster_cards": _world_array_call(&"_monster_card_names", [1]),
		"allowed_monster_cards": _world_array_call(&"_run_allowed_monster_card_names", [1]),
		"ai_primary_route_counts": _ai_primary_route_counts(),
		"ai_route_diversity": _ai_route_diversity(),
		"region_rows": _region_rows(),
		"counter_card_exists": bool(coordinator.call("card_exists", "相位否决1")),
		"economy_legacy_turn_seconds": 30.0,
		"futures_terms": _futures_terms(),
		"model_version": "runtime_balance_v1",
	}
	return _sanitize(snapshot) as Dictionary


func debug_snapshot() -> Dictionary:
	return {
		"bridge_ready": _world != null and is_instance_valid(_world),
		"build_count": _build_count,
		"fact_collection_authority": true,
		"diagnostic_authority": false,
		"formula_authority": false,
		"world_mutation_authority": false,
		"privacy_boundary": "public_and_developer_safe_facts_only",
		"world_session_state_ready": _world_session_state != null,
		"card_catalog_ready": _card_catalog != null and is_instance_valid(_card_catalog),
		"district_supply_query_ready": _district_supply_query != null,
	}


func _card_facts(coordinator: Node, selected_player: int, sample_only: bool) -> Array:
	var card_ids: Array = coordinator.call("card_catalog_ordered_ids")
	for monster_card_variant in _world_array_call(&"_monster_card_names", [1]):
		var monster_card_id := str(monster_card_variant)
		if monster_card_id != "" and not card_ids.has(monster_card_id):
			card_ids.append(monster_card_id)
	if sample_only:
		card_ids = _sample_card_ids(card_ids)
	var run_pool := _world_array_call(&"_current_run_card_pool")
	var result: Array = []
	for card_variant in card_ids:
		var card_id := str(card_variant)
		if card_id == "" or not bool(coordinator.call("card_exists", card_id)):
			continue
		var skill := _world_dictionary_call(&"_make_skill", [card_id])
		if skill.is_empty():
			skill = coordinator.call("card_definition", card_id)
		var requirement := _world_dictionary_call(&"_card_play_requirement_snapshot", [selected_player, skill])
		var target := _world_dictionary_call(&"_card_play_target_snapshot", [skill])
		var chip_texts: Array = []
		var chip_variants: Array = _world_array_call(&"_card_presentation_array", [skill, "chips", card_id, selected_player, _table_selection_state.selected_district])
		for chip_variant in chip_variants:
			if chip_variant is Dictionary:
				chip_texts.append(str((chip_variant as Dictionary).get("text", "")))
		result.append({
			"card_id": card_id,
			"card_name": card_id,
			"family": str(coordinator.call("card_family_id", card_id)),
			"rank": int(coordinator.call("card_rank", card_id)),
			"skill": skill,
			"authored_skill": coordinator.call("card_authored_catalog_definition", card_id),
			"price": int(_world.call("_card_price", card_id)) if _world.has_method("_card_price") else 0,
			"route_label": _world_string_call(&"_card_presentation_text", [skill, "strategy_route_label", card_id]),
			"use_case": _world_string_call(&"_card_presentation_text", [skill, "use_case", card_id]),
			"quick_effect": _world_string_call(&"_card_presentation_text", [skill, "quick_effect_compact", card_id]),
			"art_stats": _world_string_call(&"_card_presentation_text", [skill, "art_stats", card_id]),
			"chip_texts": chip_texts,
			"requirement": requirement,
			"target": target,
			"play_product": _world_string_call(&"_skill_play_product", [skill, selected_player]),
			"resolution_handler": _card_effect_router != null and _card_effect_router.supports_skill(skill),
			"in_run_pool": run_pool.has(card_id),
		})
	return result


func _role_facts() -> Array:
	var roles: Array = []
	if _role_catalog == null:
		return roles
	for role_index in range(_role_catalog.role_count()):
		var role := _role_catalog.definition_at(role_index)
		role["role_index"] = role_index
		roles.append(role)
	return roles


func _product_facts() -> Array:
	var products: Array = []
	for product_variant in ProductMarketRuntimeController.PRODUCT_CATALOG:
		var product_name := str(product_variant)
		var profile := _world_dictionary_call(&"_product_profile", [product_name])
		var market := _world_dictionary_call(&"_product_market_entry_snapshot", [product_name])
		products.append({
			"name": product_name,
			"profile": profile,
			"market": market,
			"primary_strategy": _world_dictionary_call(&"_product_primary_strategy_entry", [product_name]),
			"related_card_count": _card_catalog.product_related_card_count(product_name),
			"monster_focus_count": int(_world.call("_product_monster_focus_count", product_name)) if _world.has_method("_product_monster_focus_count") else 0,
			"profile_complete": bool(_world.call("_product_profile_has_required_fields", product_name)) if _world.has_method("_product_profile_has_required_fields") else false,
		})
	return products


func _monster_facts(coordinator: Node) -> Array:
	var result: Array = []
	var catalog_count := int(_world.call("_catalog_size")) if _world.has_method("_catalog_size") else 0
	var monster_controller := _monster_controller()
	for catalog_index in range(catalog_count):
		var entry := _world_dictionary_call(&"_catalog_entry", [catalog_index])
		var actions := _world_array_call(&"_catalog_actions", [catalog_index])
		var action_role_tags: Array = []
		for action_variant in actions:
			var action: Dictionary = action_variant if action_variant is Dictionary else {}
			var tags: Array = monster_controller.call("_monster_action_role_tags", action) if monster_controller != null and monster_controller.has_method("_monster_action_role_tags") else []
			action_role_tags.append(tags)
		var monster_name := str(entry.get("name", "怪兽%d" % catalog_index))
		var bound_skill_counts: Array = []
		var bound_skill_missing: Array = []
		for rank in range(1, 5):
			var monster_card_id := _world_string_call(&"_monster_card_name", [catalog_index, rank])
			var monster_card := coordinator.call("card_definition", monster_card_id) as Dictionary
			bound_skill_counts.append(int(monster_card.get("fixed_skill_count", 0)))
			for action_index in range(mini(rank, actions.size())):
				var technique_id := _world_string_call(&"_monster_technique_card_name", [monster_name, action_index, rank])
				if technique_id != "" and not bool(coordinator.call("card_exists", technique_id)):
					bound_skill_missing.append(technique_id)
		var special_cards := _world_array_call(&"_catalog_special_cards", [catalog_index])
		var missing_special_cards: Array = []
		for special_variant in special_cards:
			var special_id := str(special_variant)
			if special_id != "" and not bool(coordinator.call("card_exists", special_id)):
				missing_special_cards.append(special_id)
		result.append({
			"index": catalog_index,
			"entry": entry,
			"actions": actions,
			"early_weights": _world_array_call(&"_catalog_action_weights_for_index", [catalog_index, false]),
			"escalated_weights": _world_array_call(&"_catalog_action_weights_for_index", [catalog_index, true]),
			"rank_iv_weights": _world_array_call(&"_catalog_ranked_action_weights_for_index", [catalog_index, false, 4]),
			"action_role_tags": action_role_tags,
			"special_cards": special_cards,
			"missing_special_cards": missing_special_cards,
			"bound_skill_counts": bound_skill_counts,
			"bound_skill_missing": bound_skill_missing,
			"has_art_profile": not MonsterCatalogV06.art_profile(monster_name).is_empty(),
		})
	return result


func _district_facts(selected_player: int) -> Array:
	var source: Array = _array_property("districts")
	var result: Array = []
	for district_index in range(source.size()):
		var district: Dictionary = source[district_index] if source[district_index] is Dictionary else {}
		var city := _world_dictionary_call(&"_district_city", [district_index])
		var public_rack_card_ids := _district_supply_query.public_card_ids_for_district(district_index) \
			if _district_supply_query != null else []
		var monster_cards: Array = []
		for card_variant in public_rack_card_ids:
			var card_name := _world_string_call(&"_canonical_card_supply_name", [str(card_variant)])
			if card_name == "":
				card_name = str(card_variant)
			if _world.has_method("_is_monster_card_name") and bool(_world.call("_is_monster_card_name", card_name)):
				monster_cards.append(card_name)
		result.append({
			"index": district_index,
			"name": str(district.get("name", "区域%d" % district_index)),
			"terrain": str(district.get("terrain", "land")),
			"destroyed": bool(district.get("destroyed", false)),
			"products": _array(district.get("products", [])),
			"demands": _array(district.get("demands", [])),
			"public_rack_card_ids": _canonical_card_choices(public_rack_card_ids),
			"monster_cards": monster_cards,
			"availability_kind": str(_district_supply_query.public_market_availability(district_index).get("availability_kind", "invalid")) \
				if _district_supply_query != null else "invalid",
			"city_active": bool(_world.call("_city_is_active", city)) if _world.has_method("_city_is_active") else not city.is_empty(),
			"city_products": _world_array_call(&"_city_product_names", [city]),
			"city_demands": _world_array_call(&"_city_demand_names", [city]),
		})
	return result


func _canonical_card_choices(value: Variant) -> Array:
	var result: Array = []
	for card_variant in _array(value):
		var card_id := _canonical_card_id(str(card_variant))
		if card_id != "":
			result.append(card_id)
	return result


func _canonical_card_id(card_id: String) -> String:
	var canonical_id := _world_string_call(&"_canonical_card_supply_name", [card_id])
	return canonical_id if canonical_id != "" else card_id


func _ai_primary_route_counts() -> Dictionary:
	var controller := _ai_controller()
	if controller == null or not controller.has_method("_ai_development_route_diversity_audit"):
		return {}
	var report: Variant = controller.call("_ai_development_route_diversity_audit")
	return _dictionary((report as Dictionary).get("primary_counts", {})) if report is Dictionary else {}


func _ai_route_diversity() -> Dictionary:
	var controller := _ai_controller()
	if controller == null or not controller.has_method("_ai_development_route_diversity_audit"):
		return {}
	var report: Variant = controller.call("_ai_development_route_diversity_audit")
	return _dictionary(report)


func _region_rows() -> Dictionary:
	var rows := {}
	for depth in range(1, 7):
		var profile := _world_dictionary_call(&"_roguelike_planet_profile", [depth])
		rows[depth] = {"min": int(profile.get("region_min", 6)), "max": int(profile.get("region_max", 9))}
	return rows


func _futures_terms() -> Array:
	var controller := _product_market_controller()
	if controller == null or not controller.has_method("all_futures_terms"):
		return []
	var value: Variant = controller.call("all_futures_terms")
	return _array(value)


func _sample_card_ids(all_ids: Array) -> Array:
	var wanted := ["移动1", "价格套利1", "垄断协议1", "商品看涨1", "商品看跌1", "港仓囤货1", "城市买涨1", "城市做空1", "星链拆解1", "影仓牵引1", "轨道齐射1", "相位否决1", "行星防卫军1", "轨道轰炸机1"]
	var result: Array = []
	for card_variant in wanted:
		if all_ids.has(card_variant):
			result.append(card_variant)
	if _world.has_method("_monster_card_name"):
		var monster_card := _world_string_call(&"_monster_card_name", [0, 1])
		if monster_card != "" and all_ids.has(monster_card):
			result.append(monster_card)
	return result


func _coordinator() -> Node:
	return _world.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") if _world != null else null


func _ai_controller() -> Node:
	var coordinator := _coordinator()
	return coordinator.get_node_or_null("AiRuntimeController") if coordinator != null else null


func _monster_controller() -> Node:
	var coordinator := _coordinator()
	return coordinator.get_node_or_null("MonsterRuntimeController") if coordinator != null else null


func _product_market_controller() -> Node:
	var coordinator := _coordinator()
	return coordinator.get_node_or_null("ProductMarketRuntimeController") if coordinator != null else null


func _array_property(property_name: StringName) -> Array:
	return _array(_world.get(property_name)) if _world != null else []


func _world_dictionary_call(method_name: StringName, arguments: Array = []) -> Dictionary:
	if _world == null or not _world.has_method(method_name):
		return {}
	return _dictionary(_world.callv(method_name, arguments))


func _world_array_call(method_name: StringName, arguments: Array = []) -> Array:
	if _world == null or not _world.has_method(method_name):
		return []
	return _array(_world.callv(method_name, arguments))


func _world_string_call(method_name: StringName, arguments: Array = []) -> String:
	if _world == null or not _world.has_method(method_name):
		return ""
	return str(_world.callv(method_name, arguments))


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if value is Array else []


func _sanitize(value: Variant) -> Variant:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return value
		TYPE_STRING_NAME:
			return str(value)
		TYPE_ARRAY:
			var output: Array = []
			for item in value as Array:
				var clean: Variant = _sanitize(item)
				if clean != null or item == null:
					output.append(clean)
			return output
		TYPE_DICTIONARY:
			var output := {}
			for key_variant in (value as Dictionary).keys():
				var clean_key: Variant = _sanitize(key_variant)
				var clean_value: Variant = _sanitize((value as Dictionary)[key_variant])
				if clean_key != null and (clean_value != null or (value as Dictionary)[key_variant] == null):
					output[clean_key] = clean_value
			return output
	if value is Color or value is Vector2 or value is Vector3:
		return str(value)
	return null
