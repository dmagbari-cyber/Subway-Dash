extends Node3D

const LANES := [-2.6, 0.0, 2.6]
const SEGMENT_LENGTH := 36.0
const SEGMENT_COUNT := 8
const START_SPEED := 13.0
const MAX_SPEED := 24.0
const JUMP_AIRTIME := 1.5
const SCORE_SPEED_STEP := 180.0
const SPEED_PER_SCORE_STEP := 0.75
const RUNNER_MODEL_PATH := "res://assets/kenney_mini_characters/character-male-c.glb"
const CITY_BUILDINGS := ["building-a.glb", "building-d.glb", "building-g.glb", "building-j.glb", "building-m.glb", "building-skyscraper-a.glb", "building-skyscraper-c.glb", "building-skyscraper-e.glb"]

var player: CharacterBody3D
var player_shape: CollisionShape3D
var player_skin: Node3D
var camera: Camera3D
var world_root: Node3D
var segments: Array[Node3D] = []
var next_segment_z := 0.0
var rng := RandomNumberGenerator.new()
var lane := 1
var speed := START_SPEED
var distance := 0.0
var score := 0
var coins := 0
var running := false
var game_over := false
var sliding := false
var slide_time := 0.0
var jump_velocity := 0.0
var riding_train := false
var ride_train_end_z := 0.0
var start_grace_time := 0.0
var hud: CanvasLayer
var score_label: Label
var coin_label: Label
var speed_label: Label
var overlay: ColorRect
var overlay_title: Label
var overlay_message: Label
var play_button: Button
var quit_button: Button
var coin_material: StandardMaterial3D
var materials: Dictionary = {}


func _ready() -> void:
	_rng_seed()
	_create_materials()
	_create_world()
	_create_player()
	_create_camera()
	_create_hud()
	for i in range(SEGMENT_COUNT):
		_add_segment(next_segment_z)
		next_segment_z -= SEGMENT_LENGTH
	_show_overlay("SUBWAY DASH", "DODGE THE TRAINS  •  GRAB THE COINS  •  JUMP ON MARKED TRAINS\n\nA / D  Switch lanes     SPACE  Jump     ↓  Slide", "START RUN")


func _rng_seed() -> void:
	rng.randomize()


func _create_materials() -> void:
	materials["track_a"] = _mat(Color("373534"), 0.9)
	materials["track_b"] = _mat(Color("403d3a"), 0.9)
	materials["rail"] = _mat(Color("79736a"), 0.62)
	materials["sleeper"] = _mat(Color("d9c6a2"), 0.75)
	materials["stripe"] = _mat(Color("f5e6c9"), 0.72)
	materials["gold"] = _mat(Color("f5bd55"), 0.5, 0.12)
	materials["barrier"] = _mat(Color("d85f40"), 0.55, 0.03)
	materials["barrier_dark"] = _mat(Color("463b32"), 0.72)
	materials["overhead"] = _mat(Color("df8848"), 0.58, 0.02)
	materials["train_body"] = _mat(Color("1f6687"), 0.38, 0.02)
	materials["train_trim"] = _mat(Color("e7a94f"), 0.45, 0.03)
	materials["train_window"] = _mat(Color("a8d9e4"), 0.3, 0.08)
	materials["train_dark"] = _mat(Color("26323a"), 0.62)
	materials["white"] = _mat(Color("fff2d8"), 0.6)
	materials["skin"] = _mat(Color("e7ad7b"), 0.72)
	materials["jacket"] = _mat(Color("2870a9"), 0.58)
	materials["pants"] = _mat(Color("303941"), 0.68)
	materials["hair"] = _mat(Color("33251e"), 0.75)
	materials["window"] = _mat(Color("86a7b8"), 0.42, 0.02)
	materials["window_warm"] = _mat(Color("f1b86c"), 0.42, 0.05)
	materials["lamp"] = _mat(Color("ffd28b"), 0.45, 0.16)
	materials["sign"] = _mat(Color("e7834d"), 0.52, 0.04)
	coin_material = materials["gold"]


