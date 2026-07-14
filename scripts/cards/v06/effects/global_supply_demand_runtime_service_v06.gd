extends RefCounted
class_name GlobalSupplyDemandRuntimeServiceV06

const SUPPORT := preload("res://scripts/cards/v06/effects/card_effect_adapter_support_v06.gd")
const RULESET_ID := "v0.6"
const OBSERVATION_WINDOW_SECONDS := 30
const VALID_EFFECT_KINDS := ["global_order_budget", "global_supply_spawn"]
const VALID_INDUSTRY_IDS := ["life", "energy", "industry", "technology", "commerce", "shipping"]
const VALID_ROUTE_MODES := ["land", "sea", "air", "direct", "local"]
const VALID_BUDGETS := [20, 40, 80, 160]

var _batch_sink: Object
var _candidate_snapshot_revision := -1
var _candidate_snapshot_fingerprint := ""
var _candidates: Array[Dictionary] = []
var _capacity_resource_limits: Dictionary = {}
var _transaction_journal: Dictionary = {}
var _batch_receipts: Array[Dictionary] = []
var _batch_sequence := 0


func set_batch_sink(batch_sink: Object) -> Dictionary:
	_batch_sink = batch_sink
	var configured := (
		_batch_sink != null
		and _batch_sink.has_method("prepare_batch")
		and _batch_sink.has_method("commit_batch")
		and _batch_sink.has_method("rollback_batch")
	)
	if not configured:
		_batch_sink = null
	return {"configured": configured, "reason_code": "configured" if configured else "batch_sink_contract_invalid"}


func replace_authoritative_candidates(snapshot_revision: int, candidates: Array) -> Dictionary:
	if snapshot_revision < 0:
		return _setup_failure("candidate_snapshot_revision_invalid")
	var normalized: Array[Dictionary] = []
	var candidate_ids: Dictionary = {}
	var goods_gdp: Dictionary = {}
	var resource_limits: Dictionary = {}
	for candidate_variant in candidates:
		if not (candidate_variant is Dictionary):
			return _setup_failure("candidate_not_dictionary")
		var result := _normalize_candidate(candidate_variant as Dictionary)
		if not bool(result.get("valid", false)):
			return _setup_failure(str(result.get("reason_code", "candidate_invalid")))
		var candidate: Dictionary = result.get("candidate", {}) as Dictionary
		var candidate_id := str(candidate.get("candidate_id", ""))
		if candidate_ids.has(candidate_id):
			return _setup_failure("candidate_id_duplicate")
		candidate_ids[candidate_id] = true
		var goods_key := _goods_key(candidate)
		var gdp := int(candidate.get("matching_product_gdp_30s", 0))
		if goods_gdp.has(goods_key) and int(goods_gdp[goods_key]) != gdp:
			return _setup_failure("goods_gdp_inconsistent_across_routes")
		goods_gdp[goods_key] = gdp
		var route: Dictionary = candidate.get("route", {}) as Dictionary
		for resource_variant in route.get("capacity_resources", []):
			var resource: Dictionary = resource_variant
			var resource_id := str(resource.get("resource_id", ""))
			var available_units := int(resource.get("available_units", -1))
			if resource_limits.has(resource_id) and int(resource_limits[resource_id]) != available_units:
				return _setup_failure("capacity_resource_snapshot_inconsistent")
			resource_limits[resource_id] = available_units
		normalized.append(candidate)
	normalized.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return str(first.get("candidate_id", "")) < str(second.get("candidate_id", "")))
	var fingerprint := SUPPORT.fingerprint({"candidates": normalized, "capacity_resources": resource_limits})
	if snapshot_revision < _candidate_snapshot_revision:
		return _setup_failure("candidate_snapshot_stale")
	if snapshot_revision == _candidate_snapshot_revision:
		if fingerprint != _candidate_snapshot_fingerprint:
			return _setup_failure("candidate_snapshot_revision_collision")
		return {"configured": true, "reason_code": "configured", "idempotent_replay": true, "candidate_snapshot": candidate_snapshot_metadata()}
	_candidate_snapshot_revision = snapshot_revision
	_candidate_snapshot_fingerprint = fingerprint
	_candidates = normalized
	_capacity_resource_limits = resource_limits
	return {"configured": true, "reason_code": "configured", "idempotent_replay": false, "candidate_snapshot": candidate_snapshot_metadata()}


func candidate_snapshot_metadata() -> Dictionary:
	return {
		"configured": _candidate_snapshot_revision >= 0,
		"ruleset_id": RULESET_ID,
		"revision": _candidate_snapshot_revision,
		"fingerprint": _candidate_snapshot_fingerprint,
		"candidate_count": _candidates.size(),
		"capacity_resource_count": _capacity_resource_limits.size(),
		"observation_window_seconds": OBSERVATION_WINDOW_SECONDS,
		"batch_sink_configured": _batch_sink != null,
	}


