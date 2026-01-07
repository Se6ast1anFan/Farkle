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
@onready var restart_btn = $RestartButton

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
	
	roll_btn.pressed.connect(_on_roll_pressed)
	bank_btn.pressed.connect(_on_bank_pressed)
	stop_btn.pressed.connect(_on_stop_pressed)
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
	var all_btns = [roll_btn, bank_btn, stop_btn, restart_btn]
	for btn in all_btns:
		btn.custom_minimum_size = Vector2(120, 60) # 最小宽高

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
	# 圆角半径设为直径的一半，保证绝对是圆的
	cup_style.set_corner_radius_all(cup_diameter / 2) 
	
	dice_cup.add_theme_stylebox_override("panel", cup_style)
	dice_cup.visible = false 
	# --- 修改结束 ---

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
	
	# 隐藏按钮逻辑...
	roll_btn.visible = false
	bank_btn.visible = false
	stop_btn.visible = true # 此时显示 Stop 按钮
	
	# --- 新增：显示骰盅并开始摇晃 ---
	dice_cup.visible = true
	dice_cup.modulate.a = 1.0 # 确保不透明
	
	# 这一步很重要：先把骰子藏在盅底下，并重新洗牌位置
	for die in container.get_children(): 
		if die != dice_cup:
			die.disabled = true
			# 在摇的时候就可以先随机好位置，等揭开
			# 或者你也可以在揭开瞬间随机，这里先随机是为了逻辑统一
	
	scatter_dice_visuals() 
	
	# 开始摇晃动画 (Loop)
	start_shaking_tween()

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

func _on_stop_pressed():
	is_rolling = false
	stop_btn.visible = false
	
	# 1. 停止摇晃
	if shake_tween: shake_tween.kill()
	dice_cup.set_anchors_preset(Control.PRESET_CENTER)
	dice_cup.set_offsets_preset(Control.PRESET_CENTER)
	
	# 2. 播放“揭盖”动画 (1秒)
	# 这里我们做一个简单的淡出+向上飘走的动画
	var reveal_tween = create_tween()
	reveal_tween.tween_property(dice_cup, "position", Vector2(0, -100), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	reveal_tween.parallel().tween_property(dice_cup, "modulate:a", 0.0, 0.5)
	
	# 3. 等待动画结束
	await reveal_tween.finished
	dice_cup.visible = false
	
	# 4. 恢复交互并结算
	roll_btn.visible = true
	bank_btn.visible = true
	
	for die in container.get_children():
		if die != dice_cup:
			die.disabled = false
			die.reset_visual_transform() # 这里的 reset 可能要改改，不要重置 position
	
	check_bust_logic()
# --- 按钮事件 ---

func _on_roll_pressed():
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
	if is_game_over: return
	if turn_accumulated_score + current_selection_score == 0: return
	
	total_scores[current_player_index] += turn_accumulated_score + current_selection_score
	
	if total_scores[current_player_index] >= WINNING_SCORE:
		handle_win()
	else:
		switch_turn()

func _on_restart_pressed():
	start_game()

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
	roll_btn.visible = false # 爆掉了就不准再投了
	bank_btn.visible = false # 也不准存分
	stop_btn.visible = false
	
	for die in container.get_children():
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
