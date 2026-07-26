@tool
extends Node
class_name CardSemanticSourceAuthorizationPort

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const CARD_SCHEMA := preload(
	"res://scripts/cards/semantic/card_semantic_schema_v1.gd"
)
const AUTHORIZED_ENVELOPE := preload(
	"res://scripts/cards/semantic/authorized_card_semantic_envelope_v1.gd"
)
const INSTANCE_STATE := preload(
	"res://scripts/cards/semantic/card_instance_decision_state_v1.gd"
)

const SCHEMA_VERSION := 1
const SOURCE_KIND_OWN_HAND := "own_hand"
const VISIBILITY_SCOPE_ACTOR_PRIVATE := "actor_private"
const JOURNAL_LIMIT := 128
const REQUEST_BINDING_LIMIT := 4096
const MICROSECONDS_PER_SECOND := 1000000

const REASON_AUTHORIZED := "authorized"
const REASON_SOURCE_KIND_UNSUPPORTED := "source_kind_unsupported"
const REASON_CAPABILITY_REJECTED := "capability_rejected"
const REASON_DEPENDENCY_UNAVAILABLE := "dependency_unavailable"
const REASON_SOURCE_ATTESTATION_FAILED := "source_attestation_failed"
const REASON_SOURCE_ATTESTATION_STALE := "source_attestation_stale"
const REASON_SOURCE_CARD_RECORD_INVALID := "source_card_record_invalid"
const REASON_SOURCE_CARD_IDENTITY_INVALID := "source_card_identity_invalid"
const REASON_RUNTIME_INSTANCE_ID_INVALID := "runtime_instance_id_invalid"
const REASON_SOURCE_INSTANCE_STATE_INVALID := "source_instance_state_invalid"
const REASON_REQUEST_ID_INVALID := "request_id_invalid"
const REASON_REQUEST_ID_COLLISION := "request_id_collision"
const REASON_REQUEST_BINDING_CAPACITY_EXHAUSTED := \
	"request_binding_capacity_exhausted"
const REASON_REQUEST_REPLAY_MISMATCH := "request_replay_mismatch"
const REASON_SEMANTIC_COMPILE_FAILED := "semantic_compile_failed"
const REASON_SEMANTIC_CACHE_MISS := "semantic_cache_miss"
const REASON_SEMANTIC_SPEC_INVALID := "semantic_spec_invalid"
const REASON_SEMANTIC_SPEC_UNAUTHORIZED := "semantic_spec_unauthorized"
const REASON_INSTANCE_STATE_INVALID := "instance_state_invalid"
const REASON_ENVELOPE_INVALID := "authorized_envelope_invalid"
const REASON_RECEIPT_INVALID := "authorization_receipt_invalid"
const REASON_BUNDLE_INVALID := "authorized_bundle_invalid"
const REASON_BUNDLE_FINGERPRINT_INVALID := "bundle_fingerprint_invalid"
const REASON_REQUEST_NOT_JOURNALED := "request_not_journaled"
const REASON_JOURNAL_BUNDLE_MISMATCH := "journal_bundle_mismatch"

const RESULT_KEYS := [
	"schema_version",
	"accepted",
	"reason_id",
	"authorized_envelope_ref",
	"semantic_spec",
	"instance_decision_state",
	"authorization_receipt",
	"bundle_fingerprint",
]
const RECEIPT_BUILD_KEYS := [
	"schema_version",
	"receipt_id",
	"request_id",
	"accepted",
	"reason_id",
	"envelope_ref",
	"source_attestation_fingerprint",
	"static_record_fingerprint",
	"source_definition_fingerprint",
	"semantic_fingerprint",
	"instance_revision",
	"instance_state_fingerprint",
]
const RECEIPT_KEYS := RECEIPT_BUILD_KEYS + ["receipt_fingerprint"]
const STATIC_RECORD_KEYS := ["machine", "player", "developer"]

@export var ai_actor_hand_inventory_query_port_path := NodePath(
	"../AiActorHandInventoryQueryPort"
)
@export var card_semantic_catalog_service_path := NodePath(
	"../CardSemanticCatalogService"
)

var _capability: AiActorHandInventoryCapability
var _actor_capability_by_index: Dictionary = {}
var _actor_capabilities_sealed := false
var _capability_revision := 0
var _capability_bind_rejection_count := 0
var _authorization_attempt_count := 0
var _authorization_success_count := 0
var _rejection_count := 0
var _replay_count := 0
var _collision_count := 0
var _validation_attempt_count := 0
var _validation_success_count := 0
var _validation_failure_count := 0
var _journal_eviction_count := 0
var _hand_snapshot_query_count := 0
var _successful_hand_snapshot_query_count := 0
var _source_revalidation_count := 0
var _catalog_compile_request_count := 0
var _catalog_spec_authorization_count := 0
var _detached_bundle_copy_count := 0
var _binding_fingerprint_by_request_fingerprint: Dictionary = {}
var _bundle_fingerprint_by_request_fingerprint: Dictionary = {}
var _journal_order: Array[String] = []


