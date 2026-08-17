# 终局结果浮层 —— 胜利方结算动画
#
# 设计：
#   - 全屏遮罩淡入 + 金色光晕扩散
#   - 中央对话框：缩放进场 + 边框金色脉冲
#   - 胜方信息：大字号胜方名 + 棋色指示圆 + 原因
#   - 分数对比：黑/白总分对比柱状条
#   - 按钮：再来一局 / 返回主菜单
#   - 错峰动画：遮罩→对话框→胜方标题→分数→按钮
extends Control

signal new_game_requested
signal back_to_main_menu_requested
signal dismissed

var _overlay: ColorRect = null
var _dialog: Panel = null
var _winner_label: Label = null
var _winner_circle: Control = null
var _reason_label: Label = null
var _score_view: Control = null
var _btn_row: HBoxContainer = null
var _result: Dictionary = {}

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

static func create(result: Dictionary) -> Control:
	var inst := preload("res://scripts/ui/ResultOverlay.gd").new()
	inst._result = result
	inst._build()
	return inst

func _build() -> void:
	# 胜方颜色：优先用 result["winner_color"]（语言无关）；旧结果兜底用中文匹配
	var winner_color: int = _result.get("winner_color", -1)
	if winner_color < 0:
		var winner_str_legacy: String = _result.get("winner", "和棋")
		if winner_str_legacy.find("黑") >= 0:
			winner_color = Const.BLACK
		elif winner_str_legacy.find("白") >= 0:
			winner_color = Const.WHITE
	var winner_text: String = LocaleManager.L("result.win_black") if winner_color == Const.BLACK \
		else (LocaleManager.L("result.win_white") if winner_color == Const.WHITE else LocaleManager.L("result.draw"))

	# 遮罩（更深，突出胜利时刻）
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(PRESET_FULL_RECT)
	_overlay.color = Color(0, 0, 0, 0.0)
	add_child(_overlay)

	# 胜方金色光晕（背景）
	_glow_layer = Control.new()
	_glow_layer.set_anchors_preset(PRESET_FULL_RECT)
	_glow_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow_layer.draw.connect(_draw_glow.bind(_glow_layer, winner_color))
	add_child(_glow_layer)

	# 居中容器
	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center)

	_dialog = Panel.new()
	_dialog.custom_minimum_size = Vector2(480, 360)
	var sb := StyleBoxFlat.new()
	sb.corner_detail = 1
	sb.bg_color = Color(0.04, 0.03, 0.05, 0.97)
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	sb.border_color = UITheme.C_GOLD if winner_color >= 0 else UITheme.C_GOLD_DIM
	_dialog.add_theme_stylebox_override("panel", sb)
	center.add_child(_dialog)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.offset_left = 28
	vbox.offset_right = -28
	vbox.offset_top = 24
	vbox.offset_bottom = -24
	vbox.add_theme_constant_override("separation", 16)
	_dialog.add_child(vbox)

	# 顶部：胜方标题行（圆 + 文字）
	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 14)
	vbox.add_child(title_row)

	# 胜方棋色圆
	_winner_circle = Control.new()
	_winner_circle.custom_minimum_size = Vector2(32, 32)
	_winner_circle.draw.connect(_draw_winner_circle.bind(_winner_circle, winner_color))
	title_row.add_child(_winner_circle)

	_winner_label = Label.new()
	_winner_label.text = winner_text
	_winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_winner_label.add_theme_font_size_override("font_size", 42)
	_winner_label.add_theme_color_override("font_color", UITheme.C_GOLD_BRIGHT if winner_color >= 0 else UITheme.C_TEXT)
	title_row.add_child(_winner_label)

	# 原因（core 层终局原因可能为中文，按当前语言翻译）
	var reason_str: String = LocaleManager.translate_reason(_result.get("reason", ""))
	_reason_label = Label.new()
	_reason_label.text = reason_str
	_reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reason_label.add_theme_font_size_override("font_size", 16)
	_reason_label.add_theme_color_override("font_color", UITheme.C_TEXT_DIM)
	vbox.add_child(_reason_label)

	# 分隔线
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	vbox.add_child(sep)

	# 分数对比视图
	_score_view = Control.new()
	_score_view.custom_minimum_size = Vector2(0, 90)
	_score_view.draw.connect(_draw_score_comparison.bind(_score_view))
	vbox.add_child(_score_view)

	# 按钮行
	_btn_row = HBoxContainer.new()
	_btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(_btn_row)

	var again_btn := _make_button(LocaleManager.L("result.play_again"))
	again_btn.pressed.connect(func():
		new_game_requested.emit()
		queue_free()
	)
	_btn_row.add_child(again_btn)

	var menu_btn := _make_button(LocaleManager.L("result.back_to_main"))
	menu_btn.pressed.connect(func():
		back_to_main_menu_requested.emit()
		queue_free()
	)
	_btn_row.add_child(menu_btn)

	# 初始状态：所有元素隐藏
	_overlay.color.a = 0.0
	_glow_layer.modulate.a = 0.0
	_dialog.modulate.a = 0.0
	_dialog.scale = Vector2(0.7, 0.7)
	_winner_label.modulate.a = 0.0
	_reason_label.modulate.a = 0.0
	_score_view.modulate.a = 0.0
	_btn_row.modulate.a = 0.0

	_play_entrance(winner_color)

