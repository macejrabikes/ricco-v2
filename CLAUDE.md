# Ricco v2 – kontext pre Claude

Toto je odovzdávací súhrn pre nový chat / Claude Code. Prečítaj celý pred prácou.

## O hre
- **Ricco v2** – 2D akčná plošinovka v štýle pôvodnej flash hry *My Friend Pedro*, remake môjho stredoškolského projektu (SOČ).
- Hrdina **Ricco** je mafiánsky tučniak (~1 m, „čisté svaly“, miluje pizzu). Don Vito ho zavolá do pizzerie, Ricco ho nájde umierať v pivnici,
  Donov **duch** mu požičia ruky na držanie zbrane a na pár sekúnd **spomaľuje čas** (obrazovka zmodrie).
- **Iba Ricco je tučniak. Nepriatelia (mafiáni) aj hostia sú ľudia.**
- Godot **4.7.1**, GDScript so statickým typovaním, len PC, pixel art **640×360** s celočíselným škálovaním.
- Addony: Phantom Camera, Aseprite Wizard, LimboAI, Dialogic 2.

## Pravidlá spolupráce (dôležité)
- **Odpovedaj po slovensky**, pokojne neformálne.
- **Postupne, nie všetko naraz.** Jeden krok → otestovať → commit.
- **Nové vizuálne veci (dizajn, sprite, efekt, UI): najprv mi ukáž pár možností (obrázky/náhľady), až potom to daj do kódu.**
- Zvuky: keď sa mi niečo nepáči, nepýtaj sa zbytočne – ak poviem „daj X“, sprav X. Nedávaj na výber tam, kde som povedal konkrétne.
- **Pripomínaj mi git commit + push často** – po každom hotovom kroku mi daj hotové PowerShell príkazy.
  Radšej 5 malých pushov ako jeden obrovský po 2 dňoch.
- **Nikdy sám necommituj ani nepushuj. Git robím len ja.**
- `project.godot` upravuj len keď je Godot zavretý (inak ho Godot prepíše).
- Testovacie skripty (testboti) nikdy nenechávaj v `project.godot` ani v repe.
- Komentáre v kóde píšem **po slovensky**; pri Godot API sa hodí odkaz typu `## Godot docs: classes/class_tween`.

## Štruktúra
```
audio/        sfx.gd (trieda Sfx), sfx/*.wav (efekty), amb/*.ogg (slučky prostredia)
characters/   ricco/ (hráč, focus/ = spomalenie), gangster/ (mafiáni z častí tela), don/, lou/ (Big Lou – boss kapitoly II, dynamit)
effects/      burst.gd (Burst – čiastočky), explosion.gd (trieda Explosion – výbuch: ohnivá guľa, tlaková vlna, záblesk, sadza, zranenie, reťaz sudov), art/
levels/       level1/ (ulica → reštaurácia → kuchyňa → sklad → herňa) + cellar (tunely), level2/ (kapitola II – cintorín + docks = prístav + coldstore = mraziareň), test_room/
world/        stealth/ (light_zone – svetlo/tma), fx/ (dážď, neón, hat_lamp, speakeasy_door…), npc/ (guest, rat, dog – pes na reťazi), fx/lighthouse_beam (otáčavý lúč majáka),
              coldstore/ (hook_rail – koľajnica s hákmi, carcass – visiace mäso = kryt, conveyor – pás),
              ship/ (storm – blesky a hrom, roll – hojdanie mora a mrakov, ship_crate – debna/kryt, ship_barrel – sud whisky,
              deck_fire – oheň na palube, crane – žeriav so sieťou, falling_cargo – debna zo siete)
weapons/      pistol/ (bullet, magazine_drop, záblesky), hat/ (hat_projectile – hod klobúka)
props/        ammo/ (krabička nábojov), pizza/ (kúsok pizze +2 zdravie), target/
ui/           hud, boss_bar (pás zdravia bossa, značky fáz), dialog, main_menu, pause_menu (menu_pages: nastavenia, AUDIO), cursor, fonts (Tiny5), retro_filter
settings/     game_settings.gd (GameSettings – ukladá do user://settings.cfg, aj hlasitosti [audio])
tools/        build_level1.gd (generuje level1.tscn aj cellar.tscn), build_level2.gd (cintorín), build_docks.gd (prístav), build_coldstore.gd (mraziareň), build_margaret.gd (loď), build_ricco_frames.gd (SpriteFrames Ricca)
docs/media/   obrázky do README (bannery v jednotnom „S2“ štýle)
```
- **Level 1 a pivnica sa generujú skriptom**, needitovať `.tscn` ručne:
  `godot --headless --path . --script res://tools/build_level1.gd`. Bludisko pivnice je textová mapa (const MAZE) v tom súbore.
  Level 2 (cintorín) rovnako: `godot --headless --path . --script res://tools/build_level2.gd`,
  prístav: `godot --headless --path . --script res://tools/build_docks.gd`,
  mraziareň: `godot --headless --path . --script res://tools/build_coldstore.gd` (generuje aj `tiles_cold.tres` s vlastnými dátami „ice“),
  loď: `godot --headless --path . --script res://tools/build_margaret.gd` (generuje aj `tiles_ship.tres`).
