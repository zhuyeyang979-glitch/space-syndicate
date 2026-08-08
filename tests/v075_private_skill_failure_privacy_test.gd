extends SceneTree

const RuntimeOwner := preload(
	"res://scripts/v075_runtime/v075_runtime_owner.gd"
)


class RejectingCombatOwner extends Node:
	var rollback_count := 0

	func capture_checkpoint(checkpoint_id: String) -> Dictionary:
		return {"checkpoint_id": checkpoint_id, "revision": 1}

	func request_private_skill(
		_request: Dictionary,
		_asset_state: Dictionary,
		_public_facilities: Array
	) -> Dictionary:
		return {
			"accepted": false,
			"reason_code": "injected_private_skill_rejection",
			"asset_state": {
				"players": {
					"player.rival": {
						"assets": {"technology": 987654321},
					},
				},
			},
			"detail": {
				"future_target": "facility.rival.secret",
				"internal_sequence": 77,
			},
		}

	func rollback_checkpoint(_checkpoint: Dictionary) -> Dictionary:
		rollback_count += 1
		return {"rolled_back": true, "reason_code": "fake_rolled_back"}


class RuntimeHarness extends V075RuntimeOwner:
	var fixture_source := {
		"source_instance_id": "monster.owner.privacy",
		"source_generation": 1,
		"owner_player_id": "player.owner",
		"status": "active",
	}

	func configure(combat_owner: Node) -> void:
		_combat_owner = combat_owner
		_combat_initialized = true
		_player_ids = ["player.owner", "player.rival"]
		_asset_state = {
			"players": {
				"player.owner": {"assets": {"life": 2}},
				"player.rival": {"assets": {"technology": 987654321}},
			},
		}
		_facility_state = {}

	func _public_monster_by_id(source_id: String) -> Dictionary:
		if source_id == str(fixture_source.get("source_instance_id", "")):
			return fixture_source.duplicate(true)
		return {}

	func _owner_skill_by_id(
		_actor_id: String,
		_source_id: String,
		skill_id: String
	) -> Dictionary:
		return {
			"skill_definition_id": skill_id,
			"target_contract": {"target_kind": "self_source"},
		}

	func _public_occupied_facilities() -> Array:
		return []

	func public_payload(source: Dictionary) -> Dictionary:
		return _public_combat_payload(source)


