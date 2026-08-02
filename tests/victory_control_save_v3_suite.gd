extends RefCounted
class_name VictoryControlSaveV3Suite

const FIXTURE := preload("res://tests/victory_control_save_v3_fixture.gd")
const SAVE_CODEC := preload("res://scripts/runtime/victory_control_save_wire_codec_v3.gd")
const SCALAR := preload("res://scripts/runtime/closed_save_scalar_codec_v1.gd")
const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const PROJECTION := preload("res://scripts/tools/victory_authoritative_restore_projection_v1.gd")
const HANDSHAKE := preload("res://scripts/runtime/ruleset_save_handshake_service.gd")
const HANDSHAKE_SCENE := preload("res://scenes/runtime/RulesetSaveHandshakeService.tscn")


static func run(tree: SceneTree, focus: String) -> Dictionary:
	var state := {"checks": 0, "failures": []}
	var owner := FIXTURE.controller(tree)
	_expect(state, owner != null, "victory_controller_fixture_ready")
	if owner == null:
		return state
	match focus:
		"wire_codec": _test_wire_codec(state, owner)
		"save_v3": _test_save_v3(state, tree, owner)
		"legacy": _test_legacy_fail_closed(state, owner)
		"idle": _test_idle_roundtrip(state, tree, owner)
		"qualification": _test_qualification_roundtrip(state, tree, owner)
		"audit": _test_audit_roundtrip(state, tree, owner)
		"audit_zero": _test_audit_zero_boundary(state, tree, owner)
		"resolved": _test_resolved_roundtrip(state, tree, owner)
		"special": _test_special_roundtrip(state, tree, owner)
		"fresh_gate": _test_fresh_world_facts_gate(state, tree, owner)
		"outcome_exact_once": _test_outcome_exact_once(state, tree, owner)
		"final_settlement_exact_once": _test_final_settlement_exact_once(state, tree, owner)
		"zero_side_effect": _test_zero_side_effect(state, owner)
		"registry_checkpoint": _test_registry_managed_checkpoint(state, owner)
		"fault_rollback": _test_fault_rollback(state, owner)
		_:
			_expect(state, false, "unknown_suite_focus:%s" % focus)
	owner.free()
	return state


static func _test_wire_codec(state: Dictionary, owner: Node) -> void:
	var save := FIXTURE.qualification(owner)
	var decoded := SAVE_CODEC.decode_save_state(save)
	var runtime := decoded.get("value", {}) as Dictionary
	var payload := FIXTURE.payload(save)
	var qualification := payload.get("qualification_elapsed_by_player", {}) as Dictionary
	_expect(state, bool(decoded.get("ok", false)) and WIRE.is_closed_data(save), "save_v3_codec_closed")
	_expect(state, _raw_float_count(save) == 0 and _raw_null_count(save) == 0, "save_v3_codec_has_no_raw_float_or_null")
	_expect(state, qualification.size() == 2, "qualification_map_preserves_two_string_keys")
	for tag in qualification.values():
		_expect(state, tag is Dictionary and str((tag as Dictionary).get("codec", "")) == SCALAR.F64_CODEC_ID, "qualification_elapsed_uses_shared_f64_codec")
	_expect(state, (payload.get("audit_remaining_seconds", {}) as Dictionary) == SCALAR.encode_f64(0.0).get("value"), "audit_timer_uses_shared_f64_codec")
	for invalid_key in ["", "+1", "-1", "01", "8"]:
		var invalid := runtime.duplicate(true)
		var invalid_payload := (invalid.get("victory_control_runtime", {}) as Dictionary).duplicate(true)
		invalid_payload["qualification_elapsed_by_player"] = {invalid_key: 1.25}
		invalid["victory_control_runtime"] = invalid_payload
		_expect(state, not bool(SAVE_CODEC.encode_save_state(invalid).get("ok", true)), "invalid_player_key_rejected:%s" % invalid_key)
	var integer_key := runtime.duplicate(true)
	var integer_payload := (integer_key.get("victory_control_runtime", {}) as Dictionary).duplicate(true)
	integer_payload["qualification_elapsed_by_player"] = {1: 1.25}
	integer_key["victory_control_runtime"] = integer_payload
	_expect(state, not bool(SAVE_CODEC.encode_save_state(integer_key).get("ok", true)), "non_string_player_key_rejected")
	var malformed := save.duplicate(true)
	(malformed.get("victory_control_runtime", {}) as Dictionary)["audit_remaining_seconds"] = 1.25
	_expect(state, not bool(SAVE_CODEC.decode_save_state(malformed).get("ok", true)), "raw_float_wire_rejected")
	var extra := save.duplicate(true)
	extra["unknown"] = true
	_expect(state, not bool(SAVE_CODEC.decode_save_state(extra).get("ok", true)), "unknown_top_level_field_rejected")


