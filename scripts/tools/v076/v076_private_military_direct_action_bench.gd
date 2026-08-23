extends Control
class_name V076PrivateMilitaryDirectActionBench

const AuthorizationFixture := preload(
	"res://scripts/tools/card_semantic_source_authorization_fixture.gd"
)
const RULESET_PROFILE := preload(
	"res://resources/rules/space_syndicate_ruleset_v06.tres"
)
const MilitaryCrosswalk := preload(
	"res://scripts/v076/military/v076_military_card_crosswalk_v1.gd"
)
const MilitaryProfileCatalog := preload(
	"res://scripts/v076/military/v076_military_unit_profile_catalog_v1.gd"
)
const SemanticCatalogResource := preload(
	"res://scripts/cards/card_runtime_catalog_v06_resource.gd"
)
const ReplayRunner := preload(
	"res://scripts/v076/simulation/v076_replay_runner.gd"
)
const DirectActionReducer := preload(
	"res://scripts/v076/direct_action/v076_private_direct_action_reducer_v1.gd"
)
const PublicActionBatchCore := preload(
	"res://scripts/v075/runtime/v075_public_action_batch_core.gd"
)
const FacilityCore := preload(
	"res://scripts/v074/facility/v074_facility_runtime_core.gd"
)
const FacilityDamageIntent := preload(
	"res://scripts/v075/combat/facility_combat_damage_intent_v1.gd"
)
const ACTIVE_CATALOG_PATH := "res://data/v075/v075_combat_active_catalog.json"
const BALANCE_DEFAULTS_PATH := "res://docs/rules/v075_combat_balance_defaults.json"

const MILITARY_CARD_ID := "unit.military.air_superiority_fighter.rank_1"
const MILITARY_CATALOG_CARD_ID := "制空战斗机1"
const MILITARY_CARD_INSTANCE_ID := "fixture:v076:military:private:01"
const MILITARY_MONSTER_CARD_INSTANCE_ID := "fixture:v076:military:private:02"
const SUBMISSION_ID := "stage4.private.military.region.001"
const MONSTER_SUBMISSION_ID := "stage4.private.military.monster.001"
const MONSTER_SOURCE_INSTANCE_ID := "monster.stage4.target.001"
const MONSTER_RUNTIME_UID := 77

@onready var status_label: Label = %StatusLabel
@onready var detail_label: Label = %DetailLabel

var _checks := 0
var _failures: Array[String] = []
var _crosswalk_report: Dictionary = {}


func _ready() -> void:
	call_deferred("_run_bench")


