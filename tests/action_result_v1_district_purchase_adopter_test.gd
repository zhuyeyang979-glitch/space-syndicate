extends SceneTree

const ACTION_RESULT_SCRIPT := preload("res://scripts/runtime/action_result_v1.gd")
const PRESENTATION_SERVICE_SCRIPT := preload("res://scripts/runtime/action_result_presentation_service.gd")
const PRIVATE_SENTINELS := [
	"ARV1_RIVAL_CASH_SENTINEL",
	"ARV1_RIVAL_HAND_SENTINEL",
	"ARV1_HIDDEN_OWNER_SENTINEL",
	"ARV1_AI_WEIGHT_SENTINEL",
	"ARV1_PRIVATE_QUOTE_SENTINEL",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_projection_contract()
	_test_main_helper_retirement()
	_finish()


func _test_projection_contract() -> void:
	var service := PRESENTATION_SERVICE_SCRIPT.new() as Node
	service.call("configure", {})
	var schema: Array = service.call("public_field_schema")
	var success: Dictionary = service.call("compose", {
		"schema_version": 1,
		"action_id": "district_card_purchase",
		"action_family": "card_market",
		"public_receipt": {"event_code": "anonymous_purchase_committed", "district_index": 7, "price_cash": 202},
	})
	_expect(bool(success.get("success", false)) and str(success.get("failure_code", "")) == "", "public anonymous-purchase receipt projects one success ActionResult")
	_expect(_same_string_set(success.keys(), schema), "purchase success exposes only the strict ActionResult v1 field schema")
	_expect(success.get("affected_entity_ids", []) == ["district:7"] and str(success.get("focus_target", "")) == "district_supply", "purchase success focuses the public source district without actor identity")
	_expect(str(success.get("relevant_cost", "")) == "¥202" and str(success.get("consequence", "")).contains("支付¥202"), "purchase success explains the public locked price and committed consequence")
	_expect(_required_copy_present(success) and not _contains_private_value(success), "purchase success contains complete decision copy and no private fact")

	var failure_cases := [
		["v06_card_runtime_not_ready", "purchase_market_unavailable"],
		["market_listing_changed", "purchase_listing_changed"],
		["source_item_unavailable", "purchase_source_unavailable"],
		["market_quote_binding_mismatch", "purchase_terms_unavailable"],
		["cash_insufficient", "purchase_funds_unavailable"],
		["inventory_commit_failed", "purchase_inventory_unavailable"],
		["state_port_commit_failed", "purchase_conflict"],
	]
	for case_variant in failure_cases:
		var case: Array = case_variant as Array
		var failure: Dictionary = service.call("compose", {
			"schema_version": 1,
			"action_id": "district_card_purchase",
			"action_family": "card_market",
			"failure_code": str(case[0]),
		})
		_expect(not bool(failure.get("success", true)) and str(failure.get("failure_code", "")) == str(case[1]), "%s maps to stable public failure %s" % [case[0], case[1]])
		_expect(_same_string_set(failure.keys(), schema) and failure.get("affected_entity_ids", []) == [], "purchase failure keeps the strict schema and claims no committed entity")
		_expect(_required_copy_present(failure) and not _contains_private_value(failure), "purchase failure remains decision-complete and privacy-safe")

	for forbidden_patch in [
		{"cash": 999999},
		{"hand": ["ARV1_RIVAL_HAND_SENTINEL"]},
		{"owner": "ARV1_HIDDEN_OWNER_SENTINEL"},
		{"ai_weight": "ARV1_AI_WEIGHT_SENTINEL"},
		{"quote_id": "ARV1_PRIVATE_QUOTE_SENTINEL"},
		{"quote_fingerprint": "ARV1_PRIVATE_QUOTE_SENTINEL"},
	]:
		var unsafe := {
			"schema_version": 1,
			"action_id": "district_card_purchase",
			"action_family": "card_market",
			"failure_code": "market_listing_changed",
		}
		for key_variant in forbidden_patch.keys():
			unsafe[key_variant] = forbidden_patch[key_variant]
		var rejected: Dictionary = service.call("compose", unsafe)
		_expect(str(rejected.get("failure_code", "")) == "unsafe_source" and not _contains_private_value(rejected), "private purchase source fails closed without echoing private input")

	var overbroad_receipt: Dictionary = service.call("compose", {
		"schema_version": 1,
		"action_id": "district_card_purchase",
		"action_family": "card_market",
		"public_receipt": {
			"event_code": "anonymous_purchase_committed",
			"district_index": 7,
			"price_cash": 202,
			"card_id": "PRIVATE_CARD",
		},
	})
	_expect(str(overbroad_receipt.get("failure_code", "")) == "unsafe_source", "success projection rejects receipt fields beyond event code and public district")
	service.free()


func _test_main_helper_retirement() -> void:
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	_expect(not main_source.contains("func _purchase_v06_first_table_facility_card(") and not main_source.contains("_purchase_v06_first_table_facility_card("), "old Main facility-purchase helper has zero definitions and references")
	for retired_copy in [
		"城市设施牌市场已经刷新，请重新选择。",
		"已购买一张I级城市设施牌；现金¥-",
		"城市设施牌未购买：",
	]:
		_expect(not main_source.contains(retired_copy), "old ambiguous Main purchase copy is physically deleted: %s" % retired_copy)
	var buy_source := _function_source(main_source, "_buy_card_for_player_from_district")
	_expect(
		buy_source.contains("purchase_region_supply_card")
			and not main_source.contains("execute_v06_facility_purchase_action"),
		"Main dispatches every rack card through the single RegionSupply CardFlow purchase facade"
	)
	_expect(coordinator_source.contains("public_receipt") and coordinator_source.contains("anonymous_purchase_committed") and coordinator_source.contains("compose_action_result_v1(action_source)"), "Coordinator projects only the owner public receipt or failure code after atomic purchase")


func _required_copy_present(result: Dictionary) -> bool:
	for key in ["title", "explanation", "consequence", "suggested_action", "focus_target", "relevant_cost", "relevant_requirement"]:
		if str(result.get(key, "")).strip_edges().is_empty():
			return false
	return true


func _function_source(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start < 0:
		return ""
	var finish := source.find("\nfunc ", start + 5)
	if finish < 0:
		finish = source.length()
	return source.substr(start, finish - start)


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


func _contains_private_value(value: Variant) -> bool:
	var serialized := var_to_str(value)
	for sentinel in PRIVATE_SENTINELS:
		if serialized.contains(sentinel):
			return true
	for token in ["quote_id", "quote_fingerprint", "owner_player_index", "ai_weight"]:
		if serialized.to_lower().contains(token):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error("ACTION RESULT PURCHASE ADOPTER: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("ACTION_RESULT_V1_DISTRICT_PURCHASE_ADOPTER_TEST|status=PASS|checks=%d" % _checks)
		quit(0)
		return
	push_error("ActionResult district-purchase adopter failed:\n- %s" % "\n- ".join(_failures))
	quit(1)
