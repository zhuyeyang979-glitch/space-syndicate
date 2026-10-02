extends SceneTree

# Focused native-fixture contract only. No natural-loop or production-green claim.
# Root stages the bound candidates and reference support before executing.
const Core = preload("res://scripts/v075/monster/v075_monster_private_skill_core.gd")
const ReferenceSkillCore = preload("res://tests/support/v076_source_rows_skill_reference.gd")
const Owner = preload("res://scripts/v075/runtime/v075_combat_runtime_owner.gd")
const OwnerBench = preload("res://scripts/tools/v075/v075_combat_runtime_owner_bench.gd")
const SkillBench = preload("res://scripts/tools/v075/v075_monster_private_skill_bench.gd")
const AssetCore = preload("res://scripts/v07_semantic/v07_asset_batch_core.gd")
const CapacityPort = preload("res://scripts/v075/monster/v075_character_monster_capacity_port.gd")
const ProjectionAdapter = preload("res://scripts/v075/player/v075_combat_projection_adapter.gd")
const DamageCore = preload("res://scripts/v075/combat/v075_combat_damage_core.gd")

const SOURCE_SHA256 = {
	"res://scripts/v075/monster/v075_monster_private_skill_core.gd": "417820E177C718C598AF54B262F45C0E84D3F2330C05C86B6A36120E81FD7721",
	"res://scripts/v075/runtime/v075_combat_runtime_owner.gd": "8708A3BCFE75EBC9D019C4666667DC5F14EEEA1AC81608BE8A8A6E85228F750D",
	"res://tests/support/v076_source_rows_skill_reference.gd": "81C5C0564F9CA04C1FB218B4D87974EA0BAFF87F97D5B0509627767AEFD2805B",
	"res://scripts/tools/v075/v075_combat_runtime_owner_bench.gd": "3EBEE19FE6E715CF997D1E6F4AC345C074E59568D93049D14A83D3A1ED2D5E56",
	"res://scripts/tools/v075/v075_monster_private_skill_bench.gd": "39684A2E3C30D98A9738A438655A246A1CDB3D661ECED5EA44A47D8FF144B4CF",
	"res://scripts/v07_semantic/v07_asset_batch_core.gd": "E3F3C34D025E9111A398EF74CDF45C825781CD5E542557B4FB0155ED04B06EAD",
	"res://scripts/v075/monster/v075_character_monster_capacity_port.gd": "7CF69774CDF0A17D4EC279FEF4FD52D9C0C2B5E3957FB246DFD72C9DBC6B75D1",
	"res://scripts/v075/player/v075_combat_projection_adapter.gd": "0DA03775BA79E6721ED8AF01BF7F4BB740598FAFC5C06B8CD10A5D09292E15C9",
	"res://scripts/v075/combat/v075_combat_damage_core.gd": "347F9112214045C4A4F4E39B157F135EE665009F39A420DDEAC79E536D982135",
}
const OWNER_VIEWERS = ["player.alpha", "player.beta", "player.gamma", "player.unknown", "", "INVALID"]
const CORE_VIEWERS = ["player.0", "player.1", "player.unknown", "", "INVALID"]
const REPORT_PATH = "E:/SpaceSyndicateData/development/20261002/ui-diagnostic-scope/production-source-rows/source-rows-contract-v4-report.json"

class DerivedOwner:
	extends "res://scripts/v075/runtime/v075_combat_runtime_owner.gd"
	var public_inputs: Array[Dictionary] = []
	var private_inputs: Array[Dictionary] = []

	func _public_monsters_from_skill_public(skill_public: Dictionary) -> Array:
		public_inputs.append(skill_public.duplicate(true))
		return super._public_monsters_from_skill_public(skill_public)

	func _owner_private_skill_zone_from_projection(
		owner_player_id: String, facilities: Array, projection: Dictionary,
		public_snapshot: Variant = null
	) -> Array:
		private_inputs.append(projection.duplicate(true))
		return super._owner_private_skill_zone_from_projection(
			owner_player_id, facilities, projection, public_snapshot
		)

var _checks: int = 0
var _failures: Array[String] = []
var _cases: Array[Dictionary] = []
var _source_before: Dictionary = {}
var _source_after: Dictionary = {}
var _started_usec: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_started_usec = Time.get_ticks_usec()
	_source_before = _source_bindings()
	_expect(_source_before.get("matches_expected", false), "all frozen source files match before fixtures")
	if not _failures.is_empty():
		_finish()
		return
	_native_owner()
	_derived_fallback()
	_native_core_lifecycle()
	_near_depth_native_core()
	_source_after = _source_bindings()
	_expect(_source_after.get("matches_expected", false), "all frozen source files match after fixtures")
	_same(_source_before, _source_after, "source files unchanged across every impact")
	_finish()

