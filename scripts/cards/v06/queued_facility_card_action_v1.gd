extends RefCounted
class_name V06QueuedFacilityCardActionV1

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")

const SCHEMA_VERSION := 1
const BINDING_KIND_ID := "v06.queued-facility-card-action"
const TARGET_KIND_ID := "region_unique_facility_slot"
const ASSET_RESERVATION_OWNER_ID := "player_mana"
const ASSET_RESERVATION_STATE_ID := "reserved"
const CARD_ESCROW_OWNER_ID := "world_session_state"
const CARD_ESCROW_STATE_ID := "committed_resolution_escrow"

const ACTOR_KIND_IDS := ["human", "ai"]
const FACILITY_KIND_IDS := [
	"factory",
	"market",
	"warehouse",
	"road",
	"port",
	"spaceport",
]

const BUILD_FIELDS := [
	"schema_version",
	"binding_kind_id",
	"resolution_id",
	"request_id",
	"intent_fingerprint",
	"session_id",
	"session_revision",
	"session_identity_fingerprint",
	"source_revision",
	"actor_kind_id",
	"actor_id",
	"actor_player_index",
	"card_instance_id",
	"runtime_instance_id",
	"card_semantic_id",
	"hand_slot_id",
	"source_slot_index",
	"source_record_fingerprint",
	"source_slot_fingerprint",
	"facility_kind_id",
	"industry_id",
	"rank",
	"prebound_target",
	"asset_reservation",
	"card_escrow",
	"submitted_at_world_time",
	"queue_revision_at_commit",
	"local_action_index",
	"public_visibility",
]
const FIELDS := BUILD_FIELDS + ["binding_fingerprint"]

const PREBOUND_TARGET_FIELDS := [
	"schema_version",
	"target_kind_id",
	"region_id",
	"region_revision",
	"target_slot_id",
	"target_slot_generation",
	"target_state_fingerprint",
]
const ASSET_RESERVATION_FIELDS := [
	"schema_version",
	"owner_id",
	"required",
	"reservation_id",
	"reservation_state_id",
	"reservation_fingerprint",
]
const CARD_ESCROW_FIELDS := [
	"schema_version",
	"owner_id",
	"escrow_id",
	"state_id",
	"escrow_fingerprint",
]
const PUBLIC_VISIBILITY_FIELDS := [
	"schema_version",
	"owner_visibility_id",
	"card_visibility_id",
	"target_visibility_id",
]


static func build(unsealed: Dictionary) -> Dictionary:
	if not WIRE.is_closed_data(unsealed) \
			or not WIRE.exact_fields(unsealed, BUILD_FIELDS):
		return {}
	var sealed := WIRE.sealed_copy(unsealed, "binding_fingerprint")
	return sealed \
		if bool(validation_report(sealed).get("valid", false)) else {}


static func validation_report(value: Variant) -> Dictionary:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return _invalid("not_closed_data")
	var binding := value as Dictionary
	if not WIRE.exact_fields(binding, FIELDS):
		return _invalid("fields_invalid")
	if binding.get("schema_version") != SCHEMA_VERSION:
		return _invalid("schema_version_invalid")
	if str(binding.get("binding_kind_id", "")) != BINDING_KIND_ID:
		return _invalid("binding_kind_invalid")

	for field in ["actor_id", "card_semantic_id", "hand_slot_id"]:
		if not WIRE.is_stable_id(binding.get(field)):
			return _invalid("%s_invalid" % field)
	for field in ["request_id", "session_id", "card_instance_id", "runtime_instance_id"]:
		if not WIRE.is_session_id(binding.get(field)):
			return _invalid("%s_invalid" % field)
	if not WIRE.is_positive_integer(binding.get("resolution_id")):
		return _invalid("resolution_id_invalid")

	for field in [
		"intent_fingerprint",
		"session_identity_fingerprint",
		"source_record_fingerprint",
		"source_slot_fingerprint",
	]:
		if not WIRE.is_fingerprint(binding.get(field)):
			return _invalid("%s_invalid" % field)

	for field in [
		"session_revision",
		"source_revision",
		"actor_player_index",
		"source_slot_index",
		"submitted_at_world_time",
		"queue_revision_at_commit",
	]:
		if not WIRE.is_nonnegative_integer(binding.get(field)):
			return _invalid("%s_invalid" % field)

	var actor_kind_id := str(binding.get("actor_kind_id", ""))
	if actor_kind_id not in ACTOR_KIND_IDS:
		return _invalid("actor_kind_id_invalid")
	var expected_actor_id := "player.%d" % int(
		binding.get("actor_player_index", -1)
	)
	if str(binding.get("actor_id", "")) != expected_actor_id:
		return _invalid("actor_identity_mismatch")
	if str(binding.get("card_instance_id", "")) \
			!= str(binding.get("runtime_instance_id", "")):
		return _invalid("card_instance_identity_mismatch")

	if str(binding.get("facility_kind_id", "")) not in FACILITY_KIND_IDS:
		return _invalid("facility_kind_id_invalid")
	var facility_kind_id := str(binding.get("facility_kind_id", ""))
	var industry_id := str(binding.get("industry_id", ""))
	if facility_kind_id in ["factory", "market", "warehouse"]:
		if not WIRE.is_stable_id(industry_id):
			return _invalid("industry_id_invalid")
	elif not industry_id.is_empty():
		return _invalid("industry_id_invalid")
	if not WIRE.is_positive_integer(binding.get("rank")) \
			or int(binding.get("rank", 0)) > 4:
		return _invalid("rank_invalid")
	if binding.get("local_action_index") != 0:
		return _invalid("local_action_index_invalid")

	var nested_error := _prebound_target_error(binding.get("prebound_target"))
	if not nested_error.is_empty():
		return _invalid(nested_error)
	nested_error = _asset_reservation_error(binding.get("asset_reservation"))
	if not nested_error.is_empty():
		return _invalid(nested_error)
	nested_error = _card_escrow_error(binding.get("card_escrow"))
	if not nested_error.is_empty():
		return _invalid(nested_error)
	nested_error = _public_visibility_error(binding.get("public_visibility"))
	if not nested_error.is_empty():
		return _invalid(nested_error)

	if not WIRE.is_fingerprint(binding.get("binding_fingerprint")) \
			or str(binding.get("binding_fingerprint", "")) \
				!= WIRE.fingerprint(binding, "binding_fingerprint"):
		return _invalid("binding_fingerprint_invalid")
	return WIRE.valid_result()


