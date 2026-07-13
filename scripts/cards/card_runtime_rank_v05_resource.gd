extends Resource
class_name CardRuntimeRankV05Resource

@export var schema_version: String = "v0.5"
@export var card_id: String = ""
@export var family_id: String = ""
@export_range(1, 4, 1) var rank: int = 1
@export var source_v04_card_id: String = ""
@export var name_key: String = ""
@export var rules_key: String = ""
@export var short_effect_key: String = ""
@export var assistive_name_key: String = ""
@export var requirements: Array[CardPlayRequirementV05Resource] = []
@export_enum("blocked", "draft", "release_ready") var migration_status: String = "blocked"
@export_multiline var blocking_reason: String = ""
@export var release_ready: bool = false
@export var public_pool: bool = false


func to_snapshot() -> Dictionary:
	var requirement_snapshots: Array[Dictionary] = []
	for requirement in requirements:
		if requirement != null:
			requirement_snapshots.append(requirement.to_snapshot())
	return {
		"schema_version": schema_version,
		"card_id": card_id,
		"family_id": family_id,
		"rank": rank,
		"source_v04_card_id": source_v04_card_id,
		"name_key": name_key,
		"rules_key": rules_key,
		"short_effect_key": short_effect_key,
		"assistive_name_key": assistive_name_key,
		"requirements": requirement_snapshots,
		"migration_status": migration_status,
		"blocking_reason": blocking_reason,
		"release_ready": release_ready,
		"public_pool": public_pool,
	}