func preview_batch(request: Dictionary) -> Dictionary:
	if _candidate_snapshot_revision < 0:
		return _plan_failure(request, "candidate_snapshot_unavailable")
	if not _is_pure_data(request):
		return _plan_failure(request, "request_not_pure_data")
	var transaction_id := str(request.get("transaction_id", "")).strip_edges()
	var intent_hash := str(request.get("intent_hash", "")).strip_edges()
	var actor_player_index := int(request.get("actor_player_index", -1))
	var effect_kind := str(request.get("effect_kind", ""))
	if transaction_id.is_empty() or intent_hash.is_empty():
		return _plan_failure(request, "transaction_binding_missing")
	if actor_player_index < 0:
		return _plan_failure(request, "actor_player_index_invalid")
	if int(request.get("expected_candidate_snapshot_revision", -1)) != _candidate_snapshot_revision:
		return _plan_failure(request, "candidate_snapshot_revision_changed")
	var payload: Dictionary = request.get("effect_payload", {}) if request.get("effect_payload", {}) is Dictionary else {}
	var spec := _effect_spec(effect_kind, payload)
	if not bool(spec.get("valid", false)):
		return _plan_failure(request, str(spec.get("reason_code", "effect_payload_invalid")))
	var eligible: Array[Dictionary] = []
	var rejected_candidate_ids: Array[String] = []
	for candidate in _candidates:
		if _candidate_matches_spec(candidate, spec):
			eligible.append(candidate.duplicate(true))
		else:
			rejected_candidate_ids.append(str(candidate.get("candidate_id", "")))
	var actor_has_positive_matching_gdp := false
	for candidate in eligible:
		if int(candidate.get("commodity_owner_player_index", -1)) == actor_player_index and int(candidate.get("matching_product_gdp_30s", 0)) > 0:
			actor_has_positive_matching_gdp = true
			break
	if not actor_has_positive_matching_gdp:
		return _plan_failure(request, "actor_matching_product_gdp_not_positive")
	var groups := _goods_groups(eligible)
	if groups.is_empty():
		return _plan_failure(request, "matching_goods_unavailable")
	var budget_units := int(spec.get("budget_units", 0))
	var allocation_result := _allocate_budget(budget_units, groups, spec)
	var allocations: Array = allocation_result.get("allocations", []) if allocation_result.get("allocations", []) is Array else []
	var allocated_units := int(allocation_result.get("allocated_units", 0))
	var plan := {
		"ready": true,
		"committed": false,
		"reason_code": "ready",
		"transaction_id": transaction_id,
		"intent_hash": intent_hash,
		"binding": (request.get("binding", {}) as Dictionary).duplicate(true) if request.get("binding", {}) is Dictionary else {},
		"actor_player_index": actor_player_index,
		"effect_kind": effect_kind,
		"one_time_effect_kind": str(spec.get("one_time_effect_kind", "")),
		"budget_units": budget_units,
		"allocated_units": allocated_units,
		"unallocated_units": budget_units - allocated_units,
		"allocations": allocations,
		"eligible_candidate_count": eligible.size(),
		"rejected_candidate_ids": rejected_candidate_ids,
		"candidate_snapshot_revision": _candidate_snapshot_revision,
		"candidate_snapshot_fingerprint": _candidate_snapshot_fingerprint,
		"observation_window_seconds": OBSERVATION_WINDOW_SECONDS,
		"allocation_method": "integer_largest_remainder_with_iterative_capacity_redistribution_and_best_route_fill",
		"shared_capacity_resources_enforced": true,
		"permanent_production_rate_delta": 0,
		"permanent_demand_rate_delta": 0,
		"facility_owner_reward_units": 0,
		"requires_atomic_batch_sink": true,
	}
	plan["plan_hash"] = SUPPORT.fingerprint(plan)
	return plan


