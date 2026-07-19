extends Control
class_name IntelDossierPublicSnapshotCutoverBench

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const QUERY_SCENE := "res://scenes/runtime/presentation/IntelDossierViewerQueryPort.tscn"
const COMMAND_SCENE := "res://scenes/runtime/IntelPrivateCommandPort.tscn"
const CONTROLLER_SCENE := "res://scenes/runtime/IntelApplicationFlowController.tscn"
const BOARD_SCENE := "res://scenes/ui/IntelDossierBoard.tscn"
const OUTPUT_DIR := "res://docs/ui_qa/intel_query_command_split/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := OUTPUT_DIR + "intel_query_command_split_summary.png"

const RETIRED_FORMATTERS := [
	"_focused_intel_card_action_snapshots", "_intel_dossier_chip_snapshots", "_focused_intel_card_guess_entry",
	"_focused_intel_card_evidence_card", "_focused_intel_card_evidence_lines", "_intel_card_guess_time_text",
	"_focused_intel_card_private_note", "_intel_dossier_kpi_snapshots", "_intel_board_city_lines",
	"_intel_board_card_lines", "_intel_board_monster_lines", "_intel_board_warehouse_lines",
	"_intel_board_public_city_clue_lines", "_intel_board_next_step_lines", "_add_intel_dossier_link_button",
	"_add_intel_city_guess_buttons", "_populate_intel_dossier_links", "_intel_dossier_board_snapshot",
	"_intel_city_guess_line", "_player_city_guess_confidence_summary", "_player_city_guess_reason_summary",
	"_intel_card_guess_line",
]

@export var auto_run := true

@onready var status_label: Label = %StatusLabel
@onready var summary_label: Label = %SummaryLabel
@onready var ownership_text: RichTextLabel = %OwnershipText
@onready var results_text: RichTextLabel = %ResultsText

var _main: Control
var _flow: ApplicationFlowPort
var _query: IntelDossierViewerQueryPort
var _commands: IntelPrivateCommandPort
var _controller: IntelApplicationFlowController
var _coordinator: GameRuntimeCoordinator
var _world: WorldSessionState
var _annotations: CardHistoryPrivateAnnotationService
var _history: CardResolutionHistoryRuntimeService
var _monster: MonsterRuntimeController
var _records: Array = []
var _failures: Array[String] = []
var _evidence: Dictionary = {}
var _main_source := ""
var _open_elapsed_ms := -1
var _command_sequence := 0


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_cutover_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func retired_formatter_names() -> Array:
	return RETIRED_FORMATTERS.duplicate()


func cutover_cases() -> Array:
	return [
		"formal_assets_load", "scene_owned_composition", "dedicated_application_boundary",
		"authorized_query_zero_mutation", "public_world_categories", "public_facility_privacy",
		"viewer_private_guess", "viewer_isolation", "authorized_reveal",
		"card_annotation_delegation", "typed_public_links", "controller_exact_once",
		"final_settlement_real_owner", "main_routes_retired", "bounded_capture_manifest",
	]


func build_cutover_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id_variant in cutover_cases():
		records.append(_record(str(case_id_variant), false, "preview"))
	return {
		"suite": "intel-query-command-split-v1",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"record_count": records.size(),
		"retired_formatter_count": RETIRED_FORMATTERS.size(),
		"records": records,
	}


func run_cutover_suite() -> void:
	_records.clear()
	_failures.clear()
	_evidence.clear()
	_prepare_output_dir()
	await _prepare_formal_runtime()
	for case_id_variant in cutover_cases():
		var case_id := str(case_id_variant)
		var passed := bool(_evidence.get(case_id, false))
		var notes := str((_evidence.get("notes", {}) as Dictionary).get(case_id, "formal main.tscn evidence"))
		var record := _record(case_id, passed, notes)
		_records.append(record)
		if not passed:
			_failures.append("%s: %s" % [case_id, notes])
	var manifest := {
		"suite": "intel-query-command-split-v1",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"record_count": _records.size(),
		"passed_count": _passed_count(),
		"retired_formatter_count": RETIRED_FORMATTERS.size(),
		"open_elapsed_ms": _open_elapsed_ms,
		"main_metrics": _main_metrics(),
		"diagnostics": (_evidence.get("diagnostics", {}) as Dictionary).duplicate(true),
		"records": _records.duplicate(true),
	}
	_write_text(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text(REPORT_PATH, _markdown_report(manifest))
	if _main != null:
		_main.visible = false
	_update_ui(manifest)
	await get_tree().process_frame
	await _save_viewport(SCREENSHOT_PATH)
	await _dispose_runtime()
	print("IntelQueryCommandSplitBench|passed=%d/%d|output=%s" % [_passed_count(), _records.size(), OUTPUT_DIR])
	if not _failures.is_empty():
		push_error("IntelQueryCommandSplitBench failed:\n- %s" % "\n- ".join(_failures))
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _failures.is_empty() else 1)


