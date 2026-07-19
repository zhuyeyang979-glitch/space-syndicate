@tool
extends Node
class_name IntelPrivateCommandPort

signal receipt_ready(receipt: IntelPrivateCommandReceipt)

const RECEIPT_CACHE_LIMIT := 128
const CITY_COMMANDS := [
	&"set_city_owner_guess",
	&"clear_city_owner_guess",
	&"set_city_guess_confidence",
	&"set_city_guess_reason",
]
const CARD_COMMANDS := [
	&"set_card_history_note",
	&"set_card_history_tags",
	&"set_card_history_suspects",
	&"set_card_history_private_confidence",
	&"set_card_history_subscription",
	&"clear_card_history_annotation",
	&"use_residual_frame_catalog",
	&"use_public_evidence_exclusion",
]

@export var local_viewer_authorization_path: NodePath
@export var world_session_state_path: NodePath
@export var card_history_public_query_path: NodePath
@export var card_history_annotation_service_path: NodePath
@export var role_catalog_path: NodePath
@export var game_session_path: NodePath

var _receipt_cache: Dictionary = {}
var _receipt_order: Array[String] = []
var _submission_count := 0
var _success_count := 0
var _failure_count := 0
var _replay_count := 0
var _binding_mismatch_count := 0
var _owner_mutation_count := 0
var _save_dirty_mark_count := 0


func submit_command(command: IntelPrivateCommand) -> IntelPrivateCommandReceipt:
	_submission_count += 1
	if command == null:
		return _emit_receipt(_failure(null, "command_missing"))
	var validation := command.validation_report()
	if not bool(validation.get("valid", false)):
		return _emit_receipt(_failure(command, str(validation.get("reason_code", "command_invalid"))))
	var fingerprint := command.fingerprint()
	if _receipt_cache.has(command.command_id):
		var cached: Dictionary = _receipt_cache[command.command_id]
		if str(cached.get("fingerprint", "")) != fingerprint:
			_binding_mismatch_count += 1
			return _emit_receipt(_failure(command, "command_binding_mismatch"))
		_replay_count += 1
		var cached_receipt := cached.get("receipt") as IntelPrivateCommandReceipt
		return _emit_receipt(cached_receipt.replay_copy())
	if not _dependencies_ready():
		return _remember_and_emit(command, fingerprint, _failure(command, "dependency_missing"))
	if command.viewer_index != _authorization().authorized_viewer_index():
		return _remember_and_emit(command, fingerprint, _failure(command, "viewer_unauthorized"))
	if _game_session().is_finished():
		return _remember_and_emit(command, fingerprint, _failure(command, "session_finished"))
	var payload_validation := _validate_payload(command)
	if not bool(payload_validation.get("valid", false)):
		return _remember_and_emit(command, fingerprint, _failure(command, str(payload_validation.get("reason_code", "payload_invalid"))))
	var owner_revision_before := _owner_revision(command)
	if owner_revision_before.is_empty() or command.expected_owner_revision != owner_revision_before:
		return _remember_and_emit(command, fingerprint, _failure(command, "owner_revision_stale", owner_revision_before))
	var notification_before := _annotations().notification_count()
	var role_usage_before := _role_usage_total(command.viewer_index)
	var owner_result := _apply_owner_command(command)
	var owner_revision_after := _owner_revision(command)
	var changed := bool(owner_result.get("changed", false))
	var applied := bool(owner_result.get("applied", false))
	var receipt := _receipt(command)
	receipt.accepted = applied
	receipt.applied = applied
	receipt.changed = changed
	receipt.reason_code = str(owner_result.get("reason_code", "command_rejected"))
	receipt.owner_revision_before = owner_revision_before
	receipt.owner_revision_after = owner_revision_after if not owner_revision_after.is_empty() else owner_revision_before
	receipt.notification_delta = _annotations().notification_count() - notification_before
	receipt.role_usage_delta = _role_usage_total(command.viewer_index) - role_usage_before
	if changed:
		_owner_mutation_count += 1
		_game_session().mark_dirty("intel_private_command")
		_save_dirty_mark_count += 1
		receipt.save_dirty_delta = 1
	return _remember_and_emit(command, fingerprint, receipt)


