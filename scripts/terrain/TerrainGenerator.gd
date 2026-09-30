extends Node3D

# ============================================================
# LUNA-SIM
# Phase 3
# Procedural Lunar Terrain + Explicit Craters
# ============================================================

@export_category("Terrain")
@export var terrain_size: float = 100.0
@export_range(20,256, 1) var resolution: int = 256


@export_category("Terrain Height")
@export var height_scale: float = 8.0

@export_category("Macro Terrain")
@export var macro_strength: float = 1.0
@export var macro_frequency: float = 0.018

@export_category("Meso Terrain")
@export var meso_strength: float = 0.35
@export var meso_frequency: float = 0.055

@export_category("Micro Terrain")
@export var micro_strength: float = 0.05
@export var micro_frequency: float = 0.18

@export_category("Craters")
@export_range(0, 100, 1) var crater_count: int = 20
@export var crater_min_radius: float = 5.0
@export var crater_max_radius: float = 10.0
@export var crater_depth: float = 8.0
@export var crater_rim_height: float = 3.0
@export_range(0.0, 1.0, 0.01) var crater_irregularity: float = 0.10

@export_category("Reproducibility")
@export var terrain_seed: int = 12345
@export_category("Experiment")
@export var camera_test_offset: Vector3 = Vector3(2.0, 0.0, 0.0)

@export var camera_test_rotation: Vector3 = Vector3.ZERO

@export_category("Automated Dataset")

var experiments = [
	{
		"type": "camera_translation",
		"offset": Vector3(2.0, 0.0, 0.0),
		"rotation": Vector3(0.0, 0.0, 0.0),
		"sun_rotation": Vector3(-50.0, 45.0, 0.0)
	},
	{
		"type": "camera_translation_rotation",
		"offset": Vector3(4.0, 0.0, 0.0),
		"rotation": Vector3(5.0, 0.0, 0.0),
		"sun_rotation": Vector3(-50.0, 45.0, 0.0)
	},
	{
		"type": "camera_translation_rotation",
		"offset": Vector3(6.0, 0.0, 0.0),
		"rotation": Vector3(-5.0, 0.0, 0.0),
		"sun_rotation": Vector3(-50.0, 45.0, 0.0)
	},
	{
		"type": "camera_translation_rotation",
		"offset": Vector3(8.0, 0.0, 0.0),
		"rotation": Vector3(0.0, 10.0, 0.0),
		"sun_rotation": Vector3(-50.0, 45.0, 0.0)
	},
	{
		"type": "camera_translation_rotation",
		"offset": Vector3(10.0, 0.0, 0.0),
		"rotation": Vector3(0.0, -10.0, 0.0),
		"sun_rotation": Vector3(-50.0, 45.0, 0.0)
	},

	# --------------------------------------------------------
	# Illumination-only experiments
	# --------------------------------------------------------

	{
		"type": "illumination_change",
		"offset": Vector3(0.0, 0.0, 0.0),
		"rotation": Vector3(0.0, 0.0, 0.0),
		"sun_rotation": Vector3(-45.0, 75.0, 0.0)
	},
	{
		"type": "illumination_change",
		"offset": Vector3(0.0, 0.0, 0.0),
		"rotation": Vector3(0.0, 0.0, 0.0),
		"sun_rotation": Vector3(-30.0, 120.0, 0.0)
	},
	{
		"type": "illumination_change",
		"offset": Vector3(0.0, 0.0, 0.0),
		"rotation": Vector3(0.0, 0.0, 0.0),
		"sun_rotation": Vector3(-20.0, 160.0, 0.0)
	}
]

var dataset_running: bool = false
var terrain_mesh_instance: MeshInstance3D
var current_experiment_type: String = "camera_translation_rotation"
var craters: Array[Dictionary] = []

# Stores the parameters used to create the current terrain.
var last_seed: int = -999999
var last_crater_count: int = -1
var last_height_scale: float = -999999.0

var pair_number: int = 1
var image_a_data: Dictionary = {}
var image_a_captured: bool = false

func _ready() -> void:
	find_next_pair_number()
	generate_terrain()
func find_next_pair_number() -> void:
	pair_number = 1

	while FileAccess.file_exists(
		"res://data/pair_%03d/image_A.png" % pair_number
	):
		pair_number += 1

	print("Next available pair: pair_%03d" % pair_number)
	
	

func _process(_delta: float) -> void:
	# Automatically regenerate when important parameters change.
	if (
		terrain_seed != last_seed
		or crater_count != last_crater_count
		or height_scale != last_height_scale
	):
		generate_terrain()
	update_simulation_ui()


