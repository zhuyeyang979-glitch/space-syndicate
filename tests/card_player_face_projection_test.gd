extends SceneTree

const PlayerFaceDTO := preload("res://scripts/presentation/player_face_dto_v1.gd")
const CardSemanticSchema := preload("res://scripts/cards/semantic/card_semantic_schema_v1.gd")
const SERVICE_SCENE := preload("res://scenes/runtime/CardPlayerFaceProjectionService.tscn")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var service := SERVICE_SCENE.instantiate()
	root.add_child(service)
	var semantic := _semantic_spec()
	var localization := _localization_source(semantic)
	var semantic_before := PlayerFaceDTO.fingerprint_value(semantic)
	var localization_before := PlayerFaceDTO.fingerprint_value(localization)
	_expect(bool(CardSemanticSchema.validate_semantic_spec(semantic).get("valid", false)), "fixture is accepted by the shared Card semantic authority")

	var market_report: Dictionary = service.project_report(semantic, localization, "market")
	_expect(bool(market_report.get("accepted", false)), "market projection is accepted")
	var market_dto: Dictionary = market_report.get("dto", {}) as Dictionary
	_expect(bool(PlayerFaceDTO.validate(market_dto).get("valid", false)), "market DTO passes the closed schema")
	_expect(_has_exact_root(market_dto), "DTO root has the exact frozen fields")
	_expect(_identity_refs_are_bound(market_dto), "market carries authorized name and family message refs")
	_expect(not _contains_key(market_dto, ["cost", "price", "play_cost", "effect", "text", "description"]), "DTO emits no legacy aliases")

	var acquisition: Dictionary = market_dto.get("acquisition_cost", {}) as Dictionary
	var activation: Dictionary = market_dto.get("activation_cost", {}) as Dictionary
	var asset_cost: Dictionary = activation.get("asset_cost", {}) as Dictionary
	_expect(int(acquisition.get("purchase_cash", -1)) == 7 and int(asset_cost.get("technology", -1)) == 2, "acquisition and activation costs remain separate")
	_expect(str(acquisition.get("emphasis_id", "")) == "primary" and str(activation.get("emphasis_id", "")) == "secondary", "market emphasizes acquisition cost")

	var hand_dto: Dictionary = service.project(semantic, localization, "hand")
	var detail_dto: Dictionary = service.project(semantic, localization, "detail")
	_expect(not hand_dto.is_empty() and not detail_dto.is_empty(), "hand and detail projections are accepted")
	_expect(_identity_refs_are_bound(hand_dto), "hand carries authorized name and family message refs")
	_expect(_identity_refs_are_bound(detail_dto), "detail carries authorized name and family message refs")
	_expect(str((hand_dto.get("activation_cost", {}) as Dictionary).get("emphasis_id", "")) == "primary" and str((hand_dto.get("acquisition_cost", {}) as Dictionary).get("emphasis_id", "")) == "reference", "hand emphasizes activation cost")
	_expect(str((detail_dto.get("activation_cost", {}) as Dictionary).get("emphasis_id", "")) == "complete" and str((detail_dto.get("acquisition_cost", {}) as Dictionary).get("emphasis_id", "")) == "complete", "detail gives both costs complete emphasis")
	_expect(PlayerFaceDTO.fingerprint_value(_without_surface_metadata(market_dto)) == PlayerFaceDTO.fingerprint_value(_without_surface_metadata(hand_dto)) and PlayerFaceDTO.fingerprint_value(_without_surface_metadata(hand_dto)) == PlayerFaceDTO.fingerprint_value(_without_surface_metadata(detail_dto)), "surface profiles change emphasis only")

	var timing: Dictionary = market_dto.get("timing", {}) as Dictionary
	var targets: Array = market_dto.get("targets", []) as Array
	var conditions: Array = market_dto.get("conditions", []) as Array
	var effect_steps: Array = market_dto.get("effect_steps", []) as Array
	var duration: Dictionary = market_dto.get("duration", {}) as Dictionary
	var counterability: Dictionary = market_dto.get("counterability", {}) as Dictionary
	var information_scope: Dictionary = market_dto.get("information_scope", {}) as Dictionary
	_expect(str(timing.get("timing_id", "")) == "main_action", "timing is structured")
	_expect(targets.size() == 1 and str((targets[0] as Dictionary).get("target_id", "")) == "player.opponent", "target selection is structured")
	_expect(conditions.size() == 1 and str((conditions[0] as Dictionary).get("condition_id", "")) == "hand.discardable", "target filter conditions are structured")
	_expect(effect_steps.size() == 2 and int((effect_steps[0] as Dictionary).get("order", 0)) == 1 and int((effect_steps[1] as Dictionary).get("order", 0)) == 2, "effect steps preserve authored order")
	_expect(str((effect_steps[0] as Dictionary).get("op_id", "")) == "discard_random" and str((effect_steps[1] as Dictionary).get("op_id", "")) == "lock_random", "effect step IDs remain semantic IDs")
	_expect(str(duration.get("duration_id", "")) == "effect_defined" and _duration_has_parameter(duration, "duration_seconds"), "duration exposes typed semantic duration parameters")
	var explicit_duration_components: Array = service._duration_components([{"op_id": "lock_random", "duration_seconds": 5}])
	var heuristic_traps: Array = service._duration_components([{
		"op_id": "lock_random",
		"display_duration_seconds": 5,
		"cooldown_preview": 5,
		"termination_hint": "window.end",
		"persistence_color_token_id": "color.duration",
	}])
	_expect(explicit_duration_components.size() == 1 and str((explicit_duration_components[0] as Dictionary).get("parameter_id", "")) == "duration_seconds", "explicit duration allowlist entries are promoted")
	_expect(heuristic_traps.is_empty(), "unknown duration-looking fields are not promoted")
	var typed_argument_traps: Array = service._typed_args_from_dictionary({"display_cash_bonus": 3, "cooldown_seconds": 4, "speed_rate": 5})
	_expect(_all_typed_args_use(typed_argument_traps, "integer"), "unknown unit-looking fields use primitive integer typing rather than substring inference")
	_expect(str(counterability.get("response_id", "")) == "counterable" and (counterability.get("parameters", []) as Array).is_empty(), "counterability preserves the closed response ID")
	_expect(str(information_scope.get("policy_id", "")) == "authorized_source_only" and (information_scope.get("scope_rows", []) as Array).size() == 1, "information scope is structured")

	var keywords: Array = market_dto.get("keywords", []) as Array
	var first_keyword: Dictionary = keywords[0] as Dictionary
	_expect(keywords.size() == 2 and str(first_keyword.get("keyword_id", "")) == "interaction.hand_disrupt", "keywords use stable keyword IDs")
	_expect(str(first_keyword.get("icon_token_id", "")).begins_with("icon.") and str(first_keyword.get("color_token_id", "")).begins_with("color.") and not str(first_keyword.get("color_token_id", "")).contains("#"), "keywords expose token IDs rather than glyphs or colors")
	_expect(_message_refs_are_typed(market_dto), "message refs contain stable IDs and typed args")
	_expect(not _contains_non_ascii_string(market_dto), "DTO contains identifiers and typed values, not localized prose")

	var repeated_dto: Dictionary = service.project(semantic, localization, "market")
	_expect(str(repeated_dto.get("dto_fingerprint", "")) == str(market_dto.get("dto_fingerprint", "")), "identical inputs produce an identical DTO fingerprint")
	market_dto["acquisition_cost"]["purchase_cash"] = 999
	var detached_dto: Dictionary = service.project(semantic, localization, "market")
	_expect(int((detached_dto.get("acquisition_cost", {}) as Dictionary).get("purchase_cash", -1)) == 7, "returned DTOs are detached copies")
	_expect(PlayerFaceDTO.fingerprint_value(semantic) == semantic_before and PlayerFaceDTO.fingerprint_value(localization) == localization_before, "projection does not mutate either input")

	var private_source := localization.duplicate(true)
	private_source["authorization_scope_id"] = "viewer_private"
	private_source["message_ids"]["timing"] = "\u65f6\u673a"
	var private_report: Dictionary = service.project_report(semantic, private_source, "hand")
	_expect(str(private_report.get("reason_id", "")) == "player_face_projection.localization_scope_violation", "privacy filtering runs before localization ID validation")
	var unauthorized_source := localization.duplicate(true)
	unauthorized_source["authorized"] = false
	_expect(str(service.project_report(semantic, unauthorized_source, "market").get("reason_id", "")) == "player_face_projection.localization_not_authorized", "unauthorized localization sources fail closed")
	var hidden_source := localization.duplicate(true)
	hidden_source["keyword_rows"][0]["hidden_owner"] = "seat.2"
	_expect(str(service.project_report(semantic, hidden_source, "market").get("reason_id", "")).begins_with("player_face_projection.localization_private_field"), "hidden localization fields are rejected before use")
	var raw_name_source := localization.duplicate(true)
	raw_name_source["message_ids"]["name"] = "Blackout Protocol"
	_expect(str(service.project_report(semantic, raw_name_source, "market").get("reason_id", "")) == "player_face_projection.localization_message_id_invalid", "raw player-facing names are rejected in favor of stable message IDs")

	var wrong_card_source := localization.duplicate(true)
	wrong_card_source["card_id"] = "interaction.other.rank_1"
	_expect(str(service.project_report(semantic, wrong_card_source, "market").get("reason_id", "")) == "player_face_projection.localization_card_binding_mismatch", "localization card binding is enforced")
	var wrong_semantic_source := localization.duplicate(true)
	wrong_semantic_source["semantic_fingerprint"] = "b".repeat(64)
	_expect(str(service.project_report(semantic, wrong_semantic_source, "market").get("reason_id", "")) == "player_face_projection.localization_semantic_binding_mismatch", "localization semantic binding is enforced")

	var extra_semantic := semantic.duplicate(true)
	extra_semantic["price"] = 7
	_reseal_semantic(extra_semantic)
	_expect(str(service.project_report(extra_semantic, localization, "market").get("reason_id", "")) == "player_face_projection.semantic_schema_rejected", "shared schema rejects unknown semantic root fields")
	var unknown_op := semantic.duplicate(true)
	unknown_op["effect_ops"][0]["op_id"] = "invent_rule_from_text"
	_reseal_semantic(unknown_op)
	_expect(str(service.project_report(unknown_op, localization, "market").get("reason_id", "")) == "player_face_projection.semantic_schema_rejected", "shared schema rejects unknown effect operations")
	var forged_semantic := semantic.duplicate(true)
	forged_semantic["identity"]["rank"] = 4
	_expect(str(service.project_report(forged_semantic, localization, "market").get("reason_id", "")) == "player_face_projection.semantic_schema_rejected", "shared schema rejects semantic fingerprint forgery")
	var nonfinite_semantic := semantic.duplicate(true)
	nonfinite_semantic["effect_ops"][0]["count"] = NAN
	_expect(str(service.project_report(nonfinite_semantic, localization, "market").get("reason_id", "")) == "player_face_projection.semantic_schema_rejected", "shared schema rejects non-finite semantic values")

	var runtime_node := Node.new()
	var object_semantic := semantic.duplicate(true)
	object_semantic["identity"]["runtime_node"] = runtime_node
	_expect(str(service.project_report(object_semantic, localization, "market").get("reason_id", "")) == "player_face_projection.semantic_schema_rejected", "shared schema rejects runtime objects at the semantic boundary")
	runtime_node.free()
	var callback_source := localization.duplicate(true)
	callback_source["callback"] = Callable(self, "_run")
	_expect(str(service.project_report(semantic, callback_source, "market").get("reason_id", "")) == "player_face_projection.localization_not_detached_pure_data", "callables cannot cross the localization boundary")

	var invalid_dto := detached_dto.duplicate(true)
	invalid_dto["price"] = 7
	_expect(str(PlayerFaceDTO.validate(invalid_dto).get("reason_id", "")) == "dto_root_fields_invalid", "DTO validation rejects unknown fields")
	var tampered_dto := detached_dto.duplicate(true)
	tampered_dto["dto_fingerprint"] = "0".repeat(64)
	_expect(str(PlayerFaceDTO.validate(tampered_dto).get("reason_id", "")) == "dto_fingerprint_mismatch", "DTO fingerprint tampering is rejected")
	var unordered_source := localization.duplicate(true)
	unordered_source["effect_step_message_rows"][1]["order"] = 1
	_expect(str(service.project_report(semantic, unordered_source, "market").get("reason_id", "")) == "player_face_projection.effect_message_order_invalid", "localization effect rows must match semantic order")
	var duplicate_keyword_source := localization.duplicate(true)
	duplicate_keyword_source["keyword_rows"][1]["keyword_id"] = "interaction.hand_disrupt"
	_expect(str(service.project_report(semantic, duplicate_keyword_source, "market").get("reason_id", "")) == "player_face_projection.keyword_duplicate", "keyword IDs must be unique")
	var missing_message_source := localization.duplicate(true)
	missing_message_source["message_ids"].erase("duration")
	_expect(str(service.project_report(semantic, missing_message_source, "market").get("reason_id", "")) == "player_face_projection.localization_message_fields_invalid", "missing localization identifiers fail closed")
	_expect(service.project(semantic, localization, "codex").is_empty(), "unsupported surfaces fail closed")

	var market_profile: Dictionary = service.surface_profile("market")
	var hand_profile: Dictionary = service.surface_profile("hand")
	var detail_profile: Dictionary = service.surface_profile("detail")
	_expect(str(market_profile.get("profile_id", "")) == "market_acquisition" and str(hand_profile.get("profile_id", "")) == "hand_activation" and str(detail_profile.get("profile_id", "")) == "detail_complete", "three stable emphasis profiles are available")
	var debug: Dictionary = service.debug_snapshot()
	_expect(bool(debug.get("stateless", false)) and int(debug.get("cache_entries", -1)) == 0 and not bool(debug.get("owns_rules", true)) and not bool(debug.get("owns_legality", true)) and not bool(debug.get("owns_save_state", true)) and not bool(debug.get("uses_rng", true)) and not bool(debug.get("mutates_game_state", true)), "service owns no rules, legality, persistence, RNG, cache, or mutation")
	_expect(str(debug.get("semantic_authority_id", "")) == "card_semantic_schema_v1", "debug boundary identifies the shared semantic authority")
	_expect(debug.get("duration_parameter_ids", []) == ["counter_window_seconds", "duration_seconds", "persistence_id"], "duration promotion exposes one exact closed descriptor list")
	_expect(_source_dependencies_are_clean(), "new production scripts have no Main, RNG, timers, or current-scene dependency")
	_expect(_semantic_authority_is_delegated(), "PlayerFace service has zero duplicated Card semantic schema tables")

	var started_usec := Time.get_ticks_usec()
	var accepted_count := 0
	for index in range(600):
		var surface_id: String = PlayerFaceDTO.SURFACE_IDS[index % PlayerFaceDTO.SURFACE_IDS.size()]
		if not service.project(semantic, localization, surface_id).is_empty():
			accepted_count += 1
	var elapsed_usec := Time.get_ticks_usec() - started_usec
	_expect(accepted_count == 600 and elapsed_usec < 5000000, "600 bounded projections complete under five seconds")

	service.free()
	if _failures.is_empty():
		print("CARD_PLAYER_FACE_PROJECTION_TEST|status=PASS|checks=%d|projections=600|elapsed_usec=%d" % [_checks, elapsed_usec])
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("CARD_PLAYER_FACE_PROJECTION_TEST|status=FAIL|checks=%d|failures=%d" % [_checks, _failures.size()])
		quit(1)


