extends SceneTree

const INVENTORY_SCENE := preload("res://scenes/runtime/CommodityCardInventoryRuntimeController.tscn")
const PROFILE := preload("res://resources/rules/space_syndicate_ruleset_v06.tres")
const CATALOG := preload("res://resources/cards/runtime/card_runtime_catalog_v06.tres")
const STATE_ADAPTER_SCRIPT := preload("res://scripts/cards/v06/production/card_player_state_production_adapter_v06.gd")
const ASSET_CONTROLLER_SCRIPT := preload("res://scripts/runtime/player_mana_runtime_controller.gd")
const FLOW_SCRIPT := preload("res://scripts/runtime/commodity_flow_runtime_controller.gd")
const INFRASTRUCTURE_SCRIPT := preload("res://scripts/runtime/region_infrastructure_runtime_controller.gd")
const CORE_ADAPTER_SCRIPT := preload("res://scripts/cards/v06/production/core_economic_card_runtime_adapter_v06.gd")
const TRANSACTION_SERVICE_SCRIPT := preload("res://scripts/cards/v06/card_flow_transaction_service_v06.gd")
const FACILITY_ADAPTER_SCRIPT := preload("res://scripts/cards/v06/effects/facility_card_effect_adapter_v06.gd")
const ROUTER_SCRIPT := preload("res://scripts/cards/v06/production/core_economic_card_effect_router_v06.gd")
const ASSET_IDS := ["life", "energy", "industry", "technology", "commerce", "shipping"]

var _checks := 0
var _failures: Array[String] = []


class RuntimeWorld:
	extends WorldSessionState


class LegacyInfrastructurePort:
	extends Node
	var target: Node

	func _init(owner: Node) -> void:
		target = owner

	func region_snapshot(region_id: String) -> Dictionary:
		return target.call("region_snapshot", region_id)

	func facilities_snapshot(include_tombstones := false) -> Array:
		return target.call("facilities_snapshot", include_tombstones)

	func slot_id(region_id: String, facility_type: String, industry_id := "") -> String:
		return str(target.call("slot_id", region_id, facility_type, industry_id))

	func apply_facility_action(request: Dictionary) -> Dictionary:
		return target.call("apply_facility_action", request)

	func rollback_facility_action(receipt: Variant) -> Dictionary:
		return target.call("rollback_facility_action", receipt)


class FlakyFinalizeInfrastructurePort:
	extends LegacyInfrastructurePort
	var finalize_attempts := 0

	func finalize_facility_action(receipt: Variant) -> Dictionary:
		finalize_attempts += 1
		if finalize_attempts == 1:
			return {
				"receipt_kind": "facility_action_finalize",
				"transaction_id": str((receipt as Dictionary).get("transaction_id", "")) if receipt is Dictionary else str(receipt),
				"committed": true,
				"finalized": false,
				"rollback_open": true,
				"reason_code": "injected_finalize_retry_required",
			}
		return target.call("finalize_facility_action", receipt)

	func facility_rollback_atomic_ready() -> bool:
		return bool(target.call("facility_rollback_atomic_ready"))

	func facility_action_checkpoint_status() -> Dictionary:
		return target.call("facility_action_checkpoint_status")