func generate_terrain() -> void:

	print("========================================")
	print("Generating LUNA-SIM terrain")
	print("Seed: ", terrain_seed)
	print("Crater Count: ", crater_count)
	print("========================================")

	# Remember the parameters used for this generation.
	last_seed = terrain_seed
	last_crater_count = crater_count
	last_height_scale = height_scale

	# --------------------------------------------------------
	# Noise generators
	# --------------------------------------------------------

	var macro_noise := FastNoiseLite.new()
	macro_noise.seed = terrain_seed
	macro_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	macro_noise.frequency = macro_frequency

	var meso_noise := FastNoiseLite.new()
	meso_noise.seed = terrain_seed + 1000
	meso_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	meso_noise.frequency = meso_frequency

	var micro_noise := FastNoiseLite.new()
	micro_noise.seed = terrain_seed + 2000
	micro_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	micro_noise.frequency = micro_frequency

	# --------------------------------------------------------
	# Generate craters
	# --------------------------------------------------------

	generate_craters()

	# --------------------------------------------------------
	# Build terrain mesh
	# --------------------------------------------------------

	var surface_tool := SurfaceTool.new()

	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var step := terrain_size / float(resolution)

	for z in range(resolution):

		for x in range(resolution):

			var x0 := -terrain_size / 2.0 + x * step
			var z0 := -terrain_size / 2.0 + z * step

			var x1 := x0 + step
			var z1 := z0 + step

			var p00 := Vector3(
				x0,
				get_height(
					x0,
					z0,
					macro_noise,
					meso_noise,
					micro_noise
				),
				z0
			)

			var p10 := Vector3(
				x1,
				get_height(
					x1,
					z0,
					macro_noise,
					meso_noise,
					micro_noise
				),
				z0
			)

			var p01 := Vector3(
				x0,
				get_height(
					x0,
					z1,
					macro_noise,
					meso_noise,
					micro_noise
				),
				z1
			)

			var p11 := Vector3(
				x1,
				get_height(
					x1,
					z1,
					macro_noise,
					meso_noise,
					micro_noise
				),
				z1
			)

			add_triangle(surface_tool, p00, p10, p11)
			add_triangle(surface_tool, p00, p11, p01)

	surface_tool.index()
	surface_tool.generate_normals()

	var terrain_mesh := surface_tool.commit()

	# --------------------------------------------------------
	# Remove previous terrain
	# --------------------------------------------------------

	if terrain_mesh_instance != null:
		terrain_mesh_instance.queue_free()

	# --------------------------------------------------------
	# Create new terrain
	# --------------------------------------------------------

	terrain_mesh_instance = MeshInstance3D.new()

	terrain_mesh_instance.name = "ProceduralTerrain"

	terrain_mesh_instance.mesh = terrain_mesh

	# --------------------------------------------------------
	# Lunar material
	# --------------------------------------------------------

	var material := StandardMaterial3D.new()

	material.albedo_color = Color(0.42, 0.42, 0.42)

	material.roughness = 0.92

	material.metallic = 0.0

	terrain_mesh_instance.material_override = material

	add_child(terrain_mesh_instance)
# --------------------------------------------------------
# Create collision from the exact terrain mesh
# --------------------------------------------------------
	terrain_mesh_instance.create_trimesh_collision()

	print("Terrain collision created successfully.")


func generate_craters() -> void:

	craters.clear()

	var rng := RandomNumberGenerator.new()

	# Separate deterministic seed for crater placement.
	rng.seed = terrain_seed + 5000

	for i in range(crater_count):

		var radius := rng.randf_range(
			crater_min_radius,
			crater_max_radius
		)

		var margin := radius + 1.0

		var x := rng.randf_range(
			-terrain_size / 2.0 + margin,
			terrain_size / 2.0 - margin
		)

		var z := rng.randf_range(
			-terrain_size / 2.0 + margin,
			terrain_size / 2.0 - margin
		)

		var irregularity := rng.randf_range(
			0.0,
			crater_irregularity
		)

		craters.append({
			"position": Vector2(x, z),
			"radius": radius,
			"irregularity": irregularity,
			"rotation": rng.randf_range(0.0, TAU)
		})


func get_height(
	x: float,
	z: float,
	macro_noise: FastNoiseLite,
	meso_noise: FastNoiseLite,
	micro_noise: FastNoiseLite
) -> float:

	var macro := macro_noise.get_noise_2d(x, z)

	var meso := meso_noise.get_noise_2d(x, z)

	var micro := micro_noise.get_noise_2d(x, z)

	var natural_height := (
		macro * macro_strength
		+ meso * meso_strength
		+ micro * micro_strength
	) * height_scale

	var crater_height := get_crater_height(x, z)

	return natural_height + crater_height


