extends RefCounted
class_name Alpha04CRegistryBindingContractValidatorV1

const SaveRegistry := preload("res://scripts/runtime/v06_save_owner_registry.gd")

const FAILURE_REASON := "diagnostic_registry_binding_contract_mismatch"
const STRATEGY_EXPLICIT := SaveRegistry.CHECKPOINT_STRATEGY_EXPLICIT_OWNER_METHOD
const STRATEGY_REGISTRY_MANAGED := SaveRegistry.CHECKPOINT_STRATEGY_REGISTRY_MANAGED
const STRATEGY_OWNER_INTERNAL := SaveRegistry.CHECKPOINT_STRATEGY_OWNER_INTERNAL


static func validate(
	contract: Dictionary,
	registry: Node,
	expected_binding_count := -1
) -> Dictionary:
	if registry == null:
		return _rejection({}, "save_registry", "", "registry", "registry_missing")
	if not (contract.get("schema_version") is int) or int(contract.get("schema_version", 0)) != 1:
		return _rejection({}, "schema_version", "", "registry", "value_mismatch")
	if str(contract.get("contract_id", "")).is_empty():
		return _rejection({}, "contract_id", "", "registry", "missing")
	if str(contract.get("registry_id", "")) != "v06_save_owner_registry":
		return _rejection({}, "registry_id", "", "registry", "value_mismatch")
	if not (contract.get("registry_version") is int) or int(contract.get("registry_version", 0)) < 1:
		return _rejection({}, "registry_version", "", "registry", "wrong_type_or_range")
	if not (contract.get("valid") is bool) or not bool(contract.get("valid", false)):
		return _rejection({}, "valid", "", "registry", "contract_not_ready")
	if not (contract.get("errors") is Array) or not (contract.get("errors", []) as Array).is_empty():
		return _rejection({}, "errors", "", "registry", "contract_not_ready")
	if not (contract.get("fixed_section_order") is Array):
		return _rejection({}, "fixed_section_order", "", "registry", "wrong_type")
	if not (contract.get("configured_section_order") is Array):
		return _rejection({}, "configured_section_order", "", "registry", "wrong_type")
	if not (contract.get("bindings") is Array):
		return _rejection({}, "bindings", "", "registry", "wrong_type")
	if not (contract.get("checkpoint_strategies") is Array):
		return _rejection({}, "checkpoint_strategies", "", "registry", "wrong_type")

	var order := contract.get("fixed_section_order", []) as Array
	var configured_order := contract.get("configured_section_order", []) as Array
	var rows := contract.get("bindings", []) as Array
	var allowed_strategies := contract.get("checkpoint_strategies", []) as Array
	var declared_strategies: Array[String] = []
	for strategy_variant in allowed_strategies:
		declared_strategies.append(str(strategy_variant))
	declared_strategies.sort()
	var required_strategies: Array[String] = [
		STRATEGY_EXPLICIT,
		STRATEGY_REGISTRY_MANAGED,
		STRATEGY_OWNER_INTERNAL,
	]
	required_strategies.sort()
	if declared_strategies != required_strategies:
		return _rejection({}, "checkpoint_strategies", "", "registry", "closed_set_mismatch")
	if expected_binding_count > 0 \
			and (rows.size() != expected_binding_count or order.size() != expected_binding_count):
		return _rejection({}, "binding_count", "", "registry", "value_mismatch")
	if rows.is_empty() or rows.size() != order.size():
		return _rejection({}, "binding_count", "", "registry", "value_mismatch")
	if not (contract.get("binding_count") is int) \
			or int(contract.get("binding_count", -1)) != rows.size():
		return _rejection({}, "binding_count", "", "registry", "value_mismatch")
	if not (contract.get("owner_without_checkpoint_or_rollback_semantics_count") is int) \
			or int(contract.get("owner_without_checkpoint_or_rollback_semantics_count", -1)) != 0:
		return _rejection(
			{}, "owner_without_checkpoint_or_rollback_semantics_count", "", "registry", "value_mismatch"
		)

	var restore_dag_report := _validate_restore_dag(contract)
	if not bool(restore_dag_report.get("valid", false)):
		return restore_dag_report
	var restore_node_ids: Dictionary = restore_dag_report.get("node_ids", {})
	var section_ids: Dictionary = {}
	var owner_ids: Dictionary = {}
	var explicit_count := 0
	var registry_managed_count := 0
	var owner_internal_count := 0
	var omitted_count := 0
	for index in range(rows.size()):
		if not (rows[index] is Dictionary):
			return _rejection({}, "bindings", "", "registry", "row_wrong_type")
		var row := rows[index] as Dictionary
		var section_id := str(row.get("section_id", ""))
		var owner_id := str(row.get("owner_id", ""))
		var strategy := str(row.get("checkpoint_strategy", ""))
		if not (row.get("section_index") is int) or int(row.get("section_index", -1)) != index:
			return _rejection(row, "section_index", strategy, "registry", "registration_order_mismatch")
		if section_id.is_empty() or str(order[index]) != section_id:
			return _rejection(row, "section_id", strategy, "registry", "registration_order_mismatch")
		if section_ids.has(section_id):
			return _rejection(row, "section_id", strategy, "registry", "duplicate")
		if owner_id.is_empty() or owner_ids.has(owner_id):
			return _rejection(
				row, "owner_id", strategy, "registry", "duplicate" if not owner_id.is_empty() else "missing"
			)
		section_ids[section_id] = true
		owner_ids[owner_id] = true
		if not (row.get("state_version") is int) or int(row.get("state_version", 0)) < 1:
			return _rejection(row, "state_version", strategy, "registry", "wrong_type_or_range")
		if str(row.get("restore_mode", "")) != "transactional":
			return _rejection(row, "restore_mode", strategy, "registry", "value_mismatch")
		if not (row.get("checkpoint_method_present") is bool):
			return _rejection(row, "checkpoint_method_present", strategy, "registry", "wrong_type")
		var checkpoint_method := str(row.get("checkpoint_method", ""))
		var checkpoint_present := bool(row.get("checkpoint_method_present", false))
		if checkpoint_present != not checkpoint_method.is_empty():
			return _rejection(row, "checkpoint_method", strategy, "registry", "presence_value_conflict")
		if not checkpoint_present:
			omitted_count += 1
		if strategy not in required_strategies:
			return _rejection(row, "checkpoint_strategy", strategy, "registry", "unknown_or_none")
		var owner_path_text := str(row.get("owner_path", ""))
		if owner_path_text.is_empty():
			return _rejection(row, "owner_path", strategy, "registry", "missing")
		var owner := registry.get_node_or_null(NodePath(owner_path_text))
		if owner == null:
			return _rejection(row, "owner_path", strategy, "registry", "owner_node_missing")
		for method_field in ["capture_method", "preflight_method", "apply_method", "rollback_method"]:
			var method_name := str(row.get(method_field, ""))
			if method_name.is_empty():
				return _rejection(row, method_field, strategy, "owner_api", "missing")
			if not owner.has_method(method_name):
				return _rejection(row, method_field, strategy, "owner_api", "method_missing")
		if str(row.get("method_contract_source", "")).is_empty():
			return _rejection(row, "method_contract_source", strategy, "registry", "missing")
		if not bool(row.get("valid", false)) \
				or not bool(row.get("owner_node_present", false)) \
				or not bool(row.get("capture_method_exists", false)) \
				or not bool(row.get("preflight_method_exists", false)) \
				or not bool(row.get("apply_method_exists", false)) \
				or not bool(row.get("rollback_method_exists", false)) \
				or not bool(row.get("checkpoint_strategy_valid", false)) \
				or not bool(row.get("state_version_valid", false)):
			return _rejection(row, "binding_runtime_evidence", strategy, "registry", "value_mismatch")
		match strategy:
			STRATEGY_EXPLICIT:
				explicit_count += 1
				if not checkpoint_present:
					return _rejection(row, "checkpoint_method", strategy, "owner_api", "missing")
				if not owner.has_method(checkpoint_method):
					return _rejection(row, "checkpoint_method", strategy, "owner_api", "method_missing")
				if str(row.get("checkpoint_source_method", "")) != checkpoint_method:
					return _rejection(row, "checkpoint_source_method", strategy, "registry", "value_mismatch")
			STRATEGY_REGISTRY_MANAGED:
				registry_managed_count += 1
				if checkpoint_present:
					return _rejection(row, "checkpoint_method", strategy, "registry", "strategy_field_conflict")
				if str(row.get("checkpoint_source_method", "")) != str(row.get("capture_method", "")) \
						or not bool(row.get("checkpoint_captured_before_any_apply", false)) \
						or not bool(row.get("rollback_invoked_by_registry", false)) \
						or str(row.get("rollback_order", "")) != "reverse_restore_dag" \
						or not bool(row.get("post_rollback_exact_recapture_required", false)):
					return _rejection(row, "checkpoint_strategy", strategy, "registry", "strategy_evidence_invalid")
			STRATEGY_OWNER_INTERNAL:
				owner_internal_count += 1
				if checkpoint_present:
					return _rejection(row, "checkpoint_method", strategy, "owner_api", "strategy_field_conflict")
		if not (row.get("dependencies") is Array):
			return _rejection(row, "dependencies", strategy, "registry", "wrong_type")
		var dependencies: Array = row.get("dependencies", [])
		for dependency in dependencies:
			if not (dependency is String or dependency is StringName) or str(dependency).is_empty():
				return _rejection(row, "dependencies", strategy, "registry", "invalid_dependency")
			if not restore_node_ids.has(str(dependency)):
				return _rejection(row, "dependencies", strategy, "registry", "missing_dependency")
		var expected_fingerprint := binding_contract_fingerprint(row)
		if not _lower_sha256(str(row.get("binding_contract_fingerprint", ""))) \
				or str(row.get("binding_contract_fingerprint", "")) != expected_fingerprint:
			return _rejection(row, "binding_contract_fingerprint", strategy, "registry", "value_mismatch")

	var observed_counts: Dictionary = contract.get("checkpoint_strategy_counts", {}) \
			if contract.get("checkpoint_strategy_counts", {}) is Dictionary else {}
	if configured_order != order:
		return _rejection({}, "configured_section_order", "", "registry", "registration_order_mismatch")
	if int(observed_counts.get(STRATEGY_EXPLICIT, -1)) != explicit_count \
			or int(observed_counts.get(STRATEGY_REGISTRY_MANAGED, -1)) != registry_managed_count \
			or int(observed_counts.get(STRATEGY_OWNER_INTERNAL, -1)) != owner_internal_count:
		return _rejection({}, "checkpoint_strategy_counts", "", "registry", "value_mismatch")
	if contract.has("contract_fingerprint") \
			and (not _lower_sha256(str(contract.get("contract_fingerprint", ""))) \
			or str(contract.get("contract_fingerprint", "")) != registry_contract_fingerprint(contract)):
		return _rejection({}, "contract_fingerprint", "", "registry", "value_mismatch")
	return {
		"valid": true,
		"reason_code": "registry_binding_contract_valid",
		"binding_count": rows.size(),
		"explicit_checkpoint_count": explicit_count,
		"registry_managed_checkpoint_count": registry_managed_count,
		"owner_internal_checkpoint_count": owner_internal_count,
		"omitted_checkpoint_method_count": omitted_count,
		"owner_without_transaction_semantics_count": 0,
	}


