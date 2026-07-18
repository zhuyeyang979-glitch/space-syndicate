@tool
extends Node
class_name SessionEnvelopeSaveOwnerBench

const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")
const RESTORE_CONTRACT := preload("res://scripts/runtime/card_history_restore_dependency_contract.gd")
const RULESET_PROFILE := preload("res://resources/rules/space_syndicate_ruleset_v06.tres")
const EXPECTED_FIXED_ORDER := [
	"ruleset",
	"region_infrastructure",
	"region_supply",
	"commodity_flow",
	"routes",
	"player_mana",
	"commodity_belt_visibility",
	"card_inventory",
	"player_organization",
	"monsters",
	"military",
	"weather",
	"card_resolution_queue",
	"card_resolution_execution",
	"card_resolution_history",
	"ai",
	"bankruptcy_neutral_estate",
	"victory_control",
	"session",
]

@export var auto_run_on_ready := true

var _checks := 0
var _failures: Array[String] = []
var _cold_history_before := -1
var _cold_annotations_before := -1
var _cold_history_after := -1
var _cold_annotations_after := -1


func _ready() -> void:
	if auto_run_on_ready and not Engine.is_editor_hint():
		call_deferred("_run_from_scene")


func _run_from_scene() -> void:
	var result := run_bench()
	print("SESSION_ENVELOPE_SAVE_OWNER_BENCH|status=%s|checks=%d|failures=%d|details=%s|evidence=%s" % [
		"PASS" if bool(result.get("passed", false)) else "FAIL",
		int(result.get("checks", 0)),
		int(result.get("failure_count", 0)),
		JSON.stringify(result.get("failures", [])),
		JSON.stringify(result.get("evidence", {})),
	])
	if not bool(result.get("passed", false)):
		push_error("Session envelope save owner Bench failed: %s" % JSON.stringify(result.get("failures", [])))