func get_crater_height(x: float, z: float) -> float:

	var total: float = 0.0

	var point: Vector2 = Vector2(x, z)

	for crater in craters:

		var center: Vector2 = crater["position"] as Vector2
		var radius: float = float(crater["radius"])

		var distance: float = point.distance_to(center)

		# Outside crater influence.
		if distance > radius * 1.4:
			continue

		var r: float = distance / radius

		# ----------------------------------------------------
		# Crater bowl
		# ----------------------------------------------------
		# Creates a broader, smoother crater floor instead
		# of a sharp depression at the center.

		var bowl_t: float = clamp(r / 0.85, 0.0, 1.0)

		var bowl: float = 1.0 - (
			bowl_t * bowl_t * (3.0 - 2.0 * bowl_t)
		)

		var depression: float = -crater_depth * bowl

		# ----------------------------------------------------
		# Raised crater rim
		# ----------------------------------------------------

		var rim_distance: float = abs(r - 1.0)

		var rim_width: float = 0.10

		var rim: float = exp(
			-pow(rim_distance / rim_width, 2.0)
		)

		var raised_rim: float = crater_rim_height * rim

		# ----------------------------------------------------
		# Slight natural irregularity
		# ----------------------------------------------------

		var angle: float = atan2(
			z - center.y,
			x - center.x
		)

		var irregularity: float = float(crater["irregularity"])

		var rotation: float = float(crater["rotation"])

		var variation: float = sin(
			angle * 3.0 + rotation
		) * irregularity

		var shape_factor: float = 1.0 + variation

		total += (
			depression + raised_rim
		) * shape_factor

	return total
func add_triangle(
	surface_tool: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3
) -> void:

	surface_tool.set_uv(Vector2(0.0, 0.0))
	surface_tool.add_vertex(a)

	surface_tool.set_uv(Vector2(1.0, 0.0))
	surface_tool.add_vertex(b)

	surface_tool.set_uv(Vector2(1.0, 1.0))
	surface_tool.add_vertex(c)


func _on_regenerate_button_pressed() -> void:
	crater_count = int($UI/ControlPanel/CraterCountInput.value)
	terrain_seed = int($UI/ControlPanel/TerrainSeedInput.value)
	generate_terrain()
func _on_capture_image_button_pressed() -> bool:

	if image_a_captured:
		print("ERROR: Image A has already been captured.")
		print("Capture Image B before starting a new pair.")
		return false

	# --------------------------------------------------------
	# Hide UI
	# --------------------------------------------------------

	$UI.visible = false

	await RenderingServer.frame_post_draw

	# --------------------------------------------------------
	# Capture clean Image A
	# --------------------------------------------------------

	var image: Image = (
		$Camera3D.get_viewport().get_texture().get_image()
	)

	# Show UI again
	$UI.visible = true

	# --------------------------------------------------------
	# File paths
	# --------------------------------------------------------

	var pair_name: String = "pair_%03d" % pair_number
	var folder_path: String = "res://data/" + pair_name

	# --------------------------------------------------------
	# Create pair folder
	# --------------------------------------------------------

	var directory: DirAccess = DirAccess.open("res://data")

	if directory == null:
		print("ERROR: Could not open res://data folder.")
		return false

	var dir_error: Error = directory.make_dir_recursive(pair_name)

	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		print("ERROR: Could not create pair folder.")
		print("Folder: ", folder_path)
		print("Error code: ", dir_error)
		return false

	# --------------------------------------------------------
	# Save Image A
	# --------------------------------------------------------

	var image_path: String = folder_path + "/image_A.png"

	var image_error: Error = image.save_png(image_path)

	if image_error != OK:
		print("ERROR: Could not save Image A.")
		print("Path: ", image_path)
		print("Error code: ", image_error)
		return false

	# --------------------------------------------------------
	# Record Image A state
	# --------------------------------------------------------

	image_a_data = {
		"terrain_seed": terrain_seed,
		"crater_count": crater_count,

		"camera_position": [
			$Camera3D.global_position.x,
			$Camera3D.global_position.y,
			$Camera3D.global_position.z
		],

		"camera_rotation": [
			$Camera3D.global_rotation_degrees.x,
			$Camera3D.global_rotation_degrees.y,
			$Camera3D.global_rotation_degrees.z
		],

		"sun_rotation": [
			$Sun.global_rotation_degrees.x,
			$Sun.global_rotation_degrees.y,
			$Sun.global_rotation_degrees.z
		]
	}

	image_a_captured = true

	print("================================")
	print("CLEAN IMAGE A CAPTURED")
	print("Pair: ", pair_name)
	print("Saved to: ", image_path)
	print("================================")

	return true
