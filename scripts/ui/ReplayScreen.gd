# 棋谱回放场景 —— 从主菜单进入
#
# 布局（三栏结构，播放面板在右上角不遮挡棋盘）：
#   - 左上角：返回主菜单按钮（悬浮，不占布局空间）
#   - 左侧：黑方得分板（显示执黑玩家名）
#   - 中央：棋盘视图（完整显示，不被遮挡）
#   - 右侧：播放控制面板（上） + 白方得分板（下）
extends Control

signal back_to_main_menu_requested

const SGFLoader = preload("res://scripts/core/SGFLoader.gd")

var _board_view: Control = null
var _session: GameSession = null
var _player_panel: Control = null
var _black_score_panel: Panel = null
var _white_score_panel: Panel = null
var _replay_moves: Array = []
var _replay_total_moves: int = 0
var _replay_score_history: Array = []
var _current_ply: int = 0
var _current_file: String = ""

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_log("场景启动 — 初始化棋谱回放场景")
	_build_ui()
	# 初始空棋盘（回放不受兵力限制：piece_limit=361 即 19×19 全盘上限）
	_session = GameSession.new(Const.KOMI_DEFAULT, false, 361)
	_board_view.set_session(_session)
	_black_score_panel.set_session(_session)
	_white_score_panel.set_session(_session)
	_log("初始空棋盘已创建，贴目=%.1f" % Const.KOMI_DEFAULT)
	# 延迟到下一帧加载棋谱，让场景先渲染第一帧（避免 80 秒卡死导致白屏）
	_log("场景就绪，延迟触发初始棋谱加载")
	call_deferred("_load_initial")

func _load_initial() -> void:
	_player_panel.load_initial_game()

# 日志缓冲（避免每步都做文件 IO 导致卡顿；最后一次性写入）
var _log_buffer: Array = []

# 统一日志输出（带 [REPLAY] 前缀，便于过滤；写入缓冲，最后统一落盘）
func _log(msg: String) -> void:
	var line := "[REPLAY] %s" % msg
	print(line)
	_log_buffer.append(line)

func _log_error(msg: String) -> void:
	var line := "[REPLAY][ERROR] %s" % msg
	print(line)
	_log_buffer.append(line)

