class_name Timeline
extends RefCounted
## Buffer of host snapshots. Used for client interpolation AND for replays (host records its own).
## Frame data layout: per entity STRIDE floats: id, px, py, pz, qx, qy, qz, qw, state.
## Entities absent from a frame keep their last known value (host skips resting ones).

const STRIDE := 9
const MAX_FRAMES := 30 * 60 * 4  # 4 min at 30 Hz: longer than the longest chore phase (200 s)

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


## Stateless sample of one entity (does not move the shared cursor). Used for the local bean,
## which is shown with less delay than everything else.
func sample_one(id: int, rt: float) -> Array:
	var n := frames.size()
	var a = null
	var ta := 0.0
	var b = null
	var tb := 0.0
	var i := n - 1
	var steps := 0
	while i >= 0 and steps < 90:
		var f: Dictionary = frames[i]
		var v = _find(f["d"], id)
		if v != null:
			if float(f["t"]) <= rt:
				a = v
				ta = f["t"]
				break
			b = v
			tb = f["t"]
		i -= 1
		steps += 1
	if a == null:
		return [] if b == null else [Vector3(b[0], b[1], b[2]), Quaternion(b[3], b[4], b[5], b[6]).normalized(), b[7]]
	if b == null:
		return [Vector3(a[0], a[1], a[2]), Quaternion(a[3], a[4], a[5], a[6]).normalized(), a[7]]
	var k := clampf((rt - ta) / maxf(tb - ta, 0.0001), 0.0, 1.0)
	var pa := Vector3(a[0], a[1], a[2])
	var pb := Vector3(b[0], b[1], b[2])
	var qa := Quaternion(a[3], a[4], a[5], a[6]).normalized()
	var qb := Quaternion(b[3], b[4], b[5], b[6]).normalized()
	return [pa.lerp(pb, k), qa.slerp(qb, k), a[7] if k < 0.5 else b[7]]


func _find(d: PackedFloat32Array, id: int):
	var i := 0
	while i + STRIDE <= d.size():
		if int(d[i]) == id:
			return d.slice(i + 1, i + STRIDE)
		i += STRIDE
	return null


func add_event(t: float, kind: String, args: Array) -> void:
	events.append({"t": t, "kind": kind, "args": args})


func events_between(t0: float, t1: float) -> Array:
	var r := []
	for e in events:
		if e["t"] > t0 and e["t"] <= t1:
			r.append(e)
	return r
