extends Node

const CLICK_1 = preload("res://assets/sounds/click1.ogg")
const ROLLOVER_1 = preload("res://assets/sounds/rollover1.ogg")
const CLICK_3 = preload("res://assets/sounds/click3.ogg")
const ROLLOVER_2 = preload("res://assets/sounds/rollover2.ogg")
const PEP_SOUND_3 = preload("res://assets/sounds/pepSound3.ogg")
const SWITCH_8 = preload("res://assets/sounds/switch8.ogg")
const SWITCH_11 = preload("res://assets/sounds/switch11.ogg")
const FOOTSTEP_GRASS_002 = preload("res://assets/sounds/footstep_grass_002.ogg")
const IMPACT_MINING_002 = preload("res://assets/sounds/impactMining_002.ogg")
const IMPACT_SOFT_HEAVY_003 = preload("res://assets/sounds/impactSoft_heavy_003.ogg")
const DOOR_CLOSE_4 = preload("res://assets/sounds/doorClose_4.ogg")
const IMPACT_PLANK_MEDIUM_004 = preload("res://assets/sounds/impactPlank_medium_004.ogg")
const SUCK = preload("res://assets/sounds/suck.wav")

@onready var audioPlayers := $AudioPlayers
@onready var musicPlayers := $MusicPlayers

func play_sound(sound):	
	for audioStreamPlayer in audioPlayers.get_children():
		if not audioStreamPlayer.playing:
			audioStreamPlayer.stream = sound
			audioStreamPlayer.play()
			break

func play_music(sound):	
	for audioStreamPlayer in musicPlayers.get_children():
		if not audioStreamPlayer.playing:
			audioStreamPlayer.stream = sound
			audioStreamPlayer.play()
			break
			
func stop_music():
	for audioStreamPlayer in musicPlayers.get_children():
		if audioStreamPlayer.playing:
			audioStreamPlayer.stop()
			
func is_sound_playing() -> bool:
	var playing = false
	for audioStreamPlayer in audioPlayers.get_children():
		if audioStreamPlayer.playing:
			return true
	return false
