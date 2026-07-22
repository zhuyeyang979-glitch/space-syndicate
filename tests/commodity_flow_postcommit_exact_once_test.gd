extends SceneTree

const CONSUMER_SCENE := preload("res://scenes/runtime/CommodityFlowPostCommitReceiptConsumer.tscn")
const WORLD_SCENE := preload("res://scenes/runtime/WorldSessionState.tscn")
const VISUAL_SCENE := preload("res://scenes/runtime/VisualCueRuntimeOwner.tscn")
const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")
const RULESET_V06 := preload("res://resources/rules/space_syndicate_ruleset_v06.tres")

var _failures := 0
var _checks := 0


class FakeFlow:
	extends CommodityFlowRuntimeController
	var region_snapshots: Dictionary = {}
	var recent_receipts: Array = []

	func region_gdp_snapshot(region_id: String) -> Dictionary:
		return (region_snapshots.get(region_id, {}) as Dictionary).duplicate(true) if region_snapshots.get(region_id, {}) is Dictionary else {}

	func recent_sale_receipts_snapshot(_viewer_index := -1) -> Array:
		return recent_receipts.duplicate(true)

	func player_color_flow_snapshot(player_index: int) -> Dictionary:
		return {
			"valid": true,
			"ruleset_id": "v0.6",
			"player_index": player_index,
			"observation_window_seconds": 30.0,
			"colors": {},
			"asset_recovery_observation_only": true,
		}


class FakeDerivative:
	extends CityGdpDerivativeRuntimeController
	var settle_calls: Array = []
	var due_position := false

	func positions_for_district(_district_index: int, _include_private := false) -> Array:
		return [{"expires_at": 0.0}] if due_position else []

	func settle_district(district_index: int, current_gdp: int, source := "实时GDP", force_all := false) -> Dictionary:
		settle_calls.append({
			"district_index": district_index,
			"current_gdp": current_gdp,
			"source": source,
			"force_all": force_all,
		})
		var settled_count := 1 if due_position else 0
		due_position = false
		return {"committed": settled_count > 0, "reason": "", "settled_count": settled_count, "receipts": []}


