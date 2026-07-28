@tool
extends Node
class_name PlayerCardDockViewerQueryPort

var _query_ports: TablePresentationQueryPorts
var _table_query: TablePresentationViewModelQuery
var _card_presentation: CardPresentationRuntimeService
var _projection_service := PlayerCardDockProjectionService.new()
var _query_count := 0
var _accepted_count := 0
var _rejected_count := 0
var _last_reason_id := "player-card-dock-query-unconfigured"


func configure(
	query_ports: TablePresentationQueryPorts,
	table_query: TablePresentationViewModelQuery,
	card_presentation: CardPresentationRuntimeService
) -> void:
	_query_ports = query_ports
	_table_query = table_query
	_card_presentation = card_presentation
	_last_reason_id = "player-card-dock-query-ready" if _is_configured() \
		else "player-card-dock-query-unconfigured"


func snapshot_for_viewer(viewer_index: int, expected_authorization_revision: int = -1) -> Dictionary:
	_query_count += 1
	if not _is_configured():
		return _reject("player-card-dock-query-unconfigured")
	var context := _query_ports.viewer_context()
	if context == null or not context.authorized or context.viewer_index != viewer_index \
			or not _query_ports.can_view_private_subject(viewer_index, viewer_index):
		return _reject("player-card-dock-viewer-unauthorized")
	if expected_authorization_revision >= 0 \
			and expected_authorization_revision != context.authorization_revision:
		return _reject("player-card-dock-authorization-stale")
	var private_projection := _query_ports.private_world_projection(viewer_index, viewer_index).to_dictionary()
	if not bool(private_projection.get("authorized", false)) \
			or int(private_projection.get("authorization_revision", -1)) != context.authorization_revision \
			or str(private_projection.get("visibility_scope", "")) != "viewer_private":
		return _reject("player-card-dock-private-query-rejected")
	var player: Dictionary = private_projection.get("player", {}) \
		if private_projection.get("player", {}) is Dictionary else {}
	var private_hand: Array = player.get("hand", []) if player.get("hand", []) is Array else []
	var hand_sources := _table_query.hand_presentation_sources_for_viewer(viewer_index)
	var hand_viewmodels: Array = []
	for source_variant in hand_sources:
		if not (source_variant is Dictionary):
			return _reject("player-card-dock-hand-source-invalid")
		var viewmodel := _card_presentation.compose_hand_card(source_variant as Dictionary)
		if viewmodel.is_empty():
			return _reject("player-card-dock-card-presentation-failed")
		hand_viewmodels.append(viewmodel)
	var projection := _projection_service.compose_shared_v06(
		viewer_index,
		"player.%d" % viewer_index,
		context.authorization_revision,
		_table_query.current_action_offer_revision(viewer_index),
		private_hand,
		hand_sources,
		hand_viewmodels
	)
	if projection.is_empty():
		return _reject("player-card-dock-projection-rejected")
	_accepted_count += 1
	_last_reason_id = "player-card-dock-projection-ready"
	return PlayerCardDockProjectionV1.detached_copy(projection)


func debug_snapshot() -> Dictionary:
	return {
		"configured": _is_configured(),
		"query_count": _query_count,
		"accepted_count": _accepted_count,
		"rejected_count": _rejected_count,
		"last_reason_id": _last_reason_id,
		"capacity_mode": PlayerCardDockProjectionV1.CAPACITY_MODE_SHARED_V06,
		"runtime_ruleset_id": PlayerCardDockProjectionV1.RUNTIME_RULESET_V06,
		"viewer_authorized_only": true,
		"mutates_gameplay": false,
		"stores_card_state": false,
		"consumes_rng": false,
		"references_main": false,
	}


func _is_configured() -> bool:
	return _query_ports != null and _table_query != null and _card_presentation != null


func _reject(reason_id: String) -> Dictionary:
	_rejected_count += 1
	_last_reason_id = reason_id
	return {}
