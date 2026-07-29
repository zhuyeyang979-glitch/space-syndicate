extends SceneTree

const StrictState := preload("res://scripts/runtime/save_owner_state_v2_contract.gd")
const SimulationIdentityScript := preload("res://scripts/runtime/simulation_state_identity.gd")
const RULESET_PROFILE := preload("res://resources/rules/space_syndicate_ruleset_v06.tres")
const RULESET_OWNER_SCENE := preload("res://scenes/runtime/RulesetSaveAttestationOwner.tscn")
const ROUTE_SCENE := preload("res://scenes/runtime/RouteNetworkRuntimeController.tscn")
const MILITARY_SCENE := preload("res://scenes/runtime/MilitaryRuntimeController.tscn")
const QUEUE_SCENE := preload("res://scenes/runtime/CardResolutionQueueRuntimeService.tscn")
const RNG_SCENE := preload("res://scenes/runtime/RunRngService.tscn")

const SOURCE_TOPOLOGY_REVISION := "alpha04c-fork-source"
const CONTINUATION_TOPOLOGY_REVISION := "alpha04c-fork-continuation"
const RNG_SEED := 0x5A17C04

var _checks := 0
var _failures: Array[String] = []


class FakeRouteBridge:
	extends Node
	var topology: Dictionary = {}

	func capture_route_topology() -> Dictionary:
		return topology.duplicate(true)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var source := _build_stack("Source")
	var source_seed := _seed_source(source)
	_expect(bool(source_seed.get("ok", false)), "source checkpoint is produced through real owner mutations")
	var checkpoint := _capture_save(source)
	var checkpoint_fingerprint := StrictState.fingerprint(checkpoint)
	_expect(checkpoint_fingerprint.length() == 64, "source checkpoint has a canonical SHA-256 fingerprint")
	_free_stack(source)

	var fork_a := _build_stack("ForkA")
	var fork_b := _build_stack("ForkB")
	var divergent_fork := _build_stack("DivergentFork")
	_expect(_restore_stack(fork_a, checkpoint), "fork A restores every checkpoint section exactly")
	_expect(_restore_stack(fork_b, checkpoint), "fork B restores every checkpoint section exactly")
	_expect(_restore_stack(divergent_fork, checkpoint), "sensitivity fork restores the same checkpoint exactly")
	_expect(_capture_save(fork_a) == checkpoint and _capture_save(fork_b) == checkpoint, "independent forks begin from byte-equivalent authoritative state")

	var outcome_a := _continue_stack(fork_a, 0)
	var outcome_b := _continue_stack(fork_b, 0)
	var divergent_outcome := _continue_stack(divergent_fork, 1)
	_expect(bool(outcome_a.get("ok", false)) and bool(outcome_b.get("ok", false)), "both forks complete the same deterministic continuation actions")
	_expect(outcome_a.get("trace", []) == outcome_b.get("trace", []), "fork action receipts and RNG draws are identical")
	_expect(outcome_a.get("summary", {}) == outcome_b.get("summary", {}), "fork critical summaries are identical")
	_expect(str(outcome_a.get("fingerprint", "")) == str(outcome_b.get("fingerprint", "")), "fork continuation state/trace SHA-256 fingerprints are identical")
	_expect(str(outcome_a.get("fingerprint", "")).length() == 64, "fork parity fingerprint is canonical SHA-256")
	_expect(str(outcome_a.get("save_fingerprint", "")) != checkpoint_fingerprint, "continuation advances the authoritative state beyond the checkpoint")
	_expect(bool(divergent_outcome.get("ok", false)), "sensitivity fork completes its alternate valid action")
	_expect(str(divergent_outcome.get("fingerprint", "")) != str(outcome_a.get("fingerprint", "")), "a different post-restore action produces a different continuation hash")

	_free_stack(fork_a)
	_free_stack(fork_b)
	_free_stack(divergent_fork)
	_finish()


