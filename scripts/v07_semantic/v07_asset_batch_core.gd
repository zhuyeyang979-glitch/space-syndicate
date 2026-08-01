extends RefCounted
class_name V07AssetBatchCore

const CardDefinitions := preload(
	"res://scripts/v07_semantic/v072_card_definition_registry.gd"
)

const SCHEMA_VERSION := 1
const STATE_VERSION := 3
const RULESET_ID := CardDefinitions.RULESET_ID
const BALANCE_PROFILE_ID := CardDefinitions.BALANCE_PROFILE_ID
const BALANCE_PROFILE_FINGERPRINT := CardDefinitions.BALANCE_PROFILE_FINGERPRINT
const PROFILE_FINGERPRINT_INPUT := CardDefinitions.PROFILE_FINGERPRINT_INPUT

const ASSET_CORE_AUTHORITY_ID := "v072.six_color_assets.core_authority.v3"
const ASSET_AI_OBSERVATION_ID := "v072.six_color_assets.ai_observation.v3"
const ASSET_PLAYER_PROJECTION_ID := "v072.six_color_assets.player_projection.v3"
const ASSET_INTENT_ID := "v072.six_color_assets.intent.v3"
const ASSET_RECEIPT_ID := "v072.six_color_assets.authoritative_receipt.v3"
const ASSET_SAVE_STATE_ID := "v072.six_color_assets.save_state.v3"

const BATCH_CORE_AUTHORITY_ID := "v072.card_batch.core_authority.v3"
const BATCH_AI_OBSERVATION_ID := "v072.card_batch.ai_observation.v3"
const BATCH_PLAYER_PROJECTION_ID := "v072.card_batch.player_projection.v3"
const BATCH_INTENT_ID := "v072.card_batch.intent.v3"
const BATCH_RECEIPT_ID := "v072.card_batch.authoritative_receipt.v3"
const BATCH_SAVE_STATE_ID := "v072.card_batch.save_state.v3"
const PUBLIC_PROJECTION_ID := "v072.card_batch.public_projection.v3"

const INTERNAL_INTENT_ID := "internal.v072.asset_batch.lock_intent.v3"
const INTERNAL_RECEIPT_ID := "internal.v072.asset_batch.authoritative_receipt.v3"
const INTERNAL_SAVE_STATE_ID := "internal.v072.asset_batch.save_state.v3"
const CHECKPOINT_ID := "internal.v072.asset_batch.checkpoint.v3"
const PRIVACY_POLICY_ID := "v072.asset_batch.privacy.v3"
const TIME_ATTESTATION_INTERFACE_ID := "v07.time.authoritative_attestation.v1"
const TIME_ATTESTATION_LOOKUP_METHOD := "authoritative_time_attestation_v1"

const SIX_COLOR_ASSET_STATE_ID := "V072SixColorAssetState"
const ASSET_CYCLE_SNAPSHOT_ID := "V072AssetCycleSnapshot"
const ASSET_RESERVATION_STATE_ID := "V072AssetReservationState"
const CARD_BATCH_STATE_ID := "V072CardBatchState"
const PREBOUND_TARGET_STATE_ID := "V072PreboundTargetState"
const ANONYMOUS_RESOLUTION_STATE_ID := "V072AnonymousResolutionState"

const WINDOW_DURATION_MS := 30000
const MAX_ACTIONS_PER_PLAYER := 5
const ASSET_CAP := 6
const INITIAL_ASSETS_PER_COLOR := 0
const INITIAL_REMAINDER_MILLI_PER_COLOR := 0
const ZERO_DEADLOCK_MECHANISM := "zero_asset_cost_starter_cards"
const MAX_ASSET_REFRESH_PER_COLOR_PER_BATCH := 3
const DEFAULT_GDP_MILLI_PER_ASSET := 1000
const MAX_SAFE_INTEGER := 9007199254740991

const COLORS := [
	"life",
	"energy",
	"industry",
	"technology",
	"commerce",
	"shipping",
]
const ACTION_KINDS := [
	"normal_card",
	"commodity_card",
	"monster_action",
	"military_action",
]
const DIRECT_SETTLEMENT_OUTCOMES := [
	"success",
	"rule_allowed_refundable_failure",
]
const INVALID_TARGET_POLICY_IDS := [
	"FIZZLE_FULL_ASSET_REFUND",
	"FIZZLE_NO_REFUND",
	"RESOLVE_LEGAL_REMAINDER",
	"DETERMINISTIC_FALLBACK",
]
const DEFAULT_INVALID_TARGET_POLICY_ID := "FIZZLE_FULL_ASSET_REFUND"
const INVALID_TARGET_OUTCOME_BY_POLICY := {
	"FIZZLE_FULL_ASSET_REFUND": "invalid_target_fizzle_full_asset_refund",
	"FIZZLE_NO_REFUND": "invalid_target_fizzle_no_refund",
	"RESOLVE_LEGAL_REMAINDER": "invalid_target_resolve_legal_remainder",
	"DETERMINISTIC_FALLBACK": "invalid_target_deterministic_fallback",
}

const SETTLEMENT_OUTCOMES := [
	"success",
	"rule_allowed_refundable_failure",
	"invalid_target_fizzle_full_asset_refund",
	"invalid_target_fizzle_no_refund",
	"invalid_target_resolve_legal_remainder",
	"invalid_target_deterministic_fallback",
]

const STATE_FIELDS := [
	"schema_version",
	"state_version",
	"ruleset_id",
	"balance_profile_id",
	"balance_profile_fingerprint",
	"default_invalid_target_policy_id",
	"max_asset_refresh_per_color_per_batch",
	"core_authority_ids",
	"revision",
	"batch_id",
	"lineage_fingerprint",
	"window",
	"player_ids",
	"submission_hidden_lead_order",
	"frozen_hidden_lead_order",
	"gdp_milli_per_asset",
	"players",
	"authority_queue",
	"resolution_cursor",
	"seen_intent_ids",
	"intent_receipt_ledger",
	"receipts",
	"refresh_applied",
]
const WINDOW_FIELDS := [
	"opened_at_ms",
	"deadline_ms",
	"status",
	"one_shot",
	"locked_player_count",
	"time_observation_watermark_ms",
]
const PLAYER_FIELDS := [
	"assets",
	"remainders_milli",
	"queue_status",
	"local_queue",
	"reservations",
	"reserved_totals",
	"frozen_gdp_milli",
	"action_results",
	"refresh_overflow",
]
const ACTION_FIELDS := [
	"action_id",
	"action_kind",
	"source_id",
	"local_order",
	"card",
	"target_binding",
	"current_effect",
	"cost",
	"any_payment",
	"invalid_target_policy_id",
	"lock_fingerprint",
]
const TARGET_BINDING_FIELDS := [
	"binding_id",
	"target_ids",
	"selection_revision",
	"complete",
]
const AUTHORITY_QUEUE_FIELDS := [
	"action_id",
	"actor_id",
	"local_order",
	"reservation",
	"public",
]
const PUBLIC_QUEUE_FIELDS := [
	"card",
	"rule_allowed_target",
	"current_effect",
	"result",
	"reason_code",
	"invalid_target_policy_id",
	"asset_refund_applied",
	"normal_card_destination",
	"action_slot_refunded",
]
const ACTION_RESULT_FIELDS := [
	"outcome_id",
	"reason_code",
	"invalid_target_policy_id",
	"asset_refund_applied",
	"normal_card_destination",
	"action_slot_refunded",
]
const INTENT_FIELDS := [
	"schema_version",
	"contract_id",
	"intent_id",
	"batch_id",
	"actor_id",
	"submitted_at_ms",
	"actions",
	"intent_fingerprint",
]
const RECEIPT_FIELDS := [
	"schema_version",
	"contract_id",
	"receipt_id",
	"batch_id",
	"lineage_fingerprint",
	"operation_id",
	"accepted",
	"reason_code",
	"state_revision",
	"actor_id",
	"action_id",
	"outcome_id",
	"invalid_target_policy_id",
	"public_history_reason_code",
	"asset_refund_applied",
	"normal_card_destination",
	"action_slot_refunded",
	"intent_id",
	"intent_fingerprint",
	"receipt_fingerprint",
]
const TIME_ATTESTATION_FIELDS := [
	"schema_version",
	"interface_id",
	"attestation_id",
	"observed_at_ms",
	"attestation_fingerprint",
]
const INTENT_RECEIPT_LEDGER_ENTRY_FIELDS := [
	"intent_id",
	"intent_fingerprint",
	"submitted_at_ms",
	"receipt_id",
	"receipt_fingerprint",
	"actor_id",
	"lineage_fingerprint",
]
const ASSET_CORE_CONTRACT_FIELDS := [
	"schema_version", "state_version", "ruleset_id", "contract_id",
	"balance_profile_id", "balance_profile_fingerprint",
	"default_invalid_target_policy_id",
	"max_asset_refresh_per_color_per_batch", "state_revision",
	"per_player_assets_by_color", "per_player_fixed_point_remainders",
	"gdp_cycle_snapshot", "per_action_reservations", "reservation_journal",
	"asset_refresh_revision", "authority_fingerprint",
]
const ASSET_VIEW_CONTRACT_FIELDS := [
	"schema_version", "state_version", "ruleset_id", "contract_id",
	"balance_profile_id", "balance_profile_fingerprint",
	"default_invalid_target_policy_id",
	"max_asset_refresh_per_color_per_batch", "viewer_id", "state_revision",
	"own_exact_assets", "own_remainders", "own_reservations",
	"own_available_assets", "own_projected_refresh", "public_costs",
	"projection_fingerprint",
]
const ASSET_INTENT_CONTRACT_FIELDS := [
	"schema_version", "state_version", "ruleset_id", "contract_id",
	"balance_profile_id", "balance_profile_fingerprint",
	"default_invalid_target_policy_id",
	"intent_id", "actor_id",
	"expected_core_revision", "asset_snapshot_revision", "action_costs",
	"reservation_ids", "intent_fingerprint",
]
const ASSET_RECEIPT_CONTRACT_FIELDS := [
	"schema_version", "state_version", "ruleset_id", "contract_id",
	"balance_profile_id", "balance_profile_fingerprint",
	"default_invalid_target_policy_id",
	"receipt_id", "intent_id", "accepted",
	"reason_code", "committed_core_revision", "reservation_ids",
	"asset_delta_by_color", "receipt_fingerprint",
]
const ASSET_SAVE_CONTRACT_FIELDS := [
	"schema_version", "state_version", "ruleset_id", "contract_id",
	"balance_profile_id", "balance_profile_fingerprint",
	"default_invalid_target_policy_id",
	"max_asset_refresh_per_color_per_batch", "section_id",
	"state_revision", "per_player_assets_by_color",
	"per_player_fixed_point_remainders", "gdp_cycle_snapshot",
	"per_action_reservations", "reservation_journal",
	"asset_refresh_revision", "shared_batch_id",
	"shared_lineage_fingerprint", "shared_authority_state",
	"save_fingerprint",
]
const BATCH_CORE_CONTRACT_FIELDS := [
	"schema_version", "state_version", "ruleset_id", "contract_id",
	"balance_profile_id", "balance_profile_fingerprint",
	"default_invalid_target_policy_id",
	"state_revision",
	"submission_window_state", "player_local_queues", "prebound_targets",
	"private_owner_bindings", "anonymous_global_queue", "round_robin_cursor",
	"resolution_journal", "processed_intent_ids", "intent_receipt_ledger",
	"authority_fingerprint",
]
const BATCH_VIEW_CONTRACT_FIELDS := [
	"schema_version", "state_version", "ruleset_id", "contract_id",
	"balance_profile_id", "balance_profile_fingerprint",
	"default_invalid_target_policy_id",
	"viewer_id", "state_revision",
	"own_local_queue", "own_prebound_targets", "own_reserved_costs",
	"anonymous_public_queue", "public_resolution_aftermath",
	"projection_fingerprint",
]
const BATCH_INTENT_CONTRACT_FIELDS := [
	"schema_version", "state_version", "ruleset_id", "contract_id",
	"balance_profile_id", "balance_profile_fingerprint",
	"default_invalid_target_policy_id",
	"intent_id",
	"actor_id_or_authoritative_system", "expected_core_revision", "window_id",
	"local_action_index", "source_instance_id", "prebound_target_identity",
	"reservation_id", "intent_fingerprint",
]
const BATCH_RECEIPT_CONTRACT_FIELDS := [
	"schema_version", "state_version", "ruleset_id", "contract_id",
	"balance_profile_id", "balance_profile_fingerprint",
	"default_invalid_target_policy_id",
	"receipt_id", "intent_id", "accepted",
	"reason_code", "committed_core_revision", "window_id",
	"anonymous_action_id", "resolution_status", "receipt_fingerprint",
]
const BATCH_SAVE_CONTRACT_FIELDS := [
	"schema_version", "state_version", "ruleset_id", "contract_id",
	"balance_profile_id", "balance_profile_fingerprint",
	"default_invalid_target_policy_id",
	"section_id",
	"state_revision", "submission_window_state", "player_local_queues",
	"prebound_targets", "private_owner_bindings", "anonymous_global_queue",
	"round_robin_cursor", "resolution_journal", "processed_intent_ids",
	"intent_receipt_ledger",
	"shared_batch_id", "shared_lineage_fingerprint",
	"shared_authority_state", "save_fingerprint",
]


var _time_attestation_authority: RefCounted = null


func bind_time_attestation_authority(authority: RefCounted) -> Dictionary:
	_time_attestation_authority = null
	if authority == null or not authority.has_method(TIME_ATTESTATION_LOOKUP_METHOD):
		return {
			"bound": false,
			"reason_code": "time_attestation_authority_port_invalid",
		}
	_time_attestation_authority = authority
	return {
		"bound": true,
		"reason_code": "time_attestation_authority_bound",
	}


func unbind_time_attestation_authority() -> Dictionary:
	_time_attestation_authority = null
	return {
		"bound": false,
		"reason_code": "time_attestation_authority_unbound",
	}


static func create_state(
	batch_id: String,
	player_ids: Array,
	hidden_lead_order: Array,
	initial_assets: Dictionary,
	initial_remainders_milli: Dictionary = {},
	opened_at_ms: int = 0,
	gdp_milli_per_asset: int = DEFAULT_GDP_MILLI_PER_ASSET
) -> Dictionary:
	if not _stable_id(batch_id) or not _nonnegative_integer(opened_at_ms) \
			or not _positive_integer(gdp_milli_per_asset):
		return {}
	var normalized_players := _string_id_array(player_ids, false)
	var normalized_order := _string_id_array(hidden_lead_order, false)
	if normalized_players.is_empty() or normalized_order.is_empty() \
			or not _same_string_set(normalized_players, normalized_order):
		return {}
	if not _exact_keys(initial_assets, normalized_players):
		return {}
	if not initial_remainders_milli.is_empty() \
			and not _exact_keys(initial_remainders_milli, normalized_players):
		return {}

	var players := {}
	for player_id in normalized_players:
		var assets_variant: Variant = initial_assets.get(player_id)
		if not _color_map_valid(assets_variant, 0, ASSET_CAP):
			return {}
		var remainders := _zero_color_map()
		if initial_remainders_milli.has(player_id):
			var remainder_variant: Variant = initial_remainders_milli.get(player_id)
			if not _color_map_valid(remainder_variant, 0, gdp_milli_per_asset - 1):
				return {}
			remainders = (remainder_variant as Dictionary).duplicate(true)
		players[player_id] = {
			"assets": (assets_variant as Dictionary).duplicate(true),
			"remainders_milli": remainders,
			"queue_status": "open",
			"local_queue": [],
			"reservations": {},
			"reserved_totals": _zero_color_map(),
			"frozen_gdp_milli": _zero_color_map(),
			"action_results": {},
			"refresh_overflow": _zero_color_map(),
		}

	var lineage_fingerprint := _fingerprint({
		"schema_version": SCHEMA_VERSION,
		"state_version": STATE_VERSION,
		"ruleset_id": RULESET_ID,
		"balance_profile_id": BALANCE_PROFILE_ID,
		"balance_profile_fingerprint": BALANCE_PROFILE_FINGERPRINT,
		"default_invalid_target_policy_id": DEFAULT_INVALID_TARGET_POLICY_ID,
		"max_asset_refresh_per_color_per_batch": (
			MAX_ASSET_REFRESH_PER_COLOR_PER_BATCH
		),
		"batch_id": batch_id,
		"opened_at_ms": opened_at_ms,
		"player_ids": normalized_players,
		"initial_submission_hidden_lead_order": normalized_order,
		"gdp_milli_per_asset": gdp_milli_per_asset,
		"initial_assets": initial_assets.duplicate(true),
		"initial_remainders_milli": initial_remainders_milli.duplicate(true),
	})
	var state := {
		"schema_version": SCHEMA_VERSION,
		"state_version": STATE_VERSION,
		"ruleset_id": RULESET_ID,
		"balance_profile_id": BALANCE_PROFILE_ID,
		"balance_profile_fingerprint": BALANCE_PROFILE_FINGERPRINT,
		"default_invalid_target_policy_id": DEFAULT_INVALID_TARGET_POLICY_ID,
		"max_asset_refresh_per_color_per_batch": (
			MAX_ASSET_REFRESH_PER_COLOR_PER_BATCH
		),
		"core_authority_ids": [ASSET_CORE_AUTHORITY_ID, BATCH_CORE_AUTHORITY_ID],
		"revision": 0,
		"batch_id": batch_id,
		"lineage_fingerprint": lineage_fingerprint,
		"window": {
			"opened_at_ms": opened_at_ms,
			"deadline_ms": opened_at_ms + WINDOW_DURATION_MS,
			"status": "submission_open",
			"one_shot": true,
			"locked_player_count": 0,
			"time_observation_watermark_ms": opened_at_ms,
		},
		"player_ids": normalized_players,
		"submission_hidden_lead_order": normalized_order,
		"frozen_hidden_lead_order": [],
		"gdp_milli_per_asset": gdp_milli_per_asset,
		"players": players,
		"authority_queue": [],
		"resolution_cursor": 0,
		"seen_intent_ids": [],
		"intent_receipt_ledger": {},
		"receipts": [],
		"refresh_applied": false,
	}
	return state if _state_error(state).is_empty() else {}


static func create_genesis_state(
	batch_id: String,
	player_ids: Array,
	hidden_lead_order: Array,
	opened_at_ms: int = 0,
	gdp_milli_per_asset: int = DEFAULT_GDP_MILLI_PER_ASSET
) -> Dictionary:
	var normalized_players := _string_id_array(player_ids, false)
	if normalized_players.is_empty():
		return {}
	var initial_assets := {}
	var initial_remainders := {}
	for player_id in normalized_players:
		initial_assets[player_id] = _zero_color_map()
		initial_remainders[player_id] = _zero_color_map()
	return create_state(
		batch_id,
		normalized_players,
		hidden_lead_order,
		initial_assets,
		initial_remainders,
		opened_at_ms,
		gdp_milli_per_asset
	)


