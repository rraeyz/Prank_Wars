class_name Timeline
extends RefCounted
## Buffer of host snapshots. Used for client interpolation AND for replays (host records its own).
## Frame data layout: per entity STRIDE floats: id, px, py, pz, qx, qy, qz, qw, state.
## Entities absent from a frame keep their last known value (host skips resting ones).

const STRIDE := 9
const MAX_FRAMES := 20 * 60 * 4

var frames: Array = []  # [{"t": float, "d": PackedFloat32Array}]
var known := {}  # id -> PackedFloat32Array(8)
var cursor := -1
var events: Array = []  # [{"t", "kind", "args"}] effects, re-fired during replays


func clear() -> void:
	frames.clear()
	known.clear()
	events.clear()
	cursor = -1


func push(t: float, d: PackedFloat32Array) -> void:
	if frames.size() > 0 and t <= float(frames[-1]["t"]):
		return
	frames.append({"t": t, "d": d})
	if frames.size() > MAX_FRAMES:
		frames.pop_front()
		cursor = maxi(cursor - 1, -1)


func latest_t() -> float:
	return float(frames[-1]["t"]) if frames.size() > 0 else 0.0


func first_t() -> float:
	return float(frames[0]["t"]) if frames.size() > 0 else 0.0


func rewind() -> void:
	cursor = -1
	known.clear()


func _absorb(d: PackedFloat32Array) -> void:
	var i := 0
	while i + STRIDE <= d.size():
		known[int(d[i])] = d.slice(i + 1, i + STRIDE)
		i += STRIDE


## Returns id -> [Vector3 pos, Quaternion rot, float state] interpolated at time rt.
func sample(rt: float) -> Dictionary:
	if cursor >= 0 and cursor < frames.size() and rt < float(frames[cursor]["t"]):
		rewind()
	while cursor + 1 < frames.size() and float(frames[cursor + 1]["t"]) <= rt:
		cursor += 1
		_absorb(frames[cursor]["d"])
	var out := {}
	for id in known:
		var k: PackedFloat32Array = known[id]
		out[id] = [Vector3(k[0], k[1], k[2]), Quaternion(k[3], k[4], k[5], k[6]).normalized(), k[7]]
	if cursor >= 0 and cursor + 1 < frames.size():
		var ta: float = frames[cursor]["t"]
		var tb: float = frames[cursor + 1]["t"]
		var a := clampf((rt - ta) / maxf(tb - ta, 0.0001), 0.0, 1.0)
		var d: PackedFloat32Array = frames[cursor + 1]["d"]
		var i := 0
		while i + STRIDE <= d.size():
			var id := int(d[i])
			if known.has(id):
				var k: PackedFloat32Array = known[id]
				var p0 := Vector3(k[0], k[1], k[2])
				var q0 := Quaternion(k[3], k[4], k[5], k[6]).normalized()
				var p1 := Vector3(d[i + 1], d[i + 2], d[i + 3])
				var q1 := Quaternion(d[i + 4], d[i + 5], d[i + 6], d[i + 7]).normalized()
				# teleports (respawn) should not be smeared
				var p := p1 if p0.distance_to(p1) > maxf(4.0, 40.0 * (tb - ta)) else p0.lerp(p1, a)
				out[id] = [p, q0.slerp(q1, a), k[7] if a < 0.5 else d[i + 8]]
			i += STRIDE
	return out


func add_event(t: float, kind: String, args: Array) -> void:
	events.append({"t": t, "kind": kind, "args": args})


func events_between(t0: float, t1: float) -> Array:
	var r := []
	for e in events:
		if e["t"] > t0 and e["t"] <= t1:
			r.append(e)
	return r
