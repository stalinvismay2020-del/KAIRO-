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
var match_active := false
var is_paused := false
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
var ball_visual: MeshInstance3D
var kick_anim_time := 0.0
var kick_anim_leg: Node3D
var player_left_leg: Node3D
var player_right_leg: Node3D
var player_left_arm: Node3D
var player_right_arm: Node3D
var ball_bounce_phase := 0.0
var goal_flash: ColorRect
var goal_flash_time := 0.0
var burst_fx_timer := 0.0
var run_phase := 0.0
var lobby_layer: CanvasLayer
var lobby_status: Label
var character_picker: OptionButton
var ability_picker: OptionButton
var color_picker: OptionButton
var selected_ability := "Speed Burst"
var selected_character := "Striker"
var selected_team_color := "Electric Blue"
var wins_total := 0
var goals_total := 0
var player_level := 1
var aim_line: MeshInstance3D
var goal_banner: Label
var sfx_player: AudioStreamPlayer
var goal_animation_busy := false
var goal_banner_tween: Tween
var sound_enabled := true
var ultimate_cooldown := 0.0
var ultimate_button: Button
var pause_button: Button
var sound_button: Button
var ultimate_fx_timer := 0.0

func _ready() -> void:
	rng.randomize()
	_build_world()
	_build_pitch()
	_build_goals()
	_build_players()
	_build_ball()
	_build_camera()
	_build_ui()
	_load_progress()
	_build_lobby()
	_update_hud()
	_build_founder_intro()