class FailingStatePort:
	extends Node
	var delegate: Node
	var infrastructure: Node
	var advance_owner_before_failure := false
	var failure_count := 0

	func _init(real_port: Node, owner: Node, advance_owner := false) -> void:
		delegate = real_port
		infrastructure = owner
		advance_owner_before_failure = advance_owner

	func actor_player_indices() -> Dictionary:
		return delegate.call("actor_player_indices")

	func register_player(actor_id: String, initial_state: Dictionary) -> Dictionary:
		return delegate.call("register_player", actor_id, initial_state)

	func read_player(actor_id: String) -> Dictionary:
		return delegate.call("read_player", actor_id)

	func reserve_transaction(transaction_id: String, intent_hash: String, expected_revisions: Dictionary, actor_ids: Array) -> Dictionary:
		return delegate.call("reserve_transaction", transaction_id, intent_hash, expected_revisions, actor_ids)

	func prepare_reserved_mutations(reservation_id: String, next_states: Dictionary) -> Dictionary:
		return delegate.call("prepare_reserved_mutations", reservation_id, next_states)

	func commit_reserved(reservation_id: String, _next_states: Dictionary, _effect_receipt: Dictionary) -> Dictionary:
		failure_count += 1
		if advance_owner_before_failure:
			infrastructure.call("apply_unit_damage", {
				"transaction_id": "fault-progress:%s" % reservation_id,
				"source_kind": "monster",
				"source_entity_id": "monster.fault",
				"region_id": "region.alpha",
				"amount": 1,
				"occurred_at": 3.0,
			})
		return {"committed": false, "reason_code": "injected_player_state_commit_failure", "reservation_id": reservation_id}

	func abort_reserved(reservation_id: String, reason_code: String) -> Dictionary:
		return delegate.call("abort_reserved", reservation_id, reason_code)

	func replay_result(transaction_id: String, intent_hash: String) -> Dictionary:
		return delegate.call("replay_result", transaction_id, intent_hash)

	func to_save_data() -> Dictionary:
		return delegate.call("to_save_data")

	func apply_save_data(data: Dictionary) -> Dictionary:
		return delegate.call("apply_save_data", data)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_real_facility_card_unlock_and_exact_once()
	_verify_finalize_failure_blocks_checkpoint_then_retries()
	_verify_missing_capability_remains_fail_closed()
	_verify_player_state_failure_compensates()
	_verify_owner_progression_reports_compensation_failure()
	_finish()


func _verify_real_facility_card_unlock_and_exact_once() -> void:
	var fixture := _production_fixture("success")
	var inventory: CommodityCardInventoryRuntimeController = fixture.get("inventory")
	var core: Node = fixture.get("core")
	var infrastructure: RegionInfrastructureRuntimeController = fixture.get("infrastructure")
	var world: RuntimeWorld = fixture.get("world")
	var assets: Node = fixture.get("assets")
	var before := inventory.player_snapshot("A")
	var play: Dictionary = core.call("play_card", "A", 0, _target(), int(before.get("revision", -1)), "facility-unlock-success")
	var finalization: Dictionary = play.get("effect_finalization", {}) if play.get("effect_finalization", {}) is Dictionary else {}
	_expect(bool(play.get("committed", false)), "real public facility card is unlocked through the unique inventory CardFlow path")
	_expect(bool(finalization.get("finalized", false)), "successful player-state commit explicitly finalizes the facility owner")
	_expect(infrastructure.facilities_snapshot(false).size() == 1 and _world_card_count(world) == 0, "one card creates exactly one facility and is consumed exactly once")
	_expect(_life_assets(assets) == 3, "rank-I facility card leaves the six-color asset owner unchanged")
	var facility: Dictionary = (infrastructure.facilities_snapshot(false)[0] as Dictionary).duplicate(true)
	var lifecycle := infrastructure.facility_action_lifecycle_snapshot("facility-unlock-success")
	_expect(str(facility.get("facility_type", "")) == "factory" and str(facility.get("industry_id", "")) == "life" and str(lifecycle.get("state", "")) == "finalized", "owner roster and lifecycle agree on the committed factory")
	_expect(bool(inventory.checkpoint_status().get("can_checkpoint", false)), "fully finalized facility transaction is checkpoint-safe")
	var replay: Dictionary = core.call("play_card", "A", 0, _target(), int(before.get("revision", -1)), "facility-unlock-success")
	_expect(bool(replay.get("idempotent_replay", false)) and infrastructure.facilities_snapshot(false).size() == 1 and _life_assets(assets) == 3 and _world_card_count(world) == 0, "terminal replay checks the journal before the now-empty hand slot")
	_cleanup(fixture)