var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var combat := RejectingCombatOwner.new()
	var runtime := RuntimeHarness.new()
	root.add_child(combat)
	root.add_child(runtime)
	runtime.configure(combat)
	var before_assets := (
		runtime.get("_asset_state") as Dictionary
	).duplicate(true)
	var rejected := runtime.request_private_monster_skill(
		"player.owner",
		{
			"source_instance_id": "monster.owner.privacy",
			"source_generation": 1,
			"skill_definition_id": "skill.owner.privacy",
			"target_binding": {
				"target_kind": "monster",
				"target_id": "monster.owner.privacy",
				"target_source_generation": 1,
			},
		}
	)
	var missing_generation_rejected := runtime.request_private_monster_skill(
		"player.owner",
		{
			"source_instance_id": "monster.owner.privacy",
			"skill_definition_id": "skill.owner.privacy",
			"target_binding": {
				"target_kind": "monster",
				"target_id": "monster.owner.privacy",
				"target_source_generation": 1,
			},
		}
	)
	var stale_generation_rejected := runtime.request_private_monster_skill(
		"player.owner",
		{
			"source_instance_id": "monster.owner.privacy",
			"source_generation": 2,
			"skill_definition_id": "skill.owner.privacy",
			"target_binding": {
				"target_kind": "monster",
				"target_id": "monster.owner.privacy",
				"target_source_generation": 2,
			},
		}
	)
	var mixed_target_rejected := runtime.request_private_monster_skill(
		"player.owner",
		{
			"source_instance_id": "monster.owner.privacy",
			"source_generation": 1,
			"skill_definition_id": "skill.owner.privacy",
			"target_binding": {
				"target_kind": "monster",
				"target_id": "monster.owner.privacy",
				"target_source_generation": 1,
				"target_region_id": "region.injected",
			},
		}
	)
	_expect(
		not bool(missing_generation_rejected.get("accepted", true))
		and str(missing_generation_rejected.get("reason_code", ""))
			== "private_skill_source_generation_missing"
		and combat.rollback_count == 1,
		"missing monster source generation is rejected before reservation"
	)
	_expect(
		not bool(stale_generation_rejected.get("accepted", true))
		and str(stale_generation_rejected.get("reason_code", ""))
			== "private_skill_source_generation_stale"
		and combat.rollback_count == 1,
		"stale monster source generation is rejected before the skill boundary"
	)
	_expect(
		not bool(mixed_target_rejected.get("accepted", true))
		and str(mixed_target_rejected.get("reason_code", ""))
			== "private_skill_has_no_legal_target"
		and combat.rollback_count == 1,
		"mixed private target identity is rejected before reservation"
	)
	var rejected_text := JSON.stringify(rejected)
	_expect(
		not bool(rejected.get("accepted", true))
		and str(rejected.get("reason_code", ""))
			== "injected_private_skill_rejection"
		and str(rejected.get("event_kind", ""))
			== "monster_private_skill_request_rejected",
		"the owner receives a minimal typed rejection"
	)
	_expect(
		not rejected_text.contains("asset_state")
		and not rejected_text.contains("player.rival")
		and not rejected_text.contains("987654321")
		and not rejected_text.contains("facility.rival.secret")
		and not rejected_text.contains("internal_sequence"),
		"a rejected private skill exposes no asset, target, or sequence detail"
	)
	_expect(
		combat.rollback_count == 1
		and runtime.get("_asset_state") == before_assets,
		"the rejected request rolls back without mutating authoritative assets"
	)

	var public_payload := runtime.public_payload({
		"public_effect_id": "public.effect.owner.privacy",
		"source_instance_id": "monster.owner.privacy",
		"outcome": "resolved",
		"reason_code": "resolved",
		"public_presentation_key": "monster.effect.flash",
		"public_target": {
			"target_kind": "facility",
			"target_facility_id": "facility.public.target",
			"future_target": "facility.rival.secret",
		},
		"public_result": {
			"effect_summary_key": "combat.monster.skill.resolved",
			"damage_amount": 3,
			"armor_absorbed": 1,
			"status_changes": ["damaged"],
			"skill_definition_id": "skill.owner.privacy",
		},
	})
	var public_text := JSON.stringify(public_payload)
	_expect(
		str(public_payload.get("target_facility_id", ""))
			== "facility.public.target"
		and int(public_payload.get("damage_amount", 0)) == 3
		and int(public_payload.get("armor_absorbed", 0)) == 1,
		"the public result preserves the allowlisted target and effect outcome"
	)
	_expect(
		not public_text.contains("skill.owner.privacy")
		and not public_text.contains("facility.rival.secret")
		and not public_text.contains("future_target"),
		"public effect projection excludes private card and future-target fields"
	)
	var rejection_count_before := int(runtime.get(
		"_v075_public_card_identity_rejection_count"
	))
	var poisoned_payload := runtime.public_payload({
		"public_effect_id": "public.effect.poisoned",
		"public_result": {
			"status_changes": [{
				"nested": {
					"binding_fingerprint": "f".repeat(64),
				},
			}],
		},
	})
	_expect(
		poisoned_payload.is_empty()
		and int(runtime.get(
			"_v075_public_card_identity_rejection_count"
		)) == rejection_count_before + 1
		and int(runtime.get("_hidden_info_violation_count")) >= 1,
		"allowlisted nested status data cannot smuggle a private card binding"
	)
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	print("V075_PRIVATE_SKILL_FAILURE_PRIVACY_TEST|%s|%d/%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks - _failures.size(),
		_checks,
	])
	quit(0 if _failures.is_empty() else 1)