- Obrázky sú v **Git LFS**.

## Čo je hotové (kapitola I hrateľná)
- Pohyb: coyote time, jump buffer, variabilný skok, chytenie hrany, wall jump, šmyk po bruchu, plíženie.
  **Podkopnutie:** šmyk po bruchu (od `slide_trip_speed`) do mafiána ho zvalí na chrbát (`Gangster.trip`, leží `trip_time`, nestrieľa,
  dá sa zložiť F), potom vstane a ide po Riccovi.
- Streľba, obmedzené zásobníky (prázdne padajú a odrážajú sa), spomalenie (duch Dona), klobúk (hod omráči / zhasne lampu, vracia sa), zdravie.
- Stealth: svetlo/tma, zneškodnenie zozadu (F, dosah `takedown_range` 44 px), mafiáni s hliadkami, baterkami, rôznymi zbraňami.
- **Kapitola I:** daždivá ulica (neón, vyhadzovač, intro I1) → súkromná oslava v reštaurácii (hostia s náhodnými tvárami; keď ťa uvidia na svetle,
  majú „!“ a privolajú mafiánov; hat_lamp; z trámu nad barom vedie **vetracie potrubie** – šmyk dnu, plazenie, vypadne na policu nad kuchárom) → kuchyňa, sklad → **herňa za oceľovými dverami s tajným klopaním** (mafián ukáže rytmus,
  Ricco klope F: KLOP KLOP … KLOP KLOP KLOP) → **pivnica = samostatná mapa, bludisko tunelov** (krv, potkany, baterky) → Donov úkryt, cutscéna, prvá prestrelka.
