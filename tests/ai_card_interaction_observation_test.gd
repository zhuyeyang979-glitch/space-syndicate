extends SceneTree

const COORDINATOR_SCENE := preload(
	"res://scenes/runtime/GameRuntimeCoordinator.tscn"
)
const CATALOG_PATH := \
	"res://resources/cards/runtime/card_runtime_catalog_v06.tres"
const OBSERVATION_CAPABILITY := preload(
	"res://scripts/runtime/ai_card_interaction_observation_capability.gd"
)
const SESSION_ID := "ai.card.interaction.observation.test"
const AI_ACTOR_INDEX := 1
const OTHER_AI_ACTOR_INDEX := 2
const BASELINE_CARD_ID := "interaction.starlink_dismantle.rank_3"
const UNSUPPORTED_CARD_ID := "interaction.phase_veto.rank_1"
const FORBIDDEN_FIELDS := [
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
	"developer",
	"effect_payload",
	"card",
	"machine",
	"player",
	"skill",
	"method_name",
	"script_path",
]
const LEGACY_INTERACTION_FIELDS := [
	"kind",
	"hand_discard_count",
	"hand_steal_count",
	"hand_lock_seconds",
	"target_cash_penalty",
	"steal_fail_cash",
]
const INTERACTION_CASES := [
	{
		"card_id": "interaction.starlink_dismantle.rank_1",
		"semantic_interaction_kind_id": "player_hand_disrupt",
		"semantic_discard_count": 1,
		"semantic_steal_count": 0,
		"semantic_lock_duration_seconds": 0,
		"semantic_cash_penalty": 0,
		"semantic_steal_failure_cash": 0,
	},
	{
		"card_id": "interaction.starlink_dismantle.rank_2",
		"semantic_interaction_kind_id": "player_hand_disrupt",
		"semantic_discard_count": 1,
		"semantic_steal_count": 0,
		"semantic_lock_duration_seconds": 10,
		"semantic_cash_penalty": 0,
		"semantic_steal_failure_cash": 0,
	},
	{
		"card_id": "interaction.starlink_dismantle.rank_3",
		"semantic_interaction_kind_id": "player_hand_disrupt",
		"semantic_discard_count": 1,
		"semantic_steal_count": 0,
		"semantic_lock_duration_seconds": 18,
		"semantic_cash_penalty": 80,
		"semantic_steal_failure_cash": 0,
	},
	{
		"card_id": "interaction.starlink_dismantle.rank_4",
		"semantic_interaction_kind_id": "player_hand_disrupt",
		"semantic_discard_count": 2,
		"semantic_steal_count": 0,
		"semantic_lock_duration_seconds": 20,
		"semantic_cash_penalty": 120,
		"semantic_steal_failure_cash": 0,
	},
	{
		"card_id": "interaction.shadow_warehouse_traction.rank_1",
		"semantic_interaction_kind_id": "player_hand_steal",
		"semantic_discard_count": 0,
		"semantic_steal_count": 1,
		"semantic_lock_duration_seconds": 0,
		"semantic_cash_penalty": 0,
		"semantic_steal_failure_cash": 60,
	},
	{
		"card_id": "interaction.shadow_warehouse_traction.rank_2",
		"semantic_interaction_kind_id": "player_hand_steal",
		"semantic_discard_count": 0,
		"semantic_steal_count": 1,
		"semantic_lock_duration_seconds": 8,
		"semantic_cash_penalty": 0,
		"semantic_steal_failure_cash": 90,
	},
	{
		"card_id": "interaction.shadow_warehouse_traction.rank_3",
		"semantic_interaction_kind_id": "player_hand_steal",
		"semantic_discard_count": 0,
		"semantic_steal_count": 1,
		"semantic_lock_duration_seconds": 15,
		"semantic_cash_penalty": 0,
		"semantic_steal_failure_cash": 140,
	},
	{
		"card_id": "interaction.shadow_warehouse_traction.rank_4",
		"semantic_interaction_kind_id": "player_hand_steal",
		"semantic_discard_count": 0,
		"semantic_steal_count": 2,
		"semantic_lock_duration_seconds": 18,
		"semantic_cash_penalty": 0,
		"semantic_steal_failure_cash": 220,
	},
]

var _catalog: CardRuntimeCatalogV06Resource
var _observation_capability: RefCounted
var _observation_capability_by_actor: Dictionary = {}
var _first_binder_probe_service: AiCardInteractionObservationService
var _first_binder_probe_ai: AiRuntimeController
var _first_binder_probe_capability: RefCounted
var _first_binder_probe_attempted := false
var _first_binder_probe_accepted := true
var _first_binder_probe_ai_accepted := true
var _checks := 0
var _failures: Array[String] = []
var _started_usec := 0


func _init() -> void:
	_started_usec = Time.get_ticks_usec()
	call_deferred("_run")


