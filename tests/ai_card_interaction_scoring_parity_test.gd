extends SceneTree

const COORDINATOR_SCENE := preload(
	"res://scenes/runtime/GameRuntimeCoordinator.tscn"
)
const SOURCE_FIXTURE := preload(
	"res://scripts/tools/card_semantic_source_authorization_fixture.gd"
)
const OBSERVATION_SCHEMA := preload(
	"res://scripts/semantic/ai_card_interaction_observation_v1.gd"
)
const CARD_PLAY_REQUIREMENT_POLICY := preload(
	"res://scripts/cards/card_play_requirement_policy.gd"
)

const CATALOG_PATH := \
	"res://resources/cards/runtime/card_runtime_catalog_v06.tres"
const MAIN_SOURCE_PATH := "res://scripts/main.gd"
const MAIN_BASELINE_SHA256 := \
	"0c76d2c58c98f8c70f6f893a2872fc937bd621c68ec94a07b552be2bc763326c"
const ACTOR_INDEX := 1
const HAND_LIMIT := 8
const SAMPLE_ITERATIONS := 100
const REPEAT_ITERATIONS := 400
const REPEAT_TIME_LIMIT_MS := 30000.0
const CANDIDATE_PERFORMANCE_ITERATIONS := 20
const CANDIDATE_PERFORMANCE_MAX_RATIO := 10.0
const CANDIDATE_PERFORMANCE_TIME_LIMIT_MS := 15000.0
const PRODUCTION_CANDIDATE_RNG_SEED := 56572
const PRODUCTION_CANDIDATE_CARD_IDS := [
	"interaction.starlink_dismantle.rank_1",
	"interaction.shadow_warehouse_traction.rank_4",
]
const GENUINE_V04_CARD_IDS := [
	"星链拆解1",
	"影仓牵引4",
]
const CARRIER_RAW_V06 := "raw_v06"
const CARRIER_PRODUCTION_ADAPTER := "production_adapter_v06"
const CARRIER_LEGACY_FLAT := "owner_attested_legacy_flat"
const CARRIER_GENUINE_V04_OWNER := "owner_attested_genuine_v04_owner_restore"
const PRODUCTION_CARRIER_IDS := [
	CARRIER_RAW_V06,
	CARRIER_PRODUCTION_ADAPTER,
	CARRIER_LEGACY_FLAT,
	CARRIER_GENUINE_V04_OWNER,
]
const FROZEN_PRODUCTION_CANDIDATE_GOLDENS := {
	"raw_v06": {
		"candidate_fingerprints": [
			"b134ee942b781c9a32b6f68ce48d30a62dbeb3d2335e75ec3a395b76dd5a78ad",
			"3b827e5ee5d1a8e3c2308c2fc3e43870572c6db41d09b4b1a15693183d82105a",
		],
		"score_vector": [
			{
				"slot_index": 0,
				"score": 103,
				"direct_interaction_score": 0,
				"generic_effect_bonus": 0,
				"phase_bonus": 0,
				"profile_signature_bonus": 0,
			},
			{
				"slot_index": 1,
				"score": 103,
				"direct_interaction_score": 0,
				"generic_effect_bonus": 0,
				"phase_bonus": 0,
				"profile_signature_bonus": 0,
			},
		],
		"ranked_slots": [0, 1],
		"selected_slot": 0,
		"observation_attempt_delta": 0,
		"normal_terminal_checkpoint": {
			"schema_version": 1,
			"rng_state": 4331395523003180704,
			"draw_count": 1,
		},
	},
	"production_adapter_v06": {
		"candidate_fingerprints": [
			"a1f9f00ec662e8d1e627c983617515067f826cc152568b835aff0d7278d9ae3a",
			"843dac219626e2684ad0580978e4938153835a9d2db96002186a4cd04a5ead59",
		],
		"score_vector": [
			{
				"slot_index": 0,
				"score": 103,
				"direct_interaction_score": 0,
				"generic_effect_bonus": 0,
				"phase_bonus": 0,
				"profile_signature_bonus": 0,
			},
			{
				"slot_index": 1,
				"score": 103,
				"direct_interaction_score": 0,
				"generic_effect_bonus": 0,
				"phase_bonus": 0,
				"profile_signature_bonus": 0,
			},
		],
		"ranked_slots": [0, 1],
		"selected_slot": 0,
		"observation_attempt_delta": 0,
		"normal_terminal_checkpoint": {
			"schema_version": 1,
			"rng_state": 4331395523003180704,
			"draw_count": 1,
		},
	},
	"owner_attested_legacy_flat": {
		"candidate_fingerprints": [
			"6f89fe8d2dac104ae11dde8b51216ba784507d689890084b9e21d24c98b76cbd",
			"91debf0692cd235023348c286a6fc8c7702d9704c2cf5336368581b754f23dce",
		],
		"score_vector": [
			{
				"slot_index": 0,
				"score": 512,
				"direct_interaction_score": 262,
				"generic_effect_bonus": 82,
				"phase_bonus": 65,
				"profile_signature_bonus": 0,
			},
			{
				"slot_index": 1,
				"score": 998,
				"direct_interaction_score": 570,
				"generic_effect_bonus": 260,
				"phase_bonus": 65,
				"profile_signature_bonus": 0,
			},
		],
		"ranked_slots": [1, 0],
		"selected_slot": 1,
		"observation_attempt_delta": 2,
		"normal_terminal_checkpoint": {
			"schema_version": 1,
			"rng_state": 4331395523003180704,
			"draw_count": 1,
		},
	},
	"owner_attested_genuine_v04_owner_restore": {
		"candidate_fingerprints": [
			"03b90992aaaae29c075823f4667fc3373fcea538e5a500e12d33942a6da2235f",
			"34170a9ee419e7ac86c725abdba223eeb43b93b9657358b1a695e100589eaf94",
		],
		"score_vector": [
			{
				"slot_index": 0,
				"score": 536,
				"direct_interaction_score": 262,
				"generic_effect_bonus": 82,
				"phase_bonus": 65,
				"profile_signature_bonus": 0,
			},
			{
				"slot_index": 1,
				"score": 1106,
				"direct_interaction_score": 570,
				"generic_effect_bonus": 260,
				"phase_bonus": 65,
				"profile_signature_bonus": 0,
			},
		],
		"ranked_slots": [1, 0],
		"selected_slot": 1,
		"observation_attempt_delta": 2,
		"normal_terminal_checkpoint": {
			"schema_version": 1,
			"rng_state": 4331395523003180704,
			"draw_count": 1,
		},
	},
}
const CARD_IDS := [
	"interaction.starlink_dismantle.rank_1",
	"interaction.starlink_dismantle.rank_2",
	"interaction.starlink_dismantle.rank_3",
	"interaction.starlink_dismantle.rank_4",
	"interaction.shadow_warehouse_traction.rank_1",
	"interaction.shadow_warehouse_traction.rank_2",
	"interaction.shadow_warehouse_traction.rank_3",
	"interaction.shadow_warehouse_traction.rank_4",
]
const GOLDEN_RANKED_CARD_IDS := [
	"interaction.shadow_warehouse_traction.rank_1",
	"interaction.shadow_warehouse_traction.rank_2",
	"interaction.shadow_warehouse_traction.rank_3",
	"interaction.shadow_warehouse_traction.rank_4",
	"interaction.starlink_dismantle.rank_1",
	"interaction.starlink_dismantle.rank_2",
	"interaction.starlink_dismantle.rank_3",
	"interaction.starlink_dismantle.rank_4",
]
const RUNTIME_ONLY_CARD_FIELDS := [
	"runtime_instance_id",
	"queued_for_resolution",
	"cooldown_left",
	"lock_left",
	"persistent",
]
const CANONICAL_INTERACTION_FIELDS := [
	"semantic_interaction_kind_id",
	"semantic_discard_count",
	"semantic_steal_count",
	"semantic_lock_duration_seconds",
	"semantic_cash_penalty",
	"semantic_steal_failure_cash",
]
const POLICY_INTERACTION_FIELDS := [
	"policy_interaction_kind_id",
	"policy_discard_count",
	"policy_steal_count",
	"policy_lock_duration_microseconds",
	"policy_cash_penalty",
	"policy_steal_failure_cash",
]
const DIRECT_PLAN_FIELDS := [
	"policy_kind",
	"target_player",
	"target_owner",
	"direct_interaction_role",
	"direct_interaction_score",
	"direct_target_settlement",
	"direct_target_gap",
	"direct_target_city_pressure",
	"direct_target_monster_pressure",
	"direct_target_public_audit_known",
	"direct_effect_pressure",
	"score",
	"reason",
]

var _checks := 0
var _failures: Array[String] = []
var _started_usec := 0
var _observation_capability_by_actor: Dictionary = {}
var _timings := {
	"repeat_100_ms": -1.0,
	"repeat_400_ms": -1.0,
}


class CandidateWorldOracle:
	extends Node

	var city := {
		"active": true,
		"owner": 2,
		"last_income": 0,
		"products": [],
		"demands": [],
		"trade_routes": [],
		"trade_route_damage": 0,
		"trade_disrupted_routes": 0,
		"warehouse_stockpile_count": 0,
		"warehouse_stockpile_units": 0,
		"warehouse_stockpile_products": [],
	}

	func _queued_card_entry_index_for_player(_player_index: int) -> int:
		return -1

	func _ai_runtime_world_constant_snapshot() -> Dictionary:
		return {"ECONOMY_LEGACY_TURN_SECONDS": 30.0}

	func _next_batch_card_entry_index_for_player(_player_index: int) -> int:
		return -1

	func _card_play_target_snapshot(skill: Dictionary) -> Dictionary:
		var kind := str(skill.get("kind", ""))
		var targets_player := kind in [
			"player_hand_disrupt",
			"player_hand_steal",
		] or bool(skill.get("target_player_required", false))
		return {
			"target_kind": "player" if targets_player else "none",
			"is_counter": false,
			"targets_monster": false,
			"targets_player": targets_player,
			"target_required": targets_player,
			"target_ready": true,
			"requires_target_monster": false,
			"requires_target_player": targets_player,
		}

	func _card_play_requirement_snapshot(
		_player_index: int,
		_skill: Dictionary
	) -> Dictionary:
		return {
			"kind": "none",
			"scope": "own_best_region",
			"required_share_percent": 0,
			"current_share_percent": 0.0,
			"qualifying_district": 0,
			"requirement_satisfied": true,
			"cash_cost": 0,
		}

	func _best_player_gdp_share_district(_player_index: int) -> int:
		return 0

	func _skill_play_product(
		_skill: Dictionary,
		_player_index: int
	) -> String:
		return ""

	func _skill_play_flow_required(
		_skill: Dictionary,
		_player_index: int = -1
	) -> int:
		return 0

	func _player_product_flow(
		_player_index: int,
		_product_name: String
	) -> int:
		return 0

	func _skill_duration_seconds(
		_skill: Dictionary,
		_seconds_key: String,
		_turns_key: String,
		_default_turns: int = 0
	) -> float:
		return 0.0

	func _district_city(index: int) -> Dictionary:
		return city.duplicate(true) if index == 0 else {}

	func _city_warehouse_stockpile_pressure(_city: Dictionary) -> int:
		return 0


func _init() -> void:
	_started_usec = Time.get_ticks_usec()
	call_deferred("_run")


