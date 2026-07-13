extends RefCounted
class_name CompendiumCodexMcpPreviewFixtures

const FIXTURE_IDS := [
	"card_browser_grid",
	"card_detail_long_text",
	"product_market_detail",
	"monster_bestiary_detail",
	"mixed_compendium_hub",
	"empty_payload_safe_state",
	"long_text_stress",
	"missing_art_safe_state",
]


func preview_ids() -> Array[String]:
	return fixture_ids()


func fixture_ids() -> Array[String]:
	var result: Array[String] = []
	for id in FIXTURE_IDS:
		result.append(str(id))
	return result


func all_fixtures() -> Array:
	var result: Array = []
	for id in FIXTURE_IDS:
		result.append(fixture(str(id)))
	return result


func fixture(id: String) -> Dictionary:
	match id:
		"card_browser_grid":
			return _card_browser_grid()
		"card_detail_long_text":
			return _card_detail_long_text()
		"product_market_detail":
			return _product_market_detail()
		"monster_bestiary_detail":
			return _monster_bestiary_detail()
		"mixed_compendium_hub":
			return _mixed_compendium_hub()
		"empty_payload_safe_state":
			return _empty_payload_safe_state()
		"long_text_stress":
			return _long_text_stress()
		"missing_art_safe_state":
			return _missing_art_safe_state()
		_:
			return _empty_payload_safe_state()


func is_pure_data(value: Variant) -> bool:
	return not _contains_runtime_object(value)


func _card_browser_grid() -> Dictionary:
	return {
		"id": "card_browser_grid",
		"view": "card_browser",
		"title": "Card Codex Browser",
		"summary": "Filter chips, thumbnail cards, hover preview, and double-click detail signals.",
		"expected_component": "CardCodexBrowser",
		"payload": {
			"accent": "#38bdf8",
			"legend": "Card type filters",
			"columns": 3,
			"page_text": "Page 1/2 | 3 cards",
			"previous_disabled": true,
			"filters": [
				{"id": "all", "text": "All 3", "active": true, "accent": "#38bdf8"},
				{"id": "monster", "text": "Monster 1", "accent": "#fb7185"},
				{"id": "trade", "text": "Trade 2", "accent": "#22c55e"},
			],
			"cards": [
				_card_thumb("phase_beast_i", "Phase Beast I", "Monster", "#fb7185", true),
				_card_thumb("storm_credit_i", "Storm Credit I", "Finance", "#38bdf8", false),
				_card_thumb("harbor_chain_i", "Harbor Chain I", "Trade", "#22c55e", false),
			],
			"preview": {
				"title": "Hover: Storm Credit",
				"body": "Public preview only. Shows cost band, target, timing, and table-use summary without hidden owner data.",
				"accent": "#38bdf8",
			},
		},
	}


func _card_detail_long_text() -> Dictionary:
	return {
		"id": "card_detail_long_text",
		"view": "card_detail",
		"title": "Card Detail Long Text",
		"summary": "TCG-style card detail with fact cards and public resolution note.",
		"expected_component": "CardCodexDetail",
		"payload": {
			"accent": "#38bdf8",
			"face_note": "Duplicates upgrade this series; purchase price reads from rank I.",
			"card_face": {
				"name": "Phase Beast I",
				"rank": "I",
				"type": "Monster Command",
				"cost": "$80",
				"effect": "Move a summoned monster after revealing public timing.",
				"minimum_width": 230.0,
				"minimum_height": 300.0,
			},
			"summary": {
				"title": "Scan order",
				"accent": "#38bdf8",
				"header_chips": [{"text": "$80", "accent": "#facc15"}, {"text": "Target: district", "accent": "#93c5fd"}],
				"chips": [{"text": "Public route"}, {"text": "Monster"}, {"text": "Once"}],
				"effect": "Use this card when monster movement creates pressure without exposing a private target.",
				"read_order": "Cost -> threshold -> target -> route -> effect -> upgrade ladder",
			},
			"tactical": {
				"title": "Table use | read these first",
				"entries": [
					{"title": "Timing", "body": "Best after a player commits a route.", "accent": "#38bdf8"},
					{"title": "Target", "body": "Any public district with legal monster pressure.", "accent": "#fb7185"},
					{"title": "Risk", "body": "Telegraphs intent through the public track.", "accent": "#facc15"},
				],
			},
			"facts": [
				{"title": "Requirement", "body": "Requires a summoned monster and a visible district target.", "meta": "Public", "accent": "#93c5fd"},
				{"title": "Privacy", "body": "Never shows hidden owner, private target, or private discard data.", "meta": "Sanitized", "accent": "#f472b6"},
			],
			"upgrades": [
				{"roman": "I", "price": "$80", "band": "Entry", "body": "Move one step or create a short public threat.", "accent": "#38bdf8"},
				{"roman": "IV", "price": "$80", "band": "Peak", "body": "Longer pressure window, still public-safe.", "accent": "#facc15"},
			],
			"resolution": {"title": "Resolution", "body": "Public track records the effect as anonymous table pressure.", "meta": "No hidden owner.", "accent": "#22c55e"},
		},
	}


