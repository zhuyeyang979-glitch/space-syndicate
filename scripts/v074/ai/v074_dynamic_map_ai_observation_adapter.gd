extends RefCounted
class_name V074AIDynamicMapAdapter

## Read-only V0.7.4 adapter over public map facts and the acting AI's
## authorized private card actions. It builds detached indexes once and never
## owns gameplay state, RNG, Save data, or legal-action policy.

const CODEC := preload(
	"res://scripts/v07_adapters/v07_canonical_data_codec.gd"
)

const SCHEMA_VERSION := 1
const RULESET_ID := "v0.7.4"
const ADAPTER_ID := "v074.ai.dynamic_map_observation_adapter.v1"
const OBSERVATION_ID := "v074.ai.dynamic_map_observation.v1"
const PUBLIC_VISIBILITY_SCOPE_ID := "public"
const ACTOR_VISIBILITY_SCOPE_ID := "actor_private"
const OBSERVATION_VISIBILITY_SCOPE_ID := "ai_actor_authorized_plus_public"

const SUPPORTED_REGION_COUNT_MIN := 6
const SUPPORTED_REGION_COUNT_MAX := 30
const TERRAIN_CLASSES := ["land", "ocean"]
const SOLAR_STATES := ["sunlit", "dark"]
const FACILITY_TYPES := ["factory", "market", "warehouse"]
const INDUSTRY_IDS := [
	"life",
	"energy",
	"industry",
	"technology",
	"commerce",
	"shipping",
]
const ACTION_MODES := ["BUILD_NEW", "UPGRADE_OWN", "REPAIR_OWN"]


const PUBLIC_PROJECTION_FIELDS := [
	"schema_version",
	"projection_id",
	"ruleset_id",
	"visibility_scope_id",
	"source_revision",
	"map_id",
	"map_fingerprint",
	"region_count",
	"region_ids",
	"terrain_by_region",
	"adjacency_graph",
	"sunlight_by_region",
	"public_facility_slots",
	"projection_fingerprint",
]
const ACTOR_PROJECTION_FIELDS := [
	"schema_version",
	"projection_id",
	"ruleset_id",
	"visibility_scope_id",
	"source_revision",
	"map_id",
	"map_fingerprint",
	"viewer_id",
	"own_cards",
	"authorized_legal_actions",
	"projection_fingerprint",
]
const PUBLIC_SLOT_FIELDS := [
	"slot_id",
	"region_id",
	"facility_type",
	"industry_id",
	"occupied",
	"facility_id",
	"owner_id",
	"rank",
	"damage_points",
	"damage_revision",
	"facility_generation",
	"slot_generation",
	"solar_efficiency_state",
	"public_capacity",
	"public_ingress_throughput",
	"public_egress_throughput",
]
const OWN_CARD_FIELDS := [
	"card_instance_id",
	"card_definition_id",
	"facility_type",
	"industry_id",
	"rank",
]
const LEGAL_ACTION_FIELDS := [
	"card_instance_id",
	"card_definition_id",
	"facility_type",
	"industry_id",
	"action_mode",
	"target_slot_id",
	"region_id",
]
const INDEX_FIELDS := [
	"slots_by_facility_type_and_industry",
	"regions_by_terrain",
	"neighbors_by_region",
	"legal_targets_by_card_definition",
	"warehouse_slots_by_industry",
]
const INDEX_STATS_FIELDS := [
	"region_count",
	"facility_slot_count",
	"legal_action_count",
	"public_slot_index_build_count",
	"query_full_slot_scan_count",
]
const OBSERVATION_FIELDS := [
	"schema_version",
	"observation_id",
	"adapter_id",
	"ruleset_id",
	"visibility_scope_id",
	"viewer_id",
	"source_revisions",
	"map_id",
	"map_fingerprint",
	"region_count",
	"region_ids",
	"terrain_by_region",
	"sunlight_by_region",
	"public_facility_slots",
	"own_cards",
	"indexes",
	"index_stats",
	"source_projection_fingerprints",
	"observation_fingerprint",
]

const FORBIDDEN_INFORMATION_KEYS := [
	"opponent_hand",
	"opponent_hands",
	"other_player_hand",
	"other_player_hands",
	"opponent_target",
	"opponent_targets",
	"other_player_targets",
	"private_stock",
	"warehouse_stock",
	"warehouse_inventory",
	"stock_by_commodity",
	"private_logistics",
	"private_logistics_plan",
	"private_logistics_plans",
	"future_transport_plan",
	"future_transport_plans",
	"future_action",
	"future_actions",
	"ai_plan",
	"ai_plans",
	"rival_ai_state",
	"hidden_lead_order",
	"frozen_hidden_lead_order",
	"submission_hidden_lead_order",
	"private_assets",
	"opponent_assets",
	"authority_state",
	"authority_capability",
	"authorization_capability",
	"rng_state",
	"rng_seed",
	"map_genesis_rng",
	"save_payload",
]


var _last_observation: Dictionary = {}
var _adapt_attempt_count := 0
var _adapt_success_count := 0
var _adapt_rejection_count := 0
var _validation_count := 0
var _validation_failure_count := 0
var _indexed_legal_target_query_count := 0
var _last_reason_code := "adapter_unconfigured"


