extends Control

# --- UI 引用 ---
@onready var container = $VBoxContainer/DiceTray 
@onready var dice_cup = $VBoxContainer/DiceTray/DiceCup
@onready var score_label = $VBoxContainer/ScoreLabel
@onready var p1_label = $TopBar/P1Label
@onready var p2_label = $TopBar/P2Label

# 按钮组
@onready var roll_btn = $VBoxContainer/ButtonBox/RollButton
@onready var bank_btn = $VBoxContainer/ButtonBox/BankButton
@onready var stop_btn = $VBoxContainer/ButtonBox/StopButton # 新增
@onready var shake_up_btn = $VBoxContainer/ButtonBox/ShakeUpBtn
@onready var shake_down_btn = $VBoxContainer/ButtonBox/ShakeDownBtn
@onready var restart_btn = $RestartButton

# ... 其他变量 ...
@onready var pause_btn = $PauseButton
@onready var pause_menu = $PauseMenu
@onready var pm_title = $PauseMenu/Label_Title
@onready var pm_text = $PauseMenu/RichTextLabel
@onready var resume_btn = $PauseMenu/ResumeButton

# --- 游戏数据 ---
const WINNING_SCORE = 2000
const TRAY_RADIUS = 150.0  # 骰盘半径
const DICE_SIZE = 80.0     # 骰子大小 (需与你设置的 custom_minimum_size 匹配)
var total_scores = [0, 0]
var current_player_index = 0

var turn_accumulated_score = 0
var current_selection_score = 0

# --- 状态标记 ---
var is_rolling = false     # 是否正在播放摇骰子动画
var is_busted = false      # 是否爆掉
var is_game_over = false   # 游戏是否结束

# GameTest.gd

func _ready():
	randomize()
	setup_ui_layout()
	
	# ... (绑定信号的代码保持不变，记得要有那个 if child == dice_cup: continue) ...
	for child in container.get_children():
		if child == dice_cup: continue 
		child.toggled.connect(_on_dice_clicked)
	
	# --- 纯代码设置暂停逻辑模式 ---
	# 1. 根节点设为 ALWAYS，确保它能一直处理 ESC 按键
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 2. 暂停菜单和继续按钮设为 WHEN_PAUSED，只有暂停时它们才工作
	# (其实 Panel 只要父级没停就行，但保险起见设一下)
	pause_menu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# 3. 其他游戏元素不需要手动设，默认是 INHERIT (继承)，
	# 一旦我们调用 get_tree().paused = true，所有没特殊设置的节点都会停。
	
	# 绑定点击事件
	pause_btn.pressed.connect(toggle_pause)
	resume_btn.pressed.connect(toggle_pause)
	
	roll_btn.pressed.connect(_on_roll_pressed)
	bank_btn.pressed.connect(_on_bank_pressed)
	stop_btn.pressed.connect(_on_stop_pressed)
	shake_up_btn.pressed.connect(_on_shake_up)
	shake_down_btn.pressed.connect(_on_shake_down)
	restart_btn.pressed.connect(_on_restart_pressed)
	
	# --- 核心修复：等待一帧 ---
	# 让 UI 引擎先把界面排好版，确保 container.size 是正确的值
	await get_tree().process_frame 
	
	start_game()

# --- 新增这个函数：纯代码控制布局 ---
func setup_ui_layout():
	# 1. 确保根节点填满整个屏幕 (对应编辑器的 Full Rect)
	# 这里的 self 指的是 GameTest 根节点
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# 2. 设置顶部栏 (TopBar) - 始终吸附顶部，宽度拉伸
	var top_bar = $TopBar
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	# 给顶部留一点空隙，别贴着手机刘海屏
	top_bar.offset_top = 40 
	top_bar.offset_bottom = 100 # 设置高度
	
	# 3. 设置两个玩家标签 - 也就是让它们平分 TopBar 的宽度
	# 对应 Size Flags -> Horizontal -> Expand + Fill
	p1_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p1_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	p2_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p2_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# 4. 设置核心游戏区 (VBoxContainer) - 始终居中
	var main_vbox = $VBoxContainer
	# 对应编辑器的 Center (屏幕正中心)
	main_vbox.set_anchors_preset(Control.PRESET_CENTER)
	# 确保它不会因为内容变动而跑偏，重置偏移量
	main_vbox.set_offsets_preset(Control.PRESET_CENTER)
	# 增加一点组件之间的间距
	main_vbox.add_theme_constant_override("separation", 30)

	# 5. 设置重开按钮 (RestartButton) - 始终吸附右上角
	restart_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	
	# --- 修改开始 ---
	# 不要用 position，要用 offset
	# 逻辑是：距离右边界越远，负数越大
	restart_btn.offset_left = -140  # 按钮左边缘距离屏幕右侧 140 像素
	restart_btn.offset_right = -20  # 按钮右边缘距离屏幕右侧 20 像素 (留边距)
	restart_btn.offset_top = 40     # 距离顶部 40 像素
	restart_btn.offset_bottom = 100 # 距离顶部 100 像素 (即高度60)
	# --- 修改结束 ---

	# 6. 设置底部按钮组 (ButtonBox)
	var btn_box = $VBoxContainer/ButtonBox
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER # 按钮居中对齐
	btn_box.add_theme_constant_override("separation", 20) # 按钮间距
	
