extends RefCounted
class_name V07CanonicalPlayerProjectionAdapter

## Capability-gated, read-only adapter over detached V0.7.3 Player projections.
## The capability is transient object identity; it is never copied into wire data.

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
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

const SCHEMA_VERSION := 4
const RULESET_ID := "v0.7.3"
const ADAPTER_ID := "v073.canonical.player_projection_adapter.v4"
const PROJECTION_ID := "v073.canonical.player_projection.v4"
const VISIBILITY_SCOPE_ID := "viewer_authorized_plus_public"

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
	"contention_source_revision",
	"track_projection_fingerprint",
	"dbg_projection_fingerprint",
	"asset_projection_fingerprint",
	"batch_projection_fingerprint",
	"contention_projection_fingerprint",
]
const SOURCE_BUNDLE_FIELDS := [
	"unified_track",
	"personal_dbg",
	"six_color_assets",
	"card_batch",
	"facility_contention",
]
const COMPONENT_SOURCE_REVISION_FIELDS := [
	"unified_track",
	"personal_dbg",
	"six_color_assets",
	"card_batch",
	"facility_contention",
]
const CANONICAL_PROJECTION_FIELDS := [
	"schema_version",
	"projection_id",
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
	"facility_contention",
	"presentation_assets",
	"projection_fingerprint",
]

