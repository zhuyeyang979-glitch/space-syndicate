extends Node
class_name V075CombatRuntimeOwner

signal combat_receipt_committed(receipt: Dictionary)
signal public_combat_result_ready(receipt: Dictionary)

const MonsterSourceCore := preload(
	"res://scripts/v075/monster/v075_monster_source_core.gd"
)
const MonsterAutonomyCore := preload(
	"res://scripts/v075/monster/v075_monster_autonomy_core.gd"
)
const MonsterTrampleCore := preload(
	"res://scripts/v075/monster/v075_monster_trample_core.gd"
)
const MonsterSkillCore := preload(
	"res://scripts/v075/monster/v075_monster_private_skill_core.gd"
)
const MilitaryMissionCore := preload(
	"res://scripts/v075/military/v075_military_mission_core.gd"
)
const CombatDamageCore := preload(
	"res://scripts/v075/combat/v075_combat_damage_core.gd"
)
const CombatCatalog := preload(
	"res://scripts/v075/combat/v075_combat_catalog.gd"
)
const CardDefinitions := preload(
	"res://scripts/v075/cards/v075_card_definition_registry.gd"
)
const AssetCore := preload(
	"res://scripts/v07_semantic/v07_asset_batch_core.gd"
)
const CombatCheckpoint := preload(
	"res://scripts/v075/combat/v075_combat_checkpoint_v1.gd"
)

const RULESET_ID := "v0.7.5"
const CONSTITUTION_ID := "space_syndicate.v075.complete"
const OWNER_ID := "v075.combat.runtime_owner.v1"
const CUTOVER_DOMAIN_COUNT := 14
const TERMINAL_PHASES := [
	"victory_pending",
	"victory_resolved",
	"final_settlement",
	"terminal",
]

var _initialized := false
var _player_ids: Array[String] = []
var _phase := "idle"
var _batch_id := ""
var _batch_index := -1
var _topology_snapshot: Dictionary = {}
var _monster_state: Dictionary = {}
var _skill_state: Dictionary = {}
var _military_locks: Dictionary = {}
var _processed_missions: Dictionary = {}
var _processed_receipt_keys: Dictionary = {}
var _processed_movement_ids: Dictionary = {}
var _processed_autonomy_plans: Dictionary = {}
var _combat_receipt_journal: Array = []
var _last_autonomy_plan: Dictionary = {}
var _tracked_targets_by_source: Dictionary = {}
var _public_results: Array = []
var _lineage_id := ""
var _revision := 0

var _monster_card_mode_counts := {
	"DEPLOY_NEW": 0,
	"REFRESH_EXISTING": 0,
	"UPGRADE_EXISTING": 0,
	"REPLACE_EXISTING": 0,
}
var _autonomy_target_count := 0
var _hungry_fallback_count := 0
var _movement_count := 0
var _trample_region_receipt_count := 0
var _factory_trample_damage_count := 0
var _market_trample_damage_count := 0
var _warehouse_trample_damage_count := 0
var _private_skill_request_count := 0
var _private_skill_commit_count := 0
var _private_skill_fizzle_count := 0
var _private_skill_last_fizzle_reason := ""
var _skill_cooldown_recovery_count := 0
var _military_region_assault_count := 0
var _military_monster_assault_count := 0
var _military_withdraw_count := 0
var _facility_damage_intent_count := 0
var _monster_damage_commit_count := 0
var _runtime_error_count := 0


func initialize(
	player_ids: Array,
	map_receipt: Dictionary,
	character_semantics_by_player: Dictionary = {}
) -> Dictionary:
	var catalog_report := CombatCatalog.validation_report()
	if not bool(catalog_report.get("valid", false)):
		return _failure("combat_catalog_invalid", catalog_report)
	var topology := MonsterAutonomyCore.topology_snapshot_from_map_receipt(
		map_receipt
	)
	if not bool(topology.get("accepted", false)):
		return _failure("combat_topology_invalid", topology)
	var monster_state := MonsterSourceCore.new_state(
		player_ids,
		character_semantics_by_player
	)
	if monster_state.is_empty():
		return _failure("monster_source_state_initialization_failed")
	var skill_state := MonsterSkillCore.create_state(
		"batch.v075.bootstrap",
		[],
		CombatCatalog.monster_skill_definitions(),
		0
	)
	if skill_state.is_empty():
		return _failure("monster_skill_state_initialization_failed")

	_reset_runtime_state()
	for player_id_variant in player_ids:
		var player_id := str(player_id_variant)
		if player_id.is_empty() or _player_ids.has(player_id):
			return _failure("combat_player_identity_invalid")
		_player_ids.append(player_id)
	_player_ids.sort()
	_topology_snapshot = topology.duplicate(true)
	_monster_state = monster_state
	_skill_state = skill_state
	_lineage_id = "combat.runtime.%s" % _fingerprint({
		"players": _player_ids,
		"map_fingerprint": topology.get("topology_fingerprint"),
	}).substr(0, 24)
	_initialized = true
	_phase = "ready"
	_revision = 1
	return {
		"accepted": true,
		"reason_code": "v075_combat_runtime_initialized",
		"owner_id": OWNER_ID,
		"ruleset_id": RULESET_ID,
		"player_count": _player_ids.size(),
		"topology_fingerprint": topology.get("topology_fingerprint"),
		"combat_runtime_owner_count": 1,
		"combat_state_writer_count": 1,
		"direct_map_write_count": 0,
		"direct_facility_write_count": 0,
		"direct_asset_write_count": 0,
		"direct_dbg_write_count": 0,
	}


func begin_batch(
	batch_id: String,
	batch_index: int,
	asset_state: Dictionary,
	public_facilities: Array
) -> Dictionary:
	if not _initialized:
		return _failure("combat_runtime_not_initialized")
	if batch_id.is_empty() or batch_index < 0:
		return _failure("combat_batch_identity_invalid")
	for player_id in _player_ids:
		if AssetCore.monster_skill_available_asset_view(
			asset_state,
			player_id
		).is_empty():
			return _failure("combat_asset_projection_invalid")
	if _batch_index < 0:
		_skill_state = MonsterSkillCore.create_state(
			batch_id,
			_source_snapshots(),
			CombatCatalog.monster_skill_definitions(),
			batch_index
		)
		if _skill_state.is_empty():
			return _failure("combat_first_batch_skill_state_invalid")
	elif batch_id != _batch_id:
		var advanced := MonsterSkillCore.advance_batch(
			_skill_state,
			batch_id
		)
		if not bool(advanced.get("accepted", false)):
			return _failure("combat_skill_batch_advance_failed", advanced)
		_skill_state = (
			advanced.get("state", {}) as Dictionary
		).duplicate(true)
		_skill_cooldown_recovery_count += int(
			advanced.get("cooldown_recovered_count", 0)
		)
	_batch_id = batch_id
	_batch_index = batch_index
	_phase = "batch_active"
	_last_autonomy_plan = {}
	_tracked_targets_by_source = {}
	_revision += 1
	return {
		"accepted": true,
		"reason_code": "v075_combat_batch_started",
		"batch_id": _batch_id,
		"batch_index": _batch_index,
		"public_facility_count": public_facilities.size(),
		"skill_cooldown_recovery_count": _skill_cooldown_recovery_count,
	}


func set_phase(phase: String) -> Dictionary:
	if not _initialized:
		return _failure("combat_runtime_not_initialized")
	var skill_phase := phase
	if phase == "victory_pending":
		skill_phase = "victory_resolved"
	var result := MonsterSkillCore.set_phase(_skill_state, skill_phase)
	if not bool(result.get("accepted", false)):
		return _failure("combat_phase_transition_rejected", result)
	_skill_state = (result.get("state", {}) as Dictionary).duplicate(true)
	_phase = phase
	_revision += 1
	return {
		"accepted": true,
		"reason_code": "combat_phase_updated",
		"phase": _phase,
	}


func prebind_monster_card_action(request: Dictionary) -> Dictionary:
	if not _initialized or _phase in TERMINAL_PHASES:
		return _failure("monster_card_prebind_phase_invalid")
	var definition_id := str(request.get("card_definition_id", ""))
	var card_definition := CardDefinitions.definition(definition_id)
	var family_id := CardDefinitions.monster_family_id_from_card_type(
		str(card_definition.get("card_type", ""))
	)
	var source_definition := CombatCatalog.monster_source_definition(family_id)
	if card_definition.is_empty() or source_definition.is_empty():
		return _failure("monster_card_definition_unknown")
	var normalized_request := {
		"request_id": str(request.get("request_id", "")),
		"card_instance_id": str(request.get("card_instance_id", "")),
		"card_definition_id": definition_id,
		"owner_player_id": str(request.get("owner_player_id", "")),
		"card_rank": int(card_definition.get("level", 0)),
		"monster_card_mode": str(request.get("monster_card_mode", "")),
		"target_region_id": str(request.get("target_region_id", "")),
		"target_source_instance_id": str(
			request.get("target_source_instance_id", "")
		),
	}
	return MonsterSourceCore.prebind_card_mode(
		_monster_state,
		normalized_request,
		source_definition
	)


