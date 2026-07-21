extends SceneTree

const MENU_SCENE := preload("res://scenes/ui/MenuOverlay.tscn")

var _checks := 0
var _failures: Array[String] = []
var _host: Node
var _world: WorldSessionState
var _history: CardResolutionHistoryRuntimeService
var _history_query: CardHistoryPublicQueryPort
var _annotations: CardHistoryPrivateAnnotationService
var _viewer_query: IntelDossierViewerQueryPort
var _commands: IntelPrivateCommandPort
var _application_flow: ApplicationFlowPort
var _controller: IntelApplicationFlowController
var _roles: RoleCatalogRuntimeService
var _region_source: RegionCodexPublicSourceService
var _session: GameSessionRuntimeController


class RegionPublicBridgeStub:
	extends Node

	func region_codex_public_facts(index: int) -> Dictionary:
		return {
			"available": index >= 0 and index < 3,
			"card_ids": ["公开设施牌"],
			"city": {"active": true, "last_income": 50 + index, "level": 2, "present": true},
			"contract_version": "region_codex_public_facts_v06",
			"demands": ["燃料"],
			"destroyed": false,
			"economic_focus_label": "能源",
			"facilities": [
				{"facility_type": "warehouse", "industry_id": "storage", "owner_kind": "player", "owner_player_index": 2, "rank": 1},
				{"facility_type": "factory", "industry_id": "energy", "owner_kind": "neutral", "owner_player_index": -1, "rank": 1},
			],
			"hp_now": 80,
			"hp_total": 100,
			"index": index,
			"name": "区域%d" % (index + 1),
			"neighbor_indices": [wrapi(index + 1, 0, 3)],
			"products": ["能源"],
			"public_clue": "公开运输痕迹",
			"reason_code": "ok",
			"region_id": "region.%03d" % index,
			"terrain": "land",
			"terrain_label": "陆地",
			"total": 3,
		}


class MonsterPublicStub:
	extends Node

	func region_attraction_public_snapshot_v06(index: int) -> Dictionary:
		return {
			"available": true,
			"contract_version": "monster_region_public_attraction_v06",
			"entries": [{"factor_codes": ["resource"], "name": "流星哨兵", "ordinal": 1, "reason": "被公开能源信号吸引"}],
			"reason_code": "ok",
			"region_index": index,
		}


class WeatherPublicStub:
	extends Node

	func district_summary(_index: int) -> String:
		return "晴朗"


class RoutePublicStub:
	extends Node

	func route_load_for_legacy_region(index: int) -> int:
		return index + 2


class SnapshotStub:
	extends Node

	func compose_region(source: Dictionary) -> Dictionary:
		return source.duplicate(true)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_build_runtime()
	await process_frame
	_seed_history_and_annotations()
	_test_query_denials()
	_test_authorized_query()
	_test_dedicated_flow_and_exact_refresh()
	_test_city_commands()
	_test_city_command_failures()
	_test_card_annotation_command()
	_test_confidence_100_and_cold_restore()
	_test_session_finished_rejection()
	_test_source_gates()
	_host.queue_free()
	await process_frame
	_finish()


