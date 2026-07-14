@tool
extends Node
class_name PlayerOrganizationRuntimeController

const RULESET_ID := "v0.6"
const STATE_VERSION := 1
const EFFECT_KIND := "install_organization_upgrade"
const TARGET_KIND := "self_organization_slot"
const SLOT_LIMIT := 3
const BASE_HAND_LIMIT := 5
const ABSOLUTE_HAND_LIMIT_CAP := 9
const BASE_SUBMISSION_LIMIT := 1
const ABSOLUTE_SUBMISSION_LIMIT_CAP := 3
const BASE_MONSTER_COUNT_LIMIT := 1
const BASE_MONSTER_PRIMARY_RANK_LIMIT := 2
const BASE_MILITARY_COUNT_LIMIT := 1
const BASE_MILITARY_PRIMARY_RANK_LIMIT := 2

const AXIS_ASSET_CONVERSION := "asset_conversion"
const AXIS_ACTION_BANDWIDTH := "action_bandwidth"
const AXIS_HAND_CAPACITY := "hand_capacity"
const AXIS_MONSTER_BINDING := "monster_binding"
const AXIS_MILITARY_COMMAND := "military_command"

const FAMILY_BY_AXIS := {
	AXIS_ASSET_CONVERSION: "organization.starport_clearinghouse",
	AXIS_ACTION_BANDWIDTH: "organization.quantum_agenda_network",
	AXIS_HAND_CAPACITY: "organization.deep_space_archive",
	AXIS_MONSTER_BINDING: "organization.monster_liaison_charter",
	AXIS_MILITARY_COMMAND: "organization.stellar_command_directorate",
}

const ASSET_BONUS_BP := [0, 500, 1000, 1500, 2000]
const ASSET_CAP_MILLI_PER_SECOND := [0, 50, 100, 150, 200]
const ACTION_SURCHARGE := [0, 4, 3, 2, 1]
const HAND_LIMIT_BY_RANK := [0, 6, 7, 8, 9]
const UNIT_COUNT_LIMIT_BY_RANK := [0, 1, 1, 2, 2]
const PRIMARY_UNIT_RANK_LIMIT_BY_RANK := [0, 3, 4, 4, 4]
const SECONDARY_UNIT_RANK_LIMIT_BY_RANK := [0, 0, 0, 2, 4]

const PUBLIC_FORBIDDEN_KEYS := [
	"actor_id",
	"owner_id",
	"owner",
	"true_owner",
	"hidden_owner",
	"owner_truth",
	"hand_limit",
	"ordinary_hand_limit",
	"asset_conversion_bonus_bp",
	"asset_conversion_bonus_cap_milli_per_second",
	"controlled_monster_count_limit",
	"primary_monster_rank_limit",
	"secondary_monster_rank_limit",
	"controlled_military_count_limit",
	"primary_military_rank_limit",
	"secondary_military_rank_limit",
	"ai_reason",
	"ai_utility_score",
	"route_plan_score",
	"decision_samples",
	"learning_bonus",
]

var _configured := false
var _actor_ids: Array[String] = []
var _players: Dictionary = {}
var _transaction_journal: Dictionary = {}
var _revision := 0
var _capability_secret := ""


func configure(actor_ids: Array) -> Dictionary:
	var normalized := _normalized_actor_ids(actor_ids)
	_configured = not normalized.is_empty()
	_actor_ids = normalized
	_players.clear()
	_transaction_journal.clear()
	_revision = 0
	_capability_secret = _new_capability_secret()
	for actor_id in _actor_ids:
		_players[actor_id] = _empty_player_state(actor_id)
	return {
		"configured": _configured,
		"ruleset_id": RULESET_ID,
		"actor_count": _actor_ids.size(),
		"organization_slot_limit": SLOT_LIMIT,
		"effect_kind": EFFECT_KIND,
		"target_kind": TARGET_KIND,
	}


func reset_state(actor_ids: Array = []) -> void:
	var next_actor_ids: Array = actor_ids if not actor_ids.is_empty() else _actor_ids
	configure(next_actor_ids)


