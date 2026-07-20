extends SceneTree

const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")
const WORLD_STATE_SCENE := preload("res://scenes/runtime/WorldSessionState.tscn")
const SELECTION_SCENE := preload("res://scenes/runtime/TableSelectionState.tscn")
const COOLDOWN_SCENE := preload("res://scenes/runtime/CardCooldownRuntimeController.tscn")
const COMMITMENT_SCENE := preload("res://scenes/runtime/CardCommitmentRuntimeService.tscn")

const TYPED_OWNER_NAMES := [
	"CardResolutionHistoryRuntimeService",
	"CardResolutionPresentationPort",
	"CardIntelRuntimeService",
	"CardEffectRuntimeRouter",
	"CardCommitmentRuntimeService",
	"CardCounterSettlementRuntimeService",
	"CardPlaySubmissionRuntimeController",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var coordinator := COORDINATOR_SCENE.instantiate() as GameRuntimeCoordinator
	root.add_child(coordinator)
	await process_frame
	for owner_name in TYPED_OWNER_NAMES:
		_expect(coordinator.find_children(owner_name, "", true, false).size() == 1, "%s is production-composed exactly once" % owner_name)

	var execution_port := coordinator.get_node_or_null("CardResolutionExecutionWorldBridge") as CardResolutionExecutionWorldBridge
	var submission := coordinator.get_node_or_null("CardPlaySubmissionRuntimeController") as CardPlaySubmissionRuntimeController
	var history := coordinator.get_node_or_null("CardResolutionHistoryRuntimeService") as CardResolutionHistoryRuntimeService
	var presentation := coordinator.get_node_or_null("CardResolutionPresentationPort") as CardResolutionPresentationPort
	var ai := coordinator.get_node_or_null("AiRuntimeController") as AiRuntimeController
	_expect(execution_port != null and bool(execution_port.debug_snapshot().get("typed_execution_port", false)), "production execution bridge is a typed port")
	_expect(int(execution_port.debug_snapshot().get("dynamic_main_access_count", -1)) == 0, "typed execution port reports zero dynamic Main access")
	_expect(submission != null and bool(submission.debug_snapshot().get("shared_human_ai_entry", false)), "one typed submission owner serves human and AI")
	var ai_debug := ai.debug_snapshot() if ai != null else {}
	_expect(bool(ai_debug.get("typed_card_submission_bound", false)) and bool(ai_debug.get("typed_card_history_bound", false)), "AI is bound to typed submission and history owners")
	_expect(coordinator.card_play_submission_controller() == submission, "coordinator human entry returns the production submission owner")

	_verify_sources()
	_verify_selection_roundtrip()
	_verify_history_privacy(history)
	_verify_presentation_privacy(presentation)
	_verify_commitment_semantics()

	coordinator.queue_free()
	await process_frame
	_finish()


func _verify_sources() -> void:
	var execution_source := FileAccess.get_file_as_string("res://scripts/runtime/card_resolution_execution_world_bridge.gd")
	for forbidden in ["world.call", "world.get", "world.set", "world.has_method", "get_node_or_null", "current_scene", "apply_intent(world", "Callable("]:
		_expect(not execution_source.contains(forbidden), "execution port omits dynamic Main pattern %s" % forbidden)
	var ai_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_runtime_controller.gd")
	_expect(not ai_source.contains("_call_world(&\"_queue_skill_resolution\"") and ai_source.contains("_card_play_submission_controller.submit_card_play"), "AI submits through the shared typed controller without Main fallback")
	var contract_source := FileAccess.get_file_as_string("res://scripts/runtime/contract_runtime_world_bridge.gd")
	_expect(not contract_source.contains("get(\"resolved_card_history\"") and not contract_source.contains("set(\"resolved_card_history\""), "contract tracing uses the typed history owner")


func _verify_selection_roundtrip() -> void:
	var selection := SELECTION_SCENE.instantiate() as TableSelectionState
	root.add_child(selection)
	selection.select_card_resolution_target(73, -1, int(selection.snapshot().get("revision", -1)))
	var saved := selection.to_save_data()
	selection.select_card_resolution_target(-1, -1, int(selection.snapshot().get("revision", -1)))
	selection.apply_save_data(saved)
	_expect(selection.selected_card_resolution_id == 73, "selected resolution is scene-owned and survives save/load")
	selection.queue_free()


func _verify_history_privacy(history: CardResolutionHistoryRuntimeService) -> void:
	history.configure({"history_limit": 4})
	var entry := {
		"resolution_id": 501,
		"player_index": 2,
		"slot_index": 4,
		"skill": {"name": "星链拆解", "kind": "player_hand_disrupt"},
		"true_owner": 2,
		"hidden_owner": "SECRET_OWNER",
		"cash": 777,
		"ai_plan": "SECRET_PLAN",
	}
	_expect(bool(history.append_resolved(entry).get("appended", false)), "history appends a resolved card once")
	_expect(bool(history.append_resolved(entry).get("duplicate", false)), "history rejects duplicate resolution lineage")
	var public_text := JSON.stringify(history.public_history_snapshot())
	for forbidden in ["player_index", "slot_index", "true_owner", "hidden_owner", "cash", "ai_plan", "SECRET_OWNER", "SECRET_PLAN"]:
		_expect(not public_text.contains(forbidden), "public history omits %s" % forbidden)


func _verify_presentation_privacy(presentation: CardResolutionPresentationPort) -> void:
	presentation.reset_state()
	var receipt := presentation.publish_public_event({
		"event_id": "typed-cutover-1",
		"event_kind": "card_aftermath",
		"resolution_id": 501,
		"card_name": "星链拆解",
		"summary": "公开结果",
		"player_index": 2,
		"cash": 999,
		"true_owner": 2,
		"ai_reason": "SECRET_REASON",
	})
	_expect(bool(receipt.get("published", false)), "public card presentation receipt publishes")
	var public_text := JSON.stringify(presentation.public_snapshot())
	for forbidden in ["player_index", "cash", "true_owner", "ai_reason", "SECRET_REASON"]:
		_expect(not public_text.contains(forbidden), "public presentation omits %s" % forbidden)


func _verify_commitment_semantics() -> void:
	var world := WORLD_STATE_SCENE.instantiate() as WorldSessionState
	var cooldown := COOLDOWN_SCENE.instantiate() as CardCooldownRuntimeController
	var commitment := COMMITMENT_SCENE.instantiate() as CardCommitmentRuntimeService
	for node in [world, cooldown, commitment]:
		root.add_child(node)
	world.players = [{
		"cash": 100,
		"action_cooldown": 0.0,
		"slots": [null],
	}]
	cooldown.configure(world)
	commitment.set_dependencies(world, cooldown, null, null, null)
	var request := {
		"transaction_id": "countered-or-failed:901",
		"entry": {
			"resolution_id": 901,
			"player_index": 0,
			"slot_index": 0,
			"consumed_on_queue": true,
			"play_cost_paid_on_queue": true,
		},
		"skill": {"name": "一次性干扰", "kind": "player_hand_disrupt", "play_cash_cost": 25},
		"selected_district": -1,
	}
	var first := commitment.finalize_commitment(request)
	var second := commitment.finalize_commitment(request)
	_expect(bool(first.get("committed", false)) and first == second, "commitment is exact-once for repeated resolution intent")
	_expect(int((world.players[0] as Dictionary).get("cash", -1)) == 100, "queue-paid play cash is never charged twice at failed/countered settlement")
	_expect((world.players[0] as Dictionary).get("slots", []).size() == 1 and (world.players[0] as Dictionary).get("slots", [])[0] == null, "one-shot committed at submission is not restored after failed/countered settlement")
	for node in [world, cooldown, commitment]:
		node.queue_free()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Card execution typed ports cutover passed (%d checks)." % _checks)
		quit(0)
		return
	push_error("Card execution typed ports cutover failed:\n- " + "\n- ".join(_failures))
	quit(1)