# 7. 确保所有按钮有最小尺寸，方便手机触摸
	# --- 修改：同时设置轴心点 (Pivot Offset) 以支持缩放动画 ---
	var all_btns = [roll_btn, bank_btn, stop_btn, restart_btn, shake_up_btn, shake_down_btn, resume_btn]
	for btn in all_btns:
		var btn_size = Vector2(120, 60) # 默认大小
		# 如果是继续按钮，它比较大
		if btn == resume_btn: btn_size = Vector2(200, 80)
		
		btn.custom_minimum_size = btn_size
		btn.size = btn_size # 强制应用尺寸
		
		# 关键：设置轴心点为按钮中心
		btn.pivot_offset = btn_size / 2
	
	# 默认隐藏摇晃按钮
	shake_up_btn.visible = false
	shake_down_btn.visible = false

# 1. 设置骰盘区域 (container)
	# 确保这里的大小比杯子大 (杯子是320，盘子设400没问题)
	container.custom_minimum_size = Vector2(400, 400) 
	# 确保盘子自己在屏幕正中间
	container.set_anchors_preset(Control.PRESET_CENTER) 
	# 如果它是VBox的子节点，这一行很重要，让它在VBox里居中
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
# 2. 用代码把 DiceCup 画成一个圆形 (红色/褐色)
	# --- 修改开始 ---
	
	# 设定一个固定的直径 (比盘子略小一点或者一样大)
	var cup_diameter = 320.0 
	
	# 强制设定大小为正方形 (正方形+大圆角 = 正圆)
	dice_cup.custom_minimum_size = Vector2(cup_diameter, cup_diameter)
	dice_cup.size = Vector2(cup_diameter, cup_diameter)
	
	# 关键：让它居中在父节点(DiceTray)内部，而不是铺满
# ... (前文设置大小和 anchors_preset)
	dice_cup.set_anchors_preset(Control.PRESET_CENTER)
	dice_cup.set_offsets_preset(Control.PRESET_CENTER)
	
	# --- 新增/修改：强制让它向中心生长 ---
	dice_cup.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dice_cup.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	# 设置中心点 (Pivot) 为圆心，这样缩放和旋转都会围绕中心
	dice_cup.pivot_offset = Vector2(cup_diameter / 2, cup_diameter / 2)
	# --------------------------------
	
	dice_cup.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	
	var cup_style = StyleBoxFlat.new()
	cup_style.bg_color = Color(0.4, 0.2, 0.1) # 棕色
	# 60 这个数值越大越圆，越小越方。320的大小配 60 看起来像个 APP 图标或圆角盒子
	cup_style.set_corner_radius_all(100) 
	
	dice_cup.add_theme_stylebox_override("panel", cup_style)
	dice_cup.visible = false 
	# --- 修改结束 ---

	# --- 8. 设置暂停按钮 (放在重开按钮正下方) ---
	pause_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_btn.offset_left = -140
	pause_btn.offset_right = -20
	pause_btn.offset_top = 110    # 重开是40-100，这里从110开始
	pause_btn.offset_bottom = 170 
	pause_btn.custom_minimum_size = Vector2(120, 60)

