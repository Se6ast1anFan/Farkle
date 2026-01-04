class_name ScoreCalculator
extends Node

# 计算一组骰子的分数
# dice_values: 数组，包含骰子点数，例如 [1, 5, 2, 2, 2]
# is_fresh_roll: 布尔值，是否是刚投掷出的状态（用于判断顺子）
static func calculate_score(dice_values: Array, is_fresh_roll: bool = false) -> int:
	var score = 0
	var counts = {1:0, 2:0, 3:0, 4:0, 5:0, 6:0}
	var dice_count = dice_values.size()
	
	# 统计每个点数出现了几次
	for val in dice_values:
		if val >= 1 and val <= 6:
			counts[val] += 1
			
	# --- 1. 优先判断顺子 (必须是一次性投出的，且骰子数量符合) ---
	if is_fresh_roll:
		# 1-6 全顺子
		if dice_count == 6 and _is_straight(counts, 1, 6):
			return 1500
		# 1-5 小顺子
		if dice_count >= 5 and _is_straight(counts, 1, 5):
			return 500
		# 2-6 小顺子
		if dice_count >= 5 and _is_straight(counts, 2, 6):
			return 750

	# --- 2. 判断三条及以上 (N of a Kind) ---
	for num in range(1, 7):
		var count = counts[num]
		if count >= 3:
			var base = 0
			if num == 1:
				base = 1000
			else:
				base = num * 100
			
			# KCD规则：三个骰子后，每多一个翻一倍
			var multiplier = pow(2, count - 3)
			score += base * multiplier
			
			# 这种点数全部算完分了，清零，避免后面重复算单骰
			counts[num] = 0

	# --- 3. 判断剩余单骰 (只有1和5) ---
	score += counts[1] * 100
	score += counts[5] * 50
	
	return score

# 辅助工具：判断是不是顺子
static func _is_straight(counts: Dictionary, start: int, end: int) -> bool:
	for i in range(start, end + 1):
		if counts[i] < 1:
			return false
	return true