static func _test_save_v3(state: Dictionary, tree: SceneTree, owner: Node) -> void:
	var save_a := FIXTURE.qualification(owner)
	var parsed := _json_roundtrip(save_a)
	var preflight: Dictionary = owner.call("preflight_save_data", parsed)
	var projection_a := PROJECTION.project(save_a)
	var target := FIXTURE.controller(tree)
	var applied: Dictionary = target.call("apply_save_data", parsed) if target != null else {}
	var save_b: Dictionary = target.call("to_save_data") if target != null else {}
	var projection_b := PROJECTION.project(save_b)
	_expect(state, int(_decoded_payload(save_a).get("schema_version", 0)) == 3, "save_schema_version_three")
	_expect(state, WIRE.is_closed_data(save_a) and _raw_float_count(save_a) == 0, "save_v3_strict_closed_wire")
	_expect(state, bool(preflight.get("accepted", false)), "save_v3_json_preflight_green:%s" % str(preflight))
	_expect(state, bool(applied.get("applied", false)) and save_a == save_b, "save_v3_a_equals_b:%s" % str(applied))
	_expect(state, WIRE.fingerprint(save_a) == WIRE.fingerprint(save_b), "save_v3_fingerprint_parity")
	_expect(state, bool(projection_a.get("ok", false)) and projection_a == projection_b, "authoritative_projection_parity")
	var registry_scene := FileAccess.get_file_as_string("res://scenes/runtime/V06SaveOwnerRegistry.tscn")
	var binding_start := registry_scene.find('[sub_resource type="Resource" id="BindingVictory"]')
	var binding_end := registry_scene.find("[sub_resource", binding_start + 1)
	var victory_binding := registry_scene.substr(binding_start, binding_end - binding_start)
	var version_registry := FileAccess.get_file_as_string("res://resources/rules/controller_state_version_registry_v06.tres")
	var version_start := version_registry.find('controller_id = "victory_control"')
	var version_block := version_registry.substr(version_start, 160)
	_expect(state, victory_binding.contains("state_version = 2") \
			and not victory_binding.contains("checkpoint_method"), "victory_registry_owner_state_v2_keeps_managed_checkpoint")
	_expect(state, version_block.contains("state_version = 2"), "controller_state_registry_declares_victory_v2")
	if target != null:
		target.free()


static func _test_legacy_fail_closed(state: Dictionary, owner: Node) -> void:
	var before: Dictionary = owner.call("to_save_data")
	var legacy := _decoded_save(before)
	var legacy_payload := FIXTURE.payload(legacy)
	legacy_payload["schema_version"] = 2
	legacy["victory_control_runtime"] = legacy_payload
	var legacy_copy := legacy.duplicate(true)
	var preflight: Dictionary = owner.call("preflight_save_data", legacy)
	var applied: Dictionary = owner.call("apply_save_data", legacy)
	_expect(state, not bool(preflight.get("accepted", true)) and bool(preflight.get("requires_backup", false)), "legacy_v2_preflight_requires_backup:%s" % str(preflight))
	_expect(state, not bool(applied.get("applied", true)) \
			and str(applied.get("reason_code", "")) == "victory_save_v2_closed_wire_upgrade_requires_backup" \
			and bool(applied.get("requires_backup", false)), "legacy_v2_apply_requires_backup:%s" % str(applied))
	_expect(state, legacy == legacy_copy and owner.call("to_save_data") == before, "legacy_v2_rejection_has_zero_mutation")
	var handshake: Node = HANDSHAKE_SCENE.instantiate()
	owner.get_tree().root.add_child(handshake)
	var legacy_envelope := _legacy_victory_v2_envelope(handshake, legacy)
	var envelope_validation: Dictionary = handshake.call("validate_envelope", legacy_envelope)
	_expect(state, not bool(envelope_validation.get("valid", true)) \
			and str(envelope_validation.get("reason_code", "")) == "victory_save_v2_closed_wire_upgrade_requires_backup" \
			and bool(envelope_validation.get("requires_backup", false)), "legacy_v2_envelope_requires_backup")
	var legacy_path := "user://test_runs/alpha04c_victory_v2_fail_closed/victory_v2_%d.save" % OS.get_process_id()
	var absolute_directory := ProjectSettings.globalize_path(legacy_path.get_base_dir())
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	var file := FileAccess.open(legacy_path, FileAccess.WRITE) if directory_error == OK else null
	if file != null:
		file.store_string(JSON.stringify(legacy))
		file.flush()
		file.close()
	var bytes_before := FileAccess.get_file_as_bytes(legacy_path) if FileAccess.file_exists(legacy_path) else PackedByteArray()
	owner.call("apply_save_data", legacy)
	var bytes_after := FileAccess.get_file_as_bytes(legacy_path) if FileAccess.file_exists(legacy_path) else PackedByteArray()
	_expect(state, not bytes_before.is_empty() and bytes_before == bytes_after, "legacy_save_file_preserved_byte_exact")
	if FileAccess.file_exists(legacy_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy_path))
	handshake.free()


