extends Node

const PROFILE := preload("res://resources/rules/space_syndicate_ruleset_v04.tres")
const CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v06.tres"
const ORGANIZATION_OWNER_SCRIPT_PATH := "res://scripts/runtime/player_organization_runtime_controller.gd"
const CARD_FLOW_SCRIPT_PATH := "res://scripts/cards/v06/card_flow_transaction_service_v06.gd"
const ACTOR_ID := "bench.organization.human"
const CARD_ID := "organization.deep_space_archive.rank_1"
const ORGANIZATION_EFFECT_KIND := "install_organization_upgrade"

class RuntimeWorld:
	extends Node
	var players: Array = []
	var districts: Array = []
	var game_time := 0.0

var _checks := 0
var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var coordinator := get_node_or_null("GameRuntimeCoordinator")
	_record("coordinator_scene", coordinator != null and coordinator.has_method("organization_consumer_readiness_snapshot"))
	var evidence := {
		"unique_organization_owner": false,
		"route_id": "",
		"effect_kind": "",
		"single_cardflow": false,
		"consumer_count": 0,
		"monster_provider_ready": false,
		"production_ready": false,
		"second_owner": true,
		"second_journal": true,
	}
	if coordinator != null:
		var organization_owner_count := 0
		for child in coordinator.find_children("*", "", true, false):
			var script_variant: Variant = child.get_script()
			if script_variant is Script and str((script_variant as Script).resource_path) == ORGANIZATION_OWNER_SCRIPT_PATH:
				organization_owner_count += 1
		evidence["unique_organization_owner"] = organization_owner_count == 1
		evidence["second_owner"] = organization_owner_count != 1
		_record("unique_organization_owner", organization_owner_count == 1)

		var catalog := load(CATALOG_PATH)
		var catalog_ready := catalog != null and catalog.has_method("reload") and bool((catalog.call("reload") as Dictionary).get("valid", false))
		_record("catalog_ready", catalog_ready)
		var card: Dictionary = catalog.call("card_snapshot", CARD_ID) as Dictionary if catalog_ready else {}
		_record("canonical_organization_card", not card.is_empty())

		coordinator.call("configure", PROFILE.debug_snapshot())
		var world := RuntimeWorld.new()
		world.players = [{
			"id": 0,
			"actor_id": ACTOR_ID,
			"name": "Organization Bench Human",
			"cash": 20,
			"cash_cents": 2000,
			"slots": [card.duplicate(true)],
		}]
		add_child(world)
		var queue := coordinator.get_node_or_null("CardResolutionQueueRuntimeService")
		if queue != null and queue.has_method("replace_state"):
			queue.call("replace_state", {
				"current_queue": [], "active_entry": {}, "next_queue": [],
				"resolution_sequence": 0, "last_group_window_sequence": 2, "revision": 7,
			})
		var binding: Dictionary = coordinator.call("refresh_v06_production_player_bindings", world)
		_record("organization_owner_binding", bool(binding.get("organization_owner_ready", false)))

		var route: Dictionary = coordinator.call("v06_runtime_card_route", card)
		evidence["route_id"] = str(route.get("route_id", ""))
		evidence["effect_kind"] = str(route.get("effect_kind", ""))
		_record(
			"field_driven_organization_route",
			str(route.get("route_id", "")) == "core_economic_card_runtime"
				and str(route.get("effect_kind", "")) == ORGANIZATION_EFFECT_KIND
		)

		var core := coordinator.get_node_or_null("CoreEconomicCardRuntimeAdapterV06")
		var core_debug: Dictionary = core.call("debug_snapshot") if core != null and core.has_method("debug_snapshot") else {}
		var inventory := coordinator.get_node_or_null("CommodityCardInventoryRuntimeController")
		var inventory_debug: Dictionary = inventory.call("debug_snapshot") if inventory != null and inventory.has_method("debug_snapshot") else {}
		var single_cardflow := bool(core_debug.get("uses_shared_card_source_transaction_service", false)) \
			and not bool(core_debug.get("owns_hand_state", true)) \
			and not bool(core_debug.get("owns_cash_state", true)) \
			and str(inventory_debug.get("card_flow_api_script", "")) == CARD_FLOW_SCRIPT_PATH
		evidence["single_cardflow"] = single_cardflow
		evidence["second_journal"] = not single_cardflow
		_record("single_cardflow_owner_and_journal", single_cardflow)

		var readiness: Dictionary = coordinator.call("organization_consumer_readiness_snapshot")
		var consumers: Dictionary = readiness.get("consumers", {}) if readiness.get("consumers", {}) is Dictionary else {}
		var required_domains := ["asset_recovery", "hand_limit", "card_window", "monster_binding", "military_command"]
		var all_domains_present := consumers.size() == required_domains.size()
		for domain in required_domains:
			all_domains_present = all_domains_present and consumers.has(domain)
		evidence["consumer_count"] = consumers.size()
		evidence["monster_provider_ready"] = bool((consumers.get("monster_binding", {}) as Dictionary).get("ready", false))
		evidence["production_ready"] = bool(readiness.get("production_ready", false))
		_record("five_readiness_domains", all_domains_present)
		_record("b7_monster_provider_wired", bool(evidence["monster_provider_ready"]))
		_record("incomplete_consumers_fail_closed", not bool(evidence["production_ready"]))
		_record("checkpoint_forwarding", coordinator.call("player_organization_checkpoint_status").has("can_checkpoint"))
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("ORGANIZATION_PRODUCTION_COMPOSITION_V06_BENCH|status=%s|checks=%d|failures=%d|details=%s|evidence=%s" % [status, _checks, _failures.size(), JSON.stringify(_failures), JSON.stringify(evidence)])
	# MCP owns the production Bench lifecycle so debug output can be inspected
	# before the project is stopped. A failure stays visible instead of exiting
	# before get_debug_output can collect it.
	if not _failures.is_empty():
		push_error("Organization production composition Bench failed: %s" % JSON.stringify(_failures))


func _record(label: String, passed: bool) -> void:
	_checks += 1
	if not passed:
		_failures.append(label)
