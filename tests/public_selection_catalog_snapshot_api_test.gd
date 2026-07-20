extends SceneTree

const QUERY_SCENE := preload("res://scenes/runtime/presentation/TableSelectionCatalogQueryPort.tscn")
const QUERY_SCRIPT := preload("res://scripts/presentation/table_selection_catalog_query_port.gd")
const REGION_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/public_region_selection_catalog_snapshot.gd")
const PRODUCT_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/public_product_selection_catalog_snapshot.gd")
const SUSHI_TRACK_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/commodity_sushi_track_snapshot.gd")

var _checks := 0
var _failures: Array[String] = []
var _host: Node
var _world: WorldSessionState
var _product_market: ProductMarketRuntimeController
var _session: GameSessionRuntimeController
var _query: QUERY_SCRIPT


class InvalidProductMarket:
	extends ProductMarketRuntimeController

	var source_override: Dictionary = {}

	func public_product_selection_catalog_source() -> Dictionary:
		return source_override.duplicate(true)


class InvalidGameSession:
	extends GameSessionRuntimeController

	var summary_override: Dictionary = {}
	var revision_override := 0

	func session_summary() -> Dictionary:
		return summary_override.duplicate(true)

	func session_start_revision() -> int:
		return revision_override


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_build_fixture()
	_test_scene_composition_and_authorities()
	_test_pre_session_contract()
	_test_region_order_and_revision_semantics()
	_test_product_order_and_revision_semantics()
	_test_session_identity_and_source_metadata()
	_test_commodity_slot_behavior_isolation()
	_test_fail_closed_sources()
	_test_pure_data_zero_mutation_and_privacy()
	_test_source_negative_gates()
	print("PublicSelectionCatalogSnapshotApi: %d checks / %d failures" % [_checks, _failures.size()])
	_host.free()
	quit(0 if _failures.is_empty() else 1)


func _build_fixture() -> void:
	_host = Node.new()
	root.add_child(_host)
	_world = WorldSessionState.new()
	_world.name = "WorldSessionState"
	_host.add_child(_world)
	_product_market = ProductMarketRuntimeController.new()
	_product_market.name = "ProductMarketRuntimeController"
	_host.add_child(_product_market)
	_session = GameSessionRuntimeController.new()
	_session.name = "GameSessionRuntimeController"
	_host.add_child(_session)
	_query = QUERY_SCENE.instantiate() as QUERY_SCRIPT
	_query.name = "TableSelectionCatalogQueryPort"
	_query.world_session_state_path = NodePath("../WorldSessionState")
	_query.product_market_runtime_controller_path = NodePath("../ProductMarketRuntimeController")
	_query.game_session_runtime_controller_path = NodePath("../GameSessionRuntimeController")
	_host.add_child(_query)


func _test_scene_composition_and_authorities() -> void:
	var scene_source := FileAccess.get_file_as_string("res://scenes/runtime/GameRuntimeCoordinator.tscn")
	_expect(scene_source.count("[node name=\"TableSelectionCatalogQueryPort\"") == 1, "runtime composition contains one public selection catalog query port")
	_expect(scene_source.contains("world_session_state_path = NodePath(\"../WorldSessionState\")"), "region catalog explicitly binds WorldSessionState")
	_expect(scene_source.contains("product_market_runtime_controller_path = NodePath(\"../ProductMarketRuntimeController\")"), "product catalog explicitly binds ProductMarketRuntimeController")
	_expect(scene_source.contains("game_session_runtime_controller_path = NodePath(\"../GameSessionRuntimeController\")"), "catalog snapshots explicitly bind GameSessionRuntimeController")
	_expect(_query.get_node_or_null(_query.game_session_runtime_controller_path) == _session, "focused composition resolves the typed session dependency")
	var debug := _query.debug_snapshot()
	_expect(bool(debug.get("stateless", false)) and bool(debug.get("read_only", false)), "query port declares a stateless read-only boundary")
	_expect(not bool(debug.get("owns_region_catalog", true)) and not bool(debug.get("owns_product_catalog", true)), "query port owns neither mutable catalog")
	_expect(str(debug.get("region_authority", "")) == "WorldSessionState", "region order authority is explicit")
	_expect(str(debug.get("product_authority", "")) == "ProductMarketRuntimeController.PRODUCT_CATALOG", "product order authority is explicit")
	_expect(str(debug.get("session_authority", "")) == "GameSessionRuntimeController", "session identity authority is explicit")


