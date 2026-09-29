extends Control
## Start menu: new game, sound/music toggles, high score table.


func _ready() -> void:
	%Scores.text = "HIGH SCORES"
	for i in Save.scores.size():
		%Scores.text += "\n%d.  %s   %d" % [i + 1, Save.scores[i].name, Save.scores[i].score]
	if Save.scores.is_empty():
		%Scores.text += "\nno scores yet"
	# Set toggles before connecting so loading state doesn't fire the handlers.
	%SoundToggle.button_pressed = Save.sound_enabled
	%MusicToggle.button_pressed = Save.music_enabled
	%Start.pressed.connect(_on_start)
	%SoundToggle.toggled.connect(_on_sound_toggled)
	%MusicToggle.toggled.connect(_on_music_toggled)
	_update_labels()
	Sound.update_music()


func _on_start() -> void:
	Sound.play("click")
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_sound_toggled(on: bool) -> void:
	Save.sound_enabled = on
	Save.save_file()
	_update_labels()
	Sound.play("click")


func _on_music_toggled(on: bool) -> void:
	Save.music_enabled = on
	Save.save_file()
	_update_labels()
	Sound.update_music()


func _update_labels() -> void:
	%SoundToggle.text = "Sound: %s" % ("ON" if Save.sound_enabled else "OFF")
	%MusicToggle.text = "Music: %s" % ("ON" if Save.music_enabled else "OFF")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:  # Android back button on menu = exit app
		get_tree().quit()
