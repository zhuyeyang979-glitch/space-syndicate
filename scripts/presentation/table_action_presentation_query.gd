@tool
extends Node
class_name TableActionPresentationQuery

const TARGET_CHOICE_KINDS := ["monster_target_choice", "player_target_choice"]

var _authorization: LocalViewerAuthorization
var _world_query: WorldSessionPresentationQuery
var _selection: TableSelectionState
var _forced_scheduler: ForcedDecisionRuntimeScheduler
var _purchase: DistrictPurchaseRuntimeController
var _target_choice: CardTargetChoiceRuntimeController
var _card_resolution: CardResolutionRuntimeController
var _queue: CardResolutionQueueRuntimeService
var _history: CardResolutionHistoryRuntimeService
var _revision := 0
var _last_fingerprint := ""


func configure(
	authorization: LocalViewerAuthorization,
	world_query: WorldSessionPresentationQuery,
	selection: TableSelectionState,
	forced_scheduler: ForcedDecisionRuntimeScheduler,
	purchase: DistrictPurchaseRuntimeController,
	target_choice: CardTargetChoiceRuntimeController,
	card_resolution: CardResolutionRuntimeController,
	queue: CardResolutionQueueRuntimeService,
	history: CardResolutionHistoryRuntimeService
) -> void:
	_authorization = authorization
	_world_query = world_query
	_selection = selection
	_forced_scheduler = forced_scheduler
	_purchase = purchase
	_target_choice = target_choice
	_card_resolution = card_resolution
	_queue = queue
	_history = history


func snapshot_for_viewer(viewer_index: int) -> TableActionPresentationProjection:
	var projection := TableActionPresentationProjection.new()
	projection.viewer_index = viewer_index
	if _authorization == null or not _authorization.can_view_subject(viewer_index, viewer_index):
		return projection
	var public_world := _world_query.public_projection() if _world_query != null else WorldSessionPublicProjection.new()
	var selected_district := _selection.selected_district if _selection != null else -1
	var district_exists := selected_district >= 0 and selected_district < public_world.districts.size()
	var district_destroyed := bool((public_world.districts[selected_district] as Dictionary).get("destroyed", false)) if district_exists else false
	var forced := _forced_scheduler.active_decision(viewer_index) if _forced_scheduler != null else {}
	var queue_snapshot := _queue.public_snapshot() if _queue != null else {}
	var queue_empty := int(queue_snapshot.get("current_count", 0)) <= 0 and not bool(queue_snapshot.get("active_present", false))
	var resolution_facts := _card_resolution.card_play_fact_snapshot() if _card_resolution != null else {}
	var phase_facts := resolution_facts.duplicate(true)
	phase_facts["queue_empty"] = queue_empty
	phase_facts["active_present"] = bool(queue_snapshot.get("active_present", false))
	var blocks_player_actions := _forced_scheduler.blocks_player_actions(viewer_index) if _forced_scheduler != null else false
	projection.availability = {
		"can_view_private_hand": true,
		"selected_district_exists": district_exists,
		"selected_district_destroyed": district_destroyed,
		"can_inspect_region_rack": district_exists,
		"can_request_region_purchase": district_exists and not district_destroyed and not blocks_player_actions,
		"card_submissions_open": _card_resolution.submissions_open(phase_facts) if _card_resolution != null else false,
		"public_bidding_open": _card_resolution.bidding_open(phase_facts) if _card_resolution != null else false,
		"blocks_player_actions": blocks_player_actions,
		"selected_district": selected_district,
	}
	projection.forced_decision = forced.duplicate(true)
	projection.purchase = _purchase.private_ui_snapshot(viewer_index) if _purchase != null else {}
	projection.target_choices = _target_choice.private_snapshot(viewer_index) if _target_choice != null else {}
	projection.card_track = {
		"queue": queue_snapshot.duplicate(true),
		"history": _history.private_viewer_snapshot(viewer_index) if _history != null else [],
		"public_history": _history.public_history_snapshot() if _history != null else [],
		"phase": _card_resolution.current_phase(phase_facts) if _card_resolution != null else "idle",
	}
	var fingerprint := JSON.stringify([projection.availability, projection.forced_decision, projection.purchase, projection.target_choices, projection.card_track])
	if fingerprint != _last_fingerprint:
		_last_fingerprint = fingerprint
		_revision += 1
	projection.revision = _revision
	return projection


func public_card_track_snapshot() -> Dictionary:
	return {
		"queue": _queue.public_snapshot() if _queue != null else {},
		"history": _history.public_history_snapshot() if _history != null else [],
		"visibility_scope": "public",
	}


func debug_snapshot() -> Dictionary:
	return {
		"configured": _authorization != null and _world_query != null and _selection != null,
		"revision": _revision,
		"private_target_choice_requires_authorized_viewer": true,
		"card_track_uses_public_owner_projection": true,
		"owns_gameplay_legality": false,
	}
