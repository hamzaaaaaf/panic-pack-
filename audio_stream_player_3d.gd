extends AudioStreamPlayer3D

@onready var raycast: RayCast3D = $RayCast3D

# Target settings
var target_cutoff: float = 20000.0
var target_volume: float = -20.0       # Matches your quiet base volume from the inspector

# Config values
var clear_cutoff: float = 20000.0
var muffled_cutoff: float = 300.0      # Low value = deep wall muffle
var base_volume: float = -20.0         # How quiet it is inside the radio room
var muted_volume: float = -80.0        # -80 dB is functionally absolute silence in Godot

var transition_speed: float = 7.0      # How fast the audio shifts when crossing the doorway

func _ready() -> void:
	# Add the radio's own static body to the raycast's exception list 
	# so it doesn't accidentally collide with itself!
	var parent_body = _find_first_static_body(get_parent())
	if parent_body:
		raycast.add_exception(parent_body)
	
	attenuation_filter_cutoff_hz = clear_cutoff
	volume_db = base_volume

func _physics_process(delta: float) -> void:
	var listener = get_viewport().get_camera_3d()
	if listener:
		# Continually point the raycast right at the player's head
		raycast.target_position = raycast.to_local(listener.global_position)
		
		# If a wall is physically blocking the line of sight, drop volume and muffle it
		if raycast.is_colliding():
			target_cutoff = muffled_cutoff
			target_volume = muted_volume
		else:
			target_cutoff = clear_cutoff
			target_volume = base_volume
		
		# Smoothly slide the muffle frequency and the volume so it doesn't pop suddenly
		attenuation_filter_cutoff_hz = lerp(attenuation_filter_cutoff_hz, target_cutoff, transition_speed * delta)
		volume_db = lerp(volume_db, target_volume, transition_speed * delta)

func _find_first_static_body(node: Node) -> StaticBody3D:
	if node is StaticBody3D:
		return node
	for child in node.get_children():
		var found = _find_first_static_body(child)
		if found:
			return found
	return null
