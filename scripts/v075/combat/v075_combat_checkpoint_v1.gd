extends RefCounted
class_name V075CombatCheckpointV1

const SCHEMA_VERSION := 1
const RULESET_ID := "v0.7.5"
const COMBAT_CHECKPOINT_ID := "CombatCheckpointV1"
const MONSTER_SOURCE_CHECKPOINT_ID := "MonsterSourceCheckpointV1"
const MONSTER_SKILL_CHECKPOINT_ID := "MonsterSkillCheckpointV1"
const MILITARY_MISSION_CHECKPOINT_ID := "MilitaryMissionCheckpointV1"
const COMPONENT_CONTRACTS := {
	"combat": COMBAT_CHECKPOINT_ID,
	"monster_source": MONSTER_SOURCE_CHECKPOINT_ID,
	"monster_skill": MONSTER_SKILL_CHECKPOINT_ID,
	"military_mission": MILITARY_MISSION_CHECKPOINT_ID,
}
const MAX_SAFE_INTEGER := 9007199254740991


static func contract_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"ruleset_id": RULESET_ID,
		"contract_id": COMBAT_CHECKPOINT_ID,
		"component_contract_ids": COMPONENT_CONTRACTS.duplicate(true),
		"detached": true,
		"pure_data": true,
		"capture_mutation_count": 0,
		"production_save_write_count": 0,
		"production_save_owner_connected": false,
		"rollback_lineage_bound": true,
		"rollback_receipt_prefix_bound": true,
		"exact_once_ledger_preserved": true,
	}


static func capture_combat(
	checkpoint_id: String,
	combat_state: Dictionary
) -> Dictionary:
	return capture_component(checkpoint_id, "combat", combat_state)


static func capture_monster_skill(
	checkpoint_id: String,
	monster_skill_state: Dictionary
) -> Dictionary:
	return capture_component(
		checkpoint_id,
		"monster_skill",
		monster_skill_state
	)


static func capture_component(
	checkpoint_id: String,
	component_kind: String,
	component_state: Dictionary
) -> Dictionary:
	if (
		not _stable_id(checkpoint_id)
		or not COMPONENT_CONTRACTS.has(component_kind)
		or _state_error(component_state) != ""
	):
		return {}
	var receipt_prefix: Array = []
	for receipt_variant in component_state.get("receipt_journal") as Array:
		var receipt := receipt_variant as Dictionary
		receipt_prefix.append({
			"receipt_id": receipt.get("receipt_id"),
			"receipt_fingerprint": receipt.get("receipt_fingerprint"),
		})
	var checkpoint := {
		"schema_version": SCHEMA_VERSION,
		"ruleset_id": RULESET_ID,
		"contract_id": COMPONENT_CONTRACTS.get(component_kind),
		"checkpoint_id": checkpoint_id,
		"component_kind": component_kind,
		"detached": true,
		"production_save_slot": false,
		"lineage_id": component_state.get("lineage_id"),
		"captured_revision": component_state.get("revision"),
		"receipt_prefix": receipt_prefix,
		"state": component_state.duplicate(true),
	}
	return _seal(checkpoint, "checkpoint_fingerprint")


