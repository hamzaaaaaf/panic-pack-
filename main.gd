extends Node3D

@onready var timer = $FlightTimer
@onready var time_label = $UI/TimeLabel

# Placeholder counts for your packing list (We will wire real objects here later!)
var total_items_needed: int = 3
var items_collected: int = 0

var taxi_arrived: bool = false

func _ready():
	# Update our user interface text on frame one
	update_ui_display()
	print("Panic Pack Started! Find your items before the timer runs out!")

func _process(_delta):
	if taxi_arrived:
		return # Stop updating the packing phase once the taxi sequence takes over
		
	var time_left = timer.time_left
	var minutes = int(time_left) / 60
	var seconds = int(time_left) % 60
	
	# Update your screen clock overlay
	time_label.text = "Flight Departure: %02d:%02d" % [minutes, seconds]
	
	# If the packing countdown clock hits absolute zero
	if time_left <= 0:
		trigger_game_over_missed_flight()

# This is a custom helper function our future Loot items will talk to!
func collect_item(item_name: String):
	items_collected += 1
	print("Packed item: ", item_name, " (", items_collected, "/", total_items_needed, ")")
	update_ui_display()

func update_ui_display():
	# If we haven't found everything yet, show packing progress
	if items_collected < total_items_needed:
		print("Checking items... Keep searching!")
	else:
		# If everything is packed, unlock the front exit!
		trigger_taxi_arrival_sequence()

func trigger_taxi_arrival_sequence():
	taxi_arrived = true
	timer.stop() # Pause the main countdown
	
	time_label.text = "TAXI ARRIVED! SPRINT TO THE FRONT DOOR!"
	time_label.modulate = Color.GREEN # Turn the clock bright green!
	
	print("BEEP BEEP! The getaway car is idling outside!")
	
	# Computer Science Search: Find our designated exit door in the world and force it open!
	var exit_doors = get_tree().get_nodes_in_group("ExitDoor")
	for door in exit_doors:
		if door.has_method("interact"):
			# Force the door wide open automatically so the player can escape to the yard!
			door.interact()

func trigger_game_over_missed_flight():
	taxi_arrived = true
	time_label.text = "GAME OVER: YOU MISSED YOUR FLIGHT!"
	time_label.modulate = Color.RED
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE) # Release the mouse pointer
	print("Too slow! Your plane took off without you.")