func commit_batch(plan: Dictionary) -> Dictionary:
	var transaction_id := str(plan.get("transaction_id", "")).strip_edges()
	var intent_hash := str(plan.get("intent_hash", "")).strip_edges()
	if transaction_id.is_empty() or intent_hash.is_empty():
		return _commit_failure(plan, "transaction_binding_missing")
	if _transaction_journal.has(transaction_id):
		var journal_entry: Dictionary = _transaction_journal[transaction_id]
		if str(journal_entry.get("intent_hash", "")) != intent_hash:
			return _commit_failure(plan, "transaction_intent_collision")
		var replay: Dictionary = journal_entry.get("receipt", {}) as Dictionary
		replay = replay.duplicate(true)
		replay["duplicate"] = true
		return replay
	if not bool(plan.get("ready", false)):
		return _remember_terminal(plan, _commit_failure(plan, "plan_not_ready"))
	var unhashed := plan.duplicate(true)
	unhashed.erase("plan_hash")
	if str(plan.get("plan_hash", "")) != SUPPORT.fingerprint(unhashed):
		return _remember_terminal(plan, _commit_failure(plan, "plan_hash_invalid"))
	if int(plan.get("candidate_snapshot_revision", -2)) != _candidate_snapshot_revision or str(plan.get("candidate_snapshot_fingerprint", "")) != _candidate_snapshot_fingerprint:
		return _remember_terminal(plan, _commit_failure(plan, "candidate_snapshot_revision_changed"))
	if _batch_sink == null:
		return _remember_terminal(plan, _commit_failure(plan, "batch_sink_unavailable"))
	var sink_prepare_variant: Variant = _batch_sink.call("prepare_batch", plan.duplicate(true))
	if not (sink_prepare_variant is Dictionary):
		return _remember_terminal(plan, _commit_failure(plan, "batch_sink_prepare_invalid"))
	var sink_prepared: Dictionary = sink_prepare_variant
	if not bool(sink_prepared.get("prepared", false)):
		return _remember_terminal(plan, _commit_failure(plan, str(sink_prepared.get("reason_code", "batch_sink_prepare_rejected"))))
	if not _sink_binding_matches(sink_prepared, plan):
		return _remember_terminal(plan, _commit_failure(plan, "batch_sink_prepare_binding_invalid"))
	var sink_commit_variant: Variant = _batch_sink.call("commit_batch", sink_prepared.duplicate(true))
	if not (sink_commit_variant is Dictionary):
		return _remember_terminal(plan, _commit_failure(plan, "batch_sink_commit_invalid"))
	var sink_receipt: Dictionary = sink_commit_variant
	if not bool(sink_receipt.get("committed", false)):
		return _remember_terminal(plan, _commit_failure(plan, str(sink_receipt.get("reason_code", "batch_sink_commit_rejected"))))
	if not _sink_binding_matches(sink_receipt, plan):
		_batch_sink.call("rollback_batch", sink_receipt.duplicate(true))
		return _remember_terminal(plan, _commit_failure(plan, "batch_sink_commit_binding_invalid"))
	_batch_sequence += 1
	var receipt := {
		"receipt_kind": "global_supply_demand_rights_batch",
		"transaction_id": transaction_id,
		"intent_hash": intent_hash,
		"plan_hash": str(plan.get("plan_hash", "")),
		"committed": true,
		"duplicate": false,
		"reason": "committed",
		"reason_code": "committed",
		"batch_id": "supply-demand-rights-%08d" % _batch_sequence,
		"batch_sequence": _batch_sequence,
		"actor_player_index": int(plan.get("actor_player_index", -1)),
		"effect_kind": str(plan.get("effect_kind", "")),
		"one_time_effect_kind": str(plan.get("one_time_effect_kind", "")),
		"budget_units": int(plan.get("budget_units", 0)),
		"allocated_units": int(plan.get("allocated_units", 0)),
		"unallocated_units": int(plan.get("unallocated_units", 0)),
		"allocations": (plan.get("allocations", []) as Array).duplicate(true),
		"candidate_snapshot_revision": _candidate_snapshot_revision,
		"observation_window_seconds": OBSERVATION_WINDOW_SECONDS,
		"does_not_change_permanent_rates": true,
		"permanent_production_rate_delta": 0,
		"permanent_demand_rate_delta": 0,
		"facility_owner_reward_units": 0,
		"sink_receipt": sink_receipt.duplicate(true),
		"rolled_back": false,
	}
	_batch_receipts.append(receipt.duplicate(true))
	return _remember_terminal(plan, receipt)


