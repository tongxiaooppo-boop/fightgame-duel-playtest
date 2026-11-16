extends RefCounted

const Roster := preload("res://2D/duel_roster.gd")
const TICK_RATE := 60
const ECHO_WAVE_INTERVAL := 13
const ROUND_TICKS := 60 * TICK_RATE
const MAX_HP := 1000
const BOSS_HP := 1320
const MAX_METER := 360
const LEFT_EDGE := 108.0
const RIGHT_EDGE := 1172.0
const BODY_WIDTH := 96.0
const BUFFER_TICKS := 16
const PUNCH_START_RANGE := 133.0
const SUPER_SLOW_END := 18
const SUPER_PORTRAIT_END := 44
const SUPER_FINISH_CUE := 24
const SUPER_FINISH_HOLD := 6

# Move data is measured in simulation ticks and pixels at the arena's design size.
const MOVES := {
	&"jab": {"hits": [5], "end": 21, "damage": 17, "reach": 151.0, "stun": 23, "step": 24.0},
	&"cross": {"hits": [6], "end": 23, "damage": 21, "reach": 164.0, "stun": 24, "step": 31.0},
	&"hook": {"hits": [7], "end": 29, "damage": 27, "reach": 184.0, "stun": 25, "step": 37.0},
	&"kick": {"hits": [8], "end": 27, "damage": 21, "reach": 195.0, "stun": 25, "step": 29.0},
	&"roundhouse": {"hits": [7], "end": 29, "damage": 25, "reach": 209.0, "stun": 26, "step": 38.0},
	&"heel": {"hits": [9], "end": 33, "damage": 32, "reach": 217.0, "stun": 28, "step": 45.0},
	&"lane_step": {"hits": [8], "end": 30, "damage": 135, "reach": 183.0, "stun": 27, "step": 24.0},
	&"ribbon_split": {"hits": [], "casts": [9, 15], "end": 37},
	&"paper_flock": {"hits": [], "casts": [4], "end": 37},
	&"second_question": {"hits": [7, 16], "end": 35, "damage": 77, "reach": 235.0, "stun": 27, "step": 25.0},
	&"afterimage": {"hits": [], "casts": [4], "end": 34},
	&"echo_swarm": {"hits": [], "casts": [8], "end": 44},
	&"copper_palm": {"hits": [], "end": 33, "shots": [[9, &"copper_bolt", 70.0]]},
	&"copper_guard": {"hits": [], "end": 38, "counter": [5, 18, &"copper_shock"]},
	&"copper_volley": {"hits": [], "end": 44, "shots": [[9, &"copper_ray", 62.0], [18, &"copper_ray", 62.0], [31, &"copper_ray", 62.0]]},
	&"pile_driver": {"hits": [11], "end": 34, "damage": 170, "reach": 196.0, "stun": 29, "step": 35.0, "rush": [4, 11, 10.0, 0.0], "push": 7.0},
	&"steel_barrier": {"hits": [], "end": 33, "shots": [[8, &"barrier", 68.0], [8, &"barrier_sweep", 93.0]]},
	&"steel_wheel": {"hits": [], "end": 45, "shots": [[8, &"wheel", 73.0]]},
	&"station_elbow": {"hits": [7], "end": 28, "damage": 125, "reach": 178.0, "stun": 25, "step": 25.0, "rush": [1, 7, 25.0, 0.0]},
	&"return_line": {"hits": [], "end": 32, "rush": [3, 12, -12.0, 0.0], "shots": [[3, &"line_trap", 116.0]]},
	&"ridge_dash": {"hits": [24], "end": 41, "damage": 174, "reach": 190.0, "stun": 30, "step": 31.0, "rush": [6, 24, 12.0, 8.5], "shots": [[6, &"ridge_marker", 218.0]]},
	&"tide_palms": {"hits": [7, 15], "end": 33, "damage": 76, "reach": 216.0, "stun": 26, "step": 33.0, "push": 5.0, "lift": 10.0},
	&"ebb_step": {"hits": [], "end": 34, "rush": [4, 13, -8.0, 0.0], "shots": [[4, &"ebb", 48.0]]},
	&"harbor_wave": {"hits": [], "end": 49, "shots": [[5, &"harbor", 74.0]]},
	&"fan_point": {"hits": [6], "end": 25, "damage": 130, "reach": 242.0, "stun": 26, "step": 23.0},
	&"fan_counter": {"hits": [], "end": 35, "counter": [4, 15, &"fan_reply"]},
	&"returning_fan": {"hits": [], "end": 41, "shots": [[9, &"fan", 66.0]]},
	&"magnet_relay": {"hits": [7], "end": 30, "damage": 83, "reach": 195.0, "stun": 26, "step": 28.0, "shots": [[8, &"magnet", 96.0]]},
	&"machine_drop": {"hits": [], "end": 39, "shots": [[8, &"machine", 76.0]]},
	&"workshop_overload": {"hits": [], "casts": [8], "end": 44},
	&"internal_poll": {"hits": [8, 16], "end": 36, "damage": 83, "reach": 212.0, "stun": 23, "step": 19.0, "rush": [3, 8, 7.0, 0.0]},
	&"folding_chairs": {"hits": [], "end": 36, "shots": [[7, &"chairs", 167.0]]},
	&"victory_scroll": {"hits": [], "end": 45, "shots": [[6, &"results", 65.0]]},
	&"super": {"hits": [10], "end": 42, "damage": 30, "reach": 236.0, "stun": 28, "step": 54.0},
}
const PUNCH_CHAIN := [&"jab", &"cross", &"hook"]
const KICK_CHAIN := [&"kick", &"roundhouse", &"heel"]
const SKILL_ACTIONS := [&"skill_1", &"skill_2", &"skill_3"]
const EFFECTS := {
	&"ribbon_low": {"delay": 3, "duration": 33, "speed": 15.0, "height": 45.0, "half_height": 42.0, "reach": 32.0, "damage": 61, "stun": 20, "lift": 0.0},
	&"ribbon_high": {"delay": 6, "duration": 34, "speed": 14.0, "height": 78.0, "half_height": 43.0, "reach": 31.0, "damage": 78, "stun": 26, "lift": 0.0},
	&"birds": {"delay": 32, "duration": 5, "speed": 0.0, "height": 57.0, "half_height": 67.0, "reach": 81.0, "damage": 155, "stun": 32, "lift": 11.0},
	&"image": {"delay": 10, "duration": 7, "speed": 0.0, "height": 58.0, "half_height": 52.0, "reach": 86.0, "damage": 135, "stun": 26, "lift": 0.0},
	&"echo": {"delay": 11, "duration": 39, "speed": 13.0, "height": 40.0, "half_height": 44.0, "reach": 26.0, "damage": 54, "stun": 23, "lift": 0.0},
	&"copper_shock": {"delay": 3, "duration": 12, "speed": 9.0, "height": 59.0, "half_height": 51.0, "reach": 59.0, "damage": 119, "stun": 26, "lift": 0.0},
	&"copper_bolt": {"delay": 2, "duration": 23, "speed": 18.0, "height": 66.0, "half_height": 42.0, "reach": 30.0, "damage": 137, "stun": 24, "lift": 0.0},
	&"copper_ray": {"delay": 5, "duration": 25, "speed": 14.0, "height": 66.0, "half_height": 44.0, "reach": 36.0, "damage": 55, "stun": 18, "lift": 0.0},
	&"barrier": {"delay": 1, "duration": 77, "speed": 0.0, "height": 60.0, "half_height": 53.0, "reach": 23.0, "damage": 0, "stun": 0, "lift": 0.0},
	&"barrier_sweep": {"delay": 1, "duration": 9, "speed": 7.0, "height": 39.0, "half_height": 39.0, "reach": 52.0, "damage": 120, "stun": 24, "lift": 0.0, "push": 9.0},
	&"wheel": {"delay": 16, "duration": 35, "speed": 15.0, "height": 33.0, "half_height": 38.0, "reach": 43.0, "damage": 148, "stun": 30, "lift": 0.0},
	&"line_trap": {"delay": 5, "duration": 64, "speed": 0.0, "height": 47.0, "half_height": 42.0, "reach": 83.0, "damage": 123, "stun": 25, "lift": 0.0},
	&"ridge_marker": {"delay": 19, "duration": 2, "speed": 0.0, "height": 0.0, "half_height": 0.0, "reach": 0.0, "damage": 0, "stun": 0, "lift": 0.0},
	&"ebb": {"delay": 5, "duration": 21, "speed": 11.0, "height": 54.0, "half_height": 49.0, "reach": 60.0, "damage": 130, "stun": 27, "lift": 0.0, "push": 6.0},
	&"harbor": {"delay": 30, "duration": 36, "speed": 13.0, "height": 77.0, "half_height": 58.0, "reach": 48.0, "damage": 153, "stun": 30, "lift": 12.0},
	&"fan_reply": {"delay": 4, "duration": 6, "speed": 0.0, "height": 58.0, "half_height": 60.0, "reach": 81.0, "damage": 132, "stun": 28, "lift": 0.0},
	&"fan": {"delay": 7, "duration": 50, "speed": 15.0, "height": 73.0, "half_height": 54.0, "reach": 38.0, "damage": 75, "stun": 19, "lift": 0.0, "turn": 25},
	&"magnet": {"delay": 7, "duration": 11, "speed": 6.0, "height": 59.0, "half_height": 50.0, "reach": 51.0, "damage": 59, "stun": 26, "lift": 0.0},
	&"machine": {"delay": 16, "duration": 28, "speed": 9.0, "height": 46.0, "half_height": 43.0, "reach": 55.0, "damage": 139, "stun": 27, "lift": 0.0},
	&"overload": {"delay": 27, "duration": 5, "speed": 0.0, "height": 55.0, "half_height": 51.0, "reach": 84.0, "damage": 185, "stun": 31, "lift": 0.0, "push": 8.0},
	&"chairs": {"delay": 19, "duration": 17, "speed": 0.0, "height": 51.0, "half_height": 48.0, "reach": 90.0, "damage": 144, "stun": 27, "lift": 0.0},
	&"results": {"delay": 15, "duration": 29, "speed": 15.0, "height": 72.0, "half_height": 52.0, "reach": 46.0, "damage": 166, "stun": 30, "lift": 0.0},
}


