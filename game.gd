extends Node3D
## CINDERHORN ATLAS — third-person wilderness expedition.
## Builds the whole basin in code, owns the run state machine, weather phases,
## camp defence, pickups, quest log and scoring.

const BASIN_R := 78.0
const EV_NAMES := ["Spoor Cast", "Shed Carapace Plate", "Vent Ash Sample"]
const SAVE_PATH := "user://cinderhorn_atlas.cfg"

enum GS {TITLE, PLAYING, PAUSED, OVER, WIN}

var state: int = GS.TITLE

var player: CxPlayer
var creature: CxCreature
var hud: CxHud
var env: Environment
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D
var fill: DirectionalLight3D
var forge_beacon: MeshInstance3D
var forge_light: OmniLight3D
var ambient_dust: CPUParticles3D
var ember_rain: CPUParticles3D
var title_cam: Camera3D

var camp_pos := Vector3(0, 0, 28)
var player_spawn := Vector3(2, 0, 9)
var forge_pos := Vector3(0, 0, -66)
var camp_hp := 100.0
var evidence := 0
var traces_read := 0
var herbs_total := 0
var phase := 1
var run_time := 0.0
var creature_reveal := 0.0
var ember_timer := 6.0
var best_score := 0
var last_score := 0
var charge_camp_hit := false

var traces: Array = []
var herbs: Array = []
var shards: Array = []
var embers: Array = []

var fog_target := 0.017
var sky_top_target := Color(0.42, 0.26, 0.24)
var sky_hor_target := Color(0.96, 0.72, 0.44)
var sun_energy_target := 1.55
var sun_col_target := Color(1.0, 0.86, 0.64)

var sfx_step_a: AudioStream = preload("res://assets/sfx/step.ogg")
var sfx_hit_a: AudioStream = preload("res://assets/sfx/hit_heavy.ogg")
var sfx_pick_a: AudioStream = preload("res://assets/sfx/pickup.ogg")
var sfx_click_a: AudioStream = preload("res://assets/sfx/click.wav")
var sfx_alert_a: AudioStream = preload("res://assets/sfx/alert.wav")
var _step_gate := 0.0


# ================================================================== lifecycle
func _ready() -> void:
	randomize()
	_register_inputs()
	_load_best()
	_build_env()
	_build_ground()
	_build_rim()
	_build_camp()
	_build_forge()
	_build_traces()
	_build_herbs()
	_build_weather_fx()

	player = CxPlayer.new()
	player.position = player_spawn
	player.game = self
	add_child(player)

	creature = CxCreature.new()
	creature.position = Vector3(13, 0, -22)
	creature.game = self
	add_child(creature)
	creature.player = player

	hud = CxHud.new()
	hud.game = self
	add_child(hud)
	player.hud = hud

	title_cam = Camera3D.new()
	title_cam.fov = 62.0
	title_cam.position = camp_pos + Vector3(-18, 10, 22)
	add_child(title_cam)
	title_cam.look_at(camp_pos + Vector3(0, 2, -6), Vector3.UP)

	if Engine.has_meta("cx_autostart") and bool(Engine.get_meta("cx_autostart")):
		Engine.set_meta("cx_autostart", false)
		call_deferred("start_run")
	else:
		to_title()


func running() -> bool:
	return state == GS.PLAYING


func _register_inputs() -> void:
	_add_action("cx_up", [KEY_W, KEY_UP])
	_add_action("cx_down", [KEY_S, KEY_DOWN])
	_add_action("cx_left", [KEY_A, KEY_LEFT])
	_add_action("cx_right", [KEY_D, KEY_RIGHT])
	_add_action("cx_sprint", [KEY_SHIFT])
	_add_action("cx_dodge", [KEY_SPACE, KEY_CTRL])
	_add_action("cx_attack", [KEY_F, KEY_J], [MOUSE_BUTTON_LEFT])
	_add_action("cx_interact", [KEY_E])
	_add_action("cx_potion", [KEY_Q, KEY_1])
	_add_action("cx_map", [KEY_M])
	_add_action("cx_pause", [KEY_ESCAPE, KEY_P])
	_add_action("cx_restart", [KEY_R])


func _add_action(aname: String, keys: Array, buttons: Array = []) -> void:
	if InputMap.has_action(aname):
		InputMap.action_erase_events(aname)
	else:
		InputMap.add_action(aname)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(aname, ev)
	for b in buttons:
		var mb := InputEventMouseButton.new()
		mb.button_index = b
		InputMap.action_add_event(aname, mb)


# ================================================================ world build
func _build_env() -> void:
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.42, 0.26, 0.24)
	sky_mat.sky_horizon_color = Color(0.96, 0.72, 0.44)
	sky_mat.sky_curve = 0.55
	sky_mat.ground_bottom_color = Color(0.20, 0.14, 0.11)
	sky_mat.ground_horizon_color = Color(0.72, 0.52, 0.33)
	sky_mat.sun_angle_max = 28.0
	sky_mat.energy_multiplier = 1.1
	var sky := Sky.new()
	sky.sky_material = sky_mat

	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.96, 0.72, 0.44)
	env.fog_density = 0.017
	env.fog_sky_affect = 0.35
	env.fog_aerial_perspective = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.02
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.32
	env.glow_bloom = 0.10
	env.glow_hdr_threshold = 1.0

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -126, 0)
	sun.light_color = Color(1.0, 0.86, 0.64)
	sun.light_energy = 1.55
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	sun.directional_shadow_blend_splits = true
	add_child(sun)

	fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-24, 58, 0)
	fill.light_color = Color(0.46, 0.60, 0.86)
	fill.light_energy = 0.42
	fill.shadow_enabled = false
	add_child(fill)