static func update_submission_hidden_lead_order(
	state: Dictionary,
	authoritative_order: Array,
	observed_at_ms: int
) -> Dictionary:
	if not _state_error(state).is_empty():
		return _failure(state, "update_submission_hidden_lead_order", "state_invalid")
	var window := state.get("window") as Dictionary
	if str(window.get("status", "")) != "submission_open":
		return _failure(state, "update_submission_hidden_lead_order", "hidden_lead_order_already_frozen")
	if not _nonnegative_integer(observed_at_ms) \
			or observed_at_ms > int(window.get("deadline_ms", -1)):
		return _failure(state, "update_submission_hidden_lead_order", "hidden_lead_observation_time_invalid")
	var normalized := _string_id_array(authoritative_order, false)
	var player_ids := _string_id_array(state.get("player_ids"), false)
	if normalized.is_empty() or not _same_string_set(normalized, player_ids):
		return _failure(state, "update_submission_hidden_lead_order", "hidden_lead_order_invalid")
	var next := state.duplicate(true)
	next["submission_hidden_lead_order"] = normalized
	_increment_revision(next)
	var receipt := _receipt(
		next,
		"update_submission_hidden_lead_order",
		true,
		"hidden_lead_order_updated",
		"",
		"",
		"submission_order_updated"
	)
	(next.get("receipts") as Array).append(receipt)
	return _success(next, receipt)


static func build_prebound_action(
	action_id: String,
	action_kind: String,
	source_id: String,
	local_order: int,
	card: String,
	target_binding: Dictionary,
	current_effect: String,
	cost: Dictionary,
	any_payment: Dictionary,
	invalid_target_policy_id: String = DEFAULT_INVALID_TARGET_POLICY_ID
) -> Dictionary:
	var action := {
		"action_id": action_id,
		"action_kind": action_kind,
		"source_id": source_id,
		"local_order": local_order,
		"card": card,
		"target_binding": target_binding.duplicate(true),
		"current_effect": current_effect,
		"cost": cost.duplicate(true),
		"any_payment": any_payment.duplicate(true),
		"invalid_target_policy_id": invalid_target_policy_id,
	}
	if not _action_error_without_fingerprint(action).is_empty():
		return {}
	action["lock_fingerprint"] = _fingerprint(action)
	return action


static func build_target_binding(
	binding_id: String,
	target_ids: Array,
	selection_revision: int
) -> Dictionary:
	var binding := {
		"binding_id": binding_id,
		"target_ids": _string_id_array(target_ids, false),
		"selection_revision": selection_revision,
		"complete": true,
	}
	return binding if _target_binding_error(binding).is_empty() else {}


static func build_lock_intent(
	intent_id: String,
	batch_id: String,
	actor_id: String,
	submitted_at_ms: int,
	actions: Array
) -> Dictionary:
	var intent := {
		"schema_version": SCHEMA_VERSION,
		"contract_id": INTERNAL_INTENT_ID,
		"intent_id": intent_id,
		"batch_id": batch_id,
		"actor_id": actor_id,
		"submitted_at_ms": submitted_at_ms,
		"actions": actions.duplicate(true),
	}
	if not _intent_error_without_fingerprint(intent).is_empty():
		return {}
	intent["intent_fingerprint"] = _fingerprint(intent)
	return intent


static func validate_time_attestation(attestation: Dictionary) -> String:
	if not _is_pure_data(attestation) \
			or not _exact_fields(attestation, TIME_ATTESTATION_FIELDS):
		return "time_attestation_fields_invalid"
	if attestation.get("schema_version") != SCHEMA_VERSION \
			or attestation.get("interface_id") != TIME_ATTESTATION_INTERFACE_ID \
			or not _stable_id(attestation.get("attestation_id")) \
			or not _nonnegative_integer(attestation.get("observed_at_ms")):
		return "time_attestation_schema_invalid"
	var unsealed := attestation.duplicate(true)
	unsealed.erase("attestation_fingerprint")
	if not _fingerprint_valid(attestation.get("attestation_fingerprint")) \
			or attestation.get("attestation_fingerprint") != _fingerprint(unsealed):
		return "time_attestation_fingerprint_invalid"
	return ""


func _trusted_time_observation(attestation: Dictionary) -> Dictionary:
	var shape_reason := validate_time_attestation(attestation)
	if not shape_reason.is_empty():
		return {"valid": false, "reason_code": shape_reason}
	if _time_attestation_authority == null:
		return {
			"valid": false,
			"reason_code": "time_attestation_authority_unbound",
		}
	if not _time_attestation_authority.has_method(TIME_ATTESTATION_LOOKUP_METHOD):
		return {
			"valid": false,
			"reason_code": "time_attestation_authority_port_invalid",
		}
	var issued_variant: Variant = _time_attestation_authority.call(
		TIME_ATTESTATION_LOOKUP_METHOD,
		str(attestation.get("attestation_id", ""))
	)
	if not (issued_variant is Dictionary) or (issued_variant as Dictionary).is_empty():
		return {
			"valid": false,
			"reason_code": "time_attestation_authoritative_record_missing",
		}
	if (issued_variant as Dictionary) != attestation:
		return {
			"valid": false,
			"reason_code": "time_attestation_authoritative_record_mismatch",
		}
	return {
		"valid": true,
		"reason_code": "none",
		"observed_at_ms": int(attestation.get("observed_at_ms", -1)),
	}


func lock_player_queue(
	state: Dictionary,
	intent: Dictionary,
	completed_gdp_milli: Dictionary,
	time_attestation: Dictionary,
	authoritative_hidden_lead_order: Array = []
) -> Dictionary:
	var state_error := _state_error(state)
	if not state_error.is_empty():
		return _failure(state, "lock_player_queue", "state_invalid")
	var intent_error := _intent_error(intent)
	if not intent_error.is_empty():
		return _failure(state, "lock_player_queue", intent_error)
	var actor_id := str(intent.get("actor_id", ""))
	var intent_id := str(intent.get("intent_id", ""))
	if str(intent.get("batch_id", "")) != str(state.get("batch_id", "")):
		return _failure(state, "lock_player_queue", "batch_binding_invalid", actor_id)
	if not (state.get("player_ids") as Array).has(actor_id):
		return _failure(state, "lock_player_queue", "actor_not_registered", actor_id)
	var intent_ledger := state.get("intent_receipt_ledger") as Dictionary
	if intent_ledger.has(intent_id):
		var prior_entry := intent_ledger.get(intent_id) as Dictionary
		if prior_entry.get("intent_fingerprint") != intent.get("intent_fingerprint"):
			return _failure(state, "lock_player_queue", "intent_id_collision", actor_id)
		var prior_receipt := _receipt_by_id(
			state.get("receipts") as Array,
			str(prior_entry.get("receipt_id", ""))
		)
		if prior_receipt.is_empty() \
				or prior_receipt.get("receipt_fingerprint") \
					!= prior_entry.get("receipt_fingerprint"):
			return _failure(state, "lock_player_queue", "intent_receipt_ledger_invalid", actor_id)
		return _success(state, prior_receipt)
	var window := state.get("window") as Dictionary
	if str(window.get("status", "")) != "submission_open":
		return _failure(state, "lock_player_queue", "one_shot_window_closed", actor_id)
	var time_observation := _trusted_time_observation(time_attestation)
	if not bool(time_observation.get("valid", false)):
		return _failure(
			state,
			"lock_player_queue",
			str(time_observation.get("reason_code", "time_attestation_invalid")),
			actor_id
		)
	var authority_observed_at_ms := int(time_observation.get("observed_at_ms", -1))
	if authority_observed_at_ms < int(window.get("opened_at_ms", -1)):
		return _failure(
			state,
			"lock_player_queue",
			"authority_observation_time_invalid",
			actor_id
		)
	if authority_observed_at_ms \
			< int(window.get("time_observation_watermark_ms", -1)):
		return _failure(
			state,
			"lock_player_queue",
			"time_observation_regressed",
			actor_id
		)
	if authority_observed_at_ms > int(window.get("deadline_ms", -1)):
		return _failure(state, "lock_player_queue", "submission_deadline_elapsed", actor_id)
	if int(intent.get("submitted_at_ms", -1)) > authority_observed_at_ms:
		return _failure(
			state,
			"lock_player_queue",
			"submission_after_authority_observation",
			actor_id
		)
	var player := (state.get("players") as Dictionary).get(actor_id) as Dictionary
	if str(player.get("queue_status", "")) != "open":
		return _failure(state, "lock_player_queue", "player_queue_already_locked", actor_id)
	if not _color_map_valid(completed_gdp_milli, 0, MAX_SAFE_INTEGER):
		return _failure(state, "lock_player_queue", "gdp_snapshot_invalid", actor_id)
	var normalized_authoritative_order: Array[String] = []
	if not authoritative_hidden_lead_order.is_empty():
		normalized_authoritative_order = _string_id_array(
			authoritative_hidden_lead_order,
			false
		)
		if normalized_authoritative_order.is_empty() \
				or not _same_string_set(
					normalized_authoritative_order,
					_string_id_array(state.get("player_ids"), false)
				):
			return _failure(state, "lock_player_queue", "hidden_lead_order_invalid", actor_id)

	var sorted_actions := _sorted_actions(intent.get("actions") as Array)
	if sorted_actions.size() != (intent.get("actions") as Array).size():
		return _failure(state, "lock_player_queue", "local_order_invalid", actor_id)
	var existing_action_ids := _all_action_ids(state)
	for action_variant in sorted_actions:
		var action_id := str((action_variant as Dictionary).get("action_id", ""))
		if existing_action_ids.has(action_id):
			return _failure(state, "lock_player_queue", "action_id_already_bound", actor_id)
		existing_action_ids.append(action_id)

	var reservation_plan := _reservation_plan(
		sorted_actions,
		player.get("assets") as Dictionary
	)
	if not bool(reservation_plan.get("affordable", false)):
		return _failure(
			state,
			"lock_player_queue",
			str(reservation_plan.get("reason_code", "full_queue_unaffordable")),
			actor_id
		)

	var next := state.duplicate(true)
	(next.get("window") as Dictionary)["time_observation_watermark_ms"] = (
		authority_observed_at_ms
	)
	if not normalized_authoritative_order.is_empty():
		next["submission_hidden_lead_order"] = normalized_authoritative_order
	_lock_player_in_state(
		next,
		actor_id,
		sorted_actions,
		reservation_plan.get("reservations") as Dictionary,
		reservation_plan.get("totals") as Dictionary,
		completed_gdp_milli
	)
	(next.get("seen_intent_ids") as Array).append(intent_id)
	_increment_revision(next)
	var receipt := _receipt(
		next,
		"lock_player_queue",
		true,
		"queue_locked",
		actor_id,
		"",
		"reserved",
		intent_id,
		str(intent.get("intent_fingerprint", ""))
	)
	(next.get("receipts") as Array).append(receipt)
	(next.get("intent_receipt_ledger") as Dictionary)[intent_id] = {
		"intent_id": intent_id,
		"intent_fingerprint": str(intent.get("intent_fingerprint", "")),
		"submitted_at_ms": int(intent.get("submitted_at_ms", -1)),
		"receipt_id": str(receipt.get("receipt_id", "")),
		"receipt_fingerprint": str(receipt.get("receipt_fingerprint", "")),
		"actor_id": actor_id,
		"lineage_fingerprint": str(next.get("lineage_fingerprint", "")),
	}
	_finalize_submission_if_ready(next)
	return _success(next, receipt)


func close_expired_window(
	state: Dictionary,
	time_attestation: Dictionary,
	completed_gdp_milli_by_player: Dictionary,
	authoritative_hidden_lead_order: Array = []
) -> Dictionary:
	if not _state_error(state).is_empty():
		return _failure(state, "close_expired_window", "state_invalid")
	var window := state.get("window") as Dictionary
	if str(window.get("status", "")) != "submission_open":
		return _failure(state, "close_expired_window", "one_shot_window_closed")
	var time_observation := _trusted_time_observation(time_attestation)
	if not bool(time_observation.get("valid", false)):
		return _failure(
			state,
			"close_expired_window",
			str(time_observation.get("reason_code", "time_attestation_invalid"))
		)
	var observed_at_ms := int(time_observation.get("observed_at_ms", -1))
	if observed_at_ms < int(window.get("time_observation_watermark_ms", -1)):
		return _failure(state, "close_expired_window", "time_observation_regressed")
	if observed_at_ms <= int(window.get("deadline_ms", -1)):
		return _failure(state, "close_expired_window", "submission_window_still_open")
	if not _is_pure_data(completed_gdp_milli_by_player):
		return _failure(state, "close_expired_window", "gdp_snapshot_set_invalid")

	var players := state.get("players") as Dictionary
	var normalized_authoritative_order := _string_id_array(
		authoritative_hidden_lead_order,
		true
	)
	if not authoritative_hidden_lead_order.is_empty() \
			and (
				normalized_authoritative_order.is_empty() \
				or not _same_string_set(
					normalized_authoritative_order,
					_string_id_array(state.get("player_ids"), false)
				)
			):
		return _failure(state, "close_expired_window", "hidden_lead_order_invalid")
	var open_player_ids: Array[String] = []
	for player_id_variant in state.get("player_ids") as Array:
		var player_id := str(player_id_variant)
		var player := players.get(player_id) as Dictionary
		if str(player.get("queue_status", "")) == "open":
			open_player_ids.append(player_id)
			if not completed_gdp_milli_by_player.has(player_id) \
					or not _color_map_valid(
						completed_gdp_milli_by_player.get(player_id),
						0,
						MAX_SAFE_INTEGER
					):
				return _failure(state, "close_expired_window", "gdp_snapshot_set_invalid")

	var next := state.duplicate(true)
	(next.get("window") as Dictionary)["time_observation_watermark_ms"] = observed_at_ms
	if not normalized_authoritative_order.is_empty():
		next["submission_hidden_lead_order"] = normalized_authoritative_order
	for player_id in open_player_ids:
		_lock_player_in_state(
			next,
			player_id,
			[],
			{},
			_zero_color_map(),
			(completed_gdp_milli_by_player.get(player_id) as Dictionary)
		)
	_increment_revision(next)
	var receipt := _receipt(
		next,
		"close_expired_window",
		true,
		"window_closed",
		"",
		"",
		"empty_queues_locked"
	)
	(next.get("receipts") as Array).append(receipt)
	_finalize_submission_if_ready(next)
	return _success(next, receipt)


static func settle_next_action(
	state: Dictionary,
	action_id: String,
	outcome_id: String
) -> Dictionary:
	if not _stable_id(action_id) or not DIRECT_SETTLEMENT_OUTCOMES.has(outcome_id):
		return _failure(state, "settle_next_action", "resolution_outcome_invalid", "", action_id)
	var context := _resolution_context(state, action_id, "settle_next_action")
	if not bool(context.get("valid", false)):
		return (context.get("failure") as Dictionary).duplicate(true)
	var action := context.get("action") as Dictionary
	var result_record := {
		"outcome_id": outcome_id,
		"reason_code": "action_resolved_success" \
			if outcome_id == "success" else "rule_allowed_refundable_failure",
		"invalid_target_policy_id": action.get("invalid_target_policy_id"),
		"asset_refund_applied": outcome_id == "rule_allowed_refundable_failure",
		"normal_card_destination": "not_attested",
		"action_slot_refunded": false,
	}
	return _commit_current_resolution(
		state,
		context,
		result_record,
		outcome_id == "success",
		"settle_next_action",
		"action_settled"
	)


static func settle_invalid_target(
	state: Dictionary,
	action_id: String,
	public_history_reason_code: String
) -> Dictionary:
	if not _stable_id(action_id) or not _stable_id(public_history_reason_code) \
			or ["none", "pending"].has(public_history_reason_code):
		return _failure(
			state,
			"settle_invalid_target",
			"invalid_target_reason_invalid",
			"",
			action_id
		)
	var context := _resolution_context(state, action_id, "settle_invalid_target")
	if not bool(context.get("valid", false)):
		return (context.get("failure") as Dictionary).duplicate(true)
	var action := context.get("action") as Dictionary
	var policy_id := str(action.get("invalid_target_policy_id", ""))
	if not INVALID_TARGET_POLICY_IDS.has(policy_id):
		return _failure(
			state,
			"settle_invalid_target",
			"invalid_target_policy_invalid",
			str(context.get("actor_id", "")),
			action_id
		)
	var refund_assets := policy_id == "FIZZLE_FULL_ASSET_REFUND"
	var result_record := {
		"outcome_id": str(INVALID_TARGET_OUTCOME_BY_POLICY.get(policy_id, "")),
		"reason_code": public_history_reason_code,
		"invalid_target_policy_id": policy_id,
		"asset_refund_applied": refund_assets,
		"normal_card_destination": "discard" \
			if str(action.get("action_kind", "")) == "normal_card" \
			else "not_applicable",
		"action_slot_refunded": false,
	}
	return _commit_current_resolution(
		state,
		context,
		result_record,
		not refund_assets,
		"settle_invalid_target",
		"invalid_target_resolved"
	)


static func refresh_assets_after_batch(state: Dictionary) -> Dictionary:
	if not _state_error(state).is_empty():
		return _failure(state, "refresh_assets_after_batch", "state_invalid")
	if bool(state.get("refresh_applied", false)):
		return _failure(state, "refresh_assets_after_batch", "refresh_already_applied")
	if str((state.get("window") as Dictionary).get("status", "")) != "batch_resolved":
		return _failure(state, "refresh_assets_after_batch", "batch_not_resolved")
	for player_variant in (state.get("players") as Dictionary).values():
		if not (player_variant.get("reservations") as Dictionary).is_empty():
			return _failure(state, "refresh_assets_after_batch", "reservation_settlement_incomplete")

	var next := state.duplicate(true)
	var conversion := int(next.get("gdp_milli_per_asset", DEFAULT_GDP_MILLI_PER_ASSET))
	for player_id_variant in next.get("player_ids") as Array:
		var player := (next.get("players") as Dictionary).get(str(player_id_variant)) as Dictionary
		var assets := player.get("assets") as Dictionary
		var remainders := player.get("remainders_milli") as Dictionary
		var snapshot := player.get("frozen_gdp_milli") as Dictionary
		var overflow := player.get("refresh_overflow") as Dictionary
		for color in COLORS:
			var accrued_milli := int(remainders.get(color, 0)) + int(snapshot.get(color, 0))
			var raw_earned_units := accrued_milli / conversion
			var capped_earned_units := mini(
				raw_earned_units,
				int(next.get(
					"max_asset_refresh_per_color_per_batch",
					MAX_ASSET_REFRESH_PER_COLOR_PER_BATCH
				))
			)
			var before_assets := int(assets.get(color, 0))
			var candidate := before_assets + capped_earned_units
			var refreshed_assets := mini(ASSET_CAP, candidate)
			overflow[color] = maxi(0, raw_earned_units - (refreshed_assets - before_assets))
			assets[color] = refreshed_assets
			remainders[color] = accrued_milli % conversion
	next["refresh_applied"] = true
	(next.get("window") as Dictionary)["status"] = "assets_refreshed"
	_increment_revision(next)
	var receipt := _receipt(
		next,
		"refresh_assets_after_batch",
		true,
		"frozen_snapshot_applied",
		"",
		"",
		"assets_refreshed"
	)
	(next.get("receipts") as Array).append(receipt)
	return _success(next, receipt)


static func reject_resolution_input(state: Dictionary, operation_id: String) -> Dictionary:
	if not _state_error(state).is_empty():
		return _failure(state, "reject_resolution_input", "state_invalid")
	if not _stable_id(operation_id):
		return _failure(state, "reject_resolution_input", "operation_invalid")
	return _failure(state, "reject_resolution_input", "resolution_accepts_no_new_input")