func rollback_batch(receipt: Dictionary) -> Dictionary:
	var transaction_id := str(receipt.get("transaction_id", "")).strip_edges()
	if transaction_id.is_empty() or not _transaction_journal.has(transaction_id):
		return {"rolled_back": false, "committed": false, "reason_code": "batch_receipt_missing", "transaction_id": transaction_id}
	var journal_entry: Dictionary = _transaction_journal[transaction_id]
	var stored: Dictionary = journal_entry.get("receipt", {}) as Dictionary
	if str(stored.get("intent_hash", "")) != str(receipt.get("intent_hash", "")):
		return {"rolled_back": false, "committed": false, "reason_code": "batch_receipt_binding_invalid", "transaction_id": transaction_id}
	if bool(stored.get("rolled_back", false)):
		return {"rolled_back": true, "committed": false, "reason_code": "rolled_back", "transaction_id": transaction_id, "idempotent_replay": true}
	if not bool(stored.get("committed", false)) or _batch_sink == null:
		return {"rolled_back": false, "committed": false, "reason_code": "batch_not_rollbackable", "transaction_id": transaction_id}
	var sink_receipt: Dictionary = stored.get("sink_receipt", {}) if stored.get("sink_receipt", {}) is Dictionary else {}
	var rollback_variant: Variant = _batch_sink.call("rollback_batch", sink_receipt.duplicate(true))
	if not (rollback_variant is Dictionary) or not bool((rollback_variant as Dictionary).get("rolled_back", false)):
		return {"rolled_back": false, "committed": false, "reason_code": "batch_sink_rollback_failed", "transaction_id": transaction_id}
	stored["committed"] = false
	stored["rolled_back"] = true
	stored["reason"] = "rolled_back"
	stored["reason_code"] = "rolled_back"
	journal_entry["receipt"] = stored.duplicate(true)
	_transaction_journal[transaction_id] = journal_entry
	for index in range(_batch_receipts.size()):
		if str(_batch_receipts[index].get("transaction_id", "")) == transaction_id:
			_batch_receipts[index] = stored.duplicate(true)
	return {"rolled_back": true, "committed": false, "reason_code": "rolled_back", "transaction_id": transaction_id, "sink_rollback": (rollback_variant as Dictionary).duplicate(true)}


func batch_receipts_snapshot(include_rolled_back := true) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for receipt in _batch_receipts:
		if include_rolled_back or not bool(receipt.get("rolled_back", false)):
			result.append(receipt.duplicate(true))
	return result


func journal_snapshot() -> Dictionary:
	return _transaction_journal.duplicate(true)


func debug_snapshot() -> Dictionary:
	return {
		"runtime_owner": "GlobalSupplyDemandRuntimeServiceV06",
		"ownership_scope": "rights_planning_and_atomic_batch_orchestration_only",
		"ruleset_id": RULESET_ID,
		"candidate_snapshot": candidate_snapshot_metadata(),
		"active_batch_count": batch_receipts_snapshot(false).size(),
		"audit_batch_count": _batch_receipts.size(),
		"permanent_rate_mutation_count": 0,
		"transaction_count": _transaction_journal.size(),
		"production_flow_sink_required": true,
		"pure_data": _is_pure_data({"receipts": _batch_receipts, "journal": _transaction_journal}),
	}


func _allocate_budget(budget_units: int, groups: Dictionary, spec: Dictionary) -> Dictionary:
	var resource_remaining := _capacity_resource_limits.duplicate(true)
	var candidate_remaining: Dictionary = {}
	var allocated_by_candidate: Dictionary = {}
	var group_keys: Array[String] = []
	for group_key_variant in groups.keys():
		group_keys.append(str(group_key_variant))
	group_keys.sort()
	for group_key in group_keys:
		var group: Dictionary = groups[group_key]
		for candidate_variant in group.get("candidates", []):
			var candidate: Dictionary = candidate_variant
			var candidate_id := str(candidate.get("candidate_id", ""))
			candidate_remaining[candidate_id] = int(candidate.get("available_capacity_units", 0))
			allocated_by_candidate[candidate_id] = 0
	var remaining_units := budget_units
	while remaining_units > 0:
		var active_rows: Array[Dictionary] = []
		for group_key in group_keys:
			var capacity := _group_capacity_preview(groups[group_key] as Dictionary, resource_remaining, candidate_remaining)
			if capacity > 0:
				active_rows.append({"key": group_key, "weight": int((groups[group_key] as Dictionary).get("gdp_weight", 0))})
		if active_rows.is_empty():
			break
		var proposed := _largest_remainder(remaining_units, active_rows)
		var progress := 0
		for group_key in group_keys:
			var requested := int(proposed.get(group_key, 0))
			if requested <= 0:
				continue
			progress += _allocate_group_routes(groups[group_key] as Dictionary, requested, resource_remaining, candidate_remaining, allocated_by_candidate)
		remaining_units -= progress
		if progress <= 0:
			break
	var allocations: Array[Dictionary] = []
	var allocated_units := 0
	for group_key in group_keys:
		var group: Dictionary = groups[group_key]
		for candidate_variant in group.get("candidates", []):
			var candidate: Dictionary = candidate_variant
			var allocated := int(allocated_by_candidate.get(str(candidate.get("candidate_id", "")), 0))
			allocated_units += allocated
			allocations.append(_allocation_row(candidate, spec, allocated))
	allocations.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return str(first.get("candidate_id", "")) < str(second.get("candidate_id", "")))
	return {"allocations": allocations, "allocated_units": allocated_units, "unallocated_units": budget_units - allocated_units}


