extends SceneTree

const CapabilityCatalog := preload(
	"res://scripts/v075/combat/v075_combat_capability_catalog.gd"
)
const CombatCatalog := preload(
	"res://scripts/v075/combat/v075_combat_catalog.gd"
)
const CombatCandidate := preload(
	"res://scripts/v075/ai/v075_ai_combat_action_candidate_v1.gd"
)
const DbgCore := preload(
	"res://scripts/v07_semantic/v07_dbg_deck_core.gd"
)
const AssetBatchCore := preload(
	"res://scripts/v07_semantic/v07_asset_batch_core.gd"
)
const FacilityCore := preload(
	"res://scripts/v074/facility/v074_facility_runtime_core.gd"
)
const PublicActionBatchCore := preload(
	"res://scripts/v075/runtime/v075_public_action_batch_core.gd"
)
const CombatAIAdapter := preload(
	"res://scripts/v075/ai/v075_combat_ai_adapter.gd"
)
const MonsterCore := preload(
	"res://scripts/v075/monster/v075_monster_source_core.gd"
)
const CapacityPort := preload(
	"res://scripts/v075/monster/v075_character_monster_capacity_port.gd"
)
const MilitaryCore := preload(
	"res://scripts/v075/military/v075_military_mission_core.gd"
)
const CombatOwner := preload(
	"res://scripts/v075/runtime/v075_combat_runtime_owner.gd"
)
const COMPOSITION_PATH := "res://scenes/runtime/V075RuntimeComposition.tscn"
const ACTOR_ID := "player.alpha"
const CONTRACT_TEST_NAMES := [
	"v075_ai_combat_capability_catalog_test",
	"v075_ai_monster_mode_catalog_exact_four_test",
	"v075_ai_monster_mode_candidate_legality_test",
	"v075_ai_monster_mode_prebinding_test",
	"v075_ai_monster_mode_no_runtime_conversion_test",
	"v075_ai_monster_mode_lineage_test",
	"v075_ai_military_mission_catalog_exact_two_test",
	"v075_ai_military_candidate_legality_test",
	"v075_ai_military_prebinding_test",
	"v075_ai_military_no_guard_test",
	"v075_ai_military_no_retarget_test",
	"v075_ai_combat_candidate_privacy_test",
	"v075_ai_combat_candidate_determinism_test",
	"v075_ai_combat_candidate_order_stability_test",
	"v075_combat_ai_test",
]

var _checks := 0
var _failures: Array[String] = []
var _fixture_candidates: Array[Dictionary] = []
var _lineage_pass_count := 0
var _core_lineage_pass_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_catalog_contract()
	await _test_production_composition()
	await _test_production_capability_lineage_fixtures()
	_test_monster_dynamic_fixtures()
	_test_military_dynamic_fixtures()
	_test_candidate_schema_fail_closed()
	_test_privacy_fail_closed()
	_test_candidate_order_determinism()
	_test_policy_oracle_coverage()
	_expect(
		_lineage_pass_count == 6,
		"all six production capability fixtures preserve prebound lineage"
	)
	_expect(
		_core_lineage_pass_count == 6,
		"all six core contract fixtures preserve Candidate-to-Receipt lineage"
	)
	_expect(
		CONTRACT_TEST_NAMES.size() == 15,
		"Gate 60 covers the complete named focused contract inventory"
	)
	_finish()


func _test_catalog_contract() -> void:
	var report := CapabilityCatalog.validation_report()
	var product_report := CombatCatalog.validation_report()
	_expect(
		bool(report.get("valid", false))
		and CapabilityCatalog.monster_card_modes() == [
			"DEPLOY_NEW",
			"REFRESH_EXISTING",
			"UPGRADE_EXISTING",
			"REPLACE_EXISTING",
		]
		and int(report.get("monster_mode_count", 0)) == 4,
		"catalog exposes exactly four supported monster modes"
	)
	_expect(
		CapabilityCatalog.military_mission_kinds() == [
			"assault_region",
			"assault_monster",
		]
		and int(report.get("military_mission_count", 0)) == 2,
		"catalog exposes exactly two supported military missions"
	)
	_expect(
		int(report.get("capability_catalog_owner_count", 0)) == 1,
		"one production owner defines both combat capability catalogs"
	)
	_expect(
		bool(product_report.get("valid", false))
		and int(product_report.get("capability_duplicate_definition_count", -1)) == 0,
		"active product data derives capabilities from the single typed catalog"
	)


func _test_production_composition() -> void:
	var packed := load(COMPOSITION_PATH) as PackedScene
	_expect(packed != null, "production V075RuntimeComposition loads")
	if packed == null:
		return
	var composition := packed.instantiate()
	root.add_child(composition)
	await process_frame
	await process_frame
	var runtime := composition.get_node_or_null("V075RuntimeOwner")
	var combat := composition.get_node_or_null("V075CombatRuntimeOwner")
	_expect(runtime != null and combat != null, "production composition owns runtime and combat authorities")
	if runtime == null or combat == null:
		composition.queue_free()
		await process_frame
		return
	var started := composition.call("_start_new_game", {
		"player_count": 4,
		"seed": 900626424,
		"accelerated": false,
		"automate_local_human": false,
		"map_seed": 900626424,
		"region_count": 16,
		"geography_complexity": "STANDARD",
		"land_ocean_profile": "BALANCED",
	}) as Dictionary
	if not bool(started.get("accepted", false)):
		print("V075_COMBAT_AI_COMPOSITION_START_DIAGNOSTIC|%s" % JSON.stringify(started))
	_expect(bool(started.get("accepted", false)), "production composition starts an exact-seed V0.7.5 match")
	if bool(started.get("accepted", false)):
		var first := runtime.call("ai_observation", "player.ai.1") as Dictionary
		var second := runtime.call("ai_observation", "player.ai.1") as Dictionary
		_expect(
			first.get("monster_mode_capabilities") == CapabilityCatalog.monster_card_modes()
			and first.get("military_mission_capabilities") == CapabilityCatalog.military_mission_kinds(),
			"real AI observation separates supported catalogs from current candidates"
		)
		_expect(
			first.get("combat_candidates") == second.get("combat_candidates"),
			"repeated real AI observation preserves candidate bytes and order"
		)
		for candidate_variant in first.get("combat_candidates", []) as Array:
			_expect(
				bool(CombatCandidate.validation_report(candidate_variant).get("valid", false)),
				"every real AI observation candidate validates as V075AICombatActionCandidateV1"
			)
		var public_projection := combat.call(
			"projection_authority_for_viewer",
			"",
			{}
		) as Dictionary
		_expect(
			_public_candidate_leak_count(public_projection) == 0,
			"public combat authority projection exposes no candidate row or private binding"
		)
	composition.queue_free()
	await process_frame