func _test_pre_session_contract() -> void:
	var region_a := _query.compose_region_catalog()
	var region_b := _query.compose_region_catalog()
	var product_a := _query.compose_product_catalog()
	var product_b := _query.compose_product_catalog()
	_expect(region_a.is_valid() and not region_a.available and region_a.entries.is_empty(), "pre-session region catalog is a valid unavailable empty snapshot")
	_expect(product_a.is_valid() and not product_a.available and product_a.entries.is_empty(), "pre-session product catalog is a valid unavailable empty snapshot")
	_expect(region_a.to_dictionary() == region_b.to_dictionary(), "pre-session region snapshot is deterministic")
	_expect(product_a.to_dictionary() == product_b.to_dictionary(), "pre-session product snapshot is deterministic")
	_expect(region_a.session_id.is_empty() and region_a.session_revision == 0 and not region_a.source_ready, "pre-session region identity is deterministic and not ready")
	_expect(product_a.session_id.is_empty() and product_a.session_revision == 0 and not product_a.source_ready, "pre-session product identity is deterministic and not ready")
	_expect(region_a.source_owner_id == "WorldSessionState", "pre-session region source owner remains explicit")
	_expect(product_a.source_owner_id == "ProductMarketRuntimeController.PRODUCT_CATALOG", "pre-session product source owner remains explicit")
	_expect(region_a.ordering_revision.length() == 64 and region_a.data_revision.length() == 64 and region_a.ordering_fingerprint.length() == 64, "unavailable region snapshot still has canonical fingerprints")
	_expect(product_a.ordering_revision.length() == 64 and product_a.data_revision.length() == 64 and product_a.ordering_fingerprint.length() == 64, "unavailable product snapshot still has canonical fingerprints")
	_expect(region_a.ordering_revision != product_a.ordering_revision and region_a.ordering_fingerprint != product_a.ordering_fingerprint, "region and product empty catalogs use independent business fingerprints")


func _test_region_order_and_revision_semantics() -> void:
	_activate_session("session-selection-a", 101)
	_activate_world(_district_fixture())
	var baseline := _query.compose_region_catalog()
	_expect(baseline.is_valid() and baseline.available and baseline.entries.size() == 3, "active session exposes three valid public region entries")
	_expect(_region_ids(baseline) == ["region.000", "region.001", "region.002"], "region snapshot preserves authoritative WorldSession array order")
	_expect(baseline.entries[0].public_index == 0 and baseline.entries[2].public_index == 2, "region public indices are contiguous compatibility metadata")
	_expect(baseline.entries[1].public_status == "ruins" and baseline.entries[1].selectable, "ruined regions remain available for public table inspection")
	_expect(baseline.entry_by_id("region.002").public_name == "Outer Ring", "stable region lookup returns a detached typed entry")

	var order_revision := baseline.ordering_revision
	var data_revision := baseline.data_revision
	var fingerprint := baseline.ordering_fingerprint
	_world.set_game_time(1234.0)
	var after_time := _query.compose_region_catalog()
	_expect(after_time.ordering_revision == order_revision and after_time.data_revision == data_revision and after_time.ordering_fingerprint == fingerprint, "game time enters no region selection revision")

	var renamed := _district_fixture()
	(renamed[0] as Dictionary)["name"] = "Renamed North"
	(renamed[0] as Dictionary)["terrain"] = "ice"
	(renamed[2] as Dictionary)["destroyed"] = true
	_world.replace_districts(renamed, true)
	var after_public_data := _query.compose_region_catalog()
	_expect(after_public_data.ordering_revision == order_revision and after_public_data.ordering_fingerprint == fingerprint, "region names, terrain and lifecycle do not change ordering identity")
	_expect(after_public_data.data_revision != data_revision, "region public allowlist changes advance only data revision")

	var reordered := _district_fixture()
	reordered = [reordered[2], reordered[0], reordered[1]]
	_world.replace_districts(reordered, true)
	var after_reorder := _query.compose_region_catalog()
	_expect(after_reorder.ordering_revision != order_revision and after_reorder.ordering_fingerprint != fingerprint, "authoritative region reordering changes order revision and fingerprint")
	_expect(_region_ids(after_reorder) == ["region.002", "region.000", "region.001"], "query never sorts stable region IDs")
	_world.replace_districts(_district_fixture(), true)


