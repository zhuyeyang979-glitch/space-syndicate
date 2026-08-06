extends SceneTree

const Adapter := preload(
	"res://scripts/v075/ai/v075_combat_ai_adapter.gd"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var adapter := Adapter.new()
	var own := {
		"viewer_player_id": "player.local",
		"available_unreserved_assets": {
			"life": 6,
			"energy": 6,
			"industry": 6,
			"technology": 6,
			"commerce": 6,
			"shipping": 6,
		},
		"monster_card_options": [
			{
				"card_instance_id": "card.monster.deploy",
				"card_definition_id": "monster.tech.rank.1",
				"card_rank": 1,
				"legal_modes": ["DEPLOY_NEW"],
				"prebound_target_by_mode": {
					"DEPLOY_NEW": "region.03",
				},
			},
			{
				"card_instance_id": "card.monster.refresh",
				"card_definition_id": "monster.tech.rank.1",
				"card_rank": 1,
				"legal_modes": ["REFRESH_EXISTING"],
				"prebound_target_by_mode": {
					"REFRESH_EXISTING": "monster.tech.local.01",
				},
			},
			{
				"card_instance_id": "card.monster.upgrade",
				"card_definition_id": "monster.tech.rank.4",
				"card_rank": 4,
				"legal_modes": ["UPGRADE_EXISTING"],
				"prebound_target_by_mode": {
					"UPGRADE_EXISTING": "monster.tech.local.01",
				},
			},
			{
				"card_instance_id": "card.monster.replace",
				"card_definition_id": "monster.industry.rank.2",
				"card_rank": 2,
				"legal_modes": ["REPLACE_EXISTING"],
				"prebound_target_by_mode": {
					"REPLACE_EXISTING": "monster.tech.local.01",
				},
			},
		],
		"owned_monsters": [
			{
				"source_instance_id": "monster.tech.local.01",
				"owner_player_id": "player.local",
				"status": "active",
				"batch_active_skill_used": false,
				"private_skills": [
					{
						"skill_definition_id": "skill.tech.l1",
						"state": "READY",
						"asset_cost_by_color": {"technology": 1},
						"target_contract": "enemy_facility",
						"ultimate": false,
					},
				],
			},
		],
		"military_card_options": [
			{
				"card_instance_id": "card.military.01",
				"card_definition_id": "military.rank.1",
				"legal_task_kinds": [
					"assault_region",
					"assault_monster",
				],
			},
		],
	}
	var public_facts := {
		"phase": "batch_active",
		"regions": ["region.01", "region.02"],
		"facilities": [
			{
				"facility_id": "factory.02.technology",
				"owner_player_id": "player.ai.1",
				"region_id": "region.02",
				"status": "active",
			},
		],
		"monsters": [
			{
				"source_instance_id": "monster.ai.01",
				"owner_player_id": "player.ai.1",
				"status": "active",
			},
		],
	}
	var result := adapter.enumerate_candidates(own, public_facts)
	_expect(bool(result.get("accepted", false)), "combat facts accepted")
	var candidates := result.get("candidates", []) as Array
	var modes: Array[String] = []
	var task_kinds: Array[String] = []
	var private_skill_count := 0
	for candidate_variant in candidates:
		var candidate := candidate_variant as Dictionary
		var mode := str(candidate.get("monster_card_mode", ""))
		if not mode.is_empty() and mode not in modes:
			modes.append(mode)
		var task_kind := str(candidate.get("task_kind", ""))
		if not task_kind.is_empty() and task_kind not in task_kinds:
			task_kinds.append(task_kind)
		if str(candidate.get("action_kind", "")) == "monster_private_skill":
			private_skill_count += 1
	_expect(modes.size() == 4, "all four monster modes remain prebound")
	_expect(
		"assault_region" in task_kinds
		and "assault_monster" in task_kinds,
		"AI exposes exactly the two military assaults"
	)
	_expect(private_skill_count == 1, "AI can request an owner-private skill")
	for candidate_variant in candidates:
		_expect(
			not str(
				(candidate_variant as Dictionary).get("task_kind", "")
			).to_lower().contains("guard"),
			"AI never emits a guard task"
		)
	var first_choice := adapter.choose_action(own, public_facts)
	var second_choice := adapter.choose_action(own, public_facts)
	_expect(
		JSON.stringify(first_choice) == JSON.stringify(second_choice),
		"combat AI choice is deterministic without RNG"
	)
	var leaked_public := public_facts.duplicate(true)
	leaked_public["private_skill_zones_by_player"] = {
		"player.ai.1": ["hidden"],
	}
	var rejected := adapter.enumerate_candidates(own, leaked_public)
	_expect(
		not bool(rejected.get("accepted", true))
		and str(rejected.get("reason_code", "")).begins_with(
			"public_facts_contains_private_field"
		),
		"AI rejects a public projection carrying private skill data"
	)
	var leaked_cooldown := public_facts.duplicate(true)
	leaked_cooldown["opponent_skill_cooldowns"] = {
		"player.ai.1": 2,
	}
	var cooldown_rejected := adapter.enumerate_candidates(
		own,
		leaked_cooldown
	)
	_expect(
		not bool(cooldown_rejected.get("accepted", true)),
		"AI rejects opponent skill cooldown variants"
	)
	var no_action_own := {
		"viewer_player_id": "player.local",
		"owned_monsters": [],
	}
	var no_action := adapter.choose_action(no_action_own, public_facts)
	_expect(
		not bool(no_action.get("accepted", true))
		and str(no_action.get("reason_code", "")) ==
			"no_legal_combat_action",
		"AI reports a stable no-action reason"
	)
	var victory_pending_facts := public_facts.duplicate(true)
	victory_pending_facts["phase"] = "victory_pending"
	var victory_pending := adapter.enumerate_candidates(
		own,
		victory_pending_facts
	)
	_expect(
		(victory_pending.get("candidates", []) as Array).is_empty(),
		"victory pending rejects new combat actions"
	)
	var terminal_facts := public_facts.duplicate(true)
	terminal_facts["phase"] = "final_settlement"
	var terminal := adapter.enumerate_candidates(own, terminal_facts)
	_expect(
		(candidates.size() > 0)
		and (terminal.get("candidates", []) as Array).is_empty(),
		"terminal combat produces no new AI action"
	)
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print(
		"V075_COMBAT_AI_TEST|status=%s|passed=%d|total=%d|failures=%s"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks - _failures.size(),
			_checks,
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)
