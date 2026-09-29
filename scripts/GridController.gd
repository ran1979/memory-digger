extends Node2D
## Board: draws the grid, spawns diamonds, maps touches to cells.

signal cell_tapped(cell: Vector2i)

const COLS := 6
const ROWS := 8
const CELL := 100.0
const NONE := Vector2i(-1, -1)
const THEME_COLORS := {
	"grass": Color(0.33, 0.58, 0.28),
	"city": Color(0.38, 0.38, 0.42),
	"desert": Color(0.8, 0.68, 0.42),
}

var theme_name := "grass"
var diamonds: Array[Vector2i] = []
var dug := {}  # Vector2i -> bool (hit)
var show_diamonds := false
var input_enabled := false:
	set(v):
		input_enabled = v
		_pressed_cell = NONE
var _pressed_cell := NONE
var _anim := {}  # Vector2i -> seconds since dug, while the dig animation plays
var _tile := _make_tile()

const ANIM_TIME := 0.4


func spawn(count: int) -> void:
	var cells: Array[Vector2i] = []
	for x in COLS:
		for y in ROWS:
			cells.append(Vector2i(x, y))
	cells.shuffle()
	diamonds = cells.slice(0, count)
	dug.clear()
	_anim.clear()
	queue_redraw()


func dig(cell: Vector2i) -> bool:
	var hit := cell in diamonds
	dug[cell] = hit
	_anim[cell] = 0.0
	_burst(_cell_center(cell), hit)
	queue_redraw()
	return hit


## Floating text that rises and fades above a cell (e.g. "+100").
func popup(cell: Vector2i, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(CELL, 50)
	label.position = Vector2(cell) * CELL
	add_child(label)
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 70, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)


func _process(delta: float) -> void:
	if _anim.is_empty():
		return
	for c in _anim.keys():
		_anim[c] += delta
		if _anim[c] >= ANIM_TIME:
			_anim.erase(c)
	queue_redraw()


## One-shot particles: sparkles on a hit, dust puff on a miss.
func _burst(pos: Vector2, hit: bool) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 180.0
	p.amount = 24 if hit else 12
	p.lifetime = 0.6 if hit else 0.5
	p.initial_velocity_min = 120.0 if hit else 40.0
	p.initial_velocity_max = 260.0 if hit else 90.0
	p.gravity = Vector2(0, 300) if hit else Vector2(0, -40)
	p.scale_amount_min = 3.0 if hit else 6.0
	p.scale_amount_max = 6.0 if hit else 12.0
	p.color = Color(0.75, 0.95, 1.0) if hit else Color(0.55, 0.4, 0.25, 0.8)
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	p.color_ramp = fade
	p.finished.connect(p.queue_free)
	add_child(p)
	p.emitting = true


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or not event is InputEventScreenTouch or event.index != 0:
		return
	var local: Vector2 = make_input_local(event).position
	var cell := Vector2i((local / CELL).floor())
	var valid := Rect2i(0, 0, COLS, ROWS).has_point(cell) and not dug.has(cell)
	if event.pressed:
		_pressed_cell = cell if valid else NONE
	else:
		if valid and cell == _pressed_cell:
			cell_tapped.emit(cell)
		_pressed_cell = NONE
	queue_redraw()


func _draw() -> void:
	var base: Color = THEME_COLORS[theme_name]
	for x in COLS:
		for y in ROWS:
			var c := Vector2i(x, y)
			var shake := 0.0
			var pop := 1.0
			if _anim.has(c):
				var t: float = _anim[c]
				var fade := 1.0 - t / ANIM_TIME
				if dug[c]:
					pop += 0.5 * sin(t * PI / ANIM_TIME) * fade
				else:
					shake = sin(t * 70.0) * 8.0 * fade
			var r := Rect2(Vector2(c) * CELL + Vector2(shake, 0), Vector2.ONE * CELL).grow(-4)
			var center := r.get_center()
			_tile.bg_color = base.darkened(0.35)
			draw_style_box(_tile, Rect2(r.position + Vector2(0, 4), r.size))  # shadow
			var color := base.lightened(0.07) if (x + y) % 2 == 0 else base
			_tile.bg_color = base.lightened(0.3) if c == _pressed_cell else color
			draw_style_box(_tile, r)
			if dug.has(c):
				draw_set_transform(center, 0, Vector2(1, 0.75))
				draw_circle(Vector2.ZERO, 40, base.darkened(0.5))  # rim
				draw_circle(Vector2.ZERO, 34, Color(0.22, 0.14, 0.08))  # hole
				draw_set_transform(Vector2.ZERO)
			if show_diamonds and c in diamonds or dug.get(c, false):
				_draw_diamond(center, pop)
			if dug.has(c) and not dug[c]:
				draw_line(center + Vector2(-20, -20), center + Vector2(20, 20), Color.RED, 6)
				draw_line(center + Vector2(20, -20), center + Vector2(-20, 20), Color.RED, 6)


## Brilliant-cut side view: light crown, deeper pavilion, facet lines, shine.
func _draw_diamond(center: Vector2, scale_by := 1.0) -> void:
	draw_set_transform(center, 0, Vector2.ONE * scale_by)
	var crown := PackedVector2Array([Vector2(-16, -22), Vector2(16, -22), Vector2(30, -8), Vector2(-30, -8)])
	var pavilion := PackedVector2Array([Vector2(-30, -8), Vector2(30, -8), Vector2(0, 30)])
	draw_colored_polygon(crown, Color(0.72, 0.95, 1.0))
	draw_colored_polygon(pavilion, Color(0.3, 0.7, 0.95))
	var facet := Color(1, 1, 1, 0.5)
	for a: Vector2 in [Vector2(-16, -22), Vector2(0, -22), Vector2(16, -22)]:
		draw_line(a, Vector2(-10, -8), facet, 1.5)
		draw_line(a, Vector2(10, -8), facet, 1.5)
	draw_line(Vector2(-10, -8), Vector2(0, 30), facet, 1.5)
	draw_line(Vector2(10, -8), Vector2(0, 30), facet, 1.5)
	draw_polyline(PackedVector2Array([Vector2(-16, -22), Vector2(16, -22), Vector2(30, -8), Vector2(0, 30), Vector2(-30, -8), Vector2(-16, -22)]), Color.WHITE, 2)
	draw_line(Vector2(-20, -16), Vector2(-8, -16), Color.WHITE, 2)  # shine
	draw_line(Vector2(-14, -22), Vector2(-14, -10), Color.WHITE, 2)
	draw_set_transform(Vector2.ZERO)


func _cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL


static func _make_tile() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(14)
	return box