var _glow_layer: Control = null

# 绘制胜方金色光晕（v: 触发绘制的节点 = _glow_layer）
func _draw_glow(v: Control, winner_color: int) -> void:
	if winner_color < 0:
		return
	var center_pos: Vector2 = v.size * 0.5
	var max_r: float = max(v.size.x, v.size.y) * 0.7
	var glow_color: Color = Color(1.0, 0.85, 0.3, 0.15)
	# 多层径向渐变（用同心圆模拟）
	for i in 8:
		var r: float = max_r * (1.0 - i / 8.0)
		var a: float = 0.04 * (1.0 - i / 8.0)
		v.draw_arc(center_pos, r, 0, TAU, 48, Color(glow_color.r, glow_color.g, glow_color.b, a), 12.0)

# 绘制胜方棋色圆（v: 触发绘制的节点 = _winner_circle）
func _draw_winner_circle(v: Control, winner_color: int) -> void:
	var center_pos: Vector2 = v.size * 0.5
	var r: float = min(v.size.x, v.size.y) * 0.45
	if winner_color == Const.BLACK:
		v.draw_circle(center_pos, r, Color(0.08, 0.08, 0.08, 1.0))
		v.draw_arc(center_pos, r, 0, TAU, 32, UITheme.C_GOLD, 2.0)
	elif winner_color == Const.WHITE:
		v.draw_circle(center_pos, r, Color(0.95, 0.95, 0.95, 1.0))
		v.draw_arc(center_pos, r, 0, TAU, 32, UITheme.C_GOLD, 2.0)
	else:
		# 和棋：金色空心圆
		v.draw_arc(center_pos, r, 0, TAU, 32, UITheme.C_GOLD_DIM, 2.0)

# 绘制分数对比柱状条（v: 触发绘制的节点 = _score_view）
func _draw_score_comparison(v: Control) -> void:
	if _result.is_empty():
		return
	var w: float = v.size.x
	var h: float = v.size.y
	if w <= 0 or h <= 0:
		return
	# 提取分数
	var black_total: float = float(_result.get("black_total", 0))
	var white_total: float = float(_result.get("white_total", 0))
	# 兼容旧字段
	if _result.has("black") and _result.black is Dictionary:
		black_total = float(_result.black.get("final", _result.black.get("total", 0)))
	if _result.has("white") and _result.white is Dictionary:
		white_total = float(_result.white.get("final", _result.white.get("total", 0)))
	var max_score: float = max(max(black_total, white_total), 1.0)
	# 布局参数
	var bar_h: float = 22.0
	var bar_w: float = w * 0.55
	var bar_x: float = (w - bar_w) * 0.5
	var black_y: float = h * 0.25
	var white_y: float = h * 0.65
	# 黑方条
	var black_w: float = bar_w * (black_total / max_score) if black_total > 0 else 0
	v.draw_rect(Rect2(Vector2(bar_x, black_y), Vector2(bar_w, bar_h)), Color(0.15, 0.12, 0.08, 0.6), true)
	if black_w > 0:
		v.draw_rect(Rect2(Vector2(bar_x, black_y), Vector2(black_w, bar_h)), Color(0.2, 0.15, 0.05, 0.95), true)
	v.draw_rect(Rect2(Vector2(bar_x, black_y), Vector2(bar_w, bar_h)), UITheme.C_GOLD_DIM, false, 1.0)
	# 黑方标签
	var black_short: String = LocaleManager.L("result.color_black_short")
	var white_short: String = LocaleManager.L("result.color_white_short")
	v.draw_string(_default_font(), Vector2(bar_x - 4, black_y + bar_h * 0.75), black_short,
		HORIZONTAL_ALIGNMENT_RIGHT, -1, 14, UITheme.C_GOLD)
	v.draw_string(_default_font(), Vector2(bar_x + bar_w + 8, black_y + bar_h * 0.75), "%.1f" % black_total,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UITheme.C_GOLD)
	# 白方条
	var white_w: float = bar_w * (white_total / max_score) if white_total > 0 else 0
	v.draw_rect(Rect2(Vector2(bar_x, white_y), Vector2(bar_w, bar_h)), Color(0.15, 0.12, 0.08, 0.6), true)
	if white_w > 0:
		v.draw_rect(Rect2(Vector2(bar_x, white_y), Vector2(white_w, bar_h)), Color(0.85, 0.85, 0.85, 0.7), true)
	v.draw_rect(Rect2(Vector2(bar_x, white_y), Vector2(bar_w, bar_h)), UITheme.C_GOLD_DIM, false, 1.0)
	# 白方标签
	v.draw_string(_default_font(), Vector2(bar_x - 4, white_y + bar_h * 0.75), white_short,
		HORIZONTAL_ALIGNMENT_RIGHT, -1, 14, Color(0.9, 0.9, 0.9))
	v.draw_string(_default_font(), Vector2(bar_x + bar_w + 8, white_y + bar_h * 0.75), "%.1f" % white_total,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.9, 0.9))

