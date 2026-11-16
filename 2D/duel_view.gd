extends Node2D

signal fighter_selected(character: int)
signal stage_selected(index: int)
signal mode_selected(campaign: bool)
signal resume_requested
signal pause_requested
signal restart_requested
signal select_requested
signal action_requested(action: StringName)
signal practice_toggled(enabled: bool)

const Rules := preload("res://2D/duel_rules.gd")
const Roster := preload("res://2D/duel_roster.gd")
const STAGES := [preload("res://2D/assets/night-arena.png"), preload("res://2D/assets/campaign/debate.jpg"),
	preload("res://2D/assets/campaign/rally.jpg"), preload("res://2D/assets/campaign/park.jpg")]
const STAGE_NAMES := ["夜市", "辯論會場", "造勢大會", "公園"]
const PORTRAITS := [
	preload("res://2D/assets/campaign/liu-super.jpg"), preload("res://2D/assets/campaign/gu-super.jpg"),
	preload("res://2D/assets/campaign/pei-super.jpg"), preload("res://2D/assets/campaign/shi-super.jpg"),
	preload("res://2D/assets/campaign/lu-super.jpg"), preload("res://2D/assets/campaign/ruan-super.jpg"),
	preload("res://2D/assets/campaign/wen-super.jpg"), preload("res://2D/assets/campaign/fang-super.jpg"),
	preload("res://2D/assets/campaign/hong-super.jpg"),
]
const CHARACTER_ATLASES := [
	preload("res://2D/assets/campaign/liu.png"), preload("res://2D/assets/campaign/gu.png"),
	preload("res://2D/assets/campaign/pei.png"), preload("res://2D/assets/campaign/shi.png"),
	preload("res://2D/assets/campaign/lu.png"), preload("res://2D/assets/campaign/ruan.png"),
	preload("res://2D/assets/campaign/wen.png"), preload("res://2D/assets/campaign/fang.png"),
	preload("res://2D/assets/campaign/hong.png"),
]
const FONT := preload("res://2D/assets/DuelText.ttf")
const SIZE := Vector2(1280, 720)
const FLOOR := 573.0
const CELL := Vector2(480, 360)
const ANCHOR := Vector2(198, 346)
const BODY_SCALE := 0.95
const KO_SETTLED_REMAINING := 112
const PAPER := Color("fff2d8")
const INK := Color("10131e")
const JADE := Color("5aefc3")
const ORCHID := Color("f5a0d7")
const GOLD := Color("ffc468")
const CORAL := Color("f45640")
const GLASS := Color("a4cbff")
const RALLY_BLUE := Color("54d4ff")
const ECHO_MESSAGES := ["推", "+1", "洗版"]
const ECHO_COLORS := [GLASS, GOLD, Color("ff917e")]
const CHARACTER_ACCENTS := [JADE, GOLD, Color("e9a37b"), Color("acc4d8"), Color("80b8ff"),
	Color("72e1eb"), Color("ecaacb"), Color("edc65f"), Color("ff7b72")]
const TOUCH_STICK := Vector2(132, 530)
const TOUCH_GUARD := Vector2(272, 554)
const TOUCH_GUARD_RADIUS := 43.0
const TOUCH_CENTERS := [Vector2(1147, 552), Vector2(1016, 550), Vector2(1025, 449), Vector2(1124, 432), Vector2(1212, 440)]
const TOUCH_RADII := [55.0, 39.0, 38.0, 38.0, 39.0]
const ACTIONS := [&"normal", &"skill_1", &"skill_2", &"skill_3", &"super"]
const ACTION_KEYS := ["J", "K", "L", "U", "I"]
const ACTION_BUTTON_START := Vector2(314.0, 636.0)
const ACTION_BUTTON_SIZE := Vector2(122.0, 55.0)
const ACTION_BUTTON_STEP := 132.0
const SELECT_COLUMNS := 4

enum Pose { IDLE, JAB, KICK, HURT, GUARD, LUNGE, STRIDE, PASS, COIL, UPPERCUT, LOW_KICK, KNEE }
const SUPER_POSES := [
	[Pose.LOW_KICK, Pose.KNEE, Pose.UPPERCUT, Pose.JAB, Pose.KICK, Pose.LUNGE],
	[Pose.JAB, Pose.LUNGE, Pose.LOW_KICK, Pose.UPPERCUT, Pose.JAB, Pose.LUNGE],
	[Pose.JAB, Pose.LUNGE, Pose.LUNGE, Pose.UPPERCUT, Pose.JAB, Pose.LUNGE],
	[Pose.LUNGE, Pose.LOW_KICK, Pose.JAB, Pose.UPPERCUT, Pose.KNEE, Pose.LOW_KICK],
	[Pose.JAB, Pose.KNEE, Pose.LUNGE, Pose.KICK, Pose.STRIDE, Pose.LOW_KICK],
	[Pose.LUNGE, Pose.JAB, Pose.LUNGE, Pose.UPPERCUT, Pose.KICK, Pose.LUNGE],
	[Pose.JAB, Pose.LUNGE, Pose.LOW_KICK, Pose.UPPERCUT, Pose.LUNGE, Pose.JAB],
	[Pose.JAB, Pose.LUNGE, Pose.JAB, Pose.UPPERCUT, Pose.LUNGE, Pose.UPPERCUT],
	[Pose.JAB, Pose.LUNGE, Pose.LOW_KICK, Pose.JAB, Pose.UPPERCUT, Pose.LUNGE],
]
const SUPER_OPENER := [Pose.KICK, Pose.LUNGE, Pose.LUNGE, Pose.LUNGE, Pose.JAB, Pose.KICK, Pose.LUNGE, Pose.LUNGE, Pose.LUNGE]


class Impact:
	var point := Vector2.ZERO
	var direction := 1.0
	var side := 0
	var age := 0
	var style: StringName
	var effect: StringName
	var effect_x := 0.0
	var wave := 0
	var seed := 0


var model: Rules
var playing := false
var player_character := 0
var selected_stage := 0
var guard_held := false
var bout := 0
var ladder_size := 0
var suspended := false
var sound_off := false
var full_meter := false
var campaign_mode := true
var touch_mode := false
var joystick := Vector2.ZERO
var pulse_clock := 0
var impacts: Array[Impact] = []
var callouts: Array[Dictionary] = [{}, {}]
var typeface := FontVariation.new()
var fighter_buttons: Array[Button] = []
var mode_buttons: Array[Button] = []
var stage_buttons: Array[Button] = []
var action_buttons: Array[Button] = []
var practice_button: Button
var resume_button: Button
var pause_button: Button
var restart_button: Button
var select_button: Button


func _ready() -> void:
	typeface.base_font = FONT
	typeface.variation_opentype = {"wght": 680.0}
	typeface.variation_embolden = 0.3
	for index in 2:
		var label := "1 對 1" if index == 0 else "闖關模式"
		var button := _menu_button(label, Vector2(76 + 174 * index, 32), GOLD, Vector2(162, 48))
		button.toggle_mode = true
		button.pressed.connect(mode_selected.emit.bind(index == 1))
		mode_buttons.append(button)
	for character in Roster.PLAYABLE_COUNT:
		var card := _fighter_card(character)
		var button := _menu_button("", card.position, CHARACTER_ACCENTS[character], card.size)
		var invisible := StyleBoxEmpty.new()
		for style in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(style, invisible)
		button.tooltip_text = Roster.NAMES[character]
		button.pressed.connect(fighter_selected.emit.bind(character))
		fighter_buttons.append(button)
	for index in STAGE_NAMES.size():
		var button := _menu_button(STAGE_NAMES[index], Vector2(126.0 + 260.0 * index, 578), GOLD, Vector2(248, 52))
		button.toggle_mode = true
		button.pressed.connect(stage_selected.emit.bind(index))
		stage_buttons.append(button)
	practice_button = _menu_button("滿槽練習", Vector2(510, 644), GOLD, Vector2(260, 52))
	practice_button.toggle_mode = true
	practice_button.toggled.connect(practice_toggled.emit)
	resume_button = _menu_button("繼續", Vector2(234, 406), JADE)
	resume_button.pressed.connect(resume_requested.emit)
	restart_button = _menu_button("重賽", Vector2(510, 406), GOLD)
	restart_button.pressed.connect(restart_requested.emit)
	select_button = _menu_button("返回選角", Vector2(786, 406), ORCHID)
	select_button.pressed.connect(select_requested.emit)
	pause_button = _menu_button("Ⅱ", Vector2(1196, 123), PAPER, Vector2(52, 45))
	pause_button.pressed.connect(pause_requested.emit)
	var empty := StyleBoxEmpty.new()
	for index in ACTIONS.size():
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.position = ACTION_BUTTON_START + Vector2(index * ACTION_BUTTON_STEP, 0.0)
		button.size = ACTION_BUTTON_SIZE
		for style in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(style, empty)
		button.pressed.connect(action_requested.emit.bind(ACTIONS[index]))
		add_child(button)
		action_buttons.append(button)


func render_state(state: Rules, active: bool, character: int, paused: bool, muted: bool,
		full: bool, touch: bool, stick: Vector2, stage: int, holding_guard: bool, level: int,
		total_levels: int, campaign: bool) -> void:
	model = state
	playing = active
	player_character = character
	suspended = paused
	sound_off = muted
	full_meter = full
	campaign_mode = campaign
	touch_mode = touch
	joystick = stick
	selected_stage = stage
	guard_held = holding_guard
	bout = level
	ladder_size = total_levels
	for index in mode_buttons.size():
		mode_buttons[index].visible = not playing
		mode_buttons[index].set_pressed_no_signal(index == int(campaign_mode))
	for button in fighter_buttons:
		button.visible = not playing
	for index in stage_buttons.size():
		stage_buttons[index].visible = not playing
		stage_buttons[index].set_pressed_no_signal(index == selected_stage)
	practice_button.visible = not playing
	practice_button.set_pressed_no_signal(full_meter)
	var practice_label := "滿槽練習開啟" if full_meter else "滿槽練習"
	practice_button.text = practice_label if touch_mode else "F2  " + practice_label
	resume_button.visible = suspended
	var result := playing and model.match_winner >= 0
	restart_button.text = _restart_label() if result else ("重打本關" if ladder_size > 0 else "重賽")
	restart_button.visible = suspended or result
	select_button.visible = suspended or result
	restart_button.position = Vector2(510 if suspended else 372, 432)
	select_button.position = Vector2(786 if suspended else 648, 432)
	if _campaign_cleared():
		restart_button.position.y = 605
		select_button.position.y = 605
	resume_button.position.y = 432
	pause_button.visible = touch_mode and playing and not suspended and not result and model.super_side < 0
	var show_actions := playing and not touch_mode and not suspended and not result and model.super_side < 0
	for index in action_buttons.size():
		var button := action_buttons[index]
		button.visible = show_actions
		button.disabled = not show_actions or not model.is_live() or not _action_ready(index)
	queue_redraw()


func _menu_button(label: String, at: Vector2, accent: Color, size := Vector2(260, 58)) -> Button:
	var button := Button.new()
	button.text = label
	button.position = at
	button.size = size
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", typeface)
	button.add_theme_font_size_override("font_size", 25)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("151d2c")
	frame.border_color = accent
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", frame)
	var hover := frame.duplicate() as StyleBoxFlat
	hover.bg_color = accent
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	add_child(button)
	return button


func clear_effects() -> void:
	impacts.clear()
	callouts = [{}, {}]


func advance() -> void:
	pulse_clock += 1
	for index in range(impacts.size() - 1, -1, -1):
		impacts[index].age += 1
		if impacts[index].age > 32:
			impacts.remove_at(index)


func handle(event: Dictionary) -> void:
	if event["kind"] == &"super_punchline":
		var side: int = event["side"]
		var character := model.fighters[side].character
		callouts[side] = {"start": pulse_clock, "gag": Roster.SUPER_GAGS[character], "character": character}
		return
	if event["kind"] == &"start":
		var side: int = event["side"]
		var character := model.fighters[side].character
		var slot: int = Roster.SKILLS[character].find(event["move"])
		if slot >= 0:
			callouts[side] = {"start": pulse_clock, "gag": Roster.SKILL_GAGS[character][slot], "character": character}
		return
	if event["kind"] not in [&"hit", &"block", &"barrier"]:
		return
	var impact := Impact.new()
	var move: StringName = event["move"]
	impact.effect = event.get("effect", &"")
	impact.effect_x = event.get("effect_x", 0.0)
	impact.wave = event.get("wave", 0)
	var strike_height := 238.0
	match move:
		&"hook": strike_height = 275.0
		&"roundhouse": strike_height = 57.0
		&"lane_step": strike_height = 189.0
		&"second_question": strike_height = 202.0 if event["move_tick"] == Rules.MOVES[move]["hits"][0] else 175.0
		&"super":
			strike_height = 189.0 if model.super_beat < 0 else float([112, 198, 261, 181, 231, 165][model.super_beat])
	impact.point = Vector2(event["position"].x, FLOOR + event["position"].y - strike_height)
	if impact.effect != &"":
		impact.point.y = FLOOR - float(Rules.EFFECTS[impact.effect]["height"])
	impact.direction = event["dir"]
	impact.side = event["side"]
	impact.seed = pulse_clock + impacts.size() * 11
	if event["kind"] == &"barrier":
		impact.point.y = FLOOR - 92.0
		impact.style = &"guard"
	elif event["kind"] == &"block":
		impact.style = &"guard"
	elif event["last"]:
		impact.style = &"final"
	elif move == &"super" or Rules.is_skill(move):
		impact.style = &"super" if move == &"super" else &"special"
	else:
		impact.style = &"normal"
	impacts.append(impact)


