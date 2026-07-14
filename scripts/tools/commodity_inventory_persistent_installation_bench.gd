extends Control
class_name CommodityInventoryPersistentInstallationBench

const OUTPUT_DIR := "user://space_syndicate_design_qa/commodity_inventory_persistent_installation/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/commodity_inventory_persistent_installation_sprint_6.png"
const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")
const FLOW_SCENE := preload("res://scenes/runtime/CommodityFlowRuntimeController.tscn")
const RULESET_V04 := preload("res://resources/rules/space_syndicate_ruleset_v04.tres")
const RULESET_V06 := preload("res://resources/rules/space_syndicate_ruleset_v06.tres")
const PRODUCT_CATALOG := preload("res://resources/content/product_industry_catalog_v05.tres")
const CARD_FLOW_TRANSACTION_SCRIPT := preload("res://scripts/cards/v06/card_flow_transaction_service_v06.gd")
const GLOBAL_SUPPLY_DEMAND_OWNER_SCRIPT := preload("res://scripts/cards/v06/effects/global_supply_demand_runtime_service_v06.gd")
const GLOBAL_SUPPLY_DEMAND_ADAPTER_SCRIPT := preload("res://scripts/cards/v06/effects/global_supply_demand_card_effect_adapter_v06.gd")
const CORE_EFFECT_ROUTER_SCRIPT := preload("res://scripts/cards/v06/production/core_economic_card_effect_router_v06.gd")
const FLOW_BATCH_SINK_SCRIPT := preload("res://scripts/cards/v06/production/commodity_flow_atomic_batch_sink_v06.gd")

const CASE_IDS := [
	"controller_scene_composition",
	"consumed_card_flow_api_ready",
	"production_state_adapter_single_mutation_owner",
	"legacy_state_bridge_absent",
	"v06_catalog_real",
	"free_belt_claim",
	"free_claim_cash_unchanged",
	"under_limit_duplicate_remains_separate",
	"full_hand_auto_merge_exactly_one",
	"full_hand_no_match_atomic_reject",
	"rank_iv_full_hand_reject",
	"failed_claim_keeps_source",
	"manual_merge_success",
	"manual_merge_invalid_atomic",
	"market_api_ready",
	"market_purchase_atomic_cash_inventory",
	"market_purchase_replay_exact_once",
	"generic_manual_merge_non_commodity",
	"generic_play_port_ready",
	"facility_effect_fail_closed_until_atomic_rollback",
	"transaction_journal_save_covered",
	"play_same_color_factory",
	"cross_owner_install_preserved",
	"card_consumed_after_effect_commit",
	"wrong_color_target_atomic_reject",
	"inactive_target_atomic_reject",
	"rate_rank_i_10",
	"rate_rank_ii_20",
	"rate_rank_iii_40",
	"rate_rank_iv_80",
	"installation_persistent_save_round_trip",
	"installation_deactivates_on_facility_destroyed",
	"authoritative_candidate_snapshot_ready",
	"candidate_lineage_preserved",
	"current_route_enumeration_not_receipt_lineage",
	"batch_snapshot_binding_enforced",
	"shared_capacity_aggregate_enforced",
	"extra_demand_lineage_constrained",
	"rollback_binding_precedes_replay",
	"finalized_batch_rollback_closed",
	"global_supply_demand_outer_finalize_closed",
	"saved_batch_binding_validated",
	"operation_replay_exact_once",
	"player_state_adapter_save_owner_stable",
	"pure_data_snapshots",
	"public_installation_hides_installer",
	"viewer_belt_visibility_not_owned",
	"v06_state_route_avoids_legacy_receive",
	"no_parallel_card_flow_implementation",
]

const LIFE_CARD_IDS := [
	"commodity.star_dew_berry.rank_1",
	"commodity.lunar_soil_grape.rank_1",
	"commodity.spore_silk.rank_1",
	"commodity.photosynthetic_gel.rank_1",
	"commodity.orbital_bonsai.rank_1",
]

@onready var runtime_host: Node = %RuntimeHost
@onready var status_label: Label = %StatusLabel
@onready var ownership_text: RichTextLabel = %OwnershipText
@onready var cases_text: RichTextLabel = %CasesText

var _records: Array = []
var _failures: Array[String] = []
var _coordinator: GameRuntimeCoordinator
var _world: RuntimeWorld
var _controller: CommodityCardInventoryRuntimeController
var _state_adapter: CardPlayerStateProductionAdapterV06
var _core_economic_adapter: CoreEconomicCardRuntimeAdapterV06
var _flow: CommodityFlowRuntimeController
var _infrastructure: RegionInfrastructureRuntimeController
var _catalog: Resource
var _life_facility_id := ""
var _energy_facility_id := ""


class RuntimeWorld:
	extends Node
	var players: Array = []
	var game_time := 0.0


class FlowFactsBridge:
	extends Node
	var facts: Dictionary = {}
	var receipt_batches: Array = []
	var applied_batch_ids: Dictionary = {}

	func capture_flow_facts() -> Dictionary:
		return facts.duplicate(true)

	func apply_sale_receipt_batch(batch: Dictionary) -> Dictionary:
		var batch_id := str(batch.get("batch_id", ""))
		if batch_id.is_empty():
			return {"applied": false, "reason": "batch_id_missing"}
		if applied_batch_ids.has(batch_id):
			return {"applied": true, "duplicate": true, "batch_id": batch_id}
		applied_batch_ids[batch_id] = true
		receipt_batches.append(batch.duplicate(true))
		return {"applied": true, "duplicate": false, "batch_id": batch_id}