func _run() -> void:
	var main_source_before := FileAccess.get_file_as_string(MAIN_SOURCE_PATH)
	var main_fingerprint_before := main_source_before.sha256_text()
	_expect(not main_source_before.is_empty(), "Main source is readable")
	_expect(
		main_fingerprint_before == MAIN_BASELINE_SHA256,
		"Main source matches the frozen 56b572a baseline fingerprint"
	)

	var coordinator := COORDINATOR_SCENE.instantiate() as GameRuntimeCoordinator
	_expect(coordinator != null, "production GameRuntimeCoordinator instantiates")
	if coordinator == null:
		_finish({})
		return
	coordinator.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(coordinator)
	await process_frame

	var fixture := SOURCE_FIXTURE.configure_coordinator(
		coordinator,
		"ai.card.interaction.scoring.parity.batch1"
	)
	_expect(not fixture.is_empty(), "production semantic source fixture configures")
	if fixture.is_empty():
		coordinator.queue_free()
		await process_frame
		_finish({})
		return

	var world := fixture.get("world") as WorldSessionState
	var source := fixture.get("source") as CardSemanticSourceAuthorizationPort
	var semantic_catalog := fixture.get("catalog") \
		as CardSemanticCatalogService
	var rng := fixture.get("rng") as RunRngService
	var service := coordinator.get_node_or_null(
		"AiCardInteractionObservationService"
	) as AiCardInteractionObservationService
	var observation_capability_map_variant: Variant = coordinator.get(
		"_ai_card_interaction_observation_capability_by_actor"
	)
	_observation_capability_by_actor = (
		observation_capability_map_variant as Dictionary
	).duplicate() if observation_capability_map_variant is Dictionary else {}
	var observation_capability := _observation_capability_by_actor.get(
		ACTOR_INDEX
	) as RefCounted
	var inventory := coordinator.get_node_or_null(
		"CardInventoryRuntimeService"
	) as CardInventoryRuntimeService
	var ai := coordinator.get_node_or_null(
		"AiRuntimeController"
	) as AiRuntimeController
	var bridge := coordinator.get_node_or_null(
		"AiRuntimeWorldBridge"
	) as AiRuntimeWorldBridge
	var capability_map_value: Variant = coordinator.get(
		"_card_semantic_source_capability_by_actor"
	)
	var capability_map := capability_map_value as Dictionary \
		if capability_map_value is Dictionary else {}
	var capability := capability_map.get(ACTOR_INDEX) \
		as AiActorHandInventoryCapability
	var catalog_fixture := load(CATALOG_PATH) \
		as CardRuntimeCatalogV06Resource
	var dependencies_ready := world != null \
		and source != null \
		and semantic_catalog != null \
		and rng != null \
		and service != null \
		and observation_capability != null \
		and inventory != null \
		and ai != null \
		and bridge != null \
		and capability != null \
		and catalog_fixture != null
	_expect(dependencies_ready, "all production dependencies resolve")
	if not dependencies_ready:
		coordinator.queue_free()
		await process_frame
		_finish({})
		return

	bridge.set_rng_service(rng)
	bridge.set_world_session_state(world)
	ai.set_world_bridge(bridge)
	ai.configure({"ruleset_id": "v0.6"})
	inventory.configure({
		"ruleset_id": "v0.4",
		"card_inventory": {
			"ordinary_hand_limit": HAND_LIMIT,
			"maximum_card_rank": 4,
		},
	})
	var catalog_report := catalog_fixture.reload()
	_expect(
		bool(catalog_report.get("valid", false))
			and int(catalog_report.get("card_count", 0)) == 348,
		"immutable v0.6 catalog fixture validates all 348 cards"
	)
	_expect(
		_sorted_strings(_direct_player_interaction_card_ids(catalog_fixture))
			== _sorted_strings(CARD_IDS),
		"all and only eight v0.6 cards enter the direct player interaction family"
	)
	_expect(
		service.is_ready() and source.is_ready() and inventory.is_ready(),
		"production observation, source authorization, and inventory are ready"
	)
	_expect(
		ai.get("_ai_card_interaction_observation_service") == service,
		"production AI receives the composed observation service"
	)
	var service_capability_map_value: Variant = service.get(
		"_actor_capability_by_index"
	)
	var service_capability_map := service_capability_map_value as Dictionary \
		if service_capability_map_value is Dictionary else {}
	_expect(
		service_capability_map.get(ACTOR_INDEX) == capability,
		"observation owner holds the Coordinator-bound actor capability"
	)
	_expect(
		not service.debug_snapshot().has("actor_capabilities")
			and not service.debug_snapshot().has("capability"),
		"observation owner never exposes its capability map through debug data"
	)

	var catalog_records := _catalog_records(catalog_fixture)
	_expect(
		catalog_records.size() == CARD_IDS.size(),
		"all eight interaction catalog records are present"
	)
	_expect(
		_install_authoritative_hand(world, catalog_records),
		"all eight exact catalog records occupy the authoritative AI hand"
	)
	_expect(
		_authoritative_hand_matches_catalog(world, catalog_records),
		"runtime-only instance fields leave each catalog record byte-for-data exact"
	)
	var actor_hand := ai._actor_hand_inventory_snapshot(ACTOR_INDEX)
	_expect(
		int(actor_hand.get("hand_limit", -1)) == HAND_LIMIT
			and int(actor_hand.get("counted_hand_size", -1)) == HAND_LIMIT,
		"authoritative hand is full so steal-failure cash affects legacy scoring"
	)
	_expect(
		is_equal_approx(
			float((ai._ai_profile_for_player(ACTOR_INDEX) as Dictionary).get(
				"exploration",
				-1.0
			)),
			0.0
		),
		"selection fixture disables exploration without changing selection code"
	)

	var registry := coordinator.get_node_or_null(
		"GameSessionRuntimeController/V06SaveOwnerRegistry"
	)
	var section_ids: Array = registry.call("fixed_section_order") \
		if registry != null else []
	var section_ids_before := section_ids.duplicate()
	var registry_before := registry.call("debug_snapshot") as Dictionary \
		if registry != null else {}
	var ai_save_before := ai.to_save_data()
	_expect(
		registry != null and section_ids.size() == 19,
		"production Save registry remains exactly 19 sections"
	)
	_expect(
		_not_contains_semantic_save_section(section_ids),
		"Save registry contains no semantic observation section"
	)

	var world_before := world.to_save_data()
	var ai_memory_before := _actor_private_ai_state(world, ACTOR_INDEX)
	var receipt_count_before := int(ai.debug_snapshot().get(
		"receipt_count",
		-1
	))
	var rng_before := rng.capture_plan_checkpoint()
	var catalog_before := semantic_catalog.validation_snapshot()
	var source_before := source.debug_snapshot()
	var service_before := service.debug_snapshot()
	var production_candidates: Array = []
	var legacy_candidates: Array = []
	var legacy_plan_by_card_id: Dictionary = {}
	var observation_by_card_id: Dictionary = {}
	var semantic_policy_differences: Array = []
	var direct_plan_mismatches: Array = []
	var policy_fingerprints: Dictionary = {}

	for slot_index in range(CARD_IDS.size()):
		var card_id := str(CARD_IDS[slot_index])
		var record := catalog_records.get(card_id, {}) as Dictionary
		var expected_facts := _canonical_facts_from_catalog(record)
		var legacy_world_card := ai._actor_hand_card_at(
			actor_hand,
			slot_index
		)
		var legacy_effective_facts := _legacy_effective_facts(
			legacy_world_card
		)
		var observation := service.observe_own_hand_interaction(
			observation_capability,
			ACTOR_INDEX,
			slot_index
		)
		var observation_validation := service.validate_observation(
			observation_capability,
			ACTOR_INDEX,
			observation
		)
		_expect(
			bool(observation_validation.get("valid", false)),
			"%s produces an issued valid observation" % card_id
		)
		_expect(
			_observation_identity_matches(
				observation,
				card_id,
				_runtime_instance_id(slot_index),
				slot_index
			),
			"%s observation binds actor, slot, instance, and card identity" % card_id
		)
		_expect(
			_selected_fields(observation, CANONICAL_INTERACTION_FIELDS)
				== expected_facts,
			"%s canonical fields equal the immutable legacy payload fixture" % card_id
		)
		var semantic_facts := _selected_fields(
			observation,
			CANONICAL_INTERACTION_FIELDS
		)
		var policy_facts := _selected_fields(
			observation,
			POLICY_INTERACTION_FIELDS
		)
		if semantic_facts != _semantic_shape_from_policy(policy_facts):
			semantic_policy_differences.append({
				"card_id": card_id,
				"world_card_top_level_keys": _sorted_keys(legacy_world_card),
				"world_card_top_level_kind": legacy_world_card.get(
					"kind",
					"<absent>"
				),
				"world_card_top_level_category": legacy_world_card.get(
					"category",
					"<absent>"
				),
				"flat_payload_fields_present": _present_fields(
					legacy_world_card,
					[
						"hand_discard_count",
						"hand_steal_count",
						"hand_lock_seconds",
						"target_cash_penalty",
						"steal_fail_cash",
					]
				),
				"legacy_effective_facts": legacy_effective_facts,
				"semantic_facts": semantic_facts,
			})
		_expect(
			policy_facts == legacy_effective_facts,
			(
				"%s policy/legacy effective mismatch: kind=%s category=%s flat=%s "
				+ "top_level_keys=%s legacy=%s policy=%s"
			)
				% [
					card_id,
					str(legacy_world_card.get("kind", "<absent>")),
					str(legacy_world_card.get("category", "<absent>")),
					JSON.stringify(_present_fields(
						legacy_world_card,
						[
							"hand_discard_count",
							"hand_steal_count",
							"hand_lock_seconds",
							"target_cash_penalty",
							"steal_fail_cash",
						]
					)),
					JSON.stringify(_sorted_keys(legacy_world_card)),
					JSON.stringify(legacy_effective_facts),
					JSON.stringify(policy_facts),
				]
		)
		_expect(
			str(observation.get("policy_compatibility_id", ""))
				== "legacy_ai_card_interaction_flat_fields_v1",
			"%s explicitly versions the temporary policy bridge" % card_id
		)
		policy_fingerprints[str(observation.get(
			"policy_compatibility_fingerprint",
			""
		))] = true
		var legacy_plan := _legacy_direct_player_interaction_plan(
			ai,
			ACTOR_INDEX,
			legacy_world_card
		)
		var production_plan := ai._ai_direct_player_interaction_plan(
			ACTOR_INDEX,
			observation
		)
		_expect(
			_has_exact_fields(legacy_plan, DIRECT_PLAN_FIELDS)
				and _has_exact_fields(production_plan, DIRECT_PLAN_FIELDS),
			"%s direct plans use the frozen closed score-component shape" % card_id
		)
		if production_plan != legacy_plan:
			direct_plan_mismatches.append({
				"card_id": card_id,
				"legacy_plan": legacy_plan,
				"production_plan": production_plan,
			})
		for field_value in DIRECT_PLAN_FIELDS:
			var field := str(field_value)
			_expect(
				production_plan.get(field) == legacy_plan.get(field),
				"%s direct-plan.%s mismatch: legacy=%s production=%s" % [
					card_id,
					field,
					JSON.stringify(legacy_plan.get(field)),
					JSON.stringify(production_plan.get(field)),
				]
			)
		_expect(
			int(production_plan.get("target_player", -1)) >= 0
				and int(production_plan.get("target_player", -1)) != ACTOR_INDEX,
			"%s selects a valid rival target" % card_id
		)
		_expect(
			int(production_plan.get("target_player", -1)) == 2
				and int(production_plan.get("direct_effect_pressure", -1)) == 75
				and int(production_plan.get("score", -1)) == 219,
			"%s matches the frozen 56b572a direct-plan golden" % card_id
		)
		observation_by_card_id[card_id] = observation.duplicate(true)
		legacy_plan_by_card_id[card_id] = legacy_plan.duplicate(true)
		production_candidates.append(_candidate(
			card_id,
			slot_index,
			production_plan
		))
		legacy_candidates.append(_candidate(card_id, slot_index, legacy_plan))

	var source_after_initial := source.debug_snapshot()
	var service_after_initial := service.debug_snapshot()
	_expect(
		semantic_policy_differences.size() == CARD_IDS.size()
			and policy_fingerprints.size() == CARD_IDS.size(),
		"all eight semantic/policy differences and slot-bound fingerprints are explicit"
	)
	_expect(
		_candidate_ids(production_candidates) == CARD_IDS
			and _candidate_ids(legacy_candidates) == CARD_IDS,
		"candidate membership and original catalog order are unchanged"
	)
	_expect(
		_counter_delta(
			source_before,
			source_after_initial,
			"request_binding_count"
		) == CARD_IDS.size()
			and _counter_delta(
				source_before,
				source_after_initial,
				"journal_entry_count"
			) == CARD_IDS.size(),
		"first authorization creates exactly one binding and journal row per slot"
	)
	_expect(
		_counter_delta(source_before, source_after_initial, "replay_count")
			== CARD_IDS.size(),
		"current validation performs one deterministic replay per first observation"
	)
	_expect(
		int(service_after_initial.get(
			"issued_observation_fingerprint_count",
			-1
		)) == CARD_IDS.size(),
		"observation journal contains exactly eight detached fingerprints"
	)

	var rank_checkpoint := rng.capture_plan_checkpoint()
	var production_ranked := ai.rank_candidates(
		ACTOR_INDEX,
		production_candidates,
		{"source_context": "interaction_observation_batch1"}
	)
	var legacy_ranked := ai.rank_candidates(
		ACTOR_INDEX,
		legacy_candidates,
		{"source_context": "legacy_interaction_oracle"}
	)
	_expect(
		production_ranked == legacy_ranked
			and _candidate_ids(production_ranked)
				== _candidate_ids(legacy_ranked)
			and _candidate_ids(production_ranked) == GOLDEN_RANKED_CARD_IDS,
		"ranked order is unchanged for all eight candidates"
	)
	_expect(
		_candidate_ids(production_ranked).size() == CARD_IDS.size(),
		"ranked order preserves all eight candidate identities"
	)
	_expect(
		rng.capture_plan_checkpoint() == rank_checkpoint,
		"manual direct-plan ranking consumes zero RNG"
	)

	var forced_checkpoint := rng.capture_plan_checkpoint()
	var forced_production := ai._ai_pick_candidate(
		ACTOR_INDEX,
		production_candidates,
		true
	)
	var forced_legacy := ai._ai_pick_candidate(
		ACTOR_INDEX,
		legacy_candidates,
		true
	)
	_expect(
		forced_production == forced_legacy
			and str(forced_production.get("card_id", "")) == str(CARD_IDS[0])
			and int(forced_production.get("slot_index", -1)) == 0,
		"forced selected candidate is unchanged"
	)
	_expect(
		rng.capture_plan_checkpoint() == forced_checkpoint,
		"forced selection consumes zero RNG before and after migration"
	)

	var normal_checkpoint := rng.capture_plan_checkpoint()
	var normal_production := ai._ai_pick_candidate(
		ACTOR_INDEX,
		production_candidates,
		false
	)
	var production_terminal_checkpoint := rng.capture_plan_checkpoint()
	var restore_before_legacy := rng.restore_plan_checkpoint(normal_checkpoint)
	var normal_legacy := ai._ai_pick_candidate(
		ACTOR_INDEX,
		legacy_candidates,
		false
	)
	var legacy_terminal_checkpoint := rng.capture_plan_checkpoint()
	var restore_after_comparison := rng.restore_plan_checkpoint(normal_checkpoint)
	_expect(
		bool(restore_before_legacy.get("restored", false))
			and bool(restore_after_comparison.get("restored", false)),
		"selection parity restores the exact shared RNG checkpoint"
	)
	_expect(
		normal_production == normal_legacy
			and str(normal_production.get("card_id", "")) == str(CARD_IDS[0])
			and int(normal_production.get("slot_index", -1)) == 0,
		"normal selected candidate is unchanged"
	)
	_expect(
		production_terminal_checkpoint == legacy_terminal_checkpoint
			and int(production_terminal_checkpoint.get("draw_count", -1))
				- int(normal_checkpoint.get("draw_count", -1)) == 1,
		"normal selection preserves one-draw RNG order and terminal checkpoint"
	)
	_expect(
		rng.capture_plan_checkpoint() == normal_checkpoint,
		"selection comparison leaves the live RNG checkpoint unchanged"
	)

	var performance_source_before := source.debug_snapshot()
	var performance_catalog_before := semantic_catalog.validation_snapshot()
	var performance_rng_before := rng.capture_plan_checkpoint()
	var repeat_valid_count := 0
	var repeat_valid_count_at_100 := -1
	var repeat_started_usec := Time.get_ticks_usec()
	for iteration in range(REPEAT_ITERATIONS):
		var slot_index := iteration % CARD_IDS.size()
		var card_id := str(CARD_IDS[slot_index])
		var observation := ai._authorized_card_interaction_observation(
			ACTOR_INDEX,
			slot_index
		)
		var plan := ai._ai_direct_player_interaction_plan(
			ACTOR_INDEX,
			observation
		)
		if not observation.is_empty() \
				and observation == observation_by_card_id.get(card_id, {}) \
				and plan == legacy_plan_by_card_id.get(card_id, {}):
			repeat_valid_count += 1
		if iteration + 1 == SAMPLE_ITERATIONS:
			repeat_valid_count_at_100 = repeat_valid_count
			_timings["repeat_100_ms"] = _elapsed_ms(repeat_started_usec)
	_timings["repeat_400_ms"] = _elapsed_ms(repeat_started_usec)
	var performance_source_after := source.debug_snapshot()
	var performance_catalog_after := semantic_catalog.validation_snapshot()
	var performance_rng_after := rng.capture_plan_checkpoint()
	_expect(
		repeat_valid_count == REPEAT_ITERATIONS,
		"all 400 repeated production observation-plus-plan calls preserve parity"
	)
	_expect(
		repeat_valid_count_at_100 == SAMPLE_ITERATIONS,
		"the independent 100-call checkpoint preserves complete parity"
	)
	_expect(
		float(_timings.get("repeat_100_ms", -1.0)) > 0.0
			and float(_timings.get("repeat_400_ms", -1.0))
				>= float(_timings.get("repeat_100_ms", -1.0))
			and float(_timings.get("repeat_400_ms", -1.0))
				< REPEAT_TIME_LIMIT_MS
			and float(_timings.get("repeat_400_ms", -1.0))
				<= float(_timings.get("repeat_100_ms", -1.0)) * 5.0 + 1000.0,
		"100 and 400 observation-plus-plan timings scale without order regression"
	)
	_expect(
		_counter_delta(
			performance_source_before,
			performance_source_after,
			"request_binding_count"
		) == 0
			and _counter_delta(
				performance_source_before,
				performance_source_after,
				"journal_entry_count"
			) == 0,
		"400 current-slot replays grow neither authorization registry nor journal"
	)
	_expect(
		_counter_delta(
			performance_source_before,
			performance_source_after,
			"replay_count"
		) == REPEAT_ITERATIONS,
		"each repeated observation performs exactly one deterministic replay"
	)
	_expect(
		int(performance_catalog_after.get("compile_count", -1))
			== int(performance_catalog_before.get("compile_count", -2))
			and int(performance_catalog_after.get("compile_count", -1))
				== int(catalog_before.get("compile_count", -2)),
		"initial and repeated observation-plus-plan compile_count delta is zero"
	)
	_expect(
		int(performance_catalog_after.get("cache_entry_count", -1))
			== int(catalog_before.get("cache_entry_count", -2)),
		"candidate loop neither reloads nor expands the semantic catalog"
	)
	_expect(
		performance_rng_after == performance_rng_before
			and performance_rng_after == rng_before,
		"all observation and direct-plan work consumes zero RNG"
	)

	var catalog_after := semantic_catalog.validation_snapshot()
	var source_after := source.debug_snapshot()
	var service_after := service.debug_snapshot()
	_expect(
		int(catalog_after.get("compile_count", -1))
			== int(catalog_before.get("compile_count", -2)),
		"semantic catalog compile_count remains unchanged end to end"
	)
	_expect(
		int(source_after.get("request_binding_count", -1))
			== int(source_before.get("request_binding_count", -2))
				+ CARD_IDS.size(),
		"authorization registry retains only the eight current source bindings"
	)
	_expect(
		int(service_after.get("issued_observation_fingerprint_count", -1))
			== CARD_IDS.size()
			and int(service_after.get("issued_observation_eviction_count", -1)) == 0,
		"observation replay journal remains bounded to eight fingerprints"
	)
	_expect(
		world.to_save_data() == world_before
			and _actor_private_ai_state(world, ACTOR_INDEX) == ai_memory_before
			and ai.to_save_data() == ai_save_before
			and section_ids_before == registry.call("fixed_section_order")
			and registry_before == registry.call("debug_snapshot"),
		"observation, planning, ranking, and selection commit no world or AI memory"
	)
	_expect(
		int(ai.debug_snapshot().get("receipt_count", -1))
			== receipt_count_before,
		"candidate comparison creates no AI commit receipt"
	)
	_expect(
		_catalog_fixture_unchanged(catalog_fixture, catalog_records),
		"legacy oracle never mutates the immutable v0.6 catalog fixture"
	)
	var production_candidate_gate: Dictionary = {}
	for carrier_id_variant in PRODUCTION_CARRIER_IDS:
		var carrier_id := str(carrier_id_variant)
		production_candidate_gate[carrier_id] = await \
			_run_production_candidate_case(carrier_id)
	var main_fingerprint_after := FileAccess.get_file_as_string(
		MAIN_SOURCE_PATH
	).sha256_text()
	_expect(
		main_fingerprint_after == main_fingerprint_before,
		"test and production observation path leave Main source unchanged"
	)

	var metrics := {
		"card_count": CARD_IDS.size(),
		"candidate_order": _candidate_ids(production_candidates),
		"ranked_order": _candidate_ids(production_ranked),
		"legacy_ranked_order": _candidate_ids(legacy_ranked),
		"forced_selected_card_id": str(forced_production.get("card_id", "")),
		"legacy_forced_selected_card_id": str(forced_legacy.get(
			"card_id",
			""
		)),
		"normal_selected_card_id": str(normal_production.get("card_id", "")),
		"legacy_normal_selected_card_id": str(normal_legacy.get(
			"card_id",
			""
		)),
		"repeat_100_ms": _timings.get("repeat_100_ms", -1.0),
		"repeat_valid_count_at_100": repeat_valid_count_at_100,
		"repeat_400_ms": _timings.get("repeat_400_ms", -1.0),
		"compile_count_before": int(catalog_before.get("compile_count", -1)),
		"compile_count_after": int(catalog_after.get("compile_count", -1)),
		"compile_delta": int(catalog_after.get("compile_count", -1))
			- int(catalog_before.get("compile_count", -1)),
		"cache_hit_delta": int(catalog_after.get("cache_hit_count", -1))
			- int(catalog_before.get("cache_hit_count", -1)),
		"authorization_binding_delta": _counter_delta(
			source_before,
			source_after,
			"request_binding_count"
		),
		"authorization_replay_delta": _counter_delta(
			source_before,
			source_after,
			"replay_count"
		),
		"observation_attempt_delta": _counter_delta(
			service_before,
			service_after,
			"observation_attempt_count"
		),
		"rng_unchanged": rng.capture_plan_checkpoint() == rng_before,
		"save_section_count": section_ids.size(),
		"main_fingerprint": main_fingerprint_after,
		"semantic_policy_differences": semantic_policy_differences,
		"direct_plan_mismatches": direct_plan_mismatches,
		"production_candidate_gate": production_candidate_gate,
	}
	coordinator.queue_free()
	await process_frame
	_finish(metrics)


