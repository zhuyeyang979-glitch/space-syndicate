extends SceneTree

const PLAYER_FACE_DTO := preload("res://scripts/presentation/player_face_dto_v1.gd")
const CODEX_DTO := preload(
	"res://scripts/presentation/player_card_codex_dto_v1.gd"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_positive_contract()
	_test_closed_schema_and_bindings()
	_test_detail_face_and_identity_boundary()
	_test_presentation_boundary()
	_test_detached_data_and_forbidden_channels()
	_finish()


func _test_positive_contract() -> void:
	var unsealed := _valid_codex_input(2)
	var dto := CODEX_DTO.seal(unsealed)
	_expect(not dto.is_empty(), "valid Codex DTO seals")
	_expect(
		bool(CODEX_DTO.validate(dto).get("valid", false)),
		"sealed Codex DTO validates"
	)
	_expect(
		dto.keys().size() == CODEX_DTO.ROOT_FIELDS.size(),
		"Codex DTO has the exact frozen root"
	)
	_expect(
		int(dto.get("schema_version", 0)) == 1 \
			and str(dto.get("projection_id", "")) == "card_codex.public",
		"Codex DTO carries the versioned projection identity"
	)
	_expect(
		str((dto.get("detail_face") as Dictionary).get("surface_id", "")) \
			== "detail",
		"Codex specialization composes a detail PlayerFaceDTO"
	)
	_expect(
		not PLAYER_FACE_DTO.SURFACE_IDS.has("codex"),
		"frozen PlayerFaceDTOv1 surface IDs remain unchanged"
	)
	var semantic_binding := dto.get("semantic_binding") as Dictionary
	var localization_binding := dto.get("localization_binding") as Dictionary
	_expect(
		str(semantic_binding.get("semantic_fingerprint", "")) \
			== str(localization_binding.get("semantic_fingerprint", "")),
		"semantic and localization bindings share one semantic fingerprint"
	)

	var reordered := unsealed.duplicate(true)
	var reordered_binding := reordered.get("semantic_binding") as Dictionary
	var catalog_id: Variant = reordered_binding.get("source_catalog_id")
	reordered_binding.erase("source_catalog_id")
	reordered_binding["source_catalog_id"] = catalog_id
	var reordered_dto := CODEX_DTO.seal(reordered)
	_expect(
		str(dto.get("dto_fingerprint", "")) \
			== str(reordered_dto.get("dto_fingerprint", "")),
		"fingerprinting is deterministic across dictionary insertion order"
	)

	unsealed["presentation_copy"]["name"] = "Caller mutation"
	unsealed["detail_face"]["card_id"] = "interaction.changed.rank_2"
	_expect(
		str((dto.get("presentation_copy") as Dictionary).get("name", "")) \
			== "Blackout II" \
			and str((dto.get("detail_face") as Dictionary).get("card_id", "")) \
				== "interaction.blackout.rank_2",
		"sealed DTO is deeply detached from caller data"
	)

	var text_only_change := _unsealed(dto)
	text_only_change["presentation_copy"]["timing"] = "Any trusted display copy"
	text_only_change["presentation_copy"]["effect_steps"] = [
		"Second display sentence",
		"First display sentence",
	]
	var text_only_dto := CODEX_DTO.seal(text_only_change)
	_expect(
		not text_only_dto.is_empty() \
			and (text_only_dto["presentation_copy"]["effect_steps"] as Array)[0] \
				== "Second display sentence",
		"presentation text is preserved in authored order without interpretation"
	)
	_expect(
		str(text_only_dto.get("dto_fingerprint", "")) \
			!= str(dto.get("dto_fingerprint", "")),
		"presentation changes rotate the deterministic DTO fingerprint"
	)


func _test_closed_schema_and_bindings() -> void:
	var extra_root := _valid_codex_input(2)
	extra_root["cost"] = 7
	_expect(CODEX_DTO.seal(extra_root).is_empty(), "legacy root alias is rejected")

	var missing_root := _valid_codex_input(2)
	missing_root.erase("taxonomy")
	_expect(CODEX_DTO.seal(missing_root).is_empty(), "missing root field is rejected")

	var wrong_version := _valid_codex_input(2)
	wrong_version["schema_version"] = 2
	_expect(CODEX_DTO.seal(wrong_version).is_empty(), "unknown schema version fails closed")

	var wrong_projection := _valid_codex_input(2)
	wrong_projection["projection_id"] = "card_codex.private"
	_expect(CODEX_DTO.seal(wrong_projection).is_empty(), "wrong projection ID fails closed")

	var binding_extra := _valid_codex_input(2)
	binding_extra["semantic_binding"]["authorized"] = true
	_expect(
		CODEX_DTO.seal(binding_extra).is_empty(),
		"caller-controlled semantic authorization is rejected"
	)

	var localization_extra := _valid_codex_input(2)
	localization_extra["localization_binding"]["authorization_scope_id"] = "public"
	_expect(
		CODEX_DTO.seal(localization_extra).is_empty(),
		"caller-controlled localization authorization is rejected"
	)

	var mismatch := _valid_codex_input(2)
	mismatch["localization_binding"]["semantic_fingerprint"] = "9".repeat(64)
	_expect(
		CODEX_DTO.seal(mismatch).is_empty(),
		"localization cannot bind a different semantic fingerprint"
	)

	for invalid_revision in [0, -1, 1.5, "1"]:
		var invalid := _valid_codex_input(2)
		invalid["localization_binding"]["source_revision"] = invalid_revision
		_expect(
			CODEX_DTO.seal(invalid).is_empty(),
			"invalid localization source revision is rejected"
		)

	var invalid_catalog_type := _valid_codex_input(2)
	invalid_catalog_type["semantic_binding"]["source_catalog_id"] = false
	_expect(
		CODEX_DTO.seal(invalid_catalog_type).is_empty(),
		"stable catalog identity requires a String"
	)

	var invalid_fingerprint := _valid_codex_input(2)
	invalid_fingerprint["semantic_binding"]["source_definition_fingerprint"] \
		= "not-a-fingerprint"
	_expect(
		CODEX_DTO.seal(invalid_fingerprint).is_empty(),
		"invalid source definition fingerprint is rejected"
	)

	var tampered := CODEX_DTO.seal(_valid_codex_input(2))
	tampered["presentation_copy"]["name"] = "Tampered"
	_expect(
		not bool(CODEX_DTO.validate(tampered).get("valid", false)),
		"post-seal mutation invalidates the fingerprint"
	)


func _test_detail_face_and_identity_boundary() -> void:
	var hand_face := _valid_codex_input(2)
	var unsealed_face := _unsealed_face(hand_face.get("detail_face") as Dictionary)
	unsealed_face["surface_id"] = "hand"
	hand_face["detail_face"] = PLAYER_FACE_DTO.seal(unsealed_face)
	_expect(
		CODEX_DTO.seal(hand_face).is_empty(),
		"non-detail PlayerFaceDTO is rejected"
	)

	var broken_face := _valid_codex_input(2)
	broken_face["detail_face"]["rank"] = 4
	_expect(
		CODEX_DTO.seal(broken_face).is_empty(),
		"invalid nested PlayerFace fingerprint is rejected"
	)

	var invalid_identity := _valid_codex_input(2)
	var face_input := _unsealed_face(
		invalid_identity.get("detail_face") as Dictionary
	)
	face_input["name_ref"]["args"][0]["value"] = "interaction.other.rank_2"
	invalid_identity["detail_face"] = PLAYER_FACE_DTO.seal(face_input)
	_expect(
		invalid_identity.get("detail_face", {}).is_empty() \
			and CODEX_DTO.seal(invalid_identity).is_empty(),
		"detail identity must remain bound to its stable card ID"
	)

	var raw_name_identity := _valid_codex_input(2)
	raw_name_identity["taxonomy"]["category_label_ref"] = "Interaction"
	_expect(
		CODEX_DTO.seal(raw_name_identity).is_empty(),
		"localized display text cannot act as a message identity"
	)

	var taxonomy_arg_channel := _valid_codex_input(2)
	taxonomy_arg_channel["taxonomy"]["category_label_ref"] = {
		"message_id": "card.category.interaction",
		"args": [{"arg_id": "ai_score", "type_id": "integer", "value": 100}],
	}
	_expect(
		CODEX_DTO.seal(taxonomy_arg_channel).is_empty(),
		"taxonomy label refs cannot become open value-channel objects"
	)

	var invalid_taxonomy_type := _valid_codex_input(2)
	invalid_taxonomy_type["taxonomy"]["industry_id"] = true
	_expect(
		CODEX_DTO.seal(invalid_taxonomy_type).is_empty(),
		"taxonomy stable IDs require String values"
	)


func _test_presentation_boundary() -> void:
	for array_field in CODEX_DTO.PRESENTATION_ARRAY_FIELDS:
		var non_string := _valid_codex_input(2)
		non_string["presentation_copy"][array_field] = [1]
		_expect(
			CODEX_DTO.seal(non_string).is_empty(),
			"%s rejects non-string rows" % array_field
		)

	var count_mismatch := _valid_codex_input(2)
	count_mismatch["presentation_copy"]["effect_steps"] = ["Only one step"]
	_expect(
		CODEX_DTO.seal(count_mismatch).is_empty(),
		"display effect rows stay positionally bound to semantic effect rows"
	)

	var empty_condition_copy := _valid_codex_input(2)
	var face_input := _unsealed_face(
		empty_condition_copy.get("detail_face") as Dictionary
	)
	face_input["conditions"] = []
	empty_condition_copy["detail_face"] = PLAYER_FACE_DTO.seal(face_input)
	empty_condition_copy["presentation_copy"]["conditions"] = []
	_expect(
		not CODEX_DTO.seal(empty_condition_copy).is_empty(),
		"empty condition arrays remain valid when the detail face has none"
	)

	var blank_text := _valid_codex_input(2)
	blank_text["presentation_copy"]["full_effect"] = "   "
	_expect(
		CODEX_DTO.seal(blank_text).is_empty(),
		"required resolved presentation text cannot be blank"
	)

	var invalid_token := _valid_codex_input(2)
	invalid_token["presentation_tokens"]["category_icon_token_id"] = "Icon/Card"
	_expect(
		CODEX_DTO.seal(invalid_token).is_empty(),
		"presentation tokens require stable IDs"
	)

	var fallback_art := _valid_codex_input(2)
	fallback_art["presentation_tokens"]["illustration_key"] = ""
	_expect(
		not CODEX_DTO.seal(fallback_art).is_empty(),
		"empty illustration key explicitly selects the stable fallback token"
	)

	var invalid_art_key := _valid_codex_input(2)
	invalid_art_key["presentation_tokens"]["illustration_key"] = "res://card.png"
	_expect(
		CODEX_DTO.seal(invalid_art_key).is_empty(),
		"illustration key cannot become a resource path"
	)


func _test_detached_data_and_forbidden_channels() -> void:
	for forbidden_key in [
		"owner",
		"hidden_owner",
		"opponent_hand",
		"exact_cash",
		"private_plan",
		"ai_score",
		"ai_value",
		"route_plan",
		"rng_state",
		"save_payload",
		"developer",
		"effect_payload",
		"method_name",
		"script_path",
	]:
		var injected := _valid_codex_input(2)
		injected["presentation_copy"][forbidden_key] = "injected"
		_expect(
			CODEX_DTO.seal(injected).is_empty(),
			"forbidden value channel is rejected: %s" % forbidden_key
		)

	var runtime_node := Node.new()
	var node_injected := _valid_codex_input(2)
	node_injected["presentation_copy"]["name"] = runtime_node
	_expect(CODEX_DTO.seal(node_injected).is_empty(), "Node value is rejected")
	runtime_node.free()

	var resource_injected := _valid_codex_input(2)
	resource_injected["presentation_tokens"]["illustration_key"] = Resource.new()
	_expect(
		CODEX_DTO.seal(resource_injected).is_empty(),
		"Resource value is rejected"
	)

	var callable_injected := _valid_codex_input(2)
	callable_injected["presentation_copy"]["full_effect"] = Callable(
		self,
		"_run"
	)
	_expect(
		CODEX_DTO.seal(callable_injected).is_empty(),
		"Callable value is rejected"
	)


func _valid_codex_input(rank: int) -> Dictionary:
	var detail_face := _valid_detail_face(rank)
	var semantic_fingerprint := "b".repeat(64)
	return {
		"schema_version": 1,
		"projection_id": "card_codex.public",
		"semantic_binding": {
			"source_catalog_id": "space_syndicate.card_runtime_catalog.v06",
			"source_definition_fingerprint": "a".repeat(64),
			"semantic_fingerprint": semantic_fingerprint,
		},
		"localization_binding": {
			"source_id": "space_syndicate.card_player_face_public_localization.v1",
			"source_revision": 1,
			"source_fingerprint": "c".repeat(64),
			"semantic_fingerprint": semantic_fingerprint,
		},
		"detail_face": detail_face,
		"taxonomy": {
			"category_id": "interaction",
			"industry_id": "generic",
			"category_label_ref": "card.category.interaction",
			"industry_label_ref": "card.industry.generic",
		},
		"presentation_tokens": {
			"category_icon_token_id": "icon.card.category.interaction",
			"category_color_token_id": "color.card.category.interaction",
			"industry_color_token_id": "color.card.industry.generic",
			"illustration_key": "alpha01_art_001",
			"fallback_illustration_token_id": "illustration.card.fallback",
		},
		"presentation_copy": {
			"name": "Blackout %s" % _roman(rank),
			"family_name": "Blackout",
			"category_label": "Interaction",
			"industry_label": "Generic",
			"acquisition_cost": "Acquire for 7 cash",
			"activation_cost": "Spend 1 energy and 2 technology",
			"timing": "Main action",
			"targets": ["Choose one opponent"],
			"conditions": ["Opponent has a discardable card"],
			"effect_steps": [
				"Discard one random card",
				"Lock one random card",
			],
			"duration": "5 seconds",
			"counterability": "Counterable",
			"information_scope": "Public result",
			"keywords": ["Hand disruption", "Counterable"],
			"short_effect": "Discard and lock cards.",
			"full_effect": "Discard one random card, then lock one random card.",
		},
	}


func _valid_detail_face(rank: int) -> Dictionary:
	var card_id := "interaction.blackout.rank_%d" % rank
	var family_id := "interaction.blackout"
	return PLAYER_FACE_DTO.seal({
		"schema_version": 1,
		"card_id": card_id,
		"family_id": family_id,
		"rank": rank,
		"name_ref": _identity_ref("card.name.interaction.blackout", "card_id", card_id),
		"family_name_ref": _identity_ref(
			"card.family.interaction.blackout",
			"family_id",
			family_id
		),
		"surface_id": "detail",
		"acquisition_cost": {
			"acquisition_kind": "region_rack_cash",
			"purchase_cash": 7,
			"message_ref": _message_ref("card.cost.acquisition.cash"),
			"emphasis_id": "complete",
		},
		"activation_cost": {
			"asset_cost": {
				"life": 0,
				"energy": 1,
				"industry": 0,
				"technology": 2,
				"commerce": 0,
				"shipping": 0,
				"generic": 0,
			},
			"message_ref": _message_ref("card.cost.activation.assets"),
			"emphasis_id": "complete",
		},
		"timing": {
			"timing_id": "main_action",
			"message_ref": _message_ref("card.timing.main_action"),
			"emphasis_id": "complete",
		},
		"targets": [{
			"target_id": "player.opponent",
			"selection_id": "actor_choice",
			"cardinality_id": "exactly_one",
			"filter_ids": ["hand.discardable"],
			"message_ref": _message_ref("card.target.player.opponent"),
			"emphasis_id": "complete",
		}],
		"conditions": [{
			"condition_id": "hand.discardable",
			"source_id": "target.player.opponent",
			"message_ref": _message_ref("card.condition.hand.discardable"),
			"emphasis_id": "complete",
		}],
		"effect_steps": [
			_effect_step(1, "discard_random"),
			_effect_step(2, "lock_random"),
		],
		"duration": {
			"duration_id": "effect_defined",
			"components": [],
			"message_ref": _message_ref("card.duration.effect_defined"),
			"emphasis_id": "complete",
		},
		"counterability": {
			"response_id": "counterable",
			"parameters": [],
			"message_ref": _message_ref("card.counterability.counterable"),
			"emphasis_id": "complete",
		},
		"information_scope": {
			"policy_id": "public_result",
			"scope_rows": [{
				"scope_id": "result",
				"value_id": "public",
			}],
			"message_ref": _message_ref("card.information.public_result"),
			"emphasis_id": "complete",
		},
		"keywords": [
			_keyword("interaction.hand_disrupt"),
			_keyword("response.counterable"),
		],
	})


func _effect_step(order: int, op_id: String) -> Dictionary:
	var parameters := [{
		"arg_id": "count",
		"type_id": "count",
		"value": 1,
	}]
	return {
		"order": order,
		"step_id": "effect.step_%d" % order,
		"op_id": op_id,
		"target_id": "player.opponent",
		"parameters": parameters,
		"summary_ref": {
			"message_id": "card.effect.%s.summary" % op_id,
			"args": parameters.duplicate(true),
		},
		"detail_ref": {
			"message_id": "card.effect.%s.detail" % op_id,
			"args": parameters.duplicate(true),
		},
		"emphasis_id": "complete",
	}


func _keyword(keyword_id: String) -> Dictionary:
	return {
		"keyword_id": keyword_id,
		"label_ref": _message_ref("card.keyword.%s.label" % keyword_id),
		"tooltip_ref": _message_ref("card.keyword.%s.tooltip" % keyword_id),
		"icon_token_id": "icon.card.keyword",
		"color_token_id": "color.card.keyword",
	}


func _message_ref(message_id: String) -> Dictionary:
	return {"message_id": message_id, "args": []}


func _identity_ref(
	message_id: String,
	arg_id: String,
	value: String
) -> Dictionary:
	return {
		"message_id": message_id,
		"args": [{
			"arg_id": arg_id,
			"type_id": "stable_id",
			"value": value,
		}],
	}


func _unsealed(dto: Dictionary) -> Dictionary:
	var result := dto.duplicate(true)
	result.erase("dto_fingerprint")
	return result


func _unsealed_face(dto: Dictionary) -> Dictionary:
	var result := dto.duplicate(true)
	result.erase("dto_fingerprint")
	return result


func _roman(rank: int) -> String:
	return ["I", "II", "III", "IV"][rank - 1]


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("PLAYER_CARD_CODEX_DTO_V1_TEST|status=PASS|checks=%d" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print(
		"PLAYER_CARD_CODEX_DTO_V1_TEST|status=FAIL|checks=%d|failures=%d" \
		% [_checks, _failures.size()]
	)
	quit(1)
