extends RefCounted
class_name V07DbgDeckCore

## Frozen V0.7.1 personal DBG reference authority. The live state, checkpoints,
## projections, intents, receipts, and Save payloads are closed pure data.

const TrackCore := preload("res://scripts/v07_semantic/v07_unified_card_track_core.gd")

const SCHEMA_VERSION := 2
const STATE_VERSION := 2
const HAND_LIMIT := 5
const COMMODITY_INVENTORY_LIMIT := 5
const MAX_CARD_LEVEL := 4
const MAX_COMMODITY_LEVEL := 3
const DOMAIN_ID := "v07.personal_dbg"
const RULESET_ID := "v0.7.1"
const STARTER_SHUFFLE_DRAW_COUNT := 11
const RNG_ALGORITHM_ID := "sha256.owner_bound_counter.v1"
const RNG_AUTHORITY_OWNER_ID := "v071.personal_dbg.core_authority.v2"
const BALANCE_PROFILE_ID := "V071_CANDIDATE_A_FAST"
const BALANCE_PROFILE_FINGERPRINT := (
	"8d8de8d406ca2f7d5123ecc951a606a0a08b56282bc3d6a40e0cd4d5ff50f19a"
)
const NORMAL_DECK_MINIMUM_TOTAL_CARD_COUNT := 5
const NORMAL_DECK_MINIMUM_COUNT_RULE_VERSION := (
	"v071.normal_merge.minimum_total_five.v1"
)

const CORE_AUTHORITY_SCHEMA_ID := "v071.personal_dbg.core_authority.v2"
const AI_OBSERVATION_SCHEMA_ID := "v071.personal_dbg.ai_observation.v2"
const PLAYER_PROJECTION_SCHEMA_ID := "v071.personal_dbg.player_projection.v2"
const INTENT_SCHEMA_ID := "v071.personal_dbg.intent.v2"
const RECEIPT_SCHEMA_ID := "v071.personal_dbg.authoritative_receipt.v2"
const SAVE_SCHEMA_ID := "v071.personal_dbg.save_state.v2"
const CHECKPOINT_SCHEMA_ID := "v071.personal_dbg.checkpoint.v2"

const NORMAL_DECK_STATE_CONTRACT_ID := "V071NormalDeckState"
const NORMAL_HAND_STATE_CONTRACT_ID := "V071NormalHandState"
const NORMAL_DISCARD_STATE_CONTRACT_ID := "V071NormalDiscardState"
const NORMAL_MERGE_STATE_CONTRACT_ID := "V071NormalMergeState"
const COMMODITY_INVENTORY_STATE_CONTRACT_ID := "V071CommodityInventoryState"
const BOUND_SOURCE_STATE_CONTRACT_ID := "V071BoundSourceLifecycleState"
const LOCAL_QUEUE_STATE_CONTRACT_ID := "V071LocalQueueState"
const TYPED_STATE_CONTRACT_FIELDS := [
	"normal_deck_state",
	"normal_hand_state",
	"normal_discard_state",
	"normal_merge_state",
	"commodity_inventory_state",
	"bound_source_state",
	"local_queue_state",
]

const PHASE_BATCH := "batch_active"
const PHASE_MAINTENANCE := "hand_maintenance"

const ACTION_PLAY_CARD := "play_card"
const ACTION_ACCEPT_PURCHASE := "accept_purchase"
const ACTION_COMPLETE_BATCH := "complete_batch"
const ACTION_MERGE_CARDS := "merge_cards"
const ACTION_ACCEPT_COMMODITY_CLAIM := "accept_commodity_track_claim"
const ACTION_MERGE_COMMODITIES := "merge_commodities"
const ACTION_LOCK_LOCAL_QUEUE := "lock_local_queue"
const ACTION_END_MAINTENANCE := "end_maintenance"

const DECISION_PLAYER_EXPLICIT := "player_explicit"
const DECISION_AUTHORITY := "authority"
const DECISION_AUTOMATIC := "automatic"

const COLORS := [
	"life",
	"energy",
	"industry",
	"technology",
	"commerce",
	"shipping",
]
const CARD_TYPES := ["factory", "market"]
const ACTION_KINDS := [
	ACTION_PLAY_CARD,
	ACTION_ACCEPT_PURCHASE,
	ACTION_COMPLETE_BATCH,
	ACTION_MERGE_CARDS,
	ACTION_ACCEPT_COMMODITY_CLAIM,
	ACTION_MERGE_COMMODITIES,
	ACTION_LOCK_LOCAL_QUEUE,
	ACTION_END_MAINTENANCE,
]
const CARD_FIELDS := [
	"instance_id",
	"semantic_id",
	"primary_color",
	"card_type",
	"merge_family_id",
	"level",
	"locked",
]
const CARD_SPEC_FIELDS := [
	"semantic_id",
	"primary_color",
	"card_type",
	"merge_family_id",
	"level",
]
const COMMODITY_CARD_FIELDS := [
	"instance_id",
	"owner_player_id",
	"commodity_id",
	"primary_color",
	"level",
	"locked",
	"available_from_batch_id",
	"source_track_instance_ids",
	"claim_receipt_ids",
]
const PROJECTED_COMMODITY_CARD_FIELDS := [
	"instance_id",
	"commodity_id",
	"primary_color",
	"level",
	"locked",
	"available_from_batch_id",
]
const TRACK_CLAIM_RECEIPT_SCHEMA_ID := "v071.unified_track.authoritative_receipt.v2"
const TRACK_CLAIM_INTENT_SCHEMA_ID := "v071.unified_track.intent.v2"
const TRACK_AI_OBSERVATION_SCHEMA_ID := "v071.unified_track.ai_observation.v2"
const TRACK_DOMAIN_ID := "unified_card_track"
const TRACK_CLAIM_ACTION_ID := "claim_visible_commodity"
const TRACK_RECEIPT_AUTHORITY_METHOD := "authoritative_receipt_v1"
const TRACK_AUTHORITY_METHODS := [
	"bind_acquisition_authority_port_v1",
	"prepare_visible_acquisition_v1",
	"commit_prepared_acquisition_v1",
	"rollback_acquisition_transaction_v1",
	"finalize_acquisition_transaction_v1",
	TRACK_RECEIPT_AUTHORITY_METHOD,
	"core_authority_v1",
	"ai_observation_v1",
	"save_state_v1",
]
const ACQUISITION_PARTICIPANT_REQUEST_INTERFACE_ID := (
	"v071.unified_track.acquisition_participant_request.v2"
)
const ACQUISITION_PARTICIPANT_CHECKPOINT_SCHEMA_ID := (
	"v071.personal_dbg.acquisition_participant_checkpoint.v2"
)
const ACQUISITION_PARTICIPANT_REQUEST_FIELDS := [
	"schema_version",
	"interface_id",
	"ruleset_id",
	"domain_id",
	"transaction_id",
	"participant_role",
	"authority_id",
	"reservation_kind",
	"request_id",
	"actor_id",
	"action_id",
	"source_identity",
	"destination_zone",
	"proposal_fingerprint",
	"request_fingerprint",
]
const ACQUISITION_PARTICIPANT_CHECKPOINT_FIELDS := [
	"schema_id",
	"schema_version",
	"state_version",
	"ruleset_id",
	"balance_profile_id",
	"balance_profile_fingerprint",
	"authority_id",
	"core_checkpoint",
	"reservations",
	"commit_receipts",
	"checkpoint_fingerprint",
]
const ACQUISITION_RESERVATION_FIELDS := [
	"reservation_id",
	"request",
	"source_identity",
	"source_item",
	"dbg_revision",
	"dbg_state_fingerprint",
	"track_match_instance_id",
	"track_lineage_fingerprint",
]
const TRACK_CLAIM_RECEIPT_FIELDS := [
	"schema_version",
	"interface_id",
	"domain_id",
	"request_id",
	"receipt_id",
	"intent_id",
	"action_id",
	"intent_fingerprint",
	"accepted",
	"reason_code",
	"source_revision",
	"result_revision",
	"committed_core_revision",
	"destination_zone",
	"cash_delta",
	"inventory_commit",
	"external_authority_commit_required",
	"public_facts",
	"receipt_fingerprint",
]
const TRACK_CLAIM_INTENT_FIELDS := [
	"schema_version",
	"interface_id",
	"domain_id",
	"request_id",
	"intent_id",
	"actor_id",
	"action_id",
	"source_revision",
	"expected_core_revision",
	"source_core_fingerprint",
	"source_identity",
	"viewer_segment_authorization",
	"parameters",
	"intent_fingerprint",
]
const TRACK_SOURCE_IDENTITY_FIELDS := [
	"schema_version",
	"source_identity_id",
	"source_instance_id",
	"source_definition_id",
	"source_kind",
	"source_track_revision",
	"segment_owner_id",
	"identity_fingerprint",
]
const TRACK_VIEWER_AUTHORIZATION_FIELDS := [
	"schema_version",
	"capability_id",
	"authorization_id",
	"authorization_authority_id",
	"authorized_actor_id",
	"authorized_source_identity_id",
	"authorized_source_instance_id",
	"authorized_segment_owner_id",
	"source_track_revision",
	"inventory_authority_id",
	"cash_authority_id",
	"authorization_fingerprint",
]
const TRACK_PROJECTION_FIELDS := [
	"schema_version",
	"interface_id",
	"ruleset_id",
	"state_version",
	"balance_profile_id",
	"balance_profile_fingerprint",
	"domain_id",
	"source_revision",
	"source_core_fingerprint",
	"viewer_actor_id",
	"public_facts",
	"viewer_private_facts",
	"projection_fingerprint",
]
const TRACK_PUBLIC_FACT_FIELDS := [
	"single_unified_track",
	"allowed_card_kinds",
	"track_revision",
	"scroll_sequence",
	"unified_track_item_count",
	"balance_profile_id",
	"balance_profile_fingerprint",
	"card_kind_ratio_basis_points",
	"color_cycle_number",
	"color_distribution_basis_points",
	"revealed_stances",
	"completed_batch_count",
	"lead_batch_cursor",
	"lead_tenure_batches",
	"color_cycle_batch_cursor",
	"color_cycle_batches",
	"lead_identity_not_directly_published",
	"lead_identity_may_be_inferred_from_public_information",
]
const TRACK_AI_PRIVATE_FACT_FIELDS := [
	"own_segment_items",
	"own_pending_stance",
	"self_is_current_lead",
	"self_influence_class",
]
const TRACK_VISIBLE_ITEM_FIELDS := [
	"instance_id",
	"card_definition_id",
	"card_kind",
	"level",
	"primary_color",
	"local_slot_index",
	"track_revision",
	"claimable_from_scroll_sequence",
	"claimable",
	"claimability_state",
]
const TRACK_CASH_DELTA_FIELDS := [
	"mode",
	"track_core_committed",
	"amount_known",
	"amount_decimal",
	"external_authority_id",
]
const TRACK_INVENTORY_COMMIT_FIELDS := [
	"track_core_committed",
	"external_authority_id",
	"destination_zone",
]
const TRACK_ACQUISITION_PUBLIC_FACT_FIELDS := [
	"track_item_removed",
	"replacement_count",
	"track_revision",
]
const BOUND_SOURCE_STATE_FIELDS := [
	"schema_version",
	"contract_id",
	"runtime_binding_supported",
	"entries",
]
const BOUND_SOURCE_ENTRY_FIELDS := ["match_instance_id", "lineage_fingerprint"]
const LOCAL_QUEUE_STATE_FIELDS := [
	"schema_version",
	"contract_id",
	"batch_id",
	"locked",
]
const TAGGED_INT64_FIELDS := ["type", "decimal"]
const RNG_FIELDS := [
	"schema_version",
	"stream_id",
	"stream_instance_id",
	"authoritative_owner_id",
	"algorithm_id",
	"seed",
	"cursor",
	"stream_revision",
	"state_fingerprint",
]
const COMMODITY_CLAIM_HISTORY_FIELDS := [
	"claim_receipt_id",
	"claim_receipt_fingerprint",
	"track_intent_id",
	"track_intent_fingerprint",
	"track_instance_id",
	"commodity_instance_id",
	"commodity_id",
	"primary_color",
	"level",
	"claim_batch_id",
	"local_queue_locked_at_claim",
	"available_from_batch_id",
	"revision",
]
const COMMODITY_MERGE_HISTORY_FIELDS := [
	"merge_id",
	"request_id",
	"source_instance_ids",
	"result_instance_id",
	"commodity_id",
	"primary_color",
	"result_level",
	"available_from_batch_id",
	"revision",
]
const STATE_FIELDS := [
	"schema_version",
	"state_version",
	"ruleset_id",
	"balance_profile_id",
	"balance_profile_fingerprint",
	"domain_id",
	"owner_player_id",
	"root_seed",
	"revision",
	"phase",
	"batch_index",
	"draw_pile",
	"hand",
	"committed_escrow",
	"discard",
	"merge_history",
	"next_instance_sequence",
	"commodity_inventory",
	"commodity_claim_history",
	"commodity_merge_history",
	"next_commodity_instance_sequence",
	"bound_source_state",
	"local_queue_state",
	"normal_deck_minimum_count_rule_version",
	"starter_rng",
	"reshuffle_rng",
	"processed_intent_ids",
	"receipt_journal",
]
const CORE_AUTHORITY_FIELDS := [
	"schema_id",
	"schema_version",
	"state_version",
	"ruleset_id",
	"balance_profile_id",
	"balance_profile_fingerprint",
	"domain_id",
	"privacy_scope",
	"typed_state_contracts",
	"state",
	"document_section",
	"state_fingerprint",
	"core_fingerprint",
]
const DOCUMENT_SECTION_FIELDS := [
	"section_id",
	"section_version",
	"state_version",
	"ruleset_id",
	"balance_profile_id",
	"balance_profile_fingerprint",
	"semantic_owner",
	"privacy",
	"state_revision",
	"players",
	"merge_instance_allocator_cursor",
	"processed_intent_ids",
	"receipt_ledger",
	"rng_stream_states",
]
const DOCUMENT_PLAYER_FIELDS := [
	"player_id",
	"draw_pile_order",
	"hand",
	"committed_escrow",
	"discard_order",
	"merge_results_and_lineage",
	"commodity_inventory",
	"bound_source_state",
	"local_queue_state",
	"normal_deck_minimum_count_rule_version",
	"zone_revision",
]
const PROJECTION_FIELDS := [
	"schema_id",
	"schema_version",
	"state_version",
	"ruleset_id",
	"balance_profile_id",
	"balance_profile_fingerprint",
	"domain_id",
	"visibility_scope",
	"revision",
	"core_fingerprint",
	"facts",
	"facts_fingerprint",
	"allowed_intent_kinds",
]
const VIEWER_FACT_FIELDS := [
	"phase",
	"batch_index",
	"balance_profile_id",
	"balance_profile_fingerprint",
	"normal_deck_total_card_count",
	"normal_deck_minimum_total_card_count",
	"normal_deck_minimum_count_rule_version",
	"local_queue_state",
	"hand",
	"hand_count",
	"draw_pile_count",
	"discard",
	"discard_count",
	"committed_escrow_count",
	"merge_history_count",
	"eligible_merge_pairs",
	"commodity_inventory",
	"commodity_inventory_count",
	"commodity_merge_history_count",
	"eligible_commodity_merge_pairs",
	"bound_source_state",
]
const INTENT_FIELDS := [
	"schema_id",
	"schema_version",
	"state_version",
	"ruleset_id",
	"balance_profile_id",
	"balance_profile_fingerprint",
	"domain_id",
	"privacy_scope",
	"request_id",
	"actor_player_id",
	"action_kind",
	"source_revision",
	"source_core_fingerprint",
	"decision_mode",
	"arguments",
	"intent_fingerprint",
]
const RECEIPT_FIELDS := [
	"schema_id",
	"schema_version",
	"state_version",
	"ruleset_id",
	"balance_profile_id",
	"balance_profile_fingerprint",
	"domain_id",
	"visibility_scope",
	"request_id",
	"action_kind",
	"intent_fingerprint",
	"source_core_fingerprint",
	"result_core_fingerprint",
	"success",
	"reason_code",
	"revision_before",
	"revision_after",
	"changed_instance_ids",
	"created_instance_id",
	"destination_zone",
	"hand_count",
	"draw_pile_count",
	"discard_count",
	"commodity_inventory_count",
	"refill_count",
	"reshuffle_count",
	"receipt_fingerprint",
]
const RESULT_FIELDS := [
	"success",
	"reason_code",
	"changed_instance_ids",
	"created_instance_id",
	"destination_zone",
	"refill_count",
	"reshuffle_count",
]
const CHECKPOINT_FIELDS := [
	"schema_id",
	"schema_version",
	"state_version",
	"ruleset_id",
	"balance_profile_id",
	"balance_profile_fingerprint",
	"state",
	"state_fingerprint",
]
const SAVE_FIELDS := [
	"schema_id",
	"schema_version",
	"state_version",
	"ruleset_id",
	"balance_profile_id",
	"balance_profile_fingerprint",
	"domain_id",
	"privacy_scope",
	"typed_state_contracts",
	"state",
	"document_section",
	"state_fingerprint",
	"core_fingerprint",
]
const THREE_WING_CONTRACT_FIELDS := [
	"schema_version",
	"state_version",
	"ruleset_id",
	"balance_profile_id",
	"balance_profile_fingerprint",
	"domain_id",
	"core_authority_schema_id",
	"ai_observation_schema_id",
	"player_projection_schema_id",
	"intent_schema_id",
	"authoritative_receipt_schema_id",
	"save_state_schema_id",
	"typed_state_contracts",
	"shared_fact_binding_field",
	"rng_stream_ids",
	"player_merge_choice_required",
	"automatic_merge_allowed",
	"mid_batch_refill_allowed",
	"save_is_second_authority",
	"commodity_inventory_limit",
	"commodity_merge_edges",
	"bound_source_runtime_binding_supported",
	"normal_deck_minimum_total_card_count",
	"normal_deck_minimum_count_rule_version",
	"commodity_available_from_batch_field",
	"local_queue_state_contract_id",
]
const PRIVATE_PROJECTION_KEYS := [
	"owner_player_id",
	"root_seed",
	"draw_pile",
	"discard_order",
	"committed_escrow",
	"starter_rng",
	"reshuffle_rng",
	"seed",
	"cursor",
	"stream_revision",
	"state_fingerprint",
	"rng_state",
	"rng_seed",
	"receipt_journal",
	"save_state",
	"save_payload",
	"checkpoint",
	"other_hand",
	"other_player_hand",
	"other_commodity_inventory",
	"commodity_claim_history",
	"commodity_merge_history",
	"source_track_instance_ids",
	"claim_receipt_ids",
	"processed_intent_ids",
	"future_draw",
]

var _state: Dictionary = {}
var _track_receipt_authority: RefCounted = null
var _commodity_slot_reservations: Dictionary = {}
var _commodity_slot_commit_receipts: Dictionary = {}