func _semantic_spec() -> Dictionary:
	var spec := {
		"schema_version": 1,
		"source_catalog_id": "space_syndicate.card_runtime_catalog.v06",
		"source_definition_fingerprint": "a".repeat(64),
		"semantic_fingerprint": "",
		"identity": {
			"card_id": "interaction.blackout.rank_2",
			"family_id": "interaction.blackout",
			"rank": 2,
			"category_id": "interaction",
			"available_for_acquisition": true,
		},
		"cost": {
			"acquisition": {"acquisition_kind": "region_rack_cash", "purchase_cash": 7},
			"activation": {
				"life": 0,
				"energy": 1,
				"industry": 0,
				"technology": 2,
				"commerce": 0,
				"shipping": 0,
				"generic": 1,
			},
		},
		"timing": {"timing_id": "main_action"},
		"target": {
			"target_id": "player.opponent",
			"selection_id": "actor_choice",
			"cardinality_id": "exactly_one",
			"filter_ids": ["hand.discardable"],
		},
		"effect_ops": [
			{"op_id": "discard_random", "count": 1, "target_cash_penalty": 0},
			{"op_id": "lock_random", "duration_seconds": 5},
		],
		"response": {"response_id": "counterable"},
		"information_policy": {"visibility_policy_id": "authorized_source_only"},
		"runtime_readiness_id": "projection_only",
	}
	_reseal_semantic(spec)
	return spec


