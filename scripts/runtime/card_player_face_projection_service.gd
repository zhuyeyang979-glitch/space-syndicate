@tool
extends Node
class_name CardPlayerFaceProjectionService

const PlayerFaceDTO := preload("res://scripts/presentation/player_face_dto_v1.gd")
const CardSemanticSchema := preload("res://scripts/cards/semantic/card_semantic_schema_v1.gd")

const SCHEMA_VERSION := 1

const LOCALIZATION_ROOT_FIELDS := [
	"schema_version",
	"source_id",
	"card_id",
	"semantic_fingerprint",
	"authorization_scope_id",
	"authorization_revision",
	"authorized",
	"message_ids",
	"target_message_rows",
	"condition_message_rows",
	"effect_step_message_rows",
	"keyword_rows",
]
const LOCALIZATION_MESSAGE_FIELDS := [
	"name",
	"family_name",
	"acquisition_cost",
	"activation_cost",
	"timing",
	"duration",
	"counterability",
	"information_scope",
]
const LOCALIZATION_FORBIDDEN_KEYS := [
	"text",
	"raw_text",
	"localized_text",
	"raw_name",
	"description",
	"rules_text",
	"effect",
	"tooltip",
	"color",
	"icon",
	"hidden_owner",
	"private_owner",
	"owner_id",
	"actor_id",
	"private_target",
	"private_discard",
	"exact_cash",
	"hand_cards",
	"quote_id",
	"quote_key",
	"quote_fingerprint",
	"future_supply_order",
	"ai_plan",
	"ai_score",
	"developer",
]
const DURATION_DESCRIPTOR_TYPE_BY_PARAMETER_ID := {
	"duration_seconds": "seconds",
	"counter_window_seconds": "seconds",
	"persistence_id": "stable_id",
}
const TYPED_ARGUMENT_TYPE_BY_FIELD_ID := {
	"purchase_cash": "cash",
	"target_cash_penalty": "cash",
	"steal_fail_cash": "cash",
	"refund_cash": "cash",
	"life": "asset_units",
	"energy": "asset_units",
	"industry": "asset_units",
	"technology": "asset_units",
	"commerce": "asset_units",
	"shipping": "asset_units",
	"generic": "asset_units",
	"duration_seconds": "seconds",
	"counter_window_seconds": "seconds",
	"count": "count",
	"private_trace_count": "count",
	"rate_units_per_minute": "rate",
	"production_capacity_units_per_minute": "rate",
	"demand_capacity_units_per_minute": "rate",
	"throughput_units_per_minute": "rate",
	"inbound_throughput_units_per_minute": "rate",
	"outbound_throughput_units_per_minute": "rate",
}


func project(semantic_spec: Dictionary, localization_source: Dictionary, surface_id: String) -> Dictionary:
	var report := project_report(semantic_spec, localization_source, surface_id)
	if not bool(report.get("accepted", false)):
		return {}
	return (report.get("dto", {}) as Dictionary).duplicate(true)


