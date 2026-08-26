extends CanvasLayer
class_name CommercialShowcaseVisualLayer

## Read-only presentation stage for CommercialPresentationShowcase.
##
## The production scene stays mounted behind this fixture.  This layer reads only
## the parent's episode evidence and draws authored, deterministic poses.  It does
## not submit commands, advance Tick, reveal hidden authority state, or own rules.


class FixtureStage:
	extends Control

	const REFERENCE_SIZE := Vector2(1600.0, 960.0)
	# The mask spans the complete production content width.  The underlying main
	# stays mounted, but its empty hand/pile controls cannot contradict fixture
	# projections such as 4/5 or 5/5 at the exposed right edge.
	const STAGE_RECT := Rect2(10.0, 84.0, 1580.0, 824.0)
	const INK := Color(0.86, 0.93, 1.0, 1.0)
	const MUTED := Color(0.51, 0.63, 0.74, 1.0)
	const TEAL := Color(0.20, 0.91, 0.78, 1.0)
	const BLUE := Color(0.22, 0.62, 1.0, 1.0)
	const GOLD := Color(0.98, 0.72, 0.22, 1.0)
	const PURPLE := Color(0.72, 0.38, 0.96, 1.0)
	const RED := Color(1.0, 0.30, 0.28, 1.0)
	const GREEN := Color(0.34, 0.92, 0.55, 1.0)
	const PANEL := Color(0.012, 0.028, 0.055, 1.0)
	const PANEL_SOFT := Color(0.025, 0.055, 0.095, 0.96)
	const CARD_BACK := Color(0.055, 0.16, 0.27, 1.0)

	var episode_id := "main_menu"
	var phase := "start"
	var _font: Font = ThemeDB.fallback_font


	func set_episode(next_episode_id: String, next_phase: String) -> void:
		episode_id = next_episode_id
		phase = next_phase
		queue_redraw()


	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return
		var scale_factor := Vector2(
			size.x / REFERENCE_SIZE.x,
			size.y / REFERENCE_SIZE.y
		)
		draw_set_transform(Vector2.ZERO, 0.0, scale_factor)
		_draw_stage_shell()
		match episode_id:
			"main_menu":
				_draw_main_menu()
			"loading":
				_draw_loading()
			"acquire_to_deck":
				_draw_acquire()
			"shuffle":
				_draw_shuffle()
			"draw":
				_draw_draw_to_hand()
			"hand_hover":
				_draw_hand_hover()
			"public_play":
				_draw_public_row(false)
			"public_resolution":
				_draw_public_row(true)
			"facility":
				_draw_facility()
			"monster":
				_draw_monster()
			"military":
				_draw_military()
			"track_handoff":
				_draw_track()
			"final_settlement":
				_draw_final_settlement()
			_:
				_draw_unknown()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


	func _draw_stage_shell() -> void:
		_panel(STAGE_RECT.grow(6.0), Color(0.0, 0.0, 0.0, 0.42), Color(0.0, 0.0, 0.0, 0.0), 14, 0)
		_panel(STAGE_RECT, PANEL, Color(0.12, 0.78, 0.73, 0.95), 12, 2)
		draw_rect(Rect2(144.0, 86.0, 1312.0, 58.0), Color(0.018, 0.065, 0.105, 1.0))
		draw_line(Vector2(166.0, 144.0), Vector2(1434.0, 144.0), Color(0.12, 0.43, 0.48, 0.75), 1.0)
		_text(Rect2(166.0, 103.0, 790.0, 30.0), "PRODUCTION TABLE CONTEXT  /  AUTHORED VISUAL STAGE", 18, TEAL)
		var title := _episode_title()
		_text(Rect2(830.0, 103.0, 450.0, 30.0), title, 18, INK, HORIZONTAL_ALIGNMENT_RIGHT)
		_chip(Rect2(1294.0, 100.0, 134.0, 31.0), phase.to_upper(), _phase_color())
		# A restrained globe watermark keeps the living-planet context visible even
		# where the stage masks contradictory empty production controls.
		draw_circle(Vector2(800.0, 526.0), 252.0, Color(0.02, 0.12, 0.16, 0.24))
		draw_arc(Vector2(800.0, 526.0), 252.0, 0.0, TAU, 96, Color(0.18, 0.62, 0.67, 0.10), 2.0, true)
		draw_arc(Vector2(800.0, 526.0), 176.0, 0.0, TAU, 72, Color(0.18, 0.62, 0.67, 0.07), 1.0, true)
		_text(Rect2(170.0, 866.0, 1260.0, 25.0), "PRESENTATION FIXTURE / VISUAL SAMPLE ONLY  |  AUTHORITY UNCHANGED  |  NOT HUMAN GREEN", 12, MUTED, HORIZONTAL_ALIGNMENT_CENTER)


	func _episode_title() -> String:
		return {
			"main_menu": "PRODUCT SHELL",
			"loading": "NEW GAME LOADING",
			"acquire_to_deck": "ACQUIRE -> DECK",
			"shuffle": "DISCARD -> SHUFFLE",
			"draw": "DRAW -> HAND",
			"hand_hover": "FIVE-CARD HAND HOVER",
			"public_play": "PUBLIC ACTION ROW",
			"public_resolution": "PUBLIC RESOLUTION",
			"facility": "REGION 09 FACILITY BUILD",
			"monster": "MONSTER COMBAT",
			"military": "GEODESIC MILITARY MISSION",
			"track_handoff": "SUSHI TRACK HANDOFF",
			"final_settlement": "FINAL SETTLEMENT",
		}.get(episode_id, episode_id.to_upper())


	func _phase_color() -> Color:
		return {"start": BLUE, "mid": GOLD, "end": GREEN}.get(phase, TEAL)


	func _draw_main_menu() -> void:
		_panel(Rect2(330.0, 190.0, 940.0, 570.0), Color(0.008, 0.023, 0.052, 0.995), Color(0.16, 0.64, 0.73, 0.85), 16, 2)
		_text(Rect2(380.0, 235.0, 840.0, 55.0), "SPACE SYNDICATE", 34, Color(0.76, 0.95, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
		_text(Rect2(380.0, 290.0, 840.0, 34.0), "ALPHA 0.7  /  LIVING PLANET", 18, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		_draw_orbit_mark(Vector2(800.0, 414.0), 76.0)
		var seats := ["YOU", "AI-A", "AI-B", "AI-C"]
		for index in seats.size():
			var x := 500.0 + float(index) * 200.0
			draw_circle(Vector2(x, 535.0), 31.0, Color(0.035, 0.13, 0.20, 1.0))
			draw_arc(Vector2(x, 535.0), 31.0, 0.0, TAU, 32, TEAL if index == 0 else BLUE, 2.0, true)
			_text(Rect2(x - 48.0, 525.0, 96.0, 24.0), seats[index], 12, INK, HORIZONTAL_ALIGNMENT_CENTER)
		_panel(Rect2(575.0, 615.0, 450.0, 72.0), Color(0.06, 0.25, 0.28, 1.0), TEAL, 9, 2)
		_text(Rect2(575.0, 635.0, 450.0, 30.0), "NEW GAME  /  1 PLAYER + 3 AI", 17, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		_text(Rect2(500.0, 714.0, 600.0, 24.0), "Single clean launch surface · duplicate menu residue masked", 12, MUTED, HORIZONTAL_ALIGNMENT_CENTER)


	func _draw_loading() -> void:
		var active_step: int = int({"start": 1, "mid": 2, "end": 3}.get(phase, 1))
		_text(Rect2(250.0, 190.0, 1100.0, 38.0), "BUILDING YOUR LIVING PLANET", 26, INK, HORIZONTAL_ALIGNMENT_CENTER)
		_text(Rect2(300.0, 240.0, 1000.0, 26.0), "Visible initialization · production main remains mounted", 13, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		var names := ["WORLD MAP", "DECKS + TRACK", "TABLE READY"]
		var details := ["Half-edge sphere / regions", "Cards / seats / private hands", "Presentation owners / HUD"]
		for index in 3:
			var rect := Rect2(245.0 + float(index) * 380.0, 340.0, 350.0, 245.0)
			var done: bool = index < active_step
			_panel(rect, Color(0.022, 0.055, 0.09, 1.0), GREEN if done else Color(0.17, 0.30, 0.40, 1.0), 12, 2)
			_chip(Rect2(rect.position.x + 120.0, rect.position.y + 28.0, 110.0, 30.0), "READY" if done else "WAITING", GREEN if done else MUTED)
			_text(Rect2(rect.position.x + 20.0, rect.position.y + 95.0, rect.size.x - 40.0, 32.0), names[index], 18, INK, HORIZONTAL_ALIGNMENT_CENTER)
			_text(Rect2(rect.position.x + 20.0, rect.position.y + 140.0, rect.size.x - 40.0, 50.0), details[index], 12, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
			_draw_progress(Rect2(rect.position.x + 35.0, rect.end.y - 40.0, rect.size.x - 70.0, 10.0), 1.0 if done else 0.0, GREEN)
		_draw_progress(Rect2(350.0, 675.0, 900.0, 18.0), float(active_step) / 3.0, TEAL)
		_text(Rect2(350.0, 710.0, 900.0, 28.0), "STEP %d / 3" % active_step, 16, GOLD, HORIZONTAL_ALIGNMENT_CENTER)


	func _draw_acquire() -> void:
		var deck_count := 13 if phase == "end" else 12
		_text(Rect2(205.0, 175.0, 1190.0, 30.0), "ONE-CLICK CLAIM  ·  CARD IDENTITY PRESERVED  ·  DRAW PILE +1", 14, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		# Once the card begins transit, the source is a visible vacancy.  The
		# moving card is therefore the only recognizable instance of its identity.
		_draw_track_slot(
			Rect2(240.0, 285.0, 220.0, 290.0),
			phase in ["mid", "end"]
		)
		_text(Rect2(230.0, 605.0, 240.0, 25.0), "SUSHI TRACK SOURCE", 13, BLUE, HORIZONTAL_ALIGNMENT_CENTER)
		_draw_deck_stack(Rect2(1120.0, 290.0, 150.0, 210.0), deck_count, true, "DRAW PILE")
		_text(Rect2(1080.0, 535.0, 230.0, 28.0), "%d CARDS" % deck_count, 18, GOLD if phase == "end" else INK, HORIZONTAL_ALIGNMENT_CENTER)
		var card_rect := Rect2(285.0, 330.0, 130.0, 190.0)
		if phase == "mid":
			card_rect.position = Vector2(730.0, 285.0)
		if phase == "end":
			card_rect.position = Vector2(1112.0, 278.0)
		_draw_curved_arrow(Vector2(430.0, 420.0), Vector2(1120.0, 405.0), Vector2(775.0, 250.0), TEAL)
		if phase != "end":
			_draw_mini_card(card_rect, "SOLAR", "FREIGHT", GOLD, true, phase == "mid", "ACQUIRED")
		else:
			_draw_glow(Rect2(1105.0, 280.0, 170.0, 225.0), GREEN)
			_chip(Rect2(1085.0, 585.0, 220.0, 34.0), "INTAKE COMPLETE  +1", GREEN)
		_text(Rect2(555.0, 675.0, 490.0, 44.0), "12 -> 13  /  exact-once presentation receipt", 16, INK, HORIZONTAL_ALIGNMENT_CENTER)


	func _draw_shuffle() -> void:
		var finished := phase == "end"
		_draw_deck_stack(Rect2(260.0, 285.0, 150.0, 210.0), 7 if not finished else 0, false, "DISCARD")
		_draw_deck_stack(Rect2(1140.0, 285.0, 150.0, 210.0), 19 if finished else 12, true, "DRAW PILE")
		_text(Rect2(220.0, 535.0, 230.0, 28.0), ("0 CARDS" if finished else "7 CARDS"), 17, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		_text(Rect2(1100.0, 535.0, 230.0, 28.0), ("19 CARDS · SEALED" if finished else "12 CARDS"), 17, GOLD if finished else INK, HORIZONTAL_ALIGNMENT_CENTER)
		_draw_curved_arrow(Vector2(415.0, 390.0), Vector2(1135.0, 390.0), Vector2(780.0, 215.0), BLUE)
		if phase == "start":
			for index in 3:
				_draw_mini_card(Rect2(545.0 + index * 42.0, 330.0 + index * 12.0, 118.0, 168.0), "CARD", "BACK", BLUE, false, false, "QUEUE")
			_chip(Rect2(620.0, 600.0, 360.0, 35.0), "COLLECTING HIDDEN ORDER", BLUE)
		elif phase == "mid":
			for index in 5:
				var x := 540.0 + float(index) * 105.0
				var y := 312.0 + (34.0 if index % 2 == 0 else 0.0)
				_draw_mini_card(Rect2(x, y, 105.0, 158.0), "", "", GOLD if index % 2 == 0 else BLUE, false, index == 2, "INTERLEAVE")
			_chip(Rect2(620.0, 600.0, 360.0, 35.0), "INTERLEAVE PASS 2 / 3", GOLD)
		else:
			_draw_lock(Vector2(800.0, 400.0), 74.0)
			_chip(Rect2(620.0, 600.0, 360.0, 35.0), "ORDER SEALED · BACKS ONLY", GREEN)
		_text(Rect2(420.0, 690.0, 760.0, 34.0), "7 DISCARD + 12 DRAW = 19 DRAW  /  no face disclosure", 15, INK, HORIZONTAL_ALIGNMENT_CENTER)


	func _draw_draw_to_hand() -> void:
		var hand_count := 5 if phase == "end" else 4
		var deck_count := 19 if phase == "start" else 18
		_draw_deck_stack(Rect2(230.0, 280.0, 145.0, 205.0), deck_count, true, "DRAW PILE")
		_text(Rect2(200.0, 520.0, 205.0, 30.0), "%d CARDS" % deck_count, 17, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		_draw_curved_arrow(Vector2(390.0, 400.0), Vector2(1110.0, 420.0), Vector2(745.0, 245.0), TEAL)
		var hand_x := 700.0
		for index in hand_count:
			_draw_mini_card(Rect2(hand_x + index * 116.0, 405.0, 106.0, 158.0), "CARD %d" % (index + 1), "LOCAL", [BLUE, PURPLE, TEAL, GOLD, GREEN][index], true, false, "HAND")
		if phase == "mid":
			_draw_mini_card(Rect2(565.0, 275.0, 112.0, 166.0), "CARD", "BACK", BLUE, false, true, "OWNER REVEAL")
		if phase == "end":
			_draw_glow(Rect2(hand_x + 4.0 * 116.0, 405.0, 106.0, 158.0), GREEN)
		_text(Rect2(680.0, 600.0, 600.0, 30.0), "GENERAL HAND  %d / 5" % hand_count, 18, GREEN if hand_count == 5 else INK, HORIZONTAL_ALIGNMENT_CENTER)
		_panel(Rect2(490.0, 670.0, 620.0, 62.0), PANEL_SOFT, Color(0.13, 0.39, 0.50, 1.0), 8, 1)
		_text(Rect2(510.0, 685.0, 580.0, 28.0), "LOCAL OWNER: FACE UP     |     RIVALS: CARD BACK ONLY", 13, MUTED, HORIZONTAL_ALIGNMENT_CENTER)


	func _draw_hand_hover() -> void:
		var cards := [
			["SOLAR", "FREIGHT", BLUE],
			["DEEP", "MINE", PURPLE],
			["ORBITAL", "MARKET", GOLD],
			["FLEET", "ALPHA", RED],
			["VOID", "RELAY", TEAL],
		]
		for index in cards.size():
			var selected := index == 2
			var y := 388.0 - (54.0 if selected and phase != "start" else 0.0)
			var rect := Rect2(205.0 + index * 154.0, y, 140.0, 205.0)
			if selected:
				_draw_glow(rect, GOLD)
			_draw_mini_card(rect, cards[index][0], cards[index][1], cards[index][2], true, selected, "$6" if selected else "HAND")
		_text(Rect2(205.0, 635.0, 750.0, 30.0), "GENERAL HAND  5 / 5  ·  target card lifts without covering controls", 14, INK, HORIZONTAL_ALIGNMENT_CENTER)
		_panel(Rect2(1010.0, 245.0, 350.0, 490.0), Color(0.025, 0.045, 0.075, 1.0), GOLD, 12, 2)
		_text(Rect2(1040.0, 275.0, 290.0, 38.0), "ORBITAL MARKET", 21, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		_text(Rect2(1040.0, 325.0, 290.0, 28.0), "FACILITY  ·  COST 6", 13, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		_draw_market_model(Vector2(1185.0, 440.0), 1.0, GOLD)
		_draw_mini_planet(Vector2(1185.0, 600.0), 76.0, "09", TEAL)
		_chip(Rect2(1070.0, 690.0, 230.0, 32.0), "REGION 09  ·  LEGAL", GREEN if phase == "end" else TEAL)


	func _draw_public_row(resolving: bool) -> void:
		_text(Rect2(260.0, 172.0, 1080.0, 30.0), "THREE PUBLIC CARDS REMAIN INSPECTABLE THROUGH THE 30s WINDOW", 14, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		var owners := ["YOU", "AI-A", "AI-B"]
		var names := [["ORBITAL", "MARKET"], ["ION", "FOUNDRY"], ["VOID", "CONVOY"]]
		var colors := [GOLD, BLUE, PURPLE]
		for index in 3:
			var rect := Rect2(330.0 + index * 330.0, 295.0, 210.0, 300.0)
			var state := _public_state(index, resolving)
			var highlight := state == "RESOLVING" or (not resolving and phase == "mid" and index == 0)
			if highlight:
				_draw_glow(rect, colors[index])
			_draw_mini_card(rect, names[index][0], names[index][1], colors[index], true, highlight, owners[index])
			_chip(Rect2(rect.position.x + 20.0, rect.end.y + 18.0, rect.size.x - 40.0, 34.0), state, GREEN if state == "RESOLVED" else (GOLD if state == "RESOLVING" else BLUE))
			if resolving:
				var target := Vector2(rect.get_center().x, 735.0)
				draw_line(Vector2(rect.get_center().x, rect.end.y + 58.0), target, colors[index] if state != "QUEUED" else Color(0.20, 0.30, 0.40, 1.0), 3.0 if state == "RESOLVING" else 1.0, true)
				draw_circle(target, 28.0, Color(0.025, 0.10, 0.14, 1.0))
				draw_arc(target, 28.0, 0.0, TAU, 28, colors[index], 2.0, true)
				_text(Rect2(target.x - 40.0, target.y - 10.0, 80.0, 22.0), ["R09", "R04", "R12"][index], 11, INK, HORIZONTAL_ALIGNMENT_CENTER)
		if not resolving:
			var time: String = str({"start": "30.0", "mid": "18.0", "end": "06.0"}.get(phase, "30.0"))
			_panel(Rect2(570.0, 700.0, 460.0, 70.0), Color(0.13, 0.09, 0.02, 1.0), GOLD, 8, 2)
			_text(Rect2(590.0, 719.0, 420.0, 30.0), "PEEKABLE PUBLIC WINDOW  ·  %ss" % time, 16, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		else:
			_text(Rect2(420.0, 805.0, 760.0, 28.0), "QUEUED -> RESOLVING -> RESOLVED / DISCARD", 14, MUTED, HORIZONTAL_ALIGNMENT_CENTER)


	func _public_state(index: int, resolving: bool) -> String:
		if not resolving:
			if phase == "start":
				return "SELECTED" if index == 0 else "QUEUED"
			return "QUEUED  %d / 3" % (index + 1)
		var resolved_count: int = int({"start": 0, "mid": 1, "end": 3}.get(phase, 0))
		if index < resolved_count:
			return "RESOLVED"
		if index == resolved_count and resolved_count < 3:
			return "RESOLVING"
		return "QUEUED"


	func _draw_facility() -> void:
		_panel(Rect2(195.0, 235.0, 380.0, 535.0), PANEL_SOFT, Color(0.14, 0.35, 0.45, 1.0), 12, 1)
		_text(Rect2(225.0, 265.0, 320.0, 28.0), "DISTINCT FACILITY SILHOUETTES", 14, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		_draw_factory_model(Vector2(290.0, 400.0), 0.82, BLUE)
		_draw_market_model(Vector2(475.0, 400.0), 0.82, GOLD)
		_draw_warehouse_model(Vector2(290.0, 610.0), 0.82, PURPLE)
		_text(Rect2(225.0, 475.0, 130.0, 24.0), "FACTORY", 12, BLUE, HORIZONTAL_ALIGNMENT_CENTER)
		_text(Rect2(410.0, 475.0, 130.0, 24.0), "MARKET", 12, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		_text(Rect2(225.0, 685.0, 130.0, 24.0), "WAREHOUSE", 12, PURPLE, HORIZONTAL_ALIGNMENT_CENTER)
		_draw_mini_planet(Vector2(995.0, 500.0), 280.0, "09", TEAL)
		var growth: float = float({"start": 0.28, "mid": 0.68, "end": 1.0}.get(phase, 0.28))
		var model_color := Color(GOLD.r, GOLD.g, GOLD.b, 0.42 if phase == "start" else 1.0)
		_draw_market_model(Vector2(995.0, 485.0), growth, model_color)
		_text(Rect2(810.0, 715.0, 370.0, 28.0), "REGION 09  ·  ORBITAL MARKET", 17, INK, HORIZONTAL_ALIGNMENT_CENTER)
		_chip(Rect2(850.0, 758.0, 290.0, 36.0), "BUILT + PERSISTENT" if phase == "end" else ("MODEL GROW 68%" if phase == "mid" else "FOUNDATION 28%"), GREEN if phase == "end" else GOLD)


	func _draw_monster() -> void:
		_panel(Rect2(205.0, 220.0, 1190.0, 570.0), Color(0.025, 0.025, 0.05, 0.985), Color(0.30, 0.22, 0.45, 1.0), 14, 2)
		var target_x := 1080.0 + (42.0 if phase == "mid" else 0.0)
		_draw_monster_token(Vector2(470.0, 470.0), 100.0, "EMBER\nWYRM", RED, false)
		_draw_monster_token(Vector2(target_x, 470.0), 100.0, "VOID\nMANTA", PURPLE, true)
		_draw_hp_bar(Rect2(330.0, 630.0, 280.0, 22.0), 8, 8, RED, "HP 8 / 8   ARMOR 2")
		var target_hp := 9 if phase == "start" else 6
		_draw_hp_bar(Rect2(940.0, 630.0, 280.0, 22.0), target_hp, 9, PURPLE, "HP %d / 9   ARMOR 1" % target_hp)
		_draw_curved_arrow(Vector2(570.0, 450.0), Vector2(980.0, 450.0), Vector2(780.0, 310.0), RED)
		if phase == "mid":
			_draw_impact(Vector2(805.0, 440.0), 95.0)
			_chip(Rect2(700.0, 555.0, 210.0, 42.0), "IMPACT  -3 HP", RED)
		elif phase == "end":
			_chip(Rect2(690.0, 420.0, 230.0, 42.0), "RECOVERY · HP 6", GREEN)
		else:
			_chip(Rect2(690.0, 420.0, 230.0, 42.0), "WINDUP · TARGET LOCK", GOLD)
		_text(Rect2(475.0, 710.0, 650.0, 28.0), "ENTRY  ->  WINDUP  ->  IMPACT / FLASH / KNOCK  ->  RECOVERY", 13, MUTED, HORIZONTAL_ALIGNMENT_CENTER)


	func _draw_military() -> void:
		# R07 is a contextual globe landmark; the red route endpoint alone owns
		# the mission target identity R12 across all three authored poses.
		_draw_mini_planet(Vector2(805.0, 495.0), 282.0, "07", BLUE)
		var start := Vector2(600.0, 620.0)
		var midpoint := Vector2(805.0, 245.0)
		var target := Vector2(1035.0, 475.0)
		var points := PackedVector2Array()
		for index in 25:
			var t := float(index) / 24.0
			points.append(_quadratic(start, midpoint, target, t))
		draw_polyline(points, Color(0.30, 0.82, 1.0, 0.75), 5.0, true)
		for index in [4, 10, 16, 22]:
			draw_circle(points[index], 5.0, GOLD)
		_draw_region_beacon(start, "BASE", TEAL)
		_draw_region_beacon(target, "R12", RED)
		var fleet_position := start
		if phase == "mid":
			fleet_position = points[13]
		elif phase == "end":
			fleet_position = Vector2(540.0, 665.0)
		_draw_fleet_token(fleet_position, phase == "end")
		if phase == "mid":
			_draw_impact(target, 46.0)
			_chip(Rect2(1065.0, 550.0, 240.0, 36.0), "IMPACT · ARMOR 4 -> 2", RED)
		elif phase == "end":
			draw_line(target, Vector2(720.0, 720.0), Color(0.30, 0.82, 1.0, 0.42), 3.0, true)
			_chip(Rect2(500.0, 735.0, 300.0, 38.0), "MISSION COMPLETE · WITHDRAWN", GREEN)
		else:
			_chip(Rect2(300.0, 690.0, 260.0, 36.0), "ASSAULT REGION · ETA 2", BLUE)
		_text(Rect2(420.0, 815.0, 760.0, 25.0), "PHYSICAL SPHERICAL GEODESIC  /  NO TELEPORT  /  ONE MISSION THEN WITHDRAW", 13, MUTED, HORIZONTAL_ALIGNMENT_CENTER)


	func _draw_track() -> void:
		_text(Rect2(300.0, 176.0, 1000.0, 30.0), "THREE SLOTS  ·  CARDS + VACANCY MOVE AS ONE ORDERED TRAIN  ·  ONE WAY", 14, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		var centers := [Vector2(440.0, 475.0), Vector2(760.0, 475.0), Vector2(1080.0, 475.0)]
		for index in 3:
			var slot_rect := Rect2(centers[index] - Vector2(130.0, 175.0), Vector2(260.0, 350.0))
			_panel(slot_rect, Color(0.018, 0.052, 0.087, 1.0), Color(0.18, 0.46, 0.62, 1.0), 12, 2)
			_text(Rect2(slot_rect.position.x, slot_rect.position.y + 18.0, slot_rect.size.x, 24.0), "SLOT %02d" % (index + 1), 12, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		if phase == "start":
			_draw_track_piece(centers[0], "01", BLUE, false)
			_draw_track_piece(centers[1], "02", PURPLE, false)
			_draw_track_piece(centers[2], "VAC", GOLD, true)
		elif phase == "mid":
			_draw_track_piece(centers[0] + Vector2(155.0, 0.0), "01", BLUE, false)
			_draw_track_piece(centers[1] + Vector2(155.0, 0.0), "02", PURPLE, false)
			_draw_track_piece(Vector2(1260.0, 475.0), "VAC", GOLD, true)
			_draw_curved_arrow(Vector2(1255.0, 575.0), Vector2(285.0, 575.0), Vector2(770.0, 790.0), GOLD)
		else:
			_draw_track_piece(centers[0], "VAC", GOLD, true)
			_draw_track_piece(centers[1], "01", BLUE, false)
			_draw_track_piece(centers[2], "02", PURPLE, false)
		for index in 2:
			_draw_arrow(Vector2(centers[index].x + 135.0, 475.0), Vector2(centers[index + 1].x - 135.0, 475.0), TEAL)
		_chip(Rect2(610.0, 710.0, 380.0, 42.0), {"start": "CURRENT: YOU  [01][02][VAC]", "mid": "HANDOFF IN TRANSIT  ->", "end": "NEXT: AI-A  [VAC][01][02]"}.get(phase, "HANDOFF"), GREEN if phase == "end" else GOLD)
		_text(Rect2(480.0, 780.0, 640.0, 26.0), "NO RETURN  ·  NO REFILL  ·  VACANCY REMAINS VISIBLE", 13, MUTED, HORIZONTAL_ALIGNMENT_CENTER)


	func _draw_final_settlement() -> void:
		_panel(Rect2(300.0, 190.0, 1000.0, 620.0), Color(0.008, 0.02, 0.045, 0.995), GOLD if phase == "end" else TEAL, 14, 2)
		_text(Rect2(350.0, 225.0, 900.0, 42.0), "FINAL SETTLEMENT", 28, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		if phase == "start":
			_chip(Rect2(630.0, 285.0, 340.0, 38.0), "SCORING IN PROGRESS", BLUE)
			var categories := ["FACILITIES", "ASSETS", "MISSIONS", "VICTORY QUALIFICATION"]
			for index in categories.size():
				_panel(Rect2(435.0, 360.0 + index * 82.0, 730.0, 58.0), PANEL_SOFT, Color(0.12, 0.28, 0.38, 1.0), 7, 1)
				_text(Rect2(460.0, 377.0 + index * 82.0, 480.0, 25.0), categories[index], 14, INK)
				_text(Rect2(1000.0, 377.0 + index * 82.0, 125.0, 25.0), "...", 16, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
			_draw_progress(Rect2(500.0, 710.0, 600.0, 12.0), 0.28, BLUE)
		elif phase == "mid":
			_chip(Rect2(630.0, 285.0, 340.0, 38.0), "CATEGORY REVEAL  3 / 4", GOLD)
			var reveal_rows := [
				["YOU", "FAC 4", "ASSET 12", "+ MISSION 3", "19"],
				["AI-A", "FAC 3", "ASSET 10", "+ MISSION 2", "15"],
				["AI-B", "FAC 2", "ASSET 8", "+ MISSION ...", "..."],
				["AI-C", "FAC 1", "ASSET 6", "+ MISSION ...", "..."],
			]
			_draw_score_rows(reveal_rows, false)
			_draw_progress(Rect2(500.0, 710.0, 600.0, 12.0), 0.75, GOLD)
		else:
			_chip(Rect2(630.0, 285.0, 340.0, 38.0), "RANKING LOCKED · EXACTLY ONCE", GREEN)
			var final_rows := [
				["1", "YOU / player.local", "FAC 4", "ASSET 12", "22"],
				["2", "AI-A", "FAC 3", "ASSET 10", "17"],
				["3", "AI-B", "FAC 2", "ASSET 8", "13"],
				["4", "AI-C", "FAC 1", "ASSET 6", "9"],
			]
			_draw_score_rows(final_rows, true)
			_draw_progress(Rect2(500.0, 710.0, 600.0, 12.0), 1.0, GREEN)
			_text(Rect2(500.0, 746.0, 600.0, 30.0), "WINNER  ·  PLAYER.LOCAL", 18, GOLD, HORIZONTAL_ALIGNMENT_CENTER)


	func _draw_score_rows(rows: Array, final_rows: bool) -> void:
		for index in rows.size():
			var rect := Rect2(400.0, 355.0 + index * 78.0, 800.0, 58.0)
			var accent := GOLD if index == 0 else Color(0.14, 0.32, 0.42, 1.0)
			_panel(rect, Color(0.02, 0.05, 0.08, 1.0), accent, 7, 1)
			var row: Array = rows[index]
			var prefix_width := 80.0 if final_rows else 110.0
			_text(Rect2(rect.position.x + 18.0, rect.position.y + 17.0, prefix_width, 25.0), str(row[0]), 14, GOLD if index == 0 else INK)
			_text(Rect2(rect.position.x + 125.0, rect.position.y + 17.0, 260.0, 25.0), str(row[1]), 14, INK)
			_text(Rect2(rect.position.x + 395.0, rect.position.y + 17.0, 110.0, 25.0), str(row[2]), 13, MUTED)
			_text(Rect2(rect.position.x + 510.0, rect.position.y + 17.0, 140.0, 25.0), str(row[3]), 13, MUTED)
			_text(Rect2(rect.end.x - 105.0, rect.position.y + 14.0, 80.0, 28.0), str(row[4]), 18, GREEN if final_rows else GOLD, HORIZONTAL_ALIGNMENT_RIGHT)


	func _draw_unknown() -> void:
		_text(Rect2(300.0, 430.0, 1000.0, 60.0), episode_id.to_upper(), 30, INK, HORIZONTAL_ALIGNMENT_CENTER)


	func _draw_track_slot(rect: Rect2, vacancy: bool) -> void:
		_panel(rect, PANEL_SOFT, BLUE, 10, 2)
		_text(Rect2(rect.position.x, rect.position.y + 18.0, rect.size.x, 24.0), "SLOT 03", 12, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		if vacancy:
			_panel(Rect2(rect.position.x + 30.0, rect.position.y + 68.0, rect.size.x - 60.0, 165.0), Color(0.08, 0.065, 0.025, 1.0), GOLD, 8, 2)
			_text(Rect2(rect.position.x + 30.0, rect.position.y + 130.0, rect.size.x - 60.0, 30.0), "VACANCY", 16, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		else:
			_draw_mini_card(Rect2(rect.position.x + 45.0, rect.position.y + 65.0, 130.0, 190.0), "SOLAR", "FREIGHT", GOLD, true, true, "TRACK")


	func _draw_deck_stack(rect: Rect2, count: int, card_back: bool, label: String) -> void:
		for offset in range(5, -1, -1):
			var layer := Rect2(rect.position + Vector2(float(offset) * 5.0, -float(offset) * 4.0), rect.size)
			_panel(layer, CARD_BACK if card_back else Color(0.11, 0.08, 0.12, 1.0), BLUE if card_back else PURPLE, 8, 1)
		if card_back:
			_draw_card_back_pattern(rect.grow(-18.0))
		_text(Rect2(rect.position.x, rect.position.y + 78.0, rect.size.x, 28.0), label, 13, INK, HORIZONTAL_ALIGNMENT_CENTER)
		_text(Rect2(rect.position.x, rect.position.y + 112.0, rect.size.x, 24.0), "%d" % count, 24, GOLD, HORIZONTAL_ALIGNMENT_CENTER)


	func _draw_mini_card(rect: Rect2, title: String, subtitle: String, color: Color, face_up: bool, highlighted: bool, badge: String) -> void:
		if highlighted:
			_draw_glow(rect, color)
		_panel(rect, Color(0.045, 0.065, 0.095, 1.0) if face_up else CARD_BACK, color, 9, 2)
		draw_rect(Rect2(rect.position + Vector2(5.0, 5.0), Vector2(rect.size.x - 10.0, 12.0)), color)
		if face_up:
			draw_circle(Vector2(rect.get_center().x, rect.position.y + rect.size.y * 0.39), minf(rect.size.x, rect.size.y) * 0.19, Color(color.r, color.g, color.b, 0.25))
			draw_arc(Vector2(rect.get_center().x, rect.position.y + rect.size.y * 0.39), minf(rect.size.x, rect.size.y) * 0.19, 0.0, TAU, 28, color, 2.0, true)
			_text(Rect2(rect.position.x + 8.0, rect.position.y + rect.size.y * 0.58, rect.size.x - 16.0, 24.0), title, 13, INK, HORIZONTAL_ALIGNMENT_CENTER)
			_text(Rect2(rect.position.x + 8.0, rect.position.y + rect.size.y * 0.72, rect.size.x - 16.0, 24.0), subtitle, 12, color, HORIZONTAL_ALIGNMENT_CENTER)
		else:
			_draw_card_back_pattern(rect.grow(-15.0))
		_text(Rect2(rect.position.x + 5.0, rect.end.y - 28.0, rect.size.x - 10.0, 20.0), badge, 10, MUTED, HORIZONTAL_ALIGNMENT_CENTER)


	func _draw_card_back_pattern(rect: Rect2) -> void:
		for row in 4:
			for column in 3:
				var center := Vector2(rect.position.x + 16.0 + column * (rect.size.x - 32.0) / 2.0, rect.position.y + 16.0 + row * (rect.size.y - 32.0) / 3.0)
				draw_circle(center, 4.0, Color(0.25, 0.78, 0.84, 0.78))


	func _draw_mini_planet(center: Vector2, radius: float, region: String, accent: Color) -> void:
		draw_circle(center, radius, Color(0.015, 0.10, 0.16, 1.0))
		draw_circle(center - Vector2(radius * 0.18, radius * 0.10), radius * 0.62, Color(0.03, 0.22, 0.19, 0.52))
		draw_arc(center, radius, 0.0, TAU, 72, accent, 3.0, true)
		draw_arc(center, radius * 0.72, 0.0, TAU, 64, Color(accent.r, accent.g, accent.b, 0.35), 1.0, true)
		draw_arc(center, radius * 0.42, 0.0, TAU, 48, Color(accent.r, accent.g, accent.b, 0.24), 1.0, true)
		draw_line(center - Vector2(radius, 0.0), center + Vector2(radius, 0.0), Color(accent.r, accent.g, accent.b, 0.22), 1.0, true)
		var marker := center + Vector2(radius * 0.28, -radius * 0.12)
		draw_circle(marker, 28.0 if radius > 100.0 else 18.0, Color(0.12, 0.055, 0.02, 1.0))
		draw_arc(marker, 28.0 if radius > 100.0 else 18.0, 0.0, TAU, 24, GOLD, 2.0, true)
		_text(Rect2(marker.x - 34.0, marker.y - 10.0, 68.0, 22.0), "R%s" % region, 11, GOLD, HORIZONTAL_ALIGNMENT_CENTER)


	func _draw_factory_model(center: Vector2, scale_value: float, color: Color) -> void:
		var s := scale_value
		draw_rect(Rect2(center + Vector2(-62.0, -16.0) * s, Vector2(124.0, 72.0) * s), Color(color.r, color.g, color.b, 0.22))
		draw_rect(Rect2(center + Vector2(-50.0, -70.0) * s, Vector2(24.0, 62.0) * s), color)
		var roof := PackedVector2Array([center + Vector2(-62.0, -16.0) * s, center + Vector2(-22.0, -55.0) * s, center + Vector2(18.0, -16.0) * s, center + Vector2(55.0, -48.0) * s, center + Vector2(62.0, -16.0) * s])
		draw_polyline(roof, color, 4.0, true)
		for index in 3:
			draw_circle(center + Vector2(-32.0 + index * 32.0, 22.0) * s, 9.0 * s, color)


	func _draw_market_model(center: Vector2, scale_value: float, color: Color) -> void:
		var s := scale_value
		var roof := PackedVector2Array([center + Vector2(-75.0, -10.0) * s, center + Vector2(0.0, -85.0) * s, center + Vector2(75.0, -10.0) * s])
		draw_colored_polygon(roof, Color(color.r, color.g, color.b, 0.28))
		draw_polyline(roof, color, 4.0, true)
		draw_line(roof[2], roof[0], color, 4.0, true)
		for x in [-48.0, 0.0, 48.0]:
			draw_line(center + Vector2(x, -5.0) * s, center + Vector2(x, 68.0) * s, color, 5.0, true)
		draw_line(center + Vector2(-72.0, 68.0) * s, center + Vector2(72.0, 68.0) * s, color, 6.0, true)


	func _draw_warehouse_model(center: Vector2, scale_value: float, color: Color) -> void:
		var s := scale_value
		var body := Rect2(center + Vector2(-70.0, -50.0) * s, Vector2(140.0, 118.0) * s)
		draw_rect(body, Color(color.r, color.g, color.b, 0.22))
		draw_rect(body, color, false, 4.0, true)
		var roof := PackedVector2Array([center + Vector2(-78.0, -50.0) * s, center + Vector2(0.0, -92.0) * s, center + Vector2(78.0, -50.0) * s])
		draw_polyline(roof, color, 4.0, true)
		for index in 3:
			draw_line(center + Vector2(-42.0, -22.0 + index * 28.0) * s, center + Vector2(42.0, -22.0 + index * 28.0) * s, color, 3.0, true)


	func _draw_monster_token(center: Vector2, radius: float, label: String, color: Color, manta: bool) -> void:
		draw_circle(center, radius, Color(color.r * 0.20, color.g * 0.20, color.b * 0.20, 1.0))
		draw_arc(center, radius, 0.0, TAU, 48, color, 4.0, true)
		if manta:
			var wings := PackedVector2Array([center + Vector2(-85.0, 5.0), center + Vector2(0.0, -55.0), center + Vector2(85.0, 5.0), center + Vector2(0.0, 58.0)])
			draw_colored_polygon(wings, Color(color.r, color.g, color.b, 0.28))
			draw_polyline(wings, color, 3.0, true)
		else:
			for index in 8:
				var angle := float(index) / 8.0 * TAU
				draw_line(center + Vector2.RIGHT.rotated(angle) * 68.0, center + Vector2.RIGHT.rotated(angle) * 92.0, color, 5.0, true)
		_text(Rect2(center.x - 80.0, center.y - 18.0, 160.0, 44.0), label, 15, INK, HORIZONTAL_ALIGNMENT_CENTER)


	func _draw_fleet_token(center: Vector2, withdrawn: bool) -> void:
		var color := GREEN if withdrawn else BLUE
		var hull := PackedVector2Array([center + Vector2(-42.0, 24.0), center + Vector2(50.0, 0.0), center + Vector2(-42.0, -24.0), center + Vector2(-18.0, 0.0)])
		draw_colored_polygon(hull, Color(color.r, color.g, color.b, 0.42))
		draw_polyline(hull, color, 3.0, true)
		draw_line(hull[hull.size() - 1], hull[0], color, 3.0, true)
		_text(Rect2(center.x - 75.0, center.y + 35.0, 150.0, 22.0), "FLEET ALPHA", 11, INK, HORIZONTAL_ALIGNMENT_CENTER)


	func _draw_region_beacon(center: Vector2, label: String, color: Color) -> void:
		draw_circle(center, 24.0, Color(0.02, 0.07, 0.10, 1.0))
		draw_arc(center, 24.0, 0.0, TAU, 24, color, 3.0, true)
		_text(Rect2(center.x - 42.0, center.y - 9.0, 84.0, 20.0), label, 10, color, HORIZONTAL_ALIGNMENT_CENTER)


	func _draw_track_piece(center: Vector2, label: String, color: Color, vacancy: bool) -> void:
		var rect := Rect2(center - Vector2(82.0, 115.0), Vector2(164.0, 230.0))
		_panel(rect, Color(0.085, 0.065, 0.02, 1.0) if vacancy else Color(0.035, 0.07, 0.11, 1.0), color, 9, 3)
		if vacancy:
			draw_rect(rect.grow(-20.0), Color(color.r, color.g, color.b, 0.08), false, 3.0, true)
		else:
			draw_circle(center - Vector2(0.0, 26.0), 36.0, Color(color.r, color.g, color.b, 0.26))
			draw_arc(center - Vector2(0.0, 26.0), 36.0, 0.0, TAU, 30, color, 2.0, true)
		_text(Rect2(rect.position.x, center.y + 38.0, rect.size.x, 30.0), label, 22, color, HORIZONTAL_ALIGNMENT_CENTER)


	func _draw_orbit_mark(center: Vector2, radius: float) -> void:
		draw_circle(center, radius * 0.64, Color(0.04, 0.20, 0.25, 1.0))
		draw_arc(center, radius * 0.64, 0.0, TAU, 48, TEAL, 3.0, true)
		draw_arc(center, radius, -0.25, PI + 0.35, 42, GOLD, 3.0, true)
		draw_circle(center + Vector2(radius * 0.82, radius * 0.24), 8.0, GOLD)


	func _draw_lock(center: Vector2, size_value: float) -> void:
		draw_arc(center - Vector2(0.0, size_value * 0.15), size_value * 0.42, PI, TAU, 28, GOLD, 8.0, true)
		_panel(Rect2(center - Vector2(size_value * 0.55, 0.0), Vector2(size_value * 1.1, size_value * 0.82)), Color(0.12, 0.085, 0.02, 1.0), GOLD, 8, 3)
		draw_circle(center + Vector2(0.0, size_value * 0.32), size_value * 0.10, GOLD)


	func _draw_impact(center: Vector2, radius: float) -> void:
		for index in 12:
			var angle := float(index) / 12.0 * TAU
			var inner := center + Vector2.RIGHT.rotated(angle) * radius * 0.28
			var outer := center + Vector2.RIGHT.rotated(angle) * radius * (1.0 if index % 2 == 0 else 0.72)
			draw_line(inner, outer, GOLD if index % 2 == 0 else RED, 5.0, true)
		draw_circle(center, radius * 0.28, Color(1.0, 0.78, 0.18, 0.90))


	func _draw_hp_bar(rect: Rect2, value: int, maximum: int, color: Color, label: String) -> void:
		_panel(rect, Color(0.05, 0.05, 0.07, 1.0), Color(0.20, 0.22, 0.28, 1.0), 5, 1)
		draw_rect(Rect2(rect.position + Vector2(3.0, 3.0), Vector2((rect.size.x - 6.0) * float(value) / float(maximum), rect.size.y - 6.0)), color)
		_text(Rect2(rect.position.x, rect.end.y + 8.0, rect.size.x, 24.0), label, 12, INK, HORIZONTAL_ALIGNMENT_CENTER)


	func _draw_progress(rect: Rect2, value: float, color: Color) -> void:
		_panel(rect, Color(0.04, 0.065, 0.08, 1.0), Color(0.14, 0.24, 0.28, 1.0), 5, 1)
		draw_rect(Rect2(rect.position + Vector2(2.0, 2.0), Vector2((rect.size.x - 4.0) * clampf(value, 0.0, 1.0), rect.size.y - 4.0)), color)


	func _draw_glow(rect: Rect2, color: Color) -> void:
		for index in 3:
			var grown := rect.grow(7.0 + index * 5.0)
			draw_rect(grown, Color(color.r, color.g, color.b, 0.34 - index * 0.08), false, 3.0, true)


	func _draw_arrow(from: Vector2, to: Vector2, color: Color) -> void:
		draw_line(from, to, color, 4.0, true)
		var direction := (to - from).normalized()
		var normal := Vector2(-direction.y, direction.x)
		var head := PackedVector2Array([to, to - direction * 18.0 + normal * 9.0, to - direction * 18.0 - normal * 9.0])
		draw_colored_polygon(head, color)


	func _draw_curved_arrow(from: Vector2, to: Vector2, control: Vector2, color: Color) -> void:
		var points := PackedVector2Array()
		for index in 25:
			points.append(_quadratic(from, control, to, float(index) / 24.0))
		draw_polyline(points, color, 4.0, true)
		_draw_arrow(points[22], points[24], color)


	func _quadratic(from: Vector2, control: Vector2, to: Vector2, t: float) -> Vector2:
		return from * pow(1.0 - t, 2.0) + control * 2.0 * (1.0 - t) * t + to * t * t


	func _chip(rect: Rect2, label: String, color: Color) -> void:
		_panel(rect, Color(color.r * 0.16, color.g * 0.16, color.b * 0.16, 1.0), color, 7, 1)
		_text(Rect2(rect.position.x + 6.0, rect.position.y + (rect.size.y - 20.0) * 0.5, rect.size.x - 12.0, 22.0), label, 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)


	func _panel(rect: Rect2, fill: Color, border: Color, radius: int, border_width: int) -> void:
		var style := StyleBoxFlat.new()
		style.bg_color = fill
		style.border_color = border
		style.border_width_left = border_width
		style.border_width_top = border_width
		style.border_width_right = border_width
		style.border_width_bottom = border_width
		style.corner_radius_top_left = radius
		style.corner_radius_top_right = radius
		style.corner_radius_bottom_left = radius
		style.corner_radius_bottom_right = radius
		draw_style_box(style, rect)


	func _text(rect: Rect2, value: String, font_size: int, color: Color, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> void:
		var lines := value.split("\n")
		var line_height := float(font_size) * 1.26
		for index in lines.size():
			draw_string(
				_font,
				Vector2(rect.position.x, rect.position.y + float(font_size) + float(index) * line_height),
				str(lines[index]),
				alignment,
				rect.size.x,
				font_size,
				color
			)


@export var showcase_path: NodePath

@onready var _showcase: Control = get_node_or_null(showcase_path) as Control
@onready var _legacy_panel: Control = %ShowcaseVisualPanel
@onready var _legacy_proxy: Control = get_node_or_null(
	"../FixtureEvidenceLayer/FixtureMotionProxy"
) as Control

var _stage: FixtureStage
var _last_episode_id := ""
var _last_phase := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_legacy_panel.visible = false
	if _legacy_proxy != null:
		_legacy_proxy.visible = false
	_stage = FixtureStage.new()
	_stage.name = "CommercialFixtureStage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.position = Vector2.ZERO
	_stage.size = get_viewport().get_visible_rect().size
	add_child(_stage)
	_apply_fixture_visual("main_menu", "start")


func _process(_delta: float) -> void:
	if _legacy_proxy != null:
		_legacy_proxy.visible = false
	if _stage != null:
		var viewport_size := get_viewport().get_visible_rect().size
		if not _stage.size.is_equal_approx(viewport_size):
			_stage.size = viewport_size
			_stage.queue_redraw()
	if _showcase == null:
		_showcase = get_node_or_null(showcase_path) as Control
	if _showcase == null or not _showcase.has_method("get_episode_evidence"):
		return
	var evidence := _showcase.call("get_episode_evidence") as Dictionary
	var episode_id := str(evidence.get("episode_id", ""))
	var frame_phase := str(evidence.get("frame_phase", ""))
	if episode_id.is_empty() or frame_phase.is_empty():
		return
	if episode_id == _last_episode_id and frame_phase == _last_phase:
		return
	_apply_fixture_visual(episode_id, frame_phase)


func _apply_fixture_visual(episode_id: String, frame_phase: String) -> void:
	_last_episode_id = episode_id
	_last_phase = frame_phase
	_legacy_panel.visible = false
	if _stage != null:
		_stage.visible = true
		_stage.set_episode(episode_id, frame_phase)
