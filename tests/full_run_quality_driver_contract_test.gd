extends SceneTree

const DriverScript := preload("res://scripts/tools/full_run_quality_driver.gd")
const SnapshotScript := preload("res://scripts/viewmodels/full_run_quality_snapshot.gd")
const GameActionReceiptScript := preload("res://scripts/semantic/game_action_receipt_v1.gd")
const DRIVER_PATH := "res://scripts/tools/full_run_quality_driver.gd"
const SNAPSHOT_PATH := "res://scripts/viewmodels/full_run_quality_snapshot.gd"
const STEPPER_PATH := "res://scripts/tools/full_run_authoritative_runtime_stepper.gd"
const EXPECTED_SEEDS: Array[int] = [
	900626424,
	865984508,
	1419123495,
	1471257297,
	2038431333,
	948459684,
	1635321996,
	1280235321,
	899123644,
	43885519,
	950436207,
	102090361,
	124449428,
	545676743,
	1471036570,
	1968730869,
	1969748911,
	853285161,
	1765914414,
	1515999483,
]
const REQUIRED_TELEMETRY_KEYS := [
	"seed",
	"phase",
	"elapsed",
	"progress",
	"sale_receipt",
	"decision_window",
	"settlement",
	"invalid_actions",
	"nonfinite",
	"last_event",
]
const FORBIDDEN_DRIVER_TOKENS := [
	"_capture_run_state",
	"_apply_run_state",
	"_save_run",
	"resolve_victory_outcome",
	"advance_victory_control",
	"finish_session",
	"_apply_victory_outcome_receipt",
	"set(\"cash\"",
	"set(\"gdp\"",
	"scenes/ui/",
]
const FORBIDDEN_PUBLIC_KEYS := [
	"players",
	"cash",
	"cash_cents",
	"hand",
	"slots",
	"discard",
	"owner",
	"owner_id",
	"owner_player_index",
	"hidden_owner",
	"city_guesses",
	"ai_memory",
	"ai_plan",
	"utility_scores",
	"raw_envelope",
	"envelope",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var driver_source := FileAccess.get_file_as_string(DRIVER_PATH)
	var snapshot_source := FileAccess.get_file_as_string(SNAPSHOT_PATH)
	var stepper_source := FileAccess.get_file_as_string(STEPPER_PATH)
	_expect(not driver_source.is_empty() and not snapshot_source.is_empty(), "driver and telemetry source are readable")
	_expect(DriverScript.DRIVER_ID == "full_run_quality_driver_v2" and DriverScript.FIXED_SEEDS == EXPECTED_SEEDS, "driver carries one versioned execution contract and the audited seed set")
	_expect(bool(DriverScript.public_output_contract().get("single_run_only", false)), "this atomic block executes one seed and cannot claim a twenty-run completion rate")
	_expect(driver_source.contains("parse_command_line_options(OS.get_cmdline_user_args(), OS.get_cmdline_args())") and driver_source.contains("func _legacy_engine_driver_arguments("), "driver reads official arguments after the Godot delimiter and isolates the legacy engine-side compatibility path")
	_expect(driver_source.contains("if user_arguments.is_empty():") and driver_source.contains("if not legacy_arguments.is_empty():") and driver_source.contains('result["valid"] = false'), "canonical and legacy argument transports cannot be combined")
	_expect(driver_source.contains("_claim_option(seen_options") and driver_source.contains("_has_reserved_driver_prefix"), "duplicate, conflicting, and malformed reserved driver options fail closed")
	_expect(not driver_source.contains('main_instance.set("time_scale"') and not driver_source.contains("WAIT_SIMULATION_TIME_SCALE"), "driver does not claim a nonexistent per-Main time-scale property")
	_expect(driver_source.contains('["district_supply_wait", "facility_play_wait", "gdp_accumulation_wait"]'), "only explicit no-action rack, facility-play, and GDP waits use Engine acceleration")
	_expect(DriverScript.TELEMETRY_REFRESH_INTERVAL_MSEC == 100 and driver_source.contains("now_msec - last_telemetry_refresh_msec >= TELEMETRY_REFRESH_INTERVAL_MSEC"), "heavy viewer-authorized telemetry is bounded to ten refreshes per wall second instead of every render frame")
	_expect(driver_source.contains("var cached_ui_action") and driver_source.contains("ui_action_override") and not driver_source.contains("var ui_action := _scripted_ui_action(runtime_screen, exhausted_navigation_actions, public_progress, supply_rotation_state)"), "scripted UI projection is cached between telemetry refreshes instead of rebuilding the district-supply snapshot every frame")

	_expect(driver_source.contains("res://scenes/main.tscn") and driver_source.contains("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator"), "driver instantiates the real Main scene and current Coordinator composition")
	_expect(driver_source.contains("NewGameSetupDraftService") and driver_source.contains("SessionStartTransactionCoordinator") and driver_source.contains("SessionStartRequest.create"), "driver starts a normal four-seat session through the formal setup transaction")
	_expect(driver_source.contains('action_screen.submit_game_action_offer(offer, "human_click", {}, {})'), "all scripted economic actions consume a typed offer through GameScreen's public semantic adapter")
	_expect(driver_source.contains("TYPED_RACK_ACTION_IDS") and driver_source.contains('request["game_action_offer"] = offer.duplicate(true)'), "rack navigation preserves its projected GameAction offer instead of invoking the supply port directly")
	_expect(not driver_source.contains("if action_id in TYPED_RACK_ACTION_IDS:") and not driver_source.contains('request_district_supply_open('), "typed rack routing has no parallel direct GameScreen request path")
	_expect(driver_source.contains('runtime_screen is SpaceSyndicateGameScreen') and driver_source.contains('runtime_screen.has_method("submit_game_action_offer")') and driver_source.contains('runtime_screen.has_method("game_action_actor_authorization")') and driver_source.contains('"game_action_receipt_ready": game_action_receipt_ready'), "fresh-run preflight fails closed unless public offer submission and authoritative GameAction receipts are wired")
	_expect(driver_source.contains('"origin": "temporary_decision"') and driver_source.contains("func _temporary_decision_overlay(runtime_screen: Node) -> SpaceSyndicateOverlayLayer:"), "temporary decision actions bind the existing typed Overlay surface")
	_expect(driver_source.contains("temporary_decision_overlay.temporary_decision_action_requested.emit(action_id)"), "monster wager and other forced choices enter GameScreen through the production temporary-decision signal")
	_expect(driver_source.find('str(action.get("origin", "")) == "temporary_decision"') < driver_source.find('action_screen.submit_game_action_offer(offer, "human_click", {}, {})'), "typed forced-decision routing is resolved before the shared game-action offer adapter")
	_expect(driver_source.contains("and _temporary_decision_overlay(runtime_screen) != null"), "fresh-run preflight fails closed when the production temporary-decision surface is missing")
	_expect(driver_source.contains("scripted_ui_action_submission_rejected") and driver_source.contains("if not _submit_scripted_ui_action(runtime_screen, ui_action):"), "a missing typed UI entrypoint is reported immediately instead of timing out as false gameplay progress")
	_expect(driver_source.contains('_district_supply_query_port.snapshot_for_viewer(SCRIPTED_PLAYER_INDEX)') and driver_source.contains('GameActionIntentV1.ACTION_DISTRICT_SUPPLY_QUOTE') and not driver_source.contains('drawer.emit_signal("supply_action_requested"') and not driver_source.contains('drawer.call("debug_snapshot")'), "scripted human consumes the formal viewer query and submits quotes only through the semantic Action Spine")
	_expect(driver_source.contains('GameActionIntentV1.ACTION_DISTRICT_SELECT') and not driver_source.contains('request_district_selection(') and not driver_source.contains('map_view.emit_signal("district_selected"'), "scripted human rotates regions through a typed district-select GameAction offer")
	_expect(DriverScript.SUPPLY_QUOTE_REFRESH_ATTEMPTS_PER_RACK == 1 and DriverScript.SUPPLY_RACK_ROTATION_LIMIT == 8, "district exploration has explicit quote-retry and whole-run rotation bounds")
	_expect(DriverScript.SUPPLY_RESCAN_WORLD_SECONDS == 15.0 and driver_source.contains('supply_rotation_state["exhausted_world_seconds"]') and driver_source.contains('current_world_seconds - exhausted_world_seconds >= SUPPLY_RESCAN_WORLD_SECONDS'), "an exhausted public scan waits on authoritative world time before starting another legal browse epoch")
	_expect(driver_source.contains('GameActionIntentV1.ACTION_DISTRICT_SUPPLY_CLOSE') and driver_source.contains('GameActionIntentV1.ACTION_DISTRICT_SUPPLY_OPEN'), "bounded rack exploration uses semantic close and open offers")
	_expect(driver_source.contains('str(pending_action.get("origin", "")) in ["district_supply", "district_supply_rotation"]'), "typed rack rotation observes and classifies its action-port receipt instead of timing out on a forced-decision race")
	_expect(driver_source.contains('table_selection_port.receipt_ready.connect(_on_table_selection_receipt)') and driver_source.contains('"table_selection_receipt_ready": table_selection_receipt_ready'), "fresh-run composition requires and observes the scene-owned typed table-selection receipt")
	var accepted_supply_progress := {
		"origin": "district_supply_rotation",
		"supply_receipt_sequence": 7,
	}
	_expect(
		DriverScript.supply_receipt_confirms_progress(
			accepted_supply_progress,
			8,
			{"accepted": true, "applied": true}
		),
		"an exact newer accepted-and-applied typed rack receipt confirms action progress without waiting for presentation cadence"
	)
	_expect(
		not DriverScript.supply_receipt_confirms_progress(
			accepted_supply_progress,
			8,
			{"accepted": true, "applied": false}
		) \
			and not DriverScript.supply_receipt_confirms_progress(
				accepted_supply_progress,
				7,
				{"accepted": true, "applied": true}
			),
		"unapplied or stale rack receipts cannot advance the scripted action lifecycle"
	)
	var accepted_selection_progress := {
		"origin": "planet_map",
		"district_index": 4,
		"selection_receipt_sequence": 11,
	}
	_expect(
		DriverScript.selection_receipt_confirms_progress(
			accepted_selection_progress,
			12,
			{
				"accepted": true,
				"applied": true,
				"changed": true,
				"selection_kind": str(TableSelectionIntent.KIND_SELECT_DISTRICT),
				"district_index": 4,
				"selection_revision_before": 8,
				"selection_revision_after": 9,
			}
		),
		"an exact newer typed district-selection receipt confirms map progress without waiting for presentation cadence"
	)
	_expect(
		not DriverScript.selection_receipt_confirms_progress(
			accepted_selection_progress,
			12,
			{
				"accepted": true,
				"applied": true,
				"changed": true,
				"selection_kind": str(TableSelectionIntent.KIND_SELECT_DISTRICT),
				"district_index": 5,
				"selection_revision_before": 8,
				"selection_revision_after": 9,
			}
		),
		"a district-selection receipt for another target cannot advance the pending map action"
	)
	_expect(
		not DriverScript.selection_receipt_confirms_progress(
			accepted_selection_progress,
			12,
			{
				"accepted": true,
				"applied": true,
				"changed": false,
				"selection_kind": str(TableSelectionIntent.KIND_SELECT_DISTRICT),
				"district_index": 4,
				"selection_revision_before": 8,
				"selection_revision_after": 8,
			}
		),
		"an already-selected map target is a neutral replan, never authoritative progress"
	)
	var game_action_request_fingerprint := "c".repeat(64)
	var game_action_pending := {
		"game_action_required": true,
		"game_action_receipt_sequence": 21,
		"game_action_revision_before": 50,
		"game_action_request_id": "game-action.0.22",
		"game_action_request_fingerprint": game_action_request_fingerprint,
		"game_action_semantic_action_id": GameActionIntentV1.ACTION_DISTRICT_SUPPLY_PURCHASE,
	}
	var game_action_commit := GameActionReceiptScript.build({
		"schema_version": GameActionReceiptScript.SCHEMA_VERSION,
		"semantic_action_id": GameActionIntentV1.ACTION_DISTRICT_SUPPLY_PURCHASE,
		"accepted": true,
		"reason_id": "purchase-committed",
		"request_id": "game-action.0.22",
		"request_fingerprint": game_action_request_fingerprint,
		"authoritative_revision": 51,
		"committed_effect_refs": ["district.supply.purchase.facility.market.energy.rank_1"],
		"public_projection_ref": "none",
		"viewer_private_projection_ref": "viewer.feedback.game-action.0.22",
		"idempotent_replay": false,
		"request_id_collision": false,
		"refresh_scope": "full",
	})
	_expect(
		DriverScript.game_action_receipt_confirms_progress(
			game_action_pending,
			22,
			game_action_commit
		),
		"a bound GameAction receipt confirms progress only with accepted commit evidence and a newer authority revision"
	)
	var stale_game_action := game_action_commit.duplicate(true)
	stale_game_action["authoritative_revision"] = 50
	var uncommitted_game_action := game_action_commit.duplicate(true)
	uncommitted_game_action["committed_effect_refs"] = []
	var replayed_game_action := game_action_commit.duplicate(true)
	replayed_game_action["idempotent_replay"] = true
	_expect(
		not DriverScript.game_action_receipt_confirms_progress(
			game_action_pending,
			21,
			game_action_commit
		) \
			and not DriverScript.game_action_receipt_confirms_progress(
				game_action_pending,
				22,
				stale_game_action
			) \
			and not DriverScript.game_action_receipt_confirms_progress(
				game_action_pending,
				22,
				uncommitted_game_action
			) \
			and not DriverScript.game_action_receipt_confirms_progress(
				game_action_pending,
				22,
				replayed_game_action
			),
		"duplicate delivery, replay, stale authority, and missing effect evidence cannot advance Driver state"
	)
	var unavailable_rotation := {
		"phase": "open",
		"target_district": 3,
		"source_rack_signature": "closed-rack",
		"source_selection_revision": 41,
		"rotation_count": 3,
		"visited_districts": {0: true, 1: true, 2: true},
	}
	_expect(
		DriverScript.advance_supply_rotation_after_unavailable_open(unavailable_rotation, 3, 3, 6, 42) \
			and str(unavailable_rotation.get("phase", "")) == "select" \
			and int(unavailable_rotation.get("target_district", -1)) == 4 \
			and bool((unavailable_rotation.get("visited_districts", {}) as Dictionary).get(3, false)) \
			and int(unavailable_rotation.get("rotation_count", 0)) == 4,
		"a typed unavailable rotation-open receipt advances to the next unvisited public district"
	)
	var exhausted_rotation := unavailable_rotation.duplicate(true)
	exhausted_rotation["phase"] = "open"
	exhausted_rotation["target_district"] = 4
	exhausted_rotation["rotation_count"] = DriverScript.SUPPLY_RACK_ROTATION_LIMIT
	_expect(
		DriverScript.advance_supply_rotation_after_unavailable_open(exhausted_rotation, 4, 4, 6, 43) \
			and str(exhausted_rotation.get("phase", "")) == "exhausted" \
			and int(exhausted_rotation.get("target_district", 99)) == -1,
		"an unavailable rotation-open receipt respects the bounded exploration limit"
	)
	_expect(driver_source.contains('"origin": "planet_map"') and driver_source.contains('GameActionIntentV1.ACTION_DISTRICT_SELECT'), "bounded rack exploration selects another region through the same semantic Action Spine boundary")
	_expect(driver_source.contains('"selection_revision": int(selection.get("revision", -1))') and driver_source.contains("EconomyContinuationPlannerScript.rack_plan_signature("), "rack retry de-duplication binds the public selection revision to a stable rack-content and continuation-plan signature")
	_expect(driver_source.contains('"evaluated_rack_plan_signatures": preserved') and driver_source.contains("SUPPLY_EVALUATED_RACK_SIGNATURE_LIMIT") and driver_source.contains('supply_rotation_state.get("evaluated_rack_plan_signatures"'), "bounded exploration preserves evaluated rack-plan signatures across timed rescans")
	_expect(
		driver_source.contains('current_facility_count > observed_owned_facility_count') \
			and driver_source.contains('var preserved_facility_rack_hints') \
			and driver_source.contains('supply_rotation_state = _new_supply_rotation_state('),
		"an authoritative facility-count advance starts a fresh search epoch while retaining only revision-bound public facility navigation hints"
	)
	_expect(not driver_source.contains("public_market_purchasable") and not driver_source.contains("public_card_ids_for_district"), "scripted exploration does not query hidden or unopened-rack purchasability before visiting a district")
	_expect(driver_source.contains("world_effective_clock_snapshot") and driver_source.contains("victory_control_public_snapshot") and driver_source.contains("active_forced_decision"), "telemetry reads the authoritative clock, public victory state, and viewer-scoped decision window")
	_expect(driver_source.contains('STANDINGS_QUERY_PATH := "RuntimeServices/StandingsPublicQueryPort"') and driver_source.contains('standings_query_port.call("victory_progress_for_authorized_viewer")'), "scripted-player victory progress enters telemetry through the production viewer-authorized standings query")
	_expect(driver_source.contains('presentation_recent_public_log_entries') and driver_source.contains('CommodityFlowPostCommitPublicReceipt.EVENT_KIND'), "the first Sale Receipt is observed from the typed public-log receipt boundary instead of inferred from GDP")
	_expect(driver_source.contains('str(entry.get("event_kind", "")) != "final_settlement"') and driver_source.contains('outcome_id != expected_outcome_id') and driver_source.contains('int(final_log.get("public_entry_count", 0)) == 1') and driver_source.contains('str(final_log.get("outcome_id", "")) == str(stable.get("outcome_id", ""))'), "terminal completion requires exactly one typed public final-settlement log entry bound to the resolved outcome")
	_expect(driver_source.contains('"standings_query_ready": standings_query_ready') and driver_source.contains('has_method("victory_progress_for_authorized_viewer")') and driver_source.contains("and standings_query_ready"), "fresh-run preflight requires the unique typed standings progress boundary")
	_expect(not driver_source.contains("victory_control_private_snapshot") and not driver_source.contains("private_victory") and not driver_source.contains("own_candidate"), "full-run telemetry cannot call or retain a direct Victory private snapshot")
	_expect(not driver_source.contains("_standings_progress_from_snapshot") and not driver_source.contains("_nonnegative_ratio") and not driver_source.contains("scoreboard"), "full-run telemetry never parses a presentation KPI or localized ratio back into rules facts")
	_expect(driver_source.contains("FinalSettlementRuntimeComposition") and driver_source.contains("last_public_snapshot"), "driver observes the real final-settlement composition without forcing an outcome")
	_expect(driver_source.contains("registry_snapshot") and driver_source.contains("capture_resume_envelope") and driver_source.contains("restore_capability_incomplete"), "save continuation remains explicitly fail-closed while owner coverage is incomplete")
	_expect(driver_source.contains("scripted_ui_action_no_progress") and driver_source.contains("scripted_ui_action_disabled") and driver_source.contains("scripted_guidance_exhausted_before_settlement"), "driver reports an exact scripted-player stall or disabled action instead of claiming completion")
	_expect(driver_source.contains("EconomyContinuationPlannerScript.ranked_plans(") and driver_source.contains("_select_economy_continuation_plan(") and driver_source.contains("PublicEconomyContinuationObservationScript") and driver_source.contains("matching_facility_cards"), "driver plans ranked complementary economy continuation from the narrow viewer-safe typed observation")
	_expect(driver_source.contains('for strategy_kind in ["expand_economic_source", "build_economic_source"]'), "strategy navigation only opens the real rack after typed hand and visible-rack matching")
	_expect(driver_source.contains('int(strategy_action.get("source_revision", 0))'), "GDP expansion exhaustion is scoped to the authoritative source revision")
	_expect(driver_source.contains('pending_id != "strategy_expand_gdp"'), "a successful GDP expansion remains repeatable until the owner reports no legal facility target")
	var facility_hand_index := driver_source.find("var facility_hand_action")
	var continuation_strategy_index := driver_source.find('for strategy_kind in ["expand_economic_source", "build_economic_source"]', facility_hand_index)
	var visible_supply_index := driver_source.find("var visible_supply_action", facility_hand_index)
	var exhausted_visible_supply_index := driver_source.find("var exhausted_visible_supply_action", facility_hand_index)
	var rack_advancement_index := driver_source.find("var rack_advancement", facility_hand_index)
	var supply_rotation_index := driver_source.find("var supply_rotation_action", facility_hand_index)
	_expect(facility_hand_index >= 0 and facility_hand_index < continuation_strategy_index, "a matching facility already in hand is played before another strategy navigation action")
	_expect(driver_source.find("var facility_hand_action") < driver_source.find("var supply_rotation_action"), "a purchased facility is played before any public rack rotation can continue")
	_expect(
		exhausted_visible_supply_index > facility_hand_index \
			and exhausted_visible_supply_index < rack_advancement_index \
			and rack_advancement_index < supply_rotation_index,
		"an exhausted rack rechecks matching typed facilities, then bounded advancement, before returning the neutral exhausted wait"
	)
	_expect(
		DriverScript.SUPPLY_RACK_ADVANCEMENT_PURCHASE_LIMIT \
			== DriverScript.SUPPLY_RACK_ROTATION_LIMIT \
			and driver_source.contains("var _rack_advancement_purchase_count := 0") \
			and not driver_source.contains('rotation_state["rack_advancement_purchase_count"]') \
			and not driver_source.contains("_first_enabled_nonfacility_hand_action"),
		"rack advancement has one run-scoped cap aligned to the existing public-rack search bound and never plays arbitrary ordinary cards from hand"
	)
	_expect(
		driver_source.contains("district_supply_advancement_action_from_snapshot") \
			and driver_source.contains('str(snapshot.get("visibility_scope", "")) != "viewer_private"') \
			and driver_source.contains('GameActionIntentV1.ACTION_DISTRICT_SUPPLY_QUOTE') \
			and driver_source.contains('GameActionIntentV1.ACTION_DISTRICT_SUPPLY_PURCHASE') \
			and driver_source.contains("rack_advancement_purchase_committed") \
			and driver_source.contains("reset_supply_rotation_after_advancement"),
		"advancement uses the current-player typed snapshot, shared quote/purchase Action Spine, exact commit evidence, and a post-commit search reset"
	)
	_expect(
		driver_source.contains('surface.get("rack_source_revision", "")') \
			and driver_source.contains("facility_rack_hint_matches_snapshot") \
			and driver_source.contains("first_public_facility_rack_hint_for_plan") \
			and driver_source.contains("_promote_next_facility_rack_hint") \
			and driver_source.contains("rack_advancement_candidate_matches_snapshot"),
		"facility and advancement navigation re-query opaque public rack revisions, reject stale hints, and promote the next observed candidate"
	)
	_expect(
		not driver_source.contains("public_rack_snapshot(") \
			and not driver_source.contains("bags_by_region") \
			and not driver_source.contains('get("supply_revision"'),
		"driver never reads RegionSupply internals, future bags, or per-slot purchase credentials"
	)
	_expect(driver_source.contains("_facility_candidate_attempts") and driver_source.contains("candidate_attempt_signature") and driver_source.contains("_apply_driver_planning_transition") and not driver_source.contains("_exhausted_facility_card_signatures") and not driver_source.contains("first_unexhausted_card_by_kind"), "facility target bookkeeping uses revision-bound stable attempts without permanently exhausting a card")
	_expect(driver_source.contains("FACILITY_TARGET_RETRY_REASON_IDS") and driver_source.contains('blocked_facility.get("play_reason_id"') and driver_source.contains('target_retry["phase"] = "play.hand.facility_v06.retarget.%s"'), "a stable facility target rejection retries through the public map selection path without parsing player prose")
	_expect(driver_source.contains("public_new_facility_target_candidates") and driver_source.contains("matching_target_candidates") and driver_source.contains("facility_card_retry_signature") and driver_source.contains('target.get("source_revision", 0)') and not driver_source.contains("PRODUCT_INDUSTRY_CATALOG") and not driver_source.contains("_public_map_query") and not driver_source.contains('card_name.contains("facility.factory'), "facility targeting consumes typed public commodity-compatible candidates without copying lifecycle rules into the driver")
	_expect(visible_supply_index >= 0 and visible_supply_index < continuation_strategy_index, "an opened rack is consumed before the expansion button can repeat")
	_expect(driver_source.contains('bool(card.get("actionable", false))') and driver_source.contains("_next_matching_supply_facility_card") and not driver_source.contains("_next_supply_facility_card"), "facility supply selection admits only a typed complementary listing and never falls back to an unrelated ordinary card")
	_expect(driver_source.contains('production_installation_count := int(public_progress.get("production_installation_count", 0))') and driver_source.contains('growth_policy := production_growth_policy(') and driver_source.contains('required_top_k_gdp_per_minute') and driver_source.contains('top_k_gdp_per_minute'), "the scripted player treats three installations as an acceptance floor and continues legal typed growth until the public Victory GDP threshold is met")
	_expect(driver_source.contains('victory_state in ["qualification", "audit", "resolved"]') and driver_source.contains('rolling GDP') and driver_source.find('victory_state :=') < driver_source.find('growth_policy := production_growth_policy('), "once Victory owns qualification or audit, the driver freezes further growth and leaves terminal advancement to RuntimeLoop")
	_expect(driver_source.contains("PRODUCTION_MATURITY_WORLD_SECONDS := 30.0") and driver_source.contains("PRODUCTION_MATURITY_SALE_RECEIPT_COUNT := 2") and driver_source.contains("production_maturation_pending"), "each new production-installation count receives a bounded public Sale Receipt/world-time maturation observation")
	_expect(driver_source.contains('_peak_production_installation_count = maxi(') and driver_source.contains('int(stable.get("peak_production_installation_count", 0)) >= TARGET_PRODUCTION_INSTALLATION_COUNT'), "terminal acceptance proves that three production installations existed in the authoritative run even if later damage removes one")
	_expect(not driver_source.contains("production_chain_incomplete") and not driver_source.contains('var required_facility_kind := "factory"'), "the retired GDP-shortfall-to-factory-only policy is absent")
	_expect(driver_source.contains('not bool(wait_facts.get("has_visible_matching_facility", false))') and driver_source.contains('not bool(wait_facts.get("has_visible_matching_target", false))'), "a rack without the plan-matching facility and target rotates without buying unrelated cards")
	_expect(driver_source.contains('preview.get("action_reason_code", "facility_not_visible")') and driver_source.contains('return kind in ["facility", "facility_v06", "public_facility"]'), "a visible but unavailable matching facility retains a qualitative typed wait reason")
	_expect(driver_source.contains("action_records_economic_success") and driver_source.contains('origin == "district_supply"') and driver_source.contains('action_id == "district_supply_purchase_card"'), "navigation, selection, preview, and refresh progress do not update economic-success evidence")
	_expect(driver_source.contains("const ACTION_ENGINE_TIME_SCALE := 1.0") and not driver_source.contains("SUPPLY_WAIT_ENGINE_TIME_SCALE"), "every automatic driver frame remains at human-scale engine time")
	_expect(driver_source.contains("district_supply_port.receipt_ready.connect(_on_district_supply_action_receipt)") and driver_source.contains("blocked_typed_receipt"), "district-supply failures are attributed from the scene-owned typed receipt instead of a generic UI timeout")
	_expect(driver_source.contains('GameActionIntentV1.ACTION_DISTRICT_SUPPLY_PURCHASE') and driver_source.contains('GameActionIntentV1.ACTION_DISTRICT_SUPPLY_QUOTE') and driver_source.contains('game_action_receipt_confirms_progress'), "quote and purchase use GameAction offers and authoritative commit evidence")
	var private_root_call_token := "main" + '.call("_'
	_expect(not driver_source.contains("submit_current_actor_action") and not driver_source.contains(".submit_intent(") and not driver_source.contains('main_instance.call("_') and not driver_source.contains(private_root_call_token), "driver cannot bypass the public scene boundary through an owner submission port or private Main call")
	var retired_main_source_path := "scripts/" + "main.gd"
	_expect(not driver_source.contains(retired_main_source_path), "driver cannot inspect or depend on the retired Main script source")
	_expect(driver_source.contains('"time_to_first_rack"') and driver_source.contains('"time_to_first_quote"') and driver_source.contains('"time_to_first_purchase"') and DriverScript.SUMMARY_PUBLIC_KEYS.has("milestones"), "single-run output reports accepted rack, quote, and purchase wall-time milestones")
	_expect(driver_source.contains('"phase": "play.supply.rotation_exhausted_wait.%d"') and not driver_source.contains('"id": "district_supply_rotation_exhausted"'), "bounded public rack exploration becomes a neutral observation wait instead of a false product blocker")
	_expect(driver_source.contains('preview.get("action_reason_code", "facility_not_visible")') and not driver_source.contains('preview.get("player_cash"'), "facility wait telemetry records only an allowlisted qualitative reason and never reads exact cash")
	_expect(driver_source.contains('preview.get("primary_action_id", "")') and driver_source.contains('"quote" if primary_action_id == "district_supply_preview_card" else "purchase"'), "scripted human follows the visible quote-or-purchase projection instead of treating every enabled button as a purchase")
	_expect(not driver_source.contains('"id": "district_supply_purchase_card",\n\t\t\t"phase": "play.supply.purchase.%s" % preview_card_name'), "driver no longer hard-codes enabled district supply previews as purchases")
	_expect(visible_supply_index >= 0 and visible_supply_index < continuation_strategy_index, "an in-progress matching expansion purchase completes before new navigation")
	_expect(driver_source.contains('standings_progress.get("required_controlled_region_count", 0)') and driver_source.contains('standings_progress.get("required_top_k_gdp_per_minute", 0)') and not driver_source.contains('victory.get("victory_rule"'), "driver reads dynamic victory requirements from the authorized standings projection while Victory public remains state-only")
	_expect(driver_source.contains('production_floor_established := production_installation_count') and driver_source.contains('>= TARGET_PRODUCTION_INSTALLATION_COUNT') and driver_source.contains('not bool(sale_receipt.get("observed", false))') and driver_source.contains('"phase": "play.gdp_first_receipt"'), "driver establishes the three-installation proof floor before waiting for the first typed Sale Receipt")
	_expect(driver_source.contains("draft.reset_to_defaults()"), "fixed-seed runs reset the unique draft owner to the first-run depth instead of inheriting local settings")
	_expect(driver_source.contains('(session as GameSessionRuntimeController).session_summary()') and driver_source.contains('setup.get("player_count", 0)') and driver_source.contains('setup.get("ai_player_count", 0)'), "fixed-seed start verification consumes the authoritative session setup summary")
	_expect(not driver_source.contains("world_session_state()") and not driver_source.contains("players_variant"), "full-run QA cannot inspect private WorldSessionState player records to verify startup")
	_expect(driver_source.contains("district_supply_quote_availability") and driver_source.contains("Engine.time_scale = ACTION_ENGINE_TIME_SCALE"), "driver waits for world-time quote availability without scaling a future forced-decision frame")
	_expect(DriverScript.ACTION_ENGINE_TIME_SCALE == 1.0 and DriverScript.AUTHORITATIVE_WAIT_STEP_SECONDS == 1.0 and DriverScript.AUTHORITATIVE_WAIT_STEPS_PER_RENDER_FRAME == 1 and DriverScript.AUTHORITATIVE_WAIT_BASE_STEP_LIMIT == 360 and DriverScript.AUTHORITATIVE_WAIT_MAX_STEP_LIMIT == 480 and DriverScript.AUTHORITATIVE_PROGRESS_STALL_WINDOW_STEPS == 90 and DriverScript.BLOCKED_REALTIME_TOTAL_STEP_LIMIT >= 15, "each one-second authoritative step is followed by a typed action probe and only recent deterministic progress may lease the bounded 360-to-480 extension")
	_expect(not driver_source.contains("AUTHORITATIVE_WAIT_TOTAL_STEP_LIMIT") and driver_source.contains("authoritative_progress_budget_decision") and driver_source.contains("authoritative_runtime_progress_stalled") and driver_source.contains("authoritative_world_time_budget_exhausted"), "the stale single total-step constant is deleted in favor of distinct progress-stall, world-time, and hard-step failure modes")
	_expect(driver_source.contains("PROGRESS_CHECKPOINT_INTERVAL_STEPS := 30") and driver_source.contains('"type": "progress_checkpoint"') and driver_source.contains('"steps_since_progress"') and driver_source.contains('"rng_draw_count"'), "the driver emits step-aligned viewer-safe progress checkpoints")
	_expect(stepper_source.contains("const MAX_STEP_SECONDS := 1.0") and stepper_source.contains("step_seconds > MAX_STEP_SECONDS") and not driver_source.contains("AUTHORITATIVE_PRE_RECEIPT_ACCUMULATION_SECONDS") and not driver_source.contains("AUTHORITATIVE_AUDIT_STEP_SECONDS"), "the bounded driver has no 55/120-second single-frame shortcut")
	_expect(stepper_source.count("advance_frame_for_test(") == 1 and not stepper_source.contains("CommodityFlow") and not stepper_source.contains("VictoryControl") and not stepper_source.contains("RuntimePhaseCoordinator"), "the test-only stepper calls only the unique RuntimeLoop entry and knows no child owner")
	_expect(stepper_source.contains("advance_blocked_realtime_bounded") and stepper_source.contains("BLOCKED_REALTIME_PHASE_TRACE") and stepper_source.contains("blocked_realtime_delta_mismatch"), "blocked-only stepping validates its closed phase trace and zero-world receipt")
	_expect(driver_source.contains("MonsterWagerResponseSink") and driver_source.contains("_on_monster_wager_response_receipt") and driver_source.contains("blocked_realtime_wait_policy"), "blocked-real-time acceleration is attested by the applied domain receipt")
	_expect(driver_source.contains("_capture_world_clock_checkpoint") and driver_source.contains("blocked_realtime_step_evidence") and driver_source.contains("_capture_rng_checkpoint"), "each blocked-only step proves world-clock and RNG invariance")
	_expect(driver_source.contains("_next_matching_supply_facility_card") and driver_source.contains("source_region_dark") and driver_source.contains("district_supply_preview_card"), "driver rotates only matching visible facility listings when the public quote reports an unavailable source region")
	_expect(DriverScript.SUPPLY_QUOTE_REFRESH_INTERVAL_MSEC == 250 and driver_source.contains("quote_retry_allowed") and driver_source.contains('GameActionIntentV1.ACTION_DISTRICT_SUPPLY_QUOTE') and not driver_source.contains("_refresh_visible_supply_quote") and not driver_source.contains('"source": "full_run_quote_refresh"'), "stale quotes retry through a new semantic offer without a Drawer-signal bypass")
	_expect(driver_source.contains("gdp_accumulation_wait") and driver_source.contains("victory_qualification"), "driver stops manufacturing clicks after strategy review and lets authoritative GDP/victory time advance")
	_expect(driver_source.contains("MenuModalOverlay") and driver_source.contains("continue_requested"), "driver closes strategy pages through the scene-owned menu signal")
	_expect(driver_source.contains("if not temporary.is_empty():") and not driver_source.contains('temporary.get("visible"') and not driver_source.contains('temporary.get("active"'), "driver consumes the normalized non-empty temporary-decision snapshot instead of retired visible/active flags")
	_expect(driver_source.contains('player_board.get("hand_cards"') and driver_source.contains('player_board.get("actions"') and driver_source.contains('"play.hand.facility_v06.%s"') and driver_source.contains('"play.board.%s.%s"'), "post-coach scripted play uses only public HandRack and PlayerBoard action ids with stateful progress fingerprints")
	_expect(driver_source.contains('"board_primary"') and driver_source.contains("navigation_no_state_change") and driver_source.contains('"selected_district_summary"'), "one-shot board navigation cannot loop in one region and becomes eligible again after a public region change")
	_expect(driver_source.contains("observation_window_elapsed_before_settlement") and driver_source.contains("driver_wall_timeout"), "bounded observation and wall timeout have distinct failure codes")
	_expect(not driver_source.contains("observation_window_elapsed_during_action"), "observation expiry no longer misclassifies an action admitted near the boundary as a product stall")
	_expect(driver_source.contains("observation_action_policy") and driver_source.contains("OBSERVATION_ACTION_DRAIN"), "the observation boundary stops admitting new actions while boundedly draining an already accepted action")
	_expect(driver_source.find("observation_policy == OBSERVATION_ACTION_CLOSED") < driver_source.find("if not _submit_scripted_ui_action(runtime_screen, ui_action):"), "the closed observation gate runs before any next scripted UI action can be submitted")
	_expect(DriverScript.TERMINAL_QUIESCENCE_FRAME_COUNT == 8 and driver_source.contains("for _frame_index in range(TERMINAL_QUIESCENCE_FRAME_COUNT)") and driver_source.contains("await process_frame"), "terminal quiescence samples eight consecutive production render frames")
	_expect(driver_source.contains('"world_effective_us": int(clock.get("world_effective_us", -1))') and driver_source.contains("presentation_public_world_projection") and driver_source.contains('"public_world_fingerprint": public_world_fingerprint') and driver_source.contains("if stable != baseline_stable:"), "terminal stability compares an integer authoritative clock and viewer-safe public-world fingerprint with the complete oracle on every frame")
	_expect(driver_source.contains('_record_rng_checkpoint("terminal_quiescent", coordinator)') and driver_source.contains("rng_quiescence_evidence") and driver_source.contains('"rng_quiescence_verified", false'), "successful completion requires terminal and terminal-quiescent RNG checkpoints with zero within-run draw delta")
	_expect(driver_source.contains('progress.get("qualification_duration_seconds", null)') and driver_source.contains('progress.get("audit_duration_seconds", null)') and not driver_source.contains("EXPECTED_QUALIFICATION_DURATION") and not driver_source.contains("EXPECTED_AUDIT_DURATION"), "timer evidence consumes the viewer-authorized Standings duration contract without copying rule durations into the driver")
	_expect(not driver_source.contains('"completion_rate"') and not driver_source.contains('"completed_runs"'), "single-run output cannot masquerade as aggregate quality evidence")
	_expect(
		DriverScript.authoritative_manual_wait_policy(
			{},
			"running",
			{"active": false},
			{"id": "gdp_accumulation_wait", "disabled": true},
			{}
		),
		"GDP accumulation uses the bounded one-step authoritative wait"
	)
	_expect(
		DriverScript.authoritative_manual_wait_policy(
			{},
			"running",
			{"active": false},
			{"id": "district_supply_wait", "disabled": true},
			{"phase": "exhausted"}
		),
		"an exhausted public-rack epoch waits fifteen world seconds through the same bounded one-step authority"
	)
	_expect(
		not DriverScript.authoritative_manual_wait_policy(
			{},
			"running",
			{"active": false},
			{"id": "district_supply_wait", "disabled": true},
			{"phase": "browsing"}
		),
		"an actionable public-rack browsing epoch is never accelerated as a neutral wait"
	)
	_expect(
		not DriverScript.authoritative_manual_wait_policy(
			{},
			"running",
			{"active": true},
			{"id": "gdp_accumulation_wait", "disabled": true},
			{}
		),
		"an active forced decision always closes authoritative wait acceleration"
	)
	_expect(
		not DriverScript.authoritative_manual_wait_policy(
			{"id": "already_submitted"},
			"running",
			{"active": false},
			{"id": "gdp_accumulation_wait", "disabled": true},
			{}
		),
		"a pending typed action always closes authoritative wait acceleration"
	)
	_expect(
		DriverScript.terminal_presentation_drain_policy(
			{},
			{"state": "resolved", "completed": false}
		),
		"a resolved outcome receives a bounded no-action frame to finish the exact-once presentation chain"
	)
	_expect(
		not DriverScript.terminal_presentation_drain_policy(
			{"id": "already_submitted"},
			{"state": "resolved", "completed": false}
		),
		"terminal presentation drain never overlaps a pending typed action"
	)
	_expect(
		not DriverScript.terminal_presentation_drain_policy(
			{},
			{"state": "resolved", "completed": true}
		),
		"a committed terminal presentation exits the drain immediately"
	)
	_expect(
		DriverScript.terminal_lifecycle_drain_policy({}, {"state": "audit"}, 150_000, 180_000),
		"an in-progress terminal audit can use the explicit max-wall grace after the observation window"
	)
	_expect(
		DriverScript.terminal_lifecycle_drain_policy({}, {"state": "qualification"}, 150_000, 180_000),
		"an in-progress qualification can finish only inside the same bounded max-wall grace"
	)
	_expect(
		not DriverScript.terminal_lifecycle_drain_policy({}, {"state": "idle"}, 150_000, 180_000),
		"an idle run cannot extend the observation window"
	)
	_expect(
		not DriverScript.terminal_lifecycle_drain_policy({"id": "pending"}, {"state": "audit"}, 150_000, 180_000),
		"terminal lifecycle grace never bypasses an in-flight action"
	)
	_expect(
		not DriverScript.terminal_lifecycle_drain_policy({}, {"state": "audit"}, 180_000, 180_000),
		"terminal lifecycle grace cannot exceed the configured hard wall"
	)

	var pending_wager := {
		"origin": "temporary_decision",
		"decision_id": "monster_wager_7",
		"decision_kind": "monster_wager",
		"decision_revision": 11,
		"wager_receipt_sequence": 4,
	}
	var current_wager := {
		"decision_id": "monster_wager_7",
		"decision_kind": "monster_wager",
		"decision_revision": 11,
		"blocks_global_time": true,
		"visible_to_viewer": true,
	}
	var applied_wager_receipt := {
		"schema_version": 1,
		"sequence": 5,
		"decision_id": "monster_wager_7",
		"decision_revision": 11,
		"viewer_index": 0,
		"player_index": 0,
		"accepted": true,
		"applied": true,
		"decision_closed": false,
		"visibility_scope": "viewer_private",
	}
	applied_wager_receipt["receipt_fingerprint"] = JSON.stringify(applied_wager_receipt).sha256_text()
	_expect(DriverScript.blocked_realtime_wait_policy(pending_wager, current_wager, applied_wager_receipt, "running"), "an applied actor-bound wager receipt grants one blocked-real-time lease")
	var authorization_only_receipt := applied_wager_receipt.duplicate(true)
	authorization_only_receipt["applied"] = false
	var authorization_only_body := authorization_only_receipt.duplicate(true)
	authorization_only_body.erase("receipt_fingerprint")
	authorization_only_receipt["receipt_fingerprint"] = JSON.stringify(authorization_only_body).sha256_text()
	_expect(not DriverScript.blocked_realtime_wait_policy(pending_wager, current_wager, authorization_only_receipt, "running"), "authorization without domain application cannot grant acceleration")
	var wrong_viewer_receipt := applied_wager_receipt.duplicate(true)
	wrong_viewer_receipt["viewer_index"] = 1
	var wrong_viewer_body := wrong_viewer_receipt.duplicate(true)
	wrong_viewer_body.erase("receipt_fingerprint")
	wrong_viewer_receipt["receipt_fingerprint"] = JSON.stringify(wrong_viewer_body).sha256_text()
	_expect(not DriverScript.blocked_realtime_wait_policy(pending_wager, current_wager, wrong_viewer_receipt, "running"), "another viewer's receipt cannot grant acceleration")
	var stale_decision := current_wager.duplicate(true)
	stale_decision["decision_revision"] = 12
	_expect(not DriverScript.blocked_realtime_wait_policy(pending_wager, stale_decision, applied_wager_receipt, "running"), "a changed decision revision revokes the blocked-real-time lease")
	var replayed_receipt := applied_wager_receipt.duplicate(true)
	replayed_receipt["sequence"] = 4
	var replayed_body := replayed_receipt.duplicate(true)
	replayed_body.erase("receipt_fingerprint")
	replayed_receipt["receipt_fingerprint"] = JSON.stringify(replayed_body).sha256_text()
	_expect(not DriverScript.blocked_realtime_wait_policy(pending_wager, current_wager, replayed_receipt, "running"), "a receipt predating the submitted UI action cannot grant acceleration")

	var blocked_step := {
		"accepted": true,
		"attempted_steps": 1,
		"active_steps": 0,
		"world_seconds": 0.0,
		"last_path": "global_blocked",
		"blocked_realtime_steps": 1,
		"blocked_realtime_precondition_ended": false,
	}
	var world_checkpoint := {"world_effective_us": 40_000_000, "checkpoint_fingerprint": "w".repeat(64)}
	var rng_checkpoint := {"draw_count": 538, "checkpoint_fingerprint": "g".repeat(64)}
	_expect(bool(DriverScript.blocked_realtime_step_evidence(blocked_step, world_checkpoint, world_checkpoint, rng_checkpoint, rng_checkpoint).get("verified", false)), "a closed blocked-only receipt with stable clock and RNG is verified")
	var changed_world := world_checkpoint.duplicate(true)
	changed_world["world_effective_us"] = 40_000_001
	changed_world["checkpoint_fingerprint"] = "x".repeat(64)
	_expect(not bool(DriverScript.blocked_realtime_step_evidence(blocked_step, world_checkpoint, changed_world, rng_checkpoint, rng_checkpoint).get("verified", true)), "any blocked-only world-clock delta fails closed")
	var changed_rng := rng_checkpoint.duplicate(true)
	changed_rng["draw_count"] = 539
	changed_rng["checkpoint_fingerprint"] = "y".repeat(64)
	_expect(not bool(DriverScript.blocked_realtime_step_evidence(blocked_step, world_checkpoint, world_checkpoint, rng_checkpoint, changed_rng).get("verified", true)), "any blocked-only RNG delta fails closed")

	var timer_contract := _timer_contract(10.0, 120.0)
	var timer_trace := _timer_trace(timer_contract)
	var sale_observation := {
		"observed": true,
		"first_observation_sequence": 1,
		"first_world_effective_us": 0,
		"public_event_count": 4,
		"public_fingerprint": "d".repeat(64),
	}
	var timer_evidence := DriverScript.timer_traversal_evidence(
		timer_trace,
		sale_observation,
		timer_contract,
		"",
		false
	)
	_expect(bool(timer_evidence.get("verified", false)), "authorized duration fields plus one-second remaining-time trace prove the complete qualification and audit traversal")
	_expect(int(timer_evidence.get("qualification_authorized_duration_us", -1)) == 10_000_000 and int(timer_evidence.get("audit_authorized_duration_us", -1)) == 120_000_000 and int(timer_evidence.get("audit_countdown_world_delta_us", -1)) == 120_000_000, "timer evidence records authorized durations and matching world-clock deltas")
	var restarted_timer_trace := _timer_trace_after_qualification_reset(timer_contract)
	var restarted_timer_evidence := DriverScript.timer_traversal_evidence(
		restarted_timer_trace,
		sale_observation,
		timer_contract,
		"",
		false
	)
	_expect(
		bool(restarted_timer_evidence.get("verified", false)) \
			and int(restarted_timer_evidence.get("qualification_reset_count", 0)) == 1,
		"a rules-authorized qualification loss is recorded before the final complete timer traversal"
	)
	var illegal_regression_trace := timer_trace.duplicate(true)
	(illegal_regression_trace[11] as Dictionary)["state"] = "qualification"
	_expect(
		str(DriverScript.timer_traversal_evidence(
			illegal_regression_trace,
			sale_observation,
			timer_contract,
			"",
			false
		).get("reason_id", "")) == "timer_trace_state_regressed",
		"an audit-to-qualification regression remains invalid"
	)
	var post_resolved_trace := timer_trace.duplicate(true)
	post_resolved_trace.append(_timer_sample(
		post_resolved_trace.size() + 1,
		131_000_000,
		"idle",
		0,
		0,
		timer_contract
	))
	_expect(
		str(DriverScript.timer_traversal_evidence(
			post_resolved_trace,
			sale_observation,
			timer_contract,
			"",
			false
		).get("reason_id", "")) == "timer_trace_state_regressed",
		"a resolved terminal state cannot regress into a new attempt"
	)
	var no_sale_evidence := DriverScript.timer_traversal_evidence(timer_trace, {}, timer_contract, "", false)
	_expect(not bool(no_sale_evidence.get("verified", true)), "a terminal trace without a real SaleReceipt fails closed")
	var late_sale := sale_observation.duplicate(true)
	late_sale["first_observation_sequence"] = 3
	late_sale["first_world_effective_us"] = 2_000_000
	_expect(not bool(DriverScript.timer_traversal_evidence(timer_trace, late_sale, timer_contract, "", false).get("verified", true)), "a SaleReceipt first observed after qualification begins fails closed")
	var shortened_trace := timer_trace.duplicate(true)
	shortened_trace.remove_at(60)
	_expect(not bool(DriverScript.timer_traversal_evidence(shortened_trace, sale_observation, timer_contract, "", false).get("verified", true)), "a shortened timer trace cannot masquerade as configured timer traversal")
	_expect(not bool(DriverScript.timer_traversal_evidence(timer_trace, sale_observation, {}, "", false).get("verified", true)), "absent authorized timer durations fail closed")
	var invalid_timer_contract := timer_contract.duplicate(true)
	invalid_timer_contract["audit_duration_us"] = 0
	_expect(not bool(DriverScript.timer_traversal_evidence(timer_trace, sale_observation, invalid_timer_contract, "", false).get("verified", true)), "invalid authorized timer durations fail closed")
	_expect(not bool(DriverScript.timer_traversal_evidence(timer_trace, sale_observation, timer_contract, "timer_contract_changed_during_run", false).get("verified", true)), "a changing authorized timer contract fails closed")
	var public_outcome := _outcome("victory.v06.1")
	var authoritative_outcome := public_outcome.duplicate(true)
	var authoritative_rankings := (authoritative_outcome.get("rankings", []) as Array).duplicate(true)
	(authoritative_rankings[0] as Dictionary)["cash_ledger_cents"] = 48_900
	(authoritative_rankings[0] as Dictionary)["private_cash_carrier"] = {"ledger_revision": 11}
	authoritative_outcome["rankings"] = authoritative_rankings
	var public_rankings := (public_outcome.get("rankings", []) as Array).duplicate(true)
	(public_rankings[0] as Dictionary)["cash_visibility"] = "redacted"
	public_outcome["rankings"] = public_rankings
	var identity_evidence := DriverScript.outcome_identity_evidence(public_outcome, authoritative_outcome)
	_expect(bool(identity_evidence.get("verified", false)), "visibility-safe public and private authoritative outcome carriers share one normalized terminal identity")
	var different_session_outcome := public_outcome.duplicate(true)
	different_session_outcome["winner_player_indices"] = [1]
	_expect(not bool(DriverScript.outcome_identity_evidence(public_outcome, different_session_outcome).get("verified", true)), "same-ID Session and public receipts with different winner identity fail closed")
	var different_gdp_outcome := public_outcome.duplicate(true)
	var different_gdp_rankings := (different_gdp_outcome.get("rankings", []) as Array).duplicate(true)
	(different_gdp_rankings[0] as Dictionary)["top_k_gdp_per_minute_cents"] = 10_801
	different_gdp_outcome["rankings"] = different_gdp_rankings
	_expect(not bool(DriverScript.outcome_identity_evidence(public_outcome, different_gdp_outcome).get("verified", true)), "same-ID receipts with different ranked GDP fail closed")
	var different_control_outcome := public_outcome.duplicate(true)
	var different_control_rankings := (different_control_outcome.get("rankings", []) as Array).duplicate(true)
	(different_control_rankings[0] as Dictionary)["controlled_region_count"] = 4
	different_control_outcome["rankings"] = different_control_rankings
	_expect(not bool(DriverScript.outcome_identity_evidence(public_outcome, different_control_outcome).get("verified", true)), "same-ID receipts with different controlled-region rank facts fail closed")
	var different_order_outcome := public_outcome.duplicate(true)
	different_order_outcome["comparison_order"] = ["controlled_region_count", "top_k_gdp_per_minute_cents", "cash_ledger_cents"]
	_expect(not bool(DriverScript.outcome_identity_evidence(public_outcome, different_order_outcome).get("verified", true)), "same-ID receipts with a different comparison order fail closed")
	var different_checkpoint_outcome := public_outcome.duplicate(true)
	var different_checkpoint_evidence := (different_checkpoint_outcome.get("audit_evidence", {}) as Dictionary).duplicate(true)
	different_checkpoint_evidence["settlement_checkpoint"] = "forged_checkpoint"
	different_checkpoint_outcome["audit_evidence"] = different_checkpoint_evidence
	_expect(not bool(DriverScript.outcome_identity_evidence(public_outcome, different_checkpoint_outcome).get("verified", true)), "same-ID receipts with different settlement checkpoints fail closed")
	var different_roster_outcome := public_outcome.duplicate(true)
	var different_roster_evidence := (different_roster_outcome.get("audit_evidence", {}) as Dictionary).duplicate(true)
	different_roster_evidence["audit_roster"] = [1]
	different_roster_outcome["audit_evidence"] = different_roster_evidence
	_expect(not bool(DriverScript.outcome_identity_evidence(public_outcome, different_roster_outcome).get("verified", true)), "same-ID receipts with different audit rosters fail closed")
	var different_rule_outcome := public_outcome.duplicate(true)
	var different_rule_evidence := (different_rule_outcome.get("audit_evidence", {}) as Dictionary).duplicate(true)
	var different_rule := (different_rule_evidence.get("victory_rule", {}) as Dictionary).duplicate(true)
	different_rule["required_region_count"] = 4
	different_rule_evidence["victory_rule"] = different_rule
	different_rule_outcome["audit_evidence"] = different_rule_evidence
	_expect(not bool(DriverScript.outcome_identity_evidence(public_outcome, different_rule_outcome).get("verified", true)), "same-ID receipts with different public victory rules fail closed")
	var terminal_stable := {
		"session_state": "finished",
		"world_effective_us": 185000000,
		"public_world_fingerprint": "f".repeat(64),
		"victory_state": "resolved",
		"victory_visibility_scope": "public",
		"victory_settlement_checkpoint": "post_world_settlement",
		"victory_public_fingerprint": "a".repeat(64),
		"outcome_id": "victory.v06.1",
		"session_outcome_id": "victory.v06.1",
		"outcome_identity_matches": true,
		"public_outcome_identity_fingerprint": str(identity_evidence.get("public_fingerprint", "")),
		"session_outcome_identity_fingerprint": str(identity_evidence.get("session_fingerprint", "")),
		"outcome_reason_code": "public_audit_complete",
		"winner_count": 1,
		"peak_production_installation_count": 3,
		"post_victory_production_installation_delta": 0,
		"present_count": 1,
		"presented_outcome_count": 1,
		"logged_outcome_count": 1,
		"last_presented_outcome_id": "victory.v06.1",
		"settlement_snapshot_fingerprint": "b".repeat(64),
		"settlement_action_emission_count": 0,
		"final_public_log": {"public_entry_count": 1, "outcome_id": "victory.v06.1", "public_fingerprint": "c".repeat(64)},
		"sale_receipt": {"observed": true, "public_event_count": 4, "public_fingerprint": "d".repeat(64)},
		"timer_evidence": timer_evidence,
		"actions": {"attempted": 39, "progressed": 32, "rejected_invalid": 0},
		"rng": {"draw_count": 538, "checkpoint_fingerprint": "e".repeat(64)},
	}
	_expect(DriverScript._terminal_baseline_valid(terminal_stable), "a finished typed settlement with public log and RNG evidence is a valid terminal baseline")
	var incomplete_installation_slice := terminal_stable.duplicate(true)
	incomplete_installation_slice["peak_production_installation_count"] = 2
	_expect(not DriverScript._terminal_baseline_valid(incomplete_installation_slice), "terminal settlement cannot pass before the scripted player has owned three production installations")
	var post_victory_growth := terminal_stable.duplicate(true)
	post_victory_growth["post_victory_production_installation_delta"] = 1
	_expect(not DriverScript._terminal_baseline_valid(post_victory_growth), "terminal settlement rejects any scripted production installation after qualification begins")
	var missing_log := terminal_stable.duplicate(true)
	missing_log["final_public_log"] = {"public_entry_count": 0, "outcome_id": "", "public_fingerprint": ""}
	_expect(not DriverScript._terminal_baseline_valid(missing_log), "composition counters without a public final-settlement log cannot satisfy the terminal baseline")
	var duplicate_log := terminal_stable.duplicate(true)
	duplicate_log["final_public_log"] = {"public_entry_count": 2, "outcome_id": "", "public_fingerprint": "c".repeat(64)}
	_expect(not DriverScript._terminal_baseline_valid(duplicate_log), "duplicate outcome-bound FinalSettlement public logs fail exact-once settlement")
	var mismatched_session_outcome := terminal_stable.duplicate(true)
	mismatched_session_outcome["session_outcome_id"] = "victory.v06.2"
	mismatched_session_outcome["outcome_identity_matches"] = false
	_expect(not DriverScript._terminal_baseline_valid(mismatched_session_outcome), "a Session outcome that differs from the public Victory outcome fails closed")
	var missing_sale_terminal := terminal_stable.duplicate(true)
	missing_sale_terminal["sale_receipt"] = {"observed": false, "public_event_count": 0, "public_fingerprint": ""}
	_expect(not DriverScript._terminal_baseline_valid(missing_sale_terminal), "terminal presentation without a SaleReceipt cannot satisfy the vertical-slice oracle")
	var shortened_terminal := terminal_stable.duplicate(true)
	shortened_terminal["timer_evidence"] = DriverScript.timer_traversal_evidence(shortened_trace, sale_observation, timer_contract, "", false)
	_expect(not DriverScript._terminal_baseline_valid(shortened_terminal), "terminal presentation cannot hide a shortened qualification or audit trace")
	var rng_pair := {
		"terminal": {"draw_count": 538, "checkpoint_fingerprint": "e".repeat(64)},
		"terminal_quiescent": {"draw_count": 538, "checkpoint_fingerprint": "e".repeat(64)},
	}
	_expect(bool(DriverScript.rng_quiescence_evidence(rng_pair).get("verified", false)), "within-run terminal quiescence preserves RNG draw count and state fingerprint")
	(rng_pair["terminal_quiescent"] as Dictionary)["draw_count"] = 539
	_expect(not bool(DriverScript.rng_quiescence_evidence(rng_pair).get("verified", true)), "any terminal-to-quiescent RNG draw delta fails closed")
	var finished_frame := {
		"frame_index": 101,
		"path": "finished",
		"stopped_reason": "session_finished",
		"world_delta": 0.0,
		"phase_trace": ["lifecycle_begin"],
	}
	_expect(DriverScript._terminal_finished_frame_valid(finished_frame, 101), "a finished RuntimeLoop frame advances its lease once and performs no world phases")
	var mutated_frame := finished_frame.duplicate(true)
	mutated_frame["world_delta"] = 0.001
	_expect(not DriverScript._terminal_finished_frame_valid(mutated_frame, 101), "any terminal world-time advance fails quiescence")
	_expect(not DriverScript._terminal_finished_frame_valid(finished_frame, 102), "a skipped or duplicated terminal RuntimeLoop frame fails the frame-index lease")

	for token in FORBIDDEN_DRIVER_TOKENS:
		_expect(not driver_source.contains(token), "driver excludes forbidden runtime shortcut: %s" % token)
	_expect(driver_source.count("\tprint(") == 1 and driver_source.contains("print(JSON.stringify(payload))"), "all driver console output uses one NDJSON emitter")

	var sample := SnapshotScript.compose({
		"seed": EXPECTED_SEEDS[0],
		"phase": "decision_window.counter_response",
		"elapsed": {"wall_seconds": 2.5, "world_seconds": 10.0},
		"sale_receipt": {"observed": true, "public_event_count": 1, "first_world_seconds": 9.0, "latest_source_revision": 7, "public_fingerprint": "a".repeat(64)},
		"decision_window": {
			"active": true,
			"kind": "counter_response",
			"priority_group": "counter_response",
			"blocks_global_time": true,
			"blocks_player_actions": true,
			"visible_to_scripted_player": true,
		},
		"settlement": {
			"state": "audit",
			"completed": false,
			"outcome_id": "",
			"reason_code": "",
			"winner_count": 0,
			"presentation_ready": false,
			"present_count": 0,
			"presented_outcome_count": 0,
			"logged_outcome_count": 0,
			"last_presented_outcome_id": "",
			"public_snapshot_fingerprint": "",
		},
		"invalid_actions": {"count": 1, "last_reason_code": "ui_action_no_progress"},
		"last_event": "action_requested:counter_pass",
		"observed_public_facts": {"clock": 10.0, "probe": INF},
	})
	_expect(bool(sample.get("valid", false)) and int(sample.get("seed", 0)) == EXPECTED_SEEDS[0], "telemetry accepts aggregate public facts and preserves the fixed seed")
	_expect(_contains_all(sample, REQUIRED_TELEMETRY_KEYS), "telemetry exposes seed, phase, elapsed, decision, settlement, invalid-action, nonfinite, and last-event fields")
	_expect(str(sample.get("phase", "")) == "decision_window.counter_response", "telemetry keeps the exact public decision phase")
	_expect(int((sample.get("invalid_actions", {}) as Dictionary).get("count", 0)) == 1, "telemetry preserves the aggregate invalid-action count")
	_expect(int((sample.get("nonfinite", {}) as Dictionary).get("count", 0)) == 1 and (sample.get("nonfinite", {}) as Dictionary).get("paths", []) == ["public.probe"], "telemetry detects a non-finite public runtime fact without serializing its value")
	_expect(not _contains_forbidden_key(sample), "composed telemetry contains no player cash, hand, owner truth, or AI-private key")

	var rejected := SnapshotScript.compose({
		"seed": EXPECTED_SEEDS[0],
		"phase": "play",
		"hand": ["PRIVATE_CARD_SENTINEL"],
	})
	_expect(not bool(rejected.get("valid", true)) and str((rejected.get("invalid_actions", {}) as Dictionary).get("last_reason_code", "")) == "telemetry_input_not_public", "telemetry fails closed before a private hand can enter the public output")
	_expect(not JSON.stringify(rejected).contains("PRIVATE_CARD_SENTINEL"), "fail-closed telemetry never echoes a private value")

	var contract: Dictionary = DriverScript.public_output_contract()
	var telemetry_contract: Dictionary = contract.get("telemetry", {}) if contract.get("telemetry", {}) is Dictionary else {}
	_expect(_same_members(telemetry_contract.get("public_keys", []) as Array, SnapshotScript.PUBLIC_KEYS), "driver publishes the exact telemetry schema")
	_expect(_same_members(contract.get("capability_keys", []) as Array, DriverScript.CAPABILITY_PUBLIC_KEYS), "capability output is explicit and aggregate-only")
	_expect(_public_contract_is_safe(contract), "driver and telemetry contracts exclude private runtime fields")

	var qa_scope := DriverScript.qa_save_directory("abc123", EXPECTED_SEEDS[0])
	_expect(qa_scope == "user://test_runs/full_run_quality/abc123/%d/" % EXPECTED_SEEDS[0], "QA save scope is isolated by head and seed")
	_finish()


func _timer_contract(qualification_seconds: float, audit_seconds: float) -> Dictionary:
	return {
		"schema_version": 1,
		"visibility_scope": "viewer_private",
		"viewer_index": 0,
		"qualification_duration_us": int(round(qualification_seconds * 1_000_000.0)),
		"audit_duration_us": int(round(audit_seconds * 1_000_000.0)),
	}


func _timer_trace(timer_contract: Dictionary) -> Array[Dictionary]:
	var qualification_duration_us := int(timer_contract.get("qualification_duration_us", 0))
	var audit_duration_us := int(timer_contract.get("audit_duration_us", 0))
	var qualification_seconds := int(qualification_duration_us / 1_000_000)
	var audit_seconds := int(audit_duration_us / 1_000_000)
	var trace: Array[Dictionary] = []
	trace.append(_timer_sample(trace.size() + 1, 0, "idle", 0, 0, timer_contract))
	for elapsed_seconds in range(1, qualification_seconds):
		trace.append(_timer_sample(
			trace.size() + 1,
			elapsed_seconds * 1_000_000,
			"qualification",
			qualification_duration_us - elapsed_seconds * 1_000_000,
			0,
			timer_contract
		))
	trace.append(_timer_sample(
		trace.size() + 1,
		qualification_duration_us,
		"audit",
		0,
		audit_duration_us,
		timer_contract
	))
	for elapsed_seconds in range(1, audit_seconds):
		trace.append(_timer_sample(
			trace.size() + 1,
			qualification_duration_us + elapsed_seconds * 1_000_000,
			"audit",
			0,
			audit_duration_us - elapsed_seconds * 1_000_000,
			timer_contract
		))
	trace.append(_timer_sample(
		trace.size() + 1,
		qualification_duration_us + audit_duration_us,
		"resolved",
		0,
		0,
		timer_contract
	))
	return trace


func _timer_trace_after_qualification_reset(timer_contract: Dictionary) -> Array[Dictionary]:
	var qualification_duration_us := int(timer_contract.get("qualification_duration_us", 0))
	var trace: Array[Dictionary] = [
		_timer_sample(1, 0, "idle", 0, 0, timer_contract),
		_timer_sample(2, 1_000_000, "qualification", qualification_duration_us - 1_000_000, 0, timer_contract),
		_timer_sample(3, 2_000_000, "qualification", qualification_duration_us - 2_000_000, 0, timer_contract),
		_timer_sample(4, 3_000_000, "idle", 0, 0, timer_contract),
	]
	var successful_trace := _timer_trace(timer_contract)
	for index in range(1, successful_trace.size()):
		var sample := (successful_trace[index] as Dictionary).duplicate(true)
		sample["observation_sequence"] = trace.size() + 1
		sample["world_effective_us"] = int(sample.get("world_effective_us", 0)) + 3_000_000
		trace.append(sample)
	return trace


func _timer_sample(
	sequence: int,
	world_effective_us: int,
	state: String,
	qualification_remaining_us: int,
	audit_remaining_us: int,
	timer_contract: Dictionary
) -> Dictionary:
	return {
		"observation_sequence": sequence,
		"world_effective_us": world_effective_us,
		"state": state,
		"qualification_remaining_us": qualification_remaining_us,
		"audit_remaining_us": audit_remaining_us,
		"qualification_duration_us": int(timer_contract.get("qualification_duration_us", -1)),
		"audit_duration_us": int(timer_contract.get("audit_duration_us", -1)),
	}


func _outcome(outcome_id: String) -> Dictionary:
	return {
		"outcome_id": outcome_id,
		"schema_version": 2,
		"ruleset_id": "v0.6",
		"reason_code": "public_audit_complete",
		"winner_player_indices": [0],
		"co_victory": false,
		"comparison_order": ["top_k_gdp_per_minute_cents", "controlled_region_count", "cash_ledger_cents"],
		"rankings": [{
			"player_index": 0,
			"top_k_gdp_per_minute_cents": 10_800,
			"top_k_gdp_per_minute": 108,
			"controlled_region_count": 3,
			"winner": true,
		}],
		"audit_evidence": {
			"victory_rule": {
				"surviving_region_count": 6,
				"coverage_basis_points": 4000,
				"required_region_count": 3,
				"gdp_per_required_region_per_minute": 36,
				"required_top_k_gdp_per_minute": 108,
				"required_top_k_gdp_per_minute_cents": 10_800,
				"ordinary_victory_paused": false,
			},
			"audit_roster": [0],
			"settlement_checkpoint": "post_world_settlement",
		},
	}


func _contains_all(source: Dictionary, keys: Array) -> bool:
	for key_variant in keys:
		if not source.has(str(key_variant)):
			return false
	return true


func _contains_forbidden_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if FORBIDDEN_PUBLIC_KEYS.has(str(key_variant).to_lower()):
				return true
			if _contains_forbidden_key((value as Dictionary).get(key_variant)):
				return true
		return false
	if value is Array:
		for item_variant in value as Array:
			if _contains_forbidden_key(item_variant):
				return true
	return false


func _public_contract_is_safe(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant).to_lower()
			if FORBIDDEN_PUBLIC_KEYS.has(key):
				return false
			if not _public_contract_is_safe((value as Dictionary).get(key_variant)):
				return false
		return true
	if value is Array:
		for item_variant in value as Array:
			if str(item_variant).to_lower() in FORBIDDEN_PUBLIC_KEYS:
				return false
			if not _public_contract_is_safe(item_variant):
				return false
	return true


func _same_members(left: Array, right: Array) -> bool:
	if left.size() != right.size():
		return false
	for value in left:
		if not right.has(value):
			return false
	return true


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("FULL_RUN_QUALITY_DRIVER_CONTRACT|status=PASS|checks=%d|failures=0|single_run=true" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("FULL_RUN_QUALITY_DRIVER_CONTRACT: %s" % failure)
	print("FULL_RUN_QUALITY_DRIVER_CONTRACT|status=FAIL|checks=%d|failures=%d" % [_checks, _failures.size()])
	quit(1)
