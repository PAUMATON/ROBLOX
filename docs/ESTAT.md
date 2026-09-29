# Museu de Fòssils — ESTAT DEL PROJECTE

Document de context per a qualsevol sessió nova de Claude Code. Les REGLES
del joc són a `CLAUDE.md`; aquí hi ha QUÈ hi ha fet, COM es treballa i QUÈ falta.
Última actualització: 29/09/2026 (revisió al núvol, sense Studio).

---

## 1. Qui és el propietari i com vol treballar

- Parla en **català** (sempre respondre-li en català). Tot el que veu el
  jugador, en **anglès**.
- Vol veure el resultat: després de cada canvi al món 3D, **fer captures**
  (també de llocs a l'atzar) i arreglar el que es vegi malament abans de dir
  que està fet.
- Gustos: cases tradicionals (no tocar-les); plaça, platja, obra i museus
  moderns i amb molt de detall; UI de simulador molt dopamínica; botiga
  estil Fisch; totes les eines són paletes d'arqueòleg i NOMÉS donen sort.
- Si una petició trenca `CLAUDE.md`, dir-li-ho abans de fer-la.
- Vol llançar el joc aviat i guanyar diners; li agrada que se li parli clar
  sobre les probabilitats d'èxit.

## 2. El joc, en una línia per sistema

| Sistema | On és | Resum |
|---|---|---|
| Excavar | `DigService`, `DigController`, `Config/Dig` | Minijoc de 3 cops: la franja verda salta a cada cop i la línia va més ràpid. El client diu quan ha clicat (±0,07 s de marge); el servidor calcula el resultat. |
| Fòssils | `Config/Bones`, `Util/BoneBuilder` | 14 esquelets × 5 peces = 70 (els 4 d'Egipte, 29/09/2026). 7 rareses "1 de cada N" (Secret 1/25.000). Models fets amb parts (el·lipsoides, ossos llargs, vèrtebres...). |
| Zones | `Config/Zones` | Obra (gratis, Rat → T-Rex), Platja (750.000, Seagull/Otter/Cormorant) i **Egipte** (8.000.000 i cal la platja; Ibis Rare, Jackal Epic, Camel Legendary, Crocodile Mythic). Egipte és una illa a x = 2000 (`tools/world/11_egypt.luau`): només s'hi arriba amb ✈️ Travel → 🐫 Egypt, i es desbloqueja a la portalada de l'illa (`ZoneUnlock`). `Zones.requires` = la zona que cal tenir abans; `unlockAt` = on es desbloqueja (missatge). |
| Paletes | `Config/Tools`, `ShopService`, `ShopController`, `ToolService` | 6 paletes (x1 → x3 de sort) a Dig & Co. (plaça): 22.500 · 180.000 · 1,2 M · 6 M · 27 M (29/09/2026: economia ~2x més ràpida, preus a la meitat i +50% de monedes per excavació). Mantens E sobre l'eina → fitxa amb el model 3D i BUY. |
| Vendre | `ShopService` (sell), `DialogController` (Bonnie) | La Bonnie (Fossil Buyer, al costat de Dig & Co.) compra repetits / tot / una peça. Val 4 min de renda. |
| Museu | `MuseumService`, `MuseumController`, `Config/Museum` | 10 vitrines, renda amb sostre 360.000/min (6.000 $/s), esquelet muntat x2, renda offline (8 h, 24 h amb passi). La renda es COMPTA per minut (economia i simulador) però el jugador la VEU per segon (`Museum.PerSecondText`: un Common exposat fa 60/min = "+1 $/s") i entra cada segon: el servidor cobra cada `TICK` (1 s) i envia només les monedes (`CoinsUpdate`); el perfil sencer, cada `PUSH_EVERY` (10 s). Els diners es marquen amb **$** (verd amb contorn, `Theme.Icon("$")`), no amb 💰. **29/09/2026: TOTS els diners x60** (renda, monedes d'excavar, preus de les paletes, platja, sostre, venda, propines, renda mínima de premis i packs; migració de perfil v3 que multiplica les monedes que ja tenies): el ritme del joc és el mateix, els números 60 vegades més grossos. |
| Visitants | `VisitorService`, `VisitorController`, `Config/Visitors`, `Util/VisitorPath` | NPC amb l'avatar dels amics de tots els jugadors del servidor. Miren vitrines i de tant en tant deixen propina (💰 +X sobre el cap). El servidor decideix; el client els dibuixa. |
| Comerç | `TradeService`, `TradeController` | Amb tot el servidor, escrow atòmic, rètols al passar el ratolí. Es pot desactivar a la configuració. Proteccions: 30 min de joc abans de comerciar (`stats.playSeconds`; a Studio no compta), els fòssils de recompensa van bloquejats (`lockedBones`, 🔒 a la motxilla; exposar-los no els desbloqueja: `museumLocked`), cal que el perfil es desi de debò, registre `tradeLog` amb el mateix id als dos perfils, avís de canvi desigual (x3 de renda). Després d'un canvi els dos perfils es desen alhora (`DataService.SaveMany`) i no poden tornar a comerciar fins que acaben. |
| Robux | `MonetizationService`, `StoreController`, `Config/Monetization` | Cadena de sort x2→x32, cadena de diners x2→x8, boosts, VIP, productes. **Els `id` encara són 0**: cal crear-los al Creator Dashboard. |
| Recompenses | `RewardsService`, `RewardsController`, `Config/Rewards` | Diària (7 dies), regals per estona de joc, invitacions. El like NO té premi (normes de Roblox). |
| Missions | `QuestService`, `QuestController`, `Config/Quests` | Cadena de 24 missions (la 23 és "Fly to Egypt and unlock it") i després repetibles. La base de cada missió porta `baseFor` (el text de la missió): si es canvia l'ordre de la cadena, una base d'una altra missió no es fa servir. El progrés surt del perfil (stats: `totalDigs`, `rarityFinds`, `totalSold`, `totalAssembled`...): res d'esdeveniments. Es veu a dalt quan el tutorial s'acaba, amb CLAIM i el raig de llum cap on anar. |
| Guia | `UI/Guide` | El raig de llum + fletxa (tutorial i missions; `owner` perquè no es trepitgin) i on són els llocs (entrada de zona, munt més proper, botiguers). |
| Configuració | `SettingsService`, `SettingsController` | Mida del HUD, mida dels menús, música, efectes, gràfics, trades, premis ràpids. Es desa al perfil. |
| Dades | `DataService`, `Config/ProfileSchema` | Session locking, autosave, migracions (esquema v2). Cada desat porta un `saveSeq` que puja: un desat vell que arriba tard no trepitja un de nou, i cap desat normal torna a agafar un lock ja alliberat. El lloc està publicat: el DataStore funciona. |
| UI | `src/client/UI/*` | `Theme` (estil), `Widgets`, `Windows`, `Effects`, `PieceView` (peça 3D dins la UI). Al mòbil (`Theme.IsCompact`) el HUD es reorganitza (rajoles 4x2 a dalt, sense barra d'índex) per no tapar el joystick ni el salt, i les finestres creixen fins a omplir la pantalla. A Studio es pot simular un mòbil amb els atributs `EmulateViewport` (Vector2) i `EmulateTouch` al LocalPlayer. |
| So | `AmbienceController` | Ocells a la ciutat, onades a la platja, aigua a la font. Música de fons en roda (llista `MUSIC`: **encara buida**, cal posar-hi pistes de la biblioteca de Roblox). |

## 3. El món 3D

El món NO és al codi del joc: el construeixen els scripts de `tools/world/`
(01 terra i llum · 02 carrers · 03 cases · 04 museus · 05 plaça · 06 platja ·
07 obra · 08 arbres i fanals · 09 Dig & Co. i la parada de la Bonnie ·
10 indicadors a les cruïlles cap a la plaça, l'obra i la platja ·
11 Egipte: l'illa amb el moll, la portalada, els cràters, piràmides,
esfinx, temple, oasi i mercat; **mai construït encara**: cal executar-lo a
Studio i fer-ne captures), amb
`tools/world/lib.luau` com a biblioteca comuna (peces, Toolbox, forats CSG).
Els models de la Toolbox es carreguen per id i sense scripts (`ASSETS` a
`lib.luau`).

**Peces que se solapen** (28/09/2026): dues cares al mateix pla amb colors
diferents fan pampallugues. Es va fer un escàner (cares coplanars visibles i
peces d'objectes diferents que s'encavalquen) i es va passar de ~1.100
parelles a ~200, gairebé totes amagades. Arreglat a la font: carener de les
teulades a dues aigües, sòcol de les cases (`w + 0,5`), finestres de la vila
que tocaven la torre, balcó de la vila, perfil de la tapa de les vitrines,
pals de la tanca de l'obra, pilars i taulons de Dig & Co., barca, tovalloles,
voreres. Els arbres (08) miren si la capçada toca un edifici i s'encongeixen
o no es planten. Regla: deixar sempre **0,05** entre cares paral·leles.

## 4. Com es treballa (Roblox Studio via MCP)

- El Studio ha d'estar obert amb el lloc **Experiencia sin título
  (placeId 78248822694193)** i l'**Assistant > MCP Server** activat.
- L'id del Studio canvia cada cop que s'obre: `list_roblox_studios`.
- Codi → Studio: `STUDIO_ID=<id> python tools/sync_src.py` (fa com Rojo, amb
  el Studio en mode **Edit**; si està en Play, cal aturar-lo abans).
- Món → Studio: `STUDIO_ID=<id> python tools/world/run.py` (tot) o
  `python tools/world/run.py 05` (un mòdul; abans esborrar la seva carpeta).
- Plugin del món: `python tools/world/make_plugin.py`.
- Economia: `python tools/economy_sim.py 300` (triga uns minuts).
- Pont MCP propi: `tools/mcp/studio_mcp.py` (el fan servir els scripts).

### Trucs que ja han costat temps
- Les captures en mode Edit sovint surten **blanques**: fer-les en **Play**
  amb una càmera Scriptable (`RunService:BindToRenderStep`).
- A 300 d'alçada l'Atmosphere ho fa tot blanc: treure-la al client per a
  galeries de proves.
- Els `ViewportFrame` es dibuixen de mica en mica: esperar abans de capturar.
- Per provar un ModuleScript modificat a Edit: clonar-lo DINS la mateixa
  carpeta (els `require` relatius) i fer-ne `require`.
- Heredocs de bash amb molts apòstrofs fallen: escriure un .py i executar-lo.
- A Studio, les compres de Robux de prova són gratis i només duren la sessió
  (`studioTestPasses`).
- Esborrar sempre les galeries i peces de prova del Workspace abans d'acabar.
- Si el propietari és dins del joc publicat, el seu perfil està bloquejat
  per aquell servidor i a Studio l'expulsen als ~10 s ("bloquejat per un
  altre servidor"). Cal que surti del joc publicat abans de provar.

## 5. Què falta (per ordre)

1. **Crear els passis i productes** al Creator Dashboard i posar els `id` a
   `Config/Monetization.luau`.
2. **Provar el comerç amb 2 jugadors reals** (mai s'ha provat de debò). Tot el codi del 28/09 s'ha revisat al núvol però
   no s'ha executat mai (veure §6): cal una partida de prova sencera a Studio. A
   Studio: Test > Clients and Servers amb 2 jugadors (a Studio no cal la
   mitja hora de joc).
3. **Protegir l'economia del comerç**: fet (28/09/2026) menys el sostre per
   raresa, que canvia els números de sort de `CLAUDE.md` i està pendent de
   decidir. També: invitacions que caduquen (20 s), 3 s per mirar l'oferta
   abans d'ACCEPT, 5 s entre canvis i registre global `TradeAudit_v1`.
4. Comprovar a joc els visitants (que no quedin torts) i les propines.
5. UI: fet el HUD per a mòbil i les finestres que omplen la pantalla, el
   HUD d'ordinador un 12% més petit, els 5 viatges dins d'un sol botó
   ✈️ Travel, ✕ per tancar a totes les targetes i probabilitats 🎲 a
   l'Índex (28/09/2026, feedback d'en Luca); falta provar-ho en un mòbil
   de debò.
6. Llançament: tot a **`docs/LLANÇAMENT.md`** (qüestionari d'edat, que és
   per què en Luca no hi podia entrar; nom, descripció, icona, passis).
   Música: omplir `MUSIC` a `AmbienceController`.
7. Idees parlades: rebirth (només diners, mai sort), neteja de fòssils amb
   pinzell, desar menys sovint quan es compren molts passis seguits.

## 6. Revisió al núvol (29/09/2026)

Tot el codi del 28/09 es va revisar SENSE Studio: analitzador de tipus
(luau-lsp amb les definicions de Roblox i el sourcemap de Rojo) sobre `src/`
i sobre cada mòdul de `tools/world/` amb `lib.luau` al davant, i revisió a mà
del servidor, del client i del món. Les eines no són al repositori (es
compilen de la font oficial: `cargo install rojo` i luau-lsp amb cmake).

**Analitzador**: cap error real. El que surt són limitacions de les
definicions (`for x in t or {}`, taules amb tipus barrejats, `nil` a taules
tipades) i avisos d'estil. `Player:IsFriendsWith` surt com a obsolet
(Roblox recomana `IsFriendsWithAsync`); no s'ha tocat perquè encara funciona.

**Arreglat**:
- `DataService`: si el jugador marxava MENTRE es carregava el perfil, el
  perfil arribava després del seu PlayerRemoving: el lock quedava agafat
  (en tornar a entrar l'expulsaven, "profile still open") i ell i el seu
  museu quedaven a les taules per sempre. Ara es desa, s'allibera i es
  neteja al moment.
- `DataService`: el batec recorria `profiles` mentre cedia el control (hi
  entren i en surten jugadors); això pot petar i aturar el batec per
  sempre, i llavors els locks caducarien amb els jugadors dins. Ara recorre
  una llista feta abans.
- `TradeService`: no es pot confirmar un canvi sense cap fòssil a cap banda
  (servia per cobrar la missió "Trade with another player" sense donar res).
- HUD: el 👆 de la missió a Backpack/Trade/Store l'esborrava el refresc del
  HUD (cada 10 s). Ara hi ha `HudController.SetBadge` (la guia: tutorial i
  missions) i `HudController.AutoBadge` (comptadors i avisos), i les
  automàtiques no trepitgen el 👆.
- `MonetizationService.processReceipt`: si el desat fallava, s'esborrava el
  registre de la compra però les monedes ja eren al perfil, i el reintent
  de Roblox les tornava a donar. Ara el registre es queda i el reintent
  només torna a provar de desar.
- `Theme.AutoScale`: cada UIScale quedava per sempre en una llista, i la
  targeta de cada troballa en fa una (una per excavació). Ara les que ja
  no hi són es treuen.
- Detall de UI no arreglat: SHOW a la motxilla ensenya "is on display!"
  encara que el museu sigui ple (el servidor també avisa en vermell).

**Revisat i bé**: saveSeq/SaveMany (un desat vell no trepitja un de nou),
escrow del comerç (validació sencera i mutació sense yield), invitacions que
caduquen, ACCEPT amb retard, cooldown, audit; `lockedBones`/`museumLocked`
(exposar o muntar no desbloqueja); missions (cap yield entre comprovar i
cobrar: no es poden cobrar dos cops); cicles de `require` (cap); taules per
jugador (totes es buiden a PlayerRemoving); tots els remotes (Settings,
Travel, Shop, Sell, Museum, Dig, Quest, Reward, Purchase: validen tipus i
rate limit, i el client no decideix cap resultat); connexions del client
(totes un sol cop a `Start`); probabilitats de l'Índex (mateixa fórmula que
el servidor); `08_props`, `10_signs`, `gableRoof`. Els retocs de 02/03/04/
06/07/09 només s'han pogut passar per l'analitzador: si es veuen bé cal
mirar-ho amb captures a Studio.

**Economia de les missions** (simulació amb la cadena de `Config/Quests`,
300 partides, jugant sol): els premis en monedes (mínim 20/min de renda, ara 1.200/min amb el x60)
pesen molt al principi. Sense missions → amb missions:
Steel Trowel 6,7 → 2,0 min · Pro Trowel 33 → 6,5 min · Platja 91 → 64 min
(44 min si el comerç de la missió 12 es fa als 35 min). A partir de la Ruby
Trowel l'efecte és petit. **Pendent de decidir** (no s'ha tocat): rebaixar
les monedes de les 11 primeres missions o la renda mínima per a missions.
A més, la missió 12 ("Trade with another player") arriba cap als 6 min,
però no es pot comerciar fins als 30 min de joc: **la cadena queda aturada
~25 min** per a tothom i per sempre per a qui juga sol. Proposta: moure-la
més avall (després de "Dig 75 fossils") o fer-la opcional.

**29/09/2026 (tarda)**: economia ~2x més ràpida (simulació: Steel Trowel
6,5 → 2,8 min · Pro 32 → 18 min · Platja 89 → 54 min · Ruby 2,5 → 1,5 h ·
Golden 6,1 → 3,7 h · Diamond 17 → 11 h · Egipte als ~5,7 h); la sort no es
toca, així que els esquelets alts continuen igual de lents (el comerç
continua sent la drecera). Tutorial redissenyat (targeta gran amb icona,
títol, consell i punts de progrés, celebració en acabar). Els avisos
(toasts) han baixat a y = 172 perquè no els tapi.

**Dubte**: el tutorial es dedueix del perfil; si algú buida el museu,
el tutorial (pas 3) torna a sortir i amaga les missions fins que exposa
alguna cosa.

## 7. Fitxers que no s'han de fer servir

- `INSTALL.lua`: instal·lador antic de la primera versió de l'obra (80x80).
  Obsolet; el món actual es fa amb `tools/world/`.
