extends SceneTree

## Phase 8 focused gate for the canonical commercial-presentation fixture.
##
## FIXTURE_CLASS=PRESENTATION_FIXTURE
## NATURAL_GAMEPLAY=false
## HUMAN_GREEN=false
##
## The gate instances the one canonical Showcase, which in turn instances the
## real production main scene and consumes its unique Animation Director. It
## never starts a match, advances Tick, draws rules RNG, or authors gameplay.

const PresentationReceiptIdentity := preload(
	"res://scripts/v075/presentation/v075_presentation_receipt_identity_v2.gd"
)

const SHOWCASE_SCENE_PATH := (
	"res://scenes/tools/CommercialPresentationShowcase.tscn"
)
const EPISODE_PLAN_PATH := (
	"res://data/presentation/v076_commercial_showcase_episode_plan.json"
)
const PRODUCTION_MAIN_SCENE_PATH := "res://scenes/main.tscn"
const FIXTURE_CLASS := "PRESENTATION_FIXTURE"
const FIXTURE_BANNER_TEXT := (
	"PRESENTATION_FIXTURE — NOT NATURAL GAMEPLAY / NOT HUMAN GREEN"
)
const CARD_TABLE_FIXTURE_RECEIPT_KIND_BY_CUE := {
	"CARD_SELECT": "card_selection_receipt",
	"CARD_PLAY_PUBLIC": "public_card_play_receipt",
	"CARD_RESOLUTION_FOCUS": "public_resolution_receipt",
	"FINAL_SETTLEMENT": "final_settlement_receipt",
}
const EXPECTED_EPISODE_IDS := [
	"main_menu",
	"loading",
	"acquire_to_deck",
	"shuffle",
	"draw",
	"hand_hover",
	"public_play",
	"public_resolution",
	"facility",
	"monster",
	"military",
	"track_handoff",
	"final_settlement",
]
const FRAME_PHASES := ["start", "mid", "end"]
const EXPECTED_AUTHORITY_COMPONENT_IDS := [
	"V075RulesetRuntimeOwner",
	"V075RuntimeOwner",
	"V075CombatRuntimeOwner",
	"V076DeterministicKernel",
	"V076PrivateDirectActionInputOwnerV1",
	"V076MilitaryPhysicalEtaOwnerV1",
	"V076V075ProductionAdapterV1",
]
const ZERO_MUTATION_KEYS := [
	"animation_gameplay_mutation_count",
	"animation_rng_draw_delta",
	"animation_authority_sequence_delta",
	"animation_deck_order_mutation_count",
	"animation_card_zone_mutation_count",
	"animation_facility_state_mutation_count",
]

var _checks := 0
var _failures: Array[String] = []
var _episode_pass_count := 0
var _frame_evidence_count := 0
var _duplicate_suppression_count := 0
var _finish_once_count := 0
var _original_root_size := Vector2i.ZERO
var _original_content_scale_size := Vector2i.ZERO


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_original_root_size = root.size
	_original_content_scale_size = root.content_scale_size
	root.content_scale_size = Vector2i(1600, 960)
	root.size = Vector2i(1600, 960)

	var plan := _read_json_dictionary(EPISODE_PLAN_PATH)
	_audit_plan(plan)
	_expect(
		ResourceLoader.exists(SHOWCASE_SCENE_PATH),
		"canonical CommercialPresentationShowcase scene exists"
	)
	var packed := load(SHOWCASE_SCENE_PATH) as PackedScene
	_expect(packed != null, "canonical CommercialPresentationShowcase scene loads")
	if packed == null:
		_finish()
		return

	var showcase := packed.instantiate() as Control
	_expect(showcase != null, "canonical CommercialPresentationShowcase instantiates")
	if showcase == null:
		_finish()
		return
	root.add_child(showcase)
	await _frames(16)

	var contract_variant: Variant = showcase.call("get_showcase_contract")
	var contract: Dictionary = (
		contract_variant as Dictionary
		if contract_variant is Dictionary
		else {}
	)
	_audit_production_composition(showcase, contract)
	_audit_fail_closed_guards(showcase)

	var plan_rows: Array = (
		plan.get("episodes", []) as Array
		if plan.get("episodes", []) is Array
		else []
	)
	if plan_rows.size() == EXPECTED_EPISODE_IDS.size():
		for row_variant: Variant in plan_rows:
			if not (row_variant is Dictionary):
				continue
			await _audit_episode(showcase, row_variant as Dictionary)

	root.remove_child(showcase)
	showcase.queue_free()
	await _frames(6)
	root.content_scale_size = _original_content_scale_size
	root.size = _original_root_size
	_finish()