func _ready() -> void:
	if not Engine.is_editor_hint():
		call_deferred("run_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func screenshot_path() -> String:
	return SCREENSHOT_PATH


func runtime_cases() -> Array:
	return CASE_IDS.duplicate()


func build_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id_variant in CASE_IDS:
		records.append(_record(str(case_id_variant), "preview", false, {"executed": false}))
	return {
		"suite_id": "ss06_06_commodity_inventory_persistent_installation",
		"ruleset_id": "v0.6",
		"record_count": records.size(),
		"records": records,
	}


func run_suite() -> void:
	_records.clear()
	_failures.clear()
	await _setup_runtime()
	_run_composition_cases()
	_run_claim_cases()
	_run_merge_cases()
	_run_market_and_generic_cases()
	_run_installation_cases()
	_run_ownership_cases()
	await _finish_suite()


func _setup_runtime() -> void:
	_coordinator = COORDINATOR_SCENE.instantiate() as GameRuntimeCoordinator
	runtime_host.add_child(_coordinator)
	await get_tree().process_frame
	_coordinator.configure(RULESET_V04.debug_snapshot())
	_world = RuntimeWorld.new()
	_world.players = [_player_fixture(0), _player_fixture(1)]
	runtime_host.add_child(_world)
	_coordinator.bind_ai_world(_world)
	_controller = _coordinator.commodity_card_inventory_runtime_controller()
	_state_adapter = _coordinator.card_player_state_production_adapter_v06()
	_core_economic_adapter = _coordinator.core_economic_card_runtime_adapter_v06()
	_flow = _coordinator.commodity_flow_runtime_controller()
	_infrastructure = _coordinator.get_node_or_null("RegionInfrastructureRuntimeController") as RegionInfrastructureRuntimeController
	_catalog = _controller.catalog() if _controller != null else null
	var initialized := _infrastructure.initialize_regions([
		{"region_id": "region.alpha", "terrain_id": "land", "neighbor_region_ids": [], "legacy_index": 0},
	]) if _infrastructure != null else {}
	var life_receipt := _build_facility("bench:facility:life", "life", 1)
	var energy_receipt := _build_facility("bench:facility:energy", "energy", 1)
	_life_facility_id = str(life_receipt.get("facility_id", ""))
	_energy_facility_id = str(energy_receipt.get("facility_id", ""))
	_check("controller_scene_composition", "composition", _controller != null and _state_adapter != null and _core_economic_adapter != null and _flow != null and _infrastructure != null and bool(initialized.get("initialized", false)), {
		"controller": _controller != null,
		"state_adapter": _state_adapter != null,
		"core_economic_adapter": _core_economic_adapter != null,
		"flow_owner": _flow != null,
		"infrastructure_owner": _infrastructure != null,
	})


func _run_composition_cases() -> void:
	var controller_debug := _controller.debug_snapshot()
	var state_adapter_debug := _state_adapter.debug_snapshot()
	var core_adapter_debug := _core_economic_adapter.debug_snapshot()
	var catalog_report: Dictionary = _catalog.call("validation_report") if _catalog != null and _catalog.has_method("validation_report") else {}
	_check("consumed_card_flow_api_ready", "composition", bool(controller_debug.get("controller_ready", false)) and str(controller_debug.get("card_flow_api_script", "")) == "res://scripts/cards/v06/card_flow_transaction_service_v06.gd", controller_debug)
	_check("production_state_adapter_single_mutation_owner", "ownership", bool(state_adapter_debug.get("world_bound", false)) and not bool(state_adapter_debug.get("stores_inventory", true)) and not bool(controller_debug.get("stores_player_inventory", true)), state_adapter_debug)
	_check("legacy_state_bridge_absent", "ownership", _coordinator.get_node_or_null("CommodityCardInventoryWorldBridge") == null and bool(core_adapter_debug.get("uses_shared_card_source_transaction_service", false)), core_adapter_debug)
	_check("v06_catalog_real", "content", bool(catalog_report.get("valid", false)) and int(catalog_report.get("card_count", 0)) >= 300 and not _card("commodity.star_dew_berry.rank_1").is_empty(), {
		"valid": catalog_report.get("valid", false),
		"card_count": catalog_report.get("card_count", 0),
		"sample_card_id": "commodity.star_dew_berry.rank_1",
	})


func _run_claim_cases() -> void:
	_reset_card_runtime(true)
	_set_world_cards(0, [])
	var rank_one := _card("commodity.star_dew_berry.rank_1")
	var cash_before := int((_world.players[0] as Dictionary).get("cash", -1))
	var before := _controller.player_snapshot("player.0")
	var configured := _controller.configure_belt(1, [_belt_item("belt:free", rank_one)])
	var claim := _controller.claim_belt_card("player.0", "belt:free", int(before.get("revision", -1)), 1, "bench:claim:free")
	_check("free_belt_claim", "claim", bool(configured.get("configured", false)) and bool(claim.get("committed", false)) and _world_card_count(0, "commodity.star_dew_berry.rank_1") == 1, _receipt_evidence(claim))
	_check("free_claim_cash_unchanged", "claim", int((_world.players[0] as Dictionary).get("cash", -1)) == cash_before, {"cash_before": cash_before, "cash_after": (_world.players[0] as Dictionary).get("cash", -1)})
	var replay := _controller.claim_belt_card("player.0", "belt:free", int(before.get("revision", -1)), 1, "bench:claim:free")
	_check("operation_replay_exact_once", "transaction", bool(replay.get("committed", false)) and bool(replay.get("idempotent_replay", false)) and _world_card_count(0, "commodity.star_dew_berry.rank_1") == 1, _receipt_evidence(replay))

	_reset_card_runtime(true)
	_set_world_cards(0, _cards(["commodity.star_dew_berry.rank_1"], "under-limit"))
	before = _controller.player_snapshot("player.0")
	_controller.configure_belt(2, [_belt_item("belt:duplicate", rank_one)])
	claim = _controller.claim_belt_card("player.0", "belt:duplicate", int(before.get("revision", -1)), 2, "bench:claim:duplicate")
	_check("under_limit_duplicate_remains_separate", "claim", bool(claim.get("committed", false)) and _world_card_count(0, "commodity.star_dew_berry.rank_1") == 2 and not _world_has_card(0, "commodity.star_dew_berry.rank_2"), _receipt_evidence(claim))

	_reset_card_runtime(true)
	_set_world_cards(0, _cards(LIFE_CARD_IDS, "full-match"))
	before = _controller.player_snapshot("player.0")
	_controller.configure_belt(3, [_belt_item("belt:auto-merge", rank_one)])
	claim = _controller.claim_belt_card("player.0", "belt:auto-merge", int(before.get("revision", -1)), 3, "bench:claim:auto-merge")
	_check("full_hand_auto_merge_exactly_one", "claim", bool(claim.get("committed", false)) and _world_has_card(0, "commodity.star_dew_berry.rank_2") and _world_nonempty_slot_count(0) == 5 and _world_card_count(0, "commodity.star_dew_berry.rank_1") == 0, _receipt_evidence(claim))

	_reset_card_runtime(true)
	_set_world_cards(0, _cards([
		"commodity.lunar_soil_grape.rank_1",
		"commodity.spore_silk.rank_1",
		"commodity.photosynthetic_gel.rank_1",
		"commodity.orbital_bonsai.rank_1",
		"commodity.lunar_soil_grape.rank_2",
	], "full-no-match"))
	before = _controller.player_snapshot("player.0")
	_controller.configure_belt(4, [_belt_item("belt:no-match", rank_one)])
	claim = _controller.claim_belt_card("player.0", "belt:no-match", int(before.get("revision", -1)), 4, "bench:claim:no-match")
	var no_match_source_present := (_controller.belt_snapshot().get("items", {}) as Dictionary).has("belt:no-match")
	_check("full_hand_no_match_atomic_reject", "claim", not bool(claim.get("committed", false)) and str(claim.get("reason_code", "")) == "hand_full_no_matching_merge" and _world_nonempty_slot_count(0) == 5, _receipt_evidence(claim))

	_reset_card_runtime(true)
	var rank_four := _card("commodity.star_dew_berry.rank_4")
	_set_world_cards(0, _cards([
		"commodity.star_dew_berry.rank_4",
		"commodity.lunar_soil_grape.rank_1",
		"commodity.spore_silk.rank_1",
		"commodity.photosynthetic_gel.rank_1",
		"commodity.orbital_bonsai.rank_1",
	], "rank-four"))
	before = _controller.player_snapshot("player.0")
	_controller.configure_belt(5, [_belt_item("belt:rank-four", rank_four)])
	var rank_four_claim := _controller.claim_belt_card("player.0", "belt:rank-four", int(before.get("revision", -1)), 5, "bench:claim:rank-four")
	_check("rank_iv_full_hand_reject", "claim", not bool(rank_four_claim.get("committed", false)) and str(rank_four_claim.get("reason_code", "")) == "matching_card_at_max_rank" and _world_card_count(0, "commodity.star_dew_berry.rank_4") == 1, _receipt_evidence(rank_four_claim))
	var rank_four_source_present := (_controller.belt_snapshot().get("items", {}) as Dictionary).has("belt:rank-four")
	_check("failed_claim_keeps_source", "claim", no_match_source_present and rank_four_source_present, {"no_match_source_present": no_match_source_present, "rank_four_source_present": rank_four_source_present})


func _run_merge_cases() -> void:
	_reset_card_runtime(true)
	_set_world_cards(0, _cards(["commodity.star_dew_berry.rank_1", "commodity.star_dew_berry.rank_1"], "manual"))
	var before := _controller.player_snapshot("player.0")
	var merged := _controller.manual_merge("player.0", 0, 1, int(before.get("revision", -1)), "bench:merge:valid")
	_check("manual_merge_success", "merge", bool(merged.get("committed", false)) and _world_has_card(0, "commodity.star_dew_berry.rank_2") and _world_nonempty_slot_count(0) == 1, _receipt_evidence(merged))

	_reset_card_runtime(true)
	_set_world_cards(0, _cards(["commodity.star_dew_berry.rank_1", "commodity.lunar_soil_grape.rank_1"], "manual-invalid"))
	before = _controller.player_snapshot("player.0")
	var fingerprint_before := _world_hand_fingerprint(0)
	var rejected := _controller.manual_merge("player.0", 0, 1, int(before.get("revision", -1)), "bench:merge:invalid")
	_check("manual_merge_invalid_atomic", "merge", not bool(rejected.get("committed", false)) and str(rejected.get("reason_code", "")) == "merge_family_mismatch" and fingerprint_before == _world_hand_fingerprint(0), _receipt_evidence(rejected))


func _run_market_and_generic_cases() -> void:
	_reset_card_runtime(true)
	_set_world_cards(0, [])
	_set_world_cash(0, 1000)
	var factory_card := _card("facility.factory.life.rank_1")
	var market_card := _card("facility.market.life.rank_1")
	var configured := _controller.configure_market(10, _market_listing("market:factory-life", factory_card, 4))
	var market_snapshot := _controller.market_snapshot()
	_check("market_api_ready", "market", bool(configured.get("configured", false)) and int(market_snapshot.get("revision", -1)) == 10 and str((market_snapshot.get("listing", {}) as Dictionary).get("item_id", "")) == "market:factory-life", market_snapshot)
	var before := _controller.player_snapshot("player.0")
	var purchase := _controller.purchase_market_card(
		"player.0",
		"market:factory-life",
		_market_listing("market:market-life", market_card, 4),
		int(before.get("revision", -1)),
		10,
		"bench:market:purchase"
	)
	_check("market_purchase_atomic_cash_inventory", "market", bool(purchase.get("committed", false)) and _world_cash(0) == 996 and _world_has_card(0, "facility.factory.life.rank_1") and int(_controller.market_snapshot().get("revision", -1)) == 11, {
		"committed": purchase.get("committed", false),
		"cash_after": _world_cash(0),
		"card_present": _world_has_card(0, "facility.factory.life.rank_1"),
		"market_revision": _controller.market_snapshot().get("revision", -1),
	})
	var replay := _controller.purchase_market_card(
		"player.0",
		"market:factory-life",
		_market_listing("market:market-life", market_card, 4),
		int(before.get("revision", -1)),
		10,
		"bench:market:purchase"
	)
	_check("market_purchase_replay_exact_once", "transaction", bool(replay.get("committed", false)) and bool(replay.get("idempotent_replay", false)) and _world_cash(0) == 996 and _world_nonempty_slot_count(0) == 1, _receipt_evidence(replay))

	_reset_card_runtime(true)
	_set_world_cards(0, _cards(["facility.factory.life.rank_1", "facility.factory.life.rank_1"], "generic-merge"))
	before = _controller.player_snapshot("player.0")
	var merged := _controller.manual_merge("player.0", 0, 1, int(before.get("revision", -1)), "bench:merge:generic")
	_check("generic_manual_merge_non_commodity", "merge", bool(merged.get("committed", false)) and _world_has_card(0, "facility.factory.life.rank_2") and _world_nonempty_slot_count(0) == 1, _receipt_evidence(merged))
	_check("generic_play_port_ready", "composition", _controller.has_method("play_core_card"), {"method": "play_core_card", "effect_router_owner": "Agent B"})
	var controller_save := _controller.to_save_data()
	var journal: Dictionary = controller_save.get("transaction_journal", {}) if controller_save.get("transaction_journal", {}) is Dictionary else {}
	_check("transaction_journal_save_covered", "save", not journal.is_empty() and _is_pure_data(journal) and controller_save.has("market"), {"journal_count": journal.size(), "market_saved": controller_save.has("market")})
	_reset_card_runtime(true)
	_set_world_cards(0, _cards(["facility.factory.life.rank_1"], "facility-fail-closed"))
	before = _controller.player_snapshot("player.0")
	var facility_fingerprint_before := _world_hand_fingerprint(0)
	var facility_play := _core_economic_adapter.play_card(
		"player.0",
		0,
		{"region_id": "region.alpha", "facility_type": "factory", "industry_id": "life"},
		int(before.get("revision", -1)),
		"bench:facility:rollback-gate"
	)
	_check("facility_effect_fail_closed_until_atomic_rollback", "transaction", not bool(facility_play.get("committed", false)) and str(facility_play.get("reason_code", "")) == "facility_rollback_atomicity_unavailable" and _world_hand_fingerprint(0) == facility_fingerprint_before, {
		"committed": facility_play.get("committed", false),
		"reason_code": facility_play.get("reason_code", ""),
		"hand_unchanged": _world_hand_fingerprint(0) == facility_fingerprint_before,
	})


func _run_installation_cases() -> void:
	_reset_card_runtime(true)
	_set_world_cards(0, _cards(["commodity.star_dew_berry.rank_1"], "play-valid"))
	var before := _controller.player_snapshot("player.0")
	var play := _controller.play_commodity_card("player.0", 0, _target(_life_facility_id), int(before.get("revision", -1)), "bench:play:valid")
	var active := _flow.installations_snapshot(false)
	var installation: Dictionary = active[0] if not active.is_empty() and active[0] is Dictionary else {}
	var finalization: Dictionary = play.get("effect_finalization", {}) if play.get("effect_finalization", {}) is Dictionary else {}
	var closed_rollback := _flow.rollback_commodity_installation("bench:play:valid")
	_check("play_same_color_factory", "installation", bool(play.get("committed", false)) and active.size() == 1, _receipt_evidence(play))
	_check("cross_owner_install_preserved", "installation", int(installation.get("installer_player_index", -1)) == 0 and _facility_owner(_life_facility_id) == 1, installation)
	_check("card_consumed_after_effect_commit", "transaction", _world_nonempty_slot_count(0) == 0 \
		and bool(play.get("committed", false)) \
		and bool(finalization.get("finalized", false)) \
		and str(closed_rollback.get("reason_code", closed_rollback.get("reason", ""))) == "installation_rollback_closed" \
		and _flow.installations_snapshot(false).size() == 1, {
		"hand_count": _world_nonempty_slot_count(0),
		"effect_committed": play.get("committed", false),
		"effect_finalized": finalization.get("finalized", false),
		"rollback_reason": closed_rollback.get("reason_code", closed_rollback.get("reason", "")),
		"installation_count": _flow.installations_snapshot(false).size(),
	})
	var replay := _controller.play_commodity_card("player.0", 0, _target(_life_facility_id), int(before.get("revision", -1)), "bench:play:valid")
	_check("operation_replay_exact_once", "transaction", _case_already_passed("operation_replay_exact_once") and bool(replay.get("committed", false)) and bool(replay.get("idempotent_replay", false)) and _flow.installations_snapshot(false).size() == 1, _receipt_evidence(replay), true)
	var market_receipt := _build_facility("bench:facility:market-life", "life", 1, "market")
	var market_facility_id := str(market_receipt.get("facility_id", ""))
	var market_facility := _facility_by_id(market_facility_id)
	var demand_install := _flow.install_commodity({
		"transaction_id": "bench:flow:demand-life",
		"facility_id": market_facility_id,
		"facility": market_facility,
		"region_id": "region.alpha",
		"region_revision": int(_infrastructure.region_snapshot("region.alpha").get("revision", 0)),
		"commodity_id": str(installation.get("commodity_id", "")),
		"direction": "demand",
		"installer_player_index": 1,
		"source_card_rank": 1,
		"game_time": 6.0,
	})
	_world.game_time = 12.0
	var flow_tick := _flow.advance_world(6.0)
	var candidate_snapshot := _flow.card_effect_candidates_snapshot()
	var candidates: Array = candidate_snapshot.get("candidates", []) if candidate_snapshot.get("candidates", []) is Array else []
	_check("authoritative_candidate_snapshot_ready", "flow_candidate", bool(demand_install.get("committed", false)) and bool(flow_tick.get("advanced", false)) and int(flow_tick.get("receipt_count", 0)) >= 1 and bool(candidate_snapshot.get("valid", false)) and candidates.size() >= 2 and candidates.size() % 2 == 0, {
		"demand_committed": demand_install.get("committed", false),
		"flow_receipt_count": flow_tick.get("receipt_count", 0),
		"candidate_count": candidates.size(),
		"candidate_revision": candidate_snapshot.get("revision", 0),
	})
	var lineage_preserved := not candidates.is_empty()
	var lineage_evidence: Dictionary = {}
	if lineage_preserved:
		var candidate: Dictionary = candidates[0]
		var route: Dictionary = candidate.get("route", {}) if candidate.get("route", {}) is Dictionary else {}
		var resources: Array = route.get("capacity_resources", []) if route.get("capacity_resources", []) is Array else []
		lineage_preserved = not str(route.get("source_facility_id", "")).is_empty() \
			and not str(route.get("market_facility_id", "")).is_empty() \
			and not str(route.get("route_id", "")).is_empty() \
			and not resources.is_empty() \
			and int(candidate.get("available_capacity_units", 0)) > 0
		lineage_evidence = {
			"source_factory_id": route.get("source_facility_id", ""),
			"market_facility_id": route.get("market_facility_id", ""),
			"route_id": route.get("route_id", ""),
			"capacity_resource_count": resources.size(),
			"available_capacity_units": candidate.get("available_capacity_units", 0),
		}
	_check("candidate_lineage_preserved", "flow_candidate", lineage_preserved, lineage_evidence)
	_run_card_effect_batch_hard_gate_cases(str(installation.get("commodity_id", "")))

	_reset_card_runtime(true)
	_set_world_cards(0, _cards(["commodity.star_dew_berry.rank_1"], "wrong-color"))
	before = _controller.player_snapshot("player.0")
	var rejected := _controller.play_commodity_card("player.0", 0, _target(_energy_facility_id), int(before.get("revision", -1)), "bench:play:wrong-color")
	_check("wrong_color_target_atomic_reject", "installation", not bool(rejected.get("committed", false)) and _world_nonempty_slot_count(0) == 1 and _flow.installations_snapshot(false).is_empty(), _receipt_evidence(rejected))

	_reset_card_runtime(true)
	_set_world_cards(0, _cards(["commodity.star_dew_berry.rank_1"], "inactive"))
	before = _controller.player_snapshot("player.0")
	rejected = _controller.play_commodity_card("player.0", 0, _target("facility.missing"), int(before.get("revision", -1)), "bench:play:inactive")
	_check("inactive_target_atomic_reject", "installation", not bool(rejected.get("committed", false)) and _world_nonempty_slot_count(0) == 1 and _flow.installations_snapshot(false).is_empty(), _receipt_evidence(rejected))

	_reset_card_runtime(true)
	var expected_rates := {1: 10, 2: 20, 3: 40, 4: 80}
	var rate_results: Dictionary = {}
	for rank in range(1, 5):
		_set_world_cards(0, _cards(["commodity.star_dew_berry.rank_%d" % rank], "rate-%d" % rank))
		before = _controller.player_snapshot("player.0")
		var rank_play := _controller.play_commodity_card("player.0", 0, _target(_life_facility_id), int(before.get("revision", -1)), "bench:play:rank:%d" % rank)
		var installed_rate := _installed_rate_for_rank(rank)
		rate_results[rank] = {"committed": rank_play.get("committed", false), "rate": installed_rate}
		_check("rate_rank_%s_%d" % [_roman(rank).to_lower(), int(expected_rates[rank])], "installation", bool(rank_play.get("committed", false)) and installed_rate == int(expected_rates[rank]), rate_results[rank])
	var flow_save := _flow.to_save_data()
	_flow.reset_state()
	var restored := _flow.apply_save_data(flow_save)
	_check("installation_persistent_save_round_trip", "save", bool(restored.get("applied", false)) and _flow.installations_snapshot(false).size() == 4 and _installed_rate_for_rank(4) == 80, {"applied": restored.get("applied", false), "installation_count": _flow.installations_snapshot(false).size()})

	var region := _infrastructure.region_snapshot("region.alpha")
	var destroyed := _infrastructure.apply_unit_damage({
		"transaction_id": "bench:destroy:region",
		"source_kind": "monster",
		"source_entity_id": "monster.bench",
		"region_id": "region.alpha",
		"amount": maxi(1, int(region.get("derived_current_hp", 1))),
		"occurred_at": 20.0,
	})
	_world.game_time = 20.0
	var advanced := _coordinator.advance_commodity_flow(1.0)
	var inactive := _flow.installations_snapshot(true)
	var all_destroyed := not inactive.is_empty()
	for row_variant in inactive:
		if not (row_variant is Dictionary) or bool((row_variant as Dictionary).get("active", true)) or str((row_variant as Dictionary).get("removed_reason", "")) != "facility_destroyed":
			all_destroyed = false
	_check("installation_deactivates_on_facility_destroyed", "lifecycle", bool(destroyed.get("region_ruined", false)) and bool(advanced.get("advanced", false)) and _flow.installations_snapshot(false).is_empty() and all_destroyed, {"destroyed_facility_ids": destroyed.get("destroyed_facility_ids", []), "active_count": _flow.installations_snapshot(false).size(), "historical_count": inactive.size()})


func _run_card_effect_batch_hard_gate_cases(commodity_id: String) -> void:
	var industry_id := str(PRODUCT_CATALOG.call("industry_for_product", commodity_id)) if PRODUCT_CATALOG != null and PRODUCT_CATALOG.has_method("industry_for_product") else ""
	var flow := FLOW_SCENE.instantiate() as CommodityFlowRuntimeController
	var bridge := FlowFactsBridge.new()
	runtime_host.add_child(flow)
	runtime_host.add_child(bridge)
	bridge.facts = _hard_gate_flow_facts(commodity_id, industry_id)
	var configured := flow.configure(RULESET_V06.debug_snapshot())
	flow.set_world_bridge(bridge)
	var factory_a: Dictionary = (bridge.facts.get("facilities", []) as Array)[0]
	var factory_b: Dictionary = (bridge.facts.get("facilities", []) as Array)[1]
	var market: Dictionary = (bridge.facts.get("facilities", []) as Array)[2]
	var production_a := _install_hard_gate_commodity(flow, "hard-gate:production:a", factory_a, commodity_id, "production", 0, 4)
	var demand := _install_hard_gate_commodity(flow, "hard-gate:demand", market, commodity_id, "demand", 1, 1)
	bridge.facts["route_candidates"] = [_hard_gate_land_route(commodity_id)]
	bridge.facts["game_time"] = 60.0
	var seeded := flow.advance_world(60.0)
	var production_b := _install_hard_gate_commodity(flow, "hard-gate:production:b", factory_b, commodity_id, "production", 0, 4)
	var snapshot := flow.card_effect_candidates_snapshot()
	var factory_candidates := _card_effect_candidates_by_type(snapshot, "factory")
	var market_candidates := _card_effect_candidates_by_type(snapshot, "market")
	var source_ids: Dictionary = {}
	for candidate_variant in factory_candidates:
		var route: Dictionary = (candidate_variant as Dictionary).get("route", {}) if (candidate_variant as Dictionary).get("route", {}) is Dictionary else {}
		source_ids[str(route.get("source_facility_id", ""))] = true
	_check("current_route_enumeration_not_receipt_lineage", "flow_candidate", bool(configured.get("configured", false)) and bool(production_a.get("committed", false)) and bool(demand.get("committed", false)) and bool(seeded.get("advanced", false)) and bool(production_b.get("committed", false)) and bool(snapshot.get("valid", false)) and source_ids.has("factory-a") and source_ids.has("factory-b") and factory_candidates.size() >= 2 and market_candidates.size() >= 2, {
		"candidate_count": (snapshot.get("candidates", []) as Array).size(),
		"factory_candidate_count": factory_candidates.size(),
		"market_candidate_count": market_candidates.size(),
		"source_factory_ids": source_ids.keys(),
		"route_candidates_in_facts": (bridge.facts.get("route_candidates", []) as Array).size(),
	})

	var first_factory: Dictionary = factory_candidates[0] if not factory_candidates.is_empty() else {}
	var stale_plan := _card_effect_plan_from_candidate("hard-gate:stale", "physical_supply", first_factory, snapshot, 1)
	stale_plan["candidate_snapshot_revision"] = int(snapshot.get("revision", 0)) - 1
	var stale_result := flow.prepare_card_effect_batch(stale_plan)
	_check("batch_snapshot_binding_enforced", "transaction", not bool(stale_result.get("prepared", false)) and str(stale_result.get("reason_code", "")) == "candidate_snapshot_revision_changed", _receipt_evidence(stale_result))

	var aggregate_result: Dictionary = {"prepared": false, "reason_code": "insufficient_distinct_candidates"}
	if factory_candidates.size() >= 2:
		var first_units := maxi(1, int((factory_candidates[0] as Dictionary).get("available_capacity_units", 0)))
		var second_units := maxi(1, int((factory_candidates[1] as Dictionary).get("available_capacity_units", 0)))
		var aggregate_plan := _card_effect_plan_from_candidate("hard-gate:aggregate", "physical_supply", factory_candidates[0] as Dictionary, snapshot, first_units)
		var second_plan := _card_effect_plan_from_candidate("hard-gate:aggregate", "physical_supply", factory_candidates[1] as Dictionary, snapshot, second_units)
		(aggregate_plan.get("allocations", []) as Array).append(((second_plan.get("allocations", []) as Array)[0] as Dictionary).duplicate(true))
		var before_aggregate := flow.to_save_data()
		aggregate_result = flow.prepare_card_effect_batch(aggregate_plan)
		aggregate_result["state_unchanged"] = before_aggregate == flow.to_save_data()
	_check("shared_capacity_aggregate_enforced", "transaction", not bool(aggregate_result.get("prepared", false)) and str(aggregate_result.get("reason_code", "")) == "batch_shared_capacity_exceeded" and bool(aggregate_result.get("state_unchanged", false)), _receipt_evidence(aggregate_result))

	var selected_market: Dictionary = market_candidates[0] if not market_candidates.is_empty() else {}
	var selected_route: Dictionary = selected_market.get("route", {}) if selected_market.get("route", {}) is Dictionary else {}
	var demand_plan := _card_effect_plan_from_candidate("hard-gate:lineage", "extra_demand", selected_market, snapshot, 1)
	var demand_prepared := flow.prepare_card_effect_batch(demand_plan)
	var demand_committed := flow.commit_card_effect_batch(demand_prepared)
	var pending_save := flow.to_save_data()
	var pending_demands: Dictionary = pending_save.get("pending_one_shot_demands", {}) if pending_save.get("pending_one_shot_demands", {}) is Dictionary else {}
	var pending_claim: Dictionary = (pending_demands.values()[0] as Dictionary) if not pending_demands.is_empty() else {}
	var pending_lineage_matches := str(pending_claim.get("planned_source_factory_id", "")) == str(selected_route.get("source_facility_id", "")) \
		and str(pending_claim.get("planned_market_facility_id", "")) == str(selected_route.get("market_facility_id", "")) \
		and str(pending_claim.get("planned_route_id", "")) == str(selected_route.get("route_id", "")) \
		and int(pending_claim.get("planned_shortest_legal_distance", -1)) == int(selected_route.get("shortest_legal_distance", -2))
	var finalized := flow.finalize_card_effect_batch(demand_committed)
	var closed_rollback := flow.rollback_card_effect_batch(demand_committed)
	bridge.facts["game_time"] = 120.0
	var settled_tick := flow.advance_world(60.0)
	var settled_batch := flow.card_effect_batch_snapshot("hard-gate:lineage")
	var sale_lineage_matches := false
	for sale_variant in flow.to_save_data().get("recent_sale_receipts", []):
		if not (sale_variant is Dictionary):
			continue
		var sale: Dictionary = sale_variant
		if str(sale.get("source_factory_id", "")) == str(selected_route.get("source_facility_id", "")) \
			and str(sale.get("market_facility_id", "")) == str(selected_route.get("market_facility_id", "")) \
			and str(sale.get("route_id", "")) == str(selected_route.get("route_id", "")):
			sale_lineage_matches = true
			break
	_check("extra_demand_lineage_constrained", "transaction", bool(demand_committed.get("committed", false)) and pending_lineage_matches and bool(settled_tick.get("advanced", false)) and bool(settled_batch.get("settled", false)) and sale_lineage_matches, {
		"pending_lineage_matches": pending_lineage_matches,
		"sale_lineage_matches": sale_lineage_matches,
		"selected_source_factory_id": selected_route.get("source_facility_id", ""),
		"selected_market_facility_id": selected_route.get("market_facility_id", ""),
		"selected_route_id": selected_route.get("route_id", ""),
	})
	_check("finalized_batch_rollback_closed", "transaction", bool(finalized.get("finalized", false)) and not bool(finalized.get("rollback_open", true)) and not bool(closed_rollback.get("rolled_back", false)) and str(closed_rollback.get("reason_code", "")) == "batch_rollback_closed", {
		"finalized": finalized.get("finalized", false),
		"rollback_open": finalized.get("rollback_open", true),
		"rollback_reason": closed_rollback.get("reason_code", ""),
	})

	var supply_snapshot := flow.card_effect_candidates_snapshot()
	var supply_candidates := _card_effect_candidates_by_type(supply_snapshot, "factory")
	var selected_factory: Dictionary = supply_candidates[0] if not supply_candidates.is_empty() else {}
	var supply_plan := _card_effect_plan_from_candidate("hard-gate:save-binding", "physical_supply", selected_factory, supply_snapshot, 1)
	var supply_prepared := flow.prepare_card_effect_batch(supply_plan)
	var supply_committed := flow.commit_card_effect_batch(supply_prepared)
	var reserved_snapshot := flow.card_effect_candidates_snapshot()
	var reserved_candidate: Dictionary = {}
	for candidate_variant in reserved_snapshot.get("candidates", []):
		if candidate_variant is Dictionary and str((candidate_variant as Dictionary).get("candidate_id", "")) == str(selected_factory.get("candidate_id", "")):
			reserved_candidate = (candidate_variant as Dictionary).duplicate(true)
			break
	var pending_capacity_checked := not reserved_candidate.is_empty() \
		and int(reserved_candidate.get("available_capacity_units", -1)) == int(selected_factory.get("available_capacity_units", 0)) - 1
	_check("shared_capacity_aggregate_enforced", "transaction", _case_already_passed("shared_capacity_aggregate_enforced") and pending_capacity_checked, {
		"multi_child_aggregate_rejected": true,
		"pending_capacity_checked": pending_capacity_checked,
		"available_before": selected_factory.get("available_capacity_units", -1),
		"available_after_pending": reserved_candidate.get("available_capacity_units", -1),
	}, true)
	var valid_save := flow.to_save_data()
	var tampered_save := valid_save.duplicate(true)
	var tampered_supplies: Dictionary = tampered_save.get("pending_one_shot_supplies", {}) if tampered_save.get("pending_one_shot_supplies", {}) is Dictionary else {}
	if not tampered_supplies.is_empty():
		var supply_id: Variant = tampered_supplies.keys()[0]
		var tampered_claim: Dictionary = (tampered_supplies.get(supply_id, {}) as Dictionary).duplicate(true)
		tampered_claim["batch_transaction_id"] = "wrong-batch"
		tampered_supplies[supply_id] = tampered_claim
		tampered_save["pending_one_shot_supplies"] = tampered_supplies
	var invalid_restore := flow.apply_save_data(tampered_save)
	_check("saved_batch_binding_validated", "save", bool(supply_committed.get("committed", false)) and not bool(invalid_restore.get("applied", false)) and str(invalid_restore.get("reason", "")) == "card_effect_batch_child_binding_invalid" and flow.to_save_data() == valid_save, {
		"committed": supply_committed.get("committed", false),
		"restore_applied": invalid_restore.get("applied", false),
		"restore_reason": invalid_restore.get("reason", ""),
		"state_unchanged": flow.to_save_data() == valid_save,
	})
	var tampered_receipt := supply_committed.duplicate(true)
	tampered_receipt["intent_hash"] = "wrong-intent"
	var rejected_rollback := flow.rollback_card_effect_batch(tampered_receipt)
	var accepted_rollback := flow.rollback_card_effect_batch(supply_committed)
	_check("rollback_binding_precedes_replay", "transaction", not bool(rejected_rollback.get("rolled_back", false)) and str(rejected_rollback.get("reason_code", "")) == "batch_receipt_binding_invalid" and bool(accepted_rollback.get("rolled_back", false)), {
		"tampered_reason": rejected_rollback.get("reason_code", ""),
		"correct_rollback": accepted_rollback.get("rolled_back", false),
	})
	_run_global_supply_demand_outer_finalize_case(flow)
	flow.queue_free()
	bridge.queue_free()


func _run_ownership_cases() -> void:
	var controller_save := _controller.to_save_data()
	var state_port_save: Dictionary = controller_save.get("state_port", {}) if controller_save.get("state_port", {}) is Dictionary else {}
	_check("player_state_adapter_save_owner_stable", "ownership", not state_port_save.has("players") and not state_port_save.has("inventory") and state_port_save.has("journal"), {"state_port_keys": state_port_save.keys()})
	var controller_debug := _controller.debug_snapshot()
	var state_adapter_debug := _state_adapter.debug_snapshot()
	var core_adapter_debug := _core_economic_adapter.debug_snapshot()
	var public_installations := _flow.public_installations_snapshot()
	var public_hides_installer := true
	for row_variant in public_installations:
		if row_variant is Dictionary and (row_variant as Dictionary).has("installer_player_index"):
			public_hides_installer = false
	_check("pure_data_snapshots", "privacy", _is_pure_data(controller_debug) and _is_pure_data(state_adapter_debug) and _is_pure_data(core_adapter_debug) and _is_pure_data(controller_save) and _is_pure_data(_flow.to_save_data()), {"controller": true, "state_adapter": true, "core_adapter": true, "save": true})
	_check("public_installation_hides_installer", "privacy", public_hides_installer, {"public_count": public_installations.size(), "installer_hidden": public_hides_installer})
	_check("viewer_belt_visibility_not_owned", "ownership", not bool(controller_debug.get("viewer_belt_visibility_owner", true)), {"viewer_belt_visibility_owner": controller_debug.get("viewer_belt_visibility_owner", true), "next_owner": "SS06-07"})
	var state_adapter_source := FileAccess.get_file_as_string("res://scripts/cards/v06/production/card_player_state_production_adapter_v06.gd")
	var controller_source := FileAccess.get_file_as_string("res://scripts/runtime/commodity_card_inventory_runtime_controller.gd")
	_check("v06_state_route_avoids_legacy_receive", "ownership", state_adapter_source.find("commit_reserved") >= 0 and state_adapter_source.find("plan_receive") < 0 and state_adapter_source.find("commit_receive") < 0, {"production_commit_reserved": true, "legacy_receive_calls": false})
	_check("no_parallel_card_flow_implementation", "ownership", controller_source.find("card_flow_transaction_service_v06.gd") >= 0 and controller_source.find("plan_acquisition") < 0 and controller_source.find("commit_acquisition") < 0 and not bool(controller_debug.get("stores_player_inventory", true)), {"consumed_api": controller_debug.get("card_flow_api_script", ""), "stores_player_inventory": controller_debug.get("stores_player_inventory", true)})


func _finish_suite() -> void:
	var passed_count := _records.size() - _failures.size()
	var manifest := {
		"suite_id": "ss06_06_commodity_inventory_persistent_installation",
		"ruleset_id": "v0.6",
		"record_count": _records.size(),
		"passed_count": passed_count,
		"failed_count": _failures.size(),
		"card_flow_api_owner": "CardFlowTransactionServiceV06",
		"inventory_mutation_owner": "CardPlayerStateProductionAdapterV06",
		"installation_owner": "CommodityFlowRuntimeController",
		"viewer_belt_visibility_owner": "SS06-07",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"records": _records.duplicate(true),
	}
	_write_outputs(manifest)
	status_label.text = "%d/%d PASSED" % [passed_count, _records.size()]
	status_label.modulate = Color("#67e8a4") if _failures.is_empty() else Color("#fb7185")
	ownership_text.text = "[b]Runtime ownership[/b]\n\nCard Flow: one shared transaction service\nPlayer-state mutation port: CardPlayerStateProductionAdapterV06\nWorld projection: real player slots\nPermanent install: CommodityFlowRuntimeController\nBelt visibility: deferred to SS06-07\n\n[b]Result[/b]\n%d/%d passed" % [passed_count, _records.size()]
	cases_text.text = _case_summary_text()
	set_meta("bench_exit_code", 0 if _failures.is_empty() else 1)
	set_meta("passed_count", passed_count)
	set_meta("record_count", _records.size())
	await get_tree().process_frame
	await get_tree().process_frame
	_save_screenshot()
	print("COMMODITY_INVENTORY_PERSISTENT_INSTALLATION_BENCH|passed=%d|total=%d|manifest=%s|report=%s|screenshot=%s" % [passed_count, _records.size(), MANIFEST_PATH, REPORT_PATH, SCREENSHOT_PATH])
	if not _failures.is_empty():
		push_error("SS06-06 failed:\n- %s" % "\n- ".join(_failures))
	if DisplayServer.get_name() == "headless":
		for _frame in range(3):
			await get_tree().process_frame
		get_tree().quit(0 if _failures.is_empty() else 1)


func _check(case_id: String, category: String, passed: bool, evidence: Dictionary, replace_existing := false) -> void:
	var record := _record(case_id, category, passed, evidence)
	if replace_existing:
		for index in range(_records.size()):
			if str((_records[index] as Dictionary).get("case_id", "")) == case_id:
				if not bool((_records[index] as Dictionary).get("passed", false)):
					_failures.erase(case_id)
				_records[index] = record
				if not passed and not _failures.has(case_id):
					_failures.append(case_id)
				print("COMMODITY_INVENTORY_CASE|case=%s|passed=%s" % [case_id, str(passed)])
				return
	_records.append(record)
	if not passed:
		_failures.append(case_id)
	print("COMMODITY_INVENTORY_CASE|case=%s|passed=%s" % [case_id, str(passed)])


func _record(case_id: String, category: String, passed: bool, evidence: Dictionary) -> Dictionary:
	return {
		"case_id": case_id,
		"category": category,
		"passed": passed,
		"inventory_owner_checked": category == "ownership" or category == "transaction" or category == "claim" or category == "merge",
		"installation_owner_checked": category == "installation" or category == "lifecycle" or category == "save",
		"card_flow_api_checked": true,
		"privacy_checked": category == "privacy" or category == "ownership",
		"pure_data_checked": _is_pure_data(evidence),
		"notes": "passed" if passed else "check failed",
		"evidence": evidence.duplicate(true),
	}


func _build_facility(transaction_id: String, industry_id: String, owner_player_index: int, facility_type := "factory") -> Dictionary:
	if _infrastructure == null:
		return {}
	return _infrastructure.apply_facility_action({
		"transaction_id": transaction_id,
		"region_id": "region.alpha",
		"owner_kind": "player",
		"owner_player_index": owner_player_index,
		"facility_type": facility_type,
		"industry_id": industry_id,
		"rank": 1,
		"occurred_at": 1.0,
	})


func _hard_gate_flow_facts(commodity_id: String, industry_id: String) -> Dictionary:
	return {
		"game_time": 0.0,
		"regions": [{
			"region_id": "region.local",
			"revision": 1,
			"lifecycle_state": "active",
			"integrity_basis_points": 10000,
			"neighbor_region_ids": [],
		}],
		"facilities": [
			{"facility_id": "factory-a", "facility_type": "factory", "industry_id": industry_id, "region_id": "region.local", "owner_player_index": 4, "rank": 4, "active": true},
			{"facility_id": "factory-b", "facility_type": "factory", "industry_id": industry_id, "region_id": "region.local", "owner_player_index": 5, "rank": 4, "active": true},
			{"facility_id": "market-a", "facility_type": "market", "industry_id": industry_id, "region_id": "region.local", "owner_player_index": 6, "rank": 4, "active": true},
		],
		"destroyed_facility_ids": [],
		"price_cents_by_commodity": {commodity_id: 1000},
		"route_candidates": [],
	}


func _hard_gate_land_route(commodity_id: String) -> Dictionary:
	return {
		"route_id": "hard-gate:land:local",
		"commodity_id": commodity_id,
		"source_region_id": "region.local",
		"market_region_id": "region.local",
		"ordered_legs": [{"from_region_id": "region.local", "to_region_id": "region.local", "mode": "land"}],
		"mode_tags": ["land"],
		"shortest_legal_distance": 1,
		"bottleneck_units_per_minute": 120,
		"capacity_resources": [{"resource_id": "hard-gate:land-capacity", "capacity_units_per_minute": 120}],
		"expected_rents": [],
		"arrival_seconds": 0.0,
		"transfer_count": 0,
		"topology_revision": "hard-gate:land:v1",
	}


func _run_global_supply_demand_outer_finalize_case(flow: CommodityFlowRuntimeController) -> void:
	var candidate_snapshot := flow.card_effect_candidates_snapshot()
	var batch_sink: Object = FLOW_BATCH_SINK_SCRIPT.new()
	var sink_config: Dictionary = batch_sink.call("configure", flow)
	var global_owner: Object = GLOBAL_SUPPLY_DEMAND_OWNER_SCRIPT.new()
	var owner_config: Dictionary = global_owner.call("set_batch_sink", batch_sink)
	var candidates: Array = candidate_snapshot.get("candidates", []) if candidate_snapshot.get("candidates", []) is Array else []
	var candidate_config: Dictionary = global_owner.call("replace_authoritative_candidates", int(candidate_snapshot.get("revision", -1)), candidates.duplicate(true))
	var global_adapter: Object = GLOBAL_SUPPLY_DEMAND_ADAPTER_SCRIPT.new()
	var adapter_config: Dictionary = global_adapter.call("configure", global_owner, {"actor.global": 0})
	var router: Object = CORE_EFFECT_ROUTER_SCRIPT.new()
	var router_config: Dictionary = router.call("configure", {"global_supply_spawn": global_adapter})
	var card := _card("supply_demand.near_land_supply.rank_1")
	card["runtime_instance_id"] = "global-finalize:card"
	var transaction_service: Object = CARD_FLOW_TRANSACTION_SCRIPT.new(_catalog)
	transaction_service.call("register_player", "actor.global", {
		"revision": 0,
		"cash": 20,
		"assets": _all_assets(20),
		"inventory": {"hand_limit": 5, "slots": [card]},
	})
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	var boundary := CommodityCardInventoryRuntimeController.EffectTransactionBoundary.new(router, flow)
	var play_variant: Variant = transaction_service.call("play_card", "actor.global", 0, {
		"valid": true,
		"target_kind": str(machine.get("target_kind", "")),
		"candidate_snapshot_revision": int(candidate_snapshot.get("revision", -1)),
	}, boundary, 0, "hard-gate:global-finalize")
	var play: Dictionary = (play_variant as Dictionary).duplicate(true) if play_variant is Dictionary else {}
	var flow_receipt := _find_receipt_kind(play.get("effect_receipt", {}), "commodity_flow_card_effect_batch")
	var finalization: Dictionary = play.get("effect_finalization", {}) if play.get("effect_finalization", {}) is Dictionary else {}
	var closed_rollback := flow.rollback_card_effect_batch(flow_receipt) if not flow_receipt.is_empty() else {}
	_check("global_supply_demand_outer_finalize_closed", "transaction", bool(sink_config.get("configured", false)) \
		and bool(owner_config.get("configured", false)) \
		and bool(candidate_config.get("configured", false)) \
		and bool(adapter_config.get("configured", false)) \
		and bool(router_config.get("configured", false)) \
		and bool(play.get("committed", false)) \
		and bool(finalization.get("finalized", false)) \
		and not bool(closed_rollback.get("rolled_back", false)) \
		and str(closed_rollback.get("reason_code", "")) == "batch_rollback_closed", {
		"candidate_count": candidates.size(),
		"play_committed": play.get("committed", false),
		"finalized": finalization.get("finalized", false),
		"finalization_reason": finalization.get("reason_code", ""),
		"rollback_reason": closed_rollback.get("reason_code", ""),
	})


func _find_receipt_kind(value: Variant, receipt_kind: String) -> Dictionary:
	if value is Dictionary:
		var source: Dictionary = value
		if str(source.get("receipt_kind", "")) == receipt_kind:
			return source.duplicate(true)
		for nested_value in source.values():
			var nested := _find_receipt_kind(nested_value, receipt_kind)
			if not nested.is_empty():
				return nested
	elif value is Array:
		for nested_value in value:
			var nested := _find_receipt_kind(nested_value, receipt_kind)
			if not nested.is_empty():
				return nested
	return {}


func _all_assets(value: int) -> Dictionary:
	return {"life": value, "energy": value, "industry": value, "technology": value, "commerce": value, "shipping": value}


func _install_hard_gate_commodity(
	flow: CommodityFlowRuntimeController,
	transaction_id: String,
	facility: Dictionary,
	commodity_id: String,
	direction: String,
	installer_player_index: int,
	rank: int
) -> Dictionary:
	return flow.install_commodity({
		"transaction_id": transaction_id,
		"facility_id": str(facility.get("facility_id", "")),
		"facility": facility.duplicate(true),
		"region_id": str(facility.get("region_id", "")),
		"region_revision": 1,
		"commodity_id": commodity_id,
		"direction": direction,
		"installer_player_index": installer_player_index,
		"source_card_rank": rank,
		"game_time": 0.0,
	})


func _card_effect_candidates_by_type(snapshot: Dictionary, facility_type: String) -> Array:
	var result: Array = []
	for candidate_variant in snapshot.get("candidates", []):
		if not (candidate_variant is Dictionary):
			continue
		var candidate: Dictionary = candidate_variant
		var facility: Dictionary = candidate.get("facility", {}) if candidate.get("facility", {}) is Dictionary else {}
		if str(facility.get("facility_type", "")) == facility_type:
			result.append(candidate.duplicate(true))
	return result


func _card_effect_plan_from_candidate(
	transaction_id: String,
	effect_kind: String,
	candidate: Dictionary,
	snapshot: Dictionary,
	allocated_units: int
) -> Dictionary:
	var facility: Dictionary = candidate.get("facility", {}) if candidate.get("facility", {}) is Dictionary else {}
	var region: Dictionary = candidate.get("region", {}) if candidate.get("region", {}) is Dictionary else {}
	var product: Dictionary = candidate.get("product", {}) if candidate.get("product", {}) is Dictionary else {}
	var route: Dictionary = candidate.get("route", {}) if candidate.get("route", {}) is Dictionary else {}
	var resource_ids: Array = []
	for resource_variant in route.get("capacity_resources", []):
		if resource_variant is Dictionary:
			resource_ids.append(str((resource_variant as Dictionary).get("resource_id", "")))
	var owner_index := int(candidate.get("commodity_owner_player_index", -1))
	var product_id := str(product.get("product_id", ""))
	return {
		"ready": true,
		"transaction_id": transaction_id,
		"intent_hash": "intent:%s" % transaction_id,
		"plan_hash": "plan:%s" % transaction_id,
		"candidate_snapshot_revision": int(snapshot.get("revision", -1)),
		"candidate_snapshot_fingerprint": str(snapshot.get("fingerprint", "")),
		"one_time_effect_kind": effect_kind,
		"allocations": [{
			"candidate_id": str(candidate.get("candidate_id", "")),
			"goods_key": "%08d|%s" % [owner_index, product_id],
			"product_id": product_id,
			"industry_id": str(product.get("industry_id", "")),
			"commodity_owner_player_index": owner_index,
			"matching_product_gdp_30s": int(candidate.get("matching_product_gdp_30s", -1)),
			"beneficiary_player_index": owner_index,
			"facility_owner_player_index": int(facility.get("owner_player_index", -1)),
			"facility_owner_reward_units": 0,
			"permanent_rate_delta": 0,
			"facility_id": str(facility.get("facility_id", "")),
			"facility_type": str(facility.get("facility_type", "")),
			"source_facility_id": str(route.get("source_facility_id", "")),
			"market_facility_id": str(route.get("market_facility_id", "")),
			"region_id": str(region.get("region_id", "")),
			"region_revision": int(region.get("revision", -1)),
			"route_id": str(route.get("route_id", "")),
			"topology_revision": str(route.get("topology_revision", "")),
			"route_mode_tags": (route.get("mode_tags", []) as Array).duplicate(true) if route.get("mode_tags", []) is Array else [],
			"shortest_legal_distance": int(route.get("shortest_legal_distance", -1)),
			"capacity_resource_ids": resource_ids,
			"allocated_units": allocated_units,
			"one_time_effect_kind": effect_kind,
		}],
	}


func _reset_card_runtime(clear_flow: bool) -> void:
	if _controller != null:
		_controller.reset_state()
	if clear_flow and _flow != null:
		_flow.reset_state()


func _card(card_id: String) -> Dictionary:
	if _catalog == null or not _catalog.has_method("card_snapshot"):
		return {}
	var value: Variant = _catalog.call("card_snapshot", card_id)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _cards(card_ids: Array, prefix: String) -> Array:
	var result: Array = []
	for index in range(card_ids.size()):
		var card := _card(str(card_ids[index]))
		card["runtime_instance_id"] = "%s:%d" % [prefix, index]
		result.append(card)
	return result


func _belt_item(item_id: String, card: Dictionary) -> Dictionary:
	return {"item_id": item_id, "card": card.duplicate(true), "claimable": true, "visible_actor_ids": ["player.0"]}


func _market_listing(item_id: String, card: Dictionary, price_cash: int) -> Dictionary:
	return {"item_id": item_id, "card": card.duplicate(true), "price_cash": price_cash, "claimable": true, "legal_actor_ids": ["player.0"]}


func _target(facility_id: String) -> Dictionary:
	return {"valid": true, "target_kind": "same_industry_factory_or_market", "facility_id": facility_id, "game_time": _world.game_time}


func _player_fixture(player_index: int) -> Dictionary:
	return {"id": player_index, "name": "Player %d" % (player_index + 1), "cash": 1000, "cash_cents": 100000, "slots": []}


func _set_world_cards(player_index: int, cards: Array) -> void:
	var players := _world.players.duplicate(true)
	var player: Dictionary = (players[player_index] as Dictionary).duplicate(true)
	player["slots"] = cards.duplicate(true)
	players[player_index] = player
	_world.players = players


func _set_world_cash(player_index: int, cash: int) -> void:
	var players := _world.players.duplicate(true)
	var player: Dictionary = (players[player_index] as Dictionary).duplicate(true)
	player["cash"] = cash
	players[player_index] = player
	_world.players = players


func _world_cash(player_index: int) -> int:
	return int((_world.players[player_index] as Dictionary).get("cash", -1))


func _world_slots(player_index: int) -> Array:
	return (((_world.players[player_index] as Dictionary).get("slots", [])) as Array).duplicate(true)


func _world_nonempty_slot_count(player_index: int) -> int:
	var count := 0
	for slot_variant in _world_slots(player_index):
		if slot_variant is Dictionary:
			count += 1
	return count


func _world_card_count(player_index: int, card_id: String) -> int:
	var count := 0
	for slot_variant in _world_slots(player_index):
		if slot_variant is Dictionary and _machine_card_id(slot_variant as Dictionary) == card_id:
			count += 1
	return count


func _world_has_card(player_index: int, card_id: String) -> bool:
	return _world_card_count(player_index, card_id) > 0


func _machine_card_id(card: Dictionary) -> String:
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	return str(machine.get("card_id", card.get("card_id", card.get("name", ""))))


func _world_hand_fingerprint(player_index: int) -> String:
	return JSON.stringify(_world_slots(player_index))


func _facility_owner(facility_id: String) -> int:
	for row_variant in _infrastructure.facilities_snapshot(false):
		if row_variant is Dictionary and str((row_variant as Dictionary).get("facility_id", "")) == facility_id:
			return int((row_variant as Dictionary).get("owner_player_index", -1))
	return -1


func _facility_by_id(facility_id: String) -> Dictionary:
	for row_variant in _infrastructure.facilities_snapshot(false):
		if row_variant is Dictionary and str((row_variant as Dictionary).get("facility_id", "")) == facility_id:
			return (row_variant as Dictionary).duplicate(true)
	return {}


func _installed_rate_for_rank(rank: int) -> int:
	for row_variant in _flow.installations_snapshot(true):
		if row_variant is Dictionary and int((row_variant as Dictionary).get("source_card_rank", 0)) == rank:
			return int((row_variant as Dictionary).get("base_units_per_minute", 0))
	return -1


func _receipt_evidence(receipt: Dictionary) -> Dictionary:
	return {
		"committed": receipt.get("committed", false),
		"reason_code": receipt.get("reason_code", receipt.get("reason", "")),
		"operation": receipt.get("operation", ""),
		"outcome": receipt.get("outcome", ""),
		"idempotent_replay": receipt.get("idempotent_replay", false),
	}


func _case_already_passed(case_id: String) -> bool:
	for record_variant in _records:
		if record_variant is Dictionary and str((record_variant as Dictionary).get("case_id", "")) == case_id:
			return bool((record_variant as Dictionary).get("passed", false))
	return false


func _roman(rank: int) -> String:
	return ["", "I", "II", "III", "IV"][clampi(rank, 0, 4)]


func _write_outputs(manifest: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var manifest_file := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if manifest_file != null:
		manifest_file.store_string(JSON.stringify(manifest, "  "))
	var report_file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if report_file == null:
		return
	var lines: Array[String] = [
		"# SS06-06 Commodity Inventory and Persistent Installation", "",
		"- Ruleset: `v0.6`",
		"- Result: `%d/%d`" % [int(manifest.get("passed_count", 0)), int(manifest.get("record_count", 0))],
		"- Card Flow API owner: `CardFlowTransactionServiceV06`",
		"- Player-state mutation port: `CardPlayerStateProductionAdapterV06`",
		"- Installation owner: `CommodityFlowRuntimeController`",
		"- Viewer belt visibility: deferred to `SS06-07`", "",
		"| Case | Category | Passed |", "|---|---|---|",
	]
	for record_variant in _records:
		var record := record_variant as Dictionary
		lines.append("| `%s` | %s | %s |" % [str(record.get("case_id", "")), str(record.get("category", "")), "yes" if bool(record.get("passed", false)) else "no"])
	report_file.store_string("\n".join(lines) + "\n")


func _case_summary_text() -> String:
	var lines: Array[String] = ["[b]Focused cases[/b]"]
	for record_variant in _records:
		var record := record_variant as Dictionary
		var marker := "[color=#67e8a4]PASS[/color]" if bool(record.get("passed", false)) else "[color=#fb7185]FAIL[/color]"
		lines.append("%s  %s" % [marker, str(record.get("case_id", ""))])
	return "\n".join(lines)


func _save_screenshot() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://space_syndicate_design_qa/"))
	var image := get_viewport().get_texture().get_image()
	if image != null and not image.is_empty():
		image.save_png(ProjectSettings.globalize_path(SCREENSHOT_PATH))


func _is_pure_data(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item in value:
			if not _is_pure_data(item):
				return false
		return true
	if value is Dictionary:
		for key_variant in value.keys():
			if not _is_pure_data(key_variant) or not _is_pure_data(value.get(key_variant)):
				return false
		return true
	return false
