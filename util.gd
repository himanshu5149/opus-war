extends RefCounted
class_name CxUtil
## Shared construction helpers for meshes and materials.

static func mat(col: Color, rough: float = 0.85, metal: float = 0.0, emis: Color = Color.BLACK, emis_e: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	if emis_e > 0.0:
		m.emission_enabled = true
		m.emission = emis
		m.emission_energy_multiplier = emis_e
	return m


static func tex_mat(path: String, col: Color, rough: float = 0.9, uv: Vector3 = Vector3(1, 1, 0)) -> StandardMaterial3D:
	var m := mat(col, rough)
	var t: Texture2D = load(path)
	m.albedo_texture = t
	m.uv1_scale = uv
	return m


static func glow_mat(col: Color, energy: float = 2.0) -> StandardMaterial3D:
	return mat(col, 0.4, 0.0, col, energy)


static func box(sx: float, sy: float, sz: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(sx, sy, sz)
	return b


static func cyl(rt: float, rb: float, h: float, seg: int = 12) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = seg
	return c


static func sph(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 16
	s.rings = 10
	return s


static func mi(mesh: Mesh, m: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = m
	n.position = pos
	return n


## Yaw angle so that a node's -Z axis points along `dir` (xz plane).
static func yaw_to(dir: Vector3) -> float:
	if dir.length_squared() < 0.0001:
		return 0.0
	return atan2(-dir.x, -dir.z)


static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