func _mat(color: Color, roughness := 0.35, emission := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	return material


func _create_world() -> void:
	world_root = Node3D.new()
	world_root.name = "EndlessCity"
	add_child(world_root)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("6689a6")
	sky_material.sky_horizon_color = Color("efb16f")
	sky_material.ground_bottom_color = Color("98806b")
	sky_material.ground_horizon_color = Color("e5a36d")
	sky_material.sun_angle_max = 18.0
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e7c6a0")
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.35
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, -25.0, 0.0)
	sun.light_color = Color("ffbdab")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)


func _create_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Runner"
	player.position = Vector3(0.0, 0.0, -6.0)
	player.floor_snap_length = 0.25
	player.floor_max_angle = deg_to_rad(48.0)
	player.collision_layer = 1
	player.collision_mask = 1
	add_child(player)
	player_shape = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.85
	player_shape.shape = capsule
	player_shape.position.y = 0.93
	player.add_child(player_shape)
	var runner_scene := load(RUNNER_MODEL_PATH) as PackedScene
	player_skin = runner_scene.instantiate() as Node3D
	player_skin.name = "RunnerVisual"
	player.add_child(player_skin)


func _add_capsule_mesh(parent: Node3D, pos: Vector3, radius: float, height: float, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)


func _create_camera() -> void:
	camera = Camera3D.new()
	camera.name = "RunnerCamera"
	camera.position = Vector3(0.0, 5.3, 10.5)
	camera.current = true
	camera.fov = 72.0
	add_child(camera)
	camera.look_at(Vector3(0.0, 1.0, -5.0), Vector3.UP)


func _create_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 2
	add_child(hud)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(root)
	var top_panel := PanelContainer.new()
	top_panel.position = Vector2(26, 22)
	top_panel.custom_minimum_size = Vector2(260, 94)
	root.add_child(top_panel)
	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 1)
	top_panel.add_child(stats)
	score_label = _label("SCORE  00000", 25, Color("ffffff"))
	coin_label = _label("◆  0", 20, Color("f5bd55"))
	speed_label = _label("SPEED  13", 14, Color("f7d8a7"))
	stats.add_child(score_label)
	stats.add_child(coin_label)
	stats.add_child(speed_label)
	overlay = ColorRect.new()
	overlay.color = Color(0.12, 0.09, 0.07, 0.82)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)
	var center := VBoxContainer.new()
	center.anchor_left = 0.5
	center.anchor_top = 0.5
	center.anchor_right = 0.5
	center.anchor_bottom = 0.5
	center.offset_left = -310
	center.offset_top = -155
	center.offset_right = 310
	center.offset_bottom = 155
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 15)
	overlay.add_child(center)
	overlay_title = _label("SUBWAY DASH", 48, Color("f5bd55"))
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(overlay_title)
	overlay_message = _label("", 17, Color("fff0db"))
	overlay_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(overlay_message)
	play_button = Button.new()
	play_button.text = "START RUN"
	play_button.custom_minimum_size = Vector2(220, 58)
	play_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play_button.add_theme_font_size_override("font_size", 21)
	play_button.add_theme_color_override("font_color", Color("35251c"))
	play_button.add_theme_color_override("font_color_hover", Color("35251c"))
	play_button.add_theme_stylebox_override("normal", _button_style(Color("f5bd55")))
	play_button.add_theme_stylebox_override("hover", _button_style(Color("ffd28b")))
	play_button.add_theme_stylebox_override("pressed", _button_style(Color("d99339")))
	play_button.pressed.connect(_on_play_pressed)
	center.add_child(play_button)
	quit_button = Button.new()
	quit_button.text = "QUIT"
	quit_button.custom_minimum_size = Vector2(220, 52)
	quit_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quit_button.add_theme_font_size_override("font_size", 19)
	quit_button.add_theme_color_override("font_color", Color("fff0db"))
	quit_button.add_theme_color_override("font_color_hover", Color("ffffff"))
	quit_button.add_theme_stylebox_override("normal", _button_style(Color("5a4940")))
	quit_button.add_theme_stylebox_override("hover", _button_style(Color("765d50")))
	quit_button.add_theme_stylebox_override("pressed", _button_style(Color("40332d")))
	quit_button.pressed.connect(_on_quit_pressed)
	quit_button.visible = false
	center.add_child(quit_button)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.02, 0.04, 0.1, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(13)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _show_overlay(title: String, message: String, button_text: String, show_quit := false) -> void:
	overlay_title.text = title
	overlay_message.text = message
	play_button.text = button_text
	quit_button.visible = show_quit
	overlay.visible = true


