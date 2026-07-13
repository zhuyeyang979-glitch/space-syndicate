extends RefCounted
class_name PlayerTextLocaleResolverV05

const PlayerTextSpecScript := preload("res://scripts/presentation/player_text_spec_v05.gd")
const VisibilityContractScript := preload("res://scripts/presentation/player_text_visibility_contract_v05.gd")


func resolve(
	spec: Dictionary,
	viewer_context: Dictionary,
	catalog: Resource,
	unit_catalog: Resource,
	locale: String = "zh_Hans",
	release_mode: bool = true
) -> Dictionary:
	var validation := PlayerTextSpecScript.validate_spec(spec, catalog, release_mode)
	if not bool(validation.get("valid", false)):
		return _safe_fallback(catalog, locale, "spec_invalid:%s" % ",".join(validation.get("errors", [])))
	var normalized_spec: Dictionary = validation.get("normalized_spec", {}) as Dictionary
	var authorization := VisibilityContractScript.authorize(normalized_spec, viewer_context)
	if not bool(authorization.get("allowed", false)):
		return {
			"visible": false,
			"text": "",
			"assistive_text": "",
			"used_safe_fallback": false,
			"diagnostic_code": str(authorization.get("reason", "visibility_denied")),
			"resolved_locale": locale,
		}
	var authorized_spec: Dictionary = authorization.get("authorized_spec", {}) as Dictionary
	var entry: Dictionary = catalog.call("entry_snapshot", str(authorized_spec.get("message_key", "")))
	var formatted_args := _format_args(authorized_spec.get("args", {}) as Dictionary, entry.get("argument_types", {}) as Dictionary, unit_catalog, locale, str(entry.get("translation_context", "")))
	if not bool(formatted_args.get("valid", false)):
		return _safe_fallback(catalog, locale, str(formatted_args.get("reason", "format_failed")))
	var args: Dictionary = formatted_args.get("args", {}) as Dictionary
	var text_template := _translated(str(entry.get("message_key", "")), str(entry.get("translation_context", "")), locale)
	if text_template.is_empty() or text_template == str(entry.get("message_key", "")):
		return _safe_fallback(catalog, locale, "translation_missing")
	var text := text_template.format(args)
	var assistive_key := str(authorized_spec.get("assistive_message_key", ""))
	if assistive_key.is_empty():
		assistive_key = str(entry.get("assistive_message_key", ""))
	var assistive_text := text
	if not assistive_key.is_empty():
		var assistive_template := _translated(assistive_key, str(entry.get("translation_context", "")), locale)
		if not assistive_template.is_empty() and assistive_template != assistive_key:
			assistive_text = assistive_template.format(args)
	return {
		"visible": true,
		"text": text,
		"assistive_text": assistive_text,
		"used_safe_fallback": false,
		"diagnostic_code": "",
		"resolved_locale": locale,
	}


func pseudolocalize_for_qa(text: String, expansion_ratio: float = 0.5) -> String:
	var transformed := ""
	var literal_start := 0
	var cursor := 0
	while cursor < text.length():
		if text[cursor] != "{":
			cursor += 1
			continue
		var closing_brace := text.find("}", cursor + 1)
		if closing_brace < 0:
			break
		transformed += _pseudolocalize_literal(text.substr(literal_start, cursor - literal_start))
		transformed += text.substr(cursor, closing_brace - cursor + 1)
		cursor = closing_brace + 1
		literal_start = cursor
	transformed += _pseudolocalize_literal(text.substr(literal_start))
	var padding_count := ceili(float(text.length()) * clampf(expansion_ratio, 0.0, 2.0))
	return "[[%s%s]]" % [transformed, "~".repeat(padding_count)]


func _pseudolocalize_literal(text: String) -> String:
	var transformed := text
	var replacements := {"a": "á", "e": "ë", "i": "ï", "o": "õ", "u": "ü", "A": "Á", "E": "Ë", "I": "Ï", "O": "Õ", "U": "Ü"}
	for source in replacements:
		transformed = transformed.replace(str(source), str(replacements[source]))
	return transformed


func _format_args(raw_args: Dictionary, argument_types: Dictionary, unit_catalog: Resource, locale: String, context: String) -> Dictionary:
	var result: Dictionary = {}
	for key_variant in argument_types.keys():
		var key := str(key_variant)
		var type_id := str(argument_types[key_variant])
		var value: Variant = raw_args.get(key)
		match type_id:
			"localized_key":
				var localized := _translated(str(value), context, locale)
				if localized.is_empty() or localized == str(value):
					return {"valid": false, "reason": "localized_argument_missing:%s" % key, "args": {}}
				result[key] = localized
			"currency_cents", "basis_points", "seconds", "gdp_per_minute":
				if unit_catalog == null or not unit_catalog.has_method("entry_for_id"):
					return {"valid": false, "reason": "unit_catalog_missing", "args": {}}
				var unit_entry: Resource = unit_catalog.call("entry_for_id", type_id)
				if unit_entry == null:
					return {"valid": false, "reason": "unit_missing:%s" % type_id, "args": {}}
				var number_text := str(unit_catalog.call("format_numeric_value", int(value), type_id))
				var suffix := _translated(str(unit_entry.get("suffix_message_key")), context, locale)
				var separator := " " if bool(unit_entry.get("join_with_space")) else ""
				result[key] = number_text + separator + suffix
			_:
				result[key] = value
	return {"valid": true, "reason": "", "args": result}


func _safe_fallback(catalog: Resource, locale: String, diagnostic_code: String) -> Dictionary:
	var fallback_key := "ui.error.generic_safe"
	var context := "player_text_v05"
	if catalog != null:
		fallback_key = str(catalog.safe_fallback_key)
		var fallback_entry: Dictionary = catalog.call("entry_snapshot", fallback_key)
		context = str(fallback_entry.get("translation_context", context))
	var fallback_text := _translated(fallback_key, context, locale)
	if fallback_text.is_empty() or fallback_text == fallback_key:
		fallback_text = "暂时无法显示这项信息。请返回后重试。"
	return {
		"visible": true,
		"text": fallback_text,
		"assistive_text": fallback_text,
		"used_safe_fallback": true,
		"diagnostic_code": diagnostic_code,
		"resolved_locale": locale,
	}


func _translated(message_key: String, context: String, locale: String) -> String:
	var previous_locale := TranslationServer.get_locale()
	if not locale.is_empty() and locale != previous_locale:
		TranslationServer.set_locale(locale)
	var translated := str(TranslationServer.translate(message_key, context))
	if TranslationServer.get_locale() != previous_locale:
		TranslationServer.set_locale(previous_locale)
	return translated
