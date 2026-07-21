@tool
extends Node

var checks := 0
var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var coordinator_scene := load("res://scenes/runtime/GameRuntimeCoordinator.tscn") as PackedScene
	_check(coordinator_scene != null, "production coordinator scene loads")
	var coordinator := coordinator_scene.instantiate()
	add_child(coordinator)
	await get_tree().process_frame
	var monster := coordinator.find_child("MonsterRuntimeController", true, false) as MonsterRuntimeController
	var pipeline := coordinator.find_child("RuntimeCommandPipeline", true, false) as RuntimeCommandPipeline
	_check(monster != null, "production coordinator composes MonsterRuntimeController")
	_check(pipeline != null and bool(pipeline.debug_snapshot().get("monster_action_ready", false)), "production command pipeline has monster action sink")
	_check(monster != null and monster.has_method("tick_wager_decisions_realtime") and monster.has_method("tick_battle_lifecycles"), "monster owner exposes separate decision and battle tick APIs")
	_check(monster != null and bool(monster.configure_battle_lifecycle_v06({"wager_seconds": 15.0, "battle_limit_seconds": 60.0}).get("configured", false)), "battle lifecycle accepts 15s/60s rules")
	var source := FileAccess.get_file_as_string("res://scripts/runtime/monster_runtime_controller.gd")
	_check(source.contains("dispatch_autonomous_action_command") and source.contains("opening_attack_applied"), "opening battle strike is bound to typed command authority")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	_check(not main_source.contains("_update_monster_wagers") and not main_source.contains("tick_wagers"), "main no longer owns wager ticking")
	var policy_source := FileAccess.get_file_as_string("res://scripts/runtime/monster_battle_lifecycle_policy_v06.gd")
	_check(policy_source.contains("PHASE_DECISION") and policy_source.contains("PHASE_BATTLE") and policy_source.contains("PHASE_SETTLING"), "battle lifecycle policy declares decision, battle, and settling phases")
	print("MONSTER_BATTLE_LIFECYCLE_OWNER_BENCH status=%s checks=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	if not failures.is_empty():
		push_error("\n- ".join(failures))
	var hold_seconds := 0.1 if DisplayServer.get_name() == "headless" else 5.0
	await get_tree().create_timer(hold_seconds).timeout
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: %s" % message)
		return
	failures.append(message)
	push_error("FAIL: %s" % message)
