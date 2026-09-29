# Museu de Fòssils

> Estat del projecte, com es treballa amb el Studio i què falta: @docs/ESTAT.md

## Joc
Roblox. Excaves fòssils amb un minijoc de precisió: cada excavació dona UN
fòssil (una peça d'un esquelet). Els guardes a la motxilla, els exposes al teu
museu (10 vitrines) i **comercies peces amb altres jugadors**. Si tens la sort
de reunir totes les peces d'un esquelet (de 5 a 8: com més rar, més peces), el
muntes i rendeix la suma de les peces x5. L'índex
(a part de la motxilla) apunta tot el que has descobert. El museu genera renda
passiva amb sostre.

## Loop
Excavar → minijoc → fòssil amb raresa → motxilla (i índex) → l'exposes → renda →
si et falta una peça d'un esquelet la comercies o segueixes excavant → muntes
l'esquelet (x5) → millor eina a Dig & Co. (més sort) → repeteixes.
Els fòssils que sobren es venen a la Bonnie (Fossil Buyer, al costat de
Dig & Co.): una peça val 4 minuts de la seva renda de museu.

## L'EIX DEL JOC: el comerç
7 rareses: Common, Uncommon, Rare, Epic, Legendary, Mythic, Secret. Cada
esquelet té UNA raresa i totes les seves peces també (5 a 8 peces:
Bones.luau `pieces`; les de més surten de partir-ne una de base: caixa
toràcica, pelvis, mandíbula o coll). A la Zona 1 hi ha un esquelet
per raresa (del Rat al T-Rex).
Dins d'una raresa, TOTES les peces són igual de probables, i entre esquelets de
la mateixa raresa també. Sense pietat: el que ja tens no fa més probable el que
et falta. Per això completar un esquelet alt sol és molt lent, i el comerç n'és
la drecera. Qualsevol canvi que faci que tothom completi sol mata el joc.
Els números es balancegen amb tools/economy_sim.py.

## ESTAT DELS FÒSSILS (30/09/2026, Bones.luau > ESTAT)
Cada fòssil surt amb un de 6 estats: Crushed x0,5 · Cracked x0,75 · Dusty x1
· Clean x1,25 · Polished x1,6 · Pristine x2,2 (renda i venda). Com més rara
la peça, més fàcil que surti malmesa; com millor la paleta (NOMÉS la sort de
la paleta: ni passis ni pocions), més neta. Mitjana: Common x1,18 (Rusty) →
x1,66 (Pharaoh's); Secret x0,81 → x1,18. Esquelet muntat = (suma de cada
peça x el seu estat) x5 x bonus de conjunt (+10% per estat de la peça
PITJOR: Crushed +0% … Pristine +50%). En muntar, el servidor tria la peça de
millor estat de cada. La clau porta l'estat: "Rat_Skull#4", "Rat#34425".
Els perfils vells passen a Dusty (migració v4). El minijoc no toca l'estat.

## Regla de zones
Cada esquelet és completable DINS de la seva zona. No reparteixis peces d'un
mateix conjunt entre zones — un jugador de zona 1 no pot comerciar amb un
d'Egipte (poder de compra asimètric, no hi ha intercanvi possible). Només els
esquelets de raresa molt alta poden tenir peces en més d'una zona.
Tres zones (29/09/2026): Obra (Rat → T-Rex), Platja (Seagull, Otter,
Cormorant) i **Egipte** (Ibis, Jackal, Camel, Crocodile: de Rare a Mythic).
Egipte és un desert lluny de tot: només s'hi arriba amb ✈️ Travel (mai
caminant) i es desbloqueja a la seva portalada, amb la platja ja oberta.

