extends SceneTree

const SUPPORT := preload("res://tests/support/commodity_flow_v06_test_support.gd")
const CONSUMER_SCENE := preload("res://scenes/runtime/CommodityFlowPostCommitReceiptConsumer.tscn")
const WORLD_SCENE := preload("res://scenes/runtime/WorldSessionState.tscn")
const VISUAL_SCENE := preload("res://scenes/runtime/VisualCueRuntimeOwner.tscn")

var _checks := 0
var _failures := 0


class FakeDerivative:
	extends CityGdpDerivativeRuntimeController
	var settle_count := 0

	func positions_for_district(_district_index: int, _include_private := false) -> Array:
		return []

	func settle_district(_district_index: int, _current_gdp: int, _source := "实时GDP", _force_all := false) -> Dictionary:
		settle_count += 1
		return {"committed": false, "reason": "no_positions", "settled_count": 0, "receipts": []}


class FakeBankruptcy:
	extends BankruptcyNeutralEstateRuntimeController
	var finalized_ids: Dictionary = {}

	func settle_checkpoint(request: Dictionary) -> Dictionary:
		var transaction_id := str(request.get("transaction_id", ""))
		var fingerprint := JSON.stringify([
			transaction_id,
			str(request.get("reason_code", "")),
			float(request.get("occurred_at", 0.0)),
			str(request.get("source_fingerprint", "")),
		]).sha256_text()
		finalized_ids[transaction_id] = fingerprint
		return {"finalized": true, "transaction_id": transaction_id, "request_fingerprint": fingerprint}

	func checkpoint_transaction_binding(transaction_id: String) -> Dictionary:
		return {
			"transaction_id": transaction_id,
			"state": "finalized",
			"finalized": true,
			"request_fingerprint": str(finalized_ids.get(transaction_id, "")),
		} if finalized_ids.has(transaction_id) else {}