static func _test_idle_roundtrip(state: Dictionary, tree: SceneTree, owner: Node) -> void:
	var save := owner.call("to_save_data") as Dictionary
	var target := FIXTURE.controller(tree)
	var applied: Dictionary = target.call("apply_save_data", _json_roundtrip(save)) if target != null else {}
	_expect(state, bool(applied.get("applied", false)) and target.call("to_save_data") == save, "idle_roundtrip_exact")
	_expect(state, str(_decoded_payload(save).get("state", "")) == "idle", "idle_state_preserved")
	if target != null:
		target.free()


static func _test_qualification_roundtrip(state: Dictionary, tree: SceneTree, owner: Node) -> void:
	var save := FIXTURE.qualification(owner)
	var before := _decoded_payload(save).get("qualification_elapsed_by_player", {}) as Dictionary
	var target := FIXTURE.controller(tree)
	var applied: Dictionary = target.call("apply_save_data", _json_roundtrip(save)) if target != null else {}
	var after := _decoded_payload(target.call("to_save_data") as Dictionary).get("qualification_elapsed_by_player", {}) as Dictionary if target != null else {}
	_expect(state, bool(applied.get("applied", false)) and before.size() == 2 and before.keys() == after.keys(), "qualification_two_player_roundtrip")
	for key in before.keys():
		_expect(state, after.has(key) \
				and SCALAR.f64_bits_hex(float(before.get(key))) == SCALAR.f64_bits_hex(float(after.get(key))), "qualification_timer_bits_parity:%s" % key)
	if target != null:
		target.free()


static func _test_audit_roundtrip(state: Dictionary, tree: SceneTree, owner: Node) -> void:
	var save := FIXTURE.audit(owner)
	var before := _decoded_payload(save)
	var target := FIXTURE.controller(tree)
	var applied: Dictionary = target.call("apply_save_data", _json_roundtrip(save)) if target != null else {}
	var after := _decoded_payload(target.call("to_save_data") as Dictionary) if target != null else {}
	_expect(state, bool(applied.get("applied", false)) and before.get("audit_roster") == after.get("audit_roster"), "audit_roster_parity")
	_expect(state, SCALAR.f64_bits_hex(float(before.get("audit_remaining_seconds"))) == SCALAR.f64_bits_hex(float(after.get("audit_remaining_seconds"))), "audit_timer_bits_parity")
	_expect(state, (after.get("outcome_receipt", {}) as Dictionary).is_empty(), "audit_restore_does_not_finalize_early")
	if target != null:
		target.free()


