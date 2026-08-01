extends RefCounted
class_name V07UnifiedCardTrackCore

const SCHEMA_VERSION := 1
const STATE_VERSION := 2
const RULESET_ID := "v0.7"
const DOMAIN_ID := "unified_card_track"

const CORE_INTERFACE_ID := "v07.unified_track.core_authority.v1"
const AI_INTERFACE_ID := "v07.unified_track.ai_observation.v1"
const PLAYER_INTERFACE_ID := "v07.unified_track.player_projection.v1"
const INTENT_INTERFACE_ID := "v07.unified_track.intent.v1"
const RECEIPT_INTERFACE_ID := "v07.unified_track.authoritative_receipt.v1"
const SAVE_INTERFACE_ID := "v07.unified_track.save_state.v1"
const CHECKPOINT_INTERFACE_ID := "v07.unified_track.checkpoint.v1"
const ACQUISITION_PROPOSAL_INTERFACE_ID := "v07.unified_track.acquisition_proposal.v1"
const ACQUISITION_AUTHORITY_PORT_INTERFACE_ID := (
	"v07.unified_track.acquisition_authority_port.v1"
)
const ACQUISITION_AUTHORITY_PORT_SCRIPT_PATH := (
	"res://scripts/v07_semantic/v07_track_acquisition_authority_port.gd"
)
const PRIVACY_POLICY_ID := "v07.unified_track.privacy.v1"
const ROOT_LINEAGE_PARENT_HASH := (
	"0000000000000000000000000000000000000000000000000000000000000000"
)

const UNIFIED_TRACK_STATE_ID := "V07UnifiedCardTrackState"
const COLOR_CYCLE_STATE_ID := "V07MarketColorCycleState"
const HIDDEN_LEAD_STATE_ID := "V07HiddenLeadCycleState"

const COLOR_IDS := [
	"life",
	"energy",
	"industry",
	"technology",
	"commerce",
	"shipping",
]
const CARD_KIND_IDS := ["normal_card", "commodity_card"]

const ACTION_SET_STANCE := "color_cycle.set_stance"
const ACTION_COMMIT_COLOR_CYCLE := "color_cycle.commit_boundary"
const ACTION_ADVANCE_TRACK := "unified_track.advance"
const ACTION_CLAIM_VISIBLE_COMMODITY := "claim_visible_commodity"
const ACTION_PURCHASE_VISIBLE_NORMAL_CARD := "purchase_visible_normal_card"
const ACTION_IDS := [
	ACTION_SET_STANCE,
	ACTION_COMMIT_COLOR_CYCLE,
	ACTION_ADVANCE_TRACK,
	ACTION_CLAIM_VISIBLE_COMMODITY,
	ACTION_PURCHASE_VISIBLE_NORMAL_CARD,
]
const ACQUISITION_ACTION_IDS := [
	ACTION_CLAIM_VISIBLE_COMMODITY,
	ACTION_PURCHASE_VISIBLE_NORMAL_CARD,
]

const NORMAL_INFLUENCE_BASIS_POINTS := 300
const LEAD_INFLUENCE_BASIS_POINTS := 600
const DISTRIBUTION_BASIS_POINTS := 10000
const COLOR_WEIGHT_TOTAL := 60000
const UNIFORM_COLOR_WEIGHT := 10000
const NORMAL_INFLUENCE_WEIGHT := 1800
const LEAD_INFLUENCE_WEIGHT := 3600
const MINIMUM_COLOR_WEIGHT := 3000
const MAXIMUM_COLOR_WEIGHT := 24000
const COLOR_BAG_SIZE := 600
const TYPE_BAG_SIZE := 100

const DEFAULT_NORMAL_RATIO_BASIS_POINTS := 7000
const DEFAULT_COMMODITY_RATIO_BASIS_POINTS := 3000
const DEFAULT_LOCAL_VISIBLE_SLOT_COUNT := 5
const MIN_PLAYER_COUNT := 3
const MAX_PLAYER_COUNT := 8

const RNG_MODULUS := 2147483647
const RNG_MULTIPLIER := 48271

