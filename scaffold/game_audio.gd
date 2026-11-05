extends Node
## Web-safe SFX. Browsers block audio until the first user gesture, and web export
## uses Sample playback (AudioEffects / reverb / procedural audio do NOT work).
## Usage:
##   GameAudio.unlock()                       # call once on first tap/key
##   GameAudio.play(preload("res://hit.wav")) # fire-and-forget one-shot

const POOL_SIZE := 8
var _players: Array[AudioStreamPlayer] = []
var _unlocked := false

func _ready() -> void:
    for _i in POOL_SIZE:
        var p := AudioStreamPlayer.new()
        add_child(p)
        _players.append(p)

func unlock() -> void:
    _unlocked = true

func play(stream: AudioStream, volume_db: float = 0.0) -> void:
    if stream == null:
        return
    for p in _players:
        if not p.playing:
            p.stream = stream
            p.volume_db = volume_db
            p.play()
            return
    _players[0].stream = stream
    _players[0].volume_db = volume_db
    _players[0].play()
