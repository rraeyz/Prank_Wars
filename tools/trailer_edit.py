#!/usr/bin/env python3
"""Cuts raw trailer footage (tools/trailer.gd) into trailer.mp4 + trailer_vertical.mp4.

usage: python3 tools/trailer_edit.py OUTDIR   (expects OUTDIR/raw.avi, trailer_log.json, music.wav)
Keeps the title cards, the moments around knock-downs (most hits first), and one slow-motion replay.
"""
import json
import os
import subprocess
import sys

PRE, POST = 1.3, 2.2          # seconds kept around a knock-down
BEAT_KEEP = 9.0               # gameplay seconds per map
CARD_KEEP = 2.8               # seconds of each in-between card


def windows(beat):
    s, e = beat["start"], beat["end"]
    hits = sorted(h for h in beat["hits"] if s <= h <= e)
    out = []
    for h in hits:
        a, b = max(s, h - PRE), min(e, h + POST)
        if out and a <= out[-1][1]:
            out[-1][1] = max(out[-1][1], b)
            out[-1][2].append(h)
        else:
            out.append([a, b, [h]])
    return out


def plan(log):
    segs = []  # (start, end, speed)
    best = None
    for seg in log["segments"]:
        if seg["kind"] == "card":
            segs.append((seg["start"], seg["end"], 1.0))
            continue
        segs.append((seg["start"] - CARD_KEEP, seg["start"], 1.0))
        ws = sorted(windows(seg), key=lambda w: (-len(w[2]), w[0]))
        keep, total = [], 0.0
        for w in ws:
            if total >= BEAT_KEEP or len(keep) >= 3:
                break
            keep.append(w)
            total += w[1] - w[0]
        if not keep:  # nothing happened: just show some footage
            keep = [[seg["start"], seg["start"] + 5.0, []]]
        keep.sort()
        for w in keep:
            w[1] = min(w[1], w[0] + 6.0)  # long brawls get cut short
            w[2] = [h for h in w[2] if h <= w[1]]
            segs.append((w[0], w[1], 1.0))
            if w[2] and (best is None or len(w[2]) > best[0]):
                best = (len(w[2]), len(segs) - 1, w[2][0])
    if best:  # slow-motion replay right after the busiest moment
        _, idx, h = best
        segs.insert(idx + 1, (h - 0.4, h + 1.6, 0.5))
    return segs


def build(outdir):
    log = json.load(open(os.path.join(outdir, "trailer_log.json")))
    segs = plan(log)
    raw = os.path.join(outdir, "raw.avi")
    music = os.path.join(outdir, "music.wav")
    parts, labels = [], ""
    for i, (a, b, sp) in enumerate(segs):
        k = 1.0 / sp
        parts.append(f"[0:v]trim=start={a:.3f}:end={b:.3f},setpts=(PTS-STARTPTS)*{k}[v{i}]")
        tempo = f",atempo={sp}" if sp != 1.0 else ""
        parts.append(f"[0:a]atrim=start={a:.3f}:end={b:.3f},asetpts=PTS-STARTPTS{tempo}[a{i}]")
        labels += f"[v{i}][a{i}]"
    dur = sum((b - a) / sp for a, b, sp in segs)
    parts.append(f"{labels}concat=n={len(segs)}:v=1:a=1[vc][ac]")
    parts.append(f"[vc]fade=t=in:st=0:d=0.5,fade=t=out:st={dur - 0.8:.2f}:d=0.8,format=yuv420p[v]")
    inputs = ["-i", raw]
    if os.path.exists(music):
        inputs += ["-stream_loop", "-1", "-i", music]
        parts.append("[1:a]volume=0.45[m]")
        parts.append("[ac][m]amix=inputs=2:duration=first:normalize=0[mx]")
        parts.append(f"[mx]alimiter=limit=0.79:level=0,afade=t=out:st={dur - 1.5:.2f}:d=1.5[a]")
    else:
        parts.append(f"[ac]alimiter=limit=0.79:level=0,afade=t=out:st={dur - 1.5:.2f}:d=1.5[a]")
    out = os.path.join(outdir, "trailer.mp4")
    cmd = ["ffmpeg", "-y", "-loglevel", "error"] + inputs + [
        "-filter_complex", ";".join(parts), "-map", "[v]", "-map", "[a]",
        "-c:v", "libx264", "-crf", "21", "-preset", "medium", "-r", "30",
        "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", out]
    subprocess.run(cmd, check=True)
    vert = os.path.join(outdir, "trailer_vertical.mp4")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", out, "-vf", "crop=ih*9/16:ih,scale=1080:1920",
                    "-c:v", "libx264", "-crf", "20", "-preset", "medium", "-c:a", "copy",
                    "-movflags", "+faststart", vert], check=True)
    print(f"{len(segs)} cuts, {dur:.1f}s -> {out}, {vert}")


if __name__ == "__main__":
    build(sys.argv[1])