func bind_ai_capability(capability: AiActorHandInventoryCapability) -> bool:
	if capability == null:
		_capability_bind_rejection_count += 1
		return false
	if _capability != null:
		if capability == _capability:
			return true
		_capability_bind_rejection_count += 1
		return false
	var hand_port := _hand_port()
	if hand_port == null or not hand_port.bind_ai_capability(capability):
		_capability_bind_rejection_count += 1
		return false
	_capability = capability
	_capability_revision = 1
	return true


func bind_actor_capability(
	root_capability: AiActorHandInventoryCapability,
	actor_capability: AiActorHandInventoryCapability,
	actor_index: int
) -> bool:
	if _actor_capabilities_sealed or root_capability == null \
			or root_capability != _capability or actor_capability == null \
			or actor_capability == root_capability or actor_index < 0:
		_capability_bind_rejection_count += 1
		return false
	if _actor_capability_by_index.has(actor_index):
		var existing := _actor_capability_by_index.get(actor_index) \
			as AiActorHandInventoryCapability
		if existing == actor_capability:
			return true
		_capability_bind_rejection_count += 1
		return false
	for existing_variant in _actor_capability_by_index.values():
		if existing_variant == actor_capability:
			_capability_bind_rejection_count += 1
			return false
	_actor_capability_by_index[actor_index] = actor_capability
	return true


func seal_actor_capabilities(
	root_capability: AiActorHandInventoryCapability
) -> bool:
	if root_capability == null or root_capability != _capability \
			or _actor_capability_by_index.is_empty():
		_capability_bind_rejection_count += 1
		return false
	_actor_capabilities_sealed = true
	return true


func is_ready() -> bool:
	var hand_port := _hand_port()
	var catalog := _catalog_service()
	if _capability == null or not _actor_capabilities_sealed \
			or hand_port == null or catalog == null \
			or not hand_port.is_ready():
		return false
	return bool(catalog.validation_snapshot().get("configured", false))


func authorize_source(
	source_kind: String,
	capability: AiActorHandInventoryCapability,
	actor_index: int,
	slot_index: int,
	request_id: String = ""
) -> Dictionary:
	if source_kind != SOURCE_KIND_OWN_HAND:
		_authorization_attempt_count += 1
		return _reject(REASON_SOURCE_KIND_UNSUPPORTED)
	return _authorize_own_hand_card(
		capability,
		actor_index,
		slot_index,
		request_id
	)


func authorize_own_hand_card(
	capability: AiActorHandInventoryCapability,
	actor_index: int,
	slot_index: int,
	request_id: String = ""
) -> Dictionary:
	return _authorize_own_hand_card(
		capability,
		actor_index,
		slot_index,
		request_id
	)


func validate_authorized_bundle(bundle: Dictionary) -> Dictionary:
	_validation_attempt_count += 1
	if _capability == null or not is_ready():
		return _validation_reject(REASON_DEPENDENCY_UNAVAILABLE)
	var shape_reason := _bundle_shape_reason(bundle)
	if not shape_reason.is_empty():
		return _validation_reject(shape_reason)
	var envelope := bundle.get("authorized_envelope_ref", {}) as Dictionary
	var semantic_spec := bundle.get("semantic_spec", {}) as Dictionary
	var state := bundle.get("instance_decision_state", {}) as Dictionary
	var request_fingerprint := _journal_request_fingerprint(
		str(envelope.get("request_id", "")),
		str(envelope.get("session_id", "")),
		int(envelope.get("session_revision", -1))
	)
	if request_fingerprint.is_empty() \
			or not _binding_fingerprint_by_request_fingerprint.has(
				request_fingerprint
			) \
			or not _bundle_fingerprint_by_request_fingerprint.has(
				request_fingerprint
			):
		return _validation_reject(REASON_REQUEST_NOT_JOURNALED)
	if str(
		_bundle_fingerprint_by_request_fingerprint.get(
			request_fingerprint,
			""
		)
	) != str(bundle.get("bundle_fingerprint", "")):
		return _validation_reject(REASON_JOURNAL_BUNDLE_MISMATCH)
	var viewer_ref := envelope.get("viewer_ref", {}) as Dictionary
	var actor_index := int(viewer_ref.get("actor_index", -1))
	var slot_index := int(envelope.get("source_slot", -1))
	var hand_port := _hand_port()
	_hand_snapshot_query_count += 1
	_source_revalidation_count += 1
	var attestation := hand_port.actor_hand_slot_attestation(
		_capability,
		actor_index,
		slot_index
	)
	if attestation.is_empty():
		return _validation_reject(REASON_SOURCE_ATTESTATION_STALE)
	_successful_hand_snapshot_query_count += 1
	var material := _source_material(attestation)
	if not bool(material.get("valid", false)):
		return _validation_reject(REASON_SOURCE_ATTESTATION_STALE)
	var expected_state := _build_instance_state(attestation, material)
	if expected_state.is_empty() or expected_state != state:
		return _validation_reject(REASON_SOURCE_ATTESTATION_STALE)
	var binding_fingerprint := _binding_fingerprint(
		attestation,
		material,
		expected_state
	)
	if binding_fingerprint.is_empty() \
			or str(
				_binding_fingerprint_by_request_fingerprint.get(
					request_fingerprint,
					""
				)
			) != binding_fingerprint:
		return _validation_reject(REASON_SOURCE_ATTESTATION_STALE)
	if str((semantic_spec.get("identity", {}) as Dictionary).get(
		"card_id",
		""
	)) != str(material.get("card_id", "")):
		return _validation_reject(REASON_BUNDLE_INVALID)
	var static_record := material.get("static_record", {}) as Dictionary
	var source_definition_fingerprint := \
		_expected_source_definition_fingerprint(semantic_spec, static_record)
	if source_definition_fingerprint.is_empty() \
			or source_definition_fingerprint \
				!= str(envelope.get("source_definition_fingerprint", "")) \
			or source_definition_fingerprint \
				!= str(semantic_spec.get(
					"source_definition_fingerprint",
					""
				)):
		return _validation_reject(REASON_BUNDLE_INVALID)
	_catalog_spec_authorization_count += 1
	var catalog_authorization := _catalog_service().authorize_semantic_spec(
		semantic_spec
	)
	if not bool(catalog_authorization.get("ok", false)) \
			or (catalog_authorization.get("spec", {}) as Dictionary) \
				!= semantic_spec:
		return _validation_reject(REASON_SEMANTIC_SPEC_UNAUTHORIZED)
	_validation_success_count += 1
	_detached_bundle_copy_count += 1
	return bundle.duplicate(true)