func _localization_source(semantic: Dictionary) -> Dictionary:
	return {
		"schema_version": 1,
		"source_id": "player_face.interaction.blackout.rank_2.zh_hans",
		"card_id": "interaction.blackout.rank_2",
		"semantic_fingerprint": str(semantic.get("semantic_fingerprint", "")),
		"authorization_scope_id": "public",
		"authorization_revision": 1,
		"authorized": true,
		"message_ids": {
			"name": "card.name.interaction.blackout.rank_2",
			"family_name": "card.family.interaction.blackout",
			"acquisition_cost": "card.cost.acquisition.region_rack_cash",
			"activation_cost": "card.cost.activation.assets",
			"timing": "card.timing.main_action",
			"duration": "card.duration.effect_defined",
			"counterability": "card.counterability.counterable",
			"information_scope": "card.information.anonymous_direct_interaction",
		},
		"target_message_rows": [
			{"target_id": "player.opponent", "message_id": "card.target.player.opponent"},
		],
		"condition_message_rows": [
			{"condition_id": "hand.discardable", "message_id": "card.condition.hand.discardable"},
		],
		"effect_step_message_rows": [
			{"order": 1, "op_id": "discard_random", "summary_message_id": "card.effect.discard_random.summary", "detail_message_id": "card.effect.discard_random.detail"},
			{"order": 2, "op_id": "lock_random", "summary_message_id": "card.effect.lock_random.summary", "detail_message_id": "card.effect.lock_random.detail"},
		],
		"keyword_rows": [
			{"keyword_id": "interaction.hand_disrupt", "label_message_id": "card.keyword.interaction.hand_disrupt.label", "tooltip_message_id": "card.keyword.interaction.hand_disrupt.tooltip", "icon_token_id": "icon.card.hand_disrupt", "color_token_id": "color.card.interaction"},
			{"keyword_id": "response.counterable", "label_message_id": "card.keyword.response.counterable.label", "tooltip_message_id": "card.keyword.response.counterable.tooltip", "icon_token_id": "icon.card.counterable", "color_token_id": "color.card.response"},
		],
	}


