extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.003
const CARRY_MAX_SPEED = 8.0
const PUSH_IMPULSE = 2.0

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var camera = $Camera3D
@onready var animation_player: AnimationPlayer = $"Root Scene/AnimationPlayer"
@onready var carry_point = $Camera3D/CarryPoint
@onready var footstep_player: AudioStreamPlayer = $FootstepPlayer

var held_object: RigidBody3D = null
var interact_anim_playing: bool = false
var footstep_timer: float = 0.0

func _ready():
	# main.gd owns mouse mode -- it starts visible for the start screen and
	# captures it once start_game() runs.
	footstep_player.stream = _generate_footstep_stream()

func _unhandled_input(event):
	var main_node = get_node_or_null("/root/Main")
	if main_node == null or not main_node.game_started or main_node.game_over:
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func _process(_delta):
	_update_interact_prompt()

func _physics_process(delta):
	var main_node = get_node("/root/Main")
	if main_node and (main_node.game_over or not main_node.game_started):
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
	_push_away_rigid_bodies()

	# Handle animations based on movement vectors (unless the reach/grab
	# animation is mid-playback -- let that finish before walk/idle takes over)
	if not interact_anim_playing:
		if velocity.length() > 0.1:
			animation_player.play("CharacterArmature|Walk")
		else:
			animation_player.pause()

	_update_footsteps(delta)

	if held_object:
		_update_held_object(delta)

	# INTERACTION LOGIC
	if Input.is_action_just_pressed("interact"):
		if held_object:
			drop_held_object()
		elif $Camera3D/RayCast3D.is_colliding():
			var hit_object = $Camera3D/RayCast3D.get_collider()

			# The raycast's cached collider can briefly point at something
			# that was just queue_free()'d (e.g. a packed item) until physics
			# catches up next step -- bail out safely instead of crashing.
			if not is_instance_valid(hit_object):
				return

			if hit_object.is_in_group("Carryable"):
				hit_object.interact()
			else:
				var target = hit_object.get_parent()
				while target != null:
					if target.has_method("interact"):
						# Check if this door belongs to the locked exit group
						if target.is_in_group("ExitDoor"):
							var game_manager = get_node("/root/Main")
							if game_manager and game_manager.taxi_arrived == false:
								print("The front door is locked tight! Find everything on your packing list first.")
								break
						# Open normal interior room doors, unlocked exits, toggle the radio, etc.
						target.interact()
						break
					target = target.get_parent()

# --- Carrying ---------------------------------------------------------

func pickup_object(obj: RigidBody3D):
	if held_object != null or obj == null:
		return
	held_object = obj
	held_object.gravity_scale = 0.0
	held_object.linear_velocity = Vector3.ZERO
	held_object.angular_velocity = Vector3.ZERO
	play_interact_animation()

func drop_held_object():
	if held_object == null:
		return
	held_object.gravity_scale = 1.0
	held_object = null
	play_interact_animation()

func _update_held_object(delta):
	var target_pos = carry_point.global_position
	var offset = target_pos - held_object.global_position
	var desired_velocity = offset / max(delta, 0.001)
	if desired_velocity.length() > CARRY_MAX_SPEED:
		desired_velocity = desired_velocity.normalized() * CARRY_MAX_SPEED
	held_object.linear_velocity = desired_velocity
	# Keep it from tumbling wildly while it's being carried around.
	held_object.angular_velocity = held_object.angular_velocity.lerp(Vector3.ZERO, clamp(delta * 8.0, 0.0, 1.0))

# Nudge any RigidBody3D the player walks into -- separate from carrying,
# this is what makes clutter on the floor scatter as you push through it.
func _push_away_rigid_bodies():
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider is RigidBody3D and collider != held_object:
			var push_dir = -collision.get_normal()
			collider.apply_central_impulse(push_dir * PUSH_IMPULSE)

# --- Animation ----------------------------------------------------------

func play_interact_animation():
	interact_anim_playing = true
	animation_player.play("CharacterArmature|Interact")
	var anim = animation_player.get_animation("CharacterArmature|Interact")
	var length = anim.length if anim else 1.0
	await get_tree().create_timer(length).timeout
	interact_anim_playing = false

# --- On-screen interact prompt -------------------------------------------

func _update_interact_prompt():
	var main_node = get_node_or_null("/root/Main")
	if main_node == null:
		return
	if not main_node.game_started or main_node.game_over:
		main_node.set_interact_prompt("")
		return

	var prompt = ""
	if held_object:
		prompt = "[E] Drop"
	elif $Camera3D/RayCast3D.is_colliding():
		var hit_object = $Camera3D/RayCast3D.get_collider()
		if not is_instance_valid(hit_object):
			main_node.set_interact_prompt("")
			return
		if hit_object.is_in_group("Carryable"):
			if not hit_object.is_obstacle and main_node.required_items.has(hit_object.name) and not main_node.collected_items.has(hit_object.name):
				prompt = "[E] Pack " + hit_object.display_name
			else:
				prompt = "[E] Pick up " + hit_object.display_name
		else:
			var target = hit_object.get_parent()
			while target != null:
				if target.has_method("interact"):
					if target.is_in_group("ExitDoor") and not main_node.taxi_arrived:
						prompt = "Locked -- find everything on your packing list"
					elif target.is_in_group("ExitDoor"):
						prompt = "[E] Open the front door"
					else:
						prompt = "[E] Interact"
					break
				target = target.get_parent()

	main_node.set_interact_prompt(prompt)

# --- Footsteps ------------------------------------------------------------

func _update_footsteps(delta):
	var horizontal_speed = Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and horizontal_speed > 0.5:
		footstep_timer -= delta
		if footstep_timer <= 0.0:
			footstep_player.pitch_scale = randf_range(0.9, 1.1)
			footstep_player.play()
			var interval = 0.5 - (horizontal_speed - 0.5) * 0.05
			footstep_timer = clamp(interval, 0.28, 0.5)
	else:
		footstep_timer = 0.0

# Synthesizes a short, bass-heavy "thump" so footsteps work with zero imported
# audio assets. Swap footstep_player.stream for a real SFX file any time.
func _generate_footstep_stream() -> AudioStreamWAV:
	var mix_rate = 22050
	var duration = 0.18
	var sample_count = int(mix_rate * duration)
	var bytes = PackedByteArray()
	bytes.resize(sample_count * 2)

	var rng = RandomNumberGenerator.new()
	rng.randomize()

	# A pitch-dropping low sine (like a soft kick drum) carries the weight...
	var start_freq = 150.0
	var end_freq = 45.0
	var phase = 0.0
	# ...with a touch of heavily low-passed noise on top for foot-on-ground texture.
	var noise_prev = 0.0

	for i in range(sample_count):
		var t = float(i) / sample_count
		var envelope = pow(1.0 - t, 4.0)

		var freq = lerp(start_freq, end_freq, t)
		phase += freq / mix_rate
		var thump = sin(phase * TAU) * envelope

		var noise = rng.randf_range(-1.0, 1.0)
		noise_prev = lerp(noise_prev, noise, 0.15) # aggressive low-pass -- dull, not hissy
		var texture = noise_prev * envelope

		var sample = clamp(thump * 0.8 + texture * 0.2, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 32767.0))

	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = bytes
	return stream