const STATE_FIELDS := [
	"schema_version",
	"state_version",
	"ruleset_id",
	"domain_id",
	"revision",
	"match_seed",
	"match_instance_id",
	"match_instance_id_explicit",
	"roster_ids",
	"track_state",
	"type_supply_state",
	"normal_supply_state",
	"commodity_supply_state",
	"color_cycle_state",
	"hidden_lead_cycle_state",
	"projection_revisions",
	"processed_requests",
	"revision_lineage",
]
const REVISION_LINEAGE_ENTRY_FIELDS := [
	"revision",
	"request_id",
	"action_id",
	"intent_fingerprint",
	"parent_lineage_hash",
	"state_payload_fingerprint",
	"lineage_hash",
]
const TRACK_FIELDS := [
	"state_id",
	"revision",
	"capacity",
	"local_visible_slot_count",
	"next_instance_sequence",
	"items",
]
const TRACK_ITEM_FIELDS := [
	"instance_id",
	"card_definition_id",
	"card_kind",
	"primary_color",
	"path_origin_index",
	"path_position",
	"segment_owner_id",
	"supply_draw_index",
]
const TYPE_SUPPLY_FIELDS := [
	"stream_id",
	"ratio_basis_points",
	"bag",
	"cursor",
	"bag_cycle",
	"rng_state",
	"rng_draw_count",
]
const DEFINITION_SUPPLY_FIELDS := [
	"stream_id",
	"card_kind",
	"templates",
	"bag",
	"cursor",
	"bag_cycle",
	"rng_state",
	"rng_draw_count",
]
const COLOR_CYCLE_FIELDS := [
	"state_id",
	"cycle_number",
	"distribution_weight_units",
	"distribution_basis_points",
	"pending_stances",
	"revealed_stances",
	"color_supply_state",
]
const COLOR_SUPPLY_FIELDS := [
	"stream_id",
	"bag",
	"cursor",
	"bag_cycle",
	"rng_state",
	"rng_draw_count",
]
const HIDDEN_LEAD_FIELDS := [
	"state_id",
	"stream_id",
	"fixed_order",
	"macro_round_number",
	"direction",
	"round_order",
	"lead_cursor",
	"current_lead_id",
	"completed_lead_ids",
	"rng_state",
	"rng_draw_count",
]
const STANCE_FIELDS := ["increase_color", "decrease_color"]
const REVEALED_STANCE_FIELDS := ["actor_id", "increase_color", "decrease_color"]
const SOURCE_IDENTITY_FIELDS := [
	"schema_version",
	"source_identity_id",
	"source_instance_id",
	"source_definition_id",
	"source_kind",
	"source_track_revision",
	"segment_owner_id",
	"identity_fingerprint",
]
const SOURCE_IDENTITY_UNSEALED_FIELDS := [
	"schema_version",
	"source_identity_id",
	"source_instance_id",
	"source_definition_id",
	"source_kind",
	"source_track_revision",
	"segment_owner_id",
]
const VIEWER_AUTHORIZATION_FIELDS := [
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
const VIEWER_AUTHORIZATION_UNSEALED_FIELDS := [
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
]
const CASH_DELTA_FIELDS := [
	"mode",
	"track_core_committed",
	"amount_known",
	"amount_decimal",
	"external_authority_id",
]
const INVENTORY_COMMIT_FIELDS := [
	"track_core_committed",
	"external_authority_id",
	"destination_zone",
]
const PROCESSED_REQUEST_FIELDS := [
	"intent_fingerprint",
	"action_id",
	"accepted",
	"reason_code",
	"source_revision",
	"result_revision",
	"receipt_id",
	"intent_id",
	"committed_core_revision",
	"destination_zone",
	"cash_delta",
	"inventory_commit",
	"external_authority_commit_required",
	"consumed_capability_id",
	"consumed_authorization_id",
	"public_facts",
]
const INTENT_FIELDS := [
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
const RECEIPT_FIELDS := [
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
const STANCE_PUBLIC_FACT_FIELDS := ["stance_recorded"]
const COLOR_CYCLE_PUBLIC_FACT_FIELDS := [
	"color_cycle_number",
	"color_distribution_basis_points",
	"revealed_stances",
]
const TRACK_ADVANCE_PUBLIC_FACT_FIELDS := ["advanced_steps", "track_revision"]
const ACQUISITION_PUBLIC_FACT_FIELDS := [
	"track_item_removed",
	"replacement_count",
	"track_revision",
]
const ACQUISITION_PROPOSAL_FIELDS := [
	"schema_version",
	"interface_id",
	"domain_id",
	"request_id",
	"intent_id",
	"intent_fingerprint",
	"actor_id",
	"action_id",
	"source_revision",
	"source_core_revision",
	"source_track_revision",
	"source_identity",
	"destination_zone",
	"participant_requirements",
	"cash_reservation_required",
	"asset_reservation_required",
	"proposal_fingerprint",
]
const ACQUISITION_PARTICIPANT_REQUIREMENT_FIELDS := [
	"participant_role",
	"authority_id",
	"reservation_kind",
]

var _state: Dictionary = {}
var _acquisition_authority_port: WeakRef = null
var _active_acquisition_transactions: Dictionary = {}


func _init(roster_ids: Array = [], seed: int = 1, config: Dictionary = {}) -> void:
	if not roster_ids.is_empty():
		start_match(roster_ids, seed, config)


func start_match(roster_ids: Array, seed: int, config: Dictionary = {}) -> Dictionary:
	if not _active_acquisition_transactions.is_empty():
		return _operation_result(false, "match_start_blocked_by_acquisition_transaction")
	var roster_error := _roster_error(roster_ids)
	if not roster_error.is_empty():
		return _operation_result(false, roster_error)
	if not (seed is int):
		return _operation_result(false, "seed_invalid")
	var config_error := _config_error(config)
	if not config_error.is_empty():
		return _operation_result(false, config_error)

	var normal_ratio := int(config.get(
		"normal_card_ratio_basis_points",
		DEFAULT_NORMAL_RATIO_BASIS_POINTS
	))
	var commodity_ratio := int(config.get(
		"commodity_card_ratio_basis_points",
		DEFAULT_COMMODITY_RATIO_BASIS_POINTS
	))
	var local_slots := int(config.get(
		"local_visible_slot_count",
		DEFAULT_LOCAL_VISIBLE_SLOT_COUNT
	))
	var match_instance_id_explicit := config.has("match_instance_id")
	var match_instance_id := str(config.get(
		"match_instance_id",
		"match.unspecified"
	))
	var normalized_seed := _normalize_seed(seed)
	var roster: Array = roster_ids.duplicate(true)

	var lead_stream := _new_rng_stream(normalized_seed, "initial_hidden_lead_order")
	var fixed_order := _shuffle_copy(roster, lead_stream)
	var type_supply := {
		"stream_id": "unified_track_type_draw",
		"ratio_basis_points": {
			"normal_card": normal_ratio,
			"commodity_card": commodity_ratio,
		},
		"bag": [],
		"cursor": 0,
		"bag_cycle": 0,
		"rng_state": _derive_seed(normalized_seed, "unified_track_type_draw"),
		"rng_draw_count": 0,
	}
	_refill_type_bag(type_supply)

	var color_supply := {
		"stream_id": "unified_track_color_draw",
		"bag": [],
		"cursor": 0,
		"bag_cycle": 0,
		"rng_state": _derive_seed(normalized_seed, "unified_track_color_draw"),
		"rng_draw_count": 0,
	}
	var uniform_weights := _uniform_color_weights()
	_refill_color_bag(color_supply, uniform_weights)

	var normal_supply := _new_definition_supply(
		"normal_card",
		normalized_seed,
		"unified_track_normal_card_draw"
	)
	var commodity_supply := _new_definition_supply(
		"commodity_card",
		normalized_seed,
		"unified_track_commodity_draw"
	)
	var projection_revisions: Dictionary = {}
	for actor_id in roster:
		projection_revisions[str(actor_id)] = 1

	_active_acquisition_transactions = {}
	_state = {
		"schema_version": SCHEMA_VERSION,
		"state_version": STATE_VERSION,
		"ruleset_id": RULESET_ID,
		"domain_id": DOMAIN_ID,
		"revision": 1,
		"match_seed": normalized_seed,
		"match_instance_id": match_instance_id,
		"match_instance_id_explicit": match_instance_id_explicit,
		"roster_ids": roster,
		"track_state": {
			"state_id": UNIFIED_TRACK_STATE_ID,
			"revision": 1,
			"capacity": roster.size() * local_slots,
			"local_visible_slot_count": local_slots,
			"next_instance_sequence": 0,
			"items": [],
		},
		"type_supply_state": type_supply,
		"normal_supply_state": normal_supply,
		"commodity_supply_state": commodity_supply,
		"color_cycle_state": {
			"state_id": COLOR_CYCLE_STATE_ID,
			"cycle_number": 1,
			"distribution_weight_units": uniform_weights,
			"distribution_basis_points": _weights_to_counts(
				uniform_weights,
				DISTRIBUTION_BASIS_POINTS
			),
			"pending_stances": {},
			"revealed_stances": [],
			"color_supply_state": color_supply,
		},
		"hidden_lead_cycle_state": {
			"state_id": HIDDEN_LEAD_STATE_ID,
			"stream_id": "initial_hidden_lead_order",
			"fixed_order": fixed_order,
			"macro_round_number": 1,
			"direction": "forward",
			"round_order": fixed_order.duplicate(true),
			"lead_cursor": 0,
			"current_lead_id": str(fixed_order[0]),
			"completed_lead_ids": [],
			"rng_state": int(lead_stream.get("rng_state", 1)),
			"rng_draw_count": int(lead_stream.get("rng_draw_count", 0)),
		},
		"projection_revisions": projection_revisions,
		"processed_requests": {},
		"revision_lineage": [],
	}
	_fill_initial_track()
	_append_revision_lineage_entry(
		"match.genesis",
		"match_started",
		fingerprint({
			"match_instance_id": match_instance_id,
			"match_seed": normalized_seed,
			"roster_ids": roster,
		})
	)
	var state_error := _state_error(_state)
	if not state_error.is_empty():
		_state = {}
		return _operation_result(false, "initial_state_invalid.%s" % state_error)
	return {
		"accepted": true,
		"reason_code": "match_started",
		"source_revision": 0,
		"result_revision": int(_state.get("revision", 0)),
		"core_fingerprint": fingerprint(_state),
	}


func initialize(roster_ids: Array, seed: int, config: Dictionary = {}) -> Dictionary:
	return start_match(roster_ids, seed, config)


func is_configured() -> bool:
	return not _state.is_empty() and _state_error(_state).is_empty()


func interface_contract_v1() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"domain_id": DOMAIN_ID,
		"ruleset_id": RULESET_ID,
		"state_type_ids": [
			UNIFIED_TRACK_STATE_ID,
			COLOR_CYCLE_STATE_ID,
			HIDDEN_LEAD_STATE_ID,
		],
		"interfaces": {
			"core": CORE_INTERFACE_ID,
			"ai_observation": AI_INTERFACE_ID,
			"player_projection": PLAYER_INTERFACE_ID,
			"intent": INTENT_INTERFACE_ID,
			"receipt": RECEIPT_INTERFACE_ID,
			"save_state": SAVE_INTERFACE_ID,
			"acquisition_proposal": ACQUISITION_PROPOSAL_INTERFACE_ID,
			"acquisition_authority_port": ACQUISITION_AUTHORITY_PORT_INTERFACE_ID,
			"privacy_policy": PRIVACY_POLICY_ID,
		},
		"same_core_source_required": true,
		"single_unified_track": true,
		"card_kind_ratio_independent_of_color_stances": true,
		"gdp_affects_track_color_distribution": false,
		"gdp_affects_track_card_type_distribution": false,
		"normal_player_influence_basis_points": NORMAL_INFLUENCE_BASIS_POINTS,
		"lead_player_influence_basis_points": LEAD_INFLUENCE_BASIS_POINTS,
		"acquisition_requires_trusted_authority_port": true,
		"caller_supplied_acquisition_receipts_trusted": false,
		"production_runtime_connected": false,
		"v07_production_cutover_complete": false,
	}


func privacy_policy_v1() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_id": PRIVACY_POLICY_ID,
		"domain_id": DOMAIN_ID,
		"public_facts": [
			"current_color_distribution",
			"revealed_stances_with_actor_identity",
			"track_and_cycle_revision",
			"card_kind_ratio",
		],
		"ai_private_facts": [
			"own_track_segment",
			"own_pending_stance",
		],
		"player_private_facts": [
			"own_track_segment",
			"own_pending_stance",
			"self_lead_notice_without_numeric_weight",
		],
		"authority_secret_facts": [
			"other_track_segments",
			"future_track_sequence",
			"future_supply_bags",
			"hidden_lead_identity_and_order",
			"effective_weights",
			"rng_state",
			"save_payload",
		],
		"ai_and_player_share_allowlisted_core_source": true,
		"projection_source_fingerprint_scope": "allowlisted_viewer_facts_only",
		"projection_source_fingerprint_commits_authority_secrets": false,
		"other_unrevealed_stance_changes_viewer_projection": false,
		"timing_animation_audio_identity_leak_allowed": false,
	}


func core_authority_v1() -> Dictionary:
	if not is_configured():
		return {}
	var result := {
		"schema_version": SCHEMA_VERSION,
		"interface_id": CORE_INTERFACE_ID,
		"domain_id": DOMAIN_ID,
		"authority_scope": "authority_secret",
		"source_revision": int(_state.get("revision", 0)),
		"authority_state": _state.duplicate(true),
		"core_fingerprint": fingerprint(_state),
	}
	return result.duplicate(true)


func core_snapshot() -> Dictionary:
	return core_authority_v1()


func core_authority_snapshot() -> Dictionary:
	return core_authority_v1()


func ai_observation_v1(viewer_actor_id: String) -> Dictionary:
	return _viewer_projection(AI_INTERFACE_ID, viewer_actor_id)


func ai_observation(viewer_actor_id: String) -> Dictionary:
	return ai_observation_v1(viewer_actor_id)


func player_projection_v1(viewer_actor_id: String) -> Dictionary:
	return _viewer_projection(PLAYER_INTERFACE_ID, viewer_actor_id)


func player_projection(viewer_actor_id: String) -> Dictionary:
	return player_projection_v1(viewer_actor_id)


func visible_source_identity_v1(
	viewer_actor_id: String,
	source_instance_id: String
) -> Dictionary:
	if not is_configured() \
		or not (_state.get("roster_ids", []) as Array).has(viewer_actor_id):
		return {}
	var track := _state.get("track_state", {}) as Dictionary
	for item_variant in track.get("items", []) as Array:
		var item := item_variant as Dictionary
		if str(item.get("instance_id", "")) != source_instance_id \
			or str(item.get("segment_owner_id", "")) != viewer_actor_id:
			continue
		var unsealed := {
			"schema_version": SCHEMA_VERSION,
			"source_identity_id": "track.source.%s.r%d" % [
				source_instance_id,
				int(track.get("revision", 0)),
			],
			"source_instance_id": source_instance_id,
			"source_definition_id": str(item.get("card_definition_id", "")),
			"source_kind": str(item.get("card_kind", "")),
			"source_track_revision": int(track.get("revision", 0)),
			"segment_owner_id": viewer_actor_id,
		}
		return sealed_copy(unsealed, "identity_fingerprint")
	return {}


static func seal_viewer_segment_authorization_v1(unsealed: Dictionary) -> Dictionary:
	if not is_pure_data(unsealed) \
		or not _exact_fields(unsealed, VIEWER_AUTHORIZATION_UNSEALED_FIELDS):
		return {}
	var sealed := sealed_copy(unsealed, "authorization_fingerprint")
	return sealed if _viewer_authorization_error(sealed).is_empty() else {}


func build_visible_acquisition_intent_v1(
	request_id: String,
	actor_id: String,
	action_id: String,
	source_identity: Dictionary,
	viewer_segment_authorization: Dictionary,
	source_revision: int = -1
) -> Dictionary:
	if action_id not in ACQUISITION_ACTION_IDS:
		return {}
	return build_intent_v1(
		request_id,
		actor_id,
		action_id,
		{
			"source_identity": source_identity.duplicate(true),
			"viewer_segment_authorization": (
				viewer_segment_authorization.duplicate(true)
			),
		},
		source_revision
	)


func build_intent_v1(
	request_id: String,
	actor_id: String,
	action_id: String,
	parameters: Dictionary,
	source_revision: int = -1
) -> Dictionary:
	if not is_configured():
		return {}
	var revision := _intent_source_revision(actor_id) \
		if source_revision < 0 else source_revision
	var source_identity: Dictionary = {}
	var viewer_segment_authorization: Dictionary = {}
	var action_parameters := parameters.duplicate(true)
	if action_id in ACQUISITION_ACTION_IDS:
		if parameters.get("source_identity") is Dictionary:
			source_identity = (
				parameters.get("source_identity", {}) as Dictionary
			).duplicate(true)
		if parameters.get("viewer_segment_authorization") is Dictionary:
			viewer_segment_authorization = (
				parameters.get("viewer_segment_authorization", {}) as Dictionary
			).duplicate(true)
		action_parameters = {}
	var unsealed := {
		"schema_version": SCHEMA_VERSION,
		"interface_id": INTENT_INTERFACE_ID,
		"domain_id": DOMAIN_ID,
		"request_id": request_id,
		"intent_id": request_id,
		"actor_id": actor_id,
		"action_id": action_id,
		"source_revision": revision,
		"expected_core_revision": revision,
		"source_core_fingerprint": _intent_source_fingerprint(actor_id),
		"source_identity": source_identity,
		"viewer_segment_authorization": viewer_segment_authorization,
		"parameters": action_parameters,
	}
	var intent := sealed_copy(unsealed, "intent_fingerprint")
	return intent if _intent_error(intent).is_empty() else {}


func build_intent(
	request_id: String,
	actor_id: String,
	action_id: String,
	parameters: Dictionary,
	source_revision: int = -1
) -> Dictionary:
	return build_intent_v1(
		request_id,
		actor_id,
		action_id,
		parameters,
		source_revision
	)


func bind_acquisition_authority_port_v1(authority_port: RefCounted) -> Dictionary:
	if authority_port == null:
		return _operation_result(false, "acquisition_authority_port_missing")
	var authority_port_script: Script = authority_port.get_script() as Script
	if authority_port_script == null \
		or authority_port_script.resource_path != ACQUISITION_AUTHORITY_PORT_SCRIPT_PATH:
		return _operation_result(false, "acquisition_authority_port_script_not_trusted")
	for method_name in [
		"acquisition_port_contract_v1",
		"track_authority_v1",
		"_track_commit_context_v1",
	]:
		if not authority_port.has_method(method_name):
			return _operation_result(false, "acquisition_authority_port_contract_invalid")
	if _acquisition_authority_port != null \
		and _acquisition_authority_port.get_ref() != authority_port:
		return _operation_result(false, "acquisition_authority_port_already_bound")
	var contract_variant: Variant = authority_port.call("acquisition_port_contract_v1")
	if not (contract_variant is Dictionary):
		return _operation_result(false, "acquisition_authority_port_contract_invalid")
	var contract := contract_variant as Dictionary
	if str(contract.get("interface_id", "")) \
			!= ACQUISITION_AUTHORITY_PORT_INTERFACE_ID \
		or str(contract.get("domain_id", "")) != DOMAIN_ID \
		or contract.get("production_runtime_connected") != false \
		or authority_port.call("track_authority_v1") != self:
		return _operation_result(false, "acquisition_authority_port_contract_invalid")
	_acquisition_authority_port = weakref(authority_port)
	return _operation_result(true, "acquisition_authority_port_bound")


func prepare_visible_acquisition_v1(intent: Dictionary) -> Dictionary:
	var before_fingerprint := fingerprint(_state) if is_configured() else ""
	if not is_configured():
		return _acquisition_prepare_result(false, "core_not_configured")
	var intent_error := _intent_error(intent)
	if not intent_error.is_empty():
		return _acquisition_prepare_result(false, intent_error)
	var action_id := str(intent.get("action_id", ""))
	if action_id not in ACQUISITION_ACTION_IDS:
		return _acquisition_prepare_result(false, "acquisition_action_required")
	var request_id := str(intent.get("request_id", ""))
	var processed := _state.get("processed_requests", {}) as Dictionary
	if processed.has(request_id):
		var prior := processed.get(request_id, {}) as Dictionary
		var reason := "request_already_committed" \
			if str(prior.get("intent_fingerprint", "")) \
				== str(intent.get("intent_fingerprint", "")) \
			else "request_id_collision"
		return _acquisition_prepare_result(false, reason)
	var actor_id := str(intent.get("actor_id", ""))
	if int(intent.get("source_revision", -1)) != _intent_source_revision(actor_id) \
		or str(intent.get("source_core_fingerprint", "")) \
			!= _intent_source_fingerprint(actor_id):
		return _acquisition_prepare_result(false, "source_state_stale")
	var acquisition_error := _acquisition_live_error(intent)
	if not acquisition_error.is_empty():
		return _acquisition_prepare_result(false, acquisition_error)

	var authorization := (
		intent.get("viewer_segment_authorization", {}) as Dictionary
	)
	var destination_zone := "commodity_inventory" \
		if action_id == ACTION_CLAIM_VISIBLE_COMMODITY else "personal_discard"
	var participant_requirements: Array = []
	if action_id == ACTION_PURCHASE_VISIBLE_NORMAL_CARD:
		participant_requirements.append({
			"participant_role": "cash",
			"authority_id": str(authorization.get("cash_authority_id", "")),
			"reservation_kind": "cash",
		})
		participant_requirements.append({
			"participant_role": "personal_discard",
			"authority_id": str(authorization.get("inventory_authority_id", "")),
			"reservation_kind": "destination_capacity",
		})
	else:
		participant_requirements.append({
			"participant_role": "commodity_slot",
			"authority_id": str(authorization.get("inventory_authority_id", "")),
			"reservation_kind": "destination_capacity",
		})
	var track := _state.get("track_state", {}) as Dictionary
	var proposal := sealed_copy({
		"schema_version": SCHEMA_VERSION,
		"interface_id": ACQUISITION_PROPOSAL_INTERFACE_ID,
		"domain_id": DOMAIN_ID,
		"request_id": request_id,
		"intent_id": str(intent.get("intent_id", "")),
		"intent_fingerprint": str(intent.get("intent_fingerprint", "")),
		"actor_id": actor_id,
		"action_id": action_id,
		"source_revision": int(intent.get("source_revision", 0)),
		"source_core_revision": int(_state.get("revision", 0)),
		"source_track_revision": int(track.get("revision", 0)),
		"source_identity": (
			intent.get("source_identity", {}) as Dictionary
		).duplicate(true),
		"destination_zone": destination_zone,
		"participant_requirements": participant_requirements,
		"cash_reservation_required": (
			action_id == ACTION_PURCHASE_VISIBLE_NORMAL_CARD
		),
		"asset_reservation_required": false,
	}, "proposal_fingerprint")
	if not _acquisition_proposal_error(proposal).is_empty():
		return _acquisition_prepare_result(false, "acquisition_proposal_invalid")
	if fingerprint(_state) != before_fingerprint:
		return _acquisition_prepare_result(false, "prepare_mutated_track_authority")
	return {
		"accepted": true,
		"prepared": true,
		"reason_code": "acquisition_prepared",
		"proposal": proposal,
	}


func register_prepared_acquisition_transaction_v1(
	transaction_id: String,
	authority_port: RefCounted
) -> Dictionary:
	if authority_port == null \
		or _acquisition_authority_port == null \
		or authority_port != _acquisition_authority_port.get_ref():
		return _transaction_operation_result(
			false,
			"acquisition_authority_port_not_trusted",
			transaction_id
		)
	if not _is_stable_id(transaction_id):
		return _transaction_operation_result(
			false,
			"acquisition_transaction_id_invalid",
			transaction_id
		)
	if _active_acquisition_transactions.has(transaction_id):
		var existing := _active_acquisition_transactions.get(
			transaction_id, {}
		) as Dictionary
		return _transaction_operation_result(
			str(existing.get("status", "")) == "prepared",
			"acquisition_transaction_already_registered",
			transaction_id
		)
	var context_variant: Variant = authority_port.call(
		"_track_commit_context_v1",
		transaction_id,
		self
	)
	if not (context_variant is Dictionary):
		return _transaction_operation_result(
			false,
			"acquisition_transaction_not_prepared",
			transaction_id
		)
	var context := context_variant as Dictionary
	var intent_variant: Variant = context.get("intent")
	var proposal_variant: Variant = context.get("proposal")
	if not (intent_variant is Dictionary) \
		or not (proposal_variant is Dictionary) \
		or context.get("all_required_participants_prepared") != true:
		return _transaction_operation_result(
			false,
			"acquisition_transaction_not_prepared",
			transaction_id
		)
	var prepared_again := prepare_visible_acquisition_v1(intent_variant as Dictionary)
	if not bool(prepared_again.get("accepted", false)) \
		or prepared_again.get("proposal", {}) != proposal_variant:
		return _transaction_operation_result(
			false,
			str(prepared_again.get("reason_code", "acquisition_proposal_mismatch")),
			transaction_id
		)
	_active_acquisition_transactions[transaction_id] = {
		"status": "prepared",
		"request_id": str((intent_variant as Dictionary).get("request_id", "")),
		"intent_fingerprint": str(
			(intent_variant as Dictionary).get("intent_fingerprint", "")
		),
		"authority_state": {},
		"post_commit_fingerprint": "",
		"track_receipt_fingerprint": "",
	}
	return _transaction_operation_result(
		true,
		"acquisition_transaction_registered",
		transaction_id
	)


func abort_prepared_acquisition_transaction_v1(
	transaction_id: String,
	authority_port: RefCounted
) -> Dictionary:
	var transaction_error := _acquisition_transaction_access_error(
		transaction_id,
		authority_port
	)
	if not transaction_error.is_empty():
		return _transaction_operation_result(false, transaction_error, transaction_id)
	var transaction := _active_acquisition_transactions.get(
		transaction_id, {}
	) as Dictionary
	if str(transaction.get("status", "")) != "prepared":
		return _transaction_operation_result(
			false,
			"acquisition_transaction_not_prepared",
			transaction_id
		)
	_active_acquisition_transactions.erase(transaction_id)
	return _transaction_operation_result(
		true,
		"acquisition_prepared_transaction_aborted",
		transaction_id
	)


func acquisition_transaction_status_v1() -> Dictionary:
	var rows: Array = []
	for transaction_id_variant in _active_acquisition_transactions.keys():
		var transaction_id := str(transaction_id_variant)
		var transaction := _active_acquisition_transactions.get(
			transaction_id, {}
		) as Dictionary
		rows.append({
			"transaction_id": transaction_id,
			"request_id": str(transaction.get("request_id", "")),
			"status": str(transaction.get("status", "")),
		})
	return {
		"quiescent": rows.is_empty(),
		"active_transaction_count": rows.size(),
		"transaction_rows": rows,
	}


func commit_prepared_acquisition_v1(
	transaction_id: String,
	authority_port: RefCounted
) -> Dictionary:
	if authority_port == null \
		or _acquisition_authority_port == null \
		or authority_port != _acquisition_authority_port.get_ref():
		return _failure_receipt({}, "acquisition_authority_port_not_trusted")
	if not _is_stable_id(transaction_id):
		return _failure_receipt({}, "acquisition_transaction_id_invalid")
	var context_variant: Variant = authority_port.call(
		"_track_commit_context_v1",
		transaction_id,
		self
	)
	if not (context_variant is Dictionary):
		return _failure_receipt({}, "acquisition_transaction_not_prepared")
	var context := context_variant as Dictionary
	var intent_variant: Variant = context.get("intent")
	var proposal_variant: Variant = context.get("proposal")
	if not (intent_variant is Dictionary) \
		or not (proposal_variant is Dictionary) \
		or context.get("all_required_participants_prepared") != true \
		or not (context.get("prepared_participant_roles") is Array):
		return _failure_receipt({}, "acquisition_transaction_not_prepared")
	var intent := intent_variant as Dictionary
	var proposal := proposal_variant as Dictionary
	var prepared_again := prepare_visible_acquisition_v1(intent)
	if not bool(prepared_again.get("accepted", false)):
		return _failure_receipt(intent, str(prepared_again.get(
			"reason_code", "acquisition_revalidation_failed"
		)))
	var authoritative_proposal := prepared_again.get("proposal", {}) as Dictionary
	if proposal != authoritative_proposal:
		return _failure_receipt(intent, "acquisition_proposal_mismatch")
	var required_roles: Array = []
	for row_variant in proposal.get("participant_requirements", []) as Array:
		required_roles.append(str((row_variant as Dictionary).get(
			"participant_role", ""
		)))
	if not _same_string_set(
		required_roles,
		context.get("prepared_participant_roles", []) as Array
	):
		return _failure_receipt(intent, "acquisition_participants_incomplete")
	var before := _state.duplicate(true)
	if not _active_acquisition_transactions.has(transaction_id):
		return _failure_receipt(intent, "acquisition_transaction_not_registered")
	var transaction := _active_acquisition_transactions.get(
		transaction_id, {}
	) as Dictionary
	if str(transaction.get("status", "")) != "prepared" \
		or str(transaction.get("request_id", "")) \
			!= str(intent.get("request_id", "")) \
		or str(transaction.get("intent_fingerprint", "")) \
			!= str(intent.get("intent_fingerprint", "")):
		return _failure_receipt(intent, "acquisition_transaction_registration_mismatch")
	transaction["authority_state"] = before
	transaction["status"] = "track_committing"
	_active_acquisition_transactions[transaction_id] = transaction
	var receipt := _apply_validated_intent(intent)
	if not bool(receipt.get("accepted", false)):
		transaction["status"] = "prepared"
		transaction["authority_state"] = {}
		_active_acquisition_transactions[transaction_id] = transaction
		return receipt
	transaction = _active_acquisition_transactions.get(transaction_id, {}) as Dictionary
	transaction["status"] = "track_committed"
	transaction["post_commit_fingerprint"] = fingerprint(_state)
	transaction["track_receipt_fingerprint"] = str(
		receipt.get("receipt_fingerprint", "")
	)
	_active_acquisition_transactions[transaction_id] = transaction
	return receipt


func finalize_acquisition_transaction_v1(
	transaction_id: String,
	authority_port: RefCounted
) -> Dictionary:
	var transaction_error := _acquisition_transaction_access_error(
		transaction_id,
		authority_port
	)
	if not transaction_error.is_empty():
		return _transaction_operation_result(false, transaction_error, transaction_id)
	var transaction := _active_acquisition_transactions.get(
		transaction_id, {}
	) as Dictionary
	if str(transaction.get("status", "")) != "track_committed":
		return _transaction_operation_result(
			false,
			"acquisition_transaction_not_track_committed",
			transaction_id
		)
	if str(transaction.get("post_commit_fingerprint", "")) != fingerprint(_state):
		return _transaction_operation_result(
			false,
			"acquisition_transaction_lineage_diverged",
			transaction_id
		)
	_active_acquisition_transactions.erase(transaction_id)
	return _transaction_operation_result(
		true,
		"acquisition_transaction_finalized",
		transaction_id
	)


func rollback_acquisition_transaction_v1(
	transaction_id: String,
	authority_port: RefCounted
) -> Dictionary:
	var transaction_error := _acquisition_transaction_access_error(
		transaction_id,
		authority_port
	)
	if not transaction_error.is_empty():
		return _transaction_operation_result(false, transaction_error, transaction_id)
	var transaction := _active_acquisition_transactions.get(
		transaction_id, {}
	) as Dictionary
	if str(transaction.get("status", "")) != "track_committed":
		return _transaction_operation_result(
			false,
			"acquisition_transaction_not_track_committed",
			transaction_id
		)
	if str(transaction.get("post_commit_fingerprint", "")) != fingerprint(_state):
		return _transaction_operation_result(
			false,
			"acquisition_transaction_lineage_diverged",
			transaction_id
		)
	var restored_variant: Variant = transaction.get("authority_state")
	if not (restored_variant is Dictionary) \
		or not _state_error(restored_variant as Dictionary).is_empty():
		return _transaction_operation_result(
			false,
			"acquisition_transaction_checkpoint_invalid",
			transaction_id
		)
	_state = (restored_variant as Dictionary).duplicate(true)
	_active_acquisition_transactions.erase(transaction_id)
	return _transaction_operation_result(
		true,
		"acquisition_transaction_rolled_back",
		transaction_id
	)


func apply_intent_v1(intent: Dictionary) -> Dictionary:
	if not is_configured():
		return _failure_receipt(intent, "core_not_configured")
	var intent_error := _intent_error(intent)
	if not intent_error.is_empty():
		return _failure_receipt(intent, intent_error)

	var request_id := str(intent.get("request_id", ""))
	var intent_fingerprint := str(intent.get("intent_fingerprint", ""))
	var processed := _state.get("processed_requests", {}) as Dictionary
	if processed.has(request_id):
		var prior := processed.get(request_id, {}) as Dictionary
		if str(prior.get("intent_fingerprint", "")) == intent_fingerprint:
			return _receipt_from_record(request_id, prior)
		return _failure_receipt(intent, "request_id_collision")

	if int(intent.get("source_revision", -1)) \
		!= _intent_source_revision(str(intent.get("actor_id", ""))) \
		or str(intent.get("source_core_fingerprint", "")) \
			!= _intent_source_fingerprint(str(intent.get("actor_id", ""))):
		return _failure_receipt(intent, "source_state_stale")
	var action_id := str(intent.get("action_id", ""))
	if action_id in ACQUISITION_ACTION_IDS:
		var acquisition_error := _acquisition_live_error(intent)
		if not acquisition_error.is_empty():
			return _failure_receipt(intent, acquisition_error)
		return _failure_receipt(intent, "acquisition_authority_port_required")
	return _apply_validated_intent(intent)


func _apply_validated_intent(intent: Dictionary) -> Dictionary:
	var request_id := str(intent.get("request_id", ""))
	var intent_fingerprint := str(intent.get("intent_fingerprint", ""))
	var processed := _state.get("processed_requests", {}) as Dictionary
	var action_id := str(intent.get("action_id", ""))

	var before := _state.duplicate(true)
	var actor_id := str(intent.get("actor_id", ""))
	var parameters := intent.get("parameters", {}) as Dictionary
	var public_facts: Dictionary = {}
	match action_id:
		ACTION_SET_STANCE:
			var color_cycle := _state.get("color_cycle_state", {}) as Dictionary
			var pending := color_cycle.get("pending_stances", {}) as Dictionary
			pending[actor_id] = {
				"increase_color": str(parameters.get("increase_color", "")),
				"decrease_color": str(parameters.get("decrease_color", "")),
			}
			color_cycle["pending_stances"] = pending
			public_facts = {"stance_recorded": true}
			_bump_projection_revisions([actor_id])
		ACTION_COMMIT_COLOR_CYCLE:
			public_facts = _commit_color_cycle_boundary()
			_bump_projection_revisions(_state.get("roster_ids", []) as Array)
		ACTION_ADVANCE_TRACK:
			var steps := int(parameters.get("steps", 0))
			_advance_track(steps)
			public_facts = {
				"advanced_steps": steps,
				"track_revision": int(
					(_state.get("track_state", {}) as Dictionary).get("revision", 0)
				),
			}
			_bump_projection_revisions(_state.get("roster_ids", []) as Array)
		ACTION_CLAIM_VISIBLE_COMMODITY, ACTION_PURCHASE_VISIBLE_NORMAL_CARD:
			var source_identity := intent.get("source_identity", {}) as Dictionary
			public_facts = _commit_visible_acquisition(
				str(source_identity.get("source_instance_id", ""))
			)
			if public_facts.is_empty():
				_state = before
				return _failure_receipt(intent, "acquisition_commit_failed")
			_bump_projection_revisions(_state.get("roster_ids", []) as Array)
		_:
			_state = before
			return _failure_receipt(intent, "action_id_invalid")

	var authority_source_revision := int(before.get("revision", 0))
	var source_revision := int(intent.get("source_revision", 0))
	_state["revision"] = authority_source_revision + 1
	var result_revision := _intent_source_revision(actor_id)
	var authorization := (
		intent.get("viewer_segment_authorization", {}) as Dictionary
	)
	var receipt_metadata := _receipt_metadata_for_action(action_id, authorization)
	var consumed_capability_id := "authority.none"
	var consumed_authorization_id := "authority.none"
	if action_id in ACQUISITION_ACTION_IDS:
		consumed_capability_id = str(authorization.get("capability_id", ""))
		consumed_authorization_id = str(authorization.get("authorization_id", ""))
	var record := {
		"intent_fingerprint": intent_fingerprint,
		"action_id": action_id,
		"accepted": true,
		"reason_code": "accepted",
		"source_revision": source_revision,
		"result_revision": result_revision,
		"receipt_id": _receipt_id_for_request(request_id),
		"intent_id": str(intent.get("intent_id", "")),
		"committed_core_revision": int(_state.get("revision", 0)),
		"destination_zone": str(receipt_metadata.get("destination_zone", "none")),
		"cash_delta": (
			receipt_metadata.get("cash_delta", {}) as Dictionary
		).duplicate(true),
		"inventory_commit": (
			receipt_metadata.get("inventory_commit", {}) as Dictionary
		).duplicate(true),
		"external_authority_commit_required": bool(
			receipt_metadata.get("external_authority_commit_required", false)
		),
		"consumed_capability_id": consumed_capability_id,
		"consumed_authorization_id": consumed_authorization_id,
		"public_facts": public_facts.duplicate(true),
	}
	processed = _state.get("processed_requests", {}) as Dictionary
	processed[request_id] = record
	_state["processed_requests"] = processed
	_append_revision_lineage_entry(request_id, action_id, intent_fingerprint)
	var state_error := _state_error(_state)
	if not state_error.is_empty():
		_state = before
		return _failure_receipt(intent, "postcondition_failed.%s" % state_error)
	return _receipt_from_record(request_id, record)


func apply_intent(intent: Dictionary) -> Dictionary:
	return apply_intent_v1(intent)


func _append_revision_lineage_entry(
	request_id: String,
	action_id: String,
	intent_fingerprint: String
) -> void:
	var history := _state.get("revision_lineage", []) as Array
	var parent_hash := ROOT_LINEAGE_PARENT_HASH
	if not history.is_empty():
		parent_hash = str((history[-1] as Dictionary).get("lineage_hash", ""))
	var entry := sealed_copy({
		"revision": int(_state.get("revision", 0)),
		"request_id": request_id,
		"action_id": action_id,
		"intent_fingerprint": intent_fingerprint,
		"parent_lineage_hash": parent_hash,
		"state_payload_fingerprint": _state_lineage_payload_fingerprint(_state),
	}, "lineage_hash")
	history.append(entry)
	_state["revision_lineage"] = history


static func _state_lineage_payload_fingerprint(value: Dictionary) -> String:
	var payload := value.duplicate(true)
	payload["revision_lineage"] = []
	return fingerprint(payload)


func authoritative_receipt_v1(request_id: String) -> Dictionary:
	if not is_configured():
		return {}
	var processed := _state.get("processed_requests", {}) as Dictionary
	if not processed.has(request_id):
		return {}
	return _receipt_from_record(
		request_id,
		processed.get(request_id, {}) as Dictionary
	)


func authoritative_receipt(request_id: String) -> Dictionary:
	return authoritative_receipt_v1(request_id)


func save_state_v1() -> Dictionary:
	if not is_configured() or not _active_acquisition_transactions.is_empty():
		return {}
	var unsealed := {
		"schema_version": SCHEMA_VERSION,
		"interface_id": SAVE_INTERFACE_ID,
		"ruleset_id": RULESET_ID,
		"domain_id": DOMAIN_ID,
		"state_version": STATE_VERSION,
		"source_revision": int(_state.get("revision", 0)),
		"source_core_fingerprint": fingerprint(_state),
		"authority_state": _state.duplicate(true),
	}
	return sealed_copy(unsealed, "save_fingerprint")


func save_state() -> Dictionary:
	return save_state_v1()


func restore_save_state_v1(save_value: Dictionary) -> Dictionary:
	if not _active_acquisition_transactions.is_empty():
		return _operation_result(
			false,
			"save_restore_blocked_by_acquisition_transaction"
		)
	var save_error := _save_state_error(save_value)
	if not save_error.is_empty():
		return _operation_result(false, save_error)
	var candidate := (save_value.get("authority_state", {}) as Dictionary).duplicate(true)
	var candidate_error := _state_error(candidate)
	if not candidate_error.is_empty():
		return _operation_result(false, "authority_state_invalid.%s" % candidate_error)
	_state = candidate
	_active_acquisition_transactions = {}
	return {
		"accepted": true,
		"reason_code": "save_state_restored",
		"source_revision": int(save_value.get("source_revision", 0)),
		"result_revision": int(_state.get("revision", 0)),
		"core_fingerprint": fingerprint(_state),
	}


func restore_save_state(save_value: Dictionary) -> Dictionary:
	return restore_save_state_v1(save_value)


func capture_checkpoint_v1() -> Dictionary:
	if not is_configured() \
		or not bool(_state.get("match_instance_id_explicit", false)) \
		or not _active_acquisition_transactions.is_empty():
		return {}
	var unsealed := {
		"schema_version": SCHEMA_VERSION,
		"interface_id": CHECKPOINT_INTERFACE_ID,
		"domain_id": DOMAIN_ID,
		"match_instance_id": str(_state.get("match_instance_id", "")),
		"source_revision": int(_state.get("revision", 0)),
		"source_core_fingerprint": fingerprint(_state),
		"authority_state": _state.duplicate(true),
	}
	return sealed_copy(unsealed, "checkpoint_fingerprint")


func checkpoint() -> Dictionary:
	return capture_checkpoint_v1()


func capture_checkpoint() -> Dictionary:
	return capture_checkpoint_v1()


func rollback_v1(checkpoint_value: Dictionary) -> Dictionary:
	if not is_configured():
		return _operation_result(false, "checkpoint_core_not_configured")
	var checkpoint_error := _checkpoint_error(checkpoint_value)
	if not checkpoint_error.is_empty():
		return _operation_result(false, checkpoint_error)
	var candidate := (
		checkpoint_value.get("authority_state", {}) as Dictionary
	).duplicate(true)
	var candidate_error := _state_error(candidate)
	if not candidate_error.is_empty():
		return _operation_result(false, "checkpoint_state_invalid.%s" % candidate_error)
	if not bool(_state.get("match_instance_id_explicit", false)) \
		or not bool(candidate.get("match_instance_id_explicit", false)) \
		or str(checkpoint_value.get("match_instance_id", "")) \
			!= str(_state.get("match_instance_id", "")) \
		or str(candidate.get("match_instance_id", "")) \
			!= str(_state.get("match_instance_id", "")) \
		or int(candidate.get("match_seed", 0)) != int(_state.get("match_seed", -1)) \
		or candidate.get("roster_ids", []) != _state.get("roster_ids", []):
		return _operation_result(false, "checkpoint_lineage_mismatch")
	if not _active_acquisition_transactions.is_empty():
		return _operation_result(false, "checkpoint_acquisition_transaction_active")
	var ancestry_error := _checkpoint_ancestry_error(candidate)
	if not ancestry_error.is_empty():
		return _operation_result(false, ancestry_error)
	_state = candidate
	return {
		"accepted": true,
		"reason_code": "checkpoint_restored",
		"source_revision": int(checkpoint_value.get("source_revision", 0)),
		"result_revision": int(_state.get("revision", 0)),
		"core_fingerprint": fingerprint(_state),
	}


func rollback(checkpoint_value: Dictionary) -> Dictionary:
	return rollback_v1(checkpoint_value)


func rollback_to_checkpoint(checkpoint_value: Dictionary) -> Dictionary:
	return rollback_v1(checkpoint_value)


func _checkpoint_ancestry_error(candidate: Dictionary) -> String:
	var candidate_revision := int(candidate.get("revision", -1))
	var current_revision := int(_state.get("revision", -1))
	if candidate_revision > current_revision:
		return "checkpoint_from_future"
	var candidate_lineage := candidate.get("revision_lineage", []) as Array
	var current_lineage := _state.get("revision_lineage", []) as Array
	if candidate_lineage.size() > current_lineage.size():
		return "checkpoint_from_future"
	for index in range(candidate_lineage.size()):
		if candidate_lineage[index] != current_lineage[index]:
			return "checkpoint_full_state_lineage_mismatch"
	var candidate_processed := candidate.get("processed_requests", {}) as Dictionary
	var current_processed := _state.get("processed_requests", {}) as Dictionary
	var candidate_keys := candidate_processed.keys()
	var current_keys := current_processed.keys()
	if candidate_keys.size() > current_keys.size():
		return "checkpoint_from_future"
	for index in range(candidate_keys.size()):
		var candidate_request_id := str(candidate_keys[index])
		if candidate_request_id != str(current_keys[index]) \
			or candidate_processed.get(candidate_request_id) \
				!= current_processed.get(candidate_request_id):
			return "checkpoint_not_current_lineage"
	if current_revision - candidate_revision \
			!= current_keys.size() - candidate_keys.size():
		return "checkpoint_revision_ancestry_mismatch"
	if candidate_revision == current_revision \
		and fingerprint(candidate) != fingerprint(_state):
		return "checkpoint_not_current_lineage"
	for index in range(candidate_keys.size(), current_keys.size()):
		var record := current_processed.get(current_keys[index], {}) as Dictionary
		if str(record.get("action_id", "")) in ACQUISITION_ACTION_IDS:
			return "checkpoint_requires_transaction_owned_acquisition_rollback"
	return ""


func validation_report_v1() -> Dictionary:
	var reason := _state_error(_state)
	return {
		"valid": reason.is_empty(),
		"reason_code": "none" if reason.is_empty() else reason,
	}


func _viewer_projection(interface_id: String, viewer_actor_id: String) -> Dictionary:
	if not is_configured() \
		or not (_state.get("roster_ids", []) as Array).has(viewer_actor_id):
		return {}
	var track := _state.get("track_state", {}) as Dictionary
	var own_items: Array = []
	for item_variant in track.get("items", []) as Array:
		var item := item_variant as Dictionary
		if str(item.get("segment_owner_id", "")) != viewer_actor_id:
			continue
		own_items.append({
			"instance_id": str(item.get("instance_id", "")),
			"card_definition_id": str(item.get("card_definition_id", "")),
			"card_kind": str(item.get("card_kind", "")),
			"primary_color": str(item.get("primary_color", "")),
			"local_slot_index": int(item.get("path_position", 0)) \
				% int(track.get("local_visible_slot_count", 1)),
			"track_revision": int(track.get("revision", 0)),
		})
	var color_cycle := _state.get("color_cycle_state", {}) as Dictionary
	var pending := color_cycle.get("pending_stances", {}) as Dictionary
	var own_pending: Dictionary = {}
	if pending.has(viewer_actor_id):
		own_pending = (pending.get(viewer_actor_id, {}) as Dictionary).duplicate(true)
	var lead := _state.get("hidden_lead_cycle_state", {}) as Dictionary
	var public_facts := {
		"single_unified_track": true,
		"allowed_card_kinds": CARD_KIND_IDS.duplicate(),
		"track_revision": int(track.get("revision", 0)),
		"unified_track_item_count": (track.get("items", []) as Array).size(),
		"card_kind_ratio_basis_points": (
			(_state.get("type_supply_state", {}) as Dictionary)
				.get("ratio_basis_points", {}) as Dictionary
		).duplicate(true),
		"color_cycle_number": int(color_cycle.get("cycle_number", 0)),
		"color_distribution_basis_points": (
			color_cycle.get("distribution_basis_points", {}) as Dictionary
		).duplicate(true),
		"revealed_stances": (
			color_cycle.get("revealed_stances", []) as Array
		).duplicate(true),
	}
	var viewer_private_facts := {
		"own_segment_items": own_items,
		"own_pending_stance": own_pending,
	}
	if interface_id == PLAYER_INTERFACE_ID:
		viewer_private_facts["self_lead_notice"] = (
			str(lead.get("current_lead_id", "")) == viewer_actor_id
		)
		viewer_private_facts["self_lead_notice_token"] = (
			"v07.lead.double_influence"
			if str(lead.get("current_lead_id", "")) == viewer_actor_id
			else "none"
		)
	var source_revision := int(
		(_state.get("projection_revisions", {}) as Dictionary)
			.get(viewer_actor_id, 0)
	)
	var source_projection_fingerprint := fingerprint({
		"schema_version": SCHEMA_VERSION,
		"domain_id": DOMAIN_ID,
		"source_revision": source_revision,
		"viewer_actor_id": viewer_actor_id,
		"public_facts": public_facts,
		"viewer_private_facts": viewer_private_facts,
	})
	var result := {
		"schema_version": SCHEMA_VERSION,
		"interface_id": interface_id,
		"domain_id": DOMAIN_ID,
		"source_revision": source_revision,
		"source_core_fingerprint": source_projection_fingerprint,
		"viewer_actor_id": viewer_actor_id,
		"public_facts": public_facts,
		"viewer_private_facts": viewer_private_facts,
	}
	return sealed_copy(result, "projection_fingerprint")


func _intent_source_fingerprint(actor_id: String) -> String:
	if actor_id == "system":
		return fingerprint(_state)
	var projection := _viewer_projection(AI_INTERFACE_ID, actor_id)
	return str(projection.get("source_core_fingerprint", ""))


func _intent_source_revision(actor_id: String) -> int:
	if actor_id == "system":
		return int(_state.get("revision", 0))
	return int(
		(_state.get("projection_revisions", {}) as Dictionary).get(actor_id, 0)
	)


func _bump_projection_revisions(actor_ids: Array) -> void:
	var revisions := _state.get("projection_revisions", {}) as Dictionary
	for actor_variant in actor_ids:
		var actor_id := str(actor_variant)
		if not revisions.has(actor_id):
			continue
		revisions[actor_id] = int(revisions.get(actor_id, 0)) + 1
	_state["projection_revisions"] = revisions


func _commit_color_cycle_boundary() -> Dictionary:
	var color_cycle := _state.get("color_cycle_state", {}) as Dictionary
	var pending := color_cycle.get("pending_stances", {}) as Dictionary
	var lead := _state.get("hidden_lead_cycle_state", {}) as Dictionary
	var frozen_lead_id := str(lead.get("current_lead_id", ""))
	var weights := _uniform_color_weights()
	var revealed: Array = []
	var public_actor_order: Array = (_state.get("roster_ids", []) as Array).duplicate()
	public_actor_order.sort()
	for actor_variant in public_actor_order:
		var actor_id := str(actor_variant)
		if not pending.has(actor_id):
			continue
		var stance := pending.get(actor_id, {}) as Dictionary
		if not _stance_error(stance).is_empty():
			continue
		var influence := LEAD_INFLUENCE_WEIGHT \
			if actor_id == frozen_lead_id else NORMAL_INFLUENCE_WEIGHT
		var increase_color := str(stance.get("increase_color", ""))
		var decrease_color := str(stance.get("decrease_color", ""))
		weights[increase_color] = int(weights.get(increase_color, 0)) + influence
		weights[decrease_color] = int(weights.get(decrease_color, 0)) - influence
		revealed.append({
			"actor_id": actor_id,
			"increase_color": increase_color,
			"decrease_color": decrease_color,
		})
	weights = _normalize_color_weights(weights)
	color_cycle["distribution_weight_units"] = weights
	color_cycle["distribution_basis_points"] = _weights_to_counts(
		weights,
		DISTRIBUTION_BASIS_POINTS
	)
	color_cycle["revealed_stances"] = revealed
	color_cycle["pending_stances"] = {}
	color_cycle["cycle_number"] = int(color_cycle.get("cycle_number", 0)) + 1
	var color_supply := color_cycle.get("color_supply_state", {}) as Dictionary
	color_supply["bag"] = []
	color_supply["cursor"] = 0
	_refill_color_bag(color_supply, weights)
	color_cycle["color_supply_state"] = color_supply
	_state["color_cycle_state"] = color_cycle
	_advance_hidden_lead()
	return {
		"color_cycle_number": int(color_cycle.get("cycle_number", 0)),
		"color_distribution_basis_points": (
			color_cycle.get("distribution_basis_points", {}) as Dictionary
		).duplicate(true),
		"revealed_stances": revealed.duplicate(true),
	}


func _advance_hidden_lead() -> void:
	var lead := _state.get("hidden_lead_cycle_state", {}) as Dictionary
	var round_order := lead.get("round_order", []) as Array
	var cursor := int(lead.get("lead_cursor", 0))
	var completed := lead.get("completed_lead_ids", []) as Array
	completed.append(str(lead.get("current_lead_id", "")))
	if cursor + 1 < round_order.size():
		cursor += 1
	else:
		var macro_round := int(lead.get("macro_round_number", 1)) + 1
		var direction := "forward" if macro_round % 2 == 1 else "reverse"
		round_order = (lead.get("fixed_order", []) as Array).duplicate()
		if direction == "reverse":
			round_order.reverse()
		lead["macro_round_number"] = macro_round
		lead["direction"] = direction
		lead["round_order"] = round_order
		cursor = 0
		completed = []
	lead["lead_cursor"] = cursor
	lead["completed_lead_ids"] = completed
	lead["current_lead_id"] = str(round_order[cursor])
	_state["hidden_lead_cycle_state"] = lead


func _fill_initial_track() -> void:
	var track := _state.get("track_state", {}) as Dictionary
	var items: Array = []
	var capacity := int(track.get("capacity", 0))
	var lead := _state.get("hidden_lead_cycle_state", {}) as Dictionary
	var fixed_order := lead.get("fixed_order", []) as Array
	var origin_index := fixed_order.find(str(lead.get("current_lead_id", "")))
	for position in range(capacity):
		var item := _draw_supply_card()
		item["path_origin_index"] = origin_index
		item["path_position"] = position
		items.append(item)
	track["items"] = items
	_state["track_state"] = track
	_refresh_track_owners()


func _advance_track(steps: int) -> void:
	var track := _state.get("track_state", {}) as Dictionary
	var capacity := int(track.get("capacity", 0))
	for _step in range(steps):
		var moved: Array = []
		for item_variant in track.get("items", []) as Array:
			var item := (item_variant as Dictionary).duplicate(true)
			item["path_position"] = int(item.get("path_position", 0)) + 1
			if int(item.get("path_position", 0)) < capacity:
				moved.append(item)
		var lead := _state.get("hidden_lead_cycle_state", {}) as Dictionary
		var fixed_order := lead.get("fixed_order", []) as Array
		var origin_index := fixed_order.find(str(lead.get("current_lead_id", "")))
		var incoming := _draw_supply_card()
		incoming["path_origin_index"] = origin_index
		incoming["path_position"] = 0
		moved.push_front(incoming)
		track["items"] = moved
		track["revision"] = int(track.get("revision", 0)) + 1
		_state["track_state"] = track
		_refresh_track_owners()


func _acquisition_live_error(intent: Dictionary) -> String:
	var source_identity := intent.get("source_identity", {}) as Dictionary
	var authorization := (
		intent.get("viewer_segment_authorization", {}) as Dictionary
	)
	var capability_id := str(authorization.get("capability_id", ""))
	var authorization_id := str(authorization.get("authorization_id", ""))
	var consumed_error := _authorization_already_consumed(
		capability_id,
		authorization_id
	)
	if not consumed_error.is_empty():
		return consumed_error
	var track := _state.get("track_state", {}) as Dictionary
	var track_revision := int(track.get("revision", 0))
	if int(source_identity.get("source_track_revision", -1)) != track_revision \
		or int(authorization.get("source_track_revision", -1)) != track_revision:
		return "source_track_revision_stale"
	var actor_id := str(intent.get("actor_id", ""))
	var source_instance_id := str(source_identity.get("source_instance_id", ""))
	var live_identity := visible_source_identity_v1(actor_id, source_instance_id)
	if live_identity.is_empty():
		return "source_not_in_actor_visible_segment"
	if live_identity != source_identity:
		return "source_identity_live_mismatch"
	if str(authorization.get("authorized_source_identity_id", "")) \
		!= str(live_identity.get("source_identity_id", "")) \
		or str(authorization.get("authorized_source_instance_id", "")) \
			!= source_instance_id \
		or str(authorization.get("authorized_actor_id", "")) != actor_id \
		or str(authorization.get("authorized_segment_owner_id", "")) != actor_id:
		return "authorization_live_binding_mismatch"
	return ""


func _acquisition_transaction_access_error(
	transaction_id: String,
	authority_port: RefCounted
) -> String:
	if authority_port == null \
		or _acquisition_authority_port == null \
		or authority_port != _acquisition_authority_port.get_ref():
		return "acquisition_authority_port_not_trusted"
	if not _is_stable_id(transaction_id):
		return "acquisition_transaction_id_invalid"
	if not _active_acquisition_transactions.has(transaction_id):
		return "acquisition_transaction_not_active"
	return ""


func _authorization_already_consumed(
	capability_id: String,
	authorization_id: String
) -> String:
	var processed := _state.get("processed_requests", {}) as Dictionary
	for record_variant in processed.values():
		if not (record_variant is Dictionary):
			continue
		var record := record_variant as Dictionary
		if str(record.get("consumed_capability_id", "")) == capability_id:
			return "capability_already_consumed"
		if str(record.get("consumed_authorization_id", "")) == authorization_id:
			return "authorization_already_consumed"
	return ""


func _commit_visible_acquisition(source_instance_id: String) -> Dictionary:
	var track := _state.get("track_state", {}) as Dictionary
	var items := track.get("items", []) as Array
	var removed_item: Dictionary = {}
	for item_variant in items:
		var item := item_variant as Dictionary
		if str(item.get("instance_id", "")) != source_instance_id:
			continue
		removed_item = item.duplicate(true)
		break
	if removed_item.is_empty():
		return {}

	var removed_position := int(removed_item.get("path_position", -1))
	var surviving_items: Array = []
	for item_variant in items:
		var item := (item_variant as Dictionary).duplicate(true)
		if str(item.get("instance_id", "")) == source_instance_id:
			continue
		if int(item.get("path_position", -1)) < removed_position:
			item["path_position"] = int(item.get("path_position", 0)) + 1
		surviving_items.append(item)
	var replacement := _draw_supply_card()
	track = _state.get("track_state", {}) as Dictionary
	var lead := _state.get("hidden_lead_cycle_state", {}) as Dictionary
	var fixed_order := lead.get("fixed_order", []) as Array
	replacement["path_origin_index"] = fixed_order.find(str(
		lead.get("current_lead_id", "")
	))
	replacement["path_position"] = 0
	surviving_items.push_front(replacement)
	track["items"] = surviving_items
	track["revision"] = int(track.get("revision", 0)) + 1
	_state["track_state"] = track
	_refresh_track_owners()
	return {
		"track_item_removed": true,
		"replacement_count": 1,
		"track_revision": int(track.get("revision", 0)),
	}


func _refresh_track_owners() -> void:
	var track := _state.get("track_state", {}) as Dictionary
	var lead := _state.get("hidden_lead_cycle_state", {}) as Dictionary
	var fixed_order := lead.get("fixed_order", []) as Array
	var local_slots := int(track.get("local_visible_slot_count", 1))
	var refreshed: Array = []
	for item_variant in track.get("items", []) as Array:
		var item := (item_variant as Dictionary).duplicate(true)
		var segment_offset := int(int(item.get("path_position", 0)) / local_slots)
		var owner_index := (
			int(item.get("path_origin_index", 0)) + segment_offset
		) % fixed_order.size()
		item["segment_owner_id"] = str(fixed_order[owner_index])
		refreshed.append(item)
	track["items"] = refreshed
	_state["track_state"] = track


func _draw_supply_card() -> Dictionary:
	var type_supply := _state.get("type_supply_state", {}) as Dictionary
	var card_kind := _draw_type(type_supply)
	_state["type_supply_state"] = type_supply
	var color_cycle := _state.get("color_cycle_state", {}) as Dictionary
	var color_supply := color_cycle.get("color_supply_state", {}) as Dictionary
	var primary_color := _draw_color(
		color_supply,
		color_cycle.get("distribution_weight_units", {}) as Dictionary
	)
	color_cycle["color_supply_state"] = color_supply
	_state["color_cycle_state"] = color_cycle
	var definition_supply := _state.get(
		"normal_supply_state" if card_kind == "normal_card" \
		else "commodity_supply_state",
		{}
	) as Dictionary
	var card_definition_id := _draw_definition(definition_supply)
	if card_kind == "normal_card":
		_state["normal_supply_state"] = definition_supply
	else:
		_state["commodity_supply_state"] = definition_supply
	var track := _state.get("track_state", {}) as Dictionary
	var sequence := int(track.get("next_instance_sequence", 0))
	track["next_instance_sequence"] = sequence + 1
	_state["track_state"] = track
	return {
		"instance_id": "track.card.%08d" % sequence,
		"card_definition_id": card_definition_id,
		"card_kind": card_kind,
		"primary_color": primary_color,
		"path_origin_index": 0,
		"path_position": 0,
		"segment_owner_id": "unassigned",
		"supply_draw_index": sequence,
	}


func _draw_type(supply: Dictionary) -> String:
	var bag := supply.get("bag", []) as Array
	var cursor := int(supply.get("cursor", 0))
	if cursor >= bag.size():
		_refill_type_bag(supply)
		bag = supply.get("bag", []) as Array
		cursor = 0
	var result := str(bag[cursor])
	supply["cursor"] = cursor + 1
	return result


func _draw_color(supply: Dictionary, weights: Dictionary) -> String:
	var bag := supply.get("bag", []) as Array
	var cursor := int(supply.get("cursor", 0))
	if cursor >= bag.size():
		_refill_color_bag(supply, weights)
		bag = supply.get("bag", []) as Array
		cursor = 0
	var result := str(bag[cursor])
	supply["cursor"] = cursor + 1
	return result


func _draw_definition(supply: Dictionary) -> String:
	var bag := supply.get("bag", []) as Array
	var cursor := int(supply.get("cursor", 0))
	if cursor >= bag.size():
		_refill_definition_bag(supply)
		bag = supply.get("bag", []) as Array
		cursor = 0
	var result := str(bag[cursor])
	supply["cursor"] = cursor + 1
	return result


static func _new_definition_supply(
	card_kind: String,
	seed: int,
	stream_id: String
) -> Dictionary:
	var templates: Array = []
	for index in range(12):
		templates.append("%s.reference.%02d" % [card_kind, index])
	var supply := {
		"stream_id": stream_id,
		"card_kind": card_kind,
		"templates": templates,
		"bag": [],
		"cursor": 0,
		"bag_cycle": 0,
		"rng_state": _derive_seed(seed, stream_id),
		"rng_draw_count": 0,
	}
	_refill_definition_bag(supply)
	return supply


static func _refill_type_bag(supply: Dictionary) -> void:
	var ratios := supply.get("ratio_basis_points", {}) as Dictionary
	var counts := _weights_to_counts(ratios, TYPE_BAG_SIZE, CARD_KIND_IDS)
	var entries: Array = []
	for card_kind in CARD_KIND_IDS:
		for _index in range(int(counts.get(card_kind, 0))):
			entries.append(card_kind)
	supply["bag"] = _shuffle_copy(entries, supply)
	supply["cursor"] = 0
	supply["bag_cycle"] = int(supply.get("bag_cycle", 0)) + 1


static func _refill_color_bag(supply: Dictionary, weights: Dictionary) -> void:
	var counts := _weights_to_counts(weights, COLOR_BAG_SIZE, COLOR_IDS)
	var entries: Array = []
	for color_id in COLOR_IDS:
		for _index in range(int(counts.get(color_id, 0))):
			entries.append(color_id)
	supply["bag"] = _shuffle_copy(entries, supply)
	supply["cursor"] = 0
	supply["bag_cycle"] = int(supply.get("bag_cycle", 0)) + 1


static func _refill_definition_bag(supply: Dictionary) -> void:
	supply["bag"] = _shuffle_copy(
		(supply.get("templates", []) as Array).duplicate(),
		supply
	)
	supply["cursor"] = 0
	supply["bag_cycle"] = int(supply.get("bag_cycle", 0)) + 1


static func _uniform_color_weights() -> Dictionary:
	var result: Dictionary = {}
	for color_id in COLOR_IDS:
		result[color_id] = UNIFORM_COLOR_WEIGHT
	return result


static func _normalize_color_weights(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for color_id in COLOR_IDS:
		result[color_id] = clampi(
			int(source.get(color_id, UNIFORM_COLOR_WEIGHT)),
			MINIMUM_COLOR_WEIGHT,
			MAXIMUM_COLOR_WEIGHT
		)
	var total := _integer_dictionary_total(result, COLOR_IDS)
	while total != COLOR_WEIGHT_TOTAL:
		var add := total < COLOR_WEIGHT_TOTAL
		var remaining: int = absi(COLOR_WEIGHT_TOTAL - total)
		var eligible: Array = []
		var eligible_weight_total := 0
		for color_id in COLOR_IDS:
			var value := int(result.get(color_id, 0))
			var room := MAXIMUM_COLOR_WEIGHT - value \
				if add else value - MINIMUM_COLOR_WEIGHT
			if room <= 0:
				continue
			eligible.append(color_id)
			eligible_weight_total += maxi(1, value)
		if eligible.is_empty():
			break
		var allocations: Dictionary = {}
		var remainders: Dictionary = {}
		var allocated := 0
		for color_id in eligible:
			var value := int(result.get(color_id, 0))
			var room := MAXIMUM_COLOR_WEIGHT - value \
				if add else value - MINIMUM_COLOR_WEIGHT
			var numerator: int = remaining * maxi(1, value)
			var share := mini(room, int(numerator / eligible_weight_total))
			allocations[color_id] = share
			remainders[color_id] = numerator % eligible_weight_total
			allocated += share
		if allocated == 0:
			var best_color := str(eligible[0])
			var best_remainder := -1
			for color_id in eligible:
				var remainder := int(remainders.get(color_id, 0))
				if remainder > best_remainder:
					best_remainder = remainder
					best_color = color_id
			allocations[best_color] = 1
			allocated = 1
		for color_id in eligible:
			var delta := int(allocations.get(color_id, 0))
			result[color_id] = int(result.get(color_id, 0)) \
				+ delta * (1 if add else -1)
		total += allocated * (1 if add else -1)
	return result


static func _weights_to_counts(
	weights: Dictionary,
	target_total: int,
	ordered_ids: Array = COLOR_IDS
) -> Dictionary:
	var result: Dictionary = {}
	var remainders: Dictionary = {}
	var weight_total := _integer_dictionary_total(weights, ordered_ids)
	if weight_total <= 0:
		return result
	var allocated := 0
	for id_variant in ordered_ids:
		var item_id := str(id_variant)
		var weight := int(weights.get(item_id, 0))
		var numerator := weight * target_total
		var count := int(numerator / weight_total)
		result[item_id] = count
		remainders[item_id] = numerator % weight_total
		allocated += count
	while allocated < target_total:
		var best_id := str(ordered_ids[0])
		var best_remainder := -1
		for id_variant in ordered_ids:
			var item_id := str(id_variant)
			var remainder := int(remainders.get(item_id, -1))
			if remainder > best_remainder:
				best_remainder = remainder
				best_id = item_id
		result[best_id] = int(result.get(best_id, 0)) + 1
		remainders[best_id] = -1
		allocated += 1
	return result


static func _integer_dictionary_total(values: Dictionary, ordered_ids: Array) -> int:
	var total := 0
	for id_variant in ordered_ids:
		total += int(values.get(str(id_variant), 0))
	return total


static func _new_rng_stream(seed: int, stream_id: String) -> Dictionary:
	return {
		"rng_state": _derive_seed(seed, stream_id),
		"rng_draw_count": 0,
	}


static func _derive_seed(seed: int, stream_id: String) -> int:
	var value := _normalize_seed(seed)
	for index in range(stream_id.length()):
		value = int(
			(value * RNG_MULTIPLIER + stream_id.unicode_at(index) + index + 1)
			% (RNG_MODULUS - 1)
		) + 1
	return value


static func _normalize_seed(seed: int) -> int:
	var value := seed % (RNG_MODULUS - 1)
	if value < 0:
		value += RNG_MODULUS - 1
	return value + 1


static func _next_random_index(stream: Dictionary, upper_bound: int) -> int:
	var state := int(stream.get("rng_state", 1))
	state = int((state * RNG_MULTIPLIER) % RNG_MODULUS)
	stream["rng_state"] = state
	stream["rng_draw_count"] = int(stream.get("rng_draw_count", 0)) + 1
	return state % upper_bound


static func _shuffle_copy(source: Array, stream: Dictionary) -> Array:
	var result := source.duplicate(true)
	for index in range(result.size() - 1, 0, -1):
		var swap_index := _next_random_index(stream, index + 1)
		var temporary: Variant = result[index]
		result[index] = result[swap_index]
		result[swap_index] = temporary
	return result


static func _acquisition_proposal_error(proposal: Dictionary) -> String:
	if not is_pure_data(proposal) \
		or not _exact_fields(proposal, ACQUISITION_PROPOSAL_FIELDS):
		return "fields_invalid"
	if proposal.get("schema_version") != SCHEMA_VERSION \
		or str(proposal.get("interface_id", "")) \
			!= ACQUISITION_PROPOSAL_INTERFACE_ID \
		or str(proposal.get("domain_id", "")) != DOMAIN_ID:
		return "header_invalid"
	for field_name in ["request_id", "intent_id", "actor_id"]:
		if not _is_stable_id(proposal.get(field_name)):
			return "%s_invalid" % field_name
	if proposal.get("intent_id") != proposal.get("request_id") \
		or not _is_fingerprint(proposal.get("intent_fingerprint")):
		return "intent_identity_invalid"
	var action_id := str(proposal.get("action_id", ""))
	if action_id not in ACQUISITION_ACTION_IDS \
		or not _is_positive_integer(proposal.get("source_revision")) \
		or not _is_positive_integer(proposal.get("source_core_revision")) \
		or not _is_positive_integer(proposal.get("source_track_revision")):
		return "source_invalid"
	if not (proposal.get("source_identity") is Dictionary) \
		or not _source_identity_error(
			proposal.get("source_identity", {}) as Dictionary
	).is_empty():
		return "source_identity_invalid"
	if int(proposal.get("source_track_revision", 0)) != int(
		(proposal.get("source_identity", {}) as Dictionary).get(
			"source_track_revision", -1
		)
	):
		return "source_track_revision_mismatch"
	var requirements_variant: Variant = proposal.get("participant_requirements")
	if not (requirements_variant is Array):
		return "participant_requirements_invalid"
	var requirements := requirements_variant as Array
	var observed_roles: Array = []
	for row_variant in requirements:
		if not (row_variant is Dictionary):
			return "participant_requirement_wrong_type"
		var row := row_variant as Dictionary
		if not _exact_fields(row, ACQUISITION_PARTICIPANT_REQUIREMENT_FIELDS) \
			or not _is_stable_id(row.get("participant_role")) \
			or not _is_stable_id(row.get("authority_id")) \
			or not _is_stable_id(row.get("reservation_kind")):
			return "participant_requirement_invalid"
		observed_roles.append(str(row.get("participant_role", "")))
	var expected_roles := ["commodity_slot"] \
		if action_id == ACTION_CLAIM_VISIBLE_COMMODITY \
		else ["cash", "personal_discard"]
	var expected_destination := "commodity_inventory" \
		if action_id == ACTION_CLAIM_VISIBLE_COMMODITY else "personal_discard"
	if not _same_string_set(observed_roles, expected_roles) \
		or str(proposal.get("destination_zone", "")) != expected_destination \
		or proposal.get("cash_reservation_required") \
			!= (action_id == ACTION_PURCHASE_VISIBLE_NORMAL_CARD) \
		or proposal.get("asset_reservation_required") != false:
		return "action_contract_invalid"
	if not _is_fingerprint(proposal.get("proposal_fingerprint")) \
		or str(proposal.get("proposal_fingerprint", "")) \
			!= fingerprint(proposal, "proposal_fingerprint"):
		return "fingerprint_invalid"
	return ""


func _intent_error(intent: Dictionary) -> String:
	if not is_pure_data(intent) or not _exact_fields(intent, INTENT_FIELDS):
		return "intent_fields_invalid"
	if intent.get("schema_version") != SCHEMA_VERSION \
		or str(intent.get("interface_id", "")) != INTENT_INTERFACE_ID \
		or str(intent.get("domain_id", "")) != DOMAIN_ID:
		return "intent_header_invalid"
	if not _is_stable_id(intent.get("request_id")):
		return "request_id_invalid"
	if intent.get("intent_id") != intent.get("request_id"):
		return "intent_id_invalid"
	if not (intent.get("actor_id") is String) \
		or str(intent.get("actor_id", "")).is_empty():
		return "actor_id_invalid"
	if str(intent.get("action_id", "")) not in ACTION_IDS:
		return "action_id_invalid"
	if not _is_nonnegative_integer(intent.get("source_revision")):
		return "source_revision_invalid"
	if intent.get("expected_core_revision") != intent.get("source_revision"):
		return "expected_core_revision_invalid"
	if not _is_fingerprint(intent.get("source_core_fingerprint")):
		return "source_core_fingerprint_invalid"
	if not (intent.get("source_identity") is Dictionary) \
		or not (intent.get("viewer_segment_authorization") is Dictionary) \
		or not (intent.get("parameters") is Dictionary):
		return "parameters_invalid"
	if not _is_fingerprint(intent.get("intent_fingerprint")) \
		or str(intent.get("intent_fingerprint", "")) \
			!= fingerprint(intent, "intent_fingerprint"):
		return "intent_fingerprint_invalid"
	var actor_id := str(intent.get("actor_id", ""))
	var action_id := str(intent.get("action_id", ""))
	var parameters := intent.get("parameters", {}) as Dictionary
	var source_identity := intent.get("source_identity", {}) as Dictionary
	var authorization := (
		intent.get("viewer_segment_authorization", {}) as Dictionary
	)
	if action_id in ACQUISITION_ACTION_IDS:
		if not (_state.get("roster_ids", []) as Array).has(actor_id):
			return "actor_not_authorized"
		if not parameters.is_empty():
			return "acquisition_parameters_not_empty"
		var source_error := _source_identity_error(source_identity)
		if not source_error.is_empty():
			return "source_identity.%s" % source_error
		var authorization_error := _viewer_authorization_error(authorization)
		if not authorization_error.is_empty():
			return "viewer_authorization.%s" % authorization_error
		if str(source_identity.get("segment_owner_id", "")) != actor_id \
			or str(authorization.get("authorized_actor_id", "")) != actor_id \
			or str(authorization.get("authorized_segment_owner_id", "")) != actor_id:
			return "actor_segment_identity_mismatch"
		if authorization.get("authorized_source_identity_id") \
			!= source_identity.get("source_identity_id") \
			or authorization.get("authorized_source_instance_id") \
				!= source_identity.get("source_instance_id") \
			or authorization.get("source_track_revision") \
				!= source_identity.get("source_track_revision"):
			return "authorization_source_identity_mismatch"
		var expected_kind := "commodity_card" \
			if action_id == ACTION_CLAIM_VISIBLE_COMMODITY else "normal_card"
		if str(source_identity.get("source_kind", "")) != expected_kind:
			return "source_kind_action_mismatch"
		if action_id == ACTION_CLAIM_VISIBLE_COMMODITY \
			and str(authorization.get("cash_authority_id", "")) != "authority.none":
			return "commodity_cash_authority_must_be_none"
		if action_id == ACTION_PURCHASE_VISIBLE_NORMAL_CARD \
			and str(authorization.get("cash_authority_id", "")) == "authority.none":
			return "normal_purchase_cash_authority_required"
		return ""
	if not source_identity.is_empty() or not authorization.is_empty():
		return "non_acquisition_source_identity_forbidden"
	if action_id == ACTION_SET_STANCE:
		if not (_state.get("roster_ids", []) as Array).has(actor_id):
			return "actor_not_authorized"
		var stance_error := _stance_error(parameters)
		return "stance.%s" % stance_error if not stance_error.is_empty() else ""
	if actor_id != "system":
		return "system_actor_required"
	if action_id == ACTION_COMMIT_COLOR_CYCLE:
		return "parameters_not_empty" if not parameters.is_empty() else ""
	if not _exact_fields(parameters, ["steps"]) \
		or not _is_positive_integer(parameters.get("steps")) \
		or int(parameters.get("steps", 0)) > 1000:
		return "advance_steps_invalid"
	return ""


static func _stance_error(stance: Dictionary) -> String:
	if not is_pure_data(stance) or not _exact_fields(stance, STANCE_FIELDS):
		return "fields_invalid"
	var increase_color := str(stance.get("increase_color", ""))
	var decrease_color := str(stance.get("decrease_color", ""))
	if increase_color not in COLOR_IDS or decrease_color not in COLOR_IDS:
		return "color_invalid"
	if increase_color == decrease_color:
		return "colors_must_differ"
	return ""


static func _source_identity_error(source_identity: Dictionary) -> String:
	if not is_pure_data(source_identity) \
		or not _exact_fields(source_identity, SOURCE_IDENTITY_FIELDS):
		return "fields_invalid"
	if source_identity.get("schema_version") != SCHEMA_VERSION:
		return "schema_version_invalid"
	for field in [
		"source_identity_id",
		"source_instance_id",
		"source_definition_id",
		"segment_owner_id",
	]:
		if not _is_stable_id(source_identity.get(field)):
			return "%s_invalid" % field
	if str(source_identity.get("source_kind", "")) not in CARD_KIND_IDS:
		return "source_kind_invalid"
	if not _is_positive_integer(source_identity.get("source_track_revision")):
		return "source_track_revision_invalid"
	if not _is_fingerprint(source_identity.get("identity_fingerprint")) \
		or str(source_identity.get("identity_fingerprint", "")) \
			!= fingerprint(source_identity, "identity_fingerprint"):
		return "fingerprint_invalid"
	return ""


static func _viewer_authorization_error(authorization: Dictionary) -> String:
	if not is_pure_data(authorization) \
		or not _exact_fields(authorization, VIEWER_AUTHORIZATION_FIELDS):
		return "fields_invalid"
	if authorization.get("schema_version") != SCHEMA_VERSION:
		return "schema_version_invalid"
	for field in [
		"capability_id",
		"authorization_id",
		"authorization_authority_id",
		"authorized_actor_id",
		"authorized_source_identity_id",
		"authorized_source_instance_id",
		"authorized_segment_owner_id",
		"inventory_authority_id",
		"cash_authority_id",
	]:
		if not _is_stable_id(authorization.get(field)):
			return "%s_invalid" % field
	if str(authorization.get("capability_id", "")) \
			in [CORE_INTERFACE_ID, "authority.none"] \
		or str(authorization.get("authorization_id", "")) \
			in [CORE_INTERFACE_ID, "authority.none"] \
		or authorization.get("capability_id") == authorization.get("authorization_id") \
		or str(authorization.get("authorization_authority_id", "")) \
			in [CORE_INTERFACE_ID, "authority.none"] \
		or str(authorization.get("inventory_authority_id", "")) \
			in [CORE_INTERFACE_ID, "authority.none"] \
		or str(authorization.get("cash_authority_id", "")) == CORE_INTERFACE_ID:
		return "external_authority_identity_invalid"
	if not _is_positive_integer(authorization.get("source_track_revision")):
		return "source_track_revision_invalid"
	if not _is_fingerprint(authorization.get("authorization_fingerprint")) \
		or str(authorization.get("authorization_fingerprint", "")) \
			!= fingerprint(authorization, "authorization_fingerprint"):
		return "fingerprint_invalid"
	return ""


static func _processed_request_record_error(
	request_id: String,
	record: Dictionary,
	current_core_revision: int,
	current_track_revision: int
) -> String:
	if not _exact_fields(record, PROCESSED_REQUEST_FIELDS):
		return "fields_invalid"
	var action_id := str(record.get("action_id", ""))
	if not _is_fingerprint(record.get("intent_fingerprint")) \
		or action_id not in ACTION_IDS \
		or record.get("accepted") != true \
		or str(record.get("reason_code", "")) != "accepted" \
		or not _is_positive_integer(record.get("source_revision")) \
		or not _is_positive_integer(record.get("result_revision")) \
		or int(record.get("result_revision", 0)) \
			!= int(record.get("source_revision", 0)) + 1:
		return "result_invalid"
	if str(record.get("receipt_id", "")) != _receipt_id_for_request(request_id) \
		or str(record.get("intent_id", "")) != request_id \
		or not _is_positive_integer(record.get("committed_core_revision")) \
		or int(record.get("committed_core_revision", 0)) > current_core_revision:
		return "identity_or_revision_invalid"
	var metadata_error := _receipt_metadata_error(action_id, record)
	if not metadata_error.is_empty():
		return "receipt_metadata.%s" % metadata_error
	if not (record.get("public_facts") is Dictionary):
		return "public_facts.wrong_type"
	var public_facts := record.get("public_facts", {}) as Dictionary
	var public_error := _public_facts_error(action_id, public_facts)
	if not public_error.is_empty():
		return "public_facts.%s" % public_error
	if action_id in [
		ACTION_ADVANCE_TRACK,
		ACTION_CLAIM_VISIBLE_COMMODITY,
		ACTION_PURCHASE_VISIBLE_NORMAL_CARD,
	] and int(public_facts.get("track_revision", 0)) > current_track_revision:
		return "public_facts.track_revision_future"
	return ""


static func _receipt_metadata_error(action_id: String, record: Dictionary) -> String:
	if not (record.get("cash_delta") is Dictionary) \
		or not (record.get("inventory_commit") is Dictionary) \
		or not (record.get("external_authority_commit_required") is bool):
		return "fields_invalid"
	var destination_zone := str(record.get("destination_zone", ""))
	var cash_delta := record.get("cash_delta", {}) as Dictionary
	var inventory_commit := record.get("inventory_commit", {}) as Dictionary
	var capability_id := str(record.get("consumed_capability_id", ""))
	var authorization_id := str(record.get("consumed_authorization_id", ""))
	if action_id not in ACQUISITION_ACTION_IDS:
		if destination_zone != "none" \
			or cash_delta != _no_cash_delta() \
			or inventory_commit != _no_inventory_commit() \
			or bool(record.get("external_authority_commit_required", true)) \
			or capability_id != "authority.none" \
			or authorization_id != "authority.none":
			return "non_acquisition_claims_authority"
		return ""
	var expected_destination := "commodity_inventory" \
		if action_id == ACTION_CLAIM_VISIBLE_COMMODITY else "personal_discard"
	if destination_zone != expected_destination \
		or not bool(record.get("external_authority_commit_required", false)) \
		or not _is_stable_id(capability_id) \
		or not _is_stable_id(authorization_id) \
		or capability_id in [CORE_INTERFACE_ID, "authority.none"] \
		or authorization_id in [CORE_INTERFACE_ID, "authority.none"] \
		or capability_id == authorization_id:
		return "acquisition_identity_invalid"
	if not _exact_fields(inventory_commit, INVENTORY_COMMIT_FIELDS) \
		or inventory_commit.get("track_core_committed") != false \
		or str(inventory_commit.get("destination_zone", "")) != expected_destination:
		return "inventory_commit_invalid"
	var inventory_authority_id := str(
		inventory_commit.get("external_authority_id", "")
	)
	if not _is_stable_id(inventory_authority_id) \
		or inventory_authority_id in [CORE_INTERFACE_ID, "authority.none"]:
		return "inventory_authority_invalid"
	if action_id == ACTION_CLAIM_VISIBLE_COMMODITY:
		return "" if cash_delta == _no_cash_delta() else "commodity_cash_delta_invalid"
	if not _exact_fields(cash_delta, CASH_DELTA_FIELDS) \
		or str(cash_delta.get("mode", "")) != "external_authority_required" \
		or cash_delta.get("track_core_committed") != false \
		or cash_delta.get("amount_known") != false \
		or str(cash_delta.get("amount_decimal", "")) != "not_owned":
		return "purchase_cash_delta_invalid"
	var cash_authority_id := str(cash_delta.get("external_authority_id", ""))
	if not _is_stable_id(cash_authority_id) \
		or cash_authority_id in [CORE_INTERFACE_ID, "authority.none"]:
		return "purchase_cash_authority_invalid"
	return ""


static func _public_facts_error(action_id: String, facts: Dictionary) -> String:
	if not is_pure_data(facts):
		return "not_pure_data"
	match action_id:
		ACTION_SET_STANCE:
			if not _exact_fields(facts, STANCE_PUBLIC_FACT_FIELDS) \
				or facts.get("stance_recorded") != true:
				return "stance_schema_invalid"
		ACTION_COMMIT_COLOR_CYCLE:
			if not _exact_fields(facts, COLOR_CYCLE_PUBLIC_FACT_FIELDS) \
				or not _is_positive_integer(facts.get("color_cycle_number")) \
				or not (facts.get("color_distribution_basis_points") is Dictionary) \
				or not (facts.get("revealed_stances") is Array):
				return "color_cycle_schema_invalid"
			var distribution := (
				facts.get("color_distribution_basis_points", {}) as Dictionary
			)
			if not _same_string_set(distribution.keys(), COLOR_IDS) \
				or _integer_dictionary_total(distribution, COLOR_IDS) \
					!= DISTRIBUTION_BASIS_POINTS:
				return "color_cycle_distribution_invalid"
			for color_id in COLOR_IDS:
				if not _is_nonnegative_integer(distribution.get(color_id)):
					return "color_cycle_distribution_invalid"
			var revealed_actor_ids: Array[String] = []
			for row_variant in facts.get("revealed_stances", []) as Array:
				if not (row_variant is Dictionary):
					return "color_cycle_revealed_invalid"
				var row := row_variant as Dictionary
				var actor_id := str(row.get("actor_id", ""))
				if not _exact_fields(row, REVEALED_STANCE_FIELDS) \
					or not _is_stable_id(actor_id) \
					or revealed_actor_ids.has(actor_id) \
					or not _stance_error({
						"increase_color": row.get("increase_color"),
						"decrease_color": row.get("decrease_color"),
					}).is_empty():
					return "color_cycle_revealed_invalid"
				revealed_actor_ids.append(actor_id)
		ACTION_ADVANCE_TRACK:
			if not _exact_fields(facts, TRACK_ADVANCE_PUBLIC_FACT_FIELDS) \
				or not _is_positive_integer(facts.get("advanced_steps")) \
				or not _is_positive_integer(facts.get("track_revision")):
				return "track_advance_schema_invalid"
		ACTION_CLAIM_VISIBLE_COMMODITY, ACTION_PURCHASE_VISIBLE_NORMAL_CARD:
			if not _exact_fields(facts, ACQUISITION_PUBLIC_FACT_FIELDS) \
				or facts.get("track_item_removed") != true \
				or facts.get("replacement_count") != 1 \
				or not _is_positive_integer(facts.get("track_revision")):
				return "acquisition_schema_invalid"
		_:
			return "action_invalid"
	return ""


func _state_error(value: Dictionary) -> String:
	if not is_pure_data(value) or not _exact_fields(value, STATE_FIELDS):
		return "fields_invalid"
	if value.get("schema_version") != SCHEMA_VERSION \
		or value.get("state_version") != STATE_VERSION \
		or str(value.get("ruleset_id", "")) != RULESET_ID \
		or str(value.get("domain_id", "")) != DOMAIN_ID:
		return "header_invalid"
	if not _is_positive_integer(value.get("revision")) \
		or not _is_valid_rng_state(value.get("match_seed")):
		return "revision_or_seed_invalid"
	if not _is_stable_id(value.get("match_instance_id")) \
		or not (value.get("match_instance_id_explicit") is bool):
		return "match_instance_lineage_invalid"
	var match_instance_id := str(value.get("match_instance_id", ""))
	var match_instance_id_explicit := bool(value.get("match_instance_id_explicit", false))
	if (match_instance_id_explicit and match_instance_id == "match.unspecified") \
		or (not match_instance_id_explicit and match_instance_id != "match.unspecified"):
		return "match_instance_lineage_invalid"
	var roster := value.get("roster_ids", []) as Array
	var roster_error := _roster_error(roster)
	if not roster_error.is_empty():
		return "roster.%s" % roster_error

	var track := value.get("track_state", {}) as Dictionary
	if not _exact_fields(track, TRACK_FIELDS) \
		or str(track.get("state_id", "")) != UNIFIED_TRACK_STATE_ID \
		or not _is_positive_integer(track.get("revision")) \
		or not _is_positive_integer(track.get("capacity")) \
		or not _is_positive_integer(track.get("local_visible_slot_count")) \
		or not _is_nonnegative_integer(track.get("next_instance_sequence")) \
		or not (track.get("items") is Array):
		return "track_invalid"
	if int(track.get("capacity", 0)) \
		!= roster.size() * int(track.get("local_visible_slot_count", 0)):
		return "track_capacity_invalid"
	var items := track.get("items", []) as Array
	if items.size() != int(track.get("capacity", 0)):
		return "track_item_count_invalid"
	var instance_ids: Array[String] = []
	var path_positions: Array[int] = []
	var maximum_supply_draw_index := -1
	for item_variant in items:
		if not (item_variant is Dictionary):
			return "track_item_not_dictionary"
		var item := item_variant as Dictionary
		if not _exact_fields(item, TRACK_ITEM_FIELDS) \
			or not _is_stable_id(item.get("instance_id")) \
			or not _is_stable_id(item.get("card_definition_id")) \
			or str(item.get("card_kind", "")) not in CARD_KIND_IDS \
			or str(item.get("primary_color", "")) not in COLOR_IDS \
			or not _is_nonnegative_integer(item.get("path_origin_index")) \
			or not _is_nonnegative_integer(item.get("path_position")) \
			or int(item.get("path_origin_index", -1)) >= roster.size() \
			or int(item.get("path_position", -1)) >= int(track.get("capacity", 0)) \
			or not roster.has(str(item.get("segment_owner_id", ""))) \
			or not _is_nonnegative_integer(item.get("supply_draw_index")):
			return "track_item_invalid"
		var instance_id := str(item.get("instance_id", ""))
		if instance_ids.has(instance_id):
			return "track_instance_duplicate"
		instance_ids.append(instance_id)
		var path_position := int(item.get("path_position", -1))
		if path_positions.has(path_position):
			return "track_position_duplicate"
		path_positions.append(path_position)
		maximum_supply_draw_index = maxi(
			maximum_supply_draw_index,
			int(item.get("supply_draw_index", -1))
		)
	if int(track.get("next_instance_sequence", 0)) <= maximum_supply_draw_index:
		return "track_instance_sequence_invalid"

	var type_supply := value.get("type_supply_state", {}) as Dictionary
	if not _exact_fields(type_supply, TYPE_SUPPLY_FIELDS) \
		or str(type_supply.get("stream_id", "")) != "unified_track_type_draw":
		return "type_supply_fields_invalid"
	var ratios := type_supply.get("ratio_basis_points", {}) as Dictionary
	if not _same_string_set(ratios.keys(), CARD_KIND_IDS) \
		or _integer_dictionary_total(ratios, CARD_KIND_IDS) \
			!= DISTRIBUTION_BASIS_POINTS:
		return "type_supply_ratio_invalid"
	for card_kind in CARD_KIND_IDS:
		if not _is_positive_integer(ratios.get(card_kind)):
			return "type_supply_ratio_invalid"
	if not _supply_cursor_valid(type_supply, CARD_KIND_IDS):
		return "type_supply_invalid"
	var type_bag := type_supply.get("bag", []) as Array
	if type_bag.size() != TYPE_BAG_SIZE \
		or _array_counts(type_bag) \
			!= _weights_to_counts(ratios, TYPE_BAG_SIZE, CARD_KIND_IDS):
		return "type_supply_bag_ratio_invalid"

	for field_name in ["normal_supply_state", "commodity_supply_state"]:
		var supply := value.get(field_name, {}) as Dictionary
		var expected_kind := "normal_card" \
			if field_name == "normal_supply_state" else "commodity_card"
		var expected_stream := "unified_track_normal_card_draw" \
			if field_name == "normal_supply_state" \
			else "unified_track_commodity_draw"
		if not _exact_fields(supply, DEFINITION_SUPPLY_FIELDS) \
			or str(supply.get("stream_id", "")) != expected_stream \
			or str(supply.get("card_kind", "")) != expected_kind \
			or not _supply_cursor_valid(supply, []):
			return "%s_invalid" % field_name
		var templates := supply.get("templates", []) as Array
		if templates.is_empty():
			return "%s_templates_empty" % field_name
		for template_id in templates:
			if not _is_stable_id(template_id):
				return "%s_template_invalid" % field_name
		if _array_counts(templates) \
			!= _array_counts(supply.get("bag", []) as Array):
			return "%s_bag_not_template_permutation" % field_name

	var color_cycle := value.get("color_cycle_state", {}) as Dictionary
	if not _exact_fields(color_cycle, COLOR_CYCLE_FIELDS) \
		or str(color_cycle.get("state_id", "")) != COLOR_CYCLE_STATE_ID \
		or not _is_positive_integer(color_cycle.get("cycle_number")):
		return "color_cycle_invalid"
	var weights := color_cycle.get("distribution_weight_units", {}) as Dictionary
	var basis_points := color_cycle.get("distribution_basis_points", {}) as Dictionary
	if not _same_string_set(weights.keys(), COLOR_IDS) \
		or _integer_dictionary_total(weights, COLOR_IDS) != COLOR_WEIGHT_TOTAL:
		return "color_weights_invalid"
	if not _same_string_set(basis_points.keys(), COLOR_IDS) \
		or _integer_dictionary_total(basis_points, COLOR_IDS) \
			!= DISTRIBUTION_BASIS_POINTS:
		return "color_basis_points_invalid"
	for color_id in COLOR_IDS:
		if not _is_nonnegative_integer(weights.get(color_id)) \
			or int(weights.get(color_id, 0)) < MINIMUM_COLOR_WEIGHT \
			or int(weights.get(color_id, 0)) > MAXIMUM_COLOR_WEIGHT \
			or not _is_nonnegative_integer(basis_points.get(color_id)):
			return "color_value_invalid"
	var pending := color_cycle.get("pending_stances", {}) as Dictionary
	for actor_variant in pending.keys():
		if not roster.has(str(actor_variant)) \
			or not (pending.get(actor_variant) is Dictionary) \
			or not _stance_error(pending.get(actor_variant, {}) as Dictionary).is_empty():
			return "pending_stance_invalid"
	var revealed := color_cycle.get("revealed_stances", []) as Array
	for row_variant in revealed:
		if not (row_variant is Dictionary):
			return "revealed_stance_invalid"
		var row := row_variant as Dictionary
		if not _exact_fields(row, REVEALED_STANCE_FIELDS) \
			or not roster.has(str(row.get("actor_id", ""))) \
			or not _stance_error({
				"increase_color": row.get("increase_color"),
				"decrease_color": row.get("decrease_color"),
			}).is_empty():
			return "revealed_stance_invalid"
	var color_supply := color_cycle.get("color_supply_state", {}) as Dictionary
	if not _exact_fields(color_supply, COLOR_SUPPLY_FIELDS) \
		or str(color_supply.get("stream_id", "")) != "unified_track_color_draw" \
		or not _supply_cursor_valid(color_supply, COLOR_IDS):
		return "color_supply_invalid"
	var color_bag := color_supply.get("bag", []) as Array
	if color_bag.size() != COLOR_BAG_SIZE \
		or _array_counts(color_bag) \
			!= _weights_to_counts(weights, COLOR_BAG_SIZE, COLOR_IDS):
		return "color_supply_bag_distribution_invalid"

	var lead := value.get("hidden_lead_cycle_state", {}) as Dictionary
	if not _exact_fields(lead, HIDDEN_LEAD_FIELDS) \
		or str(lead.get("state_id", "")) != HIDDEN_LEAD_STATE_ID \
		or str(lead.get("stream_id", "")) != "initial_hidden_lead_order" \
		or not _same_string_set(lead.get("fixed_order", []) as Array, roster) \
		or not _same_string_set(lead.get("round_order", []) as Array, roster) \
		or not _is_positive_integer(lead.get("macro_round_number")) \
		or str(lead.get("direction", "")) not in ["forward", "reverse"] \
		or not _is_nonnegative_integer(lead.get("lead_cursor")) \
		or int(lead.get("lead_cursor", -1)) >= roster.size() \
		or not _is_valid_rng_state(lead.get("rng_state")) \
		or not _is_nonnegative_integer(lead.get("rng_draw_count")):
		return "hidden_lead_invalid"
	var expected_round_order := (lead.get("fixed_order", []) as Array).duplicate()
	if str(lead.get("direction", "")) == "reverse":
		expected_round_order.reverse()
	if lead.get("round_order", []) != expected_round_order \
		or str(lead.get("current_lead_id", "")) \
			!= str((lead.get("round_order", []) as Array)[int(lead.get("lead_cursor", 0))]):
		return "hidden_lead_cursor_invalid"
	var completed := lead.get("completed_lead_ids", []) as Array
	if completed.size() != int(lead.get("lead_cursor", 0)):
		return "hidden_lead_completion_invalid"
	for index in range(completed.size()):
		if str(completed[index]) != str((lead.get("round_order", []) as Array)[index]):
			return "hidden_lead_completion_invalid"
	var fixed_order := lead.get("fixed_order", []) as Array
	var local_slots := int(track.get("local_visible_slot_count", 1))
	for item_variant in items:
		var item := item_variant as Dictionary
		var segment_offset := int(int(item.get("path_position", 0)) / local_slots)
		var expected_owner_index := (
			int(item.get("path_origin_index", 0)) + segment_offset
		) % fixed_order.size()
		if str(item.get("segment_owner_id", "")) \
			!= str(fixed_order[expected_owner_index]):
			return "track_segment_binding_invalid"
	var projection_revisions := value.get("projection_revisions", {}) as Dictionary
	if not _same_string_set(projection_revisions.keys(), roster):
		return "projection_revisions_invalid"
	for actor_id in roster:
		if not _is_positive_integer(projection_revisions.get(actor_id)):
			return "projection_revisions_invalid"

	var processed := value.get("processed_requests", {}) as Dictionary
	if int(value.get("revision", 0)) != processed.size() + 1:
		return "processed_request_revision_lineage_invalid"
	var consumed_capabilities: Array[String] = []
	var consumed_authorizations: Array[String] = []
	for request_variant in processed.keys():
		if not _is_stable_id(request_variant) \
			or not (processed.get(request_variant) is Dictionary):
			return "processed_request_invalid"
		var record := processed.get(request_variant, {}) as Dictionary
		var record_error := _processed_request_record_error(
			str(request_variant),
			record,
			int(value.get("revision", 0)),
			int(track.get("revision", 0))
		)
		if not record_error.is_empty():
			return "processed_request_record_invalid.%s" % record_error
		if str(record.get("action_id", "")) in ACQUISITION_ACTION_IDS:
			var capability_id := str(record.get("consumed_capability_id", ""))
			var authorization_id := str(record.get("consumed_authorization_id", ""))
			if consumed_capabilities.has(capability_id) \
				or consumed_authorizations.has(authorization_id):
				return "processed_request_authorization_reused"
			consumed_capabilities.append(capability_id)
			consumed_authorizations.append(authorization_id)
	var lineage_error := _revision_lineage_error(value, processed)
	if not lineage_error.is_empty():
		return "revision_lineage_invalid.%s" % lineage_error
	return ""


static func _revision_lineage_error(
	value: Dictionary,
	processed: Dictionary
) -> String:
	var history_variant: Variant = value.get("revision_lineage")
	if not (history_variant is Array):
		return "wrong_type"
	var history := history_variant as Array
	if history.size() != int(value.get("revision", 0)) \
		or history.size() != processed.size() + 1:
		return "length_invalid"
	var processed_keys := processed.keys()
	var expected_parent := ROOT_LINEAGE_PARENT_HASH
	for index in range(history.size()):
		if not (history[index] is Dictionary):
			return "entry_wrong_type"
		var entry := history[index] as Dictionary
		if not is_pure_data(entry) \
			or not _exact_fields(entry, REVISION_LINEAGE_ENTRY_FIELDS):
			return "entry_fields_invalid"
		if int(entry.get("revision", 0)) != index + 1 \
			or not _is_stable_id(entry.get("request_id")) \
			or not _is_stable_id(entry.get("action_id")) \
			or not _is_fingerprint(entry.get("intent_fingerprint")) \
			or not _is_fingerprint(entry.get("parent_lineage_hash")) \
			or not _is_fingerprint(entry.get("state_payload_fingerprint")) \
			or not _is_fingerprint(entry.get("lineage_hash")):
			return "entry_value_invalid"
		if str(entry.get("parent_lineage_hash", "")) != expected_parent \
			or str(entry.get("lineage_hash", "")) \
				!= fingerprint(entry, "lineage_hash"):
			return "hash_chain_invalid"
		if index == 0:
			if str(entry.get("request_id", "")) != "match.genesis" \
				or str(entry.get("action_id", "")) != "match_started":
				return "genesis_invalid"
		else:
			var request_id := str(processed_keys[index - 1])
			var record := processed.get(request_id, {}) as Dictionary
			if str(entry.get("request_id", "")) != request_id \
				or str(entry.get("action_id", "")) \
					!= str(record.get("action_id", "")) \
				or str(entry.get("intent_fingerprint", "")) \
					!= str(record.get("intent_fingerprint", "")):
				return "processed_request_binding_invalid"
		expected_parent = str(entry.get("lineage_hash", ""))
	var current_entry := history[-1] as Dictionary
	if str(current_entry.get("state_payload_fingerprint", "")) \
			!= _state_lineage_payload_fingerprint(value):
		return "current_state_payload_mismatch"
	return ""


static func _supply_cursor_valid(supply: Dictionary, allowed_bag_values: Array) -> bool:
	if not (supply.get("bag") is Array) \
		or not _is_nonnegative_integer(supply.get("cursor")) \
		or not _is_positive_integer(supply.get("bag_cycle")) \
		or not _is_valid_rng_state(supply.get("rng_state")) \
		or not _is_nonnegative_integer(supply.get("rng_draw_count")):
		return false
	var bag := supply.get("bag", []) as Array
	if bag.is_empty() or int(supply.get("cursor", -1)) > bag.size():
		return false
	for item in bag:
		if not (item is String):
			return false
		if not allowed_bag_values.is_empty() and str(item) not in allowed_bag_values:
			return false
		if allowed_bag_values.is_empty() and not _is_stable_id(item):
			return false
	return true


static func _save_state_error(value: Dictionary) -> String:
	var fields := [
		"schema_version",
		"interface_id",
		"ruleset_id",
		"domain_id",
		"state_version",
		"source_revision",
		"source_core_fingerprint",
		"authority_state",
		"save_fingerprint",
	]
	if not is_pure_data(value) or not _exact_fields(value, fields):
		return "save_state_fields_invalid"
	if value.get("schema_version") != SCHEMA_VERSION \
		or value.get("state_version") != STATE_VERSION \
		or str(value.get("interface_id", "")) != SAVE_INTERFACE_ID \
		or str(value.get("ruleset_id", "")) != RULESET_ID \
		or str(value.get("domain_id", "")) != DOMAIN_ID:
		return "save_state_header_invalid"
	if not _is_positive_integer(value.get("source_revision")) \
		or not (value.get("authority_state") is Dictionary):
		return "save_state_source_invalid"
	var authority_state := value.get("authority_state", {}) as Dictionary
	if int(authority_state.get("revision", 0)) != int(value.get("source_revision", 0)) \
		or str(value.get("source_core_fingerprint", "")) != fingerprint(authority_state):
		return "save_state_source_fingerprint_invalid"
	if not _is_fingerprint(value.get("save_fingerprint")) \
		or str(value.get("save_fingerprint", "")) \
			!= fingerprint(value, "save_fingerprint"):
		return "save_state_fingerprint_invalid"
	return ""


static func _checkpoint_error(value: Dictionary) -> String:
	var fields := [
		"schema_version",
		"interface_id",
		"domain_id",
		"match_instance_id",
		"source_revision",
		"source_core_fingerprint",
		"authority_state",
		"checkpoint_fingerprint",
	]
	if not is_pure_data(value) or not _exact_fields(value, fields):
		return "checkpoint_fields_invalid"
	if value.get("schema_version") != SCHEMA_VERSION \
		or str(value.get("interface_id", "")) != CHECKPOINT_INTERFACE_ID \
		or str(value.get("domain_id", "")) != DOMAIN_ID \
		or not _is_stable_id(value.get("match_instance_id")) \
		or str(value.get("match_instance_id", "")) == "match.unspecified":
		return "checkpoint_header_invalid"
	if not _is_positive_integer(value.get("source_revision")) \
		or not (value.get("authority_state") is Dictionary):
		return "checkpoint_source_invalid"
	var authority_state := value.get("authority_state", {}) as Dictionary
	if int(authority_state.get("revision", 0)) != int(value.get("source_revision", 0)) \
		or str(value.get("source_core_fingerprint", "")) != fingerprint(authority_state) \
		or not bool(authority_state.get("match_instance_id_explicit", false)) \
		or str(authority_state.get("match_instance_id", "")) \
			!= str(value.get("match_instance_id", "")):
		return "checkpoint_source_fingerprint_invalid"
	if not _is_fingerprint(value.get("checkpoint_fingerprint")) \
		or str(value.get("checkpoint_fingerprint", "")) \
			!= fingerprint(value, "checkpoint_fingerprint"):
		return "checkpoint_fingerprint_invalid"
	return ""


static func _receipt_metadata_for_action(
	action_id: String,
	authorization: Dictionary
) -> Dictionary:
	var destination_zone := "none"
	var cash_delta := _no_cash_delta()
	var inventory_commit := _no_inventory_commit()
	var external_authority_commit_required := false
	if action_id in ACQUISITION_ACTION_IDS:
		destination_zone = "commodity_inventory" \
			if action_id == ACTION_CLAIM_VISIBLE_COMMODITY else "personal_discard"
		inventory_commit = {
			"track_core_committed": false,
			"external_authority_id": str(
				authorization.get("inventory_authority_id", "")
			),
			"destination_zone": destination_zone,
		}
		external_authority_commit_required = true
		if action_id == ACTION_PURCHASE_VISIBLE_NORMAL_CARD:
			cash_delta = {
				"mode": "external_authority_required",
				"track_core_committed": false,
				"amount_known": false,
				"amount_decimal": "not_owned",
				"external_authority_id": str(
					authorization.get("cash_authority_id", "")
				),
			}
	return {
		"destination_zone": destination_zone,
		"cash_delta": cash_delta,
		"inventory_commit": inventory_commit,
		"external_authority_commit_required": external_authority_commit_required,
	}


static func _no_cash_delta() -> Dictionary:
	return {
		"mode": "none",
		"track_core_committed": false,
		"amount_known": true,
		"amount_decimal": "0",
		"external_authority_id": "authority.none",
	}


static func _no_inventory_commit() -> Dictionary:
	return {
		"track_core_committed": false,
		"external_authority_id": "authority.none",
		"destination_zone": "none",
	}


static func _receipt_id_for_request(request_id: String) -> String:
	return "receipt.%s" % request_id.sha256_text().left(32).to_lower()


func _receipt_from_record(request_id: String, record: Dictionary) -> Dictionary:
	var unsealed := {
		"schema_version": SCHEMA_VERSION,
		"interface_id": RECEIPT_INTERFACE_ID,
		"domain_id": DOMAIN_ID,
		"request_id": request_id,
		"receipt_id": str(record.get("receipt_id", "")),
		"intent_id": str(record.get("intent_id", "")),
		"action_id": str(record.get("action_id", "")),
		"intent_fingerprint": str(record.get("intent_fingerprint", "")),
		"accepted": bool(record.get("accepted", false)),
		"reason_code": str(record.get("reason_code", "")),
		"source_revision": int(record.get("source_revision", 0)),
		"result_revision": int(record.get("result_revision", 0)),
		"committed_core_revision": int(record.get("committed_core_revision", 0)),
		"destination_zone": str(record.get("destination_zone", "none")),
		"cash_delta": (
			record.get("cash_delta", {}) as Dictionary
		).duplicate(true),
		"inventory_commit": (
			record.get("inventory_commit", {}) as Dictionary
		).duplicate(true),
		"external_authority_commit_required": bool(
			record.get("external_authority_commit_required", false)
		),
		"public_facts": (
			record.get("public_facts", {}) as Dictionary
		).duplicate(true),
	}
	return sealed_copy(unsealed, "receipt_fingerprint")


func _failure_receipt(intent: Dictionary, reason_code: String) -> Dictionary:
	var actor_id := str(intent.get("actor_id", ""))
	var request_id := str(intent.get("request_id", "invalid.request"))
	var source_revision := _intent_source_revision(actor_id) \
		if is_configured() and (actor_id == "system" \
			or (_state.get("roster_ids", []) as Array).has(actor_id)) else 0
	var unsealed := {
		"schema_version": SCHEMA_VERSION,
		"interface_id": RECEIPT_INTERFACE_ID,
		"domain_id": DOMAIN_ID,
		"request_id": request_id,
		"receipt_id": _receipt_id_for_request(request_id),
		"intent_id": str(intent.get("intent_id", request_id)),
		"action_id": str(intent.get("action_id", "invalid.action")),
		"intent_fingerprint": str(intent.get("intent_fingerprint", "")),
		"accepted": false,
		"reason_code": reason_code,
		"source_revision": source_revision,
		"result_revision": source_revision,
		"committed_core_revision": int(_state.get("revision", 0)) \
			if is_configured() else 0,
		"destination_zone": "none",
		"cash_delta": _no_cash_delta(),
		"inventory_commit": _no_inventory_commit(),
		"external_authority_commit_required": false,
		"public_facts": {},
	}
	return sealed_copy(unsealed, "receipt_fingerprint")


static func _acquisition_prepare_result(
	accepted: bool,
	reason_code: String
) -> Dictionary:
	return {
		"accepted": accepted,
		"prepared": accepted,
		"reason_code": reason_code,
		"proposal": {},
	}


static func _transaction_operation_result(
	accepted: bool,
	reason_code: String,
	transaction_id: String
) -> Dictionary:
	return {
		"accepted": accepted,
		"reason_code": reason_code,
		"transaction_id": transaction_id,
	}


static func _operation_result(accepted: bool, reason_code: String) -> Dictionary:
	return {
		"accepted": accepted,
		"reason_code": reason_code,
		"source_revision": 0,
		"result_revision": 0,
		"core_fingerprint": "",
	}


static func _config_error(config: Dictionary) -> String:
	if not is_pure_data(config) or not _exact_fields(
		config,
		[],
		[
			"normal_card_ratio_basis_points",
			"commodity_card_ratio_basis_points",
			"local_visible_slot_count",
			"match_instance_id",
		]
	):
		return "config_fields_invalid"
	var normal_ratio: Variant = config.get(
		"normal_card_ratio_basis_points",
		DEFAULT_NORMAL_RATIO_BASIS_POINTS
	)
	var commodity_ratio: Variant = config.get(
		"commodity_card_ratio_basis_points",
		DEFAULT_COMMODITY_RATIO_BASIS_POINTS
	)
	var local_slots: Variant = config.get(
		"local_visible_slot_count",
		DEFAULT_LOCAL_VISIBLE_SLOT_COUNT
	)
	if not _is_positive_integer(normal_ratio) \
		or not _is_positive_integer(commodity_ratio) \
		or int(normal_ratio) + int(commodity_ratio) \
			!= DISTRIBUTION_BASIS_POINTS:
		return "card_kind_ratio_invalid"
	if not _is_positive_integer(local_slots) or int(local_slots) > 20:
		return "local_visible_slot_count_invalid"
	if config.has("match_instance_id"):
		if not _is_stable_id(config.get("match_instance_id")) \
			or str(config.get("match_instance_id", "")) == "match.unspecified":
			return "match_instance_id_invalid"
	return ""


static func _roster_error(roster: Array) -> String:
	if roster.size() < MIN_PLAYER_COUNT or roster.size() > MAX_PLAYER_COUNT:
		return "player_count_invalid"
	var seen: Array[String] = []
	for actor_variant in roster:
		if not _is_stable_id(actor_variant):
			return "actor_id_invalid"
		var actor_id := str(actor_variant)
		if actor_id == "system" or seen.has(actor_id):
			return "actor_id_duplicate_or_reserved"
		seen.append(actor_id)
	return ""


static func is_pure_data(value: Variant) -> bool:
	if value is String or value is bool or value is int:
		return true
	if value is Array:
		for item in value as Array:
			if not is_pure_data(item):
				return false
		return true
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if not (key_variant is String) \
				or not is_pure_data((value as Dictionary).get(key_variant)):
				return false
		return true
	return false


static func canonical_json(value: Variant) -> String:
	if not is_pure_data(value):
		return ""
	if value is String or value is bool or value is int:
		return JSON.stringify(value)
	if value is Array:
		var parts: Array[String] = []
		for item in value as Array:
			parts.append(canonical_json(item))
		return "[" + ",".join(parts) + "]"
	var source := value as Dictionary
	var keys: Array[String] = []
	for key_variant in source.keys():
		keys.append(str(key_variant))
	keys.sort()
	var members: Array[String] = []
	for key in keys:
		members.append(JSON.stringify(key) + ":" + canonical_json(source.get(key)))
	return "{" + ",".join(members) + "}"


static func fingerprint(value: Variant, omitted_field: String = "") -> String:
	if not is_pure_data(value):
		return ""
	var source: Variant = value.duplicate(true) \
		if value is Dictionary or value is Array else value
	if source is Dictionary and not omitted_field.is_empty():
		(source as Dictionary).erase(omitted_field)
	var canonical := canonical_json(source)
	return canonical.sha256_text().to_lower() if not canonical.is_empty() else ""


static func sealed_copy(unsealed: Dictionary, fingerprint_field: String) -> Dictionary:
	if not is_pure_data(unsealed) or unsealed.has(fingerprint_field):
		return {}
	var result := unsealed.duplicate(true)
	result[fingerprint_field] = fingerprint(result)
	return result


static func _exact_fields(
	value: Dictionary,
	required_fields: Array,
	optional_fields: Array = []
) -> bool:
	for key_variant in value.keys():
		var key := str(key_variant)
		if not required_fields.has(key) and not optional_fields.has(key):
			return false
	for field_variant in required_fields:
		if not value.has(str(field_variant)):
			return false
	return true


static func _same_string_set(first: Array, second: Array) -> bool:
	if first.size() != second.size():
		return false
	var left: Array[String] = []
	var right: Array[String] = []
	for value in first:
		left.append(str(value))
	for value in second:
		right.append(str(value))
	left.sort()
	right.sort()
	return left == right


static func _array_counts(values: Array) -> Dictionary:
	var result: Dictionary = {}
	for value in values:
		var key := str(value)
		result[key] = int(result.get(key, 0)) + 1
	return result


static func _is_nonnegative_integer(value: Variant) -> bool:
	return value is int and int(value) >= 0


static func _is_positive_integer(value: Variant) -> bool:
	return value is int and int(value) > 0


static func _is_valid_rng_state(value: Variant) -> bool:
	return value is int and int(value) >= 1 and int(value) < RNG_MODULUS


static func _is_stable_id(value: Variant) -> bool:
	if not (value is String):
		return false
	var text := value as String
	if text.is_empty() or text.length() > 160:
		return false
	for index in range(text.length()):
		var code := text.unicode_at(index)
		var lower := code >= 97 and code <= 122
		var digit := code >= 48 and code <= 57
		var separator := code in [45, 46, 95]
		if not lower and not digit and not separator:
			return false
	return true


static func _is_fingerprint(value: Variant) -> bool:
	if not (value is String) or (value as String).length() != 64:
		return false
	for index in range((value as String).length()):
		var code := (value as String).unicode_at(index)
		if not ((code >= 48 and code <= 57) or (code >= 97 and code <= 102)):
			return false
	return true
