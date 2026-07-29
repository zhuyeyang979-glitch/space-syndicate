extends SceneTree

const PROJECTION := preload("res://scripts/presentation/player_card_dock_projection_v1.gd")
const SERVICE := preload("res://scripts/presentation/player_card_dock_projection_service.gd")
const OFFER := preload("res://scripts/semantic/game_action_offer_v1.gd")
const INTENT := preload("res://scripts/semantic/game_action_intent_v1.gd")
const CARD_BINDING := preload("res://scripts/semantic/game_action_card_binding_v1.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	_run()


func _run() -> void:
	var normal_id := "facility.market.technology.rank-1"
	var commodity_id := "commodity.star-dew-berry.rank-2"
	var bound_id := "monster.guard.bound-action"
	var normal_offer := _offer(0, 7, true)
	var commodity_offer := _offer(1, 7, false)
	var bound_offer := _offer(5, 7, true)
	var private_hand := [
		{
			"slot_index": 0,
			"card_id": normal_id,
			"runtime_instance_id": "runtime:normal:1",
			"kind": "facility",
			"rank": 1,
			"persistent": false,
			"machine": {
				"card_id": normal_id,
				"family_id": "facility.market.technology",
				"category_id": "facility",
				"rank": 1,
				"counts_toward_hand_limit": true,
			},
		},
		{
			"slot_index": 1,
			"card_id": commodity_id,
			"runtime_instance_id": "runtime:commodity:1",
			"kind": "commodity",
			"rank": 2,
			"persistent": false,
			"machine": {
				"card_id": commodity_id,
				"family_id": "commodity.star-dew-berry",
				"category_id": "commodity",
				"rank": 2,
				"counts_toward_hand_limit": true,
				"target_kind": "same-industry-factory-or-market",
				"effect_payload": {"product_id": "star-dew-berry", "industry_id": "life"},
			},
		},
		{
			"slot_index": 5,
			"card_id": bound_id,
			"runtime_instance_id": "runtime:bound:1",
			"kind": "monster_bound_action",
			"rank": 1,
			"persistent": true,
			"bound_monster_uid": 42,
			"cooldown_left": 0.0,
		},
	]
	var hand_sources := [
		_source(0, normal_id, "facility", normal_offer, {
			"card_id": normal_id, "family_id": "facility.market.technology",
			"category_id": "facility", "rank": 1,
		}),
		_source(1, commodity_id, "commodity", commodity_offer, {
			"card_id": commodity_id, "family_id": "commodity.star-dew-berry",
			"category_id": "commodity", "rank": 2,
			"target_kind": "same-industry-factory-or-market",
			"effect_payload": {"product_id": "star-dew-berry", "industry_id": "life"},
		}),
		_source(5, bound_id, "monster_bound_action", bound_offer, {
			"card_id": bound_id, "family_id": "monster.guard",
			"category_id": "legacy-v06", "rank": 1,
		}),
	]
	(hand_sources[2] as Dictionary)["card"]["skill"]["bound_monster_uid"] = 42
	var hand_viewmodels := [
		_viewmodel(0, "科技市场", "facility_v06", normal_offer, "facility.market.technology.rank-1"),
		_viewmodel(1, "星露莓 II", "commodity", commodity_offer, "commodity.star-dew-berry.rank-2"),
		_viewmodel(5, "怪兽守卫", "monster_bound_action", bound_offer, "monster.guard.bound-action"),
	]
	var service := SERVICE.new()
	var projection := service.compose_shared_v06(
		0, "player.0", 3, 7, private_hand, hand_sources, hand_viewmodels
	)
	_expect(bool(PROJECTION.validation_report(projection).get("valid", false)), "typed projection validates")
	_expect(PROJECTION.matches_viewer_authorization(projection, 0, 3), "projection accepts its exact viewer authorization binding")
	_expect(not PROJECTION.matches_viewer_authorization(projection, 1, 3), "projection rejects a wrong viewer")
	_expect(not PROJECTION.matches_viewer_authorization(projection, 0, 4), "projection rejects a stale authorization revision")
	_expect(str(projection.get("capacity_mode", "")) == "SHARED_V06" and str(projection.get("runtime_ruleset_id", "")) == "v0.6", "v0.6 projection declares the shared capacity mode")
	_expect(int(projection.get("normal_count", -1)) == 1 and int(projection.get("commodity_count", -1)) == 1 and int(projection.get("shared_capacity_count", -1)) == 2 and int(projection.get("shared_capacity_limit", -1)) == 5, "normal and commodity pools display separate counts over one real shared 5-card capacity")
	_expect((projection.get("bound_actions", []) as Array).size() == 1, "bound action is projected in the zero-capacity pool")
	var normal := (projection.get("normal_cards", []) as Array)[0] as Dictionary
	var commodity := (projection.get("commodity_cards", []) as Array)[0] as Dictionary
	var bound := (projection.get("bound_actions", []) as Array)[0] as Dictionary
	_expect(str(normal.get("card_instance_id", "")) == str(OFFER.target_ids(normal_offer).get("card_instance_id", "")) and normal.get("game_action_offer", {}) == normal_offer, "normal card preserves its opaque authoritative instance binding and exact Action Spine offer")
	_expect(str(commodity.get("commodity_id", "")) == "star-dew-berry" and str(commodity.get("color_id", "")) == "life" and int(commodity.get("level", 0)) == 2 and int(commodity.get("base_units", 0)) == 2, "commodity card projects identity, color, level and linear base units")
	_expect(str(commodity.get("play_state", "")) == "disabled" and str(commodity.get("disabled_reason_id", "")) == "target-required", "disabled commodity keeps its authoritative offer reason")
	_expect(str(bound.get("source_entity_id", "")) == "monster.42" and str(bound.get("source_entity_kind", "")) == "monster" and int(bound.get("charges", 0)) == -1 and bool(bound.get("enabled", false)), "bound action projects its source and reusable v0.6 charge sentinel without capacity cost")
	_expect(_is_closed_data(projection) and not _contains_forbidden_key(projection), "projection is stable pure data with no rival, owner, RNG or object fields")

	var invalid_bound_hand := private_hand.duplicate(true)
	(invalid_bound_hand[2] as Dictionary)["bound_monster_uid"] = -1
	var invalidated := service.compose_shared_v06(
		0, "player.0", 3, 7, invalid_bound_hand, hand_sources, hand_viewmodels
	)
	_expect(not invalidated.is_empty() and (invalidated.get("bound_actions", []) as Array).is_empty() and int(invalidated.get("shared_capacity_count", -1)) == 2, "invalidated source removes the bound action without changing shared capacity")

	var rival_hand := private_hand.duplicate(true)
	(rival_hand[0] as Dictionary)["rival_cash"] = 999999
	var ignored_private_input := service.compose_shared_v06(
		0, "player.0", 3, 7, rival_hand, hand_sources, hand_viewmodels
	)
	_expect(not ignored_private_input.is_empty() and not JSON.stringify(ignored_private_input).contains("999999"), "unrequested rival-like input cannot enter the allowlisted projection")

	var stale_sources := hand_sources.duplicate(true)
	(stale_sources[0] as Dictionary)["game_action_offer"] = _offer(0, 8, true)
	_expect(service.compose_shared_v06(0, "player.0", 3, 8, private_hand, stale_sources, hand_viewmodels).is_empty(), "offer/viewmodel revision mismatch fails closed")
	_expect(service.compose_shared_v06(1, "player.0", 3, 7, private_hand, hand_sources, hand_viewmodels).is_empty(), "viewer/actor mismatch fails closed")
	_expect(service.compose_shared_v06(0, "player.0", 0, 7, private_hand, hand_sources, hand_viewmodels).is_empty(), "missing or stale authorization revision fails closed")

	var current_actor_offer := _offer(0, 7, true, "current_actor")
	var current_actor_sources := hand_sources.duplicate(true)
	var current_actor_viewmodels := hand_viewmodels.duplicate(true)
	_replace_offer(current_actor_sources, current_actor_viewmodels, 0, current_actor_offer)
	_expect(service.compose_shared_v06(0, "player.0", 3, 7, private_hand, current_actor_sources, current_actor_viewmodels).is_empty(), "projection service rejects a card offer outside authorized_actor scope")
	_expect(_projection_with_offer(projection, "normal_cards", 0, current_actor_offer).is_empty(), "projection contract rejects current_actor card offers")
	_expect(_projection_with_offer(projection, "normal_cards", 0, _offer(0, 7, true, "authorized_actor", "public")).is_empty(), "projection contract rejects publicly scoped private card targets")
	_expect(_projection_with_offer(projection, "normal_cards", 0, _offer(0, 7, true, "authorized_actor", "viewer_private", true)).is_empty(), "projection contract rejects pre-bound player targets")
	_expect(_projection_with_offer(projection, "normal_cards", 0, _non_card_offer(7)).is_empty(), "projection contract rejects non-card-play offers")

	for pool_id in ["normal_cards", "commodity_cards", "bound_actions"]:
		for field in ["display_name", "illustration_key"]:
			_expect(
				_projection_with_row_field(projection, pool_id, 0, field, 17).is_empty(),
				"%s %s must remain a String" % [pool_id, field]
			)
	_expect(_projection_with_row_field(projection, "commodity_cards", 0, "play_state", "available").is_empty(), "disabled card cannot be projected as selectable")
	_expect(_projection_with_row_field(projection, "bound_actions", 0, "enabled", false).is_empty(), "available bound action cannot be projected as disabled independently of its offer")

	var legacy_private := {
		"name": "Legacy Monster Guard",
		"kind": "monster_bound_action",
		"rank": 1,
		"runtime_instance_id": "runtime:legacy:one",
		"bound_monster_uid": 42,
	}
	var legacy_other_instance := legacy_private.duplicate(true)
	legacy_other_instance["rank"] = 4
	legacy_other_instance["runtime_instance_id"] = "runtime:legacy:two"
	legacy_other_instance["bound_monster_uid"] = 999
	legacy_other_instance["bound_military_uid"] = 77
	var legacy_id := CARD_BINDING.semantic_card_id(legacy_private, 0)
	_expect(not legacy_id.is_empty() and legacy_id.begins_with("legacy.card."), "legacy authored card name produces an opaque stable semantic identity")
	_expect(CARD_BINDING.semantic_card_id(legacy_other_instance, 8) == legacy_id, "legacy semantic identity excludes slot, rank, runtime instance and bound entity UIDs")
	_expect(CARD_BINDING.semantic_card_id({"name": "Legacy Monster Guard"}, 5) == legacy_id, "private card and presentation source use the same authored-only fallback")
	_expect(CARD_BINDING.semantic_card_id({"name": "Legacy Monster Strike"}, 0) != legacy_id, "different authored legacy cards keep distinct semantic identities")
	_expect(CARD_BINDING.semantic_card_id({"card_id": RefCounted.new()}, 0).is_empty(), "runtime objects cannot become authored semantic card identity")
	var legacy_offer := _offer(2, 7, true)
	var legacy_projection := service.compose_shared_v06(
		0,
		"player.0",
		3,
		7,
		[{
			"slot_index": 2,
			"name": "Legacy Monster Guard",
			"runtime_instance_id": "runtime:legacy:projection",
			"kind": "facility",
			"rank": 1,
			"machine": {
				"family_id": "legacy.monster-guard",
				"category_id": "facility",
				"rank": 1,
			},
		}],
		[_source(2, "Legacy Monster Guard", "facility", legacy_offer, {
			"family_id": "legacy.monster-guard",
			"category_id": "facility",
			"rank": 1,
		})],
		[_viewmodel(2, "旧版怪兽守卫", "facility", legacy_offer, "legacy.monster-guard")]
	)
	_expect(
		bool(PROJECTION.validation_report(legacy_projection).get("valid", false))
			and str(((legacy_projection.get("normal_cards", []) as Array)[0] as Dictionary).get("card_semantic_id", "")) == legacy_id,
		"projection service consumes the same legacy authored semantic identity as GameActionCardBindingV1"
	)

	var independent := projection.duplicate(true)
	independent.erase("projection_fingerprint")
	independent["runtime_ruleset_id"] = "v0.7"
	independent["capacity_mode"] = "INDEPENDENT_V07"
	independent["shared_capacity_limit"] = 10
	var future_projection := PROJECTION.build(independent)
	_expect(bool(PROJECTION.validation_report(future_projection).get("valid", false)) and int(future_projection.get("shared_capacity_limit", 0)) == 10, "the same typed shell supports the future independent 5+5 projection without changing v0.6")

	_finish()


func _source(slot: int, semantic_id: String, kind: String, offer: Dictionary, machine: Dictionary) -> Dictionary:
	return {
		"slot": slot,
		"card": {
			"skill": {
				"name": semantic_id,
				"card_id": semantic_id,
				"display_name": semantic_id,
				"kind": kind,
				"rank": int(machine.get("rank", 1)),
				"machine": machine.duplicate(true),
			},
		},
		"eligibility": {"allowed": str(offer.get("legality_state", "")) == "available"},
		"game_action_offer": offer.duplicate(true),
	}


func _viewmodel(slot: int, name: String, kind: String, offer: Dictionary, illustration_key: String) -> Dictionary:
	return {
		"slot": slot,
		"name": name,
		"kind": kind,
		"illustration_key": illustration_key,
		"actions": [{"game_action_offer": offer.duplicate(true)}],
	}


func _offer(
	slot: int,
	revision: int,
	available: bool,
	actor_scope: String = "authorized_actor",
	visibility_scope: String = "viewer_private",
	include_player_binding: bool = false
) -> Dictionary:
	var reason := "none" if available else "target-required"
	var target_bindings: Array = [
		{"target_role_id": "card_instance_id", "target_id": "card.instance.fixture-%d" % slot},
		{"target_role_id": "hand_slot_id", "target_id": "hand.slot.%d" % slot},
	]
	if include_player_binding:
		target_bindings.append({"target_role_id": "player_id", "target_id": "player.0"})
	return OFFER.build({
		"schema_version": OFFER.SCHEMA_VERSION,
		"semantic_action_id": INTENT.ACTION_CARD_PLAY,
		"action_family_id": INTENT.FAMILY_CARD_PLAY,
		"source_revision": revision,
		"actor_scope": actor_scope,
		"public_or_private_target_spec": {
			"visibility_scope_id": visibility_scope,
			"target_kind_id": "stable-ids",
			"target_bindings": target_bindings,
			"requires_target": true,
		},
		"legality_state": "available" if available else "disabled",
		"disabled_reason_id": reason,
		"cost_spec": {"cost_kind_id": "domain-owned", "amount_units": 0, "resource_id": "none"},
		"requirement_spec": {"requirement_ids": ["domain-legality"], "source_revision_required": true},
		"consequence_spec": {"committed_effect_refs": [], "refresh_scope": "full"},
		"presentation_token_ids": ["action.card.play", "feedback.card.play"],
	})


func _non_card_offer(revision: int) -> Dictionary:
	return OFFER.build({
		"schema_version": OFFER.SCHEMA_VERSION,
		"semantic_action_id": INTENT.ACTION_SESSION_END_TURN,
		"action_family_id": INTENT.FAMILY_SESSION,
		"source_revision": revision,
		"actor_scope": "authorized_actor",
		"public_or_private_target_spec": {
			"visibility_scope_id": "viewer_private",
			"target_kind_id": "none",
			"target_bindings": [],
			"requires_target": false,
		},
		"legality_state": "available",
		"disabled_reason_id": "none",
		"cost_spec": {"cost_kind_id": "domain-owned", "amount_units": 0, "resource_id": "none"},
		"requirement_spec": {"requirement_ids": ["domain-legality"], "source_revision_required": true},
		"consequence_spec": {"committed_effect_refs": [], "refresh_scope": "full"},
		"presentation_token_ids": ["action.session.end-turn"],
	})


func _replace_offer(
	sources: Array,
	viewmodels: Array,
	index: int,
	offer: Dictionary
) -> void:
	(sources[index] as Dictionary)["game_action_offer"] = offer.duplicate(true)
	var actions := (viewmodels[index] as Dictionary).get("actions", []) as Array
	(actions[0] as Dictionary)["game_action_offer"] = offer.duplicate(true)


func _projection_with_offer(
	projection: Dictionary,
	pool_id: String,
	index: int,
	offer: Dictionary
) -> Dictionary:
	var unsealed := projection.duplicate(true)
	unsealed.erase("projection_fingerprint")
	var row := (unsealed.get(pool_id, []) as Array)[index] as Dictionary
	row["game_action_offer"] = offer.duplicate(true)
	row["source_revision"] = int(offer.get("source_revision", 0))
	row["disabled_reason_id"] = str(offer.get("disabled_reason_id", "none"))
	if row.has("play_state"):
		row["play_state"] = str(offer.get("legality_state", "disabled"))
	else:
		row["enabled"] = str(offer.get("legality_state", "disabled")) == "available"
	return PROJECTION.build(unsealed)


func _projection_with_row_field(
	projection: Dictionary,
	pool_id: String,
	index: int,
	field: String,
	value: Variant
) -> Dictionary:
	var unsealed := projection.duplicate(true)
	unsealed.erase("projection_fingerprint")
	((unsealed.get(pool_id, []) as Array)[index] as Dictionary)[field] = value
	return PROJECTION.build(unsealed)


func _is_closed_data(value: Variant) -> bool:
	return SemanticWireV1.is_closed_data(value)


func _contains_forbidden_key(value: Variant) -> bool:
	return SemanticWireV1.contains_key_recursive(value, PROJECTION.FORBIDDEN_KEYS)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PLAYER_CARD_DOCK_PROJECTION_V1_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("PLAYER_CARD_DOCK_PROJECTION_V1_TEST: %s" % failure)
	print("PLAYER_CARD_DOCK_PROJECTION_V1_TEST|status=FAIL|checks=%d|failures=%d" % [_checks, _failures.size()])
	quit(1)
