extends CharacterBody3D
class_name CxCreature
## The Cinderhorn: armored six-legged basin beast.
## Telegraphs a charge lane, rushes, and if it misses it crashes and staggers
## open — the only window where the field cutter bites deep.

enum S {ROAM, STALK, TELEGRAPH, CHARGE, RECOVER, STAGGER, RETREAT, SUBDUED}

const CHARGE_SPEED := 23.0
const STAGGER_TIME := 3.1

var game
var player

var state := S.ROAM
var t := 0.0
var max_hp := 240.0
var hp := 240.0
var walk_speed := 5.0
var charge_dir := Vector3.FORWARD
var hit_player := false
var roam_target := Vector3.ZERO
var walk_phase := 0.0
var flash := 0.0
var shed_at := [160.0, 80.0, 0.0]
var shed_idx := 0
var enraged := false
var combo := 0

var body_root: Node3D
var lane: MeshInstance3D
var lane_mat: StandardMaterial3D
var seam_mat: StandardMaterial3D
var eye_mat: StandardMaterial3D
var plate_mat: StandardMaterial3D
var legs: Array[Node3D] = []
var glow: OmniLight3D
var crash_dust: CPUParticles3D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 1.5
	cap.height = 3.0
	shape.shape = cap
	shape.position = Vector3(0, 1.5, 0)
	add_child(shape)
	_build()
	roam_target = _random_point()