func _draw() -> void:
	if model == null:
		return
	if _campaign_cleared():
		_draw_campaign_ending()
		return
	var cinema := model.super_side >= 0
	_draw_world(cinema)
	if cinema:
		_draw_super_overlay()
	elif not playing:
		_draw_menu()
	else:
		_draw_hud()
		if model.is_live() and not suspended:
			_draw_skill_callouts()
		if model.match_winner >= 0:
			_draw_result()
		elif model.intro > 0 or model.round_end > 0:
			_draw_round_banner()
		if touch_mode and model.match_winner < 0 and not suspended:
			_draw_touch_controls()
	if suspended:
		_draw_pause()


func _draw_world(cinema: bool) -> void:
	var camera_center := SIZE * 0.5
	var zoom := 1.0
	var age := float(model.super_tick)
	var finale := 0.0
	var stage_tint := Color(0.91, 0.94, 0.98)
	if cinema:
		var attacker := model.fighters[model.super_side]
		var defender := model.fighters[1 - model.super_side]
		var beats: Array = Roster.SUPER_BEATS[attacker.character]
		finale = float(beats[-1])
		var shot := _super_camera(age, attacker, defender, beats)
		camera_center = Vector2(shot.x, shot.y)
		zoom = shot.z
		stage_tint = Color("416276") if attacker.character == Roster.LIU else Color("67464a")
		if attacker.character > Roster.GU:
			stage_tint = Color("293246").lerp(CHARACTER_ACCENTS[attacker.character], 0.36)
		var charge := smoothstep(finale - Rules.SUPER_FINISH_CUE, finale - 9.0, age)
		var release := smoothstep(finale + Rules.SUPER_FINISH_HOLD, float(Roster.SUPER_LENGTH[attacker.character]), age)
		stage_tint = stage_tint.lerp(Color("252837"), charge).lerp(Color(0.91, 0.94, 0.98), release)
	var shake := _shake()
	var origin := SIZE * 0.5 - camera_center * zoom + shake
	var stage_size := (SIZE + Vector2(96, 32)) * (1.0 + (zoom - 1.0) * 0.35)
	var stage_shift := (SIZE * 0.5 - camera_center) * 0.20 + shake * 0.24
	draw_texture_rect(STAGES[selected_stage], Rect2((SIZE - stage_size) * 0.5 + stage_shift, stage_size), false, stage_tint)
	if not playing:
		return
	if cinema and model.super_tick >= Rules.SUPER_PORTRAIT_END:
		_draw_speed_lines(finale)
		_draw_super_scenery(age, finale)
	for fighter in model.fighters:
		var height_shadow := clampf(1.0 - fighter.height / 270.0, 0.4, 1.0)
		var location := Vector2(fighter.x, FLOOR + 2.0) * zoom + origin
		draw_set_transform(location, 0.0, Vector2(1.0, 0.17) * zoom * height_shadow)
		draw_circle(Vector2.ZERO, 69.0, Color(0.08, 0.06, 0.14, 0.33 * height_shadow), true, -1, true)
		draw_circle(Vector2.ZERO, 50.0, Color(0.07, 0.05, 0.11, 0.34 * height_shadow), true, -1, true)
	var front := model.super_side if cinema else 0
	_draw_fighter(1 - front, origin, zoom)
	_draw_fighter(front, origin, zoom)
	draw_set_transform(origin, 0.0, Vector2.ONE * zoom)
	if cinema:
		_draw_super_foreground(age, finale)
	else:
		for side in model.fighters.size():
			if not _gu_winner_settled(side):
				_draw_skill_gesture(model.fighters[side])
		for effect in model.effects:
			_draw_skill_effect(effect, origin, zoom)
	for impact in impacts:
		_draw_impact(impact)
	draw_set_transform(Vector2.ZERO)


func _super_camera(age: float, attacker: Rules.Fighter, defender: Rules.Fighter, beats: Array) -> Vector3:
	var duo := (attacker.x + defender.x) * 0.5
	var direction := attacker.facing
	var aerial := attacker.character == Roster.LIU
	var finale: float = beats[-1]
	var arm := finale - Rules.SUPER_FINISH_CUE
	if age < Rules.SUPER_PORTRAIT_END:
		var ease := smoothstep(0.0, 15.0, age)
		var x := lerpf(SIZE.x * 0.5, model.super_origin + direction * 14.0, ease)
		return Vector3(x, lerpf(SIZE.y * 0.5, FLOOR - 169.0, ease), 1.0 + ease * 0.57)
	if age < float(beats[2]) - 1.0:
		# Liu gets a wide entrance. Gu starts closer on the first two palms.
		var approach := smoothstep(float(Rules.SUPER_PORTRAIT_END), float(beats[2]) - 1.0, age)
		if aerial:
			return Vector3(duo - direction * (74.0 - approach * 40.0), 401.0, 1.16 + approach * 0.20)
		return Vector3(duo + direction * 32.0, 414.0, 1.61 - approach * 0.13)
	if age < arm:
		if aerial:
			return Vector3(duo + direction * 35.0, 377.0 - defender.height * 0.42, 1.47)
		var track := smoothstep(float(beats[2]), arm, age)
		return Vector3(duo + direction * (58.0 + track * 23.0), 434.0 - defender.height * 0.22, 1.28 + track * 0.14)
	if age < finale:
		var charge := smoothstep(arm, finale - 2.0, age)
		return Vector3(lerpf(attacker.x + direction * 30.0, duo + direction * 16.0, charge),
			lerpf(397.0, 414.0, charge), lerpf(1.90, 1.63, charge))
	var release := smoothstep(finale + Rules.SUPER_FINISH_HOLD, float(Roster.SUPER_LENGTH[attacker.character]) - 1.0, age)
	return Vector3(lerpf(duo + direction * 46.0, SIZE.x * 0.5, release),
		lerpf(395.0 - defender.height * 0.38, SIZE.y * 0.5, release), lerpf(1.94, 1.0, release))


func _shake() -> Vector2:
	var strength := 0.0
	for impact in impacts:
		var power := 26.0 if impact.style == &"final" else (8.0 if impact.style in [&"special", &"super"] else 3.0)
		strength = maxf(strength, power * maxf(0.0, 1.0 - impact.age / 10.0))
	return Vector2(sin(pulse_clock * 2.7), sin(pulse_clock * 3.1) * 0.65) * strength


func _draw_fighter(side: int, origin: Vector2, zoom: float) -> void:
	var fighter := model.fighters[side]
	var atlas: Texture2D = CHARACTER_ATLASES[fighter.character]
	if _gu_winner_settled(side):
		var feet := Vector2(fighter.x, FLOOR) * zoom + origin
		_draw_sprite(atlas, Pose.IDLE, feet, zoom, fighter.facing, 0.0, Color.WHITE)
		return
	var pose := _pose(side)
	var point := Vector2(fighter.x, FLOOR - fighter.height) * zoom + origin
	var motion := float(pulse_clock if not playing else model.tick)
	var lean := 0.0
	if model.super_side == 1 - side and model.super_beat >= 0:
		var beats: Array = Roster.SUPER_BEATS[model.fighters[model.super_side].character]
		var elapsed := float(model.super_tick - int(beats[model.super_beat]))
		if model.super_beat == beats.size() - 1:
			elapsed = maxf(0.0, elapsed - Rules.SUPER_FINISH_HOLD)
		var recoil := 0.39 * smoothstep(0.0, 13.0, elapsed) if model.super_beat == beats.size() - 1 \
			else 0.13 * sin(PI * clampf(elapsed / 10.0, 0.0, 1.0))
		lean = -fighter.facing * recoil
	if fighter.hp == 0 and model.super_side < 0:
		var fall := 1.0 - smoothstep(KO_SETTLED_REMAINING, 136.0, model.round_end)
		if model.match_winner >= 0:
			fall = 1.0
		lean = -fighter.facing * fall * 1.46
		point.y += fall * 57.0
	if model.super_side < 0:
		if fighter.move == &"lane_step" and fighter.move_tick in range(3, 8):
			lean = fighter.facing * 0.13
		elif fighter.move == &"second_question" and fighter.move_tick in range(16, 23):
			lean = fighter.facing * 0.10
		elif fighter.move == &"afterimage" and fighter.move_tick in range(4, 12):
			lean = -fighter.facing * 0.12
	var is_super := side == model.super_side and model.super_tick > 19
	var is_special := model.super_side < 0 and fighter.move == &"lane_step" and fighter.move_tick in range(3, 13)
	if is_super or is_special:
		var accent: Color = CHARACTER_ACCENTS[fighter.character]
		for echo in range(3, 0, -1):
			var lag := float(echo) * (19.0 if is_super else 19.0 + fighter.move_tick)
			var ghost := point - Vector2(fighter.facing * lag, echo * (7.0 if is_super else 3.0)) * zoom
			var ghost_pose := Pose.STRIDE if is_special and echo > 1 else pose
			_draw_sprite(atlas, ghost_pose, ghost, zoom, fighter.facing, lean, Color(accent, 0.19 / echo))
	if pose == Pose.IDLE:
		var breathing := 1.0 + sin((motion + side * 14.0) * 0.082) * 0.009
		_draw_sprite(atlas, pose, point, zoom, fighter.facing, lean, Color.WHITE, breathing)
	else:
		_draw_sprite(atlas, pose, point, zoom, fighter.facing, lean, Color.WHITE)


func _gu_winner_settled(side: int) -> bool:
	var settled_round := model.winner == side and model.round_end > 0 and model.round_end <= KO_SETTLED_REMAINING
	return model.fighters[side].character == Roster.GU and (model.match_winner == side or settled_round)


func _draw_sprite(atlas: Texture2D, pose: int, point: Vector2, zoom: float, dir: float, lean: float,
		tint: Color, stretch := 1.0) -> void:
	var source := Rect2(Vector2(pose % 3, floori(pose / 3.0)) * CELL, CELL)
	draw_set_transform(point, lean, Vector2(dir, stretch) * zoom * BODY_SCALE)
	draw_texture_rect_region(atlas, Rect2(-ANCHOR, CELL), source, tint)


func _pose(side: int) -> int:
	var fighter := model.fighters[side]
	if model.super_side >= 0:
		if model.super_side != side:
			return Pose.HURT
		var age := model.super_tick
		if age < Rules.SUPER_SLOW_END:
			return SUPER_OPENER[fighter.character]
		var beats: Array = Roster.SUPER_BEATS[fighter.character]
		for index in beats.size():
			var strike: int = beats[index]
			if age < strike:
				return Pose.COIL if index in [0, 5] else Pose.PASS
			if age < strike + (16 if index == 5 else 7):
				return SUPER_POSES[fighter.character][index]
		return Pose.IDLE
	if fighter.hitstun > 0 or fighter.hp == 0:
		return Pose.HURT
	if fighter.guarding:
		return Pose.GUARD
	var move := fighter.move
	var age := fighter.move_tick
	match move:
		&"jab": return _attack_pose(age, 5, 5, Pose.IDLE, Pose.JAB)
		&"cross": return _attack_pose(age, 6, 6, Pose.COIL, Pose.JAB)
		&"hook": return _attack_pose(age, 7, 8, Pose.COIL, Pose.UPPERCUT)
		&"kick": return _attack_pose(age, 8, 6, Pose.KNEE, Pose.KICK)
		&"roundhouse": return _attack_pose(age, 7, 7, Pose.KNEE, Pose.LOW_KICK)
		&"heel": return _attack_pose(age, 9, 8, Pose.COIL, Pose.KICK)
		&"super": return _attack_pose(age, 10, 8, Pose.COIL, SUPER_OPENER[fighter.character])
		&"lane_step":
			if age < 3: return Pose.COIL
			if age < 6: return Pose.STRIDE
			return _attack_pose(age, Rules.MOVES[move]["hits"][0], 7, Pose.KNEE, Pose.KICK)
		&"ribbon_split":
			var casts: Array = Rules.MOVES[move]["casts"]
			if age < casts[0] + 3: return _attack_pose(age, casts[0], 3, Pose.COIL, Pose.LOW_KICK)
			return _attack_pose(age, casts[1], 7, Pose.COIL, Pose.LUNGE)
		&"paper_flock": return _attack_pose(age, Rules.MOVES[move]["casts"][0], 12, Pose.GUARD, Pose.UPPERCUT)
		&"second_question":
			var hits: Array = Rules.MOVES[move]["hits"]
			if age < 12: return _attack_pose(age, hits[0], 4, Pose.COIL, Pose.LUNGE)
			return _attack_pose(age, hits[1], 7, Pose.GUARD, Pose.LUNGE)
		&"afterimage":
			if age < 4: return Pose.GUARD
			if age < 12: return Pose.STRIDE if age < 8 else Pose.PASS
			return Pose.GUARD if age < 19 else Pose.IDLE
		&"echo_swarm": return _attack_pose(age, Rules.MOVES[move]["casts"][0], 10, Pose.COIL, Pose.LUNGE)
		&"copper_guard", &"fan_counter": return Pose.LUNGE if fighter.counter_used else Pose.GUARD
		&"steel_barrier": return _attack_pose(age, 8, 9, Pose.COIL, Pose.GUARD)
		&"return_line", &"ebb_step": return Pose.STRIDE if age in range(4, 14) else Pose.GUARD
		&"ridge_dash":
			if age < 6: return Pose.COIL
			if age < 24: return Pose.KNEE if fighter.height > 0.0 else Pose.STRIDE
			return _attack_pose(age, 24, 8, Pose.COIL, Pose.LOW_KICK)
		&"tide_palms":
			var hits: Array = Rules.MOVES[move]["hits"]
			return _attack_pose(age, hits[0], 5, Pose.COIL, Pose.LUNGE) if age < 12 else _attack_pose(age, hits[1], 8, Pose.COIL, Pose.UPPERCUT)
		&"internal_poll":
			var hits: Array = Rules.MOVES[move]["hits"]
			return _attack_pose(age, hits[0] if age < 12 else hits[1], 5, Pose.COIL, Pose.LUNGE)
		&"pile_driver": return _attack_pose(age, Rules.MOVES[move]["hits"][0], 9, Pose.COIL, Pose.LOW_KICK)
		&"station_elbow": return _attack_pose(age, Rules.MOVES[move]["hits"][0], 5, Pose.STRIDE, Pose.LUNGE)
		&"fan_point": return _attack_pose(age, Rules.MOVES[move]["hits"][0], 6, Pose.IDLE, Pose.JAB)
		&"workshop_overload": return _attack_pose(age, Rules.MOVES[move]["casts"][0], 10, Pose.GUARD, Pose.UPPERCUT)
		&"magnet_relay":
			return _attack_pose(age, Rules.MOVES[move]["hits"][0], 8, Pose.COIL, Pose.LUNGE)
		&"copper_palm", &"copper_volley", &"steel_wheel", &"harbor_wave", &"returning_fan", &"machine_drop", &"folding_chairs", &"victory_scroll":
			return _attack_pose(age, Rules.MOVES[move]["shots"][0][0], 12, Pose.COIL, Pose.UPPERCUT)
	if fighter.height > 0.0:
		return Pose.KNEE if fighter.velocity_y < 1.0 else Pose.PASS
	if fighter.walking:
		return Pose.STRIDE if fposmod(fighter.walk_distance, 95.0) < 51.0 else Pose.PASS
	return Pose.IDLE


