#!/bin/bash
# Archetype bot fights for balance (Docs/BOTS.md). A dedicated server on the test map `field` (or $MAP) records the
# match statistics; a headless client per bot. Prints the server's [SUMMARY] line and the script errors, copies the
# stats to stats/bots/ (repository root) for tools/stats_report.py.
#   bash tools/bots.sh SECONDS STYLE:SKILL:KIT [STYLE:SKILL:KIT ...]
#   bash tools/bots.sh 120 tapok:average:pdw larry:average:ak
# STYLE - BotProfiles.STYLES (tapok, stepashka, larry, owner, rulka), SKILL - BotProfiles.SKILLS (novice, average,
# good, pro), KIT - a kit id without "kit." (ak, acr, aug, m16, groza, val, mp7, p90, pdw, winchester, striker,
# contender, mk14, khruger). A bot's name is STYLE-SKILL (the report's rows).
# Env: MAP=field (any map: --map=), HARDCORE=1 (the "Хардкор" mode), VOD_PORT=N (another port: runs side by side),
# OUT=folder (where the stats go), GODOT (the editor binary). Runs on a copy of the project in %TEMP%\vod-bots[-PORT], like tools/test.sh.
set -u
[ $# -ge 2 ] || { sed -n 2,13p "$0"; exit 1; }
SECS=$1; shift
HERE="$(cd "$(dirname "$0")/.." && pwd)"   # vibe-of-duty-p
G="${GODOT:-$HERE/../../Godot_v4.7.2.exe}"
[ -f "$G" ] || { echo "Godot not found: $G (set GODOT)"; exit 1; }
W="$(cygpath -u "${TEMP:-/tmp}")/vod-bots${VOD_PORT:+-$VOD_PORT}"; P="$W/project"; O="$W/logs"
mkdir -p "$P" "$O" "$W/appdata"
robocopy "$(cygpath -w "$HERE")" "$(cygpath -w "$P")" //MIR //XD test-logs //NFL //NDL //NJH //NJS //NP > /dev/null
[ $? -lt 8 ] || { echo "robocopy failed"; exit 1; }
export APPDATA="$(cygpath -w "$W/appdata")"
PW="$(cygpath -w "$P")"
timeout 170 "$G" --headless --path "$PW" --import > /dev/null 2>&1
rm -f "$O"/*.log
STATS="$W/appdata/Godot/app_userdata/vibe-of-duty-p/stats"
rm -rf "$STATS"
MODE=""; [ "${HARDCORE:-}" = 1 ] && MODE="--hardcore"
R="timeout $((SECS + 60)) $G --headless --path $PW -- ${VOD_PORT:+--port=$VOD_PORT}"
# No kill limit in practice, one long match: the bots fight the whole time.
$R --server --map="${MAP:-field}" $MODE --stats --score-limit=100000 --match-time=$((SECS + 30)) \
	--summary=$((SECS + 3)) > "$O/server.log" 2>&1 &
sleep 3
for spec in "$@"; do
	IFS=: read -r style skill kit <<< "$spec"
	$R --join=127.0.0.1 $MODE --bot-style="$style" --bot-skill="$skill" --build="kit.$kit" --name="$style-$skill" \
		--summary="$SECS" > "$O/bot_${style}_${skill}_${kit}.log" 2>&1 &
done
wait
grep -hE 'SCRIPT ERROR|ERROR:|Parse Error' "$O"/*.log | grep -v 'at exit\|Unrecognized UID' | sort | uniq -c | head
grep -h '^\[SUMMARY SERVER' "$O/server.log"
OUT="${OUT:-$HERE/../stats/bots}"
mkdir -p "$OUT"
for f in "$STATS"/*.jsonl; do
	[ -f "$f" ] || continue
	name="${VOD_PORT:+$VOD_PORT-}$(basename "$f")"  # side by side runs may start in the same second
	cp "$f" "$OUT/$name" && echo "stats: $(cygpath -w "$OUT/$name")"
done
echo "logs: $(cygpath -w "$O")"
