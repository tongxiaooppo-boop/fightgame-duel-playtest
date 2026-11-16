extends Node2D

const Rules := preload("res://2D/duel_rules.gd")
const View := preload("res://2D/duel_view.gd")
const Roster := preload("res://2D/duel_roster.gd")
const Voice := preload("res://2D/duel_voice.gd")
const CPU_OPENING_TICKS := 90
const EFFECT_CUES := {
	&"ribbon_low": &"cast", &"ribbon_high": &"cast", &"birds": &"paper_flock",
	&"image": &"afterimage", &"echo": &"echo_swarm",
	&"copper_shock": &"cast", &"copper_bolt": &"cast", &"copper_ray": &"cast", &"barrier": &"guard",
	&"barrier_sweep": &"heavy", &"wheel": &"heavy",
	&"line_trap": &"afterimage", &"ridge_marker": &"swing", &"ebb": &"afterimage", &"harbor": &"paper_flock",
	&"fan_reply": &"cast", &"fan": &"paper_flock", &"magnet": &"guard", &"machine": &"echo_swarm",
	&"overload": &"heavy", &"chairs": &"heavy", &"results": &"echo_swarm",
}
const AUDIO := {
	&"swing": preload("res://assets/audio/swing.wav"),
	&"light": preload("res://assets/audio/hit.wav"),
	&"heavy": preload("res://assets/audio/heavy.wav"),
	&"guard": preload("res://assets/audio/clasp.wav"),
	&"lane_step": preload("res://assets/audio/swing.wav"),
	&"ribbon_split": preload("res://assets/audio/sign_fold.wav"),
	&"paper_flock": preload("res://assets/audio/move_pages.wav"),
	&"second_question": preload("res://assets/audio/move_reply.wav"),
	&"afterimage": preload("res://assets/audio/move_splice.wav"),
	&"echo_swarm": preload("res://assets/audio/move_spam.wav"),
	&"super_start": preload("res://assets/audio/ready_spotlights.wav"),
	&"super": preload("res://assets/audio/ready_reels.wav"),
	&"cut_in": preload("res://assets/audio/horn.wav"),
	&"liu_charge": preload("res://assets/audio/ready_rails.wav"),
	&"gu_charge": preload("res://assets/audio/ready_drums.wav"),
	&"cast": preload("res://assets/audio/flag_crack.wav"),
	&"final": preload("res://assets/audio/truck_impact.wav"),
	&"fight": preload("res://assets/audio/open.wav"),
	&"ko": preload("res://assets/audio/win.wav"),
}

var battle := Rules.new()
var started := false
var player_character := Roster.LIU
var selected_stage := 0
var fight_stage := 0
var ladder: Array[int] = []
var bout := 0
var paused := false
var muted := false
var ai_wait := 0
var ai_guard := 0
var ai_round := 0
var sounds: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var music: AudioStreamPlayer
var rng := RandomNumberGenerator.new()
var full_meter := false
var campaign_mode := true
var touch_mode := false
var stick_id := -1
var guard_id := -1
var stick := Vector2.ZERO
var web_viewport: JavaScriptObject
var web_touch := false
var web_portrait := false
var web_interruption := 0
var web_controls := true
@onready var arena: View = $Arena


func _ready() -> void:
	get_window().title = "選戰風雲S"
	RenderingServer.set_default_clear_color(Color("0a0c13"))
	get_viewport().size_changed.connect(_layout)
	_layout()
	arena.fighter_selected.connect(start_match)
	arena.stage_selected.connect(_set_stage)
	arena.resume_requested.connect(_set_paused.bind(false))
	arena.pause_requested.connect(_set_paused.bind(true))
	arena.restart_requested.connect(_restart)
	arena.select_requested.connect(_return_to_select)
	arena.action_requested.connect(_queue_player_action)
	arena.practice_toggled.connect(_set_full_meter)
	arena.mode_selected.connect(_set_mode)
	full_meter = "--full-meter" in OS.get_cmdline_user_args()
	campaign_mode = not full_meter
	if OS.has_feature("web"):
		web_viewport = JavaScriptBridge.get_interface("duelViewport")
	else:
		touch_mode = DisplayServer.is_touchscreen_available()
	_sync_web_viewport()
	_refresh_view()
	for key in AUDIO:
		var player := AudioStreamPlayer.new()
		player.stream = AUDIO[key]
		player.max_polyphony = 3
		player.volume_db = -13.0
		add_child(player)
		sounds[key] = player
	for side in 2:
		var player := AudioStreamPlayer.new()
		player.volume_db = -5.0
		voices.append(player)
		add_child(player)
	music = AudioStreamPlayer.new()
	music.stream = preload("res://assets/audio/music_rival.wav")
	music.volume_db = -20.0
	add_child(music)
	music.finished.connect(_loop_music)
	rng.randomize()


