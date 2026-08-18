extends Node
class_name V075CombatRuntimeOwnerBench

const CombatOwner := preload(
	"res://scripts/v075/runtime/v075_combat_runtime_owner.gd"
)
const AssetCore := preload(
	"res://scripts/v07_semantic/v07_asset_batch_core.gd"
)
const CardDefinitions := preload(
	"res://scripts/v075/cards/v075_card_definition_registry.gd"
)

var _checks := 0
var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var owner := CombatOwner.new()
	add_child(owner)
	var player_ids := ["player.alpha", "player.beta", "player.gamma"]
	var initialized := owner.initialize(player_ids, _map_receipt())
	_expect(bool(initialized.get("accepted", false)), "combat owner initializes")
	var asset_state := AssetCore.create_state(
		"batch.owner.001",
		player_ids,
		player_ids,
		{
			"player.alpha": _all_six(6),
			"player.beta": _all_six(6),
			"player.gamma": _all_six(6),
		},
		{},
		0,
		1000
	)
	var facilities := _facilities()
	var batch := owner.begin_batch(
		"batch.owner.001",
		0,
		asset_state,
		facilities
	)
	_expect(bool(batch.get("accepted", false)), "combat batch starts")

	var alpha_deploy := _deploy(
		owner,
		"player.alpha",
		"card.monster.alpha.001",
		"spore_tide_emperor",
		"life",
		"region.000"
	)
	_expect(bool(alpha_deploy.get("accepted", false)), "alpha monster deploys")
	var public_monsters := owner.public_monsters()
	_expect(
		public_monsters.size() == 1
		and str((public_monsters[0] as Dictionary).get(
			"preferred_industry_color",
			""
		)) == "life",
		"public monster exposes preferred color"
	)
	var alpha_source_id := str(
		(alpha_deploy.get("receipt", {}) as Dictionary).get(
			"source_instance_id",
			""
		)
	)
	var owner_zone := owner.owner_private_skill_zone("player.alpha")
	_expect(
		owner_zone.size() == 1
		and ((owner_zone[0] as Dictionary).get("skills", []) as Array).size() == 1,
		"rank one owner receives one private skill"
	)
	_expect(
		owner.owner_private_skill_zone("player.beta").is_empty(),
		"rival receives no alpha skill cards"
	)

	var skill_id := str(
		(((owner_zone[0] as Dictionary).get("skills", []) as Array)[0]
		as Dictionary).get("skill_definition_id", "")
	)
	var skill_result := owner.request_private_skill(
		{
			"request_id": "request.skill.alpha.001",
			"owner_player_id": "player.alpha",
			"source_instance_id": alpha_source_id,
			"source_generation": 1,
			"skill_definition_id": skill_id,
			"target_request": {
				"target_kind": "enemy_public_facility",
				"target_id": "facility.enemy.factory.000",
				"target_facility_generation": 1,
			},
		},
		asset_state,
		facilities
	)
	_expect(
		bool(skill_result.get("accepted", false))
		and str(skill_result.get("reason_code", ""))
			== "private_skill_safe_boundary_drained"
		and int(skill_result.get("resolved_count", 0)) == 1,
		"private skill resolves immediately at the current safe boundary"
	)
	asset_state = skill_result.get("asset_state", {}) as Dictionary
	var alpha_asset_row := (
		(asset_state.get("players", {}) as Dictionary).get(
			"player.alpha",
			{}
		) as Dictionary
	)
	_expect(
		int((AssetCore.monster_skill_available_asset_view(
			asset_state,
			"player.alpha"
		).get("own_available_assets", {}) as Dictionary).get("life", -1)) == 5,
		"private skill commits exactly one available life asset"
	)
	_expect(
		int((alpha_asset_row.get("assets", {}) as Dictionary).get(
			"life",
			-1
		)) == 5
		and alpha_asset_row.get("reserved_totals", {}) == _all_six(0),
		"immediate settlement debits the asset owner and clears its reservation"
	)
	_expect(
		(skill_result.get("facility_damage_intents", []) as Array).size() == 1
		and (skill_result.get("public_results", []) as Array).size() == 1
		and (skill_result.get("resolution_receipts", []) as Array).size() == 1,
		"immediate settlement returns one damage intent, public result, and private operation receipt"
	)
	var second_skill := owner.request_private_skill(
		{
			"request_id": "request.skill.alpha.002",
			"owner_player_id": "player.alpha",
			"source_instance_id": alpha_source_id,
			"source_generation": 1,
			"skill_definition_id": skill_id,
			"target_request": {
				"target_kind": "enemy_public_facility",
				"target_id": "facility.enemy.factory.000",
				"target_facility_generation": 1,
			},
		},
		asset_state,
		facilities
	)
	_expect(
		not bool(second_skill.get("accepted", true)),
		"same source second skill request is rejected in one batch"
	)

	var plan := owner.plan_autonomy(facilities)
	_expect(bool(plan.get("accepted", false)), "autonomy plan freezes")
	var autonomy := owner.resolve_autonomy(facilities)
	_expect(bool(autonomy.get("accepted", false)), "autonomy resolves")
	_expect(
		(autonomy.get("movement_receipts", []) as Array).size() == 1,
		"ground monster crosses the frozen path"
	)
	_expect(
		(autonomy.get("trample_region_receipts", []) as Array).size() == 3,
		"three traversed regions aggregate one trample receipt each"
	)
	_expect(
		(autonomy.get("facility_damage_intents", []) as Array).size() >= 4,
		"trample plus arrival attack emit typed facility intents"
	)

	var second_batch := owner.begin_batch(
		"batch.owner.002",
		1,
		asset_state,
		facilities
	)
	_expect(bool(second_batch.get("accepted", false)), "second combat batch starts")
	var reused := owner.request_private_skill(
		{
			"request_id": "request.skill.alpha.reuse.001",
			"owner_player_id": "player.alpha",
			"source_instance_id": alpha_source_id,
			"source_generation": 1,
			"skill_definition_id": skill_id,
			"target_request": {
				"target_kind": "enemy_public_facility",
				"target_id": "facility.enemy.warehouse.002",
				"target_facility_generation": 1,
			},
		},
		asset_state,
		facilities
	)
	_expect(bool(reused.get("accepted", false)), "cooled skill is reusable next batch")
	asset_state = reused.get("asset_state", {}) as Dictionary

	var beta_deploy := _deploy(
		owner,
		"player.beta",
		"card.monster.beta.001",
		"meteor_sentinel",
		"energy",
		"region.002"
	)
	_expect(bool(beta_deploy.get("accepted", false)), "beta monster deploys")
	var beta_source_id := str(
		(beta_deploy.get("receipt", {}) as Dictionary).get(
			"source_instance_id",
			""
		)
	)

	var region_lock := owner.build_military_lock(
		_military_binding(
			"region",
			"card.military.alpha.region.001",
			"mission.region.001",
			"region.002",
			""
		),
		facilities
	)
	_expect(bool(region_lock.get("accepted", false)), "military region mission locks")
	var region_assault := owner.resolve_military_action(
		"mission.region.001",
		facilities
	)
	_expect(
		bool(region_assault.get("accepted", false))
		and (region_assault.get("facility_damage_intents", []) as Array).size() == 1
		and str((region_assault.get("receipt", {}) as Dictionary).get(
			"mission_state_after",
			""
		)) == "withdrawn",
		"region assault spends one total budget and withdraws"
	)

	var monster_lock := owner.build_military_lock(
		_military_binding(
			"monster",
			"card.military.alpha.monster.001",
			"mission.monster.001",
			"",
			beta_source_id
		),
		facilities
	)
	_expect(bool(monster_lock.get("accepted", false)), "military monster mission locks")
	var monster_assault := owner.resolve_military_action(
		"mission.monster.001",
		facilities
	)
	_expect(
		bool(monster_assault.get("accepted", false))
		and (monster_assault.get("monster_damage_receipts", []) as Array).size() == 1,
		"monster assault attacks once and withdraws"
	)

	var checkpoint := owner.capture_checkpoint("checkpoint.combat.owner.001")
	_expect(
		bool(CombatOwner.CombatCheckpoint.validation_report(checkpoint).get(
			"valid",
			false
		)),
		"combat owner exposes detached valid checkpoint"
	)
	var debug := owner.debug_snapshot()
	_expect(
		int(debug.get("combat_runtime_owner_count", 0)) == 1
		and int(debug.get("combat_state_writer_count", 0)) == 1
		and int(debug.get("military_guard_task_count", -1)) == 0
		and int(debug.get("military_bound_action_count", -1)) == 0
		and int(debug.get("monster_public_skill_card_disclosure_count", -1)) == 0
		and int(debug.get("runtime_error_count", -1)) == 0,
		"runtime authority, privacy and retired-path gates stay green"
	)
	_finish(debug)


