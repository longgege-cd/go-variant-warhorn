# 国际化管理：负责加载/切换语言，提供 tr() 等价的本地化字符串查询
#
# 设计：
#   - 两个翻译表（中文/英文）直接以 Dictionary 形式存储在脚本中，避免外部 CSV/.translation 资源导入
#   - 启动时读取持久化配置（user://settings.cfg）决定语言；默认中文
#   - 切换语言后 emit locale_changed 信号，UI 监听后重新渲染
#   - 字符串查询统一用 L(key, args?) 辅助函数（兼容格式化参数）
extends Node

signal locale_changed(new_locale: String)

const LOCALE_ZH: String = "zh"
const LOCALE_EN: String = "en"

var current_locale: String = LOCALE_ZH

# 翻译表：key -> {locale -> 翻译文本}
# 新增翻译键时只需在此字典添加一项，无需重启编辑器
var _translations: Dictionary = {}
# 行棋拒绝原因翻译表：key = core 层返回的中文 reason 原文，value = 英文翻译
var _reason_translations: Dictionary = {}

# 格式化参数占位符映射（GDScript 不支持 {n} 直接格式化，需手工替换）
# 占位符约定：{0} {1} {2} ... 位置参数；{name} 命名参数
func _ready() -> void:
	_init_translations()
	_load_from_config()

# 查询翻译文本；fallback 为未命中时的兜底（默认返回 key 本身）
func L(key: String, args: Dictionary = {}) -> String:
	var entry: Dictionary = _translations.get(key, {})
	var text: String = entry.get(current_locale, entry.get(LOCALE_ZH, key))
	if args.is_empty():
		return text
	# 替换命名占位符 {name}
	for k in args:
		text = text.replace("{%s}" % k, str(args[k]))
	return text

# 翻译行棋拒绝原因：core 层（GameSession/GoRules）返回中文 reason，
# 由 UI 层按当前语言翻译后显示；带参数原因（虚手冷却/弹子点非法）用前缀规则提取。
func translate_reason(text: String) -> String:
	if current_locale == LOCALE_ZH:
		return text
	# 1. 整句查表
	if _reason_translations.has(text):
		return _reason_translations[text]
	# 2. 虚手冷却带参数：虚手冷却中（还需 N 个己方回合）
	const PASS_PREFIX: String = "虚手冷却中（还需 "
	if text.begins_with(PASS_PREFIX):
		var n: int = int(text.substr(PASS_PREFIX.length()).get_slice(" 个己方回合）", 0))
		return "Pass cooldown (%d of your own turns needed)" % n
	# 3. 弹子点意外非法: <原因>
	const BOUNCE_PREFIX: String = "弹子点意外非法: "
	if text.begins_with(BOUNCE_PREFIX):
		return "Unexpected illegal bounce point: " + translate_reason(text.substr(BOUNCE_PREFIX.length()))
	return text

# 切换语言；同语言不触发信号
func set_locale(locale: String) -> void:
	if locale == current_locale:
		return
	if locale != LOCALE_ZH and locale != LOCALE_EN:
		return
	current_locale = locale
	_save_to_config()
	locale_changed.emit(locale)

# 切换到另一种语言（菜单按钮使用）
func toggle_locale() -> void:
	set_locale(LOCALE_EN if current_locale == LOCALE_ZH else LOCALE_ZH)

# 从 user://settings.cfg 读取语言偏好
func _load_from_config() -> void:
	var cfg := ConfigFile.new()
	var err: int = cfg.load("user://settings.cfg")
	if err == OK and cfg.has_section_key("ui", "locale"):
		var saved: String = cfg.get_value("ui", "locale", LOCALE_ZH)
		if saved == LOCALE_EN or saved == LOCALE_ZH:
			current_locale = saved

# 保存语言偏好到 user://settings.cfg
func _save_to_config() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")  # 加载已有配置（忽略错误）
	cfg.set_value("ui", "locale", current_locale)
	cfg.save("user://settings.cfg")

