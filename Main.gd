extends Node3D

const MATCH_SECONDS := 300.0
const FIELD_LENGTH := 42.0
const FIELD_WIDTH := 26.0
const PLAYER_SPEED := 7.0
const BOT_SPEED := 4.4
const BALL_RADIUS := 0.34

var player: CharacterBody3D
var ball: RigidBody3D
var teammates: Array[CharacterBody3D] = []
var opponents: Array[CharacterBody3D] = []
var all_bots: Array[CharacterBody3D] = []
var score_home := 0
var score_away := 0
var time_left := MATCH_SECONDS
var match_active := true
var joystick_vector := Vector2.ZERO
var touch_origin := Vector2.ZERO
var joystick_touch_id := -1
var burst_time := 0.0
var burst_cooldown := 0.0
var ui_score: Label
var ui_timer: Label
var ui_hint: Label
var joystick_base: Control
var joystick_knob: Control
var shoot_button: Button
var pass_button: Button
var burst_button: Button
var camera_rig: Node3D
var camera: Camera3D
var rng := RandomNumberGenerator.new()
var player_visual: MeshInstance3D
var goal_flash: ColorRect
var goal_flash_time := 0.0
var burst_fx_timer := 0.0
var run_phase := 0.0

func _ready() -> void:
	rng.randomize()
	_build_world()
	_build_pitch()
	_build_goals()
	_build_players()
	_build_ball()
	_build_camera()
	_build_ui()
	_update_hud()

func _process(delta: float) -> void:
	if match_active:
		time_left = maxf(0.0, time_left - delta)
		if time_left <= 0.0:
			match_active = false
			ui_hint.text = "FULL TIME  •  Tap RESTART to play again"
		_update_hud()
	if burst_time > 0.0:
		burst_time = maxf(0.0, burst_time - delta)
	if burst_cooldown > 0.0:
		burst_cooldown = maxf(0.0, burst_cooldown - delta)
	if player_visual and player:
		var moving := Vector2(player.velocity.x, player.velocity.z).length() > 0.5
		run_phase += delta * (12.0 if moving else 3.0)
		player_visual.position.y = 0.95 + (absf(sin(run_phase)) * 0.10 if moving else 0.0)
		player_visual.rotation.z = sin(run_phase * 0.5) * 0.06 if moving else lerpf(player_visual.rotation.z, 0.0, delta * 5.0)
	if burst_time > 0.0 and player:
		burst_fx_timer -= delta
		if burst_fx_timer <= 0.0:
			burst_fx_timer = 0.12
			_spawn_skill_burst(player.global_position + Vector3(0, 0.12, 0), Color(0.15, 0.75, 1.0))
	if goal_flash_time > 0.0 and goal_flash:
		goal_flash_time = maxf(0.0, goal_flash_time - delta)
		var flash_color := goal_flash.color
		flash_color.a = clampf(goal_flash_time * 1.8, 0.0, 0.28)
		goal_flash.color = flash_color
	if camera_rig and player:
		var target := player.global_position
		camera_rig.global_position = camera_rig.global_position.lerp(target, minf(1.0, delta * 5.0))
		camera_rig.rotation.y = lerp_angle(camera_rig.rotation.y, player.rotation.y, minf(1.0, delta * 3.0))
		if joystick_knob and joystick_base:
			var offset := joystick_vector * 35.0
			joystick_knob.position = Vector2(42, 42) + offset

func _physics_process(delta: float) -> void:
	if not match_active:
		_move_ball(delta)
		return
	_move_user(delta)
	_move_bots(delta)
	_move_ball(delta)
	_check_goals()

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = ProceduralSkyMaterial.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.78, 0.9)
	environment.ambient_light_energy = 0.8
	env.environment = environment
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -30, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)

func _material(color: Color, roughness := 0.8) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat

func _mesh_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi

