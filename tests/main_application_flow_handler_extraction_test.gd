extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"
const MAIN_SOURCE := "res://scripts/" + "main.gd"
const PORT_SCENE := "res://scenes/runtime/ApplicationFlowPort.tscn"
const CONTROLLER_SCENE := "res://scenes/runtime/ApplicationFlowController.tscn"
const INTEL_QUERY_SCENE := "res://scenes/runtime/presentation/IntelDossierViewerQueryPort.tscn"
const INTEL_COMMAND_SCENE := "res://scenes/runtime/IntelPrivateCommandPort.tscn"
const INTEL_CONTROLLER_SCENE := "res://scenes/runtime/IntelApplicationFlowController.tscn"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_scene := load(MAIN_SCENE) as PackedScene
	_check(main_scene != null, "formal main scene loads")
	_check(load(PORT_SCENE) != null, "ApplicationFlowPort scene loads")
	_check(load(CONTROLLER_SCENE) != null, "ApplicationFlowController scene loads")
	_check(load(INTEL_QUERY_SCENE) != null, "Intel viewer query scene loads")
	_check(load(INTEL_COMMAND_SCENE) != null, "Intel private command scene loads")
	_check(load(INTEL_CONTROLLER_SCENE) != null, "Intel application controller scene loads")
	if main_scene == null:
		_finish()
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	var port := main.get_node_or_null("RuntimeServices/ApplicationFlowPort") as ApplicationFlowPort
	var controller := main.get_node_or_null("RuntimeServices/ApplicationFlowController") as ApplicationFlowController
	var standings_controller := main.get_node_or_null("RuntimeServices/StandingsApplicationFlowController")
	var standings_query := main.get_node_or_null("RuntimeServices/StandingsPublicQueryPort")
	var intel_query := main.get_node_or_null("RuntimeServices/IntelDossierViewerQueryPort") as IntelDossierViewerQueryPort
	var intel_commands := main.get_node_or_null("RuntimeServices/IntelPrivateCommandPort") as IntelPrivateCommandPort
	var intel_controller := main.get_node_or_null("RuntimeServices/IntelApplicationFlowController") as IntelApplicationFlowController
	_check(port != null, "one production ApplicationFlowPort is composed")
	_check(controller != null, "one production ApplicationFlowController is composed")
	_check(standings_controller != null and standings_query != null, "one production standings controller and query port are composed")
	_check(intel_query != null and intel_commands != null and intel_controller != null, "one production Intel query, command, and scene controller are composed")
	if port != null and controller != null:
		var controller_debug := controller.debug_snapshot()
		_check(not bool(controller_debug.get("owns_gameplay_state", true)), "controller does not own gameplay state")
		_check(not bool(controller_debug.get("owns_runtime_command_pipeline", true)), "controller does not own command pipeline")
		_check(bool(port.submit_action("rules")), "rules action remains allow-listed")
		_check(int(controller.debug_snapshot().get("rules_open_count", 0)) == 1, "rules reaches the real ApplicationFlowController")
		_check(not port.submit_action("invalid_action"), "invalid action is rejected")
		var generic_before := int(port.debug_snapshot().get("action_emission_count", 0))
		_check(port.submit_action("standings"), "standings action remains allow-listed")
		var port_debug := port.debug_snapshot()
		_check(int(port_debug.get("standings_emission_count", 0)) == 1 and int(port_debug.get("action_emission_count", 0)) == generic_before, "standings bypasses the generic Main action signal")
		var emissions := {"generic": 0, "intel": 0}
		port.action_requested.connect(func(_action_id: StringName): emissions["generic"] = int(emissions["generic"]) + 1)
		port.intel_requested.connect(func(): emissions["intel"] = int(emissions["intel"]) + 1)
		_check(port.submit_action("intel"), "intel action remains allow-listed")
		port_debug = port.debug_snapshot()
		_check(int(emissions["intel"]) == 1 and int(emissions["generic"]) == 0, "intel emits only its dedicated signal")
		_check(int(port_debug.get("intel_emission_count", 0)) == 1 and int(port_debug.get("action_emission_count", 0)) == generic_before, "intel debug counters prove zero generic dispatch")
		var typed_emissions := {"count": 0}
		port.intel_application_intent_requested.connect(func(_intent: IntelApplicationIntent): typed_emissions["count"] = int(typed_emissions["count"]) + 1)
		_check(port.submit_intel_application_intent(IntelApplicationIntent.open("", "region.001")), "typed Intel intent is accepted at the application boundary")
		port_debug = port.debug_snapshot()
		_check(int(typed_emissions["count"]) == 1 and int(port_debug.get("intel_application_intent_emission_count", 0)) == 1 and int(port_debug.get("action_emission_count", 0)) == generic_before, "typed Intel intent emits dedicated exactly once and never generic")
		_check(not port.request_menu("", "", false), "empty menu request is rejected")

	var main_scene_source := FileAccess.get_file_as_string(MAIN_SCENE)
	_check(main_scene_source.contains("IntelDossierViewerQueryPort.tscn") and main_scene_source.contains("IntelPrivateCommandPort.tscn") and main_scene_source.contains("IntelApplicationFlowController.tscn"), "main scene explicitly composes the Intel cutover nodes")
	_check(main_scene_source.contains('signal="intel_requested" from="RuntimeServices/ApplicationFlowPort" to="RuntimeServices/IntelApplicationFlowController" method="open_intel"'), "dedicated Intel signal targets the scene-owned controller")
	_check(main_scene_source.contains('signal="application_intent_requested" from="RuntimeGameScreen" to="RuntimeServices/ApplicationFlowPort" method="submit_intel_application_intent"'), "GameScreen typed Intel intent enters ApplicationFlowPort")
	_check(main_scene_source.contains('signal="application_intent_requested" from="RuntimeGameScreen/OverlayLayer/RuntimeSurfaceLayer/MenuModalOverlay" to="RuntimeServices/ApplicationFlowPort" method="submit_intel_application_intent"'), "MenuOverlay typed Intel intent enters ApplicationFlowPort")
	_check(main_scene_source.contains('signal="intel_application_intent_requested" from="RuntimeServices/ApplicationFlowPort" to="RuntimeServices/IntelApplicationFlowController" method="open_application_intent"'), "ApplicationFlowPort typed signal targets the scene-owned controller")
	_check(main_scene_source.count('signal="application_intent_requested" from="RuntimeGameScreen') == 2 and not main_scene_source.contains('application_intent_requested" from="RuntimeGameScreen" to="RuntimeServices/IntelApplicationFlowController'), "direct UI-to-Intel-controller typed routes are zero")
	_check(not main_scene_source.contains('to="." method="_open_intel_dossier_menu"'), "production scene has no direct Intel-to-Main connection")

	var main_source := FileAccess.get_file_as_string(MAIN_SOURCE)
	for retired_symbol in [
		"func _open_intel_dossier_menu(",
		"func _intel_dossier_public_source_snapshot(",
		"func _intel_dossier_public_snapshot(",
		"func _on_intel_dossier_action_requested(",
		"func _mark_city_guess_for_player(",
		"track_intel_",
		"strategy_intel_",
		"district_open_intel",
		"IntelApplicationIntent",
		"IntelDossier",
	]:
		_check(not main_source.contains(retired_symbol), "Main retired Intel route is absent: %s" % retired_symbol)
	var intel_controller_source := FileAccess.get_file_as_string("res://scripts/runtime/intel_application_flow_controller.gd")
	var intel_query_source := FileAccess.get_file_as_string("res://scripts/presentation/intel_dossier_viewer_query_port.gd")
	_check(not intel_controller_source.contains("current_scene") and not intel_controller_source.contains("/root/") and not intel_controller_source.contains("has_method") and not intel_controller_source.contains("Object.call"), "Intel controller has no Main, root, or dynamic method fallback")
	_check(not intel_query_source.contains("RouteNetwork") and not intel_query_source.contains("refresh_routes") and not intel_query_source.contains("current_scene") and not intel_query_source.contains("/root/"), "Intel viewer query has no route refresh or scene fallback")
	main.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("main_application_flow_handler_extraction_test: PASS %d/%d" % [_checks, _checks])
		quit(0)
	else:
		printerr("main_application_flow_handler_extraction_test: FAIL %d/%d\n%s" % [_failures.size(), _checks, "\n".join(_failures)])
		quit(1)
