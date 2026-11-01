extends Node
var t := 0.0
func _ready():
	Twitch.status_changed.connect(func(s): print("TW ", s))
	Twitch.start("twitchdev")
func _process(d):
	t += d
	if t > 12.0:
		print("TW connected=", Twitch.connected)
		get_tree().quit()