func debug_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"port_ready": is_ready(),
		"capability_bound": _capability != null,
		"capability_revision": _capability_revision,
		"capability_bind_rejection_count": _capability_bind_rejection_count,
		"authorization_attempt_count": _authorization_attempt_count,
		"authorization_success_count": _authorization_success_count,
		"rejection_count": _rejection_count,
		"replay_count": _replay_count,
		"collision_count": _collision_count,
		"validation_attempt_count": _validation_attempt_count,
		"validation_success_count": _validation_success_count,
		"validation_failure_count": _validation_failure_count,
		"journal_entry_count": _journal_order.size(),
		"journal_limit": JOURNAL_LIMIT,
		"journal_eviction_count": _journal_eviction_count,
		"request_binding_count": (
			_binding_fingerprint_by_request_fingerprint.size()
		),
		"request_binding_limit": REQUEST_BINDING_LIMIT,
		"hand_snapshot_query_count": _hand_snapshot_query_count,
		"source_revalidation_count": _source_revalidation_count,
		"actor_state_query_proxy_count": _hand_snapshot_query_count,
		"card_inventory_policy_query_lower_bound_count": (
			_successful_hand_snapshot_query_count * 3
		),
		"catalog_compile_request_count": _catalog_compile_request_count,
		"catalog_spec_authorization_count": _catalog_spec_authorization_count,
		"detached_bundle_copy_count": _detached_bundle_copy_count,
		"journal_fingerprint": _journal_fingerprint(),
		"journal_fingerprint_only": true,
		"stores_authorized_payloads": false,
	}