func _on_capture_image_b_button_pressed() -> bool:

	if not image_a_captured:
		print("ERROR: Capture IMAGE A first!")
		return false

	# --------------------------------------------------------
	# Get Image A camera state
	# --------------------------------------------------------

	var image_a_position := Vector3(
		float(image_a_data["camera_position"][0]),
		float(image_a_data["camera_position"][1]),
		float(image_a_data["camera_position"][2])
	)

	var image_a_rotation := Vector3(
		float(image_a_data["camera_rotation"][0]),
		float(image_a_data["camera_rotation"][1]),
		float(image_a_data["camera_rotation"][2])
	)

	# --------------------------------------------------------
	# Apply controlled camera experiment
	# --------------------------------------------------------

	$Camera3D.global_position = (
	image_a_position + camera_test_offset)
	$Camera3D.global_rotation_degrees = (
	image_a_rotation + camera_test_rotation
)

	print("Camera offset: ", camera_test_offset)
	print("Camera rotation offset: ", camera_test_rotation)
	print("Image A position: ", image_a_position)
	print("Image B position: ", $Camera3D.global_position)
	print("Image A rotation: ", image_a_rotation)
	print("Image B rotation: ", $Camera3D.global_rotation_degrees)

	# --------------------------------------------------------
	# Wait for camera movement to render
	# --------------------------------------------------------

	await RenderingServer.frame_post_draw

	# --------------------------------------------------------
	# Hide UI
	# --------------------------------------------------------

	$UI.visible = false

	await RenderingServer.frame_post_draw

	# --------------------------------------------------------
	# Capture clean Image B
	# --------------------------------------------------------

	var image: Image = (
		$Camera3D.get_viewport().get_texture().get_image()
	)

	# Show UI again
	$UI.visible = true

	# --------------------------------------------------------
	# File paths
	# --------------------------------------------------------

	var pair_name: String = "pair_%03d" % pair_number
	var folder_path: String = "res://data/" + pair_name

	# --------------------------------------------------------
	# Create pair folder
	# --------------------------------------------------------

	var directory: DirAccess = DirAccess.open("res://data")

	if directory == null:
		print("ERROR: Could not open res://data folder.")
		return false

	var dir_error: Error = directory.make_dir_recursive(pair_name)

	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		print("ERROR: Could not create pair folder.")
		print("Folder: ", folder_path)
		print("Error code: ", dir_error)
		return false

	# --------------------------------------------------------
	# Save Image B
	# --------------------------------------------------------

	var image_path: String = folder_path + "/image_B.png"

	var image_error: Error = image.save_png(image_path)

	if image_error != OK:
		print("ERROR: Could not save Image B.")
		print("Path: ", image_path)
		print("Error code: ", image_error)
		return false

	# --------------------------------------------------------
	# Record Image B state
	# --------------------------------------------------------

	var image_b_data: Dictionary = {
		"camera_position": [
			$Camera3D.global_position.x,
			$Camera3D.global_position.y,
			$Camera3D.global_position.z
		],

		"camera_rotation": [
			$Camera3D.global_rotation_degrees.x,
			$Camera3D.global_rotation_degrees.y,
			$Camera3D.global_rotation_degrees.z
		],

		"sun_rotation": [
			$Sun.global_rotation_degrees.x,
			$Sun.global_rotation_degrees.y,
			$Sun.global_rotation_degrees.z
		]
	}

	# --------------------------------------------------------
	# Ground truth
	# --------------------------------------------------------

	var ground_truth: Dictionary = {

		"pair_id": pair_name,

		"experiment": {
	"type": current_experiment_type,

	"camera_offset": [
		camera_test_offset.x,
		camera_test_offset.y,
		camera_test_offset.z
	],

	"camera_rotation_offset": [
		camera_test_rotation.x,
		camera_test_rotation.y,
		camera_test_rotation.z
	]
},
		"terrain": {
			"seed": terrain_seed,
			"crater_count": crater_count
		},

		"image_A": image_a_data,

		"image_B": image_b_data
	}

	# --------------------------------------------------------
	# Save ground truth
	# --------------------------------------------------------

	var json_path: String = folder_path + "/ground_truth.json"

	var json_text: String = JSON.stringify(
		ground_truth,
		"\t"
	)

	var file: FileAccess = FileAccess.open(
		json_path,
		FileAccess.WRITE
	)

	if file == null:
		print("ERROR: Could not create ground truth file.")
		print("Path: ", json_path)
		print("Make sure the pair folder exists.")

		# Restore Image A camera
		$Camera3D.global_position = image_a_position
		$Camera3D.global_rotation_degrees = image_a_rotation

		return false

	file.store_string(json_text)
	file.close()

	# --------------------------------------------------------
	# Restore Image A camera position
	# --------------------------------------------------------

	$Camera3D.global_position = image_a_position
	$Camera3D.global_rotation_degrees = image_a_rotation

	# --------------------------------------------------------
	# Finish pair
	# --------------------------------------------------------

	print("================================")
	print("CLEAN IMAGE B CAPTURED")
	print("Pair: ", pair_name)
	print("Saved to: ", image_path)

	print("GROUND TRUTH SAVED")
	print("Saved to: ", json_path)

	print("Camera experiment offset: ", camera_test_offset)
	print("Camera rotation experiment: ", camera_test_rotation)

	print("================================")

	pair_number += 1

	image_a_captured = false
	image_a_data = {}

	return true
