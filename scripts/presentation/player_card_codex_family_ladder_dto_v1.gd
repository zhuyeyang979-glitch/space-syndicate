extends RefCounted
class_name PlayerCardCodexFamilyLadderDTOv1

const PLAYER_FACE_DTO := preload("res://scripts/presentation/player_face_dto_v1.gd")
const CARD_CODEX_DTO := preload(
	"res://scripts/presentation/player_card_codex_dto_v1.gd"
)

const SCHEMA_VERSION := 1
const ENTRY_COUNT := 4
const ROOT_FIELDS := [
	"schema_version",
	"family_id",
	"entries",
	"ladder_fingerprint",
]
const UNSEALED_ROOT_FIELDS := [
	"schema_version",
	"family_id",
	"entries",
]
const CODEX_ENTRY_FIELDS := [
	"schema_version",
	"projection_id",
	"semantic_binding",
	"localization_binding",
	"detail_face",
	"taxonomy",
	"presentation_tokens",
	"presentation_copy",
	"dto_fingerprint",
]
const PLAYER_FACE_FIELDS := [
	"schema_version",
	"card_id",
	"family_id",
	"rank",
	"name_ref",
	"family_name_ref",
	"surface_id",
	"acquisition_cost",
	"activation_cost",
	"timing",
	"targets",
	"conditions",
	"effect_steps",
	"duration",
	"counterability",
	"information_scope",
	"keywords",
	"dto_fingerprint",
]


static func seal(unsealed_ladder: Dictionary) -> Dictionary:
	if not PLAYER_FACE_DTO.is_detached_pure_data(unsealed_ladder) \
			or not _has_exact_fields(unsealed_ladder, UNSEALED_ROOT_FIELDS):
		return {}
	var ladder := unsealed_ladder.duplicate(true)
	ladder["ladder_fingerprint"] = CARD_CODEX_DTO.fingerprint_value(ladder)
	return ladder if bool(validate(ladder).get("valid", false)) else {}


static func seal_catalog_owned(unsealed_ladder: Dictionary) -> Dictionary:
	if not PLAYER_FACE_DTO.is_detached_pure_data(unsealed_ladder) \
			or not _has_exact_fields(unsealed_ladder, UNSEALED_ROOT_FIELDS) \
			or unsealed_ladder.get("schema_version") != SCHEMA_VERSION:
		return {}
	var family_id := str(unsealed_ladder.get("family_id", ""))
	var entries_value: Variant = unsealed_ladder.get("entries")
	if not PLAYER_FACE_DTO.is_stable_id(family_id) \
			or not (entries_value is Array) \
			or (entries_value as Array).size() != ENTRY_COUNT:
		return {}
	var seen_card_ids: Dictionary = {}
	for index in range(ENTRY_COUNT):
		var entry_value: Variant = (entries_value as Array)[index]
		if not (entry_value is Dictionary):
			return {}
		var entry := entry_value as Dictionary
		if not _has_exact_fields(entry, CODEX_ENTRY_FIELDS) \
				or str(entry.get("projection_id", "")) \
					!= CARD_CODEX_DTO.PROJECTION_ID \
				or not PLAYER_FACE_DTO.is_fingerprint(str(entry.get(
					"dto_fingerprint",
					""
				))) \
				or str(entry.get("dto_fingerprint", "")) \
					!= CARD_CODEX_DTO.fingerprint_value(
						entry,
						"dto_fingerprint"
					):
			return {}
		var semantic_value: Variant = entry.get("semantic_binding")
		var localization_value: Variant = entry.get("localization_binding")
		if not (semantic_value is Dictionary) \
				or not (localization_value is Dictionary) \
				or str((semantic_value as Dictionary).get(
					"semantic_fingerprint",
					""
				)) != str((localization_value as Dictionary).get(
					"semantic_fingerprint",
					""
				)):
			return {}
		var detail_value: Variant = entry.get("detail_face")
		if not (detail_value is Dictionary):
			return {}
		var detail_face := detail_value as Dictionary
		var card_id := str(detail_face.get("card_id", ""))
		var rank_value: Variant = detail_face.get("rank")
		if not _has_exact_fields(detail_face, PLAYER_FACE_FIELDS) \
				or not (rank_value is int) \
				or str(detail_face.get("family_id", "")) != family_id \
				or int(rank_value) != index + 1 \
				or not PLAYER_FACE_DTO.is_stable_id(card_id) \
				or seen_card_ids.has(card_id) \
				or not PLAYER_FACE_DTO.is_fingerprint(str(detail_face.get(
					"dto_fingerprint",
					""
				))):
			return {}
		var detail_fingerprint_input := detail_face.duplicate(true)
		detail_fingerprint_input.erase("dto_fingerprint")
		if str(detail_face.get("dto_fingerprint", "")) \
				!= PLAYER_FACE_DTO.fingerprint_value(detail_fingerprint_input):
			return {}
		seen_card_ids[card_id] = true
	var ladder := unsealed_ladder.duplicate(true)
	ladder["ladder_fingerprint"] = CARD_CODEX_DTO.fingerprint_value(ladder)
	return ladder if PLAYER_FACE_DTO.is_fingerprint(str(ladder.get(
		"ladder_fingerprint",
		""
	))) else {}