func _build_pitch() -> void:
	var grass := _material(Color(0.08, 0.37, 0.18))
	_mesh_box(self, Vector3(FIELD_LENGTH, 0.3, FIELD_WIDTH), Vector3(0, -0.2, 0), grass)
	for i in range(7):
		var stripe_mat := _material(Color(0.10 if i % 2 == 0 else 0.12, 0.42 if i % 2 == 0 else 0.46, 0.20))
		_mesh_box(self, Vector3(FIELD_LENGTH / 7.0, 0.015, FIELD_WIDTH), Vector3(-FIELD_LENGTH / 2.0 + FIELD_LENGTH / 14.0 + i * FIELD_LENGTH / 7.0, -0.04, 0), stripe_mat)
	var white := _material(Color(0.92, 0.95, 0.91))
	_mesh_box(self, Vector3(0.08, 0.03, FIELD_WIDTH - 0.3), Vector3(0, -0.025, 0), white)
	_mesh_box(self, Vector3(0.08, 0.03, FIELD_WIDTH - 0.3), Vector3(-FIELD_LENGTH / 2.0 + 0.2, -0.025, 0), white)
	_mesh_box(self, Vector3(0.08, 0.03, FIELD_WIDTH - 0.3), Vector3(FIELD_LENGTH / 2.0 - 0.2, -0.025, 0), white)
	_mesh_box(self, Vector3(FIELD_LENGTH - 0.3, 0.03, 0.08), Vector3(0, -0.025, -FIELD_WIDTH / 2.0 + 0.2), white)
	_mesh_box(self, Vector3(FIELD_LENGTH - 0.3, 0.03, 0.08), Vector3(0, -0.025, FIELD_WIDTH / 2.0 - 0.2), white)
	var center := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 3.7
	ring.outer_radius = 3.82
	center.mesh = ring
	center.position = Vector3(0, -0.015, 0)
	center.material_override = white
	add_child(center)
	# Low perimeter barriers and stadium seating blocks create a sense of scale.
	var dark := _material(Color(0.035, 0.07, 0.11))
	_mesh_box(self, Vector3(FIELD_LENGTH + 2, 0.6, 0.45), Vector3(0, 0.1, -FIELD_WIDTH / 2.0 - 0.45), dark)
	_mesh_box(self, Vector3(FIELD_LENGTH + 2, 0.6, 0.45), Vector3(0, 0.1, FIELD_WIDTH / 2.0 + 0.45), dark)
	for side in [-1.0, 1.0]:
		for tier in range(3):
			var seat_mat := _material([Color(0.09,0.15,0.23), Color(0.12,0.20,0.29), Color(0.16,0.24,0.34)][tier])
			_mesh_box(self, Vector3(FIELD_LENGTH + 8, 0.55, 1.5), Vector3(0, 0.25 + tier * 0.55, side * (FIELD_WIDTH / 2.0 + 2.0 + tier * 1.1)), seat_mat)

func _build_goals() -> void:
	var goal_mat := _material(Color(0.93, 0.96, 1.0), 0.4)
	for x in [-FIELD_LENGTH / 2.0 - 0.65, FIELD_LENGTH / 2.0 + 0.65]:
		_mesh_box(self, Vector3(1.4, 0.15, 7.0), Vector3(x, 0.05, 0), _material(Color(0.1, 0.1, 0.12)))
		_mesh_box(self, Vector3(0.18, 2.3, 0.18), Vector3(x, 1.1, -3.1), goal_mat)
		_mesh_box(self, Vector3(0.18, 2.3, 0.18), Vector3(x, 1.1, 3.1), goal_mat)
		_mesh_box(self, Vector3(0.18, 0.18, 6.4), Vector3(x, 2.2, 0), goal_mat)
		_mesh_box(self, Vector3(1.8, 0.08, 6.3), Vector3(x + (0.9 if x < 0 else -0.9), 0.12, 0), _material(Color(0.75, 0.85, 0.9, 0.25)))