func _catalog_records(
	catalog: CardRuntimeCatalogV06Resource
) -> Dictionary:
	var result: Dictionary = {}
	for card_id_variant in CARD_IDS:
		var card_id := str(card_id_variant)
		var record := catalog.card_snapshot(card_id)
		if not record.is_empty():
			result[card_id] = record.duplicate(true)
	return result


func _direct_player_interaction_card_ids(
	catalog: CardRuntimeCatalogV06Resource
) -> Array:
	var result: Array = []
	for card_id_variant in catalog.card_ids():
		var card_id := str(card_id_variant)
		var record := catalog.card_snapshot(card_id)
		var machine := record.get("machine", {}) as Dictionary
		if str(machine.get("effect_kind", "")) in [
			"player_hand_disrupt",
			"player_hand_steal",
		]:
			result.append(card_id)
	return result


func _install_authoritative_hand(
	world: WorldSessionState,
	catalog_records: Dictionary
) -> bool:
	var snapshot := world.internal_snapshot()
	var players_value: Variant = snapshot.get("players")
	if not (players_value is Array):
		return false
	var players := (players_value as Array).duplicate(true)
	if ACTOR_INDEX < 0 or ACTOR_INDEX >= players.size() \
			or not (players[ACTOR_INDEX] is Dictionary):
		return false
	var actor := (players[ACTOR_INDEX] as Dictionary).duplicate(true)
	var slots: Array = []
	for slot_index in range(CARD_IDS.size()):
		var card_id := str(CARD_IDS[slot_index])
		var record := catalog_records.get(card_id, {}) as Dictionary
		if record.is_empty():
			return false
		var runtime_card := record.duplicate(true)
		runtime_card["runtime_instance_id"] = _runtime_instance_id(slot_index)
		runtime_card["queued_for_resolution"] = false
		runtime_card["cooldown_left"] = 0.0
		runtime_card["lock_left"] = 0.0
		runtime_card["persistent"] = false
		slots.append(runtime_card)
	actor["slots"] = slots
	var profile_value: Variant = actor.get("ai_profile", {})
	var profile := (profile_value as Dictionary).duplicate(true) \
		if profile_value is Dictionary else {}
	profile["exploration"] = 0.0
	actor["ai_profile"] = profile
	players[ACTOR_INDEX] = actor
	snapshot["players"] = players
	world.restore(snapshot, true)
	var restored_players := world.internal_snapshot().get("players", []) as Array
	if ACTOR_INDEX < 0 or ACTOR_INDEX >= restored_players.size() \
			or not (restored_players[ACTOR_INDEX] is Dictionary):
		return false
	var restored_slots := (restored_players[ACTOR_INDEX] as Dictionary).get(
		"slots",
		[]
	) as Array
	return restored_slots.size() == CARD_IDS.size()