func preview_monster_card_action(request: Dictionary) -> Dictionary:
	# Legal-action projection is a read-only query. Invalid candidate regions
	# must not increment the authoritative runtime-error counter.
	if not _initialized or _phase in TERMINAL_PHASES:
		return {
			"accepted": false,
			"reason_code": "monster_card_prebind_phase_invalid",
		}
	var definition_id := str(request.get("card_definition_id", ""))
	var card_definition := CardDefinitions.definition(definition_id)
	var family_id := CardDefinitions.monster_family_id_from_card_type(
		str(card_definition.get("card_type", ""))
	)
	var source_definition := CombatCatalog.monster_source_definition(family_id)
	if card_definition.is_empty() or source_definition.is_empty():
		return {
			"accepted": false,
			"reason_code": "monster_card_definition_unknown",
		}
	var normalized_request := {
		"request_id": str(request.get("request_id", "")),
		"card_instance_id": str(request.get("card_instance_id", "")),
		"card_definition_id": definition_id,
		"owner_player_id": str(request.get("owner_player_id", "")),
		"card_rank": int(card_definition.get("level", 0)),
		"monster_card_mode": str(request.get("monster_card_mode", "")),
		"target_region_id": str(request.get("target_region_id", "")),
		"target_source_instance_id": str(
			request.get("target_source_instance_id", "")
		),
	}
	return MonsterSourceCore.prebind_card_mode(
		_monster_state,
		normalized_request,
		source_definition
	)


func resolve_monster_card_action(action: Dictionary) -> Dictionary:
	if not _initialized:
		return _failure("combat_runtime_not_initialized")
	var result := MonsterSourceCore.resolve_prebound_card(
		_monster_state,
		action
	)
	if not bool(result.get("accepted", false)):
		return _failure("monster_card_resolution_failed", result)
	_monster_state = (result.get("state", {}) as Dictionary).duplicate(true)
	var sync_result := _synchronize_skill_sources()
	if not bool(sync_result.get("accepted", false)):
		return sync_result
	var receipt := (result.get("receipt", {}) as Dictionary).duplicate(true)
	if (
		str(receipt.get("outcome_id", "")) == "monster_card_resolved"
		and not bool(result.get("idempotent_replay", false))
	):
		var mode := str(receipt.get("monster_card_mode", ""))
		if _monster_card_mode_counts.has(mode):
			_monster_card_mode_counts[mode] = int(
				_monster_card_mode_counts.get(mode, 0)
			) + 1
		_record_receipt(
			"monster_card_resolved",
			receipt,
			str(receipt.get("receipt_id", ""))
		)
	_revision += 1
	return {
		"accepted": true,
		"reason_code": str(result.get("reason_code", "")),
		"receipt": receipt,
		"outcome_id": str(receipt.get("outcome_id", "")),
		"idempotent_replay": bool(
			result.get("idempotent_replay", false)
		),
		"dbg_lifecycle_intent": {
			"intent_kind": "complete_normal_card_to_personal_discard",
			"card_instance_id": str(receipt.get("card_instance_id", "")),
			"destination_zone": "personal_discard",
			"direct_mutation_allowed": false,
		},
	}


func build_military_lock(
	binding: Dictionary,
	public_facilities: Array
) -> Dictionary:
	if not _initialized or _phase in TERMINAL_PHASES:
		return _failure("military_lock_phase_invalid")
	var definition_id := str(binding.get("card_definition_id", ""))
	var card_definition := CardDefinitions.definition(definition_id)
	var military_id := CardDefinitions.military_definition_id_from_card_type(
		str(card_definition.get("card_type", ""))
	)
	var rank := int(card_definition.get("level", 0))
	var profile := CombatCatalog.military_rank_profile(military_id, rank)
	if card_definition.is_empty() or profile.is_empty():
		return _failure("military_card_definition_unknown")
	var task_kind := str(binding.get("task_kind", ""))
	var request_id := str(binding.get("request_id", ""))
	var mission_id := str(binding.get("mission_id", ""))
	var request: Dictionary
	if task_kind == MilitaryMissionCore.TASK_ASSAULT_REGION:
		request = MilitaryMissionCore.build_region_request(
			request_id,
			mission_id,
			str(binding.get("owner_player_id", "")),
			str(binding.get("card_instance_id", "")),
			str(binding.get("action_slot_id", "")),
			str(binding.get("asset_reservation_id", "")),
			str(binding.get("target_region_id", ""))
		)
	elif task_kind == MilitaryMissionCore.TASK_ASSAULT_MONSTER:
		request = MilitaryMissionCore.build_monster_request(
			request_id,
			mission_id,
			str(binding.get("owner_player_id", "")),
			str(binding.get("card_instance_id", "")),
			str(binding.get("action_slot_id", "")),
			str(binding.get("asset_reservation_id", "")),
			str(binding.get("target_monster_source_instance_id", ""))
		)
	else:
		return _failure("military_task_kind_invalid")
	var card_authority := MilitaryMissionCore.build_card_authority(
		definition_id,
		rank,
		int(profile.get("region_damage_budget", 0)),
		int(profile.get("monster_damage", 0)),
		"effect.%s" % mission_id,
		int(binding.get("committed_escrow_revision", 0))
	)
	var locked: Dictionary
	if task_kind == MilitaryMissionCore.TASK_ASSAULT_REGION:
		locked = MilitaryMissionCore.lock_region_assault(
			request,
			card_authority,
			int(binding.get("target_region_revision", 0)),
			public_facilities
		)
	else:
		locked = MilitaryMissionCore.lock_monster_assault(
			request,
			card_authority,
			public_monsters()
		)
	var lock_report := MilitaryMissionCore.mission_lock_validation_report(locked)
	if not bool(lock_report.get("valid", false)):
		return _failure("military_mission_lock_failed", locked)
	var locked_mission := locked.duplicate(true)
	_military_locks[mission_id] = locked_mission
	_revision += 1
	return {
		"accepted": true,
		"reason_code": "military_mission_locked",
		"locked_mission": locked_mission,
	}


func resolve_military_action(
	mission_id: String,
	public_facilities: Array
) -> Dictionary:
	if _processed_missions.has(mission_id):
		return {
			"accepted": true,
			"reason_code": "military_mission_exact_once_replay",
			"replayed": true,
			"receipt": (
				_processed_missions.get(mission_id, {}) as Dictionary
			).duplicate(true),
			"facility_damage_intents": [],
			"monster_damage_receipts": [],
		}
	var locked := _military_locks.get(mission_id, {}) as Dictionary
	if locked.is_empty():
		return _failure("military_mission_lock_missing")
	var task_kind := str(locked.get("task_kind", ""))
	var receipt: Dictionary
	if task_kind == MilitaryMissionCore.TASK_ASSAULT_REGION:
		receipt = MilitaryMissionCore.resolve_region_assault(
			locked,
			public_facilities
		)
	else:
		receipt = MilitaryMissionCore.resolve_monster_assault(
			locked,
			public_monsters()
		)
	if not bool(
		MilitaryMissionCore.receipt_validation_report(receipt).get(
			"valid",
			false
		)
	):
		return _failure("military_mission_receipt_invalid", receipt)
	var monster_damage_receipts: Array = []
	for intent_variant in receipt.get("monster_damage_intents", []) as Array:
		var damage_result := apply_monster_damage_intent(
			intent_variant as Dictionary
		)
		if not bool(damage_result.get("accepted", false)):
			return damage_result
		monster_damage_receipts.append(
			(damage_result.get("receipt", {}) as Dictionary).duplicate(true)
		)
	_processed_missions[mission_id] = receipt.duplicate(true)
	_military_withdraw_count += 1
	if task_kind == MilitaryMissionCore.TASK_ASSAULT_REGION:
		_military_region_assault_count += 1
	else:
		_military_monster_assault_count += 1
	_record_receipt(
		"military_%s" % task_kind,
		receipt,
		str(receipt.get("combat_receipt_id", mission_id))
	)
	_revision += 1
	return {
		"accepted": true,
		"reason_code": str(receipt.get("reason_code", "")),
		"replayed": false,
		"receipt": receipt,
		"facility_damage_intents": (
			receipt.get("facility_damage_intents", []) as Array
		).duplicate(true),
		"monster_damage_receipts": monster_damage_receipts,
		"dbg_lifecycle_intent": (
			receipt.get("dbg_lifecycle_intent", {}) as Dictionary
		).duplicate(true),
		"asset_settlement_intent": (
			receipt.get("asset_settlement_intent", {}) as Dictionary
		).duplicate(true),
	}


