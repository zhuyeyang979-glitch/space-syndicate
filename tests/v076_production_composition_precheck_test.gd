extends SceneTree

## Read-only boundary proof for the next authorized V0.7.6 action.
##
## This test intentionally proves that the current production entry remains the
## V0.7.5 composition.  It does not wire V0.7.6 Owners, mutate the scene, or
## promote isolated STEP10 evidence to production or human green.

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const V075_COMPOSITION_PATH := "res://scenes/runtime/V075RuntimeComposition.tscn"
const V075_SCREEN_PATH := "res://scenes/ui/v075/V075SampleGameScreen.tscn"
const V075_BOOTSTRAP_PATH := "res://scripts/v075_runtime/v075_application_bootstrap.gd"
const V075_FLOW_PATH := "res://scripts/v075_runtime/v075_application_flow.gd"
const V075_RUNTIME_OWNER_PATH := "res://scripts/v075_runtime/v075_runtime_owner.gd"
const V075_COMBAT_OWNER_PATH := "res://scripts/v075/runtime/v075_combat_runtime_owner.gd"
const GOLDEN_PATH := "res://docs/architecture/V076_ALPHA07_GOLDEN_PLAYTEST_SCENARIO.json"
const LEDGER_PATH := "res://docs/architecture/V076_INHERITED_GREEN_LEDGER.json"
const V076_SCRIPT_PREFIX := "res://scripts/v076/"
const NEXT_AUTHORIZATION_BOUNDARY := (
	"V076_STAGE4_MILITARY_PRODUCTION_COMPOSITION_AUTHORIZATION_BOUNDARY"
)

const V076_OWNER_TOKENS := [
	"V076PrivateDirectActionInputOwnerV1",
	"V076PrivateDirectActionReducerV1",
	"V076DeterministicKernel",
	"V076MilitaryPhysicalEtaOwnerV1",
	"V076MilitaryUnitProfileAuthority",
	"V076MilitaryUnitProfileCatalogV1",
	"V076MilitaryCardCrosswalkV1",
	"V076SharedHalfEdgePartitionV1",
	"V076MonsterL1ReducerV1",
]

const V076_PRODUCTION_ENTRY_TOKENS := [
	"res://scripts/v076/",
	"res://scenes/tools/v076/",
	"res://scenes/runtime/v076/",
	"res://scenes/ui/v076/",
]

const LEGACY_FALLBACK_TOKENS := [
	"res://scripts/v074_runtime/",
	"res://scenes/runtime/V074RuntimeComposition.tscn",
	"res://scenes/ui/v074/V074SampleGameScreen.tscn",
	"res://scenes/runtime/MonsterRuntimeController.tscn",
	"res://scenes/runtime/MilitaryRuntimeController.tscn",
	"res://scenes/runtime/MonsterWagerResponseSink.tscn",
	"res://scripts/main.gd",
]

var _checks := 0
var _failures: Array[String] = []
var _instantiated_node_count := 0
var _instantiated_v076_script_count := 0
var _v075_runtime_owner_count := 0
var _v075_combat_owner_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_required_files()
	var main_source := _read_text(MAIN_SCENE_PATH)
	var composition_source := _read_text(V075_COMPOSITION_PATH)
	var screen_source := _read_text(V075_SCREEN_PATH)
	_test_static_v075_only_contract(main_source, composition_source, screen_source)
	_test_golden_and_ledger_boundary()
	await _test_instantiated_production_closure()
	_finish()


func _test_required_files() -> void:
	for path in [
		MAIN_SCENE_PATH,
		V075_COMPOSITION_PATH,
		V075_SCREEN_PATH,
		V075_BOOTSTRAP_PATH,
		V075_FLOW_PATH,
		V075_RUNTIME_OWNER_PATH,
		V075_COMBAT_OWNER_PATH,
		GOLDEN_PATH,
		LEDGER_PATH,
	]:
		_expect(FileAccess.file_exists(path), "precheck dependency exists: %s" % path)