func _attack_pose(tick: int, key_tick: int, hold: int, windup: int, contact: int) -> int:
	if tick < key_tick:
		return windup
	if tick < key_tick + hold:
		return contact
	return windup if tick < key_tick + hold + 4 else Pose.IDLE


func _draw_impact(impact: Impact) -> void:
	var age := float(impact.age)
	if impact.effect in [&"ribbon_low", &"ribbon_high", &"birds", &"image", &"echo"] and impact.style != &"guard":
		_draw_skill_contact(impact, age)
		return
	var special := impact.style in [&"special", &"super", &"final"]
	var finishing := impact.style == &"final"
	var guard := impact.style == &"guard"
	var radius := 173.0 if finishing else (96.0 if special else 51.0)
	var accent := (JADE if guard else CORAL) if impact.side == 0 else ORCHID
	var bright := Color("fff5c6") if not guard else Color("dafcff")
	var energy := maxf(0.0, 1.0 - age / (30.0 if special else 20.0))
	if guard:
		_draw_shield(impact.point, 44.0 + age, Color(bright, energy * 0.8))
	elif special and model.fighters[impact.side].character > Roster.GU:
		var character := model.fighters[impact.side].character
		_draw_campaign_mark(character, impact.point, 26.0 + age * 4.0, impact.direction, age,
			Color(CHARACTER_ACCENTS[character], energy * 0.88))
	if age < 9:
		var burst := radius * (0.43 + age * 0.078)
		for ray in (15 if special else 9):
			var angle := ray * TAU / (15.0 if special else 9.0) + impact.seed * 0.23
			var dir := Vector2.from_angle(angle)
			var length := burst * (0.66 + 0.34 * sin(ray * 17.14 + impact.seed))
			var base := dir.orthogonal() * (7.0 if special else 5.0)
			draw_colored_polygon(PackedVector2Array([impact.point - base, impact.point + dir * length, impact.point + base]), Color(bright, energy))
		draw_circle(impact.point, radius * 0.19 * (1.0 - age / 10.0), Color(bright, energy), true, -1, true)
	if special or guard:
		var sweep := (0.48 + age * 0.023) * radius
		var from := -2.68 + age * 0.052
		var arc_center := impact.point - Vector2(impact.direction * (22.0 if finishing else 29.0), -11.0)
		_draw_ribbon(arc_center, Vector2(sweep, sweep * 0.59), from, from + 3.9, impact.direction,
			(26.0 if finishing else 13.0) * energy, Color(accent, energy * 0.91))
		_draw_ribbon(arc_center, Vector2(sweep + 8.0, (sweep + 8.0) * 0.59), from - 0.18, from + 3.66, impact.direction,
			(11.0 if finishing else 5.0) * energy, Color(bright, energy * 0.91))
	for ray in (23 if special else 10):
		var angle := sin((ray * 0.839 + impact.seed) * 2.63) * 2.34
		var dir := Vector2(cos(angle) * impact.direction, sin(angle))
		var rate := 2.2 + (ray % 6) * (0.92 if special else 0.54)
		var tip := impact.point + dir * (age + 2.0) * rate + Vector2(0.0, age * age * 0.027)
		var tail := tip - dir * rate * (4.0 if special else 2.7)
		draw_line(tail, tip, Color(accent if ray % 3 == 0 else bright, energy), (3.0 if special else 2.0), true)


func _draw_ribbon(center: Vector2, radii: Vector2, start: float, finish: float, direction: float, width: float, color: Color) -> void:
	if width < 0.4:
		return
	var points := PackedVector2Array()
	var inner := PackedVector2Array()
	for index in 24:
		var progress := float(index) / 23.0
		var angle := lerpf(start, finish, progress)
		var normal := Vector2(cos(angle) * direction, sin(angle))
		var taper := maxf(0.012, sin(progress * PI)) * width
		points.append(center + normal * (radii + Vector2.ONE * taper * 0.5))
		inner.append(center + normal * (radii - Vector2.ONE * taper * 0.5))
	inner.reverse()
	points.append_array(inner)
	draw_colored_polygon(points, color)


func _draw_skill_gesture(fighter: Rules.Fighter) -> void:
	var age := float(fighter.move_tick)
	var at := Vector2(fighter.x, FLOOR - fighter.height)
	var dir := fighter.facing
	match fighter.move:
		&"lane_step":
			_draw_canvass_flags(at, dir, age)
			if age >= 3.0 and age < 17.0:
				var fade := 1.0 - smoothstep(8.0, 17.0, age)
				for streak in 4:
					var tip := at + Vector2(dir * (42.0 - streak * 13.0), -5.0 - streak * 9.0)
					var tail := tip - Vector2(dir * (28.0 + age * 5.0 + streak * 12.0), -3.0)
					_draw_tapered_stroke(tail, tip, 4.0, Color(GOLD, fade * (0.72 - streak * 0.12)))
			var contact_tick: float = Rules.MOVES[fighter.move]["hits"][0]
			var sweep := clampf((age - contact_tick + 1.0) / 9.0, 0.0, 1.0)
			if sweep > 0.0 and sweep < 1.0:
				var center := at + Vector2(dir * 57.0, -157.0)
				var cut := -1.45 + sweep * 1.65
				_draw_ribbon(center, Vector2(99.0, 74.0), cut - 0.90, cut + 1.68, dir, 24.0 * (1.0 - sweep), Color(JADE, 0.76 * (1.0 - sweep)))
				_draw_ribbon(center, Vector2(103.0, 77.0), cut - 0.66, cut + 1.52, dir, 7.0 * (1.0 - sweep), Color(PAPER, 1.0 - sweep))
		&"second_question":
			var hits: Array = Rules.MOVES[fighter.move]["hits"]
			_draw_debate_caption(at, dir, age, hits[1])
			for beat in hits.size():
				var travel := (age - float(hits[beat])) / 8.0
				if travel < 0.0 or travel >= 1.0:
					continue
				var palm := at + Vector2(dir * (142.0 + travel * 42.0), -202.0 + beat * 27.0)
				var radii := Vector2(15.0 + travel * 27.0, (42.0 + travel * 52.0) * (0.73 + beat * 0.27))
				var color := GLASS if beat == 0 else GOLD
				_draw_ribbon(palm, radii, -1.59, 1.59, dir, (10.0 + beat * 9.0) * (1.0 - travel), Color(color, 0.93 * (1.0 - travel)))
				_draw_ribbon(palm, radii + Vector2(6.0, 8.0), -1.16, 1.16, dir, 4.0 * (1.0 - travel), Color(PAPER, 1.0 - travel))
		_:
			if fighter.character <= Roster.GU or not Rules.is_skill(fighter.move):
				return
			var data: Dictionary = Rules.MOVES[fighter.move]
			var tint: Color = CHARACTER_ACCENTS[fighter.character]
			var slot: int = Roster.SKILLS[fighter.character].find(fighter.move)
			var gag: Array = Roster.SKILL_GAGS[fighter.character][slot]
			var appear := smoothstep(0.0, 4.0, age) * (1.0 - smoothstep(12.0, 24.0, age))
			if appear > 0.01:
				var prop := at + Vector2(dir * (65.0 + age * 1.8), -295.0 - age * 1.1)
				_draw_campaign_prop(gag[0], prop, 1.35 + appear * 0.27, Color(tint, appear * 0.93))
			var counter: Array = data.get("counter", [])
			if not counter.is_empty() and age >= float(counter[0]) and age <= float(counter[1]) and not fighter.counter_used:
				_draw_shield(at + Vector2(dir * 75.0, -178.0), 53.0, Color(tint, 0.75))
			for hit in data["hits"]:
				var swing := (age - float(hit) + 7.0) / 17.0
				if swing > 0.0 and swing < 1.0:
					var point := at + Vector2(dir * lerpf(70.0, float(data["reach"]) - 50.0, swing), -162)
					_draw_campaign_mark(fighter.character, point, lerpf(19.0, 61.0, swing), dir, age,
						Color(tint, sin(swing * PI) * 0.88))


func _draw_canvass_flags(at: Vector2, dir: float, age: float) -> void:
	var opacity := smoothstep(0.0, 3.0, age) * (1.0 - smoothstep(14.0, 25.0, age))
	if opacity < 0.01:
		return
	for index in range(2, -1, -1):
		var size := 1.0 - index * 0.17
		var pole := at + Vector2(-dir * (54.0 + index * (37.0 + age * 1.3)), -250.0 + index * 25.0)
		var tip := pole + Vector2(dir * 12.0, -37.0) * size
		var tail := tip + Vector2(-dir * 92.0, sin(age * 0.8 + index) * 10.0) * size
		var fade := opacity * (1.0 - index * 0.24)
		draw_line(pole + Vector2(-dir * 7.0, 52.0) * size, tip, Color(PAPER, fade * 0.78), 3.0, true)
		var flag := PackedVector2Array([tip, tail, tail + Vector2(dir * 9.0, 39.0) * size, tip + Vector2(0, 42.0 * size)])
		draw_colored_polygon(flag, Color(JADE if index < 2 else GOLD, fade))
		flag.append(tip)
		draw_polyline(flag, Color(PAPER, fade * 0.68), 2.0, true)
		if index == 0:
			draw_string(typeface, tip.lerp(tail, 0.48) + Vector2(-23.0, 27.0), "拜票", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color(INK, fade))


func _draw_debate_caption(at: Vector2, dir: float, age: float, second_hit: int) -> void:
	var fade := smoothstep(0.0, 3.0, age) * (1.0 - smoothstep(24.0, 34.0, age))
	var second := age >= second_hit - 3.0
	var center := Vector2(clampf(at.x + dir * 75.0, 120.0, SIZE.x - 120.0), at.y - 313.0)
	var box := Rect2(center - Vector2(101, 21), Vector2(202, 42))
	draw_rect(box, Color(INK, fade * 0.96))
	draw_rect(box, Color(GOLD if second else GLASS, fade), false, 2.0)
	draw_rect(Rect2(box.position + Vector2(5, 5), Vector2(58, 32)), Color(CORAL, fade))
	_center_text("直播", box.position + Vector2(34, 28), 17, Color(PAPER, fade))
	_center_text("加開一輪！" if second else "交互詰問", center + Vector2(31, 8), 24, Color(PAPER, fade))


func _draw_tapered_stroke(tail: Vector2, tip: Vector2, width: float, color: Color) -> void:
	var edge := (tip - tail).normalized().orthogonal() * width
	var shoulder := tail.lerp(tip, 0.76)
	draw_colored_polygon(PackedVector2Array([tail, shoulder - edge, tip, shoulder + edge]), color)