func _test_monster_dynamic_fixtures() -> void:
	var alpha := _monster_definition("alpha", "life")
	var beta := _monster_definition("beta", "energy")
	var deploy_state := MonsterCore.new_state(
		[ACTOR_ID],
		{ACTOR_ID: CapacityPort.build_semantic(ACTOR_ID, 1)}
	)
	_test_monster_fixture(
		"DEPLOY_NEW",
		deploy_state,
		_monster_request("deploy", "card.alpha.deploy", "definition.alpha.deploy", 1, "DEPLOY_NEW", "region.deploy", ""),
		alpha
	)
	var damaged := MonsterCore.build_source_snapshot(
		alpha, "monster.alpha.damaged", ACTOR_ID, "region.alpha", 3, 100,
		"active", 2, "card.origin.alpha"
	)
	_test_monster_fixture(
		"REFRESH_EXISTING",
		MonsterCore.new_state([ACTOR_ID], {}, [damaged]),
		_monster_request("refresh", "card.alpha.refresh", "definition.alpha.refresh", 1, "REFRESH_EXISTING", "", "monster.alpha.damaged"),
		alpha
	)
	var low_rank := MonsterCore.build_source_snapshot(
		alpha, "monster.alpha.low", ACTOR_ID, "region.alpha", 1, 20,
		"active", 3, "card.origin.low"
	)
	_test_monster_fixture(
		"UPGRADE_EXISTING",
		MonsterCore.new_state([ACTOR_ID], {}, [low_rank]),
		_monster_request("upgrade", "card.alpha.upgrade", "definition.alpha.upgrade", 4, "UPGRADE_EXISTING", "", "monster.alpha.low"),
		alpha
	)
	var old_source := MonsterCore.build_source_snapshot(
		alpha, "monster.alpha.replace", ACTOR_ID, "region.alpha", 2, 120,
		"active", 4, "card.origin.replace"
	)
	_test_monster_fixture(
		"REPLACE_EXISTING",
		MonsterCore.new_state([ACTOR_ID], {}, [old_source]),
		_monster_request("replace", "card.beta.replace", "definition.beta.replace", 2, "REPLACE_EXISTING", "region.beta", "monster.alpha.replace"),
		beta
	)


func _test_monster_fixture(
	mode: String,
	state: Dictionary,
	request: Dictionary,
	definition: Dictionary
) -> void:
	var bound := MonsterCore.prebind_card_mode(state, request, definition)
	var action := bound.get("action", {}) as Dictionary
	_expect(
		bool(bound.get("accepted", false))
		and action.get("monster_card_mode") == mode
		and action.get("prebound") == true
		and action.get("mode_auto_conversion_allowed") == false,
		"%s fixture produces one explicit production prebound action" % mode
	)
	if not bool(bound.get("accepted", false)):
		return
	_expect(
		(
			mode == "REFRESH_EXISTING"
			and int(action.get("expected_hp_revision", -1)) >= 0
		) or (
			mode != "REFRESH_EXISTING"
			and int(action.get("expected_hp_revision", -2)) == -1
		),
		"%s fixture uses an explicit HP-revision binding or sentinel" % mode
	)
	var option := _monster_option(action, mode, 7)
	var candidate := CombatCandidate.monster_candidate(option, _monster_score(mode, int(action.get("card_rank", 1))))
	var validation := CombatCandidate.validation_report(candidate)
	_expect(
		not candidate.is_empty() and bool(validation.get("valid", false)),
		"%s fixture builds a legal typed candidate without manufacturing catalog coverage" % mode
	)
	if candidate.is_empty():
		return
	if mode == "REFRESH_EXISTING":
		var intervening := MonsterCore.commit_combat_damage(
			state,
			"operation.refresh.stale",
			str(action.get("target_source_instance_id", "")),
			int(action.get("target_source_generation", 0)),
			1
		)
		var stale_result := MonsterCore.resolve_prebound_card(
			intervening.get("state", {}) as Dictionary,
			action
		)
		var stale_receipt := stale_result.get("receipt", {}) as Dictionary
		_expect(
			bool(intervening.get("accepted", false))
			and bool(stale_result.get("accepted", false))
			and stale_receipt.get("outcome_id") == "monster_card_fizzled"
			and stale_receipt.get("reason_code") == "monster_refresh_hp_revision_changed",
			"refresh target HP revision drift produces one typed fizzle"
		)
	_fixture_candidates.append(candidate.duplicate(true))
	var result := MonsterCore.resolve_prebound_card(
		state,
		candidate.get("prebound_monster_action", {}) as Dictionary
	)
	var receipt := result.get("receipt", {}) as Dictionary
	var lineage_green: bool = (
		bool(result.get("accepted", false))
		and receipt.get("monster_card_mode") == mode
		and receipt.get("mode_auto_converted") == false
		and int(receipt.get("mode_auto_conversion_count", -1)) == 0
		and receipt.get("action_fingerprint") == action.get("action_fingerprint")
	)
	_expect(lineage_green, "%s Candidate-to-Receipt lineage remains unchanged" % mode)
	if lineage_green:
		_core_lineage_pass_count += 1


func _test_military_dynamic_fixtures() -> void:
	var combat := CombatOwner.new()
	var authority := MilitaryCore.build_card_authority(
		"military.fixture.rank.2", 2, 8, 6, "effect.military.fixture", 3
	)
	var facilities := [
		_facility("facility.enemy.b", 2, "market", "commerce"),
		_facility("facility.enemy.a", 1, "factory", "life"),
	]
	var region_request := MilitaryCore.build_region_request(
		"request.region.fixture", "mission.region.fixture", ACTOR_ID,
		"card.military.region", "slot.region", "reservation.region",
		"region.enemy"
	)
	var region_lock := MilitaryCore.lock_region_assault(
		region_request, authority, 11, facilities
	)
	var region_envelope := combat.military_target_envelope(region_lock)
	_test_military_fixture(
		"assault_region", region_lock, region_envelope, facilities, []
	)
	var monster_request := MilitaryCore.build_monster_request(
		"request.monster.fixture", "mission.monster.fixture", ACTOR_ID,
		"card.military.monster", "slot.monster", "reservation.monster",
		"monster.enemy.fixture"
	)
	var monster_snapshot := _enemy_monster("monster.enemy.fixture", 4, 12, "region.enemy")
	var monster_lock := MilitaryCore.lock_monster_assault(
		monster_request, authority, [monster_snapshot]
	)
	var monster_envelope := combat.military_target_envelope(monster_lock)
	_test_military_fixture(
		"assault_monster", monster_lock, monster_envelope, [], [monster_snapshot]
	)
	var guard_option := _military_option(
		"guard_region", region_envelope, "card.military.guard", 1
	)
	_expect(
		CombatCandidate.military_candidate(guard_option, 1).is_empty(),
		"legacy guard mission fails closed and cannot become a candidate"
	)
	combat.free()


