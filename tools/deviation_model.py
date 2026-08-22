# -*- coding: utf-8 -*-
"""Modelo exato do deviation de granadas do Rato's Explosive Overhaul 2.0.
Replica FUNCTIONS_DeviateGrenade.lua (v1.21). Distribuicao EXATA (enumeracao), sem Monte Carlo.
"""
from collections import Counter
from math import cos, radians, sqrt

# ---------------- parametros do Lua ----------------
P = dict(
    base_skill_modifier=6,
    GR_dist_pen=18,
    magnitude_effect=100,
    potent=2,
    num_dice=2,
    stat_factor_perfect_throw=20,
    critical_roll_threshold=0,
    def_min_dev=0.0,
    perfect_throw_threshold=0.0,
    great_throw_threshold=0.75,
    dev_thrs_innac_throw=2.0,
    terrible=3.2,
    base_gr_rotation_factor=20.0,
    accurate_angle_mul=0.85,
    grenade_length_factor=0.1,
)

def cround(x):
    return int(x + 0.5) if x >= 0 else -int(-x + 0.5)

def roll_pmf(num_dice=2, max_value=100):
    """throw_dice: soma de num_dice x InteractionRand(max/num) , +1."""
    face = max_value // num_dice           # MulDivRound(100,1,n)
    cur = Counter({0: 1})
    for _ in range(num_dice):
        nxt = Counter()
        for s, c in cur.items():
            for f in range(face):          # InteractionRand(face) -> 0..face-1
                nxt[s + f] += c
        cur = nxt
    tot = sum(cur.values())
    return {k + 1: v / tot for k, v in sorted(cur.items())}

def uniform_pmf():
    return {k: 1/100 for k in range(1, 101)}

# ---------------- stat pipeline ----------------
def stat_mishap(dex=80, expl=70, opt="avg", throwing_perk=False, shape_acc=0,
                dist_tiles=10, max_range_tiles=15, opt_diff=0, wounds=0,
                inaccurate=False, blind=False, rain=False):
    if opt == "dex":
        s = dex
    elif opt == "expl":
        s = expl
    else:
        s = cround((dex + expl) // 2)      # Lua 5.3: '/' e divisao inteira
    if throwing_perk:
        s += 10
    s = max(45, s)
    ratio = dist_tiles / max_range_tiles
    diff_dist = cround(ratio * P["GR_dist_pen"])
    wound_pen = wounds * 5
    mods = -shape_acc + opt_diff + diff_dist + wound_pen
    if inaccurate: mods += 15
    if blind:      mods += 15
    if rain:       mods += 10
    return max(0, s - mods), wound_pen

def deviation(roll, stat_m, wound_pen=0, ai_mod=0, p=P, wound_bug=True):
    perfect_gate = p["critical_roll_threshold"] + stat_m / 100.0 * p["stat_factor_perfect_throw"]
    st = stat_m + p["base_skill_modifier"] - ai_mod + (wound_pen if wound_bug else -0)
    if roll <= perfect_gate:
        return 0.0
    diff = st - roll
    min_dev = 0.0 if diff >= 50 else p["def_min_dev"]
    return max(min_dev, ((p["magnitude_effect"] - diff) ** p["potent"]) /
               (p["magnitude_effect"] ** p["potent"]) * 2)

# ---------------- geometria ----------------
def miss_tiles(dev, L_tiles, clamp_bug=True, p=P):
    """Retorna [(erro_em_tiles, peso)] sobre os 2 sinais de distancia."""
    if dev <= p["perfect_throw_threshold"]:
        return [(0.0, 1.0)]
    rot = p["base_gr_rotation_factor"]
    if dev <= p["great_throw_threshold"]:
        rot *= p["accurate_angle_mul"]
    th = radians(rot * dev / 5.0)          # rot*60*dev/5 em unidades de 1/60 grau
    out = []
    for s2 in (1, -1):
        m = p["grenade_length_factor"] * dev * s2
        if clamp_bug and s2 > 0:
            m = -m                          # clamp de unidades quebrado -> sempre encurta
        r = 1.0 + m
        out.append((L_tiles * sqrt(r * r + 1 - 2 * r * cos(th)), 0.5))
    return out

def label(dev, p=P):
    if dev <= p["perfect_throw_threshold"]: return "Perfect"
    if dev <= p["great_throw_threshold"]:   return "Great"
    if dev >= p["terrible"]:                 return "Terrible"
    if dev >= p["dev_thrs_innac_throw"]:     return "Inaccurate"
    return "(sem label)"

# ---------------- agregacao ----------------
def analyse(stat_m, L_tiles, wound_pen=0, ai_mod=0, pmf=None, clamp_bug=True,
            p=P, wound_bug=True):
    pmf = pmf or roll_pmf(p["num_dice"])
    bands = Counter(); devs = []; errs = []
    for roll, pr in pmf.items():
        d = deviation(roll, stat_m, wound_pen, ai_mod, p, wound_bug)
        bands[label(d, p)] += pr
        devs.append((d, pr))
        for e, w in miss_tiles(d, L_tiles, clamp_bug, p):
            errs.append((e, pr * w))
    errs.sort()
    def q(x):
        acc = 0
        for e, w in errs:
            acc += w
            if acc >= x: return e
        return errs[-1][0]
    tot = sum(w for _, w in errs)
    mean = sum(e * w for e, w in errs) / tot
    within = lambda t: sum(w for e, w in errs if e <= t) / tot
    return dict(bands=dict(bands), p50=q(.5), p90=q(.9), p99=q(.99), max=errs[-1][0],
                mean=mean, w1=within(1), w2=within(2), w3=within(3), w4=within(4),
                devs=devs, errs=errs)


# ---------------- CLI ----------------
if __name__ == "__main__":
    MR = 15                       # alcance maximo em tiles (frag, Strength ~80)
    print("Erro do arremesso em tiles — granada 'Can' (-3), sem perk, alcance %dt\n" % MR)
    hdr = "%-9s %-5s | %-7s %-7s %-7s %-7s %-7s | %6s %6s %6s"
    print(hdr % ("dex=expl", "dist", "Perfect", "Great", "(mudo)", "Inacc", "Terr",
                 "p50", "p90", "<=2t"))
    for base in (50, 65, 80, 95):
        for dist in (3, 6, 10, 15):
            sm, _ = stat_mishap(dex=base, expl=base, dist_tiles=dist,
                                max_range_tiles=MR, shape_acc=-3)
            a = analyse(sm, dist)
            b = a["bands"]
            print(hdr % ("%d (ui %d)" % (base, sm), "%dt" % dist,
                         "%.1f%%" % (100 * b.get("Perfect", 0)),
                         "%.1f%%" % (100 * b.get("Great", 0)),
                         "%.1f%%" % (100 * b.get("(sem label)", 0)),
                         "%.1f%%" % (100 * b.get("Inaccurate", 0)),
                         "%.1f%%" % (100 * b.get("Terrible", 0)),
                         "%.2f" % a["p50"], "%.2f" % a["p90"],
                         "%.0f%%" % (100 * a["w2"])))
        print()
