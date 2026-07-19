extends SceneTree

const SESSION_START_DRIVER := preload("res://tests/support/production_session_start_driver.gd")
const MENU_OVERLAY_PATH := "RuntimeGameScreen/OverlayLayer/RuntimeSurfaceLayer/MenuModalOverlay"
const QA_SAVE_PATH := "user://test_runs/compendium_v06_public_semantics.save"
const RETIRED_TEXT := [
	"城市产权份额",
	"项目份额",
	"项目GDP",
	"签/拒",
	"路线HP",
	"商路伤害",
	"商路修复",
	"单一城市业主",
	"行动概率",
]
const PRIVATE_KEYS := [
	"players",
	"player_state",
	"selected_player",
	"selected_district",
	"cash",
	"cash_cents",
	"exact_cash",
	"hand",
	"private_hand",
	"discard",
	"private_discard",
	"inventory",
	"private_inventory",
	"warehouse_units",
	"futures_positions",
	"hidden_owner",
	"hidden_owner_id",
	"true_owner",
	"city_guesses",
	"private_plan",
	"ai_plan",
	"ai_private_plan",
	"ai_score",
	"target_weight",
	"target_probability",
	"rng_state",
	"random_ticket",
]
const SESSION_VISIBILITY_SOURCE_PATHS := [
	"res://scripts/runtime/card_codex_public_source_service.gd",
	"res://scripts/runtime/card_codex_public_snapshot_service.gd",
	"res://scripts/runtime/monster_codex_public_source_service.gd",
	"res://scripts/runtime/monster_codex_public_snapshot_service.gd",
	"res://scripts/runtime/product_codex_public_source_service.gd",
	"res://scripts/runtime/product_codex_public_snapshot_service.gd",
	"res://scripts/runtime/region_codex_public_source_service.gd",
	"res://scripts/runtime/codex_public_snapshot_service.gd",
	"res://scripts/runtime/role_codex_public_source_service.gd",
	"res://scripts/viewmodels/compendium_hub_snapshot.gd",
	"res://scripts/ui/codex_compendium_surface.gd",
]

var _checks := 0
var _failures: Array[String] = []
var _main: Node
var _coordinator: Node
var _menu_overlay: Control
var _surface: Control


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup_test_save()
	var start_result := await SESSION_START_DRIVER.start_default_session(self, QA_SAVE_PATH, "compendium-v06-public-semantics")
	_main = start_result.get("main_root") as Node
	_assert_formal_session_start(start_result, 4)
	if _main == null or not bool(start_result.get("started", false)):
		await _cleanup()
		_finish()
		return
	_coordinator = start_result.get("coordinator") as Node
	_menu_overlay = _main.get_node_or_null(MENU_OVERLAY_PATH) as Control
	_surface = _menu_overlay.call("get_codex_surface") as Control if _menu_overlay != null and _menu_overlay.has_method("get_codex_surface") else null
	_expect(_coordinator != null, "real_game_runtime_coordinator_available")
	_expect(_menu_overlay != null and _surface != null, "real_menu_overlay_owns_codex_surface")
	if _coordinator != null and _surface != null:
		await _test_real_public_pages()
		await _test_surface_rejects_runtime_objects()
		_test_finished_session_does_not_expand_visibility()
		_test_retired_player_text_absent_from_active_sources()
	await _cleanup()
	_finish()


func _assert_formal_session_start(start_result: Dictionary, expected_players: int) -> void:
	_expect(bool(start_result.get("qa_save_override_ready", false)), "driver_installs_qa_save_override_before_tree_entry")
	_expect(bool(start_result.get("started", false)), "formal_session_start_succeeds|reason=%s" % start_result.get("reason_code", ""))
	var receipt := start_result.get("receipt") as SessionStartReceipt
	_expect(receipt != null and receipt.applied, "formal_session_receipt_is_applied")
	_expect(int(start_result.get("main_start_call_count", -1)) == 0, "formal_fixture_calls_no_Main_start_method")
	_expect(int(start_result.get("setup_fallback_count", -1)) == 0, "formal_fixture_uses_no_setup_fallback")
	var world := start_result.get("world_session") as WorldSessionState
	_expect(world != null and world.players.size() == expected_players, "formal_world_has_expected_player_count")
	var operation: Dictionary = start_result.get("transaction_snapshot", {})
	_expect(str(operation.get("operation_state", "")) == "succeeded" and int(operation.get("terminal_request_count", 0)) == 1 and not bool(operation.get("references_main", true)), "formal_session_transaction_commits_exactly_once_without_Main")
	var game_session := start_result.get("game_session") as GameSessionRuntimeController
	_expect(game_session != null and str(game_session.session_summary().get("session_state", "")) == "running", "formal_game_session_is_running")