func _build_runtime() -> void:
	_host = Node.new()
	_host.name = "IntelCutoverHost"
	root.add_child(_host)
	_roles = RoleCatalogRuntimeService.new()
	_roles.name = "RoleCatalog"
	_host.add_child(_roles)
	_world = WorldSessionState.new()
	_world.name = "World"
	_world.role_catalog_path = NodePath("../RoleCatalog")
	_host.add_child(_world)
	_world.restore({
		"schema_version": 1,
		"players": _players_fixture(),
		"districts": _districts_fixture(),
		"game_time": 12.0,
		"map_width_m": 1400.0,
		"map_height_m": 950.0,
		"world_geometry_revision": 7,
	}, true)
	_history = CardResolutionHistoryRuntimeService.new()
	_history.name = "History"
	_host.add_child(_history)
	_history.configure({"history_limit": 8})
	_history_query = CardHistoryPublicQueryPort.new()
	_history_query.name = "HistoryQuery"
	_host.add_child(_history_query)
	_history_query.configure(_history)
	_annotations = CardHistoryPrivateAnnotationService.new()
	_annotations.name = "Annotations"
	_host.add_child(_annotations)
	_annotations.configure(_history_query)
	var authorization := LocalViewerAuthorization.new()
	authorization.name = "Authorization"
	_host.add_child(authorization)
	authorization.configure(_world)
	var snapshot_service := IntelDossierPublicSnapshotService.new()
	snapshot_service.name = "SnapshotService"
	_host.add_child(snapshot_service)
	_region_source = RegionCodexPublicSourceService.new()
	_region_source.name = "RegionPublicSource"
	_host.add_child(_region_source)
	var region_bridge := RegionPublicBridgeStub.new()
	var monster_public := MonsterPublicStub.new()
	var weather_public := WeatherPublicStub.new()
	var route_public := RoutePublicStub.new()
	var region_snapshot := SnapshotStub.new()
	for dependency in [region_bridge, monster_public, weather_public, route_public, region_snapshot]:
		_host.add_child(dependency)
	_expect(bool(_region_source.configure({"region_public_bridge": region_bridge, "monster": monster_public, "weather": weather_public, "route": route_public, "snapshot": region_snapshot}).get("configured", false)), "strict public Region Codex source configures")
	_viewer_query = IntelDossierViewerQueryPort.new()
	_viewer_query.name = "ViewerQuery"
	_viewer_query.local_viewer_authorization_path = NodePath("../Authorization")
	_viewer_query.world_session_state_path = NodePath("../World")
	_viewer_query.card_history_public_query_path = NodePath("../HistoryQuery")
	_viewer_query.card_history_annotation_service_path = NodePath("../Annotations")
	_viewer_query.role_catalog_path = NodePath("../RoleCatalog")
	_viewer_query.region_codex_public_source_path = NodePath("../RegionPublicSource")
	_viewer_query.snapshot_service_path = NodePath("../SnapshotService")
	_host.add_child(_viewer_query)
	_session = GameSessionRuntimeController.new()
	_session.name = "GameSession"
	_host.add_child(_session)
	_commands = IntelPrivateCommandPort.new()
	_commands.name = "Commands"
	_commands.local_viewer_authorization_path = NodePath("../Authorization")
	_commands.world_session_state_path = NodePath("../World")
	_commands.card_history_public_query_path = NodePath("../HistoryQuery")
	_commands.card_history_annotation_service_path = NodePath("../Annotations")
	_commands.role_catalog_path = NodePath("../RoleCatalog")
	_commands.game_session_path = NodePath("../GameSession")
	_host.add_child(_commands)
	_application_flow = ApplicationFlowPort.new()
	_application_flow.name = "ApplicationFlow"
	_host.add_child(_application_flow)
	var compendium := CompendiumNavigationPort.new()
	compendium.name = "CompendiumNavigation"
	_host.add_child(compendium)
	var menu := MENU_SCENE.instantiate() as SpaceSyndicateMenuOverlay
	menu.name = "MenuOverlay"
	_host.add_child(menu)
	_controller = IntelApplicationFlowController.new()
	_controller.name = "IntelController"
	_controller.menu_overlay_path = NodePath("../MenuOverlay")
	_controller.application_flow_port_path = NodePath("../ApplicationFlow")
	_controller.viewer_query_port_path = NodePath("../ViewerQuery")
	_controller.private_command_port_path = NodePath("../Commands")
	_controller.compendium_navigation_port_path = NodePath("../CompendiumNavigation")
	_host.add_child(_controller)
	_application_flow.intel_requested.connect(_controller.open_intel)
	_application_flow.intel_application_intent_requested.connect(_controller.open_application_intent)