const PRESENTATION_ASSET_ENTRY_FIELDS := ["asset_key"]
const PLAYER_PRESENTATION_ASSET_KEYS := [
	"icon.asset.life",
	"icon.asset.energy",
	"icon.asset.industry",
	"icon.asset.technology",
	"icon.asset.commerce",
	"icon.asset.shipping",
	"card.frame.normal",
	"card.frame.commodity",
	"card.frame.bound_action",
	"card.back.normal",
	"card.badge.starter",
]
const CONTENTION_PROJECTION_FIELDS := [
	"schema_version", "state_version", "ruleset_id", "contract_id", "viewer_id",
	"batch_id", "state_revision", "own_local_queue", "anonymous_public_queue",
	"public_facility_slots", "resolution_cursor", "complete_hidden_order_disclosed",
	"projection_fingerprint",
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
const TRACK_PRIVATE_FACT_FIELDS := [
	"own_segment_items",
	"own_pending_stance",
	"self_lead_notice",
	"self_lead_notice_token",
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
const TRACK_NORMAL_ITEM_FIELDS := TRACK_ITEM_FIELDS + [
	"origin_class",
	"asset_cost_profile",
	"primary_asset_cost",
	"starter_badge",
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

const SOURCE_FORBIDDEN_KEYS := [
	"authority_capability",
	"authority_state",
	"future_supply_bags",
	"future_track_sequence",
	"hidden_lead_cycle_state",
	"hidden_lead_identity_and_order",
	"lock_fingerprint",
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
	"frozen_hidden_lead_order_at_batch_lock",
	"player_local_queues",
	"authority_queue",
	"resolution_receipts",
	"other_player_targets",
	"ai_plan",
	"ai_plans",
	"ai_score",
	"ai_scores",
]
const DBG_FORBIDDEN_KEYS := [
	"owner_player_id",
	"root_seed",
	"draw_pile",
	"discard_order",
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


class PlayerProjectionCapability:
	extends RefCounted


var _capability: RefCounted = null
var _authorization_context: Dictionary = {}
var _last_projection_fingerprint := ""
var _last_projection: Dictionary = {}
var _bind_count := 0
var _adapt_count := 0
var _duplicate_count := 0
var _bind_rejection_count := 0
var _adapt_rejection_count := 0
var _last_reason_code := "adapter_unconfigured"


func _init(capability: RefCounted = null) -> void:
	if capability is PlayerProjectionCapability:
		_capability = capability


static func issue_capability() -> RefCounted:
	return PlayerProjectionCapability.new()


static func build_authorization_context(
	match_instance_id: String,
	match_generation: int,
	viewer_id: String,
	authorization_revision: int,
	source_revision: int,
	unified_track_projection: Dictionary,
	personal_dbg_projection: Dictionary,
	six_color_asset_projection: Dictionary,
	card_batch_projection: Dictionary,
	facility_contention_projection: Dictionary
) -> Dictionary:
	var sources := {
		"unified_track": unified_track_projection,
		"personal_dbg": personal_dbg_projection,
		"six_color_assets": six_color_asset_projection,
		"card_batch": card_batch_projection,
		"facility_contention": facility_contention_projection,
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
			unified_track_projection.get("source_revision", -1)
		),
		"dbg_source_revision": int(personal_dbg_projection.get("revision", -1)),
		"asset_source_revision": int(
			six_color_asset_projection.get("state_revision", -1)
		),
		"batch_source_revision": int(
			card_batch_projection.get("state_revision", -1)
		),
		"contention_source_revision": int(
			facility_contention_projection.get("state_revision", -1)
		),
		"track_projection_fingerprint": str(
			unified_track_projection.get("projection_fingerprint", "")
		),
		"dbg_projection_fingerprint": WIRE.fingerprint(
			personal_dbg_projection
		),
		"asset_projection_fingerprint": str(
			six_color_asset_projection.get("projection_fingerprint", "")
		),
		"batch_projection_fingerprint": str(
			card_batch_projection.get("projection_fingerprint", "")
		),
		"contention_projection_fingerprint": str(
			facility_contention_projection.get("projection_fingerprint", "")
		),
	}


func bind_authorization(capability: RefCounted, context: Dictionary) -> bool:
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
		_last_projection_fingerprint = ""
		_last_projection = {}
	_bind_count += 1
	_last_reason_code = "authorization_bound"
	return true


func adapt_player_projection(
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
	var contention := sources.get("facility_contention", {}) as Dictionary
	var unsealed := {
		"schema_version": SCHEMA_VERSION,
		"projection_id": PROJECTION_ID,
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
			"facility_contention": int(contention.get("state_revision", -1)),
		},
		"unified_track": track.duplicate(true),
		"personal_dbg": dbg.duplicate(true),
		"six_color_assets": assets.duplicate(true),
		"card_batch": batch.duplicate(true),
		"facility_contention": contention.duplicate(true),
		"presentation_assets": presentation_asset_contract(),
	}
	var projection := CODEC.seal(unsealed, "projection_fingerprint")
	var validation := validation_report(projection)
	if not bool(validation.get("valid", false)):
		return _reject_adaptation(str(validation.get(
			"reason_code",
			"canonical_projection_invalid"
		)))
	var projection_fingerprint := str(
		projection.get("projection_fingerprint", "")
	)
	if not _last_projection_fingerprint.is_empty():
		if projection_fingerprint == _last_projection_fingerprint:
			_duplicate_count += 1
			_last_reason_code = "projection_duplicate"
			return detached_copy(_last_projection)
		return _reject_adaptation("bound_source_projection_conflict")
	_last_projection_fingerprint = projection_fingerprint
	_last_projection = projection.duplicate(true)
	_adapt_count += 1
	_last_reason_code = "projection_adapted"
	return detached_copy(projection)


func player_projection(
	capability: RefCounted,
	context: Dictionary,
	sources: Dictionary
) -> Dictionary:
	return adapt_player_projection(capability, context, sources)


static func presentation_asset_contract() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for asset_key in PLAYER_PRESENTATION_ASSET_KEYS:
		result.append({"asset_key": asset_key})
	return result


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
		"capability_is_projection_data": false,
	}


static func validation_report(value: Variant) -> Dictionary:
	if not (value is Dictionary) or not CODEC.is_pure_data(value):
		return _invalid("canonical_projection_not_closed_data")
	var projection := value as Dictionary
	if not WIRE.exact_fields(projection, CANONICAL_PROJECTION_FIELDS):
		return _invalid("canonical_projection_fields_invalid")
	if projection.get("schema_version") != SCHEMA_VERSION \
			or str(projection.get("projection_id", "")) != PROJECTION_ID \
			or str(projection.get("adapter_id", "")) != ADAPTER_ID \
			or str(projection.get("ruleset_id", "")) != RULESET_ID \
			or str(projection.get("visibility_scope_id", "")) \
				!= VISIBILITY_SCOPE_ID:
		return _invalid("canonical_projection_identity_invalid")
	var identity_reason := _authorization_identity_reason(
		str(projection.get("match_instance_id", "")),
		int(projection.get("match_generation", -1)),
		str(projection.get("viewer_id", "")),
		int(projection.get("authorization_revision", -1)),
		int(projection.get("source_revision", -1))
	)
	if not identity_reason.is_empty():
		return _invalid(identity_reason)
	var sources := {
		"unified_track": projection.get("unified_track"),
		"personal_dbg": projection.get("personal_dbg"),
		"six_color_assets": projection.get("six_color_assets"),
		"card_batch": projection.get("card_batch"),
		"facility_contention": projection.get("facility_contention"),
	}
	var source_reason := _source_bundle_reason(
		sources,
		str(projection.get("viewer_id", ""))
	)
	if not source_reason.is_empty():
		return _invalid(source_reason)
	var revisions_variant: Variant = projection.get("component_source_revisions")
	if not (revisions_variant is Dictionary):
		return _invalid("component_source_revisions_invalid")
	var revisions := revisions_variant as Dictionary
	if not WIRE.exact_fields(revisions, COMPONENT_SOURCE_REVISION_FIELDS) \
			or revisions.get("unified_track") \
				!= (sources.get("unified_track") as Dictionary).get("source_revision") \
			or revisions.get("personal_dbg") \
				!= (sources.get("personal_dbg") as Dictionary).get("revision") \
			or revisions.get("six_color_assets") \
				!= (sources.get("six_color_assets") as Dictionary).get("state_revision") \
			or revisions.get("card_batch") \
				!= (sources.get("card_batch") as Dictionary).get("state_revision") \
			or revisions.get("facility_contention") \
				!= (sources.get("facility_contention") as Dictionary).get(
					"state_revision"
				):
		return _invalid("component_source_revisions_mismatch")
	if WIRE.contains_key_recursive(sources, SOURCE_FORBIDDEN_KEYS):
		return _invalid("canonical_projection_private_field_forbidden")
	var presentation_reason := _presentation_assets_reason(
		projection.get("presentation_assets")
	)
	if not presentation_reason.is_empty():
		return _invalid(presentation_reason)
	if not WIRE.is_fingerprint(projection.get("projection_fingerprint")) \
			or str(projection.get("projection_fingerprint", "")) \
			!= CODEC.fingerprint(projection, "projection_fingerprint"):
		return _invalid("canonical_projection_fingerprint_invalid")
	return _valid()


static func _presentation_assets_reason(value: Variant) -> String:
	if not value is Array:
		return "presentation_assets_invalid"
	var entries := value as Array
	if entries.size() != PLAYER_PRESENTATION_ASSET_KEYS.size():
		return "presentation_asset_count_invalid"
	for index in entries.size():
		var entry_variant: Variant = entries[index]
		if not entry_variant is Dictionary:
			return "presentation_asset_entry_invalid"
		var entry := entry_variant as Dictionary
		if not WIRE.exact_fields(entry, PRESENTATION_ASSET_ENTRY_FIELDS) \
				or str(entry.get("asset_key", "")) \
					!= str(PLAYER_PRESENTATION_ASSET_KEYS[index]):
			return "presentation_asset_key_invalid"
	return ""


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
	var projection := value as Dictionary
	return str(projection.get("match_instance_id", "")) == match_instance_id \
		and int(projection.get("match_generation", -1)) == match_generation \
		and str(projection.get("viewer_id", "")) == viewer_id \
		and int(projection.get("authorization_revision", -1)) \
			== authorization_revision \
		and int(projection.get("source_revision", -1)) == source_revision


func _capability_matches(capability: RefCounted) -> bool:
	return _capability != null \
		and capability is PlayerProjectionCapability \
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
		"contention_source_revision",
		"track_projection_fingerprint",
		"dbg_projection_fingerprint",
		"asset_projection_fingerprint",
		"batch_projection_fingerprint",
		"contention_projection_fingerprint",
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
		"contention_source_revision",
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
		"contention_source_revision",
		"track_projection_fingerprint",
		"dbg_projection_fingerprint",
		"asset_projection_fingerprint",
		"batch_projection_fingerprint",
		"contention_projection_fingerprint",
	]:
		if context.get(field) != current.get(field):
			return "authorized_source_binding_mismatch"
	return ""


static func _authorization_context_reason(context: Dictionary) -> String:
	if not WIRE.is_closed_data(context) \
			or not WIRE.exact_fields(context, AUTHORIZATION_CONTEXT_FIELDS):
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
	if not WIRE.is_positive_integer(context.get("track_source_revision")) \
			or not WIRE.is_nonnegative_integer(context.get("dbg_source_revision")) \
			or not WIRE.is_nonnegative_integer(
				context.get("asset_source_revision")
			) \
			or not WIRE.is_nonnegative_integer(
				context.get("batch_source_revision")
			) \
			or not WIRE.is_nonnegative_integer(
				context.get("contention_source_revision")
			) \
			or context.get("asset_source_revision") \
				!= context.get("batch_source_revision"):
		return "authorization_component_revision_invalid"
	for field in [
		"track_projection_fingerprint",
		"dbg_projection_fingerprint",
		"asset_projection_fingerprint",
		"batch_projection_fingerprint",
		"contention_projection_fingerprint",
	]:
		if not WIRE.is_fingerprint(context.get(field)):
			return "authorization_source_fingerprint_invalid"
	return ""


static func _authorization_identity_reason(
	match_instance_id: String,
	match_generation: int,
	viewer_id: String,
	authorization_revision: int,
	source_revision: int
) -> String:
	if not WIRE.is_stable_id(match_instance_id):
		return "match_instance_id_invalid"
	if not WIRE.is_positive_integer(match_generation):
		return "match_generation_invalid"
	if not WIRE.is_stable_id(viewer_id):
		return "viewer_id_invalid"
	if not WIRE.is_positive_integer(authorization_revision):
		return "authorization_revision_invalid"
	if not WIRE.is_nonnegative_integer(source_revision):
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
	var contention := sources.get("facility_contention", {}) as Dictionary
	if track.get("source_revision") != context.get("track_source_revision"):
		return "track_source_revision_stale"
	if dbg.get("revision") != context.get("dbg_source_revision"):
		return "dbg_source_revision_stale"
	if assets.get("state_revision") != context.get("asset_source_revision"):
		return "asset_source_revision_stale"
	if batch.get("state_revision") != context.get("batch_source_revision"):
		return "batch_source_revision_stale"
	if contention.get("state_revision") != context.get("contention_source_revision"):
		return "contention_source_revision_stale"
	if track.get("projection_fingerprint") \
			!= context.get("track_projection_fingerprint"):
		return "track_projection_forged"
	if WIRE.fingerprint(dbg) != context.get("dbg_projection_fingerprint"):
		return "dbg_projection_forged"
	if assets.get("projection_fingerprint") \
			!= context.get("asset_projection_fingerprint"):
		return "asset_projection_forged"
	if batch.get("projection_fingerprint") \
			!= context.get("batch_projection_fingerprint"):
		return "batch_projection_forged"
	if contention.get("projection_fingerprint") \
			!= context.get("contention_projection_fingerprint"):
		return "contention_projection_forged"
	return ""


static func _source_bundle_reason(sources: Dictionary, viewer_id: String) -> String:
	if not CODEC.is_pure_data(sources) \
			or not WIRE.exact_fields(sources, SOURCE_BUNDLE_FIELDS):
		return "source_bundle_fields_invalid"
	for field in SOURCE_BUNDLE_FIELDS:
		if not (sources.get(field) is Dictionary):
			return "source_bundle_projection_invalid"
	var track := sources.get("unified_track", {}) as Dictionary
	var track_reason := _track_projection_reason(track, viewer_id)
	if not track_reason.is_empty():
		return track_reason
	var dbg := sources.get("personal_dbg", {}) as Dictionary
	var dbg_reason := _dbg_projection_reason(dbg, viewer_id)
	if not dbg_reason.is_empty():
		return dbg_reason
	var assets := sources.get("six_color_assets", {}) as Dictionary
	var asset_report := ASSET_BATCH_CORE.domain_contract_validation_report(
		assets,
		ASSET_BATCH_CORE.ASSET_PLAYER_PROJECTION_ID
	)
	if not bool(asset_report.get("valid", false)):
		return "asset_%s" % str(asset_report.get(
			"reason_code",
			"projection_invalid"
		))
	var batch := sources.get("card_batch", {}) as Dictionary
	var batch_report := ASSET_BATCH_CORE.domain_contract_validation_report(
		batch,
		ASSET_BATCH_CORE.BATCH_PLAYER_PROJECTION_ID
	)
	if not bool(batch_report.get("valid", false)):
		return "batch_%s" % str(batch_report.get(
			"reason_code",
			"projection_invalid"
		))
	if str(assets.get("viewer_id", "")) != viewer_id \
			or str(batch.get("viewer_id", "")) != viewer_id:
		return "rival_projection_rejected"
	if assets.get("state_revision") != batch.get("state_revision"):
		return "asset_batch_revision_mismatch"
	if assets.get("own_reservations") != batch.get("own_reserved_costs"):
		return "asset_batch_reservation_mismatch"
	if assets.get("public_costs") != _public_costs_from_batch(batch):
		return "asset_batch_cost_mismatch"
	var contention_reason := _facility_contention_projection_reason(
		sources.get("facility_contention", {}) as Dictionary,
		viewer_id
	)
	if not contention_reason.is_empty():
		return contention_reason
	if WIRE.contains_key_recursive(sources, SOURCE_FORBIDDEN_KEYS):
		return "source_private_field_forbidden"
	return ""


static func _facility_contention_projection_reason(
	projection: Dictionary,
	viewer_id: String
) -> String:
	if not WIRE.exact_fields(projection, CONTENTION_PROJECTION_FIELDS) \
			or not CODEC.is_pure_data(projection):
		return "facility_contention_projection_fields_invalid"
	if projection.get("schema_version") != 1 \
			or projection.get("state_version") != 1 \
			or projection.get("ruleset_id") != RULESET_ID \
			or projection.get("contract_id") \
				!= "v073.facility_contention.player_projection.v1" \
			or projection.get("viewer_id") != viewer_id \
			or projection.get("complete_hidden_order_disclosed") != false \
			or not (projection.get("own_local_queue") is Array) \
			or not (projection.get("anonymous_public_queue") is Array) \
			or not (projection.get("public_facility_slots") is Array) \
			or not (projection.get("resolution_cursor") is int):
		return "facility_contention_projection_identity_invalid"
	if not WIRE.is_fingerprint(projection.get("projection_fingerprint")) \
			or str(projection.get("projection_fingerprint", "")) \
				!= CODEC.fingerprint(projection, "projection_fingerprint"):
		return "facility_contention_projection_fingerprint_invalid"
	for public_entry_variant in projection.get("anonymous_public_queue") as Array:
		if not (public_entry_variant is Dictionary):
			return "facility_contention_public_queue_invalid"
		var public_entry := public_entry_variant as Dictionary
		if public_entry.has("actor_id") or public_entry.has("owner_id") \
				or public_entry.has("target_slot_id"):
			return "facility_contention_public_owner_or_target_disclosed"
	return ""


static func _dbg_projection_reason(
	projection: Dictionary,
	viewer_id: String
) -> String:
	if not DBG_CORE.projection_is_private_safe(projection) \
			or str(projection.get("schema_id", "")) \
				!= DBG_CORE.PLAYER_PROJECTION_SCHEMA_ID \
			or str(projection.get("domain_id", "")) != DBG_CORE.DOMAIN_ID \
			or str(projection.get("visibility_scope", "")) != "viewer_private":
		return "dbg_projection_invalid"
	var facts := projection.get("facts", {}) as Dictionary
	var normal_prefix := "dbg.%s." % viewer_id
	for zone in ["hand", "committed_escrow", "discard"]:
		for card_variant in facts.get(zone, []) as Array:
			if not (card_variant is Dictionary) \
					or not str((card_variant as Dictionary).get(
						"instance_id",
						""
					)).begins_with(normal_prefix):
				return "dbg_rival_projection_rejected"
	var commodity_prefix := "commodity.%s." % viewer_id
	for commodity_variant in facts.get("commodity_inventory", []) as Array:
		if not (commodity_variant is Dictionary) \
				or not str((commodity_variant as Dictionary).get(
					"instance_id",
					""
				)).begins_with(commodity_prefix):
			return "dbg_rival_projection_rejected"
	if WIRE.contains_key_recursive(projection, DBG_FORBIDDEN_KEYS):
		return "dbg_projection_private_field_forbidden"
	return ""


static func _track_projection_reason(
	projection: Dictionary,
	viewer_id: String
) -> String:
	if not WIRE.is_closed_data(projection) \
			or not WIRE.exact_fields(projection, TRACK_PROJECTION_FIELDS):
		return "track_projection_fields_invalid"
	if projection.get("schema_version") != TRACK_CORE.SCHEMA_VERSION \
			or str(projection.get("interface_id", "")) \
				!= TRACK_CORE.PLAYER_INTERFACE_ID \
			or str(projection.get("ruleset_id", "")) != TRACK_CORE.RULESET_ID \
			or projection.get("state_version") != TRACK_CORE.STATE_VERSION \
			or str(projection.get("balance_profile_id", "")) \
				!= TRACK_CORE.BALANCE_PROFILE_ID \
			or str(projection.get("balance_profile_fingerprint", "")) \
				!= TRACK_CORE.BALANCE_PROFILE_FINGERPRINT \
			or str(projection.get("domain_id", "")) != TRACK_CORE.DOMAIN_ID:
		return "track_projection_identity_invalid"
	if not WIRE.is_positive_integer(projection.get("source_revision")) \
			or not WIRE.is_stable_id(projection.get("viewer_actor_id")) \
			or str(projection.get("viewer_actor_id", "")) != viewer_id:
		return "track_viewer_binding_invalid"
	if not (projection.get("public_facts") is Dictionary) \
			or not (projection.get("viewer_private_facts") is Dictionary):
		return "track_projection_facts_invalid"
	var public_facts := projection.get("public_facts", {}) as Dictionary
	var private_facts := projection.get("viewer_private_facts", {}) as Dictionary
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
		"schema_version": projection.get("schema_version"),
		"domain_id": projection.get("domain_id"),
		"source_revision": projection.get("source_revision"),
		"viewer_actor_id": projection.get("viewer_actor_id"),
		"public_facts": public_facts,
		"viewer_private_facts": private_facts,
	}
	if not WIRE.is_fingerprint(projection.get("source_core_fingerprint")) \
			or projection.get("source_core_fingerprint") \
				!= WIRE.fingerprint(source_facts):
		return "track_source_fingerprint_invalid"
	if not WIRE.is_fingerprint(projection.get("projection_fingerprint")) \
			or projection.get("projection_fingerprint") \
				!= WIRE.fingerprint(projection, "projection_fingerprint"):
		return "track_projection_fingerprint_invalid"
	if WIRE.contains_key_recursive(projection, SOURCE_FORBIDDEN_KEYS):
		return "track_private_field_forbidden"
	return ""