static func validate(value: Variant) -> Dictionary:
	if not (value is Dictionary) \
			or not PLAYER_FACE_DTO.is_detached_pure_data(value):
		return _invalid("player_card_codex_family_ladder.not_detached_pure_data")
	var ladder := value as Dictionary
	if not _has_exact_fields(ladder, ROOT_FIELDS):
		return _invalid("player_card_codex_family_ladder.root_fields_invalid")
	if ladder.get("schema_version") != SCHEMA_VERSION:
		return _invalid("player_card_codex_family_ladder.schema_version_invalid")
	var family_id_value: Variant = ladder.get("family_id")
	if not (family_id_value is String) \
			or not PLAYER_FACE_DTO.is_stable_id(family_id_value as String):
		return _invalid("player_card_codex_family_ladder.family_id_invalid")
	var family_id := family_id_value as String
	var entries_value: Variant = ladder.get("entries")
	if not (entries_value is Array) \
			or (entries_value as Array).size() != ENTRY_COUNT:
		return _invalid("player_card_codex_family_ladder.entries_invalid")

	var seen_card_ids: Dictionary = {}
	for index in range(ENTRY_COUNT):
		var entry_value: Variant = (entries_value as Array)[index]
		if not (entry_value is Dictionary) \
				or not bool(CARD_CODEX_DTO.validate(entry_value).get("valid", false)):
			return _invalid("player_card_codex_family_ladder.entry_invalid")
		var entry := entry_value as Dictionary
		var detail_face := entry.get("detail_face") as Dictionary
		if str(detail_face.get("family_id", "")) != family_id:
			return _invalid("player_card_codex_family_ladder.family_mismatch")
		if int(detail_face.get("rank", 0)) != index + 1:
			return _invalid("player_card_codex_family_ladder.rank_order_invalid")
		var card_id := str(detail_face.get("card_id", ""))
		if seen_card_ids.has(card_id):
			return _invalid("player_card_codex_family_ladder.card_duplicate")
		seen_card_ids[card_id] = true

	var fingerprint := str(ladder.get("ladder_fingerprint", ""))
	if not PLAYER_FACE_DTO.is_fingerprint(fingerprint) \
			or fingerprint != CARD_CODEX_DTO.fingerprint_value(
				ladder,
				"ladder_fingerprint"
			):
		return _invalid("player_card_codex_family_ladder.fingerprint_invalid")
	return {
		"valid": true,
		"reason_id": "player_card_codex_family_ladder.valid",
	}


static func _has_exact_fields(source: Dictionary, expected_fields: Array) -> bool:
	if source.size() != expected_fields.size():
		return false
	for field_variant in expected_fields:
		if not source.has(str(field_variant)):
			return false
	return true


static func _invalid(reason_id: String) -> Dictionary:
	return {"valid": false, "reason_id": reason_id}