func debug_snapshot() -> Dictionary:
	return {
		"port_id": "intel_private_command_port_v1",
		"submission_count": _submission_count,
		"success_count": _success_count,
		"failure_count": _failure_count,
		"replay_count": _replay_count,
		"binding_mismatch_count": _binding_mismatch_count,
		"owner_mutation_count": _owner_mutation_count,
		"save_dirty_mark_count": _save_dirty_mark_count,
		"receipt_cache_size": _receipt_cache.size(),
		"receipt_cache_limit": RECEIPT_CACHE_LIMIT,
		"viewer_authorization_required": true,
		"stale_commands_fail_closed": true,
		"generic_annotation_patch_used": false,
		"owns_gameplay_state": false,
		"owns_save_schema": false,
		"references_main": false,
	}


func _apply_owner_command(command: IntelPrivateCommand) -> Dictionary:
	var payload := command.payload
	if CITY_COMMANDS.has(command.command_kind):
		var region_id := command.subject_id.trim_prefix("region:")
		match command.command_kind:
			&"set_city_owner_guess":
				return _world().set_city_owner_guess(command.viewer_index, region_id, int(payload.get("suspected_player_index", -1)), int(payload.get("confidence", 0)), str(payload.get("reason_id", "")), command.expected_owner_revision)
			&"clear_city_owner_guess":
				return _world().clear_city_owner_guess(command.viewer_index, region_id, command.expected_owner_revision)
			&"set_city_guess_confidence":
				return _world().set_city_guess_confidence(command.viewer_index, region_id, int(payload.get("confidence", 0)), command.expected_owner_revision)
			&"set_city_guess_reason":
				return _world().set_city_guess_reason(command.viewer_index, region_id, str(payload.get("reason_id", "")), command.expected_owner_revision)
	var history_entry_id := command.subject_id
	match command.command_kind:
		&"set_card_history_note":
			return _annotations().set_note_exact(command.viewer_index, history_entry_id, str(payload.get("note_text", "")))
		&"set_card_history_tags":
			return _annotations().set_tags_exact(command.viewer_index, history_entry_id, payload.get("private_tags", []) as Array)
		&"set_card_history_suspects":
			return _annotations().set_suspects_exact(command.viewer_index, history_entry_id, payload.get("suspected_player_indices", []) as Array, _world().public_intel_projection().get("players", []).size())
		&"set_card_history_private_confidence":
			return _annotations().set_private_confidence_exact(command.viewer_index, history_entry_id, int(payload.get("private_confidence", 0)))
		&"set_card_history_subscription":
			return _annotations().set_subscription_exact(command.viewer_index, history_entry_id, bool(payload.get("subscribed", false)))
		&"clear_card_history_annotation":
			return _annotations().clear_annotation_exact(command.viewer_index, history_entry_id)
		&"use_residual_frame_catalog":
			return _annotations().use_residual_catalog_from_public_evidence(command.viewer_index, history_entry_id, _world().public_intel_projection().get("players", []).size(), _role_charge(command.viewer_index, "card_history_residual_catalog_charges"))
		&"use_public_evidence_exclusion":
			return _annotations().use_public_exclusion_from_public_evidence(command.viewer_index, history_entry_id, _role_charge(command.viewer_index, "card_history_public_exclusion_charges"))
	return {"applied": false, "changed": false, "reason_code": "command_kind_unsupported"}