func _unhandled_input(event: InputEvent) -> void:

	if event is InputEventKey:

		if event.pressed and not event.echo:

			if event.keycode == KEY_G:

				if dataset_running:
					print("Dataset generation is already running.")
					return

				run_camera_dataset()

			elif event.keycode == KEY_T:

				test_camera_a_to_b_correspondence()

			elif event.keycode == KEY_P:

				generate_pixel_ground_truth()


func run_camera_dataset() -> void:

	dataset_running = true

	print("")
	print("========================================")
	print("AUTOMATED DATASET GENERATION STARTED")
	print("========================================")

	# --------------------------------------------------------
	# Store the original Camera A state
	# --------------------------------------------------------

	var fixed_camera_position: Vector3 = $Camera3D.global_position
	var fixed_camera_rotation: Vector3 = $Camera3D.global_rotation_degrees

	# --------------------------------------------------------
	# Store the original Sun A state
	# --------------------------------------------------------
	var fixed_sun_rotation: Vector3 = Vector3(-50.0, 45.0, 0.0)
	print("Fixed Camera A position: ", fixed_camera_position)
	print("Fixed Camera A rotation: ", fixed_camera_rotation)
	print("Fixed Sun A rotation: ", fixed_sun_rotation)

	# --------------------------------------------------------
	# Generate one pair for every experiment
	# --------------------------------------------------------

	for experiment in experiments:

		# ----------------------------------------------------
		# Reset Camera A
		# ----------------------------------------------------

		$Camera3D.global_position = fixed_camera_position
		$Camera3D.global_rotation_degrees = fixed_camera_rotation

		# ----------------------------------------------------
		# Reset Sun A
		# ----------------------------------------------------
		$Sun.set_sun_rotation(fixed_sun_rotation)
		# ----------------------------------------------------
		# Load experiment parameters
		# ----------------------------------------------------

		camera_test_offset = experiment["offset"]
		camera_test_rotation = experiment["rotation"]
		current_experiment_type = experiment["type"]
		var experiment_sun_rotation: Vector3 = experiment["sun_rotation"]
		

		print("")
		print("----------------------------------------")
		print("Starting experiment")
		print("Camera offset: ", camera_test_offset)
		print("Camera rotation: ", camera_test_rotation)
		print("Sun rotation A: ", fixed_sun_rotation)
		print("Sun rotation B: ", experiment_sun_rotation)
		print("----------------------------------------")

		# ----------------------------------------------------
		# Capture Image A
		# ----------------------------------------------------
		# Image A always uses the fixed camera and
		# baseline Sun illumination.

		var image_a_success: bool = await _on_capture_image_button_pressed()

		if not image_a_success:
			print("ERROR: Image A capture failed.")
			print("Stopping automated dataset generation.")

			dataset_running = false
			return

		# ----------------------------------------------------
		# Apply experiment Sun illumination
		# ----------------------------------------------------
		
		$Sun.set_sun_rotation(experiment_sun_rotation)
		print("Applied experiment Sun rotation: ",
			$Sun.global_rotation_degrees)

		# ----------------------------------------------------
		# Capture Image B + Ground Truth
		# ----------------------------------------------------

		var image_b_success: bool = await _on_capture_image_b_button_pressed()

		if not image_b_success:
			print("ERROR: Image B capture or ground truth failed.")
			print("Stopping automated dataset generation.")

			dataset_running = false
			return

	# --------------------------------------------------------
	# Restore original Camera A state
	# --------------------------------------------------------

	$Camera3D.global_position = fixed_camera_position
	$Camera3D.global_rotation_degrees = fixed_camera_rotation

	# --------------------------------------------------------
	# Restore original Sun A state
	# --------------------------------------------------------

	$Sun.set_sun_rotation(fixed_sun_rotation)

	dataset_running = false

	print("")
	print("========================================")
	print("AUTOMATED DATASET GENERATION COMPLETE")
	print("========================================")
# ============================================================
# TEST TERRAIN RAYCAST
# ============================================================

# ============================================================
# TEST TERRAIN POINT PROJECTION
# ============================================================
# ============================================================
# TEST CAMERA A TO CAMERA B PIXEL CORRESPONDENCE
# ============================================================

