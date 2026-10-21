#!/bin/bash
# Automated bot tests in Claude's Linux sandbox (or any Linux box). Prints only the [SUMMARY] lines and script errors.
#   bash tools/test.sh [arena|course|range|train|all]     (default: all; run from anywhere)
# Godot: $GODOT, or the Linux build unpacked once from ../Builds/godot-linux/godot.zip.part* into ~/godot-linux.
# The tests run on a copy of the project in ~/godot-work (Godot rewrites .godot/ and must not touch the real folder).
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"   # vibe-of-duty-p
G="${GODOT:-$HOME/godot-linux/Godot_v4.7.2-stable_linux.x86_64}"
if [ ! -x "$G" ]; then
	mkdir -p "$HOME/godot-linux"
	cat "$HERE"/../Builds/godot-linux/godot.zip.part* > "$HOME/godot-linux/godot.zip" || exit 1
	python3 -c "import zipfile,sys;zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$HOME/godot-linux/godot.zip" "$HOME/godot-linux"
	rm "$HOME/godot-linux/godot.zip"; chmod +x "$G"
fi
P="$HOME/godot-work"; O="$P/test-logs"
mkdir -p "$P"
rsync -a --delete --exclude test-logs "$HERE/" "$P/"
timeout 170 "$G" --headless --path "$P" --import > /dev/null 2>&1
mkdir -p "$O"; rm -f "$O"/*.log
R="timeout 90 $G --headless --path $P --"
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
	esac
	echo "== $1"
	grep -hE 'SCRIPT ERROR|ERROR:|Parse Error' "$O/$1"*.log | grep -v 'at exit' | sort | uniq -c | head
	grep -h '^\[SUMMARY' "$O/$1"*.log
}
if [ "${1:-all}" = all ]; then for t in arena course range train; do run $t; done; else run "$1"; fi
echo "logs: $O"
