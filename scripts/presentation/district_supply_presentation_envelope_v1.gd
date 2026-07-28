extends RefCounted
class_name DistrictSupplyPresentationEnvelopeV1

const SCHEMA_VERSION := 1
const FIELDS := [
	"schema_version",
	"visible",
	"reason_code",
	"district_index",
	"rack_source_revision",
	"rack_source_version",
	"viewer_index",
	"subject_player_index",
	"authorization_revision",
	"visibility_scope",
	"snapshot",
]
const VISIBILITY_SCOPES := ["closed", "public", "viewer_private"]


static func validation_report(value: Variant) -> Dictionary:
	if not (value is Dictionary) or not SemanticWireV1.is_closed_data(value):
		return SemanticWireV1.invalid_result("district_supply_envelope_not_closed_data")
	var envelope := value as Dictionary
	if not SemanticWireV1.exact_fields(envelope, FIELDS):
		return SemanticWireV1.invalid_result("district_supply_envelope_fields_invalid")
	if envelope.get("schema_version") != SCHEMA_VERSION:
		return SemanticWireV1.invalid_result("district_supply_envelope_schema_version_invalid")
	if not (envelope.get("visible") is bool) \
			or not (envelope.get("reason_code") is String) \
			or str(envelope.get("reason_code", "")).strip_edges().is_empty():
		return SemanticWireV1.invalid_result("district_supply_envelope_status_invalid")
	for field in ["district_index", "viewer_index", "subject_player_index"]:
		if not (envelope.get(field) is int):
			return SemanticWireV1.invalid_result("district_supply_envelope_%s_invalid" % field)
	if not SemanticWireV1.is_nonnegative_integer(envelope.get("authorization_revision")):
		return SemanticWireV1.invalid_result("district_supply_envelope_authorization_revision_invalid")
	if not (envelope.get("rack_source_revision") is String):
		return SemanticWireV1.invalid_result("district_supply_envelope_rack_revision_invalid")
	if not SemanticWireV1.is_nonnegative_integer(envelope.get("rack_source_version")):
		return SemanticWireV1.invalid_result("district_supply_envelope_rack_version_invalid")
	var scope := str(envelope.get("visibility_scope", ""))
	if scope not in VISIBILITY_SCOPES or not (envelope.get("snapshot") is Dictionary):
		return SemanticWireV1.invalid_result("district_supply_envelope_visibility_invalid")
	var visible := bool(envelope.get("visible", false))
	if not visible:
		if scope != "closed" or int(envelope.get("district_index", -1)) != -1 \
				or int(envelope.get("subject_player_index", -1)) != -1 \
				or not str(envelope.get("rack_source_revision", "")).is_empty() \
				or int(envelope.get("rack_source_version", -1)) != 0 \
				or not (envelope.get("snapshot", {}) as Dictionary).is_empty():
			return SemanticWireV1.invalid_result("district_supply_envelope_closed_shape_invalid")
		return SemanticWireV1.valid_result()
	if scope == "closed" or int(envelope.get("district_index", -1)) < 0 \
			or str(envelope.get("rack_source_revision", "")).is_empty() \
			or int(envelope.get("rack_source_version", 0)) <= 0 \
			or (envelope.get("snapshot", {}) as Dictionary).is_empty():
		return SemanticWireV1.invalid_result("district_supply_envelope_open_shape_invalid")
	if scope == "viewer_private" \
			and (int(envelope.get("viewer_index", -1)) < 0 \
				or int(envelope.get("subject_player_index", -1)) != int(envelope.get("viewer_index", -2)) \
				or int(envelope.get("authorization_revision", 0)) <= 0):
		return SemanticWireV1.invalid_result("district_supply_envelope_private_binding_invalid")
	return SemanticWireV1.valid_result()


static func detached_copy(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) \
		if bool(validation_report(value).get("valid", false)) else {}
