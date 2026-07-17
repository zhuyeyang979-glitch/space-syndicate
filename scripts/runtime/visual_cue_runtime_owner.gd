@tool
extends Node
class_name VisualCueRuntimeOwner

const VISUAL_TRAIL_DURATION := 1.8
const ACTION_CALLOUT_DURATION := 4.5
const MAP_EVENT_EFFECT_DURATION := 1.35
const DISTRICT_PULSE_DURATION := 1.2
const MAX_VISUAL_TRAILS := 18
const MAX_ACTION_CALLOUTS := 8
const MAX_MAP_EVENT_EFFECTS := 32
const MELEE_RANGE_METERS := 110.0
const SFX_KEYS := ["card", "impact", "storm"]

var _movement_trails: Array = []
var _action_callouts: Array = []
var _map_event_effects: Array = []
var _district_pulses: Dictionary = {}
var _world_width_m := 0.0
var _world_height_m := 0.0
var _sfx_players: Dictionary = {}
var _sfx_last_time: Dictionary = {}
var _advance_count := 0
var _revision := 0


func configure_world_bounds(width_m: float, height_m: float) -> void:
	_world_width_m = maxf(0.0, width_m)
	_world_height_m = maxf(0.0, height_m)


func bind_sfx_players(players: Dictionary) -> void:
	_sfx_players.clear()
	for key in SFX_KEYS:
		var player := players.get(key, null) as AudioStreamPlayer
		if player != null:
			_sfx_players[key] = player


func reset_state() -> void:
	_movement_trails.clear()
	_action_callouts.clear()
	_map_event_effects.clear()
	_district_pulses.clear()
	_revision += 1


func import_legacy_state(state: Dictionary, districts: Array = []) -> Dictionary:
	_movement_trails = _data_array(state.get("movement_trails", []), MAX_VISUAL_TRAILS)
	_action_callouts = _data_array(state.get("action_callouts", []), MAX_ACTION_CALLOUTS)
	_map_event_effects = _data_array(state.get("map_event_effects", []), MAX_MAP_EVENT_EFFECTS)
	_district_pulses.clear()
	for index in range(districts.size()):
		if not (districts[index] is Dictionary):
			continue
		var district := districts[index] as Dictionary
		var life := maxf(0.0, float(district.get("pulse", 0.0)))
		if life > 0.0:
			_district_pulses[str(index)] = {
				"life": life,
				"duration": maxf(life, DISTRICT_PULSE_DURATION),
				"color": district.get("pulse_color", Color.WHITE),
			}
		district.erase("pulse")
		district.erase("pulse_color")
	_revision += 1
	return {"imported": true, "revision": _revision, "legacy_pulse_count": _district_pulses.size()}


func advance(delta: float) -> Dictionary:
	var step := maxf(0.0, delta)
	_age_array(_movement_trails, step)
	_age_array(_action_callouts, step)
	_age_array(_map_event_effects, step)
	for key_variant in _district_pulses.keys():
		var key := str(key_variant)
		var pulse: Dictionary = _district_pulses.get(key, {}) if _district_pulses.get(key, {}) is Dictionary else {}
		pulse["life"] = maxf(0.0, float(pulse.get("life", 0.0)) - step)
		if float(pulse.get("life", 0.0)) <= 0.0:
			_district_pulses.erase(key)
		else:
			_district_pulses[key] = pulse
	_advance_count += 1
	if step > 0.0:
		_revision += 1
	return {"advanced": true, "advance_count": _advance_count, "revision": _revision}


func add_action_callout(actor: String, action: String, detail: String, color: Color, world_position: Vector2, duration: float = ACTION_CALLOUT_DURATION) -> Dictionary:
	var resolved_duration := maxf(0.1, duration)
	var callout := {
		"actor": actor,
		"action": action,
		"detail": detail,
		"color": color,
		"world_position": _wrap(world_position),
		"life": resolved_duration,
		"duration": resolved_duration,
	}
	_action_callouts.append(callout)
	_trim(_action_callouts, MAX_ACTION_CALLOUTS)
	_play_sfx(_sfx_key_for_callout(actor, action, detail))
	_revision += 1
	return callout.duplicate(true)


