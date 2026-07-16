extends SceneTree

const CONTRACT_CONTROLLER_SCENE := preload("res://scenes/runtime/ContractRuntimeController.tscn")
const CONTRACT_BRIDGE_SCENE := preload("res://scenes/runtime/ContractRuntimeWorldBridge.tscn")
const VICTORY_CONTROLLER_SCRIPT := preload("res://scripts/runtime/victory_control_runtime_controller.gd")

var checks := 0
var failures: Array[String] = []


class FakeWorld:
	extends Node

	var game_time := 10.0
	var selected_trade_product := ""
	var resolved_card_history: Array = []
	var players: Array = [
		{"cash": 1000},
		{"cash": 1000},
		{"cash": 1000},
	]
	var districts: Array = [
		{
			"name": "供给区",
			"region_id": "region.source",
			"terrain": "land",
			"destroyed": false,
			"products": ["product.alpha"],
			"demands": [],
			"city": {"active": true, "products": [{"name": "product.alpha"}], "demands": []},
		},
		{
			"name": "需求区",
			"region_id": "region.target",
			"terrain": "land",
			"destroyed": false,
			"products": [],
			"demands": ["product.alpha"],
			"city": {"active": true, "products": [], "demands": ["product.alpha"]},
		},
	]

	func _product_catalog_names() -> Array:
		return ["product.alpha"]