func initialize(owner_player_id: String, fixed_seed: int) -> Dictionary:
	_track_receipt_authority = null
	_commodity_slot_reservations = {}
	_commodity_slot_commit_receipts = {}
	if not _stable_id(owner_player_id):
		return {"initialized": false, "reason_code": "owner_player_id_invalid"}
	var starter_rng := _new_rng_cursor(
		"starter_deck_shuffle", owner_player_id, fixed_seed
	)
	var reshuffle_rng := _new_rng_cursor(
		"normal_deck_reshuffle_by_player", owner_player_id, fixed_seed
	)
	var cards: Array = []
	var sequence := 1
	for spec_variant in starter_card_specs():
		var spec := spec_variant as Dictionary
		cards.append(_card_from_spec(spec, _instance_id(owner_player_id, sequence)))
		sequence += 1
	var shuffled := _shuffle_cards(cards, starter_rng)
	var draw_pile: Array = (shuffled.get("cards", []) as Array).duplicate(true)
	var hand: Array = []
	while hand.size() < HAND_LIMIT:
		hand.append(draw_pile.pop_back())
	_state = {
		"schema_version": SCHEMA_VERSION,
		"state_version": STATE_VERSION,
		"ruleset_id": RULESET_ID,
		"balance_profile_id": BALANCE_PROFILE_ID,
		"balance_profile_fingerprint": BALANCE_PROFILE_FINGERPRINT,
		"domain_id": DOMAIN_ID,
		"owner_player_id": owner_player_id,
		"root_seed": _tagged_int64(fixed_seed),
		"revision": 0,
		"phase": PHASE_BATCH,
		"batch_index": 1,
		"draw_pile": draw_pile,
		"hand": hand,
		"committed_escrow": [],
		"discard": [],
		"merge_history": [],
		"next_instance_sequence": sequence,
		"commodity_inventory": [],
		"commodity_claim_history": [],
		"commodity_merge_history": [],
		"next_commodity_instance_sequence": 1,
		"bound_source_state": _empty_bound_source_state(),
		"local_queue_state": _new_local_queue_state(1, false),
		"normal_deck_minimum_count_rule_version": (
			NORMAL_DECK_MINIMUM_COUNT_RULE_VERSION
		),
		"starter_rng": (shuffled.get("cursor", {}) as Dictionary).duplicate(true),
		"reshuffle_rng": reshuffle_rng,
		"processed_intent_ids": [],
		"receipt_journal": {},
	}
	if not _state_valid(_state):
		_state = {}
		return {"initialized": false, "reason_code": "starter_state_invalid"}
	return {
		"initialized": true,
		"reason_code": "starter_deck_initialized",
		"card_count": _all_cards(_state).size(),
		"hand_count": hand.size(),
		"draw_pile_count": draw_pile.size(),
		"state_fingerprint": _fingerprint(_state),
	}


func is_ready() -> bool:
	return not _state.is_empty() and _state_valid(_state)


func bind_unified_track_receipt_authority(authority: RefCounted) -> Dictionary:
	var contract_reason := _track_authority_contract_reason(authority)
	if not contract_reason.is_empty():
		return {
			"bound": false,
			"reason_code": contract_reason,
		}
	var descriptor := _track_authority_descriptor(authority)
	if descriptor.is_empty():
		return {
			"bound": false,
			"reason_code": "track_receipt_authority_lineage_invalid",
		}
	if _track_receipt_authority != null:
		if _track_receipt_authority != authority:
			return {
				"bound": false,
				"reason_code": "track_receipt_authority_live_replacement_forbidden",
			}
		if not _descriptor_matches_bound_source(descriptor):
			return {
				"bound": false,
				"reason_code": "track_receipt_authority_lineage_mismatch",
			}
		return {
			"bound": true,
			"reason_code": "track_receipt_authority_already_bound",
		}
	var bound_entry := _bound_source_entry(_state.get("bound_source_state"))
	if bound_entry.is_empty():
		var state_before := _state.duplicate(true)
		_state["bound_source_state"] = _bound_source_state_for_descriptor(descriptor)
		if not _state_valid(_state):
			_state = state_before
			return {
				"bound": false,
				"reason_code": "track_receipt_authority_pin_invalid",
			}
	elif not _descriptor_matches_bound_source(descriptor):
		return {
			"bound": false,
			"reason_code": "track_receipt_authority_lineage_mismatch",
		}
	_track_receipt_authority = authority
	return {
		"bound": true,
		"reason_code": "track_receipt_authority_bound",
	}


func unbind_unified_track_receipt_authority() -> Dictionary:
	_track_receipt_authority = null
	return {
		"bound": false,
		"reason_code": "track_receipt_authority_unbound",
	}


func acquisition_authority_id_v1() -> String:
	return RNG_AUTHORITY_OWNER_ID


func prepare_acquisition_v1(request: Dictionary) -> Dictionary:
	var transaction_id := str(request.get("transaction_id", ""))
	var state_fingerprint_before := _fingerprint(_state) if is_ready() else ""
	if not is_ready():
		return _participant_operation(
			false, "commodity_slot_core_not_initialized", "", transaction_id
		)
	var request_reason := _acquisition_participant_request_reason(request)
	if not request_reason.is_empty():
		return _participant_operation(false, request_reason, "", transaction_id)
	if _track_receipt_authority == null:
		return _participant_operation(
			false, "track_receipt_authority_unbound", "", transaction_id
		)
	var descriptor := _track_authority_descriptor(_track_receipt_authority)
	if descriptor.is_empty() or not _descriptor_matches_bound_source(descriptor):
		return _participant_operation(
			false, "track_receipt_authority_lineage_mismatch", "", transaction_id
		)
	for reservation_variant in _commodity_slot_reservations.values():
		var existing := reservation_variant as Dictionary
		var existing_request := existing.get("request", {}) as Dictionary
		if str(existing_request.get("transaction_id", "")) != transaction_id:
			continue
		if existing_request != request:
			return _participant_operation(
				false, "acquisition_transaction_collision", "", transaction_id
			)
		return _participant_operation(
			true,
			"commodity_slot_already_reserved",
			str(existing.get("reservation_id", "")),
			transaction_id
		)
	var inventory := _state.get("commodity_inventory", []) as Array
	if inventory.size() + _commodity_slot_reservations.size() >= COMMODITY_INVENTORY_LIMIT:
		return _participant_operation(
			false, "commodity_inventory_full", "", transaction_id
		)
	var source_identity := request.get("source_identity", {}) as Dictionary
	var duplicate_reason := _reserved_or_consumed_source_reason(
		str(request.get("request_id", "")),
		str(source_identity.get("source_instance_id", ""))
	)
	if not duplicate_reason.is_empty():
		return _participant_operation(false, duplicate_reason, "", transaction_id)
	var observation_variant: Variant = _track_receipt_authority.call(
		"ai_observation_v1",
		str(request.get("actor_id", ""))
	)
	if not (observation_variant is Dictionary):
		return _participant_operation(
			false, "track_source_observation_invalid", "", transaction_id
		)
	var observation := observation_variant as Dictionary
	if not _track_ai_observation_reason(observation).is_empty():
		return _participant_operation(
			false, "track_source_observation_invalid", "", transaction_id
		)
	var source_item := _track_visible_item_for_source(
		observation,
		str(source_identity.get("source_instance_id", ""))
	)
	if source_item.is_empty() \
			or source_item.get("card_definition_id") \
			!= source_identity.get("source_definition_id") \
			or source_item.get("card_kind") != "commodity_card" \
			or source_item.get("track_revision") \
			!= source_identity.get("source_track_revision"):
		return _participant_operation(
			false, "track_claim_source_binding_invalid", "", transaction_id
		)
	var reservation_id := "reservation.personal_dbg.%s" % _fingerprint(request).left(32)
	var reservation := {
		"reservation_id": reservation_id,
		"request": request.duplicate(true),
		"source_identity": source_identity.duplicate(true),
		"source_item": source_item.duplicate(true),
		"dbg_revision": int(_state.get("revision", 0)),
		"dbg_state_fingerprint": state_fingerprint_before,
		"track_match_instance_id": str(descriptor.get("match_instance_id", "")),
		"track_lineage_fingerprint": str(descriptor.get("lineage_fingerprint", "")),
	}
	if not _acquisition_reservation_valid(reservation):
		return _participant_operation(
			false, "commodity_slot_reservation_invalid", "", transaction_id
		)
	_commodity_slot_reservations[reservation_id] = reservation
	if _fingerprint(_state) != state_fingerprint_before:
		_commodity_slot_reservations.erase(reservation_id)
		return _participant_operation(
			false, "commodity_slot_prepare_mutated_state", "", transaction_id
		)
	return _participant_operation(
		true, "commodity_slot_reserved", reservation_id, transaction_id
	)


func commit_prepared_acquisition_v1(
	reservation_id: String,
	track_receipt: Dictionary
) -> Dictionary:
	var transaction_id := _transaction_id_for_reservation(reservation_id)
	if _commodity_slot_commit_receipts.has(reservation_id):
		var committed := _commodity_slot_commit_receipts.get(
			reservation_id, {}
		) as Dictionary
		if str(committed.get("track_receipt_fingerprint", "")) \
				!= str(track_receipt.get("receipt_fingerprint", "")):
			return _participant_operation(
				false,
				"reservation_receipt_collision",
				reservation_id,
				transaction_id
			)
		return committed.duplicate(true)
	if not _commodity_slot_reservations.has(reservation_id):
		return _participant_operation(
			false,
			"commodity_slot_reservation_missing",
			reservation_id,
			transaction_id
		)
	var reservation := _commodity_slot_reservations.get(reservation_id, {}) as Dictionary
	if not _acquisition_reservation_valid(reservation):
		return _participant_operation(
			false,
			"commodity_slot_reservation_invalid",
			reservation_id,
			transaction_id
		)
	if int(_state.get("revision", -1)) != int(reservation.get("dbg_revision", -2)) \
			or _fingerprint(_state) \
			!= str(reservation.get("dbg_state_fingerprint", "")):
		return _participant_operation(
			false,
			"commodity_slot_reservation_stale",
			reservation_id,
			transaction_id
		)
	var receipt_reason := _track_receipt_for_reservation_reason(
		track_receipt,
		reservation
	)
	if not receipt_reason.is_empty():
		return _participant_operation(
			false, receipt_reason, reservation_id, transaction_id
		)
	var internal_request_id := "request.dbg.track_acquisition.%s" % _fingerprint({
		"reservation_id": reservation_id,
		"track_receipt_fingerprint": str(track_receipt.get(
			"receipt_fingerprint", ""
		)),
	}).left(32)
	var dbg_intent := create_authority_intent(
		internal_request_id,
		ACTION_ACCEPT_COMMODITY_CLAIM,
		{
			"reservation_id": reservation_id,
			"track_claim_receipt": track_receipt.duplicate(true),
			"source_identity": (
				reservation.get("source_identity", {}) as Dictionary
			).duplicate(true),
			"source_item": (
				reservation.get("source_item", {}) as Dictionary
			).duplicate(true),
		}
	)
	var dbg_receipt := apply_intent(dbg_intent)
	if not bool(dbg_receipt.get("success", false)):
		return _participant_operation(
			false,
			"commodity_slot_finalize_failed.%s" % str(dbg_receipt.get(
				"reason_code", "unknown"
			)),
			reservation_id,
			transaction_id
		)
	var result := {
		"accepted": true,
		"reason_code": "commodity_slot_committed",
		"transaction_id": transaction_id,
		"reservation_id": reservation_id,
		"authority_id": RNG_AUTHORITY_OWNER_ID,
		"participant_role": "commodity_slot",
		"track_receipt_fingerprint": str(track_receipt.get(
			"receipt_fingerprint", ""
		)),
		"commodity_instance_id": str(dbg_receipt.get("created_instance_id", "")),
		"dbg_receipt_fingerprint": str(dbg_receipt.get("receipt_fingerprint", "")),
		"state_fingerprint": _fingerprint(_state),
	}
	result["receipt_fingerprint"] = TrackCore.fingerprint(result)
	_commodity_slot_reservations.erase(reservation_id)
	_commodity_slot_commit_receipts[reservation_id] = result.duplicate(true)
	return result


func abort_prepared_acquisition_v1(
	reservation_id: String,
	_reason_code: String
) -> Dictionary:
	var transaction_id := _transaction_id_for_reservation(reservation_id)
	if _commodity_slot_commit_receipts.has(reservation_id):
		return _participant_operation(
			true,
			"commodity_slot_commit_pending_transaction_rollback",
			reservation_id,
			transaction_id
		)
	if not _commodity_slot_reservations.has(reservation_id):
		if reservation_id.begins_with("reservation.personal_dbg.rejected."):
			return _participant_operation(
				true,
				"commodity_slot_rejected_prepare_released",
				reservation_id,
				transaction_id
			)
		return _participant_operation(
			false,
			"commodity_slot_reservation_missing",
			reservation_id,
			transaction_id
		)
	var state_fingerprint_before := _fingerprint(_state)
	_commodity_slot_reservations.erase(reservation_id)
	if _fingerprint(_state) != state_fingerprint_before:
		return _participant_operation(
			false,
			"commodity_slot_abort_mutated_state",
			reservation_id,
			transaction_id
		)
	return _participant_operation(
		true,
		"commodity_slot_reservation_aborted",
		reservation_id,
		transaction_id
	)


func capture_checkpoint_v1() -> Dictionary:
	var core_checkpoint := capture_checkpoint()
	if core_checkpoint.is_empty():
		return {}
	var checkpoint := {
		"schema_id": ACQUISITION_PARTICIPANT_CHECKPOINT_SCHEMA_ID,
		"schema_version": SCHEMA_VERSION,
		"state_version": STATE_VERSION,
		"ruleset_id": RULESET_ID,
		"balance_profile_id": BALANCE_PROFILE_ID,
		"balance_profile_fingerprint": BALANCE_PROFILE_FINGERPRINT,
		"authority_id": RNG_AUTHORITY_OWNER_ID,
		"core_checkpoint": core_checkpoint,
		"reservations": _commodity_slot_reservations.duplicate(true),
		"commit_receipts": _commodity_slot_commit_receipts.duplicate(true),
	}
	checkpoint["checkpoint_fingerprint"] = _fingerprint(checkpoint)
	return checkpoint


func rollback_v1(checkpoint: Dictionary) -> Dictionary:
	if not _pure_data(checkpoint) \
			or not _exact_fields(
				checkpoint,
				ACQUISITION_PARTICIPANT_CHECKPOINT_FIELDS
			) \
			or checkpoint.get("schema_id") \
			!= ACQUISITION_PARTICIPANT_CHECKPOINT_SCHEMA_ID \
			or checkpoint.get("schema_version") != SCHEMA_VERSION \
			or checkpoint.get("state_version") != STATE_VERSION \
			or checkpoint.get("ruleset_id") != RULESET_ID \
			or checkpoint.get("balance_profile_id") != BALANCE_PROFILE_ID \
			or checkpoint.get("balance_profile_fingerprint") \
			!= BALANCE_PROFILE_FINGERPRINT \
			or checkpoint.get("authority_id") != RNG_AUTHORITY_OWNER_ID \
			or not (checkpoint.get("core_checkpoint") is Dictionary) \
			or not (checkpoint.get("reservations") is Dictionary) \
			or not (checkpoint.get("commit_receipts") is Dictionary) \
			or checkpoint.get("checkpoint_fingerprint") \
			!= _fingerprint_without(checkpoint, "checkpoint_fingerprint"):
		return _participant_operation(
			false,
			"acquisition_checkpoint_invalid",
			"reservation.checkpoint.invalid",
			"transaction.checkpoint"
		)
	var rollback_result := rollback_to_checkpoint(
		checkpoint.get("core_checkpoint", {}) as Dictionary
	)
	if not bool(rollback_result.get("rolled_back", false)):
		return _participant_operation(
			false,
			"acquisition_checkpoint_core_rejected",
			"reservation.checkpoint.invalid",
			"transaction.checkpoint"
		)
	_commodity_slot_reservations = (
		checkpoint.get("reservations", {}) as Dictionary
	).duplicate(true)
	_commodity_slot_commit_receipts = (
		checkpoint.get("commit_receipts", {}) as Dictionary
	).duplicate(true)
	return {
		"accepted": true,
		"rolled_back": true,
		"reason_code": "commodity_slot_checkpoint_restored",
	}


static func starter_card_specs() -> Array:
	var cards: Array = []
	for color_variant in COLORS:
		var color := str(color_variant)
		for card_type_variant in CARD_TYPES:
			var card_type := str(card_type_variant)
			cards.append({
				"semantic_id": "facility.%s.%s.rank_1" % [card_type, color],
				"primary_color": color,
				"card_type": card_type,
				"merge_family_id": "facility.%s.%s" % [card_type, color],
				"level": 1,
			})
	return cards


static func typed_state_contracts() -> Dictionary:
	return {
		"normal_deck_state": NORMAL_DECK_STATE_CONTRACT_ID,
		"normal_hand_state": NORMAL_HAND_STATE_CONTRACT_ID,
		"normal_discard_state": NORMAL_DISCARD_STATE_CONTRACT_ID,
		"normal_merge_state": NORMAL_MERGE_STATE_CONTRACT_ID,
		"commodity_inventory_state": COMMODITY_INVENTORY_STATE_CONTRACT_ID,
		"bound_source_state": BOUND_SOURCE_STATE_CONTRACT_ID,
		"local_queue_state": LOCAL_QUEUE_STATE_CONTRACT_ID,
	}


static func three_wing_contract() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"state_version": STATE_VERSION,
		"ruleset_id": RULESET_ID,
		"balance_profile_id": BALANCE_PROFILE_ID,
		"balance_profile_fingerprint": BALANCE_PROFILE_FINGERPRINT,
		"domain_id": DOMAIN_ID,
		"core_authority_schema_id": CORE_AUTHORITY_SCHEMA_ID,
		"ai_observation_schema_id": AI_OBSERVATION_SCHEMA_ID,
		"player_projection_schema_id": PLAYER_PROJECTION_SCHEMA_ID,
		"intent_schema_id": INTENT_SCHEMA_ID,
		"authoritative_receipt_schema_id": RECEIPT_SCHEMA_ID,
		"save_state_schema_id": SAVE_SCHEMA_ID,
		"typed_state_contracts": typed_state_contracts(),
		"shared_fact_binding_field": "core_fingerprint",
		"rng_stream_ids": [
			"starter_deck_shuffle",
			"normal_deck_reshuffle_by_player",
		],
		"player_merge_choice_required": true,
		"automatic_merge_allowed": false,
		"mid_batch_refill_allowed": false,
		"save_is_second_authority": false,
		"commodity_inventory_limit": COMMODITY_INVENTORY_LIMIT,
		"commodity_merge_edges": ["L1+L1=L2", "L2+L1=L3"],
		"bound_source_runtime_binding_supported": true,
		"normal_deck_minimum_total_card_count": (
			NORMAL_DECK_MINIMUM_TOTAL_CARD_COUNT
		),
		"normal_deck_minimum_count_rule_version": (
			NORMAL_DECK_MINIMUM_COUNT_RULE_VERSION
		),
		"commodity_available_from_batch_field": "available_from_batch_id",
		"local_queue_state_contract_id": LOCAL_QUEUE_STATE_CONTRACT_ID,
	}


func core_authority_snapshot() -> Dictionary:
	if not is_ready():
		return {}
	var state_copy := _state.duplicate(true)
	return {
		"schema_id": CORE_AUTHORITY_SCHEMA_ID,
		"schema_version": SCHEMA_VERSION,
		"state_version": STATE_VERSION,
		"ruleset_id": RULESET_ID,
		"balance_profile_id": BALANCE_PROFILE_ID,
		"balance_profile_fingerprint": BALANCE_PROFILE_FINGERPRINT,
		"domain_id": DOMAIN_ID,
		"privacy_scope": "authority_secret",
		"typed_state_contracts": typed_state_contracts(),
		"state": state_copy,
		"document_section": _document_save_section(state_copy),
		"state_fingerprint": _fingerprint(state_copy),
		"core_fingerprint": _core_fingerprint(state_copy),
	}


func ai_observation(viewer_player_id: String) -> Dictionary:
	if not _viewer_is_owner(viewer_player_id):
		return {}
	var facts := _viewer_private_facts()
	return {
		"schema_id": AI_OBSERVATION_SCHEMA_ID,
		"schema_version": SCHEMA_VERSION,
		"state_version": STATE_VERSION,
		"ruleset_id": RULESET_ID,
		"balance_profile_id": BALANCE_PROFILE_ID,
		"balance_profile_fingerprint": BALANCE_PROFILE_FINGERPRINT,
		"domain_id": DOMAIN_ID,
		"visibility_scope": "actor_private",
		"revision": int(_state.get("revision", 0)),
		"core_fingerprint": _core_fingerprint(_state),
		"facts": facts,
		"facts_fingerprint": _fingerprint(facts),
		"allowed_intent_kinds": _allowed_intent_kinds(),
	}