func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error(label)

func _same(actual: Variant, expected: Variant, label: String) -> void:
	_expect(var_to_bytes(actual) == var_to_bytes(expected), label + " typed var_to_bytes")
	_expect(JSON.stringify(actual) == JSON.stringify(expected), label + " complete JSON")

func _source_bindings() -> Dictionary:
	var rows: Array[Dictionary] = []
	var matches: bool = true
	for path: String in SOURCE_SHA256:
		var actual: String = FileAccess.get_sha256(path).to_upper()
		var expected: String = str(SOURCE_SHA256[path])
		rows.append({"path": path, "expected_sha256": expected, "actual_sha256": actual})
		matches = matches and actual == expected
	return {"matches_expected": matches, "files": rows}

func _guard(owner: Node) -> bool:
	var program: Variant = owner.get("_projection_source_rows_native_program")
	_expect(program is Callable, "actual native guard property is a Callable")
	return bool((program as Callable).call(owner)) if program is Callable else false

func _all_six(amount: int) -> Dictionary:
	return {"life": amount, "energy": amount, "industry": amount, "technology": amount, "commerce": amount, "shipping": amount}

func _setup_owner(owner: Node, label: String) -> Dictionary:
	var fixture: Node = OwnerBench.new()
	# Never add Bench to the tree: its _ready would launch its own unrelated test.
	var players: Array = ["player.alpha", "player.beta", "player.gamma"]
	var semantics: Dictionary = {"player.alpha": CapacityPort.build_semantic("player.alpha", 1)}
	var initialized: Dictionary = owner.call("initialize", players, fixture.call("_map_receipt"), semantics) as Dictionary
	_expect(bool(initialized.get("accepted", false)), label + " native initialize")
	var assets: Dictionary = AssetCore.create_state("batch.owner.001", players, players, {"player.alpha": _all_six(6), "player.beta": _all_six(6), "player.gamma": _all_six(6)}, {}, 0, 1000)
	var facilities: Array = fixture.call("_facilities") as Array
	var begun: Dictionary = owner.call("begin_batch", "batch.owner.001", 0, assets, facilities) as Dictionary
	_expect(bool(begun.get("accepted", false)), label + " native begin batch")
	var source_ids: Array[String] = []
	for deployment: Array in [
		["player.alpha", "card.monster.alpha.001", "spore_tide_emperor", "life", "region.000"],
		["player.alpha", "card.monster.alpha.002", "meteor_sentinel", "energy", "region.001"],
		["player.beta", "card.monster.beta.001", "spore_tide_emperor", "life", "region.002"],
	]:
		var result: Dictionary = fixture.call("_deploy", owner, deployment[0], deployment[1], deployment[2], deployment[3], deployment[4]) as Dictionary
		_expect(bool(result.get("accepted", false)), label + " actual native deployment " + str(deployment[1]))
		source_ids.append(str((result.get("receipt", {}) as Dictionary).get("source_instance_id", "")))
	fixture.free()
	return {"assets": assets, "facilities": facilities, "source_ids": source_ids}

func _old_authority(owner: Node, viewer: String, facts: Dictionary, use_frozen_reference: bool = true) -> Dictionary:
	# Explicit historical algorithm; reference Core never uses the new selectors.
	var skill_state: Dictionary = owner.get("_skill_state") as Dictionary
	var bundle: Dictionary = ReferenceSkillCore.projection_bundle_for_viewer(skill_state, viewer) if use_frozen_reference else Core.projection_bundle_for_viewer(skill_state, viewer)
	var terminal: Dictionary = owner.call("_terminal_quiescence_from_skill_report", bundle.get("terminal_quiescence", {}) as Dictionary) as Dictionary
	var monsters: Array = owner.call("_public_monsters_from_skill_public", bundle.get("public_projection", {}) as Dictionary) as Array
	var zone: Array = owner.call("_owner_private_skill_zone_from_projection", viewer, [], bundle.get("owner_private_projection", {}) as Dictionary, monsters) as Array
	return {
		"phase": owner.get("_phase"),
		"terminal_quiescence": terminal,
		"public_monsters": monsters,
		"private_skill_zones_by_player": {viewer: zone},
		"private_player_facts_by_player": {viewer: facts.duplicate(true)},
	}

