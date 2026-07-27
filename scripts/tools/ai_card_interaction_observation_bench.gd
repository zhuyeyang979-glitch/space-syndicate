extends Node
class_name AiCardInteractionObservationBench

const FIXTURE := preload(
	"res://scripts/tools/card_semantic_source_authorization_fixture.gd"
)
const OBSERVATION := preload(
	"res://scripts/semantic/ai_card_interaction_observation_v1.gd"
)
const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const DISRUPT_CARD_ID := "interaction.starlink_dismantle.rank_4"
const STEAL_CARD_ID := "interaction.shadow_warehouse_traction.rank_4"
const DISRUPT_INSTANCE_ID := "fixture:interaction-observation:disrupt:01"
const STEAL_INSTANCE_ID := "fixture:interaction-observation:steal:01"
const DISRUPT_SLOT_INDEX := 0
const STEAL_SLOT_INDEX := 1
const SAMPLE_ITERATIONS := 100
const REPEAT_ITERATIONS := 400
const REPEAT_TIME_LIMIT_MS := 20000.0
const FORBIDDEN_OUTPUT_KEYS := [
	"card",
	"card_record",
	"semantic_spec",
	"machine",
	"player",
	"developer",
	"effect_payload",
	"skill",
	"world",
	"world_facts",
	"legal_targets",
	"target_recommendation",
	"owner",
	"hidden_owner",
	"true_owner",
	"rival_hand",
	"opponent_hand",
	"exact_cash",
	"private_plan",
	"ai_score",
	"ai_value",
	"route_plan",
	"future_bag",
	"rng_state",
	"save_payload",
	"authorization_capability",
	"capability",
	"method_name",
	"script_path",
]

var bench_status := "PENDING"
var check_count := 0
var failure_count := 0
var result_snapshot: Dictionary = {}
var _running := false


func _ready() -> void:
	call_deferred("_run_bench")


func _run_bench() -> void:
	if _running:
		return
	_running = true
	var coordinator := get_node_or_null(
		"GameRuntimeCoordinator"
	) as GameRuntimeCoordinator
	result_snapshot = evaluate(coordinator)
	bench_status = str(result_snapshot.get("status", "FAIL"))
	check_count = int(result_snapshot.get("check_count", 0))
	failure_count = int(result_snapshot.get("failure_count", 0))
	print(
		"AI_CARD_INTERACTION_OBSERVATION_BENCH|status=%s|checks=%d|failures=%d|result=%s"
		% [
			bench_status,
			check_count,
			failure_count,
			JSON.stringify(result_snapshot),
		]
	)
	var hold_seconds := 0.1 if DisplayServer.get_name() == "headless" else 30.0
	await get_tree().create_timer(hold_seconds).timeout
	get_tree().quit(0 if bench_status == "PASS" else 1)


