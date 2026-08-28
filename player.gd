extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.003

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var camera = $Camera3D
@onready var animation_player: AnimationPlayer = $"Root Scene/AnimationPlayer"



func _ready():
	# This locks your mouse cursor inside the game window so you can look around seamlessly
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	# If the player moves the mouse, rotate the camera
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		# Prevent the player from flipping their head upside down!
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func _physics_process(delta):
	# Add the gravity if the player is in mid-air
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump if the spacebar is pressed
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction using WSAD keys we mapped earlier
	# If you haven't mapped 'move_forward', etc. yet, ui_left/right/up/down will use arrow keys
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)


	move_and_slide()

	# Check if the player is physically moving on the ground
	if velocity.length() > 0.1:
		# Play the walk animation track normally
		animation_player.play("CharacterArmature|Walk")
	else:
		# Instead of shifting to idle, pause the walk animation exactly where it is!
		animation_player.pause()
