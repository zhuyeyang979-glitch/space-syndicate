extends SceneTree

const PURE = preload("res://scripts/semantic/card_batch_pure_data.gd")
const TARGET = preload("res://scripts/semantic/card_batch_prebound_target_spec_v1.gd")
const SUBMISSION = preload("res://scripts/semantic/card_batch_submission_v1.gd")
const INVENTORY = preload("res://scripts/semantic/card_batch_inventory_state_v1.gd")
const RECEIPT = preload("res://scripts/semantic/card_batch_receipt_v1.gd")
const STATE = preload("res://scripts/semantic/card_batch_state_v1.gd")
const SAVE_CODEC = preload("res://scripts/runtime/card_batch_save_codec_v1.gd")
const REPLAY_IDENTITY = preload("res://scripts/runtime/card_batch_replay_identity_v1.gd")
const RUNTIME = preload("res://scripts/runtime/card_batch_reference_runtime.gd")
const VIEWER_AUTHORIZATION = preload("res://scripts/semantic/card_batch_viewer_authorization_v1.gd")
const AUTHORED_RULE = preload("res://scripts/semantic/card_batch_authored_rule_v1.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_window_draft_save_and_privacy()
	_test_mid_resolution_restore_exact_once()
	_test_hostile_save_payloads_and_rng_boundary()
	_finish()


func _test_window_draft_save_and_privacy() -> void:
	var runtime := _new_runtime()
	var inventories := _fixture_inventories()
	_expect(bool(runtime.begin_initial_window(["player.0", "player.1"], inventories, 40_000_000).get("accepted", false)), "save fixture opens its initial card window")
	runtime.advance_window_phase_time_usec(7_250_000)
	var submissions := _fixture_submissions()
	_expect(bool(runtime.configure_authoritative_card_rules(_rules_for_submissions(submissions)).get("accepted", false)), "save fixture binds a trusted authored rule catalog")
	for submission in submissions:
		_expect(bool(runtime.submit_or_replace_draft(submission).get("accepted", false)), "unlocked submission is captured during the open window")
	var player_zero_authorization := VIEWER_AUTHORIZATION.new(7) as CardBatchViewerAuthorizationV1
	_expect(runtime.bind_viewer_authorization("player.0", player_zero_authorization), "viewer-private projection requires an explicitly bound opaque authorization")
	var player_zero_projection := runtime.viewer_projection(player_zero_authorization)
	var projection_text := JSON.stringify(player_zero_projection)
	_expect(str((player_zero_projection.get("own_draft", {}) as Dictionary).get("submission_id", "")) == "submission.defense", "viewer sees only its own unlocked draft")
	_expect(not projection_text.contains("card.attack.private") and not projection_text.contains("city.rival.private"), "viewer projection hides opponent card instance and prebound target")
	_expect((player_zero_projection.get("own_inventory", {}) as Dictionary).get("actor_id", "") == "player.0" and not player_zero_projection.has("opponent_inventories"), "viewer projection exposes no opponent private inventory")
	var unbound_authorization := VIEWER_AUTHORIZATION.new(7) as CardBatchViewerAuthorizationV1
	var unbound_projection := runtime.viewer_projection(unbound_authorization)
	_expect((unbound_projection.get("own_draft", {}) as Dictionary).is_empty() and (unbound_projection.get("own_inventory", {}) as Dictionary).is_empty() and str(unbound_projection.get("visibility_scope", "")) == "public", "enumerating an actor ID cannot forge viewer-private access")
	player_zero_authorization.rotate()
	var stale_projection := runtime.viewer_projection(player_zero_authorization)
	_expect((stale_projection.get("own_draft", {}) as Dictionary).is_empty() and int(stale_projection.get("authorization_revision", -1)) == 0, "rotated viewer capability fails closed until explicitly rebound")
	var capture := runtime.capture_save_data()
	_expect(bool(capture.get("captured", false)), "open-window state captures as a pure V0.7 reference save")
	var save_data: Dictionary = capture.get("save_data", {})
	_expect(PURE.first_retired_counter_key(save_data).is_empty() and not JSON.stringify(save_data).to_lower().contains("counter_window"), "save schema contains no counter stack, window, or pending input")
	_expect(PURE.stable_serialize(save_data) != "" and str(capture.get("fingerprint", "")).length() == 64, "save payload is stably JSON serializable")
	var restore_authorization := VIEWER_AUTHORIZATION.new(13) as CardBatchViewerAuthorizationV1
	_expect(runtime.bind_viewer_authorization("player.0", restore_authorization) and not (runtime.viewer_projection(restore_authorization).get("own_draft", {}) as Dictionary).is_empty(), "pre-restore viewer capability can read only its bound actor")
	_expect(bool(runtime.restore_save_data(save_data).get("accepted", false)), "same runtime accepts its validated save checkpoint")
	var post_restore_old_capability := runtime.viewer_projection(restore_authorization)
	_expect(str(post_restore_old_capability.get("visibility_scope", "")) == "public" and (post_restore_old_capability.get("own_inventory", {}) as Dictionary).is_empty(), "restore revokes every pre-restore viewer capability")
	_expect(runtime.bind_viewer_authorization("player.0", restore_authorization) and str(runtime.viewer_projection(restore_authorization).get("visibility_scope", "")) == "viewer_private", "restored state requires explicit viewer-capability rebinding")
	var restored := _new_runtime()
	var restore := restored.restore_save_data(save_data)
	_expect(bool(restore.get("accepted", false)), "open-window save restores through preflight")
	_expect(runtime.state_fingerprint() == restored.state_fingerprint(), "open-window roundtrip preserves the exact deterministic state identity")
	_expect(int(restored.state_snapshot().get("window_remaining_phase_time_usec", -1)) == 22_750_000, "window remaining phase time restores exactly without engine clock metadata")
	var restored_inventory: Dictionary = (restored.state_snapshot().get("inventories_by_actor", {}) as Dictionary).get("player.0", {})
	var restored_bounds: Array = restored_inventory.get("bound_actions", [])
	_expect(restored_bounds.size() == 2 and int((restored_bounds[0] as Dictionary).get("charges", -1)) >= 0, "bound action sources, charges, and cooldowns roundtrip without duplicate grant")
	_free_runtime(runtime)
	_free_runtime(restored)


func _test_mid_resolution_restore_exact_once() -> void:
	var runtime := _new_runtime()
	runtime.begin_initial_window(["player.0", "player.1"], _fixture_inventories(), 80_000_000)
	var submissions := _fixture_submissions()
	runtime.configure_authoritative_card_rules(_rules_for_submissions(submissions))
	for submission in submissions:
		runtime.submit_or_replace_draft(submission)
	var lock := runtime.lock_window()
	var locked_order: Array = lock.get("resolution_order", []).duplicate()
	_expect(locked_order == ["submission.defense", "submission.attack"], "fixture resolution order is stable before the save point")
	var target_projection := {
		"submission.defense": {"target_revisions": {"city.shared": 11}, "inactive_target_ids": []},
		"submission.attack": {"target_revisions": {"city.shared": 11}, "inactive_target_ids": []},
	}
	var first_commit := runtime.commit_active_card(target_projection.get("submission.defense", {}))
	_expect(bool(first_commit.get("accepted", false)) and str(runtime.state_snapshot().get("phase", "")) == STATE.PHASE_CARD_AFTERMATH, "save point occurs after first authoritative commit and before its aftermath acknowledgement")
	var state_before_save := runtime.state_snapshot()
	_expect((state_before_save.get("card_receipts", []) as Array).size() == 1 and (state_before_save.get("defense_statuses", []) as Array).size() == 1, "first receipt and DefenseStatus exist at the mid-resolution save point")
	var identity_before := runtime.replay_identity()
	_expect(bool(REPLAY_IDENTITY.validate(identity_before).get("valid", false)), "mid-resolution state exposes a valid pure replay identity")
	var capture := runtime.capture_save_data()
	_expect(bool(capture.get("captured", false)), "mid-resolution aftermath state is saveable (%s)" % str(capture.get("reason_code", "missing_reason")))
	var restored := _new_runtime()
	var restore := restored.restore_save_data(capture.get("save_data", {}))
	_expect(bool(restore.get("accepted", false)) and restored.state_fingerprint() == runtime.state_fingerprint(), "mid-resolution restore preserves current index, active card, pending receipt, and defense state")
	_expect(restored.state_snapshot().get("resolution_order", []) == locked_order, "restore never rebuilds or reorders the locked resolution sequence")
	_expect(PURE.stable_fingerprint(restored.replay_identity()) == PURE.stable_fingerprint(identity_before), "replay identity is unchanged by save/load")
	var resume := restored.run_uninterrupted(target_projection)
	_expect(bool(resume.get("accepted", false)), "restored aftermath resumes without new player or AI input")
	var completed_receipts: Array = restored.state_snapshot().get("card_receipts", [])
	_expect(completed_receipts.size() == 2 and _receipt_count(completed_receipts, "card-receipt:card-batch:000001:000000") == 1, "already committed first card is not committed twice after restore")
	var attack_receipt: Dictionary = completed_receipts[1] if completed_receipts.size() == 2 else {}
	_expect(int(attack_receipt.get("effect_amount", -1)) == 6 and (attack_receipt.get("defense_applications", []) as Array).size() == 1, "restored DefenseStatus automatically affects the later attack")
	_expect(int(resume.get("mid_resolution_gameplay_wait_count", -1)) == 0, "restore adds no mid-resolution gameplay wait")
	var completed_state := restored.state_snapshot()
	var private_by_actor: Dictionary = completed_state.get("private_defense_receipts_by_actor", {})
	var private_rows: Array = private_by_actor.get("player.0", []) if private_by_actor.get("player.0") is Array else []
	var private_receipt: Dictionary = private_rows[0] if private_rows.size() == 1 else {}
	_expect(private_rows.size() == 1 and RECEIPT.validate_private_defense_trigger(private_receipt), "defense trigger creates one typed owner-private receipt with stable lineage")
	_expect(int(private_receipt.get("refund_amount", -1)) == 17 and int(private_receipt.get("private_trace_count", -1)) == 2 and str(private_receipt.get("triggering_submission_id", "")) == "submission.attack", "owner-private receipt preserves authored refund, trace, and triggering submission")
	var completed_capture := restored.capture_save_data()
	_expect(bool(completed_capture.get("captured", false)), "completed batch saves typed private defense receipts")
	var completed_save: Dictionary = completed_capture.get("save_data", {})
	var completed_roundtrip := SAVE_CODEC.stable_roundtrip(completed_save)
	var roundtrip_private: Dictionary = (completed_roundtrip.get("restored_state", {}) as Dictionary).get("private_defense_receipts_by_actor", {})
	_expect(bool(completed_roundtrip.get("roundtrip", false)) and PURE.stable_fingerprint(roundtrip_private) == PURE.stable_fingerprint(private_by_actor), "JSON Save roundtrip preserves private defense receipt identity exactly")
	var completed_identity := restored.replay_identity()
	_expect(bool(REPLAY_IDENTITY.validate(completed_identity).get("valid", false)) and str(completed_identity.get("private_defense_receipts_fingerprint", "")) == PURE.stable_fingerprint(private_by_actor), "Replay identity directly fingerprints owner-private defense receipts")
	var hostile_identity_extra := completed_identity.duplicate(true)
	hostile_identity_extra["unexpected_field"] = true
	_expect(not bool(REPLAY_IDENTITY.validate(hostile_identity_extra).get("valid", true)), "Replay identity rejects non-allowlisted fields")
	var hostile_identity_self := completed_identity.duplicate(true)
	hostile_identity_self["private_defense_receipts_fingerprint"] = str(completed_identity.get("card_receipts_fingerprint", ""))
	_expect(not bool(REPLAY_IDENTITY.validate(hostile_identity_self).get("valid", true)), "Replay identity recomputes and rejects a stale self fingerprint")
	var hostile_identity_order := completed_identity.duplicate(true)
	(hostile_identity_order.get("submissions", []) as Array).reverse()
	var hostile_identity_payload := hostile_identity_order.duplicate(true)
	hostile_identity_payload.erase("replay_identity_fingerprint")
	hostile_identity_order["replay_identity_fingerprint"] = PURE.stable_fingerprint(hostile_identity_payload)
	_expect(not bool(REPLAY_IDENTITY.validate(hostile_identity_order).get("valid", true)), "Replay identity rejects reordered submissions even with a recomputed self fingerprint")
	var hostile_receipt_shape := completed_save.duplicate(true)
	var hostile_shape_state: Dictionary = hostile_receipt_shape.get("card_batch_state", {})
	((hostile_shape_state.get("card_receipts", []) as Array)[0] as Dictionary)["unexpected_field"] = true
	_expect(not bool(SAVE_CODEC.preflight(hostile_receipt_shape).get("accepted", true)), "hostile Save cannot add fields to typed card receipts")
	var hostile_receipt_lineage := completed_save.duplicate(true)
	var hostile_lineage_state: Dictionary = hostile_receipt_lineage.get("card_batch_state", {})
	var hostile_attack_receipt := (hostile_lineage_state.get("card_receipts", []) as Array)[1] as Dictionary
	hostile_attack_receipt["submission_id"] = "submission.defense"
	(hostile_attack_receipt.get("mutation_summary", {}) as Dictionary)["submission_id"] = "submission.defense"
	_expect(not bool(SAVE_CODEC.preflight(hostile_receipt_lineage).get("accepted", true)), "hostile Save cannot rebind a receipt to another ordered submission")
	var hostile_private_duplicate := completed_save.duplicate(true)
	var duplicate_private: Dictionary = (hostile_private_duplicate.get("card_batch_state", {}) as Dictionary).get("private_defense_receipts_by_actor", {})
	(duplicate_private.get("player.0", []) as Array).append(private_receipt.duplicate(true))
	_expect(not bool(SAVE_CODEC.preflight(hostile_private_duplicate).get("accepted", true)), "hostile Save cannot duplicate an owner-private defense receipt")
	var hostile_private_refund := completed_save.duplicate(true)
	var changed_private: Dictionary = (hostile_private_refund.get("card_batch_state", {}) as Dictionary).get("private_defense_receipts_by_actor", {})
	((changed_private.get("player.0", []) as Array)[0] as Dictionary)["refund_amount"] = 18
	_expect(not bool(SAVE_CODEC.preflight(hostile_private_refund).get("accepted", true)), "hostile Save cannot change private refund lineage independently")
	var hostile_defense_lineage := completed_save.duplicate(true)
	var defense_lineage_state: Dictionary = hostile_defense_lineage.get("card_batch_state", {})
	var defense_lineage_application := (((defense_lineage_state.get("card_receipts", []) as Array)[1] as Dictionary).get("defense_applications", []) as Array)[0] as Dictionary
	defense_lineage_application["owner_player_id"] = "player.1"
	_expect(not bool(SAVE_CODEC.preflight(hostile_defense_lineage).get("accepted", true)), "hostile Save cannot detach a defense application from its authoritative status owner")
	var hostile_completion := completed_save.duplicate(true)
	var changed_completion: Dictionary = (hostile_completion.get("card_batch_state", {}) as Dictionary).get("batch_complete_receipt", {})
	changed_completion["completed_submission_ids"] = ["submission.attack", "submission.defense"]
	_expect(not bool(SAVE_CODEC.preflight(hostile_completion).get("accepted", true)), "hostile Save cannot replace the batch-complete resolution order")
	var hostile_pending := (capture.get("save_data", {}) as Dictionary).duplicate(true)
	var pending_ids: Array = (hostile_pending.get("card_batch_state", {}) as Dictionary).get("pending_receipt_ids", [])
	pending_ids.append(pending_ids[0])
	_expect(not bool(SAVE_CODEC.preflight(hostile_pending).get("accepted", true)), "hostile Save cannot duplicate a pending authoritative receipt")
	var complete_receipt: Dictionary = resume.get("batch_complete_receipt", {})
	_expect(bool(restored.consume_batch_complete_receipt(complete_receipt).get("accepted", false)), "restored batch complete receipt alone opens the next window")
	var next_inventory: Dictionary = (restored.state_snapshot().get("inventories_by_actor", {}) as Dictionary).get("player.0", {})
	var bounds_after_restore: Array = next_inventory.get("bound_actions", [])
	_expect(bounds_after_restore.size() == 2 and _bound_ids_unique(bounds_after_restore), "bound actions restore once and never re-grant on next-window open")
	_expect((restored.state_snapshot().get("private_defense_receipts_by_actor", {}) as Dictionary).is_empty(), "next window clears batch-scoped private defense receipts")
	var next_window_capture := restored.capture_save_data()
	var hostile_consumed := (next_window_capture.get("save_data", {}) as Dictionary).duplicate(true)
	var consumed_ids: Array = (hostile_consumed.get("card_batch_state", {}) as Dictionary).get("consumed_batch_complete_receipt_ids", [])
	consumed_ids.append(consumed_ids[0])
	_expect(not bool(SAVE_CODEC.preflight(hostile_consumed).get("accepted", true)), "hostile Save cannot duplicate a consumed batch-complete receipt id")
	_free_runtime(runtime)
	_free_runtime(restored)


func _test_hostile_save_payloads_and_rng_boundary() -> void:
	var runtime := _new_runtime()
	runtime.begin_initial_window(["player.0", "player.1"], _fixture_inventories())
	var capture := runtime.capture_save_data()
	var save_data: Dictionary = capture.get("save_data", {})
	_expect(not PURE.is_pure_json_data({"value": NAN}) and not PURE.is_pure_json_data({"value": INF}) \
		and PURE.stable_serialize({"value": NAN}).is_empty() and PURE.stable_fingerprint({"value": INF}).is_empty(), "pure-data serialization and identity reject NaN and Infinity")
	for non_finite_value in [NAN, INF, -INF]:
		var non_finite_save := save_data.duplicate(true)
		(non_finite_save.get("card_batch_state", {}) as Dictionary)["world_effective_time_usec"] = non_finite_value
		_expect(not bool(SAVE_CODEC.preflight(non_finite_save).get("accepted", true)), "Save rejects non-finite simulation time: %s" % str(non_finite_value))
	var retired_markers := ["card_counter", "Counter-Check", "counter pass", "Counter.Play.Reactive"]
	for marker in retired_markers:
		var hostile_rule := AUTHORED_RULE.build(
			"v07.hostile.rule", "normal_card", "normal_hand", 0,
			"none", "FIZZLE_NO_EFFECT", {"legacy_timing_marker": marker}
		)
		_expect(not bool(AUTHORED_RULE.validate(hostile_rule).get("valid", true)), "authored rule rejects normalized retired Counter marker: %s" % marker)
		var marker_save := save_data.duplicate(true)
		(marker_save.get("card_batch_state", {}) as Dictionary)["phase_trace"] = [{"event_kind": marker}]
		_expect(not bool(SAVE_CODEC.preflight(marker_save).get("accepted", true)), "Save rejects normalized retired Counter marker: %s" % marker)
	var hostile_counter_key_rule := AUTHORED_RULE.build(
		"v07.hostile.key", "normal_card", "normal_hand", 0,
		"none", "FIZZLE_NO_EFFECT", {"counter_play_mode": "late"}
	)
	_expect(not bool(AUTHORED_RULE.validate(hostile_counter_key_rule).get("valid", true)), "authored rule rejects retired Counter prefixes in field names")
	var hostile_batch_id := save_data.duplicate(true)
	(hostile_batch_id.get("card_batch_state", {}) as Dictionary)["batch_id"] = "card-batch:000099"
	_expect(not bool(SAVE_CODEC.preflight(hostile_batch_id).get("accepted", true)), "Save binds batch_id to batch_sequence")
	var hostile_window_id := save_data.duplicate(true)
	(hostile_window_id.get("card_batch_state", {}) as Dictionary)["window_id"] = "card-window:000099"
	_expect(not bool(SAVE_CODEC.preflight(hostile_window_id).get("accepted", true)), "Save binds window_id to window_sequence")
	var retired_payload := save_data.duplicate(true)
	(retired_payload.get("card_batch_state", {}) as Dictionary)["counter_stack"] = []
	_expect(not bool(SAVE_CODEC.preflight(retired_payload).get("accepted", true)), "hostile retired counter-stack save field fails closed")
	var retired_event_payload := save_data.duplicate(true)
	(retired_event_payload.get("card_batch_state", {}) as Dictionary)["phase_trace"] = [{"event_kind": "COUNTER_WINDOW"}]
	_expect(not bool(SAVE_CODEC.preflight(retired_event_payload).get("accepted", true)), "hostile retired counter event fails closed and cannot enter replay identity")
	var object_payload := save_data.duplicate(true)
	var runtime_object := Node.new()
	((object_payload.get("card_batch_state", {}) as Dictionary).get("aftermath_state", {}) as Dictionary)["node"] = runtime_object
	_expect(not bool(SAVE_CODEC.preflight(object_payload).get("accepted", true)), "Node/Object cannot enter card-batch save data")
	runtime_object.free()
	var source_text := ""
	for path in _card_batch_source_paths():
		source_text += "\n" + FileAccess.get_file_as_string(path)
	var lowered := source_text.to_lower()
	var has_rng_entry := lowered.contains("randomnumbergenerator") \
		or lowered.contains("randf(") \
		or lowered.contains("randi(") \
		or lowered.contains("randomize(") \
		or lowered.contains("seed(")
	_expect(not has_rng_entry, "lock, target validation, DefenseStatus application, save restore, and display order consume zero RNG")
	var state_validation := STATE.validate(runtime.state_snapshot())
	_expect(bool(state_validation.get("valid", false)), "hostile probes do not mutate the live authoritative reference state")
	_free_runtime(runtime)


func _fixture_inventories() -> Dictionary:
	var player_zero := INVENTORY.empty("player.0")
	player_zero = INVENTORY.add_normal_card(player_zero, _normal("card.defense.private", "v07.proactive.shield", 1)).get("state", {})
	player_zero = INVENTORY.grant_bound_action(player_zero, _bound("bound.monster.action", "v07.bound.monster", "batch_action", "monster", "monster.alpha", 4, 2, 5_000_000)).get("state", {})
	player_zero = INVENTORY.grant_bound_action(player_zero, _bound("bound.monster.passive", "v07.bound.passive", "passive_source_ability", "monster", "monster.alpha", 4, 99, 0)).get("state", {})
	var player_one := INVENTORY.empty("player.1")
	player_one = INVENTORY.add_normal_card(player_one, _normal("card.attack.private", "v07.batch.attack", 1)).get("state", {})
	player_one = INVENTORY.add_commodity_card(player_one, _commodity("commodity.private", "v07.commodity.private", 2)).get("state", {})
	return {"player.0": player_zero, "player.1": player_one}


func _fixture_submissions() -> Array:
	return [
		SUBMISSION.build(
			"submission.defense", "player.0", "card.defense.private", "v07.proactive.shield",
			"proactive_defense", "normal_hand", 1, 0, 0, 0,
			TARGET.build("city", ["city.shared"], 11, "", "protect", 1, {
				"defense_kind": "shield", "effect_filter": "damage", "reduction_amount": 4,
				"prevention_count": 0, "remaining_uses": 1, "visibility_policy": "owner_private",
				"trigger_refund_amount": 17, "private_trace_count": 2,
			}),
		),
		SUBMISSION.build(
			"submission.attack", "player.1", "card.attack.private", "v07.batch.attack",
			"batch_interference", "normal_hand", 1, 1, 10, 0,
			TARGET.build("city", ["city.shared"], 11, "", "damage", 1, {"effect_kind": "damage", "effect_amount": 10, "private_planning_target": "city.rival.private"}),
		),
	]


func _rules_for_submissions(submissions: Array) -> Dictionary:
	var rules: Dictionary = {}
	for submission_variant in submissions:
		var submission := submission_variant as Dictionary
		rules[str(submission.get("card_semantic_id", ""))] = AUTHORED_RULE.from_submission(submission)
	return rules


func _normal(instance_id: String, semantic_id: String, revision: int) -> Dictionary:
	return {"card_instance_id": instance_id, "card_semantic_id": semantic_id, "source_revision": revision}


func _commodity(instance_id: String, semantic_id: String, revision: int) -> Dictionary:
	return {"card_instance_id": instance_id, "card_semantic_id": semantic_id, "source_revision": revision, "commodity_id": "technology", "commodity_level": 2}


func _bound(instance_id: String, semantic_id: String, action_kind: String, source_kind: String, source_id: String, revision: int, charges: int, cooldown_usec: int) -> Dictionary:
	return {
		"bound_action_id": instance_id,
		"card_semantic_id": semantic_id,
		"action_kind": action_kind,
		"source_kind": source_kind,
		"source_id": source_id,
		"source_revision": revision,
		"cooldown_remaining_phase_time_usec": cooldown_usec,
		"charges": charges,
	}


func _receipt_count(receipts: Array, receipt_id: String) -> int:
	var count := 0
	for receipt_variant in receipts:
		if receipt_variant is Dictionary and str((receipt_variant as Dictionary).get("receipt_id", "")) == receipt_id:
			count += 1
	return count


func _bound_ids_unique(actions: Array) -> bool:
	var ids: Array[String] = []
	for action_variant in actions:
		if not (action_variant is Dictionary):
			return false
		var action_id := str((action_variant as Dictionary).get("bound_action_id", ""))
		if action_id.is_empty() or action_id in ids:
			return false
		ids.append(action_id)
	return true


func _card_batch_source_paths() -> Array[String]:
	var result: Array[String] = []
	for directory_path in ["res://scripts/semantic", "res://scripts/runtime"]:
		var directory := DirAccess.open(directory_path)
		if directory == null:
			continue
		directory.list_dir_begin()
		var file_name := directory.get_next()
		while not file_name.is_empty():
			if not directory.current_is_dir() and file_name.begins_with("card_batch_") and file_name.ends_with(".gd"):
				result.append("%s/%s" % [directory_path, file_name])
			file_name = directory.get_next()
		directory.list_dir_end()
	result.sort()
	return result


func _new_runtime() -> CardBatchReferenceRuntime:
	var runtime := RUNTIME.new() as CardBatchReferenceRuntime
	root.add_child(runtime)
	return runtime


func _free_runtime(runtime: CardBatchReferenceRuntime) -> void:
	if runtime == null:
		return
	root.remove_child(runtime)
	runtime.free()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("CARD_BATCH_SAVE_REPLAY_ROUNDTRIP_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	push_error("CARD_BATCH_SAVE_REPLAY_ROUNDTRIP_TEST|status=FAIL|checks=%d|failures=%d\n- %s" % [_checks, _failures.size(), "\n- ".join(_failures)])
	quit(1)
