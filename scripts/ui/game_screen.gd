extends Control
class_name SpaceSyndicateGameScreen

const TABLE_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/table_snapshot.gd")
const OVERLAY_LAYER_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/overlay_layer_snapshot.gd")
const COMMODITY_CLAIM_REQUEST_SCRIPT := preload("res://scripts/runtime/commodity_sushi_track_claim_request.gd")
const COMMODITY_ITEM_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/commodity_sushi_track_item_snapshot.gd")
const COMMODITY_TRACK_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/commodity_sushi_track_snapshot.gd")
const COMMODITY_TRACK_SCRIPT := preload("res://scripts/ui/table/top_commodity_sushi_track.gd")
const TABLE_SELECTION_INTENT_SCRIPT := preload("res://scripts/runtime/table_selection_intent.gd")
const TABLE_NAVIGATION_ACTION_INTENT_SCRIPT := preload("res://scripts/runtime/table_navigation_action_intent.gd")
const DISTRICT_SUPPLY_ACTION_INTENT_SCRIPT := preload("res://scripts/runtime/district_supply_action_intent.gd")
const CARD_TARGET_CHOICE_RESPONSE_RECEIPT_SCRIPT := preload("res://scripts/runtime/card_target_choice_response_receipt.gd")
const MONSTER_WAGER_RESPONSE_RECEIPT_SCRIPT := preload("res://scripts/runtime/monster_wager_response_receipt.gd")
const HAND_HOVER_PREVIEW_LEFT := 0.020
const HAND_HOVER_PREVIEW_TOP := 0.350
const HAND_HOVER_PREVIEW_RIGHT := 0.190
const HAND_HOVER_PREVIEW_BOTTOM := 0.880
const HAND_HOVER_PREVIEW_CARD_MIN_SIZE := Vector2(216, 292)
const PRIVATE_TRACK_ENTRY_KEYS := [
	"hidden_owner",
	"hidden_owner_id",
	"private_owner",
	"private_target",
	"owner_secret",
	"secret_owner",
	"private_discard",
	"private_hand",
	"opponent_hand",
	"opponent_cash",
	"true_owner",
	"owner",
	"owner_id",
	"owner_index",
	"player_index",
	"viewer_index",
	"cash",
	"cash_cents",
	"exact_cash",
	"hand",
	"hand_size",
]
const PRIVATE_TRACK_TEXT_TOKENS := ["hidden_", "private_", "owner_secret", "secret_owner", "opponent_cash", "opponent_hand", "true_owner"]

signal end_turn_requested
signal action_requested(action_id: String)
signal application_intent_requested(intent: IntelApplicationIntent)
signal card_selected(card_data: Dictionary)
signal card_hovered(card_data: Dictionary)
signal card_unhovered
signal card_unselected(card_data: Dictionary)
signal card_drag_preview_started(card_data: Dictionary)
signal card_drag_preview_ended(card_data: Dictionary)
signal card_drop_requested(card_data: Dictionary, screen_position: Vector2)
signal commodity_claim_requested(request: COMMODITY_CLAIM_REQUEST_SCRIPT)
signal table_selection_intent_requested(intent: TABLE_SELECTION_INTENT_SCRIPT)
signal navigation_intent_requested(intent: TABLE_NAVIGATION_ACTION_INTENT_SCRIPT)
signal district_supply_action_intent_requested(intent: DISTRICT_SUPPLY_ACTION_INTENT_SCRIPT)
signal forced_decision_response_requested(request: ForcedDecisionResponseRequest)

@onready var top_bar: Node = %TopBar
@onready var commodity_sushi_track: COMMODITY_TRACK_SCRIPT = %TopCommoditySushiTrack
@onready var planet_board: Node = %PlanetBoard
@onready var right_inspector: SpaceSyndicateRightInspector = %RightInspector
@onready var player_board: SpaceSyndicatePlayerBoard = %PlayerBoard
@onready var visual_event_layer: Node = get_node_or_null("%RuntimeVisualEventLayer")
@onready var overlay_layer: Node = %OverlayLayer
@onready var hand_hover_preview_host: Control = get_node_or_null("%HandHoverPreviewHost") as Control
@onready var hand_hover_preview_panel: PanelContainer = get_node_or_null("%HandHoverPreviewPanel") as PanelContainer
@onready var hand_hover_preview_title: Label = get_node_or_null("%HandHoverPreviewTitle") as Label
@onready var hand_hover_preview_card: Control = get_node_or_null("%HandHoverPreviewCard") as Control

var current_ui_data: Dictionary = {}
var _rendered_forced_decision_binding: Dictionary = {}
var _temporary_track_focus_active := false
var _selected_hand_card_data: Dictionary = {}
var _last_runtime_player_feedback: Dictionary = {}
var _last_track_action_bridge_id := ""
var _last_track_action_bridge_frame := -1
var _last_visual_event_key := ""
var _selected_commodity_slot_id := ""
var _selected_commodity_item_data: Dictionary = {}
var _last_commodity_action_result: Dictionary = {}
var _commodity_claim_request_revision := 1
var _presentation_target_revision := 0
var _live_presentation_target_count := 0
var _full_presentation_target_count := 0
var _presentation_authorized_viewer_index := -1
var _presentation_authorization_revision := 0
var _presentation_session_id := ""
var _presentation_session_revision := 0
var _inspected_player_index := -1
var _last_player_inspection_receipt_revision := -1
var _player_inspection_receipt_apply_count := 0
var _table_selection_request_revision := 0
var _navigation_request_revision := 0
var _district_supply_action_request_revision := 0
var _forced_decision_response_request_revision := 0
var _district_supply_locked_quote_ids: Dictionary = {}
var _district_supply_selected_card_by_district: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_bind_presentation_map_targets()
	_configure_pointer_passthrough_hosts()
	_configure_hand_hover_preview()
	if top_bar.has_signal("end_turn_requested"):
		top_bar.connect("end_turn_requested", Callable(self, "_on_end_turn_requested"))
	if top_bar.has_signal("menu_requested"):
		top_bar.connect("menu_requested", Callable(self, "_on_menu_requested"))
	if top_bar.has_signal("player_inspection_requested"):
		top_bar.connect("player_inspection_requested", Callable(self, "_on_toolbar_player_inspection_requested"))
	if commodity_sushi_track != null:
		commodity_sushi_track.item_focused.connect(_on_commodity_item_focused)
		commodity_sushi_track.claim_requested.connect(_on_commodity_claim_requested)
	if right_inspector.has_signal("action_requested"):
		right_inspector.connect("action_requested", Callable(self, "_on_action_requested"))
	right_inspector.application_intent_requested.connect(_on_application_intent_requested)
	if player_board.has_signal("card_selected"):
		player_board.connect("card_selected", Callable(self, "_on_card_selected"))
	if player_board.has_signal("card_hovered"):
		player_board.connect("card_hovered", Callable(self, "_on_card_hovered"))
	if player_board.has_signal("card_unhovered"):
		player_board.connect("card_unhovered", Callable(self, "_on_card_unhovered"))
	if player_board.has_signal("card_unselected"):
		player_board.connect("card_unselected", Callable(self, "_on_card_unselected"))
	if player_board.has_signal("card_drag_preview_started"):
		player_board.connect("card_drag_preview_started", Callable(self, "_on_card_drag_preview_started"))
	if player_board.has_signal("card_drag_preview_moved"):
		player_board.connect("card_drag_preview_moved", Callable(self, "_on_card_drag_preview_moved"))
	if player_board.has_signal("card_drag_preview_ended"):
		player_board.connect("card_drag_preview_ended", Callable(self, "_on_card_drag_preview_ended"))
	if player_board.has_signal("card_drag_released"):
		player_board.connect("card_drag_released", Callable(self, "_on_card_drag_released"))
	if player_board.has_signal("action_requested"):
		player_board.connect("action_requested", Callable(self, "_on_action_requested"))
	if player_board.has_signal("player_inspection_requested"):
		player_board.connect("player_inspection_requested", Callable(self, "_on_player_board_inspection_requested"))
	player_board.application_intent_requested.connect(_on_application_intent_requested)
	if planet_board.has_signal("player_inspection_requested"):
		planet_board.connect("player_inspection_requested", Callable(self, "_on_player_seat_inspection_requested"))
	if overlay_layer.has_signal("side_drawer_action_requested"):
		overlay_layer.connect("side_drawer_action_requested", Callable(self, "_on_side_drawer_action_requested"))
	if overlay_layer.has_signal("temporary_decision_action_requested"):
		overlay_layer.connect("temporary_decision_action_requested", Callable(self, "_on_temporary_decision_action_requested"))
	if overlay_layer.has_signal("public_bid_action_requested"):
		overlay_layer.connect("public_bid_action_requested", Callable(self, "_on_public_bid_action_requested"))
	if overlay_layer.has_signal("public_bid_track_link_hovered"):
		overlay_layer.connect("public_bid_track_link_hovered", Callable(self, "_on_track_link_hovered"))
	if overlay_layer.has_signal("public_bid_track_link_unhovered"):
		overlay_layer.connect("public_bid_track_link_unhovered", Callable(self, "_on_track_link_unhovered"))
	if overlay_layer.has_signal("map_layer_focus_requested"):
		overlay_layer.connect("map_layer_focus_requested", Callable(self, "_on_map_layer_focus_requested"))
	var district_supply_drawer := get_district_supply_drawer()
	if district_supply_drawer != null and district_supply_drawer.has_signal("supply_action_requested"):
		district_supply_drawer.connect("supply_action_requested", Callable(self, "_on_district_supply_action_requested"))
	call_deferred("_bind_district_selection_sources")
	call_deferred("_sync_runtime_table_focus_order")


