"""Build the gameplay loop from ACE Studio's source and detected downbeats.

Requires NumPy and ffmpeg. The original generation and beat analysis are kept
beside this script's inputs so the loop can be rebuilt without spending credits.
"""
import json
import shutil
import subprocess
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'tools/audio/coin_rush_source.mp3'
ANALYSIS = ROOT / 'tools/audio/beat_analysis.json'
OUTPUT = ROOT / 'assets/audio/music/coin_rush.ogg'
FFMPEG = shutil.which('ffmpeg') or '/opt/homebrew/bin/ffmpeg'
RATE = 44100

analysis = json.loads(ANALYSIS.read_text())
# Matching repeated sections, chosen by comparing the neighboring bars' spectra
# and rhythmic envelopes. Keep the downbeat attack intact at the loop head.
START_BAR, END_BAR = 48, 80
start = analysis['downbeats'][START_BAR] - 0.03
end = analysis['downbeats'][END_BAR] - 0.03
pcm = subprocess.check_output([
    FFMPEG, '-v', 'error', '-i', str(SOURCE), '-ar', str(RATE), '-ac', '2',
    '-f', 'f32le', '-',
])
samples = np.frombuffer(pcm, dtype='<f4').reshape(-1, 2)
begin, finish = round(start * RATE), round(end * RATE)
loop = samples[begin:finish].copy()
# Transition BEFORE the seam into the original lead-in to the loop head.
# The last sample then naturally leads into the untouched first sample. Unlike
# a head crossfade, this never fades away the first kick or melody attack.
tail_begin = round((analysis['downbeats'][END_BAR - 1] - 0.03) * RATE)
lead_begin = round((analysis['downbeats'][START_BAR - 1] - 0.03) * RATE)
fade_size = finish - tail_begin
lead = samples[lead_begin:begin]
# The generated performance drifts slightly in tempo. Map corresponding beats
# in the lead-in onto the final bar so drums do not double-hit during the blend.
source_beats = np.asarray(analysis['beats'], dtype=np.float64)
lead_beats = source_beats[(source_beats >= analysis['downbeats'][START_BAR - 1] - 0.001)
                          & (source_beats <= analysis['downbeats'][START_BAR] + 0.001)]
tail_beats = source_beats[(source_beats >= analysis['downbeats'][END_BAR - 1] - 0.001)
                          & (source_beats <= analysis['downbeats'][END_BAR] + 0.001)]
assert len(lead_beats) == len(tail_beats) == 5, 'Expected one complete 4/4 bar'
source_positions = (lead_beats - 0.03) * RATE - lead_begin
target_positions = (tail_beats - 0.03) * RATE - tail_begin
source_positions[[0, -1]] = [0, len(lead) - 1]
target_positions[[0, -1]] = [0, fade_size - 1]
positions = np.interp(np.arange(fade_size), target_positions, source_positions)
aligned_lead = np.column_stack([
    np.interp(positions, np.arange(len(lead)), lead[:, channel]) for channel in range(2)
])
outgoing = loop[-fade_size:].copy()
phase = np.linspace(0, np.pi / 2, fade_size)[:, None]
out_gain, in_gain = np.cos(phase), np.sin(phase)
# Correlation-aware equal-power blend avoids a dip for unrelated waveforms,
# while avoiding the gain bump of equal-power mixing for correlated material.
correlation = float(np.sum(outgoing * aligned_lead) /
                    max(np.linalg.norm(outgoing) * np.linalg.norm(aligned_lead), 1e-12))
normalizer = np.sqrt(1 + 2 * max(0, correlation) * out_gain * in_gain)
loop[-fade_size:] = (outgoing * out_gain + aligned_lead * in_gain) / normalizer
peak = float(np.max(np.abs(loop)))
loop *= 10 ** (-2 / 20) / max(peak, 1e-6)
OUTPUT.parent.mkdir(parents=True, exist_ok=True)
subprocess.run([
    FFMPEG, '-v', 'error', '-y', '-f', 'f32le', '-ar', str(RATE), '-ac', '2',
    '-i', '-', '-c:a', 'libvorbis', '-q:a', '6',
    '-metadata', 'title=Coin Rush', '-metadata', 'comment=ACE Studio original chiptune; beat-aligned 32-bar gameplay loop',
    str(OUTPUT),
], input=loop.astype('<f4').tobytes(), check=True)
metadata = {
    'title': 'Coin Rush', 'generator': 'ACE Studio Inspire Me',
    'source': 'coin_rush_source.mp3', 'bars': END_BAR - START_BAR,
    'start_bar_index': START_BAR, 'end_bar_index': END_BAR,
    'estimated_bpm': analysis['bpm'], 'start_seconds': start, 'end_seconds': end,
    'loop_seconds': len(loop) / RATE, 'tail_crossfade_seconds': fade_size / RATE,
    'crossfade_method': 'beat-aligned lead-in, correlation-aware equal-power',
    'head_attack_preserved': True,
    'peak_dbfs_before_encoding': -2, 'sample_rate': RATE,
}
(ROOT / 'tools/audio/music_manifest.json').write_text(json.dumps(metadata, indent=2) + '\n')
print(json.dumps(metadata, indent=2))
# Audition the actual encoded seam without waiting for the full loop.
decoded = subprocess.check_output([
    FFMPEG, '-v', 'error', '-i', str(OUTPUT), '-ar', str(RATE), '-ac', '2',
    '-f', 'f32le', '-',
])
decoded = np.frombuffer(decoded, dtype='<f4').reshape(-1, 2)
preview = np.concatenate([decoded[-6 * RATE:], decoded[:8 * RATE]])
subprocess.run([
    FFMPEG, '-v', 'error', '-y', '-f', 'f32le', '-ar', str(RATE), '-ac', '2',
    '-i', '-', '-c:a', 'pcm_s16le', str(ROOT / 'docs/bgm-loop-preview.wav'),
], input=preview.astype('<f4').tobytes(), check=True)