func _on_play_pressed() -> void:
	_reset_run()
	running = true
	game_over = false
	start_grace_time = 1.0
	overlay.visible = false


func _reset_run() -> void:
	for segment in segments:
		world_root.remove_child(segment)
		segment.queue_free()
	segments.clear()
	lane = 1
	speed = START_SPEED
	distance = 0.0
	score = 0
	coins = 0
	player.position = Vector3(0.0, 0.0, -6.0)
	player.velocity = Vector3.ZERO
	jump_velocity = 0.0
	riding_train = false
	ride_train_end_z = 0.0
	_set_sliding(false)
	next_segment_z = 0.0
	for i in range(SEGMENT_COUNT):
		_add_segment(next_segment_z)
		next_segment_z -= SEGMENT_LENGTH


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event.is_action_pressed("lane_left"):
		lane = maxi(0, lane - 1)
	elif event.is_action_pressed("lane_right"):
		lane = mini(2, lane + 1)
	elif event.is_action_pressed("jump") and player.is_on_floor():
		var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
		jump_velocity = gravity * JUMP_AIRTIME * 0.5
	elif event.is_action_pressed("slide"):
		_set_sliding(true)


func _physics_process(delta: float) -> void:
	if not running:
		return
	start_grace_time = maxf(0.0, start_grace_time - delta)
	distance += speed * delta
	score = int(distance) + coins * 10
	speed = minf(MAX_SPEED, START_SPEED + floori(float(score) / SCORE_SPEED_STEP) * SPEED_PER_SCORE_STEP)
	player.velocity.z = -speed
	player.position.x = LANES[lane]
	player.velocity.x = 0.0
	if riding_train and player.position.z <= ride_train_end_z:
		riding_train = false
	if riding_train:
		player.position.y = 3.05
		player.velocity.y = 0.0
	elif player.is_on_floor():
		if jump_velocity <= 0.0:
			player.velocity.y = 0.0
		else:
			player.velocity.y = jump_velocity
			jump_velocity = 0.0
	else:
		player.velocity.y -= float(ProjectSettings.get_setting("physics/3d/default_gravity")) * delta
	player.move_and_slide()
	if sliding:
		slide_time -= delta
		if slide_time <= 0.0:
			_set_sliding(false)
	_update_camera(delta)
	_update_segments()
	_update_hud()
	_check_fall()


func _process(delta: float) -> void:
	if not running:
		return
	for segment in segments:
		for item in segment.get_children():
			if item.is_in_group("coins"):
				item.rotate_y(delta * 2.8)
				item.position.y = 1.15 + sin(Time.get_ticks_msec() * 0.004 + item.position.z) * 0.12
	player_skin.rotation.z = lerpf(player_skin.rotation.z, -player.velocity.x * 0.035, minf(delta * 7.0, 1.0))


func _update_camera(delta: float) -> void:
	var target := Vector3(0.0, 5.3, player.position.z + 10.5)
	camera.position = camera.position.lerp(target, minf(delta * 4.5, 1.0))
	camera.look_at(Vector3(0.0, 1.1, player.position.z - 5.0), Vector3.UP)


