extends RefCounted
class_name V073PlanetPresentationAdapterV1

const Geometry := preload("res://scripts/presentation/v073/v073_procedural_region_geometry_v1.gd")
const Snapshot := preload("res://scripts/presentation/map_presentation_snapshot.gd")

const RULESET_ID := "v0.7.3"
const FACILITY_ASSET_KEYS := {
	"factory": "model.facility.factory.base",
	"market": "model.facility.market.base",
	"warehouse": "model.facility.warehouse.base",
	"starport": "model.facility.starport.base",
}
const COLOR_HEX := {
	"life": "#52d681",
	"energy": "#f2c14e",
	"industry": "#aeb8c6",
	"technology": "#4cc9f0",
	"commerce": "#d08cf0",
	"shipping": "#46d6b5",
}
const PALETTE := [
	Color("#42d6c6"), Color("#f2c14e"), Color("#d08cf0"),
	Color("#62a8ff"), Color("#ff7a90"), Color("#a6e36d"),
]

var _geometry_cache: Dictionary = {}
var _build_count := 0


func authorization_revision(player_snapshot: Dictionary) -> int:
	return maxi(1, int(player_snapshot.get("batch_number", 0)) + 1)


func build_map_snapshot(
	match_seed: int,
	player_snapshot: Dictionary,
	selected_card_id: String,
	selected_region_id: String
) -> MapPresentationSnapshot:
	if str(player_snapshot.get("ruleset_id", "")) != RULESET_ID:
		return null
	var geometry := _geometry_for_seed(match_seed)
	var districts := (geometry.get("districts", []) as Array).duplicate(true)
	var solar_by_region := _solar_by_region(player_snapshot)
	var legal_regions := _legal_regions(player_snapshot, selected_card_id)
	for index in range(districts.size()):
		var district := (districts[index] as Dictionary).duplicate(true)
		var region_id := str(district.get("region_id", ""))
		var solar := solar_by_region.get(region_id, {}) as Dictionary
		var sunlit := bool(solar.get("sunlit", false))
		district["sunlit"] = sunlit
		district["facility_efficiency_multiplier"] = float(solar.get("facility_efficiency_multiplier", 1.0))
		district["unified_track_supply_affected"] = false
		district["legal_target"] = selected_card_id.is_empty() or legal_regions.has(region_id)
		district["products"] = [
			("日照" if sunlit else "暗面")
			+ " ×%.1f" % float(district.get("facility_efficiency_multiplier", 1.0))
		]
		districts[index] = district
	var result := Snapshot.new()
	result.revision = maxi(0, int(player_snapshot.get("batch_number", 0)))
	result.viewer_index = _viewer_index(player_snapshot)
	result.authorization_revision = authorization_revision(player_snapshot)
	result.districts = districts
	result.width_m = float(geometry.get("width_m", Geometry.MAP_WIDTH_M))
	result.height_m = float(geometry.get("height_m", Geometry.MAP_HEIGHT_M))
	result.selected_district = _district_index(districts, selected_region_id)
	result.palette.assign(PALETTE)
	result.unit_markers = _public_unit_markers(player_snapshot, districts)
	result.city_markers = _public_facility_markers(player_snapshot, districts, match_seed)
	result.route_markers = _public_route_markers(player_snapshot, districts)
	result.solar_presentation = _solar_presentation(player_snapshot, districts, solar_by_region)
	result.weather_forecast = {}
	result.weather_overlay = {}
	result.motion_mode = "full"
	result.presentation_seed = match_seed
	result.geometry_fingerprint = str(geometry.get("fingerprint", ""))
	_build_count += 1
	return result


func geometry_for_seed(match_seed: int) -> Dictionary:
	return _geometry_for_seed(match_seed).duplicate(true)


func region_id_for_index(match_seed: int, district_index: int) -> String:
	var districts := _geometry_for_seed(match_seed).get("districts", []) as Array
	if district_index < 0 or district_index >= districts.size():
		return ""
	return str((districts[district_index] as Dictionary).get("region_id", ""))


func debug_snapshot(match_seed: int = 0) -> Dictionary:
	var geometry := _geometry_for_seed(match_seed)
	return {
		"schema": "V073PlanetPresentationAdapterDebugV1",
		"connection_count": 1,
		"build_count": _build_count,
		"gameplay_owner_count": 0,
		"save_owner_count": 0,
		"rng_owner_count": 0,
		"gameplay_rng_draw_count": 0,
		"region_count": (geometry.get("districts", []) as Array).size(),
		"geometry_fingerprint": str(geometry.get("fingerprint", "")),
		"geometry_source": "V073ProceduralRegionGeometryV1 extracted from SessionStartWorldPlanBuilder Voronoi",
	}


func _geometry_for_seed(match_seed: int) -> Dictionary:
	var cache_key := str(match_seed)
	if not _geometry_cache.has(cache_key):
		_geometry_cache[cache_key] = Geometry.build(match_seed)
	return _geometry_cache.get(cache_key, {}) as Dictionary


func _viewer_index(player_snapshot: Dictionary) -> int:
	for row_variant in player_snapshot.get("roster", []) as Array:
		var row := row_variant as Dictionary
		if bool(row.get("is_local_player", false)):
			return int(row.get("public_order_index", 0))
	return 0


func _solar_by_region(player_snapshot: Dictionary) -> Dictionary:
	var result := {}
	for row_variant in player_snapshot.get("region_solar", []) as Array:
		var row := row_variant as Dictionary
		result[str(row.get("region_id", ""))] = row.duplicate(true)
	return result