func _draw_skill_effect(effect: Rules.SkillEffect, origin: Vector2, zoom: float) -> void:
	var data: Dictionary = Rules.EFFECTS[effect.kind]
	var at := Vector2(effect.x, FLOOR - float(data["height"]))
	var progress := clampf(float(effect.age) / float(effect.delay), 0.0, 1.0)
	var dir := effect.direction
	match effect.kind:
		&"ribbon_low", &"ribbon_high":
			_draw_campaign_route(at, dir, effect.age, progress, effect.kind == &"ribbon_high")
		&"birds":
			var landing := Vector2(effect.x, FLOOR)
			var reach: float = data["reach"]
			var settle := float(maxi(0, effect.age - effect.delay)) / float(data["duration"])
			_draw_ground_ring(landing, reach, RALLY_BLUE, progress)
			_draw_floor_arc(landing, reach * (1.22 - progress * 0.56), -PI + progress * TAU, progress * TAU, Color(PAPER, 0.38), 2.0)
			var rally_sign := landing + Vector2(0, 33)
			draw_rect(Rect2(rally_sign - Vector2(61, 14), Vector2(122, 28)), Color(INK, 0.88 * (1.0 - settle)))
			_center_text("青鳥集合", rally_sign + Vector2(0, 8), 21, Color(RALLY_BLUE, 0.92 * (1.0 - settle)))
			var spread := sin(progress * PI)
			var rise := smoothstep(0.0, 0.48, progress)
			var dive := smoothstep(0.52, 1.0, progress)
			var launch := Vector2(effect.source_x + dir * 42.0, FLOOR - 229.0)
			for index in 5:
				var wing := float(index - 2)
				var x := wing * (19.0 + 39.0 * spread) - dir * (88.0 * (1.0 - dive))
				var y := lerpf(-239.0 - 108.0 * spread + absf(wing) * 27.0, -48.0 - absf(wing) * 18.0, dive)
				var center := launch.lerp(landing + Vector2(x, y + settle * 31.0), rise)
				if dive > 0.0:
					var tail := center + Vector2(-dir * (16.0 + wing * 12.0), -74.0 * dive)
					_draw_tapered_stroke(tail, center, 4.0, Color(RALLY_BLUE, 0.52 * dive))
				draw_set_transform(origin + center * zoom, dir * dive * 0.68, Vector2.ONE * zoom)
				_draw_bird(Vector2.ZERO, (0.63 - absf(wing) * 0.12) + dive * 0.32, sin(effect.age * 0.38 + index) * (1.0 - dive * 0.72), dir, RALLY_BLUE, minf(1.0, progress * 3.0) * (1.0 - settle))
				draw_set_transform(origin, 0.0, Vector2.ONE * zoom)
		&"image":
			var atlas: Texture2D = CHARACTER_ATLASES[Roster.GU]
			var point := Vector2(effect.x, FLOOR) * zoom + origin
			var fracture := float(maxi(0, effect.age - effect.delay)) / float(data["duration"])
			_draw_sprite(atlas, Pose.GUARD, point + Vector2(-dir * 13.0, 0) * zoom, zoom * 0.88, dir, -dir * 0.04, Color(GLASS, 0.45 * (1.0 - fracture)))
			_draw_sprite(atlas, Pose.LUNGE, point + Vector2(dir * 14.0, 0) * zoom, zoom * 0.88, dir, 0.0, Color(GLASS.lightened(0.3), 0.49 * progress * (1.0 - fracture)))
			draw_set_transform(origin, 0.0, Vector2.ONE * zoom)
			_draw_ground_ring(Vector2(effect.x, FLOOR), data["reach"], GLASS, progress * (1.0 - fracture))
			_draw_verification_card(Vector2(effect.x + dir * 30.0, FLOOR - 216.0), 1.0 - fracture)
			for index in 7:
				var x := float((index * 71) % 118) - 56.0 + fracture * (28.0 + index * 12.0)
				var y := -35.0 - float((index * 43) % 167) + fracture * (index - 3) * 12.0
				var shard := Vector2(effect.x + dir * x, FLOOR + y)
				draw_colored_polygon(PackedVector2Array([shard, shard + Vector2(dir * 24, -5), shard + Vector2(dir * 6, 6 + index % 3 * 5)]), Color(GLASS, (1.0 - fracture) * progress * 0.76))
		&"echo":
			_draw_echo(effect, at, data["speed"], progress)
		_:
			_draw_campaign_effect(effect, at, data, progress)


func _draw_campaign_effect(effect: Rules.SkillEffect, at: Vector2, data: Dictionary, charge: float) -> void:
	var character := model.fighters[effect.side].character
	var tint: Color = CHARACTER_ACCENTS[character]
	var age := float(effect.age)
	var ground := Vector2(at.x, FLOOR)
	var reach: float = data["reach"]
	var elapsed := maxf(0.0, age - effect.delay)
	var alpha := 1.0 - smoothstep(float(data["duration"]) * 0.81, float(data["duration"]), elapsed)
	if effect.kind == &"overload":
		var flash := 1.0 - clampf(elapsed / float(data["duration"]), 0.0, 1.0)
		_draw_ground_ring(ground, reach, tint, 0.40 + charge * 0.60)
		for ring in 3:
			_draw_floor_arc(ground, reach * (0.28 + ring * 0.31), -PI, TAU, Color(tint, flash * charge), 2.0 + ring)
		_draw_campaign_prop(&"stamp", at - Vector2(0, 30), 1.35 + charge * 0.50, Color(tint, flash))
		return
	if effect.kind == &"chairs":
		_draw_ground_ring(ground, reach, tint, charge)
		for index in 5:
			var rise := smoothstep(float(index) * 0.12, 0.42 + index * 0.12, charge)
			var stool := ground + Vector2((index - 2) * 28.0, -55.0 * rise)
			_draw_campaign_prop(&"chair", stool, 1.26, Color(tint, rise * alpha))
		return
	if effect.kind == &"results":
		for index in 3:
			var card := at + Vector2(effect.direction * -48.0 * index, -12 - index * 23)
			_draw_campaign_prop(&"poll", card, 1.25 - index * 0.18, Color(tint, charge * alpha))
		return
	if effect.kind == &"barrier":
		var rect := Rect2(ground + Vector2(-24, -112), Vector2(48, 112))
		draw_rect(rect, Color(tint, alpha * 0.17))
		draw_rect(rect, Color(tint, alpha * 0.85), false, 3.0)
		draw_line(rect.position, rect.end, Color(PAPER, alpha), 4.0, true)
		draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), Color(PAPER, alpha), 4.0, true)
		_draw_world_label("工期未定", ground - Vector2(0, 124), tint, alpha)
		return
	if effect.kind == &"ridge_marker":
		draw_line(Vector2(effect.source_x, FLOOR), ground, Color(tint, charge * 0.7), 5.0, true)
		_draw_ground_ring(ground, 48.0, tint, charge)
		_draw_world_label("前方改道", ground - Vector2(0, 34), tint, charge)
		return
	if effect.kind == &"barrier_sweep":
		_draw_tapered_stroke(ground - Vector2(effect.direction * 36.0, 1.0),
			ground + Vector2(effect.direction * reach, -18.0), 15.0, Color(tint, alpha * 0.85))
		return
	if effect.kind in [&"wheel", &"line_trap", &"ebb", &"harbor", &"machine"]:
		_draw_ground_ring(ground, reach, tint, charge * alpha)
	if effect.kind == &"harbor" and age < effect.delay:
		for ring in mini(4, 1 + floori(charge * 4.0)):
			_draw_floor_arc(ground, 26.0 + ring * 21.0, -PI, TAU, Color(tint, 0.59), 3.0)
		_draw_world_label(str(maxi(1, 4 - floori(charge * 4.0))), at - Vector2(0, 34), tint, 0.92)
		return
	if effect.kind == &"wheel":
		_draw_wheel(at, 30.0 * maxf(0.42, charge), age * 0.34 * effect.direction, Color(tint, alpha))
		_draw_tapered_stroke(ground - Vector2(effect.direction * 93.0, -6), ground + Vector2(effect.direction * 31, -6), 4.0, Color(tint, alpha * 0.72))
		_draw_world_label("捷運試車", at - Vector2(0, 51), tint, alpha)
		return
	if effect.kind == &"fan":
		var turn := float(data["turn"])
		var flash := maxf(0.0, 1.0 - absf(elapsed - turn) / 5.0)
		var point := at + Vector2(0.0, -sin(elapsed / float(data["duration"]) * PI) * 24.0)
		_draw_campaign_prop(&"fan", point, 1.62 + flash * 0.46, Color(tint, alpha))
		if flash > 0.1:
			_draw_world_label("再送一次", point - Vector2(0, 39), tint, flash)
		return
	if effect.kind == &"copper_bolt":
		_draw_tapered_stroke(at - Vector2(effect.direction * 86.0, 0), at + Vector2(effect.direction * reach, 0), 9.0, Color(tint, alpha))
		_draw_campaign_prop(&"arrow", at, 1.15, Color(PAPER, alpha))
		return
	if effect.kind == &"copper_ray":
		_draw_world_label("都更公告", at - Vector2(0, 37), tint, charge * alpha)
	elif effect.kind == &"machine":
		_draw_campaign_prop(&"poll", at, 1.65, Color(tint, alpha))
		_draw_world_label("更新 %d%%" % mini(99, floori(charge * 100.0)), at - Vector2(0, 52), tint, alpha)
	_draw_campaign_mark(character, at, reach * (0.44 + 0.56 * charge), effect.direction, age, Color(tint, alpha * (0.5 + charge * 0.47)))


func _draw_world_label(label: String, at: Vector2, tint: Color, opacity: float) -> void:
	var width := typeface.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 19.0
	var rect := Rect2(at - Vector2(width * 0.5, 22), Vector2(width, 28))
	draw_rect(rect, Color(INK, opacity * 0.86))
	draw_rect(rect, Color(tint, opacity), false, 1.5)
	_center_text(label, at, 17, Color(PAPER, opacity))


func _draw_shield(at: Vector2, radius: float, tint: Color) -> void:
	var edge := PackedVector2Array()
	for point in [Vector2(-0.72, -0.71), Vector2(0, -0.97), Vector2(0.72, -0.71),
			Vector2(0.66, 0.22), Vector2(0, 0.90), Vector2(-0.66, 0.22), Vector2(-0.72, -0.71)]:
		edge.append(at + point * radius)
	draw_colored_polygon(edge.slice(0, -1), Color(tint, tint.a * 0.16))
	draw_polyline(edge, tint, maxf(1.6, radius * 0.06), true)


func _draw_wheel(at: Vector2, radius: float, angle: float, tint: Color) -> void:
	var width := maxf(1.5, radius * 0.11)
	draw_arc(at, radius, 0.0, TAU, 40, tint, width, true)
	draw_arc(at, radius * 0.70, 0.0, TAU, 40, Color(PAPER, tint.a * 0.53), width * 0.6, true)
	for tooth in 8:
		var axis := Vector2.from_angle(angle + tooth * TAU / 8.0)
		draw_line(at + axis * radius * 0.19, at + axis * radius * 1.09, tint, width, true)


func _draw_campaign_mark(character: int, at: Vector2, radius: float, dir: float, age: float, tint: Color) -> void:
	var width := maxf(1.5, radius * 0.075)
	match character:
		Roster.PEI:
			for ray in 3:
				var tip := at + Vector2(dir, (ray - 1) * 0.42) * radius
				_draw_tapered_stroke(tip - Vector2(dir * radius * 1.65, 0), tip, width * 1.5, tint)
				draw_polyline(PackedVector2Array([tip - Vector2(dir * 0.50, 0.30) * radius, tip,
					tip - Vector2(dir * 0.50, -0.30) * radius]), Color(PAPER, tint.a), width, true)
		Roster.SHI:
			var apex := at - Vector2(0, radius * 0.72)
			var left := at + Vector2(-radius, radius * 0.49)
			var right := at + Vector2(radius, radius * 0.49)
			draw_polyline(PackedVector2Array([left, apex, right, left]), tint, width * 1.5, true)
			draw_line(apex, at + Vector2(0, radius * 0.49), Color(PAPER, tint.a * 0.72), width, true)
			for pivot in [left, apex, right]:
				draw_circle(pivot, width * 1.2, Color(PAPER, tint.a), true, -1, true)
		Roster.LU:
			for lane in 3:
				var front := at + Vector2(dir * 1.02, (lane - 1) * 0.45) * radius
				_draw_tapered_stroke(front - Vector2(dir * (radius * 1.72 + lane * width), radius * 0.35), front, width * 1.45, tint)
				draw_circle(front, width * 1.3, Color(PAPER, tint.a), true, -1, true)
		Roster.RUAN:
			for wave in 3:
				var offset := at + Vector2(-dir * wave * radius * 0.37, wave * radius * 0.15)
				_draw_ribbon(offset, Vector2(radius * 0.7, radius * (0.93 - wave * 0.18)), -2.65, 0.40, dir,
					width * 2.2, Color(tint.lerp(PAPER, 0.23 * wave), tint.a))
		Roster.WEN:
			var spin := sin(age * 0.3) * 0.64
			for blade in 5:
				var angle := -PI * 0.90 + blade * PI * 0.20 + spin
				var edge := at + Vector2(cos(angle) * dir, sin(angle)) * radius
				draw_line(at, edge, tint, width, true)
			_draw_ribbon(at, Vector2.ONE * radius, -PI * 0.92 + spin, -PI * 0.08 + spin, dir, width * 2.6, tint)
		Roster.FANG:
			_draw_wheel(at, radius * 0.74, age * 0.18 * dir, tint)
		Roster.HONG:
			_draw_campaign_prop(&"poll", at, radius / 27.0, tint)