func _product_market_detail() -> Dictionary:
	return {
		"id": "product_market_detail",
		"view": "product_detail",
		"title": "Product Market Detail",
		"summary": "Product badge, KPI cards, strategy cards, and long market copy.",
		"expected_component": "ProductCodexDetail",
		"payload": {
			"accent": "#22c55e",
			"secondary": "#bbf7d0",
			"title": "Volatile Spice Market",
			"subtitle": "Price, demand, route pressure, storage, and monster preference.",
			"badge": {
				"glyph": "SP",
				"name": "Spice",
				"profile": "Luxury | contract line",
				"terrain": "Terrain: harbor / market",
				"price": "$120 | base $90 | rising",
				"meter": "Supply 2 Demand 5 Risk 3 Vol 4",
				"weather": "Solar wind creates delivery delays and public auction pressure.",
				"use": "Great for contract tempo, but route disruption can erase profit.",
				"accent": "#22c55e",
				"secondary": "#bbf7d0",
			},
			"chips": [{"text": "Luxury"}, {"text": "Route risk"}, {"text": "Monster bait"}],
			"kpis": [
				{"title": "Demand", "value": "High", "meta": "Buy early, sell after a public shortage.", "accent": "#22c55e"},
				{"title": "Storage", "value": "Fragile", "meta": "Warehouse pressure grows when monsters move.", "accent": "#facc15"},
				{"title": "Contract", "value": "Strong", "meta": "Good response-window teaching product.", "accent": "#38bdf8"},
				{"title": "Risk", "value": "3 / 5", "meta": "Track route effects before investing.", "accent": "#fb7185"},
			],
			"strategies": [
				{"title": "Safe line", "body": "Pair with harbor control and public route watch.", "accent": "#38bdf8"},
				{"title": "Aggressive line", "body": "Force auction tempo while a monster threatens a rival route.", "accent": "#fb7185"},
				{"title": "Teaching note", "body": "Use this to explain product pressure without private leakage.", "accent": "#facc15"},
			],
		},
	}


func _monster_bestiary_detail() -> Dictionary:
	return {
		"id": "monster_bestiary_detail",
		"view": "bestiary_detail",
		"title": "Monster Bestiary Detail",
		"summary": "Monster art, KPI cards, action probability cards, and public ecology copy.",
		"expected_component": "BestiaryDetail",
		"payload": {
			"accent": "#fb7185",
			"title": "Phase Leviathan",
			"subtitle": "Autonomous monster. It pressures routes and districts through public movement, not owner-directed targeting.",
			"art": {
				"name": "Phase Leviathan",
				"style": "Long-body orbital kaiju with market-disruption behavior.",
				"hp": 12,
				"armor": 2,
				"move_text": "Move 2 | route pressure",
				"profile": {"accent": "#fb7185", "body": "orbital pressure"},
			},
			"chips": [{"text": "Autonomous"}, {"text": "Route"}, {"text": "Pressure"}],
			"kpis": [
				{"title": "HP", "value": "12", "meta": "Medium boss", "accent": "#fb7185"},
				{"title": "Armor", "value": "2", "meta": "Blocks chip damage", "accent": "#facc15"},
				{"title": "Speed", "value": "2", "meta": "Route hunter", "accent": "#38bdf8"},
				{"title": "Tell", "value": "Public", "meta": "No hidden owner leak", "accent": "#f472b6"},
			],
			"actions": [
				{"index": "01", "name": "Orbit Crush", "tags": "move", "probability": "I 2/6 | IV 3/6", "facts": "Moves toward a profitable route.", "body": "Pressure appears as public route callout.", "accent": "#fb7185"},
				{"index": "02", "name": "Market Roar", "tags": "event", "probability": "I 1/6 | IV 2/6", "facts": "Raises volatility on adjacent product.", "body": "Effect is public and anonymized.", "accent": "#facc15"},
			],
		},
	}


