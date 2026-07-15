extends SceneTree

const ActionResultV1Script := preload("res://scripts/runtime/action_result_v1.gd")
const ActionResultPresentationServiceScript := preload("res://scripts/runtime/action_result_presentation_service.gd")
const CardResolutionMainTestHarnessScript := preload("res://tests/helpers/card_resolution_main_test_harness.gd")

const OUTCOMES := [
	"player_unavailable",
	"queued_entry_missing",
	"group_window_closed",
	"already_ready",
	"ready_rejected",
	"group_ready_committed",
]

var _checks := 0
var _failures: Array[String] = []


class FeedbackSpy:
	extends Control

	var last_feedback: Dictionary = {}

	func _show_player_action_feedback(action_id: String, state: String = "pending", detail: String = "") -> void:
		last_feedback = {
			"action_id": action_id,
			"state": state,
			"detail": detail,
		}


class RejectingReadyController:
	extends Node

	var ready_calls := 0
	var simultaneous_timer := 30.0
	var window_sequence := 3

	func current_phase(_facts: Dictionary = {}) -> String:
		return "planning"

	func cadence_snapshot(sequence: int = 3) -> Dictionary:
		return {
			"window_sequence": sequence,
			"total_seconds": 30,
			"planning_seconds": 20,
			"public_bid_seconds": 5,
			"lock_seconds": 5,
		}

	func debug_snapshot() -> Dictionary:
		return {"ready_players": {}}

	func set_player_ready(_player_index: int, _ready_state: bool, _active_player_indices: Array) -> Dictionary:
		ready_calls += 1
		return {"changed": false, "reason": "qa_reject"}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_presentation_contract()
	_test_main_success_and_failures()
	_test_dead_priority_bid_ui_entrypoints_retired()
	_finish()


func _test_presentation_contract() -> void:
	var service := ActionResultPresentationServiceScript.new() as Node
	service.call("configure", {})
	var schema: Array = service.call("public_field_schema")
	for outcome_variant in OUTCOMES:
		var outcome := str(outcome_variant)
		var result: Dictionary = service.call("compose", _request(outcome, 101))
		_expect(not result.is_empty(), "%s composes a public ActionResult" % outcome)
		_expect(_same_string_set(result.keys(), schema), "%s exposes only the ActionResult v1 field schema" % outcome)
		_expect(bool(result.get("success", false)) == (outcome == "group_ready_committed"), "%s exposes the correct success status" % outcome)
		_expect(str(result.get("failure_code", "")) == ("" if outcome == "group_ready_committed" else outcome), "%s preserves the public outcome code" % outcome)
		_expect(_required_copy_present(result), "%s explains reason, consequence, and next action" % outcome)
		_expect(result.get("affected_entity_ids", []) == ["resolution:101"], "%s binds only the public resolution id" % outcome)
		_expect(not _contains_private_token(result), "%s output contains no private action facts" % outcome)

	var debug: Dictionary = service.call("debug_snapshot")
	_expect(bool(debug.get("service_ready", false)) and not bool(debug.get("service_authoritative", true)), "presentation service is ready but never action-authoritative")
	_expect(bool(debug.get("owns_action_result_presentation", false)) and not bool(debug.get("owns_rules", true)) and not bool(debug.get("owns_save_state", true)) and not bool(debug.get("mutates_game_state", true)), "presentation service owns copy only")
	_expect(not service.has_method("to_save_data") and not service.has_method("apply_save_data"), "presentation service adds no save owner")

	for missing_field in ["schema_version", "action_id", "action_family", "outcome_code"]:
		var missing := _request("ready_rejected", 101)
		missing.erase(missing_field)
		_expect(ActionResultV1Script.sanitize_request(missing).is_empty(), "request missing %s fails closed" % missing_field)
	var malformed := _request("ready_rejected", 101)
	malformed["schema_version"] = {}
	_expect(ActionResultV1Script.sanitize_request(malformed).is_empty(), "malformed schema version fails closed without coercion")
	var wrong_public: Dictionary = service.call("compose", _request("ready_rejected", 101))
	wrong_public["action_id"] = "buy_card"
	_expect(ActionResultV1Script.sanitize_public_result(wrong_public).is_empty(), "wrong public action identity fails closed")
	wrong_public = service.call("compose", _request("ready_rejected", 101))
	wrong_public["schema_version"] = 2
	_expect(ActionResultV1Script.sanitize_public_result(wrong_public).is_empty(), "wrong public schema fails closed")

	for forbidden_source in [
		{"player_index": 0},
		{"nested": {"cash": 5000}},
		{"nested": {"hand": ["PRIVATE_SENTINEL"]}},
		{"nested": {"owner": "hidden_owner"}},
		{"nested": {"ai_plan": "secret"}},
		{"nested": {"authorization": "PRIVATE_SENTINEL"}},
	]:
		var unsafe := _request("ready_rejected", 101)
		for key_variant in forbidden_source.keys():
			unsafe[key_variant] = forbidden_source[key_variant]
		_expect(ActionResultV1Script.sanitize_request(unsafe).is_empty(), "forbidden raw request fails closed")
		var public_failure: Dictionary = service.call("compose", unsafe)
		_expect(str(public_failure.get("failure_code", "")) == "unsafe_source" and not _contains_private_token(public_failure), "unsafe request produces fixed private-free feedback")
	service.free()