func _build_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(260, 260)
	plane.subdivide_width = 4
	plane.subdivide_depth = 4
	var sh := Shader.new()
	sh.code = "shader_type spatial;\n" + \
		"uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;\n" + \
		"uniform vec3 tint = vec3(0.98, 0.88, 0.70);\n" + \
		"void fragment() {\n" + \
		"	vec3 a = texture(tex, UV * 96.0).rgb;\n" + \
		"	vec3 b = texture(tex, UV * 7.0).rgb;\n" + \
		"	vec3 c = mix(a, b, 0.22);\n" + \
		"	c = mix(c, vec3(0.90, 0.80, 0.60), 0.45);\n" + \
		"	ALBEDO = c * tint;\n" + \
		"	ROUGHNESS = 0.95;\n" + \
		"	SPECULAR = 0.12;\n" + \
		"}\n"
	var gm := ShaderMaterial.new()
	gm.shader = sh
	var gtex: Texture2D = load("res://assets/tex/salt_crust.png")
	gm.set_shader_parameter("tex", gtex)
	var ground := CxUtil.mi(plane, gm, Vector3.ZERO)
	add_child(ground)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(300, 2, 300)
	cs.shape = bs
	cs.position = Vector3(0, -1, 0)
	body.add_child(cs)
	add_child(body)

	# scorched vent patches + dried salt pans break up the flat floor
	for i in range(26):
		var a := randf() * TAU
		var r := randf_range(8.0, 70.0)
		var p := Vector3(cos(a) * r, 0.02, sin(a) * r)
		var disc := CylinderMesh.new()
		disc.top_radius = randf_range(2.5, 7.0)
		disc.bottom_radius = disc.top_radius
		disc.height = 0.04
		disc.radial_segments = 14
		var dark := randf() < 0.45
		var col := Color(0.28, 0.20, 0.17) if dark else Color(0.96, 0.90, 0.78)
		var m := CxUtil.mat(col, 0.95)
		add_child(CxUtil.mi(disc, m, p))
		if dark and randf() < 0.6:
			var vent := CxUtil.mi(CxUtil.cyl(0.5, 0.9, 0.5), CxUtil.glow_mat(Color(1.0, 0.38, 0.08), 1.6), p + Vector3(0, 0.1, 0))
			add_child(vent)

	# salt ridges
	for i in range(34):
		var a2 := randf() * TAU
		var r2 := randf_range(12.0, 72.0)
		var ridge := CxUtil.mi(CxUtil.box(randf_range(2.0, 6.0), randf_range(0.3, 0.9), randf_range(0.6, 1.6)),
			CxUtil.tex_mat("res://assets/tex/salt_crust.png", Color(0.98, 0.93, 0.82), 0.8, Vector3(2, 2, 0)),
			Vector3(cos(a2) * r2, 0.12, sin(a2) * r2))
		ridge.rotation.y = randf() * TAU
		ridge.rotation.z = randf_range(-0.08, 0.08)
		add_child(ridge)


func _build_rim() -> void:
	var rock_mat := CxUtil.tex_mat("res://assets/tex/ash_rock.png", Color(0.52, 0.46, 0.44), 0.95, Vector3(3, 3, 0))
	var rock_scene: PackedScene = load("res://assets/models/rock_small.glb")
	var tree_scene: PackedScene = load("res://assets/models/tree.glb")

	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	add_child(wall)

	for i in range(74):
		var a := TAU * float(i) / 74.0 + randf_range(-0.02, 0.02)
		var r := 84.0 + randf_range(-3.0, 5.0)
		var h := randf_range(9.0, 26.0)
		var w := randf_range(9.0, 16.0)
		var slab := CxUtil.mi(CxUtil.box(w, h, randf_range(8.0, 14.0)), rock_mat,
			Vector3(cos(a) * r, h * 0.42 - 1.0, sin(a) * r))
		slab.rotation.y = -a + randf_range(-0.25, 0.25)
		slab.rotation.z = randf_range(-0.09, 0.09)
		slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		slab.material_override = CxUtil.tex_mat("res://assets/tex/ash_rock.png",
			Color(0.52, 0.46, 0.44).lerp(Color(0.34, 0.26, 0.24), randf()), randf_range(0.82, 0.98), Vector3(3, 3, 0))
		add_child(slab)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(w, h, 10.0)
		cs.shape = bs
		cs.position = Vector3(cos(a) * r, h * 0.42 - 1.0, sin(a) * r)
		cs.rotation.y = -a
		wall.add_child(cs)

	# distant volcanic horizon cones
	for i in range(9):
		var a3 := TAU * float(i) / 9.0 + 0.3
		var d := randf_range(120.0, 165.0)
		var ch := randf_range(28.0, 62.0)
		var cone := CxUtil.mi(CxUtil.cyl(randf_range(1.0, 5.0), randf_range(20.0, 34.0), ch, 10),
			CxUtil.mat(Color(0.34, 0.26, 0.25).lerp(Color(0.52, 0.38, 0.33), randf()), 0.95),
			Vector3(cos(a3) * d, ch * 0.4, sin(a3) * d))
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(cone)

	# scattered boulders (fetched model, jittered per instance)
	for i in range(62):
		var a4 := randf() * TAU
		var r4 := randf_range(10.0, 76.0)
		var rp := Vector3(cos(a4) * r4, 0.0, sin(a4) * r4)
		if rp.distance_to(player_spawn) < 18.0 or rp.distance_to(camp_pos) < 15.0:
			continue
		var rock: Node3D = rock_scene.instantiate()
		rock.position = rp
		var s := randf_range(1.5, 4.0)
		rock.scale = Vector3(s, s * randf_range(0.7, 1.2), s)
		rock.rotation.y = randf() * TAU
		add_child(rock)
		if s > 2.2:
			var sb := StaticBody3D.new()
			sb.collision_layer = 1
			sb.position = rp
			var cs2 := CollisionShape3D.new()
			var sp := SphereShape3D.new()
			sp.radius = maxf(1.0, s * 0.42)
			cs2.shape = sp
			cs2.position = Vector3(0, sp.radius * 0.55, 0)
			sb.add_child(cs2)
			add_child(sb)

	# ash trees cluster near the rim
	for i in range(30):
		var a5 := randf() * TAU
		var r5 := randf_range(48.0, 76.0)
		var tp := Vector3(cos(a5) * r5, 0.0, sin(a5) * r5)
		if tp.distance_to(player_spawn) < 18.0:
			continue
		var tree: Node3D = tree_scene.instantiate()
		tree.position = tp
		var ts := randf_range(2.2, 4.4)
		tree.scale = Vector3(ts * randf_range(0.8, 1.15), ts, ts * randf_range(0.8, 1.15))
		tree.rotation.y = randf() * TAU
		tree.rotation.z = randf_range(-0.09, 0.09)
		_tint(tree, Color(0.70, 0.55, 0.42))
		add_child(tree)