class FakeBankruptcy:
	extends BankruptcyNeutralEstateRuntimeController
	var calls := 0
	var failures_remaining := 0
	var finalized_ids: Dictionary = {}

	func settle_checkpoint(request: Dictionary) -> Dictionary:
		calls += 1
		if failures_remaining > 0:
			failures_remaining -= 1
			return {"finalized": false, "reason_code": "injected_bankruptcy_failure"}
		var transaction_id := str(request.get("transaction_id", ""))
		var fingerprint := JSON.stringify([
			transaction_id,
			str(request.get("reason_code", "")),
			float(request.get("occurred_at", 0.0)),
			str(request.get("source_fingerprint", "")),
		]).sha256_text()
		if finalized_ids.has(transaction_id) and str(finalized_ids.get(transaction_id, "")) != fingerprint:
			return {"finalized": false, "reason_code": "bankruptcy_transaction_binding_collision"}
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
	var calls := 0
	var failures_remaining := 0

	func advance(delta_milliseconds: int, _game_time: float, _color_gdp_by_player: Dictionary) -> Dictionary:
		calls += 1
		if failures_remaining > 0:
			failures_remaining -= 1
			return {"advanced": false, "reason": "injected_asset_recovery_failure"}
		return {"advanced": true, "delta_milliseconds": delta_milliseconds}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var flow := FakeFlow.new()
	var world := WORLD_SCENE.instantiate() as WorldSessionState
	var derivative := FakeDerivative.new()
	var visual := VISUAL_SCENE.instantiate() as VisualCueRuntimeOwner
	var consumer := CONSUMER_SCENE.instantiate() as CommodityFlowPostCommitReceiptConsumer
	root.add_child(flow)
	root.add_child(world)
	root.add_child(derivative)
	root.add_child(visual)
	root.add_child(consumer)
	_expect(bool(flow.configure(RULESET_V06.debug_snapshot()).get("configured", false)), "flow fixture uses the production v0.6 continuous-flow terms")
	world.replace_players([
		{"id": 0, "cash": 110, "cash_cents": 11000},
		{"id": 1, "cash": 95, "cash_cents": 9500},
		{"id": 2, "cash": 80, "cash_cents": 8000},
	], true)
	world.replace_districts([
		{"region_id": "region.000", "name": "甲区", "city": {"active": true}},
		{"region_id": "region.001", "name": "乙区", "city": {"active": true}},
	], true)
	world.game_time = 12.0
	flow.region_snapshots = {
		"region.000": _region_gdp(4200, ["sale-0001", "sale-0002"]),
		"region.001": _region_gdp(2600, ["sale-0003"]),
	}
	var receipts_one := [
		_receipt("sale-0001", "region.000", "星露莓", 0, 1000),
		_receipt("sale-0002", "region.000", "星露莓", 0, 1000),
		_receipt("sale-0003", "region.001", "蓝潮藻", 1, 900),
	]
	flow.recent_receipts = receipts_one.duplicate(true)
	_expect(bool(_configure_consumer(consumer, flow, world, derivative, visual).get("configured", false)), "scene-owned consumer binds typed flow, world, derivative, visual, bankruptcy and asset owners")
	var batch_one := _batch(1, 0, 1, receipts_one, 12.0, 1.0)
	var first := consumer.consume_committed_batch(batch_one)
	var expected_trace := [
		"district:0:gdp_history",
		"district:0:derivative",
		"district:0:pulse",
		"district:1:gdp_history",
		"district:1:derivative",
		"district:1:pulse",
		"player:0:cash_snapshot",
		"player:1:cash_snapshot",
		"player:2:cash_snapshot",
		"bankruptcy_checkpoint",
		"asset_recovery",
		"public_receipt",
		"presentation_refresh_requested",
		"finalize",
	]
	_expect(bool(first.get("completed", false)) and first.get("trace", []) == expected_trace, "first batch preserves Main's deterministic per-district GDP/derivative/pulse order followed by player cash snapshots")
	_expect(_city_history_size(world, 0) == 1 and _city_history_size(world, 1) == 1, "multiple receipts for one region append exactly one GDP observation")
	_expect(derivative.settle_calls.size() == 2, "each affected district reaches derivative settlement exactly once on the normal path")
	var visual_after_first := visual.debug_snapshot()
	_expect(int(visual_after_first.get("postcommit_pulse_lineage_count", 0)) == 2 and int(visual_after_first.get("district_pulse_count", 0)) == 2, "public district pulse is emitted once per affected district")
	var pulse_revision_before_collision := int(visual_after_first.get("revision", 0))
	var pulse_collision := visual.pulse_district_once(
		"%s:district:0" % str(batch_one.get("batch_id", "")),
		1,
		Color("#2dd4bf")
	)
	_expect(
		not bool(pulse_collision.get("pulsed", true))
		and str(pulse_collision.get("reason", "")) == "postcommit_pulse_lineage_collision"
		and int(visual.debug_snapshot().get("revision", -1)) == pulse_revision_before_collision,
		"visual pulse target binds event identity to district, color and duration and rejects payload collisions"
	)
	_expect(_cash_history_sizes(world) == [1, 1, 1], "all player cash snapshots run after district post-commit stages")
	var first_public_owner := consumer.get_meta("test_public_log_owner") as PublicLogPresentationOwner
	var first_public_entries := first_public_owner.recent_public_entries(8)
	var first_record: Dictionary = ((consumer.to_save_data().get("journal", {}) as Dictionary).get(str(batch_one.get("batch_id", "")), {}) as Dictionary)
	var first_public_receipt := CommodityFlowPostCommitPublicReceipt.from_dictionary(first_record.get("public_receipt", {}) as Dictionary)
	_expect(first_public_receipt.is_valid() and first_public_receipt.matches_committed_batch(batch_one) and first_public_entries.size() == 1, "non-empty batch persists one exact-derived typed public receipt and applies one public-log target")
	var public_projection_text := JSON.stringify(first_public_entries).to_lower()
	_expect(not public_projection_text.contains("batch_id") and not public_projection_text.contains("batch_fingerprint") and not public_projection_text.contains("星露莓") and not public_projection_text.contains("蓝潮藻") and not public_projection_text.contains("cash") and not public_projection_text.contains("owner") and not public_projection_text.contains("hand"), "public receipt projection exposes no internal lineage, commodity identity, owner, cash or hand facts")
	var malformed_public_data := first_public_receipt.to_dictionary()
	malformed_public_data["settled_at"] = 12
	_expect(not CommodityFlowPostCommitPublicReceipt.from_dictionary(malformed_public_data).is_valid(), "public receipt rejects malformed raw numeric types")
	var first_log_receipt := first_public_receipt.to_public_log_receipt()
	var colliding_log_receipt := PublicLogReceipt.create(
		first_log_receipt.receipt_id,
		first_log_receipt.event_kind,
		first_log_receipt.localization_key,
		{"result": "collision", "public_status": "sale_receipt", "value_band": "single"},
		first_log_receipt.source_revision,
		first_log_receipt.world_time
	)
	var public_collision := first_public_owner.append_receipt(colliding_log_receipt)
	_expect(bool(public_collision.get("collision", false)) and first_public_owner.recent_public_entries(8).size() == 1, "public-log owner rejects same receipt id with a different typed fingerprint")
	var target_collision_fingerprint := "different-cross-owner-payload".sha256_text()
	var first_city_rows: Dictionary = first_record.get("city_breakdown_by_district", {}) as Dictionary
	var first_city_row: Dictionary = first_city_rows.get("0", {}) as Dictionary
	var valid_city_breakdown: Dictionary = (first_city_row.get("breakdown", {}) as Dictionary).duplicate(true)
	var city_binding_before_invalid := world.commodity_postcommit_city_binding(0)
	var city_history_before_invalid := _city_history_size(world, 0)
	var partial_city_snapshot := world.apply_commodity_postcommit_city_gdp_snapshot(
		1,
		str(batch_one.get("batch_id", "")),
		str(batch_one.get("batch_fingerprint", "")),
		str(city_binding_before_invalid.get("city_breakdown_fingerprint", "")),
		0,
		{"net": 42, "net_cents": 4200, "receipt_count": 2}
	)
	var private_node := Node.new()
	var object_city_breakdown := valid_city_breakdown.duplicate(true)
	object_city_breakdown["product_lines"] = [private_node]
	var object_city_snapshot := world.apply_commodity_postcommit_city_gdp_snapshot(
		1,
		str(batch_one.get("batch_id", "")),
		str(batch_one.get("batch_fingerprint", "")),
		str(city_binding_before_invalid.get("city_breakdown_fingerprint", "")),
		0,
		object_city_breakdown
	)
	private_node.free()
	_expect(
		not bool(partial_city_snapshot.get("applied", true))
		and not bool(object_city_snapshot.get("applied", true))
		and str(partial_city_snapshot.get("reason_code", "")) == "commodity_postcommit_city_snapshot_invalid"
		and str(object_city_snapshot.get("reason_code", "")) == "commodity_postcommit_city_snapshot_invalid"
		and world.commodity_postcommit_city_binding(0) == city_binding_before_invalid
		and _city_history_size(world, 0) == city_history_before_invalid,
		"WorldSession target rejects partial or non-pure GDP snapshots with zero mutation"
	)
	var city_target_collision := world.apply_commodity_postcommit_city_gdp_snapshot(
		1,
		str(batch_one.get("batch_id", "")),
		target_collision_fingerprint,
		str(world.commodity_postcommit_city_binding(0).get("city_breakdown_fingerprint", "")),
		0,
		valid_city_breakdown
	)
	var cash_target_collision := world.record_commodity_postcommit_cash_snapshot(
		1,
		str(batch_one.get("batch_id", "")),
		target_collision_fingerprint,
		0
	)
	_expect(not bool(city_target_collision.get("applied", true)) and str(city_target_collision.get("reason_code", "")) == "commodity_postcommit_city_lineage_collision" and _city_history_size(world, 0) == 1, "same target sequence with a different batch fingerprint fails closed")
	_expect(not bool(cash_target_collision.get("applied", true)) and str(cash_target_collision.get("reason_code", "")) == "commodity_postcommit_cash_lineage_collision" and _cash_history_sizes(world) == [1, 1, 1], "cash target binds sequence to the same batch fingerprint")

	var world_after_first := world.to_save_data()
	var derivative_calls_after_first := derivative.settle_calls.size()
	var visual_revision_after_first := int(visual.debug_snapshot().get("revision", 0))
	var replay := consumer.consume_committed_batch(batch_one)
	_expect(bool(replay.get("completed", false)) and bool(replay.get("replayed", false)), "same batch and fingerprint returns a terminal replay receipt")
	_expect(world.to_save_data() == world_after_first and derivative.settle_calls.size() == derivative_calls_after_first and int(visual.debug_snapshot().get("revision", 0)) == visual_revision_after_first, "terminal replay has zero GDP, derivative, pulse or cash-history side effects")

	var receipts_two := [_receipt("sale-0004", "region.000", "星露莓", 0, 1100)]
	flow.recent_receipts = receipts_one + receipts_two
	flow.region_snapshots["region.000"] = _region_gdp(5300, ["sale-0001", "sale-0002", "sale-0004"])
	var batch_two := _batch(2, 1, 2, receipts_two, 13.0, 1.0)
	consumer.inject_test_failure(&"after_city_target_before_mark")
	var interrupted := consumer.consume_committed_batch(batch_two)
	_expect(not bool(interrupted.get("completed", true)) and str(interrupted.get("reason_code", "")) == "fault_injected_after_city_target_before_mark", "fault injection observes the target-success/caller-interruption window")
	_expect(_city_history_size(world, 0) == 2, "interrupted city target has applied the new GDP observation once")
	var pending_save := consumer.to_save_data()
	var pending_world_save := world.to_save_data()

	var restored_world := WORLD_SCENE.instantiate() as WorldSessionState
	var restored_derivative := FakeDerivative.new()
	var restored_visual := VISUAL_SCENE.instantiate() as VisualCueRuntimeOwner
	var restored_consumer := CONSUMER_SCENE.instantiate() as CommodityFlowPostCommitReceiptConsumer
	root.add_child(restored_world)
	root.add_child(restored_derivative)
	root.add_child(restored_visual)
	root.add_child(restored_consumer)
	restored_world.apply_save_data(pending_world_save)
	_expect(bool(_configure_consumer(restored_consumer, flow, restored_world, restored_derivative, restored_visual).get("configured", false)), "restored consumer binds the same authoritative query and fresh target owners")
	var restored_journal := restored_consumer.apply_save_data(pending_save, 2)
	_expect(bool(restored_journal.get("applied", false)) and int(restored_journal.get("pending_count", 0)) == 1, "partial post-commit journal restores one pending batch without executing it")
	var recovered := restored_consumer.retry_pending_batch()
	_expect(bool(recovered.get("completed", false)) and bool(recovered.get("recovered", false)), "pending post-commit batch forward-recovers after save/load")
	_expect(_city_history_size(restored_world, 0) == 2, "recovery detects the already-applied city target and does not duplicate GDP history")
	_expect(int(restored_visual.debug_snapshot().get("postcommit_pulse_lineage_count", 0)) == 1 and _cash_history_sizes(restored_world) == [1, 1, 1], "recovery completes only derivative, pulse and already-current cash snapshots")
	var restored_terminal_world := restored_world.to_save_data()
	var restored_terminal_visual_revision := int(restored_visual.debug_snapshot().get("revision", 0))
	var restored_replay := restored_consumer.consume_committed_batch(batch_two)
	_expect(bool(restored_replay.get("replayed", false)) and restored_world.to_save_data() == restored_terminal_world and int(restored_visual.debug_snapshot().get("revision", 0)) == restored_terminal_visual_revision, "restored terminal lineage rejects a second observer application")
	for fault_stage in [
		&"after_city_breakdown_snapshot",
		&"after_city_target_before_mark",
		&"after_derivative_target_before_mark",
		&"after_pulse_target_before_mark",
		&"after_cash_target_before_mark",
		&"after_bankruptcy_target_before_mark",
		&"after_asset_recovery_target_before_mark",
		&"after_public_log_target_before_mark",
		&"after_presentation_invalidation_before_mark",
	]:
		var fault_result: Dictionary = await _verify_fault_roundtrip(flow, fault_stage)
		_expect(bool(fault_result.get("interrupted", false)), "%s leaves one persistable pending journal entry" % fault_stage)
		_expect(bool(fault_result.get("recovered", false)), "%s forward-recovers after save/load (%s)" % [fault_stage, str(fault_result.get("recovery_reason", ""))])
		_expect(
			int(fault_result.get("city_history_size", -1)) == 1
			and int(fault_result.get("city_gdp", -1)) == 18
			and int(fault_result.get("derivative_apply_count", -1)) == 1
			and int(fault_result.get("pulse_apply_count", -1)) == 1
			and fault_result.get("cash_history_sizes", []) == [1, 1, 1],
			"%s applies GDP, derivative, pulse and player observations exactly once" % fault_stage
		)
		_expect(
			int(fault_result.get("restored_public_receipt_count", -1)) == 1
			and int(fault_result.get("presentation_due_count", -1)) == 1
			and int(fault_result.get("presentation_second_due_count", -1)) == 0,
			"%s restores one public receipt and one cadence refresh without duplicate target apply" % fault_stage
		)
	var same_runtime_tail := await _verify_public_tail_same_runtime(flow)
	_expect(bool(same_runtime_tail.get("public_log_exact_once", false)), "public-log target success/caller-ack interruption retries without a second public receipt")
	_expect(bool(same_runtime_tail.get("presentation_exact_once", false)), "presentation invalidation target success/caller-ack interruption yields one scheduled target apply")
	var downstream_target_failures := await _verify_downstream_target_failures(flow)
	_expect(bool(downstream_target_failures.get("bankruptcy_recovered", false)), "bankruptcy target failure keeps the original batch pending and retries it before asset recovery (%s)" % str(downstream_target_failures.get("bankruptcy_reason", "")))
	_expect(bool(downstream_target_failures.get("asset_recovery_recovered", false)), "asset-recovery failure retries the stable transaction without replaying bankruptcy (%s)" % str(downstream_target_failures.get("asset_reason", "")))
	var torn_bankruptcy := await _verify_torn_downstream_restore(flow, &"after_bankruptcy_target_before_mark")
	var torn_asset := await _verify_torn_downstream_restore(flow, &"after_asset_recovery_target_before_mark")
	var torn_derivative := await _verify_torn_derivative_restore(flow)
	_expect(str(torn_bankruptcy.get("reason_code", "")) == "commodity_postcommit_bankruptcy_target_lineage_mismatch", "consumer-ahead bankruptcy save skew fails closed")
	_expect(str(torn_asset.get("reason_code", "")) == "commodity_postcommit_asset_target_lineage_mismatch", "consumer-ahead asset-recovery save skew fails closed")
	_expect(str(torn_derivative.get("reason_code", "")) == "commodity_postcommit_derivative_target_lineage_mismatch", "consumer-ahead derivative save skew fails closed")

	var collision := batch_two.duplicate(true)
	(collision.get("receipts", []) as Array)[0]["unit_price_cents"] = 9999
	collision["batch_fingerprint"] = CommodityFlowPostCommitReceiptConsumer.batch_fingerprint(collision)
	var collision_result := restored_consumer.consume_committed_batch(collision)
	_expect(not bool(collision_result.get("completed", true)) and str(collision_result.get("reason_code", "")) == "commodity_postcommit_batch_binding_collision", "same batch id with a different fingerprint fails closed")

	var history_before_empty := [_city_history_size(restored_world, 0), _city_history_size(restored_world, 1)]
	var cash_before_empty := _cash_history_sizes(restored_world)
	var visual_before_empty := int(restored_visual.debug_snapshot().get("revision", 0))
	var empty_public_owner := restored_consumer.get_meta("test_public_log_owner") as PublicLogPresentationOwner
	var empty_scheduler := restored_consumer.get_meta("test_presentation_scheduler") as TablePresentationRefreshScheduler
	var public_before_empty := empty_public_owner.recent_public_entries(90).size()
	empty_scheduler.advance_typed(0.0)
	var empty_result := restored_consumer.consume_committed_batch(_batch(3, 2, 3, [], 14.0, 1.0))
	_expect(bool(empty_result.get("completed", false)) and int(empty_result.get("receipt_count", -1)) == 0, "empty sale batch advances the lineage watermark without observer work")
	_expect(history_before_empty == [_city_history_size(restored_world, 0), _city_history_size(restored_world, 1)] and cash_before_empty == _cash_history_sizes(restored_world) and visual_before_empty == int(restored_visual.debug_snapshot().get("revision", 0)), "empty batch has zero GDP, derivative, pulse and cash-history side effects")
	_expect(empty_public_owner.recent_public_entries(90).size() == public_before_empty and empty_scheduler.advance_typed(0.0).is_empty(), "empty batch applies zero public receipt and zero presentation invalidation")

	var terminal_save := restored_consumer.to_save_data()
	var empty_record: Dictionary = ((terminal_save.get("journal", {}) as Dictionary).get("commodity-flow-batch-0000000003", {}) as Dictionary)
	_expect(
		str(empty_record.get("state", "")) == "finalized"
		and int(empty_record.get("tail_progress", -1)) == 2
		and (empty_record.get("public_receipt", {}) as Dictionary).is_empty()
		and not bool(empty_record.get("public_log_target_completed", true))
		and not bool(empty_record.get("presentation_invalidation_completed", true))
		and int((empty_record.get("final_receipt", {}) as Dictionary).get("receipt_count", -1)) == 0
		and (empty_record.get("trace", []) as Array).has("public_tail:empty_noop")
		and str((empty_record.get("trace", []) as Array).back()) == "finalize",
		"empty finalized batch persists the explicit no-public tail contract"
	)
	var empty_roundtrip := await _verify_empty_finalized_roundtrip(
		flow,
		terminal_save,
		_batch(3, 2, 3, [], 14.0, 1.0)
	)
	_expect(bool(empty_roundtrip.get("roundtrip_equal", false)), "empty finalized batch preflight/apply/recapture is exact")
	_expect(bool(empty_roundtrip.get("replay_zero_side_effect", false)), "empty finalized batch replay is a zero-side-effect terminal no-op")

	var unknown_legacy_reason := terminal_save.duplicate(true)
	unknown_legacy_reason["legacy_bootstrap_reason"] = "forged_legacy_bootstrap"
	var legacy_before := restored_consumer.to_save_data()
	var unknown_preflight := restored_consumer.preflight_save_data(unknown_legacy_reason, 3)
	var unknown_apply := restored_consumer.apply_save_data(unknown_legacy_reason, 3)
	_expect(
		not bool(unknown_preflight.get("accepted", true))
		and str(unknown_preflight.get("reason_code", "")) == "commodity_postcommit_legacy_bootstrap_reason_invalid"
		and not bool(unknown_apply.get("applied", true))
		and restored_consumer.to_save_data() == legacy_before,
		"unknown legacy bootstrap reason fails closed with zero live journal mutation"
	)

	flow.set_postcommit_consumer(restored_consumer)
	var flow_candidate := flow.to_save_data()
	flow_candidate["batch_sequence"] = 3
	flow_candidate["flow_revision"] = 3
	flow_candidate["postcommit_consumer"] = terminal_save.duplicate(true)
	var flow_before_preflight := flow.to_save_data()
	var consumer_before_preflight := restored_consumer.to_save_data()
	var flow_preflight := flow.preflight_save_data(flow_candidate)
	_expect(
		bool(flow_preflight.get("accepted", false))
		and flow.to_save_data() == flow_before_preflight
		and restored_consumer.to_save_data() == consumer_before_preflight
		and (flow_preflight.get("normalized_state", {}) as Dictionary).get("postcommit_consumer", {}) == terminal_save,
		"CommodityFlow pure preflight normalizes on a detached owner/consumer and mutates neither live checkpoint"
	)

	var capacity := await _verify_journal_capacity_boundary(flow)
	_expect(bool(capacity.get("pending_overflow_accepted", false)), "128 finalized records plus the one valid pending record remains restorable")
	_expect(bool(capacity.get("terminal_pruned", false)), "finalizing the pending record prunes terminal lineage back to 128")
	_expect(bool(capacity.get("terminal_overflow_rejected", false)), "129 finalized records with no pending record fail closed with zero live mutation")
	var self_consistent_public_tamper := terminal_save.duplicate(true)
	var self_consistent_journal: Dictionary = (self_consistent_public_tamper.get("journal", {}) as Dictionary).duplicate(true)
	var self_consistent_record: Dictionary = (self_consistent_journal.get("commodity-flow-batch-0000000002", {}) as Dictionary).duplicate(true)
	var self_consistent_receipt: Dictionary = (self_consistent_record.get("public_receipt", {}) as Dictionary).duplicate(true)
	self_consistent_receipt["sale_count"] = 2
	self_consistent_receipt["value_band"] = "multiple"
	self_consistent_receipt["receipt_fingerprint"] = CommodityFlowPostCommitPublicReceipt.fingerprint_for_data(self_consistent_receipt)
	self_consistent_record["public_receipt"] = self_consistent_receipt
	self_consistent_journal["commodity-flow-batch-0000000002"] = self_consistent_record
	self_consistent_public_tamper["journal"] = self_consistent_journal
	_expect(
		not bool(restored_consumer.preflight_save_data(self_consistent_public_tamper, 3).get("accepted", true)),
		"self-consistent public receipt fingerprint cannot diverge from the original committed batch"
	)
	for tamper_kind in [
		"extra_private_field",
		"flow_revision",
		"settled_at",
		"flow_delta_seconds",
		"receipt_count",
		"flow_result_summary",
		"reason_code",
		"recovered",
		"replayed",
		"batch_fingerprint",
		"trace",
	]:
		var tampered_terminal := terminal_save.duplicate(true)
		var tampered_terminal_journal: Dictionary = (tampered_terminal.get("journal", {}) as Dictionary).duplicate(true)
		var tampered_terminal_record: Dictionary = (tampered_terminal_journal.get("commodity-flow-batch-0000000003", {}) as Dictionary).duplicate(true)
		var tampered_final: Dictionary = (tampered_terminal_record.get("final_receipt", {}) as Dictionary).duplicate(true)
		match tamper_kind:
			"extra_private_field": tampered_final["private_cash"] = 999999
			"flow_revision": tampered_final["flow_revision"] = int(tampered_final.get("flow_revision", 0)) + 1
			"settled_at": tampered_final["settled_at"] = float(tampered_final.get("settled_at", 0.0)) + 1.0
			"flow_delta_seconds": tampered_final["flow_delta_seconds"] = float(tampered_final.get("flow_delta_seconds", 0.0)) + 1.0
			"receipt_count": tampered_final["receipt_count"] = int(tampered_final.get("receipt_count", 0)) + 1
			"flow_result_summary":
				var summary: Dictionary = (tampered_final.get("flow_result_summary", {}) as Dictionary).duplicate(true)
				summary["private_cash"] = 999999
				tampered_final["flow_result_summary"] = summary
			"reason_code": tampered_final["reason_code"] = "forged"
			"recovered": tampered_final["recovered"] = not bool(tampered_final.get("recovered", false))
			"replayed": tampered_final["replayed"] = true
			"batch_fingerprint": tampered_final["batch_fingerprint"] = "forged".sha256_text()
			"trace":
				var trace: Array = (tampered_final.get("trace", []) as Array).duplicate()
				trace.append("forged")
				tampered_final["trace"] = trace
		tampered_terminal_record["final_receipt"] = tampered_final
		tampered_terminal_journal["commodity-flow-batch-0000000003"] = tampered_terminal_record
		tampered_terminal["journal"] = tampered_terminal_journal
		_expect(not bool(restored_consumer.preflight_save_data(tampered_terminal, 3).get("accepted", true)), "terminal receipt tamper fails closed: %s" % tamper_kind)
	var corrupt_save := terminal_save.duplicate(true)
	var corrupt_journal: Dictionary = corrupt_save.get("journal", {}) as Dictionary
	var corrupt_record: Dictionary = (corrupt_journal.get("commodity-flow-batch-0000000003", {}) as Dictionary).duplicate(true)
	corrupt_record["batch_fingerprint"] = "forged"
	corrupt_journal["commodity-flow-batch-0000000003"] = corrupt_record
	corrupt_save["journal"] = corrupt_journal
	_expect(not bool(restored_consumer.preflight_save_data(corrupt_save, 3).get("accepted", true)), "corrupt saved fingerprint is rejected before live journal mutation")
	var mismatched_record_save := terminal_save.duplicate(true)
	var mismatched_journal: Dictionary = (mismatched_record_save.get("journal", {}) as Dictionary).duplicate(true)
	var mismatched_record: Dictionary = (mismatched_journal.get("commodity-flow-batch-0000000003", {}) as Dictionary).duplicate(true)
	mismatched_record["batch_sequence"] = 2
	mismatched_journal["commodity-flow-batch-0000000003"] = mismatched_record
	mismatched_record_save["journal"] = mismatched_journal
	_expect(not bool(restored_consumer.preflight_save_data(mismatched_record_save, 3).get("accepted", true)), "saved record sequence cannot diverge from its fingerprint-bound batch")
	var mismatched_district_save := pending_save.duplicate(true)
	var mismatched_district_journal: Dictionary = (mismatched_district_save.get("journal", {}) as Dictionary).duplicate(true)
	var mismatched_district_record: Dictionary = (mismatched_district_journal.get("commodity-flow-batch-0000000002", {}) as Dictionary).duplicate(true)
	mismatched_district_record["district_indices"] = [1]
	mismatched_district_journal["commodity-flow-batch-0000000002"] = mismatched_district_record
	mismatched_district_save["journal"] = mismatched_district_journal
	_expect(not bool(restored_consumer.preflight_save_data(mismatched_district_save, 2).get("accepted", true)), "saved district binding cannot diverge from receipt region identity")
	var malformed_key_save := pending_save.duplicate(true)
	var malformed_key_journal: Dictionary = (malformed_key_save.get("journal", {}) as Dictionary).duplicate(true)
	var malformed_key_record: Dictionary = (malformed_key_journal.get("commodity-flow-batch-0000000002", {}) as Dictionary).duplicate(true)
	malformed_key_record["district_progress"] = {"abc": 0}
	malformed_key_journal["commodity-flow-batch-0000000002"] = malformed_key_record
	malformed_key_save["journal"] = malformed_key_journal
	_expect(not bool(restored_consumer.preflight_save_data(malformed_key_save, 2).get("accepted", true)), "non-canonical journal index keys fail closed instead of aliasing district zero")
	var tampered_observer_save := pending_save.duplicate(true)
	var tampered_observer_journal: Dictionary = (tampered_observer_save.get("journal", {}) as Dictionary).duplicate(true)
	var tampered_observer_record: Dictionary = (tampered_observer_journal.get("commodity-flow-batch-0000000002", {}) as Dictionary).duplicate(true)
	var tampered_breakdowns: Dictionary = (tampered_observer_record.get("city_breakdown_by_district", {}) as Dictionary).duplicate(true)
	var tampered_breakdown: Dictionary = (tampered_breakdowns.get("0", {}) as Dictionary).duplicate(true)
	tampered_breakdown["net"] = int(tampered_breakdown.get("net", 0)) + 1
	tampered_breakdowns["0"] = tampered_breakdown
	tampered_observer_record["city_breakdown_by_district"] = tampered_breakdowns
	tampered_observer_journal["commodity-flow-batch-0000000002"] = tampered_observer_record
	tampered_observer_save["journal"] = tampered_observer_journal
	_expect(not bool(restored_consumer.preflight_save_data(tampered_observer_save, 2).get("accepted", true)), "persisted GDP observer payload cannot diverge from its batch-bound fingerprint")
	var malformed_observer_key_save := pending_save.duplicate(true)
	var malformed_observer_key_journal: Dictionary = (malformed_observer_key_save.get("journal", {}) as Dictionary).duplicate(true)
	var malformed_observer_key_record: Dictionary = (malformed_observer_key_journal.get("commodity-flow-batch-0000000002", {}) as Dictionary).duplicate(true)
	var malformed_observer_breakdowns: Dictionary = (malformed_observer_key_record.get("city_breakdown_by_district", {}) as Dictionary).duplicate(true)
	malformed_observer_breakdowns["999"] = malformed_observer_breakdowns.get("0", {})
	malformed_observer_breakdowns.erase("0")
	malformed_observer_key_record["city_breakdown_by_district"] = malformed_observer_breakdowns
	malformed_observer_key_journal["commodity-flow-batch-0000000002"] = malformed_observer_key_record
	malformed_observer_key_save["journal"] = malformed_observer_key_journal
	_expect(not bool(restored_consumer.preflight_save_data(malformed_observer_key_save, 2).get("accepted", true)), "persisted GDP observer snapshot keys must match the frozen district binding")
	_expect(not bool(restored_consumer.preflight_save_data({}, 3).get("accepted", true)), "an explicit empty post-commit section is malformed rather than legacy")
	_expect(not bool(restored_consumer.preflight_save_data({"schema_version": 1}, 3).get("accepted", true)), "a truncated post-commit section fails closed")
	var behind_terminal_cursor := terminal_save.duplicate(true)
	behind_terminal_cursor["completed_through_batch_sequence"] = 2
	_expect(not bool(restored_consumer.preflight_save_data(behind_terminal_cursor, 3).get("accepted", true)), "terminal consumer cursor must equal the CommodityFlow batch cursor")
	_expect(not bool(restored_consumer.preflight_save_data(pending_save, 3).get("accepted", true)), "pending consumer batch must be the current committed CommodityFlow batch")

	var behind_city_world := WORLD_SCENE.instantiate() as WorldSessionState
	var behind_city_derivative := FakeDerivative.new()
	var behind_city_visual := VISUAL_SCENE.instantiate() as VisualCueRuntimeOwner
	var behind_city_consumer := CONSUMER_SCENE.instantiate() as CommodityFlowPostCommitReceiptConsumer
	for node in [behind_city_world, behind_city_derivative, behind_city_visual, behind_city_consumer]:
		root.add_child(node)
	behind_city_world.replace_players([{"id": 0, "cash": 100}, {"id": 1, "cash": 100}, {"id": 2, "cash": 100}], true)
	behind_city_world.replace_districts([{"region_id": "region.000", "city": {"active": true}}], true)
	_configure_consumer(behind_city_consumer, flow, behind_city_world, behind_city_derivative, behind_city_visual)
	behind_city_consumer.apply_save_data(pending_save, 2)
	var behind_city_result := behind_city_consumer.retry_pending_batch()
	_expect(not bool(behind_city_result.get("completed", true)) and str(behind_city_result.get("reason_code", "")) == "commodity_postcommit_city_target_lineage_mismatch" and _city_history_size(behind_city_world, 0) == 0, "consumer city acknowledgement cannot finalize against a WorldSession envelope that is behind")

	var cash_ack_world := WORLD_SCENE.instantiate() as WorldSessionState
	var cash_ack_derivative := FakeDerivative.new()
	var cash_ack_visual := VISUAL_SCENE.instantiate() as VisualCueRuntimeOwner
	var cash_ack_consumer := CONSUMER_SCENE.instantiate() as CommodityFlowPostCommitReceiptConsumer
	for node in [cash_ack_world, cash_ack_derivative, cash_ack_visual, cash_ack_consumer]:
		root.add_child(node)
	cash_ack_world.replace_players([{"id": 0, "cash": 100}, {"id": 1, "cash": 100}, {"id": 2, "cash": 100}], true)
	cash_ack_world.replace_districts([{"region_id": "region.000", "city": {"active": true}}], true)
	flow.region_snapshots = {"region.000": _region_gdp(1900, ["sale-cash-ack"])}
	flow.recent_receipts = [_receipt("sale-cash-ack", "region.000", "星露莓", 0, 1000)]
	_configure_consumer(cash_ack_consumer, flow, cash_ack_world, cash_ack_derivative, cash_ack_visual)
	cash_ack_consumer.inject_test_failure(&"after_cash_target_before_mark")
	cash_ack_consumer.consume_committed_batch(_batch(1, 0, 1, flow.recent_receipts, 1.0, 1.0))
	var cash_ack_save := cash_ack_consumer.to_save_data()
	var behind_cash_world := WORLD_SCENE.instantiate() as WorldSessionState
	var behind_cash_derivative := FakeDerivative.new()
	var behind_cash_visual := VISUAL_SCENE.instantiate() as VisualCueRuntimeOwner
	var behind_cash_consumer := CONSUMER_SCENE.instantiate() as CommodityFlowPostCommitReceiptConsumer
	for node in [behind_cash_world, behind_cash_derivative, behind_cash_visual, behind_cash_consumer]:
		root.add_child(node)
	behind_cash_world.replace_players([{"id": 0, "cash": 100}, {"id": 1, "cash": 100}, {"id": 2, "cash": 100}], true)
	behind_cash_world.replace_districts([{"region_id": "region.000", "city": {"active": true}}], true)
	var cash_ack_batch := _batch(1, 0, 1, flow.recent_receipts, 1.0, 1.0)
	var cash_ack_record: Dictionary = ((cash_ack_save.get("journal", {}) as Dictionary).get(str(cash_ack_batch.get("batch_id", "")), {}) as Dictionary)
	var behind_cash_city_seed := behind_cash_world.apply_commodity_postcommit_city_gdp_snapshot(
		1,
		str(cash_ack_batch.get("batch_id", "")),
		str(cash_ack_batch.get("batch_fingerprint", "")),
		str(cash_ack_record.get("city_breakdown_fingerprint", "")),
		0,
		_city_breakdown(19, 1900, 1)
	)
	_expect(bool(behind_cash_city_seed.get("applied", false)), "behind-cash skew fixture first applies its complete authoritative city snapshot")
	_configure_consumer(behind_cash_consumer, flow, behind_cash_world, behind_cash_derivative, behind_cash_visual)
	behind_cash_consumer.apply_save_data(cash_ack_save, 1)
	var behind_cash_result := behind_cash_consumer.retry_pending_batch()
	_expect(not bool(behind_cash_result.get("completed", true)) and str(behind_cash_result.get("reason_code", "")) == "commodity_postcommit_player_target_lineage_mismatch" and _cash_history_sizes(behind_cash_world) == [0, 0, 0], "consumer player acknowledgement cannot finalize against a WorldSession envelope that is behind")

	var debug_text := JSON.stringify(restored_consumer.debug_snapshot()).to_lower()
	_expect(not debug_text.contains("commodity_owner") and not debug_text.contains("cash_history") and not debug_text.contains("receipt_ids") and not debug_text.contains("rent_rows"), "developer debug snapshot exposes counts and stages but no private receipt payload")

	var skew_receipts := [_receipt("sale-skew-1", "region.000", "星露莓", 0, 1000)]
	flow.region_snapshots = {"region.000": _region_gdp(2200, ["sale-skew-1"])}
	flow.recent_receipts = skew_receipts.duplicate(true)
	var skew_city_world := WORLD_SCENE.instantiate() as WorldSessionState
	var skew_city_derivative := FakeDerivative.new()
	var skew_city_visual := VISUAL_SCENE.instantiate() as VisualCueRuntimeOwner
	var skew_city_consumer := CONSUMER_SCENE.instantiate() as CommodityFlowPostCommitReceiptConsumer
	for node in [skew_city_world, skew_city_derivative, skew_city_visual, skew_city_consumer]:
		root.add_child(node)
	skew_city_world.replace_players([{"id": 0, "cash": 100}, {"id": 1, "cash": 100}, {"id": 2, "cash": 100}], true)
	skew_city_world.replace_districts([{"region_id": "region.000", "city": {"active": true}}], true)
	var ahead_city_batch := _batch(2, 1, 2, skew_receipts, 1.0, 1.0)
	var ahead_city_seed := skew_city_world.apply_commodity_postcommit_city_gdp_snapshot(
		2,
		str(ahead_city_batch.get("batch_id", "")),
		str(ahead_city_batch.get("batch_fingerprint", "")),
		"skew-ahead-city-breakdown".sha256_text(),
		0,
		_city_breakdown(22, 2200, 1)
	)
	_expect(bool(ahead_city_seed.get("applied", false)), "ahead-city skew fixture first applies its complete authoritative city snapshot")
	_configure_consumer(skew_city_consumer, flow, skew_city_world, skew_city_derivative, skew_city_visual)
	var skew_city_result := skew_city_consumer.consume_committed_batch(_batch(1, 0, 1, skew_receipts, 1.0, 1.0))
	_expect(not bool(skew_city_result.get("completed", true)) and str(skew_city_result.get("reason_code", "")) == "commodity_postcommit_city_target_lineage_mismatch" and _city_history_size(skew_city_world, 0) == 1, "a target lineage ahead of the pending batch fails closed instead of silently skipping a mismatched city mutation")

	var skew_cash_world := WORLD_SCENE.instantiate() as WorldSessionState
	var skew_cash_derivative := FakeDerivative.new()
	var skew_cash_visual := VISUAL_SCENE.instantiate() as VisualCueRuntimeOwner
	var skew_cash_consumer := CONSUMER_SCENE.instantiate() as CommodityFlowPostCommitReceiptConsumer
	for node in [skew_cash_world, skew_cash_derivative, skew_cash_visual, skew_cash_consumer]:
		root.add_child(node)
	skew_cash_world.replace_players([{"id": 0, "cash": 100}, {"id": 1, "cash": 100}, {"id": 2, "cash": 100}], true)
	skew_cash_world.replace_districts([{"region_id": "region.000", "city": {"active": true}}], true)
	var current_city_batch := _batch(1, 0, 1, skew_receipts, 1.0, 1.0)
	_configure_consumer(skew_cash_consumer, flow, skew_cash_world, skew_cash_derivative, skew_cash_visual)
	skew_cash_consumer.prepare_committed_batch(current_city_batch)
	skew_cash_consumer.seal_committed_batch_inputs(current_city_batch)
	var skew_cash_record: Dictionary = ((skew_cash_consumer.to_save_data().get("journal", {}) as Dictionary).get(str(current_city_batch.get("batch_id", "")), {}) as Dictionary)
	skew_cash_world.apply_commodity_postcommit_city_gdp_snapshot(
		1,
		str(current_city_batch.get("batch_id", "")),
		str(current_city_batch.get("batch_fingerprint", "")),
		str(skew_cash_record.get("city_breakdown_fingerprint", "")),
		0,
		{"net": 22, "net_cents": 2200, "receipt_count": 1}
	)
	skew_cash_world.record_commodity_postcommit_cash_snapshot(
		2,
		str(ahead_city_batch.get("batch_id", "")),
		str(ahead_city_batch.get("batch_fingerprint", "")),
		0
	)
	var skew_cash_result := skew_cash_consumer.consume_committed_batch(_batch(1, 0, 1, skew_receipts, 1.0, 1.0))
	_expect(not bool(skew_cash_result.get("completed", true)) and str(skew_cash_result.get("reason_code", "")) == "commodity_postcommit_player_target_lineage_mismatch" and _cash_history_sizes(skew_cash_world) == [1, 0, 0], "a player-observation lineage ahead of the pending batch fails closed without duplicating history")

	var coordinator := COORDINATOR_SCENE.instantiate()
	root.add_child(coordinator)
	var production_consumers := coordinator.find_children("CommodityFlowPostCommitReceiptConsumer", "CommodityFlowPostCommitReceiptConsumer", true, false)
	_expect(production_consumers.size() == 1 and (production_consumers[0] as Node).scene_file_path == "res://scenes/runtime/CommodityFlowPostCommitReceiptConsumer.tscn", "production coordinator composes exactly one editable post-commit consumer scene")
	var bridge_source := FileAccess.get_file_as_string("res://scripts/runtime/commodity_flow_world_bridge.gd")
	var flow_source := FileAccess.get_file_as_string("res://scripts/runtime/commodity_flow_runtime_controller.gd")
	var consumer_source := FileAccess.get_file_as_string("res://scripts/runtime/commodity_flow_post_commit_receipt_consumer.gd")
	var presentation_source := FileAccess.get_file_as_string("res://scripts/presentation/table_presentation_refresh_port.gd")
	_expect(not bridge_source.contains("notify_sale_receipt_batch_committed") and not bridge_source.contains("_on_commodity_flow_receipt_batch") and not bridge_source.contains("bind_world"), "CommodityFlowWorldBridge no longer holds a dynamic Main callback capability")
	_expect(flow_source.contains("CommodityFlowPostCommitReceiptConsumer") and not flow_source.contains("notify_sale_receipt_batch_committed"), "CommodityFlow uses one typed scene-owned consumer with no legacy notification fallback")
	_expect(not flow_source.contains("sale_receipt_batch_committed") and not consumer_source.contains("public_receipt_committed") and consumer_source.contains("CommodityFlowPostCommitPublicReceipt") and consumer_source.contains("PublicLogProducerPort") and consumer_source.contains("TablePresentationRefreshScheduler") and not consumer_source.contains("TablePresentationRefreshPort") and not presentation_source.contains("request_immediate_once"), "typed public receipt and idempotent cadence invalidation have no synchronous signal, direct UI target, or in-memory once wrapper")

	var next_session_plan := {
		"plan_schema_version": 1,
		"players": [
			{"id": 0, "cash": 75, "cash_cents": 7500},
			{"id": 1, "cash": 75, "cash_cents": 7500},
			{"id": 2, "cash": 75, "cash_cents": 7500},
		],
		"districts": [{"region_id": "region.000", "name": "新局甲区", "city": {"active": true}}],
		"map_width_m": 1000.0,
		"map_height_m": 500.0,
	}
	_expect(bool(restored_world.apply_new_session_plan(next_session_plan).get("applied", false)), "new-session plan resets authoritative world data")
	restored_consumer.reset_state()
	flow.region_snapshots = {"region.000": _region_gdp(3100, ["sale-new-session-1"])}
	flow.recent_receipts = [_receipt("sale-new-session-1", "region.000", "星露莓", 0, 1000)]
	var next_session_batch := _batch(1, 0, 1, flow.recent_receipts, 1.0, 1.0)
	var next_session_result := restored_consumer.consume_committed_batch(next_session_batch)
	_expect(bool(next_session_result.get("completed", false)) and _city_history_size(restored_world, 0) == 1 and _cash_history_sizes(restored_world) == [1, 1, 1], "a second run's batch sequence 1 is applied instead of being mistaken for a prior-run replay")

	for node in [behind_cash_consumer, behind_cash_visual, behind_cash_derivative, behind_cash_world, cash_ack_consumer, cash_ack_visual, cash_ack_derivative, cash_ack_world, behind_city_consumer, behind_city_visual, behind_city_derivative, behind_city_world, skew_cash_consumer, skew_cash_visual, skew_cash_derivative, skew_cash_world, skew_city_consumer, skew_city_visual, skew_city_derivative, skew_city_world, coordinator, restored_consumer, restored_visual, restored_derivative, restored_world, consumer, visual, derivative, world, flow]:
		if node is Node:
			(node as Node).queue_free()
	await process_frame
	if _failures == 0:
		print("COMMODITY FLOW POSTCOMMIT EXACT-ONCE PASS: %d/%d" % [_checks, _checks])
		quit(0)
	else:
		push_error("COMMODITY FLOW POSTCOMMIT EXACT-ONCE FAIL: %d/%d" % [_failures, _checks])
		quit(1)


