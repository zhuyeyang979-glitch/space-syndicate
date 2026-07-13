extends RefCounted
class_name CityWorldFixtureFactory

const COORDINATOR_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator"


static func create_city(world: Node, player_index: int, district_index: int, source_label := "test fixture", preferred_direction := "production") -> Dictionary:
	if world == null or not is_instance_valid(world):
		return {"created": false, "reason": "world_unavailable", "city": {}, "receipt": {}}
	var coordinator := world.get_node_or_null(COORDINATOR_PATH)
	if coordinator == null or not coordinator.has_method("execute_city_development"):
		return {"created": false, "reason": "coordinator_unavailable", "city": {}, "receipt": {}}
	var skill := _development_skill(world, district_index, preferred_direction)
	if skill.is_empty():
		return {"created": false, "reason": "development_card_unavailable", "city": {}, "receipt": {}}
	skill["development_target_district"] = district_index
	skill["fixture_source_label"] = source_label
	var receipt_variant: Variant = coordinator.call("execute_city_development", {
		"player_index": player_index,
		"district_index": district_index,
		"skill": skill,
	})
	var receipt: Dictionary = (receipt_variant as Dictionary).duplicate(true) if receipt_variant is Dictionary else {}
	var city: Dictionary = world.call("_district_city", district_index) if world.has_method("_district_city") else {}
	return {
		"created": bool(receipt.get("resolved", false)) and not city.is_empty(),
		"reason": str(receipt.get("reason_code", receipt.get("reason", ""))),
		"city": city.duplicate(true),
		"receipt": receipt,
	}


static func create_city_bool(world: Node, player_index: int, district_index: int, source_label := "test fixture", preferred_direction := "production") -> bool:
	return bool(create_city(world, player_index, district_index, source_label, preferred_direction).get("created", false))


static func create_city_surface(world: Node, player_index: int, district_index: int, source_label := "test fixture", preferred_direction := "production") -> Dictionary:
	return (create_city(world, player_index, district_index, source_label, preferred_direction).get("city", {}) as Dictionary).duplicate(true)


static func site_error(world: Node, player_index: int, district_index: int, require_empty_city := false, require_cooldown := false) -> String:
	if world == null or not is_instance_valid(world):
		return "world_unavailable"
	var coordinator := world.get_node_or_null(COORDINATOR_PATH)
	if coordinator == null or not coordinator.has_method("city_development_site_status"):
		return "coordinator_unavailable"
	var status_variant: Variant = coordinator.call("city_development_site_status", player_index, district_index, require_empty_city, require_cooldown)
	var status: Dictionary = status_variant if status_variant is Dictionary else {}
	return "" if bool(status.get("allowed", false)) else str(status.get("reason_code", status.get("reason", "site_rejected")))


static func _development_skill(world: Node, district_index: int, preferred_direction: String) -> Dictionary:
	var cards_variant: Variant = world.get("city_development_runtime_cards")
	var cards: Dictionary = cards_variant if cards_variant is Dictionary else {}
	if cards.is_empty() and world.has_method("_rebuild_city_development_runtime_cards"):
		world.call("_rebuild_city_development_runtime_cards")
		cards_variant = world.get("city_development_runtime_cards")
		cards = cards_variant if cards_variant is Dictionary else {}
	var local_products: Array = world.call("_district_local_product_names", district_index) if world.has_method("_district_local_product_names") else []
	var directions := [preferred_direction, "production", "demand", "commerce"]
	var names: Array = cards.keys()
	names.sort()
	for direction_variant in directions:
		var direction := str(direction_variant)
		for name_variant in names:
			var card_variant: Variant = cards.get(name_variant, {})
			if not (card_variant is Dictionary):
				continue
			var card: Dictionary = card_variant
			if str(card.get("kind", "")) != "city_development" or int(card.get("rank", 1)) != 1:
				continue
			if str(card.get("project_direction", "")) != direction:
				continue
			if not local_products.has(str(card.get("product_id", ""))):
				continue
			return card.duplicate(true)
	return {}