func _build() -> void:
	body_root = Node3D.new()
	add_child(body_root)

	plate_mat = CxUtil.tex_mat("res://assets/tex/carapace.png", Color(0.62, 0.56, 0.52), 0.62)
	var dark := CxUtil.mat(Color(0.17, 0.14, 0.13), 0.78)
	seam_mat = CxUtil.glow_mat(Color(1.0, 0.42, 0.10), 2.6)
	eye_mat = CxUtil.glow_mat(Color(1.0, 0.82, 0.30), 4.0)

	var body := CxUtil.mi(CxUtil.sph(1.0), plate_mat, Vector3(0, 1.55, 0))
	body.scale = Vector3(1.7, 1.15, 2.5)
	body_root.add_child(body)

	# dorsal plates
	for i in range(4):
		var p := PrismMesh.new()
		p.size = Vector3(2.0 - float(i) * 0.18, 0.9 - float(i) * 0.1, 1.0)
		var inst := CxUtil.mi(p, plate_mat, Vector3(0, 2.15 - float(i) * 0.06, -1.5 + float(i) * 1.05))
		inst.rotation.x = -0.12
		body_root.add_child(inst)
		var seam := CxUtil.mi(CxUtil.box(1.7 - float(i) * 0.15, 0.07, 0.14), seam_mat, Vector3(0, 1.9 - float(i) * 0.05, -1.0 + float(i) * 1.05))
		body_root.add_child(seam)

	# flank seams
	for sx in [-1.0, 1.0]:
		var fs := CxUtil.mi(CxUtil.box(0.10, 0.16, 3.0), seam_mat, Vector3(sx * 1.52, 1.35, 0.0))
		body_root.add_child(fs)

	# head
	var head := Node3D.new()
	head.position = Vector3(0, 1.4, -2.45)
	body_root.add_child(head)
	head.add_child(CxUtil.mi(CxUtil.box(1.5, 1.0, 1.3), plate_mat, Vector3.ZERO))
	head.add_child(CxUtil.mi(CxUtil.box(1.0, 0.35, 0.5), dark, Vector3(0, -0.42, -0.5)))
	head.add_child(CxUtil.mi(CxUtil.box(0.9, 0.12, 0.3), seam_mat, Vector3(0, -0.30, -0.62)))
	head.add_child(CxUtil.mi(CxUtil.sph(0.13), eye_mat, Vector3(-0.45, 0.22, -0.66)))
	head.add_child(CxUtil.mi(CxUtil.sph(0.13), eye_mat, Vector3(0.45, 0.22, -0.66)))
	for sx2 in [-1.0, 1.0]:
		var horn := CxUtil.mi(CxUtil.cyl(0.03, 0.20, 1.5, 8), plate_mat, Vector3(sx2 * 0.52, 0.55, -0.85))
		horn.rotation = Vector3(-1.15, 0.0, sx2 * 0.22)
		head.add_child(horn)
		var tip := CxUtil.mi(CxUtil.sph(0.09), seam_mat, Vector3(sx2 * 0.62, 1.02, -1.52))
		head.add_child(tip)

	# tail
	var tail := CxUtil.mi(CxUtil.cyl(0.08, 0.6, 2.0, 8), plate_mat, Vector3(0, 1.5, 2.1))
	tail.rotation.x = 1.25
	body_root.add_child(tail)

	# six legs
	for i in range(6):
		var sx3 := -1.0 if i < 3 else 1.0
		var zi := -1.25 + float(i % 3) * 1.3
		var leg := Node3D.new()
		leg.position = Vector3(sx3 * 1.3, 1.45, zi)
		body_root.add_child(leg)
		var upper := CxUtil.mi(CxUtil.cyl(0.14, 0.22, 1.0, 8), dark, Vector3(sx3 * 0.35, -0.25, 0))
		upper.rotation.z = sx3 * 0.85
		leg.add_child(upper)
		var lower := CxUtil.mi(CxUtil.cyl(0.08, 0.14, 1.25, 8), plate_mat, Vector3(sx3 * 0.72, -1.02, 0))
		lower.rotation.z = sx3 * 0.12
		leg.add_child(lower)
		var foot := CxUtil.mi(CxUtil.box(0.34, 0.16, 0.5), dark, Vector3(sx3 * 0.78, -1.62, 0))
		leg.add_child(foot)
		legs.append(leg)

	glow = OmniLight3D.new()
	glow.position = Vector3(0, 1.6, 0)
	glow.light_color = Color(1.0, 0.45, 0.14)
	glow.light_energy = 2.0
	glow.omni_range = 14.0
	glow.shadow_enabled = false
	body_root.add_child(glow)

	# charge lane decal
	var plane := PlaneMesh.new()
	plane.size = Vector2(4.2, 26.0)
	lane_mat = CxUtil.mat(Color(1.0, 0.45, 0.12, 0.5), 1.0)
	lane_mat.emission_enabled = true
	lane_mat.emission = Color(1.0, 0.45, 0.12)
	lane_mat.emission_energy_multiplier = 2.2
	lane_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lane_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	lane_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lane = CxUtil.mi(plane, lane_mat, Vector3(0, 0.07, -13.5))
	lane.visible = false
	body_root.add_child(lane)

	crash_dust = CPUParticles3D.new()
	crash_dust.emitting = false
	crash_dust.one_shot = true
	crash_dust.amount = 36
	crash_dust.lifetime = 1.1
	crash_dust.explosiveness = 0.9
	crash_dust.direction = Vector3(0, 1, 0)
	crash_dust.spread = 60.0
	crash_dust.initial_velocity_min = 2.0
	crash_dust.initial_velocity_max = 6.0
	crash_dust.gravity = Vector3(0, -3.0, 0)
	crash_dust.scale_amount_min = 0.2
	crash_dust.scale_amount_max = 0.6
	crash_dust.color = Color(0.86, 0.72, 0.48, 0.8)
	crash_dust.mesh = CxUtil.sph(0.5)
	crash_dust.position = Vector3(0, 0.4, -2.0)
	body_root.add_child(crash_dust)


func _random_point() -> Vector3:
	var a := randf() * TAU
	var r := randf_range(15.0, 64.0)
	return Vector3(cos(a) * r, 0, sin(a) * r)


func set_phase(p: int) -> void:
	walk_speed = 5.0 + float(p - 1) * 1.6
	enraged = p >= 3
	if enraged:
		seam_mat.emission_energy_multiplier = 4.0
		plate_mat.albedo_color = Color(0.72, 0.48, 0.40)


