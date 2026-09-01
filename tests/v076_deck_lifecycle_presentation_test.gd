extends SceneTree

const SurfaceScene := preload(
	"res://scenes/ui/v076/V076DeckLifecyclePresentation.tscn"
)
const DirectorScript := preload(
	"res://scripts/presentation/v076_presentation_animation_director.gd"
)

var _checks := 0
var _failures: Array[String] = []
var _finished_receipt_ids: Array[String] = []
var _director: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var surface := SurfaceScene.instantiate() as Control
	_expect(surface != null, "deck lifecycle presentation scene instantiates")
	if surface == null:
		_finish()
		return
	surface.position = Vector2(320.0, 620.0)
	surface.size = Vector2(330.0, 38.0)
	root.add_child(surface)
	_director = DirectorScript.new()
	_director.name = "DeckTestPresentationAnimationDirector"
	root.add_child(_director)
	surface.animation_finished.connect(_on_animation_finished)
	await process_frame
	await process_frame
	surface.call("set_motion_policy", false, true)
	var snapshot := {
		"personal_dbg": {
			"facts": {
				"revision": 7,
				"draw_pile_count": 4,
				"discard_count": 1,
				"hand_count": 4,
				"hand": [_card("dbg.local.1")],
				"discard": [_card("dbg.local.discard")],
			}
		}
	}
	surface.call("apply_private_projection", snapshot)
	var initial := surface.call("debug_snapshot") as Dictionary
	_expect(bool(initial.get("draw_pile_visible", false)), "draw pile is a visible production object")
	_expect(bool(initial.get("discard_pile_visible", false)), "discard pile is a visible production object")
	_expect(int(initial.get("draw_pile_count", -1)) == 4, "draw pile count consumes private projection")
	_expect(int(initial.get("discard_count", -1)) == 1, "discard pile count consumes private projection")

	var acquisition := {
		"accepted": true,
		"schema": "V075ApplicationReceiptV1",
		"intent_id": "intent.deck.acquire.1",
		"intent_kind": "track.acquire",
		"destination_zone": "discard",
		"card_kind": "normal_card",
	}
	var acquired := surface.call(
		"consume_acquisition_receipt",
		acquisition,
		_card("dbg.local.new"),
		Rect2(Vector2(120.0, 100.0), Vector2(150.0, 111.0)),
		Rect2()
	) as Dictionary
	_expect(bool(acquired.get("accepted", false)), "accepted purchase queues CARD_ACQUIRE")
	_expect(str(acquired.get("target_zone", "")) == "discard", "purchase animation targets authoritative discard zone")
	await process_frame
	await process_frame
	var after_acquire := surface.call("debug_snapshot") as Dictionary
	_expect(int(after_acquire.get("acquire_animation_count", 0)) == 1, "purchase receipt animates exactly once")
	_expect(int(after_acquire.get("target_zone_parity_count", 0)) == 1, "purchase target Rect matches authority zone")
	var replay := surface.call(
		"consume_acquisition_receipt",
		acquisition,
		_card("dbg.local.new"),
		Rect2(Vector2(120.0, 100.0), Vector2(150.0, 111.0)),
		Rect2()
	) as Dictionary
	_expect(bool(replay.get("replayed", false)), "duplicate acquisition receipt is suppressed")

	var shuffle := _deck_receipt("deck.shuffle.1", "DECK_SHUFFLE")
	shuffle["reshuffle_count"] = 1
	_expect(bool((surface.call("consume_deck_lifecycle_receipt", shuffle) as Dictionary).get("accepted", false)), "authority shuffle receipt queues DECK_SHUFFLE")
	var draw := _deck_receipt("deck.draw.1", "CARD_DRAW")
	draw["drawn_card_projections"] = [_card("dbg.local.drawn")]
	draw["drawn_card_count"] = 1
	draw["hand_target_global_rect"] = Rect2(Vector2(680.0, 600.0), Vector2(260.0, 100.0))
	draw["cue_id"] = "CARD_DRAW"
	var queued_draw := _director.call(
		"enqueue_receipt",
		draw.duplicate(true),
		{"current_player_authorized": true}
	) as Dictionary
	_expect(str(queued_draw.get("cue_id", "")) == "CARD_DRAW", "Director queues the parent CARD_DRAW receipt")
	_expect(bool((surface.call("consume_deck_lifecycle_receipt", draw) as Dictionary).get("accepted", false)), "authority draw receipt queues CARD_DRAW")
	var discard := _deck_receipt("deck.discard.1", "CARD_DISCARD")
	discard["card_projection"] = _card("dbg.local.played")
	discard["source_global_rect"] = Rect2(Vector2(600.0, 280.0), Vector2(120.0, 170.0))
	_expect(bool((surface.call("consume_deck_lifecycle_receipt", discard) as Dictionary).get("accepted", false)), "owner-private play receipt queues CARD_DISCARD")
	await process_frame
	await process_frame
	var terminal := surface.call("debug_snapshot") as Dictionary
	_expect(int(terminal.get("shuffle_animation_count", 0)) == 1, "shuffle receipt animation is exact-once")
	_expect(int(terminal.get("draw_animation_count", 0)) == 1, "draw animation covers the drawn card")
	_expect(int(terminal.get("enter_hand_animation_count", 0)) == 1, "draw chains into the hand anchor")
	_expect(int(terminal.get("discard_animation_count", 0)) == 1, "public play chains into discard")
	_expect((terminal.get("evidence", []) as Array).size() >= 4, "start/mid/end Rect evidence is retained")
	_expect(int(terminal.get("receipt_collision_count", -1)) == 0, "receipt identities have no collision")
	_expect(int(terminal.get("animation_gameplay_mutation_count", -1)) == 0, "animation never mutates gameplay")
	_expect(int(terminal.get("animation_rng_draw_delta", -1)) == 0, "animation draws no RNG")
	_expect(int(terminal.get("animation_authority_sequence_delta", -1)) == 0, "animation advances no authority sequence")
	_expect(int(terminal.get("animation_deck_order_mutation_count", -1)) == 0, "animation never changes deck order")
	_expect(int(terminal.get("animation_card_zone_mutation_count", -1)) == 0, "animation never changes card zones")
	_expect(_finished_receipt_ids.count("deck.draw.1") == 1, "draw batch emits the parent receipt exactly once")
	_expect(not _finished_receipt_ids.has("deck.draw.1.00"), "draw child receipt never escapes as a Director completion identity")
	_expect(int(terminal.get("draw_child_finish_count", 0)) == 1 and int(terminal.get("draw_batch_finish_count", 0)) == 1, "draw child completion aggregates into one finished batch")
	_expect(int(terminal.get("active_draw_batch_count", -1)) == 0 and int(terminal.get("active_draw_child_count", -1)) == 0, "draw aggregation ledgers drain")
	var director_terminal := _director.call("animation_debug_snapshot") as Dictionary
	_expect(int(director_terminal.get("queued_cue_count", -1)) == 0 and int(director_terminal.get("finished_cue_count", -1)) == 1, "parent draw completion drains the unique Director queue")
	_expect(not bool(terminal.get("instant_test_mode_production_ui_reachable", true)), "instant mode is not production UI reachable")

	surface.queue_free()
	_director.queue_free()
	await process_frame
	_finish()


