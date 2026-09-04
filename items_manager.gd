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

# An item only gets shuffled between spawn points if its footprint AND height
# both stay under these -- picked from the real measured sizes of everything
# in the house (see the header comment on _shuffle_small_item_positions).
const SMALL_FOOTPRINT_MAX := 0.55
const SMALL_HEIGHT_MAX := 0.5

func _ready():
	randomize()

	var wrapped = []
	for item in get_children():
		if item.name == "item_radio":
			item.set_script(RADIO_SCRIPT)
			continue
		var rb = _physics_ify(item)
		if rb:
			wrapped.append(rb)

	_assign_collectible_pool(wrapped)
	_shuffle_small_item_positions(wrapped)

func _physics_ify(item: Node3D) -> RigidBody3D:
	var world_aabb = _compute_world_aabb(item)
	if world_aabb.size == Vector3.ZERO:
		return null # no mesh found under this item -- leave it alone rather than guess

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

	var footprint = max(size.x, size.z)
	var is_small = footprint < SMALL_FOOTPRINT_MAX and size.y < SMALL_HEIGHT_MAX

	rb.mass = OBSTACLE_MASS if is_obstacle else ITEM_MASS
	rb.linear_damp = 0.4
	rb.angular_damp = 0.6
	rb.display_name = _format_name(original_name)
	rb.is_obstacle = is_obstacle
	rb.is_small = is_small
	rb.spawn_position = origin
	rb.add_to_group("Carryable")

	return rb

# Items that exist as visually-identical duplicates (item_floor_lamp1,
# item_floor_lamp2, ...) never go on the packing list -- the player has no
# way to tell "Floor Lamp 1" apart from "Floor Lamp 2" in the world, so a
# required item like that would be impossible to fulfil correctly. They're
# still fully carryable, just never required. Chairs/big plants are excluded
# the same way they always were.
func _assign_collectible_pool(wrapped: Array):
	var counts = {}
	for rb in wrapped:
		if rb.is_obstacle:
			continue
		var base_key = _strip_trailing_digits(rb.name)
		counts[base_key] = counts.get(base_key, 0) + 1

	for rb in wrapped:
		if rb.is_obstacle:
			continue
		var base_key = _strip_trailing_digits(rb.name)
		if counts[base_key] == 1:
			rb.add_to_group("CollectiblePool")

func _strip_trailing_digits(text: String) -> String:
	var end = text.length()
	while end > 0 and text[end - 1].is_valid_int():
		end -= 1
	return text.substr(0, end)

func _format_name(raw: String) -> String:
	var cleaned = raw.trim_prefix("item_").capitalize()
	cleaned = cleaned.replace("Tv", "TV")
	return cleaned

# Randomizes layout WITHOUT inventing any new positions: every item you
# placed in the editor sits somewhere you already checked is valid (on a
# counter, a floor tile, wherever), so the only safe way to shuffle things is
# to swap items between each other's authored spots -- never generate a new
# one. Chairs, big plants, and the radio never move. Bigger non-obstacle
# items (a TV, a floor lamp, a microwave, ...) also stay put, since a spot
# picked for a mug on a shelf might not fit a floor lamp; "small" here means
# both a modest footprint AND a modest height (see the constants above),
# which was tuned against the real bounding boxes of everything in the house.
func _shuffle_small_item_positions(wrapped: Array):
	var small_items = []
	for rb in wrapped:
		if not rb.is_obstacle and rb.is_small:
			small_items.append(rb)

	var positions = []
	for rb in small_items:
		positions.append(rb.spawn_position)
	positions.shuffle()

	for i in range(small_items.size()):
		var rb = small_items[i]
		rb.global_transform = Transform3D(Basis.IDENTITY, positions[i])
		rb.linear_velocity = Vector3.ZERO
		rb.angular_velocity = Vector3.ZERO

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