func _draw_skill_callouts() -> void:
	for side in 2:
		var card: Dictionary = callouts[side]
		if card.is_empty():
			continue
		var age := float(pulse_clock - int(card["start"]))
		var opacity := smoothstep(0.0, 5.0, age) * (1.0 - smoothstep(93.0, 112.0, age))
		if opacity > 0.01:
			var at := Vector2(62 if side == 0 else 900, 131 + (39 if side == 1 else 0))
			_draw_gag_card(card["gag"], at, CHARACTER_ACCENTS[card["character"]], smoothstep(9.0, 19.0, age), opacity)


func _draw_gag_card(gag: Array, at: Vector2, accent: Color, reveal: float, opacity: float) -> void:
	var header: String = gag[1]
	var punchline: String = gag[2]
	var width := maxf(typeface.get_string_size(header, HORIZONTAL_ALIGNMENT_LEFT, -1, 25).x,
		typeface.get_string_size(punchline, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x) + 82.0
	var rect := Rect2(at, Vector2(width, 77))
	draw_rect(rect, Color(INK, opacity * 0.87))
	draw_rect(rect, Color(accent, opacity * 0.74), false, 1.5)
	draw_rect(Rect2(at, Vector2(4, 77)), Color(accent, opacity))
	_draw_campaign_prop(gag[0], at + Vector2(36, 39), 0.95, Color(accent, opacity))
	_text(header, at + Vector2(66, 32), 25, Color(accent, opacity))
	_text(punchline, at + Vector2(66, 60), 20, Color(PAPER, opacity * reveal))


func _draw_campaign_prop(kind: StringName, at: Vector2, scale: float, tint: Color) -> void:
	var rect := Rect2(at - Vector2(21, 16) * scale, Vector2(42, 32) * scale)
	var line := maxf(1.5, 2.2 * scale)
	match kind:
		&"flag":
			draw_line(at + Vector2(-17, 23) * scale, at + Vector2(-17, -24) * scale, tint, line, true)
			draw_colored_polygon(PackedVector2Array([at + Vector2(-16, -22) * scale, at + Vector2(21, -17) * scale,
				at + Vector2(10, -7) * scale, at + Vector2(21, 1) * scale, at + Vector2(-16, -3) * scale]), tint)
		&"mic":
			draw_line(at + Vector2(-12, 21) * scale, at + Vector2(11, -12) * scale, tint, line * 2.5, true)
			draw_circle(at + Vector2(12, -12) * scale, 10.0 * scale, tint, true, -1, true)
			draw_line(at + Vector2(5, -15) * scale, at + Vector2(18, -6) * scale, Color(INK, tint.a), line, true)
		&"fan":
			var points := PackedVector2Array([at + Vector2(0, 17) * scale])
			for blade in 7:
				var tip := at + Vector2.from_angle(-2.71 + blade * 0.38) * 23.0 * scale
				points.append(tip)
			draw_colored_polygon(points, Color(tint, tint.a * 0.35))
			for blade in range(1, points.size()):
				draw_line(points[0], points[blade], tint, line * 0.62, true)
		&"route":
			var points := PackedVector2Array([at + Vector2(-19, 14) * scale, at + Vector2(-8, -8) * scale,
				at + Vector2(7, 4) * scale, at + Vector2(19, -15) * scale])
			draw_polyline(points, tint, line, true)
			for stop in points:
				draw_circle(stop, 3.8 * scale, Color(PAPER, tint.a), true, -1, true)
		&"arrow":
			draw_line(at + Vector2(-19, 17) * scale, at + Vector2(20, -19) * scale, tint, line * 1.5, true)
			draw_polyline(PackedVector2Array([at + Vector2(5, -18) * scale, at + Vector2(20, -19) * scale,
				at + Vector2(18, -4) * scale]), tint, line * 1.5, true)
		&"ribbon":
			draw_rect(Rect2(at + Vector2(-21, -4) * scale, Vector2(42, 9) * scale), Color(CORAL, tint.a))
			for side in [-1, 1]:
				draw_circle(at + Vector2(side * 10, 15) * scale, 6.3 * scale, tint, false, line, true)
				draw_line(at + Vector2(side * 7, 11) * scale, at + Vector2(-side * 12, -16) * scale, tint, line, true)
		&"chair":
			draw_rect(Rect2(at + Vector2(-13, -16) * scale, Vector2(26, 14) * scale), Color(tint, tint.a * 0.7))
			draw_line(at + Vector2(-16, 4) * scale, at + Vector2(16, 4) * scale, tint, line * 2.0, true)
			draw_line(at + Vector2(-11, 4) * scale, at + Vector2(8, 22) * scale, tint, line, true)
			draw_line(at + Vector2(11, 4) * scale, at + Vector2(-8, 22) * scale, tint, line, true)
		&"barrier":
			draw_rect(rect, tint, false, line)
			for stripe in [-13, 0, 13]:
				draw_line(at + Vector2(stripe - 6, 13) * scale, at + Vector2(stripe + 6, -13) * scale, tint, line, true)
		&"poll":
			draw_rect(rect, Color(INK, tint.a * 0.93))
			draw_rect(rect, tint, false, line)
			for column in 3:
				var height: float = [11.0, 7.0, 22.0][column] * scale
				draw_rect(Rect2(at + Vector2((-12.0 + column * 11.0) * scale, 10.0 * scale - height), Vector2(7.0 * scale, height)), tint)
		_:
			draw_rect(rect, tint, false, line)
			for row in 3:
				draw_line(at + Vector2(-13, -8 + row * 8) * scale, at + Vector2(11 - row * 4, -8 + row * 8) * scale, tint, line, true)
			if kind == &"stamp":
				draw_circle(at + Vector2(14, 8) * scale, 9.0 * scale, Color(CORAL, tint.a), false, line * 1.5, true)


func _draw_campaign_route(at: Vector2, dir: float, age: float, progress: float, high: bool) -> void:
	var accent := JADE if high else GOLD
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	var centerline := PackedVector2Array()
	for index in 19:
		var t := float(index) / 18.0
		var point := at + Vector2(dir * lerpf(-119.0, 29.0, t), sin(t * TAU - age * 0.47) * sin(t * PI) * (27.0 if high else 17.0)) * lerpf(0.45, 1.0, progress)
		var width := maxf(0.2, sin(t * PI) * 5.0 * progress + (7.0 if high else 10.0) * progress)
		top.append(point - Vector2(0, width))
		bottom.append(point + Vector2(0, width))
		centerline.append(point)
	var strip := top.duplicate()
	var underside := bottom.duplicate()
	underside.reverse()
	strip.append_array(underside)
	draw_colored_polygon(strip, Color(INK.lerp(accent, 0.21), 0.52 + progress * 0.39))
	draw_polyline(top, Color(accent, progress), 3.0, true)
	draw_polyline(bottom, Color(accent, progress * 0.82), 2.0, true)
	for index in range(1, 17, 4):
		draw_line(centerline[index], centerline[index + 2], Color(PAPER, progress * 0.87), 2.0, true)
	var tip := centerline[-1]
	draw_circle(tip, 8.0 * progress, Color(accent, progress), true, -1, true)
	draw_circle(tip, 4.0 * progress, Color(INK, progress), true, -1, true)
	var label := Rect2(tip + Vector2(-33.0, -39.0), Vector2(66, 24))
	draw_rect(label, Color(INK, progress * 0.91))
	draw_rect(label, Color(accent, progress), false, 1.5)
	_center_text("支線" if high else "幹道", label.get_center() + Vector2(0, 7), 18, Color(PAPER, progress))


func _draw_verification_card(at: Vector2, opacity: float) -> void:
	var box := Rect2(at - Vector2(67, 32), Vector2(134, 64))
	draw_rect(box, Color(INK, opacity * 0.96))
	draw_rect(box, Color(GLASS, opacity), false, 2.0)
	for index in 3:
		var line := box.position + Vector2(9.0, 36.0 + index * 8.0)
		draw_line(line, line + Vector2(76.0 - index * 13.0, 0), Color(GLASS, opacity * 0.57), 2.0, true)
	_center_text("請附來源", at + Vector2(0, -8), 22, Color(PAPER, opacity))
	_center_text("？", at + Vector2(47, 19), 27, Color(GOLD, opacity))


func _draw_echo(effect: Rules.SkillEffect, at: Vector2, speed: float, progress: float) -> void:
	var dir := effect.direction
	var travel := effect.age - effect.delay
	var accent: Color = ECHO_COLORS[effect.wave]
	if travel < 7:
		var opacity := 1.0 - smoothstep(0.0, 7.0, float(travel))
		var source := at - Vector2(dir * speed * maxi(0, travel + 1), 0.0)
		var bob := roundf(sin(effect.age * 0.34 + effect.wave * 2.1) * 2.0) * 4.0
		var top := source + Vector2(0, bob - 25.0 + (1.0 - progress) * 8.0)
		var body := Rect2(top - Vector2(16, 11), Vector2(32, 32))
		draw_rect(body, Color(INK, opacity * 0.92))
		draw_rect(body, Color(accent, opacity * 0.92), false, 3.0)
		for side in [-1, 1]:
			draw_rect(Rect2(top + Vector2(side * 11 - 3, -19), Vector2(6, 9)), Color(accent, opacity))
			draw_rect(Rect2(top + Vector2(side * 7 - 2, -2), Vector2(5, 6)), Color(PAPER, opacity))
			draw_rect(Rect2(top + Vector2(side * 11 - 4, 23), Vector2(8, 5)), Color(accent, opacity * 0.84))
		draw_rect(Rect2(top + Vector2(-9.0, 12.0), Vector2(18.0 * progress, 4.0)), Color(accent, opacity * 0.90))
		if travel < 0:
			for dot in 3:
				var y := -27.0 - (3.0 if posmod(travel + dot, 6) < 2 else 0.0)
				draw_rect(Rect2(top + Vector2((dot - 1) * 9.0 - 2.0, y), Vector2(4.0, 4.0)), Color(accent, opacity))
	if travel >= 0:
		for tile in range(3, 7):
			var drift := sin(travel * 0.50 + tile * 1.7) * (5.0 + tile * 1.8)
			var point := at + Vector2(-dir * tile * 11.0, drift)
			point = (point / 4.0).round() * 4.0
			var size := Vector2(26.0 - tile * 2.8, 20.0 - tile * 2.4)
			var opacity := 1.0 - tile * 0.12
			draw_rect(Rect2(point - size * 0.5, size), Color(accent, opacity))
		_draw_echo_message(at, dir, effect.wave, 1.0)


func _draw_echo_message(at: Vector2, dir: float, wave: int, opacity: float) -> void:
	var accent := Color(ECHO_COLORS[wave], opacity)
	var box := Rect2(at - Vector2(30, 17), Vector2(60, 34))
	var tail := at - Vector2(dir * 27.0, 2.0)
	draw_colored_polygon(PackedVector2Array([tail + Vector2(0, -2), tail - Vector2(dir * 15.0, -9), tail + Vector2(0, 12)]), accent)
	draw_rect(box, Color(INK, opacity))
	draw_rect(box, accent, false, 2.0)
	_center_text(ECHO_MESSAGES[wave], at + Vector2(0, 8), 22, Color(PAPER, opacity))


func _draw_skill_contact(impact: Impact, age: float) -> void:
	if age >= 25.0:
		return
	var accent := JADE
	var radius := 66.0
	match impact.effect:
		&"ribbon_low": accent = GOLD
		&"image": accent = GLASS
		&"echo": accent = ECHO_COLORS[impact.wave]
		&"birds":
			accent = RALLY_BLUE
			radius = 110.0
	var energy := 1.0 - smoothstep(0.0, 25.0, age)
	if impact.effect == &"birds":
		var landing := Vector2(impact.effect_x, FLOOR)
		_draw_floor_arc(landing, 30.0 + age * 6.0, 0.0, TAU, Color(accent, energy * 0.72), 3.0)
		_draw_floor_arc(landing, 15.0 + age * 4.2, 0.0, TAU, Color(PAPER, energy * 0.81), 2.0)
	elif impact.effect == &"image":
		var center := Vector2(impact.effect_x, FLOOR - 130.0)
		var radii := Vector2(25.0 + age * 5.0, 75.0 + age * 2.0)
		_draw_ribbon(center, radii, -1.43, 1.60, impact.direction, energy * 15.0, Color(GLASS, energy * 0.8))
		_draw_ribbon(center, radii + Vector2(9.0, -15.0), -1.22, 1.44, impact.direction, energy * 4.0, Color(PAPER, energy * 0.77))
		var stamp := Rect2(center - Vector2(49.0, 100.0 + age * 1.45), Vector2(98, 42))
		draw_rect(stamp, Color(INK, energy * 0.94))
		draw_rect(stamp, Color(CORAL, energy), false, 3.0)
		_center_text("退件", stamp.get_center() + Vector2(0, 11), 28, Color(PAPER, energy))
	elif impact.effect == &"echo":
		_draw_echo_message(impact.point + Vector2(0, -age * 2.8 - 20.0), impact.direction, impact.wave, energy)
	if age < 9.0:
		draw_circle(impact.point, radius * (0.21 - age * 0.014), Color(PAPER, energy * 0.89), true, -1, true)
	for index in (18 if impact.effect == &"birds" else 10):
		var angle := float(index) * 2.39996 + impact.seed
		var direction := Vector2(cos(angle), sin(angle))
		var speed := radius * (0.021 + (index % 4) * 0.011)
		var point := impact.point + direction * (8.0 + age * speed) + Vector2(0, age * age * 0.038)
		var color := Color(accent if index % 3 else PAPER, energy)
		if impact.effect == &"echo":
			var tile := Vector2.ONE * ((index % 3 + 1) * 3.0 + 2.0)
			draw_rect(Rect2((point / 3.0).round() * 3.0, tile), color)
		else:
			var flank := direction.orthogonal() * (3.0 + index % 3 * 2.0)
			draw_colored_polygon(PackedVector2Array([point - flank, point + direction * speed * 5.0, point + flank]), color)


func _draw_floor_arc(at: Vector2, radius: float, start: float, end: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for index in 33:
		var angle := lerpf(start, end, float(index) / 32.0)
		points.append(at + Vector2(cos(angle), sin(angle) * 0.23) * radius)
	draw_polyline(points, color, width, true)


func _draw_ground_ring(at: Vector2, radius: float, color: Color, charge: float) -> void:
	var points := PackedVector2Array()
	for index in 40:
		var angle := float(index) * TAU / 40.0
		points.append(at + Vector2(cos(angle), 0.23 * sin(angle)) * radius)
	draw_colored_polygon(points, Color(color, 0.07 + charge * 0.13))
	points.append(points[0])
	draw_polyline(points, Color(color, 0.45 + charge * 0.45), 2.0 + charge * 2.0, true)
	draw_line(at + Vector2(-8, 0), at + Vector2(8, 0), Color(color, 0.85), 2.0)
	draw_line(at + Vector2(0, -5), at + Vector2(0, 5), Color(color, 0.85), 2.0)


func _draw_bird(at: Vector2, scale: float, flap: float, direction: float, accent: Color, opacity: float) -> void:
	if scale <= 0.02 or opacity <= 0.01:
		return
	var wing := 30.0 + flap * 16.0
	var v := Vector2(scale * direction, scale)
	var ridge := at + Vector2(-4.0, -3.0) * v
	var belly := at + Vector2(7.0, 13.0) * v
	var shoulder := at + Vector2(23.0, 3.0) * v
	var brow := at + Vector2(27.0, -12.0) * v
	var beak := at + Vector2(43.0, -9.0) * v
	var tail := at + Vector2(-41.0, 5.0) * v
	var near_tip := at + Vector2(-47.0, -wing - 11.0) * v
	var far_tip := at + Vector2(-22.0, wing * 0.68) * v
	draw_colored_polygon(PackedVector2Array([ridge, far_tip, shoulder]), Color(Color("246166").lerp(accent, 0.37), opacity))
	draw_colored_polygon(PackedVector2Array([tail, ridge, shoulder, belly]), Color(accent, opacity))
	draw_colored_polygon(PackedVector2Array([near_tip, ridge, belly]), Color(PAPER.lerp(accent, 0.21), opacity))
	draw_colored_polygon(PackedVector2Array([near_tip, belly, at + Vector2(-31.0, -5.0) * v]), Color(accent, opacity))
	draw_colored_polygon(PackedVector2Array([shoulder, brow, beak]), Color(PAPER.lerp(accent, 0.38), opacity))
	draw_line(ridge, belly, Color(PAPER, opacity * 0.79), maxf(1.0, scale * 0.73), true)


func _draw_speed_lines(finale: float) -> void:
	var age := model.super_tick
	var from := Vector2(640.0, 398.0)
	var accent: Color = CHARACTER_ACCENTS[model.fighters[model.super_side].character]
	var opacity := 0.30 * (1.0 - smoothstep(finale, finale + 20.0, age))
	for index in 31:
		var angle := TAU * (float(index) / 31.0) + sin(index * 11.74) * 0.14
		var line := Vector2.from_angle(angle) * Vector2(1.67, 0.85)
		var point := fposmod(float(age) * (6.0 + index % 7) + index * 59.0, 355.0) + 255.0
		var end := point + 34.0 + (index % 8) * 13.0
		draw_line(from + line * point, from + line * end, Color(PAPER if index % 3 == 0 else accent, opacity), 1.4, true)


func _draw_super_scenery(age: float, finale: float) -> void:
	var attacker := model.fighters[model.super_side]
	var progress := clampf((age - Rules.SUPER_PORTRAIT_END) / (finale - Rules.SUPER_PORTRAIT_END), 0.0, 1.0)
	var vanish := 1.0 - smoothstep(finale + 6.0, finale + 22.0, age)
	var gag: Array = Roster.SUPER_GAGS[attacker.character]
	var accent: Color = CHARACTER_ACCENTS[attacker.character]
	if attacker.character != Roster.HONG:
		for index in 4:
			var side := -1.0 if index % 2 == 0 else 1.0
			var at := Vector2(640 + side * (250.0 + index * 72.0), 483 - index * 74.0)
			var opacity := smoothstep(index * 0.14, index * 0.14 + 0.26, progress) * vanish
			_draw_campaign_prop(gag[0], at, 2.0 + index * 0.27, Color(accent, opacity * 0.53))
	if attacker.character > Roster.GU:
		_draw_campaign_super(Vector2(640, 416), attacker, age, progress, vanish)
		return
	if attacker.character == Roster.LIU:
		for depth in range(7, 0, -1):
			var z := fposmod(depth * 0.137 + progress * 0.83, 1.0)
			var radii := Vector2(62.0, 30.0) + Vector2(680.0, 385.0) * z * z
			var center := Vector2(640, 355) + Vector2(-attacker.facing * z * 69.0, z * 106.0)
			_draw_ribbon(center, radii, -2.9, 0.09, 1.0, 7.0 + z * 8.0, Color(JADE, z * vanish * 0.47))
			_draw_ribbon(center, radii, 0.24, 2.88, 1.0, 4.0 + z * 8.0, Color(PAPER, z * vanish * 0.41))
			_draw_bird(center + Vector2(cos(depth * 2.6) * radii.x, sin(depth * 2.6) * radii.y),
				0.35 + z * 1.03, sin(age * 0.22 + depth), attacker.facing, JADE, vanish * 0.84)
	else:
		for depth in 8:
			var size := 15.0 + depth * 6.0
			var glow := smoothstep(depth * 0.084, depth * 0.084 + 0.12, progress) * vanish
			for direction in [-1, 1]:
				var at := Vector2(640.0 + direction * (84.0 + depth * depth * 9.0), 304.0 - depth * 23.0)
				draw_line(Vector2(640, 301), at, Color(GOLD, glow * 0.51), 1.5)
				draw_circle(at, size * 0.92, Color(GOLD, glow * 0.12), true, -1, true)
				draw_circle(at, size * 0.45, Color(CORAL.lerp(GOLD, 0.68), glow * 0.86), true, -1, true)
				draw_rect(Rect2(at - Vector2(size * 0.19, size * 0.37), Vector2(size * 0.38, size * 0.75)), Color(PAPER, glow * 0.72))
				for offset in [-0.19, 0.0, 0.19]:
					var rib := at + Vector2(offset * size, 0.0)
					draw_line(rib - Vector2(0.0, size * 0.34), rib + Vector2(0.0, size * 0.34), Color(CORAL, glow * 0.64), 1.4, true)
				draw_line(at + Vector2(0.0, size * 0.40), at + Vector2(0.0, size * 0.60), Color(GOLD, glow * 0.93), 1.6, true)
				var reflection := Vector2(at.x, 592.0 + depth * 5.0)
				draw_line(reflection - Vector2(size, 0), reflection + Vector2(size * 1.6, 0), Color(GOLD, glow * 0.43), 3.0)


func _draw_super_foreground(age: float, finale: float) -> void:
	var attacker := model.fighters[model.super_side]
	var defender := model.fighters[1 - model.super_side]
	var at := Vector2(defender.x, FLOOR - defender.height - 154.0)
	var accent: Color = CHARACTER_ACCENTS[attacker.character]
	if attacker.character > Roster.GU:
		var wind := smoothstep(finale - 24.0, finale, age)
		var fade := 1.0 - smoothstep(finale, finale + 18.0, age)
		if age < Rules.SUPER_SLOW_END:
			_draw_campaign_mark(attacker.character, at, 40.0 + age * 3.2, attacker.facing, age, Color(accent, 1.0 - age / 23.0))
		elif wind * fade > 0.01:
			_draw_campaign_mark(attacker.character, at, 112.0 + wind * 93.0 + (1.0 - fade) * 84.0,
				attacker.facing, age, Color(accent, wind * fade))
		return
	if age < Rules.SUPER_SLOW_END:
		var expansion := age / float(Rules.SUPER_SLOW_END)
		for shard in 13:
			var dir := Vector2.from_angle(shard * TAU / 13.0 + 0.15)
			var center := at + dir * (38.0 + expansion * (76.0 + shard % 4 * 13.0))
			if attacker.character == Roster.LIU:
				_draw_bird(center, 0.16 + shard % 3 * 0.05, 0.25, attacker.facing, accent, 0.89)
			else:
				draw_rect(Rect2(center - Vector2(4, 4), Vector2.ONE * (7.0 + shard % 4 * 2.0)), Color(GOLD, 0.83))
		return
	if age < finale - 18.0 or age > finale + 18.0:
		return
	var windup := smoothstep(finale - 18.0, finale, age)
	var fallout := 1.0 - smoothstep(finale, finale + 18.0, age)
	if attacker.character == Roster.LIU:
		if age <= finale:
			var swoop := at + Vector2(-attacker.facing * (560.0 * (1.0 - windup) + 46.0), -320.0 * (1.0 - windup) - 39.0)
			_draw_bird(swoop, 2.5 + windup * 0.83, sin(age * 0.32), attacker.facing, JADE, 0.76)
		else:
			for shard in 23:
				var dir := Vector2.from_angle(shard * TAU / 23.0)
				_draw_bird(at + dir * (44.0 + (age - finale) * (8.0 + shard % 4)), fallout * 0.58,
					0.3, attacker.facing, JADE, fallout)
	else:
		var flame := windup * fallout
		for pillar in 3:
			var p := at + Vector2(attacker.facing * (pillar - 1) * 25.0, 64.0)
			var upper := p - Vector2(attacker.facing * (8.0 + pillar * 13.0), (143.0 + pillar * 41.0) * flame)
			var edge := (8.0 + pillar * 3.0) * flame
			if edge > 0.6:
				draw_colored_polygon(PackedVector2Array([p - Vector2(edge, 0.0), upper, p + Vector2(edge, 0.0)]),
					Color(GOLD if pillar % 2 else PAPER, flame * 0.54))
		for ring in 4:
			var center := at - Vector2(attacker.facing * (26.0 - ring * 14.0), ring * 38.0)
			var radius := 45.0 + ring * 15.0 + (1.0 - fallout) * 170.0
			_draw_ribbon(center, Vector2(radius, radius * 0.74), -2.8 + ring * 0.17, 2.6,
				attacker.facing, flame * (18.0 - ring * 2.0), Color(GOLD if ring % 2 else PAPER, flame * 0.86))
		for shard in 22:
			var dir := Vector2.from_angle(shard * TAU / 22.0 - 0.9)
			var point := at + dir * (46.0 + windup * 80.0 + (1.0 - fallout) * (108.0 + shard % 4 * 25.0))
			draw_rect(Rect2(point, Vector2.ONE * (4.0 + shard % 5 * 3.0)), Color(GOLD if shard % 3 else PAPER, flame))


func _draw_campaign_super(center: Vector2, attacker: Rules.Fighter, age: float, phase: float, fade: float) -> void:
	var tint: Color = CHARACTER_ACCENTS[attacker.character]
	var dir := attacker.facing
	match attacker.character:
		Roster.PEI:
			for index in 8:
				var unit := Vector2.from_angle(index * TAU / 8.0 + phase * 0.45)
				var at := center + unit * Vector2(258.0, 134.0) * (1.18 - phase * 0.22)
				var lit := fade * smoothstep(index * 0.10, index * 0.10 + 0.13, phase)
				draw_line(center + unit * 75.0, at, Color(tint, lit * 0.45), 2.5, true)
				_draw_campaign_mark(attacker.character, at, 33.0 + phase * 15.0, dir, age, Color(tint, lit))
		Roster.SHI:
			for index in 5:
				var extent := 490.0 - index * 81.0
				var y := 124.0 - index * 42.0
				var close := smoothstep(index * 0.10, index * 0.10 + 0.32, phase)
				for side in [-1, 1]:
					var at := center + Vector2(side * (extent * (1.24 - close * 0.40)), y)
					_draw_campaign_mark(attacker.character, at, 90.0, float(side), age, Color(tint, fade * close * 0.60))
		Roster.LU:
			for lane in 6:
				var track := fposmod(phase * 2.8 + lane * 0.14, 1.0)
				var at := center + Vector2(dir * lerpf(-480.0, 460.0, track), lane * 29.0 - 102.0)
				_draw_campaign_mark(attacker.character, at, 68.0 + lane * 11.0, dir, age, Color(tint, fade * sin(track * PI)))
		Roster.RUAN:
			for wave in 4:
				var crest := smoothstep(wave * 0.16, 0.27 + wave * 0.16, phase)
				var at := center + Vector2(dir * (-290.0 + wave * 135.0), 119.0 - crest * (53.0 + wave * 25.0))
				_draw_campaign_mark(attacker.character, at, 81.0 + 31.0 * wave, dir, age, Color(tint, fade * crest * 0.65))
		Roster.WEN:
			for ring in 5:
				var lit := smoothstep(ring * 0.12, ring * 0.12 + 0.22, phase)
				var scale := (47.0 + ring * 33.0) * (1.12 - phase * 0.20)
				var at := center + Vector2(dir * (ring - 2) * 86.0, -ring * 6.0)
				_draw_ribbon(at, Vector2(scale, scale * 0.61), -PI + 0.05, PI - 0.05, dir,
					9.0 + ring * 1.5, Color(tint.lerp(PAPER, ring * 0.13), fade * lit * 0.75))
		Roster.FANG:
			var radius := lerpf(57.0, 178.0, phase)
			_draw_wheel(center, radius, age * 0.13, Color(tint, fade * 0.74))
			_draw_wheel(center - Vector2(dir * 195.0, -80.0), radius * 0.47, -age * 0.19, Color(tint, fade * 0.42))
		Roster.HONG:
			for panel in 5:
				var at := center + Vector2((panel - 2) * 185.0, -81.0 + absf(panel - 2.0) * 24.0)
				var reveal := smoothstep(panel * 0.12, 0.18 + panel * 0.12, phase)
				_draw_campaign_prop(&"poll", at, 2.7, Color(tint, reveal * fade))
				_center_text("勝選速報", at + Vector2(0, 69), 25, Color(PAPER, reveal * fade))


func _draw_super_overlay() -> void:
	var age := float(model.super_tick)
	var attacker := model.fighters[model.super_side]
	var character := attacker.character
	var accent: Color = CHARACTER_ACCENTS[character]
	var beats: Array = Roster.SUPER_BEATS[character]
	var finale: float = beats[-1]
	var total: float = Roster.SUPER_LENGTH[character]
	var gag: Array = Roster.SUPER_GAGS[character]
	if age < Rules.SUPER_SLOW_END:
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color(INK, 0.20 * smoothstep(0.0, 12.0, age)))
		if age < 5.0:
			draw_rect(Rect2(Vector2.ZERO, SIZE), Color(accent, 0.26 * (1.0 - age / 5.0)))
	elif age < Rules.SUPER_PORTRAIT_END:
		var elapsed := age - Rules.SUPER_SLOW_END
		var portrait_duration := float(Rules.SUPER_PORTRAIT_END - Rules.SUPER_SLOW_END)
		var fade := 1.0 - smoothstep(portrait_duration - 8.0, portrait_duration, elapsed)
		var zoom := 1.0 + elapsed * 0.0037
		var offset := -SIZE * (zoom - 1.0) * Vector2(0.55, 0.4)
		if attacker.facing < 0.0:
			draw_set_transform(Vector2(SIZE.x, 0), 0.0, Vector2(-1, 1))
		draw_texture_rect(PORTRAITS[character], Rect2(offset, SIZE * zoom), false, Color(1, 1, 1, fade))
		draw_set_transform(Vector2.ZERO)
		var title: String = Roster.SUPER_NAMES[character]
		var title_width := typeface.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 62).x
		var text_x := 63.0 if attacker.facing > 0.0 else SIZE.x - title_width - 63.0
		var slant := Vector2(text_x - attacker.facing * (1.0 - smoothstep(0.0, 7.0, elapsed)) * 42.0, 400.0)
		draw_line(slant + Vector2(0, -46), slant + Vector2(170, -46), Color(accent, fade), 4.0, true)
		_text(Roster.NAMES[character] + "  /  大絕", slant, 24, Color(accent, fade))
		_text(title, slant + Vector2(0, 76), 62, Color(PAPER, fade))
	else:
		_draw_super_finish_overlay(age, finale, attacker, accent)
		_text(Roster.SUPER_NAMES[character], Vector2(46, 88), 29, accent)
		_draw_combo(attacker.combo_display, Vector2(50, 163), accent)
		var line: String = gag[2] if age >= finale else gag[1]
		var label_width := typeface.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x + 88.0
		var subtitle := Rect2(640 - label_width * 0.5, 590, label_width, 63)
		draw_rect(subtitle, Color(INK, 0.86))
		draw_rect(subtitle, Color(accent, 0.72), false, 2.0)
		_draw_campaign_prop(gag[0], subtitle.position + Vector2(35, 31), 0.9, accent)
		_text(line, subtitle.position + Vector2(64, 42), 30, PAPER)
	var frame := 50.0 * smoothstep(0.0, 11.0, age) * (1.0 - smoothstep(finale + 10.0, total, age))
	draw_rect(Rect2(0.0, 0.0, SIZE.x, frame), Color("0a0911"))
	draw_rect(Rect2(0.0, SIZE.y - frame, SIZE.x, frame), Color("0a0911"))