func _tint(root: Node, col: Color) -> void:
	for c in root.get_children():
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			var m := CxUtil.mat(col, 0.9)
			var src: Material = mi.get_active_material(0)
			if src is StandardMaterial3D:
				var sm := src as StandardMaterial3D
				m.albedo_texture = sm.albedo_texture
				m.albedo_color = sm.albedo_color * col
			mi.material_override = m
		_tint(c, col)


func _emissive(root: Node, col: Color, energy: float) -> void:
	for c in root.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_override = CxUtil.glow_mat(col, energy)
		_emissive(c, col, energy)


func _build_camp() -> void:
	var camp := Node3D.new()
	camp.position = camp_pos
	add_child(camp)

	var house_scene: PackedScene = load("res://assets/models/house.glb")
	var house: Node3D = house_scene.instantiate()
	house.scale = Vector3(3.1, 3.1, 3.1)
	house.rotation.y = 0.5
	house.position = Vector3(-4.0, 0.0, 5.0)
	camp.add_child(house)

	var crate_scene: PackedScene = load("res://assets/models/crate.glb")
	for i in range(7):
		var crate: Node3D = crate_scene.instantiate()
		var a := randf() * TAU
		crate.position = Vector3(cos(a) * randf_range(4.0, 8.0), 0.6, sin(a) * randf_range(4.0, 8.0))
		crate.scale = Vector3.ONE * randf_range(1.0, 1.6)
		crate.rotation.y = randf() * TAU
		camp.add_child(crate)

	# canvas survey tarp
	var canvas := CxUtil.tex_mat("res://assets/tex/canvas.png", Color(0.95, 0.88, 0.74), 0.95, Vector3(2, 2, 0))
	var tarp := CxUtil.mi(CxUtil.box(7.0, 0.14, 6.0), canvas, Vector3(-7.0, 3.4, 2.0))
	tarp.rotation.z = 0.12
	camp.add_child(tarp)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var pole := CxUtil.mi(CxUtil.cyl(0.11, 0.13, 3.4), CxUtil.mat(Color(0.33, 0.24, 0.17), 0.9),
				Vector3(-7.0 + sx * 3.2, 1.7, 2.0 + sz * 2.6))
			camp.add_child(pole)

	# fire pit
	var ring := CxUtil.mi(CxUtil.cyl(1.5, 1.7, 0.4, 14), CxUtil.mat(Color(0.26, 0.21, 0.19), 0.95), Vector3(5.0, 0.2, 2.0))
	camp.add_child(ring)
	var fire := CPUParticles3D.new()
	fire.amount = 26
	fire.lifetime = 1.2
	fire.position = Vector3(5.0, 0.4, 2.0)
	fire.direction = Vector3(0, 1, 0)
	fire.spread = 14.0
	fire.initial_velocity_min = 1.4
	fire.initial_velocity_max = 3.0
	fire.gravity = Vector3(0, 1.0, 0)
	fire.scale_amount_min = 0.2
	fire.scale_amount_max = 0.55
	fire.color = Color(1.0, 0.55, 0.16, 0.9)
	fire.mesh = CxUtil.sph(0.5)
	camp.add_child(fire)
	var fl := OmniLight3D.new()
	fl.position = Vector3(5.0, 1.6, 2.0)
	fl.light_color = Color(1.0, 0.56, 0.22)
	fl.light_energy = 3.2
	fl.omni_range = 18.0
	camp.add_child(fl)

	# teal lantern posts marking the shelter ring
	for i in range(6):
		var a2 := TAU * float(i) / 6.0
		var p := Vector3(cos(a2) * 11.0, 0, sin(a2) * 11.0)
		camp.add_child(CxUtil.mi(CxUtil.cyl(0.08, 0.12, 3.0), CxUtil.mat(Color(0.30, 0.22, 0.16), 0.9), p + Vector3(0, 1.5, 0)))
		camp.add_child(CxUtil.mi(CxUtil.sph(0.26), CxUtil.glow_mat(Color(0.25, 0.92, 0.82), 3.0), p + Vector3(0, 3.1, 0)))
		var ll := OmniLight3D.new()
		ll.position = p + Vector3(0, 3.1, 0)
		ll.light_color = Color(0.28, 0.92, 0.84)
		ll.light_energy = 1.5
		ll.omni_range = 10.0
		camp.add_child(ll)

	# survey table (interaction anchor)
	camp.add_child(CxUtil.mi(CxUtil.box(2.6, 0.18, 1.7), CxUtil.tex_mat("res://assets/tex/canvas.png", Color(0.92, 0.84, 0.66), 0.9), Vector3(-2.5, 1.1, -3.5)))
	for sx2 in [-1.0, 1.0]:
		camp.add_child(CxUtil.mi(CxUtil.cyl(0.07, 0.07, 1.1), CxUtil.mat(Color(0.30, 0.22, 0.16), 0.9), Vector3(-2.5 + sx2 * 1.1, 0.55, -3.5)))


