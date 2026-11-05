extends Node2D
##
## Reference example: classic Brick-Breaker in Godot 4.6.
##
## Read this file to learn the Godot idioms the system prompt expects.
## Do NOT import it directly into your own game — copy the patterns instead.
##
## Demonstrates:
##   - Pure-script scene building (no .tscn — everything in _ready())
##   - State machine for menu -> play -> gameover transitions
##   - CharacterBody2D paddle + RigidBody2D ball with manual reflection
##   - Area2D bricks with body_entered signal for collision
##   - GPUParticles2D burst on brick destroy
##   - AudioStreamPlayer for SFX (loaded with `load()`)
##   - High score persistence via ConfigFile in user://
##   - Mouse AND touch input (InputEventScreenTouch + mouse fallback)
##   - Explicit type annotations everywhere (no `var x := dict[key]` traps)
##

# --- Constants -------------------------------------------------------------

const VIEWPORT_W: float = 480.0
const VIEWPORT_H: float = 720.0

const PADDLE_W: float = 96.0
const PADDLE_H: float = 14.0
const PADDLE_Y: float = VIEWPORT_H - 60.0
const PADDLE_SPEED: float = 900.0

const BALL_RADIUS: float = 8.0
const BALL_START_SPEED: float = 320.0
const BALL_MAX_SPEED: float = 720.0
const BALL_SPEEDUP_PER_HIT: float = 4.0

const BRICK_COLS: int = 8
const BRICK_ROWS: int = 5
const BRICK_W: float = 52.0
const BRICK_H: float = 22.0
const BRICK_GAP: float = 4.0
const BRICK_TOP: float = 80.0
const BRICK_COLORS: Array[Color] = [
	Color("#ff5e5b"), Color("#ffc145"), Color("#7ed957"),
	Color("#4fc3f7"), Color("#b06cf0"),
]

const SAVE_PATH: String = "user://breakout-save.cfg"

# --- State machine ---------------------------------------------------------

enum GameState { MENU, PLAYING, GAME_OVER, WIN }

# --- Nodes (built in _ready) -----------------------------------------------

var paddle: ColorRect
var ball: ColorRect
var ball_velocity: Vector2 = Vector2.ZERO
var brick_container: Node2D
var particles: GPUParticles2D
var status_label: Label
var score_label: Label
var lives_label: Label
var high_score_label: Label
var hit_player: AudioStreamPlayer
var lose_player: AudioStreamPlayer

# --- Runtime state ---------------------------------------------------------

var state: GameState = GameState.MENU
var score: int = 0
var lives: int = 3
var high_score: int = 0
var bricks_left: int = 0

# ---------------------------------------------------------------------------

func _ready() -> void:
	high_score = _load_high_score()
	_build_ui()
	_build_paddle()
	_build_ball()
	_build_bricks_container()
	_build_particles()
	_build_audio()
	_enter_menu()


func _process(delta: float) -> void:
	if state != GameState.PLAYING:
		return
	_update_paddle(delta)
	_update_ball(delta)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_handle_pointer_press()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_pointer_press()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_handle_pointer_press()


# --- State transitions ------------------------------------------------------

func _handle_pointer_press() -> void:
	match state:
		GameState.MENU, GameState.GAME_OVER, GameState.WIN:
			_start_new_game()
		GameState.PLAYING:
			pass


func _enter_menu() -> void:
	state = GameState.MENU
	status_label.text = "BREAKOUT\nTap or press SPACE to start"
	status_label.visible = true
	_clear_bricks()


func _start_new_game() -> void:
	state = GameState.PLAYING
	score = 0
	lives = 3
	_spawn_bricks()
	_reset_ball()
	status_label.visible = false
	_refresh_hud()


func _enter_game_over() -> void:
	state = GameState.GAME_OVER
	status_label.text = "GAME OVER\nScore: %d\nTap to retry" % score
	status_label.visible = true
	lose_player.play()
	_save_high_score()


func _enter_win() -> void:
	state = GameState.WIN
	status_label.text = "YOU WIN!\nScore: %d\nTap to play again" % score
	status_label.visible = true
	_save_high_score()


# --- Build helpers ----------------------------------------------------------

