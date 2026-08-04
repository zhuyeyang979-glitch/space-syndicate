extends SceneTree

const Audit := preload(
	"res://scripts/architecture/v074/v074_legacy_main_retirement_audit.gd"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(Audit.AUDIT_SCHEMA_VERSION == 1, "retirement audit schema is V1")
	_expect(
		not FileAccess.file_exists(Audit.LEGACY_MAIN_PATH),
		"legacy Main script is physically absent"
	)
	_expect(
		not FileAccess.file_exists(Audit.LEGACY_MAIN_UID_PATH),
		"legacy Main UID is physically absent"
	)
	var production_closure := Audit.production_dependency_closure()
	var production_references := Audit.production_reference_records()
	var active_test_references := Audit.active_v074_test_reference_records()
	var wrappers := Audit.compatibility_wrapper_paths()
	_expect(
		production_closure.has(Audit.MAIN_SCENE_PATH),
		"production dependency audit starts at main.tscn"
	)
	_expect(
		production_references.is_empty(),
		"production dependency closure has zero legacy Main references"
	)
	_expect(
		active_test_references.is_empty(),
		"active V0.7.4 tests have zero legacy Main dependencies"
	)
	_expect(
		wrappers.is_empty(),
		"no compatibility wrapper or replacement monolith exists"
	)
	var main_scene_source := FileAccess.get_file_as_string(
		Audit.MAIN_SCENE_PATH
	)
	_expect(
		not main_scene_source.contains(Audit.LEGACY_MAIN_RESOURCE_TOKEN),
		"main.tscn has no legacy Main script reference"
	)
	print((
		"V074_LEGACY_MAIN_RETIREMENT_TEST|status=%s|passed=%d|total=%d"
		+ "|production_closure=%d|production_references=%d"
		+ "|active_test_references=%d|compatibility_wrappers=%d"
		+ "|details=%s"
	) % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks - _failures.size(),
		_checks,
		production_closure.size(),
		production_references.size(),
		active_test_references.size(),
		wrappers.size(),
		JSON.stringify(_failures),
	])
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)