func adapt(
	actor_id: String,
	map_receipt: Dictionary,
	public_facilities: Dictionary,
	legal_targets: Dictionary,
	own_private_facts: Dictionary
) -> Dictionary:
	_adapt_attempt_count += 1
	_validation_count += 1
	var integration_reason := _integration_source_reason(
		actor_id,
		map_receipt,
		public_facilities,
		legal_targets,
		own_private_facts
	)
	if not integration_reason.is_empty():
		_validation_failure_count += 1
		return _reject_integration(integration_reason)
	var public_projection := _public_projection_from_sources(
		map_receipt,
		public_facilities
	)
	var actor_projection := _actor_projection_from_sources(
		actor_id,
		map_receipt,
		legal_targets,
		own_private_facts
	)
	var result := _adapt_projections(public_projection, actor_projection)
	if not bool(result.get("accepted", false)):
		_validation_failure_count += 1
		return _reject_integration(str(result.get(
			"reason_code",
			"adaptation_rejected"
		)))
	var observation_variant: Variant = result.get("observation")
	if not (observation_variant is Dictionary):
		_validation_failure_count += 1
		return _reject_integration("adaptation_observation_missing")
	_last_observation = (
		observation_variant as Dictionary
	).duplicate(true)
	_adapt_success_count += 1
	_last_reason_code = "dynamic_map_observation_adapted"
	return _last_observation.duplicate(true)


func indexed_legal_targets_for_card(
	card_definition_id: String
) -> Array:
	_indexed_legal_target_query_count += 1
	if not _is_stable_id(card_definition_id) 			or _last_observation.is_empty():
		return []
	return legal_targets_for_card(
		_last_observation,
		card_definition_id
	)


func indexed_slots_for_facility(
	facility_type: String,
	industry_id: String
) -> Array:
	if _last_observation.is_empty():
		return []
	return slots_for(
		_last_observation,
		facility_type,
		industry_id
	)


func debug_snapshot() -> Dictionary:
	var stats := (
		_last_observation.get("index_stats", {}) as Dictionary
		if _last_observation.get("index_stats") is Dictionary
		else {}
	)
	return {
		"adapter_id": ADAPTER_ID,
		"ruleset_id": RULESET_ID,
		"adapt_attempt_count": _adapt_attempt_count,
		"adapt_success_count": _adapt_success_count,
		"adapt_rejection_count": _adapt_rejection_count,
		"validation_count": _validation_count,
		"validation_failure_count": _validation_failure_count,
		"indexed_legal_target_query_count":
			_indexed_legal_target_query_count,
		"query_full_slot_scan_count": 0,
		"indexed_region_count": int(stats.get("region_count", 0)),
		"indexed_facility_slot_count": int(stats.get(
			"facility_slot_count",
			0
		)),
		"last_observation_fingerprint": str(
			_last_observation.get("observation_fingerprint", "")
		),
		"last_reason_code": _last_reason_code,
	}


func validation_counters() -> Dictionary:
	return {
		"adapt_attempt_count": _adapt_attempt_count,
		"adapt_success_count": _adapt_success_count,
		"adapt_rejection_count": _adapt_rejection_count,
		"validation_count": _validation_count,
		"validation_failure_count": _validation_failure_count,
		"indexed_legal_target_query_count":
			_indexed_legal_target_query_count,
		"query_full_slot_scan_count": 0,
	}


func detached_observation() -> Dictionary:
	return _last_observation.duplicate(true)


func _reject_integration(reason_code: String) -> Dictionary:
	_adapt_rejection_count += 1
	_last_reason_code = reason_code
	_last_observation = {}
	return {}


static func _integration_source_reason(
	actor_id: String,
	map_receipt: Dictionary,
	public_facilities: Dictionary,
	legal_targets: Dictionary,
	own_private_facts: Dictionary
) -> String:
	if not _is_stable_id(actor_id):
		return "actor_id_invalid"
	for source in [
		map_receipt,
		public_facilities,
		legal_targets,
		own_private_facts,
	]:
		if not CODEC.is_pure_data(source):
			return "integration_source_not_pure_data"
		if _contains_forbidden_key(source):
			return "integration_source_privacy_rejected"
	if str(own_private_facts.get("viewer_id", actor_id)) != actor_id:
		return "own_private_facts_viewer_mismatch"
	if not _is_stable_id(map_receipt.get("map_id")) 			or not CODEC.is_fingerprint(map_receipt.get(
				"map_fingerprint"
			)):
		return "map_receipt_binding_invalid"
	if str(map_receipt.get("ruleset_id", RULESET_ID)) != RULESET_ID:
		return "map_receipt_ruleset_invalid"
	if not (map_receipt.get("region_ids") is Array) 			or not (map_receipt.get("terrain_by_region") is Dictionary) 			or not (map_receipt.get("adjacency_graph") is Dictionary):
		return "map_receipt_projection_fields_missing"
	var slots := _first_array(
		public_facilities,
		["public_facility_slots", "slots"]
	)
	if slots.is_empty():
		return "public_facility_slots_missing"
	if not _has_array_field(
		own_private_facts,
		["own_cards", "cards"]
	):
		return "own_cards_missing"
	return ""