func _authorize_own_hand_card(
	capability: AiActorHandInventoryCapability,
	actor_index: int,
	slot_index: int,
	request_id: String
) -> Dictionary:
	_authorization_attempt_count += 1
	if not _actor_capability_matches(capability, actor_index):
		return _reject(REASON_CAPABILITY_REJECTED)
	if not is_ready():
		return _reject(REASON_DEPENDENCY_UNAVAILABLE)
	var hand_port := _hand_port()
	_hand_snapshot_query_count += 1
	var attestation := hand_port.actor_hand_slot_attestation(
		_capability,
		actor_index,
		slot_index
	)
	if attestation.is_empty():
		return _reject(REASON_SOURCE_ATTESTATION_FAILED)
	_successful_hand_snapshot_query_count += 1
	_hand_snapshot_query_count += 1
	_source_revalidation_count += 1
	var source_is_current := hand_port.is_current_slot_attestation(
		_capability,
		attestation
	)
	if source_is_current:
		_successful_hand_snapshot_query_count += 1
	else:
		return _reject(REASON_SOURCE_ATTESTATION_FAILED)
	var material := _source_material(attestation)
	if not bool(material.get("valid", false)):
		return _reject(str(material.get(
			"reason_id",
			REASON_SOURCE_CARD_RECORD_INVALID
		)))
	var state := _build_instance_state(attestation, material)
	if state.is_empty():
		return _reject(REASON_INSTANCE_STATE_INVALID)
	var binding_fingerprint := _binding_fingerprint(
		attestation,
		material,
		state
	)
	if binding_fingerprint.is_empty():
		return _reject(REASON_BUNDLE_INVALID)
	var normalized_request_id := request_id
	if normalized_request_id.is_empty():
		normalized_request_id = _generated_runtime_id(
			"card-semantic-authorization-request",
			binding_fingerprint,
			binding_fingerprint
		)
	elif not _is_runtime_id(normalized_request_id):
		return _reject(REASON_REQUEST_ID_INVALID)
	if not _is_runtime_id(normalized_request_id):
		return _reject(REASON_REQUEST_ID_INVALID)
	var request_fingerprint := _journal_request_fingerprint(
		normalized_request_id,
		str(attestation.get("session_id", "")),
		int(attestation.get("session_revision", -1))
	)
	if request_fingerprint.is_empty():
		return _reject(REASON_REQUEST_ID_INVALID)
	var replay := false
	if _binding_fingerprint_by_request_fingerprint.has(request_fingerprint):
		if str(_binding_fingerprint_by_request_fingerprint.get(
			request_fingerprint,
			""
		)) != binding_fingerprint:
			_collision_count += 1
			return _reject(REASON_REQUEST_ID_COLLISION)
		if not _bundle_fingerprint_by_request_fingerprint.has(
			request_fingerprint
		):
			return _reject(REASON_REQUEST_NOT_JOURNALED)
		replay = true
	elif _binding_fingerprint_by_request_fingerprint.size() \
			>= REQUEST_BINDING_LIMIT:
		return _reject(REASON_REQUEST_BINDING_CAPACITY_EXHAUSTED)

	var static_record := material.get("static_record", {}) as Dictionary
	_catalog_compile_request_count += 1
	var compile_result := _catalog_service().compile_authorized({
		"schema_version": CARD_SCHEMA.SCHEMA_VERSION,
		"source_kind": SOURCE_KIND_OWN_HAND,
		"source_revision": "own_hand.%s" % str(attestation.get(
			"source_revision",
			""
		)),
		"visibility_scope_id": VISIBILITY_SCOPE_ACTOR_PRIVATE,
		"card_record": static_record.duplicate(true),
	})
	if not bool(compile_result.get("ok", false)):
		return _reject(REASON_SEMANTIC_COMPILE_FAILED)
	if not bool(compile_result.get("cache_hit", false)):
		return _reject(REASON_SEMANTIC_CACHE_MISS)
	var semantic_spec := compile_result.get("spec", {}) as Dictionary
	if not bool(CARD_SCHEMA.validate_semantic_spec(semantic_spec).get(
		"valid",
		false
	)):
		return _reject(REASON_SEMANTIC_SPEC_INVALID)
	var source_definition_fingerprint := str(compile_result.get(
		"source_definition_fingerprint",
		""
	))
	if source_definition_fingerprint.is_empty() \
			or source_definition_fingerprint \
				!= _expected_source_definition_fingerprint(
					semantic_spec,
					static_record
				) \
			or source_definition_fingerprint \
				!= str(semantic_spec.get(
					"source_definition_fingerprint",
					""
				)):
		return _reject(REASON_SEMANTIC_SPEC_INVALID)
	_catalog_spec_authorization_count += 1
	var catalog_authorization := _catalog_service().authorize_semantic_spec(
		semantic_spec
	)
	if not bool(catalog_authorization.get("ok", false)) \
			or (catalog_authorization.get("spec", {}) as Dictionary) \
				!= semantic_spec:
		return _reject(REASON_SEMANTIC_SPEC_UNAUTHORIZED)
	var envelope_id := _generated_runtime_id(
		"authorized-card-semantic-envelope",
		normalized_request_id,
		binding_fingerprint
	)
	var receipt_id := _generated_runtime_id(
		"card-semantic-authorization-receipt",
		normalized_request_id,
		CARD_SCHEMA.fingerprint({
			"binding_fingerprint": binding_fingerprint,
			"envelope_id": envelope_id,
		})
	)
	var envelope := _build_envelope(
		normalized_request_id,
		envelope_id,
		receipt_id,
		attestation,
		material,
		semantic_spec,
		state,
		source_definition_fingerprint
	)
	if envelope.is_empty():
		return _reject(REASON_ENVELOPE_INVALID)
	var receipt := _build_receipt(
		normalized_request_id,
		receipt_id,
		envelope_id,
		str(attestation.get("fingerprint", "")),
		str(material.get("static_record_fingerprint", "")),
		source_definition_fingerprint,
		str(semantic_spec.get("semantic_fingerprint", "")),
		str(state.get("instance_revision", "")),
		str(state.get("state_fingerprint", ""))
	)
	if receipt.is_empty():
		return _reject(REASON_RECEIPT_INVALID)
	var bundle := _success_bundle(envelope, semantic_spec, state, receipt)
	if not _bundle_shape_reason(bundle).is_empty():
		return _reject(REASON_BUNDLE_INVALID)
	if replay:
		if not _bundle_fingerprint_by_request_fingerprint.has(
			request_fingerprint
		) or str(_bundle_fingerprint_by_request_fingerprint.get(
			request_fingerprint,
			""
		)) != str(bundle.get("bundle_fingerprint", "")):
			return _reject(REASON_REQUEST_REPLAY_MISMATCH)
		_replay_count += 1
	else:
		if not _remember_request(
			request_fingerprint,
			binding_fingerprint,
			str(bundle.get("bundle_fingerprint", ""))
		):
			return _reject(REASON_REQUEST_BINDING_CAPACITY_EXHAUSTED)
	_authorization_success_count += 1
	_detached_bundle_copy_count += 1
	return bundle.duplicate(true)


