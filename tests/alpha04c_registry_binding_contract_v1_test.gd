extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")

const EXPECTED_BINDING_COUNT := 19
const EXPECTED_EXPLICIT_CHECKPOINT_COUNT := 8
const EXPECTED_REGISTRY_MANAGED_CHECKPOINT_COUNT := 11
const EXPECTED_OWNER_INTERNAL_CHECKPOINT_COUNT := 0

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := MAIN_SCENE.instantiate()
	var lifecycle := main.get_node_or_null("RuntimeServices/MenuLifecycleApplicationFlowController")
	if lifecycle != null:
		lifecycle.set("open_root_on_ready", false)
	root.add_child(main)
	await process_frame
	await process_frame
	var services := main.get_node_or_null("RuntimeServices")
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	var session := coordinator.get_node_or_null("GameSessionRuntimeController") if coordinator != null else null
	var draft := services.get_node_or_null("NewGameSetupDraftService") as NewGameSetupDraftService \
		if services != null else null
	var transaction := services.get_node_or_null("SessionStartTransactionCoordinator") as SessionStartTransactionCoordinator \
		if services != null else null
	var started := false
	if draft != null and transaction != null and session != null:
		draft.reset_to_defaults()
		var request := SessionStartRequest.create(
			"alpha04c-registry-binding-contract-v1",
			draft.draft_snapshot(),
			session.session_start_revision(),
			"focused_test"
		)
		var start_receipt := transaction.start_session(request)
		started = start_receipt != null and start_receipt.applied
	_expect(started, "real production composition starts an isolated default session")
	main.process_mode = Node.PROCESS_MODE_DISABLED
	var registry := session.get_node_or_null("V06SaveOwnerRegistry") if session != null else null
	var handshake := session.get_node_or_null("GameSaveRuntimeCoordinator/RulesetSaveHandshakeService") \
		if session != null else null
	_expect(registry != null and handshake != null, "real production Registry and handshake are composed")
	if not started or registry == null or handshake == null:
		main.queue_free()
		await process_frame
		_finish(0, 0, 0, 0)
		return

	var contract: Dictionary = registry.registry_binding_contract_v1()
	var rows: Array = contract.get("bindings", []) as Array
	var strategy_counts: Dictionary = contract.get("checkpoint_strategy_counts", {}) \
		if contract.get("checkpoint_strategy_counts", {}) is Dictionary else {}
	var explicit_count := int(strategy_counts.get(
		V06SaveOwnerRegistry.CHECKPOINT_STRATEGY_EXPLICIT_OWNER_METHOD,
		-1
	))
	var registry_managed_count := int(strategy_counts.get(
		V06SaveOwnerRegistry.CHECKPOINT_STRATEGY_REGISTRY_MANAGED,
		-1
	))
	var owner_internal_count := int(strategy_counts.get(
		V06SaveOwnerRegistry.CHECKPOINT_STRATEGY_OWNER_INTERNAL,
		-1
	))
	_expect(bool(contract.get("valid", false)) \
		and str(contract.get("contract_id", "")) == V06SaveOwnerRegistry.BINDING_CONTRACT_ID \
		and int(contract.get("schema_version", 0)) == 1,
		"Registry publishes one valid read-only v1 binding contract")
	_expect(int(contract.get("binding_count", 0)) == EXPECTED_BINDING_COUNT \
		and rows.size() == EXPECTED_BINDING_COUNT,
		"binding contract projects all 19 production bindings")
	_expect(explicit_count == EXPECTED_EXPLICIT_CHECKPOINT_COUNT \
		and registry_managed_count == EXPECTED_REGISTRY_MANAGED_CHECKPOINT_COUNT \
		and owner_internal_count == EXPECTED_OWNER_INTERNAL_CHECKPOINT_COUNT,
		"production strategies are 8 explicit, 11 Registry-managed, and 0 owner-internal")
	_expect(int(contract.get("owner_without_checkpoint_or_rollback_semantics_count", -1)) == 0,
		"no production Owner lacks checkpoint or rollback semantics")
	_expect(contract.get("configured_section_order", []) == registry.fixed_section_order() \
		and contract.get("fixed_section_order", []) == registry.fixed_section_order(),
		"configured binding order exactly matches the Registry serialization order")
	_expect(_restore_dag_valid(contract),
		"restore DAG contains unique ordered nodes with closed predecessor dependencies")

	var manifest: Dictionary = handshake.required_section_manifest()
	var section_ids: Dictionary = {}
	var owner_ids: Dictionary = {}
	var omitted_checkpoint_count := 0
	var row_contracts_valid := true
	for row_index in range(rows.size()):
		var row: Dictionary = rows[row_index] if rows[row_index] is Dictionary else {}
		var section_id := str(row.get("section_id", ""))
		var owner_id := str(row.get("owner_id", ""))
		var owner := registry.get_node_or_null(NodePath(str(row.get("owner_path", ""))))
		var strategy := str(row.get("checkpoint_strategy", ""))
		var checkpoint_present := bool(row.get("checkpoint_method_present", false))
		var manifest_row: Dictionary = manifest.get(section_id, {}) \
			if manifest.get(section_id, {}) is Dictionary else {}
		if not checkpoint_present:
			omitted_checkpoint_count += 1
		var identity_unique := not section_ids.has(section_id) and not owner_ids.has(owner_id)
		section_ids[section_id] = true
		owner_ids[owner_id] = true
		var actual_methods_valid := owner != null \
			and owner.has_method(str(row.get("capture_method", ""))) \
			and (str(row.get("preflight_method", "")).is_empty() \
				or owner.has_method(str(row.get("preflight_method", "")))) \
			and owner.has_method(str(row.get("apply_method", ""))) \
			and owner.has_method(str(row.get("rollback_method", "")))
		var strategy_shape_valid := strategy == V06SaveOwnerRegistry.CHECKPOINT_STRATEGY_EXPLICIT_OWNER_METHOD \
			and checkpoint_present \
			and owner != null \
			and owner.has_method(str(row.get("checkpoint_method", ""))) \
			or strategy == V06SaveOwnerRegistry.CHECKPOINT_STRATEGY_REGISTRY_MANAGED \
			and not checkpoint_present \
			and str(row.get("checkpoint_source_method", "")) == str(row.get("capture_method", ""))
		var version_valid := int(row.get("state_version", 0)) > 0 \
			and str(manifest_row.get("owner_id", "")) == owner_id \
			and int(manifest_row.get("state_version", 0)) == int(row.get("state_version", 0))
		row_contracts_valid = row_contracts_valid \
			and int(row.get("section_index", -1)) == row_index \
			and section_id == str(registry.fixed_section_order()[row_index]) \
			and identity_unique \
			and actual_methods_valid \
			and strategy_shape_valid \
			and version_valid \
			and bool(row.get("checkpoint_strategy_valid", false)) \
			and bool(row.get("checkpoint_captured_before_any_apply", false)) \
			and bool(row.get("rollback_invoked_by_registry", false)) \
			and str(row.get("rollback_order", "")) == "reverse_restore_dag" \
			and bool(row.get("post_rollback_exact_recapture_required", false)) \
			and bool(row.get("valid", false)) \
			and _is_sha256(str(row.get("binding_contract_fingerprint", "")))
	_expect(section_ids.size() == EXPECTED_BINDING_COUNT and owner_ids.size() == EXPECTED_BINDING_COUNT,
		"all section and Owner identities are unique")
	_expect(omitted_checkpoint_count == EXPECTED_REGISTRY_MANAGED_CHECKPOINT_COUNT,
		"exactly 11 legal Registry-managed bindings omit checkpoint_method")
	_expect(row_contracts_valid,
		"every projected binding matches the real Owner methods, manifest version, strategy, and rollback contract")

	var rollback_counts := await _prove_fault_rollback_by_strategy(registry, handshake, rows)
	var rollback_total := int(rollback_counts.get("total", 0))
	_expect(rollback_total == EXPECTED_BINDING_COUNT,
		"all 19 production bindings restore their exact checkpoint after an injected apply fault")
	_expect(int(rollback_counts.get(V06SaveOwnerRegistry.CHECKPOINT_STRATEGY_EXPLICIT_OWNER_METHOD, 0)) \
			== EXPECTED_EXPLICIT_CHECKPOINT_COUNT \
		and int(rollback_counts.get(V06SaveOwnerRegistry.CHECKPOINT_STRATEGY_REGISTRY_MANAGED, 0)) \
			== EXPECTED_REGISTRY_MANAGED_CHECKPOINT_COUNT,
		"both explicit and omitted-method strategies prove exact reverse-order rollback")

	main.queue_free()
	await process_frame
	_finish(explicit_count, registry_managed_count, owner_internal_count, rollback_total)


