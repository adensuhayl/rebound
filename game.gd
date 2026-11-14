extends Node2D
## Rebound: a small, asset-independent arcade game. All coordinates use 1152 x 768.

const INK = Color("101b30")
const MUTED = Color("7d91ac")
const WHITE = Color("edf6ff")
const MINT = Color("67f0c0")
const GOLD = Color("ffd179")
const CORAL = Color("ff7b91")
const BLUE = Color("7faaff")
const FIELD = Rect2(56, 114, 1040, 560)
const PADDLE_Y = 626.0
const RADIUS = 9.0
var font: Font = ThemeDB.fallback_font
var mode = "title"
var stage = 1
var lives = 3
var score = 0
var best = 0
var persist_records = true
var paddle_x = 576.0
var ball = Vector2(576, 605)
var velocity = Vector2.ZERO
var launched = false
var cooldown = 0.0
var pulse = 0.0
var shake = 0.0
var elapsed = 0.0
var bricks: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var trail: Array[Vector2] = []
var toast = ""
var toast_time = 0.0
var mouse_control = false
var stage_delay = 0.0

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("0b1221"))
	var save = ConfigFile.new()
	if save.load("user://rebound.cfg") == OK:
		best = int(save.get_value("record", "best", 0))
	_build_stage()

func _build_stage() -> void:
	bricks.clear()
	for row in range(4 + stage):
		for col in range(10):
			if stage == 2 and (col + row) % 4 == 0:
				continue
			if stage == 3 and row < 2 and col in [0, 1, 8, 9]:
				continue
			var hp = 2 if stage > 1 and row % 3 == 0 else 1
			bricks.append({"rect": Rect2(91 + col * 98, 167 + row * 38, 88, 27), "hp": hp, "color": [MINT, BLUE, CORAL, GOLD][row % 4]})
	_reset_ball()

func _reset_ball() -> void:
	launched = false
	velocity = Vector2.ZERO
	ball = Vector2(paddle_x, PADDLE_Y - 20)
	trail.clear()
	cooldown = 0.0

func _start() -> void:
	stage = 1
	lives = 3
	score = 0
	paddle_x = 576
	particles.clear()
	stage_delay = 0
	mode = "play"
	_build_stage()
	_notice("FIND YOUR ANGLE. MAKE YOUR COMEBACK.")

func _notice(message: String) -> void:
	toast = message
	toast_time = 2.8

func _action() -> void:
	if mode in ["title", "lost", "won"]:
		_start()
	elif mode == "play" and stage_delay <= 0:
		if not launched:
			launched = true
			velocity = Vector2(180, -390 - stage * 25)
		elif cooldown <= 0 and velocity.y > 0:
			velocity.y = -absf(velocity.y)
			cooldown = 5.0
			pulse = 1.0
			_burst(ball, MINT, 22)
			_notice("BOUNCE BACK!")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_control = true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_action()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_A, KEY_D, KEY_LEFT, KEY_RIGHT]:
			mouse_control = false
		if event.keycode in [KEY_SPACE, KEY_ENTER]:
			_action()
		if event.keycode in [KEY_P, KEY_ESCAPE] and mode in ["play", "pause"]:
			mode = "play" if mode == "pause" else "pause"
		if event.keycode == KEY_R and mode != "title":
			_start()

func _process(delta: float) -> void:
	elapsed += delta
	if mode != "pause":
		pulse = maxf(0, pulse - delta * 2)
		shake = maxf(0, shake - delta * 30)
		toast_time = maxf(0, toast_time - delta)
		for i in range(particles.size() - 1, -1, -1):
			particles[i]["life"] -= delta
			particles[i]["pos"] += particles[i]["vel"] * delta
			particles[i]["vel"].y += 160 * delta
			if particles[i]["life"] <= 0:
				particles.remove_at(i)
	if mode == "play":
		cooldown = maxf(0, cooldown - delta)
		if mouse_control:
			paddle_x = move_toward(paddle_x, get_global_mouse_position().x, 1500 * delta)
		else:
			var axis = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
			paddle_x += axis * 660 * delta
		paddle_x = clampf(paddle_x, 122, 1030)
		if stage_delay > 0:
			stage_delay -= delta
			if stage_delay <= 0:
				stage += 1
				_build_stage()
		elif not launched:
			ball = Vector2(paddle_x, PADDLE_Y - 20)
		else:
			# Small substeps keep fast balls from passing through thin bricks.
			var steps = maxi(1, ceili(velocity.length() * minf(delta, 0.05) / 6.0))
			for step in range(steps):
				if not launched or mode != "play" or stage_delay > 0:
					break
				_move_ball(minf(delta, 0.05) / steps)
			trail.push_front(ball)
			if trail.size() > 14:
				trail.pop_back()
	queue_redraw()