static func validate_projection(
	canonical_contract: Dictionary,
	observed_projection: Dictionary,
	registry: Node,
	expected_binding_count := -1
) -> Dictionary:
	var canonical_validation := validate(canonical_contract, registry, expected_binding_count)
	if not bool(canonical_validation.get("valid", false)):
		return canonical_validation
	if not (observed_projection.get("bindings") is Array):
		return _rejection({}, "bindings", "", "diagnostic_projection", "wrong_type")
	var canonical_rows := canonical_contract.get("bindings", []) as Array
	var observed_rows := observed_projection.get("bindings", []) as Array
	if observed_rows.size() != canonical_rows.size():
		return _rejection({}, "binding_count", "", "diagnostic_projection", "value_mismatch")
	for index in range(canonical_rows.size()):
		if not (canonical_rows[index] is Dictionary) or not (observed_rows[index] is Dictionary):
			return _rejection({}, "bindings", "", "diagnostic_projection", "row_wrong_type")
		var expected_row := canonical_rows[index] as Dictionary
		var actual_row := observed_rows[index] as Dictionary
		var expected_keys := expected_row.keys()
		var actual_keys := actual_row.keys()
		expected_keys.sort()
		actual_keys.sort()
		if expected_keys != actual_keys:
			return _rejection(
				actual_row, "binding_fields", str(actual_row.get("checkpoint_strategy", "")),
				"diagnostic_projection", "shape_mismatch"
			)
		for identity_field in ["section_index", "section_id", "owner_id"]:
			if actual_row.get(identity_field) != expected_row.get(identity_field):
				return _rejection(
					actual_row, identity_field, str(actual_row.get("checkpoint_strategy", "")),
					"diagnostic_projection", "value_mismatch"
				)
		for field in expected_keys:
			if str(field) in [
				"section_index", "section_id", "owner_id", "binding_contract_fingerprint",
			]:
				continue
			if actual_row.get(field) != expected_row.get(field):
				return _rejection(
					actual_row, str(field), str(actual_row.get("checkpoint_strategy", "")),
					"diagnostic_projection", "value_mismatch"
				)
		if actual_row.get("binding_contract_fingerprint") \
				!= expected_row.get("binding_contract_fingerprint"):
			return _rejection(
				actual_row, "binding_contract_fingerprint",
				str(actual_row.get("checkpoint_strategy", "")),
				"diagnostic_projection", "value_mismatch"
			)
	var expected_top_keys := canonical_contract.keys()
	var actual_top_keys := observed_projection.keys()
	expected_top_keys.sort()
	actual_top_keys.sort()
	if expected_top_keys != actual_top_keys:
		return _rejection({}, "contract_fields", "", "diagnostic_projection", "shape_mismatch")
	for field in expected_top_keys:
		if str(field) != "bindings" and observed_projection.get(field) != canonical_contract.get(field):
			return _rejection({}, str(field), "", "diagnostic_projection", "value_mismatch")
	return canonical_validation


