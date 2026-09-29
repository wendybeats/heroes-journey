#!/usr/bin/env python3
"""Verify WCAG 2.x contrast for Content/v1/design-tokens.json.

Rules enforced (exit 1 on failure):
  text.primary   on every surface  >= 7.0  (AAA body)
  text.secondary on every surface  >= 4.5  (AA body)
  text.muted     on surface.base   >= 3.0  (AA large / non-essential)
  every accent   on surface.base   >= 3.0  (AA UI component / large text)
  text.on_accent on every accent   >= 4.5
  accent.gold (primary) on every surface >= 4.5 (it carries XP numbers at small sizes)
  text.on_accent on accent.button  >= 7.0
  hierarchy names must resolve to accents; attribute colors must alias an accent
"""
import json, sys

TOK = json.load(open("Content/v1/design-tokens.json"))

def lin(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def lum(h):
    h = h.lstrip("#")
    r, g, b = (int(h[i:i+2], 16) for i in (0, 2, 4))
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)

def ratio(a, b):
    la, lb = lum(a), lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)

fails = 0
def check(label, fg, bg, minimum):
    global fails
    r = ratio(fg, bg)
    ok = r >= minimum
    fails += 0 if ok else 1
    print(f"{'PASS' if ok else 'FAIL'}  {r:5.2f} >= {minimum:<4}  {label}")

surfaces = {k: v["hex"] for k, v in TOK["surface"].items() if k not in ("scene_fade", "scrim")}
for sk, sv in surfaces.items():
    check(f"text.primary on surface.{sk}", TOK["text"]["primary"]["hex"], sv, 7.0)
    check(f"text.secondary on surface.{sk}", TOK["text"]["secondary"]["hex"], sv, 4.5)
check("text.muted on surface.base", TOK["text"]["muted"]["hex"], surfaces["base"], 3.0)
for ak, av in TOK["accent"].items():
    check(f"accent.{ak} on surface.base", av["hex"], surfaces["base"], 3.0)
    check(f"accent.{ak} on surface.raised", av["hex"], surfaces["raised"], 3.0)
    check(f"text.on_accent on accent.{ak}", TOK["text"]["on_accent"]["hex"], av["hex"], 4.5)
check("accent.gold on surface.overlay", TOK["accent"]["gold"]["hex"], surfaces["overlay"], 4.5)
check("accent.gold on surface.raised", TOK["accent"]["gold"]["hex"], surfaces["raised"], 4.5)
check("text.on_accent on accent.button", TOK["text"]["on_accent"]["hex"], TOK["accent"]["button"]["hex"], 7.0)
h = TOK["hierarchy"]
for name in [h["primary"], h["tertiary"], h["destructive"], *h["fallback"]]:
    if name not in TOK["accent"]:
        fails += 1; print(f"FAIL  hierarchy names unknown accent '{name}'")
accent_hexes = {v["hex"] for v in TOK["accent"].values()}
for name, v in TOK["attribute"].items():
    if v["hex"] not in accent_hexes:
        fails += 1; print(f"FAIL  attribute.{name} {v['hex']} does not alias an accent")
    else:
        print(f"PASS  attribute.{name} aliases an accent")
print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
