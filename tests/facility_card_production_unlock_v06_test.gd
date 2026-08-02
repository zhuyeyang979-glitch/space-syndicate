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


class PrepareOnlyEffectRouter:
	extends RefCounted
	var prepare_count := 0

	func prepare_effect(_intent: Dictionary) -> Dictionary:
		prepare_count += 1
		return {"prepared": true}


class UnverifiedAbortEffectRouter:
	extends RefCounted
	var prepare_count := 0
	var abort_count := 0

	func prepare_effect(intent: Dictionary) -> Dictionary:
		prepare_count += 1
		var prepared := intent.duplicate(true)
		prepared["prepared"] = true
		prepared["prepared_token"] = "unverified-abort-token"
		return prepared

	func abort_prepared_effect(_prepared: Dictionary) -> void:
		abort_count += 1


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
	_verify_facility_target_preflight_contract()
	_verify_facility_preflight_requires_abort_capability()
	_verify_occupied_facility_target_preflight()
	_verify_owned_facility_upgrade_and_repair_preflight()
	_verify_direct_facility_play_is_closed_and_queue_lifecycle_remains_available()
	_verify_missing_capability_remains_fail_closed()
	_verify_player_state_failure_compensates()
	_verify_owner_progression_reports_compensation_failure()
	_finish()


func _verify_facility_target_preflight_contract() -> void:
	var fixture := _production_fixture("preflight-empty")
	var core: CoreEconomicCardRuntimeAdapterV06 = fixture.get("core")
	var before := _preflight_owner_snapshots(fixture)
	var first := core.preflight_facility_target(0, 0, "facility.factory.life.rank_1", "region.alpha", 2.0)
	var middle := _preflight_owner_snapshots(fixture)
	var second := core.preflight_facility_target(0, 0, "facility.factory.life.rank_1", "region.alpha", 2.0)
	var after := _preflight_owner_snapshots(fixture)
	var router: Dictionary = core.debug_snapshot().get("router", {})
	_expect(bool(first.get("ready", false)) and str(first.get("reason_code", "")) == "public_facility_target_ready", "empty facility slot passes the final adapter prepare preflight")
	_expect(bool(second.get("ready", false)), "repeated facility preflight remains stable")
	_expect(before.get("facility") == middle.get("facility") and middle.get("facility") == after.get("facility"), "facility owner state is byte-stable across repeated preflight")
	_expect(before.get("flow") == middle.get("flow") and middle.get("flow") == after.get("flow"), "commodity-flow owner state is byte-stable across repeated preflight")
	_expect(before.get("player") == middle.get("player") and middle.get("player") == after.get("player"), "player and hand state are byte-stable across repeated preflight")
	_expect(before.get("journal") == middle.get("journal") and middle.get("journal") == after.get("journal"), "inventory transaction journal is byte-stable across repeated preflight")
	_expect(int(router.get("pending_transaction_count", -1)) == 0, "repeated preflight aborts every prepared router record")
	var ui := _facility_ui_actionability(fixture, "facility.factory.life.rank_1")
	var inventory: CommodityCardInventoryRuntimeController = fixture.get("inventory")
	var player := inventory.player_snapshot("A")
	var play := core.play_card("A", 0, _target(), int(player.get("revision", -1)), "v06-play:A:preflight-empty-card:region.alpha")
	var after_direct := _preflight_owner_snapshots(fixture)
	_expect(bool(ui.get("actionable", false)) and not bool(play.get("committed", true)) and str(play.get("reason_code", "")) == "v06_facility_requires_game_action_spine", "facility target eligibility remains readable while the retired direct runtime play surface fails closed|ui=%s|play=%s" % [JSON.stringify(ui), JSON.stringify(play)])
	_expect(after == after_direct, "rejected direct facility play changes no facility, flow, player, or journal state")
	_expect(bool(ui.get("privacy_safe", false)), "facility hand eligibility exposes no machine, runtime-instance, actor, or owner truth")
	_cleanup(fixture)