func _make_player(team_home: bool, pos: Vector3, is_user := false) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.name = "HomePlayer" if team_home else "AwayPlayer"
	body.position = pos
	body.floor_snap_length = 0.4
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.42
	capsule.height = 1.65
	var mesh := MeshInstance3D.new()
	mesh.mesh = capsule
	mesh.position.y = 0.95
	mesh.material_override = _material(Color(0.08, 0.36, 0.95) if team_home else Color(0.92, 0.15, 0.12), 0.45)
	body.add_child(mesh)
	if is_user:
		player_visual = mesh
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.27
	sphere.height = 0.54
	head.mesh = sphere
	head.position = Vector3(0, 1.9, 0)
	head.material_override = _material(Color(0.72, 0.48, 0.32))
	body.add_child(head)
	var boot_mat := _material(Color(0.05, 0.06, 0.08))
	for z in [-0.22, 0.22]:
		var boot := MeshInstance3D.new()
		var bootmesh := BoxMesh.new()
		bootmesh.size = Vector3(0.22, 0.16, 0.32)
		boot.mesh = bootmesh
		boot.position = Vector3(0, 0.18, z)
		boot.material_override = boot_mat
		body.add_child(boot)
	var shape := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.42
	capsule_shape.height = 1.65
	shape.shape = capsule_shape
	shape.position.y = 0.92
	body.add_child(shape)
	add_child(body)
	if is_user:
		player = body
	return body

func _build_players() -> void:
	player = _make_player(true, Vector3(-12, 0, 0), true)
	teammates.append(_make_player(true, Vector3(-7, 0, -7)))
	teammates.append(_make_player(true, Vector3(-1, 0, 7)))
	teammates.append(_make_player(true, Vector3(-9, 0, 1)))
	opponents.append(_make_player(false, Vector3(11, 0, 0)))
	opponents.append(_make_player(false, Vector3(7, 0, -7)))
	opponents.append(_make_player(false, Vector3(1, 0, 7)))
	opponents.append(_make_player(false, Vector3(9, 0, 1)))
	all_bots.append_array(teammates)
	all_bots.append_array(opponents)

func _build_ball() -> void:
	ball = RigidBody3D.new()
	ball.name = "Football"
	ball.position = Vector3.ZERO
	ball.mass = 0.43
	ball.linear_damp = 0.8
	ball.angular_damp = 0.8
	ball.continuous_cd = true
	var sphere := SphereMesh.new()
	sphere.radius = BALL_RADIUS
	sphere.height = BALL_RADIUS * 2.0
	var mesh := MeshInstance3D.new()
	mesh.mesh = sphere
	mesh.material_override = _material(Color(0.95, 0.95, 0.9), 0.3)
	ball.add_child(mesh)
	var shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = BALL_RADIUS
	shape.shape = sphere_shape
	ball.add_child(shape)
	add_child(ball)