func _reseal_semantic(spec: Dictionary) -> void:
	spec["semantic_fingerprint"] = CardSemanticSchema.fingerprint(spec, "semantic_fingerprint")


func _has_exact_root(dto: Dictionary) -> bool:
	if dto.size() != PlayerFaceDTO.ROOT_FIELDS.size():
		return false
	for field_id in PlayerFaceDTO.ROOT_FIELDS:
		if not dto.has(field_id):
			return false
	return true


func _identity_refs_are_bound(dto: Dictionary) -> bool:
	var name_ref: Dictionary = dto.get("name_ref", {}) as Dictionary
	var family_name_ref: Dictionary = dto.get("family_name_ref", {}) as Dictionary
	var name_args: Array = name_ref.get("args", []) as Array
	var family_args: Array = family_name_ref.get("args", []) as Array
	if not PlayerFaceDTO.is_stable_id(str(name_ref.get("message_id", ""))) \
			or not PlayerFaceDTO.is_stable_id(str(family_name_ref.get("message_id", ""))) \
			or name_args.size() != 1 \
			or family_args.size() != 1:
		return false
	var name_binding: Dictionary = name_args[0] as Dictionary
	var family_binding: Dictionary = family_args[0] as Dictionary
	return str(name_binding.get("arg_id", "")) == "card_id" \
		and str(name_binding.get("type_id", "")) == "stable_id" \
		and str(name_binding.get("value", "")) == str(dto.get("card_id", "")) \
		and str(family_binding.get("arg_id", "")) == "family_id" \
		and str(family_binding.get("type_id", "")) == "stable_id" \
		and str(family_binding.get("value", "")) == str(dto.get("family_id", ""))