func _verify_facility_preflight_requires_abort_capability() -> void:
	var fixture := _production_fixture("preflight-abort-capability")
	var core: CoreEconomicCardRuntimeAdapterV06 = fixture.get("core")
	var prepare_only := PrepareOnlyEffectRouter.new()
	core.set("_effect_router", prepare_only)
	var result := core.preflight_facility_target(0, 0, "facility.factory.life.rank_1", "region.alpha", 2.0)
	_expect(not bool(result.get("ready", true)) and str(result.get("reason_code", "")) == "public_facility_preflight_unavailable", "facility preflight fails closed when the router cannot abort prepared effects")
	_expect(prepare_only.prepare_count == 0, "missing abort capability is rejected before prepare can create residue")
	_cleanup(fixture)

	var receipt_fixture := _production_fixture("preflight-abort-receipt")
	var receipt_core: CoreEconomicCardRuntimeAdapterV06 = receipt_fixture.get("core")
	var unverified := UnverifiedAbortEffectRouter.new()
	receipt_core.set("_effect_router", unverified)
	var receipt_result := receipt_core.preflight_facility_target(0, 0, "facility.factory.life.rank_1", "region.alpha", 2.0)
	_expect(not bool(receipt_result.get("ready", true)) and str(receipt_result.get("reason_code", "")) == "public_facility_preflight_unavailable", "void abort cannot certify a prepared facility preflight")
	_expect(unverified.prepare_count == 1 and unverified.abort_count == 1, "unverified abort path is exercised once and remains fail-closed")
	_cleanup(receipt_fixture)


func _verify_occupied_facility_target_preflight() -> void:
	for owner_case in [
		{"label": "other-player", "owner_kind": "player", "owner_player_index": 1},
		{"label": "neutral", "owner_kind": "neutral", "owner_player_index": -1},
	]:
		var label := str(owner_case.get("label", "occupied"))
		var fixture := _production_fixture("preflight-%s" % label)
		var infrastructure: RegionInfrastructureRuntimeController = fixture.get("infrastructure")
		_seed_facility_owner(infrastructure, label, str(owner_case.get("owner_kind", "neutral")), int(owner_case.get("owner_player_index", -1)), 1)
		var core: CoreEconomicCardRuntimeAdapterV06 = fixture.get("core")
		var before := _preflight_owner_snapshots(fixture)
		var first := core.preflight_facility_target(0, 0, "facility.factory.life.rank_1", "region.alpha", 2.0)
		var second := core.preflight_facility_target(0, 0, "facility.factory.life.rank_1", "region.alpha", 2.0)
		var after := _preflight_owner_snapshots(fixture)
		var router: Dictionary = core.debug_snapshot().get("router", {})
		_expect(not bool(first.get("ready", true)) and str(first.get("reason_code", "")) == "public_facility_slot_occupied", "%s occupied slot is rejected without disclosing its owner class" % label)
		_expect(not bool(second.get("ready", true)) and int(router.get("pending_transaction_count", -1)) == 0, "%s rejection remains stable with no prepared residue" % label)
		_expect(before == after, "%s occupied-slot preflight changes no facility, flow, player, or journal state" % label)
		var ui := _facility_ui_actionability(fixture, "facility.factory.life.rank_1")
		var inventory: CommodityCardInventoryRuntimeController = fixture.get("inventory")
		var player := inventory.player_snapshot("A")
		var play := core.play_card("A", 0, _target(), int(player.get("revision", -1)), "v06-play:A:preflight-%s-card:region.alpha" % label)
		_expect(not bool(ui.get("actionable", true)) and not bool(play.get("committed", true)) and str(play.get("reason_code", "")) == "v06_facility_requires_game_action_spine", "%s disabled facility hand action and the retired direct runtime surface both fail closed" % label)
		_expect(str(ui.get("reason_code", "")) == "public_facility_slot_occupied" and bool(ui.get("readable", false)), "%s hand state carries a readable, target-specific rejection" % label)
		var ui_facts: Dictionary = ui.get("facts", {}) if ui.get("facts", {}) is Dictionary else {}
		_expect(int(ui_facts.get("selected_district", -1)) == 0 and str(ui.get("reason_code", "")) == "public_facility_slot_occupied", "%s keeps the invalid current selection instead of silently switching to the empty second region" % label)
		_expect(bool(ui.get("privacy_safe", false)), "%s hand rejection leaks no machine, runtime-instance, actor, or owner truth" % label)
		_cleanup(fixture)