func _prepare_formal_runtime() -> void:
	var notes := {}
	var diagnostics := {}
	_evidence["notes"] = notes
	_evidence["diagnostics"] = diagnostics
	_evidence["formal_assets_load"] = load(MAIN_SCENE_PATH) is PackedScene \
		and load(QUERY_SCENE) is PackedScene and load(COMMAND_SCENE) is PackedScene \
		and load(CONTROLLER_SCENE) is PackedScene and load(BOARD_SCENE) is PackedScene
	notes["formal_assets_load"] = "formal main, query, command, controller, and board scenes load"
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	_main = packed.instantiate() as Control if packed != null else null
	if _main == null:
		return
	add_child(_main)
	var main_script := _main.get_script() as Script
	_main_source = main_script.get_source_code() if main_script != null else ""
	var session_started: bool = await _start_formal_session()
	_query = _main.get_node_or_null("RuntimeServices/IntelDossierViewerQueryPort") as IntelDossierViewerQueryPort
	_commands = _main.get_node_or_null("RuntimeServices/IntelPrivateCommandPort") as IntelPrivateCommandPort
	_controller = _main.get_node_or_null("RuntimeServices/IntelApplicationFlowController") as IntelApplicationFlowController
	_coordinator = _main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator
	_world = _coordinator.world_session_state() if _coordinator != null else null
	_annotations = _coordinator.get_node_or_null("CardHistoryPrivateAnnotationService") as CardHistoryPrivateAnnotationService if _coordinator != null else null
	_history = _coordinator.get_node_or_null("CardResolutionHistoryRuntimeService") as CardResolutionHistoryRuntimeService if _coordinator != null else null
	_monster = _coordinator.monster_runtime_controller() if _coordinator != null else null
	_evidence["scene_owned_composition"] = session_started and _flow != null and _query != null and _commands != null \
		and _controller != null and _world != null and _annotations != null and _history != null and _monster != null
	notes["scene_owned_composition"] = "one formal scene-owned Flow, Query, Command, Controller, WorldSession, and annotation owner"
	if not bool(_evidence["scene_owned_composition"]):
		return
	var district_index := _first_foreign_city(0)
	var city_fixture := {"created": district_index >= 0, "reason_code": "existing_foreign_city" if district_index >= 0 else "foreign_city_missing"}
	if district_index < 0:
		city_fixture = _seed_foreign_city()
		district_index = _first_foreign_city(0)
	diagnostics["city_fixture"] = city_fixture.duplicate(true)
	var region_id := _world.region_id_for_district(district_index) if district_index >= 0 else ""
	var monster_fixture := _seed_public_monster(district_index)
	diagnostics["monster_fixture"] = monster_fixture.duplicate(true)
	_seed_public_history()
	var history_id := _first_history_id()
	var world_before := _world.internal_snapshot()
	var annotation_before := _annotations.viewer_snapshot(0)
	var snapshot := _query.snapshot_for_authorized_viewer(history_id, region_id)
	var snapshot_text := JSON.stringify(snapshot)
	_evidence["authorized_query_zero_mutation"] = bool(snapshot.get("valid", false)) \
		and _world.internal_snapshot() == world_before and _annotations.viewer_snapshot(0) == annotation_before \
		and int(_query.debug_snapshot().get("owner_mutation_delta", -1)) == 0
	notes["authorized_query_zero_mutation"] = "authorized viewer query returns detached data and mutates no owner"
	var world_intel: Array = snapshot.get("public_world_intel", []) if snapshot.get("public_world_intel", []) is Array else []
	_evidence["public_world_categories"] = not world_intel.is_empty() \
		and _world_categories_present(world_intel) and _clue_categories_present(snapshot.get("board", {}) as Dictionary)
	notes["public_world_categories"] = "public region, facility, product/demand, route, weather, and monster-attraction evidence is present"
	_evidence["public_facility_privacy"] = snapshot_text.contains("public_facility_entries") \
		and snapshot_text.contains("owner_player_index") and not _contains_private_material(snapshot)
	notes["public_facility_privacy"] = "audited public facility ownership remains visible; inventory and hidden owner stay absent"
	var generic_before := int(_flow.debug_snapshot().get("action_emission_count", 0))
	var controller_before := _controller.debug_snapshot()
	var started := Time.get_ticks_msec()
	var submitted := _flow.submit_intel_application_intent(IntelApplicationIntent.open(history_id, region_id))
	await _wait_frames(2)
	_open_elapsed_ms = Time.get_ticks_msec() - started
	var controller_after := _controller.debug_snapshot()
	_evidence["dedicated_application_boundary"] = submitted \
		and int(_flow.debug_snapshot().get("intel_application_intent_emission_count", 0)) == 1 \
		and int(_flow.debug_snapshot().get("action_emission_count", 0)) == generic_before
	notes["dedicated_application_boundary"] = "typed focus crosses ApplicationFlowPort exactly once and never emits generic action_requested"
	_evidence["controller_exact_once"] = int(controller_after.get("open_count", 0)) == int(controller_before.get("open_count", 0)) + 1 \
		and int(controller_after.get("query_count", 0)) == int(controller_before.get("query_count", 0)) + 1 \
		and int(controller_after.get("apply_count", 0)) == int(controller_before.get("apply_count", 0)) + 1
	notes["controller_exact_once"] = "one typed application intent produces one open, query, and apply"
	await _capture_stage("01_viewer_private_guess_before.png")
	var guessed_player := _first_valid_suspect(0)
	var city_receipt := _submit_command(&"set_city_owner_guess", 0, "region:%s" % region_id, _world.city_inference_owner_revision(0), {"suspected_player_index": guessed_player, "confidence": 2, "reason_id": "card"})
	var city_projection := _world.city_inference_projection(0)
	var city_record := _city_record_for_region(city_projection.get("records", []), region_id)
	var city_receipt_evidence := city_receipt.to_dictionary() if city_receipt != null else {"reason_code": "receipt_missing"}
	diagnostics["viewer_private_guess"] = {
		"district_index": district_index,
		"region_id": region_id,
		"receipt": city_receipt_evidence,
		"projection": city_record,
	}
	_evidence["viewer_private_guess"] = city_receipt != null and city_receipt.applied \
		and city_receipt.reason_code == "city_owner_guess_set" and not city_record.is_empty()
	notes["viewer_private_guess"] = "WorldSession receipt=%s; target=%s; projection=%s" % [
		str(city_receipt_evidence.get("reason_code", "receipt_missing")), region_id, JSON.stringify(city_record),
	]
	_flow.submit_intel_application_intent(IntelApplicationIntent.open(history_id, region_id))
	await _wait_frames(2)
	await _capture_stage("01_viewer_private_guess.png")
	var viewer_zero_before := _annotations.viewer_snapshot(0)
	var viewer_zero_revision := _annotations.owner_revision_for_viewer(0)
	var viewer_one_before := _annotations.owner_revision_for_viewer(1)
	_annotations.set_note_exact(1, history_id, "QA_VIEWER_ONE_PRIVATE_NOTE")
	var isolated := _query.snapshot_for_authorized_viewer(history_id, region_id)
	_evidence["viewer_isolation"] = not JSON.stringify(isolated).contains("QA_VIEWER_ONE_PRIVATE_NOTE") \
		and _annotations.viewer_snapshot(0) == viewer_zero_before \
		and _annotations.owner_revision_for_viewer(0) == viewer_zero_revision \
		and _annotations.owner_revision_for_viewer(1) != viewer_one_before
	notes["viewer_isolation"] = "viewer B mutation changes only B revision; viewer A snapshot and query remain isolated"
	await _capture_stage("02_viewer_isolation.png")
	var true_owner := -1
	if district_index >= 0 and district_index < _world.districts.size() and _world.districts[district_index] is Dictionary:
		true_owner = int((_world.districts[district_index] as Dictionary).get("city", {}).get("owner", -1))
	var reveal := _world.apply_authorized_city_reveal(0, region_id, true_owner, "QA authorized reveal") if not region_id.is_empty() else {
		"applied": false, "changed": false, "reason_code": "city_fixture_missing",
	}
	var reveal_snapshot := _query.snapshot_for_authorized_viewer(history_id, region_id)
	var reveal_record := _city_record_for_region(reveal_snapshot.get("city_inference_projection", []), region_id)
	diagnostics["authorized_reveal"] = {"owner_receipt": reveal.duplicate(true), "projection": reveal_record}
	_evidence["authorized_reveal"] = bool(reveal.get("applied", false)) \
		and str(reveal.get("reason_code", "")) == "authorized_city_reveal_set" \
		and int(reveal_record.get("confidence", 0)) == WorldSessionState.CITY_GUESS_AUTHORIZED_REVEAL \
		and bool(reveal_record.get("authorized_reveal", false))
	notes["authorized_reveal"] = "WorldSession receipt=%s; confidence=%d; locked=%s" % [
		str(reveal.get("reason_code", "receipt_missing")), int(reveal_record.get("confidence", 0)), str(reveal_record.get("authorized_reveal", false)),
	]
	_flow.submit_intel_application_intent(IntelApplicationIntent.open(history_id, region_id))
	await _wait_frames(2)
	await _capture_stage("03_authorized_reveal.png")
	var note_receipt := _submit_command(&"set_card_history_note", 0, history_id, _annotations.owner_revision_for_viewer(0), {"note_text": "QA viewer annotation"})
	var card_snapshot := _query.snapshot_for_authorized_viewer(history_id, region_id)
	_evidence["card_annotation_delegation"] = note_receipt != null and note_receipt.applied \
		and JSON.stringify(card_snapshot.get("own_private_card_annotations", {})).contains("QA viewer annotation")
	notes["card_annotation_delegation"] = "typed card note delegates to CardHistoryPrivateAnnotationService"
	_flow.submit_intel_application_intent(IntelApplicationIntent.open(history_id, region_id))
	await _wait_frames(2)
	await _capture_stage("04_card_annotation.png")
	var link_evidence := _typed_link_evidence(card_snapshot.get("public_navigation_links", []))
	diagnostics["typed_public_links"] = link_evidence.duplicate(true)
	_evidence["typed_public_links"] = _typed_links_present(card_snapshot.get("public_navigation_links", [])) \
		and bool(monster_fixture.get("applied", false))
	notes["typed_public_links"] = "typed kinds=%s; subjects=%s; monster owner=%s" % [
		JSON.stringify(link_evidence.get("kinds", [])), JSON.stringify(link_evidence.get("subjects", {})), str(monster_fixture.get("reason_code", "fixture_missing")),
	]
	var settlement := _main.get_node_or_null("RuntimeServices/FinalSettlementRuntimeComposition") as FinalSettlementRuntimeComposition
	var settlement_before := int(settlement.debug_snapshot().get("present_count", 0)) if settlement != null else -1
	var survivor_evidence := _seed_last_survivor(0)
	var outcome_receipt := _coordinator.resolve_victory_outcome("last_survivor", {})
	await _wait_frames(3)
	var settlement_after := int(settlement.debug_snapshot().get("present_count", 0)) if settlement != null else -1
	var settlement_snapshot := settlement.last_public_snapshot() if settlement != null else {}
	diagnostics["final_settlement_real_owner"] = {
		"authoritative_world": survivor_evidence,
		"outcome_receipt": outcome_receipt.duplicate(true),
		"present_count_before": settlement_before,
		"present_count_after": settlement_after,
	}
	_evidence["final_settlement_real_owner"] = settlement != null \
		and bool(survivor_evidence.get("valid", false)) \
		and str(outcome_receipt.get("reason_code", "")) == "last_survivor" \
		and outcome_receipt.get("winner_player_indices", []) == [0] \
		and settlement_after == settlement_before + 1 and not settlement_snapshot.is_empty()
	notes["final_settlement_real_owner"] = "bridge active=%s; owner reason=%s; winners=%s; present delta=%d" % [
		JSON.stringify(survivor_evidence.get("active_player_indices", [])), str(outcome_receipt.get("reason_code", "receipt_missing")),
		JSON.stringify(outcome_receipt.get("winner_player_indices", [])), settlement_after - settlement_before,
	]
	await _capture_stage("05_final_settlement.png")
	var retired := not _main_source.is_empty() \
		and not _main_source.contains("IntelApplicationIntent") and not _main_source.contains("IntelDossier") \
		and not _main_source.contains("func _intel_city_guess_entries(")
	for formatter_name in RETIRED_FORMATTERS:
		retired = retired and not _main_source.contains("func %s(" % str(formatter_name))
	_evidence["main_routes_retired"] = retired
	notes["main_routes_retired"] = "Main contains no executable typed Intel route, dossier builder, or dead city-query wrapper"
	_evidence["bounded_capture_manifest"] = _open_elapsed_ms >= 0 and _open_elapsed_ms < 5000 and cutover_cases().size() == 15
	notes["bounded_capture_manifest"] = "single bounded driver records five formal UI evidence stages and a 15-case manifest"


