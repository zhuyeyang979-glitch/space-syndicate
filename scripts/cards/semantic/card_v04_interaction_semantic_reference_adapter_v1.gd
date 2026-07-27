@tool
extends RefCounted
class_name CardV04InteractionSemanticReferenceAdapterV1

const CARD_SCHEMA := preload(
	"res://scripts/cards/semantic/card_semantic_schema_v1.gd"
)

const SCHEMA_VERSION := 1
const ADAPTER_ID := "card_v04_interaction_semantic_reference_v1"
const SOURCE_CATALOG_ID := "card_runtime_catalog_v04"
const REVIEWED_RUNTIME_ONLY_KEYS := [
	"card_id",
	"play_requirement_kind",
	"play_region_scope",
	"play_region_gdp_share_required",
	"supply_product",
	"use_case",
	"cooldown",
	"cooldown_left",
	"lock_left",
	"persistent",
	"queued_for_resolution",
	"runtime_instance_id",
	"counts_toward_hand_limit",
	"display_name",
]

# Exact SHA-256 identities for the eight reviewed v0.4 interaction card IDs.
# The adapter never parses a localized name or rank suffix.
const ENTRY_BY_LEGACY_ID_FINGERPRINT := {
	"5fb4535d1cc88a1ef94eb61123584b9d3f3877f14449c6def1f315bdb7b022d1": {
		"semantic_card_id": "interaction.starlink_dismantle.rank_1",
		"semantic_family_id": "interaction.starlink_dismantle",
		"semantic_rank": 1,
		"interaction_kind_id": "player_hand_disrupt",
	},
	"6bde0574c509fe021f385119d50e47f6e637fe633f8206c3ee5f694633581215": {
		"semantic_card_id": "interaction.starlink_dismantle.rank_2",
		"semantic_family_id": "interaction.starlink_dismantle",
		"semantic_rank": 2,
		"interaction_kind_id": "player_hand_disrupt",
	},
	"e162388ed17821f3a972e09a4483ee548e1f523c23fe200863c0dff5fbb151fe": {
		"semantic_card_id": "interaction.starlink_dismantle.rank_3",
		"semantic_family_id": "interaction.starlink_dismantle",
		"semantic_rank": 3,
		"interaction_kind_id": "player_hand_disrupt",
	},
	"049375e10ed990fc6195cdfdd4a46d3a038465398ce538680810f76afe0ca970": {
		"semantic_card_id": "interaction.starlink_dismantle.rank_4",
		"semantic_family_id": "interaction.starlink_dismantle",
		"semantic_rank": 4,
		"interaction_kind_id": "player_hand_disrupt",
	},
	"5d0ac6306835115dbdff9c6236bd530a55e44d7e35905bdf2994ead30c9c2a37": {
		"semantic_card_id": "interaction.shadow_warehouse_traction.rank_1",
		"semantic_family_id": "interaction.shadow_warehouse_traction",
		"semantic_rank": 1,
		"interaction_kind_id": "player_hand_steal",
	},
	"19a845ba97fc178ae46a8ae0b4f38677d1142eab8042ab39f762c9b6a227cdc2": {
		"semantic_card_id": "interaction.shadow_warehouse_traction.rank_2",
		"semantic_family_id": "interaction.shadow_warehouse_traction",
		"semantic_rank": 2,
		"interaction_kind_id": "player_hand_steal",
	},
	"9c9c76c6e245d411a2ae193cc2e87ef2df29065f7659ae434b79bd4d2750c756": {
		"semantic_card_id": "interaction.shadow_warehouse_traction.rank_3",
		"semantic_family_id": "interaction.shadow_warehouse_traction",
		"semantic_rank": 3,
		"interaction_kind_id": "player_hand_steal",
	},
	"71d597ba77c4d4beff36fc46a3320a5603ca6e892798ec04b8957990607c4ce0": {
		"semantic_card_id": "interaction.shadow_warehouse_traction.rank_4",
		"semantic_family_id": "interaction.shadow_warehouse_traction",
		"semantic_rank": 4,
		"interaction_kind_id": "player_hand_steal",
	},
}
const RESULT_KEYS := [
	"schema_version",
	"adapter_id",
	"source_catalog_id",
	"legacy_card_id_fingerprint",
	"legacy_definition",
	"legacy_definition_fingerprint",
	"semantic_card_id",
	"semantic_family_id",
	"semantic_rank",
	"interaction_kind_id",
	"mapping_fingerprint",
	"reference_fingerprint",
]
const WITNESS_REQUEST_KEYS := [
	"schema_version",
	"adapter_id",
	"source_catalog_id",
	"legacy_card_id_fingerprint",
	"legacy_definition_fingerprint",
	"semantic_card_id",
	"semantic_family_id",
	"semantic_rank",
	"interaction_kind_id",
	"mapping_fingerprint",
	"reference_fingerprint",
	"request_fingerprint",
]