func _verify_finalize_failure_blocks_checkpoint_then_retries() -> void:
	var real_owner := _new_infrastructure()
	var flaky := FlakyFinalizeInfrastructurePort.new(real_owner)
	root.add_child(flaky)
	var fixture := _production_fixture("retry", flaky, real_owner)
	var inventory: CommodityCardInventoryRuntimeController = fixture.get("inventory")
	var core: Node = fixture.get("core")
	var world: RuntimeWorld = fixture.get("world")
	var assets: Node = fixture.get("assets")
	var before := inventory.player_snapshot("A")
	var first: Dictionary = core.call("play_card", "A", 0, _target(), int(before.get("revision", -1)), "facility-finalize-retry")
	var first_finalization: Dictionary = first.get("effect_finalization", {}) if first.get("effect_finalization", {}) is Dictionary else {}
	_expect(bool(first.get("committed", false)) and not bool(first_finalization.get("finalized", true)), "finalize failure preserves the already committed player and owner facts")
	_expect(_world_card_count(world) == 0 and _life_assets(assets) == 3 and real_owner.facilities_snapshot(false).size() == 1, "failed finalize never double-spends or rolls back a successful player commit")
	_expect(not bool(inventory.checkpoint_status().get("can_checkpoint", true)), "failed finalize remains an explicit checkpoint blocker")
	var replay: Dictionary = core.call("play_card", "A", 0, _target(), int(before.get("revision", -1)), "facility-finalize-retry")
	var replay_finalization: Dictionary = replay.get("effect_finalization", {}) if replay.get("effect_finalization", {}) is Dictionary else {}
	_expect(bool(replay.get("idempotent_replay", false)) and bool(replay_finalization.get("finalized", false)), "same transaction replay retries only finalization")
	_expect(flaky.finalize_attempts == 2 and _world_card_count(world) == 0 and _life_assets(assets) == 3 and real_owner.facilities_snapshot(false).size() == 1, "finalization retry does not repeat card asset or facility mutation")
	_expect(bool(inventory.checkpoint_status().get("can_checkpoint", false)) and str(real_owner.facility_action_lifecycle_snapshot("facility-finalize-retry").get("state", "")) == "finalized", "owner-confirmed finalize closes the checkpoint blocker")
	_cleanup(fixture)
	flaky.free()


func _verify_missing_capability_remains_fail_closed() -> void:
	var real_owner := _new_infrastructure()
	var legacy := LegacyInfrastructurePort.new(real_owner)
	root.add_child(legacy)
	var fixture := _production_fixture("legacy", legacy, real_owner)
	var inventory: CommodityCardInventoryRuntimeController = fixture.get("inventory")
	var core: Node = fixture.get("core")
	var world: RuntimeWorld = fixture.get("world")
	var assets: Node = fixture.get("assets")
	var before := inventory.player_snapshot("A")
	var before_world := JSON.stringify(world.players)
	var result: Dictionary = core.call("play_card", "A", 0, _target(), int(before.get("revision", -1)), "facility-legacy-blocked")
	_expect(not bool(result.get("committed", true)) and str(result.get("reason_code", "")) == "facility_rollback_atomicity_unavailable", "missing finalize/readiness capability keeps the public facility card fail-closed")
	_expect(before_world == JSON.stringify(world.players) and _life_assets(assets) == 3 and real_owner.facilities_snapshot(false).is_empty(), "capability rejection changes no card asset cash or facility state")
	_cleanup(fixture)
	legacy.free()


func _verify_player_state_failure_compensates() -> void:
	var fixture := _transaction_fixture("compensate", false)
	var service: Object = fixture.get("service")
	var router: Object = fixture.get("router")
	var infrastructure: RegionInfrastructureRuntimeController = fixture.get("infrastructure")
	var world: RuntimeWorld = fixture.get("world")
	var assets: Node = fixture.get("assets")
	var registered: Dictionary = service.call("register_player", "A", {})
	var before: Dictionary = registered.get("player_state", {}) if registered.get("player_state", {}) is Dictionary else {}
	var result: Dictionary = service.call("play_card", "A", 0, _target(), router, int(before.get("revision", -1)), "facility-state-failure")
	_expect(not bool(result.get("committed", true)) and str(result.get("reason_code", "")) == "player_state_commit_failed" and bool(result.get("rolled_back", false)), "player-state commit failure reports successful owner compensation")
	_expect(infrastructure.facilities_snapshot(false).size() == 1 and _facility_rank(infrastructure) == 1 and _world_card_count(world) == 1 and _life_assets(assets) == 3, "rank-II compensation restores the rank-I facility card and asset facts with no partial upgrade")
	var lifecycle := infrastructure.facility_action_lifecycle_snapshot("facility-state-failure")
	_expect(str(lifecycle.get("state", "")) == "rolled_back" and not bool(lifecycle.get("rollback_open", true)), "compensated owner receipt is terminal and exact-once")
	_cleanup(fixture)