func test_camera_a_to_b_correspondence() -> void:

	var camera: Camera3D = $Camera3D

	# --------------------------------------------------------
	# Store the original Camera A state
	# --------------------------------------------------------

	var camera_a_position: Vector3 = camera.global_position

	var camera_a_rotation: Vector3 = (
		camera.global_rotation_degrees
	)

	# --------------------------------------------------------
	# Select one pixel from Image A
	# --------------------------------------------------------

	var viewport_size: Vector2 = (
		camera.get_viewport().get_visible_rect().size
	)

	var image_a_pixel: Vector2 = (
		viewport_size / 2.0
	)

	print("")
	print("========================================")
	print("CAMERA A TO B CORRESPONDENCE TEST")
	print("========================================")

	print("Image A pixel: ", image_a_pixel)

	# --------------------------------------------------------
	# Create a ray from Camera A through the pixel
	# --------------------------------------------------------

	var ray_origin: Vector3 = (
		camera.project_ray_origin(image_a_pixel)
	)

	var ray_direction: Vector3 = (
		camera.project_ray_normal(image_a_pixel)
	)

	var ray_end: Vector3 = (
		ray_origin + ray_direction * 200.0
	)

	# --------------------------------------------------------
	# Raycast against the lunar terrain
	# --------------------------------------------------------

	var space_state: PhysicsDirectSpaceState3D = (
		get_world_3d().direct_space_state
	)

	var query := PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_end
	)

	var result: Dictionary = (
		space_state.intersect_ray(query)
	)

	if result.is_empty():

		print("ERROR: Camera A ray did not hit terrain.")
		print("Cannot calculate correspondence.")

		return

	# --------------------------------------------------------
	# Get the true 3D terrain point
	# --------------------------------------------------------

	var terrain_point: Vector3 = result["position"]

	print("3D terrain point: ", terrain_point)

	# --------------------------------------------------------
	# Apply the existing Camera B experiment
	# --------------------------------------------------------

	camera.global_position = (
		camera_a_position + camera_test_offset
	)

	camera.global_rotation_degrees = (
		camera_a_rotation + camera_test_rotation
	)

	print("Camera A position: ", camera_a_position)
	print("Camera A rotation: ", camera_a_rotation)

	print("Camera B position: ", camera.global_position)
	print("Camera B rotation: ", camera.global_rotation_degrees)

	print("Camera offset: ", camera_test_offset)
	print("Camera rotation offset: ", camera_test_rotation)

	# --------------------------------------------------------
	# Project the same 3D terrain point into Camera B
	# --------------------------------------------------------

	var image_b_pixel: Vector2 = (
		camera.unproject_position(terrain_point)
	)

	print("True Image B pixel: ", image_b_pixel)

	# --------------------------------------------------------
	# Check whether the point is behind Camera B
	# --------------------------------------------------------

	var point_behind_camera_b: bool = (
		camera.is_position_behind(terrain_point)
	)

	print(
		"Point behind Camera B: ",
		point_behind_camera_b
	)

	# --------------------------------------------------------
	# Check whether the projected point is inside Image B
	# --------------------------------------------------------

	var inside_image_b: bool = (
		image_b_pixel.x >= 0.0
		and image_b_pixel.x < viewport_size.x
		and image_b_pixel.y >= 0.0
		and image_b_pixel.y < viewport_size.y
	)

	print(
		"Point inside Image B: ",
		inside_image_b
	)

	# --------------------------------------------------------
	# Check Camera B visibility / occlusion
	# --------------------------------------------------------

	var b_to_point: Vector3 = (
		terrain_point - camera.global_position
	)

	var b_distance: float = b_to_point.length()

	var b_direction: Vector3 = (
		b_to_point.normalized()
	)

	var b_ray_end: Vector3 = (
		camera.global_position
		+ b_direction * b_distance
	)

	var b_query := PhysicsRayQueryParameters3D.create(
		camera.global_position,
		b_ray_end
	)

	var b_result: Dictionary = (
		space_state.intersect_ray(b_query)
	)

	var terrain_point_visible_from_b: bool = false

	if not b_result.is_empty():

		var b_hit_position: Vector3 = (
			b_result["position"]
		)

		var b_hit_distance: float = (
			b_hit_position.distance_to(terrain_point)
		)

		print("Camera B ray hit position: ", b_hit_position)

		print(
			"Distance from B hit to target point: %.6f"
			% b_hit_distance
		)

		# Small tolerance for floating-point and
		# collision precision.
		if b_hit_distance < 0.05:

			terrain_point_visible_from_b = true

	print(
		"Terrain point visible from Camera B: ",
		terrain_point_visible_from_b
	)
	# --------------------------------------------------------
	# Restore Camera A
	# --------------------------------------------------------

	camera.global_position = camera_a_position

	camera.global_rotation_degrees = camera_a_rotation

	print("Camera A state restored.")

	print("========================================")
