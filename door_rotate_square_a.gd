extends Node3D

@onready var anim_player = $AnimationPlayer

var is_open = false

# This is a custom function our Player script will call
func interact():
	if not is_open:
		anim_player.play("open")
		is_open = true
	else:
		anim_player.play("close")
		is_open = false