static func _public_projection_from_sources(
	map_receipt: Dictionary,
	public_facilities: Dictionary
) -> Dictionary:
	var region_ids := (
		map_receipt.get("region_ids", []) as Array
	).duplicate(true)
	var slots := _first_array(
		public_facilities,
		["public_facility_slots", "slots"]
	)
	var sunlight := _sunlight_from_sources(map_receipt, slots)
	var projection := {
		"schema_version": SCHEMA_VERSION,
		"projection_id": "v074.map.public_ai_projection.v1",
		"ruleset_id": RULESET_ID,
		"visibility_scope_id": PUBLIC_VISIBILITY_SCOPE_ID,
		"source_revision": _source_revision(
			public_facilities,
			_source_revision(map_receipt, 0)
		),
		"map_id": str(map_receipt.get("map_id", "")),
		"map_fingerprint": str(map_receipt.get(
			"map_fingerprint",
			""
		)),
		"region_count": int(map_receipt.get(
			"region_count",
			region_ids.size()
		)),
		"region_ids": region_ids,
		"terrain_by_region": (
			map_receipt.get("terrain_by_region", {}) as Dictionary
		).duplicate(true),
		"adjacency_graph": (
			map_receipt.get("adjacency_graph", {}) as Dictionary
		).duplicate(true),
		"sunlight_by_region": sunlight,
		"public_facility_slots": slots,
		"projection_fingerprint": "",
	}
	projection["projection_fingerprint"] = CODEC.fingerprint(
		projection,
		"projection_fingerprint"
	)
	return projection


static func _actor_projection_from_sources(
	actor_id: String,
	map_receipt: Dictionary,
	legal_targets: Dictionary,
	own_private_facts: Dictionary
) -> Dictionary:
	var projection := {
		"schema_version": SCHEMA_VERSION,
		"projection_id": "v074.map.actor_private_ai_projection.v1",
		"ruleset_id": RULESET_ID,
		"visibility_scope_id": ACTOR_VISIBILITY_SCOPE_ID,
		"source_revision": maxi(
			_source_revision(legal_targets, 0),
			_source_revision(own_private_facts, 0)
		),
		"map_id": str(map_receipt.get("map_id", "")),
		"map_fingerprint": str(map_receipt.get(
			"map_fingerprint",
			""
		)),
		"viewer_id": actor_id,
		"own_cards": _first_array(
			own_private_facts,
			["own_cards", "cards"]
		),
		"authorized_legal_actions":
			_legal_action_array(legal_targets),
		"projection_fingerprint": "",
	}
	projection["projection_fingerprint"] = CODEC.fingerprint(
		projection,
		"projection_fingerprint"
	)
	return projection


static func _sunlight_from_sources(
	map_receipt: Dictionary,
	slots: Array
) -> Dictionary:
	for field in [
		"sunlight_by_region",
		"solar_state_by_region",
		"solar_by_region",
	]:
		if map_receipt.get(field) is Dictionary:
			return (
				map_receipt.get(field, {}) as Dictionary
			).duplicate(true)
	var sunlight := {}
	for slot_variant in slots:
		if not (slot_variant is Dictionary):
			continue
		var slot := slot_variant as Dictionary
		var region_id := str(slot.get("region_id", ""))
		var solar_state := str(slot.get(
			"solar_efficiency_state",
			""
		))
		if not region_id.is_empty() and SOLAR_STATES.has(solar_state):
			sunlight[region_id] = solar_state
	return sunlight


static func _legal_action_array(source: Dictionary) -> Array:
	for field in ["authorized_legal_actions", "legal_actions"]:
		if source.get(field) is Array:
			return (source.get(field, []) as Array).duplicate(true)
	var keyed_variant: Variant = source.get(
		"legal_targets_by_card_definition"
	)
	var keyed := (
		keyed_variant as Dictionary
		if keyed_variant is Dictionary
		else source
	)
	var actions: Array = []
	for key_variant in keyed.keys():
		var definition_id := str(key_variant)
		var rows_variant: Variant = keyed.get(key_variant)
		if not (rows_variant is Array) 				or not _is_stable_id(definition_id):
			continue
		for row_variant in rows_variant as Array:
			if not (row_variant is Dictionary):
				continue
			var row := (row_variant as Dictionary).duplicate(true)
			if not row.has("card_definition_id"):
				row["card_definition_id"] = definition_id
			actions.append(row)
	return actions


static func _has_array_field(
	source: Dictionary,
	fields: Array
) -> bool:
	for field_variant in fields:
		if source.get(str(field_variant)) is Array:
			return true
	return false


static func _first_array(
	source: Dictionary,
	fields: Array
) -> Array:
	for field_variant in fields:
		var value: Variant = source.get(str(field_variant))
		if value is Array:
			return (value as Array).duplicate(true)
	return []


static func _source_revision(
	source: Dictionary,
	fallback: int
) -> int:
	var value: Variant = source.get("source_revision")
	return int(value) if value is int and int(value) >= 0 else fallback


