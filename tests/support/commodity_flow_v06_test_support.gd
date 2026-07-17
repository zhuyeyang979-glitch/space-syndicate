extends RefCounted

const PROFILE := preload("res://resources/rules/space_syndicate_ruleset_v06.tres")
const FLOW_SCRIPT := preload("res://scripts/runtime/commodity_flow_runtime_controller.gd")
const DEFAULT_PRODUCT_ID := "星露莓"
const SECOND_LIFE_PRODUCT_ID := "月壤葡萄"
const DEFAULT_PRICE_CENTS := 1000


class FactsBridge:
	extends Node

	var facts: Dictionary = {}
	var cash_by_player: Dictionary = {}
	var committed_receipts: Array = []
	var applied_batches: Dictionary = {}
	var reject_next_batch := false

	func capture_flow_facts() -> Dictionary:
		return facts.duplicate(true)

	func apply_sale_receipt_batch(batch: Dictionary) -> Dictionary:
		if reject_next_batch:
			reject_next_batch = false
			return {"applied": false, "reason": "injected_rejection"}
		var batch_id := str(batch.get("batch_id", ""))
		if batch_id.is_empty():
			return {"applied": false, "reason": "batch_id_missing"}
		if applied_batches.has(batch_id):
			return {
				"applied": true,
				"duplicate": true,
				"batch_id": batch_id,
				"receipt_count": int(applied_batches.get(batch_id, 0)),
			}
		var receipts: Array = batch.get("receipts", []) if batch.get("receipts", []) is Array else []
		for receipt_variant in receipts:
			if not (receipt_variant is Dictionary):
				return {"applied": false, "reason": "receipt_invalid"}
			var receipt: Dictionary = receipt_variant
			var owner_index := int(receipt.get("commodity_owner", -1))
			if owner_index < 0:
				return {"applied": false, "reason": "commodity_owner_invalid"}
			cash_by_player[owner_index] = int(cash_by_player.get(owner_index, 0)) + int(receipt.get("owner_net_cash", 0))
			committed_receipts.append(receipt.duplicate(true))
		applied_batches[batch_id] = receipts.size()
		return {
			"applied": true,
			"duplicate": false,
			"batch_id": batch_id,
			"receipt_count": receipts.size(),
		}


static func profile_snapshot() -> Dictionary:
	return PROFILE.call("debug_snapshot").duplicate(true)


static func create_fixture(
	tree: SceneTree,
	regions: Array,
	facilities: Array,
	routes: Array,
	prices: Dictionary = {DEFAULT_PRODUCT_ID: DEFAULT_PRICE_CENTS},
	custom_profile: Dictionary = {}
) -> Dictionary:
	var flow := FLOW_SCRIPT.new()
	var bridge := FactsBridge.new()
	bridge.facts = {
		"game_time": 0.0,
		"regions": regions.duplicate(true),
		"facilities": facilities.duplicate(true),
		"destroyed_facility_ids": [],
		"price_cents_by_commodity": prices.duplicate(true),
		"route_candidates": routes.duplicate(true),
	}
	tree.root.add_child(flow)
	tree.root.add_child(bridge)
	flow.call("set_world_bridge", bridge)
	var snapshot := custom_profile.duplicate(true) if not custom_profile.is_empty() else profile_snapshot()
	var configured: Dictionary = flow.call("configure", snapshot)
	return {
		"flow": flow,
		"bridge": bridge,
		"configured": configured,
	}


static func free_fixture(fixture: Dictionary) -> void:
	var flow: Variant = fixture.get("flow")
	var bridge: Variant = fixture.get("bridge")
	if flow is Node:
		(flow as Node).queue_free()
	if bridge is Node:
		(bridge as Node).queue_free()


static func region(
	region_id: String,
	neighbors: Array = [],
	terrain_id := "land",
	lifecycle_state := "active",
	integrity_basis_points := 10000
) -> Dictionary:
	return {
		"region_id": region_id,
		"revision": 1,
		"lifecycle_state": lifecycle_state,
		"integrity_basis_points": integrity_basis_points,
		"neighbor_region_ids": neighbors.duplicate(),
		"terrain_id": terrain_id,
	}


