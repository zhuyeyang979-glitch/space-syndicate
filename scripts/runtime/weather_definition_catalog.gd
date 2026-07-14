@tool
extends Resource
class_name WeatherDefinitionCatalog

@export var definitions: Array[Resource] = []


func definition_ids() -> Array:
	var ids: Array = []
	for definition in _valid_definition_resources():
		ids.append(definition.id)
	return ids


func has_definition(type_id: String) -> bool:
	return definition(type_id) != null


func definition(type_id: String) -> WeatherDefinition:
	for definition in _valid_definition_resources():
		if definition.id == type_id:
			return definition
	return null


func first_definition() -> WeatherDefinition:
	var valid := _valid_definition_resources()
	return valid[0] if not valid.is_empty() else null


func snapshot() -> Dictionary:
	var result := {}
	for definition in _valid_definition_resources():
		result[definition.id] = definition.to_dictionary()
	return result


func validate_catalog() -> Dictionary:
	var ids := {}
	var errors: Array[String] = []
	var valid_count := 0
	for index in range(definitions.size()):
		var definition := definitions[index] as WeatherDefinition
		if definition == null:
			errors.append("definition_%d_invalid_resource" % index)
			continue
		valid_count += 1
		if ids.has(definition.id):
			errors.append("definition_%s_duplicate" % definition.id)
		ids[definition.id] = true
		for error in definition.validation_errors():
			errors.append("%s:%s" % [definition.id, error])
	return {
		"valid": errors.is_empty() and valid_count == 6,
		"definition_count": valid_count,
		"errors": errors,
		"definition_ids": definition_ids(),
	}


func _valid_definition_resources() -> Array[WeatherDefinition]:
	var result: Array[WeatherDefinition] = []
	for resource in definitions:
		var definition := resource as WeatherDefinition
		if definition != null:
			result.append(definition)
	return result