func _audit_plan(plan: Dictionary) -> void:
	_expect(not plan.is_empty(), "commercial Showcase episode plan parses")
	_expect(
		str(plan.get("contract_id", ""))
			== "space_syndicate.v076.commercial_showcase_episode_plan.v1",
		"episode plan uses the Phase 8 contract"
	)
	_expect(
		str(plan.get("fixture_class", "")) == FIXTURE_CLASS
			and not bool(plan.get("natural_gameplay", true))
			and not bool(plan.get("human_green", true)),
		"episode plan is explicitly fixture-only and not Human Green"
	)
	_expect(
		str(plan.get("canonical_scene_path", "")) == SHOWCASE_SCENE_PATH
			and str(plan.get("production_main_scene_path", ""))
				== PRODUCTION_MAIN_SCENE_PATH,
		"episode plan binds the canonical Showcase to production main.tscn"
	)
	var phases: Array = (
		plan.get("frame_phases", []) as Array
		if plan.get("frame_phases", []) is Array
		else []
	)
	_expect(phases == FRAME_PHASES, "episode plan fixes start/mid/end frame order")
	_expect(
		int(plan.get("episode_count", 0)) == EXPECTED_EPISODE_IDS.size()
			and int(plan.get("frame_count", 0))
				== EXPECTED_EPISODE_IDS.size() * FRAME_PHASES.size(),
		"episode plan declares 13 episodes and 39 frames"
	)

	var rows: Array = (
		plan.get("episodes", []) as Array
		if plan.get("episodes", []) is Array
		else []
	)
	_expect(rows.size() == EXPECTED_EPISODE_IDS.size(), "episode plan has 13 rows")
	var observed_ids: Array[String] = []
	var observed_directories: Dictionary = {}
	for index in range(rows.size()):
		var row_variant: Variant = rows[index]
		_expect(row_variant is Dictionary, "episode plan row %d is typed" % index)
		if not (row_variant is Dictionary):
			continue
		var row := row_variant as Dictionary
		var episode_id := str(row.get("episode_id", ""))
		var capture_directory := str(row.get("capture_directory", ""))
		observed_ids.append(episode_id)
		_expect(
			int(row.get("ordinal", 0)) == index + 1,
			"episode %s keeps its stable ordinal" % episode_id
		)
		_expect(
			not capture_directory.is_empty()
				and not observed_directories.has(capture_directory),
			"episode %s has one unique capture directory" % episode_id
		)
		observed_directories[capture_directory] = true
		_expect(
			not str(row.get("receipt_kind", "")).is_empty()
				and not str(row.get("expected_cue_id", "")).is_empty(),
			"episode %s declares Receipt and Cue evidence" % episode_id
		)
		_expect(
			not str(row.get("source_anchor_path", "")).is_empty()
				and not str(row.get("target_anchor_path", "")).is_empty()
				and str(row.get("source_anchor_path", "")).ends_with(
					str(row.get("source_node", ""))
				)
				and str(row.get("target_anchor_path", "")).ends_with(
					str(row.get("target_node", ""))
				),
			"episode %s declares exact terminal-matching NodePaths" % episode_id
		)
		var director_applicable := bool(row.get("director_applicable", false))
		if episode_id in ["main_menu", "loading"]:
			_expect(
				not director_applicable
					and row.get("director_cue_id", null) == null
					and str(row.get("exact_once_mode", ""))
						== "SHOWCASE_EPISODE_APPLICATION",
				"%s is an explicit Director-N/A product-shell transition"
					% episode_id
			)
		else:
			_expect(
				director_applicable
					and str(row.get("director_cue_id", ""))
						== str(row.get("expected_cue_id", ""))
					and str(row.get("exact_once_mode", ""))
						== "DIRECTOR_RECEIPT",
				"episode %s has an exact Director Cue binding" % episode_id
			)
	_expect(observed_ids == EXPECTED_EPISODE_IDS, "episode plan order is canonical")


