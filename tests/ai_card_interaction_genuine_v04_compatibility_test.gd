extends SceneTree

const COORDINATOR_SCENE := preload(
	"res://scenes/runtime/GameRuntimeCoordinator.tscn"
)
const SOURCE_FIXTURE := preload(
	"res://scripts/tools/card_semantic_source_authorization_fixture.gd"
)
const CARD_PLAY_REQUIREMENT_POLICY := preload(
	"res://scripts/cards/card_play_requirement_policy.gd"
)
const LEGACY_REFERENCE := preload(
	"res://scripts/cards/semantic/card_v04_interaction_semantic_reference_adapter_v1.gd"
)
const LEGACY_SOURCE_BUNDLE := preload(
	"res://scripts/semantic/ai_card_interaction_legacy_source_bundle_v1.gd"
)

const ACTOR_INDEX := 1
const LEGACY_CARD_IDS := [
	"星链拆解1",
	"星链拆解2",
	"星链拆解3",
	"星链拆解4",
	"影仓牵引1",
	"影仓牵引2",
	"影仓牵引3",
	"影仓牵引4",
]
const SEMANTIC_CARD_IDS := [
	"interaction.starlink_dismantle.rank_1",
	"interaction.starlink_dismantle.rank_2",
	"interaction.starlink_dismantle.rank_3",
	"interaction.starlink_dismantle.rank_4",
	"interaction.shadow_warehouse_traction.rank_1",
	"interaction.shadow_warehouse_traction.rank_2",
	"interaction.shadow_warehouse_traction.rank_3",
	"interaction.shadow_warehouse_traction.rank_4",
]
const EXPECTED_POLICY := [
	["player_hand_disrupt", 1, 0, 0, 0, 0],
	["player_hand_disrupt", 1, 0, 10000000, 0, 0],
	["player_hand_disrupt", 1, 0, 18000000, 80, 0],
	["player_hand_disrupt", 2, 0, 20000000, 120, 0],
	["player_hand_steal", 0, 1, 0, 0, 60],
	["player_hand_steal", 0, 1, 8000000, 0, 90],
	["player_hand_steal", 0, 1, 15000000, 0, 140],
	["player_hand_steal", 0, 2, 18000000, 0, 220],
]

var _checks := 0
var _failures: Array[String] = []
var _started_usec := 0


func _init() -> void:
	_started_usec = Time.get_ticks_usec()
	call_deferred("_run")


