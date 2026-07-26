extends RefCounted
class_name CardInstanceDecisionStateV1

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const ENVELOPE := preload(
	"res://scripts/cards/semantic/authorized_card_semantic_envelope_v1.gd"
)

const SCHEMA_VERSION := 1
const SOURCE_KIND := "own_hand"
const VISIBILITY_SCOPE_ID := "actor_private"
const BUILD_FIELDS := [
	"schema_version",
	"instance_id",
	"card_id",
	"source_kind",
	"visibility_scope_id",
	"viewer_ref",
	"session_id",
	"session_revision",
	"source_revision",
	"source_slot",
	"queued",
	"locked",
	"cooldown_remaining_microseconds",
]
const FIELDS := [
	"schema_version",
	"instance_id",
	"card_id",
	"source_kind",
	"visibility_scope_id",
	"viewer_ref",
	"session_id",
	"session_revision",
	"source_revision",
	"source_slot",
	"instance_revision",
	"queued",
	"locked",
	"cooldown_remaining_microseconds",
	"state_fingerprint",
]


static func build(unsealed: Dictionary) -> Dictionary:
	if not WIRE.is_closed_data(unsealed) \
			or not WIRE.exact_fields(unsealed, BUILD_FIELDS):
		return {}
	var state := {
		"schema_version": unsealed.get("schema_version"),
		"instance_id": unsealed.get("instance_id"),
		"card_id": unsealed.get("card_id"),
		"source_kind": unsealed.get("source_kind"),
		"visibility_scope_id": unsealed.get("visibility_scope_id"),
		"viewer_ref": (unsealed.get("viewer_ref", {}) as Dictionary).duplicate(true),
		"session_id": unsealed.get("session_id"),
		"session_revision": unsealed.get("session_revision"),
		"source_revision": unsealed.get("source_revision"),
		"source_slot": unsealed.get("source_slot"),
		"instance_revision": WIRE.fingerprint(unsealed),
		"queued": unsealed.get("queued"),
		"locked": unsealed.get("locked"),
		"cooldown_remaining_microseconds": unsealed.get(
			"cooldown_remaining_microseconds"
		),
	}
	state["state_fingerprint"] = WIRE.fingerprint(state)
	return state if bool(validate(state).get("valid", false)) else {}


static func validate(value: Variant) -> Dictionary:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return WIRE.invalid_result("card_instance_decision_state.not_closed_data")
	var state := value as Dictionary
	if not WIRE.exact_fields(state, FIELDS):
		return WIRE.invalid_result("card_instance_decision_state.fields_invalid")
	if state.get("schema_version") != SCHEMA_VERSION:
		return WIRE.invalid_result(
			"card_instance_decision_state.schema_version_invalid"
		)
	if str(state.get("source_kind", "")) != SOURCE_KIND \
			or str(state.get("visibility_scope_id", "")) \
				!= VISIBILITY_SCOPE_ID:
		return WIRE.invalid_result("card_instance_decision_state.scope_invalid")
	if not _is_runtime_id(state.get("instance_id")) \
			or not _is_runtime_id(state.get("session_id")):
		return WIRE.invalid_result("card_instance_decision_state.runtime_id_invalid")
	if not WIRE.is_stable_id(state.get("card_id")):
		return WIRE.invalid_result("card_instance_decision_state.card_id_invalid")
	var viewer_error := ENVELOPE.viewer_ref_error(state.get("viewer_ref"))
	if not viewer_error.is_empty():
		return WIRE.invalid_result(
			"card_instance_decision_state.%s" % viewer_error
		)
	if not WIRE.is_nonnegative_integer(state.get("session_revision")) \
			or not WIRE.is_nonnegative_integer(state.get("source_slot")) \
			or not WIRE.is_nonnegative_integer(
				state.get("cooldown_remaining_microseconds")
			):
		return WIRE.invalid_result("card_instance_decision_state.revision_invalid")
	if not WIRE.is_fingerprint(state.get("source_revision")):
		return WIRE.invalid_result(
			"card_instance_decision_state.source_revision_invalid"
		)
	if not (state.get("queued") is bool) or not (state.get("locked") is bool):
		return WIRE.invalid_result("card_instance_decision_state.flags_invalid")
	if not WIRE.is_fingerprint(state.get("instance_revision")) \
			or str(state.get("instance_revision", "")) \
				!= _expected_instance_revision(state):
		return WIRE.invalid_result(
			"card_instance_decision_state.instance_revision_invalid"
		)
	if not WIRE.is_fingerprint(state.get("state_fingerprint")) \
			or str(state.get("state_fingerprint", "")) \
				!= WIRE.fingerprint(state, "state_fingerprint"):
		return WIRE.invalid_result(
			"card_instance_decision_state.fingerprint_invalid"
		)
	return WIRE.valid_result()


static func validation_error(state: Dictionary) -> String:
	var report := validate(state)
	return "" if bool(report.get("valid", false)) else str(report.get(
		"reason_id",
		"card_instance_decision_state.invalid"
	))


static func is_available(state: Dictionary) -> bool:
	return validation_error(state).is_empty() \
		and not bool(state.get("queued", false)) \
		and not bool(state.get("locked", false)) \
		and int(state.get("cooldown_remaining_microseconds", -1)) == 0


static func to_ai_projection_input(state: Dictionary) -> Dictionary:
	if not validation_error(state).is_empty():
		return {}
	return {
		"schema_version": SCHEMA_VERSION,
		"instance_id": str(state.get("instance_id", "")),
		"card_id": str(state.get("card_id", "")),
		"source_slot": int(state.get("source_slot", -1)),
		"instance_revision": str(state.get("instance_revision", "")),
		"queued": bool(state.get("queued", false)),
		"locked": bool(state.get("locked", false)),
		"cooldown_remaining_seconds": float(int(state.get(
			"cooldown_remaining_microseconds",
			0
		))) / 1000000.0,
	}


static func _expected_instance_revision(state: Dictionary) -> String:
	var revision_input := state.duplicate(true)
	revision_input.erase("instance_revision")
	revision_input.erase("state_fingerprint")
	return WIRE.fingerprint(revision_input)


static func _is_runtime_id(value: Variant) -> bool:
	return WIRE.is_ascii_reference(value) \
		and str(value) == str(value).strip_edges()
