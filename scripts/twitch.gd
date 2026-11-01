extends Node
## Twitch mode (autoload "Twitch"): reads the streamer's chat anonymously (no login, no server) and
## counts viewer votes like "!banana". The host's World asks for the winner every few seconds.

signal status_changed(text: String)

const URL := "wss://irc-ws.chat.twitch.tv:443"
const COMMANDS := {
	"!muz": "banana", "!banana": "banana", "!un": "flour", "!flour": "flour",
	"!konfeti": "confetti", "!confetti": "confetti", "!deprem": "quake", "!quake": "quake",
	"!kedi": "cat", "!cat": "cat", "!osuruk": "fart", "!fart": "fart",
}

var channel := ""
var connected := false
var votes := {}  # effect -> count
var _voters := {}  # user -> true (one vote per viewer per window)
var _ws: WebSocketPeer
var _logged_in := false


func active() -> bool:
	return connected and channel != ""


## Twitch channel names: 4-25 chars of a-z, 0-9, _ .
static func clean_channel(ch: String) -> String:
	var out := ""
	for c in ch.strip_edges().to_lower().trim_prefix("#"):
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_":
			out += c
	return out.substr(0, 25)


func start(ch: String) -> void:
	stop()
	channel = clean_channel(ch)
	if channel.length() < 3:
		return
	_ws = WebSocketPeer.new()
	if _ws.connect_to_url(URL) != OK:
		status_changed.emit(I18n.t("twitch_fail"))
		_ws = null


func stop() -> void:
	if _ws:
		_ws.close()
	_ws = null
	connected = false
	_logged_in = false
	votes.clear()
	_voters.clear()


func _process(_d: float) -> void:
	if _ws == null:
		return
	_ws.poll()
	match _ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _logged_in:
				_logged_in = true
				_ws.send_text("PASS SCHMOOPIIE")
				_ws.send_text("NICK justinfan%d" % randi_range(10000, 99999))
				_ws.send_text("JOIN #" + channel)
			while _ws.get_available_packet_count() > 0:
				for line in _ws.get_packet().get_string_from_utf8().split("\r\n", false):
					_on_line(line)
		WebSocketPeer.STATE_CLOSED:
			if connected:
				status_changed.emit(I18n.t("twitch_lost"))
			connected = false
			_ws = null


func _on_line(line: String) -> void:
	if line.begins_with("PING"):
		_ws.send_text("PONG :tmi.twitch.tv")
		return
	if " JOIN #" in line and not connected:
		connected = true
		status_changed.emit(I18n.t("twitch_ok", [channel]))
		return
	var msg := parse_line(line)
	if not msg.is_empty():
		vote(msg[0], msg[1])


## ":user!user@user.tmi.twitch.tv PRIVMSG #chan :text" -> [user, text]; anything else -> [].
static func parse_line(line: String) -> Array:
	if not line.begins_with(":") or not " PRIVMSG #" in line:
		return []
	var bang := line.find("!")
	var text_at := line.find(" :", 1)
	if bang < 2 or text_at < 0:
		return []
	return [line.substr(1, bang - 1).substr(0, 25), line.substr(text_at + 2).substr(0, 200)]


## One vote per viewer per window; only known commands count.
func vote(user: String, text: String) -> void:
	var cmd := text.strip_edges().to_lower().split(" ", false)
	if cmd.is_empty() or not COMMANDS.has(cmd[0]) or _voters.has(user):
		return
	_voters[user] = true
	var eff: String = COMMANDS[cmd[0]]
	votes[eff] = int(votes.get(eff, 0)) + 1


## Winner of this voting window ({} if nobody voted) and start a new window.
func take_winner() -> Dictionary:
	var best := ""
	var total := 0
	for e in votes:
		total += int(votes[e])
		if best == "" or int(votes[e]) > int(votes[best]):
			best = e
	var out := {} if best == "" else {"effect": best, "votes": int(votes[best]), "total": total}
	votes.clear()
	_voters.clear()
	return out
