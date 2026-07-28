@tool
extends Node
class_name AiCardBatchObservationSourceOwner

const OBSERVATION = preload("res://scripts/semantic/ai_card_batch_observation_v1.gd")

var _issued_observation_count := 0
var _rejected_observation_count := 0
var _last_observation_fingerprint := ""
var _authorized_actor_id := ""
var _authorized_seat_index := -1
var _authorized_source_revision := -1
var _authorization_revision := 0


func configure_authorized_actor(actor_id: String, seat_index: int, source_revision: int) -> bool:
	var normalized_actor_id := actor_id.strip_edges()
	if not _authorized_actor_id.is_empty() \
			or normalized_actor_id.is_empty() \
			or seat_index < 0 \
			or source_revision < 0:
		return false
	_authorized_actor_id = normalized_actor_id
	_authorized_seat_index = seat_index
	_authorized_source_revision = source_revision
	_authorization_revision += 1
	return true


func issue_observation(owner_authorized_source: Dictionary) -> Dictionary:
	if _authorized_actor_id.is_empty() \
			or str(owner_authorized_source.get("viewer_actor_id", "")) != _authorized_actor_id \
			or int(owner_authorized_source.get("viewer_seat_index", -1)) != _authorized_seat_index \
			or int(owner_authorized_source.get("source_revision", -1)) != _authorized_source_revision:
		_rejected_observation_count += 1
		return {}
	var observation := OBSERVATION.build_authorized(
		owner_authorized_source,
		OBSERVATION.AUTHORITY_OWNER_ID
	)
	if observation.is_empty():
		_rejected_observation_count += 1
		return {}
	_issued_observation_count += 1
	_last_observation_fingerprint = str(
		observation.get("observation_fingerprint", "")
	)
	return observation.duplicate(true)


func debug_snapshot() -> Dictionary:
	return {
		"authority_owner_id": OBSERVATION.AUTHORITY_OWNER_ID,
		"issued_observation_count": _issued_observation_count,
		"rejected_observation_count": _rejected_observation_count,
		"rng_consumption_count": 0,
		"stores_observation_payloads": false,
		"last_observation_fingerprint": _last_observation_fingerprint,
		"authorized_actor_id": _authorized_actor_id,
		"authorized_seat_index": _authorized_seat_index,
		"authorized_source_revision": _authorized_source_revision,
		"authorization_revision": _authorization_revision,
		"viewer_identity_binding_required": true,
	}
