extends Node2D

@export var cell_scene: PackedScene
@export var row_count: int = 45
@export var col_count: int = 80
@export var cell_width: int = 15
@export var simulation_speed: float = 0.2  # seconds per generation

var cell_matrix: Array = []
var cell_matrix_previous: Array = []

var simulation_timer: float = 0.0
var is_paused: bool = false
var generation_count: int = 0
var show_grid: bool = false
var wrap_edges: bool = false

# Colors for cell states
var alive_color: Color = Color(1, 1, 1)
var dead_color: Color = Color(0, 0, 0)

# UI Elements
var canvas_layer: CanvasLayer
var generation_label: Label
var live_count_label: Label

func _ready():
	# Create UI layer
	canvas_layer = CanvasLayer.new()
	add_child(canvas_layer)
	
	# Create generation label
	generation_label = Label.new()
	generation_label.position = Vector2(10, 10)
	canvas_layer.add_child(generation_label)
	
	# Create live count label
	live_count_label = Label.new()
	live_count_label.position = Vector2(10, 30)
	canvas_layer.add_child(live_count_label)
	
	# Initialize the cell grid
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	for column in range(col_count):
		cell_matrix.append([])
		cell_matrix_previous.append([])
		for row in range(row_count):
			var cell = cell_scene.instantiate()
			add_child(cell)
			cell.position = Vector2(column * cell_width, row * cell_width)
			# Randomly initialize cell state; force edges to be dead
			if (rng.randi_range(0, 1) == 1 or is_edge(column, row)):
				cell.modulate = dead_color
				cell_matrix_previous[column].append(false)
			else:
				cell.modulate = alive_color
				cell_matrix_previous[column].append(true)
			cell_matrix[column].append(cell)
	update_ui_text()  # Initial UI update

func _process(delta):
	if is_paused:
		return
	
	# Update simulation only after simulation_speed seconds have passed
	simulation_timer += delta
	if simulation_timer >= simulation_speed:
		simulation_timer = 0.0
		
		# Copy current cell states for computation
		for column in range(col_count):
			for row in range(row_count):
				cell_matrix_previous[column][row] = (cell_matrix[column][row].modulate == alive_color)
		
		# Update each cell based on its neighbors
		for column in range(col_count):
			for row in range(row_count):
				# Process the cell if it's not an edge or if wrap-around is enabled
				if not is_edge(column, row) or wrap_edges:
					var next_state = get_next_state(column, row)
					var cell = cell_matrix[column][row]
					var current_state = cell_matrix_previous[column][row]
					if current_state != next_state:
						animate_cell_transition(cell, next_state)
					else:
						cell.modulate = alive_color if next_state else dead_color
						
		generation_count += 1
		update_ui_text()  # Update UI text
		queue_redraw()  # refresh grid

func animate_cell_transition(cell, next_state: bool):
	# Animate the cell color transition using a Tween
	var target_color = alive_color if next_state else dead_color
	var tween = get_tree().create_tween()
	tween.tween_property(cell, "modulate", target_color, simulation_speed)

func is_edge(column, row):
	return column == 0 or column == col_count - 1 or row == 0 or row == row_count - 1

func get_count_of_live_neighbors(column, row):
	var count = 0
	for x in range(-1, 2):
		for y in range(-1, 2):
			if x == 0 and y == 0:
				continue
			var neighbor_column = column + x
			var neighbor_row = row + y
			if wrap_edges:
				neighbor_column = (neighbor_column + col_count) % col_count
				neighbor_row = (neighbor_row + row_count) % row_count
			else:
				if neighbor_column < 0 or neighbor_column >= col_count or neighbor_row < 0 or neighbor_row >= row_count:
					continue
			if cell_matrix_previous[neighbor_column][neighbor_row]:
				count += 1
	return count

func get_next_state(column, row):
	var current = cell_matrix_previous[column][row]
	var neighbours_alive = get_count_of_live_neighbors(column, row)
	if current:
		# Underpopulation or overpopulation
		if neighbours_alive < 2 or neighbours_alive > 3:
			return false
	else:
		# Reproduction
		if neighbours_alive == 3:
			return true
	return current

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.scancode:
			KEY_SPACE:
				is_paused = !is_paused  # Toggle pause/resume
			KEY_R:
				reset_board()         # Reset board state
			KEY_G:
				show_grid = !show_grid  # Toggle grid display
				queue_redraw()
			KEY_W:
				wrap_edges = !wrap_edges  # Toggle wrap-around neighbor counting
			KEY_EQUAL:  # Changed from KEY_PLUS
				simulation_speed = max(0.05, simulation_speed - 0.05)
			KEY_MINUS:
				simulation_speed += 0.05
	if event is InputEventMouseButton and event.pressed:
		# Toggle cell state on mouse click
		var pos = event.position
		var col = int(pos.x / cell_width)
		var row = int(pos.y / cell_width)
		if col >= 0 and col < col_count and row >= 0 and row < row_count:
			var cell = cell_matrix[col][row]
			var new_state = !cell_matrix_previous[col][row]
			cell_matrix_previous[col][row] = new_state
			animate_cell_transition(cell, new_state)

func reset_board():
	# Reinitialize the board with a new random state
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	for column in range(col_count):
		for row in range(row_count):
			var cell = cell_matrix[column][row]
			if (rng.randi_range(0, 1) == 1 or is_edge(column, row)):
				cell_matrix_previous[column][row] = false
				cell.modulate = dead_color
			else:
				cell_matrix_previous[column][row] = true
				cell.modulate = alive_color
	generation_count = 0
	update_ui_text()  # Update UI text
	queue_redraw()

func update_ui_text():
	var live_count = 0
	for column in range(col_count):
		for row in range(row_count):
			if cell_matrix_previous[column][row]:
				live_count += 1
	
	generation_label.text = "Generation: " + str(generation_count)
	live_count_label.text = "Live Cells: " + str(live_count)

func _draw():
	# Draw grid lines if toggled on.
	if show_grid:
		for column in range(col_count + 1):
			draw_line(Vector2(column * cell_width, 0), Vector2(column * cell_width, row_count * cell_width), Color(0.5, 0.5, 0.5))
		for row in range(row_count + 1):
			draw_line(Vector2(0, row * cell_width), Vector2(col_count * cell_width, row * cell_width), Color(0.5, 0.5, 0.5))