func _test_query_denials() -> void:
	var denied_world := WorldSessionState.new()
	denied_world.name = "DeniedWorld"
	denied_world.role_catalog_path = NodePath("../RoleCatalog")
	_host.add_child(denied_world)
	var denied_authorization := LocalViewerAuthorization.new()
	denied_authorization.name = "DeniedAuthorization"
	_host.add_child(denied_authorization)
	denied_authorization.configure(denied_world)
	var denied_query := IntelDossierViewerQueryPort.new()
	denied_query.name = "DeniedViewerQuery"
	denied_query.local_viewer_authorization_path = NodePath("../DeniedAuthorization")
	denied_query.world_session_state_path = NodePath("../DeniedWorld")
	denied_query.card_history_public_query_path = NodePath("../HistoryQuery")
	denied_query.card_history_annotation_service_path = NodePath("../Annotations")
	denied_query.role_catalog_path = NodePath("../RoleCatalog")
	denied_query.region_codex_public_source_path = NodePath("../RegionPublicSource")
	denied_query.snapshot_service_path = NodePath("../SnapshotService")
	_host.add_child(denied_query)
	var pre_session := denied_query.snapshot_for_authorized_viewer()
	_expect(not bool(pre_session.get("valid", true)) and str(pre_session.get("reason_code", "")) == "local_viewer_unauthorized", "pre-session query fails closed without a local viewer")
	var ai_only_players := _players_fixture()
	for player_variant in ai_only_players:
		(player_variant as Dictionary)["seat_type"] = "ai"
		(player_variant as Dictionary)["is_ai"] = true
	denied_world.restore({"schema_version": 1, "players": ai_only_players, "districts": _districts_fixture(), "game_time": 0.0, "map_width_m": 1400.0, "map_height_m": 950.0, "world_geometry_revision": 1}, true)
	var unauthorized := denied_query.snapshot_for_authorized_viewer()
	_expect(not bool(unauthorized.get("valid", true)) and str(unauthorized.get("reason_code", "")) == "local_viewer_unauthorized", "query fails closed when no unique local human viewer is authorized")


func _seed_history_and_annotations() -> void:
	_expect(bool(_history.append_resolved({
		"resolution_id": 70,
		"player_index": 2,
		"slot_index": 4,
		"resolved_time": 20.0,
		"selected_district": 1,
		"resolved": true,
		"aftermath_clue": "公开余波",
		"skill": {"name": "public_card_i", "display_name": "公共牌 I", "kind": "card_counter", "hidden_actor": "SECRET_ACTOR"},
		"true_owner": 2,
	}).get("appended", false)), "public history fixture appends")
	_expect(bool(_annotations.set_note_exact(0, "card-history:70", "MY_PRIVATE_NOTE").get("applied", false)), "authorized viewer annotation seeds")
	_expect(bool(_annotations.set_note_exact(1, "card-history:70", "OPPONENT_PRIVATE_NOTE").get("applied", false)), "opponent annotation fixture seeds")