func _build_camera() -> void:
	camera_rig = Node3D.new()
	camera_rig.position = player.position
	add_child(camera_rig)
	camera = Camera3D.new()
	camera.position = Vector3(0, 5.2, 8.8)
	camera.rotation_degrees = Vector3(-24, 0, 0)
	camera.current = true
	camera.fov = 75
	camera_rig.add_child(camera)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var top := HBoxContainer.new()
	top.anchor_left = 0.25
	top.anchor_right = 0.75
	top.anchor_top = 0.025
	top.anchor_bottom = 0.12
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	layer.add_child(top)
	ui_score = Label.new()
	ui_score.add_theme_font_size_override("font_size", 30)
	ui_score.add_theme_color_override("font_color", Color.WHITE)
	top.add_child(ui_score)
	ui_timer = Label.new()
	ui_timer.add_theme_font_size_override("font_size", 27)
	ui_timer.add_theme_color_override("font_color", Color(1, 0.9, 0.35))
	top.add_child(ui_timer)
	ui_hint = Label.new()
	ui_hint.text = "BLUE TEAM  •  Score more goals!"
	ui_hint.anchor_left = 0.28
	ui_hint.anchor_right = 0.72
	ui_hint.anchor_top = 0.13
	ui_hint.anchor_bottom = 0.2
	ui_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_hint.add_theme_font_size_override("font_size", 17)
	ui_hint.add_theme_color_override("font_color", Color.WHITE)
	layer.add_child(ui_hint)
	joystick_base = Control.new()
	joystick_base.anchor_left = 0.035
	joystick_base.anchor_right = 0.035
	joystick_base.anchor_top = 0.69
	joystick_base.anchor_bottom = 0.69
	joystick_base.position = Vector2.ZERO
	joystick_base.size = Vector2(100, 100)
	joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(joystick_base)
	var base_panel := Panel.new()
	base_panel.size = Vector2(100, 100)
	base_panel.position = Vector2.ZERO
	base_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.1,0.2,0.3,0.55), Color(0.8,0.9,1,0.5)))
	joystick_base.add_child(base_panel)
	joystick_knob = Panel.new()
	joystick_knob.position = Vector2(28, 28)
	joystick_knob.size = Vector2(44, 44)
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick_knob.add_theme_stylebox_override("panel", _panel_style(Color(0.65,0.82,1,0.9), Color(1,1,1,0.9)))
	joystick_base.add_child(joystick_knob)
	shoot_button = _make_button(layer, "SHOOT", Vector2(-128, -142), Color(0.85,0.12,0.13))
	shoot_button.pressed.connect(_shoot)
	pass_button = _make_button(layer, "PASS", Vector2(-235, -80), Color(0.05,0.4,0.85))
	pass_button.pressed.connect(_pass_ball)
	burst_button = _make_button(layer, "BURST", Vector2(-128, -62), Color(0.45,0.2,0.8))
	burst_button.pressed.connect(_burst)
	var restart := _make_button(layer, "RESTART", Vector2(18, -55), Color(0.08,0.45,0.24))
	restart.anchor_left = 0.5
	restart.anchor_right = 0.5
	restart.anchor_top = 0.15
	restart.anchor_bottom = 0.15
	restart.position = Vector2(-65, 0)
	restart.size = Vector2(130, 44)
	restart.pressed.connect(_restart)
	goal_flash = ColorRect.new()
	goal_flash.anchor_right = 1.0
	goal_flash.anchor_bottom = 1.0
	goal_flash.color = Color(0.1, 0.9, 1.0, 0.0)
	goal_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(goal_flash)

func _panel_style(bg: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(50)
	return style

func _make_button(layer: CanvasLayer, caption: String, offset: Vector2, color: Color) -> Button:
	var b := Button.new()
	b.text = caption
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.anchor_top = 1.0
	b.anchor_bottom = 1.0
	b.position = offset
	b.size = Vector2(100, 72) if caption != "BURST" else Vector2(100, 54)
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", Color.WHITE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.set_corner_radius_all(18)
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	b.add_theme_stylebox_override("normal", normal)
	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = color.lightened(0.2)
	pressed_style.set_corner_radius_all(18)
	b.add_theme_stylebox_override("pressed", pressed_style)
	layer.add_child(b)
	return b

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and event.position.x < get_viewport().get_visible_rect().size.x * 0.45 and event.position.y > get_viewport().get_visible_rect().size.y * 0.55:
			joystick_touch_id = event.index
			touch_origin = event.position
			joystick_vector = Vector2.ZERO
		elif not event.pressed and event.index == joystick_touch_id:
			joystick_touch_id = -1
			joystick_vector = Vector2.ZERO
	elif event is InputEventScreenDrag and event.index == joystick_touch_id:
		var d: Vector2 = event.position - touch_origin
		joystick_vector = Vector2(clampf(d.x / 52.0, -1.0, 1.0), clampf(d.y / 52.0, -1.0, 1.0))
	elif event is InputEventMouseButton:
		if event.pressed and event.position.x < get_viewport().get_visible_rect().size.x * 0.45 and event.position.y > get_viewport().get_visible_rect().size.y * 0.55:
			joystick_touch_id = 999
			touch_origin = event.position
		elif not event.pressed and joystick_touch_id == 999:
			joystick_touch_id = -1
			joystick_vector = Vector2.ZERO
	elif event is InputEventMouseMotion and joystick_touch_id == 999:
		var d: Vector2 = event.position - touch_origin
		joystick_vector = Vector2(clampf(d.x / 52.0, -1.0, 1.0), clampf(d.y / 52.0, -1.0, 1.0))

func _move_user(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var input_dir := joystick_vector
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): input_dir.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): input_dir.x += 1.0
	input_dir = input_dir.limit_length(1.0)
	var forward := -camera_rig.global_basis.z
	forward.y = 0
	forward = forward.normalized()
	var right := camera_rig.global_basis.x
	right.y = 0
	right = right.normalized()
	var direction := (right * input_dir.x + forward * -input_dir.y).normalized()
	var speed := PLAYER_SPEED * (1.8 if burst_time > 0.0 else 1.0)
	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed
	player.velocity.y = -0.5
	player.move_and_slide()
	if direction.length() > 0.1:
		player.rotation.y = lerp_angle(player.rotation.y, atan2(-direction.x, -direction.z), minf(1.0, delta * 10.0))
	player.position.x = clampf(player.position.x, -FIELD_LENGTH / 2.0 + 1.0, FIELD_LENGTH / 2.0 - 1.0)
	player.position.z = clampf(player.position.z, -FIELD_WIDTH / 2.0 + 1.0, FIELD_WIDTH / 2.0 - 1.0)