func player_projection(viewer_player_id: String) -> Dictionary:
	if not _viewer_is_owner(viewer_player_id):
		return {}
	var facts := _viewer_private_facts()
	return {
		"schema_id": PLAYER_PROJECTION_SCHEMA_ID,
		"schema_version": SCHEMA_VERSION,
		"state_version": STATE_VERSION,
		"ruleset_id": RULESET_ID,
		"balance_profile_id": BALANCE_PROFILE_ID,
		"balance_profile_fingerprint": BALANCE_PROFILE_FINGERPRINT,
		"domain_id": DOMAIN_ID,
		"visibility_scope": "viewer_private",
		"revision": int(_state.get("revision", 0)),
		"core_fingerprint": _core_fingerprint(_state),
		"facts": facts,
		"facts_fingerprint": _fingerprint(facts),
		"allowed_intent_kinds": _allowed_intent_kinds(),
	}


func create_intent(
	request_id: String,
	actor_player_id: String,
	action_kind: String,
	arguments: Dictionary = {},
	decision_mode: String = DECISION_PLAYER_EXPLICIT,
	source_revision: int = -1
) -> Dictionary:
	var revision := int(_state.get("revision", -1)) if source_revision < 0 else source_revision
	var intent := {
		"schema_id": INTENT_SCHEMA_ID,
		"schema_version": SCHEMA_VERSION,
		"state_version": STATE_VERSION,
		"ruleset_id": RULESET_ID,
		"balance_profile_id": BALANCE_PROFILE_ID,
		"balance_profile_fingerprint": BALANCE_PROFILE_FINGERPRINT,
		"domain_id": DOMAIN_ID,
		"privacy_scope": "actor_to_authority_private",
		"request_id": request_id,
		"actor_player_id": actor_player_id,
		"action_kind": action_kind,
		"source_revision": revision,
		"source_core_fingerprint": _core_fingerprint(_state),
		"decision_mode": decision_mode,
		"arguments": arguments.duplicate(true),
	}
	intent["intent_fingerprint"] = _fingerprint(intent)
	return intent


func create_authority_intent(
	request_id: String,
	action_kind: String,
	arguments: Dictionary = {},
	source_revision: int = -1
) -> Dictionary:
	return create_intent(
		request_id,
		str(_state.get("owner_player_id", "")),
		action_kind,
		arguments,
		DECISION_AUTHORITY,
		source_revision
	)


func apply_intent(intent: Dictionary) -> Dictionary:
	if not is_ready():
		return _unbound_failure_receipt(intent, "core_not_initialized")
	var shape_reason := _intent_shape_reason(intent)
	if not shape_reason.is_empty():
		return _unbound_failure_receipt(intent, shape_reason)
	var request_id := str(intent.get("request_id", ""))
	var intent_fingerprint := str(intent.get("intent_fingerprint", ""))
	var journal := _state.get("receipt_journal", {}) as Dictionary
	if journal.has(request_id):
		var saved_receipt := journal.get(request_id, {}) as Dictionary
		if str(saved_receipt.get("intent_fingerprint", "")) == intent_fingerprint:
			return saved_receipt.duplicate(true)
		return _unbound_failure_receipt(intent, "request_id_collision")
	if str(intent.get("actor_player_id", "")) != str(_state.get("owner_player_id", "")):
		return _unbound_failure_receipt(intent, "actor_not_authorized")
	if int(intent.get("source_revision", -1)) != int(_state.get("revision", -2)):
		return _unbound_failure_receipt(intent, "source_revision_stale")
	if str(intent.get("source_core_fingerprint", "")) != _core_fingerprint(_state):
		return _unbound_failure_receipt(intent, "source_core_fingerprint_mismatch")

	var state_before := _state.duplicate(true)
	var source_core_fingerprint := _core_fingerprint(state_before)
	var revision_before := int(_state.get("revision", 0))
	var result := _dispatch_intent(intent)
	if not _exact_fields(result, RESULT_FIELDS):
		_state = state_before
		return _unbound_failure_receipt(intent, "core_result_invalid")
	if not bool(result.get("success", false)):
		_state = state_before
		return _build_receipt(
			intent, result, revision_before, source_core_fingerprint
		)
	_state["revision"] = revision_before + 1
	var processed_ids := _state.get("processed_intent_ids", []) as Array
	processed_ids.append(request_id)
	_state["processed_intent_ids"] = processed_ids
	var receipt := _build_receipt(
		intent, result, revision_before, source_core_fingerprint
	)
	journal[request_id] = receipt.duplicate(true)
	_state["receipt_journal"] = journal
	if not _state_valid(_state):
		_state = state_before
		return _unbound_failure_receipt(intent, "postcondition_state_invalid")
	return receipt


func execute_intent(intent: Dictionary) -> Dictionary:
	return apply_intent(intent)


func capture_checkpoint() -> Dictionary:
	if not is_ready():
		return {}
	var state_copy := _state.duplicate(true)
	return {
		"schema_id": CHECKPOINT_SCHEMA_ID,
		"schema_version": SCHEMA_VERSION,
		"state_version": STATE_VERSION,
		"ruleset_id": RULESET_ID,
		"balance_profile_id": BALANCE_PROFILE_ID,
		"balance_profile_fingerprint": BALANCE_PROFILE_FINGERPRINT,
		"state": state_copy,
		"state_fingerprint": _fingerprint(state_copy),
	}


func rollback_to_checkpoint(checkpoint: Dictionary) -> Dictionary:
	if not _exact_fields(checkpoint, CHECKPOINT_FIELDS):
		return {"rolled_back": false, "reason_code": "checkpoint_fields_invalid"}
	if checkpoint.get("schema_id") != CHECKPOINT_SCHEMA_ID \
			or checkpoint.get("schema_version") != SCHEMA_VERSION \
			or checkpoint.get("state_version") != STATE_VERSION \
			or checkpoint.get("ruleset_id") != RULESET_ID \
			or checkpoint.get("balance_profile_id") != BALANCE_PROFILE_ID \
			or checkpoint.get("balance_profile_fingerprint") \
			!= BALANCE_PROFILE_FINGERPRINT:
		return {"rolled_back": false, "reason_code": "checkpoint_schema_invalid"}
	var candidate_variant: Variant = checkpoint.get("state")
	if not (candidate_variant is Dictionary):
		return {"rolled_back": false, "reason_code": "checkpoint_state_invalid"}
	var candidate := candidate_variant as Dictionary
	if str(checkpoint.get("state_fingerprint", "")) != _fingerprint(candidate) \
			or not _state_valid(candidate):
		return {"rolled_back": false, "reason_code": "checkpoint_fingerprint_invalid"}
	if is_ready() and str(candidate.get("owner_player_id", "")) \
			!= str(_state.get("owner_player_id", "")):
		return {"rolled_back": false, "reason_code": "checkpoint_owner_mismatch"}
	if _track_receipt_authority != null:
		var descriptor := _track_authority_descriptor(_track_receipt_authority)
		if descriptor.is_empty() or not _descriptor_matches_bound_source_value(
			descriptor,
			candidate.get("bound_source_state")
		):
			return {
				"rolled_back": false,
				"reason_code": "checkpoint_track_lineage_mismatch",
			}
	_state = candidate.duplicate(true)
	return {
		"rolled_back": true,
		"reason_code": "checkpoint_restored",
		"state_fingerprint": _fingerprint(_state),
	}


func rollback(checkpoint: Dictionary) -> Dictionary:
	return rollback_to_checkpoint(checkpoint)


func to_save_state() -> Dictionary:
	if not is_ready():
		return {}
	var state_copy := _state.duplicate(true)
	return {
		"schema_id": SAVE_SCHEMA_ID,
		"schema_version": SCHEMA_VERSION,
		"state_version": STATE_VERSION,
		"ruleset_id": RULESET_ID,
		"balance_profile_id": BALANCE_PROFILE_ID,
		"balance_profile_fingerprint": BALANCE_PROFILE_FINGERPRINT,
		"domain_id": DOMAIN_ID,
		"privacy_scope": "authority_secret",
		"typed_state_contracts": typed_state_contracts(),
		"state": state_copy,
		"document_section": _document_save_section(state_copy),
		"state_fingerprint": _fingerprint(state_copy),
		"core_fingerprint": _core_fingerprint(state_copy),
	}


func to_save_data() -> Dictionary:
	return to_save_state()


func apply_save_state(save_state: Dictionary) -> Dictionary:
	var reason := validate_save_state(save_state)
	if not reason.is_empty():
		return {"applied": false, "reason_code": reason}
	var normalized_state := _normalize_json_numbers(save_state.get("state", {})) as Dictionary
	if is_ready() and str(normalized_state.get("owner_player_id", "")) \
			!= str(_state.get("owner_player_id", "")):
		return {"applied": false, "reason_code": "save_state_owner_mismatch"}
	_track_receipt_authority = null
	_commodity_slot_reservations = {}
	_commodity_slot_commit_receipts = {}
	_state = normalized_state
	return {
		"applied": true,
		"reason_code": "v071_dbg_save_state_restored",
		"state_fingerprint": _fingerprint(_state),
		"core_fingerprint": _core_fingerprint(_state),
	}


func apply_save_data(save_state: Dictionary) -> Dictionary:
	return apply_save_state(save_state)


static func validate_save_state(save_state: Dictionary) -> String:
	if not _pure_data(save_state) or not _exact_fields(save_state, SAVE_FIELDS):
		return "save_state_fields_invalid"
	if save_state.get("schema_id") != SAVE_SCHEMA_ID \
			or save_state.get("schema_version") != SCHEMA_VERSION \
			or save_state.get("state_version") != STATE_VERSION \
			or save_state.get("ruleset_id") != RULESET_ID \
			or save_state.get("balance_profile_id") != BALANCE_PROFILE_ID \
			or save_state.get("balance_profile_fingerprint") \
			!= BALANCE_PROFILE_FINGERPRINT \
			or save_state.get("domain_id") != DOMAIN_ID \
			or save_state.get("privacy_scope") != "authority_secret":
		return "save_state_schema_invalid"
	if not validate_typed_state_contracts(
		save_state.get("typed_state_contracts")
	).is_empty():
		return "save_state_typed_state_contracts_invalid"
	var state_variant: Variant = save_state.get("state")
	if not (state_variant is Dictionary):
		return "save_state_payload_invalid"
	var candidate := state_variant as Dictionary
	if str(save_state.get("state_fingerprint", "")) != _fingerprint(candidate):
		return "save_state_fingerprint_invalid"
	if str(save_state.get("core_fingerprint", "")) != _core_fingerprint(candidate):
		return "save_state_core_fingerprint_invalid"
	var normalized_candidate: Variant = _normalize_json_numbers(candidate)
	if not (normalized_candidate is Dictionary) \
			or not _state_valid(normalized_candidate as Dictionary):
		return "save_state_invariant_invalid"
	var normalized_document: Variant = _normalize_json_numbers(
		save_state.get("document_section")
	)
	if not (normalized_document is Dictionary) \
			or normalized_document \
			!= _document_save_section(normalized_candidate as Dictionary):
		return "save_state_document_section_invalid"
	return ""


static func is_pure_data(value: Variant) -> bool:
	return _pure_data(value)


static func validate_typed_state_contracts(value: Variant) -> String:
	if not (value is Dictionary) or not _pure_data(value) \
			or not _exact_fields(value as Dictionary, TYPED_STATE_CONTRACT_FIELDS):
		return "typed_state_contract_fields_invalid"
	var contracts := value as Dictionary
	if contracts.get("normal_deck_state") != NORMAL_DECK_STATE_CONTRACT_ID \
			or contracts.get("normal_hand_state") != NORMAL_HAND_STATE_CONTRACT_ID \
			or contracts.get("normal_discard_state") \
			!= NORMAL_DISCARD_STATE_CONTRACT_ID \
			or contracts.get("normal_merge_state") != NORMAL_MERGE_STATE_CONTRACT_ID \
			or contracts.get("commodity_inventory_state") \
			!= COMMODITY_INVENTORY_STATE_CONTRACT_ID \
			or contracts.get("bound_source_state") != BOUND_SOURCE_STATE_CONTRACT_ID \
			or contracts.get("local_queue_state") != LOCAL_QUEUE_STATE_CONTRACT_ID:
		return "typed_state_contract_identity_invalid"
	return ""


static func validate_three_wing_contract(value: Dictionary) -> String:
	if not _pure_data(value) or not _exact_fields(value, THREE_WING_CONTRACT_FIELDS):
		return "three_wing_contract_fields_invalid"
	if value.get("schema_version") != SCHEMA_VERSION \
			or value.get("state_version") != STATE_VERSION \
			or value.get("ruleset_id") != RULESET_ID \
			or value.get("balance_profile_id") != BALANCE_PROFILE_ID \
			or value.get("balance_profile_fingerprint") \
			!= BALANCE_PROFILE_FINGERPRINT \
			or value.get("domain_id") != DOMAIN_ID \
			or value.get("core_authority_schema_id") != CORE_AUTHORITY_SCHEMA_ID \
			or value.get("ai_observation_schema_id") != AI_OBSERVATION_SCHEMA_ID \
			or value.get("player_projection_schema_id") != PLAYER_PROJECTION_SCHEMA_ID \
			or value.get("intent_schema_id") != INTENT_SCHEMA_ID \
			or value.get("authoritative_receipt_schema_id") != RECEIPT_SCHEMA_ID \
			or value.get("save_state_schema_id") != SAVE_SCHEMA_ID \
			or value.get("shared_fact_binding_field") != "core_fingerprint":
		return "three_wing_contract_identity_invalid"
	var typed_reason := validate_typed_state_contracts(
		value.get("typed_state_contracts")
	)
	if not typed_reason.is_empty():
		return "three_wing_contract_%s" % typed_reason
	if value.get("rng_stream_ids") != [
			"starter_deck_shuffle", "normal_deck_reshuffle_by_player",
		] \
			or value.get("player_merge_choice_required") != true \
			or value.get("automatic_merge_allowed") != false \
			or value.get("mid_batch_refill_allowed") != false \
			or value.get("save_is_second_authority") != false \
			or value.get("commodity_inventory_limit") != COMMODITY_INVENTORY_LIMIT \
			or value.get("commodity_merge_edges") != ["L1+L1=L2", "L2+L1=L3"] \
			or value.get("bound_source_runtime_binding_supported") != true \
			or value.get("normal_deck_minimum_total_card_count") \
			!= NORMAL_DECK_MINIMUM_TOTAL_CARD_COUNT \
			or value.get("normal_deck_minimum_count_rule_version") \
			!= NORMAL_DECK_MINIMUM_COUNT_RULE_VERSION \
			or value.get("commodity_available_from_batch_field") \
			!= "available_from_batch_id" \
			or value.get("local_queue_state_contract_id") \
			!= LOCAL_QUEUE_STATE_CONTRACT_ID:
		return "three_wing_contract_rule_flags_invalid"
	return ""


