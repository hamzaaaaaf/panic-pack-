extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.003

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var camera = $Camera3D
@onready var animation_player: AnimationPlayer = $"Root Scene/AnimationPlayer"

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func _physics_process(delta):
	var main_node = get_node("/root/Main")
	if main_node and main_node.game_over:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	# Add the gravity if the player is in mid-air
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump if the spacebar is pressed
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction using WSAD keys we mapped earlier
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

	# Handle animations based on movement vectors
	if velocity.length() > 0.1:
		animation_player.play("CharacterArmature|Walk")
	else:
		animation_player.pause()

	# INTERACTION LOGIC
	if Input.is_action_just_pressed("interact"):
		if $Camera3D/RayCast3D.is_colliding():
			var hit_object = $Camera3D/RayCast3D.get_collider()
			
			var target = hit_object.get_parent()
			while target != null:
				if target.has_method("interact"):
					# Check if this door belongs to the locked exit group
					if target.is_in_group("ExitDoor"):
						var game_manager = get_node("/root/Main")
						if game_manager and game_manager.taxi_arrived == false:
							print("The front door is locked tight! Find everything on your packing list first.")
							return # STOP RIGHT HERE so the door remains locked!
					
					# Open normal interior room doors, unlocked exits, or pick up items
					target.interact()
					break
				target = target.get_parent()