- Checkpointy (`Level1.checkpoint`, ≥3 = pivnica).
- **Kapitola II – Wharf Rats** (rozrobená): **level 2 = cintorín v noci, Donov pohreb**
  (`levels/level2/level2.gd`, statické `Level2.checkpoint` atď., `Level2.reset()`). Koniec kapitoly I vedie rovno sem, v menu je aj CHAPTER II.
  Ricco má derringer + spomalenie; celý cintorín je tma (`dark_area`). Hrobník s lampášom (úkryt v otvorenom hrobe), kôlňa s **revolverom .38**
  (F výmena za derringer), mauzóleá ako plošiny, na streche duch komentuje vlastný pohreb (hlášky), mafián odhodí **zápalky Fontana Shipping – Pier 13**
  (stopa; bez nej krypta nepustí), smútiaci (prefarbení hostia) a kňaz zvreskú na svetle, konáre duba ponad pohreb, strážnik s lampášom,
  stráž s palicou pred kryptou. Krypta → pašerácky tunel → prístav. Prví strelci v hre majú revolvery.
  **Prístav** (`levels/level2/docks.gd extends Level2`, `docks.tscn`, checkpointy 4–6, návrh A2 – móla v hmle): nábrežie s kanálom →
  mólo 1 s **dokárom s hákom** (`Gangster.hook`: dlhší dosah, úder Ricca pritiahne) a lampášom → rybárska loď Santa Rosalia (16 dlaždíc, z oboch strán 4 dlaždice vody, paluba y −16, rybár na korme s **luparou** –
  zozadu zneškodniť, lupara = prvá hlavná zbraň, `Level2.has_lupara`) → mólo 2 so **psom na reťazi** (`world/npc/dog.gd`: cíti aj v tme,
  pod vodou nie, štekot privolá mafiánov, klobúk ho omráči, guľka len vyľaká) a strelcami → **lúč majáka** (`world/fx/lighthouse_beam.gd`,
  pohyblivá LightZone; kužeľ sa kreslí od vzdialenej lampy `source`, škvrna dopadá okolo uzla Beam) → 13 dlaždíc vody k Pier 13 na preplávanie (žiadny
  vlnolam; vo vode checkpoint 6 a scéna s Lou, na móle by Ricco ožil pri strážach; maják je **v diaľke** na skalke pri obzore – `FarLighthouse`, Parallax2D 0.3, zmenšený a v hmle; v diaľke aj loď S.S. Margaret,
  **Big Lou ako silueta za oknom mostíka**, duch ho spozná) →
  Pier 13 → dvere skladu Fontana Shipping → mraziareň. Paluby mól sú jednosmerné
  plošiny – z vody sa na ne vyskočí zospodu, pod palubou ťa nevidno; medzi mólami sú medzery na skok do vody.
  **Mraziareň** (`levels/level2/coldstore.gd extends Level2`, `coldstore.tscn`, checkpointy 7–10, návrh A – háky + ľad, ~312 dlaždíc):
  príjem tovaru (whisky sa prebaľuje do rybích debien) → mraziareň 1 (ľad, koľajnica s hákmi, mafián vo veste) → chodba s potrubím
  (len šmykom po ľade, para) → mraziareň 2 (regály, druhá koľajnica, lávka, rozbitá debna „tresky“ s whisky, lupara) → kancelária Lou na lávke
  (**účtovná kniha** = stopa, `Level2.ledger_read`: S.S. Margaret odpláva o 2:00) → tunel (schody, pás do podpalubia) → vráta k lodi =
  pás do podpalubia lode (bez knihy nepustí) → `margaret.tscn`, checkpoint 11.
  **Loď S.S. Margaret – finále** (`levels/level2/margaret.gd extends Level2`, `margaret.tscn`, checkpoint 11, návrh A + žeriav, Big Lou
  v bielom obleku – vybrané): paluba v búrke (lejak, blesky `world/ship/storm.gd` so signálom `flashed`, hrom, hojdanie mora `roll.gd`,
  vlny cez zábradlie – zatiaľ len efekt). Kajuta na korme (príchod) → záchranný čln (plošina −48) → debny = kryt (`CoverN`, skupina
  `ship_cover`, `world/ship/ship_crate.gd` – guľky ich postupne rozbijú, horná debna spadne, niekedy vypadnú náboje) a sudy RYE
  (`Barrel1–3`, `world/ship/ship_barrel.gd`, vrstva 4 – jedna Riccova guľka a vybuchne, Louove ním prejdú; 4 HP Louovi, potom horí)
  → žeriav (`CraneArm` = `world/ship/crane.gd` s `Boom`, `Rope`, `Net`, `Shadow`; búdka `BoothBack`/`BoothFront`/`Lever`/`BoothLamp`,
  steny `BoothWallL/R` na vrstve 32, `BoothSpot` x 628) → krídlo mostíka (`WingFloor`, `LouSpot`, y −96) →
  nadstavba (strecha −96, na hranu sa dá chytiť) s mostíkom → prova. Dvere na lodi sú 80 px (mafián ~75 px).
  **Big Lou** (`characters/lou/big_lou.gd`, `class_name BigLou`, `big_lou.tscn`, časti tela v `characters/lou/`, ~108 px = ~1,4× mafián
  ako na vybranom návrhu; samostatný skript, nie Gangster – iné rozmery kostry): krémový oblek, fedora, cigara (dym), vesta
  (`vest_factor` 0,25 do trupu, hlava a nohy naplno, signál `vest_hit`), Thompson s bubnom (`thompson_drum.png`, dáta `tommy.tres`).
  Signály `health_changed`, `vest_hit`, `threw`, `stage(name)` (réžia pre level), `died`. Pás zdravia hore v strede:
  `ui/boss_bar.gd` (`track(meno, boss)`, `notches` = značky fáz). **36 HP, tri fázy po 12** – pod hranicu fázy nejde, najprv
  prechod (Lou je vtedy nezraniteľný, guľky sa odrážajú). Checkpoint boja `Level2.lou_phase` (po smrti začne v búdke / na horiacej
  palube – `setup_phase()`, `margaret.gd _resume_phase()`, žeriav `wrecked()`).
  **1. fáza – krídlo mostíka:** keď ho Ricco prvý raz uvidí, blesk + nabitie Thompsonu (`start(true)`, `Level2.lou_revealed`
  – po smrti už bez úvodu); mieri (červená čiara) → dávka 8–12 rán, zbraň sa počas nej otáča pomaly (dá sa utiecť) → pauza / prejde
  sa po krídle (`walk_span`); Ricco sa skrýva za debnou (`hide_time`), stojí pod krídlom alebo po 3 dávkach → **dynamit**
  (`characters/lou/dynamite.gd`: oblúk, šnúra syčí 1,6 s, dosah 48 px, 2 kúsky pizze, rozbije debny; pod krídlo ho pustí cez
  zábradlie a skotúľa sa k Riccovi); Ricco pri ňom na krídle → výpad a **úder pažbou** (zhodí ho z krídla). Klobúk mu zhodí
  fedoru a zarazí ho, šmyk ho len zapotáca, potichu zneškodniť nejde. Strieľa len keď je na obrazovke (po zásahu 4 s aj mimo).
  **Prechod 1→2:** dôjde na kraj krídla, prikrčí sa, zoskočí na palubu (rozdrví debnu, vypadne kúsok pizze), beží do búdky, skok dnu.
  **2. fáza – žeriav z búdky** (z plechu trčí hlava a ramená, telo kryjú steny búdky): sieť ide za Riccom → tieň + rinčanie →
  vypadne debna (`falling_cargo.gd`: 2 kúsky pizze, potom polovica sa rozbije, inak nový kryt) ×3 → rameno na vzdialenejší kraj,
  sieť dole (spodok −30) a **zametie palubu** (`lethal`; stojaceho Ricca zrazí, po bruchu prejde popod; stohy debien zhodí).
  Ricco mimo dosahu (x < ~390, záchranný čln) → Thompson / dynamit; zblízka úder pažbou cez plech; 3 zásahy do hlavy za 2,5 s → skrčí
  sa (1,5 s, guľky cinknú o plech); debna zo siete na hlavu = 3 HP. Kyvadlo siete poháňa zrýchlenie kladky (`x_accel`).
  **Prechod 2→3** (`stage(&"lightning")`, réžiu robí `margaret.gd _lightning()`): žeriav sa vymkne k zádi → blesk (zubatá čiara)
  do kabíny, výbuch, kabína horí → rameno sa zrúti (kladka na x ~447 – Barrel1, výbuch, stály oheň + dva dočasné) → sieť spadne a
  roztrhne sa (2× náboje, pizza) → výbuch búdky vyhodí Lou (`blown`), padne na chrbát, leží, vstane **pripálený** (`*_burnt.png`,
  zúrivá tvár), rev (dupne 2×, para z uší). Loď horí: ohne na mostíku/kajute/člne, iskry (CPUParticles2D za kamerou), oranžový nádych.
  **3. fáza – na palube** (`deck_span` 124–812, vesta 0,5, mierenie 0,5 s): kráča k Riccovi (debny v ceste rozbije, cez pätu žeriavu
  prekročí), dávky, po 3 dávkach **prebíja bubon** (`thompson_nodrum.png`, `drum.png`), **trojitý dynamit**, **rozbeh** (dupne 2×,
  hlava dole, 230 px/s): stojaceho Ricca zrazí (2), šmyk do neho = podkopnutie → padne na tvár, **omámený** 2,2 s (hviezdičky,
  vesta nepomáha); náraz do steny / päty žeriavu → omámený 1,8 s. Keď Ricca zraní, **smeje sa**. Duch radí: sud pri Lou, rozbeh, hviezdy.
  **Smrť:** zapotáca sa, posledná dávka do neba, Thompson vyletí (pickup), na kolená, na tvár → zo saka sa vykotúľa dynamit → veľký
  výbuch (bez zranenia), z Lou ostane klobúk, ktorý sa znesie ako list → hláška ducha → TO BE CONTINUED (`margaret.gd _on_lou_died`).
  Duch hlási: úvod, mier na hlavu, dynamit, debny, beh k žeriavu, náklad, švih sieťou, „loď horí“, rozbeh, hviezdy, sud.
  **Ďalej:** únik z horiacej lode a cliffhanger (list v kajute), README roadmapa.
  **Ľad:** dlaždica s vlastnými dátami `ice` (TileSet) alebo kolízia v skupine `ice` → `ricco.on_ice` (malé trenie, dlhý šmyk, `ground_friction()`).
  **Háky:** `world/coldstore/hook_rail.gd` – vozíky idú po koľajnici (vzor `pattern`: C = mäso, H = voľný hák, - = nič); Ricco vo vzduchu
  chytí voľný hák (stav HOOK = 6, animácia `hook` = jedna plutva hore, `sprites/hook.png` z `jump.png`; vezie sa, strieľa,
  skok/šmyk = pustí sa, pred koncom koľajnice sa pustí sám). Na koncoch koľajnica zatáča dozadu (`DEPTH`): vozík spomalí, zmenší sa, stmavne a zmizne. Mäso (`carcass.gd`, vrstva 32)
  zastaví pohľad aj guľky, postavy prejdú. **Vesta:** `Gangster.vest` – do trupu len `vest_factor` damage (iskry, cink), hlava a nohy naplno
  (`take_hit_at`). `Gangster.cold_breath` = para od úst; Riccovi ide para v mraziarňach (coldstore.gd).
