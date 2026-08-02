extends RefCounted
class_name AiRuntimeSaveV3Suite

const FIXTURE := preload("res://tests/ai_runtime_save_v3_fixture.gd")
const AI_CODEC := preload("res://scripts/runtime/ai_runtime_save_wire_codec_v3.gd")
const SCALAR := preload("res://scripts/runtime/closed_save_scalar_codec_v1.gd")
const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")


static func run(tree: SceneTree, focus: String) -> Dictionary:
	var state := {"checks": 0, "failures": []}
	if focus == "wire_codec":
		_test_wire_codec(state)
		return state
	var fixture := await FIXTURE.create(tree)
	_expect(state, bool(fixture.get("ready", false)), "production_fixture_ready")
	if not bool(fixture.get("ready", false)):
		await FIXTURE.close(tree, fixture)
		return state
	var enriched := FIXTURE.enrich(fixture)
	_expect(state, bool(enriched.get("accepted", false)), "nontrivial_typed_state_applied")
	match focus:
		"save_v3":
			_test_save_v3(state, fixture)
		"checkpoint_v2":
			_test_checkpoint_v2(state, fixture)
		"new_session_v3":
			_test_new_session_v3(state, fixture)
		"profile":
			_test_profile_roundtrip(state, fixture)
		"memory":
			_test_memory_roundtrip(state, fixture)
		"learning":
			_test_learning_roundtrip(state, fixture)
		"decision_sample":
			_test_decision_sample_roundtrip(state, fixture)
		"timer":
			_test_timer_parity(state, fixture)
		"legacy":
			_test_legacy_fail_closed(state, fixture)
		"zero_side_effect":
			_test_zero_side_effect(state, fixture)
		"checkpoint_restore":
			_test_checkpoint_restore(state, fixture)
		"fault_rollback":
			_test_fault_rollback(state, fixture)
		"exact_once":
			_test_exact_once(state, fixture)
		_:
			_expect(state, false, "unknown_suite_focus:%s" % focus)
	await FIXTURE.close(tree, fixture)
	return state


static func _test_wire_codec(state: Dictionary) -> void:
	var runtime := _codec_runtime_fixture()
	var encoded := AI_CODEC.encode_save_state(runtime)
	var wire: Dictionary = encoded.get("value", {}) if encoded.get("value", {}) is Dictionary else {}
	var parsed: Variant = JSON.parse_string(JSON.stringify(wire))
	var decoded := AI_CODEC.decode_save_state(parsed as Dictionary if parsed is Dictionary else {})
	_expect(state, bool(encoded.get("ok", false)) and WIRE.is_closed_data(wire), "codec_emits_closed_save_v3")
	_expect(state, _raw_float_count(wire) == 0 and _raw_null_count(wire) == 0, "codec_emits_no_raw_float_or_null")
	_expect(state, bool(decoded.get("ok", false)), "codec_json_decode:%s" % str(decoded.get("reason_code", "none")))
	var canonical := AI_CODEC.encode_save_state(decoded.get("value", {}) as Dictionary) \
			if bool(decoded.get("ok", false)) else {}
	_expect(state, bool(canonical.get("ok", false)) and canonical.get("value") == wire, "codec_json_canonical_wire_roundtrip")
	var timer_tag := wire.get("ai_card_decision_timer", {}) as Dictionary
	_expect(state, timer_tag == SCALAR.encode_f64(runtime.get("ai_card_decision_timer")).get("value"), "codec_reuses_f64_bits_hex_v1")
	var reserved := runtime.duplicate(true)
	((reserved.get("player_states", []) as Array)[0] as Dictionary)["ai_memory"] = {"codec": "collision"}
	_expect(state, not bool(AI_CODEC.encode_save_state(reserved).get("ok", true)), "codec_rejects_reserved_tag_collision")
	var with_null := runtime.duplicate(true)
	((with_null.get("player_states", []) as Array)[0] as Dictionary)["ai_memory"] = {"optional": null}
	_expect(state, not bool(AI_CODEC.encode_save_state(with_null).get("ok", true)), "codec_rejects_unauthorized_null")
	var with_string_name := runtime.duplicate(true)
	((with_string_name.get("player_states", []) as Array)[0] as Dictionary)["ai_memory"] = {"kind": &"private"}
	_expect(state, not bool(AI_CODEC.encode_save_state(with_string_name).get("ok", true)), "codec_rejects_string_name_without_explicit_schema")
	var with_nonstring_key := runtime.duplicate(true)
	((with_nonstring_key.get("player_states", []) as Array)[0] as Dictionary)["ai_memory"] = {1: "forbidden"}
	_expect(state, not bool(AI_CODEC.encode_save_state(with_nonstring_key).get("ok", true)), "codec_rejects_nonstring_dictionary_key")
	var malformed := wire.duplicate(true)
	malformed["ai_card_decision_timer"] = 0.5
	_expect(state, not bool(AI_CODEC.decode_save_state(malformed).get("ok", true)), "codec_rejects_raw_float_wire")


