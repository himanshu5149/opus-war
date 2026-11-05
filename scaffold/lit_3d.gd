class_name Lit3D
## Call once from a 3D scene root so meshes are lit (flat/black 3D is almost
## always missing a light + environment):
##   func _ready() -> void:
##       Lit3D.setup(self)

static func setup(parent: Node) -> void:
    if parent == null:
        return
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.53, 0.62, 0.74)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.45, 0.45, 0.5)
    env.ambient_light_energy = 1.0
    var we := WorldEnvironment.new()
    we.environment = env
    parent.add_child(we)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-50, -40, 0)
    sun.shadow_enabled = true
    parent.add_child(sun)
