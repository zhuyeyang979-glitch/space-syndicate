extends SceneTree

const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")
const HANDSHAKE_SCENE := preload("res://scenes/runtime/RulesetSaveHandshakeService.tscn")
const PUBLIC_QUERY_SCENE := preload("res://scenes/runtime/presentation/CardHistoryPublicQueryPort.tscn")
const RestoreDependencyContract := preload("res://scripts/runtime/card_history_restore_dependency_contract.gd")
const EXPECTED_ORDER := [
	"ruleset", "region_infrastructure", "region_supply", "commodity_flow", "routes",
	"player_mana", "commodity_belt_visibility", "card_inventory", "player_organization",
	"monsters", "military", "weather", "card_resolution_queue", "card_resolution_execution",
	"card_resolution_history", "ai", "bankruptcy_neutral_estate", "victory_control", "session",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var coordinator := COORDINATOR_SCENE.instantiate()
	root.add_child(coordinator)
	await process_frame
	var history := coordinator.get_node_or_null("CardResolutionHistoryRuntimeService")
	var execution := coordinator.get_node_or_null("CardResolutionExecutionRuntimeService")
	var session := coordinator.get_node_or_null("GameSessionRuntimeController")
	var registry := coordinator.get_node_or_null("GameSessionRuntimeController/V06SaveOwnerRegistry")
	_expect(history != null and execution != null and session != null and registry != null, "formal Coordinator exposes history, execution, session, and registry")
	_expect(coordinator.find_children("CardResolutionHistoryRuntimeService", "", true, false).size() == 1, "formal Coordinator has one history owner instance")
	if history == null or execution == null or session == null or registry == null:
		_finish()
		return
	var handshake := HANDSHAKE_SCENE.instantiate()
	root.add_child(handshake)

	history.configure({"history_limit": 3})
	var empty_state: Dictionary = history.to_save_data()
	_expect(empty_state.keys().size() == 5 and _exact_keys(empty_state, RestoreDependencyContract.HISTORY_STATE_KEYS), "empty capture uses exactly five fields")
	_expect(bool(history.preflight_save_data(empty_state).get("accepted", false)), "empty capture passes pure preflight")
	var before_empty_preflight: Dictionary = history.to_save_data()
	history.preflight_save_data(empty_state)
	_expect(history.to_save_data() == before_empty_preflight, "empty preflight mutates no live history")
	_expect(bool(history.apply_save_data(empty_state).get("applied", false)) and history.to_save_data() == empty_state, "empty state cold-restores exactly")

	var first_append: Dictionary = history.append_resolved(_entry(7, "星链拆解"))
	var second_append: Dictionary = history.append_resolved(_entry(9, "影仓牵引"))
	_expect(bool(first_append.get("appended", false)), "first history entry appends")
	_expect(bool(second_append.get("appended", false)), "second history entry appends")
	_expect(not JSON.stringify(first_append).contains("player_index") and not JSON.stringify(first_append).contains("actor"), "append receipt exposes no authoritative actor")
	var saved: Dictionary = history.to_save_data()
	var saved_text := JSON.stringify(saved)
	_expect(saved.get("appended_resolution_ids", []) == [7, 9], "capture lineage is canonical and matches retained history")
	_expect(not saved_text.contains("PRIVATE_OWNER") and not saved_text.contains("PRIVATE_AI") and not saved_text.contains("guessers"), "capture strips forbidden and retired private fields")
	_expect(saved_text.contains("player_index") and not saved_text.contains("PRIVATE_CASH") and not saved_text.contains("PRIVATE_HAND") and not saved_text.contains("PRIVATE_DISCARD") and not saved_text.contains("PRIVATE_SLOT"), "authoritative history retains player_index while stripping nested private payload")
	var before_preflight: Dictionary = history.to_save_data()
	var accepted: Dictionary = history.preflight_save_data(saved)
	_expect(bool(accepted.get("accepted", false)) and accepted.get("normalized_state", {}) == saved, "nonempty preflight returns the exact normalized state")
	_expect(history.to_save_data() == before_preflight, "nonempty preflight has zero live mutation")
	var encoded_history: Dictionary = handshake.encode_codec_value(accepted.get("normalized_state", {}))
	var decoded_history: Dictionary = handshake.decode_codec_value(encoded_history.get("value"))
	_expect(bool(encoded_history.get("ok", false)) and bool(decoded_history.get("ok", false)) and decoded_history.get("value", {}) == saved, "accepted normalized history roundtrips through the real handshake codec")

	history.reset_state()
	_expect(bool(history.apply_save_data(saved).get("applied", false)), "nonempty state cold-restores")
	_expect(history.to_save_data() == saved, "nonempty cold restore roundtrip is exact")
	_expect((history.history_snapshot() as Array).size() == 2, "cold restore recovers every history entry")
	var public_history_text := JSON.stringify(history.public_history_snapshot())
	_expect(not public_history_text.contains("player_index") and not public_history_text.contains("PRIVATE_"), "public history snapshot hides the authoritative player index and private payload")
	var public_query := PUBLIC_QUERY_SCENE.instantiate()
	root.add_child(public_query)
	public_query.configure(history)
	var public_query_snapshot: Dictionary = public_query.compose_history()
	var public_query_text := JSON.stringify(public_query_snapshot)
	var query_actor_empty := true
	for query_entry_variant in public_query_snapshot.get("entries", []):
		if query_entry_variant is Dictionary and not str((query_entry_variant as Dictionary).get("publicly_revealed_actor", "")).is_empty():
			query_actor_empty = false
	_expect(not public_query_text.contains("player_index") and query_actor_empty, "public query port exposes no authoritative actor")

	_expect(_rejected(history, _with(saved, "history_limit", 0), "history_limit_invalid"), "zero history limit fails closed")
	_expect(_rejected(history, _with(saved, "history_limit", 1), "history_limit_exceeded"), "history beyond limit fails closed")
	_expect(_rejected(history, _with(saved, "revision", -1), "history_revision_invalid"), "negative revision fails closed")
	_expect(_rejected(history, _with(saved, "schema", "wrong"), "history_schema_invalid"), "schema mismatch fails closed")
	var missing_field := saved.duplicate(true)
	missing_field.erase("revision")
	_expect(_rejected(history, missing_field, "history_state_shape_invalid"), "missing top-level field fails closed")
	var extra_field := saved.duplicate(true)
	extra_field["extra"] = true
	_expect(_rejected(history, extra_field, "history_state_shape_invalid"), "extra top-level field fails closed")

	var duplicate_history := saved.duplicate(true)
	(duplicate_history.get("history", []) as Array).append((duplicate_history.get("history", []) as Array)[0].duplicate(true))
	duplicate_history["history_limit"] = 3
	_expect(_rejected(history, duplicate_history, "history_duplicate_resolution"), "duplicate history resolution fails closed")
	_expect(_rejected(history, _with(saved, "appended_resolution_ids", [7, 7]), "history_lineage_invalid"), "duplicate lineage fails closed")
	_expect(_rejected(history, _with(saved, "appended_resolution_ids", [7]), "history_lineage_mismatch"), "missing lineage ID fails closed")
	_expect(_rejected(history, _with(saved, "appended_resolution_ids", [7, 9, 11]), "history_lineage_mismatch"), "extra lineage ID fails closed")
	_expect(_rejected(history, _with(saved, "appended_resolution_ids", ["7", 9]), "history_lineage_invalid"), "non-integer lineage fails closed")
	_expect(_rejected(history, _with(saved, "appended_resolution_ids", [9, 7]), "history_lineage_not_canonical"), "noncanonical lineage order fails closed")
	var malformed_entry := saved.duplicate(true)
	(malformed_entry.get("history", []) as Array)[0] = {"resolution_id": "7"}
	_expect(_rejected(history, malformed_entry, "history_resolution_id_invalid"), "malformed resolution ID fails closed")
	var private_entry := saved.duplicate(true)
	var private_rows := private_entry.get("history", []) as Array
	(private_rows[0] as Dictionary)["owner_truth"] = 2
	_expect(_rejected(history, private_entry, "history_private_field_forbidden"), "forbidden private key fails recursively")
	var nested_private_entry := saved.duplicate(true)
	var nested_private_rows := nested_private_entry.get("history", []) as Array
	(nested_private_rows[0] as Dictionary)["nested_private"] = [{"cash": "PRIVATE_CASH", "hand": ["PRIVATE_HAND"]}, [{"discard": ["PRIVATE_DISCARD"], "private_hand": "PRIVATE_HAND", "slot_index": "PRIVATE_SLOT"}]]
	_expect(_rejected(history, nested_private_entry, "history_private_field_forbidden"), "nested cash, hand, discard, private_hand, and slot_index fail closed")
	var non_string_key := saved.duplicate(true)
	non_string_key[7] = "codec-unsafe-key"
	_expect(_rejected(history, non_string_key, "history_state_not_data_only"), "non-string dictionary key fails the strict codec boundary")
	var string_name_value := saved.duplicate(true)
	var string_name_rows := string_name_value.get("history", []) as Array
	(string_name_rows[0] as Dictionary)["codec_value"] = StringName("codec-unsafe-value")
	_expect(_rejected(history, string_name_value, "history_state_not_data_only"), "StringName value fails the strict codec boundary")
	var object_payload := saved.duplicate(true)
	object_payload["runtime_object"] = RefCounted.new()
	_expect(_rejected(history, object_payload, "history_state_not_data_only"), "Object payload fails before normalization")

	var retired_state := saved.duplicate(true)
	var retired_rows := retired_state.get("history", []) as Array
	(retired_rows[0] as Dictionary)["guessers"] = [0, 1]
	(retired_rows[0] as Dictionary)["nested"] = {"hidden_actor": "retired"}
	var retired_preflight: Dictionary = history.preflight_save_data(retired_state)
	_expect(bool(retired_preflight.get("accepted", false)) and not JSON.stringify(retired_preflight.get("normalized_state", {})).contains("guessers") and not JSON.stringify(retired_preflight.get("normalized_state", {})).contains("hidden_actor"), "retired owner fields normalize away without restoration")

	var before_invalid: Dictionary = history.to_save_data()
	history.apply_save_data(private_entry)
	_expect(history.to_save_data() == before_invalid, "rejected apply is atomic")
	var rollback_checkpoint: Dictionary = history.to_save_data()
	history.append_resolved(_entry(11, "业主透镜"))
	_expect(history.to_save_data() != rollback_checkpoint, "mutation changes the live checkpoint")
	_expect(bool(history.apply_save_data(rollback_checkpoint).get("applied", false)) and history.to_save_data() == rollback_checkpoint, "apply_save_data restores an exact rollback checkpoint")

	var entry_ids := RestoreDependencyContract.history_entry_ids(saved)
	_expect(entry_ids == ["card-history:7", "card-history:9"], "dependency contract derives stable public query IDs")
	var reordered := saved.duplicate(true)
	var first_entry: Dictionary = (reordered.get("history", []) as Array)[0]
	var reordered_entry: Dictionary = {}
	var first_keys: Array = first_entry.keys()
	first_keys.reverse()
	for key_variant in first_keys:
		reordered_entry[key_variant] = first_entry.get(key_variant)
	(reordered.get("history", []) as Array)[0] = reordered_entry
	_expect(RestoreDependencyContract.history_fingerprint(reordered) == RestoreDependencyContract.history_fingerprint(saved), "history fingerprint ignores dictionary insertion order")
	var annotation_checkpoint := {"annotations_by_viewer": {"0": {"card-history:7": {"subscribed": true}}, "1": {"card-history:9": {"note_text": "private"}}}}
	_expect(bool(RestoreDependencyContract.validate_annotation_dependency(annotation_checkpoint, saved).get("accepted", false)), "candidate annotations validate against candidate history without live lookup")
	var expected_fingerprint := RestoreDependencyContract.history_fingerprint(saved)
	var fingerprinted_checkpoint := annotation_checkpoint.duplicate(true)
	fingerprinted_checkpoint["history_fingerprint"] = expected_fingerprint
	var fingerprinted_dependency: Dictionary = RestoreDependencyContract.validate_annotation_dependency(fingerprinted_checkpoint, saved)
	_expect(bool(fingerprinted_dependency.get("accepted", false)) and str(fingerprinted_dependency.get("history_fingerprint", "")) == expected_fingerprint, "optional canonical history fingerprint validates against candidate history")
	var mismatched_checkpoint := annotation_checkpoint.duplicate(true)
	mismatched_checkpoint["history_fingerprint"] = "0".repeat(64)
	var mismatched_dependency: Dictionary = RestoreDependencyContract.validate_annotation_dependency(mismatched_checkpoint, saved)
	_expect(not bool(mismatched_dependency.get("accepted", true)) and str(mismatched_dependency.get("reason_code", "")) == "annotation_history_fingerprint_mismatch" and not mismatched_dependency.has("normalized_state") and not JSON.stringify(mismatched_dependency).contains(expected_fingerprint), "mismatched history fingerprint fails closed without private payload")
	var missing_annotation := {"annotations_by_viewer": {"0": {"card-history:99": {}}}}
	var missing_dependency: Dictionary = RestoreDependencyContract.validate_annotation_dependency(missing_annotation, saved)
	_expect(not bool(missing_dependency.get("accepted", true)) and str(missing_dependency.get("reason_code", "")) == "card_annotation_public_history_missing", "missing annotation history ID fails closed")
	_expect(not bool(RestoreDependencyContract.validate_annotation_dependency({"annotations_by_viewer": {"0": {"card-history:07": {}}}}, saved).get("accepted", true)), "noncanonical annotation history ID fails closed")

	var registry_snapshot: Dictionary = registry.registry_snapshot()
	_expect(registry.fixed_section_order() == EXPECTED_ORDER and EXPECTED_ORDER[-1] == "session", "registry fixed order inserts history after execution and keeps session last")
	_expect(int(registry_snapshot.get("required_section_count", 0)) == 19 and int(registry_snapshot.get("binding_count", 0)) == 19, "registry has nineteen required unique bindings")
	_expect(int(registry_snapshot.get("transactional_section_count", 0)) == 12 and int(registry_snapshot.get("unsupported_section_count", 0)) == 7 and not bool(registry_snapshot.get("resume_ready", true)), "registry remains fail-closed at the 12/7 boundary")
	_expect(_history_binding_valid(registry), "history binding is unique, transactional, and uses explicit preflight")
	_expect(not execution.to_save_data().has("history") and not execution.to_save_data().has("card_resolution_history"), "execution section contains no history copy")
	_expect(not session.to_save_data().has("history") and not session.to_save_data().has("card_resolution_history"), "session section contains no history copy")

	var current_envelope := _compose_envelope(handshake)
	_expect(bool(handshake.validate_envelope(current_envelope).get("valid", false)), "current nineteen-section envelope validates")
	var old_envelope := current_envelope.duplicate(true)
	(old_envelope.get("sections", {}) as Dictionary).erase("card_resolution_history")
	_expect(not bool(handshake.validate_envelope(old_envelope).get("valid", true)), "old eighteen-section envelope fails closed after manifest change")

	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	_expect(not main_source.contains("CardHistoryRestoreDependencyContract") and not main_source.contains("preflight_save_data"), "Stage A adds no Main dependency")
	_expect(not FileAccess.get_file_as_string("res://scripts/runtime/card_resolution_execution_runtime_service.gd").contains('"history": _history'), "execution owner does not duplicate authoritative history content")

	coordinator.queue_free()
	public_query.queue_free()
	handshake.queue_free()
	await process_frame
	_finish()


func _entry(resolution_id: int, card_name: String) -> Dictionary:
	return {
		"resolution_id": resolution_id,
		"player_index": resolution_id % 4,
		"resolved": true,
		"resolved_time": float(resolution_id),
		"skill": {"name": card_name, "kind": "card_counter", "hidden_owner": "PRIVATE_OWNER"},
		"owner_truth": 2,
		"ai_plan": "PRIVATE_AI",
		"nested_private": [{"cash": "PRIVATE_CASH", "hand": ["PRIVATE_HAND"]}, [{"discard": ["PRIVATE_DISCARD"], "private_hand": "PRIVATE_HAND", "slot_index": "PRIVATE_SLOT"}]],
		"guessers": [1],
	}


func _with(source: Dictionary, key: String, value: Variant) -> Dictionary:
	var result := source.duplicate(true)
	result[key] = value
	return result


func _rejected(history: Node, state: Dictionary, reason_code: String) -> bool:
	var before: Dictionary = history.to_save_data()
	var result: Dictionary = history.preflight_save_data(state)
	return not bool(result.get("accepted", true)) and str(result.get("reason_code", "")) == reason_code and history.to_save_data() == before


func _exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key_variant in value.keys():
		if typeof(key_variant) != TYPE_STRING or not expected.has(str(key_variant)):
			return false
	return true


func _history_binding_valid(registry: Node) -> bool:
	var count := 0
	for binding in registry.bindings:
		if binding == null or binding.section_id != "card_resolution_history":
			continue
		count += 1
		if binding.owner_id != "card_resolution_history" \
			or binding.state_version != 1 \
			or str(binding.owner_path) != "../../CardResolutionHistoryRuntimeService" \
			or binding.capture_method != "to_save_data" \
			or binding.preflight_method != "preflight_save_data" \
			or binding.apply_method != "apply_save_data" \
			or binding.rollback_method != "apply_save_data" \
			or binding.restore_mode != "transactional":
			return false
	return count == 1


func _compose_envelope(handshake: Node) -> Dictionary:
	var manifest: Dictionary = handshake.required_section_manifest()
	var domains: Dictionary = {}
	var session: Dictionary = {}
	for section_id_variant in manifest.keys():
		var section_id := str(section_id_variant)
		var contract: Dictionary = manifest.get(section_id, {})
		var encoded: Dictionary = handshake.encode_codec_value({"section_id": section_id})
		var wrapper := {
			"schema_version": int(contract.get("state_version", 0)),
			"owner_id": str(contract.get("owner_id", "")),
			"owner_state": encoded.get("value"),
		}
		if section_id == "session":
			session = wrapper
		else:
			domains[section_id] = wrapper
	return handshake.compose_v06_envelope(session, domains, {"envelope_id": "history-save-owner-test", "write_id": "history-save-owner-test-write"})


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print("CARD_RESOLUTION_HISTORY_SAVE_OWNER_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