func _test_military_fixture(
	mission_kind: String,
	locked: Dictionary,
	envelope: Dictionary,
	facilities: Array,
	monsters: Array
) -> void:
	_expect(
		bool(MilitaryCore.mission_lock_validation_report(locked).get("valid", false))
		and not envelope.is_empty(),
		"%s fixture uses a valid production lock preview envelope" % mission_kind
	)
	if envelope.is_empty():
		return
	var option := _military_option(
		mission_kind,
		envelope,
		str(locked.get("card_instance_id", "")),
		2
	)
	var score := 640 if mission_kind == "assault_monster" else 610
	var candidate := CombatCandidate.military_candidate(option, score)
	_expect(
		not candidate.is_empty()
		and bool(CombatCandidate.validation_report(candidate).get("valid", false)),
		"%s fixture builds one legal target-envelope candidate" % mission_kind
	)
	if candidate.is_empty():
		return
	var canonical_again := CombatCandidate.military_candidate(candidate, score)
	_expect(
		not canonical_again.is_empty()
		and int(canonical_again.get("primary_asset_cost", -1))
			== int(candidate.get("primary_asset_cost", -2))
		and canonical_again.get("asset_cost") == candidate.get("asset_cost")
		and str(canonical_again.get("candidate_fingerprint", ""))
			== str(candidate.get("candidate_fingerprint", "")),
		"%s canonical candidate normalization preserves cost and identity"
		% mission_kind
	)
	_fixture_candidates.append(candidate.duplicate(true))
	var receipt := (
		MilitaryCore.resolve_region_assault(locked, facilities)
		if mission_kind == "assault_region"
		else MilitaryCore.resolve_monster_assault(locked, monsters)
	) as Dictionary
	var lineage_green: bool = (
		str(receipt.get("task_kind", "")) == mission_kind
		and int(receipt.get("retarget_count", -1)) == 0
		and int(receipt.get("bound_action_count", -1)) == 0
	)
	_expect(lineage_green, "%s Candidate-to-Receipt lineage never retargets or converts" % mission_kind)
	if lineage_green:
		_core_lineage_pass_count += 1
	if mission_kind == "assault_region":
		var drifted_facilities := facilities.duplicate(true)
		var drifted_facility := (drifted_facilities[0] as Dictionary).duplicate(true)
		drifted_facility["facility_generation"] = int(
			drifted_facility.get("facility_generation", 0)
		) + 1
		drifted_facilities[0] = drifted_facility
		var stale_region := MilitaryCore.resolve_region_assault(
			locked,
			drifted_facilities
		)
		_expect(
			stale_region.get("outcome") == "fizzled"
			and stale_region.get("reason_code") == "locked_facility_target_invalid"
			and int(stale_region.get("allocated_damage_total", -1)) == 0
			and int(stale_region.get("retarget_count", -1)) == 0,
			"one stale locked facility fizzles the full mission without reallocating damage"
		)
	if mission_kind == "assault_monster":
		var revision_drift := monsters.duplicate(true)
		var revision_target := (revision_drift[0] as Dictionary).duplicate(true)
		revision_target["damage_revision"] = int(
			revision_target.get("damage_revision", 0)
		) + 1
		revision_drift[0] = revision_target
		var stale_revision := MilitaryCore.resolve_monster_assault(
			locked,
			revision_drift
		)
		var region_drift := monsters.duplicate(true)
		var region_target := (region_drift[0] as Dictionary).duplicate(true)
		region_target["region_id"] = "region.other"
		region_drift[0] = region_target
		var stale_region := MilitaryCore.resolve_monster_assault(locked, region_drift)
		_expect(
			stale_revision.get("outcome") == "fizzled"
			and stale_region.get("outcome") == "fizzled"
			and int(stale_revision.get("retarget_count", -1)) == 0
			and int(stale_region.get("retarget_count", -1)) == 0,
			"monster revision or region drift fizzles without retargeting"
		)
		var stale := _enemy_monster("monster.enemy.replacement", 1, 1, "region.other")
		var stale_receipt := MilitaryCore.resolve_monster_assault(locked, [stale])
		_expect(
			stale_receipt.get("outcome") == "fizzled"
			and int(stale_receipt.get("retarget_count", -1)) == 0,
			"stale military target fizzles without selecting a replacement"
		)


func _test_candidate_schema_fail_closed() -> void:
	_expect(_fixture_candidates.size() == 6, "six dynamic fixtures produced six typed candidates")
	if _fixture_candidates.is_empty():
		return
	var baseline := _fixture_candidates[0]
	for mutation in [
		{"field": "unknown_field", "value": 1},
		{"field": "legality_reason", "value": null},
		{"field": "score", "value": 1.5},
		{"field": "expected_world_revision", "value": null},
	]:
		var malformed := baseline.duplicate(true)
		malformed[mutation.get("field")] = mutation.get("value")
		_expect(
			not bool(CombatCandidate.validation_report(malformed).get("valid", true)),
			"candidate schema rejects unknown, null and float top-level values"
		)
	var nested_null := baseline.duplicate(true)
	(nested_null.get("target_binding") as Dictionary)["target_kind"] = null
	_expect(
		not bool(CombatCandidate.validation_report(nested_null).get("valid", true)),
		"candidate schema rejects null nested collection elements"
	)
	var forged_public := baseline.duplicate(true)
	forged_public["public_information_fingerprint"] = "f".repeat(64)
	_expect(
		not bool(CombatCandidate.validation_report(forged_public).get("valid", true)),
		"candidate schema recomputes rather than trusts public fingerprints"
	)


func _test_privacy_fail_closed() -> void:
	var adapter := CombatAIAdapter.new()
	var own := {"viewer_player_id": ACTOR_ID, "owned_monsters": []}
	for forbidden_key in [
		"combat_private_facts",
		"combat_candidates",
		"monster_mode_candidates",
		"military_mission_candidates",
		"prebound_monster_action",
		"military_target_envelope",
		"target_binding",
		"candidate_fingerprint",
		"private_information_fingerprint",
		"public_information_fingerprint",
		"priority_features",
		"expected_world_revision",
		"expected_region_revision",
		"expected_hp_revision",
	]:
		var public_facts := {"phase": "batch_active", "regions": []}
		public_facts[forbidden_key] = {"canary": "private"}
		var result := adapter.enumerate_candidates(own, public_facts)
		_expect(
			not bool(result.get("accepted", true))
			and int(result.get("hidden_info_violation_count", 0)) == 1,
			"public AI facts reject private candidate field %s" % forbidden_key
		)


func _test_candidate_order_determinism() -> void:
	var adapter := CombatAIAdapter.new()
	var monster_rows: Array = []
	var military_rows: Array = []
	for candidate in _fixture_candidates:
		if candidate.get("variant_type") == CombatCandidate.VARIANT_MONSTER_CARD:
			monster_rows.append(candidate.duplicate(true))
		else:
			military_rows.append(candidate.duplicate(true))
	var own := {
		"viewer_player_id": ACTOR_ID,
		"monster_card_options": _group_candidates(monster_rows, "monster"),
		"military_card_options": _group_candidates(military_rows, "military"),
		"military_options": [],
		"owned_monsters": [],
		"available_unreserved_assets": _six_assets(20),
	}
	var public_facts := {
		"phase": "batch_active",
		"regions": ["region.alpha", "region.beta", "region.enemy"],
		"facilities": [
			_facility("facility.enemy.a", 1, "factory", "life"),
		],
		"monsters": [
			_enemy_monster("monster.enemy.fixture", 4, 12, "region.enemy"),
		],
	}
	var first := adapter.enumerate_candidates(own, public_facts)
	var second := adapter.enumerate_candidates(own, public_facts)
	_expect(
		JSON.stringify(first.get("candidates", [])) == JSON.stringify(second.get("candidates", [])),
		"same authorized private/public snapshots produce identical candidate order"
	)