static func resolve(
	runtime_card: Dictionary,
	source_card_id: String,
	legacy_catalog: CardRuntimeCatalogService
) -> Dictionary:
	if legacy_catalog == null \
			or source_card_id.is_empty() \
			or source_card_id != source_card_id.strip_edges() \
			or not CARD_SCHEMA.is_pure_data(runtime_card):
		return {}
	var legacy_card_id_fingerprint := source_card_id.sha256_text()
	var entry_value: Variant = ENTRY_BY_LEGACY_ID_FINGERPRINT.get(
		legacy_card_id_fingerprint
	)
	if not (entry_value is Dictionary):
		return {}
	var entry := entry_value as Dictionary
	var legacy_definition := legacy_catalog.exact_definition(source_card_id)
	if legacy_definition.is_empty() \
			or not CARD_SCHEMA.is_pure_data(legacy_definition) \
			or not _runtime_card_matches_definition(
				runtime_card,
				legacy_definition,
				source_card_id
			) \
			or str(legacy_definition.get("kind", "")) \
				!= str(entry.get("interaction_kind_id", "")):
		return {}
	var semantic_card_id := str(entry.get("semantic_card_id", ""))
	var legacy_definition_fingerprint := CARD_SCHEMA.fingerprint(
		legacy_definition
	)
	var mapping_fingerprint := _mapping_fingerprint(
		legacy_card_id_fingerprint,
		entry
	)
	if legacy_definition_fingerprint.is_empty() \
			or mapping_fingerprint.is_empty():
		return {}
	var result := {
		"schema_version": SCHEMA_VERSION,
		"adapter_id": ADAPTER_ID,
		"source_catalog_id": SOURCE_CATALOG_ID,
		"legacy_card_id_fingerprint": legacy_card_id_fingerprint,
		"legacy_definition": legacy_definition.duplicate(true),
		"legacy_definition_fingerprint": legacy_definition_fingerprint,
		"semantic_card_id": semantic_card_id,
		"semantic_family_id": str(entry.get("semantic_family_id", "")),
		"semantic_rank": int(entry.get("semantic_rank", 0)),
		"interaction_kind_id": str(entry.get("interaction_kind_id", "")),
		"mapping_fingerprint": mapping_fingerprint,
		"reference_fingerprint": "",
	}
	result["reference_fingerprint"] = CARD_SCHEMA.fingerprint(
		result,
		"reference_fingerprint"
	)
	if not CARD_SCHEMA.is_pure_data(result) \
			or not _has_exact_keys(result, RESULT_KEYS) \
			or str(result.get("reference_fingerprint", "")).is_empty():
		return {}
	return result.duplicate(true)


static func semantic_witness_request(reference: Dictionary) -> Dictionary:
	if not _valid_reference(reference):
		return {}
	var request := {
		"schema_version": SCHEMA_VERSION,
		"adapter_id": ADAPTER_ID,
		"source_catalog_id": SOURCE_CATALOG_ID,
		"legacy_card_id_fingerprint": str(reference.get(
			"legacy_card_id_fingerprint",
			""
		)),
		"legacy_definition_fingerprint": str(reference.get(
			"legacy_definition_fingerprint",
			""
		)),
		"semantic_card_id": str(reference.get("semantic_card_id", "")),
		"semantic_family_id": str(reference.get("semantic_family_id", "")),
		"semantic_rank": int(reference.get("semantic_rank", 0)),
		"interaction_kind_id": str(reference.get(
			"interaction_kind_id",
			""
		)),
		"mapping_fingerprint": str(reference.get("mapping_fingerprint", "")),
		"reference_fingerprint": str(reference.get(
			"reference_fingerprint",
			""
		)),
		"request_fingerprint": "",
	}
	request["request_fingerprint"] = CARD_SCHEMA.fingerprint(
		request,
		"request_fingerprint"
	)
	return request if validate_witness_request(request) else {}


static func validate_witness_request(request: Dictionary) -> bool:
	if not CARD_SCHEMA.is_pure_data(request) \
			or not _has_exact_keys(request, WITNESS_REQUEST_KEYS) \
			or request.get("schema_version") != SCHEMA_VERSION \
			or str(request.get("adapter_id", "")) != ADAPTER_ID \
			or str(request.get("source_catalog_id", "")) != SOURCE_CATALOG_ID:
		return false
	var legacy_fingerprint := str(request.get(
		"legacy_card_id_fingerprint",
		""
	))
	var entry_value: Variant = ENTRY_BY_LEGACY_ID_FINGERPRINT.get(
		legacy_fingerprint
	)
	if not (entry_value is Dictionary):
		return false
	var entry := entry_value as Dictionary
	if str(request.get("semantic_card_id", "")) \
			!= str(entry.get("semantic_card_id", "")) \
			or str(request.get("semantic_family_id", "")) \
				!= str(entry.get("semantic_family_id", "")) \
			or request.get("semantic_rank") != entry.get("semantic_rank") \
			or str(request.get("interaction_kind_id", "")) \
				!= str(entry.get("interaction_kind_id", "")) \
			or str(request.get("mapping_fingerprint", "")) \
				!= _mapping_fingerprint(legacy_fingerprint, entry):
		return false
	for field in [
		"legacy_card_id_fingerprint",
		"legacy_definition_fingerprint",
		"mapping_fingerprint",
		"reference_fingerprint",
		"request_fingerprint",
	]:
		if not _is_fingerprint(request.get(field)):
			return false
	return str(request.get("request_fingerprint", "")) \
		== CARD_SCHEMA.fingerprint(request, "request_fingerprint")


