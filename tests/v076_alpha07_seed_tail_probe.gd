extends SceneTree

const RuntimeOwner := preload("res://scripts/v075_runtime/v075_runtime_owner.gd")
const CombatOwner := preload("res://scripts/v075/runtime/v075_combat_runtime_owner.gd")
const BASE_SEED := 900626424
const SAMPLE_COUNT := 24


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var seed_start := BASE_SEED
	var override := OS.get_environment("V076_SEED_START")
	if not override.is_empty() and override.is_valid_int():
		seed_start = override.to_int()
	var count := SAMPLE_COUNT
	var count_override := OS.get_environment("V076_SEED_COUNT")
	if not count_override.is_empty() and count_override.is_valid_int():
		count = maxi(1, count_override.to_int())
	for offset in range(count):
		var seed_value := seed_start + offset * 104729
		var host := Node.new()
		root.add_child(host)
		var runtime := RuntimeOwner.new()
		var combat := CombatOwner.new()
		host.add_child(runtime)
		host.add_child(combat)
		var bound := runtime.bind_combat_owner(combat)
		if not bool(bound.get("accepted", false)):
			print("V076_SEED_TAIL_ROW|seed=%d|bind=false" % seed_value)
			host.queue_free()
			await process_frame
			continue
		var started := runtime.start_new_game(
			4,
			seed_value,
			true,
			true,
			{
				"map_seed": seed_value,
				"region_count": 16,
				"geography_complexity": "STANDARD",
				"land_ocean_profile": "BALANCED",
			}
		)
		if not bool(started.get("accepted", false)):
			print("V076_SEED_TAIL_ROW|seed=%d|start=false|reason=%s" % [seed_value, str(started.get("reason_code", ""))])
			host.queue_free()
			await process_frame
			continue
		var initial_track := runtime.get("_track_core").call("core_authority_v1") as Dictionary
		var initial_state := (initial_track.get("authority_state", {}) as Dictionary).get("track_state", {}) as Dictionary
		var result := runtime.run_accelerated_until_settled(8000)
		var debug := runtime.debug_snapshot()
		var ai_rows := debug.get("ai_public_action_receipts", []) as Array
		print("V076_SEED_TAIL_ROW|seed=%d|accepted=%s|phase=%s|batch=%d|progress=%d|target=%d|ai_public=%d|capacity=%d|scroll=%d|reason=%s" % [
			seed_value,
			str(bool(result.get("accepted", false))),
			str(result.get("phase", "")),
			int(debug.get("batch_number", 0)),
			int(debug.get("public_progress_points", 0)),
			int(debug.get("public_progress_target", 0)),
			ai_rows.size(),
			int(initial_state.get("capacity", -1)),
			int(debug.get("track_scroll_sequence", -1)),
			str(result.get("reason_code", "")),
		])
		host.queue_free()
		await process_frame
	quit(0)
