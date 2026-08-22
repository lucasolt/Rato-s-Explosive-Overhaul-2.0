# -*- coding: utf-8 -*-
"""Modelo do sistema de estilhacos do Rato's Explosive Overhaul 2.0.
Replica FUNCTIONS_Shrapnel*.lua. Vetores enumerados exatamente como no Lua (Fibonacci deterministico).
"""
import math

PHI_GOLD = (1 + math.sqrt(5)) / 2
RADIUS = 13000          # comprimento do raio, unidades de mundo
SHRAP_DMG = 9           # weapon_shrapnel.Damage
BIAS_CUT, BIAS_HI, BIAS_LO = 1.4, 0.65, 2.5   # phi >= 1.4 -> *0.65 ; senao *2.5

FRAG_ARGS = {
    "High":     dict(diminish=2, ceiling=5, step=0.5,  maxpen=0.95),
    "Medium":   dict(diminish=1, ceiling=3, step=0.75, maxpen=0.95),
    "Low":      dict(diminish=1, ceiling=2, step=0.8,  maxpen=0.95),
    "Very Low": dict(diminish=1, ceiling=1, step=1.0,  maxpen=1.0),   # fallback
    "None":     dict(diminish=1, ceiling=1, step=1.0,  maxpen=1.0),
}

def frag_level(num):
    if not num:            return "None"
    if num > 630:          return "High"
    if num > 280:          return "Medium"
    if num > 200:          return "Low"
    if num > 0:            return "Very Low"
    return "None"

def vectors(n, cut=BIAS_CUT, hi=BIAS_HI, lo=BIAS_LO):
    """Espelha generateShrapnelVectors: devolve (x, y, z) unitarios."""
    out = []
    for i in range(1, n + 1):
        theta = 2 * math.pi * (i - 1) / PHI_GOLD
        phi = math.acos(-1 + 2 * (i - 0.5) / n)
        phi = phi * hi if phi >= cut else phi * lo
        out.append((math.sin(phi) * math.cos(theta),
                    math.sin(phi) * math.sin(theta),
                    math.cos(phi)))
    return out

def survivors(n, **kw):
    """generateShrapnelPositions descarta tudo com z <= centro."""
    return [v for v in vectors(n, **kw) if v[2] * RADIUS > 0]

def elevation_deg(v):
    """angulo acima do horizonte, em graus."""
    return math.degrees(math.atan2(v[2], math.hypot(v[0], v[1])))

# ---------------- multiplicadores de dano por ordem de acerto ----------------
def hit_multipliers(level):
    """Lista dos multiplicadores aplicados ao 1o, 2o, ... acerto no MESMO alvo."""
    a = FRAG_ARGS[level]
    muls, received = [], 0
    while received < a["ceiling"]:
        if received >= a["diminish"]:
            red = min(a["maxpen"], (received - a["diminish"]) * a["step"])
        else:
            red = 0.0
        muls.append(1.0 - red)
        received += 1
    return muls

def zone_factor(dist_tiles, aoe, radius_mul=2.0, secondary=88, outer=30):
    """dist_t: 100 dentro do AoE, 88 ate AoE*radius_mul, 30 alem."""
    if dist_tiles <= aoe:                    return 100
    if dist_tiles <= round(aoe * radius_mul): return secondary
    return outer

# ---------------- geometria do acerto ----------------
UNIT_H = 1.8      # altura do alvo, metros
UNIT_W = 0.6      # largura do alvo, metros

def expected_hits(surv, n_total, dist_m, unit_h=UNIT_H, unit_w=UNIT_W):
    """Raios que interceptam um alvo em pe a dist_m metros do centro da explosao.
    Janela de azimute ~ w/d; janela de elevacao 0..atan(h/d)."""
    if dist_m <= 0: return len(surv)
    a_max = math.atan2(unit_h, dist_m)
    p_az = min(1.0, 2 * math.atan2(unit_w / 2, dist_m) / (2 * math.pi))
    in_band = sum(1 for v in surv if 0 <= math.atan2(v[2], math.hypot(v[0], v[1])) <= a_max)
    return in_band * p_az

def expected_damage(n_shrap, dist_m, aoe_tiles, tile_m=1.0, level=None,
                    dmg_opt=100, num_opt=100, radius_mul=2.0, secondary=88, outer=30,
                    **bias):
    lvl = level or frag_level(n_shrap)
    n_rays = round(n_shrap * num_opt / 100)          # MulDivRound(num, opt, 100)
    surv = survivors(n_rays, **bias) if n_rays else []
    hits = expected_hits(surv, n_rays, dist_m)
    muls = hit_multipliers(lvl)
    eff = sum(muls[:int(hits)]) + (muls[int(hits)] * (hits - int(hits))
                                   if int(hits) < len(muls) else 0)
    base = round(SHRAP_DMG * dmg_opt / 100)
    zf = zone_factor(dist_m / tile_m, aoe_tiles, radius_mul, secondary, outer)
    return dict(level=lvl, rays=n_rays, survivors=len(surv), hits=hits,
                eff_hits=eff, damage=eff * base * zf / 100, zone=zf,
                cap=sum(muls) * base * zf / 100, ceiling=len(muls))


# ---------------- CLI ----------------
ITEMS = [("HE_Grenade", 700, 3), ("NailBomb_IED", 680, 3), ("HE_Grenade_1", 350, 3),
         ("FragGrenade", 300, 3), ("TNTBolt_IED", 300, 3), ("PipeBomb", 240, 3),
         ("C4 / PETN / TNT", 75, 3)]

if __name__ == "__main__":
    print("Filtro z > centro: quanto de cada explosivo chega a virar um CheckLOF\n")
    print("%-16s %-5s %-9s %-8s %-9s %-8s %s" % (
        "explosivo", "num", "tier", "teto", "raios", "acertos", "dano @2t / max"))
    for name, num, aoe in ITEMS:
        r = expected_damage(num, 2, aoe)
        print("%-16s %-5d %-9s %-8d %-9d %-8.2f %.1f / %.1f" % (
            name, num, r["level"], r["ceiling"], r["survivors"], r["hits"],
            r["damage"], r["cap"]))

    print("\nMultiplicadores por ordem de acerto no mesmo alvo")
    for lvl in ("High", "Medium", "Low", "Very Low"):
        m = hit_multipliers(lvl)
        print("  %-9s %-28s soma %.2f -> teto %.0f de dano" % (
            lvl, "[" + ", ".join("%.2f" % x for x in m) + "]", sum(m), sum(m) * SHRAP_DMG))

    print("\nA escada: dano a 2 tiles varrendo r_shrap_num")
    prev = None
    for n in (150, 200, 201, 280, 281, 400, 630, 631, 700, 1000):
        r = expected_damage(n, 2, 3)
        step = "  <-- degrau" if prev is not None and abs(r["damage"] - prev) > 0.5 else ""
        print("  %4d  %-9s dano %5.1f%s" % (n, r["level"], r["damage"], step))
        prev = r["damage"]