func _verify_owned_facility_upgrade_and_repair_preflight() -> void:
	var upgrade_fixture := _production_fixture("preflight-upgrade", null, null, "facility.factory.life.rank_2")
	var upgrade_infrastructure: RegionInfrastructureRuntimeController = upgrade_fixture.get("infrastructure")
	_seed_facility_owner(upgrade_infrastructure, "owned-upgrade", "player", 0, 1)
	var upgrade_core: CoreEconomicCardRuntimeAdapterV06 = upgrade_fixture.get("core")
	var upgrade := upgrade_core.preflight_facility_target(0, 0, "facility.factory.life.rank_2", "region.alpha", 2.0)
	var upgrade_ui := _facility_ui_actionability(upgrade_fixture, "facility.factory.life.rank_2")
	var upgrade_inventory: CommodityCardInventoryRuntimeController = upgrade_fixture.get("inventory")
	var upgrade_player := upgrade_inventory.player_snapshot("A")
	var upgrade_play := upgrade_core.play_card("A", 0, _target(), int(upgrade_player.get("revision", -1)), "v06-play:A:preflight-upgrade-card:region.alpha")
	_expect(bool(upgrade.get("ready", false)), "higher-rank card remains eligible against the viewer's own matching facility")
	_expect(bool(upgrade_ui.get("actionable", false)) and not bool(upgrade_play.get("committed", true)) and str(upgrade_play.get("reason_code", "")) == "v06_facility_requires_game_action_spine", "actionable owned Rank-II upgrade is still required to enter through the GameAction spine|ui=%s|play=%s" % [JSON.stringify(upgrade_ui), JSON.stringify(upgrade_play)])
	_expect(_facility_rank(upgrade_infrastructure) == 1 and _facility_count_for_region(upgrade_infrastructure, "region.alpha") == 1 and _facility_count_for_region(upgrade_infrastructure, "region.beta") == 0, "rejected direct upgrade leaves the selected facility unchanged")
	_expect(int((upgrade_core.debug_snapshot().get("router", {}) as Dictionary).get("pending_transaction_count", -1)) == 0, "owned upgrade leaves no prepared router record")
	_cleanup(upgrade_fixture)

	var repair_fixture := _production_fixture("preflight-repair")
	var repair_infrastructure: RegionInfrastructureRuntimeController = repair_fixture.get("infrastructure")
	_seed_facility_owner(repair_infrastructure, "owned-repair", "player", 0, 1)
	var damage := repair_infrastructure.apply_unit_damage({
		"transaction_id": "owned-repair-damage",
		"source_kind": "monster",
		"source_entity_id": "monster.preflight",
		"region_id": "region.alpha",
		"amount": 20,
		"occurred_at": 1.0,
	})
	var repair_core: CoreEconomicCardRuntimeAdapterV06 = repair_fixture.get("core")
	var repair := repair_core.preflight_facility_target(0, 0, "facility.factory.life.rank_1", "region.alpha", 2.0)
	var repair_ui := _facility_ui_actionability(repair_fixture, "facility.factory.life.rank_1")
	var repair_inventory: CommodityCardInventoryRuntimeController = repair_fixture.get("inventory")
	var repair_player := repair_inventory.player_snapshot("A")
	var damage_before_repair := int(repair_infrastructure.region_snapshot("region.alpha").get("damage_taken", 0))
	var repair_play := repair_core.play_card("A", 0, _target(), int(repair_player.get("revision", -1)), "v06-play:A:preflight-repair-card:region.alpha")
	var damage_after_repair := int(repair_infrastructure.region_snapshot("region.alpha").get("damage_taken", -1))
	_expect(bool(damage.get("committed", false)) and bool(repair.get("ready", false)), "same-rank card remains eligible to repair the viewer's damaged matching facility")
	_expect(bool(repair_ui.get("actionable", false)) and not bool(repair_play.get("committed", true)) and str(repair_play.get("reason_code", "")) == "v06_facility_requires_game_action_spine", "actionable owned same-rank repair is still required to enter through the GameAction spine")
	_expect(damage_before_repair > 0 and damage_after_repair == damage_before_repair and _facility_count_for_region(repair_infrastructure, "region.beta") == 0, "rejected direct repair leaves facility damage unchanged")
	_expect(int((repair_core.debug_snapshot().get("router", {}) as Dictionary).get("pending_transaction_count", -1)) == 0, "owned repair leaves no prepared router record")
	_cleanup(repair_fixture)