func _deploy(
	owner: Node,
	player_id: String,
	card_id: String,
	family_id: String,
	color_id: String,
	region_id: String
) -> Dictionary:
	var definition_id := CardDefinitions.standard_definition_id(
		"monster.%s" % family_id,
		color_id,
		1
	)
	var bound: Dictionary = owner.prebind_monster_card_action({
		"request_id": "request.%s" % card_id,
		"card_instance_id": card_id,
		"card_definition_id": definition_id,
		"owner_player_id": player_id,
		"monster_card_mode": "DEPLOY_NEW",
		"target_region_id": region_id,
		"target_source_instance_id": "",
	})
	if not bool(bound.get("accepted", false)):
		return bound
	return owner.resolve_monster_card_action(
		bound.get("action", {}) as Dictionary
	)


func _military_binding(
	task: String,
	card_id: String,
	mission_id: String,
	region_id: String,
	monster_id: String
) -> Dictionary:
	return {
		"request_id": "request.%s" % mission_id,
		"mission_id": mission_id,
		"owner_player_id": "player.alpha",
		"card_instance_id": card_id,
		"card_definition_id": CardDefinitions.standard_definition_id(
			"military.planetary_defense_force",
			"life",
			1
		),
		"action_slot_id": "action.slot.%s" % mission_id,
		"asset_reservation_id": "reservation.%s" % mission_id,
		"committed_escrow_revision": 1,
		"target_region_revision": 1,
		"task_kind": "assault_region" if task == "region" else "assault_monster",
		"target_region_id": region_id,
		"target_monster_source_instance_id": monster_id,
	}