func run_bench() -> Dictionary:
	_checks = 0
	_failures.clear()
	_cold_history_before = -1
	_cold_annotations_before = -1
	_cold_history_after = -1
	_cold_annotations_after = -1

	var runtime_a := _create_runtime("RuntimeA")
	_check(runtime_a != null, "cold_runtime_a_created")
	if runtime_a == null:
		return _finish()
	var world_a := runtime_a.world_session_state()
	var session_a := runtime_a.get_node_or_null("GameSessionRuntimeController") as GameSessionRuntimeController
	var owner_a := session_a.get_node_or_null("SessionEnvelopeSaveOwner") as SessionEnvelopeSaveOwner if session_a != null else null
	var registry_a := session_a.get_node_or_null("V06SaveOwnerRegistry") as V06SaveOwnerRegistry if session_a != null else null
	var history_a := runtime_a.get_node_or_null("CardResolutionHistoryRuntimeService") as CardResolutionHistoryRuntimeService
	var annotations_a := runtime_a.get_node_or_null("CardHistoryPrivateAnnotationService") as CardHistoryPrivateAnnotationService
	_check(world_a != null and session_a != null and owner_a != null and registry_a != null and history_a != null and annotations_a != null, "runtime_a_production_composition_ready")
	if world_a == null or session_a == null or owner_a == null or registry_a == null or history_a == null or annotations_a == null:
		runtime_a.free()
		return _finish()

	_test_registry_contract(registry_a)
	_seed_public_history(history_a)
	_seed_session(runtime_a, world_a, session_a, annotations_a)
	var history_state := history_a.to_save_data()
	var capture_before := owner_a.to_save_data()
	var notification_before := int(annotations_a.debug_snapshot().get("notification_count", -1))
	var capture := owner_a.capture_composite_state()
	var session_state: Dictionary = capture.get("state", {}) if capture.get("state", {}) is Dictionary else {}
	_check(bool(capture.get("captured", false)) and int(session_state.get("schema_version", 0)) == 2, "composite_capture_returns_session_v2:%s" % str(capture.get("reason_code", "missing_reason")))
	_check(owner_a.to_save_data() == capture_before and int(annotations_a.debug_snapshot().get("notification_count", -2)) == notification_before, "capture_mutates_zero_child_owners")
	_check(_pure_data(history_state) and _pure_data(session_state), "history_and_session_capture_are_pure_data")
	_test_dependency_contract(history_state, session_state.get("card_history_private_annotations", {}) as Dictionary)

	# The source runtime is destroyed before any restore assertion. Runtime B has no
	# inherited history, annotation cache, subscription fingerprint, or session state.
	runtime_a.free()
	var runtime_b := _create_runtime("RuntimeB")
	_check(runtime_b != null, "cold_runtime_b_created_after_runtime_a_destroyed")
	if runtime_b == null:
		return _finish()
	var world_b := runtime_b.world_session_state()
	var session_b := runtime_b.get_node_or_null("GameSessionRuntimeController") as GameSessionRuntimeController
	var owner_b := session_b.get_node_or_null("SessionEnvelopeSaveOwner") as SessionEnvelopeSaveOwner if session_b != null else null
	var history_b := runtime_b.get_node_or_null("CardResolutionHistoryRuntimeService") as CardResolutionHistoryRuntimeService
	var annotations_b := runtime_b.get_node_or_null("CardHistoryPrivateAnnotationService") as CardHistoryPrivateAnnotationService
	_check(world_b != null and session_b != null and owner_b != null and history_b != null and annotations_b != null, "runtime_b_production_composition_ready")
	if world_b == null or session_b == null or owner_b == null or history_b == null or annotations_b == null:
		runtime_b.free()
		return _finish()
	_cold_history_before = history_b.history_snapshot().size()
	_cold_annotations_before = _annotation_count(annotations_b, 4)
	_check(_cold_history_before == 0 and _cold_annotations_before == 0, "cold_runtime_starts_without_history_or_annotations")

	var structural_preflight: Dictionary = owner_b.preflight_save_data(session_state)
	_check(bool(structural_preflight.get("accepted", false)) and not bool(annotations_b.debug_snapshot().get("preflight_reads_live_history", true)), "session_structural_preflight_does_not_query_empty_live_history")
	var before_wrong_order := owner_b.to_save_data()
	var wrong_order: Dictionary = owner_b.apply_save_data(session_state)
	_check(not bool(wrong_order.get("applied", true)) and str(wrong_order.get("reason_code", "")) == "card_annotation_public_history_missing", "session_apply_before_history_fails_defensively")
	_check(owner_b.to_save_data() == before_wrong_order and history_b.history_snapshot().is_empty(), "wrong_restore_order_rolls_back_without_residual_state")

	var history_apply: Dictionary = history_b.apply_save_data(history_state)
	_check(bool(history_apply.get("applied", false)), "public_history_restores_before_private_annotations")
	var restored: Dictionary = owner_b.apply_save_data(session_state)
	_check(bool(restored.get("applied", false)), "session_and_private_annotations_restore_after_public_history")
	_cold_history_after = history_b.history_snapshot().size()
	_cold_annotations_after = _annotation_count(annotations_b, 4)
	_check(_cold_history_after == 3 and _cold_annotations_after == 4, "cold_restore_recovers_all_history_and_private_annotation_rows")
	_check(history_b.to_save_data() == history_state and owner_b.to_save_data() == session_state, "cold_restore_recaptures_semantically_identical_states")
	_check(_city_intel_roundtrip(world_b), "city_guess_confidence_and_reason_roundtrip")
	_check(_annotation_roundtrip(annotations_b), "private_annotations_subscriptions_and_role_usage_roundtrip")
	_check((annotations_b.viewer_snapshot(1).get("annotations", []) as Array).size() == 1 and not JSON.stringify(annotations_b.viewer_snapshot(1)).contains("viewer-zero-note"), "viewer_private_annotations_remain_isolated")
	_check(int(annotations_b.debug_snapshot().get("notification_count", -1)) == 0, "restore_rebuilds_subscriptions_without_notifications")
	_check(not JSON.stringify(history_b.public_history_snapshot()).contains("viewer-zero-note"), "public_history_contains_no_private_annotation")
	_check(not JSON.stringify(annotations_b.viewer_snapshot(0)).contains("hidden_actor"), "restored_annotation_contains_no_hidden_actor")
	_check(int(annotations_b.debug_snapshot().get("economic_reward_count", -1)) == 0 and int(annotations_b.debug_snapshot().get("gdp_reward_count", -1)) == 0, "restore_creates_no_card_history_cash_or_gdp_reward")

	_test_fault_matrix(owner_b)
	_test_strict_corruption_matrix(owner_b, session_state)
	_test_v1_policy(owner_b, session_b)
	_test_load_classification_and_active_session_isolation(runtime_b, world_b, session_b, annotations_b)
	_test_main_v3_load_boundary()
	runtime_b.free()
	return _finish()