func telegraph_time() -> float:
	if enraged:
		return 0.72
	return 1.18 - (0.18 if walk_speed > 6.0 else 0.0)


func is_open() -> bool:
	return state == S.STAGGER


func _physics_process(delta: float) -> void:
	if game == null or not game.running():
		return
	t += delta
	flash = maxf(0.0, flash - delta)
	var base_col := Color(0.62, 0.56, 0.52)
	if enraged:
		base_col = Color(0.72, 0.48, 0.40)
	if flash > 0.0:
		base_col = base_col.lerp(Color(1.0, 0.95, 0.90), clampf(flash * 3.0, 0.0, 1.0))
	plate_mat.albedo_color = base_col

	match state:
		S.ROAM:
			_do_roam(delta)
		S.STALK:
			_do_stalk(delta)
		S.TELEGRAPH:
			_do_telegraph(delta)
		S.CHARGE:
			_do_charge(delta)
		S.RECOVER:
			_do_recover(delta)
		S.STAGGER:
			_do_stagger(delta)
		S.RETREAT:
			_do_retreat(delta)
		S.SUBDUED:
			_do_subdued(delta)

	if not is_on_floor():
		velocity.y -= 26.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	_clamp()
	_animate(delta)


func _clamp() -> void:
	var r := Vector2(global_position.x, global_position.z)
	if r.length() > 72.0:
		r = r.normalized() * 72.0
		global_position.x = r.x
		global_position.z = r.y
		if state == S.CHARGE:
			_end_charge()


func _set_state(s: int) -> void:
	state = s
	t = 0.0
	lane.visible = (s == S.TELEGRAPH)


func _face(dir: Vector3, delta: float, rate: float = 4.0) -> void:
	if dir.length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, CxUtil.yaw_to(dir.normalized()), clampf(delta * rate, 0.0, 1.0))


func _move_towards(target: Vector3, speed: float, delta: float) -> void:
	var d := CxUtil.flat(target - global_position)
	if d.length() < 0.5:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var dir := d.normalized()
	velocity.x = move_toward(velocity.x, dir.x * speed, 16.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, 16.0 * delta)
	_face(dir, delta)


func _do_roam(delta: float) -> void:
	_move_towards(roam_target, walk_speed * 0.55, delta)
	if CxUtil.flat(roam_target - global_position).length() < 2.0 or t > 7.0:
		roam_target = _random_point()
		t = 0.0
	if player != null and CxUtil.flat(player.global_position - global_position).length() < 34.0:
		_set_state(S.STALK)


func _do_stalk(delta: float) -> void:
	if player == null:
		_set_state(S.ROAM)
		return
	var d := CxUtil.flat(player.global_position - global_position)
	if d.length() > 46.0:
		_set_state(S.ROAM)
		return
	if d.length() > 13.0:
		_move_towards(player.global_position, walk_speed, delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 22.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 22.0 * delta)
		_face(d, delta, 3.0)
	if t > (0.7 if enraged else 1.25) and d.length() < 26.0:
		_set_state(S.TELEGRAPH)
		if game != null:
			game.sfx_alert()


