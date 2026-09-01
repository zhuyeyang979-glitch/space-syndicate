extends "res://scripts/ui/v073/v073_sample_card_button.gd"
class_name V074TrackCardButton

const TRACK_HOVER_SCALE := Vector2(1.025, 1.025)

var _track_hover_tween: Tween


func _init() -> void:
	super._init()
	custom_minimum_size = Vector2(96.0, 106.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func configure(
	payload: Dictionary,
	title_text: String,
	meta_text: String,
	art_texture: Texture2D,
	accent_color: Color,
	badge_text: String = ""
) -> void:
	super.configure(
		payload,
		title_text,
		meta_text,
		art_texture,
		accent_color,
		badge_text
	)
	var kind := str(payload.get("card_kind", "normal_card"))
	var claimable := bool(payload.get("claimable", false))
	var claimability_state := str(payload.get("claimability_state", ""))
	var affordance := (
		"点击后在固定行动区确认；手牌满也可取得并进入弃牌"
		if kind == "normal_card"
		else "点击后在固定行动区确认并进入商品库存"
	)
	# Claimability is a player-facing decision, not a tooltip-only diagnostic.
	# Keep the owner/segment identity private while making the legal opportunity
	# legible on the card face itself.
	if kind == "commodity_card":
		_meta.text = (
			"可取得 · 点击后确认 · 商品库存"
			if claimable
			else "交接后解锁 · 商品库存"
		)
		_badge.text = "COMMODITY · 可取得" if claimable else "COMMODITY · 等待交接"
		_badge.add_theme_color_override(
			"font_color",
			Color("#86efac") if claimable else Color("#94a3b8")
		)
		set_meta("human_claimability_label", "可取得" if claimable else "交接后解锁")
		set_meta("claimability_state", claimability_state)
	else:
		set_meta("human_claimability_label", "可取得" if claimable else "不可取得")
		set_meta("claimability_state", claimability_state)
	if not claimable:
		var reason_code := str(payload.get(
			"public_claim_disabled_reason",
			"track_item_not_claimable"
		))
		var reason_text := {
			"track_item_not_claimable": "等待共享轨滚动或合法报价",
			"insufficient_assets": "对应颜色资产不足",
			"commodity_slot_unavailable": "商品库存槽位已满",
		}.get(reason_code, "等待合法窗口") as String
		affordance = "当前不可取得 · %s" % reason_text
	tooltip_text = "%s\n%s\n%s" % [title_text, _meta.text, affordance]


func _animate_scale(target: Vector2) -> void:
	if _track_hover_tween != null and _track_hover_tween.is_valid():
		_track_hover_tween.kill()
	var resolved := (
		Vector2.ONE
		if target == Vector2.ONE
		else TRACK_HOVER_SCALE
	)
	_track_hover_tween = create_tween()
	_track_hover_tween.set_trans(Tween.TRANS_QUAD)
	_track_hover_tween.set_ease(Tween.EASE_OUT)
	_track_hover_tween.tween_property(self, "scale", resolved, 0.1)
