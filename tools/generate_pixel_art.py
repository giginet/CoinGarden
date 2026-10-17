"""Original SNES-inspired art, authored through draw-pixel-art's indexed harness.

Run with the skill's uv project (see README). No RGB painting or resizing is
used to author assets: all drawing writes predefined palette indices.
"""
from pathlib import Path
from math import sqrt, sin, cos, pi
from pixel_art.canvas import Canvas
from pixel_art.palette import Palette, parse_color
from pixel_art.document import save
from pixel_art.render import export_png

ROOT = Path(__file__).resolve().parents[1] / 'assets' / 'pixel'
# Palette first: shared 32-color budget, including transparency.
COLORS = {
    'ink':'17152b', 'deep':'24233d', 'night':'323454',
    'wall':'454363', 'wall_light':'575377', 'lavender':'7d7395',
    'mist':'aaa2bc', 'silver_shadow':'667e96', 'silver':'9fb3bb',
    'silver_light':'d7e6d6', 'ivory':'fff1c5', 'burgundy':'593448',
    'pink_shadow':'945069', 'rose':'c8768a', 'pink':'efa1a2',
    'peach':'ffd0af', 'copper_dark':'6c423f', 'copper':'ab6750',
    'copper_light':'e5a167', 'gold_shadow':'9d672f', 'gold':'c99743',
    'gold_light':'f5d478', 'gold_pale':'fff0ad',
    'green_shadow':'284749', 'green':'476957', 'green_light':'85a875',
    'wood_shadow':'382735', 'wood':'654650', 'wood_light':'93645d',
    'blue':'5385a1', 'sky':'89bdc7',
}
PALETTE = Palette(32)
PALETTE.add_transparent()
for name, color in COLORS.items():
    PALETTE.add(name, parse_color(color))
assert len(PALETTE) == 32

def canvas(w,h):
    return Canvas.new(w,h,PALETTE)

def dot(c,x,y,color):
    if c.in_bounds(int(x),int(y)):
        c.set_pixel(int(x),int(y),color)

def ellipse(c,cx,cy,rx,ry,color):
    for y in range(max(0,int(cy-ry)),min(c.height,int(cy+ry)+1)):
        t=1-((y-cy)/ry)**2
        if t < 0: continue
        d=rx*sqrt(t)
        lo,hi=max(0,int(cx-d+0.999)),min(c.width-1,int(cx+d))
        if hi>=lo: c.rect(lo,y,hi-lo+1,1,color)

def line(c,x1,y1,x2,y2,color):
    c.line(int(x1),int(y1),int(x2),int(y2),color)

def frame(c,x,y,w,h):
    c.rect(x+1,y+2,w,h,'ink')
    c.rect(x,y,w,h,'gold_shadow')
    c.rect(x+1,y+1,w-2,h-2,'gold_light')
    c.rect(x+2,y+2,w-4,h-4,'deep')
    c.rect(x+3,y+3,w-6,1,'wall')
    for xx,yy in [(x,y),(x+w-1,y),(x,y+h-1),(x+w-1,y+h-1)]:dot(c,xx,yy,'ink')

def spark(c,x,y,color):
    c.draw_map(['..a..','..a..','aaaaa','..a..','..a..'], {'.':'clear','a':color},(x-2,y-2))

def export(c,name):
    out=ROOT / (name+'.png'); out.parent.mkdir(parents=True,exist_ok=True)
    save(c,ROOT/'source'/(name.replace('/','_')+'.pixel.json'))
    export_png(c,out)