func _update_hud() -> void:
	score_label.text = "SCORE  %05d" % score
	coin_label.text = "◆  %d" % coins
	speed_label.text = "SPEED  %d" % int(speed)


func _check_fall() -> void:
	if player.position.y < -4.0 and running:
		_finish_run()


func _add_segment(start_z: float) -> void:
	var segment := Node3D.new()
	segment.name = "TrackSegment"
	segment.position.z = start_z
	world_root.add_child(segment)
	segments.append(segment)
	_add_box(segment, Vector3(0, -0.32, -SEGMENT_LENGTH * 0.5), Vector3(10.8, 0.55, SEGMENT_LENGTH), materials["track_a"] if segments.size() % 2 == 0 else materials["track_b"], true)
	for side in [-1.0, 1.0]:
		_add_box(segment, Vector3(side * 5.25, 0.015, -SEGMENT_LENGTH * 0.5), Vector3(0.24, 0.11, SEGMENT_LENGTH), materials["rail"])
	for x in [-1.3, 1.3]:
		for i in range(6):
			var z := -float(i) * 6.0 - 2.0
			_add_box(segment, Vector3(x, -0.015, z), Vector3(0.11, 0.035, 2.6), materials["stripe"])
	_add_city_side(segment, -1.0)
	_add_city_side(segment, 1.0)
	_add_segment_props(segment)


func _add_city_side(segment: Node3D, side: float) -> void:
	var building_name: String = CITY_BUILDINGS[rng.randi_range(0, CITY_BUILDINGS.size() - 1)]
	var building_scene := load("res://assets/kenney_city_commercial/" + building_name) as PackedScene
	var building := building_scene.instantiate() as Node3D
	building.position = Vector3(side * rng.randf_range(9.0, 11.0), 0.0, -SEGMENT_LENGTH * 0.5)
	building.rotation.y = -side * PI * 0.5
	building.scale = Vector3.ONE * rng.randf_range(1.1, 1.5)
	segment.add_child(building)


func _add_segment_props(segment: Node3D) -> void:
	var street_light_scene := load("res://assets/kenney_city_roads/light-square.glb") as PackedScene
	for side in [-1.0, 1.0]:
		var lamp_z := -rng.randf_range(8.0, 28.0)
		var street_light := street_light_scene.instantiate() as Node3D
		street_light.position = Vector3(side * 5.7, 0.0, lamp_z)
		street_light.rotation.y = -side * PI * 0.5
		segment.add_child(street_light)
	if rng.randf() < 0.35:
		var street_sign_scene := load("res://assets/kenney_city_roads/road-sign-street.glb") as PackedScene
		var street_sign := street_sign_scene.instantiate() as Node3D
		var sign_side := -1.0 if rng.randf() < 0.5 else 1.0
		street_sign.position = Vector3(sign_side * 6.0, 0.0, -rng.randf_range(6.0, 30.0))
		street_sign.rotation.y = -sign_side * PI * 0.5
		segment.add_child(street_sign)
	if segment.position.z >= -36.1:
		_add_coin_line(segment, 1, -20.0)
		return
	var obstacle_count := rng.randi_range(2, 3)
	var previous_lane := -1
	for i in range(obstacle_count):
		var obstacle_lane := rng.randi_range(0, 2)
		if obstacle_lane == previous_lane:
			obstacle_lane = (obstacle_lane + rng.randi_range(1, 2)) % 3
		previous_lane = obstacle_lane
		var z := -rng.randf_range(8.0 + i * 11.0, 9.5 + i * 11.0)
		if rng.randf() < 0.22:
			_add_train(segment, obstacle_lane, z, rng.randf() < 0.45)
		elif rng.randf() < 0.48:
			_add_barrier(segment, obstacle_lane, z)
		else:
			_add_overhead(segment, obstacle_lane, z)
		if rng.randf() < 0.76:
			_add_coin_line(segment, (obstacle_lane + 1) % 3, z - 2.8)
	if rng.randf() < 0.7:
		_add_coin_line(segment, rng.randi_range(0, 2), -rng.randf_range(17.0, 30.0))