func _region_gdp(net_cents: int, receipt_ids: Array) -> Dictionary:
	return {
		"region_gdp_per_minute": int(floor(float(net_cents) / 100.0)),
		"region_gdp_per_minute_cents": net_cents,
		"receipt_ids": receipt_ids.duplicate(),
		"observation_window_seconds": 30.0,
	}


func _city_breakdown(net: int, net_cents: int, receipt_count: int) -> Dictionary:
	return {
		"net": net,
		"net_cents": net_cents,
		"receipt_count": receipt_count,
		"observation_window_seconds": 30.0,
		"competition_matches": 0,
		"product_lines": [],
		"route_lines": [],
		"transit_lines": [],
	}


func _receipt(receipt_id: String, region_id: String, commodity_id: String, owner: int, unit_price_cents: int) -> Dictionary:
	return {
		"receipt_id": receipt_id,
		"commodity_owner": owner,
		"commodity_id": commodity_id,
		"color": "life",
		"units": 1,
		"source_region_id": region_id,
		"market_region_id": region_id,
		"route_id": "",
		"base_unit_price_cents": unit_price_cents,
		"shortest_legal_distance": 0,
		"distance_premium_basis_points": 0,
		"unit_price_cents": unit_price_cents,
		"gdp_value": unit_price_cents,
		"owner_net_cash": unit_price_cents,
		"rent_rows": [],
		"settled_at": 12.0,
	}