func _owner_checkpoint(owner: Node) -> Dictionary:
	var checkpoint: Dictionary = owner.call("_checkpoint_state") as Dictionary
	var skill: Dictionary = owner.get("_skill_state") as Dictionary
	var monster: Dictionary = owner.get("_monster_state") as Dictionary
	return {
		"full_checkpoint_state": checkpoint.duplicate(true),
		"combat_raw_receipt_journal": (owner.get("_combat_receipt_journal") as Array).duplicate(true),
		"skill_raw_receipt_journal": (skill.get("receipt_journal", []) as Array).duplicate(true),
		"monster_raw_receipt_journal": (monster.get("receipt_journal", []) as Array).duplicate(true),
		"monster_raw_transition_receipt_journal": (monster.get("transition_receipt_journal", []) as Array).duplicate(true),
	}

func _probe_owner(owner: Node, assets: Dictionary, label: String, expect_native: bool) -> void:
	var before: Dictionary = _owner_checkpoint(owner)
	var assets_before: Dictionary = assets.duplicate(true)
	_expect(_guard(owner) == expect_native, label + " actual native/fallback guard")
	var viewer_rows: Array[Dictionary] = []
	for viewer: String in OWNER_VIEWERS:
		var facts: Dictionary = {"private_marker": {"viewer": viewer}}
		var expected: Dictionary = _old_authority(owner, viewer, facts)
		var actual: Dictionary = owner.call("projection_authority_for_viewer", viewer, facts) as Dictionary
		_same(actual, expected, label + " full original five-field authority " + viewer)
		var adapter: RefCounted = ProjectionAdapter.new()
		var projected: Dictionary = adapter.call("project_for_viewer", actual, viewer) as Dictionary
		var baseline: Dictionary = adapter.call("project_for_viewer", expected, viewer) as Dictionary
		_same(projected, baseline, label + " final privacy DTO " + viewer)
		var privacy: Dictionary = adapter.call("privacy_report", projected) as Dictionary
		if viewer in ["player.alpha", "player.beta", "player.gamma"]:
			_expect(bool(privacy.get("valid", false)), label + " unchanged privacy boundary " + viewer)
		viewer_rows.append({"viewer": viewer, "expected_authority": expected.duplicate(true), "actual_authority": actual.duplicate(true), "privacy_report": privacy.duplicate(true), "typed_equal": var_to_bytes(actual) == var_to_bytes(expected), "json_equal": JSON.stringify(actual) == JSON.stringify(expected)})
		(actual.get("public_monsters", []) as Array).clear()
		((actual.get("private_player_facts_by_player", {}) as Dictionary).get(viewer, {}) as Dictionary).clear()
		_same(owner.call("projection_authority_for_viewer", viewer, facts), expected, label + " detached returned DTO " + viewer)
		_probe_core(owner.get("_skill_state") as Dictionary, assets, label + "." + viewer, [viewer])
	var after: Dictionary = _owner_checkpoint(owner)
	_same(after, before, label + " full checkpoint and every raw receipt journal unchanged")
	_same(assets, assets_before, label + " assets unchanged by all projection reads")
	_cases.append({"case": label, "kind": "actual_owner_native_fixture", "native_guard": expect_native, "before": before, "after": after, "asset_state_before": assets_before, "asset_state_after": assets.duplicate(true), "viewers": viewer_rows})