## Sort: paleta (x1 → x20) × passi de sort per Robux (x2 → x32). Sostre x640.
(29/09/2026: el propietari va pujar les paletes de x3 a x20; per compensar,
Legendary, Mythic i Secret tenen la N més alta.)
Rareses "1 de cada N" (Bones.RARITY_ODDS), la sort divideix la N de Rare cap
amunt: Secret 1/100.000 sense sort, ~1/5.000 amb la millor paleta (x20) i
~1/156 al sostre (x640). Mythic 1/20.000 → 1/1.000 → 1/31. Han de ser MOLT
rares encara amb la sort màxima.
La sort surt de la paleta × els passis de sort (i els boosts x2 temporals);
el minijoc només dona monedes. 11 paletes: 8 a Dig & Co. (x1, x1.5, x2, x3,
x4, x5.5, x7, x9) i 3 al basar d'Egipte, que demanen Egipte obert (x12, x15,
x20). Es talla el PRODUCTE a x640 (Constants.MAX_LUCK). Totes les eines són
paletes d'arqueòleg i NOMÉS donen sort (de raresa i, des del 30/09/2026, també
d'estat del fòssil): no toquen el minijoc ni la velocitat.

## Stack
Roblox Studio + Luau + Rojo. Els ossos es fan amb parts (Util/BoneBuilder:
el·lipsoides, ossos llargs, vèrtebres) i es veuen igual al museu i a la UI
(UI/PieceView). Cube 3D queda com a opció per al futur. Claude Code via MCP
(com treballar: docs/ESTAT.md).

## Estructura
src/server/Services/, src/client/Controllers/, src/client/UI/,
src/shared/Config/, src/shared/Remotes/, src/shared/Util/

## SEGURETAT — no negociable
1. Autoritat total al servidor. El client envia intenció, mai resultat.
   Únic matís: al minijoc el client diu QUAN ha clicat (contra el lag), i el
   servidor només s'ho creu dins ±0,07 s de la seva estimació amb el ping que
   mesura ell. El resultat (PERFECT/GOOD/MISS i la sort) el calcula el servidor.
2. Tot remote valida: jugador, permís, distància (quan l'acció és al món:
   excavar, comprar...), cooldown, tipus d'arguments. El comerç és amb tot
   el servidor, sense distància (ho vas demanar així).
3. Rate limit a tots els remotes.
4. Cap valor econòmic en objectes del Player. Tot a la sessió del servidor.
5. Es venen passis de sort per Robux (decisió del propietari). Res més aleatori.
6. **El trading és el codi més perillós del joc.** Escrow atòmic o res.

## DADES
Session-locking per perfil. Autosave 120s + PlayerRemoving + BindToClose.
pcall i retry a tot arreu. schemaVersion amb migracions.
Cap acció modifica el perfil abans que hagi carregat (`profileReady`).

## ESTIL
MÓN 3D: cases TRADICIONALS (no es toquen, agraden així); carrer, plaça,
platja, obra i museus MODERNS. Acollidor, no realista, amb molt de detall.
Plaça: l'ÚNICA botiga és Dig & Co. (res de parades). Forats d'excavació
de veritat (CSG), no boles. Models de la Toolbox: només triats a mà i
sempre sense scripts (tools/world/lib.luau → Asset).
Sorra #D9C7A0 · terra #8B6F47 · roca #6E6A63 · os #EDE3CC
Llautó #C08A3E · verd fosc #2F4A3C
UI: estil simulador, molt dopamínic. Colors vius (vermell, groc, verd, cian,
rosa, arc de Sant Martí), contorns negres gruixuts, lletra FredokaOne amb
contorn, botons grossos amb volum, rebots, números que salten, cartes de
raresa amb raigs i confeti. Tot l'estil de la UI viu a src/client/UI/Theme.luau.
Materials: Sand, Slate, WoodPlanks, Marble, Brick, Glass, Concrete, Metal,
SmoothPlastic, Ground, Grass, Limestone (els ossos). Neon només per a
efectes i llums.
Lighting Technology = "Future".

