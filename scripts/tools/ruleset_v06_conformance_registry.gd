extends RefCounted
class_name RulesetV06ConformanceRegistry

const STATUS_ALIGNED := "aligned"
const STATUS_CHARACTERIZED := "characterized"
const STATUS_RUNTIME_INACTIVE := "runtime_inactive"
const STATUS_BLOCKED := "blocked"

const RECORDS := [
	{
		"gate_id": "ss06_00_recoverable_baseline",
		"status": STATUS_ALIGNED,
		"owner": "Git pre-v0.6-runtime-baseline",
		"evidence": "Clean-clone import, composition, and layout smoke passed at c9c1b33841df3f96efe6a5b2a2132ed19e0effce.",
		"next_step": "Keep the annotated baseline immutable.",
	},
	{
		"gate_id": "ss06_00_ruleset_profile",
		"status": STATUS_RUNTIME_INACTIVE,
		"owner": "res://resources/rules/space_syndicate_ruleset_v06.tres",
		"evidence": "Inspector profile and validator expose v0.6 shared-HP, facility, commodity, mana, victory, card-window, and wager defaults.",
		"next_step": "Consume only at an atomic owning-domain cutover; never add a global selector or fallback.",
	},
	{
		"gate_id": "ss06_00_region_infrastructure_characterization",
		"status": STATUS_CHARACTERIZED,
		"owner": "res://scenes/tools/RegionInfrastructureRuntimeCharacterizationBench.tscn",
		"evidence": "68/68 observations freeze the real v0.4 main lifecycle, save boundary, cross-domain writers, and SS06-01 deletion budget.",
		"next_step": "Create one RegionInfrastructureRuntimeController and delete the old main owner in the same SS06-01 commit.",
	},
	{
		"gate_id": "legacy_heat_panic_retirement",
		"status": STATUS_BLOCKED,
		"owner": "legacy v0.4 main/cards/presentation/monster surfaces",
		"evidence": "v0.6 Profile and schemas contain no heat/panic state; legacy sources are cataloged only as deletion evidence.",
		"next_step": "Delete region panic state, target scoring, heat-triggered damage, player labels, and reauthor-or-block affected cards during SS06-01.",
	},
]


static func records() -> Array:
	return RECORDS.duplicate(true)


static func record_for_gate(gate_id: String) -> Dictionary:
	for record_variant in RECORDS:
		var record: Dictionary = record_variant
		if str(record.get("gate_id", "")) == gate_id:
			return record.duplicate(true)
	return {}


static func debug_snapshot() -> Dictionary:
	return {
		"registry_id": "ruleset_v06_conformance",
		"ruleset_id": "v0.6",
		"production_runtime_active": false,
		"production_ruleset_id": "v0.4",
		"records": records(),
	}