func _audit_production_composition(
	showcase: Control,
	contract: Dictionary
) -> void:
	_expect(
		str(contract.get("schema", ""))
			== "V076CommercialPresentationShowcaseFixtureV1",
		"Showcase exposes the Phase 8 fixture contract"
	)
	_expect(
		str(contract.get("canonical_scene_path", "")) == SHOWCASE_SCENE_PATH
			and str(contract.get("production_main_scene_path", ""))
				== PRODUCTION_MAIN_SCENE_PATH,
		"Showcase contract names canonical scene and production main"
	)
	_expect(
		str(contract.get("fixture_class", "")) == FIXTURE_CLASS
			and not bool(contract.get("natural_gameplay", true))
			and not bool(contract.get("human_green", true))
			and not bool(contract.get("production_green", true)),
		"Showcase never claims natural gameplay, Human Green, or Production Green"
	)
	var episode_ids: Array = (
		contract.get("episode_ids", []) as Array
		if contract.get("episode_ids", []) is Array
		else []
	)
	var frame_phases: Array = (
		contract.get("frame_phases", []) as Array
		if contract.get("frame_phases", []) is Array
		else []
	)
	_expect(episode_ids == EXPECTED_EPISODE_IDS, "Showcase exposes all 13 canonical episodes")
	_expect(
		int(contract.get("episode_count", 0)) == EXPECTED_EPISODE_IDS.size()
			and frame_phases == FRAME_PHASES
			and int(contract.get("frame_count", 0)) == 39,
		"Showcase exposes exactly 13 x 3 deterministic frames"
	)

	var production_main := showcase.get_node_or_null("ProductionMain") as Control
	var screen := (
		production_main.get_node_or_null("V075GameScreen") as Control
		if production_main != null
		else null
	)
	var runtime := (
		production_main.get_node_or_null("V075RuntimeComposition")
		if production_main != null
		else null
	)
	var menu_lifecycle := (
		production_main.get_node_or_null(
			"CommercialMenuLifecycleApplicationFlowController"
		)
		if production_main != null
		else null
	)
	var loading_overlay := (
		production_main.get_node_or_null("V075NewGameLoadingOverlay")
		if production_main != null
		else null
	)
	var director := showcase.find_child(
		"V076PresentationAnimationDirector", true, false
	)
	_expect(
		production_main != null
			and screen != null
			and runtime != null
			and menu_lifecycle != null
			and loading_overlay != null,
		"Showcase instances the real production main composition"
	)
	_expect(
		bool(contract.get("uses_production_main", false))
			and int(contract.get("presentation_director_instance_count", 0)) == 1
			and _count_named_recursive(
				showcase, "V076PresentationAnimationDirector"
			) == 1,
		"Showcase composes exactly one production Animation Director"
	)
	_expect(
		director != null
			and screen != null
			and screen.is_ancestor_of(director)
			and bool(contract.get("uses_production_director", false)),
		"the unique Director belongs to the real production GameScreen"
	)
	_expect(
		int(contract.get("showcase_gameplay_owner_count", -1)) == 0
			and int(contract.get("showcase_rng_owner_count", -1)) == 0
			and int(contract.get("showcase_tick_owner_count", -1)) == 0
			and int(contract.get("showcase_card_zone_owner_count", -1)) == 0
			and int(contract.get("showcase_facility_owner_count", -1)) == 0
			and int(contract.get("showcase_settlement_owner_count", -1)) == 0,
		"Showcase owns no gameplay, RNG, Tick, card-zone, facility, or settlement authority"
	)
	_expect(
		(contract.get("card_table_fixture_cue_ids", []) as Array)
			== CARD_TABLE_FIXTURE_RECEIPT_KIND_BY_CUE.keys()
			and str(contract.get("card_table_fixture_bridge_method", ""))
				== "V075GameScreen.enqueue_card_table_presentation"
			and str(contract.get("showcase_fixture_consumer_method", ""))
				== "V075GameScreen.enqueue_commercial_showcase_presentation_fixture"
			and str(contract.get("final_settlement_fixture_surface_method", ""))
				== "V075GameScreen.present_final_settlement_fixture",
		"card-table fixture cues use the unique Screen bridge and dedicated settlement surface"
	)
	var showcase_owner_audit := contract.get(
		"showcase_authority_owner_audit", {}
	) as Dictionary
	var production_owner_audit := contract.get(
		"production_authority_owner_audit", {}
	) as Dictionary
	_expect(
		(showcase_owner_audit.get("instances_by_script", {}) as Dictionary).is_empty()
			and int(showcase_owner_audit.get(
				"duplicate_authority_owner_count", -1
			)) == 0,
		"Showcase owner audit is measured from its non-production subtree"
	)
	_expect(
		int(production_owner_audit.get("gameplay", -1)) == 5
			and int(production_owner_audit.get("rng", -1)) == 2
			and int(production_owner_audit.get("tick", -1)) == 2
			and int(production_owner_audit.get("card_zone", -1)) == 1
			and int(production_owner_audit.get("facility", -1)) == 1
			and int(production_owner_audit.get("settlement", -1)) == 1
			and int(production_owner_audit.get(
				"duplicate_authority_owner_count", -1
			)) == 0,
		"production subtree contains the exact inherited authority owners once"
	)

	var banner := showcase.find_child("FixtureBanner", true, false) as Label
	_expect(
		banner != null
			and banner.text == FIXTURE_BANNER_TEXT
			and banner.visible
			and banner.is_visible_in_tree()
			and bool(contract.get("fixture_banner_visible", false)),
		"fixture banner is permanent, exact, and visible"
	)
	var settlement_fixture := showcase.call(
		"_fixture_settlement_projection"
	) as Dictionary
	var fixture_standings := settlement_fixture.get("standings", []) as Array
	var fixture_player_ids: Array[String] = []
	for standing_variant in fixture_standings:
		if standing_variant is Dictionary:
			fixture_player_ids.append(str((standing_variant as Dictionary).get(
				"player_id",
				""
			)))
	_expect(
		str(settlement_fixture.get("winner_player_id", "")) == "player.local"
			and fixture_standings.size() == 4
			and fixture_player_ids == [
				"player.local",
				"player.ai.01",
				"player.ai.02",
				"player.ai.03",
			],
		"FinalSettlement fixture matches the production four-seat identity shape"
	)


