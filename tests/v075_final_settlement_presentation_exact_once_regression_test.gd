extends SceneTree

const Identity := preload(
	"res://scripts/v075/presentation/v075_presentation_receipt_identity_v2.gd"
)
const Consumer := preload(
	"res://scripts/v075/presentation/v075_combat_presentation_consumer.gd"
)


class FocusVictoryController extends VictoryControlRuntimeController:
	var authoritative_outcome: Dictionary = {}
	var public_value: Dictionary = {}

	func public_snapshot(_viewer_index := -1) -> Dictionary:
		return public_value.duplicate(true)

	func outcome_receipt() -> Dictionary:
		return authoritative_outcome.duplicate(true)


class FocusWorldBridge extends VictoryControlWorldBridge:
	func capture_world_snapshot(
		_clock_pause: Dictionary = {},
		settlement_checkpoint := "read_only"
	) -> Dictionary:
		return {"settlement_checkpoint": settlement_checkpoint}


class FocusSessionController extends GameSessionRuntimeController:
	var finished := false
	var finish_attempt_count := 0
	var successful_finish_count := 0
	var failed_finish_attempts_remaining := 1

	func finish_session(_result_summary: Dictionary = {}) -> void:
		finish_attempt_count += 1
		if failed_finish_attempts_remaining > 0:
			failed_finish_attempts_remaining -= 1
			return
		finished = true
		successful_finish_count += 1

	func is_finished() -> bool:
		return finished

	func session_summary() -> Dictionary:
		return {
			"session_state": "running",
			"session_id": "session.final.settlement.focused",
			"scenario_id": "final-settlement-focused",
			"ruleset_id": "v0.6",
			"seed": 7506,
			"setup": {},
			"save_state": "dirty",
			"dirty": true,
			"outcome_receipt": {},
		}

	func session_start_revision() -> int:
		return 1


class FocusPresentationQueries extends TablePresentationQueryPorts:
	var outcome_count := 0
	var receipt: VictoryPresentationStateChangeReceipt

	func capture_victory_outcome(
		public_snapshot: Dictionary
	) -> VictoryPresentationStateChangeReceipt:
		outcome_count += 1
		receipt.public_snapshot = (
			VictoryPresentationStateChangeReceipt.project_public_snapshot(
				public_snapshot
			)
		)
		return receipt


var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var victory := FocusVictoryController.new()
	var world := FocusWorldBridge.new()
	var session := FocusSessionController.new()
	var presentation := FocusPresentationQueries.new()
	presentation.receipt = _terminal_presentation_receipt()
	var port := RuntimeVictoryPort.new()
	for node in [victory, world, session, presentation, port]:
		root.add_child(node)
	port.bind_dependencies(victory, world, session, null, presentation)
	var outcome := _outcome_receipt()
	var public_snapshot := _terminal_public_snapshot(outcome)
	victory.authoritative_outcome = outcome.duplicate(true)
	victory.public_value = public_snapshot.duplicate(true)

	var first := port.commit_terminal_outcome(outcome, public_snapshot)
	var first_debug := port.debug_snapshot()
	_expect(
		not bool(first.get("accepted", true))
			and str(first.get("reason_id", ""))
				== "terminal_session_finish_rejected"
			and bool(first_debug.get("pending_terminal", false))
			and bool(first_debug.get("pending_presentation_committed", false))
			and presentation.outcome_count == 1,
		"real RuntimeVictoryPort retains one accepted FinalSettlement presentation across a failed Session finish"
	)

	var mutated_outcome := outcome.duplicate(true)
	mutated_outcome["reason_code"] = "planet_destroyed"
	var mutated_public := _terminal_public_snapshot(mutated_outcome)
	var collision := port.commit_terminal_outcome(mutated_outcome, mutated_public)
	_expect(
		not bool(collision.get("accepted", true))
			and str(collision.get("reason_id", ""))
				== "terminal_outcome_binding_collision"
			and presentation.outcome_count == 1
			and session.finish_attempt_count == 1,
		"same terminal outcome ID with changed semantic binding fails closed before any duplicate side effect"
	)

	var retry := port.commit_terminal_outcome(outcome, public_snapshot)
	var replay_after_finish := port.commit_terminal_outcome(outcome, public_snapshot)
	var final_debug := port.debug_snapshot()
	_expect(
		bool(retry.get("accepted", false))
			and str(replay_after_finish.get("reason_id", ""))
				== "session_already_finished"
			and presentation.outcome_count == 1
			and session.successful_finish_count == 1
			and int(final_debug.get("terminal_commit_count", -1)) == 1,
		"same-fingerprint Session retry reuses one Presentation and commits FinalSettlement exactly once"
	)

	var consumer := Consumer.new()
	root.add_child(consumer)
	var combat_receipt := Identity.build_public(
		"source.final.settlement.presentation.001",
		Identity.canonical_sha256("source-final-settlement"),
		0,
		"facility_combat_damaged",
		0,
		"v0.7.5",
		"session.final.settlement.presentation",
		{
			"target_facility_id": "facility.public.001",
			"facility_type": "market",
			"damage_amount": 2,
			"facility_damage_state": "damaged",
		}
	)
	var applied := consumer.consume_receipt(combat_receipt)
	consumer.set_terminal_phase("final_settlement")
	var rejected := consumer.consume_receipt(Identity.build_public(
		"source.final.settlement.presentation.002",
		Identity.canonical_sha256("source-after-final-settlement"),
		1,
		"facility_combat_damaged",
		0,
		"v0.7.5",
		"session.final.settlement.presentation",
		{"target_facility_id": "facility.public.002", "damage_amount": 1}
	))
	var combat_debug := consumer.debug_snapshot()
	_expect(
		bool(applied.get("applied", false))
			and str(rejected.get("reason_code", ""))
				== "post_settlement_combat_effect_rejected"
			and int(combat_debug.get("applied_receipt_count", -1)) == 1
			and int(combat_debug.get("collision_receipt_count", -1)) == 0,
		"FinalSettlement makes the combat Presentation path quiescent without weakening collision fail-closed"
	)

	for node in [consumer, port, presentation, session, world, victory]:
		node.queue_free()
	await process_frame
	_finish()