static func _adapt_projections(
	public_projection: Dictionary,
	actor_projection: Dictionary
) -> Dictionary:
	var public_source := public_projection.duplicate(true)
	var actor_source := actor_projection.duplicate(true)
	var public_reason := _public_projection_reason(public_source)
	if not public_reason.is_empty():
		return _rejected(public_reason)
	var public_indexes := _build_public_indexes(public_source)
	var actor_reason := _actor_projection_reason(
		actor_source,
		public_source,
		public_indexes.get("_slot_lookup", {}) as Dictionary
	)
	if not actor_reason.is_empty():
		return _rejected(actor_reason)
	var legal_targets := _build_legal_target_index(actor_source)
	public_indexes.erase("_slot_lookup")
	public_indexes["legal_targets_by_card_definition"] = legal_targets
	_sort_index_arrays(public_indexes)

	var observation := CODEC.seal({
		"schema_version": SCHEMA_VERSION,
		"observation_id": OBSERVATION_ID,
		"adapter_id": ADAPTER_ID,
		"ruleset_id": RULESET_ID,
		"visibility_scope_id": OBSERVATION_VISIBILITY_SCOPE_ID,
		"viewer_id": str(actor_source.get("viewer_id", "")),
		"source_revisions": {
			"public_map": int(public_source.get("source_revision", -1)),
			"actor_private": int(actor_source.get("source_revision", -1)),
		},
		"map_id": str(public_source.get("map_id", "")),
		"map_fingerprint": str(public_source.get("map_fingerprint", "")),
		"region_count": int(public_source.get("region_count", 0)),
		"region_ids": (
			public_source.get("region_ids", []) as Array
		).duplicate(true),
		"terrain_by_region": (
			public_source.get("terrain_by_region", {}) as Dictionary
		).duplicate(true),
		"sunlight_by_region": (
			public_source.get("sunlight_by_region", {}) as Dictionary
		).duplicate(true),
		"public_facility_slots": (
			public_source.get("public_facility_slots", []) as Array
		).duplicate(true),
		"own_cards": (
			actor_source.get("own_cards", []) as Array
		).duplicate(true),
		"indexes": public_indexes,
		"index_stats": {
			"region_count": int(public_source.get("region_count", 0)),
			"facility_slot_count": (
				public_source.get("public_facility_slots", []) as Array
			).size(),
			"legal_action_count": (
				actor_source.get("authorized_legal_actions", []) as Array
			).size(),
			"public_slot_index_build_count": 1,
			"query_full_slot_scan_count": 0,
		},
		"source_projection_fingerprints": {
			"public_map": str(public_source.get(
				"projection_fingerprint",
				""
			)),
			"actor_private": str(actor_source.get(
				"projection_fingerprint",
				""
			)),
		},
	}, "observation_fingerprint")
	var report := validation_report(observation)
	if not bool(report.get("valid", false)):
		return _rejected(str(report.get(
			"reason_code",
			"observation_invalid"
		)))
	return {
		"accepted": true,
		"reason_code": "dynamic_map_observation_adapted",
		"observation": observation.duplicate(true),
	}


static func validation_report(value: Variant) -> Dictionary:
	if not (value is Dictionary) or not CODEC.is_pure_data(value):
		return _invalid("observation_not_pure_data")
	var observation := value as Dictionary
	if _contains_forbidden_key(observation):
		return _invalid("forbidden_information_disclosed")
	if not CODEC.has_exact_fields(observation, OBSERVATION_FIELDS):
		return _invalid("observation_fields_invalid")
	if observation.get("schema_version") != SCHEMA_VERSION 			or observation.get("ruleset_id") != RULESET_ID 			or observation.get("adapter_id") != ADAPTER_ID 			or observation.get("observation_id") != OBSERVATION_ID 			or observation.get("visibility_scope_id") 				!= OBSERVATION_VISIBILITY_SCOPE_ID:
		return _invalid("observation_identity_invalid")
	if not _is_stable_id(observation.get("viewer_id")) 			or not _is_stable_id(observation.get("map_id")) 			or not CODEC.is_fingerprint(observation.get("map_fingerprint")):
		return _invalid("observation_binding_invalid")
	if not (observation.get("source_revisions") is Dictionary) 			or not CODEC.has_exact_fields(
				observation.get("source_revisions", {}) as Dictionary,
				["public_map", "actor_private"]
			):
		return _invalid("source_revisions_invalid")
	if not (observation.get("indexes") is Dictionary) 			or not CODEC.has_exact_fields(
				observation.get("indexes", {}) as Dictionary,
				INDEX_FIELDS
			):
		return _invalid("observation_indexes_invalid")
	if not (observation.get("index_stats") is Dictionary) 			or not CODEC.has_exact_fields(
				observation.get("index_stats", {}) as Dictionary,
				INDEX_STATS_FIELDS
			):
		return _invalid("observation_index_stats_invalid")
	var stats := observation.get("index_stats", {}) as Dictionary
	if int(stats.get("public_slot_index_build_count", -1)) != 1 			or int(stats.get("query_full_slot_scan_count", -1)) != 0:
		return _invalid("observation_scan_contract_invalid")
	if not (observation.get("source_projection_fingerprints") is Dictionary):
		return _invalid("source_projection_fingerprints_invalid")
	var source_fingerprints := observation.get(
		"source_projection_fingerprints",
		{}
	) as Dictionary
	if not CODEC.has_exact_fields(
		source_fingerprints,
		["public_map", "actor_private"]
	) or not CODEC.is_fingerprint(source_fingerprints.get("public_map")) 			or not CODEC.is_fingerprint(source_fingerprints.get(
				"actor_private"
			)):
		return _invalid("source_projection_fingerprints_invalid")
	if not CODEC.is_fingerprint(observation.get("observation_fingerprint")) 			or str(observation.get("observation_fingerprint", "")) 				!= CODEC.fingerprint(observation, "observation_fingerprint"):
		return _invalid("observation_fingerprint_invalid")
	return _valid()