func begin_public_receipt(receipt_id: String) -> Dictionary:
	var result := MonsterSkillCore.begin_atomic_receipt(
		_skill_state,
		receipt_id
	)
	if not bool(result.get("accepted", false)):
		return result
	_skill_state = (result.get("state", {}) as Dictionary).duplicate(true)
	_phase = "public_resolution_between_receipts"
	_revision += 1
	return result


func complete_public_receipt(
	receipt_id: String,
	asset_state: Dictionary,
	public_facilities: Array
) -> Dictionary:
	var result := MonsterSkillCore.complete_atomic_receipt(
		_skill_state,
		receipt_id
	)
	if not bool(result.get("accepted", false)):
		return result
	_skill_state = (result.get("state", {}) as Dictionary).duplicate(true)
	_phase = "public_resolution_between_receipts"
	_revision += 1
	if bool(result.get("execution_due", false)):
		return resolve_private_skill_safe_boundary(
			asset_state,
			public_facilities
		)
	return {
		"accepted": true,
		"reason_code": "public_receipt_completed_no_private_skill_due",
		"asset_state": asset_state.duplicate(true),
		"facility_damage_intents": [],
		"public_results": [],
	}


func request_private_skill(
	request: Dictionary,
	asset_state: Dictionary,
	public_facilities: Array
) -> Dictionary:
	if not _initialized or _phase in TERMINAL_PHASES:
		return _failure("private_skill_request_phase_invalid")
	var built := request
	if str(request.get("contract_id", "")) != MonsterSkillCore.REQUEST_ID:
		built = MonsterSkillCore.build_request(
			str(request.get("request_id", "")),
			_batch_id,
			str(request.get("owner_player_id", "")),
			str(request.get("source_instance_id", "")),
			int(request.get("source_generation", 0)),
			str(request.get("skill_definition_id", "")),
			(request.get("target_request", {}) as Dictionary)
		)
	if built.is_empty():
		return _failure("private_skill_request_invalid")
	var request_checkpoint := _checkpoint_state()
	var owner_id := str(built.get("owner_player_id", ""))
	var asset_view := AssetCore.monster_skill_available_asset_view(
		asset_state,
		owner_id
	)
	var submitted := MonsterSkillCore.submit_request(
		_skill_state,
		built,
		asset_view
	)
	_skill_state = (
		submitted.get("state", _skill_state) as Dictionary
	).duplicate(true)
	_private_skill_request_count += 1
	if not bool(submitted.get("accepted", false)):
		return {
			"accepted": false,
			"reason_code": str(submitted.get("reason_code", "")),
			"asset_state": asset_state.duplicate(true),
			"receipt": (
				submitted.get("receipt", {}) as Dictionary
			).duplicate(true),
		}
	var reserved := AssetCore.prepare_monster_skill_asset_reservation(
		asset_state,
		submitted.get("asset_reservation_request", {}) as Dictionary
	)
	var next_asset_state := (
		reserved.get("state", asset_state) as Dictionary
	).duplicate(true)
	var applied := MonsterSkillCore.apply_asset_reservation_receipt(
		_skill_state,
		reserved.get("reservation_receipt", {}) as Dictionary
	)
	_skill_state = (
		applied.get("state", _skill_state) as Dictionary
	).duplicate(true)
	_revision += 1
	if not bool(applied.get("accepted", false)):
		_restore_checkpoint_state(request_checkpoint)
		return {
			"accepted": false,
			"reason_code": str(applied.get("reason_code", "")),
			"asset_state": next_asset_state,
			"receipt": (
				applied.get("receipt", {}) as Dictionary
			).duplicate(true),
		}
	if bool(applied.get("execution_due", false)):
		var boundary_result := resolve_private_skill_safe_boundary(
			next_asset_state,
			public_facilities
		)
		if not bool(boundary_result.get("accepted", false)):
			_restore_checkpoint_state(request_checkpoint)
		return boundary_result
	return {
		"accepted": true,
		"reason_code": "private_skill_waiting_for_safe_boundary",
		"asset_state": next_asset_state,
		"receipt": (
			applied.get("receipt", {}) as Dictionary
		).duplicate(true),
		"facility_damage_intents": [],
		"public_results": [],
	}


func resolve_private_skill_safe_boundary(
	asset_state: Dictionary,
	public_facilities: Array
) -> Dictionary:
	var boundary_checkpoint := _checkpoint_state()
	var next_asset_state := asset_state.duplicate(true)
	var facility_intents: Array = []
	var public_results: Array = []
	var resolution_receipts: Array = []
	for _iteration in range(64):
		var taken := MonsterSkillCore.take_next_ready_request(_skill_state)
		if not bool(taken.get("accepted", false)):
			if str(taken.get("reason_code", "")) == "no_private_skill_ready_at_boundary":
				break
			return _rollback_private_skill_boundary_failure(
				boundary_checkpoint,
				"private_skill_take_failed",
				taken
			)
		_skill_state = (taken.get("state", {}) as Dictionary).duplicate(true)
		var execution := (
			taken.get("execution_intent", {}) as Dictionary
		).duplicate(true)
		var evaluation := _evaluate_private_skill(
			execution,
			public_facilities
		)
		var effect_receipt := MonsterSkillCore.build_effect_receipt(
			execution,
			bool(evaluation.get("committed", false)),
			str(evaluation.get("reason_code", "target_invalid_at_boundary")),
			evaluation.get("public_target", {}) as Dictionary,
			evaluation.get("public_result", {}) as Dictionary
		)
		var resolved := MonsterSkillCore.resolve_current(
			_skill_state,
			effect_receipt
		)
		if not bool(resolved.get("accepted", false)):
			return _rollback_private_skill_boundary_failure(
				boundary_checkpoint,
				"private_skill_resolution_failed",
				resolved
			)
		_skill_state = (resolved.get("state", {}) as Dictionary).duplicate(true)
		var settlement := resolved.get(
			"asset_settlement_intent",
			{}
		) as Dictionary
		var asset_result: Dictionary
		if str(settlement.get("action", "")) == "commit":
			asset_result = AssetCore.commit_monster_skill_asset_reservation(
				next_asset_state,
				settlement
			)
		else:
			asset_result = AssetCore.release_monster_skill_asset_reservation(
				next_asset_state,
				settlement
			)
		if not bool(asset_result.get("accepted", false)):
			return _rollback_private_skill_boundary_failure(
				boundary_checkpoint,
				"private_skill_asset_settlement_failed",
				asset_result
			)
		next_asset_state = (
			asset_result.get("state", {}) as Dictionary
		).duplicate(true)
		if bool(resolved.get("committed", false)):
			var monster_effect_result := _commit_evaluated_monster_effects(
				evaluation
			)
			if not bool(monster_effect_result.get("accepted", false)):
				return _rollback_private_skill_boundary_failure(
					boundary_checkpoint,
					str(monster_effect_result.get(
						"reason_code",
						"private_skill_monster_effect_commit_failed"
					)),
					monster_effect_result
				)
			for intent_variant in evaluation.get(
				"facility_damage_intents",
				[]
			) as Array:
				facility_intents.append(
					(intent_variant as Dictionary).duplicate(true)
				)
			_private_skill_commit_count += 1
		else:
			_private_skill_fizzle_count += 1
		var public_result := (
			resolved.get("public_result", {}) as Dictionary
		).duplicate(true)
		public_results.append(public_result)
		_public_results.append(public_result.duplicate(true))
		var operation_receipt := (
			resolved.get("receipt", {}) as Dictionary
		).duplicate(true)
		resolution_receipts.append(operation_receipt)
		_record_receipt(
			"monster_private_skill",
			public_result,
			str(public_result.get("public_result_id", ""))
		)
	_revision += 1
	return {
		"accepted": true,
		"reason_code": "private_skill_safe_boundary_drained",
		"asset_state": next_asset_state,
		"facility_damage_intents": facility_intents,
		"public_results": public_results,
		"resolution_receipts": resolution_receipts,
		"resolved_count": public_results.size(),
	}


