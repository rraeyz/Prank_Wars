extends Node
## Global config, tunables, prank/task tables, input map and saved settings (autoload "Config").

const VERSION := "0.1.0"
const STORE_URL := "store.steampowered.com — Prank Wars"

# --- Match timing (seconds). Change here only. ---
var intro_time := 4.0
var setup_time := 90.0
var run_time := 150.0
var replay_time := 9.0
var score_time := 6.0
var rounds := 2  # default match: each team traps once, ~9 minutes
const SETUP_CHOICES := [60.0, 90.0, 120.0]
const RUN_CHOICES := [100.0, 150.0, 200.0]
const MODIFIERS := ["moon", "ice", "bighead", "blackout", "turbo", "quake", "double"]
const RUSH_TIME := 30.0  # "Mom's coming home!": the last seconds of chores count double
const REVEAL_COOLDOWN := 25.0
const REVEAL_RADIUS := 6.0
var house_rules := true  # random rule each round (from round 2)
var rule_choice := "random"
var mode := "turns"  # turns | chaos
var map := "house"  # house | office | mansion (base of custom maps too)
var custom_items: Array = []  # map editor items: [type, x, z, yaw]
var custom_name := ""
var editor := false
const CHAOS_START_BUDGET := 6
const CHAOS_BUDGET_EVERY := 5.0


## Bigger maps get longer phases.
func time_scale() -> float:
	return 1.3 if map == "mansion" else 1.0


## Chaos is one long round where everybody traps and runs at once.
func chaos_time() -> float:
	return run_time * 1.6 * time_scale()  # random | off | one of MODIFIERS (every round)
const GHOST_DELAY := 20.0  # trappers become poltergeists this long after chores start
const GHOST_COOLDOWN := 12.0

# --- Scoring ---
const BUDGET := 15
const TASKS_PER_ROUND := 3


## Longer chore phases get one more chore so the round doesn't end early.
func tasks_per_round() -> int:
	return TASKS_PER_ROUND + (1 if run_time >= 140.0 else 0) + (1 if run_time >= 190.0 else 0) + (1 if map == "mansion" else 0)


## Rough match length in minutes (intro + setup + chores + replay + score per round).
func match_minutes() -> float:
	if mode == "chaos":
		return (intro_time + chaos_time() + replay_time + score_time) / 60.0
	return rounds * (intro_time + (setup_time + run_time) * time_scale() + replay_time + score_time) / 60.0
const TASK_POINTS := 15
const PRANK_POINTS := 10
const DISARM_POINTS := 10
const ALARM_POINTS := 10
const MESS_DIVISOR := 4.0  # trapper gets mess% / 4 per runner

# --- Network ---
const PORT := 24680
const NET_RATE := 30.0
const INTERP_DELAY := 0.08
const MAX_PLAYERS := 8

const TEAM_COLORS := [Color("ff6b3d"), Color("3da5ff")]
const PLAYER_COLORS := [
	Color("ff5a5a"), Color("ffb02e"), Color("ff6ec7"), Color("c58bff"),
	Color("3dd6c2"), Color("4f8bff"), Color("7ad13d"), Color("ffe14d"),
]