static func core_authority(state: Dictionary) -> Dictionary:
	if not _state_error(state).is_empty():
		return {}
	return _seal({
		"schema_version": SCHEMA_VERSION,
		"state_version": STATE_VERSION,
		"ruleset_id": RULESET_ID,
		"balance_profile_id": BALANCE_PROFILE_ID,
		"balance_profile_fingerprint": BALANCE_PROFILE_FINGERPRINT,
		"contract_ids": [ASSET_CORE_AUTHORITY_ID, BATCH_CORE_AUTHORITY_ID],
		"state": state.duplicate(true),
	}, "authority_fingerprint")


static func public_projection(state: Dictionary) -> Dictionary:
	if not _state_error(state).is_empty():
		return {}
	var public_queue: Array = []
	for entry_variant in state.get("authority_queue") as Array:
		public_queue.append((entry_variant as Dictionary).get("public").duplicate(true))
	var window := state.get("window") as Dictionary
	return _seal({
		"schema_version": SCHEMA_VERSION,
		"state_version": STATE_VERSION,
		"ruleset_id": RULESET_ID,
		"balance_profile_id": BALANCE_PROFILE_ID,
		"balance_profile_fingerprint": BALANCE_PROFILE_FINGERPRINT,
		"contract_id": PUBLIC_PROJECTION_ID,
		"batch_id": state.get("batch_id"),
		"state_revision": state.get("revision"),
		"window_status": window.get("status"),
		"window_duration_ms": WINDOW_DURATION_MS,
		"submission_deadline_ms": window.get("deadline_ms"),
		"anonymous_queue": public_queue,
		"resolution_cursor": state.get("resolution_cursor"),
		"interactive_counters": false,
		"new_resolution_input_allowed": false,
	}, "projection_fingerprint")


static func ai_observation(state: Dictionary, viewer_id: String) -> Dictionary:
	return _viewer_projection(
		state,
		viewer_id,
		[ASSET_AI_OBSERVATION_ID, BATCH_AI_OBSERVATION_ID]
	)


static func player_projection(state: Dictionary, viewer_id: String) -> Dictionary:
	return _viewer_projection(
		state,
		viewer_id,
		[ASSET_PLAYER_PROJECTION_ID, BATCH_PLAYER_PROJECTION_ID]
	)


static func privacy_contract() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"contract_id": PRIVACY_POLICY_ID,
		"public_fields": [
			"state_version",
			"ruleset_id",
			"balance_profile_id",
			"balance_profile_fingerprint",
			"batch_id",
			"window_status",
			"window_duration_ms",
			"submission_deadline_ms",
			"anonymous_queue",
			"resolution_cursor",
			"interactive_counters",
			"new_resolution_input_allowed",
		],
		"viewer_private_fields": [
			"own_assets",
			"own_remainders_milli",
			"own_reserved_totals",
			"own_local_queue",
			"own_frozen_gdp_milli",
			"own_projected_refresh",
		],
		"authority_secret_fields": [
			"submission_hidden_lead_order",
			"frozen_hidden_lead_order",
			"actor_id",
			"lineage_fingerprint",
			"lock_fingerprint",
			"other_exact_assets",
			"other_reservations",
			"other_local_queues",
			"save_payload",
		],
		"owner_specific_timing_audio_animation_allowed": false,
	}


static func contract_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"state_version": STATE_VERSION,
		"ruleset_id": RULESET_ID,
		"balance_profile_id": BALANCE_PROFILE_ID,
		"balance_profile_fingerprint": BALANCE_PROFILE_FINGERPRINT,
		"core_authority": [ASSET_CORE_AUTHORITY_ID, BATCH_CORE_AUTHORITY_ID],
		"ai_observation": [ASSET_AI_OBSERVATION_ID, BATCH_AI_OBSERVATION_ID],
		"player_projection": [ASSET_PLAYER_PROJECTION_ID, BATCH_PLAYER_PROJECTION_ID],
		"intent": [ASSET_INTENT_ID, BATCH_INTENT_ID],
		"authoritative_receipt": [ASSET_RECEIPT_ID, BATCH_RECEIPT_ID],
		"save_state": [ASSET_SAVE_STATE_ID, BATCH_SAVE_STATE_ID],
		"asset_domain": {
			"CoreAuthorityV3": ASSET_CORE_AUTHORITY_ID,
			"AiObservationV3": ASSET_AI_OBSERVATION_ID,
			"PlayerProjectionV3": ASSET_PLAYER_PROJECTION_ID,
			"IntentV3": ASSET_INTENT_ID,
			"AuthoritativeReceiptV3": ASSET_RECEIPT_ID,
			"SaveStateV3": ASSET_SAVE_STATE_ID,
		},
		"batch_domain": {
			"CoreAuthorityV3": BATCH_CORE_AUTHORITY_ID,
			"AiObservationV3": BATCH_AI_OBSERVATION_ID,
			"PlayerProjectionV3": BATCH_PLAYER_PROJECTION_ID,
			"IntentV3": BATCH_INTENT_ID,
			"AuthoritativeReceiptV3": BATCH_RECEIPT_ID,
			"SaveStateV3": BATCH_SAVE_STATE_ID,
		},
		"privacy_policy": PRIVACY_POLICY_ID,
		"state_contract_ids": [
			SIX_COLOR_ASSET_STATE_ID,
			ASSET_CYCLE_SNAPSHOT_ID,
			ASSET_RESERVATION_STATE_ID,
			CARD_BATCH_STATE_ID,
			PREBOUND_TARGET_STATE_ID,
			ANONYMOUS_RESOLUTION_STATE_ID,
		],
		"colors": COLORS.duplicate(),
		"per_color_cap": ASSET_CAP,
		"initial_assets_per_color": INITIAL_ASSETS_PER_COLOR,
		"initial_remainder_milli_per_color": (
			INITIAL_REMAINDER_MILLI_PER_COLOR
		),
		"asset_owner_created_at_genesis": true,
		"zero_deadlock_mechanism": ZERO_DEADLOCK_MECHANISM,
		"max_asset_refresh_per_color_per_batch": (
			MAX_ASSET_REFRESH_PER_COLOR_PER_BATCH
		),
		"invalid_target_policy_ids": INVALID_TARGET_POLICY_IDS.duplicate(),
		"default_invalid_target_policy_id": DEFAULT_INVALID_TARGET_POLICY_ID,
		"invalid_target_normal_card_destination": "discard",
		"invalid_target_action_slot_refunded": false,
		"invalid_target_public_history_reason_required": true,
		"window_duration_ms": WINDOW_DURATION_MS,
		"maximum_active_actions": MAX_ACTIONS_PER_PLAYER,
		"one_shot": true,
		"full_queue_atomic_reservation": true,
		"per_action_reservation": true,
		"future_refresh_can_pay_current_batch": false,
		"interactive_counters": false,
		"resolution_mode": "round_robin_by_local_action_index",
		"player_iteration_order": "frozen_hidden_lead_order",
	}


static func asset_core_authority(state: Dictionary) -> Dictionary:
	if not _state_error(state).is_empty():
		return {}
	var contract := _asset_authority_payload(state)
	contract["schema_version"] = SCHEMA_VERSION
	contract["contract_id"] = ASSET_CORE_AUTHORITY_ID
	return _seal(contract, "authority_fingerprint")


static func batch_core_authority(state: Dictionary) -> Dictionary:
	if not _state_error(state).is_empty():
		return {}
	var contract := _batch_authority_payload(state)
	contract["schema_version"] = SCHEMA_VERSION
	contract["contract_id"] = BATCH_CORE_AUTHORITY_ID
	return _seal(contract, "authority_fingerprint")


static func asset_ai_observation(state: Dictionary, viewer_id: String) -> Dictionary:
	return _asset_view_contract(state, viewer_id, ASSET_AI_OBSERVATION_ID)


static func asset_player_projection(state: Dictionary, viewer_id: String) -> Dictionary:
	return _asset_view_contract(state, viewer_id, ASSET_PLAYER_PROJECTION_ID)


static func batch_ai_observation(state: Dictionary, viewer_id: String) -> Dictionary:
	return _batch_view_contract(state, viewer_id, BATCH_AI_OBSERVATION_ID)


static func batch_player_projection(state: Dictionary, viewer_id: String) -> Dictionary:
	return _batch_view_contract(state, viewer_id, BATCH_PLAYER_PROJECTION_ID)


static func asset_intent_adapter(
	intent: Dictionary,
	expected_core_revision: int,
	asset_snapshot_revision: int
) -> Dictionary:
	if not _intent_error(intent).is_empty() \
			or not _nonnegative_integer(expected_core_revision) \
			or not _nonnegative_integer(asset_snapshot_revision):
		return {}
	var action_costs: Array = []
	var reservation_ids: Array[String] = []
	for action_variant in intent.get("actions") as Array:
		var action := action_variant as Dictionary
		var action_id := str(action.get("action_id", ""))
		action_costs.append({
			"action_id": action_id,
			"cost": (action.get("cost") as Dictionary).duplicate(true),
			"any_payment": (action.get("any_payment") as Dictionary).duplicate(true),
		})
		reservation_ids.append("reservation.%s" % action_id)
	return _seal({
		"schema_version": SCHEMA_VERSION,
		"state_version": STATE_VERSION,
		"ruleset_id": RULESET_ID,
		"balance_profile_id": BALANCE_PROFILE_ID,
		"balance_profile_fingerprint": BALANCE_PROFILE_FINGERPRINT,
		"default_invalid_target_policy_id": DEFAULT_INVALID_TARGET_POLICY_ID,
		"contract_id": ASSET_INTENT_ID,
		"intent_id": intent.get("intent_id"),
		"actor_id": intent.get("actor_id"),
		"expected_core_revision": expected_core_revision,
		"asset_snapshot_revision": asset_snapshot_revision,
		"action_costs": action_costs,
		"reservation_ids": reservation_ids,
	}, "intent_fingerprint")


static func batch_intent_adapter(
	intent: Dictionary,
	expected_core_revision: int
) -> Dictionary:
	if not _intent_error(intent).is_empty() \
			or not _nonnegative_integer(expected_core_revision):
		return {}
	var local_indices: Array[int] = []
	var source_ids: Array[String] = []
	var target_bindings: Array = []
	var reservation_ids: Array[String] = []
	for action_variant in intent.get("actions") as Array:
		var action := action_variant as Dictionary
		local_indices.append(int(action.get("local_order", -1)))
		source_ids.append(str(action.get("source_id", "")))
		target_bindings.append((action.get("target_binding") as Dictionary).duplicate(true))
		reservation_ids.append("reservation.%s" % str(action.get("action_id", "")))
	return _seal({
		"schema_version": SCHEMA_VERSION,
		"state_version": STATE_VERSION,
		"ruleset_id": RULESET_ID,
		"balance_profile_id": BALANCE_PROFILE_ID,
		"balance_profile_fingerprint": BALANCE_PROFILE_FINGERPRINT,
		"default_invalid_target_policy_id": DEFAULT_INVALID_TARGET_POLICY_ID,
		"contract_id": BATCH_INTENT_ID,
		"intent_id": intent.get("intent_id"),
		"actor_id_or_authoritative_system": intent.get("actor_id"),
		"expected_core_revision": expected_core_revision,
		"window_id": intent.get("batch_id"),
		"local_action_index": local_indices,
		"source_instance_id": source_ids,
		"prebound_target_identity": target_bindings,
		"reservation_id": reservation_ids,
	}, "intent_fingerprint")


static func asset_receipt_adapter(
	internal_receipt: Dictionary,
	intent: Dictionary,
	state_before: Dictionary,
	state_after: Dictionary
) -> Dictionary:
	if not _receipt_error(internal_receipt).is_empty() \
			or not _intent_error(intent).is_empty() \
			or not _state_error(state_before).is_empty() \
			or not _state_error(state_after).is_empty():
		return {}
	if not _receipt_adapter_transition_error(
		internal_receipt,
		intent,
		state_before,
		state_after
	).is_empty():
		return {}
	var actor_id := str(intent.get("actor_id", ""))
	if not (state_before.get("player_ids") as Array).has(actor_id) \
			or not (state_after.get("player_ids") as Array).has(actor_id):
		return {}
	var before_assets := ((state_before.get("players") as Dictionary).get(actor_id) as Dictionary).get("assets") as Dictionary
	var after_assets := ((state_after.get("players") as Dictionary).get(actor_id) as Dictionary).get("assets") as Dictionary
	var delta := _zero_color_map()
	for color in COLORS:
		delta[color] = int(after_assets.get(color, 0)) - int(before_assets.get(color, 0))
	var reservation_ids: Array[String] = []
	for action_variant in intent.get("actions") as Array:
		reservation_ids.append(
			"reservation.%s" % str((action_variant as Dictionary).get("action_id", ""))
		)
	return _seal({
		"schema_version": SCHEMA_VERSION,
		"state_version": STATE_VERSION,
		"ruleset_id": RULESET_ID,
		"balance_profile_id": BALANCE_PROFILE_ID,
		"balance_profile_fingerprint": BALANCE_PROFILE_FINGERPRINT,
		"default_invalid_target_policy_id": DEFAULT_INVALID_TARGET_POLICY_ID,
		"contract_id": ASSET_RECEIPT_ID,
		"receipt_id": internal_receipt.get("receipt_id"),
		"intent_id": intent.get("intent_id"),
		"accepted": internal_receipt.get("accepted"),
		"reason_code": internal_receipt.get("reason_code"),
		"committed_core_revision": state_after.get("revision"),
		"reservation_ids": reservation_ids,
		"asset_delta_by_color": delta,
	}, "receipt_fingerprint")


static func batch_receipt_adapter(
	internal_receipt: Dictionary,
	intent: Dictionary,
	state_before: Dictionary,
	state_after: Dictionary
) -> Dictionary:
	if not _receipt_error(internal_receipt).is_empty() \
			or not _intent_error(intent).is_empty() \
			or not _state_error(state_before).is_empty() \
			or not _state_error(state_after).is_empty():
		return {}
	if not _receipt_adapter_transition_error(
		internal_receipt,
		intent,
		state_before,
		state_after
	).is_empty():
		return {}
	var anonymous_action_id := str(internal_receipt.get("action_id", ""))
	if anonymous_action_id.is_empty() and not (intent.get("actions") as Array).is_empty():
		anonymous_action_id = str(((intent.get("actions") as Array)[0] as Dictionary).get("action_id", ""))
	if anonymous_action_id.is_empty():
		anonymous_action_id = "none"
	return _seal({
		"schema_version": SCHEMA_VERSION,
		"state_version": STATE_VERSION,
		"ruleset_id": RULESET_ID,
		"balance_profile_id": BALANCE_PROFILE_ID,
		"balance_profile_fingerprint": BALANCE_PROFILE_FINGERPRINT,
		"default_invalid_target_policy_id": DEFAULT_INVALID_TARGET_POLICY_ID,
		"contract_id": BATCH_RECEIPT_ID,
		"receipt_id": internal_receipt.get("receipt_id"),
		"intent_id": intent.get("intent_id"),
		"accepted": internal_receipt.get("accepted"),
		"reason_code": internal_receipt.get("reason_code"),
		"committed_core_revision": state_after.get("revision"),
		"window_id": state_after.get("batch_id"),
		"anonymous_action_id": anonymous_action_id,
		"resolution_status": (state_after.get("window") as Dictionary).get("status"),
	}, "receipt_fingerprint")


static func to_asset_save_state(state: Dictionary) -> Dictionary:
	if not _state_error(state).is_empty():
		return {}
	var save := _asset_authority_payload(state)
	save["schema_version"] = SCHEMA_VERSION
	save["contract_id"] = ASSET_SAVE_STATE_ID
	save["section_id"] = "six_color_assets_and_reservations"
	save["ruleset_id"] = RULESET_ID
	save["shared_batch_id"] = state.get("batch_id")
	save["shared_lineage_fingerprint"] = state.get("lineage_fingerprint")
	save["shared_authority_state"] = state.duplicate(true)
	return _seal(save, "save_fingerprint")


static func to_batch_save_state(state: Dictionary) -> Dictionary:
	if not _state_error(state).is_empty():
		return {}
	var save := _batch_authority_payload(state)
	save["schema_version"] = SCHEMA_VERSION
	save["contract_id"] = BATCH_SAVE_STATE_ID
	save["section_id"] = "card_batch_and_anonymous_resolution"
	save["ruleset_id"] = RULESET_ID
	save["shared_batch_id"] = state.get("batch_id")
	save["shared_lineage_fingerprint"] = state.get("lineage_fingerprint")
	save["shared_authority_state"] = state.duplicate(true)
	return _seal(save, "save_fingerprint")


static func domain_contract_validation_report(
	value: Variant,
	contract_id: String
) -> Dictionary:
	var spec := _domain_contract_spec(contract_id)
	if spec.is_empty() or not (value is Dictionary) or not _is_pure_data(value):
		return {"valid": false, "reason_code": "domain_contract_not_pure_or_unknown"}
	var contract := value as Dictionary
	if not _exact_fields(contract, spec.get("fields") as Array):
		return {"valid": false, "reason_code": "domain_contract_fields_invalid"}
	if contract.get("schema_version") != SCHEMA_VERSION \
			or str(contract.get("contract_id", "")) != contract_id:
		return {"valid": false, "reason_code": "domain_contract_identity_invalid"}
	var context_error := _domain_contract_context_error(contract)
	if not context_error.is_empty():
		return {"valid": false, "reason_code": context_error}
	var fingerprint_field := str(spec.get("fingerprint_field", ""))
	var unsealed := contract.duplicate(true)
	unsealed.erase(fingerprint_field)
	if not _fingerprint_valid(contract.get(fingerprint_field)) \
			or str(contract.get(fingerprint_field, "")) != _fingerprint(unsealed):
		return {"valid": false, "reason_code": "domain_contract_fingerprint_invalid"}
	var semantic_error := _domain_contract_semantic_error(contract, contract_id)
	if not semantic_error.is_empty():
		return {"valid": false, "reason_code": semantic_error}
	return {"valid": true, "reason_code": "none"}


static func restore_domain_save_state(
	save_state: Dictionary,
	expected_contract_id: String
) -> Dictionary:
	if not [ASSET_SAVE_STATE_ID, BATCH_SAVE_STATE_ID].has(expected_contract_id):
		return _domain_restore_failure("domain_save_contract_not_supported")
	var validation := domain_contract_validation_report(
		save_state,
		expected_contract_id
	)
	if not bool(validation.get("valid", false)):
		return _domain_restore_failure(str(validation.get(
			"reason_code",
			"domain_save_invalid"
		)))
	return {
		"restored": false,
		"preflight_valid": true,
		"reason_code": "domain_save_preflight_green",
		"contract_id": expected_contract_id,
		"state": {},
	}


