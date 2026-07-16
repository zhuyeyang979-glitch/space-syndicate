extends SceneTree

const CURRENT_GATES := [
	"res://tests/commodity_flow_ambient_consumption_v06_test.gd",
	"res://tests/commodity_flow_market_backlog_v06_test.gd",
	"res://tests/commodity_flow_warehouse_then_waste_v06_test.gd",
	"res://tests/market_before_factory_integration_v06_test.gd",
	"res://tests/commodity_flow_backlog_save_roundtrip_v06_test.gd",
	"res://tests/commodity_flow_public_privacy_v06_test.gd",
]

var _failures: Array[String] = []


func _init() -> void:
	for path_variant in CURRENT_GATES:
		var path := str(path_variant)
		if not ResourceLoader.exists(path) or not (load(path) is Script):
			_failures.append("current gate missing: %s" % path)
	print("COMMODITY_FLOW_CURRENT_GATE_REDIRECT_V06_TEST|status=%s|gates=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		CURRENT_GATES.size(),
		_failures.size(),
	])
	quit(_failures.size())
