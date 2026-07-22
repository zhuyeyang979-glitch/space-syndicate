extends SceneTree

var _checks := 0
var _failures := 0


class StubFlow:
	extends CommodityFlowRuntimeController
	var queued_results: Array = []
	var pending := true
	var recovery_result := {"needed": true, "completed": true, "batch_id": "commodity-flow-batch-0000000001"}

	func advance_world(_delta_seconds: float, _clock_pause: Dictionary = {}) -> Dictionary:
		return (queued_results.pop_front() as Dictionary).duplicate(true) if not queued_results.is_empty() else {"advanced": false, "reason": "stub_empty"}

	func player_color_flow_snapshot(_player_index: int) -> Dictionary:
		return {"colors": {}}

	func has_pending_postcommit_recovery() -> bool:
		return pending

	func recover_pending_postcommit() -> Dictionary:
		pending = false
		return recovery_result.duplicate(true)


class StubBankruptcy:
	extends BankruptcyNeutralEstateRuntimeController
	var calls: Array = []
	var finalized_ids: Dictionary = {}

	func settle_checkpoint(request: Dictionary) -> Dictionary:
		calls.append(request.duplicate(true))
		var transaction_id := str(request.get("transaction_id", ""))
		var duplicate := finalized_ids.has(transaction_id)
		finalized_ids[transaction_id] = true
		return {"finalized": true, "duplicate": duplicate, "transaction_id": transaction_id}


class StubMana:
	extends PlayerManaRuntimeController
	var calls: Array = []

	func advance(delta_milliseconds: int, game_time: float, color_gdp_by_player: Dictionary) -> Dictionary:
		calls.append({
			"delta_milliseconds": delta_milliseconds,
			"game_time": game_time,
			"player_count": color_gdp_by_player.size(),
		})
		return {"advanced": true, "delta_milliseconds": delta_milliseconds}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var flow := StubFlow.new()
	var bankruptcy := StubBankruptcy.new()
	var mana := StubMana.new()
	var world := WorldSessionState.new()
	var port := RuntimeEconomyPort.new()
	for node in [flow, bankruptcy, mana, world, port]:
		root.add_child(node)
	port.bind_dependencies(null, null, flow, bankruptcy, mana, null, null, world)
	flow.queued_results = [
		{
			"advanced": false,
			"flow_committed": true,
			"postcommit_completed": false,
			"batch_id": "commodity-flow-batch-0000000001",
			"settled_at": 42.0,
			"flow_delta_seconds": 1.25,
		},
		{
			"advanced": true,
			"flow_committed": true,
			"postcommit_completed": true,
			"postcommit_recovered_only": true,
			"batch_id": "commodity-flow-batch-0000000001",
			"settled_at": 42.0,
			"flow_delta_seconds": 1.25,
		},
		{
			"advanced": true,
			"flow_committed": true,
			"postcommit_completed": true,
			"postcommit_recovered_only": false,
			"batch_id": "commodity-flow-batch-0000000002",
			"settled_at": 43.0,
			"flow_delta_seconds": 2.0,
		},
	]
	var blocking := {"game_time": 999.0, "player_count": 2}
	var incomplete := port.advance_commodity_flow(9.0, blocking)
	_expect(not bool(incomplete.get("advanced", true)) and bankruptcy.calls.is_empty() and mana.calls.is_empty(), "downstream checkpoints do not run while a committed flow batch remains post-commit pending")
	var recovered := port.advance_commodity_flow(9.0, blocking)
	_expect(bool(recovered.get("advanced", false)) and bool(recovered.get("postcommit_recovered_only", false)), "the recovered original batch resumes downstream processing")
	_expect(bankruptcy.calls.is_empty() and mana.calls.is_empty(), "RuntimeEconomyPort does not duplicate downstream mutations already owned by the post-commit consumer")
	var fresh := port.advance_commodity_flow(9.0, blocking)
	_expect(bool(fresh.get("advanced", false)) and bankruptcy.calls.is_empty() and mana.calls.is_empty(), "only the consumer may execute a following batch's bankruptcy and asset-recovery checkpoints")
	_expect(port.has_pending_postcommit_recovery() and bool(port.recover_pending_postcommit().get("completed", false)) and not port.has_pending_postcommit_recovery(), "RuntimeEconomyPort exposes one typed early-recovery fence for the original pending batch")
	var source := FileAccess.get_file_as_string("res://scripts/runtime/runtime_economy_port.gd")
	var consumer_source := FileAccess.get_file_as_string("res://scripts/runtime/commodity_flow_post_commit_receipt_consumer.gd")
	_expect(source.contains("recover_pending_postcommit") and not source.contains("settle_checkpoint") and not source.contains("_player_mana.advance") and not source.contains("Main") and consumer_source.contains("bankruptcy:") and consumer_source.contains("asset-recovery:") and consumer_source.contains("advance_once"), "one scene-owned consumer owns stable downstream lineage with no port or composition-root fallback")

	for node in [port, world, mana, bankruptcy, flow]:
		node.queue_free()
	await process_frame
	if _failures == 0:
		print("COMMODITY POSTCOMMIT DOWNSTREAM CHECKPOINT PASS: %d/%d" % [_checks, _checks])
		quit(0)
		return
	push_error("COMMODITY POSTCOMMIT DOWNSTREAM CHECKPOINT FAIL: %d/%d" % [_failures, _checks])
	quit(1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("COMMODITY POSTCOMMIT DOWNSTREAM: %s" % message)
