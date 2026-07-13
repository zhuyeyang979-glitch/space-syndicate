extends RefCounted
class_name MovementBalanceModel

## Developer-only movement and planet-scale balance model.
##
## This script owns planet size, region count/area, monster movement speed, and
## military movement speed.  It intentionally has no dependency on main.gd.

const ROGUELIKE_DEPTH_MIN := 1
const ROGUELIKE_DEPTH_MAX := 6
const DEFAULT_ROGUELIKE_DEPTH := 1

const MAP_WIDTH_METERS := 1400.0
const MAP_HEIGHT_METERS := 950.0
const MAP_REGION_COUNT_MIN := 6
const MAP_REGION_COUNT_MAX := 54
const REGION_TARGET_AREA_MIN_M2 := 65000.0
const REGION_TARGET_AREA_MAX_M2 := 140000.0

const MONSTER_RAMPAGE_MOVE_METERS := 190.0
const AUTO_MONSTER_MOVE_RATIO := 0.72
const AUTO_MONSTER_DEFAULT_MOVE_DAMAGE := 1
const MONSTER_REGION_EXIT_TARGET_SECONDS := 10.0
const MONSTER_REGION_EXIT_MIN_SECONDS := 7.0
const MONSTER_REGION_EXIT_MAX_SECONDS := 14.0
const MONSTER_SPEED_FACTOR_MIN := 0.03
const MONSTER_SPEED_FACTOR_MAX := 14.0
const MONSTER_FLYING_SPEED_MULTIPLIER := 10.0
const MONSTER_AQUATIC_SPEED_MULTIPLIER := 6.5
const MONSTER_TUNNEL_SPEED_MULTIPLIER := 2.4
const MONSTER_ORBITAL_SPEED_MULTIPLIER := 8.0

const MILITARY_REGION_EXIT_TARGET_SECONDS := 10.0
const MILITARY_SPEED_FACTOR_MIN := 0.15
const MILITARY_SPEED_FACTOR_MAX := 2.8


func region_count_range_for_depth(depth: int = -1) -> Dictionary:
	var value := _safe_depth(depth)
	var region_min := 6
	var region_max := 9
	match value:
		1:
			region_min = 6
			region_max = 9
		2:
			region_min = 10
			region_max = 14
		3:
			region_min = 15
			region_max = 21
		4:
			region_min = 22
			region_max = 30
		5:
			region_min = 31
			region_max = 41
		_:
			region_min = 40
			region_max = 54
	return {
		"depth": value,
		"region_min": region_min,
		"region_max": region_max,
		"region_mid": int(round(float(region_min + region_max) * 0.5)),
	}


func planet_size_for_depth(depth: int = -1) -> Dictionary:
	var value := _safe_depth(depth)
	var scale := 0.65 + float(value) * 0.18
	var width := MAP_WIDTH_METERS * scale
	var height := MAP_HEIGHT_METERS * scale
	return {
		"depth": value,
		"width_m": width,
		"height_m": height,
		"area_m2": width * height,
		"scale": scale,
	}


func region_size_model(depth: int = -1, region_count: int = -1) -> Dictionary:
	var value := _safe_depth(depth)
	var count_range := region_count_range_for_depth(value)
	var planet := planet_size_for_depth(value)
	var safe_count := int(count_range.get("region_mid", 1)) if region_count <= 0 else clampi(region_count, int(count_range.get("region_min", 1)), int(count_range.get("region_max", 1)))
	var area := float(planet.get("area_m2", 1.0))
	var avg_area := area / float(maxi(1, safe_count))
	var density := float(safe_count) / maxf(1.0, area) * 1000000.0
	var issues := []
	if avg_area < REGION_TARGET_AREA_MIN_M2:
		issues.append("average_region_area_too_small")
	if avg_area > REGION_TARGET_AREA_MAX_M2:
		issues.append("average_region_area_too_large")
	return {
		"depth": value,
		"region_count": safe_count,
		"region_min": int(count_range.get("region_min", safe_count)),
		"region_max": int(count_range.get("region_max", safe_count)),
		"planet_width_m": float(planet.get("width_m", MAP_WIDTH_METERS)),
		"planet_height_m": float(planet.get("height_m", MAP_HEIGHT_METERS)),
		"planet_area_m2": area,
		"avg_region_area_m2": avg_area,
		"avg_region_radius_m": sqrt(avg_area / PI),
		"regions_per_million_m2": density,
		"target_area_min_m2": REGION_TARGET_AREA_MIN_M2,
		"target_area_max_m2": REGION_TARGET_AREA_MAX_M2,
		"issues": issues,
		"passes": issues.is_empty(),
	}