func _add_train(parent: Node3D, train_lane: int, z: float, boardable: bool) -> void:
	var train := Area3D.new()
	train.name = "BoardableTrain" if boardable else "TrainObstacle"
	train.set_meta("boardable", boardable)
	train.position = Vector3(LANES[train_lane], 0.0, z)
	train.collision_layer = 0
	train.collision_mask = 1
	parent.add_child(train)

	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.15, 3.1, 9.5)
	shape_node.shape = shape
	shape_node.position.y = 1.55
	train.add_child(shape_node)

	_add_box(train, Vector3(0.0, 1.65, 0.0), Vector3(2.0, 2.45, 9.2), materials["train_body"])
	_add_box(train, Vector3(0.0, 0.32, 0.0), Vector3(2.12, 0.48, 9.4), materials["train_dark"])
	_add_box(train, Vector3(0.0, 2.9, 0.0), Vector3(2.08, 0.16, 9.35), materials["train_dark"])
	_add_box(train, Vector3(0.0, 1.12, 4.66), Vector3(2.04, 0.12, 0.12), materials["train_trim"])
	_add_box(train, Vector3(0.0, 2.16, 4.64), Vector3(1.58, 0.72, 0.08), materials["train_window"])
	_add_box(train, Vector3(-0.83, 0.62, 4.72), Vector3(0.18, 0.18, 0.12), materials["lamp"])
	_add_box(train, Vector3(0.83, 0.62, 4.72), Vector3(0.18, 0.18, 0.12), materials["lamp"])

	for side in [-1.0, 1.0]:
		_add_box(train, Vector3(side * 1.02, 1.12, 0.0), Vector3(0.08, 0.12, 9.0), materials["train_trim"])
		for window_index in range(5):
			var window_z := -3.6 + float(window_index) * 1.8
			_add_box(train, Vector3(side * 1.02, 2.12, window_z), Vector3(0.08, 0.68, 1.05), materials["train_window"])

	if boardable:
		for step in range(3):
			_add_box(train, Vector3(0.0, 0.3 + step * 0.28, 4.78), Vector3(0.72, 0.08, 0.32), materials["train_trim"])
	train.body_entered.connect(_on_train_hit.bind(train))


func _add_barrier(parent: Node3D, obstacle_lane: int, z: float) -> void:
	var area := Area3D.new()
	area.name = "JumpBarrier"
	area.position = Vector3(LANES[obstacle_lane], 0.0, z)
	area.collision_layer = 0
	area.collision_mask = 1
	parent.add_child(area)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.65, 1.35, 0.85)
	shape_node.shape = shape
	shape_node.position.y = 0.68
	area.add_child(shape_node)
	var barrier_scene := load("res://assets/kenney_city_roads/construction-barrier.glb") as PackedScene
	var barrier_model := barrier_scene.instantiate() as Node3D
	area.add_child(barrier_model)
	area.body_entered.connect(_on_obstacle_hit.bind(area))


func _add_overhead(parent: Node3D, obstacle_lane: int, z: float) -> void:
	var area := Area3D.new()
	area.name = "SlideGate"
	area.position = Vector3(LANES[obstacle_lane], 0.0, z)
	area.collision_layer = 0
	area.collision_mask = 1
	parent.add_child(area)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.9, 0.52, 0.9)
	shape_node.shape = shape
	shape_node.position.y = 1.72
	area.add_child(shape_node)
	_add_box(area, Vector3(0, 1.72, 0), Vector3(1.9, 0.52, 0.9), materials["overhead"])
	_add_box(area, Vector3(-0.82, 1.05, 0), Vector3(0.16, 1.4, 0.82), materials["overhead"])
	_add_box(area, Vector3(0.82, 1.05, 0), Vector3(0.16, 1.4, 0.82), materials["overhead"])
	area.body_entered.connect(_on_obstacle_hit.bind(area))


