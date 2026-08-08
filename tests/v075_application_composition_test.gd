extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const V075_BOOTSTRAP_PATH := "res://scripts/v075_runtime/v075_application_bootstrap.gd"
const V075_FLOW_PATH := "res://scripts/v075_runtime/v075_application_flow.gd"
const V075_RULESET_PATH := "res://scripts/v075_runtime/v075_ruleset_runtime_owner.gd"
const V075_RUNTIME_PATH := "res://scripts/v075_runtime/v075_runtime_owner.gd"
const V075_COMPOSITION_PATH := "res://scenes/runtime/V075RuntimeComposition.tscn"
const V075_COMBAT_OWNER_PATH := "res://scripts/v075/runtime/v075_combat_runtime_owner.gd"
const V075_SCREEN_PATH := "res://scenes/ui/v075/V075SampleGameScreen.tscn"
const V075_SCREEN_SCRIPT_PATH := "res://scripts/ui/v075/v075_sample_game_screen.gd"
const V075_SURFACE_SCRIPT_PATH := (
	"res://scripts/ui/v075/v075_combat_player_surface.gd"
)
const V075_SKILL_DOCK_SCRIPT_PATH := (
	"res://scripts/ui/v075/v075_monster_private_skill_dock.gd"
)
const V073_TELEMETRY_SCENE_PATH := "res://scenes/playtest/V073PlaytestTelemetryService.tscn"
const V073_TELEMETRY_SCRIPT_PATH := "res://scripts/playtest/v073_playtest_telemetry_service.gd"
const V074_COMPOSITION_PATH := "res://scenes/runtime/V074RuntimeComposition.tscn"
const LEGACY_MAIN_PATH := "res://scripts/main.gd"
const LEGACY_MAIN_UID_PATH := "res://scripts/main.gd.uid"
const PRIVATE_SKILL_INTENT_KIND := "combat.monster_private_skill.request"
const PRIVATE_SKILL_SOURCE_ID := "monster.ui.single_submission.01"
const PRIVATE_SKILL_DEFINITION_ID := "skill.ui.single_submission.l1"
const COMBAT_SURFACE_NODE_PATH := (
	"V075GameScreen/RootMargin/Shell/V075CombatStackHost/"
	+ "V075CombatOverlay/Margin/Rows/SurfaceHost/CombatSurface"
)
const SKILL_DOCK_NODE_PATH := (
	COMBAT_SURFACE_NODE_PATH + "/Rows/PrivateGrid/SkillDock"
)
const SKILL_CARDS_NODE_PATH := (
	SKILL_DOCK_NODE_PATH + "/Margin/Rows/SkillScroll/SkillCards"
)

var _checks := 0
var _failures: Array[String] = []
var _main_combat_owner_count := 0
var _composition_combat_owner_count := 0
var _composition_telemetry_count := 0
var _v074_composition_reachable_count := 0
var _private_skill_button_press_count := 0
var _private_skill_flow_issue_delta := -1
var _private_skill_flow_submit_delta := -1
var _private_skill_owner_receipt_delta := -1
var _private_skill_runtime_entry_delta := -1
var _private_skill_non_ui_ai_caller_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_required_files()
	var main_source := _read_text(MAIN_SCENE_PATH)
	_test_main_static_contract(main_source)
	_test_v075_source_contracts()
	_test_scene_instantiation()
	await _test_private_skill_button_exact_once()
	_finish()


func _test_required_files() -> void:
	for path in [
		MAIN_SCENE_PATH,
		V075_BOOTSTRAP_PATH,
		V075_FLOW_PATH,
		V075_RULESET_PATH,
		V075_RUNTIME_PATH,
		V075_COMPOSITION_PATH,
		V075_COMBAT_OWNER_PATH,
		V075_SCREEN_PATH,
		V075_SCREEN_SCRIPT_PATH,
		V073_TELEMETRY_SCENE_PATH,
		V073_TELEMETRY_SCRIPT_PATH,
	]:
		_expect(
			FileAccess.file_exists(path),
			"required V075 production dependency exists: %s" % path
		)
	_expect(
		not FileAccess.file_exists(LEGACY_MAIN_PATH),
		"scripts/main.gd is physically absent"
	)
	_expect(
		not FileAccess.file_exists(LEGACY_MAIN_UID_PATH),
		"scripts/main.gd.uid is physically absent"
	)
	_expect(
		FileAccess.file_exists(V074_COMPOSITION_PATH),
		"historical V074 composition remains available for negative reachability test"
	)


