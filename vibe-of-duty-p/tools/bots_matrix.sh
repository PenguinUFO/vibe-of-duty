#!/bin/bash
# Every kit against every style (Docs/BOTS.md, "Матрица"): 14 matches of 5 bots, one bot per style; match i gives style
# j the kit (i + 3j) mod 14 (a Latin rotation), so over the 14 matches each kit plays each style exactly once and meets
# different kits every time. PARALLEL matches side by side (own ports), the stats into one folder.
#   bash tools/bots_matrix.sh SECONDS SKILL [PARALLEL]      (default: 180 average 2)
#   python tools/stats_report.py stats/bots/matrix_<skill>_<date> --bots
# HARDCORE=1 - the "Хардкор" mode (the folder gets _hardcore).
set -u
SECS=${1:-180}; SKILL=${2:-average}; PAR=${3:-2}
HERE="$(cd "$(dirname "$0")/.." && pwd)"
KITS=(ak acr aug m16 groza val mp7 p90 pdw winchester striker contender mk14 khruger)
STYLES=(tapok stepashka larry owner rulka)
N=${#KITS[@]}
export OUT="$HERE/../stats/bots/matrix_${SKILL}${HARDCORE:+_hardcore}_$(date +%Y-%m-%d_%H-%M)"
mkdir -p "$OUT"
echo "matrix: $N matches x ${SECS}s, skill $SKILL, $PAR at a time -> $(cygpath -w "$OUT")"
for ((i = 0; i < N; i += PAR)); do
	for ((p = 0; p < PAR && i + p < N; p++)); do
		m=$((i + p))
		specs=()
		for j in "${!STYLES[@]}"; do
			specs+=("${STYLES[$j]}:$SKILL:${KITS[$(((m + 3 * j) % N))]}")
		done
		(VOD_PORT=$((27120 + p)) bash "$HERE/tools/bots.sh" "$SECS" "${specs[@]}" 2>&1 | grep -E 'SUMMARY|ERROR' \
			| sed "s/^/[match $m] /") &
	done
	wait
done
echo "done: python tools/stats_report.py \"$(cygpath -w "$OUT")\" --bots"