func _add_coin_line(parent: Node3D, coin_lane: int, z: float) -> void:
	for i in range(5):
		var area := Area3D.new()
		area.name = "Coin"
		area.add_to_group("coins")
		area.position = Vector3(LANES[coin_lane], 1.15, z - i * 1.5)
		area.collision_layer = 0
		area.collision_mask = 1
		parent.add_child(area)
		var shape_node := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 0.55
		shape_node.shape = shape
		area.add_child(shape_node)
		var coin_mesh := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.22
		mesh.outer_radius = 0.38
		mesh.rings = 8
		mesh.ring_segments = 16
		coin_mesh.mesh = mesh
		coin_mesh.material_override = coin_material
		coin_mesh.rotation.x = deg_to_rad(90)
		area.add_child(coin_mesh)
		area.body_entered.connect(_on_coin_collected.bind(area))


func _add_box(parent: Node3D, pos: Vector3, size: Vector3, material: Material, collider := false) -> void:
	if collider:
		var body := StaticBody3D.new()
		body.position = pos
		body.collision_layer = 1
		body.collision_mask = 0
		parent.add_child(body)
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		body.add_child(shape_node)
		var mesh_instance := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size
		mesh_instance.mesh = mesh
		mesh_instance.material_override = material
		body.add_child(mesh_instance)
	else:
		var mesh_instance := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size
		mesh_instance.mesh = mesh
		mesh_instance.position = pos
		mesh_instance.material_override = material
		parent.add_child(mesh_instance)


func _add_sphere(parent: Node3D, pos: Vector3, radius: float, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)


func _set_sliding(value: bool) -> void:
	sliding = value
	slide_time = 0.85 if value else 0.0
	if not is_instance_valid(player_shape):
		return
	var capsule := player_shape.shape as CapsuleShape3D
	capsule.height = 1.0 if value else 1.85
	player_shape.position.y = 0.5 if value else 0.93
	player_skin.scale.y = 0.52 if value else 1.0
	player_skin.position.y = 0.32 if value else 0.0


func _update_segments() -> void:
	if player.position.z < next_segment_z + SEGMENT_LENGTH * (SEGMENT_COUNT - 2):
		_add_segment(next_segment_z)
		next_segment_z -= SEGMENT_LENGTH
	while segments.size() > SEGMENT_COUNT:
		var old: Node3D = segments.pop_front() as Node3D
		old.queue_free()


func _on_train_hit(body: Node3D, train: Area3D) -> void:
	if body != player or not running or start_grace_time > 0.0 or not train.overlaps_body(player):
		return
	if train.get_meta("boardable", false) and not riding_train and player.position.y > 0.5:
		riding_train = true
		ride_train_end_z = train.global_position.z - 4.75
		player.position.y = 3.05
		player.velocity.y = 0.0
		jump_velocity = 0.0
		return
	_finish_run()


func _on_obstacle_hit(body: Node3D, obstacle: Area3D) -> void:
	if body == player and running and start_grace_time <= 0.0 and obstacle.overlaps_body(player):
		_finish_run()


func _on_coin_collected(body: Node3D, coin: Area3D) -> void:
	if body != player or not running or not is_instance_valid(coin):
		return
	coins += 1
	coin.queue_free()


func _finish_run() -> void:
	if game_over:
		return
	running = false
	game_over = true
	_show_overlay("RUN OVER", "SCORE  %d    •    DISTANCE  %d    •    COINS  %d" % [score, int(distance), coins], "RUN AGAIN", true)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		_setup_input()


func _setup_input() -> void:
	_add_action("lane_left", [KEY_LEFT, KEY_A])
	_add_action("lane_right", [KEY_RIGHT, KEY_D])
	_add_action("jump", [KEY_SPACE])
	_add_action("slide", [KEY_DOWN, KEY_S, KEY_SHIFT])


func _add_action(action: StringName, keys: Array[int]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)