func _source_material(attestation: Dictionary) -> Dictionary:
	if not CARD_SCHEMA.is_pure_data(attestation) \
			or attestation.keys() \
				!= AiActorHandInventoryQueryPort.SLOT_ATTESTATION_KEYS \
			or attestation.get("schema_version") \
				!= AiActorHandInventoryQueryPort.SCHEMA_VERSION \
			or str(attestation.get("visibility_scope", "")) \
				!= VISIBILITY_SCOPE_ACTOR_PRIVATE \
			or not _is_runtime_id(attestation.get("session_id")) \
			or not WIRE.is_nonnegative_integer(
				attestation.get("session_revision")
			) \
			or not WIRE.is_fingerprint(attestation.get("source_revision")) \
			or not WIRE.is_fingerprint(attestation.get("source_fingerprint")) \
			or not WIRE.is_fingerprint(attestation.get("fingerprint")):
		return _invalid_material(REASON_SOURCE_ATTESTATION_FAILED)
	var slot_value: Variant = attestation.get("slot")
	if not (slot_value is Dictionary):
		return _invalid_material(REASON_SOURCE_ATTESTATION_FAILED)
	var slot := slot_value as Dictionary
	if slot.keys() != AiActorHandInventoryQueryPort.SLOT_KEYS \
			or not bool(slot.get("occupied", false)) \
			or int(slot.get("slot_index", -1)) < 0:
		return _invalid_material(REASON_SOURCE_ATTESTATION_FAILED)
	var card_value: Variant = slot.get("card")
	if not (card_value is Dictionary):
		return _invalid_material(REASON_SOURCE_CARD_RECORD_INVALID)
	var card := card_value as Dictionary
	for block_id in ["machine", "player", "developer"]:
		if not (card.get(block_id) is Dictionary):
			return _invalid_material(REASON_SOURCE_CARD_RECORD_INVALID)
	var static_record := {
		"machine": (card.get("machine", {}) as Dictionary).duplicate(true),
		"player": (card.get("player", {}) as Dictionary).duplicate(true),
		"developer": (card.get("developer", {}) as Dictionary).duplicate(true),
	}
	if not CARD_SCHEMA.is_pure_data(static_record) \
			or static_record.keys() \
				!= STATIC_RECORD_KEYS:
		return _invalid_material(REASON_SOURCE_CARD_RECORD_INVALID)
	var machine := static_record.get("machine", {}) as Dictionary
	var card_id := str(machine.get("card_id", ""))
	if not CARD_SCHEMA.is_stable_id(card_id) \
			or card_id != str(slot.get("card_id", "")):
		return _invalid_material(REASON_SOURCE_CARD_IDENTITY_INVALID)
	var runtime_instance_id := str(slot.get("runtime_instance_id", ""))
	if not _is_runtime_id(runtime_instance_id) \
			or runtime_instance_id \
				!= str(card.get("runtime_instance_id", "")):
		return _invalid_material(REASON_RUNTIME_INSTANCE_ID_INVALID)
	var static_record_fingerprint := CARD_SCHEMA.fingerprint(static_record)
	if not WIRE.is_fingerprint(static_record_fingerprint):
		return _invalid_material(REASON_SOURCE_CARD_RECORD_INVALID)
	var cooldown_microseconds := _cooldown_microseconds(
		slot.get("cooldown_left")
	)
	if cooldown_microseconds < 0:
		return _invalid_material(REASON_SOURCE_INSTANCE_STATE_INVALID)
	return {
		"valid": true,
		"reason_id": REASON_AUTHORIZED,
		"static_record": static_record,
		"static_record_fingerprint": static_record_fingerprint,
		"card_id": card_id,
		"runtime_instance_id": runtime_instance_id,
		"queued": bool(slot.get("queued_for_resolution", false)),
		"locked": float(slot.get("lock_left", 0.0)) > 0.0,
		"cooldown_remaining_microseconds": cooldown_microseconds,
	}


func _build_instance_state(
	attestation: Dictionary,
	material: Dictionary
) -> Dictionary:
	return INSTANCE_STATE.build({
		"schema_version": INSTANCE_STATE.SCHEMA_VERSION,
		"instance_id": str(material.get("runtime_instance_id", "")),
		"card_id": str(material.get("card_id", "")),
		"source_kind": SOURCE_KIND_OWN_HAND,
		"visibility_scope_id": VISIBILITY_SCOPE_ACTOR_PRIVATE,
		"viewer_ref": _viewer_ref(int(attestation.get("actor_index", -1))),
		"session_id": str(attestation.get("session_id", "")),
		"session_revision": int(attestation.get("session_revision", -1)),
		"source_revision": str(attestation.get("source_revision", "")),
		"source_slot": int((attestation.get("slot", {}) as Dictionary).get(
			"slot_index",
			-1
		)),
		"queued": bool(material.get("queued", false)),
		"locked": bool(material.get("locked", false)),
		"cooldown_remaining_microseconds": int(material.get(
			"cooldown_remaining_microseconds",
			-1
		)),
	})