func _draw_super_finish_overlay(age: float, finale: float, attacker: Rules.Fighter, accent: Color) -> void:
	var charge := finale - Rules.SUPER_FINISH_CUE
	if age >= charge and age < charge + 11.0:
		var elapsed := age - charge
		var opacity := (1.0 - smoothstep(8.0, 11.0, elapsed)) * 0.97
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color(INK, opacity * 0.45))
		var sweep := -attacker.facing * (1.0 - smoothstep(0.0, 5.0, elapsed)) * 107.0
		var panel := Vector2(275.0 + sweep, 183.0)
		var points := PackedVector2Array([panel + Vector2(93, 0), panel + Vector2(790, 0),
			panel + Vector2(708, 195), panel + Vector2(7, 195)])
		var u0 := 0.48 if attacker.facing > 0.0 else 0.96
		var u1 := 0.96 if attacker.facing > 0.0 else 0.48
		var uvs := PackedVector2Array([Vector2(u0, 0.13), Vector2(u1, 0.13),
			Vector2(u1, 0.40), Vector2(u0, 0.40)])
		draw_polygon(points, PackedColorArray([Color(1.0, 1.0, 1.0, opacity)]), uvs, PORTRAITS[attacker.character])
		points.append(points[0])
		draw_polyline(points, Color(accent, opacity), 2.5, true)
	if age < finale or age > finale + 11.0:
		return
	var elapsed := age - finale
	var strike := 1.0 - smoothstep(0.0, 9.0, elapsed)
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color(PAPER.lerp(accent, 0.45), strike * 0.45))
	var center := Vector2(692.0 - attacker.facing * 74.0, 389.0)
	for ray in 14:
		var direction := Vector2.from_angle(ray * TAU / 14.0 + 0.15) * Vector2(1.47, 0.95)
		var start := (228.0 + ray % 3 * 56.0) + elapsed * 12.0
		var end := start + 140.0 + ray % 5 * 24.0
		draw_line(center + direction * start, center + direction * end, Color(PAPER if ray % 3 else accent, strike * 0.89),
			float(2 + ray % 4), true)