# 把缓冲的日志一次性写入文件（在加载流程结束时调用）
func _flush_log() -> void:
	if _log_buffer.is_empty():
		return
	var f := FileAccess.open("user://replay_debug.log", FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open("user://replay_debug.log", FileAccess.WRITE)
	if f != null:
		f.seek_end()
		for line in _log_buffer:
			f.store_line(line)
	_log_buffer.clear()

func _build_ui() -> void:
	# 返回主菜单按钮（左上角悬浮，不占用布局空间）
	var back_btn := Button.new()
	back_btn.text = LocaleManager.L("replay.back")
	back_btn.set_anchors_preset(PRESET_TOP_LEFT)
	back_btn.offset_left = 12
	back_btn.offset_top = 8
	back_btn.offset_right = 152
	back_btn.offset_bottom = 40
	back_btn.add_theme_font_size_override("font_size", 13)
	back_btn.add_theme_color_override("font_color", UITheme.C_GOLD_DIM)
	back_btn.add_theme_color_override("font_hover_color", UITheme.C_GOLD_BRIGHT)
	back_btn.pressed.connect(func(): back_to_main_menu_requested.emit())
	add_child(back_btn)

	# 主布局：水平三栏 = [黑方得分板 | 中间棋盘区 | 白方得分板]
	# 顶部预留给返回按钮（高 32），底部贴边（播放面板在棋盘上方，下方无需空间）
	var main_row := HBoxContainer.new()
	main_row.set_anchors_preset(PRESET_FULL_RECT)
	main_row.offset_top = 44
	main_row.offset_bottom = 0
	main_row.offset_left = 12
	main_row.offset_right = -12
	main_row.add_theme_constant_override("separation", 8)
	add_child(main_row)

	# 左侧：黑方得分板（固定宽度，垂直撑满）
	_black_score_panel = preload("res://scripts/ui/ScorePanel.gd").new()
	_black_score_panel.set_side(Const.BLACK)
	_black_score_panel.custom_minimum_size = Vector2(260, 0)
	_black_score_panel.size_flags_vertical = SIZE_FILL
	_black_score_panel.set_controllable(false)
	main_row.add_child(_black_score_panel)

	# 中央：棋盘（整体居中）
	var center := VBoxContainer.new()
	center.size_flags_horizontal = SIZE_EXPAND_FILL
	center.size_flags_vertical = SIZE_EXPAND_FILL
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 6)
	main_row.add_child(center)

	_board_view = preload("res://scripts/ui/BoardView.gd").new()
	_board_view.size_flags_horizontal = SIZE_SHRINK_CENTER
	_board_view.size_flags_vertical = SIZE_SHRINK_CENTER
	center.add_child(_board_view)

	# 右侧：播放面板（上） + 白方得分板（下）
	var right_col := VBoxContainer.new()
	right_col.custom_minimum_size = Vector2(240, 0)
	right_col.size_flags_vertical = SIZE_FILL
	right_col.add_theme_constant_override("separation", 6)
	main_row.add_child(right_col)

	# 播放控制面板（右上角，竖向紧凑布局）
	_player_panel = preload("res://scripts/ui/GamePlayerPanel.gd").new()
	_player_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	_player_panel.size_flags_vertical = SIZE_SHRINK_BEGIN
	_player_panel.custom_minimum_size = Vector2(240, 150)
	# 信号连接必须在 add_child 之前（_ready 会在 add_child 时同步执行并 emit game_selected）
	_player_panel.move_requested.connect(_on_replay_jump)
	_player_panel.import_requested.connect(_on_import_sgf)
	_player_panel.game_selected.connect(_on_game_selected)
	_player_panel.closed.connect(_on_player_panel_closed)
	right_col.add_child(_player_panel)

	# 白方得分板（面板下方，垂直撑满剩余空间）
	_white_score_panel = preload("res://scripts/ui/ScorePanel.gd").new()
	_white_score_panel.set_side(Const.WHITE)
	_white_score_panel.size_flags_vertical = SIZE_EXPAND_FILL
	_white_score_panel.set_controllable(false)
	right_col.add_child(_white_score_panel)

func _on_game_selected(path: String) -> void:
	_log("下拉选择棋谱: %s" % path)
	_load_sgf_and_play(path)

func _on_import_sgf() -> void:
	_log("用户请求导入 SGF 文件 — 弹出文件对话框")
	var dlg := FileDialog.new()
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dlg.filters = PackedStringArray([LocaleManager.L("replay.sgf_filter")])
	dlg.use_native_dialog = true
	add_child(dlg)
	dlg.file_selected.connect(func(path: String):
		_log("用户选择导入文件: %s" % path)
		_load_sgf_and_play(path)
		dlg.queue_free()
	)
	dlg.canceled.connect(func():
		_log("用户取消导入文件对话框")
		dlg.queue_free()
	)
	dlg.popup_centered(Vector2i(640, 480))