class Fighter:
	var character := Roster.LIU
	var x := 0.0
	var height := 0.0
	var velocity_y := 0.0
	var push := 0.0
	var facing := 1.0
	var max_hp := MAX_HP
	var hp := MAX_HP
	var meter := 0
	var cooldowns: Array[int] = [0, 0, 0]
	var move: StringName
	var move_tick := 0
	var chain_step := 0
	var last_contact := -100
	var confirmed := false
	var counter_used := false
	var buffered: StringName
	var buffer_left := 0
	var jump_queued := false
	var guarding := false
	var walking := false
	var walk_distance := 0.0
	var hitstun := 0
	var blockstun := 0
	var combo := 0
	var combo_display := 0
	var combo_timer := 0


class SkillEffect:
	var kind: StringName
	var move: StringName
	var side := 0
	var direction := 1.0
	var x := 0.0
	var source_x := 0.0
	var age := 0
	var delay := 0
	var wave := 0
	var active := true
	var confirms := false
	var hit_leg := false


var fighters: Array[Fighter] = []
var events: Array[Dictionary] = []
var effects: Array[SkillEffect] = []
var player_character := Roster.LIU
var opponent_character := Roster.GU
var practice_meter := false
var score: Array[int] = [0, 0]
var round_number := 0
var intro := 0
var round_end := 0
var ticks_left := ROUND_TICKS
var tick := 0
var hitstop := 0
var winner := -2
var match_winner := -1
var super_side := -1
var super_tick := 0
var super_beat := -1
var super_origin := 0.0
var super_start_x := 0.0


