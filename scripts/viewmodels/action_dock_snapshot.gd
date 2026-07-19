extends RefCounted
class_name ActionDockSnapshot

const DEFAULT_QUICK_ACTIONS := [
	{"id": "rack", "label": "牌架", "state": "未选", "disabled": true, "shortcut": "1", "tooltip": "先选择区域查看发展牌架。"},
	{"id": "buy", "label": "买牌", "state": "--", "disabled": true, "shortcut": "2", "tooltip": "进入可购买窗口后再买牌。"},
	{"id": "play", "label": "出牌", "state": "--", "disabled": true, "shortcut": "3", "tooltip": "当前没有可直接打出的手牌。"},
]

var quick_actions: Array = []
var actions: Array = []


func apply_dictionary(data: Dictionary) -> RefCounted:
	var quick_source: Variant = data.get("quick_actions", data.get("action_summary", []))
	var action_source: Variant = data.get("actions", [])
	quick_actions = _normalize_quick_actions(quick_source)
	actions = _normalize_actions(action_source, "")
	return self


func apply_actions(entries_variant: Variant, fallback_label: String = "") -> RefCounted:
	quick_actions = []
	actions = _normalize_actions(entries_variant, fallback_label)
	return self


func to_ui_dictionary() -> Dictionary:
	return {
		"quick_actions": _duplicate_array(quick_actions),
		"actions": _duplicate_array(actions),
	}


func to_action_array() -> Array:
	return _duplicate_array(actions)


func _normalize_quick_actions(entries_variant: Variant) -> Array:
	var entries: Array = entries_variant if entries_variant is Array else []
	if entries.is_empty():
		entries = DEFAULT_QUICK_ACTIONS
	var result: Array = []
	var index := 0
	for entry_variant in entries:
		index += 1
		result.append(_normalize_action(entry_variant, index, "行动%d" % index, true))
	return result


func _normalize_actions(entries_variant: Variant, fallback_label: String) -> Array:
	var entries: Array = entries_variant if entries_variant is Array else []
	var result: Array = []
	var index := 0
	for entry_variant in entries:
		index += 1
		result.append(_normalize_action(entry_variant, index, "行动%d" % index, false))
	if result.is_empty() and fallback_label.strip_edges() != "":
		result.append({
			"id": fallback_label,
			"label": fallback_label,
			"state": "--",
			"active": false,
			"disabled": true,
			"tooltip": "",
		})
	return result


func _normalize_action(entry_variant: Variant, index: int, fallback_label: String, quick_action: bool) -> Dictionary:
	var entry: Dictionary = entry_variant if entry_variant is Dictionary else {}
	var fallback_text := str(entry_variant).strip_edges() if not (entry_variant is Dictionary) else fallback_label
	if fallback_text == "" or fallback_text == "<null>":
		fallback_text = fallback_label
	var raw_label := _first_text(entry, ["label", "title", "name", "text"], fallback_text)
	var action_id := _first_text(entry, ["id", "action_id", "key"], raw_label)
	var disabled := bool(entry.get("disabled", false)) or bool(entry.get("locked", false))
	var active := bool(entry.get("active", not disabled))
	var state := _state_text(_first_text(entry, ["state", "status", "phase"], "ready" if active else "waiting"), active, disabled)
	var shortcut := _quick_action_shortcut(entry, index, quick_action)
	var result := {
		"id": _short_text(action_id, 32),
		"label": _short_text(raw_label, 8 if quick_action else 16),
		"state": state,
		"active": active and not disabled,
		"disabled": disabled,
		"shortcut": shortcut,
		"tooltip": _first_text(entry, ["tooltip", "hint", "why"], ""),
	}
	for semantic_key in ["kind", "strategy_route", "consequence", "suggested_action", "focus_target", "relevant_cost", "relevant_requirement"]:
		var semantic_value := str(entry.get(semantic_key, "")).strip_edges()
		if not semantic_value.is_empty():
			result[semantic_key] = semantic_value
	var application_intent: Variant = entry.get("application_intent", {})
	if application_intent is Dictionary and IntelApplicationIntent.from_dictionary(application_intent as Dictionary) != null:
		result["application_intent"] = (application_intent as Dictionary).duplicate(true)
	return result


func _quick_action_shortcut(entry: Dictionary, index: int, quick_action: bool) -> String:
	if not quick_action:
		return ""
	var explicit := _first_text(entry, ["shortcut", "hotkey", "key_hint"], "")
	if explicit != "":
		return _short_text(explicit, 3)
	if index >= 1 and index <= 4:
		return str(index)
	return ""


func _state_text(raw_state: String, active: bool, disabled: bool) -> String:
	var text := raw_state.strip_edges()
	if text == "":
		return "就绪" if active and not disabled else "--"
	match text.to_lower():
		"ready", "active", "current", "available":
			return "就绪"
		"browse", "inspect", "open":
			return "可看"
		"blocked", "locked", "waiting", "select", "empty", "disabled":
			return "--"
	return _short_text(text, 6)


func _first_text(data: Dictionary, keys: Array, fallback: String) -> String:
	for key_variant in keys:
		var key := String(key_variant)
		if data.has(key):
			var value := str(data.get(key, "")).replace("\n", " ").strip_edges()
			if value != "":
				return value
	return fallback


func _short_text(value: String, limit: int) -> String:
	var text := value.strip_edges()
	if text.length() <= limit:
		return text
	return "%s…" % text.substr(0, maxi(1, limit - 1))


func _duplicate_array(entries: Array) -> Array:
	var result: Array = []
	for entry_variant in entries:
		if entry_variant is Dictionary:
			result.append((entry_variant as Dictionary).duplicate(true))
		else:
			result.append(entry_variant)
	return result