static func slots_for(
	observation: Dictionary,
	facility_type: String,
	industry_id: String
) -> Array:
	if not FACILITY_TYPES.has(facility_type) 			or not INDUSTRY_IDS.has(industry_id):
		return []
	return _index_array(
		observation,
		"slots_by_facility_type_and_industry",
		"%s|%s" % [facility_type, industry_id]
	)


static func regions_for_terrain(
	observation: Dictionary,
	terrain_class: String
) -> Array:
	if not TERRAIN_CLASSES.has(terrain_class):
		return []
	return _index_array(observation, "regions_by_terrain", terrain_class)


static func neighbors_for(
	observation: Dictionary,
	region_id: String
) -> Array:
	return _index_array(observation, "neighbors_by_region", region_id)


static func legal_targets_for_card(
	observation: Dictionary,
	card_definition_id: String
) -> Array:
	return _index_array(
		observation,
		"legal_targets_by_card_definition",
		card_definition_id
	)


static func warehouse_slots_for_industry(
	observation: Dictionary,
	industry_id: String
) -> Array:
	if not INDUSTRY_IDS.has(industry_id):
		return []
	return _index_array(
		observation,
		"warehouse_slots_by_industry",
		industry_id
	)


static func _public_projection_reason(source: Dictionary) -> String:
	if not CODEC.is_pure_data(source):
		return "public_projection_not_pure_data"
	if _contains_forbidden_key(source):
		return "forbidden_information_in_public_projection"
	if not CODEC.has_exact_fields(source, PUBLIC_PROJECTION_FIELDS):
		return "public_projection_fields_invalid"
	if source.get("schema_version") != SCHEMA_VERSION 			or source.get("ruleset_id") != RULESET_ID 			or source.get("visibility_scope_id") 				!= PUBLIC_VISIBILITY_SCOPE_ID:
		return "public_projection_identity_invalid"
	if not _is_stable_id(source.get("projection_id")) 			or not _is_stable_id(source.get("map_id")) 			or not _is_nonnegative_integer(source.get("source_revision")) 			or not CODEC.is_fingerprint(source.get("map_fingerprint")):
		return "public_projection_binding_invalid"
	if not _projection_fingerprint_valid(source):
		return "public_projection_fingerprint_invalid"
	var region_count := int(source.get("region_count", -1))
	if region_count < SUPPORTED_REGION_COUNT_MIN 			or region_count > SUPPORTED_REGION_COUNT_MAX:
		return "region_count_outside_supported_range"
	if not (source.get("region_ids") is Array):
		return "region_ids_invalid"
	var region_ids := source.get("region_ids", []) as Array
	if region_ids.size() != region_count:
		return "region_count_mismatch"
	var region_set := {}
	for region_variant in region_ids:
		var region_id := str(region_variant)
		if not _is_region_id(region_id) or region_set.has(region_id):
			return "region_identity_invalid"
		region_set[region_id] = true
	var terrain_reason := _terrain_reason(
		source.get("terrain_by_region"),
		region_set
	)
	if not terrain_reason.is_empty():
		return terrain_reason
	var adjacency_reason := _adjacency_reason(
		source.get("adjacency_graph"),
		region_ids,
		region_set
	)
	if not adjacency_reason.is_empty():
		return adjacency_reason
	var sunlight_reason := _sunlight_reason(
		source.get("sunlight_by_region"),
		region_set
	)
	if not sunlight_reason.is_empty():
		return sunlight_reason
	return _public_slots_reason(
		source.get("public_facility_slots"),
		region_count,
		region_set,
		source.get("sunlight_by_region", {}) as Dictionary
	)