func _run() -> void:
	var coordinator := COORDINATOR_SCENE.instantiate() as GameRuntimeCoordinator
	_expect(coordinator != null, "real GameRuntimeCoordinator instantiates")
	if coordinator == null:
		_finish()
		return
	_first_binder_probe_service = coordinator.get_node_or_null(
		"AiCardInteractionObservationService"
	) as AiCardInteractionObservationService
	_first_binder_probe_ai = coordinator.get_node_or_null(
		"AiRuntimeController"
	) as AiRuntimeController
	_first_binder_probe_capability = OBSERVATION_CAPABILITY.new()
	var first_binder_probe := Node.new()
	first_binder_probe.name = "HostileObservationFirstBinderProbe"
	first_binder_probe.tree_entered.connect(
		_on_hostile_observation_first_binder_probe_entered
	)
	coordinator.add_child(first_binder_probe)
	root.add_child(coordinator)
	await process_frame
	_expect(
		_first_binder_probe_attempted \
			and not _first_binder_probe_accepted \
			and not _first_binder_probe_ai_accepted,
		"Coordinator prebinds the observation service and AI consumer before child lifecycle callbacks"
	)

	_catalog = load(CATALOG_PATH) as CardRuntimeCatalogV06Resource
	_expect(
		_catalog != null and bool(_catalog.reload().get("valid", false)),
		"complete v0.6 runtime catalog loads"
	)
	var fixture := _configure_fixture(coordinator)
	_expect(not fixture.is_empty(), "real coordinator fixture configures")
	if fixture.is_empty():
		coordinator.queue_free()
		await process_frame
		_finish()
		return

	var service := fixture.get("service") as AiCardInteractionObservationService
	var observation_capabilities := fixture.get(
		"observation_capabilities"
	) as Dictionary
	_observation_capability_by_actor = observation_capabilities.duplicate()
	_observation_capability = _observation_capability_by_actor.get(
		AI_ACTOR_INDEX
	) as RefCounted
	var semantic_catalog := fixture.get("semantic_catalog") \
		as CardSemanticCatalogService
	var rng := fixture.get("rng") as RunRngService
	_expect(
		service.is_ready() and _observation_capability != null,
		"production interaction observation service and consumer capability are ready"
	)
	var compile_before := int(
		semantic_catalog.validation_snapshot().get("compile_count", -1)
	)
	var rng_before := rng.capture_plan_checkpoint()

	_test_all_eight_interaction_ranks(fixture)
	_test_production_legacy_policy_shape(fixture)
	_test_policy_compatibility_adversarial(fixture)
	_replace_ai_slots(fixture, [
		_runtime_card(BASELINE_CARD_ID, "interaction-observation:baseline")
	])
	var baseline := _observe(service,
		AI_ACTOR_INDEX,
		0
	)
	_expect(not baseline.is_empty(), "baseline observation is issued")
	if not baseline.is_empty():
		_test_closed_schema_and_fingerprint(service, baseline)
		_test_forbidden_value_channels(service, baseline)
		_test_same_id_mutation_and_issue_attestation(service, baseline)
	_test_capability_binding_actor_and_slot_rejections(fixture)
	_test_stale_slot_and_session_rejections(fixture, baseline)
	_test_catalog_record_same_id_mutation(fixture)
	_test_unsupported_mixed_and_duplicate_operations(fixture)
	_test_debug_snapshot_privacy(service)

	_expect(
		int(semantic_catalog.validation_snapshot().get("compile_count", -2))
			== compile_before,
		"authorized interaction observations compile zero semantic specs"
	)
	_expect(
		rng.capture_plan_checkpoint() == rng_before,
		"observation success and rejection consume zero RNG"
	)

	coordinator.queue_free()
	await process_frame
	_finish()


func _on_hostile_observation_first_binder_probe_entered() -> void:
	_first_binder_probe_attempted = true
	_first_binder_probe_accepted = _first_binder_probe_service != null \
		and _first_binder_probe_service.bind_consumer_capabilities(
			{AI_ACTOR_INDEX: _first_binder_probe_capability}
		)
	_first_binder_probe_ai_accepted = _first_binder_probe_ai != null \
		and _first_binder_probe_ai.set_card_interaction_observation_source(
			_first_binder_probe_service,
			{AI_ACTOR_INDEX: _first_binder_probe_capability}
		)


func _configure_fixture(coordinator: GameRuntimeCoordinator) -> Dictionary:
	if _catalog == null:
		return {}
	var world := coordinator.world_session_state()
	var session := coordinator.get_node_or_null(
		"GameSessionRuntimeController"
	) as GameSessionRuntimeController
	var role_catalog := coordinator.get_node_or_null(
		"RoleCatalogRuntimeService"
	) as RoleCatalogRuntimeService
	var inventory := coordinator.get_node_or_null(
		"CardInventoryRuntimeService"
	) as CardInventoryRuntimeService
	var source := coordinator.get_node_or_null(
		"CardSemanticSourceAuthorizationPort"
	) as CardSemanticSourceAuthorizationPort
	var semantic_catalog := coordinator.get_node_or_null(
		"CardSemanticCatalogService"
	) as CardSemanticCatalogService
	var service := coordinator.get_node_or_null(
		"AiCardInteractionObservationService"
	) as AiCardInteractionObservationService
	var rng := coordinator.run_rng_service()
	if world == null or session == null or role_catalog == null \
			or inventory == null or source == null \
			or semantic_catalog == null or service == null or rng == null:
		return {}
	inventory.configure({
		"ruleset_id": "v0.4",
		"card_inventory": {
			"ordinary_hand_limit": 8,
			"maximum_card_rank": 4,
		},
	})
	session.configure({"ruleset_id": "v0.6"}, {})
	var started := session.begin_session({
		"session_id": SESSION_ID,
		"scenario_id": "ai.card.interaction.observation",
		"seed": 1618033,
		"player_count": 4,
	})
	var baseline_slots := [
		_runtime_card(BASELINE_CARD_ID, "interaction-observation:baseline")
	]
	world.restore({
		"players": _players(role_catalog, baseline_slots),
		"districts": [],
		"game_time": 31.0,
	}, true)
	var actor_capabilities_variant: Variant = coordinator.get(
		"_card_semantic_source_capability_by_actor"
	)
	var actor_capabilities := actor_capabilities_variant as Dictionary \
		if actor_capabilities_variant is Dictionary else {}
	var capability := actor_capabilities.get(AI_ACTOR_INDEX) \
		as AiActorHandInventoryCapability
	var observation_capabilities_variant: Variant = coordinator.get(
		"_ai_card_interaction_observation_capability_by_actor"
	)
	var observation_capabilities := observation_capabilities_variant \
		as Dictionary if observation_capabilities_variant is Dictionary else {}
	var observation_capability := observation_capabilities.get(
		AI_ACTOR_INDEX
	) as RefCounted
	if str(started.get("session_state", "")) \
			!= GameSessionRuntimeController.STATE_RUNNING \
			or capability == null or observation_capability == null:
		return {}
	return {
		"coordinator": coordinator,
		"world": world,
		"session": session,
		"source": source,
		"semantic_catalog": semantic_catalog,
		"service": service,
		"observation_capability": observation_capability,
		"observation_capabilities": observation_capabilities.duplicate(),
		"rng": rng,
		"capability": capability,
		"actor_capabilities": actor_capabilities.duplicate(),
		"baseline_slots": baseline_slots.duplicate(true),
	}


