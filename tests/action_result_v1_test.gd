extends SceneTree

const ActionResultV1Script := preload("res://scripts/runtime/action_result_v1.gd")
const ActionResultPresentationServiceScript := preload("res://scripts/runtime/action_result_presentation_service.gd")

const OUTCOMES := [
	"player_unavailable",
	"queued_entry_missing",
	"group_window_closed",
	"already_ready",
	"ready_rejected",
	"group_ready_committed",
]
const PURE_DATA_ONLY_ARG := "--pure-data"
const CORE_PUBLIC_FIELDS := [
	"success",
	"failure_code",
	"title",
	"explanation",
	"consequence",
	"suggested_action",
	"focus_target",
	"relevant_cost",
	"relevant_requirement",
	"affected_entity_ids",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_presentation_contract()
	_test_public_schema_validator_and_presenter()
	_test_recursive_private_rejection()
	_test_failure_copy_quality()
	var command_line_args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if not command_line_args.has(PURE_DATA_ONLY_ARG):
		_test_main_action_result_entrypoints_retired()
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
	wrong_public["action_id"] = "buy card"
	_expect(ActionResultV1Script.sanitize_public_result(wrong_public).is_empty(), "malformed public action identity fails closed")
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


func _test_public_schema_validator_and_presenter() -> void:
	var service := ActionResultPresentationServiceScript.new() as Node
	var schema: Dictionary = service.call("public_schema_snapshot")
	var field_schema: Array = service.call("public_field_schema")
	var expected_fields: Array = ["schema_version", "action_id", "action_family", "status"] + CORE_PUBLIC_FIELDS
	var expected_types := {
		"schema_version": "int",
		"action_id": "string",
		"action_family": "string",
		"status": "string",
		"success": "bool",
		"failure_code": "string",
		"title": "string",
		"explanation": "string",
		"consequence": "string",
		"suggested_action": "string",
		"focus_target": "string",
		"relevant_cost": "string",
		"relevant_requirement": "string",
		"affected_entity_ids": "array[string]",
	}
	var field_types: Dictionary = schema.get("field_types", {}) if schema.get("field_types", {}) is Dictionary else {}
	_expect(str(schema.get("schema_id", "")) == "action_result.v1" and int(schema.get("schema_version", 0)) == 1, "schema snapshot publishes the stable ActionResult v1 identity")
	_expect(_same_string_set(schema.get("fields", []) as Array, expected_fields) and _same_string_set(schema.get("required_fields", []) as Array, expected_fields), "schema snapshot makes every envelope and core field explicit and required")
	_expect(_same_string_set(schema.get("core_fields", []) as Array, CORE_PUBLIC_FIELDS), "schema snapshot covers every player-facing ActionResult field")
	_expect(_same_string_set(field_schema, expected_fields) and not bool(schema.get("allow_additional_fields", true)), "schema is exact and rejects undeclared fields")
	for field_variant in expected_types.keys():
		var field := str(field_variant)
		_expect(str(field_types.get(field, "")) == str(expected_types[field]), "schema publishes the exact type for %s" % field)
	_expect(int(schema.get("failure_detail_min_length", 0)) >= 8 and int(schema.get("max_affected_entity_ids", 0)) == 64, "schema publishes bounded failure detail and affected-entity limits")
	_expect(_is_pure_data(schema), "schema snapshot contains pure data only")

	(schema.get("core_fields", []) as Array).clear()
	field_types["success"] = "string"
	var fresh_schema: Dictionary = service.call("public_schema_snapshot")
	_expect(_same_string_set(fresh_schema.get("core_fields", []) as Array, CORE_PUBLIC_FIELDS) and str((fresh_schema.get("field_types", {}) as Dictionary).get("success", "")) == "bool", "schema snapshots are defensive copies")

	var success := _public_result(true)
	var failure := _public_result(false)
	_expect(bool(service.call("validate_public_result", success)) and bool(service.call("validate_public_result", failure)), "validator accepts complete generic success and failure results")
	_expect(service.call("presenter_snapshot", failure) == failure, "presenter returns the exact validated pure-data failure snapshot")
	_expect(str(failure.get("action_id", "")) == "fleet_move" and str(failure.get("failure_code", "")) == "target_out_of_range", "v1 validation is reusable beyond the two original adopters")

	var padded := failure.duplicate(true)
	for field_variant in ["action_id", "action_family", "failure_code", "title", "explanation", "consequence", "suggested_action", "focus_target", "relevant_cost", "relevant_requirement"]:
		var field := str(field_variant)
		padded[field] = "  %s  " % str(padded[field])
	padded["affected_entity_ids"] = ["  fleet:7  "]
	var normalized: Dictionary = service.call("presenter_snapshot", padded)
	_expect(str(normalized.get("action_id", "")) == "fleet_move" and str(normalized.get("failure_code", "")) == "target_out_of_range" and normalized.get("affected_entity_ids", []) == ["fleet:7"], "presenter normalizes surrounding whitespace without mutating meaning")
	_expect(str(padded.get("action_id", "")).begins_with("  "), "presenter does not mutate its source dictionary")

	for field_variant in expected_fields:
		var field := str(field_variant)
		var missing := failure.duplicate(true)
		missing.erase(field)
		_expect(not bool(service.call("validate_public_result", missing)) and (service.call("presenter_snapshot", missing) as Dictionary).is_empty(), "validator and presenter reject missing field %s" % field)
		var wrong_type := failure.duplicate(true)
		wrong_type[field] = "fleet:7" if field == "affected_entity_ids" else []
		_expect(not bool(service.call("validate_public_result", wrong_type)) and (service.call("presenter_snapshot", wrong_type) as Dictionary).is_empty(), "validator and presenter reject the wrong type for %s" % field)

	var extra_field := failure.duplicate(true)
	extra_field["debug_detail"] = "not part of v1"
	_expect(not bool(service.call("validate_public_result", extra_field)), "validator rejects additional public-result fields")
	var success_with_failure := success.duplicate(true)
	success_with_failure["failure_code"] = "unexpected_failure"
	_expect(not bool(service.call("validate_public_result", success_with_failure)), "success requires an empty failure_code")
	var failure_without_code := failure.duplicate(true)
	failure_without_code["failure_code"] = ""
	_expect(not bool(service.call("validate_public_result", failure_without_code)), "failure requires a concrete failure_code")
	var wrong_status := failure.duplicate(true)
	wrong_status["status"] = "committed"
	_expect(not bool(service.call("validate_public_result", wrong_status)), "status must agree with success")
	var malformed_focus := failure.duplicate(true)
	malformed_focus["focus_target"] = "fleet board"
	_expect(not bool(service.call("validate_public_result", malformed_focus)), "focus_target is a bounded machine token")

	for invalid_ids_variant in [
		["fleet"],
		["fleet:7", "fleet:7"],
		["owner:7"],
		[7],
	]:
		var invalid_ids := failure.duplicate(true)
		invalid_ids["affected_entity_ids"] = invalid_ids_variant
		_expect(not bool(service.call("validate_public_result", invalid_ids)), "affected_entity_ids reject malformed, duplicate, or private identities")
	var too_many_ids := failure.duplicate(true)
	var entity_ids: Array = []
	for index in range(65):
		entity_ids.append("fleet:%d" % index)
	too_many_ids["affected_entity_ids"] = entity_ids
	_expect(not bool(service.call("validate_public_result", too_many_ids)), "affected_entity_ids enforce the published maximum")
	service.free()


func _test_recursive_private_rejection() -> void:
	var service := ActionResultPresentationServiceScript.new() as Node
	service.call("configure", {})
	for private_key_variant in ["private_hand_probe", "rival_cash_snapshot", "hidden_owner", "ai_weight", "quote_fingerprint"]:
		var private_key := str(private_key_variant)
		var unsafe := _request("ready_rejected", 101)
		unsafe["public_context"] = {
			"layers": [
				{"metadata": {private_key: "redacted"}},
			],
		}
		_expect(ActionResultV1Script.sanitize_request(unsafe).is_empty(), "request recursively rejects private field %s" % private_key)
		var public_failure: Dictionary = service.call("compose", unsafe)
		_expect(str(public_failure.get("failure_code", "")) == "unsafe_source" and not _contains_private_token(public_failure), "recursive private rejection returns fixed public copy for %s" % private_key)

	var safe_purchase := {
		"schema_version": 1,
		"action_id": "district_card_purchase",
		"action_family": "card_market",
		"public_receipt": {
			"event_code": "anonymous_purchase_committed",
			"district_index": 7,
			"price_cash": 202,
		},
	}
	_expect(not ActionResultV1Script.sanitize_request(safe_purchase).is_empty(), "recursive privacy guard preserves the explicit public price_cash receipt field")
	var non_string_key := _request("ready_rejected", 101)
	non_string_key[7] = "not a JSON object key"
	_expect(ActionResultV1Script.sanitize_request(non_string_key).is_empty(), "pure-data dictionaries require string keys at every level")

	var nested_private_result := _public_result(false)
	nested_private_result["affected_entity_ids"] = [{"layers": [{"metadata": {"owner": "redacted"}}]}]
	_expect(not bool(service.call("validate_public_result", nested_private_result)) and (service.call("presenter_snapshot", nested_private_result) as Dictionary).is_empty(), "validator and presenter recursively reject a private field hidden inside an array")
	var private_value_result := _public_result(false)
	private_value_result["explanation"] = "PRIVATE_SENTINEL must never reach presentation"
	_expect(not bool(service.call("validate_public_result", private_value_result)), "validator rejects private value sentinels without echoing them")
	service.free()


func _test_failure_copy_quality() -> void:
	var service := ActionResultPresentationServiceScript.new() as Node
	var vague_copy := [
		"错误。",
		"条件不足。",
		"不能使用，请重试。",
		"目标无效。",
		"操作失败。",
		"发生未知错误，请稍后重试。",
	]
	for field_variant in ["explanation", "consequence", "suggested_action", "relevant_requirement"]:
		var field := str(field_variant)
		for copy_variant in vague_copy:
			var vague_failure := _public_result(false)
			vague_failure[field] = str(copy_variant)
			_expect(not bool(service.call("validate_public_result", vague_failure)) and (service.call("presenter_snapshot", vague_failure) as Dictionary).is_empty(), "failure %s rejects vague copy: %s" % [field, str(copy_variant)])
	_expect(bool(service.call("validate_public_result", _public_result(false))), "failure with reason, consequence, next action, and requirement passes copy quality")
	service.free()














func _test_main_action_result_entrypoints_retired() -> void:
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var flow_source := FileAccess.get_file_as_string("res://scripts/runtime/table_player_action_application_flow_controller.gd")
	var receipt_source := FileAccess.get_file_as_string("res://scripts/semantic/game_action_receipt_v1.gd")
	_expect(not main_source.contains("_on_runtime_game_screen_action_requested") and not main_source.contains("_set_selected_player_card_group_ready") and not main_source.contains("_set_authorized_player_card_group_ready"), "legacy Main ActionResult dispatch and card-group ready entrypoints stay retired")
	_expect(flow_source.contains("func submit_intent(") and flow_source.contains("RECEIPT.build") and receipt_source.contains("class_name GameActionReceiptV1"), "production actions now return the closed GameActionReceiptV1 through the scene-owned flow")
	_expect(FileAccess.file_exists("res://tests/table_player_action_application_flow_test.gd"), "dedicated Action Flow behavior test replaces the retired Main fixture")


func _request(outcome_code: String, resolution_id: int) -> Dictionary:
	return {
		"schema_version": 1,
		"action_id": "card_group_ready",
		"action_family": "card_resolution",
		"outcome_code": outcome_code,
		"resolution_id": resolution_id,
	}


func _public_result(success: bool) -> Dictionary:
	return {
		"schema_version": 1,
		"action_id": "fleet_move",
		"action_family": "fleet_runtime",
		"status": "committed" if success else "rejected",
		"success": success,
		"failure_code": "" if success else "target_out_of_range",
		"title": "舰队移动已完成" if success else "舰队未能进入目标区域",
		"explanation": "舰队已通过公开航线抵达所选区域。" if success else "目标区域不在当前舰队可用航线的连接范围内。",
		"consequence": "舰队位置已经更新，原区域不再保留该舰队。" if success else "舰队仍停留在原区域，行动资源与地图状态均未改变。",
		"suggested_action": "查看目标区域状态并继续下一项行动。" if success else "选择与当前区域直接相连且允许舰队进入的公开区域。",
		"focus_target": "fleet_board",
		"relevant_cost": "已支付1点行动力" if success else "未支付行动力",
		"relevant_requirement": "舰队必须沿公开航线移动到一个合法相邻区域。",
		"affected_entity_ids": ["fleet:7"],
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


func _is_pure_data(value: Variant, depth: int = 0) -> bool:
	if depth > 32:
		return false
	if value == null or value is bool or value is int or value is float or value is String or value is StringName:
		return true
	if value is Array:
		for item_variant in value:
			if not _is_pure_data(item_variant, depth + 1):
				return false
		return true
	if value is Dictionary:
		for key_variant in value.keys():
			if not (key_variant is String or key_variant is StringName) or not _is_pure_data(value[key_variant], depth + 1):
				return false
		return true
	return false


func _contains_private_token(value: Variant) -> bool:
	var serialized := var_to_str(value).to_lower()
	for token in ["private_sentinel", "player_index", "cash", "hand", "discard", "slot", "owner", "ai_plan", "ai_score", "authorization", "secret"]:
		if serialized.contains(token):
			return true
	return false


func _test_dead_priority_bid_ui_entrypoints_retired() -> void:
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	var ai_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_runtime_controller.gd")
	var ai_registry_source := FileAccess.get_file_as_string("res://scripts/ai/ai_policy_resource_registry.gd")
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
	for retired_ai_symbol in [
		"func _auto_ai_auction_bids(",
		"func _ai_auction_policy_candidates_for_audit(",
		"func _ai_card_bid_budget(",
		"func _ai_priority_bid_for_budget(",
		"_set_card_bid_for_player",
		"_highest_card_resolution_bid",
		"winning_priority_bid_cents",
		"priority_bid_cents",
		"ai_bid_budget",
		"bid_budget",
	]:
		_expect(not ai_source.contains(retired_ai_symbol), "AI retires fixed-priority bid behavior and metadata %s" % retired_ai_symbol)
	_expect(not ai_registry_source.contains("auction_candidate_parity"), "AI policy registry no longer treats retired priority bidding as a runtime capability")
	var flow_source := FileAccess.get_file_as_string("res://scripts/runtime/table_player_action_application_flow_controller.gd")
	_expect(not main_source.contains('"card_group_ready"') and flow_source.contains("ACTION_CARD_GROUP_READY") and flow_source.contains("_receipt_for("), "scene-owned Action Flow returns the typed receipt for the real ready action outside Main")


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
