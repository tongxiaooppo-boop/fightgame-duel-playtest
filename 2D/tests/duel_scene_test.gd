extends SceneTree

const DUEL := preload("res://2D/duel.tscn")
const Rules := preload("res://2D/duel_rules.gd")
const Roster := preload("res://2D/duel_roster.gd")
const View := preload("res://2D/duel_view.gd")
const CAPTURE_NAMES := ["liu", "gu", "pei", "shi", "lu", "ruan", "wen", "fang"]

var duel: Node2D
var failures := 0
var capture := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	if capture:
		_check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build")) == OK,
			"capture directory is available")
	duel = DUEL.instantiate()
	root.add_child(duel)
	duel.set_physics_process(false)
	duel.rng.seed = 94873
	_key(KEY_M)
	duel.arena.mode_buttons[0].pressed.emit()
	_check(not duel.campaign_mode and duel.arena.mode_buttons[0].button_pressed, "1 on 1 is selectable")
	_key(KEY_ENTER)
	_check(duel.ladder.is_empty() and duel.battle.fighters[0].meter == 0,
		"1 on 1 starts a regular single match without a full meter")
	duel.battle.match_winner = 0
	duel._refresh_view()
	_check(not duel.arena._campaign_cleared() and duel.arena.restart_button.text == "重賽",
		"a single-match win offers a rematch")
	_key(KEY_TAB)
	_key(KEY_F2)
	_check(duel.full_meter, "F2 enables practice meter")
	await _capture("selection")
	_key(KEY_ENTER)
	_check(duel.started and duel.battle.fighters[0].character == Roster.LIU, "keyboard starts Liu's match")
	_check(duel.battle.fighters[0].meter == Rules.MAX_METER and duel.battle.fighters[1].meter == 0,
		"practice meter starts full for the player only")
	_finish_intro()
	var cpu_x: float = duel.battle.fighters[1].x
	_step(6)
	_check(duel.battle.fighters[1].x < cpu_x, "CPU approaches without a second player")
	duel.ai_wait = 10000
	_set_gap(113.0, false)
	_key(KEY_J)
	_step(1)
	_check(duel.battle.fighters[0].move == &"jab", "J triggers a close normal from the scene")
	_step(35)
	await _test_touch()
	await _test_super(Roster.LIU, false)
	_key(KEY_ESCAPE)
	_key(KEY_TAB)
	_key(KEY_F1)
	_check(not duel.touch_mode, "F1 returns the HUD to keyboard controls")
	_key(KEY_RIGHT)
	_key(KEY_ENTER)
	_check(duel.started and duel.battle.fighters[0].character == Roster.GU, "selection switches to Gu and assigns Liu to CPU")
	_finish_intro()
	duel.ai_wait = 10000
	await _capture("desktop-actions")
	_set_gap(135.0, false)
	var player_x: float = duel.battle.fighters[0].x
	_key_state(KEY_RIGHT, true)
	_click_action(0)
	_step(1)
	_key_state(KEY_RIGHT, false)
	_check(duel.battle.fighters[0].x > player_x and duel.battle.fighters[0].move == &"jab",
		"mouse normal works while keyboard movement is held")
	_step(35)
	_click_action(1)
	_step(1)
	_check(duel.battle.fighters[0].move == &"second_question", "mouse reaches Gu's first skill")
	_check(duel.arena.action_buttons[1].disabled, "the mouse button is disabled while its skill cools down")
	_click_action(1)
	_check(duel.battle.fighters[0].buffer_left == 0, "cooling mouse button does not buffer a second cast")
	_step(60)
	_set_gap(124.0, true)
	_click_action(2)
	_step(10)
	_check(duel.battle.effects.size() == 1, "mouse opens Gu's afterimage while facing left")
	await _capture("gu-afterimage")
	_step(60)
	_click_action(3)
	_step(10)
	_check(duel.battle.effects.size() == 3, "mouse spawns the three echo waves")
	await _capture("gu-echoes")
	await _test_super(Roster.GU, true, true)
	_test_cpu_tempo(Roster.LIU)
	_test_cpu_tempo(Roster.GU)
	await _test_campaign_scene()
	await _test_arcade_route()
	_test_voice()
	if capture:
		await _capture_skills()
		for character in range(Roster.PEI, Roster.PLAYABLE_COUNT):
			duel.full_meter = true
			duel._set_stage(character % View.STAGE_NAMES.size())
			duel.start_match(character)
			_finish_intro()
			duel.ai_wait = 10000
			await _test_super(character, character % 2 == 1)
	duel.queue_free()
	await create_timer(0.12).timeout
	print("Duel scene tests complete: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _test_touch() -> void:
	_set_gap(205.0, false)
	var before: float = duel.battle.fighters[0].x
	_touch(4, View.TOUCH_STICK, true)
	_drag(4, View.TOUCH_STICK + Vector2(48, 0))
	_touch(9, View.TOUCH_CENTERS[1], true)
	_step(1)
	_check(duel.touch_mode and duel.stick_id == 4, "skill finger does not steal the joystick")
	_check(duel.battle.fighters[0].x > before, "left touch moves while right touch triggers a skill")
	_check(duel.battle.fighters[0].move == &"lane_step", "right touch reaches Liu's first skill")
	_touch(9, View.TOUCH_CENTERS[1], false)
	_touch(4, View.TOUCH_STICK, false)
	_check(duel.stick_id == -1, "lifting joystick stops movement")
	_step(40)
	_touch(4, View.TOUCH_STICK + Vector2(0, 66), true)
	_step(1)
	_check(duel.battle.fighters[0].guarding, "down on touch joystick guards")
	_key(KEY_ESCAPE)
	_check(duel.paused and duel.stick_id == -1, "pause releases joystick")
	_key(KEY_ESCAPE)
	_touch(4, View.TOUCH_STICK + Vector2(0, -66), true)
	_step(1)
	_check(duel.battle.fighters[0].height > 0.0, "up on touch joystick jumps")
	_touch(4, View.TOUCH_STICK, false)
	_step(48)
	_set_gap(310.0, false)
	_key(KEY_U)
	_step(19)
	_check(duel.battle.effects.size() == 1, "U shows Liu's telegraphed bird drop")
	await _capture("liu-touch")


func _test_campaign_scene() -> void:
	duel._return_to_select()
	_key(KEY_G)
	_check(duel.selected_stage == 1 and duel.arena.stage_buttons[1].button_pressed, "G changes the stage")
	duel.arena.stage_buttons[3].pressed.emit()
	_check(duel.selected_stage == 3 and duel.arena.stage_buttons[3].button_pressed, "stage button selects the park")
	for character in Roster.PLAYABLE_COUNT:
		duel.arena.fighter_buttons[character].pressed.emit()
		_check(duel.battle.fighters[0].character == character and duel.selected_stage == 3
			and duel.battle.fighters[1].character == Roster.RIVALS[character], "every roster card starts its own matchup")
	_finish_intro()
	duel.ai_wait = 10000
	_set_gap(109.0, false)
	duel.battle.queue_action(1, &"normal")
	_touch(7, View.TOUCH_GUARD, true)
	_step(12)
	_check(duel.guard_id == 7 and duel.battle.fighters[0].blockstun > 0
		and duel.battle.fighters[0].hp == Rules.MAX_HP, "held mobile guard blocks a real attack")
	await _capture("campaign-guard")
	_touch(7, View.TOUCH_GUARD, false)
	_step(32)
	_check(duel.guard_id < 0 and not duel.battle.fighters[0].guarding, "lifting the guard finger leaves guard")
	_set_gap(109.0, true)
	duel.battle.queue_action(1, &"normal")
	_key_state(KEY_S, true)
	_step(12)
	_key_state(KEY_S, false)
	_check(duel.battle.fighters[0].blockstun > 0 and duel.battle.fighters[0].hp == Rules.MAX_HP,
		"holding S guards an attack when facing left")


func _test_arcade_route() -> void:
	duel._return_to_select()
	duel.player_character = Roster.RUAN
	_key(KEY_2)
	_check(duel.campaign_mode and not duel.full_meter and duel.arena.mode_buttons[1].button_pressed,
		"campaign is selectable with the keyboard and starts without full meter")
	_key(KEY_ENTER)
	var seen: Array[int] = []
	var opening_wait := 200
	for level in Roster.LADDER_LENGTH:
		var rival: int = duel.battle.fighters[1].character
		_check(duel.bout == level and duel.battle.fighters[0].character == Roster.RUAN and rival not in seen,
			"arcade keeps the selected fighter against distinct opponents")
		seen.append(rival)
		_step(1)
		_check(duel.ai_wait < opening_wait, "each level shortens the CPU opening delay")
		opening_wait = duel.ai_wait
		if level == 2:
			duel.battle.match_winner = 1
			_key(KEY_ENTER)
			_check(duel.bout == level and duel.battle.fighters[1].character == rival, "a loss retries the same level")
		if level == Roster.LADDER_LENGTH - 1:
			_check(rival == Roster.HONG and duel.battle.fighters[1].max_hp == Rules.BOSS_HP and duel.fight_stage == 2,
				"the last level is the boss on the rally stage")
			await _capture("arcade-boss")
			duel.battle.match_winner = 1
			duel._refresh_view()
			_check(not duel.arena._campaign_cleared(), "losing to the boss does not open the ending")
			_key(KEY_ENTER)
			_finish_intro()
			duel.ai_wait = 10000
			duel.battle.score[0] = 1
			duel.battle.fighters[1].hp = 1
			duel.battle.fighters[1].hitstun = 15
			_set_gap(110.0, false)
			_key(KEY_J)
			_step(180)
			_check(duel.arena._campaign_cleared() and duel.arena.restart_button.text == "再跑一輪",
				"winning both rounds against the boss opens the ending and offers a new run")
			await _capture("campaign-ending")
		else:
			duel.battle.match_winner = 0
			_check(not duel.arena._campaign_cleared(), "a regular campaign win advances without the ending")
		_key(KEY_ENTER)
	_check(duel.bout == 0 and seen.size() == Roster.LADDER_LENGTH, "clearing the boss offers a fresh run")


func _test_voice() -> void:
	duel._return_to_select()
	duel._set_full_meter(true)
	duel.start_match(Roster.LIU)
	_finish_intro()
	duel.ai_wait = 10000
	_key(KEY_M)
	_key(KEY_K)
	_step(1)
	_check(duel.voices[0].playing and duel.voices[0].stream.resource_path.ends_with("liu-0.wav"), "skill starts its bundled Mandarin voice clip")
	_step(45)
	_set_gap(109.0, false)
	_key(KEY_I)
	_step(33)
	_check(duel.voices[0].playing and duel.voices[0].stream.resource_path.ends_with("liu-3.wav"), "confirmed super plays its Mandarin title")
	_key(KEY_M)


func _test_super(character: int, mirrored: bool, mouse := false) -> void:
	_step(64)
	_set_gap(122.0, mirrored)
	if mouse:
		_click_action(4)
	else:
		_key(KEY_I)
	_step(12)
	_check(duel.battle.super_side == 0, "super input triggers %s's hit-confirmed cut-in" % Roster.NAMES[character])
	if duel.battle.super_side != 0:
		return
	var before: int = duel.battle.ticks_left
	var name: String = CAPTURE_NAMES[character]
	var finale: int = Roster.SUPER_BEATS[character][-1]
	_check(not duel.arena.action_buttons[0].visible, "mouse controls hide during cinematics")
	# Draw each tick during a capture pass so the renderer exercises the entire sequence.
	for index in int(Roster.SUPER_LENGTH[character]):
		if duel.battle.super_side != 0:
			break
		_step(1)
		var tick: int = duel.battle.super_tick
		if tick == 12:
			await _capture(name + "-slow")
		elif tick == 29:
			await _capture(name + "-portrait")
		elif tick == finale - Rules.SUPER_FINISH_CUE + 5:
			await _capture(name + "-charge")
		elif tick == finale + 3:
			await _capture(name + "-finale")
		elif tick == finale + 15:
			await _capture(name + "-launch")
		if capture:
			await RenderingServer.frame_post_draw
	_check(duel.battle.ticks_left == before, "round clock does not run during the cinematic")
	_check(duel.battle.super_side == -1, "cinematic returns to the live arena")
	_check(duel.battle.fighters[0].combo_display >= 7, "cinematic resolves all seven hits")


func _set_gap(gap: float, mirrored: bool) -> void:
	duel.battle.fighters[0].x = 620.0
	duel.battle.fighters[1].x = 620.0 + gap * (-1.0 if mirrored else 1.0)


func _capture_skills() -> void:
	var samples := [
		[KEY_K, 205.0, [9], ["liu-lane-step"]],
		[KEY_L, 430.0, [23], ["liu-ribbons"]],
		[KEY_U, 145.0, [13, 30, 41], ["liu-flock-rise", "liu-flock-dive", "liu-flock-impact"]],
		[KEY_K, 147.0, [8, 23], ["gu-first-palm", "gu-second-palm"]],
		[KEY_L, 122.0, [11, 19], ["gu-image-charge", "gu-image-impact"]],
		[KEY_U, 415.0, [13, 29, 55], ["gu-echo-ready", "gu-echo-wave", "gu-echo-last"]],
	]
	for index in samples.size():
		var character := Roster.LIU if index < 3 else Roster.GU
		var sample: Array = samples[index]
		duel.start_match(character)
		_finish_intro()
		duel.ai_wait = 10000
		_set_gap(sample[1], character == Roster.GU)
		_key(sample[0])
		for elapsed in range(1, sample[2][-1] + 1):
			_step(1)
			var moment: int = sample[2].find(elapsed)
			if moment >= 0:
				await _capture(sample[3][moment])
			else:
				await RenderingServer.frame_post_draw


func _test_cpu_tempo(character: int) -> void:
	duel.full_meter = false
	duel.rng.seed = 94873
	duel.start_match(character)
	_finish_intro()
	_click_action(4)
	_check(duel.arena.action_buttons[4].disabled and duel.battle.fighters[0].buffer_left == 0,
		"an empty meter disables the mouse super")
	var attack_ticks: Array[int] = []
	for tick in 8 * Rules.TICK_RATE:
		_step(1)
		for event in duel.battle.events:
			if event["kind"] == &"start" and event["side"] == 1:
				attack_ticks.append(tick)
	_check(not attack_ticks.is_empty(), "CPU still attacks a stationary player")
	if not attack_ticks.is_empty():
		_check(attack_ticks[0] >= Rules.TICK_RATE, "CPU leaves an opening when the round starts")
	for index in range(1, attack_ticks.size()):
		_check(attack_ticks[index] - attack_ticks[index - 1] >= Rules.TICK_RATE, "CPU leaves time between attacks")
	var player_hp: int = duel.battle.fighters[0].hp
	_check(player_hp >= 550, "a stationary player survives the first eight seconds with over half health")
	print("CPU %s in first 8s: %d attacks, player HP %d/%d" % [
		Roster.NAMES[1 - character], attack_ticks.size(), player_hp, Rules.MAX_HP])


func _finish_intro() -> void:
	_step(duel.battle.intro)


func _step(ticks: int) -> void:
	for index in ticks:
		duel._physics_process(1.0 / Rules.TICK_RATE)


func _key(code: Key) -> void:
	_key_state(code, true)
	_key_state(code, false)


func _key_state(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _click_action(index: int) -> void:
	var button: Button = duel.arena.action_buttons[index]
	var position_in_viewport: Vector2 = button.get_global_transform_with_canvas() * (button.size * 0.5)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position_in_viewport
		event.global_position = position_in_viewport
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)


func _touch(id: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = id
	event.position = duel.arena.get_global_transform_with_canvas() * point
	event.pressed = pressed
	root.push_input(event, true)


func _drag(id: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = id
	event.position = duel.arena.get_global_transform_with_canvas() * point
	root.push_input(event, true)


func _capture(name: String) -> void:
	if not capture:
		return
	await RenderingServer.frame_post_draw
	var file := ProjectSettings.globalize_path("res://build/duel-" + name + ".png")
	_check(root.get_texture().get_image().save_png(file) == OK, "saved capture of " + name)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
