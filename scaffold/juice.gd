class_name Juice
## Static juice helpers. Examples:
##   Juice.pop($Sprite2D)
##   Juice.shake($Camera2D, 6.0, 0.25)

static func pop(node: Node, to_scale: float = 1.2, time: float = 0.12) -> void:
    if node == null or not (node is Node2D or node is Control):
        return
    var base = node.scale
    var tw := node.create_tween()
    tw.tween_property(node, "scale", base * to_scale, time * 0.5)
    tw.tween_property(node, "scale", base, time * 0.5)

static func shake(cam: Camera2D, amount: float = 6.0, time: float = 0.25) -> void:
    if cam == null:
        return
    var origin := cam.offset
    var tw := cam.create_tween()
    var steps := 6
    for i in steps:
        var off := Vector2(randf_range(-amount, amount), randf_range(-amount, amount))
        tw.tween_property(cam, "offset", origin + off, time / steps)
    tw.tween_property(cam, "offset", origin, time / steps)
