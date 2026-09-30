"""Simulador de l'economia: quant es triga a cada fita, jugant SOL (sense comerç).

Us:
    python tools/economy_sim.py            # 1500 partides
    python tools/economy_sim.py 5000

Els numeros son copia de src/shared/Config (Bones, Dig, Zones, Tools, Museum).
Si en canvies algun alla, canvia'l aqui tambe (a dalt de tot, tot junt).

Model del jugador (mitja):
  - cada excavacio triga: cooldown (1.2 s) + ~2.5 s de minijoc + ~3.5 s de
    caminar fins al munt seguent (els munts es buiden 20 s).
  - cada clic: 30% perfecte, 40% be, 30% fallat (l'eina no hi fa res).
  - sort = la de la paleta (x1 .. x20; el minijoc ja no en dona), sense passis.
  - al museu (10 vitrines) hi posa sempre el que mes rendeix; munta un
    esquelet quan en te les 5 peces (rendeix x2).
  - compra l'eina seguent quan hi arriba i obre la platja quan pot.
"""
import math
import random
import statistics
import sys

# ── copia de la config ──
RARITIES = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret"]
WEIGHTS = {"Common": 55, "Uncommon": 28, "Rare": 11, "Epic": 4.5, "Legendary": 1.2, "Mythic": 0.25, "Secret": 0.05}
LUCKY_FROM = "Rare"
PIECE_INCOME = {"Common": 60, "Uncommon": 120, "Rare": 240, "Epic": 600, "Legendary": 1500, "Mythic": 4200, "Secret": 12000}  # x60 (29/09/2026)
SKELETON_BONUS = 5  # 29/09/2026: el muntat rendeix la suma de les peces x5

# Estat dels fòssils (Bones.luau > ESTAT): Crushed … Mint, Pristine
GRADE_MULT = [0.5, 0.7, 1.0, 1.4, 1.9, 3.2, 6.0]
GRADE_WEIGHT = [10, 18, 30, 20, 12, 7, 3]
GRADE_TILT_TOOL, GRADE_TILT_RARITY, GRADE_TILT_BASE, GRADE_TOOL_TOP = 0.8, 0.8, 0.1, 20
SET_BONUS_STEP = 0.1  # bonus de conjunt: +10% per estat de la peça pitjor
NOGRADE = "--nograde" in sys.argv  # com abans: tot Dusty i sense bonus de conjunt


def roll_grade(rarity, tool_luck):
    """1..7, com Bones.RollGrade (només la sort de la paleta)"""
    if NOGRADE:
        return 3
    t = min(max(math.log(max(1, tool_luck)) / math.log(GRADE_TOOL_TOP), 0), 1)
    r = RARITIES.index(rarity) / (len(RARITIES) - 1)
    tilt = GRADE_TILT_TOOL * t - GRADE_TILT_RARITY * r + GRADE_TILT_BASE
    c = (len(GRADE_WEIGHT) - 1) / 2
    w = [b * math.exp(tilt * (i - c)) for i, b in enumerate(GRADE_WEIGHT)]
    return random.choices(range(1, len(GRADE_WEIGHT) + 1), weights=w)[0]


def skeleton_value(rarity, grades):
    bonus = 1 if NOGRADE else 1 + SET_BONUS_STEP * (min(grades) - 1)
    return sum(PIECE_INCOME[rarity] * GRADE_MULT[g - 1] for g in grades) * SKELETON_BONUS * bonus
PIECES = ["Skull", "Spine", "ForeLimbs", "HindLimbs", "Tail", "Ribs", "Pelvis", "Extra"]
# quantes peces té cada esquelet (Bones.luau: `pieces`)
PIECES_OF = {"Rat": 5, "Pigeon": 5, "Cat": 6, "Dog": 6, "Dodo": 7, "Sabertooth": 8, "TRex": 8,
             "Seagull": 5, "Otter": 6, "Cormorant": 7, "Ibis": 6, "Jackal": 7, "Camel": 7, "Crocodile": 8}
