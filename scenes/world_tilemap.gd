extends TileMap

enum e_layers {
	OCEAN,
	BACKGROUND,
	FOREGROUND,
	FOREGROUND2
}

enum e_source_id {
	TILES,
	SHAPES_BW,
	SHAPES_TRANS
}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func set_cell_broken_wall(coords: Vector2):
	set_cells_terrain_connect(e_layers.FOREGROUND, [coords], 0, -1)
	set_cell(e_layers.FOREGROUND, Vector2i(coords), e_source_id.TILES, Vector2i(9, 0))

func try_attack_wall(coords: Vector2) -> bool:
	var data = get_cell_tile_data(e_layers.FOREGROUND, coords)
	var data2 = get_cell_tile_data(e_layers.FOREGROUND2, coords)
	if data:
		if data.terrain == 0 and data.terrain_set == 0:
			if data2:
				var atlas_coords = get_cell_atlas_coords(e_layers.FOREGROUND2, coords)
				if atlas_coords == Vector2i(9,2): # broken wall
					set_cell_broken_wall(coords)
			else:
				set_cell(e_layers.FOREGROUND2, coords, e_source_id.TILES, Vector2(9, 2)) 
			return true
	return false
	
func try_build_wall(coords: Vector2) -> bool:
	var data = get_cell_tile_data(e_layers.FOREGROUND, coords)
	var data2 = get_cell_tile_data(e_layers.FOREGROUND2, coords)
	if data:
		if data.terrain == 0 and data.terrain_set == 0:
			if data2:
				var atlas_coords = get_cell_atlas_coords(e_layers.FOREGROUND2, coords)
				if atlas_coords == Vector2i(9,2): # broken wall
					set_cell(e_layers.FOREGROUND2, coords, e_source_id.TILES, Vector2(-1, -1)) #clear out broken part
					return true
			return false
	set_cell(e_layers.FOREGROUND, Vector2i(coords), e_source_id.TILES, Vector2i(0, 0))
	set_cells_terrain_connect(e_layers.FOREGROUND, [coords], 0, 0)	
	return true
	
func is_coord_walkable(coords: Vector2) -> bool:
	var bg_data = get_cell_tile_data(e_layers.BACKGROUND, coords)
	if not bg_data:
		return false
	var fg_data = get_cell_tile_data(e_layers.FOREGROUND, coords)
	if fg_data:
		if fg_data.terrain == 0 and fg_data.terrain_set == 0:
			return false
	return true
