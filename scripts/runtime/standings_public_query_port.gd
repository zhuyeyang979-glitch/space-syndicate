@tool
extends Node
class_name StandingsPublicQueryPort

## Read-only, viewer-authorized source for the standings application page.
## It composes existing public/private query projections and delegates all
## player-facing formatting to StandingsPublicSnapshotService.

@export var table_query_ports_path: NodePath
@export var victory_controller_path: NodePath
@export var final_settlement_path: NodePath
@export var snapshot_service_path: NodePath

var _query_count := 0
var _rejected_count := 0
var _last_viewer_index := -1


func snapshot_for_authorized_viewer(content_width: float = 960.0) -> Dictionary:
	var query_ports := _table_query_ports()
	var victory := _victory_controller()
	var service := _snapshot_service()
	if query_ports == null or victory == null or service == null:
		_rejected_count += 1
		return service.compose({"valid": false}) if service != null else {}
	var context := query_ports.viewer_context()
	var public_world := query_ports.public_world_projection()
	if not context.authorized or public_world.players.is_empty():
		_rejected_count += 1
		return service.compose({"valid": false})
	var viewer_index := context.viewer_index
	var private_world := query_ports.private_world_projection(viewer_index, viewer_index)
	if not private_world.authorized:
		_rejected_count += 1
		return service.compose({"valid": false})
	var victory_public := victory.public_snapshot(viewer_index)
	var victory_private := victory.private_snapshot(viewer_index)
	var source := _compose_source(
		viewer_index,
		public_world,
		private_world,
		victory_public,
		victory_private,
		content_width,
		query_ports
	)
	if not TablePresentationPureDataPolicy.is_pure_data(source):
		_rejected_count += 1
		return service.compose({"valid": false})
	_query_count += 1
	_last_viewer_index = viewer_index
	return service.compose(source)


func debug_snapshot() -> Dictionary:
	return {
		"port_id": "standings_public_query_port_v06",
		"query_count": _query_count,
		"rejected_count": _rejected_count,
		"last_viewer_index": _last_viewer_index,
		"viewer_authorization_required": true,
		"selected_player_is_authorization": false,
		"refreshes_routes": false,
		"mutates_world": false,
		"reveals_all_on_session_finish": false,
		"references_main": false,
	}


func _compose_source(
	viewer_index: int,
	public_world: WorldSessionPublicProjection,
	private_world: WorldSessionPrivateProjection,
	victory_public: Dictionary,
	victory_private: Dictionary,
	content_width: float,
	query_ports: TablePresentationQueryPorts
) -> Dictionary:
	var own_candidate: Dictionary = victory_private.get("own_candidate", {}) if victory_private.get("own_candidate", {}) is Dictionary else {}
	var own_player := private_world.player
	var victory_rule: Dictionary = victory_public.get("victory_rule", {}) if victory_public.get("victory_rule", {}) is Dictionary else {}
	var outcome: Dictionary = victory_public.get("outcome_receipt", {}) if victory_public.get("outcome_receipt", {}) is Dictionary else {}
	var seats: Array = []
	for public_player_variant in public_world.players:
		if not (public_player_variant is Dictionary):
			continue
		var public_player := public_player_variant as Dictionary
		var player_index := int(public_player.get("player_index", seats.size()))
		var seat := {
			"player_index": player_index,
			"name": str(public_player.get("public_player_name", "玩家%d" % (player_index + 1))),
			"eliminated": bool(public_player.get("eliminated", false)),
			"can_view_private": player_index == viewer_index,
		}
		if player_index == viewer_index:
			seat["cash"] = int(own_player.get("cash", int(round(float(int(own_player.get("cash_cents", 0))) / 100.0))))
			seat["top_n_gdp_per_minute"] = int(own_candidate.get("top_n_gdp_per_minute", 0))
			seat["controlled_region_count"] = int(own_candidate.get("controlled_region_count", 0))
		seats.append(seat)
	var final_summary := ""
	if not outcome.is_empty():
		var final_settlement := _final_settlement()
		if final_settlement != null:
			final_summary = final_settlement.latest_public_summary()
	return {
		"valid": true,
		"game_over": not outcome.is_empty(),
		"selected_available": true,
		"selected_top_n_gdp_per_minute": int(own_candidate.get("top_n_gdp_per_minute", 0)),
		"selected_controlled_region_count": int(own_candidate.get("controlled_region_count", 0)),
		"selected_cash": int(own_player.get("cash", 0)),
		"required_top_n_gdp_per_minute": int(victory_rule.get("required_top_k_gdp_per_minute", 0)),
		"required_controlled_region_count": int(victory_rule.get("required_region_count", 0)),
		"victory_control": victory_public.duplicate(true),
		"countdown_text": _countdown_text(victory_public),
		"public_shift_count": query_ports.recent_public_log_entries(5).size(),
		"overview_columns": clampi(int(floor(maxf(260.0, content_width) / 280.0)), 1, 3),
		"kpi_columns": clampi(int(floor(maxf(260.0, content_width) / 230.0)), 1, 4),
		"seat_columns": clampi(int(floor(maxf(260.0, content_width) / 260.0)), 1, 4),
		"seat_entries": seats,
		"final_summary_text": final_summary,
	}


func _countdown_text(victory_public: Dictionary) -> String:
	match str(victory_public.get("state", "idle")):
		"qualification":
			return "资格保持 %.1f秒" % float(victory_public.get("qualification_remaining_seconds", 0.0))
		"audit":
			return "公开审计 %.1f秒" % float(victory_public.get("audit_remaining_seconds", 0.0))
		"cooldown":
			return "审计冷却"
		"resolved":
			return "胜利已结算"
	return "等待胜利资格"


func _table_query_ports() -> TablePresentationQueryPorts:
	return get_node_or_null(table_query_ports_path) as TablePresentationQueryPorts if not table_query_ports_path.is_empty() else null


func _victory_controller() -> VictoryControlRuntimeController:
	return get_node_or_null(victory_controller_path) as VictoryControlRuntimeController if not victory_controller_path.is_empty() else null


func _final_settlement() -> FinalSettlementRuntimeComposition:
	return get_node_or_null(final_settlement_path) as FinalSettlementRuntimeComposition if not final_settlement_path.is_empty() else null


func _snapshot_service() -> StandingsPublicSnapshotService:
	return get_node_or_null(snapshot_service_path) as StandingsPublicSnapshotService if not snapshot_service_path.is_empty() else null