func _run_bench() -> void:
	var semantic_catalog := SemanticCatalogResource.new()
	var semantic_catalog_report := semantic_catalog.reload()
	_expect(bool(semantic_catalog_report.get("valid", false)),
		"the unique V06 semantic source Owner validates")
	_crosswalk_report = MilitaryCrosswalk.new().validate(
		semantic_catalog.catalog_snapshot(),
		_read_json(ACTIVE_CATALOG_PATH),
		_read_json(BALANCE_DEFAULTS_PATH)
	)
	_expect(bool(_crosswalk_report.get("valid", false)),
		"the single read-only military Crosswalk validates")
	_expect(
		int(_crosswalk_report.get("mapping_record_count", 0)) == 28
			and str(_crosswalk_report.get("source_family_rank_coverage", "")) == "7/7",
		"the sealed source set closes at 28 records and seven rank ladders"
	)
	_expect(
		int(_crosswalk_report.get("exact_mapped_count", 0)) == 28
			and int(_crosswalk_report.get("reauthor_required_count", 0)) == 0,
		"all twenty-eight cards bind exactly to the unique Profile Authority"
	)
	_expect(
		int(_crosswalk_report.get("forbidden_mission_token_count", -1)) == 0
			and int(_crosswalk_report.get("mission_fallback_count", -1)) == 0,
		"the Crosswalk contains only authorized missions and no fallback"
	)
	_expect(
		int(_crosswalk_report.get("public_batch_entry_count", -1)) == 0
			and int(_crosswalk_report.get("shared_sushi_track_resolution_count", -1)) == 0,
		"Crosswalk bindings remain private and bypass both shared tracks"
	)
	var coordinator := get_node_or_null(
		"GameRuntimeCoordinator"
	) as GameRuntimeCoordinator
	var kernel := get_node_or_null(
		"V076DeterministicKernel"
	) as V076DeterministicKernel
	var direct_action_owner := get_node_or_null(
		"V076PrivateDirectActionInputOwnerV1"
	) as V076PrivateDirectActionInputOwnerV1
	var eta_owner: Variant = get_node_or_null(
		"V076MilitaryPhysicalEtaOwnerV1"
	)
	var facility_damage_owner: Variant = get_node_or_null("V075RuntimeOwner")
	var damage_pipeline: Variant = coordinator.get_node_or_null(
		"RuntimeCommandPipeline"
	)
	_expect(
		coordinator != null and kernel != null
			and direct_action_owner != null and eta_owner != null
			and facility_damage_owner != null and damage_pipeline != null,
		"isolated Bench composes the existing facility/monster damage sinks with the Kernel owners"
	)
	if coordinator == null or kernel == null \
			or direct_action_owner == null or eta_owner == null \
			or facility_damage_owner == null or damage_pipeline == null:
		_finish({})
		return

	var fixture := AuthorizationFixture.configure_coordinator(
		coordinator,
		"v076.private.direct.action.bench"
	)
	_expect(not fixture.is_empty(),
		"PR65 production authorization fixture configures the real coordinator")
	if fixture.is_empty():
		_finish({})
		return
	var world := fixture.get("world") as WorldSessionState
	var source := fixture.get("source") as CardSemanticSourceAuthorizationPort
	var capability := fixture.get("capability") as AiActorHandInventoryCapability
	var role_catalog := coordinator.get_node_or_null(
		"RoleCatalogRuntimeService"
	) as RoleCatalogRuntimeService
	var catalog := coordinator.get_node_or_null(
		"CardRuntimeCatalogService"
	) as CardRuntimeCatalogService
	var assets := coordinator.get_node_or_null(
		"PlayerManaRuntimeController"
	) as PlayerManaRuntimeController
	var military := coordinator.get_node_or_null(
		"MilitaryRuntimeController"
	) as MilitaryRuntimeController
	var monster := coordinator.get_node_or_null(
		"MonsterRuntimeController"
	) as MonsterRuntimeController
	var mutation_authority := coordinator.get_node_or_null(
		"RuntimePhaseCoordinator/RuntimeSimulationStep/SimulationMutationAuthority"
	) as SimulationMutationAuthority
	_expect(
		world != null and source != null and capability != null
			and role_catalog != null and catalog != null
			and assets != null and military != null
			and monster != null and mutation_authority != null,
		"all inherited Owner dependencies resolve from the real coordinator"
	)
	if (
		world == null or source == null or capability == null
		or role_catalog == null or catalog == null
		or assets == null or military == null
		or monster == null or mutation_authority == null
	):
		_finish({})
		return

	var military_card := AuthorizationFixture.runtime_card(
		MILITARY_CARD_ID,
		MILITARY_CARD_INSTANCE_ID
	)
	var military_monster_card := AuthorizationFixture.runtime_card(
		MILITARY_CARD_ID,
		MILITARY_MONSTER_CARD_INSTANCE_ID
	)
	world.restore({
		"players": AuthorizationFixture._players(
			role_catalog,
			[military_card, military_monster_card]
		),
		"districts": [],
		"game_time": 23.0,
	}, true)
	var bundle := source.authorize_own_hand_card(
		capability,
		AuthorizationFixture.AI_ACTOR_INDEX,
		0,
		"stage4-private-military-source"
	)
	_expect(
		bool(bundle.get("accepted", false))
			and str((bundle.get("instance_decision_state", {}) as Dictionary).get(
				"card_id", ""
			)) == MILITARY_CARD_ID,
		"one exact military card instance is authorized from the actor-private own hand"
	)
	var monster_bundle := source.authorize_own_hand_card(
		capability,
		AuthorizationFixture.AI_ACTOR_INDEX,
		1,
		"stage4-private-military-monster-source"
	)
	_expect(
		bool(monster_bundle.get("accepted", false))
			and str((monster_bundle.get(
				"instance_decision_state", {}
			) as Dictionary).get("instance_id", ""))
				== MILITARY_MONSTER_CARD_INSTANCE_ID,
		"a second exact own-hand instance authorizes the typed monster assault"
	)

	var kernel_config := kernel.configure(7604)
	var profile_authority: Variant = MilitaryProfileCatalog.new()
	var eta_config: Dictionary = eta_owner.configure(profile_authority)
	var facility_fixture := _configure_facility_damage_owner(
		facility_damage_owner
	)
	var owner_config := direct_action_owner.configure_dependencies(
		kernel,
		source,
		catalog,
		assets,
		military,
		profile_authority,
		eta_owner,
		facility_damage_owner,
		damage_pipeline
	)
	_expect(
		bool(kernel_config.get("accepted", false))
			and bool(eta_config.get("accepted", false))
			and not facility_fixture.is_empty()
			and bool(owner_config.get("accepted", false)),
		"Profile, ETA, private input, and existing typed sink ownership compose at tick zero"
	)
	var owner_debug := direct_action_owner.debug_snapshot()
	_expect(
		owner_debug.get("allowed_missions")
			== ["ASSAULT_REGION", "ASSAULT_MONSTER"]
			and int(owner_debug.get("public_batch_entry_count", -1)) == 0
			and int(owner_debug.get("shared_sushi_track_resolution_count", -1)) == 0,
		"mission surface is exactly two private Direct Actions with no public batch"
	)
	_expect(
		not bool(owner_debug.get("owns_tick", true))
			and not bool(owner_debug.get("owns_authority_sequence", true))
			and not bool(owner_debug.get("owns_rng", true))
			and not bool(owner_debug.get("owns_military_unit_state", true))
			and not bool(owner_debug.get("owns_asset_quantity", true))
			and not bool(owner_debug.get("owns_map_topology", true))
			and not bool(owner_debug.get("owns_presentation", true))
			and not bool(owner_debug.get("owns_card_catalog", true))
			and not bool(owner_debug.get("owns_military_profile", true))
			and not bool(owner_debug.get("owns_physical_eta", true))
			and not bool(owner_debug.get("owns_facility_damage", true))
			and not bool(owner_debug.get("owns_monster_damage", true)),
		"the private Owner exposes no inherited authority surface"
	)
	var eta_debug: Dictionary = eta_owner.debug_snapshot()
	_expect(
		bool(eta_debug.get("owns_eta_formula", false))
			and not bool(eta_debug.get("owns_tick", true))
			and not bool(eta_debug.get("owns_map_topology", true))
			and not bool(eta_debug.get("owns_route_geometry", true))
			and not bool(eta_debug.get("owns_military_unit_state", true))
			and not bool(eta_debug.get("owns_asset_quantity", true))
			and not bool(eta_debug.get("owns_card_catalog", true))
			and not bool(eta_debug.get("owns_presentation", true)),
		"the ETA Owner owns only the physical distance-plus-speed formula"
	)

	_fund_assets(assets, AuthorizationFixture.AI_ACTOR_INDEX)
	var asset_before := assets.availability_snapshot(
		AuthorizationFixture.AI_ACTOR_INDEX
	)
	var asset_plan := assets.plan_reservation({
		"transaction_id": "stage4.asset.region.001",
		"player_index": AuthorizationFixture.AI_ACTOR_INDEX,
		"asset_cost": {"industry": 2},
		"generic_asset_allocation": {},
	})
	_expect(bool(asset_plan.get("accepted", false)),
		"the existing six-color asset Owner plans the action reservation")
	military.replace_runtime_state([{
		"uid": 41,
		"owner": AuthorizationFixture.AI_ACTOR_INDEX,
		"name": MILITARY_CATALOG_CARD_ID,
		"military_type": "fighter",
		"position": 0,
		"hp": 5,
		"remaining_time": 30.0,
	}, {
		"uid": 42,
		"owner": AuthorizationFixture.AI_ACTOR_INDEX,
		"name": MILITARY_CATALOG_CARD_ID,
		"military_type": "fighter",
		"position": 0,
		"hp": 5,
		"remaining_time": 30.0,
	}], 43)
	var request := _region_request(asset_plan)
	var submitted := direct_action_owner.submit_private_military_direct_action(bundle, request)
	_expect(
		bool(submitted.get("accepted", false))
			and not bool(submitted.get("duplicate", true))
			and int(submitted.get("eta_ticks", 0)) > 1
			and int(submitted.get("dispatch_delay_ticks", 0)) \
			== int(submitted.get("eta_ticks", -1))
			and int(submitted.get("total_distance_mu", 0)) > 0
			and str(submitted.get("eta_receipt_fingerprint", "")).length() == 64,
		"the exact private card/action binding submits one future geodesic Kernel command (%s)"
			% str(submitted.get("reason", ""))
	)
	var duplicate_submission := direct_action_owner.submit_private_military_direct_action(bundle, request)
	_expect(
		bool(duplicate_submission.get("accepted", false))
			and bool(duplicate_submission.get("duplicate", false))
			and kernel.root_commands().size() == 1,
		"exact replay is acknowledged without a second root command or reservation"
	)
	var collision_request := request.duplicate(true)
	collision_request["target_face_id"] = int(request.get("target_face_id", 0)) + 1
	var collision := direct_action_owner.submit_private_military_direct_action(
		bundle,
		collision_request
	)
	_expect(
		not bool(collision.get("accepted", true))
			and str(collision.get("reason", ""))
				== "private_direct_action_submission_collision",
		"same submission identity with a different route target fails closed"
	)
	var guard_request := request.duplicate(true)
	guard_request["submission_id"] = "stage4.private.military.guard.forbidden"
	guard_request["mission_kind"] = "GUARD"
	var guard := direct_action_owner.submit_private_military_direct_action(bundle, guard_request)
	var protect_request := guard_request.duplicate(true)
	protect_request["submission_id"] = "stage4.private.military.protect.forbidden"
	protect_request["mission_kind"] = "PROTECT"
	var protect := direct_action_owner.submit_private_military_direct_action(
		bundle,
		protect_request
	)
	_expect(
		not bool(guard.get("accepted", true))
			and not bool(protect.get("accepted", true))
			and kernel.root_commands().size() == 1,
		"GUARD and PROTECT never enter the Kernel"
	)
	var monster_prepared := _prepare_monster_sink_slice(
		monster_bundle,
		assets,
		monster,
		direct_action_owner
	)
	_expect(
		bool(monster_prepared.get("accepted", false))
			and kernel.root_commands().size() == 2,
		"the same authority tick receives one region root and one monster root in stable producer order"
	)

	var eta_ticks := int(submitted.get("eta_ticks", 0))
	var dispatch_delay_ticks := int(submitted.get("dispatch_delay_ticks", 0))
	var early := direct_action_owner.settle_completed_submission(SUBMISSION_ID)
	_expect(
		not bool(early.get("accepted", true))
			and military.roster_snapshot(true).size() == 2,
		"the military unit cannot resolve or withdraw before physical ETA"
	)
	var pre_arrival := kernel.advance_ticks(dispatch_delay_ticks - 1)
	_expect(
		bool(pre_arrival.get("accepted", false))
			and military.roster_snapshot(true).size() == 2
			and (kernel.domain_state(
				V076PrivateDirectActionInputOwnerV1.DOMAIN_ID
			).get("submission_ledger", {}) as Dictionary).is_empty(),
		"no teleport or early mission effect occurs along the geodesic route"
	)
	var arrival := kernel.advance_ticks(1)
	var arrival_state := kernel.domain_state(
		V076PrivateDirectActionInputOwnerV1.DOMAIN_ID
	)
	var arrival_entry := ((arrival_state.get(
		"submission_ledger", {}
	) as Dictionary).get(SUBMISSION_ID, {}) as Dictionary)
	var arrival_settlement := direct_action_owner.settle_completed_submission(
		SUBMISSION_ID
	)
	_expect(
		bool(arrival.get("accepted", false))
			and str(arrival_entry.get("phase", ""))
				== DirectActionReducer.PHASE_ARRIVED
			and int(arrival_entry.get("arrival_tick", -1))
				== int(submitted.get("scheduled_tick", -2))
			and (arrival_entry.get("mission_receipt", {}) as Dictionary).is_empty()
			and not bool(arrival_settlement.get("accepted", true))
			and military.roster_snapshot(true).size() == 2,
		"the exact ETA tick records ARRIVED without attacking or withdrawing"
	)
	var execution := kernel.advance_ticks(1)
	var execution_state := kernel.domain_state(
		V076PrivateDirectActionInputOwnerV1.DOMAIN_ID
	)
	var execution_entry := ((execution_state.get(
		"submission_ledger", {}
	) as Dictionary).get(SUBMISSION_ID, {}) as Dictionary)
	var execution_settlement := direct_action_owner.settle_completed_submission(
		SUBMISSION_ID
	)
	var mission_receipt := execution_entry.get(
		"mission_receipt", {}
	) as Dictionary
	_expect(
		bool(execution.get("accepted", false))
			and str(execution_entry.get("phase", ""))
				== DirectActionReducer.PHASE_EXECUTED_ONCE
			and int(execution_entry.get("execution_count", 0)) == 1
			and int(execution_entry.get("execution_tick", -1))
				== int(submitted.get("scheduled_tick", -2)) + 1
			and not bool(execution_settlement.get("accepted", true))
			and military.roster_snapshot(true).size() == 2,
		"the next Kernel tick executes exactly one locked assault and cannot settle early"
	)
	var withdrawal := kernel.advance_ticks(1)
	var domain_state := kernel.domain_state(
		V076PrivateDirectActionInputOwnerV1.DOMAIN_ID
	)
	var ledger := domain_state.get("submission_ledger", {}) as Dictionary
	var entry := ledger.get(SUBMISSION_ID, {}) as Dictionary
	var settled := direct_action_owner.settle_completed_submission(SUBMISSION_ID)
	mission_receipt = entry.get("mission_receipt", {}) as Dictionary
	var damage_settlement := settled.get("damage_settlement", {}) as Dictionary
	_expect(
		bool(withdrawal.get("accepted", false))
			and str(entry.get("phase", ""))
				== DirectActionReducer.PHASE_WITHDRAWAL_READY
			and int(entry.get("withdrawal_intent_count", 0)) == 1
			and bool(settled.get("accepted", false))
			and bool(settled.get("withdrawn", false))
			and military.roster_snapshot(true).size() == 1,
		"the third lifecycle tick emits one withdrawal intent, then the existing unit Owner removes the unit"
	)
	var facility_after := _facility_by_id(
		facility_damage_owner,
		"facility.factory.stage4.target"
	)
	_expect(
		int(damage_settlement.get("facility_intent_count", 0)) == 1
			and int((damage_settlement.get(
				"facility_receipts", []
			) as Array).size()) == 1
			and int(facility_after.get("damage_points", -1))
				== int((facility_fixture.get("facility", {}) as Dictionary).get(
					"damage_points", -2
				)) + int(mission_receipt.get("allocated_damage_total", 0))
			and int(damage_settlement.get("direct_reducer_mutation_count", -1)) == 0,
		"typed facility intent commits exactly once through V075RuntimeOwner with no reducer mutation"
	)
	_expect(
		str(mission_receipt.get("outcome", "")) == "resolved"
			and str(mission_receipt.get("mission_state_after", "")) == "withdrawn"
			and int(mission_receipt.get("allocated_damage_total", 0))
				== int((MilitaryProfileCatalog.new().profile_by_id(
					str(submitted.get("profile_id", ""))
				).get("assault_region_profile", {}) as Dictionary).get(
					"damage_budget", -1
				))
			and int(mission_receipt.get("retarget_count", -1)) == 0
			and int(mission_receipt.get("persistent_source_count", -1)) == 0
			and int(mission_receipt.get("bound_action_count", -1)) == 0,
		"the V075 mission contract emits Profile-authored damage once with no retarget or persistence"
	)
	var asset_after := assets.availability_snapshot(
		AuthorizationFixture.AI_ACTOR_INDEX
	)
	var industry_before := int((asset_before.get("assets", {}) as Dictionary).get(
		"industry", -1
	))
	var industry_after := int((asset_after.get("assets", {}) as Dictionary).get(
		"industry", -1
	))
	_expect(
		industry_after == industry_before - 4
			and str(settled.get("asset_outcome", "")) == "consumed",
		"only the existing asset Owner reserves both actions and consumes the completed region quantity"
	)
	var duplicate_settlement := direct_action_owner.settle_completed_submission(SUBMISSION_ID)
	var facility_after_replay := _facility_by_id(
		facility_damage_owner,
		"facility.factory.stage4.target"
	)
	_expect(
		bool(duplicate_settlement.get("accepted", false))
			and bool(duplicate_settlement.get("duplicate", false))
			and assets.availability_snapshot(
				AuthorizationFixture.AI_ACTOR_INDEX
			) == asset_after
			and facility_after_replay == facility_after,
		"settlement replay cannot damage, consume assets, or withdraw twice"
	)
	var before_tamper_assets := assets.availability_snapshot(
		AuthorizationFixture.AI_ACTOR_INDEX
	)
	var kernel_states := (kernel.get("_domain_states") as Dictionary).duplicate(true)
	var tampered_states := kernel_states.duplicate(true)
	var tampered_domain := (tampered_states.get(
		V076PrivateDirectActionInputOwnerV1.DOMAIN_ID, {}
	) as Dictionary).duplicate(true)
	var tampered_ledger := (tampered_domain.get(
		"submission_ledger", {}
	) as Dictionary).duplicate(true)
	var tampered_entry := (tampered_ledger.get(SUBMISSION_ID, {}) as Dictionary).duplicate(true)
	var tampered_receipt := (tampered_entry.get(
		"mission_receipt", {}
	) as Dictionary).duplicate(true)
	tampered_receipt["allocated_damage_total"] = int(tampered_receipt.get(
		"allocated_damage_total", 0
	)) + 1
	tampered_entry["mission_receipt"] = tampered_receipt
	tampered_ledger[SUBMISSION_ID] = tampered_entry
	tampered_domain["submission_ledger"] = tampered_ledger
	tampered_states[V076PrivateDirectActionInputOwnerV1.DOMAIN_ID] = tampered_domain
	kernel.set("_domain_states", tampered_states)
	var tampered_settlement := direct_action_owner.settle_completed_submission(
		SUBMISSION_ID
	)
	kernel.set("_domain_states", kernel_states)
	_expect(
		not bool(tampered_settlement.get("accepted", true))
			and str(tampered_settlement.get("reason", ""))
				== "private_direct_action_mission_receipt_invalid"
			and _facility_by_id(
				facility_damage_owner,
				"facility.factory.stage4.target"
			) == facility_after
			and assets.availability_snapshot(
				AuthorizationFixture.AI_ACTOR_INDEX
			) == before_tamper_assets,
		"a tampered mission receipt fails before any sink, asset, or unit mutation"
	)
	var missing_intent := FacilityDamageIntent.build(
		"effect.stage4.private.military.missing-target",
		"facility.stage4.missing",
		1,
		1,
		"military_region_assault",
		"combat.stage4.missing-target"
	)
	var missing_first := facility_damage_owner.call(
		"consume_v076_military_facility_damage_intents",
		[missing_intent]
	) as Dictionary
	var missing_replay := facility_damage_owner.call(
		"consume_v076_military_facility_damage_intents",
		[missing_intent]
	) as Dictionary
	var missing_receipts := missing_first.get("receipts", []) as Array
	_expect(
		bool(missing_first.get("accepted", false))
			and missing_receipts.size() == 1
			and not bool((missing_receipts[0] as Dictionary).get(
				"accepted", true
			))
			and int((missing_receipts[0] as Dictionary).get(
				"applied_damage", -1
			)) == 0
			and str((missing_receipts[0] as Dictionary).get(
				"reason_code", ""
			)) == "facility_combat_damage_target_missing"
			and bool(missing_replay.get("duplicate", false))
			and _facility_by_id(
				facility_damage_owner,
				"facility.factory.stage4.target"
			) == facility_after,
		"a missing typed facility target commits one zero-damage fizzle and replays without retarget"
	)
	var lifecycle_before_idle := kernel.domain_state(
		V076PrivateDirectActionInputOwnerV1.DOMAIN_ID
	)
	var idle_advance := kernel.advance_ticks(3)
	var lifecycle_after_idle := kernel.domain_state(
		V076PrivateDirectActionInputOwnerV1.DOMAIN_ID
	)
	_expect(
		bool(idle_advance.get("accepted", false))
			and lifecycle_after_idle == lifecycle_before_idle
			and kernel.execution_log().size() == 6,
		"no attack, retarget, repeat, or second withdrawal occurs after withdrawal"
	)
	var replay_envelope := kernel.build_replay_recipe()
	var replay := ReplayRunner.new().verify(
		replay_envelope.get("recipe", {}) as Dictionary,
		str(replay_envelope.get("recipe_sha256", "")),
		{V076PrivateDirectActionInputOwnerV1.DOMAIN_ID: DirectActionReducer}
	)
	_expect(
		str(replay.get("status", "")) == "PASS"
			and int(replay.get("root_command_count", -1)) == 2
			and int(replay.get("derived_command_count", -1)) == 4,
		"root-only replay regenerates the exact execute and withdrawal lineage"
	)
	var monster_slice := _run_monster_sink_slice(
		monster_prepared,
		assets,
		military,
		monster,
		mutation_authority,
		kernel,
		direct_action_owner
	)
	var final_debug := direct_action_owner.debug_snapshot()
	_expect(
		int(final_debug.get("submission_count", 0)) == 2
			and int(final_debug.get("settlement_count", 0)) == 2
			and int(final_debug.get("damage_settlement_count", 0)) == 2
			and int(final_debug.get("collision_count", 0)) == 1
			and int(final_debug.get("public_batch_entry_count", -1)) == 0,
		"private exact-once ledger remains bounded to one isolated submission"
	)
	_finish({
		"eta_ticks": eta_ticks,
		"dispatch_delay_ticks": dispatch_delay_ticks,
		"eta_receipt_fingerprint": str(submitted.get(
			"eta_receipt_fingerprint", ""
		)),
		"profile_id": str(submitted.get("profile_id", "")),
		"total_distance_mu": int(submitted.get("total_distance_mu", 0)),
		"route_sha256": str(submitted.get("route_sha256", "")),
		"mission_receipt_fingerprint": str(mission_receipt.get(
			"receipt_fingerprint", ""
		)),
		"facility_damage_receipt_count": int((damage_settlement.get(
			"facility_receipts", []
		) as Array).size()),
		"monster_damage_receipt_count": int(monster_slice.get(
			"monster_damage_receipt_count", 0
		)),
		"monster_hp_before": int(monster_slice.get("hp_before", -1)),
		"monster_hp_after": int(monster_slice.get("hp_after", -1)),
		"arrival_tick": int(entry.get("arrival_tick", -1)),
		"execution_tick": int(entry.get("execution_tick", -1)),
		"withdrawal_ready_tick": int(entry.get("withdrawal_ready_tick", -1)),
		"lifecycle_phase": str(entry.get("phase", "")),
		"lifecycle_transition_order": (entry.get(
			"transition_order", []
		) as Array).duplicate(),
		"kernel_root_command_count": kernel.root_commands().size(),
		"kernel_derived_command_count": kernel.derived_commands().size(),
		"kernel_execution_count": kernel.execution_log().size(),
		"public_batch_entry_count": 0,
		"shared_sushi_track_resolution_count": 0,
		"production_green": false,
		"human_green": false,
	})


