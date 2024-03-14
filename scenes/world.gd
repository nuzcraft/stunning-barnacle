extends Node2D

@onready var tile_map: TileMap = $TileMap
@onready var hero: Hero = $Hero
@onready var border_gradient: TextureRect = $Overlay/BorderGradient
@onready var move_control: Control = $Overlay/MoveControl
@onready var action_control: Control = $Overlay/ActionControl
@onready var suck_control: Control = $Overlay/SuckControl
@onready var lighthouse: Lighthouse = $Lighthouse
@onready var builder_spawners: Node = $BuilderSpawners
@onready var enemy_spawners: Node = $EnemySpawners
@onready var turn_label: Label = $Overlay/TurnLabel
@onready var pause_and_game_over: CanvasLayer = $PauseAndGameOver
@onready var resume_button: Button = $PauseAndGameOver/VBoxContainer/HBoxContainer/ResumeButton
@onready var game_over_label: Label = $PauseAndGameOver/VBoxContainer/GameOverLabel

const SUCK_EFFECT = preload("res://scenes/effects/suck.tscn")
const FIRE = preload("res://scenes/effects/fire.tscn")
const TELEPORT_EFFECT = preload("res://scenes/effects/teleport_effect.tscn")
const BUILDER = preload("res://scenes/actor/builder.tscn")
const ENEMY = preload("res://scenes/actor/enemy.tscn")
const FIRE_ENEMY = preload("res://scenes/actor/fire_enemy.tscn")
const TELEPORT_ENEMY = preload("res://scenes/actor/teleport_enemy.tscn")
const magenta: Color = "#f92672"
const blue: Color = "#66d9ef"

enum {
	MOVING,
	ACTION,
	SUCK
}

var tilesize = 16
var astar_grid = AStarGrid2D.new()
var astar_grid_2 = AStarGrid2D.new()

var gamestate = MOVING
var turn_taken = false
var num_turns = -1
var builders_to_spawn = 0

var enemy_spawn_base_multiplier = 1.5
var enemy_spawn_base = 2
var enemies_to_spawn = 0
var turns_till_enemy_spawn = 0

var paused = false
var game_data = GameData.new()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	randomize()
	prep_astar_grids()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.target = tile_map.local_to_map(lighthouse.position)
		enemy.died.connect(_on_actor_died)
	for builder in get_tree().get_nodes_in_group("builders"):
		builder.target = tile_map.nearest_broken_wall(tile_map.local_to_map(builder.position), builder.target_radius)
		builder.died.connect(_on_actor_died)
	for lighthouse in get_tree().get_nodes_in_group("lighthouses"):
		lighthouse.died.connect(_on_actor_died)
	hero.died.connect(_on_actor_died)
	if ResourceLoader.exists("user://high_scores_file.tres"):
		game_data = ResourceLoader.load("user://high_scores_file.tres")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	set_turn_label()
	if not turn_taken:
		match gamestate:
			MOVING:
				hero_moving()
			ACTION:
				hero_action()
			SUCK:
				hero_suck()
	if turn_taken:
		# do things
		for builder in get_tree().get_nodes_in_group("builders"):
			var builder_coords = tile_map.local_to_map(builder.position)
			var path: Array[Vector2i] = astar_grid_2.get_id_path(builder_coords, builder.target)
			if not path and builder_coords != builder.target: # target is not reachable or is a wall
				var new_path: Array[Vector2i]
				for cell in tile_map.get_surrounding_cells(builder.target):
					new_path = astar_grid_2.get_id_path(builder_coords, cell)
					if new_path and (not path or (new_path.size() + 1) < path.size()):
						path = new_path
						path.append(builder.target)			
			if path.size() > 1:
				var vector = path[1] - path[0]
				if path.size() == 2:
					try_build(builder, vector)
				else:
					try_move(builder, vector)
		# spawn stuff
		if num_turns % 15 == 0 and (get_tree().get_nodes_in_group("builders").size() + builders_to_spawn) < 4:
			builders_to_spawn += 1
		if builders_to_spawn > 0:
			try_spawn_builder()
		
		if get_tree().get_nodes_in_group("enemies").size() == 0 and enemies_to_spawn == 0:
			if turns_till_enemy_spawn == 0:
				enemies_to_spawn = enemy_spawn_base
				enemy_spawn_base = ceili(enemy_spawn_base * enemy_spawn_base_multiplier)
				enemy_spawn_base_multiplier = max(enemy_spawn_base_multiplier - 0.1, 1.1)
				turns_till_enemy_spawn = 10
				hero.health = 20
			else:
				turns_till_enemy_spawn -= 1
		if enemies_to_spawn > 0:
			try_spawn_enemy()
		# set target			
		for builder in get_tree().get_nodes_in_group("builders"):
			builder.target = tile_map.nearest_broken_wall(tile_map.local_to_map(builder.position), builder.target_radius)
		for enemy in get_tree().get_nodes_in_group("enemies"):
			var path: Array[Vector2i] = astar_grid.get_id_path(tile_map.local_to_map(enemy.position), enemy.target)
			if path.size() > 1:
				var vector = path[1] - path[0]
				if enemy.is_in_group("fire_enemies"):
					if not try_fireball(enemy, vector):
						try_move(enemy, vector)
				elif enemy.is_in_group("teleport_enemies"):
					if path.size() == 2 or enemy.wait_turns > 0:
						if not try_attack(enemy, vector):
							try_move(enemy, vector)
						enemy.wait_turns -= 1
					else:
						var teleported = try_teleport(enemy, vector)
						if not teleported:
							if not try_attack(enemy, vector):
								try_move(enemy, vector)
						else:
							enemy.wait_turns = 1
				elif not try_attack(enemy, vector):
					try_move(enemy, vector)
		for enemy: Actor in get_tree().get_nodes_in_group("enemies"):
			if lighthouse:
				if enemy.position.distance_to(hero.position) < enemy.target_radius * tilesize:
					if enemy.position.distance_to(hero.position) < enemy.position.distance_to(lighthouse.position):
						enemy.target = tile_map.local_to_map(hero.position)
				else:
					enemy.target = tile_map.local_to_map(lighthouse.position)
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
	if actor == hero:
		SoundPlayer.play_sound(SoundPlayer.FOOTSTEP_GRASS_002)
	return true
	