func _submit_command(kind: StringName, viewer_index: int, subject_id: String, revision: String, payload: Dictionary) -> IntelPrivateCommandReceipt:
	_command_sequence += 1
	return _commands.submit_command(IntelPrivateCommand.create("qa:%d" % _command_sequence, kind, viewer_index, subject_id, revision, payload))


func _start_formal_session() -> bool:
	_flow = _main.get_node_or_null("RuntimeServices/ApplicationFlowPort") as ApplicationFlowPort
	if _flow == null or not _flow.submit_action("setup"):
		return false
	await _wait_frames(2)
	var start_button := _main.find_child("NewGameSetupStartButton", true, false) as Button
	if start_button == null or start_button.disabled:
		return false
	start_button.pressed.emit()
	await _wait_frames(4)
	return true


func _seed_foreign_city() -> Dictionary:
	if _world == null or _world.players.size() < 2:
		return {"created": false, "reason_code": "fixture_dependency_missing", "attempts": []}
	var districts := _world.districts.duplicate(true)
	var attempts: Array = []
	for district_index in range(districts.size()):
		if not (districts[district_index] is Dictionary):
			continue
		var district := (districts[district_index] as Dictionary).duplicate(true)
		if str(district.get("terrain", "land")) == "ocean" or bool(district.get("destroyed", false)):
			continue
		var city: Dictionary = district.get("city", {}) if district.get("city", {}) is Dictionary else {}
		if city.is_empty():
			var region_id := _world.region_id_for_district(district_index)
			district["city"] = {
				"region_id": region_id,
				"owner": 1,
				"active": true,
				"level": 1,
				"gdp_focus": str(district.get("economic_focus", "balanced")),
				"products": [],
				"demands": [],
				"projects": [],
				"last_income": 0,
				"competition_matches": 0,
				"trade_routes": [],
				"warehouse_stockpile_count": 0,
				"warehouse_stockpile_units": 0,
				"warehouse_stockpile_products": [],
				"built_at": _world.game_time,
				"last_public_clue": "该区域已出现稳定的城市经营活动",
				"public_clues": [],
			}
			districts[district_index] = district
			_world.replace_districts(districts, true)
			var created := _first_foreign_city(0) == district_index
			attempts.append({"district_index": district_index, "created": created, "reason_code": "world_session_city_fixture_applied" if created else "world_session_city_fixture_rejected"})
			return {
				"created": created,
				"reason_code": "world_session_city_fixture_applied" if created else "world_session_city_fixture_rejected",
				"district_index": district_index,
				"region_id": region_id,
				"owner_api": "WorldSessionState.replace_districts",
				"attempts": attempts,
			}
	return {"created": false, "reason_code": "no_legal_foreign_city_fixture", "attempts": attempts}


