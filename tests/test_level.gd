extends SceneTree
## Run: ./scripts/test.sh
## Scripts are load()ed at runtime (not preload) so autoloads like Sound exist when they compile.


func _initialize() -> void:
	var game_manager = load("res://scripts/GameManager.gd")
	var grid = load("res://scripts/GridController.gd")

	var cells: int = grid.COLS * grid.ROWS
	for n in range(1, 101):
		var c: Dictionary = game_manager.level_config(n)
		assert(c.diamond_count > 0 and c.diamond_count <= cells, "diamonds fit, level %d" % n)
		assert(game_manager.max_diggers(c) >= c.diamond_count, "enough diggers, level %d" % n)
		assert(game_manager.max_diggers(c) <= cells, "diggers fit, level %d" % n)
		assert(c.memorize_time > 0.0 and c.pass_accuracy_percentage <= 1.0)

	var board = grid.new()
	board.spawn(20)
	var unique := {}
	for d in board.diamonds:
		unique[d] = true
	assert(unique.size() == 20, "spawn non-overlapping")
	assert(board.dig(board.diamonds[0]) and not board.dig(Vector2i(-5, -5)))
	board.free()

	# State machine playthrough: observe -> dig all diamonds -> pass -> next level.
	var save = root.get_node("Save")
	save.path = "user://test_save.cfg"  # don't touch the real best score
	save.scores = []
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	assert(main.state == main.STATE_OBSERVE)
	main._process(99.0)
	assert(main.state == main.STATE_DIGGING)
	for d in main.board.diamonds.duplicate():
		main._on_cell_tapped(d)
	assert(main.state == main.STATE_EVALUATING and main.passed())
	assert(main.new_best and save.scores.is_empty(), "score only saved at game over")
	main._on_action_pressed()
	assert(main.level == 2 and main.state == main.STATE_OBSERVE)

	# Fail path: dig only empty cells -> Retry + sad music, retry resets both.
	var sound = root.get_node("Sound")
	main._process(99.0)
	for x in grid.COLS:
		for y in grid.ROWS:
			var cell := Vector2i(x, y)
			if main.state == main.STATE_DIGGING and cell not in main.board.diamonds:
				main._on_cell_tapped(cell)
	assert(main.state == main.STATE_EVALUATING and not main.passed())
	assert(main.action_button.visible and main.action_button.text == "Retry")
	assert(sound._sad_on, "sad music on fail")
	main._on_action_pressed()
	assert(main.level == 2 and not sound._sad_on and main.lives == 2)

	# Lose remaining lives -> game over, name entry, score saved.
	for i in 2:
		main._process(99.0)
		for x in grid.COLS:
			for y in grid.ROWS:
				var cell := Vector2i(x, y)
				if main.state == main.STATE_DIGGING and cell not in main.board.diamonds:
					main._on_cell_tapped(cell)
		if i == 0:
			main._on_action_pressed()
	assert(main.game_over() and main.name_entry.visible and main.action_button.text == "Save score")
	main.name_entry.insert_text_at_caret("abcdefg")
	assert(main.name_entry.text == "abcde", "max 5 chars")
	main._on_action_pressed()
	assert(save.scores == [{"name": "ABCDE", "score": 400}], str(save.scores))
	assert(not save.qualifies(0) and save.qualifies(1))
	main.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save.path))

	var menu = load("res://scenes/Menu.tscn").instantiate()
	root.add_child(menu)
	assert(menu.get_node("%Scores").text == "HIGH SCORES\n1.  ABCDE   400", menu.get_node("%Scores").text)
	menu.free()

	print("OK")
	quit()
