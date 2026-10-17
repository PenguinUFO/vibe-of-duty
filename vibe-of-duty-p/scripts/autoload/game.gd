extends Node
## Match state (Free-for-All). Stub: server-authoritative logic is added in later stages.

enum State { MENU, LOBBY, PLAYING, ENDED }

signal state_changed(new_state: State)
signal score_changed(peer_id: int)

const SCORE_LIMIT := 20
const MATCH_TIME := 600.0  # seconds

var state: State = State.MENU
var scores: Dictionary = {}  # peer_id -> {"kills": int, "deaths": int}


func set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(state)


func reset_scores() -> void:
	scores.clear()


func ensure_player(peer_id: int) -> void:
	if not scores.has(peer_id):
		scores[peer_id] = {"kills": 0, "deaths": 0}


func add_kill(killer_id: int, victim_id: int) -> void:
	ensure_player(killer_id)
	ensure_player(victim_id)
	if killer_id != victim_id:
		scores[killer_id]["kills"] += 1
	scores[victim_id]["deaths"] += 1
	score_changed.emit(killer_id)
	score_changed.emit(victim_id)
