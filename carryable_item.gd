extends RigidBody3D

# Set by items_manager.gd right after this item is wrapped in physics.
var display_name: String = ""
var is_obstacle: bool = false
var is_small: bool = false
var spawn_position: Vector3 = Vector3.ZERO # the position it was authored at in the editor

func interact():
	var main_node = get_node_or_null("/root/Main")
	var player = get_node_or_null("/root/Main/Player")

	# Required packing-list items get instantly packed away instead of carried.
	if not is_obstacle and main_node and main_node.try_collect_item(self):
		if player:
			player.play_interact_animation()
		queue_free()
		return

	if player:
		player.pickup_object(self)
