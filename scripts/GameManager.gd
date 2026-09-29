extends Node2D
## Game state machine: observe -> dig -> evaluate.

enum { STATE_OBSERVE, STATE_DIGGING, STATE_EVALUATING }

const THEMES := ["grass", "city", "desert"]
const POINTS_PER_HIT := 100
const LIVES := 3

@onready var board := $Board
@onready var background: TextureRect = $Background
@onready var info: Label = $Info
@onready var timer_bar: ProgressBar = $TimerBar
@onready var action_button: Button = $ActionButton
@onready var menu_button: Button = $MenuButton
@onready var name_entry: LineEdit = $NameEntry

var state := STATE_OBSERVE
var level := 1
var score := 0
var level_start_score := 0
var cfg: Dictionary
var time_left := 0.0
var diggers_left := 0
var hits := 0
var new_best := false
var lives := LIVES


# ponytail: formula instead of a level table; swap for a Resource list if levels need hand-tuning.
static func level_config(n: int) -> Dictionary:
	return {
		"level_number": n,
		"map_theme": THEMES[int((n - 1) / 3.0) % THEMES.size()],
		"diamond_count": mini(3 + n, 20),
		"memorize_time": maxf(5.0 - 0.3 * (n - 1), 1.5),
		"digger_factor": maxf(1.6 - 0.05 * (n - 1), 1.2),
		"pass_accuracy_percentage": minf(0.6 + 0.02 * (n - 1), 0.9),
	}


static func max_diggers(c: Dictionary) -> int:
	return ceili(c.diamond_count * c.digger_factor)


func _ready() -> void:
	board.cell_tapped.connect(_on_cell_tapped)
	action_button.pressed.connect(_on_action_pressed)
	menu_button.pressed.connect(_to_menu)
	name_entry.text_changed.connect(_on_name_changed)
	name_entry.text_submitted.connect(func(_t): _on_action_pressed())
	Sound.update_music()
	start_level()


func start_level() -> void:
	cfg = level_config(level)
	level_start_score = score
	board.theme_name = cfg.map_theme
	var base: Color = board.THEME_COLORS[cfg.map_theme]
	background.texture.gradient.colors = PackedColorArray([base.darkened(0.55), base.darkened(0.8)])
	board.spawn(cfg.diamond_count)
	diggers_left = max_diggers(cfg)
	hits = 0
	time_left = cfg.memorize_time
	Sound.play("new_level")
	_set_state(STATE_OBSERVE)


func _set_state(s: int) -> void:
	state = s
	board.show_diamonds = s != STATE_DIGGING
	board.input_enabled = s == STATE_DIGGING
	board.queue_redraw()
	timer_bar.visible = s == STATE_OBSERVE
	action_button.visible = s == STATE_EVALUATING
	name_entry.visible = false
	if s == STATE_EVALUATING:
		if not passed():
			lives -= 1
		action_button.text = "Next level" if passed() else "Retry"
		action_button.get_theme_stylebox("normal").bg_color = Color(0.2, 0.55, 0.3) if passed() else Color(0.7, 0.2, 0.2)
		new_best = score > Save.best_score
		if game_over():
			action_button.text = "Save score" if Save.qualifies(score) else "Game over"
			name_entry.visible = Save.qualifies(score)
			name_entry.text = Save.last_name
			name_entry.grab_focus.call_deferred()  # pops the Android keyboard
		Sound.play("level_up" if passed() else "game_over")
		Sound.set_sad(not passed())
	_update_hud()


func _process(delta: float) -> void:
	if state != STATE_OBSERVE:
		return
	time_left -= delta
	timer_bar.value = time_left / cfg.memorize_time * 100.0
	if time_left <= 0.0:
		_set_state(STATE_DIGGING)


func _on_cell_tapped(cell: Vector2i) -> void:
	diggers_left -= 1
	if board.dig(cell):
		hits += 1
		score += POINTS_PER_HIT
		board.popup(cell, "+%d" % POINTS_PER_HIT)
		Sound.play("hit")
		Input.vibrate_handheld(30)  # ponytail: always on; add a Save toggle if asked
	else:
		Sound.play("miss")
		Input.vibrate_handheld(90)
	if diggers_left == 0 or hits == cfg.diamond_count:
		_set_state(STATE_EVALUATING)
	else:
		_update_hud()


func accuracy() -> float:
	return float(hits) / cfg.diamond_count


func passed() -> bool:
	return accuracy() >= cfg.pass_accuracy_percentage


func game_over() -> bool:
	return lives <= 0


func _on_name_changed(text: String) -> void:
	var caret := name_entry.caret_column
	name_entry.text = text.to_upper()
	name_entry.caret_column = caret


func _on_action_pressed() -> void:
	Sound.set_sad(false)
	if game_over():
		if name_entry.visible:
			var player_name := name_entry.text.strip_edges().to_upper()
			Save.add_score(player_name if player_name else "?????", score)
		_to_menu()
		return
	if passed():
		level += 1
	else:
		score = level_start_score
	start_level()


func _to_menu() -> void:
	Sound.play("click")
	Sound.set_sad(false)
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:  # Android back button
		_to_menu()


func _update_hud() -> void:
	queue_redraw()
	var need := "need %d%%" % roundi(cfg.pass_accuracy_percentage * 100)
	match state:
		STATE_OBSERVE:
			info.text = "Level %d  ·  Score %d  ·  Lives %d\nMemorize the %d diamonds!" % [level, score, lives, cfg.diamond_count]
		STATE_DIGGING:
			info.text = "Found %d/%d\nScore %d  ·  %s" % [hits, cfg.diamond_count, score, need]
		STATE_EVALUATING:
			var result := "GAME OVER" if game_over() else "PASSED" if passed() else "FAILED · %d lives left" % lives
			info.text = "%s  %d%%\nFound %d/%d  ·  Score %d%s" % [
				result, roundi(accuracy() * 100), hits, cfg.diamond_count, score, "  NEW BEST!" if new_best else ""]
			if name_entry.visible:
				info.text += "\nEnter your name:"


## Digging phase: row of shovels in the timer bar's slot, used ones dimmed.
func _draw() -> void:
	if state != STATE_DIGGING:
		return
	var total := max_diggers(cfg)
	var spacing := minf(28.0, 640.0 / total)
	for i in total:
		var pos := Vector2(360.0 - spacing * (total - 1) / 2.0 + spacing * i, 232.0)
		_draw_shovel(pos, 1.0 if i < diggers_left else 0.25)


func _draw_shovel(pos: Vector2, alpha: float) -> void:
	var wood := Color(0.65, 0.45, 0.25, alpha)
	draw_line(pos + Vector2(0, -16), pos + Vector2(0, 4), wood, 3)
	draw_line(pos + Vector2(-5, -16), pos + Vector2(5, -16), wood, 3)
	var blade := PackedVector2Array([Vector2(-7, 2), Vector2(7, 2), Vector2(7, 10), Vector2(0, 18), Vector2(-7, 10)])
	for i in blade.size():
		blade[i] += pos
	draw_colored_polygon(blade, Color(0.82, 0.84, 0.88, alpha))