func _verify_owner_progression_reports_compensation_failure() -> void:
	var fixture := _transaction_fixture("compensation-failure", true)
	var service: Object = fixture.get("service")
	var router: Object = fixture.get("router")
	var infrastructure: RegionInfrastructureRuntimeController = fixture.get("infrastructure")
	var world: RuntimeWorld = fixture.get("world")
	var assets: Node = fixture.get("assets")
	var registered: Dictionary = service.call("register_player", "A", {})
	var before: Dictionary = registered.get("player_state", {}) if registered.get("player_state", {}) is Dictionary else {}
	var result: Dictionary = service.call("play_card", "A", 0, _target(), router, int(before.get("revision", -1)), "facility-compensation-failure")
	_expect(not bool(result.get("committed", true)) and str(result.get("reason_code", "")) == "effect_compensation_failed" and bool(result.get("compensation_failed", false)), "owner progression makes compensation failure explicit instead of pretending success")
	_expect(infrastructure.facilities_snapshot(false).size() == 1 and _facility_rank(infrastructure) == 2 and _world_card_count(world) == 1 and _life_assets(assets) == 3, "failed rank-II compensation preserves honest split facts for recovery without double charging player state")
	_expect(not bool(infrastructure.facility_rollback_atomic_ready()), "unresolved split owner state remains fail-closed")
	_cleanup(fixture)


func _production_fixture(label: String, infrastructure_port: Node = null, existing_infrastructure: RegionInfrastructureRuntimeController = null) -> Dictionary:
	var infrastructure := existing_infrastructure if existing_infrastructure != null else _new_infrastructure()
	var port: Node = infrastructure_port if infrastructure_port != null else infrastructure
	var flow := FLOW_SCRIPT.new() as CommodityFlowRuntimeController
	root.add_child(flow)
	_expect(bool(flow.configure(PROFILE.debug_snapshot()).get("configured", false)), "%s flow owner configures" % label)
	var assets := _asset_owner()
	var state := STATE_ADAPTER_SCRIPT.new() as CardPlayerStateProductionAdapterV06
	root.add_child(state)
	_expect(bool(state.configure(CATALOG, assets).get("configured", false)), "%s production state port configures" % label)
	var world := RuntimeWorld.new()
	world.players = [_player(_card("facility.factory.life.rank_1", "%s-card" % label))]
	root.add_child(world)
	_expect(bool(state.set_world_session_state(world).get("bound", false)), "%s production state port binds real player facts" % label)
	var inventory := INVENTORY_SCENE.instantiate() as CommodityCardInventoryRuntimeController
	root.add_child(inventory)
	_expect(bool(inventory.configure(PROFILE.debug_snapshot(), state, flow, port).get("configured", false)), "%s commodity inventory controller configures" % label)
	inventory.set_world_session_state(world)
	var core := CORE_ADAPTER_SCRIPT.new() as CoreEconomicCardRuntimeAdapterV06
	root.add_child(core)
	_expect(bool(core.configure(inventory, flow, port, {"A": 0}).get("configured", false)), "%s core effect adapter configures" % label)
	return {"infrastructure": infrastructure, "port": port, "flow": flow, "assets": assets, "state": state, "world": world, "inventory": inventory, "core": core}


func _transaction_fixture(label: String, advance_owner: bool) -> Dictionary:
	var infrastructure := _new_infrastructure()
	_seed_rank_i_factory(infrastructure, label)
	var assets := _asset_owner()
	var state := STATE_ADAPTER_SCRIPT.new() as CardPlayerStateProductionAdapterV06
	root.add_child(state)
	var world := RuntimeWorld.new()
	world.players = [_player(_card("facility.factory.life.rank_2", "%s-card" % label))]
	root.add_child(world)
	state.configure(CATALOG, assets)
	state.set_world_session_state(world)
	var failing := FailingStatePort.new(state, infrastructure, advance_owner)
	root.add_child(failing)
	var facility_adapter := FACILITY_ADAPTER_SCRIPT.new()
	_expect(bool(facility_adapter.configure(infrastructure, {"A": 0}).get("configured", false)), "%s facility adapter configures" % label)
	var router := ROUTER_SCRIPT.new()
	_expect(bool(router.configure({"build_upgrade_or_repair_facility": facility_adapter}).get("configured", false)), "%s router configures" % label)
	var service = TRANSACTION_SERVICE_SCRIPT.new(CATALOG, failing)
	return {"infrastructure": infrastructure, "assets": assets, "state": state, "failing": failing, "world": world, "router": router, "service": service}