static func _test_save_v3(state: Dictionary, fixture: Dictionary) -> void:
	var ai := fixture.get("ai") as AiRuntimeController
	var save_a := ai.to_save_data()
	var fingerprint_a := WIRE.fingerprint(save_a)
	var parsed: Variant = JSON.parse_string(JSON.stringify(save_a))
	var parsed_save: Dictionary = parsed if parsed is Dictionary else {}
	var preflight := ai.preflight_save_data(parsed_save)
	var raw_a := _decode_save(parsed_save)
	_expect(state, int(raw_a.get("schema_version", 0)) == 3 and WIRE.is_closed_data(save_a), "save_v3_closed_header")
	_expect(state, _raw_float_count(save_a) == 0 and _raw_null_count(save_a) == 0, "save_v3_has_no_raw_float_or_null")
	_expect(state, bool(preflight.get("accepted", false)), "save_v3_json_preflight_green")
	_expect(state, (raw_a.get("player_states", []) as Array).size() == 3, "save_v3_preserves_three_ai_rows")
	_mutate_owner_state(fixture)
	var applied := ai.apply_save_data(parsed_save)
	var save_b := ai.to_save_data()
	_expect(state, bool(applied.get("applied", false)) and save_a == save_b, "save_v3_a_equals_b")
	_expect(state, fingerprint_a == WIRE.fingerprint(save_b), "save_v3_fingerprint_parity")
	_expect(state, _decode_save(save_b) == raw_a, "save_v3_runtime_state_parity")


static func _test_checkpoint_v2(state: Dictionary, fixture: Dictionary) -> void:
	var ai := fixture.get("ai") as AiRuntimeController
	var checkpoint := ai.capture_runtime_checkpoint()
	var decoded := AI_CODEC.decode_runtime_checkpoint(checkpoint)
	var raw := decoded.get("value", {}) as Dictionary
	_expect(state, int(raw.get("schema_version", 0)) == 2 and WIRE.is_closed_data(checkpoint), "runtime_checkpoint_v2_closed")
	_expect(state, _raw_float_count(checkpoint) == 0 and bool(decoded.get("ok", false)), "runtime_checkpoint_v2_decodes")
	_expect(state, (raw.get("actor_state_tick_cache", {}) as Dictionary).is_empty() and not bool(raw.get("actor_state_tick_cache_active", true)), "runtime_checkpoint_cache_canonical")
	_mutate_owner_state(fixture)
	var restored := ai.restore_runtime_checkpoint(checkpoint)
	_expect(state, bool(restored.get("restored", false)) and ai.capture_runtime_checkpoint() == checkpoint, "runtime_checkpoint_v2_a_equals_b")


