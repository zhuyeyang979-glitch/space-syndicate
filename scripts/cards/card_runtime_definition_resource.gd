@tool
extends Resource
class_name CardRuntimeDefinitionResource

@export_group("Identity")
@export var card_id := ""
@export var family_id := ""
@export_range(1, 4, 1) var rank := 1
@export var kind: StringName = &""

@export_group("Core authored fields")
@export var purchase_cost := 0
@export_multiline var rules_text := ""
@export var tags := PackedStringArray()
@export var move := 0.0
@warning_ignore("shadowed_global_identifier")
@export var range := 0.0
@export var damage := 0
@export var persistent := false
@export var consumed_on_queue := false

@export_group("Requirements")
@export var play_requirement_kind: StringName = &""
@export var play_region_scope: StringName = &""
@export var play_region_gdp_share_required := 0
@export var play_product := ""
@export var play_flow_required := 0
@export var supply_product := ""
@export var starter_play_free := false

@export_group("Targets")
@export var target_player_required := false
@export var target_monster_required := false
@export var summon_access: StringName = &""
@export var military_deploy_terrain: StringName = &""
@export var contract_product_mode: StringName = &""
@export var card_access_global := false

@export_group("Sparse authored shape")
@export var authored_keys := PackedStringArray()
@export var integer_core_fields := PackedStringArray()
@export var effect_parameters: Dictionary = {}


func to_dictionary() -> Dictionary:
	var result: Dictionary = {}
	for key_variant in authored_keys:
		var key := str(key_variant)
		result[key] = _authored_value(key)
	return result.duplicate(true)


func debug_snapshot() -> Dictionary:
	return {
		"card_id": card_id,
		"family_id": family_id,
		"rank": rank,
		"kind": str(kind),
		"authored_keys": Array(authored_keys),
		"definition": to_dictionary(),
	}


func _authored_value(key: String) -> Variant:
	match key:
		"kind": return str(kind)
		"cost": return purchase_cost
		"text": return rules_text
		"tags": return Array(tags)
		"move":
			if integer_core_fields.has("move"):
				return int(move)
			return move
		"range":
			if integer_core_fields.has("range"):
				return int(range)
			return range
		"damage": return damage
		"persistent": return persistent
		"consumed_on_queue": return consumed_on_queue
		"play_requirement_kind": return str(play_requirement_kind)
		"play_region_scope": return str(play_region_scope)
		"play_region_gdp_share_required": return play_region_gdp_share_required
		"play_product": return play_product
		"play_flow_required": return play_flow_required
		"supply_product": return supply_product
		"starter_play_free": return starter_play_free
		"target_player_required": return target_player_required
		"target_monster_required": return target_monster_required
		"summon_access": return str(summon_access)
		"military_deploy_terrain": return str(military_deploy_terrain)
		"contract_product_mode": return str(contract_product_mode)
		"card_access_global": return card_access_global
	return effect_parameters.get(key)