static func detached_copy(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) \
		if bool(validation_report(value).get("valid", false)) else {}


static func binding_fingerprint(value: Variant) -> String:
	return str((value as Dictionary).get("binding_fingerprint", "")) \
		if bool(validation_report(value).get("valid", false)) else ""


static func _prebound_target_error(value: Variant) -> String:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return "prebound_target_not_closed_data"
	var target := value as Dictionary
	if not WIRE.exact_fields(target, PREBOUND_TARGET_FIELDS):
		return "prebound_target_fields_invalid"
	if target.get("schema_version") != SCHEMA_VERSION:
		return "prebound_target_schema_version_invalid"
	if str(target.get("target_kind_id", "")) != TARGET_KIND_ID:
		return "prebound_target_kind_invalid"
	if not WIRE.is_stable_id(target.get("region_id")):
		return "prebound_target_region_id_invalid"
	if not _opaque_target_slot_id(target.get("target_slot_id")):
		return "prebound_target_target_slot_id_invalid"
	for field in ["region_revision", "target_slot_generation"]:
		if not WIRE.is_nonnegative_integer(target.get(field)):
			return "prebound_target_%s_invalid" % field
	if not WIRE.is_fingerprint(target.get("target_state_fingerprint")):
		return "prebound_target_state_fingerprint_invalid"
	return ""


static func _asset_reservation_error(value: Variant) -> String:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return "asset_reservation_not_closed_data"
	var reservation := value as Dictionary
	if not WIRE.exact_fields(reservation, ASSET_RESERVATION_FIELDS):
		return "asset_reservation_fields_invalid"
	if reservation.get("schema_version") != SCHEMA_VERSION:
		return "asset_reservation_schema_version_invalid"
	if str(reservation.get("owner_id", "")) \
			!= ASSET_RESERVATION_OWNER_ID \
			or str(reservation.get("reservation_state_id", "")) \
				!= ASSET_RESERVATION_STATE_ID:
		return "asset_reservation_authority_invalid"
	if not (reservation.get("required") is bool):
		return "asset_reservation_required_invalid"
	var reservation_id: Variant = reservation.get("reservation_id")
	if bool(reservation.get("required", false)):
		if not WIRE.is_stable_id(reservation_id):
			return "asset_reservation_id_invalid"
	elif not (reservation_id is String) or not str(reservation_id).is_empty():
		return "asset_reservation_id_invalid"
	if not WIRE.is_fingerprint(reservation.get("reservation_fingerprint")):
		return "asset_reservation_fingerprint_invalid"
	return ""


static func _card_escrow_error(value: Variant) -> String:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return "card_escrow_not_closed_data"
	var escrow := value as Dictionary
	if not WIRE.exact_fields(escrow, CARD_ESCROW_FIELDS):
		return "card_escrow_fields_invalid"
	if escrow.get("schema_version") != SCHEMA_VERSION:
		return "card_escrow_schema_version_invalid"
	if str(escrow.get("owner_id", "")) != CARD_ESCROW_OWNER_ID \
			or str(escrow.get("state_id", "")) != CARD_ESCROW_STATE_ID:
		return "card_escrow_authority_invalid"
	if not WIRE.is_stable_id(escrow.get("escrow_id")):
		return "card_escrow_id_invalid"
	if not WIRE.is_fingerprint(escrow.get("escrow_fingerprint")):
		return "card_escrow_fingerprint_invalid"
	return ""


static func _public_visibility_error(value: Variant) -> String:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return "public_visibility_not_closed_data"
	var visibility := value as Dictionary
	if not WIRE.exact_fields(visibility, PUBLIC_VISIBILITY_FIELDS):
		return "public_visibility_fields_invalid"
	if visibility.get("schema_version") != SCHEMA_VERSION:
		return "public_visibility_schema_version_invalid"
	if str(visibility.get("owner_visibility_id", "")) != "anonymous" \
			or str(visibility.get("card_visibility_id", "")) != "public" \
			or str(visibility.get("target_visibility_id", "")) != "public":
		return "public_visibility_policy_invalid"
	return ""


static func _invalid(reason_suffix: String) -> Dictionary:
	return WIRE.invalid_result(
		"v06_queued_facility_card_action.%s" % reason_suffix
	)


static func _opaque_target_slot_id(value: Variant) -> bool:
	if not (value is String):
		return false
	var text := value as String
	if text.is_empty() or text.length() > 160:
		return false
	for index in range(text.length()):
		var code := text.unicode_at(index)
		var lower := code >= 97 and code <= 122
		var digit := code >= 48 and code <= 57
		if not lower and not digit and code not in [46, 95, 45, 58]:
			return false
	return true