# ===== 翻译键值表 =====
# 命名规范：<模块>.<场景>.<条目>，如 main_menu.title、game.pass_btn、result.win_black
# 含占位符的用 {name} 标注，如 {n}、{winner}、{ip}
# 新增翻译键时务必同时填写中英文，避免 fallback 到 key
func _init_translations() -> void:
	# ===== 主菜单 / 启动菜单 =====
	_add("main_menu.app_title", "战争号角", "War Horn")
	_add("main_menu.app_subtitle", "边境线", "Borderline")
	_add("main_menu.app_tagline", "受围棋启发的双人回合制战略棋类", "A Go-inspired two-player turn-based strategy game")
	_add("main_menu.start", "开 始 对 局", "Start Game")
	_add("main_menu.replay", "棋 谱 回 放", "Replay")
	_add("main_menu.tutorial", "规 则 教 程", "Tutorial")
	_add("main_menu.theme_switch", "切换主题", "Switch Theme")
	_add("main_menu.exit", "退出", "Exit")
	_add("main_menu.thinking_time", "思考时间", "Thinking Time")
	_add("main_menu.amateur", "业 余", "Amateur")
	_add("main_menu.professional", "专 业", "Professional")
	_add("main_menu.komi", "贴  目", "Komi")
	_add("main_menu.komi_unit", "目", "pt")
	_add("main_menu.komi_value", "{n} 目", "{n} pt")
	_add("main_menu.forces", "兵  力", "Forces")
	_add("main_menu.forces_unit", "子", "stones")
	_add("main_menu.forces_value", "{n} 子", "{n} stones")
	_add("main_menu.difficulty_label", "选择 AI 难度", "AI Difficulty")
	_add("main_menu.back", "返 回", "Back")
	_add("main_menu.time_unlimited", "无限制", "Unlimited")
	_add("main_menu.time_blitz", "闪电5分", "Blitz 5m")
	_add("main_menu.time_rapid", "快棋15分+30秒×3", "Rapid 15m+30s×3")
	_add("main_menu.time_standard", "标准30分+30秒×3", "Standard 30m+30s×3")
	_add("main_menu.time_amateur_long", "业余60分+30秒×5", "Amateur 60m+30s×5")
	_add("main_menu.time_pro_rapid", "快棋赛1h+30秒×5", "Pro Rapid 1h+30s×5")
	_add("main_menu.time_pro_normal", "普通赛3h+60秒×5", "Pro Normal 3h+60s×5")
	_add("main_menu.time_pro_grand", "大赛5h+60秒×5", "Pro Grand 5h+60s×5")
	_add("main_menu.time_pro_title", "头衔战8h+60秒×10", "Title Match 8h+60s×10")
	_add("main_menu.language", "语言", "Language")
	_add("main_menu.lang_zh", "中文", "中文")
	_add("main_menu.lang_en", "English", "English")
	# ===== 模式条目（主菜单列表）=====
	_add("mode.pvp", "本地双人", "Local 2-Player")
	_add("mode.pvp_desc", "同一屏幕对弈", "Play on the same screen")
	_add("mode.pve", "人机对战", "vs AI")
	_add("mode.pve_desc", "选择 AI 难度", "Choose AI difficulty")
	_add("mode.online", "联机对战", "Online Battle")
	_add("mode.online_desc", "主机或加入", "Host or join")

	# ===== 控制面板（棋盘下方按钮）=====
	_add("control.undo", "悔 棋 (U)", "Undo (U)")
	_add("control.pass", "虚 手 (P)", "Pass (P)")
	_add("control.resign", "认 输 (R)", "Resign (R)")
	_add("control.menu", "≡ 设 置 (ESC)", "≡ Menu (ESC)")
	_add("control.new_game", "新局", "New")
	_add("control.deploy", "部署(S)", "Deploy (S)")
	_add("control.theme", "主题(T)", "Theme (T)")
	_add("control.local_2p", "双人", "2P")
	_add("control.online", "联机…", "Online…")
	_add("control.exit_online", "退出联机", "Exit Online")
	_add("control.cancel_deploy", "取消部署", "Cancel Deploy")
	_add("control.mode_med", "中等", "Medium")

	# ===== 暂停菜单 =====
	_add("pause.title_settings", "—— 设  置 ——", "—— Settings ——")
	_add("pause.resume", "继 续 游 戏", "Resume")
	_add("pause.new_game", "新  对  局", "New Game")
	_add("pause.resign", "认      输", "Resign")
	_add("pause.deploy_special", "部 署 特 种 (S)", "Deploy Special (S)")
	_add("pause.title_mode", "—— 对战模式 ——", "—— Game Mode ——")
	_add("pause.local_2p", "本 地 双 人", "Local 2-Player")
	_add("pause.online", "联 机 对 战 …", "Online…")
	_add("pause.exit_online", "退出联机", "Exit Online")
	_add("pause.theme_switch", "切 换 主 题 (T)", "Switch Theme (T)")
	_add("pause.back_to_main", "返 回 主 菜 单", "Back to Main Menu")
	_add("pause.exit_game", "退 出 游 戏", "Exit Game")
	_add("pause.press_esc", "按 ESC 继续", "Press ESC to continue")
	_add("pause.mode_easy", "简  单", "Easy")
	_add("pause.mode_med", "中  等", "Medium")
	_add("pause.mode_hard", "困  难", "Hard")

	# ===== AI 难度 =====
	_add("ai.easy", "简单", "Easy")
	_add("ai.normal", "普通", "Normal")
	_add("ai.hard", "困难", "Hard")
	_add("ai.expert", "专家", "Expert")
	_add("ai.master", "大师", "Master")
	_add("ai.unknown", "未知", "Unknown")
	_add("ai.easy_desc", "只看当前手评分", "Heuristic only")
	_add("ai.normal_desc", "浅层搜索", "Shallow search")
	_add("ai.hard_desc", "标准搜索", "Standard search")
	_add("ai.expert_desc", "标准搜索+关键局面MCTS", "Search + MCTS on key positions")
	_add("ai.master_desc", "更深搜索+更多模拟", "Deeper search + more simulations")

	# ===== 对局内消息（GameScreen）=====
	_add("game.deploying", "正在布局", "Deploying…")
	_add("game.start_black", "对局开始 · 您执黑方 · 第 1 手", "Game start · You are Black · Move 1")
	_add("game.start_white", "对局开始 · 您执白方 · 第 1 手", "Game start · You are White · Move 1")
	_add("game.not_your_turn", "非您的回合", "Not your turn")
	_add("game.deploy_phase_no_pass", "布局阶段请先完成布局落子", "Complete deployment before passing")
	_add("game.deploy_phase_no_resign", "布局阶段无法认输", "Cannot resign during deployment")
	_add("game.deploy_phase_no_deploy", "布局阶段暂不能部署特种部队", "Cannot deploy special forces during deployment")
	_add("game.deploy_phase_no_undo", "布局阶段暂不支持悔棋", "Undo not available during deployment")
	_add("game.deploy_zone_error", "布局阶段只能在己方领土落子", "Deploy only in your own territory")
	_add("game.online_no_undo", "联机模式不支持悔棋", "Undo not available in online mode")
	_add("game.ai_thinking", "AI 思考中，请稍候", "AI is thinking, please wait")
	_add("game.no_undo_history", "无可悔棋历史", "No moves to undo")
	_add("game.undone_n_moves", "已悔棋 {n} 手", "Undone {n} move(s)")
	_add("game.exit_online_mode", "已退出联机模式", "Exited online mode")
	_add("game.opponent_disconnected", "对手已断开，等待新对手加入…", "Opponent disconnected, waiting for new opponent…")
	_add("game.opponent_disconnect_reason", "对手断开连接", "Opponent disconnected")
	_add("game.waiting_host_start", "等待主机开始新对局…", "Waiting for host to start new game…")
	_add("game.connected_waiting", "已连接 {ip}:{port}，等待主机开始游戏…", "Connected to {ip}:{port}, waiting for host to start…")
	_add("game.room_created", "已创建房间（端口 {port}），等待对手加入…", "Room created (port {port}), waiting for opponent…")
	_add("game.room_canceled", "已取消房间", "Room canceled")
	_add("game.room_broadcast_failed", "房间广播失败（端口 5006 可能被占用），对手可能搜索不到您的房间", "Room broadcast failed (port 5006 may be occupied); opponents may not find your room")
	_add("game.room_host_failed", "建主失败（端口 {port} 可能被占用）", "Host failed (port {port} may be occupied)")
	_add("game.room_hosted", "已建主（端口 {port}），等待对手加入…", "Hosting (port {port}), waiting for opponent…")
	_add("game.join_failed", "加入失败，请检查 IP/端口", "Join failed, check IP/port")
	_add("game.connecting", "正在连接 {ip}:{port}…", "Connecting to {ip}:{port}…")
	_add("game.peer_joined_ready", "对手已加入，点击「开始游戏」开始对局", "Opponent joined! Click 'Start Game' to begin")
	_add("game.connected_to_host", "已连接主机，等待主机开始游戏…", "Connected to host, waiting for game to start…")
	_add("game.host_disconnected", "主机已断开连接", "Host disconnected")
	_add("game.host_disconnect_reason", "主机断开连接", "Host disconnected")
	_add("game.connection_failed", "连接失败", "Connection failed")
	_add("game.connection_closed", "连接已关闭", "Connection closed")
	_add("game.new_game_started_white", "新对局开始（贴目 {komi}）· 您执白方", "New game (komi {komi}) · You are White")
	_add("game.sync_mismatch", "状态同步异常，请双方重新开始对局", "State sync mismatch, please restart the game")
	_add("game.ai_role_prefix", "AI·", "AI·")
	_add("game.select_deploy_pos", "选择部署特种部队的位置（点击棋盘）", "Select deployment position (click board)")
	_add("game.deploy_canceled", "已取消部署", "Deployment canceled")
	_add("game.player_you", "你", "You")
	_add("game.player_opponent", "对手", "Opponent")
	_add("game.color_black", "黑方", "Black")
	_add("game.color_white", "白方", "White")
	_add("game.score_annihilate", "歼灭 +{n}", "Annihilate +{n}")
	_add("game.score_loss", "战损 -{n}", "Loss -{n}")
	_add("game.score_territory", "围空 +{n}", "Territory +{n}")
	_add("game.score_territory_loss", "围空 -{n}", "Territory -{n}")
	_add("game.score_siege", "围困 +{n}", "Siege +{n}")
	_add("game.score_siege_victim", "活子 -{n}", "Stones -{n}")
	_add("game.score_siege_broken", "围困 -{n}", "Siege -{n}")

	# ===== 终局原因与结果 =====
	_add("result.reason_resign", "认输", "Resignation")
	_add("result.reason_timeout", "超时", "Timeout")
	_add("result.reason_disconnect", "对手断开", "Opponent disconnected")
	_add("result.reason_passes", "双方虚手", "Both passed")
	_add("result.reason_force_end", "强制终局", "Forced end")
	_add("result.win_black", "黑方胜", "Black Wins")
	_add("result.win_white", "白方胜", "White Wins")
	_add("result.draw", "和棋", "Draw")
	_add("result.color_black_short", "黑", "B")
	_add("result.color_white_short", "白", "W")
	_add("result.play_again", "再 来 一 局", "Play Again")
	_add("result.back_to_main", "返 回 主 菜 单", "Back to Main Menu")
	_add("result.resign_format", "{who}认输", "{who} Resigned")
	_add("result.timeout_format", "{who}超时", "{who} Timeout")

	# ===== 得分板（ScorePanel）=====
	_add("score.log_title", "▾ 得分日志", "▾ Score Log")
	_add("score.log_name", "得分日志", "Score Log")
	_add("score.log_empty", "（暂无记录）", "(No records yet)")
	_add("score.log_move", "落子", "Move")
	_add("score.log_deploy", "部署", "Deploy")
	_add("score.log_pass", "虚手", "Pass")
	_add("score.log_bounce", "弹子", "Bounce")
	_add("score.log_special", "特种部队", "Special Forces")
	_add("score.log_cap_format", "提{n}", "Cap {n}")
	_add("score.special_used_out", "特 种 已 用 尽", "Special Used Up")
	_add("score.special_remaining", "特 种 (剩 {n})", "Special ({n} left)")
	_add("score.special_cooldown", "特 种 冷 却 中", "Special Cooling Down")
	_add("score.deploy_btn", "▸ 部 署 特 种 (剩 {n})", "▸ Deploy Special ({n} left)")
	_add("score.cancel_deploy", "✕ 取 消 部 署", "✕ Cancel Deploy")
	_add("score.black_side", "黑 方", "Black")
	_add("score.white_side", "白 方", "White")
	_add("score.forces_format", "兵力 {used} / {total}", "Forces {used} / {total}")
	_add("score.total_score", "总  分", "Total")
	_add("score.thinking", "思 考 中 …", "Thinking…")
	_add("score.score_breakdown", "得 分 构 成", "Score Breakdown")
	_add("score.occupation", "占领分", "Occupation")
	_add("score.defense", "防御分", "Defense")
	_add("score.loss", "战损分", "Loss")
	_add("score.score_change", "总分变化", "Total Change")
	_add("score.waiting_game", "等待对局...", "Waiting for game…")
	_add("score.own_side", "本方", "Own")
	_add("score.opp_side", "对方", "Opp")
	_add("score.time_unlimited", "∞   无 限", "∞ Unlimited")
	_add("score.time_byoyomi", "读秒 {n}s", "Byoyomi {n}s")

	# ===== 联机对话框 =====
	_add("net.menu_title", "联机对战", "Online Battle")
	_add("net.menu_close", "关闭", "Close")
	_add("net.menu_role", "选择您的角色：", "Select your role:")
	_add("net.menu_host", "建立房间（黑方 · 主机）", "Host Room (Black · Host)")
	_add("net.menu_join", "加入房间（白方 · 客户端）", "Join Room (White · Client)")
	_add("net.host_title", "建立房间 · 房间设置", "Host Room · Settings")
	_add("net.host_create", "建立房间", "Create Room")
	_add("net.host_cancel", "取消", "Cancel")
	_add("net.host_role_hint", "您将作为黑方（主机）建立房间...", "You will host as Black…")
	_add("net.host_thinking_time", "思考时间", "Thinking Time")
	_add("net.host_forces", "兵力", "Forces")
	_add("net.host_komi", "贴目", "Komi")
	_add("net.host_port", "端口:", "Port:")
	_add("net.list_title", "加入房间 · 房间列表", "Join Room · Room List")
	_add("net.list_join", "加入房间", "Join")
	_add("net.list_cancel", "取消", "Cancel")
	_add("net.list_port_failed", "⚠ 监听端口 5007 失败（可能被占用），无法搜索房间", "⚠ Port 5007 bind failed (may be occupied); cannot search rooms")
	_add("net.list_searching", "正在搜索局域网房间…（每 2 秒自动刷新）", "Searching for LAN rooms… (auto-refresh every 2s)")
	_add("net.list_hint", "局域网内发现的房间列表：\n选中一个房间后点击「加入房间」", "Rooms discovered on LAN:\nSelect one and click 'Join'")
	_add("net.list_refresh", "刷新列表", "Refresh")
	_add("net.list_found", "发现 {n} 个房间", "Found {n} room(s)")
	_add("net.list_unlimited", "无限制", "Unlimited")
	_add("net.list_time_format", "{n}分×{m}秒", "{n}m×{m}s")
	_add("net.list_forces_komi", "兵力 {forces}  |  贴目 {komi}", "Forces {forces}  |  Komi {komi}")
	_add("net.wait_title", "房间等待中", "Room Waiting")
	_add("net.wait_start", "开始游戏", "Start Game")
	_add("net.wait_cancel", "取消房间", "Cancel Room")
	_add("net.wait_waiting", "等待对手加入…", "Waiting for opponent to join…")
	_add("net.wait_joined", "对手已加入！\n点击「开始游戏」开始对局", "Opponent joined!\nClick 'Start Game' to begin")

	# ===== 棋盘视图（BoardView 绘制文本）=====
	_add("board.deploy_mode", "部 署 模 式", "Deploy Mode")

	# ===== 对局日志（GameLogOverlay）=====
	_add("log.title", "对 局 日 志", "Game Log")
	_add("log.header", "  手  | 方  | 动作       | 位置  | 提子 | 得分变化", "  # | Side| Action     | Pos  | Cap  | Score")
	_add("log.empty", "（暂无对局记录）", "(No game records yet)")
	_add("log.close_hint", "L / ESC 关闭", "L / ESC to close")
	_add("log.action_capture", "提", "Cap")
	_add("log.action_deploy", "部署特种", "Deploy Spec")
	_add("log.action_bounce", "落子·弹子", "Move·Bounce")

	# ===== 历史面板 =====
	_add("history.capture_suffix", " 提{n}", " cap {n}")
	_add("history.bounce_suffix", " 弹子", " bounce")
	_add("history.pass_suffix", " 虚手", " pass")
	_add("history.deploy_suffix", " 部署", " deploy")

	# ===== 回放界面（GamePlayerPanel + ReplayScreen）=====
	_add("replay.back", "← 返回主菜单", "← Back to Main Menu")
	_add("replay.sgf_filter", "*.sgf ; SGF 棋谱", "*.sgf ; SGF Files")
	_add("replay.classic", "经典对局", "Classic Games")
	_add("replay.masters", "棋圣名局", "Master Games")
	_add("replay.modern", "当代对局", "Modern Games")
	_add("replay.import", "导入", "Import")
	_add("replay.not_imported", "未导入棋谱", "No SGF imported")
	_add("replay.no_game", "（无棋谱）", "(No game)")
	_add("replay.unnamed", "未命名对局", "Unnamed Game")
	_add("replay.result_format", "\n结果: {n}", "\nResult: {n}")
	_add("replay.prev_move", "上一手", "Prev")
	_add("replay.next_move", "下一手", "Next")

	# ===== 教程（TutorialScreen + TutorialLesson，仅界面文本；关卡内容见 LessonData）=====
	_add("tutorial.title", "规则教程", "Tutorial")
	_add("tutorial.back", "← 返回主菜单", "← Back to Main Menu")
	_add("tutorial.lessons_count", "共 {n} 关 · 完成前一关解锁下一关", "{n} lessons · Complete one to unlock the next")
	_add("tutorial.reset_progress", "重置进度", "Reset Progress")
	_add("tutorial.stage_basic", "基础", "Basic")
	_add("tutorial.stage_core", "核心", "Core")
	_add("tutorial.stage_advanced", "进阶", "Advanced")
	_add("tutorial.stage_expert", "高级", "Expert")
	_add("tutorial.stage_optional", "可选", "Optional")
	_add("tutorial.completed", "✓ 已完成", "✓ Completed")
	_add("tutorial.locked", "🔒 未解锁", "🔒 Locked")
	_add("tutorial.click_to_learn", "点击学习", "Click to Learn")
	_add("tutorial.lessons_list_back", "← 关卡列表", "← Lessons List")
	_add("tutorial.retry", "重 试", "Retry")
	_add("tutorial.next_lesson", "我已理解，下一关", "Got it, Next Lesson")
	_add("tutorial.pass_btn", "虚 手", "Pass")
	_add("tutorial.deploy_btn", "部署特种", "Deploy Special")
	_add("tutorial.color_black", "执子：黑", "Playing: Black")
	_add("tutorial.lesson_idx", " 关卡", " Lesson")
	_add("tutorial.objective_label", "目标：", "Objective:")
	_add("tutorial.special_deployed", "特种部队已部署（隐藏棋子）", "Special forces deployed (hidden stone)")
	_add("tutorial.captured_n", "提吃 {n} 子！", "Captured {n} stone(s)!")
	_add("tutorial.move_success", "落子成功", "Move placed")
	_add("tutorial.move_illegal", "禁止落子：", "Illegal move:")
	_add("tutorial.correct", "✓ 正确（{name}）", "✓ Correct ({name})")
	_add("tutorial.wrong_click", "点错了：需要点击「{name}」区域", "Wrong click: click the '{name}' zone")
	_add("tutorial.zone_black", "黑方领土（第1-9行）", "Black territory (rows 1-9)")
	_add("tutorial.zone_border", "边境线（第10行）", "Borderline (row 10)")
	_add("tutorial.zone_white", "白方领土（第11-19行）", "White territory (rows 11-19)")
	_add("tutorial.pass_success", "虚手成功：保留棋子，等待对方落子", "Pass: keep stones, wait for opponent's move")
	_add("tutorial.deploy_canceled", "已取消部署", "Deployment canceled")
	_add("tutorial.lesson_complete", "🎉 关卡完成！", "🎉 Lesson Complete!")
	_add("tutorial.next_btn", "下一关", "Next Lesson")
	_add("tutorial.remaining_stones", "剩余棋子：黑 {b} / 白 {w}", "Stones left: Black {b} / White {w}")
	_add("game.room_canceled", "已取消房间", "Room canceled")
	_add("game.online_exited", "已退出联机模式", "Exited online mode")
	# 行棋拒绝原因（core 层返回中文，UI 层 translate_reason 运行时翻译）
	_add_reason("对局已结束", "Game over")
	_add_reason("非该方行棋", "Not that side's turn")
	_add_reason("兵力已用尽", "Forces exhausted")
	_add_reason("越界", "Out of bounds")
	_add_reason("撞隐子且八格均不可落子，请重新选择", "Collided with a hidden stone; all 8 surrounding cells are unplayable. Choose another point")
	_add_reason("特种部队不可用（次数/冷却/未开启）", "Special forces unavailable (uses/cooldown/disabled)")
	_add_reason("该点已有棋子", "A stone already occupies this point")
	_add_reason("劫争禁着", "Ko move forbidden")
	_add_reason("自杀禁着", "Suicide move forbidden")
	_add_reason("对局已结束，无法悔棋", "Game over, cannot undo")
	_add_reason("无可悔棋历史", "No undo history")
	_add_reason("一方兵力用尽且双方连续虚手", "Forces exhausted and both sides passed consecutively")
	_add_reason("双方均无法落子", "Neither side can move")
	_add_reason("双方连续虚手", "Both sides passed consecutively")

# 注册一条翻译键
func _add(key: String, zh: String, en: String) -> void:
	_translations[key] = {LOCALE_ZH: zh, LOCALE_EN: en}

# 注册一条行棋拒绝原因翻译（中文原文 -> 英文）
func _add_reason(zh: String, en: String) -> void:
	_reason_translations[zh] = en