func _move_ball(dt: float) -> void:
	var previous = ball
	ball += velocity * dt
	if ball.x < FIELD.position.x + RADIUS:
		ball.x = FIELD.position.x + RADIUS
		velocity.x = absf(velocity.x)
	if ball.x > FIELD.end.x - RADIUS:
		ball.x = FIELD.end.x - RADIUS
		velocity.x = -absf(velocity.x)
	if ball.y < FIELD.position.y + RADIUS:
		ball.y = FIELD.position.y + RADIUS
		velocity.y = absf(velocity.y)
	if velocity.y > 0 and previous.y + RADIUS <= PADDLE_Y and ball.y + RADIUS >= PADDLE_Y and absf(ball.x - paddle_x) < 72:
		ball.y = PADDLE_Y - RADIUS
		var angle = clampf((ball.x - paddle_x) / 64, -1, 1) * 1.05
		velocity = Vector2(sin(angle), -cos(angle)) * minf(velocity.length() + 7, 730)
		_burst(ball, MINT, 5)
	for i in range(bricks.size()):
		var rect: Rect2 = bricks[i]["rect"]
		if rect.grow(RADIUS).has_point(ball):
			if previous.y <= rect.position.y - RADIUS or previous.y >= rect.end.y + RADIUS:
				velocity.y *= -1
			else:
				velocity.x *= -1
			ball = previous
			bricks[i]["hp"] -= 1
			_burst(rect.get_center(), bricks[i]["color"], 12)
			if bricks[i]["hp"] <= 0:
				bricks.remove_at(i)
				score += 100 * stage
			else:
				score += 25
			shake = 2.5
			if bricks.is_empty():
				if stage == 3:
					_finish("won")
				else:
					stage_delay = 1.5
					_notice("STAGE CLEAR  /  KEEP RISING")
			break
	if ball.y > FIELD.end.y + 30:
		lives -= 1
		shake = 8
		if lives <= 0:
			_finish("lost")
		else:
			_reset_ball()
			_notice("A SETBACK. A NEW START.")

func _finish(result: String) -> void:
	mode = result
	if score > best:
		best = score
		if persist_records:
			var save = ConfigFile.new()
			save.set_value("record", "best", best)
			save.save("user://rebound.cfg")

func _burst(at: Vector2, color: Color, count: int) -> void:
	for i in range(count):
		particles.append({"pos": at, "vel": Vector2.from_angle(randf() * TAU) * randf_range(40, 200), "life": randf_range(0.25, 0.65), "color": color})

func _text(value: String, at: Vector2, size: int, color: Color = WHITE) -> void:
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _center(value: String, y: float, size: int, color: Color = WHITE) -> void:
	_text(value, Vector2((1152 - font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x) / 2, y), size, color)