func _seed_public_monster(preferred_district_index: int) -> Dictionary:
	if _monster == null or _world == null or _world.districts.is_empty():
		return {"applied": false, "reason_code": "monster_fixture_dependency_missing"}
	var district_index := preferred_district_index
	if district_index < 0 or district_index >= _world.districts.size() or bool((_world.districts[district_index] as Dictionary).get("destroyed", false)):
		district_index = _first_live_district()
	if district_index < 0:
		return {"applied": false, "reason_code": "monster_fixture_region_missing"}
	var existing := _monster.region_attraction_public_snapshot_v06(district_index)
	var existing_entries: Array = existing.get("entries", []) if existing.get("entries", []) is Array else []
	if not existing_entries.is_empty():
		return {"applied": true, "reason_code": "existing_public_monster", "district_index": district_index, "public_entry": (existing_entries[0] as Dictionary).duplicate(true)}
	var catalog_source := _monster.monster_codex_public_catalog_source_v06(0)
	var catalog_entry: Dictionary = catalog_source.get("entry", {}) if catalog_source.get("entry", {}) is Dictionary else {}
	if not bool(catalog_source.get("valid", false)) or str(catalog_entry.get("name", "")).is_empty():
		return {"applied": false, "reason_code": str(catalog_source.get("reason_code", "monster_catalog_fixture_missing"))}
	var save_data := _monster.to_save_data()
	var roster: Array = save_data.get("auto_monsters", []) if save_data.get("auto_monsters", []) is Array else []
	roster = roster.duplicate(true)
	var uid := maxi(1, int(save_data.get("next_auto_monster_uid", 1)))
	var hp := maxi(1, int(catalog_entry.get("hp", 40)))
	var district := _world.districts[district_index] as Dictionary
	roster.append({
		"uid": uid,
		"catalog_index": 0,
		"slot": roster.size(),
		"rank": 1,
		"name": str(catalog_entry.get("name", "怪兽")),
		"hp": hp,
		"max_hp": hp,
		"duration": 45.0,
		"remaining_time": 45.0,
		"move": float(catalog_entry.get("move", 1.0)),
		"move_damage": 1,
		"collision_damage": 1,
		"movement_traits": (catalog_entry.get("movement_traits", []) as Array).duplicate(true),
		"terrain_move_multiplier": (catalog_entry.get("terrain_move_multiplier", {}) as Dictionary).duplicate(true),
		"resource_drain": 1,
		"resource_focus": (catalog_entry.get("resource_focus", []) as Array).duplicate(true),
		"position": district_index,
		"world_position": district.get("center", Vector2.ZERO),
		"armor": maxi(0, int(catalog_entry.get("armor", 0))),
		"guard": 0,
		"ranged_guard": 0,
		"tether": 0,
		"down": false,
		"owner": -1,
		"owner_revealed": false,
		"owner_clue": "",
	})
	save_data["auto_monsters"] = roster
	save_data["next_auto_monster_uid"] = uid + 1
	var owner_receipt := _monster.apply_save_data(save_data)
	var public_snapshot := _monster.region_attraction_public_snapshot_v06(district_index)
	var public_entries: Array = public_snapshot.get("entries", []) if public_snapshot.get("entries", []) is Array else []
	return {
		"applied": bool(owner_receipt.get("applied", false)) and not public_entries.is_empty(),
		"reason_code": "monster_owner_save_applied" if bool(owner_receipt.get("applied", false)) else str(owner_receipt.get("reason_code", "monster_owner_save_rejected")),
		"district_index": district_index,
		"catalog_stable_id": "monster:0",
		"owner_receipt": owner_receipt.duplicate(true),
		"public_entry": (public_entries[0] as Dictionary).duplicate(true) if not public_entries.is_empty() else {},
	}