func _test_authorized_query() -> void:
	var world_before := _world.internal_snapshot()
	var viewer_before := _annotations.viewer_snapshot(0)
	var opponent_before := _annotations.viewer_snapshot(1)
	var snapshot := _viewer_query.snapshot_for_authorized_viewer("card-history:70", "region.001")
	var encoded := JSON.stringify(snapshot)
	_expect(bool(snapshot.get("valid", false)) and int(snapshot.get("viewer_index", -1)) == 0, "query authorizes the single local human viewer")
	_expect(encoded.contains("MY_PRIVATE_NOTE") and not encoded.contains("OPPONENT_PRIVATE_NOTE"), "query includes only the current viewer annotation projection")
	_expect(not encoded.contains("OPPONENT_SECRET_HAND") and not encoded.contains("987654"), "query excludes opponent hand and cash")
	_expect(not encoded.contains("SECRET_ACTOR") and not encoded.contains("true_owner"), "query excludes hidden card actor and raw owner fields")
	for forbidden in ["warehouse_inventory", "inventory", "raw_monsters", "current_price", "base_price", "hidden_owner", "true_owner"]:
		_expect(not encoded.contains(forbidden), "query excludes raw/private public-world field %s" % forbidden)
	_expect(_world.internal_snapshot() == world_before and _annotations.viewer_snapshot(0) == viewer_before and _annotations.viewer_snapshot(1) == opponent_before, "query mutates zero owner state")
	_expect(int(_viewer_query.debug_snapshot().get("owner_mutation_delta", -1)) == 0 and not bool(_viewer_query.debug_snapshot().get("refreshes_route_network", true)), "query reports zero owner mutation and zero route refresh")
	var city_projection: Array = snapshot.get("city_inference_projection", [])
	_expect(city_projection.size() == 2 and str((city_projection[0] as Dictionary).get("region_id", "")) == "region.001", "focused region is first without exposing its owner")
	var detached := snapshot.duplicate(true)
	(detached.get("city_inference_projection", []) as Array)[0]["name"] = "MUTATED_COPY"
	_expect(str((_world.public_intel_projection().get("regions", []) as Array)[1].get("name", "")) != "MUTATED_COPY", "query result is detached pure data")
	for partition in ["public_world_intel", "own_private_city_or_facility_inference", "public_card_history", "own_private_card_annotations", "role_intel_capabilities", "public_navigation_links"]:
		_expect(snapshot.has(partition), "query exposes contract partition %s" % partition)
	var world_intel: Array = snapshot.get("public_world_intel", [])
	_expect(world_intel.size() == 3 and int((world_intel[0] as Dictionary).get("anonymous_warehouse_count", 0)) == 1, "query restores public regions and warehouse counts")
	var public_facilities: Array = (world_intel[0] as Dictionary).get("public_facility_entries", [])
	_expect(public_facilities.size() == 2 and int((public_facilities[0] as Dictionary).get("owner_player_index", -1)) == 2 and str((public_facilities[1] as Dictionary).get("owner_kind", "")) == "neutral", "query preserves the exact audited public facility ownership projection")
	_expect(str((world_intel[0] as Dictionary).get("demand_text", "")).contains("燃料") and str((world_intel[0] as Dictionary).get("weather_text", "")) == "晴朗" and int((world_intel[0] as Dictionary).get("trade_route_load", 0)) == int((world_intel[0] as Dictionary).get("district_index", -1)) + 2, "query restores public product demand, route load, and weather")
	_expect(((world_intel[0] as Dictionary).get("monster_attraction_entries", []) as Array).size() == 1 and str((((world_intel[0] as Dictionary).get("monster_attraction_entries", []) as Array)[0] as Dictionary).get("reason", "")).contains("能源"), "query restores non-numeric public monster attraction reasons")
	var clue_titles: Array[String] = []
	for clue_variant in (snapshot.get("board", {}) as Dictionary).get("clues", []) as Array:
		clue_titles.append(str((clue_variant as Dictionary).get("title", "")))
	_expect(clue_titles.has("公开区域证据") and clue_titles.has("匿名设施概览") and clue_titles.has("商品、路线与天气") and clue_titles.has("怪兽吸引线索"), "formatter restores all audited public clue categories")
	_expect(_board_has_typed_navigation(snapshot.get("board", {}) as Dictionary), "query board exposes typed deep links")


func _test_dedicated_flow_and_exact_refresh() -> void:
	var emissions := {"generic": 0, "dedicated": 0, "typed": 0}
	_application_flow.action_requested.connect(func(_action_id: StringName): emissions["generic"] = int(emissions["generic"]) + 1)
	_application_flow.intel_requested.connect(func(): emissions["dedicated"] = int(emissions["dedicated"]) + 1)
	_application_flow.intel_application_intent_requested.connect(func(_intent: IntelApplicationIntent): emissions["typed"] = int(emissions["typed"]) + 1)
	var preflight := _viewer_query.snapshot_for_authorized_viewer("card-history:70", "region.001")
	var set_intent := _first_board_intent(preflight.get("board", {}) as Dictionary, &"set_city_owner_guess")
	_expect(set_intent != null, "board provides a typed city owner command")
	var generic_before := int(_application_flow.debug_snapshot().get("action_emission_count", 0))
	_expect(_application_flow.submit_action("intel"), "intel application action is accepted")
	var opened := _controller.debug_snapshot()
	var flow_debug := _application_flow.debug_snapshot()
	_expect(bool(flow_debug.get("intel_signal_boundary", false)) \
		and int(flow_debug.get("intel_emission_count", 0)) == 1 \
		and int(flow_debug.get("action_emission_count", -1)) == generic_before \
		and int(emissions["dedicated"]) == 1 and int(emissions["generic"]) == 0, "intel_signal_boundary freezes dedicated exactly-once and generic zero dispatch")
	_expect(int(opened.get("open_count", 0)) == 1 and int(opened.get("query_count", 0)) == 1 and int(opened.get("apply_count", 0)) == 1, "scene controller opens, queries, and applies exactly once")
	var before_typed := _controller.debug_snapshot()
	_expect(_application_flow.submit_intel_application_intent(IntelApplicationIntent.open("card-history:70", "region.001")), "typed Intel application intent is accepted by the dedicated port boundary")
	var after_typed := _controller.debug_snapshot()
	_expect(int(emissions["typed"]) == 1 and int(emissions["generic"]) == 0, "typed Intel intent emits dedicated exactly once and never generic")
	_expect(int(after_typed.get("open_count", 0)) == int(before_typed.get("open_count", 0)) + 1 and int(after_typed.get("query_count", 0)) == int(before_typed.get("query_count", 0)) + 1 and int(after_typed.get("apply_count", 0)) == int(before_typed.get("apply_count", 0)) + 1, "typed boundary causes one open, one query, and one apply")
	var mutation_before := int(_world.debug_snapshot().get("city_inference_mutation_count", 0))
	_controller._on_board_action_requested(set_intent)
	var refreshed := _controller.debug_snapshot()
	_expect(int(_world.debug_snapshot().get("city_inference_mutation_count", 0)) == mutation_before + 1, "typed board command delegates one owner mutation")
	_expect(int(refreshed.get("command_count", 0)) == 1 and int(refreshed.get("command_refresh_count", 0)) == 1, "successful command refreshes exactly once")
	_expect(int(refreshed.get("query_count", 0)) == int(after_typed.get("query_count", 0)) + 1 and int(refreshed.get("apply_count", 0)) == int(after_typed.get("apply_count", 0)) + 1, "command adds exactly one query and one apply")