func _test_session_identity_and_source_metadata() -> void:
	var region_a := _query.compose_region_catalog()
	var product_a := _query.compose_product_catalog()
	_expect(region_a.session_id == "session-selection-a" and product_a.session_id == region_a.session_id, "region and product snapshots bind session A")
	_expect(region_a.session_revision == _session.session_start_revision() and product_a.session_revision == region_a.session_revision, "both catalogs use the same deterministic session revision")
	_expect(region_a.source_ready and product_a.source_ready and region_a.available and product_a.available, "active source readiness aligns with availability")
	_expect(region_a.source_owner_id == "WorldSessionState" and product_a.source_owner_id == "ProductMarketRuntimeController.PRODUCT_CATALOG", "active snapshots expose exact domain source owners")

	_activate_session("session-selection-b", 202)
	var region_b := _query.compose_region_catalog()
	var product_b := _query.compose_product_catalog()
	_expect(region_b.session_id == "session-selection-b" and region_b.session_revision != region_a.session_revision, "new session changes catalog session identity")
	_expect(product_b.session_id == region_b.session_id and product_b.session_revision == region_b.session_revision, "new-session region and product snapshots remain pairable")
	_expect(region_b.ordering_revision == region_a.ordering_revision and region_b.ordering_fingerprint == region_a.ordering_fingerprint, "region order identity ignores session identity")
	_expect(product_b.ordering_revision == product_a.ordering_revision and product_b.ordering_fingerprint == product_a.ordering_fingerprint, "product order identity ignores session identity")
	_expect(not _same_catalog_session(region_a, product_b), "downstream callers can reject a region/product cross-session mix")
	_expect(_same_catalog_session(region_b, product_b), "same-session region/product snapshots are compatible")
	_expect(TablePresentationPureDataPolicy.is_pure_data(region_b.to_dictionary()) and TablePresentationPureDataPolicy.is_pure_data(product_b.to_dictionary()), "session/source metadata remains detached pure data")

	var missing_identity := region_b.to_dictionary()
	missing_identity.erase("session_id")
	_expect(not REGION_SNAPSHOT_SCRIPT.new().apply_dictionary(missing_identity).is_valid(), "missing session identity fails closed")
	var malformed_identity := product_b.to_dictionary()
	malformed_identity["session_revision"] = "not-an-int"
	_expect(not PRODUCT_SNAPSHOT_SCRIPT.new().apply_dictionary(malformed_identity).is_valid(), "malformed session revision fails closed without coercion")
	var wrong_owner := product_b.to_dictionary()
	wrong_owner["source_owner_id"] = "CommoditySushiTrack"
	_expect(not PRODUCT_SNAPSHOT_SCRIPT.new().apply_dictionary(wrong_owner).is_valid(), "wrong product source owner fails closed")
	var mismatched_ready := region_b.to_dictionary()
	mismatched_ready["source_ready"] = false
	_expect(not REGION_SNAPSHOT_SCRIPT.new().apply_dictionary(mismatched_ready).is_valid(), "source readiness cannot disagree with availability")

	var invalid_session := InvalidGameSession.new()
	invalid_session.name = "InvalidGameSession"
	invalid_session.summary_override = {"session_state": GameSessionRuntimeController.STATE_RUNNING, "session_id": 42}
	invalid_session.revision_override = 7
	_host.add_child(invalid_session)
	_query.game_session_runtime_controller_path = NodePath("../InvalidGameSession")
	var fail_closed := _query.compose_region_catalog()
	_expect(fail_closed.is_valid() and not fail_closed.available and fail_closed.session_id.is_empty() and fail_closed.session_revision == 0, "malformed runtime session identity yields deterministic unavailable output")
	_query.game_session_runtime_controller_path = NodePath("../GameSessionRuntimeController")
	invalid_session.free()