func _test_main_static_contract(main_source: String) -> void:
	_expect(
		not main_source.is_empty(),
		"main.tscn can be read by the production gate"
	)
	for path in [V075_BOOTSTRAP_PATH, V075_COMPOSITION_PATH, V075_SCREEN_PATH]:
		_expect(
			_count_occurrences(main_source, path) == 1,
			"main.tscn references exactly one V075 entry dependency: %s" % path
		)
	for path in [
		"res://scripts/v074_runtime/v074_application_bootstrap.gd",
		V074_COMPOSITION_PATH,
		"res://scenes/ui/v074/V074SampleGameScreen.tscn",
	]:
		_expect(
			not main_source.contains(path),
			"main.tscn has no retired V074 production entry reference: %s" % path
		)
	_expect(
		_count_occurrences(
			main_source,
			"[node name=\"V075RuntimeComposition\""
		) == 1,
		"main.tscn has one V075 composition instance"
	)
	_expect(
		_count_occurrences(main_source, "[node name=\"V075GameScreen\"") == 1,
		"main.tscn has one V075 screen instance"
	)
	_expect(
		_count_occurrences(
			main_source,
			"[node name=\"V074RuntimeComposition\""
		) == 0,
		"main.tscn does not instantiate V074RuntimeComposition"
	)
	_expect(
		_count_occurrences(main_source, "[node name=\"V074GameScreen\"") == 0,
		"main.tscn does not instantiate V074GameScreen"
	)


func _test_v075_source_contracts() -> void:
	var composition_source := _read_text(V075_COMPOSITION_PATH)
	if composition_source.is_empty():
		return
	_expect(
		_count_occurrences(composition_source, V075_FLOW_PATH) == 1,
		"V075 composition has one application flow script"
	)
	_expect(
		_count_occurrences(composition_source, V075_RULESET_PATH) == 1,
		"V075 composition has one ruleset owner script"
	)
	_expect(
		_count_occurrences(composition_source, V075_RUNTIME_PATH) == 1,
		"V075 composition has one V075 runtime owner script"
	)
	_expect(
		_count_occurrences(composition_source, V075_COMBAT_OWNER_PATH) == 1,
		"V075 composition has one combat owner script dependency"
	)
	_expect(
		_count_occurrences(composition_source, V073_TELEMETRY_SCENE_PATH) == 1,
		"V075 composition has one V073 playtest telemetry service"
	)
	_expect(
		_count_occurrences(composition_source, "V075RuntimeComposition") == 1,
		"V075 composition has one named root"
	)
	_expect(
		not composition_source.contains(V074_COMPOSITION_PATH),
		"V075 composition does not reach V074 runtime composition"
	)
	for retired_path in [
		"res://scenes/runtime/MonsterRuntimeController.tscn",
		"res://scenes/runtime/MilitaryRuntimeController.tscn",
		"res://scenes/runtime/MonsterWagerResponseSink.tscn",
	]:
		_expect(
			not composition_source.contains(retired_path),
			"V075 composition has no retired combat fallback: %s" % retired_path
		)
	for source_path in [V075_BOOTSTRAP_PATH, V075_FLOW_PATH, V075_RUNTIME_PATH]:
		var source := _read_text(source_path)
		_expect(
			not source.contains(V074_COMPOSITION_PATH),
			"V075 production script has no V074 composition fallback: %s" % source_path
		)
	var dock_source := _read_text(V075_SKILL_DOCK_SCRIPT_PATH)
	var surface_source := _read_text(V075_SURFACE_SCRIPT_PATH)
	var screen_source := _read_text(V075_SCREEN_SCRIPT_PATH)
	var bootstrap_source := _read_text(V075_BOOTSTRAP_PATH)
	var flow_source := _read_text(V075_FLOW_PATH)
	var runtime_source := _read_text(V075_RUNTIME_PATH)
	_expect(
		_count_occurrences(
			dock_source,
			"_on_skill_pressed.bind(_skill_request(skill, target_binding))"
		) == 1
		and _count_occurrences(
			dock_source,
			"private_target_selection_requested.emit(request.duplicate(true))"
		) == 1,
		"one real Skill button has one dock emission route"
	)
	_expect(
		_count_occurrences(
			surface_source,
			"private_target_selection_requested.emit(canonical_request)"
		) == 1
		and _count_occurrences(
			screen_source,
			"application_intent_requested.emit(intent.duplicate(true))"
		) == 1,
		"private skill crosses one surface route and one screen intent route"
	)
	_expect(
		_count_occurrences(
			bootstrap_source,
			'_application_flow.call("submit_intent", intent)'
		) == 1
		and _count_occurrences(
			flow_source,
			'"request_private_monster_skill",'
		) == 1,
		"bootstrap and application flow expose one player-UI runtime submission route"
	)
	_private_skill_non_ui_ai_caller_count = _count_occurrences(
		runtime_source,
		"request_private_monster_skill(actor_id, request_parameters)"
	)
	_expect(
		_private_skill_non_ui_ai_caller_count == 1,
		"the separate non-UI AI private-skill caller remains explicit and singular"
	)


