extends RefCounted
class_name PlayerTextCatalogValidatorV05

const PlayerTextSpecScript := preload("res://scripts/presentation/player_text_spec_v05.gd")


static func validate(catalog: Resource) -> Dictionary:
	var errors: Array[String] = []
	if catalog == null:
		return {"valid": false, "errors": ["catalog_missing"], "entry_count": 0}
	if str(catalog.schema_version) != "v0.5":
		errors.append("schema_version_invalid")
	if str(catalog.default_locale) != "zh_Hans":
		errors.append("default_locale_invalid")
	var seen: Dictionary = {}
	for entry in catalog.entries:
		if entry == null:
			errors.append("entry_missing")
			continue
		var message_key := str(entry.message_key)
		if not PlayerTextSpecScript.is_stable_ascii_id(message_key):
			errors.append("message_key_invalid:%s" % message_key)
		elif seen.has(message_key):
			errors.append("message_key_duplicate:%s" % message_key)
		else:
			seen[message_key] = true
		if not PlayerTextSpecScript.ALLOWED_AUDIENCES.has(str(entry.audience)):
			errors.append("audience_invalid:%s" % message_key)
		if str(entry.owner).strip_edges().is_empty() or str(entry.translation_context).strip_edges().is_empty():
			errors.append("metadata_incomplete:%s" % message_key)
		if int(entry.character_budget) <= 0:
			errors.append("character_budget_invalid:%s" % message_key)
		for arg_key_variant in entry.argument_types.keys():
			var arg_key := str(arg_key_variant)
			var arg_type := str(entry.argument_types[arg_key_variant])
			if not PlayerTextSpecScript.is_stable_ascii_id(arg_key) or not PlayerTextSpecScript.ALLOWED_ARGUMENT_TYPES.has(arg_type):
				errors.append("argument_schema_invalid:%s:%s" % [message_key, arg_key])
	if not seen.has(str(catalog.safe_fallback_key)):
		errors.append("safe_fallback_missing")
	for entry in catalog.entries:
		if entry != null and not str(entry.assistive_message_key).is_empty() and not seen.has(str(entry.assistive_message_key)):
			errors.append("assistive_key_missing:%s" % str(entry.message_key))
	var snapshot: Dictionary = catalog.debug_snapshot()
	if not PlayerTextSpecScript.is_pure_data(snapshot):
		errors.append("catalog_snapshot_not_pure_data")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"entry_count": seen.size(),
		"snapshot": snapshot,
	}
