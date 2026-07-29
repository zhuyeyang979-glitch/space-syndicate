extends SceneTree

const StrictState := preload("res://scripts/runtime/save_owner_state_v2_contract.gd")
const RULESET_PROFILE := preload("res://resources/rules/space_syndicate_ruleset_v06.tres")
const RULESET_OWNER_SCENE := preload("res://scenes/runtime/RulesetSaveAttestationOwner.tscn")
const ROUTE_SCENE := preload("res://scenes/runtime/RouteNetworkRuntimeController.tscn")
const MILITARY_SCENE := preload("res://scenes/runtime/MilitaryRuntimeController.tscn")
const QUEUE_SCENE := preload("res://scenes/runtime/CardResolutionQueueRuntimeService.tscn")

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
	_test_ruleset_attestation()
	_test_routes_v2()
	_test_military_v2()
	_test_queue_v2()
	_finish()


func _test_ruleset_attestation() -> void:
	var owner := RULESET_OWNER_SCENE.instantiate() as RulesetSaveAttestationOwner
	root.add_child(owner)
	var saved := owner.to_save_data()
	_expect(bool(owner.preflight_save_data(saved).get("accepted", false)), "Ruleset immutable attestation passes strict preflight")
	_expect(StrictState.has_exact_keys(saved, ["schema_version", "ruleset_id", "profile_schema_version", "ruleset_profile_id", "ruleset_fingerprint", "compatibility_profile_fingerprint", "balance_fingerprint", "content_manifest_fingerprint"]), "Ruleset persists only the frozen immutable attestation fields")
	_expect(str(saved.get("ruleset_profile_id", "")) == "v0.6", "Ruleset attests the active v0.6 profile")
	_expect(str(owner.debug_snapshot().get("compatibility_profile_id", "")) == "v0.4", "Ruleset fingerprint is sourced from the current v0.4 compatibility profile")
	_expect(_fingerprints_valid(saved), "Ruleset, compatibility, balance, and content fingerprints are canonical SHA-256 values")
	_expect(not StrictState.contains_rng_continuation(saved), "Ruleset attestation owns zero RNG continuation")
	_expect(_apply_exact(owner, saved), "Ruleset immutable apply verifies without mutation")
	_expect(_apply_exact(owner, saved), "Ruleset immutable apply is repeatable")
	_expect(_preflight_rejects_without_mutation(owner, _with(saved, "unknown", true)), "Ruleset rejects an unknown top-level field")
	var missing := saved.duplicate(true)
	missing.erase("content_manifest_fingerprint")
	_expect(_preflight_rejects_without_mutation(owner, missing), "Ruleset rejects a missing top-level field")
	_expect(_preflight_rejects_without_mutation(owner, _with(saved, "schema_version", 99)), "Ruleset rejects a wrong schema version")
	_expect(_preflight_rejects_without_mutation(owner, _with(saved, "profile_schema_version", INF)), "Ruleset rejects a non-finite value")
	var forged := saved.duplicate(true)
	forged["compatibility_profile_fingerprint"] = "0".repeat(64)
	_expect(_preflight_rejects_without_mutation(owner, forged), "Ruleset rejects a compatibility-profile fingerprint mismatch")
	var checkpoint := owner.capture_runtime_checkpoint()
	_expect(bool(owner.restore_runtime_checkpoint(checkpoint).get("restored", false)) and owner.to_save_data() == saved, "Ruleset rollback re-verifies the immutable checkpoint")
	owner.queue_free()


