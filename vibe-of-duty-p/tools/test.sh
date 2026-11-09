#!/bin/bash
# Automated bot tests on Windows (Git Bash). Prints only the [SUMMARY] lines and script errors.
#   bash tools/test.sh [arena|course|range|train|melee|build|moves|grenade|akimbo|smg|val|striker|random|hardcore|all]     (default: all; run from anywhere)
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
R="timeout 90 $G --headless --path $PW -- ${VOD_PORT:+--port=$VOD_PORT}"  # VOD_PORT: tests next to another run
run() {
	case $1 in
	arena)  # server + 2 aim bots, one with 40 ms lag, fake prediction errors and 10% lost command packets
		$R --server --map=arena --summary=40 --stats > "$O/arena_srv.log" 2>&1 &
		sleep 3
		$R --join=127.0.0.1 --bot-aim --name=A --summary=37 > "$O/arena_c1.log" 2>&1 &
		$R --join=127.0.0.1 --bot-aim --name=B --lag=40 --perturb --loss=10 --summary=37 > "$O/arena_c2.log" 2>&1 &
		wait;;
	course) $R --training=course --bot-course --summary=68 > "$O/course.log" 2>&1;;  # ~33 s a lap
	range)  $R --training=range --bot-targets --summary=25 > "$O/range.log" 2>&1;;
	train)  # the train map: server + an oinking bot + an aim bot
		$R --server --map=train --summary=20 --stats > "$O/train_srv.log" 2>&1 &
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
	build)  # arena: aim bots with kits - B1 with a module changed, B2 a kit as is
		$R --server --map=arena --summary=30 --stats > "$O/build_srv.log" 2>&1 &
		sleep 3
		$R --join=127.0.0.1 --bot-aim --name=B1 --build=kit.ak,ak.suppressor.on --summary=27 > "$O/build_c1.log" 2>&1 &
		$R --join=127.0.0.1 --bot-aim --name=B2 --build=kit.acr --summary=27 > "$O/build_c2.log" 2>&1 &
		wait;;
	moves)  # station: running bots jump and slide, bunny hopping (life.jumps, life.moves in the stats)
		$R --server --map=station --summary=30 --stats > "$O/moves_srv.log" 2>&1 &
		sleep 3
		$R --join=127.0.0.1 --bot-run=0 --name=R1 --build=kit.ak --summary=27 > "$O/moves_c1.log" 2>&1 &
		$R --join=127.0.0.1 --bot-run=180 --name=R2 --build=kit.p90 --summary=27 > "$O/moves_c2.log" 2>&1 &
		wait;;
	grenade)  # arena: aim bots - each throws its one grenade a life at mid range (every bot does, in every test)
		$R --server --map=arena --summary=30 --stats > "$O/grenade_srv.log" 2>&1 &
		sleep 3
		$R --join=127.0.0.1 --bot-aim --name=G1 --build=kit.ak --summary=27 > "$O/grenade_c1.log" 2>&1 &
		$R --join=127.0.0.1 --bot-aim --name=G2 --build=kit.p90 --lag=40 --summary=27 > "$O/grenade_c2.log" 2>&1 &
		wait;;
	akimbo)  # arena: the Хрюгер kit (a Luger in each hand) - K1 as it is (the snail), K2 with the stock magazine; the left
		# gun is thrown away empty, a new life brings it back
		$R --server --map=arena --stats --summary=40 > "$O/akimbo_srv.log" 2>&1 &
		sleep 3
		$R --join=127.0.0.1 --bot-aim --name=K1 --build=kit.khruger --summary=37 > "$O/akimbo_c1.log" 2>&1 &
		$R --join=127.0.0.1 --bot-aim --name=K2 --build=kit.khruger,luger.mag.8 --lag=40 --summary=37 > "$O/akimbo_c2.log" 2>&1 &
		wait;;
	val)  # arena: the АС ВАЛ - V1 the kit; V2 the short barrel, the wooden stock, the PO, the 10 (a shot per press)
		$R --server --map=arena --summary=40 > "$O/val_srv.log" 2>&1 &
		sleep 3
		$R --join=127.0.0.1 --bot-aim --name=V1 --build=kit.val --summary=37 > "$O/val_c1.log" 2>&1 &
		$R --join=127.0.0.1 --bot-aim --name=V2 --build=kit.val,val.barrel.short,val.stock.wood,val.sight.po,val.mag.10 --lag=40 --summary=37 > "$O/val_c2.log" 2>&1 &
		wait;;
	striker)  # arena: the Armsel Striker - T1 the kit; T2 the Bulldog akimbo, T3 the folded stock
		$R --server --map=arena --summary=40 > "$O/striker_srv.log" 2>&1 &
		sleep 3
		$R --join=127.0.0.1 --bot-aim --name=T1 --build=kit.striker --summary=37 > "$O/striker_c1.log" 2>&1 &
		$R --join=127.0.0.1 --bot-aim --name=T2 --build=kit.striker,striker.akimbo.on --lag=40 --summary=37 > "$O/striker_c2.log" 2>&1 &
		$R --join=127.0.0.1 --bot-aim --name=T3 --build=kit.striker,striker.stock.folded --summary=37 > "$O/striker_c3.log" 2>&1 &
		wait;;
	smg)  # arena: akimbo SMGs - S1 the MP7 (the can stays, the ACOG must go, the stock folds), S2 the PH IDW
		$R --server --map=arena --summary=40 > "$O/smg_srv.log" 2>&1 &
		sleep 3
		$R --join=127.0.0.1 --bot-aim --name=S1 --build=kit.mp7,mp7.akimbo.on,mp7.sight.acog --summary=37 > "$O/smg_c1.log" 2>&1 &
		$R --join=127.0.0.1 --bot-aim --name=S2 --build=kit.pdw,pdw.akimbo.on --lag=40 --summary=37 > "$O/smg_c2.log" 2>&1 &
		wait;;
	random)  # arena: "Бойня рандом" - a random kit with its own modules each life (RandomWeapons)
		$R --server --map=arena --random-weapons --stats --summary=40 > "$O/random_srv.log" 2>&1 &
		sleep 3
		$R --join=127.0.0.1 --bot-aim --name=R1 --summary=37 > "$O/random_c1.log" 2>&1 &
		$R --join=127.0.0.1 --bot-aim --name=R2 --lag=40 --summary=37 > "$O/random_c2.log" 2>&1 &
		wait;;
	hardcore)  # arena: "Хардкор" - everybody 100 HP (kills in the stats: k_max 100)
		$R --server --map=arena --hardcore --stats --summary=40 > "$O/hardcore_srv.log" 2>&1 &
		sleep 3
		$R --join=127.0.0.1 --bot-aim --name=H1 --hardcore --summary=37 > "$O/hardcore_c1.log" 2>&1 &
		$R --join=127.0.0.1 --bot-aim --name=H2 --hardcore --build=kit.ak --lag=40 --summary=37 > "$O/hardcore_c2.log" 2>&1 &
		wait;;
	*) echo "unknown test: $1"; return;;
	esac
	echo "== $1"
	grep -hE 'SCRIPT ERROR|ERROR:|Parse Error' "$O/$1"*.log | grep -v 'at exit' | sort | uniq -c | head
	grep -h '^\[SUMMARY' "$O/$1"*.log
}
if [ "${1:-all}" = all ]; then for t in arena course range train melee build moves grenade akimbo smg val striker random hardcore; do run $t; done; else run "$1"; fi
echo "logs: $(cygpath -w "$O")"
