#!/usr/bin/env bash
# Screenshot helper: tests/shot.sh OUT.png SECONDS [game args...]  (Forward+ via software Vulkan if available)
out=$1; at=$2; shift 2
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json timeout 200 xvfb-run -a -s "-screen 0 1280x720x24" godot --path "$(dirname "$0")/.." --rendering-driver vulkan -- "$@" --shot="$out@$at" --quit-after=$(python3 -c "print($at+0.6)") 2>&1 | grep -E "SCRIPT ERROR|Parse Error" | head -5