static func projection_is_private_safe(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var projection := value as Dictionary
	match str(projection.get("schema_id", "")):
		AI_OBSERVATION_SCHEMA_ID:
			return _projection_reason(
				projection, AI_OBSERVATION_SCHEMA_ID, "actor_private"
			).is_empty()
		PLAYER_PROJECTION_SCHEMA_ID:
			return _projection_reason(
				projection, PLAYER_PROJECTION_SCHEMA_ID, "viewer_private"
			).is_empty()
	return false


static func receipt_is_private_safe(value: Variant) -> bool:
	return value is Dictionary and _receipt_valid(value as Dictionary) \
		and not _contains_key_recursive(value, PRIVATE_PROJECTION_KEYS)


static func validate_core_authority_snapshot(value: Dictionary) -> String:
	if not _pure_data(value) or not _exact_fields(value, CORE_AUTHORITY_FIELDS):
		return "core_authority_fields_invalid"
	if value.get("schema_id") != CORE_AUTHORITY_SCHEMA_ID \
			or value.get("schema_version") != SCHEMA_VERSION \
			or value.get("state_version") != STATE_VERSION \
			or value.get("ruleset_id") != RULESET_ID \
			or value.get("balance_profile_id") != BALANCE_PROFILE_ID \
			or value.get("balance_profile_fingerprint") \
			!= BALANCE_PROFILE_FINGERPRINT \
			or value.get("domain_id") != DOMAIN_ID \
			or value.get("privacy_scope") != "authority_secret":
		return "core_authority_schema_invalid"
	if not validate_typed_state_contracts(
		value.get("typed_state_contracts")
	).is_empty():
		return "core_authority_typed_state_contracts_invalid"
	var state_variant: Variant = value.get("state")
	if not (state_variant is Dictionary) or not _state_valid(state_variant as Dictionary):
		return "core_authority_state_invalid"
	var state := state_variant as Dictionary
	if str(value.get("state_fingerprint", "")) != _fingerprint(state):
		return "core_authority_state_fingerprint_invalid"
	if str(value.get("core_fingerprint", "")) != _core_fingerprint(state):
		return "core_authority_fact_fingerprint_invalid"
	if not (value.get("document_section") is Dictionary) \
			or value.get("document_section") != _document_save_section(state):
		return "core_authority_document_section_invalid"
	return ""


static func validate_intent(intent: Dictionary) -> String:
	return _intent_shape_reason(intent)


static func validate_track_claim_receipt(
	receipt: Dictionary,
	track_intent: Dictionary = {},
	track_ai_observation: Dictionary = {}
) -> String:
	var observation_reason := _track_ai_observation_reason(track_ai_observation)
	if not observation_reason.is_empty():
		return observation_reason
	var intent_reason := _track_claim_intent_reason(track_intent)
	if not intent_reason.is_empty():
		return intent_reason
	var receipt_reason := _track_claim_receipt_reason(receipt)
	if not receipt_reason.is_empty():
		return receipt_reason
	var actor_id := str(track_intent.get("actor_id", ""))
	if track_ai_observation.get("viewer_actor_id") != actor_id:
		return "track_claim_actor_binding_invalid"
	if track_intent.get("source_revision") \
			!= track_ai_observation.get("source_revision") \
			or track_intent.get("source_core_fingerprint") \
			!= track_ai_observation.get("source_core_fingerprint"):
		return "track_claim_revision_binding_invalid"
	if receipt.get("request_id") != track_intent.get("request_id") \
			or receipt.get("intent_id") != track_intent.get("intent_id") \
			or receipt.get("intent_fingerprint") \
			!= track_intent.get("intent_fingerprint"):
		return "track_claim_intent_binding_invalid"
	if receipt.get("source_revision") != track_intent.get("source_revision") \
			or int(receipt.get("result_revision", 0)) \
			!= int(track_intent.get("source_revision", 0)) + 1:
		return "track_claim_revision_binding_invalid"
	var source_identity := track_intent.get("source_identity", {}) as Dictionary
	var authorization := (
		track_intent.get("viewer_segment_authorization", {}) as Dictionary
	)
	if source_identity.get("segment_owner_id") != actor_id \
			or authorization.get("authorized_actor_id") != actor_id \
			or authorization.get("authorized_segment_owner_id") != actor_id:
		return "track_claim_actor_binding_invalid"
	if authorization.get("authorized_source_identity_id") \
			!= source_identity.get("source_identity_id") \
			or authorization.get("authorized_source_instance_id") \
			!= source_identity.get("source_instance_id") \
			or authorization.get("source_track_revision") \
			!= source_identity.get("source_track_revision"):
		return "track_claim_capability_binding_invalid"
	if authorization.get("inventory_authority_id") != RNG_AUTHORITY_OWNER_ID \
			or authorization.get("cash_authority_id") != "authority.none":
		return "track_claim_capability_binding_invalid"
	var projected_item := _track_visible_item_for_source(
		track_ai_observation,
		str(source_identity.get("source_instance_id", ""))
	)
	if projected_item.is_empty() \
			or projected_item.get("card_definition_id") \
			!= source_identity.get("source_definition_id") \
			or projected_item.get("card_kind") != source_identity.get("source_kind") \
			or projected_item.get("track_revision") \
			!= source_identity.get("source_track_revision"):
		return "track_claim_source_binding_invalid"
	var public_facts := receipt.get("public_facts", {}) as Dictionary
	if int(public_facts.get("track_revision", 0)) \
			!= int(source_identity.get("source_track_revision", 0)) + 1:
		return "track_claim_revision_binding_invalid"
	return ""


func _track_authority_contract_reason(authority: RefCounted) -> String:
	if authority == null:
		return "track_receipt_authority_missing"
	var authority_script: Script = authority.get_script() as Script
	if authority_script == null or authority_script != TrackCore:
		return "track_receipt_authority_script_invalid"
	for method_name in TRACK_AUTHORITY_METHODS:
		if not authority.has_method(method_name):
			return "track_receipt_authority_contract_invalid"
	return ""


func _track_authority_descriptor(authority: RefCounted) -> Dictionary:
	if not _track_authority_contract_reason(authority).is_empty():
		return {}
	var snapshot_variant: Variant = authority.call("core_authority_v1")
	if not (snapshot_variant is Dictionary) \
			or not TrackCore.is_pure_data(snapshot_variant):
		return {}
	var snapshot := snapshot_variant as Dictionary
	if not _exact_fields(snapshot, [
		"schema_version", "interface_id", "ruleset_id", "state_version",
		"balance_profile_id", "balance_profile_fingerprint", "domain_id",
		"authority_scope", "source_revision", "authority_state",
		"core_fingerprint",
	]) \
			or snapshot.get("schema_version") != TrackCore.SCHEMA_VERSION \
			or snapshot.get("interface_id") != TrackCore.CORE_INTERFACE_ID \
			or snapshot.get("ruleset_id") != TrackCore.RULESET_ID \
			or snapshot.get("state_version") != TrackCore.STATE_VERSION \
			or snapshot.get("balance_profile_id") != TrackCore.BALANCE_PROFILE_ID \
			or snapshot.get("balance_profile_fingerprint") \
			!= TrackCore.BALANCE_PROFILE_FINGERPRINT \
			or snapshot.get("domain_id") != TrackCore.DOMAIN_ID \
			or snapshot.get("authority_scope") != "authority_secret" \
			or not _positive_int(snapshot.get("source_revision")) \
			or not (snapshot.get("authority_state") is Dictionary):
		return {}
	var authority_state := snapshot.get("authority_state", {}) as Dictionary
	if str(snapshot.get("core_fingerprint", "")) \
			!= TrackCore.fingerprint(authority_state) \
			or authority_state.get("schema_version") != TrackCore.SCHEMA_VERSION \
			or authority_state.get("state_version") != TrackCore.STATE_VERSION \
			or authority_state.get("ruleset_id") != TrackCore.RULESET_ID \
			or authority_state.get("domain_id") != TrackCore.DOMAIN_ID \
			or authority_state.get("match_instance_id_explicit") != true \
			or not _stable_id(authority_state.get("match_instance_id")) \
			or authority_state.get("match_instance_id") == "match.unspecified" \
			or not _positive_int(authority_state.get("match_seed")) \
			or not (authority_state.get("roster_ids") is Array):
		return {}
	var roster := authority_state.get("roster_ids", []) as Array
	if roster.is_empty():
		return {}
	for actor_variant in roster:
		if not _stable_id(actor_variant):
			return {}
	var lineage_basis := {
		"schema_version": TrackCore.SCHEMA_VERSION,
		"state_version": TrackCore.STATE_VERSION,
		"ruleset_id": TrackCore.RULESET_ID,
		"domain_id": TrackCore.DOMAIN_ID,
		"match_instance_id": str(authority_state.get("match_instance_id", "")),
		"match_seed": int(authority_state.get("match_seed", 0)),
		"roster_ids": roster.duplicate(true),
	}
	return {
		"match_instance_id": str(authority_state.get("match_instance_id", "")),
		"lineage_fingerprint": TrackCore.fingerprint(lineage_basis),
	}


func _descriptor_matches_bound_source(descriptor: Dictionary) -> bool:
	return _descriptor_matches_bound_source_value(
		descriptor,
		_state.get("bound_source_state")
	)


static func _descriptor_matches_bound_source_value(
	descriptor: Dictionary,
	bound_source_value: Variant
) -> bool:
	var entry := _bound_source_entry(bound_source_value)
	return not entry.is_empty() \
		and entry.get("match_instance_id") == descriptor.get("match_instance_id") \
		and entry.get("lineage_fingerprint") \
		== descriptor.get("lineage_fingerprint")


static func _bound_source_entry(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var entries_variant: Variant = (value as Dictionary).get("entries")
	if not (entries_variant is Array) or (entries_variant as Array).size() != 1:
		return {}
	var entry_variant: Variant = (entries_variant as Array)[0]
	if not (entry_variant is Dictionary):
		return {}
	return (entry_variant as Dictionary).duplicate(true)


static func _bound_source_state_for_descriptor(descriptor: Dictionary) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"contract_id": BOUND_SOURCE_STATE_CONTRACT_ID,
		"runtime_binding_supported": true,
		"entries": [{
			"match_instance_id": str(descriptor.get("match_instance_id", "")),
			"lineage_fingerprint": str(descriptor.get("lineage_fingerprint", "")),
		}],
	}


func _acquisition_participant_request_reason(request: Dictionary) -> String:
	if not _pure_data(request) \
			or not _exact_fields(request, ACQUISITION_PARTICIPANT_REQUEST_FIELDS):
		return "acquisition_participant_request_fields_invalid"
	if request.get("schema_version") != SCHEMA_VERSION \
			or request.get("interface_id") \
			!= ACQUISITION_PARTICIPANT_REQUEST_INTERFACE_ID \
			or request.get("ruleset_id") != RULESET_ID \
			or request.get("domain_id") != TRACK_DOMAIN_ID \
			or request.get("participant_role") != "commodity_slot" \
			or request.get("authority_id") != RNG_AUTHORITY_OWNER_ID \
			or request.get("reservation_kind") != "destination_capacity" \
			or request.get("action_id") != TRACK_CLAIM_ACTION_ID \
			or request.get("destination_zone") != "commodity_inventory":
		return "acquisition_participant_request_schema_invalid"
	for field_name in ["transaction_id", "request_id", "actor_id"]:
		if not _stable_id(request.get(field_name)):
			return "acquisition_participant_request_identity_invalid"
	if request.get("actor_id") != _state.get("owner_player_id") \
			or not _fingerprint_string(request.get("proposal_fingerprint")) \
			or not _fingerprint_string(request.get("request_fingerprint")) \
			or request.get("request_fingerprint") \
			!= TrackCore.fingerprint(request, "request_fingerprint") \
			or not (request.get("source_identity") is Dictionary):
		return "acquisition_participant_request_binding_invalid"
	var source_identity := request.get("source_identity", {}) as Dictionary
	var source_reason := _track_source_identity_reason(source_identity)
	if not source_reason.is_empty():
		return source_reason
	if source_identity.get("source_kind") != "commodity_card" \
			or source_identity.get("segment_owner_id") != request.get("actor_id"):
		return "track_claim_source_binding_invalid"
	return ""


func _reserved_or_consumed_source_reason(
	track_request_id: String,
	track_instance_id: String
) -> String:
	for reservation_variant in _commodity_slot_reservations.values():
		var reservation := reservation_variant as Dictionary
		var request := reservation.get("request", {}) as Dictionary
		var source := reservation.get("source_identity", {}) as Dictionary
		if str(request.get("request_id", "")) == track_request_id:
			return "track_claim_intent_already_reserved"
		if str(source.get("source_instance_id", "")) == track_instance_id:
			return "track_instance_already_reserved"
	for row_variant in _state.get("commodity_claim_history", []) as Array:
		var row := row_variant as Dictionary
		if str(row.get("track_intent_id", "")) == track_request_id:
			return "track_claim_intent_already_consumed"
		if str(row.get("track_instance_id", "")) == track_instance_id:
			return "track_instance_already_claimed"
	return ""


func _acquisition_reservation_valid(reservation: Dictionary) -> bool:
	if not _pure_data(reservation) \
			or not _exact_fields(reservation, ACQUISITION_RESERVATION_FIELDS) \
			or not _stable_id(reservation.get("reservation_id")) \
			or not _nonnegative_int(reservation.get("dbg_revision")) \
			or not _fingerprint_string(reservation.get("dbg_state_fingerprint")) \
			or not _stable_id(reservation.get("track_match_instance_id")) \
			or not _fingerprint_string(reservation.get("track_lineage_fingerprint")) \
			or not (reservation.get("request") is Dictionary) \
			or not (reservation.get("source_identity") is Dictionary) \
			or not (reservation.get("source_item") is Dictionary):
		return false
	var request := reservation.get("request", {}) as Dictionary
	var source_identity := reservation.get("source_identity", {}) as Dictionary
	var source_item := reservation.get("source_item", {}) as Dictionary
	return _acquisition_participant_request_reason(request).is_empty() \
		and request.get("source_identity", {}) == source_identity \
		and _track_source_identity_reason(source_identity).is_empty() \
		and _track_visible_item_reason(
			source_item,
			int(source_identity.get("source_track_revision", 0))
		).is_empty() \
		and source_item.get("instance_id") \
		== source_identity.get("source_instance_id") \
		and source_item.get("card_definition_id") \
		== source_identity.get("source_definition_id") \
		and source_item.get("card_kind") == source_identity.get("source_kind")


func _track_receipt_for_reservation_reason(
	receipt: Dictionary,
	reservation: Dictionary
) -> String:
	var receipt_reason := _track_claim_receipt_reason(receipt)
	if not receipt_reason.is_empty():
		return receipt_reason
	var authority_reason := _track_claim_authority_reason(receipt)
	if not authority_reason.is_empty():
		return authority_reason
	var request := reservation.get("request", {}) as Dictionary
	var source_identity := reservation.get("source_identity", {}) as Dictionary
	var source_item := reservation.get("source_item", {}) as Dictionary
	if receipt.get("request_id") != request.get("request_id") \
			or receipt.get("intent_id") != request.get("request_id"):
		return "track_claim_intent_binding_invalid"
	if (receipt.get("inventory_commit", {}) as Dictionary).get(
		"external_authority_id"
	) != RNG_AUTHORITY_OWNER_ID:
		return "track_claim_capability_binding_invalid"
	if int((receipt.get("public_facts", {}) as Dictionary).get(
		"track_revision", 0
	)) != int(source_identity.get("source_track_revision", 0)) + 1:
		return "track_claim_revision_binding_invalid"
	if source_item.get("instance_id") != source_identity.get("source_instance_id") \
			or source_item.get("card_definition_id") \
			!= source_identity.get("source_definition_id") \
			or source_item.get("card_kind") != "commodity_card":
		return "track_claim_source_binding_invalid"
	var descriptor := _track_authority_descriptor(_track_receipt_authority)
	if descriptor.is_empty() \
			or descriptor.get("match_instance_id") \
			!= reservation.get("track_match_instance_id") \
			or descriptor.get("lineage_fingerprint") \
			!= reservation.get("track_lineage_fingerprint") \
			or not _descriptor_matches_bound_source(descriptor):
		return "track_receipt_authority_lineage_mismatch"
	return ""


static func _participant_operation(
	accepted: bool,
	reason_code: String,
	reservation_id: String,
	transaction_id: String
) -> Dictionary:
	var effective_transaction_id := transaction_id
	if not _stable_id(effective_transaction_id):
		effective_transaction_id = "transaction.unknown"
	var effective_reservation_id := reservation_id
	if not _stable_id(effective_reservation_id):
		effective_reservation_id = (
			"reservation.personal_dbg.rejected.%s" % effective_transaction_id
		)
	return TrackCore.sealed_copy({
		"accepted": accepted,
		"reason_code": reason_code,
		"transaction_id": effective_transaction_id,
		"reservation_id": effective_reservation_id,
		"authority_id": RNG_AUTHORITY_OWNER_ID,
		"participant_role": "commodity_slot",
	}, "receipt_fingerprint")


func _transaction_id_for_reservation(reservation_id: String) -> String:
	if _commodity_slot_reservations.has(reservation_id):
		var reservation := _commodity_slot_reservations.get(
			reservation_id, {}
		) as Dictionary
		return str((reservation.get("request", {}) as Dictionary).get(
			"transaction_id", ""
		))
	if _commodity_slot_commit_receipts.has(reservation_id):
		return str((_commodity_slot_commit_receipts.get(
			reservation_id, {}
		) as Dictionary).get("transaction_id", ""))
	var rejected_prefix := "reservation.personal_dbg.rejected."
	if reservation_id.begins_with(rejected_prefix):
		return reservation_id.trim_prefix(rejected_prefix)
	return ""


func _track_claim_authority_reason(receipt: Dictionary) -> String:
	if _track_receipt_authority == null:
		return "track_receipt_authority_unbound"
	if not _track_receipt_authority.has_method(TRACK_RECEIPT_AUTHORITY_METHOD):
		return "track_receipt_authority_port_invalid"
	var issued_variant: Variant = _track_receipt_authority.call(
		TRACK_RECEIPT_AUTHORITY_METHOD,
		str(receipt.get("request_id", ""))
	)
	if not (issued_variant is Dictionary) or (issued_variant as Dictionary).is_empty():
		return "track_claim_authoritative_receipt_missing"
	if (issued_variant as Dictionary) != receipt:
		return "track_claim_authoritative_receipt_mismatch"
	return ""


static func _track_ai_observation_reason(observation: Dictionary) -> String:
	if not _pure_data(observation) \
			or not _exact_fields(observation, TRACK_PROJECTION_FIELDS):
		return "track_claim_observation_fields_invalid"
	if observation.get("schema_version") != SCHEMA_VERSION \
			or observation.get("interface_id") != TRACK_AI_OBSERVATION_SCHEMA_ID \
			or observation.get("ruleset_id") != TrackCore.RULESET_ID \
			or observation.get("state_version") != TrackCore.STATE_VERSION \
			or observation.get("balance_profile_id") \
			!= TrackCore.BALANCE_PROFILE_ID \
			or observation.get("balance_profile_fingerprint") \
			!= TrackCore.BALANCE_PROFILE_FINGERPRINT \
			or observation.get("domain_id") != TRACK_DOMAIN_ID \
			or not _positive_int(observation.get("source_revision")) \
			or not _stable_id(observation.get("viewer_actor_id")):
		return "track_claim_observation_schema_invalid"
	if not (observation.get("public_facts") is Dictionary) \
			or not (observation.get("viewer_private_facts") is Dictionary):
		return "track_claim_observation_payload_invalid"
	var public_facts := observation.get("public_facts", {}) as Dictionary
	var private_facts := observation.get("viewer_private_facts", {}) as Dictionary
	if not _exact_fields(public_facts, TRACK_PUBLIC_FACT_FIELDS) \
			or not _exact_fields(private_facts, TRACK_AI_PRIVATE_FACT_FIELDS):
		return "track_claim_observation_fact_fields_invalid"
	if public_facts.get("single_unified_track") != true \
			or public_facts.get("allowed_card_kinds") \
			!= ["normal_card", "commodity_card"] \
			or not _positive_int(public_facts.get("track_revision")) \
			or not _nonnegative_int(public_facts.get("scroll_sequence")) \
			or not _positive_int(public_facts.get("unified_track_item_count")) \
			or public_facts.get("balance_profile_id") \
			!= TrackCore.BALANCE_PROFILE_ID \
			or public_facts.get("balance_profile_fingerprint") \
			!= TrackCore.BALANCE_PROFILE_FINGERPRINT \
			or not _positive_int(public_facts.get("color_cycle_number")) \
			or not _nonnegative_int(public_facts.get("completed_batch_count")) \
			or not _nonnegative_int(public_facts.get("lead_batch_cursor")) \
			or not _positive_int(public_facts.get("lead_tenure_batches")) \
			or not _nonnegative_int(public_facts.get("color_cycle_batch_cursor")) \
			or not _positive_int(public_facts.get("color_cycle_batches")) \
			or public_facts.get("lead_identity_not_directly_published") != true \
			or public_facts.get(
				"lead_identity_may_be_inferred_from_public_information"
			) != true \
			or not (public_facts.get("card_kind_ratio_basis_points") is Dictionary) \
			or not (public_facts.get("color_distribution_basis_points") is Dictionary) \
			or not (public_facts.get("revealed_stances") is Array) \
			or not (private_facts.get("own_segment_items") is Array) \
			or not (private_facts.get("own_pending_stance") is Dictionary) \
			or not (private_facts.get("self_is_current_lead") is bool) \
			or str(private_facts.get("self_influence_class", "")) \
			not in ["normal", "double"]:
		return "track_claim_observation_fact_invalid"
	var ratio := public_facts.get("card_kind_ratio_basis_points", {}) as Dictionary
	if not _exact_fields(ratio, ["normal_card", "commodity_card"]) \
			or not _nonnegative_int(ratio.get("normal_card")) \
			or not _nonnegative_int(ratio.get("commodity_card")) \
			or int(ratio.get("normal_card", 0)) \
			+ int(ratio.get("commodity_card", 0)) != 10000:
		return "track_claim_observation_ratio_invalid"
	var distribution := (
		public_facts.get("color_distribution_basis_points", {}) as Dictionary
	)
	if not _exact_fields(distribution, COLORS):
		return "track_claim_observation_color_distribution_invalid"
	var distribution_total := 0
	for color_variant in COLORS:
		if not _nonnegative_int(distribution.get(str(color_variant))):
			return "track_claim_observation_color_distribution_invalid"
		distribution_total += int(distribution.get(str(color_variant), 0))
	if distribution_total != 10000:
		return "track_claim_observation_color_distribution_invalid"
	var seen_items: Array[String] = []
	for item_variant in private_facts.get("own_segment_items", []) as Array:
		if not (item_variant is Dictionary) \
				or not _track_visible_item_reason(
					item_variant as Dictionary,
					int(public_facts.get("track_revision", 0))
				).is_empty():
			return "track_claim_observation_item_invalid"
		var item_id := str((item_variant as Dictionary).get("instance_id", ""))
		if seen_items.has(item_id):
			return "track_claim_observation_item_duplicate"
		seen_items.append(item_id)
	var source_facts := {
		"schema_version": SCHEMA_VERSION,
		"domain_id": TRACK_DOMAIN_ID,
		"source_revision": int(observation.get("source_revision", 0)),
		"viewer_actor_id": str(observation.get("viewer_actor_id", "")),
		"public_facts": public_facts,
		"viewer_private_facts": private_facts,
	}
	if not _fingerprint_string(observation.get("source_core_fingerprint")) \
			or observation.get("source_core_fingerprint") != _fingerprint(source_facts):
		return "track_claim_observation_source_fingerprint_invalid"
	if not _fingerprint_string(observation.get("projection_fingerprint")) \
			or observation.get("projection_fingerprint") \
			!= _fingerprint_without(observation, "projection_fingerprint"):
		return "track_claim_observation_fingerprint_invalid"
	return ""


static func _track_visible_item_reason(item: Dictionary, track_revision: int) -> String:
	if not _exact_fields(item, TRACK_VISIBLE_ITEM_FIELDS) \
			or not _stable_id(item.get("instance_id")) \
			or not _stable_id(item.get("card_definition_id")) \
			or str(item.get("card_kind", "")) not in ["normal_card", "commodity_card"] \
			or item.get("level") != 1 \
			or str(item.get("primary_color", "")) not in COLORS \
			or not _nonnegative_int(item.get("local_slot_index")) \
			or item.get("track_revision") != track_revision \
			or not _nonnegative_int(item.get("claimable_from_scroll_sequence")) \
			or not (item.get("claimable") is bool) \
			or str(item.get("claimability_state", "")) \
			not in ["claimable", "incoming_locked"]:
		return "track_visible_item_invalid"
	if bool(item.get("claimable", false)) \
			!= (str(item.get("claimability_state", "")) == "claimable"):
		return "track_visible_item_claimability_invalid"
	return ""


static func _track_claim_intent_reason(intent: Dictionary) -> String:
	if not _pure_data(intent) \
			or not _exact_fields(intent, TRACK_CLAIM_INTENT_FIELDS):
		return "track_claim_intent_fields_invalid"
	if intent.get("schema_version") != SCHEMA_VERSION \
			or intent.get("interface_id") != TRACK_CLAIM_INTENT_SCHEMA_ID \
			or intent.get("domain_id") != TRACK_DOMAIN_ID \
			or intent.get("action_id") != TRACK_CLAIM_ACTION_ID:
		return "track_claim_intent_schema_invalid"
	for field in ["request_id", "intent_id", "actor_id"]:
		if not _stable_id(intent.get(field)):
			return "track_claim_intent_identity_invalid"
	if intent.get("intent_id") != intent.get("request_id") \
			or not _positive_int(intent.get("source_revision")) \
			or intent.get("expected_core_revision") != intent.get("source_revision") \
			or not _fingerprint_string(intent.get("source_core_fingerprint")) \
			or not (intent.get("source_identity") is Dictionary) \
			or not (intent.get("viewer_segment_authorization") is Dictionary) \
			or not (intent.get("parameters") is Dictionary) \
			or not (intent.get("parameters", {}) as Dictionary).is_empty():
		return "track_claim_intent_identity_invalid"
	var source_reason := _track_source_identity_reason(
		intent.get("source_identity", {}) as Dictionary
	)
	if not source_reason.is_empty():
		return source_reason
	var authorization_reason := _track_authorization_reason(
		intent.get("viewer_segment_authorization", {}) as Dictionary
	)
	if not authorization_reason.is_empty():
		return authorization_reason
	if not _fingerprint_string(intent.get("intent_fingerprint")) \
			or intent.get("intent_fingerprint") \
			!= _fingerprint_without(intent, "intent_fingerprint"):
		return "track_claim_intent_fingerprint_invalid"
	return ""


static func _track_source_identity_reason(source: Dictionary) -> String:
	if not _exact_fields(source, TRACK_SOURCE_IDENTITY_FIELDS) \
			or source.get("schema_version") != SCHEMA_VERSION:
		return "track_claim_source_fields_invalid"
	for field in [
		"source_identity_id", "source_instance_id", "source_definition_id",
		"segment_owner_id",
	]:
		if not _stable_id(source.get(field)):
			return "track_claim_source_identity_invalid"
	if source.get("source_kind") != "commodity_card" \
			or not _positive_int(source.get("source_track_revision")):
		return "track_claim_source_kind_invalid"
	if not _fingerprint_string(source.get("identity_fingerprint")) \
			or source.get("identity_fingerprint") \
			!= _fingerprint_without(source, "identity_fingerprint"):
		return "track_claim_source_fingerprint_invalid"
	return ""


static func _track_authorization_reason(authorization: Dictionary) -> String:
	if not _exact_fields(authorization, TRACK_VIEWER_AUTHORIZATION_FIELDS) \
			or authorization.get("schema_version") != SCHEMA_VERSION:
		return "track_claim_capability_fields_invalid"
	for field in [
		"capability_id", "authorization_id", "authorization_authority_id",
		"authorized_actor_id", "authorized_source_identity_id",
		"authorized_source_instance_id", "authorized_segment_owner_id",
		"inventory_authority_id", "cash_authority_id",
	]:
		if not _stable_id(authorization.get(field)):
			return "track_claim_capability_identity_invalid"
	if not _positive_int(authorization.get("source_track_revision")):
		return "track_claim_capability_revision_invalid"
	if not _fingerprint_string(authorization.get("authorization_fingerprint")) \
			or authorization.get("authorization_fingerprint") \
			!= _fingerprint_without(authorization, "authorization_fingerprint"):
		return "track_claim_capability_fingerprint_invalid"
	return ""


static func _track_claim_receipt_reason(receipt: Dictionary) -> String:
	if not _pure_data(receipt) \
			or not _exact_fields(receipt, TRACK_CLAIM_RECEIPT_FIELDS):
		return "track_claim_receipt_fields_invalid"
	if receipt.get("schema_version") != SCHEMA_VERSION \
			or receipt.get("interface_id") != TRACK_CLAIM_RECEIPT_SCHEMA_ID \
			or receipt.get("domain_id") != TRACK_DOMAIN_ID:
		return "track_claim_receipt_schema_invalid"
	for field in ["request_id", "receipt_id", "intent_id"]:
		if not _stable_id(receipt.get(field)):
			return "track_claim_receipt_identity_invalid"
	if receipt.get("action_id") != TRACK_CLAIM_ACTION_ID:
		return "track_claim_kind_invalid"
	if not _fingerprint_string(receipt.get("intent_fingerprint")) \
			or receipt.get("accepted") != true \
			or receipt.get("reason_code") != "accepted":
		return "track_claim_receipt_transition_invalid"
	if not _positive_int(receipt.get("source_revision")) \
			or not _positive_int(receipt.get("result_revision")) \
			or int(receipt.get("result_revision", 0)) \
			!= int(receipt.get("source_revision", 0)) + 1 \
			or not _positive_int(receipt.get("committed_core_revision")):
		return "track_claim_receipt_revision_invalid"
	if receipt.get("destination_zone") != "commodity_inventory":
		return "track_claim_destination_invalid"
	if receipt.get("external_authority_commit_required") != true \
			or not (receipt.get("cash_delta") is Dictionary) \
			or not (receipt.get("inventory_commit") is Dictionary) \
			or not (receipt.get("public_facts") is Dictionary):
		return "track_claim_receipt_commit_invalid"
	var cash := receipt.get("cash_delta", {}) as Dictionary
	if not _exact_fields(cash, TRACK_CASH_DELTA_FIELDS) \
			or cash.get("mode") != "none" \
			or cash.get("track_core_committed") != false \
			or cash.get("amount_known") != true \
			or cash.get("amount_decimal") != "0" \
			or cash.get("external_authority_id") != "authority.none":
		return "track_claim_cash_delta_invalid"
	var inventory_commit := receipt.get("inventory_commit", {}) as Dictionary
	if not _exact_fields(inventory_commit, TRACK_INVENTORY_COMMIT_FIELDS) \
			or inventory_commit.get("track_core_committed") != false \
			or inventory_commit.get("external_authority_id") \
			!= RNG_AUTHORITY_OWNER_ID \
			or inventory_commit.get("destination_zone") != "commodity_inventory":
		return "track_claim_capability_binding_invalid"
	var public_facts := receipt.get("public_facts", {}) as Dictionary
	if not _exact_fields(public_facts, TRACK_ACQUISITION_PUBLIC_FACT_FIELDS) \
			or public_facts.get("track_item_removed") != true \
			or public_facts.get("replacement_count") != 1 \
			or not _positive_int(public_facts.get("track_revision")):
		return "track_claim_receipt_public_facts_invalid"
	if not _fingerprint_string(receipt.get("receipt_fingerprint")) \
			or receipt.get("receipt_fingerprint") \
			!= _fingerprint_without(receipt, "receipt_fingerprint"):
		return "track_claim_receipt_fingerprint_invalid"
	return ""


static func _track_visible_item_for_source(
	observation: Dictionary,
	source_instance_id: String
) -> Dictionary:
	var private_facts := observation.get("viewer_private_facts", {}) as Dictionary
	for item_variant in private_facts.get("own_segment_items", []) as Array:
		if item_variant is Dictionary \
				and str((item_variant as Dictionary).get("instance_id", "")) \
				== source_instance_id:
			return (item_variant as Dictionary).duplicate(true)
	return {}


static func validate_receipt(receipt: Dictionary) -> String:
	return "" if _receipt_valid(receipt) else "receipt_contract_invalid"


static func _projection_reason(
	projection: Dictionary,
	expected_schema_id: String,
	expected_visibility_scope: String
) -> String:
	if not _pure_data(projection) or not _exact_fields(projection, PROJECTION_FIELDS):
		return "projection_fields_invalid"
	if projection.get("schema_id") != expected_schema_id \
			or projection.get("schema_version") != SCHEMA_VERSION \
			or projection.get("state_version") != STATE_VERSION \
			or projection.get("ruleset_id") != RULESET_ID \
			or projection.get("balance_profile_id") != BALANCE_PROFILE_ID \
			or projection.get("balance_profile_fingerprint") \
			!= BALANCE_PROFILE_FINGERPRINT \
			or projection.get("domain_id") != DOMAIN_ID \
			or projection.get("visibility_scope") != expected_visibility_scope:
		return "projection_schema_invalid"
	if not _nonnegative_int(projection.get("revision")) \
			or not _fingerprint_string(projection.get("core_fingerprint")):
		return "projection_source_binding_invalid"
	var facts_variant: Variant = projection.get("facts")
	if not (facts_variant is Dictionary):
		return "projection_facts_invalid"
	var facts := facts_variant as Dictionary
	var facts_reason := _viewer_facts_reason(facts)
	if not facts_reason.is_empty():
		return facts_reason
	if str(projection.get("facts_fingerprint", "")) != _fingerprint(facts):
		return "projection_facts_fingerprint_invalid"
	var allowed_variant: Variant = projection.get("allowed_intent_kinds")
	if not (allowed_variant is Array) \
			or allowed_variant != _intent_kinds_for_phase(str(facts.get("phase", ""))):
		return "projection_allowed_intents_invalid"
	if _contains_key_recursive(projection, PRIVATE_PROJECTION_KEYS):
		return "projection_private_field_forbidden"
	return ""


static func _viewer_facts_reason(facts: Dictionary) -> String:
	if not _pure_data(facts) or not _exact_fields(facts, VIEWER_FACT_FIELDS):
		return "projection_fact_fields_invalid"
	var phase := str(facts.get("phase", ""))
	if phase not in [PHASE_BATCH, PHASE_MAINTENANCE] \
			or not _positive_int(facts.get("batch_index")) \
			or facts.get("balance_profile_id") != BALANCE_PROFILE_ID \
			or facts.get("balance_profile_fingerprint") \
			!= BALANCE_PROFILE_FINGERPRINT \
			or not _positive_int(facts.get("normal_deck_total_card_count")) \
			or int(facts.get("normal_deck_total_card_count", 0)) \
			< NORMAL_DECK_MINIMUM_TOTAL_CARD_COUNT \
			or facts.get("normal_deck_minimum_total_card_count") \
			!= NORMAL_DECK_MINIMUM_TOTAL_CARD_COUNT \
			or facts.get("normal_deck_minimum_count_rule_version") \
			!= NORMAL_DECK_MINIMUM_COUNT_RULE_VERSION \
			or not _nonnegative_int(facts.get("draw_pile_count")) \
			or not _nonnegative_int(facts.get("committed_escrow_count")) \
			or not _nonnegative_int(facts.get("merge_history_count")) \
			or not _nonnegative_int(facts.get("commodity_inventory_count")) \
			or not _nonnegative_int(facts.get("commodity_merge_history_count")):
		return "projection_fact_identity_invalid"
	if not _local_queue_state_valid(facts.get("local_queue_state")) \
			or int((facts.get("local_queue_state", {}) as Dictionary).get(
				"batch_id", 0
			)) != int(facts.get("batch_index", 0)):
		return "projection_fact_local_queue_state_invalid"
	var hand_variant: Variant = facts.get("hand")
	var discard_variant: Variant = facts.get("discard")
	if not (hand_variant is Array) or not (discard_variant is Array):
		return "projection_fact_zones_invalid"
	var hand := hand_variant as Array
	var discard := discard_variant as Array
	if hand.size() > HAND_LIMIT \
			or facts.get("hand_count") != hand.size() \
			or facts.get("discard_count") != discard.size():
		return "projection_fact_zone_counts_invalid"
	if int(facts.get("normal_deck_total_card_count", 0)) != (
		hand.size()
		+ discard.size()
		+ int(facts.get("draw_pile_count", 0))
		+ int(facts.get("committed_escrow_count", 0))
	):
		return "projection_fact_normal_deck_total_invalid"
	var seen_ids: Array[String] = []
	for card_variant in hand + discard:
		if not (card_variant is Dictionary) or not _card_valid(card_variant as Dictionary):
			return "projection_fact_card_invalid"
		var instance_id := str((card_variant as Dictionary).get("instance_id", ""))
		if seen_ids.has(instance_id):
			return "projection_fact_card_duplicate"
		seen_ids.append(instance_id)
	var pairs_variant: Variant = facts.get("eligible_merge_pairs")
	if not (pairs_variant is Array) \
			or pairs_variant != _eligible_pairs_for_hand(
				hand,
				int(facts.get("normal_deck_total_card_count", 0))
			):
		return "projection_fact_merge_pairs_invalid"
	var commodity_variant: Variant = facts.get("commodity_inventory")
	if not (commodity_variant is Array):
		return "projection_fact_commodity_inventory_invalid"
	var commodities := commodity_variant as Array
	if commodities.size() > COMMODITY_INVENTORY_LIMIT \
			or facts.get("commodity_inventory_count") != commodities.size():
		return "projection_fact_commodity_inventory_count_invalid"
	var commodity_ids: Array[String] = []
	for commodity_variant_row in commodities:
		if not (commodity_variant_row is Dictionary) \
				or not _projected_commodity_valid(commodity_variant_row as Dictionary):
			return "projection_fact_commodity_invalid"
		var commodity_instance_id := str(
			(commodity_variant_row as Dictionary).get("instance_id", "")
		)
		if commodity_ids.has(commodity_instance_id):
			return "projection_fact_commodity_duplicate"
		commodity_ids.append(commodity_instance_id)
	var commodity_pairs_variant: Variant = facts.get("eligible_commodity_merge_pairs")
	if not (commodity_pairs_variant is Array) \
			or commodity_pairs_variant != _eligible_pairs_for_commodities(
				commodities,
				int(facts.get("batch_index", 0))
			):
		return "projection_fact_commodity_merge_pairs_invalid"
	if not _bound_source_state_valid(facts.get("bound_source_state")):
		return "projection_fact_bound_source_state_invalid"
	return ""


static func _intent_kinds_for_phase(phase: String) -> Array:
	if phase == PHASE_MAINTENANCE:
		return [ACTION_MERGE_CARDS, ACTION_MERGE_COMMODITIES, ACTION_END_MAINTENANCE]
	if phase == PHASE_BATCH:
		return [ACTION_PLAY_CARD, ACTION_MERGE_COMMODITIES]
	return []


func _dispatch_intent(intent: Dictionary) -> Dictionary:
	var action_kind := str(intent.get("action_kind", ""))
	match action_kind:
		ACTION_PLAY_CARD:
			return _apply_play_card(intent)
		ACTION_ACCEPT_PURCHASE:
			return _apply_purchase(intent)
		ACTION_COMPLETE_BATCH:
			return _apply_complete_batch(intent)
		ACTION_MERGE_CARDS:
			return _apply_merge(intent)
		ACTION_ACCEPT_COMMODITY_CLAIM:
			return _apply_commodity_claim(intent)
		ACTION_MERGE_COMMODITIES:
			return _apply_commodity_merge(intent)
		ACTION_LOCK_LOCAL_QUEUE:
			return _apply_lock_local_queue(intent)
		ACTION_END_MAINTENANCE:
			return _apply_end_maintenance(intent)
	return _result(false, "action_kind_unsupported")


func _apply_play_card(intent: Dictionary) -> Dictionary:
	if str(_state.get("phase", "")) != PHASE_BATCH:
		return _result(false, "play_outside_batch")
	if str(intent.get("decision_mode", "")) != DECISION_PLAYER_EXPLICIT:
		return _result(false, "play_requires_player_intent")
	var arguments := intent.get("arguments", {}) as Dictionary
	if not _exact_fields(arguments, ["instance_id"]):
		return _result(false, "play_arguments_invalid")
	var instance_id := str(arguments.get("instance_id", ""))
	var hand := _state.get("hand", []) as Array
	var index := _card_index(hand, instance_id)
	if index < 0:
		return _result(false, "play_card_not_in_hand")
	var card := hand[index] as Dictionary
	if bool(card.get("locked", false)):
		return _result(false, "play_card_locked")
	hand.remove_at(index)
	(_state.get("discard", []) as Array).append(card.duplicate(true))
	return _result(true, "card_played_to_discard", [instance_id], "", "discard")


func _apply_purchase(intent: Dictionary) -> Dictionary:
	if str(_state.get("phase", "")) != PHASE_BATCH:
		return _result(false, "purchase_outside_batch")
	if str(intent.get("decision_mode", "")) != DECISION_AUTHORITY:
		return _result(false, "purchase_requires_authority")
	var arguments := intent.get("arguments", {}) as Dictionary
	if not _exact_fields(arguments, ["purchase_receipt_id", "card_spec"]):
		return _result(false, "purchase_arguments_invalid")
	if not _stable_id(arguments.get("purchase_receipt_id")):
		return _result(false, "purchase_receipt_id_invalid")
	var spec_variant: Variant = arguments.get("card_spec")
	if not (spec_variant is Dictionary) or not _card_spec_valid(spec_variant as Dictionary):
		return _result(false, "purchased_card_spec_invalid")
	var spec := spec_variant as Dictionary
	var instance_id := _allocate_instance_id()
	var card := _card_from_spec(spec, instance_id)
	(_state.get("discard", []) as Array).append(card)
	return _result(
		true,
		"purchased_card_entered_discard",
		[instance_id],
		instance_id,
		"discard"
	)


func _apply_commodity_claim(intent: Dictionary) -> Dictionary:
	if str(_state.get("phase", "")) != PHASE_BATCH:
		return _result(false, "commodity_claim_outside_active_batch")
	if str(intent.get("decision_mode", "")) != DECISION_AUTHORITY:
		return _result(false, "commodity_claim_requires_authority")
	var arguments := intent.get("arguments", {}) as Dictionary
	if not _exact_fields(arguments, [
		"reservation_id", "track_claim_receipt", "source_identity", "source_item",
	]):
		return _result(false, "commodity_claim_arguments_invalid")
	var reservation_id := str(arguments.get("reservation_id", ""))
	if not _commodity_slot_reservations.has(reservation_id):
		return _result(false, "commodity_claim_requires_prepared_slot")
	var reservation := _commodity_slot_reservations.get(reservation_id, {}) as Dictionary
	if not _acquisition_reservation_valid(reservation) \
			or reservation.get("source_identity", {}) \
			!= arguments.get("source_identity", {}) \
			or reservation.get("source_item", {}) != arguments.get("source_item", {}):
		return _result(false, "commodity_claim_reservation_binding_invalid")
	var claim_variant: Variant = arguments.get("track_claim_receipt")
	if not (claim_variant is Dictionary) \
			or not (arguments.get("source_identity") is Dictionary) \
			or not (arguments.get("source_item") is Dictionary):
		return _result(false, "track_claim_receipt_invalid")
	var claim := claim_variant as Dictionary
	var source_identity := arguments.get("source_identity", {}) as Dictionary
	var projected_item := arguments.get("source_item", {}) as Dictionary
	var claim_reason := _track_receipt_for_reservation_reason(claim, reservation)
	if not claim_reason.is_empty():
		return _result(false, claim_reason)
	var request := reservation.get("request", {}) as Dictionary
	if str(request.get("actor_id", "")) != str(_state.get("owner_player_id", "")):
		return _result(false, "track_claim_actor_mismatch")
	var inventory := _state.get("commodity_inventory", []) as Array
	var claim_receipt_id := str(claim.get("receipt_id", ""))
	var track_intent_id := str(request.get("request_id", ""))
	var track_instance_id := str(source_identity.get("source_instance_id", ""))
	for row_variant in _state.get("commodity_claim_history", []) as Array:
		var row := row_variant as Dictionary
		if str(row.get("claim_receipt_id", "")) == claim_receipt_id:
			return _result(false, "track_claim_receipt_already_consumed")
		if str(row.get("track_intent_id", "")) == track_intent_id:
			return _result(false, "track_claim_intent_already_consumed")
		if str(row.get("track_instance_id", "")) == track_instance_id:
			return _result(false, "track_instance_already_claimed")
	if inventory.size() >= COMMODITY_INVENTORY_LIMIT:
		return _result(false, "commodity_inventory_full")
	var current_batch_id := int(_state.get("batch_index", 0))
	var local_queue_state := _state.get("local_queue_state", {}) as Dictionary
	var available_from_batch_id := current_batch_id + (
		1 if bool(local_queue_state.get("locked", false)) else 0
	)
	var instance_id := _allocate_commodity_instance_id()
	var commodity := {
		"instance_id": instance_id,
		"owner_player_id": str(_state.get("owner_player_id", "")),
		"commodity_id": str(source_identity.get("source_definition_id", "")),
		"primary_color": str(projected_item.get("primary_color", "")),
		"level": 1,
		"locked": false,
		"available_from_batch_id": available_from_batch_id,
		"source_track_instance_ids": [track_instance_id],
		"claim_receipt_ids": [claim_receipt_id],
	}
	inventory.append(commodity)
	var claim_history := _state.get("commodity_claim_history", []) as Array
	claim_history.append({
		"claim_receipt_id": claim_receipt_id,
		"claim_receipt_fingerprint": str(claim.get("receipt_fingerprint", "")),
		"track_intent_id": track_intent_id,
		"track_intent_fingerprint": str(claim.get("intent_fingerprint", "")),
		"track_instance_id": track_instance_id,
		"commodity_instance_id": instance_id,
		"commodity_id": str(commodity.get("commodity_id", "")),
		"primary_color": str(commodity.get("primary_color", "")),
		"level": int(commodity.get("level", 0)),
		"claim_batch_id": current_batch_id,
		"local_queue_locked_at_claim": bool(local_queue_state.get(
			"locked", false
		)),
		"available_from_batch_id": available_from_batch_id,
		"revision": int(_state.get("revision", 0)) + 1,
	})
	return _result(
		true,
		"commodity_claim_entered_inventory",
		[instance_id],
		instance_id,
		"commodity_inventory"
	)


func _apply_complete_batch(intent: Dictionary) -> Dictionary:
	if str(_state.get("phase", "")) != PHASE_BATCH:
		return _result(false, "batch_already_complete")
	if str(intent.get("decision_mode", "")) != DECISION_AUTHORITY:
		return _result(false, "batch_completion_requires_authority")
	if not (intent.get("arguments", {}) as Dictionary).is_empty():
		return _result(false, "batch_completion_arguments_invalid")
	var refill := _draw_to_hand_limit()
	_state["phase"] = PHASE_MAINTENANCE
	return _result(
		true,
		"batch_complete_hand_refilled",
		[],
		"",
		"hand",
		int(refill.get("drawn", 0)),
		int(refill.get("reshuffles", 0))
	)


func _apply_merge(intent: Dictionary) -> Dictionary:
	if str(_state.get("phase", "")) != PHASE_MAINTENANCE:
		return _result(false, "merge_outside_maintenance")
	if str(intent.get("decision_mode", "")) != DECISION_PLAYER_EXPLICIT:
		return _result(false, "automatic_merge_forbidden")
	var arguments := intent.get("arguments", {}) as Dictionary
	if not _exact_fields(arguments, ["left_instance_id", "right_instance_id"]):
		return _result(false, "merge_arguments_invalid")
	var left_id := str(arguments.get("left_instance_id", ""))
	var right_id := str(arguments.get("right_instance_id", ""))
	if left_id.is_empty() or right_id.is_empty() or left_id == right_id:
		return _result(false, "merge_pair_invalid")
	var hand := _state.get("hand", []) as Array
	var left_index := _card_index(hand, left_id)
	var right_index := _card_index(hand, right_id)
	if left_index < 0 or right_index < 0:
		return _result(false, "merge_card_not_in_hand")
	var left := hand[left_index] as Dictionary
	var right := hand[right_index] as Dictionary
	var eligibility_reason := _merge_eligibility_reason(left, right)
	if not eligibility_reason.is_empty():
		return _result(false, eligibility_reason)
	if _all_cards(_state).size() - 1 < NORMAL_DECK_MINIMUM_TOTAL_CARD_COUNT:
		return _result(false, "minimum_normal_deck_size_violation")

	var first_remove := maxi(left_index, right_index)
	var second_remove := mini(left_index, right_index)
	hand.remove_at(first_remove)
	hand.remove_at(second_remove)
	var result_level := int(left.get("level", 0)) + 1
	var result_spec := {
		"semantic_id": "facility.%s.%s.rank_%d" % [
			str(left.get("card_type", "")),
			str(left.get("primary_color", "")),
			result_level,
		],
		"primary_color": str(left.get("primary_color", "")),
		"card_type": str(left.get("card_type", "")),
		"merge_family_id": str(left.get("merge_family_id", "")),
		"level": result_level,
	}
	var result_id := _allocate_instance_id()
	var result_card := _card_from_spec(result_spec, result_id)
	hand.append(result_card)
	var merge_history := _state.get("merge_history", []) as Array
	merge_history.append({
		"merge_id": "merge.%06d" % (merge_history.size() + 1),
		"request_id": str(intent.get("request_id", "")),
		"source_instance_ids": [left_id, right_id],
		"result_instance_id": result_id,
		"semantic_id": str(result_card.get("semantic_id", "")),
		"primary_color": str(result_card.get("primary_color", "")),
		"card_type": str(result_card.get("card_type", "")),
		"merge_family_id": str(result_card.get("merge_family_id", "")),
		"level": result_level,
		"revision": int(_state.get("revision", 0)) + 1,
	})
	var refill := _draw_to_hand_limit()
	return _result(
		true,
		"normal_cards_merged",
		[left_id, right_id, result_id],
		result_id,
		"hand",
		int(refill.get("drawn", 0)),
		int(refill.get("reshuffles", 0))
	)


func _apply_commodity_merge(intent: Dictionary) -> Dictionary:
	if str(intent.get("decision_mode", "")) != DECISION_PLAYER_EXPLICIT:
		return _result(false, "automatic_commodity_merge_forbidden")
	var arguments := intent.get("arguments", {}) as Dictionary
	if not _exact_fields(arguments, ["left_instance_id", "right_instance_id"]):
		return _result(false, "commodity_merge_arguments_invalid")
	var left_id := str(arguments.get("left_instance_id", ""))
	var right_id := str(arguments.get("right_instance_id", ""))
	if left_id.is_empty() or right_id.is_empty() or left_id == right_id:
		return _result(false, "commodity_merge_pair_invalid")
	var inventory := _state.get("commodity_inventory", []) as Array
	var left_index := _commodity_index(inventory, left_id)
	var right_index := _commodity_index(inventory, right_id)
	if left_index < 0 or right_index < 0:
		return _result(false, "commodity_merge_item_not_in_inventory")
	var left := inventory[left_index] as Dictionary
	var right := inventory[right_index] as Dictionary
	var eligibility_reason := _commodity_merge_eligibility_reason(
		left,
		right,
		int(_state.get("batch_index", 0))
	)
	if not eligibility_reason.is_empty():
		return _result(false, eligibility_reason)
	var result_level := 2 if int(left.get("level", 0)) == 1 \
		and int(right.get("level", 0)) == 1 else 3
	var first_remove := maxi(left_index, right_index)
	var second_remove := mini(left_index, right_index)
	inventory.remove_at(first_remove)
	inventory.remove_at(second_remove)
	var result_id := _allocate_commodity_instance_id()
	var source_tracks := _unique_stable_ids(
		(left.get("source_track_instance_ids", []) as Array)
		+ (right.get("source_track_instance_ids", []) as Array)
	)
	var claim_receipts := _unique_stable_ids(
		(left.get("claim_receipt_ids", []) as Array)
		+ (right.get("claim_receipt_ids", []) as Array)
	)
	var result_commodity := {
		"instance_id": result_id,
		"owner_player_id": str(_state.get("owner_player_id", "")),
		"commodity_id": str(left.get("commodity_id", "")),
		"primary_color": str(left.get("primary_color", "")),
		"level": result_level,
		"locked": false,
		"available_from_batch_id": maxi(
			int(left.get("available_from_batch_id", 0)),
			int(right.get("available_from_batch_id", 0))
		),
		"source_track_instance_ids": source_tracks,
		"claim_receipt_ids": claim_receipts,
	}
	inventory.append(result_commodity)
	var history := _state.get("commodity_merge_history", []) as Array
	history.append({
		"merge_id": "commodity.merge.%06d" % (history.size() + 1),
		"request_id": str(intent.get("request_id", "")),
		"source_instance_ids": [left_id, right_id],
		"result_instance_id": result_id,
		"commodity_id": str(result_commodity.get("commodity_id", "")),
		"primary_color": str(result_commodity.get("primary_color", "")),
		"result_level": result_level,
		"available_from_batch_id": int(result_commodity.get(
			"available_from_batch_id", 0
		)),
		"revision": int(_state.get("revision", 0)) + 1,
	})
	return _result(
		true,
		"commodities_merged",
		[left_id, right_id, result_id],
		result_id,
		"commodity_inventory"
	)


func _apply_lock_local_queue(intent: Dictionary) -> Dictionary:
	if str(_state.get("phase", "")) != PHASE_BATCH:
		return _result(false, "local_queue_lock_outside_active_batch")
	if str(intent.get("decision_mode", "")) != DECISION_AUTHORITY:
		return _result(false, "local_queue_lock_requires_authority")
	if not _commodity_slot_reservations.is_empty():
		return _result(false, "local_queue_lock_blocked_by_acquisition_transaction")
	var arguments := intent.get("arguments", {}) as Dictionary
	if not _exact_fields(arguments, ["batch_id"]):
		return _result(false, "local_queue_lock_arguments_invalid")
	var batch_id_variant: Variant = arguments.get("batch_id")
	if not _positive_int(batch_id_variant) \
			or int(batch_id_variant) != int(_state.get("batch_index", 0)):
		return _result(false, "local_queue_batch_mismatch")
	var queue_state := _state.get("local_queue_state", {}) as Dictionary
	if bool(queue_state.get("locked", false)):
		return _result(false, "local_queue_already_locked")
	queue_state["locked"] = true
	_state["local_queue_state"] = queue_state
	return _result(true, "local_queue_locked", [], "", "local_queue")


func _apply_end_maintenance(intent: Dictionary) -> Dictionary:
	if str(_state.get("phase", "")) != PHASE_MAINTENANCE:
		return _result(false, "maintenance_not_active")
	if str(intent.get("decision_mode", "")) != DECISION_PLAYER_EXPLICIT:
		return _result(false, "maintenance_end_requires_player_intent")
	if not (intent.get("arguments", {}) as Dictionary).is_empty():
		return _result(false, "maintenance_end_arguments_invalid")
	_state["phase"] = PHASE_BATCH
	var next_batch_id := int(_state.get("batch_index", 0)) + 1
	_state["batch_index"] = next_batch_id
	_state["local_queue_state"] = _new_local_queue_state(next_batch_id, false)
	return _result(true, "maintenance_ended", [], "", "none")


func _draw_to_hand_limit() -> Dictionary:
	var hand := _state.get("hand", []) as Array
	var draw_pile := _state.get("draw_pile", []) as Array
	var drawn := 0
	var reshuffles := 0
	while hand.size() < HAND_LIMIT:
		if draw_pile.is_empty():
			if (_state.get("discard", []) as Array).is_empty():
				break
			_reshuffle_discard_into_draw_pile()
			reshuffles += 1
			draw_pile = _state.get("draw_pile", []) as Array
		hand.append(draw_pile.pop_back())
		drawn += 1
	return {"drawn": drawn, "reshuffles": reshuffles}


func _reshuffle_discard_into_draw_pile() -> void:
	var discard := _state.get("discard", []) as Array
	var shuffled := _shuffle_cards(discard, _state.get("reshuffle_rng", {}) as Dictionary)
	_state["draw_pile"] = (shuffled.get("cards", []) as Array).duplicate(true)
	_state["reshuffle_rng"] = (shuffled.get("cursor", {}) as Dictionary).duplicate(true)
	_state["discard"] = []


func _allocate_instance_id() -> String:
	var sequence := int(_state.get("next_instance_sequence", 0))
	_state["next_instance_sequence"] = sequence + 1
	return _instance_id(str(_state.get("owner_player_id", "")), sequence)


func _viewer_is_owner(viewer_player_id: String) -> bool:
	return is_ready() and viewer_player_id == str(_state.get("owner_player_id", ""))


func _viewer_private_facts() -> Dictionary:
	var hand_projection: Array = []
	for card_variant in _state.get("hand", []) as Array:
		hand_projection.append(_project_card(card_variant as Dictionary))
	var discard_projection: Array = []
	for card_variant in _state.get("discard", []) as Array:
		discard_projection.append(_project_card(card_variant as Dictionary))
	var commodity_projection: Array = []
	for commodity_variant in _state.get("commodity_inventory", []) as Array:
		commodity_projection.append(_project_commodity(commodity_variant as Dictionary))
	return {
		"phase": str(_state.get("phase", "")),
		"batch_index": int(_state.get("batch_index", 0)),
		"balance_profile_id": BALANCE_PROFILE_ID,
		"balance_profile_fingerprint": BALANCE_PROFILE_FINGERPRINT,
		"normal_deck_total_card_count": _all_cards(_state).size(),
		"normal_deck_minimum_total_card_count": (
			NORMAL_DECK_MINIMUM_TOTAL_CARD_COUNT
		),
		"normal_deck_minimum_count_rule_version": (
			NORMAL_DECK_MINIMUM_COUNT_RULE_VERSION
		),
		"local_queue_state": (
			_state.get("local_queue_state", {}) as Dictionary
		).duplicate(true),
		"hand": hand_projection,
		"hand_count": hand_projection.size(),
		"draw_pile_count": (_state.get("draw_pile", []) as Array).size(),
		"discard": discard_projection,
		"discard_count": discard_projection.size(),
		"committed_escrow_count": (
			_state.get("committed_escrow", []) as Array
		).size(),
		"merge_history_count": (_state.get("merge_history", []) as Array).size(),
		"eligible_merge_pairs": _eligible_merge_pairs(),
		"commodity_inventory": commodity_projection,
		"commodity_inventory_count": commodity_projection.size(),
		"commodity_merge_history_count": (
			_state.get("commodity_merge_history", []) as Array
		).size(),
		"eligible_commodity_merge_pairs": _eligible_commodity_merge_pairs(),
		"bound_source_state": (
			_state.get("bound_source_state", {}) as Dictionary
		).duplicate(true),
	}


static func _project_card(card: Dictionary) -> Dictionary:
	return {
		"instance_id": str(card.get("instance_id", "")),
		"semantic_id": str(card.get("semantic_id", "")),
		"primary_color": str(card.get("primary_color", "")),
		"card_type": str(card.get("card_type", "")),
		"merge_family_id": str(card.get("merge_family_id", "")),
		"level": int(card.get("level", 0)),
		"locked": bool(card.get("locked", false)),
	}


static func _project_commodity(commodity: Dictionary) -> Dictionary:
	return {
		"instance_id": str(commodity.get("instance_id", "")),
		"commodity_id": str(commodity.get("commodity_id", "")),
		"primary_color": str(commodity.get("primary_color", "")),
		"level": int(commodity.get("level", 0)),
		"locked": bool(commodity.get("locked", false)),
		"available_from_batch_id": int(commodity.get("available_from_batch_id", 0)),
	}


func _eligible_merge_pairs() -> Array:
	return _eligible_pairs_for_hand(
		_state.get("hand", []) as Array,
		_all_cards(_state).size()
	)


static func _eligible_pairs_for_hand(
	hand: Array,
	normal_deck_total_card_count: int = -1
) -> Array:
	var pairs: Array = []
	if normal_deck_total_card_count > 0 \
			and normal_deck_total_card_count - 1 \
			< NORMAL_DECK_MINIMUM_TOTAL_CARD_COUNT:
		return pairs
	for left_index in range(hand.size()):
		for right_index in range(left_index + 1, hand.size()):
			var left := hand[left_index] as Dictionary
			var right := hand[right_index] as Dictionary
			if _merge_eligibility_reason(left, right).is_empty():
				pairs.append([
					str(left.get("instance_id", "")),
					str(right.get("instance_id", "")),
				])
	return pairs


func _eligible_commodity_merge_pairs() -> Array:
	return _eligible_pairs_for_commodities(
		_state.get("commodity_inventory", []) as Array,
		int(_state.get("batch_index", 0))
	)


static func _eligible_pairs_for_commodities(
	commodities: Array,
	current_batch_id: int = -1
) -> Array:
	var pairs: Array = []
	for left_index in range(commodities.size()):
		for right_index in range(left_index + 1, commodities.size()):
			var left := commodities[left_index] as Dictionary
			var right := commodities[right_index] as Dictionary
			if _commodity_merge_eligibility_reason(
				left, right, current_batch_id
			).is_empty():
				pairs.append([
					str(left.get("instance_id", "")),
					str(right.get("instance_id", "")),
				])
	return pairs


func _allowed_intent_kinds() -> Array:
	return _intent_kinds_for_phase(str(_state.get("phase", "")))


static func _merge_eligibility_reason(left: Dictionary, right: Dictionary) -> String:
	if bool(left.get("locked", false)) or bool(right.get("locked", false)):
		return "merge_card_locked"
	if str(left.get("primary_color", "")) != str(right.get("primary_color", "")):
		return "merge_primary_color_mismatch"
	if str(left.get("card_type", "")) != str(right.get("card_type", "")):
		return "merge_card_type_mismatch"
	if str(left.get("merge_family_id", "")) != str(right.get("merge_family_id", "")):
		return "merge_family_mismatch"
	if int(left.get("level", 0)) != int(right.get("level", 0)):
		return "merge_level_mismatch"
	if int(left.get("level", 0)) >= MAX_CARD_LEVEL:
		return "merge_level_cap_reached"
	return ""


static func _commodity_merge_eligibility_reason(
	left: Dictionary,
	right: Dictionary,
	current_batch_id: int = -1
) -> String:
	if bool(left.get("locked", false)) or bool(right.get("locked", false)):
		return "commodity_merge_item_locked"
	if str(left.get("owner_player_id", "")) \
			!= str(right.get("owner_player_id", "")):
		return "commodity_merge_owner_mismatch"
	if str(left.get("commodity_id", "")) != str(right.get("commodity_id", "")):
		return "commodity_merge_identity_mismatch"
	if str(left.get("primary_color", "")) != str(right.get("primary_color", "")):
		return "commodity_merge_color_mismatch"
	if current_batch_id > 0 and (
		int(left.get("available_from_batch_id", 0)) > current_batch_id
		or int(right.get("available_from_batch_id", 0)) > current_batch_id
	):
		return "commodity_not_available_in_current_batch"
	var levels := [int(left.get("level", 0)), int(right.get("level", 0))]
	levels.sort()
	if levels == [1, 1] or levels == [1, 2]:
		return ""
	if int(levels[1]) >= MAX_COMMODITY_LEVEL:
		return "commodity_merge_level_cap_reached"
	return "commodity_merge_level_pair_invalid"


static func _intent_shape_reason(intent: Dictionary) -> String:
	if not _pure_data(intent) or not _exact_fields(intent, INTENT_FIELDS):
		return "intent_fields_invalid"
	if intent.get("schema_id") != INTENT_SCHEMA_ID \
			or intent.get("schema_version") != SCHEMA_VERSION \
			or intent.get("state_version") != STATE_VERSION \
			or intent.get("ruleset_id") != RULESET_ID \
			or intent.get("balance_profile_id") != BALANCE_PROFILE_ID \
			or intent.get("balance_profile_fingerprint") \
			!= BALANCE_PROFILE_FINGERPRINT \
			or intent.get("domain_id") != DOMAIN_ID \
			or intent.get("privacy_scope") != "actor_to_authority_private":
		return "intent_schema_invalid"
	if not _stable_id(intent.get("request_id")) \
			or not _stable_id(intent.get("actor_player_id")) \
			or str(intent.get("action_kind", "")) not in ACTION_KINDS \
			or not _nonnegative_int(intent.get("source_revision")) \
			or not _fingerprint_string(intent.get("source_core_fingerprint")) \
			or str(intent.get("decision_mode", "")) not in [
				DECISION_PLAYER_EXPLICIT, DECISION_AUTHORITY, DECISION_AUTOMATIC,
			] \
			or not (intent.get("arguments") is Dictionary):
		return "intent_identity_invalid"
	var expected_fingerprint := _fingerprint_without(intent, "intent_fingerprint")
	if str(intent.get("intent_fingerprint", "")) != expected_fingerprint:
		return "intent_fingerprint_invalid"
	return ""


func _build_receipt(
	intent: Dictionary,
	result: Dictionary,
	revision_before: int,
	source_core_fingerprint: String
) -> Dictionary:
	var success := bool(result.get("success", false))
	var receipt := {
		"schema_id": RECEIPT_SCHEMA_ID,
		"schema_version": SCHEMA_VERSION,
		"state_version": STATE_VERSION,
		"ruleset_id": RULESET_ID,
		"balance_profile_id": BALANCE_PROFILE_ID,
		"balance_profile_fingerprint": BALANCE_PROFILE_FINGERPRINT,
		"domain_id": DOMAIN_ID,
		"visibility_scope": "actor_private",
		"request_id": str(intent.get("request_id", "invalid_request")),
		"action_kind": str(intent.get("action_kind", "invalid_action")),
		"intent_fingerprint": str(intent.get("intent_fingerprint", "")),
		"source_core_fingerprint": source_core_fingerprint,
		"result_core_fingerprint": _core_fingerprint(_state),
		"success": success,
		"reason_code": str(result.get("reason_code", "core_result_invalid")),
		"revision_before": revision_before,
		"revision_after": int(_state.get("revision", revision_before)),
		"changed_instance_ids": (
			result.get("changed_instance_ids", []) as Array
		).duplicate(true),
		"created_instance_id": str(result.get("created_instance_id", "")),
		"destination_zone": str(result.get("destination_zone", "none")),
		"hand_count": (_state.get("hand", []) as Array).size(),
		"draw_pile_count": (_state.get("draw_pile", []) as Array).size(),
		"discard_count": (_state.get("discard", []) as Array).size(),
		"commodity_inventory_count": (
			_state.get("commodity_inventory", []) as Array
		).size(),
		"refill_count": int(result.get("refill_count", 0)),
		"reshuffle_count": int(result.get("reshuffle_count", 0)),
	}
	receipt["receipt_fingerprint"] = _fingerprint(receipt)
	return receipt


func _unbound_failure_receipt(intent: Dictionary, reason_code: String) -> Dictionary:
	var revision := int(_state.get("revision", 0))
	var safe_request_id := str(intent.get("request_id", "invalid_request")) \
		if _stable_id(intent.get("request_id")) else "invalid_request"
	var safe_action_kind := str(intent.get("action_kind", "invalid_action")) \
		if _stable_id(intent.get("action_kind")) else "invalid_action"
	var safe_intent_fingerprint := str(intent.get("intent_fingerprint", "")) \
		if _fingerprint_string(intent.get("intent_fingerprint")) else _fingerprint({
			"request_id": safe_request_id,
			"action_kind": safe_action_kind,
		})
	var result := _result(false, reason_code)
	var safe_intent := {
		"request_id": safe_request_id,
		"action_kind": safe_action_kind,
		"intent_fingerprint": safe_intent_fingerprint,
	}
	var current_core_fingerprint := _core_fingerprint(_state)
	return _build_receipt(
		safe_intent, result, revision, current_core_fingerprint
	)


static func _result(
	success: bool,
	reason_code: String,
	changed_instance_ids: Array = [],
	created_instance_id: String = "",
	destination_zone: String = "none",
	refill_count: int = 0,
	reshuffle_count: int = 0
) -> Dictionary:
	return {
		"success": success,
		"reason_code": reason_code,
		"changed_instance_ids": changed_instance_ids.duplicate(true),
		"created_instance_id": created_instance_id,
		"destination_zone": destination_zone,
		"refill_count": refill_count,
		"reshuffle_count": reshuffle_count,
	}


static func _state_valid(candidate: Dictionary) -> bool:
	if not _pure_data(candidate) or not _exact_fields(candidate, STATE_FIELDS):
		return false
	if candidate.get("schema_version") != SCHEMA_VERSION \
			or candidate.get("state_version") != STATE_VERSION \
			or candidate.get("ruleset_id") != RULESET_ID \
			or candidate.get("balance_profile_id") != BALANCE_PROFILE_ID \
			or candidate.get("balance_profile_fingerprint") \
			!= BALANCE_PROFILE_FINGERPRINT \
			or candidate.get("domain_id") != DOMAIN_ID \
			or not _stable_id(candidate.get("owner_player_id")) \
			or not _tagged_int64_valid(candidate.get("root_seed")) \
			or not _nonnegative_int(candidate.get("revision")) \
			or str(candidate.get("phase", "")) not in [PHASE_BATCH, PHASE_MAINTENANCE] \
			or not _positive_int(candidate.get("batch_index")) \
			or not _positive_int(candidate.get("next_instance_sequence")) \
			or not _positive_int(candidate.get("next_commodity_instance_sequence")) \
			or candidate.get("normal_deck_minimum_count_rule_version") \
			!= NORMAL_DECK_MINIMUM_COUNT_RULE_VERSION:
		return false
	if not _local_queue_state_valid(candidate.get("local_queue_state")) \
			or int((candidate.get("local_queue_state", {}) as Dictionary).get(
				"batch_id", 0
			)) != int(candidate.get("batch_index", 0)):
		return false
	var owner_player_id := str(candidate.get("owner_player_id", ""))
	for zone in ["draw_pile", "hand", "committed_escrow", "discard"]:
		if not (candidate.get(zone) is Array):
			return false
		for card_variant in candidate.get(zone) as Array:
			if not (card_variant is Dictionary) or not _card_valid(card_variant as Dictionary):
				return false
	if (candidate.get("hand", []) as Array).size() > HAND_LIMIT:
		return false
	if _all_cards(candidate).size() < NORMAL_DECK_MINIMUM_TOTAL_CARD_COUNT:
		return false
	if not _rng_valid(
		candidate.get("starter_rng", {}),
		"starter_deck_shuffle",
		owner_player_id,
		candidate.get("root_seed")
	) or not _rng_valid(
		candidate.get("reshuffle_rng", {}),
		"normal_deck_reshuffle_by_player",
		owner_player_id,
		candidate.get("root_seed")
	):
		return false
	var starter_rng := candidate.get("starter_rng", {}) as Dictionary
	if _tagged_int64_value(starter_rng.get("cursor")) != STARTER_SHUFFLE_DRAW_COUNT:
		return false
	if not (candidate.get("merge_history") is Array) \
			or not (candidate.get("commodity_inventory") is Array) \
			or not (candidate.get("commodity_claim_history") is Array) \
			or not (candidate.get("commodity_merge_history") is Array) \
			or not (candidate.get("processed_intent_ids") is Array) \
			or not (candidate.get("receipt_journal") is Dictionary) \
			or not _bound_source_state_valid(candidate.get("bound_source_state")):
		return false
	var seen_ids: Array[String] = []
	var maximum_sequence := 0
	for card_variant in _all_cards(candidate):
		var card := card_variant as Dictionary
		var instance_id := str(card.get("instance_id", ""))
		if seen_ids.has(instance_id) or not instance_id.begins_with(
			"dbg.%s." % owner_player_id
		):
			return false
		seen_ids.append(instance_id)
		maximum_sequence = maxi(maximum_sequence, _instance_sequence(instance_id))
	if int(candidate.get("next_instance_sequence", 0)) <= maximum_sequence:
		return false
	for row_variant in candidate.get("merge_history") as Array:
		if not (row_variant is Dictionary) or not _merge_history_row_valid(row_variant as Dictionary):
			return false
	if not _commodity_lineage_valid(candidate):
		return false
	var processed_ids := candidate.get("processed_intent_ids") as Array
	var seen_processed: Array[String] = []
	for request_variant in processed_ids:
		if not _stable_id(request_variant) or seen_processed.has(str(request_variant)):
			return false
		seen_processed.append(str(request_variant))
	var journal := candidate.get("receipt_journal") as Dictionary
	if processed_ids.size() != journal.size() \
			or int(candidate.get("revision", -1)) != processed_ids.size():
		return false
	for index in range(processed_ids.size()):
		var request_variant: Variant = processed_ids[index]
		if not _stable_id(request_variant):
			return false
		if not journal.has(request_variant):
			return false
		var receipt_variant: Variant = journal.get(request_variant)
		if not (receipt_variant is Dictionary) or not _receipt_valid(receipt_variant as Dictionary):
			return false
		if str((receipt_variant as Dictionary).get("request_id", "")) != str(request_variant) \
				or not bool((receipt_variant as Dictionary).get("success", false)) \
				or int((receipt_variant as Dictionary).get("revision_before", -1)) != index \
				or int((receipt_variant as Dictionary).get("revision_after", -1)) != index + 1:
			return false
	return true


static func _card_valid(card: Dictionary) -> bool:
	if not _exact_fields(card, CARD_FIELDS) \
			or not _stable_id(card.get("instance_id")) \
			or not (card.get("locked") is bool):
		return false
	return _card_spec_valid({
		"semantic_id": card.get("semantic_id"),
		"primary_color": card.get("primary_color"),
		"card_type": card.get("card_type"),
		"merge_family_id": card.get("merge_family_id"),
		"level": card.get("level"),
	})


static func _card_spec_valid(spec: Dictionary) -> bool:
	if not _exact_fields(spec, CARD_SPEC_FIELDS):
		return false
	var expected_family := "facility.%s.%s" % [
		str(spec.get("card_type", "")), str(spec.get("primary_color", "")),
	]
	var expected_semantic := "facility.%s.%s.rank_%d" % [
		str(spec.get("card_type", "")),
		str(spec.get("primary_color", "")),
		int(spec.get("level", 0)),
	]
	return str(spec.get("semantic_id", "")) == expected_semantic \
		and str(spec.get("primary_color", "")) in COLORS \
		and str(spec.get("card_type", "")) in CARD_TYPES \
		and str(spec.get("merge_family_id", "")) == expected_family \
		and _positive_int(spec.get("level")) \
		and int(spec.get("level", 0)) <= MAX_CARD_LEVEL


static func _rng_valid(
	value: Variant,
	expected_stream_id: String,
	expected_owner_player_id: String,
	root_seed_variant: Variant
) -> bool:
	if not (value is Dictionary):
		return false
	var stream := value as Dictionary
	if not _exact_fields(stream, RNG_FIELDS) \
			or stream.get("schema_version") != SCHEMA_VERSION \
			or stream.get("stream_id") != expected_stream_id \
			or stream.get("stream_instance_id") != expected_owner_player_id \
			or stream.get("authoritative_owner_id") != RNG_AUTHORITY_OWNER_ID \
			or stream.get("algorithm_id") != RNG_ALGORITHM_ID \
			or not _tagged_int64_valid(stream.get("seed")) \
			or not _tagged_int64_valid(stream.get("cursor"), true) \
			or not _tagged_int64_valid(stream.get("stream_revision"), true):
		return false
	if not _tagged_int64_valid(root_seed_variant):
		return false
	var expected_seed := _derive_stream_seed(
		_tagged_int64_value(root_seed_variant),
		expected_stream_id,
		expected_owner_player_id
	)
	if stream.get("seed") != _tagged_int64(expected_seed) \
			or _tagged_int64_value(stream.get("cursor")) \
			!= _tagged_int64_value(stream.get("stream_revision")):
		return false
	return _fingerprint_string(stream.get("state_fingerprint")) \
		and str(stream.get("state_fingerprint", "")) \
		== _fingerprint_without(stream, "state_fingerprint")


static func _empty_bound_source_state() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"contract_id": BOUND_SOURCE_STATE_CONTRACT_ID,
		"runtime_binding_supported": true,
		"entries": [],
	}