static func restore_domain_save_pair(
	asset_save_state: Dictionary,
	batch_save_state: Dictionary
) -> Dictionary:
	var asset_preflight := restore_domain_save_state(
		asset_save_state,
		ASSET_SAVE_STATE_ID
	)
	if not bool(asset_preflight.get("preflight_valid", false)):
		return _domain_restore_failure(
			"asset_%s" % str(asset_preflight.get("reason_code", "domain_save_invalid"))
		)
	var batch_preflight := restore_domain_save_state(
		batch_save_state,
		BATCH_SAVE_STATE_ID
	)
	if not bool(batch_preflight.get("preflight_valid", false)):
		return _domain_restore_failure(
			"batch_%s" % str(batch_preflight.get("reason_code", "domain_save_invalid"))
		)
	if asset_save_state.get("shared_batch_id") \
			!= batch_save_state.get("shared_batch_id"):
		return _domain_restore_failure("domain_save_pair_batch_mismatch")
	if asset_save_state.get("shared_lineage_fingerprint") \
			!= batch_save_state.get("shared_lineage_fingerprint"):
		return _domain_restore_failure("domain_save_pair_lineage_mismatch")
	var asset_state := asset_save_state.get("shared_authority_state") as Dictionary
	var batch_state := batch_save_state.get("shared_authority_state") as Dictionary
	if asset_state != batch_state:
		return _domain_restore_failure("domain_save_pair_shared_state_mismatch")
	return {
		"restored": true,
		"reason_code": "domain_save_pair_restored",
		"contract_ids": [ASSET_SAVE_STATE_ID, BATCH_SAVE_STATE_ID],
		"state": asset_state.duplicate(true),
	}


static func to_save_state(state: Dictionary) -> Dictionary:
	if not _state_error(state).is_empty():
		return {}
	return _seal({
		"schema_version": SCHEMA_VERSION,
		"state_version": STATE_VERSION,
		"schema_id": INTERNAL_SAVE_STATE_ID,
		"ruleset_id": RULESET_ID,
		"balance_profile_id": BALANCE_PROFILE_ID,
		"balance_profile_fingerprint": BALANCE_PROFILE_FINGERPRINT,
		"default_invalid_target_policy_id": DEFAULT_INVALID_TARGET_POLICY_ID,
		"max_asset_refresh_per_color_per_batch": (
			MAX_ASSET_REFRESH_PER_COLOR_PER_BATCH
		),
		"state": state.duplicate(true),
	}, "save_fingerprint")


static func restore_save_state(save_state: Dictionary) -> Dictionary:
	var error := _saved_envelope_error(
		save_state,
		INTERNAL_SAVE_STATE_ID,
		"save_fingerprint"
	)
	if not error.is_empty():
		return {"restored": false, "reason_code": error, "state": {}}
	return {
		"restored": true,
		"reason_code": "save_state_restored",
		"state": (save_state.get("state") as Dictionary).duplicate(true),
	}


static func checkpoint(state: Dictionary) -> Dictionary:
	if not _state_error(state).is_empty():
		return {}
	return _seal({
		"schema_version": SCHEMA_VERSION,
		"state_version": STATE_VERSION,
		"schema_id": CHECKPOINT_ID,
		"ruleset_id": RULESET_ID,
		"balance_profile_id": BALANCE_PROFILE_ID,
		"balance_profile_fingerprint": BALANCE_PROFILE_FINGERPRINT,
		"default_invalid_target_policy_id": DEFAULT_INVALID_TARGET_POLICY_ID,
		"max_asset_refresh_per_color_per_batch": (
			MAX_ASSET_REFRESH_PER_COLOR_PER_BATCH
		),
		"state": state.duplicate(true),
	}, "checkpoint_fingerprint")


static func rollback(state: Dictionary, saved_checkpoint: Dictionary) -> Dictionary:
	if not _state_error(state).is_empty():
		return {"rolled_back": false, "reason_code": "state_invalid", "state": state.duplicate(true)}
	var error := _saved_envelope_error(
		saved_checkpoint,
		CHECKPOINT_ID,
		"checkpoint_fingerprint"
	)
	if not error.is_empty():
		return {"rolled_back": false, "reason_code": error, "state": state.duplicate(true)}
	var restored := saved_checkpoint.get("state") as Dictionary
	if str(restored.get("batch_id", "")) != str(state.get("batch_id", "")):
		return {
			"rolled_back": false,
			"reason_code": "checkpoint_batch_binding_invalid",
			"state": state.duplicate(true),
		}
	if str(restored.get("lineage_fingerprint", "")) \
			!= str(state.get("lineage_fingerprint", "")):
		return {
			"rolled_back": false,
			"reason_code": "checkpoint_lineage_invalid",
			"state": state.duplicate(true),
		}
	if int(restored.get("revision", -1)) > int(state.get("revision", -1)):
		return {
			"rolled_back": false,
			"reason_code": "checkpoint_from_future",
			"state": state.duplicate(true),
		}
	var checkpoint_receipts := restored.get("receipts") as Array
	var current_receipts := state.get("receipts") as Array
	for index in range(checkpoint_receipts.size()):
		if index >= current_receipts.size() \
				or str((checkpoint_receipts[index] as Dictionary).get("receipt_fingerprint", "")) \
				!= str((current_receipts[index] as Dictionary).get("receipt_fingerprint", "")):
			return {
				"rolled_back": false,
				"reason_code": "checkpoint_not_current_lineage",
				"state": state.duplicate(true),
			}
	return {
		"rolled_back": true,
		"reason_code": "checkpoint_restored",
		"state": restored.duplicate(true),
		"receipt": _receipt(
			restored,
			"rollback",
			true,
			"checkpoint_restored",
			"",
			"",
			"rolled_back"
		),
	}


static func validation_report(state: Variant) -> Dictionary:
	var reason_code := _state_error(state)
	return {
		"valid": reason_code.is_empty(),
		"reason_code": "none" if reason_code.is_empty() else reason_code,
	}


static func is_pure_data(value: Variant) -> bool:
	return _is_pure_data(value)


static func _asset_authority_payload(state: Dictionary) -> Dictionary:
	var assets_by_player := {}
	var remainders_by_player := {}
	var snapshots_by_player := {}
	var reservations_by_player := {}
	var journal_by_player := {}
	for player_id_variant in state.get("player_ids") as Array:
		var player_id := str(player_id_variant)
		var player := (state.get("players") as Dictionary).get(player_id) as Dictionary
		assets_by_player[player_id] = (player.get("assets") as Dictionary).duplicate(true)
		remainders_by_player[player_id] = (player.get("remainders_milli") as Dictionary).duplicate(true)
		snapshots_by_player[player_id] = (player.get("frozen_gdp_milli") as Dictionary).duplicate(true)
		reservations_by_player[player_id] = (player.get("reservations") as Dictionary).duplicate(true)
		journal_by_player[player_id] = (player.get("action_results") as Dictionary).duplicate(true)
	return {
		"state_version": STATE_VERSION,
		"ruleset_id": RULESET_ID,
		"balance_profile_id": BALANCE_PROFILE_ID,
		"balance_profile_fingerprint": BALANCE_PROFILE_FINGERPRINT,
		"default_invalid_target_policy_id": DEFAULT_INVALID_TARGET_POLICY_ID,
		"max_asset_refresh_per_color_per_batch": (
			MAX_ASSET_REFRESH_PER_COLOR_PER_BATCH
		),
		"state_revision": state.get("revision"),
		"per_player_assets_by_color": assets_by_player,
		"per_player_fixed_point_remainders": remainders_by_player,
		"gdp_cycle_snapshot": snapshots_by_player,
		"per_action_reservations": reservations_by_player,
		"reservation_journal": journal_by_player,
		"asset_refresh_revision": state.get("revision") \
			if bool(state.get("refresh_applied", false)) else 0,
	}


static func _batch_authority_payload(state: Dictionary) -> Dictionary:
	var window_state := (state.get("window") as Dictionary).duplicate(true)
	window_state["submission_hidden_lead_order"] = (
		state.get("submission_hidden_lead_order") as Array
	).duplicate()
	window_state["frozen_hidden_lead_order"] = (
		state.get("frozen_hidden_lead_order") as Array
	).duplicate()
	var local_queues := {}
	var targets := {}
	var owner_bindings := {}
	var journal := {}
	for player_id_variant in state.get("player_ids") as Array:
		var player_id := str(player_id_variant)
		var player := (state.get("players") as Dictionary).get(player_id) as Dictionary
		local_queues[player_id] = (player.get("local_queue") as Array).duplicate(true)
		journal[player_id] = (player.get("action_results") as Dictionary).duplicate(true)
		for action_variant in player.get("local_queue") as Array:
			var action := action_variant as Dictionary
			var action_id := str(action.get("action_id", ""))
			targets[action_id] = (action.get("target_binding") as Dictionary).duplicate(true)
			owner_bindings[action_id] = player_id
	var anonymous_queue: Array = []
	for entry_variant in state.get("authority_queue") as Array:
		anonymous_queue.append(((entry_variant as Dictionary).get("public") as Dictionary).duplicate(true))
	return {
		"state_version": STATE_VERSION,
		"ruleset_id": RULESET_ID,
		"balance_profile_id": BALANCE_PROFILE_ID,
		"balance_profile_fingerprint": BALANCE_PROFILE_FINGERPRINT,
		"default_invalid_target_policy_id": DEFAULT_INVALID_TARGET_POLICY_ID,
		"state_revision": state.get("revision"),
		"submission_window_state": window_state,
		"player_local_queues": local_queues,
		"prebound_targets": targets,
		"private_owner_bindings": owner_bindings,
		"anonymous_global_queue": anonymous_queue,
		"round_robin_cursor": state.get("resolution_cursor"),
		"resolution_journal": journal,
		"processed_intent_ids": (state.get("seen_intent_ids") as Array).duplicate(),
		"intent_receipt_ledger": (
			state.get("intent_receipt_ledger") as Dictionary
		).duplicate(true),
	}


static func _asset_view_contract(
	state: Dictionary,
	viewer_id: String,
	contract_id: String
) -> Dictionary:
	if not _state_error(state).is_empty() \
			or not (state.get("player_ids") as Array).has(viewer_id):
		return {}
	var player := (state.get("players") as Dictionary).get(viewer_id) as Dictionary
	var available := _zero_color_map()
	for color in COLORS:
		available[color] = int((player.get("assets") as Dictionary).get(color, 0)) \
			- int((player.get("reserved_totals") as Dictionary).get(color, 0))
	var public_costs: Array = []
	for action_variant in player.get("local_queue") as Array:
		var action := action_variant as Dictionary
		public_costs.append({
			"action_id": action.get("action_id"),
			"cost": (action.get("cost") as Dictionary).duplicate(true),
			"any_payment": (action.get("any_payment") as Dictionary).duplicate(true),
		})
	return _seal({
		"schema_version": SCHEMA_VERSION,
		"state_version": STATE_VERSION,
		"ruleset_id": RULESET_ID,
		"balance_profile_id": BALANCE_PROFILE_ID,
		"balance_profile_fingerprint": BALANCE_PROFILE_FINGERPRINT,
		"default_invalid_target_policy_id": DEFAULT_INVALID_TARGET_POLICY_ID,
		"max_asset_refresh_per_color_per_batch": (
			MAX_ASSET_REFRESH_PER_COLOR_PER_BATCH
		),
		"contract_id": contract_id,
		"viewer_id": viewer_id,
		"state_revision": state.get("revision"),
		"own_exact_assets": (player.get("assets") as Dictionary).duplicate(true),
		"own_remainders": (player.get("remainders_milli") as Dictionary).duplicate(true),
		"own_reservations": (player.get("reservations") as Dictionary).duplicate(true),
		"own_available_assets": available,
		"own_projected_refresh": _projected_refresh_after_success(state, player),
		"public_costs": public_costs,
	}, "projection_fingerprint")


static func _batch_view_contract(
	state: Dictionary,
	viewer_id: String,
	contract_id: String
) -> Dictionary:
	if not _state_error(state).is_empty() \
			or not (state.get("player_ids") as Array).has(viewer_id):
		return {}
	var player := (state.get("players") as Dictionary).get(viewer_id) as Dictionary
	var own_queue: Array = []
	var own_targets := {}
	for action_variant in player.get("local_queue") as Array:
		var action := (action_variant as Dictionary).duplicate(true)
		action.erase("lock_fingerprint")
		own_queue.append(action)
		own_targets[str(action.get("action_id", ""))] = (
			action.get("target_binding") as Dictionary
		).duplicate(true)
	var anonymous_queue: Array = []
	var aftermath: Array = []
	for entry_variant in state.get("authority_queue") as Array:
		var public_entry := ((entry_variant as Dictionary).get("public") as Dictionary).duplicate(true)
		anonymous_queue.append(public_entry)
		if str(public_entry.get("result", "")) != "pending":
			aftermath.append(public_entry.duplicate(true))
	return _seal({
		"schema_version": SCHEMA_VERSION,
		"state_version": STATE_VERSION,
		"ruleset_id": RULESET_ID,
		"balance_profile_id": BALANCE_PROFILE_ID,
		"balance_profile_fingerprint": BALANCE_PROFILE_FINGERPRINT,
		"default_invalid_target_policy_id": DEFAULT_INVALID_TARGET_POLICY_ID,
		"contract_id": contract_id,
		"viewer_id": viewer_id,
		"state_revision": state.get("revision"),
		"own_local_queue": own_queue,
		"own_prebound_targets": own_targets,
		"own_reserved_costs": (player.get("reservations") as Dictionary).duplicate(true),
		"anonymous_public_queue": anonymous_queue,
		"public_resolution_aftermath": aftermath,
	}, "projection_fingerprint")


static func _projected_refresh_after_success(
	state: Dictionary,
	player: Dictionary
) -> Dictionary:
	var result := _zero_color_map()
	var conversion := int(state.get("gdp_milli_per_asset", DEFAULT_GDP_MILLI_PER_ASSET))
	for color in COLORS:
		var after_success := int((player.get("assets") as Dictionary).get(color, 0)) \
			- int((player.get("reserved_totals") as Dictionary).get(color, 0))
		var accrued := int((player.get("remainders_milli") as Dictionary).get(color, 0)) \
			+ int((player.get("frozen_gdp_milli") as Dictionary).get(color, 0))
		var earned_units := mini(
			accrued / conversion,
			int(state.get(
				"max_asset_refresh_per_color_per_batch",
				MAX_ASSET_REFRESH_PER_COLOR_PER_BATCH
			))
		)
		result[color] = mini(ASSET_CAP, after_success + earned_units)
	return result


static func _domain_contract_spec(contract_id: String) -> Dictionary:
	match contract_id:
		ASSET_CORE_AUTHORITY_ID:
			return {"fields": ASSET_CORE_CONTRACT_FIELDS, "fingerprint_field": "authority_fingerprint"}
		ASSET_AI_OBSERVATION_ID, ASSET_PLAYER_PROJECTION_ID:
			return {"fields": ASSET_VIEW_CONTRACT_FIELDS, "fingerprint_field": "projection_fingerprint"}
		ASSET_INTENT_ID:
			return {"fields": ASSET_INTENT_CONTRACT_FIELDS, "fingerprint_field": "intent_fingerprint"}
		ASSET_RECEIPT_ID:
			return {"fields": ASSET_RECEIPT_CONTRACT_FIELDS, "fingerprint_field": "receipt_fingerprint"}
		ASSET_SAVE_STATE_ID:
			return {"fields": ASSET_SAVE_CONTRACT_FIELDS, "fingerprint_field": "save_fingerprint"}
		BATCH_CORE_AUTHORITY_ID:
			return {"fields": BATCH_CORE_CONTRACT_FIELDS, "fingerprint_field": "authority_fingerprint"}
		BATCH_AI_OBSERVATION_ID, BATCH_PLAYER_PROJECTION_ID:
			return {"fields": BATCH_VIEW_CONTRACT_FIELDS, "fingerprint_field": "projection_fingerprint"}
		BATCH_INTENT_ID:
			return {"fields": BATCH_INTENT_CONTRACT_FIELDS, "fingerprint_field": "intent_fingerprint"}
		BATCH_RECEIPT_ID:
			return {"fields": BATCH_RECEIPT_CONTRACT_FIELDS, "fingerprint_field": "receipt_fingerprint"}
		BATCH_SAVE_STATE_ID:
			return {"fields": BATCH_SAVE_CONTRACT_FIELDS, "fingerprint_field": "save_fingerprint"}
	return {}


static func _domain_contract_context_error(contract: Dictionary) -> String:
	if contract.get("state_version") != STATE_VERSION \
			or str(contract.get("ruleset_id", "")) != RULESET_ID \
			or str(contract.get("balance_profile_id", "")) != BALANCE_PROFILE_ID \
			or str(contract.get("balance_profile_fingerprint", "")) \
				!= BALANCE_PROFILE_FINGERPRINT \
			or str(contract.get("default_invalid_target_policy_id", "")) \
				!= DEFAULT_INVALID_TARGET_POLICY_ID:
		return "domain_contract_v072_context_invalid"
	if contract.has("max_asset_refresh_per_color_per_batch") \
			and contract.get("max_asset_refresh_per_color_per_batch") \
				!= MAX_ASSET_REFRESH_PER_COLOR_PER_BATCH:
		return "domain_contract_balance_profile_invalid"
	return ""


static func _domain_contract_semantic_error(
	contract: Dictionary,
	contract_id: String
) -> String:
	match contract_id:
		ASSET_CORE_AUTHORITY_ID:
			return _asset_authority_payload_error(contract)
		ASSET_AI_OBSERVATION_ID, ASSET_PLAYER_PROJECTION_ID:
			return _asset_view_contract_error(contract)
		ASSET_INTENT_ID:
			return _asset_intent_contract_error(contract)
		ASSET_RECEIPT_ID:
			return _asset_receipt_contract_error(contract)
		ASSET_SAVE_STATE_ID, BATCH_SAVE_STATE_ID:
			return _domain_save_contract_error(contract, contract_id)
		BATCH_CORE_AUTHORITY_ID:
			return _batch_authority_payload_error(contract)
		BATCH_AI_OBSERVATION_ID, BATCH_PLAYER_PROJECTION_ID:
			return _batch_view_contract_error(contract)
		BATCH_INTENT_ID:
			return _batch_intent_contract_error(contract)
		BATCH_RECEIPT_ID:
			return _batch_receipt_contract_error(contract)
	return "domain_contract_semantics_unknown"