func _build_stack(label: String) -> Dictionary:
	var host := Node.new()
	host.name = label
	root.add_child(host)

	var bridge := FakeRouteBridge.new()
	bridge.name = "RouteBridge"
	bridge.topology = _route_topology(SOURCE_TOPOLOGY_REVISION)
	host.add_child(bridge)

	var ruleset := RULESET_OWNER_SCENE.instantiate() as RulesetSaveAttestationOwner
	var routes := ROUTE_SCENE.instantiate() as RouteNetworkRuntimeController
	var military := MILITARY_SCENE.instantiate() as MilitaryRuntimeController
	var queue := QUEUE_SCENE.instantiate() as CardResolutionQueueRuntimeService
	var rng := RNG_SCENE.instantiate() as RunRngService
	host.add_child(ruleset)
	host.add_child(routes)
	host.add_child(military)
	host.add_child(queue)
	host.add_child(rng)

	routes.set_world_bridge(bridge)
	var route_configuration := routes.configure(RULESET_PROFILE.debug_snapshot())
	var route_refresh := routes.refresh_routes(true)
	queue.configure({"ruleset_id": "v0.6", "card_group": RULESET_PROFILE.card_group_rules()})
	return {
		"host": host,
		"bridge": bridge,
		"ruleset": ruleset,
		"routes": routes,
		"military": military,
		"queue": queue,
		"rng": rng,
		"ready": bool(route_configuration.get("configured", false))
			and bool(route_refresh.get("refreshed", false))
			and int(route_refresh.get("route_count", 0)) > 0,
	}


func _seed_source(stack: Dictionary) -> Dictionary:
	if not bool(stack.get("ready", false)):
		return {"ok": false}
	var military := stack.get("military") as MilitaryRuntimeController
	var queue := stack.get("queue") as CardResolutionQueueRuntimeService
	var rng := stack.get("rng") as RunRngService

	var military_state := military.to_save_data()
	military_state["military_units"] = [_military_unit(1, 0, 0), _military_unit(2, 1, 1)]
	military_state["next_military_unit_uid"] = 3
	var military_receipt := military.apply_save_data(military_state)
	var queue_result := _submit_card(queue, 0, 0, 45.0)
	rng.set_seed(RNG_SEED)
	var warmup_draw := rng.randi_range(100, 999)
	return {
		"ok": bool(military_receipt.get("applied", false))
			and bool(queue_result.get("committed", false))
			and warmup_draw >= 100,
	}


func _restore_stack(stack: Dictionary, checkpoint: Dictionary) -> bool:
	if not bool(stack.get("ready", false)):
		return false
	var ruleset := stack.get("ruleset") as RulesetSaveAttestationOwner
	var routes := stack.get("routes") as RouteNetworkRuntimeController
	var military := stack.get("military") as MilitaryRuntimeController
	var queue := stack.get("queue") as CardResolutionQueueRuntimeService
	var rng := stack.get("rng") as RunRngService
	var ruleset_receipt := ruleset.apply_save_data((checkpoint.get("ruleset") as Dictionary).duplicate(true))
	var route_receipt := routes.apply_save_data((checkpoint.get("routes") as Dictionary).duplicate(true))
	var military_receipt := military.apply_save_data((checkpoint.get("military") as Dictionary).duplicate(true))
	var queue_receipt := queue.apply_save_data((checkpoint.get("queue") as Dictionary).duplicate(true))
	var rng_receipt := rng.apply_save_data((checkpoint.get("rng") as Dictionary).duplicate(true))
	return bool(ruleset_receipt.get("applied", false)) \
		and bool(route_receipt.get("applied", false)) \
		and bool(military_receipt.get("applied", false)) \
		and bool(queue_receipt.get("applied", false)) \
		and bool(rng_receipt.get("applied", false)) \
		and _capture_save(stack) == checkpoint