func _verify_direct_facility_play_is_closed_and_queue_lifecycle_remains_available() -> void:
	var fixture := _production_fixture("direct-closed")
	var inventory: CommodityCardInventoryRuntimeController = fixture.get("inventory")
	var core: CoreEconomicCardRuntimeAdapterV06 = fixture.get("core")
	var infrastructure: RegionInfrastructureRuntimeController = fixture.get("infrastructure")
	var world: RuntimeWorld = fixture.get("world")
	var before := _preflight_owner_snapshots(fixture)
	var player := inventory.player_snapshot("A")
	var direct := core.play_card(
		"A",
		0,
		_target(),
		int(player.get("revision", -1)),
		"facility-direct-path-must-stay-closed"
	)
	var after := _preflight_owner_snapshots(fixture)
	_expect(not bool(direct.get("committed", true)) and str(direct.get("reason_code", "")) == "v06_facility_requires_game_action_spine", "public Core adapter play_card rejects facility effects with the stable Action Spine reason")
	_expect(before == after and infrastructure.facilities_snapshot(false).is_empty() and _world_card_count(world) == 1, "direct facility rejection reaches neither CardFlow nor the facility router handler")

	var source := FileAccess.get_file_as_string("res://scripts/cards/v06/production/core_economic_card_runtime_adapter_v06.gd")
	var play_offset := source.find("func play_card(")
	var debug_offset := source.find("func debug_snapshot()", play_offset)
	var play_body := source.substr(play_offset, debug_offset - play_offset) if play_offset >= 0 and debug_offset > play_offset else ""
	var guard_offset := play_body.find("if effect_kind == FACILITY_EFFECT_KIND:")
	var delegation_offset := play_body.find("\"play_core_card\",")
	_expect(guard_offset >= 0 and delegation_offset > guard_offset and play_body.count("FACILITY_ACTION_SPINE_REQUIRED_REASON") == 1, "source scan proves the facility guard dominates the only legacy CardFlow delegation; direct path count=0")

	for method_name in [
		"prepare_queued_facility_card",
		"commit_queued_facility_card",
		"rollback_queued_facility_card",
		"finalize_queued_facility_card",
	]:
		_expect(core.has_method(method_name), "Queue-only facility lifecycle retains %s" % method_name)
	var target_result := core.facility_target_context("A", 0, "facility.factory.life.rank_1", "region.alpha", 2.0)
	var target_context: Dictionary = target_result.get("target_context", {}) if target_result.get("target_context", {}) is Dictionary else {}
	var card := _card("facility.factory.life.rank_1", "direct-closed-card")
	var prepared := core.prepare_queued_facility_card("A", card, target_context, "facility-queue-finalize")
	var committed := core.commit_queued_facility_card(prepared)
	var effect_receipt: Dictionary = committed.get("effect_receipt", {}) if committed.get("effect_receipt", {}) is Dictionary else {}
	var finalize_preflight := core.preflight_finalize_queued_facility_card(effect_receipt)
	var finalized := core.finalize_queued_facility_card(effect_receipt)
	_expect(bool(target_result.get("ready", false)) and bool(prepared.get("prepared", false)) and bool(committed.get("committed", false)), "Queue-only prepare and commit remain operational")
	_expect(bool(finalize_preflight.get("ready", false)) and bool(finalized.get("finalized", false)), "Queue-only finalize remains operational")
	_expect(infrastructure.facilities_snapshot(false).size() == 1 and _world_card_count(world) == 1, "Queue effect lifecycle mutates only the facility Owner and leaves card escrow to the Queue bridge")
	_cleanup(fixture)

	var rollback_fixture := _production_fixture("queue-rollback")
	var rollback_core: CoreEconomicCardRuntimeAdapterV06 = rollback_fixture.get("core")
	var rollback_owner: RegionInfrastructureRuntimeController = rollback_fixture.get("infrastructure")
	var rollback_target_result := rollback_core.facility_target_context("A", 0, "facility.factory.life.rank_1", "region.alpha", 2.0)
	var rollback_target: Dictionary = rollback_target_result.get("target_context", {}) if rollback_target_result.get("target_context", {}) is Dictionary else {}
	var rollback_prepared := rollback_core.prepare_queued_facility_card("A", _card("facility.factory.life.rank_1", "queue-rollback-card"), rollback_target, "facility-queue-rollback")
	var rollback_committed := rollback_core.commit_queued_facility_card(rollback_prepared)
	var rollback_receipt: Dictionary = rollback_committed.get("effect_receipt", {}) if rollback_committed.get("effect_receipt", {}) is Dictionary else {}
	var rolled_back := rollback_core.rollback_queued_facility_card(rollback_receipt)
	_expect(bool(rollback_committed.get("committed", false)) and bool(rolled_back.get("rolled_back", false)), "Queue-only rollback remains operational")
	_expect(rollback_owner.facilities_snapshot(false).is_empty(), "Queue rollback removes the unfinalized facility mutation")
	_cleanup(rollback_fixture)


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
	_expect(not bool(result.get("committed", true)) and str(result.get("reason_code", "")) == "v06_facility_requires_game_action_spine", "legacy infrastructure capability cannot reopen the retired direct facility surface")
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


