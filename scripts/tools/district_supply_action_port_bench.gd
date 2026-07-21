extends Node


func _ready() -> void:
	var coordinator := get_node_or_null("GameRuntimeCoordinator") as GameRuntimeCoordinator
	var port := coordinator.district_supply_action_port() if coordinator != null else null
	var checks := [
		coordinator != null,
		port != null,
		port is DistrictSupplyActionPort,
		bool(port.debug_snapshot().get("typed_intents", false)) if port != null else false,
		not bool(port.debug_snapshot().get("references_main", true)) if port != null else false,
		not bool(port.debug_snapshot().get("owns_region_supply", true)) if port != null else false,
		not bool(port.debug_snapshot().get("owns_inventory", true)) if port != null else false,
		not bool(port.debug_snapshot().get("owns_cash", true)) if port != null else false,
	]
	var passed := 0
	for check in checks:
		if bool(check):
			passed += 1
	print("DISTRICT_SUPPLY_ACTION_PORT_BENCH PASS %d/%d" % [passed, checks.size()])
	if passed != checks.size():
		push_error("DistrictSupplyActionPort production composition failed")
	await get_tree().create_timer(5.0).timeout
	get_tree().quit(0 if passed == checks.size() else 1)
