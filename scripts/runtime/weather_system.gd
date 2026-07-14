extends RefCounted
class_name WeatherSystem

const MICROS_PER_SECOND := 1_000_000
const FORECAST_LEAD_MIN_SECONDS := 30.0
const FORECAST_LEAD_MAX_SECONDS := 60.0
const ACTIVE_MIN_SECONDS := 45.0
const ACTIVE_MAX_SECONDS := 90.0
const FADE_SECONDS := 10.0
const GENERATION_MIN_SECONDS := 90.0
const GENERATION_MAX_SECONDS := 150.0
const START_GRACE_SECONDS := 90.0
const MAX_UNENDED_EVENTS := 2
const DEFAULT_AFFECTED_REGION_COUNT := 1

const FORECAST_LEAD_MIN_US := 30_000_000
const FORECAST_LEAD_MAX_US := 60_000_000
const ACTIVE_MIN_US := 45_000_000
const ACTIVE_MAX_US := 90_000_000
const FADE_US := 10_000_000
const GENERATION_MIN_US := 90_000_000
const GENERATION_MAX_US := 150_000_000
const START_GRACE_US := 90_000_000


func lifecycle_phase(event: Dictionary, now_us: int) -> String:
	var current_phase := str(event.get("phase", WeatherRuntimeState.PHASE_FORECAST))
	if current_phase == WeatherRuntimeState.PHASE_QUEUED or current_phase == WeatherRuntimeState.PHASE_ENDED:
		return current_phase
	if now_us >= int(event.get("fade_ends_at_world_us", 0)):
		return WeatherRuntimeState.PHASE_ENDED
	if now_us >= int(event.get("active_ends_at_world_us", 0)):
		return WeatherRuntimeState.PHASE_FADING
	if now_us >= int(event.get("active_starts_at_world_us", 0)):
		return WeatherRuntimeState.PHASE_ACTIVE
	return WeatherRuntimeState.PHASE_FORECAST


func intensity(event: Dictionary, now_us: int) -> float:
	var phase := str(event.get("phase", lifecycle_phase(event, now_us)))
	match phase:
		WeatherRuntimeState.PHASE_ACTIVE:
			return 1.0
		WeatherRuntimeState.PHASE_FADING:
			var fade_start := int(event.get("active_ends_at_world_us", 0))
			var fade_end := int(event.get("fade_ends_at_world_us", fade_start))
			if fade_end <= fade_start:
				return 0.0
			return clampf(float(fade_end - now_us) / float(fade_end - fade_start), 0.0, 1.0)
	return 0.0


func random_duration_us(rng: RandomNumberGenerator, minimum_us: int, maximum_us: int) -> int:
	if rng == null:
		return minimum_us
	return rng.randi_range(minimum_us, maximum_us)


func next_generation_us(now_us: int, rng: RandomNumberGenerator) -> int:
	return now_us + random_duration_us(rng, GENERATION_MIN_US, GENERATION_MAX_US)


func can_generate_natural(now_us: int, next_generation_world_us: int, new_forecasts_allowed: bool, unended_count: int) -> bool:
	return new_forecasts_allowed and now_us >= START_GRACE_US and now_us >= next_generation_world_us and unended_count < MAX_UNENDED_EVENTS


func select_definition_id(definition_ids: Array, rng: RandomNumberGenerator) -> String:
	if definition_ids.is_empty():
		return ""
	if rng == null:
		return str(definition_ids[0])
	return str(definition_ids[rng.randi_range(0, definition_ids.size() - 1)])


func select_region(region_facts: Array, occupied_regions: Array, region_history: Dictionary, rng: RandomNumberGenerator) -> int:
	var best_score := -INF
	var best_regions: Array = []
	for fact_variant in region_facts:
		if not (fact_variant is Dictionary):
			continue
		var fact := fact_variant as Dictionary
		var index := int(fact.get("index", -1))
		if index < 0 or bool(fact.get("destroyed", false)) or occupied_regions.has(index):
			continue
		var score := 0.0
		if bool(fact.get("has_active_city", false)):
			score += 8.0
		score += float(maxi(0, int(fact.get("active_route_count", 0)))) * 2.0
		score += float(maxi(0, int(fact.get("live_monster_count", 0)))) * 1.5
		score += float(maxi(0, int(fact.get("trade_volume_bucket", 0)))) * 1.25
		score -= float(maxi(0, int(region_history.get(str(index), 0)))) * 0.35
		if score > best_score + 0.001:
			best_score = score
			best_regions = [index]
		elif is_equal_approx(score, best_score):
			best_regions.append(index)
	if best_regions.is_empty():
		return -1
	if rng == null:
		return int(best_regions[0])
	return int(best_regions[rng.randi_range(0, best_regions.size() - 1)])


func regions_conflict(a: Array, b: Array) -> bool:
	for region in a:
		if b.has(region):
			return true
	return false