static func evaluate(coordinator: GameRuntimeCoordinator) -> Dictionary:
	var started_usec := Time.get_ticks_usec()
	var state := {"checks": 0, "failures": []}
	_check(state, coordinator != null, "production_coordinator_present")
	if coordinator == null:
		return _finish(state, started_usec, {})

	var fixture := FIXTURE.configure_coordinator(
		coordinator,
		"ai.card.interaction.observation.bench"
	)
	_check(state, not fixture.is_empty(), "real_coordinator_fixture_configured")
	if fixture.is_empty():
		return _finish(state, started_usec, {})

	var world := fixture.get("world") as WorldSessionState
	var source := fixture.get("source") as CardSemanticSourceAuthorizationPort
	var catalog := fixture.get("catalog") as CardSemanticCatalogService
	var rng := fixture.get("rng") as RunRngService
	var service := coordinator.get_node_or_null(
		"AiCardInteractionObservationService"
	) as AiCardInteractionObservationService
	var ai := coordinator.get_node_or_null(
		"AiRuntimeController"
	) as AiRuntimeController
	var observation_capability_map_variant: Variant = coordinator.get(
		"_ai_card_interaction_observation_capability_by_actor"
	)
	var observation_capability_map := observation_capability_map_variant \
		as Dictionary if observation_capability_map_variant is Dictionary else {}
	var observation_capability_variant: Variant = observation_capability_map.get(
		FIXTURE.AI_ACTOR_INDEX
	)
	var observation_capability := observation_capability_variant \
		as RefCounted
	_check(
		state,
		world != null
			and source != null
			and catalog != null
			and rng != null
			and service != null
			and ai != null
			and observation_capability != null,
		"integrated_production_dependencies_resolve"
	)
	if world == null or source == null or catalog == null \
		or rng == null or service == null or ai == null \
		or observation_capability == null:
		return _finish(state, started_usec, {})
	_check(
		state,
		coordinator.find_children(
			"AiCardInteractionObservationService",
			"",
			true,
			false
		).size() == 1,
		"exactly_one_observation_service_in_real_coordinator"
	)
	_check(
		state,
		coordinator.find_children(
			"CardSemanticSourceAuthorizationPort",
			"",
			true,
			false
		).size() == 1,
		"exactly_one_source_authorization_port_in_real_coordinator"
	)
	_check(state, service.is_ready(), "observation_service_is_production_ready")
	_check(
		state,
		service.get_node_or_null(service.source_authorization_port_path)
			== source,
		"observation_service_uses_composed_source_authorization_port"
	)
	var service_binding_debug := service.debug_snapshot()
	var ai_binding_debug := ai.debug_snapshot()
	_check(
		state,
		ai.get("_ai_card_interaction_observation_service") == service
			and bool(ai_binding_debug.get(
				"typed_card_interaction_observation_bound",
				false
			)),
		"production_ai_has_same_observation_service_binding"
	)
	_check(
		state,
		bool(service_binding_debug.get("actor_capabilities_bound", false))
			and int(service_binding_debug.get("actor_capability_count", 0)) > 0
			and not bool(service_binding_debug.get(
				"exposes_actor_capabilities",
				true
			))
			and _capability_debug_is_count_only(service_binding_debug),
		"service_owns_bound_capabilities_but_debug_exposes_counts_only"
	)
	_check(
		state,
		int(ai_binding_debug.get(
			"card_interaction_source_capability_count",
			-1
		)) == 0
			and not bool(ai_binding_debug.get(
				"card_interaction_source_capabilities_held",
				true
			))
			and not bool(ai_binding_debug.get(
				"card_interaction_observation_exposes_capabilities",
				true
			))
			and not _object_has_property(
				ai,
				"_card_interaction_capability_by_actor"
			),
		"production_ai_stores_zero_interaction_source_capabilities"
	)
	_check(
		state,
		_install_interaction_slots(world),
		"authoritative_ai_hand_contains_disrupt_and_steal_slots"
	)

	var catalog_before := FIXTURE.catalog_metrics(catalog.validation_snapshot())
	var source_before := source.debug_snapshot()
	var service_before := service.debug_snapshot()
	var rng_before := rng.capture_plan_checkpoint()

	var disrupt := service.observe_own_hand_interaction(
		observation_capability,
		FIXTURE.AI_ACTOR_INDEX,
		DISRUPT_SLOT_INDEX
	)
	var steal := service.observe_own_hand_interaction(
		observation_capability,
		FIXTURE.AI_ACTOR_INDEX,
		STEAL_SLOT_INDEX
	)
	_check(
		state,
		_is_valid_observation(service, observation_capability, disrupt),
		"disrupt_slot_produces_valid_closed_observation"
	)
	_check(
		state,
		_is_valid_observation(service, observation_capability, steal),
		"steal_slot_produces_valid_closed_observation"
	)
	_check(
		state,
		WIRE.exact_fields(disrupt, OBSERVATION.FIELDS)
			and WIRE.exact_fields(steal, OBSERVATION.FIELDS),
		"observations_use_exact_frozen_schema_fields"
	)
	_check(
		state,
		_matches_interaction(
			disrupt,
			DISRUPT_CARD_ID,
			DISRUPT_INSTANCE_ID,
			DISRUPT_SLOT_INDEX,
			"player_hand_disrupt",
			2,
			0,
			20,
			120,
			0
		),
		"disrupt_semantic_operations_project_exact_rank_four_facts"
	)
	_check(
		state,
		_matches_interaction(
			steal,
			STEAL_CARD_ID,
			STEAL_INSTANCE_ID,
			STEAL_SLOT_INDEX,
			"player_hand_steal",
			0,
			2,
			18,
			0,
			220
		),
		"steal_semantic_operations_project_exact_rank_four_facts"
	)
	_check(
		state,
		str(disrupt.get("runtime_readiness_id", "")) == "projection_only"
			and str(steal.get("runtime_readiness_id", ""))
				== "projection_only",
		"projection_only_readiness_remains_metadata"
	)
	_check(
		state,
		_output_is_private_data_free(disrupt)
			and _output_is_private_data_free(steal),
		"observations_exclude_full_card_private_world_ai_and_ui_values"
	)

	var disrupt_baseline := disrupt.duplicate(true)
	var steal_baseline := steal.duplicate(true)
	var manual_raw_disrupt_card := FIXTURE.runtime_card(
		DISRUPT_CARD_ID,
		DISRUPT_INSTANCE_ID
	)
	var manual_raw_steal_card := FIXTURE.runtime_card(
		STEAL_CARD_ID,
		STEAL_INSTANCE_ID
	)
	var manual_raw_disrupt := _manual_raw_policy_slice(
		manual_raw_disrupt_card
	)
	var manual_raw_steal := _manual_raw_policy_slice(
		manual_raw_steal_card
	)
	var authorized_disrupt_policy := _authorized_policy_slice(
		disrupt_baseline
	)
	var authorized_steal_policy := _authorized_policy_slice(steal_baseline)
	_check(
		state,
		not manual_raw_disrupt.is_empty()
			and not manual_raw_steal.is_empty()
			and manual_raw_disrupt == authorized_disrupt_policy
			and manual_raw_steal == authorized_steal_policy,
		"manual_raw_and_authorized_policy_slices_match"
	)
	var hostile_local_copy := disrupt.duplicate(true)
	hostile_local_copy["semantic_discard_count"] = 999
	_check(
		state,
		not bool(service.validate_observation(
			observation_capability,
			FIXTURE.AI_ACTOR_INDEX,
			hostile_local_copy
		).get(
			"valid",
			false
		)),
		"locally_mutated_observation_is_not_an_issued_replay"
	)
	var disrupt_after_local_mutation := service.observe_own_hand_interaction(
		observation_capability,
		FIXTURE.AI_ACTOR_INDEX,
		DISRUPT_SLOT_INDEX
	)
	_check(
		state,
		disrupt_after_local_mutation == disrupt_baseline,
		"returned_observation_is_detached_from_service_state"
	)

	var manual_raw_started_usec := Time.get_ticks_usec()
	var manual_raw_100_ms := -1.0
	var manual_raw_valid_count := 0
	for index in range(REPEAT_ITERATIONS):
		var repeated_raw_disrupt := _manual_raw_policy_slice(
			manual_raw_disrupt_card
		)
		var repeated_raw_steal := _manual_raw_policy_slice(
			manual_raw_steal_card
		)
		if repeated_raw_disrupt == authorized_disrupt_policy \
		and repeated_raw_steal == authorized_steal_policy:
			manual_raw_valid_count += 2
		if index + 1 == SAMPLE_ITERATIONS:
			manual_raw_100_ms = snappedf(
				float(Time.get_ticks_usec() - manual_raw_started_usec) / 1000.0,
				0.001
			)
	var manual_raw_400_ms := snappedf(
		float(Time.get_ticks_usec() - manual_raw_started_usec) / 1000.0,
		0.001
	)

	var repeat_started_usec := Time.get_ticks_usec()
	var repeat_100_ms := -1.0
	var repeat_valid_count := 0
	var deterministic := true
	for index in range(REPEAT_ITERATIONS):
		var repeated_disrupt := service.observe_own_hand_interaction(
			observation_capability,
			FIXTURE.AI_ACTOR_INDEX,
			DISRUPT_SLOT_INDEX
		)
		var repeated_steal := service.observe_own_hand_interaction(
			observation_capability,
			FIXTURE.AI_ACTOR_INDEX,
			STEAL_SLOT_INDEX
		)
		if repeated_disrupt == disrupt_baseline \
			and repeated_steal == steal_baseline \
			and _authorized_policy_slice(repeated_disrupt) \
				== manual_raw_disrupt \
			and _authorized_policy_slice(repeated_steal) == manual_raw_steal:
			repeat_valid_count += 2
		if repeated_disrupt != disrupt_baseline \
			or repeated_steal != steal_baseline:
			deterministic = false
		if index + 1 == SAMPLE_ITERATIONS:
			repeat_100_ms = snappedf(
				float(Time.get_ticks_usec() - repeat_started_usec) / 1000.0,
				0.001
			)
	var repeat_400_ms := snappedf(
		float(Time.get_ticks_usec() - repeat_started_usec) / 1000.0,
		0.001
	)

	var catalog_after := FIXTURE.catalog_metrics(catalog.validation_snapshot())
	var source_after := source.debug_snapshot()
	var service_after := service.debug_snapshot()
	var rng_after := rng.capture_plan_checkpoint()
	var request_binding_delta := _counter_delta(
		source_before,
		source_after,
		"request_binding_count"
	)
	var journal_entry_delta := _counter_delta(
		source_before,
		source_after,
		"journal_entry_count"
	)
	var expected_observation_count := REPEAT_ITERATIONS * 2 + 3
	var expected_issued_validation_count := 3
	var expected_source_authorization_count := \
		expected_observation_count + 2
	var expected_source_revalidation_count := \
		expected_source_authorization_count * 2
	var expected_hand_snapshot_query_count := \
		expected_source_authorization_count * 3
	_check(
		state,
		manual_raw_valid_count == REPEAT_ITERATIONS * 2,
		"400_manual_raw_policy_slices_match_authorized_values"
	)
	_check(
		state,
		repeat_valid_count == REPEAT_ITERATIONS * 2,
		"400_repeats_validate_both_authorized_slots"
	)
	_check(
		state,
		deterministic,
		"100_and_400_repeated_observations_are_deterministic"
	)
	_check(
		state,
		repeat_100_ms >= 0.0
			and repeat_400_ms < REPEAT_TIME_LIMIT_MS
			and repeat_400_ms - repeat_100_ms
				<= repeat_100_ms * 4.0 + 50.0,
		"100_and_400_observation_timings_are_bounded"
	)
	_check(
		state,
		request_binding_delta >= 0
			and request_binding_delta <= 2
			and journal_entry_delta >= 0
			and journal_entry_delta <= 2,
		"repeated_observations_reuse_at_most_one_binding_per_slot"
	)
	_check(
		state,
		int(service_after.get("issued_observation_fingerprint_count", -1))
			== 2
			and int(service_after.get(
				"issued_observation_eviction_count",
				-1
			)) == 0,
		"replay_journal_stays_bounded_to_two_current_slot_fingerprints"
	)
	_check(
		state,
		int(catalog_after.get("compile_count", -1))
			== int(catalog_before.get("compile_count", -2))
			and int(catalog_after.get("cache_entry_count", -1))
				== int(catalog_before.get("cache_entry_count", -2)),
		"observation_compile_delta_zero"
	)
	_check(
		state,
		_counter_delta(
			source_before,
			source_after,
			"authorization_attempt_count"
		) == expected_source_authorization_count
			and _counter_delta(
				source_before,
				source_after,
				"catalog_compile_request_count"
			) == expected_source_authorization_count
			and _counter_delta(
				source_before,
				source_after,
				"catalog_spec_authorization_count"
			) == expected_source_authorization_count
			and _counter_delta(
				source_before,
				source_after,
				"policy_compatibility_attempt_count"
			) == expected_source_authorization_count
			and _counter_delta(
				source_before,
				source_after,
				"source_revalidation_count"
			) == expected_source_revalidation_count
			and _counter_delta(
				source_before,
				source_after,
				"hand_snapshot_query_count"
			) == expected_hand_snapshot_query_count
			and _counter_delta(
				service_before,
				service_after,
				"observation_attempt_count"
			) == expected_observation_count
			and _counter_delta(
				service_before,
				service_after,
				"observation_validation_count"
			) == expected_issued_validation_count
			and int(catalog_after.get("cache_hit_count", -1))
				- int(catalog_before.get("cache_hit_count", -1))
				== expected_source_authorization_count,
		"observation_query_and_cache_work_matches_the_frozen_production_path"
	)
	_check(state, rng_before == rng_after, "observation_rng_delta_zero")
	_check(
		state,
		_output_is_private_data_free(service_after)
			and _capability_debug_is_count_only(service_after),
		"observation_service_debug_snapshot_has_no_private_values"
	)

	return _finish(state, started_usec, {
		"actor_index": FIXTURE.AI_ACTOR_INDEX,
		"disrupt_card_id": DISRUPT_CARD_ID,
		"disrupt_slot": DISRUPT_SLOT_INDEX,
		"disrupt_observation_fingerprint": _observation_fingerprint(
			disrupt_baseline
		),
		"steal_card_id": STEAL_CARD_ID,
		"steal_slot": STEAL_SLOT_INDEX,
		"steal_observation_fingerprint": _observation_fingerprint(
			steal_baseline
		),
		"runtime_readiness_id": "projection_only",
		"service_bound_capability_count": int(service_after.get(
			"actor_capability_count",
			0
		)),
		"ai_source_capability_count": int(ai_binding_debug.get(
			"card_interaction_source_capability_count",
			-1
		)),
		"sample_iterations": SAMPLE_ITERATIONS,
		"repeat_iterations": REPEAT_ITERATIONS,
		"observations_per_iteration": 2,
		"manual_raw_valid_count": manual_raw_valid_count,
		"manual_raw_100_ms": manual_raw_100_ms,
		"manual_raw_400_ms": manual_raw_400_ms,
		"manual_raw_average_policy_slice_ms": snappedf(
			manual_raw_400_ms / float(REPEAT_ITERATIONS * 2),
			0.001
		),
		"repeat_valid_count": repeat_valid_count,
		"repeat_deterministic": deterministic,
		"repeat_100_ms": repeat_100_ms,
		"repeat_400_ms": repeat_400_ms,
		"repeat_average_observation_ms": snappedf(
			repeat_400_ms / float(REPEAT_ITERATIONS * 2),
			0.001
		),
		"authorized_to_manual_raw_ratio": snappedf(
			repeat_400_ms / maxf(manual_raw_400_ms, 0.001),
			0.001
		),
		"manual_raw_authorized_policy_parity": (
			manual_raw_valid_count == REPEAT_ITERATIONS * 2
				and repeat_valid_count == REPEAT_ITERATIONS * 2
		),
		"repeat_time_limit_ms": REPEAT_TIME_LIMIT_MS,
		"expected_observation_count": expected_observation_count,
		"expected_issued_validation_count": expected_issued_validation_count,
		"expected_source_authorization_count": (
			expected_source_authorization_count
		),
		"expected_source_revalidation_count": (
			expected_source_revalidation_count
		),
		"expected_hand_snapshot_query_count": (
			expected_hand_snapshot_query_count
		),
		"compile_count_before": int(catalog_before.get("compile_count", -1)),
		"compile_count_after": int(catalog_after.get("compile_count", -1)),
		"compile_delta": int(catalog_after.get("compile_count", -1))
			- int(catalog_before.get("compile_count", -1)),
		"cache_hit_delta": int(catalog_after.get("cache_hit_count", -1))
			- int(catalog_before.get("cache_hit_count", -1)),
		"source_request_binding_delta": request_binding_delta,
		"source_journal_entry_delta": journal_entry_delta,
		"source_metrics": _source_metrics(source_after),
		"service_metrics_before": _service_metrics(service_before),
		"service_metrics_after": _service_metrics(service_after),
		"rng_unchanged": rng_before == rng_after,
		"private_value_leak": not (
			_output_is_private_data_free(disrupt_baseline)
			and _output_is_private_data_free(steal_baseline)
		),
	})


