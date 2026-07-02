extends RefCounted
class_name ScenarioProgress

var scenario: Dictionary = {}
var completed_signals := {}
var phase_failed_attempts := {}
var phase_started_at := 0.0
var now_seconds := 0.0
var dismissed := false
var closed_to_chip := false


func apply_state(definition: Dictionary, signals: Dictionary = {}, is_dismissed: bool = false, is_closed_to_chip: bool = false, failures: Dictionary = {}, started_at: float = 0.0, current_time: float = 0.0) -> RefCounted:
	scenario = definition.duplicate(true)
	completed_signals = signals.duplicate(true)
	phase_failed_attempts = failures.duplicate(true)
	phase_started_at = maxf(0.0, started_at)
	now_seconds = maxf(phase_started_at, current_time)
	dismissed = is_dismissed
	closed_to_chip = is_closed_to_chip
	return self


func mark_signal(signal_id: String) -> void:
	var key := signal_id.strip_edges()
	if key != "":
		completed_signals[key] = true


func current_phase_index() -> int:
	var phases: Array = scenario.get("phases", []) if scenario.get("phases", []) is Array else []
	for i in range(phases.size()):
		var phase: Dictionary = phases[i] if phases[i] is Dictionary else {}
		var signal_id := str(phase.get("success_signal", phase.get("id", ""))).strip_edges()
		if signal_id == "" or not bool(completed_signals.get(signal_id, false)):
			return i
	return phases.size()


func is_complete() -> bool:
	var phases: Array = scenario.get("phases", []) if scenario.get("phases", []) is Array else []
	return not phases.is_empty() and current_phase_index() >= phases.size()


func current_phase() -> Dictionary:
	var phases: Array = scenario.get("phases", []) if scenario.get("phases", []) is Array else []
	var index := current_phase_index()
	if index >= 0 and index < phases.size() and phases[index] is Dictionary:
		return phases[index]
	return {}


func current_phase_id() -> String:
	return str(current_phase().get("id", "")).strip_edges()


func current_phase_failed_attempts() -> int:
	var phase_id := current_phase_id()
	if phase_id == "":
		return 0
	return maxi(0, int(phase_failed_attempts.get(phase_id, 0)))


func current_phase_stuck_seconds() -> float:
	if is_complete() or phase_started_at <= 0.0:
		return 0.0
	return maxf(0.0, now_seconds - phase_started_at)


func to_dictionary() -> Dictionary:
	return {
		"scenario_id": str(scenario.get("id", "")),
		"title": str(scenario.get("title", "")),
		"summary": str(scenario.get("summary", "")),
		"current_index": current_phase_index(),
		"total": (scenario.get("phases", []) as Array).size() if scenario.get("phases", []) is Array else 0,
		"current_phase": current_phase(),
		"completed": is_complete(),
		"dismissed": dismissed,
		"closed_to_chip": closed_to_chip,
		"failed_attempts": current_phase_failed_attempts(),
		"stuck_seconds": current_phase_stuck_seconds(),
		"completed_signals": completed_signals.duplicate(true),
	}