static func _test_new_session_v3(state: Dictionary, fixture: Dictionary) -> void:
	var ai := fixture.get("ai") as AiRuntimeController
	var checkpoint := ai.capture_new_session_checkpoint()
	var parsed: Variant = JSON.parse_string(JSON.stringify(checkpoint))
	var parsed_checkpoint: Dictionary = parsed if parsed is Dictionary else {}
	var decoded := AI_CODEC.decode_new_session_checkpoint(parsed_checkpoint)
	var raw := decoded.get("value", {}) as Dictionary
	_expect(state, int(raw.get("schema_version", 0)) == 3 and WIRE.is_closed_data(checkpoint), "new_session_checkpoint_v3_closed")
	_expect(state, _raw_float_count(checkpoint) == 0 and bool(decoded.get("ok", false)), "new_session_checkpoint_v3_decodes")
	ai.ai_card_decision_timer = 9.0
	ai.ai_auction_reaction_timer = 8.0
	ai.ai_intel_decision_timer = 7.0
	ai.set("_game_action_request_sequence", 999)
	ai.commit_plan_receipt({"intent_id": "mutated", "action_id": "mutated", "applied": false, "reason": "mutated", "context_revision": 9})
	var restored := ai.restore_new_session_checkpoint(parsed_checkpoint)
	_expect(state, bool(restored.get("restored", false)) and ai.capture_new_session_checkpoint() == checkpoint, "new_session_checkpoint_v3_parity")


static func _test_profile_roundtrip(state: Dictionary, fixture: Dictionary) -> void:
	var ai := fixture.get("ai") as AiRuntimeController
	var save := ai.to_save_data()
	var raw_before := _decode_save(save)
	var profiles_before := _row_field_array(raw_before, "ai_profile")
	_mutate_profiles(fixture)
	var applied := ai.apply_save_data(save)
	var profiles_after := _row_field_array(_decode_save(ai.to_save_data()), "ai_profile")
	_expect(state, bool(applied.get("applied", false)) and profiles_before == profiles_after, "profile_wire_roundtrip_exact")
	_expect(state, _distinct_profile_indices(profiles_after) == 3, "three_profile_identities_preserved")
	_expect(state, WIRE.fingerprint({"profiles": profiles_before}) == WIRE.fingerprint({"profiles": profiles_after}), "profile_fingerprint_parity")


static func _test_memory_roundtrip(state: Dictionary, fixture: Dictionary) -> void:
	var ai := fixture.get("ai") as AiRuntimeController
	var save := ai.to_save_data()
	var memories_before := _row_field_array(_decode_save(save), "ai_memory")
	_mutate_memories(fixture)
	var applied := ai.apply_save_data(save)
	var memories_after := _row_field_array(_decode_save(ai.to_save_data()), "ai_memory")
	_expect(state, bool(applied.get("applied", false)) and memories_before == memories_after, "memory_wire_roundtrip_exact")
	_expect(state, not ((memories_after[0] as Dictionary).get("route_plan_rankings", []) as Array).is_empty(), "route_plan_preserved")
	_expect(state, str((memories_after[0] as Dictionary).get("strategic_intent", "")) == "expand_route", "strategic_intent_preserved")


static func _test_learning_roundtrip(state: Dictionary, fixture: Dictionary) -> void:
	var ai := fixture.get("ai") as AiRuntimeController
	var save := ai.to_save_data()
	var raw_before := _decode_save(save)
	var memory_before := _row_memory(raw_before, 0)
	var learned_before := memory_before.get("learned_policy_values", {}) as Dictionary
	var value_before := float((learned_before.get("action:ordinary_card_purchase", {}) as Dictionary).get("value"))
	_mutate_memories(fixture)
	var applied := ai.apply_save_data(save)
	var memory_after := _row_memory(_decode_save(ai.to_save_data()), 0)
	var learned_after := memory_after.get("learned_policy_values", {}) as Dictionary
	var value_after := float((learned_after.get("action:ordinary_card_purchase", {}) as Dictionary).get("value"))
	_expect(state, bool(applied.get("applied", false)) and SCALAR.f64_bits_hex(value_before) == SCALAR.f64_bits_hex(value_after), "learned_policy_value_bits_parity")
	_expect(state, int(memory_after.get("learning_updates", 0)) == int(memory_before.get("learning_updates", -1)), "learning_counter_parity")


static func _test_decision_sample_roundtrip(state: Dictionary, fixture: Dictionary) -> void:
	var ai := fixture.get("ai") as AiRuntimeController
	var save := ai.to_save_data()
	var samples_before := (_row_memory(_decode_save(save), 0).get("decision_samples", []) as Array).duplicate(true)
	_mutate_memories(fixture)
	var applied := ai.apply_save_data(save)
	var samples_after := (_row_memory(_decode_save(ai.to_save_data()), 0).get("decision_samples", []) as Array).duplicate(true)
	_expect(state, bool(applied.get("applied", false)) and samples_before == samples_after, "decision_sample_full_parity")
	_expect(state, SCALAR.f64_bits_hex(float((samples_before[0] as Dictionary).get("time"))) == SCALAR.f64_bits_hex(float((samples_after[0] as Dictionary).get("time"))), "decision_sample_time_bits_parity")