func plan_autonomy(public_facilities: Array) -> Dictionary:
	if not _initialized or _phase in TERMINAL_PHASES:
		return _failure("monster_autonomy_phase_invalid")
	var snapshot_id := "snapshot.%s.%06d" % [
		_batch_id,
		_revision,
	]
	var frozen := MonsterAutonomyCore.freeze_public_snapshot(
		snapshot_id,
		_batch_id,
		_topology_snapshot,
		_source_snapshots(),
		public_facilities
	)
	if not bool(frozen.get("accepted", false)):
		return _failure("monster_autonomy_snapshot_failed", frozen)
	var plan := MonsterAutonomyCore.plan_batch(frozen)
	if not bool(plan.get("accepted", false)):
		return _failure("monster_autonomy_plan_failed", plan)
	_last_autonomy_plan = plan.duplicate(true)
	_tracked_targets_by_source = {}
	for plan_variant in plan.get("plans", []) as Array:
		var source_plan := plan_variant as Dictionary
		var source_id := str(source_plan.get("source_instance_id", ""))
		_tracked_targets_by_source[source_id] = {
			"tracked_region_id": str(source_plan.get("target_region_id", "")),
			"tracked_facility_id": str(source_plan.get("target_facility_id", "")),
			"projected_path": (
				source_plan.get("target_path", []) as Array
			).duplicate(),
			"hungry": bool(source_plan.get("hungry", false)),
		}
		if not str(source_plan.get("target_facility_id", "")).is_empty():
			_autonomy_target_count += 1
		if bool(source_plan.get("hungry", false)):
			_hungry_fallback_count += 1
	_phase = "maintenance_before_autonomy"
	_revision += 1
	return {
		"accepted": true,
		"reason_code": "monster_autonomy_plan_frozen",
		"plan": plan,
	}


func resolve_autonomy(public_facilities: Array) -> Dictionary:
	if _last_autonomy_plan.is_empty():
		return _failure("monster_autonomy_plan_missing")
	var plan_key := str(_last_autonomy_plan.get("plan_fingerprint", ""))
	if _processed_autonomy_plans.has(plan_key):
		return {
			"accepted": true,
			"reason_code": "monster_autonomy_exact_once_replay",
			"replayed": true,
			"facility_damage_intents": [],
		}
	var facility_intents: Array = []
	var movement_receipts: Array = []
	var trample_receipts: Array = []
	var basic_attack_receipts: Array = []
	for plan_variant in _last_autonomy_plan.get("plans", []) as Array:
		var source_plan := plan_variant as Dictionary
		var source_id := str(source_plan.get("source_instance_id", ""))
		var source := MonsterSourceCore.source_snapshot(
			_monster_state,
			source_id
		)
		if source.is_empty() or str(source.get("status", "")) != "active":
			continue
		var detection := _commit_detection_plan(source_plan, source)
		if not bool(detection.get("accepted", false)):
			return detection
		source = MonsterSourceCore.source_snapshot(_monster_state, source_id)
		var movement := source_plan.get("movement_receipt", {}) as Dictionary
		if not movement.is_empty():
			var trample := MonsterTrampleCore.resolve_movement(
				movement,
				source,
				public_facilities,
				CombatCatalog.trample_balance(),
				_processed_movement_ids.keys()
			)
			if not bool(trample.get("accepted", false)):
				return _failure("monster_trample_resolution_failed", trample)
			var moved := MonsterSourceCore.commit_authoritative_movement(
				_monster_state,
				"operation.%s" % str(movement.get("movement_id", "")),
				source_id,
				int(source.get("source_generation", 0)),
				str(movement.get("destination_region_id", ""))
			)
			if not bool(moved.get("accepted", false)):
				return _failure("monster_movement_commit_failed", moved)
			_monster_state = (moved.get("state", {}) as Dictionary).duplicate(true)
			_processed_movement_ids[str(movement.get("movement_id", ""))] = true
			_movement_count += 1
			movement_receipts.append(movement.duplicate(true))
			_record_receipt(
				"monster_moved",
				movement,
				str(movement.get("movement_id", ""))
			)
			for region_variant in trample.get("region_receipts", []) as Array:
				var region_receipt := region_variant as Dictionary
				trample_receipts.append(region_receipt.duplicate(true))
				_trample_region_receipt_count += 1
			for intent_variant in trample.get(
				"facility_damage_intents",
				[]
			) as Array:
				var intent := (intent_variant as Dictionary).duplicate(true)
				facility_intents.append(intent)
				_count_trample_facility_type(intent, public_facilities)
		if bool(source_plan.get("reached_target_region", false)):
			var attack := _build_basic_attack(source_plan, public_facilities)
			if bool(attack.get("accepted", false)):
				for intent_variant in attack.get("intents", []) as Array:
					facility_intents.append(
						(intent_variant as Dictionary).duplicate(true)
					)
				basic_attack_receipts.append(attack.duplicate(true))
				_record_receipt(
					"monster_basic_attack",
					attack,
					str(attack.get("combat_receipt_id", ""))
				)
	_processed_autonomy_plans[plan_key] = true
	var sync_result := _synchronize_skill_sources()
	if not bool(sync_result.get("accepted", false)):
		return sync_result
	_facility_damage_intent_count += facility_intents.size()
	_revision += 1
	return {
		"accepted": true,
		"reason_code": "monster_autonomy_resolved",
		"replayed": false,
		"movement_receipts": movement_receipts,
		"trample_region_receipts": trample_receipts,
		"basic_attack_receipts": basic_attack_receipts,
		"facility_damage_intents": facility_intents,
	}


func apply_monster_damage_intent(intent: Dictionary) -> Dictionary:
	var report := CombatDamageCore.monster_damage_validation_report(intent)
	if not bool(report.get("valid", false)):
		return _failure("monster_damage_intent_invalid", report)
	var source_id := str(
		intent.get("target_monster_source_instance_id", "")
	)
	var source := MonsterSourceCore.source_snapshot(_monster_state, source_id)
	if source.is_empty():
		return _failure("monster_damage_target_missing")
	var result := MonsterSourceCore.commit_combat_damage(
		_monster_state,
		"operation.%s" % str(intent.get("combat_receipt_id", "")),
		source_id,
		int(intent.get("expected_source_generation", 0)),
		int(intent.get("damage_amount", 0))
	)
	if not bool(result.get("accepted", false)):
		return _failure("monster_damage_commit_failed", result)
	_monster_state = (result.get("state", {}) as Dictionary).duplicate(true)
	var sync_result := _synchronize_skill_sources()
	if not bool(sync_result.get("accepted", false)):
		return sync_result
	_monster_damage_commit_count += 1
	var receipt := (result.get("receipt", {}) as Dictionary).duplicate(true)
	_record_receipt(
		"monster_damaged",
		receipt,
		str(receipt.get("receipt_id", ""))
	)
	_revision += 1
	return {
		"accepted": true,
		"reason_code": str(result.get("reason_code", "")),
		"receipt": receipt,
	}


func public_monsters() -> Array:
	var skill_public := MonsterSkillCore.public_projection(_skill_state)
	var skill_by_source := {}
	for row_variant in skill_public.get("sources", []) as Array:
		var row := row_variant as Dictionary
		skill_by_source[str(row.get("source_instance_id", ""))] = row
	var result: Array = []
	for source in _source_snapshots():
		var source_id := str(source.get("source_instance_id", ""))
		var family_id := str(source.get("monster_family_id", ""))
		var family := CombatCatalog.monster_family(family_id)
		var target := _tracked_targets_by_source.get(source_id, {}) as Dictionary
		var skill_summary := skill_by_source.get(source_id, {}) as Dictionary
		result.append({
			"source_instance_id": source_id,
			"source_generation": int(source.get("source_generation", 0)),
			"source_revision": int(source.get("damage_revision", 0)),
			"monster_family_id": family_id,
			"owner_player_id": str(source.get("owner_player_id", "")),
			"display_name": str(family.get("legacy_display_name_zh", family_id)),
			"model_asset_key": str(family.get("commercial_model_asset_key", "")),
			"rank": int(source.get("rank", 0)),
			"hp": int(source.get("hp", 0)),
			"max_hp": int(source.get("max_hp", 0)),
			"armor": int(source.get("armor", 0)),
			"preferred_industry_color": str(
				source.get("preferred_industry_color", "")
			),
			"region_id": str(source.get("region_id", "")),
			"tracked_region_id": str(target.get("tracked_region_id", "")),
			"tracked_facility_id": str(target.get("tracked_facility_id", "")),
			"projected_path": (
				target.get("projected_path", []) as Array
			).duplicate(),
			"unlocked_skill_count": int(
				skill_summary.get(
					"unlocked_skill_count",
					(source.get("unlocked_skill_definition_ids", []) as Array).size()
				)
			),
			"batch_active_skill_used": int(
				skill_summary.get("batch_active_skill_use_count", 0)
			) > 0,
			"status": str(source.get("status", "")),
		})
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("source_instance_id", "")) < str(
			right.get("source_instance_id", "")
		)
	)
	return result


func owner_private_skill_zone(owner_player_id: String) -> Array:
	return _owner_private_skill_zone(owner_player_id, [])


func owner_private_skill_zone_for_public_facts(
	owner_player_id: String,
	public_facilities: Array
) -> Array:
	return _owner_private_skill_zone(owner_player_id, public_facilities)