func _continue_stack(stack: Dictionary, bankrupt_owner: int) -> Dictionary:
	var bridge := stack.get("bridge") as FakeRouteBridge
	var routes := stack.get("routes") as RouteNetworkRuntimeController
	var military := stack.get("military") as MilitaryRuntimeController
	var queue := stack.get("queue") as CardResolutionQueueRuntimeService
	var rng := stack.get("rng") as RunRngService

	bridge.topology = _route_topology(CONTINUATION_TOPOLOGY_REVISION)
	var route_refresh := routes.refresh_routes(true)
	var route_candidates := routes.all_route_candidates("life")

	var queue_submission := _submit_card(queue, 1, 0, 44.0)
	var queue_lock := queue.lock_batch({"reference_player": 0, "player_count": 3})
	var queue_start := queue.start_next({"game_time": 8.0})
	var active_entry: Dictionary = queue_start.get("active_entry", {}) if queue_start.get("active_entry", {}) is Dictionary else {}
	var queue_complete := queue.complete_active(int(active_entry.get("resolution_id", -1)), {"outcome": "resolved"})

	var transaction := {"transaction_id": "alpha04c.fork.bankruptcy", "player_indices": [bankrupt_owner]}
	var military_prepare := military.bankruptcy_estate_stage("prepare", transaction)
	var military_commit := military.bankruptcy_estate_stage("commit", transaction)
	var military_finalize := military.bankruptcy_estate_stage("finalize", transaction)

	var integer_draw := rng.randi_range(10, 100000)
	var float_draw := rng.randf_range(-5.0, 5.0)
	var trace: Array = [
		{
			"action": "route_refresh_and_query",
			"refreshed": bool(route_refresh.get("refreshed", false)),
			"rebuilt": bool(route_refresh.get("rebuilt", false)),
			"topology_revision": str(route_refresh.get("topology_revision", "")),
			"route_count": route_candidates.size(),
			"route_fingerprint": StrictState.fingerprint(route_candidates),
		},
		{
			"action": "queue_submit_lock_start_complete",
			"planned": bool(queue_submission.get("planned", false)),
			"committed": bool(queue_submission.get("committed", false)),
			"resolution_id": int(queue_submission.get("resolution_id", -1)),
			"locked": bool(queue_lock.get("locked", false)),
			"started": bool(queue_start.get("started", false)),
			"completed": bool(queue_complete.get("completed", false)),
			"completed_resolution_id": int((queue_complete.get("entry", {}) as Dictionary).get("resolution_id", -1)) if queue_complete.get("entry", {}) is Dictionary else -1,
		},
		{
			"action": "military_bankruptcy_finalize",
			"player_index": bankrupt_owner,
			"prepared": bool(military_prepare.get("prepared", false)),
			"committed": bool(military_commit.get("committed", false)),
			"finalized": bool(military_finalize.get("finalized", false)),
			"estate_counts": (military_finalize.get("estate_counts", {}) as Dictionary).duplicate(true),
		},
		{
			"action": "rng_draws",
			"integer": integer_draw,
			"float": float_draw,
		},
	]
	var save_state := _capture_save(stack)
	var summary := _critical_summary(save_state, route_candidates.size())
	var identity := SimulationIdentityScript.new()
	var identity_result := identity.identify(save_state, trace)
	var ok := bool(route_refresh.get("refreshed", false)) \
		and not route_candidates.is_empty() \
		and bool(queue_submission.get("committed", false)) \
		and bool(queue_lock.get("locked", false)) \
		and bool(queue_start.get("started", false)) \
		and bool(queue_complete.get("completed", false)) \
		and bool(military_prepare.get("prepared", false)) \
		and bool(military_commit.get("committed", false)) \
		and bool(military_finalize.get("finalized", false)) \
		and bool(identity_result.get("valid", false))
	return {
		"ok": ok,
		"trace": trace,
		"summary": summary,
		"fingerprint": str(identity_result.get("fingerprint", "")),
		"save_fingerprint": StrictState.fingerprint(save_state),
	}


func _submit_card(queue: CardResolutionQueueRuntimeService, player_index: int, slot_index: int, remaining_time: float) -> Dictionary:
	var request := {
		"player_index": player_index,
		"slot_index": slot_index,
		"already_queued": false,
		"available_cash_cents": 50000,
		"play_cash_cost_cents": 0,
		"financial_margin_cents": 0,
		"financial_terms_version": "none",
		"cash_revision": "cash:%d" % player_index,
		"skill": {
			"name": "fork-parity-card-%d-%d" % [player_index, slot_index],
			"kind": "strategy",
			"rank": 1,
			"persistent": false,
		},
	}
	var facts := {
		"player_count": 3,
		"batch_locked": false,
		"counter_window_active": false,
		"simultaneous_timer": remaining_time,
		"lock_duration": 5.0,
		"public_bid_duration": 5.0,
		"window_sequence": 0,
		"reference_player": 0,
	}
	var plan := queue.plan_submission(request, facts)
	var commit: Dictionary = {}
	if bool(plan.get("accepted", false)):
		commit = queue.commit_submission(plan, {
			"authorized": true,
			"inventory_committed": true,
			"play_cost_authorized": true,
			"financial_margin_authorized": true,
			"asset_authorized": true,
		})
	var entry: Dictionary = commit.get("entry", {}) if commit.get("entry", {}) is Dictionary else {}
	return {
		"planned": bool(plan.get("accepted", false)),
		"committed": bool(commit.get("committed", false)),
		"resolution_id": int(entry.get("resolution_id", -1)),
	}


