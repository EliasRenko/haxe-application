"""
Generates a debug GUI texture (gui_debug.tga) with visually distinct regions
matching the layout defined in res/textures/gui.json.

Each UI category (buttons, checkboxes, panels, strips, stamps, sliders,
windowPanels/Strips) is given a distinct hue. 9-slice corner tiles get a
visible corner marker so they are easy to spot in-engine.

Small "embedded" regions (grip_0, slider_full_*, folder, indicator_0,
stamp_brush, stamp_clipping, stamp_select) share pixel space with the main
large tiles by atlas design. They are drawn last as outline-only rectangles
so the main tile colour remains visible and correct.
"""

from PIL import Image, ImageDraw

WIDTH  = 512
HEIGHT = 512

# ── Region data (matches gui.json) ─────────────────────────────────────────
REGIONS = [
    # Buttons (3-slice)
    {"name": "button_0",    "dim": [  0,   0, 28, 28]},
    {"name": "button_1",    "dim": [ 30,   0, 28, 28]},
    {"name": "button_2",    "dim": [ 60,   0, 28, 28]},

    # Checkboxes
    {"name": "checkbox_0",  "dim": [  0,  30, 28, 28]},
    {"name": "checkbox_1",  "dim": [ 30,  30, 28, 28]},

    # Panels (9-slice: TL T TR / L C R / BL B BR)
    {"name": "panel_1",     "dim": [  0,  60, 28, 28]},   # TL
    {"name": "panel_2",     "dim": [ 30,  60, 28, 28]},   # T
    {"name": "panel_3",     "dim": [ 60,  60, 28, 28]},   # TR
    {"name": "panel_4",     "dim": [ 90,  60, 28, 28]},   # L
    {"name": "panel_5",     "dim": [120,  60, 28, 28]},   # C
    {"name": "panel_6",     "dim": [150,  60, 28, 28]},   # R
    {"name": "panel_7",     "dim": [180,  60, 28, 28]},   # BL
    {"name": "panel_8",     "dim": [210,  60, 28, 28]},   # B
    {"name": "panel_9",     "dim": [240,  60, 28, 28]},   # BR

    # Strips (3-slice) + stamps in the same row — all safe, no overlap
    {"name": "strip_1",     "dim": [  0,  90, 28, 28]},
    {"name": "strip_2",     "dim": [ 30,  90, 28, 28]},
    {"name": "strip_3",     "dim": [ 60,  90, 28, 28]},
    {"name": "stamp_fold",  "dim": [ 90,  90, 28, 28]},
    {"name": "stamp_close", "dim": [120,  90, 28, 28]},

    # Sliders — standalone rows (safe)
    {"name": "slider_0",    "dim": [  0, 349, 24, 24]},
    {"name": "slider_1",    "dim": [  0, 373, 24, 24]},
    {"name": "slider_2",    "dim": [  0, 397, 24, 24]},

    # Stamp file / folder — safe rows
    {"name": "stamp_file",   "dim": [  0, 437, 24, 18]},
    {"name": "stamp_folder", "dim": [  0, 471, 18, 16]},

    # Window panels (9-slice: TL T TR / L C R / BL B BR)
    {"name": "windowPanel_0", "dim": [156,   0, 24, 24]},  # TL
    {"name": "windowPanel_1", "dim": [180,   0, 24, 24]},  # T
    {"name": "windowPanel_2", "dim": [204,   0, 24, 24]},  # TR
    {"name": "windowPanel_3", "dim": [228,   0, 24, 24]},  # L
    {"name": "windowPanel_4", "dim": [252,   0, 24, 24]},  # C
    {"name": "windowPanel_5", "dim": [276,   0, 24, 24]},  # R
    {"name": "windowPanel_6", "dim": [300,   0, 24, 24]},  # BL
    {"name": "windowPanel_7", "dim": [324,   0, 24, 24]},  # B
    {"name": "windowPanel_8", "dim": [348,   0, 24, 24]},  # BR
    # Window strips (3-slice)
    {"name": "windowStrip_0", "dim": [372,   0, 24, 24]},
    {"name": "windowStrip_1", "dim": [396,   0, 24, 24]},
    {"name": "windowStrip_2", "dim": [420,   0, 24, 24]},
]

# These regions are intentionally packed INSIDE a larger tile's pixel area
# in the original atlas design. Draw them outline-only so the main tile
# colours remain visible.
OUTLINE_ONLY = {
    "empty",
    "folder",
    "grip_0",
    "indicator_0",
    "slider_full_0",
    "slider_full_1",
    "slider_full_2",
    "stamp_brush",
    "stamp_clipping",
    "stamp_select",
}

# ── 9-slice role lookup ─────────────────────────────────────────────────────
NINE_SLICE_ROLES = {0: "corner", 1: "edge", 2: "corner",
                    3: "edge",   4: "center", 5: "edge",
                    6: "corner", 7: "edge",   8: "corner"}