func project_report(semantic_spec: Dictionary, localization_source: Dictionary, surface_id: String) -> Dictionary:
	if not PlayerFaceDTO.SURFACE_IDS.has(surface_id):
		return _rejected("player_face_projection.surface_invalid")
	if not PlayerFaceDTO.is_detached_pure_data(localization_source):
		return _rejected("player_face_projection.localization_not_detached_pure_data")

	# Authorization is intentionally checked before any localization identifier is read.
	var privacy_report := _localization_privacy_report(localization_source)
	if not bool(privacy_report.get("valid", false)):
		return _rejected(str(privacy_report.get("reason_id", "player_face_projection.localization_denied")))

	var semantic_report := _semantic_report(semantic_spec)
	if not bool(semantic_report.get("valid", false)):
		return _rejected(str(semantic_report.get("reason_id", "player_face_projection.semantic_invalid")))
	var localization_report := _localization_structure_report(localization_source, semantic_spec)
	if not bool(localization_report.get("valid", false)):
		return _rejected(str(localization_report.get("reason_id", "player_face_projection.localization_invalid")))

	var profile := PlayerFaceDTO.surface_profile(surface_id)
	var identity: Dictionary = semantic_spec.get("identity", {}) as Dictionary
	var cost: Dictionary = semantic_spec.get("cost", {}) as Dictionary
	var acquisition: Dictionary = cost.get("acquisition", {}) as Dictionary
	var activation: Dictionary = cost.get("activation", {}) as Dictionary
	var asset_cost: Dictionary = activation
	var timing: Dictionary = semantic_spec.get("timing", {}) as Dictionary
	var target := _normalized_target(semantic_spec.get("target", {}) as Dictionary)
	var effect_ops: Array = semantic_spec.get("effect_ops", []) as Array
	var response: Dictionary = semantic_spec.get("response", {}) as Dictionary
	var information_policy: Dictionary = semantic_spec.get("information_policy", {}) as Dictionary
	var messages: Dictionary = localization_source.get("message_ids", {}) as Dictionary
	var condition_descriptors := _condition_descriptors(target, effect_ops)

	var target_rows: Array = []
	var target_message_rows: Array = localization_source.get("target_message_rows", []) as Array
	var target_message: Dictionary = target_message_rows[0] as Dictionary
	target_rows.append({
		"target_id": str(target.get("target_id", "")),
		"selection_id": str(target.get("selection_id", "")),
		"cardinality_id": str(target.get("cardinality_id", "")),
		"filter_ids": (target.get("filter_ids", []) as Array).duplicate(true),
		"message_ref": _message_ref(str(target_message.get("message_id", "")), _typed_args_from_dictionary(target)),
		"emphasis_id": _profile_emphasis(profile, "targets"),
	})

	var condition_rows: Array = []
	var condition_message_rows: Array = localization_source.get("condition_message_rows", []) as Array
	for index in range(condition_descriptors.size()):
		var descriptor: Dictionary = condition_descriptors[index] as Dictionary
		var message_row: Dictionary = condition_message_rows[index] as Dictionary
		condition_rows.append({
			"condition_id": str(descriptor.get("condition_id", "")),
			"source_id": str(descriptor.get("source_id", "")),
			"message_ref": _message_ref(str(message_row.get("message_id", "")), _typed_args_from_dictionary(descriptor)),
			"emphasis_id": _profile_emphasis(profile, "conditions"),
		})

	var effect_steps: Array = []
	var effect_message_rows: Array = localization_source.get("effect_step_message_rows", []) as Array
	for index in range(effect_ops.size()):
		var effect_op: Dictionary = effect_ops[index] as Dictionary
		var effect_message: Dictionary = effect_message_rows[index] as Dictionary
		var order := index + 1
		var op_id := str(effect_op.get("op_id", ""))
		var step_id := "step.%d.%s" % [order, op_id]
		var parameters := _typed_args_from_dictionary(effect_op, ["op_id"])
		effect_steps.append({
			"order": order,
			"step_id": step_id,
			"op_id": op_id,
			"target_id": str(target.get("target_id", "")),
			"parameters": parameters,
			"summary_ref": _message_ref(str(effect_message.get("summary_message_id", "")), parameters),
			"detail_ref": _message_ref(str(effect_message.get("detail_message_id", "")), parameters),
			"emphasis_id": _profile_emphasis(profile, "effect_steps"),
		})

	var duration_components := _duration_components(effect_ops)
	var duration_args: Array = []
	for component_variant in duration_components:
		var component: Dictionary = component_variant
		duration_args.append({
			"arg_id": "%s.%s" % [str(component.get("step_id", "")), str(component.get("parameter_id", ""))],
			"type_id": str(component.get("type_id", "")),
			"value": component.get("value"),
		})

	var acquisition_args: Array = [
		_typed_arg("acquisition_kind", "stable_id", str(acquisition.get("acquisition_kind", ""))),
		_typed_arg("purchase_cash", "cash", int(acquisition.get("purchase_cash", 0))),
	]
	var activation_args: Array = []
	for asset_id in PlayerFaceDTO.ASSET_COST_FIELDS:
		activation_args.append(_typed_arg(str(asset_id), "asset_units", int(asset_cost.get(asset_id, 0))))

	var keyword_rows: Array = []
	for keyword_variant in localization_source.get("keyword_rows", []) as Array:
		var keyword: Dictionary = keyword_variant
		keyword_rows.append({
			"keyword_id": str(keyword.get("keyword_id", "")),
			"label_ref": _message_ref(str(keyword.get("label_message_id", "")), []),
			"tooltip_ref": _message_ref(str(keyword.get("tooltip_message_id", "")), []),
			"icon_token_id": str(keyword.get("icon_token_id", "")),
			"color_token_id": str(keyword.get("color_token_id", "")),
		})

	var unsealed_dto := {
		"schema_version": SCHEMA_VERSION,
		"card_id": str(identity.get("card_id", "")),
		"family_id": str(identity.get("family_id", "")),
		"rank": int(identity.get("rank", 0)),
		"name_ref": _message_ref(str(messages.get("name", "")), [
			_typed_arg("card_id", "stable_id", str(identity.get("card_id", ""))),
		]),
		"family_name_ref": _message_ref(str(messages.get("family_name", "")), [
			_typed_arg("family_id", "stable_id", str(identity.get("family_id", ""))),
		]),
		"surface_id": surface_id,
		"acquisition_cost": {
			"acquisition_kind": str(acquisition.get("acquisition_kind", "")),
			"purchase_cash": int(acquisition.get("purchase_cash", 0)),
			"message_ref": _message_ref(str(messages.get("acquisition_cost", "")), acquisition_args),
			"emphasis_id": _profile_emphasis(profile, "acquisition_cost"),
		},
		"activation_cost": {
			"asset_cost": asset_cost.duplicate(true),
			"message_ref": _message_ref(str(messages.get("activation_cost", "")), activation_args),
			"emphasis_id": _profile_emphasis(profile, "activation_cost"),
		},
		"timing": {
			"timing_id": str(timing.get("timing_id", "")),
			"message_ref": _message_ref(str(messages.get("timing", "")), _typed_args_from_dictionary(timing)),
			"emphasis_id": _profile_emphasis(profile, "timing"),
		},
		"targets": target_rows,
		"conditions": condition_rows,
		"effect_steps": effect_steps,
		"duration": {
			"duration_id": "effect_defined" if not duration_components.is_empty() else "not_specified",
			"components": duration_components,
			"message_ref": _message_ref(str(messages.get("duration", "")), duration_args),
			"emphasis_id": _profile_emphasis(profile, "duration"),
		},
		"counterability": {
			"response_id": str(response.get("response_id", "")),
			"parameters": _typed_args_from_dictionary(response, ["response_id"]),
			"message_ref": _message_ref(str(messages.get("counterability", "")), _typed_args_from_dictionary(response)),
			"emphasis_id": _profile_emphasis(profile, "counterability"),
		},
		"information_scope": {
			"policy_id": str(information_policy.get("visibility_policy_id", "")),
			"scope_rows": _information_scope_rows(information_policy),
			"message_ref": _message_ref(str(messages.get("information_scope", "")), _typed_args_from_dictionary(information_policy)),
			"emphasis_id": _profile_emphasis(profile, "information_scope"),
		},
		"keywords": keyword_rows,
	}
	var dto := PlayerFaceDTO.seal(unsealed_dto)
	if dto.is_empty():
		return _rejected("player_face_projection.dto_seal_failed")
	return {
		"accepted": true,
		"reason_id": "player_face_projection.accepted",
		"dto": dto,
	}


