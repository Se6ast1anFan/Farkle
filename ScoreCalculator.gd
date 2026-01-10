class_name ScoreCalculator
extends Node

# 注意：去掉了 is_fresh_roll 参数，因为算分不应该关心是不是刚投出来的，
# 只要你选中的骰子凑成了顺子，就该给你分。
static func calculate_score(dice_values: Array, _unused_arg: bool = false) -> int:
	var score = 0
	var counts = {1:0, 2:0, 3:0, 4:0, 5:0, 6:0}
	
	for val in dice_values:
		if val >= 1 and val <= 6: counts[val] += 1
			
	# --- 1. 优先检测顺子 ---
	# 逻辑升级：如果检测到顺子，加分后要“消耗”掉这些骰子，
	# 这样剩下的骰子（例如多出来的那个5）还能继续往下走，参与单点计分。
	
	var straight_found = false
	
	# 1-6 大顺子 (1500)
	if _is_straight(counts, 1, 6):
		score += 1500
		_consume_dice(counts, 1, 6)
		straight_found = true
	
	# 1-5 小顺子 (500) - 互斥检测
	elif _is_straight(counts, 1, 5): 
		score += 500
		_consume_dice(counts, 1, 5)
		straight_found = true
		
	# 2-6 小顺子 (750) - 互斥检测
	elif _is_straight(counts, 2, 6): 
		score += 750
		_consume_dice(counts, 2, 6)
		straight_found = true

	# --- 2. 检测多重骰子 (三条、四条等) ---
	# 顺子和豹子理论上不会同时出现在同一组骰子里(除非你有7个以上骰子)，
	# 但为了逻辑严谨，我们继续处理剩下的 counts
	for num in range(1, 7):
		var count = counts[num]
		if count >= 3:
			var base = 1000 if num == 1 else num * 100
			score += base * pow(2, count - 3)
			counts[num] = 0 # 消耗掉所有用于豹子的骰子

	# --- 3. 检测剩余的单点 (1和5) ---
	score += counts[1] * 100
	score += counts[5] * 50
	
	return score

# 检查是否存在顺子
static func _is_straight(counts: Dictionary, start: int, end: int) -> bool:
	for i in range(start, end + 1):
		if counts[i] < 1: return false
	return true

# 消耗骰子 (将计数减1)
static func _consume_dice(counts: Dictionary, start: int, end: int):
	for i in range(start, end + 1):
		counts[i] -= 1
