extends RefCounted
class_name PlayerCardDockProjectionService

const PROJECTION := preload("res://scripts/presentation/player_card_dock_projection_v1.gd")
const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const OFFER := preload("res://scripts/semantic/game_action_offer_v1.gd")
const INTENT := preload("res://scripts/semantic/game_action_intent_v1.gd")
const CARD_BINDING := preload("res://scripts/semantic/game_action_card_binding_v1.gd")

const BOUND_MONSTER_KINDS := ["monster_bound_action"]
const BOUND_MILITARY_KINDS := ["military_command", "military_reusable_command"]


func compose_shared_v06(
	viewer_index: int,
	actor_id: String,
	authorization_revision: int,
	source_revision: int,
	private_hand: Array,
	hand_sources: Array,
	hand_viewmodels: Array
) -> Dictionary:
	if viewer_index < 0 or actor_id != "player.%d" % viewer_index \
			or authorization_revision <= 0 or source_revision < 0:
		return {}
	var private_by_slot := _by_slot(private_hand, "slot_index")
	var source_by_slot := _by_slot(hand_sources, "slot")
	var viewmodel_by_slot := _by_slot(hand_viewmodels, "slot")
	if private_by_slot.size() != private_hand.size() \
			or source_by_slot.size() != hand_sources.size() \
			or viewmodel_by_slot.size() != hand_viewmodels.size() \
			or private_by_slot.keys() != source_by_slot.keys() \
			or private_by_slot.keys() != viewmodel_by_slot.keys():
		return {}
	var normal_cards: Array = []
	var commodity_cards: Array = []
	var bound_actions: Array = []
	var slots: Array = private_by_slot.keys()
	slots.sort()
	for slot_variant in slots:
		var slot := int(slot_variant)
		var private_card := private_by_slot.get(slot) as Dictionary
		var source := source_by_slot.get(slot) as Dictionary
		var viewmodel := viewmodel_by_slot.get(slot) as Dictionary
		var offer := _offer(source, viewmodel, slot)
		if offer.is_empty():
			return {}
		var skill := _skill(source)
		var card_semantic_id := CARD_BINDING.semantic_card_id(private_card, slot)
		if card_semantic_id.is_empty() \
				or not _source_identity_matches(skill, card_semantic_id, slot):
			return {}
		var kind := _card_kind(private_card, skill, viewmodel)
		var pool := _pool_id(private_card, skill, kind)
		if pool == "bound":
			var bound := _bound_action(private_card, skill, viewmodel, offer, card_semantic_id, kind)
			# Legacy v0.6 invalidates a bound source in place.  The viewer projection
			# removes that action immediately instead of presenting a dead card as a
			# second state owner.
			if not bound.is_empty():
				bound_actions.append(bound)
		elif pool == "commodity":
			var commodity := _commodity_card(private_card, skill, viewmodel, offer, card_semantic_id)
			if commodity.is_empty():
				return {}
			commodity_cards.append(commodity)
		else:
			var normal := _normal_card(private_card, skill, viewmodel, offer, card_semantic_id, kind)
			if normal.is_empty():
				return {}
			normal_cards.append(normal)
	return PROJECTION.build({
		"schema_version": PROJECTION.SCHEMA_VERSION,
		"viewer_index": viewer_index,
		"actor_id": actor_id,
		"authorization_revision": authorization_revision,
		"source_revision": source_revision,
		"runtime_ruleset_id": PROJECTION.RUNTIME_RULESET_V06,
		"capacity_mode": PROJECTION.CAPACITY_MODE_SHARED_V06,
		"visibility_scope": "viewer_private",
		"normal_cards": normal_cards,
		"commodity_cards": commodity_cards,
		"bound_actions": bound_actions,
		"normal_count": normal_cards.size(),
		"normal_limit": PROJECTION.CARD_LIMIT,
		"commodity_count": commodity_cards.size(),
		"commodity_limit": PROJECTION.CARD_LIMIT,
		"shared_capacity_count": normal_cards.size() + commodity_cards.size(),
		"shared_capacity_limit": PROJECTION.CARD_LIMIT,
	})


