extends Node

@export var auto_run := true

var _checks := 0
var _failures: Array[String] = []
var _run_started := false
var _last_result: Dictionary = {}


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("_run_auto_bench")


func _run_auto_bench() -> void:
	var result := await run_bench()
	get_tree().quit(0 if bool(result.get("passed", false)) else 1)


func run_bench() -> Dictionary:
	if _run_started:
		return _last_result.duplicate(true)
	_run_started = true
	var selection := get_node_or_null("TableSelectionState") as TableSelectionState
	var navigation := get_node_or_null("CompendiumNavigationPort") as CompendiumNavigationPort
	var application := get_node_or_null("ApplicationFlowPort") as ApplicationFlowPort
	var router := get_node_or_null("TableNavigationActionRouter") as TableNavigationActionRouter
	_check(selection != null, "typed table-selection owner exists")
	_check(navigation != null, "typed Compendium navigation port exists")
	_check(application != null, "typed application-flow port exists")
	_check(router != null, "scene-owned navigation router exists")
	if selection == null or navigation == null or application == null or router == null:
		return _finish()

	var navigation_requests: Array = []
	var compendium_requests := [0]
	var receipt_events: Array = []
	navigation.navigation_requested.connect(func(request: Variant) -> void: navigation_requests.append(request))
	application.compendium_requested.connect(func() -> void: compendium_requests[0] = int(compendium_requests[0]) + 1)
	router.receipt_ready.connect(func(receipt: Dictionary) -> void: receipt_events.append(receipt.duplicate(true)))

	selection.selected_district = 4
	var region_receipt := router.submit_intent(_intent("region-1", TableNavigationActionIntent.KIND_REGION_DETAIL))
	_check(bool(region_receipt.get("accepted", false)), "region detail intent is accepted")
	_check(navigation_requests.size() == 1, "region detail emits one navigation request")
	if not navigation_requests.is_empty():
		var request: Variant = navigation_requests[0]
		_check(str(request.domain) == "region" and str(request.view) == "detail", "region request uses the detail projection")
		_check(int(request.optional_index) == 4 and str(request.stable_item_id) == "region:4", "region request uses authoritative table selection")

	var browser_receipt := router.submit_intent(_intent("cards-1", TableNavigationActionIntent.KIND_CARD_BROWSER))
	_check(bool(browser_receipt.get("accepted", false)), "card browser intent is accepted")
	_check(navigation_requests.size() == 2 and str(navigation_requests[1].view) == "browser", "card browser emits one typed request")

	var detail := _intent("card-detail-1", TableNavigationActionIntent.KIND_CARD_DETAIL)
	detail.target_card_name = "轨道收购"
	var detail_receipt := router.submit_intent(detail)
	_check(bool(detail_receipt.get("accepted", false)), "card detail intent is accepted")
	_check(navigation_requests.size() == 3 and str(navigation_requests[2].stable_item_id) == "轨道收购", "card detail preserves the public card name")

	var hub_receipt := router.submit_intent(_intent("hub-1", TableNavigationActionIntent.KIND_COMPENDIUM_HUB))
	_check(bool(hub_receipt.get("accepted", false)), "Compendium hub intent is accepted")
	_check(int(compendium_requests[0]) == 1, "Compendium hub emits once through ApplicationFlowPort")

	var duplicate := router.submit_intent(detail)
	_check(not bool(duplicate.get("accepted", true)) and str(duplicate.get("reason_code", "")) == "request_replay", "duplicate request is rejected")
	_check(navigation_requests.size() == 3, "duplicate request never reaches navigation target")

	var invalid := _intent("invalid-detail", TableNavigationActionIntent.KIND_CARD_DETAIL)
	var invalid_receipt := router.submit_intent(invalid)
	_check(not bool(invalid_receipt.get("accepted", true)) and str(invalid_receipt.get("reason_code", "")) == "target_card_missing", "missing card target fails closed")
	selection.selected_district = -1
	var missing_region := router.submit_intent(_intent("missing-region", TableNavigationActionIntent.KIND_REGION_DETAIL))
	_check(not bool(missing_region.get("accepted", true)) and str(missing_region.get("reason_code", "")) == "selected_district_missing", "missing region selection fails closed")

	var debug := router.debug_snapshot()
	_check(int(debug.get("accepted_count", 0)) == 4, "accepted diagnostic count is exact")
	_check(int(debug.get("duplicate_count", 0)) == 1, "duplicate diagnostic count is exact")
	_check(int(debug.get("journal_size", 0)) == 4, "journal stores accepted requests only")
	_check(not bool(debug.get("owns_gameplay_state", true)) and not bool(debug.get("owns_navigation_state", true)), "router owns no gameplay or navigation state")
	_check(not bool(debug.get("references_main", true)) and not bool(debug.get("uses_callable_dispatch", true)), "router has no Main or Callable dispatch path")
	_check(receipt_events.size() == 7, "every submission produces exactly one receipt")

	var main_scene := FileAccess.get_file_as_string("res://scenes/main.tscn")
	var screen_source := FileAccess.get_file_as_string("res://scripts/ui/game_screen.gd")
	var router_source := FileAccess.get_file_as_string("res://scripts/runtime/table_navigation_action_router.gd")
	_check(main_scene.count("TableNavigationActionRouter.tscn") == 1, "production main scene composes one router")
	_check(main_scene.count("navigation_intent_requested") == 1, "production scene has one typed navigation connection")
	_check(screen_source.contains("navigation_intent_requested.emit(intent)"), "GameScreen emits the typed navigation intent")
	_check(screen_source.contains("action_requested.emit(action_id)"), "unrelated GameScreen actions retain the scoped legacy route")
	_check(not router_source.contains("scripts/" + "main.gd") and not router_source.contains("/root/" + "Main") and not router_source.contains("current_scene"), "router source has no root discovery or service locator")
	return _finish()


func _intent(request_id: String, kind: StringName) -> TableNavigationActionIntent:
	var intent := TableNavigationActionIntent.new()
	intent.request_id = request_id
	intent.action_kind = kind
	intent.source_surface = &"bench"
	return intent


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> Dictionary:
	_last_result = {
		"passed": _failures.is_empty(),
		"checks": _checks,
		"failures": _failures.duplicate(),
	}
	print("TableNavigationActionRouterBench: %s %d/%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks - _failures.size(), _checks])
	if not _failures.is_empty():
		push_error("TableNavigationActionRouterBench failures:\n- " + "\n- ".join(_failures))
	return _last_result.duplicate(true)