func _audit_fail_closed_guards(showcase: Control) -> void:
	var detached_root := Node.new()
	var duplicate_runtime := Node.new()
	duplicate_runtime.set_script(load(
		"res://scripts/v075_runtime/v075_runtime_owner.gd"
	))
	detached_root.add_child(duplicate_runtime)
	var duplicate_audit := showcase.call(
		"_authority_owner_audit", detached_root, null
	) as Dictionary
	_expect(
		int(duplicate_audit.get("gameplay", 0)) == 1
			and int(duplicate_audit.get("rng", 0)) == 1
			and int(duplicate_audit.get("tick", 0)) == 1
			and int(duplicate_audit.get("card_zone", 0)) == 1
			and int(duplicate_audit.get("facility", 0)) == 1
			and int(duplicate_audit.get("settlement", 0)) == 1,
		"owner audit dynamically detects an injected Runtime authority script"
	)
	detached_root.free()

	var anchor_path := (
		"ProductionMain/V075GameScreen/RootMargin/Shell/Header/"
		+ "HeaderMargin/HeaderRows/HeaderPrimaryRow/CommercialMenuButton"
	)
	var anchor := showcase.get_node_or_null(anchor_path)
	var director_before := showcase.call("animation_debug_snapshot") as Dictionary
	_expect(anchor != null, "negative anchor probe resolves its exact target")
	if anchor != null:
		anchor.name = "CommercialMenuButtonPhase8NegativeProbe"
		_expect(
			not bool(showcase.call("prepare_episode", "main_menu")),
			"renamed exact anchor fails closed before presentation enqueue"
		)
		anchor.name = "CommercialMenuButton"
	var director_after := showcase.call("animation_debug_snapshot") as Dictionary
	_expect(
		int(director_after.get("queued_cue_count", -1))
			== int(director_before.get("queued_cue_count", -2)),
		"anchor rejection leaves the unique Director queue unchanged"
	)
	var restored_prepared := bool(showcase.call("prepare_episode", "main_menu"))
	if not restored_prepared:
		print("V076_SHOWCASE_RESTORED_PREPARE_DIAGNOSTIC|%s" % JSON.stringify(
			showcase.call("get_episode_evidence") as Dictionary
		))
	_expect(
		restored_prepared,
		"restored exact anchor prepares normally after the negative probe"
	)