static func _install_interaction_slots(world: WorldSessionState) -> bool:
	var disrupt := FIXTURE.runtime_card(
		DISRUPT_CARD_ID,
		DISRUPT_INSTANCE_ID
	)
	var steal := FIXTURE.runtime_card(STEAL_CARD_ID, STEAL_INSTANCE_ID)
	if disrupt.is_empty() or steal.is_empty():
		return false
	var world_snapshot := world.internal_snapshot()
	var players_value: Variant = world_snapshot.get("players")
	if not (players_value is Array):
		return false
	var players := (players_value as Array).duplicate(true)
	if FIXTURE.AI_ACTOR_INDEX < 0 \
		or FIXTURE.AI_ACTOR_INDEX >= players.size() \
		or not (players[FIXTURE.AI_ACTOR_INDEX] is Dictionary):
		return false
	var actor := (players[FIXTURE.AI_ACTOR_INDEX] as Dictionary).duplicate(true)
	actor["slots"] = [disrupt, steal]
	players[FIXTURE.AI_ACTOR_INDEX] = actor
	world_snapshot["players"] = players
	world.restore(world_snapshot, true)
	var restored := world.internal_snapshot()
	var restored_players := restored.get("players", []) as Array
	if FIXTURE.AI_ACTOR_INDEX >= restored_players.size():
		return false
	var restored_actor := restored_players[FIXTURE.AI_ACTOR_INDEX] as Dictionary
	var restored_slots := restored_actor.get("slots", []) as Array
	return restored_slots.size() == 2 \
		and str((restored_slots[0] as Dictionary).get(
			"runtime_instance_id",
			""
		)) == DISRUPT_INSTANCE_ID \
		and str((restored_slots[1] as Dictionary).get(
			"runtime_instance_id",
			""
		)) == STEAL_INSTANCE_ID