func _test_commodity_slot_behavior_isolation() -> void:
	var baseline := _query.compose_product_catalog()
	var slot_state := [
		{"commodity_slot_id": "slot.alpha", "product_id": "星露莓", "commodity_card_id": "commodity.star_dew_berry.rank_1", "slot_index": 0, "hovered": false, "claimable": true},
		{"commodity_slot_id": "slot.beta", "product_id": "星露莓", "commodity_card_id": "commodity.star_dew_berry.rank_2", "slot_index": 1, "hovered": true, "claimable": true},
	]
	_expect(str(slot_state[0]["product_id"]) == str(slot_state[1]["product_id"]) and str(slot_state[0]["commodity_slot_id"]) != str(slot_state[1]["commodity_slot_id"]), "two independent sushi slots may share one product ID")
	var sushi_a := _sushi_snapshot(slot_state, 1)
	_expect(sushi_a.is_valid() and sushi_a.items.size() == 2, "shared-product slot fixture forms a valid public sushi snapshot")

	(slot_state[0] as Dictionary)["slot_index"] = 1
	(slot_state[0] as Dictionary)["hovered"] = true
	(slot_state[1] as Dictionary)["slot_index"] = 0
	(slot_state[1] as Dictionary)["hovered"] = false
	var sushi_reordered := _sushi_snapshot(slot_state, 2)
	_expect(sushi_reordered.is_valid() and sushi_reordered.items[0].commodity_slot_id == "slot.beta", "slot reorder and hover-equivalent state change are real and independent")
	var after_reorder := _query.compose_product_catalog()
	_expect(after_reorder.entries.size() == 46 and _product_ids(after_reorder) == ProductMarketRuntimeController.PRODUCT_CATALOG, "slot reorder keeps one authoritative 46-entry product catalog")
	_expect(after_reorder.ordering_revision == baseline.ordering_revision and after_reorder.ordering_fingerprint == baseline.ordering_fingerprint, "slot reorder cannot change product ordering identity")

	slot_state.remove_at(0)
	slot_state.append({"commodity_slot_id": "slot.gamma", "product_id": "星露莓", "commodity_card_id": "commodity.star_dew_berry.rank_3", "slot_index": 1, "hovered": false, "claimable": false})
	var sushi_entry_exit := _sushi_snapshot(slot_state, 3)
	_expect(sushi_entry_exit.is_valid() and sushi_entry_exit.item_by_id("slot.gamma") != null, "slot entry and exit produce a distinct valid sushi state")
	var after_entry_exit := _query.compose_product_catalog()
	_expect(after_entry_exit.to_dictionary() == after_reorder.to_dictionary(), "slot entry, exit, claimability and hover-equivalent state leave product snapshot unchanged")
	_expect(not bool(_query.debug_snapshot().get("submits_commodity_claims", true)), "behavioral slot changes submit zero commodity claims")