func _load_sgf_and_play(path: String) -> void:
	_log("===== 开始加载 SGF 棋谱 =====")
	_log("文件路径: %s" % path)
	var t0: float = Time.get_ticks_msec()
	var parsed: Dictionary = SGFLoader.load_from_file(path)
	var t1: float = Time.get_ticks_msec()
	if not parsed.get("ok", false):
		_log_error("SGF 解析失败: %s (耗时 %.1fms)" % [parsed.get("error", ""), t1 - t0])
		return
	_replay_moves = parsed.moves
	_replay_total_moves = _replay_moves.size()
	if _replay_total_moves == 0:
		_log_error("棋谱无落子 (耗时 %.1fms)" % (t1 - t0))
		return
	_current_file = path
	# 输出棋谱元数据
	var pb: String = parsed.get("black_player", "?")
	var pw: String = parsed.get("white_player", "?")
	var re: String = parsed.get("result", "?")
	var dt: String = parsed.get("date", "?")
	var ev: String = parsed.get("event", "?")
	_log("解析成功 (耗时 %.1fms): 黑=%s | 白=%s | 结果=%s | 日期=%s | 赛事=%s | 手数=%d" % [
		t1 - t0, pb, pw, re, dt, ev, _replay_total_moves])
	# 得分板显示执黑/执白玩家名
	_black_score_panel.set_role_name(pb if pb != "?" else "")
	_white_score_panel.set_role_name(pw if pw != "?" else "")
	# 统计落子分布
	var black_count: int = 0
	var white_count: int = 0
	var pass_count: int = 0
	for mv in _replay_moves:
		if mv.pass:
			pass_count += 1
		elif mv.color == Const.BLACK:
			black_count += 1
		else:
			white_count += 1
	_log("落子分布: 黑=%d 白=%d 虚手=%d" % [black_count, white_count, pass_count])
	# 跳过预计算分数历史（分数图表已移除，且 222 手预计算耗时 ~80 秒会卡死界面）
	# 显示棋谱信息
	var info: Dictionary = {
		"black_player": parsed.get("black_player", ""),
		"white_player": parsed.get("white_player", ""),
		"result": parsed.get("result", ""),
		"date": parsed.get("date", ""),
		"event": parsed.get("event", ""),
		"total_moves": _replay_total_moves,
	}
	_player_panel.set_game_info(info)
	# 在下拉菜单中高亮当前棋谱
	_player_panel.select_game_by_path(path)
	# 跳到第 1 步（显示第一手棋，避免空棋盘让用户以为没反应）
	_log("跳转到第一手 (ply=1)")
	_jump_to_replay_ply(1)
	_log("===== SGF 棋谱加载完成 =====")
	_flush_log()

func _compute_replay_score_history() -> void:
	_replay_score_history = []
	var sim := GameSession.new(Const.KOMI_DEFAULT, false, 361)
	sim.emit_signals = false
	sim.skip_endgame = true
	sim.skip_pass_limits = true  # 旧棋谱不受虚手次数/连续限制（规则改动前的对局）
	var sc0: Dictionary = sim.scores()
	_replay_score_history.append({
		"black": sc0.black.total(),
		"white": sc0.white.total(),
	})
	var illegal_count: int = 0
	var prev_black: int = sc0.black.total()
	var prev_white: int = sc0.white.total()
	for i in _replay_moves.size():
		var mv: Dictionary = _replay_moves[i]
		var ply_num: int = i + 1
		if sim.game_over:
			sim.game_over = false
			sim.consecutive_passes = 0
		if mv.pass:
			sim.do_pass(mv.color)
		else:
			var out = sim.play_move(mv.color, mv.pos.y, mv.pos.x)
			if not out.ok:
				illegal_count += 1
				# 仅记录，不每步输出（避免日志过多）；最后汇总
			else:
				if out.captures.size() > 0:
					_log("  ply=%d %s (%d,%d) 提子 %d 枚" % [
						ply_num, "黑" if mv.color == Const.BLACK else "白",
						mv.pos.y, mv.pos.x, out.captures.size()])
		var sc: Dictionary = sim.scores()
		var cur_black: int = sc.black.total()
		var cur_white: int = sc.white.total()
		# 仅每 20 步输出一次采样日志，减少日志量
		if ply_num % 20 == 0:
			_log("  ply=%d 分数: 黑=%d 白=%d" % [ply_num, cur_black, cur_white])
		prev_black = cur_black
		prev_white = cur_white
		_replay_score_history.append({
			"black": cur_black,
			"white": cur_white,
		})
	if illegal_count > 0:
		_log_error("预计算完成: 共 %d 个非法手被跳过 (占总手数 %.1f%%)" % [
			illegal_count, 100.0 * illegal_count / _replay_moves.size()])
	else:
		_log("预计算完成: 所有手数合法，无跳过")

func _on_replay_jump(ply: int) -> void:
	_jump_to_replay_ply(ply)

