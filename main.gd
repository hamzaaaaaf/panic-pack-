extends Node3D

@onready var timer = $FlightTimer
@onready var time_label = $UI/TimeLabel
@onready var packing_list = $UI/PaperList/ItemList
@onready var escape_zone = $EscapeZone

# The full set of items that could possibly be asked for. Each run only picks
# a handful of these as the real packing list -- the rest just sit around the
# house as clutter/decoys.
var item_pool = [
	{"id": "passport", "name": "Passport"},
	{"id": "phone_charger", "name": "Phone Charger"},
	{"id": "toothbrush", "name": "Toothbrush"},
	{"id": "sunglasses", "name": "Sunglasses"},
	{"id": "wallet", "name": "Wallet"},
	{"id": "camera", "name": "Camera"},
	{"id": "headphones", "name": "Headphones"},
	{"id": "medication", "name": "Medication"},
	{"id": "travel_adapter", "name": "Travel Adapter"},
	{"id": "swimsuit", "name": "Swimsuit"},
]

var required_items = []
var collected_items = []
var item_name_by_id = {}
var checklist_labels = {}

var taxi_arrived: bool = false
var game_over: bool = false

func _ready():
	randomize()

	for entry in item_pool:
		item_name_by_id[entry["id"]] = entry["name"]

	var pool_ids = []
	for entry in item_pool:
		pool_ids.append(entry["id"])
	pool_ids.shuffle()

	var required_count = randi_range(4, 5)
	required_items = pool_ids.slice(0, required_count)

	build_packing_list_ui()
	escape_zone.body_entered.connect(_on_escape_zone_body_entered)

	print("Panic Pack Started! Find your items before the timer runs out!")
	print("Packing list: ", required_items)

func _process(_delta):
	if taxi_arrived or game_over:
		return # Stop updating the packing phase once the taxi sequence takes over

	var time_left = timer.time_left
	var minutes = int(time_left) / 60
	var seconds = int(time_left) % 60

	# Update your screen clock overlay
	time_label.text = "Flight Departure: %02d:%02d" % [minutes, seconds]

	# If the packing countdown clock hits absolute zero
	if time_left <= 0:
		trigger_game_over_missed_flight()

# Called by item_pickup.gd whenever the player interacts with a pickup.
# Returns true if the item was on the packing list (and should vanish from the world).
func try_collect_item(item_id: String, display_name: String) -> bool:
	if game_over or taxi_arrived:
		return false

	if not required_items.has(item_id):
		print("Picked up ", display_name, " but it's not on your packing list.")
		return false

	if collected_items.has(item_id):
		return false

	collected_items.append(item_id)
	print("Packed item: ", display_name, " (", collected_items.size(), "/", required_items.size(), ")")
	mark_checklist_item_collected(item_id)

	if collected_items.size() >= required_items.size():
		trigger_taxi_arrival_sequence()

	return true

func build_packing_list_ui():
	for child in packing_list.get_children():
		child.queue_free()
	checklist_labels.clear()

	for item_id in required_items:
		var label = Label.new()
		label.text = "[ ] " + item_name_by_id[item_id]
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", Color.BLACK)
		packing_list.add_child(label)
		checklist_labels[item_id] = label

func mark_checklist_item_collected(item_id):
	if checklist_labels.has(item_id):
		var label = checklist_labels[item_id]
		label.text = "[x] " + item_name_by_id[item_id]
		label.add_theme_color_override("font_color", Color(0.1, 0.5, 0.15))

func trigger_taxi_arrival_sequence():
	taxi_arrived = true
	timer.stop() # Pause the main countdown

	time_label.text = "TAXI ARRIVED! SPRINT TO THE FRONT DOOR!"
	time_label.modulate = Color.GREEN # Turn the clock bright green!

	print("BEEP BEEP! The getaway car is idling outside!")

	# Find our designated exit door in the world and force it open!
	var exit_doors = get_tree().get_nodes_in_group("ExitDoor")
	for door in exit_doors:
		if door.has_method("interact"):
			door.interact()

func trigger_game_over_missed_flight():
	game_over = true
	time_label.text = "GAME OVER: YOU MISSED YOUR FLIGHT!"
	time_label.modulate = Color.RED
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE) # Release the mouse pointer
	print("Too slow! Your plane took off without you.")

func _on_escape_zone_body_entered(body):
	if taxi_arrived and not game_over and body is CharacterBody3D:
		trigger_win()

func trigger_win():
	game_over = true
	time_label.text = "YOU MADE YOUR FLIGHT! SAFE TRAVELS!"
	time_label.modulate = Color.GREEN
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	print("You made it out the door in time. Bon voyage!")