static func _is_valid_observation(
	service: AiCardInteractionObservationService,
	consumer_capability: RefCounted,
	observation: Dictionary
) -> bool:
	if observation.is_empty() or not WIRE.is_closed_data(observation):
		return false
	var schema_report := OBSERVATION.validate(observation)
	var issued_report := service.validate_observation(
		consumer_capability,
		FIXTURE.AI_ACTOR_INDEX,
		observation
	)
	return bool(schema_report.get("valid", false)) \
		and bool(issued_report.get("valid", false))


static func _manual_raw_policy_slice(card: Dictionary) -> Dictionary:
	if card.is_empty():
		return {}
	# Mirrors the six pre-batch top-level reads and their frozen defaults.
	return {
		"policy_interaction_kind_id": str(card.get(
			"kind",
			"player_hand_disrupt"
		)),
		"policy_discard_count": int(card.get("hand_discard_count", 0)),
		"policy_steal_count": int(card.get("hand_steal_count", 0)),
		"policy_lock_duration_microseconds": int(round(
			float(card.get("hand_lock_seconds", 0.0)) * 1000000.0
		)),
		"policy_cash_penalty": int(card.get("target_cash_penalty", 0)),
		"policy_steal_failure_cash": int(card.get("steal_fail_cash", 0)),
	}


