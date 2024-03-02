extends TileMap

enum e_layers {
	OCEAN,
	BACKGROUND,
	FOREGROUND
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