func _capture_save(stack: Dictionary) -> Dictionary:
	return {
		"ruleset": (stack.get("ruleset") as RulesetSaveAttestationOwner).to_save_data(),
		"routes": (stack.get("routes") as RouteNetworkRuntimeController).to_save_data(),
		"military": (stack.get("military") as MilitaryRuntimeController).to_save_data(),
		"queue": (stack.get("queue") as CardResolutionQueueRuntimeService).to_save_data(),
		"rng": (stack.get("rng") as RunRngService).to_save_data(),
	}


func _critical_summary(save_state: Dictionary, route_count: int) -> Dictionary:
	var ruleset := save_state.get("ruleset") as Dictionary
	var routes := save_state.get("routes") as Dictionary
	var military := save_state.get("military") as Dictionary
	var queue := save_state.get("queue") as Dictionary
	var rng := save_state.get("rng") as Dictionary
	return {
		"ruleset_profile_id": str(ruleset.get("ruleset_profile_id", "")),
		"ruleset_fingerprint": str(ruleset.get("ruleset_fingerprint", "")),
		"route_topology_revision": str(routes.get("saved_topology_revision", "")),
		"route_manifest_fingerprint": str(routes.get("rebuilt_route_fingerprint", "")),
		"route_count": route_count,
		"military_unit_uids": _field_values(military.get("military_units", []) as Array, "uid"),
		"military_next_uid": int(military.get("next_military_unit_uid", -1)),
		"military_journal_fingerprint": StrictState.fingerprint(military.get("bankruptcy_estate_journal", {})),
		"queue_revision": int(queue.get("revision", -1)),
		"queue_resolution_sequence": int(queue.get("resolution_sequence", -1)),
		"queue_current_resolution_ids": _field_values(queue.get("current_queue", []) as Array, "resolution_id"),
		"queue_active_resolution_id": int((queue.get("active_entry", {}) as Dictionary).get("resolution_id", -1)) if queue.get("active_entry", {}) is Dictionary else -1,
		"queue_next_resolution_ids": _field_values(queue.get("next_queue", []) as Array, "resolution_id"),
		"rng_state": int(rng.get("rng_state", 0)),
		"section_fingerprints": {
			"ruleset": StrictState.fingerprint(ruleset),
			"routes": StrictState.fingerprint(routes),
			"military": StrictState.fingerprint(military),
			"queue": StrictState.fingerprint(queue),
			"rng": StrictState.fingerprint(rng),
		},
	}


func _field_values(rows: Array, field: String) -> Array:
	var values: Array = []
	for row_variant in rows:
		if row_variant is Dictionary:
			values.append((row_variant as Dictionary).get(field))
	return values


func _route_topology(revision: String) -> Dictionary:
	return {
		"ruleset_id": "v0.6",
		"topology_revision": revision,
		"regions": [
			{"region_id": "region-a", "legacy_index": 0, "lifecycle_state": "active", "terrain_id": "land", "integrity_basis_points": 10000, "neighbor_region_ids": ["region-b"]},
			{"region_id": "region-b", "legacy_index": 1, "lifecycle_state": "active", "terrain_id": "land", "integrity_basis_points": 10000, "neighbor_region_ids": ["region-a"]},
		],
		"facilities": [],
	}


func _military_unit(uid: int, owner: int, position: int) -> Dictionary:
	return {
		"uid": uid,
		"owner": owner,
		"position": position,
		"world_position": Vector2(120.0 + float(position) * 80.0, 80.0),
		"cooldown_left": 1.5,
		"public_owner_revealed": false,
		"rank": 1,
		"name": "行星防卫军",
		"source_card": "行星防卫军1",
		"military_type": "defense",
		"military_domain": "mixed",
		"movement_traits": ["land"],
		"terrain_move_multiplier": {"land": 1.0, "ocean": 0.25},
		"military_gdp_penalty": 0,
		"military_gdp_pressure_seconds": 0.0,
		"military_strike_gdp_penalty": 0,
		"military_strike_route_damage": 0,
		"hp": 8,
		"max_hp": 8,
		"damage": 1,
		"range": 220.0,
		"move": 260.0,
		"duration": 28.0,
		"remaining_time": 24.0,
	}


func _free_stack(stack: Dictionary) -> void:
	var host_variant: Variant = stack.get("host")
	if host_variant is Node and is_instance_valid(host_variant):
		(host_variant as Node).free()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	var passed := _failures.is_empty()
	print("ALPHA04C_SAVE_FORK_DETERMINISM_PARITY_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if passed else "FAIL", _checks, _failures.size()])
	if not passed:
		push_error("ALPHA_0_4_C save fork determinism parity test failed:\n- %s" % "\n- ".join(_failures))
	quit(0 if passed else 1)