func _test_city_commands() -> void:
	var revision := _world.city_inference_owner_revision(0)
	var confidence := IntelPrivateCommand.create("city:confidence:1", &"set_city_guess_confidence", 0, "region:region.001", revision, {"confidence": 3})
	var mutation_before := int(_world.debug_snapshot().get("city_inference_mutation_count", 0))
	var first := _commands.submit_command(confidence)
	_expect(first.applied and first.changed and int(_world.city_inference_projection(0).get("records", [])[0].get("confidence", 0)) == 3, "confidence command succeeds through WorldSession owner")
	var replay := _commands.submit_command(confidence)
	_expect(replay.idempotent_replay and _zero_side_effect_deltas(replay) and int(_world.debug_snapshot().get("city_inference_mutation_count", 0)) == mutation_before + 1, "same command binding replays without a second mutation or repeated deltas")
	var rebound := IntelPrivateCommand.create("city:confidence:1", &"set_city_guess_confidence", 0, "region:region.001", revision, {"confidence": 1})
	var mismatch := _commands.submit_command(rebound)
	_expect(not mismatch.applied and mismatch.reason_code == "command_binding_mismatch", "same command id with a different binding fails closed")
	var stale := IntelPrivateCommand.create("city:reason:stale", &"set_city_guess_reason", 0, "region:region.001", revision, {"reason_id": "product"})
	var stale_receipt := _commands.submit_command(stale)
	_expect(not stale_receipt.applied and stale_receipt.reason_code == "owner_revision_stale" and _zero_side_effect_deltas(stale_receipt), "stale city revision fails with zero mutation and zero external deltas")
	var stale_replay := _commands.submit_command(stale)
	_expect(stale_replay.idempotent_replay and not stale_replay.applied and _zero_side_effect_deltas(stale_replay), "failed stale command replay remains exact-once with zero external deltas")
	revision = _world.city_inference_owner_revision(0)
	var reason := IntelPrivateCommand.create("city:reason:1", &"set_city_guess_reason", 0, "region:region.001", revision, {"reason_id": "product"})
	_expect(_commands.submit_command(reason).applied, "reason command succeeds")
	revision = _world.city_inference_owner_revision(0)
	var clear := IntelPrivateCommand.create("city:clear:1", &"clear_city_owner_guess", 0, "region:region.001", revision, {})
	_expect(_commands.submit_command(clear).applied and (_world.city_inference_projection(0).get("records", []) as Array).is_empty(), "clear city owner guess succeeds")
	var unauthorized_revision := _world.city_inference_owner_revision(1)
	var unauthorized := IntelPrivateCommand.create("city:unauthorized:1", &"set_city_owner_guess", 1, "region:region.000", unauthorized_revision, {"suspected_player_index": 2, "confidence": 2, "reason_id": "intuition"})
	_expect(not _commands.submit_command(unauthorized).applied, "non-local viewer command is rejected before mutation")