# --- 9. 设置暂停菜单 (父容器) ---
	# 确保父容器铺满全屏。使用 set_anchors_and_offsets_preset 强制重置所有偏移量为0
	pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_menu.visible = false 
	
	# 设置背景色
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.9) # 90% 黑
	pause_menu.add_theme_stylebox_override("panel", style)
	
	# 拦截点击 (防止穿透)
	pause_menu.mouse_filter = Control.MOUSE_FILTER_STOP

# --- 10. 设置暂停菜单内部子节点布局 (蛋糕分层法) ---
	
	# === A. 标题层 (调整：压缩高度，给下面腾地方) ===
	pm_title.anchor_left = 0
	pm_title.anchor_right = 1
	pm_title.anchor_top = 0
	pm_title.anchor_bottom = 0.15 # 从 0.2 改为 0.15，标题不需要那么高
	
	# ... (标题的 offset 和 alignment 设置代码保持不变) ...
	pm_title.offset_left = 0
	pm_title.offset_right = 0
	pm_title.offset_top = 0
	pm_title.offset_bottom = 0
	pm_title.text = "游戏已暂停"
	pm_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pm_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pm_title.add_theme_font_size_override("font_size", 64)

	# === B. 规则文本 (调整：大幅增加高度范围) ===
	# 左右边距稍微调小一点 (0.05)，让横向能写下更多字
	pm_text.anchor_left = 0.05 
	pm_text.anchor_right = 0.95
	
	# 上下范围扩大！从标题下面(0.15)一直延伸到按钮上面(0.82)
	pm_text.anchor_top = 0.15 
	pm_text.anchor_bottom = 0.82
	
	pm_text.offset_left = 0
	pm_text.offset_right = 0
	pm_text.offset_top = 0
	pm_text.offset_bottom = 0
	
	pm_text.fit_content = false 
	pm_text.scroll_active = true
	pm_text.bbcode_enabled = true 
	
	# 使用你提供的最新文案
	pm_text.text = """[center][font_size=32][b]📜 游戏规则说明[/b][/font_size]

[color=#ffdd88][b]🏆 获胜目标[/b][/color]
双人轮流，率先累计总分达到 [color=#44ff44][b]2000 分[/b][/color] 者获胜。

[color=#ffdd88][b]🎲 计分指南[/b][/color]
[color=#88ccff]• 单个骰子[/color]: 仅 [b]1点[/b](100分) 和 [b]5点[/b](50分) 得分。
[color=#88ccff]• 豹子(3个相同)[/color]: 面值x100 [color=#aaaaaa](例: 222=200)[/color]。
  [color=#ff6666]*特例: 111 = 1000 分！[/color]
[color=#88ccff]• 多重豹子[/color]: 4个及以上，分数随个数翻倍。
[color=#88ccff]• 顺子[/color]: 1~5=[b]500[/b]，2~6=[b]750[/b]，1~6=[b]1500[/b]。

[color=#ffdd88][b]⚠️ 核心玩法[/b][/color]
必须留出得分骰子才能[b]离手[/b]或[b]继续投掷[/b]。继续投掷若[b]无分[/b]则[color=#ff4444][b]爆掉清零本轮[/b][/color]。
6个骰子全得分可[color=#ffff44][b]清台[/b][/color]，保留分数并全部重新投掷。

--------------------------------------------------
[b]【按键映射】[/b]
[color=#44ff44]P1[/color]: 向上/下摇(W/S)  离手(D)
[color=#44ff44]P2[/color]: 向上/下摇(I/K)  离手(J)
[color=#aaaaaa]通用[/color]: 查看骰子(G)  继续投掷(空格)  说明(ESC)  重开游戏(B)[/center]"""
	# === C. 按钮层 (占据底部 85% 处) ===
	# 这里的策略是：锚点定在一个具体的水平线(0.85)上，然后定死宽高
	
	resume_btn.anchor_left = 0.5  # 水平中心
	resume_btn.anchor_right = 0.5
	resume_btn.anchor_top = 0.85  # 屏幕高度的 85% 位置
	resume_btn.anchor_bottom = 0.85
	
	# 关键：开启双向生长，配合下面的负偏移量来实现绝对居中
	resume_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	resume_btn.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	# 设定按钮的具体大小 (宽200，高80)
	var btn_w = 200
	var btn_h = 80
	
	# 手动偏移：从中心点向左移一半宽度，向右移一半宽度
	resume_btn.offset_left = -btn_w / 2
	resume_btn.offset_right = btn_w / 2
	resume_btn.offset_top = 0
	resume_btn.offset_bottom = btn_h # 向下生长80像素
	
	resume_btn.text = "继续游戏"