func _map_receipt() -> Dictionary:
	return {
		"map_id": "map.owner.bench",
		"map_fingerprint": "bench-map-fingerprint",
		"region_ids": ["region.000", "region.001", "region.002"],
		"adjacency_graph": {
			"region.000": ["region.001"],
			"region.001": ["region.000", "region.002"],
			"region.002": ["region.001"],
		},
		"edge_distance_milli_arc": {
			"region.000": {"region.001": 70},
			"region.001": {"region.000": 70, "region.002": 70},
			"region.002": {"region.001": 70},
		},
	}


func _facilities() -> Array:
	return [
		{
			"facility_id": "facility.enemy.factory.000",
			"facility_generation": 1,
			"owner_player_id": "player.beta",
			"region_id": "region.000",
			"facility_type": "factory",
			"industry_id": "energy",
			"status": "active",
			"occupancy": "occupied",
			"damage_points": 0,
			"damage_revision": 0,
		},
		{
			"facility_id": "facility.enemy.market.001",
			"facility_generation": 1,
			"owner_player_id": "player.beta",
			"region_id": "region.001",
			"facility_type": "market",
			"industry_id": "industry",
			"status": "active",
			"occupancy": "occupied",
			"damage_points": 0,
			"damage_revision": 0,
		},
		{
			"facility_id": "facility.enemy.warehouse.002",
			"facility_generation": 1,
			"owner_player_id": "player.beta",
			"region_id": "region.002",
			"facility_type": "warehouse",
			"industry_id": "life",
			"status": "active",
			"occupancy": "occupied",
			"damage_points": 0,
			"damage_revision": 0,
		},
	]


func _all_six(value: int) -> Dictionary:
	return {
		"life": value,
		"energy": value,
		"industry": value,
		"technology": value,
		"commerce": value,
		"shipping": value,
	}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish(debug: Dictionary) -> void:
	var result := {
		"status": "PASS" if _failures.is_empty() else "FAIL",
		"passed": _checks - _failures.size(),
		"total": _checks,
		"failures": _failures,
		"debug": debug,
	}
	print("V075_COMBAT_RUNTIME_OWNER_BENCH|%s" % JSON.stringify(result))
	get_tree().quit(0 if _failures.is_empty() else 1)