func prepare_organization_upgrade(intent: Dictionary) -> Dictionary:
	var binding_error := _binding_error(intent)
	if not binding_error.is_empty():
		return _failure(intent, binding_error, "prepare")
	var transaction_id := str(intent.get("transaction_id", ""))
	if _transaction_journal.has(transaction_id):
		return _journal_replay_or_collision(intent, _transaction_journal[transaction_id] as Dictionary)
	var actor_id := str(intent.get("actor_id", ""))
	if not _players.has(actor_id):
		return _failure(intent, "organization_actor_unavailable", "prepare")
	var target: Dictionary = _dictionary(intent.get("target_context", {}))
	var target_actor_id := str(target.get("target_actor_id", target.get("actor_id", actor_id))).strip_edges()
	if target_actor_id != actor_id:
		return _failure(intent, "organization_target_must_be_self", "prepare")
	var target_kind := str(target.get("target_kind", TARGET_KIND))
	if target_kind != TARGET_KIND:
		return _failure(intent, "organization_target_kind_invalid", "prepare")
	var window_sequence := int(target.get("window_sequence", -1))
	if window_sequence < 0:
		return _failure(intent, "organization_window_sequence_required", "prepare")
	var player: Dictionary = _dictionary(_players.get(actor_id, {}))
	var expected_revision := int(target.get("expected_owner_revision", -1))
	if expected_revision >= 0 and expected_revision != int(player.get("revision", -1)):
		return _failure(intent, "organization_owner_revision_stale", "prepare")
	var payload_result := _normalize_and_validate_payload(_dictionary(intent.get("effect_payload", {})))
	if not bool(payload_result.get("valid", false)):
		return _failure(intent, str(payload_result.get("reason_code", "organization_payload_invalid")), "prepare")
	var payload: Dictionary = _dictionary(payload_result.get("payload", {}))
	var family_id := str(payload.get("organization_family_id", ""))
	var rank := int(payload.get("organization_rank", 0))
	var slots: Array = _array(player.get("slots", []))
	var existing_slot := _family_slot(slots, family_id)
	if existing_slot >= 0:
		var existing: Dictionary = _dictionary(slots[existing_slot])
		if rank <= int(existing.get("rank", 0)):
			return _failure(intent, "organization_upgrade_must_be_higher_rank", "prepare")
	var slot_index := existing_slot if existing_slot >= 0 else _first_empty_slot(slots)
	if slot_index < 0:
		return _failure(intent, "organization_slots_full", "prepare")
	var requested_slot := int(target.get("organization_slot_index", target.get("slot_index", -1)))
	if requested_slot >= 0 and requested_slot != slot_index:
		return _failure(intent, "organization_slot_binding_mismatch", "prepare")
	var activation_offset := int(payload.get("activation_window_offset", 1))
	var preimage := player.duplicate(true)
	var postimage := player.duplicate(true)
	var post_slots: Array = _array(postimage.get("slots", []))
	post_slots[slot_index] = {
		"family_id": family_id,
		"axis": str(payload.get("organization_axis", "")),
		"rank": rank,
		"slot_index": slot_index,
		"activation_window_sequence": window_sequence + activation_offset,
		"expiry_window_sequence": -1,
		"installed_by_transaction": transaction_id,
		"payload": payload.duplicate(true),
	}
	postimage["slots"] = post_slots
	postimage["revision"] = int(player.get("revision", 0)) + 1
	var prepared_token := _fingerprint({
		"binding": _binding_from(intent),
		"preimage": preimage,
		"postimage": postimage,
	})
	var prepared := _binding_from(intent)
	prepared.merge({
		"prepared": true,
		"committed": false,
		"finalized": false,
		"rolled_back": false,
		"reason_code": "organization_upgrade_prepared",
		"prepared_token": prepared_token,
		"organization_family_id": family_id,
		"organization_axis": str(payload.get("organization_axis", "")),
		"organization_rank": rank,
		"organization_slot_index": slot_index,
		"activation_window_sequence": window_sequence + activation_offset,
		"owner_revision_before": int(preimage.get("revision", 0)),
		"owner_revision_after": int(postimage.get("revision", 0)),
	}, true)
	_transaction_journal[transaction_id] = {
		"stage": "prepared",
		"binding": _binding_from(intent),
		"prepared_token": prepared_token,
		"actor_id": actor_id,
		"preimage": preimage,
		"postimage": postimage,
		"prepared_receipt": prepared.duplicate(true),
		"terminal_receipt": {},
	}
	return prepared


func commit_organization_upgrade(prepared: Dictionary) -> Dictionary:
	var transaction_id := str(prepared.get("transaction_id", ""))
	if not _transaction_journal.has(transaction_id):
		return _failure(prepared, "organization_prepared_record_missing", "commit")
	var lifecycle: Dictionary = _dictionary(_transaction_journal[transaction_id])
	if not _binding_matches(_dictionary(lifecycle.get("binding", {})), prepared) \
		or str(lifecycle.get("prepared_token", "")) != str(prepared.get("prepared_token", "")):
		return _failure(prepared, "organization_prepared_record_mismatch", "commit")
	var stage := str(lifecycle.get("stage", ""))
	if ["committed", "finalized", "rolled_back", "aborted"].has(stage):
		return _dictionary(lifecycle.get("terminal_receipt", lifecycle.get("prepared_receipt", {}))).duplicate(true)
	if stage != "prepared":
		return _failure(prepared, "organization_lifecycle_stage_invalid", "commit")
	var actor_id := str(lifecycle.get("actor_id", ""))
	var current := _dictionary(_players.get(actor_id, {}))
	var preimage := _dictionary(lifecycle.get("preimage", {}))
	if _fingerprint(current) != _fingerprint(preimage):
		return _failure(prepared, "organization_owner_state_changed", "commit")
	var postimage := _dictionary(lifecycle.get("postimage", {})).duplicate(true)
	_players[actor_id] = postimage
	_revision += 1
	var receipt := _binding_from(prepared)
	receipt.merge({
		"prepared": true,
		"committed": true,
		"finalized": false,
		"rolled_back": false,
		"rollback_open": true,
		"reason_code": "organization_upgrade_committed",
		"organization_family_id": str(prepared.get("organization_family_id", "")),
		"organization_axis": str(prepared.get("organization_axis", "")),
		"organization_rank": int(prepared.get("organization_rank", 0)),
		"organization_slot_index": int(prepared.get("organization_slot_index", -1)),
		"activation_window_sequence": int(prepared.get("activation_window_sequence", -1)),
		"owner_revision": int(postimage.get("revision", 0)),
	}, true)
	lifecycle["stage"] = "committed"
	lifecycle["terminal_receipt"] = receipt.duplicate(true)
	_transaction_journal[transaction_id] = lifecycle
	return receipt


