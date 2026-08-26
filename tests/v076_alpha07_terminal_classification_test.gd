extends SceneTree

const RuntimeOwner := preload("res://scripts/v075_runtime/v075_runtime_owner.gd")
const CombatOwner := preload("res://scripts/v075/runtime/v075_combat_runtime_owner.gd")
const FIXED_SEED := 900626424

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node.new()
	root.add_child(host)
	var runtime := RuntimeOwner.new()
	var combat := CombatOwner.new()
	host.add_child(runtime)
	host.add_child(combat)
	var bound := runtime.bind_combat_owner(combat)
	_expect(bool(bound.get("accepted", false)), "terminal classification reuses the existing combat owner binding")
	var started := runtime.start_new_game(
		4,
		FIXED_SEED,
		true,
		true,
		{
			"map_seed": FIXED_SEED,
			"region_count": 16,
			"geography_complexity": "STANDARD",
			"land_ocean_profile": "BALANCED",
		}
	)
	_expect(bool(started.get("accepted", false)), "terminal classification starts a natural four-seat game")
	if not bool(started.get("accepted", false)):
		_finish(host)
		return
	var settled := runtime.run_accelerated_until_settled(8000)
	var debug := runtime.debug_snapshot() as Dictionary
	var phase := str(debug.get("phase", ""))
	var progress := int(debug.get("public_progress_points", -1))
	var target := int(debug.get("public_progress_target", -1))
	var final_settlement_count := int(debug.get("final_settlement_count", 0))
	var final_presentation_count := int(debug.get("final_settlement_presentation_count", 0))
	var final_public_log_count := int(debug.get("final_settlement_public_log_count", 0))
	var runtime_errors := int(debug.get("runtime_error_count", 0))
	var normal_terminal := (
		bool(settled.get("accepted", false))
		and phase == "settled"
		and progress >= target
		and final_settlement_count == 1
		and final_presentation_count == 1
		and final_public_log_count == 1
		and runtime_errors == 0
	)
	print("V076_NATURAL_TERMINAL_CLASSIFICATION|classification=%s|phase=%s|progress=%d|target=%d|final_settlement=%d|presentation=%d|public_log=%d|runtime_errors=%d" % [
		"NORMAL_TERMINAL" if normal_terminal else "LOOP_BLOCKER",
		phase,
		progress,
		target,
		final_settlement_count,
		final_presentation_count,
		final_public_log_count,
		runtime_errors,
	])
	_expect(normal_terminal, "natural seed terminal is a normal Victory/FinalSettlement, not a track-loop blocker")
	if normal_terminal:
		var source_instance_id := ""
		var core := runtime.get("_track_core") as RefCounted
		var envelope := core.call("core_authority_v1") as Dictionary if core != null else {}
		var authority := envelope.get("authority_state", {}) as Dictionary
		var track := authority.get("track_state", {}) as Dictionary
		for item_variant in track.get("items", []) as Array:
			if item_variant is Dictionary:
				source_instance_id = str((item_variant as Dictionary).get("instance_id", ""))
				if not source_instance_id.is_empty():
					break
		_expect(not source_instance_id.is_empty(), "normal terminal retains a real shared-track source for rejection characterization")
		if not source_instance_id.is_empty():
			var rejected := runtime.acquire_track_item("player.local", source_instance_id)
			_expect(
				not bool(rejected.get("accepted", false))
				and str(rejected.get("reason_code", "")) == "track_acquisition_outside_submission",
				"post-Victory track acquire is rejected with the exact terminal-phase reason"
			)
			print("V076_POST_VICTORY_TRACK_ACQUIRE|accepted=%s|reason_code=%s|phase=%s" % [
				str(bool(rejected.get("accepted", false))),
				str(rejected.get("reason_code", "")),
				phase,
			])
	_finish(host)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish(host: Node) -> void:
	if host != null and is_instance_valid(host):
		host.queue_free()
		await process_frame
		await process_frame
	print("V076_ALPHA07_TERMINAL_CLASSIFICATION|status=%s|passed=%d|total=%d|failures=%s" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks - _failures.size(),
		_checks,
		JSON.stringify(_failures),
	])
	quit(0 if _failures.is_empty() else 1)