func _run_production_candidate_case(carrier_id: String) -> Dictionary:
	var started_usec := Time.get_ticks_usec()
	var coordinator := COORDINATOR_SCENE.instantiate() as GameRuntimeCoordinator
	_expect(
		coordinator != null,
		"%s production-candidate coordinator instantiates" % carrier_id
	)
	if coordinator == null:
		return {"carrier_id": carrier_id, "fixture_ready": false}
	coordinator.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(coordinator)
	await process_frame

	var fixture := SOURCE_FIXTURE.configure_coordinator(
		coordinator,
		"ai.card.interaction.production-candidate.%s" % carrier_id
	)
	var world := fixture.get("world") as WorldSessionState
	var semantic_catalog := fixture.get("catalog") \
		as CardSemanticCatalogService
	var rng := fixture.get("rng") as RunRngService
	var ai := coordinator.get_node_or_null(
		"AiRuntimeController"
	) as AiRuntimeController
	var bridge := coordinator.get_node_or_null(
		"AiRuntimeWorldBridge"
	) as AiRuntimeWorldBridge
	var monster_bridge := coordinator.get_node_or_null(
		"MonsterRuntimeWorldBridge"
	) as MonsterRuntimeWorldBridge
	var service := coordinator.get_node_or_null(
		"AiCardInteractionObservationService"
	) as AiCardInteractionObservationService
	var adapter := coordinator.get_node_or_null(
		"CardPlayerStateProductionAdapterV06"
	) as CardPlayerStateProductionAdapterV06
	var legacy_catalog := coordinator.get_node_or_null(
		"CardRuntimeCatalogService"
	) as CardRuntimeCatalogService
	var monster := coordinator.get_node_or_null(
		"MonsterRuntimeController"
	) as MonsterRuntimeController
	var cash_query := coordinator.get_node_or_null(
		"MonsterWagerCashCommitmentQueryPort"
	) as MonsterWagerCashCommitmentQueryPort
	var catalog := load(CATALOG_PATH) as CardRuntimeCatalogV06Resource
	var dependencies_ready := not fixture.is_empty() \
		and world != null \
		and semantic_catalog != null \
		and rng != null \
		and ai != null \
		and bridge != null \
		and monster_bridge != null \
		and service != null \
		and adapter != null \
		and legacy_catalog != null \
		and monster != null \
		and cash_query != null \
		and catalog != null \
		and bool(catalog.reload().get("valid", false))
	_expect(
		dependencies_ready,
		"%s production-candidate dependencies resolve" % carrier_id
	)
	if not dependencies_ready:
		coordinator.queue_free()
		await process_frame
		return {"carrier_id": carrier_id, "fixture_ready": false}

	var candidate_world := CandidateWorldOracle.new()
	root.add_child(candidate_world)
	bridge.bind_world(candidate_world)
	bridge.set_world_session_state(world)
	monster_bridge.bind_world(candidate_world)
	monster_bridge.set_world_session_state(world)
	monster.set_world_bridge(monster_bridge)
	ai.set_world_bridge(bridge)
	ai.configure({"ruleset_id": "v0.6"})
	rng.set_seed(PRODUCTION_CANDIDATE_RNG_SEED)
	var cash_query_configured := cash_query.configure(world, monster)
	_expect(
		bool(cash_query_configured.get("configured", false)),
		"%s production cash availability query binds" % carrier_id
	)

	var semantic_card_ids := _carrier_semantic_card_ids(carrier_id)
	var source_card_ids := _carrier_source_card_ids(carrier_id)
	var records: Dictionary = {}
	for card_id_variant in semantic_card_ids:
		var card_id := str(card_id_variant)
		var record := catalog.card_snapshot(card_id)
		if not record.is_empty():
			records[card_id] = record.duplicate(true)
	_expect(
		records.size() == semantic_card_ids.size(),
		"%s candidate records resolve from the exact v0.6 catalog" % carrier_id
	)
	var install := _install_production_candidate_carriers(
		world,
		adapter,
		legacy_catalog,
		records,
		carrier_id
	)
	_expect(
		bool(install.get("installed", false)),
		"%s authoritative carrier hand installs" % carrier_id
	)
	if not bool(install.get("installed", false)):
		candidate_world.queue_free()
		coordinator.queue_free()
		await process_frame
		return {
			"carrier_id": carrier_id,
			"fixture_ready": false,
			"install": install,
		}
	# WorldSessionState.restore advances every typed source generation. Rebind the
	# focused world oracle afterward so no production bridge can retain a stale
	# scene-world reference from fixture composition.
	bridge.bind_world(candidate_world)
	bridge.set_world_session_state(world)
	monster_bridge.bind_world(candidate_world)
	monster_bridge.set_world_session_state(world)
	monster.set_world_bridge(monster_bridge)
	ai.set_world_bridge(bridge)
	ai.set_monster_runtime_controller(monster)
	_expect(
		candidate_world.has_method("_district_city")
			and ai.get("_world_bridge") == bridge
			and monster_bridge.call_world(&"_district_city", [0]) \
				== candidate_world.city
			and bridge.call_world(
				&"_skill_duration_seconds",
				[{}, "seconds", "turns", 0]
			) == 0.0
			and ai._skill_duration_seconds(
				{},
				"seconds",
				"turns",
				0
			) == 0.0,
		"%s focused world oracle is live after authoritative restore" % carrier_id
	)

	var hand := ai._actor_hand_inventory_snapshot(ACTOR_INDEX)
	var hand_cards: Array = []
	for slot_index in range(source_card_ids.size()):
		hand_cards.append(ai._actor_hand_card_at(hand, slot_index))
	_expect(
		hand_cards.size() == source_card_ids.size()
			and not (hand_cards[0] as Dictionary).is_empty()
			and not (hand_cards[1] as Dictionary).is_empty(),
		"%s typed hand port returns every authoritative carrier" % carrier_id
	)
	_expect(
		_hand_card_ids(hand) == source_card_ids,
		"%s candidate slots retain authoritative source identities" \
			% carrier_id
	)
	if carrier_id == CARRIER_RAW_V06:
		_expect(
			not (hand_cards[0] as Dictionary).has("kind")
				and not (hand_cards[1] as Dictionary).has("kind"),
			"raw v0.6 carriers preserve the exact static shape without top-level kind"
		)
	elif carrier_id == CARRIER_PRODUCTION_ADAPTER:
		_expect(
			str((hand_cards[0] as Dictionary).get("kind", "")) == "interaction"
				and str((hand_cards[1] as Dictionary).get("kind", "")) \
					== "interaction"
				and bool(install.get("adapter_output_method_used", false)),
			"adapter carriers come from the production adapter output method"
		)
	elif carrier_id == CARRIER_LEGACY_FLAT:
		_expect(
			str((hand_cards[0] as Dictionary).get("kind", "")) \
				== "player_hand_disrupt"
				and str((hand_cards[1] as Dictionary).get("kind", "")) \
					== "player_hand_steal",
			"legacy carriers expose the two frozen pre-batch interaction kinds"
		)
	else:
		_expect(
			hand_cards.size() == GENUINE_V04_CARD_IDS.size()
				and not (hand_cards[0] as Dictionary).has("machine")
				and not (hand_cards[-1] as Dictionary).has("developer")
				and str((hand_cards[0] as Dictionary).get("name", ""))
					== str(GENUINE_V04_CARD_IDS[0]),
			"genuine v0.4 owner-restored carriers retain the exact flat shape"
		)

	var service_before := service.debug_snapshot()
	var catalog_before := semantic_catalog.validation_snapshot()
	var rng_before := rng.capture_plan_checkpoint()
	var world_before := world.to_save_data()
	var ai_save_before := ai.to_save_data()
	var ai_memory_before := _actor_private_ai_state(world, ACTOR_INDEX)
	var economy_facts := ai._actor_decision_economy_facts(ACTOR_INDEX)
	var economy_port := coordinator.get_node_or_null(
		"AiActorEconomyFactsQueryPort"
	) as AiActorEconomyFactsQueryPort
	var cash_probe := cash_query.private_cash_availability_projection(
		ACTOR_INDEX
	)
	var commitment_probe := monster.private_wager_cash_commitment_snapshot(
		ACTOR_INDEX
	)
	var candidate_preconditions := {
		"is_ai": ai._player_is_ai(ACTOR_INDEX),
		"economy_facts_present": not economy_facts.is_empty(),
		"action_ready": bool(economy_facts.get("action_ready", false)),
		"hand_snapshot_present": not hand.is_empty(),
		"hand_slot_count": (hand.get("slots", []) as Array).size(),
		"queued_index": ai._queued_card_entry_index_for_player(ACTOR_INDEX),
		"next_queue_index": ai._next_batch_card_entry_index_for_player(
			ACTOR_INDEX
		),
		"economy_port_ready": economy_port != null and economy_port.is_ready(),
		"cash_probe_valid": bool(cash_probe.get("valid", false)),
		"cash_probe_reason": str(cash_probe.get("reason_code", "")),
		"commitment_probe_valid": bool(commitment_probe.get("valid", false)),
		"commitment_probe_reason": str(commitment_probe.get(
			"reason_code",
			""
		)),
	}
	_expect(
		bool(candidate_preconditions.get("is_ai", false))
			and bool(candidate_preconditions.get("economy_facts_present", false))
			and bool(candidate_preconditions.get("action_ready", false))
			and bool(candidate_preconditions.get("hand_snapshot_present", false))
			and int(candidate_preconditions.get("queued_index", -2)) == -1
			and int(candidate_preconditions.get("next_queue_index", -2)) == -1,
		"%s real candidate preconditions are production-ready" % carrier_id
	)
	var scoring_context := _production_candidate_scoring_context(ai)
	var production_candidates := ai._ai_card_play_candidates(
		ACTOR_INDEX,
		scoring_context
	)
	var rng_after_generation := rng.capture_plan_checkpoint()
	var service_after_generation := service.debug_snapshot()
	var catalog_after_generation := semantic_catalog.validation_snapshot()
	var baseline_candidates := _legacy_card_play_candidates_oracle(
		ai,
		ai._actor_hand_inventory_snapshot(ACTOR_INDEX),
		_production_candidate_scoring_context(ai)
	)
	_expect(
		production_candidates == baseline_candidates,
		"%s full production candidates equal the frozen 56b572a oracle" \
			% carrier_id
	)
	_expect(
		_candidate_membership(production_candidates)
			== _candidate_membership(baseline_candidates)
			and production_candidates.size() == source_card_ids.size(),
		"%s candidate membership preserves every authoritative slot" \
			% carrier_id
	)
	for candidate_index in range(production_candidates.size()):
		var production_candidate := production_candidates[candidate_index] \
			as Dictionary
		var baseline_candidate := baseline_candidates[candidate_index] \
			as Dictionary
		_expect(
			_sorted_strings(production_candidate.keys())
				== _sorted_strings(baseline_candidate.keys())
				and production_candidate == baseline_candidate,
			"%s slot %d preserves every candidate score component" % [
				carrier_id,
				candidate_index,
			]
		)
	var frozen_golden := FROZEN_PRODUCTION_CANDIDATE_GOLDENS.get(
		carrier_id,
		{}
	) as Dictionary
	_expect(
		_candidate_fingerprints(production_candidates)
			== frozen_golden.get("candidate_fingerprints", [])
			and _candidate_scores(production_candidates)
				== frozen_golden.get("score_vector", []),
		"%s full candidates match frozen 56b572a fingerprints and scores" \
			% carrier_id
	)

	var observation_attempt_delta := _counter_delta(
		service_before,
		service_after_generation,
		"observation_attempt_count"
	)
	var observation_success_delta := _counter_delta(
		service_before,
		service_after_generation,
		"observation_success_count"
	)
	var observation_rejection_delta := _counter_delta(
		service_before,
		service_after_generation,
		"rejection_count"
	)
	_expect(
		observation_attempt_delta == int(frozen_golden.get(
			"observation_attempt_delta",
			-1
		))
			and (
				observation_attempt_delta == 0
				if carrier_id in [
					CARRIER_RAW_V06,
					CARRIER_PRODUCTION_ADAPTER,
				]
				else observation_attempt_delta > 0
			),
		"%s observation attempt delta matches the production carrier branch" \
			% carrier_id
	)
	_expect(
		observation_success_delta == observation_attempt_delta
			and observation_rejection_delta == 0,
		"%s every attempted owner-attested observation succeeds" % carrier_id
	)
	_expect(
		int(catalog_after_generation.get("compile_count", -1))
			== int(catalog_before.get("compile_count", -2)),
		"%s real candidate generation has zero semantic compile delta" \
			% carrier_id
	)
	_expect(
		rng_after_generation == rng_before,
		"%s real candidate generation consumes zero RNG" % carrier_id
	)

	var production_rank_checkpoint := rng.capture_plan_checkpoint()
	var production_ranked := ai.rank_candidates(
		ACTOR_INDEX,
		production_candidates,
		{"source_context": "production_candidate_%s" % carrier_id}
	)
	var baseline_ranked := ai.rank_candidates(
		ACTOR_INDEX,
		baseline_candidates,
		{"source_context": "frozen_56b572a_%s" % carrier_id}
	)
	_expect(
		production_ranked == baseline_ranked
			and _candidate_slot_indices(production_ranked)
				== frozen_golden.get("ranked_slots", []),
		"%s production rank_candidates preserves full ranked candidates" \
			% carrier_id
	)
	_expect(
		rng.capture_plan_checkpoint() == production_rank_checkpoint,
		"%s production and baseline ranking consume zero RNG" % carrier_id
	)

	var forced_checkpoint := rng.capture_plan_checkpoint()
	var production_forced := ai._ai_pick_candidate(
		ACTOR_INDEX,
		production_candidates,
		true
	)
	var baseline_forced := ai._ai_pick_candidate(
		ACTOR_INDEX,
		baseline_candidates,
		true
	)
	_expect(
		production_forced == baseline_forced
			and int(production_forced.get("slot_index", -1))
				== int(frozen_golden.get("selected_slot", -2)),
		"%s forced production selection preserves the frozen winner" \
			% carrier_id
	)
	_expect(
		rng.capture_plan_checkpoint() == forced_checkpoint,
		"%s forced selection consumes zero RNG" % carrier_id
	)

	var normal_checkpoint := rng.capture_plan_checkpoint()
	var production_normal := ai._ai_pick_candidate(
		ACTOR_INDEX,
		production_candidates,
		false
	)
	var production_terminal := rng.capture_plan_checkpoint()
	var restore_before_baseline := rng.restore_plan_checkpoint(normal_checkpoint)
	var baseline_normal := ai._ai_pick_candidate(
		ACTOR_INDEX,
		baseline_candidates,
		false
	)
	var baseline_terminal := rng.capture_plan_checkpoint()
	var restore_after_baseline := rng.restore_plan_checkpoint(normal_checkpoint)
	_expect(
		bool(restore_before_baseline.get("restored", false))
			and bool(restore_after_baseline.get("restored", false))
			and production_normal == baseline_normal
			and int(production_normal.get("slot_index", -1))
				== int(frozen_golden.get("selected_slot", -2)),
		"%s normal production selection preserves the frozen winner" \
			% carrier_id
	)
	_expect(
		production_terminal == baseline_terminal
			and production_terminal
				== frozen_golden.get("normal_terminal_checkpoint", {})
			and int(production_terminal.get("draw_count", -1))
				- int(normal_checkpoint.get("draw_count", -1)) == 1,
		"%s normal selection preserves the frozen one-draw RNG checkpoint" \
			% carrier_id
	)
	_expect(
		rng.capture_plan_checkpoint() == normal_checkpoint,
		"%s selection comparison restores the live RNG checkpoint" % carrier_id
	)
	var candidate_loop_performance: Dictionary = {}
	if carrier_id == CARRIER_GENUINE_V04_OWNER:
		candidate_loop_performance = _genuine_v04_candidate_loop_performance(
			ai,
			service,
			semantic_catalog,
			rng
		)
	_expect(
		world.to_save_data() == world_before
			and ai.to_save_data() == ai_save_before
			and _actor_private_ai_state(world, ACTOR_INDEX) == ai_memory_before,
		"%s candidates, ranking, and selection leave AI memory/save unchanged" \
			% carrier_id
	)

	var result := {
		"carrier_id": carrier_id,
		"fixture_ready": true,
		"candidate_count": production_candidates.size(),
		"authoritative_hand_card_ids": _hand_card_ids(hand),
		"candidate_preconditions": candidate_preconditions,
		"candidate_membership": _candidate_membership(production_candidates),
		"candidate_fingerprints": _candidate_fingerprints(
			production_candidates
		),
		"candidate_scores": _candidate_scores(production_candidates),
		"ranked_membership": _candidate_membership(production_ranked),
		"forced_membership": _candidate_identity(production_forced),
		"normal_membership": _candidate_identity(production_normal),
		"observation_attempt_delta": observation_attempt_delta,
		"observation_success_delta": observation_success_delta,
		"observation_rejection_delta": observation_rejection_delta,
		"compile_delta": int(catalog_after_generation.get(
			"compile_count",
			-1
		)) - int(catalog_before.get("compile_count", -1)),
		"generation_rng_unchanged": rng_after_generation == rng_before,
		"normal_selection_draw_delta": int(production_terminal.get(
			"draw_count",
			-1
		)) - int(normal_checkpoint.get("draw_count", -1)),
		"normal_terminal_checkpoint": production_terminal.duplicate(true),
		"memory_unchanged": _actor_private_ai_state(world, ACTOR_INDEX) \
			== ai_memory_before,
		"candidate_loop_performance": candidate_loop_performance,
		"duration_ms": _elapsed_ms(started_usec),
	}
	candidate_world.queue_free()
	coordinator.queue_free()
	await process_frame
	return result