func _test_city_command_failures() -> void:
	var owner_revision := _world.city_inference_owner_revision(0)
	var world_mutations_before := int(_world.debug_snapshot().get("city_inference_mutation_count", 0))
	var dirty_before := int(_commands.debug_snapshot().get("save_dirty_mark_count", 0))
	var notifications_before := _annotations.notification_count()
	var invalid_subject := _commands.submit_command(IntelPrivateCommand.create("city:invalid-subject", &"set_city_owner_guess", 0, "region:region.missing", owner_revision, {"suspected_player_index": 1, "confidence": 2, "reason_id": "intuition"}))
	var invalid_suspect := _commands.submit_command(IntelPrivateCommand.create("city:invalid-suspect", &"set_city_owner_guess", 0, "region:region.001", owner_revision, {"suspected_player_index": 0, "confidence": 2, "reason_id": "intuition"}))
	var invalid_confidence := _commands.submit_command(IntelPrivateCommand.create("city:invalid-confidence", &"set_city_guess_confidence", 0, "region:region.001", owner_revision, {"confidence": 99}))
	var invalid_reason := _commands.submit_command(IntelPrivateCommand.create("city:invalid-reason", &"set_city_guess_reason", 0, "region:region.001", owner_revision, {"reason_id": "private-oracle"}))
	_expect(not invalid_subject.applied and invalid_subject.reason_code == "city_subject_invalid" and _zero_side_effect_deltas(invalid_subject), "invalid city subject fails closed with zero external deltas")
	_expect(not invalid_suspect.applied and invalid_suspect.reason_code == "city_suspect_invalid" and _zero_side_effect_deltas(invalid_suspect), "invalid city suspect fails closed with zero external deltas")
	_expect(not invalid_confidence.applied and invalid_confidence.reason_code == "city_confidence_invalid" and _zero_side_effect_deltas(invalid_confidence), "invalid city confidence fails closed with zero external deltas")
	_expect(not invalid_reason.applied and invalid_reason.reason_code == "city_reason_invalid" and _zero_side_effect_deltas(invalid_reason), "invalid city reason fails closed with zero external deltas")
	_expect(int(_world.debug_snapshot().get("city_inference_mutation_count", 0)) == world_mutations_before and int(_commands.debug_snapshot().get("save_dirty_mark_count", 0)) == dirty_before and _annotations.notification_count() == notifications_before, "all invalid city commands preserve owner, save-dirty, and notification counters")


func _test_card_annotation_command() -> void:
	var public_before := _history_query.compose_history()
	var revision := _annotations.owner_revision_for_viewer(0)
	var note := IntelPrivateCommand.create("card:note:1", &"set_card_history_note", 0, "card-history:70", revision, {"note_text": "UPDATED_PRIVATE_NOTE"})
	var receipt := _commands.submit_command(note)
	_expect(receipt.applied and receipt.changed and str(_annotations.annotation_for_viewer(0, "card-history:70").get("note_text", "")) == "UPDATED_PRIVATE_NOTE", "card note command delegates to annotation owner")
	_expect(_history_query.compose_history() == public_before, "private card command leaves public history unchanged")
	var annotation_revision := int(_annotations.debug_snapshot().get("revision", 0))
	var replay := _commands.submit_command(note)
	_expect(replay.idempotent_replay and _zero_side_effect_deltas(replay) and int(_annotations.debug_snapshot().get("revision", 0)) == annotation_revision, "card command replay is exact once with zero repeated external deltas")
	var stale := IntelPrivateCommand.create("card:tags:stale", &"set_card_history_tags", 0, "card-history:70", revision, {"private_tags": ["复盘"]})
	_expect(not _commands.submit_command(stale).applied, "stale annotation revision fails closed")