func _region_request(asset_plan: Dictionary) -> Dictionary:
	return {
		"schema_version": 1,
		"submission_id": SUBMISSION_ID,
		"actor_id": "player.%d" % AuthorizationFixture.AI_ACTOR_INDEX,
		"mission_kind": "ASSAULT_REGION",
		"military_unit_uid": 41,
		"catalog_card_id": MILITARY_CATALOG_CARD_ID,
		"card_instance_id": MILITARY_CARD_INSTANCE_ID,
		"action_slot_id": "action.slot.stage4.private.001",
		"asset_reservation_plan": asset_plan.duplicate(true),
		"source_face_id": 0,
		"target_face_id": 137,
		"target_region_id": "region.007",
		"target_monster_source_instance_id": "",
		"target_region_revision": 14,
		"public_targets": [{
			"facility_id": "facility.factory.stage4.target",
			"facility_generation": 1,
			"owner_player_id": "player.2",
			"region_id": "region.007",
			"facility_type": "factory",
			"industry_id": "energy",
			"status": "active",
		}],
		"source_effect_id": "effect.stage4.private.military.001",
		"producer_sequence": 1,
	}


func _run_monster_sink_slice(
	prepared: Dictionary,
	assets: PlayerManaRuntimeController,
	military: MilitaryRuntimeController,
	monster: MonsterRuntimeController,
	mutation_authority: SimulationMutationAuthority,
	kernel: V076DeterministicKernel,
	direct_action_owner: V076PrivateDirectActionInputOwnerV1
) -> Dictionary:
	if not bool(prepared.get("accepted", false)):
		return {}
	var state := kernel.domain_state(
		V076PrivateDirectActionInputOwnerV1.DOMAIN_ID
	)
	var entry := ((state.get("submission_ledger", {}) as Dictionary).get(
		MONSTER_SUBMISSION_ID,
		{}
	) as Dictionary)
	var hp_before := int(monster.simulation_mutation_snapshot_by_uid(
		MONSTER_RUNTIME_UID
	).get("hp", -1))
	var outside_step := direct_action_owner.settle_completed_submission(
		MONSTER_SUBMISSION_ID
	)
	_expect(
		str(entry.get("phase", ""))
				== DirectActionReducer.PHASE_WITHDRAWAL_READY
			and not bool(outside_step.get("accepted", true))
			and str(outside_step.get("reason", "")).contains(
				"outside_active_step"
			)
			and int(monster.simulation_mutation_snapshot_by_uid(
				MONSTER_RUNTIME_UID
			).get("hp", -2)) == hp_before,
		"the existing mutation authority rejects monster damage outside its active step"
	)
	var opened := mutation_authority.begin_step(
		int(entry.get("execution_tick", 0))
	)
	var settled := direct_action_owner.settle_completed_submission(
		MONSTER_SUBMISSION_ID
	)
	var closed := mutation_authority.end_step()
	var damage_settlement := settled.get("damage_settlement", {}) as Dictionary
	var monster_receipts := damage_settlement.get(
		"monster_receipts", []
	) as Array
	var hp_after := int(monster.simulation_mutation_snapshot_by_uid(
		MONSTER_RUNTIME_UID
	).get("hp", -1))
	_expect(
		bool(opened.get("opened", false))
			and bool(settled.get("accepted", false))
			and str(settled.get("asset_outcome", "")) == "consumed"
			and bool(closed.get("closed", false))
			and int(damage_settlement.get("monster_intent_count", 0)) == 1
			and monster_receipts.size() == 1
			and hp_after < hp_before
			and military.roster_snapshot(true).is_empty()
			and int((monster_receipts[0] as Dictionary).get(
				"applied_damage", 0
			)) == hp_before - hp_after,
		"typed monster intent commits exactly once through Pipeline and MonsterRuntimeController"
	)
	var roster_after := military.roster_snapshot(true)
	var assets_after := assets.availability_snapshot(
		AuthorizationFixture.AI_ACTOR_INDEX
	)
	var replayed := direct_action_owner.settle_completed_submission(
		MONSTER_SUBMISSION_ID
	)
	_expect(
		bool(replayed.get("accepted", false))
			and bool(replayed.get("duplicate", false))
			and int(monster.simulation_mutation_snapshot_by_uid(
				MONSTER_RUNTIME_UID
			).get("hp", -1)) == hp_after
			and military.roster_snapshot(true) == roster_after
			and assets.availability_snapshot(
				AuthorizationFixture.AI_ACTOR_INDEX
			) == assets_after,
		"monster settlement replay cannot damage, consume assets, or withdraw twice"
	)
	var replay_envelope := kernel.build_replay_recipe()
	var replay := ReplayRunner.new().verify(
		replay_envelope.get("recipe", {}) as Dictionary,
		str(replay_envelope.get("recipe_sha256", "")),
		{V076PrivateDirectActionInputOwnerV1.DOMAIN_ID: DirectActionReducer}
	)
	_expect(
		str(replay.get("status", "")) == "PASS"
			and int(replay.get("root_command_count", -1)) == 2
			and int(replay.get("derived_command_count", -1)) == 4,
		"both typed sink missions retain root-only Kernel replay parity: %s"
			% JSON.stringify(replay)
	)
	return {
		"monster_damage_receipt_count": monster_receipts.size(),
		"hp_before": hp_before,
		"hp_after": hp_after,
	}


