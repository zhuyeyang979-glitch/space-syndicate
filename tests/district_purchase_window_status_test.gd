extends SceneTree

const STATUS_SCENE := preload("res://scenes/ui/DistrictPurchaseWindowStatus.tscn")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var status := STATUS_SCENE.instantiate() as Control
	root.add_child(status)
	await process_frame

	status.call("set_snapshot", {"state": "active", "active": true})
	_expect(_label(status, "DistrictPurchaseWindowModeLabel") == "等待选择报价" and _label(status, "DistrictPurchaseWindowTimerLabel") == "未启动" and _label(status, "DistrictPurchaseWindowDetailLabel").contains("先选牌生成报价"), "a browsing session without a quote prompts explicit selection")

	status.call("set_snapshot", _window(_quote("sunlit", true, true, 4_500_000, 152, 3)))
	_expect(_label(status, "DistrictPurchaseWindowModeLabel") == "日照报价已锁定" and _label(status, "DistrictPurchaseWindowTimerLabel") == "4.5 秒", "sunlit quote renders the authoritative five-second countdown")
	_expect(_label(status, "DistrictPurchaseWindowDetailLabel").contains("最终价 ¥152") and _label(status, "DistrictPurchaseWindowDetailLabel").contains("怪兽压力 ×1.5") and is_equal_approx(float((status.get_node("%DistrictPurchaseWindowTimerBar") as ProgressBar).value), 90.0), "sunlit quote renders final price, q2 multiplier and remaining fraction")

	status.call("set_snapshot", _window(_quote("dark", true, false, 3_000_000, 202, 4)))
	_expect(_label(status, "DistrictPurchaseWindowModeLabel") == "暗面资格已锁定" and _label(status, "DistrictPurchaseWindowDetailLabel").contains("暗面仅可查看") and _label(status, "DistrictPurchaseWindowDetailLabel").contains("参考价 ¥202"), "dark-side quote remains viewable and visibly non-purchasable")

	status.call("set_snapshot", _window(_quote("sunlit", false, true, 0, 152, 3)))
	_expect(_label(status, "DistrictPurchaseWindowModeLabel") == "报价已过期" and _label(status, "DistrictPurchaseWindowTimerLabel") == "已过期" and _label(status, "DistrictPurchaseWindowDetailLabel").contains("重新选择挂牌"), "half-open quote expiry asks for an explicit new quote")

	var changed := _window(_quote("sunlit", true, true, 4_000_000, 152, 3))
	changed["requires_reselection"] = true
	status.call("set_snapshot", changed)
	_expect(_label(status, "DistrictPurchaseWindowModeLabel") == "供应已变化" and _label(status, "DistrictPurchaseWindowTimerLabel") == "需重新选择" and _label(status, "DistrictPurchaseWindowDetailLabel").contains("供应已变化") and is_zero_approx(float((status.get_node("%DistrictPurchaseWindowTimerBar") as ProgressBar).value)), "supply revision change takes precedence over a stale attached quote")

	changed["cash"] = 999999
	changed["hand"] = ["PRIVATE_CARD"]
	changed["owner"] = "PRIVATE_OWNER"
	(changed["quote"] as Dictionary)["player_index"] = 7
	status.call("set_snapshot", changed)
	var public_json := JSON.stringify(status.call("debug_snapshot"))
	_expect(not public_json.contains("cash") and not public_json.contains("hand") and not public_json.contains("owner") and not public_json.contains("player_index"), "component snapshot contains no cash, hand, owner or player binding")

	var drawer_source := FileAccess.get_file_as_string("res://scripts/ui/district_supply_drawer.gd") + FileAccess.get_file_as_string("res://scenes/ui/DistrictSupplyDrawer.tscn")
	var status_source := FileAccess.get_file_as_string("res://scripts/ui/district_purchase_window_status.gd") + FileAccess.get_file_as_string("res://scenes/ui/DistrictPurchaseWindowStatus.tscn")
	_expect(drawer_source.contains("选择生成5秒报价") and not drawer_source.contains("开窗瞬间锁定"), "drawer defaults describe explicit quote creation instead of window-open locking")
	_expect(not status_source.contains("access_kind") and not status_source.contains("channel_discount_applied") and not status_source.contains("locked_price_multiplier") and not status_source.contains("remaining_seconds") and not status_source.contains("duration_seconds") and not status_source.contains("怪兽落地区") and not status_source.contains("远程补给"), "status component has zero legacy access, discount or twelve-second fields")

	status.queue_free()
	await process_frame
	_finish()


func _window(quote: Dictionary) -> Dictionary:
	return {"state": "active", "active": true, "requires_reselection": false, "quote": quote}


func _quote(availability_kind: String, quote_active: bool, locked_eligible: bool, remaining_world_us: int, final_price: int, multiplier_q2: int) -> Dictionary:
	return {
		"quote_id": "quote-component",
		"quote_active": quote_active,
		"locked_eligible": locked_eligible,
		"eligible": quote_active and locked_eligible,
		"confirmable": quote_active and locked_eligible,
		"viewable": true,
		"availability_kind": availability_kind,
		"remaining_world_us": remaining_world_us,
		"final_price": final_price,
		"multiplier_q2": multiplier_q2,
		"same_region_alive_count": 0,
		"directly_adjacent_alive_count": 1,
	}


func _label(status: Control, unique_name: String) -> String:
	var label := status.get_node_or_null("%%%s" % unique_name) as Label
	return label.text if label != null else ""


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error("DISTRICT PURCHASE WINDOW STATUS: %s" % message)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("DISTRICT_PURCHASE_WINDOW_STATUS_TEST|status=%s|checks=%d|failures=%d|details=%s" % [status, _checks, _failures.size(), JSON.stringify(_failures)])
	quit(0 if _failures.is_empty() else 1)
