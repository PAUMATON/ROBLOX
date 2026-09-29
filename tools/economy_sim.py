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
  - sort = la del minijoc (fins a x1.5) x la de l'eina (fins a x2), sostre x3.
  - al museu (10 vitrines) hi posa sempre el que mes rendeix; munta un
    esquelet quan en te les 5 peces (rendeix x2).
  - compra l'eina seguent quan hi arriba i obre la platja quan pot.
"""
import random
import statistics
import sys

# ── copia de la config ──
RARITIES = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret"]
WEIGHTS = {"Common": 55, "Uncommon": 28, "Rare": 11, "Epic": 4.5, "Legendary": 1.2, "Mythic": 0.25, "Secret": 0.05}
LUCKY_FROM = "Rare"
PIECE_INCOME = {"Common": 60, "Uncommon": 120, "Rare": 240, "Epic": 600, "Legendary": 1500, "Mythic": 4200, "Secret": 12000}  # x60 (29/09/2026)
SKELETON_BONUS = 2
PIECES = ["Skull", "Spine", "ForeLimbs", "HindLimbs", "Tail"]
MAX_LUCK = 3
ZONES = {
    "construction": {"cost": 0, "coins": 180, "sk": {"Rat": "Common", "Pigeon": "Uncommon", "Cat": "Rare", "Dog": "Epic",
                                                   "Dodo": "Legendary", "Sabertooth": "Mythic", "TRex": "Secret"}},
    "beach": {"cost": 1500000, "coins": 480, "sk": {"Seagull": "Uncommon", "Otter": "Rare", "Cormorant": "Epic"}},
}
# (id, preu, sort)
TOOLS = [("rusty_shovel", 0, 1.0), ("steel_trowel", 45000, 1.5), ("field_pickaxe", 360000, 2.0),
         ("pro_brush", 2400000, 2.4), ("golden_shovel", 12000000, 2.7), ("sonic_drill", 54000000, 3.0)]
DIG_COOLDOWN = 1.2
MINIGAME_MAX_LUCK = 1
SLOTS, INCOME_CAP = 10, 360000
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


ODDS = {"Uncommon": 4, "Rare": 15, "Epic": 80, "Legendary": 600, "Mythic": 4000, "Secret": 25000}


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
    pool = [(s, p) for s, rr in ZONES[zone]["sk"].items() if rr == rarity for p in PIECES]
    return random.choice(pool)


def rarity_of(sk):
    for z in ZONES.values():
        if sk in z["sk"]:
            return z["sk"][sk]
    raise KeyError(sk)


# categories (valor, raresa, és_esquelet) ordenades de més a menys renda
CATS = sorted([(PIECE_INCOME[r] * (len(PIECES) * SKELETON_BONUS if sk else 1), r, sk)
               for r in RARITIES for sk in (True, False)], reverse=True)


def museum_income(piece_count, skel_count):
    left, total = SLOTS, 0
    for value, r, sk in CATS:
        n = min(left, (skel_count if sk else piece_count).get(r, 0))
        total += n * value
        left -= n
        if left == 0:
            break
    return min(total, INCOME_CAP)


def play(max_minutes=2400):
    t = 0.0
    coins = 6000.0
    tool = 0
    zones = ["construction"]
    zone = "construction"
    bones = {}
    piece_count, skel_count = {}, {}
    events = {}
    income = 0
    while t < max_minutes * 60:
        _, _, tool_luck = TOOLS[tool]
        dt = DIG_COOLDOWN + MINIGAME_S + WALK_S
        t += dt
        coins += income * dt / 60
        bonus = sum(click_bonus() for _ in range(ATTEMPTS))
        coins += int(ZONES[zone]["coins"] * (1 + bonus / 100))
        sk, piece = roll(zone, luck_of(bonus, tool_luck))
        bones[(sk, piece)] = bones.get((sk, piece), 0) + 1
        rarity = rarity_of(sk)
        events.setdefault(f"1a peça {rarity}", t)
        # venda (Fossil Buyer): les repetides fins a Rare es venen; la resta es guarda
        if SELL and bones[(sk, piece)] > 1 and RARITIES.index(rarity) <= RARITIES.index("Rare"):
            bones[(sk, piece)] -= 1
            coins += PIECE_INCOME[rarity] * SELL_MINUTES
            continue_sell = True
        else:
            piece_count[rarity] = piece_count.get(rarity, 0) + 1
        # munta tot el que es pugui
        if all(bones.get((sk, p), 0) > 0 for p in PIECES):
            for p in PIECES:
                bones[(sk, p)] -= 1
            piece_count[rarity] -= len(PIECES)
            skel_count[rarity] = skel_count.get(rarity, 0) + 1
            events.setdefault(f"esquelet {rarity} muntat", t)
        income = museum_income(piece_count, skel_count)
        for milestone in (3000, 12000, 60000, INCOME_CAP):
            if income >= milestone:
                events.setdefault(f"renda >= {milestone}/min", t)
        # compres
        if tool + 1 < len(TOOLS) and coins >= TOOLS[tool + 1][1]:
            coins -= TOOLS[tool + 1][1]
            tool += 1
            events.setdefault(f"eina {TOOLS[tool][0]}", t)
        if "beach" not in zones and coins >= ZONES["beach"]["cost"]:
            coins -= ZONES["beach"]["cost"]
            zones.append("beach")
            events.setdefault("obre la Platja", t)
        # alterna zona: la platja no té Common però tampoc Legendary+
        zone = "beach" if ("beach" in zones and random.random() < 0.35) else "construction"
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
