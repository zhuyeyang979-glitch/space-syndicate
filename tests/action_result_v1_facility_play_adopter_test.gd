extends SceneTree

const COORDINATOR_PATH := "res://scripts/runtime/game_runtime_coordinator.gd"
const SUBMISSION_PATH := "res://scripts/runtime/card_play_submission_runtime_controller.gd"
const FLOW_PATH := "res://scripts/runtime/table_player_action_application_flow_controller.gd"
const ADAPTER_PATH := "res://scripts/runtime/facility_card_queue_adapter_v06.gd"
const SCREEN_PATH := "res://scripts/ui/game_screen.gd"
const MAIN_PATH := "res://scripts/main.gd"
const COORDINATOR_SCENE_PATH := "res://scenes/runtime/GameRuntimeCoordinator.tscn"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var coordinator := FileAccess.get_file_as_string(COORDINATOR_PATH)
	var submission := FileAccess.get_file_as_string(SUBMISSION_PATH)
	var flow := FileAccess.get_file_as_string(FLOW_PATH)
	var adapter := FileAccess.get_file_as_string(ADAPTER_PATH)
	var screen := FileAccess.get_file_as_string(SCREEN_PATH)
	var main := FileAccess.get_file_as_string(MAIN_PATH)
	var scene := FileAccess.get_file_as_string(COORDINATOR_SCENE_PATH)
	var retired_execute := "execute_" + "v06_facility_play_action"
	var retired_submit := "submit_" + "v06_facility_play_action"
	var retired_ai_port := "func play_" + "runtime_card(request: Dictionary)"

	_expect(not coordinator.contains(retired_execute), "Coordinator direct facility action port is physically absent")
	_expect(not submission.contains(retired_submit), "submission controller direct facility action port is physically absent")
	_expect(not coordinator.contains(retired_ai_port), "Coordinator direct AI facility card port is physically absent")
	_expect(not main.contains(retired_execute) and not main.contains("queue_v06_facility_card_action"), "Main owns no direct or queued facility routing")
	_expect(submission.contains("func _queue_v06_facility(") and submission.contains("_facility_queue_source.submit(_facility_queue_capability"), "v0.6 facilities have one capability-bound queue submission adapter path")
	_expect(submission.contains("CardBinding.matches_private_instance_ref(") and submission.contains("CardBinding.hand_slot_ref(slot_index)"), "facility queue submission validates the opaque Action Spine card binding before storing the authoritative runtime instance")
	_expect(adapter.contains("str(summary.get(\"session_state\", \"\")) != GameSessionRuntimeController.STATE_RUNNING"), "facility queue submission remains restricted to a running production session")
	_expect(adapter.contains("StableTargetEnvelope.context_at_capture(stable_target_envelope)") and adapter.contains("entry_context[\"stable_target_envelope\"] = stable_target_envelope"), "facility queue entry mirrors the complete stable target context through the shared envelope contract")
	_expect(adapter.contains("_asset_reservation_id(request)") and not adapter.contains("facility_queue_not_idle"), "facility reservations bind to request identity while ordinary Queue grouping remains authoritative")
	_expect(adapter.contains("preflight_finalize_queued_facility_card") and adapter.contains("preflight_finalize_facility_card_escrow") and adapter.contains("_rollback_resolution_owners(") and adapter.contains("func settle_commitment("), "cross-owner finalization is preflighted, compensated, and retryable before rollback windows close")
	_expect(flow.contains("_card_play().request_hand_play(request)") and flow.contains("bool(v06_receipt.get(\"queued\", false))"), "human and AI GameAction intents share the typed card submission path")
	_expect(flow.contains("CARD_BINDING.resolution_ref(") and flow.contains("if queued and accepted else"), "queued facility receipts attest only the committed Queue entry, never a completed facility effect")
	_expect(not coordinator.contains("func queue_v06_facility_card_action(") and coordinator.contains("func resolve_queued_v06_facility_card_action("), "caller-facing Coordinator submission is removed while resolution keeps narrow owner delegation")
	_expect(scene.count("FacilityCardQueueAdapterV06") == 2, "Coordinator scene composes exactly one facility queue adapter resource and node")
	_expect(screen.contains("reason_id == \"facility-card-queued\"") and screen.contains("\"pending\" if queued"), "accepted facility queue receipts remain pending in player feedback")
	_expect(not coordinator.contains("await process_frame") and not coordinator.contains("Timer"), "production queue phase separation is command-driven")

	print("ACTION_RESULT_V1_FACILITY_PLAY_ADOPTER_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	quit(_failures.size())


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)