func _layout() -> void:
	var available := get_viewport_rect().size
	var fit := minf(available.x / View.SIZE.x, available.y / View.SIZE.y)
	arena.scale = Vector2.ONE * fit
	arena.position = (available - View.SIZE * fit) * 0.5


func start_match(character: int) -> void:
	if web_portrait:
		return
	player_character = character
	ladder.clear()
	if campaign_mode:
		ladder = Roster.ladder_for(character)
	bout = 0
	_begin_bout()


func _begin_bout() -> void:
	if web_portrait:
		return
	started = true
	paused = false
	ai_round = 0
	var rival := -1 if ladder.is_empty() else ladder[bout]
	fight_stage = 2 if rival == Roster.HONG else (selected_stage + bout) % View.STAGE_NAMES.size()
	battle.reset_match(player_character, full_meter, rival)
	_stop_voices()
	music.stream_paused = false
	_release_touches()
	arena.clear_effects()
	_loop_music()
	_refresh_view()


func _loop_music() -> void:
	if started and not muted and not music.playing:
		music.play()


func _physics_process(_delta: float) -> void:
	_sync_web_viewport()
	if started and not paused:
		var p1_axis := float(_down(KEY_D) or _down(KEY_RIGHT)) - float(_down(KEY_A) or _down(KEY_LEFT))
		var p1_guard := _down(KEY_S) or _down(KEY_DOWN) or guard_id >= 0
		if stick_id >= 0:
			p1_axis = clampf(p1_axis + stick.x, -1.0, 1.0)
			p1_guard = p1_guard or stick.y > 0.57
		var p2_axis := _cpu_axis()
		battle.step(p1_axis, p1_guard, p2_axis, ai_guard > 0)
		for event in battle.events:
			arena.handle(event)
			_play_event(event)
		if battle.super_side >= 0 or battle.match_winner >= 0:
			_release_touches()
		var music_target := -20.0
		if battle.super_side >= 0:
			var character := battle.fighters[battle.super_side].character
			var finale: int = Roster.SUPER_BEATS[character][-1]
			var charge := finale - Rules.SUPER_FINISH_CUE
			music_target = -42.0 if battle.super_tick >= charge and battle.super_tick <= finale + Rules.SUPER_FINISH_HOLD else -33.0
			if battle.super_tick == Rules.SUPER_SLOW_END:
				_play_event({"kind": &"cut_in"})
				_speak(battle.super_side, 3)
			elif battle.super_tick == charge:
				_play_event({"kind": &"liu_charge" if character == Roster.LIU else &"gu_charge"})
			elif battle.super_tick == finale:
				arena.handle({"kind": &"super_punchline", "side": battle.super_side})
		music.volume_db = move_toward(music.volume_db, music_target, 2.5)
		arena.advance()
	_refresh_view()


func _sync_web_viewport() -> void:
	if web_viewport == null:
		return
	var coarse_pointer := bool(web_viewport.touch)
	if coarse_pointer != web_touch:
		web_touch = coarse_pointer
		touch_mode = coarse_pointer
		_release_touches()
	web_portrait = bool(web_viewport.portrait)
	var interruption := int(web_viewport.interruption)
	if interruption != web_interruption:
		web_interruption = interruption
		_interrupt_match()


func _refresh_view() -> void:
	var show_controls := not started or paused
	if web_viewport != null and web_controls != show_controls:
		web_controls = show_controls
		web_viewport.setControls(show_controls)
	var stage := fight_stage if started else selected_stage
	arena.render_state(battle, started, player_character, paused, muted, full_meter, touch_mode,
		stick, stage, guard_id >= 0, bout, ladder.size(), campaign_mode)