func _audit_episode(showcase: Control, row: Dictionary) -> void:
	var episode_id := str(row.get("episode_id", ""))
	var expected_cue_id := str(row.get("expected_cue_id", ""))
	var director_applicable := bool(row.get("director_applicable", false))
	var active_variant: Variant = showcase.call("get_episode_evidence")
	var active: Dictionary = (
		active_variant as Dictionary
		if active_variant is Dictionary
		else {}
	)
	var already_prepared := str(active.get("episode_id", "")) == episode_id
	_expect(
		already_prepared or bool(showcase.call("prepare_episode", episode_id)),
		"episode %s prepares through the canonical fixture" % episode_id
	)

	var evidence_by_phase: Dictionary = {}
	for phase_variant: Variant in FRAME_PHASES:
		var phase := str(phase_variant)
		_expect(
			bool(showcase.call("set_episode_frame", episode_id, phase)),
			"episode %s exposes %s frame" % [episode_id, phase]
		)
		await _frames(2)
		var evidence_variant: Variant = showcase.call("get_episode_evidence")
		var evidence: Dictionary = (
			evidence_variant as Dictionary
			if evidence_variant is Dictionary
			else {}
		)
		evidence_by_phase[phase] = evidence.duplicate(true)
		_frame_evidence_count += 1
		_audit_frame_evidence(
			showcase,
			row,
			phase,
			evidence,
			expected_cue_id,
			director_applicable
		)

	var start := evidence_by_phase.get("start", {}) as Dictionary
	var mid := evidence_by_phase.get("mid", {}) as Dictionary
	var end := evidence_by_phase.get("end", {}) as Dictionary
	var start_rect := _rect_from_data(start.get("current_rect", {}))
	var mid_rect := _rect_from_data(mid.get("current_rect", {}))
	var end_rect := _rect_from_data(end.get("current_rect", {}))
	var target_rect := _rect_from_data(end.get("target_rect", {}))
	_expect(
		start_rect.has_area()
			and mid_rect.has_area()
			and end_rect.has_area()
			and target_rect.has_area(),
		"episode %s records complete start/mid/end/target Rect evidence"
			% episode_id
	)
	_expect(
		not _rect_close(start_rect, mid_rect)
			and not _rect_close(mid_rect, end_rect),
		"episode %s has a material three-frame Rect sequence" % episode_id
	)
	_expect(
		_rect_close(end_rect, target_rect)
			and bool(end.get("final_rect_matches_target", false)),
		"episode %s final Rect preserves target Projection parity" % episode_id
	)
	_expect(
		str((start.get("receipt", {}) as Dictionary).get(
			"receipt_fingerprint", ""
		)) == str((mid.get("receipt", {}) as Dictionary).get(
			"receipt_fingerprint", ""
		))
			and str((mid.get("receipt", {}) as Dictionary).get(
				"receipt_fingerprint", ""
			)) == str((end.get("receipt", {}) as Dictionary).get(
				"receipt_fingerprint", ""
			)),
		"episode %s keeps one immutable Receipt across all frames" % episode_id
	)

	var replay_variant: Variant = showcase.call("replay_active_receipt")
	var replay: Dictionary = (
		replay_variant as Dictionary
		if replay_variant is Dictionary
		else {}
	)
	_expect(
		bool(replay.get("suppressed", false))
			and int(replay.get("queued_count_before", -1))
				== int(replay.get("queued_count_after", -2)),
		"episode %s suppresses an exact replay without another queue" % episode_id
	)
	if director_applicable:
		var expected_replay_reason := (
			"card_table_presentation_duplicate_suppressed"
			if CARD_TABLE_FIXTURE_RECEIPT_KIND_BY_CUE.has(expected_cue_id)
			else "animation_receipt_duplicate_suppressed"
		)
		_expect(
			str(replay.get("reason_code", "")) == expected_replay_reason,
			"episode %s uses the canonical exact-once duplicate suppression route"
				% episode_id
		)
	else:
		_expect(
			str(replay.get("reason_code", ""))
				== "fixture_surface_receipt_duplicate_suppressed",
			"episode %s uses explicit Director-N/A surface exact-once"
				% episode_id
		)
	_duplicate_suppression_count += 1

	_expect(
		bool(showcase.call("finish_episode")),
		"episode %s finishes its one presentation Receipt" % episode_id
	)
	_expect(
		not bool(showcase.call("finish_episode")),
		"episode %s rejects a second finish" % episode_id
	)
	await _frames(1)
	var terminal_variant: Variant = showcase.call("get_episode_evidence")
	var terminal: Dictionary = (
		terminal_variant as Dictionary
		if terminal_variant is Dictionary
		else {}
	)
	_expect(
		int(terminal.get("enqueue_count", 0)) == 1
			and int(terminal.get("finish_count", 0)) == 1,
		"episode %s queues and finishes exactly once" % episode_id
	)
	var director_debug_variant: Variant = showcase.call(
		"animation_debug_snapshot"
	)
	var director_debug: Dictionary = (
		director_debug_variant as Dictionary
		if director_debug_variant is Dictionary
		else {}
	)
	_expect(
		int(director_debug.get("queued_cue_count", -1)) == 0,
		"episode %s leaves the production Director queue drained" % episode_id
	)
	_expect(
		int(director_debug.get("receipt_collision_count", -1)) == 0
			and int(director_debug.get("receipt_rejection_count", -1)) == 0,
		"episode %s has no Director collision or rejection" % episode_id
	)
	if CARD_TABLE_FIXTURE_RECEIPT_KIND_BY_CUE.has(expected_cue_id):
		var bridge_terminal := terminal.get("card_table_fixture_bridge", {}) as Dictionary
		var bridge_counts := bridge_terminal.get("cue_counts", {}) as Dictionary
		var bridge_row := bridge_counts.get(expected_cue_id, {}) as Dictionary
		var bridge_evidence := (bridge_terminal.get(
			"cue_evidence",
			{}
		) as Dictionary).get(expected_cue_id, {}) as Dictionary
		_expect(
			int(bridge_row.get("fixture_surface_finished_count", 0)) == 1
				and int(bridge_row.get("fixture_finished_count", 0)) == 1
				and int(bridge_row.get("production_finished_count", 0)) == 0
				and str(bridge_evidence.get("status", "")) == "FINISHED"
				and int(bridge_terminal.get("active_receipt_count", -1)) == 0,
			"episode %s finishes its Screen fixture surface exactly once"
				% episode_id
		)
	_expect(
		bool(terminal.get("authority_projection_consistent", false))
			and _zero_mutation(terminal),
		"episode %s finishes with unchanged authority and zero mutation"
			% episode_id
	)
	if episode_id == "loading":
		var loading_terminal := (terminal.get(
			"surface_state", {}
		) as Dictionary).get("loading_debug", {}) as Dictionary
		_expect(
			not bool(loading_terminal.get(
				"presentation_fixture_active", true
			))
				and int(loading_terminal.get("presentation_fixture_begin_count", 0)) == 1
				and int(loading_terminal.get("presentation_fixture_end_count", 0)) == 1
				and int(loading_terminal.get("begin_count", -1)) == 0
				and int(loading_terminal.get("failure_count", -1)) == 0,
			"loading fixture lifecycle balances once without a production failure"
		)
	_finish_once_count += 1
	_episode_pass_count += 1


