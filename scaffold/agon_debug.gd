extends Node
## Harness-only preview bridge. No gameplay effect. Add your player to the
## "player" group (add_to_group("player")) to enable the controls check.

var _accum := 0.0

func _process(delta: float) -> void:
    if not OS.has_feature("web"):
        return
    if not Engine.has_singleton("JavaScriptBridge"):
        return
    _accum += delta
    if _accum < 0.25:
        return
    _accum = 0.0
    var jsb = Engine.get_singleton("JavaScriptBridge")
    var payload := JSON.stringify(_snapshot())
    jsb.eval("window.__agon_last_debug=" + payload + ";window.__agon_debug=function(){return window.__agon_last_debug;};", true)

func _snapshot() -> Dictionary:
    var data := {}
    var tree := get_tree()
    if tree == null or tree.root == null:
        return data
    var size := tree.root.get_visible_rect().size
    data["viewport"] = {"w": size.x, "h": size.y}

    var players := tree.get_nodes_in_group("player")
    if players.size() > 0:
        var pos = _screen_pos(players[0])
        if pos != null:
            data["player"] = {"x": pos.x, "y": pos.y}

    var nodes := []
    _collect(tree.root, nodes)
    data["nodes"] = nodes

    # State signature for the playtest responsiveness check: a cheap value that
    # shifts whenever the game reacts to input (nodes spawn/despawn, the player
    # or UI moves). If this is identical before and after a scripted input burst,
    # the game is dead/frozen. Bounded work: node count + already-collected rects
    # + player position.
    var sig := float(tree.get_node_count())
    for n in nodes:
        sig += float(n["x"]) + float(n["y"])
    if data.has("player"):
        sig += float(data["player"]["x"]) + float(data["player"]["y"])
    data["node_count"] = tree.get_node_count()
    data["sig"] = sig
    return data

func _screen_pos(node):
    if node is Control:
        var r: Rect2 = node.get_global_rect()
        return r.position + r.size * 0.5
    if node is Node2D:
        return node.get_global_transform_with_canvas().origin
    return null

func _collect(node: Node, out: Array) -> void:
    if out.size() >= 24:
        return
    for child in node.get_children():
        if child is Control and child.visible and child.size.x > 1.0 and child.size.y > 1.0:
            var r: Rect2 = child.get_global_rect()
            out.append({
                "name": child.name, "kind": "control",
                "x": r.position.x, "y": r.position.y, "w": r.size.x, "h": r.size.y,
                "visible": true,
            })
        _collect(child, out)