func _test_private_skill_button_exact_once() -> void:
	var main_instance := _instantiate_scene(
		MAIN_SCENE_PATH,
		"main exact-once scene"
	)
	if main_instance == null:
		return
	root.add_child(main_instance)
	await process_frame
	await process_frame

	var screen := main_instance.get_node_or_null("V075GameScreen")
	var flow := main_instance.get_node_or_null("V075RuntimeComposition")
	var runtime := main_instance.get_node_or_null(
		"V075RuntimeComposition/V075RuntimeOwner"
	)
	var surface := main_instance.get_node_or_null(COMBAT_SURFACE_NODE_PATH)
	var skill_dock := main_instance.get_node_or_null(SKILL_DOCK_NODE_PATH)
	_expect(screen != null, "exact-once main exposes the production V075 screen")
	_expect(flow != null, "exact-once main exposes the production application flow")
	_expect(runtime != null, "exact-once main exposes the production runtime owner")
	_expect(surface != null, "exact-once main exposes the production combat surface")
	_expect(skill_dock != null, "exact-once main exposes the production skill dock")
	if (
		screen == null
		or flow == null
		or runtime == null
		or surface == null
		or skill_dock == null
	):
		main_instance.queue_free()
		await process_frame
		return

	screen.call(
		"apply_combat_projection",
		_private_skill_button_projection(),
		PRIVATE_SKILL_SOURCE_ID
	)
	await process_frame
	var skill_cards := main_instance.get_node_or_null(SKILL_CARDS_NODE_PATH)
	var skill_button := _first_enabled_skill_button(skill_cards)
	_expect(
		skill_cards != null,
		"typed owner projection reaches the production SkillCards container"
	)
	_expect(
		skill_button != null,
		"typed owner projection renders one enabled real Skill_* button"
	)
	if skill_button == null:
		main_instance.queue_free()
		await process_frame
		return
	_expect(
		skill_button.name == "Skill_skill_ui_single_submission_l1",
		"the exact-once fixture resolves the expected stable Skill_* node"
	)
	_expect(
		not skill_button.disabled,
		"the exact-once Skill_* button is genuinely requestable"
	)

	_expect(
		skill_button.get_signal_connection_list(&"pressed").size() == 1,
		"the real Skill_* button has one production pressed connection"
	)
	_expect(
		skill_dock.get_signal_connection_list(
			&"private_target_selection_requested"
		).size() == 1,
		"the skill dock has one production target-request connection"
	)
	_expect(
		surface.get_signal_connection_list(
			&"private_target_selection_requested"
		).size() == 1,
		"the combat surface has one production target-request connection"
	)
	_expect(
		screen.get_signal_connection_list(
			&"application_intent_requested"
		).size() == 1,
		"the production screen has one bootstrap submission connection"
	)

	var observed := {
		"button": 0,
		"dock": 0,
		"surface": 0,
		"screen": 0,
		"owner_receipt": 0,
	}
	var screen_intents: Array[Dictionary] = []
	var owner_receipts: Array[Dictionary] = []
	skill_button.pressed.connect(func() -> void:
		observed["button"] = int(observed.get("button", 0)) + 1
	)
	skill_dock.connect(
		&"private_target_selection_requested",
		func(_request: Dictionary) -> void:
			observed["dock"] = int(observed.get("dock", 0)) + 1
	)
	surface.connect(
		&"private_target_selection_requested",
		func(_request: Dictionary) -> void:
			observed["surface"] = int(observed.get("surface", 0)) + 1
	)
	screen.connect(
		&"application_intent_requested",
		func(intent: Dictionary) -> void:
			observed["screen"] = int(observed.get("screen", 0)) + 1
			screen_intents.append(intent.duplicate(true))
	)
	flow.connect(
		&"owner_private_receipt_ready",
		func(receipt: Dictionary) -> void:
			observed["owner_receipt"] = int(
				observed.get("owner_receipt", 0)
			) + 1
			owner_receipts.append(receipt.duplicate(true))
	)

	var flow_before := flow.call("debug_snapshot") as Dictionary
	var runtime_before := runtime.call("debug_snapshot") as Dictionary
	var screen_before := screen.call("combat_debug_snapshot") as Dictionary
	skill_button.pressed.emit()
	await process_frame
	var flow_after := flow.call("debug_snapshot") as Dictionary
	var runtime_after := runtime.call("debug_snapshot") as Dictionary
	var screen_after := screen.call("combat_debug_snapshot") as Dictionary
	_expect(
		runtime_before.has("private_skill_submission_entry_count")
		and runtime_after.has("private_skill_submission_entry_count"),
		"runtime debug exposes the private-skill submission entry counter"
	)

	_private_skill_button_press_count = int(observed.get("button", 0))
	_private_skill_flow_issue_delta = _counter_delta(
		flow_before,
		flow_after,
		"private_skill_issue_count"
	)
	_private_skill_flow_submit_delta = _counter_delta(
		flow_before,
		flow_after,
		"private_skill_submit_count"
	)
	_private_skill_owner_receipt_delta = _counter_delta(
		flow_before,
		flow_after,
		"private_skill_owner_receipt_count"
	)
	_private_skill_runtime_entry_delta = _counter_delta(
		runtime_before,
		runtime_after,
		"private_skill_submission_entry_count"
	)
	var screen_intent_delta := _counter_delta(
		screen_before,
		screen_after,
		"private_skill_intent_count"
	)
	_expect(
		_private_skill_button_press_count == 1
		and int(observed.get("dock", 0)) == 1
		and int(observed.get("surface", 0)) == 1
		and int(observed.get("screen", 0)) == 1,
		"one real Skill_* press crosses dock, surface and screen exactly once"
	)
	_expect(
		screen_intent_delta == 1
		and _private_skill_flow_issue_delta == 1
		and _private_skill_flow_submit_delta == 1,
		"one screen intent is issued and submitted by the real flow exactly once"
	)
	_expect(
		_private_skill_owner_receipt_delta == 1
		and int(observed.get("owner_receipt", 0)) == 1,
		"one application submission publishes one owner-private receipt"
	)
	_expect(
		_private_skill_runtime_entry_delta == 1,
		"one application submission enters the runtime owner exactly once"
	)
	var screen_intent := (
		screen_intents[0]
		if screen_intents.size() == 1
		else {}
	) as Dictionary
	var owner_receipt := (
		owner_receipts[0]
		if owner_receipts.size() == 1
		else {}
	) as Dictionary
	_expect(
		not screen_intent.is_empty()
		and not owner_receipt.is_empty()
		and str(screen_intent.get("intent_id", "")) == str(
			owner_receipt.get("intent_id", "")
		)
		and str(screen_intent.get("intent_kind", ""))
			== PRIVATE_SKILL_INTENT_KIND,
		"screen intent and owner-private receipt retain one canonical identity"
	)
	_expect(
		not owner_receipt.is_empty()
		and not bool(owner_receipt.get("accepted", true))
		and str(owner_receipt.get("reason_code", ""))
			== "private_skill_actor_or_runtime_invalid",
		"synthetic UI-only projection reaches runtime and fails closed without state injection"
	)

	main_instance.queue_free()
	await process_frame


