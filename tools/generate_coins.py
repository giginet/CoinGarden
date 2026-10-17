"""Generate original, scalable Japanese coin-inspired artwork (no external assets)."""
from pathlib import Path
from math import sin, cos, pi

OUT = Path(__file__).resolve().parents[1] / 'assets' / 'coins'
PALETTES = [
    ('1', '#f4faf5', '#bbcfc6', '#829c90', '#658073'),
    ('5', '#ffe9a0', '#d4ac4d', '#ae7d2d', '#9b742c'),
    ('10', '#efba91', '#bd8059', '#8a5236', '#855139'),
    ('50', '#edf7ed', '#b5c7b9', '#789484', '#698375'),
    ('100', '#f6fbf4', '#c5d5c8', '#8ca393', '#708979'),
    ('500', '#fff0b4', '#d5bd71', '#ab9148', '#968040'),
]
for value, light, mid, dark, ink in PALETTES:
    hole = value in ('5', '50')
    # Even-odd compound path gives the 5/50 yen a genuinely transparent hole.
    disc = 'M128 3a125 125 0 1 0 0 250a125 125 0 1 0 0-250Z'
    if hole:
        disc += ' M128 66a20 20 0 1 0 0 40a20 20 0 1 0 0-40Z'
    parts = [f'''<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
<defs><linearGradient id="metal" x1="0" y1="0" x2="0.8" y2="1"><stop stop-color="{light}"/><stop offset="0.46" stop-color="{mid}"/><stop offset="1" stop-color="{dark}"/></linearGradient>
<linearGradient id="rim" x1="0" y1="0" x2="1" y2="1"><stop stop-color="{light}"/><stop offset="0.5" stop-color="{dark}"/><stop offset="1" stop-color="{light}"/></linearGradient></defs>
<path d="{disc}" fill="url(#metal)" fill-rule="evenodd" stroke="{dark}" stroke-width="4"/>
<circle cx="128" cy="128" r="116" fill="none" stroke="url(#rim)" stroke-width="6"/>
<circle cx="128" cy="128" r="105" fill="none" stroke="{ink}" stroke-width="1.5" opacity="0.55"/>''']
    if value in ('50', '100', '500'):
        for i in range(72):
            a = i * 2 * pi / 72
            parts.append(f'<path d="M{128+108*cos(a):.2f} {128+108*sin(a):.2f}L{128+113*cos(a):.2f} {128+113*sin(a):.2f}" stroke="{ink}" stroke-width="1.6" opacity="0.6"/>')
    if hole:
        parts.append(f'<circle cx="128" cy="86" r="22" fill="none" stroke="{ink}" stroke-width="3"/><path d="M107 85a21 21 0 0 1 42 0" fill="none" stroke="{light}" stroke-width="2"/>')
    # Paired botanical branches: leaves / rice grains / laurel.
    for side in (1, -1):
        parts.append(f'<g transform="translate(128 128) scale({side} 1)" fill="none" stroke="{ink}" opacity="0.7" stroke-width="2.5" stroke-linecap="round"><path d="M-10 76 Q-78 61 -70 -29"/>')
        for j in range(5):
            x, y = -30 - j*9, 67 - j*18
            parts.append(f'<path d="M{x} {y}q-22 -1 -19 -17q17 1 19 17M{x} {y}q16 -8 8 -22q-13 8 -8 22" fill="{ink}" fill-opacity="0.28"/>')
        parts.append('</g>')
    if not hole:
        # Distinct crests: sapling, temple roof, cherry blossom, paulownia.
        if value == '1':
            motif = '<path d="M128 79V49M128 64q-28 0 -26 -19q24 -2 26 19M128 56q0 -21 24 -21q1 21 -24 21"/>'
        elif value == '10':
            motif = '<path d="M96 74h64M100 60h56M109 60v14m12 -14v14m14 -14v14m12 -14v14M94 58l34 -20l34 20M105 46h46"/>'
        elif value == '100':
            motif = ''.join(f'<ellipse cx="128" cy="47" rx="8" ry="15" transform="rotate({a} 128 60)"/>' for a in range(0,360,72))
        else:
            motif = '<path d="M128 78V38m-20 36V47m40 27V47M96 79h64"/>' + ''.join(f'<circle cx="{x}" cy="{y}" r="5"/>' for x,y in [(108,43),(128,34),(148,43),(100,54),(116,54),(120,45),(136,45),(140,54),(156,54)])
        parts.append(f'<g fill="none" stroke="{ink}" stroke-width="2.5" opacity="0.75">{motif}</g>')
    parts.append(f'<path d="M117 215h22M122 222h12" stroke="{ink}" stroke-width="2" stroke-linecap="round" opacity="0.7"/></svg>')
    (OUT / f'{value}.svg').write_text('\n'.join(parts))
print('Generated six original coin designs.')