func _binding_fingerprint(
	attestation: Dictionary,
	material: Dictionary,
	state: Dictionary
) -> String:
	return CARD_SCHEMA.fingerprint({
		"schema_version": SCHEMA_VERSION,
		"source_kind": SOURCE_KIND_OWN_HAND,
		"visibility_scope_id": VISIBILITY_SCOPE_ACTOR_PRIVATE,
		"viewer_ref": state.get("viewer_ref", {}),
		"session_id": attestation.get("session_id", ""),
		"session_revision": attestation.get("session_revision", -1),
		"hand_source_revision": attestation.get("source_revision", ""),
		"hand_source_fingerprint": attestation.get("source_fingerprint", ""),
		"source_attestation_fingerprint": attestation.get("fingerprint", ""),
		"source_slot": state.get("source_slot", -1),
		"runtime_instance_id": material.get("runtime_instance_id", ""),
		"static_record_fingerprint": material.get(
			"static_record_fingerprint",
			""
		),
		"instance_revision": state.get("instance_revision", ""),
		"instance_state_fingerprint": state.get("state_fingerprint", ""),
	})


func _build_envelope(
	request_id: String,
	envelope_id: String,
	receipt_id: String,
	attestation: Dictionary,
	material: Dictionary,
	semantic_spec: Dictionary,
	state: Dictionary,
	source_definition_fingerprint: String
) -> Dictionary:
	return AUTHORIZED_ENVELOPE.build({
		"schema_version": AUTHORIZED_ENVELOPE.SCHEMA_VERSION,
		"envelope_id": envelope_id,
		"request_id": request_id,
		"source_kind": SOURCE_KIND_OWN_HAND,
		"source_owner_id": AUTHORIZED_ENVELOPE.SOURCE_OWNER_ID,
		"attestation_port_id": AUTHORIZED_ENVELOPE.ATTESTATION_PORT_ID,
		"visibility_scope_id": VISIBILITY_SCOPE_ACTOR_PRIVATE,
		"viewer_ref": state.get("viewer_ref", {}),
		"session_id": str(attestation.get("session_id", "")),
		"session_revision": int(attestation.get("session_revision", -1)),
		"hand_source_revision": str(attestation.get("source_revision", "")),
		"hand_source_fingerprint": str(attestation.get(
			"source_fingerprint",
			""
		)),
		"card_id": str(material.get("card_id", "")),
		"source_slot": int(state.get("source_slot", -1)),
		"runtime_instance_id": str(material.get("runtime_instance_id", "")),
		"static_record_fingerprint": str(material.get(
			"static_record_fingerprint",
			""
		)),
		"source_definition_fingerprint": source_definition_fingerprint,
		"semantic_fingerprint": str(semantic_spec.get(
			"semantic_fingerprint",
			""
		)),
		"instance_revision": str(state.get("instance_revision", "")),
		"instance_state_fingerprint": str(state.get("state_fingerprint", "")),
		"authorization_receipt_ref": receipt_id,
	})


func _build_receipt(
	request_id: String,
	receipt_id: String,
	envelope_id: String,
	source_attestation_fingerprint: String,
	static_record_fingerprint: String,
	source_definition_fingerprint: String,
	semantic_fingerprint: String,
	instance_revision: String,
	instance_state_fingerprint: String
) -> Dictionary:
	var unsealed := {
		"schema_version": SCHEMA_VERSION,
		"receipt_id": receipt_id,
		"request_id": request_id,
		"accepted": true,
		"reason_id": REASON_AUTHORIZED,
		"envelope_ref": envelope_id,
		"source_attestation_fingerprint": source_attestation_fingerprint,
		"static_record_fingerprint": static_record_fingerprint,
		"source_definition_fingerprint": source_definition_fingerprint,
		"semantic_fingerprint": semantic_fingerprint,
		"instance_revision": instance_revision,
		"instance_state_fingerprint": instance_state_fingerprint,
	}
	if not WIRE.is_closed_data(unsealed) \
			or not WIRE.exact_fields(unsealed, RECEIPT_BUILD_KEYS):
		return {}
	var receipt := WIRE.sealed_copy(unsealed, "receipt_fingerprint")
	return receipt if _receipt_reason(receipt).is_empty() else {}


func _success_bundle(
	envelope: Dictionary,
	semantic_spec: Dictionary,
	state: Dictionary,
	receipt: Dictionary
) -> Dictionary:
	var result := {
		"schema_version": SCHEMA_VERSION,
		"accepted": true,
		"reason_id": REASON_AUTHORIZED,
		"authorized_envelope_ref": envelope.duplicate(true),
		"semantic_spec": semantic_spec.duplicate(true),
		"instance_decision_state": state.duplicate(true),
		"authorization_receipt": receipt.duplicate(true),
		"bundle_fingerprint": "",
	}
	result["bundle_fingerprint"] = CARD_SCHEMA.fingerprint(
		result,
		"bundle_fingerprint"
	)
	return result