func _probe_core(state: Dictionary, assets: Dictionary, label: String, viewers: Array = CORE_VIEWERS) -> void:
	var before: Dictionary = state.duplicate(true)
	var assets_before: Dictionary = assets.duplicate(true)
	var rows: Array[Dictionary] = []
	for viewer: String in viewers:
		var reference: Dictionary = ReferenceSkillCore.projection_bundle_for_viewer(state, viewer)
		var complete: Dictionary = Core.projection_bundle_for_viewer(state, viewer)
		_same(complete, reference, label + " legacy default three full DTOs " + viewer)
		_same(Core.public_projection(state), ReferenceSkillCore.public_projection(state), label + " legacy standalone public " + viewer)
		_same(Core.owner_private_projection(state, viewer), ReferenceSkillCore.owner_private_projection(state, viewer), label + " legacy standalone private " + viewer)
		_same(Core.terminal_quiescence_report(state), ReferenceSkillCore.terminal_quiescence_report(state), label + " legacy terminal " + viewer)
		var selected: Dictionary = Core.projection_bundle_for_viewer(state, viewer, ["terminal_quiescence", "public_source_rows", "owner_private_source_rows"])
		_same(selected.get("terminal_quiescence", {}), reference.get("terminal_quiescence", {}), label + " fresh terminal with rows " + viewer)
		for pair: Array in [["public_source_rows", "public_projection"], ["owner_private_source_rows", "owner_private_projection"]]:
			var full: Dictionary = reference.get(pair[1], {}) as Dictionary
			var expected: Dictionary = {} if full.is_empty() else {"sources": (full.get("sources", []) as Array).duplicate(true)}
			var actual: Dictionary = selected.get(pair[0], {}) as Dictionary
			_same(actual, expected, label + " complete typed source array " + str(pair[0]) + " " + viewer)
			_expect(actual.is_empty() or actual.keys() == ["sources"], label + " new kind has only sources " + str(pair[0]))
			(actual.get("sources", []) as Array).clear()
		var again: Dictionary = Core.projection_bundle_for_viewer(state, viewer, ["terminal_quiescence", "public_source_rows", "owner_private_source_rows"])
		_same(again.get("public_source_rows", {}), {} if (reference.get("public_projection", {}) as Dictionary).is_empty() else {"sources": (reference.get("public_projection") as Dictionary).get("sources")}, label + " new public DTO detached " + viewer)
		rows.append({"viewer": viewer, "reference_default": reference, "candidate_default": complete, "new_selected_detached_read": again})
	_same(state, before, label + " full skill authority and raw receipt journal unchanged")
	_same(assets, assets_before, label + " real AssetCore authority unchanged")
	_cases.append({"case": label, "kind": "native_core_projection", "full_state_before": before, "full_state_after": state.duplicate(true), "raw_receipt_journal_before": before.get("receipt_journal", []), "raw_receipt_journal_after": state.get("receipt_journal", []).duplicate(true), "asset_state_before": assets_before, "asset_state_after": assets.duplicate(true), "viewers": rows})

func _native_owner() -> void:
	var owner: Node = Owner.new()
	_expect(_guard(owner), "positive fixture is actual production native Owner, not a counted/derived class")
	var fixture: Dictionary = _setup_owner(owner, "native")
	var assets: Dictionary = fixture.get("assets") as Dictionary
	_probe_owner(owner, assets, "three_native_sources", true)
	var zone: Array = owner.call("owner_private_skill_zone", "player.alpha") as Array
	var chosen_source: Dictionary = {}
	for row: Dictionary in zone:
		if str(row.get("source_instance_id", "")) == str((fixture.get("source_ids") as Array)[0]):
			chosen_source = row
	var skills: Array = chosen_source.get("skills", []) as Array
	_expect(not skills.is_empty(), "actual alpha native source exposes its unlocked skill")
	if not skills.is_empty():
		var result: Dictionary = owner.call("request_private_skill", {
			"request_id": "request.source.rows.alpha.001", "owner_player_id": "player.alpha",
			"source_instance_id": (fixture.get("source_ids") as Array)[0], "source_generation": 1,
			"skill_definition_id": (skills[0] as Dictionary).get("skill_definition_id"),
			"target_request": {"target_kind": "enemy_public_facility", "target_id": "facility.enemy.factory.000", "target_facility_generation": 1},
		}, assets, fixture.get("facilities") as Array) as Dictionary
		_expect(bool(result.get("accepted", false)) and int(result.get("resolved_count", 0)) == 1, "actual native skill safe-boundary resolution commits")
		assets = result.get("asset_state", assets) as Dictionary
		_probe_owner(owner, assets, "native_skill_resolved_cooldown", true)
		var skill_state: Dictionary = owner.get("_skill_state") as Dictionary
		var alpha_source: Dictionary = (skill_state.get("sources") as Dictionary).get((fixture.get("source_ids") as Array)[0], {}) as Dictionary
		var saw_cooldown: bool = false
		for skill: Dictionary in (alpha_source.get("skill_states", {}) as Dictionary).values():
			saw_cooldown = saw_cooldown or int(skill.get("cooldown_remaining_batches", 0)) > 0
		_expect(saw_cooldown, "resolved native source has an actual nonzero cooldown")
	var target: Dictionary = _public_monster_by_id(owner, str((fixture.get("source_ids") as Array)[1]))
	_expect(not target.is_empty(), "actual SourceCore HP mutation target exists")
	if not target.is_empty():
		var hp_before: int = int(target.get("hp", -1))
		var intent: Dictionary = DamageCore.build_monster_damage_intent("effect.source.rows.hp", str(target.get("source_instance_id", "")), int(target.get("source_generation", 0)), int(target.get("source_revision", 0)), int(target.get("armor", 0)) + 1, str(target.get("region_id", "")), "combat.source.rows.hp")
		var hit: Dictionary = owner.call("apply_monster_damage_intent", intent) as Dictionary
		_expect(bool(hit.get("accepted", false)), "actual apply_monster_damage_intent accepts native fixture target")
		var fresh: Dictionary = _public_monster_by_id(owner, str((fixture.get("source_ids") as Array)[1]))
		_expect(int(fresh.get("hp", -1)) < hp_before, "native apply_monster_damage_intent actually changes HP")
		_probe_owner(owner, assets, "native_hp_changed", true)
	_dynamic_public_fields(owner, assets)
	_hot_fallback(owner, assets, Owner, "loaded_owner_source_string")
	_hot_fallback(owner, assets, Core, "loaded_skill_source_string")
	var terminal: Dictionary = owner.call("set_phase", "terminal") as Dictionary
	_expect(bool(terminal.get("accepted", false)), "native terminal phase transition")
	_probe_owner(owner, assets, "native_terminal", true)
	owner.free()