func _build_founder_intro() -> void:
	# Founder-only cinematic intro: no roster or extra characters appear here.
	lobby_layer.visible = false
	var intro := CanvasLayer.new()
	intro.layer = 30
	add_child(intro)
	var backdrop := ColorRect.new()
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	backdrop.color = Color(0.008, 0.012, 0.035, 1.0)
	intro.add_child(backdrop)
	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.offset_left = 16
	center.offset_right = -16
	intro.add_child(center)
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 14)
	center.add_child(stack)
	var aura := Label.new()
	aura.text = "◉"
	aura.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aura.add_theme_font_size_override("font_size", 94)
	aura.add_theme_color_override("font_color", Color(0.2, 0.68, 1.0, 0.95))
	stack.add_child(aura)
	var title := Label.new()
	title.text = "ECLIPSE STRIKERS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 29)
	title.add_theme_color_override("font_color", Color(0.35, 0.82, 1.0))
	stack.add_child(title)
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(180, 3)
	line.color = Color(0.85, 0.12, 0.28, 0.95)
	stack.add_child(line)
	var founder := Label.new()
	founder.text = "FOUNDER\nSTALIN VISMAY"
	founder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	founder.add_theme_font_size_override("font_size", 23)
	founder.add_theme_color_override("font_color", Color(1.0, 0.94, 0.9))
	stack.add_child(founder)
	var identity := Label.new()
	identity.text = "KING OF KINGS  •  INNOCENT ZERO"
	identity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	identity.add_theme_font_size_override("font_size", 13)
	identity.add_theme_color_override("font_color", Color(0.72, 0.78, 0.92))
	stack.add_child(identity)
	var skip := Button.new()
	skip.text = "ENTER THE ARENA  ▶"
	skip.custom_minimum_size = Vector2(210, 44)
	skip.add_theme_color_override("font_color", Color.WHITE)
	skip.add_theme_stylebox_override("normal", _panel_style(Color(0.04, 0.22, 0.42), Color(0.2, 0.68, 1.0)))
	stack.add_child(skip)
	var finish_intro := func() -> void:
		if is_instance_valid(intro):
			var fade := create_tween()
			fade.tween_property(intro, "modulate:a", 0.0, 0.35)
			fade.tween_callback(func() -> void:
				if is_instance_valid(intro):
					intro.queue_free()
				if is_instance_valid(lobby_layer):
					lobby_layer.visible = true
			)
	skip.pressed.connect(finish_intro)
	var pulse := create_tween().set_loops()
	pulse.tween_property(aura, "scale", Vector2(1.13, 1.13), 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(aura, "scale", Vector2.ONE, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var reveal := create_tween()
	reveal.tween_interval(4.5)
	reveal.tween_callback(finish_intro)

func _process(delta: float) -> void:
	_update_aim_guide()
	if match_active and not is_paused:
		time_left = maxf(0.0, time_left - delta)
		if time_left <= 0.0:
			match_active = false
			if score_home > score_away:
				wins_total += 1
			player_level = 1 + int(wins_total / 3) + int(goals_total / 10)
			_save_progress()
			var stats := lobby_layer.find_child("ProgressStats", true, false) as Label
			if stats:
				stats.text = "LEVEL %d   •   WINS %d   •   GOALS %d" % [player_level, wins_total, goals_total]
			ui_hint.text = "FULL TIME  •  Tap RESTART to play again"
		_update_hud()
	if burst_time > 0.0:
		burst_time = maxf(0.0, burst_time - delta)
	if burst_cooldown > 0.0:
		burst_cooldown = maxf(0.0, burst_cooldown - delta)
	if ultimate_cooldown > 0.0:
		ultimate_cooldown = maxf(0.0, ultimate_cooldown - delta)
	if ultimate_button:
		ultimate_button.text = "ULTIMATE" if ultimate_cooldown <= 0.0 else "ULT " + str(int(ceil(ultimate_cooldown))) + "s"
	if player_visual and player:
		var moving := Vector2(player.velocity.x, player.velocity.z).length() > 0.5
		run_phase += delta * (12.0 if moving else 3.0)
		player_visual.position.y = 0.95 + (absf(sin(run_phase)) * 0.10 if moving else 0.0)
		player_visual.rotation.z = sin(run_phase * 0.5) * 0.06 if moving else lerpf(player_visual.rotation.z, 0.0, delta * 5.0)
		if player_left_leg and player_right_leg and kick_anim_time <= 0.0:
			var stride := sin(run_phase) * (0.55 if moving else 0.035)
			player_left_leg.rotation.x = stride
			player_right_leg.rotation.x = -stride
			if player_left_arm and player_right_arm:
				player_left_arm.rotation.x = -stride * 0.65
				player_right_arm.rotation.x = stride * 0.65
	if kick_anim_time > 0.0:
		kick_anim_time = maxf(0.0, kick_anim_time - delta)
		if kick_anim_leg:
			var progress := 1.0 - kick_anim_time / 0.34
			kick_anim_leg.rotation.x = -1.15 * sin(progress * PI) if progress < 1.0 else 0.0
		if player_visual:
			player_visual.rotation.z = sin((1.0 - kick_anim_time / 0.34) * PI) * -0.16
	if is_instance_valid(ball_visual) and is_instance_valid(ball):
		var speed_spin := ball.linear_velocity.length()
		ball_visual.rotate_x(delta * speed_spin * 0.65)
		ball_visual.rotate_z(delta * speed_spin * 0.45)
		var ground_dist := maxf(0.0, ball.global_position.y - BALL_RADIUS)
		ball_visual.position.y = 0.0
		ball_visual.scale = Vector3.ONE * (1.0 + minf(0.08, ground_dist * 0.06))
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
	if is_paused:
		return
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
		for tier in range(5):
			var seat_mat := _material([Color(0.045,0.075,0.13), Color(0.065,0.11,0.19), Color(0.09,0.15,0.25), Color(0.12,0.19,0.3), Color(0.15,0.23,0.35)][tier])
			_mesh_box(self, Vector3(FIELD_LENGTH + 10, 0.48, 1.25), Vector3(0, 0.25 + tier * 0.48, side * (FIELD_WIDTH / 2.0 + 1.8 + tier * 0.92)), seat_mat)
	# Proper penalty areas, six-yard boxes and penalty spots.
	for end in [-1.0, 1.0]:
		var box_x: float = float(end) * (FIELD_LENGTH / 2.0 - 4.0)
		_mesh_box(self, Vector3(0.07, 0.025, 15.0), Vector3(box_x, -0.018, 0), white)
		_mesh_box(self, Vector3(6.0, 0.025, 0.07), Vector3(end * (FIELD_LENGTH / 2.0 - 7.0), -0.018, -7.5), white)
		_mesh_box(self, Vector3(6.0, 0.025, 0.07), Vector3(end * (FIELD_LENGTH / 2.0 - 7.0), -0.018, 7.5), white)
		_mesh_box(self, Vector3(0.07, 0.025, 7.0), Vector3(end * (FIELD_LENGTH / 2.0 - 1.0), -0.018, 0), white)
		_mesh_box(self, Vector3(0.07, 0.025, 0.07), Vector3(end * (FIELD_LENGTH / 2.0 - 7.0), -0.005, 0), white)
	# Stadium fascia and subtle anime-arena cyan lighting.
	var fascia := _material(Color(0.025, 0.045, 0.085))
	_mesh_box(self, Vector3(FIELD_LENGTH + 14, 0.45, 0.7), Vector3(0, 2.65, -FIELD_WIDTH / 2.0 - 5.1), fascia)
	_mesh_box(self, Vector3(FIELD_LENGTH + 14, 0.45, 0.7), Vector3(0, 2.65, FIELD_WIDTH / 2.0 + 5.1), fascia)
	var glow := _material(Color(0.05, 0.55, 0.95))
	glow.emission_enabled = true
	glow.emission = Color(0.04, 0.38, 1.0)
	glow.emission_energy_multiplier = 1.3
	_mesh_box(self, Vector3(FIELD_LENGTH + 12, 0.07, 0.08), Vector3(0, 2.4, -FIELD_WIDTH / 2.0 - 5.0), glow)
	_mesh_box(self, Vector3(FIELD_LENGTH + 12, 0.07, 0.08), Vector3(0, 2.4, FIELD_WIDTH / 2.0 + 5.0), glow)
	# Floodlight towers around the pitch.
	for x in [-FIELD_LENGTH / 2.0 - 5.0, FIELD_LENGTH / 2.0 + 5.0]:
		for z in [-FIELD_WIDTH / 2.0 - 6.0, FIELD_WIDTH / 2.0 + 6.0]:
			_mesh_box(self, Vector3(0.22, 8.0, 0.22), Vector3(x, 4.0, z), _material(Color(0.12, 0.16, 0.23), 0.35))
			var lamp := _mesh_box(self, Vector3(1.6, 0.22, 0.65), Vector3(x, 8.0, z), glow)
			lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_goals() -> void:
	var goal_mat := _material(Color(0.93, 0.96, 1.0), 0.4)
	for x in [-FIELD_LENGTH / 2.0 - 0.65, FIELD_LENGTH / 2.0 + 0.65]:
		_mesh_box(self, Vector3(1.4, 0.15, 7.0), Vector3(x, 0.05, 0), _material(Color(0.1, 0.1, 0.12)))
		_mesh_box(self, Vector3(0.18, 2.3, 0.18), Vector3(x, 1.1, -3.1), goal_mat)
		_mesh_box(self, Vector3(0.18, 2.3, 0.18), Vector3(x, 1.1, 3.1), goal_mat)
		_mesh_box(self, Vector3(0.18, 0.18, 6.4), Vector3(x, 2.2, 0), goal_mat)
		var net_mat := _material(Color(0.55, 0.76, 0.9, 0.28), 0.95)
		# Fine net grid, rather than a solid translucent panel.
		for zline in range(13):
			_mesh_box(self, Vector3(1.55, 0.025, 0.025), Vector3(x + (0.78 if x < 0 else -0.78), 0.2 + zline * 0.16, -3.0 + zline * 0.5), net_mat)
		for hline in range(8):
			_mesh_box(self, Vector3(1.55, 0.025, 0.025), Vector3(x + (0.78 if x < 0 else -0.78), 0.18 + hline * 0.28, 0), net_mat)
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
	# Anime-inspired athletic silhouette: defined torso, hair silhouette and bright eye band.
	var trim_mat := _material(Color(0.12, 0.86, 1.0) if team_home else Color(1.0, 0.36, 0.18), 0.35)
	_mesh_box(body, Vector3(0.56, 0.09, 0.46), Vector3(0, 1.12, 0), trim_mat)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.27
	sphere.height = 0.54
	head.mesh = sphere
	head.position = Vector3(0, 1.9, 0)
	head.material_override = _material(Color(0.72, 0.48, 0.32))
	body.add_child(head)
	var hair := MeshInstance3D.new()
	var hair_mesh := SphereMesh.new()
	hair_mesh.radius = 0.29
	hair_mesh.height = 0.28
	hair.mesh = hair_mesh
	hair.position = Vector3(0, 2.13, -0.015)
	hair.material_override = _material(Color(0.035, 0.045, 0.075) if team_home else Color(0.16, 0.035, 0.045), 0.4)
	body.add_child(hair)
	var eye_band := _mesh_box(body, Vector3(0.29, 0.045, 0.035), Vector3(0, 1.96, 0.245), trim_mat)
	eye_band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var limb_mat := _material(Color(0.055, 0.075, 0.12) if team_home else Color(0.16, 0.035, 0.045), 0.55)
	var leg_nodes: Array[MeshInstance3D] = []
	for leg_name in ["LeftLeg", "RightLeg"]:
		var leg := MeshInstance3D.new()
		var leg_mesh := BoxMesh.new()
		leg_mesh.size = Vector3(0.19, 0.52, 0.22)
		leg.mesh = leg_mesh
		leg.name = leg_name
		leg.position = Vector3(-0.17 if leg_name == "LeftLeg" else 0.17, 0.48, 0.0)
		leg.material_override = limb_mat
		body.add_child(leg)
		leg_nodes.append(leg)
	var arm_nodes: Array[MeshInstance3D] = []
	for arm_name in ["LeftArm", "RightArm"]:
		var arm := MeshInstance3D.new()
		var arm_mesh := BoxMesh.new()
		arm_mesh.size = Vector3(0.16, 0.5, 0.18)
		arm.mesh = arm_mesh
		arm.name = arm_name
		arm.position = Vector3(-0.34 if arm_name == "LeftArm" else 0.34, 1.08, 0.0)
		arm.material_override = limb_mat
		body.add_child(arm)
		arm_nodes.append(arm)
	if is_user:
		player_left_leg = leg_nodes[0]
		player_right_leg = leg_nodes[1]
		kick_anim_leg = player_right_leg
		player_left_arm = arm_nodes[0]
		player_right_arm = arm_nodes[1]
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
	mesh.name = "AnimatedBallVisual"
	mesh.material_override = _material(Color(0.95, 0.95, 0.9), 0.3)
	ball.add_child(mesh)
	ball_visual = mesh
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
	ultimate_button = _make_button(layer, "ULTIMATE", Vector2(-238, -155), Color(0.06, 0.72, 0.92))
	ultimate_button.size = Vector2(112, 58)
	ultimate_button.pressed.connect(_use_ultimate)
	var restart := _make_button(layer, "RESTART", Vector2(18, -55), Color(0.08,0.45,0.24))
	restart.anchor_left = 0.5
	restart.anchor_right = 0.5
	restart.anchor_top = 0.15
	restart.anchor_bottom = 0.15
	restart.position = Vector2(-138, 0)
	restart.size = Vector2(130, 44)
	restart.pressed.connect(_restart)
	var lobby_button := _make_button(layer, "LOBBY", Vector2.ZERO, Color(0.22,0.25,0.34))
	lobby_button.anchor_left = 0.5
	lobby_button.anchor_right = 0.5
	lobby_button.anchor_top = 0.15
	lobby_button.anchor_bottom = 0.15
	lobby_button.position = Vector2(8, 0)
	lobby_button.size = Vector2(112, 44)
	lobby_button.pressed.connect(_return_to_lobby)
	goal_banner = Label.new()
	goal_banner.anchor_left = 0.15
	goal_banner.anchor_right = 0.85
	goal_banner.anchor_top = 0.31
	goal_banner.anchor_bottom = 0.49
	goal_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	goal_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	goal_banner.add_theme_font_size_override("font_size", 36)
	goal_banner.add_theme_color_override("font_color", Color(1.0, 0.88, 0.28))
	goal_banner.add_theme_color_override("font_shadow_color", Color(0.02, 0.04, 0.1, 1.0))
	goal_banner.add_theme_constant_override("shadow_offset_x", 3)
	goal_banner.add_theme_constant_override("shadow_offset_y", 4)
	goal_banner.text = ""
	goal_banner.modulate.a = 0.0
	goal_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(goal_banner)
	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "ProceduralSFX"
	sfx_player.volume_db = -7.0
	add_child(sfx_player)
	var aim_material := StandardMaterial3D.new()
	aim_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aim_material.albedo_color = Color(0.15, 0.95, 1.0, 0.9)
	aim_material.emission_enabled = true
	aim_material.emission = Color(0.05, 0.7, 1.0)
	aim_material.emission_energy_multiplier = 1.8
	var aim_mesh := ImmediateMesh.new()
	aim_line = MeshInstance3D.new()
	aim_line.name = "ShotTrajectoryGuide"
	aim_line.mesh = aim_mesh
	aim_line.material_override = aim_material
	add_child(aim_line)
	goal_flash = ColorRect.new()
	goal_flash.anchor_right = 1.0
	goal_flash.anchor_bottom = 1.0
	goal_flash.color = Color(0.1, 0.9, 1.0, 0.0)
	goal_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(goal_flash)
	# Compact top-corner controls keep pause and sound accessible on phones.
	pause_button = Button.new()
	pause_button.text = "PAUSE"
	pause_button.anchor_left = 1.0
	pause_button.anchor_right = 1.0
	pause_button.anchor_top = 0.025
	pause_button.anchor_bottom = 0.025
	pause_button.position = Vector2(-108, 0)
	pause_button.size = Vector2(92, 38)
	pause_button.add_theme_font_size_override("font_size", 14)
	pause_button.pressed.connect(_toggle_pause)
	layer.add_child(pause_button)
	sound_button = Button.new()
	sound_button.text = "SFX ON"
	sound_button.anchor_left = 1.0
	sound_button.anchor_right = 1.0
	sound_button.anchor_top = 0.025
	sound_button.anchor_bottom = 0.025
	sound_button.position = Vector2(-208, 0)
	sound_button.size = Vector2(88, 38)
	sound_button.add_theme_font_size_override("font_size", 14)
	sound_button.pressed.connect(_toggle_sound)
	layer.add_child(sound_button)
	goal_banner.move_to_front()

func _toggle_pause() -> void:
	if not match_active:
		ui_hint.text = "Start a match before pausing"
		return
	is_paused = not is_paused
	joystick_vector = Vector2.ZERO
	if pause_button:
		pause_button.text = "RESUME" if is_paused else "PAUSE"
	ui_hint.text = "MATCH PAUSED" if is_paused else "MATCH RESUMED"

func _toggle_sound() -> void:
	sound_enabled = not sound_enabled
	if sound_button:
		sound_button.text = "SFX ON" if sound_enabled else "SFX OFF"
	ui_hint.text = "Sound effects enabled" if sound_enabled else "Sound effects muted"

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
		# Small, damped rebound so the ball visibly bounces instead of sticking to the turf.
		if ball.linear_velocity.y < -0.9:
			ball.linear_velocity.y = -ball.linear_velocity.y * 0.38
			ball.linear_velocity.x *= 0.94
			ball.linear_velocity.z *= 0.94
		else:
			ball.linear_velocity.y = 0.0
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
	var goal_target := Vector3(FIELD_LENGTH / 2.0 + 2.0, 1.0, clampf(-player.global_position.z * 0.45, -2.35, 2.35))
	var dir := (goal_target - ball.global_position).normalized()
	var shot_power := 13.0
	if selected_ability == "Power Shot":
		shot_power = 18.0
	ball.apply_central_impulse(dir * shot_power)
	kick_anim_time = 0.34
	_play_sfx("kick")
	_spawn_skill_burst(ball.global_position, Color(1.0, 0.25, 0.12))
	ui_hint.text = "⚡ DIRECT SHOT! ⚡"

func _pass_ball() -> void:
	if not match_active or not _near_ball():
		ui_hint.text = "Get closer to the ball to pass"
		return
	var target := teammates[0].global_position if not teammates.is_empty() else player.global_position + Vector3(5,0,0)
	var dir := (target - ball.global_position).normalized()
	dir.y = 0.05
	var pass_power := 7.5
	if selected_ability == "Precision Pass":
		pass_power = 11.0
	ball.apply_central_impulse(dir.normalized() * pass_power)
	kick_anim_time = 0.28
	_play_sfx("pass")
	_spawn_skill_burst(ball.global_position, Color(0.15, 0.65, 1.0))
	ui_hint.text = "◆ PERFECT PASS ◆"


func _use_ultimate() -> void:
	if not match_active:
		ui_hint.text = "Start a match before using your ultimate"
		return
	if selected_character != "Eclipse Ace":
		ui_hint.text = "Select ECLIPSE ACE in the lobby to unlock the ultimate"
		return
	if ultimate_cooldown > 0.0:
		ui_hint.text = "ECLIPSE BREAKER recharging..."
		return
	if not _near_ball():
		ui_hint.text = "Get close to the ball to unleash ECLIPSE BREAKER"
		return
	ultimate_cooldown = 32.0
	kick_anim_time = 0.46
	_play_sfx("ultimate")
	_spawn_skill_burst(player.global_position + Vector3(0, 0.5, 0), Color(0.25, 0.05, 0.95))
	_spawn_skill_burst(ball.global_position, Color(0.05, 0.9, 1.0))
	# Original anime-style finisher: high precision toward the goal with a small
	# controlled miss chance so the move is powerful but not an automatic score.
	var goal_x := FIELD_LENGTH / 2.0 + 2.0
	var in_range := player.global_position.x > 2.0
	var target_z := clampf(-player.global_position.z * 0.32, -2.15, 2.15)
	if in_range and rng.randf() > 0.80:
		target_z = 3.5 if rng.randf() > 0.5 else -3.5
	var target := Vector3(goal_x, 0.7, target_z)
	var dir := (target - ball.global_position).normalized()
	dir.y = 0.035
	ball.linear_velocity = Vector3.ZERO
	ball.apply_central_impulse(dir.normalized() * 22.0)
	ui_hint.text = "ECLIPSE BREAKER!! • 80% TARGET ACCURACY IN RANGE"
	if goal_banner:
		if goal_banner_tween and goal_banner_tween.is_running():
			goal_banner_tween.kill()
		goal_banner.text = "ECLIPSE BREAKER"
		goal_banner.scale = Vector2(0.45, 0.45)
		goal_banner.modulate.a = 1.0
		goal_banner.add_theme_color_override("font_color", Color(0.25, 0.9, 1.0))
		goal_banner_tween = create_tween()
		goal_banner_tween.set_parallel(true)
		goal_banner_tween.tween_property(goal_banner, "scale", Vector2(1.15, 1.15), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		goal_banner_tween.tween_property(goal_banner, "modulate:a", 0.0, 1.25).set_delay(0.65)

func _burst() -> void:
	if selected_ability != "Speed Burst":
		ui_hint.text = "POWER SHOT selected — use SHOOT" if selected_ability == "Power Shot" else "PRECISION PASS selected — use PASS"
		return
	if burst_cooldown > 0.0:
		ui_hint.text = "BURST recharging..."
		return
	burst_time = 1.6
	burst_cooldown = 5.0
	_play_sfx("burst")
	burst_fx_timer = 0.0
	_spawn_skill_burst(player.global_position, Color(0.15, 0.75, 1.0))
	ui_hint.text = "⚡ ANIME BURST! ⚡"

func _check_goals() -> void:
	if ball.global_position.x > FIELD_LENGTH / 2.0 + 0.5 and absf(ball.global_position.z) < 3.1:
		score_home += 1
		goals_total += 1
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
	if message.contains("SCORES") or message.contains("GOAL"):
		_show_goal_celebration(message)
		_play_sfx("goal")
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
	is_paused = false
	if pause_button:
		pause_button.text = "PAUSE"
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
		if selected_ability == "Speed Burst":
			burst_button.text = "BURST" if burst_cooldown <= 0.0 else str(int(ceil(burst_cooldown))) + "s"
		else:
			burst_button.text = "SKILL"


func _build_lobby() -> void:
	lobby_layer = CanvasLayer.new()
	lobby_layer.layer = 10
	add_child(lobby_layer)
	var backdrop := ColorRect.new()
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	backdrop.color = Color(0.015, 0.025, 0.065, 0.96)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	lobby_layer.add_child(backdrop)
	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.offset_left = 18
	center.offset_right = -18
	center.offset_top = 10
	center.offset_bottom = -10
	lobby_layer.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 500)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.07, 0.14, 0.98)
	panel_style.border_color = Color(0.1, 0.75, 1.0, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(22)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	margin.add_child(stack)
	var title := Label.new()
	title.text = "ECLIPSE STRIKERS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", Color(0.25, 0.82, 1.0))
	var title_tween := create_tween().set_loops()
	title_tween.tween_property(title, "scale", Vector2(1.035, 1.035), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	title_tween.tween_property(title, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	stack.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "FOUNDER’S ARENA  •  4v4 ANIME FOOTBALL"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.88, 1.0))
	stack.add_child(subtitle)
	stack.add_child(_lobby_label("CHARACTER"))
	character_picker = OptionButton.new()
	for item in ["Striker", "Playmaker", "Defender", "Eclipse Ace"]:
		character_picker.add_item(item)
	stack.add_child(character_picker)
	stack.add_child(_lobby_label("SPECIAL ABILITY"))
	ability_picker = OptionButton.new()
	for item in ["Speed Burst", "Power Shot", "Precision Pass"]:
		ability_picker.add_item(item)
	stack.add_child(ability_picker)
	stack.add_child(_lobby_label("TEAM KIT"))
	color_picker = OptionButton.new()
	for item in ["Electric Blue", "Neon Green", "Royal Purple", "Crimson Red"]:
		color_picker.add_item(item)
	stack.add_child(color_picker)
	var stats := Label.new()
	stats.name = "ProgressStats"
	stats.text = "LEVEL %d   •   WINS %d   •   GOALS %d" % [player_level, wins_total, goals_total]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3))
	stats.add_theme_font_size_override("font_size", 14)
	stack.add_child(stats)
	var play := Button.new()
	play.text = "▶  PLAY MATCH"
	play.custom_minimum_size.y = 46
	play.add_theme_font_size_override("font_size", 18)
	play.add_theme_color_override("font_color", Color.WHITE)
	play.add_theme_stylebox_override("normal", _panel_style(Color(0.03, 0.42, 0.78), Color(0.25, 0.82, 1.0)))
	play.pressed.connect(_start_match)
	stack.add_child(play)
	var room := Button.new()
	room.text = "FRIENDS ROOM / ONLINE"
	room.custom_minimum_size.y = 38
	room.pressed.connect(_show_online_room_status)
	stack.add_child(room)
	lobby_status = Label.new()
	lobby_status.text = "Choose your loadout and kick off."
	lobby_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lobby_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_status.add_theme_font_size_override("font_size", 12)
	lobby_status.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	stack.add_child(lobby_status)