func _card(instance_id: String) -> Dictionary:
	return {
		"instance_id": instance_id,
		"definition_id": "facility.factory.industry.rank_1",
		"card_definition_id": "facility.factory.industry.rank_1",
		"name": "轨道工厂",
		"card_kind": "normal_card",
		"card_type": "factory",
		"primary_color": "industry",
		"level": 1,
		"short_effect": "在目标地区建设工厂",
	}


func _deck_receipt(receipt_id: String, event_kind: String) -> Dictionary:
	return {
		"schema": "V076OwnerPrivateDeckLifecycleReceiptV1",
		"accepted": true,
		"receipt_scope": "owner_private",
		"receipt_id": receipt_id,
		"event_kind": event_kind,
		"owner_player_id": "player.local",
		"source_authority_receipt_id": "authority.%s" % receipt_id,
		"source_authority_receipt_fingerprint": receipt_id.sha256_text(),
		"draw_pile_count": 3,
		"discard_count": 0,
		"hand_count": 5,
	}


func _on_animation_finished(receipt_id: String, _cue_id: String) -> void:
	_finished_receipt_ids.append(receipt_id)
	if is_instance_valid(_director):
		_director.call("finish_receipt", receipt_id)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	print("V076_DECK_LIFECYCLE_PRESENTATION_TEST|status=%s|passed=%d|total=%d|failures=%s" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks - _failures.size(),
		_checks,
		JSON.stringify(_failures),
	])
	quit(0 if _failures.is_empty() else 1)