func _private_skill_button_projection() -> Dictionary:
	return {
		"schema": "V075CombatPlayerProjectionV1",
		"ruleset_id": "v0.7.5",
		"viewer_player_id": "player.local",
		"phase": "batch_active",
		"combat_requests_allowed": true,
		"terminal_combat_quiescent": false,
		"public_monsters": [{
			"source_instance_id": PRIVATE_SKILL_SOURCE_ID,
			"source_generation": 1,
			"monster_family_id": "monster.technology.single_submission",
			"owner_player_id": "player.local",
			"display_name": "单次提交校验怪兽",
			"rank": 1,
			"hp": 10,
			"max_hp": 10,
			"armor": 0,
			"preferred_industry_color": "technology",
			"region_id": "region.single_submission",
			"unlocked_skill_count": 1,
			"batch_active_skill_used": false,
			"status": "active",
		}],
		"own_monster_skill_sources": [{
			"source_instance_id": PRIVATE_SKILL_SOURCE_ID,
			"source_generation": 1,
			"owner_player_id": "player.local",
			"monster_display_name": "单次提交校验怪兽",
			"rank": 1,
			"status": "active",
			"batch_active_skill_used": false,
			"skills": [{
				"skill_definition_id": PRIVATE_SKILL_DEFINITION_ID,
				"display_name": "单次提交校验技能",
				"state": "READY",
				"can_request": true,
				"asset_cost_by_color": {},
				"target_contract": {
					"target_kind": "self_source",
				},
				"target_binding": {
					"target_kind": "monster",
					"target_id": PRIVATE_SKILL_SOURCE_ID,
					"target_monster_source_instance_id": (
						PRIVATE_SKILL_SOURCE_ID
					),
					"target_source_generation": 1,
				},
				"cooldown_remaining_batches": 0,
				"ultimate": false,
				"required_rank": 1,
				"public_effect_id": "effect.single_submission",
			}],
		}],
		"military_task_options": [],
		"public_monster_count": 1,
		"own_private_skill_source_count": 1,
	}


