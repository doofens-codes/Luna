extends Camera3D

@export var move_speed: float = 20.0
@export var mouse_sensitivity: float = 0.002
@export var angle_speed: float = 1.0


var pitch: float = 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:

	# Mouse movement
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)

		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, -1.5, 1.5)

		rotation.x = pitch

	# Escape releases the mouse
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Left click captures the mouse again
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:

	var direction := Vector3.ZERO

	# Forward / backward
	if Input.is_key_pressed(KEY_W):
		direction -= global_transform.basis.z

	if Input.is_key_pressed(KEY_S):
		direction += global_transform.basis.z

	# Left / right
	if Input.is_key_pressed(KEY_A):
		direction -= global_transform.basis.x

	if Input.is_key_pressed(KEY_D):
		direction += global_transform.basis.x
		# Up / down
	if Input.is_key_pressed(KEY_Q):
		global_position.y += move_speed * delta

	if Input.is_key_pressed(KEY_E):
		global_position.y -= move_speed * delta
		# Controlled viewing angle
	if Input.is_key_pressed(KEY_R):
		pitch -= angle_speed * delta

	if Input.is_key_pressed(KEY_F):
		pitch += angle_speed * delta

	# Limit viewing angle
	pitch = clamp(pitch, -1.5, 1.5)

	rotation.x = pitch

	# Prevent camera from going underground
	global_position.y = max(global_position.y, 2.0)
	# Normalize so diagonal movement isn't faster
	if direction.length() > 0.0:
		direction = direction.normalized()

		global_position += direction * move_speed * delta