func surface_profile(surface_id: String) -> Dictionary:
	return PlayerFaceDTO.surface_profile(surface_id)


func debug_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"service_id": "card_player_face_projection.v1",
		"stateless": true,
		"cache_entries": 0,
		"owns_rules": false,
		"owns_legality": false,
		"owns_localization": false,
		"owns_save_state": false,
		"uses_rng": false,
		"mutates_game_state": false,
		"localization_authorized_before_resolution": true,
		"semantic_authority_id": "card_semantic_schema_v1",
		"duration_parameter_ids": _duration_parameter_ids(),
		"supported_surface_ids": PlayerFaceDTO.SURFACE_IDS.duplicate(),
	}


func _semantic_report(spec: Dictionary) -> Dictionary:
	var schema_report: Dictionary = CardSemanticSchema.validate_semantic_spec(spec)
	if not bool(schema_report.get("valid", false)):
		return {
			"valid": false,
			"reason_id": "player_face_projection.semantic_schema_rejected",
			"schema_errors": (schema_report.get("errors", []) as Array).duplicate(true),
		}
	return {"valid": true, "reason_id": "player_face_projection.semantic_valid"}


func _localization_privacy_report(source: Dictionary) -> Dictionary:
	var forbidden_key := _first_forbidden_key(source, LOCALIZATION_FORBIDDEN_KEYS)
	if not forbidden_key.is_empty():
		return _invalid("player_face_projection.localization_private_field:%s" % forbidden_key)
	if not (source.get("authorized") is bool) or not bool(source.get("authorized", false)):
		return _invalid("player_face_projection.localization_not_authorized")
	if str(source.get("authorization_scope_id", "")) != "public":
		return _invalid("player_face_projection.localization_scope_violation")
	if not (source.get("authorization_revision") is int) or int(source.get("authorization_revision")) <= 0:
		return _invalid("player_face_projection.localization_authorization_revision_invalid")
	return {"valid": true, "reason_id": "player_face_projection.localization_authorized"}


