extends SceneTree

const LATEST_MAIN_SHA := "054552f0c3748da2960d94440b2062f042401d3e"
const PR80_PRE_RESYNC_HEAD := "a1fdfc485815e924f465562d60165500cd436671"
const MANIFEST_PATH := "res://docs/migration/v07_atomic_cutover_manifest.json"
const CATALOG_PATH := (
	"res://resources/presentation/alpha01_card_illustration_catalog.tres"
)
const ALLOWED_CHANGE_PREFIXES := [
	"docs/migration/",
	"scripts/v07_adapters/",
	"tests/v07_adapters/",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	if OS.get_cmdline_user_args().has("--parse-only"):
		print("V07_LATEST_MAIN_RESYNC | status=PARSE_ONLY_PASS")
		quit(0)
		return
	call_deferred("_run")


func _run() -> void:
	_expect(
		_git_is_ancestor(LATEST_MAIN_SHA, "HEAD"),
		"task branch contains the latest commercial-art main baseline"
	)
	_expect(
		_git_is_ancestor(PR80_PRE_RESYNC_HEAD, "HEAD"),
		"task branch preserves the complete pre-resync PR80 history"
	)
	var manifest := _load_json(MANIFEST_PATH)
	_expect(
		str(manifest.get("baseline_sha", "")) == LATEST_MAIN_SHA,
		"atomic cutover manifest binds the latest main baseline"
	)
	var catalog_source := FileAccess.get_file_as_string(CATALOG_PATH)
	_expect(
		catalog_source.contains(
			'stable_asset_schema_version = "commercial.presentation_assets.v1"'
		),
		"latest main supplies the canonical commercial Presentation Asset Catalog"
	)
	_expect(
		catalog_source.contains('"icon.asset.life"')
			and catalog_source.contains('"card.frame.normal"')
			and catalog_source.contains('"model.facility.factory.base"')
			and catalog_source.contains('"font.display"'),
		"latest main Catalog exposes representative icon, card, model, and font keys"
	)
	var changed_paths := _git_lines([
		"diff", "--name-only", "%s...HEAD" % LATEST_MAIN_SHA,
	])
	_expect(
		not changed_paths.is_empty(),
		"resynced adapter branch has an explicit detached change set"
	)
	var scope_ready := true
	for path in changed_paths:
		if not _starts_with_any(path, ALLOWED_CHANGE_PREFIXES):
			scope_ready = false
			break
	_expect(
		scope_ready,
		"all post-main changes remain in adapter, adapter-test, or migration-doc scope"
	)
	_expect(
		not changed_paths.has("scripts/main.gd")
			and not changed_paths.has("scenes/main.tscn")
			and not changed_paths.has(
				"scenes/runtime/GameRuntimeCoordinator.tscn"
			),
		"resync adds no Main or production-scene connection"
	)
	_finish()


func _git_is_ancestor(ancestor: String, descendant: String) -> bool:
	var output: Array = []
	return OS.execute(
		"git",
		PackedStringArray(["merge-base", "--is-ancestor", ancestor, descendant]),
		output,
		true
	) == 0


func _git_lines(arguments: Array[String]) -> Array[String]:
	var output: Array = []
	var exit_code := OS.execute("git", PackedStringArray(arguments), output, true)
	var result: Array[String] = []
	if exit_code != 0:
		return result
	for output_variant in output:
		for line_variant in str(output_variant).split("\n", false):
			var line := str(line_variant).strip_edges().replace("\\", "/")
			if not line.is_empty():
				result.append(line)
	return result


func _starts_with_any(value: String, prefixes: Array) -> bool:
	for prefix_variant in prefixes:
		if value.begins_with(str(prefix_variant)):
			return true
	return false


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("V07_LATEST_MAIN_RESYNC | passed=%d total=%d" % [_checks, _checks])
		quit(0)
		return
	for failure in _failures:
		push_error("V07_LATEST_MAIN_RESYNC | %s" % failure)
	push_error(
		"V07_LATEST_MAIN_RESYNC | passed=%d total=%d"
			% [_checks - _failures.size(), _checks]
	)
	quit(1)