func _without_surface_metadata(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant)
			if key not in ["surface_id", "emphasis_id", "dto_fingerprint"]:
				result[key] = _without_surface_metadata((value as Dictionary).get(key_variant))
		return result
	if value is Array:
		var result: Array = []
		for item in value as Array:
			result.append(_without_surface_metadata(item))
		return result
	return value


func _duration_has_parameter(duration: Dictionary, parameter_id: String) -> bool:
	for component_variant in duration.get("components", []) as Array:
		var component: Dictionary = component_variant
		if str(component.get("parameter_id", "")) == parameter_id:
			return true
	return false


func _typed_args_have(value: Variant, arg_id: String, type_id: String, expected_value: Variant) -> bool:
	if not (value is Array):
		return false
	for arg_variant in value as Array:
		var arg: Dictionary = arg_variant
		if str(arg.get("arg_id", "")) == arg_id and str(arg.get("type_id", "")) == type_id and arg.get("value") == expected_value:
			return true
	return false


func _all_typed_args_use(value: Array, type_id: String) -> bool:
	if value.is_empty():
		return false
	for arg_variant in value:
		if str((arg_variant as Dictionary).get("type_id", "")) != type_id:
			return false
	return true


func _message_refs_are_typed(value: Variant) -> bool:
	if value is Dictionary:
		var source: Dictionary = value
		if source.has("message_id"):
			if not PlayerFaceDTO.is_stable_id(str(source.get("message_id", ""))) or not (source.get("args") is Array):
				return false
			for arg_variant in source.get("args", []) as Array:
				if not (arg_variant is Dictionary):
					return false
				var arg: Dictionary = arg_variant
				if not arg.has("arg_id") or not arg.has("type_id") or not arg.has("value"):
					return false
		for nested in source.values():
			if not _message_refs_are_typed(nested):
				return false
	elif value is Array:
		for nested in value as Array:
			if not _message_refs_are_typed(nested):
				return false
	return true


