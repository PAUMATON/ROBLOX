# Museu de Fòssils — LLISTA PER LLANÇAR-LO

Tot el que falta per posar el joc al mercat, per ordre. El que hi ha al
codi ja està fet; això són passos del **Creator Dashboard**
(create.roblox.com → Creations → el teu joc) que només pots fer tu.

---

## 1. La qualificació d'edat (per què en Luca i tu no hi podeu entrar)

Un joc nou surt **sense qualificació**, i Roblox el tanca per a la gent
jove fins que respons el qüestionari. Per això us sortia "16+". No ho canvia
cap moderador: ho canvies tu responent-lo.

1. Creator Dashboard → el joc → **Audience → Maturity & Compliance**
   (o "Experience Questionnaire").
2. Respon amb sinceritat. Per a aquest joc:
   - Violència, sang, por, llenguatge groller, drogues, apostes: **no**.
   - Compres amb Robux: **sí** (passis i productes).
   - Xat de text i **comerç entre jugadors**: sí.
   - Articles aleatoris de pagament ("paid random items"): **no**. Excavar
     és gratis; els passis de sort no donen cap objecte, i les
     probabilitats es veuen a l'Índex (🎲).
3. Hauria de sortir **Minimal** o **Mild**, i llavors hi pot entrar
   tothom (també menors de 13).

## 2. Nom, descripció i configuració

**Nom** (ara és "Experiencia sin título"). Amb "Simulator" es troba més:
- `Fossil Museum Simulator 🦖` (recomanat)
- `Dig & Display: Fossil Museum`

**Descripció** (per enganxar, en anglès):

```
🦴 Dig up fossils, build your own museum and trade with friends!

⛏️ DIG at the construction site and on Fossil Beach — every dig is a skill minigame
🦖 FIND 7 rarities, from Common rats to the SECRET T-Rex
🏛️ SHOW your fossils in your museum and earn coins, even while you're offline
🔨 BUILD complete skeletons for DOUBLE income
🤝 TRADE pieces with other players to finish your skeletons faster
🛠️ UPGRADE your trowel for more luck
📜 QUESTS, daily rewards and playtime gifts

👍 Like the game and add it to your favorites to follow the updates!
```

**Configuració** (Places → Configure / Settings):
- Gènere: **Simulation**.
- Dispositius: **Computer, Phone, Tablet**. La consola, encara no (no s'ha
  provat amb comandament).
- Jugadors per servidor: **12–16** (perquè hi hagi gent per comerciar).
- Permisos: **Public** quan ho vulguis obrir.

## 3. Icona i miniatures

- **Icona** (512×512): gran i clara. Un crani de T-Rex amb una paleta, sobre
  un fons de color viu. Poc text o cap.
- **Miniatures** (1920×1080, 3–5): l'obra excavant, un museu ple
  d'esquelets, la carta d'un Secret amb els raigs, la finestra de comerç.
  Es poden fer al Studio amb el joc en marxa: amaga la UI si cal i fes
  captures de pantalla.

## 4. Robux (quan vulguis)

Crear cada passi a **Monetization → Passes** i cada producte a
**Developer Products**, amb el mateix nom i preu, i posar-ne l'`id` a
`src/shared/Config/Monetization.luau` (ara tots són 0 i no es poden comprar).

| clau | nom | preu R$ | tipus |
|---|---|---|---|
| luck2 | x2 Luck | 4 | passi |
| luck4 | x4 Luck | 12 | passi |
| luck8 | x8 Luck | 29 | passi |
| luck16 | x16 Luck | 59 | passi |
| luck32 | x32 Luck | 99 | passi |
| money2 | x2 Money | 99 | passi |
| money4 | x4 Money | 129 | passi |
| money8 | x8 Money | 179 | passi |
| fastDig | Fast Dig | 149 | passi |
| speed | Speed Boots | 79 | passi |
| offline2 | x2 Offline Income | 99 | passi |
| offline24 | 24h Offline | 149 | passi |
| sell2 | x2 Sell Price | 99 | passi |
| vip | VIP | 249 | passi |
| boost15 | x2 Money · 15 min | 29 | producte |
| boost60 | x2 Money · 1 hour | 79 | producte |
| coinsS | Pile of Coins | 25 | producte |
| coinsM | Bag of Coins | 99 | producte |
| coinsL | Vault of Coins | 399 | producte |

## 5. Abans de publicar (al Studio)

1. Surt del joc publicat (si hi ets dins, el Studio no pot obrir el teu
   perfil i t'expulsa).
2. Codi: `STUDIO_ID=<id> python tools/sync_src.py`.
3. Món: `STUDIO_ID=<id> python tools/world/run.py` (el refà sencer; ara
   inclou els indicadors de les cruïlles, `10_signs`).
4. Prova ràpida: **Test → Clients and Servers → 2 jugadors**. Fes un
   canvi entre tots dos (a Studio no cal la mitja hora de joc).
5. Prova el mòbil: **Test → Device** (un mòbil apaïsat) i mira que res
   no tapi el joystick ni el botó de saltar.
6. **File → Publish to Roblox**.

## 6. Els primers dies

- Passa-li a en Luca perquè ho provi (ell ja s'hi ha ofert).
- Mira **Analytics**: quanta estona es queda la gent (session time) i
  quants tornen l'endemà (D1 retention). Si surten bé, llavors val la
  pena posar-hi una mica d'anuncis (Ads Manager), que és quan rendeixen.
- Actualitza el joc sovint al principi: l'algorisme de Roblox ho premia.