func _audit_frame_evidence(
	showcase: Control,
	row: Dictionary,
	phase: String,
	evidence: Dictionary,
	expected_cue_id: String,
	director_applicable: bool
) -> void:
	var episode_id := str(row.get("episode_id", ""))
	_expect(not evidence.is_empty(), "%s/%s evidence is present" % [episode_id, phase])
	_expect(
		str(evidence.get("schema", ""))
			== "V076CommercialPresentationEpisodeEvidenceV1"
			and str(evidence.get("episode_id", "")) == episode_id
			and str(evidence.get("frame_phase", "")) == phase,
		"%s/%s evidence identity is exact" % [episode_id, phase]
	)
	_expect(
		str(evidence.get("fixture_class", "")) == FIXTURE_CLASS
			and not bool(evidence.get("natural_gameplay", true))
			and not bool(evidence.get("human_green", true))
			and not bool(evidence.get("production_green", true)),
		"%s/%s remains fixture-only and non-green" % [episode_id, phase]
	)
	var surface_state := evidence.get("surface_state", {}) as Dictionary
	var banner := showcase.find_child("FixtureBanner", true, false) as Label
	_expect(
		bool(surface_state.get("fixture_banner_visible", false))
			and banner != null
			and banner.visible
			and banner.is_visible_in_tree()
			and banner.text == FIXTURE_BANNER_TEXT,
		"%s/%s permanently displays the fixture banner" % [episode_id, phase]
	)
	_expect(
		int(evidence.get("production_main_instance_count", 0)) == 1
			and int(evidence.get("presentation_director_instance_count", 0)) == 1
			and bool(evidence.get("uses_production_director", false)),
		"%s/%s continues to use one real main and one Director"
			% [episode_id, phase]
	)

	var receipt := evidence.get("receipt", {}) as Dictionary
	var cue := evidence.get("animation_cue", {}) as Dictionary
	var projection := evidence.get("projection", {}) as Dictionary
	var expected_receipt_kind := str(row.get("receipt_kind", ""))
	if CARD_TABLE_FIXTURE_RECEIPT_KIND_BY_CUE.has(expected_cue_id):
		expected_receipt_kind = str(
			CARD_TABLE_FIXTURE_RECEIPT_KIND_BY_CUE.get(expected_cue_id, "")
		)
	_expect(
		str(receipt.get("receipt_kind", "")) == expected_receipt_kind
			and bool(receipt.get("fixture_sealed", false))
			and str(receipt.get("fixture_class", "")) == FIXTURE_CLASS
			and bool(receipt.get("accepted", false))
			and int(receipt.get("schema_version", -1)) == 1
			and _receipt_fingerprint_valid(receipt),
		"%s/%s carries one sealed, fingerprinted Receipt" % [episode_id, phase]
	)
	if CARD_TABLE_FIXTURE_RECEIPT_KIND_BY_CUE.has(expected_cue_id):
		_expect(
			str(receipt.get("schema", "")) == "V076PresentationFixtureEnvelopeV1"
				and str(receipt.get("cue_id", "")) == expected_cue_id
				and not bool(receipt.get("production_green", true))
				and not bool(receipt.get("human_green", true)),
			"%s/%s uses the typed Screen fixture envelope without Green claims"
				% [episode_id, phase]
		)
	_expect(
		str(projection.get("episode_id", "")) == episode_id
			and str(projection.get("fixture_class", "")) == FIXTURE_CLASS
			and str(projection.get("source_anchor", ""))
				== str(row.get("source_node", ""))
			and str(projection.get("target_anchor", ""))
				== str(row.get("target_node", "")),
		"%s/%s preserves the legal Projection anchors" % [episode_id, phase]
	)
	_expect(
		bool(evidence.get("anchor_resolution_valid", false))
			and str(evidence.get("source_anchor_resolved_path", ""))
				== str(row.get("source_anchor_path", ""))
			and str(evidence.get("target_anchor_resolved_path", ""))
				== str(row.get("target_anchor_path", ""))
			and int(evidence.get("source_anchor_resolution_count", 0)) == 1
			and int(evidence.get("target_anchor_resolution_count", 0)) == 1
			and int(evidence.get("anchor_fallback_count", -1)) == 0
			and str(evidence.get("prepare_rejection_reason", "")).is_empty(),
		"%s/%s resolves two exact unique production anchors without fallback"
			% [episode_id, phase]
	)
	_expect(
		str(cue.get("cue_id", "")) == expected_cue_id,
		"%s/%s expected Cue equals the queued Cue" % [episode_id, phase]
	)
	if director_applicable:
		_expect(
			str(receipt.get("cue_id", "")) == expected_cue_id
				and int(evidence.get("enqueue_count", 0)) == 1,
			"%s/%s is bound to one production Director Receipt"
				% [episode_id, phase]
		)
	else:
		_expect(
			str(receipt.get("cue_id", "")).is_empty()
				and not bool(cue.get("director_owned", true))
				and bool(cue.get("product_shell_owned", false)),
			"%s/%s explicitly records Director N/A" % [episode_id, phase]
		)
	if CARD_TABLE_FIXTURE_RECEIPT_KIND_BY_CUE.has(expected_cue_id):
		var bridge := evidence.get("card_table_fixture_bridge", {}) as Dictionary
		var cue_counts := bridge.get("cue_counts", {}) as Dictionary
		var bridge_row := cue_counts.get(expected_cue_id, {}) as Dictionary
		var cue_evidence := bridge.get("cue_evidence", {}) as Dictionary
		var bridge_evidence := cue_evidence.get(expected_cue_id, {}) as Dictionary
		var bridge_envelope := bridge_evidence.get("envelope", {}) as Dictionary
		_expect(
			str(bridge_evidence.get("consumer_class", "")) == FIXTURE_CLASS
				and str(bridge_envelope.get("schema", ""))
					== "V076PresentationFixtureEnvelopeV1"
				and str(bridge_envelope.get("receipt_kind", ""))
					== expected_receipt_kind
				and str(bridge_envelope.get("cue_id", "")) == expected_cue_id
				and str(bridge_envelope.get("receipt_id", ""))
					== str(receipt.get("receipt_id", "")),
			"%s/%s is routed through the unique Screen fixture bridge"
				% [episode_id, phase]
		)
		_expect(
			int(bridge_row.get("fixture_source_count", 0)) == 1
				and int(bridge_row.get("fixture_queued_count", 0)) == 1
				and int(bridge_row.get("fixture_surface_started_count", 0)) == 1
				and int(bridge_row.get("production_source_count", 0)) == 0
				and int(bridge_row.get("production_queued_count", 0)) == 0,
			"%s/%s records one fixture source/queue and no production bridge source"
				% [episode_id, phase]
		)

	var start_rect := _rect_from_data(evidence.get("start_rect", {}))
	var current_rect := _rect_from_data(evidence.get("current_rect", {}))
	var source_rect := _rect_from_data(evidence.get("source_rect", {}))
	var target_rect := _rect_from_data(evidence.get("target_rect", {}))
	_expect(
		start_rect.has_area()
			and current_rect.has_area()
			and source_rect.has_area()
			and target_rect.has_area(),
		"%s/%s has nonempty Rect evidence" % [episode_id, phase]
	)
	if phase == "start":
		_expect(
			_rect_close(start_rect, current_rect)
				and not bool(evidence.get("rect_changed_from_start", true)),
			"%s start frame binds the source Rect" % episode_id
		)
	else:
		_expect(
			bool(evidence.get("rect_changed_from_start", false)),
			"%s %s frame materially leaves the start Rect"
				% [episode_id, phase]
		)
	_expect(
		bool(evidence.get("authority_projection_consistent", false))
			and str(evidence.get("authority_boundary_hash_before", ""))
				== str(evidence.get("authority_boundary_hash_after", ""))
			and not str(evidence.get(
				"authority_boundary_hash_before", ""
			)).is_empty(),
		"%s/%s leaves the authority snapshot hash unchanged"
			% [episode_id, phase]
	)
	var authority_guard := evidence.get("authority_guard", {}) as Dictionary
	_expect(
		bool(authority_guard.get("valid", false))
			and int(authority_guard.get("missing_component_count", -1)) == 0
			and int(authority_guard.get("component_count", -1))
				== EXPECTED_AUTHORITY_COMPONENT_IDS.size()
			and authority_guard.get("component_ids", [])
				== EXPECTED_AUTHORITY_COMPONENT_IDS
			and str(authority_guard.get("snapshot_sha256", "")).length() == 64
			and str(authority_guard.get(
				"kernel_rng_state_sha256", ""
			)).length() == 64
			and str(authority_guard.get(
				"runtime_card_zone_state_sha256", ""
			)).length() == 64
			and str(authority_guard.get(
				"runtime_track_state_sha256", ""
			)).length() == 64
			and str(authority_guard.get(
				"runtime_facility_state_sha256", ""
			)).length() == 64
			and str(authority_guard.get(
				"runtime_settlement_state_sha256", ""
			)).length() == 64,
		"%s/%s guard covers Kernel RNG/sequence and Runtime domain owners"
			% [episode_id, phase]
	)
	if episode_id == "loading":
		var loading_debug := (evidence.get(
			"surface_state", {}
		) as Dictionary).get("loading_debug", {}) as Dictionary
		_expect(
			int(loading_debug.get("begin_count", -1)) == 0
				and int(loading_debug.get("failure_count", -1)) == 0
				and bool(loading_debug.get(
					"presentation_fixture_active", false
				)),
			"loading/%s uses the fixture lifecycle without production failure"
				% phase
		)
	_expect(
		_zero_mutation(evidence),
		"%s/%s reports zero gameplay/RNG/authority mutation"
			% [episode_id, phase]
	)
	_expect(
		_evidence_hash_valid(evidence),
		"%s/%s evidence hash covers the full frame record"
			% [episode_id, phase]
	)


