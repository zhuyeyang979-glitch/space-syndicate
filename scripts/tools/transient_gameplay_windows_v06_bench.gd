extends Control
class_name TransientGameplayWindowsV06Bench

const ACCEPTANCE_WINDOW_SIZE := Vector2i(1280, 720)

@onready var game_screen: Control = %TransientGameScreen


func _ready() -> void:
	get_window().size = ACCEPTANCE_WINDOW_SIZE
	game_screen.call("apply_state", {
		"top_bar": {"phase": "牌序竞价"},
		"active_forced_decision": {
			"id": "public_bid",
			"kind": "public_bid",
			"priority_group": "public_bid",
			"visible_to_viewer": true,
			"presentation_surface": "overlay",
			"blocks_global_time": false,
			"blocks_player_actions": true,
			"blocks_card_resolution": false,
		},
		"player_board": {
			"title": "玩家板",
			"identity": "本席",
			"cash_text": "¥1000",
			"gdp_text": "18/min",
			"goal_text": "Top-N 18/60",
			"selected_district_summary": "雾港区",
			"bid_board": {
				"title": "牌序竞价",
				"phase_id": "public_bid",
				"phase": "公开竞价 5s",
				"status": "完整竞价只在真实 public_bid 阶段出现。",
				"active": true,
				"chips": [{"label": "本阶段", "state": "待确认", "active": true}],
				"track_links": [
					{"id": "track_select_11", "label": "领跑", "state": "展示组1", "active": true},
					{"id": "track_select_12", "label": "我的牌", "state": "展示组2", "active": true},
				],
				"actions": [{"id": "card_group_ready", "label": "完成展示"}],
			},
			"actions": [{"id": "inspect", "label": "查看详情"}],
			"quick_actions": [],
			"hand_cards": [],
		},
		"temporary_decision": {},
	})
	call_deferred("_report")


func _report() -> void:
	var bid_panel := game_screen.find_child("PublicBidDecisionPanel", true, false) as Control
	var action_dock := game_screen.find_child("PlayerMainActionDock", true, false) as Control
	var player_board := game_screen.find_child("PlayerBoard", true, false)
	var planet_board := game_screen.find_child("PlanetBoard", true, false) as Control
	var bid_rect := bid_panel.get_global_rect() if bid_panel != null else Rect2()
	var viewport_rect := get_viewport().get_visible_rect()
	var exact_target_window := get_window().size == ACCEPTANCE_WINDOW_SIZE
	var editor_embedded_host := not exact_target_window and viewport_rect.size.is_equal_approx(Vector2(1600, 960))
	var primary_clear := bid_panel != null and action_dock != null and bid_rect.intersection(action_dock.get_global_rect()).get_area() <= 0.01
	var planet_recognizable := bid_panel != null and planet_board != null \
		and planet_board.get_global_rect().get_area() - bid_rect.intersection(planet_board.get_global_rect()).get_area() > 10_000.0
	var no_player_placeholder := player_board != null and player_board.find_child("PlayerBidBoard", true, false) == null
	var passed := (exact_target_window or editor_embedded_host) \
		and bid_panel != null and bid_panel.visible and viewport_rect.encloses(bid_rect) \
		and primary_clear and planet_recognizable and no_player_placeholder
	print("TRANSIENT_GAMEPLAY_WINDOWS_V06_BENCH|passed=%s|window=%s|viewport=%s|window_mode=%s|primary_clear=%s|planet_recognizable=%s|player_placeholder=%s" % [
		str(passed),
		str(get_window().size),
		str(viewport_rect.size),
		"exact_1280x720" if exact_target_window else "editor_embedded_1600x960",
		str(primary_clear),
		str(planet_recognizable),
		str(no_player_placeholder),
	])
	if not passed:
		push_error("TransientGameplayWindowsV06Bench failed.")
	if DisplayServer.get_name().to_lower() == "headless":
		get_tree().quit(0 if passed else 1)