static func _test_audit_zero_boundary(state: Dictionary, tree: SceneTree, owner: Node) -> void:
	var save := FIXTURE.audit_zero(owner)
	var payload := _decoded_payload(save)
	_expect(state, float(payload.get("audit_remaining_seconds", -1.0)) == 0.0, "epsilon_boundary_canonicalizes_to_zero")
	_expect(state, (FIXTURE.payload(save).get("audit_remaining_seconds", {}) as Dictionary) == SCALAR.encode_f64(0.0).get("value"), "epsilon_zero_has_canonical_positive_zero_wire")
	var target := FIXTURE.controller(tree)
	var stale_world := FIXTURE.issue_world(target, FIXTURE.world([36, 36], [], 5, [111111, 222222], FIXTURE.POST_SETTLEMENT_CHECKPOINT)) if target != null else {}
	var applied: Dictionary = target.call("apply_save_data", save) if target != null else {}
	var stale: Dictionary = target.call("advance_world_effective", 0.0, stale_world) if target != null else {}
	var fresh_read_only_world := FIXTURE.issue_world(target, FIXTURE.world([36, 36], [], 5, [333333, 222222], "read_only")) if target != null else {}
	var fresh_read_only: Dictionary = target.call("advance_world_effective", 0.0, fresh_read_only_world) if target != null else {}
	var before_final := target.call("outcome_receipt") as Dictionary if target != null else {}
	var fresh_endpoint_world := FIXTURE.issue_world(target, FIXTURE.world([36, 36], [], 5, [333333, 222222])) if target != null else {}
	var fresh_endpoint: Dictionary = target.call("advance_world_effective", 0.0, fresh_endpoint_world) if target != null else {}
	var after_final := target.call("outcome_receipt") as Dictionary if target != null else {}
	_expect(state, bool(applied.get("applied", false)) and str(stale.get("reason", "")) == "awaiting_fresh_world_facts_after_restore", "stale_endpoint_cannot_complete_audit")
	_expect(state, str(fresh_read_only.get("reason", "")) == "awaiting_post_world_settlement_checkpoint" and before_final.is_empty(), "fresh_read_only_snapshot_still_waits_for_settlement")
	_expect(state, str(fresh_endpoint.get("state", "")) == "resolved" and not after_final.is_empty(), "fresh_post_settlement_completes_once")
	if target != null:
		target.free()


static func _test_resolved_roundtrip(state: Dictionary, tree: SceneTree, owner: Node) -> void:
	var save := FIXTURE.resolved(owner)
	var before := _decoded_payload(save)
	var target := FIXTURE.controller(tree)
	var applied: Dictionary = target.call("apply_save_data", _json_roundtrip(save)) if target != null else {}
	var after := _decoded_payload(target.call("to_save_data") as Dictionary) if target != null else {}
	_expect(state, bool(applied.get("applied", false)) and str(after.get("state", "")) == "resolved", "resolved_state_roundtrip")
	_expect(state, before.get("outcome_sequence") == after.get("outcome_sequence"), "outcome_sequence_parity")
	_expect(state, before.get("outcome_receipt") == after.get("outcome_receipt"), "outcome_receipt_parity")
	_expect(state, bool((after.get("outcome_receipt", {}) as Dictionary).get("co_victory", false)), "resolved_co_victory_preserved")
	if target != null:
		target.free()


static func _test_special_roundtrip(state: Dictionary, tree: SceneTree, owner: Node) -> void:
	var save := FIXTURE.special(owner)
	var before := _decoded_payload(save)
	var receipt := before.get("outcome_receipt", {}) as Dictionary
	var evidence := receipt.get("audit_evidence", {}) as Dictionary
	var target := FIXTURE.controller(tree)
	var applied: Dictionary = target.call("apply_save_data", _json_roundtrip(save)) if target != null else {}
	var after := _decoded_payload(target.call("to_save_data") as Dictionary) if target != null else {}
	_expect(state, str(receipt.get("reason_code", "")) == "last_survivor" and str(evidence.get("settlement_checkpoint", "x")) == "", "special_outcome_has_empty_audit_checkpoint")
	_expect(state, bool(applied.get("applied", false)) and before == after, "special_outcome_roundtrip_exact")
	if target != null:
		target.free()