func _hot_fallback(owner: Node, assets: Dictionary, program: Script, label: String) -> void:
	var saved: String = program.source_code
	program.source_code = saved + "\n# source rows contract: hot String mutation, intentionally no reload\n"
	_expect(not _guard(owner), label + " changed loaded source String rejects native guard")
	_probe_owner(owner, assets, label + ".fallback", false)
	program.source_code = saved
	_expect(program.source_code == saved, label + " restores exact complete source String")
	_expect(_guard(owner), label + " exact native source restoration re-enables guard")
	_cases.append({"case": label, "kind": "loaded_script_string_no_reload", "reload_called": false, "compiled_default_changed": false, "original_source_sha256": saved.sha256_text(), "restored_source_sha256": program.source_code.sha256_text()})

func _derived_fallback() -> void:
	var owner: Node = DerivedOwner.new()
	_expect(not _guard(owner), "derived marker Owner must use full default bundle")
	var fixture: Dictionary = _setup_owner(owner, "derived_negative")
	_probe_owner(owner, fixture.get("assets") as Dictionary, "derived_full_bundle_fallback", false)
	var derived: DerivedOwner = owner as DerivedOwner
	derived.public_inputs.clear()
	derived.private_inputs.clear()
	var result: Dictionary = owner.call("projection_authority_for_viewer", "player.alpha", {"private_marker": true}) as Dictionary
	_expect(not result.is_empty(), "derived production read returns complete authority")
	_expect(derived.public_inputs.size() == 1 and derived.private_inputs.size() == 1, "actual derived helper overrides are called once per production read")
	if not derived.public_inputs.is_empty():
		_expect(derived.public_inputs[0].has("public_results") and derived.public_inputs[0].has("projection_fingerprint"), "derived public helper receives enclosing full historical result/seal fields")
	if not derived.private_inputs.is_empty():
		_expect(derived.private_inputs[0].has("viewer_player_id") and derived.private_inputs[0].has("projection_fingerprint"), "derived private helper receives original complete enclosing fields")
	_cases.append({"case": "derived_override_enclosing_fields", "public_inputs": derived.public_inputs.duplicate(true), "private_inputs": derived.private_inputs.duplicate(true), "native_guard": _guard(owner)})
	owner.free()

