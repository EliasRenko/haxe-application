"""
Generates a GUI texture (gui_debug.tga) with a grayscale bevel palette.

All colors are pure greyscale so the shader can tint them via per-vertex
color multiply (r,g,b,a).  Luminance values are scaled so the panel
background maps to 128 (0.5), giving headroom for both highlights and
shadows.  The HL1 olive-green look is applied at runtime by setting
canvas.setTint(0.588, 0.690, 0.518).
Icons: stamp_close = X, stamp_fold = underscore.
"""

from PIL import Image, ImageDraw

WIDTH  = 512
HEIGHT = 512

def g(v): return (v, v, v)   # grayscale helper

C_PANEL_BG  = g(128)
C_PANEL_HI  = g(215)
C_PANEL_SH  = g( 62)
C_STRIP_BG  = g( 88)
C_STRIP_HI  = g(163)
C_STRIP_SH  = g( 42)
C_BTN_BG    = g(153)
C_BTN_HI    = g(248)
C_BTN_SH    = g( 62)
C_CB_BG     = g(106)
C_CB_HI     = g(189)
C_CB_SH     = g( 53)
C_CB_TICK   = g(255)
C_ICON      = g(255)
C_CANVAS    = ( 39,  39,  39, 255)

REGIONS = [
    {"name": "button_0",      "dim": [  0,   0, 28, 28]},
    {"name": "button_1",      "dim": [ 30,   0, 28, 28]},
    {"name": "button_2",      "dim": [ 60,   0, 28, 28]},
    {"name": "checkbox_0",    "dim": [  0,  30, 28, 28]},
    {"name": "checkbox_1",    "dim": [ 30,  30, 28, 28]},
    {"name": "panel_1",       "dim": [  0,  60, 28, 28]},
    {"name": "panel_2",       "dim": [ 30,  60, 28, 28]},
    {"name": "panel_3",       "dim": [ 60,  60, 28, 28]},
    {"name": "panel_4",       "dim": [ 90,  60, 28, 28]},
    {"name": "panel_5",       "dim": [120,  60, 28, 28]},
    {"name": "panel_6",       "dim": [150,  60, 28, 28]},
    {"name": "panel_7",       "dim": [180,  60, 28, 28]},
    {"name": "panel_8",       "dim": [210,  60, 28, 28]},
    {"name": "panel_9",       "dim": [240,  60, 28, 28]},
    {"name": "strip_1",       "dim": [  0,  90, 28, 28]},
    {"name": "strip_2",       "dim": [ 30,  90, 28, 28]},
    {"name": "strip_3",       "dim": [ 60,  90, 28, 28]},
    {"name": "stamp_fold",    "dim": [ 90,  90, 28, 28]},
    {"name": "stamp_close",   "dim": [120,  90, 28, 28]},
    {"name": "slider_0",      "dim": [  0, 349, 24, 24]},
    {"name": "slider_1",      "dim": [  0, 373, 24, 24]},
    {"name": "slider_2",      "dim": [  0, 397, 24, 24]},
    {"name": "stamp_file",    "dim": [  0, 437, 24, 18]},
    {"name": "stamp_folder",  "dim": [  0, 471, 18, 16]},
    {"name": "windowPanel_0", "dim": [156,   0, 24, 24]},
    {"name": "windowPanel_1", "dim": [180,   0, 24, 24]},
    {"name": "windowPanel_2", "dim": [204,   0, 24, 24]},
    {"name": "windowPanel_3", "dim": [228,   0, 24, 24]},
    {"name": "windowPanel_4", "dim": [252,   0, 24, 24]},
    {"name": "windowPanel_5", "dim": [276,   0, 24, 24]},
    {"name": "windowPanel_6", "dim": [300,   0, 24, 24]},
    {"name": "windowPanel_7", "dim": [324,   0, 24, 24]},
    {"name": "windowPanel_8", "dim": [348,   0, 24, 24]},
    {"name": "windowStrip_0", "dim": [372,   0, 24, 24]},
    {"name": "windowStrip_1", "dim": [396,   0, 24, 24]},
    {"name": "windowStrip_2", "dim": [420,   0, 24, 24]},
]

OUTLINE_ONLY = {
    "empty", "folder", "grip_0", "indicator_0",
    "slider_full_0", "slider_full_1", "slider_full_2",
    "stamp_brush", "stamp_clipping", "stamp_select",
}

_ROLES = {0: "corner", 1: "edge_h", 2: "corner",
          3: "edge_v", 4: "center", 5: "edge_v",
          6: "corner", 7: "edge_h", 8: "corner"}

def get_role(name):
    for prefix, offset, base in (("panel_", 6, 1), ("windowPanel_", 12, 0)):
        if name.startswith(prefix):
            try: return _ROLES.get(int(name[offset:]) - base)
            except ValueError: pass
    return None

def bevel(draw, x, y, w, h, bg, hi, sh, bv=2):
    draw.rectangle([x, y, x+w-1, y+h-1], fill=bg+(255,))
    for i in range(bv):
        draw.line([x+i,     y+i,     x+w-1-i, y+i      ], fill=hi+(255,))
        draw.line([x+i,     y+i,     x+i,     y+h-1-i  ], fill=hi+(255,))
        draw.line([x+i,     y+h-1-i, x+w-1-i, y+h-1-i  ], fill=sh+(255,))
        draw.line([x+w-1-i, y+i,     x+w-1-i, y+h-1-i  ], fill=sh+(255,))