func _prepare_monster_sink_slice(
	bundle: Dictionary,
	assets: PlayerManaRuntimeController,
	monster: MonsterRuntimeController,
	direct_action_owner: V076PrivateDirectActionInputOwnerV1
) -> Dictionary:
	var asset_plan := assets.plan_reservation({
		"transaction_id": "stage4.asset.monster.001",
		"player_index": AuthorizationFixture.AI_ACTOR_INDEX,
		"asset_cost": {"industry": 2},
		"generic_asset_allocation": {},
	})
	_expect(bool(asset_plan.get("accepted", false)),
		"the asset Owner plans the monster-assault reservation")
	var monster_bridge := monster.get("_world_bridge") as MonsterRuntimeWorldBridge
	if monster_bridge == null and monster.get_parent() != null:
		monster_bridge = monster.get_parent().get_node_or_null(
			"MonsterRuntimeWorldBridge"
		) as MonsterRuntimeWorldBridge
	if monster_bridge != null:
		monster_bridge.bind_world(self)
		monster.set_world_bridge(monster_bridge)
	monster.set("auto_monsters", [{
		"uid": MONSTER_RUNTIME_UID,
		"slot": 0,
		"catalog_index": 0,
		"name": "Stage4Target",
		"rank": 1,
		"hp": 20,
		"max_hp": 20,
		"armor": 0,
		"down": false,
		"owner": 2,
		"owner_revealed": false,
		"owner_damage_cash_pool": 0,
		"owner_damage_cash_lost": 0,
		"position": 0,
		"world_position": Vector2.ZERO,
	}])
	var submitted := direct_action_owner.submit_private_military_direct_action(
		bundle,
		_monster_request(asset_plan)
	)
	_expect(
		bool(submitted.get("accepted", false))
			and int(submitted.get("eta_ticks", 0)) > 1,
		"the second private root binds one typed monster target and physical ETA"
	)
	return {
		"accepted": bool(submitted.get("accepted", false)),
		"submitted": submitted.duplicate(true),
	}


