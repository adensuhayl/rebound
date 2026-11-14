extends SceneTree
## Run: Godot --headless --path . --script res://tests/smoke.gd
var checks = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error("FAIL: " + message)
		quit(1)
		assert(condition, message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.persist_records = false
	game.set_process(false)
	check(game.mode == "title", "Starts on title")
	game._start()
	check(game.bricks.size() == 50 and game.lives == 3, "New run has stage one and three lives")
	game._action()
	check(game.launched and game.velocity.y < 0, "Launch moves upward")
	game.ball = Vector2(500, 500)
	game.velocity = Vector2(100, 400)
	game._action()
	check(game.velocity.y < 0 and game.cooldown == 5, "Comeback reverses descent")
	game.velocity.y = 400
	game._action()
	check(game.velocity.y > 0, "Cooldown prevents repeated rescue")
	game.ball = Vector2(66, 450)
	game.velocity = Vector2(-400, 0)
	game._move_ball(0.01)
	check(game.velocity.x > 0, "Left wall reflects")
	game.ball = Vector2(576, 615)
	game.velocity = Vector2(0, 400)
	game._move_ball(0.01)
	check(game.velocity.y < 0, "Paddle reflects")
	var before: int = game.bricks.size()
	game.ball = Vector2(135, 153)
	game.velocity = Vector2(0, 400)
	game._move_ball(0.02)
	check(game.bricks.size() == before - 1 and game.score == 100, "Crystal collision scores and removes crystal")
	game.ball = Vector2(500, 710)
	game._move_ball(0.01)
	check(game.lives == 2 and not game.launched, "Miss costs one life and resets ball")
	game.lives = 1
	game.ball = Vector2(500, 710)
	game._move_ball(0.01)
	check(game.mode == "lost", "Last miss ends run")
	game._start()
	game.bricks.clear()
	game.bricks.append({"rect": Rect2(91, 167, 88, 27), "hp": 1, "color": Color.WHITE})
	game.ball = Vector2(135, 153)
	game.velocity = Vector2(0, 400)
	game.launched = true
	game._move_ball(0.02)
	check(game.stage_delay > 0, "Last crystal schedules next stage")
	game._process(1.6)
	check(game.stage == 2 and not game.launched and not game.bricks.is_empty(), "Next stage resets safely")
	game.stage = 3
	game.bricks.clear()
	game.bricks.append({"rect": Rect2(91, 167, 88, 27), "hp": 1, "color": Color.WHITE})
	game.ball = Vector2(135, 153)
	game.velocity = Vector2(0, 400)
	game._move_ball(0.02)
	check(game.mode == "won", "Third stage clear wins")
	game._start()
	var pause_event = InputEventKey.new()
	pause_event.keycode = KEY_P
	pause_event.pressed = true
	game._unhandled_input(pause_event)
	check(game.mode == "pause", "Pause works")
	game._unhandled_input(pause_event)
	check(game.mode == "play", "Resume works")
	# Simulate a minute at 120 Hz to exercise repeated collision/miss cycles.
	game._start()
	game._action()
	for frame in range(7200):
		if game.mode != "play":
			break
		if not game.launched:
			game._action()
		game._process(1.0 / 120.0)
		check(game.ball.is_finite() and game.velocity.is_finite(), "Simulation stays finite")
	check(game.lives >= 0 and game.lives <= 3, "Simulation maintains valid life count")
	print("PASS: ", checks, " gameplay checks")
	if "--capture" in OS.get_cmdline_user_args():
		game.mode = "play"
		game.stage = 1
		game.lives = 3
		game.score = 0
		game.best = 0
		game.particles.clear()
		game.shake = 0
		game.toast_time = 0
		game._build_stage()
		game.ball = Vector2(640, 460)
		game.launched = true
		game.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://preview.png")
	quit(0)