func _draw_hud() -> void:
	var clock := ceili(float(model.ticks_left) / Rules.TICK_RATE)
	var left_accent: Color = CHARACTER_ACCENTS[player_character]
	var right_accent: Color = CHARACTER_ACCENTS[model.fighters[1].character]
	draw_rect(Rect2(0, 0, SIZE.x, 108), Color(0.03, 0.05, 0.09, 0.67))
	draw_line(Vector2(30, 108), Vector2(1250, 108), Color(1, 0.84, 0.66, 0.22), 1.0)
	_draw_health(0, Vector2(42, 58), left_accent)
	_draw_health(1, Vector2(748, 58), right_accent)
	draw_colored_polygon(PackedVector2Array([Vector2(572, 18), Vector2(706, 18), Vector2(691, 92), Vector2(589, 92)]), INK)
	_center_text("%02d" % clock, Vector2(640, 76), 49, GOLD if clock > 10 else CORAL)
	if ladder_size > 0:
		var progress := "最終關・競選總部" if bout == ladder_size - 1 else "第 %d／%d 關" % [bout + 1, ladder_size]
		_center_text(progress, Vector2(640, 104), 18, GOLD)
	var left := model.fighters[0]
	var right := model.fighters[1]
	if left.combo_display > 1 and left.combo_timer > 0:
		_draw_combo(left.combo_display, Vector2(48, 198), left_accent)
	if right.combo_display > 1 and right.combo_timer > 0:
		_draw_combo(right.combo_display, Vector2(1100, 198), right_accent)
	draw_rect(Rect2(0, 632, SIZE.x, 88), Color(0.03, 0.04, 0.085, 0.89))
	draw_line(Vector2(30, 632), Vector2(1250, 632), Color(1, 0.84, 0.66, 0.34), 1.0)
	_draw_meter(0, Vector2(42, 673), left_accent)
	_draw_meter(1, Vector2(995, 673), right_accent)
	if sound_off:
		_right_text("靜音", Vector2(1238, 710), 14, Color("b3b6c5"))
	if full_meter:
		_text("滿槽練習", Vector2(42, 710), 14, GOLD)
	if action_buttons[0].visible:
		_center_text("A/D 移動    W 跳    按住 S 防禦    Esc 暫停", Vector2(640, 710), 14, Color("b5c3d0"))
		for index in ACTIONS.size():
			_draw_action_button(index)


func _draw_touch_controls() -> void:
	var stick_center := TOUCH_STICK
	draw_circle(stick_center, 76.0, Color(INK, 0.65), true, -1, true)
	draw_arc(stick_center, 74.0, 0.0, TAU, 64, Color(PAPER, 0.58), 2.0, true)
	_center_text("跳", stick_center + Vector2(0, -42), 18, PAPER)
	_center_text("防", stick_center + Vector2(0, 55), 18, PAPER)
	for direction in [-1, 1]:
		var p := stick_center + Vector2(direction * 54.0, 0.0)
		draw_polyline(PackedVector2Array([p + Vector2(-direction * 7, -7), p,
			p + Vector2(-direction * 7, 7)]), Color(PAPER, 0.64), 2.0, true)
	var thumb := stick_center + joystick * 45.0
	var accent: Color = CHARACTER_ACCENTS[player_character]
	draw_circle(thumb, 25.0, Color(accent, 0.35), true, -1, true)
	draw_arc(thumb, 24.0, 0.0, TAU, 40, accent, 2.0, true)
	var defending := model.fighters[0].guarding
	var glow := accent if defending else PAPER
	draw_circle(TOUCH_GUARD, TOUCH_GUARD_RADIUS, Color(INK.lerp(accent, 0.42 if defending else 0.08), 0.82), true, -1, true)
	draw_arc(TOUCH_GUARD, TOUCH_GUARD_RADIUS - 1.0, 0.0, TAU, 52, Color(glow, 0.9 if defending or guard_held else 0.48), 2.0, true)
	_center_text("防", TOUCH_GUARD + Vector2(0, 10), 27, glow)
	for index in TOUCH_CENTERS.size():
		_draw_touch_action(index, TOUCH_CENTERS[index], TOUCH_RADII[index])


func _action_label(index: int) -> String:
	if index == 0:
		return "普攻"
	if index == 4:
		return "大絕"
	return Roster.SKILL_NAMES[player_character][index - 1]


func _action_ready(index: int) -> bool:
	var fighter := model.fighters[0]
	if index == 4:
		return fighter.meter == Rules.MAX_METER
	return index == 0 or fighter.cooldowns[index - 1] == 0


func _action_progress(index: int) -> float:
	var fighter := model.fighters[0]
	if index == 0:
		return 1.0
	if index == 4:
		return float(fighter.meter) / Rules.MAX_METER
	return 1.0 - float(fighter.cooldowns[index - 1]) / float(Roster.COOLDOWNS[index - 1])


func _draw_action_button(index: int) -> void:
	var button := action_buttons[index]
	var rect := Rect2(button.position, button.size)
	var accent: Color = GOLD if index == 4 else CHARACTER_ACCENTS[player_character]
	var hovered := button.is_hovered() and not button.disabled
	var fill := INK.lerp(accent, 0.20 if hovered else 0.08)
	draw_rect(rect, Color(fill, 0.98))
	draw_rect(rect, Color(accent, 0.91 if hovered else (0.37 if button.disabled else 0.60)), false, 1.0)
	if not button.disabled or index == 4 or not _action_ready(index):
		var progress := _action_progress(index)
		draw_rect(Rect2(rect.position + Vector2(1.0, rect.size.y - 3.0), Vector2((rect.size.x - 2.0) * progress, 2.0)),
			Color(accent, 0.52 if button.disabled else 0.89))
	var icon := rect.position + Vector2(22.0, 30.0)
	_draw_move_icon(index, player_character, icon, 0.90, Color(accent, 0.46 if button.disabled else 1.0))
	_text(_action_label(index), rect.position + Vector2(40.0, 38.0), 17, Color(PAPER, 0.66 if button.disabled else 1.0))
	var hint: String = ACTION_KEYS[index]
	if index in [1, 2, 3] and not _action_ready(index):
		hint = "%d 秒" % ceili(float(model.fighters[0].cooldowns[index - 1]) / Rules.TICK_RATE)
	_right_text(hint, rect.end - Vector2(7.0, 37.0), 13, Color(PAPER, 0.55 if button.disabled else 0.73))