func border_gradient_alpha(alpha: float) -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(border_gradient, "modulate:a", alpha, 0.25)
	
func border_gradient_color(color: Color) -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(border_gradient, "modulate:r", color.r, 0.25)
	tween.parallel().tween_property(border_gradient, "modulate:g", color.g, 0.25)
	tween.parallel().tween_property(border_gradient, "modulate:b", color.b, 0.25)
	
func move_control_alpha(alpha: float) -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(move_control, "modulate:a", alpha, 0.25)
	
func action_control_alpha(alpha: float) -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(action_control, "modulate:a", alpha, 0.25)
	set_action_control_labels()
	
func suck_control_alpha(alpha: float) -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(suck_control, "modulate:a", alpha, 0.25)
	
func set_action_control_labels() -> void:
	var hbox: HBoxContainer = action_control.get_node("HBoxContainer")
	hbox.get_node("upLabel").text = "up:" + hero.action["up"]
	hbox.get_node("downLabel").text = "down:" + hero.action["down"]
	hbox.get_node("leftLabel").text = "left:" + hero.action["left"]
	hbox.get_node("rightLabel").text = "right:" + hero.action["right"]
	
func set_turn_label() -> void:
	turn_label.text = "Turns: " + str(num_turns + 1)
	
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
		SoundPlayer.play_sound(SoundPlayer.IMPACT_SOFT_HEAVY_003)
		#actor.bump_anim(vector)
		astar_grid.set_point_weight_scale(coords, 8.0)
		astar_grid_2.set_point_solid(coords, not tile_map.is_coord_walkable(coords))
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
				SoundPlayer.play_sound(SoundPlayer.IMPACT_PLANK_MEDIUM_004)
				return true
	var success = tile_map.try_attack_wall(coords)
	if success:
		actor.bump_anim(vector)
		astar_grid.set_point_weight_scale(coords, 1.0)
		astar_grid_2.set_point_solid(coords, not tile_map.is_coord_walkable(coords))
	return success
	