# place: floor | door | container | ceiling | surface | task
# trigger: step | door | open | remote | timed | task | always
const PRANKS := {
	"banana": {"cost": 1, "place": "floor", "trigger": "step", "reveal": true},
	"bucket": {"cost": 2, "place": "door", "trigger": "door", "reveal": true},
	"paint": {"cost": 3, "place": "container", "trigger": "open", "reveal": false},
	"oil": {"cost": 2, "place": "floor", "trigger": "step", "reveal": true},
	"flour": {"cost": 2, "place": "ceiling", "trigger": "remote", "reveal": true},
	"whoopee": {"cost": 1, "place": "floor", "trigger": "step", "reveal": true},
	"glove": {"cost": 3, "place": "container", "trigger": "open", "reveal": false},
	"tape": {"cost": 2, "place": "floor", "trigger": "step", "reveal": true},
	"spring": {"cost": 4, "place": "floor", "trigger": "step", "reveal": true},
	"marbles": {"cost": 3, "place": "floor", "trigger": "step", "reveal": true},
	"confetti": {"cost": 1, "place": "surface", "trigger": "remote", "reveal": true},
	"alarm": {"cost": 1, "place": "surface", "trigger": "timed", "reveal": false},
	"fake_remote": {"cost": 3, "place": "task", "trigger": "task", "reveal": false},
	"vacuum": {"cost": 4, "place": "floor", "trigger": "always", "reveal": true},
	"trampoline": {"cost": 2, "place": "floor", "trigger": "step", "reveal": true},
	"cake": {"cost": 2, "place": "surface", "trigger": "eat", "reveal": true, "bait": true},
}
const PRANK_ORDER := ["banana", "bucket", "paint", "oil", "flour", "whoopee", "glove",
	"tape", "spring", "marbles", "confetti", "alarm", "fake_remote", "vacuum", "trampoline", "cake"]
const CAKE_BONUS := 5  # eating the bait cake still pays the runners a little
const XP_PER_LEVEL := 200
# achievement id -> [counter, needed] (counter "" = one-off). Same ids go to Steamworks > Achievements.
const ACHIEVEMENTS := {
	"FIRST_PRANK": ["", 1], "CHAIN_3": ["", 1], "CHAIN_5": ["", 1], "GHOSTLY": ["", 1], "CAT_HERDER": ["", 1],
	"WINNER": ["", 1], "BOMB_SQUAD": ["disarms", 5], "CHORE_MASTER": ["tasks", 25], "REGULAR": ["matches", 10], "LEVEL_10": ["", 1],
}
signal achievement(id: String)


func unlock_ach(id: String) -> void:
	if not ACHIEVEMENTS.has(id):
		return
	var got: Dictionary = settings["ach"] if settings["ach"] is Dictionary else {}
	if got.has(id):
		return
	got[id] = true
	settings["ach"] = got
	save_settings()
	if has_node("/root/SteamNet"):
		get_node("/root/SteamNet").achieve(id)
	achievement.emit(id)


## Lifetime counters (disarms, chores, matches); unlocks the matching achievement when reached.
func add_count(key: String, n := 1) -> void:
	var c: Dictionary = settings["counts"] if settings["counts"] is Dictionary else {}
	c[key] = int(c.get(key, 0)) + n
	settings["counts"] = c
	save_settings()
	for id in ACHIEVEMENTS:
		if ACHIEVEMENTS[id][0] == key and int(c[key]) >= int(ACHIEVEMENTS[id][1]):
			unlock_ach(id)
	_check_daily()


# ------------------------------------------------------------------ daily challenges

const DAILY_POOL := [["tasks", 3], ["disarms", 2], ["hits", 5], ["chains", 1], ["cats", 1], ["ghosts", 1], ["wins", 1], ["matches", 2]]
const DAILY_XP := 150
signal daily_done(index: int)


