extends Node2D

@onready var tile_map: TileMap = $TileMap
@onready var hero: Hero = $Hero
@onready var border_gradient: TextureRect = $Overlay/BorderGradient
@onready var move_control: Control = $Overlay/MoveControl
@onready var action_control: Control = $Overlay/ActionControl

var tilesize = 16
var astar_grid = AStarGrid2D.new()

enum {
	MOVING,
	ACTION,
	SUCK
}
var gamestate = MOVING
var turn_taken = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	prep_astar_grid()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.target = tile_map.local_to_map(hero.position)
		enemy.died.connect(_on_actor_died)
	hero.died.connect(_on_actor_died)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not turn_taken:
		match gamestate:
			MOVING:
				hero_moving()
			ACTION:
				hero_action()
	if turn_taken:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			var path: Array[Vector2i] = astar_grid.get_id_path(tile_map.local_to_map(enemy.position), enemy.target)
			if path.size() > 1:
				var vector = path[1] - path[0]
				if not try_attack(enemy, vector):
					try_move(enemy, vector)
		for enemy in get_tree().get_nodes_in_group("enemies"):
			enemy.target = tile_map.local_to_map(hero.position)
		turn_taken = false
		
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
	
func move_control_alpha(alpha: float) -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(move_control, "modulate:a", alpha, 0.25)
	
func action_control_alpha(alpha: float) -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(action_control, "modulate:a", alpha, 0.25)
	set_action_control_labels()
	
func set_action_control_labels() -> void:
	var hbox: HBoxContainer = action_control.get_node("HBoxContainer")
	hbox.get_node("upLabel").text = "up:" + hero.action["up"]
	hbox.get_node("downLabel").text = "down:" + hero.action["down"]
	hbox.get_node("leftLabel").text = "left:" + hero.action["left"]
	hbox.get_node("rightLabel").text = "right:" + hero.action["right"]
	
func try_build(actor: Actor, vector: Vector2) -> bool:
	var destination = actor.position + (vector * tilesize)
	var coords = tile_map.local_to_map(destination)
	for act: Actor in get_tree().get_nodes_in_group("actors"):
		if actor != act:
			var act_coords = tile_map.local_to_map(act.position)
			if act_coords == coords:
				return false #actor on spot
	var success = tile_map.try_build_wall(coords)
	if success:
		actor.bump_anim(vector)
		astar_grid.set_point_solid(coords, not tile_map.is_coord_walkable(coords))
	return success
	
func try_attack(actor: Actor, vector: Vector2) -> bool:
	var destination = actor.position + (vector * tilesize)
	var coords = tile_map.local_to_map(destination)
	for act: Actor in get_tree().get_nodes_in_group("actors"):
		if actor != act:
			var act_coords = tile_map.local_to_map(act.position)
			if act_coords == coords:
				act.damage(1)
				actor.bump_anim(vector)
				return true
	var success = tile_map.try_attack_wall(coords)
	if success:
		actor.bump_anim(vector)
		astar_grid.set_point_solid(coords, not tile_map.is_coord_walkable(coords))
	return success
	
func prep_astar_grid() -> void:
	astar_grid.region = Rect2i(0, 0, 36, 20)
	astar_grid.cell_size = Vector2(tilesize, tilesize)
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar_grid.update()
	for x in astar_grid.region.end.x:
		for y in astar_grid.region.end.y:
			if not tile_map.is_coord_walkable(Vector2(x, y)):
				astar_grid.set_point_solid(Vector2(x, y))
				
func hero_moving():
	if Input.is_action_just_pressed("up"):
		turn_taken = try_move(hero, Vector2(0, -1))
	if Input.is_action_just_pressed("down"):
		turn_taken = try_move(hero, Vector2(0, 1))
	if Input.is_action_just_pressed("left"):
		turn_taken = try_move(hero, Vector2(-1, 0))
	if Input.is_action_just_pressed("right"):
		turn_taken = try_move(hero, Vector2(1, 0))
	if Input.is_action_just_pressed("action"):
		gamestate = ACTION
		border_gradient_alpha(1.0)
		move_control_alpha(0.0)
		action_control_alpha(1.0)
		
func hero_action():
	if Input.is_action_just_pressed("up"):
		turn_taken = take_action(hero, hero.action["up"], Vector2(0, -1))
		gamestate = MOVING
		border_gradient_alpha(0.0)
		move_control_alpha(1.0)
		action_control_alpha(0.0)
	if Input.is_action_just_pressed("down"):
		turn_taken = take_action(hero, hero.action["down"], Vector2(0, 1))
		gamestate = MOVING
		border_gradient_alpha(0.0)
		move_control_alpha(1.0)
		action_control_alpha(0.0)
	if Input.is_action_just_pressed("left"):
		turn_taken = take_action(hero, hero.action["left"], Vector2(-1, 0))
		gamestate = MOVING
		border_gradient_alpha(0.0)
		move_control_alpha(1.0)
		action_control_alpha(0.0)
	if Input.is_action_just_pressed("right"):
		turn_taken = take_action(hero, hero.action["right"], Vector2(1, 0))
		gamestate = MOVING
		border_gradient_alpha(0.0)
		move_control_alpha(1.0)
		action_control_alpha(0.0)
	if Input.is_action_just_pressed("escape") or Input.is_action_just_pressed("action"):
		turn_taken = false
		gamestate = MOVING
		border_gradient_alpha(0.0)
		move_control_alpha(1.0)
		action_control_alpha(0.0)
		
func take_action(actor: Actor, action: String, vector: Vector2) -> bool:
	if action == "attack":
		return try_attack(actor, vector)
	elif action == "build":
		return try_build(actor, vector)
	return false
	
func _on_actor_died(actor: Actor) -> void:
	await get_tree().process_frame
	if actor == hero:
		get_tree().reload_current_scene()
	actor.queue_free()
	
		
