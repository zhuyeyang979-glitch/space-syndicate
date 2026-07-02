extends RefCounted
class_name CityDamagePresenter


static func city_damage(at_point: Vector2, hp_delta: int, gdp_delta: int) -> Array:
	return [
		{"type": "city_damage_crack", "at": at_point, "label": "城市受损", "event_class": "city_damage"},
		{"type": "gdp_delta_float", "at": at_point + Vector2(70, 4), "label": "%+d GDP" % gdp_delta, "event_class": "gdp_delta"},
		{"type": "cash_gain_float", "at": at_point + Vector2(-70, 34), "label": "%+d HP" % hp_delta, "event_class": "cash_gain"},
	]