static func _new_local_queue_state(batch_id: int, locked: bool) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"contract_id": LOCAL_QUEUE_STATE_CONTRACT_ID,
		"batch_id": batch_id,
		"locked": locked,
	}


static func _local_queue_state_valid(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var queue_state := value as Dictionary
	return _exact_fields(queue_state, LOCAL_QUEUE_STATE_FIELDS) \
		and queue_state.get("schema_version") == SCHEMA_VERSION \
		and queue_state.get("contract_id") == LOCAL_QUEUE_STATE_CONTRACT_ID \
		and _positive_int(queue_state.get("batch_id")) \
		and queue_state.get("locked") is bool


static func _bound_source_state_valid(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var state := value as Dictionary
	if not _exact_fields(state, BOUND_SOURCE_STATE_FIELDS) \
			or state.get("schema_version") != SCHEMA_VERSION \
			or state.get("contract_id") != BOUND_SOURCE_STATE_CONTRACT_ID \
			or state.get("runtime_binding_supported") != true \
			or not (state.get("entries") is Array):
		return false
	var entries := state.get("entries", []) as Array
	if entries.size() > 1:
		return false
	if entries.is_empty():
		return true
	if not (entries[0] is Dictionary):
		return false
	var entry := entries[0] as Dictionary
	return _exact_fields(entry, BOUND_SOURCE_ENTRY_FIELDS) \
		and _stable_id(entry.get("match_instance_id")) \
		and str(entry.get("match_instance_id", "")) != "match.unspecified" \
		and _fingerprint_string(entry.get("lineage_fingerprint"))


static func _projected_commodity_valid(commodity: Dictionary) -> bool:
	return _exact_fields(commodity, PROJECTED_COMMODITY_CARD_FIELDS) \
		and _stable_id(commodity.get("instance_id")) \
		and _stable_id(commodity.get("commodity_id")) \
		and str(commodity.get("primary_color", "")) in COLORS \
		and _positive_int(commodity.get("level")) \
		and int(commodity.get("level", 0)) <= MAX_COMMODITY_LEVEL \
		and commodity.get("locked") is bool \
		and _positive_int(commodity.get("available_from_batch_id"))


static func _commodity_card_valid(
	commodity: Dictionary,
	expected_owner_player_id: String
) -> bool:
	if not _exact_fields(commodity, COMMODITY_CARD_FIELDS) \
			or not _stable_id(commodity.get("instance_id")) \
			or commodity.get("owner_player_id") != expected_owner_player_id \
			or not _stable_id(commodity.get("commodity_id")) \
			or str(commodity.get("primary_color", "")) not in COLORS \
			or not _positive_int(commodity.get("level")) \
			or int(commodity.get("level", 0)) > MAX_COMMODITY_LEVEL \
			or not (commodity.get("locked") is bool) \
			or not _positive_int(commodity.get("available_from_batch_id")) \
			or not (commodity.get("source_track_instance_ids") is Array) \
			or not (commodity.get("claim_receipt_ids") is Array):
		return false
	var source_ids := commodity.get("source_track_instance_ids") as Array
	var receipt_ids := commodity.get("claim_receipt_ids") as Array
	var level := int(commodity.get("level", 0))
	return source_ids.size() == level \
		and receipt_ids.size() == level \
		and _unique_stable_ids(source_ids).size() == source_ids.size() \
		and _unique_stable_ids(receipt_ids).size() == receipt_ids.size()


static func _commodity_claim_history_row_valid(row: Dictionary) -> bool:
	if not _exact_fields(row, COMMODITY_CLAIM_HISTORY_FIELDS):
		return false
	for field in [
		"claim_receipt_id",
		"track_intent_id",
		"track_instance_id",
		"commodity_instance_id",
		"commodity_id",
	]:
		if not _stable_id(row.get(field)):
			return false
	if not _positive_int(row.get("claim_batch_id")) \
			or not (row.get("local_queue_locked_at_claim") is bool) \
			or int(row.get("available_from_batch_id", 0)) != (
				int(row.get("claim_batch_id", 0))
				+ (1 if bool(row.get("local_queue_locked_at_claim", false)) else 0)
			):
		return false
	return _fingerprint_string(row.get("claim_receipt_fingerprint")) \
		and _fingerprint_string(row.get("track_intent_fingerprint")) \
		and str(row.get("primary_color", "")) in COLORS \
		and row.get("level") == 1 \
		and _positive_int(row.get("available_from_batch_id")) \
		and _positive_int(row.get("revision"))


static func _commodity_merge_history_row_valid(row: Dictionary) -> bool:
	if not _exact_fields(row, COMMODITY_MERGE_HISTORY_FIELDS) \
			or not _stable_id(row.get("merge_id")) \
			or not _stable_id(row.get("request_id")) \
			or not (row.get("source_instance_ids") is Array) \
			or (row.get("source_instance_ids") as Array).size() != 2 \
			or not _stable_id(row.get("result_instance_id")) \
			or not _stable_id(row.get("commodity_id")) \
			or str(row.get("primary_color", "")) not in COLORS \
			or int(row.get("result_level", 0)) not in [2, 3] \
			or not _positive_int(row.get("available_from_batch_id")) \
			or not _positive_int(row.get("revision")):
		return false
	var source_ids := row.get("source_instance_ids") as Array
	return _stable_id(source_ids[0]) and _stable_id(source_ids[1]) \
		and str(source_ids[0]) != str(source_ids[1])


static func _commodity_lineage_valid(candidate: Dictionary) -> bool:
	var owner_player_id := str(candidate.get("owner_player_id", ""))
	var inventory := candidate.get("commodity_inventory", []) as Array
	if inventory.size() > COMMODITY_INVENTORY_LIMIT:
		return false
	var generated: Dictionary = {}
	var lineage: Dictionary = {}
	var consumed: Dictionary = {}
	var seen_claim_receipts: Array[String] = []
	var seen_track_intents: Array[String] = []
	var seen_track_instances: Array[String] = []
	var maximum_sequence := 0
	for row_variant in candidate.get("commodity_claim_history", []) as Array:
		if not (row_variant is Dictionary) \
				or not _commodity_claim_history_row_valid(row_variant as Dictionary):
			return false
		var row := row_variant as Dictionary
		var instance_id := str(row.get("commodity_instance_id", ""))
		var receipt_id := str(row.get("claim_receipt_id", ""))
		var track_intent_id := str(row.get("track_intent_id", ""))
		var track_id := str(row.get("track_instance_id", ""))
		var sequence := _commodity_instance_sequence(instance_id)
		if generated.has(instance_id) or seen_claim_receipts.has(receipt_id) \
				or seen_track_intents.has(track_intent_id) \
				or seen_track_instances.has(track_id) or sequence <= 0 \
				or not instance_id.begins_with("commodity.%s." % owner_player_id):
			return false
		generated[instance_id] = true
		seen_claim_receipts.append(receipt_id)
		seen_track_intents.append(track_intent_id)
		seen_track_instances.append(track_id)
		maximum_sequence = maxi(maximum_sequence, sequence)
		lineage[instance_id] = {
			"commodity_id": str(row.get("commodity_id", "")),
			"primary_color": str(row.get("primary_color", "")),
			"level": 1,
			"available_from_batch_id": int(row.get("available_from_batch_id", 0)),
			"source_track_instance_ids": [track_id],
			"claim_receipt_ids": [receipt_id],
			"revision": int(row.get("revision", 0)),
		}
	var seen_merge_ids: Array[String] = []
	var seen_merge_requests: Array[String] = []
	for row_variant in candidate.get("commodity_merge_history", []) as Array:
		if not (row_variant is Dictionary) \
				or not _commodity_merge_history_row_valid(row_variant as Dictionary):
			return false
		var row := row_variant as Dictionary
		var merge_id := str(row.get("merge_id", ""))
		var request_id := str(row.get("request_id", ""))
		var result_id := str(row.get("result_instance_id", ""))
		var result_sequence := _commodity_instance_sequence(result_id)
		if seen_merge_ids.has(merge_id) or seen_merge_requests.has(request_id) \
				or generated.has(result_id) or result_sequence <= 0 \
				or not result_id.begins_with("commodity.%s." % owner_player_id):
			return false
		var source_ids := row.get("source_instance_ids") as Array
		var left_id := str(source_ids[0])
		var right_id := str(source_ids[1])
		if not lineage.has(left_id) or not lineage.has(right_id) \
				or consumed.has(left_id) or consumed.has(right_id) \
				or result_sequence <= _commodity_instance_sequence(left_id) \
				or result_sequence <= _commodity_instance_sequence(right_id):
			return false
		var left := lineage.get(left_id, {}) as Dictionary
		var right := lineage.get(right_id, {}) as Dictionary
		if int(left.get("revision", 0)) >= int(row.get("revision", 0)) \
				or int(right.get("revision", 0)) >= int(row.get("revision", 0)):
			return false
		var left_card := {
			"owner_player_id": owner_player_id,
			"commodity_id": left.get("commodity_id"),
			"primary_color": left.get("primary_color"),
			"level": left.get("level"),
			"locked": false,
			"available_from_batch_id": left.get("available_from_batch_id"),
		}
		var right_card := {
			"owner_player_id": owner_player_id,
			"commodity_id": right.get("commodity_id"),
			"primary_color": right.get("primary_color"),
			"level": right.get("level"),
			"locked": false,
			"available_from_batch_id": right.get("available_from_batch_id"),
		}
		if not _commodity_merge_eligibility_reason(left_card, right_card).is_empty():
			return false
		var result_level := 2 if int(left.get("level", 0)) == 1 \
			and int(right.get("level", 0)) == 1 else 3
		if row.get("commodity_id") != left.get("commodity_id") \
				or row.get("primary_color") != left.get("primary_color") \
				or row.get("result_level") != result_level \
				or row.get("available_from_batch_id") != maxi(
					int(left.get("available_from_batch_id", 0)),
					int(right.get("available_from_batch_id", 0))
				):
			return false
		var source_tracks := _unique_stable_ids(
			(left.get("source_track_instance_ids", []) as Array)
			+ (right.get("source_track_instance_ids", []) as Array)
		)
		var claim_receipts := _unique_stable_ids(
			(left.get("claim_receipt_ids", []) as Array)
			+ (right.get("claim_receipt_ids", []) as Array)
		)
		if source_tracks.size() != result_level or claim_receipts.size() != result_level:
			return false
		consumed[left_id] = true
		consumed[right_id] = true
		generated[result_id] = true
		seen_merge_ids.append(merge_id)
		seen_merge_requests.append(request_id)
		maximum_sequence = maxi(maximum_sequence, result_sequence)
		lineage[result_id] = {
			"commodity_id": left.get("commodity_id"),
			"primary_color": left.get("primary_color"),
			"level": result_level,
			"available_from_batch_id": int(row.get(
				"available_from_batch_id", 0
			)),
			"source_track_instance_ids": source_tracks,
			"claim_receipt_ids": claim_receipts,
			"revision": int(row.get("revision", 0)),
		}
	var live_ids: Dictionary = {}
	for commodity_variant in inventory:
		if not (commodity_variant is Dictionary) \
				or not _commodity_card_valid(
					commodity_variant as Dictionary, owner_player_id
				):
			return false
		var commodity := commodity_variant as Dictionary
		var instance_id := str(commodity.get("instance_id", ""))
		if live_ids.has(instance_id) or consumed.has(instance_id) \
				or not lineage.has(instance_id):
			return false
		var expected := lineage.get(instance_id, {}) as Dictionary
		if commodity.get("commodity_id") != expected.get("commodity_id") \
				or commodity.get("primary_color") != expected.get("primary_color") \
				or commodity.get("level") != expected.get("level") \
				or commodity.get("available_from_batch_id") \
				!= expected.get("available_from_batch_id") \
				or commodity.get("source_track_instance_ids") \
				!= expected.get("source_track_instance_ids") \
				or commodity.get("claim_receipt_ids") != expected.get("claim_receipt_ids"):
			return false
		live_ids[instance_id] = true
	for instance_id_variant in generated.keys():
		var generated_id := str(instance_id_variant)
		if consumed.has(generated_id) == live_ids.has(generated_id):
			return false
	return int(candidate.get("next_commodity_instance_sequence", 0)) \
		> maximum_sequence


static func _merge_history_row_valid(row: Dictionary) -> bool:
	var fields := [
		"merge_id", "request_id", "source_instance_ids", "result_instance_id",
		"semantic_id", "primary_color", "card_type", "merge_family_id", "level",
		"revision",
	]
	if not _exact_fields(row, fields) \
			or not _stable_id(row.get("merge_id")) \
			or not _stable_id(row.get("request_id")) \
			or not (row.get("source_instance_ids") is Array) \
			or (row.get("source_instance_ids") as Array).size() != 2 \
			or not _stable_id(row.get("result_instance_id")) \
			or not _stable_id(row.get("semantic_id")) \
			or str(row.get("primary_color", "")) not in COLORS \
			or str(row.get("card_type", "")) not in CARD_TYPES \
			or not _stable_id(row.get("merge_family_id")) \
			or not _positive_int(row.get("level")) \
			or int(row.get("level", 0)) > MAX_CARD_LEVEL \
			or not _positive_int(row.get("revision")):
		return false
	var source_ids := row.get("source_instance_ids") as Array
	return _stable_id(source_ids[0]) and _stable_id(source_ids[1]) \
		and str(source_ids[0]) != str(source_ids[1])


static func _receipt_valid(receipt: Dictionary) -> bool:
	if not _exact_fields(receipt, RECEIPT_FIELDS) \
			or receipt.get("schema_id") != RECEIPT_SCHEMA_ID \
			or receipt.get("schema_version") != SCHEMA_VERSION \
			or receipt.get("state_version") != STATE_VERSION \
			or receipt.get("ruleset_id") != RULESET_ID \
			or receipt.get("balance_profile_id") != BALANCE_PROFILE_ID \
			or receipt.get("balance_profile_fingerprint") \
			!= BALANCE_PROFILE_FINGERPRINT \
			or receipt.get("domain_id") != DOMAIN_ID \
			or receipt.get("visibility_scope") != "actor_private" \
			or not _stable_id(receipt.get("request_id")) \
			or not _stable_id(receipt.get("action_kind")) \
			or not _fingerprint_string(receipt.get("intent_fingerprint")) \
			or not _fingerprint_string(receipt.get("source_core_fingerprint")) \
			or not _fingerprint_string(receipt.get("result_core_fingerprint")) \
			or not (receipt.get("success") is bool) \
			or not _stable_id(receipt.get("reason_code")) \
			or not _nonnegative_int(receipt.get("revision_before")) \
			or not _nonnegative_int(receipt.get("revision_after")) \
			or not (receipt.get("changed_instance_ids") is Array) \
			or not (receipt.get("created_instance_id") is String) \
			or not _stable_id(receipt.get("destination_zone")) \
			or not _nonnegative_int(receipt.get("hand_count")) \
			or not _nonnegative_int(receipt.get("draw_pile_count")) \
			or not _nonnegative_int(receipt.get("discard_count")) \
			or not _nonnegative_int(receipt.get("commodity_inventory_count")) \
			or int(receipt.get("commodity_inventory_count", 0)) \
			> COMMODITY_INVENTORY_LIMIT \
			or not _nonnegative_int(receipt.get("refill_count")) \
			or not _nonnegative_int(receipt.get("reshuffle_count")):
		return false
	for instance_id_variant in receipt.get("changed_instance_ids") as Array:
		if not _stable_id(instance_id_variant):
			return false
	return _fingerprint_string(receipt.get("receipt_fingerprint")) \
		and str(receipt.get("receipt_fingerprint", "")) \
		== _fingerprint_without(receipt, "receipt_fingerprint")


static func _card_from_spec(spec: Dictionary, instance_id: String) -> Dictionary:
	return {
		"instance_id": instance_id,
		"semantic_id": str(spec.get("semantic_id", "")),
		"primary_color": str(spec.get("primary_color", "")),
		"card_type": str(spec.get("card_type", "")),
		"merge_family_id": str(spec.get("merge_family_id", "")),
		"level": int(spec.get("level", 0)),
		"locked": false,
	}


static func _all_cards(candidate: Dictionary) -> Array:
	var cards: Array = []
	for zone in ["draw_pile", "hand", "committed_escrow", "discard"]:
		if candidate.get(zone) is Array:
			for card_variant in candidate.get(zone) as Array:
				cards.append((card_variant as Dictionary).duplicate(true))
	return cards


static func _card_index(cards: Array, instance_id: String) -> int:
	for index in range(cards.size()):
		if str((cards[index] as Dictionary).get("instance_id", "")) == instance_id:
			return index
	return -1


static func _commodity_index(commodities: Array, instance_id: String) -> int:
	for index in range(commodities.size()):
		if str((commodities[index] as Dictionary).get("instance_id", "")) \
				== instance_id:
			return index
	return -1


static func _instance_id(owner_player_id: String, sequence: int) -> String:
	return "dbg.%s.%06d" % [owner_player_id, sequence]


static func _instance_sequence(instance_id: String) -> int:
	var pieces := instance_id.split(".")
	return int(pieces[pieces.size() - 1]) if not pieces.is_empty() else -1


func _allocate_commodity_instance_id() -> String:
	var sequence := int(_state.get("next_commodity_instance_sequence", 0))
	_state["next_commodity_instance_sequence"] = sequence + 1
	return _commodity_instance_id(
		str(_state.get("owner_player_id", "")), sequence
	)


static func _commodity_instance_id(owner_player_id: String, sequence: int) -> String:
	return "commodity.%s.%06d" % [owner_player_id, sequence]


static func _commodity_instance_sequence(instance_id: String) -> int:
	var pieces := instance_id.split(".")
	return int(pieces[pieces.size() - 1]) if not pieces.is_empty() else -1


static func _unique_stable_ids(values: Array) -> Array:
	var result: Array = []
	for value_variant in values:
		if _stable_id(value_variant) and not result.has(str(value_variant)):
			result.append(str(value_variant))
	return result


static func _new_rng_cursor(
	stream_id: String,
	owner_player_id: String,
	root_seed: int
) -> Dictionary:
	var stream := {
		"schema_version": SCHEMA_VERSION,
		"stream_id": stream_id,
		"stream_instance_id": owner_player_id,
		"authoritative_owner_id": RNG_AUTHORITY_OWNER_ID,
		"algorithm_id": RNG_ALGORITHM_ID,
		"seed": _tagged_int64(
			_derive_stream_seed(root_seed, stream_id, owner_player_id)
		),
		"cursor": _tagged_int64(0),
		"stream_revision": _tagged_int64(0),
	}
	stream["state_fingerprint"] = _fingerprint(stream)
	return stream


static func _derive_stream_seed(
	root_seed: int,
	stream_id: String,
	owner_player_id: String
) -> int:
	var digest := ("%s:%s:%s:%s" % [
		RULESET_ID,
		str(root_seed),
		stream_id,
		owner_player_id,
	]).sha256_text()
	var upper_unsigned := int(digest.substr(0, 8).hex_to_int())
	var lower_unsigned := int(digest.substr(8, 8).hex_to_int())
	var upper_signed := upper_unsigned \
		if upper_unsigned < 2147483648 else upper_unsigned - 4294967296
	return (upper_signed * 4294967296) + lower_unsigned


static func _shuffle_cards(cards: Array, cursor: Dictionary) -> Dictionary:
	var shuffled := cards.duplicate(true)
	var terminal := cursor.duplicate(true)
	for index in range(shuffled.size() - 1, 0, -1):
		var step := _next_rng(terminal)
		terminal = step.get("cursor", {}) as Dictionary
		var swap_index := int(step.get("value", 0)) % (index + 1)
		var held: Variant = shuffled[index]
		shuffled[index] = shuffled[swap_index]
		shuffled[swap_index] = held
	return {"cards": shuffled, "cursor": terminal}


static func _next_rng(cursor: Dictionary) -> Dictionary:
	var cursor_value := _tagged_int64_value(cursor.get("cursor"))
	var revision_value := _tagged_int64_value(cursor.get("stream_revision"))
	var seed := cursor.get("seed", {}) as Dictionary
	var material := "%s:%s:%s:%s:%s:%d" % [
		RULESET_ID,
		RNG_ALGORITHM_ID,
		str(cursor.get("stream_id", "")),
		str(cursor.get("stream_instance_id", "")),
		str(seed.get("decimal", "0")),
		cursor_value,
	]
	var value := int(material.sha256_text().substr(0, 15).hex_to_int())
	var terminal := cursor.duplicate(true)
	terminal["cursor"] = _tagged_int64(cursor_value + 1)
	terminal["stream_revision"] = _tagged_int64(revision_value + 1)
	terminal["state_fingerprint"] = _fingerprint_without(
		terminal, "state_fingerprint"
	)
	return {"value": value, "cursor": terminal}


static func _tagged_int64(value: int) -> Dictionary:
	return {"type": "int64", "decimal": str(value)}


static func _tagged_int64_valid(value: Variant, require_nonnegative: bool = false) -> bool:
	if not (value is Dictionary) \
			or not _exact_fields(value as Dictionary, TAGGED_INT64_FIELDS):
		return false
	var tagged := value as Dictionary
	if tagged.get("type") != "int64" or not (tagged.get("decimal") is String):
		return false
	var decimal := str(tagged.get("decimal", ""))
	if decimal.is_empty() or not decimal.is_valid_int():
		return false
	var parsed := decimal.to_int()
	if str(parsed) != decimal:
		return false
	return not require_nonnegative or parsed >= 0


static func _tagged_int64_value(value: Variant) -> int:
	if not _tagged_int64_valid(value):
		return 0
	return str((value as Dictionary).get("decimal", "0")).to_int()


static func _document_save_section(state: Dictionary) -> Dictionary:
	var draw_order: Array = []
	for card_variant in state.get("draw_pile", []) as Array:
		draw_order.append(str((card_variant as Dictionary).get("instance_id", "")))
	var discard_order: Array = []
	for card_variant in state.get("discard", []) as Array:
		discard_order.append(str((card_variant as Dictionary).get("instance_id", "")))
	var player := {
		"player_id": str(state.get("owner_player_id", "")),
		"draw_pile_order": draw_order,
		"hand": (state.get("hand", []) as Array).duplicate(true),
		"committed_escrow": (
			state.get("committed_escrow", []) as Array
		).duplicate(true),
		"discard_order": discard_order,
		"merge_results_and_lineage": {
			"normal": (state.get("merge_history", []) as Array).duplicate(true),
			"commodity": (
				state.get("commodity_merge_history", []) as Array
			).duplicate(true),
		},
		"commodity_inventory": (
			state.get("commodity_inventory", []) as Array
		).duplicate(true),
		"bound_source_state": (
			state.get("bound_source_state", {}) as Dictionary
		).duplicate(true),
		"local_queue_state": (
			state.get("local_queue_state", {}) as Dictionary
		).duplicate(true),
		"normal_deck_minimum_count_rule_version": state.get(
			"normal_deck_minimum_count_rule_version"
		),
		"zone_revision": _tagged_int64(int(state.get("revision", 0))),
	}
	var allocator_cursor := maxi(
		int(state.get("next_instance_sequence", 0)),
		int(state.get("next_commodity_instance_sequence", 0))
	)
	return {
		"section_id": "personal_dbg_and_merge",
		"section_version": SCHEMA_VERSION,
		"state_version": STATE_VERSION,
		"ruleset_id": RULESET_ID,
		"balance_profile_id": BALANCE_PROFILE_ID,
		"balance_profile_fingerprint": BALANCE_PROFILE_FINGERPRINT,
		"semantic_owner": RNG_AUTHORITY_OWNER_ID,
		"privacy": "player_private_partitioned",
		"state_revision": _tagged_int64(int(state.get("revision", 0))),
		"players": [player],
		"merge_instance_allocator_cursor": _tagged_int64(allocator_cursor),
		"processed_intent_ids": (
			state.get("processed_intent_ids", []) as Array
		).duplicate(true),
		"receipt_ledger": (
			state.get("receipt_journal", {}) as Dictionary
		).duplicate(true),
		"rng_stream_states": [
			(state.get("starter_rng", {}) as Dictionary).duplicate(true),
			(state.get("reshuffle_rng", {}) as Dictionary).duplicate(true),
		],
	}


static func _exact_fields(value: Dictionary, expected_fields: Array) -> bool:
	if value.size() != expected_fields.size():
		return false
	for field_variant in expected_fields:
		if not value.has(str(field_variant)):
			return false
	return true


static func _stable_id(value: Variant) -> bool:
	if not (value is String or value is StringName):
		return false
	var text := str(value)
	if text.is_empty() or text.length() > 160 or text.strip_edges() != text:
		return false
	for index in range(text.length()):
		var code := text.unicode_at(index)
		var allowed := (code >= 48 and code <= 57) \
			or (code >= 65 and code <= 90) \
			or (code >= 97 and code <= 122) \
			or code in [45, 46, 58, 95]
		if not allowed:
			return false
	return true


static func _positive_int(value: Variant) -> bool:
	return value is int and int(value) > 0


static func _nonnegative_int(value: Variant) -> bool:
	return value is int and int(value) >= 0


static func _fingerprint_string(value: Variant) -> bool:
	if not (value is String) or str(value).length() != 64:
		return false
	for index in range(64):
		var code := str(value).unicode_at(index)
		if not ((code >= 48 and code <= 57) or (code >= 97 and code <= 102)):
			return false
	return true


static func _fingerprint(value: Variant) -> String:
	return _canonical(value).sha256_text()


static func _core_fingerprint(state: Dictionary) -> String:
	var core_facts := state.duplicate(true)
	core_facts.erase("receipt_journal")
	return _fingerprint(core_facts)


static func _fingerprint_without(value: Dictionary, excluded_field: String) -> String:
	var copy := value.duplicate(true)
	copy.erase(excluded_field)
	return _fingerprint(copy)


static func _canonical(value: Variant) -> String:
	if value == null:
		return "null"
	if value is bool:
		return "true" if bool(value) else "false"
	if value is int:
		return str(value)
	if value is float:
		var number := float(value)
		if is_finite(number) and number == floor(number) and absf(number) <= 9007199254740991.0:
			return str(int(number))
		return str(number)
	if value is String or value is StringName:
		return JSON.stringify(str(value))
	if value is Array:
		var rows: Array[String] = []
		for item_variant in value as Array:
			rows.append(_canonical(item_variant))
		return "[%s]" % ",".join(rows)
	if value is Dictionary:
		var keys: Array[String] = []
		for key_variant in (value as Dictionary).keys():
			keys.append(str(key_variant))
		keys.sort()
		var pairs: Array[String] = []
		for key in keys:
			pairs.append("%s:%s" % [JSON.stringify(key), _canonical((value as Dictionary).get(key))])
		return "{%s}" % ",".join(pairs)
	return "<invalid>"


static func _normalize_json_numbers(value: Variant, depth: int = 0) -> Variant:
	if depth > 64:
		return null
	if value is float:
		var number := float(value)
		if is_finite(number) and number == floor(number) and absf(number) <= 9007199254740991.0:
			return int(number)
		return number
	if value is Array:
		var normalized_array: Array = []
		for item_variant in value as Array:
			normalized_array.append(_normalize_json_numbers(item_variant, depth + 1))
		return normalized_array
	if value is Dictionary:
		var normalized_dictionary := {}
		for key_variant in (value as Dictionary).keys():
			normalized_dictionary[str(key_variant)] = _normalize_json_numbers(
				(value as Dictionary).get(key_variant), depth + 1
			)
		return normalized_dictionary
	return value


static func _pure_data(value: Variant, depth: int = 0) -> bool:
	if depth > 64:
		return false
	if value == null or value is bool or value is int \
			or value is String or value is StringName:
		return true
	if value is float:
		return is_finite(float(value))
	if value is Array:
		for item_variant in value as Array:
			if not _pure_data(item_variant, depth + 1):
				return false
		return true
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if not (key_variant is String or key_variant is StringName) \
					or not _pure_data((value as Dictionary).get(key_variant), depth + 1):
				return false
		return true
	return false


static func _contains_key_recursive(value: Variant, forbidden_keys: Array) -> bool:
	if value is Array:
		for item_variant in value as Array:
			if _contains_key_recursive(item_variant, forbidden_keys):
				return true
		return false
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if str(key_variant) in forbidden_keys:
				return true
			if _contains_key_recursive((value as Dictionary).get(key_variant), forbidden_keys):
				return true
	return false