func _build_forge() -> void:
	var forge := Node3D.new()
	forge.position = forge_pos
	add_child(forge)
	var castle_scene: PackedScene = load("res://assets/models/castle.glb")
	var castle: Node3D = castle_scene.instantiate()
	castle.scale = Vector3(7.0, 7.0, 7.0)
	castle.rotation.y = PI
	forge.add_child(castle)

	var anvil := CxUtil.mi(CxUtil.box(3.0, 1.2, 1.8), CxUtil.mat(Color(0.22, 0.20, 0.21), 0.42, 0.65), Vector3(0, 1.0, 8.0))
	forge.add_child(anvil)
	forge_beacon = CxUtil.mi(CxUtil.cyl(1.0, 1.6, 26.0, 12), CxUtil.glow_mat(Color(1.0, 0.56, 0.14), 3.0), Vector3(0, 13.0, 8.0))
	forge_beacon.visible = false
	forge.add_child(forge_beacon)
	forge_light = OmniLight3D.new()
	forge_light.position = Vector3(0, 4.0, 8.0)
	forge_light.light_color = Color(1.0, 0.56, 0.18)
	forge_light.light_energy = 0.0
	forge_light.omni_range = 34.0
	forge.add_child(forge_light)


func _build_traces() -> void:
	var spots := [
		Vector3(-17, 0, -3), Vector3(44, 0, 18), Vector3(-18, 0, 52),
		Vector3(16, 0, -52), Vector3(60, 0, -28), Vector3(-58, 0, 30)
	]
	var rock_scene: PackedScene = load("res://assets/models/rock_small.glb")
	for i in range(spots.size()):
		var pos: Vector3 = spots[i]
		var node := Node3D.new()
		node.position = pos
		add_child(node)
		for j in range(4):
			var rk: Node3D = rock_scene.instantiate()
			var s := 2.6 - float(j) * 0.45
			rk.scale = Vector3(s, s * 0.8, s)
			rk.position = Vector3(randf_range(-0.3, 0.3), float(j) * 0.55, randf_range(-0.3, 0.3))
			rk.rotation.y = randf() * TAU
			node.add_child(rk)
		var beam_mat := CxUtil.glow_mat(Color(0.98, 0.66, 0.20), 1.1)
		beam_mat.albedo_color = Color(0.98, 0.66, 0.20, 0.34)
		beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var col := CxUtil.mi(CxUtil.cyl(0.30, 0.46, 9.0, 10), beam_mat, Vector3(0, 4.6, 0))
		col.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(col)
		var torus := TorusMesh.new()
		torus.inner_radius = 2.9
		torus.outer_radius = 3.2
		torus.rings = 24
		var ring := CxUtil.mi(torus, CxUtil.glow_mat(Color(0.98, 0.66, 0.20), 1.0), Vector3(0, 0.08, 0))
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(ring)
		var lt := OmniLight3D.new()
		lt.position = Vector3(0, 2.0, 0)
		lt.light_color = Color(1.0, 0.70, 0.26)
		lt.light_energy = 1.6
		lt.omni_range = 12.0
		node.add_child(lt)
		# three claw-prints hinting the beast's gait
		for k in range(5):
			var side := -1.0 if k % 2 == 0 else 1.0
			var pr_root := Node3D.new()
			pr_root.position = Vector3(side * 1.3 + randf_range(-0.4, 0.4), 0.03, 4.0 + float(k) * 2.6)
			pr_root.rotation.y = randf_range(-0.3, 0.3)
			node.add_child(pr_root)
			for toe in range(3):
				var claw := CxUtil.mi(CxUtil.cyl(0.10, 0.17, 0.05, 8), CxUtil.mat(Color(0.26, 0.18, 0.15), 0.98),
					Vector3((float(toe) - 1.0) * 0.32, 0.0, -0.18 + absf(float(toe) - 1.0) * 0.12))
				claw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				pr_root.add_child(claw)
			var pad := CxUtil.mi(CxUtil.cyl(0.30, 0.34, 0.05, 10), CxUtil.mat(Color(0.26, 0.18, 0.15), 0.98), Vector3(0, 0, 0.26))
			pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pr_root.add_child(pad)
		traces.append({"pos": pos, "read": false, "node": node, "col": col, "ring": ring, "light": lt})


func _build_herbs() -> void:
	var jewel_scene: PackedScene = load("res://assets/models/jewel.glb")
	for i in range(26):
		var a := randf() * TAU
		var r := randf_range(14.0, 72.0)
		_spawn_herb(Vector3(cos(a) * r, 0.6, sin(a) * r), jewel_scene)


func _spawn_herb(pos: Vector3, scn: PackedScene = null) -> void:
	var jewel_scene: PackedScene = scn
	if jewel_scene == null:
		jewel_scene = load("res://assets/models/jewel.glb")
	var h: Node3D = jewel_scene.instantiate()
	h.position = pos
	h.scale = Vector3(2.0, 2.4, 2.0)
	_emissive(h, Color(0.38, 0.86, 0.40), 0.55)
	add_child(h)
	var base := CxUtil.mi(CxUtil.cyl(0.05, 0.5, 0.5, 8), CxUtil.mat(Color(0.86, 0.80, 0.62), 0.9), Vector3(0, -0.4, 0))
	h.add_child(base)
	herbs.append(h)


