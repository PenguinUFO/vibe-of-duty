#!/bin/bash
# Automated bot tests on Windows (Git Bash). Prints only the [SUMMARY] lines and script errors.
#   bash tools/test.sh [arena|course|range|train|melee|build|all]     (default: all; run from anywhere)
# Godot: $GODOT, or Godot_v4.7.2.exe next to the repository (C:\Users\mestr\Documents\Godot).
# The tests run on a copy of the project in %TEMP%\vod-test (Godot rewrites .godot/ and must not touch the real folder),
# with APPDATA pointed there too, so user:// (settings, builds, stats) of the real profile stays untouched.
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"   # vibe-of-duty-p
G="${GODOT:-$HERE/../../Godot_v4.7.2.exe}"
[ -f "$G" ] || { echo "Godot not found: $G (set GODOT)"; exit 1; }
W="$(cygpath -u "${TEMP:-/tmp}")/vod-test"; P="$W/project"; O="$W/logs"
mkdir -p "$P" "$O" "$W/appdata"
robocopy "$(cygpath -w "$HERE")" "$(cygpath -w "$P")" //MIR //XD test-logs //NFL //NDL //NJH //NJS //NP > /dev/null
[ $? -lt 8 ] || { echo "robocopy failed"; exit 1; }
export APPDATA="$(cygpath -w "$W/appdata")"
PW="$(cygpath -w "$P")"
timeout 170 "$G" --headless --path "$PW" --import > /dev/null 2>&1
rm -f "$O"/*.log
R="timeout 90 $G --headless --path $PW --"
run() {
	case $1 in
	arena)  # server + 2 aim bots, one with 40 ms lag, fake prediction errors and 10% lost command packets
		$R --server --map=arena --summary=40 > "$O/arena_srv.log" 2>&1 &
		sleep 3
		$R --join=127.0.0.1 --bot-aim --name=A --summary=37 > "$O/arena_c1.log" 2>&1 &
		$R --join=127.0.0.1 --bot-aim --name=B --lag=40 --perturb --loss=10 --summary=37 > "$O/arena_c2.log" 2>&1 &
		wait;;
	course) $R --training=course --bot-course --summary=68 > "$O/course.log" 2>&1;;  # ~33 s a lap
	range)  $R --training=range --bot-targets --summary=25 > "$O/range.log" 2>&1;;
	train)  # the train map: server + an oinking bot + an aim bot
		$R --server --map=train --summary=20 > "$O/train_srv.log" 2>&1 &
		sleep 3
		$R --join=127.0.0.1 --bot-oink --name=O1 --summary=17 > "$O/train_c1.log" 2>&1 &
		$R --join=127.0.0.1 --bot-aim --name=O2 --summary=17 > "$O/train_c2.log" 2>&1 &
		wait;;
	melee)  # arena: two bots run at each other and punch
		$R --server --map=arena --summary=30 > "$O/melee_srv.log" 2>&1 &
		sleep 3
		$R --join=127.0.0.1 --bot-melee --name=M1 --summary=27 > "$O/melee_c1.log" 2>&1 &
		$R --join=127.0.0.1 --bot-melee --name=M2 --summary=27 > "$O/melee_c2.log" 2>&1 &
		wait;;
	build)  # arena: aim bots with kits - B1 changed with the "Инженер" (+ an organ the match leaves out), B2 a kit as is
		$R --server --map=arena --summary=30 > "$O/build_srv.log" 2>&1 &
		sleep 3
		$R --join=127.0.0.1 --bot-aim --name=B1 --build=kit.ak_kobra,engineer,ak.suppressor.on,lead_heart --summary=27 > "$O/build_c1.log" 2>&1 &
		$R --join=127.0.0.1 --bot-aim --name=B2 --build=kit.acr_rat --summary=27 > "$O/build_c2.log" 2>&1 &
		wait;;
	*) echo "unknown test: $1"; return;;
	esac
	echo "== $1"
	grep -hE 'SCRIPT ERROR|ERROR:|Parse Error' "$O/$1"*.log | grep -v 'at exit' | sort | uniq -c | head
	grep -h '^\[SUMMARY' "$O/$1"*.log
}
if [ "${1:-all}" = all ]; then for t in arena course range train melee build; do run $t; done; else run "$1"; fi
echo "logs: $(cygpath -w "$O")"
