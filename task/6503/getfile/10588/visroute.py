import sys
from PIL import Image

# Visualizes train path in subtile coordinates (outputs to route.png)
# Usage: python3 visroute.py train_pos_log.txt
# Where log contains lines in format:
# pos_x pos_y progress advance_distance direction
# NOTE Only do small lines in top corner of map, use only one train.

S = 32  # subtile size in pixels on resulting image
# COLORS = [(200, 0, 0), (200, 200, 0), (0, 200, 0), (0, 200, 200),
#           (0, 0, 200), (200, 0, 200)] * 100
COLORS = [(255, 64, 64), (255, 255, 64), (64, 255, 64), (64, 255, 255),
          (64, 64, 255), (255, 64, 255)]

coords = [(x - 16, y - 16, p, pt, d) for x, y, p, pt, d in
          (map(int, l.split()) for l in open(sys.argv[1]))]
DXY = [(-1, -1), (-1, 0), (-1, 1), (0, 1), (1, 1), (1, 0), (1, -1), (0, -1)]
sx = ((max(p[0] + 15 for p in coords)) // 16) * 16 + 4
sy = ((max(p[1] + 15 for p in coords)) // 16) * 16 + 4
psx, psy = sx * S, sy * S
if max(psx, psy) > 5000:
    print('Image too big: %d x %d' % (psx, psyZ))
    sys.exit(1)

im = Image.new("RGB", (psx, psy), "black")


# def grid_color(x):
#     if x % 16 == 0 == 0:
#         return (150, 150, 150)
#     elif x % 8 == 0:
#         return (200, 200, 200)
#     return (220, 220, 220)
def grid_color(x):
    if x % 16 == 0 == 0:
        return (100, 100, 100)
    elif x % 8 == 0:
        return (50, 50, 50)
    return (30, 30, 30)


for x in range(0, psx, S):
    for y in range(psy):
        im.putpixel((x, y), grid_color(x // S - 2))
for y in range(0, psy, S):
    for x in range(psx):
        im.putpixel((x, y), grid_color(y // S - 2))


def dot(x, y, color, diag):
    if diag:
        for i in range(-2, 3, 1):
            for j in range(-2, 3, 1):
                if abs(i) == 2 or abs(j) == 2:
                    im.putpixel((x + i, y + j), color)
    else:
        for i in range(-1, 2, 1):
            for j in range(-1, 2, 1):
                im.putpixel((x + i, y + j), color)


def plus(x, y, color, diag):
    l = 4 if diag else 2
    for i in range(-l, l + 1, 1):
        im.putpixel((x + i, y), color)
        im.putpixel((x, y + i), color)


pd = coords[0][2]
i = 0
for x, y, p, pt, d in coords:
    dx, dy = DXY[d]
    # naive coordinates: just going in that direction
    # vx = S * x + S * dx * p // pt
    # vy = S * y + S * dy * p // pt

    # actual coordinates, takes _initial_tile_subcoord into account
    # x + int(dx == -1) + dx * progress
    vx = S * x + (dx == -1) * S + S * dx * p // pt
    vy = S * y + (dy == -1) * S + S * dy * p // pt

    # on reverse change color and shift line few pixels to avoid overlapping
    i = (i + (abs(pd - d) == 4)) % len(COLORS)

    pd = d
    ofs = 2 * S + 3 * i
    try:
        dot(ofs + vx, ofs + vy, COLORS[i], pt == 256)
        plus(ofs + S * x, ofs + S * y, COLORS[i], pt == 256)
    except IndexError:
        print('OUT', ofs + vx, ofs + vy, psx, psy)


im = im.transpose(Image.FLIP_LEFT_RIGHT)
im = im.transpose(Image.ROTATE_90)
im.save("route.png")
