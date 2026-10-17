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
# These repeated 16-bar passages match on both sides of the seam. The old
# 48 -> 80 cut crossed different melodic material and hid it with a full-bar
# blend, which audibly superimposed different notes and percussion.
START_BAR, END_BAR = 61, 77
start = analysis['downbeats'][START_BAR] - 0.03
end = analysis['downbeats'][END_BAR] - 0.03
pcm = subprocess.check_output([
    FFMPEG, '-v', 'error', '-i', str(SOURCE), '-ar', str(RATE), '-ac', '2',
    '-f', 'f32le', '-',
])
samples = np.frombuffer(pcm, dtype='<f4').reshape(-1, 2)
begin, nominal_finish = round(start * RATE), round(end * RATE)
# Beat timestamps have 20 ms resolution. Refine the outgoing position using
# stereo waveform correlation across 240 ms of the repeated passage. This
# adjusts the cut by milliseconds without resampling or changing pitch.
half_window = round(0.12 * RATE)
reference = samples[begin - half_window:begin + half_window].astype(np.float64)
reference_norm = np.linalg.norm(reference)
best_correlation, finish = -1.0, nominal_finish
for offset in range(-round(0.04 * RATE), round(0.04 * RATE) + 1):
    candidate = nominal_finish + offset
    window = samples[candidate - half_window:candidate + half_window]
    correlation = float(np.sum(reference * window) /
                        max(reference_norm * np.linalg.norm(window), 1e-12))
    if correlation > best_correlation:
        best_correlation, finish = correlation, candidate
assert best_correlation > 0.45, 'The repeated passages no longer match'
loop = samples[begin:finish].copy()
# Only bridge the last 80 ms into the original audio immediately before the
# head. Matching material needs no full-bar crossfade or beat/pitch warping.
# Linear complementary gains avoid a volume bump with correlated waveforms.
fade_size = round(0.08 * RATE)
lead = samples[begin - fade_size:begin]
weight = np.linspace(0.0, 1.0, fade_size)[:, None]
loop[-fade_size:] = loop[-fade_size:] * (1.0 - weight) + lead * weight
peak = float(np.max(np.abs(loop)))
loop *= 10 ** (-2 / 20) / max(peak, 1e-6)
OUTPUT.parent.mkdir(parents=True, exist_ok=True)
subprocess.run([
    FFMPEG, '-v', 'error', '-y', '-f', 'f32le', '-ar', str(RATE), '-ac', '2',
    '-i', '-', '-c:a', 'libvorbis', '-q:a', '6',
    '-metadata', 'title=Coin Rush', '-metadata', 'comment=ACE Studio original chiptune; matched-phrase 16-bar gameplay loop',
    str(OUTPUT),
], input=loop.astype('<f4').tobytes(), check=True)
metadata = {
    'title': 'Coin Rush', 'generator': 'ACE Studio Inspire Me',
    'source': 'coin_rush_source.mp3', 'bars': END_BAR - START_BAR,
    'start_bar_index': START_BAR, 'end_bar_index': END_BAR,
    'estimated_bpm': analysis['bpm'], 'start_seconds': start, 'end_seconds': finish / RATE,
    'loop_seconds': len(loop) / RATE, 'tail_crossfade_seconds': fade_size / RATE,
    'crossfade_method': '80 ms complementary blend into matching phrase lead-in',
    'seam_waveform_correlation': best_correlation,
    'end_adjustment_seconds': (finish - nominal_finish) / RATE,
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
