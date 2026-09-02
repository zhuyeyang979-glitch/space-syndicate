extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(MAIN_SCENE) as PackedScene
	_expect(packed != null, "commercial main scene loads")
	if packed == null:
		_finish()
		return
	var application := packed.instantiate()
	root.add_child(application)
	for _frame in range(8):
		await process_frame
	var controller := application.get_node_or_null(
		"CommercialMenuLifecycleApplicationFlowController"
	) as Node
	var overlay := application.get_node_or_null(
		"V075GameScreen/OverlayLayer/CommercialShellSurfaceLayer/MenuModalOverlay"
	) as Control
	var screen := application.get_node_or_null("V075GameScreen") as Control
	var flow := application.get_node_or_null("V075RuntimeComposition") as Node
	_expect(controller != null, "single commercial menu lifecycle owner is reachable")
	_expect(overlay != null and overlay.visible, "root menu is visible from production main")
	_expect(screen != null and flow != null, "production screen and flow remain bound")
	if controller == null or overlay == null or screen == null or flow == null:
		application.queue_free()
		await process_frame
		_finish()
		return
	var root_lobby := overlay.find_child("MainMenuPlanetLobbyPanel", true, false) as Control
	_expect(root_lobby != null, "historical MenuRootLobby is attached to the one shell")
	var root_snapshot := overlay.call("debug_snapshot") as Dictionary
	_expect(bool(root_snapshot.get("root_table_menu", false)), "root shell is marked as main menu")
	var settings_button := root_lobby.call("get_action_button", "settings") as Button
	var compendium_button := root_lobby.call("get_action_button", "compendium") as Button
	var rules_button := root_lobby.call("get_action_button", "rules") as Button
	var new_game_button := root_lobby.call("get_action_button", "new_run") as Button
	_expect(settings_button != null and compendium_button != null and rules_button != null and new_game_button != null, "main menu exposes New Game, Settings, Codex and Rules")

	settings_button.pressed.emit()
	await process_frame
	var settings := overlay.find_child("CommercialSettingsSurface", true, false) as Control
	_expect(settings != null and settings.visible, "settings surface is production reachable")
	if settings != null and settings.has_method("debug_snapshot"):
		var settings_debug := settings.call("debug_snapshot") as Dictionary
		_expect(bool(settings_debug.get("presentation_only", false)) and not bool(settings_debug.get("owns_gameplay_state", true)), "settings stays outside gameplay authority")
	var back_button := overlay.find_child("MenuBackButton", true, false) as Button
	if back_button != null:
		back_button.pressed.emit()
	await process_frame

	root_lobby = overlay.find_child("MainMenuPlanetLobbyPanel", true, false) as Control
	compendium_button = root_lobby.call("get_action_button", "compendium") as Button if root_lobby != null else null
	if compendium_button != null:
		compendium_button.pressed.emit()
	await process_frame
	var codex := overlay.find_child("CodexCompendiumSurface", true, false) as Control
	_expect(codex != null and codex.visible, "existing Codex surface is production reachable")
	if codex != null and codex.has_method("debug_snapshot"):
		var codex_debug := codex.call("debug_snapshot") as Dictionary
		_expect(bool(codex_debug.get("contracts_ready", false)), "Codex surface contracts remain valid")
	var catalog_back := overlay.find_child("MenuBestiaryBackButton", true, false) as Button
	if catalog_back != null and catalog_back.visible:
		catalog_back.pressed.emit()
	await process_frame

	root_lobby = overlay.find_child("MainMenuPlanetLobbyPanel", true, false) as Control
	rules_button = root_lobby.call("get_action_button", "rules") as Button if root_lobby != null else null
	if rules_button != null:
		rules_button.pressed.emit()
	await process_frame
	var rules_board := overlay.find_child("RulesQuickReferencePanel", true, false) as Control
	_expect(rules_board != null and rules_board.visible, "Rules Quick Reference is production reachable")
	back_button = overlay.find_child("MenuBackButton", true, false) as Button
	if back_button != null:
		back_button.pressed.emit()
	await process_frame

	root_lobby = overlay.find_child("MainMenuPlanetLobbyPanel", true, false) as Control
	new_game_button = root_lobby.call("get_action_button", "new_run") as Button if root_lobby != null else null
	if new_game_button != null:
		new_game_button.pressed.emit()
	await process_frame
	var start_overlay := screen.get_node_or_null("OverlayLayer/StartOverlay") as Control
	var seed_input := screen.find_child("SeedInput", true, false) as LineEdit
	_expect(start_overlay != null and start_overlay.visible, "New Game returns to the inherited embedded setup surface")
	_expect(not overlay.visible, "shell closes before embedded New Game input")
	_expect(seed_input != null and seed_input.has_focus(), "commercial New Game hands GUI focus to the visible Seed input")
	var snapshot := flow.call("local_snapshot") as Dictionary
	_expect(not bool(snapshot.get("match_started", false)), "shell navigation does not start a match")

	application.queue_free()
	await process_frame
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	print((
		"V076_COMMERCIAL_SHELL_REACHABILITY_TEST|status=%s|passed=%d|total=%d|failures=%s"
	) % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks - _failures.size(),
		_checks,
		JSON.stringify(_failures),
	])
	quit(0 if _failures.is_empty() else 1)