static func _track_public_facts_reason(facts: Dictionary) -> String:
	if not WIRE.exact_fields(facts, TRACK_PUBLIC_FACT_FIELDS) \
			or facts.get("single_unified_track") != true \
			or facts.get("allowed_card_kinds") != CARD_KIND_IDS \
			or not WIRE.is_positive_integer(facts.get("track_revision")) \
			or not WIRE.is_nonnegative_integer(facts.get("scroll_sequence")) \
			or not WIRE.is_nonnegative_integer(
				facts.get("unified_track_item_count")
			) \
			or str(facts.get("balance_profile_id", "")) \
				!= TRACK_CORE.BALANCE_PROFILE_ID \
			or str(facts.get("balance_profile_fingerprint", "")) \
				!= TRACK_CORE.BALANCE_PROFILE_FINGERPRINT \
			or not WIRE.is_positive_integer(facts.get("color_cycle_number")) \
			or not WIRE.is_nonnegative_integer(facts.get("completed_batch_count")) \
			or not WIRE.is_nonnegative_integer(facts.get("lead_batch_cursor")) \
			or not WIRE.is_positive_integer(facts.get("lead_tenure_batches")) \
			or int(facts.get("lead_batch_cursor", -1)) \
				>= int(facts.get("lead_tenure_batches", 0)) \
			or not WIRE.is_nonnegative_integer(facts.get("color_cycle_batch_cursor")) \
			or not WIRE.is_positive_integer(facts.get("color_cycle_batches")) \
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
		if not WIRE.exact_fields(stance, TRACK_REVEALED_STANCE_FIELDS) \
				or not WIRE.is_stable_id(actor_id) \
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
	if not WIRE.exact_fields(facts, TRACK_PRIVATE_FACT_FIELDS) \
			or not (facts.get("own_segment_items") is Array) \
			or not (facts.get("own_pending_stance") is Dictionary) \
			or not (facts.get("self_lead_notice") is bool):
		return "track_private_facts_invalid"
	var lead_notice := bool(facts.get("self_lead_notice", false))
	var expected_token := "v072.lead.double_influence" if lead_notice else "none"
	if str(facts.get("self_lead_notice_token", "")) != expected_token:
		return "track_self_lead_notice_invalid"
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
		var target_v072_normal := TRACK_CORE.RULESET_ID == "v0.7.2" \
			and str(item.get("card_kind", "")) == "normal_card"
		var expected_fields := TRACK_NORMAL_ITEM_FIELDS \
			if target_v072_normal \
			else TRACK_ITEM_FIELDS
		if not WIRE.exact_fields(item, expected_fields) \
				or not WIRE.is_stable_id(instance_id) \
				or not WIRE.is_stable_id(item.get("card_definition_id")) \
				or str(item.get("card_kind", "")) not in CARD_KIND_IDS \
				or item.get("level") != TRACK_CORE.TRACK_ITEM_LEVEL \
				or str(item.get("primary_color", "")) not in COLOR_IDS \
				or not WIRE.is_nonnegative_integer(
					item.get("local_slot_index")
				) \
				or item.get("track_revision") != track_revision \
				or not WIRE.is_nonnegative_integer(
					item.get("claimable_from_scroll_sequence")
				) \
				or not (item.get("claimable") is bool) \
				or claimable != (scroll_sequence >= claimable_from) \
				or str(item.get("claimability_state", "")) \
					!= ("claimable" if claimable else "incoming_locked") \
				or instance_ids.has(instance_id) \
				or local_slots.has(local_slot):
			return "track_segment_item_invalid"
		if target_v072_normal \
				and (str(item.get("origin_class", "")) != "standard" \
				or str(item.get("asset_cost_profile", "")) != "standard_rank_1" \
				or int(item.get("primary_asset_cost", -1)) != 1 \
				or item.get("starter_badge") != false):
			return "track_normal_item_cost_semantics_invalid"
		instance_ids.append(instance_id)
		local_slots.append(local_slot)
	var pending := facts.get("own_pending_stance", {}) as Dictionary
	if pending.is_empty():
		return ""
	if not WIRE.exact_fields(pending, TRACK_PENDING_STANCE_FIELDS):
		return "track_pending_stance_invalid"
	var increase_color := str(pending.get("increase_color", ""))
	var decrease_color := str(pending.get("decrease_color", ""))
	if increase_color not in COLOR_IDS \
			or decrease_color not in COLOR_IDS \
			or increase_color == decrease_color:
		return "track_pending_stance_invalid"
	return ""


static func _integer_map_valid(
	value: Variant,
	keys: Array,
	expected_total: int
) -> bool:
	if not (value is Dictionary):
		return false
	var values := value as Dictionary
	if not WIRE.exact_fields(values, keys):
		return false
	var total := 0
	for key in keys:
		if not WIRE.is_nonnegative_integer(values.get(key)):
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