func monster_region_exit_speed_model(depth: int = -1, region_count: int = -1, terrain_multiplier: float = 1.0, speed_rating: float = 1.0) -> Dictionary:
	var region := region_size_model(depth, region_count)
	var radius_m := float(region.get("avg_region_radius_m", 180.0))
	var target_seconds := clampf(MONSTER_REGION_EXIT_TARGET_SECONDS, MONSTER_REGION_EXIT_MIN_SECONDS, MONSTER_REGION_EXIT_MAX_SECONDS)
	var safe_rating := clampf(speed_rating, MONSTER_SPEED_FACTOR_MIN, MONSTER_SPEED_FACTOR_MAX)
	var safe_terrain := clampf(terrain_multiplier, 0.25, 2.4)
	var speed := maxf(1.0, radius_m / target_seconds * safe_rating * safe_terrain)
	return {
		"depth": _safe_depth(depth),
		"region_count": int(region.get("region_count", region_count)),
		"avg_region_radius_m": radius_m,
		"target_region_exit_seconds": target_seconds,
		"speed_rating": safe_rating,
		"terrain_multiplier": safe_terrain,
		"speed_mps": speed,
		"estimated_region_exit_seconds": radius_m / maxf(1.0, speed),
	}


func monster_movement_speed_model(actor: Dictionary, terrain_multiplier: float = 1.0, action_speed_mps: float = -1.0, region_radius_m: float = -1.0, target_region_exit_seconds: float = MONSTER_REGION_EXIT_TARGET_SECONDS) -> Dictionary:
	var raw_speed := action_speed_mps if action_speed_mps > 0.0 else float(actor.get("move", MONSTER_RAMPAGE_MOVE_METERS)) * AUTO_MONSTER_MOVE_RATIO
	var safe_terrain := clampf(terrain_multiplier, 0.25, 2.4)
	var raw_rating := raw_speed / maxf(1.0, MONSTER_RAMPAGE_MOVE_METERS * AUTO_MONSTER_MOVE_RATIO)
	var individual_rating := clampf(raw_rating, 0.1, 1.75)
	if actor.has("speed_rating"):
		individual_rating = clampf(float(actor.get("speed_rating", individual_rating)), 0.0, MONSTER_SPEED_FACTOR_MAX)
	var ecology_multiplier := monster_ecology_speed_multiplier(actor)
	var speed_factor := clampf(individual_rating * ecology_multiplier, MONSTER_SPEED_FACTOR_MIN, MONSTER_SPEED_FACTOR_MAX)
	var target_seconds := clampf(target_region_exit_seconds, MONSTER_REGION_EXIT_MIN_SECONDS, MONSTER_REGION_EXIT_MAX_SECONDS)
	var region_speed := -1.0
	var speed_limited_by_region := false
	if region_radius_m > 0.0:
		region_speed = maxf(0.1, region_radius_m / target_seconds * speed_factor * safe_terrain)
		speed_limited_by_region = region_speed < raw_speed * safe_terrain
	var speed := region_speed if region_speed > 0.0 else raw_speed * safe_terrain
	speed = clampf(speed, 0.1, 420.0)
	var actor_movement_mode := movement_mode(actor)
	var actor_move_damage := move_damage(actor, actor_movement_mode)
	return {
		"movement_mode": actor_movement_mode,
		"base_speed_mps": raw_speed,
		"terrain_multiplier": safe_terrain,
		"individual_speed_rating": individual_rating,
		"ecology_speed_multiplier": ecology_multiplier,
		"speed_factor": speed_factor,
		"region_radius_m": region_radius_m,
		"target_region_exit_seconds": target_seconds,
		"speed_mps": speed,
		"estimated_region_exit_seconds": region_radius_m / maxf(1.0, speed) if region_radius_m > 0.0 else -1.0,
		"speed_limited_by_region": speed_limited_by_region,
		"move_damage": actor_move_damage,
		"flying_no_trample": actor_move_damage == 0 and (actor_movement_mode == "fly" or has_trait(actor, "flying")),
	}