func _test_product_order_and_revision_semantics() -> void:
	var baseline := _query.compose_product_catalog()
	_expect(baseline.is_valid() and baseline.available and baseline.entries.size() == 46, "product selection catalog exposes the exact 46 authoritative products")
	_expect(_product_ids(baseline) == ProductMarketRuntimeController.PRODUCT_CATALOG, "product order is exactly ProductMarketRuntimeController.PRODUCT_CATALOG")
	_expect(baseline.entries[0].product_id == "星露莓" and baseline.entries[45].product_id == "梦游蘑菇", "product endpoints preserve current opaque IDs")
	_expect(baseline.entries[0].public_name == baseline.entries[0].product_id, "display text equality does not create a second product identity")
	_expect(not baseline.entries[0].public_category.is_empty(), "authoritative public category is included only as data metadata")

	var order_revision := baseline.ordering_revision
	var data_revision := baseline.data_revision
	var fingerprint := baseline.ordering_fingerprint
	_product_market.product_market = {"星露莓": {"price": 999, "supply": 77, "demand": -12}}
	_product_market.business_cycle_count = 48
	_product_market.market_timer = 0.25
	var after_market := _query.compose_product_catalog()
	_expect(after_market.ordering_revision == order_revision and after_market.ordering_fingerprint == fingerprint, "price, supply, demand and market cycle enter no product ordering identity")
	_expect(after_market.data_revision == data_revision, "market state enters no static product catalog data revision")

	var region_before := _query.compose_region_catalog()
	var regions := _district_fixture()
	(regions[0] as Dictionary)["name"] = "Another Public Name"
	_world.replace_districts(regions, true)
	var product_after_region := _query.compose_product_catalog()
	_expect(product_after_region.to_dictionary() == after_market.to_dictionary(), "region public data changes cannot alter the product catalog snapshot")
	_expect(_query.compose_region_catalog().data_revision != region_before.data_revision, "region data revision advances independently from product revision")
	_expect(baseline.ordering_revision != _query.compose_region_catalog().ordering_revision, "region and product order revisions are separate domain values")
	_world.replace_districts(_district_fixture(), true)


