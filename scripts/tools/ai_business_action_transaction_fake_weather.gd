@tool
extends WeatherRuntimeController


func region_effect_snapshot(region_index: int, _context: Dictionary = {}) -> Dictionary:
	return {
		"region_index": region_index,
		"effects": [{
			"definition_id": "qa_market_weather",
			"event_id": 7001,
			"phase": "active",
			"intensity": 1.0,
			"economy": {
				"price_growth_multiplier": 1.10,
				"production_multiplier": 1.0,
				"demand_multiplier": 1.0,
			},
			"explanations": ["qa_market_weather"],
		}],
	}


func label(_definition_id: String) -> String:
	return "测试市场天气"
