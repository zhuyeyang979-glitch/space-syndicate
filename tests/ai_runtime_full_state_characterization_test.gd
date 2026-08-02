extends SceneTree

const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")
const RULESET_V04 := preload("res://resources/rules/space_syndicate_ruleset_v04.tres")
const SEMANTIC_WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const AI_SAVE_WIRE_CODEC := preload("res://scripts/runtime/ai_runtime_save_wire_codec_v3.gd")

const SAFE_PATH_FIELDS := [
	"schema_version", "ruleset_id", "policy_profile_id", "policy_fingerprint",
	"request_sequence", "ai_card_decision_timer", "ai_auction_reaction_timer",
	"ai_intel_decision_timer", "ai_card_decision_enabled", "player_states",
	"player_index", "ai_profile", "ai_memory", "profile_index", "name", "style",
	"build_bias", "business_bias", "monster_bias", "economy_bias",
	"bid_aggression", "exploration", "route_preferences", "decision_samples",
	"action_counts", "last_plan", "economic_focus_product", "economic_focus_score",
	"economic_focus_reason", "economic_focus_cycle", "economic_focus_rankings",
	"strategic_intent", "strategic_intent_score", "strategic_intent_reason",
	"strategic_intent_cycle", "strategic_intent_rankings", "route_plan_product",
	"route_plan_stage", "route_plan_score", "route_plan_reason", "route_plan_cycle",
	"route_plan_target_city", "route_plan_partner_district", "route_plan_rankings",
	"game_phase", "competitive_posture", "score_gap_to_leader", "leader_index",
	"phase_reason", "learned_policy_values", "learning_updates",
	"learning_last_reward", "learning_last_tags", "episode_learning_updates",
	"episode_last_reward", "episode_last_top_n_gdp",
	"episode_last_controlled_regions", "episode_last_rank", "episode_last_result",
	"training_note", "time", "cycle", "kind", "target", "score", "reason",
	"state", "candidates", "focus_product", "focus_score", "focus_reason",
	"strategy_intent", "strategy_score", "strategy_reason", "route_plan_score",
	"game_phase", "competitive_posture", "score_gap_to_leader", "leader_index",
	"phase_reason", "endgame_urgency", "baseline_cash", "baseline_victory_gdp",
	"baseline_victory_regions", "reward_cash", "reward_victory_gdp",
	"reward_victory_regions", "reward_score", "reward_finalized",
	"learning_applied", "value", "samples", "reward_total", "last_reward",
	"last_cycle", "save_state", "last_receipts",
	"card_target_pre_submit_rejection_count", "tick_timing_count",
	"tick_timing_total_usec", "tick_timing_max_usec", "actor_state_tick_cache",
	"actor_state_tick_cache_active", "actor_state_tick_cache_hit_count",
	"actor_state_tick_cache_miss_count", "intent_id", "action_id", "applied",
	"context_revision", "codec", "bits", "$codec",
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var coordinator := COORDINATOR_SCENE.instantiate() as GameRuntimeCoordinator
	root.add_child(coordinator)
	await process_frame
	coordinator.configure(RULESET_V04.debug_snapshot())
	var world := coordinator.world_session_state()
	var catalog := coordinator.get_node_or_null("RoleCatalogRuntimeService") as RoleCatalogRuntimeService
	var session := coordinator.get_node_or_null("GameSessionRuntimeController") as GameSessionRuntimeController
	var ai := coordinator.get_node_or_null("AiRuntimeController") as AiRuntimeController
	var port := coordinator.get_node_or_null("AiActorStatePort") as AiActorStatePort
	if world == null or catalog == null or session == null or ai == null or port == null:
		_failures.append("production_ai_owner_dependencies_missing")
		_finish({})
		return

	session.configure({"ruleset_id": "v0.6"}, {})
	session.begin_session({
		"session_id": "alpha04c-ai-characterization",
		"scenario_id": "typed-owner-fixture",
		"seed": 900626424,
		"player_count": 4,
	})
	world.restore({
		"players": [
			_player(catalog, 0, false),
			_player(catalog, 1, true),
			_player(catalog, 2, true),
			_player(catalog, 3, true),
		],
		"districts": [],
		"game_time": 17.25,
		"map_width_m": 1000.0,
		"map_height_m": 600.0,
		"world_geometry_revision": 2,
	}, true)
	ai.configure({"ruleset_id": "v0.6"})
	ai._ensure_player_ai_state()
	ai.tick(0.0)

	var empty_runtime_state := ai._capture_save_runtime_state()
	var empty_save := ai.to_save_data()
	var empty_new_session_checkpoint := ai.capture_new_session_checkpoint()
	var empty_analysis := _analyze(empty_runtime_state, "persistent_runtime_state_empty_session")
	var empty_wire_analysis := _analyze(empty_save, "persistent_save_v3_empty_session")
	if int(empty_analysis.get("raw_float_count", -1)) != 31:
		_failures.append("attested_empty_session_float_count_not_31")
	if int(empty_wire_analysis.get("non_closed_leaf_count", -1)) != 0 \
			or not SEMANTIC_WIRE.is_closed_data(empty_save):
		_failures.append("empty_session_save_v3_not_closed")
	if (empty_save.get("player_states", []) as Array).size() != 3:
		_failures.append("empty_session_ai_roster_not_three")

	var capability := ai.get("_ai_actor_state_capability") as AiActorStateCapability
	var capture := port.capture_ai_state_batch_for_save(capability, true)
	var rows := (capture.get("rows", []) as Array).duplicate(true)
	for row_index in range(rows.size()):
		var row := rows[row_index] as Dictionary
		var memory := (row.get("ai_memory", {}) as Dictionary).duplicate(true)
		memory["decision_samples"] = [_decision_sample(row_index)]
		memory["action_counts"] = {
			"ordinary_card_purchase": row_index + 1,
			"legal_card_submission": 1,
		}
		memory["last_plan"] = "private-plan-redacted-%d" % row_index
		memory["economic_focus_product"] = "fixture-product-%d" % row_index
		memory["economic_focus_score"] = 120 + row_index
		memory["economic_focus_reason"] = "private-focus-redacted"
		memory["economic_focus_cycle"] = 3
		memory["economic_focus_rankings"] = [{"product": "fixture", "score": 120 + row_index}]
		memory["strategic_intent"] = "expand_route"
		memory["strategic_intent_score"] = 210 + row_index
		memory["strategic_intent_reason"] = "private-intent-redacted"
		memory["strategic_intent_cycle"] = 3
		memory["strategic_intent_rankings"] = [{"intent": "expand_route", "score": 210 + row_index}]
		memory["route_plan_product"] = "fixture-product-%d" % row_index
		memory["route_plan_stage"] = "supply"
		memory["route_plan_score"] = 330 + row_index
		memory["route_plan_reason"] = "private-route-redacted"
		memory["route_plan_cycle"] = 3
		memory["route_plan_target_city"] = row_index
		memory["route_plan_partner_district"] = row_index + 4
		memory["route_plan_rankings"] = [{"stage": "supply", "score": 330 + row_index}]
		memory["game_phase"] = "midgame"
		memory["competitive_posture"] = "trailing"
		memory["score_gap_to_leader"] = -40 - row_index
		memory["leader_index"] = 1
		memory["phase_reason"] = "private-phase-redacted"
		memory["learned_policy_values"] = {
			"action:ordinary_card_purchase": {
				"value": 1.23456789012345 + float(row_index) * 0.125,
				"samples": 2 + row_index,
				"reward_total": 31 + row_index,
				"last_reward": 17 + row_index,
				"last_cycle": 3,
			},
		}
		memory["learning_updates"] = row_index + 1
		memory["learning_last_reward"] = 17 + row_index
		memory["learning_last_tags"] = ["action:ordinary_card_purchase"]
		memory["episode_learning_updates"] = 1
		memory["episode_last_reward"] = 91 + row_index
		memory["episode_last_top_n_gdp"] = 140 + row_index
		memory["episode_last_controlled_regions"] = 2
		memory["episode_last_rank"] = row_index
		memory["episode_last_result"] = "characterized"
		row["ai_memory"] = memory
		rows[row_index] = row
	var applied := port.apply_ai_state_batch_for_restore(capability, rows)
	if not bool(applied.get("accepted", false)):
		_failures.append("typed_actor_state_fixture_apply_failed")

	ai.ai_card_decision_timer = 1.23456789012345
	ai.ai_auction_reaction_timer = 0.345678901234567
	ai.ai_intel_decision_timer = 4.56789012345678
	ai.set("_game_action_request_sequence", 19)
	ai.commit_plan_receipt({
		"intent_id": "ai-game-action.1.19",
		"action_id": "ordinary-card-purchase",
		"applied": true,
		"reason": "committed",
		"context_revision": 7,
	})
	ai.set("_card_target_pre_submit_rejection_count", 2)
	ai.set("_tick_timing_count", {"runtime_tick": 3})
	ai.set("_tick_timing_total_usec", {"runtime_tick": 1700})
	ai.set("_tick_timing_max_usec", {"runtime_tick": 800})
	ai.set("_actor_state_tick_cache", {})
	ai.set("_actor_state_tick_cache_active", false)
	ai.set("_actor_state_tick_cache_hit_count", 4)
	ai.set("_actor_state_tick_cache_miss_count", 5)

	var nontrivial_runtime_state := ai._capture_save_runtime_state()
	var nontrivial_save := ai.to_save_data()
	var runtime_checkpoint := ai.capture_runtime_checkpoint()
	var new_session_checkpoint := ai.capture_new_session_checkpoint()
	var runtime_decoded := AI_SAVE_WIRE_CODEC.decode_runtime_checkpoint(runtime_checkpoint)
	var new_session_decoded := AI_SAVE_WIRE_CODEC.decode_new_session_checkpoint(new_session_checkpoint)
	var nontrivial_analysis := _analyze(nontrivial_runtime_state, "persistent_runtime_state_nontrivial")
	var nontrivial_wire_analysis := _analyze(nontrivial_save, "persistent_save_v3_nontrivial")
	var runtime_analysis := _analyze(runtime_decoded.get("value", {}), "runtime_checkpoint_v2_decoded")
	var runtime_wire_analysis := _analyze(runtime_checkpoint, "runtime_checkpoint_v2_wire")
	var new_session_analysis := _analyze(new_session_decoded.get("value", {}), "new_session_checkpoint_v3_decoded")
	var new_session_wire_analysis := _analyze(new_session_checkpoint, "new_session_checkpoint_v3_wire")
	for analysis in [
		empty_analysis,
		empty_wire_analysis,
		nontrivial_analysis,
		nontrivial_wire_analysis,
		runtime_analysis,
		runtime_wire_analysis,
		new_session_analysis,
		new_session_wire_analysis,
	]:
		if not _leaf_paths_are_unique(analysis as Dictionary):
			_failures.append("characterization_leaf_path_collision:%s" % str((analysis as Dictionary).get("representation", "unknown")))
	var aggregate := _aggregate([
		empty_analysis,
		empty_wire_analysis,
		nontrivial_analysis,
		nontrivial_wire_analysis,
		runtime_analysis,
		runtime_wire_analysis,
		new_session_analysis,
		new_session_wire_analysis,
	])

	var first_memory := (((nontrivial_runtime_state.get("player_states", []) as Array)[0] as Dictionary).get("ai_memory", {}) as Dictionary)
	if (first_memory.get("decision_samples", []) as Array).is_empty() \
			or (first_memory.get("action_counts", {}) as Dictionary).is_empty() \
			or (first_memory.get("learned_policy_values", {}) as Dictionary).is_empty():
		_failures.append("nontrivial_memory_characterization_incomplete")
	if not (runtime_checkpoint.get("actor_state_tick_cache", {}) as Dictionary).is_empty() \
			or bool(runtime_checkpoint.get("actor_state_tick_cache_active", true)):
		_failures.append("save_barrier_tick_cache_not_canonical")
	if int(aggregate.get("object_count", -1)) != 0 \
			or int(aggregate.get("resource_count", -1)) != 0 \
			or int(aggregate.get("callable_count", -1)) != 0 \
			or int(aggregate.get("rid_count", -1)) != 0:
		_failures.append("rebindable_runtime_dependency_found")
	if int(nontrivial_wire_analysis.get("non_closed_leaf_count", -1)) != 0 \
			or int(runtime_wire_analysis.get("non_closed_leaf_count", -1)) != 0 \
			or int(new_session_wire_analysis.get("non_closed_leaf_count", -1)) != 0:
		_failures.append("v3_wire_representation_not_closed")

	var report := {
		"schema_version": 1,
		"characterization_id": "alpha04c_ai_runtime_full_state_pre_v3",
		"production_ruleset_id": "v0.6",
		"fixture_kind": "typed_actor_state_nontrivial",
		"private_payload_redacted": true,
		"scenarios": {
			"new_session_before_decision": _scenario_evidence(not empty_save.is_empty(), true, "production_owner_new_session_capture"),
			"three_ai_completed_tick_state": _scenario_evidence(rows.size() == 3, true, "production_ai_owner_tick_with_three_actor_rows"),
			"legal_card_action_state": _scenario_evidence(true, false, "typed_actor_state_shape_fixture_only"),
			"normal_purchase_or_business_state": _scenario_evidence(true, false, "typed_actor_state_shape_fixture_only"),
			"decision_samples_nonempty": _scenario_evidence(not (first_memory.get("decision_samples", []) as Array).is_empty(), false, "typed_actor_state_shape_fixture"),
			"action_counts_nonempty": _scenario_evidence(not (first_memory.get("action_counts", {}) as Dictionary).is_empty(), false, "typed_actor_state_shape_fixture"),
			"economic_focus_nonempty": _scenario_evidence(not str(first_memory.get("economic_focus_product", "")).is_empty(), false, "typed_actor_state_shape_fixture"),
			"strategic_intent_nonempty": _scenario_evidence(not str(first_memory.get("strategic_intent", "")).is_empty(), false, "typed_actor_state_shape_fixture"),
			"route_plan_nonempty": _scenario_evidence(not str(first_memory.get("route_plan_stage", "")).is_empty(), false, "typed_actor_state_shape_fixture"),
			"learned_policy_values_nonempty": _scenario_evidence(not (first_memory.get("learned_policy_values", {}) as Dictionary).is_empty(), false, "typed_actor_state_shape_fixture"),
			"learning_update_present": _scenario_evidence(int(first_memory.get("learning_updates", 0)) > 0, false, "typed_actor_state_shape_fixture"),
			"last_receipt_present": _scenario_evidence(not (runtime_checkpoint.get("last_receipts", []) as Array).is_empty(), false, "typed_owner_receipt_shape_fixture"),
			"three_timers_nondefault": _scenario_evidence(true, false, "typed_owner_timer_shape_fixture"),
			"tick_timing_diagnostics_present": _scenario_evidence(not (runtime_checkpoint.get("tick_timing_count", {}) as Dictionary).is_empty(), false, "typed_owner_diagnostic_shape_fixture"),
			"tick_cache_save_barrier_canonical": _scenario_evidence((runtime_checkpoint.get("actor_state_tick_cache", {}) as Dictionary).is_empty() and not bool(runtime_checkpoint.get("actor_state_tick_cache_active", true)), true, "production_checkpoint_capture_invariant"),
			"new_session_checkpoint_present": _scenario_evidence(not new_session_checkpoint.is_empty(), true, "production_owner_new_session_checkpoint"),
		},
		"attested_empty_session_raw_float_distribution": empty_analysis.get("float_source_counts", {}),
		"representations": {
			"empty_persistent_runtime_state": empty_analysis,
			"empty_persistent_save_v3": empty_wire_analysis,
			"nontrivial_persistent_runtime_state": nontrivial_analysis,
			"nontrivial_persistent_save_v3": nontrivial_wire_analysis,
			"runtime_checkpoint_v2_decoded": runtime_analysis,
			"runtime_checkpoint_v2_wire": runtime_wire_analysis,
			"new_session_checkpoint_v3_decoded": new_session_analysis,
			"new_session_checkpoint_v3_wire": new_session_wire_analysis,
		},
		"aggregate": aggregate,
		"failures": _failures.duplicate(),
	}
	coordinator.queue_free()
	await process_frame
	_finish(report)


func _decision_sample(index: int) -> Dictionary:
	return {
		"time": 17.1234567890123 + float(index) * 0.25,
		"cycle": 3,
		"kind": "ordinary_card_purchase",
		"target": index + 4,
		"score": 200 + index,
		"reason": "private-sample-redacted",
		"state": {"authorized_public_feature": 1},
		"candidates": [{"candidate_id": "redacted", "score": 200 + index}],
		"focus_product": "fixture-product-%d" % index,
		"focus_score": 120 + index,
		"focus_reason": "private-focus-redacted",
		"strategy_intent": "expand_route",
		"strategy_score": 210 + index,
		"strategy_reason": "private-intent-redacted",
		"route_plan_product": "fixture-product-%d" % index,
		"route_plan_stage": "supply",
		"route_plan_score": 330 + index,
		"route_plan_reason": "private-route-redacted",
		"game_phase": "midgame",
		"competitive_posture": "trailing",
		"score_gap_to_leader": -40 - index,
		"leader_index": 1,
		"phase_reason": "private-phase-redacted",
		"endgame_urgency": 10,
		"baseline_cash": 700,
		"baseline_victory_gdp": 100,
		"baseline_victory_regions": 1,
		"reward_cash": 20,
		"reward_victory_gdp": 3,
		"reward_victory_regions": 0,
		"reward_score": 35,
		"reward_finalized": true,
		"learning_applied": true,
	}


func _analyze(value: Variant, representation: String) -> Dictionary:
	var result := {
		"representation": representation,
		"leaf_count": 0,
		"non_closed_leaf_count": 0,
		"raw_float_count": 0,
		"null_count": 0,
		"string_name_count": 0,
		"non_string_dictionary_key_count": 0,
		"unsafe_integer_count": 0,
		"object_count": 0,
		"resource_count": 0,
		"callable_count": 0,
		"rid_count": 0,
		"non_closed_type_counts": {},
		"float_source_counts": {},
		"leaf_records": [],
	}
	_walk(value, "$", "none", result)
	return result


func _walk(value: Variant, path: String, dictionary_key_type: String, result: Dictionary) -> void:
	if value is Dictionary:
		var dictionary := value as Dictionary
		if dictionary.is_empty():
			_record_leaf(value, path, dictionary_key_type, result, "empty_container")
			return
		var keys := dictionary.keys()
		keys.sort_custom(func(left: Variant, right: Variant) -> bool:
			return ("%s|%s" % [type_string(typeof(left)), str(left)]) \
					< ("%s|%s" % [type_string(typeof(right)), str(right)])
		)
		for key_index in range(keys.size()):
			var key_variant: Variant = keys[key_index]
			var key_kind := type_string(typeof(key_variant))
			if not (key_variant is String):
				result["non_string_dictionary_key_count"] = int(result.get("non_string_dictionary_key_count", 0)) + 1
				_increment(result.get("non_closed_type_counts", {}) as Dictionary, "dictionary_key:%s" % key_kind)
			var child_path := "%s.%s" % [path, _path_component(key_variant, key_index)]
			_walk(dictionary.get(key_variant), child_path, key_kind, result)
		return
	if value is Array:
		var array := value as Array
		if array.is_empty():
			_record_leaf(value, path, dictionary_key_type, result, "empty_container")
			return
		for index in range(array.size()):
			_walk(array[index], "%s[%d]" % [path, index], dictionary_key_type, result)
		return
	_record_leaf(value, path, dictionary_key_type, result, _reason_code(value))


func _record_leaf(value: Variant, path: String, dictionary_key_type: String, result: Dictionary, reason_code: String) -> void:
	result["leaf_count"] = int(result.get("leaf_count", 0)) + 1
	var kind := type_string(typeof(value))
	var source_subdomain := _source_subdomain(path)
	var is_non_closed := reason_code != "closed_scalar" and reason_code != "empty_container"
	if is_non_closed:
		result["non_closed_leaf_count"] = int(result.get("non_closed_leaf_count", 0)) + 1
		_increment(result.get("non_closed_type_counts", {}) as Dictionary, kind)
	if value is float:
		result["raw_float_count"] = int(result.get("raw_float_count", 0)) + 1
		_increment(result.get("float_source_counts", {}) as Dictionary, source_subdomain)
	elif value == null:
		result["null_count"] = int(result.get("null_count", 0)) + 1
	elif value is StringName:
		result["string_name_count"] = int(result.get("string_name_count", 0)) + 1
	elif value is int and not SEMANTIC_WIRE.is_safe_integer(value):
		result["unsafe_integer_count"] = int(result.get("unsafe_integer_count", 0)) + 1
	elif value is Object:
		result["object_count"] = int(result.get("object_count", 0)) + 1
		if value is Resource:
			result["resource_count"] = int(result.get("resource_count", 0)) + 1
	elif value is Callable:
		result["callable_count"] = int(result.get("callable_count", 0)) + 1
	elif value is RID:
		result["rid_count"] = int(result.get("rid_count", 0)) + 1
	var diagnostic_only := path.contains("tick_timing_") \
			or path.contains("actor_state_tick_cache_hit_count") \
			or path.contains("actor_state_tick_cache_miss_count") \
			or path.contains("card_target_pre_submit_rejection_count") \
			or path.contains("last_receipts")
	var derived_cache := path.contains("actor_state_tick_cache") \
			and not path.contains("_hit_count") and not path.contains("_miss_count")
	var runtime_memory := path.contains(".ai_memory")
	var static_profile_data := path.contains(".ai_profile") \
			or path.contains("policy_profile_id") or path.contains("policy_fingerprint")
	var exact_once_required := path.contains("request_sequence") \
			or path.contains("decision_samples") or path.contains("action_counts") \
			or path.contains("learned_policy_values") or path.contains("learning_")
	(result.get("leaf_records", []) as Array).append({
		"json_path": path,
		"source_subdomain": source_subdomain,
		"variant_type": kind,
		"dictionary_key_type": dictionary_key_type,
		"authoritative": not diagnostic_only and not derived_cache,
		"exact_once_required": exact_once_required,
		"static_profile_data": static_profile_data,
		"runtime_memory": runtime_memory,
		"derived_cache": derived_cache,
		"diagnostic_only": diagnostic_only,
		"rebindable_dependency": value is Object or value is Callable or value is RID,
		"finite": is_finite(float(value)) if value is float else true,
		"safe_integer": SEMANTIC_WIRE.is_safe_integer(value) if value is int else false,
		"reason_code": reason_code,
		"redacted_fingerprint": ("%s|%s|%s|%s" % [
			path,
			kind,
			source_subdomain,
			reason_code,
		]).sha256_text(),
	})


func _reason_code(value: Variant) -> String:
	if value is float:
		return "raw_float_not_closed_data" if is_finite(float(value)) else "nonfinite_float"
	if value == null:
		return "raw_null_not_closed_data"
	if value is StringName:
		return "string_name_not_closed_data"
	if value is int and not SEMANTIC_WIRE.is_safe_integer(value):
		return "unsafe_integer_not_closed_data"
	if value is Object:
		return "object_dependency_rebind_required"
	if value is Callable:
		return "callable_dependency_rebind_required"
	if value is RID:
		return "rid_dependency_rebind_required"
	return "closed_scalar"


func _source_subdomain(path: String) -> String:
	if path.contains("ai_card_decision_timer"):
		return "timer.ai_card_decision"
	if path.contains("ai_auction_reaction_timer"):
		return "timer.ai_auction_reaction"
	if path.contains("ai_intel_decision_timer"):
		return "timer.ai_intel_decision"
	if path.contains(".ai_profile.route_preferences"):
		return "ai_profile.route_preferences"
	if path.contains(".ai_profile"):
		return "ai_profile.decision_bias"
	if path.contains(".ai_memory.decision_samples"):
		return "ai_memory.decision_samples"
	if path.contains(".ai_memory.learned_policy_values"):
		return "ai_memory.learned_policy_values"
	if path.contains(".ai_memory"):
		return "ai_memory.runtime_state"
	if path.contains("last_receipts"):
		return "runtime_checkpoint.last_receipts"
	if path.contains("tick_timing"):
		return "runtime_checkpoint.tick_timing_diagnostic"
	if path.contains("actor_state_tick_cache"):
		return "runtime_checkpoint.actor_state_tick_cache"
	if path.contains("request_sequence"):
		return "exact_once.request_sequence"
	return "owner_metadata"


func _path_component(key: Variant, key_index: int) -> String:
	if key is String and SAFE_PATH_FIELDS.has(str(key)):
		return str(key)
	return "<redacted-%s-key-%d>" % [type_string(typeof(key)), key_index]


func _increment(counts: Dictionary, key: String) -> void:
	counts[key] = int(counts.get(key, 0)) + 1


func _aggregate(analyses: Array) -> Dictionary:
	var result := {
		"raw_float_count": 0,
		"null_count": 0,
		"string_name_count": 0,
		"non_string_dictionary_key_count": 0,
		"unsafe_integer_count": 0,
		"object_count": 0,
		"resource_count": 0,
		"callable_count": 0,
		"rid_count": 0,
		"non_closed_type_counts": {},
		"raw_float_observation_breakdown": {},
	}
	for analysis_variant in analyses:
		var analysis := analysis_variant as Dictionary
		for key_variant in [
			"raw_float_count", "null_count", "string_name_count",
			"non_string_dictionary_key_count", "unsafe_integer_count",
			"object_count", "resource_count", "callable_count", "rid_count",
		]:
			var key := str(key_variant)
			result[key] = int(result.get(key, 0)) + int(analysis.get(key, 0))
		_merge_counts(result.get("non_closed_type_counts", {}) as Dictionary, analysis.get("non_closed_type_counts", {}) as Dictionary)
		(result.get("raw_float_observation_breakdown", {}) as Dictionary)[str(analysis.get("representation", "unknown"))] = int(analysis.get("raw_float_count", 0))
	return result


func _merge_counts(target: Dictionary, source: Dictionary) -> void:
	for key_variant in source.keys():
		var key := str(key_variant)
		target[key] = int(target.get(key, 0)) + int(source.get(key_variant, 0))


func _leaf_paths_are_unique(analysis: Dictionary) -> bool:
	var seen_paths: Dictionary = {}
	var seen_fingerprints: Dictionary = {}
	for row_variant in analysis.get("leaf_records", []) as Array:
		var row := row_variant as Dictionary
		var path := str(row.get("json_path", ""))
		var fingerprint := str(row.get("redacted_fingerprint", ""))
		if path.is_empty() or fingerprint.is_empty() \
				or seen_paths.has(path) or seen_fingerprints.has(fingerprint):
			return false
		seen_paths[path] = true
		seen_fingerprints[fingerprint] = true
	return true


func _scenario_evidence(state_shape_observed: bool, runtime_execution_attested: bool, evidence_kind: String) -> Dictionary:
	return {
		"state_shape_observed": state_shape_observed,
		"runtime_execution_attested": runtime_execution_attested,
		"evidence_kind": evidence_kind,
	}


func _player(catalog: RoleCatalogRuntimeService, player_index: int, is_ai: bool) -> Dictionary:
	var role := catalog.definition_at(player_index)
	role["role_index"] = player_index
	return {
		"id": player_index,
		"name": "AI-%d" % player_index if is_ai else "Human-%d" % player_index,
		"seat_type": "ai" if is_ai else "human",
		"is_ai": is_ai,
		"ai_profile": {},
		"ai_memory": {},
		"role_index": player_index,
		"role_card": role,
		"base_starting_cash": 700,
		"role_starting_cash_delta": 0,
		"starting_cash_total": 700,
		"cash": 700,
		"cash_cents": 70000,
		"cash_history": [],
		"v06_transaction_ledger": [],
		"eliminated": false,
		"eliminated_at": -1.0,
		"elimination_reason": "",
		"economic_ledger": [],
		"city_guesses": {},
		"city_guess_confidence": {},
		"city_guess_reasons": {},
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
	}


func _finish(report: Dictionary) -> void:
	var output_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--characterization-output="):
			output_path = argument.trim_prefix("--characterization-output=")
	if not output_path.is_empty() and not report.is_empty():
		var file := FileAccess.open(output_path, FileAccess.WRITE)
		if file == null:
			_failures.append("characterization_output_open_failed")
		else:
			file.store_string(JSON.stringify(report, "  "))
			file.close()
	print("AI_RUNTIME_FULL_STATE_CHARACTERIZATION_TEST|status=%s|failures=%d|output_written=%s" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_failures.size(),
		str(not output_path.is_empty()),
	])
	for failure in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)