static func _test_timer_parity(state: Dictionary, fixture: Dictionary) -> void:
	var ai := fixture.get("ai") as AiRuntimeController
	var before := [ai.ai_card_decision_timer, ai.ai_auction_reaction_timer, ai.ai_intel_decision_timer]
	var save := ai.to_save_data()
	var parsed: Variant = JSON.parse_string(JSON.stringify(save))
	ai.ai_card_decision_timer = 9.0
	ai.ai_auction_reaction_timer = 8.0
	ai.ai_intel_decision_timer = 7.0
	var applied := ai.apply_save_data(parsed as Dictionary if parsed is Dictionary else {})
	var after := [ai.ai_card_decision_timer, ai.ai_auction_reaction_timer, ai.ai_intel_decision_timer]
	var parity := bool(applied.get("applied", false))
	for index in range(3):
		parity = parity and SCALAR.f64_bits_hex(float(before[index])) == SCALAR.f64_bits_hex(float(after[index]))
	_expect(state, parity, "all_three_timer_bits_parity_including_sub_0_1_values")


static func _test_legacy_fail_closed(state: Dictionary, fixture: Dictionary) -> void:
	var ai := fixture.get("ai") as AiRuntimeController
	var before := ai.to_save_data()
	var legacy_save := ai._capture_save_runtime_state()
	legacy_save["schema_version"] = 2
	var legacy_copy := legacy_save.duplicate(true)
	var rejected := ai.apply_save_data(legacy_save)
	_expect(state, not bool(rejected.get("applied", true)) and str(rejected.get("reason_code", "")) == "ai_save_v2_closed_wire_upgrade_requires_backup" and bool(rejected.get("requires_backup", false)), "legacy_save_v2_requires_backup")
	_expect(state, legacy_save == legacy_copy and ai.to_save_data() == before, "legacy_save_preserved_without_partial_apply")
	var legacy_checkpoint := {"schema_version": 1}
	var checkpoint_rejected := ai.restore_runtime_checkpoint(legacy_checkpoint)
	var legacy_new_session := {"schema_version": 2}
	var new_session_rejected := ai.restore_new_session_checkpoint(legacy_new_session)
	_expect(state, not bool(checkpoint_rejected.get("restored", true)) and str(checkpoint_rejected.get("reason_code", "")).contains("requires_backup"), "legacy_runtime_checkpoint_v1_rejected")
	_expect(state, not bool(new_session_rejected.get("restored", true)) and str(new_session_rejected.get("reason_code", "")).contains("requires_backup"), "legacy_new_session_checkpoint_v2_rejected")
	var session := fixture.get("session") as GameSessionRuntimeController
	var registry := session.get_node_or_null("V06SaveOwnerRegistry")
	var save_coordinator := session.get_node_or_null("GameSaveRuntimeCoordinator")
	var handshake := session.get_node_or_null("GameSaveRuntimeCoordinator/RulesetSaveHandshakeService")
	var legacy_envelope := _legacy_ai_v2_envelope(handshake)
	var handshake_result: Dictionary = handshake.call("validate_envelope", legacy_envelope) if handshake != null else {}
	var registry_result: Dictionary = registry.call("preflight_envelope", legacy_envelope) if registry != null else {}
	_expect(state, not bool(handshake_result.get("valid", true)) and str(handshake_result.get("reason_code", "")) == "ai_save_v2_closed_wire_upgrade_requires_backup" and bool(handshake_result.get("requires_backup", false)), "legacy_ai_envelope_typed_backup_reason")
	_expect(state, not bool(registry_result.get("ok", true)) and str(registry_result.get("reason_code", "")) == "ai_save_v2_closed_wire_upgrade_requires_backup" and bool(registry_result.get("requires_backup", false)), "registry_propagates_ai_backup_reason")
	var legacy_path := "user://test_runs/alpha04c_ai_save_v2_fail_closed/ai_v2_%d.save" % OS.get_process_id()
	var absolute_directory := ProjectSettings.globalize_path(legacy_path.get_base_dir())
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	var file := FileAccess.open(legacy_path, FileAccess.WRITE) if directory_error == OK else null
	if file != null and handshake != null:
		file.store_string(str(handshake.call("canonical_json", legacy_envelope)))
		file.flush()
		file.close()
	var bytes_before := FileAccess.get_file_as_bytes(legacy_path) if FileAccess.file_exists(legacy_path) else PackedByteArray()
	var readback: Dictionary = save_coordinator.call("read_and_validate", legacy_path) if save_coordinator != null else {}
	var bytes_after := FileAccess.get_file_as_bytes(legacy_path) if FileAccess.file_exists(legacy_path) else PackedByteArray()
	_expect(state, not bytes_before.is_empty() and bytes_after == bytes_before and not bool(readback.get("ok", true)) and str(readback.get("reason_code", "")) == "ai_save_v2_closed_wire_upgrade_requires_backup" and bool(readback.get("requires_backup", false)), "legacy_ai_file_preserved_byte_exact")
	if FileAccess.file_exists(legacy_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy_path))