func _localization_structure_report(source: Dictionary, semantic_spec: Dictionary) -> Dictionary:
	if not _has_exact_fields(source, LOCALIZATION_ROOT_FIELDS):
		return _invalid("player_face_projection.localization_root_fields_invalid")
	if not (source.get("schema_version") is int) or int(source.get("schema_version")) != SCHEMA_VERSION:
		return _invalid("player_face_projection.localization_schema_invalid")
	if not PlayerFaceDTO.is_stable_id(str(source.get("source_id", ""))):
		return _invalid("player_face_projection.localization_source_id_invalid")
	var identity: Dictionary = semantic_spec.get("identity", {}) as Dictionary
	if str(source.get("card_id", "")) != str(identity.get("card_id", "")):
		return _invalid("player_face_projection.localization_card_binding_mismatch")
	if str(source.get("semantic_fingerprint", "")) != str(semantic_spec.get("semantic_fingerprint", "")):
		return _invalid("player_face_projection.localization_semantic_binding_mismatch")

	var messages_value: Variant = source.get("message_ids")
	if not (messages_value is Dictionary):
		return _invalid("player_face_projection.localization_message_ids_invalid")
	var messages: Dictionary = messages_value
	if not _has_exact_fields(messages, LOCALIZATION_MESSAGE_FIELDS):
		return _invalid("player_face_projection.localization_message_fields_invalid")
	for field_id in LOCALIZATION_MESSAGE_FIELDS:
		if not PlayerFaceDTO.is_stable_id(str(messages.get(field_id, ""))):
			return _invalid("player_face_projection.localization_message_id_invalid")

	var target: Dictionary = _normalized_target(semantic_spec.get("target", {}) as Dictionary)
	var target_rows_error := _target_message_rows_error(source.get("target_message_rows"), target)
	if not target_rows_error.is_empty():
		return _invalid(target_rows_error)
	var effects: Array = semantic_spec.get("effect_ops", []) as Array
	var conditions := _condition_descriptors(target, effects)
	var condition_rows_error := _condition_message_rows_error(source.get("condition_message_rows"), conditions)
	if not condition_rows_error.is_empty():
		return _invalid(condition_rows_error)
	var effect_rows_error := _effect_message_rows_error(source.get("effect_step_message_rows"), effects)
	if not effect_rows_error.is_empty():
		return _invalid(effect_rows_error)
	var keyword_rows_error := _keyword_rows_error(source.get("keyword_rows"))
	if not keyword_rows_error.is_empty():
		return _invalid(keyword_rows_error)
	return {"valid": true, "reason_id": "player_face_projection.localization_valid"}


func _target_message_rows_error(value: Variant, target: Dictionary) -> String:
	if not (value is Array) or (value as Array).size() != 1:
		return "player_face_projection.target_message_rows_invalid"
	var row_value: Variant = (value as Array)[0]
	if not (row_value is Dictionary):
		return "player_face_projection.target_message_row_invalid"
	var row: Dictionary = row_value
	if not _has_exact_fields(row, ["target_id", "message_id"]):
		return "player_face_projection.target_message_fields_invalid"
	if str(row.get("target_id", "")) != str(target.get("target_id", "")):
		return "player_face_projection.target_message_binding_mismatch"
	if not PlayerFaceDTO.is_stable_id(str(row.get("message_id", ""))):
		return "player_face_projection.target_message_id_invalid"
	return ""