func _legal_regions(player_snapshot: Dictionary, selected_card_id: String) -> Dictionary:
	var result := {}
	if selected_card_id.is_empty():
		return result
	for option_variant in player_snapshot.get("legal_actions", []) as Array:
		var option := option_variant as Dictionary
		if str(option.get("card_instance_id", "")) == selected_card_id:
			result[str(option.get("target_region_id", ""))] = true
	return result


func _district_index(districts: Array, region_id: String) -> int:
	if region_id.is_empty():
		return -1
	for index in range(districts.size()):
		if str((districts[index] as Dictionary).get("region_id", "")) == region_id:
			return index
	return -1


func _center_for_region(districts: Array, region_id: String) -> Vector2:
	var index := _district_index(districts, region_id)
	if index < 0:
		return Vector2.ZERO
	return (districts[index] as Dictionary).get("center", Vector2.ZERO) as Vector2


func _public_facility_markers(player_snapshot: Dictionary, districts: Array, match_seed: int) -> Array:
	var result: Array = []
	var facility := player_snapshot.get("facility_contention", {}) as Dictionary
	var rows := facility.get("public_facility_slots", []) as Array
	var region_ordinals := {}
	for index in range(rows.size()):
		var row := rows[index] as Dictionary
		if str(row.get("occupancy", "")) != "occupied":
			continue
		var facility_type := str(row.get("facility_type", "facility"))
		var industry_id := str(row.get("industry_id", "industry"))
		var region_id := str(row.get("region_id", ""))
		var center := _center_for_region(districts, region_id)
		var region_ordinal := int(region_ordinals.get(region_id, 0))
		region_ordinals[region_id] = region_ordinal + 1
		var region_index := maxi(0, _district_index(districts, region_id))
		var base_angle := float(posmod(match_seed + region_index * 59, 360)) / 360.0 * TAU
		var offset_angle := base_angle + float(region_ordinal) * 2.39996323
		var offset_radius := 112.0 + float(region_ordinal / 6) * 28.0
		result.append({
			"position": center + Vector2(cos(offset_angle), sin(offset_angle)) * offset_radius,
			"tag": str({"factory": "F", "market": "M", "warehouse": "W", "starport": "S"}.get(facility_type, "F")),
			"level": maxi(1, int(row.get("rank", 1))),
			"products": [industry_id],
			"tag_color": Color(str(COLOR_HEX.get(industry_id, "#38bdf8"))),
			"active": int(row.get("damage_points", 0)) <= 0,
			"asset_key": str(FACILITY_ASSET_KEYS.get(facility_type, "model.facility.factory.base")),
			"region_id": region_id,
			"facility_type": facility_type,
		})
	return result


func _public_unit_markers(player_snapshot: Dictionary, districts: Array) -> Array:
	var result: Array = []
	for source_key in ["monster_public_facts", "military_public_facts"]:
		for row_variant in player_snapshot.get(source_key, []) as Array:
			var row := row_variant as Dictionary
			var region_id := str(row.get("region_id", ""))
			var unit_kind := "monster" if source_key.begins_with("monster") else "military"
			var family := str(row.get("family_id", row.get("industry_id", "industry")))
			var tier := maxi(1, int(row.get("tier", 1)))
			result.append({
				"position": _center_for_region(districts, region_id),
				"name": str(row.get("display_name", unit_kind.capitalize())),
				"label": str(row.get("public_label", unit_kind.capitalize())),
				"glyph": "M" if unit_kind == "monster" else "A",
				"display_subtitle": str(row.get("public_status", "公开单位")),
				"color": Color(str(COLOR_HEX.get(family, "#ef4444"))),
				"secondary": Color("#fde68a"),
				"asset_key": "model.monster.%s" % family if unit_kind == "monster" else "model.military.tier%d" % clampi(tier, 1, 4),
				"region_id": region_id,
				"unit_kind": unit_kind,
			})
	return result


func _public_route_markers(player_snapshot: Dictionary, districts: Array) -> Array:
	var result: Array = []
	for row_variant in player_snapshot.get("public_routes", []) as Array:
		var row := row_variant as Dictionary
		result.append({
			"points": [
				_center_for_region(districts, str(row.get("from_region_id", ""))),
				_center_for_region(districts, str(row.get("to_region_id", ""))),
			],
			"product": str(row.get("commodity_id", "公开路线")),
			"flow_kind": str(row.get("flow_kind", "public")),
			"disrupted": bool(row.get("disrupted", false)),
			"show_marker": true,
			"asset_key": "model.shipping.route_marker",
		})
	return result


func _solar_presentation(player_snapshot: Dictionary, districts: Array, solar_by_region: Dictionary) -> Dictionary:
	var best_turn := 0
	var best_score := -INF
	for candidate in range(72):
		var turn := float(candidate) / 72.0
		var score := 0.0
		for district_variant in districts:
			var district := district_variant as Dictionary
			var region_id := str(district.get("region_id", ""))
			var center := district.get("center", Vector2.ZERO) as Vector2
			var predicted_sunlit := cos((center.x / Geometry.MAP_WIDTH_M - turn) * TAU) >= 0.0
			var actual_sunlit := bool((solar_by_region.get(region_id, {}) as Dictionary).get("sunlit", false))
			score += 1.0 if predicted_sunlit == actual_sunlit else -1.0
		if score > best_score:
			best_score = score
			best_turn = candidate
	var batch_number := maxi(0, int(player_snapshot.get("batch_number", 0)))
	return {
		"world_effective_us": batch_number * 30_000_000,
		"rotation_period_us": 120_000_000,
		"sun_turn_ppm": int(round(float(best_turn) / 72.0 * 1_000_000.0)) % 1_000_000,
	}
