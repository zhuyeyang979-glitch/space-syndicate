extends SceneTree

const Replay := preload("res://scripts/tools/alpha04c_v6_registry_binding_replay.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var evidence_root := Replay.locate_retained_v6_evidence_root()
	_expect(not evidence_root.is_empty(), "retained V6 evidence root resolves from the shared Git common directory")
	var replay := Replay.run(evidence_root)
	print("V6_REPLAY_CHARACTERIZATION|reason=%s|ledger=%s|scenario=%s|scenario_reason=%s|scenario_failure=%s|historical_failure=%s|child=%s|parent=%s" % [
		str(replay.get("reason_code", "")),
		str(replay.get("ledger_green", false)),
		str(replay.get("scenario_identity_green", false)),
		str(replay.get("scenario_identity_validation_reason_code", "")),
		JSON.stringify(replay.get("scenario_identity_validation_failure", {})),
		str(replay.get("historical_failure_green", false)),
		str(replay.get("child_completion_green", false)),
		str(replay.get("parent_exit_green", false)),
	])
	_expect(
		bool(replay.get("valid", false)),
		"exact retained V6 Registry replay is green: %s" % str(replay.get("reason_code", "missing_reason"))
	)
	_expect(str(replay.get("v6_ledger_sha256", "")) == Replay.EXPECTED_LEDGER_SHA256, "exact V6 ledger bytes retain the authorized SHA-256")
	_expect(bool(replay.get("v6_retained_ledger_replay_green", false)), "retained V6 ledger and Launch Context replay without mutation")
	_expect(bool(replay.get("v6_scenario_identity_replay_green", false)), "retained V6 scenario identity revalidates")
	_expect(bool(replay.get("v6_registry_binding_replay_green", false)), "canonical Registry Binding replay validates 19/19")
	_expect(int(replay.get("registry_binding_contract_source_count", 0)) == 1, "production Registry is the one binding-contract source")
	_expect(int(replay.get("duplicate_binding_required_field_list_count", -1)) == 0, "diagnostic keeps no duplicate binding-field list")
	_expect(int(replay.get("diagnostic_hardcoded_checkpoint_requirement_count", -1)) == 0, "diagnostic has no hardcoded checkpoint-method requirement")
	_expect(bool(replay.get("pre_fix_characterized", false)), "legacy validator failure is characterized at the first omitted checkpoint method")
	_expect(int(replay.get("v6_replay_pre_fix_omitted_row_count", -1)) == 11, "legacy production projection has exactly eleven omitted checkpoint methods")
	_expect(str(replay.get("v6_replay_pre_fix_first_mismatch_section", "")) == "region_infrastructure", "legacy first mismatch identifies region_infrastructure")
	_expect(str(replay.get("v6_replay_pre_fix_first_mismatch_owner", "")) == "public_facility_region", "legacy first mismatch identifies public_facility_region")
	_expect(str(replay.get("v6_replay_pre_fix_mismatch_field", "")) == "checkpoint_method", "legacy first mismatch identifies checkpoint_method")
	_expect(bool(replay.get("retained_registry_fingerprint_match", false)), "read-only production Registry projection matches the fingerprint retained by V6")
	_expect(bool(replay.get("retained_evidence_bytes_unchanged", false)), "the replay leaves every retained V6 evidence byte unchanged")
	_expect(int(replay.get("replay_diagnostic_count_delta", -1)) == 0, "replay changes no diagnostic count")
	_expect(int(replay.get("replay_quota_claim_count", -1)) == 0, "replay claims no quota")
	_expect(int(replay.get("replay_production_session_create_count", -1)) == 0, "replay creates no production Session")
	_expect(int(replay.get("replay_owner_capture_count", -1)) == 0, "replay performs no Owner Capture")
	_expect(int(replay.get("replay_save_write_count", -1)) == 0, "replay writes no Save")

	var fixture := Replay.read_only_registry_fixture()
	_expect(bool(fixture.get("ready", false)), "read-only production Registry composition exposes the canonical v1 port")
	if not bool(fixture.get("ready", false)):
		_finish()
		return
	var composition := fixture.get("composition") as Node
	var session := fixture.get("session") as Node
	var registry := fixture.get("registry") as Node
	var contract: Dictionary = fixture.get("contract", {})
	_expect(str(session.call("session_state")) == "idle", "Registry composition stays idle and creates no production Session")

	var canonical := Replay.validate_registry_binding_contract(contract, registry)
	_expect(bool(canonical.get("valid", false)), "canonical production Registry contract validates")
	_expect(int(canonical.get("binding_count", 0)) == 19, "canonical contract contains nineteen ordered bindings")
	_expect(int(canonical.get("explicit_checkpoint_count", -1)) == 8, "eight bindings use explicit Owner checkpoint methods")
	_expect(int(canonical.get("registry_managed_checkpoint_count", -1)) == 11, "eleven bindings use Registry-managed capture checkpoints")
	_expect(int(canonical.get("owner_internal_checkpoint_count", -1)) == 0, "no current production binding relies on an unproven internal checkpoint")
	_expect(int(canonical.get("omitted_checkpoint_method_count", -1)) == 11, "all eleven omitted methods are represented explicitly by strategy")
	_expect(int(canonical.get("owner_without_transaction_semantics_count", -1)) == 0, "every Owner has checkpoint and rollback semantics")

	var rows := contract.get("bindings", []) as Array
	var explicit_index := _first_strategy_index(rows, Replay.STRATEGY_EXPLICIT)
	var managed_index := _first_strategy_index(rows, Replay.STRATEGY_REGISTRY_MANAGED)
	_expect(explicit_index >= 0 and managed_index >= 0, "canonical contract contains explicit and Registry-managed examples")

	var fake_method := _mutate_row(contract, explicit_index, {
		"checkpoint_method": "checkpoint_method_that_does_not_exist",
		"checkpoint_method_present": true,
	})
	_expect_rejected(
		Replay.validate_registry_binding_contract(fake_method, registry),
		"checkpoint_method", "method_missing", "fake explicit checkpoint method"
	)

	var strategy_conflict := _mutate_row(contract, explicit_index, {
		"checkpoint_strategy": Replay.STRATEGY_REGISTRY_MANAGED,
	})
	_expect_rejected(
		Replay.validate_registry_binding_contract(strategy_conflict, registry),
		"checkpoint_method", "strategy_field_conflict", "strategy and checkpoint field conflict"
	)

	var explicit_without_method := _mutate_row(contract, managed_index, {
		"checkpoint_strategy": Replay.STRATEGY_EXPLICIT,
	})
	_expect_rejected(
		Replay.validate_registry_binding_contract(explicit_without_method, registry),
		"checkpoint_method", "missing", "explicit strategy without method"
	)

	var missing_rollback := _mutate_row(contract, managed_index, {"rollback_method": ""})
	_expect_rejected(
		Replay.validate_registry_binding_contract(missing_rollback, registry),
		"rollback_method", "missing", "Owner without rollback"
	)

	var duplicate_section := contract.duplicate(true)
	var duplicate_section_rows := duplicate_section.get("bindings", []) as Array
	var duplicate_order := duplicate_section.get("fixed_section_order", []) as Array
	var first_section := str((duplicate_section_rows[0] as Dictionary).get("section_id", ""))
	(duplicate_section_rows[1] as Dictionary)["section_id"] = first_section
	duplicate_order[1] = first_section
	duplicate_section["bindings"] = duplicate_section_rows
	duplicate_section["fixed_section_order"] = duplicate_order
	duplicate_section = Replay.reseal_contract(duplicate_section)
	_expect_rejected(
		Replay.validate_registry_binding_contract(duplicate_section, registry),
		"section_id", "duplicate", "duplicate section"
	)

	var duplicate_owner := _mutate_row(contract, 1, {
		"owner_id": str((rows[0] as Dictionary).get("owner_id", "")),
	})
	_expect_rejected(
		Replay.validate_registry_binding_contract(duplicate_owner, registry),
		"owner_id", "duplicate", "duplicate Owner"
	)

	var missing_dependency := _mutate_row(contract, 0, {
		"dependencies": ["section.not_registered"],
	})
	_expect_rejected(
		Replay.validate_registry_binding_contract(missing_dependency, registry),
		"dependencies", "missing_dependency", "missing dependency"
	)

	var cyclic_dependency := contract.duplicate(true)
	var cyclic_dag := cyclic_dependency.get("restore_dag", []) as Array
	(cyclic_dag[0] as Dictionary)["dependencies"] = [str((cyclic_dag[1] as Dictionary).get("node_id", ""))]
	(cyclic_dag[1] as Dictionary)["dependencies"] = [str((cyclic_dag[0] as Dictionary).get("node_id", ""))]
	cyclic_dependency["restore_dag"] = cyclic_dag
	cyclic_dependency = Replay.reseal_contract(cyclic_dependency)
	_expect_rejected(
		Replay.validate_registry_binding_contract(cyclic_dependency, registry),
		"restore_dag.dependencies", "dependency_cycle", "cyclic dependency"
	)

	var wrong_state_version := _mutate_row(contract, 0, {
		"state_version": int((rows[0] as Dictionary).get("state_version", 1)) + 1,
	})
	_expect_rejected(
		Replay.validate_registry_projection(contract, wrong_state_version, registry),
		"state_version", "value_mismatch", "wrong state version"
	)

	var wrong_order := contract.duplicate(true)
	var wrong_order_rows := wrong_order.get("bindings", []) as Array
	var first_row := (wrong_order_rows[0] as Dictionary).duplicate(true)
	var second_row := (wrong_order_rows[1] as Dictionary).duplicate(true)
	first_row["section_index"] = 1
	second_row["section_index"] = 0
	wrong_order_rows[0] = second_row
	wrong_order_rows[1] = first_row
	wrong_order["bindings"] = wrong_order_rows
	wrong_order = Replay.reseal_contract(wrong_order)
	_expect_rejected(
		Replay.validate_registry_projection(contract, wrong_order, registry),
		"section_id", "value_mismatch", "registration order drift"
	)

	var divergent_fixture := _mutate_row(contract, 0, {
		"method_contract_source": "test_fixture_not_production_registry",
	})
	_expect_rejected(
		Replay.validate_registry_projection(contract, divergent_fixture, registry),
		"method_contract_source", "value_mismatch", "diagnostic fixture divergence"
	)

	var replay_source := FileAccess.get_file_as_string(
		"res://scripts/tools/alpha04c_v6_registry_binding_replay.gd"
	)
	_expect(not replay_source.contains("registry.bindings"), "replay consumes the canonical Registry port instead of reading a duplicate binding list")
	_expect(not replay_source.contains("const ALLOWED_STRATEGIES"), "replay consumes the Registry strategy set instead of defining a second authority")
	_expect(not replay_source.contains("capture_all_sections_detailed"), "replay cannot enter Owner Capture")
	_expect(not replay_source.contains("capture_resume_envelope"), "replay cannot capture a Save envelope")
	_expect(not replay_source.contains("begin_session("), "replay cannot create a production Session")
	_expect(not replay_source.contains("FileAccess.WRITE"), "replay has no file-write path")
	_expect(str(session.call("session_state")) == "idle", "negative characterization leaves the Registry composition idle")
	composition.free()
	_finish()


func _first_strategy_index(rows: Array, strategy: String) -> int:
	for index in range(rows.size()):
		if rows[index] is Dictionary \
				and str((rows[index] as Dictionary).get("checkpoint_strategy", "")) == strategy:
			return index
	return -1


func _mutate_row(contract: Dictionary, row_index: int, values: Dictionary) -> Dictionary:
	var mutated := contract.duplicate(true)
	var rows := mutated.get("bindings", []) as Array
	if row_index < 0 or row_index >= rows.size() or not (rows[row_index] is Dictionary):
		return mutated
	var row := (rows[row_index] as Dictionary).duplicate(true)
	for key in values:
		row[key] = values[key]
	rows[row_index] = row
	mutated["bindings"] = rows
	return Replay.reseal_contract(mutated)


func _expect_rejected(
	report: Dictionary,
	expected_field: String,
	expected_typed_reason: String,
	case_name: String
) -> void:
	_expect(
		not bool(report.get("valid", true)) \
				and str(report.get("reason_code", "")) == Replay.EXPECTED_FAILURE_REASON \
				and str(report.get("failing_field", "")) == expected_field \
				and str(report.get("typed_reason", "")) == expected_typed_reason \
				and bool(report.get("private_payload_redacted", false)),
		"%s is rejected precisely at %s/%s: %s" % [
			case_name,
			expected_field,
			expected_typed_reason,
			JSON.stringify(report),
		]
	)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print("ALPHA04C_V6_REGISTRY_BINDING_REPLAY_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	quit(0 if _failures.is_empty() else 1)
