extends RefCounted
class_name CombatBalanceModel

## Developer-only combat balance model.
##
## This script owns monster attack pressure, region-scale knockback distance,
## and knockback speed.  It intentionally has no dependency on main.gd.

const MovementBalanceModelScript := preload("res://scripts/balance/movement_balance_model.gd")

const DEFAULT_ROGUELIKE_DEPTH := 1
const AUTO_MONSTER_MIN_SPECIAL_DAMAGE := 1

const MONSTER_KNOCKBACK_SECONDS := 0.5
const MONSTER_KNOCKBACK_MIN_SECONDS := 0.35
const MONSTER_KNOCKBACK_MAX_SECONDS := 0.65
const MONSTER_KNOCKBACK_MIN_RADIUS_RATIO := 0.45
const MONSTER_KNOCKBACK_NORMAL_RADIUS_RATIO := 0.85
const MONSTER_KNOCKBACK_HEAVY_RADIUS_RATIO := 1.4
const MONSTER_KNOCKBACK_PROFILE_MULTIPLIERS := {
	"melee": 1.0,
	"beam": 1.85,
	"throw": 2.25,
	"charge": 1.65,
	"blast": 1.45,
}


func monster_knockback_distance_model(action: Dictionary, actor: Dictionary = {}, region_radius_m: float = -1.0) -> Dictionary:
	var radius_m := region_radius_m if region_radius_m > 0.0 else _default_region_radius_m()
	var explicit := float(action.get("knockback", -1.0))
	var damage := maxi(1, int(action.get("damage", action.get("close_damage", 1))))
	var profile := monster_knockback_profile(action)
	var profile_multiplier := float(MONSTER_KNOCKBACK_PROFILE_MULTIPLIERS.get(profile, 1.0))
	var ratio := MONSTER_KNOCKBACK_NORMAL_RADIUS_RATIO
	if damage <= 1:
		ratio = MONSTER_KNOCKBACK_MIN_RADIUS_RATIO
	elif damage >= 4:
		ratio = MONSTER_KNOCKBACK_HEAVY_RADIUS_RATIO
	ratio *= profile_multiplier
	var model_distance := radius_m * ratio
	var distance := explicit if explicit > 0.0 else model_distance
	var lower := radius_m * MONSTER_KNOCKBACK_MIN_RADIUS_RATIO * minf(1.0, profile_multiplier)
	var upper := radius_m * MONSTER_KNOCKBACK_HEAVY_RADIUS_RATIO * maxf(1.0, profile_multiplier)
	distance = clampf(distance, lower, upper)
	return {
		"region_radius_m": radius_m,
		"damage": damage,
		"profile": profile,
		"profile_multiplier": profile_multiplier,
		"radius_ratio": distance / maxf(1.0, radius_m),
		"knockback_m": distance,
		"recommended_min_m": lower,
		"recommended_normal_m": radius_m * MONSTER_KNOCKBACK_NORMAL_RADIUS_RATIO,
		"recommended_heavy_m": upper,
		"explicit_knockback_m": explicit,
	}


func monster_knockback_profile(action: Dictionary) -> String:
	var explicit := String(action.get("knockback_profile", ""))
	if explicit != "":
		return explicit
	var kind := String(action.get("kind", ""))
	var name := String(action.get("name", ""))
	var tags := _as_array(action.get("tags", []))
	if kind == "charge_attack" or name.contains("冲锋") or tags.has("冲撞"):
		return "charge"
	if name.contains("光线") or name.contains("射线") or tags.has("光线") or float(action.get("range", 0.0)) >= 400.0:
		return "beam"
	if name.contains("投掷") or name.contains("抛") or tags.has("投掷"):
		return "throw"
	if name.contains("爆") or tags.has("爆炸"):
		return "blast"
	return "melee"


func monster_knockback_speed_model(action: Dictionary, actor: Dictionary = {}, region_radius_m: float = -1.0, duration_seconds: float = MONSTER_KNOCKBACK_SECONDS) -> Dictionary:
	var distance_model := monster_knockback_distance_model(action, actor, region_radius_m)
	var duration := clampf(duration_seconds, MONSTER_KNOCKBACK_MIN_SECONDS, MONSTER_KNOCKBACK_MAX_SECONDS)
	var distance := float(distance_model.get("knockback_m", 0.0))
	var speed := distance / maxf(0.01, duration)
	distance_model["knockback_duration_seconds"] = duration
	distance_model["knockback_speed_mps"] = speed
	distance_model["impact_feel"] = "center_to_edge" if float(distance_model.get("radius_ratio", 0.0)) >= 0.75 else "short_stagger"
	return distance_model


func monster_attack_model(action: Dictionary, actor: Dictionary = {}) -> Dictionary:
	var rank := clampi(int(actor.get("rank", action.get("rank", 1))), 1, 4)
	var base_damage := maxi(AUTO_MONSTER_MIN_SPECIAL_DAMAGE, int(action.get("damage", AUTO_MONSTER_MIN_SPECIAL_DAMAGE)))
	var close_damage := maxi(base_damage, int(action.get("close_damage", base_damage)))
	var range_m := maxf(0.0, float(action.get("range", 0.0)))
	var knockback_m := maxf(0.0, float(action.get("knockback", 0.0)))
	var region_radius_m := float(actor.get("region_radius_m", action.get("region_radius_m", -1.0)))
	var knockback_model := monster_knockback_speed_model(action, actor, region_radius_m)
	if knockback_m <= 0.0:
		knockback_m = float(knockback_model.get("knockback_m", 0.0))
	var area_damage := base_damage * (1.0 + minf(0.45, range_m / 900.0))
	var displacement_pressure := knockback_m / 220.0
	var rank_pressure := 1.0 + float(rank - 1) * 0.18
	var attack_pressure_score := int(round((area_damage * 54.0 + displacement_pressure * 24.0 + float(close_damage - base_damage) * 18.0) * rank_pressure))
	return {
		"rank": rank,
		"base_damage": base_damage,
		"close_damage": close_damage,
		"range_m": range_m,
		"knockback_m": knockback_m,
		"knockback": knockback_model,
		"rank_pressure_multiplier": rank_pressure,
		"attack_pressure_score": attack_pressure_score,
		"expected_region_damage": base_damage,
		"expected_monster_damage": close_damage,
	}


func _default_region_radius_m() -> float:
	var movement: RefCounted = MovementBalanceModelScript.new()
	var region: Dictionary = movement.call("region_size_model", DEFAULT_ROGUELIKE_DEPTH)
	return float(region.get("avg_region_radius_m", 180.0))


func _as_array(value: Variant) -> Array:
	return value as Array if value is Array else []
