extends Node2D
class_name Actor

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

var tilesize = 16

var action = {"up": "attack"
, "down": "attack"
, "left": "attack"
, "right": "attack"}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	animated_sprite_2d.position = animated_sprite_2d.position.move_toward(Vector2.ZERO, 100.0*delta)
	
func move(vector: Vector2) -> void:
	position += vector * tilesize
	animated_sprite_2d.position -= vector * tilesize
	if vector.x > 0:
		animated_sprite_2d.flip_h = false
	elif vector.x < 0:
		animated_sprite_2d.flip_h = true 
	
func bump_anim(vector: Vector2) -> void:
	animated_sprite_2d.position += (vector * tilesize) * 0.75
	if vector.x > 0:
		animated_sprite_2d.flip_h = false
	elif vector.x < 0:
		animated_sprite_2d.flip_h = true 
	