func _first_live_district() -> int:
	for district_index in range(_world.districts.size()):
		if _world.districts[district_index] is Dictionary and not bool((_world.districts[district_index] as Dictionary).get("destroyed", false)):
			return district_index
	return -1


func _seed_public_history() -> void:
	if _history == null or not _first_history_id().is_empty():
		return
	_history.append_resolved({
		"resolution_id": 90701,
		"player_index": 1,
		"slot_index": 0,
		"resolved_time": _world.game_time,
		"selected_district": maxi(0, _first_foreign_city(0)),
		"resolved": true,
		"aftermath_clue": "公开 QA 余波",
		"skill": {"name": "城市融资1", "display_name": "城市融资 I", "kind": "economy"},
	})


func _first_history_id() -> String:
	var query := _coordinator.get_node_or_null("CardHistoryPublicQueryPort") as CardHistoryPublicQueryPort if _coordinator != null else null
	if query == null:
		return ""
	var entries: Array = query.compose_history().get("entries", [])
	return str((entries[0] as Dictionary).get("history_entry_id", "")) if not entries.is_empty() else ""


func _first_foreign_city(viewer_index: int) -> int:
	if _world == null:
		return -1
	for district_index in range(_world.districts.size()):
		var district := _world.districts[district_index] as Dictionary
		var city: Dictionary = district.get("city", {}) if district.get("city", {}) is Dictionary else {}
		if bool(city.get("active", false)) and int(city.get("owner", -1)) >= 0 and int(city.get("owner", -1)) != viewer_index:
			return district_index
	return -1


