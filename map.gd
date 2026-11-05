extends Control
class_name CxMap
## Hand-drawn survey map of the basin.

var game

func _draw() -> void:
	if game == null:
		return
	var s := size
	var c := s * 0.5
	var r: float = min(s.x, s.y) * 0.46
	var k: float = r / 78.0

	draw_circle(c, r + 10.0, Color(0.16, 0.12, 0.10, 0.95))
	draw_circle(c, r, Color(0.78, 0.63, 0.40, 0.95))
	draw_arc(c, r, 0.0, TAU, 96, Color(0.30, 0.22, 0.18, 1.0), 5.0, true)
	for i in range(7):
		var a := TAU * float(i) / 7.0
		var p1 := c + Vector2(cos(a), sin(a)) * r * 0.25
		var p2 := c + Vector2(cos(a + 0.5), sin(a + 0.5)) * r * 0.92
		draw_line(p1, p2, Color(0.86, 0.76, 0.56, 0.7), 2.0)
	draw_arc(c, r * 0.55, 0.0, TAU, 64, Color(0.70, 0.55, 0.34, 0.8), 2.0, true)

	var w2m := func(v: Vector3) -> Vector2:
		return c + Vector2(v.x, v.z) * k

	for h in game.herbs:
		if is_instance_valid(h):
			var hp2: Vector2 = w2m.call(h.global_position)
			draw_circle(hp2, 3.0, Color(0.55, 0.92, 0.55, 0.9))

	for t in game.traces:
		var p: Vector2 = w2m.call(t["pos"])
		var col := Color(0.95, 0.62, 0.20)
		if t["read"]:
			col = Color(0.25, 0.88, 0.78)
		draw_arc(p, 9.0, 0.0, TAU, 20, col, 3.0, true)
		if not t["read"]:
			draw_circle(p, 3.5, col)

	for sh in game.shards:
		if is_instance_valid(sh):
			var sp: Vector2 = w2m.call(sh.global_position)
			draw_circle(sp, 6.0, Color(1.0, 0.78, 0.25, 0.95))

	var cp: Vector2 = w2m.call(game.camp_pos)
	draw_rect(Rect2(cp - Vector2(9, 9), Vector2(18, 18)), Color(0.25, 0.88, 0.78, 0.9))
	draw_rect(Rect2(cp - Vector2(9, 9), Vector2(18, 18)), Color(0.08, 0.20, 0.18), false, 2.0)

	var fp: Vector2 = w2m.call(game.forge_pos)
	var fcol := Color(0.45, 0.35, 0.28)
	if game.evidence >= 3:
		fcol = Color(1.0, 0.55, 0.12)
	var tri := PackedVector2Array([fp + Vector2(0, -13), fp + Vector2(11, 9), fp + Vector2(-11, 9)])
	draw_colored_polygon(tri, fcol)

	if is_instance_valid(game.creature):
		var gp: Vector3 = game.creature.global_position
		var near := false
		if game.player != null:
			near = gp.distance_to(game.player.global_position) < 45.0
		if near or game.creature_reveal > 0.0:
			var mp: Vector2 = w2m.call(gp)
			draw_circle(mp, 10.0, Color(1.0, 0.36, 0.10, 0.85))
			draw_arc(mp, 16.0, 0.0, TAU, 24, Color(1.0, 0.45, 0.15, 0.6), 2.0, true)

	if game.player != null:
		var pp: Vector2 = w2m.call(game.player.global_position)
		var ang: float = -game.player.face_yaw - PI * 0.5
		var d1 := Vector2(cos(ang), sin(ang))
		var d2 := Vector2(-d1.y, d1.x)
		var ptri := PackedVector2Array([pp + d1 * 13.0, pp - d1 * 7.0 + d2 * 8.0, pp - d1 * 7.0 - d2 * 8.0])
		draw_colored_polygon(ptri, Color(0.25, 0.95, 0.85))
		draw_arc(pp, 26.0, 0.0, TAU, 28, Color(0.25, 0.95, 0.85, 0.35), 2.0, true)