func rollback_organization_upgrade(receipt_or_transaction: Variant) -> Dictionary:
	var transaction_id := _transaction_id_from(receipt_or_transaction)
	if not _transaction_journal.has(transaction_id):
		return {"rolled_back": false, "committed": false, "reason_code": "organization_transaction_missing", "transaction_id": transaction_id}
	var lifecycle: Dictionary = _dictionary(_transaction_journal[transaction_id])
	var stage := str(lifecycle.get("stage", ""))
	if stage in ["rolled_back", "aborted"]:
		return _dictionary(lifecycle.get("terminal_receipt", {})).duplicate(true)
	if stage == "finalized":
		return {"rolled_back": false, "committed": true, "finalized": true, "reason_code": "organization_rollback_closed", "transaction_id": transaction_id}
	if stage == "prepared":
		return abort_prepared_organization_upgrade(_dictionary(lifecycle.get("prepared_receipt", {})))
	if stage != "committed":
		return {"rolled_back": false, "committed": false, "reason_code": "organization_lifecycle_stage_invalid", "transaction_id": transaction_id}
	var actor_id := str(lifecycle.get("actor_id", ""))
	var current := _dictionary(_players.get(actor_id, {}))
	var postimage := _dictionary(lifecycle.get("postimage", {}))
	if _fingerprint(current) != _fingerprint(postimage):
		return {"rolled_back": false, "committed": true, "reason_code": "organization_rollback_state_changed", "transaction_id": transaction_id}
	var restored := _dictionary(lifecycle.get("preimage", {})).duplicate(true)
	# Content returns to the exact preimage while the monotonic revision prevents
	# a pre-commit private capability from becoming valid again.
	restored["revision"] = maxi(int(current.get("revision", 0)), int(restored.get("revision", 0))) + 1
	_players[actor_id] = restored
	_revision += 1
	var result := {
		"transaction_id": transaction_id,
		"rolled_back": true,
		"committed": false,
		"finalized": false,
		"rollback_open": false,
		"reason_code": "organization_upgrade_rolled_back",
		"owner_revision": int(restored.get("revision", 0)),
	}
	lifecycle["stage"] = "rolled_back"
	lifecycle["rollback_postimage"] = restored.duplicate(true)
	lifecycle["terminal_receipt"] = result.duplicate(true)
	_transaction_journal[transaction_id] = lifecycle
	return result


func finalize_organization_upgrade(receipt_or_transaction: Variant) -> Dictionary:
	var transaction_id := _transaction_id_from(receipt_or_transaction)
	if not _transaction_journal.has(transaction_id):
		return {"finalized": false, "reason_code": "organization_transaction_missing", "transaction_id": transaction_id}
	var lifecycle: Dictionary = _dictionary(_transaction_journal[transaction_id])
	var stage := str(lifecycle.get("stage", ""))
	if stage == "finalized":
		return _dictionary(lifecycle.get("terminal_receipt", {})).duplicate(true)
	if stage != "committed":
		return {"finalized": false, "reason_code": "organization_commit_required", "transaction_id": transaction_id}
	var committed_receipt := _dictionary(lifecycle.get("terminal_receipt", {}))
	var result := committed_receipt.duplicate(true)
	result["finalized"] = true
	result["rollback_open"] = false
	result["reason_code"] = "organization_upgrade_finalized"
	lifecycle["stage"] = "finalized"
	lifecycle["terminal_receipt"] = result.duplicate(true)
	_transaction_journal[transaction_id] = lifecycle
	return result


func abort_prepared_organization_upgrade(prepared: Dictionary) -> Dictionary:
	var transaction_id := str(prepared.get("transaction_id", ""))
	if not _transaction_journal.has(transaction_id):
		return {"rolled_back": false, "committed": false, "reason_code": "organization_transaction_missing", "transaction_id": transaction_id}
	var lifecycle: Dictionary = _dictionary(_transaction_journal[transaction_id])
	if str(lifecycle.get("stage", "")) in ["aborted", "rolled_back"]:
		return _dictionary(lifecycle.get("terminal_receipt", {})).duplicate(true)
	if str(lifecycle.get("stage", "")) != "prepared" \
		or not _binding_matches(_dictionary(lifecycle.get("binding", {})), prepared):
		return {"rolled_back": false, "committed": false, "reason_code": "organization_abort_not_allowed", "transaction_id": transaction_id}
	var result := {
		"transaction_id": transaction_id,
		"rolled_back": true,
		"committed": false,
		"finalized": false,
		"rollback_open": false,
		"reason_code": "organization_prepare_aborted",
	}
	lifecycle["stage"] = "aborted"
	lifecycle["terminal_receipt"] = result.duplicate(true)
	_transaction_journal[transaction_id] = lifecycle
	return result