static func _actor_projection_reason(
	source: Dictionary,
	public_source: Dictionary,
	slot_lookup: Dictionary
) -> String:
	if not CODEC.is_pure_data(source):
		return "actor_projection_not_pure_data"
	if _contains_forbidden_key(source):
		return "forbidden_information_in_actor_projection"
	if not CODEC.has_exact_fields(source, ACTOR_PROJECTION_FIELDS):
		return "actor_projection_fields_invalid"
	if source.get("schema_version") != SCHEMA_VERSION 			or source.get("ruleset_id") != RULESET_ID 			or source.get("visibility_scope_id") 				!= ACTOR_VISIBILITY_SCOPE_ID:
		return "actor_projection_identity_invalid"
	if not _is_stable_id(source.get("projection_id")) 			or not _is_stable_id(source.get("viewer_id")) 			or not _is_nonnegative_integer(source.get("source_revision")):
		return "actor_projection_binding_invalid"
	if source.get("map_id") != public_source.get("map_id") 			or source.get("map_fingerprint") 				!= public_source.get("map_fingerprint"):
		return "actor_map_binding_mismatch"
	if not _projection_fingerprint_valid(source):
		return "actor_projection_fingerprint_invalid"
	if not (source.get("own_cards") is Array) 			or not (source.get("authorized_legal_actions") is Array):
		return "actor_projection_collections_invalid"
	var cards_by_instance := {}
	for card_variant in source.get("own_cards", []) as Array:
		if not (card_variant is Dictionary):
			return "own_card_invalid"
		var card := card_variant as Dictionary
		if not CODEC.has_exact_fields(card, OWN_CARD_FIELDS) 				or not _is_stable_id(card.get("card_instance_id")) 				or not _is_stable_id(card.get("card_definition_id")) 				or not FACILITY_TYPES.has(card.get("facility_type")) 				or not INDUSTRY_IDS.has(card.get("industry_id")) 				or not _is_positive_integer(card.get("rank")):
			return "own_card_invalid"
		var instance_id := str(card.get("card_instance_id", ""))
		if cards_by_instance.has(instance_id):
			return "own_card_duplicate"
		cards_by_instance[instance_id] = card
	var action_keys := {}
	for action_variant in source.get("authorized_legal_actions", []) as Array:
		var action_reason := _legal_action_reason(
			action_variant,
			source,
			cards_by_instance,
			slot_lookup
		)
		if not action_reason.is_empty():
			return action_reason
		var action := action_variant as Dictionary
		var action_key := "%s|%s|%s" % [
			action.get("card_instance_id", ""),
			action.get("action_mode", ""),
			action.get("target_slot_id", ""),
		]
		if action_keys.has(action_key):
			return "authorized_legal_action_duplicate"
		action_keys[action_key] = true
	return ""


static func _terrain_reason(value: Variant, region_set: Dictionary) -> String:
	if not (value is Dictionary):
		return "terrain_by_region_invalid"
	var terrain_by_region := value as Dictionary
	if terrain_by_region.size() != region_set.size():
		return "terrain_region_count_mismatch"
	var land_count := 0
	var ocean_count := 0
	for region_id in region_set:
		if not terrain_by_region.has(region_id) 				or not TERRAIN_CLASSES.has(terrain_by_region.get(region_id)):
			return "terrain_region_invalid"
		if terrain_by_region.get(region_id) == "land":
			land_count += 1
		else:
			ocean_count += 1
	return "" if land_count > 0 and ocean_count > 0 else "terrain_mix_invalid"


static func _adjacency_reason(
	value: Variant,
	region_ids: Array,
	region_set: Dictionary
) -> String:
	if not (value is Dictionary):
		return "adjacency_graph_invalid"
	var graph := value as Dictionary
	if graph.size() != region_set.size():
		return "adjacency_region_count_mismatch"
	for region_id_variant in region_ids:
		var region_id := str(region_id_variant)
		if not (graph.get(region_id) is Array):
			return "adjacency_neighbors_invalid"
		var seen := {}
		for neighbor_variant in graph.get(region_id, []) as Array:
			var neighbor_id := str(neighbor_variant)
			if neighbor_id == region_id or not region_set.has(neighbor_id) 					or seen.has(neighbor_id):
				return "adjacency_edge_invalid"
			seen[neighbor_id] = true
			if not (graph.get(neighbor_id) is Array) 					or not (graph.get(neighbor_id, []) as Array).has(region_id):
				return "adjacency_asymmetric"
	if region_ids.is_empty():
		return "adjacency_graph_empty"
	var visited := {}
	var pending := [str(region_ids[0])]
	while not pending.is_empty():
		var current := str(pending.pop_back())
		if visited.has(current):
			continue
		visited[current] = true
		for neighbor_variant in graph.get(current, []) as Array:
			var neighbor_id := str(neighbor_variant)
			if not visited.has(neighbor_id):
				pending.append(neighbor_id)
	return "" if visited.size() == region_set.size() 		else "adjacency_graph_disconnected"


static func _sunlight_reason(value: Variant, region_set: Dictionary) -> String:
	if not (value is Dictionary):
		return "sunlight_by_region_invalid"
	var sunlight := value as Dictionary
	if sunlight.size() != region_set.size():
		return "sunlight_region_count_mismatch"
	for region_id in region_set:
		if not sunlight.has(region_id) 				or not SOLAR_STATES.has(sunlight.get(region_id)):
			return "sunlight_region_invalid"
	return ""


static func _public_slots_reason(
	value: Variant,
	region_count: int,
	region_set: Dictionary,
	sunlight_by_region: Dictionary
) -> String:
	if not (value is Array):
		return "public_facility_slots_invalid"
	var slots := value as Array
	var expected_count := (
		region_count * FACILITY_TYPES.size() * INDUSTRY_IDS.size()
	)
	if slots.size() != expected_count:
		return "facility_slot_count_mismatch"
	var slot_ids := {}
	var combination_keys := {}
	for slot_variant in slots:
		if not (slot_variant is Dictionary):
			return "public_facility_slot_invalid"
		var slot := slot_variant as Dictionary
		var reason := _public_slot_reason(
			slot,
			region_set,
			sunlight_by_region
		)
		if not reason.is_empty():
			return reason
		var slot_id := str(slot.get("slot_id", ""))
		var combination_key := "%s|%s|%s" % [
			slot.get("region_id", ""),
			slot.get("facility_type", ""),
			slot.get("industry_id", ""),
		]
		if slot_ids.has(slot_id) or combination_keys.has(combination_key):
			return "facility_slot_duplicate"
		slot_ids[slot_id] = true
		combination_keys[combination_key] = true
	return ""