static func _test_zero_side_effect(state: Dictionary, fixture: Dictionary) -> void:
	var ai := fixture.get("ai") as AiRuntimeController
	var world := fixture.get("world") as WorldSessionState
	var port := fixture.get("port") as AiActorStatePort
	var rng := fixture.get("rng") as RunRngService
	var owner_before := ai._capture_save_runtime_state()
	var world_before := world.to_save_data()
	var port_before := port.debug_snapshot()
	var rng_before := rng.capture_plan_checkpoint()
	var save := ai.to_save_data()
	var checkpoint := ai.capture_runtime_checkpoint()
	_expect(state, not save.is_empty() and not checkpoint.is_empty(), "capture_outputs_present")
	_expect(state, ai._capture_save_runtime_state() == owner_before, "capture_mutates_no_ai_owner_state")
	_expect(state, world.to_save_data() == world_before and port.debug_snapshot() == port_before, "capture_mutates_no_world_or_actor_port")
	_expect(state, rng.capture_plan_checkpoint() == rng_before, "capture_consumes_no_rng")


static func _test_checkpoint_restore(state: Dictionary, fixture: Dictionary) -> void:
	var ai := fixture.get("ai") as AiRuntimeController
	var checkpoint_a := ai.capture_runtime_checkpoint()
	_mutate_owner_state(fixture)
	var restored := ai.restore_runtime_checkpoint(checkpoint_a)
	var checkpoint_b := ai.capture_runtime_checkpoint()
	_expect(state, bool(restored.get("restored", false)) and checkpoint_a == checkpoint_b, "checkpoint_restore_exact_recapture")
	var raw := AI_CODEC.decode_runtime_checkpoint(checkpoint_b).get("value", {}) as Dictionary
	_expect(state, (raw.get("last_receipts", []) as Array).size() == 1, "last_receipts_restore_parity")
	_expect(state, int(raw.get("card_target_pre_submit_rejection_count", -1)) == 2 and int((raw.get("tick_timing_count", {}) as Dictionary).get("runtime_tick", -1)) == 3, "diagnostic_counter_restore_parity")