func _first_enabled_skill_button(skill_cards: Node) -> Button:
	if not is_instance_valid(skill_cards):
		return null
	for child_variant in skill_cards.get_children():
		if (
			child_variant is Button
			and str((child_variant as Button).name).begins_with("Skill_")
			and not (child_variant as Button).disabled
		):
			return child_variant as Button
	return null


func _counter_delta(
	before: Dictionary,
	after: Dictionary,
	field_name: String
) -> int:
	if not before.has(field_name) or not after.has(field_name):
		return -1
	return int(after.get(field_name, 0)) - int(before.get(field_name, 0))


func _test_scene_instantiation() -> void:
	var main_instance := _instantiate_scene(MAIN_SCENE_PATH, "main scene")
	if main_instance != null:
		var main_bootstrap_count := _count_nodes_with_script(
			main_instance,
			V075_BOOTSTRAP_PATH
		)
		var main_screen_count := _count_nodes_with_script(
			main_instance,
			V075_SCREEN_SCRIPT_PATH
		)
		var main_composition_count := _count_nodes_with_script(
			main_instance,
			V075_FLOW_PATH
		)
		_main_combat_owner_count = _count_nodes_with_script(
			main_instance,
			V075_COMBAT_OWNER_PATH
		)
		_v074_composition_reachable_count = _count_nodes_with_scene_path(
			main_instance,
			V074_COMPOSITION_PATH
		)
		_expect(
			main_bootstrap_count == 1,
			"instantiated main has exactly one V075 bootstrap"
		)
		_expect(
			main_screen_count == 1,
			"instantiated main has exactly one V075 screen"
		)
		_expect(
			main_composition_count == 1,
			"instantiated main has exactly one V075 application flow"
		)
		_expect(
			_main_combat_owner_count == 1,
			"instantiated main reaches exactly one combat owner"
		)
		_expect(
			_v074_composition_reachable_count == 0,
			"instantiated main cannot reach V074 runtime composition"
		)
		main_instance.free()

	var composition_instance := _instantiate_scene(
		V075_COMPOSITION_PATH,
		"V075 runtime composition"
	)
	if composition_instance != null:
		_test_composition_instance(composition_instance)
		composition_instance.free()

	var screen_instance := _instantiate_scene(V075_SCREEN_PATH, "V075 screen")
	if screen_instance != null:
		_expect(
			_count_nodes_with_script(screen_instance, V075_SCREEN_SCRIPT_PATH) == 1,
			"instantiated V075 screen has one wrapper script"
		)
		screen_instance.free()