static func supported_reference_count() -> int:
	return ENTRY_BY_LEGACY_ID_FINGERPRINT.size()


static func _runtime_card_matches_definition(
	runtime_card: Dictionary,
	legacy_definition: Dictionary,
	source_card_id: String
) -> bool:
	var allowed_keys: Dictionary = {}
	for key_variant in legacy_definition.keys():
		var definition_key := str(key_variant)
		if definition_key.is_empty() \
				or definition_key != definition_key.to_lower():
			return false
		allowed_keys[definition_key] = true
	for runtime_key in REVIEWED_RUNTIME_ONLY_KEYS:
		allowed_keys[runtime_key] = true
	for key_variant in runtime_card.keys():
		if not (key_variant is String or key_variant is StringName):
			return false
		var runtime_key := str(key_variant)
		if runtime_key != runtime_key.to_lower() \
				or not allowed_keys.has(runtime_key):
			return false
	var name_value: Variant = runtime_card.get("name")
	if not (name_value is String) or (name_value as String) != source_card_id:
		return false
	if runtime_card.has("card_id"):
		var card_id_value: Variant = runtime_card.get("card_id")
		if not (card_id_value is String) \
				or not (card_id_value as String).is_empty() \
				and (card_id_value as String) != source_card_id:
			return false
	for key_variant in legacy_definition.keys():
		var key := str(key_variant)
		# Production v0.4 normalizes this obsolete play gate after catalog load.
		if key == "play_flow_required":
			continue
		if not runtime_card.has(key) \
				or runtime_card.get(key) != legacy_definition.get(key):
			return false
	return true


static func _valid_reference(reference: Dictionary) -> bool:
	if not CARD_SCHEMA.is_pure_data(reference) \
			or not _has_exact_keys(reference, RESULT_KEYS) \
			or reference.get("schema_version") != SCHEMA_VERSION \
			or str(reference.get("adapter_id", "")) != ADAPTER_ID \
			or str(reference.get("source_catalog_id", "")) != SOURCE_CATALOG_ID:
		return false
	var legacy_fingerprint := str(reference.get(
		"legacy_card_id_fingerprint",
		""
	))
	var entry_value: Variant = ENTRY_BY_LEGACY_ID_FINGERPRINT.get(
		legacy_fingerprint
	)
	if not (entry_value is Dictionary):
		return false
	var entry := entry_value as Dictionary
	var legacy_definition_value: Variant = reference.get("legacy_definition")
	if not (legacy_definition_value is Dictionary) \
			or str(reference.get("legacy_definition_fingerprint", "")) \
				!= CARD_SCHEMA.fingerprint(
					legacy_definition_value as Dictionary
				):
		return false
	return str(reference.get("semantic_card_id", "")) \
			== str(entry.get("semantic_card_id", "")) \
		and str(reference.get("semantic_family_id", "")) \
			== str(entry.get("semantic_family_id", "")) \
		and reference.get("semantic_rank") == entry.get("semantic_rank") \
		and str(reference.get("interaction_kind_id", "")) \
			== str(entry.get("interaction_kind_id", "")) \
		and str(reference.get("mapping_fingerprint", "")) \
			== _mapping_fingerprint(legacy_fingerprint, entry) \
		and _is_fingerprint(reference.get("legacy_definition_fingerprint")) \
		and _is_fingerprint(reference.get("reference_fingerprint")) \
		and str(reference.get("reference_fingerprint", "")) \
			== CARD_SCHEMA.fingerprint(reference, "reference_fingerprint")


static func _mapping_fingerprint(
	legacy_card_id_fingerprint: String,
	entry: Dictionary
) -> String:
	return CARD_SCHEMA.fingerprint({
		"schema_version": SCHEMA_VERSION,
		"adapter_id": ADAPTER_ID,
		"source_catalog_id": SOURCE_CATALOG_ID,
		"legacy_card_id_fingerprint": legacy_card_id_fingerprint,
		"entry": entry,
	})


static func _is_fingerprint(value: Variant) -> bool:
	if not (value is String) or (value as String).length() != 64:
		return false
	for index in range((value as String).length()):
		var code := (value as String).unicode_at(index)
		if not ((code >= 48 and code <= 57) or (code >= 97 and code <= 102)):
			return false
	return true


static func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key_variant in expected:
		if not value.has(str(key_variant)):
			return false
	return true