- **Plávanie:** v pivnici sú zatopené katakomby (kostnica ~113 dlaždíc: bazény, rošt nad vodou s hliadkou s baterkou – popod ňu sa dá preplávať,
  dlhý sifón, krypta so strážou chrbtom, dosky cez vodu). Hlboká voda je v MAZE znak `%`, build z nej spraví `WaterZone`
  (`world/water/water_zone.gd`). Ricco má stav SWIM: na hladine pláva, S = ponor, medzerník = hore / vyskočiť, k nízkemu okraju sa sám vyšvihne.
  Pod hladinou (`submerged`) ho gangstri nevidia. Dych nemá – je to tučniak.
- **Schody:** kolízia je neviditeľná 45° rampa, kresba sú jemné 4 px schodíky presne po rampe (dlaždice „nos“ v 4. riadku atlasov).
  Postavy majú `floor_snap_length = 16` (na hrane schodov nevyskočia) a na svahu sa obrázok posunie o 4 px nižšie (spodok kapsuly).
- Menu: hlavné menu, pauza, nastavenia (kurzor, zameriavače, HUD štýly, retro filter), **AUDIO** (Master, Music, SFX, Ambience, UI; 0–10),
  **CONTROLS** (zoznam kláves + SNEAK HOLD / TOGGLE – `GameSettings.sneak_toggle`; nápisy kriedou s `{SNEAK}` sa podľa toho prepíšu).
