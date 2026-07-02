extends RefCounted
class_name PublicTrackSnapshot

const DEFAULT_LABEL := "公共牌"
const HIDDEN_OWNER_TEXT := "匿名"
const DEFAULT_STATE_TEXT := "等待"

var entries: Array = []


func apply_entries(source: Variant) -> RefCounted:
	entries = []
	var source_entries: Array = source if source is Array else []
	var index := 0
	for entry_variant in source_entries:
		index += 1
		entries.append(_normalized_entry(entry_variant, index))
	return self


func to_ui_array() -> Array:
	var result: Array = []
	for entry_variant in entries:
		if entry_variant is Dictionary:
			result.append((entry_variant as Dictionary).duplicate(true))
	return result


func _normalized_entry(entry_variant: Variant, index: int) -> Dictionary:
	var entry: Dictionary = entry_variant if entry_variant is Dictionary else {}
	var fallback_label := str(entry_variant).strip_edges() if not (entry_variant is Dictionary) else DEFAULT_LABEL
	if fallback_label == "" or fallback_label == "<null>":
		fallback_label = DEFAULT_LABEL
	var label := _short_text(_first_text(entry, ["label", "title", "name", "card_name"], fallback_label), 12)
	var state := _state_text(_first_text(entry, ["state", "status", "phase"], ""))
	var kind := _kind_text(_first_text(entry, ["kind", "type", "category"], "anonymous"))
	var cost := _first_text(entry, ["cost", "bid", "price", "fee"], "")
	var owner_hint := _owner_hint(entry)
	var slot := _slot_text(entry, index)
	var accent := _accent_color(entry, kind, state)
	var badges: Array = entry.get("badges", []) if entry.get("badges", []) is Array else []
	var selected := bool(entry.get("selected", entry.get("focused", false)))
	var normalized := {
		"id": _first_text(entry, ["id", "track_id"], "track_%d" % index),
		"resolution_id": int(entry.get("resolution_id", -1)),
		"card_name": _first_text(entry, ["card_name", "source_card"], ""),
		"label": label,
		"slot": slot,
		"state": state,
		"kind": kind,
		"cost": cost,
		"owner_hint": owner_hint,
		"badges": badges,
		"accent": accent,
		"active": selected or bool(entry.get("active", _is_active_state(state))),
		"selected": selected,
		"tooltip": _tooltip_text(entry, label, state, owner_hint, cost),
	}
	for key in ["title", "summary", "detail", "full_detail", "why", "open_action", "select_action"]:
		if entry.has(key):
			normalized[key] = entry[key]
	for key in ["requirements", "actions", "deep_links", "logs"]:
		if entry.get(key, []) is Array:
			normalized[key] = (entry.get(key, []) as Array).duplicate(true)
	return normalized


func _first_text(entry: Dictionary, keys: Array, fallback: String) -> String:
	for key_variant in keys:
		var key := String(key_variant)
		if entry.has(key):
			var text := str(entry[key]).strip_edges()
			if text != "":
				return text
	return fallback


func _state_text(raw_state: String) -> String:
	var state := raw_state.strip_edges()
	if state == "":
		return DEFAULT_STATE_TEXT
	match state.to_lower():
		"ready", "active", "current", "revealing", "open":
			return "当前"
		"queued", "waiting", "pending":
			return "候补"
		"resolved", "history", "done":
			return "结算"
		"locked", "hidden":
			return "锁定"
	return _short_text(state, 8)


func _kind_text(raw_kind: String) -> String:
	var kind := raw_kind.strip_edges()
	if kind == "":
		return "anonymous"
	match kind.to_lower():
		"event":
			return "event"
		"history", "resolved":
			return "history"
		"queue", "queued":
			return "queue"
	return kind.to_lower()


func _owner_hint(entry: Dictionary) -> String:
	var explicit_hint := _first_text(entry, ["owner_hint", "owner_label", "public_owner_label"], "")
	if explicit_hint != "":
		return _short_text(explicit_hint.replace("归属：", "").replace("归属:", ""), 8)
	var owner_visible := bool(entry.get("owner_revealed", false)) or bool(entry.get("public_owner_revealed", false)) or bool(entry.get("owner_public", false))
	if not owner_visible:
		return HIDDEN_OWNER_TEXT
	var owner := _first_text(entry, ["owner", "player", "seat"], "")
	return _short_text(owner, 8) if owner != "" else HIDDEN_OWNER_TEXT


func _slot_text(entry: Dictionary, index: int) -> String:
	var raw_slot := _first_text(entry, ["slot", "index", "position"], "")
	if raw_slot == "":
		return "#%d" % index
	if raw_slot.begins_with("#"):
		return _short_text(raw_slot, 5)
	return "#%s" % _short_text(raw_slot, 4)


func _accent_color(entry: Dictionary, kind: String, state: String) -> Color:
	var accent_variant: Variant = entry.get("accent", null)
	if accent_variant is Color:
		return accent_variant
	if accent_variant is String:
		var accent_text := String(accent_variant).strip_edges()
		if accent_text.begins_with("#"):
			return Color(accent_text)
	if _is_active_state(state):
		return Color("#facc15")
	match kind:
		"event":
			return Color("#a78bfa")
		"history":
			return Color("#64748b")
		"queue":
			return Color("#f59e0b")
	return Color("#38bdf8")


func _tooltip_text(entry: Dictionary, label: String, state: String, owner_hint: String, cost: String) -> String:
	var explicit_tooltip := _first_text(entry, ["tooltip", "hint"], "")
	if explicit_tooltip != "":
		return explicit_tooltip
	var pieces: Array[String] = [label, state, "归属:%s" % owner_hint]
	if cost != "":
		pieces.append("报价:%s" % cost)
	return "｜".join(pieces)


func _is_active_state(state: String) -> bool:
	return state == "当前" or state == "揭示" or state == "结算中"


func _short_text(text: String, max_length: int) -> String:
	var value := text.strip_edges()
	if value.length() <= max_length:
		return value
	return "%s…" % value.substr(0, maxi(1, max_length - 1))