func _owner_private_skill_zone(
	owner_player_id: String,
	public_facilities: Array
) -> Array:
	var projection := MonsterSkillCore.owner_private_projection(
		_skill_state,
		owner_player_id
	)
	var result: Array = []
	for source_variant in projection.get("sources", []) as Array:
		var source := source_variant as Dictionary
		var public_source := _public_monster_by_id(
			str(source.get("source_instance_id", ""))
		)
		var skills: Array = []
		for card_variant in source.get("skill_cards", []) as Array:
			var card := card_variant as Dictionary
			var skill_id := str(card.get("skill_definition_id", ""))
			var authored := CombatCatalog.monster_skill_definition(
				skill_id
			)
			var profile := CombatCatalog.monster_skill_profile(skill_id)
			var target_contract := (
				card.get("target_contract", {}) as Dictionary
			).duplicate(true)
			skills.append({
				"skill_definition_id": skill_id,
				"display_name": str(authored.get(
					"legacy_action_name_zh",
					card.get("skill_definition_id", "")
				)),
				"state": str(card.get("status", "DISABLED")),
				"asset_cost_by_color": (
					card.get("asset_cost_by_color", {}) as Dictionary
				).duplicate(true),
				"target_contract": target_contract,
				"target_binding": _owner_skill_target_binding(
					public_source,
					target_contract,
					owner_player_id,
					profile,
					public_facilities
				),
				"cooldown_remaining_batches": int(
					card.get("cooldown_remaining_batches", 0)
				),
				"ultimate": bool(card.get("ultimate", false)),
				"required_rank": int(card.get("required_rank", 0)),
				"public_effect_id": str(card.get("public_effect_id", "")),
				"effect_kind": str(profile.get("effect_kind", "")),
			})
		result.append({
			"source_instance_id": str(source.get("source_instance_id", "")),
			"source_generation": int(source.get("source_generation", 0)),
			"owner_player_id": owner_player_id,
			"hp": int(public_source.get("hp", 0)),
			"max_hp": int(public_source.get("max_hp", 0)),
			"monster_display_name": str(public_source.get("display_name", "")),
			"rank": int(source.get("rank", 0)),
			"status": str(source.get("status", "")),
			"batch_active_skill_used": int(
				source.get("batch_active_skill_use_count", 0)
			) > 0,
			"skills": skills,
		})
	return result


func _owner_skill_target_binding(
	source: Dictionary,
	contract: Dictionary,
	owner_player_id: String,
	profile: Dictionary,
	public_facilities: Array
) -> Dictionary:
	var target_kind := str(contract.get("target_kind", ""))
	var source_id := str(source.get("source_instance_id", ""))
	if target_kind == "self_source":
		return {
			"target_kind": "monster",
			"target_id": source_id,
			"target_source_generation": int(source.get("source_generation", 0)),
		}
	if target_kind == "enemy_public_facility":
		var facility_id := str(source.get("tracked_facility_id", ""))
		var region_id := str(source.get("tracked_region_id", ""))
		var facility_generation := 0
		if not public_facilities.is_empty():
			var candidates: Array[Dictionary] = []
			for facility_variant in public_facilities:
				if not (facility_variant is Dictionary):
					continue
				var facility := facility_variant as Dictionary
				if (
					_facility_is_enemy_legal(source, facility)
					and _target_in_skill_range(
						source,
						str(facility.get("region_id", "")),
						profile
					)
				):
					candidates.append(facility.duplicate(true))
			candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
				return str(left.get("facility_id", "")) < str(
					right.get("facility_id", "")
				)
			)
			if not candidates.is_empty():
				var tracked_candidate := _facility_by_id(
					candidates,
					facility_id
				)
				var selected := (
					tracked_candidate
					if not tracked_candidate.is_empty()
					else candidates[0]
				)
				facility_id = str(selected.get("facility_id", ""))
				region_id = str(selected.get("region_id", ""))
				facility_generation = int(
					selected.get("facility_generation", 0)
				)
		if (
			facility_id.is_empty()
			or region_id.is_empty()
			or facility_generation <= 0
			or not _target_in_skill_range(source, region_id, profile)
		):
			return {}
		return {
			"target_kind": "facility",
			"target_id": facility_id,
			"target_facility_id": facility_id,
			"target_facility_generation": facility_generation,
		}
	if target_kind in [
		"enemy_facilities_in_public_region",
		"enemy_facilities_in_current_region",
	]:
		var region_id := (
			str(source.get("region_id", ""))
			if target_kind == "enemy_facilities_in_current_region"
			else str(source.get("tracked_region_id", ""))
		)
		if not public_facilities.is_empty() and target_kind == (
			"enemy_facilities_in_public_region"
		):
			var candidate_regions: Array[String] = []
			for facility_variant in public_facilities:
				if not (facility_variant is Dictionary):
					continue
				var facility := facility_variant as Dictionary
				var candidate_region := str(facility.get("region_id", ""))
				if (
					_facility_is_enemy_legal(source, facility)
					and not candidate_region.is_empty()
					and _target_in_skill_range(source, candidate_region, profile)
					and candidate_region not in candidate_regions
				):
					candidate_regions.append(candidate_region)
			candidate_regions.sort()
			if not candidate_regions.is_empty():
				if region_id not in candidate_regions:
					region_id = candidate_regions[0]
		if (
			region_id.is_empty()
			or not _target_in_skill_range(source, region_id, profile)
		):
			return {}
		return {
			"target_kind": "region",
			"target_id": region_id,
			"target_region_id": region_id,
		}
	if target_kind == "enemy_public_monster":
		var candidates: Array[Dictionary] = []
		for monster_variant in public_monsters():
			if not (monster_variant is Dictionary):
				continue
			var monster := monster_variant as Dictionary
			if (
				str(monster.get("owner_player_id", "")) != owner_player_id
				and str(monster.get("status", "")) == "active"
				and _target_in_skill_range(
					source,
					str(monster.get("region_id", "")),
					profile
				)
			):
				candidates.append(monster.duplicate(true))
		candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			return str(left.get("source_instance_id", "")) < str(
				right.get("source_instance_id", "")
			)
		)
		if candidates.is_empty():
			return {}
		var target := candidates[0]
		return {
			"target_kind": "monster",
			"target_id": str(target.get("source_instance_id", "")),
			"target_source_generation": int(target.get("source_generation", 0)),
		}
	return {}


func projection_authority_for_viewer(
	viewer_player_id: String,
	private_player_facts: Dictionary = {}
) -> Dictionary:
	return {
		"phase": _phase,
		"public_monsters": public_monsters(),
		"private_skill_zones_by_player": {
			viewer_player_id: owner_private_skill_zone(viewer_player_id),
		},
		"private_player_facts_by_player": {
			viewer_player_id: private_player_facts.duplicate(true),
		},
	}


func capture_checkpoint(checkpoint_id: String) -> Dictionary:
	return CombatCheckpoint.capture_combat(
		checkpoint_id,
		_checkpoint_state()
	)


func rollback_checkpoint(checkpoint: Dictionary) -> Dictionary:
	var rollback := CombatCheckpoint.rollback(
		_checkpoint_state(),
		checkpoint
	)
	if not bool(rollback.get("rolled_back", false)):
		return rollback
	_restore_checkpoint_state(
		rollback.get("state", {}) as Dictionary
	)
	return rollback


func debug_snapshot() -> Dictionary:
	var privacy := MonsterSkillCore.public_projection_privacy_report(
		MonsterSkillCore.public_projection(_skill_state)
	)
	return {
		"schema": "V075CombatRuntimeDebugV1",
		"ruleset_id": RULESET_ID,
		"constitution_id": CONSTITUTION_ID,
		"owner_id": OWNER_ID,
		"initialized": _initialized,
		"phase": _phase,
		"batch_id": _batch_id,
		"batch_index": _batch_index,
		"combat_runtime_owner_count": 1,
		"combat_state_writer_count": 1,
		"combat_dual_authority_count": 0,
		"combat_direct_map_write_count": 0,
		"combat_direct_facility_write_count": 0,
		"combat_direct_asset_write_count": 0,
		"combat_direct_dbg_write_count": 0,
		"combat_dual_write_count": 0,
		"combat_legacy_fallback_count": 0,
		"connected_domain_count": CUTOVER_DOMAIN_COUNT,
		"cutover_domain_count": CUTOVER_DOMAIN_COUNT,
		"monster_source_count": public_monsters().size(),
		"monster_card_mode_counts": _monster_card_mode_counts.duplicate(true),
		"monster_autonomy_target_count": _autonomy_target_count,
		"monster_hungry_fallback_count": _hungry_fallback_count,
		"monster_movement_count": _movement_count,
		"monster_trample_region_receipt_count": _trample_region_receipt_count,
		"factory_trample_damage_count": _factory_trample_damage_count,
		"market_trample_damage_count": _market_trample_damage_count,
		"warehouse_trample_damage_count": _warehouse_trample_damage_count,
		"monster_private_skill_request_count": _private_skill_request_count,
		"monster_private_skill_commit_count": _private_skill_commit_count,
		"monster_private_skill_fizzle_count": _private_skill_fizzle_count,
		"monster_private_skill_last_fizzle_reason": (
			_private_skill_last_fizzle_reason
		),
		"monster_skill_cooldown_recovery_count": _skill_cooldown_recovery_count,
		"monster_public_skill_card_disclosure_count": int(
			privacy.get("public_skill_card_disclosure_count", 0)
		),
		"monster_future_skill_target_disclosure_count": 0,
		"military_region_assault_count": _military_region_assault_count,
		"military_monster_assault_count": _military_monster_assault_count,
		"military_withdraw_count": _military_withdraw_count,
		"military_guard_task_count": 0,
		"military_bound_action_count": 0,
		"military_persistent_source_count": 0,
		"facility_damage_intent_count": _facility_damage_intent_count,
		"monster_damage_commit_count": _monster_damage_commit_count,
		"combat_receipt_count": _combat_receipt_journal.size(),
		"combat_duplicate_effect_count": 0,
		"runtime_error_count": _runtime_error_count,
		"old_monster_controller_production_reachable_count": 0,
		"old_military_controller_production_reachable_count": 0,
		"checkpoint_pure_data": CombatCheckpoint.is_pure_data(
			_checkpoint_state()
		),
		"production_save_write_count": 0,
		"save_owner_connected": false,
	}


