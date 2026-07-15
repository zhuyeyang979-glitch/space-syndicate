extends SceneTree

const DRAWER_SCENE := preload("res://scenes/ui/DistrictSupplyDrawer.tscn")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var drawer := DRAWER_SCENE.instantiate() as Control
	_expect(drawer != null, "DistrictSupplyDrawer instantiates")
	if drawer == null:
		_finish()
		return
	root.add_child(drawer)
	await process_frame
	drawer.call("set_supply", _snapshot(5_000_000, "报价剩余 5.0 秒"))
	await process_frame
	var market_grid := drawer.find_child("DistrictSupplyMarketGrid", true, false) as Container
	var preview_box := drawer.find_child("DistrictSupplyPreviewBox", true, false) as Container
	var first_market := market_grid.get_child(0) as Control if market_grid != null and market_grid.get_child_count() == 1 else null
	var first_preview := preview_box.get_child(0) as Control if preview_box != null and preview_box.get_child_count() == 1 else null
	_expect(first_market != null and first_preview != null, "drawer renders one market card and one preview card")
	var market_id := first_market.get_instance_id() if first_market != null else 0
	var preview_id := first_preview.get_instance_id() if first_preview != null else 0

	drawer.call("set_supply", _snapshot(4_000_000, "报价剩余 4.0 秒"))
	await process_frame
	var refreshed_market := market_grid.get_child(0) as Control if market_grid != null and market_grid.get_child_count() == 1 else null
	var refreshed_preview := preview_box.get_child(0) as Control if preview_box != null and preview_box.get_child_count() == 1 else null
	_expect(refreshed_market != null and refreshed_market.get_instance_id() == market_id, "transient quote refresh reuses the market card node")
	_expect(refreshed_preview != null and refreshed_preview.get_instance_id() == preview_id, "transient quote refresh reuses the preview card node")
	var preview_status := refreshed_preview.find_child("DistrictSupplyPreviewStatusLabel", true, false) as Label if refreshed_preview != null else null
	_expect(preview_status != null and preview_status.text.contains("4.0"), "reused preview still receives the latest quote text")

	drawer.queue_free()
	await process_frame
	_finish()


func _snapshot(remaining_world_us: int, status_text: String) -> Dictionary:
	return {
		"title": "区域牌架 · 实时刷新门",
		"rule_strip": "单击预览｜双击购买",
		"privacy_hint": "只显示当前玩家可见状态。",
		"purchase_window": {"remaining_world_us": remaining_world_us},
		"header_chips": [{"text": "1 张", "accent": "#38bdf8ff"}],
		"market_status": [{"text": status_text, "accent": "#34d399ff"}],
		"cards": [{
			"card_name": "设施牌测试",
			"title": "设施牌测试",
			"rank": "I",
			"route": "生产",
			"facts": status_text,
			"state_text": status_text,
			"accent": "#34d399ff",
			"theme_color": "#38bdf8ff",
			"actionable": true,
		}],
		"preview": {
			"card_name": "设施牌测试",
			"title": "设施牌测试 | 城市设施",
			"body": "建立持续生产与 GDP 来源。",
			"facts": status_text,
			"status_text": status_text,
			"buy_text": "购买 ¥200",
			"buy_enabled": true,
			"accent": "#34d399ff",
			"theme_color": "#38bdf8ff",
		},
		"empty_state": {"market_text": "暂无供牌", "preview_text": "选择供牌"},
	}


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("DISTRICT_SUPPLY_DRAWER_LIVE_REFRESH_TEST|status=%s|checks=%d|failures=%d" % [status, _checks, _failures.size()])
	for failure in _failures:
		push_error("DISTRICT_SUPPLY_DRAWER_LIVE_REFRESH_TEST: %s" % failure)
	quit(0 if _failures.is_empty() else 1)