func _observe(
	service: AiCardInteractionObservationService,
	actor_index: int,
	slot_index: int
) -> Dictionary:
	var capability := _observation_capability_by_actor.get(actor_index) \
		as RefCounted
	return service.observe_own_hand_interaction(
		capability,
		actor_index,
		slot_index
	)


func _test_all_eight_interaction_ranks(fixture: Dictionary) -> void:
	var service := fixture.get("service") as AiCardInteractionObservationService
	var observed_card_ids: Array[String] = []
	var expected_card_ids: Array[String] = []
	for case_variant in INTERACTION_CASES:
		var interaction_case := case_variant as Dictionary
		var card_id := str(interaction_case.get("card_id", ""))
		expected_card_ids.append(card_id)
		var card := _runtime_card(
			card_id,
			"interaction-observation:%s" % card_id
		)
		_expect(not card.is_empty(), "%s exists in the authoritative catalog" % card_id)
		_replace_ai_slots(fixture, [card])
		var first := _observe(service,
			AI_ACTOR_INDEX,
			0
		)
		var second := _observe(service,
			AI_ACTOR_INDEX,
			0
		)
		_expect(
			first == second and _observation_valid(service, first),
			"%s produces one deterministic owner-attested observation" % card_id
		)
		if first.is_empty():
			continue
		observed_card_ids.append(str(first.get("card_id", "")))
		_expect(
			first.keys() == AiCardInteractionObservationV1.FIELDS,
			"%s uses the exact closed observation schema" % card_id
		)
		for field in [
			"semantic_interaction_kind_id",
			"semantic_discard_count",
			"semantic_steal_count",
			"semantic_lock_duration_seconds",
			"semantic_cash_penalty",
			"semantic_steal_failure_cash",
		]:
			_expect(
				first.get(field) == interaction_case.get(field),
				"%s projects canonical %s" % [card_id, field]
			)
		_expect(
			str(first.get("policy_compatibility_id", ""))
				== "legacy_ai_card_interaction_flat_fields_v1"
				and str(first.get("policy_interaction_kind_id", ""))
					== "player_hand_disrupt"
				and int(first.get("policy_discard_count", -1)) == 0
				and int(first.get("policy_steal_count", -1)) == 0
				and int(first.get(
					"policy_lock_duration_microseconds",
					-1
				)) == 0
				and int(first.get("policy_cash_penalty", -1)) == 0
				and int(first.get("policy_steal_failure_cash", -1)) == 0
				and SemanticWireV1.is_fingerprint(first.get(
					"policy_compatibility_fingerprint"
				)),
			"%s keeps legacy-effective policy separate from semantic facts"
				% card_id
		)
		_expect(
			str(first.get("card_id", "")) == card_id
				and str(first.get("runtime_readiness_id", ""))
					== "projection_only"
				and int(first.get("source_slot", -1)) == 0
				and int(((first.get("viewer_ref", {}) as Dictionary).get(
					"actor_index",
					-1
				))) == AI_ACTOR_INDEX,
			"%s remains bound to the exact actor-private slot" % card_id
		)
		var serialized := JSON.stringify(first)
		for legacy_field in LEGACY_INTERACTION_FIELDS:
			_expect(
				not (first as Dictionary).has(legacy_field),
				"%s emits no raw legacy field %s" % [card_id, legacy_field]
			)
		for forbidden in FORBIDDEN_FIELDS:
			_expect(
				not _contains_key_recursive(first, forbidden),
				"%s emits no forbidden value channel %s" % [card_id, forbidden]
			)
		_expect(
			not serialized.contains("runtime_card")
				and SemanticWireV1.is_closed_data(first),
			"%s output is detached wire data" % card_id
		)
	_expect(
		observed_card_ids.size() == 8
			and observed_card_ids == expected_card_ids,
		"all eight interaction ranks are covered in stable catalog order"
	)


func _test_production_legacy_policy_shape(fixture: Dictionary) -> void:
	var service := fixture.get("service") as AiCardInteractionObservationService
	var card := _runtime_card(
		BASELINE_CARD_ID,
		"interaction-observation:production-policy"
	)
	card["kind"] = "interaction"
	card["hand_discard_count"] = 2
	card["hand_steal_count"] = 0
	card["hand_lock_seconds"] = 18.0
	card["target_cash_penalty"] = 80
	card["steal_fail_cash"] = 0
	_replace_ai_slots(fixture, [card])
	var observation := _observe(service,AI_ACTOR_INDEX, 0)
	_expect(
		_observation_valid(service, observation)
			and str(observation.get("policy_interaction_kind_id", ""))
				== "interaction"
			and int(observation.get("policy_discard_count", -1)) == 2
			and int(observation.get("policy_steal_count", -1)) == 0
			and int(observation.get(
				"policy_lock_duration_microseconds",
				-1
			)) == 18000000
			and int(observation.get("policy_cash_penalty", -1)) == 80
			and int(observation.get("policy_steal_failure_cash", -1)) == 0,
		"production category kind and flat values preserve exact legacy policy"
	)
	_expect(
		str(observation.get("semantic_interaction_kind_id", ""))
			== "player_hand_disrupt"
			and int(observation.get("semantic_discard_count", -1)) == 1,
		"production policy fields cannot rewrite canonical semantic facts"
	)