func _do_telegraph(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
	if player != null:
		_face(CxUtil.flat(player.global_position - global_position), delta, 5.0)
	var dur := telegraph_time()
	var p := clampf(t / dur, 0.0, 1.0)
	lane_mat.albedo_color = Color(1.0, 0.45, 0.12, 0.18 + p * 0.55)
	lane_mat.emission_energy_multiplier = 1.2 + p * 3.5
	lane.scale = Vector3(0.55 + p * 0.5, 1.0, 1.0)
	body_root.position.x = sin(t * 48.0) * 0.06 * p
	if t >= dur:
		charge_dir = -global_transform.basis.z
		charge_dir.y = 0.0
		charge_dir = charge_dir.normalized()
		hit_player = false
		_set_state(S.CHARGE)
		body_root.position.x = 0.0
		if game != null:
			game.on_charge_start()


func _do_charge(delta: float) -> void:
	velocity.x = charge_dir.x * CHARGE_SPEED
	velocity.z = charge_dir.z * CHARGE_SPEED
	body_root.rotation.x = lerp(body_root.rotation.x, -0.10, delta * 8.0)
	if player != null and not hit_player:
		var d := CxUtil.flat(player.global_position - global_position)
		if d.length() < 2.9:
			hit_player = true
			player.take_damage(20.0, global_position)
			if game != null:
				game.on_charge_hit()
	if game != null:
		game.charge_sweep(global_position)
	if t > 1.35 or get_slide_collision_count() > 2:
		_end_charge()


func _end_charge() -> void:
	body_root.rotation.x = 0.0
	velocity.x = 0.0
	velocity.z = 0.0
	if hit_player:
		_set_state(S.RECOVER)
	else:
		_set_state(S.STAGGER)
		crash_dust.restart()
		crash_dust.emitting = true
		if game != null:
			game.on_creature_stagger(global_position)


func _do_recover(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 26.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 26.0 * delta)
	if t > (0.6 if enraged else 1.1):
		if enraged and combo < 1 and randf() < 0.6:
			combo += 1
			_set_state(S.TELEGRAPH)
		else:
			combo = 0
			_set_state(S.STALK)


func _do_stagger(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
	var p := clampf(t / STAGGER_TIME, 0.0, 1.0)
	body_root.rotation.x = lerp(0.30, 0.05, p)
	body_root.position.y = lerp(-0.45, -0.1, p)
	seam_mat.emission_energy_multiplier = 5.5 - p * 2.0
	glow.light_energy = 4.0 - p * 2.0
	if t > STAGGER_TIME:
		body_root.rotation.x = 0.0
		body_root.position.y = 0.0
		seam_mat.emission_energy_multiplier = 4.0 if enraged else 2.6
		glow.light_energy = 2.0
		combo = 0
		_set_state(S.STALK)


func _do_retreat(delta: float) -> void:
	_move_towards(roam_target, walk_speed * 1.5, delta)
	if t > 5.0:
		_set_state(S.STALK)


func _do_subdued(delta: float) -> void:
	_move_towards(roam_target, walk_speed * 0.8, delta)
	if CxUtil.flat(roam_target - global_position).length() < 3.0:
		velocity.x = 0.0
		velocity.z = 0.0


func _animate(delta: float) -> void:
	var sp := Vector2(velocity.x, velocity.z).length()
	walk_phase += delta * (2.0 + sp * 0.9)
	for i in range(legs.size()):
		var ph := walk_phase + float(i) * 1.05
		var amp: float = clampf(sp / 8.0, 0.08, 1.0)
		legs[i].rotation.x = sin(ph) * 0.45 * amp
		legs[i].position.y = 1.45 + maxf(0.0, sin(ph + 1.57)) * 0.18 * amp
	if state != S.STAGGER and state != S.CHARGE:
		body_root.rotation.x = lerp(body_root.rotation.x, sin(walk_phase * 0.5) * 0.03, delta * 4.0)
		body_root.position.y = lerp(body_root.position.y, 0.0, delta * 6.0)


func take_damage(amount: float) -> void:
	if state == S.SUBDUED:
		return
	hp = maxf(0.0, hp - amount)
	flash = 0.18
	if shed_idx < shed_at.size() and hp <= shed_at[shed_idx]:
		shed_idx += 1
		if game != null:
			game.creature_shed(global_position + Vector3(0, 1.0, 0))
		if hp <= 0.0:
			roam_target = _random_point().normalized() * 68.0
			_set_state(S.SUBDUED)
			lane.visible = false
		else:
			roam_target = _random_point()
			_set_state(S.RETREAT)
