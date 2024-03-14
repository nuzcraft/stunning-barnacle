extends Node2D
class_name Actor

signal died

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_label: Label = $AnimatedSprite2D/HealthLabel

@export var health: int = 3
@export var target_radius: int = 3
@export var action = {"up": "NONE"
, "down": "NONE"
, "left": "NONE"
, "right": "NONE"}
@export var suck_action = "ATTACK"

var tilesize = 16
var target: Vector2i = Vector2i.ZERO
var wait_turns = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	animated_sprite_2d.position = animated_sprite_2d.position.move_toward(Vector2.ZERO, 100.0*delta)
	health_label.text = str(health)
	
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
		
func damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		die()
		
func die():
	died.emit(self)
	 
	
	