func _group_capacity_preview(group: Dictionary, resource_remaining: Dictionary, candidate_remaining: Dictionary) -> int:
	var resources := resource_remaining.duplicate(true)
	var candidates := candidate_remaining.duplicate(true)
	var capacity := 0
	for candidate_variant in group.get("candidates", []):
		var candidate: Dictionary = candidate_variant
		var available := _route_available_capacity(candidate, resources, candidates)
		capacity += available
		_consume_route_capacity(candidate, available, resources, candidates)
	return capacity


func _allocate_group_routes(group: Dictionary, requested_units: int, resource_remaining: Dictionary, candidate_remaining: Dictionary, allocated_by_candidate: Dictionary) -> int:
	var remaining := requested_units
	var allocated := 0
	for candidate_variant in group.get("candidates", []):
		if remaining <= 0:
			break
		var candidate: Dictionary = candidate_variant
		var available := _route_available_capacity(candidate, resource_remaining, candidate_remaining)
		var grant := mini(remaining, available)
		if grant <= 0:
			continue
		var candidate_id := str(candidate.get("candidate_id", ""))
		allocated_by_candidate[candidate_id] = int(allocated_by_candidate.get(candidate_id, 0)) + grant
		_consume_route_capacity(candidate, grant, resource_remaining, candidate_remaining)
		remaining -= grant
		allocated += grant
	return allocated


func _route_available_capacity(candidate: Dictionary, resource_remaining: Dictionary, candidate_remaining: Dictionary) -> int:
	var candidate_id := str(candidate.get("candidate_id", ""))
	var available := maxi(0, int(candidate_remaining.get(candidate_id, 0)))
	var route: Dictionary = candidate.get("route", {}) as Dictionary
	for resource_variant in route.get("capacity_resources", []):
		var resource: Dictionary = resource_variant
		available = mini(available, maxi(0, int(resource_remaining.get(str(resource.get("resource_id", "")), 0))))
	return available


func _consume_route_capacity(candidate: Dictionary, units: int, resource_remaining: Dictionary, candidate_remaining: Dictionary) -> void:
	if units <= 0:
		return
	var candidate_id := str(candidate.get("candidate_id", ""))
	candidate_remaining[candidate_id] = maxi(0, int(candidate_remaining.get(candidate_id, 0)) - units)
	var route: Dictionary = candidate.get("route", {}) as Dictionary
	for resource_variant in route.get("capacity_resources", []):
		var resource: Dictionary = resource_variant
		var resource_id := str(resource.get("resource_id", ""))
		resource_remaining[resource_id] = maxi(0, int(resource_remaining.get(resource_id, 0)) - units)


func _largest_remainder(total_units: int, rows: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	if total_units <= 0 or rows.is_empty():
		return result
	var total_weight := 0
	for row in rows:
		total_weight += maxi(0, int(row.get("weight", 0)))
	if total_weight <= 0:
		return result
	var remainders: Array[Dictionary] = []
	var assigned := 0
	for row in rows:
		var key := str(row.get("key", ""))
		var weight := maxi(0, int(row.get("weight", 0)))
		var numerator := total_units * weight
		@warning_ignore("integer_division")
		var base_units: int = numerator / total_weight
		result[key] = base_units
		assigned += base_units
		remainders.append({"key": key, "remainder": numerator % total_weight})
	remainders.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		var first_remainder := int(first.get("remainder", 0))
		var second_remainder := int(second.get("remainder", 0))
		return first_remainder > second_remainder if first_remainder != second_remainder else str(first.get("key", "")) < str(second.get("key", ""))
	)
	var remaining := total_units - assigned
	for index in range(mini(remaining, remainders.size())):
		var key := str(remainders[index].get("key", ""))
		result[key] = int(result.get(key, 0)) + 1
	return result


func _effect_spec(effect_kind: String, payload: Dictionary) -> Dictionary:
	if not VALID_EFFECT_KINDS.has(effect_kind):
		return {"valid": false, "reason_code": "effect_kind_invalid"}
	if str(payload.get("route_tag_match_mode", "")) != "any_segment_in_multimodal_route" \
		or str(payload.get("allocation_basis", "")) != "matching_product_gdp_share_30s" \
		or not bool(payload.get("requires_positive_owner_matching_product_gdp", false)) \
		or not bool(payload.get("uses_real_route_capacity", false)) \
		or not bool(payload.get("requires_real_market_or_factory_nodes", false)):
		return {"valid": false, "reason_code": "effect_payload_contract_mismatch"}
	if effect_kind == "global_order_budget":
		var budget := int(payload.get("budget_units", 0))
		if not VALID_BUDGETS.has(budget) or str(payload.get("required_route_tag", "")) != "sea" or str(payload.get("distance_rule", "")) != "remote_gt_2" or not bool(payload.get("may_exceed_persistent_demand", false)) or not bool(payload.get("requires_real_market_node", false)):
			return {"valid": false, "reason_code": "order_payload_contract_mismatch"}
		return {"valid": true, "budget_units": budget, "required_route_mode": "sea", "distance_rule": "remote_gt_2", "facility_type": "market", "one_time_effect_kind": "extra_demand"}
	var spawn_units := int(payload.get("spawn_units", 0))
	if not VALID_BUDGETS.has(spawn_units) or str(payload.get("required_route_tag", "")) != "land" or str(payload.get("distance_rule", "")) != "near_lte_2" or not bool(payload.get("creates_one_time_physical_goods", false)) or bool(payload.get("is_permanent_installation", true)) or not bool(payload.get("requires_legal_production_factory", false)):
		return {"valid": false, "reason_code": "supply_payload_contract_mismatch"}
	return {"valid": true, "budget_units": spawn_units, "required_route_mode": "land", "distance_rule": "near_lte_2", "facility_type": "factory", "one_time_effect_kind": "physical_supply"}