func _test_real_public_pages() -> void:
	var pages := _compose_real_pages()
	_expect(pages.size() == 9, "all_compendium_domains_compose_browser_and_detail_pages")
	if _menu_overlay.has_method("present_menu_shell"):
		_menu_overlay.call("present_menu_shell", {
			"title": "资料大厅",
			"body": "",
			"root_table_menu": false,
			"compact_page": false,
			"clear_preview": true,
			"viewport_size": Vector2(1600, 960),
		})
	for page_variant: Variant in pages:
		var page := page_variant as Dictionary
		var page_id := str(page.get("test_id", "unknown"))
		page.erase("test_id")
		_expect(_is_pure_data(page), "%s_payload_is_pure_data" % page_id)
		var private_paths := _private_key_paths(page)
		_expect(private_paths.is_empty(), "%s_payload_has_no_private_fields|paths=%s" % [page_id, private_paths])
		var retired_paths := _retired_text_paths(page)
		_expect(retired_paths.is_empty(), "%s_payload_has_current_v06_terms|paths=%s" % [page_id, retired_paths])
		var rendered := bool(_menu_overlay.call("present_codex_page", page))
		await process_frame
		await process_frame
		var debug := _surface.call("debug_snapshot") as Dictionary
		_expect(rendered, "%s_renders_on_real_surface" % page_id)
		_expect(str(debug.get("mode", "")) == str(page.get("mode", "")) and str(debug.get("view", "")) == str(page.get("view", "")), "%s_surface_applies_requested_mode_once" % page_id)
		_expect(bool(debug.get("page_is_pure_data", false)), "%s_surface_retains_pure_data_only" % page_id)
		var visible_names: Array = debug.get("visible_surfaces", []) if debug.get("visible_surfaces", []) is Array else []
		_expect(not visible_names.is_empty(), "%s_has_visible_contract_surface" % page_id)
		var ui_retired := _visible_ui_retired_text_paths(_surface)
		_expect(ui_retired.is_empty(), "%s_visible_labels_buttons_and_tooltips_use_v06_terms|paths=%s" % [page_id, ui_retired])


func _compose_real_pages() -> Array:
	var pages: Array = []
	pages.append({"test_id": "hub", "mode": "compendium", "view": "hub", "hub": CompendiumHubSnapshot.compose(960.0)})
	var role := _coordinator.call("role_codex_public_snapshot", 0, {}) as Dictionary
	pages.append({"test_id": "role_detail", "mode": "role", "view": "detail", "detail": _dictionary(role.get("board", {}))})

	var card_ids: Array[String] = _coordinator.call("card_codex_public_card_ids", "all") as Array[String]
	var card_page_ids: Array[String] = []
	for index in range(mini(8, card_ids.size())):
		card_page_ids.append(card_ids[index])
	var card_browser := _coordinator.call("card_codex_public_browser_snapshot", {
		"names": card_page_ids,
		"columns": 4,
		"rows": 2,
		"page_index": 0,
		"filter_id": "all",
		"selected_card": card_page_ids[0] if not card_page_ids.is_empty() else "",
		"run_pool_count": 0,
		"district_supply_count": 0,
	}) as Dictionary
	var card_detail := _coordinator.call("card_codex_public_detail_snapshot", card_ids[0], 0, card_ids.size()) as Dictionary if not card_ids.is_empty() else {}
	pages.append({"test_id": "card_browser", "mode": "card", "view": "browser", "browser": card_browser})
	pages.append({"test_id": "card_detail", "mode": "card", "view": "detail", "detail": _dictionary(card_detail.get("detail", {}))})

	var monster_browser := _coordinator.call("monster_codex_public_browser_snapshot", {
		"start_index": 0,
		"end_index": 6,
		"columns": 3,
		"selected_index": 0,
		"can_page": true,
		"page_label": "公开怪兽 1-6",
	}) as Dictionary
	var monster_detail := _coordinator.call("monster_codex_public_detail_snapshot", 0, true) as Dictionary
	pages.append({"test_id": "monster_browser", "mode": "monster", "view": "browser", "browser": monster_browser})
	pages.append({
		"test_id": "monster_detail",
		"mode": "monster",
		"view": "detail",
		"detail": _dictionary(monster_detail.get("detail", {})),
		"monster_card_link": _dictionary(monster_detail.get("monster_card_link", {})),
	})

	var product_count := ProductMarketRuntimeController.PRODUCT_CATALOG.size()
	var product_browser := _coordinator.call("product_codex_public_browser_snapshot", {
		"start_index": 0,
		"end_index": mini(6, product_count),
		"selected_index": 0,
		"columns": 3,
		"can_page": product_count > 6,
		"page_label": "公开商品 1-%d" % mini(6, product_count),
	}) as Dictionary
	var product_name := str(ProductMarketRuntimeController.PRODUCT_CATALOG[0]) if product_count > 0 else ""
	var product_detail := _coordinator.call("product_codex_public_detail_snapshot", product_name, 0, true) as Dictionary if product_name != "" else {}
	pages.append({"test_id": "product_browser", "mode": "product", "view": "browser", "browser": product_browser})
	pages.append({"test_id": "product_detail", "mode": "product", "view": "detail", "detail": _dictionary(product_detail.get("detail", {}))})

	var region := _coordinator.call("region_codex_public_snapshot", 0) as Dictionary
	pages.append({"test_id": "region_detail", "mode": "region", "view": "detail", "detail": _dictionary(region.get("detail", {}))})
	return pages