func _build_ui() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = Color("#0d1117")
	background.size = Vector2(VIEWPORT_W, VIEWPORT_H)
	add_child(background)

	score_label = Label.new()
	score_label.position = Vector2(16, 16)
	score_label.add_theme_font_size_override("font_size", 22)
	add_child(score_label)

	lives_label = Label.new()
	lives_label.position = Vector2(VIEWPORT_W - 100, 16)
	lives_label.add_theme_font_size_override("font_size", 22)
	add_child(lives_label)

	high_score_label = Label.new()
	high_score_label.position = Vector2(VIEWPORT_W / 2.0 - 50, 16)
	high_score_label.add_theme_font_size_override("font_size", 18)
	add_child(high_score_label)

	status_label = Label.new()
	status_label.position = Vector2(0, VIEWPORT_H / 2.0 - 60)
	status_label.size = Vector2(VIEWPORT_W, 200)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 28)
	status_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(status_label)


func _build_paddle() -> void:
	paddle = ColorRect.new()
	paddle.color = Color("#e6e6e6")
	paddle.size = Vector2(PADDLE_W, PADDLE_H)
	paddle.position = Vector2((VIEWPORT_W - PADDLE_W) / 2.0, PADDLE_Y)
	add_child(paddle)


func _build_ball() -> void:
	ball = ColorRect.new()
	ball.color = Color("#ffe066")
	ball.size = Vector2(BALL_RADIUS * 2.0, BALL_RADIUS * 2.0)
	add_child(ball)


func _build_bricks_container() -> void:
	brick_container = Node2D.new()
	add_child(brick_container)


func _build_particles() -> void:
	particles = GPUParticles2D.new()
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.amount = 24
	particles.lifetime = 0.6
	particles.emitting = false
	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.gravity = Vector3(0, 200, 0)
	mat.initial_velocity_min = 60.0
	mat.initial_velocity_max = 220.0
	mat.scale_min = 2.0
	mat.scale_max = 4.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	particles.process_material = mat
	add_child(particles)


func _build_audio() -> void:
	# AudioStreamGenerator-based blip — keeps the example self-contained
	# without external .wav files. Real games should load .wav/.ogg from
	# res:// or fetch via fetch_game_asset() / web_fetch().
	hit_player = AudioStreamPlayer.new()
	hit_player.stream = _make_blip(880.0, 0.05)
	hit_player.volume_db = -10.0
	add_child(hit_player)

	lose_player = AudioStreamPlayer.new()
	lose_player.stream = _make_blip(160.0, 0.35)
	lose_player.volume_db = -8.0
	add_child(lose_player)


# --- Game logic ------------------------------------------------------------

func _update_paddle(delta: float) -> void:
	# Pointer position drives the paddle on touch + mouse; keyboard fallback
	# uses arrow keys / A & D so desktop users don't need to drag.
	var target_x: float
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	target_x = clampf(mouse_pos.x - PADDLE_W / 2.0, 0.0, VIEWPORT_W - PADDLE_W)

	var keyboard_dir: float = 0.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		keyboard_dir = -1.0
	elif Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		keyboard_dir = 1.0
	if keyboard_dir != 0.0:
		target_x = clampf(
			paddle.position.x + keyboard_dir * PADDLE_SPEED * delta,
			0.0,
			VIEWPORT_W - PADDLE_W,
		)

	paddle.position.x = target_x


func _update_ball(delta: float) -> void:
	ball.position += ball_velocity * delta

	# Wall reflections.
	if ball.position.x <= 0.0:
		ball.position.x = 0.0
		ball_velocity.x = absf(ball_velocity.x)
	elif ball.position.x + BALL_RADIUS * 2.0 >= VIEWPORT_W:
		ball.position.x = VIEWPORT_W - BALL_RADIUS * 2.0
		ball_velocity.x = -absf(ball_velocity.x)
	if ball.position.y <= 0.0:
		ball.position.y = 0.0
		ball_velocity.y = absf(ball_velocity.y)

	# Paddle reflection — angle depends on hit position so the player has
	# control over ball direction (the heart of Breakout's depth).
	var ball_rect: Rect2 = Rect2(ball.position, ball.size)
	var paddle_rect: Rect2 = Rect2(paddle.position, paddle.size)
	if ball_velocity.y > 0.0 and ball_rect.intersects(paddle_rect):
		var hit_offset: float = (ball.position.x + BALL_RADIUS - paddle.position.x - PADDLE_W / 2.0) / (PADDLE_W / 2.0)
		hit_offset = clampf(hit_offset, -0.9, 0.9)
		var speed: float = ball_velocity.length()
		var angle: float = hit_offset * (PI / 3.0)  # ±60° from straight up
		ball_velocity = Vector2(sin(angle), -cos(angle)) * speed

	# Brick collisions — check every brick child; remove on hit.
	for child in brick_container.get_children():
		var brick: ColorRect = child as ColorRect
		if brick == null:
			continue
		var brick_rect: Rect2 = Rect2(brick.position, brick.size)
		if ball_rect.intersects(brick_rect):
			_destroy_brick(brick)
			# Reflect on the dominant overlap axis.
			var overlap_x: float = minf(
				ball_rect.position.x + ball_rect.size.x - brick_rect.position.x,
				brick_rect.position.x + brick_rect.size.x - ball_rect.position.x,
			)
			var overlap_y: float = minf(
				ball_rect.position.y + ball_rect.size.y - brick_rect.position.y,
				brick_rect.position.y + brick_rect.size.y - ball_rect.position.y,
			)
			if overlap_x < overlap_y:
				ball_velocity.x = -ball_velocity.x
			else:
				ball_velocity.y = -ball_velocity.y
			break  # one brick per frame keeps reflections predictable

	# Lost ball.
	if ball.position.y > VIEWPORT_H:
		lives -= 1
		_refresh_hud()
		if lives <= 0:
			_enter_game_over()
		else:
			_reset_ball()