class FakeVictoryWorldBridge:
	extends RefCounted

	var regions: Array = []

	func capture_world_snapshot(_clock_pause: Dictionary = {}, _settlement_checkpoint := "read_only") -> Dictionary:
		return {"regions": regions.duplicate(true), "players": [], "visibility_scope": "controller_private"}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := FakeWorld.new()
	get_root().add_child(world)
	var contract_bridge := CONTRACT_BRIDGE_SCENE.instantiate()
	var contract_controller := CONTRACT_CONTROLLER_SCENE.instantiate()
	var victory_controller := VICTORY_CONTROLLER_SCRIPT.new()
	world.add_child(contract_bridge)
	world.add_child(contract_controller)
	world.add_child(victory_controller)
	contract_bridge.bind_world(world)
	contract_controller.set_world_bridge(contract_bridge)
	contract_controller.configure({"ruleset_id": "v0.6", "timing": {"contract_window_seconds": 5.0}})
	var victory_world := FakeVictoryWorldBridge.new()
	victory_world.regions = [_region(0, "region.source", 1000, {"0": 600}), _region(1, "region.target", 10000, {"1": 6000, "2": 1000})]
	contract_bridge.set_region_control_runtime_dependencies(victory_controller, victory_world)

	var facts: Dictionary = contract_bridge.contract_facts(0, 1, "product.alpha")
	var target_fact: Dictionary = facts.get("target", {}) as Dictionary
	var target_city: Dictionary = target_fact.get("city", {}) as Dictionary
	var target_control: Dictionary = facts.get("target_region_control", {}) as Dictionary
	_expect(not target_city.has("projects"), "Contract world facts never read or expose district.city.projects")
	_expect(str(target_control.get("snapshot_kind", "")) == "commodity_gdp_region_control" and int(target_control.get("controller_player_index", -1)) == 1, "Contract consumes the authoritative VictoryControl region snapshot")

	var request := {
		"skill": {
			"name": "测试区域合约",
			"kind": "area_trade_contract",
			"contract_products": ["product.alpha"],
			"contract_add_products": 1,
			"contract_add_demands": 1,
		},
		"player_index": 0,
		"contract_offer_id": 41,
		"contract_source_district": 0,
		"contract_target_district": 1,
		"selected_product": "product.alpha",
		"transaction_id": "contract.offer.41",
	}
	var plan: Dictionary = contract_controller.plan_offer(request, facts)
	var offer: Dictionary = plan.get("offer", {}) as Dictionary
	_expect(bool(plan.get("planned", false)) and str(plan.get("contract_target_region_id", "")) == "region.target", "Offer binds the authoritative target region")
	_expect(not str(plan.get("contract_target_control_revision", "")).is_empty() and int(plan.get("contract_target_owner", -1)) == 1, "Offer binds control revision and controller")
	_expect(not _contains_legacy_project_binding_name(plan), "Offer plan contains no legacy project binding")

	contract_controller.pending_offers = [offer.duplicate(true)]
	var save: Dictionary = contract_controller.to_save_data()
	_expect(int(save.get("contract_runtime_schema_version", 0)) == 3 and not _contains_legacy_project_binding_name(save), "New save contains only region-control contract bindings")
	var restored := CONTRACT_CONTROLLER_SCENE.instantiate()
	world.add_child(restored)
	restored.set_world_bridge(contract_bridge)
	restored.configure({"ruleset_id": "v0.6", "timing": {"contract_window_seconds": 5.0}})
	var restore_result: Dictionary = restored.apply_save_data(save)
	_expect(bool(restore_result.get("applied", false)) and restored.pending_offers.size() == 1, "Region-control-bound offer round-trips")

	var response_request := {"player_index": 1, "contract_offer_id": 41, "accept": true}
	var response_plan: Dictionary = restored.plan_response(response_request, contract_bridge.contract_facts(0, 1, "product.alpha"))
	_expect(bool(response_plan.get("planned", false)), "Bound target controller may respond while the control snapshot is unchanged")

	victory_world.regions = [_region(0, "region.source", 1000, {"0": 600}), _region(1, "region.target", 12000, {"1": 7000, "2": 1000})]
	var revision_drift: Dictionary = restored.plan_response(response_request, contract_bridge.contract_facts(0, 1, "product.alpha"))
	_expect(not bool(revision_drift.get("planned", true)) and str(revision_drift.get("reason", "")) == "target_region_control_revision_drift", "GDP revision drift fails closed")

	victory_world.regions = [_region(0, "region.source", 1000, {"0": 600}), _region(1, "region.target", 10000, {"2": 6000, "1": 1000})]
	var controller_drift: Dictionary = restored.plan_response(response_request, contract_bridge.contract_facts(0, 1, "product.alpha"))
	_expect(not bool(controller_drift.get("planned", true)) and str(controller_drift.get("reason", "")) == "target_region_controller_drift", "Region controller drift fails closed")

	var before_rejected := JSON.stringify(restored.to_save_data())
	var legacy_save := save.duplicate(true)
	legacy_save["contract_runtime_schema_version"] = 2
	var rejected: Dictionary = restored.apply_save_data(legacy_save)
	_expect(not bool(rejected.get("applied", true)) and str(rejected.get("reason", "")) == "legacy_contract_save_schema_rejected", "Legacy project-bound save schema is explicitly rejected")
	_expect(before_rejected == JSON.stringify(restored.to_save_data()), "Rejected legacy save has zero side effects")
	var unversioned_legacy: Dictionary = save.duplicate(true)
	unversioned_legacy.erase("contract_runtime_schema_version")
	var unversioned_rejected: Dictionary = restored.apply_save_data(unversioned_legacy)
	_expect(not bool(unversioned_rejected.get("applied", true)) and str(unversioned_rejected.get("reason", "")) == "legacy_contract_save_schema_rejected", "Unversioned non-empty contract save is rejected instead of guessed")

	var bridge_source := FileAccess.get_file_as_string("res://scripts/runtime/contract_runtime_world_bridge.gd")
	var controller_source := FileAccess.get_file_as_string("res://scripts/runtime/contract_runtime_controller.gd")
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	_expect(not bridge_source.contains('city.get("projects"') and not controller_source.contains("func _target_project_authority"), "Production Contract source has no project-authority reader")
	_expect(coordinator_source.contains("set_region_control_runtime_dependencies") and coordinator_source.contains("victory_controller, victory_world_bridge"), "Coordinator injects the existing VictoryControl owner and bridge")

	print("Contract region-control authority v0.6 checks: %d" % checks)
	if failures.is_empty():
		print("Contract region-control authority v0.6 test passed.")
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _region(district_index: int, region_id: String, total_gdp_cents: int, player_gdp: Dictionary) -> Dictionary:
	return {
		"region_id": region_id,
		"district_index": district_index,
		"region_revision": 7,
		"lifecycle_state": "active",
		"destroyed": false,
		"region_gdp_per_minute_cents": total_gdp_cents,
		"player_gdp_by_index": player_gdp.duplicate(true),
	}


func _contains_key_recursive(value: Variant, needle: String) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if str(key_variant) == needle or _contains_key_recursive((value as Dictionary).get(key_variant), needle):
				return true
	elif value is Array:
		for item in value:
			if _contains_key_recursive(item, needle):
				return true
	return false


func _contains_legacy_project_binding_name(value: Variant) -> bool:
	for forbidden in [
		"contract_target_" + "project_ids",
		"target_" + "project_ids",
	]:
		if _contains_key_recursive(value, forbidden):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
