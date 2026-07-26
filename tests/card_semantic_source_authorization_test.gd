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