func _move_bots(delta: float) -> void:
	for bot in all_bots:
		if not is_instance_valid(bot):
			continue
		var target := ball.global_position
		if teammates.has(bot) and bot.global_position.distance_to(ball.global_position) > 8.0:
			target = Vector3(-5, 0, 0) if bot == teammates[0] else Vector3(ball.global_position.x - 3.0, 0, ball.global_position.z + (2.0 if bot == teammates[1] else -2.0))
		if opponents.has(bot) and bot.global_position.distance_to(ball.global_position) > 11.0:
			target = Vector3(5, 0, ball.global_position.z * 0.6)
		var to_target := target - bot.global_position
		to_target.y = 0
		var dir := to_target.normalized()
		var speed := BOT_SPEED * (0.82 if opponents.has(bot) else 1.0)
		bot.velocity.x = dir.x * speed
		bot.velocity.z = dir.z * speed
		bot.velocity.y = -0.5
		bot.move_and_slide()
		bot.position.x = clampf(bot.position.x, -FIELD_LENGTH / 2.0 + 0.8, FIELD_LENGTH / 2.0 - 0.8)
		bot.position.z = clampf(bot.position.z, -FIELD_WIDTH / 2.0 + 0.8, FIELD_WIDTH / 2.0 - 0.8)
		if dir.length() > 0.1:
			bot.rotation.y = atan2(-dir.x, -dir.z)
		if bot.global_position.distance_to(ball.global_position) < 1.25 and rng.randf() < delta * 1.4:
			var goal_x := -FIELD_LENGTH / 2.0 if opponents.has(bot) else FIELD_LENGTH / 2.0
			var aim := Vector3(goal_x, 0.15, rng.randf_range(-2.5, 2.5)) - ball.global_position
			ball.apply_central_impulse(aim.normalized() * rng.randf_range(4.0, 7.0))

func _move_ball(_delta: float) -> void:
	if ball.global_position.y < BALL_RADIUS:
		var p := ball.global_position
		p.y = BALL_RADIUS
		ball.global_position = p
	if absf(ball.global_position.z) > FIELD_WIDTH / 2.0 - 0.4:
		ball.linear_velocity.z *= -0.65
		ball.global_position.z = clampf(ball.global_position.z, -FIELD_WIDTH / 2.0 + 0.5, FIELD_WIDTH / 2.0 - 0.5)
	ball.linear_velocity.x = clampf(ball.linear_velocity.x, -18.0, 18.0)
	ball.linear_velocity.z = clampf(ball.linear_velocity.z, -14.0, 14.0)

func _near_ball() -> bool:
	return player.global_position.distance_to(ball.global_position) < 2.0

func _shoot() -> void:
	if not match_active or not _near_ball():
		ui_hint.text = "Get closer to the ball to shoot"
		return
	var dir := Vector3(1, 0.15, 0) + Vector3(0, 0, -player.global_position.z * 0.02)
	ball.apply_central_impulse(dir.normalized() * 13.0)
	_spawn_skill_burst(ball.global_position, Color(1.0, 0.25, 0.12))
	ui_hint.text = "⚡ POWER SHOT! ⚡"