func _native_core_lifecycle() -> void:
	var state: Dictionary = SkillBench.TestFixture.state(4, true)
	var players: Array = ["player.0", "player.1"]
	var assets: Dictionary = AssetCore.create_state("batch.test.001", players, players, {"player.0": _all_six(6), "player.1": _all_six(6)}, {}, 0, 1000)
	_expect(bool(Core.validation_report(state).get("valid", false)), "native SkillBench fixture is complete sealed state")
	_expect(bool(AssetCore.validation_report(assets).get("valid", false)), "native AssetCore fixture is valid")
	_probe_core(state, assets, "core.native_ready")
	var started: Dictionary = Core.begin_atomic_receipt(state, "atomic.source.rows.fixture")
	_same(started, ReferenceSkillCore.begin_atomic_receipt(state, "atomic.source.rows.fixture"), "actual atomic transition equals old complete Core")
	_expect(bool(started.get("accepted", false)), "actual atomic receipt begins")
	state = started.get("state", {}) as Dictionary
	_probe_core(state, assets, "core.atomic_inflight")
	var request: Dictionary = Core.build_request("request.source.rows.core.001", "batch.test.001", "player.0", "monster.owner.001", 1, "skill.owner.1", {"target_kind": "enemy_facility", "target_id": "facility.target.001"})
	var view: Dictionary = AssetCore.monster_skill_available_asset_view(assets, "player.0")
	var submitted: Dictionary = Core.submit_request(state, request, view)
	_same(submitted, ReferenceSkillCore.submit_request(state, request, view), "native request submit retains old authority bytes")
	_expect(bool(submitted.get("accepted", false)), "native submit accepted")
	state = submitted.get("state", {}) as Dictionary
	_probe_core(state, assets, "core.awaiting_reservation")
	var reserved: Dictionary = AssetCore.prepare_monster_skill_asset_reservation(assets, submitted.get("asset_reservation_request", {}) as Dictionary)
	_expect(bool(reserved.get("accepted", false)), "actual AssetCore reserves native skill cost")
	assets = reserved.get("state", {}) as Dictionary
	var applied: Dictionary = Core.apply_asset_reservation_receipt(state, reserved.get("reservation_receipt", {}) as Dictionary)
	_expect(bool(applied.get("accepted", false)), "native Core accepts actual asset reservation receipt")
	state = applied.get("state", {}) as Dictionary
	_probe_core(state, assets, "core.reserved_pending_target")
	var completed: Dictionary = Core.complete_atomic_receipt(state, "atomic.source.rows.fixture")
	_expect(bool(completed.get("accepted", false)), "native safe boundary completes")
	state = completed.get("state", {}) as Dictionary
	_probe_core(state, assets, "core.boundary_ready")
	var taken: Dictionary = Core.take_next_ready_request(state)
	_expect(bool(taken.get("accepted", false)), "native ready request becomes resolving")
	state = taken.get("state", {}) as Dictionary
	_probe_core(state, assets, "core.resolving")
	var effect: Dictionary = Core.build_effect_receipt(taken.get("execution_intent", {}) as Dictionary, true, "resolved", {"target_kind": "enemy_facility", "target_id": "facility.target.001", "target_region_id": "region.001"}, {"damage_amount": 1, "combat_receipt_id": "combat.source.rows.core.001"})
	var resolved: Dictionary = Core.resolve_current(state, effect)
	_same(resolved, ReferenceSkillCore.resolve_current(state, effect), "native resolve cooldown/history/seals equal old complete Core")
	_expect(bool(resolved.get("accepted", false)), "native resolve emits committed public history")
	state = resolved.get("state", {}) as Dictionary
	var settled: Dictionary = AssetCore.commit_monster_skill_asset_reservation(assets, resolved.get("asset_settlement_intent", {}) as Dictionary)
	_expect(bool(settled.get("accepted", false)), "actual AssetCore spends committed fee")
	assets = settled.get("state", {}) as Dictionary
	_probe_core(state, assets, "core.resolved_history_cooldown")
	for status: String in ["downed", "active", "withdrawn", "destroyed"]:
		var changed: Dictionary = Core.set_source_status(state, "monster.owner.001", 1, status)
		_same(changed, ReferenceSkillCore.set_source_status(state, "monster.owner.001", 1, status), "native source lifecycle " + status)
		_expect(bool(changed.get("accepted", false)), "native source lifecycle accepted " + status)
		state = changed.get("state", {}) as Dictionary
		_probe_core(state, assets, "core.status." + status)
	var replacement: Dictionary = Core.build_source_snapshot("monster.owner.001", 2, "player.0", 4, "active", SkillBench.TestFixture.skill_ids(), SkillBench.TestFixture.skill_ids())
	var synchronized: Dictionary = Core.sync_source_snapshot(state, replacement)
	_same(synchronized, ReferenceSkillCore.sync_source_snapshot(state, replacement), "actual generation sync equals full old Core")
	_expect(bool(synchronized.get("accepted", false)), "actual native source generation increases")
	state = synchronized.get("state", {}) as Dictionary
	_probe_core(state, assets, "core.generation_two")
	var advanced: Dictionary = Core.advance_batch(state, "batch.test.002")
	_same(advanced, ReferenceSkillCore.advance_batch(state, "batch.test.002"), "native batch cooldown transition equals old Core")
	_expect(bool(advanced.get("accepted", false)), "native batch advances")
	state = advanced.get("state", {}) as Dictionary
	_probe_core(state, assets, "core.next_batch")
	for phase: String in Core.TERMINAL_PHASES:
		var terminal: Dictionary = Core.set_phase(state, phase)
		_same(terminal, ReferenceSkillCore.set_phase(state, phase), "native terminal transition " + phase)
		_expect(bool(terminal.get("accepted", false)), "native terminal accepts " + phase)
		state = terminal.get("state", {}) as Dictionary
		_probe_core(state, assets, "core.terminal." + phase)
	_negative_selectors(state, assets)