func _configure_pointer_passthrough_hosts() -> void:
	for node in [
		get_node_or_null("Background"),
		hand_hover_preview_host,
		visual_event_layer,
	]:
		if node is Control:
			(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func apply_state(data: Dictionary) -> void:
	var ui_data: Dictionary = TABLE_SNAPSHOT_SCRIPT.new().apply_dictionary(data).to_ui_dictionary()
	current_ui_data = ui_data
	if top_bar.has_method("set_state"):
		top_bar.call("set_state", ui_data.get("top_bar", {}))
	if commodity_sushi_track != null:
		commodity_sushi_track.set_snapshot_dictionary(
			ui_data.get("commodity_sushi_track", {}) if ui_data.get("commodity_sushi_track", {}) is Dictionary else {}
		)
	if planet_board.has_method("set_board_state"):
		planet_board.call("set_board_state", ui_data.get("planet", {}))
	_sync_optional_route_public_surface(ui_data.get("optional_route_presentation", {}))
	if right_inspector.has_method("set_context"):
		var inspector: Dictionary = ui_data.get("right_inspector", {}) if ui_data.get("right_inspector", {}) is Dictionary else {}
		right_inspector.call("set_context", inspector)
	var player_data: Dictionary = ui_data.get("player_board", {}) if ui_data.get("player_board", {}) is Dictionary else {}
	if player_board.has_method("set_player_state"):
		player_board.call("set_player_state", player_data)
	_sync_visual_events(ui_data)
	if not _restore_selected_commodity_focus() and not _temporary_track_focus_active:
		_sync_selected_track_focus_from_state()
	_sync_transient_gameplay_surfaces(
		ui_data.get("temporary_decision", {}),
		player_data.get("bid_board", {}),
		ui_data.get("active_forced_decision", {})
	)
	_apply_inspected_player_presentation()
	call_deferred("_sync_runtime_table_focus_order")


func apply_live_presentation(snapshot: TableLivePresentationSnapshot) -> int:
	if snapshot == null or not snapshot.is_valid() or not _presentation_authorization_matches(snapshot.viewer_index, snapshot.authorization_revision):
		return _presentation_target_revision
	apply_state(snapshot.to_dictionary())
	_presentation_target_revision += 1
	_live_presentation_target_count += 1
	return _presentation_target_revision


func apply_full_presentation(snapshot: TableFullPresentationSnapshot) -> int:
	if snapshot == null or not snapshot.is_valid() or not _presentation_authorization_matches(snapshot.viewer_index, snapshot.authorization_revision):
		return _presentation_target_revision
	var data := snapshot.to_dictionary()
	apply_state(data)
	var overlays := overlay_layer as SpaceSyndicateOverlayLayer
	var district_supply: Dictionary = data.get("district_supply", {}) if data.get("district_supply", {}) is Dictionary else {}
	if overlays != null:
		overlays.apply_district_supply_presentation(
			district_supply,
			snapshot.viewer_index,
			snapshot.authorization_revision
		)
	_presentation_target_revision += 1
	_full_presentation_target_count += 1
	return _presentation_target_revision


func presentation_planet_target() -> SpaceSyndicatePlanetBoard:
	var target := planet_board as SpaceSyndicatePlanetBoard
	if target != null:
		_bind_presentation_map_targets()
	return target


func _bind_presentation_map_targets() -> void:
	var target := planet_board as SpaceSyndicatePlanetBoard
	var overlays := overlay_layer as SpaceSyndicateOverlayLayer
	if target != null and overlays != null:
		target.bind_fullscreen_map_target(overlays.presentation_fullscreen_planet_target())


func bind_presentation_viewer(viewer_index: int, authorization_revision: int) -> void:
	var authorization_changed := _presentation_authorized_viewer_index != viewer_index \
		or _presentation_authorization_revision != authorization_revision
	if _presentation_authorized_viewer_index != viewer_index:
		_selected_commodity_slot_id = ""
		_selected_commodity_item_data = {}
		_last_commodity_action_result = {}
		_inspected_player_index = viewer_index
		_last_player_inspection_receipt_revision = -1
		_player_inspection_receipt_apply_count = 0
	if authorization_changed:
		var overlays := overlay_layer as SpaceSyndicateOverlayLayer
		if overlays != null:
			overlays.clear_district_supply_presentation()
	_presentation_authorized_viewer_index = viewer_index
	_presentation_authorization_revision = authorization_revision
	if planet_board is SpaceSyndicatePlanetBoard:
		(planet_board as SpaceSyndicatePlanetBoard).bind_presentation_viewer(viewer_index, authorization_revision)
	if player_board.has_method("bind_public_identity"):
		player_board.call("bind_public_identity", viewer_index)
	if top_bar.has_method("bind_public_identity"):
		top_bar.call("bind_public_identity", viewer_index)


func bind_gameplay_actor_authorization_context(context: GameplayActorAuthorizationContext) -> void:
	if context == null or not context.is_valid():
		_presentation_session_id = ""
		_presentation_session_revision = 0
		return
	if _presentation_authorized_viewer_index >= 0 and context.viewer_index != _presentation_authorized_viewer_index:
		return
	_presentation_authorized_viewer_index = context.viewer_index
	_presentation_authorization_revision = context.authorization_revision
	_presentation_session_id = context.session_id
	_presentation_session_revision = context.session_revision


func _presentation_authorization_matches(viewer_index: int, authorization_revision: int) -> bool:
	return viewer_index >= 0 and viewer_index == _presentation_authorized_viewer_index \
		and authorization_revision > 0 and authorization_revision == _presentation_authorization_revision


func _on_map_layer_focus_requested(layer_id: String) -> void:
	if _forced_surface_blocks_player_actions():
		_show_player_action_feedback("map_layer_focus", "blocked", "请先完成当前强制决策。")
		return
	_table_selection_request_revision += 1
	var intent := TABLE_SELECTION_INTENT_SCRIPT.new()
	intent.request_id = "table-selection:%d:%d" % [_presentation_authorized_viewer_index, _table_selection_request_revision]
	intent.selection_kind = TABLE_SELECTION_INTENT_SCRIPT.KIND_MAP_LAYER
	intent.viewer_index = _presentation_authorized_viewer_index
	intent.authorization_revision = _presentation_authorization_revision
	intent.session_id = _presentation_session_id
	intent.session_revision = _presentation_session_revision
	intent.expected_selection_revision = _current_selection_revision()
	intent.map_layer_id = StringName(layer_id)
	intent.source_surface = &"planet_map"
	intent.request_revision = _table_selection_request_revision
	table_selection_intent_requested.emit(intent)


func request_player_inspection(target_player_index: int, source_surface: StringName) -> bool:
	if source_surface not in TABLE_SELECTION_INTENT_SCRIPT.PLAYER_INSPECTION_SOURCE_SURFACES \
			or target_player_index < 0 or _presentation_authorized_viewer_index < 0 \
			or _presentation_session_id.is_empty() or _presentation_session_revision <= 0:
		return false
	_table_selection_request_revision += 1
	var intent := TABLE_SELECTION_INTENT_SCRIPT.new()
	intent.request_id = "player-inspection:%d:%d" % [_presentation_authorized_viewer_index, _table_selection_request_revision]
	intent.selection_kind = TABLE_SELECTION_INTENT_SCRIPT.KIND_INSPECT_PLAYER
	intent.viewer_index = _presentation_authorized_viewer_index
	intent.authorization_revision = _presentation_authorization_revision
	intent.session_id = _presentation_session_id
	intent.session_revision = _presentation_session_revision
	intent.expected_selection_revision = _current_selection_revision()
	intent.target_player_index = target_player_index
	intent.source_surface = source_surface
	intent.request_revision = _table_selection_request_revision
	table_selection_intent_requested.emit(intent)
	return true


func request_district_selection(target_district_index: int, source_surface: StringName) -> bool:
	if source_surface not in TABLE_SELECTION_INTENT_SCRIPT.DISTRICT_SELECTION_SOURCE_SURFACES \
			or target_district_index < 0 or not _selection_identity_is_bound():
		return false
	var intent := _new_table_selection_intent(TABLE_SELECTION_INTENT_SCRIPT.KIND_SELECT_DISTRICT, source_surface, "district-selection")
	intent.target_district_index = target_district_index
	table_selection_intent_requested.emit(intent)
	return true


func request_trade_product_selection(target_product_id: String, source_surface: StringName) -> bool:
	if source_surface not in TABLE_SELECTION_INTENT_SCRIPT.TRADE_PRODUCT_SELECTION_SOURCE_SURFACES \
			or target_product_id.length() > 80 or target_product_id.strip_edges() != target_product_id \
			or not _selection_identity_is_bound():
		return false
	var intent := _new_table_selection_intent(TABLE_SELECTION_INTENT_SCRIPT.KIND_SELECT_TRADE_PRODUCT, source_surface, "trade-product-selection")
	intent.target_trade_product_id = target_product_id
	table_selection_intent_requested.emit(intent)
	return true


func request_hand_selection(target_hand_slot: int, source_surface: StringName) -> bool:
	if source_surface not in TABLE_SELECTION_INTENT_SCRIPT.HAND_SELECTION_SOURCE_SURFACES \
			or target_hand_slot < -1 or not _selection_identity_is_bound():
		return false
	var intent := _new_table_selection_intent(TABLE_SELECTION_INTENT_SCRIPT.KIND_SELECT_HAND_SLOT, source_surface, "hand-selection")
	intent.target_hand_slot = target_hand_slot
	table_selection_intent_requested.emit(intent)
	return true


func request_card_resolution_selection(target_resolution_id: int, source_surface: StringName) -> bool:
	if source_surface not in TABLE_SELECTION_INTENT_SCRIPT.CARD_RESOLUTION_SELECTION_SOURCE_SURFACES \
			or target_resolution_id < -1 or not _selection_identity_is_bound():
		return false
	var selected_resolution_id := int(_selection_context().get("selected_card_resolution_id", -1))
	var effective_target := -1 if target_resolution_id >= 0 and selected_resolution_id == target_resolution_id else target_resolution_id
	var intent := _new_table_selection_intent(TABLE_SELECTION_INTENT_SCRIPT.KIND_SELECT_CARD_RESOLUTION, source_surface, "card-resolution-selection")
	intent.target_card_resolution_id = effective_target
	table_selection_intent_requested.emit(intent)
	return true


func _new_table_selection_intent(selection_kind: StringName, source_surface: StringName, request_prefix: String) -> TableSelectionIntent:
	_table_selection_request_revision += 1
	var intent := TABLE_SELECTION_INTENT_SCRIPT.new()
	intent.request_id = "%s:%d:%d" % [request_prefix, _presentation_authorized_viewer_index, _table_selection_request_revision]
	intent.selection_kind = selection_kind
	intent.viewer_index = _presentation_authorized_viewer_index
	intent.authorization_revision = _presentation_authorization_revision
	intent.session_id = _presentation_session_id
	intent.session_revision = _presentation_session_revision
	intent.expected_selection_revision = _current_selection_revision()
	intent.source_surface = source_surface
	intent.request_revision = _table_selection_request_revision
	return intent


func _selection_identity_is_bound() -> bool:
	return _presentation_authorized_viewer_index >= 0 \
		and _presentation_authorization_revision > 0 \
		and not _presentation_session_id.is_empty() \
		and _presentation_session_revision > 0


func apply_table_selection_receipt(receipt: TableSelectionReceipt) -> void:
	if receipt == null:
		return
	if receipt.selection_kind == TABLE_SELECTION_INTENT_SCRIPT.KIND_MAP_LAYER \
			and overlay_layer != null and overlay_layer.has_method("set_selected_map_layer_focus"):
		overlay_layer.call("set_selected_map_layer_focus", str(receipt.effective_map_layer_id))
	if receipt.selection_revision_after >= 0:
		var context: Dictionary = current_ui_data.get("selection_context", {}) \
			if current_ui_data.get("selection_context", {}) is Dictionary else {}
		context["revision"] = receipt.selection_revision_after
		match receipt.selection_kind:
			TABLE_SELECTION_INTENT_SCRIPT.KIND_SELECT_DISTRICT:
				context["selected_district"] = receipt.district_index
				context["selected_hand_slot"] = receipt.hand_slot
			TABLE_SELECTION_INTENT_SCRIPT.KIND_SELECT_TRADE_PRODUCT:
				context["selected_trade_product"] = receipt.trade_product_id
			TABLE_SELECTION_INTENT_SCRIPT.KIND_SELECT_HAND_SLOT:
				context["selected_hand_slot"] = receipt.hand_slot
			TABLE_SELECTION_INTENT_SCRIPT.KIND_SELECT_CARD_RESOLUTION:
				context["selected_card_resolution_id"] = receipt.card_resolution_id
				context["selected_district"] = receipt.district_index
		current_ui_data["selection_context"] = context
	if receipt.accepted and receipt.selection_kind == TABLE_SELECTION_INTENT_SCRIPT.KIND_INSPECT_PLAYER:
		if receipt.selection_revision_after >= 0 and receipt.selection_revision_after <= _last_player_inspection_receipt_revision:
			return
		_last_player_inspection_receipt_revision = receipt.selection_revision_after
		_player_inspection_receipt_apply_count += 1
		_inspected_player_index = receipt.inspected_player_index
		_apply_inspected_player_presentation(true)
		_show_player_action_feedback(receipt.request_id, "success", "已切换公开玩家视图；你的行动身份保持不变。")
	elif receipt.accepted:
		var success_detail: String = str({
			TABLE_SELECTION_INTENT_SCRIPT.KIND_SELECT_DISTRICT: "区域焦点已切换；行动者身份保持不变。",
			TABLE_SELECTION_INTENT_SCRIPT.KIND_SELECT_TRADE_PRODUCT: "商品目标已切换；市场状态未被修改。",
			TABLE_SELECTION_INTENT_SCRIPT.KIND_SELECT_HAND_SLOT: "手牌焦点已切换；尚未提交出牌。",
			TABLE_SELECTION_INTENT_SCRIPT.KIND_SELECT_CARD_RESOLUTION: "公共牌轨焦点已切换；未触发任何卡牌结算。",
		}.get(receipt.selection_kind, "地图图层已切换。"))
		if receipt.selection_kind == TABLE_SELECTION_INTENT_SCRIPT.KIND_SELECT_CARD_RESOLUTION and receipt.focus_district_index >= 0:
			_focus_public_district(receipt.focus_district_index)
		_show_player_action_feedback(receipt.request_id, "success", success_detail)
	else:
		var detail := "当前无法切换地图图层。"
		if receipt.selection_kind == TABLE_SELECTION_INTENT_SCRIPT.KIND_INSPECT_PLAYER:
			if receipt.reason_code == "selection_revision_stale":
				detail = "查看状态已变化，请重试。"
			elif receipt.reason_code == "forced_decision_blocks_selection":
				detail = "请先完成当前强制决策。"
			else:
				detail = "当前无法切换公开玩家视图。"
		elif receipt.reason_code == "selection_revision_stale":
			detail = "图层状态已变化，请重试。"
		elif receipt.selection_kind == TABLE_SELECTION_INTENT_SCRIPT.KIND_SELECT_DISTRICT:
			detail = "当前无法切换区域焦点。"
		elif receipt.selection_kind == TABLE_SELECTION_INTENT_SCRIPT.KIND_SELECT_TRADE_PRODUCT:
			detail = "当前无法切换商品目标。"
		elif receipt.selection_kind == TABLE_SELECTION_INTENT_SCRIPT.KIND_SELECT_HAND_SLOT:
			detail = "当前无法切换手牌焦点。"
		elif receipt.selection_kind == TABLE_SELECTION_INTENT_SCRIPT.KIND_SELECT_CARD_RESOLUTION:
			detail = "这条公共牌轨记录已不存在，请刷新后重试。"
		_show_player_action_feedback(receipt.request_id, "blocked", detail)


func apply_district_supply_action_receipt(receipt: DistrictSupplyActionReceipt) -> void:
	if receipt == null:
		return
	var quote_key := _district_supply_quote_key(receipt.district_index, receipt.card_id)
	if receipt.accepted and receipt.action_kind == DISTRICT_SUPPLY_ACTION_INTENT_SCRIPT.KIND_QUOTE and not receipt.quote_id.is_empty():
		_district_supply_locked_quote_ids[quote_key] = receipt.quote_id
		_district_supply_selected_card_by_district[receipt.district_index] = receipt.card_id
	elif receipt.accepted and receipt.action_kind == DISTRICT_SUPPLY_ACTION_INTENT_SCRIPT.KIND_CLOSE:
		_district_supply_locked_quote_ids.clear()
		_district_supply_selected_card_by_district.clear()
	elif receipt.action_kind == DISTRICT_SUPPLY_ACTION_INTENT_SCRIPT.KIND_PURCHASE \
			and (receipt.accepted or receipt.reason_code in ["locked_quote_changed", "session_finished"]):
		_district_supply_locked_quote_ids.erase(quote_key)
	if receipt.accepted and receipt.focus_district_index >= 0:
		_focus_public_district(receipt.focus_district_index)
	if receipt.close_drawer:
		var overlays := overlay_layer as SpaceSyndicateOverlayLayer
		if overlays != null:
			overlays.clear_district_supply_presentation()
	var detail := "区域牌架动作已完成。" if receipt.accepted else "区域牌架状态已经变化，请刷新后重试。"
	if receipt.requires_discard:
		detail = "手牌已满，请私下选择一张可弃的普通牌。"
	_show_player_action_feedback(receipt.request_id, "success" if receipt.accepted else ("pending" if receipt.requires_discard else "blocked"), detail)


func apply_card_target_choice_response_receipt(receipt: CARD_TARGET_CHOICE_RESPONSE_RECEIPT_SCRIPT) -> void:
	if receipt == null:
		return
	var state := "success" if receipt.accepted else "blocked"
	var detail := receipt.player_message.strip_edges()
	if detail.is_empty():
		detail = "目标选择已完成。" if receipt.accepted else "目标当前不可用，请重新选择。"
	_show_player_action_feedback(receipt.request_id, state, detail)


func apply_monster_wager_response_receipt(receipt: MONSTER_WAGER_RESPONSE_RECEIPT_SCRIPT) -> void:
	if receipt == null:
		return
	var state := "success" if receipt.applied else "blocked"
	var detail := receipt.player_message.strip_edges()
	if detail.is_empty():
		detail = "下注已确认。" if receipt.applied else "下注未生效，请按当前窗口重试。"
	_show_player_action_feedback(receipt.request_id, state, detail)


func apply_forced_decision_response_receipt(receipt: ForcedDecisionResponseReceipt) -> void:
	if receipt == null or receipt.accepted \
			or str(receipt.decision_kind) not in ["monster_wager", "monster_target_choice", "player_target_choice"]:
		return
	var detail := "赌局已经变化，请按当前窗口重新下注。" if str(receipt.decision_kind) == "monster_wager" \
			else "目标选择已失效或已经处理，请按当前窗口重新选择。"
	_show_player_action_feedback(receipt.request_id, "blocked", detail)


func _district_supply_quote_key(district_index: int, card_id: String) -> String:
	return "%d:%s" % [district_index, card_id]


func _focus_public_district(district_index: int) -> void:
	for map_node in [
		get_embedded_map_view(),
		overlay_layer.call("presentation_fullscreen_planet_target") if overlay_layer != null and overlay_layer.has_method("presentation_fullscreen_planet_target") else null,
	]:
		if map_node != null and map_node.has_method("focus_district"):
			map_node.call("focus_district", district_index)


func _on_player_seat_inspection_requested(player_index: int) -> void:
	request_player_inspection(player_index, &"player_seat")


func _on_player_board_inspection_requested(player_index: int) -> void:
	request_player_inspection(player_index, &"player_board")


func _on_toolbar_player_inspection_requested(player_index: int) -> void:
	request_player_inspection(player_index, &"table_toolbar")


func _apply_inspected_player_presentation(focus_seat: bool = false) -> void:
	var descriptor := _public_player_descriptor(_inspected_player_index)
	if descriptor.is_empty():
		return
	if planet_board.has_method("set_inspected_player_index"):
		planet_board.call("set_inspected_player_index", _inspected_player_index)
	if focus_seat and planet_board.has_method("focus_inspected_player"):
		planet_board.call("focus_inspected_player", _inspected_player_index)
	if player_board.has_method("set_inspected_public_player"):
		player_board.call("set_inspected_public_player", descriptor)
	if top_bar.has_method("set_inspected_public_player"):
		top_bar.call("set_inspected_public_player", descriptor)
	if right_inspector.has_method("show_public_player"):
		right_inspector.call("show_public_player", descriptor)
	if overlay_layer != null:
		overlay_layer.set_meta("inspected_player_index", _inspected_player_index)
		overlay_layer.set_meta("player_inspection_revision", _current_selection_revision())


func _public_player_descriptor(player_index: int) -> Dictionary:
	var planet: Dictionary = current_ui_data.get("planet", {}) if current_ui_data.get("planet", {}) is Dictionary else {}
	var seats: Array = planet.get("player_seats", []) if planet.get("player_seats", []) is Array else []
	for seat_variant in seats:
		if not (seat_variant is Dictionary):
			continue
		var seat := seat_variant as Dictionary
		if int(seat.get("player_index", -1)) != player_index:
			continue
		return {
			"player_index": player_index,
			"public_player_name": str(seat.get("public_player_name", "玩家%d" % (player_index + 1))),
			"role_name": str(seat.get("role_name", "外星辛迪加")),
			"player_color": seat.get("player_color", Color.WHITE),
			"public_status": str(seat.get("public_status", "waiting")),
			"is_local_player": bool(seat.get("is_local_player", false)),
		}
	return {}


func player_inspection_debug_snapshot() -> Dictionary:
	return {
		"inspected_player_index": _inspected_player_index,
		"authorized_viewer_index": _presentation_authorized_viewer_index,
		"session_id_bound": not _presentation_session_id.is_empty(),
		"player_seat_synced": planet_board.has_method("inspected_player_index") and int(planet_board.call("inspected_player_index")) == _inspected_player_index,
		"player_board_synced": int(player_board.get_meta("inspected_player_index", -1)) == _inspected_player_index,
		"toolbar_synced": int(top_bar.get_meta("inspected_player_index", -1)) == _inspected_player_index,
		"fullscreen_hud_synced": int(overlay_layer.get_meta("inspected_player_index", -1)) == _inspected_player_index if overlay_layer != null else false,
		"right_inspector_public_only": str(right_inspector.get_meta("context_kind", "")) == "public_player",
		"receipt_apply_count": _player_inspection_receipt_apply_count,
		"last_receipt_revision": _last_player_inspection_receipt_revision,
	}


func _current_selection_revision() -> int:
	var context: Dictionary = current_ui_data.get("selection_context", {}) \
		if current_ui_data.get("selection_context", {}) is Dictionary else {}
	return maxi(0, int(context.get("revision", 0)))


func presentation_target_debug_snapshot() -> Dictionary:
	return {
		"target_revision": _presentation_target_revision,
		"live_target_count": _live_presentation_target_count,
		"full_target_count": _full_presentation_target_count,
		"owns_gameplay_state": false,
	}


func _set_overlay_anchor_rect(control: Control, left: float, top: float, right: float, bottom: float) -> void:
	control.anchor_left = left
	control.anchor_top = top
	control.anchor_right = right
	control.anchor_bottom = bottom
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0


func attach_runtime_map(map_node: Control) -> void:
	if planet_board != null and planet_board.has_method("attach_runtime_map"):
		planet_board.call("attach_runtime_map", map_node)
	_bind_district_selection_source(map_node, &"planet_map")
	call_deferred("_sync_runtime_table_focus_order")


func _bind_district_selection_sources() -> void:
	_bind_district_selection_source(get_embedded_map_view(), &"planet_map")
	var fullscreen_map := overlay_layer.call("presentation_fullscreen_planet_target") as Control \
		if overlay_layer != null and overlay_layer.has_method("presentation_fullscreen_planet_target") else null
	_bind_district_selection_source(fullscreen_map, &"fullscreen_hud")


func _bind_district_selection_source(map_node: Control, source_surface: StringName) -> void:
	if map_node == null or not map_node.has_signal("district_selected"):
		return
	var callback := Callable(self, "_on_district_selection_requested").bind(source_surface)
	if not map_node.is_connected("district_selected", callback):
		map_node.connect("district_selected", callback)
	if map_node.has_signal("district_double_clicked"):
		var double_callback := Callable(self, "_on_district_supply_open_requested").bind(source_surface)
		if not map_node.is_connected("district_double_clicked", double_callback):
			map_node.connect("district_double_clicked", double_callback)


func _on_district_selection_requested(district_index: int, source_surface: StringName) -> void:
	request_district_selection(district_index, source_surface)


func _on_district_supply_open_requested(district_index: int, source_surface: StringName) -> void:
	if _forced_surface_blocks_player_actions():
		_show_player_action_feedback("district_supply_open", "blocked", "请先完成当前强制决策。")
		return
	if not request_district_selection(district_index, source_surface):
		return
	_emit_district_supply_action(DISTRICT_SUPPLY_ACTION_INTENT_SCRIPT.KIND_OPEN, district_index, "", -1, source_surface)


func request_district_supply_open(district_index: int, source_surface: StringName = &"game_screen") -> bool:
	if _forced_surface_blocks_player_actions() or not request_district_selection(district_index, source_surface):
		return false
	return _emit_district_supply_action(DISTRICT_SUPPLY_ACTION_INTENT_SCRIPT.KIND_OPEN, district_index, "", -1, source_surface)


func request_selected_district_supply_purchase(source_surface: StringName = &"game_screen") -> bool:
	var district_index := int(_selection_context().get("selected_district", -1))
	var card_id := str(_district_supply_selected_card_by_district.get(district_index, ""))
	if district_index < 0 or card_id.is_empty() or _forced_surface_blocks_player_actions():
		return false
	return _emit_district_supply_action(DISTRICT_SUPPLY_ACTION_INTENT_SCRIPT.KIND_PURCHASE, district_index, card_id, -1, source_surface)


func request_district_supply_close(source_surface: StringName = &"game_screen") -> bool:
	return _emit_district_supply_action(DISTRICT_SUPPLY_ACTION_INTENT_SCRIPT.KIND_CLOSE, -1, "", -1, source_surface)


func _on_district_supply_action_requested(action_id: String, payload: Dictionary) -> void:
	if action_id != "district_supply_close" and _forced_surface_blocks_player_actions():
		_show_player_action_feedback(action_id, "blocked", "请先完成当前强制决策。")
		return
	var district_index := int(payload.get("district_index", _selection_context().get("selected_district", -1)))
	var card_id := str(payload.get("card_name", ""))
	match action_id:
		"district_supply_close":
			_emit_district_supply_action(DISTRICT_SUPPLY_ACTION_INTENT_SCRIPT.KIND_CLOSE, district_index, "", -1, &"district_supply")
		"district_supply_preview_card":
			var kind := DISTRICT_SUPPLY_ACTION_INTENT_SCRIPT.KIND_PREVIEW if str(payload.get("source", "")) == "hover" else DISTRICT_SUPPLY_ACTION_INTENT_SCRIPT.KIND_QUOTE
			_emit_district_supply_action(kind, district_index, card_id, -1, &"district_supply")
		"district_supply_purchase_card":
			_emit_district_supply_action(DISTRICT_SUPPLY_ACTION_INTENT_SCRIPT.KIND_PURCHASE, district_index, card_id, -1, &"district_supply")


func _emit_district_supply_action(kind: StringName, district_index: int, card_id: String, discard_slot: int, source_surface: StringName) -> bool:
	if not _selection_identity_is_bound():
		return false
	_district_supply_action_request_revision += 1
	var intent := DISTRICT_SUPPLY_ACTION_INTENT_SCRIPT.new()
	intent.request_id = "district-supply:%d:%d" % [_presentation_authorized_viewer_index, _district_supply_action_request_revision]
	intent.action_kind = kind
	intent.actor_player_index = _presentation_authorized_viewer_index
	intent.authorization_revision = _presentation_authorization_revision
	intent.session_id = _presentation_session_id
	intent.session_revision = _presentation_session_revision
	intent.district_index = district_index
	intent.card_id = card_id
	intent.discard_slot = discard_slot
	if kind in [DISTRICT_SUPPLY_ACTION_INTENT_SCRIPT.KIND_PURCHASE, DISTRICT_SUPPLY_ACTION_INTENT_SCRIPT.KIND_DISCARD_CONFIRM]:
		intent.locked_quote_id = str(_district_supply_locked_quote_ids.get(_district_supply_quote_key(district_index, card_id), ""))
	intent.source_surface = source_surface
	intent.request_revision = _district_supply_action_request_revision
	district_supply_action_intent_requested.emit(intent)
	return true


func set_weather_presentation(forecast_view_model: Dictionary, overlay_view_model: Dictionary, motion_mode: String) -> void:
	if planet_board != null and planet_board.has_method("set_weather_presentation"):
		planet_board.call("set_weather_presentation", forecast_view_model, overlay_view_model, motion_mode)


func get_embedded_map_view() -> Control:
	if planet_board != null and planet_board.has_method("get_embedded_map_view"):
		var embedded: Variant = planet_board.call("get_embedded_map_view")
		if embedded is Control:
			return embedded as Control
	var found := find_child("PlanetMapView", true, false) as Control
	return found


func set_optional_route_public_snapshot(snapshot: Dictionary, geometry_by_route_id: Dictionary = {}, world_effective_seconds := -1.0) -> void:
	for map_view in _optional_route_map_views():
		if map_view.has_method("set_optional_route_public_geometry"):
			map_view.call("set_optional_route_public_geometry", geometry_by_route_id)
		if map_view.has_method("set_optional_route_public_snapshot"):
			map_view.call("set_optional_route_public_snapshot", snapshot, world_effective_seconds)


func clear_optional_route_public_snapshot() -> void:
	for map_view in _optional_route_map_views():
		if map_view.has_method("clear_optional_route_public_snapshot"):
			map_view.call("clear_optional_route_public_snapshot")


func _sync_optional_route_public_surface(value: Variant) -> void:
	if not (value is Dictionary):
		return
	var source := value as Dictionary
	if not bool(source.get("source_bound", false)):
		return
	if not bool(source.get("available", false)):
		clear_optional_route_public_snapshot()
		return
	set_optional_route_public_snapshot(
		source.get("public_flow_snapshot", {}) if source.get("public_flow_snapshot", {}) is Dictionary else {},
		source.get("route_geometry_by_route_id", {}) if source.get("route_geometry_by_route_id", {}) is Dictionary else {},
		float(source.get("world_effective_seconds", -1.0))
	)


func _optional_route_map_views() -> Array[Control]:
	var result: Array[Control] = []
	var embedded := get_embedded_map_view()
	if embedded != null:
		result.append(embedded)
	if overlay_layer != null:
		var fullscreen := overlay_layer.find_child("FullscreenPlanetMapView", true, false) as Control
		if fullscreen != null and fullscreen != embedded:
			result.append(fullscreen)
	return result


func get_overlay_host() -> Node:
	return overlay_layer


func get_district_supply_drawer() -> Node:
	return overlay_layer.find_child("DistrictSupplySideDrawerOverlay", true, false) if overlay_layer != null else null


func get_visual_event_snapshot() -> Dictionary:
	if visual_event_layer != null and visual_event_layer.has_method("get_visual_event_snapshot"):
		return visual_event_layer.call("get_visual_event_snapshot") as Dictionary
	return {}


func get_runtime_player_feedback_snapshot() -> Dictionary:
	return _last_runtime_player_feedback.duplicate(true)


func present_action_result(result: Dictionary) -> bool:
	var action_id := str(result.get("action_id", "")).strip_edges()
	if action_id.is_empty() or not (result.get("success") is bool):
		return false
	var succeeded := bool(result.get("success", false))
	var detail := "%s｜%s｜%s｜%s" % [
		str(result.get("title", "动作未完成")),
		str(result.get("explanation", "现役事务没有返回可解释结果。")),
		str(result.get("consequence", "规则状态未改变。")),
		str(result.get("suggested_action", "刷新牌桌状态后重试。")),
	]
	_show_player_action_feedback(action_id, "resolved" if succeeded else "blocked", detail)
	return succeeded


func runtime_focus_order_snapshot() -> Array:
	_sync_runtime_table_focus_order()
	var controls := _runtime_table_focus_controls()
	var result: Array = []
	for index in range(controls.size()):
		var control: Control = controls[index]
		result.append({
			"name": control.name,
			"label": str(control.get_meta("runtime_focus_label", "")),
			"index": int(control.get_meta("runtime_focus_order_index", index)),
			"focus_mode": control.focus_mode,
			"focus_next": str(control.focus_next),
			"focus_previous": str(control.focus_previous),
		"visible": control.is_visible_in_tree(),
		})
	return result


func refresh_runtime_focus_order() -> void:
	_sync_runtime_table_focus_order()


func _sync_runtime_table_focus_order() -> void:
	var controls := _runtime_table_focus_controls()
	if controls.is_empty():
		return
	for index in range(controls.size()):
		var control: Control = controls[index]
		var next_control: Control = controls[wrapi(index + 1, 0, controls.size())]
		var previous_control: Control = controls[wrapi(index - 1, 0, controls.size())]
		control.focus_mode = Control.FOCUS_ALL
		control.focus_next = control.get_path_to(next_control)
		control.focus_previous = control.get_path_to(previous_control)
		control.set_meta("runtime_focus_order_index", index)
		control.set_meta("runtime_focus_kind", "table_focus_ring")


func _runtime_table_focus_controls() -> Array[Control]:
	var result: Array[Control] = []
	_append_runtime_focus_control(result, top_bar as Control, "顶部状态")
	_append_runtime_focus_control(result, commodity_sushi_track as Control, "公共商品带")
	_append_runtime_focus_control(result, _runtime_map_focus_control(), "星球地图")
	_append_runtime_focus_control(result, right_inspector as Control, "右侧详情")
	_append_runtime_focus_control(result, _first_visible_control(["DistrictSupplySideDrawer", "DistrictSupplyPanel", "DistrictSupplySideDrawerOverlay", "DistrictSupplyDrawer", "SideDrawerPanel"]), "区域牌架")
	_append_runtime_focus_control(result, _first_visible_control(["HandRack", "PlayerHandTableau", "PlayerBoard"]), "手牌")
	_append_runtime_focus_control(result, _first_visible_control(["PlayerMainActionDock", "PlayerCommandTableau", "PlayerBoard"]), "当前行动")
	_append_runtime_focus_control(result, _first_visible_control(["PublicBidDecisionPanel"]), "牌序竞价")
	return result


func _runtime_map_focus_control() -> Control:
	if planet_board != null and planet_board.has_method("get_runtime_map_focus_control"):
		var runtime_map: Variant = planet_board.call("get_runtime_map_focus_control")
		if runtime_map is Control and (runtime_map as Control).is_visible_in_tree():
			return runtime_map as Control
	return _first_visible_control(["MapHost", "PlanetStageViewport", "PlanetBoard"])


func _first_visible_control(names: Array[String]) -> Control:
	for node_name in names:
		var node := find_child(node_name, true, false)
		if node is Control and (node as Control).is_visible_in_tree():
			return node as Control
	return null


func _append_runtime_focus_control(result: Array[Control], control: Control, label: String) -> void:
	if control == null or not control.is_visible_in_tree():
		return
	for existing in result:
		if existing == control:
			return
	control.set_meta("runtime_focus_label", label)
	result.append(control)


func _sync_visual_events(ui_data: Dictionary) -> void:
	if visual_event_layer == null or not visual_event_layer.has_method("set_visual_events"):
		return
	var key := str(ui_data.get("visual_event_key", ""))
	var events: Array = ui_data.get("visual_events", []) if ui_data.get("visual_events", []) is Array else []
	if key == "" or events.is_empty():
		return
	if key == _last_visual_event_key:
		return
	_last_visual_event_key = key
	visual_event_layer.call("set_visual_events", events, false)


func _public_track_node() -> Node:
	return null


func _on_commodity_item_focused(item: COMMODITY_ITEM_SNAPSHOT_SCRIPT) -> void:
	if item == null or not item.is_valid():
		return
	_selected_hand_card_data = {}
	_selected_commodity_slot_id = item.commodity_slot_id
	_selected_commodity_item_data = item.to_dictionary()
	_last_commodity_action_result = {}
	if right_inspector != null and right_inspector.has_method("show_public_commodity"):
		right_inspector.call("show_public_commodity", _selected_commodity_item_data, {})


func _on_commodity_claim_requested(item: COMMODITY_ITEM_SNAPSHOT_SCRIPT) -> void:
	_on_commodity_item_focused(item)
	_submit_selected_commodity_claim()


func _submit_selected_commodity_claim() -> void:
	if _selected_commodity_slot_id.is_empty() or _selected_commodity_item_data.is_empty():
		return
	if _forced_surface_blocks_player_actions():
		_show_player_action_feedback("commodity_claim", "blocked", "请先完成当前强制决策。")
		return
	var track_state: Dictionary = current_ui_data.get("commodity_sushi_track", {}) \
		if current_ui_data.get("commodity_sushi_track", {}) is Dictionary else {}
	var request: COMMODITY_CLAIM_REQUEST_SCRIPT = COMMODITY_CLAIM_REQUEST_SCRIPT.new()
	request.viewer_index = _presentation_authorized_viewer_index
	request.commodity_slot_id = _selected_commodity_slot_id
	request.commodity_card_id = str(_selected_commodity_item_data.get("commodity_card_id", ""))
	request.snapshot_revision = int(track_state.get("snapshot_revision", -1))
	request.belt_revision = int(track_state.get("belt_revision", -1))
	request.visibility_revision = int(track_state.get("visibility_revision", -1))
	request.request_revision = _commodity_claim_request_revision
	_commodity_claim_request_revision += 1
	if not bool(request.validation_report().get("valid", false)):
		return
	commodity_claim_requested.emit(request)


func apply_commodity_claim_result(result: Dictionary, snapshot: COMMODITY_TRACK_SNAPSHOT_SCRIPT) -> void:
	_last_commodity_action_result = result.duplicate(true)
	if snapshot != null and snapshot.is_valid():
		var snapshot_data := snapshot.to_dictionary()
		current_ui_data["commodity_sushi_track"] = snapshot_data
		if commodity_sushi_track != null:
			commodity_sushi_track.set_snapshot(snapshot)
	if right_inspector != null and right_inspector.has_method("show_public_commodity") \
			and not _selected_commodity_item_data.is_empty():
		right_inspector.call("show_public_commodity", _selected_commodity_item_data, _last_commodity_action_result)


func _restore_selected_commodity_focus() -> bool:
	if _selected_commodity_item_data.is_empty() or right_inspector == null \
			or not right_inspector.has_method("show_public_commodity"):
		return false
	var current_item := commodity_sushi_track.item_snapshot_by_id(_selected_commodity_slot_id) \
		if commodity_sushi_track != null and not _selected_commodity_slot_id.is_empty() else null
	if current_item != null:
		_selected_commodity_item_data = current_item.to_dictionary()
	elif _last_commodity_action_result.is_empty():
		return false
	right_inspector.call("show_public_commodity", _selected_commodity_item_data, _last_commodity_action_result)
	return true


func _on_end_turn_requested() -> void:
	if _forced_surface_blocks_player_actions():
		_show_player_action_feedback("end_turn", "blocked", "请先完成当前强制决策。")
		return
	_show_player_action_feedback("end_turn", "pending", "结束回合已提交，等待桌面进入下一阶段。")
	end_turn_requested.emit()


func _on_menu_requested() -> void:
	_on_action_requested("menu")


func request_pause_menu() -> void:
	_on_action_requested("menu")


func _on_action_requested(action_id: String) -> void:
	if action_id == "commodity_claim_selected":
		_submit_selected_commodity_claim()
		return
	if action_id in ["rack", "buy", "district_open_rack", "primary_open_development_rack", "primary_open_rack", "primary_review_rack", "strategy_build_gdp_source"]:
		if _forced_surface_blocks_player_actions():
			_show_player_action_feedback(action_id, "blocked", "请先完成当前强制决策。")
			return
		_emit_district_supply_action(
			DISTRICT_SUPPLY_ACTION_INTENT_SCRIPT.KIND_OPEN,
			int(_selection_context().get("selected_district", -1)),
			"",
			-1,
			&"game_screen"
		)
		return
	if action_id.begins_with("track_select_"):
		_emit_track_action_request(action_id, "已选择公共轨道线索。", &"right_inspector")
		return
	if _forced_surface_blocks_player_actions():
		_show_player_action_feedback(action_id, "blocked", "请先完成当前强制决策。")
		return
	if _should_open_detail_drawer(action_id):
		_open_detail_drawer(action_id)
	_show_player_action_feedback(action_id)
	if _emit_navigation_intent_if_supported(action_id, &"game_screen"):
		return
	action_requested.emit(action_id)


func _on_application_intent_requested(intent: IntelApplicationIntent) -> void:
	if intent == null or not intent.is_valid() or _forced_surface_blocks_player_actions():
		return
	application_intent_requested.emit(intent)


func _on_track_link_hovered(action_id: String) -> void:
	_set_public_track_hover(action_id)
	_show_track_action_hover_preview(action_id)


func _on_track_link_unhovered(_action_id: String) -> void:
	_set_public_track_hover("")
	_temporary_track_focus_active = false
	_restore_right_inspector_context()
	_sync_selected_track_focus_from_state()


func _set_public_track_hover(action_id: String) -> void:
	var track_node := _public_track_node()
	if track_node != null and track_node.has_method("set_hovered_track_action"):
		track_node.call("set_hovered_track_action", action_id)


func _on_track_entry_hovered(entry: Dictionary) -> void:
	_set_player_board_track_hover(_track_hover_action(entry))
	_show_track_entry_hover_preview(entry)
	_show_track_focus_for_entry(entry, "牌轨对照", true)


func _on_track_entry_unhovered(_entry: Dictionary) -> void:
	_set_player_board_track_hover("")
	_temporary_track_focus_active = false
	_restore_right_inspector_context()
	_sync_selected_track_focus_from_state()


func _set_player_board_track_hover(action_id: String) -> void:
	if overlay_layer != null:
		var bid_panel := overlay_layer.find_child("PublicBidDecisionPanel", true, false)
		if bid_panel != null and bid_panel.has_method("set_hovered_track_action"):
			bid_panel.call("set_hovered_track_action", action_id)


func _show_track_entry_hover_preview(entry: Dictionary) -> void:
	if entry.is_empty() or right_inspector == null or not right_inspector.has_method("set_context"):
		return
	right_inspector.call("set_context", _track_entry_inspector_context(entry))


func _show_track_action_hover_preview(action_id: String) -> void:
	var entry := _track_entry_for_action(action_id)
	if entry.is_empty():
		_show_track_focus_for_action(action_id, true)
		return
	_show_track_entry_hover_preview(entry)
	_show_track_focus_for_entry(entry, "竞价对照", true)


func _on_side_drawer_action_requested(action_id: String) -> void:
	if _forced_surface_blocks_player_actions():
		_show_player_action_feedback(action_id, "blocked", "请先完成当前强制决策。")
		return
	_show_player_action_feedback(action_id, "resolved", "侧栏动作已提交。")
	action_requested.emit(action_id)


func _on_temporary_decision_action_requested(action_id: String) -> void:
	if action_id == "discard_purchase_cancel":
		_emit_district_supply_action(DISTRICT_SUPPLY_ACTION_INTENT_SCRIPT.KIND_DISCARD_CANCEL, -1, "", -1, &"forced_decision")
		return
	if action_id.begins_with("discard_purchase_"):
		var slot_index := int(action_id.trim_prefix("discard_purchase_"))
		_emit_district_supply_action(DISTRICT_SUPPLY_ACTION_INTENT_SCRIPT.KIND_DISCARD_CONFIRM, -1, "", slot_index, &"forced_decision")
		return
	if action_id.begins_with("monster_wager:"):
		if not _emit_forced_decision_response(action_id, "monster_wager", "monster-wager"):
			_show_player_action_feedback(action_id, "blocked", "赌局已经变化，请等待桌面刷新。")
		return
	if action_id == "target_monster_cancel" or action_id.begins_with("target_monster_") \
			or action_id == "target_player_cancel" or action_id.begins_with("target_player_"):
		var expected_kind := "monster_target_choice" if action_id.begins_with("target_monster_") else "player_target_choice"
		if not _emit_forced_decision_response(action_id, expected_kind, "target-choice"):
			_show_player_action_feedback(action_id, "blocked", "目标选择已失效，请等待桌面刷新。")
		return
	_show_player_action_feedback(action_id, "resolved", "临时决策已提交，等待规则结算。")
	action_requested.emit(action_id)


func _emit_forced_decision_response(option_id: String, expected_kind: String, request_prefix: String) -> bool:
	if not _selection_identity_is_bound():
		return false
	var active: Dictionary = current_ui_data.get("active_forced_decision", {}) \
			if current_ui_data.get("active_forced_decision", {}) is Dictionary else {}
	var rendered := _rendered_forced_decision_binding
	if str(active.get("kind", "")) != expected_kind \
			or str(rendered.get("kind", "")) != expected_kind \
			or str(rendered.get("decision_id", "")) != str(active.get("id", "")) \
			or int(rendered.get("decision_revision", 0)) != int(active.get("decision_revision", 0)) \
			or not bool(active.get("visible_to_viewer", false)) \
			or int(active.get("decision_revision", 0)) <= 0:
		return false
	_forced_decision_response_request_revision += 1
	var request := ForcedDecisionResponseRequest.new()
	request.request_id = "%s:%d:%d" % [request_prefix, _presentation_authorized_viewer_index, _forced_decision_response_request_revision]
	request.viewer_index = _presentation_authorized_viewer_index
	request.authorized_player_index = _presentation_authorized_viewer_index
	request.authorization_revision = _presentation_authorization_revision
	request.session_id = _presentation_session_id
	request.session_revision = _presentation_session_revision
	request.source_surface = &"forced_decision"
	request.request_revision = _forced_decision_response_request_revision
	request.decision_id = str(rendered.get("decision_id", ""))
	request.decision_kind = StringName(expected_kind)
	request.decision_revision = int(rendered.get("decision_revision", 0))
	request.option_id = option_id
	if not bool(request.validation_report().get("valid", false)):
		return false
	forced_decision_response_requested.emit(request)
	return true


func _on_public_bid_action_requested(action_id: String) -> void:
	if action_id.begins_with("track_select_"):
		_emit_track_action_request(action_id, "已选择竞价对应的公共牌轨线索。", &"public_bid_board")
		return
	_show_player_action_feedback(action_id, "resolved", "牌序竞价选择已提交，等待牌序阶段推进。")
	action_requested.emit(action_id)


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or event == null:
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if _should_ignore_player_inspection_hotkey():
		return
	if _handle_table_selection_hotkey(key_event):
		accept_event()
		return
	var inspected_index := _player_inspection_index_for_key(key_event)
	if inspected_index >= 0:
		accept_event()
		request_player_inspection(inspected_index, &"keyboard_hotkey")
		return
	if _should_ignore_quick_action_hotkey():
		return
	var quick_index := _quick_action_index_for_key(key_event)
	if quick_index < 0:
		return
	var action_id := _quick_action_id_at(quick_index)
	if action_id == "":
		return
	accept_event()
	_on_action_requested(action_id)


func _handle_table_selection_hotkey(event: InputEventKey) -> bool:
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		return false
	var context := _selection_context()
	match event.keycode:
		KEY_C:
			return _cycle_district_supply_quote()
		KEY_X:
			return request_selected_district_supply_purchase(&"keyboard_hotkey")
		KEY_Q, KEY_E:
			var district_count := int(context.get("district_count", 0))
			if district_count <= 0:
				return false
			var step := -1 if event.keycode == KEY_Q else 1
			var selected := int(context.get("selected_district", 0))
			return request_district_selection(wrapi(selected + step, 0, district_count), &"keyboard_hotkey")
		KEY_R:
			var current_product := str(context.get("selected_trade_product", ""))
			return request_trade_product_selection("" if not current_product.is_empty() else _default_trade_product_from_context(context), &"keyboard_hotkey")
		KEY_T:
			var product_ids: Array = context.get("trade_product_ids", []) if context.get("trade_product_ids", []) is Array else []
			if product_ids.is_empty():
				return false
			var current_product := str(context.get("selected_trade_product", ""))
			var current_index := product_ids.find(current_product)
			return request_trade_product_selection(str(product_ids[0] if current_index < 0 else product_ids[wrapi(current_index + 1, 0, product_ids.size())]), &"keyboard_hotkey")
	return false


func _cycle_district_supply_quote() -> bool:
	var drawer := get_district_supply_drawer()
	if drawer == null or not drawer.has_method("debug_snapshot"):
		return false
	var snapshot: Dictionary = drawer.call("debug_snapshot")
	var card_ids: Array = snapshot.get("rendered_card_names", []) if snapshot.get("rendered_card_names", []) is Array else []
	if card_ids.is_empty():
		return false
	var district_index := int(_selection_context().get("selected_district", -1))
	var current_id := str(_district_supply_selected_card_by_district.get(district_index, ""))
	var current_index := card_ids.find(current_id)
	var next_id := str(card_ids[0] if current_index < 0 else card_ids[wrapi(current_index + 1, 0, card_ids.size())])
	return _emit_district_supply_action(DISTRICT_SUPPLY_ACTION_INTENT_SCRIPT.KIND_QUOTE, district_index, next_id, -1, &"keyboard_hotkey")


func _selection_context() -> Dictionary:
	return current_ui_data.get("selection_context", {}) if current_ui_data.get("selection_context", {}) is Dictionary else {}


func _default_trade_product_from_context(context: Dictionary) -> String:
	var preferred := str(context.get("default_trade_product_id", ""))
	if not preferred.is_empty():
		return preferred
	var product_ids: Array = context.get("trade_product_ids", []) if context.get("trade_product_ids", []) is Array else []
	return str(product_ids[0]) if not product_ids.is_empty() else ""


func _should_ignore_quick_action_hotkey() -> bool:
	if not is_visible_in_tree():
		return true
	var focused := get_viewport().gui_get_focus_owner() if get_viewport() != null else null
	if focused is LineEdit or focused is TextEdit:
		return true
	var decision: Dictionary = current_ui_data.get("temporary_decision", {}) if current_ui_data.get("temporary_decision", {}) is Dictionary else {}
	if not decision.is_empty():
		return true
	return overlay_layer != null and overlay_layer.has_method("public_bid_visible") and bool(overlay_layer.call("public_bid_visible"))


func _should_ignore_player_inspection_hotkey() -> bool:
	if not is_visible_in_tree():
		return true
	var focused := get_viewport().gui_get_focus_owner() if get_viewport() != null else null
	return focused is LineEdit or focused is TextEdit


func _player_inspection_index_for_key(event: InputEventKey) -> int:
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		return -1
	var code := int(event.unicode)
	if code >= 49 and code <= 56:
		return code - 49
	if event.keycode >= KEY_1 and event.keycode <= KEY_8:
		return int(event.keycode - KEY_1)
	return -1


func _quick_action_index_for_key(event: InputEventKey) -> int:
	if not event.ctrl_pressed:
		return -1
	var code := int(event.unicode)
	if code >= 49 and code <= 52:
		return code - 49
	return -1


func _quick_action_id_at(index: int) -> String:
	var player_data: Dictionary = current_ui_data.get("player_board", {}) if current_ui_data.get("player_board", {}) is Dictionary else {}
	var quick_actions: Array = player_data.get("quick_actions", []) if player_data.get("quick_actions", []) is Array else []
	if index < 0 or index >= quick_actions.size():
		return ""
	var action: Dictionary = quick_actions[index] if quick_actions[index] is Dictionary else {}
	if bool(action.get("disabled", false)) or not bool(action.get("active", false)):
		return ""
	return str(action.get("id", "")).strip_edges()


func _on_card_selected(card_data: Dictionary) -> void:
	_selected_commodity_slot_id = ""
	_selected_commodity_item_data = {}
	_last_commodity_action_result = {}
	_selected_hand_card_data = card_data.duplicate(true)
	request_hand_selection(_hand_slot_from_card_data(card_data), &"hand_rack")
	if right_inspector.has_method("show_card"):
		right_inspector.call("show_card", card_data)
	card_selected.emit(card_data)


func _on_card_hovered(card_data: Dictionary) -> void:
	_show_hand_hover_preview(card_data)
	if right_inspector.has_method("show_card") and not card_data.is_empty():
		right_inspector.call("show_card", card_data)
	card_hovered.emit(card_data)


func _on_card_unhovered() -> void:
	_hide_hand_hover_preview()
	if not _selected_hand_card_data.is_empty() and right_inspector.has_method("show_card"):
		right_inspector.call("show_card", _selected_hand_card_data)
	else:
		_restore_right_inspector_context()
		if not _restore_selected_commodity_focus():
			_sync_selected_track_focus_from_state()
	card_unhovered.emit()


func _on_card_unselected(card_data: Dictionary) -> void:
	_selected_hand_card_data = {}
	request_hand_selection(-1, &"hand_rack")
	_restore_right_inspector_context()
	if not _restore_selected_commodity_focus():
		_sync_selected_track_focus_from_state()
	card_unselected.emit(card_data)


func _on_track_entry_selected(entry: Dictionary) -> void:
	_selected_commodity_slot_id = ""
	_selected_commodity_item_data = {}
	_last_commodity_action_result = {}
	_clear_hand_detail_focus_for_track()
	request_hand_selection(-1, &"game_screen")
	if right_inspector.has_method("set_context"):
		right_inspector.call("set_context", _track_entry_inspector_context(entry))
	_show_track_focus_for_entry(entry, "已选牌轨", false)
	var action_id := _track_select_action(entry)
	if action_id != "":
		_emit_track_action_request(action_id, "已选择公共轨道线索。", &"card_resolution_track")


func _on_track_entry_opened(entry: Dictionary) -> void:
	_clear_hand_detail_focus_for_track()
	request_hand_selection(-1, &"game_screen")
	if right_inspector.has_method("set_context"):
		right_inspector.call("set_context", _track_entry_inspector_context(entry))
	_show_track_focus_for_entry(entry, "打开牌轨", false)
	var action_id := _track_open_action(entry)
	if action_id != "":
		_emit_track_action_request(action_id, "已打开公共轨道线索。")


func _on_track_action_requested(action_id: String) -> void:
	_emit_track_action_request(action_id, "公共牌轨响应已提交。", &"card_resolution_track")


func _emit_track_action_request(action_id: String, detail: String, source_surface: StringName = &"card_resolution_track") -> void:
	var normalized_action_id := action_id.strip_edges()
	if normalized_action_id == "":
		return
	if _forced_surface_blocks_player_actions():
		_show_player_action_feedback(normalized_action_id, "blocked", "请先完成当前强制决策。")
		return
	var current_frame := Engine.get_process_frames()
	if _last_track_action_bridge_id == normalized_action_id and _last_track_action_bridge_frame == current_frame:
		return
	_last_track_action_bridge_id = normalized_action_id
	_last_track_action_bridge_frame = current_frame
	if normalized_action_id.begins_with("track_select_"):
		var resolution_text := normalized_action_id.substr("track_select_".length()).strip_edges()
		if not resolution_text.is_valid_int() or not request_card_resolution_selection(int(resolution_text), source_surface):
			_show_player_action_feedback(normalized_action_id, "blocked", "这条公共牌轨记录无法选择。")
			return
		return
	_show_player_action_feedback(normalized_action_id, "pending", detail)
	if _emit_navigation_intent_if_supported(normalized_action_id, source_surface):
		return
	action_requested.emit(normalized_action_id)


func _emit_navigation_intent_if_supported(action_id: String, source_surface: StringName) -> bool:
	var intent := TABLE_NAVIGATION_ACTION_INTENT_SCRIPT.from_action_id(action_id, source_surface)
	if intent == null:
		return false
	_navigation_request_revision += 1
	intent.request_id = "table-navigation:%d" % _navigation_request_revision
	navigation_intent_requested.emit(intent)
	return true


func _on_card_drag_preview_started(card_data: Dictionary, screen_position: Vector2) -> void:
	if _forced_surface_blocks_player_actions():
		return
	_hide_hand_hover_preview()
	_show_card_drag_feedback(card_data, screen_position)
	card_drag_preview_started.emit(card_data)


func _on_card_drag_preview_moved(card_data: Dictionary, screen_position: Vector2) -> void:
	_show_card_drag_feedback(card_data, screen_position)


func _on_card_drag_preview_ended(card_data: Dictionary) -> void:
	if overlay_layer != null and overlay_layer.has_method("hide_drag_preview"):
		overlay_layer.call("hide_drag_preview")
	card_drag_preview_ended.emit(card_data)


func _on_card_drag_released(card_data: Dictionary, screen_position: Vector2) -> void:
	if _forced_surface_blocks_player_actions():
		return
	if _card_drop_zone_contains(screen_position) and _card_can_drop_on_map(card_data):
		var district_index := _district_at_map_position(screen_position)
		if district_index < 0 or not request_district_selection(district_index, &"planet_map"):
			return
		if int(_selection_context().get("selected_district", -1)) != district_index:
			return
		request_hand_selection(_hand_slot_from_card_data(card_data), &"hand_rack")
		card_drop_requested.emit(card_data, screen_position)


func _hand_slot_from_card_data(card_data: Dictionary) -> int:
	var card_id := str(card_data.get("id", ""))
	if card_id.begins_with("hand_"):
		var slot_text := card_id.substr("hand_".length())
		return int(slot_text) if slot_text.is_valid_int() else -1
	var actions: Array = card_data.get("actions", []) if card_data.get("actions", []) is Array else []
	for action_variant in actions:
		if not (action_variant is Dictionary):
			continue
		var action_id := str((action_variant as Dictionary).get("id", ""))
		if action_id.begins_with("play_"):
			var slot_text := action_id.substr("play_".length())
			if slot_text.is_valid_int():
				return int(slot_text)
	return -1


func _district_at_map_position(screen_position: Vector2) -> int:
	var map_control := _map_drop_control()
	if map_control == null:
		return -1
	var map_rect := map_control.get_global_rect()
	if not map_rect.has_point(screen_position) or not map_control.has_method("get_district_at_control_position"):
		return -1
	return int(map_control.call("get_district_at_control_position", screen_position - map_rect.position))


func _show_card_drag_feedback(card_data: Dictionary, screen_position: Vector2) -> void:
	if overlay_layer == null or not overlay_layer.has_method("show_drag_preview"):
		return
	if _forced_surface_blocks_player_actions():
		overlay_layer.call("hide_drag_preview")
		return
	var over_map := _card_drop_zone_contains(screen_position)
	var valid_drop := over_map and _card_can_drop_on_map(card_data)
	overlay_layer.call(
		"show_drag_preview",
		_drag_preview_text(card_data, over_map, valid_drop),
		screen_position + Vector2(14, -28),
		_drag_drop_hint(screen_position, over_map, valid_drop, card_data)
	)


func _drag_preview_text(card_data: Dictionary, over_map: bool = false, valid_drop: bool = false) -> String:
	var name_text := str(card_data.get("name", "手牌")).strip_edges()
	var type_text := str(card_data.get("type", card_data.get("category", ""))).strip_edges()
	var cost_text := str(card_data.get("cost", card_data.get("price", ""))).strip_edges()
	var pieces: Array[String] = [name_text]
	if type_text != "":
		pieces.append(type_text)
	if cost_text != "":
		pieces.append("费用 %s" % cost_text)
	pieces.append(_card_drop_feedback_label(card_data, over_map, valid_drop))
	return "\n".join(pieces)


func _restore_right_inspector_context() -> void:
	if right_inspector == null or not right_inspector.has_method("set_context"):
		return
	var inspector: Dictionary = current_ui_data.get("right_inspector", {}) if current_ui_data.get("right_inspector", {}) is Dictionary else {}
	right_inspector.call("set_context", inspector)


func _clear_hand_detail_focus_for_track() -> void:
	_selected_hand_card_data = {}
	_selected_commodity_slot_id = ""
	_selected_commodity_item_data = {}
	_last_commodity_action_result = {}
	_hide_hand_hover_preview()


func _track_entry_inspector_context(entry: Dictionary) -> Dictionary:
	var public_entry := _safe_public_track_entry(entry)
	var requirements: Array = (public_entry.get("requirements", []) as Array).duplicate(true) if public_entry.get("requirements", []) is Array else []
	var actions: Array = (public_entry.get("actions", []) as Array).duplicate(true) if public_entry.get("actions", []) is Array else []
	var deep_links: Array = (public_entry.get("deep_links", []) as Array).duplicate(true) if public_entry.get("deep_links", []) is Array else []
	_append_track_action_if_missing(actions, _track_select_action(public_entry), "查看履历", "把这条公共动作设为当前查看对象。")
	_append_track_intel_intent_if_missing(actions, public_entry)
	_append_track_intel_intent_if_missing(deep_links, public_entry)
	_append_track_action_if_missing(actions, _track_open_action(public_entry), "卡牌详情", "打开这张公开牌的图鉴详情。")
	_append_track_action_if_missing(deep_links, _track_open_action(public_entry), "卡牌详情", "打开这张公开牌的图鉴详情。")
	var badges: Array = public_entry.get("badges", []) if public_entry.get("badges", []) is Array else []
	var chips: Array = [
		{"text": "槽 %s" % str(public_entry.get("slot", "--"))},
		{"text": str(public_entry.get("state", "等待"))},
	]
	var owner_hint := _track_owner_hint_text(public_entry)
	if owner_hint != "":
		chips.append({"text": "来源%s" % owner_hint})
	var cost_text := str(public_entry.get("cost", "")).strip_edges()
	if cost_text != "":
		chips.append({"text": "报价%s" % cost_text})
	for badge_variant in badges:
		var badge_text := str(badge_variant).strip_edges()
		if badge_text != "":
			chips.append({"text": badge_text})
		if chips.size() >= 6:
			break
	var logs: Array = []
	var current_logs: Variant = current_ui_data.get("logs", [])
	var safe_logs: Variant = _sanitize_public_track_value(current_logs)
	if safe_logs is Array:
		logs = safe_logs
	return {
		"context_kind": "public_track",
		"resolution_id": int(public_entry.get("resolution_id", -1)),
		"title": str(public_entry.get("title", "牌轨详情")),
		"why": str(public_entry.get("why", public_entry.get("tooltip", "看状态、报价、归属和余波线索来推理来源。"))),
		"district": {
			"id": str(public_entry.get("id", "")),
			"title": str(public_entry.get("label", "公共牌槽")),
			"summary": str(public_entry.get("summary", public_entry.get("tooltip", ""))),
			"detail": str(public_entry.get("detail", public_entry.get("tooltip", ""))),
			"full_detail": str(public_entry.get("full_detail", public_entry.get("tooltip", ""))),
			"chips": chips,
		},
		"requirements": requirements,
		"actions": actions,
		"deep_links": deep_links,
		"logs": logs,
	}


func _track_hover_action(entry: Dictionary) -> String:
	return _track_select_action(entry)


func _track_select_action(entry: Dictionary) -> String:
	var action_id := str(entry.get("select_action", "")).strip_edges()
	if action_id != "":
		return action_id
	if bool(entry.get("disabled", false)) or str(entry.get("kind", "")).strip_edges().to_lower() == "event":
		return ""
	var resolution_id := int(entry.get("resolution_id", -1))
	return "track_select_%d" % resolution_id if resolution_id >= 0 else ""


func _track_open_action(entry: Dictionary) -> String:
	var action_id := str(entry.get("open_action", "")).strip_edges()
	if action_id != "":
		return action_id
	var card_name := str(entry.get("card_name", "")).strip_edges()
	return "track_open_%s" % card_name if card_name != "" else ""


func _append_track_action_if_missing(target: Array, action_id: String, label: String, tooltip: String) -> void:
	if action_id == "":
		return
	for action_variant in target:
		var action: Dictionary = action_variant if action_variant is Dictionary else {}
		if str(action.get("id", action.get("action_id", ""))).strip_edges() == action_id:
			return
	target.append({"id": action_id, "label": label, "tooltip": tooltip})


func _append_track_intel_intent_if_missing(target: Array, entry: Dictionary) -> void:
	if str(entry.get("kind", "")).strip_edges().to_lower() == "event":
		return
	var resolution_id := int(entry.get("resolution_id", -1))
	if resolution_id < 0:
		return
	for action_variant in target:
		var action: Dictionary = action_variant if action_variant is Dictionary else {}
		var intent_value: Variant = action.get("application_intent", {})
		if intent_value is Dictionary and str((intent_value as Dictionary).get("focused_history_entry_id", "")) == "card-history:%d" % resolution_id:
			return
	target.append({
		"id": "intel",
		"label": "线索档案",
		"tooltip": "打开情报档案并置顶这张公共履历。",
		"application_intent": IntelApplicationIntent.open("card-history:%d" % resolution_id).to_dictionary(),
	})


func _safe_public_track_entry(entry: Dictionary) -> Dictionary:
	var safe_variant: Variant = _sanitize_public_track_value(entry)
	return safe_variant if safe_variant is Dictionary else {}


func _sanitize_public_track_value(value: Variant) -> Variant:
	if value is Dictionary:
		var dictionary_result: Dictionary = {}
		for key_variant in value:
			var key := str(key_variant).to_lower()
			if _is_private_track_key(key):
				continue
			dictionary_result[key_variant] = _sanitize_public_track_value((value as Dictionary)[key_variant])
		return dictionary_result
	if value is Array:
		var array_result: Array = []
		for entry_variant in value:
			array_result.append(_sanitize_public_track_value(entry_variant))
		return array_result
	if value is String:
		return _safe_public_track_text(value)
	return value


func _is_private_track_key(key: String) -> bool:
	return PRIVATE_TRACK_ENTRY_KEYS.has(key) or key.begins_with("private_") or key.begins_with("hidden_")


func _safe_public_track_text(value: String) -> String:
	var lower := value.to_lower()
	for token in PRIVATE_TRACK_TEXT_TOKENS:
		if lower.contains(token):
			return "匿名线索"
	return value


func _configure_hand_hover_preview() -> void:
	if hand_hover_preview_host == null:
		return
	_set_overlay_anchor_rect(
		hand_hover_preview_host,
		HAND_HOVER_PREVIEW_LEFT,
		HAND_HOVER_PREVIEW_TOP,
		HAND_HOVER_PREVIEW_RIGHT,
		HAND_HOVER_PREVIEW_BOTTOM
	)
	_set_mouse_filter_recursive(hand_hover_preview_host, Control.MOUSE_FILTER_IGNORE)
	hand_hover_preview_host.visible = false
	if hand_hover_preview_panel != null:
		hand_hover_preview_panel.add_theme_stylebox_override("panel", _hand_hover_preview_style())
	if hand_hover_preview_title != null:
		hand_hover_preview_title.add_theme_font_size_override("font_size", 11)
		hand_hover_preview_title.add_theme_color_override("font_color", Color("#fde68a"))
	if hand_hover_preview_card != null:
		hand_hover_preview_card.custom_minimum_size = HAND_HOVER_PREVIEW_CARD_MIN_SIZE
		hand_hover_preview_card.set_meta("hand_hover_readable_preview", true)


func _set_mouse_filter_recursive(node: Node, filter: Control.MouseFilter) -> void:
	if node is Control:
		(node as Control).mouse_filter = filter
	for child in node.get_children():
		_set_mouse_filter_recursive(child, filter)


func _show_hand_hover_preview(card_data: Dictionary) -> void:
	if hand_hover_preview_host == null or hand_hover_preview_card == null or card_data.is_empty():
		_hide_hand_hover_preview()
		return
	var display_data := card_data.duplicate(true)
	display_data["presentation"] = "inspector_full"
	display_data["detail_policy"] = "hover_readable_preview"
	display_data["summary"] = _hand_hover_preview_effect_text(card_data)
	if hand_hover_preview_card.has_method("set_card_data"):
		hand_hover_preview_card.call("set_card_data", display_data)
	if hand_hover_preview_title != null:
		hand_hover_preview_title.text = _hand_hover_preview_title(card_data)
		hand_hover_preview_title.tooltip_text = _hand_hover_preview_detail(card_data)
	hand_hover_preview_host.visible = true
	hand_hover_preview_host.set_meta("runtime_focus_kind", "hand_hover_readable_preview")
	hand_hover_preview_host.set_meta("hand_hover_card_name", str(card_data.get("name", "")))
	hand_hover_preview_host.set_meta("hand_hover_preview_policy", "left-side-readable-card")


func _hide_hand_hover_preview() -> void:
	if hand_hover_preview_host == null:
		return
	hand_hover_preview_host.visible = false
	hand_hover_preview_host.set_meta("hand_hover_card_name", "")


func get_hand_hover_preview_snapshot() -> Dictionary:
	if hand_hover_preview_host == null:
		return {"visible": false}
	var rect := hand_hover_preview_host.get_global_rect()
	return {
		"visible": hand_hover_preview_host.visible,
		"card_name": str(hand_hover_preview_host.get_meta("hand_hover_card_name", "")),
		"policy": str(hand_hover_preview_host.get_meta("hand_hover_preview_policy", "")),
		"rect": rect,
		"anchor_left": HAND_HOVER_PREVIEW_LEFT,
		"anchor_right": HAND_HOVER_PREVIEW_RIGHT,
		"card_min_size": HAND_HOVER_PREVIEW_CARD_MIN_SIZE,
	}


func _hand_hover_preview_title(card_data: Dictionary) -> String:
	var name_text := str(card_data.get("name", "手牌")).strip_edges()
	var type_text := str(card_data.get("type", card_data.get("category", ""))).strip_edges()
	var rank_text := str(card_data.get("rank", card_data.get("stats", ""))).strip_edges()
	var pieces: Array[String] = []
	if type_text != "":
		pieces.append(type_text)
	if rank_text != "":
		pieces.append(rank_text)
	pieces.append(name_text if name_text != "" else "手牌")
	var text := "｜".join(pieces)
	return text if text.length() <= 24 else "%s..." % text.left(21)


func _hand_hover_preview_effect_text(card_data: Dictionary) -> String:
	for key in ["summary", "short_effect", "effect", "text", "description"]:
		var value := str(card_data.get(key, "")).replace("\n", " ").strip_edges()
		if value != "":
			return value
	return "查看右侧详情或双击使用。"


func _hand_hover_preview_detail(card_data: Dictionary) -> String:
	var effect := _hand_hover_preview_effect_text(card_data)
	var target := str(card_data.get("target", card_data.get("target_type", ""))).strip_edges()
	var requirement := str(card_data.get("requirement", card_data.get("play_requirement", card_data.get("condition", "")))).strip_edges()
	var lines: Array[String] = [effect]
	if target != "":
		lines.append("目标：%s" % target)
	if requirement != "":
		lines.append("条件：%s" % requirement)
	return "\n".join(lines)


func _hand_hover_preview_style() -> StyleBoxFlat:
	var accent := Color("#f59e0b")
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#020617").lerp(accent, 0.10)
	style.border_color = Color("#334155").lerp(accent, 0.58)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.set_content_margin(SIDE_LEFT, 0.0)
	style.set_content_margin(SIDE_RIGHT, 0.0)
	style.set_content_margin(SIDE_TOP, 0.0)
	style.set_content_margin(SIDE_BOTTOM, 0.0)
	return style


func _sync_selected_track_focus_from_state() -> void:
	var selected_entry := _selected_track_entry()
	if selected_entry.is_empty():
		_clear_track_focus_ribbon()
		return
	_show_track_focus_for_entry(selected_entry, "已选牌轨", false)
	if not _selected_hand_card_data.is_empty() or _right_inspector_state_is_hand_card():
		return
	if right_inspector != null and right_inspector.has_method("set_context"):
		right_inspector.call("set_context", _track_entry_inspector_context(selected_entry))


func _right_inspector_state_is_hand_card() -> bool:
	var inspector: Dictionary = current_ui_data.get("right_inspector", {}) if current_ui_data.get("right_inspector", {}) is Dictionary else {}
	return str(inspector.get("context_kind", "")).strip_edges() == "hand_card" or str(inspector.get("title", "")).strip_edges() == "卡牌详情"


func _selected_track_entry() -> Dictionary:
	var entries: Array = current_ui_data.get("card_track", []) if current_ui_data.get("card_track", []) is Array else []
	for entry_variant in entries:
		var entry: Dictionary = entry_variant if entry_variant is Dictionary else {}
		if bool(entry.get("selected", entry.get("focused", false))):
			return entry
	return {}


func _track_entry_for_action(action_id: String) -> Dictionary:
	var normalized := action_id.strip_edges()
	if normalized == "":
		return {}
	var entries: Array = current_ui_data.get("card_track", []) if current_ui_data.get("card_track", []) is Array else []
	for entry_variant in entries:
		var entry: Dictionary = entry_variant if entry_variant is Dictionary else {}
		if _track_entry_matches_action(entry, normalized):
			return entry
	return {}


func _track_entry_matches_action(entry: Dictionary, action_id: String) -> bool:
	if action_id in [_track_select_action(entry), _track_open_action(entry)]:
		return true
	var actions: Array = entry.get("actions", []) if entry.get("actions", []) is Array else []
	for action_variant in actions:
		var action: Dictionary = action_variant if action_variant is Dictionary else {}
		if str(action.get("id", action.get("action_id", ""))).strip_edges() == action_id:
			return true
	return false


func _show_track_focus_for_entry(entry: Dictionary, prefix: String, temporary: bool) -> void:
	_temporary_track_focus_active = temporary


func _show_track_focus_for_action(action_id: String, temporary: bool) -> void:
	_temporary_track_focus_active = temporary


func _clear_track_focus_ribbon() -> void:
	_temporary_track_focus_active = false


func _track_focus_text(entry: Dictionary, prefix: String) -> String:
	var pieces: Array[String] = []
	var slot := str(entry.get("slot", "")).strip_edges()
	var label := str(entry.get("label", entry.get("title", "公共牌"))).strip_edges()
	if slot != "" and label != "":
		pieces.append("%s %s" % [slot, label])
	elif label != "":
		pieces.append(label)
	var state := str(entry.get("state", "")).strip_edges()
	if state != "":
		pieces.append(state)
	var owner_hint := _track_owner_hint_text(entry)
	if owner_hint != "":
		pieces.append("来源%s" % owner_hint)
	var cost := str(entry.get("cost", "")).strip_edges()
	if cost != "":
		pieces.append("报价%s" % cost)
	if pieces.is_empty():
		pieces.append("公共牌槽")
	return _short_track_focus_text("%s｜%s" % [prefix, "｜".join(pieces)])


func _track_owner_hint_text(entry: Dictionary) -> String:
	var owner_hint := str(entry.get("owner_hint", "")).strip_edges()
	if owner_hint == "":
		return ""
	match owner_hint:
		"匿名", "unknown", "Unknown", "UNKNOWN", "未公开":
			return "未知"
	return owner_hint


func _short_track_focus_text(text: String) -> String:
	var value := text.replace("\n", " ").strip_edges()
	if value.length() <= 58:
		return value
	return "%s..." % value.left(55)


func _track_focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var accent := Color("#f59e0b")
	style.bg_color = Color("#020617").lerp(accent, 0.12)
	style.border_color = Color("#334155").lerp(accent, 0.56)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.set_content_margin(SIDE_LEFT, 8.0)
	style.set_content_margin(SIDE_RIGHT, 8.0)
	style.set_content_margin(SIDE_TOP, 2.0)
	style.set_content_margin(SIDE_BOTTOM, 2.0)
	return style


func _should_open_detail_drawer(action_id: String) -> bool:
	return action_id.begins_with("codex") or action_id.begins_with("detail") or action_id == "inspect"


func _open_detail_drawer(action_id: String) -> void:
	if overlay_layer == null or not overlay_layer.has_method("show_side_drawer"):
		return
	var inspector: Dictionary = current_ui_data.get("right_inspector", {}) if current_ui_data.get("right_inspector", {}) is Dictionary else {}
	var drawer: Dictionary = OVERLAY_LAYER_SNAPSHOT_SCRIPT.new().apply_side_drawer(action_id, inspector).to_side_drawer_dictionary()
	overlay_layer.call("show_side_drawer", drawer)


func _sync_temporary_decision_overlay(value: Variant) -> void:
	if overlay_layer == null:
		return
	var decision: Dictionary = value if value is Dictionary else {}
	if decision.is_empty():
		_rendered_forced_decision_binding.clear()
		if overlay_layer.has_method("hide_confirm"):
			overlay_layer.call("hide_confirm")
		if str(_last_runtime_player_feedback.get("kind", "")) == "temporary_decision":
			_clear_player_runtime_feedback()
		return
	if str(decision.get("kind", "")) in ["monster_wager", "monster_target_choice", "player_target_choice"]:
		_rendered_forced_decision_binding = {
			"decision_id": str(decision.get("decision_id", decision.get("id", ""))),
			"decision_revision": int(decision.get("decision_revision", 0)),
			"kind": str(decision.get("kind", "")),
		}
	else:
		_rendered_forced_decision_binding.clear()
	if overlay_layer.has_method("show_temporary_decision"):
		overlay_layer.call("show_temporary_decision", decision)
	_show_temporary_decision_player_feedback(decision)


func _sync_transient_gameplay_surfaces(decision_value: Variant, bid_value: Variant, active_forced_value: Variant = {}) -> void:
	if overlay_layer == null:
		return
	var decision: Dictionary = decision_value if decision_value is Dictionary else {}
	var bid_state: Dictionary = bid_value if bid_value is Dictionary else {}
	var active_forced: Dictionary = active_forced_value if active_forced_value is Dictionary else {}
	var active_priority := str(active_forced.get("priority_group", "")).strip_edges()
	var temporary_decision_is_active := _temporary_decision_matches_active(decision, active_forced)
	var public_bid_is_active := active_priority == "public_bid" \
		and str(active_forced.get("kind", "")).strip_edges() in ["public_bid", "card_order_bid"] \
		and bool(active_forced.get("visible_to_viewer", false)) \
		and bool(active_forced.get("blocks_player_actions", false)) \
		and str(active_forced.get("presentation_surface", "")).strip_edges() == "overlay"
	if temporary_decision_is_active:
		if overlay_layer.has_method("hide_public_bid"):
			overlay_layer.call("hide_public_bid", false)
		var rendered_decision := decision.duplicate(true)
		rendered_decision["decision_id"] = str(active_forced.get("id", ""))
		rendered_decision["decision_revision"] = int(active_forced.get("decision_revision", 0))
		_sync_temporary_decision_overlay(rendered_decision)
		return
	_sync_temporary_decision_overlay({})
	if public_bid_is_active and str(bid_state.get("phase_id", "")).strip_edges() == "public_bid":
		if overlay_layer.has_method("show_public_bid"):
			overlay_layer.call("show_public_bid", bid_state)
	else:
		if overlay_layer.has_method("hide_public_bid"):
			overlay_layer.call("hide_public_bid")


func _temporary_decision_matches_active(decision: Dictionary, active_forced: Dictionary) -> bool:
	if decision.is_empty():
		return false
	if active_forced.is_empty():
		return false
	var kind := str(decision.get("kind", "")).strip_edges()
	var active_kind := str(active_forced.get("kind", "")).strip_edges()
	return str(decision.get("id", "")).strip_edges() == str(active_forced.get("id", "")).strip_edges() \
		and not kind.is_empty() \
		and kind == active_kind \
		and str(active_forced.get("priority_group", "")).strip_edges() == _forced_priority_group_for_kind(kind) \
		and bool(active_forced.get("visible_to_viewer", false)) \
		and bool(active_forced.get("blocks_player_actions", false)) \
		and str(active_forced.get("presentation_surface", "")).strip_edges() == "overlay"


func _forced_priority_group_for_kind(kind: String) -> String:
	match kind:
		"monster_wager":
			return "monster_wager"
		"counter_response":
			return "counter_response"
		"discard_purchase", "monster_target_choice", "player_target_choice":
			return "other_choice"
		"public_bid", "card_order_bid":
			return "public_bid"
	return ""


func _forced_surface_blocks_player_actions() -> bool:
	return overlay_layer != null \
		and overlay_layer.has_method("forced_surface_active") \
		and bool(overlay_layer.call("forced_surface_active"))


func _show_player_action_feedback(action_id: String, state: String = "pending", detail: String = "") -> void:
	var normalized_action_id := action_id.strip_edges()
	if normalized_action_id == "":
		return
	var label := _action_feedback_label(normalized_action_id, state)
	var resolved_detail := detail.strip_edges()
	if resolved_detail == "":
		resolved_detail = _mission_action_feedback_detail(normalized_action_id, state)
	if resolved_detail == "":
		resolved_detail = "动作 id: %s" % normalized_action_id
	_last_runtime_player_feedback = {
		"kind": "action",
		"state": state,
		"action_id": normalized_action_id,
		"label": label,
		"detail": resolved_detail,
	}
	_send_player_runtime_feedback(_last_runtime_player_feedback)


func _show_temporary_decision_player_feedback(decision: Dictionary) -> void:
	var title := str(decision.get("title", "临时决策")).strip_edges()
	if title == "":
		title = "临时决策"
	var kind := str(decision.get("kind", "")).strip_edges()
	var action_count := 0
	var actions: Array = decision.get("actions", []) if decision.get("actions", []) is Array else []
	for action_variant in actions:
		if action_variant is Dictionary and not bool((action_variant as Dictionary).get("disabled", false)):
			action_count += 1
	_last_runtime_player_feedback = {
		"kind": "temporary_decision",
		"state": "temporary_decision",
		"action_id": str(decision.get("id", kind)),
		"label": "等待决策｜%s" % _short_feedback_text(title, 18),
		"detail": "Overlay 正在等待 %s；可用选择 %d 个。" % [kind if kind != "" else title, action_count],
	}
	_send_player_runtime_feedback(_last_runtime_player_feedback)


func _clear_player_runtime_feedback() -> void:
	_last_runtime_player_feedback = {}
	if player_board != null and player_board.has_method("set_runtime_feedback"):
		player_board.call("set_runtime_feedback", {})


func _send_player_runtime_feedback(feedback: Dictionary) -> void:
	if player_board != null and player_board.has_method("set_runtime_feedback"):
		player_board.call("set_runtime_feedback", feedback)


func _action_feedback_label(action_id: String, state: String) -> String:
	var label := _action_label_for_id(action_id)
	if label == "":
		label = action_id
	match state:
		"resolved":
			return "已提交｜%s" % _short_feedback_text(label, 22)
		"blocked":
			return "未执行｜%s" % _short_feedback_text(label, 22)
	return "处理中｜%s" % _short_feedback_text(label, 22)


func _action_label_for_id(action_id: String) -> String:
	var candidates: Array = []
	var player_data: Dictionary = current_ui_data.get("player_board", {}) if current_ui_data.get("player_board", {}) is Dictionary else {}
	for key in ["actions", "quick_actions"]:
		if player_data.get(key, []) is Array:
			candidates.append_array(player_data.get(key, []))
	var bid_state: Dictionary = player_data.get("bid_board", {}) if player_data.get("bid_board", {}) is Dictionary else {}
	if bid_state.get("actions", []) is Array:
		candidates.append_array(bid_state.get("actions", []))
	if not _selected_hand_card_data.is_empty() and _selected_hand_card_data.get("actions", []) is Array:
		candidates.append_array(_selected_hand_card_data.get("actions", []))
	var inspector: Dictionary = current_ui_data.get("right_inspector", {}) if current_ui_data.get("right_inspector", {}) is Dictionary else {}
	if inspector.get("actions", []) is Array:
		candidates.append_array(inspector.get("actions", []))
	for entry_variant in candidates:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		if str(entry.get("id", entry.get("action_id", ""))).strip_edges() == action_id:
			return str(entry.get("label", entry.get("text", action_id))).strip_edges()
	return ""


func _mission_action_feedback_detail(action_id: String, state: String) -> String:
	if not action_id.begins_with("mission:"):
		return ""
	match action_id:
		"mission:first_goal_complete":
			return "第一目标已完成：选牌、看详情并提交核心行动。"
		"mission:next_step":
			return "任务指引已推进；继续读取公共线索或结束回合。"
		"mission:show_hint":
			return "任务提示已打开；当前只显示公开信息。"
	if state == "resolved":
		return "任务步骤已提交。"
	return "任务步骤已记录，等待桌面反馈。"


func _short_feedback_text(value: String, max_characters: int) -> String:
	var text := value.replace("\n", " ").strip_edges()
	if text.length() <= max_characters:
		return text
	return "%s..." % text.substr(0, maxi(0, max_characters - 3))


func _card_drop_zone_contains(screen_position: Vector2) -> bool:
	return _control_contains_screen_position(_map_drop_control(), screen_position)


func _control_contains_screen_position(control: Control, screen_position: Vector2) -> bool:
	return control != null and control.is_visible_in_tree() and control.get_global_rect().has_point(screen_position)


func _drag_drop_hint(_screen_position: Vector2, over_map: bool, valid_drop: bool, card_data: Dictionary) -> Dictionary:
	var drop_control := _map_drop_control()
	if drop_control == null:
		return {}
	var label := _card_drop_feedback_label(card_data, over_map, valid_drop)
	return {
		"target_rect": drop_control.get_global_rect(),
		"valid": valid_drop,
		"label": label,
		"tooltip": _card_drop_feedback_tooltip(card_data, over_map, valid_drop),
	}


func _card_can_drop_on_map(card_data: Dictionary) -> bool:
	if card_data.has("drop_enabled"):
		return bool(card_data.get("drop_enabled", false))
	if card_data.has("actionable"):
		return bool(card_data.get("actionable", false))
	var actions: Array = card_data.get("actions", []) if card_data.get("actions", []) is Array else []
	for action_variant in actions:
		if not (action_variant is Dictionary):
			continue
		var action: Dictionary = action_variant
		var action_id := str(action.get("id", ""))
		if action_id.begins_with("play_"):
			return not bool(action.get("disabled", false))
	return true


func _card_drop_feedback_label(card_data: Dictionary, over_map: bool, valid_drop: bool) -> String:
	if not over_map:
		return "拖到星球地图"
	if valid_drop:
		var explicit := str(card_data.get("drop_label", "")).strip_edges()
		return explicit if explicit != "" else "松开出牌"
	var blocked_label := str(card_data.get("drop_label", "")).strip_edges()
	if blocked_label != "":
		return blocked_label
	var state_text := str(card_data.get("play_state", card_data.get("target", ""))).strip_edges()
	if state_text != "":
		return "不能出：%s" % _short_drag_text(state_text, 8)
	return "暂不可出牌"


func _card_drop_feedback_tooltip(card_data: Dictionary, over_map: bool, valid_drop: bool) -> String:
	if not over_map:
		return "把手牌释放到星球地图区域来打出。"
	if valid_drop:
		var detail := str(card_data.get("why", card_data.get("tooltip", ""))).strip_edges()
		return detail if detail != "" else "松开后按当前卡牌目标流程打出。"
	var reason := str(card_data.get("block_reason", card_data.get("why", card_data.get("tooltip", "")))).strip_edges()
	return reason if reason != "" else "这张牌当前不满足出牌条件。"


func _short_drag_text(value: String, max_length: int) -> String:
	var text := value.replace("\n", " ").strip_edges()
	if text.length() <= max_length:
		return text
	return "%s..." % text.substr(0, max(0, max_length - 3))


func _map_host_control() -> Control:
	if planet_board == null:
		return null
	return planet_board.find_child("MapHost", true, false) as Control


func _map_drop_control() -> Control:
	var map_host := _map_host_control()
	if map_host == null:
		return null
	for child in map_host.get_children():
		if child is Control and (child as Control).is_visible_in_tree():
			return child as Control
	return map_host
