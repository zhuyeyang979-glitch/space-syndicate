extends SceneTree

const AtomicRuntimeTestSuite := preload(
	"res://tests/support/v075_atomic_runtime_test_suite.gd"
)
const CASE_ID := "application_flow_sync_reentry"
const RESULT_LABEL := "V075_APPLICATION_FLOW_SYNC_REENTRY_TEST"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var report := AtomicRuntimeTestSuite.run_case(self, CASE_ID)
	var passed := str(report.get("status", "FAIL")) == "PASS"
	print(
		"%s|status=%s|checks=%d|failures=%d|details=%s"
		% [
			RESULT_LABEL,
			str(report.get("status", "FAIL")),
			int(report.get("checks", 0)),
			int(report.get("failure_count", -1)),
			JSON.stringify(report.get("failures", [])),
		]
	)
	quit(0 if passed else 1)