func _test_confidence_100_and_cold_restore() -> void:
	var reveal := _world.apply_authorized_city_reveal(0, "region.001", 1, "业主透镜 I")
	_expect(bool(reveal.get("applied", false)), "authorized reveal writes through the WorldSession owner")
	var records: Array = _world.city_inference_projection(0).get("records", [])
	_expect(records.size() == 1 and int((records[0] as Dictionary).get("confidence", 0)) == 100 and bool((records[0] as Dictionary).get("authorized_reveal", false)), "authorized confidence 100 is preserved in projection")
	var locked_revision := _world.city_inference_owner_revision(0)
	var locked := IntelPrivateCommand.create("city:locked:1", &"set_city_guess_confidence", 0, "region:region.001", locked_revision, {"confidence": 3})
	var locked_receipt := _commands.submit_command(locked)
	_expect(not locked_receipt.applied and locked_receipt.reason_code == "authorized_reveal_locked", "manual command cannot overwrite confidence 100")
	var envelope := _world.capture_envelope_save_data()
	var envelope_state: Dictionary = envelope.get("normalized_state", {}) if envelope.get("normalized_state", {}) is Dictionary else {}
	_expect(bool(envelope.get("accepted", false)) and envelope_state.keys().size() == 7 and int(envelope_state.get("schema_version", -1)) == 1, "world envelope root shape remains frozen")
	var restored := WorldSessionState.new()
	restored.name = "RestoredWorld"
	restored.role_catalog_path = NodePath("../RoleCatalog")
	_host.add_child(restored)
	var restore_receipt := restored.apply_envelope_save_data(envelope_state)
	var restored_records: Array = restored.city_inference_projection(0).get("records", [])
	_expect(bool(restore_receipt.get("applied", false)) and restored_records.size() == 1 and int((restored_records[0] as Dictionary).get("confidence", 0)) == 100, "cold restore round-trips authorized confidence 100")


func _test_session_finished_rejection() -> void:
	_session.set("_session_state", GameSessionRuntimeController.STATE_RUNNING)
	_session.finish_session({"reason": "focused-test"})
	var revision := _world.city_inference_owner_revision(0)
	var mutation_before := int(_world.debug_snapshot().get("city_inference_mutation_count", 0))
	var dirty_before := int(_commands.debug_snapshot().get("save_dirty_mark_count", 0))
	var notifications_before := _annotations.notification_count()
	var command := IntelPrivateCommand.create("city:finished-session", &"clear_city_owner_guess", 0, "region:region.001", revision, {})
	var receipt := _commands.submit_command(command)
	_expect(not receipt.applied and receipt.reason_code == "session_finished" and _zero_side_effect_deltas(receipt), "finished-session command fails closed with zero save-dirty, notification, and public-log deltas")
	_expect(int(_world.debug_snapshot().get("city_inference_mutation_count", 0)) == mutation_before and int(_commands.debug_snapshot().get("save_dirty_mark_count", 0)) == dirty_before and _annotations.notification_count() == notifications_before, "finished-session rejection leaves all owners and side-effect counters unchanged")
	var replay := _commands.submit_command(command)
	_expect(replay.idempotent_replay and not replay.applied and replay.reason_code == "session_finished" and _zero_side_effect_deltas(replay), "finished-session failure replay is exact-once with zero deltas")


func _test_source_gates() -> void:
	var main_source := FileAccess.get_file_as_string("res://scripts/" + "main.gd")
	for retired in [
		"func _open_intel_dossier_menu(",
		"func _intel_dossier_public_snapshot(",
		"func _intel_dossier_public_source_snapshot(",
		"func _on_intel_dossier_board_action_requested(",
		"IntelDossierBoardScene",
		"track_intel_",
		"codex_intel",
		"detail_intel",
		"district_open_intel",
	]:
		_expect(not main_source.contains(retired), "Main retired Intel route absent: %s" % retired)
	var controller_source := FileAccess.get_file_as_string("res://scripts/runtime/intel_application_flow_controller.gd")
	var query_source := FileAccess.get_file_as_string("res://scripts/presentation/intel_dossier_viewer_query_port.gd")
	_expect(not controller_source.contains("current_scene") and not controller_source.contains("/root/") and not controller_source.contains("has_method") and not controller_source.contains("Object.call"), "Intel controller has no Main/root/dynamic routing fallback")
	_expect(not query_source.contains("RouteNetwork") and not query_source.contains("refresh_routes") and not query_source.contains("current_scene") and not query_source.contains("/root/"), "viewer query has no route refresh or scene fallback")
	var role_source := FileAccess.get_file_as_string("res://scripts/runtime/role_catalog_runtime_service.gd")
	for retired in ["intel_card_trace_charges", "card_owner_guess_discount", "card_owner_guess_bonus"]:
		_expect(not role_source.contains('"%s"' % retired), "retired card-owner guess field remains absent: %s" % retired)