func _test_policy_oracle_coverage() -> void:
	var adapter := CombatAIAdapter.new()
	var own := {
		"viewer_player_id": ACTOR_ID,
		"available_unreserved_assets": _six_assets(6),
		"monster_card_options": [],
		"military_card_options": [],
		"military_options": [],
		"owned_monsters": [
			{
				"source_instance_id": "monster.oracle.owner",
				"source_generation": 1,
				"owner_player_id": ACTOR_ID,
				"status": "active",
				"hp": 80,
				"max_hp": 100,
				"batch_active_skill_used": false,
				"private_skills": [
					{
						"skill_definition_id": "skill.oracle.owner",
						"state": "READY",
						"effect_kind": "single_facility_damage",
						"asset_cost_by_color": {"technology": 1},
						"target_contract": "enemy_facility",
						"target_binding": {
							"target_kind": "enemy_public_facility",
							"target_id": "facility.enemy.oracle",
							"target_generation": 1,
						},
						"ultimate": false,
					},
				],
			},
		],
	}
	var public_facts := {
		"phase": "batch_active",
		"regions": ["region.oracle"],
		"facilities": [
			_facility("facility.enemy.oracle", 1, "factory", "technology"),
		],
		"monsters": [],
	}
	var enumerated := adapter.enumerate_candidates(own, public_facts)
	var private_skill_count := 0
	for candidate_variant in enumerated.get("candidates", []) as Array:
		if str((candidate_variant as Dictionary).get(
			"action_kind", ""
		)) == "monster_private_skill":
			private_skill_count += 1
	_expect(
		bool(enumerated.get("accepted", false)) and private_skill_count == 1,
		"owner-private ready skill remains one legal AI candidate"
	)
	var first_choice := adapter.choose_action(own, public_facts)
	var second_choice := adapter.choose_action(own, public_facts)
	_expect(
		JSON.stringify(first_choice) == JSON.stringify(second_choice),
		"combat AI choose_action remains deterministic without RNG"
	)
	var no_action_own := {
		"viewer_player_id": ACTOR_ID,
		"owned_monsters": [],
	}
	var no_action := adapter.choose_action(no_action_own, public_facts)
	_expect(
		not bool(no_action.get("accepted", true))
		and str(no_action.get("reason_code", "")) == "no_legal_combat_action",
		"combat AI preserves the stable no-action reason"
	)
	for terminal_phase in ["victory_pending", "final_settlement"]:
		var terminal_facts := public_facts.duplicate(true)
		terminal_facts["phase"] = terminal_phase
		var terminal := adapter.enumerate_candidates(own, terminal_facts)
		_expect(
			(terminal.get("candidates", []) as Array).is_empty()
			and str(terminal.get("reason_code", "")) == "terminal_combat_quiescent",
			"%s produces no new combat candidate" % terminal_phase
		)
	for leaked_key in [
		"private_skill_zones_by_player",
		"opponent_skill_cooldowns",
	]:
		var leaked := public_facts.duplicate(true)
		leaked[leaked_key] = {"player.rival": ["hidden"]}
		var rejected := adapter.enumerate_candidates(own, leaked)
		_expect(
			not bool(rejected.get("accepted", true))
			and str(rejected.get("reason_code", "")).begins_with(
				"public_facts_contains_private_field"
			),
			"public AI projection rejects %s" % leaked_key
		)


func _test_production_capability_lineage_fixtures() -> void:
	var fixtures := [
		{
			"capability": "DEPLOY_NEW",
			"domain": "monster",
			"card_type": "monster.spore_tide_emperor",
			"card_rank": 1,
			"monster_setup": "empty",
		},
		{
			"capability": "REFRESH_EXISTING",
			"domain": "monster",
			"card_type": "monster.spore_tide_emperor",
			"card_rank": 1,
			"monster_setup": "damaged_same_family",
		},
		{
			"capability": "UPGRADE_EXISTING",
			"domain": "monster",
			"card_type": "monster.spore_tide_emperor",
			"card_rank": 2,
			"monster_setup": "lower_rank_same_family",
		},
		{
			"capability": "REPLACE_EXISTING",
			"domain": "monster",
			"card_type": "monster.meteor_sentinel",
			"card_rank": 1,
			"monster_setup": "capacity_full_other_family",
		},
		{
			"capability": "assault_region",
			"domain": "military",
			"card_type": "military.planetary_defense_force",
			"card_rank": 1,
			"monster_setup": "empty",
		},
		{
			"capability": "assault_monster",
			"domain": "military",
			"card_type": "military.planetary_defense_force",
			"card_rank": 1,
			"monster_setup": "enemy_monster",
		},
	]
	for fixture_variant in fixtures:
		var fixture := fixture_variant as Dictionary
		var result: Dictionary = await _run_production_capability_fixture(fixture)
		_expect(
			bool(result.get("green", false)),
			"%s traverses RuntimeComposition, AI, queue, lock, runtime and receipt: %s"
			% [
				str(fixture.get("capability", "")),
				JSON.stringify(result),
			]
		)
		if bool(result.get("green", false)):
			_lineage_pass_count += 1