func _test_policy_compatibility_adversarial(fixture: Dictionary) -> void:
	var source := fixture.get("source") as CardSemanticSourceAuthorizationPort
	var service := fixture.get("service") as AiCardInteractionObservationService
	var capability := fixture.get("capability") \
		as AiActorHandInventoryCapability
	var first := _runtime_card(
		BASELINE_CARD_ID,
		"interaction-observation:policy-slot-a"
	)
	var second := _runtime_card(
		BASELINE_CARD_ID,
		"interaction-observation:policy-slot-b"
	)
	_replace_ai_slots(fixture, [first, second])
	var first_bundle := source.authorize_own_hand_card(
		capability,
		AI_ACTOR_INDEX,
		0
	)
	var second_bundle := source.authorize_own_hand_card(
		capability,
		AI_ACTOR_INDEX,
		1
	)
	var first_policy := source \
		.authorize_own_hand_interaction_policy_compatibility(
			capability,
			AI_ACTOR_INDEX,
			0,
			first_bundle
		)
	var second_policy := source \
		.authorize_own_hand_interaction_policy_compatibility(
			capability,
			AI_ACTOR_INDEX,
			1,
			second_bundle
		)
	var first_profile := first_policy.get(
		"policy_compatibility_profile",
		{}
	) as Dictionary
	var second_profile := second_policy.get(
		"policy_compatibility_profile",
		{}
	) as Dictionary
	_expect(
		bool(first_policy.get("accepted", false))
			and bool(second_policy.get("accepted", false))
			and int(first_profile.get("source_slot", -1)) == 0
			and int(second_profile.get("source_slot", -1)) == 1
			and str(first_profile.get("instance_id", ""))
				!= str(second_profile.get("instance_id", ""))
			and str(first_profile.get(
				"policy_compatibility_fingerprint",
				""
			)) != str(second_profile.get(
				"policy_compatibility_fingerprint",
				""
			)),
		"same-card slots receive distinct instance-bound policy profiles"
	)
	var cross_slot := source \
		.authorize_own_hand_interaction_policy_compatibility(
			capability,
			AI_ACTOR_INDEX,
			1,
			first_bundle
		)
	_expect(
		not bool(cross_slot.get("accepted", true)),
		"bundle and policy profile cannot be spliced across slots"
	)

	var invalid_values: Array = [
		{"field": "hand_discard_count", "value": []},
		{"field": "hand_discard_count", "value": 1.9},
		{"field": "hand_steal_count", "value": -1},
		{"field": "target_cash_penalty", "value": 2.5},
		{"field": "hand_lock_seconds", "value": 0.1249996},
	]
	for case_value in invalid_values:
		var invalid_case := case_value as Dictionary
		var invalid_card := _runtime_card(
			BASELINE_CARD_ID,
			"interaction-observation:invalid-policy:%s"
				% str(invalid_case.get("field", ""))
		)
		invalid_card[str(invalid_case.get("field", ""))] = invalid_case.get(
			"value"
		)
		_replace_ai_slots(fixture, [invalid_card])
		_expect(
			_observe(service,
				AI_ACTOR_INDEX,
				0
			).is_empty(),
			"invalid policy source value fails closed: %s"
				% str(invalid_case.get("field", ""))
		)
	var numeric_card := {
		"kind": "player_hand_disrupt",
		"hand_discard_count": 0,
		"hand_steal_count": 0,
		"hand_lock_seconds": 0.0,
		"target_cash_penalty": 0,
		"steal_fail_cash": 0,
	}
	for unsafe_numeric in [INF, NAN]:
		var unsafe_card := numeric_card.duplicate(true)
		unsafe_card["target_cash_penalty"] = unsafe_numeric
		var facts := source.call(
			"_legacy_interaction_policy_facts",
			unsafe_card
		) as Dictionary
		_expect(
			not bool(facts.get("valid", true)),
			"non-finite owner compatibility values fail closed before wire output"
		)


func _test_closed_schema_and_fingerprint(
	service: AiCardInteractionObservationService,
	observation: Dictionary
) -> void:
	var core := _core_from_observation(observation)
	var rebuilt := AiCardInteractionObservationV1.build(core)
	var rebuilt_again := AiCardInteractionObservationV1.build(
		core.duplicate(true)
	)
	_expect(
		rebuilt == observation and rebuilt_again == observation,
		"closed schema build and fingerprint are deterministic"
	)
	_expect(
		str(observation.get("observation_fingerprint", ""))
			== SemanticWireV1.fingerprint(
				observation,
				"observation_fingerprint"
			),
		"observation fingerprint seals canonical sorted-key data"
	)
	var unknown := core.duplicate(true)
	unknown["future_private_value"] = 1
	_expect(
		AiCardInteractionObservationV1.build(unknown).is_empty(),
		"unknown build key fails closed"
	)
	var missing := core.duplicate(true)
	missing.erase("semantic_fingerprint")
	_expect(
		AiCardInteractionObservationV1.build(missing).is_empty(),
		"missing required build key fails closed"
	)
	var extra_sealed := observation.duplicate(true)
	extra_sealed["future_private_value"] = 1
	_expect(
		not bool(AiCardInteractionObservationV1.validate(extra_sealed).get(
			"valid",
			true
		)),
		"unknown sealed key fails closed"
	)
	var missing_sealed := observation.duplicate(true)
	missing_sealed.erase("authorization_receipt_fingerprint")
	_expect(
		not bool(service.validate_observation(
			_observation_capability,
			AI_ACTOR_INDEX,
			missing_sealed
		).get(
			"valid",
			true
		)),
		"service rejects an incomplete observation"
	)
	core["semantic_cash_penalty"] = 999
	_expect(
		rebuilt == observation,
		"built observation is deeply detached from caller input"
	)