func checkpoint_status() -> Dictionary:
	var inflight: Array[String] = []
	for transaction_id_variant in _transaction_journal.keys():
		var lifecycle := _dictionary(_transaction_journal[transaction_id_variant])
		if str(lifecycle.get("stage", "")) in ["prepared", "committed"]:
			inflight.append(str(transaction_id_variant))
	inflight.sort()
	return {
		"can_checkpoint": inflight.is_empty(),
		"reason_code": "organization_checkpoint_ready" if inflight.is_empty() else "organization_transactions_inflight",
		"inflight_transaction_ids": inflight,
		"inflight_count": inflight.size(),
	}


func asset_recovery_terms(actor_id: String, window_sequence: int) -> Dictionary:
	var base := _private_capability_base(actor_id, window_sequence, "asset_recovery")
	if not bool(base.get("available", false)):
		return base
	var record := _active_record(actor_id, AXIS_ASSET_CONVERSION, window_sequence)
	var payload := _record_payload(record)
	base.merge({
		"asset_conversion_bonus_bp": int(payload.get("asset_conversion_bonus_bp", 0)),
		"asset_conversion_bonus_cap_milli_per_second": int(payload.get("asset_conversion_bonus_cap_milli_per_second", 0)),
		"asset_conversion_scope": str(payload.get("scope", "same_color_gdp_only")),
		"activation_window_sequence": int(record.get("activation_window_sequence", -1)),
		"expiry_window_sequence": int(record.get("expiry_window_sequence", -1)),
	}, true)
	return base


func hand_limit_terms(actor_id: String, window_sequence: int) -> Dictionary:
	var base := _private_capability_base(actor_id, window_sequence, "hand_limit")
	if not bool(base.get("available", false)):
		return base
	var record := _active_record(actor_id, AXIS_HAND_CAPACITY, window_sequence)
	var payload := _record_payload(record)
	var effective_limit := clampi(int(payload.get("ordinary_hand_limit", BASE_HAND_LIMIT)), BASE_HAND_LIMIT, ABSOLUTE_HAND_LIMIT_CAP)
	base.merge({
		"base_ordinary_hand_limit": BASE_HAND_LIMIT,
		"ordinary_hand_limit": effective_limit,
		"ordinary_hand_limit_bonus": effective_limit - BASE_HAND_LIMIT,
		"absolute_hand_limit_cap": ABSOLUTE_HAND_LIMIT_CAP,
		"activation_window_sequence": int(record.get("activation_window_sequence", -1)),
		"expiry_window_sequence": int(record.get("expiry_window_sequence", -1)),
	}, true)
	return base


func card_window_submission_capability(actor_id: String, window_sequence: int) -> Dictionary:
	var base := _private_capability_base(actor_id, window_sequence, "card_window_submission")
	if not bool(base.get("available", false)):
		return base
	var record := _active_record(actor_id, AXIS_ACTION_BANDWIDTH, window_sequence)
	var payload := _record_payload(record)
	var ordinary_bonus := clampi(int(payload.get("ordinary_submission_bonus", 0)), 0, 1)
	var burst_period := maxi(0, int(payload.get("burst_window_period", 0)))
	var burst_bonus := maxi(0, int(payload.get("burst_submission_bonus", 0)))
	var activation := int(record.get("activation_window_sequence", -1))
	var burst_eligible := not record.is_empty() and burst_period > 0 and window_sequence >= activation \
		and ((window_sequence - activation + 1) % burst_period == 0)
	var effective_limit := clampi(BASE_SUBMISSION_LIMIT + ordinary_bonus + (burst_bonus if burst_eligible else 0), BASE_SUBMISSION_LIMIT, ABSOLUTE_SUBMISSION_LIMIT_CAP)
	base.merge({
		"base_submission_limit": BASE_SUBMISSION_LIMIT,
		"bonus_submission_limit": effective_limit - BASE_SUBMISSION_LIMIT,
		"effective_submission_limit": effective_limit,
		"maximum_effective_submissions": ABSOLUTE_SUBMISSION_LIMIT_CAP,
		"extra_submission_asset_surcharge": maxi(0, int(payload.get("extra_submission_asset_surcharge", 0))),
		"burst_submission_surcharge": maxi(0, int(payload.get("burst_submission_surcharge", 0))) if burst_eligible else 0,
		"burst_eligible": burst_eligible,
		"response_cards_ignore_ordinary_submission_limit": true,
		"activation_window_sequence": activation,
		"expiry_window_sequence": int(record.get("expiry_window_sequence", -1)),
	}, true)
	base["capability_id"] = _signed_capability_id(base)
	return base