static func diagnostic_failure(report: Dictionary) -> Dictionary:
	return {
		"schema_version": 1,
		"failure_field": str(report.get("failing_field", "save_registry")).left(64),
		"reason_code": FAILURE_REASON,
		"expected_summary": ("section=%s|owner=%s" % [
			str(report.get("failing_section_id", "save_registry")),
			str(report.get("failing_owner_id", "")),
		]).left(96),
		"actual_summary": ("strategy=%s|reason=%s" % [
			str(report.get("failing_strategy", "")),
			str(report.get("typed_reason", "unknown")),
		]).left(96),
		"private_payload_redacted": true,
	}


static func reseal_contract(contract: Dictionary) -> Dictionary:
	var sealed := contract.duplicate(true)
	var rows: Array = sealed.get("bindings", []) if sealed.get("bindings", []) is Array else []
	for index in range(rows.size()):
		if rows[index] is Dictionary:
			var row := (rows[index] as Dictionary).duplicate(true)
			row["binding_contract_fingerprint"] = binding_contract_fingerprint(row)
			rows[index] = row
	sealed["bindings"] = rows
	if sealed.has("contract_fingerprint"):
		sealed["contract_fingerprint"] = registry_contract_fingerprint(sealed)
	return sealed


static func binding_contract_fingerprint(row: Dictionary) -> String:
	var unsealed := row.duplicate(true)
	unsealed.erase("binding_contract_fingerprint")
	return JSON.stringify(unsealed, "", true, true).sha256_text().to_lower()