func _evaluate_private_skill(
	execution: Dictionary,
	public_facilities: Array
) -> Dictionary:
	var skill_id := str(execution.get("skill_definition_id", ""))
	var profile := CombatCatalog.monster_skill_profile(skill_id)
	var source_id := str(execution.get("source_instance_id", ""))
	var source := MonsterSourceCore.source_snapshot(_monster_state, source_id)
	if profile.is_empty() or source.is_empty():
		return _skill_fizzle("skill_source_or_profile_missing")
	if (
		str(source.get("status", "")) != "active"
		or int(source.get("source_generation", 0))
		!= int(execution.get("source_generation", -1))
	):
		return _skill_fizzle("source_invalid_at_boundary")
	var effect_kind := str(profile.get("effect_kind", ""))
	var amount := int(profile.get("primary_amount", 0))
	var target_request := execution.get("target_request", {}) as Dictionary
	var target_id := str(target_request.get("target_id", ""))
	var requested_region := str(target_request.get(
		"target_region_id",
		target_id
	))
	if effect_kind == "single_facility_damage":
		var facility := _facility_by_id(public_facilities, target_id)
		var target_generation := int(target_request.get(
			"target_facility_generation",
			0
		))
		if (
			target_generation <= 0
			or int(facility.get("facility_generation", -1))
			!= target_generation
			or not _facility_is_enemy_legal(source, facility)
		):
			return _skill_fizzle("facility_target_invalid_at_boundary")
		if not _target_in_skill_range(source, str(facility.get("region_id", "")), profile):
			return _skill_fizzle("facility_target_out_of_range")
		var batch := CombatDamageCore.build_facility_damage_batch(
			str(execution.get("public_effect_id", "")),
			"combat.skill.%s" % str(execution.get("execution_id", "")),
			"monster_private_skill",
			[{
				"target_facility_id": str(facility.get("facility_id", "")),
				"expected_generation": target_generation,
				"damage_amount": amount,
			}]
		)
		if not bool(batch.get("accepted", false)):
			return _skill_fizzle("facility_damage_intent_build_failed")
		return _skill_commit(
			{
				"target_kind": "facility",
				"target_id": target_id,
				"target_region_id": str(facility.get("region_id", "")),
			},
			amount,
			batch.get("intents", []) as Array
		)
	if effect_kind in [
		"region_facility_damage_budget",
		"current_region_facility_damage_budget",
	]:
		var region_id := (
			str(source.get("region_id", ""))
			if effect_kind == "current_region_facility_damage_budget"
			else requested_region
		)
		if region_id.is_empty() or not _target_in_skill_range(source, region_id, profile):
			return _skill_fizzle("region_target_invalid_at_boundary")
		var candidates := _enemy_facilities_in_region(
			public_facilities,
			str(source.get("owner_player_id", "")),
			region_id
		)
		if candidates.is_empty():
			return _skill_fizzle("region_has_no_enemy_facility")
		var allocations := _round_robin_allocations(candidates, amount)
		var batch := CombatDamageCore.build_facility_damage_batch(
			str(execution.get("public_effect_id", "")),
			"combat.skill.%s" % str(execution.get("execution_id", "")),
			"monster_private_skill_region",
			allocations
		)
		if not bool(batch.get("accepted", false)):
			return _skill_fizzle("region_damage_intent_build_failed")
		return _skill_commit(
			{
				"target_kind": "region",
				"target_id": region_id,
				"target_region_id": region_id,
			},
			amount,
			batch.get("intents", []) as Array
		)
	if effect_kind == "single_monster_damage":
		var target := _public_monster_by_id(target_id)
		var target_generation := int(target_request.get(
			"target_source_generation",
			0
		))
		if (
			target.is_empty()
			or target_generation <= 0
			or int(target.get("source_generation", -1))
			!= target_generation
			or str(target.get("owner_player_id", ""))
			== str(source.get("owner_player_id", ""))
			or str(target.get("status", "")) != "active"
			or not _target_in_skill_range(
				source,
				str(target.get("region_id", "")),
				profile
			)
		):
			return _skill_fizzle("monster_target_invalid_at_boundary")
		var result := _skill_commit({
			"target_kind": "monster",
			"target_id": target_id,
			"target_region_id": str(target.get("region_id", "")),
			"source_generation": target_generation,
		}, amount, [])
		result["monster_damage_effects"] = [{
			"operation_id": "operation.skill.%s" % str(execution.get("execution_id", "")),
			"target_source_instance_id": target_id,
			"expected_source_generation": target_generation,
			"damage_amount": amount,
		}]
		return result
	if effect_kind in ["self_heal", "self_armor_gain"]:
		if (
			effect_kind == "self_heal"
			and int(source.get("hp", 0)) >= int(source.get("max_hp", 0))
		):
			return _skill_fizzle("self_heal_not_needed_at_boundary")
		var result := _skill_commit({
			"target_kind": "monster",
			"target_id": source_id,
			"target_region_id": str(source.get("region_id", "")),
			"source_generation": int(source.get("source_generation", 0)),
		}, amount, [])
		result["self_effects"] = [{
			"operation_id": "operation.skill.%s" % str(execution.get("execution_id", "")),
			"source_instance_id": source_id,
			"expected_source_generation": int(source.get("source_generation", 0)),
			"effect_kind": effect_kind,
			"amount": amount,
		}]
		return result
	return _skill_fizzle("skill_effect_kind_unsupported")


func _commit_evaluated_monster_effects(evaluation: Dictionary) -> Dictionary:
	for effect_variant in evaluation.get("monster_damage_effects", []) as Array:
		var effect := effect_variant as Dictionary
		var result := MonsterSourceCore.commit_combat_damage(
			_monster_state,
			str(effect.get("operation_id", "")),
			str(effect.get("target_source_instance_id", "")),
			int(effect.get("expected_source_generation", 0)),
			int(effect.get("damage_amount", 0))
		)
		if not bool(result.get("accepted", false)):
			return _failure("private_skill_monster_damage_failed", result)
		_monster_state = (result.get("state", {}) as Dictionary).duplicate(true)
		_monster_damage_commit_count += 1
	for effect_variant in evaluation.get("self_effects", []) as Array:
		var effect := effect_variant as Dictionary
		var result: Dictionary
		if str(effect.get("effect_kind", "")) == "self_heal":
			result = MonsterSourceCore.commit_private_skill_self_heal(
				_monster_state,
				str(effect.get("operation_id", "")),
				str(effect.get("source_instance_id", "")),
				int(effect.get("expected_source_generation", 0)),
				int(effect.get("amount", 0))
			)
		else:
			result = MonsterSourceCore.commit_private_skill_armor_gain(
				_monster_state,
				str(effect.get("operation_id", "")),
				str(effect.get("source_instance_id", "")),
				int(effect.get("expected_source_generation", 0)),
				int(effect.get("amount", 0))
			)
		if not bool(result.get("accepted", false)):
			return _failure("private_skill_self_effect_failed", result)
		_monster_state = (result.get("state", {}) as Dictionary).duplicate(true)
	var sync_result := _synchronize_skill_sources()
	if not bool(sync_result.get("accepted", false)):
		return sync_result
	return {"accepted": true, "reason_code": "private_skill_effects_committed"}