func _mixed_compendium_hub() -> Dictionary:
	return {
		"id": "mixed_compendium_hub",
		"view": "compendium_hub",
		"title": "Compendium Hub",
		"summary": "Reference hub entry points for cards, products, regions, roles, and monsters.",
		"expected_component": "CompendiumHubBoard",
		"payload": {
			"accent": "#f472b6",
			"title": "Compendium QA Hub",
			"chips": [{"text": "Cards"}, {"text": "Products"}, {"text": "Monsters"}, {"text": "Regions"}],
			"kpis": [
				{"title": "Cards", "body": "Thumbnail browser and detail page.", "meta": "Sceneized entries", "accent": "#38bdf8"},
				{"title": "Products", "body": "Badge, KPI, and strategy cards.", "meta": "Sceneized entries", "accent": "#22c55e"},
				{"title": "Bestiary", "body": "KPI and action probability cards.", "meta": "Sceneized entries", "accent": "#fb7185"},
			],
			"actions": [
				{"id": "codex_cards", "title": "Cards", "body": "Open card reference.", "accent": "#38bdf8"},
				{"id": "codex_products", "title": "Products", "body": "Open market reference.", "accent": "#22c55e"},
				{"id": "codex_bestiary", "title": "Bestiary", "body": "Open monster reference.", "accent": "#fb7185"},
			],
			"footer": "Compendium handles long reference material; the main table stays scan-first.",
		},
	}


func _empty_payload_safe_state() -> Dictionary:
	return {
		"id": "empty_payload_safe_state",
		"view": "empty",
		"title": "Empty Payload Safe State",
		"summary": "No component data should crash the preview or leak private runtime data.",
		"expected_component": "EmptyStateLayer",
		"payload": {},
	}


func _long_text_stress() -> Dictionary:
	var fixture_data := _card_detail_long_text()
	fixture_data["id"] = "long_text_stress"
	fixture_data["title"] = "Long Text Stress"
	fixture_data["summary"] = "Long text pressure test for wrapping, chip rails, and detail grids."
	var payload: Dictionary = fixture_data.get("payload", {})
	payload["resolution"] = {
		"title": "Long public resolution",
		"body": "This deliberately long resolution note checks that the codex component can carry reference-grade rule copy while still preserving a scan-first hierarchy, stable minimum size, and clear public/private boundary in the Godot editor preview.",
		"meta": "Public note only. Hidden owner and private target fields are intentionally absent.",
		"accent": "#facc15",
	}
	fixture_data["payload"] = payload
	return fixture_data


func _missing_art_safe_state() -> Dictionary:
	var fixture_data := _monster_bestiary_detail()
	fixture_data["id"] = "missing_art_safe_state"
	fixture_data["title"] = "Missing Art Safe State"
	fixture_data["summary"] = "Monster detail should render a stable shell even when art payload is sparse."
	var payload: Dictionary = fixture_data.get("payload", {})
	payload["art"] = {}
	fixture_data["payload"] = payload
	return fixture_data


func _card_thumb(card_name: String, title: String, kind: String, accent: String, selected: bool) -> Dictionary:
	return {
		"card_name": card_name,
		"title": title,
		"display_name": title,
		"kind": kind,
		"rank_number": 1,
		"route": "Public route",
		"effect": "Readable table-use summary for preview QA.",
		"hint": "Hover preview | double-click detail",
		"accent": accent,
		"selected": selected,
		"chips": [
			{"text": "$80", "accent": "#facc15"},
			{"text": kind, "accent": accent},
		],
	}


func _contains_runtime_object(value: Variant) -> bool:
	if value is Callable or value is Object:
		return true
	if value is Dictionary:
		for key in value.keys():
			if _contains_runtime_object(key) or _contains_runtime_object(value[key]):
				return true
		return false
	if value is Array:
		for item in value:
			if _contains_runtime_object(item):
				return true
	return false