func _run_production_capability_fixture(spec: Dictionary) -> Dictionary:
	var packed := load(COMPOSITION_PATH) as PackedScene
	if packed == null:
		return {"green": false, "reason_code": "composition_missing"}
	var composition := packed.instantiate()
	root.add_child(composition)
	await process_frame
	await process_frame
	var runtime := composition.get_node_or_null("V075RuntimeOwner")
	var combat := composition.get_node_or_null("V075CombatRuntimeOwner")
	if runtime == null or combat == null:
		composition.queue_free()
		await process_frame
		return {"green": false, "reason_code": "production_owner_missing"}
	var seed_offset := int(str(spec.get("capability", "")).sha256_text().substr(
		0, 8
	).hex_to_int())
	var seed := 901000000 + absi(seed_offset % 1000000)
	var started := composition.call("_start_new_game", {
		"player_count": 4,
		"seed": seed,
		"accelerated": false,
		"automate_local_human": false,
		"map_seed": seed,
		"region_count": 16,
		"geography_complexity": "STANDARD",
		"land_ocean_profile": "BALANCED",
	}) as Dictionary
	if not bool(started.get("accepted", false)):
		composition.queue_free()
		await process_frame
		return {
			"green": false,
			"reason_code": "fixture_start_failed",
			"detail": started,
		}
	var actor_id := "player.ai.1"
	var asset_setup := _install_fixture_assets(runtime)
	if not bool(asset_setup.get("accepted", false)):
		composition.queue_free()
		await process_frame
		return {
			"green": false,
			"reason_code": "fixture_asset_state_invalid",
			"detail": asset_setup,
		}
	var region_ids := runtime.call("_runtime_region_ids") as Array
	if region_ids.is_empty():
		composition.queue_free()
		await process_frame
		return {"green": false, "reason_code": "fixture_region_missing"}
	var configured := _configure_fixture_monster_state(
		combat,
		runtime.player_ids(),
		actor_id,
		str(region_ids[0]),
		str(spec.get("monster_setup", ""))
	)
	if not bool(configured.get("accepted", false)):
		composition.queue_free()
		await process_frame
		return {
			"green": false,
			"reason_code": "fixture_monster_state_invalid",
			"detail": configured,
		}
	if str(spec.get("capability", "")) == "assault_region":
		var facility_setup := _install_fixture_enemy_facility(runtime, actor_id)
		if not bool(facility_setup.get("accepted", false)):
			composition.queue_free()
			await process_frame
			return {
				"green": false,
				"reason_code": "fixture_facility_state_invalid",
				"detail": facility_setup,
			}
	var installed := _install_fixture_card(
		runtime,
		actor_id,
		str(spec.get("card_type", "")),
		int(spec.get("card_rank", 0)),
		str(spec.get("capability", ""))
	)
	if not bool(installed.get("accepted", false)):
		composition.queue_free()
		await process_frame
		return {
			"green": false,
			"reason_code": "fixture_card_install_failed",
			"detail": installed,
		}
	runtime.call("_clear_v075_submission_caches")
	var observation := runtime.ai_observation(actor_id) as Dictionary
	var capability := str(spec.get("capability", ""))
	var domain := str(spec.get("domain", ""))
	var capability_list := (
		observation.get("monster_mode_capabilities", []) as Array
		if domain == "monster"
		else observation.get("military_mission_capabilities", []) as Array
	)
	var candidate := _production_candidate_for_capability(
		observation.get("combat_candidates", []) as Array,
		domain,
		capability,
		str(installed.get("card_instance_id", ""))
	)
	var legal := runtime.call(
		"_auto_legal_actions",
		actor_id
	) as Array
	var policy_plan := (
		runtime.call("_preferred_v075_ai_action", legal, actor_id) as Dictionary
		if not legal.is_empty()
		else {}
	)
	var policy_capability := str(policy_plan.get(
		"monster_card_mode" if domain == "monster" else "task_kind",
		""
	))
	var policy_candidate := _production_candidate_by_option_id(
		observation.get("combat_candidates", []) as Array,
		str(policy_plan.get("option_id", ""))
	)
	if policy_capability == capability and not policy_candidate.is_empty():
		candidate = policy_candidate
	var prebound_green := _production_candidate_prebound(
		candidate,
		domain,
		capability
	)
	var partial_candidate := candidate.duplicate(true)
	partial_candidate.erase("candidate_fingerprint")
	var partial_binding_rejected := not bool(runtime.queue_card_action(
		actor_id,
		str(candidate.get("card_instance_id", "")),
		str(candidate.get("target_slot_id", "")),
		partial_candidate
	).get("accepted", false))
	var convenience_partial_rejected := false
	if domain == "monster":
		convenience_partial_rejected = not bool(runtime.queue_monster_card_action(
			actor_id,
			str(candidate.get("card_instance_id", "")),
			capability,
			str(candidate.get("target_region_id", "")),
			str(candidate.get("target_source_instance_id", "")),
			candidate.get("card_action_binding", {}) as Dictionary
		).get("accepted", false))
	else:
		convenience_partial_rejected = not bool(runtime.queue_military_card_action(
			actor_id,
			str(candidate.get("card_instance_id", "")),
			capability,
			str(candidate.get("target_region_id", "")),
			str(candidate.get("target_monster_source_instance_id", "")),
			candidate.get("card_action_binding", {}) as Dictionary
		).get("accepted", false))
	var queued := {}
	if (
		capability_list.has(capability)
		and not candidate.is_empty()
		and policy_capability == capability
		and prebound_green
	):
		queued = runtime.queue_card_action(
			actor_id,
			str(candidate.get("card_instance_id", "")),
			str(candidate.get("target_slot_id", "")),
			candidate
		) as Dictionary
	var locked := bool(queued.get("accepted", false))
	var lock_reason := ""
	var lock_actor_id := ""
	if locked:
		for player_variant in runtime.player_ids():
			var lock_receipt: Dictionary = runtime.lock_player_submission(
				str(player_variant)
			) as Dictionary
			if not bool(lock_receipt.get("accepted", false)):
				locked = false
				lock_reason = str(lock_receipt.get("reason_code", ""))
				lock_actor_id = str(player_variant)
				break
	var resolved := {}
	if locked and runtime.phase() == "resolving":
		resolved = runtime.resolve_next_action() as Dictionary
	var public_result := resolved.get("combat_public_result", {}) as Dictionary
	var resolved_capability := str(public_result.get(
		"monster_card_mode" if domain == "monster" else "task_kind",
		""
	))
	var queue_binding := queued.get("binding", {}) as Dictionary
	var authority_receipt := _production_authority_receipt(
		combat,
		candidate,
		domain,
		capability
	)
	var authority_receipt_lineage_green := (
		_production_authority_receipt_lineage_green(
			candidate,
			domain,
			capability,
			authority_receipt
		)
	)
	var green: bool = (
		capability_list.has(capability)
		and not candidate.is_empty()
		and prebound_green
		and partial_binding_rejected
		and convenience_partial_rejected
		and policy_capability == capability
		and policy_candidate.get("candidate_fingerprint")
			== candidate.get("candidate_fingerprint")
		and bool(queued.get("accepted", false))
		and queue_binding.get("candidate_fingerprint")
			== candidate.get("candidate_fingerprint")
		and locked
		and bool(resolved.get("accepted", false))
		and resolved_capability == capability
		and authority_receipt_lineage_green
	)
	var report := {
		"green": green,
		"reason_code": "none" if green else "production_lineage_incomplete",
		"capability": capability,
		"capability_present": capability_list.has(capability),
		"candidate_found": not candidate.is_empty(),
		"candidate_prebound": prebound_green,
		"partial_binding_rejected": partial_binding_rejected,
		"convenience_partial_rejected": convenience_partial_rejected,
		"policy_capability": policy_capability,
		"queue_accepted": bool(queued.get("accepted", false)),
		"lock_green": locked,
		"lock_reason": lock_reason,
		"lock_actor_id": lock_actor_id,
		"resolve_accepted": bool(resolved.get("accepted", false)),
		"resolved_capability": resolved_capability,
		"authority_receipt_found": not authority_receipt.is_empty(),
		"authority_receipt_lineage_green": authority_receipt_lineage_green,
		"queue_reason": str(queued.get("reason_code", "")),
		"resolve_reason": str(resolved.get("reason_code", "")),
	}
	composition.queue_free()
	await process_frame
	return report


func _configure_fixture_monster_state(
	combat: Node,
	player_ids: Array,
	actor_id: String,
	region_id: String,
	setup: String
) -> Dictionary:
	var sources: Array = []
	if setup in [
		"damaged_same_family",
		"lower_rank_same_family",
		"capacity_full_other_family",
	]:
		var family_id := (
			"spore_tide_emperor"
			if setup == "capacity_full_other_family"
			else "spore_tide_emperor"
		)
		var definition := CombatCatalog.monster_source_definition(family_id)
		var hp := 40 if setup == "damaged_same_family" else -1
		var source := MonsterCore.build_source_snapshot(
			definition,
			"monster.fixture.%s" % setup,
			actor_id,
			region_id,
			1,
			hp,
			"active",
			1,
			"card.fixture.origin.%s" % setup
		)
		if source.is_empty():
			return {"accepted": false, "reason_code": "fixture_source_invalid"}
		sources.append(source)
	elif setup == "enemy_monster":
		var definition := CombatCatalog.monster_source_definition(
			"spore_tide_emperor"
		)
		var enemy := MonsterCore.build_source_snapshot(
			definition,
			"monster.fixture.enemy",
			"player.ai.2",
			region_id,
			1,
			-1,
			"active",
			1,
			"card.fixture.enemy.origin"
		)
		if enemy.is_empty():
			return {"accepted": false, "reason_code": "fixture_enemy_invalid"}
		sources.append(enemy)
	var state := MonsterCore.new_state(player_ids, {}, sources)
	if state.is_empty():
		return {"accepted": false, "reason_code": "fixture_state_invalid"}
	combat.set("_monster_state", state)
	return {"accepted": true, "reason_code": "fixture_monster_state_installed"}