static func _authorized_policy_slice(observation: Dictionary) -> Dictionary:
	if observation.is_empty():
		return {}
	return {
		"policy_interaction_kind_id": str(observation.get(
			"policy_interaction_kind_id",
			""
		)),
		"policy_discard_count": int(observation.get(
			"policy_discard_count",
			0
		)),
		"policy_steal_count": int(observation.get("policy_steal_count", 0)),
		"policy_lock_duration_microseconds": int(observation.get(
			"policy_lock_duration_microseconds",
			0
		)),
		"policy_cash_penalty": int(observation.get(
			"policy_cash_penalty",
			0
		)),
		"policy_steal_failure_cash": int(observation.get(
			"policy_steal_failure_cash",
			0
		)),
	}


static func _matches_interaction(
	observation: Dictionary,
	card_id: String,
	instance_id: String,
	slot_index: int,
	interaction_kind_id: String,
	discard_count: int,
	steal_count: int,
	lock_duration_seconds: int,
	cash_penalty: int,
	steal_failure_cash: int
) -> bool:
	var viewer := observation.get("viewer_ref", {}) as Dictionary
	return observation.get("schema_version") == OBSERVATION.SCHEMA_VERSION \
		and str(observation.get("source_kind", "")) == "own_hand" \
		and str(observation.get("visibility_scope_id", "")) \
			== "actor_private" \
		and int(viewer.get("actor_index", -1)) == FIXTURE.AI_ACTOR_INDEX \
		and str(observation.get("card_id", "")) == card_id \
		and str(observation.get("instance_id", "")) == instance_id \
		and int(observation.get("source_slot", -1)) == slot_index \
		and str(observation.get("semantic_interaction_kind_id", "")) \
			== interaction_kind_id \
		and int(observation.get("semantic_discard_count", -1)) == discard_count \
		and int(observation.get("semantic_steal_count", -1)) == steal_count \
		and int(observation.get("semantic_lock_duration_seconds", -1)) \
			== lock_duration_seconds \
		and int(observation.get("semantic_cash_penalty", -1)) == cash_penalty \
		and int(observation.get("semantic_steal_failure_cash", -1)) \
			== steal_failure_cash \
		and _proof_fingerprints_are_valid(observation)