func _bundle_shape_reason(bundle: Dictionary) -> String:
	if not CARD_SCHEMA.is_pure_data(bundle) \
			or bundle.keys() != RESULT_KEYS \
			or bundle.get("schema_version") != SCHEMA_VERSION \
			or bundle.get("accepted") != true \
			or str(bundle.get("reason_id", "")) != REASON_AUTHORIZED:
		return REASON_BUNDLE_INVALID
	var envelope_value: Variant = bundle.get("authorized_envelope_ref")
	var spec_value: Variant = bundle.get("semantic_spec")
	var state_value: Variant = bundle.get("instance_decision_state")
	var receipt_value: Variant = bundle.get("authorization_receipt")
	if not (envelope_value is Dictionary) \
			or not (spec_value is Dictionary) \
			or not (state_value is Dictionary) \
			or not (receipt_value is Dictionary):
		return REASON_BUNDLE_INVALID
	var envelope := envelope_value as Dictionary
	var semantic_spec := spec_value as Dictionary
	var state := state_value as Dictionary
	var receipt := receipt_value as Dictionary
	if not bool(AUTHORIZED_ENVELOPE.validate(envelope).get("valid", false)):
		return REASON_ENVELOPE_INVALID
	if not bool(CARD_SCHEMA.validate_semantic_spec(semantic_spec).get(
		"valid",
		false
	)):
		return REASON_SEMANTIC_SPEC_INVALID
	if not bool(INSTANCE_STATE.validate(state).get("valid", false)):
		return REASON_INSTANCE_STATE_INVALID
	if not _receipt_reason(receipt).is_empty():
		return REASON_RECEIPT_INVALID
	if envelope.get("viewer_ref") != state.get("viewer_ref") \
			or envelope.get("session_id") != state.get("session_id") \
			or envelope.get("session_revision") != state.get("session_revision") \
			or envelope.get("hand_source_revision") \
				!= state.get("source_revision") \
			or envelope.get("source_slot") != state.get("source_slot") \
			or envelope.get("runtime_instance_id") != state.get("instance_id") \
			or envelope.get("card_id") != state.get("card_id") \
			or envelope.get("source_definition_fingerprint") \
				!= semantic_spec.get("source_definition_fingerprint") \
			or envelope.get("semantic_fingerprint") \
				!= semantic_spec.get("semantic_fingerprint") \
			or envelope.get("instance_revision") \
				!= state.get("instance_revision") \
			or envelope.get("instance_state_fingerprint") \
				!= state.get("state_fingerprint") \
			or envelope.get("authorization_receipt_ref") \
				!= receipt.get("receipt_id") \
			or envelope.get("request_id") != receipt.get("request_id") \
			or envelope.get("envelope_id") != receipt.get("envelope_ref") \
			or envelope.get("static_record_fingerprint") \
				!= receipt.get("static_record_fingerprint") \
			or envelope.get("source_definition_fingerprint") \
				!= receipt.get("source_definition_fingerprint") \
			or envelope.get("semantic_fingerprint") \
				!= receipt.get("semantic_fingerprint") \
			or state.get("instance_revision") \
				!= receipt.get("instance_revision") \
			or state.get("state_fingerprint") \
				!= receipt.get("instance_state_fingerprint"):
		return REASON_BUNDLE_INVALID
	var bundle_fingerprint := str(bundle.get("bundle_fingerprint", ""))
	if not WIRE.is_fingerprint(bundle_fingerprint) \
			or bundle_fingerprint \
				!= CARD_SCHEMA.fingerprint(bundle, "bundle_fingerprint"):
		return REASON_BUNDLE_FINGERPRINT_INVALID
	return ""


func _receipt_reason(receipt: Dictionary) -> String:
	if not WIRE.is_closed_data(receipt) \
			or receipt.keys() != RECEIPT_KEYS \
			or receipt.get("schema_version") != SCHEMA_VERSION \
			or receipt.get("accepted") != true \
			or str(receipt.get("reason_id", "")) != REASON_AUTHORIZED:
		return REASON_RECEIPT_INVALID
	for field in ["receipt_id", "request_id", "envelope_ref"]:
		if not _is_runtime_id(receipt.get(field)):
			return REASON_RECEIPT_INVALID
	for field in [
		"source_attestation_fingerprint",
		"static_record_fingerprint",
		"source_definition_fingerprint",
		"semantic_fingerprint",
		"instance_revision",
		"instance_state_fingerprint",
	]:
		if not WIRE.is_fingerprint(receipt.get(field)):
			return REASON_RECEIPT_INVALID
	if not WIRE.is_fingerprint(receipt.get("receipt_fingerprint")) \
			or str(receipt.get("receipt_fingerprint", "")) \
				!= WIRE.fingerprint(receipt, "receipt_fingerprint"):
		return REASON_RECEIPT_INVALID
	return ""