static func _test_fresh_world_facts_gate(state: Dictionary, tree: SceneTree, owner: Node) -> void:
	var save := FIXTURE.audit(owner)
	var target := FIXTURE.controller(tree)
	if target == null:
		_expect(state, false, "fresh_gate_target_missing")
		return
	var stale_world := FIXTURE.issue_world(target, FIXTURE.world([36, 36], [], 5, [777777, 888888], "read_only"))
	target.call("advance_world_effective", 10.0, stale_world)
	var applied: Dictionary = target.call("apply_save_data", save)
	var immediate: Dictionary = target.call("public_snapshot")
	var stale: Dictionary = target.call("advance_world_effective", 0.0, stale_world)
	var stale_public: Dictionary = target.call("public_snapshot")
	var forged_world := stale_world.duplicate(true)
	var forged_ordering := (forged_world.get("ordering_receipt", {}) as Dictionary).duplicate(true)
	forged_ordering["capture_sequence"] = 2
	forged_world["ordering_receipt"] = forged_ordering
	var forged: Dictionary = target.call("advance_world_effective", 0.0, forged_world)
	var fresh_world := FIXTURE.issue_world(target, FIXTURE.world([36, 36], [], 5, [555555, 444444], "read_only"))
	var fresh: Dictionary = target.call("advance_world_effective", 0.0, fresh_world)
	var fresh_public: Dictionary = target.call("public_snapshot")
	_expect(state, bool(applied.get("applied", false)) and not FIXTURE.contains_key_recursive(immediate, "cash_ledger_cents"), "no_public_cash_before_fresh_facts")
	_expect(state, str(stale.get("reason", "")) == "awaiting_fresh_world_facts_after_restore" and not FIXTURE.contains_value_recursive(stale_public, 777777), "stale_snapshot_reuse_blocked")
	_expect(state, str(forged.get("reason", "")) == "awaiting_fresh_world_facts_after_restore", "edited_capture_sequence_cannot_forge_freshness")
	_expect(state, bool(fresh.get("valid", false)) and FIXTURE.contains_value_recursive(fresh_public, 555555) and not FIXTURE.contains_value_recursive(fresh_public, 777777), "fresh_snapshot_rebinds_current_cash_only")
	target.free()


static func _test_outcome_exact_once(state: Dictionary, tree: SceneTree, owner: Node) -> void:
	var qualification_save := FIXTURE.qualification(owner)
	var qualification_before := _decoded_payload(qualification_save).get("qualification_elapsed_by_player", {}) as Dictionary
	var qualification_target := FIXTURE.controller(tree)
	qualification_target.call("apply_save_data", qualification_save)
	qualification_target.call("advance_world_effective", 1.5, FIXTURE.issue_world(qualification_target, FIXTURE.world([36, 36], [36, 36], 5, [10000, 9000], "read_only")))
	var qualification_after := _decoded_payload(qualification_target.call("to_save_data") as Dictionary).get("qualification_elapsed_by_player", {}) as Dictionary
	_expect(state, is_equal_approx(float(qualification_after.get("0", 0.0)), float(qualification_before.get("0", 0.0)) + 1.5), "qualification_delta_applied_once_after_restore")
	qualification_target.free()

	owner.call("reset_state")
	var audit_save := FIXTURE.audit(owner)
	var audit_before := float(_decoded_payload(audit_save).get("audit_remaining_seconds", 0.0))
	var audit_target := FIXTURE.controller(tree)
	audit_target.call("apply_save_data", audit_save)
	audit_target.call("advance_world_effective", 1.25, FIXTURE.issue_world(audit_target, FIXTURE.world([36, 36], [], 5, [10000, 9000], "read_only")))
	var audit_after := float(_decoded_payload(audit_target.call("to_save_data") as Dictionary).get("audit_remaining_seconds", 0.0))
	_expect(state, is_equal_approx(audit_after, audit_before - 1.25), "audit_delta_applied_once_after_restore")
	audit_target.free()

	owner.call("reset_state")
	var resolved_save := FIXTURE.resolved(owner)
	var resolved_target := FIXTURE.controller(tree)
	resolved_target.call("apply_save_data", resolved_save)
	var before := _decoded_payload(resolved_target.call("to_save_data") as Dictionary)
	var advance: Dictionary = resolved_target.call("advance_world_effective", 1.0, FIXTURE.issue_world(resolved_target, FIXTURE.world([36, 36], [36, 36], 5, [10000, 10000])))
	var after := _decoded_payload(resolved_target.call("to_save_data") as Dictionary)
	_expect(state, (advance.get("outcome_receipt", {}) as Dictionary).is_empty() and before == after, "resolved_restore_does_not_redispatch_or_increment")
	resolved_target.free()