func _validate_payload(command: IntelPrivateCommand) -> Dictionary:
	if CITY_COMMANDS.has(command.command_kind):
		if not _canonical_city_subject(command.subject_id):
			return _invalid("city_subject_invalid")
	else:
		if not _canonical_history_subject(command.subject_id) or _history_query().entry_by_id(command.subject_id).is_empty():
			return _invalid("card_history_subject_invalid")
	var payload := command.payload
	match command.command_kind:
		&"set_city_owner_guess":
			if not _exact_keys(payload, ["suspected_player_index", "confidence", "reason_id"]) \
					or not (payload.get("suspected_player_index") is int) \
					or not (payload.get("confidence") is int) \
					or not _string_value(payload.get("reason_id")):
				return _invalid("payload_invalid")
		&"clear_city_owner_guess", &"clear_card_history_annotation", &"use_residual_frame_catalog", &"use_public_evidence_exclusion":
			if not payload.is_empty():
				return _invalid("payload_invalid")
		&"set_city_guess_confidence":
			if not _exact_keys(payload, ["confidence"]) or not (payload.get("confidence") is int):
				return _invalid("payload_invalid")
		&"set_city_guess_reason":
			if not _exact_keys(payload, ["reason_id"]) or not _string_value(payload.get("reason_id")):
				return _invalid("payload_invalid")
		&"set_card_history_note":
			if not _exact_keys(payload, ["note_text"]) or not (payload.get("note_text") is String) or str(payload.get("note_text", "")).length() > 240:
				return _invalid("annotation_note_invalid")
		&"set_card_history_tags":
			if not _exact_keys(payload, ["private_tags"]) or not (payload.get("private_tags") is Array) or not _strict_tags(payload.get("private_tags", []) as Array):
				return _invalid("annotation_tags_invalid")
		&"set_card_history_suspects":
			if not _exact_keys(payload, ["suspected_player_indices"]) or not (payload.get("suspected_player_indices") is Array) or not _strict_indices(payload.get("suspected_player_indices", []) as Array, _world().public_intel_projection().get("players", []).size()):
				return _invalid("annotation_suspects_invalid")
			var current := _annotations().annotation_for_viewer(command.viewer_index, command.subject_id)
			var excluded: Array = current.get("excluded_player_indices", []) if current.get("excluded_player_indices", []) is Array else []
			for player_index_variant in payload.get("suspected_player_indices", []) as Array:
				if excluded.has(player_index_variant):
					return _invalid("annotation_indices_overlap")
		&"set_card_history_private_confidence":
			if not _exact_keys(payload, ["private_confidence"]) or not (payload.get("private_confidence") is int) or int(payload.get("private_confidence", -1)) not in [0, 1, 2, 3]:
				return _invalid("annotation_confidence_invalid")
		&"set_card_history_subscription":
			if not _exact_keys(payload, ["subscribed"]) or not (payload.get("subscribed") is bool):
				return _invalid("annotation_subscription_invalid")
		_:
			return _invalid("command_kind_unsupported")
	return {"valid": true, "reason_code": ""}


func _owner_revision(command: IntelPrivateCommand) -> String:
	if CITY_COMMANDS.has(command.command_kind):
		return _world().city_inference_owner_revision(command.viewer_index)
	if CARD_COMMANDS.has(command.command_kind):
		return _annotations().owner_revision_for_viewer(command.viewer_index)
	return ""


func _role_charge(viewer_index: int, field_name: String) -> int:
	var public_players: Array = _world().public_intel_projection().get("players", [])
	if viewer_index < 0 or viewer_index >= public_players.size() or not (public_players[viewer_index] is Dictionary):
		return 0
	var role_index := int((public_players[viewer_index] as Dictionary).get("role_index", -1))
	return maxi(0, int(_roles().public_definition_at(role_index).get(field_name, 0)))


func _role_usage_total(viewer_index: int) -> int:
	var usage := _annotations().role_usage_snapshot(viewer_index)
	return int(usage.get("residual_catalog", 0)) + int(usage.get("public_exclusion", 0))