func _expected_source_definition_fingerprint(
	semantic_spec: Dictionary,
	static_record: Dictionary
) -> String:
	var source_catalog_id := str(semantic_spec.get("source_catalog_id", ""))
	var machine_value: Variant = static_record.get("machine")
	if not CARD_SCHEMA.is_stable_id(source_catalog_id) \
			or not (machine_value is Dictionary):
		return ""
	return CARD_SCHEMA.fingerprint({
		"source_catalog_id": source_catalog_id,
		"machine": (machine_value as Dictionary).duplicate(true),
	})


func _viewer_ref(actor_index: int) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"actor_ref_id": "player.%d" % actor_index,
		"actor_index": actor_index,
	}


func _generated_runtime_id(
	prefix: String,
	request_component: String,
	binding_component: String
) -> String:
	var suffix := CARD_SCHEMA.fingerprint({
		"prefix": prefix,
		"request_component": request_component,
		"binding_component": binding_component,
	})
	return "%s:%s" % [prefix, suffix] if not suffix.is_empty() else ""


func _journal_request_fingerprint(
	request_id: String,
	session_id: String,
	session_revision: int
) -> String:
	if not _is_runtime_id(request_id) or not _is_runtime_id(session_id) \
			or not WIRE.is_nonnegative_integer(session_revision):
		return ""
	return CARD_SCHEMA.fingerprint({
		"request_id": request_id,
		"session_id": session_id,
		"session_revision": session_revision,
	})


func _remember_request(
	request_fingerprint: String,
	binding_fingerprint: String,
	bundle_fingerprint: String
) -> bool:
	if not WIRE.is_fingerprint(request_fingerprint) \
			or not WIRE.is_fingerprint(binding_fingerprint) \
			or not WIRE.is_fingerprint(bundle_fingerprint) \
			or _binding_fingerprint_by_request_fingerprint.has(
				request_fingerprint
			):
		return false
	if _binding_fingerprint_by_request_fingerprint.size() \
			>= REQUEST_BINDING_LIMIT:
		return false
	while _journal_order.size() >= JOURNAL_LIMIT:
		var retired_request_fingerprint: String = _journal_order.pop_front()
		_bundle_fingerprint_by_request_fingerprint.erase(
			retired_request_fingerprint
		)
		_journal_eviction_count += 1
	_binding_fingerprint_by_request_fingerprint[request_fingerprint] = \
		binding_fingerprint
	_bundle_fingerprint_by_request_fingerprint[request_fingerprint] = \
		bundle_fingerprint
	_journal_order.append(request_fingerprint)
	return true


func _journal_fingerprint() -> String:
	var request_fingerprints := _journal_order.duplicate()
	request_fingerprints.sort()
	var entries: Array = []
	for request_fingerprint in request_fingerprints:
		entries.append({
			"request_fingerprint": request_fingerprint,
			"binding_fingerprint": str(
				_binding_fingerprint_by_request_fingerprint.get(
					request_fingerprint,
					""
				)
			),
			"bundle_fingerprint": str(
				_bundle_fingerprint_by_request_fingerprint.get(
					request_fingerprint,
					""
				)
			),
		})
	return CARD_SCHEMA.fingerprint({
		"schema_version": SCHEMA_VERSION,
		"entries": entries,
	})


func _cooldown_microseconds(value: Variant) -> int:
	if not (value is int or value is float):
		return -1
	var seconds := float(value)
	if not is_finite(seconds) or seconds < 0.0:
		return -1
	if seconds == 0.0:
		return 0
	var maximum_seconds := float(WIRE.MAX_SAFE_INTEGER) \
		/ float(MICROSECONDS_PER_SECOND)
	if seconds > maximum_seconds:
		return -1
	var microseconds := ceili(seconds * float(MICROSECONDS_PER_SECOND))
	return microseconds if WIRE.is_nonnegative_integer(microseconds) else -1


func _is_runtime_id(value: Variant) -> bool:
	return WIRE.is_ascii_reference(value) \
		and str(value) == str(value).strip_edges()


func _invalid_material(reason_id: String) -> Dictionary:
	return {"valid": false, "reason_id": reason_id}


func _reject(reason_id: String) -> Dictionary:
	_rejection_count += 1
	return _failure_result(reason_id)


func _validation_reject(reason_id: String) -> Dictionary:
	_validation_failure_count += 1
	return _reject(reason_id)


func _failure_result(reason_id: String) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"accepted": false,
		"reason_id": reason_id,
		"authorized_envelope_ref": {},
		"semantic_spec": {},
		"instance_decision_state": {},
		"authorization_receipt": {},
		"bundle_fingerprint": "",
	}


func _actor_capability_matches(
	capability: AiActorHandInventoryCapability,
	actor_index: int
) -> bool:
	return (
		_actor_capabilities_sealed
		and capability != null
		and actor_index >= 0
		and _actor_capability_by_index.get(actor_index) == capability
	)


func _hand_port() -> AiActorHandInventoryQueryPort:
	return get_node_or_null(ai_actor_hand_inventory_query_port_path) \
		as AiActorHandInventoryQueryPort


func _catalog_service() -> CardSemanticCatalogService:
	return get_node_or_null(card_semantic_catalog_service_path) \
		as CardSemanticCatalogService
