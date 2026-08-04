extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := V074MapGenesisAudit.run_focused()
	var passed := bool(result.get("success", false))
	print("V074_MAP_GENESIS_CONTRACT_TEST|status=%s|passed=%d|total=%d|fingerprint=%s|failures=%s" % [
		"PASS" if passed else "FAIL",
		int(result.get("passed", 0)),
		int(result.get("total", 0)),
		str(result.get("reference_fingerprint", "")),
		JSON.stringify(result.get("failures", [])),
	])
	quit(0 if passed else 1)
