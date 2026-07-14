extends SceneTree

const FILTER := preload("res://scripts/cards/v06/interaction/anonymous_interaction_receipt_sanitizer_v06.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var source := {"transaction_id": "tx", "effect_kind": "player_hand_steal", "public_outcome": "resolved", "nested": {"true_owner": "A", "opponent_cash": 900, "opponent_hand": ["secret"], "ai_metadata": {"plan": "attack"}, "safe": "aftermath"}, "private_by_viewer": {"A": {"cash": 400, "hand": ["own-card"], "safe_note": "own evidence"}, "B": {"cash": 500}}, "developer_fields": {"owner_truth": "A"}}
	var public := FILTER.sanitize_public(source)
	var leaks := FILTER.scan_public_leaks(public)
	_expect(leaks.is_empty(), "public receipt privacy scan has zero leaks")
	_expect(str((public.get("nested", {}) as Dictionary).get("safe", "")) == "aftermath", "safe public aftermath remains")
	_expect(not public.has("private_by_viewer") and not public.has("developer_fields"), "public receipt removes private and developer layers")
	var private := FILTER.sanitize_private(source, "A")
	_expect(private.has("viewer_private") and str((private.get("viewer_private", {}) as Dictionary).get("safe_note", "")) == "own evidence", "private receipt includes only viewer-scoped payload")
	_expect(not (private.get("nested", {}) as Dictionary).has("opponent_cash") and not (private.get("nested", {}) as Dictionary).has("ai_metadata"), "private receipt still removes rival and AI secrets")
	var dev := FILTER.sanitize_developer(source)
	_expect(str((dev.get("developer_fields", {}) as Dictionary).get("owner_truth", "")) == "A", "developer receipt retains diagnostic truth")
	print("ANONYMOUS_INTERACTION_PRIVACY_V06_TEST|status=%s|checks=%d|failures=%d|public_leaks=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size(), leaks.size()])
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		print("FAIL: %s" % message)
