extends RefCounted
class_name V075CharacterMonsterCapacityPort

const SCHEMA_VERSION := "1.0.0"
const RULESET_ID := "v0.7.5"
const CONTRACT_ID := "v075.character_monster_capacity_port.v1"
const SEMANTIC_CONTRACT_ID := "v075.character_monster_capacity_semantic.v1"
const BASE_MONSTER_CONTROL_CAPACITY_PER_PLAYER := 1
const MAX_SAFE_INTEGER := 9007199254740991
const SEMANTIC_FIELDS := [
	"schema_version",
	"contract_id",
	"ruleset_id",
	"character_semantic_id",
	"player_id",
	"revision",
	"monster_control_capacity_modifier",
	"semantic_fingerprint",
]


static func build_semantic(
	player_id: String,
	monster_control_capacity_modifier: int,
	revision: int = 1,
	character_semantic_id: String = ""
) -> Dictionary:
	var semantic_id := character_semantic_id
	if semantic_id.is_empty() and _stable_id(player_id):
		semantic_id = "character.semantic.%s" % player_id
	var unsealed := {
		"schema_version": SCHEMA_VERSION,
		"contract_id": SEMANTIC_CONTRACT_ID,
		"ruleset_id": RULESET_ID,
		"character_semantic_id": semantic_id,
		"player_id": player_id,
		"revision": revision,
		"monster_control_capacity_modifier": (
			monster_control_capacity_modifier
		),
	}
	if _unsealed_semantic_error(unsealed) != "":
		return {}
	var semantic := unsealed.duplicate(true)
	semantic["semantic_fingerprint"] = _fingerprint(unsealed)
	return semantic


static func capacity_receipt(character_semantic: Dictionary) -> Dictionary:
	var error := _semantic_error(character_semantic)
	if error != "":
		return {
			"accepted": false,
			"reason_code": error,
			"contract_id": CONTRACT_ID,
			"ruleset_id": RULESET_ID,
			"base_capacity": BASE_MONSTER_CONTROL_CAPACITY_PER_PLAYER,
			"modifier": 0,
			"effective_capacity": -1,
		}
	var modifier := int(
		character_semantic.get("monster_control_capacity_modifier", 0)
	)
	return {
		"accepted": true,
		"reason_code": "character_monster_capacity_resolved",
		"contract_id": CONTRACT_ID,
		"ruleset_id": RULESET_ID,
		"character_semantic_id": str(
			character_semantic.get("character_semantic_id", "")
		),
		"player_id": str(character_semantic.get("player_id", "")),
		"semantic_revision": int(character_semantic.get("revision", 0)),
		"base_capacity": BASE_MONSTER_CONTROL_CAPACITY_PER_PLAYER,
		"modifier": modifier,
		"effective_capacity": (
			BASE_MONSTER_CONTROL_CAPACITY_PER_PLAYER + modifier
		),
	}


static func effective_capacity(character_semantic: Dictionary) -> int:
	var receipt := capacity_receipt(character_semantic)
	return (
		int(receipt.get("effective_capacity", -1))
		if bool(receipt.get("accepted", false))
		else -1
	)


static func validation_report(character_semantic: Dictionary) -> Dictionary:
	var error := _semantic_error(character_semantic)
	return {
		"valid": error == "",
		"reason_code": (
			"character_monster_capacity_semantic_valid"
			if error == ""
			else error
		),
		"error_count": 0 if error == "" else 1,
		"base_capacity": BASE_MONSTER_CONTROL_CAPACITY_PER_PLAYER,
		"effective_capacity": effective_capacity(character_semantic),
	}


static func contract_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"contract_id": CONTRACT_ID,
		"semantic_contract_id": SEMANTIC_CONTRACT_ID,
		"ruleset_id": RULESET_ID,
		"base_monster_control_capacity_per_player": (
			BASE_MONSTER_CONTROL_CAPACITY_PER_PLAYER
		),
		"modifier_field": "monster_control_capacity_modifier",
		"character_semantic_port_count": 1,
		"ui_capacity_exception_count": 0,
		"player_index_capacity_exception_count": 0,
		"character_name_capacity_exception_count": 0,
		"capacity_drop_forced_kill_allowed": false,
	}


static func _semantic_error(character_semantic: Dictionary) -> String:
	if not _is_pure_data(character_semantic):
		return "character_capacity_semantic_not_pure_data"
	if not _exact_fields(character_semantic, SEMANTIC_FIELDS):
		return "character_capacity_semantic_fields_invalid"
	var unsealed := character_semantic.duplicate(true)
	var fingerprint := str(unsealed.get("semantic_fingerprint", ""))
	unsealed.erase("semantic_fingerprint")
	var context_error := _unsealed_semantic_error(unsealed)
	if context_error != "":
		return context_error
	if (
		fingerprint.length() != 64
		or fingerprint != _fingerprint(unsealed)
	):
		return "character_capacity_semantic_fingerprint_invalid"
	return ""


static func _unsealed_semantic_error(unsealed: Dictionary) -> String:
	if (
		unsealed.get("schema_version") != SCHEMA_VERSION
		or unsealed.get("contract_id") != SEMANTIC_CONTRACT_ID
		or unsealed.get("ruleset_id") != RULESET_ID
		or not _stable_id(unsealed.get("character_semantic_id"))
		or not _stable_id(unsealed.get("player_id"))
		or not _positive_integer(unsealed.get("revision"))
		or not _nonnegative_integer(
			unsealed.get("monster_control_capacity_modifier")
		)
		or int(unsealed.get(
			"monster_control_capacity_modifier",
			-1
		)) > (
			MAX_SAFE_INTEGER
			- BASE_MONSTER_CONTROL_CAPACITY_PER_PLAYER
		)
	):
		return "character_capacity_semantic_context_invalid"
	return ""


static func _fingerprint(value: Variant) -> String:
	var canonical := _canonical_json(value)
	return canonical.sha256_text().to_lower() if not canonical.is_empty() else ""


static func _canonical_json(value: Variant) -> String:
	if not _is_pure_data(value):
		return ""
	if value == null or value is String or value is bool or value is int:
		return JSON.stringify(value)
	if value is Array:
		var items: Array[String] = []
		for item_variant in value as Array:
			items.append(_canonical_json(item_variant))
		return "[" + ",".join(items) + "]"
	var source := value as Dictionary
	var keys: Array[String] = []
	for key_variant in source.keys():
		keys.append(str(key_variant))
	keys.sort()
	var members: Array[String] = []
	for key in keys:
		members.append(
			JSON.stringify(key) + ":" + _canonical_json(source.get(key))
		)
	return "{" + ",".join(members) + "}"


static func _is_pure_data(value: Variant, depth: int = 0) -> bool:
	if depth > 32:
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
			if (
				not (key_variant is String)
				or not _is_pure_data(
					(value as Dictionary).get(key_variant),
					depth + 1
				)
			):
				return false
		return true
	return false


static func _exact_fields(value: Dictionary, fields: Array) -> bool:
	if value.size() != fields.size():
		return false
	for field_variant in fields:
		if not value.has(str(field_variant)):
			return false
	return true


static func _safe_integer(value: Variant) -> bool:
	return (
		value is int
		and int(value) >= -MAX_SAFE_INTEGER
		and int(value) <= MAX_SAFE_INTEGER
	)


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