static func _asset_authority_payload_error(contract: Dictionary) -> String:
	if not _nonnegative_integer(contract.get("state_revision")) \
			or not _nonnegative_integer(contract.get("asset_refresh_revision")) \
			or int(contract.get("asset_refresh_revision", -1)) \
			> int(contract.get("state_revision", -1)):
		return "asset_contract_revision_invalid"
	for field in [
		"per_player_assets_by_color",
		"per_player_fixed_point_remainders",
		"gdp_cycle_snapshot",
		"per_action_reservations",
		"reservation_journal",
	]:
		if not (contract.get(field) is Dictionary):
			return "asset_contract_nested_type_invalid"
	var assets_by_player := contract.get("per_player_assets_by_color") as Dictionary
	var player_ids := _stable_dictionary_ids(assets_by_player, false)
	if player_ids.is_empty():
		return "asset_contract_player_ids_invalid"
	var remainders := contract.get("per_player_fixed_point_remainders") as Dictionary
	var snapshots := contract.get("gdp_cycle_snapshot") as Dictionary
	var reservations := contract.get("per_action_reservations") as Dictionary
	var journal := contract.get("reservation_journal") as Dictionary
	for player_map in [remainders, snapshots, reservations, journal]:
		if not _exact_keys(player_map as Dictionary, player_ids):
			return "asset_contract_player_partition_invalid"
	var global_action_ids: Array[String] = []
	for player_id in player_ids:
		var player_assets: Variant = assets_by_player.get(player_id)
		var player_remainders: Variant = remainders.get(player_id)
		var player_snapshot: Variant = snapshots.get(player_id)
		if not _color_map_valid(player_assets, 0, ASSET_CAP):
			return "asset_contract_balance_invalid"
		if not _color_map_valid(player_remainders, 0, MAX_SAFE_INTEGER):
			return "asset_contract_remainder_invalid"
		if not _color_map_valid(player_snapshot, 0, MAX_SAFE_INTEGER):
			return "asset_contract_gdp_snapshot_invalid"
		if not (reservations.get(player_id) is Dictionary) \
				or not (journal.get(player_id) is Dictionary):
			return "asset_contract_reservation_partition_invalid"
		var player_reservations := reservations.get(player_id) as Dictionary
		var player_journal := journal.get(player_id) as Dictionary
		var reserved_totals := _zero_color_map()
		for action_id_variant in player_reservations.keys():
			var action_id := str(action_id_variant)
			if not _stable_id(action_id_variant) or global_action_ids.has(action_id):
				return "asset_contract_reservation_identity_invalid"
			var reservation: Variant = player_reservations.get(action_id_variant)
			if not _color_map_valid(reservation, 0, ASSET_CAP * 2):
				return "asset_contract_reservation_value_invalid"
			for color in COLORS:
				reserved_totals[color] = int(reserved_totals.get(color, 0)) \
					+ int((reservation as Dictionary).get(color, 0))
			global_action_ids.append(action_id)
		for color in COLORS:
			if int(reserved_totals.get(color, 0)) \
					> int((player_assets as Dictionary).get(color, 0)):
				return "asset_contract_reservation_exceeds_balance"
		for action_id_variant in player_journal.keys():
			var action_id := str(action_id_variant)
			if not _stable_id(action_id_variant) \
					or player_reservations.has(action_id_variant) \
					or global_action_ids.has(action_id) \
					or not _action_result_error(
						player_journal.get(action_id_variant)
					).is_empty():
				return "asset_contract_reservation_journal_inconsistent"
			global_action_ids.append(action_id)
	return ""


static func _asset_view_contract_error(contract: Dictionary) -> String:
	if not _stable_id(contract.get("viewer_id")) \
			or not _nonnegative_integer(contract.get("state_revision")):
		return "asset_view_identity_invalid"
	if not _color_map_valid(contract.get("own_exact_assets"), 0, ASSET_CAP) \
			or not _color_map_valid(contract.get("own_remainders"), 0, MAX_SAFE_INTEGER) \
			or not _color_map_valid(contract.get("own_available_assets"), 0, ASSET_CAP) \
			or not _color_map_valid(contract.get("own_projected_refresh"), 0, ASSET_CAP):
		return "asset_view_color_state_invalid"
	if not (contract.get("own_reservations") is Dictionary) \
			or not (contract.get("public_costs") is Array):
		return "asset_view_nested_type_invalid"
	var reservations := contract.get("own_reservations") as Dictionary
	var costs_by_action := {}
	for cost_variant in contract.get("public_costs") as Array:
		if not (cost_variant is Dictionary):
			return "asset_view_cost_invalid"
		var cost_record := cost_variant as Dictionary
		if not _exact_fields(cost_record, ["action_id", "cost", "any_payment"]) \
				or not _stable_id(cost_record.get("action_id")) \
				or costs_by_action.has(str(cost_record.get("action_id", ""))) \
				or not _authored_cost_valid(
					cost_record.get("cost"),
					cost_record.get("any_payment")
				):
			return "asset_view_cost_invalid"
		costs_by_action[str(cost_record.get("action_id", ""))] = cost_record
	var totals := _zero_color_map()
	for action_id_variant in reservations.keys():
		var action_id := str(action_id_variant)
		var reservation: Variant = reservations.get(action_id_variant)
		if not _stable_id(action_id_variant) or not costs_by_action.has(action_id) \
				or not _color_map_valid(reservation, 0, ASSET_CAP * 2) \
				or reservation != _reservation_from_cost_record(
					costs_by_action.get(action_id) as Dictionary
				):
			return "asset_view_reservation_invalid"
		for color in COLORS:
			totals[color] = int(totals.get(color, 0)) \
				+ int((reservation as Dictionary).get(color, 0))
	var assets := contract.get("own_exact_assets") as Dictionary
	var available := contract.get("own_available_assets") as Dictionary
	for color in COLORS:
		if int(available.get(color, -1)) \
				!= int(assets.get(color, 0)) - int(totals.get(color, 0)):
			return "asset_view_available_balance_inconsistent"
	return ""


static func _asset_intent_contract_error(contract: Dictionary) -> String:
	if not _stable_id(contract.get("intent_id")) \
			or not _stable_id(contract.get("actor_id")) \
			or not _nonnegative_integer(contract.get("expected_core_revision")) \
			or not _nonnegative_integer(contract.get("asset_snapshot_revision")) \
			or not (contract.get("action_costs") is Array) \
			or not (contract.get("reservation_ids") is Array):
		return "asset_intent_binding_invalid"
	var action_costs := contract.get("action_costs") as Array
	var reservation_ids := contract.get("reservation_ids") as Array
	if action_costs.size() != reservation_ids.size() \
			or action_costs.size() > MAX_ACTIONS_PER_PLAYER:
		return "asset_intent_action_count_invalid"
	var action_ids: Array[String] = []
	for index in range(action_costs.size()):
		var cost_variant: Variant = action_costs[index]
		if not (cost_variant is Dictionary):
			return "asset_intent_cost_invalid"
		var cost_record := cost_variant as Dictionary
		var action_id := str(cost_record.get("action_id", ""))
		if not _exact_fields(cost_record, ["action_id", "cost", "any_payment"]) \
				or not _stable_id(cost_record.get("action_id")) \
				or action_ids.has(action_id) \
				or not _authored_cost_valid(
					cost_record.get("cost"),
					cost_record.get("any_payment")
				) \
				or str(reservation_ids[index]) != "reservation.%s" % action_id:
			return "asset_intent_cost_invalid"
		action_ids.append(action_id)
	return ""


static func _asset_receipt_contract_error(contract: Dictionary) -> String:
	if not _stable_id(contract.get("receipt_id")) \
			or not _stable_id(contract.get("intent_id")) \
			or not (contract.get("accepted") is bool) \
			or not _stable_id(contract.get("reason_code")) \
			or not _nonnegative_integer(contract.get("committed_core_revision")) \
			or not (contract.get("reservation_ids") is Array) \
			or not _color_map_valid(contract.get("asset_delta_by_color"), -ASSET_CAP, ASSET_CAP):
		return "asset_receipt_semantics_invalid"
	var reservation_ids := _string_id_array(contract.get("reservation_ids"), true)
	if reservation_ids.size() != (contract.get("reservation_ids") as Array).size():
		return "asset_receipt_reservation_ids_invalid"
	return ""


static func _batch_authority_payload_error(contract: Dictionary) -> String:
	if not _nonnegative_integer(contract.get("state_revision")) \
			or not (contract.get("submission_window_state") is Dictionary) \
			or not (contract.get("player_local_queues") is Dictionary) \
			or not (contract.get("prebound_targets") is Dictionary) \
			or not (contract.get("private_owner_bindings") is Dictionary) \
			or not (contract.get("anonymous_global_queue") is Array) \
			or not _nonnegative_integer(contract.get("round_robin_cursor")) \
			or not (contract.get("resolution_journal") is Dictionary) \
			or not (contract.get("processed_intent_ids") is Array) \
			or not (contract.get("intent_receipt_ledger") is Dictionary):
		return "batch_contract_nested_type_invalid"
	var local_queues := contract.get("player_local_queues") as Dictionary
	var player_ids := _stable_dictionary_ids(local_queues, false)
	if player_ids.is_empty():
		return "batch_contract_player_ids_invalid"
	var window := contract.get("submission_window_state") as Dictionary
	var extended_window_fields := WINDOW_FIELDS + [
		"submission_hidden_lead_order",
		"frozen_hidden_lead_order",
	]
	if not _exact_fields(window, extended_window_fields):
		return "batch_contract_window_fields_invalid"
	if not (window.get("submission_hidden_lead_order") is Array) \
			or not (window.get("frozen_hidden_lead_order") is Array):
		return "batch_contract_hidden_order_type_invalid"
	var base_window := window.duplicate(true)
	base_window.erase("submission_hidden_lead_order")
	base_window.erase("frozen_hidden_lead_order")
	if not _window_error(base_window, player_ids.size()).is_empty():
		return "batch_contract_window_invalid"
	var submission_order := _string_id_array(
		window.get("submission_hidden_lead_order"),
		false
	)
	var frozen_order := _string_id_array(
		window.get("frozen_hidden_lead_order"),
		true
	)
	if submission_order.size() != (window.get("submission_hidden_lead_order") as Array).size() \
			or not _same_string_set(submission_order, player_ids) \
			or frozen_order.size() != (window.get("frozen_hidden_lead_order") as Array).size() \
			or (not frozen_order.is_empty() and not _same_string_set(frozen_order, player_ids)):
		return "batch_contract_hidden_order_invalid"
	var targets := contract.get("prebound_targets") as Dictionary
	var owners := contract.get("private_owner_bindings") as Dictionary
	var journals := contract.get("resolution_journal") as Dictionary
	if not _exact_keys(journals, player_ids):
		return "batch_contract_journal_partition_invalid"
	var action_ids: Array[String] = []
	var actions_by_id := {}
	for player_id in player_ids:
		var queue_variant: Variant = local_queues.get(player_id)
		var journal_variant: Variant = journals.get(player_id)
		if not (queue_variant is Array) or not (journal_variant is Dictionary):
			return "batch_contract_player_queue_invalid"
		var queue := queue_variant as Array
		var sorted := _sorted_actions(queue)
		if sorted.size() != queue.size():
			return "batch_contract_player_queue_invalid"
		for action_variant in queue:
			var action := action_variant as Dictionary
			var action_id := str(action.get("action_id", ""))
			if action_ids.has(action_id):
				return "batch_contract_action_identity_invalid"
			action_ids.append(action_id)
			actions_by_id[action_id] = {
				"owner": player_id,
				"action": action,
			}
		for action_id_variant in (journal_variant as Dictionary).keys():
			var journal_action_id := str(action_id_variant)
			var action_record := actions_by_id.get(journal_action_id, {}) as Dictionary
			if not action_ids.has(journal_action_id) \
					or action_record.is_empty() \
					or not _action_result_error(
						(journal_variant as Dictionary).get(action_id_variant),
						action_record.get("action") as Dictionary
					).is_empty():
				return "batch_contract_journal_invalid"
	if not _exact_keys(targets, action_ids) or not _exact_keys(owners, action_ids):
		return "batch_contract_action_binding_set_invalid"
	for action_id in action_ids:
		var action_record := actions_by_id.get(action_id) as Dictionary
		var action := action_record.get("action") as Dictionary
		if targets.get(action_id) != action.get("target_binding") \
				or owners.get(action_id) != action_record.get("owner"):
			return "batch_contract_action_binding_invalid"
	var expected_public: Array = []
	if not frozen_order.is_empty():
		for local_order in range(MAX_ACTIONS_PER_PLAYER):
			for player_id in frozen_order:
				var queue := local_queues.get(player_id) as Array
				if local_order >= queue.size():
					continue
				var action := queue[local_order] as Dictionary
				var action_id := str(action.get("action_id", ""))
				var player_journal := journals.get(player_id) as Dictionary
				var result_record := player_journal.get(action_id, {}) as Dictionary
				expected_public.append(_public_entry_for_action(action, result_record))
	var anonymous_queue := contract.get("anonymous_global_queue") as Array
	if anonymous_queue != expected_public:
		return "batch_contract_anonymous_queue_invalid"
	var cursor := int(contract.get("round_robin_cursor", -1))
	if cursor > anonymous_queue.size():
		return "batch_contract_cursor_invalid"
	for index in range(anonymous_queue.size()):
		var result := str((anonymous_queue[index] as Dictionary).get("result", ""))
		if (index < cursor and result == "pending") \
				or (index >= cursor and result != "pending"):
			return "batch_contract_cursor_journal_inconsistent"
	var status := str(window.get("status", ""))
	if status == "submission_open":
		if not frozen_order.is_empty() or not anonymous_queue.is_empty() or cursor != 0:
			return "batch_contract_submission_state_inconsistent"
	elif frozen_order.is_empty():
		return "batch_contract_frozen_order_missing"
	if status == "resolution_ready" and (anonymous_queue.is_empty() or cursor != 0):
		return "batch_contract_resolution_ready_invalid"
	if status == "resolving" and (cursor <= 0 or cursor >= anonymous_queue.size()):
		return "batch_contract_resolving_invalid"
	if ["batch_resolved", "assets_refreshed"].has(status) \
			and not anonymous_queue.is_empty() and cursor != anonymous_queue.size():
		return "batch_contract_resolved_invalid"
	var processed := _string_id_array(contract.get("processed_intent_ids"), true)
	if processed.size() != (contract.get("processed_intent_ids") as Array).size():
		return "batch_contract_processed_intents_invalid"
	var intent_ledger := contract.get("intent_receipt_ledger") as Dictionary
	if not _exact_keys(intent_ledger, processed):
		return "batch_contract_intent_receipt_ledger_set_invalid"
	for intent_id in processed:
		var entry_variant: Variant = intent_ledger.get(intent_id)
		if not (entry_variant is Dictionary):
			return "batch_contract_intent_receipt_ledger_entry_invalid"
		var entry := entry_variant as Dictionary
		if not _exact_fields(entry, INTENT_RECEIPT_LEDGER_ENTRY_FIELDS) \
				or entry.get("intent_id") != intent_id \
				or not _fingerprint_valid(entry.get("intent_fingerprint")) \
				or not _nonnegative_integer(entry.get("submitted_at_ms")) \
				or not _nonnegative_integer(entry.get("submitted_at_ms")) \
				or not _stable_id(entry.get("receipt_id")) \
				or not _fingerprint_valid(entry.get("receipt_fingerprint")) \
				or not player_ids.has(str(entry.get("actor_id", ""))) \
				or not _fingerprint_valid(entry.get("lineage_fingerprint")):
			return "batch_contract_intent_receipt_ledger_entry_invalid"
	return ""


static func _batch_view_contract_error(contract: Dictionary) -> String:
	if not _stable_id(contract.get("viewer_id")) \
			or not _nonnegative_integer(contract.get("state_revision")) \
			or not (contract.get("own_local_queue") is Array) \
			or not (contract.get("own_prebound_targets") is Dictionary) \
			or not (contract.get("own_reserved_costs") is Dictionary) \
			or not (contract.get("anonymous_public_queue") is Array) \
			or not (contract.get("public_resolution_aftermath") is Array):
		return "batch_view_nested_type_invalid"
	var queue := contract.get("own_local_queue") as Array
	if queue.size() > MAX_ACTIONS_PER_PLAYER:
		return "batch_view_queue_invalid"
	var action_ids: Array[String] = []
	var actions_by_id := {}
	for index in range(queue.size()):
		var action_variant: Variant = queue[index]
		if not (action_variant is Dictionary) \
				or not _action_error_without_fingerprint(action_variant).is_empty():
			return "batch_view_queue_invalid"
		var action := action_variant as Dictionary
		var action_id := str(action.get("action_id", ""))
		if action_ids.has(action_id) or int(action.get("local_order", -1)) != index:
			return "batch_view_queue_invalid"
		action_ids.append(action_id)
		actions_by_id[action_id] = action
	var targets := contract.get("own_prebound_targets") as Dictionary
	if not _exact_keys(targets, action_ids):
		return "batch_view_target_set_invalid"
	for action_id in action_ids:
		if targets.get(action_id) \
				!= (actions_by_id.get(action_id) as Dictionary).get("target_binding"):
			return "batch_view_target_binding_invalid"
	var reservations := contract.get("own_reserved_costs") as Dictionary
	for action_id_variant in reservations.keys():
		var action_id := str(action_id_variant)
		if not action_ids.has(action_id) \
				or not _color_map_valid(
					reservations.get(action_id_variant),
					0,
					ASSET_CAP * 2
				) \
				or reservations.get(action_id_variant) \
					!= _reservation_for_action(actions_by_id.get(action_id) as Dictionary):
			return "batch_view_reservation_invalid"
	for entry_variant in contract.get("anonymous_public_queue") as Array:
		if not _public_queue_contract_entry_valid(entry_variant):
			return "batch_view_public_queue_invalid"
	for entry_variant in contract.get("public_resolution_aftermath") as Array:
		if not _public_queue_contract_entry_valid(entry_variant) \
				or str((entry_variant as Dictionary).get("result", "")) == "pending" \
				or not (contract.get("anonymous_public_queue") as Array).has(entry_variant):
			return "batch_view_aftermath_invalid"
	return ""


static func _batch_intent_contract_error(contract: Dictionary) -> String:
	if not _stable_id(contract.get("intent_id")) \
			or not _stable_id(contract.get("actor_id_or_authoritative_system")) \
			or not _nonnegative_integer(contract.get("expected_core_revision")) \
			or not _stable_id(contract.get("window_id")):
		return "batch_intent_binding_invalid"
	for field in [
		"local_action_index",
		"source_instance_id",
		"prebound_target_identity",
		"reservation_id",
	]:
		if not (contract.get(field) is Array):
			return "batch_intent_nested_type_invalid"
	var indices := contract.get("local_action_index") as Array
	var sources := contract.get("source_instance_id") as Array
	var targets := contract.get("prebound_target_identity") as Array
	var reservations := contract.get("reservation_id") as Array
	if indices.size() != sources.size() or indices.size() != targets.size() \
			or indices.size() != reservations.size() \
			or indices.size() > MAX_ACTIONS_PER_PLAYER:
		return "batch_intent_action_count_invalid"
	var source_ids: Array[String] = []
	var reservation_ids: Array[String] = []
	for index in range(indices.size()):
		if not _nonnegative_integer(indices[index]) or int(indices[index]) != index \
				or not _stable_id(sources[index]) \
				or source_ids.has(str(sources[index])) \
				or not _target_binding_error(targets[index]).is_empty() \
				or not _stable_id(reservations[index]) \
				or reservation_ids.has(str(reservations[index])):
			return "batch_intent_action_binding_invalid"
		source_ids.append(str(sources[index]))
		reservation_ids.append(str(reservations[index]))
	return ""


static func _batch_receipt_contract_error(contract: Dictionary) -> String:
	if not _stable_id(contract.get("receipt_id")) \
			or not _stable_id(contract.get("intent_id")) \
			or not (contract.get("accepted") is bool) \
			or not _stable_id(contract.get("reason_code")) \
			or not _nonnegative_integer(contract.get("committed_core_revision")) \
			or not _stable_id(contract.get("window_id")) \
			or not _stable_id(contract.get("anonymous_action_id")) \
			or not [
				"submission_open",
				"resolution_ready",
				"resolving",
				"batch_resolved",
				"assets_refreshed",
			].has(str(contract.get("resolution_status", ""))):
		return "batch_receipt_semantics_invalid"
	return ""