func update_simulation_ui() -> void:

	var camera_position: Vector3 = $Camera3D.global_position
	var camera_rotation: Vector3 = $Camera3D.global_rotation_degrees

	var sun_azimuth: float = $Sun.azimuth
	var sun_elevation: float = $Sun.elevation

	$UI/ControlPanel/CameraInfoLabel.text = (
		"Position: (%.2f, %.2f, %.2f)\n" %
		[
			camera_position.x,
			camera_position.y,
			camera_position.z
		]
		+
		"Rotation: (%.2f°, %.2f°, %.2f°)" %
		[
			camera_rotation.x,
			camera_rotation.y,
			camera_rotation.z
		]
	)

	$UI/ControlPanel/SunInfoLabel.text = (
		"Azimuth: %.1f°\n" %
		sun_azimuth
		+
		"Elevation: %.1f°\n" %
		sun_elevation
		+
		"J/L: Azimuth\n"
		+
		"I/K: Elevation"
	)

# ============================================================
# PHASE 7.2
# 5x5 PIXEL-LEVEL GROUND TRUTH
# ============================================================

func generate_pixel_ground_truth() -> void:

	var camera: Camera3D = $Camera3D

	# --------------------------------------------------------
	# Get Camera A state from recorded Image A data
	# --------------------------------------------------------

	var camera_a_position := Vector3(
		float(image_a_data["camera_position"][0]),
		float(image_a_data["camera_position"][1]),
		float(image_a_data["camera_position"][2])
	)

	var camera_a_rotation := Vector3(
		float(image_a_data["camera_rotation"][0]),
		float(image_a_data["camera_rotation"][1]),
		float(image_a_data["camera_rotation"][2])
	)

	# --------------------------------------------------------
	# Image size
	# --------------------------------------------------------

	var viewport_size: Vector2 = (
		camera.get_viewport().get_visible_rect().size
	)

	print("")
	print("========================================")
	print("5x5 PIXEL GROUND TRUTH GENERATION")
	print("========================================")

	print("Image size: ", viewport_size)
	print("Camera A position: ", camera_a_position)
	print("Camera A rotation: ", camera_a_rotation)

	# --------------------------------------------------------
	# Apply Camera B experiment
	# --------------------------------------------------------

	camera.global_position = (
		camera_a_position + camera_test_offset
	)

	camera.global_rotation_degrees = (
		camera_a_rotation + camera_test_rotation
	)

	print("Camera B position: ", camera.global_position)
	print("Camera B rotation: ", camera.global_rotation_degrees)

	# --------------------------------------------------------
	# Physics state
	# --------------------------------------------------------

	var space_state: PhysicsDirectSpaceState3D = (
		get_world_3d().direct_space_state
	)

	# --------------------------------------------------------
	# Storage
	# --------------------------------------------------------

	var correspondences: Array[Dictionary] = []

	# --------------------------------------------------------
	# Generate 5x5 grid
	# --------------------------------------------------------

	for row in range(5):

		for col in range(5):

			var image_a_pixel := Vector2(
				viewport_size.x * float(col + 1) / 6.0,
				viewport_size.y * float(row + 1) / 6.0
			)

			# ------------------------------------------------
			# Camera A
			# ------------------------------------------------

			camera.global_position = camera_a_position
			camera.global_rotation_degrees = camera_a_rotation

			var ray_origin: Vector3 = (
				camera.project_ray_origin(image_a_pixel)
			)

			var ray_direction: Vector3 = (
				camera.project_ray_normal(image_a_pixel)
			)

			var ray_end: Vector3 = (
				ray_origin + ray_direction * 200.0
			)

			var query := PhysicsRayQueryParameters3D.create(
				ray_origin,
				ray_end
			)

			var result: Dictionary = (
				space_state.intersect_ray(query)
			)

			# ------------------------------------------------
			# No terrain hit
			# ------------------------------------------------

			if result.is_empty():

				print(
					"Grid [", row, ",", col,
					"] - NO TERRAIN HIT"
				)

				continue

			# ------------------------------------------------
			# True 3D terrain point
			# ------------------------------------------------

			var terrain_point: Vector3 = result["position"]

			# ------------------------------------------------
			# Camera B
			# ------------------------------------------------

			camera.global_position = (
				camera_a_position + camera_test_offset
			)

			camera.global_rotation_degrees = (
				camera_a_rotation + camera_test_rotation
			)

			# ------------------------------------------------
			# Behind Camera B
			# ------------------------------------------------

			var point_behind_camera_b: bool = (
				camera.is_position_behind(terrain_point)
			)

			if point_behind_camera_b:

				print(
					"Grid [", row, ",", col,
					"] - BEHIND CAMERA B"
				)

				continue

			# ------------------------------------------------
			# Project into Camera B
			# ------------------------------------------------

			var image_b_pixel: Vector2 = (
				camera.unproject_position(terrain_point)
			)

			# ------------------------------------------------
			# Image B boundaries
			# ------------------------------------------------

			var inside_image_b: bool = (
				image_b_pixel.x >= 0.0
				and image_b_pixel.x < viewport_size.x
				and image_b_pixel.y >= 0.0
				and image_b_pixel.y < viewport_size.y
			)

			if not inside_image_b:

				print(
					"Grid [", row, ",", col,
					"] - OUTSIDE IMAGE B"
				)

				continue

			# ------------------------------------------------
			# Camera B visibility / occlusion
			# ------------------------------------------------

			var b_to_point: Vector3 = (
				terrain_point - camera.global_position
			)

			var b_distance: float = b_to_point.length()

			var b_direction: Vector3 = (
				b_to_point.normalized()
			)

			var b_ray_end: Vector3 = (
				camera.global_position
				+ b_direction * b_distance
			)

			var b_query := PhysicsRayQueryParameters3D.create(
				camera.global_position,
				b_ray_end
			)

			var b_result: Dictionary = (
				space_state.intersect_ray(b_query)
			)

			var visible_from_b: bool = false

			if not b_result.is_empty():

				var b_hit_position: Vector3 = (
					b_result["position"]
				)

				var b_hit_distance: float = (
					b_hit_position.distance_to(terrain_point)
				)

				if b_hit_distance < 0.05:

					visible_from_b = true

			if not visible_from_b:

				print(
					"Grid [", row, ",", col,
					"] - OCCLUDED"
				)

				continue

			# ------------------------------------------------
			# Valid correspondence
			# ------------------------------------------------

			var correspondence: Dictionary = {

				"grid_row": row,
				"grid_col": col,

				"image_A_pixel": [
					image_a_pixel.x,
					image_a_pixel.y
				],

				"terrain_point_3D": [
					terrain_point.x,
					terrain_point.y,
					terrain_point.z
				],

				"image_B_pixel": [
					image_b_pixel.x,
					image_b_pixel.y
				]
			}

			correspondences.append(correspondence)

			print(
				"Grid [", row, ",", col,
				"] VALID"
			)

			print(
				"  A: ", image_a_pixel,
				" -> 3D: ", terrain_point,
				" -> B: ", image_b_pixel
			)

	# --------------------------------------------------------
	# Restore Camera A
	# --------------------------------------------------------

	camera.global_position = camera_a_position
	camera.global_rotation_degrees = camera_a_rotation

	# --------------------------------------------------------
	# Build pixel ground truth
	# --------------------------------------------------------

	var pixel_ground_truth: Dictionary = {

		"image_size": [
			viewport_size.x,
			viewport_size.y
		],

		"grid_size": [
			5,
			5
		],

		"camera_A": {
			"position": [
				camera_a_position.x,
				camera_a_position.y,
				camera_a_position.z
			],
			"rotation": [
				camera_a_rotation.x,
				camera_a_rotation.y,
				camera_a_rotation.z
			]
		},

		"camera_B": {
			"position": [
				camera_a_position.x + camera_test_offset.x,
				camera_a_position.y + camera_test_offset.y,
				camera_a_position.z + camera_test_offset.z
			],
			"rotation": [
				camera_a_rotation.x + camera_test_rotation.x,
				camera_a_rotation.y + camera_test_rotation.y,
				camera_a_rotation.z + camera_test_rotation.z
			]
		},

		"camera_offset": [
			camera_test_offset.x,
			camera_test_offset.y,
			camera_test_offset.z
		],

		"camera_rotation_offset": [
			camera_test_rotation.x,
			camera_test_rotation.y,
			camera_test_rotation.z
		],

		"terrain": {
			"seed": terrain_seed,
			"crater_count": crater_count
		},

		"valid_correspondences": correspondences.size(),

		"total_grid_points": 25,

		"correspondences": correspondences
	}

	# --------------------------------------------------------
	# Save JSON
	# --------------------------------------------------------

	var json_path: String = (
		"res://data/pixel_ground_truth_test.json"
	)

	var json_text: String = JSON.stringify(
		pixel_ground_truth,
		"\t"
	)

	var file: FileAccess = FileAccess.open(
		json_path,
		FileAccess.WRITE
	)

	if file == null:

		print("ERROR: Could not create pixel ground truth file.")
		print("Path: ", json_path)

	else:

		file.store_string(json_text)
		file.close()

		print("")
		print("PIXEL GROUND TRUTH SAVED")
		print("Saved to: ", json_path)

	# --------------------------------------------------------
	# Summary
	# --------------------------------------------------------

	print("")
	print("========================================")
	print("PIXEL GROUND TRUTH COMPLETE")
	print("========================================")

	print(
		"Valid correspondences: ",
		correspondences.size(),
		" / 25"
	)

	print("Camera A state restored.")
	print("========================================")
