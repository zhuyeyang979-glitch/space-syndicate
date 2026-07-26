extends SceneTree

const COORDINATOR_SCENE := preload(
	"res://scenes/runtime/GameRuntimeCoordinator.tscn"
)
const CATALOG_PATH := \
	"res://resources/cards/runtime/card_runtime_catalog_v06.tres"
const ACTIVE_CARD_ID := "commodity.star_dew_berry.rank_1"
const OTHER_CARD_ID := "interaction.starlink_dismantle.rank_1"
const SESSION_ID := "semantic.source.authorization.test"
const AI_ACTOR_INDEX := 1
const RESULT_KEYS := [
	"schema_version",
	"accepted",
	"reason_id",
	"authorized_envelope_ref",
	"semantic_spec",
	"instance_decision_state",
	"authorization_receipt",
	"bundle_fingerprint",
]
const DEBUG_KEYS := [
	"schema_version",
	"port_ready",
	"capability_bound",
	"capability_revision",
	"capability_bind_rejection_count",
	"authorization_attempt_count",
	"authorization_success_count",
	"rejection_count",
	"replay_count",
	"collision_count",
	"validation_attempt_count",
	"validation_success_count",
	"validation_failure_count",
	"journal_entry_count",
	"journal_limit",
	"journal_eviction_count",
	"hand_snapshot_query_count",
	"source_revalidation_count",
	"actor_state_query_proxy_count",
	"card_inventory_policy_query_lower_bound_count",
	"catalog_compile_request_count",
	"catalog_spec_authorization_count",
	"detached_bundle_copy_count",
	"journal_fingerprint",
	"journal_fingerprint_only",
	"stores_authorized_payloads",
]

