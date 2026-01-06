extends Control

# --- UI 引用 ---
@onready var container = $VBoxContainer/HBoxContainer
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
var total_scores = [0, 0]
var current_player_index = 0

var turn_accumulated_score = 0
var current_selection_score = 0

# --- 状态标记 ---
var is_rolling = false     # 是否正在播放摇骰子动画
var is_busted = false      # 是否爆掉
var is_game_over = false   # 游戏是否结束

func _ready():
	randomize()
	
	# 绑定信号
	for die in container.get_children():
		die.toggled.connect(_on_dice_clicked)
	
	roll_btn.pressed.connect(_on_roll_pressed)
	bank_btn.pressed.connect(_on_bank_pressed)
	stop_btn.pressed.connect(_on_stop_pressed) # 绑定停止按钮
	restart_btn.pressed.connect(_on_restart_pressed)
	
	start_game()

# --- 关键：每帧运行的动画逻辑 ---
func _process(delta):
	if is_rolling:
		# 遍历所有可见的骰子，让它们狂乱！
		for die in container.get_children():
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
	# UI 切换：隐藏操作按钮，显示停止按钮
	roll_btn.visible = false
	bank_btn.visible = false
	stop_btn.visible = true
	
	# 禁用骰子交互，防止摇的时候乱点
	for die in container.get_children():
		die.disabled = true

# 停止摇动动画 (点击停止按钮触发)
func _on_stop_pressed():
	is_rolling = false
	
	# UI 切换：隐藏停止按钮，显示操作按钮
	stop_btn.visible = false
	roll_btn.visible = true
	bank_btn.visible = true
	
	# 让骰子停下来并归位
	for die in container.get_children():
		die.reset_visual_transform()
		die.disabled = false # 恢复可以点击
		
	# 动画结束了，现在的数字就是最终结果
	# 立即进行算分和查爆掉
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
			if die.button_pressed:
				die.visible = false
				die.button_pressed = false
			if die.visible: active_count += 1
				
		# 清台判定
		if active_count == 0:
			for die in container.get_children():
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
		if die.visible and die.button_pressed: values.append(die.value)
	current_selection_score = ScoreCalculator.calculate_score(values)
	score_label.text = "本轮池分: %d (+选中: %d)" % [turn_accumulated_score, current_selection_score]
