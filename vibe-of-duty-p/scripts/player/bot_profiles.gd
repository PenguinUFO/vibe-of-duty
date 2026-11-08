class_name BotProfiles
## Archetype bots for balance tests (Docs/BOTS.md; PlayerBots._bot_arch_cmd): a bot = a play style x a skill level.
## The styles are the players of the 2026-11-02 playtest (Docs/balance/playtest_2026-11-02.md, "Технические
## архетипы"): how far they fight, how they move, aim and pull the trigger. The skills are how well the hands do it:
## noticing, turning, holding the aim, pulling the recoil down.
## Launch: --bot-style=<style> --bot-skill=<skill> (+ --build=kit.<id> for the weapon).

## Play styles.
##   keep        m: the distance it fights at (closes in when farther, never backs off unless `back_off`)
##   back_off    m: backs away when the enemy is nearer than this (0: never)
##   ads_from    m: aims down the sights from this distance on (nearer: from the hip)
##   strafe      0..1: sideways movement while fighting (0: stands)
##   strafe_time s: one strafe direction (the sign flips, +-40 %)
##   stand_fire  stops moving while the trigger is down
##   sprint      sprints to its distance when it is more than 6 m off and not shooting
##   jump        jumps a second in a fight (0: never)
##   crouch      share of a fight spent crouched (in stretches of ~1.5 s)
##   gate        fires when the aim is within this many body widths of the target (big: sprays at anything near)
##   burst       shots in a burst, then lets go for `pause` s (0: holds the trigger)
##   pause       s between bursts
##   melee       punches within reach
const STYLES := {
	# Тапок: close, from the hip, picks the shots, the best K/D every day.
	"tapok": {"name": "Ближний бой с точностью", "keep": 7.0, "back_off": 0.0, "ads_from": 9.0, "strafe": 0.7,
			"strafe_time": 0.9, "stand_fire": false, "sprint": true, "jump": 0.0, "crouch": 0.1, "gate": 1.0,
			"burst": 0, "pause": 0.0, "melee": true},
	# Степашка: rushes, never stops, sprays, crouches in fights, the lowest accuracy.
	"stepashka": {"name": "Агрессия без точности", "keep": 3.0, "back_off": 0.0, "ads_from": 7.0, "strafe": 1.0,
			"strafe_time": 0.6, "stand_fire": false, "sprint": true, "jump": 0.35, "crouch": 0.28, "gate": 4.0,
			"burst": 0, "pause": 0.0, "melee": true},
	# Ларри: stands at 13 m, in the sights, holds the trigger down.
	"larry": {"name": "Огонь с места", "keep": 13.0, "back_off": 8.0, "ads_from": 4.0, "strafe": 0.3,
			"strafe_time": 1.5, "stand_fire": true, "sprint": false, "jump": 0.0, "crouch": 0.0, "gate": 3.0,
			"burst": 0, "pause": 0.0, "melee": false},
	# Владелец: 6-10 m, one good shot at a time, finishes with the stock after a miss.
	"owner": {"name": "Сильный одиночный выстрел", "keep": 8.0, "back_off": 0.0, "ads_from": 3.0, "strafe": 0.5,
			"strafe_time": 1.2, "stand_fire": true, "sprint": false, "jump": 0.0, "crouch": 0.0, "gate": 0.6,
			"burst": 1, "pause": 0.25, "melee": true},
	# Рулька: the farthest, in the sights, short bursts, never punches.
	"rulka": {"name": "Дисциплина на дистанции", "keep": 15.0, "back_off": 11.0, "ads_from": 0.0, "strafe": 0.4,
			"strafe_time": 1.3, "stand_fire": false, "sprint": false, "jump": 0.0, "crouch": 0.0, "gate": 0.8,
			"burst": 4, "pause": 0.3, "melee": false},
}

## Skill levels (Claude's, not measured on people; calibrate on the human playtest accuracy, 15-25 %).
##   react      s from an enemy coming into view to the first reaction (the aim starts to move)
##   turn       deg/s the aim turns at most
##   noise      deg: the aim's wander (a slow random walk round the point it wants, this standard deviation)
##   lead       0..1: share of the target's motion it leads (the rest it chases, `react` s late)
##   recoil     0..1: share of the recoil kick it pulls down
##   head       0..1: share of the time it aims at the head (else the chest)
const SKILLS := {
	"novice": {"name": "Новичок", "react": 0.45, "turn": 220.0, "noise": 4.5, "lead": 0.0, "recoil": 0.3, "head": 0.05},
	"average": {"name": "Средний", "react": 0.3, "turn": 360.0, "noise": 2.8, "lead": 0.4, "recoil": 0.55, "head": 0.15},
	"good": {"name": "Опытный", "react": 0.22, "turn": 520.0, "noise": 1.9, "lead": 0.75, "recoil": 0.75, "head": 0.3},
	"pro": {"name": "Профи", "react": 0.16, "turn": 800.0, "noise": 0.9, "lead": 1.0, "recoil": 0.9, "head": 0.5},
}


static func style(id: String) -> Dictionary:
	return STYLES.get(id, STYLES["tapok"])


static func skill(id: String) -> Dictionary:
	return SKILLS.get(id, SKILLS["average"])