# --- 关键：每帧运行的动画逻辑 ---
func _process(delta):
	if is_rolling:
		# 遍历所有可见的骰子，让它们狂乱！
		for die in container.get_children():
			if die == dice_cup: continue 
			if die.visible:
				die.roll_visual_only()

# --- 游戏流程 ---

func start_game():
	roll_btn.disabled = false
	bank_btn.disabled = false
	stop_btn.disabled = false
	total_scores = [0, 0]
	current_player_index = 0
	is_game_over = false
	update_player_labels()
	start_new_turn()

func start_new_turn():
	turn_accumulated_score = 0
	current_selection_score = 0
	is_busted = false
	
	# --- 新增：新回合开始先隐藏分数板 ---
	score_label.visible = false 
	# --------------------------------
	
	for die in container.get_children():
		if die == dice_cup: continue 
		die.visible = true
		die.button_pressed = false
		die.disabled = false
		die.reset_visual_transform()
	start_rolling_anim()

func switch_turn():
	current_player_index = 1 - current_player_index
	update_player_labels()
	start_new_turn()

# --- 动画控制 (开始/停止) ---

# 开始摇动动画
func start_rolling_anim():
	is_rolling = true
	score_label.visible = false
	
	# 隐藏常规按钮
	roll_btn.visible = false
	bank_btn.visible = false
	
	# --- 修改：显示手动操作组 ---
	stop_btn.visible = true
	shake_up_btn.visible = true
	shake_down_btn.visible = true
	# -------------------------
	
	# 显示骰盅
	dice_cup.visible = true
	dice_cup.modulate.a = 1.0
	
	# 强制让杯子归位到正中心 (防止上回合偏移了没回来)
	var tray_center = container.size / 2
	var cup_half = dice_cup.size / 2
	dice_cup.position = tray_center - cup_half
	
	# 隐藏骰子并“洗牌”
	for die in container.get_children(): 
		if die != dice_cup:
			die.disabled = true
	
	scatter_dice_visuals() # 先随机散布一次
	
	# 注意：这里不再调用 start_shaking_tween() 了！

var shake_tween: Tween

func start_shaking_tween():
	if shake_tween: shake_tween.kill()
	shake_tween = create_tween().set_loops() 
	
	# --- 核心修复：数学计算绝对中心 ---
	# 逻辑：父节点的一半尺寸 - 杯子自身的一半尺寸 = 居中坐标
	var tray_center = container.size / 2
	var cup_half = dice_cup.size / 2
	var target_center = tray_center - cup_half
	
	# 强制先把杯子按在这个中心点上，防止它跑偏
	dice_cup.position = target_center
	
	# 基于这个计算出的中心点进行摇晃
	shake_tween.tween_property(dice_cup, "position", target_center + Vector2(0, -20), 0.1)
	shake_tween.tween_property(dice_cup, "position", target_center + Vector2(0, 20), 0.1)

func _on_shake_up():
	if get_tree().paused: return
	perform_shake(Vector2(0, -30)) # 向上偏移

func _on_shake_down():
	if get_tree().paused: return
	perform_shake(Vector2(0, 30)) # 向下偏移

func perform_shake(direction_offset: Vector2):
	# 1. 每次摇的时候，里面的骰子位置都要变！
	scatter_dice_visuals() 
	
	# 2. 播放摇晃音效 (如果有)
	# if not sfx_roll.playing: sfx_roll.play()
	
	# 3. 杯子位移动画 (Punch效果：移过去立刻弹回来)
	var tray_center = container.size / 2
	var cup_half = dice_cup.size / 2
	var base_pos = tray_center - cup_half
	
	# 加上一点随机左右偏移，模拟手的不稳定性
	var random_x = randf_range(-10, 10)
	var target_pos = base_pos + direction_offset + Vector2(random_x, 0)
	
	var tween = create_tween()
	# 快速移过去 (0.05s)
	tween.tween_property(dice_cup, "position", target_pos, 0.05)
	# 稍微慢点弹回来 (0.1s)
	tween.tween_property(dice_cup, "position", base_pos, 0.1).set_trans(Tween.TRANS_BOUNCE)