func _install_fixture_assets(runtime: Node) -> Dictionary:
	var current := runtime.get("_asset_state") as Dictionary
	var player_ids := runtime.player_ids() as Array
	var hidden_order := current.get(
		"submission_hidden_lead_order",
		[]
	) as Array
	var initial_assets := {}
	for player_variant in player_ids:
		initial_assets[str(player_variant)] = {
			"life": 6,
			"energy": 6,
			"industry": 6,
			"technology": 6,
			"commerce": 6,
			"shipping": 6,
		}
	var state := AssetBatchCore.create_state(
		str(current.get("batch_id", "")),
		player_ids,
		hidden_order,
		initial_assets,
		{},
		int(current.get("opened_at_ms", 0)),
		int(current.get("gdp_milli_per_asset", 1000))
	)
	if state.is_empty() or not bool(
		AssetBatchCore.validation_report(state).get("valid", false)
	):
		return {"accepted": false, "reason_code": "asset_fixture_invalid"}
	runtime.set("_asset_state", state)
	runtime.call("_sync_asset_balances")
	return {"accepted": true, "reason_code": "asset_fixture_installed"}


func _install_fixture_enemy_facility(
	runtime: Node,
	actor_id: String
) -> Dictionary:
	var state := (runtime.get("_facility_state") as Dictionary).duplicate(true)
	var substate := PublicActionBatchCore.facility_substate(state)
	var slots := substate.get("facility_slots", {}) as Dictionary
	var slot_ids: Array[String] = []
	for slot_id_variant in slots.keys():
		slot_ids.append(str(slot_id_variant))
	slot_ids.sort()
	if slot_ids.is_empty():
		return {"accepted": false, "reason_code": "facility_slot_missing"}
	var selected_id := slot_ids[0]
	var selected := slots.get(selected_id, {}) as Dictionary
	var enemy_owner := "player.ai.2" if actor_id != "player.ai.2" else "player.ai.3"
	var occupied := FacilityCore.build_occupied_slot(
		str(selected.get("region_id", "")),
		int(selected.get("region_revision", 0)),
		str(selected.get("facility_type", "")),
		str(selected.get("industry_id", "")),
		int(selected.get("slot_generation", 0)) + 1,
		"facility.fixture.enemy",
		1,
		enemy_owner,
		1,
		0,
		0,
		"dark"
	)
	if occupied.is_empty():
		return {"accepted": false, "reason_code": "occupied_slot_invalid"}
	var replacements: Array = []
	for slot_id in slot_ids:
		replacements.append(
			occupied.duplicate(true)
			if slot_id == selected_id
			else (slots.get(slot_id, {}) as Dictionary).duplicate(true)
		)
	var next_state := PublicActionBatchCore.replace_facility_slots(
		state,
		replacements
	)
	if next_state.is_empty():
		return {"accepted": false, "reason_code": "facility_replace_failed"}
	runtime.set("_facility_state", next_state)
	runtime.call("_sync_facility_slots")
	return {
		"accepted": true,
		"reason_code": "enemy_facility_fixture_installed",
		"facility_id": "facility.fixture.enemy",
	}


func _install_fixture_card(
	runtime: Node,
	actor_id: String,
	card_type: String,
	rank: int,
	capability: String
) -> Dictionary:
	var dbg_by_player := runtime.get("_dbg_by_player") as Dictionary
	var dbg := dbg_by_player.get(actor_id) as RefCounted
	if dbg == null:
		return {"accepted": false, "reason_code": "fixture_dbg_missing"}
	var color_id := _fixture_card_color(runtime, actor_id)
	var spec := dbg.call(
		"standard_card_spec_for_active_profile",
		color_id,
		card_type,
		rank
	) as Dictionary
	if spec.is_empty():
		return {"accepted": false, "reason_code": "fixture_card_spec_missing"}
	var save := dbg.call("to_save_data") as Dictionary
	var state := (save.get("state", {}) as Dictionary).duplicate(true)
	var sequence := int(state.get("next_instance_sequence", 0))
	var instance_id := "dbg.%s.%06d" % [actor_id, sequence]
	var card := spec.duplicate(true)
	card["instance_id"] = instance_id
	card["card_instance_id"] = instance_id
	card["card_definition_id"] = str(spec.get("definition_id", ""))
	card["locked"] = false
	var draw_pile := (state.get("draw_pile", []) as Array).duplicate(true)
	draw_pile.append_array((state.get("hand", []) as Array).duplicate(true))
	state["draw_pile"] = draw_pile
	state["hand"] = [card]
	state["next_instance_sequence"] = sequence + 1
	save["state"] = state
	save["document_section"] = DbgCore._document_save_section(state)
	save["state_fingerprint"] = DbgCore._fingerprint(state)
	save["core_fingerprint"] = DbgCore._core_fingerprint(state)
	var applied := dbg.call("apply_save_data", save) as Dictionary
	return {
		"accepted": bool(applied.get("applied", false)),
		"reason_code": str(applied.get("reason_code", "")),
		"card_instance_id": instance_id,
		"card_definition_id": str(spec.get("definition_id", "")),
		"primary_color": color_id,
		"capability": capability,
	}


func _fixture_card_color(runtime: Node, actor_id: String) -> String:
	var players := (runtime.get("_asset_state") as Dictionary).get(
		"players", {}
	) as Dictionary
	var assets := (players.get(actor_id, {}) as Dictionary).get(
		"assets", {}
	) as Dictionary
	var selected := "life"
	var maximum := -1
	for color_id in [
		"life", "energy", "industry", "technology", "commerce", "shipping",
	]:
		var amount := int(assets.get(color_id, 0))
		if amount > maximum:
			maximum = amount
			selected = color_id
	return selected


func _production_candidate_for_capability(
	candidates: Array,
	domain: String,
	capability: String,
	card_instance_id: String
) -> Dictionary:
	for candidate_variant in candidates:
		var candidate := candidate_variant as Dictionary
		if (
			str(candidate.get("action_domain", "")) == domain
			and str(candidate.get("card_instance_id", "")) == card_instance_id
			and str(candidate.get(
				"monster_card_mode" if domain == "monster" else "task_kind",
				""
			)) == capability
		):
			return candidate.duplicate(true)
	return {}


func _production_candidate_by_option_id(
	candidates: Array,
	option_id: String
) -> Dictionary:
	for candidate_variant in candidates:
		var candidate := candidate_variant as Dictionary
		if str(candidate.get("option_id", "")) == option_id:
			return candidate.duplicate(true)
	return {}