def draw_region(draw, name, x, y, w, h, outline_only=False):
    if w <= 0 or h <= 0: return
    if outline_only:
        draw.rectangle([x, y, x+w-1, y+h-1], outline=C_PANEL_HI+(120,))
        return
    role = get_role(name)

    if name.startswith("panel_") or name.startswith("windowPanel_"):
        bg, hi, sh = C_PANEL_BG, C_PANEL_HI, C_PANEL_SH
        try: idx = int(name.split("_")[1]) - (1 if name.startswith("panel_") else 0)
        except: idx = 4
        # idx map: 0=TL 1=T 2=TR / 3=L 4=C 5=R / 6=BL 7=B 8=BR
        draw.rectangle([x, y, x+w-1, y+h-1], fill=bg+(255,))
        bv = 2
        for i in range(bv):
            if idx in (0, 1, 2):  # top-facing tiles
                draw.line([x, y+i, x+w-1, y+i], fill=hi+(255,))
            if idx in (0, 3, 6):  # left-facing tiles
                draw.line([x+i, y, x+i, y+h-1], fill=hi+(255,))
            if idx in (6, 7, 8):  # bottom-facing tiles
                draw.line([x, y+h-1-i, x+w-1, y+h-1-i], fill=sh+(255,))
            if idx in (2, 5, 8):  # right-facing tiles
                draw.line([x+w-1-i, y, x+w-1-i, y+h-1], fill=sh+(255,))
        return

    # 3-slice helper: idx 0=left cap, 1=center, 2=right cap
    # Caps: top+bottom always; left side only on left cap; right side only on right cap
    def threeslice(bg, hi, sh):
        draw.rectangle([x, y, x+w-1, y+h-1], fill=bg+(255,))
        bv = 2
        for i in range(bv):
            # top + bottom on all three pieces
            draw.line([x, y+i,     x+w-1, y+i     ], fill=hi+(255,))
            draw.line([x, y+h-1-i, x+w-1, y+h-1-i ], fill=sh+(255,))
            # left cap only
            if idx == 0:
                draw.line([x+i, y, x+i, y+h-1], fill=hi+(255,))
            # right cap only
            if idx == 2:
                draw.line([x+w-1-i, y, x+w-1-i, y+h-1], fill=sh+(255,))

    if name.startswith("button_"):
        idx = int(name[7:])
        threeslice(C_BTN_BG, C_BTN_HI, C_BTN_SH)
        return

    if name.startswith("strip_") or name.startswith("windowStrip_"):
        try: idx = int(name.split("_")[1]) - (1 if name.startswith("strip_") else 0)
        except: idx = 1
        threeslice(C_STRIP_BG, C_STRIP_HI, C_STRIP_SH)
        return

    if name.startswith("checkbox_"):
        # Checkboxes are standalone — full bevel but sunken (hi/sh swapped)
        bevel(draw, x, y, w, h, C_CB_BG, C_CB_SH, C_CB_HI)
        if name == "checkbox_1":
            p = 5
            draw.line([x+p, y+h//2, x+w//2-1, y+h-p-1], fill=C_CB_TICK+(255,), width=2)
            draw.line([x+w//2-1, y+h-p-1, x+w-p, y+p], fill=C_CB_TICK+(255,), width=2)
        return

    if name == "stamp_close":
        bevel(draw, x, y, w, h, C_STRIP_BG, C_STRIP_HI, C_STRIP_SH)
        p = 6
        draw.line([x+p, y+p, x+w-1-p, y+h-1-p], fill=C_ICON+(255,), width=2)
        draw.line([x+w-1-p, y+p, x+p, y+h-1-p], fill=C_ICON+(255,), width=2)
        return

    if name == "stamp_fold":
        bevel(draw, x, y, w, h, C_STRIP_BG, C_STRIP_HI, C_STRIP_SH)
        p = 6
        cy = y + h - p - 2
        draw.line([x+p, cy, x+w-1-p, cy], fill=C_ICON+(255,), width=2)
        return

    if name.startswith("stamp_"):
        bevel(draw, x, y, w, h, C_STRIP_BG, C_STRIP_HI, C_STRIP_SH)
        return

    if name.startswith("slider_"):
        bevel(draw, x, y, w, h, C_BTN_BG, C_BTN_HI, C_BTN_SH)
        return

    bevel(draw, x, y, w, h, C_PANEL_BG, C_PANEL_HI, C_PANEL_SH)


img  = Image.new("RGBA", (WIDTH, HEIGHT), C_CANVAS)
draw = ImageDraw.Draw(img)
for r in REGIONS:
    x, y, w, h = r["dim"]
    draw_region(draw, r["name"], x, y, w, h, outline_only=(r["name"] in OUTLINE_ONLY))

out = 'c:\\Users\\efedorenko\\Documents\\projects\\github\\haxe-application\\res\\textures\\gui_debug.tga'
img.save(out)
print("Saved ->", out, str(WIDTH)+"x"+str(HEIGHT)+" RGBA")