WP_ROLES = {0: "corner", 1: "edge", 2: "corner",
            3: "edge",   4: "center", 5: "edge",
            6: "corner", 7: "edge",   8: "corner"}


def get_role(name: str):
    if name.startswith("panel_"):
        try:
            idx = int(name[6:]) - 1
            return NINE_SLICE_ROLES.get(idx)
        except ValueError:
            pass
    if name.startswith("windowPanel_"):
        try:
            idx = int(name[12:])
            return WP_ROLES.get(idx)
        except ValueError:
            pass
    return None


def base_color(name: str):
    if name.startswith("button"):
        return (60, 110, 210)
    if name.startswith("checkbox"):
        return (55, 175, 80)
    if name.startswith("panel"):
        return (190, 130, 45)
    if name.startswith("strip"):
        return (160, 65, 200)
    if name.startswith("stamp"):
        return (40, 190, 175)
    if name.startswith("slider"):
        return (210, 60, 70)
    if name.startswith("window"):
        return (70, 145, 225)
    if name in ("folder", "grip_0", "indicator_0"):
        return (140, 140, 140)
    return (130, 120, 95)


def brighten(c, amount=70):
    return tuple(min(255, v + amount) for v in c)


def darken(c, amount=50):
    return tuple(max(0, v - amount) for v in c)


def draw_region(draw: ImageDraw.ImageDraw, name: str,
                x: int, y: int, w: int, h: int, outline_only: bool = False):
    if w <= 0 or h <= 0:
        return

    fill   = base_color(name)
    border = brighten(fill, 80)
    dark   = darken(fill, 40)
    role   = get_role(name)

    if outline_only:
        # Draw just a 1-pixel border — leaves main tile colour untouched
        if w >= 2 and h >= 2:
            draw.rectangle([x, y, x + w - 1, y + h - 1],
                           outline=brighten(fill, 120) + (180,))
        return

    # ── Solid fill ──────────────────────────────────────────────────────────
    if role == "center":
        fill = brighten(fill, 30)
    elif role == "corner":
        fill = darken(fill, 10)

    draw.rectangle([x, y, x + w - 1, y + h - 1], fill=fill + (255,))

    if w >= 2 and h >= 2:
        draw.rectangle([x, y, x + w - 1, y + h - 1], outline=border + (255,))

    # ── Role markers ────────────────────────────────────────────────────────
    if role == "corner" and w >= 8 and h >= 8:
        m = 4
        draw.rectangle([x + 2, y + 2, x + 2 + m, y + 2 + m], fill=border + (255,))
    elif role == "edge" and w >= 6 and h >= 6:
        cx, cy = x + w // 2, y + h // 2
        if w > h:
            draw.line([x + 2, cy, x + w - 3, cy], fill=border + (200,))
        else:
            draw.line([cx, y + 2, cx, y + h - 3], fill=border + (200,))
    elif role == "center" and w >= 10 and h >= 10:
        cx, cy = x + w // 2, y + h // 2
        draw.line([cx - 4, cy, cx + 4, cy], fill=dark + (200,))
        draw.line([cx, cy - 4, cx, cy + 4], fill=dark + (200,))
    elif role is None and w >= 8 and h >= 8:
        cx, cy = x + w // 2, y + h // 2
        draw.line([cx - 3, cy, cx + 3, cy], fill=brighten(fill, 60) + (180,))
        draw.line([cx, cy - 3, cx, cy + 3], fill=brighten(fill, 60) + (180,))

    # ── Stamp icon ───────────────────────────────────────────────────────────
    if name.startswith("stamp") and w >= 14 and h >= 14:
        icon = brighten(fill, 100) + (220,)
        cx, cy = x + w // 2, y + h // 2
        r = min(w, h) // 4
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=icon)

    # ── Checkbox tick on state 1 ──────────────────────────────────────────────
    if name == "checkbox_1" and w >= 12 and h >= 12:
        tick = brighten(fill, 120) + (230,)
        x0, y0 = x + w // 4, y + h // 2
        x1, y1 = x + w // 2 - 1, y + h * 3 // 4
        x2, y2 = x + w * 3 // 4, y + h // 4
        draw.line([x0, y0, x1, y1], fill=tick, width=2)
        draw.line([x1, y1, x2, y2], fill=tick, width=2)


# ── Main ───────────────────────────────────────────────────────────────────
img  = Image.new("RGBA", (WIDTH, HEIGHT), (18, 18, 28, 255))
draw = ImageDraw.Draw(img)

for r in REGIONS:
    x, y, w, h = r["dim"]
    draw_region(draw, r["name"], x, y, w, h,
                outline_only=(r["name"] in OUTLINE_ONLY))

out = r"c:\Users\efedorenko\Documents\projects\github\haxe-application\res\textures\gui_debug.tga"
img.save(out)
print(f"Saved  →  {out}  ({WIDTH}×{HEIGHT} RGBA)")