func _pass_ball() -> void:
	if not match_active or not _near_ball():
		ui_hint.text = "Get closer to the ball to pass"
		return
	var target := teammates[0].global_position if not teammates.is_empty() else player.global_position + Vector3(5,0,0)
	var dir := (target - ball.global_position).normalized()
	dir.y = 0.05
	ball.apply_central_impulse(dir.normalized() * 7.5)
	_spawn_skill_burst(ball.global_position, Color(0.15, 0.65, 1.0))
	ui_hint.text = "◆ PERFECT PASS ◆"

func _burst() -> void:
	if burst_cooldown > 0.0:
		ui_hint.text = "BURST recharging..."
		return
	burst_time = 1.6
	burst_cooldown = 5.0
	burst_fx_timer = 0.0
	_spawn_skill_burst(player.global_position, Color(0.15, 0.75, 1.0))
	ui_hint.text = "⚡ ANIME BURST! ⚡"

func _check_goals() -> void:
	if ball.global_position.x > FIELD_LENGTH / 2.0 + 0.5 and absf(ball.global_position.z) < 3.1:
		score_home += 1
		_reset_kickoff("GOAL! BLUE TEAM SCORES")
	elif ball.global_position.x < -FIELD_LENGTH / 2.0 - 0.5 and absf(ball.global_position.z) < 3.1:
		score_away += 1
		_reset_kickoff("RED TEAM SCORES")
	if absf(ball.global_position.x) > FIELD_LENGTH / 2.0 + 2.0:
		_reset_ball()

func _reset_ball() -> void:
	ball.global_position = Vector3.ZERO
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO

func _reset_kickoff(message: String) -> void:
	ui_hint.text = message
	if goal_flash:
		goal_flash.color = Color(0.12, 0.95, 1.0, 0.28) if message.contains("GOAL") or message.contains("SCORES") else Color(0.1, 0.9, 1.0, 0.0)
		goal_flash_time = 0.35 if message.contains("GOAL") or message.contains("SCORES") else 0.0
	if message.contains("GOAL") or message.contains("SCORES"):
		_spawn_skill_burst(Vector3(FIELD_LENGTH / 2.0 if message.contains("BLUE") else -FIELD_LENGTH / 2.0, 0.2, 0), Color(1.0, 0.85, 0.2))
	_reset_ball()
	player.global_position = Vector3(-12,0,0)
	var starts_home := [Vector3(-7,0,-7), Vector3(-1,0,7), Vector3(-9,0,1)]
	var starts_away := [Vector3(11,0,0), Vector3(7,0,-7), Vector3(1,0,7), Vector3(9,0,1)]
	for i in range(teammates.size()):
		teammates[i].global_position = starts_home[i]
	for i in range(opponents.size()):
		opponents[i].global_position = starts_away[i]
	_update_hud()

func _restart() -> void:
	score_home = 0
	score_away = 0
	time_left = MATCH_SECONDS
	match_active = true
	burst_time = 0
	burst_cooldown = 0
	_reset_kickoff("KICK OFF!  •  Score more goals!")

func _update_hud() -> void:
	if not ui_score:
		return
	ui_score.text = "  BLUE  %d  -  %d  RED     " % [score_home, score_away]
	var total := int(ceil(time_left))
	ui_timer.text = "   %02d:%02d" % [total / 60, total % 60]
	if burst_button:
		burst_button.text = "BURST" if burst_cooldown <= 0.0 else str(int(ceil(burst_cooldown))) + "s"


func _spawn_skill_burst(at: Vector3, tint: Color) -> void:
	# Lightweight procedural anime impact ring: no external art assets required.
	var fx := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.42
	ring.outer_radius = 0.58
	fx.mesh = ring
	fx.global_position = at
	fx.scale = Vector3.ONE * 0.22
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.82)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = 1.8
	fx.material_override = mat
	add_child(fx)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(fx, "scale", Vector3.ONE * 2.8, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color", Color(tint.r, tint.g, tint.b, 0.0), 0.42)
	tween.tween_property(fx, "position:y", at.y + 0.65, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(fx.queue_free)