func _lobby_label(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.45, 0.75, 0.95))
	return label


func _start_match() -> void:
	is_paused = false
	if pause_button:
		pause_button.text = "PAUSE"
	selected_character = character_picker.get_item_text(character_picker.selected)
	selected_ability = ability_picker.get_item_text(ability_picker.selected)
	selected_team_color = color_picker.get_item_text(color_picker.selected)
	var tint := Color(0.08, 0.36, 0.95)
	match selected_team_color:
		"Neon Green": tint = Color(0.12, 0.92, 0.42)
		"Royal Purple": tint = Color(0.52, 0.2, 0.92)
		"Crimson Red": tint = Color(0.92, 0.08, 0.2)
		_: tint = Color(0.08, 0.36, 0.95)
	if player_visual:
		player_visual.material_override = _material(tint, 0.45)
		player_visual.scale = Vector3(1.0, 1.0, 1.0)
		if selected_character == "Playmaker":
			player_visual.scale = Vector3(0.92, 1.06, 0.92)
		elif selected_character == "Defender":
			player_visual.scale = Vector3(1.10, 1.0, 1.10)
	match selected_character:
		"Playmaker": ui_hint.text = "PLAYMAKER • PRECISION AND TEAMWORK"
		"Defender": ui_hint.text = "DEFENDER • HOLD YOUR LINE"
		"Eclipse Ace": ui_hint.text = "ECLIPSE ACE • ULTIMATE: ECLIPSE BREAKER"
		_: ui_hint.text = "STRIKER • GO FOR GOALS"
	match_active = true
	time_left = MATCH_SECONDS
	score_home = 0
	score_away = 0
	burst_time = 0.0
	burst_cooldown = 0.0
	ultimate_cooldown = 0.0
	_reset_kickoff("KICK OFF! • " + selected_ability.to_upper())
	lobby_layer.visible = false
	_update_hud()


