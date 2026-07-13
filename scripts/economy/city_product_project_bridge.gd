extends RefCounted
class_name CityProductProjectBridge

const PROJECT_STATE := preload("res://scripts/economy/city_product_project_state.gd")


static func migrate_legacy_city(city_value: Dictionary, district_index: int, created_order_seed: int = 0) -> Dictionary:
	var city := city_value.duplicate(true)
	if city.is_empty():
		return city
	var has_explicit_projects := city.has("projects")
	var source_projects: Array = city.get("projects", []) if city.get("projects", []) is Array else []
	var projects: Array = []
	for project_variant in source_projects:
		if project_variant is Dictionary:
			projects.append(PROJECT_STATE.normalize_project(project_variant as Dictionary))
	if not projects.is_empty():
		city["projects"] = projects
		return city
	if has_explicit_projects:
		city["projects"] = []
		city["project_sequence"] = maxi(0, created_order_seed)
		return city
	var owner_index := int(city.get("owner", -1))
	var order := maxi(0, created_order_seed)
	if owner_index < 0:
		city["projects"] = projects
		city["project_sequence"] = order
		return city
	for product_variant in city.get("products", []):
		if not (product_variant is Dictionary):
			continue
		var product: Dictionary = product_variant
		var product_id := str(product.get("name", "")).strip_edges()
		if product_id == "":
			continue
		var project := PROJECT_STATE.create_project(district_index, product_id, "production", owner_index, maxi(1, int(product.get("level", 1))), order)
		projects.append(project)
		order += 1
	for demand_variant in city.get("demands", []):
		var product_id := str(demand_variant).strip_edges()
		if product_id == "":
			continue
		var project := PROJECT_STATE.create_project(district_index, product_id, "demand", owner_index, 1, order)
		projects.append(project)
		order += 1
	if projects.is_empty() and owner_index >= 0:
		projects.append(PROJECT_STATE.create_project(district_index, "公共通商", "commerce", owner_index, 1, order))
	city["projects"] = projects
	city["project_sequence"] = order
	return city


static func apply_development(city_value: Dictionary, district_index: int, player_index: int, skill: Dictionary, contribution_order: int) -> Dictionary:
	var city := migrate_legacy_city(city_value, district_index, contribution_order)
	var product_id := str(skill.get("product_id", skill.get("play_product", ""))).strip_edges()
	var direction := PROJECT_STATE.normalize_direction(str(skill.get("project_direction", "production")))
	var units := maxi(1, int(skill.get("contribution_units", 1)))
	var target_id := PROJECT_STATE.project_id(district_index, product_id, direction)
	var projects: Array = city.get("projects", []) if city.get("projects", []) is Array else []
	var matched := false
	for i in range(projects.size()):
		if not (projects[i] is Dictionary):
			continue
		var project := PROJECT_STATE.normalize_project(projects[i] as Dictionary)
		if str(project.get("project_id", "")) != target_id:
			projects[i] = project
			continue
		projects[i] = PROJECT_STATE.contribute(project, player_index, units, contribution_order)
		matched = true
		break
	if not matched:
		projects.append(PROJECT_STATE.create_project(district_index, product_id, direction, player_index, units, contribution_order))
	city["projects"] = projects
	city["project_sequence"] = maxi(int(city.get("project_sequence", 0)), contribution_order + 1)
	return sync_legacy_fields(city)


static func sync_legacy_fields(city_value: Dictionary) -> Dictionary:
	var city := city_value.duplicate(true)
	var products: Array = city.get("products", []) if city.get("products", []) is Array else []
	var demands: Array = city.get("demands", []) if city.get("demands", []) is Array else []
	for project_variant in city.get("projects", []):
		if not (project_variant is Dictionary):
			continue
		var project := PROJECT_STATE.normalize_project(project_variant as Dictionary)
		if not bool(project.get("active", true)):
			continue
		var product_id := str(project.get("product_id", ""))
		match str(project.get("direction", "production")):
			"production":
				var found := false
				for product_variant in products:
					if product_variant is Dictionary and str((product_variant as Dictionary).get("name", "")) == product_id:
						(product_variant as Dictionary)["level"] = maxi(int((product_variant as Dictionary).get("level", 1)), int(project.get("level", 1)))
						found = true
						break
				if not found:
					products.append({"name": product_id, "level": int(project.get("level", 1)), "base_price": 0, "tier": 1})
			"demand":
				if not demands.has(product_id):
					demands.append(product_id)
	city["products"] = products
	city["demands"] = demands
	return city


static func assign_city_gdp(city_value: Dictionary, city_gdp: int) -> Dictionary:
	var city := city_value.duplicate(true)
	var projects: Array = city.get("projects", []) if city.get("projects", []) is Array else []
	city["projects"] = PROJECT_STATE.assign_city_gdp(projects, maxi(0, city_gdp))
	city["project_gdp_by_player"] = PROJECT_STATE.gdp_by_player(city.get("projects", []) as Array)
	return city


static func public_projects(city: Dictionary) -> Array:
	var result: Array = []
	for project_variant in city.get("projects", []):
		if project_variant is Dictionary:
			result.append(PROJECT_STATE.public_snapshot(project_variant as Dictionary))
	return result


static func private_projects(city: Dictionary, viewer_player_index: int) -> Array:
	var result: Array = []
	for project_variant in city.get("projects", []):
		if project_variant is Dictionary:
			result.append(PROJECT_STATE.private_snapshot(project_variant as Dictionary, viewer_player_index))
	return result