func validate_card_window_submission_capability(capability: Dictionary) -> Dictionary:
	var actor_id := str(capability.get("actor_id", ""))
	var window_sequence := int(capability.get("window_sequence", -1))
	var expected := card_window_submission_capability(actor_id, window_sequence)
	if not bool(expected.get("available", false)):
		return {"valid": false, "reason_code": "organization_submission_capability_unavailable"}
	if int(capability.get("owner_revision", -1)) != int(expected.get("owner_revision", -2)) \
		or str(capability.get("capability_id", "")) != str(expected.get("capability_id", "")) \
		or int(capability.get("effective_submission_limit", -1)) != int(expected.get("effective_submission_limit", -2)):
		return {"valid": false, "reason_code": "organization_submission_capability_invalid"}
	return {"valid": true, "reason_code": "organization_submission_capability_valid", "capability": expected}


func monster_binding_caps(actor_id: String, window_sequence: int) -> Dictionary:
	return _unit_caps(actor_id, window_sequence, AXIS_MONSTER_BINDING, "monster")


func monster_binding_caps_for_target_owner(actor_id: String, window_sequence: int) -> Dictionary:
	# Foreign same-name upgrades query this target-owner snapshot; the monster
	# owner still decides legality and never transfers ownership here.
	return monster_binding_caps(actor_id, window_sequence)


func military_command_caps(actor_id: String, window_sequence: int) -> Dictionary:
	return _unit_caps(actor_id, window_sequence, AXIS_MILITARY_COMMAND, "military")


func private_snapshot(actor_id: String, window_sequence: int = 0) -> Dictionary:
	if not _configured or not _players.has(actor_id):
		return {"available": false, "reason_code": "organization_actor_unavailable"}
	var player := _dictionary(_players[actor_id])
	return {
		"available": true,
		"authoritative": true,
		"actor_id": actor_id,
		"owner_revision": int(player.get("revision", 0)),
		"window_sequence": window_sequence,
		"slot_limit": SLOT_LIMIT,
		"slots": _array(player.get("slots", [])).duplicate(true),
		"asset_recovery_terms": asset_recovery_terms(actor_id, window_sequence),
		"hand_limit_terms": hand_limit_terms(actor_id, window_sequence),
		"card_window_submission_capability": card_window_submission_capability(actor_id, window_sequence),
		"monster_binding_caps": monster_binding_caps(actor_id, window_sequence),
		"military_command_caps": military_command_caps(actor_id, window_sequence),
	}


func public_snapshot() -> Dictionary:
	return {
		"available": _configured,
		"ruleset_id": RULESET_ID,
		"organization_system_enabled": _configured,
		"organization_slot_count": SLOT_LIMIT,
		"activation_policy": "next_shared_window",
		"persistence": "run",
		"stack_policy": "highest_rank_nonstacking",
		"public_clue_kind": "installed_organization_axis_aura",
	}


func debug_snapshot() -> Dictionary:
	return {
		"configured": _configured,
		"ruleset_id": RULESET_ID,
		"state_version": STATE_VERSION,
		"controller_authoritative": true,
		"parallel_business_owner": false,
		"actor_count": _actor_ids.size(),
		"revision": _revision,
		"players": _players.duplicate(true),
		"transaction_journal": _transaction_journal.duplicate(true),
		"checkpoint": checkpoint_status(),
	}


func to_save_data() -> Dictionary:
	return {
		"state_version": STATE_VERSION,
		"ruleset_id": RULESET_ID,
		"configured": _configured,
		"actor_ids": _actor_ids.duplicate(),
		"players": _players.duplicate(true),
		"transaction_journal": _transaction_journal.duplicate(true),
		"revision": _revision,
		"capability_secret": _capability_secret,
	}


func apply_save_data(data: Dictionary) -> Dictionary:
	var prepared := _prepare_save_data(data)
	if not bool(prepared.get("valid", false)):
		return {"applied": false, "reason_code": str(prepared.get("reason_code", "organization_save_invalid"))}
	_configured = bool(prepared.get("configured", false))
	_actor_ids = prepared.get("actor_ids", []) as Array[String]
	_players = _dictionary(prepared.get("players", {})).duplicate(true)
	_transaction_journal = _dictionary(prepared.get("transaction_journal", {})).duplicate(true)
	_revision = int(prepared.get("revision", 0))
	_capability_secret = str(prepared.get("capability_secret", ""))
	return {"applied": true, "reason_code": "organization_save_applied", "checkpoint": checkpoint_status()}