- **Prechody medzi scénami** idú cez `ui/loading/loading_screen.gd` (`LoadingScreen.go(get_tree(), path)`, preload, nie class_name):
  čierna clona úplne navrchu (layer 128), skrytý kurzor, scéna sa načíta na pozadí a clona sa zdvihne až po pár snímkach novej scény.
  Nové `change_scene_to_file` už nepoužívať – ísť cez LoadingScreen.
- **Zvuky** (posledná práca):
  - `Sfx.play(name, pos, vol_db, pitch_var, bus)`, `Sfx.loop(...)`, `Sfx.shot(weapon, pos)`, `Sfx.set_slowmo(on)` – zbernice sa vytvoria za behu,
    pri spomalení je dolná priepusť a SFX pitch ×0.72.
  - Väčšina efektov sú CC0 nahrávky (Kenney Impact/RPG/Casino Audio, Organic Wooshes, Smol Mechanisms, Warfork ricochety, 40 CC0 water – dážď),
    zvyšok syntetizovaný (spomalenie, Riccov zásah/smrť, zásah do tela, výstrely, menu, dav, kuchyňa, tunely, neón, potkan, tlkot srdca).
  - Klobúk: `hat_throw` (hod) + `hat_return` (keď sa vracia, `hat_projectile.gd`).
  - **Mafiáni ani hostia nehovoria** – iba žltý „!“ nad hlavou + krátky tón `alert.wav`. Hlasy (TTS) som zamietol – znelo to hrozne.
  - Muzzle flash štýl A, väčší recoil, lupara odhodí Ricca dozadu.