func _on_stop_pressed():
	if get_tree().paused: return
	is_rolling = false
	
	# --- 修改：隐藏所有手动操作按钮 ---
	stop_btn.visible = false
	shake_up_btn.visible = false
	shake_down_btn.visible = false
	# ------------------------------
	
	# 确保杯子在正中心
	var tray_center = container.size / 2
	var cup_half = dice_cup.size / 2
	dice_cup.position = tray_center - cup_half
	
	# 揭盖动画 (保持不变)
	var reveal_tween = create_tween()
	reveal_tween.tween_property(dice_cup, "position", dice_cup.position + Vector2(0, -100), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	reveal_tween.parallel().tween_property(dice_cup, "modulate:a", 0.0, 0.5)
	
	await reveal_tween.finished
	dice_cup.visible = false
	
	# 恢复常规按钮
	roll_btn.visible = true
	bank_btn.visible = true
	
	for die in container.get_children():
		if die != dice_cup:
			die.disabled = false
			die.reset_visual_transform() 
			
	check_bust_logic()

func _on_roll_pressed():
	if get_tree().paused: return
	if is_game_over: return
	
	# 点击“开始投掷”时，先锁定之前的分数
	if current_selection_score > 0:
		turn_accumulated_score += current_selection_score
		
		# 隐藏选中的骰子
		var active_count = 0
		for die in container.get_children():
			if die == dice_cup: continue
			if die.button_pressed:
				die.visible = false
				die.button_pressed = false
			if die.visible: active_count += 1
				
		# 清台判定
		if active_count == 0:
			for die in container.get_children():
				if die == dice_cup: continue
				die.visible = true
	
		# 开启下一轮摇动
		start_rolling_anim()

func _on_bank_pressed():
	if get_tree().paused: return
	if is_game_over: return
	if turn_accumulated_score + current_selection_score == 0: return
	
	total_scores[current_player_index] += turn_accumulated_score + current_selection_score
	
	if total_scores[current_player_index] >= WINNING_SCORE:
		handle_win()
	else:
		switch_turn()

func _on_restart_pressed():
	if get_tree().paused: return
	start_game()

func toggle_pause():
	var is_paused = not pause_menu.visible
	pause_menu.visible = is_paused
	get_tree().paused = is_paused

func _unhandled_input(event):
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	# ESC 键
	if event.keycode == KEY_ESCAPE:
		# 既然暂停按钮没有物理映射，我们可以给它播放一个动画，或者不放
		toggle_pause()
		return

	if get_tree().paused or is_game_over:
		return

	# --- 全局通用按键 ---
	
	# B键：重开
	if event.keycode == KEY_B:
		animate_button_press(restart_btn) # <--- 视觉反馈
		if restart_btn.visible and not restart_btn.disabled:
			_on_restart_pressed()
			return

	# G键：查看骰子
	if event.keycode == KEY_G:
		animate_button_press(stop_btn) # <--- 视觉反馈
		if is_rolling and stop_btn.visible:
			_on_stop_pressed()
			return

	# --- 玩家专属按键 ---
	
	if current_player_index == 0: # P1
		match event.keycode:
			KEY_W: # 向上摇
				animate_button_press(shake_up_btn) # <--- 视觉反馈
				if is_rolling and shake_up_btn.visible: _on_shake_up()
			KEY_S: # 向下摇
				animate_button_press(shake_down_btn) # <--- 视觉反馈
				if is_rolling and shake_down_btn.visible: _on_shake_down()
			KEY_SPACE: # 重投
				animate_button_press(roll_btn) # <--- 视觉反馈
				if not is_rolling and roll_btn.visible and not roll_btn.disabled: _on_roll_pressed()
			KEY_D: # 存分
				animate_button_press(bank_btn) # <--- 视觉反馈
				if not is_rolling and bank_btn.visible and not bank_btn.disabled: _on_bank_pressed()
	
	else: # P2
		match event.keycode:
			KEY_I: 
				animate_button_press(shake_up_btn)
				if is_rolling and shake_up_btn.visible: _on_shake_up()
			KEY_K: 
				animate_button_press(shake_down_btn)
				if is_rolling and shake_down_btn.visible: _on_shake_down()
			KEY_SPACE: 
				animate_button_press(roll_btn)
				if not is_rolling and roll_btn.visible and not roll_btn.disabled: _on_roll_pressed()
			KEY_J: 
				animate_button_press(bank_btn)
				if not is_rolling and bank_btn.visible and not bank_btn.disabled: _on_bank_pressed()
# --- 核心逻辑 ---

# 检查结果 (以前叫 roll_and_check，现在拆开了)
func check_bust_logic():
	var values = []
	for die in container.get_children():
		if die == dice_cup: continue
		if die.visible:
			values.append(die.value)
	
	# 检查是否爆掉
	var possible = ScoreCalculator.calculate_score(values, true)
	
	if possible == 0:
		handle_bust()
	else:
		# 没爆掉，刷新一下界面显示
		calculate_selection_score()

func handle_bust():
	is_busted = true
	score_label.visible = true
	score_label.text = "爆掉了！！！"
	score_label.modulate = Color(1, 0, 0)
	
	# 禁用按钮
	roll_btn.visible = false 
	bank_btn.visible = false 
	stop_btn.visible = false
	
	for die in container.get_children():
		# --- 新增：千万别把杯子也染红了 ---
		if die == dice_cup: continue 
		# -------------------------------
		
		die.modulate = Color(1, 0.5, 0.5)

	await get_tree().create_timer(2.0).timeout
	
	if not is_game_over:
		score_label.modulate = Color(1, 1, 1)
		switch_turn()

func handle_win():
	is_game_over = true
	update_player_labels()
	score_label.text = "玩家 %d 获胜！" % (current_player_index + 1)
	score_label.modulate = Color(1, 0.8, 0)
	roll_btn.disabled = true
	bank_btn.disabled = true
	stop_btn.visible = false

# --- 辅助逻辑 ---

func update_player_labels():
	p1_label.text = "P1: " + str(total_scores[0])
	p2_label.text = "P2: " + str(total_scores[1])
	
	if current_player_index == 0:
		p1_label.modulate = Color(0, 1, 0)
		p2_label.modulate = Color(0.5, 0.5, 0.5)
	else:
		p1_label.modulate = Color(0.5, 0.5, 0.5)
		p2_label.modulate = Color(0, 1, 0)

func _on_dice_clicked(pressed):
	if get_tree().paused: return
	calculate_selection_score()

func calculate_selection_score():
	# --- 新增：只要开始算分了，就显示 Label ---
	score_label.visible = true
	# ------------------------------------

	var values = []
	for die in container.get_children():
		if die == dice_cup: continue
		if die.visible and die.button_pressed: values.append(die.value)
	current_selection_score = ScoreCalculator.calculate_score(values)
	score_label.text = "本轮池分: %d (+选中: %d)" % [turn_accumulated_score, current_selection_score]

func scatter_dice_visuals():
	for die in container.get_children():
		if die == dice_cup: continue # 跳过骰盅节点
		
		# 1. 随机角度 (0 到 2π)
		var angle = randf() * TAU 
		
		# 2. 随机距离 (开方是为了保证分布均匀，不会聚集在圆心)
		# 半径减去骰子大小的一半，防止超出边界
		var max_r = TRAY_RADIUS - (DICE_SIZE / 2)
		var dist = sqrt(randf()) * max_r
		
		# 3. 计算坐标 (极坐标转笛卡尔坐标)
		# 注意：container 的中心是 size/2
		var center = container.size / 2
		var offset = Vector2(cos(angle), sin(angle)) * dist
		
		# 4. 设置位置 (需减去骰子自身中心偏移)
		die.position = center + offset - (Vector2(DICE_SIZE, DICE_SIZE) / 2)
		die.rotation_degrees = randf_range(0, 360) # 随机旋转

# 播放按钮按下的动画
func animate_button_press(btn: Button):
	# 安全检查：如果按钮不存在、隐藏或禁用，就不播放动画
	if not btn or not btn.visible or btn.disabled: return
	
	# 创建 Tween
	var tween = create_tween()
	
	# 阶段 1 (按下): 0.05秒内，变暗 + 缩小到 90%
	tween.tween_property(btn, "modulate", Color(0.7, 0.7, 0.7), 0.05)
	tween.parallel().tween_property(btn, "scale", Vector2(0.9, 0.9), 0.05)
	
	# 阶段 2 (弹回): 0.05秒内，恢复原色 + 恢复原大小
	tween.tween_property(btn, "modulate", Color(1, 1, 1), 0.05)
	tween.parallel().tween_property(btn, "scale", Vector2(1.0, 1.0), 0.05)