func _first_board_intent(board: Dictionary, kind: StringName) -> IntelDossierActionIntent:
	for group_variant in board.get("control_groups", []) as Array:
		for action_variant in (group_variant as Dictionary).get("actions", []) as Array:
			var action := action_variant as Dictionary
			var intent_value: Variant = action.get("intent", {})
			if intent_value is Dictionary and StringName((intent_value as Dictionary).get("intent_kind", "")) == kind:
				return IntelDossierActionIntent.from_dictionary(intent_value as Dictionary)
	return null


func _board_has_typed_navigation(board: Dictionary) -> bool:
	var kinds: Array[StringName] = []
	for link_variant in board.get("links", []) as Array:
		var link := link_variant as Dictionary
		var intent_value: Variant = link.get("intent", {})
		var intent := IntelDossierActionIntent.from_dictionary(intent_value as Dictionary) if intent_value is Dictionary else null
		if intent != null:
			kinds.append(intent.intent_kind)
	return kinds.has(&"open_region") and kinds.has(&"open_product") and kinds.has(&"open_monster") and kinds.has(&"focus_history") and kinds.has(&"open_card") and kinds.has(&"open_economy")


func _zero_side_effect_deltas(receipt: IntelPrivateCommandReceipt) -> bool:
	return receipt != null and receipt.save_dirty_delta == 0 and receipt.role_usage_delta == 0 \
		and receipt.notification_delta == 0 and receipt.public_log_delta == 0


func _players_fixture() -> Array:
	var players: Array = []
	for index in range(3):
		var role_card := _roles.definition_at(index)
		role_card["role_index"] = index
		var cash := 987654 if index == 1 else 1000 - index * 25
		players.append({
			"id": index, "name": "玩家%d" % (index + 1), "seat_type": "human" if index == 0 else "ai", "is_ai": index != 0,
			"ai_profile": {}, "ai_memory": {}, "role_index": index, "role_card": role_card,
			"base_starting_cash": 1000, "role_starting_cash_delta": cash - 1000, "starting_cash_total": cash,
			"cash": cash, "cash_cents": cash * 100, "cash_history": [cash], "v06_transaction_ledger": [],
			"eliminated": false, "eliminated_at": -1.0, "elimination_reason": "", "economic_ledger": [],
			"city_guesses": {}, "city_guess_confidence": {}, "city_guess_reasons": {},
			"cities_built": 0, "total_card_spend": 0, "card_purchase_count": 0, "total_build_spend": 0,
			"total_card_income": 0, "total_role_income": 0, "total_business_spend": 0, "action_cooldown": 0.0,
			"queued_card_tip": 0, "slots": [], "private_hand": ["OPPONENT_SECRET_HAND"] if index == 1 else [],
		})
	return players


func _districts_fixture() -> Array:
	var districts: Array = []
	for index in range(3):
		var neighbors: Array[int] = []
		for neighbor in range(3):
			if neighbor != index:
				neighbors.append(neighbor)
		districts.append({
			"region_id": "region.%03d" % index, "name": "区域%d" % (index + 1), "center": Vector2(100.0 + index * 200.0, 200.0),
			"polygon": [Vector2(index * 20.0, 0.0), Vector2(index * 20.0 + 15.0, 0.0), Vector2(index * 20.0 + 7.5, 12.0)],
			"area_m2": 160.0, "radius_m": 18.0, "hp": 100.0, "damage": 0.0, "last_damage_source": "",
			"last_damage_amount": 0.0, "last_damage_time": 0.0, "destroyed": false, "miasma": false,
			"terrain": "land", "terrain_label": "陆地", "products": ["商品%d" % index], "demands": ["需求%d" % index],
			"neighbors": neighbors, "transport_score": 1.0,
			"city": {"active": true, "owner": index, "level": 2, "products": ["商品%d" % index], "demands": ["需求%d" % index], "last_income": 50 + index},
		})
	return districts


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("INTEL_QUERY_COMMAND_CUTOVER_TEST|status=PASS|checks=%d" % _checks)
		quit(0)
		return
	push_error("INTEL_QUERY_COMMAND_CUTOVER_TEST failed:\n- " + "\n- ".join(_failures))
	quit(1)
