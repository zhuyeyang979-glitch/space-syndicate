extends SceneTree

const PLAYER_FACE_DTO := preload("res://scripts/presentation/player_face_dto_v1.gd")
const CODEX_DTO := preload(
	"res://scripts/presentation/player_card_codex_dto_v1.gd"
)
const LADDER_DTO := preload(
	"res://scripts/presentation/player_card_codex_family_ladder_dto_v1.gd"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_positive_contract()
	_test_rank_and_family_invariants()
	_test_closed_and_detached_boundary()
	_finish()


func _test_positive_contract() -> void:
	var unsealed := _valid_ladder_input()
	var ladder := LADDER_DTO.seal(unsealed)
	_expect(not ladder.is_empty(), "valid four-rank family ladder seals")
	_expect(
		bool(LADDER_DTO.validate(ladder).get("valid", false)),
		"sealed family ladder validates"
	)
	_expect(
		ladder.keys().size() == LADDER_DTO.ROOT_FIELDS.size(),
		"family ladder has the exact frozen root"
	)
	var entries := ladder.get("entries") as Array
	_expect(entries.size() == 4, "family ladder contains exactly four entries")
	for index in range(entries.size()):
		var face := (entries[index] as Dictionary).get("detail_face") as Dictionary
		_expect(
			int(face.get("rank", 0)) == index + 1,
			"entry %d carries its authoritative rank" % (index + 1)
		)
		_expect(
			str(face.get("family_id", "")) == "interaction.blackout",
			"entry %d carries the same authoritative family" % (index + 1)
		)

	var repeated := LADDER_DTO.seal(_valid_ladder_input())
	_expect(
		str(ladder.get("ladder_fingerprint", "")) \
			== str(repeated.get("ladder_fingerprint", "")),
		"family ladder fingerprint is deterministic"
	)

	unsealed["entries"][0]["presentation_copy"]["name"] = "Caller mutation"
	_expect(
		str(entries[0]["presentation_copy"]["name"]) == "Display rank IV",
		"sealed family ladder is deeply detached from caller entries"
	)


func _test_rank_and_family_invariants() -> void:
	for invalid_size in [3, 5]:
		var wrong_size := _valid_ladder_input()
		if invalid_size == 3:
			wrong_size["entries"].pop_back()
		else:
			wrong_size["entries"].append(_valid_codex_dto(4))
		_expect(
			LADDER_DTO.seal(wrong_size).is_empty(),
			"family ladder rejects %d entries" % invalid_size
		)

	var reordered := _valid_ladder_input()
	var first: Variant = reordered["entries"][0]
	reordered["entries"][0] = reordered["entries"][1]
	reordered["entries"][1] = first
	_expect(
		LADDER_DTO.seal(reordered).is_empty(),
		"rank order must be exactly 1 through 4"
	)

	var duplicate_rank := _valid_ladder_input()
	duplicate_rank["entries"][2] = _valid_codex_dto(2)
	_expect(
		LADDER_DTO.seal(duplicate_rank).is_empty(),
		"duplicate authoritative rank is rejected"
	)

	var wrong_family := _valid_ladder_input()
	wrong_family["family_id"] = "interaction.other"
	_expect(
		LADDER_DTO.seal(wrong_family).is_empty(),
		"ladder family must match every detail face"
	)

	var mutated_entry := _valid_ladder_input()
	mutated_entry["entries"][1]["detail_face"]["rank"] = 3
	_expect(
		LADDER_DTO.seal(mutated_entry).is_empty(),
		"invalid nested Codex DTO is rejected"
	)

	var text_does_not_define_rank := _valid_ladder_input()
	for entry_variant in text_does_not_define_rank["entries"] as Array:
		var entry := _unsealed(entry_variant as Dictionary)
		entry["presentation_copy"]["name"] = "Same localized name IV"
		entry_variant.clear()
		entry_variant.merge(CODEX_DTO.seal(entry), true)
	var text_agnostic_ladder := LADDER_DTO.seal(text_does_not_define_rank)
	_expect(
		not text_agnostic_ladder.is_empty(),
		"localized names and Roman suffixes never define ladder rank"
	)


func _test_closed_and_detached_boundary() -> void:
	var extra_root := _valid_ladder_input()
	extra_root["rank_names"] = ["I", "II", "III", "IV"]
	_expect(
		LADDER_DTO.seal(extra_root).is_empty(),
		"family ladder rejects inferred rank aliases"
	)

	var missing_root := _valid_ladder_input()
	missing_root.erase("family_id")
	_expect(LADDER_DTO.seal(missing_root).is_empty(), "missing family ID is rejected")

	var invalid_version := _valid_ladder_input()
	invalid_version["schema_version"] = 2
	_expect(
		LADDER_DTO.seal(invalid_version).is_empty(),
		"unknown family ladder schema version fails closed"
	)

	var invalid_family_type := _valid_ladder_input()
	invalid_family_type["family_id"] = false
	_expect(
		LADDER_DTO.seal(invalid_family_type).is_empty(),
		"family stable identity requires a String"
	)

	var non_dictionary_entry := _valid_ladder_input()
	non_dictionary_entry["entries"][0] = "interaction.blackout.rank_1"
	_expect(
		LADDER_DTO.seal(non_dictionary_entry).is_empty(),
		"raw card IDs cannot replace closed Codex DTO entries"
	)

	var runtime_node := Node.new()
	var node_entry := _valid_ladder_input()
	node_entry["entries"][0] = runtime_node
	_expect(LADDER_DTO.seal(node_entry).is_empty(), "Node entry is rejected")
	runtime_node.free()

	var callable_entry := _valid_ladder_input()
	callable_entry["entries"][0] = Callable(self, "_run")
	_expect(LADDER_DTO.seal(callable_entry).is_empty(), "Callable entry is rejected")

	var tampered := LADDER_DTO.seal(_valid_ladder_input())
	tampered["family_id"] = "interaction.tampered"
	_expect(
		not bool(LADDER_DTO.validate(tampered).get("valid", false)),
		"post-seal ladder mutation is rejected"
	)


func _valid_ladder_input() -> Dictionary:
	return {
		"schema_version": 1,
		"family_id": "interaction.blackout",
		"entries": [
			_valid_codex_dto(1),
			_valid_codex_dto(2),
			_valid_codex_dto(3),
			_valid_codex_dto(4),
		],
	}


func _valid_codex_dto(rank: int) -> Dictionary:
	var semantic_fingerprint := "%x" % rank
	semantic_fingerprint = semantic_fingerprint.repeat(64)
	return CODEX_DTO.seal({
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
			"source_fingerprint": "b".repeat(64),
			"semantic_fingerprint": semantic_fingerprint,
		},
		"detail_face": _valid_detail_face(rank),
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
			"illustration_key": "",
			"fallback_illustration_token_id": "illustration.card.fallback",
		},
		"presentation_copy": {
			"name": "Display rank IV",
			"family_name": "Display family",
			"category_label": "Interaction",
			"industry_label": "Generic",
			"acquisition_cost": "Acquire for cash",
			"activation_cost": "No activation cost",
			"timing": "Main action",
			"targets": ["Choose an opponent"],
			"conditions": [],
			"effect_steps": ["Resolve the effect"],
			"duration": "Immediate",
			"counterability": "Counterable",
			"information_scope": "Public result",
			"keywords": ["Counterable"],
			"short_effect": "Short display copy",
			"full_effect": "Full display copy",
		},
	})