func try_fireball(actor: Actor, vector: Vector2) -> bool:
	var destination = actor.position + (vector * tilesize)
	var destination2 = actor.position + (vector * tilesize * 2)
	var coords = tile_map.local_to_map(destination)
	var coords2 = tile_map.local_to_map(destination2)
	for act: Actor in get_tree().get_nodes_in_group("actors"):
		if actor != act:
			var act_coords = tile_map.local_to_map(act.position)
			if act_coords == coords or act_coords == coords2:
				act.damage(1)
				var fire1 = FIRE.instantiate()
				fire1.position = destination
				add_child(fire1)
				var fire2 = FIRE.instantiate()
				fire2.position = destination2
				add_child(fire2)
				SoundPlayer.play_sound(SoundPlayer.IMPACT_PLANK_MEDIUM_004) #TODO FIRE SOUND
				return true
	var success = tile_map.try_attack_wall(coords)
	var success2 = tile_map.try_attack_wall(coords2)
	if success:
		astar_grid.set_point_weight_scale(coords, 1.0)
		astar_grid_2.set_point_solid(coords, not tile_map.is_coord_walkable(coords))
	if success2:
		astar_grid.set_point_weight_scale(coords2, 1.0)
		astar_grid_2.set_point_solid(coords2, not tile_map.is_coord_walkable(coords))
	if success or success2:
		var fire1 = FIRE.instantiate()
		fire1.position = destination
		add_child(fire1)
		var fire2 = FIRE.instantiate()
		fire2.position = destination2
		add_child(fire2)
	return success
	
func try_teleport(actor: Actor, vector: Vector2) -> bool:
	#var destination = actor.position + (vector * tilesize)
	var destination2 = actor.position + (vector * tilesize * 2)
	#var coords = tile_map.local_to_map(destination)
	var coords2 = tile_map.local_to_map(destination2)
	for act: Actor in get_tree().get_nodes_in_group("actors"):
		if actor != act:
			var act_coords = tile_map.local_to_map(act.position)
			if act_coords == coords2:
				return false
	if tile_map.is_coord_walkable(coords2):
		# add effect
		var success = try_move(actor, vector * 2)
		if success:
			var effect1 = TELEPORT_EFFECT.instantiate()
			effect1.position = actor.position
			add_child(effect1)
			var effect2 = TELEPORT_EFFECT.instantiate()
			effect2.position = actor.position
			effect2.position -= (vector * tilesize * 2)
			add_child(effect2)
			actor.animated_sprite_2d.position += vector * tilesize * 2
			return success
	return false
	
func prep_astar_grids() -> void:
	astar_grid.region = Rect2i(0, 0, 36, 20)
	astar_grid.cell_size = Vector2(tilesize, tilesize)
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar_grid.update()
	for x in astar_grid.region.end.x:
		for y in astar_grid.region.end.y:
			if not tile_map.is_coord_walkable(Vector2(x, y)):
				astar_grid.set_point_weight_scale(Vector2(x, y), 8.0)
	astar_grid_2.region = Rect2i(0, 0, 36, 20)
	astar_grid_2.cell_size = Vector2(tilesize, tilesize)
	astar_grid_2.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar_grid_2.update()
	for x in astar_grid_2.region.end.x:
		for y in astar_grid_2.region.end.y:
			if not tile_map.is_coord_walkable(Vector2(x, y)):
				astar_grid_2.set_point_solid(Vector2(x, y))
				
func hero_moving():
	if not paused:
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
			border_gradient_color(magenta)
			move_control_alpha(0.0)
			action_control_alpha(1.0)
			SoundPlayer.play_sound(SoundPlayer.SWITCH_8)
		if Input.is_action_just_pressed("suck"):
			gamestate = SUCK
			border_gradient_alpha(1.0)
			border_gradient_color(blue)
			move_control_alpha(0.0)
			suck_control_alpha(1.0)
			action_control_alpha(0.5)
			SoundPlayer.play_sound(SoundPlayer.SWITCH_8)
		if turn_taken:
			num_turns += 1
	if Input.is_action_just_pressed("escape"):
		if paused == false:
			paused = true
			pause_and_game_over.show()
			game_over_label.hide()
			resume_button.show()
		else:
			paused = false
			pause_and_game_over.hide()
			
		
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
		SoundPlayer.play_sound(SoundPlayer.SWITCH_11)
	if turn_taken:
		num_turns += 1
		