static func _test_fault_rollback(state: Dictionary, fixture: Dictionary) -> void:
	var ai := fixture.get("ai") as AiRuntimeController
	var baseline_save := ai.to_save_data()
	var baseline_world := (fixture.get("world") as WorldSessionState).to_save_data()
	for row_index in range(3):
		var raw := _decode_save(baseline_save)
		var rows := (raw.get("player_states", []) as Array).duplicate(true)
		var row := (rows[row_index] as Dictionary).duplicate(true)
		var profile := (row.get("ai_profile", {}) as Dictionary).duplicate(true)
		profile.erase("exploration")
		row["ai_profile"] = profile
		rows[row_index] = row
		raw["player_states"] = rows
		var encoded := AI_CODEC.encode_save_state(raw)
		var rejected := ai.apply_save_data(encoded.get("value", {}) as Dictionary)
		_expect(state, not bool(rejected.get("applied", true)) and ai.to_save_data() == baseline_save and (fixture.get("world") as WorldSessionState).to_save_data() == baseline_world, "actor_%d_fault_has_zero_mutation" % (row_index + 1))
	var timer_raw := _decode_save(baseline_save)
	timer_raw["ai_card_decision_timer"] = -0.01
	var timer_wire := AI_CODEC.encode_save_state(timer_raw)
	_expect(state, not bool(ai.apply_save_data(timer_wire.get("value", {}) as Dictionary).get("applied", true)) and ai.to_save_data() == baseline_save, "timer_fault_has_zero_mutation")
	var checkpoint := ai.capture_runtime_checkpoint()
	var checkpoint_raw := AI_CODEC.decode_runtime_checkpoint(checkpoint).get("value", {}) as Dictionary
	checkpoint_raw["last_receipts"] = [{"invalid": true}]
	var checkpoint_wire := AI_CODEC.encode_runtime_checkpoint(checkpoint_raw)
	_expect(state, not bool(ai.restore_runtime_checkpoint(checkpoint_wire.get("value", {}) as Dictionary).get("restored", true)) and ai.to_save_data() == baseline_save, "receipt_fault_has_zero_mutation")
	ai.set("_actor_state_tick_cache_active", true)
	_expect(state, ai.capture_runtime_checkpoint().is_empty(), "active_tick_cache_blocks_checkpoint_capture")
	ai.set("_actor_state_tick_cache_active", false)
	ai.set("_actor_state_tick_cache", {})


static func _test_exact_once(state: Dictionary, fixture: Dictionary) -> void:
	var ai := fixture.get("ai") as AiRuntimeController
	var world := fixture.get("world") as WorldSessionState
	var save := ai.to_save_data()
	var raw_before := _decode_save(save)
	var cash_before := _cash_vector(world)
	var first := ai.apply_save_data(save)
	var second := ai.apply_save_data(save)
	var raw_after := _decode_save(ai.to_save_data())
	_expect(state, bool(first.get("applied", false)) and bool(second.get("applied", false)), "idempotent_restore_applies")
	_expect(state, raw_after == raw_before, "repeated_restore_adds_no_sample_or_learning_update")
	_expect(state, int(raw_after.get("request_sequence", -1)) == 19, "request_sequence_does_not_regress")
	_expect(state, _cash_vector(world) == cash_before, "repeated_restore_debits_no_business_cost")


static func _mutate_owner_state(fixture: Dictionary) -> void:
	_mutate_profiles(fixture)
	_mutate_memories(fixture)
	var ai := fixture.get("ai") as AiRuntimeController
	ai.ai_card_decision_timer = 9.0
	ai.ai_auction_reaction_timer = 8.0
	ai.ai_intel_decision_timer = 7.0
	ai.set("_game_action_request_sequence", 999)
	ai.commit_plan_receipt({"intent_id": "mutated", "action_id": "mutated", "applied": false, "reason": "mutated", "context_revision": 99})
	ai.set("_card_target_pre_submit_rejection_count", 99)
	ai.set("_tick_timing_count", {"mutated": 99})
	ai.set("_tick_timing_total_usec", {"mutated": 99})
	ai.set("_tick_timing_max_usec", {"mutated": 99})
	ai.set("_actor_state_tick_cache_hit_count", 99)
	ai.set("_actor_state_tick_cache_miss_count", 99)


static func _mutate_profiles(fixture: Dictionary) -> void:
	var port := fixture.get("port") as AiActorStatePort
	var capability := fixture.get("capability") as AiActorStateCapability
	var capture := port.capture_ai_state_batch_for_save(capability, true)
	var rows := (capture.get("rows", []) as Array).duplicate(true)
	for index in range(rows.size()):
		var row := rows[index] as Dictionary
		var profile := (row.get("ai_profile", {}) as Dictionary).duplicate(true)
		profile["build_bias"] = float(profile.get("build_bias", 1.0)) + 0.125
		row["ai_profile"] = profile
		rows[index] = row
	port.apply_ai_state_batch_for_restore(capability, rows)


