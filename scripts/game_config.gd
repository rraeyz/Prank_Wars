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
var map := "house"  # house | office
const CHAOS_START_BUDGET := 6
const CHAOS_BUDGET_EVERY := 5.0


## Chaos is one long round where everybody traps and runs at once.
func chaos_time() -> float:
	return run_time * 1.6  # random | off | one of MODIFIERS (every round)
const GHOST_DELAY := 20.0  # trappers become poltergeists this long after chores start
const GHOST_COOLDOWN := 12.0

# --- Scoring ---
const BUDGET := 15
const TASKS_PER_ROUND := 3


## Longer chore phases get one more chore so the round doesn't end early.
func tasks_per_round() -> int:
	return TASKS_PER_ROUND + (1 if run_time >= 140.0 else 0) + (1 if run_time >= 190.0 else 0)


## Rough match length in minutes (intro + setup + chores + replay + score per round).
func match_minutes() -> float:
	if mode == "chaos":
		return (intro_time + chaos_time() + replay_time + score_time) / 60.0
	return rounds * (intro_time + setup_time + run_time + replay_time + score_time) / 60.0
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
const HATS := ["none", "party", "crown", "cap", "chef", "propeller", "horns"]
const DEMO_PRANKS := ["banana", "bucket", "paint", "spring", "flour"]
var demo_mode := false
var sandbox := false

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
	"pizza": [{"type": "pickup", "at": "pizza"}, {"type": "deliver", "at": "counter"}],  # event only
}
const EVENT_TASKS := ["pizza"]
const POWERUPS := ["umbrella", "coffee"]
const CAT_BONUS := 10

## Physics-time clock of the running match (seconds). Set by World.
var now := 0.0

var settings := {
	"name": "", "lang": "", "master": 0.8, "music": 0.5, "sfx": 0.9,
	"fullscreen": false, "last_ip": "127.0.0.1", "keys": {}, "hat": 1,
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
		"taunt": [_key(KEY_V), _joy(JOY_BUTTON_DPAD_DOWN)],
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


func apply_settings() -> void:
	var buses := {"Master": settings["master"], "Music": settings["music"], "SFX": settings["sfx"]}
	for b in buses:
		var idx := AudioServer.get_bus_index(b)
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(float(buses[b]), 0.0001)))
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if settings["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