func _run() -> void:
	var coordinator := COORDINATOR_SCENE.instantiate() as GameRuntimeCoordinator
	_expect(coordinator != null, "production coordinator instantiates")
	if coordinator == null:
		_finish()
		return
	coordinator.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(coordinator)
	await process_frame
	var fixture := SOURCE_FIXTURE.configure_coordinator(
		coordinator,
		"ai.card.interaction.genuine-v04.compatibility"
	)
	var world := fixture.get("world") as WorldSessionState
	var source := fixture.get("source") as CardSemanticSourceAuthorizationPort
	var semantic_catalog := fixture.get("catalog") \
		as CardSemanticCatalogService
	var rng := fixture.get("rng") as RunRngService
	var actor_capability := fixture.get("capability") \
		as AiActorHandInventoryCapability
	var observation_service := coordinator.get_node_or_null(
		"AiCardInteractionObservationService"
	) as AiCardInteractionObservationService
	var legacy_catalog := coordinator.get_node_or_null(
		"CardRuntimeCatalogService"
	) as CardRuntimeCatalogService
	var consumer_map_value: Variant = coordinator.get(
		"_ai_card_interaction_observation_capability_by_actor"
	)
	var consumer_map := consumer_map_value as Dictionary \
		if consumer_map_value is Dictionary else {}
	var consumer_value: Variant = consumer_map.get(ACTOR_INDEX)
	var consumer_capability := consumer_value as RefCounted \
		if consumer_value is RefCounted else null
	var ready := not fixture.is_empty() \
		and world != null \
		and source != null \
		and semantic_catalog != null \
		and rng != null \
		and actor_capability != null \
		and observation_service != null \
		and observation_service.is_ready() \
		and legacy_catalog != null \
		and consumer_capability != null
	_expect(ready, "production owner, catalog, capability, and service are ready")
	if not ready:
		coordinator.queue_free()
		await process_frame
		_finish()
		return

	var catalog_before := semantic_catalog.validation_snapshot()
	var rng_before := rng.capture_plan_checkpoint()
	for index in range(LEGACY_CARD_IDS.size()):
		var legacy_card_id := str(LEGACY_CARD_IDS[index])
		var card := _legacy_runtime_card(
			legacy_catalog,
			legacy_card_id,
			"v04-compatibility:%02d" % index
		)
		_expect(not card.is_empty(), "%s exact v0.4 definition resolves" % legacy_card_id)
		_replace_actor_card(world, card)
		var generic_bundle := source.authorize_own_hand_card(
			actor_capability,
			ACTOR_INDEX,
			0,
			"v04-generic-reject-%02d" % index
		)
		_expect(
			not bool(generic_bundle.get("accepted", false))
				and str(generic_bundle.get("reason_id", "")) \
					== CardSemanticSourceAuthorizationPort \
						.REASON_SOURCE_CARD_RECORD_INVALID,
			"%s cannot masquerade as a general CardSemanticSpec bundle" \
				% legacy_card_id
		)
		var specialized := source \
			.authorize_own_hand_v04_interaction_observation_source(
				actor_capability,
				ACTOR_INDEX,
				0
			)
		var source_bundle := specialized.get("source_bundle", {}) as Dictionary
		_expect(
			bool(specialized.get("accepted", false))
				and bool(LEGACY_SOURCE_BUNDLE.validate(source_bundle).get(
					"valid",
					false
				))
				and str(source_bundle.get("semantic_card_id", "")) \
					== str(SEMANTIC_CARD_IDS[index]),
			"%s receives the closed observation-only semantic witness" \
				% legacy_card_id
		)
		var source_text := JSON.stringify(source_bundle)
		_expect(
			not source_text.contains(legacy_card_id)
				and not source_bundle.has("semantic_spec")
				and not source_bundle.has("machine")
				and not source_bundle.has("player")
				and not source_bundle.has("developer"),
			"%s source bundle exposes no legacy ID or full static record" \
				% legacy_card_id
		)
		var observation := observation_service.observe_own_hand_interaction(
			consumer_capability,
			ACTOR_INDEX,
			0
		)
		_expect(
			not observation.is_empty()
				and str(observation.get("card_id", "")) \
					== str(SEMANTIC_CARD_IDS[index])
				and _observation_policy(observation) == EXPECTED_POLICY[index],
			"%s maps to the frozen legacy scoring policy" % legacy_card_id
		)
		_expect(
			bool(observation_service.validate_observation(
				consumer_capability,
				ACTOR_INDEX,
				observation
			).get(
				"valid",
				false
			)),
			"%s issued observation revalidates against the current owner slot" \
				% legacy_card_id
		)

	_run_adversarial_cases(
		world,
		legacy_catalog,
		observation_service,
		consumer_capability
	)
	var stable_card := _legacy_runtime_card(
		legacy_catalog,
		str(LEGACY_CARD_IDS[0]),
		"v04-compatibility:stale-before"
	)
	_replace_actor_card(world, stable_card)
	var stale_observation := observation_service.observe_own_hand_interaction(
		consumer_capability,
		ACTOR_INDEX,
		0
	)
	stable_card["runtime_instance_id"] = "v04-compatibility:stale-after"
	_replace_actor_card(world, stable_card)
	_expect(
		not stale_observation.is_empty()
		and not bool(observation_service.validate_observation(
				consumer_capability,
				ACTOR_INDEX,
				stale_observation
			).get("valid", true)),
		"slot replacement makes an issued v0.4 observation stale"
	)
	var catalog_after := semantic_catalog.validation_snapshot()
	_expect(
		int(catalog_after.get("compile_count", -1)) \
			== int(catalog_before.get("compile_count", -2))
			and int(catalog_after.get("cache_entry_count", -1)) \
				== int(catalog_before.get("cache_entry_count", -2)),
		"all v0.4 witnesses reuse the sealed semantic cache with zero compile delta"
	)
	_expect(
		rng.capture_plan_checkpoint() == rng_before,
		"authorization, observation, rejection, and stale checks consume zero RNG"
	)
	_expect(
		LEGACY_REFERENCE.supported_reference_count() == 8,
		"temporary compatibility allowlist remains exactly eight references"
	)
	coordinator.queue_free()
	await process_frame
	_finish()