func _cpu_axis() -> float:
	if ai_round != battle.round_number:
		ai_round = battle.round_number
		ai_wait = CPU_OPENING_TICKS - bout * 9
		ai_guard = 0
	if not battle.is_live() or battle.super_side >= 0 or battle.hitstop > 0:
		return 0.0
	var cpu := battle.fighters[1]
	var player := battle.fighters[0]
	var gap := absf(cpu.x - player.x)
	ai_guard = maxi(0, ai_guard - 1)
	if bout >= 3 and cpu.move != &"" and cpu.confirmed and cpu.buffer_left == 0 \
			and cpu.move_tick == cpu.last_contact + 2 and cpu.hitstun == 0:
		if cpu.meter == Rules.MAX_METER and gap < 210.0 and bout >= 5:
			battle.queue_action(1, &"super")
		elif not Rules.is_skill(cpu.move) and cpu.move != &"super":
			if bout >= 5 and cpu.cooldowns[0] == 0 and cpu.chain_step >= 1:
				battle.queue_action(1, &"skill_1")
			elif cpu.chain_step < 2:
				battle.queue_action(1, &"normal")
	# Count the opening only while the CPU is free to act. Every attack leaves a gap after recovery.
	if ai_guard > 0 or cpu.move != &"" or cpu.hitstun > 0 or cpu.blockstun > 0:
		return 0.0
	if bout >= 2 and player.move != &"" and player.move_tick == 4 and gap < 205.0 and rng.randf() < float(bout) * 0.043:
		ai_guard = 17
		return 0.0
	ai_wait = maxi(0, ai_wait - 1)
	if ai_wait == 0:
		var action := _cpu_action(cpu, gap)
		if action != &"":
			battle.queue_action(1, action)
			ai_wait = rng.randi_range(44 - bout * 4, 67 - bout * 6)
		else:
			ai_wait = rng.randi_range(18, 32)
	var desired: float = Roster.CPU_DISTANCE[cpu.character]
	if ai_guard > 0 or gap <= desired:
		return 0.0
	return signf(player.x - cpu.x) * (0.64 + bout * 0.041)


func _cpu_action(cpu: Rules.Fighter, gap: float) -> StringName:
	var choice := rng.randf()
	var pressure := float(bout) * 0.038
	if gap < 176.0 and choice < 0.12:
		ai_guard = 14
		return &""
	if gap < 196.0 and cpu.meter == Rules.MAX_METER and choice > 0.90 - pressure:
		return &"super"
	var third_range: Vector2 = Roster.CPU_THIRD_RANGE[cpu.character]
	if gap > third_range.x and gap < third_range.y and cpu.cooldowns[2] == 0 and choice > 0.82 - pressure:
		return &"skill_3"
	var second_range: Vector2 = Roster.CPU_SECOND_RANGE[cpu.character]
	if cpu.cooldowns[1] == 0 and gap > second_range.x and gap < second_range.y and choice > 0.70 - pressure:
		return &"skill_2"
	if gap < Roster.CPU_FIRST_RANGE[cpu.character] and cpu.cooldowns[0] == 0 and choice > 0.55 - pressure:
		return &"skill_1"
	return &"normal" if gap < 178.0 else &""


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_touch_input(event)
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: Key = event.physical_keycode if event.physical_keycode else event.keycode
	if key == KEY_M:
		muted = not muted
		if muted:
			music.stop()
			for player in sounds.values():
				player.stop()
			_stop_voices()
		else:
			_loop_music()
		return
	if key == KEY_F1:
		touch_mode = not touch_mode
		_release_touches()
		_refresh_view()
		return
	if key == KEY_ESCAPE and started and battle.match_winner < 0:
		_set_paused(not paused)
		return
	if not started:
		match key:
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: start_match(player_character)
			KEY_1, KEY_KP_1: _set_mode(false)
			KEY_2, KEY_KP_2: _set_mode(true)
			KEY_F2: _set_full_meter(not full_meter)
			KEY_G: _set_stage((selected_stage + 1) % View.STAGE_NAMES.size())
			KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN:
				var stride := View.SELECT_COLUMNS if key in [KEY_UP, KEY_DOWN] else 1
				var direction := -1 if key in [KEY_LEFT, KEY_UP] else 1
				player_character = posmod(player_character + stride * direction, Roster.PLAYABLE_COUNT)
				_refresh_view()
		return
	if key == KEY_R and (battle.match_winner >= 0 or paused):
		_restart()
		return
	if battle.match_winner >= 0 and key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		_restart()
		return
	if paused or battle.match_winner >= 0:
		if key == KEY_TAB:
			_return_to_select()
		return
	match key:
		KEY_W, KEY_UP: _queue_player_action(&"jump")
		KEY_J: _queue_player_action(&"normal")
		KEY_K: _queue_player_action(&"skill_1")
		KEY_L: _queue_player_action(&"skill_2")
		KEY_U: _queue_player_action(&"skill_3")
		KEY_I: _queue_player_action(&"super")


func _set_full_meter(value: bool) -> void:
	full_meter = value
	if full_meter:
		campaign_mode = false
	_refresh_view()


func _set_mode(campaign: bool) -> void:
	campaign_mode = campaign
	if campaign_mode:
		full_meter = false
	_refresh_view()


func _set_stage(index: int) -> void:
	selected_stage = index
	_refresh_view()


func _queue_player_action(action: StringName) -> void:
	if started and not paused:
		battle.queue_action(0, action)