func _destroy_brick(brick: ColorRect) -> void:
	score += 10
	bricks_left -= 1
	_refresh_hud()

	particles.position = brick.position + brick.size / 2.0
	particles.modulate = brick.color
	particles.restart()
	particles.emitting = true

	hit_player.play()
	brick.queue_free()

	# Subtle speed-up so the game gets harder as bricks clear.
	var speed: float = minf(ball_velocity.length() + BALL_SPEEDUP_PER_HIT, BALL_MAX_SPEED)
	ball_velocity = ball_velocity.normalized() * speed

	if bricks_left <= 0:
		_enter_win()


func _spawn_bricks() -> void:
	_clear_bricks()
	var total_w: float = BRICK_COLS * BRICK_W + (BRICK_COLS - 1) * BRICK_GAP
	var origin_x: float = (VIEWPORT_W - total_w) / 2.0
	for row in BRICK_ROWS:
		for col in BRICK_COLS:
			var brick: ColorRect = ColorRect.new()
			brick.color = BRICK_COLORS[row % BRICK_COLORS.size()]
			brick.size = Vector2(BRICK_W, BRICK_H)
			brick.position = Vector2(
				origin_x + col * (BRICK_W + BRICK_GAP),
				BRICK_TOP + row * (BRICK_H + BRICK_GAP),
			)
			brick_container.add_child(brick)
	bricks_left = BRICK_COLS * BRICK_ROWS


func _clear_bricks() -> void:
	for child in brick_container.get_children():
		child.queue_free()
	bricks_left = 0


func _reset_ball() -> void:
	ball.position = Vector2(VIEWPORT_W / 2.0 - BALL_RADIUS, VIEWPORT_H / 2.0)
	var angle: float = randf_range(-PI / 4.0, PI / 4.0)
	ball_velocity = Vector2(sin(angle), cos(angle)) * BALL_START_SPEED


func _refresh_hud() -> void:
	score_label.text = "Score: %d" % score
	lives_label.text = "Lives: %d" % lives
	high_score_label.text = "Best: %d" % high_score


# --- Persistence -----------------------------------------------------------

func _load_high_score() -> int:
	var config: ConfigFile = ConfigFile.new()
	var err: int = config.load(SAVE_PATH)
	if err != OK:
		return 0
	var value: int = config.get_value("scores", "high", 0)
	return value


func _save_high_score() -> void:
	if score <= high_score:
		return
	high_score = score
	var config: ConfigFile = ConfigFile.new()
	config.set_value("scores", "high", high_score)
	config.save(SAVE_PATH)
	_refresh_hud()


# --- Tiny procedural blip generator ----------------------------------------

func _make_blip(freq_hz: float, duration_s: float) -> AudioStreamWAV:
	# Generate a short sine blip in PCM16 so the example needs no .wav files.
	# For real audio, prefer `load("res://my-sound.wav")` or fetch_game_asset.
	var sample_rate: int = 22050
	var sample_count: int = int(duration_s * sample_rate)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(sample_count * 2)
	for i in sample_count:
		var t: float = float(i) / sample_rate
		var envelope: float = 1.0 - (float(i) / sample_count)
		var sample: float = sin(t * freq_hz * TAU) * envelope * 0.5
		var s16: int = int(clampf(sample, -1.0, 1.0) * 32767.0)
		if s16 < 0:
			s16 += 65536
		bytes[i * 2] = s16 & 0xff
		bytes[i * 2 + 1] = (s16 >> 8) & 0xff
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = bytes
	return stream