## Pravidlá dizajnu hry
- **Zbrane len dobové** (20. a 30. roky, prohibícia) a skôr **rôzne druhy** než viac variantov toho istého typu.
- **Postup od slabých k silným:** Ricco začína so slabou zbraňou a lepšie odomyká postupne. Prvá zbraň je **Donov derringer**
  (Don ho mal schovaný). Plán bočných: derringer → revolver .38 → Colt 1911 → Mauser C96 Schnellfeuer.
  Hlavné: lupara → Winchester 1897 (pumpovačka), Thompson, Winchester 1894 (páková) → Springfield 1903, BAR M1918.
- **Nepriatelia sa postupne zlepšujú** – v ďalších leveloch silnejší protivníci so silnejšími zbraňami.
- **Výbava:** 1 bočná (kláves 1) + 2 hlavné (klávesy 2, 3). Zbraň zo zeme: voľné miesto → zoberie sám, plné → F vymení.
- **Výber výbavy medzi levelmi** (až keď bude druhý level): obrázok zbrane + štatistiky. **Damage, fire rate, range, accuracy
  ako pruhy**, čísla len pri veľkosti zásobníka a rýchlosti prebíjania. Štatistiky počítať priamo z WeaponData.
- **Nepresnosť:** každý výstrel má trochu rozptylu (spread_deg); pri automatických zbraniach sa pri dlhej streľbe zhoršuje
  (spread_bloom_deg / spread_max_deg / bloom_recover_deg vo WeaponData).
- Každá zbraň má vlastnú animáciu prebíjania podľa skutočnosti (derringer sa láme – hlavne sa vyklopia).
- **Dostrel:** guľky nemiznú – do effective_range plný damage, potom rýchly pokles na 10 % (falloff_range). Damage je desatinný.
- **Nastavenia sú v kategóriách** (DISPLAY, HUD & AIM, AUDIO); nové nastavenie patrí do správnej kategórie.

## Ďalšie kroky (poradie)
0. **Zbrane a výbava** (rozrobené): zbieranie zbraní, výbava 1+2, derringer, rozptyl – hotové, čaká na test.
   Arsenal v menu (ui/arsenal/arsenal.gd, štýl „zbrane na stene“): odomknutie v settings/progress.gd (user://progress.cfg),
   zbraň sa odomkne pri prvom vzatí do ruky. Nové zbrane pridať do Arsenal.ENTRIES (res + popis).
   Ďalej: nové dobové zbrane (vždy najprv návrhy obrázkov), ľudský štít, výber výbavy so štatistikami medzi levelmi.
1. **Realistické výstrely** (odložené) – syntetické aj CC0 nahrávky znejú „tupo“. Holé nahrávky treba vrstviť
   (prask + telo + basy + saturácia). Still North knižnica je v `_raw_audio/` (Colt 1911 = priečinok 1911).
   Sonniss GDC 2026 Part 9 v `_raw_audio/SONISS GDC` nemá strelné zbrane (má ambienty baru, dažďa, auto atď.).
   Zdroj: Still North Media „Free Firearm Sound Library“ (CC0) –
   `http://www.mediafire.com/download/gh6e02cvj8x75fr/Prepared_SFX_Library.zip` → rozbaliť do `_raw_audio/` (s `.gdignore`, a `_raw_audio/` do `.gitignore`).
   Potom do README → Credits doplniť Still North Media.
2. **Hudba** – najprv mi daj pár možností na vypočutie.
3. Pozadie hlavného menu ešte ukazuje starý nápis/dvere pizzerie – prerobiť podľa novej ulice (najprv možnosti).
4. Roadmapa: ďalšie zbrane a loadout (Tommy gun, lupara, revolver), ľudský štít, ďalšie kapitoly (pomsta, bossovia, schopnosti po leveloch),
   style meter, tajomstvá, plávanie a ľad, malé 3D retro preteky (pocta istej mafiánskej hre z 2002).

## Užitočné
- Ovládanie: A/D pohyb, Space/W skok, S/Ctrl šmyk, C/Alt plíženie, F zneškodnenie/klopanie, pravé tlačidlo/E klobúk, ľavé tlačidlo streľba,
  R prebíjanie, Shift spomalenie, Esc pauza.
- Fasády obchodov na ulici sú 128×88 px (dvere ~80 px) – mafián s klobúkom má ~75 px, dvere a otvory musia byť vyššie.
- README je v angličtine s bannermi z `docs/media/h_*.png` (bez gifov). Pri nových zdrojoch (zvuky, hudba, fonty) doplniť sekciu Credits.