func _production_fixture(
	label: String,
	infrastructure_port: Node = null,
	existing_infrastructure: RegionInfrastructureRuntimeController = null,
	card_id: String = "facility.factory.life.rank_1"
) -> Dictionary:
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
	world.players = [_player(_card(card_id, "%s-card" % label))]
	world.districts = [
		{"region_id": "region.alpha", "name": "Alpha", "destroyed": false},
		{"region_id": "region.beta", "name": "Beta", "destroyed": false},
	]
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
	_expect(bool(infrastructure.initialize_regions([
		{"region_id": "region.alpha", "terrain_id": "land", "neighbor_region_ids": ["region.beta"], "legacy_index": 0},
		{"region_id": "region.beta", "terrain_id": "land", "neighbor_region_ids": ["region.alpha"], "legacy_index": 1},
	]).get("initialized", false)), "real target regions initialize")
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


func _seed_facility_owner(
	infrastructure: RegionInfrastructureRuntimeController,
	label: String,
	owner_kind: String,
	owner_player_index: int,
	rank: int
) -> void:
	var receipt := infrastructure.apply_facility_action({
		"transaction_id": "seed-owner:%s" % label,
		"region_id": "region.alpha",
		"owner_kind": owner_kind,
		"owner_player_index": owner_player_index,
		"facility_type": "factory",
		"industry_id": "life",
		"rank": rank,
		"occurred_at": 0.5,
	})
	_expect(bool(receipt.get("committed", false)), "%s occupied facility fixture seeds" % label)
	var finalized := infrastructure.finalize_facility_action(receipt)
	_expect(bool(finalized.get("finalized", false)), "%s occupied facility fixture finalizes" % label)


func _preflight_owner_snapshots(fixture: Dictionary) -> Dictionary:
	var infrastructure: RegionInfrastructureRuntimeController = fixture.get("infrastructure")
	var flow: CommodityFlowRuntimeController = fixture.get("flow")
	var inventory: CommodityCardInventoryRuntimeController = fixture.get("inventory")
	var world: RuntimeWorld = fixture.get("world")
	return {
		"facility": JSON.stringify({
			"save": infrastructure.to_save_data(),
			"region": infrastructure.region_snapshot("region.alpha"),
			"facilities": infrastructure.facilities_snapshot(true),
		}),
		"flow": JSON.stringify(flow.to_save_data()),
		"player": JSON.stringify({
			"inventory": inventory.player_snapshot("A"),
			"world_players": world.players,
		}),
		"journal": JSON.stringify(inventory.transaction_journal_snapshot()),
	}