func _init() -> void:
	reset_match()


func reset_match(character := Roster.LIU, full_meter := false, opponent := -1) -> void:
	player_character = character
	opponent_character = Roster.RIVALS[character] if opponent < 0 else opponent
	practice_meter = full_meter
	tick = 0
	score = [0, 0]
	match_winner = -1
	round_number = 0
	_start_round()


func _start_round() -> void:
	fighters = [Fighter.new(), Fighter.new()]
	fighters[0].character = player_character
	fighters[1].character = opponent_character
	if opponent_character == Roster.HONG:
		fighters[1].max_hp = BOSS_HP
		fighters[1].hp = BOSS_HP
	if practice_meter:
		fighters[0].meter = MAX_METER
	fighters[0].x = 479.0
	fighters[1].x = 801.0
	fighters[1].facing = -1.0
	round_number += 1
	intro = 99
	round_end = 0
	ticks_left = ROUND_TICKS
	hitstop = 0
	winner = -2
	super_side = -1
	super_tick = 0
	super_beat = -1
	effects.clear()
	events.clear()


func is_live() -> bool:
	return intro == 0 and round_end == 0 and match_winner < 0


func queue_action(side: int, action: StringName) -> void:
	if not is_live() or super_side >= 0:
		return
	var fighter := fighters[side]
	if action == &"jump":
		fighter.jump_queued = true
		return
	if action == &"super" and fighter.meter < MAX_METER:
		return
	var slot := SKILL_ACTIONS.find(action)
	if slot < 0 and action not in [&"normal", &"jab", &"kick", &"super"]:
		return
	if slot >= 0 and fighter.cooldowns[slot] > 0:
		return
	fighter.buffered = action
	fighter.buffer_left = BUFFER_TICKS