func _test_fail_closed_sources() -> void:
	_world.replace_districts([
		{"region_id": "region.000", "name": "A"},
		{"region_id": "region.000", "name": "B"},
	], true)
	_expect(_unavailable_region_reason() == "region_id_invalid", "duplicate region IDs fail closed")
	_world.replace_districts([{"region_id": "", "name": "A"}], true)
	_expect(_unavailable_region_reason() == "region_id_invalid", "empty region ID fails closed without synthesis")
	var malformed_region := _district_fixture()
	(malformed_region[0] as Dictionary)["region_id"] = 101
	_world.replace_districts(malformed_region, true)
	_expect(_unavailable_region_reason() == "region_id_type_invalid", "numeric authoritative region ID fails at primitive validation")
	malformed_region = _district_fixture()
	(malformed_region[0] as Dictionary)["name"] = 202
	_world.replace_districts(malformed_region, true)
	_expect(_unavailable_region_reason() == "region_name_type_invalid", "numeric authoritative region name fails at primitive validation")
	malformed_region = _district_fixture()
	(malformed_region[0] as Dictionary)["terrain"] = 303
	_world.replace_districts(malformed_region, true)
	_expect(_unavailable_region_reason() == "region_terrain_type_invalid", "numeric authoritative region terrain fails at primitive validation")
	malformed_region = _district_fixture()
	(malformed_region[0] as Dictionary)["destroyed"] = "false"
	_world.replace_districts(malformed_region, true)
	_expect(_unavailable_region_reason() == "region_destroyed_type_invalid", "string authoritative destroyed state fails at primitive validation")
	_world.replace_districts(["not-a-dictionary"], true)
	_expect(_unavailable_region_reason() == "region_source_not_pure_data", "malformed region row fails closed")
	var forbidden_node := Node.new()
	_world.replace_districts([{"region_id": "region.000", "name": "A", "runtime_node": forbidden_node}], false)
	_expect(_unavailable_region_reason() == "region_source_not_pure_data", "runtime Object in region source fails closed")
	_world.replace_districts(_district_fixture(), true)
	forbidden_node.free()

	var noncontiguous_entries := [
		_region_entry("region.000", 0),
		_region_entry("region.001", 2),
	]
	var malformed_snapshot: REGION_SNAPSHOT_SCRIPT = REGION_SNAPSHOT_SCRIPT.new().apply_dictionary({
		"schema_version": 1,
		"catalog_kind": "region",
		"session_id": _session.session_summary().get("session_id", ""),
		"session_revision": _session.session_start_revision(),
		"source_owner_id": "WorldSessionState",
		"source_ready": true,
		"available": true,
		"unavailable_reason": "",
		"ordering_revision": REGION_SNAPSHOT_SCRIPT.ordering_revision_for(noncontiguous_entries),
		"data_revision": REGION_SNAPSHOT_SCRIPT.data_revision_for(noncontiguous_entries),
		"ordering_fingerprint": REGION_SNAPSHOT_SCRIPT.ordering_fingerprint_for(noncontiguous_entries),
		"entries": noncontiguous_entries,
	})
	_expect(not malformed_snapshot.is_valid(), "noncontiguous public region indices fail closed")
	var float_index := _region_entry("region.000", 0)
	float_index["public_index"] = 0.0
	_expect(not REGION_SNAPSHOT_SCRIPT.new().build(true, "", [float_index], "session-selection-b", _session.session_start_revision(), true).is_valid(), "float public index is not silently coerced to int")
	var integer_selectable := _product_entry("opaque-product", 0)
	integer_selectable["selectable"] = 1
	_expect(not PRODUCT_SNAPSHOT_SCRIPT.new().build(true, "", [integer_selectable], "session-selection-b", _session.session_start_revision(), true).is_valid(), "integer selectable metadata is not silently coerced to bool")

	var invalid_product := InvalidProductMarket.new()
	invalid_product.name = "InvalidProductMarket"
	_host.add_child(invalid_product)
	_query.product_market_runtime_controller_path = NodePath("../InvalidProductMarket")
	invalid_product.source_override = _product_source([
		_product_entry("duplicate", 0),
		_product_entry("duplicate", 1),
	])
	_expect(_unavailable_product_reason() == "product_source_invalid", "duplicate product IDs fail closed")
	invalid_product.source_override = _product_source([_product_entry("", 0)])
	_expect(_unavailable_product_reason() == "product_source_invalid", "empty product ID fails closed")
	invalid_product.source_override = _product_source([_product_entry("opaque-product", 0)]).merged({"private_cash": 9000}, true)
	_expect(_unavailable_product_reason() == "product_source_invalid", "unexpected product source fields fail closed")
	invalid_product.source_override = _product_source([_product_entry("opaque-product", 0)])
	(invalid_product.source_override["entries"][0] as Dictionary)["runtime_node"] = Node.new()
	var runtime_node := (invalid_product.source_override["entries"][0] as Dictionary)["runtime_node"] as Node
	_expect(_unavailable_product_reason() == "product_source_invalid", "non-pure product source fails closed")
	runtime_node.free()
	_query.product_market_runtime_controller_path = NodePath("../ProductMarketRuntimeController")
	invalid_product.free()

	var malformed_profiles := ProductMarketRuntimeController.PRODUCT_PROFILES.duplicate(true)
	(malformed_profiles[ProductMarketRuntimeController.PRODUCT_CATALOG[0]] as Dictionary)["category"] = 404
	var malformed_category_source := _product_market._public_product_selection_catalog_source_from(
		ProductMarketRuntimeController.PRODUCT_CATALOG,
		malformed_profiles
	)
	_expect(not bool(malformed_category_source.get("available", true)) \
		and str(malformed_category_source.get("unavailable_reason", "")) == "product_category_type_invalid" \
		and (malformed_category_source.get("entries", []) as Array).is_empty(), "malformed category in a full 46-product authority fails at primitive validation")
	var optional_profiles := ProductMarketRuntimeController.PRODUCT_PROFILES.duplicate(true)
	(optional_profiles[ProductMarketRuntimeController.PRODUCT_CATALOG[0]] as Dictionary).erase("category")
	var optional_category_source := _product_market._public_product_selection_catalog_source_from(
		ProductMarketRuntimeController.PRODUCT_CATALOG,
		optional_profiles
	)
	_expect(bool(optional_category_source.get("available", false)) \
		and (optional_category_source.get("entries", []) as Array).size() == 46 \
		and str(((optional_category_source.get("entries", []) as Array)[0] as Dictionary).get("public_category", "")) == "", "missing optional product category preserves the valid 46-product source contract")


