extends SceneTree

const SCHEMA := preload("res://scripts/cards/v06/units/unit_card_runtime_schema_v06.gd")
const OWNER_SCRIPT := preload("res://scripts/cards/v06/units/unit_card_reference_owner_v06.gd")
const ADAPTER_SCRIPT := preload("res://scripts/cards/v06/units/monster_card_effect_adapter_v06.gd")
const FILTER := preload("res://scripts/cards/v06/units/unit_card_receipt_filter_v06.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_public_allowlist_and_recursive_sanitization()
	_verify_private_view_is_viewer_scoped()
	_verify_developer_view_preserves_diagnostics()
	_verify_failure_feedback_is_localized_without_machine_fields()
	_finish()


func _verify_public_allowlist_and_recursive_sanitization() -> void:
	var receipt := _committed_receipt()
	receipt["true_owner"] = "secret-owner-a"
	receipt["hidden_owner"] = {"actor_id": "secret-owner-a", "cash": 777}
	receipt["owner_truth"] = "secret-owner-a"
	receipt["ai_private"] = {"ai_plan": "AI-SECRET-PLAN"}
	receipt["raw_error"] = "RAW-SECRET-ERROR"
	receipt["public_fields"] = {
		"unit_public_id": "monster-unit-1",
		"unit_rank": 1,
		"target_public": {
			"region_id": "region-alpha",
			"owner_truth": "NESTED-OWNER-SECRET",
			"opponent_cash": 999,
		},
		"public_changes": [
			{"visible_change": "怪兽已出现", "opponent_hand": ["SECRET-CARD"]},
			{"safe_status": "已进入区域", "raw_owner_receipt": "RAW-OWNER-SECRET"},
		],
		"anonymous": true,
	}
	var public_receipt: Dictionary = FILTER.public_view(receipt)
	var scan: Dictionary = FILTER.public_leak_scan(public_receipt)
	var encoded := JSON.stringify(public_receipt)
	_expect(bool(scan.get("safe", false)) and int(scan.get("leak_count", -1)) == 0, "public receipt privacy scanner reports zero forbidden fields")
	_expect(not public_receipt.has("transaction_id") and not public_receipt.has("actor_id") and not public_receipt.has("card_instance_id"), "public receipt omits transaction, actor, and card-instance bindings")
	_expect(not public_receipt.has("reason_code") and not public_receipt.has("developer_fields") and not public_receipt.has("private_fields"), "public receipt omits machine and developer layers")
	_expect(not encoded.contains("secret-owner") and not encoded.contains("SECRET") and not encoded.contains("777") and not encoded.contains("999"), "recursive sanitizer removes hidden owner, opponent resources, AI plan, hand, and raw error values")
	_expect(str(public_receipt.get("effect_kind", "")) == "deploy_or_upgrade_monster" and str(public_receipt.get("action_kind", "")) == "deploy_or_upgrade_monster", "public receipt keeps the safe public effect family")
	_expect(str(public_receipt.get("unit_public_id", "")) == "monster-unit-1" and bool(public_receipt.get("anonymous", false)), "public receipt exposes only anonymous public unit identity")
	var target_public: Dictionary = public_receipt.get("target_public", {}) as Dictionary
	_expect(str(target_public.get("region_id", "")) == "region-alpha" and not target_public.has("owner_truth"), "public target retains region while removing ownership truth")


func _verify_private_view_is_viewer_scoped() -> void:
	var receipt := _committed_receipt()
	receipt["private_fields"] = {
		"bound_unit_uid": 41,
		"card_instance_id": "private-card-instance",
		"own_cash_after": 12,
		"own_hand_after": ["own-card"],
		"own_unit_state": {
			"rank": 2,
			"opponent_cash": 700,
			"rival_hand": ["rival-card"],
			"ai_plan": "ambush",
			"raw_error": "stack trace",
		},
	}
	var own_view: Dictionary = FILTER.private_view(receipt, "syndicate-a")
	var rival_view: Dictionary = FILTER.private_view(receipt, "syndicate-b")
	_expect(own_view.has("private") and not rival_view.has("private"), "private receipt fields are visible only to the matching actor")
	var own_private: Dictionary = own_view.get("private", {}) as Dictionary
	_expect(int(own_private.get("bound_unit_uid", 0)) == 41 and int(own_private.get("own_cash_after", -1)) == 12, "actor sees its own bound unit and post-action resources")
	var own_state: Dictionary = own_private.get("own_unit_state", {}) as Dictionary
	_expect(int(own_state.get("rank", 0)) == 2 and not own_state.has("opponent_cash") and not own_state.has("rival_hand") and not own_state.has("ai_plan"), "private sanitizer still removes opponent and AI-private data")
	_expect(int((FILTER.public_leak_scan(rival_view) as Dictionary).get("leak_count", -1)) == 0, "non-owner view remains a leak-free public receipt")


func _verify_developer_view_preserves_diagnostics() -> void:
	var receipt := _committed_receipt()
	receipt["developer_fields"] = {
		"raw_error": "diagnostic-only",
		"owner_truth": "syndicate-a",
		"owner_receipt": {"revision": 4},
	}
	var developer: Dictionary = FILTER.developer_view(receipt)
	_expect(str((developer.get("developer_fields", {}) as Dictionary).get("raw_error", "")) == "diagnostic-only", "developer view preserves raw diagnostics")
	_expect(str(developer.get("transaction_id", "")) == str(receipt.get("transaction_id", "")), "developer view preserves transaction bindings")
	developer["transaction_id"] = "changed-copy"
	_expect(str(receipt.get("transaction_id", "")) != "changed-copy", "developer view is a deep copy, not mutable owner truth")


func _verify_failure_feedback_is_localized_without_machine_fields() -> void:
	var intent := _intent("privacy-failure")
	var failed := SCHEMA.failure_receipt(
		intent,
		"monster_owner_atomic_contract_missing",
		"该怪兽效果尚未安全接入。",
		"请选择其他已可用的卡牌。",
		{"raw_error": "method missing", "card_id": "internal.card"}
	)
	var public_failure: Dictionary = FILTER.public_view(failed)
	var feedback: Dictionary = public_failure.get("player_feedback", {}) as Dictionary
	var encoded := JSON.stringify(public_failure).to_lower()
	_expect(str(feedback.get("reason", "")) == "该怪兽效果尚未安全接入。" and str(feedback.get("next_step", "")) == "请选择其他已可用的卡牌。", "player failure view says both why and what to do next")
	_expect(not public_failure.has("reason_code") and not encoded.contains("internal.card") and not encoded.contains("method missing"), "failure view does not expose internal ID, reason code, or raw error")
	_expect(int((FILTER.public_leak_scan(public_failure) as Dictionary).get("leak_count", -1)) == 0, "localized failure receipt has zero public privacy leaks")


func _committed_receipt() -> Dictionary:
	var owner = OWNER_SCRIPT.new()
	owner.configure("monster")
	var adapter = ADAPTER_SCRIPT.new()
	adapter.configure(owner)
	var intent := _intent("privacy-commit")
	var prepared: Dictionary = adapter.prepare_effect(intent)
	return adapter.commit_effect(prepared)


func _intent(transaction_id: String) -> Dictionary:
	return SCHEMA.make_intent(
		transaction_id,
		"syndicate-a",
		"monster.private.test",
		"monster-private-instance",
		"deploy_or_upgrade_monster",
		"deploy_or_upgrade_monster",
		0,
		{"valid": true, "region_id": "region-alpha"},
		{"monster_family_id": "monster.test", "card_rank": 1, "same_name_upgrade_extend_seconds": 60, "public_rule_inputs": {"unit_control_limit": 1}},
		{"anonymous_play": true, "hidden_owner": true}
	)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	print("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("UNIT_CARD_PRIVACY_V06_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	print("UNIT_CARD_PRIVACY_V06_TEST|status=FAIL|checks=%d|failures=%d|details=%s" % [_checks, _failures.size(), JSON.stringify(_failures)])
	quit(1)
