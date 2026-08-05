extends SceneTree

const Audit := preload(
	"res://scripts/architecture/v074/v074_legacy_main_retirement_audit.gd"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var audit := Audit.bootstrap_audit()
	_expect(
		str(audit.get("path", "")) == (
			"res://scripts/v074_runtime/v074_application_bootstrap.gd"
		),
		"ratchet targets the V0.7.4 application bootstrap"
	)
	_expect(
		bool(audit.get("exists", false)),
		"V0.7.4 application bootstrap is integrated"
	)
	if bool(audit.get("exists", false)):
		_expect(
			int(audit.get("line_count", 0)) <= 120,
			"top-level bootstrap remains at most 120 lines"
		)
		_expect(
			(audit.get("unexpected_methods", []) as Array).is_empty(),
			"bootstrap exposes only composition and typed forwarding methods"
		)
		_expect(
			int(audit.get("domain_rule_count", -1)) == 0,
			"bootstrap owns zero domain rules"
		)
		_expect(
			int(audit.get("gameplay_mutation_count", -1)) == 0,
			"bootstrap performs zero gameplay mutations"
		)
		_expect(
			int(audit.get("save_owner_count", -1)) == 0,
			"bootstrap owns no Save behavior"
		)
		_expect(
			int(audit.get("rng_owner_count", -1)) == 0,
			"bootstrap owns no RNG behavior"
		)
		_expect(
			int(audit.get("legacy_main_reference_count", -1)) == 0,
			"bootstrap has no legacy Main lookup or fallback"
		)
		var main_scene_source := FileAccess.get_file_as_string(
			Audit.MAIN_SCENE_PATH
		)
		_expect(
			main_scene_source.contains(Audit.V074_BOOTSTRAP_PATH),
			"production main.tscn composes the V0.7.4 bootstrap"
		)
	print((
		"V074_BOOTSTRAP_ARCHITECTURE_RATCHET_TEST"
		+ "|status=%s|passed=%d|total=%d|path=%s|exists=%s"
		+ "|line_count=%d|domain_rules=%d|gameplay_mutations=%d"
		+ "|save_owners=%d|rng_owners=%d|details=%s"
	) % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks - _failures.size(),
		_checks,
		str(audit.get("path", "")),
		str(audit.get("exists", false)),
		int(audit.get("line_count", 0)),
		int(audit.get("domain_rule_count", 0)),
		int(audit.get("gameplay_mutation_count", 0)),
		int(audit.get("save_owner_count", 0)),
		int(audit.get("rng_owner_count", 0)),
		JSON.stringify(_failures),
	])
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)
