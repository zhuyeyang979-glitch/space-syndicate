extends SceneTree

const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")

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
	_expect(binding != null and str(binding.get("preflight_method")) == "preflight_save_data", "card execution section declares the pure live-owner preflight")
	var original := execution.to_save_data()
	var target := original.duplicate(true)
	var checkpoint := (target.get("transition_controller", {}) as Dictionary).duplicate(true)
	checkpoint["card_transition_command_schema_version"] = 1
	checkpoint["card_transition_command_revision"] = 41
	checkpoint["card_transition_command_next_order_index"] = 1
	checkpoint["card_transition_applied_lineage"] = [{
		"command_id": "registry-transition-41-0",
		"command_fingerprint": "fingerprint-41-0",
		"batch_revision": 41,
		"order_index": 0,
		"receipt_fingerprint": "receipt-41-0",
	}]
	checkpoint["card_transition_last_applied_revision"] = 41
	checkpoint["card_transition_last_applied_order_index"] = 0
	checkpoint["card_resolution_timer"] = -5.0
	target["transaction_sequence"] = 601
	target["completed_resolution_ids"] = [601]
	target["inflight_resolution_ids"] = []
	target["transition_controller"] = checkpoint
	var before_preflight := execution.to_save_data()
	var owner_preflight := execution.preflight_save_data(target)
	var normalized_target := (owner_preflight.get("normalized_state", {}) as Dictionary).duplicate(true)
	var normalized_checkpoint := (normalized_target.get("transition_controller", {}) as Dictionary).duplicate(true)
	_expect(bool(owner_preflight.get("accepted", false)) and is_zero_approx(float(normalized_checkpoint.get("card_resolution_timer", -1.0))), "pure owner preflight returns the exact clamped checkpoint that apply will commit")
	var preflight: Dictionary = registry.call("_preflight_owner", execution, binding, target)
	_expect(bool(preflight.get("ok", false)), "real registry preflights the composite transition checkpoint without duplicating a detached owner")
	_expect(execution.to_save_data() == before_preflight, "registry preflight mutates neither execution nor transition owner")
	var applied := execution.apply_save_data(target)
	_expect(bool(applied.get("applied", false)) and bool(applied.get("transition_checkpoint_restored", false)), "live section apply restores execution and transition lineage together")
	_expect(execution.to_save_data() == normalized_target, "composite apply exactly matches the pure preflight normalized state")
	_expect(execution.resolution_completed(601), "execution exact-once completion lineage is restored")
	var restored_checkpoint := controller.transition_lineage_snapshot()
	_expect(int(restored_checkpoint.get("batch_revision", -1)) == 41 and int(restored_checkpoint.get("applied_command_count", -1)) == 1, "producer revision and applied command lineage restore through the registered section")
	var rolled_back := execution.apply_save_data(original)
	_expect(bool(rolled_back.get("applied", false)) and execution.to_save_data() == original, "registered section rollback restores the composite checkpoint exactly")
	var forged := target.duplicate(true)
	var forged_checkpoint := (forged.get("transition_controller", {}) as Dictionary).duplicate(true)
	var forged_lineage := (forged_checkpoint.get("card_transition_applied_lineage", []) as Array).duplicate(true)
	forged_lineage.append((forged_lineage[0] as Dictionary).duplicate(true))
	forged_checkpoint["card_transition_applied_lineage"] = forged_lineage
	forged["transition_controller"] = forged_checkpoint
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