func _negative_selectors(state: Dictionary, assets: Dictionary) -> void:
	var before: Dictionary = state.duplicate(true)
	for kinds: Array in [[], ["unknown_kind"], ["public_source_rows", "public_source_rows"], ["owner_private_source_rows", "owner_private_source_rows"], [1], ["public_source_rows", "unknown_kind"]]:
		_expect(Core.projection_bundle_for_viewer(state, "player.0", kinds).is_empty(), "invalid/unknown/duplicate selectors fail closed " + JSON.stringify(kinds))
	_same(state, before, "negative selector requests preserve native source state")
	var bad: Dictionary = state.duplicate(true)
	bad["state_fingerprint"] = "0".repeat(64)
	_expect(not bool(Core.validation_report(bad).get("valid", true)), "independent malformed clone has invalid complete fingerprint")
	_probe_core(bad, assets, "core.corrupted_independent_copy")
	var selected: Dictionary = Core.projection_bundle_for_viewer(bad, "player.0", ["terminal_quiescence", "public_source_rows", "owner_private_source_rows"])
	_expect((selected.get("public_source_rows", {}) as Dictionary).is_empty() and (selected.get("owner_private_source_rows", {}) as Dictionary).is_empty(), "fresh validation rejects both rows on corrupt state")
	_expect(not bool((selected.get("terminal_quiescence", {}) as Dictionary).get("valid", true)), "fresh validation preserves invalid terminal report")
	_same(state, before, "malformed independent copy never contaminates original authority")