class FakeMana:
	extends PlayerManaRuntimeController

	func advance(delta_milliseconds: int, _game_time: float, _color_gdp_by_player: Dictionary) -> Dictionary:
		return {"advanced": true, "delta_milliseconds": delta_milliseconds}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var region := SUPPORT.region("region.000")
	var factory := SUPPORT.facility("factory-a", "region.000", "factory", 0, "life", 1)
	var market := SUPPORT.facility("market-a", "region.000", "market", 1, "life", 1)
	var route := SUPPORT.route("route-a", "region.000", "region.000", 1000000)
	var fixture := SUPPORT.create_fixture(self, [region], [factory, market], [route])
	var flow := fixture.get("flow") as CommodityFlowRuntimeController
	var bridge: SUPPORT.FactsBridge = fixture.get("bridge") as SUPPORT.FactsBridge
	var world := WORLD_SCENE.instantiate() as WorldSessionState
	var derivative := FakeDerivative.new()
	var visual := VISUAL_SCENE.instantiate() as VisualCueRuntimeOwner
	var consumer := CONSUMER_SCENE.instantiate() as CommodityFlowPostCommitReceiptConsumer
	root.add_child(world)
	root.add_child(derivative)
	root.add_child(visual)
	root.add_child(consumer)
	world.replace_players([
		{"id": 0, "cash": 100, "cash_cents": 10000},
		{"id": 1, "cash": 100, "cash_cents": 10000},
		{"id": 2, "cash": 100, "cash_cents": 10000},
	], true)
	world.replace_districts([{"region_id": "region.000", "name": "甲区", "city": {"active": true}}], true)
	_expect(bool(_configure_consumer(consumer, flow, world, derivative, visual).get("configured", false)), "consumer configures against real CommodityFlow owner")
	flow.set_postcommit_consumer(consumer)
	_expect(bool(SUPPORT.install(flow, factory, SUPPORT.DEFAULT_PRODUCT_ID, "production", 0, 1).get("finalized", false)), "production installation is finalized")
	_expect(bool(SUPPORT.install(flow, market, SUPPORT.DEFAULT_PRODUCT_ID, "demand", 1, 1).get("finalized", false)), "market demand installation is finalized")
	bridge.reject_next_batch = true
	bridge.facts["game_time"] = 1.0
	world.game_time = 1.0
	var cash_rejection := flow.advance_world(1.0, {})
	_expect(not bool(cash_rejection.get("advanced", true)) and not consumer.has_pending_batch() and int(flow.to_save_data().get("batch_sequence", -1)) == 0, "cash rejection aborts the zero-progress lineage preparation and leaves no phantom pending batch")
	consumer.inject_test_failure(&"after_city_target_before_mark")
	var failure: Dictionary = {}
	for second in range(1, 8):
		bridge.facts["game_time"] = float(second)
		world.game_time = float(second)
		var result := flow.advance_world(1.0, {})
		if not bool(result.get("advanced", false)):
			failure = result
			break
	_expect(not failure.is_empty() and bool(failure.get("flow_committed", false)) and int(failure.get("postcommit_pending_count", 0)) == 1, "post-commit interruption reports a committed flow batch but blocks downstream completion")
	var pending_flow_save := flow.to_save_data()
	var pending_sequence := int(pending_flow_save.get("batch_sequence", -1))
	_expect(pending_sequence > 0 and int((pending_flow_save.get("postcommit_consumer", {}) as Dictionary).get("completed_through_batch_sequence", -1)) == pending_sequence - 1, "CommodityFlow save embeds the pending consumer journal immediately after the committed batch")
	var history_after_target := _history_size(world)
	var next_time := float(bridge.facts.get("game_time", 0.0)) + 1.0
	bridge.facts["game_time"] = next_time
	world.game_time = next_time
	var recovered := flow.advance_world(1.0, {})
	_expect(bool(recovered.get("advanced", false)) and bool(recovered.get("postcommit_recovered_only", false)) and str(recovered.get("batch_id", "")) == str(failure.get("batch_id", "")), "first retry forward-completes the old batch and returns its original identity")
	_expect(int(flow.to_save_data().get("batch_sequence", -1)) == pending_sequence, "recovery-only call does not generate a new CommodityFlow batch")
	_expect(_history_size(world) == history_after_target and derivative.settle_count == 1 and int(visual.debug_snapshot().get("postcommit_pulse_lineage_count", 0)) == 1, "recovery adds no duplicate GDP history and completes derivative/pulse once")
	bridge.facts["game_time"] = next_time + 1.0
	world.game_time = next_time + 1.0
	var fresh := flow.advance_world(1.0, {})
	_expect(bool(fresh.get("advanced", false)) and not bool(fresh.get("postcommit_recovered_only", false)) and int(flow.to_save_data().get("batch_sequence", -1)) == pending_sequence + 1, "only the following tick may create the next sale batch")

	var restored_fixture := SUPPORT.create_fixture(self, [region], [factory, market], [route])
	var restored_flow := restored_fixture.get("flow") as CommodityFlowRuntimeController
	var restored_world := WORLD_SCENE.instantiate() as WorldSessionState
	var restored_derivative := FakeDerivative.new()
	var restored_visual := VISUAL_SCENE.instantiate() as VisualCueRuntimeOwner
	var restored_consumer := CONSUMER_SCENE.instantiate() as CommodityFlowPostCommitReceiptConsumer
	root.add_child(restored_world)
	root.add_child(restored_derivative)
	root.add_child(restored_visual)
	root.add_child(restored_consumer)
	restored_world.apply_save_data(world.to_save_data())
	_configure_consumer(restored_consumer, restored_flow, restored_world, restored_derivative, restored_visual)
	restored_flow.set_postcommit_consumer(restored_consumer)
	var malformed_flow_save := pending_flow_save.duplicate(true)
	malformed_flow_save["postcommit_consumer"] = ["truncated"]
	var before_malformed_restore := restored_flow.to_save_data()
	var malformed_restore := restored_flow.apply_save_data(malformed_flow_save)
	_expect(not bool(malformed_restore.get("applied", true)) and restored_flow.to_save_data() == before_malformed_restore, "an explicitly malformed nested post-commit section fails closed with zero live mutation")
	var truncated_current_save := pending_flow_save.duplicate(true)
	truncated_current_save.erase("postcommit_consumer")
	var truncated_restore := restored_flow.apply_save_data(truncated_current_save)
	_expect(not bool(truncated_restore.get("applied", true)) and str(truncated_restore.get("reason", "")) == "commodity_postcommit_save_section_missing" and restored_flow.to_save_data() == before_malformed_restore, "current CommodityFlow schema cannot silently bootstrap when the nested post-commit section is truncated")
	var nested_preflight := restored_consumer.preflight_save_data(pending_flow_save.get("postcommit_consumer", {}) as Dictionary, pending_sequence)
	_expect(bool(nested_preflight.get("accepted", false)), "pending nested consumer section passes its direct preflight: %s" % JSON.stringify(nested_preflight))
	var restored_result := restored_flow.apply_save_data(pending_flow_save)
	_expect(bool(restored_result.get("applied", false)) and int(restored_result.get("postcommit_pending_count", 0)) == 1, "CommodityFlow save roundtrip restores the nested pending lineage: %s" % JSON.stringify(restored_result))
	var restored_bridge: SUPPORT.FactsBridge = restored_fixture.get("bridge") as SUPPORT.FactsBridge
	restored_bridge.facts["game_time"] = next_time
	restored_world.game_time = next_time
	var restored_recovery := restored_flow.advance_world(1.0, {})
	_expect(bool(restored_recovery.get("postcommit_recovered_only", false)) and int(restored_flow.to_save_data().get("batch_sequence", -1)) == pending_sequence, "restored pending batch resumes before any new allocation: %s" % JSON.stringify(restored_recovery))

	SUPPORT.free_fixture(fixture)
	SUPPORT.free_fixture(restored_fixture)
	for node in [consumer, visual, derivative, world, restored_consumer, restored_visual, restored_derivative, restored_world]:
		if node is Node:
			(node as Node).queue_free()
	await process_frame
	if _failures == 0:
		print("COMMODITY FLOW POSTCOMMIT RECOVERY PASS: %d/%d" % [_checks, _checks])
		quit(0)
	else:
		push_error("COMMODITY FLOW POSTCOMMIT RECOVERY FAIL: %d/%d" % [_failures, _checks])
		quit(1)


