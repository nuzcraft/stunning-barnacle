extends Actor
class_name Hero


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	super._process(delta)
	if Input.is_action_just_pressed("up"):
		move(Vector2(0, -1))
	if Input.is_action_just_pressed("down"):
		move(Vector2(0, 1))
	if Input.is_action_just_pressed("left"):
		move(Vector2(-1, 0))
	if Input.is_action_just_pressed("right"):
		move(Vector2(1, 0))
