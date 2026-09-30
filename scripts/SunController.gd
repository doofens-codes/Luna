extends DirectionalLight3D

@export var azimuth_speed: float = 60.0
@export var elevation_speed: float = 60.0

var azimuth: float = 45.0
var elevation: float = -50.0


func _ready() -> void:
	rotation_degrees = Vector3(elevation, azimuth, 0.0)


func _process(delta: float) -> void:

	# Rotate Sun left / right
	if Input.is_key_pressed(KEY_J):
		azimuth -= azimuth_speed * delta

	if Input.is_key_pressed(KEY_L):
		azimuth += azimuth_speed * delta

	# Change Sun elevation
	if Input.is_key_pressed(KEY_I):
		elevation += elevation_speed * delta

	if Input.is_key_pressed(KEY_K):
		elevation -= elevation_speed * delta

	# Keep elevation within a sensible range
	elevation = clamp(elevation, -85.0, -5.0)

	rotation_degrees = Vector3(elevation, azimuth, 0.0)
	
func set_sun_rotation(new_rotation: Vector3) -> void:
	elevation = new_rotation.x
	azimuth = new_rotation.y

	elevation = clamp(elevation, -85.0, -5.0)

	rotation_degrees = Vector3(
		elevation,
		azimuth,
		0.0
	)