func _facility_ui_actionability(fixture: Dictionary, card_id: String) -> Dictionary:
	var world: RuntimeWorld = fixture.get("world")
	var core: CoreEconomicCardRuntimeAdapterV06 = fixture.get("core")
	var selection := TableSelectionState.new()
	root.add_child(selection)
	selection.selected_district = 0
	var bridge := CardPlayEligibilityWorldBridge.new()
	root.add_child(bridge)
	bridge.set_world_session_state(world)
	bridge.set_table_selection_state(selection)
	bridge.set_facility_target_preflight_port(core)
	var service := CardPlayEligibilityRuntimeService.new()
	root.add_child(service)
	service.configure({"ruleset_id": "v0.6"})
	var skill := _facility_eligibility_skill(card_id)
	var facts := bridge.build_facts(0, skill, {"selected_district": 0, "slot_index": 0, "game_time": 2.0})
	var assets: PlayerManaRuntimeController = fixture.get("assets")
	facts["player_mana"] = assets.availability_snapshot(0) if assets != null else {}
	var eligibility := service.evaluate_play({"player_index": 0, "skill": skill, "evaluation_mode": "hand"}, facts)
	var presentation := CardPresentationRuntimeService.new()
	root.add_child(presentation)
	var play_state := presentation.compose_play_eligibility(eligibility, {"display_name": str(skill.get("display_name", card_id))})
	var privacy_text := JSON.stringify({"facts": facts, "eligibility": eligibility, "play_state": play_state})
	var privacy_safe := not privacy_text.contains('"machine"') \
		and not privacy_text.contains("runtime_instance_id") \
		and not privacy_text.contains("actor_id") \
		and not privacy_text.contains("owner_kind") \
		and not privacy_text.contains("owner_player_index")
	var result := {
		"actionable": bool(play_state.get("actionable", false)),
		"reason_code": str(eligibility.get("reason_code", "")),
		"readable": str(play_state.get("detail", "")).strip_edges() != "" \
			and str(play_state.get("detail", "")) != "当前不能打出这张牌。",
		"privacy_safe": privacy_safe,
		"facts": facts.duplicate(true),
		"eligibility": eligibility.duplicate(true),
		"play_state": play_state.duplicate(true),
	}
	presentation.free()
	service.free()
	bridge.free()
	selection.free()
	return result


func _facility_eligibility_skill(card_id: String) -> Dictionary:
	var card := CATALOG.card_snapshot(card_id)
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	var player: Dictionary = card.get("player", {}) if card.get("player", {}) is Dictionary else {}
	var authored_cost: Dictionary = machine.get("asset_cost", {}) if machine.get("asset_cost", {}) is Dictionary else {}
	var asset_cost: Dictionary = {}
	for asset_id in ASSET_IDS + ["generic"]:
		var amount_variant: Variant = authored_cost.get(asset_id, 0)
		asset_cost[asset_id] = int(amount_variant) if amount_variant is float and float(amount_variant) == floor(float(amount_variant)) else amount_variant
	return {
		"name": card_id,
		"card_id": card_id,
		"schema_version": "v0.6",
		"kind": "public_facility",
		"display_name": str(player.get("name", card_id)),
		"asset_cost": asset_cost,
		"play_cash": 0,
	}


func _facility_rank(infrastructure: RegionInfrastructureRuntimeController) -> int:
	var facilities := infrastructure.facilities_snapshot(false)
	return int((facilities[0] as Dictionary).get("rank", 0)) if not facilities.is_empty() and facilities[0] is Dictionary else 0


func _facility_count_for_region(infrastructure: RegionInfrastructureRuntimeController, region_id: String) -> int:
	var count := 0
	for facility_variant in infrastructure.facilities_snapshot(false):
		if facility_variant is Dictionary and str((facility_variant as Dictionary).get("region_id", "")) == region_id:
			count += 1
	return count


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
		"advance_once_journal": {},
		"advance_once_order": [],
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