func add_visual_trail(from_position: Vector2, to_position: Vector2, color: Color, label: String, duration: float = VISUAL_TRAIL_DURATION, style: String = "movement") -> Dictionary:
	if _wrapped_distance(from_position, to_position) <= 0.5:
		return {}
	var resolved_duration := maxf(0.1, duration)
	var trail := {
		"from": _wrap(from_position),
		"to": _wrap(to_position),
		"color": color,
		"label": label,
		"life": resolved_duration,
		"duration": resolved_duration,
		"style": style,
	}
	_movement_trails.append(trail)
	_trim(_movement_trails, MAX_VISUAL_TRAILS)
	_revision += 1
	return trail.duplicate(true)


func add_map_event_effect(kind: String, world_position: Vector2, color: Color, label: String = "", duration: float = MAP_EVENT_EFFECT_DURATION, radius_m: float = 70.0, card_style: String = "") -> Dictionary:
	var position := _wrap(world_position)
	return _push_event({
		"kind": kind,
		"position": position,
		"from": position,
		"to": position,
		"color": color,
		"label": _short_label(label),
		"life": maxf(0.1, duration),
		"duration": maxf(0.1, duration),
		"radius_m": maxf(1.0, radius_m),
		"card_style": card_style,
	})


func add_attack_effect(kind: String, from_position: Vector2, to_position: Vector2, color: Color, label: String = "", duration: float = 0.95, radius_m: float = 80.0, action_profile: Dictionary = {}) -> Dictionary:
	return _push_event({
		"kind": kind,
		"position": _wrap(to_position),
		"from": _wrap(from_position),
		"to": _wrap(to_position),
		"color": color,
		"label": _short_label(label),
		"life": maxf(0.1, duration),
		"duration": maxf(0.1, duration),
		"radius_m": maxf(1.0, radius_m),
		"motion_family": str(action_profile.get("motion_family", "")),
		"pose_key": str(action_profile.get("pose_key", "")),
		"effect_layer": str(action_profile.get("effect_layer", "")),
		"profile_key": str(action_profile.get("profile_key", "")),
		"range_meters": float(action_profile.get("range_meters", radius_m)),
		"knockback_meters": float(action_profile.get("knockback_meters", 0.0)),
		"throw_meters": float(action_profile.get("throw_meters", 0.0)),
		"impact_seconds": float(action_profile.get("impact_seconds", 0.45)),
	})


func add_monster_attack_effect(from_position: Vector2, to_position: Vector2, source: String, range_limit_m: float, color: Color, is_ranged: bool = false, action_profile: Dictionary = {}) -> Dictionary:
	var kind := "laser" if is_ranged or _source_looks_ranged(source, range_limit_m) else "melee"
	return add_attack_effect(kind, from_position, to_position, color, source, 1.05 if kind == "laser" else 0.82, range_limit_m, action_profile)


func add_district_damage_effect(index: int, center: Vector2, radius_m: float, source: String, color: Color = Color("#f97316")) -> Dictionary:
	if index < 0:
		return {}
	var kind := _district_damage_effect_kind(source)
	return add_map_event_effect(kind, center, color, source, 1.05 if kind == "stomp" else 0.90, radius_m)


func pulse_district(index: int, color: Color, duration: float = DISTRICT_PULSE_DURATION) -> Dictionary:
	if index < 0:
		return {"pulsed": false, "reason": "invalid_district"}
	var resolved_duration := maxf(0.1, duration)
	_district_pulses[str(index)] = {"life": resolved_duration, "duration": resolved_duration, "color": color}
	_revision += 1
	return {"pulsed": true, "district_index": index, "revision": _revision}


func public_snapshot() -> Dictionary:
	return {
		"movement_trails": _movement_trails.duplicate(true),
		"action_callouts": _action_callouts.duplicate(true),
		"map_event_effects": _map_event_effects.duplicate(true),
		"district_pulses": _district_pulses.duplicate(true),
		"revision": _revision,
	}


func districts_with_pulses(districts: Array) -> Array:
	var result := districts.duplicate(true)
	for key_variant in _district_pulses.keys():
		var index := int(str(key_variant))
		if index < 0 or index >= result.size() or not (result[index] is Dictionary):
			continue
		var pulse: Dictionary = _district_pulses.get(str(key_variant), {}) as Dictionary
		(result[index] as Dictionary)["pulse"] = float(pulse.get("life", 0.0))
		(result[index] as Dictionary)["pulse_color"] = pulse.get("color", Color.WHITE)
	return result