func _test_surface_rejects_runtime_objects() -> void:
	var before := _surface.call("debug_snapshot") as Dictionary
	var canary := Node.new()
	var rejected_node := not bool(_surface.call("set_page", {
		"mode": "compendium",
		"view": "hub",
		"hub": {"nested": [{"runtime_node": canary}]},
	}))
	await process_frame
	var after_node := _surface.call("debug_snapshot") as Dictionary
	_expect(rejected_node, "surface_rejects_nested_node")
	_expect(int(after_node.get("rejected_page_count", 0)) == int(before.get("rejected_page_count", 0)) + 1, "nested_node_rejection_is_counted_once")
	_expect(str(after_node.get("mode", "")) == "" and str(after_node.get("view", "")) == "" and _array(after_node.get("visible_surfaces", [])).has("CodexEmptyState"), "nested_node_rejection_clears_previous_page_and_shows_safe_empty_state")
	canary.free()

	var rejected_callable := not bool(_surface.call("set_page", {
		"mode": "compendium",
		"view": "hub",
		"hub": {"nested": [{"runtime_callable": Callable(self, "_callable_canary")}]},
	}))
	await process_frame
	var after_callable := _surface.call("debug_snapshot") as Dictionary
	_expect(rejected_callable, "surface_rejects_nested_callable")
	_expect(int(after_callable.get("rejected_page_count", 0)) == int(after_node.get("rejected_page_count", 0)) + 1, "nested_callable_rejection_is_counted_once")
	_expect(str(after_callable.get("mode", "")) == "" and str(after_callable.get("view", "")) == "" and bool(after_callable.get("page_is_pure_data", false)), "nested_callable_rejection_retains_no_runtime_payload")

	var recovery := {"mode": "compendium", "view": "hub", "hub": CompendiumHubSnapshot.compose(960.0)}
	_expect(bool(_surface.call("set_page", recovery)), "surface_recovers_with_public_page_after_rejection")
	await process_frame


func _test_finished_session_does_not_expand_visibility() -> void:
	var offenders: Array[String] = []
	for path in SESSION_VISIBILITY_SOURCE_PATHS:
		var source := FileAccess.get_file_as_string(path)
		for token in ["session_finished", "game_over", "winner"]:
			if source.contains(token):
				offenders.append("%s:%s" % [path, token])
	_expect(offenders.is_empty(), "session_completion_does_not_expand_compendium_visibility|offenders=%s" % offenders)


