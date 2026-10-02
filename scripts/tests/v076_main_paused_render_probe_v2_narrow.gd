extends SceneTree
# E-only Root-run diagnostic, ordinary Main and real official genesis.
# Normal processing remains enabled. No pixels/full diagnostics inside timed windows.
const MainScene := preload("res://scenes/main.tscn")
const SOURCE_SHA := {
  "res://scenes/main.tscn": "E11C35A360997145D54830558BC7280E638B244767C4F4092DA002D493AF9FD3",
  "res://scripts/v075_runtime/v075_application_bootstrap.gd": "0CF0A6705ED2B8BEAB55AE8A4B12448F42EE77385FA96030926543B71F07A40A",
  "res://scripts/v075_runtime/v075_application_flow.gd": "BC17648D802758F9AA89E1BC1803C68A419633ACC9EFC099DFAC8576300E346A",
  "res://scripts/v075_runtime/v075_runtime_owner.gd": "60D9EFA04654CD48E1B962F5FE9FA4D5EBDD6697F63CAD8927162977E31598DE",
  "res://scripts/ui/v075/v075_sample_game_screen.gd": "0780F4C68EE9E836F0919D5E9DCA0012824AAEA9EF6A4B72ACBCCC6A326D7B18",
  "res://scripts/ui/v074/v074_sample_game_screen.gd": "9F30043E9CB5DD0CECEEB7366E60EEF925216B0F863FC9A97C13B65F3AA4EB5A",
  "res://scripts/ui/v073/v073_sample_game_screen.gd": "07230FF3671037BF759E3F72FF91C62138CA7A4B4935383B86474D694C3CD918",
  "res://scripts/ui/bottom_countdown_bar.gd": "5D3BD505C2BD2690302F9F17149B7CE68F71D9AA0F6E3757C19E12F3C967CF57",
  "res://scripts/presentation/v076_presentation_animation_director.gd": "12A70D31E5C65704393BC211C3AAE2594CAAAC900C441102B1FD0D205637183D"
}
var checks: int = 0
var failures: Array[String] = []
var main: Node
var flow: Node
var owner: Node
var kernel: Node
var screen: Node
func _init() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
func official_intent(kind: String, parameters: Dictionary = {}) -> Dictionary:
	return flow.call("submit_intent", flow.call("issue_intent", kind, parameters)) as Dictionary
func run() -> void:
	for path: String in SOURCE_SHA:
		check(FileAccess.get_sha256(path).to_upper() == str(SOURCE_SHA[path]), "exact current production source: "+path)
	if not failures.is_empty():
		await finish()
		return
	main = MainScene.instantiate()
	root.add_child(main)
	for startup_frame: int in range(4):
		await process_frame
	flow = main.get_node("V075RuntimeComposition")
	owner = flow.get_node("V075RuntimeOwner")
	kernel = flow.get_node("V076DeterministicKernel")
	screen = main.get_node("V075GameScreen")
	check(flow.process_mode != Node.PROCESS_MODE_DISABLED and flow.is_processing(), "ordinary Main Flow process remains enabled")
	var started: Dictionary = official_intent("new_game.start", {"player_count": 8, "seed": 900626424, "map_seed": 900626424, "region_count": 16, "geography_complexity": "STANDARD", "land_ocean_profile": "BALANCED"})
	check(started.get("accepted") == true, "official real eight-seat new game accepted")
	if started.get("accepted") != true:
		await finish()
		return
	# Initial menu already holds pause. Preserve an explicit user pause before
	# any yield or legitimate teaching/menu gate release can allow a rule Tick.
	check(official_intent("ui.pacing.set", {"multiplier": 0}).get("accepted") == true, "official user pause while initial menu is still held")
	for coach_frame: int in range(4):
		await process_frame
	for skip_node: Node in main.find_children("CoachSkipAll", "Button", true, false):
		var skip_button: Button = skip_node as Button
		if skip_button != null and skip_button.is_visible_in_tree() and not skip_button.disabled:
			skip_button.emit_signal("pressed")
	# Reapply the desired pause synchronously after teaching release, before yield.
	check(official_intent("ui.pacing.set", {"multiplier": 0}).get("accepted") == true, "official pause immediately after CoachSkipAll release")
	for coach_fence: int in range(6):
		await process_frame
	check(not bool(screen.get("_coach_pacing_gate_active")), "official CoachSkipAll teaching pause gate released")
	var menu: Node = main.get_node_or_null("CommercialMenuLifecycleApplicationFlowController")
	check(menu != null and menu.has_method("close_to_table"), "real initial commercial menu lifecycle")
	if menu != null and menu.has_method("close_to_table"):
		check(bool(menu.call("close_to_table")), "official close initial menu to visible table")
	# Both are official supported commands, synchronous in this same callback.
	# No await/process call intervenes, so 1x does not advance a hidden rule Tick.
	check(official_intent("ui.pacing.set", {"multiplier": 1}).get("accepted") == true, "official 1x selection accepted")
	check(official_intent("ui.pacing.set", {"multiplier": 0}).get("accepted") == true, "official pause selection accepted before any yield")
	for pause_fence: int in range(4):
		await process_frame
	check(int(flow.get("_effective_playtest_pace_multiplier")) == 0, "effective user pause after menu/teaching release")
	# Menu/teaching frames can legitimately consume earlier production Ticks.
	# Only a complete, naturally drained and now stable paused boundary is needed.
	var drained: bool = await await_paused_complete_boundary(30.0)
	check(drained, "normal engine naturally drains pending ACK and publication FIFO before sample")
	check(int(kernel.call("current_tick")) >= 0 and int(owner.get("_clock_msec")) >= 0, "actual stable production Tick and clock are nonnegative")
	check(bool(owner.get("_v076_world_time_enabled")), "production Kernel remains sole world clock")
	if not failures.is_empty():
		await finish()
		return
	print("V076_MAIN_IDLE_BINDING|viewport=%s|max_fps=%d|physics_ticks_per_second=%d|pending_enabled=%s|worker_enabled=%s|default_processing=true|pixels=0|perframe_fulldebug=0|fixture_revision=2_narrow" % [str(root.size), Engine.max_fps, Engine.physics_ticks_per_second, str(flow.get("_v076_ai_tick_pending_enabled")), str(flow.get("_v076_map_worker_candidate_enabled"))])
	await measure_pause(2.0, "pause_2sec")
	if failures.is_empty():
		await measure_pause(5.0, "pause_5sec")
	await finish()