func _zero_mutation(evidence: Dictionary) -> bool:
	for key in ZERO_MUTATION_KEYS:
		if int(evidence.get(key, -1)) != 0:
			return false
	return true


func _receipt_fingerprint_valid(receipt: Dictionary) -> bool:
	var supplied := str(receipt.get("receipt_fingerprint", ""))
	var source := receipt.duplicate(true)
	source.erase("receipt_fingerprint")
	return (
		supplied.length() == 64
		and supplied == PresentationReceiptIdentity.canonical_sha256(source)
	)


func _evidence_hash_valid(evidence: Dictionary) -> bool:
	var supplied := str(evidence.get("evidence_hash_sha256", ""))
	var source := evidence.duplicate(true)
	source.erase("evidence_hash_sha256")
	return (
		supplied.length() == 64
		and supplied == PresentationReceiptIdentity.canonical_sha256(source)
	)


func _rect_from_data(value: Variant) -> Rect2:
	if not (value is Dictionary):
		return Rect2()
	var source := value as Dictionary
	return Rect2(
		Vector2(
			float(source.get("x", 0.0)),
			float(source.get("y", 0.0))
		),
		Vector2(
			float(source.get("width", 0.0)),
			float(source.get("height", 0.0))
		)
	)


func _rect_close(left: Rect2, right: Rect2, tolerance := 0.75) -> bool:
	return (
		left.position.distance_to(right.position) <= tolerance
		and left.size.distance_to(right.size) <= tolerance
	)


func _count_named_recursive(node: Node, node_name: String) -> int:
	var count := int(str(node.name) == node_name)
	for child_variant: Variant in node.get_children():
		if child_variant is Node:
			count += _count_named_recursive(child_variant as Node, node_name)
	return count


func _read_json_dictionary(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return (
		(parsed as Dictionary).duplicate(true)
		if parsed is Dictionary
		else {}
	)


func _frames(count: int) -> void:
	for _index in range(maxi(1, count)):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print((
		"V076_PHASE8_COMMERCIAL_PRESENTATION_SHOWCASE_GATE"
		+ "|status=%s|fixture_class=%s"
		+ "|natural_gameplay=false|human_green=false"
		+ "|episodes=%d|frames=%d|duplicates_suppressed=%d"
		+ "|finishes_exact_once=%d|checks=%d|passed=%d|failures=%s"
		) % [
			status,
			FIXTURE_CLASS,
			_episode_pass_count,
			_frame_evidence_count,
			_duplicate_suppression_count,
			_finish_once_count,
			_checks,
			_checks - _failures.size(),
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)