func step(axis_1 := 0.0, guard_1 := false, axis_2 := 0.0, guard_2 := false) -> void:
	events.clear()
	if match_winner >= 0:
		return
	if round_end > 0:
		round_end -= 1
		if round_end == 0:
			if winner >= 0 and score[winner] == 2:
				match_winner = winner
			else:
				_start_round()
		return
	if intro > 0:
		intro -= 1
		if intro == 29:
			events.append({"kind": &"fight"})
		return
	if hitstop > 0:
		hitstop -= 1
		return
	if super_side >= 0:
		_advance_super()
		return

	tick += 1
	ticks_left = maxi(0, ticks_left - 1)
	_advance_fighter(fighters[0], fighters[1], axis_1, guard_1, 0)
	_advance_fighter(fighters[1], fighters[0], axis_2, guard_2, 1)
	_separate()
	# Read both contacts before applying damage so simultaneous normals can trade.
	var left_contact := _has_contact(fighters[0], fighters[1])
	var right_contact := _has_contact(fighters[1], fighters[0])
	if left_contact:
		_resolve_contact(0)
	if right_contact and super_side < 0:
		_resolve_contact(1)
	if super_side < 0:
		_advance_effects()
	for event in events:
		if event["kind"] == &"hit":
			fighters[1 - int(event["side"])].move = &""
	if super_side < 0:
		_check_round_end()


func _advance_fighter(fighter: Fighter, other: Fighter, axis: float, guard: bool, side: int) -> void:
	fighter.hitstun = maxi(0, fighter.hitstun - 1)
	fighter.blockstun = maxi(0, fighter.blockstun - 1)
	fighter.combo_timer = maxi(0, fighter.combo_timer - 1)
	for slot in fighter.cooldowns.size():
		fighter.cooldowns[slot] = maxi(0, fighter.cooldowns[slot] - 1)
	if fighter.move != &"":
		fighter.move_tick += 1
		if fighter.move_tick >= int(MOVES[fighter.move]["end"]):
			fighter.move = &""
		else:
			_advance_skill(fighter, other, side)
	fighter.walking = false
	if fighter.move == &"" and fighter.hitstun == 0 and fighter.blockstun == 0:
		fighter.facing = 1.0 if fighter.x <= other.x else -1.0
		fighter.guarding = guard and fighter.height == 0.0
		if fighter.jump_queued and fighter.height == 0.0 and not fighter.guarding:
			fighter.velocity_y = 15.0
		if not fighter.guarding:
			var speed := 4.75 if axis * fighter.facing >= 0.0 else 3.75
			fighter.x += axis * speed
			fighter.walking = axis != 0.0
			fighter.walk_distance += absf(axis) * speed
	else:
		fighter.guarding = fighter.blockstun > 0
	fighter.jump_queued = false
	fighter.height = maxf(0.0, fighter.height + fighter.velocity_y)
	fighter.velocity_y = fighter.velocity_y - 0.78 if fighter.height > 0.0 else 0.0
	fighter.x += fighter.push
	fighter.push = move_toward(fighter.push, 0.0, 0.72)
	_try_start(fighter, other, side)
	fighter.buffer_left = maxi(0, fighter.buffer_left - 1)
	fighter.x = clampf(fighter.x, LEFT_EDGE, RIGHT_EDGE)


