#!/usr/bin/env python3
"""New Game maps in an old-atlas style (parchment, sepia ink, graticule, compass rose).
Outlines: Natural Earth (public domain), tools/map_data/land110.geojson and land50.geojson.
Writes tools/map_data/map_world.svg and map_europe.svg (Godot converts them to PNG with paper grain:
tools/make_map.gd) and data/shared/map.json with the projections and the location of each league.
Usage: python3 tools/make_map.py && godot --headless --path . -s tools/make_map.gd"""
import json, math

SEA = "#E8DCBC"
LAND = "#D5BC88"
COAST_GLOW = "#C9AE7A"
INK = "#5E4426"
GRID = "#B39A6C"

MAPS = {
    "world": {"lon0": -170.0, "lon1": 190.0, "lat0": -58.0, "lat1": 80.0, "w": 1600, "scale": 1.0, "src": "land110.geojson", "grid": 30},
    "europe": {"lon0": -12.0, "lon1": 34.0, "lat0": 35.0, "lat1": 66.0, "w": 820, "scale": math.cos(math.radians(50)), "src": "land50.geojson", "grid": 10},
}
PINS = {
    "comp_british_irish_league": [54.2, -2.8, "europe"], "comp_france_league": [46.6, 2.4, "europe"],
    "comp_germany_league": [49.6, 10.2, "europe"], "comp_iberia_lux_league": [40.2, -4.0, "europe"],
    "comp_nordic_league": [61.5, 14.5, "europe"], "comp_italy_league": [42.6, 12.6, "europe"],
    "comp_low_countries_league": [51.9, 4.8, "europe"], "comp_central_europe_league": [48.9, 18.2, "europe"],
    "comp_eastern_europe_league": [47.2, 25.5, "europe"],
    "comp_usa_league": [39.0, -97.0, "world"], "comp_canada_league": [55.5, -102.0, "world"],
    "comp_mexico_caribbean_league": [21.0, -95.0, "world"], "comp_andes_league": [-9.0, -76.0, "world"],
    "comp_brazil_league": [-11.0, -50.0, "world"], "comp_argentina_league": [-35.5, -63.5, "world"],
    "comp_africa_league": [4.0, 20.0, "world"], "comp_india_league": [22.0, 79.0, "world"],
    "comp_east_asia_league": [31.0, 113.0, "world"], "comp_japan_league": [36.5, 138.5, "world"],
    "comp_oceania_league": [-26.0, 138.0, "world"],
    "school_hogwarts": [57.0, -4.6, "europe"], "school_ilvermorny": [42.6, -73.2, "world"],
    "school_beauxbatons": [42.8, 0.6, "europe"], "school_durmstrang": [42.6, 25.2, "europe"],  # Beauxbatons [PM], Durmstrang [inferred]
    "school_koldovstoretz": [57.0, 40.0, "world"], "school_mahoutokoro": [24.2, 141.5, "world"],  # Mahoutokoro [PM]
    "school_castelobruxo": [-3.5, -62.0, "world"], "school_uagadou": [0.4, 29.9, "world"],  # Castelobruxo [PM], Uagadou [PM]
    "school_wollemi": [-33.0, 150.4, "world"], "school_kapadokya": [38.6, 34.8, "world"],  # [FILLER]
    "school_nilgiri": [11.4, 76.7, "world"],  # [FILLER]
}


def proj(m, lon, lat):
    if lon < m["lon0"]:
        lon += 360.0
    span_x = (m["lon1"] - m["lon0"]) * m["scale"]
    span_y = m["lat1"] - m["lat0"]
    h = m["w"] * span_y / span_x
    x = (lon - m["lon0"]) * m["scale"] / span_x * m["w"]
    y = (m["lat1"] - lat) / span_y * h
    return x, y, h


def rings(geom):
    if geom["type"] == "Polygon":
        return [geom["coordinates"][0]]
    return [p[0] for p in geom["coordinates"]]