func _commit_detection_plan(
	plan: Dictionary,
	source: Dictionary
) -> Dictionary:
	var state_kind := str(plan.get("autonomy_state", ""))
	var transition_kind := MonsterSourceCore.DETECTION_PREFERRED_COLOR_HIT
	if state_kind == "search_expanding":
		transition_kind = MonsterSourceCore.DETECTION_NO_TARGET_GROWTH
	elif state_kind in ["hungry_tracking", "hungry_waiting"]:
		transition_kind = MonsterSourceCore.DETECTION_HUNGRY_PLAN
	var result := MonsterSourceCore.commit_detection_range_transition(
		_monster_state,
		"operation.detection.%s.%s" % [_batch_id, source.get("source_instance_id")],
		str(source.get("source_instance_id", "")),
		int(source.get("source_generation", 0)),
		transition_kind,
		maxi(
			int(plan.get("maximum_reachable_hops", 0)),
			int(source.get("base_detection_range_hops", 0))
		)
	)
	if not bool(result.get("accepted", false)):
		return _failure("monster_detection_commit_failed", result)
	_monster_state = (result.get("state", {}) as Dictionary).duplicate(true)
	return {"accepted": true, "reason_code": "monster_detection_committed"}


func _build_basic_attack(
	plan: Dictionary,
	public_facilities: Array
) -> Dictionary:
	var target_id := str(plan.get("target_facility_id", ""))
	var facility := _facility_by_id(public_facilities, target_id)
	if facility.is_empty():
		return {"accepted": false, "reason_code": "basic_attack_target_missing"}
	if (
		int(facility.get("facility_generation", -1))
		!= int(plan.get("target_facility_generation", -2))
		or str(facility.get("owner_player_id", facility.get("owner_id", "")))
		== str(plan.get("owner_player_id", ""))
	):
		return {"accepted": false, "reason_code": "basic_attack_target_changed"}
	var damage := CombatCatalog.monster_basic_attack_damage(
		str(_public_monster_by_id(
			str(plan.get("source_instance_id", ""))
		).get("monster_family_id", "")),
		int(plan.get("source_rank", 1))
	)
	var combat_receipt_id := "combat.basic.%s.%s" % [
		_batch_id,
		str(plan.get("source_instance_id", "")),
	]
	return CombatDamageCore.build_facility_damage_batch(
		"effect.monster.basic_attack",
		combat_receipt_id,
		"monster_basic_attack",
		[{
			"target_facility_id": target_id,
			"expected_generation": int(facility.get("facility_generation", 0)),
			"damage_amount": damage,
		}]
	)


func _synchronize_skill_sources() -> Dictionary:
	var known_sources := _skill_state.get("sources", {}) as Dictionary
	for source in _source_snapshots():
		var source_id := str(source.get("source_instance_id", ""))
		var result: Dictionary
		if known_sources.has(source_id):
			result = MonsterSkillCore.sync_source_snapshot(
				_skill_state,
				source
			)
		else:
			result = MonsterSkillCore.register_source_snapshot(
				_skill_state,
				source
			)
		if not bool(result.get("accepted", false)):
			return _failure("monster_skill_source_sync_failed", result)
		_skill_state = (result.get("state", {}) as Dictionary).duplicate(true)
		known_sources = _skill_state.get("sources", {}) as Dictionary
	return {"accepted": true, "reason_code": "monster_skill_sources_synchronized"}


func _source_snapshots() -> Array:
	var result: Array = []
	var sources := _monster_state.get("sources", {}) as Dictionary
	var ids: Array[String] = []
	for source_id_variant in sources.keys():
		ids.append(str(source_id_variant))
	ids.sort()
	for source_id in ids:
		result.append((sources.get(source_id, {}) as Dictionary).duplicate(true))
	return result


func _target_in_skill_range(
	source: Dictionary,
	target_region_id: String,
	profile: Dictionary
) -> bool:
	var path := MonsterAutonomyCore.shortest_path(
		_topology_snapshot,
		str(source.get("region_id", "")),
		target_region_id
	)
	return (
		not path.is_empty()
		and path.size() - 1 <= int(profile.get("maximum_range_hops", 0))
	)


func _facility_is_enemy_legal(
	source: Dictionary,
	facility: Dictionary
) -> bool:
	return (
		not facility.is_empty()
		and str(facility.get("owner_player_id", facility.get("owner_id", "")))
		!= str(source.get("owner_player_id", ""))
		and str(facility.get("status", "active")) != "destroyed"
		and str(facility.get("occupancy", "occupied")) != "empty"
	)


func _facility_by_id(facilities: Array, facility_id: String) -> Dictionary:
	for facility_variant in facilities:
		var facility := facility_variant as Dictionary
		if str(facility.get("facility_id", "")) == facility_id:
			return facility.duplicate(true)
	return {}


func _enemy_facilities_in_region(
	facilities: Array,
	owner_player_id: String,
	region_id: String
) -> Array:
	var result: Array = []
	for facility_variant in facilities:
		var facility := facility_variant as Dictionary
		if (
			str(facility.get("region_id", "")) == region_id
			and str(facility.get("owner_player_id", facility.get("owner_id", "")))
			!= owner_player_id
			and str(facility.get("status", "active")) != "destroyed"
			and str(facility.get("occupancy", "occupied")) != "empty"
		):
			result.append(facility.duplicate(true))
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("facility_id", "")) < str(right.get("facility_id", ""))
	)
	return result


func _round_robin_allocations(
	facilities: Array,
	total_budget: int
) -> Array:
	var damage_by_id := {}
	for facility_variant in facilities:
		damage_by_id[str((facility_variant as Dictionary).get("facility_id", ""))] = 0
	var remaining := total_budget
	while remaining > 0:
		for facility_variant in facilities:
			if remaining <= 0:
				break
			var facility_id := str(
				(facility_variant as Dictionary).get("facility_id", "")
			)
			damage_by_id[facility_id] = int(damage_by_id.get(facility_id, 0)) + 1
			remaining -= 1
	var result: Array = []
	for facility_variant in facilities:
		var facility := facility_variant as Dictionary
		var facility_id := str(facility.get("facility_id", ""))
		var amount := int(damage_by_id.get(facility_id, 0))
		if amount <= 0:
			continue
		result.append({
			"target_facility_id": facility_id,
			"expected_generation": int(facility.get("facility_generation", 0)),
			"damage_amount": amount,
		})
	return result


func _skill_commit(
	public_target: Dictionary,
	damage_amount: int,
	facility_damage_intents: Array
) -> Dictionary:
	return {
		"committed": true,
		"reason_code": "resolved",
		"public_target": public_target.duplicate(true),
		"public_result": {
			"effect_summary_key": "combat.monster.skill.resolved",
			"damage_amount": damage_amount,
			"armor_absorbed": 0,
			"status_changes": [],
			"facility_damage_receipt_ids": [],
			"combat_receipt_id": "combat.skill.resolved",
		},
		"facility_damage_intents": facility_damage_intents.duplicate(true),
		"monster_damage_effects": [],
		"self_effects": [],
	}


func _skill_fizzle(reason_code: String) -> Dictionary:
	_private_skill_last_fizzle_reason = reason_code
	return {
		"committed": false,
		"reason_code": reason_code,
		"public_target": {"target_kind": "none"},
		"public_result": {
			"effect_summary_key": "combat.monster.skill.fizzled",
			"damage_amount": 0,
			"armor_absorbed": 0,
			"status_changes": [],
			"facility_damage_receipt_ids": [],
			"combat_receipt_id": "combat.skill.fizzled",
		},
		"facility_damage_intents": [],
		"monster_damage_effects": [],
		"self_effects": [],
	}


func _public_monster_by_id(source_id: String) -> Dictionary:
	for source_variant in public_monsters():
		var source := source_variant as Dictionary
		if str(source.get("source_instance_id", "")) == source_id:
			return source.duplicate(true)
	return {}


func _count_trample_facility_type(
	intent: Dictionary,
	public_facilities: Array
) -> void:
	var facility := _facility_by_id(
		public_facilities,
		str(intent.get("target_facility_id", ""))
	)
	match str(facility.get("facility_type", "")):
		"factory":
			_factory_trample_damage_count += 1
		"market":
			_market_trample_damage_count += 1
		"warehouse":
			_warehouse_trample_damage_count += 1