func _test_routes_v2() -> void:
	var bridge := FakeRouteBridge.new()
	bridge.topology = _route_topology("route-topology-v2")
	root.add_child(bridge)
	var routes := ROUTE_SCENE.instantiate() as RouteNetworkRuntimeController
	root.add_child(routes)
	routes.set_world_bridge(bridge)
	_expect(bool(routes.configure(RULESET_PROFILE.debug_snapshot()).get("configured", false)), "Routes configure from the active v0.6 profile")
	_expect(bool(routes.refresh_routes(true).get("refreshed", false)), "Routes build a deterministic base manifest")
	var saved := routes.to_save_data()
	_expect(int(saved.get("schema_version", -1)) == 2 and int(routes.debug_snapshot().get("route_count", 0)) > 0, "Routes capture strict schema v2 without candidate-cache payload")
	_expect(StrictState.has_exact_keys(saved, ["schema_version", "ruleset_id", "route_semantic_version", "saved_topology_revision", "rebuilt_route_fingerprint"]), "Routes save only semantic, topology, and rebuild attestations")
	_expect(bool(routes.preflight_save_data(saved).get("accepted", false)), "Routes state v2 passes pure preflight")
	_expect(not StrictState.contains_rng_continuation(saved), "Routes own zero RNG continuation")
	_expect(_apply_exact(routes, saved), "Routes rebuild to byte-equivalent save state")
	_expect(_apply_exact(routes, saved), "Routes repeated apply preserves rebuild parity")
	_expect(_preflight_rejects_without_mutation(routes, _with(saved, "unknown", true)), "Routes reject an unknown top-level field")
	var missing := saved.duplicate(true)
	missing.erase("route_semantic_version")
	_expect(_preflight_rejects_without_mutation(routes, missing), "Routes reject a missing top-level field")
	_expect(_preflight_rejects_without_mutation(routes, _with(saved, "schema_version", 1)), "Routes reject a wrong schema version")
	_expect(_preflight_rejects_without_mutation(routes, _with(saved, "route_semantic_version", INF)), "Routes reject a non-finite value")
	var runtime_checkpoint := routes.capture_runtime_checkpoint()
	var forged_manifest := saved.duplicate(true)
	forged_manifest["rebuilt_route_fingerprint"] = "0".repeat(64)
	var forged_result := routes.apply_save_data(forged_manifest)
	_expect(not bool(forged_result.get("applied", true)) and routes.capture_runtime_checkpoint() == runtime_checkpoint, "Routes reject rebuild mismatch and restore the exact internal checkpoint")
	bridge.topology = _route_topology("different-topology")
	var before_dangling := routes.to_save_data()
	var dangling_result := routes.apply_save_data(saved)
	_expect(not bool(dangling_result.get("applied", true)) and routes.to_save_data() == before_dangling, "Routes reject a dangling topology binding with zero mutation")
	bridge.topology = _route_topology("route-topology-v2")
	routes.refresh_routes(true)
	var exact_checkpoint := routes.capture_runtime_checkpoint()
	routes.refresh_routes(true)
	_expect(bool(routes.restore_runtime_checkpoint(exact_checkpoint).get("restored", false)) and routes.capture_runtime_checkpoint() == exact_checkpoint, "Routes restore derived caches and diagnostic counters exactly")
	_expect(bool(routes.rollback_save_data(saved).get("applied", false)) and routes.to_save_data() == saved, "Routes save rollback rebuilds the original manifest")
	routes.queue_free()
	bridge.queue_free()


func _test_military_v2() -> void:
	var military := MILITARY_SCENE.instantiate() as MilitaryRuntimeController
	root.add_child(military)
	var seeded := military.to_save_data()
	seeded["military_units"] = [_military_unit(1)]
	seeded["next_military_unit_uid"] = 2
	_expect(StrictState.has_exact_keys(seeded, ["schema_version", "ruleset_id", "military_units", "next_military_unit_uid", "bankruptcy_estate_journal"]), "Military persists only its frozen v2 authority fields")
	_expect(bool(military.preflight_save_data(seeded).get("accepted", false)), "Military state v2 passes strict UID and finite-value preflight")
	_expect(bool(military.apply_save_data(seeded).get("applied", false)) and military.to_save_data() == seeded, "Military state v2 applies exactly")
	_expect(_apply_exact(military, seeded), "Military repeated apply preserves its authored state")
	_expect(not StrictState.contains_rng_continuation(seeded), "Military owns zero RNG continuation")
	_expect(_preflight_rejects_without_mutation(military, _with(seeded, "unknown", true)), "Military rejects an unknown top-level field")
	var missing := seeded.duplicate(true)
	missing.erase("bankruptcy_estate_journal")
	_expect(_preflight_rejects_without_mutation(military, missing), "Military rejects a missing top-level field")
	_expect(_preflight_rejects_without_mutation(military, _with(seeded, "schema_version", 1)), "Military rejects a wrong schema version")
	var nonfinite := seeded.duplicate(true)
	((nonfinite.get("military_units") as Array)[0] as Dictionary)["cooldown_left"] = INF
	_expect(_preflight_rejects_without_mutation(military, nonfinite), "Military rejects non-finite unit continuation")
	var duplicate := seeded.duplicate(true)
	(duplicate.get("military_units") as Array).append(_military_unit(1))
	_expect(_preflight_rejects_without_mutation(military, duplicate), "Military rejects duplicate unit UIDs")
	_expect(_preflight_rejects_without_mutation(military, _with(seeded, "next_military_unit_uid", 1)), "Military rejects a dangling next UID")
	var dangling_motion := seeded.duplicate(true)
	((dangling_motion.get("military_units") as Array)[0] as Dictionary)["linear_move_unit_label"] = "dangling"
	_expect(_preflight_rejects_without_mutation(military, dangling_motion), "Military rejects a partially bound movement continuation")
	var checkpoint := military.capture_runtime_checkpoint()
	military.replace_runtime_state([], 1)
	_expect(military.to_save_data() != checkpoint, "Military mutation changes the authoritative checkpoint")
	_expect(bool(military.restore_runtime_checkpoint(checkpoint).get("restored", false)) and military.to_save_data() == checkpoint, "Military rollback restores units, UID, cooldowns, and journal exactly")
	military.queue_free()