static func _proof_fingerprints_are_valid(observation: Dictionary) -> bool:
	for field in [
		"source_revision",
		"instance_revision",
		"semantic_fingerprint",
		"authorization_receipt_fingerprint",
		"authorized_bundle_fingerprint",
		"source_attestation_fingerprint",
		"observation_fingerprint",
	]:
		if not WIRE.is_fingerprint(observation.get(field)):
			return false
	return true


static func _output_is_private_data_free(value: Variant) -> bool:
	return WIRE.is_closed_data(value) \
		and not _contains_forbidden_key(value)


static func _contains_forbidden_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant)
			if FORBIDDEN_OUTPUT_KEYS.has(key) \
				or _contains_forbidden_key((value as Dictionary).get(key_variant)):
				return true
	elif value is Array:
		for item in value as Array:
			if _contains_forbidden_key(item):
				return true
	return false


static func _observation_fingerprint(observation: Dictionary) -> String:
	for key in [
		"observation_fingerprint",
		"snapshot_fingerprint",
		"slice_fingerprint",
	]:
		var fingerprint := str(observation.get(key, ""))
		if WIRE.is_fingerprint(fingerprint):
			return fingerprint
	return ""


static func _counter_delta(
	before: Dictionary,
	after: Dictionary,
	key: String
) -> int:
	return int(after.get(key, -1)) - int(before.get(key, -1))