def svg_for(name, m):
    feats = json.load(open("tools/map_data/" + m["src"].replace("land", "land") ))["features"]
    _, _, h = proj(m, m["lon0"], m["lat0"])
    w = m["w"]
    paths = []
    for f in feats:
        for ring in rings(f["geometry"]):
            pts = []
            for lon, lat in ring:
                x, y, _ = proj(m, lon, lat)
                pts.append(f"{x:.1f},{y:.1f}")
            xs = [float(p.split(",")[0]) for p in pts]
            if name == "world" and max(xs) - min(xs) > w * 0.9:
                continue
            paths.append("M" + " L".join(pts) + " Z")
    d = " ".join(paths)
    g = []
    step = m["grid"]
    lon = math.ceil(m["lon0"] / step) * step
    while lon <= m["lon1"]:
        x, _, _ = proj(m, lon, 0)
        g.append(f'<line x1="{x:.1f}" y1="0" x2="{x:.1f}" y2="{h:.1f}"/>')
        lon += step
    lat = math.ceil(m["lat0"] / step) * step
    while lat <= m["lat1"]:
        _, y, _ = proj(m, m["lon0"], lat)
        g.append(f'<line x1="0" y1="{y:.1f}" x2="{w}" y2="{y:.1f}"/>')
        lat += step
    extra = ""
    if name == "world":
        _, ye, _ = proj(m, 0, 0)
        extra += f'<line x1="0" y1="{ye:.1f}" x2="{w}" y2="{ye:.1f}" stroke="{INK}" stroke-width="1.2" stroke-dasharray="10 6" opacity="0.55"/>'
        cx, cy, _ = proj(m, -22, -38)
        extra += compass(cx, cy, 52)
        e = MAPS["europe"]
        x0, y0, _ = proj(m, e["lon0"], e["lat1"])
        x1, y1, _ = proj(m, e["lon1"], e["lat0"])
        extra += f'<rect x="{x0:.1f}" y="{y0:.1f}" width="{x1-x0:.1f}" height="{y1-y0:.1f}" fill="none" stroke="{INK}" stroke-width="1.6" stroke-dasharray="6 4" opacity="0.8"/>'
    else:
        cx, cy, _ = proj(m, -8.5, 38.5)
        extra += compass(cx, cy, 44)
    frame = f'<rect x="3" y="3" width="{w-6}" height="{h-6:.1f}" fill="none" stroke="{INK}" stroke-width="3"/><rect x="10" y="10" width="{w-20}" height="{h-20:.1f}" fill="none" stroke="{INK}" stroke-width="1"/>'
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h:.0f}" viewBox="0 0 {w} {h:.1f}">'
           f'<rect width="{w}" height="{h:.1f}" fill="{SEA}"/>'
           f'<g stroke="{GRID}" stroke-width="0.8" opacity="0.6">{"".join(g)}</g>'
           f'<path d="{d}" fill="none" stroke="{COAST_GLOW}" stroke-width="9" stroke-linejoin="round" opacity="0.45"/>'
           f'<path d="{d}" fill="none" stroke="{COAST_GLOW}" stroke-width="4" stroke-linejoin="round" opacity="0.6"/>'
           f'<path d="{d}" fill="{LAND}" stroke="{INK}" stroke-width="1.3" stroke-linejoin="round"/>'
           f'{extra}{frame}</svg>')
    open(f"tools/map_data/map_{name}.svg", "w").write(svg)
    return h


def compass(cx, cy, r):
    pts = []
    for i in range(16):
        a = math.radians(i * 22.5 - 90)
        rr = r if i % 4 == 0 else (r * 0.55 if i % 2 == 0 else r * 0.32)
        pts.append(f"{cx + math.cos(a) * rr:.1f},{cy + math.sin(a) * rr:.1f}")
        a2 = math.radians(i * 22.5 - 90 + 11.25)
        pts.append(f"{cx + math.cos(a2) * r * 0.16:.1f},{cy + math.sin(a2) * r * 0.16:.1f}")
    s = f'<g opacity="0.85"><circle cx="{cx:.1f}" cy="{cy:.1f}" r="{r*0.72:.1f}" fill="none" stroke="{INK}" stroke-width="1"/>'
    s += f'<polygon points="{" ".join(pts)}" fill="{LAND}" stroke="{INK}" stroke-width="1.2"/>'
    s += f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="3" fill="{INK}"/>'
    s += f'<text x="{cx:.1f}" y="{cy - r - 6:.1f}" font-family="serif" font-size="{r*0.42:.0f}" fill="{INK}" text-anchor="middle">N</text></g>'
    return s


def main():
    out = {"maps": {}, "pins": {}}
    for name, m in MAPS.items():
        h = svg_for(name, m)
        out["maps"][name] = {k: m[k] for k in ("lon0", "lon1", "lat0", "lat1", "w", "scale")} | {"h": round(h, 1)}
    for pid, (lat, lon, mp) in PINS.items():
        x, y, _ = proj(MAPS[mp], lon, lat)
        out["pins"][pid] = {"map": mp, "x": round(x / MAPS[mp]["w"], 4), "y": round(y / out["maps"][mp]["h"], 4)}
    json.dump(out, open("data/shared/map.json", "w"), indent=1)
    print("maps:", {k: (v["w"], v["h"]) for k, v in out["maps"].items()})


if __name__ == "__main__":
    main()
