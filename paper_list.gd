extends Panel

@export var hidden_y: float = -520.0
@export var shown_y: float = 40.0
@export var slide_speed: float = 10.0

func _ready():
	position.y = hidden_y

func _process(delta):
	var target_y = shown_y if Input.is_key_pressed(KEY_TAB) else hidden_y
	position.y = lerp(position.y, target_y, clamp(delta * slide_speed, 0.0, 1.0))