static func _capability_debug_is_count_only(snapshot: Dictionary) -> bool:
	if not WIRE.is_closed_data(snapshot):
		return false
	var allowed_fields := [
		"actor_capabilities_bound",
		"actor_capability_count",
		"capability_bind_rejection_count",
		"consumer_capability_bound",
		"consumer_capability_count",
		"exposes_actor_capabilities",
		"exposes_consumer_capability",
	]
	for key_variant in snapshot.keys():
		var key := str(key_variant)
		if not key.to_lower().contains("capabilit"):
			continue
		if not allowed_fields.has(key):
			return false
		var value: Variant = snapshot.get(key_variant)
		if key.ends_with("_count") and not (value is int):
			return false
		if not key.ends_with("_count") and not (value is bool):
			return false
	return true


static func _object_has_property(value: Object, property_name: String) -> bool:
	for property_variant in value.get_property_list():
		if not (property_variant is Dictionary):
			continue
		if str((property_variant as Dictionary).get("name", "")) \
			== property_name:
			return true
	return false


static func _source_metrics(snapshot: Dictionary) -> Dictionary:
	return _select_metrics(snapshot, [
		"authorization_attempt_count",
		"authorization_success_count",
		"replay_count",
		"collision_count",
		"request_binding_count",
		"journal_entry_count",
		"hand_snapshot_query_count",
		"source_revalidation_count",
		"catalog_compile_request_count",
		"catalog_spec_authorization_count",
		"policy_compatibility_attempt_count",
		"policy_compatibility_success_count",
		"policy_compatibility_rejection_count",
	])


static func _service_metrics(snapshot: Dictionary) -> Dictionary:
	return _select_metrics(snapshot, [
		"actor_capability_count",
		"consumer_capability_count",
		"capability_bind_rejection_count",
		"observation_attempt_count",
		"authorization_success_count",
		"authorization_rejection_count",
		"bundle_validation_count",
		"bundle_validation_success_count",
		"bundle_validation_rejection_count",
		"semantic_derivation_count",
		"policy_compatibility_success_count",
		"policy_compatibility_rejection_count",
		"observation_success_count",
		"observation_validation_count",
		"observation_validation_success_count",
		"observation_validation_rejection_count",
		"issued_observation_fingerprint_count",
		"issued_observation_eviction_count",
		"rejection_count",
	])


static func _select_metrics(snapshot: Dictionary, keys: Array) -> Dictionary:
	var result := {}
	for key_variant in keys:
		var key := str(key_variant)
		if snapshot.has(key) and snapshot.get(key) is int:
			result[key] = int(snapshot.get(key))
	return result


static func _check(state: Dictionary, condition: bool, check_id: String) -> void:
	state["checks"] = int(state.get("checks", 0)) + 1
	if not condition:
		(state.get("failures", []) as Array).append(check_id)


static func _finish(
	state: Dictionary,
	started_usec: int,
	details: Dictionary
) -> Dictionary:
	var failures := (state.get("failures", []) as Array).duplicate()
	return {
		"status": "PASS" if failures.is_empty() else "FAIL",
		"check_count": int(state.get("checks", 0)),
		"failure_count": failures.size(),
		"failures": failures,
		"elapsed_ms": snappedf(
			float(Time.get_ticks_usec() - started_usec) / 1000.0,
			0.001
		),
		"details": details.duplicate(true),
	}