func pause_status() -> Dictionary:
	return {"pending": flow.call("pending_submission_tick_snapshot") as Dictionary,
		"publication": flow.call("projection_publication_snapshot") as Dictionary,
		"elapsed": flow.call("retained_elapsed_snapshot") as Dictionary,
		"tick": int(kernel.call("current_tick")), "clock_msec": int(owner.get("_clock_msec")),
		"effective_pace": int(flow.get("_effective_playtest_pace_multiplier")),
		"phase": str(owner.get("_phase"))}
func retained_elapsed_valid(elapsed: Dictionary) -> bool:
	for key: String in ["pending_elapsed_us", "decision_held_elapsed_us", "gated_pending_elapsed_us"]:
		if typeof(elapsed.get(key)) != TYPE_INT or int(elapsed[key]) < 0:
			return false
	return true
func transport_quiet(status: Dictionary) -> bool:
	var pending: Dictionary = status.get("pending", {}) as Dictionary
	var publication: Dictionary = status.get("publication", {}) as Dictionary
	return pending.get("consumer_pending") == false and str(pending.get("fault_reason", "")).is_empty() and int(pending.get("buffered_input_count", -1)) == 0 and publication.get("pending") == false and not bool(publication.get("capture_active", true)) and int(publication.get("pending_event_count", -1)) == 0 and int(publication.get("barrier_retained_elapsed_us", -1)) == 0 and str(publication.get("fault_reason", "")).is_empty()
func await_paused_complete_boundary(seconds: float) -> bool:
	var started_usec: int = Time.get_ticks_usec()
	var deadline_usec: int = started_usec + int(seconds*1000000.0)
	var initial: Dictionary = pause_status()
	var stable_frames: int = 0
	var previous: PackedByteArray = PackedByteArray()
	while Time.get_ticks_usec() < deadline_usec:
		var status: Dictionary = pause_status()
		var pending: Dictionary = status.get("pending", {}) as Dictionary
		var publication: Dictionary = status.get("publication", {}) as Dictionary
		if not str(pending.get("fault_reason", "")).is_empty() or not str(publication.get("fault_reason", "")).is_empty():
			check(false, "paused ACK/FIFO drain encountered consumer/publication fault")
			print("V076_MAIN_PAUSED_DRAIN|status=FAULT|initial=%s|final=%s" % [JSON.stringify(initial), JSON.stringify(status)])
			return false
		if int(status.get("effective_pace", -1)) != 0:
			# A teaching/menu release can restore pace. Reapply desired user pause;
			# never invoke a manual Tick, resume for debt catch-up, or clear elapsed.
			var paused: Dictionary = official_intent("ui.pacing.set", {"multiplier": 0})
			check(paused.get("accepted") == true, "official desired pause preserved during boundary drain")
			if paused.get("accepted") != true:
				return false
			status = pause_status()
		var elapsed: Dictionary = status.get("elapsed", {}) as Dictionary
		var stable_state: PackedByteArray = var_to_bytes({"tick": status.get("tick"), "clock_msec": status.get("clock_msec"), "elapsed": elapsed})
		if transport_quiet(status) and int(status.get("effective_pace", -1)) == 0 and str(status.get("phase", "")) == "submission" and retained_elapsed_valid(elapsed):
			stable_frames = stable_frames + 1 if stable_state == previous else 0
			if stable_frames >= 3:
				print("V076_MAIN_PAUSED_DRAIN|status=READY|wall_usec=%d|retained_elapsed_preserved=true|debt_catchup_claim=false|initial=%s|final=%s" % [Time.get_ticks_usec()-started_usec, JSON.stringify(initial), JSON.stringify(status)])
				return true
		else:
			stable_frames = 0
		previous = stable_state
		await process_frame
	check(false, "30-second normal-engine ACK/FIFO boundary deadline")
	print("V076_MAIN_PAUSED_DRAIN|status=TIMEOUT|wall_usec=%d|initial=%s|final=%s" % [Time.get_ticks_usec()-started_usec, JSON.stringify(initial), JSON.stringify(pause_status())])
	return false