func _unit_caps(actor_id: String, window_sequence: int, axis: String, prefix: String) -> Dictionary:
	var base := _private_capability_base(actor_id, window_sequence, "%s_caps" % prefix)
	if not bool(base.get("available", false)):
		return base
	var record := _active_record(actor_id, axis, window_sequence)
	var payload := _record_payload(record)
	var base_count := BASE_MONSTER_COUNT_LIMIT if prefix == "monster" else BASE_MILITARY_COUNT_LIMIT
	var base_primary := BASE_MONSTER_PRIMARY_RANK_LIMIT if prefix == "monster" else BASE_MILITARY_PRIMARY_RANK_LIMIT
	base["controlled_%s_count_limit" % prefix] = maxi(base_count, int(payload.get("controlled_%s_count_limit" % prefix, base_count)))
	base["primary_%s_rank_limit" % prefix] = clampi(int(payload.get("primary_%s_rank_limit" % prefix, base_primary)), base_primary, 4)
	base["secondary_%s_rank_limit" % prefix] = clampi(int(payload.get("secondary_%s_rank_limit" % prefix, 0)), 0, 4)
	base["activation_window_sequence"] = int(record.get("activation_window_sequence", -1))
	base["expiry_window_sequence"] = int(record.get("expiry_window_sequence", -1))
	if prefix == "monster":
		base["foreign_same_name_upgrade_must_respect_target_owner_limits"] = true
		base["foreign_upgrade_does_not_transfer_control"] = true
	return base


func _private_capability_base(actor_id: String, window_sequence: int, capability_kind: String) -> Dictionary:
	if not _configured or not _players.has(actor_id) or window_sequence < 0:
		return {"available": false, "authoritative": false, "reason_code": "organization_capability_request_invalid"}
	var player := _dictionary(_players[actor_id])
	return {
		"available": true,
		"authoritative": true,
		"actor_id": actor_id,
		"window_sequence": window_sequence,
		"owner_revision": int(player.get("revision", 0)),
		"capability_kind": capability_kind,
	}


func _active_record(actor_id: String, axis: String, window_sequence: int) -> Dictionary:
	var player := _dictionary(_players.get(actor_id, {}))
	for slot_variant in _array(player.get("slots", [])):
		var record := _dictionary(slot_variant)
		if str(record.get("axis", "")) != axis:
			continue
		var activation := int(record.get("activation_window_sequence", 2147483647))
		var expiry := int(record.get("expiry_window_sequence", -1))
		if window_sequence >= activation and (expiry < 0 or window_sequence <= expiry):
			return record.duplicate(true)
	return {}


func _record_payload(record: Dictionary) -> Dictionary:
	return _dictionary(record.get("payload", {})) if not record.is_empty() else {}


func _normalize_and_validate_payload(source: Dictionary) -> Dictionary:
	if not _is_pure_data(source):
		return {"valid": false, "reason_code": "organization_payload_not_pure_data"}
	var payload := source.duplicate(true)
	var axis := str(payload.get("organization_axis", ""))
	var family_id := str(payload.get("organization_family_id", ""))
	var rank := int(payload.get("organization_rank", 0))
	if not FAMILY_BY_AXIS.has(axis) or str(FAMILY_BY_AXIS[axis]) != family_id:
		return {"valid": false, "reason_code": "organization_family_axis_mismatch"}
	if rank < 1 or rank > 4:
		return {"valid": false, "reason_code": "organization_rank_invalid"}
	for exact in [
		["organization_slot_cost", 1],
		["organization_slot_limit", SLOT_LIMIT],
		["activation_window_offset", 1],
		["ordinary_submission_cost", 1],
	]:
		if int(payload.get(str(exact[0]), -1)) != int(exact[1]):
			return {"valid": false, "reason_code": "organization_common_term_invalid"}
	if str(payload.get("install_policy", "")) != "upgrade_highest_rank_only" \
		or str(payload.get("stack_policy", "")) != "highest_rank_nonstacking" \
		or not bool(payload.get("replacement_requires_higher_rank", false)) \
		or str(payload.get("equal_or_lower_rank_resolution", "")) != "reject_before_consume" \
		or str(payload.get("activation_snapshot_timing", "")) != "next_window_start" \
		or str(payload.get("persistence", "")) != "run" \
		or bool(payload.get("direct_player_interaction", true)) \
		or bool(payload.get("counterable", true)) \
		or bool(payload.get("phase_veto_eligible", true)) \
		or not bool(payload.get("counts_as_normal_card_submission", false)):
		return {"valid": false, "reason_code": "organization_common_policy_invalid"}
	var axis_error := _axis_payload_error(payload, axis, rank)
	if not axis_error.is_empty():
		return {"valid": false, "reason_code": axis_error}
	return {"valid": true, "reason_code": "", "payload": payload}