func debug_snapshot() -> Dictionary:
	return {
		"owner_authoritative": true,
		"movement_trail_count": _movement_trails.size(),
		"action_callout_count": _action_callouts.size(),
		"map_event_effect_count": _map_event_effects.size(),
		"district_pulse_count": _district_pulses.size(),
		"advance_count": _advance_count,
		"revision": _revision,
		"owns_save_schema": false,
	}


func _push_event(effect: Dictionary) -> Dictionary:
	_map_event_effects.append(effect)
	_trim(_map_event_effects, MAX_MAP_EVENT_EFFECTS)
	_revision += 1
	return effect.duplicate(true)


func _age_array(items: Array, delta: float) -> void:
	for index in range(items.size() - 1, -1, -1):
		if not (items[index] is Dictionary):
			items.remove_at(index)
			continue
		var item := items[index] as Dictionary
		item["life"] = maxf(0.0, float(item.get("life", 0.0)) - delta)
		if float(item.get("life", 0.0)) <= 0.0:
			items.remove_at(index)


func _trim(items: Array, limit: int) -> void:
	while items.size() > limit:
		items.pop_front()


func _data_array(value: Variant, limit: int) -> Array:
	var result: Array = []
	if value is Array:
		for item_variant in value:
			if item_variant is Dictionary:
				result.append((item_variant as Dictionary).duplicate(true))
	_trim(result, limit)
	return result


func _wrap(point: Vector2) -> Vector2:
	var result := point
	if _world_width_m > 0.0:
		result.x = fposmod(result.x, _world_width_m)
	if _world_height_m > 0.0:
		result.y = fposmod(result.y, _world_height_m)
	return result


func _wrapped_distance(from_position: Vector2, to_position: Vector2) -> float:
	var delta := (to_position - from_position).abs()
	if _world_width_m > 0.0:
		delta.x = minf(delta.x, absf(_world_width_m - delta.x))
	if _world_height_m > 0.0:
		delta.y = minf(delta.y, absf(_world_height_m - delta.y))
	return delta.length()


func _short_label(text: String, max_len: int = 9) -> String:
	return text if text.length() <= max_len else text.left(maxi(1, max_len - 1)) + "…"


func _district_damage_effect_kind(source: String) -> String:
	var text := source.to_lower()
	return "stomp" if text.contains("移动") or text.contains("冲撞") or text.contains("碾") or text.contains("践踏") or text.contains("自动破坏") or text.contains("暴走") or text.contains("资源吸取") or text.contains("落点") or text.contains("击退") else "impact"


func _source_looks_ranged(source: String, range_limit_m: float) -> bool:
	var text := source.to_lower()
	return range_limit_m > MELEE_RANGE_METERS + 1.0 or text.contains("光线") or text.contains("射线") or text.contains("激光") or text.contains("火花") or text.contains("炮") or text.contains("炸弹") or text.contains("breath") or text.contains("shot") or text.contains("beam")


func _sfx_key_for_callout(actor: String, action: String, detail: String) -> String:
	var text := "%s %s %s" % [actor, action, detail]
	if text.contains("赌局") or text.contains("下注") or text.contains("奖池") or text.contains("攻击") or text.contains("伤害") or text.contains("摧毁") or text.contains("轰击") or text.contains("击退"):
		return "impact"
	if text.contains("天气") or text.contains("警报") or text.contains("闪电") or text.contains("风暴") or text.contains("电磁"):
		return "storm"
	if text.contains("卡牌") or text.contains("合约") or text.contains("竞价") or text.contains("公开") or text.contains("签约") or text.contains("建造") or text.contains("城市") or text.contains("购买"):
		return "card"
	return ""


func _play_sfx(key: String, min_gap_seconds: float = 0.18) -> void:
	if key.is_empty() or DisplayServer.get_name() == "headless":
		return
	var player := _sfx_players.get(key, null) as AudioStreamPlayer
	if player == null or player.stream == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_sfx_last_time.get(key, -999.0)) < min_gap_seconds:
		return
	_sfx_last_time[key] = now
	player.stop()
	player.play()