func _test_queue_v2() -> void:
	var queue := QUEUE_SCENE.instantiate() as CardResolutionQueueRuntimeService
	root.add_child(queue)
	queue.configure({"ruleset_id": "v0.6", "card_group": RULESET_PROFILE.card_group_rules()})
	var plan := queue.plan_submission(_queue_request(), {"player_count": 3, "simultaneous_timer": 45.0, "window_sequence": 0})
	var committed := queue.commit_submission(plan, {
		"authorized": true,
		"inventory_committed": true,
		"play_cost_authorized": true,
		"financial_margin_authorized": true,
		"asset_authorized": true,
	})
	_expect(bool(plan.get("accepted", false)) and bool(committed.get("committed", false)), "Queue fixture commits through the real v0.6 planning path")
	var saved := queue.to_save_data()
	_expect(int(saved.get("schema_version", -1)) == 2 and bool(queue.preflight_save_data(saved).get("accepted", false)), "Queue schema v2 passes strict preflight")
	_expect(StrictState.has_exact_keys(saved, ["schema_version", "ruleset_id", "revision", "current_queue", "active_entry", "next_queue", "resolution_sequence", "last_group_window_sequence"]), "Queue persists only its frozen v2 authority fields")
	_expect(not StrictState.contains_rng_continuation(saved), "Queue owns zero RNG continuation")
	_expect(_apply_exact(queue, saved), "Queue state v2 applies exactly")
	_expect(_apply_exact(queue, saved), "Queue repeated apply preserves revision and lineage cursors")
	_expect(_preflight_rejects_without_mutation(queue, _with(saved, "unknown", true)), "Queue rejects an unknown top-level field")
	var missing := saved.duplicate(true)
	missing.erase("revision")
	_expect(_preflight_rejects_without_mutation(queue, missing), "Queue rejects a missing top-level field")
	_expect(_preflight_rejects_without_mutation(queue, _with(saved, "schema_version", 1)), "Queue rejects a wrong schema version")
	var nonfinite := saved.duplicate(true)
	((nonfinite.get("current_queue") as Array)[0] as Dictionary)["diagnostic_time"] = INF
	_expect(_preflight_rejects_without_mutation(queue, nonfinite), "Queue rejects a non-finite nested continuation")
	var duplicate := saved.duplicate(true)
	(duplicate.get("next_queue") as Array).append(((duplicate.get("current_queue") as Array)[0] as Dictionary).duplicate(true))
	_expect(_preflight_rejects_without_mutation(queue, duplicate), "Queue rejects duplicate resolution IDs across current and waiting entries")
	var dangling_reservation := saved.duplicate(true)
	var dangling_entry := (dangling_reservation.get("current_queue") as Array)[0] as Dictionary
	dangling_entry["asset_reservation_required"] = true
	dangling_entry["asset_reservation_id"] = ""
	_expect(_preflight_rejects_without_mutation(queue, dangling_reservation), "Queue rejects a dangling asset reservation reference")
	_expect(_preflight_rejects_without_mutation(queue, _with(saved, "resolution_sequence", 0)), "Queue rejects a dangling resolution-sequence cursor")
	var checkpoint := queue.capture_runtime_checkpoint()
	queue.plan_submission({}, {})
	queue.replace_current_queue([])
	_expect(bool(queue.restore_runtime_checkpoint(checkpoint).get("restored", false)) and queue.capture_runtime_checkpoint() == checkpoint and queue.to_save_data() == saved, "Queue rollback restores current/active/waiting state, lineage, and diagnostics exactly")
	queue.queue_free()


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


func _military_unit(uid: int) -> Dictionary:
	return {
		"uid": uid,
		"owner": 0,
		"position": 0,
		"world_position": Vector2(120.0, 80.0),
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


func _queue_request() -> Dictionary:
	return {
		"player_index": 0,
		"slot_index": 0,
		"already_queued": false,
		"available_cash_cents": 50000,
		"play_cash_cost_cents": 0,
		"financial_margin_cents": 0,
		"financial_terms_version": "none",
		"cash_revision": "cash:0",
		"skill": {"name": "测试策略", "kind": "strategy", "rank": 1, "persistent": false},
	}


func _apply_exact(owner: Object, state: Dictionary) -> bool:
	var receipt: Dictionary = owner.call("apply_save_data", state.duplicate(true))
	return bool(receipt.get("applied", false)) and owner.call("to_save_data") == state


func _preflight_rejects_without_mutation(owner: Object, candidate: Dictionary) -> bool:
	var before: Dictionary = owner.call("to_save_data")
	var receipt: Dictionary = owner.call("preflight_save_data", candidate)
	return not bool(receipt.get("accepted", true)) and owner.call("to_save_data") == before


func _with(source: Dictionary, key: String, value: Variant) -> Dictionary:
	var result := source.duplicate(true)
	result[key] = value
	return result


func _fingerprints_valid(saved: Dictionary) -> bool:
	for key in ["ruleset_fingerprint", "compatibility_profile_fingerprint", "balance_fingerprint", "content_manifest_fingerprint"]:
		if str(saved.get(key, "")).length() != 64:
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	var passed := _failures.is_empty()
	print("SAVE_OWNER_DOMAIN_V2_TRANSACTION_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if passed else "FAIL", _checks, _failures.size()])
	if not passed:
		push_error("Save owner domain v2 transaction test failed:\n- %s" % "\n- ".join(_failures))
	quit(0 if passed else 1)
