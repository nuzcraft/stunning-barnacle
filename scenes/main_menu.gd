extends Control

@onready var high_scores_label: RichTextLabel = $HighScoresLabel

var game_data = GameData.new()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if ResourceLoader.exists("user://high_scores_file.tres"):
		game_data = ResourceLoader.load("user://high_scores_file.tres")
	update_high_scores_label()
	$VBoxContainer/HBoxContainer/StartButton.grab_focus()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_start_button_pressed() -> void:
	SoundPlayer.play_sound(SoundPlayer.CLICK_3)
	get_tree().change_scene_to_file("res://scenes/world.tscn")

func _on_exit_button_pressed() -> void:
	SoundPlayer.play_sound(SoundPlayer.CLICK_3)
	get_tree().quit()
	
func update_high_scores_label():
	high_scores_label.clear()
	game_data.high_scores.sort()
	game_data.high_scores.reverse()
	for x in (10 - game_data.high_scores.size()):
		game_data.high_scores.append(0)
	high_scores_label.append_text("[p align=center]High Scores\n")
	for x in range(10):
		var i = x + 1
		var color = "white"
		if i == 1:
			color = "gold"
		elif i == 2:
			color = "silver"
		elif i == 3:
			color = "saddlebrown"
		high_scores_label.append_text("[color=%s]#%d: %d[/color]\n" % [color, i, game_data.high_scores[x]])


func _on_start_button_mouse_entered() -> void:
	SoundPlayer.play_sound(SoundPlayer.ROLLOVER_2)


func _on_exit_button_mouse_entered() -> void:
	SoundPlayer.play_sound(SoundPlayer.ROLLOVER_2)