func _try_start(fighter: Fighter, other: Fighter, side: int) -> void:
	if fighter.buffer_left == 0 or fighter.hitstun > 0 or fighter.blockstun > 0 or fighter.guarding:
		return
	var action := fighter.buffered
	var slot := SKILL_ACTIONS.find(action)
	var chained := fighter.move != &""
	if chained:
		if not fighter.confirmed or fighter.move_tick < fighter.last_contact + 2 or fighter.move == &"super":
			return
		if is_skill(fighter.move) and action != &"super":
			return
		if fighter.chain_step >= 2 and action in [&"normal", &"jab", &"kick"]:
			return
	if action == &"normal":
		if chained:
			action = &"kick" if fighter.move in KICK_CHAIN else &"jab"
		else:
			action = &"jab" if absf(other.x - fighter.x) <= PUNCH_START_RANGE else &"kick"
	if action == &"super":
		if fighter.meter < MAX_METER:
			return
		fighter.meter = 0
	if slot >= 0:
		if fighter.cooldowns[slot] > 0:
			return
		fighter.cooldowns[slot] = Roster.COOLDOWNS[slot]
		action = Roster.SKILLS[fighter.character][slot]
	fighter.chain_step = fighter.chain_step + 1 if chained else 0
	match action:
		&"jab": fighter.move = PUNCH_CHAIN[mini(fighter.chain_step, 2)]
		&"kick": fighter.move = KICK_CHAIN[mini(fighter.chain_step, 2)]
		_: fighter.move = action
	fighter.facing = 1.0 if fighter.x <= other.x else -1.0
	fighter.move_tick = 0
	fighter.buffer_left = 0
	fighter.confirmed = false
	fighter.counter_used = false
	fighter.last_contact = -100
	fighter.walking = false
	events.append({"kind": &"start", "side": side, "move": fighter.move})


static func is_skill(move: StringName) -> bool:
	return MOVES.has(move) and move != &"super" and move not in PUNCH_CHAIN and move not in KICK_CHAIN


func _advance_skill(fighter: Fighter, other: Fighter, side: int) -> void:
	var age := fighter.move_tick
	match fighter.move:
		&"lane_step":
			if age in range(3, 8):
				var free := maxf(0.0, (other.x - fighter.x) * fighter.facing - BODY_WIDTH)
				fighter.x += fighter.facing * minf(15.0, free)
		&"ribbon_split":
			var casts: Array = MOVES[fighter.move]["casts"]
			if age == casts[0]:
				_spawn(side, &"ribbon_low", fighter.x + fighter.facing * 72.0)
			elif age == casts[1]:
				_spawn(side, &"ribbon_high", fighter.x + fighter.facing * 72.0, true)
		&"paper_flock":
			if age == MOVES[fighter.move]["casts"][0]:
				_spawn(side, &"birds", clampf(other.x, LEFT_EDGE, RIGHT_EDGE), true)
		&"afterimage":
			var cast_tick: int = MOVES[fighter.move]["casts"][0]
			if age == cast_tick:
				var distance := clampf((other.x - fighter.x) * fighter.facing, 70.0, 155.0)
				_spawn(side, &"image", fighter.x + fighter.facing * distance, true)
			if age >= cast_tick and age < cast_tick + 8:
				fighter.x -= fighter.facing * 9.0
		&"workshop_overload":
			if age == MOVES[fighter.move]["casts"][0]:
				var distance := clampf((other.x - fighter.x) * fighter.facing, 105.0, 345.0)
				_spawn(side, &"overload", fighter.x + fighter.facing * distance, true)
		&"echo_swarm":
			if age == MOVES[fighter.move]["casts"][0]:
				for beat in 3:
					_spawn(side, &"echo", fighter.x + fighter.facing * (104.0 - 43.0 * beat), beat == 2, beat)
		_:
			var data: Dictionary = MOVES[fighter.move]
			var counter: Array = data.get("counter", [])
			if not counter.is_empty() and age == int(counter[1]) + 1 and not fighter.counter_used:
				fighter.counter_used = true
				_spawn(side, counter[2], fighter.x + fighter.facing * 91.0, true)
			var rush: Array = data.get("rush", [])
			if not rush.is_empty() and age >= int(rush[0]) and age < int(rush[1]):
				var speed: float = rush[2]
				var free := maxf(0.0, (other.x - fighter.x) * fighter.facing - BODY_WIDTH)
				fighter.x += fighter.facing * (minf(speed, free) if speed > 0.0 else speed)
				if age == int(rush[0]) and fighter.height == 0.0:
					fighter.velocity_y = float(rush[3])
			var shots: Array = data.get("shots", [])
			for shot in shots:
				if age == int(shot[0]):
					_spawn(side, shot[1], fighter.x + fighter.facing * float(shot[2]), shot == shots[-1])