func _entity_world_position(entity: Dictionary) -> Vector2:
	var value: Variant = entity.get("world_position", Vector2.ZERO)
	return value if value is Vector2 else Vector2.ZERO


func _monster_request(asset_plan: Dictionary) -> Dictionary:
	return {
		"schema_version": 1,
		"submission_id": MONSTER_SUBMISSION_ID,
		"actor_id": "player.%d" % AuthorizationFixture.AI_ACTOR_INDEX,
		"mission_kind": "ASSAULT_MONSTER",
		"military_unit_uid": 42,
		"catalog_card_id": MILITARY_CATALOG_CARD_ID,
		"card_instance_id": MILITARY_MONSTER_CARD_INSTANCE_ID,
		"action_slot_id": "action.slot.stage4.private.002",
		"asset_reservation_plan": asset_plan.duplicate(true),
		"source_face_id": 0,
		"target_face_id": 137,
		"target_region_id": "",
		"target_monster_source_instance_id": MONSTER_SOURCE_INSTANCE_ID,
		"target_region_revision": 0,
		"public_targets": [{
			"source_instance_id": MONSTER_SOURCE_INSTANCE_ID,
			"source_generation": 1,
			"source_revision": 4,
			"owner_player_id": "player.2",
			"region_id": "region.007",
			"status": "active",
			"runtime_monster_uid": MONSTER_RUNTIME_UID,
		}],
		"source_effect_id": "effect.stage4.private.military.002",
		"producer_sequence": 2,
	}