static func rollback(
	current_state: Dictionary,
	checkpoint: Dictionary
) -> Dictionary:
	var current_error := _state_error(current_state)
	if current_error != "":
		return _failure(current_state, current_error)
	var checkpoint_error := _checkpoint_error(checkpoint)
	if checkpoint_error != "":
		return _failure(current_state, checkpoint_error)
	var restored := checkpoint.get("state") as Dictionary
	if str(restored.get("lineage_id", "")) != str(
		current_state.get("lineage_id", "")
	):
		return _failure(current_state, "checkpoint_lineage_invalid")
	if int(checkpoint.get("captured_revision", -1)) > int(
		current_state.get("revision", -1)
	):
		return _failure(current_state, "checkpoint_from_future")
	var prefix := checkpoint.get("receipt_prefix") as Array
	var current_receipts := current_state.get("receipt_journal") as Array
	if prefix.size() > current_receipts.size():
		return _failure(current_state, "checkpoint_receipt_prefix_missing")
	for index in range(prefix.size()):
		var expected := prefix[index] as Dictionary
		var actual := current_receipts[index] as Dictionary
		if (
			str(expected.get("receipt_id", ""))
			!= str(actual.get("receipt_id", ""))
			or str(expected.get("receipt_fingerprint", ""))
			!= str(actual.get("receipt_fingerprint", ""))
		):
			return _failure(
				current_state,
				"checkpoint_not_current_receipt_lineage"
			)
	var rollback_receipt := _seal({
		"schema_version": SCHEMA_VERSION,
		"contract_id": "CombatCheckpointRollbackReceiptV1",
		"rollback_receipt_id": "receipt.combat.rollback.%s" % (
			str(checkpoint.get(
				"checkpoint_fingerprint",
				""
			)).sha256_text().substr(0, 24)
		),
		"checkpoint_id": checkpoint.get("checkpoint_id"),
		"component_kind": checkpoint.get("component_kind"),
		"lineage_id": checkpoint.get("lineage_id"),
		"restored_revision": checkpoint.get("captured_revision"),
		"exact_once_ledger_preserved": true,
		"production_save_write_count": 0,
	}, "receipt_fingerprint")
	return {
		"rolled_back": true,
		"replayed": (
			current_state.get("state_fingerprint")
			== restored.get("state_fingerprint")
		),
		"reason_code": "checkpoint_restored",
		"state": restored.duplicate(true),
		"receipt": rollback_receipt,
	}


static func validation_report(checkpoint: Variant) -> Dictionary:
	var reason_code := _checkpoint_error(checkpoint)
	return {
		"valid": reason_code == "",
		"reason_code": "none" if reason_code == "" else reason_code,
		"pure_data": _is_pure_data(checkpoint),
	}


static func is_pure_data(value: Variant) -> bool:
	return _is_pure_data(value)


static func _checkpoint_error(value: Variant) -> String:
	if not (value is Dictionary) or not _is_pure_data(value):
		return "checkpoint_not_pure_dictionary"
	var checkpoint := value as Dictionary
	var component_kind := str(checkpoint.get("component_kind", ""))
	if (
		checkpoint.get("schema_version") != SCHEMA_VERSION
		or checkpoint.get("ruleset_id") != RULESET_ID
		or not COMPONENT_CONTRACTS.has(component_kind)
		or checkpoint.get("contract_id")
		!= COMPONENT_CONTRACTS.get(component_kind)
		or not _stable_id(checkpoint.get("checkpoint_id"))
		or checkpoint.get("detached") != true
		or checkpoint.get("production_save_slot") != false
		or not _stable_id(checkpoint.get("lineage_id"))
		or not _nonnegative_integer(checkpoint.get("captured_revision"))
		or not (checkpoint.get("receipt_prefix") is Array)
		or not (checkpoint.get("state") is Dictionary)
		or _state_error(checkpoint.get("state")) != ""
	):
		return "checkpoint_contract_invalid"
	var state := checkpoint.get("state") as Dictionary
	if (
		checkpoint.get("lineage_id") != state.get("lineage_id")
		or checkpoint.get("captured_revision") != state.get("revision")
	):
		return "checkpoint_state_binding_invalid"
	var state_receipts := state.get("receipt_journal") as Array
	var prefix := checkpoint.get("receipt_prefix") as Array
	if prefix.size() != state_receipts.size():
		return "checkpoint_receipt_prefix_invalid"
	for index in range(prefix.size()):
		var expected_variant: Variant = prefix[index]
		if not (expected_variant is Dictionary):
			return "checkpoint_receipt_prefix_invalid"
		var expected := expected_variant as Dictionary
		var actual := state_receipts[index] as Dictionary
		if (
			expected.size() != 2
			or expected.get("receipt_id") != actual.get("receipt_id")
			or expected.get("receipt_fingerprint")
			!= actual.get("receipt_fingerprint")
		):
			return "checkpoint_receipt_prefix_invalid"
	var fingerprint := str(checkpoint.get("checkpoint_fingerprint", ""))
	var unsealed := checkpoint.duplicate(true)
	unsealed.erase("checkpoint_fingerprint")
	if (
		not _fingerprint_valid(fingerprint)
		or _fingerprint(unsealed) != fingerprint
	):
		return "checkpoint_fingerprint_invalid"
	return ""


