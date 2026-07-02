extends RefCounted
class_name TopBarSnapshot

var phase_text: String = ""
var turn_text: String = ""
var identity_text: String = ""
var cash_text: String = ""
var gdp_text: String = ""
var goal_text: String = ""
var selected_district_text: String = ""
var primary_action_text: String = ""
var weather_status_text: String = ""


func apply_dictionary(data: Dictionary) -> RefCounted:
	phase_text = str(data.get("phase", "阶段｜开局"))
	turn_text = str(data.get("turn", data.get("seat", "席位｜1/4")))
	identity_text = _first_text(data, ["identity", "player", "player_name"], "未开局")
	cash_text = _first_text(data, ["cash_text", "cash", "money"], "¥ --")
	gdp_text = _first_text(data, ["gdp_text", "gdp"], "--/s")
	goal_text = _first_text(data, ["goal_text", "goal", "target"], "--")
	selected_district_text = _first_text(data, ["selected_district", "selected_district_summary", "selected_region", "district"], "未选择")
	primary_action_text = _first_text(data, ["primary_action", "primary_action_label", "next_action", "action"], "查看地图")
	weather_status_text = _first_text(data, ["weather_status", "weather", "forecast"], "天气:无影响｜预报:暂无")
	return self


func to_ui_dictionary() -> Dictionary:
	return {
		"phase": phase_text,
		"turn": turn_text,
		"identity": identity_text,
		"cash_text": cash_text,
		"gdp_text": gdp_text,
		"goal_text": goal_text,
		"selected_district": selected_district_text,
		"primary_action": primary_action_text,
		"weather_status": weather_status_text,
		"resources": "%s   GDP %s   目标 %s" % [cash_text, gdp_text, goal_text],
	}


func _first_text(data: Dictionary, keys: Array, fallback: String) -> String:
	for key in keys:
		if data.has(key):
			var value := str(data.get(key, ""))
			if value.strip_edges() != "":
				return value
	return fallback