func _batch(sequence: int, revision_before: int, revision_after: int, receipts: Array, settled_at: float, delta_seconds: float) -> Dictionary:
	var receipt_ids: Array = []
	for receipt_variant in receipts:
		receipt_ids.append(str((receipt_variant as Dictionary).get("receipt_id", "")))
	var summary := {
		"advanced": true,
		"reason": "",
		"batch_id": "commodity-flow-batch-%010d" % sequence,
		"receipt_count": receipts.size(),
		"flow_revision": revision_after,
		"settled_at": settled_at,
		"flow_delta_seconds": delta_seconds,
		"postcommit_completed": false,
	}
	var result := {
		"batch_id": "commodity-flow-batch-%010d" % sequence,
		"ruleset_id": "v0.6",
		"batch_sequence": sequence,
		"flow_revision_before": revision_before,
		"flow_revision": revision_after,
		"settled_at": settled_at,
		"flow_delta_seconds": delta_seconds,
		"receipt_ids": receipt_ids,
		"receipts": receipts.duplicate(true),
		"flow_result_summary": summary,
	}
	result["batch_fingerprint"] = CommodityFlowPostCommitReceiptConsumer.batch_fingerprint(result)
	return result


func _city_history_size(world: WorldSessionState, district_index: int) -> int:
	var district: Dictionary = world.districts[district_index]
	var city: Dictionary = district.get("city", {}) if district.get("city", {}) is Dictionary else {}
	return (city.get("gdp_history", []) as Array).size() if city.get("gdp_history", []) is Array else 0