func _return_to_lobby() -> void:
	is_paused = false
	match_active = false
	joystick_vector = Vector2.ZERO
	lobby_layer.visible = true
	lobby_status.text = "Choose your loadout and kick off."
	var stats := lobby_layer.find_child("ProgressStats", true, false) as Label
	if stats:
		stats.text = "LEVEL %d   •   WINS %d   •   GOALS %d" % [player_level, wins_total, goals_total]


func _show_online_room_status() -> void:
	lobby_status.text = "Online friend rooms are not connected yet. This build currently supports offline 4v4 vs AI; online play needs a multiplayer server."


func _save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("career", "wins", wins_total)
	cfg.set_value("career", "goals", goals_total)
	cfg.set_value("career", "level", player_level)
	cfg.save("user://football_progress.cfg")


func _load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://football_progress.cfg") == OK:
		wins_total = int(cfg.get_value("career", "wins", 0))
		goals_total = int(cfg.get_value("career", "goals", 0))
		player_level = int(cfg.get_value("career", "level", 1))


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


func _update_aim_guide() -> void:
	if not is_instance_valid(aim_line) or not is_instance_valid(ball) or not is_instance_valid(player):
		return
	var show_guide := match_active and _near_ball()
	aim_line.visible = show_guide
	if not show_guide:
		return
	var mesh := aim_line.mesh as ImmediateMesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var origin := ball.global_position + Vector3(0, 0.12, 0)
	var target_z := clampf(-player.global_position.z * 0.45, -2.35, 2.35)
	var target := Vector3(FIELD_LENGTH / 2.0 + 2.0, 1.0, target_z)
	var dir := (target - origin).normalized()
	var power := 13.0 if selected_ability != "Power Shot" else 18.0
	var velocity := dir * power * 0.72
	var point := origin
	mesh.surface_add_vertex(to_local(point))
	for i in range(1, 22):
		var t := float(i) * 0.11
		point = origin + velocity * t + Vector3(0, -4.9 * t * t, 0)
		mesh.surface_add_vertex(to_local(point))
	mesh.surface_end()

