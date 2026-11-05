extends CharacterBody3D
class_name CxPlayer
## The surveyor. Camera-relative movement, sprint, commit-dodge, field-cutter swing.

const SPEED := 7.2
const SPRINT := 12.4
const ACCEL := 16.0
const FRICTION := 18.0
const GRAVITY := 26.0
const DODGE_SPEED := 17.5
const DODGE_TIME := 0.42
const ATTACK_TIME := 0.36
const ATTACK_CD := 0.46
const SPRINT_DRAIN := 22.0
const DODGE_COST := 24.0
const STAM_REGEN := 20.0

var game
var hud

var max_health := 100.0
var health := 100.0
var stamina := 100.0
var max_stamina := 100.0
var potions := 1
var herbs := 0
var active := false

var model: Node3D
var tilt: Node3D
var arm: Node3D
var cutter_mat: StandardMaterial3D
var lantern: OmniLight3D
var cam_yaw: Node3D
var spring: SpringArm3D
var cam: Camera3D
var dust: CPUParticles3D

var face_yaw := 0.0
var dodge_t := 0.0
var dodge_dir := Vector3.FORWARD
var attack_t := 0.0
var attack_cd := 0.0
var hit_applied := false
var invuln := 2.5
var regen_delay := 0.0
var cam_manual := 0.0
var step_t := 0.0
var shake := 0.0
var knock := Vector3.ZERO
var flash := 0.0
var body_mats: Array[StandardMaterial3D] = []
var base_cols: Array[Color] = []


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.42
	cap.height = 1.9
	shape.shape = cap
	shape.position = Vector3(0, 0.95, 0)
	add_child(shape)
	_build_model()
	_build_camera()


func _build_model() -> void:
	model = Node3D.new()
	add_child(model)
	tilt = Node3D.new()
	model.add_child(tilt)

	var coat := CxUtil.mat(Color(0.86, 0.58, 0.26), 0.82)
	var dark := CxUtil.mat(Color(0.25, 0.19, 0.15), 0.9)
	var canvas := CxUtil.tex_mat("res://assets/tex/canvas.png", Color(0.95, 0.88, 0.74), 0.95)
	var teal := CxUtil.glow_mat(Color(0.25, 0.92, 0.82), 2.6)
	var skin := CxUtil.mat(Color(0.74, 0.55, 0.40), 0.75)
	body_mats = [coat, dark, canvas]
	base_cols = [coat.albedo_color, dark.albedo_color, canvas.albedo_color]

	tilt.add_child(CxUtil.mi(CxUtil.cyl(0.13, 0.15, 0.85), dark, Vector3(-0.17, 0.42, 0)))
	tilt.add_child(CxUtil.mi(CxUtil.cyl(0.13, 0.15, 0.85), dark, Vector3(0.17, 0.42, 0)))
	var skirt := CxUtil.mi(CxUtil.cyl(0.30, 0.46, 0.60), coat, Vector3(0, 1.0, 0))
	tilt.add_child(skirt)
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.27
	torso_mesh.height = 0.95
	tilt.add_child(CxUtil.mi(torso_mesh, coat, Vector3(0, 1.45, 0)))
	tilt.add_child(CxUtil.mi(CxUtil.box(0.50, 0.52, 0.30), canvas, Vector3(0, 1.52, 0.30)))
	tilt.add_child(CxUtil.mi(CxUtil.box(0.56, 0.10, 0.10), dark, Vector3(0, 1.45, 0.05)))
	tilt.add_child(CxUtil.mi(CxUtil.sph(0.20), skin, Vector3(0, 1.98, 0)))
	tilt.add_child(CxUtil.mi(CxUtil.box(0.32, 0.09, 0.06), teal, Vector3(0, 2.00, -0.18)))
	tilt.add_child(CxUtil.mi(CxUtil.cyl(0.38, 0.40, 0.05), dark, Vector3(0, 2.10, 0)))
	tilt.add_child(CxUtil.mi(CxUtil.cyl(0.18, 0.21, 0.20), dark, Vector3(0, 2.20, 0)))

	# lantern on the left hip
	var lamp := CxUtil.mi(CxUtil.sph(0.11), teal, Vector3(-0.38, 1.18, 0.12))
	tilt.add_child(lamp)
	lantern = OmniLight3D.new()
	lantern.position = Vector3(-0.38, 1.25, 0.12)
	lantern.light_color = Color(0.35, 0.95, 0.88)
	lantern.light_energy = 1.1
	lantern.omni_range = 7.5
	lantern.shadow_enabled = false
	tilt.add_child(lantern)

	# right arm + field cutter
	arm = Node3D.new()
	arm.position = Vector3(0.34, 1.62, 0)
	tilt.add_child(arm)
	arm.add_child(CxUtil.mi(CxUtil.cyl(0.09, 0.10, 0.62), coat, Vector3(0, -0.28, 0)))
	var grip := CxUtil.mi(CxUtil.box(0.09, 0.09, 0.30), dark, Vector3(0, -0.56, -0.08))
	arm.add_child(grip)
	cutter_mat = CxUtil.glow_mat(Color(0.30, 0.95, 0.86), 1.6)
	cutter_mat.albedo_color = Color(0.70, 0.90, 0.88)
	var blade := CxUtil.mi(CxUtil.box(0.07, 0.17, 1.15), cutter_mat, Vector3(0, -0.56, -0.74))
	arm.add_child(blade)

	dust = CPUParticles3D.new()
	dust.emitting = false
	dust.amount = 18
	dust.lifetime = 0.7
	dust.direction = Vector3(0, 1, 0)
	dust.spread = 35.0
	dust.initial_velocity_min = 0.6
	dust.initial_velocity_max = 1.6
	dust.gravity = Vector3(0, -1.2, 0)
	dust.scale_amount_min = 0.08
	dust.scale_amount_max = 0.22
	dust.color = Color(0.86, 0.72, 0.48, 0.65)
	dust.mesh = CxUtil.sph(0.5)
	add_child(dust)