func _build_weather_fx() -> void:
	ambient_dust = CPUParticles3D.new()
	ambient_dust.amount = 90
	ambient_dust.lifetime = 5.0
	ambient_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ambient_dust.emission_box_extents = Vector3(42, 9, 42)
	ambient_dust.direction = Vector3(1, 0.1, 0.4)
	ambient_dust.spread = 25.0
	ambient_dust.initial_velocity_min = 1.4
	ambient_dust.initial_velocity_max = 3.6
	ambient_dust.gravity = Vector3(0.4, -0.25, 0.2)
	ambient_dust.scale_amount_min = 0.06
	ambient_dust.scale_amount_max = 0.2
	ambient_dust.color = Color(0.92, 0.78, 0.54, 0.5)
	ambient_dust.mesh = CxUtil.sph(0.5)
	ambient_dust.position = Vector3(0, 6, 0)
	add_child(ambient_dust)

	ember_rain = CPUParticles3D.new()
	ember_rain.amount = 120
	ember_rain.lifetime = 3.2
	ember_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ember_rain.emission_box_extents = Vector3(36, 1, 36)
	ember_rain.direction = Vector3(0.2, -1, 0)
	ember_rain.spread = 8.0
	ember_rain.initial_velocity_min = 4.0
	ember_rain.initial_velocity_max = 8.0
	ember_rain.gravity = Vector3(0.6, -3.0, 0)
	ember_rain.scale_amount_min = 0.08
	ember_rain.scale_amount_max = 0.22
	ember_rain.color = Color(1.0, 0.48, 0.14, 0.95)
	ember_rain.mesh = CxUtil.sph(0.5)
	ember_rain.position = Vector3(0, 24, 0)
	ember_rain.emitting = false
	add_child(ember_rain)


# ============================================================== state machine
func to_title() -> void:
	state = GS.TITLE
	get_tree().paused = false
	if player != null:
		player.set_active(false)
	if title_cam != null:
		title_cam.current = true
	if hud != null:
		hud.show_title()


func start_run() -> void:
	if state == GS.PLAYING:
		return
	state = GS.PLAYING
	get_tree().paused = false
	GameAudio.unlock()
	run_time = 0.0
	player.set_active(true)
	player.cam.current = true
	hud.show_play()
	hud.banner("AMBER SURVEY", "Read a trace, then bait the Cinderhorn's charge", Color(1.0, 0.72, 0.28))
	toast("Find a glowing trace cairn and press E to read it")
	sfx_click()


func restart() -> void:
	Engine.set_meta("cx_autostart", true)
	get_tree().paused = false
	get_tree().reload_current_scene()


func toggle_pause() -> void:
	if state == GS.PLAYING:
		state = GS.PAUSED
		get_tree().paused = true
		hud.show_pause(true)
		sfx_click()
	elif state == GS.PAUSED:
		state = GS.PLAYING
		get_tree().paused = false
		hud.show_pause(false)
		sfx_click()


func game_over(reason: String) -> void:
	if state == GS.OVER or state == GS.WIN:
		return
	state = GS.OVER
	player.set_active(false)
	last_score = _score(false)
	_save_best(last_score)
	hud.show_result(false, "%s\n\nEvidence documented: %d/3    Traces read: %d\nSalt herbs gathered: %d    Camp integrity: %d%%\n\nAtlas score: %d        Best: %d" % [reason, evidence, traces_read, herbs_total, int(camp_hp), last_score, best_score])


func win() -> void:
	if state == GS.WIN:
		return
	state = GS.WIN
	player.set_active(false)
	last_score = _score(true)
	_save_best(last_score)
	hud.show_result(true, "The Cinderhorn Atlas is bound at the forge anvil. Three evidence sets, one basin mapped, and the camp still standing.\n\nTraces read: %d    Herbs: %d    Camp: %d%%    Time: %ds\n\nAtlas score: %d        Best: %d" % [traces_read, herbs_total, int(camp_hp), int(run_time), last_score, best_score])
	puff(player.global_position + Vector3(0, 1.5, 0), Color(0.3, 0.95, 0.85), 40)


func _score(won: bool) -> int:
	var s := evidence * 1200 + traces_read * 300 + herbs_total * 25 + int(camp_hp) * 6
	if won:
		s += 2500 + int(maxf(0.0, 480.0 - run_time) * 4.0)
	return s


func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_score = int(cfg.get_value("atlas", "best", 0))


func _save_best(s: int) -> void:
	if s > best_score:
		best_score = s
	var cfg := ConfigFile.new()
	cfg.set_value("atlas", "best", best_score)
	cfg.save(SAVE_PATH)


# ===================================================================== update
func _unhandled_input(event: InputEvent) -> void:
	if state == GS.TITLE:
		if (event is InputEventKey and event.pressed and not event.echo) \
				or (event is InputEventMouseButton and event.pressed) \
				or (event is InputEventScreenTouch and event.pressed):
			start_run()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.physical_keycode == KEY_ESCAPE or k.physical_keycode == KEY_P:
			if state == GS.PLAYING or state == GS.PAUSED:
				toggle_pause()
		elif k.physical_keycode == KEY_M:
			if state == GS.PLAYING:
				hud.toggle_map()
		elif k.physical_keycode == KEY_R:
			if state == GS.OVER or state == GS.WIN:
				restart()
		elif k.physical_keycode == KEY_E:
			if state == GS.PLAYING:
				_try_interact()


func _process(delta: float) -> void:
	_blend_weather(delta)
	if player != null:
		ambient_dust.global_position = Vector3(player.global_position.x, 7.0, player.global_position.z)
		ember_rain.global_position = Vector3(player.global_position.x, 24.0, player.global_position.z)
	if state == GS.TITLE and title_cam != null:
		var a := Time.get_ticks_msec() * 0.00012
		title_cam.position = camp_pos + Vector3(sin(a) * 26.0, 11.0, cos(a) * 26.0)
		title_cam.look_at(camp_pos + Vector3(0, 2.5, 0), Vector3.UP)
		return
	if state != GS.PLAYING:
		return

	run_time += delta
	creature_reveal = maxf(0.0, creature_reveal - delta)
	_step_gate = maxf(0.0, _step_gate - delta)
	_update_phase()
	_update_pickups(delta)
	_update_embers(delta)
	_update_prompt()
	_update_hazards(delta)

	if hud.consume_interact():
		_try_interact()

	if player.health <= 0.0:
		game_over("The basin took you. The Cinderhorn walks on, undocumented.")
	elif camp_hp <= 0.0:
		game_over("The survey camp burned. Without it, the Atlas cannot be bound.")