func _spawn(side: int, kind: StringName, x: float, confirms := false, wave := 0) -> void:
	var fighter := fighters[side]
	var effect := SkillEffect.new()
	effect.kind = kind
	effect.move = fighter.move
	effect.side = side
	effect.direction = fighter.facing
	effect.x = clampf(x, LEFT_EDGE, RIGHT_EDGE)
	effect.source_x = fighter.x
	effect.wave = wave
	effect.delay = int(EFFECTS[kind]["delay"]) + wave * ECHO_WAVE_INTERVAL
	effect.confirms = confirms
	effects.append(effect)


func _advance_effects() -> void:
	for index in effects.size():
		var effect := effects[index]
		effect.age += 1
		if not effect.active or effect.age < effect.delay:
			continue
		var data: Dictionary = EFFECTS[effect.kind]
		if effect.age == effect.delay:
			events.append({"kind": &"release", "effect": effect.kind})
		var turn := int(data.get("turn", 0))
		if turn > 0 and effect.age == effect.delay + turn:
			effect.direction = -effect.direction
			effect.hit_leg = false
			events.append({"kind": &"release", "effect": effect.kind})
		var speed := float(data["speed"])
		var previous_x := effect.x
		effect.x += effect.direction * speed
		if turn > 0:
			effect.x = clampf(effect.x, LEFT_EDGE - 40.0, RIGHT_EDGE + 40.0)
		if effect.age >= effect.delay + int(data["duration"]) or effect.x < LEFT_EDGE - 48.0 or effect.x > RIGHT_EDGE + 48.0:
			effect.active = false
			continue
		if int(data["damage"]) == 0 or effect.hit_leg:
			continue
		if speed > 0.0 and _intercept_projectile(effect, data, previous_x):
			continue
		var target := fighters[1 - effect.side]
		if absf(target.x - effect.x) > float(data["reach"]):
			continue
		if absf(target.height + 55.0 - float(data["height"])) > float(data["half_height"]):
			continue
		effect.hit_leg = turn > 0
		effect.active = turn > 0
		var incoming := effect.direction
		if is_zero_approx(speed) and absf(target.x - effect.x) > 4.0:
			incoming = signf(target.x - effect.x)
		var striker := fighters[effect.side]
		var can_face := effect.kind in [&"birds", &"overload"] or target.facing * incoming < 0.0
		var blocked := can_face and (target.guarding or _try_counter(1 - effect.side))
		if effect.confirms and striker.move == effect.move:
			striker.confirmed = not blocked
			striker.last_contact = striker.move_tick
		if blocked:
			_block(effect.side, effect.move, incoming)
		else:
			_damage(effect.side, int(data["damage"]), int(data["stun"]), effect.move, incoming,
				false, false, float(data.get("push", 2.0)))
			target.velocity_y = maxf(target.velocity_y, float(data["lift"]))
			hitstop = maxi(hitstop, 5)
		var contact: Dictionary = events[-1]
		contact["effect"] = effect.kind
		contact["effect_x"] = effect.x
		if effect.kind == &"echo":
			contact["wave"] = effect.wave
	for index in range(effects.size() - 1, -1, -1):
		if not effects[index].active:
			effects.remove_at(index)


func _intercept_projectile(effect: SkillEffect, data: Dictionary, previous_x: float) -> bool:
	for barrier in effects:
		if barrier.kind != &"barrier" or barrier.side == effect.side or not barrier.active or barrier.age < barrier.delay:
			continue
		if absf(float(data["height"]) - 60.0) > 53.0:
			continue
		if barrier.x < minf(previous_x, effect.x) - 23.0 or barrier.x > maxf(previous_x, effect.x) + 23.0:
			continue
		barrier.active = false
		effect.active = false
		var direction := effect.direction
		events.append({"kind": &"barrier", "side": effect.side, "move": effect.move, "dir": direction,
			"position": Vector2(barrier.x, 0.0)})
		return true
	return false