static func facility(
	facility_id: String,
	region_id: String,
	facility_type: String,
	owner_player_index := 0,
	industry_id := "life",
	rank := 1,
	owner_kind := "player"
) -> Dictionary:
	return {
		"facility_id": facility_id,
		"region_id": region_id,
		"facility_type": facility_type,
		"industry_id": industry_id,
		"rank": rank,
		"active": true,
		"owner_player_index": owner_player_index,
		"owner_kind": owner_kind,
	}


static func route(
	route_id: String,
	source_region_id: String,
	target_region_id: String,
	capacity_units_per_minute := 1000000,
	resource_id := "",
	mode_tags: Array = ["direct"],
	distance := 1
) -> Dictionary:
	var capacity_resource_id := resource_id if not resource_id.is_empty() else route_id
	return {
		"route_id": route_id,
		"commodity_id": "*",
		"source_region_id": source_region_id,
		"market_region_id": target_region_id,
		"ordered_region_ids": [source_region_id] if source_region_id == target_region_id else [source_region_id, target_region_id],
		"ordered_legs": [] if source_region_id == target_region_id else [{
			"from_region_id": source_region_id,
			"to_region_id": target_region_id,
			"mode": str(mode_tags[0]) if not mode_tags.is_empty() else "direct",
		}],
		"mode_tags": mode_tags.duplicate(),
		"facility_ids": [],
		"capacity_resources": [{
			"resource_id": capacity_resource_id,
			"capacity_units_per_minute": capacity_units_per_minute,
		}],
		"actual_distance": distance,
		"shortest_legal_distance": distance,
		"bottleneck_units_per_minute": capacity_units_per_minute,
		"arrival_seconds": float(distance),
		"transfer_count": maxi(0, mode_tags.size() - 1),
		"expected_rents": [],
		"region_revision_fingerprint": "fixture-topology-v1",
	}


static func install(
	flow: Node,
	facility_record: Dictionary,
	commodity_id: String,
	direction: String,
	owner_player_index := 0,
	rank := 1,
	public_demand := false,
	installation_id := ""
) -> Dictionary:
	var transaction_id := "install:%s:%s:%s:%d" % [
		str(facility_record.get("facility_id", "")),
		commodity_id,
		direction,
		owner_player_index,
	]
	var request := {
		"transaction_id": transaction_id,
		"installation_id": installation_id,
		"facility_id": str(facility_record.get("facility_id", "")),
		"facility": facility_record.duplicate(true),
		"region_id": str(facility_record.get("region_id", "")),
		"commodity_id": commodity_id,
		"direction": direction,
		"installer_player_index": owner_player_index,
		"source_card_rank": rank,
		"color": str(facility_record.get("industry_id", "")),
	}
	var receipt: Dictionary = flow.call("install_public_demand" if public_demand else "install_commodity", request)
	if bool(receipt.get("committed", false)):
		receipt = flow.call("finalize_commodity_installation", receipt)
	return receipt


static func advance(
	flow: Node,
	bridge: FactsBridge,
	total_seconds: float,
	step_seconds := 1.0,
	clock_pause: Dictionary = {}
) -> Dictionary:
	var totals := {
		"advanced": true,
		"step_count": 0,
		"receipt_count": 0,
		"market_sold_milliunits": 0,
		"ambient_consumed_milliunits": 0,
		"stored_milliunits": 0,
		"wasted_milliunits": 0,
		"market_backlog_milliunits": 0,
	}
	var elapsed := 0.0
	while elapsed < total_seconds - 0.000001:
		var delta := minf(step_seconds, total_seconds - elapsed)
		elapsed += delta
		bridge.facts["game_time"] = float(bridge.facts.get("game_time", 0.0)) + delta
		var result: Dictionary = flow.call("advance_world", delta, clock_pause)
		totals["step_count"] = int(totals.get("step_count", 0)) + 1
		if not bool(result.get("advanced", false)):
			totals["advanced"] = false
			totals["reason"] = str(result.get("reason", ""))
			break
		for field_name in [
			"receipt_count",
			"market_sold_milliunits",
			"ambient_consumed_milliunits",
			"stored_milliunits",
			"wasted_milliunits",
		]:
			totals[field_name] = int(totals.get(field_name, 0)) + int(result.get(field_name, 0))
		totals["market_backlog_milliunits"] = int(result.get("market_backlog_milliunits", 0))
	return totals
