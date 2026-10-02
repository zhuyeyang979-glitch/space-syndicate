extends SceneTree
# SourceRows same-source OFF/ON operation CPU sibling of frozen ActualMain33EB.
# Original source68993 input/ACK/receipt contract is retained via ActualMain33EB.
# OFF/ON use identical production pending ticks with real Kernel ACK and legal
# public human inputs after the seven AI. No authority/RNG/card/resource injection.
# Native leaf diagnostics read once outside operation timers; no per-frame debug.
const MainScene := preload("res://scenes/main.tscn")
const RECEIPT_CHANNELS := {
	"receipt_ready": "application", "owner_private_receipt_ready": "private",
	"deck_lifecycle_presentation_receipt_ready": "deck", "track_presentation_receipt_ready": "track",
	"public_resolution_ready": "resolution", "final_settlement_presented": "final",
	"runtime_fault_presented": "fault", "playtest_observation_ready": "observation",
}
var checks := 0
var failures: Array[String] = []
var report_path := ""
var capture_label := ""
func _init() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
func _copy(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value
func intent(flow: Node, kind: String, parameters: Dictionary = {}) -> Dictionary:
	return flow.call("submit_intent", flow.call("issue_intent", kind, parameters)) as Dictionary
func _observe(flow: Node) -> Array:
	var rows: Array = []
	for signal_name in RECEIPT_CHANNELS:
		var channel := str(RECEIPT_CHANNELS[signal_name])
		flow.connect(signal_name, func(row: Dictionary) -> void: rows.append({"channel": channel, "receipt": row.duplicate(true)}))
	return rows
func _final_receipts(rows: Array) -> Array:
	var official: Array = []
	for row in rows:
		var receipt: Dictionary = row["receipt"]
		if str(receipt.get("schema", "")) in ["V076BufferedApplicationInputV1", "V076BufferedInputCancellationV1"]:
			check(receipt.get("authority_committed") == false and not receipt.has("accepted"), "excluded transport remains explicitly unaccepted")
			continue
		official.append(row.duplicate(true))
	return official
func _binding_proof(flow: Node, owner: Node, kernel: Node, pending_enabled: bool) -> bool:
	var ok: bool = flow.get_script().resource_path == "res://scripts/v075_runtime/v075_application_flow.gd" \
		and owner.get_script().resource_path == "res://scripts/v075_runtime/v075_runtime_owner.gd" \
		and kernel.get_script() == preload("res://scripts/v076/simulation/v076_deterministic_kernel.gd") \
		and owner.get("_v076_projection_port") == flow and owner.get("_v076_time_kernel") == kernel \
		and owner.get_parent() == flow and kernel.get_parent() == flow \
		and bool(owner.get("_v076_world_time_enabled")) and int(kernel.call("current_tick")) == 0 \
		and bool(owner.call("can_v076_pend_submission_tick")) \
		and bool((flow.call("pending_submission_tick_snapshot") as Dictionary).get("candidate_enabled", false)) == pending_enabled
	check(ok, "authored script/scene identities, pristine world clock and constructed env eligibility")
	var connections := kernel.get_signal_connection_list("tick_committed")
	check(connections.size() == 1 and connections[0].get("callable") == Callable(flow, "_on_v076_tick_committed") and int(connections[0].get("flags", -1)) == 0, "one unique synchronous Flow consumer")
	return ok
func _capture(pending_enabled: bool, schedule_gap: int, profile_enabled: bool, label: String) -> Dictionary:
	capture_label = label
	check(_source_binding_proof(), label + " exact source matrix before fresh Main")
	var lane_source_before: Dictionary = _actual_source_hashes()
	OS.set_environment("V076_COMBAT_SOURCE_ROWS_EXPERIMENT", "1" if profile_enabled else "")
	OS.set_environment("SPACE_SYNDICATE_EXPERIMENTAL_AI_TICK_PENDING", "1" if pending_enabled else "")
	var main := MainScene.instantiate()
	var flow := main.get_node("V075RuntimeComposition")
	flow.process_mode = Node.PROCESS_MODE_DISABLED # Before _ready/process can run.
	var observed_outputs: Array = _observe_complete_flow_outputs(flow)
	root.add_child(main)
	for startup_frame in range(4):
		await process_frame
	var rows := _observe(flow)
	var started := intent(flow, "new_game.start", {"player_count": 8, "seed": 901626424,
		"map_seed": 900626424, "region_count": 16, "geography_complexity": "STANDARD", "land_ocean_profile": "BALANCED"})
	check(bool(started.get("accepted", false)), "eight-seat real Main genesis")
	if bool(started.get("accepted", false)):
		for coach_ready_frame in range(4):
			await process_frame
		var screen: Node = main.get_node("V075GameScreen")
		var skip_buttons: Array[Node] = main.find_children("CoachSkipAll", "Button", true, false)
		for skip_node: Node in skip_buttons:
			var skip_button: Button = skip_node as Button
			if skip_button.is_visible_in_tree() and not skip_button.disabled:
				skip_button.emit_signal("pressed")
		for coach_fence_frame in range(6):
			await process_frame
		check(not bool(screen.get("_coach_pacing_gate_active")), "official CoachSkipAll closes the teaching pause gate")
		var menu: Node = main.get_node_or_null("CommercialMenuLifecycleApplicationFlowController")
		check(menu != null and menu.has_method("close_to_table"), "authored initial menu lifecycle present")
		if menu != null and menu.has_method("close_to_table"):
			check(bool(menu.call("close_to_table")), "official initial main menu closed to active table")
		check(bool(intent(flow, "ui.pacing.set", {"multiplier": 1}).get("accepted", false)), "official 1x pacing after initial menu release")
		for unused in range(3):
			await process_frame
		check(int(flow.get("_effective_playtest_pace_multiplier")) == 1, "1x effective pace before manual first Tick")
		check(flow.process_mode == Node.PROCESS_MODE_DISABLED, "framework process remains disabled during fixture")
	var owner := flow.get_node("V075RuntimeOwner")
	var kernel := flow.get_node("V076DeterministicKernel")
	if not bool(started.get("accepted", false)) or not owner.has_method("can_v076_pend_submission_tick") or not _binding_proof(flow, owner, kernel, pending_enabled):
		main.queue_free()
		await process_frame
		return {}
	var snapshot: Dictionary = flow.call("local_snapshot")
	var selected: Dictionary = {}
	for option in snapshot.get("legal_actions", []) as Array:
		if option is Dictionary and str((option as Dictionary).get("action_domain", "facility")) == "facility":
			selected = option as Dictionary
			break
	check(not selected.is_empty(), "one official Starter legal binding")
	# Identical IDs in both schedules/reference. Only admission time differs.
	var queue_intent: Dictionary = flow.call("issue_intent", "card.queue", {"card_instance_id": str(selected.get("card_instance_id", "")), "target_slot_id": str(selected.get("target_slot_id", ""))})
	var lock_intent: Dictionary = flow.call("issue_intent", "submission.lock", {})
	var source_rows_before: Dictionary = _source_rows_world_snapshot(owner)
	var native_before: Dictionary = _all_native_profile(owner)
	var owner_before: Dictionary = (owner.get("_combat_projection_performance") as Dictionary).duplicate(true)
	var queue_profile_process_cpu_usec := 0
	var queue_profile_step_started := Time.get_ticks_usec()
	flow.call("_process", 0.05)
	queue_profile_process_cpu_usec += Time.get_ticks_usec() - queue_profile_step_started
	var tick: int = int(kernel.call("current_tick"))
	var clock: int = int(owner.get("_clock_msec"))
	check(tick == 1 and clock == 50, "exact first committed Tick/decision clock")
	var diagnostic: Dictionary = flow.call("pending_submission_tick_snapshot")
	check(bool(diagnostic.get("consumer_pending", false)) == pending_enabled, "explicit opt-in marker; default synchronous marker")
	if pending_enabled:
		check(int(diagnostic.get("pending_nonce", 0)) > 0, "live continuation nonce")
		check((owner.get("_queued_by_player") as Dictionary).get(owner.call("local_player_id"), []).is_empty(), "no test human command or early local authority write during timed seven AI")
		var steps := 0
		while bool((flow.call("pending_submission_tick_snapshot") as Dictionary).get("consumer_pending", false)) and steps < 2000:
			for unused in range(schedule_gap):
				await process_frame
			queue_profile_step_started = Time.get_ticks_usec()
			flow.call("_process", 0.0)
			queue_profile_process_cpu_usec += Time.get_ticks_usec() - queue_profile_step_started
			check(int(kernel.call("current_tick")) == tick and int(owner.get("_clock_msec")) == clock, "frame gaps preserve Tick/decision clock")
			steps += 1
		check(steps < 2000 and str((flow.call("pending_submission_tick_snapshot") as Dictionary).get("fault_reason", "")).is_empty(), "finite continuation without fault")
		var drain := 0
		while bool((flow.call("projection_publication_snapshot") as Dictionary).get("pending", false)) and drain < 2000:
			queue_profile_step_started = Time.get_ticks_usec()
			flow.call("_process", 0.0)
			queue_profile_process_cpu_usec += Time.get_ticks_usec() - queue_profile_step_started
			await process_frame
			drain += 1
		check(drain < 2000, "complete AI output drain before official human input admission")
	# Read primitive diagnostics once AFTER the complete AI authority/ACK, before
	# any local human command and all full QA checkpoint captures. No per-frame
	# Native snapshots or diagnostic formatting are included in step CPU times.
	check(not bool(kernel.get("_tick_consumer_pending")) and not bool(kernel.get("_tick_consumer_active")) and bool(kernel.get("_tick_consumer_acknowledged")), "actual Kernel final ACK complete at measured boundary")
	check(not bool((flow.call("projection_publication_snapshot") as Dictionary).get("pending", true)), "actual output FIFO empty at measured boundary")
	var measured_boundary_outputs: Array = observed_outputs.duplicate(true)
	var source_rows_after: Dictionary = _source_rows_world_snapshot(owner)
	var native_after: Dictionary = _all_native_profile(owner)
	var owner_after: Dictionary = (owner.get("_combat_projection_performance") as Dictionary).duplicate(true)
	var native_delta: Dictionary = _native_delta(native_before, native_after)
	var profile: Dictionary = {"label": label, "enabled": profile_enabled, "pending_enabled": pending_enabled,
		"native_all8_delta": native_delta,
		"actual_source_rows_world_before": source_rows_before,
		"actual_source_rows_world_after": source_rows_after,
		"owner_delta": _timing_delta(owner_before, owner_after),
		"complete_process_call_cpu_usec": queue_profile_process_cpu_usec,
		"cpu_measurement": "sum of full manual Flow._process calls from initial 7-AI Tick through ACK and publication drain; no leaf-stage sum; await wall time and independent SceneTree callbacks excluded",
		"pending_tick_performance": flow.call("pending_submission_tick_snapshot"),
		"measured_output_sequence_count": measured_boundary_outputs.size(),
		"measured_output_observer": "identical read-only deep DTO clone observers in both lanes; their synchronous signal handling is inside common operation CPU",
		"timings_may_nest_do_not_sum": true,
		"window": "first real pending Kernel Tick seven AI through complete ACK; before human queue/lock and before QA checkpoints",
		"native_window_includes_acquire_queue_lock_private_skill": true,
		"not_visual_or_FPS_acceptance": true}
	var queue_count := int((profile["owner_delta"] as Dictionary).get("ai_legacy_queue_commit", {}).get("count", 0))
	check(queue_count > 0, "actual complete seven AI contain legal queue commits")
	# Pacing receipt is at the SAME final official receipt boundary in all runs.
	check(bool(intent(flow, "ui.pacing.set", {"multiplier": 0}).get("accepted", false)), "Pause after complete AI output and before human input")
	# Admit identical legal public human commands only AFTER the measured AI.
	check(bool((flow.call("submit_intent", queue_intent) as Dictionary).get("accepted", false)), "official human queue after complete seven-AI ACK")
	check(bool((flow.call("submit_intent", lock_intent) as Dictionary).get("accepted", false)), "official human lock after complete seven-AI ACK")
	check(not bool(owner.get("_v076_ai_pending_lane_active")) and (owner.get("_v076_ai_pending_state") as Dictionary).is_empty(), "Owner continuation fully cleared after complete round")
	var complete: Dictionary = kernel.call("capture_snapshot")
	check(bool(complete.get("accepted", false)), "complete checkpoint after final ACK")
	var authority := _raw_authority(owner)
	authority["_ai_submission_started"] = owner.get("_ai_submission_started")
	authority["_v076_last_committed_tick"] = owner.get("_v076_last_committed_tick")
	authority["kernel_complete_snapshot"] = complete.get("snapshot", {})
	var complete_output: Dictionary = {
		"actual_flow_output_sequence": observed_outputs.duplicate(true),
		"measured_initial_seven_ai_output_sequence": measured_boundary_outputs,
		"flow_local_snapshot": flow.call("local_snapshot"),
		"flow_last_published_snapshot": _copy(flow.get("_v076_last_published_snapshot")),
		"screen_consumed_v075_snapshot": _copy(main.get_node("V075GameScreen").get("_v075_snapshot")),
		"screen_consumed_base_snapshot": _copy(main.get_node("V075GameScreen").get("_snapshot")),
	}
	var map_address_witness: Dictionary = _live_local_map_adapter_witness(owner)
	var verified_complete_output: Dictionary = _verified_map_address_output(complete_output, map_address_witness)
	var binding_witness := _queue_profile_runtime_binding_witness(owner)
	binding_witness["fifth_live_map_adapter"] = map_address_witness
	var normalized: Dictionary = authority.duplicate(true)
	if bool(binding_witness.get("verified", false)):
		var port_fields: Dictionary = normalized["port_raw_authority_fields"]
		port_fields["_track_instance_id"] = 0
		for role: String in ["cash", "personal_discard", "commodity_slot"]:
			(port_fields["_participant_bindings"][role] as Dictionary)["instance_id"] = 0
	var official := _final_receipts(rows)
	print("V076_PENDING_ACTUAL_MAIN_SCHEDULE|pending=%s|gap=%d|official_receipts=%d|transport_receipts=%d|diagnostic=%s" % [str(pending_enabled), schedule_gap, official.size(), rows.size()-official.size(), JSON.stringify(flow.call("pending_submission_tick_snapshot"))])
	var lane_source_after: Dictionary = _actual_source_hashes()
	check(_source_binding_proof(), label + " exact source matrix after complete output/checkpoints")
	check(var_to_bytes(lane_source_before) == var_to_bytes(lane_source_after) and JSON.stringify(lane_source_before, "", true) == JSON.stringify(lane_source_after, "", true), label + " complete bound source matrix unchanged")
	profile["source_binding_before"] = lane_source_before
	profile["source_binding_after"] = lane_source_after
	profile["projection_authority_delta"] = (profile["owner_delta"] as Dictionary).get("player_snapshot_projection_authority", {})
	profile["late_history_ROI_not_covered"] = true
	_store_capture(label, authority, normalized, rows, binding_witness, profile, complete_output, verified_complete_output)
	main.queue_free()
	for unused in range(4):
		await process_frame
	return {"authority": normalized, "official_receipts": official, "raw_receipts": rows, "profile": profile, "complete_output": verified_complete_output}
func run() -> void:
	report_path = OS.get_environment("V076_SOURCE_ROWS_ACTUAL_MAIN_REPORT_PATH")
	if report_path.is_empty() or not report_path.replace("\\", "/").begins_with("E:/"):
		push_error("Require explicit E: V076_SOURCE_ROWS_ACTUAL_MAIN_REPORT_PATH")
		quit(1)
		return
	if not _source_binding_proof():
		_finish_profile_report({})
		return
	var saved_pending := OS.get_environment("SPACE_SYNDICATE_EXPERIMENTAL_AI_TICK_PENDING")
	var saved_worker := OS.get_environment("SPACE_SYNDICATE_EXPERIMENTAL_MAP_WORKER")
	var saved_profile := OS.get_environment("V076_COMBAT_SOURCE_ROWS_EXPERIMENT")
	OS.set_environment("SPACE_SYNDICATE_EXPERIMENTAL_MAP_WORKER", "")
	var reference := await _capture(true, 1, false, "source-rows-OFF-pending")
	var profiled := await _capture(true, 1, true, "source-rows-ON-pending")
	if not reference.is_empty() and not profiled.is_empty():
		check(JSON.stringify(reference["authority"], "", true) == JSON.stringify(profiled["authority"], "", true), "profile OFF/ON complete known authority JSON; only four live-proved runtime IDs normalized")
		check(var_to_bytes(reference["authority"]) == var_to_bytes(profiled["authority"]), "profile OFF/ON complete typed authority; no fields removed")
		check(JSON.stringify(reference["raw_receipts"], "", true) == JSON.stringify(profiled["raw_receipts"], "", true), "profile OFF/ON complete raw official receipt channels/FIFO/content")
		check(var_to_bytes(reference["raw_receipts"]) == var_to_bytes(profiled["raw_receipts"]), "profile OFF/ON complete typed raw official receipt channels/FIFO/content")
		check(JSON.stringify(reference["official_receipts"], "", true) == JSON.stringify(profiled["official_receipts"], "", true), "complete official receipts unchanged")
		check(var_to_bytes(reference["official_receipts"]) == var_to_bytes(profiled["official_receipts"]), "complete typed official receipts unchanged")
		check(JSON.stringify(reference["complete_output"], "", true) == JSON.stringify(profiled["complete_output"], "", true), "OFF/ON complete published/local output JSON unchanged")
		check(var_to_bytes(reference["complete_output"]) == var_to_bytes(profiled["complete_output"]), "OFF/ON complete published/local output typed values unchanged")
		check(var_to_bytes(reference["profile"]["source_binding_before"]) == var_to_bytes(profiled["profile"]["source_binding_before"]), "OFF/ON same complete bounded source implementation")
	OS.set_environment("SPACE_SYNDICATE_EXPERIMENTAL_AI_TICK_PENDING", saved_pending)
	OS.set_environment("SPACE_SYNDICATE_EXPERIMENTAL_MAP_WORKER", saved_worker)
	OS.set_environment("V076_COMBAT_SOURCE_ROWS_EXPERIMENT", saved_profile)
	_finish_profile_report({"reference": reference.get("profile", {}), "profiled": profiled.get("profile", {}), "pending_baseline_and_profiled": true, "visual_acceptance": false, "whole_game": false})

func _raw_authority(owner: Node) -> Dictionary:
	# Full authority values, no removal of fields or performance-derived state.
	# Native diagnostic counters are collected separately below, outside timers.
	var fields := [
		"_match_id", "_seed", "_phase", "_batch_number", "_clock_msec",
		"_opened_at_msec", "_submission_deadline_msec", "_player_ids",
		"_hidden_order", "_submission_identity_sequence", "_asset_state",
		"_asset_balances", "_facility_state", "_facility_slots", "_solar_state",
		"_region_sunlit", "_queued_by_player", "_locked_by_player",
		"_maintenance_done", "_public_history", "_public_progress_points",
		"_final_settlement", "_runtime_error_count", "_invalid_action_count",
		"_invalid_action_reasons", "_nonfinite_count", "_hidden_info_violation_count",
		"_dual_authority_count", "_combat_monster_purchase_count",
		"_combat_first_monster_purchase_batch", "_combat_military_purchase_count",
		"_combat_first_military_purchase_batch", "_v075_acquisition_opportunities",
		"_v075_acquisition_last_domain", "_v075_acquisition_facility_count",
		"_v075_acquisition_monster_count", "_v075_acquisition_military_count",
		"_v075_acquisition_facility_since_combat",
		"_v075_acquisition_last_combat_opportunity", "_v075_acquisition_deferred_count",
		"_v075_acquisition_hook_count", "_v075_acquisition_rejection_count",
		"_v075_acquisition_no_mutation_violation_count",
		"_v076_deck_lifecycle_lineage_failure_count", "_v076_deck_lifecycle_receipt_count",
		"_v076_deck_lifecycle_receipt_ids", "_v076_deck_lifecycle_duplicate_count",
		"_v076_deck_lifecycle_collision_count", "_v075_ai_public_action_by_actor",
		"_v075_ai_observation_count_by_actor", "_v075_ai_observation_witness_by_actor",
		"_v075_ai_observation_witness_sequence", "_v075_ai_public_action_sequence",
		"_combat_ai_private_skill_count", "_combat_ai_military_region_count",
		"_combat_ai_military_monster_count", "_combat_ai_invalid_target_count",
	]
	var values: Dictionary = {}
	for field in fields:
		values[field] = _copy(owner.get(field))
	var track: Object = owner.get("_track_core")
	values["track_raw_state"] = _copy(track.get("_state"))
	values["track_save_complete"] = track.call("save_state_v1")
	values["dbg_raw_states"] = {}
	values["dbg_full_checkpoints"] = {}
	var dbg_by_player: Dictionary = owner.get("_dbg_by_player")
	for actor in owner.get("_player_ids"):
		var dbg: Object = dbg_by_player[actor]
		values["dbg_raw_states"][actor] = _copy(dbg.get("_state"))
		values["dbg_full_checkpoints"][actor] = dbg.call("capture_checkpoint_v1")
	values["cash_full_checkpoints"] = {}
	var cash_by_player: Dictionary = owner.get("_cash_by_player")
	for actor in cash_by_player:
		values["cash_full_checkpoints"][actor] = cash_by_player[actor].call("capture_checkpoint_v1")
	var combat: Object = owner.get("_combat_owner")
	values["combat_full_checkpoint_state"] = combat.call("_checkpoint_state")
	var port: RefCounted = owner.get("_track_port") as RefCounted
	values["port_raw_authority_fields"] = {}
	for field: String in ["_track_instance_id", "_participant_bindings", "_transactions", "_transaction_receipts", "_request_transactions", "_transaction_history", "_configured"]:
		values["port_raw_authority_fields"][field] = _copy(port.get(field))
	values["port_receipt_journal_complete"] = port.call("capture_receipt_journal_v1")
	values["router_full_checkpoints"] = {}
	for role: String in ["cash", "personal_discard", "commodity_slot"]:
		values["router_full_checkpoints"][role] = (owner.get("_acquisition_routers") as Dictionary)[role].call("capture_checkpoint_v1")
	return values



func _queue_profile_runtime_binding_witness(owner: Node) -> Dictionary:
	var port: RefCounted = owner.get("_track_port") as RefCounted
	var track: RefCounted = owner.get("_track_core") as RefCounted
	var actual_track: RefCounted = port.get("_track_authority") as RefCounted
	var ok: bool = actual_track == track and int(port.get("_track_instance_id")) == track.get_instance_id()
	var witness: Dictionary = {"track_stored": port.get("_track_instance_id"), "actual_track": track.get_instance_id(), "roles": {}}
	var participants: Dictionary = port.get("_participants") as Dictionary
	var bindings: Dictionary = port.get("_participant_bindings") as Dictionary
	var routers: Dictionary = owner.get("_acquisition_routers") as Dictionary
	for role: String in ["cash", "personal_discard", "commodity_slot"]:
		var actual: RefCounted = participants[role] as RefCounted
		var binding: Dictionary = bindings[role]
		var role_ok: bool = actual == routers[role] and int(binding["instance_id"]) == actual.get_instance_id() and str(binding["authority_id"]) == str(actual.call("acquisition_authority_id_v1")) and actual.get("_role") == role
		var actor_witness: Dictionary = {}
		for actor: String in owner.get("_player_ids"):
			var delegate: RefCounted = (actual.get("_participants_by_actor") as Dictionary).get(actor) as RefCounted
			var expected_dbg: RefCounted = (owner.get("_dbg_by_player") as Dictionary)[actor] as RefCounted
			var actor_ok: bool = delegate != null
			if role == "cash":
				actor_ok = actor_ok and delegate == (owner.get("_cash_by_player") as Dictionary)[actor] and delegate.get("_authority_id") == "v073.fixed_purchase.%s" % actor
			elif role == "personal_discard":
				actor_ok = actor_ok and delegate.get("_actor_id") == actor and delegate.get("_authority_id") == "v073.personal_discard.%s" % actor and delegate.get("_dbg") == expected_dbg
			else:
				actor_ok = actor_ok and delegate == expected_dbg and (delegate.get("_state") as Dictionary).get("owner_player_id") == actor and delegate.get("_track_receipt_authority") == track
			role_ok = role_ok and actor_ok
			actor_witness[actor] = {"actual_instance_id": delegate.get_instance_id() if delegate != null else 0, "actor_verified": actor_ok}
		witness["roles"][role] = {"stored": binding.duplicate(true), "actual_instance_id": actual.get_instance_id(), "verified": role_ok, "actors": actor_witness}
		ok = ok and role_ok
	witness["verified"] = ok
	check(ok, "complete live Track/Port/router/actor identity checks before address-only normalization")
	return witness




func _all_native_profile(owner: Node) -> Dictionary:
	var result: Dictionary = {}
	for actor: String in owner.get("_player_ids"):
		var core: RefCounted = (owner.get("_dbg_by_player") as Dictionary)[actor] as RefCounted
		result[actor] = core.call("resolution_operation_performance_snapshot") as Dictionary
	return result

func _timing_delta(before: Dictionary, after: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in after:
		var prior: Dictionary = before.get(key, {}) as Dictionary
		var current: Dictionary = after[key]
		result[key] = {"count": int(current.get("count", 0)) - int(prior.get("count", 0)), "total_usec": int(current.get("total_usec", 0)) - int(prior.get("total_usec", 0))}
	return result

func _native_delta(before: Dictionary, after: Dictionary) -> Dictionary:
	var result: Dictionary = {"by_actor": {}, "totals": {}}
	for actor: String in after:
		var delta: Dictionary = _timing_delta(before.get(actor, {}) as Dictionary, after[actor] as Dictionary)
		result["by_actor"][actor] = delta
		for stage: String in delta:
			if not result["totals"].has(stage):
				result["totals"][stage] = {"count": 0, "total_usec": 0}
			result["totals"][stage]["count"] += delta[stage]["count"]
			result["totals"][stage]["total_usec"] += delta[stage]["total_usec"]
	return result

func _write_json(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "E evidence JSON write " + path.get_file())
	if file != null:
		file.store_string(JSON.stringify(value, "\t", true))
		file.close()

func _write_typed(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "E evidence complete typed write " + path.get_file())
	if file != null:
		file.store_buffer(var_to_bytes(value))
		file.close()

func _store_capture(label: String, raw: Dictionary, normalized: Dictionary, receipts: Array, witness: Dictionary, profile: Dictionary, complete_output: Dictionary, verified_complete_output: Dictionary) -> void:
	var folder := report_path.get_base_dir()
	_write_json(folder.path_join(label + ".raw-authority.json"), raw)
	_write_typed(folder.path_join(label + ".raw-authority.variant.bin"), raw)
	_write_json(folder.path_join(label + ".verified-address-authority.json"), normalized)
	_write_typed(folder.path_join(label + ".verified-address-authority.variant.bin"), normalized)
	_write_json(folder.path_join(label + ".raw-receipts.json"), receipts)
	_write_typed(folder.path_join(label + ".raw-receipts.variant.bin"), receipts)
	_write_json(folder.path_join(label + ".live-address-witness.json"), witness)
	_write_json(folder.path_join(label + ".timings.json"), profile)
	_write_json(folder.path_join(label + ".complete-output.json"), complete_output)
	_write_typed(folder.path_join(label + ".complete-output.variant.bin"), complete_output)
	_write_json(folder.path_join(label + ".verified-map-address-complete-output.json"), verified_complete_output)
	_write_typed(folder.path_join(label + ".verified-map-address-complete-output.variant.bin"), verified_complete_output)

func _finish_profile_report(profiles: Dictionary) -> void:
	var report: Dictionary = {"schema": "v076.source_rows_actual_main_cpu_pair.v3", "status": "PASS" if failures.is_empty() else "FAIL", "checks": checks, "failures": failures, "profiles": profiles, "NOT_COVERED": ["visual/FPS acceptance", "complete match", "late-history natural Tick", "initial seven AI may have zero Monster sources/public history; zero-data fixture does not reject late-history ROI", "actual dynamic rule/source/type/derived/offthread seams: use separately frozen source rows contract and existing regressions"], "source_sha256": _actual_source_hashes()}
	_write_json(report_path, report)
	print("V076_SOURCE_ROWS_ACTUAL_MAIN_CPU_PAIR_V3|status=%s|checks=%d|failures=%s" % ["PASS" if failures.is_empty() else "FAIL", checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _actual_source_hashes() -> Dictionary:
	var hashes: Dictionary = {}
	for path: String in _expected_source_hashes():
		hashes[path] = FileAccess.get_sha256(path).to_upper()
	return hashes

func _source_binding_proof() -> bool:
	var expected: Dictionary = _expected_source_hashes()
	var owner_sha := str(expected["res://scripts/v075_runtime/v075_runtime_owner.gd"])
	check(owner_sha.length() == 64, "explicit frozen supporting Owner source binding")
	for path: String in expected:
		check(FileAccess.get_sha256(path).to_upper() == str(expected[path]), "complete exact source binding " + path)
	return failures.is_empty()

func _expected_source_hashes() -> Dictionary:
	# Bounded actual Main/support matrix, identical in both lanes. Root retains
	# responsibility for the wider affected/transitive source matrix.
	return {
	"res://scripts/v073_runtime/v073_sample_runtime_owner.gd": "28EFAAAC19268440150162A3E2079E419B55AE46195DB1CAFA5F97D46AC8199C",
	"res://scripts/v07_semantic/v07_dbg_deck_core.gd": "4B42F570208D257ED2110E066CC669B9011C81B9AB410A20AB0C7D74B89C350F",
	"res://scripts/v07_semantic/v07_track_acquisition_authority_port.gd": "01A82C9F97411A03934778F6E225E8B9C4C9915375E4B433B5F8AC829F95670A",
	"res://scripts/v07_adapters/v07_canonical_data_codec.gd": "F193745779D7FEDCCBB18BB880545EFF48985C7CCA8A360D686CD51CE58CBDD9",
	"res://scripts/v07_semantic/v07_asset_batch_core.gd": "E3F3C34D025E9111A398EF74CDF45C825781CD5E542557B4FB0155ED04B06EAD",
	"res://scripts/v07_semantic/v07_unified_card_track_core.gd": "60C15D379EDDE69E5DD325165D1502E668E788AFBD82C4BC86581DE9A6BFCC0B",
	"res://scripts/v075/runtime/v075_combat_runtime_owner.gd": "202F52B7C2BD1521EB61D39B5779B05D27D8EA6D15A02AB24B9CC2BDD303C28B",
	"res://scripts/v075/monster/v075_monster_private_skill_core.gd": "417820E177C718C598AF54B262F45C0E84D3F2330C05C86B6A36120E81FD7721",
	"res://scripts/v074/track/v074_shared_sushi_track_core.gd": "9F96D2D6CCDEE44508709F5117E1988220F31EE5281AB6A5414F6591BE046CFB",
	"res://scripts/v075_runtime/v075_application_flow.gd": "BC17648D802758F9AA89E1BC1803C68A419633ACC9EFC099DFAC8576300E346A",
	"res://scripts/v076/simulation/v076_deterministic_kernel.gd": "960AEE79DBA33654D0C2C0D740BADA5D5597CD504447A9395A4EBCD06714FE99",
	"res://scenes/main.tscn": "E11C35A360997145D54830558BC7280E638B244767C4F4092DA002D493AF9FD3",
	"res://scripts/ui/v075/v075_sample_game_screen.gd": "0780F4C68EE9E836F0919D5E9DCA0012824AAEA9EF6A4B72ACBCCC6A326D7B18",
	"res://scripts/v074/player/v074_player_map_projection_adapter.gd": "E382C9A54CC2CB91074CA31949D6E941D46F77386B00E86DF2EEDDA262F91391",
	"res://scripts/v074_runtime/v074_runtime_owner.gd": "0F8914C0006293F8AE31BFD947274E3C495DF16DF6BA8D8F356F0B25B457A961",
	"res://scripts/v075_runtime/v075_runtime_owner.gd": "60D9EFA04654CD48E1B962F5FE9FA4D5EBDD6697F63CAD8927162977E31598DE"
	}


func _source_rows_world_snapshot(owner: Node) -> Dictionary:
	var combat: Node = owner.get("_combat_owner") as Node
	check(combat != null and combat.get_script().resource_path == "res://scripts/v075/runtime/v075_combat_runtime_owner.gd", "actual Main native CombatOwner identity")
	if combat == null:
		return {}
	var skill: Dictionary = combat.get("_skill_state") as Dictionary
	var monster: Dictionary = combat.get("_monster_state") as Dictionary
	var program: Variant = combat.get("_projection_source_rows_native_program")
	check(program is Callable, "actual native program guard Callable present")
	var native_guard: bool = bool((program as Callable).call(combat)) if program is Callable else false
	check(native_guard, "OFF and ON both preserve the same fresh native program guard")
	return {
		"experiment_value": OS.get_environment("V076_COMBAT_SOURCE_ROWS_EXPERIMENT"),
		"native_program_guard": native_guard,
		"skill_source_count": (skill.get("sources", {}) as Dictionary).size(),
		"skill_public_result_count": (skill.get("public_results", []) as Array).size(),
		"monster_source_count": (monster.get("sources", {}) as Dictionary).size(),
		"combat_public_result_count": (combat.get("_public_results") as Array).size(),
		"skill_revision": int(skill.get("revision", -1)),
		"skill_batch_id": str(skill.get("batch_id", "")),
		"combat_phase": str(combat.get("_phase")),
		"sampling": "shallow native fields once at each timing boundary; no per-frame full debug",
	}


func _observe_complete_flow_outputs(flow: Node) -> Array:
	var outputs: Array = []
	for signal_name: String in ["projection_changed", "combat_presentation_cue_ready", "pacing_state_changed"]:
		var channel: String = signal_name
		check(flow.has_signal(channel), "actual authored output signal exists " + channel)
		flow.connect(channel, func(payload: Dictionary) -> void:
			outputs.append({"sequence": outputs.size() + 1, "channel": channel, "payload": payload.duplicate(true)})
		)
	return outputs


func _live_local_map_adapter_witness(owner: Node) -> Dictionary:
	var actor: String = str(owner.call("local_player_id"))
	var adapters: Dictionary = owner.get("_player_map_adapters") as Dictionary
	var adapter: RefCounted = adapters.get(actor) as RefCounted
	var native: Script = load("res://scripts/v074/player/v074_player_map_projection_adapter.gd") as Script
	var expected_sha: String = "E382C9A54CC2CB91074CA31949D6E941D46F77386B00E86DF2EEDDA262F91391"
	var ok: bool = adapter != null and native != null
	var current_identity: Dictionary = {}
	var current_body: Dictionary = {}
	var actual_id: String = ""
	if ok:
		ok = adapter.get_script() == native and native.resource_path == "res://scripts/v074/player/v074_player_map_projection_adapter.gd" and native.get_base_script() == null
		ok = ok and FileAccess.get_sha256(native.resource_path).to_upper() == expected_sha and native.source_code.sha256_text().to_upper() == expected_sha
		actual_id = str(adapter.get_instance_id())
		current_identity = adapter.call("read_model_identity") as Dictionary
		current_body = adapter.call("projection") as Dictionary
		ok = ok and current_identity.get("adapter_instance_id") is String and str(current_identity.get("adapter_instance_id", "")) == actual_id
		ok = ok and str(current_identity.get("viewer_id", "")) == actor and str(current_body.get("viewer_id", "")) == actor
		ok = ok and str(current_identity.get("projection_fingerprint", "")) == str(current_body.get("projection_fingerprint", "")) and str(current_identity.get("map_fingerprint", "")) == str(current_body.get("map_fingerprint", ""))
	check(ok, "fifth live address witness: actual local MapAdapter native script/actor/id/current identity/body")
	return {
		"verified": ok, "actor": actor, "actual_adapter_instance_id_string": actual_id,
		"actual_adapter_script_path": native.resource_path if native != null else "",
		"actual_adapter_source_sha256": FileAccess.get_sha256(native.resource_path).to_upper() if native != null else "",
		"current_read_model_identity": current_identity.duplicate(true),
		"current_projection_body": current_body.duplicate(true),
		"identity_source": {
			"owner_lookup": "scripts/v074_runtime/v074_runtime_owner.gd:245 _player_map_adapters.get(_local_player_id)",
			"owner_source_sha256": "0F8914C0006293F8AE31BFD947274E3C495DF16DF6BA8D8F356F0B25B457A961",
			"publisher": "scripts/v075_runtime/v075_runtime_owner.gd:7679-7703 validates exact adapter/identity and registers _player_map_adapters[viewer] before publication",
			"identity_constructor": "scripts/v074/player/v074_player_map_projection_adapter.gd:294-303 _read_model_identity_for uses str(get_instance_id())",
			"identity_constructor_source_sha256": expected_sha,
			"metadata_normalized": false,
		},
	}

func _verify_and_map_one_snapshot_id(snapshot: Dictionary, witness: Dictionary, path: String, current_required: bool, mapped: Array) -> void:
	if not snapshot.has("map_player_read_model_identity"):
		return
	var raw_identity: Variant = snapshot.get("map_player_read_model_identity")
	var raw_body: Variant = snapshot.get("map_player_projection")
	var ok: bool = bool(witness.get("verified", false)) and raw_identity is Dictionary and raw_body is Dictionary
	if not ok:
		check(false, "specific snapshot has complete native identity/body witness " + path)
		return
	var identity: Dictionary = raw_identity as Dictionary
	var body: Dictionary = raw_body as Dictionary
	var before: Dictionary = identity.duplicate(true)
	var expected_fields: Array = ["viewer_id", "adapter_instance_id", "input_generation", "projection_fingerprint", "map_fingerprint"]
	ok = identity.size() == expected_fields.size()
	for field: String in expected_fields:
		ok = ok and identity.has(field)
	ok = ok and identity.get("adapter_instance_id") is String and identity.get("viewer_id") is String
	ok = ok and identity.get("input_generation") is int and int(identity.get("input_generation", -1)) >= 0
	ok = ok and identity.get("projection_fingerprint") is String and identity.get("map_fingerprint") is String
	ok = ok and identity.get("adapter_instance_id") == witness.get("actual_adapter_instance_id_string") and identity.get("viewer_id") == witness.get("actor")
	ok = ok and identity.get("viewer_id") == body.get("viewer_id") and identity.get("projection_fingerprint") == body.get("projection_fingerprint") and identity.get("map_fingerprint") == body.get("map_fingerprint")
	if current_required:
		ok = ok and var_to_bytes(identity) == var_to_bytes(witness.get("current_read_model_identity")) and JSON.stringify(identity, "", true) == JSON.stringify(witness.get("current_read_model_identity"), "", true)
		ok = ok and var_to_bytes(body) == var_to_bytes(witness.get("current_projection_body")) and JSON.stringify(body, "", true) == JSON.stringify(witness.get("current_projection_body"), "", true)
	check(ok, "exact concrete snapshot historical/current identity and same-packet body metadata " + path)
	if not ok:
		return
	# The actual production capability identity stays untouched. Only this
	# detached QA output copy maps the witnessed object address String.
	identity["adapter_instance_id"] = "0"
	var after: Dictionary = identity.duplicate(true)
	var closure: Dictionary = after.duplicate(true)
	closure["adapter_instance_id"] = before["adapter_instance_id"]
	check(var_to_bytes(closure) == var_to_bytes(before) and JSON.stringify(closure, "", true) == JSON.stringify(before, "", true), "only witnessed String address changed; every identity metadata field preserved " + path)
	mapped.append({"path": path + ".map_player_read_model_identity.adapter_instance_id", "verified": ok, "raw_identity": before, "normalized_identity": after, "raw_projection_body": body.duplicate(true), "current_identity_required": current_required})

func _verified_map_address_output(raw: Dictionary, witness: Dictionary) -> Dictionary:
	var normalized: Dictionary = raw.duplicate(true)
	var mapped: Array = []
	# Explicit concrete DTO roots only; never recursively match a field name.
	for field: String in ["actual_flow_output_sequence", "measured_initial_seven_ai_output_sequence"]:
		var rows: Array = normalized.get(field, []) as Array
		for index in range(rows.size()):
			var row: Dictionary = rows[index] as Dictionary
			if str(row.get("channel", "")) == "projection_changed":
				_verify_and_map_one_snapshot_id(row.get("payload", {}) as Dictionary, witness, field + "[" + str(index) + "].payload", false, mapped)
	for field: String in ["flow_local_snapshot", "flow_last_published_snapshot", "screen_consumed_v075_snapshot", "screen_consumed_base_snapshot"]:
		_verify_and_map_one_snapshot_id(normalized.get(field, {}) as Dictionary, witness, field, true, mapped)
	check(not mapped.is_empty(), "actual complete outputs exercise the fifth live MapAdapter address")
	witness["specific_output_mappings"] = mapped
	witness["mapped_address_type"] = "String"
	witness["normalized_address_value"] = "0"
	return normalized