# Background at the final pixel grid, four display pixels per authored pixel.
bg=canvas(320,225); bg.clear('wall')
for y in range(0,211,16):
    bg.rect(0,y,320,1,'night')
    for x in range(0,320,32):
        xx=x+(16 if (y//16)%2 else 0)
        if xx<320:bg.rect(xx,y,1,min(16,225-y),'night')
for y in range(44,205,32):
    for x in range(10,319,32):
        for dx,dy in [(0,-2),(-1,0),(0,1),(1,0)]:dot(bg,x+dx,y+dy,'wall_light')
# Architectural molding and floor, with restrained tile patterns.
bg.rect(0,0,320,39,'deep');bg.rect(0,38,320,2,'ink');bg.rect(0,40,320,1,'gold_shadow')
for x in range(0,320,8):bg.rect(x,41,4,1,'wood_light')
bg.rect(0,210,320,15,'wood_shadow');bg.rect(0,210,320,2,'ink')
for y in [213,219]:
    bg.rect(0,y,320,1,'wood')
    for x in range(0,320,40):
        xx=x+(20 if y==219 else 0)
        if xx<320:bg.rect(xx,y,1,6,'wood')
for x in range(4,317,22):bg.rect(x,216,8,1,'wood_light')
# Two star-lit windows, framed like a 16-bit shop interior.
for wx in [9,278]:
    frame(bg,wx,58,33,75)
    bg.rect(wx+4,62,25,66,'night')
    bg.rect(wx+5,63,23,29,'deep')
    for sx,sy in [(8,8),(20,18),(13,31),(24,45),(8,53)]:
        dot(bg,wx+sx,62+sy,'gold_pale')
    ellipse(bg,wx+17,76,6,6,'gold_light')
    ellipse(bg,wx+20,73,5,5,'deep')
    bg.rect(wx+16,63,2,65,'wood')
    bg.rect(wx+4,95,25,2,'wood')
    bg.rect(wx-1,133,35,2,'gold_shadow')
    bg.rect(wx,135,33,2,'ink')
# Small plants: no text or decorative coins that resemble play pieces.
for px in [26,293]:
    bg.rect(px-8,197,16,3,'ink');bg.rect(px-6,199,12,10,'copper_dark')
    bg.rect(px-5,199,9,8,'copper');bg.rect(px-4,200,2,5,'copper_light')
    line(bg,px,198,px,172,'green_shadow')
    for j in range(5):
        yy=190-j*5
        direction=1 if j%2 else -1
        line(bg,px,yy,px+direction*8,yy-5,'green_shadow')
        ellipse(bg,px+direction*7,yy-5,5,2,'green')
        line(bg,px+direction*8,yy-6,px+direction*5,yy-6,'green_light')
# Ground shadow and abstract pig feet.
ellipse(bg,160,211,104,5,'ink')
for px in [103,202]:
    bg.rect(px,188,20,24,'ink'); bg.rect(px+2,189,16,21,'pink_shadow')
    bg.rect(px+3,189,13,18,'rose');bg.rect(px+4,190,4,14,'pink')
    bg.rect(px+2,207,16,3,'burgundy');bg.rect(px+9,205,2,5,'ink')
# Pixel spiral tail.
for thickness,col in [(5,'ink'),(3,'pink_shadow'),(1,'pink')]:
    for i in range(100):
        a=-0.4+2.4*pi*i/99;r=10-8*i/99
        x,y=round(49+cos(a)*r),round(127+sin(a)*r)
        bg.rect(x-thickness//2,y-thickness//2,thickness,thickness,col)

# Right-facing profile projects from the outside of the ceramic bank.
# Paint before the body so no part of the face covers the playable interior.
ellipse(bg,273,148,23,22,'ink')
ellipse(bg,274,147,21,20,'burgundy')
ellipse(bg,274,145,20,19,'pink_shadow')
ellipse(bg,275,143,18,17,'rose')
ellipse(bg,274,140,17,14,'pink')
ellipse(bg,270,135,11,6,'peach')
# One pointed, folded ear, seen from the side.
bg.draw_map([
    'oo.............',
    'oppoo..........',
    'oppppoo........',
    'opphpppoo......',
    '.opphppppoo....',
    '.opprrpppppo...',
    '..oprrrppppo...',
    '..oprrrpppo....',
    '...oprrppo.....',
    '....opppo......',
    '.....ooo.......',
],{'.':'clear','o':'burgundy','p':'pink','r':'rose','h':'peach'},(268,119),keep='.')
# Snout extends to the right; one visible nostril reinforces the profile.
bg.rect(289,138,16,18,'ink');bg.rect(287,140,20,14,'ink')
bg.rect(289,139,15,16,'pink_shadow');bg.rect(288,141,18,11,'rose')
bg.rect(289,140,14,4,'pink');bg.rect(290,140,11,1,'peach')
bg.rect(301,144,2,5,'burgundy')
# Single bright eye, blush and a short upturned smile.
bg.rect(282,135,3,5,'burgundy');dot(bg,282,135,'ivory')
ellipse(bg,282,146,4,2,'rose')
line(bg,287,156,292,156,'burgundy');line(bg,292,156,294,154,'burgundy')

def body(pad,color):
    rx,ry=100+pad,70+pad
    for y in range(69,min(225,131+ry)):
        d=rx if y<=130 else rx*sqrt(max(0,1-((y-130)/ry)**2))
        lo,hi=int(160-d+0.999),int(160+d)
        if hi>=lo:bg.rect(lo,y,hi-lo+1,1,color)
for padding,color in [(7,'ink'),(6,'burgundy'),(5,'pink_shadow'),(4,'rose'),(3,'pink'),(1,'peach'),(0,'deep')]:
    body(padding,color)
# Interior tile shading is quiet enough to keep coins legible.
for y in range(75,198):
    d=100 if y<=130 else 100*sqrt(max(0,1-((y-130)/70)**2))
    for x in range(int(160-d+1),int(160+d)):
        if y<82:dot(bg,x,y,'night')
        elif (x%24==0 and y%24==10):dot(bg,x,y,'night')
# Ceramic rim: top-left highlights and a sparse inlaid pattern.
bg.rect(55,73,1,54,'peach');bg.rect(264,73,1,54,'pink_shadow')
for yy in [83,100,117]:
    for xx in [56,264]:
        dot(bg,xx,yy-1,'gold_pale');dot(bg,xx-1,yy,'gold');dot(bg,xx,yy,'gold_light');dot(bg,xx+1,yy,'gold');dot(bg,xx,yy+1,'gold_shadow')
# Full-width slot, physically open across 800 logical pixels.
bg.rect(57,64,207,7,'ink');bg.rect(58,63,205,7,'pink_shadow')
bg.rect(59,63,203,1,'peach');bg.rect(59,65,202,3,'burgundy')
bg.rect(60,66,200,1,'ink');bg.rect(59,69,202,1,'rose')
# Small jewel fasteners at the ends of the opening.
for x in [57,263]:
    bg.rect(x-1,65,3,4,'gold_shadow');dot(bg,x,65,'gold_pale');dot(bg,x,66,'gold_light')
frame(bg,7,8,85,25);frame(bg,164,8,114,25)
frame(bg,96,8,64,25)
export(bg,'background')

DIGITS={
'0':['111','101','101','101','111'], '1':['010','110','010','010','111'],
'2':['111','001','111','100','111'], '3':['111','001','111','001','111'],
'4':['101','101','111','001','001'], '5':['111','100','111','001','111'],
'6':['111','100','111','101','111'], '7':['111','001','010','010','010'],
'8':['111','101','111','101','111'], '9':['111','101','111','001','111'],
}
for tier,(value,size) in enumerate(zip([1,5,10,50,100,500],[11,14,17,20,24,28])):
    c=canvas(size,size);m=(size-1)/2;r=size/2-0.5
    if value in [5,500]: shades=['copper_dark','gold_shadow','gold','gold_light','gold_pale']
    elif value==10: shades=['burgundy','copper_dark','copper','copper_light','peach']
    elif value==100: shades=['green_shadow','night','blue','sky','silver_light']
    else: shades=['night','silver_shadow','silver','silver_light','ivory']
    ellipse(c,m,m,r,r,'ink')
    ellipse(c,m,m-0.5,r-1,r-1,shades[0])
    ellipse(c,m-0.5,m-1,r-1.5,r-1.5,shades[3])
    ellipse(c,m,m,r-2,r-2,shades[1])
    ellipse(c,m-0.4,m-0.7,r-3,r-3,shades[2])
    # Deliberate clusters, not smoothed outlines; light comes from top-left.
    for x in range(int(m)-2,int(m)+2):dot(c,x,1,shades[4])
    for y in range(int(m)-2,int(m)+1):dot(c,1,y,shades[3])
    if size>=20:
        for i in range(12):
            a=i*pi/6
            dot(c,round(m+(r-1.5)*cos(a)),round(m+(r-1.5)*sin(a)),shades[1])
    hole=value in [5,50]
    if hole:
        hy=size//2-4
        c.rect(size//2-2,hy-1,4,4,shades[0]);c.rect(size//2-1,hy,2,2,'clear')
        c.rect(size//2-1,hy-1,2,1,shades[4])
    text=str(value);width=len(text)*4-1;ox=(size-width)//2
    oy=size//2 if hole else (size-5)//2
    # Tiny denomination stamps are baked into each sprite.
    for digit,ch in enumerate(text):
        for dy,row in enumerate(DIGITS[ch]):
            for dx,on in enumerate(row):
                if on=='1':dot(c,ox+digit*4+dx,oy+dy+1,shades[3])
        c.draw_map(DIGITS[ch],{'0':'clear','1':shades[0]},(ox+digit*4,oy),keep='0')
    if size>=24:
        for side in [-1,1]:
            xx=int(m+side*(r-5))
            line(c,xx,size-8,xx+side,size-11,shades[1])
            dot(c,xx+side,size-9,shades[3])
        # Abstract crest at top, separated from the denomination.
        for dx,dy in [(0,0),(-2,1),(2,1),(-1,2),(1,2)]:dot(c,int(m)+dx,4+dy,shades[1])
    export(c,f'coins/{value}')
    # Dedicated 13px legend coins retain full-size 3x5 denomination stamps.
    # Downscaling the large play sprites would erase their small numerals.
    mini=canvas(13,13)
    ellipse(mini,6,6,6,6,'ink')
    ellipse(mini,6,5.5,5.5,5.5,shades[3])
    ellipse(mini,6,6,4.8,4.8,shades[2])
    line(mini,4,1,7,1,shades[4])
    if hole: dot(mini,6,2,'ink')
    ox=(13-width)//2;oy=5 if hole else 4
    for digit,ch in enumerate(text):
        mini.draw_map(DIGITS[ch],{'0':'clear','1':shades[0]},(ox+digit*4,oy),keep='0')
    export(mini,f'guide/{value}')
# FX sprite: discrete, palette-colored sparkles used by exchange animations.
fx=canvas(9,9)
fx.draw_map(['....o....','....o....','...ogo...','..ogwgo..','oogwwwgoo','..ogwgo..','...ogo...','....o....','....o....'],{'.':'clear','o':'gold_shadow','g':'gold_light','w':'ivory'})
export(fx,'fx/sparkle')

# An original 5x7 bitmap alphabet; font export uses the same indexed harness.
FONT={
'A':['01110','10001','10001','11111','10001','10001','10001'],
'B':['11110','10001','10001','11110','10001','10001','11110'],
'C':['01111','10000','10000','10000','10000','10000','01111'],
'D':['11110','10001','10001','10001','10001','10001','11110'],
'E':['11111','10000','10000','11110','10000','10000','11111'],
'F':['11111','10000','10000','11110','10000','10000','10000'],
'G':['01111','10000','10000','10111','10001','10001','01111'],
'H':['10001','10001','10001','11111','10001','10001','10001'],
'I':['111','010','010','010','010','010','111'],
'J':['00111','00010','00010','00010','00010','10010','01100'],
'K':['10001','10010','10100','11000','10100','10010','10001'],
'L':['10000','10000','10000','10000','10000','10000','11111'],
'M':['10001','11011','10101','10101','10001','10001','10001'],
'N':['10001','11001','10101','10011','10001','10001','10001'],
'O':['01110','10001','10001','10001','10001','10001','01110'],
'P':['11110','10001','10001','11110','10000','10000','10000'],
'Q':['01110','10001','10001','10001','10101','10010','01101'],
'R':['11110','10001','10001','11110','10100','10010','10001'],
'S':['01111','10000','10000','01110','00001','00001','11110'],
'T':['11111','00100','00100','00100','00100','00100','00100'],
'U':['10001','10001','10001','10001','10001','10001','01110'],
'V':['10001','10001','10001','10001','10001','01010','00100'],
'W':['10001','10001','10001','10101','10101','10101','01010'],
'X':['10001','10001','01010','00100','01010','10001','10001'],
'Y':['10001','10001','01010','00100','00100','00100','00100'],
'Z':['11111','00001','00010','00100','01000','10000','11111'],
'0':['01110','10001','10011','10101','11001','10001','01110'],
'1':['00100','01100','00100','00100','00100','00100','01110'],
'2':['01110','10001','00001','00010','00100','01000','11111'],
'3':['11110','00001','00001','01110','00001','00001','11110'],
'4':['00010','00110','01010','10010','11111','00010','00010'],
'5':['11111','10000','10000','11110','00001','00001','11110'],
'6':['01110','10000','10000','11110','10001','10001','01110'],
'7':['11111','00001','00010','00100','01000','01000','01000'],
'8':['01110','10001','10001','01110','10001','10001','01110'],
'9':['01110','10001','10001','01111','00001','00001','01110'],
' ':['000'], '.':['0','0','0','0','0','0','1'],
',':['00','00','00','00','00','01','10'],
':':['0','1','0','0','1','0','0'], '-':['000','000','000','111'],
'+':['000','010','010','111','010','010'],
'/':['00001','00001','00010','00100','01000','10000','10000'],
'!':['1','1','1','1','1','0','1'], '?':['1110','0001','0001','0010','0100','0000','0100'],
'>':['1000','0100','0010','0001','0010','0100','1000'],
'<':['0001','0010','0100','1000','0100','0010','0001'],
'|':['1','1','1','1','1','1','1'],
'¥':['10001','01010','00100','11111','00100','11111','00100'],
'♪':['00110','00101','00100','00100','11100','11100','01000'],
'Ⅱ':['11011','11011','11011','11011','11011','11011','11011'],
'↺':['00010','00110','01111','10010','10000','10001','01110'],
'▶':['10000','11000','11100','11110','11100','11000','10000'],
'×':['00000','10001','01010','00100','01010','10001','00000'],
}
fp=Palette(16);fp.add_transparent();fp.add('white',(255,255,255))
atlas=Canvas.new(128,64,fp)
chars=list(map(chr,range(32,127)))+['¥','♪','Ⅱ','↺','▶','×']
lines=['info face="CoinGarden Pixel" size=8 bold=0 italic=0 unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1',
'common lineHeight=8 base=7 scaleW=128 scaleH=64 pages=1 packed=0',
'page id=0 file="pixel_font.png"',f'chars count={len(chars)}']
for i,ch in enumerate(chars):
    rows=FONT.get(ch,FONT.get(ch.upper(),FONT['?']))
    x,y=(i%16)*8,(i//16)*8
    atlas.draw_map(rows,{'0':'clear','1':'white'},(x,y))
    width=max(map(len,rows))
    lines.append(f'char id={ord(ch)} x={x} y={y} width={width} height=7 xoffset=0 yoffset=0 xadvance={width+1} page=0 chnl=15')
export_png(atlas,ROOT/'font'/'pixel_font.png');save(atlas,ROOT/'source'/'pixel_font.pixel.json')
(ROOT/'font'/'pixel_font.fnt').write_text('\n'.join(lines)+'\n')
# Native-resolution proof sheet for inspecting every coin and its holes.
sheet=canvas(144,40);sheet.clear('night')
from pixel_art.document import load
for i,value in enumerate([1,5,10,50,100,500]):
    coin=load(ROOT/'source'/f'coins_{value}.pixel.json')
    ox=i*24+(24-coin.width)//2;oy=(40-coin.height)//2
    for y,row in enumerate(coin.pixels):
        for x,index in enumerate(row):
            if index and sheet.in_bounds(ox+x,oy+y):sheet.set_pixel(ox+x,oy+y,index)
export_png(sheet,ROOT/'coin_sheet.png',scale=4)
print('Generated background, six coin sprites, sparkle, and bitmap font with indexed pixel-art harness.')
