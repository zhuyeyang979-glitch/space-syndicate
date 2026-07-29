extends Node
class_name Alpha04CMonsterBankruptcySavePreflightBench

@export var auto_run_on_ready := true

var last_result: Dictionary = {}


func _ready() -> void:
	if auto_run_on_ready:
		await get_tree().process_frame
		last_result = run_bench()
		print("ALPHA04C_MONSTER_BANKRUPTCY_PREFLIGHT_BENCH|status=%s|checks=%d|failures=%d" % [
			"PASS" if bool(last_result.get("passed", false)) else "FAIL",
			int(last_result.get("checks", 0)),
			(last_result.get("failures", []) as Array).size(),
		])


func run_bench() -> Dictionary:
	var failures: Array[String] = []
	var checks := 0
	var monster := get_node_or_null("MonsterRuntimeController") as MonsterRuntimeController
	var estate := get_node_or_null("BankruptcyNeutralEstateRuntimeController") as BankruptcyNeutralEstateRuntimeController
	checks += 1
	if monster == null or estate == null:
		failures.append("production_owner_scene_missing")
		return {"passed": false, "checks": checks, "failures": failures}
	var monster_state := monster.to_save_data()
	var monster_before := monster.to_save_data()
	var monster_preflight := monster.preflight_save_data(monster_state)
	checks += 1
	if not bool(monster_preflight.get("accepted", false)) or monster_before != monster.to_save_data():
		failures.append("monster_valid_preflight_failed_or_mutated")
	var invalid_monster := monster_state.duplicate(true)
	invalid_monster["monster_timer"] = INF
	checks += 1
	if bool(monster.preflight_save_data(invalid_monster).get("accepted", true)) or monster_before != monster.to_save_data():
		failures.append("monster_invalid_preflight_failed_open_or_mutated")
	var estate_state := estate.to_save_data()
	var estate_before := estate.to_save_data()
	var estate_preflight := estate.preflight_save_data(estate_state)
	checks += 1
	if not bool(estate_preflight.get("accepted", false)) or estate_before != estate.to_save_data():
		failures.append("bankruptcy_valid_preflight_failed_or_mutated")
	var invalid_estate := estate_state.duplicate(true)
	invalid_estate["commodity_flow_retired_sequence"] = -1
	checks += 1
	if bool(estate.preflight_save_data(invalid_estate).get("accepted", true)) or estate_before != estate.to_save_data():
		failures.append("bankruptcy_invalid_preflight_failed_open_or_mutated")
	return {"passed": failures.is_empty(), "checks": checks, "failures": failures}