func _configure_facility_damage_owner(owner: Object) -> Dictionary:
	var facility := FacilityCore.build_occupied_slot(
		"region.007",
		14,
		"factory",
		"energy",
		1,
		"facility.factory.stage4.target",
		1,
		"player.2",
		4,
		0,
		0,
		"sunlit"
	)
	var state := PublicActionBatchCore.lock_batch(
		"batch.v076.stage4.damage-sink.001",
		["player.1", "player.2"],
		["player.1", "player.2"],
		{"player.1": [], "player.2": []},
		[facility]
	)
	if state.is_empty():
		return {}
	owner.set("_facility_state", state.duplicate(true))
	owner.call("_sync_facility_slots")
	return {"state": state, "facility": facility}


func _facility_by_id(owner: Object, facility_id: String) -> Dictionary:
	for row_variant in owner.call("_public_occupied_facilities") as Array:
		if row_variant is Dictionary \
				and str((row_variant as Dictionary).get("facility_id", "")) == facility_id:
			return (row_variant as Dictionary).duplicate(true)
	return {}


func _fund_assets(
	assets: PlayerManaRuntimeController,
	player_index: int
) -> void:
	if not bool(assets.public_snapshot().get("valid", false)):
		assets.configure(RULESET_PROFILE.debug_snapshot())
	assets.availability_snapshot(player_index)
	var save := assets.to_save_data()
	var pools := save.get("pools_by_player", {}) as Dictionary
	var player_pool := pools.get(str(player_index), {}) as Dictionary
	for asset_id in PlayerManaRuntimeController.ASSET_IDS:
		player_pool[str(asset_id)] = 5_000
	pools[str(player_index)] = player_pool
	save["pools_by_player"] = pools
	assets.apply_save_data(save)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}


