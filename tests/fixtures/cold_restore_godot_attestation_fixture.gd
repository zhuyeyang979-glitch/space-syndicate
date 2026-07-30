extends SceneTree

const ATTESTATION := preload("res://scripts/tools/cold_restore_child_completion_attestation.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var run_id := ""
	var repository_head := ""
	for argument_variant in OS.get_cmdline_user_args():
		var argument := str(argument_variant)
		if argument.begins_with("--fixture-run-id="):
			run_id = argument.trim_prefix("--fixture-run-id=")
		elif argument.begins_with("--fixture-repository-head="):
			repository_head = argument.trim_prefix("--fixture-repository-head=")
	var attestation := ATTESTATION.build({
		"run_id": run_id,
		"role": "qualification",
		"repository_head": repository_head,
		"scenario_fingerprint": "a".repeat(64),
		"official": false,
		"formal": false,
		"qualification_completed": true,
		"qualification_green": true,
		"product_blocker": "",
		"queue_count": 1,
		"queue_revision": 1,
		"queue_trigger_actor": "local",
		"queue_trigger_semantic_action_id": "card.play",
		"queue_trigger_card_semantic_id": "fixture.card",
		"queue_trigger_target_fingerprint": "b".repeat(64),
		"save_written": false,
		"official_count_consumed": false,
		"product_mutation_count": 0,
		"direct_authority_mutation_count": 0,
		"queue_injection_count": 0,
		"final_reason_code": "qualification_green",
		"child_ready_to_exit": true,
	})
	var write := ATTESTATION.write_completion(attestation)
	if not bool(write.get("valid", false)):
		push_error("Godot attestation fixture write failed: %s" % str(write.get("reason_code", "unknown")))
		quit(13)
		return
	print("GODOT_ATTESTATION_FIXTURE|pid=%d" % OS.get_process_id())
	quit(0)