func _first_valid_suspect(viewer_index: int) -> int:
	for player_index in range(_world.players.size()):
		if player_index != viewer_index:
			return player_index
	return -1


func _world_categories_present(entries: Array) -> bool:
	var text := JSON.stringify(entries)
	return text.contains("public_clue") and text.contains("public_facility_entries") \
		and text.contains("supply_product_ids") and text.contains("demand_text") \
		and text.contains("weather_text") and text.contains("trade_route_load") \
		and text.contains("monster_attraction_entries")


func _clue_categories_present(board: Dictionary) -> bool:
	var text := JSON.stringify(board.get("clues", []))
	return text.contains("公开区域证据") and text.contains("匿名设施概览") \
		and text.contains("商品、路线与天气") and text.contains("怪兽吸引线索")


func _typed_links_present(value: Variant) -> bool:
	var evidence := _typed_link_evidence(value)
	var kinds: Array = evidence.get("kinds", []) if evidence.get("kinds", []) is Array else []
	return kinds.has("open_region") and kinds.has("open_product") and kinds.has("open_monster") \
		and kinds.has("open_card") and kinds.has("focus_history") and kinds.has("open_economy")


func _typed_link_evidence(value: Variant) -> Dictionary:
	var kinds: Array[String] = []
	var subjects: Dictionary = {}
	if not (value is Array):
		return {"kinds": kinds, "subjects": subjects}
	for link_variant in value as Array:
		if not (link_variant is Dictionary):
			continue
		var payload: Variant = (link_variant as Dictionary).get("intent", {})
		var intent := IntelDossierActionIntent.from_dictionary(payload as Dictionary) if payload is Dictionary else null
		if intent != null:
			var kind := str(intent.intent_kind)
			if not kinds.has(kind):
				kinds.append(kind)
				subjects[kind] = intent.subject_id
	kinds.sort()
	return {"kinds": kinds, "subjects": subjects}