func hero_suck():
	if Input.is_action_just_pressed("up"):
		turn_taken = suck(hero,"up", Vector2(0, -1))
		gamestate = MOVING
		border_gradient_alpha(0.0)
		move_control_alpha(1.0)
		suck_control_alpha(0.0)
		action_control_alpha(0.0)
	if Input.is_action_just_pressed("down"):
		turn_taken = suck(hero, "down", Vector2(0, 1))
		gamestate = MOVING
		border_gradient_alpha(0.0)
		move_control_alpha(1.0)
		suck_control_alpha(0.0)
		action_control_alpha(0.0)
	if Input.is_action_just_pressed("left"):
		turn_taken = suck(hero, "left", Vector2(-1, 0))
		gamestate = MOVING
		border_gradient_alpha(0.0)
		move_control_alpha(1.0)
		suck_control_alpha(0.0)
		action_control_alpha(0.0)
	if Input.is_action_just_pressed("right"):
		turn_taken = suck(hero, "right", Vector2(1, 0))
		gamestate = MOVING
		border_gradient_alpha(0.0)
		move_control_alpha(1.0)
		suck_control_alpha(0.0)
		action_control_alpha(0.0)
	if Input.is_action_just_pressed("escape") or Input.is_action_just_pressed("suck"):
		turn_taken = false
		gamestate = MOVING
		border_gradient_alpha(0.0)
		move_control_alpha(1.0)
		suck_control_alpha(0.0)
		action_control_alpha(0.0)
		SoundPlayer.play_sound(SoundPlayer.SWITCH_11)
	if turn_taken:
		num_turns += 1
		
func take_action(actor: Actor, action: String, vector: Vector2) -> bool:
	if action == "ATTACK":
		return try_attack(actor, vector)
	elif action == "BUILD":
		return try_build(actor, vector)
	elif action == "FIREBALL":
		return try_fireball(actor, vector)
	elif action == "TELEPORT":
		return try_teleport(actor, vector)
	elif action == "BOMB":
		return try_fireball(actor, vector)
	return false
	
func suck(actor: Actor, action_slot: String, vector: Vector2) -> bool:
	var destination = actor.position + (vector * tilesize)
	var coords = tile_map.local_to_map(destination)
	for act: Actor in get_tree().get_nodes_in_group("actors"):
		if actor != act and not act is Lighthouse:
			var act_coords = tile_map.local_to_map(act.position)
			if act_coords == coords and act.health <= 3:
				actor.action[action_slot] = act.suck_action
				#actor.bump_anim(vector)
				var suck_effect = SUCK_EFFECT.instantiate()
				suck_effect.position = destination
				if vector == Vector2(1, 0):
					suck_effect.rotation_degrees = 90
				elif vector == Vector2(0, 1):
					suck_effect.rotation_degrees = 180
				elif vector == Vector2(-1, 0):
					suck_effect.rotation_degrees = 270
				add_child(suck_effect)
				SoundPlayer.play_sound(SoundPlayer.SUCK)
				if act is Builder:
					actor.health += 1
				act.die()
				return true
	return false
	
func _on_actor_died(actor: Actor) -> void:
	await get_tree().process_frame
	if actor == hero or actor is Lighthouse:
		pause_and_game_over.show()
		game_over_label.show()
		resume_button.hide()
		game_data.high_scores.append(num_turns)
		ResourceSaver.save(game_data, "user://high_scores_file.tres")
	actor.queue_free()
	
func try_spawn_builder() -> void:
	var spawner = builder_spawners.get_children().pick_random()
	for actor in get_tree().get_nodes_in_group("actors"):
		if actor.position == spawner.position:
			return
	var builder = BUILDER.instantiate()
	builder.position = spawner.position
	add_child(builder)
	builder.died.connect(_on_actor_died)
	builders_to_spawn -= 1
	
func try_spawn_enemy() -> void:
	var spawner = enemy_spawners.get_children().pick_random()
	for actor in get_tree().get_nodes_in_group("actors"):
		if actor.position == spawner.position:
			return
	var enemy_array = [ENEMY, ENEMY, ENEMY, ENEMY]
	if num_turns > 50:
		enemy_array.append(FIRE_ENEMY)
	if num_turns > 100:
		enemy_array.append(TELEPORT_ENEMY)
	if num_turns > 150:
		enemy_array.append(FIRE_ENEMY)
		enemy_array.append(TELEPORT_ENEMY)
	if num_turns > 200:
		enemy_array.append(FIRE_ENEMY)
		enemy_array.append(TELEPORT_ENEMY)
	if num_turns > 250:
		enemy_array.append(FIRE_ENEMY)
		enemy_array.append(TELEPORT_ENEMY)
	if num_turns > 300:
		enemy_array.append(FIRE_ENEMY)
		enemy_array.append(TELEPORT_ENEMY)
	
	var enemy = enemy_array.pick_random().instantiate()
	enemy.position = spawner.position
	add_child(enemy)
	enemy.died.connect(_on_actor_died)
	enemies_to_spawn -= 1

func _on_restart_button_pressed() -> void:
	get_tree().reload_current_scene()

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _on_resume_button_pressed() -> void:
	pause_and_game_over.hide()
	paused = false