func component_guard_ok(guard: Dictionary) -> bool:
	var hashes: Variant = guard.get("component_hashes")
	var missing: Variant = guard.get("missing_components")
	return guard.get("valid") == true and hashes is Dictionary and (hashes as Dictionary).size() == 7 and missing is Array and (missing as Array).is_empty()
func numeric_delta(before: Dictionary, after: Dictionary) -> Dictionary:
	var rows: Dictionary = {}
	for key: Variant in after:
		if not (after[key] is Dictionary):
			continue
		var current: Dictionary = after[key] as Dictionary
		var prior: Dictionary = before.get(key, {}) as Dictionary
		rows[key] = {"count": int(current.get("count", 0))-int(prior.get("count", 0)), "total_usec": int(current.get("total_usec", 0))-int(prior.get("total_usec", 0)), "last_usec": int(current.get("last_usec", 0)), "max_usec": int(current.get("max_usec", 0))}
	return rows
func summary(samples: Array[float]) -> Dictionary:
	if samples.is_empty():
		return {"count": 0}
	var ordered: Array[float] = samples.duplicate()
	ordered.sort()
	var total: float = 0.0
	for sample: float in samples:
		total += sample
	return {"count": samples.size(), "mean_msec": total/float(samples.size()), "p95_msec": ordered[clampi(int(ceil(float(ordered.size())*0.95))-1, 0, ordered.size()-1)], "max_msec": ordered[ordered.size()-1], "total_msec": total}