static func _state_error(value: Variant) -> String:
	if not (value is Dictionary) or not _is_pure_data(value):
		return "checkpoint_state_not_pure_data"
	var state := value as Dictionary
	if (
		not _stable_id(state.get("lineage_id"))
		or not _nonnegative_integer(state.get("revision"))
		or not (state.get("receipt_journal") is Array)
	):
		return "checkpoint_state_contract_invalid"
	for receipt_variant in state.get("receipt_journal") as Array:
		if not (receipt_variant is Dictionary):
			return "checkpoint_receipt_invalid"
		var receipt := receipt_variant as Dictionary
		if (
			not _stable_id(receipt.get("receipt_id"))
			or not _fingerprint_valid(receipt.get("receipt_fingerprint"))
		):
			return "checkpoint_receipt_invalid"
	return ""


static func _failure(
	state: Dictionary,
	reason_code: String
) -> Dictionary:
	return {
		"rolled_back": false,
		"replayed": false,
		"reason_code": reason_code,
		"state": state.duplicate(true),
		"receipt": {},
	}


static func _seal(
	unsealed: Dictionary,
	fingerprint_field: String
) -> Dictionary:
	if unsealed.has(fingerprint_field) or not _is_pure_data(unsealed):
		return {}
	var sealed := unsealed.duplicate(true)
	sealed[fingerprint_field] = _fingerprint(sealed)
	return sealed


static func _fingerprint(value: Variant) -> String:
	var canonical := _canonical_json(value)
	return canonical.sha256_text().to_lower() if canonical != "" else ""


static func _canonical_json(value: Variant) -> String:
	if not _is_pure_data(value):
		return ""
	if (
		value == null
		or value is String
		or value is bool
		or value is int
	):
		return JSON.stringify(value)
	if value is Array:
		var parts: Array[String] = []
		for item_variant in value as Array:
			parts.append(_canonical_json(item_variant))
		return "[" + ",".join(parts) + "]"
	var dictionary := value as Dictionary
	var keys: Array[String] = []
	for key_variant in dictionary.keys():
		keys.append(str(key_variant))
	keys.sort()
	var members: Array[String] = []
	for key in keys:
		members.append(
			JSON.stringify(key)
			+ ":"
			+ _canonical_json(dictionary.get(key))
		)
	return "{" + ",".join(members) + "}"


static func _is_pure_data(
	value: Variant,
	depth: int = 0
) -> bool:
	if depth > 64:
		return false
	if (
		value == null
		or value is String
		or value is bool
		or value is int
	):
		return (
			not (value is int)
			or (
				int(value) >= -MAX_SAFE_INTEGER
				and int(value) <= MAX_SAFE_INTEGER
			)
		)
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


static func _stable_id(value: Variant) -> bool:
	if not (value is String):
		return false
	var text := str(value)
	if text.is_empty() or text.length() > 192:
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


static func _fingerprint_valid(value: Variant) -> bool:
	if not (value is String) or str(value).length() != 64:
		return false
	for index in range(str(value).length()):
		var code := str(value).unicode_at(index)
		if not (
			(code >= 48 and code <= 57)
			or (code >= 97 and code <= 102)
		):
			return false
	return true


static func _nonnegative_integer(value: Variant) -> bool:
	return (
		value is int
		and int(value) >= 0
		and int(value) <= MAX_SAFE_INTEGER
	)