static func registry_contract_fingerprint(contract: Dictionary) -> String:
	var unsealed := contract.duplicate(true)
	unsealed.erase("contract_fingerprint")
	return JSON.stringify(unsealed, "", true, true).sha256_text().to_lower()


static func _rejection(
	row: Dictionary,
	failing_field: String,
	failing_strategy: String,
	failing_stage: String,
	typed_reason: String
) -> Dictionary:
	return {
		"valid": false,
		"reason_code": FAILURE_REASON,
		"failing_stage": failing_stage,
		"failing_section_id": str(row.get("section_id", "save_registry")),
		"failing_owner_id": str(row.get("owner_id", "")),
		"failing_field": failing_field,
		"failing_strategy": failing_strategy,
		"typed_reason": typed_reason,
		"private_payload_redacted": true,
	}


static func _validate_restore_dag(contract: Dictionary) -> Dictionary:
	if not (contract.get("restore_dag") is Array) \
			or not (contract.get("restore_dag_node_order") is Array):
		return _rejection({}, "restore_dag", "", "registry", "wrong_type")
	var restore_dag := contract.get("restore_dag", []) as Array
	var declared_order := contract.get("restore_dag_node_order", []) as Array
	if restore_dag.is_empty() or restore_dag.size() != declared_order.size():
		return _rejection({}, "restore_dag", "", "registry", "value_mismatch")
	var node_ids: Dictionary = {}
	var dependencies_by_node: Dictionary = {}
	for node_index in range(restore_dag.size()):
		if not (restore_dag[node_index] is Dictionary):
			return _rejection({}, "restore_dag", "", "registry", "row_wrong_type")
		var node := restore_dag[node_index] as Dictionary
		var node_id := str(node.get("node_id", ""))
		if not (node.get("node_index") is int) or int(node.get("node_index", -1)) != node_index:
			return _rejection({}, "restore_dag.node_index", "", "registry", "registration_order_mismatch")
		if node_id.is_empty() or node_id != str(declared_order[node_index]):
			return _rejection({}, "restore_dag.node_id", "", "registry", "registration_order_mismatch")
		if node_ids.has(node_id):
			return _rejection({}, "restore_dag.node_id", "", "registry", "duplicate")
		if str(node.get("section_id", "")).is_empty():
			return _rejection({}, "restore_dag.section_id", "", "registry", "missing")
		if not (node.get("dependencies") is Array):
			return _rejection({}, "restore_dag.dependencies", "", "registry", "wrong_type")
		node_ids[node_id] = true
		dependencies_by_node[node_id] = (node.get("dependencies", []) as Array).duplicate()
	for node_id in dependencies_by_node:
		for dependency in dependencies_by_node[node_id] as Array:
			if not node_ids.has(str(dependency)):
				return _rejection({}, "restore_dag.dependencies", "", "registry", "missing_dependency")
	var cyclic_node := _first_cyclic_node(dependencies_by_node)
	if not cyclic_node.is_empty():
		return _rejection({}, "restore_dag.dependencies", "", "registry", "dependency_cycle")
	return {"valid": true, "node_ids": node_ids}


static func _first_cyclic_node(dependencies_by_node: Dictionary) -> String:
	var resolved: Dictionary = {}
	var remaining: Array[String] = []
	for node_id in dependencies_by_node:
		remaining.append(str(node_id))
	remaining.sort()
	while not remaining.is_empty():
		var progressed := false
		for node_id in remaining.duplicate():
			var dependencies := dependencies_by_node.get(node_id, []) as Array
			var dependencies_resolved := true
			for dependency in dependencies:
				if not resolved.has(str(dependency)):
					dependencies_resolved = false
					break
			if dependencies_resolved:
				resolved[node_id] = true
				remaining.erase(node_id)
				progressed = true
		if not progressed:
			return remaining[0]
	return ""


static func _lower_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for index in range(value.length()):
		if not "0123456789abcdef".contains(value.substr(index, 1)):
			return false
	return true