func _production_candidate_prebound(
	candidate: Dictionary,
	domain: String,
	capability: String
) -> bool:
	if candidate.is_empty() or not bool(
		CombatCandidate.validation_report(candidate).get("valid", false)
	):
		return false
	var binding := candidate.get("target_binding", {}) as Dictionary
	if domain == "military":
		return (
			candidate.get("task_kind") == capability
			and candidate.get("military_target_envelope") == binding
			and (
				(capability == "assault_region" and (
					not str(binding.get("target_region_id", "")).is_empty()
					and not (binding.get("locked_enemy_facility_ids", []) as Array).is_empty()
				))
				or (capability == "assault_monster" and (
					not str(binding.get("target_monster_source_instance_id", "")).is_empty()
					and int(binding.get("target_source_generation", 0)) > 0
				))
			)
		)
	var action := candidate.get("prebound_monster_action", {}) as Dictionary
	if capability == "DEPLOY_NEW":
		return (
			not str(binding.get("target_region_id", "")).is_empty()
			and int(binding.get("expected_region_revision", -1)) >= 0
			and binding.get("expected_region_revision")
				== action.get("expected_region_revision")
		)
	if capability == "REFRESH_EXISTING":
		return (
			not str(binding.get("target_source_instance_id", "")).is_empty()
			and int(binding.get("target_source_generation", 0)) > 0
			and int(binding.get("expected_hp_revision", -1)) >= 0
			and binding.get("expected_hp_revision")
				== action.get("expected_hp_revision")
		)
	if capability == "UPGRADE_EXISTING":
		return (
			not str(binding.get("target_source_instance_id", "")).is_empty()
			and int(candidate.get("target_rank", 0)) > 1
		)
	return (
		capability == "REPLACE_EXISTING"
		and not str(binding.get("withdraw_source_id", "")).is_empty()
		and int(binding.get("withdraw_source_generation", 0)) > 0
		and not str(binding.get("deploy_target_region_id", "")).is_empty()
		and binding.get("expected_region_revision")
			== action.get("expected_region_revision")
	)


func _production_authority_receipt(
	combat: Node,
	candidate: Dictionary,
	domain: String,
	capability: String
) -> Dictionary:
	var checkpoint := combat.call(
		"capture_checkpoint",
		"gate60.lineage.%s" % capability.to_lower()
	) as Dictionary
	var state := checkpoint.get("state", {}) as Dictionary
	var journal := state.get("receipt_journal", []) as Array
	var action := candidate.get("prebound_monster_action", {}) as Dictionary
	for index in range(journal.size() - 1, -1, -1):
		var envelope := journal[index] as Dictionary
		var payload := envelope.get("payload", {}) as Dictionary
		if domain == "monster":
			if payload.get("action_fingerprint") == action.get("action_fingerprint"):
				return payload.duplicate(true)
		elif (
			payload.get("card_instance_id") == candidate.get("card_instance_id")
			and payload.get("task_kind") == capability
		):
			return payload.duplicate(true)
	return {}


func _production_authority_receipt_lineage_green(
	candidate: Dictionary,
	domain: String,
	capability: String,
	receipt: Dictionary
) -> bool:
	if (
		receipt.is_empty()
		or str(receipt.get("receipt_fingerprint", "")).length() != 64
		or receipt.get("card_instance_id") != candidate.get("card_instance_id")
	):
		return false
	var binding := candidate.get("target_binding", {}) as Dictionary
	if domain == "monster":
		var action := candidate.get("prebound_monster_action", {}) as Dictionary
		if (
			receipt.get("monster_card_mode") != capability
			or receipt.get("action_fingerprint") != action.get("action_fingerprint")
			or receipt.get("target_region_id") != action.get("deployment_region_id")
			or receipt.get("target_source_instance_id")
				!= action.get("target_source_instance_id")
			or receipt.get("target_source_generation")
				!= action.get("target_source_generation")
			or receipt.get("expected_hp_revision")
				!= action.get("expected_hp_revision")
			or receipt.get("expected_region_revision")
				!= action.get("expected_region_revision")
			or receipt.get("bound_state_revision")
				!= candidate.get("expected_world_revision")
			or receipt.get("mode_auto_converted") != false
			or int(receipt.get("mode_auto_conversion_count", -1)) != 0
		):
			return false
		if capability == "DEPLOY_NEW":
			return (
				receipt.get("target_region_id") == binding.get("target_region_id")
				and receipt.get("expected_region_revision")
					== binding.get("expected_region_revision")
			)
		if capability == "REPLACE_EXISTING":
			return (
				receipt.get("target_region_id")
					== binding.get("deploy_target_region_id")
				and receipt.get("target_source_instance_id")
					== binding.get("withdraw_source_id")
				and receipt.get("target_source_generation")
					== binding.get("withdraw_source_generation")
				and receipt.get("expected_region_revision")
					== binding.get("expected_region_revision")
			)
		return (
			receipt.get("target_source_instance_id")
				== binding.get("target_source_instance_id")
			and receipt.get("target_source_generation")
				== binding.get("target_source_generation")
			and (
				capability != "REFRESH_EXISTING"
				or receipt.get("expected_hp_revision")
					== binding.get("expected_hp_revision")
			)
		)
	if (
		receipt.get("task_kind") != capability
		or int(receipt.get("retarget_count", -1)) != 0
		or str(receipt.get("lock_fingerprint", "")).length() != 64
	):
		return false
	if capability == "assault_region":
		return (
			receipt.get("target_region_id") == binding.get("target_region_id")
			and receipt.get("expected_region_revision")
				== binding.get("expected_region_revision")
			and receipt.get("locked_enemy_facility_ids")
				== binding.get("locked_enemy_facility_ids")
			and receipt.get("facility_generations")
				== binding.get("facility_generations")
		)
	return (
		receipt.get("target_monster_source_instance_id")
			== binding.get("target_monster_source_instance_id")
		and receipt.get("target_source_generation")
			== binding.get("target_source_generation")
		and receipt.get("target_monster_revision")
			== binding.get("target_monster_revision")
		and receipt.get("target_monster_owner_player_id")
			== binding.get("target_monster_owner_player_id")
		and receipt.get("public_target_region_id")
			== binding.get("public_target_region_id")
	)


func _monster_option(action: Dictionary, mode: String, region_revision: int) -> Dictionary:
	var card_id := str(action.get("card_instance_id", ""))
	var definition_id := str(action.get("card_definition_id", ""))
	var generation := 2
	var option := {
		"option_id": "option.%s.%s" % [card_id, mode.to_lower()],
		"actor_id": ACTOR_ID,
		"card_instance_id": card_id,
		"card_definition_id": definition_id,
		"card_generation": generation,
		"card_rank": int(action.get("card_rank", 0)),
		"primary_color": str((action.get("definition_snapshot", {}) as Dictionary).get("preferred_industry_color", "")),
		"asset_cost": 1,
		"action_domain": "monster",
		"monster_card_mode": mode,
		"target_slot_id": "slot.%s.%s" % [card_id, mode.to_lower()],
		"target_region_id": str(action.get("deployment_region_id", "")),
		"target_source_instance_id": str(action.get("target_source_instance_id", "")),
		"target_source_generation": int(action.get("target_source_generation", 0)),
		"expected_hp_revision": int(action.get("expected_hp_revision", -1)),
		"expected_world_revision": int(action.get("bound_state_revision", 0)),
		"prebound_monster_action": action.duplicate(true),
		"mode_prebound": true,
		"card_action_binding": _card_binding(ACTOR_ID, card_id, definition_id, generation),
	}
	if mode in ["DEPLOY_NEW", "REPLACE_EXISTING"]:
		option["expected_region_revision"] = region_revision
	return option


