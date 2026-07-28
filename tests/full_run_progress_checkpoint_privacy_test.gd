extends SceneTree

const DriverScript := preload("res://scripts/tools/full_run_quality_driver.gd")
const FORBIDDEN_KEYS := [
	"cash",
	"cash_cents",
	"hand",
	"discard",
	"owner",
	"owner_id",
	"owner_player_index",
	"hidden_owner",
	"ai_candidate",
	"ai_selected_action",
	"ai_plan",
	"private_target",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var source := {
		"run_id": "seed-00 PRIVATE_SENTINEL",
		"step": 30,
		"world_time": 42.5,
		"facilities": 3,
		"production": {"capacity_units_per_minute": 12, "settled_units": 5, "owner": "PRIVATE_SENTINEL"},
		"demand": {"capacity_units_per_minute": 9, "settled_units": 5, "cash": 999999},
		"transport": {"settled_units": 4, "ai_plan": "PRIVATE_SENTINEL"},
		"waste": {"cumulative_units": 1.25, "owner_id": "PRIVATE_SENTINEL"},
		"sale_receipts": 5,
		"top_k_gdp": 108,
		"victory_state": "qualification",
		"last_successful_action": "district_supply_purchase_card",
		"steps_since_progress": 2,
		"rng_draw_count": 573,
		"hand": ["PRIVATE_SENTINEL"],
		"ai_candidate": "PRIVATE_SENTINEL",
	}
	var first := DriverScript.progress_checkpoint_snapshot(source)
	var second := DriverScript.progress_checkpoint_snapshot(source)
	var keys := first.keys()
	keys.sort()
	var expected_keys := DriverScript.PROGRESS_CHECKPOINT_PUBLIC_KEYS.duplicate()
	expected_keys.sort()
	_expect(keys == expected_keys, "the 30-step checkpoint exposes only its explicit public allowlist")
	_expect(first == second and JSON.stringify(first).sha256_text() == JSON.stringify(second).sha256_text(), "identical aggregate inputs produce one stable deterministic checkpoint")
	_expect(_pure_data(first), "the checkpoint contains no Node, Object, Resource, or Callable")
	_expect(not _contains_forbidden_key(first), "the checkpoint contains no cash, hand, owner, private target, or AI decision key")
	_expect(not JSON.stringify(first).contains("PRIVATE_SENTINEL"), "malicious private values cannot survive the allowlist projection")
	_expect((first.get("production", {}) as Dictionary).keys().size() == 2 and (first.get("demand", {}) as Dictionary).keys().size() == 2, "production and demand expose only aggregate capacity and settled units")
	_expect((first.get("transport", {}) as Dictionary).keys() == ["settled_units"] and (first.get("waste", {}) as Dictionary).keys() == ["cumulative_units"], "transport and waste expose only aggregate public totals")
	_expect(int(first.get("step", 0)) == 30 and int(first.get("rng_draw_count", 0)) == 573 and str(first.get("victory_state", "")) == "qualification", "step, RNG draw count, and public Victory state remain observable")
	_finish()


func _pure_data(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME:
			return true
		TYPE_ARRAY:
			for item in value as Array:
				if not _pure_data(item):
					return false
			return true
		TYPE_DICTIONARY:
			for key in (value as Dictionary).keys():
				if not _pure_data(key) or not _pure_data((value as Dictionary).get(key)):
					return false
			return true
	return false


func _contains_forbidden_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if FORBIDDEN_KEYS.has(str(key_variant).to_lower()) or _contains_forbidden_key((value as Dictionary).get(key_variant)):
				return true
	elif value is Array:
		for item in value as Array:
			if _contains_forbidden_key(item):
				return true
	return false


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	for failure in _failures:
		push_error("FULL_RUN_PROGRESS_CHECKPOINT_PRIVACY: %s" % failure)
	print("FULL_RUN_PROGRESS_CHECKPOINT_PRIVACY|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	quit(_failures.size())