func _new_infrastructure() -> RegionInfrastructureRuntimeController:
	var infrastructure := INFRASTRUCTURE_SCRIPT.new() as RegionInfrastructureRuntimeController
	root.add_child(infrastructure)
	_expect(bool(infrastructure.configure(PROFILE.debug_snapshot()).get("configured", false)), "real region infrastructure owner configures")
	_expect(bool(infrastructure.initialize_regions([{"region_id": "region.alpha", "terrain_id": "land", "neighbor_region_ids": [], "legacy_index": 0}]).get("initialized", false)), "real target region initializes")
	return infrastructure


func _seed_rank_i_factory(infrastructure: RegionInfrastructureRuntimeController, label: String) -> void:
	var receipt := infrastructure.apply_facility_action({
		"transaction_id": "seed-rank-i:%s" % label,
		"region_id": "region.alpha",
		"owner_kind": "player",
		"owner_player_index": 0,
		"facility_type": "factory",
		"industry_id": "life",
		"rank": 1,
		"occurred_at": 0.5,
	})
	_expect(bool(receipt.get("committed", false)), "%s rank-I fixture facility seeds" % label)
	var finalized := infrastructure.finalize_facility_action(receipt)
	_expect(bool(finalized.get("finalized", false)), "%s rank-I fixture facility finalizes" % label)


func _facility_rank(infrastructure: RegionInfrastructureRuntimeController) -> int:
	var facilities := infrastructure.facilities_snapshot(false)
	return int((facilities[0] as Dictionary).get("rank", 0)) if not facilities.is_empty() and facilities[0] is Dictionary else 0


func _asset_owner() -> Node:
	var assets := ASSET_CONTROLLER_SCRIPT.new() as PlayerManaRuntimeController
	root.add_child(assets)
	_expect(bool(assets.configure(PROFILE.debug_snapshot()).get("configured", false)), "real six-color asset owner configures")
	var pools: Dictionary = {}
	var remainders: Dictionary = {}
	for asset_id in ASSET_IDS:
		pools[asset_id] = 3000
		remainders[asset_id] = 0
	var result: Dictionary = assets.apply_save_data({
		"state_version": 1,
		"ruleset_id": "v0.6",
		"current_game_time": 0.0,
		"revision": 1,
		"pools_by_player": {"0": pools},
		"recovery_remainders_by_player": {"0": remainders},
		"reservations": {},
		"terminal_receipts": {},
	})
	_expect(bool(result.get("applied", false)), "test assets load into the authoritative owner")
	return assets


func _player(card: Dictionary) -> Dictionary:
	return {"id": 0, "actor_id": "A", "name": "Player A", "cash": 100, "cash_cents": 10000, "slots": [card]}


func _card(card_id: String, instance_id: String) -> Dictionary:
	var card: Dictionary = CATALOG.card_snapshot(card_id)
	card["runtime_instance_id"] = instance_id
	return card


func _target() -> Dictionary:
	return {"valid": true, "target_kind": "region_unique_facility_slot", "region_id": "region.alpha", "slot_id": "region.alpha::factory.life", "industry_id": "life", "game_time": 2.0}


func _life_assets(owner: Node) -> int:
	var snapshot: Dictionary = owner.call("availability_snapshot", 0)
	return int((snapshot.get("assets", {}) as Dictionary).get("life", -1))


func _world_card_count(world: RuntimeWorld) -> int:
	var player: Dictionary = world.players[0] if not world.players.is_empty() and world.players[0] is Dictionary else {}
	var count := 0
	for card_variant in player.get("slots", []) as Array:
		if card_variant is Dictionary:
			count += 1
	return count


func _cleanup(fixture: Dictionary) -> void:
	var freed: Dictionary = {}
	for key in ["core", "inventory", "flow", "failing", "state", "world", "assets", "infrastructure"]:
		var value: Variant = fixture.get(key)
		if value is Object and is_instance_valid(value) and not freed.has(value.get_instance_id()):
			freed[value.get_instance_id()] = true
			(value as Object).free()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("FACILITY_CARD_PRODUCTION_UNLOCK_V06_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("FACILITY_CARD_PRODUCTION_UNLOCK_V06_TEST|status=FAIL|checks=%d|failures=%d" % [_checks, _failures.size()])
	quit(1)
