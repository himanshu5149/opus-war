extends Node
## Standard input actions for every game. Use these instead of raw keycodes so
## controls are consistent and directions are never inverted:
##   var dir := Vector2(
##       Input.get_axis("move_left", "move_right"),
##       Input.get_axis("move_up", "move_down"))  # +x = right, +y = down (screen)
## Also available: "jump", "action" (space/enter/left-click), "pause".

const _ACTIONS := {
    "move_left": [KEY_A, KEY_LEFT],
    "move_right": [KEY_D, KEY_RIGHT],
    "move_up": [KEY_W, KEY_UP],
    "move_down": [KEY_S, KEY_DOWN],
    "jump": [KEY_SPACE],
    "action": [KEY_ENTER, KEY_SPACE],
    "pause": [KEY_ESCAPE],
}

func _ready() -> void:
    for action_name in _ACTIONS:
        if not InputMap.has_action(action_name):
            InputMap.add_action(action_name)
        for keycode in _ACTIONS[action_name]:
            var ev := InputEventKey.new()
            ev.physical_keycode = keycode
            InputMap.action_add_event(action_name, ev)
    var mb := InputEventMouseButton.new()
    mb.button_index = MOUSE_BUTTON_LEFT
    InputMap.action_add_event("action", mb)