func _remember_and_emit(command: IntelPrivateCommand, fingerprint: String, receipt: IntelPrivateCommandReceipt) -> IntelPrivateCommandReceipt:
	_receipt_cache[command.command_id] = {"fingerprint": fingerprint, "receipt": receipt.duplicate_receipt()}
	_receipt_order.append(command.command_id)
	while _receipt_order.size() > RECEIPT_CACHE_LIMIT:
		_receipt_cache.erase(_receipt_order.pop_front())
	return _emit_receipt(receipt)


func _emit_receipt(receipt: IntelPrivateCommandReceipt) -> IntelPrivateCommandReceipt:
	if receipt.applied:
		_success_count += 1
	else:
		_failure_count += 1
	receipt_ready.emit(receipt)
	return receipt


func _failure(command: IntelPrivateCommand, reason_code: String, owner_revision: String = "") -> IntelPrivateCommandReceipt:
	var receipt := _receipt(command)
	receipt.reason_code = reason_code
	receipt.owner_revision_before = owner_revision
	receipt.owner_revision_after = owner_revision
	return receipt


func _receipt(command: IntelPrivateCommand) -> IntelPrivateCommandReceipt:
	var receipt := IntelPrivateCommandReceipt.new()
	if command != null:
		receipt.command_id = command.command_id
		receipt.command_kind = command.command_kind
		receipt.viewer_index = command.viewer_index
		receipt.subject_id = command.subject_id
	return receipt


func _dependencies_ready() -> bool:
	return _authorization() != null and _world() != null and _history_query() != null \
		and _annotations() != null and _roles() != null and _game_session() != null


func _canonical_city_subject(subject_id: String) -> bool:
	if not subject_id.begins_with("region:"):
		return false
	var region_id := subject_id.trim_prefix("region:")
	return not region_id.is_empty() and region_id.strip_edges() == region_id and _world().district_index_for_region_id(region_id) >= 0


func _canonical_history_subject(subject_id: String) -> bool:
	if not subject_id.begins_with("card-history:"):
		return false
	var suffix := subject_id.trim_prefix("card-history:")
	return suffix.is_valid_int() and int(suffix) >= 0 and str(int(suffix)) == suffix


func _exact_keys(payload: Dictionary, expected: Array) -> bool:
	if payload.keys().size() != expected.size():
		return false
	for key in expected:
		if not payload.has(key):
			return false
	return true


func _strict_tags(tags: Array) -> bool:
	if tags.size() > 8:
		return false
	var seen: Array[String] = []
	for tag_variant in tags:
		if not (tag_variant is String):
			return false
		var tag := str(tag_variant)
		if tag.is_empty() or tag.length() > 32 or tag.strip_edges() != tag or seen.has(tag):
			return false
		seen.append(tag)
	return true


func _strict_indices(indices: Array, player_count: int) -> bool:
	var values: Array[int] = []
	for index_variant in indices:
		if not (index_variant is int):
			return false
		var player_index := int(index_variant)
		if player_index < 0 or player_index >= player_count or values.has(player_index):
			return false
		values.append(player_index)
	var sorted := values.duplicate()
	sorted.sort()
	return values == sorted


func _string_value(value: Variant) -> bool:
	return value is String or value is StringName


func _invalid(reason_code: String) -> Dictionary:
	return {"valid": false, "reason_code": reason_code}


func _authorization() -> LocalViewerAuthorization:
	return get_node_or_null(local_viewer_authorization_path) as LocalViewerAuthorization


func _world() -> WorldSessionState:
	return get_node_or_null(world_session_state_path) as WorldSessionState


func _history_query() -> CardHistoryPublicQueryPort:
	return get_node_or_null(card_history_public_query_path) as CardHistoryPublicQueryPort


func _annotations() -> CardHistoryPrivateAnnotationService:
	return get_node_or_null(card_history_annotation_service_path) as CardHistoryPrivateAnnotationService


func _roles() -> RoleCatalogRuntimeService:
	return get_node_or_null(role_catalog_path) as RoleCatalogRuntimeService


func _game_session() -> GameSessionRuntimeController:
	return get_node_or_null(game_session_path) as GameSessionRuntimeController