func _test_composition_instance(composition: Node) -> void:
	var flow_nodes := _nodes_with_script(composition, V075_FLOW_PATH)
	var ruleset_nodes := _nodes_with_script(composition, V075_RULESET_PATH)
	var runtime_nodes := _nodes_with_script(composition, V075_RUNTIME_PATH)
	var combat_nodes := _nodes_with_script(composition, V075_COMBAT_OWNER_PATH)
	var telemetry_nodes := _nodes_with_script(
		composition,
		V073_TELEMETRY_SCRIPT_PATH
	)
	_composition_combat_owner_count = combat_nodes.size()
	_composition_telemetry_count = telemetry_nodes.size()
	_expect(
		_script_path(composition) == V075_FLOW_PATH,
		"V075 composition root owns the V075 application flow"
	)
	_expect(flow_nodes.size() == 1, "V075 composition has one application flow")
	_expect(ruleset_nodes.size() == 1, "V075 composition has one ruleset owner")
	_expect(runtime_nodes.size() == 1, "V075 composition has one V075 runtime owner")
	_expect(
		_composition_combat_owner_count == 1,
		"V075 composition has exactly one combat owner"
	)
	_expect(
		_composition_telemetry_count == 1,
		"V075 composition has exactly one V073 telemetry service"
	)
	_expect(
		_count_nodes_with_scene_path(composition, V074_COMPOSITION_PATH) == 0,
		"V075 composition instance cannot reach V074 composition"
	)

	if ruleset_nodes.size() == 1:
		var identity_variant: Variant = ruleset_nodes[0].call("identity_snapshot")
		_expect(identity_variant is Dictionary, "V075 ruleset owner returns identity")
		if identity_variant is Dictionary:
			var identity := identity_variant as Dictionary
			_expect(str(identity.get("ruleset_id", "")) == "v0.7.5", "entry identity is V0.7.5")
			_expect(str(identity.get("constitution_id", "")) == "space_syndicate.v075.complete", "entry constitution is V075")
			_expect(str(identity.get("sample_mode_id", "")) == "NEW_V075_GAME", "entry mode is NEW_V075_GAME")
			_expect(str(identity.get("sample_build_id", "")) == "alpha_0_5_c2.v075.monster_military.v1", "entry build identity is V075 combat")
			_expect(bool(identity.get("new_game_only", false)), "V075 entry is new-game-only")
			_expect(not bool(identity.get("save_enabled", true)), "V075 production Save is disabled")
			_expect(int(identity.get("current_supported_region_count_min", 0)) == 6, "V075 inherits six-region minimum")
			_expect(int(identity.get("current_supported_region_count_max", 0)) == 30, "V075 inherits thirty-region maximum")

	if combat_nodes.size() == 1:
		var debug_variant: Variant = combat_nodes[0].call("debug_snapshot")
		_expect(debug_variant is Dictionary, "combat owner exposes a debug contract")
		if debug_variant is Dictionary:
			var debug := debug_variant as Dictionary
			_expect(int(debug.get("combat_runtime_owner_count", 0)) == 1, "combat owner count is one")
			_expect(int(debug.get("combat_state_writer_count", 0)) == 1, "combat state writer count is one")
			_expect(int(debug.get("combat_dual_authority_count", -1)) == 0, "combat has no dual authority")
			_expect(int(debug.get("combat_legacy_fallback_count", -1)) == 0, "combat has no legacy fallback")
			_expect(int(debug.get("combat_direct_map_write_count", -1)) == 0, "combat does not write map directly")
			_expect(int(debug.get("combat_direct_facility_write_count", -1)) == 0, "combat does not write facilities directly")

	if telemetry_nodes.size() == 1:
		var telemetry_debug_variant: Variant = telemetry_nodes[0].call("debug_snapshot")
		_expect(telemetry_debug_variant is Dictionary, "V073 telemetry exposes a debug contract")
		if telemetry_debug_variant is Dictionary:
			var telemetry_debug := telemetry_debug_variant as Dictionary
			_expect(int(telemetry_debug.get("gameplay_owner_count", -1)) == 0, "telemetry owns no gameplay")
			_expect(int(telemetry_debug.get("save_owner_count", -1)) == 0, "telemetry owns no Save")
			_expect(int(telemetry_debug.get("rng_owner_count", -1)) == 0, "telemetry owns no RNG")
			_expect(int(telemetry_debug.get("world_mutation_count", -1)) == 0, "telemetry mutates no world state")