func _create_runtime(runtime_name: String) -> GameRuntimeCoordinator:
	var coordinator := COORDINATOR_SCENE.instantiate() as GameRuntimeCoordinator
	if coordinator == null:
		return null
	coordinator.name = runtime_name
	add_child(coordinator)
	var session := coordinator.get_node_or_null("GameSessionRuntimeController") as GameSessionRuntimeController
	var history := coordinator.get_node_or_null("CardResolutionHistoryRuntimeService") as CardResolutionHistoryRuntimeService
	if session != null:
		session.set_world_effective_clock(coordinator.get_node_or_null("WorldEffectiveClockRuntimeController"))
		session.configure({"ruleset_id": RULESET_PROFILE.ruleset_id})
	if history != null:
		history.configure({"history_limit": 24})
	return coordinator


func _test_registry_contract(registry: V06SaveOwnerRegistry) -> void:
	var snapshot := registry.registry_snapshot()
	var fixed_order := registry.fixed_section_order()
	var session_bindings := 0
	var history_bindings := 0
	var session_binding_ok := false
	var history_binding_ok := false
	var forbidden_sections := 0
	for binding in registry.bindings:
		if binding == null:
			continue
		if binding.section_id in ["intel", "world_session", "card_annotations"]:
			forbidden_sections += 1
		if binding.section_id == "session":
			session_bindings += 1
			session_binding_ok = binding.owner_id == "game_session" \
				and binding.state_version == 2 \
				and str(binding.owner_path) == "../SessionEnvelopeSaveOwner" \
				and binding.preflight_method == "preflight_save_data" \
				and binding.restore_mode == V06SaveOwnerBindingResource.RESTORE_TRANSACTIONAL
		elif binding.section_id == "card_resolution_history":
			history_bindings += 1
			history_binding_ok = binding.owner_id == "card_resolution_history" \
				and binding.state_version == 1 \
				and str(binding.owner_path) == "../../CardResolutionHistoryRuntimeService" \
				and binding.preflight_method == "preflight_save_data" \
				and binding.restore_mode == V06SaveOwnerBindingResource.RESTORE_TRANSACTIONAL
	_check(int(snapshot.get("required_section_count", 0)) == 19 and int(snapshot.get("binding_count", 0)) == 19, "registry_retains_exactly_19_sections")
	_check(fixed_order == EXPECTED_FIXED_ORDER and fixed_order[-1] == "session", "fixed_order_has_history_before_last_session")
	_check(fixed_order.find("card_resolution_execution") + 1 == fixed_order.find("card_resolution_history"), "execution_immediately_precedes_history")
	_check(fixed_order.find("card_resolution_history") < fixed_order.find("session"), "history_precedes_session")
	_check(session_bindings == 1 and session_binding_ok, "session_has_one_transactional_v2_composite_binding")
	_check(history_bindings == 1 and history_binding_ok, "history_has_one_authoritative_transactional_binding")
	_check(forbidden_sections == 0 and int(snapshot.get("transactional_section_count", 0)) == 12 and int(snapshot.get("unsupported_section_count", 0)) == 7 and not bool(snapshot.get("resume_ready", true)), "no_new_private_section_and_full_resume_stays_fail_closed")
	_check(not bool(registry.debug_snapshot().get("cross_section_preflight_reads_live_owners", true)), "registry_cross_section_preflight_uses_normalized_envelope_data_only")


func _seed_public_history(history: CardResolutionHistoryRuntimeService) -> void:
	history.reset_state()
	for index in range(3):
		var receipt := history.append_resolved({
			"resolution_id": 70 + index,
			"resolved_time": 20.0 + index,
			"selected_district": index,
			"resolved": true,
			"aftermath_clue": "公开余波%d" % index,
			"skill": {"name": "公开牌%d" % index, "display_name": "公开牌%d" % index, "kind": "card_counter"},
		})
		_check(bool(receipt.get("appended", false)), "public_history_entry_%d_ready" % index)