## Today's 3 challenges (same for everyone on the same date). Progress counts from the start of the day.
func daily() -> Dictionary:
	var today := Time.get_date_string_from_system()
	var d: Dictionary = settings["daily"] if settings["daily"] is Dictionary else {}
	if str(d.get("date", "")) != today:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(today)
		var idx := range(DAILY_POOL.size())
		for i in range(idx.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = idx[i]
			idx[i] = idx[j]
			idx[j] = tmp
		var counts: Dictionary = settings["counts"] if settings["counts"] is Dictionary else {}
		var base := {}
		for k in DAILY_POOL:
			base[k[0]] = int(counts.get(k[0], 0))
		d = {"date": today, "picks": idx.slice(0, 3), "done": [], "base": base}
		settings["daily"] = d
	return d


func daily_progress(i: int) -> Array:
	var d := daily()
	var k: Array = DAILY_POOL[int(d["picks"][i])]
	var counts: Dictionary = settings["counts"] if settings["counts"] is Dictionary else {}
	return [mini(int(counts.get(k[0], 0)) - int(d["base"].get(k[0], 0)), int(k[1])), int(k[1]), str(k[0])]


func _check_daily() -> void:
	var d := daily()
	for i in 3:
		var p := daily_progress(i)
		if p[0] >= p[1] and not (i in d["done"]):
			d["done"].append(i)
			settings["xp"] = int(settings.get("xp", 0)) + DAILY_XP
			save_settings()
			daily_done.emit(i)


## Level from saved XP (local progress; shortcut: stored in the settings file, move to Steam Stats for anti-cheat).
func level() -> int:
	return 1 + int(settings.get("xp", 0)) / XP_PER_LEVEL


## Match-end reward. Returns {"gained", "level", "leveled", "unlocked": [item ids]}.
func add_match_xp(won: bool, team_points: int, played_rounds: int) -> Dictionary:
	var before := level()
	add_count("matches")
	if won:
		add_count("wins")
		unlock_ach("WINNER")
	var gained := 40 + 15 * played_rounds + (40 if won else 0) + mini(60, team_points / 5)
	settings["xp"] = int(settings.get("xp", 0)) + gained
	save_settings()
	var unlocked := []
	for id in Cosmetics.ITEMS:
		var u := Cosmetics.unlock_of(id)
		if u.begins_with("level:"):
			var n := u.substr(6).to_int()
			if n > before and n <= level():
				unlocked.append(id)
	if level() >= 10:
		unlock_ach("LEVEL_10")
	return {"gained": gained, "level": level(), "leveled": level() > before, "unlocked": unlocked}
const DEMO_PRANKS := ["banana", "bucket", "paint", "spring", "flour"]
var demo_mode := false
var sandbox := false
var tutorial := false

# Task steps: hold = hold E at spot, open = open container, pickup/deliver = carry item.
const TASKS := {
	"remote": [{"type": "hold", "at": "remote_spot", "time": 1.2}],
	"sandwich": [{"type": "open", "at": "fridge"}, {"type": "hold", "at": "counter", "time": 2.0}],
	"shower": [{"type": "hold", "at": "shower", "time": 3.0}],
	"bed": [{"type": "hold", "at": "bed", "time": 2.5}],
	"trash": [{"type": "pickup", "at": "trash_bag"}, {"type": "deliver", "at": "trash_bin"}],
	"cat": [{"type": "open", "at": "cat_cabinet"}, {"type": "hold", "at": "cat_bowl", "time": 1.5}],
	"laundry": [{"type": "pickup", "at": "laundry"}, {"type": "deliver", "at": "clothesline"}],
	"plants": [{"type": "hold", "at": "plant_a", "time": 1.5}, {"type": "hold", "at": "plant_b", "time": 1.5}],
	"copies": [{"type": "hold", "at": "copier", "time": 2.5}],
	"coffee": [{"type": "open", "at": "coffee_cabinet"}, {"type": "hold", "at": "coffee_machine", "time": 2.0}],
	"meeting": [{"type": "hold", "at": "whiteboard", "time": 2.5}],
	"report": [{"type": "pickup", "at": "report"}, {"type": "deliver", "at": "boss_desk"}],
	"fish": [{"type": "open", "at": "fish_food"}, {"type": "hold", "at": "aquarium", "time": 1.5}],
	"dinner": [{"type": "hold", "at": "dining_table", "time": 2.5}],
	"books": [{"type": "open", "at": "bookcase"}, {"type": "hold", "at": "library_shelf", "time": 2.0}],
	"homework": [{"type": "pickup", "at": "homework"}, {"type": "deliver", "at": "teacher_desk"}],
	"lesson": [{"type": "hold", "at": "blackboard", "time": 2.5}],
	"hoops": [{"type": "pickup", "at": "basketball"}, {"type": "deliver", "at": "hoop"}],
	"gym_kit": [{"type": "open", "at": "school_locker"}, {"type": "hold", "at": "gym_mat", "time": 2.0}],
	"cake_cut": [{"type": "hold", "at": "wedding_cake", "time": 2.0}],
	"toast": [{"type": "open", "at": "drinks_cooler"}, {"type": "hold", "at": "head_table", "time": 2.0}],
	"dance": [{"type": "hold", "at": "dance_floor", "time": 3.0}],
	"bouquet": [{"type": "pickup", "at": "bouquet"}, {"type": "deliver", "at": "bride_mirror"}],
	"dj": [{"type": "hold", "at": "dj_booth", "time": 2.0}],
	"pizza": [{"type": "pickup", "at": "pizza"}, {"type": "deliver", "at": "counter"}],  # event only
}
const EVENT_TASKS := ["pizza"]
const POWERUPS := ["umbrella", "coffee"]
# one random perk per player per round (no pick screen, so the game never slows down)
const RUNNER_PERKS := ["nose", "steady", "quick_hands", "sprinter"]
const TRAPPER_PERKS := ["master", "budget", "remote_pro", "haunter"]
const CATCHUP_DIFF := 60
const TWITCH_WINDOW := 25.0  # seconds per viewer vote  # a team this far ahead gets a handicap, the other a boost
const CAT_BONUS := 10

## Physics-time clock of the running match (seconds). Set by World.
var now := 0.0

var settings := {
	"name": "", "lang": "", "master": 0.8, "music": 0.5, "sfx": 0.9,
	"fullscreen": false, "last_ip": "127.0.0.1", "keys": {}, "look": {}, "xp": 0,
	"brightness": 1.0, "contrast": 1.0, "saturation": 1.0, "quality": 2, "twitch": "", "twitch_on": false,
	"ach": {}, "counts": {}, "daily": {}, "tutorial_done": false, "clips": true,
}
const REBINDABLE := ["move_up", "move_down", "move_left", "move_right", "jump", "interact", "dive", "action", "prev_item", "next_item", "cam_next", "reveal", "taunt", "ghost", "trigger_all"]
const SETTINGS_PATH := "user://settings.cfg"


func _ready() -> void:
	_setup_input()
	for b in ["Music", "SFX"]:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, b)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	load_settings()