func _test_pure_data_zero_mutation_and_privacy() -> void:
	_world.replace_districts(_district_fixture(), true)
	var world_before := _world.internal_snapshot()
	var product_before := _product_market.runtime_state_snapshot()
	var region := _query.compose_region_catalog()
	var product := _query.compose_product_catalog()
	_expect(_world.internal_snapshot() == world_before and _product_market.runtime_state_snapshot() == product_before, "both query methods have zero owner mutation")
	_expect(TablePresentationPureDataPolicy.is_pure_data(region.to_dictionary()), "region snapshot serializes as detached pure data")
	_expect(TablePresentationPureDataPolicy.is_pure_data(product.to_dictionary()), "product snapshot serializes as detached pure data")
	for forbidden in ["cash", "hand", "hidden_owner", "ai_plan", "private_warehouse", "futures_positions"]:
		_expect(not _contains_key_recursive(region.to_dictionary(), forbidden) and not _contains_key_recursive(product.to_dictionary(), forbidden), "catalog snapshots omit private field %s" % forbidden)
	for entry in product.entries:
		var row := entry.to_dictionary()
		_expect(not row.has("commodity_slot_id") and not row.has("commodity_card_id") and not row.has("slot_index"), "product %s is isolated from sushi slot and card identity" % entry.product_id)
	_expect(not bool(_query.debug_snapshot().get("submits_commodity_claims", true)), "query-triggered commodity claim count is zero")
	_expect(not bool(_query.debug_snapshot().get("reads_commodity_slots", true)), "COMMODITY_SLOT_ID_CONFUSION_COUNT=0")


func _test_source_negative_gates() -> void:
	var query_source := FileAccess.get_file_as_string("res://scripts/presentation/table_selection_catalog_query_port.gd")
	var scene_source := FileAccess.get_file_as_string("res://scenes/runtime/presentation/TableSelectionCatalogQueryPort.tscn")
	var combined := query_source + scene_source
	for forbidden in ["current_scene", "/root/" + "Main", "get_nodes_in_group", "TableSelectionState", "TableSelectionIntentPort", "GameScreen", "commodity_slot_id", "commodity_card_id", "claim_slot", "request_claim"]:
		_expect(not combined.contains(forbidden), "query boundary contains no forbidden dependency %s" % forbidden)
	for rng_call in ["randomize(", "randi(", "randf(", "RunRngService"]:
		_expect(not combined.contains(rng_call), "query boundary consumes no RNG through %s" % rng_call)
	var registry_source := FileAccess.get_file_as_string("res://scenes/runtime/V06SaveOwnerRegistry.tscn")
	_expect(registry_source.count("section_id = ") == 19, "save registry remains at 19 sections")
	_expect(not registry_source.contains("selection_catalog") and not registry_source.contains("TableSelectionCatalogQueryPort"), "selection catalogs add no save section or save owner")
	var main_source := FileAccess.get_file_as_string("res://scripts/" + "main.gd")
	_expect(not main_source.contains("TableSelectionCatalogQueryPort") and not main_source.contains("public_region_selection_catalog_source") and not main_source.contains("public_product_selection_catalog_source"), "Main has no catalog query route or fallback")


func _activate_world(districts: Array) -> void:
	_world.replace_players([
		{"id": 0, "name": "Player 1"},
		{"id": 1, "name": "Player 2"},
		{"id": 2, "name": "Player 3"},
	], true)
	_world.replace_districts(districts, true)


func _activate_session(session_id: String, seed: int) -> void:
	_session.set("_configured", true)
	_session.set("_ruleset_id", "v0.6")
	_session.set("_session_state", GameSessionRuntimeController.STATE_RUNNING)
	_session.set("_session_id", session_id)
	_session.set("_scenario_id", "selection-catalog-focused")
	_session.set("_seed", seed)
	_session.set("_setup_summary", {"player_count": 3, "source": "focused_test"})