func _city_record_for_region(value: Variant, region_id: String) -> Dictionary:
	if not (value is Array):
		return {}
	for record_variant in value as Array:
		if record_variant is Dictionary and str((record_variant as Dictionary).get("region_id", "")) == region_id:
			return (record_variant as Dictionary).duplicate(true)
	return {}


func _seed_last_survivor(survivor_index: int) -> Dictionary:
	if _world == null or _coordinator == null or survivor_index < 0 or survivor_index >= _world.players.size():
		return {"valid": false, "reason_code": "last_survivor_fixture_invalid"}
	var players := _world.players.duplicate(true)
	for player_index in range(players.size()):
		if not (players[player_index] is Dictionary):
			return {"valid": false, "reason_code": "last_survivor_player_invalid"}
		var player := (players[player_index] as Dictionary).duplicate(true)
		player["eliminated"] = player_index != survivor_index
		players[player_index] = player
	_world.replace_players(players, true)
	var owner_snapshot := _coordinator.victory_control_world_snapshot()
	var active_player_indices: Array[int] = []
	for player_variant in owner_snapshot.get("players", []) if owner_snapshot.get("players", []) is Array else []:
		if player_variant is Dictionary and not bool((player_variant as Dictionary).get("eliminated", false)):
			active_player_indices.append(int((player_variant as Dictionary).get("player_index", -1)))
	return {
		"valid": active_player_indices == [survivor_index],
		"reason_code": "authoritative_last_survivor_ready" if active_player_indices == [survivor_index] else "authoritative_last_survivor_mismatch",
		"active_player_indices": active_player_indices,
		"world_visibility_scope": str(owner_snapshot.get("visibility_scope", "")),
	}


func _contains_private_material(value: Variant) -> bool:
	var text := JSON.stringify(value)
	for marker in ["warehouse_inventory", "private_hand", "hidden_owner", "true_owner", "raw_monsters", "ai_memory", "current_price", "base_price"]:
		if text.contains(marker):
			return true
	return false


func _capture_stage(file_name: String) -> void:
	await _save_viewport(OUTPUT_DIR + file_name)