func _test_forbidden_value_channels(
	service: AiCardInteractionObservationService,
	observation: Dictionary
) -> void:
	var core := _core_from_observation(observation)
	for forbidden_field in FORBIDDEN_FIELDS:
		var injected_core := core.duplicate(true)
		injected_core[forbidden_field] = "forbidden.value"
		_expect(
			AiCardInteractionObservationV1.build(injected_core).is_empty(),
			"build rejects forbidden field %s" % forbidden_field
		)
		var injected_observation := observation.duplicate(true)
		injected_observation[forbidden_field] = "forbidden.value"
		injected_observation["observation_fingerprint"] = \
			SemanticWireV1.fingerprint(
				injected_observation,
				"observation_fingerprint"
			)
		_expect(
			not bool(service.validate_observation(
				_observation_capability,
				AI_ACTOR_INDEX,
				injected_observation
			).get(
				"valid",
				true
			)),
			"service rejects resigned forbidden field %s" % forbidden_field
		)
	var nested := observation.duplicate(true)
	var nested_viewer := (nested.get("viewer_ref", {}) as Dictionary).duplicate(
		true
	)
	nested_viewer["hidden_owner"] = "player.2"
	nested["viewer_ref"] = nested_viewer
	nested["observation_fingerprint"] = SemanticWireV1.fingerprint(
		nested,
		"observation_fingerprint"
	)
	_expect(
		not bool(service.validate_observation(
			_observation_capability,
			AI_ACTOR_INDEX,
			nested
		).get("valid", true)),
		"nested hidden-owner injection fails closed"
	)

	var runtime_node := Node.new()
	var runtime_resource := Resource.new()
	var runtime_callable := Callable(self, "_finish")
	for unsafe_value in [runtime_node, runtime_resource, runtime_callable]:
		var unsafe_core := core.duplicate(true)
		unsafe_core["semantic_cash_penalty"] = unsafe_value
		_expect(
			AiCardInteractionObservationV1.build(unsafe_core).is_empty(),
			"Node, Resource, and Callable values fail closed"
		)
	runtime_node.free()


func _test_same_id_mutation_and_issue_attestation(
	service: AiCardInteractionObservationService,
	observation: Dictionary
) -> void:
	var in_place := observation.duplicate(true)
	in_place["semantic_cash_penalty"] = int(in_place.get("semantic_cash_penalty", 0)) + 1
	in_place["observation_fingerprint"] = SemanticWireV1.fingerprint(
		in_place,
		"observation_fingerprint"
	)
	_expect(
		not bool(AiCardInteractionObservationV1.validate(in_place).get(
			"valid",
			true
		)),
		"same observation ID cannot carry resigned mutated facts"
	)

	var resigned_core := _core_from_observation(observation)
	resigned_core["semantic_cash_penalty"] = int(resigned_core.get(
		"semantic_cash_penalty",
		0
	)) + 1
	var resigned := AiCardInteractionObservationV1.build(resigned_core)
	_expect(
		not resigned.is_empty()
			and bool(AiCardInteractionObservationV1.validate(resigned).get(
				"valid",
				false
			)),
		"adversary can make a schema-valid mutation for issue-attestation test"
	)
	_expect(
		not bool(service.validate_observation(
			_observation_capability,
			AI_ACTOR_INDEX,
			resigned
		).get("valid", true)),
		"service rejects schema-valid facts it did not issue from the owner"
	)
	_expect(
		bool(service.validate_observation(
			_observation_capability,
			AI_ACTOR_INDEX,
			observation
		).get("valid", false)),
		"service continues to accept the exact owner-issued observation"
	)


