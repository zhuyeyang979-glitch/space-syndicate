extends RefCounted
class_name GameActionCardBindingV1

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const PRIVATE_INSTANCE_PREFIX := "card.instance."
const HAND_SLOT_PREFIX := "hand.slot."
const RESOLUTION_PREFIX := "card.resolution."


static func semantic_card_id(card: Dictionary, slot_index: int) -> String:
	if slot_index < 0:
		return ""
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	var authored := _authored_card_name(
		machine.get("card_id", card.get("card_id", card.get("name", "")))
	)
	if WIRE.is_stable_id(authored):
		return authored
	if authored.is_empty():
		return ""
	return legacy_semantic_card_id(authored)


static func legacy_semantic_card_id(authored_name: Variant) -> String:
	var authored := _authored_card_name(authored_name)
	if authored.is_empty():
		return ""
	var authored_identity := {"legacy_card_name": authored}
	return "legacy.card.%s" % WIRE.fingerprint(authored_identity).left(24) \
		if WIRE.is_closed_data(authored_identity) else ""


static func private_instance_ref(card: Dictionary, slot_index: int) -> String:
	var source := _binding_source(card, slot_index)
	if source.is_empty():
		return ""
	return "%s%s" % [PRIVATE_INSTANCE_PREFIX, WIRE.fingerprint(source).left(24)]


static func hand_slot_ref(slot_index: int) -> String:
	return "%s%d" % [HAND_SLOT_PREFIX, slot_index] if slot_index >= 0 else ""


static func resolution_ref(resolution_id: int) -> String:
	return "%s%d" % [RESOLUTION_PREFIX, resolution_id] if resolution_id >= 0 else ""


static func matches_private_instance_ref(
	card: Dictionary,
	slot_index: int,
	expected_ref: String
) -> bool:
	return WIRE.is_stable_id(expected_ref) \
		and expected_ref == private_instance_ref(card, slot_index)


static func _binding_source(card: Dictionary, slot_index: int) -> Dictionary:
	if slot_index < 0:
		return {}
	var machine_variant: Variant = card.get("machine", {})
	var machine: Dictionary = machine_variant if machine_variant is Dictionary else {}
	var card_id := semantic_card_id(card, slot_index)
	if card_id.is_empty():
		return {}
	var family_id := _stable_id(machine.get("family_id", card.get("family_id", "")))
	if family_id.is_empty():
		family_id = "none"
	var runtime_instance_id := _runtime_reference(card.get("runtime_instance_id", ""))
	if runtime_instance_id.is_empty():
		runtime_instance_id = "none"
	var rank := _normalized_nonnegative_integer(machine.get("rank", card.get("rank", 0)))
	if rank < 0:
		return {}
	var source := {
		"runtime_instance_id": runtime_instance_id,
		"card_id": card_id,
		"family_id": family_id,
		"rank": rank,
		"slot_index": slot_index,
	}
	return source if WIRE.is_closed_data(source) else {}


static func _stable_id(value: Variant) -> String:
	var normalized := str(value) if value is String or value is StringName else ""
	return normalized if WIRE.is_stable_id(normalized) else ""


static func _runtime_reference(value: Variant) -> String:
	var normalized := str(value) if value is String or value is StringName else ""
	return normalized if normalized == normalized.strip_edges() \
		and WIRE.is_ascii_reference(normalized) else ""


static func _authored_card_name(value: Variant) -> String:
	if not (value is String or value is StringName):
		return ""
	return str(value).strip_edges()


static func _normalized_nonnegative_integer(value: Variant) -> int:
	if WIRE.is_nonnegative_integer(value):
		return int(value)
	if value is float:
		var numeric := float(value)
		if is_finite(numeric) and numeric >= 0.0 \
				and numeric <= float(WIRE.MAX_SAFE_INTEGER) \
				and numeric == floorf(numeric):
			return int(numeric)
	return -1