func _test_main_success_and_failures() -> void:
	var success_fixture := _fixture(_entry(0, 101), true)
	var success_main := success_fixture.get("main") as Control
	var success_controller := success_fixture.get("controller") as Node
	var success_queue := success_fixture.get("queue") as Node
	var success_spy := success_fixture.get("spy") as FeedbackSpy
	var success_before := _gameplay_snapshot(success_main, success_controller, success_queue)
	success_main.call("_on_runtime_game_screen_action_requested", "card_group_ready")
	var success_after := _gameplay_snapshot(success_main, success_controller, success_queue)
	_expect(success_spy.last_feedback.get("state", "") == "resolved" and str(success_spy.last_feedback.get("detail", "")).contains("等待其他席位"), "real Main UI action presents structured success feedback")
	_expect((success_after.get("ready_players", {}) as Dictionary) == {"0": true}, "successful ready action commits the selected seat once")
	_expect(success_after.get("queue") == success_before.get("queue") and success_after.get("players") == success_before.get("players") and is_equal_approx(float(success_after.get("timer", 0.0)), float(success_before.get("timer", -1.0))), "successful ready action changes no queue, player, or phase timer state")
	_expect(str(success_after.get("phase", "")) == str(success_before.get("phase", "")), "successful ready action does not advance the phase itself")
	_dispose_fixture(success_fixture)

	var unavailable_fixture := _fixture(_entry(0, 101), true)
	var unavailable_main := unavailable_fixture.get("main") as Control
	var unavailable_players: Array = unavailable_main.get("players")
	(unavailable_players[0] as Dictionary)["eliminated"] = true
	unavailable_main.set("players", unavailable_players)
	_assert_main_failure(unavailable_fixture, "player_unavailable")
	_dispose_fixture(unavailable_fixture)

	var missing_fixture := _fixture(_entry(1, 102), true)
	_assert_main_failure(missing_fixture, "queued_entry_missing")
	_dispose_fixture(missing_fixture)

	var closed_fixture := _fixture(_entry(0, 101), false)
	_assert_main_failure(closed_fixture, "group_window_closed")
	_dispose_fixture(closed_fixture)

	var ready_fixture := _fixture(_entry(0, 101), true)
	var ready_controller := ready_fixture.get("controller") as Node
	ready_controller.call("set_player_ready", 0, true, [0, 1])
	_assert_main_failure(ready_fixture, "already_ready")
	_dispose_fixture(ready_fixture)

	var rejected_fixture := _fixture(_entry(0, 101), true)
	var rejected_main := rejected_fixture.get("main") as Control
	var rejecting_controller := RejectingReadyController.new()
	rejected_main.add_child(rejecting_controller)
	rejected_main.set("card_resolution_runtime_controller", rejecting_controller)
	_assert_main_failure(rejected_fixture, "ready_rejected", rejecting_controller)
	_expect(rejecting_controller.ready_calls == 2, "each of the two explicit ready actions calls the rejecting owner exactly once")
	_dispose_fixture(rejected_fixture)


func _assert_main_failure(fixture: Dictionary, expected_code: String, snapshot_controller: Node = null) -> void:
	var main := fixture.get("main") as Control
	var controller := fixture.get("controller") as Node
	var queue := fixture.get("queue") as Node
	var spy := fixture.get("spy") as FeedbackSpy
	var observed_controller := snapshot_controller if snapshot_controller != null else controller
	var before := _gameplay_snapshot(main, observed_controller, queue)
	var result: Dictionary = main.call("_set_selected_player_card_group_ready")
	var after := _gameplay_snapshot(main, observed_controller, queue)
	_expect(str(result.get("failure_code", "")) == expected_code and not bool(result.get("success", true)), "Main maps %s without a bool-only UI path" % expected_code)
	_expect(after == before, "%s failure does not mutate queue, readiness, timer, phase, or players" % expected_code)
	main.call("_on_runtime_game_screen_action_requested", "card_group_ready")
	_expect(spy.last_feedback.get("state", "") == "blocked" and str(spy.last_feedback.get("detail", "")).strip_edges() != "", "%s reaches non-modal structured UI feedback" % expected_code)
	_expect(_gameplay_snapshot(main, observed_controller, queue) == before, "%s UI dispatch also leaves gameplay state unchanged" % expected_code)