func _condition_message_rows_error(value: Variant, descriptors: Array) -> String:
	if not (value is Array) or (value as Array).size() != descriptors.size():
		return "player_face_projection.condition_message_rows_invalid"
	for index in range(descriptors.size()):
		var row_value: Variant = (value as Array)[index]
		if not (row_value is Dictionary):
			return "player_face_projection.condition_message_row_invalid"
		var row: Dictionary = row_value
		var descriptor: Dictionary = descriptors[index] as Dictionary
		if not _has_exact_fields(row, ["condition_id", "message_id"]):
			return "player_face_projection.condition_message_fields_invalid"
		if str(row.get("condition_id", "")) != str(descriptor.get("condition_id", "")):
			return "player_face_projection.condition_message_binding_mismatch"
		if not PlayerFaceDTO.is_stable_id(str(row.get("message_id", ""))):
			return "player_face_projection.condition_message_id_invalid"
	return ""


func _effect_message_rows_error(value: Variant, effects: Array) -> String:
	if not (value is Array) or (value as Array).size() != effects.size():
		return "player_face_projection.effect_message_rows_invalid"
	for index in range(effects.size()):
		var row_value: Variant = (value as Array)[index]
		if not (row_value is Dictionary):
			return "player_face_projection.effect_message_row_invalid"
		var row: Dictionary = row_value
		var effect: Dictionary = effects[index] as Dictionary
		if not _has_exact_fields(row, ["order", "op_id", "summary_message_id", "detail_message_id"]):
			return "player_face_projection.effect_message_fields_invalid"
		if not (row.get("order") is int) or int(row.get("order")) != index + 1:
			return "player_face_projection.effect_message_order_invalid"
		if str(row.get("op_id", "")) != str(effect.get("op_id", "")):
			return "player_face_projection.effect_message_binding_mismatch"
		for field_id in ["summary_message_id", "detail_message_id"]:
			if not PlayerFaceDTO.is_stable_id(str(row.get(field_id, ""))):
				return "player_face_projection.effect_message_id_invalid"
	return ""


func _keyword_rows_error(value: Variant) -> String:
	if not (value is Array) or (value as Array).is_empty() or (value as Array).size() > 16:
		return "player_face_projection.keyword_rows_invalid"
	var seen: Dictionary = {}
	for row_variant in value as Array:
		if not (row_variant is Dictionary):
			return "player_face_projection.keyword_row_invalid"
		var row: Dictionary = row_variant
		if not _has_exact_fields(row, ["keyword_id", "label_message_id", "tooltip_message_id", "icon_token_id", "color_token_id"]):
			return "player_face_projection.keyword_fields_invalid"
		for field_id in ["keyword_id", "label_message_id", "tooltip_message_id", "icon_token_id", "color_token_id"]:
			if not PlayerFaceDTO.is_stable_id(str(row.get(field_id, ""))):
				return "player_face_projection.keyword_identifier_invalid"
		var keyword_id := str(row.get("keyword_id", ""))
		if seen.has(keyword_id):
			return "player_face_projection.keyword_duplicate"
		seen[keyword_id] = true
	return ""


func _normalized_target(target: Dictionary) -> Dictionary:
	return {
		"target_id": str(target.get("target_id", "")),
		"selection_id": str(target.get("selection_id", "")),
		"cardinality_id": str(target.get("cardinality_id", "")),
		"filter_ids": (target.get("filter_ids", []) as Array).duplicate(true),
	}


func _condition_descriptors(target: Dictionary, effects: Array) -> Array:
	var rows: Array = []
	var seen: Dictionary = {}
	for filter_variant in target.get("filter_ids", []) as Array:
		var filter_id := str(filter_variant)
		if not seen.has(filter_id):
			rows.append({"condition_id": filter_id, "source_id": "target.filter"})
			seen[filter_id] = true
	for index in range(effects.size()):
		var effect: Dictionary = effects[index] as Dictionary
		if effect.get("condition_id") is String:
			_append_condition_descriptor(rows, seen, str(effect.get("condition_id", "")), "effect.%d.condition" % (index + 1))
		if effect.get("condition_ids") is Array:
			for condition_variant in effect.get("condition_ids", []) as Array:
				_append_condition_descriptor(rows, seen, str(condition_variant), "effect.%d.condition" % (index + 1))
	return rows


func _append_condition_descriptor(rows: Array, seen: Dictionary, condition_id: String, source_id: String) -> void:
	if condition_id.is_empty() or seen.has(condition_id):
		return
	rows.append({"condition_id": condition_id, "source_id": source_id})
	seen[condition_id] = true