func _cash_history_sizes(world: WorldSessionState) -> Array:
	var result: Array = []
	for player_variant in world.players:
		var player: Dictionary = player_variant if player_variant is Dictionary else {}
		result.append((player.get("cash_history", []) as Array).size() if player.get("cash_history", []) is Array else 0)
	return result


func _verify_fault_roundtrip(flow: FakeFlow, fault_stage: StringName) -> Dictionary:
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
	world.replace_districts([{"region_id": "region.000", "city": {"active": true}}], true)
	world.game_time = 3.0
	var receipt_id := "fault-%s" % str(fault_stage)
	var receipts := [_receipt(receipt_id, "region.000", "星露莓", 0, 1000)]
	flow.region_snapshots = {"region.000": _region_gdp(1800, [receipt_id])}
	flow.recent_receipts = receipts.duplicate(true)
	_configure_consumer(consumer, flow, world, derivative, visual)
	consumer.inject_test_failure(fault_stage)
	var interrupted := consumer.consume_committed_batch(_batch(1, 0, 1, receipts, 3.0, 1.0))
	var consumer_save := consumer.to_save_data()
	var world_save := world.to_save_data()
	if fault_stage == &"after_city_breakdown_snapshot":
		flow.region_snapshots = {"region.000": _region_gdp(999900, ["drifted-live-receipt"])}
		flow.recent_receipts = [_receipt("drifted-live-receipt", "region.000", "蓝潮藻", 1, 9999)]
	var original_bankruptcy := consumer.get_meta("test_bankruptcy_owner") as FakeBankruptcy
	var original_mana := consumer.get_meta("test_mana_owner") as FakeMana
	var bankruptcy_save := original_bankruptcy.finalized_ids.duplicate(true) if original_bankruptcy != null else {}
	var mana_save := original_mana.to_save_data() if original_mana != null else {}
	var original_derivative_count := derivative.settle_calls.size()
	var original_pulse_count := int(visual.debug_snapshot().get("postcommit_pulse_lineage_count", 0))

	var restored_world := WORLD_SCENE.instantiate() as WorldSessionState
	var restored_derivative := FakeDerivative.new()
	var restored_visual := VISUAL_SCENE.instantiate() as VisualCueRuntimeOwner
	var restored_consumer := CONSUMER_SCENE.instantiate() as CommodityFlowPostCommitReceiptConsumer
	root.add_child(restored_world)
	root.add_child(restored_derivative)
	root.add_child(restored_visual)
	root.add_child(restored_consumer)
	restored_world.apply_save_data(world_save)
	_configure_consumer(restored_consumer, flow, restored_world, restored_derivative, restored_visual)
	var restored_bankruptcy := restored_consumer.get_meta("test_bankruptcy_owner") as FakeBankruptcy
	var restored_mana := restored_consumer.get_meta("test_mana_owner") as FakeMana
	if restored_bankruptcy != null:
		restored_bankruptcy.finalized_ids = bankruptcy_save.duplicate(true)
	if restored_mana != null:
		restored_mana.apply_save_data(mana_save)
	var restore_receipt := restored_consumer.apply_save_data(consumer_save, 1)
	var recovered := restored_consumer.retry_pending_batch()
	var restored_public_owner := restored_consumer.get_meta("test_public_log_owner") as PublicLogPresentationOwner
	var restored_scheduler := restored_consumer.get_meta("test_presentation_scheduler") as TablePresentationRefreshScheduler
	var presentation_due := restored_scheduler.advance_typed(0.0)
	var presentation_second_due := restored_scheduler.advance_typed(0.0)
	var result := {
		"interrupted": not bool(interrupted.get("completed", true)) and int((consumer_save.get("journal", {}) as Dictionary).size()) == 1,
		"recovered": bool(restore_receipt.get("applied", false)) and bool(recovered.get("completed", false)) and bool(recovered.get("recovered", false)),
		"recovery_reason": "%s/%s" % [str(restore_receipt.get("reason_code", "")), str(recovered.get("reason_code", ""))],
		"city_history_size": _city_history_size(restored_world, 0),
		"city_gdp": restored_world.commodity_postcommit_city_gdp(0),
		"derivative_apply_count": original_derivative_count + restored_derivative.settle_calls.size(),
		"pulse_apply_count": original_pulse_count + int(restored_visual.debug_snapshot().get("postcommit_pulse_lineage_count", 0)),
		"cash_history_sizes": _cash_history_sizes(restored_world),
		"restored_public_receipt_count": restored_public_owner.recent_public_entries(90).size(),
		"presentation_due_count": presentation_due.size(),
		"presentation_second_due_count": presentation_second_due.size(),
	}
	for node in [restored_consumer, restored_visual, restored_derivative, restored_world, consumer, visual, derivative, world]:
		node.queue_free()
	await process_frame
	return result