static func _mutate_memories(fixture: Dictionary) -> void:
	var port := fixture.get("port") as AiActorStatePort
	var capability := fixture.get("capability") as AiActorStateCapability
	var capture := port.capture_ai_state_batch_for_save(capability, true)
	var rows := (capture.get("rows", []) as Array).duplicate(true)
	for index in range(rows.size()):
		var row := rows[index] as Dictionary
		var memory := (row.get("ai_memory", {}) as Dictionary).duplicate(true)
		memory["decision_samples"] = []
		memory["action_counts"] = {}
		memory["learned_policy_values"] = {}
		memory["learning_updates"] = 0
		memory["strategic_intent"] = "mutated"
		memory["route_plan_stage"] = "mutated"
		row["ai_memory"] = memory
		rows[index] = row
	port.apply_ai_state_batch_for_restore(capability, rows)


static func _codec_runtime_fixture() -> Dictionary:
	return {
		"schema_version": 3,
		"ruleset_id": "v0.6",
		"policy_profile_id": "fixture-policy",
		"policy_fingerprint": "a".repeat(64),
		"request_sequence": 17,
		"ai_card_decision_timer": 0.0123456789012345,
		"ai_auction_reaction_timer": 0.0345678901234567,
		"ai_intel_decision_timer": 4.56789012345678,
		"ai_card_decision_enabled": true,
		"player_states": [{
			"player_index": 1,
			"ai_profile": {"exploration": 0.123456789012345, "route_preferences": {"route": 1.125}},
			"ai_memory": {"decision_samples": [{"time": 7.125}], "learned_policy_values": {"tag": {"value": -0.0}}},
		}],
	}


static func _legacy_ai_v2_envelope(handshake: Node) -> Dictionary:
	if handshake == null:
		return {}
	var manifest: Dictionary = handshake.call("required_section_manifest")
	var versions: Dictionary = handshake.call("required_controller_versions")
	var ai_row := (manifest.get("ai", {}) as Dictionary).duplicate(true)
	ai_row["state_version"] = 2
	manifest["ai"] = ai_row
	versions["ai_runtime"] = 2
	var sections: Dictionary = {}
	for section_id_variant in manifest.keys():
		var section_id := str(section_id_variant)
		var row := manifest.get(section_id, {}) as Dictionary
		var owner_state := {"schema_version": 2, "ruleset_id": "v0.6"} \
				if section_id == "ai" else {}
		var encoded: Dictionary = handshake.call("encode_codec_value", owner_state)
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
		"envelope_id": "alpha04c-ai-v2-legacy-envelope",
		"write_id": "alpha04c-ai-v2-legacy-write",
		"controller_state_versions": versions,
		"section_manifest": manifest,
		"sections": sections,
		"migration_policy": "new_session_only",
	}


static func _decode_save(wire: Dictionary) -> Dictionary:
	var decoded := AI_CODEC.decode_save_state(wire)
	return (decoded.get("value", {}) as Dictionary).duplicate(true) \
			if bool(decoded.get("ok", false)) else {}


static func _row_field_array(raw: Dictionary, field: String) -> Array:
	var result: Array = []
	for row_variant in raw.get("player_states", []) as Array:
		result.append(((row_variant as Dictionary).get(field, {}) as Dictionary).duplicate(true))
	return result


static func _row_memory(raw: Dictionary, row_index: int) -> Dictionary:
	var rows := raw.get("player_states", []) as Array
	if row_index < 0 or row_index >= rows.size():
		return {}
	return (((rows[row_index] as Dictionary).get("ai_memory", {}) as Dictionary).duplicate(true))


static func _distinct_profile_indices(profiles: Array) -> int:
	var indices: Dictionary = {}
	for profile_variant in profiles:
		indices[int((profile_variant as Dictionary).get("profile_index", -1))] = true
	return indices.size()


static func _cash_vector(world: WorldSessionState) -> Array:
	var result: Array = []
	for player_variant in world.players:
		result.append(int((player_variant as Dictionary).get("cash_cents", 0)))
	return result


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


static func _expect(state: Dictionary, condition: bool, label: String) -> void:
	state["checks"] = int(state.get("checks", 0)) + 1
	if not condition:
		(state.get("failures", []) as Array).append(label)
