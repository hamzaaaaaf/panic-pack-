extends Node3D

@onready var animation_player = %AnimationPlayer

# The door will now track as CLOSED when the game starts
var is_open = false

func _ready():
	# The millisecond the game loads, play the close animation 
	# and instantly skip to the end of it so it starts completely closed!
	if animation_player.has_animation("close"):
		animation_player.play("close")
		animation_player.advance(999) # Instantly fast-forwards the door to be shut

func interact():
	if not is_open:
		animation_player.play("open")
		is_open = true
	else:
		animation_player.play("close")
		is_open = false