func _duration_components(effects: Array) -> Array:
	var components: Array = []
	for index in range(effects.size()):
		var effect: Dictionary = effects[index] as Dictionary
		var op_id := str(effect.get("op_id", ""))
		var step_id := "step.%d.%s" % [index + 1, op_id]
		var keys: Array[String] = []
		for key_variant in effect.keys():
			if str(key_variant) != "op_id":
				keys.append(str(key_variant))
		keys.sort()
		for key in keys:
			if not DURATION_DESCRIPTOR_TYPE_BY_PARAMETER_ID.has(key):
				continue
			components.append({
				"step_id": step_id,
				"parameter_id": key,
				"type_id": str(DURATION_DESCRIPTOR_TYPE_BY_PARAMETER_ID.get(key, "")),
				"value": effect.get(key),
			})
	return components


func _duration_parameter_ids() -> Array:
	var result: Array[String] = []
	for parameter_id_variant in DURATION_DESCRIPTOR_TYPE_BY_PARAMETER_ID.keys():
		result.append(str(parameter_id_variant))
	result.sort()
	return result


func _information_scope_rows(policy: Dictionary) -> Array:
	var rows: Array = []
	var keys: Array[String] = []
	for key_variant in policy.keys():
		if str(key_variant) != "policy_id":
			keys.append(str(key_variant))
	keys.sort()
	for key in keys:
		var value: Variant = policy.get(key)
		if value is Array:
			for index in range((value as Array).size()):
				rows.append({"scope_id": "%s.%d" % [key, index], "value_id": str((value as Array)[index])})
		else:
			rows.append({"scope_id": key, "value_id": str(value)})
	return rows


func _typed_args_from_dictionary(source: Dictionary, excluded_fields: Array = []) -> Array:
	var rows: Array = []
	var keys: Array[String] = []
	for key_variant in source.keys():
		var key := str(key_variant)
		if not excluded_fields.has(key):
			keys.append(key)
	keys.sort()
	for key in keys:
		_append_typed_args(source.get(key), key, key, rows)
	return rows


func _append_typed_args(value: Variant, path: String, field_id: String, rows: Array) -> void:
	if value is Dictionary:
		var nested: Dictionary = value
		var keys: Array[String] = []
		for key_variant in nested.keys():
			keys.append(str(key_variant))
		keys.sort()
		for key in keys:
			_append_typed_args(nested.get(key), "%s.%s" % [path, key], key, rows)
		return
	if value is Array:
		for index in range((value as Array).size()):
			_append_typed_args((value as Array)[index], "%s.%d" % [path, index], field_id, rows)
		return
	if value == null:
		return
	rows.append(_typed_arg(path, _type_id_for(field_id, value), value))


func _type_id_for(field_id: String, value: Variant) -> String:
	if TYPED_ARGUMENT_TYPE_BY_FIELD_ID.has(field_id):
		return str(TYPED_ARGUMENT_TYPE_BY_FIELD_ID.get(field_id, ""))
	if value is bool:
		return "boolean"
	if value is String:
		return "stable_id"
	if value is float:
		return "number"
	return "integer"


func _typed_arg(arg_id: String, type_id: String, value: Variant) -> Dictionary:
	return {"arg_id": arg_id, "type_id": type_id, "value": value}


func _message_ref(message_id: String, args: Array) -> Dictionary:
	return {"message_id": message_id, "args": args.duplicate(true)}


func _profile_emphasis(profile: Dictionary, section_id: String) -> String:
	var emphasis: Dictionary = profile.get("emphasis_by_section", {}) as Dictionary
	return str(emphasis.get(section_id, ""))


func _first_forbidden_key(value: Variant, forbidden_keys: Array) -> String:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant).to_lower()
			if forbidden_keys.has(key):
				return key
			var nested := _first_forbidden_key((value as Dictionary).get(key_variant), forbidden_keys)
			if not nested.is_empty():
				return nested
	elif value is Array:
		for item in value as Array:
			var nested := _first_forbidden_key(item, forbidden_keys)
			if not nested.is_empty():
				return nested
	return ""


func _has_exact_fields(source: Dictionary, expected_fields: Array) -> bool:
	if source.size() != expected_fields.size():
		return false
	for field_variant in expected_fields:
		if not source.has(str(field_variant)):
			return false
	return true


func _invalid(reason_id: String) -> Dictionary:
	return {"valid": false, "reason_id": reason_id}


func _rejected(reason_id: String) -> Dictionary:
	return {"accepted": false, "reason_id": reason_id, "dto": {}}
