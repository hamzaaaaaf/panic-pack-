extends Node3D

# Runs once at startup and turns every prop scattered under this "Items" node
# into a real physics object: a RigidBody3D with gravity that can be pushed
# and carried around. The radio is left alone (fixed, not carryable). Chairs
# and big plants become movable obstacles but are never part of the random
# packing list. Everything else is both carryable AND eligible to be picked
# as one of this run's required packing-list items.

const CARRYABLE_SCRIPT = preload("res://carryable_item.gd")
const RADIO_SCRIPT = preload("res://radio_controller.gd")

const OBSTACLE_MASS := 6.0
const ITEM_MASS := 1.2
const MIN_SHAPE_SIZE := 0.08

func _ready():
	for item in get_children():
		if item.name == "item_radio":
			item.set_script(RADIO_SCRIPT)
			continue
		_physics_ify(item)

func _physics_ify(item: Node3D):
	var world_aabb = _compute_world_aabb(item)
	if world_aabb.size == Vector3.ZERO:
		return # no mesh found under this item -- leave it alone rather than guess

	var origin = item.global_transform.origin
	var item_basis = item.global_transform.basis
	var idx = item.get_index()
	var original_name = item.name

	remove_child(item)

	var rb = RigidBody3D.new()
	rb.name = original_name
	item.name = original_name + "_mesh"
	rb.set_script(CARRYABLE_SCRIPT)

	add_child(rb)
	move_child(rb, idx)
	rb.global_transform = Transform3D(Basis.IDENTITY, origin)

	rb.add_child(item)
	item.transform = Transform3D(item_basis, Vector3.ZERO)

	var box = BoxShape3D.new()
	var size = world_aabb.size
	size.x = max(size.x, MIN_SHAPE_SIZE)
	size.y = max(size.y, MIN_SHAPE_SIZE)
	size.z = max(size.z, MIN_SHAPE_SIZE)
	box.size = size

	var collision_shape = CollisionShape3D.new()
	collision_shape.shape = box
	collision_shape.position = world_aabb.get_center() - origin
	rb.add_child(collision_shape)

	# The prop's original StaticBody3D(s) would otherwise sit inside the new
	# RigidBody3D as extra, non-dynamic colliders -- neuter every one of them
	# instead of deleting them so we don't have to hunt down shape resources.
	# Multi-piece props (a burger's patty/cheese/buns, a cake's slices, ...)
	# ship with ONE StaticBody3D per piece, not just one for the whole prop --
	# leaving any of them active meant a "static" collider was being dragged
	# around by the new RigidBody3D every frame, which is what caused items
	# like the burger and cake to phase through the floor or fling away.
	var old_static_bodies = []
	_find_static_bodies(item, old_static_bodies)
	for old_static_body in old_static_bodies:
		old_static_body.collision_layer = 0
		old_static_body.collision_mask = 0

	var is_chair = original_name.begins_with("item_dining_chair") or original_name == "item_computer_chair"
	var is_big_plant = original_name.begins_with("item_big_plant")
	var is_obstacle = is_chair or is_big_plant

	rb.mass = OBSTACLE_MASS if is_obstacle else ITEM_MASS
	rb.linear_damp = 0.4
	rb.angular_damp = 0.6
	rb.display_name = _format_name(original_name)
	rb.is_obstacle = is_obstacle
	rb.add_to_group("Carryable")
	if not is_obstacle:
		rb.add_to_group("CollectiblePool")

func _format_name(raw: String) -> String:
	var cleaned = raw.trim_prefix("item_").capitalize()
	cleaned = cleaned.replace("Tv", "TV")
	return cleaned

func _compute_world_aabb(node: Node3D) -> AABB:
	var meshes = []
	_find_mesh_instances(node, meshes)

	var result := AABB()
	var first := true
	for mesh_instance in meshes:
		var local_aabb: AABB = mesh_instance.get_aabb()
		var xform: Transform3D = mesh_instance.global_transform
		for i in range(8):
			var corner = xform * local_aabb.get_endpoint(i)
			if first:
				result = AABB(corner, Vector3.ZERO)
				first = false
			else:
				result = result.expand(corner)
	return result

func _find_mesh_instances(node: Node, result: Array):
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		_find_mesh_instances(child, result)

func _find_static_bodies(node: Node, result: Array):
	if node is StaticBody3D:
		result.append(node)
	for child in node.get_children():
		_find_static_bodies(child, result)