func _candidate_matches_spec(candidate: Dictionary, spec: Dictionary) -> bool:
	if int(candidate.get("matching_product_gdp_30s", 0)) <= 0:
		return false
	var facility: Dictionary = candidate.get("facility", {}) as Dictionary
	var route: Dictionary = candidate.get("route", {}) as Dictionary
	if str(facility.get("facility_type", "")) != str(spec.get("facility_type", "")):
		return false
	var mode_tags: Array = route.get("mode_tags", []) as Array
	if not mode_tags.has(str(spec.get("required_route_mode", ""))):
		return false
	var distance := int(route.get("shortest_legal_distance", -1))
	return distance > 2 if str(spec.get("distance_rule", "")) == "remote_gt_2" else distance <= 2


func _goods_groups(eligible: Array[Dictionary]) -> Dictionary:
	var groups: Dictionary = {}
	for candidate in eligible:
		var key := _goods_key(candidate)
		if not groups.has(key):
			groups[key] = {"goods_key": key, "gdp_weight": int(candidate.get("matching_product_gdp_30s", 0)), "candidates": []}
		(groups[key]["candidates"] as Array).append(candidate.duplicate(true))
	for key_variant in groups.keys():
		(groups[key_variant]["candidates"] as Array).sort_custom(_route_better)
	return groups


func _route_better(first: Dictionary, second: Dictionary) -> bool:
	var first_route: Dictionary = first.get("route", {}) as Dictionary
	var second_route: Dictionary = second.get("route", {}) as Dictionary
	var first_net := int(first_route.get("expected_owner_net_cash", 0))
	var second_net := int(second_route.get("expected_owner_net_cash", 0))
	if first_net != second_net:
		return first_net > second_net
	var first_arrival := int(first_route.get("arrival_milliseconds", 0))
	var second_arrival := int(second_route.get("arrival_milliseconds", 0))
	if first_arrival != second_arrival:
		return first_arrival < second_arrival
	var first_transfers := int(first_route.get("transfer_count", 0))
	var second_transfers := int(second_route.get("transfer_count", 0))
	if first_transfers != second_transfers:
		return first_transfers < second_transfers
	return str(first_route.get("route_id", "")) < str(second_route.get("route_id", ""))


func _allocation_row(candidate: Dictionary, spec: Dictionary, allocated_units: int) -> Dictionary:
	var facility: Dictionary = candidate.get("facility", {}) as Dictionary
	var region: Dictionary = candidate.get("region", {}) as Dictionary
	var product: Dictionary = candidate.get("product", {}) as Dictionary
	var route: Dictionary = candidate.get("route", {}) as Dictionary
	return {
		"candidate_id": str(candidate.get("candidate_id", "")),
		"goods_key": _goods_key(candidate),
		"product_id": str(product.get("product_id", "")),
		"industry_id": str(product.get("industry_id", "")),
		"commodity_owner_player_index": int(candidate.get("commodity_owner_player_index", -1)),
		"beneficiary_player_index": int(candidate.get("commodity_owner_player_index", -1)),
		"facility_owner_player_index": int(facility.get("owner_player_index", -1)),
		"facility_owner_reward_units": 0,
		"facility_id": str(facility.get("facility_id", "")),
		"facility_type": str(facility.get("facility_type", "")),
		"source_facility_id": str(route.get("source_facility_id", "")),
		"market_facility_id": str(route.get("market_facility_id", "")),
		"region_id": str(region.get("region_id", "")),
		"region_revision": int(region.get("revision", -1)),
		"route_id": str(route.get("route_id", "")),
		"topology_revision": route.get("topology_revision", ""),
		"route_mode_tags": (route.get("mode_tags", []) as Array).duplicate(true),
		"shortest_legal_distance": int(route.get("shortest_legal_distance", -1)),
		"capacity_resource_ids": _resource_ids(route.get("capacity_resources", []) as Array),
		"matching_product_gdp_30s": int(candidate.get("matching_product_gdp_30s", 0)),
		"allocated_units": allocated_units,
		"one_time_effect_kind": str(spec.get("one_time_effect_kind", "")),
		"permanent_rate_delta": 0,
	}