## ESCALES
Referència de tot: el jugador fa 5 studs d'alt.
Zona 1 (Obra): 60x60, amb cases al voltant · Tanca: 4 alt
Excavadora: 12–14 alt · Oficina de contenidors: 8x4x3 · Grua: 22 alt
Edifici en construcció: 24x18 d'ocupació
Museus: 70x52 · Botiga Dig & Co.: 24x14, a la plaça (racó nord-est)
Forat d'excavació: llosa de 8x8 (obra) o cràter de ~12 (platja i Egipte)
Egipte: desert fins a l'horitzó a x = 6000 (zona jugable de ±480 amb parets
invisibles; el mar del continent acaba a 1100 i entremig no hi ha res).
Excepció d'escala: les tres piràmides d'Egipte són GEGANTS (fins a 130 d'alt)
Cap element de decoració es fa fora d'aquest rang.
Dues cares paral·leles mai al mateix pla (fan pampallugues): deixar 0,05.
Res dins d'una altra peça que es vegi (arbres dins de cases, etc.).

## MONETITZACIÓ
Estil "+1 Speed Keyboard Escape": molts passis. Tot a src/shared/Config/Monetization.luau.
Sort en cadena (cal l'anterior): x2 4R → x4 12R → x8 29R → x16 59R → x32 99R
Diners en cadena, multiplica TOTES les monedes: x2 99R → x4 129R → x8 179R (màxim)
Boosts: Fast Dig 149 · Speed Boots 79 · x2 Offline 99 · 24h Offline 149 ·
x2 Sell 99 · VIP 249 (+20% monedes, etiqueta).
Productes repetibles: x2 diners 15 min / 1 h, paquets de monedes.
Els id de Roblox es posen a Monetization.luau quan es creen al Dashboard.

## RECOMPENSES GRATIS (Config/Rewards.luau)
Molt generoses (paquets de monedes + pocions + fòssil). Diària en ratxa de 7
(dia 7 = fòssil Legendary) · regals per estona de joc (2 a 60 min, cada
sessió) · invitacions (premi per a qui convida i qui entra, un
cop per amic, màx. 20). Like/preferits: MAI amb premi (normes de Roblox);
només es demana amablement després d'una troballa rara.

## POCIONS (Config/Potions.luau)
A la motxilla i a la barra de baix (HotbarController, en lloc de la de
Roblox). Luck (x2 sort), Money (x2 diners), Haste (excavar 2x més sovint),
Super (luck + money). Surten de recompenses, missions i, 1 de cada 100 cops,
en excavar. Allarguen el boost en temps. No es comercien ni es venen per Robux.

## ESDEVENIMENTS
Munt daurat: cada 4–7 min un munt a l'atzar brilla 2 min (x3 sort, x3
monedes i una Super Potion per al primer que el cava); s'avisa tot el
servidor. Les troballes Legendary, Mythic i Secret també s'anuncien.

## MISSIONS (Config/Quests.luau)
Una a la vegada, a dalt de la pantalla quan el tutorial s'acaba. El raig i la
fletxa es poden apagar (botó 🧭 GUIDE, es desa a la configuració). Vendre a
la Bonnie no és cap missió (és secundari). El progrés
surt del perfil (mai del client); el client només demana "claim". Premis en
minuts de renda, com les recompenses; mai fòssils (no han de ser farmejables
per passar-los a un altre compte).

## VISITANTS (Config/Visitors.luau)
Amics de tots els jugadors del servidor (tots igual de probables) visiten els
museus i de tant en tant deixen propina (💰 +X sobre el cap). El servidor
decideix les visites i les propines; el client només els dibuixa.

## FORA D'ABAST
PvP, robatori, treballadors NPC, quarta zona, guàrdies.

## IDIOMA
Tot el que veu el jugador (UI, missatges, rètols del mapa) en ANGLÈS.
Amb mi es parla en català.

## COM TREBALLAR
--!strict on es pugui. Codi en anglès, comentaris en català.
Config primer, lògica després. Si et demano una cosa que trenca aquest fitxer,
DIGUES-M'HO abans de fer-la.
