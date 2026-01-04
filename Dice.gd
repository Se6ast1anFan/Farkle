extends Button

var value = 1
# 记录一下骰子的初始位置，用来震动后归位
var original_position = Vector2.ZERO

func _ready():
	# 启用 Toggle Mode (确保你检查器里勾选了)
	toggle_mode = true
	update_visual()

# 当进入场景树时，记录自己的初始位置
func _enter_tree():
	original_position = position

# 只改变数字（动画用）
func roll_visual_only():
	value = randi_range(1, 6)
	update_visual()
	
	# 简单的震动效果：在原位置偏移 -2 到 +2 像素
	var offset_x = randf_range(-5, 5)
	var offset_y = randf_range(-5, 5)
	# 注意：如果骰子在容器里，直接改 position 可能被容器重置
	# 但我们可以改 pivot_offset 或者用 position (容器 update 没那么快)
	# 最稳妥是修改 rotation (旋转) 或 scale
	rotation_degrees = randf_range(-10, 10) 

# 重置状态（停止摇动时调用）
func reset_visual_transform():
	rotation_degrees = 0
	# 颜色恢复
	modulate = Color(1, 1, 1)

func update_visual():
	text = str(value)