func _valid_detail_face(rank: int) -> Dictionary:
	var card_id := "interaction.blackout.rank_%d" % rank
	var family_id := "interaction.blackout"
	return PLAYER_FACE_DTO.seal({
		"schema_version": 1,
		"card_id": card_id,
		"family_id": family_id,
		"rank": rank,
		"name_ref": _identity_ref("card.name.blackout", "card_id", card_id),
		"family_name_ref": _identity_ref("card.family.blackout", "family_id", family_id),
		"surface_id": "detail",
		"acquisition_cost": {
			"acquisition_kind": "region_rack_cash",
			"purchase_cash": rank,
			"message_ref": _message_ref("card.cost.acquisition.cash"),
			"emphasis_id": "complete",
		},
		"activation_cost": {
			"asset_cost": {
				"life": 0,
				"energy": 0,
				"industry": 0,
				"technology": 0,
				"commerce": 0,
				"shipping": 0,
				"generic": 0,
			},
			"message_ref": _message_ref("card.cost.activation.none"),
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
		"conditions": [],
		"effect_steps": [{
			"order": 1,
			"step_id": "effect.step_1",
			"op_id": "discard_random",
			"target_id": "player.opponent",
			"parameters": [],
			"summary_ref": _message_ref("card.effect.discard_random.summary"),
			"detail_ref": _message_ref("card.effect.discard_random.detail"),
			"emphasis_id": "complete",
		}],
		"duration": {
			"duration_id": "immediate",
			"components": [],
			"message_ref": _message_ref("card.duration.immediate"),
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
			"scope_rows": [{"scope_id": "result", "value_id": "public"}],
			"message_ref": _message_ref("card.information.public_result"),
			"emphasis_id": "complete",
		},
		"keywords": [{
			"keyword_id": "response.counterable",
			"label_ref": _message_ref("card.keyword.counterable.label"),
			"tooltip_ref": _message_ref("card.keyword.counterable.tooltip"),
			"icon_token_id": "icon.card.counterable",
			"color_token_id": "color.card.counterable",
		}],
	})


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


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print(
			"PLAYER_CARD_CODEX_FAMILY_LADDER_DTO_V1_TEST|status=PASS|checks=%d" \
			% _checks
		)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print(
		"PLAYER_CARD_CODEX_FAMILY_LADDER_DTO_V1_TEST|status=FAIL|checks=%d|failures=%d" \
		% [_checks, _failures.size()]
	)
	quit(1)