func _normalize_candidate(source: Dictionary) -> Dictionary:
	if not _is_pure_data(source):
		return {"valid": false, "reason_code": "candidate_not_pure_data"}
	var candidate_id := str(source.get("candidate_id", "")).strip_edges()
	var facility: Dictionary = source.get("facility", {}) if source.get("facility", {}) is Dictionary else {}
	var region: Dictionary = source.get("region", {}) if source.get("region", {}) is Dictionary else {}
	var product: Dictionary = source.get("product", {}) if source.get("product", {}) is Dictionary else {}
	var route: Dictionary = source.get("route", {}) if source.get("route", {}) is Dictionary else {}
	var facility_id := str(facility.get("facility_id", "")).strip_edges()
	var facility_type := str(facility.get("facility_type", ""))
	var region_id := str(region.get("region_id", "")).strip_edges()
	var product_id := str(product.get("product_id", "")).strip_edges()
	var industry_id := str(product.get("industry_id", ""))
	var commodity_owner := int(source.get("commodity_owner_player_index", -1))
	var gdp := int(source.get("matching_product_gdp_30s", -1))
	var candidate_capacity := int(source.get("available_capacity_units", -1))
	if candidate_id.is_empty() or facility_id.is_empty() or region_id.is_empty() or product_id.is_empty():
		return {"valid": false, "reason_code": "candidate_identity_invalid"}
	if not ["factory", "market"].has(facility_type) or not bool(facility.get("active", false)):
		return {"valid": false, "reason_code": "candidate_facility_invalid"}
	if str(facility.get("region_id", "")) != region_id or int(facility.get("owner_player_index", -1)) < 0:
		return {"valid": false, "reason_code": "candidate_facility_identity_invalid"}
	if not VALID_INDUSTRY_IDS.has(industry_id) or str(facility.get("industry_id", "")) != industry_id:
		return {"valid": false, "reason_code": "candidate_industry_invalid"}
	if int(region.get("revision", -1)) < 0 or ["ruined", "destroyed"].has(str(region.get("lifecycle_state", ""))):
		return {"valid": false, "reason_code": "candidate_region_invalid"}
	if commodity_owner < 0 or gdp < 0 or candidate_capacity < 0:
		return {"valid": false, "reason_code": "candidate_economy_invalid"}
	var mode_tags_result := _normalized_mode_tags(route.get("mode_tags", route.get("route_mode_tags", [])))
	if not bool(mode_tags_result.get("valid", false)):
		return {"valid": false, "reason_code": str(mode_tags_result.get("reason_code", "candidate_route_mode_invalid"))}
	var shortest_distance := int(route.get("shortest_legal_distance", route.get("distance", -1)))
	var topology_revision: Variant = route.get("topology_revision", route.get("revision", ""))
	var route_id := str(route.get("route_id", candidate_id)).strip_edges()
	var source_facility_id := str(route.get("source_facility_id", "")).strip_edges()
	var market_facility_id := str(route.get("market_facility_id", "")).strip_edges()
	if shortest_distance < 0 or str(topology_revision).strip_edges().is_empty() or route_id.is_empty() or source_facility_id.is_empty() or market_facility_id.is_empty():
		return {"valid": false, "reason_code": "candidate_route_invalid"}
	if (facility_type == "factory" and source_facility_id != facility_id) or (facility_type == "market" and market_facility_id != facility_id):
		return {"valid": false, "reason_code": "candidate_route_endpoint_mismatch"}
	var resources_result := _normalized_capacity_resources(route.get("capacity_resources", []))
	if not bool(resources_result.get("valid", false)):
		return {"valid": false, "reason_code": str(resources_result.get("reason_code", "capacity_resources_invalid"))}
	return {
		"valid": true,
		"candidate": {
			"candidate_id": candidate_id,
			"facility": {"facility_id": facility_id, "facility_type": facility_type, "industry_id": industry_id, "region_id": region_id, "owner_player_index": int(facility.get("owner_player_index", -1)), "active": true},
			"region": {"region_id": region_id, "revision": int(region.get("revision", -1)), "lifecycle_state": str(region.get("lifecycle_state", "active"))},
			"product": {"product_id": product_id, "industry_id": industry_id},
			"commodity_owner_player_index": commodity_owner,
			"matching_product_gdp_30s": gdp,
			"available_capacity_units": candidate_capacity,
			"route": {
				"route_id": route_id,
				"source_facility_id": source_facility_id,
				"market_facility_id": market_facility_id,
				"mode_tags": mode_tags_result.get("mode_tags", []),
				"shortest_legal_distance": shortest_distance,
				"topology_revision": topology_revision,
				"capacity_resources": resources_result.get("resources", []),
				"expected_owner_net_cash": int(route.get("expected_owner_net_cash", 0)),
				"arrival_milliseconds": maxi(0, int(route.get("arrival_milliseconds", 0))),
				"transfer_count": maxi(0, int(route.get("transfer_count", 0))),
			},
		},
	}


