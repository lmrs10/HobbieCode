#!/bin/bash
set -e
VIDEO="$1"
OUTDIR="$2"
DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$VIDEO")
mkdir -p "$OUTDIR"
python3 -c "
import subprocess
dur = float('$DUR')
fracs = [0.08, 0.22, 0.36, 0.50, 0.64, 0.78, 0.90]
for i, f in enumerate(fracs, 1):
    t = dur * f
    out = f'$OUTDIR/frame_{i:02d}.png'
    subprocess.run(['ffmpeg','-y','-ss',str(t),'-i','$VIDEO','-frames:v','1','-vf','scale=960:-1', out],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
"
ls "$OUTDIR"