static func _domain_save_contract_error(
	contract: Dictionary,
	contract_id: String
) -> String:
	var expected_section := "six_color_assets_and_reservations" \
		if contract_id == ASSET_SAVE_STATE_ID \
		else "card_batch_and_anonymous_resolution"
	if str(contract.get("section_id", "")) != expected_section \
			or str(contract.get("ruleset_id", "")) != RULESET_ID \
			or not _stable_id(contract.get("shared_batch_id")) \
			or not _fingerprint_valid(contract.get("shared_lineage_fingerprint")) \
			or not (contract.get("shared_authority_state") is Dictionary):
		return "domain_save_binding_invalid"
	var shared_state := contract.get("shared_authority_state") as Dictionary
	var state_error := _state_error(shared_state)
	if not state_error.is_empty():
		return "domain_save_shared_state_%s" % state_error
	if contract.get("shared_batch_id") != shared_state.get("batch_id") \
			or contract.get("shared_lineage_fingerprint") \
				!= shared_state.get("lineage_fingerprint") \
			or contract.get("state_revision") != shared_state.get("revision"):
		return "domain_save_shared_state_binding_invalid"
	var expected_payload := _asset_authority_payload(shared_state) \
		if contract_id == ASSET_SAVE_STATE_ID \
		else _batch_authority_payload(shared_state)
	for field_variant in expected_payload.keys():
		var field := str(field_variant)
		if contract.get(field) != expected_payload.get(field):
			return "domain_save_projection_mismatch"
	return _asset_authority_payload_error(contract) \
		if contract_id == ASSET_SAVE_STATE_ID \
		else _batch_authority_payload_error(contract)


static func _receipt_adapter_transition_error(
	internal_receipt: Dictionary,
	intent: Dictionary,
	state_before: Dictionary,
	state_after: Dictionary
) -> String:
	var intent_id := str(intent.get("intent_id", ""))
	var actor_id := str(intent.get("actor_id", ""))
	if state_before.get("batch_id") != state_after.get("batch_id") \
			or state_before.get("batch_id") != intent.get("batch_id") \
			or internal_receipt.get("batch_id") != state_after.get("batch_id"):
		return "receipt_adapter_batch_binding_invalid"
	if state_before.get("lineage_fingerprint") \
			!= state_after.get("lineage_fingerprint") \
			or internal_receipt.get("lineage_fingerprint") \
				!= state_after.get("lineage_fingerprint"):
		return "receipt_adapter_lineage_binding_invalid"
	if int(state_after.get("revision", -1)) \
			!= int(state_before.get("revision", -1)) + 1 \
			or internal_receipt.get("state_revision") != state_after.get("revision"):
		return "receipt_adapter_revision_transition_invalid"
	if internal_receipt.get("operation_id") != "lock_player_queue" \
			or internal_receipt.get("accepted") != true \
			or internal_receipt.get("reason_code") != "queue_locked" \
			or internal_receipt.get("actor_id") != actor_id \
			or internal_receipt.get("intent_id") != intent_id \
			or internal_receipt.get("intent_fingerprint") \
				!= intent.get("intent_fingerprint"):
		return "receipt_adapter_operation_binding_invalid"
	if (state_before.get("seen_intent_ids") as Array).has(intent_id) \
			or not (state_after.get("seen_intent_ids") as Array).has(intent_id):
		return "receipt_adapter_exact_once_transition_invalid"
	var before_receipts := state_before.get("receipts") as Array
	var after_receipts := state_after.get("receipts") as Array
	if after_receipts.size() != before_receipts.size() + 1:
		return "receipt_adapter_receipt_append_invalid"
	for index in range(before_receipts.size()):
		if before_receipts[index] != after_receipts[index]:
			return "receipt_adapter_receipt_lineage_invalid"
	if after_receipts.back() != internal_receipt:
		return "receipt_adapter_receipt_membership_invalid"
	var ledger := state_after.get("intent_receipt_ledger") as Dictionary
	if not ledger.has(intent_id):
		return "receipt_adapter_ledger_missing"
	var entry := ledger.get(intent_id) as Dictionary
	if entry.get("intent_fingerprint") != intent.get("intent_fingerprint") \
			or entry.get("receipt_id") != internal_receipt.get("receipt_id") \
			or entry.get("receipt_fingerprint") \
				!= internal_receipt.get("receipt_fingerprint") \
			or entry.get("actor_id") != actor_id \
			or entry.get("lineage_fingerprint") \
				!= state_after.get("lineage_fingerprint"):
		return "receipt_adapter_ledger_binding_invalid"
	return ""


static func _authored_cost_valid(cost: Variant, any_payment: Variant) -> bool:
	if not _cost_map_valid(cost) \
			or not _color_map_valid(any_payment, 0, ASSET_CAP):
		return false
	var paid := 0
	for color in COLORS:
		paid += int((any_payment as Dictionary).get(color, 0))
	return paid == int((cost as Dictionary).get("any", -1))


static func _reservation_from_cost_record(cost_record: Dictionary) -> Dictionary:
	var reservation := _zero_color_map()
	var cost := cost_record.get("cost") as Dictionary
	var any_payment := cost_record.get("any_payment") as Dictionary
	for color in COLORS:
		reservation[color] = int(cost.get(color, 0)) \
			+ int(any_payment.get(color, 0))
	return reservation


static func _public_queue_contract_entry_valid(value: Variant) -> bool:
	if not (value is Dictionary) \
			or not _exact_fields(value as Dictionary, PUBLIC_QUEUE_FIELDS):
		return false
	var entry := value as Dictionary
	if not (entry.get("rule_allowed_target") is Array):
		return false
	if not _stable_id(entry.get("card")) \
			or not _stable_id(entry.get("current_effect")) \
			or _string_id_array(entry.get("rule_allowed_target"), false).size() \
				!= (entry.get("rule_allowed_target") as Array).size():
		return false
	if str(entry.get("result", "")) == "pending":
		return entry.get("reason_code") == "pending" \
			and INVALID_TARGET_POLICY_IDS.has(str(
				entry.get("invalid_target_policy_id", "")
			)) \
			and entry.get("asset_refund_applied") == false \
			and entry.get("normal_card_destination") == "pending" \
			and entry.get("action_slot_refunded") == false
	return _action_result_error({
		"outcome_id": entry.get("result"),
		"reason_code": entry.get("reason_code"),
		"invalid_target_policy_id": entry.get("invalid_target_policy_id"),
		"asset_refund_applied": entry.get("asset_refund_applied"),
		"normal_card_destination": entry.get("normal_card_destination"),
		"action_slot_refunded": entry.get("action_slot_refunded"),
	}).is_empty()


static func _stable_dictionary_ids(
	value: Variant,
	allow_empty: bool
) -> Array[String]:
	var result: Array[String] = []
	if not (value is Dictionary):
		return result
	for key_variant in (value as Dictionary).keys():
		if not _stable_id(key_variant):
			return []
		result.append(str(key_variant))
	if not allow_empty and result.is_empty():
		return []
	return result


static func _domain_restore_failure(reason_code: String) -> Dictionary:
	return {
		"restored": false,
		"preflight_valid": false,
		"reason_code": reason_code,
		"contract_ids": [],
		"state": {},
	}


static func _viewer_projection(
	state: Dictionary,
	viewer_id: String,
	contract_ids: Array
) -> Dictionary:
	if not _state_error(state).is_empty() \
			or not (state.get("player_ids") as Array).has(viewer_id):
		return {}
	var player := (state.get("players") as Dictionary).get(viewer_id) as Dictionary
	var projection := public_projection(state)
	projection.erase("projection_fingerprint")
	projection.erase("contract_id")
	projection["contract_ids"] = contract_ids.duplicate()
	projection["viewer_id"] = viewer_id
	projection["own_assets"] = (player.get("assets") as Dictionary).duplicate(true)
	projection["own_remainders_milli"] = (player.get("remainders_milli") as Dictionary).duplicate(true)
	projection["own_reserved_totals"] = (player.get("reserved_totals") as Dictionary).duplicate(true)
	var own_local_queue: Array = []
	for action_variant in player.get("local_queue") as Array:
		var projected_action := (action_variant as Dictionary).duplicate(true)
		projected_action.erase("lock_fingerprint")
		own_local_queue.append(projected_action)
	projection["own_local_queue"] = own_local_queue
	projection["own_frozen_gdp_milli"] = (player.get("frozen_gdp_milli") as Dictionary).duplicate(true)
	projection["own_projected_refresh"] = _projected_refresh_after_success(state, player)
	return _seal(projection, "projection_fingerprint")


static func _lock_player_in_state(
	state: Dictionary,
	actor_id: String,
	actions: Array,
	reservations: Dictionary,
	reserved_totals: Dictionary,
	completed_gdp_milli: Dictionary
) -> void:
	var player := (state.get("players") as Dictionary).get(actor_id) as Dictionary
	player["queue_status"] = "locked"
	player["local_queue"] = actions.duplicate(true)
	player["reservations"] = reservations.duplicate(true)
	player["reserved_totals"] = reserved_totals.duplicate(true)
	player["frozen_gdp_milli"] = completed_gdp_milli.duplicate(true)
	var window := state.get("window") as Dictionary
	window["locked_player_count"] = int(window.get("locked_player_count", 0)) + 1


static func _finalize_submission_if_ready(state: Dictionary) -> void:
	var window := state.get("window") as Dictionary
	if int(window.get("locked_player_count", 0)) != (state.get("player_ids") as Array).size():
		return
	state["frozen_hidden_lead_order"] = (
		state.get("submission_hidden_lead_order") as Array
	).duplicate()
	var queue := _build_authority_queue(state)
	state["authority_queue"] = queue
	state["resolution_cursor"] = 0
	window["status"] = "batch_resolved" if queue.is_empty() else "resolution_ready"


static func _resolution_context(
	state: Dictionary,
	action_id: String,
	operation_id: String
) -> Dictionary:
	if not _state_error(state).is_empty():
		return {
			"valid": false,
			"failure": _failure(state, operation_id, "state_invalid", "", action_id),
		}
	var status := str((state.get("window") as Dictionary).get("status", ""))
	if not ["resolution_ready", "resolving"].has(status):
		return {
			"valid": false,
			"failure": _failure(
				state,
				operation_id,
				"resolution_not_active",
				"",
				action_id
			),
		}
	var queue := state.get("authority_queue") as Array
	var cursor := int(state.get("resolution_cursor", -1))
	if cursor < 0 or cursor >= queue.size():
		return {
			"valid": false,
			"failure": _failure(
				state,
				operation_id,
				"resolution_cursor_invalid",
				"",
				action_id
			),
		}
	var current := queue[cursor] as Dictionary
	if str(current.get("action_id", "")) != action_id:
		return {
			"valid": false,
			"failure": _failure(
				state,
				operation_id,
				"resolution_order_mismatch",
				"",
				action_id
			),
		}
	var actor_id := str(current.get("actor_id", ""))
	var player := (state.get("players") as Dictionary).get(actor_id) as Dictionary
	var reservations := player.get("reservations") as Dictionary
	if not reservations.has(action_id):
		return {
			"valid": false,
			"failure": _failure(
				state,
				operation_id,
				"action_reservation_missing",
				actor_id,
				action_id
			),
		}
	var action := _action_by_id(player, action_id)
	if action.is_empty():
		return {
			"valid": false,
			"failure": _failure(
				state,
				operation_id,
				"action_binding_missing",
				actor_id,
				action_id
			),
		}
	return {
		"valid": true,
		"cursor": cursor,
		"actor_id": actor_id,
		"action": action,
	}


static func _commit_current_resolution(
	state: Dictionary,
	context: Dictionary,
	result_record: Dictionary,
	consume_reservation: bool,
	operation_id: String,
	receipt_reason_code: String
) -> Dictionary:
	var actor_id := str(context.get("actor_id", ""))
	var action_id := str((context.get("action") as Dictionary).get("action_id", ""))
	var action := context.get("action") as Dictionary
	if not _action_result_error(result_record, action).is_empty():
		return _failure(
			state,
			operation_id,
			"resolution_result_invalid",
			actor_id,
			action_id
		)
	var next := state.duplicate(true)
	var cursor := int(context.get("cursor", -1))
	var next_queue := next.get("authority_queue") as Array
	var next_entry := next_queue[cursor] as Dictionary
	var next_player := (next.get("players") as Dictionary).get(actor_id) as Dictionary
	var reservations := next_player.get("reservations") as Dictionary
	var reservation := reservations.get(action_id) as Dictionary
	if consume_reservation:
		var assets := next_player.get("assets") as Dictionary
		for color in COLORS:
			assets[color] = int(assets.get(color, 0)) - int(reservation.get(color, 0))
	reservations.erase(action_id)
	_recalculate_reserved_totals(next_player)
	(next_player.get("action_results") as Dictionary)[action_id] = (
		result_record.duplicate(true)
	)
	next_entry["public"] = _public_entry_for_action(action, result_record)
	next["resolution_cursor"] = cursor + 1
	_increment_revision(next)
	var receipt := _receipt(
		next,
		operation_id,
		true,
		receipt_reason_code,
		actor_id,
		action_id,
		str(result_record.get("outcome_id", "")),
		"",
		"",
		result_record
	)
	(next.get("receipts") as Array).append(receipt)
	if int(next.get("resolution_cursor", 0)) == next_queue.size():
		(next.get("window") as Dictionary)["status"] = "batch_resolved"
	else:
		(next.get("window") as Dictionary)["status"] = "resolving"
	return _success(next, receipt)


static func _action_by_id(player: Dictionary, action_id: String) -> Dictionary:
	for action_variant in player.get("local_queue") as Array:
		var action := action_variant as Dictionary
		if str(action.get("action_id", "")) == action_id:
			return action.duplicate(true)
	return {}


static func _public_entry_for_action(
	action: Dictionary,
	result_record: Dictionary = {}
) -> Dictionary:
	var pending := result_record.is_empty()
	return {
		"card": action.get("card"),
		"rule_allowed_target": (
			(action.get("target_binding") as Dictionary).get("target_ids") as Array
		).duplicate(),
		"current_effect": action.get("current_effect"),
		"result": "pending" if pending else result_record.get("outcome_id"),
		"reason_code": "pending" if pending else result_record.get("reason_code"),
		"invalid_target_policy_id": action.get("invalid_target_policy_id"),
		"asset_refund_applied": false \
			if pending else result_record.get("asset_refund_applied"),
		"normal_card_destination": "pending" \
			if pending else result_record.get("normal_card_destination"),
		"action_slot_refunded": false \
			if pending else result_record.get("action_slot_refunded"),
	}


static func _build_authority_queue(state: Dictionary) -> Array:
	var result: Array = []
	var players := state.get("players") as Dictionary
	for local_order in range(MAX_ACTIONS_PER_PLAYER):
		for actor_variant in state.get("frozen_hidden_lead_order") as Array:
			var actor_id := str(actor_variant)
			var player := players.get(actor_id) as Dictionary
			var queue := player.get("local_queue") as Array
			if local_order >= queue.size():
				continue
			var action := queue[local_order] as Dictionary
			if int(action.get("local_order", -1)) != local_order:
				continue
			var action_id := str(action.get("action_id", ""))
			result.append({
				"action_id": action_id,
				"actor_id": actor_id,
				"local_order": local_order,
				"reservation": _reservation_for_action(action),
				"public": _public_entry_for_action(action),
			})
	return result


static func _reservation_plan(actions: Array, assets: Dictionary) -> Dictionary:
	var reservations := {}
	var totals := _zero_color_map()
	for action_variant in actions:
		var action := action_variant as Dictionary
		var reservation := _reservation_for_action(action)
		var action_id := str(action.get("action_id", ""))
		reservations[action_id] = reservation
		for color in COLORS:
			totals[color] = int(totals.get(color, 0)) + int(reservation.get(color, 0))
			if int(totals.get(color, 0)) > int(assets.get(color, 0)):
				return {
					"affordable": false,
					"reason_code": "full_queue_unaffordable",
					"reservations": {},
					"totals": _zero_color_map(),
				}
	return {
		"affordable": true,
		"reason_code": "none",
		"reservations": reservations,
		"totals": totals,
	}


static func _reservation_for_action(action: Dictionary) -> Dictionary:
	var result := _zero_color_map()
	var cost := action.get("cost") as Dictionary
	var any_payment := action.get("any_payment") as Dictionary
	for color in COLORS:
		result[color] = int(cost.get(color, 0)) + int(any_payment.get(color, 0))
	return result


static func _recalculate_reserved_totals(player: Dictionary) -> void:
	var totals := _zero_color_map()
	for reservation_variant in (player.get("reservations") as Dictionary).values():
		var reservation := reservation_variant as Dictionary
		for color in COLORS:
			totals[color] = int(totals.get(color, 0)) + int(reservation.get(color, 0))
	player["reserved_totals"] = totals


static func _sorted_actions(actions: Array) -> Array:
	if actions.size() > MAX_ACTIONS_PER_PLAYER:
		return []
	var sorted := actions.duplicate(true)
	for action_variant in sorted:
		if not _action_error(action_variant).is_empty():
			return []
	sorted.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left.get("local_order", -1)) < int(right.get("local_order", -1))
	)
	for index in range(sorted.size()):
		if int((sorted[index] as Dictionary).get("local_order", -1)) != index:
			return []
	return sorted


static func _action_error(value: Variant) -> String:
	if not (value is Dictionary) or not _is_pure_data(value):
		return "action_not_pure_data"
	var action := value as Dictionary
	if not _exact_fields(action, ACTION_FIELDS):
		return "action_fields_invalid"
	var unsealed := action.duplicate(true)
	unsealed.erase("lock_fingerprint")
	var base_error := _action_error_without_fingerprint(unsealed)
	if not base_error.is_empty():
		return base_error
	if not _fingerprint_valid(action.get("lock_fingerprint")) \
			or str(action.get("lock_fingerprint", "")) != _fingerprint(unsealed):
		return "action_lock_fingerprint_invalid"
	return ""


static func _action_error_without_fingerprint(value: Variant) -> String:
	if not (value is Dictionary) or not _is_pure_data(value):
		return "action_not_pure_data"
	var action := value as Dictionary
	var expected_fields := ACTION_FIELDS.duplicate()
	expected_fields.erase("lock_fingerprint")
	if not _exact_fields(action, expected_fields):
		return "action_fields_invalid"
	if not _stable_id(action.get("action_id")) \
			or not ACTION_KINDS.has(str(action.get("action_kind", ""))) \
			or not _stable_id(action.get("source_id")) \
			or not _nonnegative_integer(action.get("local_order")) \
			or int(action.get("local_order", -1)) >= MAX_ACTIONS_PER_PLAYER \
			or not _stable_id(action.get("card")) \
			or not _stable_id(action.get("current_effect")) \
			or not INVALID_TARGET_POLICY_IDS.has(str(
				action.get("invalid_target_policy_id", "")
			)):
		return "action_identity_invalid"
	var target_error := _target_binding_error(action.get("target_binding"))
	if not target_error.is_empty():
		return target_error
	if not _cost_map_valid(action.get("cost")) \
			or not _color_map_valid(action.get("any_payment"), 0, ASSET_CAP):
		return "action_cost_invalid"
	var any_cost := int((action.get("cost") as Dictionary).get("any", -1))
	var any_paid := 0
	for color in COLORS:
		any_paid += int((action.get("any_payment") as Dictionary).get(color, 0))
	if any_paid != any_cost:
		return "action_any_payment_invalid"
	return ""


