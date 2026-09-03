extends Node3D

@export var item_id: String = ""
@export var display_name: String = "Item"

func _ready():
	if has_node("NameLabel"):
		$NameLabel.text = display_name

func interact():
	var main_node = get_node("/root/Main")
	if main_node == null:
		return

	var was_needed = main_node.try_collect_item(item_id, display_name)
	if was_needed:
		queue_free()
