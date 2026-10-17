"""Generate reproducible game effects using the installed Zappu CLI."""
import json
import subprocess
import io
import wave
import array
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ZAPPU = '/Applications/Zappu.app/Contents/Helpers/zappu'
PRESETS = {
    'drop': 'blipSelect', 'land': 'click', 'exchange': 'chime',
    'chain': 'chime', 'cashout': 'chime', 'game_over': 'tone',
    'ui': 'confirm', 'start': 'tone',
}

for name, preset in PRESETS.items():
    output = ROOT / 'assets/audio/sfx' / f'{name}.wav'
    output.parent.mkdir(parents=True, exist_ok=True)
    result = json.loads(subprocess.check_output([
        ZAPPU, 'generate', preset, '--seed', f'exchanger-{name}-v1',
        '--name', f'Coin Garden {name}', '--no-save', '--json',
    ]))
    parameters = result['parameters']
    if name == 'game_over':
        # Three descending, rounded brass-like hits: de, de, deeen.
        parameters.update(waveType='sine', baseFrequency=0.34,
                          envelopeAttack=0.018, envelopeSustain=0.18,
                          envelopeDecay=0.22, envelopePunch=0.22,
                          envelopeCurve=0.35, harmonics=0.55,
                          harmonicsFalloff=0.6, vibratoStrength=0,
                          frequencyRamp=0, frequencyDeltaRamp=0,
                          arpeggioMod=0, arpeggioSpeed=0, soundVolume=0.25)
    if name == 'start':
        # A sustained referee whistle: bright sine, slight flutter, abrupt release.
        parameters.update(waveType='sine', baseFrequency=0.88,
                          envelopeAttack=0.025, envelopeSustain=0.51,
                          envelopeDecay=0.12, envelopePunch=0.08,
                          harmonics=0.14, harmonicsFalloff=0.35,
                          vibratoStrength=0.045, vibratoSpeed=0.65,
                          frequencyRamp=0, frequencyDeltaRamp=0,
                          arpeggioMod=0, arpeggioSpeed=0, soundVolume=0.23)
    if name in ['exchange', 'chain', 'cashout']:
        # A struck metal ring, not a pitch sweep or a power-up siren.
        parameters.update(waveType='sine', baseFrequency=0.52,
                          envelopeAttack=0.004, envelopeSustain=0.025,
                          envelopeDecay=0.48, envelopePunch=0.32,
                          envelopeCurve=0.5, harmonics=0.8,
                          harmonicsFalloff=0.62, vibratoStrength=0.018,
                          vibratoSpeed=0.45, arpeggioMod=0, arpeggioSpeed=0,
                          frequencyRamp=0, frequencyDeltaRamp=0,
                          soundVolume=0.25)
    source = ROOT / 'tools/audio' / f'{name}.zappu.json'
    source.parent.mkdir(parents=True, exist_ok=True)
    source.write_text(json.dumps(parameters, indent=2) + '\n')
    # Zappu's sandboxed CLI supports WAV stdout for project destinations.
    def render(params):
        return subprocess.check_output([
            ZAPPU, 'render', json.dumps(params), '--wav', '-',
            '--seed', f'exchanger-{name}-v1',
        ])
    data = render(parameters)
    layers = []
    if name == 'game_over':
        layers = [(0.0, 0.85, data),
                  (0.24, 0.9, render(dict(parameters, baseFrequency=0.30)))]
        # Hold the final minor chord, with a low root and a soft falling tail.
        for frequency, gain in [(0.25, 1.0), (0.273, 0.32), (0.307, 0.25)]:
            tail = dict(parameters, baseFrequency=frequency,
                        envelopeSustain=0.35, envelopeDecay=0.56,
                        vibratoStrength=0.025, vibratoSpeed=0.3)
            layers.append((0.48, gain, render(tail)))
    if name in ['exchange', 'chain', 'cashout']:
        # Closely spaced clinks make a recognizable coin jingle. All exchange
        # variants share the same root pitch so the in-game scale stays ordered.
        layers = [(0.0, 1.0, data)]
        for delay, gain, frequency in [(0.035, 0.48, 0.67), (0.075, 0.28, 0.81)]:
            layers.append((delay, gain, render(dict(parameters, baseFrequency=frequency))))
        if name == 'cashout':
            layers += [(0.12, 0.5, data), (0.24, 0.3, data)]
    if layers:
        mixed = []
        for delay, gain, pcm in layers:
            with wave.open(io.BytesIO(pcm)) as wav:
                assert wav.getnchannels() == 1 and wav.getsampwidth() == 2
                rate = wav.getframerate()
                samples = array.array('h', wav.readframes(wav.getnframes()))
            offset = round(delay * rate)
            mixed.extend([0.0] * max(0, offset + len(samples) - len(mixed)))
            for index, sample in enumerate(samples):
                mixed[offset + index] += sample * gain
        gain = 27000 / max(1, max(abs(sample) for sample in mixed))
        with wave.open(str(output), 'wb') as wav:
            wav.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
            wav.writeframes(array.array('h', (round(sample * gain) for sample in mixed)).tobytes())
    else:
        output.write_bytes(data)
    print(name, output.stat().st_size, 'bytes')