func _genuine_v04_candidate_loop_performance(
	ai: AiRuntimeController,
	service: AiCardInteractionObservationService,
	semantic_catalog: CardSemanticCatalogService,
	rng: RunRngService
) -> Dictionary:
	var legacy_warmup := _candidate_loop_sample(ai, false)
	var authorized_warmup := _candidate_loop_sample(ai, true)
	_expect(
		legacy_warmup.get("candidates", [])
			== authorized_warmup.get("candidates", []),
		"genuine v0.4 warmup candidate loops preserve exact parity"
	)
	var service_before := service.debug_snapshot()
	var catalog_before := semantic_catalog.validation_snapshot()
	var rng_before := rng.capture_plan_checkpoint()
	var legacy_total_usec := 0
	var authorized_total_usec := 0
	var parity_count := 0
	for iteration in range(CANDIDATE_PERFORMANCE_ITERATIONS):
		var legacy_sample: Dictionary
		var authorized_sample: Dictionary
		if iteration % 2 == 0:
			legacy_sample = _candidate_loop_sample(ai, false)
			authorized_sample = _candidate_loop_sample(ai, true)
		else:
			authorized_sample = _candidate_loop_sample(ai, true)
			legacy_sample = _candidate_loop_sample(ai, false)
		legacy_total_usec += int(legacy_sample.get("elapsed_usec", 0))
		authorized_total_usec += int(authorized_sample.get("elapsed_usec", 0))
		if legacy_sample.get("candidates", []) \
				== authorized_sample.get("candidates", []):
			parity_count += 1
	var service_after := service.debug_snapshot()
	var catalog_after := semantic_catalog.validation_snapshot()
	var rng_after := rng.capture_plan_checkpoint()
	var legacy_total_ms := snappedf(float(legacy_total_usec) / 1000.0, 0.001)
	var authorized_total_ms := snappedf(
		float(authorized_total_usec) / 1000.0,
		0.001
	)
	var legacy_per_iteration_ms := snappedf(
		legacy_total_ms / float(CANDIDATE_PERFORMANCE_ITERATIONS),
		0.001
	)
	var authorized_per_iteration_ms := snappedf(
		authorized_total_ms / float(CANDIDATE_PERFORMANCE_ITERATIONS),
		0.001
	)
	var authorized_to_legacy_ratio_raw := \
		float(authorized_total_usec) / float(maxi(legacy_total_usec, 1))
	var authorized_to_legacy_ratio := snappedf(
		authorized_to_legacy_ratio_raw,
		0.001
	)
	var expected_observation_count := CANDIDATE_PERFORMANCE_ITERATIONS \
		* GENUINE_V04_CARD_IDS.size()
	_expect(
		parity_count == CANDIDATE_PERFORMANCE_ITERATIONS,
		"all measured genuine v0.4 candidate loops preserve exact parity"
	)
	_expect(
		legacy_total_usec > 0
			and authorized_total_usec > 0
			and legacy_total_ms + authorized_total_ms
				< CANDIDATE_PERFORMANCE_TIME_LIMIT_MS,
		"bounded genuine v0.4 candidate-loop measurements complete within 15 seconds"
	)
	_expect(
		authorized_to_legacy_ratio_raw < CANDIDATE_PERFORMANCE_MAX_RATIO,
		(
			"authorized genuine v0.4 candidate loop stays within the %.1fx "
			+ "order-of-magnitude regression guard (measured %.3fx)"
		) % [
			CANDIDATE_PERFORMANCE_MAX_RATIO,
			authorized_to_legacy_ratio,
		]
	)
	_expect(
		_counter_delta(
			service_before,
			service_after,
			"observation_attempt_count"
		) == expected_observation_count
			and _counter_delta(
				service_before,
				service_after,
				"observation_success_count"
			) == expected_observation_count
			and _counter_delta(
				service_before,
				service_after,
				"rejection_count"
			) == 0,
		"measured authorized loops issue exactly two accepted observations each"
	)
	_expect(
		int(catalog_after.get("compile_count", -1))
			== int(catalog_before.get("compile_count", -2)),
		"candidate-loop performance comparison has zero semantic compile delta"
	)
	_expect(
		rng_after == rng_before,
		"candidate-loop performance comparison consumes zero RNG"
	)
	return {
		"fixture_id": CARRIER_GENUINE_V04_OWNER,
		"iterations": CANDIDATE_PERFORMANCE_ITERATIONS,
		"legacy_total_ms": legacy_total_ms,
		"legacy_per_iteration_ms": legacy_per_iteration_ms,
		"authorized_total_ms": authorized_total_ms,
		"authorized_per_iteration_ms": authorized_per_iteration_ms,
		"authorized_to_legacy_ratio": authorized_to_legacy_ratio,
		"max_allowed_ratio": CANDIDATE_PERFORMANCE_MAX_RATIO,
		"parity_count": parity_count,
		"observation_attempt_delta": _counter_delta(
			service_before,
			service_after,
			"observation_attempt_count"
		),
		"compile_delta": int(catalog_after.get("compile_count", -1))
			- int(catalog_before.get("compile_count", -1)),
		"rng_unchanged": rng_after == rng_before,
	}


func _candidate_loop_sample(
	ai: AiRuntimeController,
	use_authorized_observation: bool
) -> Dictionary:
	var started_usec := Time.get_ticks_usec()
	var candidates: Array
	if use_authorized_observation:
		candidates = ai._ai_card_play_candidates(
			ACTOR_INDEX,
			_production_candidate_scoring_context(ai)
		)
	else:
		candidates = _legacy_card_play_candidates_oracle(
			ai,
			ai._actor_hand_inventory_snapshot(ACTOR_INDEX),
			_production_candidate_scoring_context(ai)
		)
	return {
		"elapsed_usec": Time.get_ticks_usec() - started_usec,
		"candidates": candidates,
	}


func _install_production_candidate_carriers(
	world: WorldSessionState,
	adapter: CardPlayerStateProductionAdapterV06,
	legacy_catalog: CardRuntimeCatalogService,
	records: Dictionary,
	carrier_id: String
) -> Dictionary:
	var slots: Array = []
	var semantic_card_ids := _carrier_semantic_card_ids(carrier_id)
	for slot_index in range(semantic_card_ids.size()):
		var card_id := str(semantic_card_ids[slot_index])
		var record := records.get(card_id, {}) as Dictionary
		if record.is_empty():
			return {"installed": false, "reason_id": "record_missing"}
		if carrier_id == CARRIER_RAW_V06:
			slots.append(_raw_v06_runtime_card(record, carrier_id, slot_index))
		elif carrier_id == CARRIER_LEGACY_FLAT:
			slots.append(_legacy_flat_runtime_card(record, carrier_id, slot_index))
		elif carrier_id == CARRIER_GENUINE_V04_OWNER:
			var source_card_id := str(GENUINE_V04_CARD_IDS[slot_index])
			var definition := legacy_catalog.exact_definition(source_card_id)
			if definition.is_empty():
				return {
					"installed": false,
					"reason_id": "legacy_v04_definition_missing",
				}
			slots.append(_genuine_v04_runtime_card(
				definition,
				source_card_id,
				carrier_id,
				slot_index
			))
	if carrier_id == CARRIER_PRODUCTION_ADAPTER:
		return _commit_adapter_candidate_hand(world, adapter, records)
	if slots.size() != semantic_card_ids.size() \
			or not _restore_candidate_world(world, slots):
		return {"installed": false, "reason_id": "world_restore_failed"}
	return {
		"installed": true,
		"adapter_transaction_committed": false,
	}


