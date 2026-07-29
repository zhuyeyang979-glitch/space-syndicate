extends SceneTree

const CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v06.tres"
const CARD_PRESENTATION_SCENE := "res://scenes/runtime/CardPresentationRuntimeService.tscn"
const TABLE_QUERY_SCRIPT := preload("res://scripts/presentation/table_presentation_viewmodel_query.gd")
const DOCK_SERVICE_SCRIPT := preload("res://scripts/presentation/player_card_dock_projection_service.gd")
const DOCK_PROJECTION := preload("res://scripts/presentation/player_card_dock_projection_v1.gd")
const DRIVER := preload("res://scripts/tools/full_run_quality_driver.gd")
const PLANNER := preload("res://scripts/tools/full_run_economy_continuation_planner.gd")
const OFFER := preload("res://scripts/semantic/game_action_offer_v1.gd")
const INTENT := preload("res://scripts/semantic/game_action_intent_v1.gd")
const CARD_BINDING := preload("res://scripts/semantic/game_action_card_binding_v1.gd")

const MATCHING_CARD_ID := "facility.market.energy.rank_1"
const DECOY_CARD_ID := "facility.factory.life.rank_1"
const SOURCE_REVISION := 73
const AUTHORIZATION_REVISION := 5
const TARGET_RETRY_REASON_IDS := [
	"public_facility_target_unavailable",
	"public_facility_slot_occupied",
	"public_facility_slot_incompatible",
	"public_facility_product_unavailable",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := load(CATALOG_PATH) as CardRuntimeCatalogV06Resource
	var packed := load(CARD_PRESENTATION_SCENE) as PackedScene
	var presentation := packed.instantiate() as CardPresentationRuntimeService \
		if packed != null else null
	var table_query := TABLE_QUERY_SCRIPT.new() as TablePresentationViewModelQuery
	var dock_service := DOCK_SERVICE_SCRIPT.new() as PlayerCardDockProjectionService
	_expect(catalog != null, "the production v0.6 card catalog loads")
	_expect(presentation != null, "the production CardPresentation service loads")
	_expect(table_query != null and dock_service != null, "both production projection services instantiate")
	if catalog == null or presentation == null or table_query == null or dock_service == null:
		_free_nodes(presentation, table_query)
		_finish()
		return

	var matching_definition := catalog.card_snapshot(MATCHING_CARD_ID)
	var decoy_definition := catalog.card_snapshot(DECOY_CARD_ID)
	_expect(_is_catalog_facility(matching_definition, "market", "energy"), "matching fixture is the real energy-market catalog card")
	_expect(_is_catalog_facility(decoy_definition, "factory", "life"), "decoy fixture is the real life-factory catalog card")
	if matching_definition.is_empty() or decoy_definition.is_empty():
		_free_nodes(presentation, table_query)
		_finish()
		return

	_run_available_case(catalog, presentation, table_query, dock_service)
	for reason_id in TARGET_RETRY_REASON_IDS:
		_run_blocked_case(
			catalog,
			presentation,
			table_query,
			dock_service,
			str(reason_id)
		)

	_free_nodes(presentation, table_query)
	_finish()


func _run_available_case(
	catalog: CardRuntimeCatalogV06Resource,
	presentation: CardPresentationRuntimeService,
	table_query: TablePresentationViewModelQuery,
	dock_service: PlayerCardDockProjectionService
) -> void:
	var bundle := _projection_bundle(
		catalog,
		presentation,
		table_query,
		dock_service,
		true,
		"playable"
	)
	_expect(bool(bundle.get("valid", false)), "available real-hand bundle projects through legacy and Dock paths")
	if not bool(bundle.get("valid", false)):
		return
	var legacy_cards: Array = bundle.get("legacy_cards", []) as Array
	var dock_cards: Array = bundle.get("dock_cards", []) as Array
	var legacy_card := _card_by_id(legacy_cards, MATCHING_CARD_ID)
	var dock_card := _card_by_id(dock_cards, MATCHING_CARD_ID)
	_expect(_same_planner_identity(legacy_card, dock_card), "available Dock row preserves legacy planner identity")
	_expect(bool(legacy_card.get("actionable", false)) and bool(dock_card.get("actionable", false)), "available actionability is equivalent")
	_expect(_canonical_reason(legacy_card) == _canonical_reason(dock_card), "available legality reason is canonically equivalent")
	_expect(_same_offer(legacy_card, dock_card), "available Dock row preserves the exact legacy offer fingerprint")

	var legacy_selected := PLANNER.first_matching_facility(legacy_cards, _market_energy_plan(), true)
	var dock_selected := PLANNER.first_matching_facility(dock_cards, _market_energy_plan(), true)
	_expect(_same_planner_identity(legacy_selected, dock_selected), "available Planner selection is identical after the Dock cutover")
	_expect(str(dock_selected.get("card_id", "")) == MATCHING_CARD_ID, "Planner selects the real matching market instead of the real decoy factory")
	var request := DRIVER._enabled_card_action_request(dock_selected)
	var request_offer: Dictionary = request.get("game_action_offer", {}) \
		if request.get("game_action_offer", {}) is Dictionary else {}
	_expect(
		not request.is_empty()
			and str(request_offer.get("offer_fingerprint", "")) == _offer_fingerprint(legacy_selected),
		"Dock Planner selection submits the same authoritative offer fingerprint as legacy"
	)


func _run_blocked_case(
	catalog: CardRuntimeCatalogV06Resource,
	presentation: CardPresentationRuntimeService,
	table_query: TablePresentationViewModelQuery,
	dock_service: PlayerCardDockProjectionService,
	reason_id: String
) -> void:
	var bundle := _projection_bundle(
		catalog,
		presentation,
		table_query,
		dock_service,
		false,
		reason_id
	)
	_expect(bool(bundle.get("valid", false)), "%s bundle projects through legacy and Dock paths" % reason_id)
	if not bool(bundle.get("valid", false)):
		return
	var legacy_cards: Array = bundle.get("legacy_cards", []) as Array
	var dock_cards: Array = bundle.get("dock_cards", []) as Array
	var legacy_card := _card_by_id(legacy_cards, MATCHING_CARD_ID)
	var dock_card := _card_by_id(dock_cards, MATCHING_CARD_ID)
	_expect(_same_planner_identity(legacy_card, dock_card), "%s preserves legacy planner identity" % reason_id)
	_expect(not bool(legacy_card.get("actionable", true)) and not bool(dock_card.get("actionable", true)), "%s preserves blocked actionability" % reason_id)
	_expect(
		str(legacy_card.get("play_reason_id", "")) == reason_id
			and str(dock_card.get("play_reason_id", "")) == reason_id,
		"%s round-trips exactly through offer wire normalization" % reason_id
	)
	_expect(_same_offer(legacy_card, dock_card), "%s preserves the exact legacy offer fingerprint" % reason_id)

	var legacy_actionable := PLANNER.first_matching_facility(legacy_cards, _market_energy_plan(), true)
	var dock_actionable := PLANNER.first_matching_facility(dock_cards, _market_energy_plan(), true)
	_expect(legacy_actionable.is_empty() and dock_actionable.is_empty(), "%s cannot become an actionable Planner match" % reason_id)
	var legacy_selected := PLANNER.first_matching_facility(legacy_cards, _market_energy_plan(), false)
	var dock_selected := PLANNER.first_matching_facility(dock_cards, _market_energy_plan(), false)
	_expect(_same_planner_identity(legacy_selected, dock_selected), "%s blocked Planner selection is identical for retargeting" % reason_id)
	_expect(DRIVER._enabled_card_action_request(dock_selected).is_empty(), "%s cannot create an enabled Dock submission" % reason_id)


func _projection_bundle(
	catalog: CardRuntimeCatalogV06Resource,
	presentation: CardPresentationRuntimeService,
	table_query: TablePresentationViewModelQuery,
	dock_service: PlayerCardDockProjectionService,
	matching_available: bool,
	matching_reason_id: String
) -> Dictionary:
	var private_hand: Array = []
	var hand_sources: Array = []
	var legacy_cards: Array = []
	for spec in [
		{"slot": 1, "card_id": DECOY_CARD_ID, "available": true, "reason_id": "playable"},
		{"slot": 3, "card_id": MATCHING_CARD_ID, "available": matching_available, "reason_id": matching_reason_id},
	]:
		var row := _real_hand_row(
			catalog,
			presentation,
			table_query,
			int(spec.get("slot", -1)),
			str(spec.get("card_id", "")),
			bool(spec.get("available", false)),
			str(spec.get("reason_id", "invalid_payload"))
		)
		if row.is_empty():
			return {}
		private_hand.append((row.get("private_card", {}) as Dictionary).duplicate(true))
		hand_sources.append((row.get("hand_source", {}) as Dictionary).duplicate(true))
		legacy_cards.append((row.get("legacy_card", {}) as Dictionary).duplicate(true))
	var projection := dock_service.compose_shared_v06(
		0,
		"player.0",
		AUTHORIZATION_REVISION,
		SOURCE_REVISION,
		private_hand,
		hand_sources,
		legacy_cards
	)
	if not bool(DOCK_PROJECTION.validation_report(projection).get("valid", false)):
		return {}
	var normal_cards: Array = projection.get("normal_cards", []) as Array
	var dock_cards := DRIVER._facility_cards_with_stable_identity(normal_cards)
	if dock_cards.size() != legacy_cards.size():
		return {}
	return {
		"valid": true,
		"legacy_cards": legacy_cards.duplicate(true),
		"dock_cards": dock_cards.duplicate(true),
		"projection": projection.duplicate(true),
	}


func _real_hand_row(
	catalog: CardRuntimeCatalogV06Resource,
	presentation: CardPresentationRuntimeService,
	table_query: TablePresentationViewModelQuery,
	slot: int,
	card_id: String,
	available: bool,
	reason_id: String
) -> Dictionary:
	var definition := catalog.card_snapshot(card_id)
	if definition.is_empty():
		return {}
	var skill_variant: Variant = table_query.call("_normalized_v06_skill", definition)
	if not (skill_variant is Dictionary):
		return {}
	var skill := (skill_variant as Dictionary).duplicate(true)
	var card_source_variant: Variant = table_query.call("_card_source", skill)
	if not (card_source_variant is Dictionary):
		return {}
	var private_card := definition.duplicate(true)
	private_card["slot_index"] = slot
	private_card["card_id"] = card_id
	private_card["runtime_instance_id"] = "runtime:alpha04-dock-parity:%d" % slot
	private_card["kind"] = "facility"
	private_card["rank"] = int((definition.get("machine", {}) as Dictionary).get("rank", 1))
	private_card["persistent"] = false
	var offer := _card_play_offer(private_card, slot, available, reason_id)
	if not bool(OFFER.validation_report(offer).get("valid", false)):
		return {}
	var hand_source := {
		"slot": slot,
		"card": (card_source_variant as Dictionary).duplicate(true),
		"eligibility": {
			"allowed": available,
			"actionable": available,
			"reason_code": "playable" if available else reason_id,
		},
		"game_action_offer": offer.duplicate(true),
	}
	var legacy_card := presentation.compose_hand_card(hand_source)
	if legacy_card.is_empty():
		return {}
	return {
		"private_card": private_card,
		"hand_source": hand_source,
		"legacy_card": legacy_card,
	}


func _card_play_offer(
	private_card: Dictionary,
	slot: int,
	available: bool,
	reason_id: String
) -> Dictionary:
	var wire_reason := "none" if available \
		else reason_id.strip_edges().to_lower().replace("_", "-")
	return OFFER.build({
		"schema_version": OFFER.SCHEMA_VERSION,
		"semantic_action_id": INTENT.ACTION_CARD_PLAY,
		"action_family_id": INTENT.FAMILY_CARD_PLAY,
		"source_revision": SOURCE_REVISION,
		"actor_scope": "authorized_actor",
		"public_or_private_target_spec": {
			"visibility_scope_id": "viewer_private",
			"target_kind_id": "stable-ids",
			"target_bindings": [
				{
					"target_role_id": "card_instance_id",
					"target_id": CARD_BINDING.private_instance_ref(private_card, slot),
				},
				{
					"target_role_id": "hand_slot_id",
					"target_id": CARD_BINDING.hand_slot_ref(slot),
				},
			],
			"requires_target": true,
		},
		"legality_state": "available" if available else "disabled",
		"disabled_reason_id": wire_reason,
		"cost_spec": {
			"cost_kind_id": "domain-owned",
			"amount_units": 0,
			"resource_id": "none",
		},
		"requirement_spec": {
			"requirement_ids": ["domain-legality"],
			"source_revision_required": true,
		},
		"consequence_spec": {
			"committed_effect_refs": [],
			"refresh_scope": "full",
		},
		"presentation_token_ids": ["action.card.play", "feedback.card.play"],
	})


func _market_energy_plan() -> Dictionary:
	return {
		"ready": true,
		"stop": false,
		"reason_id": "missing_matching_market",
		"desired_facility_kind": "market",
		"desired_direction": "demand",
		"commodity_id": "commodity.energy",
		"industry_id": "energy",
	}


func _is_catalog_facility(definition: Dictionary, facility_kind: String, industry_id: String) -> bool:
	var machine: Dictionary = definition.get("machine", {}) \
		if definition.get("machine", {}) is Dictionary else {}
	var payload: Dictionary = machine.get("effect_payload", {}) \
		if machine.get("effect_payload", {}) is Dictionary else {}
	return str(machine.get("category_id", "")) == "facility" \
		and str(payload.get("facility_kind", "")) == facility_kind \
		and str(payload.get("industry_id", "")) == industry_id


func _card_by_id(cards: Array, card_id: String) -> Dictionary:
	for card_variant in cards:
		if card_variant is Dictionary \
				and str((card_variant as Dictionary).get("card_id", "")) == card_id:
			return (card_variant as Dictionary).duplicate(true)
	return {}


func _same_planner_identity(legacy_card: Dictionary, dock_card: Dictionary) -> bool:
	return not legacy_card.is_empty() and not dock_card.is_empty() \
		and str(legacy_card.get("card_id", "")) == str(dock_card.get("card_id", "")) \
		and str(legacy_card.get("card_instance_ref", "")) == str(dock_card.get("card_instance_ref", "")) \
		and str(legacy_card.get("facility_kind", "")) == str(dock_card.get("facility_kind", "")) \
		and str(legacy_card.get("industry_id", "")) == str(dock_card.get("industry_id", ""))


func _canonical_reason(card: Dictionary) -> String:
	return "playable" if bool(card.get("actionable", false)) \
		else str(card.get("play_reason_id", "invalid_payload"))


func _same_offer(legacy_card: Dictionary, dock_card: Dictionary) -> bool:
	var legacy_offer := _legacy_offer(legacy_card)
	var dock_offer: Dictionary = dock_card.get("game_action_offer", {}) \
		if dock_card.get("game_action_offer", {}) is Dictionary else {}
	return not legacy_offer.is_empty() \
		and legacy_offer == dock_offer \
		and bool(OFFER.validation_report(dock_offer).get("valid", false)) \
		and str(legacy_offer.get("offer_fingerprint", "")) \
			== str(dock_offer.get("offer_fingerprint", ""))


func _legacy_offer(card: Dictionary) -> Dictionary:
	var actions: Array = card.get("actions", []) if card.get("actions", []) is Array else []
	if actions.is_empty() or not (actions[0] is Dictionary):
		return {}
	var offer: Variant = (actions[0] as Dictionary).get("game_action_offer", {})
	return (offer as Dictionary).duplicate(true) if offer is Dictionary else {}


func _offer_fingerprint(card: Dictionary) -> String:
	return str(_legacy_offer(card).get("offer_fingerprint", ""))


func _free_nodes(presentation: Node, table_query: Node) -> void:
	if presentation != null:
		presentation.free()
	if table_query != null:
		table_query.free()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("ALPHA04_DOCK_LEGACY_PLANNER_PARITY_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("ALPHA04_DOCK_LEGACY_PLANNER_PARITY_TEST: %s" % failure)
	print(
		"ALPHA04_DOCK_LEGACY_PLANNER_PARITY_TEST|status=FAIL|checks=%d|failures=%d" \
			% [_checks, _failures.size()]
	)
	quit(1)