func _normal_card(
	private_card: Dictionary,
	skill: Dictionary,
	viewmodel: Dictionary,
	offer: Dictionary,
	card_semantic_id: String,
	kind: String
) -> Dictionary:
	var revision := int(offer.get("source_revision", 0))
	var machine := _dictionary(skill.get("machine", {}))
	var payload := _dictionary(machine.get("effect_payload", {}))
	return {
		"card_instance_id": str(OFFER.target_ids(offer).get("card_instance_id", "")),
		"card_semantic_id": card_semantic_id,
		"display_name": str(viewmodel.get("name", skill.get("display_name", skill.get("name", card_semantic_id)))),
		"illustration_key": str(viewmodel.get("illustration_key", "")),
		"category_id": _stable_id(kind, "ordinary"),
		"facility_kind": _stable_id(str(payload.get("facility_kind", "")), "none"),
		"industry_id": _stable_id(str(payload.get("industry_id", "")), "none"),
		"rank": maxi(1, int(private_card.get("rank", skill.get("rank", 1)))),
		"play_state": str(offer.get("legality_state", "disabled")),
		"disabled_reason_id": str(offer.get("disabled_reason_id", "action-disabled")),
		"game_action_offer": offer.duplicate(true),
		"source_revision": revision,
	}


func _commodity_card(
	private_card: Dictionary,
	skill: Dictionary,
	viewmodel: Dictionary,
	offer: Dictionary,
	card_semantic_id: String
) -> Dictionary:
	var machine := _dictionary(skill.get("machine", {}))
	var payload := _dictionary(machine.get("effect_payload", {}))
	var level := maxi(1, int(private_card.get("rank", skill.get("rank", machine.get("rank", 1)))))
	var commodity_id := _stable_id(
		str(payload.get("product_id", skill.get("commodity_id", machine.get("family_id", "")))),
		"commodity.%s" % WIRE.fingerprint({"card_semantic_id": card_semantic_id}).left(24)
	)
	var color_id := _stable_id(
		str(payload.get("industry_id", skill.get("industry_id", machine.get("industry_id", "")))),
		"unknown"
	)
	return {
		"commodity_card_instance_id": str(OFFER.target_ids(offer).get("card_instance_id", "")),
		"card_semantic_id": card_semantic_id,
		"commodity_id": commodity_id,
		"color_id": color_id,
		"level": level,
		"base_units": level,
		"display_name": str(viewmodel.get("name", skill.get("display_name", skill.get("name", card_semantic_id)))),
		"illustration_key": str(viewmodel.get("illustration_key", "")),
		"play_state": str(offer.get("legality_state", "disabled")),
		"disabled_reason_id": str(offer.get("disabled_reason_id", "action-disabled")),
		"legal_target_summary": str(machine.get("target_kind", skill.get("target_type", "none"))),
		"game_action_offer": offer.duplicate(true),
		"source_revision": int(offer.get("source_revision", 0)),
	}


