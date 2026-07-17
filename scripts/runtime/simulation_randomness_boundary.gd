@tool
extends Node
class_name SimulationRandomnessBoundary

const SEEDED_SIMULATION := &"seeded_simulation"
const VISUAL_ONLY := &"visual_only"
const UNCONTROLLED := &"uncontrolled"

var _audit_count := 0
var _last_report: Dictionary = {}


func audit(declarations: Array) -> Dictionary:
	var violations: Array[Dictionary] = []
	var counts := {
		String(SEEDED_SIMULATION): 0,
		String(VISUAL_ONLY): 0,
		String(UNCONTROLLED): 0,
	}
	for declaration_variant in declarations:
		if not (declaration_variant is Dictionary):
			violations.append({"source_id": "", "reason": "randomness_declaration_invalid"})
			continue
		var declaration := declaration_variant as Dictionary
		var source_id := str(declaration.get("source_id", ""))
		var classification := StringName(str(declaration.get("classification", "")))
		var can_mutate_world := bool(declaration.get("can_mutate_world", false))
		var seedable := bool(declaration.get("seedable", false))
		var reproducible := bool(declaration.get("reproducible", false))
		if not counts.has(String(classification)):
			violations.append({"source_id": source_id, "reason": "randomness_classification_unknown"})
			continue
		counts[String(classification)] = int(counts[String(classification)]) + 1
		if classification == UNCONTROLLED and can_mutate_world:
			violations.append({"source_id": source_id, "reason": "uncontrolled_simulation_randomness"})
		elif classification == VISUAL_ONLY and can_mutate_world:
			violations.append({"source_id": source_id, "reason": "visual_randomness_world_mutation"})
		elif classification == SEEDED_SIMULATION and (not seedable or not reproducible):
			violations.append({"source_id": source_id, "reason": "simulation_randomness_not_reproducible"})
	_audit_count += 1
	_last_report = {
		"valid": violations.is_empty(),
		"declaration_count": declarations.size(),
		"counts": counts,
		"violations": violations,
		"violation_count": violations.size(),
	}
	return _last_report.duplicate(true)


func debug_snapshot() -> Dictionary:
	return {
		"audit_count": _audit_count,
		"owns_rng_state": false,
		"owns_world_state": false,
		"requires_seeded_world_randomness": true,
		"last_report": _last_report.duplicate(true),
	}