static func _test_final_settlement_exact_once(state: Dictionary, tree: SceneTree, owner: Node) -> void:
	var save := FIXTURE.resolved(owner)
	var target := FIXTURE.controller(tree)
	var applied: Dictionary = target.call("apply_save_data", save) if target != null else {}
	var first_world := FIXTURE.issue_world(target, FIXTURE.world([36, 36], [36, 36], 5, [10000, 10000])) if target != null else {}
	var first: Dictionary = target.call("advance_world_effective", 0.0, first_world) if target != null else {}
	var special_world := FIXTURE.issue_world(target, FIXTURE.world([36, 36], [36, 36], 5, [10000, 10000])) if target != null else {}
	var special_retry: Dictionary = target.call("resolve_special_outcome", "planet_destroyed", special_world) if target != null else {}
	var second_world := FIXTURE.issue_world(target, FIXTURE.world([36, 36], [36, 36], 5, [10000, 10000])) if target != null else {}
	var second: Dictionary = target.call("advance_world_effective", 0.0, second_world) if target != null else {}
	_expect(state, bool(applied.get("applied", false)) \
			and (first.get("outcome_receipt", {}) as Dictionary).is_empty() \
			and special_retry.is_empty() \
			and (second.get("outcome_receipt", {}) as Dictionary).is_empty(), "restored_outcome_never_reenters_final_settlement_dispatch")
	_expect(state, int(_decoded_payload(target.call("to_save_data") as Dictionary).get("outcome_sequence", 0)) == 1, "restored_outcome_sequence_not_incremented")
	if target != null:
		target.free()


static func _test_zero_side_effect(state: Dictionary, owner: Node) -> void:
	FIXTURE.audit(owner)
	var save_before: Dictionary = owner.call("to_save_data")
	var debug_before: Dictionary = owner.call("debug_snapshot")
	var first: Dictionary = owner.call("to_save_data")
	var second: Dictionary = owner.call("to_save_data")
	var save_after: Dictionary = owner.call("to_save_data")
	var debug_after: Dictionary = owner.call("debug_snapshot")
	_expect(state, first == second and save_before == save_after, "capture_is_deterministic")
	_expect(state, debug_before == debug_after, "capture_has_zero_owner_mutation")


static func _test_registry_managed_checkpoint(state: Dictionary, owner: Node) -> void:
	var checkpoint_a := FIXTURE.audit(owner)
	owner.call("reset_state")
	FIXTURE.qualification(owner)
	var restored: Dictionary = owner.call("apply_save_data", checkpoint_a)
	var checkpoint_b: Dictionary = owner.call("to_save_data")
	var scene_source := FileAccess.get_file_as_string("res://scenes/runtime/V06SaveOwnerRegistry.tscn")
	var binding_start := scene_source.find('[sub_resource type="Resource" id="BindingVictory"]')
	var binding_end := scene_source.find("[sub_resource", binding_start + 1)
	var binding := scene_source.substr(binding_start, binding_end - binding_start)
	_expect(state, bool(restored.get("applied", false)) and checkpoint_a == checkpoint_b, "registry_managed_checkpoint_a_equals_b")
	_expect(state, binding.contains('rollback_method = "apply_save_data"') and not binding.contains("checkpoint_method"), "victory_keeps_registry_managed_checkpoint_strategy")


static func _test_fault_rollback(state: Dictionary, owner: Node) -> void:
	var checkpoint := FIXTURE.audit(owner)
	var cases: Array[Dictionary] = []
	var bad_state := checkpoint.duplicate(true)
	var bad_state_payload := FIXTURE.payload(bad_state)
	bad_state_payload["state"] = "invalid"
	bad_state["victory_control_runtime"] = bad_state_payload
	cases.append(bad_state)
	var bad_qualification := checkpoint.duplicate(true)
	var bad_qualification_payload := FIXTURE.payload(bad_qualification)
	bad_qualification_payload["qualification_elapsed_by_player"] = {"0": {"codec": SCALAR.F64_CODEC_ID, "bits": "invalid"}}
	bad_qualification["victory_control_runtime"] = bad_qualification_payload
	cases.append(bad_qualification)
	var bad_roster := checkpoint.duplicate(true)
	var bad_roster_payload := FIXTURE.payload(bad_roster)
	bad_roster_payload["audit_roster"] = [0, 0]
	bad_roster["victory_control_runtime"] = bad_roster_payload
	cases.append(bad_roster)
	var bad_timer := checkpoint.duplicate(true)
	var bad_timer_payload := FIXTURE.payload(bad_timer)
	bad_timer_payload["audit_remaining_seconds"] = 5.0
	bad_timer["victory_control_runtime"] = bad_timer_payload
	cases.append(bad_timer)
	var bad_outcome := checkpoint.duplicate(true)
	var bad_outcome_payload := FIXTURE.payload(bad_outcome)
	bad_outcome_payload["outcome_receipt"] = {"unexpected": true}
	bad_outcome["victory_control_runtime"] = bad_outcome_payload
	cases.append(bad_outcome)
	for index in range(cases.size()):
		var before: Dictionary = owner.call("to_save_data")
		var rejected: Dictionary = owner.call("apply_save_data", cases[index])
		_expect(state, not bool(rejected.get("applied", true)) and owner.call("to_save_data") == before, "fault_rejected_without_mutation:%d" % index)
	owner.call("reset_state")
	FIXTURE.qualification(owner)
	var rollback: Dictionary = owner.call("apply_save_data", checkpoint)
	_expect(state, bool(rollback.get("applied", false)) and owner.call("to_save_data") == checkpoint, "fault_matrix_registry_rollback_complete")


