extends RefCounted
class_name ScenarioLabShowcaseAdapter

const SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/visual_event_snapshot.gd")

const SAFE_SCENARIOS := ["first_table", "monster_pressure", "public_track_intro", "bid_practice"]
const FORBIDDEN_PRIVATE_KEYS := [
	"true_owner",
	"owner_truth",
	"hidden_owner",
	"opponent_private",
	"private_cash",
	"rival_private",
	"ai_score",
	"exact_score",
	"decision_sample",
	"score_bucket",
]
const AUDIO_BY_EVENT_CLASS := {
	"card_play": "card_play",
	"card_reveal": "card_reveal",
	"target_arrow": "ui_hover",
	"monster_spawn": "monster_spawn",
	"monster_move": "monster_move",
	"monster_attack": "monster_attack",
	"city_damage": "city_damage",
	"route_damage": "route_damage",
	"cash_gain": "cash_gain",
	"gdp_delta": "gdp_delta",
	"final_countdown": "final_countdown",
}


func normalize_payload(payload: Dictionary, fallback_stage: Dictionary = {}) -> Dictionary:
	var scenario_id := _safe_scenario_id(str(payload.get("scenario_id", payload.get("id", fallback_stage.get("scenario_ids", ["first_table"])[0] if fallback_stage.get("scenario_ids", []) is Array and not (fallback_stage.get("scenario_ids", []) as Array).is_empty() else "first_table"))))
	var stage_id := str(payload.get("stage_id", fallback_stage.get("id", "%s_bridge_stage" % scenario_id))).strip_edges()
	if stage_id == "":
		stage_id = "%s_bridge_stage" % scenario_id
	var events := SNAPSHOT_SCRIPT.normalize_events(_events_from_payload(payload, fallback_stage))
	var audio_hooks := _audio_hooks_from_payload(payload, fallback_stage, events)
	var leak_fields := _private_leak_fields(payload)
	return {
		"id": stage_id,
		"scenario_ids": [scenario_id],
		"title": _player_text(payload.get("title", fallback_stage.get("title", _default_title(scenario_id)))),
		"inspector": _player_text(payload.get("inspector", payload.get("coach_copy", fallback_stage.get("inspector", _default_inspector(scenario_id))))),
		"events": events,
		"event_classes": SNAPSHOT_SCRIPT.event_classes(events),
		"audio_hooks": audio_hooks,
		"targeting": _targeting_from_payload(payload, fallback_stage),
		"source": "scenario_lab_visual_events",
		"hidden_info_safe": leak_fields.is_empty(),
		"rejected_private_fields": leak_fields,
	}


func is_payload_safe(payload: Dictionary) -> bool:
	return _private_leak_fields(payload).is_empty()


func scenario_contract_from_payload(payload: Dictionary) -> Dictionary:
	var snapshot := normalize_payload(payload)
	return {
		"id": (snapshot.get("scenario_ids", ["first_table"]) as Array)[0],
		"stage_ids": [snapshot.get("id", "")],
		"event_classes": snapshot.get("event_classes", []),
		"audio_hooks": snapshot.get("audio_hooks", []),
		"hidden_info_safe": bool(snapshot.get("hidden_info_safe", false)),
		"rejected_private_fields": snapshot.get("rejected_private_fields", []),
	}


func _events_from_payload(payload: Dictionary, fallback_stage: Dictionary) -> Array:
	var events_variant: Variant = payload.get("visual_events", payload.get("events", fallback_stage.get("events", [])))
	var events: Array = events_variant if events_variant is Array else []
	return events


func _audio_hooks_from_payload(payload: Dictionary, fallback_stage: Dictionary, events: Array) -> Array[String]:
	var hooks: Array[String] = []
	var hook_variant: Variant = payload.get("audio_hooks", fallback_stage.get("audio_hooks", []))
	var provided_hooks: Array = hook_variant if hook_variant is Array else []
	for item in provided_hooks:
		_append_unique(hooks, str(item))
	for event_class in SNAPSHOT_SCRIPT.event_classes(events):
		_append_unique(hooks, str(AUDIO_BY_EVENT_CLASS.get(event_class, "")))
	return hooks


func _targeting_from_payload(payload: Dictionary, fallback_stage: Dictionary) -> Dictionary:
	var targeting_variant: Variant = payload.get("targeting", fallback_stage.get("targeting", {}))
	if not (targeting_variant is Dictionary):
		return {}
	var targeting: Dictionary = (targeting_variant as Dictionary).duplicate(true)
	if targeting.has("true_owner") or targeting.has("private_cash"):
		targeting.erase("true_owner")
		targeting.erase("private_cash")
	return targeting


func _safe_scenario_id(value: String) -> String:
	var cleaned := value.strip_edges()
	return cleaned if SAFE_SCENARIOS.has(cleaned) else "first_table"


func _player_text(value: Variant) -> String:
	var text := str(value).strip_edges()
	for forbidden in FORBIDDEN_PRIVATE_KEYS:
		text = text.replace(forbidden, "[hidden]")
	return text


func _private_leak_fields(value: Variant, path: String = "") -> Array[String]:
	var leaks: Array[String] = []
	if value is Dictionary:
		var dict: Dictionary = value
		for key_variant in dict.keys():
			var key := str(key_variant)
			var key_path := "%s.%s" % [path, key] if path != "" else key
			for forbidden in FORBIDDEN_PRIVATE_KEYS:
				if key.to_lower().contains(forbidden):
					_append_unique(leaks, key_path)
			for nested in _private_leak_fields(dict[key_variant], key_path):
				_append_unique(leaks, nested)
	elif value is Array:
		var array: Array = value
		for i in range(array.size()):
			for nested in _private_leak_fields(array[i], "%s[%d]" % [path, i]):
				_append_unique(leaks, nested)
	elif value is String:
		var lower_text := str(value).to_lower()
		for forbidden in FORBIDDEN_PRIVATE_KEYS:
			if lower_text.contains(forbidden):
				_append_unique(leaks, path)
	return leaks


func _append_unique(target: Array[String], value: String) -> void:
	var cleaned := value.strip_edges()
	if cleaned != "" and not target.has(cleaned):
		target.append(cleaned)


func _default_title(scenario_id: String) -> String:
	match scenario_id:
		"monster_pressure":
			return "怪兽压迫演出"
		"public_track_intro":
			return "公开牌轨演出"
		"bid_practice":
			return "竞价练习演出"
	return "首局桌面演出"


func _default_inspector(scenario_id: String) -> String:
	match scenario_id:
		"monster_pressure":
			return "Scenario Lab 事件驱动怪兽出现、攻击和城市受损演出。"
		"public_track_intro":
			return "Scenario Lab 事件驱动匿名公开牌轨和公开线索演出。"
		"bid_practice":
			return "Scenario Lab 事件驱动竞价指针和公开报价演出。"
	return "Scenario Lab 事件驱动首局桌面、手牌和资源演出。"
