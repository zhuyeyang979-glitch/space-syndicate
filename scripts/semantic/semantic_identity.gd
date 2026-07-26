extends RefCounted
class_name SemanticIdentity

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const SCHEMA_VERSION := 1
const BUILD_FIELDS := [
	"schema_version",
	"domain_id",
	"definition_id",
	"definition_revision",
	"ruleset_id",
	"source_catalog_id",
	"source_definition_fingerprint",
]
const FIELDS := BUILD_FIELDS + ["identity_fingerprint"]


static func build(unsealed: Dictionary) -> Dictionary:
	if not WIRE.is_closed_data(unsealed) or not WIRE.exact_fields(unsealed, BUILD_FIELDS):
		return {}
	var sealed := WIRE.sealed_copy(unsealed, "identity_fingerprint")
	return sealed if bool(validate(sealed).get("valid", false)) else {}


static func validate(value: Variant) -> Dictionary:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return WIRE.invalid_result("semantic_identity.not_closed_data")
	var identity := value as Dictionary
	if not WIRE.exact_fields(identity, FIELDS):
		return WIRE.invalid_result("semantic_identity.fields_invalid")
	if identity.get("schema_version") != SCHEMA_VERSION:
		return WIRE.invalid_result("semantic_identity.schema_version_invalid")
	if not WIRE.DOMAIN_IDS.has(str(identity.get("domain_id", ""))):
		return WIRE.invalid_result("semantic_identity.domain_id_unknown")
	for field in ["definition_id", "ruleset_id", "source_catalog_id"]:
		if not WIRE.is_stable_id(identity.get(field)):
			return WIRE.invalid_result("semantic_identity.%s_invalid" % field)
	if not WIRE.is_positive_integer(identity.get("definition_revision")):
		return WIRE.invalid_result("semantic_identity.definition_revision_invalid")
	if not WIRE.is_fingerprint(identity.get("source_definition_fingerprint")):
		return WIRE.invalid_result("semantic_identity.source_fingerprint_invalid")
	if not WIRE.is_fingerprint(identity.get("identity_fingerprint")) \
			or str(identity.get("identity_fingerprint", "")) \
			!= WIRE.fingerprint(identity, "identity_fingerprint"):
		return WIRE.invalid_result("semantic_identity.identity_fingerprint_invalid")
	return WIRE.valid_result()