func _district_fixture() -> Array:
	return [
		{"region_id": "region.000", "name": "North Ring", "terrain": "land", "destroyed": false, "hidden_owner": 0},
		{"region_id": "region.001", "name": "South Ring", "terrain": "ocean", "destroyed": true, "hidden_owner": 1},
		{"region_id": "region.002", "name": "Outer Ring", "terrain": "land", "destroyed": false, "hidden_owner": 2},
	]


func _region_entry(region_id: String, public_index: int) -> Dictionary:
	return {
		"region_id": region_id,
		"public_index": public_index,
		"public_name": "Region %d" % public_index,
		"public_status": "active",
		"selectable": true,
		"disabled_reason": "",
		"public_terrain": "land",
	}


func _product_entry(product_id: String, public_index: int) -> Dictionary:
	return {
		"product_id": product_id,
		"public_index": public_index,
		"public_name": product_id if not product_id.is_empty() else "Invalid",
		"selectable": true,
		"disabled_reason": "",
		"public_category": "test",
	}


func _product_source(entries: Array) -> Dictionary:
	return {
		"schema_version": 1,
		"available": true,
		"unavailable_reason": "",
		"entries": entries,
	}


func _sushi_snapshot(slot_state: Array, revision: int) -> SUSHI_TRACK_SNAPSHOT_SCRIPT:
	var items: Array = []
	for slot_variant in slot_state:
		var slot := slot_variant as Dictionary
		var claimable := bool(slot.get("claimable", false))
		items.append({
			"commodity_slot_id": str(slot.get("commodity_slot_id", "")),
			"commodity_card_id": str(slot.get("commodity_card_id", "")),
			"public_name": str(slot.get("product_id", "")),
			"public_icon_id": "test",
			"slot_index": int(slot.get("slot_index", -1)),
			"availability_state": "available" if claimable else "unavailable",
			"claimable": claimable,
			"public_claim_disabled_reason": "" if claimable else "slot_unavailable",
			"public_supply_pressure": 0,
			"public_demand_pressure": 0,
			"public_market_price": 100,
			"public_market_trend": 0,
			"public_refresh_phase": "steady",
			"display_accent_id": "test",
			"public_industry": "test",
			"public_short_effect": "test fixture",
		})
	return SUSHI_TRACK_SNAPSHOT_SCRIPT.new().apply_dictionary({
		"schema_version": 1,
		"available": true,
		"snapshot_revision": revision,
		"belt_revision": revision,
		"visibility_revision": revision,
		"market_revision": 1,
		"public_refresh_phase": "steady",
		"items": items,
		"empty_text": "No public commodities",
	})


func _same_catalog_session(left: Variant, right: Variant) -> bool:
	return not str(left.session_id).is_empty() \
		and str(left.session_id) == str(right.session_id) \
		and int(left.session_revision) == int(right.session_revision)


func _region_ids(snapshot: REGION_SNAPSHOT_SCRIPT) -> Array[String]:
	var result: Array[String] = []
	for entry in snapshot.entries:
		result.append(entry.region_id)
	return result


func _product_ids(snapshot: PRODUCT_SNAPSHOT_SCRIPT) -> Array:
	var result: Array = []
	for entry in snapshot.entries:
		result.append(entry.product_id)
	return result


func _unavailable_region_reason() -> String:
	var snapshot := _query.compose_region_catalog()
	_expect(snapshot.is_valid() and not snapshot.available and snapshot.entries.is_empty(), "invalid region source yields a valid unavailable empty snapshot")
	return snapshot.unavailable_reason


func _unavailable_product_reason() -> String:
	var snapshot := _query.compose_product_catalog()
	_expect(snapshot.is_valid() and not snapshot.available and snapshot.entries.is_empty(), "invalid product source yields a valid unavailable empty snapshot")
	return snapshot.unavailable_reason


func _contains_key_recursive(value: Variant, target_key: String) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if str(key_variant) == target_key or _contains_key_recursive((value as Dictionary)[key_variant], target_key):
				return true
	elif value is Array:
		for child in value as Array:
			if _contains_key_recursive(child, target_key):
				return true
	return false


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  PASS: %s" % label)
		return
	_failures.append(label)
	push_error("FAIL: %s" % label)
