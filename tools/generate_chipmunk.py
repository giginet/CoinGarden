"""Draw the ambient chipmunk with draw-pixel-art's indexed 16-color canvas."""
from pathlib import Path
from math import sqrt
from pixel_art.canvas import Canvas
from pixel_art.palette import Palette, parse_color
from pixel_art.document import save
from pixel_art.render import export_png

ROOT = Path(__file__).resolve().parents[1] / 'assets/pixel'
palette = Palette(16)
palette.add_transparent()
for name, color in {
    'ink': '17152b', 'dark': '6c423f', 'brown': 'ab6750',
    'tan': 'e5a167', 'cream': 'fff1c5', 'peach': 'ffd0af',
    'pink': 'efa1a2', 'gold': 'f5d478',
}.items():
    palette.add(name, parse_color(color))


def oval(c, x, y, rx, ry, color):
    for yy in range(max(0, int(y-ry)), min(c.height, int(y+ry)+1)):
        d = rx * sqrt(max(0, 1-((yy-y)/ry)**2))
        left, right = max(0, int(x-d+0.999)), min(c.width-1, int(x+d))
        if right >= left:
            c.rect(left, yy, right-left+1, 1, color)


def fur(c, x, y, rx, ry):
    oval(c, x, y, rx, ry, 'ink')
    oval(c, x, y-0.5, rx-1, ry-1, 'brown')
    oval(c, x-1, y-1, max(1, rx-2), max(1, ry-2), 'tan')


def run_frame(frame):
    c = Canvas.new(32, 28, palette)
    bounce = [0, -1, -1, 0, 1, 0][frame]
    stride = [-2, 0, 2, 2, 0, -2][frame]
    # A fluffy upright tail and three contrasting back stripes identify a chipmunk.
    fur(c, 6, 15+bounce, 5, 8)
    oval(c, 5, 12+bounce, 2, 4, 'cream')
    c.line(7, 11+bounce, 8, 18+bounce, 'dark')
    fur(c, 16, 20+bounce, 9, 5)
    c.line(10, 17+bounce, 21, 17+bounce, 'dark')
    c.line(10, 18+bounce, 21, 18+bounce, 'cream')
    c.line(10, 19+bounce, 22, 19+bounce, 'dark')
    oval(c, 18, 22+bounce, 5, 2, 'cream')
    # Alternate fore/hind paws rather than sliding a static pose.
    for x, offset in [(12, stride), (22, -stride)]:
        c.line(x, 22+bounce, x+offset, 25, 'dark')
        c.rect(x+offset-1, 25, 4, 2, 'ink')
        c.rect(x+offset, 25, 3, 1, 'tan')
    fur(c, 24, 15+bounce, 6, 6)
    fur(c, 21, 9+bounce, 2, 3)
    c.rect(21, 8+bounce, 1, 2, 'pink')
    c.line(21, 12+bounce, 25, 12+bounce, 'dark')
    c.line(22, 13+bounce, 26, 13+bounce, 'cream')
    oval(c, 27, 18+bounce, 3, 2, 'cream')
    c.rect(26, 14+bounce, 2, 3, 'ink')
    c.set_pixel(26, 14+bounce, 'cream')
    c.rect(30, 16+bounce, 2, 2, 'ink')
    c.set_pixel(27, 18+bounce, 'pink')
    return c


def dance_frame(frame):
    c = Canvas.new(32, 28, palette)
    sway = [-1, 0, 1, 1, 0, -1][frame]
    bob = [0, -1, 0, 0, -1, 0][frame]
    fur(c, 24+sway, 18, 5, 8)
    oval(c, 24+sway, 15, 2, 4, 'cream')
    c.line(26+sway, 15, 26+sway, 22, 'dark')
    fur(c, 15+sway, 20+bob, 6, 6)
    oval(c, 15+sway, 21+bob, 3, 4, 'cream')
    # Little kicks, raised hands, cheek stripes and round ears.
    for x, lift in [(11, frame in [1, 2]), (18, frame in [4, 5])]:
        c.rect(x+sway-1, 25-int(lift)*2, 5, 2, 'ink')
        c.rect(x+sway, 25-int(lift)*2, 3, 1, 'tan')
    for x, side, raised in [(10, -1, frame < 3), (20, 1, frame >= 3)]:
        end_y = 13 if raised else 22
        c.line(x+sway, 19+bob, x+sway+side*4, end_y+bob, 'ink')
        c.line(x+sway, 18+bob, x+sway+side*4, end_y-1+bob, 'brown')
        oval(c, x+sway+side*4, end_y-1+bob, 2, 2, 'tan')
    fur(c, 10+sway, 7+bob, 3, 4)
    fur(c, 20+sway, 7+bob, 3, 4)
    c.rect(9+sway, 5+bob, 2, 3, 'pink')
    c.rect(19+sway, 5+bob, 2, 3, 'pink')
    fur(c, 15+sway, 12+bob, 8, 7)
    c.rect(14+sway, 6+bob, 2, 5, 'dark')
    c.line(16+sway, 6+bob, 16+sway, 10+bob, 'cream')
    for x in [9+sway, 19+sway]:
        c.line(x, 13+bob, x+2, 13+bob, 'cream')
        c.line(x, 14+bob, x+2, 14+bob, 'dark')
        c.rect(x+1, 10+bob, 2, 3, 'ink')
        c.set_pixel(x+1, 10+bob, 'cream')
    oval(c, 15+sway, 15+bob, 4, 3, 'cream')
    c.rect(14+sway, 14+bob, 2, 1, 'ink')
    c.set_pixel(15+sway, 16+bob, 'dark')
    c.set_pixel(10+sway, 15+bob, 'pink')
    c.set_pixel(20+sway, 15+bob, 'pink')
    return c


sheet = Canvas.new(192, 56, palette)
for row, draw_frame in enumerate([run_frame, dance_frame]):
    for frame in range(6):
        sprite = draw_frame(frame)
        for y, pixels in enumerate(sprite.pixels):
            for x, index in enumerate(pixels):
                if index:
                    sheet.set_pixel(frame*32+x, row*28+y, index)
save(sheet, ROOT/'source/chipmunk.pixel.json')
export_png(sheet, ROOT/'chipmunk.png')
export_png(sheet, Path('/tmp/chipmunk-sheet.png'), scale=4)
print('Generated six running and six dancing chipmunk frames.')