func _update_phase() -> void:
	var by_time := int(run_time / 85.0) + 1
	var p: int = clampi(maxi(evidence + 1, by_time), 1, 3)
	if p == phase:
		return
	phase = p
	creature.set_phase(phase)
	if phase == 2:
		fog_target = 0.030
		sky_top_target = Color(0.44, 0.26, 0.18)
		sky_hor_target = Color(0.97, 0.64, 0.32)
		sun_energy_target = 1.1
		sun_col_target = Color(1.0, 0.76, 0.50)
		ambient_dust.amount = 150
		hud.banner("AMBER HAZE", "Dust closes in. The Cinderhorn moves faster.", Color(1.0, 0.72, 0.28))
	elif phase == 3:
		fog_target = 0.040
		sky_top_target = Color(0.38, 0.12, 0.10)
		sky_hor_target = Color(0.99, 0.42, 0.16)
		sun_energy_target = 0.85
		sun_col_target = Color(1.0, 0.56, 0.34)
		ember_rain.emitting = true
		hud.banner("EMBER RAIN", "Its plates crack molten. Stay in the lantern ring to shelter.", Color(1.0, 0.36, 0.10))
	sfx_alert()


func _blend_weather(delta: float) -> void:
	var k := clampf(delta * 0.8, 0.0, 1.0)
	env.fog_density = lerp(env.fog_density, fog_target, k)
	sky_mat.sky_top_color = sky_mat.sky_top_color.lerp(sky_top_target, k)
	sky_mat.sky_horizon_color = sky_mat.sky_horizon_color.lerp(sky_hor_target, k)
	env.fog_light_color = env.fog_light_color.lerp(sky_hor_target, k)
	sun.light_energy = lerp(sun.light_energy, sun_energy_target, k)
	sun.light_color = sun.light_color.lerp(sun_col_target, k)


func sheltered() -> bool:
	return player != null and CxUtil.flat(player.global_position - camp_pos).length() < 12.0


func _update_hazards(delta: float) -> void:
	if phase >= 3 and not sheltered():
		player.health = maxf(0.0, player.health - 3.2 * delta)
		if randf() < delta * 1.6:
			puff(player.global_position + Vector3(randf_range(-1, 1), 1.4, randf_range(-1, 1)), Color(1.0, 0.45, 0.12), 6)
	if phase >= 2:
		ember_timer -= delta
		if ember_timer <= 0.0:
			ember_timer = 7.5 - float(phase) * 1.6
			_spawn_ember()