func _bound_action(
	private_card: Dictionary,
	skill: Dictionary,
	viewmodel: Dictionary,
	offer: Dictionary,
	card_semantic_id: String,
	kind: String
) -> Dictionary:
	var source_kind := "monster" if kind in BOUND_MONSTER_KINDS else "military"
	var source_uid := int(
		private_card.get(
			"bound_monster_uid" if source_kind == "monster" else "bound_military_uid",
			skill.get("bound_monster_uid" if source_kind == "monster" else "bound_military_uid", 0)
		)
	)
	if source_uid <= 0:
		return {}
	var cooldown_seconds := maxi(0, int(ceil(float(
		private_card.get("cooldown_left", skill.get("cooldown_left", 0.0))
	))))
	var action_class := str(
		skill.get("military_command", skill.get("action_kind", kind))
	)
	var charges := int(skill.get("charges", private_card.get("charges", -1)))
	return {
		"bound_action_instance_id": str(OFFER.target_ids(offer).get("card_instance_id", "")),
		"action_semantic_id": card_semantic_id,
		"source_entity_id": "%s.%d" % [source_kind, source_uid],
		"source_entity_kind": source_kind,
		"display_name": str(viewmodel.get("name", skill.get("display_name", skill.get("name", card_semantic_id)))),
		"illustration_key": str(viewmodel.get("illustration_key", "")),
		"action_class": _stable_id(action_class, kind),
		"cooldown": cooldown_seconds,
		"charges": maxi(-1, charges),
		"enabled": str(offer.get("legality_state", "disabled")) == "available",
		"disabled_reason_id": str(offer.get("disabled_reason_id", "action-disabled")),
		"game_action_offer": offer.duplicate(true),
		"source_revision": int(offer.get("source_revision", 0)),
	}


func _offer(source: Dictionary, viewmodel: Dictionary, slot: int) -> Dictionary:
	var value: Variant = source.get("game_action_offer", {})
	if not (value is Dictionary) or not bool(OFFER.validation_report(value).get("valid", false)):
		return {}
	var offer := OFFER.detached_copy(value)
	var target_spec := offer.get("public_or_private_target_spec") as Dictionary
	var targets := OFFER.target_ids(offer)
	if str(offer.get("semantic_action_id", "")) != INTENT.ACTION_CARD_PLAY \
			or str(offer.get("actor_scope", "")) != "authorized_actor" \
			or str(target_spec.get("visibility_scope_id", "")) != "viewer_private" \
			or str(targets.get("hand_slot_id", "")) != CARD_BINDING.hand_slot_ref(slot) \
			or str(targets.get("card_instance_id", "")).is_empty() \
			or targets.has("player_id"):
		return {}
	var actions: Array = viewmodel.get("actions", []) if viewmodel.get("actions", []) is Array else []
	if actions.is_empty() or not (actions[0] is Dictionary) \
			or (actions[0] as Dictionary).get("game_action_offer", {}) != offer:
		return {}
	return offer


func _pool_id(private_card: Dictionary, skill: Dictionary, kind: String) -> String:
	if kind in BOUND_MONSTER_KINDS or kind in BOUND_MILITARY_KINDS:
		return "bound"
	var machine := _dictionary(skill.get("machine", {}))
	var category_id := str(machine.get("category_id", skill.get("category_id", private_card.get("kind", ""))))
	return "commodity" if category_id == "commodity" else "normal"


func _card_kind(private_card: Dictionary, skill: Dictionary, viewmodel: Dictionary) -> String:
	var machine := _dictionary(skill.get("machine", {}))
	return str(
		viewmodel.get(
			"kind",
			skill.get("kind", machine.get("category_id", private_card.get("kind", "ordinary")))
		)
	)


func _source_identity_matches(skill: Dictionary, semantic_id: String, slot: int) -> bool:
	var source_semantic_id := CARD_BINDING.semantic_card_id(skill, slot)
	return not source_semantic_id.is_empty() and source_semantic_id == semantic_id


func _skill(source: Dictionary) -> Dictionary:
	var card := _dictionary(source.get("card", {}))
	return _dictionary(card.get("skill", {}))


func _by_slot(values: Array, field: String) -> Dictionary:
	var result := {}
	for value_variant in values:
		if not (value_variant is Dictionary):
			continue
		var value := value_variant as Dictionary
		var slot := int(value.get(field, -1))
		if slot < 0 or result.has(slot):
			continue
		result[slot] = value.duplicate(true)
	return result


func _stable_id(value: String, fallback: String) -> String:
	var normalized := value.strip_edges().to_lower().replace("_", "-").replace(" ", "-")
	if WIRE.is_stable_id(normalized):
		return normalized
	return fallback


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}