func _prove_fault_rollback_by_strategy(registry: Node, handshake: Node, rows: Array) -> Dictionary:
	var result := {
		"total": 0,
		V06SaveOwnerRegistry.CHECKPOINT_STRATEGY_EXPLICIT_OWNER_METHOD: 0,
		V06SaveOwnerRegistry.CHECKPOINT_STRATEGY_REGISTRY_MANAGED: 0,
		V06SaveOwnerRegistry.CHECKPOINT_STRATEGY_OWNER_INTERNAL: 0,
	}
	var captured: Dictionary = registry.capture_resume_envelope({
		"envelope_id": "alpha04c-registry-binding-contract-baseline",
		"write_id": "alpha04c-registry-binding-contract-baseline-write",
	})
	var envelope: Dictionary = captured.get("envelope", {}) \
		if captured.get("envelope", {}) is Dictionary else {}
	var baseline := _canonical_sections(handshake, envelope)
	_expect(bool(captured.get("ok", false)) and not baseline.is_empty(),
		"production Registry captures the baseline used by rollback proofs")
	if not bool(captured.get("ok", false)) or baseline.is_empty():
		return result
	for row_variant in rows:
		var row: Dictionary = row_variant if row_variant is Dictionary else {}
		var section_id := str(row.get("section_id", ""))
		var strategy := str(row.get("checkpoint_strategy", ""))
		var armed := bool(registry.arm_test_apply_failure_once(section_id))
		var failed: Dictionary = registry.apply_envelope(envelope)
		var rollback_debug: Dictionary = registry.debug_snapshot()
		var recaptured: Dictionary = registry.capture_resume_envelope({
			"envelope_id": "alpha04c-registry-binding-contract-after-%s" % section_id,
			"write_id": "alpha04c-registry-binding-contract-after-%s-write" % section_id,
		})
		var recaptured_envelope: Dictionary = recaptured.get("envelope", {}) \
			if recaptured.get("envelope", {}) is Dictionary else {}
		var exact := bool(recaptured.get("ok", false)) \
			and _canonical_sections(handshake, recaptured_envelope) == baseline
		var rollback_valid: bool = armed \
			and not bool(failed.get("ok", true)) \
			and bool(failed.get("rollback_attempted", false)) \
			and bool(failed.get("rollback_complete", false)) \
			and int(failed.get("partial_restore_state_count", -1)) == 0 \
			and rollback_debug.get("last_internal_rollback_order", []) \
				== _expected_reverse_rollback_order(registry, section_id) \
			and exact
		if rollback_valid:
			result["total"] = int(result.get("total", 0)) + 1
			result[strategy] = int(result.get(strategy, 0)) + 1
	return result


