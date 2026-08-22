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
const SemanticCatalogResource := preload(
	"res://scripts/cards/card_runtime_catalog_v06_resource.gd"
)
const ACTIVE_CATALOG_PATH := "res://data/v075/v075_combat_active_catalog.json"
const BALANCE_DEFAULTS_PATH := "res://docs/rules/v075_combat_balance_defaults.json"

const MILITARY_CARD_ID := "unit.military.air_superiority_fighter.rank_1"
const MILITARY_CATALOG_CARD_ID := "制空战斗机1"
const MILITARY_CARD_INSTANCE_ID := "fixture:v076:military:private:01"
const SUBMISSION_ID := "stage4.private.military.region.001"

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
		int(_crosswalk_report.get("exact_mapped_count", 0)) == 12
			and int(_crosswalk_report.get("reauthor_required_count", 0)) == 16,
		"the Bench presents twelve exact mappings and sixteen honest gaps"
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
	_expect(coordinator != null and kernel != null and direct_action_owner != null,
		"isolated Bench composes the production coordinator, Kernel, and private Owner")
	if coordinator == null or kernel == null or direct_action_owner == null:
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
	_expect(
		world != null and source != null and capability != null
			and role_catalog != null and catalog != null
			and assets != null and military != null,
		"all inherited Owner dependencies resolve from the real coordinator"
	)
	if (
		world == null or source == null or capability == null
		or role_catalog == null or catalog == null
		or assets == null or military == null
	):
		_finish({})
		return

	var military_card := AuthorizationFixture.runtime_card(
		MILITARY_CARD_ID,
		MILITARY_CARD_INSTANCE_ID
	)
	world.restore({
		"players": AuthorizationFixture._players(role_catalog, [military_card]),
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

	var kernel_config := kernel.configure(7604)
	var owner_config := direct_action_owner.configure_dependencies(
		kernel,
		source,
		catalog,
		assets,
		military
	)
	_expect(
		bool(kernel_config.get("accepted", false))
			and bool(owner_config.get("accepted", false)),
		"the unique private input Owner registers one Kernel domain at tick zero"
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
			and not bool(owner_debug.get("owns_card_catalog", true)),
		"the private Owner exposes no inherited authority surface"
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
	}], 42)
	var request := _region_request(asset_plan)
	var submitted := direct_action_owner.submit_private_military_direct_action(bundle, request)
	_expect(
		bool(submitted.get("accepted", false))
			and not bool(submitted.get("duplicate", true))
			and int(submitted.get("eta_ticks", 0)) > 1
			and int(submitted.get("total_distance_mu", 0)) > 0,
		"the exact private card/action binding submits one future geodesic Kernel command"
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

	var eta_ticks := int(submitted.get("eta_ticks", 0))
	var early := direct_action_owner.settle_completed_submission(SUBMISSION_ID)
	_expect(
		not bool(early.get("accepted", true))
			and military.roster_snapshot(true).size() == 1,
		"the military unit cannot resolve or withdraw before physical ETA"
	)
	var pre_arrival := kernel.advance_ticks(eta_ticks - 1)
	_expect(
		bool(pre_arrival.get("accepted", false))
			and military.roster_snapshot(true).size() == 1
			and (kernel.domain_state(
				V076PrivateDirectActionInputOwnerV1.DOMAIN_ID
			).get("submission_ledger", {}) as Dictionary).is_empty(),
		"no teleport or early mission effect occurs along the geodesic route"
	)
	var arrival := kernel.advance_ticks(1)
	var settled := direct_action_owner.settle_completed_submission(SUBMISSION_ID)
	var domain_state := kernel.domain_state(
		V076PrivateDirectActionInputOwnerV1.DOMAIN_ID
	)
	var ledger := domain_state.get("submission_ledger", {}) as Dictionary
	var entry := ledger.get(SUBMISSION_ID, {}) as Dictionary
	var mission_receipt := entry.get("mission_receipt", {}) as Dictionary
	_expect(
		bool(arrival.get("accepted", false))
			and bool(settled.get("accepted", false))
			and bool(settled.get("withdrawn", false))
			and military.roster_snapshot(true).is_empty(),
		"arrival executes one mission through the existing military Owner, then withdraws"
	)
	_expect(
		str(mission_receipt.get("outcome", "")) == "resolved"
			and str(mission_receipt.get("mission_state_after", "")) == "withdrawn"
			and int(mission_receipt.get("retarget_count", -1)) == 0
			and int(mission_receipt.get("persistent_source_count", -1)) == 0
			and int(mission_receipt.get("bound_action_count", -1)) == 0,
		"V075 mission contract resolves once with no retarget or persistent action"
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
		industry_after == industry_before - 2
			and str(settled.get("asset_outcome", "")) == "consumed",
		"only the existing asset Owner consumes the committed quantity"
	)
	var duplicate_settlement := direct_action_owner.settle_completed_submission(SUBMISSION_ID)
	_expect(
		bool(duplicate_settlement.get("accepted", false))
			and bool(duplicate_settlement.get("duplicate", false))
			and assets.availability_snapshot(
				AuthorizationFixture.AI_ACTOR_INDEX
			) == asset_after,
		"settlement replay cannot consume assets or withdraw twice"
	)
	var final_debug := direct_action_owner.debug_snapshot()
	_expect(
		int(final_debug.get("submission_count", 0)) == 1
			and int(final_debug.get("settlement_count", 0)) == 1
			and int(final_debug.get("collision_count", 0)) == 1
			and int(final_debug.get("public_batch_entry_count", -1)) == 0,
		"private exact-once ledger remains bounded to one isolated submission"
	)
	_finish({
		"eta_ticks": eta_ticks,
		"total_distance_mu": int(submitted.get("total_distance_mu", 0)),
		"route_sha256": str(submitted.get("route_sha256", "")),
		"mission_receipt_fingerprint": str(mission_receipt.get(
			"receipt_fingerprint", ""
		)),
		"kernel_root_command_count": kernel.root_commands().size(),
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
		"speed_mu_per_tick": 50_000,
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
		"私有授权 → Kernel 根命令 → 半边球 ETA → 一次任务 → 撤离\n"
		+ "Crosswalk：28/28 身份 · 12 exact · 16 reauthor\n"
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