func _test_capability_binding_actor_and_slot_rejections(
	fixture: Dictionary
) -> void:
	var service := fixture.get("service") as AiCardInteractionObservationService
	var actor_capabilities := fixture.get("actor_capabilities") as Dictionary
	var observation_capabilities := fixture.get(
		"observation_capabilities"
	) as Dictionary
	var observation_capability := fixture.get("observation_capability") \
		as RefCounted
	var coordinator := fixture.get("coordinator") as GameRuntimeCoordinator
	var ai := coordinator.get_node_or_null(
		"AiRuntimeController"
	) as AiRuntimeController
	var debug_before := service.debug_snapshot()
	_expect(
		bool(debug_before.get("actor_capabilities_bound", false))
			and bool(debug_before.get("consumer_capability_bound", false))
			and not bool(debug_before.get(
				"exposes_consumer_capability",
				true
			))
			and int(debug_before.get("actor_capability_count", -1))
				== actor_capabilities.size()
			and int(debug_before.get("consumer_capability_count", -1))
				== observation_capabilities.size()
			and coordinator.find_children(
				"AiCardInteractionObservationService",
				"",
				true,
				false
			).size() == 1,
		"Coordinator binds exactly one production service capability map"
	)
	var rejection_count_before := int(debug_before.get(
		"capability_bind_rejection_count",
		-1
	))
	_expect(
		service.bind_consumer_capabilities(
			observation_capabilities.duplicate()
		)
			and not service.bind_consumer_capabilities(
				_observation_capability_replacement_map(
					observation_capabilities,
					AI_ACTOR_INDEX
				)
			)
			and not service.bind_consumer_capabilities({}),

		"consumer capability is one-shot, identity-bound, and null-safe"
	)
	var aliased_capability := OBSERVATION_CAPABILITY.new()
	var aliased_consumer_map := observation_capabilities.duplicate()
	aliased_consumer_map[AI_ACTOR_INDEX] = aliased_capability
	aliased_consumer_map[OTHER_AI_ACTOR_INDEX] = aliased_capability
	var alias_probe_service := AiCardInteractionObservationService.new()
	_expect(
		alias_probe_service.bind_actor_capabilities(
			actor_capabilities.duplicate()
		)
			and not alias_probe_service.bind_consumer_capabilities(
				aliased_consumer_map
			),
		"one consumer token cannot be initially aliased to multiple actors"
	)
	var alias_probe_ai := AiRuntimeController.new()
	_expect(
		not alias_probe_ai.set_card_interaction_observation_source(
			alias_probe_service,
			aliased_consumer_map
		),
		"AI consumer rejects an actor map with aliased token identities"
	)
	alias_probe_ai.free()
	alias_probe_service.free()
	_expect(
		service.observe_own_hand_interaction(
			null,
			AI_ACTOR_INDEX,
			0
		).is_empty()
			and service.observe_own_hand_interaction(
				OBSERVATION_CAPABILITY.new(),
				AI_ACTOR_INDEX,
				0
			).is_empty(),
		"ambient callers cannot borrow the service-held actor capabilities"
	)
	var current_observation := _observe(
		service,
		AI_ACTOR_INDEX,
		0
	)
	var source := fixture.get("source") \
		as CardSemanticSourceAuthorizationPort
	var source_before_invalid_validation := source.debug_snapshot()
	var service_before_invalid_validation := service.debug_snapshot()
	_expect(
		not current_observation.is_empty()
			and not bool(service.validate_observation(
				null,
				AI_ACTOR_INDEX,
				current_observation
			).get("valid", true))
			and not bool(service.validate_observation(
				OBSERVATION_CAPABILITY.new(),
				AI_ACTOR_INDEX,
				current_observation
			).get("valid", true)),
		"null and forged capabilities cannot revalidate an observation"
	)
	var source_after_invalid_validation := source.debug_snapshot()
	var service_after_invalid_validation := service.debug_snapshot()
	_expect(
		int(source_after_invalid_validation.get(
			"hand_snapshot_query_count",
			-1
		)) == int(source_before_invalid_validation.get(
			"hand_snapshot_query_count",
			-2
		))
			and int(service_after_invalid_validation.get(
				"issued_observation_fingerprint_count",
				-1
			)) == int(service_before_invalid_validation.get(
				"issued_observation_fingerprint_count",
				-2
			))
			and bool(service.validate_observation(
				observation_capability,
				AI_ACTOR_INDEX,
				current_observation
			).get("valid", false)),
		"rejected validation is a zero-query oracle and the prebound capability remains valid"
	)
	_expect(
		service.bind_actor_capabilities(actor_capabilities.duplicate()),
		"idempotent bind with the exact same actor capability map succeeds"
	)
	var forged_map := actor_capabilities.duplicate()
	forged_map[AI_ACTOR_INDEX] = AiActorHandInventoryCapability.new()
	_expect(
		not service.bind_actor_capabilities(forged_map),
		"hostile bind with a forged actor capability rejects"
	)
	var reordered_map := actor_capabilities.duplicate()
	var actor_one_capability: Variant = actor_capabilities.get(AI_ACTOR_INDEX)
	var actor_two_capability: Variant = actor_capabilities.get(
		OTHER_AI_ACTOR_INDEX
	)
	reordered_map[AI_ACTOR_INDEX] = actor_two_capability
	reordered_map[OTHER_AI_ACTOR_INDEX] = actor_one_capability
	_expect(
		not service.bind_actor_capabilities(reordered_map),
		"hostile bind with actor capability assignments reordered rejects"
	)
	var replacement_map := actor_capabilities.duplicate()
	replacement_map.erase(OTHER_AI_ACTOR_INDEX)
	_expect(
		not service.bind_actor_capabilities(replacement_map),
		"hostile bind with a replacement capability map rejects"
	)
	var debug_after_bind_attacks := service.debug_snapshot()
	_expect(
		int(debug_after_bind_attacks.get(
			"capability_bind_rejection_count",
			-1
		)) == rejection_count_before + 5
			and int(debug_after_bind_attacks.get(
				"actor_capability_count",
				-1
			)) == actor_capabilities.size(),
		"hostile rebinds are counted without replacing the sealed map"
	)
	var ai_debug := ai.debug_snapshot() if ai != null else {}
	_expect(
		ai != null
			and ai.get("_ai_card_interaction_observation_service") == service
			and int(ai_debug.get(
				"card_interaction_source_capability_count",
				-1
			)) == 0
			and not bool(ai_debug.get(
				"card_interaction_source_capabilities_held",
				true
			))
			and not bool(ai_debug.get(
				"card_interaction_observation_exposes_capabilities",
				true
			))
			and bool(ai_debug.get(
				"card_interaction_observation_consumer_capability_bound",
				false
			))
			and int(ai_debug.get(
				"card_interaction_observation_consumer_capability_count",
				-1
			)) == observation_capabilities.size(),
		"production AI holds the service but no semantic source token"
	)

	_replace_ai_slots(fixture, [
		_runtime_card(BASELINE_CARD_ID, "interaction-observation:actor-check")
	])
	var actor_one_observation := _observe(service,
		AI_ACTOR_INDEX,
		0
	)
	_expect(
		_observation_valid(service, actor_one_observation)
			and int(((actor_one_observation.get(
				"viewer_ref",
				{}
			) as Dictionary).get("actor_index", -1))) == AI_ACTOR_INDEX,
		"actor one resolves only through its service-bound capability"
	)
	var other_actor_capability := observation_capabilities.get(
		OTHER_AI_ACTOR_INDEX
	) as RefCounted
	_expect(
		service.observe_own_hand_interaction(
			_observation_capability,
			OTHER_AI_ACTOR_INDEX,
			0
		).is_empty(),
		"actor-one consumer token cannot read another AI viewer"
	)
	var other_actor_observation := service.observe_own_hand_interaction(
		other_actor_capability,
		OTHER_AI_ACTOR_INDEX,
		0
	)
	_expect(
		not other_actor_observation.is_empty()
			and not bool(service.validate_observation(
				_observation_capability,
				OTHER_AI_ACTOR_INDEX,
				other_actor_observation
			).get("valid", true)),
		"actor-one consumer token cannot validate another AI viewer"
	)
	_expect(
		bool(service.validate_observation(
			other_actor_capability,
			OTHER_AI_ACTOR_INDEX,
			other_actor_observation
		).get("valid", false))
			and int(((other_actor_observation.get(
				"viewer_ref",
				{}
			) as Dictionary).get("actor_index", -1)))
				== OTHER_AI_ACTOR_INDEX
			and str(other_actor_observation.get("instance_id", ""))
				== "interaction-observation:rival-private",
		"other AI actor authorizes only its own bound hand owner and slot"
	)
	_expect(
		_observe(service,
			0,
			0
		).is_empty(),
		"service-bound human hand still fails source-owner authorization"
	)
	_expect(
		_observe(service,
			-1,
			0
		).is_empty(),
		"invalid actor index fails closed"
	)
	_expect(
		_observe(service,
			AI_ACTOR_INDEX,
			99
		).is_empty(),
		"out-of-range slot fails closed"
	)
	_replace_ai_slots(fixture, [null])
	_expect(
		_observe(service,
			AI_ACTOR_INDEX,
			0
		).is_empty(),
		"empty slot fails closed"
	)
	_replace_ai_slots(fixture, [
		_runtime_card(BASELINE_CARD_ID, "interaction-observation:eliminated")
	])
	var world := fixture.get("world") as WorldSessionState
	var players := world.players.duplicate(true)
	var actor := (players[AI_ACTOR_INDEX] as Dictionary).duplicate(true)
	actor["eliminated"] = true
	players[AI_ACTOR_INDEX] = actor
	world.replace_players(players, true)
	_expect(
		_observe(service,
			AI_ACTOR_INDEX,
			0
		).is_empty(),
		"eliminated AI actor fails closed"
	)
	actor["eliminated"] = false
	players[AI_ACTOR_INDEX] = actor
	world.replace_players(players, true)