static func _public_slot_reason(
	slot: Dictionary,
	region_set: Dictionary,
	sunlight_by_region: Dictionary
) -> String:
	if not CODEC.has_exact_fields(slot, PUBLIC_SLOT_FIELDS) 			or not _is_stable_id(slot.get("slot_id")) 			or not region_set.has(str(slot.get("region_id", ""))) 			or not FACILITY_TYPES.has(slot.get("facility_type")) 			or not INDUSTRY_IDS.has(slot.get("industry_id")) 			or not (slot.get("occupied") is bool):
		return "public_facility_slot_invalid"
	var region_id := str(slot.get("region_id", ""))
	if slot.get("solar_efficiency_state") != sunlight_by_region.get(region_id):
		return "facility_slot_solar_binding_invalid"
	for field in [
		"rank",
		"damage_points",
		"damage_revision",
		"facility_generation",
		"slot_generation",
		"public_capacity",
		"public_ingress_throughput",
		"public_egress_throughput",
	]:
		if not _is_nonnegative_integer(slot.get(field)):
			return "public_facility_slot_numeric_field_invalid"
	var occupied := bool(slot.get("occupied", false))
	if occupied:
		if not _is_stable_id(slot.get("facility_id")) 				or not _is_stable_id(slot.get("owner_id")) 				or int(slot.get("rank", 0)) <= 0:
			return "occupied_facility_identity_invalid"
	else:
		if not str(slot.get("facility_id", "")).is_empty() 				or not str(slot.get("owner_id", "")).is_empty() 				or int(slot.get("rank", -1)) != 0 				or int(slot.get("damage_points", -1)) != 0:
			return "vacant_facility_state_invalid"
	var is_warehouse: bool = str(slot.get("facility_type", "")) == "warehouse"
	if is_warehouse and occupied:
		if int(slot.get("public_capacity", 0)) <= 0:
			return "warehouse_public_capacity_invalid"
	elif not is_warehouse or not occupied:
		if int(slot.get("public_capacity", -1)) != 0 				or int(slot.get("public_ingress_throughput", -1)) != 0 				or int(slot.get("public_egress_throughput", -1)) != 0:
			return "nonwarehouse_private_storage_semantics_detected"
	return ""


static func _legal_action_reason(
	value: Variant,
	actor_source: Dictionary,
	cards_by_instance: Dictionary,
	slot_lookup: Dictionary
) -> String:
	if not (value is Dictionary):
		return "authorized_legal_action_invalid"
	var action := value as Dictionary
	if not CODEC.has_exact_fields(action, LEGAL_ACTION_FIELDS) 			or not ACTION_MODES.has(action.get("action_mode")):
		return "authorized_legal_action_invalid"
	var instance_id := str(action.get("card_instance_id", ""))
	var target_slot_id := str(action.get("target_slot_id", ""))
	if not cards_by_instance.has(instance_id) 			or not slot_lookup.has(target_slot_id):
		return "authorized_legal_action_reference_invalid"
	var card := cards_by_instance.get(instance_id, {}) as Dictionary
	var slot := slot_lookup.get(target_slot_id, {}) as Dictionary
	for field in ["card_definition_id", "facility_type", "industry_id"]:
		if action.get(field) != card.get(field):
			return "authorized_legal_action_card_binding_invalid"
	if action.get("facility_type") != slot.get("facility_type") 			or action.get("industry_id") != slot.get("industry_id") 			or action.get("region_id") != slot.get("region_id"):
		return "authorized_legal_action_slot_binding_invalid"
	var mode := str(action.get("action_mode", ""))
	var occupied := bool(slot.get("occupied", false))
	var viewer_id := str(actor_source.get("viewer_id", ""))
	if mode == "BUILD_NEW":
		return "" if not occupied else "build_target_occupied"
	if not occupied or str(slot.get("owner_id", "")) != viewer_id:
		return "own_facility_target_not_owned"
	if mode == "REPAIR_OWN" and int(slot.get("damage_points", 0)) <= 0:
		return "repair_target_not_damaged"
	if mode == "UPGRADE_OWN" and int(slot.get("damage_points", 0)) > 0:
		return "upgrade_target_requires_repair"
	return ""