func _draw_touch_action(index: int, at: Vector2, radius: float) -> void:
	var color: Color = GOLD if index == 4 else CHARACTER_ACCENTS[player_character]
	var fraction := _action_progress(index)
	var ready := _action_ready(index)
	draw_circle(at, radius, Color(INK.lerp(color, 0.25 if ready else 0.04), 0.51 if ready else 0.68), true, -1, true)
	draw_arc(at, radius - 1.0, 0.0, TAU, 52, Color(PAPER, 0.26), 2.0, true)
	if fraction > 0.01:
		draw_arc(at, radius - 1.0, -PI * 0.5, -PI * 0.5 + fraction * TAU, 52, Color(color, 0.66), 2.5, true)
	_draw_move_icon(index, player_character, at - Vector2(0.0, 7.0), radius / 25.0, Color(color if ready else PAPER, 0.75 if ready else 0.45))
	_center_text(_action_label(index), at + Vector2(0, radius * 0.63), 17, PAPER)
	if index in [1, 2, 3] and not ready:
		var remaining: int = model.fighters[0].cooldowns[index - 1]
		var seconds := str(ceili(float(remaining) / Rules.TICK_RATE))
		var badge := at + Vector2(radius - 3.0, -radius + 5.0)
		draw_circle(badge, 11.0, INK, true, -1, true)
		_center_text(seconds, badge + Vector2(0, 5), 14, PAPER)


func _draw_move_icon(index: int, character: int, at: Vector2, scale: float, color: Color) -> void:
	if character > Roster.GU and index in [1, 2, 3]:
		if index == 2:
			_draw_shield(at, 11.0 * scale, color)
		elif index == 3:
			_draw_campaign_mark(character, at, 11.0 * scale, 1.0, 0.0, color)
		else:
			_draw_tapered_stroke(at - Vector2(13, -5) * scale, at + Vector2(13, -5) * scale, 3.0 * scale, color)
			_draw_tapered_stroke(at - Vector2(8, 5) * scale, at + Vector2(10, 5) * scale, 2.4 * scale, color)
		return
	match index:
		0:
			draw_colored_polygon(PackedVector2Array([at + Vector2(-10, 1) * scale, at + Vector2(-1, -11) * scale,
				at + Vector2(12, -7) * scale, at + Vector2(13, 3) * scale, at + Vector2(2, 11) * scale,
				at + Vector2(-9, 8) * scale]), color)
		1:
			if character == Roster.LIU:
				draw_line(at + Vector2(-9, -12) * scale, at + Vector2(-9, 11) * scale, color, 2.5 * scale, true)
				draw_colored_polygon(PackedVector2Array([at + Vector2(-8, -12) * scale, at + Vector2(12, -7) * scale,
					at + Vector2(12, 5) * scale, at + Vector2(-8, 0) * scale]), color)
			else:
				draw_rect(Rect2(at + Vector2(-12, -9) * scale, Vector2(24, 15) * scale), color, false, 2.0 * scale)
				draw_line(at + Vector2(-6, 6) * scale, at + Vector2(-9, 11) * scale, color, 2.0 * scale, true)
				draw_line(at + Vector2(-7, -2) * scale, at + Vector2(7, -2) * scale, color, 2.0 * scale, true)
		2:
			if character == Roster.LIU:
				var junction := at + Vector2(-3, 0) * scale
				draw_line(at + Vector2(-11, 0) * scale, junction, color, 2.5 * scale, true)
				for branch in [-1, 1]:
					var terminal := at + Vector2(11, branch * 8) * scale
					draw_line(junction, terminal, color, 2.5 * scale, true)
					draw_circle(terminal, 3.0 * scale, color, true, -1, true)
			else:
				draw_rect(Rect2(at + Vector2(-10, -11) * scale, Vector2(20, 22) * scale), color, false, 2.0 * scale)
				draw_polyline(PackedVector2Array([at + Vector2(-5, 0) * scale, at + Vector2(-1, 4) * scale,
					at + Vector2(5, -5) * scale]), color, 2.0 * scale, true)
		3:
			if character == Roster.LIU:
				_draw_bird(at, scale * 0.34, -0.20, 1.0, color, color.a)
			else:
				for tile in 3:
					var p := at + Vector2((tile - 1) * 10, absf(tile - 1) * 7.0 - 8.0) * scale
					draw_rect(Rect2(p - Vector2(5, 3) * scale, Vector2(10, 7) * scale), color, false, 1.5 * scale)
					draw_line(p + Vector2(-2, 4) * scale, p + Vector2(-4, 7) * scale, color, 1.5 * scale, true)
		4:
			var star := PackedVector2Array()
			for point in 8:
				star.append(at + Vector2.from_angle(point * TAU / 8.0) * (14.0 if point % 2 == 0 else 5.0) * scale)
			draw_colored_polygon(star, color)


func _draw_health(side: int, at: Vector2, accent: Color) -> void:
	if side == 0:
		_text("1P  " + Roster.NAMES[player_character], at + Vector2(0, -13), 21, PAPER)
	else:
		_right_text(Roster.NAMES[model.fighters[1].character] + "  CPU", at + Vector2(490, -13), 21, PAPER)
	draw_rect(Rect2(at, Vector2(490, 22)), Color("42283a"))
	var fighter := model.fighters[side]
	var width := float(fighter.hp) / fighter.max_hp * 486.0
	var x := at.x + (2.0 if side == 0 else 488.0 - width)
	if width > 0.0:
		draw_rect(Rect2(x, at.y + 2.0, width, 18.0), accent)
		draw_rect(Rect2(x, at.y + 2.0, width, 5.0), Color(PAPER, 0.34))
	draw_rect(Rect2(at, Vector2(490, 22)), Color(PAPER, 0.57), false, 1.0)
	for index in 2:
		var mark := at + Vector2(5.0 + index * 18.0 if side == 0 else 484.0 - index * 18.0, 34)
		draw_colored_polygon(PackedVector2Array([mark + Vector2(-5, 0), mark + Vector2(0, -5), mark + Vector2(5, 0), mark + Vector2(0, 5)]),
			accent if model.score[side] > index else Color("596175"))


func _draw_meter(side: int, at: Vector2, accent: Color) -> void:
	var meter := model.fighters[side].meter
	var full := meter == Rules.MAX_METER
	var fill := GOLD if full else accent
	var fraction := float(meter) / Rules.MAX_METER
	var label := "大絕就緒" if full else "大絕  %d%%" % floori(fraction * 100.0)
	_text(label, at + Vector2(0, -9), 15, fill)
	for index in 4:
		var cell := at + Vector2(index * 61.0, 0.0)
		draw_rect(Rect2(cell, Vector2(57, 13)), Color("33394e"))
		var ratio := clampf(fraction * 4.0 - index, 0.0, 1.0)
		if ratio > 0.0:
			draw_rect(Rect2(cell, Vector2(57.0 * ratio, 13.0)), fill)
			draw_rect(Rect2(cell, Vector2(57.0 * ratio, 3.0)), Color(PAPER, 0.35))


func _draw_combo(count: int, at: Vector2, accent: Color) -> void:
	_text("%02d" % count, at, 58, accent)
	_text("HIT COMBO", at + Vector2(3, 22), 15, PAPER)


func _fighter_card(character: int) -> Rect2:
	return Rect2(Vector2(76 + (character % SELECT_COLUMNS) * 286, 100 + floori(float(character) / SELECT_COLUMNS) * 232),
		Vector2(270, 222))


func _draw_menu() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.035, 0.047, 0.08, 0.73))
	_center_text("選戰風雲S", Vector2(660, 77), 53, PAPER)
	var mode_note := "挑戰八關・擊敗魔王" if campaign_mode else "單場對戰・挑戰電腦"
	_center_text("滿槽練習" if full_meter else mode_note, Vector2(1034, 71), 20, GOLD)
	for character in Roster.PLAYABLE_COUNT:
		var panel := _fighter_card(character)
		var center := panel.get_center().x
		var accent: Color = CHARACTER_ACCENTS[character]
		var focused := player_character == character or fighter_buttons[character].is_hovered()
		draw_rect(panel, Color(INK, 0.83))
		var canvas := Rect2(panel.position + Vector2(2, 2), Vector2(panel.size.x - 4.0, 168.0))
		var portrait: Texture2D = PORTRAITS[character]
		var canvas_source := Rect2(400.0, 0.0, 880.0, 880.0 * canvas.size.y / canvas.size.x)
		draw_texture_rect_region(portrait, canvas, canvas_source)
		draw_line(Vector2(canvas.position.x, canvas.end.y), canvas.end, Color(accent, 0.60), 2.0)
		draw_rect(panel, Color(accent, 0.95 if focused else 0.38), false, 2.0)
		_center_text(Roster.NAMES[character], Vector2(center, panel.end.y - 25.0), 26, PAPER)
		_center_text(Roster.STYLES[character], Vector2(center, panel.end.y - 7.0), 14, accent)
	if not touch_mode:
		_center_text("1／2 選模式    方向鍵選角    Enter 開打    G 換場地", Vector2(640, 715), 15, PAPER)


func _draw_pause() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.04, 0.05, 0.095, 0.84))
	_center_text("暫停", Vector2(640, 350), 65, PAPER)
	if not touch_mode:
		_center_text("Esc  繼續     R  重賽     Tab  返回選角", Vector2(640, 536), 19, GOLD)


func _draw_result() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.04, 0.05, 0.095, 0.74))
	var player_won := model.match_winner == 0
	var label := "1P WINS" if player_won else "CPU WINS"
	if ladder_size > 0:
		label = "挺進下一關" if player_won else "本關落選"
	var character := model.fighters[model.match_winner].character
	_center_text(label, Vector2(640, 344), 79, CHARACTER_ACCENTS[character])
	_center_text("%d   /   %d" % model.score, Vector2(640, 402), 28, PAPER)
	if not touch_mode:
		_center_text("Enter  " + _restart_label() + "     Tab  返回選角", Vector2(640, 536), 19, GOLD)


func _campaign_cleared() -> bool:
	return playing and ladder_size > 0 and bout == ladder_size - 1 and model.match_winner == 0


func _draw_campaign_ending() -> void:
	var hero := model.fighters[0].character
	var accent: Color = CHARACTER_ACCENTS[hero]
	draw_texture_rect(STAGES[0], Rect2(Vector2.ZERO, SIZE), false, Color("46515c"))
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color(INK, 0.64))
	var page := Rect2(74, 72, 1132, 500)
	draw_rect(page, Color("111929"))
	draw_rect(page, Color(GOLD, 0.66), false, 2.0)

	var illustration := Rect2(632, 93, 552, 458)
	draw_texture_rect_region(PORTRAITS[hero], illustration, Rect2(412, 0, 868, 720))
	draw_rect(illustration, Color(accent, 0.88), false, 2.0)
	draw_rect(Rect2(634, 486, 548, 63), Color(INK, 0.87))
	_text(Roster.NAMES[hero], Vector2(656, 528), 29, PAPER)
	_right_text("%d 比 %d" % model.score, Vector2(1160, 528), 24, GOLD)

	_text("闖關完成    %d / %d" % [ladder_size, ladder_size], Vector2(113, 141), 25, GOLD)
	_text("夜市重新開張", Vector2(110, 229), 54, PAPER)
	draw_line(Vector2(114, 265), Vector2(568, 265), Color(GOLD, 0.57), 2.0)
	_text("洪萬金放下麥克風，宣布收工。", Vector2(113, 315), 25, PAPER)
	_text("志工搬走最後一排折疊椅，", Vector2(113, 356), 25, PAPER)
	_text("南街的攤販把招牌一盞盞點亮。", Vector2(113, 397), 25, PAPER)
	_text("%s回到夜市，只問了一句" % Roster.NAMES[hero], Vector2(113, 456), 25, PAPER)
	_text("「所以，宵夜要吃什麼？」", Vector2(113, 503), 30, GOLD)
	if not touch_mode:
		_center_text("Enter  再跑一輪     Tab  返回選角", Vector2(640, 700), 18, PAPER)


func _restart_label() -> String:
	if ladder_size == 0:
		return "重賽"
	if model.match_winner == 1:
		return "重打本關"
	return "再跑一輪" if bout == ladder_size - 1 else "下一關"


func _draw_round_banner() -> void:
	var label := "ROUND %d" % model.round_number
	var color := PAPER
	if model.intro in range(1, 30):
		label = "FIGHT!"
		color = GOLD
	elif model.round_end > 0:
		label = "TIME OUT" if model.ticks_left == 0 else "K.O."
		color = GOLD
	_center_text(label, Vector2(640, 324), 76, color)
	if model.intro >= 30 and model.fighters[1].character == Roster.HONG:
		_center_text("魔王・競總主任洪萬金", Vector2(640, 384), 33, CORAL)


func _text(message: String, at: Vector2, size: int, color: Color) -> void:
	draw_string_outline(typeface, at, message, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(INK, color.a * 0.89))
	draw_string(typeface, at, message, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _center_text(message: String, at: Vector2, size: int, color: Color) -> void:
	_text(message, at - Vector2(typeface.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5, 0), size, color)


func _right_text(message: String, at: Vector2, size: int, color: Color) -> void:
	_text(message, at - Vector2(typeface.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x, 0), size, color)