func _restore_candidate_world(
	world: WorldSessionState,
	slots: Array
) -> bool:
	var snapshot := world.internal_snapshot()
	var players := snapshot.get("players", []) as Array
	if ACTOR_INDEX < 0 or ACTOR_INDEX >= players.size() \
			or not (players[ACTOR_INDEX] is Dictionary):
		return false
	var actor := (players[ACTOR_INDEX] as Dictionary).duplicate(true)
	actor["slots"] = slots.duplicate(true)
	var profile := (actor.get("ai_profile", {}) as Dictionary).duplicate(true) \
		if actor.get("ai_profile", {}) is Dictionary else {}
	profile["exploration"] = 0.0
	actor["ai_profile"] = profile
	players[ACTOR_INDEX] = actor
	snapshot["players"] = players
	snapshot["districts"] = [{
		"name": "Candidate Region",
		"destroyed": false,
		"terrain": "land",
		"damage": 0,
		"panic": 0,
		"products": [],
		"demands": [],
		"city": {
			"active": true,
			"owner": 2,
			"products": [],
			"demands": [],
			"trade_routes": [],
		},
	}]
	world.restore(snapshot, true)
	var restored := world.internal_snapshot()
	var restored_players := restored.get("players", []) as Array
	return restored_players.size() > ACTOR_INDEX \
		and restored_players[ACTOR_INDEX] is Dictionary \
		and ((restored_players[ACTOR_INDEX] as Dictionary).get(
			"slots",
			[]
		) as Array).size() == slots.size() \
		and (restored.get("districts", []) as Array).size() == 1


func _commit_adapter_candidate_hand(
	world: WorldSessionState,
	adapter: CardPlayerStateProductionAdapterV06,
	records: Dictionary
) -> Dictionary:
	var adapter_slots: Array = []
	for slot_index in range(PRODUCTION_CANDIDATE_CARD_IDS.size()):
		var card_id := str(PRODUCTION_CANDIDATE_CARD_IDS[slot_index])
		var record := records.get(card_id, {}) as Dictionary
		var canonical := {
			"machine": (record.get("machine", {}) as Dictionary).duplicate(true),
			"player": (record.get("player", {}) as Dictionary).duplicate(true),
			"developer": (record.get("developer", {}) as Dictionary).duplicate(
				true
			),
			"runtime_instance_id": _carrier_instance_id(
				CARRIER_PRODUCTION_ADAPTER,
				slot_index
			),
		}
		var output_value: Variant = adapter.call(
			"_world_card_from_canonical",
			canonical
		)
		if not (output_value is Dictionary):
			return {"installed": false, "reason_id": "adapter_output_invalid"}
		var output := output_value as Dictionary
		if str(output.get("kind", "")) != "interaction" \
				or str(output.get("runtime_instance_id", "")) \
					!= _carrier_instance_id(
						CARRIER_PRODUCTION_ADAPTER,
						slot_index
					):
			return {"installed": false, "reason_id": "adapter_shape_invalid"}
		adapter_slots.append(output.duplicate(true))
	var installed := _restore_candidate_world(world, adapter_slots)
	var restored_players := world.internal_snapshot().get("players", []) as Array
	var output_shape_valid := installed \
		and ACTOR_INDEX < restored_players.size() \
		and restored_players[ACTOR_INDEX] is Dictionary
	var restored_slots: Array = []
	if output_shape_valid:
		restored_slots = (restored_players[ACTOR_INDEX] as Dictionary).get(
			"slots",
			[]
		) as Array
	output_shape_valid = output_shape_valid \
		and restored_slots.size() == adapter_slots.size()
	for slot_index in range(restored_slots.size()):
		output_shape_valid = output_shape_valid \
			and restored_slots[slot_index] == adapter_slots[slot_index] \
			and str((restored_slots[slot_index] as Dictionary).get(
				"kind",
				""
			)) == "interaction" \
			and str((restored_slots[slot_index] as Dictionary).get(
				"runtime_instance_id",
				""
			)) == _carrier_instance_id(
				CARRIER_PRODUCTION_ADAPTER,
				slot_index
			)
	return {
		"installed": output_shape_valid,
		"adapter_output_method_used": true,
	}


func _raw_v06_runtime_card(
	record: Dictionary,
	carrier_id: String,
	slot_index: int
) -> Dictionary:
	var card := record.duplicate(true)
	card["runtime_instance_id"] = _carrier_instance_id(carrier_id, slot_index)
	card["queued_for_resolution"] = false
	card["cooldown_left"] = 0.0
	card["lock_left"] = 0.0
	card["persistent"] = false
	return card


func _legacy_flat_runtime_card(
	record: Dictionary,
	carrier_id: String,
	slot_index: int
) -> Dictionary:
	var card := _raw_v06_runtime_card(record, carrier_id, slot_index)
	var machine := record.get("machine", {}) as Dictionary
	var player := record.get("player", {}) as Dictionary
	var payload := machine.get("effect_payload", {}) as Dictionary
	card["card_id"] = str(machine.get("card_id", ""))
	card["name"] = str(machine.get("card_id", ""))
	card["display_name"] = str(player.get("name", card.get("name", "")))
	card["family_id"] = str(machine.get("family_id", ""))
	card["rank"] = int(machine.get("rank", 1))
	card["kind"] = str(machine.get("effect_kind", ""))
	card["counts_toward_hand_limit"] = bool(machine.get(
		"counts_toward_hand_limit",
		true
	))
	card["text"] = str(player.get("effect", player.get("short_effect", "")))
	card["hand_discard_count"] = int(payload.get("hand_discard_count", 0))
	card["hand_steal_count"] = int(payload.get("hand_steal_count", 0))
	card["hand_lock_seconds"] = float(payload.get("hand_lock_seconds", 0.0))
	card["target_cash_penalty"] = int(payload.get("target_cash_penalty", 0))
	card["steal_fail_cash"] = int(payload.get("steal_fail_cash", 0))
	return card


func _genuine_v04_runtime_card(
	definition: Dictionary,
	source_card_id: String,
	carrier_id: String,
	slot_index: int
) -> Dictionary:
	var card := CARD_PLAY_REQUIREMENT_POLICY.apply_to_card(
		source_card_id,
		definition
	)
	card["runtime_instance_id"] = _carrier_instance_id(carrier_id, slot_index)
	card["queued_for_resolution"] = false
	card["cooldown_left"] = 0.0
	card["lock_left"] = 0.0
	card["persistent"] = false
	return card


func _carrier_semantic_card_ids(carrier_id: String) -> Array:
	return PRODUCTION_CANDIDATE_CARD_IDS.duplicate()


func _carrier_source_card_ids(carrier_id: String) -> Array:
	return GENUINE_V04_CARD_IDS.duplicate() \
		if carrier_id == CARRIER_GENUINE_V04_OWNER \
		else PRODUCTION_CANDIDATE_CARD_IDS.duplicate()


func _carrier_instance_id(carrier_id: String, slot_index: int) -> String:
	return "batch1:%s:instance:%02d" % [carrier_id, slot_index]


func _production_candidate_scoring_context(
	ai: AiRuntimeController
) -> Dictionary:
	return {
		"cache_active": true,
		"player_index": ACTOR_INDEX,
		"slot_play_contexts": {},
		"district_focus_score_by_index": {},
		"own_city": 0,
		"rival_city": 0,
		"fallback_district": 0,
		"focus_product": "",
		"focus_score": 0,
		"strategy": {},
		"route_plan": {},
		"route_product": "",
		"route_stage": "",
		"phase_info": {
			"phase": "midgame",
			"posture": "contesting",
			"gap": 0,
			"leader_index": 2,
		},
		"endgame_urgency": 0,
		"profile": ai._ai_profile_for_player(ACTOR_INDEX),
		"victory_context": {"player_valid": false},
	}


func _legacy_card_play_candidates_oracle(
	ai: AiRuntimeController,
	hand_snapshot: Dictionary,
	play_scoring_context: Dictionary
) -> Array:
	var result: Array = []
	var economy_facts := ai._actor_decision_economy_facts(ACTOR_INDEX)
	if not ai._player_is_ai(ACTOR_INDEX) \
			or economy_facts.is_empty() \
			or hand_snapshot.is_empty() \
			or not bool(economy_facts.get("action_ready", false)):
		return result
	if ai._queued_card_entry_index_for_player(ACTOR_INDEX) >= 0 \
			or ai._next_batch_card_entry_index_for_player(ACTOR_INDEX) >= 0:
		return result
	var slot_play_contexts := play_scoring_context.get(
		"slot_play_contexts",
		{}
	) as Dictionary
	for entry_value in ai._actor_hand_slot_entries(hand_snapshot):
		if not (entry_value is Dictionary):
			continue
		var entry := entry_value as Dictionary
		if not bool(entry.get("occupied", false)):
			continue
		var slot_index := int(entry.get("slot_index", -1))
		var skill := entry.get("card", {}) as Dictionary
		if bool(skill.get("queued_for_resolution", false)) \
				or float(skill.get("cooldown_left", 0.0)) > 0.0 \
				or float(skill.get("lock_left", 0.0)) > 0.0:
			continue
		var context := _legacy_card_play_context_oracle(
			ai,
			ACTOR_INDEX,
			slot_index,
			skill,
			play_scoring_context
		)
		slot_play_contexts[slot_index] = context
		if not context.is_empty():
			result.append(context)
	return result