func enabled_pranks() -> Array:
	return DEMO_PRANKS if demo_mode else PRANK_ORDER


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


func _joy(btn: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = btn
	return e


func _axis(axis: JoyAxis, v: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = v
	return e


func _mouse(btn: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = btn
	return e


func _setup_input() -> void:
	var map := {
		"move_left": [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)],
		"move_right": [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)],
		"move_up": [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)],
		"move_down": [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)],
		"jump": [_key(KEY_SPACE), _joy(JOY_BUTTON_A)],
		"interact": [_key(KEY_E), _joy(JOY_BUTTON_X)],
		"action": [_mouse(MOUSE_BUTTON_LEFT), _key(KEY_F), _joy(JOY_BUTTON_RIGHT_SHOULDER), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)],
		"dive": [_key(KEY_SHIFT), _key(KEY_CTRL), _joy(JOY_BUTTON_B)],
		"next_item": [_key(KEY_R), _mouse(MOUSE_BUTTON_WHEEL_DOWN), _joy(JOY_BUTTON_DPAD_RIGHT)],
		"prev_item": [_key(KEY_Q), _mouse(MOUSE_BUTTON_WHEEL_UP), _joy(JOY_BUTTON_DPAD_LEFT), _joy(JOY_BUTTON_LEFT_SHOULDER)],
		"cam_next": [_key(KEY_TAB), _joy(JOY_BUTTON_Y)],
		"menu": [_key(KEY_ESCAPE), _joy(JOY_BUTTON_START)],
		"screenshot": [_key(KEY_F9)],
		"open_clips": [_key(KEY_F10)],
		"rotate_item": [_key(KEY_X)],
		"taunt": [_key(KEY_V), _joy(JOY_BUTTON_DPAD_DOWN)],
		"zoom": [_key(KEY_Z), _joy(JOY_BUTTON_RIGHT_STICK)],
		"chat": [_key(KEY_ENTER), _key(KEY_KP_ENTER)],
		"quick_1": [_key(KEY_F1)], "quick_2": [_key(KEY_F2)], "quick_3": [_key(KEY_F3)], "quick_4": [_key(KEY_F4)],
		"reveal": [_key(KEY_C), _joy(JOY_BUTTON_LEFT_SHOULDER)],
		"ghost": [_key(KEY_G), _mouse(MOUSE_BUTTON_RIGHT)],
		"trigger_all": [_key(KEY_T), _joy(JOY_BUTTON_DPAD_UP)],
		"rearm": [_key(KEY_BACKSPACE), _joy(JOY_BUTTON_BACK)],
		"clear_all": [_key(KEY_DELETE)],
	}
	for i in range(1, 10):
		map["slot_%d" % i] = [_key(KEY_0 + i)]
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.3)
		for ev in map[action]:
			InputMap.action_add_event(action, ev)