func _touch_input(event: InputEvent) -> void:
	touch_mode = true
	if not started or paused or battle.match_winner >= 0 or battle.super_side >= 0:
		return
	var at := arena.get_global_transform_with_canvas().affine_inverse() * Vector2(event.position)
	if event is InputEventScreenDrag:
		if event.index == stick_id:
			_update_stick(at)
			get_viewport().set_input_as_handled()
		return
	if not event.pressed or event.canceled:
		if event.index == guard_id:
			guard_id = -1
			get_viewport().set_input_as_handled()
		elif event.index == stick_id:
			stick_id = -1
			stick = Vector2.ZERO
			get_viewport().set_input_as_handled()
		return
	if guard_id < 0 and at.distance_to(View.TOUCH_GUARD) <= View.TOUCH_GUARD_RADIUS:
		guard_id = event.index
		get_viewport().set_input_as_handled()
		return
	if stick_id < 0 and at.distance_to(View.TOUCH_STICK) <= 107.0:
		stick_id = event.index
		_update_stick(at)
		get_viewport().set_input_as_handled()
		return
	for index in View.TOUCH_CENTERS.size():
		if at.distance_to(View.TOUCH_CENTERS[index]) <= float(View.TOUCH_RADII[index]):
			_queue_player_action(View.ACTIONS[index])
			get_viewport().set_input_as_handled()
			return


func _update_stick(at: Vector2) -> void:
	var delta := ((at - View.TOUCH_STICK) / 66.0).limit_length(1.0)
	if delta.y < -0.61 and stick.y >= -0.61:
		battle.queue_action(0, &"jump")
	var horizontal := signf(delta.x) * maxf(0.0, (absf(delta.x) - 0.22) / 0.78)
	stick = Vector2(horizontal, delta.y)


func _release_touches() -> void:
	stick_id = -1
	guard_id = -1
	stick = Vector2.ZERO


func _restart() -> void:
	if web_portrait:
		return
	if not ladder.is_empty() and battle.match_winner == 0:
		bout = (bout + 1) % ladder.size()
	_begin_bout()


func _return_to_select() -> void:
	started = false
	paused = false
	ladder.clear()
	bout = 0
	_release_touches()
	music.stop()
	_stop_voices()
	music.stream_paused = false
	battle.reset_match(player_character, full_meter)
	arena.clear_effects()
	_refresh_view()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_interrupt_match()


func _interrupt_match() -> void:
	if started and not paused and battle.match_winner < 0:
		_set_paused(true)


func _set_paused(value: bool) -> void:
	if not value and web_portrait:
		return
	paused = value
	_release_touches()
	if value:
		var player := battle.fighters[0]
		player.buffer_left = 0
		player.jump_queued = false
	music.stream_paused = value
	for voice in voices:
		voice.stream_paused = value
	_refresh_view()


func _down(key: Key) -> bool:
	return Input.is_physical_key_pressed(key)


func _play_event(event: Dictionary) -> void:
	if muted:
		return
	var sound: StringName
	match event["kind"]:
		&"start":
			var move: StringName = event["move"]
			var side: int = event["side"]
			var slot: int = Roster.SKILLS[battle.fighters[side].character].find(move)
			if slot >= 0:
				_speak(side, slot)
			sound = move if sounds.has(move) else (&"super_start" if move == &"super" else &"swing")
		&"hit":
			if event["last"]:
				sound = &"final"
			else:
				sound = &"heavy" if Rules.is_skill(event["move"]) or event["move"] in [&"super", &"heel", &"hook"] else &"light"
		&"block", &"barrier": sound = &"guard"
		&"release": sound = EFFECT_CUES[event["effect"]]
		&"super", &"cut_in", &"liu_charge", &"gu_charge", &"ko", &"fight": sound = event["kind"]
		_: return
	var player: AudioStreamPlayer = sounds[sound]
	var pitch := randf_range(0.91, 1.08) if sound in [&"swing", &"light", &"heavy"] else 1.0
	if event["kind"] == &"release":
		pitch = 1.20 if event["effect"] == &"ribbon_high" else 0.88
	elif event["kind"] == &"hit" and event["move"] == &"second_question":
		pitch = 1.13 if event["move_tick"] == Rules.MOVES[&"second_question"]["hits"][0] else 0.82
	player.pitch_scale = pitch
	player.play()


func _speak(side: int, slot: int) -> void:
	if muted:
		return
	var player := voices[side]
	player.stream = Voice.CLIPS[battle.fighters[side].character][slot]
	player.play()


func _stop_voices() -> void:
	for player in voices:
		player.stop()
		player.stream = null
		player.stream_paused = false