func _fixture(entry: Dictionary, open_window: bool) -> Dictionary:
	var harness := CardResolutionMainTestHarnessScript.new()
	var main := harness.create_main() as Control
	_expect(main != null, "Main test harness composes the production ready action path")
	if main == null:
		return {}
	var controller := harness.controller_for(main)
	var coordinator := harness.coordinator_for(main)
	var queue := coordinator.get_node_or_null("CardResolutionQueueRuntimeService") if coordinator != null else null
	_expect(controller != null and coordinator != null and queue != null, "ready fixture owns controller, coordinator, and queue services")
	main.set("players", [
		{"name": "玩家1", "eliminated": false, "slots": [], "action_cooldown": 0.0},
		{"name": "玩家2", "eliminated": false, "slots": [], "action_cooldown": 0.0},
	])
	main.set("selected_player", 0)
	queue.call("reset_state")
	queue.call("replace_current_queue", [entry])
	controller.call("reset_state")
	if open_window:
		controller.call("begin_group_window", -1.0, 0, 3)
		controller.call("tick", 0.0, main.call("_card_resolution_controller_facts"))
	var spy := FeedbackSpy.new()
	spy.name = "ActionResultFeedbackSpy"
	main.add_child(spy)
	main.set("runtime_game_screen", spy)
	return {
		"main": main,
		"controller": controller,
		"coordinator": coordinator,
		"queue": queue,
		"spy": spy,
	}


func _entry(player_index: int, resolution_id: int) -> Dictionary:
	return {
		"resolution_id": resolution_id,
		"queued_order": resolution_id,
		"player_index": player_index,
		"window_sequence": 3,
		"group_id": "window_3_player_%d" % player_index,
		"group_position": player_index + 1,
		"group_order": 1,
		"group_size": 1,
		"skill": {"name": "QA公开牌", "kind": "economic"},
	}


func _gameplay_snapshot(main: Control, controller: Node, queue: Node) -> Dictionary:
	var controller_debug_variant: Variant = controller.call("debug_snapshot") if controller != null and controller.has_method("debug_snapshot") else {}
	var controller_debug: Dictionary = controller_debug_variant if controller_debug_variant is Dictionary else {}
	var facts_variant: Variant = main.call("_card_resolution_controller_facts")
	var facts: Dictionary = facts_variant if facts_variant is Dictionary else {}
	var phase := str(controller.call("current_phase", facts)) if controller != null and controller.has_method("current_phase") else ""
	var timer := float(controller.get("simultaneous_timer")) if controller != null else 0.0
	return {
		"queue": queue.call("current_queue") if queue != null else [],
		"ready_players": (controller_debug.get("ready_players", {}) as Dictionary).duplicate(true) if controller_debug.get("ready_players", {}) is Dictionary else {},
		"phase": phase,
		"timer": timer,
		"players": (main.get("players") as Array).duplicate(true),
	}


func _dispose_fixture(fixture: Dictionary) -> void:
	var main := fixture.get("main") as Control
	if main != null:
		main.free()


func _request(outcome_code: String, resolution_id: int) -> Dictionary:
	return {
		"schema_version": 1,
		"action_id": "card_group_ready",
		"action_family": "card_resolution",
		"outcome_code": outcome_code,
		"resolution_id": resolution_id,
	}


func _required_copy_present(result: Dictionary) -> bool:
	for key in ["title", "explanation", "consequence", "suggested_action", "focus_target", "relevant_cost", "relevant_requirement"]:
		if str(result.get(key, "")).strip_edges() == "":
			return false
	return true


func _same_string_set(left: Array, right: Array) -> bool:
	var left_strings: Array[String] = []
	var right_strings: Array[String] = []
	for value in left:
		left_strings.append(str(value))
	for value in right:
		right_strings.append(str(value))
	left_strings.sort()
	right_strings.sort()
	return left_strings == right_strings


func _contains_private_token(value: Variant) -> bool:
	var serialized := var_to_str(value).to_lower()
	for token in ["private_sentinel", "player_index", "cash", "hand", "discard", "slot", "owner", "ai_plan", "ai_score", "authorization", "secret"]:
		if serialized.contains(token):
			return true
	return false


func _test_dead_priority_bid_ui_entrypoints_retired() -> void:
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	for retired_symbol in [
		"bid_set_",
		"func _set_selected_card_priority_bid(",
		"func _increase_selected_card_bid(",
		"func _reset_selected_card_bid(",
		"func _set_selected_card_bid_absolute(",
		"func _set_card_bid_for_player(",
		"func _highest_card_resolution_bid(",
		"set_group_priority_bid_cents",
		"highest_priority_bid_cents",
	]:
		_expect(not main_source.contains(retired_symbol) and not coordinator_source.contains(retired_symbol), "Main and Coordinator retire executable priority-bid entry %s" % retired_symbol)
	_expect(main_source.contains('"card_group_ready"') and main_source.contains("compose_action_result_v1"), "Main adopts ActionResult v1 for the real ready action")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error("ACTION RESULT V1: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("ActionResult v1 test passed. checks=%d" % _checks)
		quit(0)
		return
	push_error("ActionResult v1 test failed:\n- %s" % "\n- ".join(_failures))
	quit(1)
