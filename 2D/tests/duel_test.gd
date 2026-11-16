extends SceneTree

const Rules := preload("res://2D/duel_rules.gd")
const Roster := preload("res://2D/duel_roster.gd")

var failures := 0


func _initialize() -> void:
	_test_chain([&"jab", &"jab", &"jab"], [&"jab", &"cross", &"hook"])
	_test_chain([&"kick", &"kick", &"kick"], [&"kick", &"roundhouse", &"heel"])
	_test_chain([&"jab", &"kick", &"jab"], [&"jab", &"roundhouse", &"hook"])
	_test_normal_chain(Rules.PUNCH_START_RANGE, [&"jab", &"cross", &"hook"], 65)
	_test_normal_chain(Rules.PUNCH_START_RANGE + 1.0, [&"kick", &"roundhouse", &"heel"], 78)
	_test_corner_pressure(0, &"jab", 65)
	_test_corner_pressure(1, &"kick", 78)
	_test_opener_recovery()
	_test_defense()
	_test_skill_bindings_and_cooldowns()
	_test_ribbons_and_afterimage()
	_test_flock()
	_test_echoes()
	_test_skill_cancel()
	_test_campaign_skills()
	_test_midrange_specials()
	_test_meter_and_damage()
	for character in Roster.NAMES.size():
		_test_super(character, character % 2)
	_test_super_whiff()
	_test_trade()
	_test_rounds()
	print("Duel tests complete: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _duel(gap := 113.0, character := Roster.LIU, full_meter := false) -> Rules:
	var duel := Rules.new()
	duel.reset_match(character, full_meter, Roster.LIU if character == Roster.HONG else -1)
	duel.intro = 0
	duel.fighters[0].x = 540.0
	duel.fighters[1].x = 540.0 + gap
	return duel


func _until_hit(duel: Rules, limit := 40) -> Dictionary:
	for index in limit:
		duel.step()
		for event in duel.events:
			if event["kind"] == &"hit":
				return event
	return {}


func _test_chain(inputs: Array, expected: Array) -> void:
	var duel := _duel()
	for index in inputs.size():
		duel.queue_action(0, inputs[index])
		var event := _until_hit(duel)
		_check(event.get("move", &"") == expected[index], "chain advances to %s" % expected[index])
		_check(duel.fighters[0].combo == index + 1, "chain retains consecutive hit count")
		if index == 0:
			_check(duel.hitstop > 0, "contact freezes battle")
			var frame := duel.fighters[0].move_tick
			duel.step()
			_check(duel.fighters[0].move_tick == frame, "hitstop freezes the contact pose")


func _test_normal_chain(gap: float, expected: Array, expected_damage: int) -> void:
	var duel := _duel(gap)
	for move in expected:
		duel.queue_action(0, &"normal")
		_check(_until_hit(duel).get("move", &"") == move, "normal follows its starting chain to %s" % move)
	duel.queue_action(0, &"normal")
	_check(_until_hit(duel, 45).is_empty(), "a fourth buffered normal does not extend the chain")
	_check(duel.fighters[0].combo_display == 3, "three normal inputs produce three consecutive hits")
	_check(Rules.MAX_HP - duel.fighters[1].hp == expected_damage, "three normals deal the intended total")


func _test_corner_pressure(side: int, opener: StringName, chain_damage: int) -> void:
	var duel := _duel()
	var attacker := duel.fighters[side]
	var defender := duel.fighters[1 - side]
	defender.x = Rules.RIGHT_EDGE if side == 0 else Rules.LEFT_EDGE
	attacker.x = defender.x - attacker.facing * Rules.BODY_WIDTH
	for count in 3:
		duel.queue_action(side, opener)
		_until_hit(duel)
	_check(attacker.combo == 3, "a corner finisher still lands as a three-hit combo")
	duel.queue_action(side, &"skill_1")
	for frame in 17:
		duel.step()
	_check(attacker.cooldowns[0] == 0, "third normal ends the cancel window")
	_check(absf(defender.x - attacker.x) > Rules.BODY_WIDTH + 35.0, "the finisher opens space at either wall")
	for frame in 100:
		duel.queue_action(side, &"normal")
		var toward := 1.0 if side == 0 else -1.0
		duel.step(toward if side == 0 else 0.0, side == 1, toward if side == 1 else 0.0, side == 0)
	_check(defender.hp == defender.max_hp - chain_damage, "guard breaks sustained corner pressure after three hits")


func _test_opener_recovery() -> void:
	var duel := _duel()
	var attacker := duel.fighters[0]
	var defender := duel.fighters[1]
	defender.x = Rules.RIGHT_EDGE
	attacker.x = defender.x - Rules.BODY_WIDTH
	duel.queue_action(0, &"jab")
	_until_hit(duel)
	while attacker.move != &"":
		duel.step(0.0, false, 0.0, true)
	_check(defender.guarding, "recovery on a single corner jab gives the defender a turn")
	duel.queue_action(0, &"jab")
	for frame in 12:
		duel.step(0.0, false, 0.0, true)
	_check(defender.hp == defender.max_hp - int(Rules.MOVES[&"jab"]["damage"]),
		"repeating a fresh jab cannot keep the defender in hitstun")


func _test_defense() -> void:
	var duel := _duel()
	duel.queue_action(0, &"normal")
	for index in 8:
		duel.step(0.0, false, 0.0, true)
	duel.queue_action(0, &"normal")
	for index in 11:
		duel.step(0.0, false, 0.0, true)
	_check(duel.fighters[1].hp == Rules.MAX_HP, "guard prevents damage")
	_check(duel.fighters[0].move == &"jab", "blocked jab cannot chain")
	duel = _duel(401.0)
	duel.queue_action(0, &"normal")
	for index in 10:
		duel.step()
	duel.queue_action(0, &"normal")
	for index in 10:
		duel.step()
	_check(duel.fighters[0].move == &"kick", "whiffed kick cannot chain")
	duel.queue_action(1, &"jump")
	duel.step()
	_check(duel.fighters[1].height > 0.0, "jump has independent vertical height")


func _test_skill_bindings_and_cooldowns() -> void:
	for character in Roster.NAMES.size():
		for slot in Rules.SKILL_ACTIONS.size():
			var duel := _duel(500.0, character)
			var fighter := duel.fighters[0]
			var action: StringName = Rules.SKILL_ACTIONS[slot]
			duel.queue_action(0, action)
			duel.step()
			_check(fighter.move == Roster.SKILLS[character][slot], "skill input maps to selected character's move")
			for other_slot in fighter.cooldowns.size():
				_check(fighter.cooldowns[other_slot] == (Roster.COOLDOWNS[slot] if other_slot == slot else 0),
					"skill starts only its own cooldown")
			for tick in 100:
				duel.step()
			duel.queue_action(0, action)
			_check(fighter.buffer_left == 0 and fighter.cooldowns[slot] > 0, "cooling skill rejects input")
			for tick in fighter.cooldowns[slot]:
				duel.step()
			duel.queue_action(0, action)
			duel.step()
			_check(fighter.move == Roster.SKILLS[character][slot], "skill is usable when cooldown expires")
			duel.reset_match(character, false, Roster.LIU if character == Roster.HONG else -1)
			_check(duel.fighters[0].cooldowns == [0, 0, 0], "reset clears all cooldowns")


func _test_ribbons_and_afterimage() -> void:
	var duel := _duel(230.0)
	duel.queue_action(0, &"skill_2")
	for beat in 2:
		_check(_until_hit(duel, 60).get("move", &"") == &"ribbon_split", "Liu's ribbons reach midrange in two waves")
	_check(duel.fighters[0].combo_display == 2, "two ribbons can combo")
	duel = _duel(110.0, Roster.GU)
	var cast_x := duel.fighters[0].x
	duel.queue_action(0, &"skill_2")
	_check(_until_hit(duel).get("move", &"") == &"afterimage", "Gu's residual image hits at the cast location")
	_check(duel.fighters[0].x < cast_x - 60.0, "Gu retreats while the image stays behind")


func _test_flock() -> void:
	var duel := _duel(270.0)
	duel.queue_action(0, &"skill_3")
	for tick in 20:
		duel.step()
	_check(duel.effects.size() == 1 and duel.fighters[1].hp == Rules.MAX_HP, "bird drop telegraphs before dealing damage")
	if not duel.effects.is_empty():
		_check(duel.effects[0].x == duel.fighters[1].x, "bird drop marks a fixed landing point")
	_check(_until_hit(duel).get("move", &"") == &"paper_flock", "stationary target is hit by the dive")
	_check(duel.fighters[1].velocity_y > 0.0, "bird dive launches its target")
	duel = _duel(270.0)
	duel.queue_action(0, &"skill_3")
	for tick in 65:
		duel.step(0.0, false, 0.0, true)
	_check(duel.fighters[1].hp == Rules.MAX_HP, "bird dive can be blocked")
	duel = _duel(270.0)
	duel.queue_action(0, &"skill_3")
	for tick in 7:
		duel.step()
	for tick in 52:
		duel.step(0.0, false, 1.0, false)
	_check(duel.fighters[1].hp == Rules.MAX_HP and duel.effects.is_empty(), "moving out of the warning avoids the dive")


func _test_echoes() -> void:
	var duel := _duel(225.0, Roster.GU)
	duel.queue_action(0, &"skill_3")
	var release_ticks: Array[int] = []
	var contacts: Array[int] = []
	for tick in 150:
		duel.step()
		for event in duel.events:
			if event["kind"] == &"release" and event["effect"] == &"echo":
				release_ticks.append(duel.tick)
			elif event["kind"] == &"hit" and event["move"] == &"echo_swarm":
				_check(event.get("effect") == &"echo" and event.has("effect_x"), "an echo carries its contact position to the renderer")
				contacts.append(event.get("wave", -1))
	_check(release_ticks == [19, 32, 45], "each echo releases on its own cue")
	_check(contacts == [0, 1, 2] and duel.effects.is_empty(), "each of the three echoes identifies its wave on contact")


func _test_skill_cancel() -> void:
	var duel := _duel(114.0, Roster.GU, true)
	duel.queue_action(0, &"normal")
	_check(_until_hit(duel).get("move", &"") == &"jab", "normal starts the cancel route")
	duel.queue_action(0, &"skill_1")
	_check(_until_hit(duel).get("move", &"") == &"second_question", "hit normal cancels into Gu's skill")
	_check(not duel.fighters[0].confirmed, "Gu's first palm does not yet confirm the super cancel")
	duel.queue_action(0, &"super")
	_check(_until_hit(duel).get("move", &"") == &"second_question", "second palm lands before the queued super")
	_check(_until_hit(duel).get("move", &"") == &"super", "confirmed second palm links into the super")


func _test_super(character: int, side: int) -> void:
	var duel := _duel()
	var striker := duel.fighters[side]
	var target := duel.fighters[1 - side]
	striker.character = character
	striker.meter = Rules.MAX_METER
	if side == 0:
		striker.x = Rules.RIGHT_EDGE - 113.0
		target.x = Rules.RIGHT_EDGE
	else:
		striker.x = Rules.LEFT_EDGE + 113.0
		target.x = Rules.LEFT_EDGE
	target.hp = 12
	duel.queue_action(side, &"super")
	_check(_until_hit(duel).get("move", &"") == &"super", "super opener connects near either wall")
	_check(duel.super_side == side and duel.super_tick == 0, "first contact activates cinematic once")
	_check(striker.meter == 0 and target.hp == 1 and duel.round_end == 0, "lethal opener spends meter and holds the round")
	var frozen_clock := duel.ticks_left
	duel.queue_action(1 - side, &"jab")
	var history: Array[int] = []
	var last_hits := 0
	var launch_height := 0.0
	var beats: Array = Roster.SUPER_BEATS[character]
	var finale: int = beats[-1]
	var length: int = Roster.SUPER_LENGTH[character]
	var impact_x := 0.0
	for index in length:
		duel.step()
		if duel.super_tick == finale:
			impact_x = target.x
		elif duel.super_tick <= finale + Rules.SUPER_FINISH_HOLD and duel.super_tick > finale:
			_check(is_equal_approx(impact_x, target.x) and is_zero_approx(target.height), "finisher holds before launching")
		elif duel.super_tick > finale:
			launch_height = maxf(launch_height, target.height)
		for event in duel.events:
			if event["kind"] == &"hit":
				history.append(duel.super_tick)
				last_hits += int(event["last"])
		_check(duel.round_end == 0 or index == length - 1, "cinematic finishes before round resolution")
	_check(duel.ticks_left == frozen_clock and target.buffer_left == 0, "timer and ordinary input stay frozen during super")
	_check(history == beats, "each super hits on its six distinct follow-up beats")
	_check(last_hits == 1, "super flags exactly one finisher")
	_check(launch_height >= 80.0, "finisher launches the opponent before the cinematic ends")
	_check(striker.combo_display == 7, "super shows seven hits")
	_check(target.hp == 0 and duel.score[side] == 1, "finisher resolves knockout")
	_check(target.x >= Rules.LEFT_EDGE and target.x <= Rules.RIGHT_EDGE, "finisher respects stage edges")


func _test_campaign_skills() -> void:
	var gaps := [[146.0, 175.0, 266.0], [166.0, 170.0, 276.0], [158.0, 175.0, 275.0],
		[129.0, 180.0, 265.0], [152.0, 155.0, 235.0], [120.0, 112.0, 188.0], [146.0, 100.0, 264.0]]
	for character in range(Roster.PEI, Roster.NAMES.size()):
		for slot in Rules.SKILL_ACTIONS.size():
			var gap: float = gaps[character - Roster.PEI][slot]
			var duel := _duel(gap, character)
			duel.queue_action(0, Rules.SKILL_ACTIONS[slot])
			_check(_until_hit(duel, 100).get("move", &"") == Roster.SKILLS[character][slot],
				"%s can connect at its intended range" % Roster.SKILL_NAMES[character][slot])
	for character in [Roster.PEI, Roster.WEN]:
		var duel := _duel(113.0, character)
		duel.queue_action(0, &"skill_2")
		duel.queue_action(1, &"normal")
		_check(_until_hit(duel).get("move", &"") == Roster.SKILLS[character][1]
			and duel.fighters[0].hp == Rules.MAX_HP, "counter guards one blow and fires a reply")
	var barrier := _duel(278.0, Roster.PEI)
	barrier.queue_action(1, &"skill_2")
	for tick in 10:
		barrier.step()
	barrier.queue_action(0, &"skill_3")
	var intercepts := 0
	var later_hits := 0
	for tick in 100:
		barrier.step()
		for event in barrier.events:
			intercepts += int(event["kind"] == &"barrier")
			later_hits += int(event["kind"] == &"hit")
	_check(intercepts == 1 and later_hits > 0, "steel barrier stops one projectile before disappearing")
	var fan := _duel(218.0, Roster.WEN)
	fan.queue_action(0, &"skill_3")
	var directions: Array[float] = []
	for tick in 110:
		fan.step()
		for event in fan.events:
			if event["kind"] == &"hit":
				directions.append(event["dir"])
	_check(directions == [1.0, -1.0], "returning fan hits once per direction")


func _test_midrange_specials() -> void:
	var duel := _duel(460.0, Roster.PEI)
	duel.queue_action(0, &"skill_1")
	_check(_until_hit(duel).get("effect") == &"copper_bolt" and duel.fighters[0].x == 540.0,
		"Pei can hit at long range without moving")
	duel = _duel(300.0, Roster.LU)
	duel.queue_action(0, &"skill_1")
	_check(_until_hit(duel).get("move") == &"station_elbow" and duel.fighters[0].x > 670.0,
		"Lu closes a gap outside normal range with his rush")
	duel = _duel(200.0, Roster.RUAN)
	duel.queue_action(0, &"skill_1")
	_until_hit(duel)
	_check(is_zero_approx(duel.fighters[1].velocity_y), "Ruan's first strike stays grounded")
	_check(not _until_hit(duel).is_empty() and duel.fighters[1].velocity_y > 0.0,
		"Ruan's follow-up launches the target")
	duel = _duel(325.0, Roster.FANG)
	duel.queue_action(0, &"skill_3")
	for tick in 12:
		duel.step()
	_check(duel.effects.size() == 1 and duel.effects[0].x == duel.fighters[1].x
		and duel.fighters[1].hp == Rules.MAX_HP, "Fang locks a target position before the blast")
	for tick in 40:
		duel.step(0.0, false, 1.0)
	_check(duel.fighters[1].hp == Rules.MAX_HP, "moving out of Fang's marked area avoids the blast")


func _test_meter_and_damage() -> void:
	var duel := _duel()
	for hit in 22:
		duel.fighters[0].move = &""
		duel.fighters[0].x = 540.0
		duel.fighters[1].x = 653.0
		duel.fighters[1].push = 0.0
		duel.hitstop = 0
		duel.queue_action(0, &"normal")
		_check(_until_hit(duel).get("move", &"") == &"jab", "meter test lands a single jab")
		_check((duel.fighters[0].meter == Rules.MAX_METER) == (hit == 21), "full meter requires twenty-two single jabs")
	var special := _duel()
	special.queue_action(0, &"skill_1")
	_until_hit(special)
	_check(Rules.MAX_HP - special.fighters[1].hp == 135, "Liu's rushing special deals its full damage")


func _test_super_whiff() -> void:
	var duel := _duel(410.0, Roster.LIU, true)
	duel.queue_action(0, &"super")
	_check(_until_hit(duel, 50).is_empty(), "out-of-range super misses")
	_check(duel.super_side == -1, "miss does not activate cinematic")
	duel.queue_action(0, &"super")
	duel.step()
	_check(duel.fighters[0].move == &"" and duel.fighters[0].meter == 0, "empty super meter prevents another attempt")
	duel = _duel(113.0, Roster.GU, true)
	duel.queue_action(0, &"super")
	for index in 55:
		duel.step(0.0, false, 0.0, true)
	_check(duel.super_side == -1 and duel.fighters[0].meter == 0, "blocked super spends meter with no cut-in")
	_check(duel.fighters[1].hp == Rules.MAX_HP, "blocked super does no damage")
	duel = _duel()
	duel.queue_action(0, &"super")
	_check(duel.fighters[0].buffer_left == 0, "normal round starts without full meter")
	duel.queue_action(0, &"normal")
	_until_hit(duel)
	_check(duel.fighters[0].meter > 0 and duel.fighters[1].meter > 0, "attack and taking damage build meter")


func _test_trade() -> void:
	var duel := _duel()
	duel.queue_action(0, &"jab")
	duel.queue_action(1, &"jab")
	_until_hit(duel)
	_check(duel.fighters[0].hp == duel.fighters[1].hp and duel.fighters[0].hp < Rules.MAX_HP,
		"simultaneous jabs trade damage")
	_check(duel.fighters[0].move == &"" and duel.fighters[1].move == &"", "trade interrupts both states")


func _test_rounds() -> void:
	var duel := _duel()
	for round_index in 2:
		duel.ticks_left = 1
		duel.fighters[1].hp -= 1
		duel.step()
		_check(duel.score[0] == round_index + 1, "timeout awards the round to higher health")
		for tick in duel.round_end:
			duel.step()
		duel.intro = 0
	_check(duel.match_winner == 0, "two round wins end the match")
	duel.reset_match()
	_check(duel.score == [0, 0] and duel.match_winner == -1 and duel.round_number == 1, "rematch restores initial state")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