func _seed_session(coordinator: GameRuntimeCoordinator, world: WorldSessionState, session: GameSessionRuntimeController, annotations: CardHistoryPrivateAnnotationService) -> void:
	var role_catalog := coordinator.get_node_or_null("RoleCatalogRuntimeService") as RoleCatalogRuntimeService
	world.restore({
		"players": _players_fixture(role_catalog),
		"districts": _districts_fixture(),
		"game_time": 47.5,
		"map_width_m": 1400.0,
		"map_height_m": 950.0,
		"world_geometry_revision": 9,
	}, true)
	session.begin_session({"session_id": "session-envelope-bench", "scenario_id": "qa", "seed": 42, "player_count": 4, "ai_player_count": 3, "difficulty": "standard", "mission_title": "事务验收"})
	annotations.reset_state()
	_check(bool(annotations.apply_annotation(0, "card-history:70", {
		"note_text": "viewer-zero-note",
		"private_tags": ["复盘"],
		"suspected_player_indices": [2],
		"private_confidence": 2,
		"subscribed": true,
	}).get("applied", false)), "viewer_zero_annotation_seeded")
	_check(bool(annotations.apply_annotation(1, "card-history:71", {
		"note_text": "viewer-one-note",
		"private_tags": ["航线"],
		"suspected_player_indices": [0, 3],
		"private_confidence": 1,
		"subscribed": true,
	}).get("applied", false)), "viewer_one_annotation_seeded")
	_check(bool(annotations.use_residual_catalog_role(2, "card-history:72", [0, 1, 3], 2).get("applied", false)), "residual_catalog_usage_seeded")
	annotations.apply_annotation(3, "card-history:70", {"suspected_player_indices": [0, 1, 2], "private_confidence": 1})
	_check(bool(annotations.use_public_exclusion_role(3, "card-history:70", [1], 3).get("applied", false)), "public_exclusion_usage_seeded")


func _test_dependency_contract(history_state: Dictionary, annotation_state: Dictionary) -> void:
	var history_before := history_state.duplicate(true)
	var annotation_before := annotation_state.duplicate(true)
	var valid: Dictionary = RESTORE_CONTRACT.validate_annotation_dependency(annotation_state, history_state)
	_check(bool(valid.get("accepted", false)) and str(valid.get("history_fingerprint", "")).length() == 64, "captured_history_and_annotations_pass_pure_dependency_contract")
	var missing := annotation_state.duplicate(true)
	var missing_rows: Dictionary = missing.get("annotations_by_viewer", {})
	var viewer_rows: Dictionary = missing_rows.get("0", {})
	viewer_rows["card-history:999"] = (viewer_rows.get("card-history:70", {}) as Dictionary).duplicate(true)
	missing_rows["0"] = viewer_rows
	missing["annotations_by_viewer"] = missing_rows
	var missing_result: Dictionary = RESTORE_CONTRACT.validate_annotation_dependency(missing, history_state)
	_check(not bool(missing_result.get("accepted", true)) and str(missing_result.get("reason_code", "")) == "card_annotation_public_history_missing", "missing_annotation_reference_fails_cross_section_preflight")
	var mismatch := annotation_state.duplicate(true)
	mismatch["history_fingerprint"] = "0".repeat(64)
	var mismatch_result: Dictionary = RESTORE_CONTRACT.validate_annotation_dependency(mismatch, history_state)
	_check(not bool(mismatch_result.get("accepted", true)) and str(mismatch_result.get("reason_code", "")) == "annotation_history_fingerprint_mismatch", "history_dependency_fingerprint_mismatch_fails_closed")
	_check(history_state == history_before and annotation_state == annotation_before, "dependency_preflight_mutates_zero_captured_state")


func _test_fault_matrix(owner: SessionEnvelopeSaveOwner) -> void:
	for stage in owner.TEST_FAULT_STAGES:
		var before := owner.to_save_data()
		var candidate := before.duplicate(true)
		var world_state: Dictionary = candidate.get("world_session_state", {})
		world_state["game_time"] = float(world_state.get("game_time", 0.0)) + 3.0
		candidate["world_session_state"] = world_state
		_check(owner.arm_test_fault_once(stage), "fault_stage_%s_arms" % stage)
		var receipt: Dictionary = owner.apply_save_data(candidate)
		_check(not bool(receipt.get("applied", true)) and bool(receipt.get("rollback_complete", false)), "fault_stage_%s_fails_and_rolls_back" % stage)
		_check(owner.to_save_data() == before, "fault_stage_%s_leaves_no_partial_state" % stage)