static func _action_result_error(
	value: Variant,
	action: Dictionary = {}
) -> String:
	if not (value is Dictionary) or not _is_pure_data(value) \
			or not _exact_fields(value as Dictionary, ACTION_RESULT_FIELDS):
		return "action_result_fields_invalid"
	var result := value as Dictionary
	var outcome_id := str(result.get("outcome_id", ""))
	var policy_id := str(result.get("invalid_target_policy_id", ""))
	if not SETTLEMENT_OUTCOMES.has(outcome_id) \
			or not _stable_id(result.get("reason_code")) \
			or not INVALID_TARGET_POLICY_IDS.has(policy_id) \
			or not (result.get("asset_refund_applied") is bool) \
			or not ["discard", "not_applicable", "not_attested"].has(str(
				result.get("normal_card_destination", "")
			)) \
			or result.get("action_slot_refunded") != false:
		return "action_result_value_invalid"
	if not action.is_empty() \
			and policy_id != str(action.get("invalid_target_policy_id", "")):
		return "action_result_policy_binding_invalid"
	var is_invalid_target := INVALID_TARGET_OUTCOME_BY_POLICY.values().has(outcome_id)
	if is_invalid_target:
		if str(INVALID_TARGET_OUTCOME_BY_POLICY.get(policy_id, "")) != outcome_id \
				or ["none", "pending"].has(str(result.get("reason_code", ""))) \
				or bool(result.get("asset_refund_applied", false)) \
					!= (policy_id == "FIZZLE_FULL_ASSET_REFUND"):
			return "invalid_target_result_semantics_invalid"
		if not action.is_empty():
			var expected_destination := "discard" \
				if str(action.get("action_kind", "")) == "normal_card" \
				else "not_applicable"
			if str(result.get("normal_card_destination", "")) \
					!= expected_destination:
				return "invalid_target_card_destination_invalid"
		return ""
	if outcome_id == "success":
		if result.get("reason_code") != "action_resolved_success" \
				or result.get("asset_refund_applied") != false \
				or result.get("normal_card_destination") != "not_attested":
			return "success_result_semantics_invalid"
		return ""
	if result.get("reason_code") != "rule_allowed_refundable_failure" \
			or result.get("asset_refund_applied") != true \
			or result.get("normal_card_destination") != "not_attested":
		return "refundable_result_semantics_invalid"
	return ""


static func _target_binding_error(value: Variant) -> String:
	if not (value is Dictionary) or not _is_pure_data(value):
		return "target_binding_not_pure_data"
	var binding := value as Dictionary
	if not _exact_fields(binding, TARGET_BINDING_FIELDS):
		return "target_binding_fields_invalid"
	if not _stable_id(binding.get("binding_id")) \
			or not _nonnegative_integer(binding.get("selection_revision")) \
			or not (binding.get("complete") is bool) \
			or not bool(binding.get("complete", false)):
		return "target_binding_invalid"
	var targets := _string_id_array(binding.get("target_ids"), false)
	if targets.is_empty() or targets.size() != (binding.get("target_ids") as Array).size():
		return "target_binding_targets_invalid"
	return ""


static func _intent_error(value: Variant) -> String:
	if not (value is Dictionary) or not _is_pure_data(value):
		return "intent_not_pure_data"
	var intent := value as Dictionary
	if not _exact_fields(intent, INTENT_FIELDS):
		return "intent_fields_invalid"
	var without_fingerprint := intent.duplicate(true)
	without_fingerprint.erase("intent_fingerprint")
	var base_error := _intent_error_without_fingerprint(without_fingerprint)
	if not base_error.is_empty():
		return base_error
	if not _fingerprint_valid(intent.get("intent_fingerprint")) \
			or str(intent.get("intent_fingerprint", "")) != _fingerprint(without_fingerprint):
		return "intent_fingerprint_invalid"
	return ""


static func _intent_error_without_fingerprint(value: Variant) -> String:
	if not (value is Dictionary) or not _is_pure_data(value):
		return "intent_not_pure_data"
	var intent := value as Dictionary
	var expected := INTENT_FIELDS.duplicate()
	expected.erase("intent_fingerprint")
	if not _exact_fields(intent, expected):
		return "intent_fields_invalid"
	if intent.get("schema_version") != SCHEMA_VERSION \
			or str(intent.get("contract_id", "")) != INTERNAL_INTENT_ID:
		return "intent_schema_invalid"
	if not _stable_id(intent.get("intent_id")) \
			or not _stable_id(intent.get("batch_id")) \
			or not _stable_id(intent.get("actor_id")) \
			or not _nonnegative_integer(intent.get("submitted_at_ms")) \
			or not (intent.get("actions") is Array):
		return "intent_binding_invalid"
	var sorted := _sorted_actions(intent.get("actions") as Array)
	if sorted.size() != (intent.get("actions") as Array).size():
		return "local_order_invalid"
	var action_ids: Array[String] = []
	for action_variant in sorted:
		var action_id := str((action_variant as Dictionary).get("action_id", ""))
		if action_ids.has(action_id):
			return "action_id_duplicate"
		action_ids.append(action_id)
	return ""


static func _state_error(value: Variant) -> String:
	if not (value is Dictionary) or not _is_pure_data(value):
		return "state_not_pure_data"
	var state := value as Dictionary
	if not _exact_fields(state, STATE_FIELDS):
		return "state_fields_invalid"
	if state.get("schema_version") != SCHEMA_VERSION \
			or state.get("state_version") != STATE_VERSION \
			or str(state.get("ruleset_id", "")) != RULESET_ID \
			or str(state.get("balance_profile_id", "")) != BALANCE_PROFILE_ID \
			or str(state.get("balance_profile_fingerprint", "")) \
				!= BALANCE_PROFILE_FINGERPRINT \
			or str(state.get("default_invalid_target_policy_id", "")) \
				!= DEFAULT_INVALID_TARGET_POLICY_ID \
			or state.get("max_asset_refresh_per_color_per_batch") \
				!= MAX_ASSET_REFRESH_PER_COLOR_PER_BATCH \
			or state.get("core_authority_ids") \
			!= [ASSET_CORE_AUTHORITY_ID, BATCH_CORE_AUTHORITY_ID]:
		return "state_schema_invalid"
	if not _nonnegative_integer(state.get("revision")) \
			or not _stable_id(state.get("batch_id")) \
			or not _fingerprint_valid(state.get("lineage_fingerprint")) \
			or not _positive_integer(state.get("gdp_milli_per_asset")) \
			or not _nonnegative_integer(state.get("resolution_cursor")) \
			or not (state.get("refresh_applied") is bool):
		return "state_scalar_invalid"
	var player_ids := _string_id_array(state.get("player_ids"), false)
	if not (state.get("submission_hidden_lead_order") is Array) \
			or not (state.get("frozen_hidden_lead_order") is Array):
		return "state_player_order_invalid"
	var submission_order := _string_id_array(
		state.get("submission_hidden_lead_order"),
		false
	)
	var frozen_order := _string_id_array(state.get("frozen_hidden_lead_order"), true)
	if player_ids.is_empty() or submission_order.is_empty() \
			or not _same_string_set(player_ids, submission_order) \
			or (
				not frozen_order.is_empty() \
				and not _same_string_set(player_ids, frozen_order)
			):
		return "state_player_order_invalid"
	if not (state.get("players") is Dictionary) \
			or not _exact_keys(state.get("players") as Dictionary, player_ids):
		return "state_players_invalid"
	var window_error := _window_error(state.get("window"), player_ids.size())
	if not window_error.is_empty():
		return window_error
	var action_ids: Array[String] = []
	var locked_count := 0
	for player_id in player_ids:
		var player_error := _player_error(
			(state.get("players") as Dictionary).get(player_id),
			int(state.get("gdp_milli_per_asset"))
		)
		if not player_error.is_empty():
			return player_error
		var player := (state.get("players") as Dictionary).get(player_id) as Dictionary
		if str(player.get("queue_status", "")) == "locked":
			locked_count += 1
		for action_variant in player.get("local_queue") as Array:
			var action_id := str((action_variant as Dictionary).get("action_id", ""))
			if action_ids.has(action_id):
				return "state_action_id_duplicate"
			action_ids.append(action_id)
	if locked_count != int((state.get("window") as Dictionary).get("locked_player_count", -1)):
		return "state_locked_count_invalid"
	if not (state.get("authority_queue") is Array):
		return "state_authority_queue_invalid"
	for entry_variant in state.get("authority_queue") as Array:
		var entry_error := _authority_queue_entry_error(entry_variant, player_ids, action_ids)
		if not entry_error.is_empty():
			return entry_error
	if int(state.get("resolution_cursor", 0)) > (state.get("authority_queue") as Array).size():
		return "state_resolution_cursor_invalid"
	if not (state.get("seen_intent_ids") is Array):
		return "state_seen_intents_invalid"
	var seen_intent_ids := _string_id_array(state.get("seen_intent_ids"), true)
	if seen_intent_ids.size() != (state.get("seen_intent_ids") as Array).size():
		return "state_seen_intents_invalid"
	if not (state.get("intent_receipt_ledger") is Dictionary) \
			or not _exact_keys(
				state.get("intent_receipt_ledger") as Dictionary,
				seen_intent_ids
			):
		return "state_intent_receipt_ledger_set_invalid"
	if not (state.get("receipts") is Array):
		return "state_receipts_invalid"
	var receipt_ids: Array[String] = []
	var lock_intent_ids: Array[String] = []
	var receipt_index := 0
	for receipt_variant in state.get("receipts") as Array:
		if not _receipt_error(receipt_variant).is_empty():
			return "state_receipt_invalid"
		var receipt := receipt_variant as Dictionary
		var receipt_id := str(receipt.get("receipt_id", ""))
		if receipt_ids.has(receipt_id) \
				or receipt_id != "%s.receipt.%d" % [
					state.get("batch_id", "batch"),
					int(receipt.get("state_revision", -1)),
				] \
				or receipt.get("batch_id") != state.get("batch_id") \
				or str(receipt.get("lineage_fingerprint", "")) \
				!= str(state.get("lineage_fingerprint", "")) \
				or int(receipt.get("state_revision", -1)) != receipt_index + 1 \
				or not bool(receipt.get("accepted", false)):
			return "state_receipt_sequence_invalid"
		var receipt_binding_error := _state_receipt_binding_error(
			receipt,
			state,
			player_ids
		)
		if not receipt_binding_error.is_empty():
			return receipt_binding_error
		if receipt.get("operation_id") == "lock_player_queue":
			lock_intent_ids.append(str(receipt.get("intent_id", "")))
		receipt_ids.append(receipt_id)
		receipt_index += 1
	if receipt_index != int(state.get("revision", -1)):
		return "state_revision_receipt_parity_invalid"
	if lock_intent_ids != seen_intent_ids:
		return "state_intent_receipt_order_invalid"
	var intent_ledger := state.get("intent_receipt_ledger") as Dictionary
	for intent_id in seen_intent_ids:
		var entry_variant: Variant = intent_ledger.get(intent_id)
		if not (entry_variant is Dictionary):
			return "state_intent_receipt_ledger_entry_invalid"
		var entry := entry_variant as Dictionary
		if not _exact_fields(entry, INTENT_RECEIPT_LEDGER_ENTRY_FIELDS) \
				or entry.get("intent_id") != intent_id \
				or not _fingerprint_valid(entry.get("intent_fingerprint")) \
				or not _stable_id(entry.get("receipt_id")) \
				or not _fingerprint_valid(entry.get("receipt_fingerprint")) \
				or not player_ids.has(str(entry.get("actor_id", ""))) \
				or entry.get("lineage_fingerprint") != state.get("lineage_fingerprint"):
			return "state_intent_receipt_ledger_entry_invalid"
		var bound_receipt := _receipt_by_id(
			state.get("receipts") as Array,
			str(entry.get("receipt_id", ""))
		)
		if bound_receipt.is_empty() \
				or bound_receipt.get("receipt_fingerprint") \
					!= entry.get("receipt_fingerprint") \
				or bound_receipt.get("intent_id") != intent_id \
				or bound_receipt.get("intent_fingerprint") \
					!= entry.get("intent_fingerprint") \
				or bound_receipt.get("actor_id") != entry.get("actor_id") \
				or bound_receipt.get("operation_id") != "lock_player_queue":
			return "state_intent_receipt_ledger_binding_invalid"
		var actor_player := (
			state.get("players") as Dictionary
		).get(str(entry.get("actor_id", ""))) as Dictionary
		var reconstructed_intent := {
			"schema_version": SCHEMA_VERSION,
			"contract_id": INTERNAL_INTENT_ID,
			"intent_id": intent_id,
			"batch_id": str(state.get("batch_id", "")),
			"actor_id": str(entry.get("actor_id", "")),
			"submitted_at_ms": int(entry.get("submitted_at_ms", -1)),
			"actions": (actor_player.get("local_queue") as Array).duplicate(true),
		}
		if _fingerprint(reconstructed_intent) != entry.get("intent_fingerprint"):
			return "state_intent_receipt_reconstruction_invalid"
	return _semantic_state_error(state, player_ids, action_ids, locked_count)


static func _window_error(value: Variant, player_count: int) -> String:
	if not (value is Dictionary) or not _exact_fields(value as Dictionary, WINDOW_FIELDS):
		return "window_fields_invalid"
	var window := value as Dictionary
	if not _nonnegative_integer(window.get("opened_at_ms")) \
			or not _nonnegative_integer(window.get("deadline_ms")) \
			or not _nonnegative_integer(window.get("time_observation_watermark_ms")) \
			or int(window.get("deadline_ms")) - int(window.get("opened_at_ms")) \
			!= WINDOW_DURATION_MS \
			or int(window.get("time_observation_watermark_ms", -1)) \
				< int(window.get("opened_at_ms", 0)) \
			or not [
				"submission_open",
				"resolution_ready",
				"resolving",
				"batch_resolved",
				"assets_refreshed",
			].has(str(window.get("status", ""))) \
			or window.get("one_shot") != true \
			or not _nonnegative_integer(window.get("locked_player_count")) \
			or int(window.get("locked_player_count")) > player_count:
		return "window_invalid"
	return ""


static func _player_error(value: Variant, conversion: int) -> String:
	if not (value is Dictionary) or not _exact_fields(value as Dictionary, PLAYER_FIELDS):
		return "player_fields_invalid"
	var player := value as Dictionary
	if not _color_map_valid(player.get("assets"), 0, ASSET_CAP) \
			or not _color_map_valid(player.get("remainders_milli"), 0, conversion - 1) \
			or not _color_map_valid(player.get("reserved_totals"), 0, MAX_SAFE_INTEGER) \
			or not _color_map_valid(player.get("frozen_gdp_milli"), 0, MAX_SAFE_INTEGER) \
			or not _color_map_valid(player.get("refresh_overflow"), 0, MAX_SAFE_INTEGER):
		return "player_asset_state_invalid"
	if not ["open", "locked"].has(str(player.get("queue_status", ""))) \
			or not (player.get("local_queue") is Array) \
			or not (player.get("reservations") is Dictionary) \
			or not (player.get("action_results") is Dictionary):
		return "player_queue_state_invalid"
	var sorted := _sorted_actions(player.get("local_queue") as Array)
	if sorted.size() != (player.get("local_queue") as Array).size():
		return "player_local_queue_invalid"
	if str(player.get("queue_status", "")) == "open":
		if not sorted.is_empty() \
				or not (player.get("reservations") as Dictionary).is_empty() \
				or not (player.get("action_results") as Dictionary).is_empty() \
				or player.get("reserved_totals") != _zero_color_map() \
				or player.get("frozen_gdp_milli") != _zero_color_map():
			return "open_player_queue_not_empty"
	var expected_reservation_ids: Array[String] = []
	var local_action_ids: Array[String] = []
	for action_variant in player.get("local_queue") as Array:
		var action := action_variant as Dictionary
		var action_id := str(action.get("action_id", ""))
		local_action_ids.append(action_id)
		if not (player.get("action_results") as Dictionary).has(action_id):
			expected_reservation_ids.append(action_id)
	if not _exact_keys(player.get("reservations") as Dictionary, expected_reservation_ids):
		return "player_reservations_invalid"
	var calculated_totals := _zero_color_map()
	for action_variant in player.get("local_queue") as Array:
		var action := action_variant as Dictionary
		var action_id := str(action.get("action_id", ""))
		if not (player.get("reservations") as Dictionary).has(action_id):
			continue
		var reservation_variant: Variant = (player.get("reservations") as Dictionary).get(action_id)
		if not _color_map_valid(reservation_variant, 0, ASSET_CAP * 2):
			return "player_reservation_invalid"
		if reservation_variant != _reservation_for_action(action):
			return "player_reservation_binding_invalid"
		for color in COLORS:
			calculated_totals[color] = int(calculated_totals.get(color, 0)) \
				+ int((reservation_variant as Dictionary).get(color, 0))
	if calculated_totals != player.get("reserved_totals"):
		return "player_reserved_totals_invalid"
	for color in COLORS:
		if int(calculated_totals.get(color, 0)) > int((player.get("assets") as Dictionary).get(color, 0)):
			return "player_reservation_exceeds_assets"
	for action_id_variant in (player.get("action_results") as Dictionary).keys():
		var action_id := str(action_id_variant)
		var action := _action_by_id(player, action_id)
		if not local_action_ids.has(action_id) or action.is_empty() \
				or not _action_result_error(
					(player.get("action_results") as Dictionary).get(action_id_variant),
					action
				).is_empty():
			return "player_action_result_invalid"
	return ""


static func _semantic_state_error(
	state: Dictionary,
	player_ids: Array[String],
	action_ids: Array[String],
	locked_count: int
) -> String:
	var window := state.get("window") as Dictionary
	var status := str(window.get("status", ""))
	var queue := state.get("authority_queue") as Array
	var cursor := int(state.get("resolution_cursor", -1))
	var all_locked := locked_count == player_ids.size()
	if not all_locked:
		if status != "submission_open" or not queue.is_empty() or cursor != 0 \
				or bool(state.get("refresh_applied", false)) \
				or not (state.get("frozen_hidden_lead_order") as Array).is_empty():
			return "submission_state_inconsistent"
		return ""
	if status == "submission_open":
		return "locked_submission_state_inconsistent"
	if state.get("frozen_hidden_lead_order") != state.get("submission_hidden_lead_order"):
		return "frozen_hidden_lead_order_invalid"

	var expected_queue := _build_authority_queue(state)
	if queue.size() != expected_queue.size() or queue.size() != action_ids.size():
		return "authority_queue_length_invalid"
	var settled_count := 0
	for index in range(queue.size()):
		var entry := queue[index] as Dictionary
		var expected := expected_queue[index] as Dictionary
		for field in ["action_id", "actor_id", "local_order", "reservation"]:
			if entry.get(field) != expected.get(field):
				return "authority_queue_binding_invalid"
		var entry_public := entry.get("public") as Dictionary
		var actor_id := str(entry.get("actor_id", ""))
		var action_id := str(entry.get("action_id", ""))
		var player := (state.get("players") as Dictionary).get(actor_id) as Dictionary
		var action := _action_by_id(player, action_id)
		var results := player.get("action_results") as Dictionary
		var result_record := results.get(action_id, {}) as Dictionary
		var expected_public := _public_entry_for_action(action, result_record)
		if entry_public != expected_public:
			return "authority_queue_public_binding_invalid"
		if result_record.is_empty():
			if index < cursor:
				return "authority_queue_pending_prefix_invalid"
		elif index >= cursor:
			return "authority_queue_settled_suffix_invalid"
		else:
			settled_count += 1
	if settled_count != cursor:
		return "resolution_cursor_result_parity_invalid"

	if bool(state.get("refresh_applied", false)) != (status == "assets_refreshed"):
		return "asset_refresh_status_invalid"
	if queue.is_empty():
		return "" if cursor == 0 and ["batch_resolved", "assets_refreshed"].has(status) \
			else "empty_queue_status_invalid"
	if cursor == 0:
		return "" if status == "resolution_ready" else "resolution_ready_status_invalid"
	if cursor < queue.size():
		return "" if status == "resolving" else "resolving_status_invalid"
	return "" if cursor == queue.size() and ["batch_resolved", "assets_refreshed"].has(status) \
		else "resolved_status_invalid"