func _legacy_card_play_context_oracle(
	ai: AiRuntimeController,
	player_index: int,
	slot_index: int,
	skill: Dictionary,
	cached_context: Dictionary
) -> Dictionary:
	var kind := str(skill.get("kind", ""))
	var cache_active := bool(cached_context.get("cache_active", false)) \
		and int(cached_context.get("player_index", -1)) == player_index
	var turn_context: Dictionary = cached_context if cache_active else {}
	var own_city := int(turn_context.get("own_city", -1)) \
		if cache_active and turn_context.has("own_city") \
		else ai._ai_best_city_district(player_index, true)
	var rival_city := int(turn_context.get("rival_city", -1)) \
		if cache_active and turn_context.has("rival_city") \
		else ai._ai_best_pressure_target_city(player_index)
	var fallback := int(turn_context.get("fallback_district", -1)) \
		if cache_active and turn_context.has("fallback_district") \
		else (own_city if own_city >= 0 else ai._ai_first_alive_district())
	var focus_product := str(turn_context.get("focus_product", "")) \
		if cache_active and turn_context.has("focus_product") \
		else ai._ai_focus_product(player_index)
	var planned_product := ai._ai_product_for_skill(
		player_index,
		skill,
		turn_context
	)
	var route_plan := turn_context.get("route_plan", {}) as Dictionary \
		if cache_active and turn_context.get("route_plan", {}) is Dictionary \
		else {}
	var route_product := str(route_plan.get("product", "")) \
		if cache_active else ai._ai_route_plan_product(player_index)
	var route_stage := str(route_plan.get("stage", "")) \
		if cache_active else ai._ai_route_plan_stage(player_index)
	turn_context["route_product"] = route_product
	turn_context["route_stage"] = route_stage
	var phase_info := turn_context.get("phase_info", {}) as Dictionary \
		if cache_active and turn_context.get("phase_info", {}) is Dictionary \
		else ai._ai_refresh_game_phase(player_index)
	var endgame_urgency := int(turn_context.get("endgame_urgency", 0)) \
		if cache_active and turn_context.has("endgame_urgency") \
		else ai._ai_endgame_urgency_score(player_index)
	var development_route := ai._card_development_route_id(skill)
	var profile := turn_context.get("profile", {}) as Dictionary \
		if cache_active and turn_context.get("profile", {}) is Dictionary \
		else ai._ai_profile_for_player(player_index)
	var development_route_bias := ai._ai_development_route_bias_from_profile(
		profile,
		development_route
	) if cache_active else ai._ai_development_route_bias(
		player_index,
		development_route
	)
	var focus_score := int(turn_context.get("focus_score", 0)) \
		if cache_active and turn_context.has("focus_score") \
		else ai._ai_focus_score(player_index)
	var strategy := turn_context.get("strategy", {}) as Dictionary \
		if cache_active and turn_context.get("strategy", {}) is Dictionary \
		else {}
	var strategy_intent := str(strategy.get("intent", "")) \
		if cache_active else ai._ai_strategy_intent(player_index)
	var strategy_score := int(strategy.get("score", 0)) \
		if cache_active else ai._ai_strategy_score(player_index)
	var route_plan_score := int(route_plan.get("score", 0)) \
		if cache_active else ai._ai_route_plan_score(player_index)
	var context := {
		"action": "出牌",
		"slot_index": slot_index,
		"card_name": str(skill.get("name", "卡牌")),
		"kind": kind,
		"policy_kind": kind,
		"district": fallback,
		"target_slot": -1,
		"target_player": -1,
		"product": planned_product,
		"focus_product": focus_product,
		"focus_score": focus_score,
		"focus_bonus": 0,
		"strategy_intent": strategy_intent,
		"strategy_score": strategy_score,
		"strategy_bonus": 0,
		"route_plan_product": route_product,
		"route_plan_stage": route_stage,
		"route_plan_score": route_plan_score,
		"route_plan_bonus": 0,
		"route_gap_bonus": 0,
		"route_gap_penalty": 0,
		"route_gap_reason": "",
		"route_gap_field_match": 0,
		"development_route": development_route,
		"development_route_label": ai._development_route_label(
			development_route
		),
		"development_route_bias": development_route_bias,
		"development_route_bonus": 0,
		"game_phase": str(phase_info.get("phase", "midgame")),
		"competitive_posture": str(phase_info.get(
			"posture",
			"contesting"
		)),
		"score_gap_to_leader": int(phase_info.get("gap", 0)),
		"leader_index": int(phase_info.get("leader_index", -1)),
		"endgame_urgency": endgame_urgency,
		"phase_bonus": 0,
		"learning_bonus": 0,
		"selected_card_resolution_id": -1,
		"score": 70 \
			+ maxi(0, int(skill.get("cost", 2))) * 12 \
			+ maxi(1, ai._skill_rank(str(skill.get("name", "")))) * 9,
		"reason": "按卡牌强度、目标价值、GDP份额、路线计划与AI性格评分",
	}

	if _legacy_skill_targets_player(skill):
		var direct_plan := _legacy_direct_player_interaction_plan(
			ai,
			player_index,
			skill
		)
		if direct_plan.is_empty():
			return {}
		var base_direct_score := int(context.get("score", 0))
		context.merge(direct_plan, true)
		context["district"] = rival_city if rival_city >= 0 else fallback
		context["score"] = base_direct_score + int(direct_plan.get("score", 0))
		context["reason"] = str(direct_plan.get(
			"reason",
			"直接互动压制目标玩家｜公开目标但隐藏出牌者"
		))

	if int(context.get("district", -1)) < 0:
		return {}
	var requirement_district := int(context.get("district", -1))
	var requirement_metadata := ai._ai_play_requirement_metadata(
		player_index,
		skill,
		requirement_district
	)
	if not bool(requirement_metadata.get("requirement_satisfied", false)):
		return {}
	context.merge(requirement_metadata, true)
	var product_name := str(context.get("product", ""))
	if focus_product != "" and product_name == focus_product:
		context["focus_bonus"] = int(context.get("focus_bonus", 0)) \
			+ int(ai.AI_ECONOMIC_FOCUS_MATCH_BONUS)
		context["score"] = int(context.get("score", 0)) \
			+ int(context.get("focus_bonus", 0))
	var required := ai._skill_play_flow_required(skill, player_index)
	if required > 0:
		return {}
	var cash_cost := ai._skill_play_cash_cost(skill, player_index)
	if ai._spendable_cash_units(player_index) < cash_cost:
		return {}
	var target_owner := -999
	var context_district := int(context.get("district", -1))
	if context.has("target_owner"):
		target_owner = int(context.get("target_owner", -999))
	elif context_district >= 0 and context_district < ai.districts.size():
		var target_city := ai._district_city(context_district)
		if ai._city_is_active(target_city):
			target_owner = int(target_city.get("owner", -1))

	var strategy_bonus := ai._ai_strategy_bonus_for_candidate(
		player_index,
		kind,
		context_district,
		str(context.get("product", "")),
		target_owner,
		skill,
		turn_context
	)
	if strategy_bonus > 0:
		context["strategy_bonus"] = int(context.get("strategy_bonus", 0)) \
			+ strategy_bonus
		context["score"] = int(context.get("score", 0)) + strategy_bonus
	var route_bonus := ai._ai_route_plan_bonus_for_candidate(
		player_index,
		kind,
		context_district,
		str(context.get("product", "")),
		target_owner,
		skill,
		turn_context
	)
	if route_bonus > 0:
		context["route_plan_bonus"] = int(context.get(
			"route_plan_bonus",
			0
		)) + route_bonus
		context["score"] = int(context.get("score", 0)) + route_bonus
	var route_gap := ai._ai_route_gap_adjustment(
		player_index,
		skill,
		context_district,
		str(context.get("product", "")),
		target_owner,
		turn_context
	)
	var route_gap_bonus := int(route_gap.get("bonus", 0))
	var route_gap_penalty := int(route_gap.get("penalty", 0))
	if route_gap_bonus != 0 or route_gap_penalty != 0:
		context["route_gap_bonus"] = route_gap_bonus
		context["route_gap_penalty"] = route_gap_penalty
		context["route_gap_reason"] = str(route_gap.get("reason", ""))
		context["route_gap_field_match"] = int(route_gap.get("field_match", 0))
		context["score"] = int(context.get("score", 0)) \
			+ route_gap_bonus - route_gap_penalty
		if str(route_gap.get("reason", "")) != "":
			context["reason"] = "%s｜路线缺口:%s +%d/-%d" % [
				str(context.get("reason", "按卡牌策略评分")),
				str(route_gap.get("reason", "")),
				route_gap_bonus,
				route_gap_penalty,
			]
	var development_route_bonus := ai._ai_development_route_bonus_from_profile(
		profile,
		development_route
	) if cache_active else ai._ai_development_route_bonus(
		player_index,
		development_route
	)
	if development_route_bonus != 0:
		context["development_route_bonus"] = development_route_bonus
		context["score"] = int(context.get("score", 0)) \
			+ development_route_bonus
	var phase_bonus := ai._ai_phase_bonus_for_candidate(
		player_index,
		kind,
		context_district,
		str(context.get("product", "")),
		target_owner,
		skill,
		turn_context
	)
	if phase_bonus != 0:
		context["phase_bonus"] = phase_bonus
		context["score"] = int(context.get("score", 0)) + phase_bonus
	var victory_context := turn_context.get("victory_context", {}) as Dictionary \
		if cache_active and turn_context.get("victory_context", {}) is Dictionary \
		else turn_context
	var victory_race := ai._ai_victory_race_bonus_for_candidate(
		player_index,
		kind,
		context_district,
		str(context.get("product", "")),
		target_owner,
		skill,
		victory_context
	)
	var victory_race_bonus := int(victory_race.get("bonus", 0))
	if victory_race_bonus != 0:
		context["victory_race_bonus"] = victory_race_bonus
		context["victory_race_role"] = str(victory_race.get("role", ""))
		context["victory_race_reason"] = str(victory_race.get("reason", ""))
		context["score"] = int(context.get("score", 0)) + victory_race_bonus
		context["reason"] = "%s｜终局竞速+%d:%s" % [
			str(context.get("reason", "按卡牌策略评分")),
			victory_race_bonus,
			str(victory_race.get("reason", "")),
		]
	var generic_bonus := ai._ai_generic_card_effect_score(
		player_index,
		skill,
		context_district,
		str(context.get("product", "")),
		target_owner,
		turn_context
	)
	if generic_bonus != 0:
		context["generic_effect_bonus"] = generic_bonus
		context["score"] = int(context.get("score", 0)) + generic_bonus
	var profile_signature := ai._ai_profile_signature_bonus_for_candidate_with_context(
		player_index,
		kind,
		context_district,
		str(context.get("product", "")),
		target_owner,
		skill,
		turn_context
	)
	var profile_signature_bonus := int(profile_signature.get("bonus", 0))
	if profile_signature_bonus != 0:
		context["profile_signature_bonus"] = profile_signature_bonus
		context["profile_signature_family"] = str(profile_signature.get(
			"family",
			""
		))
		context["profile_signature_route"] = str(profile_signature.get(
			"route",
			""
		))
		context["profile_signature_reason"] = str(profile_signature.get(
			"reason",
			""
		))
		context["score"] = int(context.get("score", 0)) \
			+ profile_signature_bonus
		context["reason"] = "%s｜性格签名+%d:%s" % [
			str(context.get("reason", "按卡牌策略评分")),
			profile_signature_bonus,
			str(profile_signature.get("reason", "")),
		]
	var learning_memory := ai._ai_memory_for_player(player_index) \
		if cache_active else {}
	var learning_bonus := clampi(
		ai._ai_learning_bonus_from_memory(
			learning_memory,
			str(context.get("policy_kind", kind)),
			str(context.get("strategy_intent", "")),
			str(context.get("route_plan_stage", "")),
			str(context.get("product", "")),
			"匿名出牌"
		) + ai._ai_development_route_learning_bonus_from_memory(
			learning_memory,
			development_route
		),
		-int(ai.AI_LEARNING_BONUS_CLAMP),
		int(ai.AI_LEARNING_BONUS_CLAMP)
	)
	if learning_bonus != 0:
		context["learning_bonus"] = learning_bonus
		context["score"] = int(context.get("score", 0)) + learning_bonus
	context["score"] = maxi(1, int(round(float(context.get("score", 0)) \
		* ai._ai_card_kind_bias_from_profile(profile, kind))))
	return context


func _legacy_skill_targets_player(skill: Dictionary) -> bool:
	return str(skill.get("kind", "")) in [
		"player_hand_disrupt",
		"player_hand_steal",
	] or bool(skill.get("target_player_required", false))


func _authoritative_hand_matches_catalog(
	world: WorldSessionState,
	catalog_records: Dictionary
) -> bool:
	var snapshot := world.internal_snapshot()
	var players := snapshot.get("players", []) as Array
	if ACTOR_INDEX < 0 or ACTOR_INDEX >= players.size() \
			or not (players[ACTOR_INDEX] is Dictionary):
		return false
	var slots := (players[ACTOR_INDEX] as Dictionary).get("slots", []) as Array
	if slots.size() != CARD_IDS.size():
		return false
	for slot_index in range(slots.size()):
		if not (slots[slot_index] is Dictionary):
			return false
		var card_id := str(CARD_IDS[slot_index])
		var runtime_card := (slots[slot_index] as Dictionary).duplicate(true)
		if str(runtime_card.get("runtime_instance_id", "")) \
				!= _runtime_instance_id(slot_index):
			return false
		for field in RUNTIME_ONLY_CARD_FIELDS:
			runtime_card.erase(field)
		if runtime_card != catalog_records.get(card_id, {}):
			return false
	return true


func _canonical_facts_from_catalog(record: Dictionary) -> Dictionary:
	var machine := record.get("machine", {}) as Dictionary
	var payload := machine.get("effect_payload", {}) as Dictionary
	return {
		"semantic_interaction_kind_id": str(machine.get("effect_kind", "")),
		"semantic_discard_count": int(payload.get("hand_discard_count", 0)),
		"semantic_steal_count": int(payload.get("hand_steal_count", 0)),
		"semantic_lock_duration_seconds": int(round(float(payload.get(
			"hand_lock_seconds",
			0.0
		)))),
		"semantic_cash_penalty": int(payload.get("target_cash_penalty", 0)),
		"semantic_steal_failure_cash": int(payload.get("steal_fail_cash", 0)),
	}


func _legacy_effective_facts(world_card: Dictionary) -> Dictionary:
	return {
		"policy_interaction_kind_id": str(world_card.get(
			"kind",
			"player_hand_disrupt"
		)),
		"policy_discard_count": int(world_card.get("hand_discard_count", 0)),
		"policy_steal_count": int(world_card.get("hand_steal_count", 0)),
		"policy_lock_duration_microseconds": int(round(float(world_card.get(
			"hand_lock_seconds",
			0.0
		)) * 1000000.0)),
		"policy_cash_penalty": int(world_card.get("target_cash_penalty", 0)),
		"policy_steal_failure_cash": int(world_card.get("steal_fail_cash", 0)),
	}