func _show_goal_celebration(message: String) -> void:
	if not is_instance_valid(goal_banner):
		return
	if goal_banner_tween and goal_banner_tween.is_running():
		goal_banner_tween.kill()
	var home_goal := message.contains("BLUE")
	goal_banner.text = "GOAL!!" if home_goal else "THEY SCORED!"
	if home_goal:
		goal_banner.text += "\nTHAT'S THE STRIKER'S INSTINCT!"
	else:
		goal_banner.text += "\nRESET. WE'RE NOT DONE YET."
	goal_banner.scale = Vector2(0.55, 0.55)
	goal_banner.modulate.a = 1.0
	goal_animation_busy = true
	goal_banner_tween = create_tween()
	goal_banner_tween.set_parallel(true)
	goal_banner_tween.tween_property(goal_banner, "scale", Vector2(1.0, 1.0), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	goal_banner_tween.tween_property(goal_banner, "modulate:a", 0.0, 2.4).set_delay(1.5)
	goal_banner_tween.chain().tween_callback(func(): goal_animation_busy = false)

func _play_sfx(kind: String) -> void:
	if not sound_enabled or not is_instance_valid(sfx_player):
		return
	var rate := 22050
	var duration := 0.24
	var base_freq := 180.0
	match kind:
		"goal":
			duration = 0.9
			base_freq = 440.0
		"kick":
			duration = 0.13
			base_freq = 115.0
		"pass":
			duration = 0.16
			base_freq = 260.0
		"burst":
			duration = 0.28
			base_freq = 620.0
		"ultimate":
			duration = 1.05
			base_freq = 330.0
	var count := int(rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in range(count):
		var t := float(i) / rate
		var envelope := 1.0 - float(i) / count
		var freq := base_freq
		if kind == "goal" or kind == "ultimate":
			freq = base_freq * (1.0 + 0.35 * sin(t * 9.0))
		elif kind == "kick":
			freq = base_freq * (1.0 - 0.55 * t / duration)
		elif kind == "burst":
			freq = base_freq * (0.7 + 1.1 * t / duration)
		elif kind == "ultimate":
			freq = base_freq * (0.8 + 1.4 * t / duration)
		var wave := sin(TAU * freq * t) * envelope
		if kind == "kick":
			wave = (wave * 0.65 + sin(TAU * 55.0 * t) * envelope * 0.35)
		elif kind == "goal" or kind == "ultimate":
			wave = (wave * 0.7 + sin(TAU * base_freq * 1.5 * t) * envelope * 0.3)
		var sample := int(clampf(wave * 12500.0, -32767.0, 32767.0))
		bytes.encode_s16(i * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	sfx_player.stream = stream
	sfx_player.play()