func _test_strict_corruption_matrix(owner: SessionEnvelopeSaveOwner, captured: Dictionary) -> void:
	if captured.is_empty():
		_check(false, "corruption_matrix_requires_captured_session_v2")
		return
	var cases: Array[Dictionary] = []
	var missing_player_field := captured.duplicate(true)
	var missing_players: Array = (missing_player_field.get("world_session_state", {}) as Dictionary).get("players", [])
	(missing_players[0] as Dictionary).erase("cash_cents")
	cases.append({"id": "missing_player_field", "state": missing_player_field})
	var duplicate_player := captured.duplicate(true)
	var duplicate_players: Array = (duplicate_player.get("world_session_state", {}) as Dictionary).get("players", [])
	(duplicate_players[1] as Dictionary)["id"] = 0
	cases.append({"id": "duplicate_player_id", "state": duplicate_player})
	var role_mismatch := captured.duplicate(true)
	var role_players: Array = (role_mismatch.get("world_session_state", {}) as Dictionary).get("players", [])
	((role_players[0] as Dictionary).get("role_card", {}) as Dictionary)["name"] = "错误角色"
	cases.append({"id": "role_catalog_mismatch", "state": role_mismatch})
	var bad_confidence := captured.duplicate(true)
	var confidence_players: Array = (bad_confidence.get("world_session_state", {}) as Dictionary).get("players", [])
	var records: Array = (confidence_players[0] as Dictionary).get("city_intel_records", [])
	(records[0] as Dictionary)["confidence"] = 77
	cases.append({"id": "invalid_confidence", "state": bad_confidence})
	var missing_district_field := captured.duplicate(true)
	var missing_districts: Array = (missing_district_field.get("world_session_state", {}) as Dictionary).get("districts", [])
	(missing_districts[0] as Dictionary).erase("hp")
	cases.append({"id": "missing_district_field", "state": missing_district_field})
	var duplicate_region := captured.duplicate(true)
	var duplicate_districts: Array = (duplicate_region.get("world_session_state", {}) as Dictionary).get("districts", [])
	(duplicate_districts[1] as Dictionary)["region_id"] = "region.000"
	cases.append({"id": "duplicate_region_id", "state": duplicate_region})
	for case in cases:
		var before := owner.to_save_data()
		var receipt: Dictionary = owner.preflight_save_data(case.get("state", {}) as Dictionary)
		_check(not bool(receipt.get("accepted", true)), "corrupt_%s_fails_in_preflight" % str(case.get("id", "unknown")))
		_check(owner.to_save_data() == before, "corrupt_%s_mutates_zero_state" % str(case.get("id", "unknown")))
	var object_case := captured.duplicate(true)
	var object_players: Array = (object_case.get("world_session_state", {}) as Dictionary).get("players", [])
	var forbidden_object := Node.new()
	(object_players[0] as Dictionary)["forbidden_object"] = forbidden_object
	var object_before := owner.to_save_data()
	var object_receipt: Dictionary = owner.preflight_save_data(object_case)
	_check(not bool(object_receipt.get("accepted", true)) and owner.to_save_data() == object_before, "object_payload_fails_without_live_mutation")
	forbidden_object.free()


func _test_v1_policy(owner: SessionEnvelopeSaveOwner, session: GameSessionRuntimeController) -> void:
	var active_v1 := {"game_session_runtime": (session.to_save_data().get("game_session_runtime", {}) as Dictionary).duplicate(true)}
	var active_result := owner.preflight_save_data(active_v1)
	_check(not bool(active_result.get("accepted", true)) and str(active_result.get("reason_code", "")) == "session_v1_world_state_missing" and bool(active_result.get("requires_backup", false)), "active_session_v1_fails_closed_and_requires_backup")
	var idle_payload := (active_v1.get("game_session_runtime", {}) as Dictionary).duplicate(true)
	idle_payload["session_state"] = "idle"
	idle_payload["session_id"] = ""
	idle_payload["setup"] = {}
	idle_payload["outcome_receipt"] = {}
	var idle_result := owner.preflight_save_data({"game_session_runtime": idle_payload})
	_check(bool(idle_result.get("accepted", false)) and str(idle_result.get("reason_code", "")) == "session_v1_idle_migrated", "empty_idle_session_v1_migrates_without_fake_players")
	var migrated_world: Dictionary = (idle_result.get("normalized_state", {}) as Dictionary).get("world_session_state", {})
	_check((migrated_world.get("players", []) as Array).is_empty() and (migrated_world.get("districts", []) as Array).is_empty(), "idle_v1_migration_creates_no_fake_world")