func _test_static_v075_only_contract(
	main_source: String,
	composition_source: String,
	screen_source: String
) -> void:
	_expect(
		_count_occurrences(main_source, V075_BOOTSTRAP_PATH) == 1
			and _count_occurrences(main_source, V075_COMPOSITION_PATH) == 1
			and _count_occurrences(main_source, V075_SCREEN_PATH) == 1,
		"main.tscn has one V075 bootstrap, composition, and screen entry"
	)
	_expect(
		_count_occurrences(main_source, "[node name=\"V075RuntimeComposition\"") == 1
			and _count_occurrences(main_source, "[node name=\"V075GameScreen\"") == 1,
		"main.tscn instantiates exactly one V075 runtime root and one V075 screen"
	)
	for source_name in ["main.tscn", "V075RuntimeComposition.tscn", "V075SampleGameScreen.tscn"]:
		var source := main_source
		if source_name == "V075RuntimeComposition.tscn":
			source = composition_source
		elif source_name == "V075SampleGameScreen.tscn":
			source = screen_source
		for token in V076_PRODUCTION_ENTRY_TOKENS:
			_expect(
				not source.contains(token),
				"%s has no V076 production-entry token: %s" % [source_name, token]
			)
		var legacy_tokens := LEGACY_FALLBACK_TOKENS
		if source_name == "V075SampleGameScreen.tscn":
			# The V075 screen intentionally inherits the established V074 visual
			# shell.  It must not inherit the retired V074 runtime composition.
			legacy_tokens = [
				"res://scripts/v074_runtime/",
				"res://scenes/runtime/V074RuntimeComposition.tscn",
				"res://scenes/runtime/MonsterRuntimeController.tscn",
				"res://scenes/runtime/MilitaryRuntimeController.tscn",
				"res://scenes/runtime/MonsterWagerResponseSink.tscn",
				"res://scripts/main.gd",
			]
		for token in legacy_tokens:
			_expect(
				not source.contains(token),
				"%s has no retired or fallback production token: %s" % [source_name, token]
			)
	for token in V076_OWNER_TOKENS:
		_expect(
			not composition_source.contains(token),
			"V075 composition does not name a V076 Owner or reducer: %s" % token
		)
	_expect(
		_count_occurrences(composition_source, V075_FLOW_PATH) == 1
			and _count_occurrences(composition_source, V075_RUNTIME_OWNER_PATH) == 1
			and _count_occurrences(composition_source, V075_COMBAT_OWNER_PATH) == 1,
		"V075 composition retains one application flow, runtime Owner, and combat Owner"
	)


func _test_golden_and_ledger_boundary() -> void:
	var golden_variant: Variant = JSON.parse_string(_read_text(GOLDEN_PATH))
	var ledger_variant: Variant = JSON.parse_string(_read_text(LEDGER_PATH))
	var golden := golden_variant as Dictionary
	var ledger := ledger_variant as Dictionary
	_expect(golden != null and ledger != null, "Golden and inherited Ledger JSON parse")
	if golden == null or ledger == null:
		return
	_expect(
		str(golden.get("overall_status", "")) == "PENDING_HUMAN_PRODUCTION_EXECUTION",
		"Golden overall status remains pending human production execution"
	)
	_expect(
		int(golden.get("production_pass_count", -1)) == 0
			and int(golden.get("human_execution_count", -1)) == 0,
		"Golden production and human counts remain zero"
	)
	var golden_steps := golden.get("steps", []) as Array
	var step10 := _step_by_id(golden_steps, "STEP10")
	_expect(
		step10 != null
			and str(step10.get("status", "")) == "ISOLATED_GREEN"
			and step10.get("production_composition", true) == false
			and step10.get("human_executed", true) == false,
		"STEP10 remains isolated-only and has no production or human claim"
	)
	var canonical := ledger.get("canonical_pr_status", {}) as Dictionary
	_expect(
		canonical.get("production_cutover_status", true) == false
			and int(canonical.get("golden_production_green_count", -1)) == 0
			and int(canonical.get("golden_human_green_count", -1)) == 0,
		"Ledger keeps production cutover and production/human green false"
	)
	_expect(
		str(ledger.get("product_development_resume_target", ""))
			== NEXT_AUTHORIZATION_BOUNDARY
			and str(canonical.get("next_stage", ""))
			== NEXT_AUTHORIZATION_BOUNDARY,
		"Ledger advances from the completed precheck to the explicit authorization boundary"
	)