func _default_font() -> Font:
	return ThemeDB.fallback_font

func _make_button(label: String) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(160, 42)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", UITheme.C_GOLD)
	b.add_theme_color_override("font_hover_color", UITheme.C_GOLD_BRIGHT)
	var sb_n := StyleBoxFlat.new()
	sb_n.corner_detail = 1
	sb_n.border_width_left = 2
	sb_n.border_width_right = 2
	sb_n.border_width_top = 2
	sb_n.border_width_bottom = 2
	sb_n.bg_color = Color(0.04, 0.03, 0.02, 0.9)
	sb_n.border_color = UITheme.C_GOLD_DIM
	var sb_h := sb_n.duplicate()
	sb_h.border_color = UITheme.C_GOLD
	sb_h.bg_color = Color(0.10, 0.08, 0.05, 0.95)
	b.add_theme_stylebox_override("normal", sb_n)
	b.add_theme_stylebox_override("hover", sb_h)
	b.add_theme_stylebox_override("pressed", sb_h)
	b.mouse_entered.connect(func(): UITheme.animate_button_hover(b, true))
	b.mouse_exited.connect(func(): UITheme.animate_button_hover(b, false))
	return b

# 错峰入场动画
func _play_entrance(winner_color: int) -> void:
	# 1. 遮罩淡入
	var t1 := _overlay.create_tween()
	t1.set_ease(Tween.EASE_OUT)
	t1.set_trans(Tween.TRANS_CUBIC)
	t1.tween_property(_overlay, "color:a", 0.75, 0.4)
	# 2. 光晕淡入
	var t2 := _glow_layer.create_tween()
	t2.set_ease(Tween.EASE_OUT)
	t2.set_trans(Tween.TRANS_CUBIC)
	t2.tween_interval(0.1)
	t2.tween_property(_glow_layer, "modulate:a", 1.0, 0.6)
	# 3. 对话框缩放进场
	var t3 := _dialog.create_tween()
	t3.set_ease(Tween.EASE_OUT)
	t3.set_trans(Tween.TRANS_BACK)
	t3.tween_interval(0.2)
	t3.tween_property(_dialog, "modulate:a", 1.0, 0.4)
	t3.parallel().tween_property(_dialog, "scale", Vector2(1.0, 1.0), 0.5)
	# 4. 胜方标题（缩放 + 淡入）
	_winner_label.scale = Vector2(0.5, 0.5)
	var t4 := _winner_label.create_tween()
	t4.set_ease(Tween.EASE_OUT)
	t4.set_trans(Tween.TRANS_BACK)
	t4.tween_interval(0.5)
	t4.tween_property(_winner_label, "modulate:a", 1.0, 0.3)
	t4.parallel().tween_property(_winner_label, "scale", Vector2(1.0, 1.0), 0.4)
	# 5. 原因
	var t5 := _reason_label.create_tween()
	t5.set_ease(Tween.EASE_OUT)
	t5.set_trans(Tween.TRANS_CUBIC)
	t5.tween_interval(0.7)
	t5.tween_property(_reason_label, "modulate:a", 1.0, 0.3)
	# 6. 分数对比
	var t6 := _score_view.create_tween()
	t6.set_ease(Tween.EASE_OUT)
	t6.set_trans(Tween.TRANS_CUBIC)
	t6.tween_interval(0.9)
	t6.tween_property(_score_view, "modulate:a", 1.0, 0.4)
	# 7. 按钮
	var t7 := _btn_row.create_tween()
	t7.set_ease(Tween.EASE_OUT)
	t7.set_trans(Tween.TRANS_CUBIC)
	t7.tween_interval(1.1)
	t7.tween_property(_btn_row, "modulate:a", 1.0, 0.3)
	# 8. 胜方边框脉冲（循环）
	if winner_color >= 0:
		var pulse := _dialog.create_tween()
		pulse.set_loops()
		pulse.tween_property(_dialog, "modulate", Color(1.08, 1.04, 0.95, 1.0), 1.2)
		pulse.tween_property(_dialog, "modulate", Color(1.0, 1.0, 1.0, 1.0), 1.2)

# ESC 关闭（仅终局时 ESC 视为返回主菜单）
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			dismissed.emit()
			queue_free()
			get_viewport().set_input_as_handled()