func _test_load_classification_and_active_session_isolation(coordinator: GameRuntimeCoordinator, world: WorldSessionState, session: GameSessionRuntimeController, annotations: CardHistoryPrivateAnnotationService) -> void:
	const CURRENT_PATH := "user://test_runs/session_envelope_owner/high_level_load.save"
	const LEGACY_V1_PATH := "user://test_runs/session_envelope_owner/legacy_v1.save"
	const PREVIOUS_V06_PATH := "user://test_runs/session_envelope_owner/previous_v06.save"
	var save := session.get_node_or_null("GameSaveRuntimeCoordinator")
	var handshake := save.get_node_or_null("RulesetSaveHandshakeService") if save != null else null
	_check(save != null and handshake != null, "production_load_transport_and_handshake_present")
	if save == null or handshake == null:
		return
	var legacy_v1: Dictionary = handshake.call("inspect_envelope", {"version": 1})
	var legacy_v2: Dictionary = handshake.call("inspect_envelope", {"save_version": 2, "ruleset_id": "v0.5"})
	_check(str(legacy_v1.get("classification", "")) == "legacy_v1" and str(legacy_v1.get("reason_code", "")) == "legacy_resume_forbidden" and bool(legacy_v1.get("requires_backup", false)), "legacy_v1_classifies_before_v06_validation")
	_check(str(legacy_v2.get("classification", "")) == "legacy_v2" and str(legacy_v2.get("reason_code", "")) == "legacy_resume_forbidden" and bool(legacy_v2.get("requires_backup", false)), "legacy_v2_classifies_before_v06_validation")

	var manifest_variant: Variant = handshake.call("required_section_manifest")
	var manifest: Dictionary = manifest_variant if manifest_variant is Dictionary else {}
	var previous_sections: Dictionary = {}
	for section_variant in manifest.keys():
		var section_id := str(section_variant)
		if section_id != "card_resolution_history":
			previous_sections[section_id] = {}
	var previous_payload := {"save_version": 3, "ruleset_id": "v0.6", "sections": previous_sections}
	var previous_inspection: Dictionary = handshake.call("inspect_envelope", previous_payload)
	_check(str(previous_inspection.get("classification", "")) == "v06_previous_manifest" and str(previous_inspection.get("reason_code", "")) == "v06_previous_manifest_resume_forbidden" and bool(previous_inspection.get("requires_backup", false)), "previous_18_section_manifest_is_explicitly_classified_and_rejected")

	var session_before := session.to_save_data()
	var world_before := world.internal_snapshot()
	var annotation_before := annotations.capture_runtime_checkpoint()
	_check(_write_json(LEGACY_V1_PATH, {"version": 1}), "legacy_v1_fixture_written")
	var legacy_load: Dictionary = session.request_load(LEGACY_V1_PATH)
	_check(not bool(legacy_load.get("ok", true)) and str(legacy_load.get("classification", "")) == "legacy_v1" and str(legacy_load.get("reason_code", "")) == "legacy_resume_forbidden", "legacy_v1_high_level_load_returns_classified_failure")
	_check(session.to_save_data() == session_before and world.internal_snapshot() == world_before and annotations.capture_runtime_checkpoint() == annotation_before, "failed_legacy_load_preserves_active_session_and_private_state")

	_check(_write_json(PREVIOUS_V06_PATH, previous_payload), "previous_v06_fixture_written")
	var previous_load: Dictionary = session.request_load(PREVIOUS_V06_PATH)
	_check(not bool(previous_load.get("ok", true)) and str(previous_load.get("classification", "")) == "v06_previous_manifest" and str(previous_load.get("reason_code", "")) == "v06_previous_manifest_resume_forbidden", "previous_manifest_high_level_load_fails_closed")
	_check(session.to_save_data() == session_before and world.internal_snapshot() == world_before and annotations.capture_runtime_checkpoint() == annotation_before, "failed_previous_manifest_load_preserves_active_session")

	var session_state: Dictionary = {}
	var domain_states: Dictionary = {}
	for section_variant in manifest.keys():
		var section_id := str(section_variant)
		var state_version := int((manifest.get(section_id, {}) as Dictionary).get("state_version", 0))
		var state := {"schema_version": state_version, "revision": 0, "fixture_id": "session-envelope-owner"}
		if section_id == "session":
			session_state = state
		else:
			domain_states[section_id] = state
	var envelope_variant: Variant = handshake.call("compose_v06_envelope", session_state, domain_states, {"envelope_id": "session-envelope-owner", "write_id": "session-envelope-owner-write"})
	var envelope: Dictionary = envelope_variant if envelope_variant is Dictionary else {}
	var authorization_variant: Variant = save.call("write_authorization", CURRENT_PATH, envelope)
	var authorization: Dictionary = authorization_variant if authorization_variant is Dictionary else {}
	var written_variant: Variant = save.call("write_validated_envelope", CURRENT_PATH, envelope, authorization)
	var written: Dictionary = written_variant if written_variant is Dictionary else {}
	_check(bool(written.get("ok", false)), "production_high_level_load_fixture_written")
	var inspection := session.inspect_save(CURRENT_PATH)
	_check(bool(inspection.get("ok", false)) and not bool(inspection.get("applied", true)) and str(inspection.get("reason_code", "")) == "restore_capability_incomplete" and str(inspection.get("summary", "")).contains("7个运行时分区"), "production_inspection_keeps_incomplete_resume_read_only")
	var load_receipt := session.request_load(CURRENT_PATH)
	_check(not bool(load_receipt.get("ok", true)) and not bool(load_receipt.get("applied", true)) and str(load_receipt.get("reason_code", "")) == "restore_capability_incomplete" and int(load_receipt.get("registry_apply_count", 0)) == 1 and not load_receipt.has("envelope") and not load_receipt.has("sections") and not load_receipt.has("fingerprint"), "production_load_invokes_registry_once_and_exposes_only_high_level_receipt")
	_check(session.to_save_data() == session_before and world.internal_snapshot() == world_before and annotations.capture_runtime_checkpoint() == annotation_before, "failed_current_v06_load_keeps_active_runtime_unchanged")
	for path in [CURRENT_PATH, LEGACY_V1_PATH, PREVIOUS_V06_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_check(coordinator != null, "load_isolation_uses_formal_coordinator_composition")


func _test_main_v3_load_boundary() -> void:
	var main_source := FileAccess.get_file_as_string("res://scripts/" + "main.gd")
	var session_source := FileAccess.get_file_as_string("res://scripts/runtime/game_session_runtime_controller.gd")
	_check(not main_source.contains("func _load_run(") and not main_source.contains("func _run_save_summary_text(") and not main_source.contains("func _extract_legacy_city_gdp_derivative_positions(") and not main_source.contains("func _apply_run_domain_state_compatibility_adapter("), "main_legacy_payload_and_compatibility_methods_are_physically_absent")
	_check(not main_source.contains("result.get(\"payload\"") and not main_source.contains("complete_run_load") and main_source.contains("inspect_run_save") and main_source.contains("request_run_load"), "main_consumes_only_high_level_load_and_inspection_receipts")
	_check(session_source.contains("result.get(\"envelope\"") and session_source.contains("owner_registry.call(\"apply_envelope\"") and session_source.contains("receipt[\"registry_apply_count\"] = 1"), "game_session_consumes_envelope_and_invokes_registry_exactly_once")


func _city_intel_roundtrip(world: WorldSessionState) -> bool:
	if world.players.size() != 4:
		return false
	var viewer_zero: Dictionary = world.players[0]
	var viewer_one: Dictionary = world.players[1]
	return int((viewer_zero.get("city_guesses", {}) as Dictionary).get(1, -1)) == 2 \
		and int((viewer_zero.get("city_guess_confidence", {}) as Dictionary).get(1, 0)) == 3 \
		and str((viewer_zero.get("city_guess_reasons", {}) as Dictionary).get(1, "")) == "route" \
		and int((viewer_one.get("city_guesses", {}) as Dictionary).get(2, -1)) == 3 \
		and int((viewer_one.get("city_guess_confidence", {}) as Dictionary).get(2, 0)) == 100 \
		and str((viewer_one.get("city_guess_reasons", {}) as Dictionary).get(2, "")) == "业主透镜 I"


func _annotation_roundtrip(annotations: CardHistoryPrivateAnnotationService) -> bool:
	var checkpoint := annotations.capture_save_checkpoint(4)
	if not bool(checkpoint.get("accepted", false)):
		return false
	var state: Dictionary = checkpoint.get("checkpoint", {})
	var usages: Dictionary = state.get("role_usage_by_viewer", {})
	return str(annotations.annotation_for_viewer(0, "card-history:70").get("note_text", "")) == "viewer-zero-note" \
		and bool(annotations.annotation_for_viewer(0, "card-history:70").get("subscribed", false)) \
		and int((usages.get("2", {}) as Dictionary).get("residual_catalog", 0)) == 1 \
		and int((usages.get("3", {}) as Dictionary).get("public_exclusion", 0)) == 1


func _players_fixture(role_catalog: RoleCatalogRuntimeService) -> Array:
	var players: Array = []
	for index in range(4):
		var role_card := role_catalog.definition_at(index) if role_catalog != null else {}
		role_card["role_index"] = index
		var starting_cash := 1000 - index * 25
		players.append({
			"id": index,
			"name": "玩家%d" % (index + 1),
			"seat_type": "human" if index == 0 else "ai",
			"is_ai": index != 0,
			"ai_profile": {},
			"ai_memory": {},
			"role_index": index,
			"role_card": role_card,
			"base_starting_cash": 1000,
			"role_starting_cash_delta": starting_cash - 1000,
			"starting_cash_total": starting_cash,
			"cash": starting_cash,
			"cash_cents": starting_cash * 100,
			"cash_history": [starting_cash],
			"v06_transaction_ledger": [],
			"eliminated": false,
			"eliminated_at": -1.0,
			"elimination_reason": "",
			"economic_ledger": [],
			"city_guesses": {},
			"city_guess_confidence": {},
			"city_guess_reasons": {},
			"known_contract_parties": {1: "公开合约线索"} if index == 0 else {},
			"cities_built": 0,
			"total_card_spend": 0,
			"card_purchase_count": 0,
			"total_build_spend": 0,
			"total_card_income": 0,
			"total_role_income": 0,
			"total_business_spend": 0,
			"action_cooldown": 0.0,
			"queued_card_tip": 0,
			"slots": [],
		})
	(players[0] as Dictionary)["city_guesses"] = {1: 2}
	(players[0] as Dictionary)["city_guess_confidence"] = {1: 3}
	(players[0] as Dictionary)["city_guess_reasons"] = {1: "route"}
	(players[1] as Dictionary)["city_guesses"] = {2: 3}
	(players[1] as Dictionary)["city_guess_confidence"] = {2: 100}
	(players[1] as Dictionary)["city_guess_reasons"] = {2: "业主透镜 I"}
	return players


func _districts_fixture() -> Array:
	var districts: Array = []
	for index in range(3):
		var neighbors: Array[int] = []
		for neighbor in range(3):
			if neighbor != index:
				neighbors.append(neighbor)
		districts.append({
			"region_id": "region.%03d" % index,
			"name": "区域%d" % (index + 1),
			"center": Vector2(100.0 + index * 200.0, 200.0),
			"polygon": [Vector2(index * 20.0, 0.0), Vector2(index * 20.0 + 15.0, 0.0), Vector2(index * 20.0 + 7.5, 12.0)],
			"area_m2": 160.0,
			"radius_m": 18.0,
			"hp": 100.0,
			"damage": 0.0,
			"last_damage_source": "",
			"last_damage_amount": 0.0,
			"last_damage_time": 0.0,
			"destroyed": false,
			"miasma": false,
			"terrain": "land",
			"terrain_label": "陆地",
			"products": ["测试商品%d" % index],
			"demands": ["测试需求%d" % index],
			"neighbors": neighbors,
			"transport_score": 1.0,
			"city": {"active": true, "owner": (index + 1) % 4},
		})
	return districts


func _annotation_count(annotations: CardHistoryPrivateAnnotationService, viewer_count: int) -> int:
	var count := 0
	for viewer_index in range(viewer_count):
		count += (annotations.viewer_snapshot(viewer_index).get("annotations", []) as Array).size()
	return count


func _write_json(path: String, data: Dictionary) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	return true


func _pure_data(value: Variant) -> bool:
	if typeof(value) == TYPE_OBJECT or value is Callable:
		return false
	if value is float and not is_finite(value):
		return false
	if value is Dictionary:
		for key_variant in value.keys():
			if not _pure_data(key_variant) or not _pure_data(value[key_variant]):
				return false
	elif value is Array:
		for item in value:
			if not _pure_data(item):
				return false
	return true


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> Dictionary:
	return {
		"passed": _failures.is_empty(),
		"checks": _checks,
		"failure_count": _failures.size(),
		"failures": _failures.duplicate(),
		"evidence": {
			"required_section_count": 19,
			"transactional_section_count": 12,
			"unsupported_section_count": 7,
			"cold_runtime_history_before": _cold_history_before,
			"cold_runtime_annotations_before": _cold_annotations_before,
			"cold_runtime_history_after": _cold_history_after,
			"cold_runtime_annotations_after": _cold_annotations_after,
			"full_run_resume_claimed": false,
		},
	}
