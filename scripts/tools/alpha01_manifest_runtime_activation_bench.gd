extends Node

const RULESET := preload("res://resources/rules/space_syndicate_ruleset_v04.tres")
const Loader := preload("res://scripts/runtime/alpha01_content_manifest_loader.gd")

@export_range(5.0, 60.0, 1.0) var mcp_inspection_seconds := 30.0

@onready var coordinator := $GameRuntimeCoordinator as GameRuntimeCoordinator
@onready var draft := $NewGameSetupDraftService as NewGameSetupDraftService
@onready var builder := $SessionStartPlanBuilder as SessionStartPlanBuilder


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var selection := Loader.load_active_selection()
	if not selection.is_valid():
		failures.append("selection_invalid:%s" % JSON.stringify(selection.errors))
	coordinator.configure(RULESET.debug_snapshot())
	await get_tree().process_frame
	draft.reset_to_defaults()
	var session := coordinator.get_node("GameSessionRuntimeController") as GameSessionRuntimeController
	var request := SessionStartRequest.create(
		"alpha01-runtime-activation-bench",
		draft.draft_snapshot(),
		session.session_start_revision(),
		"focused_test"
	)
	var rng := coordinator.get_node("RunRngService") as RunRngService
	var plan_result := builder.build_plan(request, rng.capture_plan_checkpoint())
	var plan := plan_result.get("plan") as SessionStartPlan
	if plan == null or not plan.is_valid():
		failures.append("formal_plan:%s" % str(plan_result.get("reason_code", "missing")))
	var plan_players: Array = plan.players if plan != null else []
	var role_indices: Array = []
	for player_variant in plan_players:
		if player_variant is Dictionary:
			role_indices.append(int((player_variant as Dictionary).get("role_index", -1)))
	if plan_players.size() != 4 or not _subset(role_indices, selection.role_source_indices()):
		failures.append("four_player_role_activation")
	var supply_result := coordinator.configure_region_supply_from_world(
		plan.region_supply_seed if plan != null else 1,
		plan.districts if plan != null else [],
		plan.card_pool if plan != null else [],
		4
	)
	var supply_debug := coordinator.region_supply_runtime_controller().debug_snapshot()
	var public_racks := coordinator.region_supply_public_rack()
	if not bool(supply_result.get("configured", false)) or int(supply_debug.get("legal_card_count", 0)) != 28 or JSON.stringify(public_racks).contains("bags_by_region"):
		failures.append("regional_supply_activation")
	var inventory := coordinator.commodity_card_inventory_runtime_controller()
	inventory.reset_state()
	var belt_result := inventory.initialize_default_belt_if_empty(plan.region_supply_seed if plan != null else 1, selection.commodity_track_card_ids)
	var belt := inventory.belt_snapshot()
	var belt_items: Dictionary = belt.get("items", {}) if belt.get("items", {}) is Dictionary else {}
	var belt_card_ids: Array = []
	for item_variant in belt_items.values():
		var item: Dictionary = item_variant if item_variant is Dictionary else {}
		var card: Dictionary = item.get("card", {}) if item.get("card", {}) is Dictionary else {}
		var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
		belt_card_ids.append(str(machine.get("card_id", "")))
	if not bool(belt_result.get("configured", false)) or belt_items.size() != 12 or not _same_set(belt_card_ids, selection.commodity_track_card_ids):
		failures.append("commodity_track_activation")
	var query := coordinator.get_node_or_null("DistrictSupplyRuntimeQueryPort")
	if query == null or bool(query.call("debug_snapshot").get("reads_future_supply_bag", true)):
		failures.append("ai_future_bag_privacy")
	var public_text := JSON.stringify({"selection": selection.public_activation_snapshot(), "racks": public_racks})
	for forbidden in ["player_cash", "private_hand", "ai_reasoning", "route_plan", "bags_by_region", "rng_state_by_region"]:
		if public_text.contains(forbidden):
			failures.append("privacy:%s" % forbidden)
	var status := "PASS" if failures.is_empty() else "FAIL"
	print("ALPHA01_MANIFEST_RUNTIME_ACTIVATION_BENCH|status=%s|players=%d|roles=%s|region_ids=%d|commodity_ids=%d|monsters=%d|map=%s|privacy_violations=%d|errors=%s" % [
		status,
		plan_players.size(),
		JSON.stringify(role_indices),
		int(supply_debug.get("legal_card_count", 0)),
		belt_items.size(),
		selection.monster_records.size(),
		str(selection.active_map.get("map_id", "")),
		failures.filter(func(value: String) -> bool: return value.begins_with("privacy:")).size(),
		JSON.stringify(failures),
	])
	get_tree().create_timer(mcp_inspection_seconds).timeout.connect(func() -> void: get_tree().quit(0 if failures.is_empty() else 1))


func _subset(values: Array, allowed: Array) -> bool:
	for value in values:
		if not allowed.has(value):
			return false
	return true


func _same_set(left: Array, right: Array) -> bool:
	var a := left.duplicate()
	var b := right.duplicate()
	a.sort()
	b.sort()
	return a == b
