extends Node3D

# The radio is deliberately NOT wrapped in physics by items_manager.gd --
# it stays fixed in place. Interacting with it just toggles its music.

func interact():
	var audio_player = get_node_or_null("AudioStreamPlayer3D")
	if audio_player == null:
		return

	if audio_player.playing:
		audio_player.stop()
		print("You switch the radio off.")
	else:
		audio_player.play()
		print("You switch the radio on.")
