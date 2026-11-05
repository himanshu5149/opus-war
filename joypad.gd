extends Control
class_name CxJoypad
## Touch virtual stick. Returns a normalised Vector2 (+x right, +y down).

var value := Vector2.ZERO
var _active_id := -1
var _knob := Vector2.ZERO
var radius := 64.0

func _ready() -> void:
	custom_minimum_size = Vector2(176, 176)
	size = Vector2(176, 176)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	var c := size * 0.5
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed and _active_id == -1:
			_active_id = e.index
			_update(e.position - c)
		elif not e.pressed and e.index == _active_id:
			_release()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _active_id:
			_update(d.position - c)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_active_id = -2
				_update(mb.position - c)
			else:
				_release()
	elif event is InputEventMouseMotion and _active_id == -2:
		var mm := event as InputEventMouseMotion
		_update(mm.position - c)


func _update(off: Vector2) -> void:
	var l := off.length()
	if l > radius:
		off = off / l * radius
	_knob = off
	value = off / radius
	queue_redraw()


func _release() -> void:
	_active_id = -1
	_knob = Vector2.ZERO
	value = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	draw_circle(c, radius + 12.0, Color(0.08, 0.05, 0.03, 0.34))
	draw_arc(c, radius + 12.0, 0.0, TAU, 48, Color(0.75, 0.55, 0.30, 0.55), 3.0, true)
	draw_arc(c, radius * 0.45, 0.0, TAU, 32, Color(0.75, 0.55, 0.30, 0.25), 2.0, true)
	draw_circle(c + _knob, 30.0, Color(0.25, 0.88, 0.78, 0.55))
	draw_arc(c + _knob, 30.0, 0.0, TAU, 32, Color(0.35, 0.95, 0.85, 0.9), 2.5, true)