func _restore_dag_valid(contract: Dictionary) -> bool:
	var dag: Array = contract.get("restore_dag", []) as Array
	var expected_order: Array = contract.get("restore_dag_node_order", []) as Array
	if dag.size() != expected_order.size() or dag.is_empty():
		return false
	var seen: Dictionary = {}
	for node_index in range(dag.size()):
		if not (dag[node_index] is Dictionary):
			return false
		var node := dag[node_index] as Dictionary
		var node_id := str(node.get("node_id", ""))
		if int(node.get("node_index", -1)) != node_index \
				or node_id != str(expected_order[node_index]) \
				or seen.has(node_id):
			return false
		for dependency_variant in node.get("dependencies", []) as Array:
			if not seen.has(str(dependency_variant)):
				return false
		seen[node_id] = true
	return seen.size() == expected_order.size()


func _expected_reverse_rollback_order(registry: Node, failing_section_id: String) -> Array[String]:
	var touched: Array[String] = []
	for node_variant in registry.restore_dag_node_order():
		var node_id := str(node_variant)
		var section_id := "session" if node_id in ["session_foundation", "session_tail"] else node_id
		if not touched.has(section_id):
			touched.append(section_id)
		if section_id == failing_section_id \
				and (failing_section_id != "session" or node_id == "session_tail"):
			break
	touched.reverse()
	return touched


func _canonical_sections(handshake: Node, envelope: Dictionary) -> String:
	if handshake == null or not handshake.has_method("canonical_json") \
			or not (envelope.get("sections") is Dictionary):
		return ""
	return str(handshake.call("canonical_json", envelope.get("sections")))


func _is_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for index in range(value.length()):
		if value[index] not in "0123456789abcdef":
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish(explicit_count: int, registry_managed_count: int, owner_internal_count: int, rollback_count: int) -> void:
	print("ALPHA04C_REGISTRY_BINDING_CONTRACT_V1_TEST|status=%s|checks=%d|bindings=%d|explicit=%d|registry_managed=%d|owner_internal=%d|rollback=%d/%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		EXPECTED_BINDING_COUNT,
		explicit_count,
		registry_managed_count,
		owner_internal_count,
		rollback_count,
		EXPECTED_BINDING_COUNT,
		_failures.size(),
	])
	quit(0 if _failures.is_empty() else 1)