var _catalog: CardRuntimeCatalogV06Resource
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
	root.add_child(coordinator)
	await process_frame

	_catalog = load(CATALOG_PATH) as CardRuntimeCatalogV06Resource
	_expect(
		_catalog != null
			and bool(_catalog.reload().get("valid", false)),
		"complete v0.6 runtime catalog loads"
	)
	var fixture := _configure_fixture(coordinator)
	_expect(not fixture.is_empty(), "real coordinator fixture configures")
	if fixture.is_empty():
		coordinator.queue_free()
		await process_frame
		_finish()
		return

	var source := fixture.get("source") as CardSemanticSourceAuthorizationPort
	var semantic_catalog := fixture.get("semantic_catalog") \
		as CardSemanticCatalogService
	var capability := fixture.get("capability") \
		as AiActorHandInventoryCapability
	var rng := fixture.get("rng") as RunRngService
	var defaults := fixture.get("default_slots", []) as Array
	_expect(source.is_ready(), "authorization port is production-ready")
	_expect(
		_is_complete_catalog_runtime_card(defaults[0] as Dictionary)
			and _is_complete_catalog_runtime_card(defaults[1] as Dictionary),
		"positive hand entries retain exact complete catalog blocks"
	)
	var rng_before := rng.capture_plan_checkpoint()

	var positive := _authorize_positive(
		fixture,
		AI_ACTOR_INDEX,
		0,
		"source-positive-current",
		"current own-hand card"
	)
	_run_positive_contract(source, semantic_catalog, positive)
	_run_authorized_envelope_schema_checks(positive)

	_authorize_rejected_without_cache_delta(
		fixture,
		"own_hand",
		null,
		AI_ACTOR_INDEX,
		0,
		"source-null-capability",
		CardSemanticSourceAuthorizationPort.REASON_CAPABILITY_REJECTED,
		"null capability"
	)
	_authorize_rejected_without_cache_delta(
		fixture,
		"own_hand",
		AiActorHandInventoryCapability.new(),
		AI_ACTOR_INDEX,
		0,
		"source-forged-capability",
		CardSemanticSourceAuthorizationPort.REASON_CAPABILITY_REJECTED,
		"forged capability"
	)
	for source_kind in ["public_rack", "public_reveal", "response_window"]:
		_authorize_rejected_without_cache_delta(
			fixture,
			source_kind,
			capability,
			AI_ACTOR_INDEX,
			0,
			"source-unsupported-%s" % source_kind,
			CardSemanticSourceAuthorizationPort.REASON_SOURCE_KIND_UNSUPPORTED,
			"unsupported %s source" % source_kind
		)

	_run_record_mutation_checks(fixture, capability)
	_run_stale_replacement_check(fixture, capability)
	_run_replay_collision_checks(fixture, capability)
	_run_actor_slot_and_instance_rejections(fixture, capability)
	_run_instance_state_mapping_checks(fixture, capability)
	_run_impure_source_rejections(fixture, capability)
	_run_resigned_bundle_rejection(fixture)
	_run_restore_and_identity_stale_checks(fixture, capability)
	_run_journal_eviction_check(fixture, capability)
	_run_surface_and_save_checks(source)
	_run_debug_privacy_check(source)
	_expect(
		rng.capture_plan_checkpoint() == rng_before,
		"authorization, validation, and rejection consume zero RNG"
	)

	coordinator.queue_free()
	await process_frame
	_finish()


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
	var rng := coordinator.run_rng_service()
	if world == null or session == null or role_catalog == null \
			or inventory == null or source == null \
			or semantic_catalog == null or rng == null:
		return {}
	inventory.configure({
		"ruleset_id": "v0.4",
		"card_inventory": {
			"ordinary_hand_limit": 5,
			"maximum_card_rank": 4,
		},
	})
	session.configure({"ruleset_id": "v0.6"}, {})
	var started := session.begin_session({
		"session_id": SESSION_ID,
		"scenario_id": "semantic.source.authorization",
		"seed": 271828,
		"player_count": 4,
	})
	var slots := [
		_runtime_card(ACTIVE_CARD_ID, "semantic:active:01"),
		_runtime_card(OTHER_CARD_ID, "semantic:other:01"),
	]
	world.restore({
		"players": _players(role_catalog, slots),
		"districts": [],
		"game_time": 23.0,
	}, true)
	var capability := coordinator.get(
		"_ai_actor_hand_inventory_capability"
	) as AiActorHandInventoryCapability
	if str(started.get("session_state", "")) \
			!= GameSessionRuntimeController.STATE_RUNNING \
			or capability == null:
		return {}
	return {
		"world": world,
		"session": session,
		"source": source,
		"semantic_catalog": semantic_catalog,
		"rng": rng,
		"capability": capability,
		"default_slots": slots.duplicate(true),
	}


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
			slots = [_runtime_card(ACTIVE_CARD_ID, "semantic:human:private")]
		elif player_index == AI_ACTOR_INDEX:
			slots = ai_slots.duplicate(true)
		elif player_index == 2:
			slots = [_runtime_card(ACTIVE_CARD_ID, "semantic:rival:private")]
		result.append({
			"id": player_index,
			"actor_id": "player.%d" % player_index,
			"name": "Human" if not is_ai else "AI-%d" % player_index,
			"seat_type": "ai" if is_ai else "human",
			"is_ai": is_ai,
			"role_index": player_index,
			"role_card": role,
			"eliminated": false,
			"cash": 700 if not is_ai else 1000,
			"cash_cents": (700 if not is_ai else 1000) * 100,
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


func _is_complete_catalog_runtime_card(card: Dictionary) -> bool:
	var machine := card.get("machine", {}) as Dictionary
	var expected := _catalog.card_snapshot(str(machine.get("card_id", "")))
	return not expected.is_empty() \
		and card.get("machine") == expected.get("machine") \
		and card.get("player") == expected.get("player") \
		and card.get("developer") == expected.get("developer") \
		and not str(card.get("runtime_instance_id", "")).is_empty()


func _run_positive_contract(
	source: CardSemanticSourceAuthorizationPort,
	semantic_catalog: CardSemanticCatalogService,
	bundle: Dictionary
) -> void:
	var before_validation := _catalog_metrics(
		semantic_catalog.validation_snapshot()
	)
	_expect(
		source.validate_authorized_bundle(bundle) == bundle,
		"current owner-issued bundle validates exactly"
	)
	_expect(
		_catalog_metrics(semantic_catalog.validation_snapshot()) \
			== before_validation,
		"current validation has zero compiler/cache delta"
	)
	var envelope := bundle.get("authorized_envelope_ref", {}) as Dictionary
	var spec := bundle.get("semantic_spec", {}) as Dictionary
	var state := bundle.get("instance_decision_state", {}) as Dictionary
	_expect(
		bundle.keys() == RESULT_KEYS
			and envelope.keys() == AuthorizedCardSemanticEnvelopeV1.FIELDS
			and bool(AuthorizedCardSemanticEnvelopeV1.validate(envelope).get(
				"valid", false
			))
			and CardInstanceDecisionStateV1.validation_error(state).is_empty()
			and bool(CardSemanticSchemaV1.validate_semantic_spec(spec).get(
				"valid", false
			)),
		"positive bundle is exact, closed, and fully sealed"
	)
	_expect(
		str((spec.get("identity", {}) as Dictionary).get("card_id", ""))
			== ACTIVE_CARD_ID
			and str(state.get("instance_id", "")) == "semantic:active:01"
			and int(state.get("source_slot", -1)) == 0,
		"bundle binds the exact current card instance and slot"
	)
	var text := JSON.stringify(bundle)
	for forbidden in [
		"\"card_record\"",
		"\"machine\"",
		"\"player\"",
		"\"developer\"",
		"semantic:other:01",
		"semantic:human:private",
		"semantic:rival:private",
		"ai_memory",
		"cash_cents",
	]:
		_expect(not text.contains(forbidden), "bundle leaks no %s" % forbidden)
	_expect(
		SemanticWireV1.is_closed_data(bundle),
		"positive bundle contains detached closed data only"
	)


func _run_authorized_envelope_schema_checks(bundle: Dictionary) -> void:
	var envelope := bundle.get("authorized_envelope_ref", {}) as Dictionary
	var unsealed := envelope.duplicate(true)
	unsealed.erase("envelope_fingerprint")
	_expect(
		AuthorizedCardSemanticEnvelopeV1.build(unsealed) == envelope,
		"authorized envelope rebuild is deterministic"
	)
	_expect(
		not bool(AuthorizedCardSemanticEnvelopeV1.validate(7).get(
			"valid", true
		)),
		"authorized envelope rejects non-dictionary input"
	)
	var scalar_viewer := unsealed.duplicate(true)
	scalar_viewer["viewer_ref"] = "player.1"
	_expect(
		AuthorizedCardSemanticEnvelopeV1.build(scalar_viewer).is_empty(),
		"authorized envelope rejects scalar viewer refs"
	)
	var unsupported_source := unsealed.duplicate(true)
	unsupported_source["source_kind"] = "public_rack"
	_expect(
		AuthorizedCardSemanticEnvelopeV1.build(unsupported_source).is_empty(),
		"authorized envelope schema remains own-hand only"
	)
	var unknown_field := unsealed.duplicate(true)
	unknown_field["hidden_owner"] = "player.2"
	_expect(
		AuthorizedCardSemanticEnvelopeV1.build(unknown_field).is_empty(),
		"authorized envelope rejects unknown value channels"
	)


func _run_record_mutation_checks(
	fixture: Dictionary,
	capability: AiActorHandInventoryCapability
) -> void:
	var defaults := fixture.get("default_slots", []) as Array
	for block_id in ["machine", "player", "developer"]:
		var card := _runtime_card(
			ACTIVE_CARD_ID,
			"semantic:mutated:%s" % block_id
		)
		var block := card.get(block_id, {}) as Dictionary
		match block_id:
			"machine":
				block["purchase_cash"] = int(block.get("purchase_cash", 0)) + 1
			"player":
				block["short_effect"] = str(block.get("short_effect", "")) + " changed"
			"developer":
				block["implementation_status"] = "forged_runtime_ready"
		_replace_ai_slots(fixture, [card, defaults[1]])
		_authorize_rejected_without_cache_delta(
			fixture,
			"own_hand",
			capability,
			AI_ACTOR_INDEX,
			0,
			"source-record-mutation-%s" % block_id,
			CardSemanticSourceAuthorizationPort.REASON_SEMANTIC_COMPILE_FAILED,
			"exact %s record mutation" % block_id
		)
	_replace_ai_slots(fixture, defaults)


func _run_stale_replacement_check(
	fixture: Dictionary,
	capability: AiActorHandInventoryCapability
) -> void:
	var defaults := fixture.get("default_slots", []) as Array
	_replace_ai_slots(fixture, defaults)
	var bundle := _authorize_positive(
		fixture,
		AI_ACTOR_INDEX,
		0,
		"source-stale-replacement",
		"pre-replacement source"
	)
	var replaced := defaults.duplicate(true)
	replaced[0] = _runtime_card(OTHER_CARD_ID, "semantic:replacement:01")
	_replace_ai_slots(fixture, replaced)
	_validate_rejected_without_cache_delta(
		fixture,
		bundle,
		CardSemanticSourceAuthorizationPort.REASON_SOURCE_ATTESTATION_STALE,
		"stale slot replacement"
	)
	_replace_ai_slots(fixture, defaults)


func _run_replay_collision_checks(
	fixture: Dictionary,
	capability: AiActorHandInventoryCapability
) -> void:
	var defaults := fixture.get("default_slots", []) as Array
	_replace_ai_slots(fixture, defaults)
	var first := _authorize_positive(
		fixture,
		AI_ACTOR_INDEX,
		0,
		"source-idempotent-request",
		"first idempotent request"
	)
	var semantic_catalog := fixture.get("semantic_catalog") \
		as CardSemanticCatalogService
	var before_replay := _catalog_metrics(semantic_catalog.validation_snapshot())
	var second := (fixture.get("source") \
		as CardSemanticSourceAuthorizationPort).authorize_own_hand_card(
		capability,
		AI_ACTOR_INDEX,
		0,
		"source-idempotent-request"
	)
	var after_replay := _catalog_metrics(semantic_catalog.validation_snapshot())
	_expect(first == second and _accepted_bundle(second), "same request replays exactly")
	_expect(
		int(after_replay.get("compile_count", -1))
			== int(before_replay.get("compile_count", -2))
			and int(after_replay.get("cache_entry_count", -1))
				== int(before_replay.get("cache_entry_count", -2))
			and int(after_replay.get("cache_hit_count", -1))
				== int(before_replay.get("cache_hit_count", -1)) + 1,
		"replay is a cache hit with compile delta zero"
	)
	_authorize_rejected_without_cache_delta(
		fixture,
		"own_hand",
		capability,
		AI_ACTOR_INDEX,
		1,
		"source-idempotent-request",
		CardSemanticSourceAuthorizationPort.REASON_REQUEST_ID_COLLISION,
		"same request with a different source binding"
	)
	var debug := (fixture.get("source") \
		as CardSemanticSourceAuthorizationPort).debug_snapshot()
	_expect(
		int(debug.get("replay_count", 0)) >= 1
			and int(debug.get("collision_count", 0)) >= 1,
		"replay and collision are aggregate-counted"
	)


func _run_actor_slot_and_instance_rejections(
	fixture: Dictionary,
	capability: AiActorHandInventoryCapability
) -> void:
	var source := fixture.get("source") as CardSemanticSourceAuthorizationPort
	var semantic_catalog := fixture.get("semantic_catalog") \
		as CardSemanticCatalogService
	var defaults := fixture.get("default_slots", []) as Array
	_replace_ai_slots(fixture, defaults)
	var cache_before_rebind := _catalog_metrics(
		semantic_catalog.validation_snapshot()
	)
	_expect(
		not source.bind_ai_capability(AiActorHandInventoryCapability.new()),
		"hostile capability rebind is rejected"
	)
	_expect(
		cache_before_rebind == _catalog_metrics(
			semantic_catalog.validation_snapshot()
		),
		"hostile capability rebind has zero compiler/cache delta"
	)
	var debug_before_human := source.debug_snapshot()
	_authorize_rejected_without_cache_delta(
		fixture, "own_hand", capability, 0, 0,
		"source-human-actor", CardSemanticSourceAuthorizationPort.REASON_SOURCE_ATTESTATION_FAILED,
		"human actor"
	)
	var debug_after_human := source.debug_snapshot()
	_expect(
		int(debug_after_human.get("hand_snapshot_query_count", -1))
			== int(debug_before_human.get("hand_snapshot_query_count", -2)) + 1
			and int(debug_after_human.get("source_revalidation_count", -1))
				== int(debug_before_human.get("source_revalidation_count", -2))
			and int(debug_after_human.get(
				"actor_state_query_proxy_count", -1
			)) == int(debug_before_human.get(
				"actor_state_query_proxy_count", -2
			)) + 1
			and int(debug_after_human.get(
				"card_inventory_policy_query_lower_bound_count", -1
			)) == int(debug_before_human.get(
				"card_inventory_policy_query_lower_bound_count", -2
			)),
		"rejected actor records one query attempt without phantom revalidation or inventory work"
	)
	_authorize_rejected_without_cache_delta(
		fixture, "own_hand", capability, AI_ACTOR_INDEX, 99,
		"source-slot-out-of-range", CardSemanticSourceAuthorizationPort.REASON_SOURCE_ATTESTATION_FAILED,
		"out-of-range slot"
	)
	_replace_ai_slots(fixture, [defaults[0], null])
	_authorize_rejected_without_cache_delta(
		fixture, "own_hand", capability, AI_ACTOR_INDEX, 1,
		"source-empty-slot", CardSemanticSourceAuthorizationPort.REASON_SOURCE_ATTESTATION_FAILED,
		"empty slot"
	)
	var empty_id_card := _runtime_card(ACTIVE_CARD_ID, "")
	_replace_ai_slots(fixture, [empty_id_card, defaults[1]])
	_authorize_rejected_without_cache_delta(
		fixture, "own_hand", capability, AI_ACTOR_INDEX, 0,
		"source-empty-instance", CardSemanticSourceAuthorizationPort.REASON_RUNTIME_INSTANCE_ID_INVALID,
		"empty runtime instance ID"
	)
	var control_id_card := _runtime_card(ACTIVE_CARD_ID, "semantic:bad\nid")
	_replace_ai_slots(fixture, [control_id_card, defaults[1]])
	_authorize_rejected_without_cache_delta(
		fixture, "own_hand", capability, AI_ACTOR_INDEX, 0,
		"source-control-instance", CardSemanticSourceAuthorizationPort.REASON_RUNTIME_INSTANCE_ID_INVALID,
		"control-character runtime instance ID"
	)
	_replace_ai_slots(fixture, defaults)
	var world := fixture.get("world") as WorldSessionState
	var eliminated_actor := (world.players[AI_ACTOR_INDEX] as Dictionary).duplicate(true)
	eliminated_actor["eliminated"] = true
	world.players[AI_ACTOR_INDEX] = eliminated_actor
	_authorize_rejected_without_cache_delta(
		fixture, "own_hand", capability, AI_ACTOR_INDEX, 0,
		"source-eliminated-actor", CardSemanticSourceAuthorizationPort.REASON_SOURCE_ATTESTATION_FAILED,
		"eliminated AI actor"
	)
	eliminated_actor["eliminated"] = false
	world.players[AI_ACTOR_INDEX] = eliminated_actor
	var session := fixture.get("session") as GameSessionRuntimeController
	session.finish_session({})
	_authorize_rejected_without_cache_delta(
		fixture, "own_hand", capability, AI_ACTOR_INDEX, 0,
		"source-stopped-session", CardSemanticSourceAuthorizationPort.REASON_SOURCE_ATTESTATION_FAILED,
		"stopped session"
	)
	session.begin_session({
		"session_id": SESSION_ID,
		"scenario_id": "semantic.source.authorization",
		"seed": 271828,
		"player_count": 4,
	})
	_replace_ai_slots(fixture, defaults)


func _run_instance_state_mapping_checks(
	fixture: Dictionary,
	capability: AiActorHandInventoryCapability
) -> void:
	var defaults := fixture.get("default_slots", []) as Array
	var queued := _runtime_card(ACTIVE_CARD_ID, "semantic:queued:01")
	queued["queued_for_resolution"] = true
	_replace_ai_slots(fixture, [queued, defaults[1]])
	var queued_bundle := _authorize_positive(
		fixture, AI_ACTOR_INDEX, 0, "source-queued-state", "queued source state"
	)
	var queued_state := queued_bundle.get("instance_decision_state", {}) as Dictionary
	_expect(
		bool(queued_state.get("queued", false))
			and not CardInstanceDecisionStateV1.is_available(queued_state),
		"queued source state remains authorized but unavailable"
	)
	var locked := _runtime_card(ACTIVE_CARD_ID, "semantic:locked:01")
	locked["lock_left"] = 0.25
	_replace_ai_slots(fixture, [locked, defaults[1]])
	var locked_bundle := _authorize_positive(
		fixture, AI_ACTOR_INDEX, 0, "source-locked-state", "locked source state"
	)
	var locked_state := locked_bundle.get("instance_decision_state", {}) as Dictionary
	_expect(
		bool(locked_state.get("locked", false))
			and not CardInstanceDecisionStateV1.is_available(locked_state),
		"positive lock duration maps to locked without becoming legality"
	)
	var cooling := _runtime_card(ACTIVE_CARD_ID, "semantic:cooling:01")
	cooling["cooldown_left"] = 0.0000001
	_replace_ai_slots(fixture, [cooling, defaults[1]])
	var cooling_bundle := _authorize_positive(
		fixture, AI_ACTOR_INDEX, 0, "source-cooling-state", "cooling source state"
	)
	var cooling_state := cooling_bundle.get("instance_decision_state", {}) as Dictionary
	_expect(
		int(cooling_state.get("cooldown_remaining_microseconds", 0)) == 1
			and not CardInstanceDecisionStateV1.is_available(cooling_state),
		"positive fractional cooldown rounds up to one microsecond"
	)
	_replace_ai_slots(fixture, defaults)


func _run_impure_source_rejections(
	fixture: Dictionary,
	capability: AiActorHandInventoryCapability
) -> void:
	var defaults := fixture.get("default_slots", []) as Array
	for field in ["hidden_owner", "rival_hand", "ai_value", "save_payload"]:
		var hidden := _runtime_card(ACTIVE_CARD_ID, "semantic:hidden:%s" % field)
		hidden[field] = "private-value"
		_replace_ai_slots(fixture, [hidden, defaults[1]])
		_authorize_rejected_without_cache_delta(
			fixture, "own_hand", capability, AI_ACTOR_INDEX, 0,
			"source-hidden-%s" % field,
			CardSemanticSourceAuthorizationPort.REASON_SOURCE_ATTESTATION_FAILED,
			"hidden value channel %s" % field
		)
	var node_value := Node.new()
	var impure_values: Array = [node_value, Resource.new(), Callable(self, "_finish")]
	for index in range(impure_values.size()):
		var impure := _runtime_card(ACTIVE_CARD_ID, "semantic:impure:%d" % index)
		impure["impure_value"] = impure_values[index]
		_replace_ai_slots(fixture, [impure, defaults[1]])
		_authorize_rejected_without_cache_delta(
			fixture, "own_hand", capability, AI_ACTOR_INDEX, 0,
			"source-impure-%d" % index,
			CardSemanticSourceAuthorizationPort.REASON_SOURCE_ATTESTATION_FAILED,
			"impure runtime value %d" % index
		)
	node_value.free()
	for timer_value in [NAN, INF, -1.0]:
		var malformed_timer := _runtime_card(
			ACTIVE_CARD_ID,
			"semantic:timer:%s" % str(timer_value)
		)
		malformed_timer["cooldown_left"] = timer_value
		_replace_ai_slots(fixture, [malformed_timer, defaults[1]])
		_authorize_rejected_without_cache_delta(
			fixture, "own_hand", capability, AI_ACTOR_INDEX, 0,
			"source-timer-%s" % str(timer_value),
			CardSemanticSourceAuthorizationPort.REASON_SOURCE_ATTESTATION_FAILED,
			"non-finite or negative timer %s" % str(timer_value)
		)
	_replace_ai_slots(fixture, defaults)


func _run_resigned_bundle_rejection(fixture: Dictionary) -> void:
	var defaults := fixture.get("default_slots", []) as Array
	_replace_ai_slots(fixture, defaults)
	var bundle := _authorize_positive(
		fixture, AI_ACTOR_INDEX, 0, "source-resigned-bundle", "pre-tamper bundle"
	)
	var resigned := bundle.duplicate(true)
	var spec := resigned.get("semantic_spec", {}) as Dictionary
	spec["runtime_readiness_id"] = "projection_only"
	spec["semantic_fingerprint"] = CardSemanticSchemaV1.fingerprint(
		spec, "semantic_fingerprint"
	)
	var envelope := resigned.get("authorized_envelope_ref", {}) as Dictionary
	envelope["semantic_fingerprint"] = spec.get("semantic_fingerprint")
	envelope["envelope_fingerprint"] = SemanticWireV1.fingerprint(
		envelope, "envelope_fingerprint"
	)
	var receipt := resigned.get("authorization_receipt", {}) as Dictionary
	receipt["semantic_fingerprint"] = spec.get("semantic_fingerprint")
	receipt["receipt_fingerprint"] = SemanticWireV1.fingerprint(
		receipt, "receipt_fingerprint"
	)
	resigned["bundle_fingerprint"] = CardSemanticSchemaV1.fingerprint(
		resigned, "bundle_fingerprint"
	)
	_validate_rejected_without_cache_delta(
		fixture,
		resigned,
		CardSemanticSourceAuthorizationPort.REASON_JOURNAL_BUNDLE_MISMATCH,
		"re-signed caller-controlled readiness"
	)
	var injected := bundle.duplicate(true)
	injected["hidden_owner"] = "player.2"
	injected["bundle_fingerprint"] = CardSemanticSchemaV1.fingerprint(
		injected, "bundle_fingerprint"
	)
	_validate_rejected_without_cache_delta(
		fixture,
		injected,
		CardSemanticSourceAuthorizationPort.REASON_BUNDLE_INVALID,
		"extra hidden owner bundle channel"
	)


func _run_restore_and_identity_stale_checks(
	fixture: Dictionary,
	capability: AiActorHandInventoryCapability
) -> void:
	var defaults := fixture.get("default_slots", []) as Array
	_replace_ai_slots(fixture, defaults)
	var instance_bundle := _authorize_positive(
		fixture, AI_ACTOR_INDEX, 0, "source-same-card-instance", "old instance"
	)
	_replace_ai_slots(fixture, [
		_runtime_card(ACTIVE_CARD_ID, "semantic:active:replacement"),
		defaults[1],
	])
	_validate_rejected_without_cache_delta(
		fixture,
		instance_bundle,
		CardSemanticSourceAuthorizationPort.REASON_SOURCE_ATTESTATION_STALE,
		"same card ID with a replaced runtime instance"
	)
	_replace_ai_slots(fixture, defaults)
	var moved_bundle := _authorize_positive(
		fixture, AI_ACTOR_INDEX, 0, "source-moved-slot", "pre-move source"
	)
	_replace_ai_slots(fixture, [null, defaults[0], defaults[1]])
	_validate_rejected_without_cache_delta(
		fixture,
		moved_bundle,
		CardSemanticSourceAuthorizationPort.REASON_SOURCE_ATTESTATION_STALE,
		"source card moved to another slot"
	)
	_replace_ai_slots(fixture, defaults)
	var restore_bundle := _authorize_positive(
		fixture, AI_ACTOR_INDEX, 0, "source-before-restore", "pre-restore source"
	)
	var world := fixture.get("world") as WorldSessionState
	var checkpoint := world.to_save_data()
	world.restore(checkpoint, true)
	_validate_rejected_without_cache_delta(
		fixture,
		restore_bundle,
		CardSemanticSourceAuthorizationPort.REASON_SOURCE_ATTESTATION_STALE,
		"old bundle after session restore"
	)
	_replace_ai_slots(fixture, defaults)


func _run_journal_eviction_check(
	fixture: Dictionary,
	capability: AiActorHandInventoryCapability
) -> void:
	var defaults := fixture.get("default_slots", []) as Array
	_replace_ai_slots(fixture, defaults)
	var source := fixture.get("source") as CardSemanticSourceAuthorizationPort
	var semantic_catalog := fixture.get("semantic_catalog") \
		as CardSemanticCatalogService
	var debug_before := source.debug_snapshot()
	var cache_before := _catalog_metrics(semantic_catalog.validation_snapshot())
	var first_bundle: Dictionary = {}
	var newest_bundle: Dictionary = {}
	var all_authorized := true
	for index in range(CardSemanticSourceAuthorizationPort.JOURNAL_LIMIT + 1):
		var bundle := source.authorize_own_hand_card(
			capability,
			AI_ACTOR_INDEX,
			0,
			"source-journal-boundary-%03d" % index
		)
		if not _accepted_bundle(bundle):
			all_authorized = false
		if index == 0:
			first_bundle = bundle
		newest_bundle = bundle
	var debug_after := source.debug_snapshot()
	var cache_after := _catalog_metrics(semantic_catalog.validation_snapshot())
	var expected_evictions := maxi(
		0,
		int(debug_before.get("journal_entry_count", 0))
			+ CardSemanticSourceAuthorizationPort.JOURNAL_LIMIT + 1
			- CardSemanticSourceAuthorizationPort.JOURNAL_LIMIT
	)
	_expect(all_authorized, "journal boundary requests all authorize")
	_expect(
		int(debug_after.get("journal_entry_count", -1))
			== CardSemanticSourceAuthorizationPort.JOURNAL_LIMIT
			and int(debug_after.get("journal_eviction_count", -1))
				== int(debug_before.get("journal_eviction_count", -2))
					+ expected_evictions,
		"fingerprint-only authorization journal stays at its closed limit"
	)
	_expect(
		int(cache_after.get("compile_count", -1))
			== int(cache_before.get("compile_count", -2))
			and int(cache_after.get("cache_entry_count", -1))
				== int(cache_before.get("cache_entry_count", -2))
			and int(cache_after.get("cache_hit_count", -1))
				== int(cache_before.get("cache_hit_count", -2))
					+ CardSemanticSourceAuthorizationPort.JOURNAL_LIMIT + 1,
		"journal pressure uses catalog cache hits with compile delta zero"
	)
	_validate_rejected_without_cache_delta(
		fixture,
		first_bundle,
		CardSemanticSourceAuthorizationPort.REASON_REQUEST_NOT_JOURNALED,
		"evicted oldest journal request"
	)
	_expect(
		source.validate_authorized_bundle(newest_bundle) == newest_bundle,
		"newest journal request remains current and idempotent"
	)


func _run_surface_and_save_checks(
	source: CardSemanticSourceAuthorizationPort
) -> void:
	for forbidden_method in [
		"authorize_card_id",
		"authorize_instance_id",
		"semantic_for_card_id",
		"card_ids",
		"catalog_snapshot",
		"all_semantics",
		"request_journal_snapshot",
		"bundle_cache_snapshot",
	]:
		_expect(
			not source.has_method(forbidden_method),
			"source exposes no arbitrary %s method" % forbidden_method
		)
	var registry := FileAccess.get_file_as_string(
		"res://scenes/runtime/V06SaveOwnerRegistry.tscn"
	)
	_expect(
		registry.count("section_id =") == 19
			and registry.count("section_id = \"semantic") == 0,
		"Save registry remains 19 owners with zero semantic sections"
	)
	var source_text := FileAccess.get_file_as_string(
		"res://scripts/runtime/card_semantic_source_authorization_port.gd"
	)
	_expect(
		not source_text.contains("card_ids(")
			and not source_text.contains("catalog_snapshot(")
			and not source_text.contains("to_save_data")
			and not source_text.contains("apply_save_data")
			and not source_text.contains("RunRngService"),
		"source has no enumeration, Save, or RNG backchannel"
	)


func _run_debug_privacy_check(
	source: CardSemanticSourceAuthorizationPort
) -> void:
	var debug := source.debug_snapshot()
	var text := JSON.stringify(debug)
	_expect(debug.keys() == DEBUG_KEYS, "debug schema is exact")
	_expect(
		SemanticWireV1.is_closed_data(debug)
			and bool(debug.get("journal_fingerprint_only", false))
			and not bool(debug.get("stores_authorized_payloads", true))
			and SemanticWireV1.is_fingerprint(debug.get("journal_fingerprint")),
		"debug stores aggregate counts and a journal fingerprint only"
	)
	for secret in [
		ACTIVE_CARD_ID,
		OTHER_CARD_ID,
		SESSION_ID,
		"semantic:active:01",
		"semantic:human:private",
		"semantic:rival:private",
		"source-idempotent-request",
	]:
		_expect(not text.contains(secret), "debug omits private value %s" % secret)


func _authorize_positive(
	fixture: Dictionary,
	actor_index: int,
	slot_index: int,
	request_id: String,
	label: String
) -> Dictionary:
	var source := fixture.get("source") as CardSemanticSourceAuthorizationPort
	var semantic_catalog := fixture.get("semantic_catalog") \
		as CardSemanticCatalogService
	var capability := fixture.get("capability") \
		as AiActorHandInventoryCapability
	var before := _catalog_metrics(semantic_catalog.validation_snapshot())
	var result := source.authorize_own_hand_card(
		capability,
		actor_index,
		slot_index,
		request_id
	)
	var after := _catalog_metrics(semantic_catalog.validation_snapshot())
	_expect(_accepted_bundle(result), "%s authorizes" % label)
	_expect(
		int(after.get("compile_count", -1))
			== int(before.get("compile_count", -2))
			and int(after.get("cache_entry_count", -1))
				== int(before.get("cache_entry_count", -2))
			and int(after.get("cache_hit_count", -1))
				== int(before.get("cache_hit_count", -1)) + 1,
		"%s is a cache hit with compile delta zero" % label
	)
	return result


func _authorize_rejected_without_cache_delta(
	fixture: Dictionary,
	source_kind: String,
	capability: AiActorHandInventoryCapability,
	actor_index: int,
	slot_index: int,
	request_id: String,
	expected_reason: String,
	label: String
) -> Dictionary:
	var source := fixture.get("source") as CardSemanticSourceAuthorizationPort
	var semantic_catalog := fixture.get("semantic_catalog") \
		as CardSemanticCatalogService
	var before := _catalog_metrics(semantic_catalog.validation_snapshot())
	var result := source.authorize_source(
		source_kind,
		capability,
		actor_index,
		slot_index,
		request_id
	)
	var after := _catalog_metrics(semantic_catalog.validation_snapshot())
	_expect(
		_closed_failure(result)
			and str(result.get("reason_id", "")) == expected_reason,
		"%s rejects closed" % label
	)
	_expect(before == after, "%s has zero compiler/cache delta" % label)
	return result


func _validate_rejected_without_cache_delta(
	fixture: Dictionary,
	bundle: Dictionary,
	expected_reason: String,
	label: String
) -> Dictionary:
	var source := fixture.get("source") as CardSemanticSourceAuthorizationPort
	var semantic_catalog := fixture.get("semantic_catalog") \
		as CardSemanticCatalogService
	var before := _catalog_metrics(semantic_catalog.validation_snapshot())
	var result := source.validate_authorized_bundle(bundle)
	var after := _catalog_metrics(semantic_catalog.validation_snapshot())
	_expect(
		_closed_failure(result)
			and str(result.get("reason_id", "")) == expected_reason,
		"%s validation rejects closed" % label
	)
	_expect(before == after, "%s validation has zero compiler/cache delta" % label)
	return result


func _replace_ai_slots(fixture: Dictionary, slots: Array) -> void:
	var world := fixture.get("world") as WorldSessionState
	var actor := (world.players[AI_ACTOR_INDEX] as Dictionary).duplicate(true)
	actor["slots"] = slots.duplicate(true)
	world.players[AI_ACTOR_INDEX] = actor


func _catalog_metrics(snapshot: Dictionary) -> Dictionary:
	return {
		"cache_entry_count": int(snapshot.get("cache_entry_count", -1)),
		"compile_count": int(snapshot.get("compile_count", -1)),
		"cache_hit_count": int(snapshot.get("cache_hit_count", -1)),
		"compile_failure_count": int(snapshot.get(
			"compile_failure_count", -1
		)),
	}


func _accepted_bundle(bundle: Dictionary) -> bool:
	return bundle.keys() == RESULT_KEYS \
		and bundle.get("schema_version") == 1 \
		and bundle.get("accepted") == true \
		and str(bundle.get("reason_id", "")) == "authorized" \
		and not (bundle.get("authorized_envelope_ref", {}) \
			as Dictionary).is_empty() \
		and not (bundle.get("semantic_spec", {}) as Dictionary).is_empty() \
		and not (bundle.get("instance_decision_state", {}) \
			as Dictionary).is_empty() \
		and not (bundle.get("authorization_receipt", {}) \
			as Dictionary).is_empty() \
		and SemanticWireV1.is_fingerprint(bundle.get("bundle_fingerprint"))


func _closed_failure(result: Dictionary) -> bool:
	return result.keys() == RESULT_KEYS \
		and result.get("schema_version") == 1 \
		and result.get("accepted") == false \
		and not str(result.get("reason_id", "")).is_empty() \
		and (result.get("authorized_envelope_ref", {}) \
			as Dictionary).is_empty() \
		and (result.get("semantic_spec", {}) as Dictionary).is_empty() \
		and (result.get("instance_decision_state", {}) \
			as Dictionary).is_empty() \
		and (result.get("authorization_receipt", {}) \
			as Dictionary).is_empty() \
		and str(result.get("bundle_fingerprint", "")).is_empty()


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
		"CARD_SEMANTIC_SOURCE_AUTHORIZATION_TEST_COMPLETE|status=%s|checks=%d|failures=%d|duration_ms=%.3f|details=%s"
		% [
			status,
			_checks,
			_failures.size(),
			duration_ms,
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)