func _jump_to_replay_ply(ply: int) -> void:
	# 边界裁剪
	var target: int = clamp(ply, 0, _replay_total_moves)
	ply = target
	# 增量优化：若是单步前进（ply == _current_ply + 1），直接在现有 session 上走一步，
	# 避免重置整个 session 重放所有手（O(n²) → O(1)）
	if ply == _current_ply + 1 and ply <= _replay_total_moves:
		_step_forward()
		return
	# 任意跳转：重置 session，重放前 ply 手（回放不受兵力限制，piece_limit=361）
	_session = GameSession.new(Const.KOMI_DEFAULT, false, 361)
	# 禁用信号发射，跳过每步的 scores() 计算（性能优化：222 手从 74s → <1s）
	_session.emit_signals = false
	# 跳过 do_pass 的终局判定（避免 _both_cannot_move 的 O(N⁴) 遍历和 final_result 终局结算）
	_session.skip_endgame = true
	# 旧棋谱不受虚手次数/连续限制（规则改动前的对局）
	_session.skip_pass_limits = true
	_board_view.set_session(_session)
	_black_score_panel.set_session(_session)
	_white_score_panel.set_session(_session)
	for i in min(ply, _replay_total_moves):
		var mv: Dictionary = _replay_moves[i]
		# 回放中若上一手触发了终局（双方连续虚手），重置 game_over 以允许继续回放
		# 同时重置 consecutive_passes，避免后续 pass 重复触发终局判定
		if _session.game_over:
			_session.game_over = false
			_session.consecutive_passes = 0
		if mv.pass:
			_session.do_pass(mv.color)
		else:
			_session.play_move(mv.color, mv.pos.y, mv.pos.x)
	# 恢复信号发射，以便 _update_view_after_jump 中的 scores() 能正常工作
	_session.emit_signals = true
	_current_ply = ply
	# 更新得分板与视图
	_update_view_after_jump(ply)

# 单步前进：在现有 session 上走一步，不重置（性能关键路径）
func _step_forward() -> void:
	var ply: int = _current_ply + 1
	if ply > _replay_total_moves:
		return
	var mv: Dictionary = _replay_moves[ply - 1]
	# 回放中若上一手触发了终局（双方连续虚手），重置 game_over 以允许继续回放
	# 同时重置 consecutive_passes，避免后续 pass 重复触发终局判定
	if _session.game_over:
		_session.game_over = false
		_session.consecutive_passes = 0
	# 禁用信号发射，跳过 scores() 计算（_update_view_after_jump 会手动调用一次）
	_session.emit_signals = false
	# 跳过 do_pass 的终局判定（同 _jump_to_replay_ply）
	_session.skip_endgame = true
	# 旧棋谱不受虚手次数/连续限制（规则改动前的对局）
	_session.skip_pass_limits = true
	if mv.pass:
		_session.do_pass(mv.color)
	else:
		_session.play_move(mv.color, mv.pos.y, mv.pos.x)
	_session.emit_signals = true
	_current_ply = ply
	_update_view_after_jump(ply)

# 跳转后统一更新视图与得分板
func _update_view_after_jump(ply: int) -> void:
	var sc: Dictionary = _session.scores()
	# 更新得分板分数（不重置 session，避免动画闪烁）
	_black_score_panel.on_scores_changed(sc)
	_white_score_panel.on_scores_changed(sc)
	# 更新棋盘视图
	var outcome: Dictionary = {
		"placed": Vector2i(-1, -1),
		"captures": [],
		"bounced": false,
		"deployed": false,
		"passed": false,
		"type": "replay_jump",
	}
	if ply > 0:
		var last_mv: Dictionary = _replay_moves[ply - 1]
		if not last_mv.pass:
			outcome.placed = last_mv.pos
	_board_view.on_move_committed(outcome)
	_board_view.queue_redraw()
	_player_panel.set_current_ply(ply)

func _on_player_panel_closed() -> void:
	# 棋谱回放场景中不关闭面板（保持可用）
	# 仅停止播放
	pass

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				_log("ESC 键 — 返回主菜单")
				back_to_main_menu_requested.emit()
				get_viewport().set_input_as_handled()
			KEY_LEFT:
				if _replay_total_moves > 0:
					_log("← 键 — 上一手 (ply %d → %d)" % [_current_ply, _current_ply - 1])
					_jump_to_replay_ply(_current_ply - 1)
				get_viewport().set_input_as_handled()
			KEY_RIGHT:
				if _replay_total_moves > 0:
					_log("→ 键 — 下一手 (ply %d → %d)" % [_current_ply, _current_ply + 1])
					_jump_to_replay_ply(_current_ply + 1)
				get_viewport().set_input_as_handled()
