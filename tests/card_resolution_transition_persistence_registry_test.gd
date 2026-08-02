extends SceneTree

const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")
const SAVE_CODEC := preload("res://scripts/runtime/card_resolution_execution_save_wire_codec_v4.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var coordinator := COORDINATOR_SCENE.instantiate()
	root.add_child(coordinator)
	await process_frame
	var registry := coordinator.get_node_or_null("GameSessionRuntimeController/V06SaveOwnerRegistry")
	var execution := coordinator.get_node_or_null("CardResolutionExecutionRuntimeService") as CardResolutionExecutionRuntimeService
	var controller := coordinator.get_node_or_null("CardResolutionRuntimeController") as CardResolutionRuntimeController
	_expect(registry != null and execution != null and controller != null, "production card-resolution save participants are composed")
	if registry == null or execution == null or controller == null:
		coordinator.queue_free()
		await process_frame
		_finish()
		return
	var binding: Resource
	for candidate in registry.bindings:
		if candidate != null and str(candidate.get("section_id")) == "card_resolution_execution":
			binding = candidate
			break
	_expect(binding != null and str(binding.get("preflight_method")) == "preflight_save_data" \
			and int(binding.get("state_version")) == 2, "card execution state-v2 section declares the pure live-owner preflight")
	var original := execution.to_save_data()
	controller.begin_group_window(-1.0, 0, 3)
	controller.simultaneous_timer = 8.625
	var commands := controller.tick(0.0, {
		"queue_empty": false,
		"active_present": false,
		"active_counterable": false,
		"active_id": "",
		"lock_duration": 5.0,
		"public_bid_duration": 5.0,
		"counter_duration": 5.0,
		"active_player_indices": [],
	})
	for command_variant: Variant in commands:
		if command_variant is Dictionary:
			controller.mark_transition_command_applied(command_variant as Dictionary, {"handled": true})
	controller.begin_active_display(2.625)
	var target := execution.to_save_data()
	_expect(target != original and bool(execution.apply_save_data(original).get("applied", false)), "test authors a valid non-idle checkpoint and restores the baseline")
	var before_preflight := execution.to_save_data()
	var owner_preflight := execution.preflight_save_data(target)
	var normalized_target := (owner_preflight.get("normalized_state", {}) as Dictionary).duplicate(true)
	_expect(bool(owner_preflight.get("accepted", false)) and normalized_target == target, "pure owner preflight returns the exact canonical checkpoint that apply will commit")
	var preflight: Dictionary = registry.call("_preflight_owner", execution, binding, target)
	_expect(bool(preflight.get("ok", false)), "real registry preflights the composite transition checkpoint without duplicating a detached owner")
	_expect(execution.to_save_data() == before_preflight, "registry preflight mutates neither execution nor transition owner")
	var applied := execution.apply_save_data(target)
	_expect(bool(applied.get("applied", false)) and bool(applied.get("transition_checkpoint_restored", false)), "live section apply restores execution and transition lineage together")
	_expect(execution.to_save_data() == normalized_target, "composite apply exactly matches the pure preflight normalized state")
	var restored_checkpoint := controller.transition_lineage_snapshot()
	_expect(int(restored_checkpoint.get("batch_revision", -1)) > 0 and int(restored_checkpoint.get("applied_command_count", -1)) > 0, "producer revision and applied command lineage restore through the registered section")
	var rolled_back := execution.apply_save_data(original)
	_expect(bool(rolled_back.get("applied", false)) and execution.to_save_data() == original, "registered section rollback restores the composite checkpoint exactly")
	var forged_runtime := (SAVE_CODEC.decode_save_state(target).get("value", {}) as Dictionary).duplicate(true)
	(forged_runtime.get("transition_controller") as Dictionary)["card_resolution_timer"] = -5.0
	var forged := SAVE_CODEC.encode_save_state(forged_runtime).get("value", {}) as Dictionary
	var before_rejection := execution.to_save_data()
	var rejected: Dictionary = registry.call("_preflight_owner", execution, binding, forged)
	_expect(not bool(rejected.get("ok", true)) and execution.to_save_data() == before_rejection, "tampered checkpoint is rejected during pure preflight with zero live mutation")
	var atomic_rejection := execution.apply_save_data(forged)
	_expect(not bool(atomic_rejection.get("applied", true)) and execution.to_save_data() == before_rejection, "composite apply rejects an invalid checkpoint before either execution or transition state mutates")
	coordinator.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print("CARD_RESOLUTION_TRANSITION_PERSISTENCE_REGISTRY|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	quit(0 if _failures.is_empty() else 1)