func _run_adversarial_cases(
	world: WorldSessionState,
	legacy_catalog: CardRuntimeCatalogService,
	service: AiCardInteractionObservationService,
	consumer_capability: RefCounted
) -> void:
	var base := _legacy_runtime_card(
		legacy_catalog,
		str(LEGACY_CARD_IDS[0]),
		"v04-compatibility:adversarial"
	)
	var cases := []
	var fuzzy_roman := base.duplicate(true)
	fuzzy_roman["name"] = "星链拆解I"
	cases.append(["roman suffix", fuzzy_roman])
	var fuzzy_zero := base.duplicate(true)
	fuzzy_zero["name"] = "星链拆解01"
	cases.append(["zero-padded suffix", fuzzy_zero])
	var wrong_rank := base.duplicate(true)
	wrong_rank["name"] = "星链拆解5"
	cases.append(["unknown rank", wrong_rank])
	var changed_cost := base.duplicate(true)
	changed_cost["cost"] = int(changed_cost.get("cost", 0)) + 1
	cases.append(["same-ID cost mutation", changed_cost])
	var changed_text := base.duplicate(true)
	changed_text["text"] = "mutated"
	cases.append(["same-ID text mutation", changed_text])
	var changed_policy := base.duplicate(true)
	changed_policy["hand_discard_count"] = 2
	cases.append(["same-ID policy mutation", changed_policy])
	var injected_policy := base.duplicate(true)
	injected_policy["target_cash_penalty"] = 1
	cases.append(["absent policy injection", injected_policy])
	var mixed_blocks := base.duplicate(true)
	mixed_blocks["machine"] = {"card_id": str(SEMANTIC_CARD_IDS[0])}
	cases.append(["mixed v0.4/v0.6 carrier", mixed_blocks])
	var unknown_private := base.duplicate(true)
	unknown_private["future_private_value"] = "hostile"
	cases.append(["unknown extra value channel", unknown_private])
	var case_variant_private := base.duplicate(true)
	case_variant_private["Effect_Payload"] = {"hostile": true}
	cases.append(["case-variant value channel", case_variant_private])
	for private_field in [
		"owner",
		"hidden_owner",
		"true_owner",
		"player_index",
		"hand",
		"opponent_hand",
		"exact_cash",
		"private_plan",
		"ai_score",
		"ai_value",
		"route_plan",
		"future_bag",
		"rng_state",
		"save_payload",
		"developer",
		"effect_payload",
		"skill",
		"method_name",
		"script_path",
	]:
		var injected_private_field := base.duplicate(true)
		injected_private_field[private_field] = "hostile"
		cases.append(["private value channel %s" % private_field, injected_private_field])
	for case_value in cases:
		var case_row := case_value as Array
		_replace_actor_card(world, case_row[1] as Dictionary)
		var observation := service.observe_own_hand_interaction(
			consumer_capability,
			ACTOR_INDEX,
			0
		)
		_expect(observation.is_empty(), "%s fails closed" % str(case_row[0]))


func _legacy_runtime_card(
	catalog: CardRuntimeCatalogService,
	legacy_card_id: String,
	instance_id: String
) -> Dictionary:
	var definition := catalog.exact_definition(legacy_card_id)
	if definition.is_empty():
		return {}
	var card := CARD_PLAY_REQUIREMENT_POLICY.apply_to_card(
		legacy_card_id,
		definition
	)
	card["runtime_instance_id"] = instance_id
	card["queued_for_resolution"] = false
	card["cooldown_left"] = 0.0
	card["lock_left"] = 0.0
	card["persistent"] = false
	return card


func _replace_actor_card(world: WorldSessionState, card: Dictionary) -> void:
	var snapshot := world.internal_snapshot()
	var players := snapshot.get("players", []) as Array
	var actor := (players[ACTOR_INDEX] as Dictionary).duplicate(true)
	actor["slots"] = [card.duplicate(true)]
	players[ACTOR_INDEX] = actor
	snapshot["players"] = players
	world.restore(snapshot, true)


func _observation_policy(observation: Dictionary) -> Array:
	return [
		str(observation.get("policy_interaction_kind_id", "")),
		int(observation.get("policy_discard_count", -1)),
		int(observation.get("policy_steal_count", -1)),
		int(observation.get("policy_lock_duration_microseconds", -1)),
		int(observation.get("policy_cash_penalty", -1)),
		int(observation.get("policy_steal_failure_cash", -1)),
	]


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	var duration_ms := snappedf(
		float(Time.get_ticks_usec() - _started_usec) / 1000.0,
		0.001
	)
	_expect(duration_ms < 60000.0, "focused compatibility test stays below 60 seconds")
	if _failures.is_empty():
		print(
			"AI_CARD_INTERACTION_GENUINE_V04_COMPATIBILITY_TEST_COMPLETE|"
			+ "status=PASS|checks=%d|failures=0|duration_ms=%.3f" \
			% [_checks, duration_ms]
		)
		quit(0)
		return
	for failure in _failures:
		push_error("Genuine v0.4 interaction compatibility failed: %s" % failure)
	print(
		"AI_CARD_INTERACTION_GENUINE_V04_COMPATIBILITY_TEST_COMPLETE|"
		+ "status=FAIL|checks=%d|failures=%d|duration_ms=%.3f|details=%s" \
		% [_checks, _failures.size(), duration_ms, JSON.stringify(_failures)]
	)
	quit(1)