func _build_camera() -> void:
	cam_yaw = Node3D.new()
	cam_yaw.position = Vector3(0, 1.5, 0)
	add_child(cam_yaw)
	spring = SpringArm3D.new()
	spring.spring_length = 8.6
	spring.margin = 0.5
	spring.collision_mask = 1 | 4
	spring.rotation.x = -0.33
	cam_yaw.add_child(spring)
	cam = Camera3D.new()
	cam.fov = 68.0
	cam.current = true
	cam.far = 400.0
	spring.add_child(cam)


func set_active(v: bool) -> void:
	active = v


func reset_run() -> void:
	health = max_health
	stamina = max_stamina
	potions = 1
	herbs = 0
	invuln = 2.5


# ---------------------------------------------------------------- input / move
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	if not active:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	attack_cd = maxf(0.0, attack_cd - delta)
	invuln = maxf(0.0, invuln - delta)
	flash = maxf(0.0, flash - delta)
	cam_manual = maxf(0.0, cam_manual - delta)
	regen_delay = maxf(0.0, regen_delay - delta)
	shake = maxf(0.0, shake - delta * 2.4)

	var wish := _wish_dir()
	var sprinting := false
	if dodge_t > 0.0:
		dodge_t -= delta
		velocity.x = dodge_dir.x * DODGE_SPEED
		velocity.z = dodge_dir.z * DODGE_SPEED
		tilt.rotation.x = -TAU * clampf(1.0 - dodge_t / DODGE_TIME, 0.0, 1.0)
		if dodge_t <= 0.0:
			tilt.rotation.x = 0.0
	else:
		tilt.rotation.x = lerp_angle(tilt.rotation.x, 0.0, delta * 12.0)
		var want_sprint := Input.is_action_pressed("cx_sprint")
		if hud != null and hud.sprint_held:
			want_sprint = true
		sprinting = want_sprint and stamina > 1.0 and wish.length() > 0.2 and attack_t <= 0.0
		var spd := SPRINT if sprinting else SPEED
		if attack_t > 0.0:
			spd *= 0.32
		var target := wish * spd
		var rate := ACCEL if wish.length() > 0.1 else FRICTION
		velocity.x = move_toward(velocity.x, target.x, rate * delta)
		velocity.z = move_toward(velocity.z, target.z, rate * delta)

	velocity += knock
	knock = knock.lerp(Vector3.ZERO, clampf(delta * 8.0, 0.0, 1.0))

	if sprinting:
		stamina = maxf(0.0, stamina - SPRINT_DRAIN * delta)
		regen_delay = 0.5
	elif regen_delay <= 0.0:
		stamina = minf(max_stamina, stamina + STAM_REGEN * delta)

	move_and_slide()
	_clamp_to_basin()
	_update_actions(delta)
	_update_visuals(delta, wish, sprinting)


func _wish_dir() -> Vector3:
	var ix := Input.get_axis("cx_left", "cx_right")
	var iz := Input.get_axis("cx_up", "cx_down")
	var v := Vector2(ix, iz)
	if v.length() < 0.15 and hud != null:
		v = hud.move_vec()
	if v.length() > 1.0:
		v = v.normalized()
	if v.length() < 0.12:
		return Vector3.ZERO
	var yaw := cam_yaw.global_rotation.y
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	return (right * v.x - fwd * v.y).normalized() * minf(v.length(), 1.0)