func _normalized_mode_tags(value: Variant) -> Dictionary:
	if not (value is Array):
		return {"valid": false, "reason_code": "candidate_route_mode_invalid"}
	var mode_tags: Array[String] = []
	for mode_variant in value as Array:
		var mode := str(mode_variant)
		if not VALID_ROUTE_MODES.has(mode):
			return {"valid": false, "reason_code": "candidate_route_mode_invalid"}
		if not mode_tags.has(mode):
			mode_tags.append(mode)
	if mode_tags.is_empty():
		return {"valid": false, "reason_code": "candidate_route_mode_missing"}
	mode_tags.sort()
	return {"valid": true, "mode_tags": mode_tags}


func _normalized_capacity_resources(value: Variant) -> Dictionary:
	if not (value is Array) or (value as Array).is_empty():
		return {"valid": false, "reason_code": "capacity_resources_missing"}
	var resources: Array[Dictionary] = []
	var seen: Dictionary = {}
	for resource_variant in value as Array:
		if not (resource_variant is Dictionary):
			return {"valid": false, "reason_code": "capacity_resource_invalid"}
		var resource: Dictionary = resource_variant
		var resource_id := str(resource.get("resource_id", "")).strip_edges()
		var available_units := int(resource.get("available_units", -1))
		if resource_id.is_empty() or available_units < 0 or seen.has(resource_id):
			return {"valid": false, "reason_code": "capacity_resource_invalid"}
		seen[resource_id] = true
		resources.append({"resource_id": resource_id, "available_units": available_units})
	resources.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return str(first.get("resource_id", "")) < str(second.get("resource_id", "")))
	return {"valid": true, "resources": resources}


func _resource_ids(resources: Array) -> Array[String]:
	var result: Array[String] = []
	for resource_variant in resources:
		result.append(str((resource_variant as Dictionary).get("resource_id", "")))
	return result


func _goods_key(candidate: Dictionary) -> String:
	var product: Dictionary = candidate.get("product", {}) as Dictionary
	return "%08d|%s" % [int(candidate.get("commodity_owner_player_index", -1)), str(product.get("product_id", ""))]


func _sink_binding_matches(receipt: Dictionary, plan: Dictionary) -> bool:
	return (
		str(receipt.get("transaction_id", "")) == str(plan.get("transaction_id", ""))
		and str(receipt.get("intent_hash", "")) == str(plan.get("intent_hash", ""))
		and str(receipt.get("plan_hash", "")) == str(plan.get("plan_hash", ""))
	)


func _remember_terminal(plan: Dictionary, receipt: Dictionary) -> Dictionary:
	var transaction_id := str(plan.get("transaction_id", ""))
	if not transaction_id.is_empty():
		_transaction_journal[transaction_id] = {"intent_hash": str(plan.get("intent_hash", "")), "plan_hash": str(plan.get("plan_hash", "")), "receipt": receipt.duplicate(true)}
	return receipt


func _setup_failure(reason_code: String) -> Dictionary:
	return {"configured": false, "reason_code": reason_code}


func _plan_failure(request: Dictionary, reason_code: String) -> Dictionary:
	return {"ready": false, "committed": false, "transaction_id": str(request.get("transaction_id", "")), "intent_hash": str(request.get("intent_hash", "")), "reason_code": reason_code}


func _commit_failure(plan: Dictionary, reason_code: String) -> Dictionary:
	return {"receipt_kind": "global_supply_demand_rights_batch", "transaction_id": str(plan.get("transaction_id", "")), "intent_hash": str(plan.get("intent_hash", "")), "plan_hash": str(plan.get("plan_hash", "")), "committed": false, "duplicate": false, "reason": reason_code, "reason_code": reason_code}


func _is_pure_data(value: Variant) -> bool:
	if value == null or value is bool or value is int or value is float or value is String:
		return true
	if value is Array:
		for child_variant in value:
			if not _is_pure_data(child_variant):
				return false
		return true
	if value is Dictionary:
		for key_variant in value.keys():
			if not (key_variant is String) or not _is_pure_data(value[key_variant]):
				return false
		return true
	return false