func _instantiate_scene(path: String, label: String) -> Node:
	if not FileAccess.file_exists(path):
		return null
	var resource: Resource = ResourceLoader.load(path)
	_expect(resource != null, "%s resource loads" % label)
	if resource == null or not resource is PackedScene:
		_expect(false, "%s is a PackedScene" % label)
		return null
	var instance: Node = (resource as PackedScene).instantiate()
	_expect(instance != null, "%s instantiates" % label)
	return instance


func _nodes_with_script(root_node: Node, script_path: String) -> Array[Node]:
	var nodes: Array[Node] = []
	var all_nodes: Array[Node] = []
	_collect_nodes(root_node, all_nodes)
	for node in all_nodes:
		if _script_path(node) == script_path:
			nodes.append(node)
	return nodes


func _count_nodes_with_script(root_node: Node, script_path: String) -> int:
	return _nodes_with_script(root_node, script_path).size()


func _count_nodes_with_scene_path(root_node: Node, scene_path: String) -> int:
	var count := 0
	var all_nodes: Array[Node] = []
	_collect_nodes(root_node, all_nodes)
	for node in all_nodes:
		if node.scene_file_path == scene_path:
			count += 1
	return count


func _collect_nodes(node: Node, result: Array[Node]) -> void:
	result.append(node)
	for child_variant in node.get_children():
		var child := child_variant as Node
		if child != null:
			_collect_nodes(child, result)


func _script_path(node: Node) -> String:
	var script: Variant = node.get_script()
	if script is Script:
		return (script as Script).resource_path
	return ""


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


func _count_occurrences(source: String, needle: String) -> int:
	if needle.is_empty():
		return 0
	var count := 0
	var cursor := 0
	while cursor < source.length():
		var index := source.find(needle, cursor)
		if index < 0:
			break
		count += 1
		cursor = index + needle.length()
	return count


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	var passed := _checks - _failures.size()
	var status := "PASS" if _failures.is_empty() else "FAIL"
	var summary_format := (
		"V075_APPLICATION_COMPOSITION_TEST"
		+ "|status=%s|passed=%d|total=%d"
		+ "|main_combat_owner_count=%d|composition_combat_owner_count=%d"
		+ "|composition_telemetry_count=%d|v074_composition_reachable_count=%d"
		+ "|private_skill_button_press_count=%d"
		+ "|private_skill_flow_issue_delta=%d"
		+ "|private_skill_flow_submit_delta=%d"
		+ "|private_skill_owner_receipt_delta=%d"
		+ "|private_skill_runtime_entry_delta=%d"
		+ "|private_skill_non_ui_ai_caller_count=%d"
		+ "|details=%s"
	)
	print(summary_format % [
		status,
		passed,
		_checks,
		_main_combat_owner_count,
		_composition_combat_owner_count,
		_composition_telemetry_count,
		_v074_composition_reachable_count,
		_private_skill_button_press_count,
		_private_skill_flow_issue_delta,
		_private_skill_flow_submit_delta,
		_private_skill_owner_receipt_delta,
		_private_skill_runtime_entry_delta,
		_private_skill_non_ui_ai_caller_count,
		JSON.stringify(_failures),
	])
	quit(0 if _failures.is_empty() else 1)