func _update_pickups(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.003
	for i in range(herbs.size() - 1, -1, -1):
		var h: Node3D = herbs[i]
		if not is_instance_valid(h):
			herbs.remove_at(i)
			continue
		h.rotation.y += delta * 1.6
		h.position.y = 0.6 + sin(t + float(i)) * 0.12
		if h.global_position.distance_to(player.global_position) < 2.2:
			herbs.remove_at(i)
			player.herbs += 1
			herbs_total += 1
			float_text(h.global_position + Vector3(0, 1.4, 0), "SALT HERB", Color(0.60, 0.95, 0.60))
			puff(h.global_position, Color(0.55, 0.95, 0.55), 14)
			sfx_pickup()
			toast("Salt herb gathered (%d) — 2 brew a tonic at camp" % player.herbs)
			h.queue_free()
	for i in range(shards.size() - 1, -1, -1):
		var s: Node3D = shards[i]
		if not is_instance_valid(s):
			shards.remove_at(i)
			continue
		s.rotation.y += delta * 2.4
		s.position.y = 1.2 + sin(t * 1.4 + float(i)) * 0.25
		if s.global_position.distance_to(player.global_position) < 2.8:
			shards.remove_at(i)
			_bank_evidence()
			puff(s.global_position, Color(1.0, 0.72, 0.22), 26)
			s.queue_free()


func _bank_evidence() -> void:
	var name_str: String = EV_NAMES[mini(evidence, EV_NAMES.size() - 1)]
	evidence += 1
	sfx_pickup()
	player.add_shake(0.5)
	hud.banner("EVIDENCE %d/3" % evidence, name_str + " recorded in the Atlas", Color(1.0, 0.75, 0.30))
	if evidence >= 3:
		forge_beacon.visible = true
		forge_light.light_energy = 6.0
		toast("Atlas full — carry it north to the forge beacon")
		hud.banner("THE FORGE IS LIT", "Return north and bind the Atlas", Color(0.30, 0.95, 0.85))


func _update_embers(delta: float) -> void:
	for i in range(embers.size() - 1, -1, -1):
		var e: Dictionary = embers[i]
		var n: Node3D = e["node"]
		if not is_instance_valid(n):
			embers.remove_at(i)
			continue
		var to_camp := CxUtil.flat(camp_pos - n.global_position)
		var d := to_camp.length()
		if d < 3.5:
			camp_hp = maxf(0.0, camp_hp - 7.0)
			puff(n.global_position, Color(1.0, 0.40, 0.12), 20)
			float_text(n.global_position + Vector3(0, 2, 0), "CAMP -7", Color(1.0, 0.45, 0.2))
			sfx_hit()
			n.queue_free()
			embers.remove_at(i)
			continue
		n.global_position += to_camp.normalized() * 5.2 * delta
		n.position.y = 1.6 + sin(Time.get_ticks_msec() * 0.005 + float(i)) * 0.4


func _spawn_ember() -> void:
	var a := randf() * TAU
	var pos := camp_pos + Vector3(cos(a), 0, sin(a)) * randf_range(32.0, 52.0)
	pos.y = 1.8
	var n := CxUtil.mi(CxUtil.sph(0.55), CxUtil.glow_mat(Color(1.0, 0.42, 0.10), 3.4), pos)
	add_child(n)
	var lt := OmniLight3D.new()
	lt.light_color = Color(1.0, 0.45, 0.12)
	lt.light_energy = 2.4
	lt.omni_range = 9.0
	n.add_child(lt)
	var tail := CPUParticles3D.new()
	tail.amount = 14
	tail.lifetime = 0.8
	tail.direction = Vector3(0, -1, 0)
	tail.spread = 20.0
	tail.initial_velocity_min = 0.6
	tail.initial_velocity_max = 1.6
	tail.gravity = Vector3(0, -1.2, 0)
	tail.scale_amount_min = 0.06
	tail.scale_amount_max = 0.2
	tail.color = Color(1.0, 0.55, 0.18, 0.8)
	tail.mesh = CxUtil.sph(0.5)
	n.add_child(tail)
	embers.append({"node": n})
	if embers.size() == 1:
		toast("Embers drift toward the camp — cut them down")


# ================================================================ interaction
func _nearest() -> Dictionary:
	if player == null:
		return {}
	var pp := player.global_position
	if evidence >= 3 and CxUtil.flat(pp - forge_pos).length() < 14.0:
		return {"type": "forge", "label": "Bind the Cinderhorn Atlas"}
	if CxUtil.flat(pp - camp_pos).length() < 11.0:
		var lbl := "Field work: brew a salt tonic (2 herbs)"
		if player.herbs < 2:
			lbl = "Field work: need 2 salt herbs"
		elif player.potions >= 3:
			lbl = "Field work: reinforce the camp (2 herbs)"
		return {"type": "camp", "label": lbl}
	for i in range(traces.size()):
		var t: Dictionary = traces[i]
		if t["read"]:
			continue
		var tp: Vector3 = t["pos"]
		if CxUtil.flat(pp - tp).length() < 5.0:
			return {"type": "trace", "idx": i, "label": "Read the creature trace"}
	return {}


func _update_prompt() -> void:
	var n := _nearest()
	if n.is_empty():
		hud.show_prompt("")
	else:
		var key := "USE" if hud.touch_mode else "[E]"
		hud.show_prompt("%s  %s" % [key, str(n["label"])])


func _try_interact() -> void:
	var n := _nearest()
	if n.is_empty():
		return
	var tp: String = str(n["type"])
	if tp == "trace":
		_read_trace(int(n["idx"]))
	elif tp == "camp":
		_camp_work()
	elif tp == "forge":
		win()


func _read_trace(idx: int) -> void:
	var t: Dictionary = traces[idx]
	if t["read"]:
		return
	t["read"] = true
	traces[idx] = t
	traces_read += 1
	creature_reveal = 45.0
	var col: MeshInstance3D = t["col"]
	var bm := CxUtil.glow_mat(Color(0.25, 0.92, 0.82), 1.1)
	bm.albedo_color = Color(0.25, 0.92, 0.82, 0.30)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	col.material_override = bm
	var ring: MeshInstance3D = t["ring"]
	ring.material_override = CxUtil.glow_mat(Color(0.25, 0.92, 0.82), 1.2)
	var lt: OmniLight3D = t["light"]
	lt.light_color = Color(0.28, 0.92, 0.84)
	var pos: Vector3 = t["pos"]
	for i in range(2):
		_spawn_herb(pos + Vector3(randf_range(-6, 6), 0.6, randf_range(-6, 6)))
	puff(pos + Vector3(0, 1.0, 0), Color(0.3, 0.95, 0.85), 26)
	sfx_pickup()
	float_text(pos + Vector3(0, 3.0, 0), "TRACE READ", Color(0.3, 0.95, 0.85))
	hud.banner("TRACE READ", "Gait depth says it charges in a straight line — step aside, never back", Color(0.30, 0.95, 0.85))
	toast("Cinderhorn marked on your map for 45s — press M")


func _camp_work() -> void:
	if player.herbs < 2:
		toast("You need 2 salt herbs for field work")
		sfx_click()
		return
	player.herbs -= 2
	if player.potions < 3:
		player.potions += 1
		toast("Salt tonic brewed (%d held) — press Q to drink" % player.potions)
		float_text(camp_pos + Vector3(0, 3, 0), "TONIC BREWED", Color(0.55, 0.95, 0.65))
	else:
		camp_hp = minf(100.0, camp_hp + 22.0)
		toast("Camp reinforced to %d%%" % int(camp_hp))
		float_text(camp_pos + Vector3(0, 3, 0), "CAMP +22", Color(0.95, 0.80, 0.35))
	puff(camp_pos + Vector3(0, 1.5, 0), Color(0.9, 0.85, 0.6), 18)
	sfx_pickup()


# ===================================================================== combat
func player_swing(origin: Vector3, dir: Vector3) -> void:
	sfx_step()
	var hit_any := false
	if is_instance_valid(creature):
		var to_c := CxUtil.flat(creature.global_position - origin)
		if to_c.length() < 4.6 and to_c.normalized().dot(dir) > 0.25:
			var open := creature.is_open()
			var dmg := 30.0 if open else 7.0
			creature.take_damage(dmg)
			hit_any = true
			var hp := origin + dir * 2.4 + Vector3(0, 1.4, 0)
			if open:
				puff(hp, Color(1.0, 0.55, 0.15), 30)
				float_text(hp, "%d  VENT HIT" % int(dmg), Color(1.0, 0.72, 0.25))
				player.add_shake(0.7)
				sfx_hit()
			else:
				puff(hp, Color(0.8, 0.8, 0.85), 12)
				float_text(hp, "%d  armored" % int(dmg), Color(0.80, 0.80, 0.80))
				player.add_shake(0.25)
				sfx_step()
	for i in range(embers.size() - 1, -1, -1):
		var e: Dictionary = embers[i]
		var n: Node3D = e["node"]
		if not is_instance_valid(n):
			embers.remove_at(i)
			continue
		if n.global_position.distance_to(origin) < 4.2:
			puff(n.global_position, Color(1.0, 0.5, 0.15), 18)
			float_text(n.global_position + Vector3(0, 1.2, 0), "EMBER CUT", Color(1.0, 0.65, 0.25))
			n.queue_free()
			embers.remove_at(i)
			hit_any = true
			sfx_pickup()
	if not hit_any:
		puff(origin + dir * 2.0 + Vector3(0, 0.3, 0), Color(0.88, 0.78, 0.56), 8)


func charge_sweep(pos: Vector3) -> void:
	if not charge_camp_hit and CxUtil.flat(pos - camp_pos).length() < 9.0:
		charge_camp_hit = true
		camp_hp = maxf(0.0, camp_hp - 12.0)
		puff(camp_pos + Vector3(0, 1.5, 0), Color(1.0, 0.45, 0.12), 30)
		float_text(camp_pos + Vector3(0, 3.5, 0), "CAMP -12", Color(1.0, 0.45, 0.2))
		player.add_shake(0.8)
		sfx_hit()
	if randf() < 0.5:
		puff(pos + Vector3(0, 0.2, 0), Color(0.86, 0.72, 0.48), 5)


func on_charge_start() -> void:
	charge_camp_hit = false
	sfx_alert()
	player.add_shake(0.25)


func on_charge_hit() -> void:
	sfx_hit()
	puff(player.global_position + Vector3(0, 1.2, 0), Color(1.0, 0.35, 0.18), 24)


func on_creature_stagger(pos: Vector3) -> void:
	player.add_shake(1.0)
	sfx_hit()
	puff(pos + Vector3(0, 0.6, 0), Color(0.88, 0.76, 0.52), 34)
	float_text(pos + Vector3(0, 3.6, 0), "STAGGERED", Color(1.0, 0.72, 0.25))
	toast("Vents open — strike now!")


func on_player_hurt(amount: float) -> void:
	sfx_hit()
	float_text(player.global_position + Vector3(0, 2.4, 0), "-%d" % int(amount), Color(1.0, 0.4, 0.3))


func creature_shed(pos: Vector3) -> void:
	var scn: PackedScene = load("res://assets/models/coin_gold.glb")
	var s: Node3D = scn.instantiate()
	s.position = Vector3(pos.x, 1.2, pos.z)
	s.scale = Vector3(3.0, 3.0, 3.0)
	_emissive(s, Color(1.0, 0.62, 0.14), 1.5)
	add_child(s)
	var lt := OmniLight3D.new()
	lt.light_color = Color(1.0, 0.70, 0.22)
	lt.light_energy = 3.0
	lt.omni_range = 14.0
	s.add_child(lt)
	shards.append(s)
	puff(pos, Color(1.0, 0.6, 0.18), 30)
	player.add_shake(0.6)
	sfx_alert()
	hud.banner("EVIDENCE SHED", "A sample broke loose — collect it", Color(1.0, 0.72, 0.28))


# ======================================================================== vfx
func puff(pos: Vector3, col: Color, amount: int) -> void:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 0.8
	p.direction = Vector3(0, 1, 0)
	p.spread = 70.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -6.0, 0)
	p.scale_amount_min = 0.1
	p.scale_amount_max = 0.35
	p.color = col
	p.mesh = CxUtil.sph(0.5)
	p.position = pos
	add_child(p)
	p.emitting = true
	var tm := get_tree().create_timer(1.6)
	tm.timeout.connect(p.queue_free)


