extends RefCounted
class_name IntelDossierActionIntent

const SCHEMA_VERSION := 1
const NAVIGATION_KINDS := [
	&"open_economy",
	&"open_card",
	&"open_monster",
	&"open_product",
	&"open_region",
	&"focus_history",
]

var schema_version := SCHEMA_VERSION
var intent_kind: StringName = &""
var viewer_index := -1
var subject_id := ""
var expected_owner_revision := ""
var payload: Dictionary = {}


static func from_dictionary(source: Dictionary) -> IntelDossierActionIntent:
	var expected := ["schema_version", "intent_kind", "viewer_index", "subject_id", "expected_owner_revision", "payload"]
	if source.keys().size() != expected.size():
		return null
	for key in expected:
		if not source.has(key):
			return null
	if not (source.get("schema_version") is int) \
			or not (source.get("viewer_index") is int) \
			or not (source.get("subject_id") is String) \
			or not (source.get("expected_owner_revision") is String) \
			or not (source.get("payload") is Dictionary):
		return null
	var intent := IntelDossierActionIntent.new()
	intent.schema_version = int(source.get("schema_version", 0))
	intent.intent_kind = StringName(source.get("intent_kind", ""))
	intent.viewer_index = int(source.get("viewer_index", -1))
	intent.subject_id = str(source.get("subject_id", ""))
	intent.expected_owner_revision = str(source.get("expected_owner_revision", ""))
	intent.payload = (source.get("payload", {}) as Dictionary).duplicate(true)
	return intent if intent.is_valid() else null


func is_valid() -> bool:
	if schema_version != SCHEMA_VERSION or viewer_index < 0 or subject_id.strip_edges() != subject_id:
		return false
	if not TablePresentationPureDataPolicy.is_pure_data(payload):
		return false
	if IntelPrivateCommand.COMMAND_KINDS.has(intent_kind):
		return not subject_id.is_empty() and not expected_owner_revision.is_empty()
	if not NAVIGATION_KINDS.has(intent_kind):
		return false
	return expected_owner_revision.is_empty()


func is_private_command() -> bool:
	return IntelPrivateCommand.COMMAND_KINDS.has(intent_kind)


func to_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"intent_kind": intent_kind,
		"viewer_index": viewer_index,
		"subject_id": subject_id,
		"expected_owner_revision": expected_owner_revision,
		"payload": payload.duplicate(true),
	}