static func _authority_queue_entry_error(
	value: Variant,
	player_ids: Array[String],
	action_ids: Array[String]
) -> String:
	if not (value is Dictionary) or not _exact_fields(value as Dictionary, AUTHORITY_QUEUE_FIELDS):
		return "authority_queue_entry_fields_invalid"
	var entry := value as Dictionary
	if not action_ids.has(str(entry.get("action_id", ""))) \
			or not player_ids.has(str(entry.get("actor_id", ""))) \
			or not _nonnegative_integer(entry.get("local_order")) \
			or int(entry.get("local_order", -1)) >= MAX_ACTIONS_PER_PLAYER \
			or not _color_map_valid(entry.get("reservation"), 0, ASSET_CAP * 2):
		return "authority_queue_entry_invalid"
	if not (entry.get("public") is Dictionary) \
			or not _exact_fields(entry.get("public") as Dictionary, PUBLIC_QUEUE_FIELDS):
		return "public_queue_entry_fields_invalid"
	var public_entry := entry.get("public") as Dictionary
	if not _stable_id(public_entry.get("card")) \
			or not _stable_id(public_entry.get("current_effect")) \
			or _string_id_array(public_entry.get("rule_allowed_target"), false).size() \
			!= (public_entry.get("rule_allowed_target") as Array).size():
		return "public_queue_entry_invalid"
	var result_id := str(public_entry.get("result", ""))
	if result_id == "pending":
		if public_entry.get("reason_code") != "pending" \
				or not INVALID_TARGET_POLICY_IDS.has(str(
					public_entry.get("invalid_target_policy_id", "")
				)) \
				or public_entry.get("asset_refund_applied") != false \
				or public_entry.get("normal_card_destination") != "pending" \
				or public_entry.get("action_slot_refunded") != false:
			return "public_queue_pending_semantics_invalid"
		return ""
	var result_record := {
		"outcome_id": result_id,
		"reason_code": public_entry.get("reason_code"),
		"invalid_target_policy_id": public_entry.get("invalid_target_policy_id"),
		"asset_refund_applied": public_entry.get("asset_refund_applied"),
		"normal_card_destination": public_entry.get("normal_card_destination"),
		"action_slot_refunded": public_entry.get("action_slot_refunded"),
	}
	if not _action_result_error(result_record).is_empty():
		return "public_queue_result_semantics_invalid"
	return ""


static func _state_receipt_binding_error(
	receipt: Dictionary,
	state: Dictionary,
	player_ids: Array[String]
) -> String:
	var operation_id := str(receipt.get("operation_id", ""))
	var actor_id := str(receipt.get("actor_id", ""))
	var action_id := str(receipt.get("action_id", ""))
	var outcome_id := str(receipt.get("outcome_id", ""))
	var intent_id := str(receipt.get("intent_id", ""))
	var intent_fingerprint := str(receipt.get("intent_fingerprint", ""))
	match operation_id:
		"update_submission_hidden_lead_order":
			if receipt.get("reason_code") != "hidden_lead_order_updated" \
					or outcome_id != "submission_order_updated" \
					or not actor_id.is_empty() or not action_id.is_empty() \
					or not intent_id.is_empty() or not intent_fingerprint.is_empty() \
					or not _receipt_resolution_detail_is_empty(receipt):
				return "state_receipt_hidden_lead_binding_invalid"
		"lock_player_queue":
			if receipt.get("reason_code") != "queue_locked" \
					or outcome_id != "reserved" \
					or not player_ids.has(actor_id) or not action_id.is_empty() \
					or not _stable_id(intent_id) \
					or not _fingerprint_valid(intent_fingerprint) \
					or not _receipt_resolution_detail_is_empty(receipt):
				return "state_receipt_lock_binding_invalid"
		"close_expired_window":
			if receipt.get("reason_code") != "window_closed" \
					or outcome_id != "empty_queues_locked" \
					or not actor_id.is_empty() or not action_id.is_empty() \
					or not intent_id.is_empty() or not intent_fingerprint.is_empty() \
					or not _receipt_resolution_detail_is_empty(receipt):
				return "state_receipt_close_binding_invalid"
		"settle_next_action", "settle_invalid_target":
			var expected_reason := "action_settled" \
				if operation_id == "settle_next_action" \
				else "invalid_target_resolved"
			if receipt.get("reason_code") != expected_reason \
					or not player_ids.has(actor_id) or not _stable_id(action_id) \
					or outcome_id not in SETTLEMENT_OUTCOMES \
					or not intent_id.is_empty() or not intent_fingerprint.is_empty():
				return "state_receipt_settlement_binding_invalid"
			var player := (state.get("players") as Dictionary).get(actor_id) as Dictionary
			var action := _action_by_id(player, action_id)
			var result_record := _receipt_action_result(receipt)
			if action.is_empty() \
					or not _action_result_error(result_record, action).is_empty() \
					or (player.get("action_results") as Dictionary).get(action_id) \
						!= result_record \
					or (
						operation_id == "settle_next_action" \
						and not DIRECT_SETTLEMENT_OUTCOMES.has(outcome_id)
					) \
					or (
						operation_id == "settle_invalid_target" \
						and not INVALID_TARGET_OUTCOME_BY_POLICY.values().has(outcome_id)
					):
				return "state_receipt_settlement_result_invalid"
		"refresh_assets_after_batch":
			if receipt.get("reason_code") != "frozen_snapshot_applied" \
					or outcome_id != "assets_refreshed" \
					or not actor_id.is_empty() or not action_id.is_empty() \
					or not intent_id.is_empty() or not intent_fingerprint.is_empty() \
					or not _receipt_resolution_detail_is_empty(receipt):
				return "state_receipt_refresh_binding_invalid"
		_:
			return "state_receipt_operation_invalid"
	return ""


static func _receipt(
	state: Dictionary,
	operation_id: String,
	accepted: bool,
	reason_code: String,
	actor_id: String,
	action_id: String,
	outcome_id: String,
	intent_id: String = "",
	intent_fingerprint: String = "",
	resolution_detail: Dictionary = {}
) -> Dictionary:
	var receipt := {
		"schema_version": SCHEMA_VERSION,
		"contract_id": INTERNAL_RECEIPT_ID,
		"receipt_id": "%s.receipt.%d" % [state.get("batch_id", "batch"), state.get("revision", 0)],
		"batch_id": str(state.get("batch_id", "")),
		"lineage_fingerprint": str(state.get(
			"lineage_fingerprint",
			_fingerprint({"batch_id": str(state.get("batch_id", "invalid.batch"))})
		)),
		"operation_id": operation_id,
		"accepted": accepted,
		"reason_code": reason_code,
		"state_revision": int(state.get("revision", 0)),
		"actor_id": actor_id,
		"action_id": action_id,
		"outcome_id": outcome_id,
		"invalid_target_policy_id": str(resolution_detail.get(
			"invalid_target_policy_id",
			"none"
		)),
		"public_history_reason_code": str(resolution_detail.get(
			"reason_code",
			"none"
		)),
		"asset_refund_applied": bool(resolution_detail.get(
			"asset_refund_applied",
			false
		)),
		"normal_card_destination": str(resolution_detail.get(
			"normal_card_destination",
			"none"
		)),
		"action_slot_refunded": bool(resolution_detail.get(
			"action_slot_refunded",
			false
		)),
		"intent_id": intent_id,
		"intent_fingerprint": intent_fingerprint,
	}
	receipt["receipt_fingerprint"] = _fingerprint(receipt)
	return receipt


static func _receipt_error(value: Variant) -> String:
	if not (value is Dictionary) or not _is_pure_data(value) \
			or not _exact_fields(value as Dictionary, RECEIPT_FIELDS):
		return "receipt_fields_invalid"
	var receipt := value as Dictionary
	if receipt.get("schema_version") != SCHEMA_VERSION \
			or str(receipt.get("contract_id", "")) != INTERNAL_RECEIPT_ID \
			or not _stable_id(receipt.get("receipt_id")) \
			or not _stable_id(receipt.get("batch_id")) \
			or not _fingerprint_valid(receipt.get("lineage_fingerprint")) \
			or not _stable_id(receipt.get("operation_id")) \
			or not (receipt.get("accepted") is bool) \
			or not _stable_id(receipt.get("reason_code")) \
			or not _nonnegative_integer(receipt.get("state_revision")) \
			or not (["none"] + INVALID_TARGET_POLICY_IDS).has(str(
				receipt.get("invalid_target_policy_id", "")
			)) \
			or not _stable_id(receipt.get("public_history_reason_code")) \
			or not (receipt.get("asset_refund_applied") is bool) \
			or not ["none", "discard", "not_applicable", "not_attested"].has(str(
				receipt.get("normal_card_destination", "")
			)) \
			or not (receipt.get("action_slot_refunded") is bool) \
			or not (receipt.get("intent_id") is String) \
			or not (receipt.get("intent_fingerprint") is String):
		return "receipt_invalid"
	var intent_id := str(receipt.get("intent_id", ""))
	var intent_fingerprint := str(receipt.get("intent_fingerprint", ""))
	if intent_id.is_empty() != intent_fingerprint.is_empty():
		return "receipt_intent_binding_invalid"
	if not intent_id.is_empty() \
			and (not _stable_id(intent_id) or not _fingerprint_valid(intent_fingerprint)):
		return "receipt_intent_binding_invalid"
	var unsealed := receipt.duplicate(true)
	unsealed.erase("receipt_fingerprint")
	if not _fingerprint_valid(receipt.get("receipt_fingerprint")) \
			or str(receipt.get("receipt_fingerprint", "")) != _fingerprint(unsealed):
		return "receipt_fingerprint_invalid"
	return ""


static func _receipt_action_result(receipt: Dictionary) -> Dictionary:
	return {
		"outcome_id": receipt.get("outcome_id"),
		"reason_code": receipt.get("public_history_reason_code"),
		"invalid_target_policy_id": receipt.get("invalid_target_policy_id"),
		"asset_refund_applied": receipt.get("asset_refund_applied"),
		"normal_card_destination": receipt.get("normal_card_destination"),
		"action_slot_refunded": receipt.get("action_slot_refunded"),
	}


static func _receipt_resolution_detail_is_empty(receipt: Dictionary) -> bool:
	return receipt.get("invalid_target_policy_id") == "none" \
		and receipt.get("public_history_reason_code") == "none" \
		and receipt.get("asset_refund_applied") == false \
		and receipt.get("normal_card_destination") == "none" \
		and receipt.get("action_slot_refunded") == false


static func _receipt_by_id(receipts: Array, receipt_id: String) -> Dictionary:
	for receipt_variant in receipts:
		if receipt_variant is Dictionary \
				and str((receipt_variant as Dictionary).get("receipt_id", "")) == receipt_id:
			return (receipt_variant as Dictionary).duplicate(true)
	return {}


static func _success(state: Dictionary, receipt: Dictionary) -> Dictionary:
	return {
		"accepted": true,
		"reason_code": str(receipt.get("reason_code", "accepted")),
		"state": state.duplicate(true),
		"receipt": receipt.duplicate(true),
	}


static func _failure(
	state: Dictionary,
	operation_id: String,
	reason_code: String,
	actor_id: String = "",
	action_id: String = ""
) -> Dictionary:
	var safe_state := state.duplicate(true) if state is Dictionary else {}
	var receipt_state := safe_state if not safe_state.is_empty() else {
		"batch_id": "invalid.batch",
		"revision": 0,
	}
	var receipt := _receipt(
		receipt_state,
		operation_id,
		false,
		reason_code,
		actor_id,
		action_id,
		"rejected"
	)
	return {
		"accepted": false,
		"reason_code": reason_code,
		"state": safe_state,
		"receipt": receipt,
	}


static func _saved_envelope_error(
	value: Variant,
	schema_id: String,
	fingerprint_field: String
) -> String:
	if not (value is Dictionary) or not _is_pure_data(value):
		return "save_not_pure_data"
	var envelope := value as Dictionary
	if not _exact_fields(
		envelope,
		[
			"schema_version",
			"state_version",
			"schema_id",
			"ruleset_id",
			"balance_profile_id",
			"balance_profile_fingerprint",
			"default_invalid_target_policy_id",
			"max_asset_refresh_per_color_per_batch",
			"state",
			fingerprint_field,
		]
	):
		return "save_fields_invalid"
	if envelope.get("schema_version") != SCHEMA_VERSION \
			or envelope.get("state_version") != STATE_VERSION \
			or str(envelope.get("schema_id", "")) != schema_id \
			or str(envelope.get("ruleset_id", "")) != RULESET_ID \
			or str(envelope.get("balance_profile_id", "")) != BALANCE_PROFILE_ID \
			or str(envelope.get("balance_profile_fingerprint", "")) \
				!= BALANCE_PROFILE_FINGERPRINT \
			or str(envelope.get("default_invalid_target_policy_id", "")) \
				!= DEFAULT_INVALID_TARGET_POLICY_ID \
			or int(envelope.get("max_asset_refresh_per_color_per_batch", -1)) \
				!= MAX_ASSET_REFRESH_PER_COLOR_PER_BATCH:
		return "save_schema_invalid"
	var unsealed := envelope.duplicate(true)
	unsealed.erase(fingerprint_field)
	if not _fingerprint_valid(envelope.get(fingerprint_field)) \
			or str(envelope.get(fingerprint_field, "")) != _fingerprint(unsealed):
		return "save_fingerprint_invalid"
	if not (envelope.get("state") is Dictionary):
		return "save_state_invalid"
	var state := envelope.get("state") as Dictionary
	if state.get("balance_profile_id") != envelope.get("balance_profile_id") \
			or state.get("balance_profile_fingerprint") \
				!= envelope.get("balance_profile_fingerprint") \
			or state.get("default_invalid_target_policy_id") \
				!= envelope.get("default_invalid_target_policy_id") \
			or state.get("max_asset_refresh_per_color_per_batch") \
				!= envelope.get("max_asset_refresh_per_color_per_batch"):
		return "save_context_binding_invalid"
	var state_error := _state_error(state)
	return "" if state_error.is_empty() else "save_state_invalid"


static func _cost_map_valid(value: Variant) -> bool:
	if not (value is Dictionary) or not _exact_fields(value as Dictionary, COLORS + ["any"]):
		return false
	for key in COLORS + ["any"]:
		if not _nonnegative_integer((value as Dictionary).get(key)) \
				or int((value as Dictionary).get(key, 0)) > ASSET_CAP:
			return false
	return true


static func _color_map_valid(value: Variant, minimum: int, maximum: int) -> bool:
	if not (value is Dictionary) or not _exact_fields(value as Dictionary, COLORS):
		return false
	for color in COLORS:
		var amount: Variant = (value as Dictionary).get(color)
		if not _safe_integer(amount) or int(amount) < minimum or int(amount) > maximum:
			return false
	return true


static func _zero_color_map() -> Dictionary:
	var result := {}
	for color in COLORS:
		result[color] = 0
	return result


static func _all_action_ids(state: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for player_variant in (state.get("players") as Dictionary).values():
		for action_variant in (player_variant as Dictionary).get("local_queue") as Array:
			result.append(str((action_variant as Dictionary).get("action_id", "")))
	return result


static func _increment_revision(state: Dictionary) -> void:
	state["revision"] = int(state.get("revision", 0)) + 1


static func _seal(unsealed: Dictionary, fingerprint_field: String) -> Dictionary:
	if not _is_pure_data(unsealed) or unsealed.has(fingerprint_field):
		return {}
	var sealed := unsealed.duplicate(true)
	sealed[fingerprint_field] = _fingerprint(sealed)
	return sealed


static func _fingerprint(value: Variant) -> String:
	var canonical := _canonical_json(value)
	return canonical.sha256_text().to_lower() if not canonical.is_empty() else ""


static func _canonical_json(value: Variant) -> String:
	if not _is_pure_data(value):
		return ""
	if value is String or value is bool or value is int:
		return JSON.stringify(value)
	if value is Array:
		var parts: Array[String] = []
		for item_variant in value as Array:
			parts.append(_canonical_json(item_variant))
		return "[" + ",".join(parts) + "]"
	var source := value as Dictionary
	var keys: Array[String] = []
	for key_variant in source.keys():
		keys.append(str(key_variant))
	keys.sort()
	var members: Array[String] = []
	for key in keys:
		members.append(JSON.stringify(key) + ":" + _canonical_json(source.get(key)))
	return "{" + ",".join(members) + "}"


static func _fingerprint_valid(value: Variant) -> bool:
	if not (value is String) or str(value).length() != 64:
		return false
	for index in range(str(value).length()):
		var code := str(value).unicode_at(index)
		if not ((code >= 48 and code <= 57) or (code >= 97 and code <= 102)):
			return false
	return true


static func _is_pure_data(value: Variant, depth: int = 0) -> bool:
	if depth > 64:
		return false
	if value == null or value is String or value is bool or value is int:
		return not (value is int) or _safe_integer(value)
	if value is Array:
		for item_variant in value as Array:
			if not _is_pure_data(item_variant, depth + 1):
				return false
		return true
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if not (key_variant is String) \
					or not _is_pure_data((value as Dictionary).get(key_variant), depth + 1):
				return false
		return true
	return false


static func _safe_integer(value: Variant) -> bool:
	return value is int and int(value) >= -MAX_SAFE_INTEGER and int(value) <= MAX_SAFE_INTEGER


static func _nonnegative_integer(value: Variant) -> bool:
	return _safe_integer(value) and int(value) >= 0


static func _positive_integer(value: Variant) -> bool:
	return _safe_integer(value) and int(value) > 0


static func _stable_id(value: Variant) -> bool:
	if not (value is String):
		return false
	var text := str(value)
	if text.is_empty() or text.length() > 160:
		return false
	var previous_separator := false
	for index in range(text.length()):
		var code := text.unicode_at(index)
		var lower := code >= 97 and code <= 122
		var digit := code >= 48 and code <= 57
		var separator := code == 46 or code == 95 or code == 45
		if index == 0 and not lower:
			return false
		if not lower and not digit and not separator:
			return false
		if separator and previous_separator:
			return false
		previous_separator = separator
	return not previous_separator


static func _string_id_array(value: Variant, allow_empty: bool) -> Array[String]:
	var result: Array[String] = []
	if not (value is Array):
		return result
	for item_variant in value as Array:
		if not _stable_id(item_variant) or result.has(str(item_variant)):
			return []
		result.append(str(item_variant))
	if not allow_empty and result.is_empty():
		return []
	return result


static func _exact_fields(value: Dictionary, fields: Array) -> bool:
	if value.size() != fields.size():
		return false
	for field_variant in fields:
		if not value.has(str(field_variant)):
			return false
	return true


static func _exact_keys(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size():
		return false
	for key_variant in keys:
		if not value.has(str(key_variant)):
			return false
	return true


static func _same_string_set(left: Array[String], right: Array[String]) -> bool:
	if left.size() != right.size():
		return false
	var left_sorted := left.duplicate()
	var right_sorted := right.duplicate()
	left_sorted.sort()
	right_sorted.sort()
	return left_sorted == right_sorted