func _finish(evidence: Dictionary) -> void:
	var passed := _failures.is_empty()
	status_label.text = "PASS · Stage 4 isolated" if passed else "FAIL · Stage 4 isolated"
	status_label.modulate = Color("#86efac") if passed else Color("#fca5a5")
	detail_label.text = (
		"私有授权 → 物理 ETA → 到达 → 攻击一次 → 撤离\n"
		+ "Crosswalk：28/28 exact · 0 reauthor · Profile 权威唯一\n"
		+ "允许：ASSAULT_REGION / ASSAULT_MONSTER · 公共批次=0\n"
		+ "checks=%d  failures=%d  production=false  human=false"
		% [_checks, _failures.size()]
	)
	var result := evidence.duplicate(true)
	result["military_card_total_count"] = int(
		_crosswalk_report.get("mapping_record_count", 0)
	)
	result["military_card_exact_mapping_count"] = int(
		_crosswalk_report.get("exact_mapped_count", 0)
	)
	result["military_card_reauthor_required_count"] = int(
		_crosswalk_report.get("reauthor_required_count", 0)
	)
	result["crosswalk_status"] = str(_crosswalk_report.get("status", "INVALID"))
	result["crosswalk_fingerprint_sha256"] = str(
		_crosswalk_report.get("crosswalk_fingerprint_sha256", "")
	)
	result["status"] = "PASS" if passed else "FAIL"
	result["check_count"] = _checks
	result["failure_count"] = _failures.size()
	result["failures"] = _failures.duplicate()
	result["scene"] = "res://scenes/tools/v076/V076PrivateMilitaryDirectActionBench.tscn"
	result["golden_step"] = "STEP10"
	result["golden_status"] = "ISOLATED_GREEN" if passed else "PENDING"
	print("V076_PRIVATE_MILITARY_DIRECT_ACTION_BENCH|%s" % JSON.stringify(result))
	var hold_seconds := 0.2 if DisplayServer.get_name() == "headless" else 30.0
	await get_tree().create_timer(hold_seconds).timeout
	get_tree().quit(0 if passed else 1)