func measure_pause(seconds: float, label: String) -> void:
	var elapsed_before: Dictionary = flow.call("retained_elapsed_snapshot") as Dictionary
	check(retained_elapsed_valid(elapsed_before), label+": typed retained earned-time ledger before sample")
	var before_pending: Dictionary = flow.call("pending_submission_tick_snapshot") as Dictionary
	var before_publication: Dictionary = flow.call("projection_publication_snapshot") as Dictionary
	check(before_pending.get("consumer_pending") == false and str(before_pending.get("fault_reason", "")).is_empty() and int(before_pending.get("buffered_input_count", -1)) == 0, label+": complete consumer and empty input FIFO")
	check(before_publication.get("pending") == false and str(before_publication.get("fault_reason", "")).is_empty(), label+": published complete boundary")
	var guard_before: Dictionary = flow.call("presentation_authority_guard_snapshot") as Dictionary
	check(component_guard_ok(guard_before), label+": all seven authority witnesses valid before sample")
	var saved_before: Dictionary = kernel.call("capture_snapshot") as Dictionary
	check(saved_before.get("accepted") == true and saved_before.get("snapshot") is Dictionary, label+": complete Kernel snapshot before sample")
	if not failures.is_empty():
		return
	var tick_before: int = int(kernel.call("current_tick"))
	var clock_before: int = int(owner.get("_clock_msec"))
	# The heavy existing guards above and both warm-up fences are outside time.
	# No scene process_mode, animation, renderer, camera, rules or node changes.
	for guard_fence: int in range(2):
		await process_frame
	var flow_before: Dictionary = flow.call("combat_frame_performance_snapshot") as Dictionary
	var screen_before: Dictionary = (screen.call("v076_projection_section_performance_snapshot") as Dictionary).get("sections", {}) as Dictionary
	var process_before: int = Engine.get_process_frames()
	var physics_before: int = Engine.get_physics_frames()
	var drawn_before: int = Engine.get_frames_drawn()
	var screen_frames_before: int = int(screen.get("_runtime_frame_count"))
	var frame_msec: Array[float] = []
	var engine_process_msec: Array[float] = []
	var engine_physics_msec: Array[float] = []
	var started_usec: int = Time.get_ticks_usec()
	var previous_usec: int = started_usec
	var deadline_usec: int = started_usec + int(seconds*1000000.0)
	while Time.get_ticks_usec() < deadline_usec:
		await process_frame
		var current_usec: int = Time.get_ticks_usec()
		frame_msec.append(float(current_usec-previous_usec)/1000.0)
		previous_usec = current_usec
		# Fixed primitive Engine monitors only; no world/UI snapshots or pixels.
		engine_process_msec.append(float(Performance.get_monitor(Performance.TIME_PROCESS))*1000.0)
		engine_physics_msec.append(float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))*1000.0)
	var elapsed_usec: int = Time.get_ticks_usec()-started_usec
	var process_delta: int = Engine.get_process_frames()-process_before
	var physics_delta: int = Engine.get_physics_frames()-physics_before
	var drawn_delta: int = Engine.get_frames_drawn()-drawn_before
	var screen_frames_delta: int = int(screen.get("_runtime_frame_count"))-screen_frames_before
	# Stop the timed window before fixed-counter reads and authority witnesses.
	var flow_after: Dictionary = flow.call("combat_frame_performance_snapshot") as Dictionary
	var screen_after: Dictionary = (screen.call("v076_projection_section_performance_snapshot") as Dictionary).get("sections", {}) as Dictionary
	var guard_after: Dictionary = flow.call("presentation_authority_guard_snapshot") as Dictionary
	var saved_after: Dictionary = kernel.call("capture_snapshot") as Dictionary
	var elapsed_after: Dictionary = flow.call("retained_elapsed_snapshot") as Dictionary
	check(retained_elapsed_valid(elapsed_after) and var_to_bytes(elapsed_before) == var_to_bytes(elapsed_after), label+": typed retained debt unchanged; no catch-up or silent discard")
	var after_pending: Dictionary = flow.call("pending_submission_tick_snapshot") as Dictionary
	var after_publication: Dictionary = flow.call("projection_publication_snapshot") as Dictionary
	check(component_guard_ok(guard_after), label+": all seven authority witnesses valid after sample")
	check(var_to_bytes(guard_before) == var_to_bytes(guard_after), label+": exact typed full seven-component authority guard unchanged")
	check(saved_after.get("accepted") == true and var_to_bytes(saved_before.get("snapshot")) == var_to_bytes(saved_after.get("snapshot")), label+": exact complete typed Kernel snapshot unchanged")
	check(int(kernel.call("current_tick")) == tick_before and int(owner.get("_clock_msec")) == clock_before, label+": production Tick and authoritative clock unchanged")
	check(int(flow.get("_effective_playtest_pace_multiplier")) == 0 and str(owner.get("_phase")) == "submission", label+": ordinary table remains paused submission")
	check(after_pending.get("consumer_pending") == false and str(after_pending.get("fault_reason", "")).is_empty() and int(after_pending.get("buffered_input_count", -1)) == 0 and after_publication.get("pending") == false, label+": no unseen authority/publication/input work")
	check(elapsed_usec >= int(seconds*1000000.0) and process_delta > 0 and physics_delta > 0 and drawn_delta > 0 and screen_frames_delta > 0, label+": actual process/physics/render/MainScreen frames recorded")
	print("V076_MAIN_PAUSED_RENDER_SAMPLE|label=%s|seconds_requested=%.1f|wall_usec=%d|process_frames=%d|physics_frames=%d|drawn_frames=%d|screen_frames=%d|drawn_fps=%.3f|tick_before=%d|tick_after=%d|clock_before=%d|clock_after=%d|frame_intervals=%s|engine_process_monitor=%s|engine_physics_monitor=%s|flow_timing_delta=%s|screen_timing_delta=%s|authority_equal=%s|retained_elapsed_before=%s|retained_elapsed_after=%s|debt_catchup_claim=false" % [label, seconds, elapsed_usec, process_delta, physics_delta, drawn_delta, screen_frames_delta, float(drawn_delta)*1000000.0/float(maxi(1,elapsed_usec)), tick_before, int(kernel.call("current_tick")), clock_before, int(owner.get("_clock_msec")), JSON.stringify(summary(frame_msec)), JSON.stringify(summary(engine_process_msec)), JSON.stringify(summary(engine_physics_msec)), JSON.stringify(numeric_delta(flow_before, flow_after)), JSON.stringify(numeric_delta(screen_before, screen_after)), str(var_to_bytes(guard_before) == var_to_bytes(guard_after)), JSON.stringify(elapsed_before), JSON.stringify(elapsed_after)])
func finish() -> void:
	if is_instance_valid(main):
		main.queue_free()
		for cleanup_frame: int in range(4):
			await process_frame
	print("V076_MAIN_PAUSED_RENDER_PROBE|status=%s|checks=%d|failures=%s" % ["PASS" if failures.is_empty() else "FAIL", checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