func _verify_public_tail_same_runtime(flow: FakeFlow) -> Dictionary:
	var result := {"public_log_exact_once": false, "presentation_exact_once": false}
	for fault_stage in [&"after_public_log_target_before_mark", &"after_presentation_invalidation_before_mark"]:
		var world := WORLD_SCENE.instantiate() as WorldSessionState
		var derivative := FakeDerivative.new()
		var visual := VISUAL_SCENE.instantiate() as VisualCueRuntimeOwner
		var consumer := CONSUMER_SCENE.instantiate() as CommodityFlowPostCommitReceiptConsumer
		for node in [world, derivative, visual, consumer]:
			root.add_child(node)
		world.replace_players([
			{"id": 0, "cash": 100, "cash_cents": 10000},
			{"id": 1, "cash": 100, "cash_cents": 10000},
			{"id": 2, "cash": 100, "cash_cents": 10000},
		], true)
		world.replace_districts([{"region_id": "region.000", "city": {"active": true}}], true)
		var receipt_id := "same-runtime-%s" % str(fault_stage)
		var receipts := [_receipt(receipt_id, "region.000", "星露莓", 0, 1000)]
		flow.region_snapshots = {"region.000": _region_gdp(2100, [receipt_id])}
		flow.recent_receipts = receipts.duplicate(true)
		_configure_consumer(consumer, flow, world, derivative, visual)
		consumer.inject_test_failure(fault_stage)
		var first := consumer.consume_committed_batch(_batch(1, 0, 1, receipts, 3.0, 1.0))
		var retry := consumer.retry_pending_batch()
		var public_owner := consumer.get_meta("test_public_log_owner") as PublicLogPresentationOwner
		var scheduler := consumer.get_meta("test_presentation_scheduler") as TablePresentationRefreshScheduler
		var due_once := scheduler.advance_typed(0.0).size()
		var due_twice := scheduler.advance_typed(0.0).size()
		var debug := consumer.debug_snapshot()
		var exact := not bool(first.get("completed", true)) \
			and bool(retry.get("completed", false)) \
			and public_owner.recent_public_entries(90).size() == 1 \
			and int(debug.get("public_log_apply_count", -1)) == 1 \
			and int(debug.get("presentation_invalidation_count", -1)) == 1 \
			and due_once == 1 and due_twice == 0
		if fault_stage == &"after_public_log_target_before_mark":
			result["public_log_exact_once"] = exact
		else:
			result["presentation_exact_once"] = exact
		for node in [consumer, visual, derivative, world]:
			node.queue_free()
		await process_frame
	return result