func _semantic_shape_from_policy(policy_facts: Dictionary) -> Dictionary:
	return {
		"semantic_interaction_kind_id": policy_facts.get(
			"policy_interaction_kind_id"
		),
		"semantic_discard_count": policy_facts.get("policy_discard_count"),
		"semantic_steal_count": policy_facts.get("policy_steal_count"),
		"semantic_lock_duration_seconds": int(round(
			float(policy_facts.get(
				"policy_lock_duration_microseconds",
				0
			)) / 1000000.0
		)),
		"semantic_cash_penalty": policy_facts.get("policy_cash_penalty"),
		"semantic_steal_failure_cash": policy_facts.get(
			"policy_steal_failure_cash"
		),
	}


func _legacy_direct_player_interaction_plan(
	ai: AiRuntimeController,
	player_index: int,
	legacy_skill: Dictionary
) -> Dictionary:
	var target_rows := ai._public_active_target_rows(player_index)
	if ai._public_player_snapshot(player_index).is_empty() \
			or target_rows.is_empty():
		return {}
	var kind := str(legacy_skill.get("kind", "player_hand_disrupt"))
	var leader_index := int(ai._visible_score_leader_entry(player_index).get(
		"player_index",
		-1
	))
	var posture := ai._ai_competitive_posture(player_index)
	var self_estimate := ai._victory_top_n_gdp(player_index)
	var hand_effect_pressure := int(legacy_skill.get(
		"hand_discard_count",
		0
	)) * 118 \
		+ int(legacy_skill.get("hand_steal_count", 0)) * 154 \
		+ int(round(float(legacy_skill.get("hand_lock_seconds", 0.0)) * 4.0)) \
		+ int(float(int(legacy_skill.get("target_cash_penalty", 0))) / 2.0)
	if hand_effect_pressure <= 0:
		hand_effect_pressure = 75
	var receive_pressure := _legacy_actor_private_receive_pressure(
		ai,
		player_index,
		kind,
		legacy_skill
	)
	var best: Dictionary = {}
	var best_score := -999999
	for target_value in target_rows:
		var target := target_value as Dictionary
		var target_index := int(target.get("player_index", -1))
		var public_audit := ai._public_victory_audit_row(target_index)
		var settlement_known := not public_audit.is_empty()
		var settlement := maxi(0, int(public_audit.get(
			"top_n_gdp_per_minute",
			0
		))) if settlement_known else 0
		var settlement_gap := settlement - self_estimate \
			if settlement_known else 0
		var leader_bonus := 0
		if target_index == leader_index and settlement_known:
			leader_bonus = 245 + int(float(
				ai._ai_endgame_urgency_score(player_index)
			) / 2.0)
		var posture_bonus := 0
		if posture == "trailing" and settlement_known:
			posture_bonus = 92 + int(float(maxi(
				0,
				settlement_gap
			)) / 12.0)
		elif posture == "leader":
			posture_bonus = 38
		var score := 90 \
			+ int(float(settlement) / 24.0) \
			+ int(float(maxi(0, settlement_gap)) / 10.0) \
			+ leader_bonus \
			+ posture_bonus \
			+ hand_effect_pressure \
			+ receive_pressure
		score += (
			target_index * 13
			+ player_index * 7
			+ int(ai.business_cycle_count)
		) % 17
		var role := "pressure_high_value_player"
		if target_index == leader_index and settlement_known:
			role = "pressure_leader_hand"
		if score > best_score:
			best_score = score
			best = {
				"policy_kind": "direct_%s" % kind,
				"target_player": target_index,
				"target_owner": target_index,
				"direct_interaction_role": role,
				"direct_interaction_score": score,
				"direct_target_settlement": settlement,
				"direct_target_gap": settlement_gap,
				"direct_target_city_pressure": 0,
				"direct_target_monster_pressure": 0,
				"direct_target_public_audit_known": settlement_known,
				"direct_effect_pressure": hand_effect_pressure,
				"score": score,
				"reason": "直接互动%s｜%s｜估值差%d｜效果压强%d" % [
					ai._interaction_target_label(target_index),
					role,
					settlement_gap,
					hand_effect_pressure,
				],
			}
	return best


func _legacy_actor_private_receive_pressure(
	ai: AiRuntimeController,
	player_index: int,
	kind: String,
	legacy_skill: Dictionary
) -> int:
	if kind != "player_hand_steal" \
			or player_index < 0 \
			or player_index >= ai._public_player_count():
		return 0
	var hand_snapshot := ai._actor_hand_inventory_snapshot(player_index)
	if hand_snapshot.is_empty():
		return 0
	if ai._actor_counted_hand_size(hand_snapshot) \
			< ai._actor_hand_limit(hand_snapshot):
		return 46
	return int(float(maxi(0, int(legacy_skill.get(
		"steal_fail_cash",
		0
	)))) / 3.0) - 32


func _candidate(
	card_id: String,
	slot_index: int,
	plan: Dictionary
) -> Dictionary:
	var candidate := plan.duplicate(true)
	candidate["candidate_id"] = "card-play:%s" % card_id
	candidate["card_id"] = card_id
	candidate["slot_index"] = slot_index
	return candidate


func _observation_identity_matches(
	observation: Dictionary,
	card_id: String,
	instance_id: String,
	slot_index: int
) -> bool:
	var viewer := observation.get("viewer_ref", {}) as Dictionary
	return observation.get("schema_version") \
			== OBSERVATION_SCHEMA.SCHEMA_VERSION \
		and str(observation.get("source_kind", "")) == "own_hand" \
		and str(observation.get("visibility_scope_id", "")) \
			== "actor_private" \
		and int(viewer.get("actor_index", -1)) == ACTOR_INDEX \
		and str(observation.get("card_id", "")) == card_id \
		and str(observation.get("instance_id", "")) == instance_id \
		and int(observation.get("source_slot", -1)) == slot_index \
		and str(observation.get("runtime_readiness_id", "")) \
			== "projection_only"


func _selected_fields(value: Dictionary, fields: Array) -> Dictionary:
	var result: Dictionary = {}
	for field_value in fields:
		var field := str(field_value)
		result[field] = value.get(field)
	return result


func _has_exact_fields(value: Dictionary, fields: Array) -> bool:
	if value.size() != fields.size():
		return false
	for field_value in fields:
		if not value.has(str(field_value)):
			return false
	return true


func _candidate_ids(candidates: Array) -> Array:
	var result: Array = []
	for candidate_value in candidates:
		if candidate_value is Dictionary:
			result.append(str((candidate_value as Dictionary).get(
				"card_id",
				""
			)))
	return result


func _sorted_keys(value: Dictionary) -> Array:
	var result: Array = []
	for key_value in value.keys():
		result.append(str(key_value))
	result.sort()
	return result


func _sorted_strings(values: Array) -> Array:
	var result: Array = []
	for value in values:
		result.append(str(value))
	result.sort()
	return result


func _candidate_membership(candidates: Array) -> Array:
	var result: Array = []
	for candidate_value in candidates:
		if candidate_value is Dictionary:
			result.append(_candidate_identity(candidate_value as Dictionary))
	return result


func _hand_card_ids(hand_snapshot: Dictionary) -> Array:
	var result: Array = []
	var slots := hand_snapshot.get("slots", []) as Array
	for slot_value in slots:
		if slot_value is Dictionary and bool((slot_value as Dictionary).get(
			"occupied",
			false
		)):
			result.append(str((slot_value as Dictionary).get("card_id", "")))
	return result


func _candidate_identity(candidate: Dictionary) -> Dictionary:
	return {
		"slot_index": int(candidate.get("slot_index", -1)),
		"card_name": str(candidate.get("card_name", "")),
		"kind": str(candidate.get("kind", "")),
		"policy_kind": str(candidate.get("policy_kind", "")),
	}


func _candidate_fingerprints(candidates: Array) -> Array:
	var result: Array = []
	for candidate_value in candidates:
		if candidate_value is Dictionary:
			result.append(_canonical_fingerprint(candidate_value))
	return result


func _candidate_slot_indices(candidates: Array) -> Array:
	var result: Array = []
	for candidate_value in candidates:
		if candidate_value is Dictionary:
			result.append(int((candidate_value as Dictionary).get(
				"slot_index",
				-1
			)))
	return result


func _candidate_scores(candidates: Array) -> Array:
	var result: Array = []
	for candidate_value in candidates:
		if candidate_value is Dictionary:
			var candidate := candidate_value as Dictionary
			result.append({
				"slot_index": int(candidate.get("slot_index", -1)),
				"score": int(candidate.get("score", -1)),
				"direct_interaction_score": int(candidate.get(
					"direct_interaction_score",
					0
				)),
				"generic_effect_bonus": int(candidate.get(
					"generic_effect_bonus",
					0
				)),
				"phase_bonus": int(candidate.get("phase_bonus", 0)),
				"profile_signature_bonus": int(candidate.get(
					"profile_signature_bonus",
					0
				)),
			})
	return result


func _canonical_fingerprint(value: Variant) -> String:
	return JSON.stringify(_canonical_variant(value), "", false, true) \
		.sha256_text()


func _canonical_variant(value: Variant) -> Variant:
	if value is Dictionary:
		var dictionary_result: Dictionary = {}
		var keys := _sorted_strings((value as Dictionary).keys())
		for key_value in keys:
			var key := str(key_value)
			dictionary_result[key] = _canonical_variant(
				(value as Dictionary).get(key)
			)
		return dictionary_result
	if value is Array:
		var array_result: Array = []
		for item in value as Array:
			array_result.append(_canonical_variant(item))
		return array_result
	return value


func _present_fields(value: Dictionary, fields: Array) -> Array:
	var result: Array = []
	for field_value in fields:
		var field := str(field_value)
		if value.has(field):
			result.append(field)
	return result


func _actor_private_ai_state(
	world: WorldSessionState,
	actor_index: int
) -> Dictionary:
	var players := world.internal_snapshot().get("players", []) as Array
	if actor_index < 0 or actor_index >= players.size() \
			or not (players[actor_index] is Dictionary):
		return {}
	var actor := players[actor_index] as Dictionary
	return {
		"ai_profile": (actor.get("ai_profile", {}) as Dictionary).duplicate(
			true
		) if actor.get("ai_profile", {}) is Dictionary else {},
		"ai_memory": (actor.get("ai_memory", {}) as Dictionary).duplicate(
			true
		) if actor.get("ai_memory", {}) is Dictionary else {},
	}


func _catalog_fixture_unchanged(
	catalog: CardRuntimeCatalogV06Resource,
	records: Dictionary
) -> bool:
	for card_id_variant in CARD_IDS:
		var card_id := str(card_id_variant)
		if catalog.card_snapshot(card_id) != records.get(card_id, {}):
			return false
	return true


func _not_contains_semantic_save_section(section_ids: Array) -> bool:
	for section_value in section_ids:
		var section_id := str(section_value).to_lower()
		if section_id.contains("semantic") \
				or section_id.contains("observation"):
			return false
	return true


func _counter_delta(
	before: Dictionary,
	after: Dictionary,
	field: String
) -> int:
	return int(after.get(field, -1)) - int(before.get(field, -1))


func _runtime_instance_id(slot_index: int) -> String:
	return "batch1:interaction:instance:%02d" % slot_index


func _elapsed_ms(started_usec: int) -> float:
	return snappedf(
		float(Time.get_ticks_usec() - started_usec) / 1000.0,
		0.001
	)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish(metrics: Dictionary) -> void:
	var duration_ms := _elapsed_ms(_started_usec)
	_expect(duration_ms < 60000.0, "focused parity test stays below 60 seconds")
	if _failures.is_empty():
		print(
			(
				"AI_CARD_INTERACTION_SCORING_PARITY_TEST|status=PASS|checks=%d|"
				+ "failures=0|duration_ms=%.3f|metrics=%s"
			)
			% [_checks, duration_ms, JSON.stringify(metrics)]
		)
		print("AI_CARD_INTERACTION_SCORING_PARITY_COMPLETE")
		quit(0)
		return
	for failure in _failures:
		push_error("AI card interaction scoring parity failed: %s" % failure)
	print(
		(
			"AI_CARD_INTERACTION_SCORING_PARITY_TEST|status=FAIL|checks=%d|"
			+ "failures=%d|duration_ms=%.3f|details=%s|metrics=%s"
		)
		% [
			_checks,
			_failures.size(),
			duration_ms,
			JSON.stringify(_failures),
			JSON.stringify(metrics),
		]
	)
	quit(1)
