extends SceneTree

const Adapter := preload(
	"res://scripts/v075/ai/v075_combat_ai_adapter.gd"
)
const TrackCore := preload(
	"res://scripts/v07_semantic/v07_unified_card_track_core.gd"
)
const AssetCore := preload(
	"res://scripts/v07_semantic/v07_asset_batch_core.gd"
)
const Registry := preload(
	"res://scripts/v075/cards/v075_card_definition_registry.gd"
)
const PresentationBench := preload(
	"res://scripts/tools/v075/v075_combat_player_surface_bench.gd"
)

const PLAYER_ID := "player.ai.1"
const ROSTER := [
	"player.ai.1",
	"player.ai.2",
	"player.ai.3",
]
const COLORS := [
	"life",
	"energy",
	"industry",
	"technology",
	"commerce",
	"shipping",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var adapter := Adapter.new()
	_test_contract_snapshot(adapter)
	var available_assets := _real_asset_projection()
	_expect(
		available_assets.size() == COLORS.size(),
		"asset availability comes from AssetCore projection"
	)
	var records := _collect_real_track_records(adapter, available_assets)
	_test_zero_assets_do_not_gate_cash_purchase(adapter, records)
	_expect(
		records.has("facility"),
		"real ten-slot track produces a legal facility acquisition"
	)
	_expect(
		records.has("monster"),
		"real ten-slot track produces a legal monster acquisition"
	)
	_expect(
		records.has("military"),
		"real ten-slot track produces a legal military acquisition"
	)
	if records.has("mixed"):
		_test_mixed_priority(adapter, records.get("mixed", {}) as Dictionary)
	else:
		_failures.append("seed scan did not find a mixed facility/combat segment")
		_checks += 1
	if records.has("facility"):
		_test_record_invariants(
			adapter,
			records.get("facility", {}) as Dictionary,
			available_assets
		)
	_test_combat_follow_up_contracts(
		adapter,
		records,
		available_assets
	)
	_finish()


func _test_zero_assets_do_not_gate_cash_purchase(
	adapter: RefCounted,
	records: Dictionary
) -> void:
	var record := records.get("mixed", {}) as Dictionary
	var facts := (record.get("facts", {}) as Dictionary).duplicate(true)
	var zero_assets := {}
	for color_id in COLORS:
		zero_assets[color_id] = 0
	facts["available_unreserved_assets"] = zero_assets
	var result := adapter.enumerate_track_acquisition_candidates(
		facts,
		{"phase": "batch_active"}
	) as Dictionary
	var candidates := result.get("candidates", []) as Array
	_expect(
		bool(result.get("accepted", false)) and not candidates.is_empty(),
		"zero play assets do not hide cash-purchasable normal cards"
	)
	for candidate_variant in candidates:
		var candidate := candidate_variant as Dictionary
		_expect(
			str(candidate.get("purchase_cost_source", ""))
				== "cash_authority",
			"zero-asset acquisition remains delegated to cash authority"
		)


func _test_contract_snapshot(adapter: RefCounted) -> void:
	var snapshot: Dictionary = adapter.debug_snapshot()
	_expect(
		int(snapshot.get("track_local_visible_capacity", 0)) == 10,
		"adapter keeps ten local visible slots"
	)
	_expect(
		str(snapshot.get("track_refill_mode", ""))
			== "shared_scroll_vacancy"
		and bool(snapshot.get("track_slow_sushi_motion", false)),
		"adapter preserves the slow shared sushi track contract"
	)
	_expect(
		not bool(snapshot.get(
			"track_immediate_refill_on_acquisition",
			true
		))
		and int(snapshot.get("track_mutation_count", -1)) == 0
		and int(snapshot.get(
			"supply_cursor_delta_on_acquisition",
			-1
		)) == 0
		and int(snapshot.get("supply_rng_draw_delta_on_acquisition", -1)) == 0,
		"adapter has no refill, cursor, or RNG side effect"
	)
	_expect(
		int(snapshot.get("outer_normal_card_ratio_basis_points", 0)) == 6000
		and int(snapshot.get(
			"outer_commodity_card_ratio_basis_points",
			0
		)) == 4000,
		"adapter does not alter the outer 6000/4000 ratio"
	)
	_expect(
		(snapshot.get("normal_subtype_weights_basis_points", {}) as Dictionary)
			== {"facility": 7000, "monster": 1500, "military": 1500},
		"adapter does not alter the 7000/1500/1500 subtype weights"
	)


func _real_asset_projection() -> Dictionary:
	var initial_assets: Dictionary = {}
	var full_assets: Dictionary = {}
	for player_id in ROSTER:
		var player_assets: Dictionary = {}
		for color_id in COLORS:
			player_assets[color_id] = 6
		initial_assets[player_id] = player_assets
	var asset_state: Dictionary = AssetCore.create_state(
		"batch.natural.acquisition",
		ROSTER,
		ROSTER,
		initial_assets
	)
	if asset_state.is_empty():
		return {}
	var projection: Dictionary = AssetCore.asset_ai_observation(
		asset_state,
		PLAYER_ID
	)
	full_assets = (
		projection.get("own_available_assets", {}) as Dictionary
	).duplicate(true)
	return full_assets


func _collect_real_track_records(
	adapter: RefCounted,
	available_assets: Dictionary
) -> Dictionary:
	var records: Dictionary = {}
	var seeds := range(900626424, 900626824)
	for seed_variant in seeds:
		var seed := int(seed_variant)
		var track := TrackCore.new()
		var started: Dictionary = track.start_match(
			ROSTER,
			seed,
			{
				"balance_profile_id": TrackCore.BALANCE_PROFILE_ID,
				"balance_profile_fingerprint": (
					TrackCore.BALANCE_PROFILE_FINGERPRINT
				),
				"normal_card_ratio_basis_points": 6000,
				"commodity_card_ratio_basis_points": 4000,
				"local_visible_slot_count": 10,
				"match_instance_id": "match.natural.acquisition.%d" % seed,
				"card_definition_registry_id": Registry.REGISTRY_ID,
			}
		)
		if not bool(started.get("accepted", false)):
			continue
		var projection: Dictionary = track.player_projection_v1(PLAYER_ID)
		var facts := (
			projection.get("viewer_private_facts", {}) as Dictionary
		).duplicate(true)
		facts["viewer_player_id"] = PLAYER_ID
		facts["available_unreserved_assets"] = available_assets.duplicate(
			true
		)
		var before_facts := facts.duplicate(true)
		var before_authority: Dictionary = track.core_authority_v1()
		var acquisition: Dictionary = adapter.enumerate_track_acquisition_candidates(
			facts,
			{"phase": "batch_active"}
		)
		var after_authority: Dictionary = track.core_authority_v1()
		_expect(
			JSON.stringify(before_authority) == JSON.stringify(after_authority),
			"AI acquisition enumeration does not mutate track authority"
		)
		_expect(
			JSON.stringify(before_facts) == JSON.stringify(facts),
			"AI acquisition enumeration does not mutate private projection"
		)
		if not bool(acquisition.get("accepted", false)):
			continue
		var domains: Dictionary = {}
		for candidate_variant in acquisition.get("candidates", []) as Array:
			var candidate := candidate_variant as Dictionary
			domains[str(candidate.get("card_domain", ""))] = true
		if domains.size() >= 2 and not records.has("mixed"):
			records["mixed"] = {
				"seed": seed,
				"track": track,
				"facts": facts.duplicate(true),
				"acquisition": acquisition.duplicate(true),
			}
		for domain in ["facility", "monster", "military"]:
			if domains.has(domain) and not records.has(domain):
				records[domain] = {
					"seed": seed,
					"track": track,
					"facts": facts.duplicate(true),
					"acquisition": acquisition.duplicate(true),
				}
		if records.has("facility") and records.has("monster") \
				and records.has("military") and records.has("mixed"):
			break
	return records


func _test_mixed_priority(
	adapter: RefCounted,
	record: Dictionary
) -> void:
	var acquisition := record.get("acquisition", {}) as Dictionary
	var candidates := acquisition.get("candidates", []) as Array
	var facility_count := 0
	var combat_count := 0
	for candidate_variant in candidates:
		var candidate := candidate_variant as Dictionary
		var domain := str(candidate.get("card_domain", ""))
		if domain == "facility":
			facility_count += 1
		elif domain in ["monster", "military"]:
			combat_count += 1
	_expect(
		facility_count > 0 and combat_count > 0,
		"mixed real segment contains facility and combat opportunities"
	)
	var chosen: Dictionary = adapter.choose_track_acquisition(
		record.get("facts", {}) as Dictionary,
		{"phase": "batch_active"}
	)
	var action := chosen.get("action", {}) as Dictionary
	_expect(
		bool(chosen.get("accepted", false))
		and str(action.get("card_domain", "")) == "facility",
		"facility economy remains dominant when combat cards share the segment"
	)
	var audit := chosen.get("acquisition_audit", {}) as Dictionary
	_expect(
		bool(audit.get("facility_economy_dominant", false))
		and str(audit.get("top_domain", "")) == "facility",
		"natural acquisition audit records facility dominance"
	)
	_expect(
		str(audit.get("baseline_root_cause_code", "")).contains(
			"facility_only_auto_acquisition"
		),
		"audit records why the previous natural combat purchase was zero"
	)


func _test_record_invariants(
	adapter: RefCounted,
	record: Dictionary,
	available_assets: Dictionary
) -> void:
	var facts := (record.get("facts", {}) as Dictionary).duplicate(true)
	var result: Dictionary = adapter.audit_natural_acquisition(
		facts,
		{"phase": "batch_active"}
	)
	var candidates := result.get("candidates", []) as Array
	_expect(
		candidates.size() > 0,
		"natural acquisition audit exposes at least one legal card"
	)
	var projected_ids: Dictionary = {}
	for item_variant in facts.get("own_segment_items", []) as Array:
		var item := item_variant as Dictionary
		projected_ids[str(item.get("instance_id", ""))] = true
	for candidate_variant in candidates:
		var candidate := candidate_variant as Dictionary
		var instance_id := str(candidate.get("source_instance_id", ""))
		_expect(
			projected_ids.has(instance_id),
			"every acquisition intent points to a real projected instance"
		)
		_expect(
			not bool(candidate.get("target_bound", true))
			and str(candidate.get("target_id", "")) == ""
			and int(candidate.get(
				"supply_cursor_delta_on_acquisition",
				-1
			)) == 0
			and int(candidate.get(
				"supply_rng_draw_delta_on_acquisition",
				-1
			)) == 0,
			"acquisition intent injects no target or supply movement"
		)
		_expect(
			str(candidate.get("purchase_cost_source", ""))
				== "cash_authority"
				and int(candidate.get("play_asset_cost", -1))
					== int(candidate.get("primary_asset_cost", -2)),
			"track purchase uses cash authority while retaining the later play asset cost"
		)
		_expect(
			str(candidate.get("card_domain", "")) in [
				"facility",
				"monster",
				"military",
			],
			"only registered normal-card domains enter acquisition"
		)
		_expect(
			str(candidate.get("card_kind", "normal_card"))
			== "normal_card",
			"combat acquisition intent remains a normal card"
		)
	var audit := result.get("acquisition_audit", {}) as Dictionary
	_expect(
		int(audit.get("track_visible_capacity", 0)) == 10
		and str(audit.get("track_refill_mode", ""))
			== "shared_scroll_vacancy"
		and not bool(audit.get("immediate_refill_on_acquisition", true)),
		"audit preserves ten-slot slow shared-vacancy behavior"
	)
	_expect(
		int(audit.get("card_injection_count", -1)) == 0
		and int(audit.get("asset_injection_count", -1)) == 0
		and int(audit.get("target_injection_count", -1)) == 0
		and int(audit.get("rng_draw_count", -1)) == 0,
		"audit proves no card, asset, target, or RNG injection"
	)


func _test_combat_follow_up_contracts(
	adapter: RefCounted,
	records: Dictionary,
	available_assets: Dictionary
) -> void:
	var monster_candidate := _first_candidate(
		records.get("monster", {}) as Dictionary,
		"monster"
	)
	var military_candidate := _first_candidate(
		records.get("military", {}) as Dictionary,
		"military"
	)
	if monster_candidate.is_empty() or military_candidate.is_empty():
		_checks += 2
		_failures.append("real combat candidates missing for follow-up contract")
		return
	var monster_contract := monster_candidate.get(
		"follow_up_contract",
		{}
	) as Dictionary
	_expect(
		monster_contract.get("allowed_modes", []) == [
			"DEPLOY_NEW",
			"REFRESH_EXISTING",
			"UPGRADE_EXISTING",
			"REPLACE_EXISTING",
		]
		and bool(monster_contract.get("requires_prebound_mode", false)),
		"monster acquisition advertises exactly four prebound modes"
	)
	var military_contract := military_candidate.get(
		"follow_up_contract",
		{}
	) as Dictionary
	_expect(
		military_contract.get("allowed_task_kinds", []) == [
			"assault_region",
			"assault_monster",
		]
		and bool(military_contract.get("requires_prebound_task", false)),
		"military acquisition advertises exactly two assault tasks"
	)
	var monster_card_id := str(monster_candidate.get("card_instance_id", ""))
	var monster_definition_id := str(monster_candidate.get(
		"card_definition_id",
		""
	))
	var monster_binding := PresentationBench.make_card_action_binding_fixture(
		PLAYER_ID,
		monster_card_id,
		monster_definition_id,
		3
	)
	var monster_options: Array = []
	for mode_variant in monster_contract.get("allowed_modes", []) as Array:
		var mode := str(mode_variant)
		var target_id := (
			"region.contract.deploy"
			if mode == "DEPLOY_NEW"
			else "monster.contract.source"
		)
		monster_options.append({
			"option_id": "option.contract.monster.%s" % mode.to_lower(),
			"action_domain": "monster",
			"card_instance_id": monster_card_id,
			"card_definition_id": monster_definition_id,
			"card_rank": int(monster_candidate.get("card_rank", 1)),
			"monster_card_mode": mode,
			"target_slot_id": "combat.contract.monster.%s" % mode.to_lower(),
			"target_region_id": target_id if mode == "DEPLOY_NEW" else "",
			"target_source_instance_id": target_id if mode != "DEPLOY_NEW" else "",
			"card_action_binding": monster_binding.duplicate(true),
		})
	var military_card_id := str(military_candidate.get("card_instance_id", ""))
	var military_definition_id := str(military_candidate.get(
		"card_definition_id",
		""
	))
	var military_binding := PresentationBench.make_card_action_binding_fixture(
		PLAYER_ID,
		military_card_id,
		military_definition_id,
		3
	)
	var military_options: Array = [{
		"option_id": "option.contract.military.region",
		"owner_player_id": PLAYER_ID,
		"action_domain": "military",
		"card_instance_id": military_card_id,
		"card_definition_id": military_definition_id,
		"card_action_binding": military_binding.duplicate(true),
		"target_slot_id": "combat.contract.military.region",
		"task_kind": "assault_region",
		"target_region_id": "region.contract.deploy",
		"target_monster_source_instance_id": "",
		"launch_region_id": "region.contract.launch",
		"asset_cost_by_color": {},
		"enabled": true,
	}, {
		"option_id": "option.contract.military.monster",
		"owner_player_id": PLAYER_ID,
		"action_domain": "military",
		"card_instance_id": military_card_id,
		"card_definition_id": military_definition_id,
		"card_action_binding": military_binding.duplicate(true),
		"target_slot_id": "combat.contract.military.monster",
		"task_kind": "assault_monster",
		"target_region_id": "",
		"target_monster_source_instance_id": "monster.contract.enemy",
		"target_source_generation": 1,
		"launch_region_id": "region.contract.launch",
		"asset_cost_by_color": {},
		"enabled": true,
	}]
	var own := {
		"viewer_player_id": PLAYER_ID,
		"available_unreserved_assets": available_assets.duplicate(true),
		"monster_card_options": [{
			"card_instance_id": monster_card_id,
			"card_definition_id": monster_definition_id,
			"card_rank": int(monster_candidate.get("card_rank", 1)),
			"legal_modes": monster_contract.get("allowed_modes", []),
			"options": monster_options,
		}],
		"military_card_options": [{
			"card_instance_id": military_card_id,
			"card_definition_id": military_definition_id,
			"legal_task_kinds": military_contract.get(
				"allowed_task_kinds",
				[]
			),
			"options": military_options,
		}],
		"military_options": military_options,
		"owned_monsters": [],
	}
	var public := {
		"phase": "batch_active",
		"regions": ["region.contract.deploy"],
		"facilities": [{
			"facility_id": "facility.contract.enemy",
			"owner_player_id": "player.ai.2",
			"region_id": "region.contract.deploy",
			"status": "active",
		}],
		"monsters": [{
			"source_instance_id": "monster.contract.enemy",
			"owner_player_id": "player.ai.2",
			"status": "active",
		}],
	}
	var combat_result: Dictionary = adapter.enumerate_candidates(own, public)
	var modes: Dictionary = {}
	var task_kinds: Dictionary = {}
	for candidate_variant in combat_result.get("candidates", []) as Array:
		var candidate := candidate_variant as Dictionary
		var mode := str(candidate.get("monster_card_mode", ""))
		if not mode.is_empty():
			modes[mode] = true
		var task := str(candidate.get("task_kind", ""))
		if not task.is_empty():
			task_kinds[task] = true
	_expect(
		modes.size() == 4
		and task_kinds.has("assault_region")
		and task_kinds.has("assault_monster"),
		"natural combat cards retain legal prebound mode/task choices"
	)


func _first_candidate(record: Dictionary, domain: String) -> Dictionary:
	for candidate_variant in (
		record.get("acquisition", {}) as Dictionary
	).get("candidates", []) as Array:
		var candidate := candidate_variant as Dictionary
		if str(candidate.get("card_domain", "")) == domain:
			return candidate.duplicate(true)
	return {}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error("V075_COMBAT_AI_NATURAL_ACQUISITION_TEST|FAIL|%s" % message)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print(
		"V075_COMBAT_AI_NATURAL_ACQUISITION_TEST|status=%s|passed=%d|total=%d|failures=%s"
		% [
			status,
			_checks - _failures.size(),
			_checks,
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)