func _verify_empty_finalized_roundtrip(
	flow: FakeFlow,
	save_data: Dictionary,
	empty_batch: Dictionary
) -> Dictionary:
	var world := WORLD_SCENE.instantiate() as WorldSessionState
	var derivative := FakeDerivative.new()
	var visual := VISUAL_SCENE.instantiate() as VisualCueRuntimeOwner
	var consumer := CONSUMER_SCENE.instantiate() as CommodityFlowPostCommitReceiptConsumer
	for node in [world, derivative, visual, consumer]:
		root.add_child(node)
	world.replace_players([{"id": 0, "cash": 100, "cash_cents": 10000}], true)
	world.replace_districts([], true)
	_configure_consumer(consumer, flow, world, derivative, visual)
	var bankruptcy := consumer.get_meta("test_bankruptcy_owner") as FakeBankruptcy
	var mana := consumer.get_meta("test_mana_owner") as FakeMana
	var applied := consumer.apply_save_data(save_data, 3)
	var world_before := world.to_save_data()
	var visual_before := visual.debug_snapshot()
	var replay := consumer.consume_committed_batch(empty_batch)
	var retry := consumer.retry_pending_batch()
	var public_owner := consumer.get_meta("test_public_log_owner") as PublicLogPresentationOwner
	var scheduler := consumer.get_meta("test_presentation_scheduler") as TablePresentationRefreshScheduler
	var result := {
		"roundtrip_equal": bool(applied.get("applied", false))
			and int(applied.get("pending_count", -1)) == 0
			and consumer.to_save_data() == save_data,
		"replay_zero_side_effect": bool(replay.get("completed", false))
			and bool(replay.get("replayed", false))
			and int(replay.get("receipt_count", -1)) == 0
			and str(retry.get("reason_code", "")) == "commodity_postcommit_idle"
			and world.to_save_data() == world_before
			and visual.debug_snapshot() == visual_before
			and derivative.settle_calls.is_empty()
			and bankruptcy != null and bankruptcy.calls == 0
			and mana != null and mana.calls == 0
			and public_owner.recent_public_entries(8).is_empty()
			and scheduler.advance_typed(0.0).is_empty(),
	}
	for node in [bankruptcy, mana, consumer, visual, derivative, world]:
		if node != null:
			node.queue_free()
	await process_frame
	return result


func _verify_journal_capacity_boundary(flow: FakeFlow) -> Dictionary:
	var world := WORLD_SCENE.instantiate() as WorldSessionState
	var derivative := FakeDerivative.new()
	var visual := VISUAL_SCENE.instantiate() as VisualCueRuntimeOwner
	var consumer := CONSUMER_SCENE.instantiate() as CommodityFlowPostCommitReceiptConsumer
	for node in [world, derivative, visual, consumer]:
		root.add_child(node)
	world.replace_players([{"id": 0, "cash": 100, "cash_cents": 10000}], true)
	world.replace_districts([], true)
	_configure_consumer(consumer, flow, world, derivative, visual)
	var all_completed := true
	for sequence in range(1, CommodityFlowPostCommitReceiptConsumer.JOURNAL_LIMIT + 1):
		var completed := consumer.consume_committed_batch(
			_batch(sequence, sequence - 1, sequence, [], float(sequence), 1.0)
		)
		all_completed = all_completed and bool(completed.get("completed", false))
	var pending_sequence := CommodityFlowPostCommitReceiptConsumer.JOURNAL_LIMIT + 1
	var pending_batch := _batch(
		pending_sequence,
		pending_sequence - 1,
		pending_sequence,
		[],
		float(pending_sequence),
		1.0
	)
	var prepared := consumer.prepare_committed_batch(pending_batch)
	var pending_save := consumer.to_save_data()
	var pending_preflight := consumer.preflight_save_data(pending_save, pending_sequence)
	var oldest_id := "commodity-flow-batch-%010d" % 1
	var oldest_record: Dictionary = ((pending_save.get("journal", {}) as Dictionary).get(oldest_id, {}) as Dictionary).duplicate(true)
	var finalized := consumer.consume_committed_batch(pending_batch)
	var pruned_save := consumer.to_save_data()
	var overflow_save := pruned_save.duplicate(true)
	var overflow_journal: Dictionary = (overflow_save.get("journal", {}) as Dictionary).duplicate(true)
	overflow_journal[oldest_id] = oldest_record
	overflow_save["journal"] = overflow_journal
	var overflow_order: Array = (overflow_save.get("terminal_order", []) as Array).duplicate()
	overflow_order.push_front(oldest_id)
	overflow_save["terminal_order"] = overflow_order
	var before_reject := consumer.to_save_data()
	var overflow_preflight := consumer.preflight_save_data(overflow_save, pending_sequence)
	var overflow_apply := consumer.apply_save_data(overflow_save, pending_sequence)
	var result := {
		"pending_overflow_accepted": all_completed
			and bool(prepared.get("staged", false))
			and (pending_save.get("journal", {}) as Dictionary).size() == CommodityFlowPostCommitReceiptConsumer.JOURNAL_LIMIT + 1
			and bool(pending_preflight.get("accepted", false)),
		"terminal_pruned": bool(finalized.get("completed", false))
			and str(pruned_save.get("pending_batch_id", "")).is_empty()
			and (pruned_save.get("journal", {}) as Dictionary).size() == CommodityFlowPostCommitReceiptConsumer.JOURNAL_LIMIT
			and (pruned_save.get("terminal_order", []) as Array).size() == CommodityFlowPostCommitReceiptConsumer.JOURNAL_LIMIT,
		"terminal_overflow_rejected": not bool(overflow_preflight.get("accepted", true))
			and str(overflow_preflight.get("reason_code", "")) == "commodity_postcommit_save_cursor_invalid"
			and not bool(overflow_apply.get("applied", true))
			and consumer.to_save_data() == before_reject,
	}
	var bankruptcy := consumer.get_meta("test_bankruptcy_owner") as FakeBankruptcy
	var mana := consumer.get_meta("test_mana_owner") as FakeMana
	for node in [bankruptcy, mana, consumer, visual, derivative, world]:
		if node != null:
			node.queue_free()
	await process_frame
	return result


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
	consumer.set_meta("test_bankruptcy_owner", bankruptcy)
	consumer.set_meta("test_mana_owner", mana)
	var presentation := _attach_presentation_dependencies(consumer)
	return consumer.configure(
		flow,
		world,
		derivative,
		visual,
		bankruptcy,
		mana,
		presentation.get("public_log_port") as PublicLogProducerPort,
		presentation.get("scheduler") as TablePresentationRefreshScheduler
	)