func _try_counter(side: int) -> bool:
	var fighter := fighters[side]
	if fighter.move == &"" or fighter.counter_used or fighter.hitstun > 0 or fighter.height > 0.0:
		return false
	var counter: Array = MOVES[fighter.move].get("counter", [])
	if counter.is_empty() or fighter.move_tick < int(counter[0]) or fighter.move_tick > int(counter[1]):
		return false
	fighter.counter_used = true
	_spawn(side, counter[2], fighter.x + fighter.facing * 91.0, true)
	return true


func _separate() -> void:
	var left := fighters[0] if fighters[0].x <= fighters[1].x else fighters[1]
	var right := fighters[1] if left == fighters[0] else fighters[0]
	if absf(left.height - right.height) > 99.0:
		return
	var gap := BODY_WIDTH - (right.x - left.x)
	if gap <= 0.0:
		return
	left.x = clampf(left.x - gap * 0.5, LEFT_EDGE, RIGHT_EDGE - BODY_WIDTH)
	right.x = clampf(left.x + BODY_WIDTH, LEFT_EDGE + BODY_WIDTH, RIGHT_EDGE)


func _has_contact(attacker: Fighter, defender: Fighter) -> bool:
	if attacker.move == &"":
		return false
	var data: Dictionary = MOVES[attacker.move]
	if not attacker.move_tick in data["hits"]:
		return false
	return (defender.x - attacker.x) * attacker.facing > 0.0 \
		and absf(defender.x - attacker.x) <= float(data["reach"]) \
		and absf(defender.height - attacker.height) < 90.0


func _resolve_contact(side: int) -> void:
	var attacker := fighters[side]
	var defender := fighters[1 - side]
	var move := attacker.move
	var data: Dictionary = MOVES[move]
	var blocked := (attacker.x - defender.x) * defender.facing > 0.0 and (defender.guarding or _try_counter(1 - side))
	attacker.x += attacker.facing * minf(float(data["step"]), maxf(0.0, absf(defender.x - attacker.x) - BODY_WIDTH))
	attacker.confirmed = not blocked and attacker.move_tick == data["hits"][-1]
	attacker.last_contact = attacker.move_tick
	if blocked:
		_block(side, move, attacker.facing)
		return
	var cinematic := move == &"super"
	var push := float(data.get("push", 2.0)) if attacker.move_tick == data["hits"][-1] else 2.0
	_damage(side, int(data["damage"]), int(data["stun"]), move, attacker.facing, cinematic, false, push)
	if attacker.confirmed and data.has("lift"):
		defender.velocity_y = maxf(defender.velocity_y, float(data["lift"]))
	hitstop = maxi(hitstop, 6 if move in [&"hook", &"heel"] or is_skill(move) else 4)
	if cinematic:
		super_side = side
		super_tick = 0
		super_beat = -1
		super_origin = (attacker.x + defender.x) * 0.5
		super_start_x = defender.x
		attacker.buffer_left = 0
		defender.buffer_left = 0
		defender.guarding = false
		hitstop = 0
		events.append({"kind": &"super", "side": side})


func _block(side: int, move: StringName, direction: float) -> void:
	var attacker := fighters[side]
	var defender := fighters[1 - side]
	defender.blockstun = 15 if move == &"super" else 12
	defender.push = direction * 2.0
	attacker.combo = 0
	if move != &"super":
		attacker.meter = mini(MAX_METER, attacker.meter + 4)
	defender.meter = mini(MAX_METER, defender.meter + 10)
	events.append(_contact_event(&"block", side, move, direction))
	hitstop = maxi(hitstop, 4)