func _test_retired_player_text_absent_from_active_sources() -> void:
	var paths := [
		"res://scenes/ui/BestiaryDetail.tscn",
		"res://scripts/ui/bestiary_detail.gd",
		"res://scripts/ui/codex/bestiary_monster_action_card.gd",
		"res://scripts/viewmodels/compendium_hub_snapshot.gd",
		"res://scripts/runtime/intel_dossier_public_snapshot_service.gd",
		"res://scripts/tools/compendium_codex_mcp_preview_fixtures.gd",
	]
	var offenders: Array[String] = []
	for path in paths:
		var source := FileAccess.get_file_as_string(path)
		for token in RETIRED_TEXT:
			if source.contains(token):
				offenders.append("%s:%s" % [path, token])
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	if main_source.contains("行动概率"):
		offenders.append("res://scripts/main.gd:行动概率")
	_expect(offenders.is_empty(), "active_compendium_sources_exclude_retired_player_text|offenders=%s" % offenders)


func _private_key_paths(value: Variant, path: String = "$") -> Array[String]:
	var result: Array[String] = []
	if value is Dictionary:
		for key_variant: Variant in (value as Dictionary).keys():
			var key := str(key_variant).to_lower()
			var child_path := "%s.%s" % [path, str(key_variant)]
			var public_facility_owner := (key == "owner_kind" or key == "owner_player_index" or key == "player_index") and child_path.to_lower().contains("facilit")
			if (PRIVATE_KEYS.has(key) or key.begins_with("private_") or key.begins_with("hidden_") or key.begins_with("ai_")) and not public_facility_owner:
				result.append(child_path)
			result.append_array(_private_key_paths((value as Dictionary)[key_variant], child_path))
	elif value is Array:
		for index in range((value as Array).size()):
			result.append_array(_private_key_paths((value as Array)[index], "%s[%d]" % [path, index]))
	elif value is String or value is StringName:
		if str(value).contains("PRIVATE_SENTINEL"):
			result.append(path)
	return result


func _retired_text_paths(value: Variant, path: String = "$") -> Array[String]:
	var result: Array[String] = []
	if value is String or value is StringName:
		for token in RETIRED_TEXT:
			if str(value).contains(token):
				result.append("%s:%s" % [path, token])
	elif value is Dictionary:
		for key_variant: Variant in (value as Dictionary).keys():
			result.append_array(_retired_text_paths((value as Dictionary)[key_variant], "%s.%s" % [path, str(key_variant)]))
	elif value is Array:
		for index in range((value as Array).size()):
			result.append_array(_retired_text_paths((value as Array)[index], "%s[%d]" % [path, index]))
	return result


func _visible_ui_retired_text_paths(node: Node) -> Array[String]:
	var result: Array[String] = []
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return result
	var texts: Array[String] = []
	if node is Label:
		texts.append((node as Label).text)
	elif node is RichTextLabel:
		texts.append((node as RichTextLabel).text)
	elif node is Button:
		texts.append((node as Button).text)
	if node is Control and (node as Control).tooltip_text != "":
		texts.append((node as Control).tooltip_text)
	for text_value in texts:
		for token in RETIRED_TEXT:
			if text_value.contains(token):
				result.append("%s:%s" % [str(node.get_path()), token])
	for child in node.get_children():
		result.append_array(_visible_ui_retired_text_paths(child))
	return result


func _is_pure_data(value: Variant) -> bool:
	if value is Callable or typeof(value) == TYPE_OBJECT:
		return false
	if value is Dictionary:
		for key_variant: Variant in value:
			if not _is_pure_data(key_variant) or not _is_pure_data(value[key_variant]):
				return false
	elif value is Array:
		for item_variant: Variant in value:
			if not _is_pure_data(item_variant):
				return false
	return true


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if value is Array else []


func _callable_canary() -> void:
	pass


func _cleanup() -> void:
	if _main != null:
		_main.queue_free()
	_main = null
	_coordinator = null
	_menu_overlay = null
	_surface = null
	await process_frame
	await process_frame
	_cleanup_test_save()


func _cleanup_test_save() -> void:
	for path in [QA_SAVE_PATH, QA_SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(label)
	push_error("COMPENDIUM_V06_PUBLIC_SEMANTICS: %s" % label)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("COMPENDIUM_V06_PUBLIC_SEMANTICS|status=%s|checks=%d|failures=%d|details=%s" % [status, _checks, _failures.size(), JSON.stringify(_failures)])
	quit(0 if _failures.is_empty() else 1)
