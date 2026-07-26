extends SceneTree

const PlayerFaceDTO := preload("res://scripts/presentation/player_face_dto_v1.gd")
const PlayerCardCodexDTO := preload(
	"res://scripts/presentation/player_card_codex_dto_v1.gd"
)
const PlayerCardCodexFamilyLadderDTO := preload(
	"res://scripts/presentation/player_card_codex_family_ladder_dto_v1.gd"
)
const AdapterScript := preload(
	"res://scripts/runtime/card_codex_public_source_adapter.gd"
)
const SnapshotScript := preload(
	"res://scripts/runtime/card_codex_public_snapshot_service.gd"
)
const BrowserSnapshotScript := preload(
	"res://scripts/viewmodels/card_codex_browser_snapshot.gd"
)
const DetailSnapshotScript := preload(
	"res://scripts/viewmodels/card_codex_detail_snapshot.gd"
)

const VALUE_CHANNEL_KEYS := [
	"owner",
	"hidden_owner",
	"true_owner",
	"player_index",
	"hand",
	"rival_hand",
	"opponent_hand",
	"exact_cash",
	"private_plan",
	"ai_score",
	"ai_value",
	"route_plan",
	"future_bag",
	"rng_state",
	"save_payload",
	"machine",
	"player",
	"developer",
	"effect_payload",
	"skill",
	"method_name",
	"script_path",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var adapter := AdapterScript.new()
	var snapshot := SnapshotScript.new()
	snapshot.configure({})
	var ladder := _ladder_dto()
	_expect(
		bool(PlayerCardCodexFamilyLadderDTO.validate(ladder).get("valid", false)),
		"four-rank fixture passes the closed ladder schema"
	)
	if ladder.is_empty():
		print("CARD_CODEX_DTO_COMPATIBILITY_ADAPTER_TEST|fixture_invalid")
		quit(1)
		return
	var dto := (ladder.get("entries", []) as Array)[1] as Dictionary
	var facts: Dictionary = adapter.compose_card_facts(dto, 7, ladder)
	_expect(not facts.is_empty(), "valid DTO composes canonical facts")
	_expect(
		str(facts.get("card_name", "")) == "interaction.test.rank_2"
			and str(facts.get("family_id", "")) == "interaction.test"
			and int(facts.get("rank", 0)) == 2,
		"card_name remains the stable card_id and rank comes from detail_face"
	)
	_expect(
		str(facts.get("acquisition_cost_text", "")) == "购买现金 ¥20"
			and str(facts.get("activation_cost_text", "")) == "打出 2 科技资产",
		"acquisition and activation copy remain separate"
	)
	_expect(
		(facts.get("family_ladder", []) as Array).size() == 4,
		"validated ladder produces four canonical upgrade rows"
	)
	var delegated_upgrades: Array = adapter.compose_upgrade_facts(ladder)
	_expect(
		delegated_upgrades.size() == 4
			and int((delegated_upgrades[0] as Dictionary).get("rank", 0)) == 1
			and int((delegated_upgrades[3] as Dictionary).get("rank", 0)) == 4,
		"compose_upgrade_facts preserves validated rank 1..4 entry order"
	)
	_expect(
		not facts.has("requires_target")
			and not facts.has("targets_player")
			and not facts.has("targets_monster")
			and not facts.has("strategy_route_label")
			and not facts.has("use_case"),
		"adapter emits no target, route, or use-case inference fields"
	)

	var request := {
		"names": ["interaction.test.rank_2"],
		"columns": 1,
		"rows": 1,
		"page_index": 0,
		"filter_id": "all",
		"filter_label": "全部",
		"selected_card": "interaction.test.rank_2",
		"icon_legend": "✦互动",
		"run_pool_count": 1,
		"district_supply_count": 0,
		"filters": [],
	}
	var filters := [{
		"id": "all",
		"label": "全部",
		"short_label": "全部",
		"icon": "□",
		"count": 1,
		"active": true,
		"disabled": false,
		"accent": Color("#93c5fd"),
	}]
	var browser_source: Dictionary = adapter.compose_browser_source(
		request,
		[facts],
		facts,
		filters
	)
	var detail_source: Dictionary = adapter.compose_detail_source(
		facts,
		facts.get("family_ladder", []) as Array,
		348
	)
	_expect(
		not browser_source.is_empty() and not detail_source.is_empty(),
		"canonical facts compose the existing browser and detail source shapes"
	)
	var browser: Dictionary = snapshot.compose_browser(browser_source)
	var detail_result: Dictionary = snapshot.compose_detail(detail_source)
	var detail := detail_result.get("detail", {}) as Dictionary
	_expect(
		(browser.get("cards", []) as Array).size() == 1
			and str(browser.get("selected_card", "")) == "interaction.test.rank_2",
		"browser selection and stable-id interactions remain intact"
	)
	_expect(
		(detail.get("upgrades", []) as Array).size() == 4
			and not (detail.get("card_face", {}) as Dictionary).is_empty(),
		"detail CardFace and I-IV ladder rendering shapes remain intact"
	)
	var tactical := detail.get("tactical", {}) as Dictionary
	var tactical_entries := tactical.get("entries", []) as Array
	_expect(
		tactical_entries.size() == 3
			and str((tactical_entries[0] as Dictionary).get("title", "")) == "出牌时机"
			and str((tactical_entries[1] as Dictionary).get("title", "")) == "目标"
			and str((tactical_entries[2] as Dictionary).get("title", "")) == "条件",
		"former tactical strip now displays explicit timing, target, and conditions"
	)
	var serialized_detail := JSON.stringify(detail)
	_expect(
		not serialized_detail.contains("何时拿")
			and not serialized_detail.contains("怎么配")
			and not serialized_detail.contains("会暴露")
			and not serialized_detail.contains("策略路线"),
		"snapshot contains no tactical or route guesses"
	)

	var raw_card := {
		"machine": {"card_id": "interaction.test.rank_2"},
		"player": {"name": "伪造卡牌"},
		"effect_payload": {"target_kind": "opponent"},
	}
	_expect(
		adapter.compose_card_facts(raw_card).is_empty(),
		"legacy raw card dictionaries fail closed"
	)
	for key in VALUE_CHANNEL_KEYS:
		var injected := dto.duplicate(true)
		injected[key] = "do-not-leak"
		injected["dto_fingerprint"] = PlayerCardCodexDTO.fingerprint_value(
			injected,
			"dto_fingerprint"
		)
		_expect(
			adapter.compose_card_facts(injected).is_empty(),
			"value channel %s is rejected even after caller re-fingerprinting" % key
		)

	var runtime_node := Node.new()
	var object_injected := dto.duplicate(true)
	object_injected["runtime_node"] = runtime_node
	_expect(
		adapter.compose_card_facts(object_injected).is_empty(),
		"runtime objects fail closed"
	)
	runtime_node.free()
	var callable_injected := dto.duplicate(true)
	callable_injected["callback"] = Callable(self, "_run")
	_expect(
		adapter.compose_card_facts(callable_injected).is_empty(),
		"Callable values fail closed"
	)

	var wrong_family_ladder := ladder.duplicate(true)
	wrong_family_ladder["family_id"] = "interaction.other"
	wrong_family_ladder["ladder_fingerprint"] = PlayerCardCodexDTO.fingerprint_value(
		wrong_family_ladder,
		"ladder_fingerprint"
	)
	_expect(
		adapter.compose_card_facts(dto, 0, wrong_family_ladder).is_empty(),
		"wrong-family ladder fails closed"
	)
	_expect(
		adapter.compose_upgrade_facts(wrong_family_ladder).is_empty(),
		"compose_upgrade_facts rejects a re-fingerprinted wrong-family ladder"
	)
	var tampered_facts := facts.duplicate(true)
	tampered_facts["target_text"] = "caller-forged-target"
	_expect(
		adapter.compose_detail_source(
			tampered_facts,
			facts.get("family_ladder", []) as Array,
			348
		).is_empty(),
		"mutated canonical facts fail their adapter fingerprint"
	)
	var raw_browser := adapter.compose_browser_source(
		request,
		[raw_card],
		{},
		filters
	)
	_expect(raw_browser.is_empty(), "browser source rejects hand-built raw cards")

	var roman_only: Dictionary = BrowserSnapshotScript.new().apply_dictionary({
		"names": ["stable.card.rank_4"],
		"columns": 1,
		"rows": 1,
		"page_index": 0,
		"selected_card": "stable.card.rank_4",
		"cards": [{
			"card_name": "stable.card.rank_4",
			"display_name": "显示名 IV",
			"title": "显示名 IV",
			"title_tooltip": "显示名 IV",
			"art_text": "展示",
			"kind": "interaction",
			"rank": "IV",
			"card_stats": "展示",
			"card_art_stats": "展示",
			"chips": [],
			"route": "互动",
			"route_tooltip": "互动",
			"effect": "展示",
			"effect_tooltip": "展示",
			"hint": "展示",
			"tooltip": "展示",
			"accent": Color.WHITE,
			"illustration_key": "",
		}],
		"filters": [],
		"preview": {},
	}).to_ui_dictionary()
	var roman_card := (roman_only.get("cards", []) as Array)[0] as Dictionary
	_expect(
		int(roman_card.get("rank_number", 0)) == 1,
		"browser ViewModel does not recover numeric rank from Roman text"
	)
	var alias_face := DetailSnapshotScript.new().apply_dictionary({
		"card_face": {
			"title": "legacy-title",
			"price": "legacy-price",
			"body": "legacy-body",
			"route": "legacy-route",
			"level": "IV",
		},
	}).to_ui_dictionary().get("card_face", {}) as Dictionary
	_expect(
		str(alias_face.get("name", "")) == "未命名卡牌"
			and str(alias_face.get("cost", "")) == ""
			and str(alias_face.get("rank", "")) == "",
		"detail ViewModel no longer follows legacy title/price/body/route/level aliases"
	)

	var schema: Dictionary = adapter.public_field_schema()
	var retirement := schema.get("compatibility_alias_retirement", {}) as Dictionary
	_expect(
		retirement.keys().size() == 9
			and retirement.has("card_name")
			and retirement.has("kind")
			and retirement.has("route")
			and retirement.has("effect")
			and retirement.has("cost")
			and retirement.has("type")
			and retirement.has("rank")
			and retirement.has("roman")
			and retirement.has("price")
			and not retirement.has("play_cost"),
		"compatibility aliases are an exact named retirement allowlist"
	)
	_expect(_source_scan_passes(), "production compatibility source has no banned inference")
	var debug: Dictionary = adapter.debug_snapshot()
	_expect(
		bool(debug.get("dto_only_semantic_input", false))
			and bool(debug.get("family_ladder_dto_supported", false))
			and not bool(debug.get("reads_raw_card_record", true))
			and not bool(debug.get("infers_rules_from_text", true)),
		"adapter debug contract reports DTO-only, no-inference behavior"
	)
	snapshot.free()

	if _failures.is_empty():
		print(
			"CARD_CODEX_DTO_COMPATIBILITY_ADAPTER_TEST|status=PASS|checks=%d" % _checks
		)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print(
		"CARD_CODEX_DTO_COMPATIBILITY_ADAPTER_TEST|status=FAIL|checks=%d|failures=%d" % [
			_checks,
			_failures.size(),
		]
	)
	quit(1)


func _ladder_dto() -> Dictionary:
	var entries: Array = []
	for rank in range(1, 5):
		entries.append(_codex_dto(rank))
	return PlayerCardCodexFamilyLadderDTO.seal({
		"schema_version": 1,
		"family_id": "interaction.test",
		"entries": entries,
	})


func _codex_dto(rank: int) -> Dictionary:
	var detail_face := _detail_face(rank)
	var source_definition_fingerprint := "%x" % rank
	source_definition_fingerprint = source_definition_fingerprint.repeat(64)
	var semantic_fingerprint := "%x" % (rank + 4)
	semantic_fingerprint = semantic_fingerprint.repeat(64)
	var unsealed := {
		"schema_version": 1,
		"projection_id": "card_codex.public",
		"semantic_binding": {
			"source_catalog_id": "space_syndicate.card_runtime_catalog.v06",
			"source_definition_fingerprint": source_definition_fingerprint,
			"semantic_fingerprint": semantic_fingerprint,
		},
		"localization_binding": {
			"source_id": "card_codex.public_localization.zh_hans",
			"source_revision": 1,
			"source_fingerprint": "a".repeat(64),
			"semantic_fingerprint": semantic_fingerprint,
		},
		"detail_face": detail_face,
		"taxonomy": {
			"category_id": "interaction",
			"industry_id": "technology",
			"category_label_ref": "card.category.interaction.label",
			"industry_label_ref": "card.industry.technology.label",
		},
		"presentation_tokens": {
			"category_icon_token_id": "icon.card.category.interaction",
			"category_color_token_id": "color.card.category.interaction",
			"industry_color_token_id": "color.card.industry.technology",
			"illustration_key": "card.art.interaction.test.rank_%d" % rank,
			"fallback_illustration_token_id": "illustration.card.fallback.interaction",
		},
		"presentation_copy": {
			"name": "测试协议",
			"family_name": "测试协议",
			"category_label": "互动牌",
			"industry_label": "科技",
			"acquisition_cost": "购买现金 ¥%d" % (rank * 10),
			"activation_cost": "打出 %d 科技资产" % rank,
			"timing": "主行动窗口",
			"targets": ["选择一名对手"],
			"conditions": ["对手有可弃置手牌"],
			"effect_steps": ["按顺序弃置一张牌"],
			"duration": "立即结算",
			"counterability": "可反制",
			"information_scope": "只公开合法回执",
			"keywords": ["手牌干扰"],
			"short_effect": "弃置一张对手手牌。",
			"full_effect": "选择一名对手，按顺序弃置其一张合法手牌。",
		},
	}
	return PlayerCardCodexDTO.seal(unsealed)


func _detail_face(rank: int) -> Dictionary:
	var card_id := "interaction.test.rank_%d" % rank
	return PlayerFaceDTO.seal({
		"schema_version": 1,
		"card_id": card_id,
		"family_id": "interaction.test",
		"rank": rank,
		"name_ref": _identity_ref("card.name.interaction.test", "card_id", card_id),
		"family_name_ref": _identity_ref(
			"card.family.interaction.test",
			"family_id",
			"interaction.test"
		),
		"surface_id": "detail",
		"acquisition_cost": {
			"acquisition_kind": "region_rack_cash",
			"purchase_cash": rank * 10,
			"message_ref": _message_ref("card.cost.acquisition.cash"),
			"emphasis_id": "complete",
		},
		"activation_cost": {
			"asset_cost": {
				"life": 0,
				"energy": 0,
				"industry": 0,
				"technology": rank,
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
			"source_id": "target.filter",
			"message_ref": _message_ref("card.condition.hand.discardable"),
			"emphasis_id": "complete",
		}],
		"effect_steps": [{
			"order": 1,
			"step_id": "step.1.discard_random",
			"op_id": "discard_random",
			"target_id": "player.opponent",
			"parameters": [],
			"summary_ref": _message_ref("card.effect.discard_random.summary"),
			"detail_ref": _message_ref("card.effect.discard_random.detail"),
			"emphasis_id": "complete",
		}],
		"duration": {
			"duration_id": "not_specified",
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
			"policy_id": "authorized_source_only",
			"scope_rows": [{
				"scope_id": "visibility_policy_id",
				"value_id": "authorized_source_only",
			}],
			"message_ref": _message_ref("card.information.authorized_source_only"),
			"emphasis_id": "complete",
		},
		"keywords": [{
			"keyword_id": "interaction.hand_disrupt",
			"label_ref": _message_ref("card.keyword.hand_disrupt.label"),
			"tooltip_ref": _message_ref("card.keyword.hand_disrupt.tooltip"),
			"icon_token_id": "icon.card.hand_disrupt",
			"color_token_id": "color.card.keyword.default",
		}],
	})


func _identity_ref(message_id: String, arg_id: String, value: String) -> Dictionary:
	return {
		"message_id": message_id,
		"args": [{"arg_id": arg_id, "type_id": "stable_id", "value": value}],
	}


func _message_ref(message_id: String) -> Dictionary:
	return {"message_id": message_id, "args": []}


func _source_scan_passes() -> bool:
	var adapter_source := FileAccess.get_file_as_string(
		"res://scripts/runtime/card_codex_public_source_adapter.gd"
	)
	var snapshot_source := FileAccess.get_file_as_string(
		"res://scripts/runtime/card_codex_public_snapshot_service.gd"
	)
	var browser_source := FileAccess.get_file_as_string(
		"res://scripts/viewmodels/card_codex_browser_snapshot.gd"
	)
	var detail_source := FileAccess.get_file_as_string(
		"res://scripts/viewmodels/card_codex_detail_snapshot.gd"
	)
	for banned in [
		"target_kind.contains",
		"kind.contains",
		"_tactical_timing_text",
		"_tactical_combo_text",
		"_tactical_clue_text",
		"_rank_number(value",
		"data.get(\"page\"",
		"data.get(\"preview_card\"",
	]:
		if adapter_source.contains(banned) \
				or snapshot_source.contains(banned) \
				or browser_source.contains(banned) \
				or detail_source.contains(banned):
			return false
	for raw_read in [
		".get(\"machine\"",
		".get(\"player\"",
		".get(\"effect_payload\"",
		".get(\"effect_kind\"",
		".get(\"target_kind\"",
	]:
		if adapter_source.contains(raw_read) or snapshot_source.contains(raw_read):
			return false
	return true


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(description)
	push_error("CARD CODEX DTO COMPATIBILITY ADAPTER: %s" % description)