MAX_LUCK = 20  # la millor paleta (sense passis de Robux)
ZONES = {
    "construction": {"cost": 0, "coins": 270, "sk": {"Rat": "Common", "Pigeon": "Uncommon", "Cat": "Rare", "Dog": "Epic",
                                                   "Dodo": "Legendary", "Sabertooth": "Mythic", "TRex": "Secret"}},
    "beach": {"cost": 320000, "coins": 720, "sk": {"Seagull": "Uncommon", "Otter": "Rare", "Cormorant": "Epic"}},
    # illa (només en avió), demana la platja
    "egypt": {"cost": 3200000, "coins": 3600, "sk": {"Ibis": "Rare", "Jackal": "Epic", "Camel": "Legendary", "Crocodile": "Mythic"}},
}
# (id, preu, sort, zona que cal tenir oberta)
TOOLS = [("rusty_shovel", 0, 1.0, None), ("steel_trowel", 9000, 1.5, None), ("bronze_trowel", 33000, 2, None),
         ("field_pickaxe", 80000, 3, None), ("pro_brush", 240000, 4, None), ("emerald_trowel", 650000, 5.5, None),
         ("golden_shovel", 1700000, 7, None), ("sonic_drill", 4200000, 9, None),
         ("scarab_trowel", 10000000, 12, "egypt"), ("anubis_trowel", 22000000, 15, "egypt"),
         ("pharaoh_trowel", 45000000, 20, "egypt")]
DIG_COOLDOWN = 1.2
MINIGAME_MAX_LUCK = 1
SLOTS, INCOME_CAP = 10, float("inf")  # 30/09/2026: sense sostre (decisió del propietari)
SELL_MINUTES = 4
SELL = "--nosell" not in sys.argv
PERFECT_BONUS, GOOD_BONUS, ATTEMPTS = 50, 30, 3
BASE_P_PERFECT, BASE_P_GOOD = 0.30, 0.40
MINIGAME_S, WALK_S = 2.5, 3.5


def click_bonus():
    r = random.random()
    return PERFECT_BONUS if r < BASE_P_PERFECT else (GOOD_BONUS if r < BASE_P_PERFECT + BASE_P_GOOD else 0)


def luck_of(bonus, tool_luck):
    minigame = 1 + bonus / (ATTEMPTS * PERFECT_BONUS) * (MINIGAME_MAX_LUCK - 1)
    return min(max(minigame * tool_luck, 1), MAX_LUCK)


ODDS = {"Uncommon": 4, "Rare": 15, "Epic": 80, "Legendary": 1500, "Mythic": 20000, "Secret": 100000}


def roll(zone, luck):
    # 1 de cada N (N/sort de Rare cap amunt), de la més rara cap avall
    present = set(ZONES[zone]["sk"].values())
    rarity = None
    for r in reversed(RARITIES[1:]):
        if r in present:
            l = luck if RARITIES.index(r) >= RARITIES.index(LUCKY_FROM) else 1
            if random.random() < min(l / ODDS[r], 0.9):
                rarity = r
                break
    if rarity is None:
        rarity = min(present, key=RARITIES.index)
    # totes les peces d'aquesta raresa a la zona, igual de probables
    pool = [(s, p) for s, rr in ZONES[zone]["sk"].items() if rr == rarity for p in PIECES[:PIECES_OF[s]]]
    return random.choice(pool)


def rarity_of(sk):
    for z in ZONES.values():
        if sk in z["sk"]:
            return z["sk"][sk]
    raise KeyError(sk)


def museum_income(loose, skels):
    """loose: renda d'una peça solta -> quantes; skels: rendes dels esquelets
    muntats. Les 10 vitrines s'omplen amb el que més rendeix."""
    items = sorted(skels, reverse=True)[:SLOTS]
    for v in sorted(loose, reverse=True):
        if len(items) >= SLOTS and v <= min(items):
            break
        items += [v] * min(loose[v], SLOTS)
    items.sort(reverse=True)
    return min(sum(items[:SLOTS]), INCOME_CAP)