func _update_actions(delta: float) -> void:
	var want_attack := Input.is_action_just_pressed("cx_attack")
	var want_dodge := Input.is_action_just_pressed("cx_dodge")
	var want_potion := Input.is_action_just_pressed("cx_potion")
	if hud != null:
		if hud.consume_attack():
			want_attack = true
		if hud.consume_dodge():
			want_dodge = true
		if hud.consume_potion():
			want_potion = true

	if want_dodge and dodge_t <= 0.0 and stamina >= DODGE_COST:
		var d := _wish_dir()
		if d.length() < 0.2:
			d = Vector3(-sin(face_yaw), 0, -cos(face_yaw))
		dodge_dir = d.normalized()
		dodge_t = DODGE_TIME
		stamina -= DODGE_COST
		regen_delay = 0.7
		invuln = maxf(invuln, DODGE_TIME + 0.08)
		attack_t = 0.0
		face_yaw = CxUtil.yaw_to(dodge_dir)
		dust.restart()
		dust.emitting = true
		if game != null:
			game.sfx_step()
			game.puff(global_position + Vector3(0, 0.2, 0), Color(0.88, 0.76, 0.52), 14)

	if want_attack and attack_cd <= 0.0 and dodge_t <= 0.0:
		attack_t = ATTACK_TIME
		attack_cd = ATTACK_CD
		hit_applied = false
		if game != null:
			var cr = game.creature
			if is_instance_valid(cr):
				var to_c := CxUtil.flat(cr.global_position - global_position)
				if to_c.length() < 6.0:
					face_yaw = CxUtil.yaw_to(to_c.normalized())

	if attack_t > 0.0:
		attack_t -= delta
		var p := 1.0 - attack_t / ATTACK_TIME
		arm.rotation.x = lerp(0.3, -1.9, sin(clampf(p, 0.0, 1.0) * PI))
		arm.rotation.y = lerp(0.0, -0.7, sin(clampf(p, 0.0, 1.0) * PI))
		if not hit_applied and p > 0.34:
			hit_applied = true
			if game != null:
				game.player_swing(global_position, Vector3(-sin(face_yaw), 0, -cos(face_yaw)))
	else:
		arm.rotation.x = lerp_angle(arm.rotation.x, 0.25, delta * 10.0)
		arm.rotation.y = lerp_angle(arm.rotation.y, 0.0, delta * 10.0)

	if want_potion:
		use_potion()


func use_potion() -> void:
	if potions <= 0:
		if game != null:
			game.toast("No salt tonic left — gather herbs")
		return
	if health >= max_health - 0.5:
		if game != null:
			game.toast("Already at full strength")
		return
	potions -= 1
	health = minf(max_health, health + 38.0)
	if game != null:
		game.sfx_pickup()
		game.puff(global_position + Vector3(0, 1.1, 0), Color(0.45, 0.95, 0.70), 20)
		game.float_text(global_position + Vector3(0, 2.2, 0), "+38", Color(0.45, 0.95, 0.70))
		game.toast("Salt tonic consumed")


func _update_visuals(delta: float, wish: Vector3, sprinting: bool) -> void:
	var hv := Vector2(velocity.x, velocity.z)
	if wish.length() > 0.2 and dodge_t <= 0.0 and attack_t <= 0.0:
		face_yaw = CxUtil.yaw_to(wish.normalized())
	model.rotation.y = lerp_angle(model.rotation.y, face_yaw, clampf(delta * 13.0, 0.0, 1.0))

	# bob
	var moving := hv.length() > 1.5
	if moving:
		step_t -= delta * (1.6 if sprinting else 1.0)
		model.position.y = abs(sin(Time.get_ticks_msec() * 0.011)) * 0.07
		if step_t <= 0.0:
			step_t = 0.40 if sprinting else 0.52
			if game != null:
				game.sfx_step()
			dust.restart()
			dust.emitting = true
	else:
		model.position.y = lerp(model.position.y, 0.0, delta * 8.0)

	lantern.light_energy = 1.05 + sin(Time.get_ticks_msec() * 0.004) * 0.2
	cutter_mat.emission_energy_multiplier = 1.4 + (2.6 if attack_t > 0.0 else 0.0)

	if flash > 0.0:
		var f := flash / 0.25
		for i in range(body_mats.size()):
			body_mats[i].albedo_color = base_cols[i].lerp(Color(1, 0.35, 0.25), f * 0.8)
	else:
		for i in range(body_mats.size()):
			body_mats[i].albedo_color = base_cols[i]

	# camera
	if cam_manual <= 0.0 and hv.length() > 2.5:
		var want := atan2(-velocity.x, -velocity.z)
		cam_yaw.rotation.y = lerp_angle(cam_yaw.rotation.y, want, clampf(delta * 1.1, 0.0, 1.0))
	if shake > 0.0:
		cam.h_offset = randf_range(-shake, shake) * 0.25
		cam.v_offset = randf_range(-shake, shake) * 0.25
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0


func _clamp_to_basin() -> void:
	var r := Vector2(global_position.x, global_position.z)
	if r.length() > 76.0:
		r = r.normalized() * 76.0
		global_position.x = r.x
		global_position.z = r.y


func orbit(dx: float, dy: float) -> void:
	cam_yaw.rotation.y -= dx * 0.0052
	spring.rotation.x = clampf(spring.rotation.x - dy * 0.004, -1.05, -0.04)
	cam_manual = 2.6


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if (mm.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0 or (mm.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0:
			orbit(mm.relative.x, mm.relative.y)


func take_damage(amount: float, from: Vector3) -> void:
	if invuln > 0.0 or health <= 0.0:
		return
	health = maxf(0.0, health - amount)
	invuln = 1.1
	flash = 0.25
	shake = 1.0
	var dir := CxUtil.flat(global_position - from)
	if dir.length() > 0.01:
		knock = dir.normalized() * 9.0
	if game != null:
		game.on_player_hurt(amount)


func add_shake(v: float) -> void:
	shake = maxf(shake, v)