func _axis_payload_error(payload: Dictionary, axis: String, rank: int) -> String:
	match axis:
		AXIS_ASSET_CONVERSION:
			if int(payload.get("asset_conversion_bonus_bp", -1)) != ASSET_BONUS_BP[rank] \
				or int(payload.get("asset_conversion_bonus_cap_milli_per_second", -1)) != ASSET_CAP_MILLI_PER_SECOND[rank] \
				or str(payload.get("scope", "")) != "same_color_gdp_only":
				return "organization_asset_conversion_terms_invalid"
		AXIS_ACTION_BANDWIDTH:
			var expected_period := 3 if rank == 4 else 0
			var expected_burst := 1 if rank == 4 else 0
			var expected_burst_surcharge := 4 if rank == 4 else 0
			if int(payload.get("ordinary_submission_bonus", -1)) != 1 \
				or int(payload.get("extra_submission_asset_surcharge", -1)) != ACTION_SURCHARGE[rank] \
				or int(payload.get("ordinary_submission_hard_cap", -1)) != ABSOLUTE_SUBMISSION_LIMIT_CAP \
				or int(payload.get("burst_window_period", -1)) != expected_period \
				or int(payload.get("burst_submission_bonus", -1)) != expected_burst \
				or int(payload.get("burst_submission_surcharge", -1)) != expected_burst_surcharge \
				or not bool(payload.get("window_start_snapshot_required", false)) \
				or not bool(payload.get("response_cards_ignore_ordinary_submission_limit", false)):
				return "organization_action_bandwidth_terms_invalid"
		AXIS_HAND_CAPACITY:
			if int(payload.get("base_ordinary_hand_limit", -1)) != BASE_HAND_LIMIT \
				or int(payload.get("ordinary_hand_limit", -1)) != HAND_LIMIT_BY_RANK[rank] \
				or int(payload.get("ordinary_hand_limit_bonus", -1)) != HAND_LIMIT_BY_RANK[rank] - BASE_HAND_LIMIT \
				or int(payload.get("absolute_hand_limit_cap", -1)) != ABSOLUTE_HAND_LIMIT_CAP \
				or str(payload.get("scope", "")) != "ordinary_hand_only":
				return "organization_hand_capacity_terms_invalid"
		AXIS_MONSTER_BINDING:
			return _unit_payload_error(payload, rank, "monster")
		AXIS_MILITARY_COMMAND:
			return _unit_payload_error(payload, rank, "military")
	return ""


func _unit_payload_error(payload: Dictionary, rank: int, prefix: String) -> String:
	var base_count_key := "base_controlled_%s_count_limit" % prefix
	var base_primary_key := "base_primary_%s_rank_limit" % prefix
	if int(payload.get(base_count_key, -1)) != 1 \
		or int(payload.get(base_primary_key, -1)) != 2 \
		or int(payload.get("controlled_%s_count_limit" % prefix, -1)) != UNIT_COUNT_LIMIT_BY_RANK[rank] \
		or int(payload.get("primary_%s_rank_limit" % prefix, -1)) != PRIMARY_UNIT_RANK_LIMIT_BY_RANK[rank] \
		or int(payload.get("secondary_%s_rank_limit" % prefix, -1)) != SECONDARY_UNIT_RANK_LIMIT_BY_RANK[rank]:
		return "organization_%s_terms_invalid" % prefix
	if prefix == "monster" and (
		not bool(payload.get("foreign_same_name_upgrade_must_respect_target_owner_limits", false))
		or str(payload.get("foreign_upgrade_rank_limit_source", "")) != "target_current_owner_organization_snapshot"
		or not bool(payload.get("foreign_upgrade_does_not_transfer_control", false))
	):
		return "organization_monster_foreign_upgrade_terms_invalid"
	return ""


func _prepare_save_data(data: Dictionary) -> Dictionary:
	if int(data.get("state_version", -1)) != STATE_VERSION or str(data.get("ruleset_id", "")) != RULESET_ID:
		return {"valid": false, "reason_code": "organization_save_version_mismatch"}
	if not _is_pure_data(data):
		return {"valid": false, "reason_code": "organization_save_not_pure_data"}
	var actor_ids := _normalized_actor_ids(_array(data.get("actor_ids", [])))
	var players := _dictionary(data.get("players", {}))
	if actor_ids.is_empty() or players.size() != actor_ids.size():
		return {"valid": false, "reason_code": "organization_save_actor_shape_invalid"}
	for actor_id in actor_ids:
		if not players.has(actor_id) or not _player_state_valid(actor_id, _dictionary(players[actor_id])):
			return {"valid": false, "reason_code": "organization_save_player_invalid"}
	var journal := _dictionary(data.get("transaction_journal", {}))
	for transaction_id_variant in journal.keys():
		var transaction_id := str(transaction_id_variant)
		var lifecycle := _dictionary(journal[transaction_id_variant])
		if transaction_id.is_empty() or not ["prepared", "committed", "finalized", "rolled_back", "aborted"].has(str(lifecycle.get("stage", ""))) \
			or str(lifecycle.get("actor_id", "")) not in actor_ids \
			or not _binding_complete(_dictionary(lifecycle.get("binding", {}))):
			return {"valid": false, "reason_code": "organization_save_journal_invalid"}
	var secret := str(data.get("capability_secret", ""))
	if secret.is_empty():
		return {"valid": false, "reason_code": "organization_save_capability_secret_missing"}
	return {
		"valid": true,
		"configured": bool(data.get("configured", true)),
		"actor_ids": actor_ids,
		"players": players,
		"transaction_journal": journal,
		"revision": maxi(0, int(data.get("revision", 0))),
		"capability_secret": secret,
	}