func _test_instantiated_production_closure() -> void:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	_expect(packed != null, "main.tscn parse-loads for read-only closure inspection")
	if packed == null:
		return
	var instance := packed.instantiate()
	_expect(instance != null, "main.tscn instantiates for read-only closure inspection")
	if instance == null:
		return
	root.add_child(instance)
	await process_frame
	await process_frame
	var nodes: Array[Node] = []
	_collect_nodes(instance, nodes)
	_instantiated_node_count = nodes.size()
	for node in nodes:
		var script_variant: Variant = node.get_script()
		if script_variant is not Script:
			continue
		var script_path := (script_variant as Script).resource_path
		if script_path.begins_with(V076_SCRIPT_PREFIX):
			_instantiated_v076_script_count += 1
		if script_path == V075_RUNTIME_OWNER_PATH:
			_v075_runtime_owner_count += 1
		if script_path == V075_COMBAT_OWNER_PATH:
			_v075_combat_owner_count += 1
	_expect(
		_instantiated_v076_script_count == 0,
		"production instance reaches zero V076 script Owners (count=%d)"
			% _instantiated_v076_script_count
	)
	_expect(
		_v075_runtime_owner_count == 1 and _v075_combat_owner_count == 1,
		"production instance reaches one V075 runtime Owner and one combat Owner"
	)
	_expect(
		_count_named_nodes(instance, "V075RuntimeComposition") == 1
			and _count_named_nodes(instance, "V075GameScreen") == 1
			and _count_named_nodes(instance, "V076PrivateDirectActionInputOwnerV1") == 0
			and _count_named_nodes(instance, "V076DeterministicKernel") == 0,
		"production instance has no duplicate V076 Owner or Kernel fallback node"
	)
	instance.queue_free()
	await process_frame


func _step_by_id(steps: Array, step_id: String) -> Dictionary:
	for item_variant in steps:
		if item_variant is Dictionary and str((item_variant as Dictionary).get("step_id", "")) == step_id:
			return item_variant as Dictionary
	return {}


func _collect_nodes(node: Node, result: Array[Node]) -> void:
	result.append(node)
	for child_variant in node.get_children():
		var child := child_variant as Node
		if child != null:
			_collect_nodes(child, result)


func _count_named_nodes(node: Node, expected_name: String) -> int:
	var count := 0
	var nodes: Array[Node] = []
	_collect_nodes(node, nodes)
	for candidate in nodes:
		if candidate.name == expected_name:
			count += 1
	return count


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
	push_error("V076 PRODUCTION COMPOSITION PRECHECK: %s" % message)


func _finish() -> void:
	var passed := _checks - _failures.size()
	var status := "PASS" if _failures.is_empty() else "FAIL"
	var summary_format := (
		"V076_PRODUCTION_COMPOSITION_PRECHECK"
		+ "|status=%s|passed=%d|total=%d"
		+ "|instantiated_node_count=%d|instantiated_v076_script_count=%d"
		+ "|v075_runtime_owner_count=%d|v075_combat_owner_count=%d"
		+ "|production_cutover_authorized=false|production_green=false|human_green=false"
		+ "|details=%s"
	)
	print(summary_format % [
		status,
		passed,
		_checks,
		_instantiated_node_count,
		_instantiated_v076_script_count,
		_v075_runtime_owner_count,
		_v075_combat_owner_count,
		JSON.stringify(_failures),
	])
	quit(0 if _failures.is_empty() else 1)