func _history_size(world: WorldSessionState) -> int:
	var district: Dictionary = world.districts[0]
	var city: Dictionary = district.get("city", {}) if district.get("city", {}) is Dictionary else {}
	return (city.get("gdp_history", []) as Array).size() if city.get("gdp_history", []) is Array else 0


func _configure_consumer(
	consumer: CommodityFlowPostCommitReceiptConsumer,
	flow: CommodityFlowRuntimeController,
	world: WorldSessionState,
	derivative: CityGdpDerivativeRuntimeController,
	visual: VisualCueRuntimeOwner
) -> Dictionary:
	var bankruptcy := FakeBankruptcy.new()
	var mana := FakeMana.new()
	root.add_child(bankruptcy)
	root.add_child(mana)
	var public_log_owner := PublicLogPresentationOwner.new()
	var public_log_port := PublicLogProducerPort.new()
	var scheduler := TablePresentationRefreshScheduler.new()
	consumer.add_child(public_log_owner)
	consumer.add_child(public_log_port)
	consumer.add_child(scheduler)
	public_log_port.configure(public_log_owner)
	scheduler.reset_table_cadence()
	consumer.set_meta("test_public_log_owner", public_log_owner)
	consumer.set_meta("test_presentation_scheduler", scheduler)
	return consumer.configure(
		flow,
		world,
		derivative,
		visual,
		bankruptcy,
		mana,
		public_log_port,
		scheduler
	)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("COMMODITY FLOW POSTCOMMIT RECOVERY: %s" % message)