static func _decoded_save(save_wire: Dictionary) -> Dictionary:
	var decoded := SAVE_CODEC.decode_save_state(save_wire)
	return (decoded.get("value", {}) as Dictionary).duplicate(true) \
			if bool(decoded.get("ok", false)) else {}


static func _decoded_payload(save_wire: Dictionary) -> Dictionary:
	return FIXTURE.payload(_decoded_save(save_wire))


static func _legacy_victory_v2_envelope(handshake: Node, owner_state: Dictionary) -> Dictionary:
	var manifest: Dictionary = handshake.call("required_section_manifest")
	var versions: Dictionary = handshake.call("required_controller_versions")
	var victory_row := (manifest.get("victory_control", {}) as Dictionary).duplicate(true)
	victory_row["state_version"] = 1
	manifest["victory_control"] = victory_row
	versions["victory_control"] = 1
	var sections: Dictionary = {}
	for section_id_variant in manifest.keys():
		var section_id := str(section_id_variant)
		var row := manifest.get(section_id, {}) as Dictionary
		var state_for_section := owner_state if section_id == "victory_control" else {}
		var encoded: Dictionary = handshake.call("encode_codec_value", state_for_section)
		sections[section_id] = {
			"schema_version": int(row.get("state_version", 0)),
			"owner_id": str(row.get("owner_id", "")),
			"owner_state": encoded.get("value"),
		}
	return {
		"envelope_schema": "space_syndicate.v06.save.v3",
		"save_version": 3,
		"ruleset_id": "v0.6",
		"profile_schema_version": 1,
		"currency_scale": 100,
		"format_id": "space_syndicate_json",
		"codec_id": "explicit_tagged_json_v2",
		"envelope_id": "alpha04c-victory-v2-legacy-envelope",
		"write_id": "alpha04c-victory-v2-legacy-write",
		"controller_state_versions": versions,
		"section_manifest": manifest,
		"sections": sections,
		"migration_policy": "new_session_only",
	}


static func _json_roundtrip(value: Dictionary) -> Dictionary:
	var handshake := HANDSHAKE.new() as RulesetSaveHandshakeService
	var encoded := handshake.encode_codec_value(value)
	var parsed: Variant = JSON.parse_string(JSON.stringify(encoded.get("value")))
	var decoded := handshake.decode_codec_value(parsed)
	handshake.free()
	return (decoded.get("value", {}) as Dictionary).duplicate(true) \
			if bool(decoded.get("ok", false)) and decoded.get("value") is Dictionary else {}


static func _raw_float_count(value: Variant) -> int:
	if value is float:
		return 1
	var count := 0
	if value is Dictionary:
		for child in (value as Dictionary).values():
			count += _raw_float_count(child)
	elif value is Array:
		for child in value as Array:
			count += _raw_float_count(child)
	return count


static func _raw_null_count(value: Variant) -> int:
	if value == null:
		return 1
	var count := 0
	if value is Dictionary:
		for child in (value as Dictionary).values():
			count += _raw_null_count(child)
	elif value is Array:
		for child in value as Array:
			count += _raw_null_count(child)
	return count


static func _expect(state: Dictionary, condition: bool, message: String) -> void:
	state["checks"] = int(state.get("checks", 0)) + 1
	if not condition:
		(state.get("failures", []) as Array).append(message)
