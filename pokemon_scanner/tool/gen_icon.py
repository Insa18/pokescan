#!/usr/bin/env python3
"""Génère les icônes Pokéball (rouge haut / blanc bas) sans dépendance externe.

Produit deux PNG RGBA :
- assets/icon/icon.png            : Pokéball sur fond jaune, plein cadre (iOS / legacy)
- assets/icon/icon_foreground.png : Pokéball centrée ~60 %, fond transparent (adaptive)
"""
import os
import struct
import zlib

RED = (238, 21, 21)
WHITE = (255, 255, 255)
BLACK = (24, 24, 28)
YELLOW = (255, 203, 5)

SIZE = 1024
SS = 3  # supersampling (SSxSS échantillons par pixel)


def ball_color(x, y, cx, cy, R):
    """Couleur (r,g,b,a) du Pokéball au point (x,y), ou None si hors balle."""
    dx, dy = x - cx, y - cy
    d = (dx * dx + dy * dy) ** 0.5
    if d > R:
        return None
    if d > R * 0.94:
        return (*BLACK, 255)  # contour
    dc = d
    if dc <= R * 0.18:
        return (*WHITE, 255)  # centre du bouton
    if dc <= R * 0.26:
        return (*BLACK, 255)  # anneau du bouton
    if abs(dy) <= R * 0.10:
        return (*BLACK, 255)  # bande centrale
    return (*RED, 255) if dy < 0 else (*WHITE, 255)


def render(path, bg, radius_ratio):
    cx = cy = SIZE / 2.0
    R = SIZE * radius_ratio
    raw = bytearray()
    for py in range(SIZE):
        raw.append(0)  # filtre 0 (None) pour la scanline
        for px in range(SIZE):
            ar = ag = ab = aa = 0
            for sy in range(SS):
                for sx in range(SS):
                    x = px + (sx + 0.5) / SS
                    y = py + (sy + 0.5) / SS
                    c = ball_color(x, y, cx, cy, R)
                    if c is None:
                        c = (*bg, 255) if bg else (0, 0, 0, 0)
                    ar += c[0] * c[3]
                    ag += c[1] * c[3]
                    ab += c[2] * c[3]
                    aa += c[3]
            n = SS * SS
            a = aa / n
            if a > 0:
                r = round(ar / aa)
                g = round(ag / aa)
                b = round(ab / aa)
            else:
                r = g = b = 0
            raw += bytes((r, g, b, round(a)))
    _write_png(path, raw)


def _chunk(tag, data):
    return (struct.pack(">I", len(data)) + tag + data +
            struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))


def _write_png(path, raw):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    ihdr = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0)
    png = (b"\x89PNG\r\n\x1a\n" + _chunk(b"IHDR", ihdr) +
           _chunk(b"IDAT", zlib.compress(bytes(raw), 9)) +
           _chunk(b"IEND", b""))
    with open(path, "wb") as f:
        f.write(png)
    print("écrit", path, len(png), "octets")


if __name__ == "__main__":
    base = os.path.join(os.path.dirname(__file__), "..", "assets", "icon")
    render(os.path.join(base, "icon.png"), YELLOW, 0.42)
    render(os.path.join(base, "icon_foreground.png"), None, 0.30)
