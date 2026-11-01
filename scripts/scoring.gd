class_name Scoring
extends RefCounted
## Pure scoring logic (no nodes) so it can be unit-tested.
## Chain rule: a chain of n links is worth PRANK_POINTS * 2^(n-1) in total (10, 20, 40, 80...).

var totals := [0, 0]
var round_pts := [0, 0]
var chains := {}  # id -> {"team", "links": [{"prank","victim","t"}], "points"}
var _next_chain := 1
var mult := 1  # "double points" rule and the final rush multiply prank, chore and disarm points
var history := []  # [{t, team, pts, reason}]


static func chain_value(links: int) -> int:
	if links <= 0:
		return 0
	return Config.PRANK_POINTS * int(pow(2.0, links - 1))


func start_round() -> void:
	round_pts = [0, 0]
	chains.clear()
	history.clear()


func _add(team: int, pts: int, reason: String, t: float) -> void:
	totals[team] += pts
	round_pts[team] += pts
	history.append({"t": t, "team": team, "pts": pts, "reason": reason})


## Registers a prank hit. Pass chain_id <= 0 to start a new chain.
## Returns {"chain": id, "links": n, "delta": points just earned}.
func prank_hit(chain_id: int, trapper_team: int, prank: String, victim: String, t: float) -> Dictionary:
	if chain_id <= 0 or not chains.has(chain_id) or chains[chain_id]["team"] != trapper_team:
		chain_id = _next_chain
		_next_chain += 1
		chains[chain_id] = {"team": trapper_team, "links": [], "points": 0}
	var c: Dictionary = chains[chain_id]
	c["links"].append({"prank": prank, "victim": victim, "t": t})
	var n: int = c["links"].size()
	var newv := chain_value(n)
	var delta: int = (newv - int(c["points"])) * mult
	c["points"] = newv
	_add(trapper_team, delta, "prank:" + prank, t)
	return {"chain": chain_id, "links": n, "delta": delta}


func task_done(runner_team: int, task: String, t: float) -> int:
	_add(runner_team, Config.TASK_POINTS * mult, "task:" + task, t)
	return Config.TASK_POINTS * mult


func disarmed(runner_team: int, prank: String, t: float) -> int:
	_add(runner_team, Config.DISARM_POINTS * mult, "disarm:" + prank, t)
	return Config.DISARM_POINTS * mult


func bonus(team: int, pts: int, reason: String, t: float) -> void:
	_add(team, pts, reason, t)


## mess values are 0..100 per runner. Returns points given to the trapper team.
func mess_points(trapper_team: int, mess: Array, t: float) -> int:
	var total := 0.0
	for m in mess:
		total += clampf(float(m), 0.0, 100.0) / Config.MESS_DIVISOR
	var pts := int(round(total))
	if pts > 0:
		_add(trapper_team, pts, "mess", t)
	return pts


## Best chain of the round: most links, then most points, then earliest.
func best_chain() -> Dictionary:
	var best := {}
	for id in chains:
		var c: Dictionary = chains[id]
		var n: int = c["links"].size()
		if best.is_empty() or n > best["links"].size() or (n == best["links"].size() and c["points"] > best["points"]):
			best = c.duplicate()
			best["id"] = id
	if best.is_empty():
		return best
	best["t0"] = best["links"][0]["t"]
	best["t1"] = best["links"][-1]["t"]
	return best


func winner() -> int:
	if totals[0] == totals[1]:
		return -1
	return 0 if totals[0] > totals[1] else 1