func _save_viewport(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null:
		_failures.append("viewport image unavailable: %s" % path)
		return
	var absolute_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var error := image.save_png(absolute_path)
	if error != OK:
		_failures.append("screenshot failed: %s" % path)


func _record(case_id: String, passed: bool, notes: String) -> Dictionary:
	return {
		"case_id": case_id,
		"service_checked": case_id in ["authorized_query_zero_mutation", "public_world_categories"],
		"main_checked": case_id in ["scene_owned_composition", "main_routes_retired", "final_settlement_real_owner"],
		"summary_checked": case_id in ["public_world_categories", "bounded_capture_manifest"],
		"board_checked": case_id in ["viewer_private_guess", "authorized_reveal", "card_annotation_delegation"],
		"domain_boundary_checked": case_id in ["viewer_private_guess", "viewer_isolation", "final_settlement_real_owner"],
		"action_id_checked": false,
		"routing_checked": case_id in ["dedicated_application_boundary", "typed_public_links", "controller_exact_once"],
		"performance_checked": case_id == "bounded_capture_manifest",
		"privacy_checked": case_id in ["authorized_query_zero_mutation", "public_facility_privacy", "viewer_isolation"],
		"pure_data_checked": case_id in ["authorized_query_zero_mutation", "public_world_categories", "typed_public_links"],
		"deletion_checked": case_id == "main_routes_retired",
		"passed": passed,
		"notes": notes,
	}


func _passed_count() -> int:
	var count := 0
	for record_variant in _records:
		if bool((record_variant as Dictionary).get("passed", false)):
			count += 1
	return count


func _main_metrics() -> Dictionary:
	var nonblank_lines := 0
	var function_count := 0
	var variable_count := 0
	var constant_count := 0
	for line_variant in _main_source.split("\n"):
		var line := str(line_variant)
		if not line.strip_edges().is_empty():
			nonblank_lines += 1
		if line.begins_with("func "):
			function_count += 1
		elif line.begins_with("var "):
			variable_count += 1
		elif line.begins_with("const "):
			constant_count += 1
	return {"nonblank_lines": nonblank_lines, "function_count": function_count, "top_level_variable_count": variable_count, "constant_count": constant_count}


func _update_ui(manifest: Dictionary) -> void:
	var passed := int(manifest.get("passed_count", 0))
	var total := int(manifest.get("record_count", 0))
	status_label.text = "PASS" if passed == total else "FAIL"
	status_label.modulate = Color("#4ade80") if passed == total else Color("#fb7185")
	summary_label.text = "%d/%d formal ownership cases" % [passed, total]
	ownership_text.text = "[b]Formal main.tscn evidence[/b]\nApplicationFlowPort -> IntelApplicationFlowController -> viewer query/private command ports.\n\n[b]Captured stages[/b]\nViewer-private guess, viewer isolation, authorized reveal, card annotation, and real final settlement.\n\n[b]Open budget[/b]\n%d ms" % _open_elapsed_ms
	var lines: Array[String] = []
	for record_variant in _records:
		var record := record_variant as Dictionary
		var result := "PASS" if bool(record.get("passed", false)) else "FAIL"
		lines.append("[color=%s]%s[/color]  [b]%s[/b]\n%s" % ["#4ade80" if result == "PASS" else "#fb7185", result, str(record.get("case_id", "")), str(record.get("notes", ""))])
	results_text.text = "\n\n".join(lines)


func _markdown_report(manifest: Dictionary) -> String:
	var lines := [
		"# Intel Query / Command Split QA",
		"",
		"- Passed: %d/%d" % [int(manifest.get("passed_count", 0)), int(manifest.get("record_count", 0))],
		"- Formal typed open: %dms" % int(manifest.get("open_elapsed_ms", -1)),
		"- Driver scene: `res://scenes/tools/IntelDossierPublicSnapshotCutoverBench.tscn`",
		"",
		"| Case | Result | Notes |",
		"| --- | --- | --- |",
	]
	for record_variant in manifest.get("records", []):
		var record := record_variant as Dictionary
		lines.append("| %s | %s | %s |" % [str(record.get("case_id", "")), "PASS" if bool(record.get("passed", false)) else "FAIL", str(record.get("notes", "")).replace("|", "/")])
	return "\n".join(lines) + "\n"


func _prepare_output_dir() -> void:
	var absolute_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	for file_name in ["manifest.json", "report.md", "intel_query_command_split_summary.png", "01_viewer_private_guess_before.png", "01_viewer_private_guess.png", "02_viewer_isolation.png", "03_authorized_reveal.png", "04_card_annotation.png", "05_final_settlement.png"]:
		var absolute_path := absolute_dir.path_join(file_name)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)


func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failures.append("cannot write %s" % path)
		return
	file.store_string(content)


func _wait_frames(count: int) -> void:
	for _index in range(maxi(1, count)):
		await get_tree().process_frame


func _dispose_runtime() -> void:
	if _main == null:
		return
	for player_variant in _main.find_children("*", "AudioStreamPlayer", true, false):
		var player := player_variant as AudioStreamPlayer
		if player != null:
			player.stop()
			player.stream = null
	_main.queue_free()
	_main = null
	await _wait_frames(3)