func _panel(rect: Rect2, color: Color, radius: int = 12) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	draw_style_box(style, rect)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1152, 768), Color("0b1221"))
	for x in range(24, 1152, 32):
		for y in range(114, 680, 32):
			draw_circle(Vector2(x, y), 1, Color(0.3, 0.5, 0.7, 0.10))
	_text("REBOUND", Vector2(56, 57), 30)
	_text("A LITTLE SETBACK. A BIG COMEBACK.", Vector2(57, 81), 11, MUTED)
	_text("STAGE  %02d / 03" % stage, Vector2(450, 54), 16, MINT)
	_text("SCORE  %06d" % score, Vector2(653, 54), 16)
	_text("BEST  %06d" % best, Vector2(888, 54), 16, MUTED)
	_panel(FIELD, Color("101c30"), 18)
	draw_line(Vector2(80, 114), Vector2(1072, 114), Color("29425b"), 2)
	draw_set_transform(Vector2(randf_range(-shake, shake), randf_range(-shake, shake)))
	for brick in bricks:
		var rect: Rect2 = brick["rect"]
		var color: Color = brick["color"]
		_panel(Rect2(rect.position + Vector2(0, 4), rect.size), color.darkened(0.65), 5)
		_panel(rect, color.darkened(0.15) if brick["hp"] == 2 else color, 5)
		draw_line(rect.position + Vector2(8, 5), rect.position + Vector2(rect.size.x - 8, 5), Color(1, 1, 1, 0.25), 2)
		if brick["hp"] == 2:
			draw_circle(rect.get_center(), 3, INK)
	for i in range(trail.size() - 1, -1, -1):
		draw_circle(trail[i], RADIUS * (1.0 - float(i) / 16), Color(0.4, 0.94, 0.75, 0.25 * (1.0 - float(i) / 15)))
	if pulse > 0:
		draw_arc(ball, 20 + (1 - pulse) * 140, 0, TAU, 64, Color(0.4, 1, 0.8, pulse), 3, true)
	draw_circle(ball, 16, Color(0.5, 1, 0.85, 0.08))
	draw_circle(ball, RADIUS, WHITE)
	_panel(Rect2(paddle_x - 64, PADDLE_Y + 5, 128, 14), Color("1a4c4a"), 7)
	_panel(Rect2(paddle_x - 64, PADDLE_Y, 128, 12), MINT, 6)
	draw_line(Vector2(paddle_x - 18, PADDLE_Y + 5), Vector2(paddle_x + 18, PADDLE_Y + 5), INK, 2)
	for particle in particles:
		var color: Color = particle["color"]
		color.a = clampf(particle["life"] * 2, 0, 1)
		draw_circle(particle["pos"], 3, color)
	draw_set_transform(Vector2.ZERO)
	for i in range(3):
		draw_circle(Vector2(70 + i * 24, 710), 6, CORAL if i < lives else Color("293349"))
	_text("CHANCES", Vector2(146, 715), 12, MUTED)
	_text("COMEBACK", Vector2(450, 710), 12, MINT if cooldown <= 0 else MUTED)
	_panel(Rect2(552, 701, 122, 7), Color("293349"), 3)
	_panel(Rect2(552, 701, 122 * (1 - cooldown / 5), 7), MINT, 3)
	_text("READY" if cooldown <= 0 else "%.1fs" % cooldown, Vector2(687, 710), 12, MUTED)
	_text("P  PAUSE     R  RESTART", Vector2(889, 714), 12, MUTED)
	_center("A / D  OR  ARROWS  /  MOUSE TO MOVE     •     SPACE / CLICK TO LAUNCH OR RESCUE", 750, 11, MUTED)
	if mode == "play":
		if toast_time > 0:
			_center(toast, 510, 17, MINT)
		if not launched and stage_delay <= 0:
			_center("SPACE OR CLICK TO LAUNCH", 555, 15, WHITE)
	if mode in ["title", "pause", "lost", "won"]:
		draw_rect(Rect2(0, 0, 1152, 768), Color(0.025, 0.045, 0.085, 0.88))
		_panel(Rect2(265, 168, 622, 433), Color("132139"), 24)
		_center("B O U N C E   B A C K", 223, 13, MINT)
		var heading = {"title": "REBOUND", "pause": "TAKE A BREATH", "lost": "RISE AGAIN", "won": "WHAT A COMEBACK"}[mode]
		_center(heading, 298, 46)
		if mode == "title":
			_center("Every fall is another chance to rise.", 341, 20, MUTED)
			_center("Break every crystal across three stages.", 389, 17)
			_center("Aim with the paddle's edge. Keep the ball alive.", 418, 17, MUTED)
			_center("SPACE flips a falling ball upward. Recharges in 5s.", 449, 16, MINT)
		elif mode == "pause":
			_center("Your comeback can wait a moment.", 365, 20, MUTED)
			_center("Press P or Esc to resume", 428, 20, MINT)
		else:
			_center("All three stages cleared." if mode == "won" else "A setback is just the start of your next run.", 355, 18, MUTED)
			_center("%06d POINTS     /     BEST %06d" % [score, best], 418, 21, MINT)
		if mode != "pause":
			_panel(Rect2(382, 491, 388, 56), MINT, 10)
			_center("SPACE / CLICK  —  " + ("LET'S PLAY" if mode == "title" else "PLAY AGAIN"), 526, 17, INK)
		_center("MOVE  A / D OR MOUSE      •      THREE CHANCES", 579, 11, MUTED)