func _terminal_presentation_receipt() -> VictoryPresentationStateChangeReceipt:
	var receipt := VictoryPresentationStateChangeReceipt.new()
	receipt.receipt_id = "victory-outcome-focused-fixture"
	receipt.revision = 1
	receipt.change_kind = &"outcome"
	receipt.previous_state = "audit"
	receipt.state = "resolved"
	receipt.world_time = 12.5
	receipt.public_snapshot = (
		VictoryPresentationStateChangeReceipt.project_public_snapshot(
			_terminal_public_snapshot(_outcome_receipt())
		)
	)
	receipt.participant_names = {"0": "Test Player"}
	receipt.public_map_facts = {"active_city_count": 3}
	receipt.immediate_refresh_mask = [&"live", &"full"]
	return receipt


func _terminal_public_snapshot(outcome: Dictionary) -> Dictionary:
	return {
		"controller_id": "victory_control_runtime_v06",
		"ruleset_id": "v0.6",
		"state": "resolved",
		"victory_rule": {
			"surviving_region_count": 4,
			"coverage_basis_points": 4000,
			"required_region_count": 2,
			"gdp_per_required_region_per_minute": 36,
			"required_top_k_gdp_per_minute": 72,
			"required_top_k_gdp_per_minute_cents": 7200,
			"ordinary_victory_paused": false,
		},
		"qualification_remaining_seconds": 0.0,
		"audit_remaining_seconds": 0.0,
		"audit_roster": [0],
		"audit_entries": [],
		"paused": false,
		"pause_reasons": [],
		"settlement_checkpoint": "post_world_settlement",
		"outcome_receipt": outcome.duplicate(true),
		"visibility_scope": "public",
	}


func _outcome_receipt() -> Dictionary:
	return {
		"outcome_id": "victory.v06.presentation.focused.1",
		"schema_version": "victory_outcome_v1",
		"ruleset_id": "v0.6",
		"reason_code": "public_audit_complete",
		"winner_player_indices": [0],
		"co_victory": false,
		"comparison_order": [
			"top_k_gdp_per_minute_cents",
			"controlled_region_count",
			"cash_ledger_cents",
		],
		"rankings": [{
			"player_index": 0,
			"top_k_gdp_per_minute_cents": 7200,
			"top_k_gdp_per_minute": 72,
			"top_n_gdp_per_minute": 72,
			"controlled_region_count": 2,
			"winner": true,
		}],
		"audit_evidence": {
			"victory_rule": {"required_region_count": 2},
			"audit_roster": [0],
			"settlement_checkpoint": "post_world_settlement",
		},
		"visibility_scope": "public",
	}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print(
		"V075_FINAL_SETTLEMENT_PRESENTATION_EXACT_ONCE_REGRESSION_TEST|status=%s|passed=%d|total=%d|failures=%s"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks - _failures.size(),
			_checks,
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)