def play(max_minutes=2400):
    t = 0.0
    coins = 6000.0
    tool = 0
    zones = ["construction"]
    zone = "construction"
    bones = {}  # (esquelet, peça) -> llista d'estats
    loose, skels = {}, []  # renda de peça solta -> quantes · rendes dels esquelets
    events = {}
    income = 0
    while t < max_minutes * 60:
        tool_luck = TOOLS[tool][2]
        dt = DIG_COOLDOWN + MINIGAME_S + WALK_S
        t += dt
        coins += income * dt / 60
        bonus = sum(click_bonus() for _ in range(ATTEMPTS))
        coins += int(ZONES[zone]["coins"] * (1 + bonus / 100))
        sk, piece = roll(zone, luck_of(bonus, tool_luck))
        rarity = rarity_of(sk)
        grade = roll_grade(rarity, tool_luck)
        value = PIECE_INCOME[rarity] * GRADE_MULT[grade - 1]
        events.setdefault(f"1a peça {rarity}", t)
        have = bones.setdefault((sk, piece), [])
        # venda (Fossil Buyer): les repetides fins a Rare es venen (la pitjor); la resta es guarda
        if SELL and have and RARITIES.index(rarity) <= RARITIES.index("Rare"):
            worst = min(have + [grade])
            if worst != grade:
                have.remove(worst)
                have.append(grade)
                loose[PIECE_INCOME[rarity] * GRADE_MULT[worst - 1]] -= 1
                loose[value] = loose.get(value, 0) + 1
            coins += PIECE_INCOME[rarity] * GRADE_MULT[worst - 1] * SELL_MINUTES
        else:
            have.append(grade)
            loose[value] = loose.get(value, 0) + 1
        # munta tot el que es pugui (amb la millor peça de cada)
        mine = PIECES[:PIECES_OF[sk]]
        if all(bones.get((sk, p)) for p in mine):
            grades = []
            for p in mine:
                g = max(bones[(sk, p)])
                bones[(sk, p)].remove(g)
                loose[PIECE_INCOME[rarity] * GRADE_MULT[g - 1]] -= 1
                grades.append(g)
            skels.append(skeleton_value(rarity, grades))
            events.setdefault(f"esquelet {rarity} muntat", t)
        income = museum_income({v: n for v, n in loose.items() if n > 0}, skels)
        for milestone in (3000, 12000, 60000, 360000, 720000, 3600000):
            if income >= milestone:
                events.setdefault(f"renda >= {milestone}/min", t)
        # compres
        if tool + 1 < len(TOOLS) and coins >= TOOLS[tool + 1][1] and (TOOLS[tool + 1][3] is None or TOOLS[tool + 1][3] in zones):
            coins -= TOOLS[tool + 1][1]
            tool += 1
            events.setdefault(f"eina {TOOLS[tool][0]}", t)
        if "beach" not in zones and coins >= ZONES["beach"]["cost"]:
            coins -= ZONES["beach"]["cost"]
            zones.append("beach")
            events.setdefault("obre la Platja", t)
        elif "beach" in zones and "egypt" not in zones and coins >= ZONES["egypt"]["cost"]:
            coins -= ZONES["egypt"]["cost"]
            zones.append("egypt")
            events.setdefault("obre Egipte", t)
        # alterna zona: la platja no té Common però tampoc Legendary+;
        # a Egipte (Rare → Mythic) hi va sobretot, però el T-Rex és a l'obra
        r = random.random()
        if "egypt" in zones:
            zone = "egypt" if r < 0.6 else ("construction" if r < 0.85 else "beach")
        else:
            zone = "beach" if ("beach" in zones and r < 0.35) else "construction"
    return events


def main():
    nums = [a for a in sys.argv[1:] if a.isdigit()]
    runs = int(nums[0]) if nums else 1500
    random.seed(7)
    all_events = {}
    for _ in range(runs):
        for k, v in play().items():
            all_events.setdefault(k, []).append(v / 60)
    print(f"{runs} partides, jugant sol (sense comerç), fins a 40 h\n")
    print(f"{'fita':30s} {'mediana':>9s} {'p10':>8s} {'p90':>8s}  {'hi arriben':>10s}")
    for k, vals in sorted(all_events.items(), key=lambda kv: statistics.median(kv[1])):
        vals.sort()
        p10 = vals[int(len(vals) * 0.1)]
        p90 = vals[min(len(vals) - 1, int(len(vals) * 0.9))]
        fmt = lambda m: f"{m:7.1f}m" if m < 120 else f"{m / 60:7.1f}h"
        print(f"{k:30s} {fmt(statistics.median(vals)):>9s} {fmt(p10):>8s} {fmt(p90):>8s}  {100 * len(vals) / runs:9.0f}%")


if __name__ == "__main__":
    main()
