extends Node2D

@onready var tile_map: TileMap = $TileMap
@onready var hero: Hero = $Hero
@onready var border_gradient: TextureRect = $Overlay/BorderGradient

var tilesize = 16

enum {
	MOVING,
	ACTION,
	SUCK
}
var gamestate = MOVING

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	match gamestate:
		MOVING:
			if Input.is_action_just_pressed("up"):
				try_move(hero, Vector2(0, -1))
			if Input.is_action_just_pressed("down"):
				try_move(hero, Vector2(0, 1))
			if Input.is_action_just_pressed("left"):
				try_move(hero, Vector2(-1, 0))
			if Input.is_action_just_pressed("right"):
				try_move(hero, Vector2(1, 0))
			if Input.is_action_just_pressed("action"):
				gamestate = ACTION
				border_gradient_alpha(1.0)
		ACTION:
			if Input.is_action_just_pressed("up"):
				try_attack_wall(hero, Vector2(0, -1))
				gamestate = MOVING
				border_gradient_alpha(0.0)
			if Input.is_action_just_pressed("down"):
				try_attack_wall(hero, Vector2(0, 1))
				gamestate = MOVING
				border_gradient_alpha(0.0)
			if Input.is_action_just_pressed("left"):
				try_attack_wall(hero, Vector2(-1, 0))
				gamestate = MOVING
				border_gradient_alpha(0.0)
			if Input.is_action_just_pressed("right"):
				try_attack_wall(hero, Vector2(1, 0))
				gamestate = MOVING
				border_gradient_alpha(0.0)
		
func try_move(actor: Actor, vector: Vector2) -> bool:
	var destination = actor.position + (vector * tilesize)
	var destination_cell = tile_map.local_to_map(destination)
	var destincation_cell_background_data = tile_map.get_cell_tile_data(1, destination_cell)
	var destination_cell_foreground_data = tile_map.get_cell_tile_data(2, destination_cell)
	if destination_cell_foreground_data:
		if destination_cell_foreground_data.terrain_set == 0 and destination_cell_foreground_data.terrain == 0: #wall
			return false
	if not destincation_cell_background_data: #no ground
		return false
	actor.move(vector)
	return true
	
func border_gradient_alpha(alpha: float) -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(border_gradient, "modulate:a", alpha, 0.25)
	
func try_attack_wall(actor: Actor, vector: Vector2) -> bool:
	var destination = actor.position + (vector * tilesize)
	var coords = tile_map.local_to_map(destination)
	var success = tile_map.try_attack_wall(coords)
	if success:
		actor.bump_anim(vector)
	return success
		
