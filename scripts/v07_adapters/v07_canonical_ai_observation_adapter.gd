extends RefCounted
class_name V07CanonicalAiObservationAdapter

## Capability-gated, read-only adapter over all five detached V0.7.1 observations.
## Authorization retains only identity, revisions, and source fingerprints.

const CODEC := preload(
	"res://scripts/v07_adapters/v07_canonical_data_codec.gd"
)
const TRACK_CORE := preload(
	"res://scripts/v07_semantic/v07_unified_card_track_core.gd"
)
const DBG_CORE := preload("res://scripts/v07_semantic/v07_dbg_deck_core.gd")
const ASSET_BATCH_CORE := preload(
	"res://scripts/v07_semantic/v07_asset_batch_core.gd"
)
const SOLAR_CORE := preload(
	"res://scripts/v07_semantic/v07_solar_victory_core.gd"
)

const SCHEMA_VERSION := 2
const RULESET_ID := "v0.7.1"
const ADAPTER_ID := "v071.canonical.ai_observation_adapter.v2"
const OBSERVATION_ID := "v071.canonical.ai_observation.v2"
const VISIBILITY_SCOPE_ID := "ai_actor_authorized_plus_public"

const AUTHORIZATION_CONTEXT_FIELDS := [
	"schema_version",
	"match_instance_id",
	"match_generation",
	"viewer_id",
	"authorization_revision",
	"source_revision",
	"track_source_revision",
	"dbg_source_revision",
	"asset_source_revision",
	"batch_source_revision",
	"track_observation_fingerprint",
	"dbg_observation_fingerprint",
	"asset_observation_fingerprint",
	"batch_observation_fingerprint",
	"solar_observation_fingerprint",
]
const SOURCE_BUNDLE_FIELDS := [
	"unified_track",
	"personal_dbg",
	"six_color_assets",
	"card_batch",
	"solar_victory",
]
const COMPONENT_SOURCE_REVISION_FIELDS := [
	"unified_track",
	"personal_dbg",
	"six_color_assets",
	"card_batch",
]
const CANONICAL_OBSERVATION_FIELDS := [
	"schema_version",
	"observation_id",
	"adapter_id",
	"ruleset_id",
	"visibility_scope_id",
	"match_instance_id",
	"match_generation",
	"viewer_id",
	"authorization_revision",
	"source_revision",
	"component_source_revisions",
	"unified_track",
	"personal_dbg",
	"six_color_assets",
	"card_batch",
	"solar_victory",
	"observation_fingerprint",
]

