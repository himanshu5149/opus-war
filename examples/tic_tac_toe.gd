extends Control
##
## Reference example: Tic-Tac-Toe in Godot 4.6.
##
## A shorter, simpler companion to breakout.gd. Showcases:
##   - Control / Button UI tree built procedurally in _ready()
##   - signal -> Callable wiring with `.connect()` (Godot 4 idiom)
##   - Lambdas with bind() for parameterised callbacks
##   - Explicit type annotations on collections (`Array[Button]`)
##   - Pure functions for win detection (easy to unit-test if you port to GUT)
##
## Read this to learn idiomatic Godot UI + signal patterns. Do not import
## this file directly into your own game.
##

# --- Constants -------------------------------------------------------------

const BOARD_SIZE: int = 3
const CELL_PX: float = 130.0
const CELL_GAP: float = 8.0
const FONT_SIZE_CELL: int = 84
const FONT_SIZE_STATUS: int = 28

const WIN_LINES: Array = [
	# Rows
	[0, 1, 2], [3, 4, 5], [6, 7, 8],
	# Columns
	[0, 3, 6], [1, 4, 7], [2, 5, 8],
	# Diagonals
	[0, 4, 8], [2, 4, 6],
]

enum Mark { EMPTY, X, O }

# --- State ------------------------------------------------------------------

var cells: Array[Button] = []
var board: Array[Mark] = []
var current_player: Mark = Mark.X
var game_over: bool = false
var status_label: Label
var reset_button: Button

# ---------------------------------------------------------------------------

func _ready() -> void:
	# Reserve space for nine cells. `resize` initializes each slot to EMPTY.
	board.resize(BOARD_SIZE * BOARD_SIZE)
	board.fill(Mark.EMPTY)

	_build_ui()
	_refresh()


func _build_ui() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = Color("#1c1f26")
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	add_child(background)

	var root: VBoxContainer = VBoxContainer.new()
	root.anchor_left = 0.5
	root.anchor_right = 0.5
	root.anchor_top = 0.5
	root.anchor_bottom = 0.5
	root.add_theme_constant_override("separation", 20)
	add_child(root)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", FONT_SIZE_STATUS)
	status_label.add_theme_color_override("font_color", Color.WHITE)
	root.add_child(status_label)

	var grid: GridContainer = GridContainer.new()
	grid.columns = BOARD_SIZE
	grid.add_theme_constant_override("h_separation", int(CELL_GAP))
	grid.add_theme_constant_override("v_separation", int(CELL_GAP))
	root.add_child(grid)

	for index in BOARD_SIZE * BOARD_SIZE:
		var cell: Button = Button.new()
		cell.custom_minimum_size = Vector2(CELL_PX, CELL_PX)
		cell.add_theme_font_size_override("font_size", FONT_SIZE_CELL)
		# `bind(index)` curries the index into the callback so we can reuse a
		# single signal handler across all 9 buttons.
		cell.pressed.connect(_on_cell_pressed.bind(index))
		grid.add_child(cell)
		cells.append(cell)

	reset_button = Button.new()
	reset_button.text = "New Game"
	reset_button.add_theme_font_size_override("font_size", 22)
	reset_button.pressed.connect(_reset)
	root.add_child(reset_button)

	# Anchor the VBox so it stays centred regardless of viewport size.
	root.position = Vector2(
		-_estimate_root_width(grid) / 2.0,
		-_estimate_root_height(grid) / 2.0,
	)


# Approximate width/height for centering (called once at startup).
func _estimate_root_width(grid: GridContainer) -> float:
	return BOARD_SIZE * CELL_PX + (BOARD_SIZE - 1) * CELL_GAP


func _estimate_root_height(grid: GridContainer) -> float:
	var grid_h: float = BOARD_SIZE * CELL_PX + (BOARD_SIZE - 1) * CELL_GAP
	return grid_h + 120.0  # plus status label + reset button


# --- Gameplay ---------------------------------------------------------------

func _on_cell_pressed(index: int) -> void:
	if game_over:
		return
	if board[index] != Mark.EMPTY:
		return
	board[index] = current_player

	var winner: int = _winner(board)
	if winner != Mark.EMPTY:
		game_over = true
		status_label.text = "%s wins!" % _mark_label(winner)
	elif _is_full(board):
		game_over = true
		status_label.text = "Draw."
	else:
		current_player = Mark.O if current_player == Mark.X else Mark.X

	_refresh()


func _reset() -> void:
	board.fill(Mark.EMPTY)
	current_player = Mark.X
	game_over = false
	_refresh()


# --- Pure helpers (no node access — easy to test) ---------------------------

static func _winner(b: Array) -> int:
	for line in WIN_LINES:
		var a: int = b[line[0]]
		if a == Mark.EMPTY:
			continue
		if b[line[1]] == a and b[line[2]] == a:
			return a
	return Mark.EMPTY


static func _is_full(b: Array) -> bool:
	for cell in b:
		if cell == Mark.EMPTY:
			return false
	return true


# --- Rendering --------------------------------------------------------------

func _refresh() -> void:
	for i in cells.size():
		cells[i].text = _mark_label(board[i])
	if not game_over:
		status_label.text = "%s to move" % _mark_label(current_player)


func _mark_label(mark: Mark) -> String:
	match mark:
		Mark.X:
			return "X"
		Mark.O:
			return "O"
		_:
			return ""