func _test_stale_slot_and_session_rejections(
	fixture: Dictionary,
	issued_observation: Dictionary
) -> void:
	var source := fixture.get("source") as CardSemanticSourceAuthorizationPort
	var service := fixture.get("service") as AiCardInteractionObservationService
	var capability := fixture.get("capability") \
		as AiActorHandInventoryCapability
	_replace_ai_slots(fixture, [
		_runtime_card(BASELINE_CARD_ID, "interaction-observation:stale-a")
	])
	var stale_slot_bundle := source.authorize_own_hand_card(
		capability,
		AI_ACTOR_INDEX,
		0,
		"interaction-observation-stale-slot"
	)
	_expect(
		bool(stale_slot_bundle.get("accepted", false)),
		"pre-mutation slot bundle authorizes"
	)
	_replace_ai_slots(fixture, [
		_runtime_card(BASELINE_CARD_ID, "interaction-observation:stale-b")
	])
	var stale_slot_result := source.validate_authorized_bundle(
		stale_slot_bundle
	)
	_expect(
		not bool(stale_slot_result.get("accepted", true))
			and str(stale_slot_result.get("reason_id", ""))
				== CardSemanticSourceAuthorizationPort \
					.REASON_SOURCE_ATTESTATION_STALE,
		"same card ID with a replaced runtime instance is stale"
	)
	_replace_ai_slots(fixture, [null])
	_expect(
		_observe(service,
			AI_ACTOR_INDEX,
			0
		).is_empty(),
		"slot invalidation cannot produce an observation"
	)

	_replace_ai_slots(fixture, [
		_runtime_card(BASELINE_CARD_ID, "interaction-observation:session")
	])
	var stale_session_bundle := source.authorize_own_hand_card(
		capability,
		AI_ACTOR_INDEX,
		0,
		"interaction-observation-stale-session"
	)
	var session := fixture.get("session") as GameSessionRuntimeController
	session.finish_session({})
	_expect(
		_observe(service,
			AI_ACTOR_INDEX,
			0
		).is_empty(),
		"stopped session fails closed"
	)
	_expect(
		not bool(source.validate_authorized_bundle(
			stale_session_bundle
		).get("accepted", true)),
		"old authorization is stale after session stop"
	)
	_expect(
		not bool(service.validate_observation(
			_observation_capability,
			AI_ACTOR_INDEX,
			issued_observation
		).get(
			"valid",
			true
		)),
		"old observation is stale after source/session mutation"
	)
	session.begin_session({
		"session_id": SESSION_ID,
		"scenario_id": "ai.card.interaction.observation",
		"seed": 1618033,
		"player_count": 4,
	})
	_expect(
		not bool(source.validate_authorized_bundle(
			stale_session_bundle
		).get("accepted", true))
			and not bool(service.validate_observation(
				_observation_capability,
				AI_ACTOR_INDEX,
				issued_observation
			).get("valid", true)),
		"same session ID restart cannot revive old bundles or observations"
	)


func _test_catalog_record_same_id_mutation(fixture: Dictionary) -> void:
	var service := fixture.get("service") as AiCardInteractionObservationService
	var mutated := _runtime_card(
		BASELINE_CARD_ID,
		"interaction-observation:same-id-mutation"
	)
	var public_block := (mutated.get("player", {}) as Dictionary).duplicate(
		true
	)
	public_block["short_effect"] = str(public_block.get(
		"short_effect",
		""
	)) + " forged"
	mutated["player"] = public_block
	_replace_ai_slots(fixture, [mutated])
	_expect(
		_observe(service,
			AI_ACTOR_INDEX,
			0
		).is_empty(),
		"same registered card ID with mutated catalog payload fails closed"
	)
	_replace_ai_slots(fixture, [
		_runtime_card(BASELINE_CARD_ID, "interaction-observation:restored")
	])


func _test_unsupported_mixed_and_duplicate_operations(
	fixture: Dictionary
) -> void:
	var service := fixture.get("service") as AiCardInteractionObservationService
	var discard := {
		"op_id": "discard_random",
		"count": 1,
		"target_cash_penalty": 0,
	}
	var steal := {
		"op_id": "steal_random",
		"count": 1,
		"steal_fail_cash": 60,
	}
	var lock := {
		"op_id": "lock_random",
		"duration_seconds": 10,
	}
	var unsupported := service._interaction_facts_from_effect_ops([
		{"op_id": "military_move"},
	])
	_expect(
		not bool(unsupported.get("valid", true))
			and str(unsupported.get("reason_id", ""))
				== "operation_not_supported",
		"registered but unsupported semantic operation fails closed"
	)
	var unknown := service._interaction_facts_from_effect_ops([
		{"op_id": "future_unknown_op"},
	])
	_expect(
		not bool(unknown.get("valid", true))
			and str(unknown.get("reason_id", "")) == "operation_invalid",
		"unknown semantic operation fails closed"
	)
	for invalid_case in [
		{"ops": [discard, steal], "reason": "mixed primary operations"},
		{"ops": [discard, discard], "reason": "duplicate primary operation"},
		{"ops": [lock, discard], "reason": "misordered lock operation"},
		{"ops": [discard, lock, lock], "reason": "duplicate lock operation"},
	]:
		var result := service._interaction_facts_from_effect_ops(
			invalid_case.get("ops", [])
		)
		_expect(
			not bool(result.get("valid", true)),
			"%s fails closed" % invalid_case.get("reason", "invalid ops")
		)
	_replace_ai_slots(fixture, [
		_runtime_card(
			UNSUPPORTED_CARD_ID,
			"interaction-observation:unsupported-semantic"
		)
	])
	_expect(
		_observe(service,
			AI_ACTOR_INDEX,
			0
		).is_empty()
			and str(service.debug_snapshot().get("last_reason_id", "")) \
				.ends_with("operation_not_supported"),
		"authorized projection-only counter card cannot enter this slice"
	)