func _player_state_valid(actor_id: String, player: Dictionary) -> bool:
	if str(player.get("actor_id", "")) != actor_id or int(player.get("revision", -1)) < 0:
		return false
	var slots := _array(player.get("slots", []))
	if slots.size() != SLOT_LIMIT:
		return false
	var families: Dictionary = {}
	for index in range(slots.size()):
		var record := _dictionary(slots[index])
		if record.is_empty():
			continue
		var family_id := str(record.get("family_id", ""))
		var axis := str(record.get("axis", ""))
		if families.has(family_id) or not FAMILY_BY_AXIS.has(axis) or str(FAMILY_BY_AXIS[axis]) != family_id \
			or int(record.get("slot_index", -1)) != index or int(record.get("activation_window_sequence", -1)) < 0:
			return false
		var payload_result := _normalize_and_validate_payload(_record_payload(record))
		if not bool(payload_result.get("valid", false)) or int(record.get("rank", 0)) != int(_record_payload(record).get("organization_rank", -1)):
			return false
		families[family_id] = true
	return true


func _empty_player_state(actor_id: String) -> Dictionary:
	return {"actor_id": actor_id, "revision": 0, "slots": [{}, {}, {}]}


func _family_slot(slots: Array, family_id: String) -> int:
	for index in range(slots.size()):
		if str(_dictionary(slots[index]).get("family_id", "")) == family_id:
			return index
	return -1


func _first_empty_slot(slots: Array) -> int:
	for index in range(slots.size()):
		if _dictionary(slots[index]).is_empty():
			return index
	return -1


func _binding_error(intent: Dictionary) -> String:
	if not _configured or not _is_pure_data(intent):
		return "organization_runtime_unavailable"
	if not _binding_complete(intent):
		return "organization_binding_incomplete"
	if str(intent.get("effect_kind", "")) != EFFECT_KIND:
		return "organization_effect_kind_invalid"
	return ""


func _binding_from(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in ["transaction_id", "actor_id", "card_id", "card_instance_id", "effect_kind", "target_hash", "payload_hash", "intent_hash"]:
		result[key] = str(source.get(key, ""))
	return result


func _binding_complete(source: Dictionary) -> bool:
	for value in _binding_from(source).values():
		if str(value).strip_edges().is_empty():
			return false
	return true


func _binding_matches(first: Dictionary, second: Dictionary) -> bool:
	for key in _binding_from(first).keys():
		if str(first.get(key, "")) != str(second.get(key, "")):
			return false
	return true


func _failure(source: Dictionary, reason_code: String, stage: String) -> Dictionary:
	var result := _binding_from(source)
	result.merge({"prepared": false, "committed": false, "finalized": false, "rolled_back": false, "reason_code": reason_code, "failure_stage": stage}, true)
	return result


func _journal_replay_or_collision(intent: Dictionary, lifecycle: Dictionary) -> Dictionary:
	if not _binding_matches(_dictionary(lifecycle.get("binding", {})), intent):
		return _failure(intent, "organization_transaction_binding_collision", "prepare")
	var terminal := _dictionary(lifecycle.get("terminal_receipt", {}))
	return terminal.duplicate(true) if not terminal.is_empty() else _dictionary(lifecycle.get("prepared_receipt", {})).duplicate(true)


func _transaction_id_from(value: Variant) -> String:
	if value is Dictionary:
		return str((value as Dictionary).get("transaction_id", ""))
	return str(value)


func _signed_capability_id(capability: Dictionary) -> String:
	var unsigned := capability.duplicate(true)
	unsigned.erase("capability_id")
	return "organization-capability:%s" % _fingerprint({"secret": _capability_secret, "capability": unsigned})


func _new_capability_secret() -> String:
	var bytes := Crypto.new().generate_random_bytes(24)
	return Marshalls.raw_to_base64(bytes)


func _fingerprint(value: Variant) -> String:
	return str(hash(JSON.stringify(_canonicalize(value))))


func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var keys: Array = (value as Dictionary).keys()
		keys.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
		var result: Dictionary = {}
		for key_variant in keys:
			result[str(key_variant)] = _canonicalize((value as Dictionary)[key_variant])
		return result
	if value is Array:
		var result: Array = []
		for item in value as Array:
			result.append(_canonicalize(item))
		return result
	return value


func _normalized_actor_ids(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		var actor_id := str(value).strip_edges()
		if not actor_id.is_empty() and actor_id not in result:
			result.append(actor_id)
	result.sort()
	return result


func _is_pure_data(value: Variant) -> bool:
	if value == null or value is bool or value is int or value is float or value is String or value is StringName:
		return true
	if value is Array:
		for item in value as Array:
			if not _is_pure_data(item):
				return false
		return true
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if not (key_variant is String or key_variant is StringName) or not _is_pure_data((value as Dictionary)[key_variant]):
				return false
		return true
	return false


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if value is Array else []