const TRACK_OBSERVATION_FIELDS := [
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
const TRACK_PRIVATE_FACT_FIELDS := [
	"own_segment_items",
	"own_pending_stance",
	"self_is_current_lead",
	"self_influence_class",
]
const TRACK_ITEM_FIELDS := [
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
const TRACK_REVEALED_STANCE_FIELDS := [
	"actor_id",
	"increase_color",
	"decrease_color",
]
const TRACK_PENDING_STANCE_FIELDS := ["increase_color", "decrease_color"]
const CARD_KIND_IDS := ["normal_card", "commodity_card"]
const COLOR_IDS := [
	"life",
	"energy",
	"industry",
	"technology",
	"commerce",
	"shipping",
]
const SOLAR_OBSERVATION_FIELDS := [
	"schema_version",
	"ruleset_id",
	"observation_id",
	"solar_phase_id",
	"facility_work_rate_multiplier",
	"victory_pending",
	"macro_round_index",
	"final_settlement_committed",
]

const SOURCE_FORBIDDEN_KEYS := [
	"authority_capability",
	"authorization_capability",
	"authority_state",
	"future_supply_bags",
	"future_track_sequence",
	"hidden_lead_cycle_state",
	"hidden_lead_identity_and_order",
	"match_seed",
	"other_exact_assets",
	"other_local_queues",
	"other_reservations",
	"other_track_segments",
	"owner_player_id",
	"private_owner_bindings",
	"rng_state",
	"save_payload",
	"submission_hidden_lead_order",
	"frozen_hidden_lead_order",
	"ai_plan",
	"ai_plans",
	"ai_score",
	"ai_scores",
	"pressure_bucket",
	"pressure_buckets",
	"private_route_plan",
	"private_route_plans",
	"private_cash",
	"exact_cash",
]
const TRACK_FORBIDDEN_KEYS := [
	"authority_state",
	"hidden_lead_cycle_state",
	"fixed_order",
	"round_order",
	"current_lead_id",
	"rng_state",
	"bag",
	"processed_requests",
	"match_seed",
	"self_lead_notice",
	"self_lead_notice_token",
]
const DBG_FORBIDDEN_KEYS := [
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
const ASSET_BATCH_FORBIDDEN_KEYS := [
	"submission_hidden_lead_order",
	"frozen_hidden_lead_order",
	"actor_id",
	"lineage_fingerprint",
	"lock_fingerprint",
	"other_exact_assets",
	"other_reservations",
	"other_local_queues",
	"save_payload",
]
const SOLAR_FORBIDDEN_KEYS := [
	"pending_condition_id",
	"pending_trigger_intent_id",
	"pending_trigger_revision",
	"pending_qualification_proof_id",
	"pending_qualification_proof_fingerprint",
	"pending_qualification_authority_id",
	"pending_qualification_source_authority_id",
	"pending_qualification_issuer_instance_id",
	"pending_qualification_source_revision",
	"processed_intent_ids",
	"receipt_ledger",
	"hidden_lead_identity_or_order",
	"trusted_authority_port",
	"authority_capability",
]


class AiObservationCapability:
	extends RefCounted


var _capability: RefCounted = null
var _authorization_context: Dictionary = {}
var _last_observation_fingerprint := ""
var _bind_count := 0
var _adapt_count := 0
var _duplicate_count := 0
var _bind_rejection_count := 0
var _adapt_rejection_count := 0
var _last_reason_code := "adapter_unconfigured"


func _init(capability: RefCounted = null) -> void:
	if capability is AiObservationCapability:
		_capability = capability


static func issue_capability() -> RefCounted:
	return AiObservationCapability.new()


static func build_authorization_context(
	match_instance_id: String,
	match_generation: int,
	viewer_id: String,
	authorization_revision: int,
	source_revision: int,
	unified_track_observation: Dictionary,
	personal_dbg_observation: Dictionary,
	six_color_asset_observation: Dictionary,
	card_batch_observation: Dictionary,
	solar_victory_observation: Dictionary
) -> Dictionary:
	var sources := {
		"unified_track": unified_track_observation,
		"personal_dbg": personal_dbg_observation,
		"six_color_assets": six_color_asset_observation,
		"card_batch": card_batch_observation,
		"solar_victory": solar_victory_observation,
	}
	if not _authorization_identity_reason(
		match_instance_id,
		match_generation,
		viewer_id,
		authorization_revision,
		source_revision
	).is_empty() or not _source_bundle_reason(sources, viewer_id).is_empty():
		return {}
	return {
		"schema_version": SCHEMA_VERSION,
		"match_instance_id": match_instance_id,
		"match_generation": match_generation,
		"viewer_id": viewer_id,
		"authorization_revision": authorization_revision,
		"source_revision": source_revision,
		"track_source_revision": int(
			unified_track_observation.get("source_revision", -1)
		),
		"dbg_source_revision": int(
			personal_dbg_observation.get("revision", -1)
		),
		"asset_source_revision": int(
			six_color_asset_observation.get("state_revision", -1)
		),
		"batch_source_revision": int(
			card_batch_observation.get("state_revision", -1)
		),
		"track_observation_fingerprint": str(
			unified_track_observation.get("projection_fingerprint", "")
		),
		"dbg_observation_fingerprint": CODEC.fingerprint(
			personal_dbg_observation
		),
		"asset_observation_fingerprint": str(
			six_color_asset_observation.get("projection_fingerprint", "")
		),
		"batch_observation_fingerprint": str(
			card_batch_observation.get("projection_fingerprint", "")
		),
		"solar_observation_fingerprint": CODEC.fingerprint(
			solar_victory_observation
		),
	}


func bind_authorization(
	capability: RefCounted,
	context: Dictionary
) -> bool:
	if not _capability_matches(capability):
		return _reject_binding("capability_rejected")
	var context_reason := _authorization_context_reason(context)
	if not context_reason.is_empty():
		return _reject_binding(context_reason)
	var rebinding_reason := _rebinding_reason(context)
	if not rebinding_reason.is_empty():
		return _reject_binding(rebinding_reason)
	var changed := context != _authorization_context
	_authorization_context = context.duplicate(true)
	if changed:
		_last_observation_fingerprint = ""
	_bind_count += 1
	_last_reason_code = "authorization_bound"
	return true


func adapt_ai_observation(
	capability: RefCounted,
	context: Dictionary,
	sources: Dictionary
) -> Dictionary:
	if not _capability_matches(capability):
		return _reject_adaptation("capability_rejected")
	if _authorization_context.is_empty():
		return _reject_adaptation("authorization_unbound")
	var context_reason := _authorization_context_reason(context)
	if not context_reason.is_empty():
		return _reject_adaptation(context_reason)
	var match_reason := _authorization_match_reason(context)
	if not match_reason.is_empty():
		return _reject_adaptation(match_reason)
	var source_reason := _source_bundle_reason(
		sources,
		str(context.get("viewer_id", ""))
	)
	if not source_reason.is_empty():
		return _reject_adaptation(source_reason)
	var binding_reason := _source_binding_reason(context, sources)
	if not binding_reason.is_empty():
		return _reject_adaptation(binding_reason)

	var track := sources.get("unified_track", {}) as Dictionary
	var dbg := sources.get("personal_dbg", {}) as Dictionary
	var assets := sources.get("six_color_assets", {}) as Dictionary
	var batch := sources.get("card_batch", {}) as Dictionary
	var solar := sources.get("solar_victory", {}) as Dictionary
	var unsealed := {
		"schema_version": SCHEMA_VERSION,
		"observation_id": OBSERVATION_ID,
		"adapter_id": ADAPTER_ID,
		"ruleset_id": RULESET_ID,
		"visibility_scope_id": VISIBILITY_SCOPE_ID,
		"match_instance_id": str(context.get("match_instance_id", "")),
		"match_generation": int(context.get("match_generation", -1)),
		"viewer_id": str(context.get("viewer_id", "")),
		"authorization_revision": int(
			context.get("authorization_revision", -1)
		),
		"source_revision": int(context.get("source_revision", -1)),
		"component_source_revisions": {
			"unified_track": int(track.get("source_revision", -1)),
			"personal_dbg": int(dbg.get("revision", -1)),
			"six_color_assets": int(assets.get("state_revision", -1)),
			"card_batch": int(batch.get("state_revision", -1)),
		},
		"unified_track": track.duplicate(true),
		"personal_dbg": dbg.duplicate(true),
		"six_color_assets": assets.duplicate(true),
		"card_batch": batch.duplicate(true),
		"solar_victory": solar.duplicate(true),
	}
	var observation := CODEC.seal(unsealed, "observation_fingerprint")
	var validation := validation_report(observation)
	if not bool(validation.get("valid", false)):
		return _reject_adaptation(str(validation.get(
			"reason_code",
			"canonical_observation_invalid"
		)))
	var observation_fingerprint := str(
		observation.get("observation_fingerprint", "")
	)
	if not _last_observation_fingerprint.is_empty():
		if observation_fingerprint == _last_observation_fingerprint:
			_duplicate_count += 1
			_last_reason_code = "observation_duplicate"
			return detached_copy(observation)
		return _reject_adaptation("bound_source_observation_conflict")
	_last_observation_fingerprint = observation_fingerprint
	_adapt_count += 1
	_last_reason_code = "observation_adapted"
	return detached_copy(observation)


func ai_observation(
	capability: RefCounted,
	context: Dictionary,
	sources: Dictionary
) -> Dictionary:
	return adapt_ai_observation(capability, context, sources)


func authorized_context(capability: RefCounted) -> Dictionary:
	if not _capability_matches(capability):
		return {}
	return _authorization_context.duplicate(true)


func last_reason_code() -> String:
	return _last_reason_code


func debug_snapshot() -> Dictionary:
	return {
		"adapter_id": ADAPTER_ID,
		"target_ruleset_id": RULESET_ID,
		"capability_bound": _capability != null,
		"authorization_bound": not _authorization_context.is_empty(),
		"match_instance_id": str(
			_authorization_context.get("match_instance_id", "")
		),
		"match_generation": int(
			_authorization_context.get("match_generation", -1)
		),
		"viewer_id": str(_authorization_context.get("viewer_id", "")),
		"authorization_revision": int(
			_authorization_context.get("authorization_revision", -1)
		),
		"source_revision": int(
			_authorization_context.get("source_revision", -1)
		),
		"bind_count": _bind_count,
		"adapt_count": _adapt_count,
		"duplicate_count": _duplicate_count,
		"bind_rejection_count": _bind_rejection_count,
		"adapt_rejection_count": _adapt_rejection_count,
		"last_reason_code": _last_reason_code,
		"mutates_core": false,
		"consumes_rng": false,
		"stores_observation_payloads": false,
		"capability_is_observation_data": false,
	}


static func validation_report(value: Variant) -> Dictionary:
	if not (value is Dictionary) or not CODEC.is_pure_data(value):
		return _invalid("canonical_observation_not_pure_data")
	var observation := value as Dictionary
	if not CODEC.has_exact_fields(observation, CANONICAL_OBSERVATION_FIELDS):
		return _invalid("canonical_observation_fields_invalid")
	if observation.get("schema_version") != SCHEMA_VERSION \
			or str(observation.get("observation_id", "")) != OBSERVATION_ID \
			or str(observation.get("adapter_id", "")) != ADAPTER_ID \
			or str(observation.get("ruleset_id", "")) != RULESET_ID \
			or str(observation.get("visibility_scope_id", "")) \
				!= VISIBILITY_SCOPE_ID:
		return _invalid("canonical_observation_identity_invalid")
	var identity_reason := _authorization_identity_reason(
		str(observation.get("match_instance_id", "")),
		int(observation.get("match_generation", -1)),
		str(observation.get("viewer_id", "")),
		int(observation.get("authorization_revision", -1)),
		int(observation.get("source_revision", -1))
	)
	if not identity_reason.is_empty():
		return _invalid(identity_reason)
	var sources := {
		"unified_track": observation.get("unified_track"),
		"personal_dbg": observation.get("personal_dbg"),
		"six_color_assets": observation.get("six_color_assets"),
		"card_batch": observation.get("card_batch"),
		"solar_victory": observation.get("solar_victory"),
	}
	var source_reason := _source_bundle_reason(
		sources,
		str(observation.get("viewer_id", ""))
	)
	if not source_reason.is_empty():
		return _invalid(source_reason)
	var revisions_variant: Variant = observation.get(
		"component_source_revisions"
	)
	if not (revisions_variant is Dictionary):
		return _invalid("component_source_revisions_invalid")
	var revisions := revisions_variant as Dictionary
	if not CODEC.has_exact_fields(
		revisions,
		COMPONENT_SOURCE_REVISION_FIELDS
	) \
			or revisions.get("unified_track") \
				!= (sources.get("unified_track") as Dictionary).get(
					"source_revision"
				) \
			or revisions.get("personal_dbg") \
				!= (sources.get("personal_dbg") as Dictionary).get("revision") \
			or revisions.get("six_color_assets") \
				!= (sources.get("six_color_assets") as Dictionary).get(
					"state_revision"
				) \
			or revisions.get("card_batch") \
				!= (sources.get("card_batch") as Dictionary).get(
					"state_revision"
				):
		return _invalid("component_source_revisions_mismatch")
	if _contains_key_recursive(sources, SOURCE_FORBIDDEN_KEYS):
		return _invalid("canonical_observation_private_field_forbidden")
	if not CODEC.is_fingerprint(observation.get("observation_fingerprint")) \
			or str(observation.get("observation_fingerprint", "")) \
				!= CODEC.fingerprint(observation, "observation_fingerprint"):
		return _invalid("canonical_observation_fingerprint_invalid")
	return _valid()


static func detached_copy(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) \
		if bool(validation_report(value).get("valid", false)) else {}


static func matches_authorization(
	value: Variant,
	match_instance_id: String,
	match_generation: int,
	viewer_id: String,
	authorization_revision: int,
	source_revision: int
) -> bool:
	if not bool(validation_report(value).get("valid", false)):
		return false
	var observation := value as Dictionary
	return str(observation.get("match_instance_id", "")) == match_instance_id \
		and int(observation.get("match_generation", -1)) == match_generation \
		and str(observation.get("viewer_id", "")) == viewer_id \
		and int(observation.get("authorization_revision", -1)) \
			== authorization_revision \
		and int(observation.get("source_revision", -1)) == source_revision


func _capability_matches(capability: RefCounted) -> bool:
	return _capability != null \
		and capability is AiObservationCapability \
		and capability == _capability


func _rebinding_reason(next: Dictionary) -> String:
	if _authorization_context.is_empty() or next == _authorization_context:
		return ""
	var current := _authorization_context
	var same_match: bool = (
		next.get("match_instance_id") == current.get("match_instance_id")
	)
	var next_generation := int(next.get("match_generation", -1))
	var current_generation := int(current.get("match_generation", -1))
	var next_authorization := int(next.get("authorization_revision", -1))
	var current_authorization := int(current.get("authorization_revision", -1))
	if same_match and next_generation < current_generation:
		return "match_generation_stale"
	if not same_match or next_generation > current_generation:
		return "" if next_authorization > current_authorization \
			else "authorization_revision_not_rotated"
	if next.get("viewer_id") != current.get("viewer_id") \
			and next_authorization <= current_authorization:
		return "viewer_authorization_not_rotated"
	if next_authorization < current_authorization:
		return "authorization_revision_stale"
	var next_source := int(next.get("source_revision", -1))
	var current_source := int(current.get("source_revision", -1))
	if next_source < current_source:
		return "source_revision_stale"
	var source_binding_fields := [
		"track_source_revision",
		"dbg_source_revision",
		"asset_source_revision",
		"batch_source_revision",
		"track_observation_fingerprint",
		"dbg_observation_fingerprint",
		"asset_observation_fingerprint",
		"batch_observation_fingerprint",
		"solar_observation_fingerprint",
	]
	if next_source == current_source:
		for field in source_binding_fields:
			if next.get(field) != current.get(field):
				return "source_revision_conflict"
		return ""
	for field in [
		"track_source_revision",
		"dbg_source_revision",
		"asset_source_revision",
		"batch_source_revision",
	]:
		if int(next.get(field, -1)) < int(current.get(field, -1)):
			return "component_source_revision_stale"
	return ""


func _authorization_match_reason(context: Dictionary) -> String:
	var current := _authorization_context
	if context.get("match_instance_id") != current.get("match_instance_id"):
		return "match_instance_mismatch"
	var generation := int(context.get("match_generation", -1))
	var current_generation := int(current.get("match_generation", -1))
	if generation != current_generation:
		return "match_generation_stale" if generation < current_generation \
			else "match_generation_mismatch"
	if context.get("viewer_id") != current.get("viewer_id"):
		return "viewer_unauthorized"
	var authorization_revision := int(context.get("authorization_revision", -1))
	var current_authorization := int(current.get("authorization_revision", -1))
	if authorization_revision != current_authorization:
		return "authorization_revision_stale" \
			if authorization_revision < current_authorization \
			else "authorization_revision_mismatch"
	var source_revision := int(context.get("source_revision", -1))
	var current_source := int(current.get("source_revision", -1))
	if source_revision != current_source:
		return "source_revision_stale" if source_revision < current_source \
			else "source_revision_mismatch"
	for field in [
		"track_source_revision",
		"dbg_source_revision",
		"asset_source_revision",
		"batch_source_revision",
		"track_observation_fingerprint",
		"dbg_observation_fingerprint",
		"asset_observation_fingerprint",
		"batch_observation_fingerprint",
		"solar_observation_fingerprint",
	]:
		if context.get(field) != current.get(field):
			return "authorized_source_binding_mismatch"
	return ""


static func _authorization_context_reason(context: Dictionary) -> String:
	if not CODEC.is_pure_data(context) \
			or not CODEC.has_exact_fields(context, AUTHORIZATION_CONTEXT_FIELDS):
		return "authorization_context_fields_invalid"
	if context.get("schema_version") != SCHEMA_VERSION:
		return "authorization_context_schema_invalid"
	var identity_reason := _authorization_identity_reason(
		str(context.get("match_instance_id", "")),
		int(context.get("match_generation", -1)),
		str(context.get("viewer_id", "")),
		int(context.get("authorization_revision", -1)),
		int(context.get("source_revision", -1))
	)
	if not identity_reason.is_empty():
		return identity_reason
	if not _is_positive_integer(context.get("track_source_revision")) \
			or not _is_nonnegative_integer(context.get("dbg_source_revision")) \
			or not _is_nonnegative_integer(
				context.get("asset_source_revision")
			) \
			or not _is_nonnegative_integer(
				context.get("batch_source_revision")
			) \
			or context.get("asset_source_revision") \
				!= context.get("batch_source_revision"):
		return "authorization_component_revision_invalid"
	for field in [
		"track_observation_fingerprint",
		"dbg_observation_fingerprint",
		"asset_observation_fingerprint",
		"batch_observation_fingerprint",
		"solar_observation_fingerprint",
	]:
		if not CODEC.is_fingerprint(context.get(field)):
			return "authorization_source_fingerprint_invalid"
	return ""


static func _authorization_identity_reason(
	match_instance_id: String,
	match_generation: int,
	viewer_id: String,
	authorization_revision: int,
	source_revision: int
) -> String:
	if not _is_stable_id(match_instance_id):
		return "match_instance_id_invalid"
	if not _is_positive_integer(match_generation):
		return "match_generation_invalid"
	if not _is_stable_id(viewer_id):
		return "viewer_id_invalid"
	if not _is_positive_integer(authorization_revision):
		return "authorization_revision_invalid"
	if not _is_nonnegative_integer(source_revision):
		return "source_revision_invalid"
	return ""


static func _source_binding_reason(
	context: Dictionary,
	sources: Dictionary
) -> String:
	var track := sources.get("unified_track", {}) as Dictionary
	var dbg := sources.get("personal_dbg", {}) as Dictionary
	var assets := sources.get("six_color_assets", {}) as Dictionary
	var batch := sources.get("card_batch", {}) as Dictionary
	var solar := sources.get("solar_victory", {}) as Dictionary
	if track.get("source_revision") != context.get("track_source_revision"):
		return "track_source_revision_stale"
	if dbg.get("revision") != context.get("dbg_source_revision"):
		return "dbg_source_revision_stale"
	if assets.get("state_revision") != context.get("asset_source_revision"):
		return "asset_source_revision_stale"
	if batch.get("state_revision") != context.get("batch_source_revision"):
		return "batch_source_revision_stale"
	if track.get("projection_fingerprint") \
			!= context.get("track_observation_fingerprint"):
		return "track_observation_forged"
	if CODEC.fingerprint(dbg) != context.get("dbg_observation_fingerprint"):
		return "dbg_observation_forged"
	if assets.get("projection_fingerprint") \
			!= context.get("asset_observation_fingerprint"):
		return "asset_observation_forged"
	if batch.get("projection_fingerprint") \
			!= context.get("batch_observation_fingerprint"):
		return "batch_observation_forged"
	if CODEC.fingerprint(solar) != context.get("solar_observation_fingerprint"):
		return "solar_observation_forged"
	return ""


static func _source_bundle_reason(sources: Dictionary, viewer_id: String) -> String:
	if not CODEC.is_pure_data(sources) \
			or not CODEC.has_exact_fields(sources, SOURCE_BUNDLE_FIELDS):
		return "source_bundle_fields_invalid"
	for field in SOURCE_BUNDLE_FIELDS:
		if not (sources.get(field) is Dictionary):
			return "source_bundle_observation_invalid"
	var track := sources.get("unified_track", {}) as Dictionary
	var track_reason := _track_observation_reason(track, viewer_id)
	if not track_reason.is_empty():
		return track_reason
	var dbg := sources.get("personal_dbg", {}) as Dictionary
	var dbg_reason := _dbg_observation_reason(dbg, viewer_id)
	if not dbg_reason.is_empty():
		return dbg_reason
	var assets := sources.get("six_color_assets", {}) as Dictionary
	var asset_report := ASSET_BATCH_CORE.domain_contract_validation_report(
		assets,
		ASSET_BATCH_CORE.ASSET_AI_OBSERVATION_ID
	)
	if not bool(asset_report.get("valid", false)):
		return "asset_%s" % str(asset_report.get(
			"reason_code",
			"observation_invalid"
		))
	var batch := sources.get("card_batch", {}) as Dictionary
	var batch_report := ASSET_BATCH_CORE.domain_contract_validation_report(
		batch,
		ASSET_BATCH_CORE.BATCH_AI_OBSERVATION_ID
	)
	if not bool(batch_report.get("valid", false)):
		return "batch_%s" % str(batch_report.get(
			"reason_code",
			"observation_invalid"
		))
	if str(assets.get("viewer_id", "")) != viewer_id \
			or str(batch.get("viewer_id", "")) != viewer_id:
		return "rival_observation_rejected"
	if assets.get("state_revision") != batch.get("state_revision"):
		return "asset_batch_revision_mismatch"
	if assets.get("own_reservations") != batch.get("own_reserved_costs"):
		return "asset_batch_reservation_mismatch"
	if assets.get("public_costs") != _public_costs_from_batch(batch):
		return "asset_batch_cost_mismatch"
	var solar_reason := _solar_observation_reason(
		sources.get("solar_victory", {}) as Dictionary
	)
	if not solar_reason.is_empty():
		return solar_reason
	if _contains_key_recursive(track, TRACK_FORBIDDEN_KEYS) \
			or _contains_key_recursive(dbg, DBG_FORBIDDEN_KEYS) \
			or _contains_key_recursive(assets, ASSET_BATCH_FORBIDDEN_KEYS) \
			or _contains_key_recursive(batch, ASSET_BATCH_FORBIDDEN_KEYS) \
			or _contains_key_recursive(
				sources.get("solar_victory"),
				SOLAR_FORBIDDEN_KEYS
			) \
			or _contains_key_recursive(sources, SOURCE_FORBIDDEN_KEYS):
		return "source_private_field_forbidden"
	return ""


static func _track_observation_reason(
	observation: Dictionary,
	viewer_id: String
) -> String:
	if not CODEC.is_pure_data(observation) \
			or not CODEC.has_exact_fields(observation, TRACK_OBSERVATION_FIELDS):
		return "track_observation_fields_invalid"
	if observation.get("schema_version") != TRACK_CORE.SCHEMA_VERSION \
			or str(observation.get("interface_id", "")) \
				!= TRACK_CORE.AI_INTERFACE_ID \
			or str(observation.get("ruleset_id", "")) != TRACK_CORE.RULESET_ID \
			or observation.get("state_version") != TRACK_CORE.STATE_VERSION \
			or str(observation.get("balance_profile_id", "")) \
				!= TRACK_CORE.BALANCE_PROFILE_ID \
			or str(observation.get("balance_profile_fingerprint", "")) \
				!= TRACK_CORE.BALANCE_PROFILE_FINGERPRINT \
			or str(observation.get("domain_id", "")) != TRACK_CORE.DOMAIN_ID:
		return "track_observation_identity_invalid"
	if not _is_positive_integer(observation.get("source_revision")) \
			or not _is_stable_id(observation.get("viewer_actor_id")) \
			or str(observation.get("viewer_actor_id", "")) != viewer_id:
		return "track_viewer_binding_invalid"
	if not (observation.get("public_facts") is Dictionary) \
			or not (observation.get("viewer_private_facts") is Dictionary):
		return "track_observation_facts_invalid"
	var public_facts := observation.get("public_facts", {}) as Dictionary
	var private_facts := observation.get("viewer_private_facts", {}) as Dictionary
	var public_reason := _track_public_facts_reason(public_facts)
	if not public_reason.is_empty():
		return public_reason
	var private_reason := _track_private_facts_reason(
		private_facts,
		int(public_facts.get("track_revision", -1)),
		int(public_facts.get("scroll_sequence", -1)),
		int(public_facts.get("unified_track_item_count", -1))
	)
	if not private_reason.is_empty():
		return private_reason
	var source_facts := {
		"schema_version": observation.get("schema_version"),
		"domain_id": observation.get("domain_id"),
		"source_revision": observation.get("source_revision"),
		"viewer_actor_id": observation.get("viewer_actor_id"),
		"public_facts": public_facts,
		"viewer_private_facts": private_facts,
	}
	if not CODEC.is_fingerprint(observation.get("source_core_fingerprint")) \
			or observation.get("source_core_fingerprint") \
				!= TRACK_CORE.fingerprint(source_facts):
		return "track_source_fingerprint_invalid"
	if not CODEC.is_fingerprint(observation.get("projection_fingerprint")) \
			or observation.get("projection_fingerprint") \
				!= TRACK_CORE.fingerprint(
					observation,
					"projection_fingerprint"
				):
		return "track_observation_fingerprint_invalid"
	return ""


static func _track_public_facts_reason(facts: Dictionary) -> String:
	if not CODEC.has_exact_fields(facts, TRACK_PUBLIC_FACT_FIELDS) \
			or facts.get("single_unified_track") != true \
			or facts.get("allowed_card_kinds") != CARD_KIND_IDS \
			or not _is_positive_integer(facts.get("track_revision")) \
			or not _is_nonnegative_integer(facts.get("scroll_sequence")) \
			or not _is_nonnegative_integer(
				facts.get("unified_track_item_count")
			) \
			or str(facts.get("balance_profile_id", "")) \
				!= TRACK_CORE.BALANCE_PROFILE_ID \
			or str(facts.get("balance_profile_fingerprint", "")) \
				!= TRACK_CORE.BALANCE_PROFILE_FINGERPRINT \
			or not _is_positive_integer(facts.get("color_cycle_number")) \
			or not _is_nonnegative_integer(facts.get("completed_batch_count")) \
			or not _is_nonnegative_integer(facts.get("lead_batch_cursor")) \
			or not _is_positive_integer(facts.get("lead_tenure_batches")) \
			or int(facts.get("lead_batch_cursor", -1)) \
				>= int(facts.get("lead_tenure_batches", 0)) \
			or not _is_nonnegative_integer(facts.get("color_cycle_batch_cursor")) \
			or not _is_positive_integer(facts.get("color_cycle_batches")) \
			or int(facts.get("color_cycle_batch_cursor", -1)) \
				>= int(facts.get("color_cycle_batches", 0)) \
			or facts.get("lead_identity_not_directly_published") != true \
			or facts.get("lead_identity_may_be_inferred_from_public_information") \
				!= true:
		return "track_public_facts_invalid"
	if not _integer_map_valid(
		facts.get("card_kind_ratio_basis_points"),
		CARD_KIND_IDS,
		10000
	) or not _integer_map_valid(
		facts.get("color_distribution_basis_points"),
		COLOR_IDS,
		10000
	):
		return "track_public_distribution_invalid"
	var revealed_variant: Variant = facts.get("revealed_stances")
	if not (revealed_variant is Array):
		return "track_revealed_stances_invalid"
	var seen_actors: Array[String] = []
	for stance_variant in revealed_variant as Array:
		if not (stance_variant is Dictionary):
			return "track_revealed_stances_invalid"
		var stance := stance_variant as Dictionary
		var actor_id := str(stance.get("actor_id", ""))
		var increase_color := str(stance.get("increase_color", ""))
		var decrease_color := str(stance.get("decrease_color", ""))
		if not CODEC.has_exact_fields(stance, TRACK_REVEALED_STANCE_FIELDS) \
				or not _is_stable_id(actor_id) \
				or seen_actors.has(actor_id) \
				or increase_color not in COLOR_IDS \
				or decrease_color not in COLOR_IDS \
				or increase_color == decrease_color:
			return "track_revealed_stances_invalid"
		seen_actors.append(actor_id)
	return ""


static func _track_private_facts_reason(
	facts: Dictionary,
	track_revision: int,
	scroll_sequence: int,
	total_item_count: int
) -> String:
	if not CODEC.has_exact_fields(facts, TRACK_PRIVATE_FACT_FIELDS) \
			or not (facts.get("own_segment_items") is Array) \
			or not (facts.get("own_pending_stance") is Dictionary) \
			or not (facts.get("self_is_current_lead") is bool) \
			or str(facts.get("self_influence_class", "")) \
				not in ["normal", "double"] \
			or bool(facts.get("self_is_current_lead", false)) \
				!= (str(facts.get("self_influence_class", "")) == "double"):
		return "track_private_facts_invalid"
	var items := facts.get("own_segment_items") as Array
	if items.size() > total_item_count:
		return "track_segment_item_count_invalid"
	var instance_ids: Array[String] = []
	var local_slots: Array[int] = []
	for item_variant in items:
		if not (item_variant is Dictionary):
			return "track_segment_item_invalid"
		var item := item_variant as Dictionary
		var instance_id := str(item.get("instance_id", ""))
		var local_slot := int(item.get("local_slot_index", -1))
		var claimable_from := int(item.get("claimable_from_scroll_sequence", -1))
		var claimable := bool(item.get("claimable", false))
		if not CODEC.has_exact_fields(item, TRACK_ITEM_FIELDS) \
				or not _is_stable_id(instance_id) \
				or not _is_stable_id(item.get("card_definition_id")) \
				or str(item.get("card_kind", "")) not in CARD_KIND_IDS \
				or item.get("level") != TRACK_CORE.TRACK_ITEM_LEVEL \
				or str(item.get("primary_color", "")) not in COLOR_IDS \
				or not _is_nonnegative_integer(item.get("local_slot_index")) \
				or item.get("track_revision") != track_revision \
				or not _is_nonnegative_integer(
					item.get("claimable_from_scroll_sequence")
				) \
				or not (item.get("claimable") is bool) \
				or claimable != (scroll_sequence >= claimable_from) \
				or str(item.get("claimability_state", "")) \
					!= ("claimable" if claimable else "incoming_locked") \
				or instance_ids.has(instance_id) \
				or local_slots.has(local_slot):
			return "track_segment_item_invalid"
		instance_ids.append(instance_id)
		local_slots.append(local_slot)
	var pending := facts.get("own_pending_stance", {}) as Dictionary
	if pending.is_empty():
		return ""
	if not CODEC.has_exact_fields(pending, TRACK_PENDING_STANCE_FIELDS):
		return "track_pending_stance_invalid"
	var increase_color := str(pending.get("increase_color", ""))
	var decrease_color := str(pending.get("decrease_color", ""))
	if increase_color not in COLOR_IDS \
			or decrease_color not in COLOR_IDS \
			or increase_color == decrease_color:
		return "track_pending_stance_invalid"
	return ""


static func _dbg_observation_reason(
	observation: Dictionary,
	viewer_id: String
) -> String:
	if not DBG_CORE.projection_is_private_safe(observation) \
			or str(observation.get("schema_id", "")) \
				!= DBG_CORE.AI_OBSERVATION_SCHEMA_ID \
			or str(observation.get("domain_id", "")) != DBG_CORE.DOMAIN_ID \
			or str(observation.get("visibility_scope", "")) != "actor_private":
		return "dbg_observation_invalid"
	var facts := observation.get("facts", {}) as Dictionary
	var owner_reason := _dbg_owner_binding_reason(facts, viewer_id)
	if not owner_reason.is_empty():
		return owner_reason
	if _contains_key_recursive(observation, DBG_FORBIDDEN_KEYS):
		return "dbg_observation_private_field_forbidden"
	return ""


static func _dbg_owner_binding_reason(
	facts: Dictionary,
	viewer_id: String
) -> String:
	var normal_prefix := "dbg.%s." % viewer_id
	for zone in ["hand", "discard"]:
		for card_variant in facts.get(zone, []) as Array:
			if not (card_variant is Dictionary) \
					or not str((card_variant as Dictionary).get(
						"instance_id",
						""
					)).begins_with(normal_prefix):
				return "dbg_rival_observation_rejected"
	var commodity_prefix := "commodity.%s." % viewer_id
	for commodity_variant in facts.get("commodity_inventory", []) as Array:
		if not (commodity_variant is Dictionary) \
				or not str((commodity_variant as Dictionary).get(
					"instance_id",
					""
				)).begins_with(commodity_prefix):
			return "dbg_rival_observation_rejected"
	return ""


static func _solar_observation_reason(observation: Dictionary) -> String:
	if not CODEC.is_pure_data(observation) \
			or not CODEC.has_exact_fields(
				observation,
				SOLAR_OBSERVATION_FIELDS
			) \
			or observation.get("schema_version") != SOLAR_CORE.SCHEMA_VERSION \
			or str(observation.get("ruleset_id", "")) != SOLAR_CORE.RULESET_ID \
			or str(observation.get("observation_id", "")) \
				!= SOLAR_CORE.AI_INTERFACE_ID \
			or not (observation.get("victory_pending") is bool) \
			or not (observation.get("final_settlement_committed") is bool) \
			or not _is_positive_integer(observation.get("macro_round_index")):
		return "solar_observation_invalid"
	var phase := str(observation.get("solar_phase_id", ""))
	var multiplier: Variant = observation.get("facility_work_rate_multiplier")
	if not (multiplier is float) or not is_finite(float(multiplier)):
		return "solar_observation_multiplier_invalid"
	if phase == "sunlit" and float(multiplier) == SOLAR_CORE.SUNLIT_MULTIPLIER:
		return ""
	if phase == "dark" and float(multiplier) == SOLAR_CORE.DARK_MULTIPLIER:
		return ""
	return "solar_observation_phase_invalid"


static func _integer_map_valid(
	value: Variant,
	keys: Array,
	expected_total: int
) -> bool:
	if not (value is Dictionary):
		return false
	var values := value as Dictionary
	if not CODEC.has_exact_fields(values, keys):
		return false
	var total := 0
	for key in keys:
		if not _is_nonnegative_integer(values.get(key)):
			return false
		total += int(values.get(key, 0))
	return total == expected_total


static func _public_costs_from_batch(batch: Dictionary) -> Array:
	var result: Array = []
	for action_variant in batch.get("own_local_queue", []) as Array:
		if not (action_variant is Dictionary):
			return []
		var action := action_variant as Dictionary
		result.append({
			"action_id": action.get("action_id"),
			"cost": (action.get("cost", {}) as Dictionary).duplicate(true),
			"any_payment": (
				action.get("any_payment", {}) as Dictionary
			).duplicate(true),
		})
	return result


static func _contains_key_recursive(
	value: Variant,
	forbidden_keys: Array
) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant).strip_edges().to_lower()
			if key in forbidden_keys \
					or _contains_key_recursive(
						(value as Dictionary).get(key_variant),
						forbidden_keys
					):
				return true
	elif value is Array:
		for item_variant in value as Array:
			if _contains_key_recursive(item_variant, forbidden_keys):
				return true
	return false


static func _is_stable_id(value: Variant) -> bool:
	if not (value is String):
		return false
	var text := value as String
	if text.is_empty() or text.length() > 160:
		return false
	var previous_was_separator := false
	for index in range(text.length()):
		var code := text.unicode_at(index)
		var lower := code >= 97 and code <= 122
		var digit := code >= 48 and code <= 57
		var separator := code in [45, 46, 95]
		if index == 0 and not lower:
			return false
		if not lower and not digit and not separator:
			return false
		if separator and previous_was_separator:
			return false
		previous_was_separator = separator
	return not previous_was_separator


static func _is_nonnegative_integer(value: Variant) -> bool:
	return value is int and int(value) >= 0


static func _is_positive_integer(value: Variant) -> bool:
	return _is_nonnegative_integer(value) and int(value) > 0


func _reject_binding(reason_code: String) -> bool:
	_bind_rejection_count += 1
	_last_reason_code = reason_code
	return false


func _reject_adaptation(reason_code: String) -> Dictionary:
	_adapt_rejection_count += 1
	_last_reason_code = reason_code
	return {}


static func _valid() -> Dictionary:
	return {"valid": true, "reason_code": "none"}


static func _invalid(reason_code: String) -> Dictionary:
	return {"valid": false, "reason_code": reason_code}