func _test_debug_snapshot_privacy(
	service: AiCardInteractionObservationService
) -> void:
	var debug := service.debug_snapshot()
	var serialized := JSON.stringify(debug)
	_expect(
		SemanticWireV1.is_closed_data(debug)
			and not bool(debug.get("stores_observation_payloads", true))
			and not bool(debug.get("stores_card_records", true))
			and not bool(debug.get("owns_save_state", true))
			and not bool(debug.get("owns_rng", true)),
		"debug snapshot exposes counters only and owns no state channel"
	)
	for secret in [
		BASELINE_CARD_ID,
		SESSION_ID,
		"interaction-observation:baseline",
		"interaction-observation:stale-a",
	]:
		_expect(not serialized.contains(secret), "debug omits private value %s" % secret)


func _runtime_card(card_id: String, instance_id: String) -> Dictionary:
	var card := _catalog.card_snapshot(card_id) if _catalog != null else {}
	if card.is_empty():
		return {}
	card["runtime_instance_id"] = instance_id
	card["queued_for_resolution"] = false
	card["cooldown_left"] = 0.0
	card["lock_left"] = 0.0
	card["persistent"] = false
	return card


func _players(role_catalog: RoleCatalogRuntimeService, ai_slots: Array) -> Array:
	var result: Array = []
	for player_index in range(4):
		var role := role_catalog.definition_at(player_index)
		role["role_index"] = player_index
		var is_ai := player_index > 0
		var slots: Array = []
		if player_index == 0:
			slots = [_runtime_card(
				BASELINE_CARD_ID,
				"interaction-observation:human-private"
			)]
		elif player_index == AI_ACTOR_INDEX:
			slots = ai_slots.duplicate(true)
		elif player_index == OTHER_AI_ACTOR_INDEX:
			slots = [_runtime_card(
				BASELINE_CARD_ID,
				"interaction-observation:rival-private"
			)]
		result.append({
			"id": player_index,
			"actor_id": "player.%d" % player_index,
			"name": "Human" if not is_ai else "AI-%d" % player_index,
			"seat_type": "ai" if is_ai else "human",
			"is_ai": is_ai,
			"role_index": player_index,
			"role_card": role,
			"eliminated": false,
			"cash": 1000,
			"cash_cents": 100000,
			"action_cooldown": 0.0,
			"cities_built": 0,
			"total_city_income": 0,
			"total_card_income": 0,
			"total_role_income": 0,
			"total_card_spend": 0,
			"total_build_spend": 0,
			"total_business_spend": 0,
			"slots": slots,
			"discard": [],
			"city_guesses": {},
			"ai_profile": {"profile_index": maxi(0, player_index - 1)} \
				if is_ai else {},
			"ai_memory": {"decision_samples": [], "action_counts": {}},
		})
	return result


func _replace_ai_slots(fixture: Dictionary, slots: Array) -> void:
	var world := fixture.get("world") as WorldSessionState
	var players := world.players.duplicate(true)
	var actor := (players[AI_ACTOR_INDEX] as Dictionary).duplicate(true)
	actor["slots"] = slots.duplicate(true)
	players[AI_ACTOR_INDEX] = actor
	world.replace_players(players, true)


func _core_from_observation(observation: Dictionary) -> Dictionary:
	var core: Dictionary = {}
	for field in AiCardInteractionObservationV1.CORE_FIELDS:
		var value: Variant = observation.get(field)
		core[field] = value.duplicate(true) \
			if value is Dictionary or value is Array else value
	return core


func _observation_valid(
	service: AiCardInteractionObservationService,
	observation: Dictionary
) -> bool:
	var viewer_ref := observation.get("viewer_ref", {}) as Dictionary
	var actor_index := int(viewer_ref.get("actor_index", -1))
	var capability := _observation_capability_by_actor.get(actor_index) \
		as RefCounted
	return not observation.is_empty() \
		and capability != null \
		and bool(AiCardInteractionObservationV1.validate(observation).get(
			"valid",
			false
		)) \
		and bool(service.validate_observation(
			capability,
			actor_index,
			observation
		).get("valid", false))


func _observation_capability_replacement_map(
	capabilities: Dictionary,
	actor_index: int
) -> Dictionary:
	var replacement := capabilities.duplicate()
	replacement[actor_index] = OBSERVATION_CAPABILITY.new()
	return replacement


func _contains_key_recursive(value: Variant, key_name: String) -> bool:
	if value is Dictionary:
		var dictionary := value as Dictionary
		for key_variant in dictionary.keys():
			if str(key_variant) == key_name \
					or _contains_key_recursive(dictionary.get(key_variant), key_name):
				return true
	elif value is Array:
		for item in value as Array:
			if _contains_key_recursive(item, key_name):
				return true
	return false


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	var duration_ms := snappedf(
		float(Time.get_ticks_usec() - _started_usec) / 1000.0,
		0.001
	)
	_expect(duration_ms < 60000.0, "focused test stays below 60 seconds")
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print(
		"AI_CARD_INTERACTION_OBSERVATION_TEST_COMPLETE|status=%s|checks=%d|failures=%d|duration_ms=%.3f|details=%s"
		% [
			status,
			_checks,
			_failures.size(),
			duration_ms,
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)