func _damage(side: int, points: int, stun: int, move: StringName, direction: float,
		lethal_hold := false, last := false, push := 2.0) -> void:
	var attacker := fighters[side]
	var defender := fighters[1 - side]
	if defender.hitstun == 0:
		attacker.combo = 0
	defender.hp = maxi(1 if lethal_hold else 0, defender.hp - points)
	defender.hitstun = stun
	defender.blockstun = 0
	defender.push = direction * (12.0 if last else push)
	attacker.combo += 1
	attacker.combo_display = attacker.combo
	attacker.combo_timer = 82
	if move != &"super":
		attacker.meter = mini(MAX_METER, attacker.meter + (13 if is_skill(move) else 17))
		defender.meter = mini(MAX_METER, defender.meter + 9)
	var event := _contact_event(&"hit", side, move, direction)
	event["last"] = last
	events.append(event)


func _contact_event(kind: StringName, side: int, move: StringName, direction: float) -> Dictionary:
	var striker := fighters[side]
	var target := fighters[1 - side]
	return {"kind": kind, "side": side, "move": move, "dir": direction,
		"position": Vector2(target.x - direction * 23.0, -target.height), "move_tick": striker.move_tick}


func _advance_super() -> void:
	super_tick += 1
	var attacker := fighters[super_side]
	var defender := fighters[1 - super_side]
	var character := attacker.character
	var beats: Array = Roster.SUPER_BEATS[character]
	var final_tick: int = beats[-1]
	attacker.height = 0.0
	defender.height = 0.0
	attacker.velocity_y = 0.0
	defender.velocity_y = 0.0
	if super_tick <= SUPER_SLOW_END:
		var drift := smoothstep(0.0, float(SUPER_SLOW_END), float(super_tick))
		defender.x = clampf(super_start_x + attacker.facing * drift * 23.0, LEFT_EDGE, RIGHT_EDGE)
		defender.height = drift * (23.0 if character == Roster.LIU else 12.0)
	elif super_tick < SUPER_PORTRAIT_END:
		defender.height = 23.0 if character == Roster.LIU else 12.0
	var beat := beats.find(super_tick)
	if beat >= 0:
		super_beat = beat
		var last := beat == beats.size() - 1
		defender.x = clampf(defender.x + attacker.facing * (19.0 if last else 12.0), LEFT_EDGE, RIGHT_EDGE)
		attacker.x = clampf(defender.x - attacker.facing * (135.0 if last else BODY_WIDTH), LEFT_EDGE, RIGHT_EDGE)
		_damage(super_side, Roster.SUPER_DAMAGE[character][beat], 29, &"super", attacker.facing, not last, last)
	if super_tick >= SUPER_PORTRAIT_END and super_tick < final_tick:
		var follow := clampf(defender.x - attacker.facing * BODY_WIDTH, LEFT_EDGE, RIGHT_EDGE)
		attacker.x = move_toward(attacker.x, follow, 14.0)
	if super_beat >= 0:
		var elapsed := super_tick - int(beats[super_beat])
		var last := super_beat == beats.size() - 1
		if last:
			elapsed = maxi(0, elapsed - SUPER_FINISH_HOLD)
		var air_time := 26.0 if last else 15.0
		defender.height = float(Roster.SUPER_LIFT[character][super_beat]) * sin(PI * clampf(elapsed / air_time, 0.0, 1.0))
		if super_beat in ([2, 4] if character == Roster.LIU else [3]):
			var leap := 53.0 if character == Roster.LIU else 30.0
			attacker.height = leap * sin(PI * clampf(elapsed / 13.0, 0.0, 1.0))
	var launch_tick := super_tick - final_tick - SUPER_FINISH_HOLD
	if launch_tick > 0:
		defender.x = clampf(defender.x + attacker.facing * maxf(0.0, 12.0 - launch_tick * 0.54), LEFT_EDGE, RIGHT_EDGE)
	if super_tick < int(Roster.SUPER_LENGTH[character]):
		return
	attacker.move = &""
	defender.move = &""
	defender.height = 0.0
	defender.hitstun = 23
	_separate()
	super_side = -1
	_check_round_end()


func _check_round_end() -> void:
	if fighters[0].hp > 0 and fighters[1].hp > 0 and ticks_left > 0:
		return
	var difference := fighters[0].hp * fighters[1].max_hp - fighters[1].hp * fighters[0].max_hp
	winner = 0 if difference > 0 else (1 if difference < 0 else -1)
	if winner >= 0:
		score[winner] += 1
	effects.clear()
	round_end = 136
	events.append({"kind": &"ko", "side": winner})
