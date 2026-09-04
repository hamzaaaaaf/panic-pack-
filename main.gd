extends Node3D

@onready var timer = $FlightTimer
@onready var time_label = $UI/TimeLabel
@onready var packed_count_label = $UI/PackedCountLabel
@onready var interact_prompt_label = $UI/InteractPrompt
@onready var packing_list = $UI/PaperList/ItemList
@onready var escape_zone = $EscapeZone
@onready var start_screen = $UI/StartScreen
@onready var end_screen = $UI/EndScreen
@onready var end_result_label = $UI/EndScreen/VBox/ResultLabel
@onready var end_summary_label = $UI/EndScreen/VBox/SummaryLabel

# Keyed by the RigidBody3D's node name (e.g. "item_banana"), assigned once
# items_manager.gd finishes turning the scattered props into physics objects.
var required_items = []
var collected_items = []
var display_name_by_item = {}
var checklist_labels = {}

var taxi_arrived: bool = false
var game_over: bool = false
var game_started: bool = false

func _ready():
	randomize()

	# items_manager.gd (on the "Items" node, a child of this one) always
	# finishes its own _ready() before this one runs, so the group is
	# already populated here.
	var pool = get_tree().get_nodes_in_group("CollectiblePool")
	pool.shuffle()

	var required_count = min(randi_range(4, 5), pool.size())
	for i in range(required_count):
		var rb = pool[i]
		required_items.append(rb.name)
		display_name_by_item[rb.name] = rb.display_name

	build_packing_list_ui()
	update_packed_count_label()
	escape_zone.body_entered.connect(_on_escape_zone_body_entered)

	end_screen.visible = false
	start_screen.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	$UI/StartScreen/VBox/StartButton.pressed.connect(start_game)
	$UI/EndScreen/VBox/RestartButton.pressed.connect(restart_game)

	print("Panic Pack Started! Find your items before the timer runs out!")
	print("Packing list: ", required_items)

func start_game():
	start_screen.visible = false
	game_started = true
	timer.start()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func restart_game():
	get_tree().reload_current_scene()

func _process(_delta):
	if not game_started or taxi_arrived or game_over:
		return # Stop updating the packing phase once the taxi sequence takes over (or before it's begun)

	var time_left = timer.time_left
	@warning_ignore("integer_division")
	var minutes = int(time_left) / 60
	var seconds = int(time_left) % 60

	# Update your screen clock overlay
	time_label.text = "Flight Departure: %02d:%02d" % [minutes, seconds]

	# If the packing countdown clock hits absolute zero
	if time_left <= 0:
		trigger_game_over_missed_flight()

# Called by carryable_item.gd whenever the player interacts with an item.
# Returns true if it was a required packing-list item (so it should vanish).
func try_collect_item(item) -> bool:
	if not game_started or game_over or taxi_arrived:
		return false

	var item_name = item.name
	if not required_items.has(item_name):
		return false
	if collected_items.has(item_name):
		return false

	collected_items.append(item_name)
	print("Packed item: ", display_name_by_item[item_name], " (", collected_items.size(), "/", required_items.size(), ")")
	mark_checklist_item_collected(item_name)
	update_packed_count_label()

	if collected_items.size() >= required_items.size():
		trigger_taxi_arrival_sequence()

	return true

func build_packing_list_ui():
	for child in packing_list.get_children():
		child.queue_free()
	checklist_labels.clear()

	for item_name in required_items:
		var label = Label.new()
		label.text = "[ ] " + display_name_by_item[item_name]
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", Color.BLACK)
		packing_list.add_child(label)
		checklist_labels[item_name] = label

func mark_checklist_item_collected(item_name):
	if checklist_labels.has(item_name):
		var label = checklist_labels[item_name]
		label.text = "[x] " + display_name_by_item[item_name]
		label.add_theme_color_override("font_color", Color(0.1, 0.5, 0.15))

func update_packed_count_label():
	packed_count_label.text = "Packed: %d / %d" % [collected_items.size(), required_items.size()]

# Called every frame by player.gd so the on-screen prompt matches whatever
# is currently under the crosshair.
func set_interact_prompt(text: String):
	interact_prompt_label.text = text
	interact_prompt_label.visible = text != ""

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
	show_end_screen(
		"GAME OVER",
		"You missed your flight -- you only packed %d / %d items." % [collected_items.size(), required_items.size()],
		Color(0.95, 0.3, 0.3)
	)

func _on_escape_zone_body_entered(body):
	if taxi_arrived and not game_over and body is CharacterBody3D:
		trigger_win()

func trigger_win():
	game_over = true
	time_label.text = "YOU MADE YOUR FLIGHT! SAFE TRAVELS!"
	time_label.modulate = Color.GREEN
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	print("You made it out the door in time. Bon voyage!")
	show_end_screen(
		"YOU MADE YOUR FLIGHT!",
		"You packed all %d items and made it out the door in time." % required_items.size(),
		Color(0.4, 0.95, 0.5)
	)

func show_end_screen(title: String, summary: String, color: Color):
	end_result_label.text = title
	end_result_label.modulate = color
	end_summary_label.text = summary
	end_screen.visible = true