func monster_ecology_speed_multiplier(actor: Dictionary) -> float:
	var mode := movement_mode(actor)
	if bool(actor.get("stationary", false)) or bool(actor.get("immobile", false)) or has_trait(actor, "stationary") or has_trait(actor, "immobile"):
		return MONSTER_SPEED_FACTOR_MIN
	if mode == "fly" or mode == "air" or has_trait(actor, "flying") or has_trait(actor, "air"):
		return MONSTER_FLYING_SPEED_MULTIPLIER
	if mode == "orbital" or has_trait(actor, "orbital"):
		return MONSTER_ORBITAL_SPEED_MULTIPLIER
	if mode == "aquatic" or mode == "swim" or mode == "sea" or has_trait(actor, "aquatic") or has_trait(actor, "ocean") or has_trait(actor, "sea"):
		return MONSTER_AQUATIC_SPEED_MULTIPLIER
	if mode == "tunnel" or has_trait(actor, "tunnel") or has_trait(actor, "burrow"):
		return MONSTER_TUNNEL_SPEED_MULTIPLIER
	if mode == "hybrid":
		return 1.6
	return 1.0


func military_movement_speed_model(unit: Dictionary, terrain_multiplier: float = 1.0, command_speed_mps: float = -1.0, region_radius_m: float = -1.0) -> Dictionary:
	var raw_speed := command_speed_mps if command_speed_mps > 0.0 else float(unit.get("move", unit.get("military_move", 260.0)))
	var safe_terrain := clampf(terrain_multiplier, 0.05, 2.0)
	var raw_rating := raw_speed / 260.0
	var individual_rating := clampf(raw_rating, 0.25, 1.35)
	var domain_multiplier := military_domain_speed_multiplier(unit)
	var speed_factor := clampf(individual_rating * domain_multiplier, MILITARY_SPEED_FACTOR_MIN, MILITARY_SPEED_FACTOR_MAX)
	var radius_m := region_radius_m if region_radius_m > 0.0 else float(region_size_model(DEFAULT_ROGUELIKE_DEPTH).get("avg_region_radius_m", 180.0))
	var speed := clampf(radius_m / MILITARY_REGION_EXIT_TARGET_SECONDS * speed_factor * safe_terrain, 0.5, 95.0)
	return {
		"domain": String(unit.get("military_domain", unit.get("movement_mode", "mixed"))),
		"military_type": String(unit.get("military_type", "defense")),
		"base_speed_mps": raw_speed,
		"individual_speed_rating": individual_rating,
		"domain_speed_multiplier": domain_multiplier,
		"terrain_multiplier": safe_terrain,
		"speed_factor": speed_factor,
		"region_radius_m": radius_m,
		"speed_mps": speed,
		"estimated_region_exit_seconds": radius_m / maxf(1.0, speed),
		"target_region_exit_seconds": MILITARY_REGION_EXIT_TARGET_SECONDS,
	}


func military_domain_speed_multiplier(unit: Dictionary) -> float:
	var domain := String(unit.get("military_domain", "mixed"))
	var military_type := String(unit.get("military_type", "defense"))
	if domain == "air" or has_trait(unit, "air"):
		return 2.2
	if military_type == "missile" or has_trait(unit, "artillery"):
		return 0.25
	if domain == "sea" or has_trait(unit, "sea") or has_trait(unit, "submerged"):
		return 1.45
	if military_type == "tank" or has_trait(unit, "armor"):
		return 0.75
	return 1.0


func movement_mode(actor: Dictionary) -> String:
	var explicit := String(actor.get("movement_mode", ""))
	if explicit != "":
		return explicit
	if has_trait(actor, "flying"):
		return "fly"
	if has_trait(actor, "ocean") or has_trait(actor, "swimming") or has_trait(actor, "aquatic"):
		return "swim"
	return "walk"


func move_damage(actor: Dictionary, mode: String) -> int:
	if mode == "fly" or has_trait(actor, "flying"):
		return 0
	return max(AUTO_MONSTER_DEFAULT_MOVE_DAMAGE, int(actor.get("move_damage", AUTO_MONSTER_DEFAULT_MOVE_DAMAGE)))


func has_trait(actor: Dictionary, trait_name: String) -> bool:
	return _as_array(actor.get("movement_traits", [])).has(trait_name) or _as_array(actor.get("traits", [])).has(trait_name)


func _safe_depth(depth: int) -> int:
	var value := DEFAULT_ROGUELIKE_DEPTH if depth < 0 else depth
	return clampi(value, ROGUELIKE_DEPTH_MIN, ROGUELIKE_DEPTH_MAX)


func _as_array(value: Variant) -> Array:
	return value as Array if value is Array else []
