@tool
extends Node

@onready var _world := $WorldSessionState as WorldSessionState
@onready var _visual := $VisualCueRuntimeOwner as VisualCueRuntimeOwner
@onready var _consumer := $CommodityFlowPostCommitReceiptConsumer as CommodityFlowPostCommitReceiptConsumer

var _checks := 0
var _failures := 0


class BenchFlow:
	extends CommodityFlowRuntimeController
	var receipts: Array = []

	func region_gdp_snapshot(_region_id: String) -> Dictionary:
		return {
			"region_gdp_per_minute": 24,
			"region_gdp_per_minute_cents": 2400,
			"receipt_ids": ["bench-sale-1"],
			"observation_window_seconds": 30.0,
		}

	func recent_sale_receipts_snapshot(_viewer_index := -1) -> Array:
		return receipts.duplicate(true)

	func player_color_flow_snapshot(player_index: int) -> Dictionary:
		return {
			"valid": true,
			"ruleset_id": "v0.6",
			"player_index": player_index,
			"observation_window_seconds": 30.0,
			"colors": {},
			"asset_recovery_observation_only": true,
		}


class BenchDerivative:
	extends CityGdpDerivativeRuntimeController
	var side_effect_count := 0

	func positions_for_district(_district_index: int, _include_private := false) -> Array:
		return []

	func settle_district(_district_index: int, _current_gdp: int, _source := "实时GDP", _force_all := false) -> Dictionary:
		side_effect_count += 1
		return {"committed": false, "reason": "no_positions", "settled_count": 0, "receipts": []}


class BenchBankruptcy:
	extends BankruptcyNeutralEstateRuntimeController

	func settle_checkpoint(request: Dictionary) -> Dictionary:
		return {"finalized": true, "transaction_id": str(request.get("transaction_id", ""))}


class BenchMana:
	extends PlayerManaRuntimeController

	func advance(delta_milliseconds: int, _game_time: float, _color_gdp_by_player: Dictionary) -> Dictionary:
		return {"advanced": true, "delta_milliseconds": delta_milliseconds}


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var flow := BenchFlow.new()
	var derivative := BenchDerivative.new()
	var bankruptcy := BenchBankruptcy.new()
	var mana := BenchMana.new()
	var public_log_owner := PublicLogPresentationOwner.new()
	var public_log_port := PublicLogProducerPort.new()
	var presentation_scheduler := TablePresentationRefreshScheduler.new()
	add_child(flow)
	add_child(derivative)
	add_child(bankruptcy)
	add_child(mana)
	add_child(public_log_owner)
	add_child(public_log_port)
	add_child(presentation_scheduler)
	public_log_port.configure(public_log_owner)
	presentation_scheduler.reset_table_cadence()
	_world.replace_players([
		{"id": 0, "cash": 100, "cash_cents": 10000},
		{"id": 1, "cash": 100, "cash_cents": 10000},
		{"id": 2, "cash": 100, "cash_cents": 10000},
	], true)
	_world.replace_districts([{"region_id": "region.000", "city": {"active": true}}], true)
	_world.game_time = 5.0
	var receipt := {
		"receipt_id": "bench-sale-1",
		"commodity_owner": 0,
		"commodity_id": "星露莓",
		"units": 1,
		"source_region_id": "region.000",
		"market_region_id": "region.000",
		"shortest_legal_distance": 0,
		"unit_price_cents": 1000,
		"gdp_value": 1000,
	}
	flow.receipts = [receipt]
	_check(bool(_consumer.configure(flow, _world, derivative, _visual, bankruptcy, mana, public_log_port, presentation_scheduler).get("configured", false)), "configured")
	var batch := {
		"batch_id": "commodity-flow-batch-0000000001",
		"ruleset_id": "v0.6",
		"batch_sequence": 1,
		"flow_revision_before": 0,
		"flow_revision": 1,
		"settled_at": 5.0,
		"flow_delta_seconds": 1.0,
		"receipt_ids": ["bench-sale-1"],
		"receipts": [receipt],
		"flow_result_summary": {"advanced": true, "batch_id": "commodity-flow-batch-0000000001", "receipt_count": 1},
	}
	batch["batch_fingerprint"] = CommodityFlowPostCommitReceiptConsumer.batch_fingerprint(batch)
	var first := _consumer.consume_committed_batch(batch)
	_check(bool(first.get("completed", false)), "first completion")
	_check((first.get("trace", []) as Array) == ["district:0:gdp_history", "district:0:derivative", "district:0:pulse", "player:0:cash_snapshot", "player:1:cash_snapshot", "player:2:cash_snapshot", "bankruptcy_checkpoint", "asset_recovery", "public_receipt", "presentation_refresh_requested", "finalize"], "ordered trace")
	_check(public_log_owner.recent_public_entries(4).size() == 1, "public receipt once")
	_check(presentation_scheduler.advance_typed(0.0).size() == 1 and presentation_scheduler.advance_typed(0.0).is_empty(), "presentation cadence invalidation produces one refresh receipt")
	_check(derivative.side_effect_count == 1, "derivative once")
	_check(int(_visual.debug_snapshot().get("postcommit_pulse_lineage_count", 0)) == 1, "pulse once")
	var pulse_revision := int(_visual.debug_snapshot().get("revision", 0))
	var pulse_collision := _visual.pulse_district_once(
		"commodity-flow-batch-0000000001:district:0",
		0,
		Color("#f97316")
	)
	_check(not bool(pulse_collision.get("pulsed", true)) and int(_visual.debug_snapshot().get("revision", -1)) == pulse_revision, "pulse binding collision rejected")
	var before := _world.to_save_data()
	var replay := _consumer.consume_committed_batch(batch)
	_check(bool(replay.get("replayed", false)), "replay receipt")
	_check(_world.to_save_data() == before and derivative.side_effect_count == 1 and int(_visual.debug_snapshot().get("postcommit_pulse_lineage_count", 0)) == 1, "replay zero side effect")
	var debug_text := JSON.stringify(_consumer.debug_snapshot()).to_lower()
	_check(not debug_text.contains("commodity_owner") and not debug_text.contains("cash_history"), "privacy-safe debug")
	var exit_code := 0
	if _failures == 0:
		print("COMMODITY FLOW POSTCOMMIT BENCH PASS: %d/%d" % [_checks, _checks])
	else:
		push_error("COMMODITY FLOW POSTCOMMIT BENCH FAIL: %d/%d" % [_failures, _checks])
		exit_code = 1
	# Keep the QA scene alive briefly so Godot MCP can collect the finished trace
	# and the engine error list before the process exits.
	await get_tree().create_timer(10.0).timeout
	get_tree().quit(exit_code)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("COMMODITY FLOW POSTCOMMIT BENCH: %s" % label)