## Replaces the first keyboard key of an action with a custom physical key.
func rebind(action: String, code: int) -> void:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			InputMap.action_erase_event(action, ev)
			break
	var k := InputEventKey.new()
	k.physical_keycode = code as Key
	InputMap.action_add_event(action, k)
	var keys: Dictionary = settings["keys"]
	keys[action] = code


func key_name(action: String) -> String:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return OS.get_keycode_string(ev.physical_keycode)
	return "?"


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		for k in settings:
			settings[k] = cf.get_value("s", k, settings[k])
	var keys = settings["keys"]
	if keys is Dictionary:
		for a in keys:
			if InputMap.has_action(a):
				rebind(a, int(keys[a]))
	else:
		settings["keys"] = {}
	if settings["name"] == "":
		settings["name"] = "Player%d" % (randi() % 900 + 100)
	apply_settings()


func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in settings:
		cf.set_value("s", k, settings[k])
	cf.save(SETTINGS_PATH)
	apply_settings()


signal visuals_changed
const SLIDERS := {"master": [0.0, 1.0], "music": [0.0, 1.0], "sfx": [0.0, 1.0],
	"brightness": [0.5, 1.5], "contrast": [0.6, 1.4], "saturation": [0.0, 1.6], "quality": [0.0, 2.0]}


## The shared look: sky light, soft AO, gentle glow, AgX tonemap. Effects the renderer can't do are ignored.
func make_env() -> Environment:
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("5fa8ff")
	sm.sky_horizon_color = Color("cfe9ff")
	sm.ground_bottom_color = Color("6d8f5a")
	sm.ground_horizon_color = Color("cfe9ff")
	sky.sky_material = sm
	e.sky = sky
	e.background_mode = Environment.BG_SKY
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 1.0
	e.ambient_light_sky_contribution = 0.6
	e.ambient_light_color = Color("fff3e0")
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.05
	e.tonemap_white = 5.0
	apply_env(e)
	return e


## Shared sun: warm, soft shadows.
func make_sun() -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_color = Color("fff1dc")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.shadow_blur = 1.8
	sun.shadow_opacity = 0.85
	sun.directional_shadow_max_distance = 45.0
	return sun


## Applies the player's brightness / contrast / saturation and graphics quality to an Environment.
func apply_env(e: Environment) -> void:
	var q := int(settings.get("quality", 2))
	e.ssao_enabled = q >= 1
	e.ssao_radius = 1.0
	e.ssao_intensity = 1.1
	e.ssil_enabled = q >= 2
	e.glow_enabled = q >= 1
	e.glow_intensity = 0.35
	e.glow_bloom = 0.05
	e.adjustment_enabled = true
	e.adjustment_brightness = 1.0 * float(settings["brightness"])
	e.adjustment_contrast = 1.05 * float(settings["contrast"])
	e.adjustment_saturation = 1.25 * float(settings["saturation"])


func apply_settings() -> void:
	visuals_changed.emit()
	var buses := {"Master": settings["master"], "Music": settings["music"], "SFX": settings["sfx"]}
	for b in buses:
		var idx := AudioServer.get_bus_index(b)
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(float(buses[b]), 0.0001)))
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if settings["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