func float_text(pos: Vector3, text: String, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 72
	l.outline_size = 16
	l.pixel_size = 0.011
	l.modulate = col
	l.outline_modulate = Color(0.05, 0.03, 0.02, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos
	add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position", pos + Vector3(0, 2.4, 0), 1.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.0)
	tw.set_parallel(false)
	tw.tween_callback(l.queue_free)


func toast(text: String) -> void:
	hud.toast(text)


# ====================================================================== audio
func sfx_step() -> void:
	if _step_gate > 0.0:
		return
	_step_gate = 0.07
	GameAudio.play(sfx_step_a)


func sfx_hit() -> void:
	GameAudio.play(sfx_hit_a)


func sfx_pickup() -> void:
	GameAudio.play(sfx_pick_a)


func sfx_click() -> void:
	GameAudio.play(sfx_click_a)


func sfx_alert() -> void:
	GameAudio.play(sfx_alert_a)


# ======================================================================== hud
func weather_name() -> String:
	if phase == 1:
		return "CLEAR BASIN"
	elif phase == 2:
		return "AMBER HAZE"
	return "EMBER RAIN"


func phase_name() -> String:
	if phase == 1:
		return "AMBER SURVEY"
	elif phase == 2:
		return "DUST CLOSES IN"
	return "THE BASIN BURNS"


func log_lines() -> Array:
	var out: Array = []
	var m1 := "[x]" if traces_read > 0 else "[ ]"
	out.append("%s Read a creature trace (%d/6)" % [m1, traces_read])
	var m2 := "[x]" if evidence >= 3 else "[ ]"
	out.append("%s Document 3 evidence sets (%d/3)" % [m2, evidence])
	var m3 := "[x]" if camp_hp > 0.0 else "[ ]"
	out.append("%s Keep the survey camp standing (%d%%)" % [m3, int(camp_hp)])
	if evidence >= 3:
		out.append("[ ] Bind the Atlas at the north forge")
	else:
		out.append("[ ] Forge sealed until the Atlas is full")
	return out