func _finish() -> void:
	var destination: String = OS.get_environment("V076_COMBAT_SOURCE_ROWS_REPORT")
	if destination.is_empty():
		destination = REPORT_PATH
	destination = destination.replace("\\", "/")
	_expect(destination.begins_with("E:/SpaceSyndicateData/") and destination.is_absolute_path() and not destination.contains("/../"), "report destination is authorized absolute E path")
	var report: Dictionary = {
		"schema": "V076CombatSourceRowsFocusedNativeContractV1",
		"status": "PASS" if _failures.is_empty() else "FAIL",
		"evidence_class": "NATIVE_FIXTURE_CONTRACT_NONNATURAL",
		"natural_complete_loop": false, "production_green": false, "human_green": false,
		"performance_claimed": false, "typed_full_variant_comparison": true,
		"json_full_dto_comparison": true, "godot_execution_owner": "Root",
		"checks": _checks, "failures": _failures.duplicate(),
		"elapsed_usec": Time.get_ticks_usec() - _started_usec,
		"source_binding_before": _source_before, "source_binding_after": _source_after,
		"cases": _cases,
	}
	if destination.begins_with("E:/SpaceSyndicateData/") and destination.is_absolute_path() and not destination.contains("/../"):
		var directory_result: Error = DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
		_expect(directory_result == OK, "E report directory is writable")
		var file: FileAccess = FileAccess.open(destination, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t"))
			file.close()
		else:
			_expect(false, "E complete raw report file opens")
	print("V076_COMBAT_SOURCE_ROWS_CONTRACT ", "PASS" if _failures.is_empty() else "FAIL", " checks=", _checks, " failures=", _failures.size(), " report=", destination)
	quit(0 if _failures.is_empty() else 1)


func _public_monster_by_id(owner: Node, source_id: String) -> Dictionary:
	for source: Dictionary in owner.call("public_monsters") as Array:
		if str(source.get("source_instance_id", "")) == source_id:
			return source.duplicate(true)
	return {}

func _dynamic_public_fields(owner: Node, assets: Dictionary) -> void:
	var fields_value: Variant = (Core as Script).get_script_constant_map().get(&"PUBLIC_RESULT_FIELDS")
	_expect(fields_value is Array, "loaded actual Skill Script constant map exposes PUBLIC_RESULT_FIELDS Array")
	if not (fields_value is Array):
		return
	var fields: Array = fields_value as Array
	if fields.is_read_only():
		_cases.append({"case": "dynamic_public_result_fields", "status": "NOT_EXERCISED", "reason": "actual constant Array is read-only; prohibited mutation was not attempted"})
		return
	var saved: Array = fields.duplicate(true)
	var before: Dictionary = _owner_checkpoint(owner)
	var assets_before: Dictionary = assets.duplicate(true)
	fields.append(false)
	_expect(not _guard(owner), "fresh native guard rejects non-String current PUBLIC_RESULT_FIELDS")
	var rows: Array[Dictionary] = []
	for viewer: String in OWNER_VIEWERS:
		var facts: Dictionary = {"private_marker": {"viewer": viewer}}
		# Current compiled Core's original two-argument default contract is the
		# correct fallback oracle when only its own mutable constants change.
		var expected: Dictionary = _old_authority(owner, viewer, facts, false)
		var actual: Dictionary = owner.call("projection_authority_for_viewer", viewer, facts) as Dictionary
		_same(actual, expected, "dynamic fields retains current full default/old five-field assembly " + viewer)
		rows.append({"viewer": viewer, "expected_current_default_authority": expected, "actual_fallback_authority": actual})
	fields.clear()
	fields.append_array(saved)
	_same(fields, saved, "dynamic PUBLIC_RESULT_FIELDS exact Array restoration")
	_expect(_guard(owner), "native guard restored after exact PUBLIC_RESULT_FIELDS restoration")
	var after: Dictionary = _owner_checkpoint(owner)
	_same(after, before, "dynamic fields does not alter full checkpoint or raw journals")
	_same(assets, assets_before, "dynamic fields does not alter real asset authority")
	_cases.append({"case": "dynamic_public_result_fields", "status": "EXERCISED", "full_checkpoint_before": before, "full_checkpoint_after": after, "viewers": rows})

func _near_depth_native_core() -> void:
	var found_valid_old_private_empty: bool = false
	var rows: Array[Dictionary] = []
	# Independent native Core fixture only. No actual Owner/Main state injection.
	for depth in range(55, 65):
		var nested: Variant = "leaf"
		for _index in range(depth):
			nested = {"next": nested}
		var definition: Dictionary = Core.build_skill_definition(
			"skill.depth.1", "effect.depth.1", 1, false, _all_six(0),
			{"target_kind": "enemy_facility", "depth_probe": nested},
			{"range_hops": 2}, 1, "monster.skill.depth.1"
		)
		var source: Dictionary = Core.build_source_snapshot(
			"monster.depth.001", 1, "player.0", 1, "active",
			["skill.depth.1"], ["skill.depth.1"]
		)
		var state: Dictionary = Core.create_state("batch.depth.001", [source], [definition])
		var reference_validation: Dictionary = ReferenceSkillCore.validation_report(state)
		var candidate_validation: Dictionary = Core.validation_report(state)
		_same(candidate_validation, reference_validation, "near-depth original complete state validation depth=" + str(depth))
		var valid: bool = bool(reference_validation.get("valid", false))
		var old: Dictionary = ReferenceSkillCore.owner_private_projection(state, "player.0")
		var selected: Dictionary = Core.projection_bundle_for_viewer(state, "player.0", ["owner_private_source_rows"])
		var actual: Dictionary = selected.get("owner_private_source_rows", {}) as Dictionary
		var expected: Dictionary = {} if old.is_empty() else {"sources": (old.get("sources", []) as Array).duplicate(true)}
		_same(actual, expected, "near-depth rows preserves old enclosing seal pure-data boundary depth=" + str(depth))
		if valid:
			_probe_core(state, {}, "core.near_depth." + str(depth))
		found_valid_old_private_empty = found_valid_old_private_empty or (valid and old.is_empty())
		rows.append({"depth": depth, "reference_validation": reference_validation, "candidate_validation": candidate_validation, "valid_state": valid, "old_complete_private_empty": old.is_empty(), "new_rows_empty": actual.is_empty(), "full_native_state": state, "old_complete_private": old, "new_private_source_rows": actual})
	_cases.append({"case": "near_depth_independent_native_core", "found_valid_state_old_private_seal_empty": found_valid_old_private_empty, "status": "EXERCISED" if found_valid_old_private_empty else "BOUNDARY_NOT_FOUND", "no_owner_injection": true, "depth_min": 55, "depth_max": 64, "rows": rows})
