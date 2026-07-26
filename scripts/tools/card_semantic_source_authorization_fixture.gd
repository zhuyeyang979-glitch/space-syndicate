extends RefCounted
class_name CardSemanticSourceAuthorizationFixture

const CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v06.tres"
const ACTIVE_CARD_ID := "commodity.star_dew_berry.rank_1"
const PROJECTION_ONLY_CARD_ID := "interaction.starlink_dismantle.rank_1"
const AI_ACTOR_INDEX := 1
const ACTIVE_SLOT_INDEX := 0
const PROJECTION_ONLY_SLOT_INDEX := 1


static func configure_coordinator(
	coordinator: GameRuntimeCoordinator,
	session_id := "semantic.source.authorization.fixture"
) -> Dictionary:
	if coordinator == null:
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
	var catalog := coordinator.get_node_or_null(
		"CardSemanticCatalogService"
	) as CardSemanticCatalogService
	var projection := coordinator.get_node_or_null(
		"AiCardSemanticProjectionService"
	) as AiCardSemanticProjectionService
	var rng := coordinator.run_rng_service()
	if (
		world == null
		or session == null
		or role_catalog == null
		or inventory == null
		or source == null
		or catalog == null
		or projection == null
		or rng == null
	):
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
		"session_id": session_id,
		"scenario_id": "semantic.source.authorization",
		"seed": 271828,
		"player_count": 4,
	})
	var ai_slots := [
		runtime_card(ACTIVE_CARD_ID, "fixture:semantic:active:01"),
		runtime_card(
			PROJECTION_ONLY_CARD_ID,
			"fixture:semantic:projection-only:01"
		),
	]
	world.restore({
		"players": _players(role_catalog, ai_slots),
		"districts": [],
		"game_time": 23.0,
	}, true)
	var actor_capabilities_variant: Variant = coordinator.get(
		"_card_semantic_source_capability_by_actor"
	)
	var actor_capabilities := actor_capabilities_variant as Dictionary \
		if actor_capabilities_variant is Dictionary else {}
	var capability := actor_capabilities.get(AI_ACTOR_INDEX) \
		as AiActorHandInventoryCapability
	if (
		str(started.get("session_state", ""))
			!= GameSessionRuntimeController.STATE_RUNNING
		or capability == null
		or not source.is_ready()
	):
		return {}
	return {
		"world": world,
		"source": source,
		"catalog": catalog,
		"projection": projection,
		"rng": rng,
		"capability": capability,
	}


static func runtime_card(card_id: String, runtime_instance_id: String) -> Dictionary:
	var catalog := load(CATALOG_PATH) as CardRuntimeCatalogV06Resource
	if catalog == null or not bool(catalog.reload().get("valid", false)):
		return {}
	var card := catalog.card_snapshot(card_id)
	if card.is_empty():
		return {}
	card["runtime_instance_id"] = runtime_instance_id
	card["queued_for_resolution"] = false
	card["cooldown_left"] = 0.0
	card["lock_left"] = 0.0
	card["persistent"] = false
	return card


static func clipped_world_projection(
	bundle: Dictionary,
	fixture_id: String,
	world_revision := 71
) -> Dictionary:
	var spec := bundle.get("semantic_spec", {}) as Dictionary
	var instance := bundle.get("instance_decision_state", {}) as Dictionary
	var viewer := instance.get("viewer_ref", {}) as Dictionary
	var target_id := str(
		(spec.get("target", {}) as Dictionary).get("target_id", "")
	)
	var target := {
		"schema_version": 1,
		"target_id": target_id,
		"target_identity": {
			"schema_version": 1,
			"target_id": target_id,
			"stable_id": "target.semantic.%s" % fixture_id,
		},
		"status_id": "legal",
		"source_revision": instance.get("source_revision"),
		"instance_revision": instance.get("instance_revision"),
		"world_revision": world_revision,
		"uncertainty": 0,
		"counter_risk": 0,
		"outcome_adjustments": AiOutcomeVectorV1.zero(),
		"explanation_tokens": ["semantic.fact.source_authorized"],
		"legality_fingerprint": "",
	}
	target["legality_fingerprint"] = CardSemanticSchemaV1.fingerprint(
		target,
		"legality_fingerprint"
	)
	var world := {
		"schema_version": 1,
		"projection_id": "world_projection.semantic.%s" % fixture_id,
		"viewer_actor_id": str(viewer.get("actor_ref_id", "")),
		"visibility_scope_id": str(instance.get("visibility_scope_id", "")),
		"source_kind": str(instance.get("source_kind", "")),
		"source_revision": instance.get("source_revision"),
		"semantic_fingerprint": str(spec.get("semantic_fingerprint", "")),
		"card_id": str(instance.get("card_id", "")),
		"instance_id": str(instance.get("instance_id", "")),
		"source_slot": int(instance.get("source_slot", -1)),
		"instance_revision": instance.get("instance_revision"),
		"world_revision": world_revision,
		"legal_targets": [target],
		"projection_fingerprint": "",
	}
	world["projection_fingerprint"] = CardSemanticSchemaV1.fingerprint(
		world,
		"projection_fingerprint"
	)
	return world


static func catalog_metrics(snapshot: Dictionary) -> Dictionary:
	return {
		"cache_entry_count": int(snapshot.get("cache_entry_count", -1)),
		"compile_count": int(snapshot.get("compile_count", -1)),
		"cache_hit_count": int(snapshot.get("cache_hit_count", -1)),
		"compile_failure_count": int(
			snapshot.get("compile_failure_count", -1)
		),
	}


static func _players(role_catalog: RoleCatalogRuntimeService, ai_slots: Array) -> Array:
	var result: Array = []
	for player_index in range(4):
		var role := role_catalog.definition_at(player_index)
		role["role_index"] = player_index
		var is_ai := player_index > 0
		var slots: Array = []
		if player_index == 0:
			slots = [runtime_card(
				ACTIVE_CARD_ID,
				"fixture:semantic:human-private:01"
			)]
		elif player_index == AI_ACTOR_INDEX:
			slots = ai_slots.duplicate(true)
		elif player_index == 2:
			slots = [runtime_card(
				ACTIVE_CARD_ID,
				"fixture:semantic:rival-private:01"
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