func _attach_presentation_dependencies(consumer: CommodityFlowPostCommitReceiptConsumer) -> Dictionary:
	var public_log_owner := PublicLogPresentationOwner.new()
	var public_log_port := PublicLogProducerPort.new()
	var scheduler := TablePresentationRefreshScheduler.new()
	consumer.add_child(public_log_owner)
	consumer.add_child(public_log_port)
	consumer.add_child(scheduler)
	public_log_port.configure(public_log_owner)
	scheduler.reset_table_cadence()
	consumer.set_meta("test_public_log_owner", public_log_owner)
	consumer.set_meta("test_public_log_port", public_log_port)
	consumer.set_meta("test_presentation_scheduler", scheduler)
	return {
		"public_log_owner": public_log_owner,
		"public_log_port": public_log_port,
		"scheduler": scheduler,
	}


func _verify_downstream_target_failures(flow: FakeFlow) -> Dictionary:
	var results := {"bankruptcy_recovered": false, "asset_recovery_recovered": false, "bankruptcy_reason": "", "asset_reason": ""}
	for failure_kind in ["bankruptcy", "asset"]:
		var world := WORLD_SCENE.instantiate() as WorldSessionState
		var derivative := FakeDerivative.new()
		var visual := VISUAL_SCENE.instantiate() as VisualCueRuntimeOwner
		var consumer := CONSUMER_SCENE.instantiate() as CommodityFlowPostCommitReceiptConsumer
		var bankruptcy := FakeBankruptcy.new()
		var mana := FakeMana.new()
		for node in [world, derivative, visual, consumer, bankruptcy, mana]:
			root.add_child(node)
		world.replace_players([
			{"id": 0, "cash": 100}, {"id": 1, "cash": 100}, {"id": 2, "cash": 100},
		], true)
		world.replace_districts([{"region_id": "region.000", "city": {"active": true}}], true)
		var receipt_id := "downstream-%s" % failure_kind
		var receipts := [_receipt(receipt_id, "region.000", "星露莓", 0, 1000)]
		flow.region_snapshots = {"region.000": _region_gdp(2000, [receipt_id])}
		flow.recent_receipts = receipts.duplicate(true)
		bankruptcy.failures_remaining = 1 if failure_kind == "bankruptcy" else 0
		mana.failures_remaining = 1 if failure_kind == "asset" else 0
		var presentation := _attach_presentation_dependencies(consumer)
		consumer.configure(
			flow,
			world,
			derivative,
			visual,
			bankruptcy,
			mana,
			presentation.get("public_log_port") as PublicLogProducerPort,
			presentation.get("scheduler") as TablePresentationRefreshScheduler
		)
		var first := consumer.consume_committed_batch(_batch(1, 0, 1, receipts, 2.0, 1.0))
		var retry := consumer.retry_pending_batch()
		if failure_kind == "bankruptcy":
			results["bankruptcy_reason"] = "%s/%s calls=%d/%d" % [str(first.get("reason_code", "")), str(retry.get("reason_code", "")), bankruptcy.calls, mana.calls]
			results["bankruptcy_recovered"] = not bool(first.get("completed", true)) \
				and bool(retry.get("completed", false)) and bankruptcy.calls == 2 and mana.calls == 1
		else:
			results["asset_reason"] = "%s/%s calls=%d/%d" % [str(first.get("reason_code", "")), str(retry.get("reason_code", "")), bankruptcy.calls, mana.calls]
			results["asset_recovery_recovered"] = not bool(first.get("completed", true)) \
				and bool(retry.get("completed", false)) and bankruptcy.calls == 1 and mana.calls == 2
		for node in [mana, bankruptcy, consumer, visual, derivative, world]:
			node.queue_free()
		await process_frame
	return results


func _verify_torn_downstream_restore(flow: FakeFlow, fault_stage: StringName) -> Dictionary:
	var world := WORLD_SCENE.instantiate() as WorldSessionState
	var derivative := FakeDerivative.new()
	var visual := VISUAL_SCENE.instantiate() as VisualCueRuntimeOwner
	var consumer := CONSUMER_SCENE.instantiate() as CommodityFlowPostCommitReceiptConsumer
	for node in [world, derivative, visual, consumer]:
		root.add_child(node)
	world.replace_players([{"id": 0, "cash": 100}, {"id": 1, "cash": 100}, {"id": 2, "cash": 100}], true)
	world.replace_districts([{"region_id": "region.000", "city": {"active": true}}], true)
	var receipt_id := "torn-%s" % str(fault_stage)
	var receipts := [_receipt(receipt_id, "region.000", "星露莓", 0, 1000)]
	flow.region_snapshots = {"region.000": _region_gdp(2300, [receipt_id])}
	flow.recent_receipts = receipts.duplicate(true)
	_configure_consumer(consumer, flow, world, derivative, visual)
	consumer.inject_test_failure(fault_stage)
	consumer.consume_committed_batch(_batch(1, 0, 1, receipts, 4.0, 1.0))
	var consumer_save := consumer.to_save_data()
	var world_save := world.to_save_data()
	var original_bankruptcy := consumer.get_meta("test_bankruptcy_owner") as FakeBankruptcy

	var restored_world := WORLD_SCENE.instantiate() as WorldSessionState
	var restored_derivative := FakeDerivative.new()
	var restored_visual := VISUAL_SCENE.instantiate() as VisualCueRuntimeOwner
	var restored_consumer := CONSUMER_SCENE.instantiate() as CommodityFlowPostCommitReceiptConsumer
	for node in [restored_world, restored_derivative, restored_visual, restored_consumer]:
		root.add_child(node)
	restored_world.apply_save_data(world_save)
	_configure_consumer(restored_consumer, flow, restored_world, restored_derivative, restored_visual)
	if fault_stage == &"after_asset_recovery_target_before_mark":
		var restored_bankruptcy := restored_consumer.get_meta("test_bankruptcy_owner") as FakeBankruptcy
		if restored_bankruptcy != null and original_bankruptcy != null:
			restored_bankruptcy.finalized_ids = original_bankruptcy.finalized_ids.duplicate(true)
	restored_consumer.apply_save_data(consumer_save, 1)
	var result := restored_consumer.retry_pending_batch()
	for node in [restored_consumer, restored_visual, restored_derivative, restored_world, consumer, visual, derivative, world]:
		node.queue_free()
	await process_frame
	return result


func _verify_torn_derivative_restore(flow: FakeFlow) -> Dictionary:
	var world := WORLD_SCENE.instantiate() as WorldSessionState
	var derivative := FakeDerivative.new()
	var visual := VISUAL_SCENE.instantiate() as VisualCueRuntimeOwner
	var consumer := CONSUMER_SCENE.instantiate() as CommodityFlowPostCommitReceiptConsumer
	for node in [world, derivative, visual, consumer]:
		root.add_child(node)
	world.replace_players([{"id": 0, "cash": 100}, {"id": 1, "cash": 100}, {"id": 2, "cash": 100}], true)
	world.replace_districts([{"region_id": "region.000", "city": {"active": true}}], true)
	var receipts := [_receipt("torn-derivative", "region.000", "星露莓", 0, 1000)]
	flow.region_snapshots = {"region.000": _region_gdp(2400, ["torn-derivative"])}
	flow.recent_receipts = receipts.duplicate(true)
	derivative.due_position = true
	_configure_consumer(consumer, flow, world, derivative, visual)
	consumer.inject_test_failure(&"after_derivative_target_before_mark")
	consumer.consume_committed_batch(_batch(1, 0, 1, receipts, 5.0, 1.0))
	var consumer_save := consumer.to_save_data()
	var world_save := world.to_save_data()

	var restored_world := WORLD_SCENE.instantiate() as WorldSessionState
	var restored_derivative := FakeDerivative.new()
	var restored_visual := VISUAL_SCENE.instantiate() as VisualCueRuntimeOwner
	var restored_consumer := CONSUMER_SCENE.instantiate() as CommodityFlowPostCommitReceiptConsumer
	for node in [restored_world, restored_derivative, restored_visual, restored_consumer]:
		root.add_child(node)
	restored_world.apply_save_data(world_save)
	restored_derivative.due_position = true
	_configure_consumer(restored_consumer, flow, restored_world, restored_derivative, restored_visual)
	restored_consumer.apply_save_data(consumer_save, 1)
	var result := restored_consumer.retry_pending_batch()
	for node in [restored_consumer, restored_visual, restored_derivative, restored_world, consumer, visual, derivative, world]:
		node.queue_free()
	await process_frame
	return result


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("COMMODITY FLOW POSTCOMMIT: %s" % message)