static func _build_public_indexes(source: Dictionary) -> Dictionary:
	var slots_by_type_and_industry := {}
	var regions_by_terrain := {"land": [], "ocean": []}
	var neighbors_by_region := {}
	var warehouse_slots_by_industry := {}
	var slot_lookup := {}
	for facility_type in FACILITY_TYPES:
		for industry_id in INDUSTRY_IDS:
			slots_by_type_and_industry[
				"%s|%s" % [facility_type, industry_id]
			] = []
	for industry_id in INDUSTRY_IDS:
		warehouse_slots_by_industry[industry_id] = []
	var terrain := source.get("terrain_by_region", {}) as Dictionary
	var adjacency := source.get("adjacency_graph", {}) as Dictionary
	for region_variant in source.get("region_ids", []) as Array:
		var region_id := str(region_variant)
		(regions_by_terrain.get(
			str(terrain.get(region_id, "")),
			[]
		) as Array).append(region_id)
		neighbors_by_region[region_id] = (
			adjacency.get(region_id, []) as Array
		).duplicate(true)
	for slot_variant in source.get("public_facility_slots", []) as Array:
		var slot := slot_variant as Dictionary
		var slot_id := str(slot.get("slot_id", ""))
		var facility_type := str(slot.get("facility_type", ""))
		var industry_id := str(slot.get("industry_id", ""))
		(slots_by_type_and_industry.get(
			"%s|%s" % [facility_type, industry_id],
			[]
		) as Array).append(slot_id)
		if facility_type == "warehouse":
			(warehouse_slots_by_industry.get(
				industry_id,
				[]
			) as Array).append(slot_id)
		slot_lookup[slot_id] = slot
	return {
		"slots_by_facility_type_and_industry":
			slots_by_type_and_industry,
		"regions_by_terrain": regions_by_terrain,
		"neighbors_by_region": neighbors_by_region,
		"legal_targets_by_card_definition": {},
		"warehouse_slots_by_industry": warehouse_slots_by_industry,
		"_slot_lookup": slot_lookup,
	}


static func _build_legal_target_index(actor_source: Dictionary) -> Dictionary:
	var index := {}
	for card_variant in actor_source.get("own_cards", []) as Array:
		var card := card_variant as Dictionary
		index[str(card.get("card_definition_id", ""))] = []
	for action_variant in actor_source.get(
		"authorized_legal_actions",
		[]
	) as Array:
		var action := action_variant as Dictionary
		var definition_id := str(action.get("card_definition_id", ""))
		var target := {
			"card_instance_id": str(action.get("card_instance_id", "")),
			"card_definition_id": definition_id,
			"facility_type": str(action.get("facility_type", "")),
			"industry_id": str(action.get("industry_id", "")),
			"action_mode": str(action.get("action_mode", "")),
			"target_slot_id": str(action.get("target_slot_id", "")),
			"region_id": str(action.get("region_id", "")),
		}
		(index.get(definition_id, []) as Array).append(target)
	return index


static func _sort_index_arrays(indexes: Dictionary) -> void:
	for index_name in INDEX_FIELDS:
		var index_variant: Variant = indexes.get(index_name)
		if not (index_variant is Dictionary):
			continue
		for key_variant in (index_variant as Dictionary).keys():
			var values_variant: Variant = (
				index_variant as Dictionary
			).get(key_variant)
			if values_variant is Array:
				(values_variant as Array).sort_custom(
					func(left: Variant, right: Variant) -> bool:
						return CODEC.canonical_json(left) 							< CODEC.canonical_json(right)
				)


static func _index_array(
	observation: Dictionary,
	index_name: String,
	key: String
) -> Array:
	if not CODEC.has_exact_fields(observation, OBSERVATION_FIELDS) 			or not (observation.get("indexes") is Dictionary):
		return []
	var indexes := observation.get("indexes", {}) as Dictionary
	if not (indexes.get(index_name) is Dictionary):
		return []
	var index := indexes.get(index_name, {}) as Dictionary
	if not (index.get(key) is Array):
		return []
	return (index.get(key, []) as Array).duplicate(true)


static func _projection_fingerprint_valid(source: Dictionary) -> bool:
	return CODEC.is_fingerprint(source.get("projection_fingerprint")) 		and str(source.get("projection_fingerprint", "")) 			== CODEC.fingerprint(source, "projection_fingerprint")


static func _contains_forbidden_key(
	value: Variant,
	depth: int = 0
) -> bool:
	if depth > 96:
		return true
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant).to_lower()
			if FORBIDDEN_INFORMATION_KEYS.has(key) 					or _contains_forbidden_key(
						(value as Dictionary).get(key_variant),
						depth + 1
					):
				return true
	elif value is Array:
		for item_variant in value as Array:
			if _contains_forbidden_key(item_variant, depth + 1):
				return true
	return false


static func _is_region_id(value: String) -> bool:
	if not _is_stable_id(value) or not value.begins_with("region."):
		return false
	var final_segment := value.get_slice(
		".",
		value.get_slice_count(".") - 1
	)
	if final_segment.is_empty():
		return false
	for index in range(final_segment.length()):
		var code := final_segment.unicode_at(index)
		if code < 48 or code > 57:
			return false
	return true


static func _is_stable_id(value: Variant) -> bool:
	if not (value is String):
		return false
	var text := str(value)
	if text.is_empty() or text != text.strip_edges():
		return false
	for index in range(text.length()):
		var code := text.unicode_at(index)
		var allowed := (code >= 97 and code <= 122) 			or (code >= 48 and code <= 57) 			or code in [45, 46, 58, 95]
		if not allowed:
			return false
	return true


static func _is_nonnegative_integer(value: Variant) -> bool:
	return value is int and int(value) >= 0


static func _is_positive_integer(value: Variant) -> bool:
	return _is_nonnegative_integer(value) and int(value) > 0


static func _valid() -> Dictionary:
	return {"valid": true, "reason_code": "none"}


static func _invalid(reason_code: String) -> Dictionary:
	return {"valid": false, "reason_code": reason_code}


static func _rejected(reason_code: String) -> Dictionary:
	return {
		"accepted": false,
		"reason_code": reason_code,
		"observation": {},
	}