func _military_option(
	mission_kind: String,
	envelope: Dictionary,
	card_id: String,
	generation: int
) -> Dictionary:
	var definition_id := "military.fixture.rank.2"
	return {
		"option_id": "option.%s.%s" % [card_id, mission_kind],
		"actor_id": ACTOR_ID,
		"owner_player_id": ACTOR_ID,
		"card_instance_id": card_id,
		"card_definition_id": definition_id,
		"card_generation": generation,
		"card_action_binding": _card_binding(ACTOR_ID, card_id, definition_id, generation),
		"primary_color": "life",
		"asset_cost": 1,
		"asset_cost_by_color": {"life": 1},
		"action_domain": "military",
		"task_kind": mission_kind,
		"target_slot_id": "slot.%s.%s" % [card_id, mission_kind],
		"target_region_id": str(envelope.get("target_region_id", "")),
		"target_monster_source_instance_id": str(envelope.get("target_monster_source_instance_id", "")),
		"target_source_generation": int(envelope.get("target_source_generation", 0)),
		"expected_region_revision": int(envelope.get("expected_region_revision", -1)),
		"expected_world_revision": 1,
		"military_target_envelope": envelope.duplicate(true),
		"mode_prebound": true,
		"enabled": true,
	}


func _card_binding(
	owner_id: String,
	card_id: String,
	definition_id: String,
	generation: int
) -> Dictionary:
	var binding := {
		"schema_id": "v07.personal_dbg.authoritative_card_action_binding.v1",
		"schema_version": 1,
		"authority_domain_id": "v07.personal_dbg",
		"authority_lineage_fingerprint": "a".repeat(64),
		"owner_player_id": owner_id,
		"card_instance_id": card_id,
		"card_definition_id": definition_id,
		"immutable_identity_fingerprint": "b".repeat(64),
		"authoritative_zone": "hand",
		"zone_revision": generation,
		"lifecycle_evidence_fingerprint": "c".repeat(64),
		"expected_action_lifecycle": "v075.combat.queue_resolve_personal_discard",
	}
	binding["binding_fingerprint"] = _hash(binding)
	return binding


func _monster_request(
	suffix: String,
	card_id: String,
	definition_id: String,
	rank: int,
	mode: String,
	region_id: String,
	target_source_id: String
) -> Dictionary:
	return {
		"request_id": "request.%s" % suffix,
		"card_instance_id": card_id,
		"card_definition_id": definition_id,
		"owner_player_id": ACTOR_ID,
		"card_rank": rank,
		"monster_card_mode": mode,
		"target_region_id": region_id,
		"target_source_instance_id": target_source_id,
		"expected_region_revision": (
			7
			if mode in ["DEPLOY_NEW", "REPLACE_EXISTING"]
			else -1
		),
	}


func _monster_definition(family_id: String, color_id: String) -> Dictionary:
	return {
		"source_definition_id": "monster.%s.source" % family_id,
		"monster_family_id": family_id,
		"preferred_industry_color": color_id,
		"facility_type_preference": ["factory", "market", "warehouse"],
		"base_detection_range_hops": 2,
		"movement_profile": "ground_trample",
		"movement_budget_milli_arc_by_rank": [1000, 1200, 1400, 1600],
		"max_hp_by_rank": [100, 200, 300, 400],
		"armor_by_rank": [0, 1, 2, 3],
		"active_skill_definition_ids": [
			"skill.%s.1" % family_id,
			"skill.%s.2" % family_id,
			"skill.%s.3" % family_id,
			"skill.%s.4" % family_id,
		],
	}


func _facility(
	facility_id: String,
	generation: int,
	facility_type: String,
	industry_id: String
) -> Dictionary:
	return {
		"facility_id": facility_id,
		"facility_generation": generation,
		"owner_player_id": "player.enemy",
		"region_id": "region.enemy",
		"facility_type": facility_type,
		"industry_id": industry_id,
		"status": "active",
	}


func _enemy_monster(
	source_id: String,
	generation: int,
	revision: int,
	region_id: String
) -> Dictionary:
	return {
		"source_instance_id": source_id,
		"source_generation": generation,
		"damage_revision": revision,
		"owner_player_id": "player.enemy",
		"region_id": region_id,
		"status": "active",
	}


func _monster_score(mode: String, rank: int) -> int:
	return int({
		"DEPLOY_NEW": 720,
		"REFRESH_EXISTING": 820,
		"UPGRADE_EXISTING": 940,
		"REPLACE_EXISTING": 680,
	}.get(mode, 0)) + rank * 5


func _group_candidates(rows: Array, domain: String) -> Array:
	var grouped := {}
	for row_variant in rows:
		var row := row_variant as Dictionary
		var card_id := str(row.get("card_instance_id", ""))
		var current := grouped.get(card_id, {
			"card_instance_id": card_id,
			"card_definition_id": str(row.get("card_definition_id", "")),
			"options": [],
		}) as Dictionary
		var options := current.get("options", []) as Array
		var option := row.duplicate(true)
		option["asset_cost_by_color"] = (row.get("asset_cost", {}) as Dictionary).duplicate(true)
		option["asset_cost"] = int(row.get("primary_asset_cost", 0))
		if domain == "monster":
			option["prebound_monster_action"] = (row.get("prebound_monster_action") as Dictionary).duplicate(true)
		else:
			option["military_target_envelope"] = (row.get("military_target_envelope") as Dictionary).duplicate(true)
		options.append(option)
		current["options"] = options
		grouped[card_id] = current
	var result: Array = grouped.values()
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("card_instance_id", "")) < str(right.get("card_instance_id", ""))
	)
	return result


func _six_assets(amount: int) -> Dictionary:
	return {
		"life": amount,
		"energy": amount,
		"industry": amount,
		"technology": amount,
		"commerce": amount,
		"shipping": amount,
	}


func _public_candidate_leak_count(value: Variant) -> int:
	var forbidden := [
		"combat_private_facts", "combat_candidates",
		"monster_mode_candidates", "military_mission_candidates",
		"prebound_monster_action", "military_target_envelope",
		"target_binding", "candidate_fingerprint",
		"private_information_fingerprint", "priority_features",
	]
	if value is Dictionary:
		var total := 0
		for key_variant in (value as Dictionary).keys():
			if str(key_variant) in forbidden:
				total += 1
			total += _public_candidate_leak_count((value as Dictionary).get(key_variant))
		return total
	if value is Array:
		var total := 0
		for child in value as Array:
			total += _public_candidate_leak_count(child)
		return total
	return 0


func _hash(value: Variant) -> String:
	return _canonical_json(value).sha256_text()


func _canonical_json(value: Variant) -> String:
	if value is Dictionary:
		var keys: Array[String] = []
		for key_variant in (value as Dictionary).keys():
			keys.append(str(key_variant))
		keys.sort()
		var pairs: Array[String] = []
		for key in keys:
			pairs.append("%s:%s" % [JSON.stringify(key), _canonical_json((value as Dictionary).get(key))])
		return "{%s}" % ",".join(pairs)
	if value is Array:
		var rows: Array[String] = []
		for child in value as Array:
			rows.append(_canonical_json(child))
		return "[%s]" % ",".join(rows)
	return JSON.stringify(value)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print(
		"V075_COMBAT_AI_TEST|status=%s|passed=%d|total=%d|failures=%s|lineage=%d/6|contracts=%s"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks - _failures.size(),
			_checks,
			JSON.stringify(_failures),
			_lineage_pass_count,
			JSON.stringify(CONTRACT_TEST_NAMES),
		]
	)
	quit(0 if _failures.is_empty() else 1)