func _record_receipt(
	event_kind: String,
	payload: Dictionary,
	identity_hint: String
) -> Dictionary:
	var key := "%s|%s|%s" % [event_kind, identity_hint, _fingerprint(payload)]
	if _processed_receipt_keys.has(key):
		return (
			_processed_receipt_keys.get(key, {}) as Dictionary
		).duplicate(true)
	var envelope := {
		"receipt_id": "receipt.combat.%s" % key.sha256_text().substr(0, 24),
		"event_kind": event_kind,
		"batch_id": _batch_id,
		"payload": payload.duplicate(true),
		"receipt_fingerprint": "",
	}
	envelope["receipt_fingerprint"] = _fingerprint({
		"receipt_id": envelope.get("receipt_id"),
		"event_kind": event_kind,
		"batch_id": _batch_id,
		"payload": payload,
	})
	_processed_receipt_keys[key] = envelope.duplicate(true)
	_combat_receipt_journal.append(envelope.duplicate(true))
	combat_receipt_committed.emit(envelope.duplicate(true))
	public_combat_result_ready.emit(envelope.duplicate(true))
	return envelope


func _checkpoint_state() -> Dictionary:
	return {
		"lineage_id": _lineage_id,
		"revision": _revision,
		"receipt_journal": _combat_receipt_journal.duplicate(true),
		"initialized": _initialized,
		"player_ids": _player_ids.duplicate(),
		"phase": _phase,
		"batch_id": _batch_id,
		"batch_index": _batch_index,
		"topology_snapshot": _topology_snapshot.duplicate(true),
		"monster_state": _monster_state.duplicate(true),
		"skill_state": _skill_state.duplicate(true),
		"military_locks": _military_locks.duplicate(true),
		"processed_missions": _processed_missions.duplicate(true),
		"processed_receipt_keys": _processed_receipt_keys.duplicate(true),
		"processed_movement_ids": _processed_movement_ids.duplicate(true),
		"processed_autonomy_plans": _processed_autonomy_plans.duplicate(true),
		"last_autonomy_plan": _last_autonomy_plan.duplicate(true),
		"tracked_targets_by_source": _tracked_targets_by_source.duplicate(true),
		"public_results": _public_results.duplicate(true),
		"monster_card_mode_counts": _monster_card_mode_counts.duplicate(true),
		"autonomy_target_count": _autonomy_target_count,
		"hungry_fallback_count": _hungry_fallback_count,
		"movement_count": _movement_count,
		"trample_region_receipt_count": _trample_region_receipt_count,
		"factory_trample_damage_count": _factory_trample_damage_count,
		"market_trample_damage_count": _market_trample_damage_count,
		"warehouse_trample_damage_count": _warehouse_trample_damage_count,
		"private_skill_request_count": _private_skill_request_count,
		"private_skill_commit_count": _private_skill_commit_count,
		"private_skill_fizzle_count": _private_skill_fizzle_count,
		"private_skill_last_fizzle_reason": _private_skill_last_fizzle_reason,
		"skill_cooldown_recovery_count": _skill_cooldown_recovery_count,
		"military_region_assault_count": _military_region_assault_count,
		"military_monster_assault_count": _military_monster_assault_count,
		"military_withdraw_count": _military_withdraw_count,
		"facility_damage_intent_count": _facility_damage_intent_count,
		"monster_damage_commit_count": _monster_damage_commit_count,
		"runtime_error_count": _runtime_error_count,
	}


func _restore_checkpoint_state(state: Dictionary) -> void:
	_lineage_id = str(state.get("lineage_id", ""))
	_revision = int(state.get("revision", 0))
	_combat_receipt_journal = (state.get("receipt_journal", []) as Array).duplicate(true)
	_initialized = bool(state.get("initialized", false))
	_player_ids.assign(state.get("player_ids", []) as Array)
	_phase = str(state.get("phase", "idle"))
	_batch_id = str(state.get("batch_id", ""))
	_batch_index = int(state.get("batch_index", -1))
	_topology_snapshot = (state.get("topology_snapshot", {}) as Dictionary).duplicate(true)
	_monster_state = (state.get("monster_state", {}) as Dictionary).duplicate(true)
	_skill_state = (state.get("skill_state", {}) as Dictionary).duplicate(true)
	_military_locks = (state.get("military_locks", {}) as Dictionary).duplicate(true)
	_processed_missions = (state.get("processed_missions", {}) as Dictionary).duplicate(true)
	_processed_receipt_keys = (state.get("processed_receipt_keys", {}) as Dictionary).duplicate(true)
	_processed_movement_ids = (state.get("processed_movement_ids", {}) as Dictionary).duplicate(true)
	_processed_autonomy_plans = (state.get("processed_autonomy_plans", {}) as Dictionary).duplicate(true)
	_last_autonomy_plan = (state.get("last_autonomy_plan", {}) as Dictionary).duplicate(true)
	_tracked_targets_by_source = (state.get("tracked_targets_by_source", {}) as Dictionary).duplicate(true)
	_public_results = (state.get("public_results", []) as Array).duplicate(true)
	_monster_card_mode_counts = (
		state.get("monster_card_mode_counts", {}) as Dictionary
	).duplicate(true)
	_autonomy_target_count = int(state.get("autonomy_target_count", 0))
	_hungry_fallback_count = int(state.get("hungry_fallback_count", 0))
	_movement_count = int(state.get("movement_count", 0))
	_trample_region_receipt_count = int(
		state.get("trample_region_receipt_count", 0)
	)
	_factory_trample_damage_count = int(
		state.get("factory_trample_damage_count", 0)
	)
	_market_trample_damage_count = int(
		state.get("market_trample_damage_count", 0)
	)
	_warehouse_trample_damage_count = int(
		state.get("warehouse_trample_damage_count", 0)
	)
	_private_skill_request_count = int(
		state.get("private_skill_request_count", 0)
	)
	_private_skill_commit_count = int(
		state.get("private_skill_commit_count", 0)
	)
	_private_skill_fizzle_count = int(
		state.get("private_skill_fizzle_count", 0)
	)
	_private_skill_last_fizzle_reason = str(
		state.get("private_skill_last_fizzle_reason", "")
	)
	_skill_cooldown_recovery_count = int(
		state.get("skill_cooldown_recovery_count", 0)
	)
	_military_region_assault_count = int(
		state.get("military_region_assault_count", 0)
	)
	_military_monster_assault_count = int(
		state.get("military_monster_assault_count", 0)
	)
	_military_withdraw_count = int(state.get("military_withdraw_count", 0))
	_facility_damage_intent_count = int(
		state.get("facility_damage_intent_count", 0)
	)
	_monster_damage_commit_count = int(
		state.get("monster_damage_commit_count", 0)
	)
	_runtime_error_count = int(state.get("runtime_error_count", 0))


func _rollback_private_skill_boundary_failure(
	checkpoint_state: Dictionary,
	reason_code: String,
	detail: Dictionary
) -> Dictionary:
	_restore_checkpoint_state(checkpoint_state)
	return _failure(reason_code, detail)


func _reset_runtime_state() -> void:
	_initialized = false
	_player_ids = []
	_phase = "idle"
	_batch_id = ""
	_batch_index = -1
	_topology_snapshot = {}
	_monster_state = {}
	_skill_state = {}
	_military_locks = {}
	_processed_missions = {}
	_processed_receipt_keys = {}
	_processed_movement_ids = {}
	_processed_autonomy_plans = {}
	_combat_receipt_journal = []
	_last_autonomy_plan = {}
	_tracked_targets_by_source = {}
	_public_results = []
	_lineage_id = ""
	_revision = 0
	_monster_card_mode_counts = {
		"DEPLOY_NEW": 0,
		"REFRESH_EXISTING": 0,
		"UPGRADE_EXISTING": 0,
		"REPLACE_EXISTING": 0,
	}
	_autonomy_target_count = 0
	_hungry_fallback_count = 0
	_movement_count = 0
	_trample_region_receipt_count = 0
	_factory_trample_damage_count = 0
	_market_trample_damage_count = 0
	_warehouse_trample_damage_count = 0
	_private_skill_request_count = 0
	_private_skill_commit_count = 0
	_private_skill_fizzle_count = 0
	_private_skill_last_fizzle_reason = ""
	_skill_cooldown_recovery_count = 0
	_military_region_assault_count = 0
	_military_monster_assault_count = 0
	_military_withdraw_count = 0
	_facility_damage_intent_count = 0
	_monster_damage_commit_count = 0
	_runtime_error_count = 0


func _failure(
	reason_code: String,
	detail: Dictionary = {}
) -> Dictionary:
	_runtime_error_count += 1
	return {
		"accepted": false,
		"reason_code": reason_code,
		"detail": detail.duplicate(true),
	}


func _fingerprint(value: Variant) -> String:
	return JSON.stringify(_canonical(value)).sha256_text().to_lower()


func _canonical(value: Variant) -> Variant:
	if value is Array:
		var rows: Array = []
		for item_variant in value as Array:
			rows.append(_canonical(item_variant))
		return rows
	if value is Dictionary:
		var keys: Array[String] = []
		for key_variant in (value as Dictionary).keys():
			keys.append(str(key_variant))
		keys.sort()
		var result := {}
		for key in keys:
			result[key] = _canonical((value as Dictionary).get(key))
		return result
	return value