func _contains_non_ascii_string(value: Variant) -> bool:
	if value is String:
		for character in str(value):
			if character.unicode_at(0) > 127:
				return true
		return false
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if _contains_non_ascii_string(key_variant) or _contains_non_ascii_string((value as Dictionary).get(key_variant)):
				return true
	elif value is Array:
		for nested in value as Array:
			if _contains_non_ascii_string(nested):
				return true
	return false


func _contains_key(value: Variant, forbidden_keys: Array) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if forbidden_keys.has(str(key_variant)) or _contains_key((value as Dictionary).get(key_variant), forbidden_keys):
				return true
	elif value is Array:
		for nested in value as Array:
			if _contains_key(nested, forbidden_keys):
				return true
	return false


func _source_dependencies_are_clean() -> bool:
	var paths := [
		"res://scripts/presentation/player_face_dto_v1.gd",
		"res://scripts/runtime/card_player_face_projection_service.gd",
	]
	for path in paths:
		var source := FileAccess.get_file_as_string(path)
		if source.contains("get_tree().current_scene") or source.contains("get_node(") or source.contains("/root/Main") or source.contains("RandomNumberGenerator") or source.contains("randf(") or source.contains("randi(") or source.contains("_process(") or source.contains("Timer.new"):
			return false
	return true


func _semantic_authority_is_delegated() -> bool:
	var source := FileAccess.get_file_as_string("res://scripts/runtime/card_player_face_projection_service.gd")
	if not source.contains('preload("res://scripts/cards/semantic/card_semantic_schema_v1.gd")') \
			or not source.contains("CardSemanticSchema.validate_semantic_spec(spec)") \
			or source.contains("func _semantic_cost_error") \
			or source.contains("func _semantic_target_error") \
			or source.contains("func _semantic_effects_error") \
			or source.contains("SEMANTIC_ROOT_FIELDS") \
			or source.contains("EFFECT_OP_IDS") \
			or source.contains("TARGET_FILTER_IDS"):
		return false
	return not source.contains(".ends_with(") and not source.contains(".contains(")


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("FAIL: %s" % description)
