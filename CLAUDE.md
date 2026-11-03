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
- **Postupne, nie všetko naraz.** Jeden krok → otestovať → hotovo.
- **Nové vizuálne veci (dizajn, sprite, efekt, UI): najprv mi ukáž pár možností (obrázky/náhľady), až potom to daj do kódu.**
- Zvuky: keď sa mi niečo nepáči, nepýtaj sa zbytočne – ak poviem „daj X“, sprav X. Nedávaj na výber tam, kde som povedal konkrétne.
- **Nepíš mi git príkazy** (ani PowerShell na commit/push) – git si robím sám.
- **Nikdy sám necommituj ani nepushuj. Git robím len ja.**
- `project.godot` upravuj len keď je Godot zavretý (inak ho Godot prepíše).
- Testovacie skripty (testboti) nikdy nenechávaj v `project.godot` ani v repe.
- Komentáre v kóde píšem **po slovensky**; pri Godot API sa hodí odkaz typu `## Godot docs: classes/class_tween`.

## Štruktúra
```
audio/        sfx.gd (trieda Sfx), sfx/*.wav (efekty, varianty meno_2/_3), amb/*.ogg (slučky prostredia), music/*.ogg (hudba)
characters/   ricco/ (hráč, focus/ = spomalenie), gangster/ (mafiáni z častí tela), don/, lou/ (Big Lou – boss kapitoly II, dynamit), iron_mike/, murphy/ (bossovia kapitoly III)
effects/      burst.gd (Burst – čiastočky), explosion.gd (trieda Explosion – výbuch: ohnivá guľa, tlaková vlna, záblesk, sadza, zranenie, reťaz sudov), art/
levels/       level1/ (ulica → reštaurácia → kuchyňa → sklad → herňa) + cellar (tunely), level2/ (kapitola II – cintorín + docks = prístav + coldstore = mraziareň),
              level3/ (kapitola III – intro = čln pri Soche slobody, street = nábrežie + ulica a strechy v jednej mape, roofs = ďalšie strechy k stanici, train = nadzemka, club = jazzový klub, club_back = zákulisie, hotel = hotel Majestic – servisné krídlo, hotel_gala = gala a strecha, tower = veža Iron Mikea, chase = naháňačka taxíkom a Queensboro Bridge),
              level4/ (kapitola IV – pier = mólo a rybárska búda, cave = pašerácka jaskyňa, boathouse = lodenica s výťahom, cellar = pivnica vily), range/ (strelnica)
world/        stealth/ (light_zone – svetlo/tma), fx/ (dážď, neón, hat_lamp, speakeasy_door, ladder – rebrík na stene, awning – markíza-trampolína, clothesline – šnúra s kladkou…), npc/ (guest, rat, dog – pes na reťazi, pigeons – holuby), fx/lighthouse_beam (otáčavý lúč majáka),
              coldstore/ (hook_rail – koľajnica s hákmi, carcass – visiace mäso = kryt, conveyor – pás),
              ship/ (storm – blesky a hrom, roll – hojdanie mora a mrakov, ship_crate – debna/kryt, ship_barrel – sud whisky,
              deck_fire – oheň na palube, crane – žeriav so sieťou, falling_cargo – debna zo siete)
weapons/      pistol/ (bullet, magazine_drop, záblesky), hat/ (hat_projectile – hod klobúka)
props/        ammo/ (krabička nábojov), food/ (jedlo so sebou + lekárnička, food.gd = Food), target/
ui/           hud, boss_bar (pás zdravia bossa, značky fáz), dialog, main_menu, pause_menu (menu_pages: nastavenia, AUDIO), cursor, fonts (Tiny5), retro_filter
settings/     game_settings.gd (GameSettings – ukladá do user://settings.cfg, aj hlasitosti [audio])
tools/        build_level1.gd (generuje level1.tscn aj cellar.tscn), build_level2.gd (cintorín), build_docks.gd (prístav), build_coldstore.gd (mraziareň), build_margaret.gd (loď + záver kapitoly epilogue.tscn),
              build_level3.gd (kapitola III – len úvod intro.tscn), build_ricco_frames.gd (SpriteFrames Ricca)
docs/media/   obrázky do README (bannery v jednotnom „S2“ štýle)
```
- **Level 1 a pivnica sa generujú skriptom**, needitovať `.tscn` ručne:
  `godot --headless --path . --script res://tools/build_level1.gd`. Bludisko pivnice je textová mapa (const MAZE) v tom súbore.
  Level 2 (cintorín) rovnako: `godot --headless --path . --script res://tools/build_level2.gd`,
  prístav: `godot --headless --path . --script res://tools/build_docks.gd`,
  mraziareň: `godot --headless --path . --script res://tools/build_coldstore.gd` (generuje aj `tiles_cold.tres` s vlastnými dátami „ice“),
  loď: `godot --headless --path . --script res://tools/build_margaret.gd` (generuje aj `tiles_ship.tres` a `epilogue.tscn`),
  kapitola III: `godot --headless --path . --script res://tools/build_level3.gd` (len úvod `intro.tscn`; nábrežie a ulica `street.tscn` píše Claude priamo).
  Nové obrázky treba pred generátorom naimportovať (otvoriť editor alebo `godot --headless --path . --import`).
- **Nové scény (od nadzemky) píše Claude priamo ako `.tscn`** – Python zapisovač `tscn.py` + skript scény (napr. `make_train_scene.py`)
  v projekte mimo repa (`ricco-v2-kapitola3-nadzemka/_art_src/`). Používateľ nemá nič spúšťať: len otvorí Godot (nové obrázky
  a zvuky sa naimportujú samé) a hrá. Uzly bez `unique_id` sú v poriadku – Godot ich doplní pri uložení scény.
- Obrázky sú v **Git LFS**.

## Čo je hotové (kapitola I hrateľná)
- Pohyb: coyote time, jump buffer, variabilný skok, chytenie hrany, wall jump, šmyk po bruchu, plíženie.
  **Podkopnutie:** šmyk po bruchu (od `slide_trip_speed`) do mafiána ho zvalí na chrbát (`Gangster.trip`, leží `trip_time`, nestrieľa,
  dá sa zložiť F), potom vstane a ide po Riccovi.
- Streľba, obmedzené zásobníky (prázdne padajú a odrážajú sa), spomalenie (duch Dona), klobúk (hod omráči / zhasne lampu, vracia sa), zdravie.
- Stealth: svetlo/tma, zneškodnenie zozadu (F, dosah `takedown_range` 44 px), mafiáni s hliadkami, baterkami, rôznymi zbraňami.
  Tma nerobí Ricca neviditeľným: mafián s `needs_light` ho pred sebou rozozná do `DARK_SIGHT` (80 px) aj prikrčeného;
  zakrádanie (C) len tlmí kroky – za chrbtom počuje bežné kroky do `HEAR_STEPS` (90 px), potichu `close_sense` · 0,45. Kryt skryje.
- **Kapitola I:** daždivá ulica (neón, vyhadzovač, intro I1) → súkromná oslava v reštaurácii (hostia s náhodnými tvárami; keď ťa uvidia na svetle,
  majú „!“ a privolajú mafiánov; hat_lamp; z trámu nad barom vedie **vetracie potrubie** – šmyk dnu, plazenie, vypadne na policu nad kuchárom) → kuchyňa, sklad → **herňa za oceľovými dverami s tajným klopaním** (mafián ukáže rytmus,
  Ricco klope F: KLOP KLOP … KLOP KLOP KLOP) → **pivnica = samostatná mapa, bludisko tunelov** (krv, potkany, baterky) → Donov úkryt, cutscéna, prvá prestrelka.
- Checkpointy (`Level1.checkpoint`, ≥3 = pivnica).
- **Kapitola II – Wharf Rats** (rozrobená): **level 2 = cintorín v noci, Donov pohreb**
  (`levels/level2/level2.gd`, statické `Level2.checkpoint` atď., `Level2.reset()`). Koniec kapitoly I vedie rovno sem, v menu je aj CHAPTER II.
  Ricco má derringer + spomalenie; celý cintorín je tma (`dark_area`). Úvod: titulok → **noviny** (ReadCard, `art/street/newspaper.png`) →
  **ulica pred cintorínom** (x < 0, `STREET_X` −76): autá Rodiny (`sedan*.png` 190×78, `hearse.png` 236×78 – mierka postáv, z `c13/make_cars.py` mimo repa; `c13/make_street.py` už nespúšťať, prepísal by ich malými), pohrebák, šofér fajčí pod lampou (`Driver`, žeravá cigareta + dym –
  `_driver_smoke`), zamknutá brána (`GateBars`, nad ňou `Edge`) so strážou s palicou hneď za ňou (`GateGuard`); dnu sa ide po strome –
  tri konáre (`BRANCHES`, jednosmerné plošiny), najvyšší vedie ponad bránu. Po prelezení `Level2.street_done` → po smrti `SpawnIn`.
  Hrobník s lampášom (úkryt v otvorenom hrobe), kôlňa s **revolverom .38**
  (F výmena za derringer), mauzóleá ako plošiny, na streche duch komentuje vlastný pohreb (kamera sa posunie k hrobu, kňaz povie modlitbu, **truhla sa spustí do hrobu** –
  `Coffin` nad `CoffinPit`, smútiaci hodia ruže), potom mafián odhodí **zápalky Fontana Shipping – Pier 13**
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
  **Loď S.S. Margaret – finále** (`levels/level2/margaret.gd extends Level2`, `margaret.tscn`, checkpoint 11, **bossfight v2**; paluba
  2080 px, voľná – len pár pevných debien): paluba v búrke (lejak, blesky `world/ship/storm.gd` so signálom `flashed`, hrom, hojdanie
  mora `roll.gd`, vlny cez zábradlie – len efekt). **Vysoký trup** (9 riadkov dlaždíc, dva rady okienok, červený pás na y ~96–112,
  vlny `WavesFront` na y 92 – čiara vody ~104 px pod palubou). Kajuta na korme (príchod, `Spawn11`) → záchranný čln (plošina −48) →
  debny = kryt (`CoverN`, skupina `ship_cover`, `world/ship/ship_crate.gd` – guľky ich postupne rozbijú, horné debny spadnú, niekedy
  vypadnú náboje) len pri x 360 a 1150, **oceľové kryty** (`build_margaret.gd _steel`: skrine LIFE BELTS `SteelLocker1/2` x 650 a 866, 40×32 – za nimi sa Ricco skrčí s C, guľky ich nerozbijú; vetrák `Vent1` x 1214, 18×40; obrázky `steel_locker.png`, `vent_cowl.png` z `c13/make_steel.py`; medzi skriňou a pätou žeriavu nechať aspoň ~40 px, inak sa poskokom zasekne lúč na hranu), vyvýšený nákladný poklop (`CargoHatch` 470–610, jednosmerná plošina −26, hrany na vrstve 32),
  sudy RYE (`Barrel1–3`, `world/ship/ship_barrel.gd`, vrstva 4; `Barrel1` = miesto dopadu zrúteného ramena) → **vysoký žeriav**
  (`crane_tall.png` 112×340 a `boom_long.png` 420×20 skladá `c11/make_ship_tall.py` mimo repa z pôvodných `crane.png`/`boom.png`;
  stred x 1000, čap (1000, −326), rameno 404 px, takmer vodorovne; `CraneArm` = `world/ship/crane.gd` s `Boom`, `Rope`, `Net`,
  `Shadow`, `landing()` ≈ x 761) → nákladný poklop `HatchSpot` x 1270 (tadiaľ lezú poskoci) → **dlhé krídlo mostíka** vysoko nad
  palubou (`wing_long.png` 112×40, `WingFloor` jednosmerná, y −176, `LouSpot`; pult `CraneConsole` + páka `Lever` v skupine
  `crane_lever`) → nadstavba `bridge_tall.png` 288×312 od x 1504 (spodné + nové stredné poschodie = pevný blok `House` −176…0,
  kormidlovňa `Wheelhouse` −248…−176) → prova. Dvere na lodi sú 80 px (mafián ~75 px).
  **Kamera v boji:** `_zoom_to()` – PhantomCamera zoom 0,8 (800×450 sveta) a stred vyššie (`Ricco.camera_bias.y` = −112, inak −20;
  `ricco.gd` ho pripočíta k follow_offset), kým je Lou na krídle, kamera sa posúva k nemu (`camera_bias.x`, najviac `LOU_BIAS` 230).
  Po smrti Lou späť na 1,0. `SHIP_MAP` = (0, −420, 2080, 560).
  **Big Lou** (`characters/lou/big_lou.gd`, `class_name BigLou`, `big_lou.tscn`, časti tela v `characters/lou/`, ~88 px, návrh A „Don Lou“
  z `c4/make_lou_don.py` mimo repa; samostatný skript, nie Gangster – iné rozmery kostry): modrý prúžkovaný dvojradový oblek, biele kamaše,
  fúzy, krémová fedora s bordovou páskou, cigara (dym), vesta (`vest_factor` 0,25 do trupu, hlava a nohy naplno, signál `vest_hit`),
  Thompson s bubnom (`thompson_drum.png`, dáta `tommy.tres`). Signály `health_changed`, `vest_hit`, `threw`, `stage(name)` (réžia pre
  level: enraged, crane_drop, wing_hit, wing_break, burnt_up, charge, dazed, reload, dying), `died`. Pás zdravia `ui/boss_bar.gd`
  (značka na tretine). **36 HP**: na mostíku nejde pod 12, pád z krídla ho zhodí na 12, na palube 12 → 0.
  `phase`: 0 poskoci, 1 mostík, 3 paluba (= checkpoint `Level2.lou_phase`; staré 2 sa berie ako 1).
  **0. fáza – poskoci** (`margaret.gd _henchmen`, `WAVES`): keď Ricco prejde x 420 (`FIGHT_START_X`), Lou hvizdne a z krídla ukazuje
  na Ricca (`command()`, stav COMMAND, nezraniteľný – guľky sa odrážajú). Dve vlny po troch (revolver = coppola s revolverom .38 – `REVOLVER_MAN`, coppola, slugger; **Thompson má na lodi len Lou**) – vyliezajú
  z poklopu (spod paluby, z −1 za trupom) a z dverí kajuty na korme, hneď `alarm()` + `hear()`; `respawn_time` 0. Všetci majú
  `Gangster.relentless` = stále agro: keď Ricca nevidia (ďaleko, za krytom), každých 0,8 s `hear()` na jeho miesto a bežia tam.
  **1. fáza – mostík** (`enrage()` → rev na krídle → `start(true)` = nabitie Thompsonu, ukáže sa pás): **jednou rukou páka žeriavu**
  (`_crane_ai`, zadná ruka na páke – `_pull_lever`): sieť ide za Riccom → tieň 0,8 s → debna (`falling_cargo.gd`: 2 kúsky pizze;
  inak ostane ako **dočasný kryt** s 5 HP – Louove guľky ju po pár zásahoch rozbijú; skupina `crane_crate`, najviac 4, ďalšie sa
  rozletia) každých 3,6–5,2 s; **druhou rukou Thompson** (mieri → dávka). **Pod krídlom** (x > krídlo − 10) nestrieľa – hodí
  dynamit, ktorý dopadne pred krídlo a skotúľa sa k Riccovi. Dynamit aj spoza obrazovky do 760 px (strieľa len na obrazovke).
  **Dynamit sa dá hodiť späť** (`dynamite.gd`: po dopade `InteractSpot` „THROW“ – F; šnúra 2,9 s na mostíku / 2,5 s na palube;
  `throw_back()` – oblúk na `dynamite_target()` bez kolízií, výbuch pri Lou 4 HP + `dynamite_hit()`). Na mostíku každý zásah
  poškodí krídlo (`wing_hit` – trasie sa, tmavne), po 3 (`wing_hp`) sa **krídlo odlomí** (`wing_break` → `margaret.gd _break_wing`:
  `WingFloor` preč, krídlo spadne na palubu ako trosky, výbuch, mostík horí, loď začne horieť, kúsok pizze) a Lou letí dole
  (stav BLOWN, pripálený), leží, vstane, rev (`burnt_up`).
  **Žeriav bez obsluhy** (`_crane_due`): keď sú Ricco aj Lou vpravo od `landing() + 50`, blesk do kabíny (`_crane_down`) → rameno
  sa zrúti na `Barrel1` (výbuch, stály oheň + dva dočasné) → **aréna sa zúži**: neviditeľná stena `ArenaWall` pri ramene (aj pre
  guľky; Lou `walk_span.x` za ňou), po smrti Lou zmizne. Sieť spadne, roztrhne sa a **debny z nej ostanú na palube ako skutočné
  debny** (`crane.gd _spill_crates`, kolízia), 2× náboje, pizza. Checkpoint na palube: krídlo aj žeriav už ležia, Ricco začne za ramenom.
  **2. fáza – na palube** (`phase` 3, `deck_span`, vesta 0,5, mierenie 0,5 s): kráča k Riccovi (debny v ceste rozbije, cez pätu žeriavu
  prekročí), dávky, po 3 dávkach **prebíja bubon**, **trojitý dynamit** (každý sa dá hodiť späť), **rozbeh** (dupne 2×, hlava dole,
  230 px/s): stojaceho Ricca zrazí (2), šmyk do neho = podkopnutie → padne na tvár, **omámený** 2,2 s (hviezdičky, vesta nepomáha);
  náraz do steny / päty žeriavu → omámený 1,8 s. Keď Ricca zraní, **smeje sa**. Klobúk mu zhodí fedoru a zarazí ho.
  **Smrť:** zapotáca sa, posledná dávka do neba, Thompson vyletí (pickup), na kolená, na tvár → zo saka sa vykotúľa dynamit → veľký
  výbuch (bez zranenia), z Lou ostane klobúk, ktorý sa znesie ako list → hláška ducha → útek z lode (`margaret.gd _on_lou_died`).
  Duch hlási: úvod, poskoci, žeriav, dynamit (hoď ho späť), krídlo, „je dole“, žeriav padá, debny, rozbeh, hviezdy, sud.
  **Útek z lode** (variant A, `Level2.escape_stage`: 1 = Lou padol, 2 = list prečítaný; po smrti Ricco začne pri dverách – `Spawn12`
  x 1615): duch pošle Ricca do **kajuty Lou** pod mostíkom – ľavé dvere spodnej nadstavby (nadstavba je 432 px široká – `HOUSE_W`; `_open_house()` zúži kolíziu `House`,
  aby sa pred dvere dalo prejsť; `InteractSpot` ENTER). Kajuta je pod mapou (`cabin.png` 640×360 na y 800, `CABIN_MAP`, podlaha
  y 1100, `CabinLamp` sa kýve, oheň nad stropom a dym pridá `_cabin_fx()`, dážď a iskry sa skryjú, búrka stíšená). Na stole **list od „M.“**
  (`letter_big.png`, hotel Majestic, Central Park West, New York – Lou bol len poskok, „M.“ vie o tučniakovi z pizzerie) cez `ReadCard`
  → kotol vybuchne → späť na palubu: **odpočet 46 s** k záchrannému člnu (pás hore „GET TO THE LIFEBOAT“), ohne na ceste
  (`ESCAPE_FIRES`), **horiace trámy** (`debris.png` – najprv tieň, kto stojí, na toho padá, 1 kúsok pizze), výbuchy za chrbtom (`BLASTS`),
  otrasy, loď sa nakláňa (`roll.gd lean_deg`, skupina `ship_roll`). Čas vyprší → loď vybuchne (smrť). Páka `DavitLever` pri člne (F) →
  Ricco skočí do člna, čln (`Lifeboat/Boat`, laná `RopeL/R` sú čiary, davity zvlášť) sa spustí za trup → Margaret vybuchne → záver.
  **Záver kapitoly** (`levels/level2/epilogue.gd`, `epilogue.tscn` generuje tiež `build_margaret.gd`, bez kamery): svitanie na mori,
  Ricco v člne, v diaľke horí Margaret (`margaret_far.png`, 3 snímky) → výbuch, potopí sa → duch v člne, hlášky o „M.“ a New Yorku →
  END OF CHAPTER II / WHARF RATS → rovno kapitola III (`levels/level3/intro.tscn`, `Level2.reset()` + `Level3.reset()`). Obrázky kreslí `c9/make_escape_art.py` mimo repa.
- **Kapitola III – The Big Apple** (hotová, nápady a rozhodnutia v projekte `ricco-navrhy/kapitola3_napady.md`):
  „M.“ = **Margaret Vito, Donova vdova** (odhalí sa na konci kapitoly). Poradie: úvod → nábrežie → ulica, požiarne schodisko a
  strechy so šnúrami (návrh A+C) → nadzemka → jazzový klub v Harleme → hotel Majestic → boss **Iron Mike** na rozostavanom
  mrakodrape (má **Winchester 1897**, Ricco ho získa až po ňom) → naháňačka taxíkom a boss **Chief Murphy** na Queensboro Bridge. Nové: **Colt 1911** (hlavná nová zbraň),
  Thompson s vzácnymi nábojmi, rozdelené mierenie pre bočné zbrane, odstreľovač (pušku Ricco nezíska), brokovník s luparou,
  policajti, výťah, šnúry s prádlom, prostredie zabíja, ricochet od panvice. Ľudský štít je odložený.
  **Úvod** (`levels/level3/intro.gd`, `intro.tscn` z `build_level3.gd`, bez kamery): noc, Ricco v člne z Margaret vesluje popri
  Soche slobody (`liberty.png`, fakľa svieti), za ňou Manhattan, trajekt, nápis CHAPTER III / THE BIG APPLE, myšlienky,
  hlášky ducha → nábrežie. Esc / Enter úvod preskočí.
  **Základ kapitoly** (`levels/level3/level3.gd`, `class_name Level3` – statické `checkpoint`, `arrived`, `barks`, `reset()`):
  výbava revolver, lupara, Thompson len s 20 nábojmi (`TOMMY_START_AMMO`, bez rezervy; `Level3.tommy_ammo` sa prenáša medzi časťami).
  Spoločné veci častí sú v `Level3`: `_setup(map)` (hráč, výbava, tma, spawn), `_fade_in`, `_tick_say`, `_go_next`, `_to_be_continued`.
  **Nábrežie + ulica a strechy = jedna mapa** (`levels/level3/street.gd extends Level3`, `street.tscn` píše `_art_src/make_city_scene.py`,
  obrázky `make_ch3_city_art.py` + `city_bldg.py` – v projekte `ricco-v2-kapitola3-mesto/`, mimo repa; bez načítavania medzi nimi):
  chodník a promenáda y 0, hladina rieky y 104, dno y 200. **Rieka** 0–448: Ricco stojí v záchrannom člne (`lifeboat_boat.png`,
  jednosmerná paluba), **železný rebrík** (`world/fx/ladder.gd`, skupina `ladders`, `length`, `side`) na čele nábrežnej steny →
  **promenáda** 448–1080 (dve lampy = svetlo, lavička, strážnik s revolverom a baterkou) → rovno **ulica** 1080–3060 (posun `SX` 1080).
  Prístav (`docks`) hrá z rieky (pozičný zvuk – v ulici dozneje), lodná siréna len po x 1600. Domy za ulicou sú parallax bez
  opakovania (`art/city/backdrop.png`, zľava sa znižujú – koniec bloku pri rieke).
  **Mierka domov = ľudská (návrh A, `ricco-navrhy/kapitola3/mierka_domov.png`):** poschodie 128 px, prízemie 168 px, okno 38×70,
  dvere 40×94 + nadsvetlík 18 px, markíza na −128 (plocha −110), zábradlia 40–42 px, lampa 150 px, búdka schodiska na streche
  70×116. Mafián má ~75 px, Ricco ~40 px – Ricco je tučniak a domy sú pre ľudí.
  **Rebrík** (Ricco stav `LADDER`): skok pri rebríku (zo zeme, z člna, z hladiny) = chytí sa, vo vzduchu pri páde sám, S pri
  vrchu = zlezie; W / medzerník hore, S dole (`ladder_speed`), smer od steny = pustí sa, so skokom odskočí; hore sa vyšvihne
  animáciou `climb` (ako pri chytení hrany), dole sa pustí. Na rebríku nestrieľa. Animácia `ladder` (`sprites/ladder.png`, 4 snímky 64 px,
  bokom čelom k stene, zarovnaná ako `hang`; kreslí `_art_src/make_ladder_anim.py` mimo repa, návrh `ricco-navrhy/rebrik/`) –
  snímok sa mení každých 8 px prelezenej výšky, keď stojí, ostane.
  **Ulica a strechy** (súradnice x ďalej sú od začiatku ulice, v mape + 1080; pôvodný návrh `strechy_AC_vyssie.png`):
  domy A pizzeria (2 poschodia, strecha −424), B Chop Suey (1, −296), C holičstvo (3, −552), D lahôdky (2, −424) – fasády sú
  pozadie, strechy a plošiny schodísk sú jednosmerné plošiny. Dážď, neóny, výklady a lampy = svetlo. Cesta: tri stĺpce debien
  (28/56/84 px) → **markíza = trampolína** (`world/fx/awning.gd`, Ricco `bounce(v)`) → požiarne schodisko (plošiny −168 a −296 +
  rebríky) → strecha A (holuby – ukážka) → **šnúra s prádlom** (`world/fx/clothesline.gd`: kladka = `hook_trolley.gd`,
  Ricco ju chytí ako hák na mäso, zvezie sa dole, na konci ho pustí, kladka sa vráti) → strecha B (vodná nádrž, na striežke
  krabička nábojov = tajomstvo, brokovník) → rebrík na boku C (stena `WallC`) → strecha C (holuby, strelec pri dverách so žiarovkou)
  → druhá šnúra → strecha D (brokovník) → dvere schodiska → ďalšie strechy (`_leave_door(ROOFS, 5)`). Z ulice sa späť hore ide
  po schodisku pizzerie alebo lahôdok (rebrík z ulice končí 20 px nad zemou). Checkpointy 0 = čln, 1 = promenáda, 2 = začiatok
  ulice (myšlienky `StreetArrive`), 3 = strecha A, 4 = strecha C. Plagát WANTED („Penguin $500“).
  **Holuby** (`world/npc/pigeons.gd`): keď Ricco prebehne alebo vedľa nich dopadne, vyletia (`pigeon_flap`) a `Gangster.noise`
  privolá mafiánov v okolí; zakrádaním sa dá prejsť aj pomedzi ne. Signál `scattered` (hláška ducha).
  **Policajti:** gangster `kind = "cop"` (časti tela `characters/gangster/cop/` prefarbené z coppola – `_art_src/make_cop_parts.py`),
  revolver, baterka, `whistle = true` – keď Ricca prvý raz zbadá, zapíska (`whistle.wav`) a `alarm()` všetkým do `WHISTLE_RANGE`.
  Obušok zatiaľ nemajú. Obrázky ulice `_art_src/make_ch3_street_art.py`, zvuky `_art_src/make_ch3_sfx.py`
  (v projekte `ricco-v2-kapitola3-strechy/`, mimo repa).
  **Strechy k stanici** (`levels/level3/roofs.gd extends Level3`, `roofs.tscn` píše `_art_src/make_roofs_scene.py`,
  mapa `ROOFS_MAP` 3840 px, ulica y 0): päť domov E–I, medzi nimi uličky s rebríkmi. **E** – reklamný billboard „LUCKY STAR
  CIGARETTES“ (vymyslená značka) s tromi reflektormi (`hat_lamp.gd`, skupina `billboard_lamps` – zhasnúť klobúkom/strelou,
  keď sú všetky zhasnuté, hláška), pod ním strážca s Tommym, na billboard vedie rebrík (holuby, tajné náboje). **F** – uličku
  premosťuje **doska** (`levels/level3/roof_plank.gd`: pri behu vŕzga `plank_creak` a praskne → `Gangster.noise`, spadne a o 5 s
  je späť; plížením prejde), holubník s chovateľom (Guest – svedok) pod lampou, mafián otočený preč. **G** – krajčírska dielňa:
  dnu cez **svetlík** (`levels/level3/skylight.gd`: rozbije ho šmyk alebo tvrdý dopad, hluk dole) alebo oknom z požiarneho
  schodiska; vnútri prierez (`GWall` zmizne, keď je Ricco v `ROOM`), šijacie stoly (plošina + kryt), balíky látok, lampa;
  vydieranie krajčíra (Collector, Muscle, skorumpovaný policajt CrookedCop – rozhovor `SHAKEDOWN`, spustí ho `ShopVoices`
  na streche), na streche hliadka. Keď je celá partia mŕtva, krajčír poďakuje. **H** – vysoká vodná veža (rebrík) a najdlhšia
  šnúra s prádlom. **I** – stanica Delancey St: markíza (rebrík, jednosmerná plošina), lampy, dvaja policajti na nástupišti.
  Spúšťače `TrainCall`/`TrainCall2` → vlak príde zľava a zabrzdí (Tween EASE_OUT QUAD, `ARRIVE_TIME`), zvonček, „ALL ABOARD“,
  potom `Board` na streche vozňa → `_go_next(TRAIN, 9)`. Checkpointy 5 = za dverami schodiska, 6 = za doskou, 7 = strecha
  dielne, 8 = požiarne schodisko dielne. Repliky postáv nad hlavou `Level3._speak(who, text, dy)`.
  Obrázky `_art_src/make_ch3_roofs_art.py`, zvuky `plank_creak`, `wheel_squeal`, `train_horn` `_art_src/make_ch3_more_sfx.py`.
  **Ľudská mierka (november 2026):** zadné fasády E–H (prízemie 168 px so zadnými dverami 94 px, poschodia 136 px, G 130 + 142 –
  horné poschodie = dielňa, H 3 × 144; výšky striech ostali) a vnútro dielne kreslí `make_ch3_roofs_city_art.py`, scénu teraz píše
  `make_roofs_scene.py` v projekte `ricco-v2-kapitola3-mesto/` (búdka schodiska, koše, lampa na nástupišti a požiarne schodisko
  dielne sú z `art/city/`).
  **Nadzemka** (`levels/level3/train.gd extends Level3`, `train.tscn` píše `_art_src/make_train_scene.py`, návrhy
  `nadzemka_A_strecha.png` + `nadzemka_B_vozen.png`, náhľad `ricco-navrhy/kapitola3/nadzemka_mapa_nahlad.png`): Third Avenue El do Harlemu.
  Vlak v scéne stojí, ubieha svet: `Parallax2D.autoscroll` (skupina `train_scroll` – mesto, domy pri trati, konštrukcia nadzemky),
  `_speed` 1 → 0 pri brzdení. Podlaha vozňov y 0, strechy y −150, **šesť vozňov** po 400 px s medzerami 32 px (0, 432, 864,
  1296, 1728, 2160; mapa 2764 px), v medzerách plech na podlahe a rebrík na čele ďalšieho vozňa;
  všetkých šesť vozňov sú **prierezy** (1, 2, 4 = osvetlené osobné s cestujúcimi, v 2 a 4 mafián – `Car2Goon`, `Car4Goon`;
  kým je predná stena zatvorená, `Gangster.set_wall_cover` schová baterku a „?“/„!“ mafiánov vnútri): strop, čelné steny s dverami (50 px) a predná stena `CarNWall`, ktorá zmizne, keď je Ricco dnu
  (`WALLS` v train.gd; strecha `CarNRoofStrip` ostane).
  **Nosníky mostov** (`_spawn_beam`, každé 3–4,6 s, keď je Ricco na streche; neskôr občas dva za sebou): letia doľava `TRAIN_SPEED`,
  spodok 30 px nad strechou – šmyk (24 px) a skrčenie za vetrákom (22 px, vetráky sú kryt na vrstve 32) prejdú, postava (38 px) nie:
  2 kúsky zdravia a odhodí dozadu. Pred príletom zvonček a blikajúci „!“ na pravom okraji. Mafiáni na streche, čo o Riccovi
  nevedia, sa prikrčia (`rig.scale.y`); kto mieri/strieľa/beží (stavy AIM–RECOVER), toho nosník zloží (prostredie zabíja).
  **Vozeň 3:** vľavo tma (rozbité žiarovky), sediaci cestujúci a mafián s luparou na hliadke; v strede svetlo (`LightCar3`,
  x 1010–1140) a stojaci cestujúci (Guest – zbadajú, skríknu, zásah = výčitka ducha); ponad nich **remienky**
  (`levels/level3/train_strap.gd` – statický „hák“, úchyt 128 px nad podlahou, 44 px od seba, zo zeme nedočiahne → z lavice na x 992;
  kto visí, je nad hlavami a mimo svetla); vpravo v tme **ochrankár v smokingu** (`kind = "tux"`, `weapons/pistol/pistol.tres` =
  Colt 1911, stojí chrbtom k Riccovi pri dverách) – po ňom ostane Colt (výmena za revolver F). Lavice: sedák = jednosmerná
  plošina 18 px, opierka = kryt. Cestou sa dá aj po streche vozňa 3 (nosníky, strelec).
  **Vozeň 2 – expres:** spúšťač `ExpressStart` → po vedľajšej koľaji dobehne expres (`Express`, z −14, strecha y −178 na vrstve
  256 – train.gd prestaví strelcom `collision_mask` na 256 a do príchodu ich vypne), strelci Tommy + 2× revolver
  (`walk_speed` 0, aby nezišli zo strechy); dobehne (EASE_OUT), ide vedľa 14 s, odíde (EASE_IN, `train_horn`) – keď sú strelci
  mŕtvi, skôr. Nosníky zasiahnu aj ich. Po checkpointe ≥ 10 sa expres nezjaví.
  **Vozeň 4 – zákruta:** `CurveStart` → 9 s náklon kamery (`Camera2D.ignore_rotation = false`, Tween `pcam.rotation`),
  `wheel_squeal`, odstredivá sila tlačí Ricca na streche dozadu (`move_and_collide`, `CURVE_PUSH` 70 px/s – plížením neprejde,
  prikrčený za vetrákom / šmyk / rebrík drží); nosníky v zákrute redšie.
  **Vozeň 5 – pošta:** tma, vrecia (kryt) a debny (pevné), Tommy s baterkou na hliadke, mafián pri dverách; cez otvorené bočné
  dvere občas prebehne svetlo pouličnej lampy – LightZone `MailSweep` ide z x 2058 na 1768 rýchlosťou vlaku, medzi lampami
  je zaparkovaný na y 400.
  **Vozeň 6 – rukojemník:** lavice (kryt), svetlo; v kabíne kľačí motorovodič (Guest, `loop`, nie svedok) a za ním únosca
  (tux, Colt, 2 životy, stojí). Riccove guľky motorovodiča zasiahnu (mieri sa nad neho). Keď únosca padne, motorovodič zabrzdí;
  keď padne motorovodič, zabrzdí „mŕtvy muž“ (výčitka ducha).
  **Stanica:** brzdy, stanica 125 St (`station.png`, 800 px) sa prisunie spoza okraja mapy a zastane na x 1964 (rovnomerné
  brzdenie, `BRAKE_TIME` 6 s), potom zmiznú `FrontStop` (čelo vlaku od strechy po podlahu) a `Car6WallR` → von na nástupište →
  `ExitStation` → klub (`_leave_door(CLUB, 14, false)`). Checkpointy 9 = strecha vozňa 1, 10 = pred vozňom 3,
  11 = pred vozňom 4, 12 = pred vozňom 5, 13 = pred vozňom 6 (spúšťače `CheckpointN` dole aj `CheckpointNRoof` hore).
  Smrť: `Level3.part_for(checkpoint)` – 2–4 ulica, 5–8 strechy, 9–13 nadzemka, 14–16 klub, 17–21 zákulisie, 22–25 hotel,
  26+ gala.
  **Výbava medzi časťami:** `Level3.carried` (čo mal Ricco pri odchode – napr. Colt namiesto revolvera) a `tommy_ammo`
  (hľadá Thompson vo výbave, nie index 2). `_leave_door(path, cp, sound := true)` = odchod dverami so stmievačkou.
  Obrázky `_art_src/make_ch3_train_art.py`, cestujúci + tux + oprava zadnej ruky policajta `_art_src/make_ch3_passengers.py`,
  zvuky (`train_rumble` slučka, `train_bell`, `beam_whoosh`, `beam_clang`, `brakes`) `_art_src/make_ch3_train_sfx.py`
  (v projekte `ricco-v2-kapitola3-nadzemka/`, mimo repa).
  **Jazzový klub The Blue Canary** (Harlem, Lenox Ave – boss Velvet Sal). Scény píšu `_art_src/make_club_scene.py`
  a `make_club_back_scene.py`, obrázky `make_ch3_club_art.py` (exteriér, sála), `make_ch3_club_back_art.py` (zákulisie,
  pivnica, herňa, kancelária, dokumenty z trezoru), `make_ch3_club_people.py` (hostia, čašníci, kapela, Sal = kind `sal`)
  – všetko v projekte `ricco-v2-kapitola3-klub/` mimo repa. Spoločný základ `levels/level3/club_level.gd` (`class_name ClubLevel
  extends Level3`): poplach = mafián v klube si Ricca všimne (stav AIM…RECOVER), Riccov výstrel v klube alebo pád lustra →
  hudba `intensity`, kapela (skupina `band`) prestane hrať, sediaci hostia (`seated`) sa skrčia, stojaci/čašníci/kapela
  (`runners`) utečú k východu (`exits`), posily na značkách `reinforce` (najbližšie k Riccovi, aspoň 260 px).
  **Časť 5 – `club.gd`/`club.tscn`** (checkpointy 14 stanica 125 St, 15 vnútri, 16 lávka): predné dvere strážia dvaja
  vyhadzovači (`passive`, kind `bouncer`) – dvere sú pevné, kým je niektorý do 90 px od nich; mačka na smetiaku
  (`alley_cat.gd`, zobudí ju beh, aj klobúk/guľka zďaleka) ich na ~15 s odláka. Zasiahnutý vyhadzovač naštve oboch.
  Ďalšie cesty: rebrík na konštrukciu nadzemky → požiarne schodisko → okno kabíny na balkóne; uhoľný poklop
  (`club_hatch.gd`, F) → tunel (plaziť sa) → kotolňa s kuričom → rebrík za bar. Sála: lampičky na stoloch sú `hat_lamp`
  (skupina `table_lamps`), hostia vidia 80 px; reflektor (`club_spotlight.gd`) prechádza sálou, keď osvetľovač (Operator)
  Ricca zbadá, sleduje ho, po jeho smrti svieti na pódium, klobúk ho zhasne. Luster (`drop_weight.gd`, heavy) nad stolom
  mafiánov: guľka/klobúk do lana → zabije do 42 px, zhasne, ostane ako kryt, spustí poplach. Rekvizitný ťah: háky
  `train_strap.gd` (nový export `texture` = `rig_hook.png`) na y −275, 44 px od seba, lávka (truss) v strede, catwalk nad
  pódiom → `ExitBackstage` (`club_loud` = či bol v sále poplach).
  **Časť 6 – `club_back.gd`/`club_back.tscn`** (checkpointy 17 zákulisie, 18 šatne, 19 pivnica, 20 šachta pri herni,
  21 strecha): vrecia s pieskom (`drop_weight.gd`), šatňa speváčky (bubon do Thompsonu 50 nábojov – `weapon_pickup` z kódu,
  telegram READ), klopacie dvere (`knock_door.gd` – F zaklope, vyjde ďalší živý z `inside`, obzerá sa, vráti sa),
  poklop z izieb personálu (spáč = Guest), pivnica so sudmi (`whisky_barrel.gd` – vrstva 32, prestrelený → úsek podlahy
  do skupiny `ice`, mafián cez mláku `trip()`), svorky na rúrach (y 40) z debien, šachta s rebríkom až na strechu.
  Herňa: lampa nad pokrovým stolom (zhasne → poručíci `hear`), stôl `flip_table.gd` (F, kryt, hluk). Kancelária: Sal
  (gangster_tommy, kind `sal`, 14 životov, vesta), bodyguard; pri poplachu (alebo `club_loud`) sa zamkne – `lock_door.gd`
  (3 výstrely do dverí), stôl sa prevráti, Sal za ním. Inak svetlík v streche (`skylight.gd`). Po Salovi trezor:
  pozvánka + fotka (ReadCard), duch „THAT VEIL... I KNOW THAT VEIL.“, otvorí sa okno → `ExitWindow` → hotel (`_leave_door(HOTEL, 22, false)`).
  **Hotel Majestic** (Iron Mike, gala „M.“). Scény píšu `_art_src/make_hotel_scene.py` a `make_hotel_gala_scene.py`,
  obrázky `make_ch3_hotel_art.py` (servisné krídlo), `make_ch3_hotel_people.py` (personál + kind `butcher` zo slugger
  a `bellhop` z tux), `make_ch3_gala_art.py` (sála, bossovia, Iron Mike, strecha, Springfield) so spoločným `hotel_lib.py`
  – v projekte `ricco-v2-kapitola3-hotel/` mimo repa. Obe časti `extends ClubLevel`.
  **Časť 7 – `hotel.gd`/`hotel.tscn`** (checkpointy 22 ulička, 23 príjem / východná galéria, 24 poschodie, 25 práčovňa;
  Ricco ide z východu na západ a hore): ulička s policajtom (whistle, baterka) – rampou do príjmu, alebo požiarnym
  schodiskom oknom na galériu. Kuchyňa: kuchári = svedkovia (`runners`), háky `train_strap.gd` na y −195 (1610–1962),
  medené panvice `ricochet_pan.gd` (Riccova guľka sa odrazí do najbližšieho viditeľného mafiána do 340 px, klobúk len cinkne),
  kotol s ventilom `steam_valve.gd` (guľka/klobúk → prúd pary `trip()`, Ricca opáli, potom oblak = kryt vrstva 32), sud
  oleja (`whisky_barrel.gd`), stojan na hrnce (`drop_weight.gd`) nad mafiánom s luparou, mäsiar (kind `butcher`).
  Výstrel v hoteli = poplach (`_in_club` = x < 2290) → `hotel_loud`. Poschodie: šatňa (spiaci poslíček), klopacie dvere
  do herne troch policajtov, slúžky, sklad bielizne s poklopom šachty na bielizeň (dolu do práčovne). Práčovňa: plachty =
  kryt, parný lis s ventilom, predák s kľúčom (F TAKE → `Level3.lift_key`), zamknuté dvere do kuchyne (`lock_door.gd`),
  poklop v podlahe → tunel (šmyk) do uličky protiváhy. **Nákladný výťah** `service_elevator.gd` (AnimatableBody2D,
  zastávky 0 / −240 / −400): kým žije liftboy (Liftman, kind `bellhop`), jazdí sám po rozpise; potom panel v kabíne
  (F UP/DOWN) a privolávače pri dverách (F CALL), 3. zastávka (predsieň) len s kľúčom (`locked_stops`). Šachtové dvere
  `lift_door.gd`. Na streche kabíny poklop (F DROP IN – za chrbát liftboya). Protiváha v uličke 720–752 beží opačne –
  v pohybe Ricca na rebríku zraní (2) a zhodí, dá sa na nej viezť. Rebrík uličkou do strojovne (−550), dierou v podlahe
  do predsiene (za chrbát vrátnikom) → `ExitGala` → časť 8.
  **Časť 8 – `hotel_gala.gd`/`hotel_gala.tscn`** (checkpointy 26 špajza, 27 sála / balkón, 28 schodisko, 29 strecha):
  špajza čašníkov (pri `hotel_loud` dvaja bodyguardi navyše), rebrík na balkón, kapela + Lark Lavelle pod balkónom,
  tanečný parket, tri lustre, dlhý stôl rodín – 7 bossov `world/npc/boss.gd` (extends Guest, nebojujú, `seated`,
  pri zastrelení duch nehreší), deviata stolička so závojom a menovkou „M.“ (READ), Iron Mike (len Sprite2D) predná
  prípitok (`toast_done`) a odíde. Schodisko (3 rebríky) na strechu: nápis MAJESTIC – 8 písmen `drop_weight.gd` pod
  lávkou (−480), odstreľovač so Springfieldom (`weapons/springfield`, Gangster `bullet_damage` 2, `drops_weapon` false),
  poistková skriňa nápisu (`hat_lamp.gd` – zhasne svetlo pod nápisom). Západný koniec strechy `EndView`: veža Iron Mikea
  so vzducholoďou → `_leave_door(TOWER, 30, false)` (časť 9).
  **Časť 9 – `tower.gd`/`tower.tscn`** – rozostavaný mrakodrap Iron Mikea za svitania (checkpointy 30 stavenisko,
  31 = 3. poschodie, 32 = vrchol/boj; `mike_phase`, `mike_revealed`, `tower_arrived` v Level3). Scénu píše
  `_art_src/make_tower_scene.py`, obrázky `make_ch3_tower_art.py` (`levels/level3/art/tower/`), postavy a Winchester
  `make_ch3_tower_people.py` (kind `mike` = variant A stavbyvedúci, kind `riveter` = nitovač), zvuky `make_ch3_tower_sfx.py`
  (pump_back/fwd, wind_loop, wind_gust, airship_drone) – v projekte `ricco-v2-kapitola3-veza/` mimo repa. Svitá: `dark_area`
  vypnuté, mafiáni `DAWN`. Poschodia každých 130 px (−130 … −650, vrchol −780), v každom diera s rebríkom striedavo
  na západe (640–670) a východe (1430–1460) – kto spadne do diery, je o poschodie nižšie. 1. posch.: vyhňa
  `world/tower/rivet_forge.gd` hádže rozžeravené nity (`hot_rivet.gd`) chytačovi (`toss_to`, `catcher`). 2. posch.: zväzok
  nosníkov `drop_weight.gd` nad obedujúcimi. 4. posch.: vežový žeriav `world/tower/tower_crane.gd` (SWEEP) zametá nosníkom
  vo výške pása (šmyk popod). Nad −600 vietor (nárazy cez `move_and_collide` – tower.gd). Vrchol: paluba 500–1500,
  diera 1420–1460 (rebrík z 5. posch.), vyhňa, stohy nosníkov (kryt), stožiar pre vzducholoď (plošina 560–720 na −930,
  rebrík x 720), vzducholoď „IRON“ (Airship – Hull, Gondola 3 snímky: okná / závoj / ruka s nožom, RopeLadder).
  **Boss Iron Mike** `characters/iron_mike/iron_mike.gd` (`class_name IronMike extends Gangster`, kind `mike`, Winchester,
  36 HP v troch fázach po 12, signály health_changed/died/stage pre `ui/boss_bar.gd` a level). 1. fáza: stojí na poslednom
  nosníku (topping out – vlajka, stromček) na háku žeriavu (RIDE, `ride_point`), klobúk do háku = `lurch()`; pri 24 HP
  `stage(&"beam_tilt")` → `crane.snap()` + `fall_off()`, nosník spadne na palubu (`falling_load.gd`, `stay`). 2. fáza:
  mieri → rana → pumpa (nábojnica) → po 5 ranách nabíja po jednom (pri Riccovi preruší a udrie pažbou), Ricco schovaný
  2,2 s → kopne do vyhne (spŕška nít); žeriav (DROPS) púšťa sudy s nitami s tieňom (Mikeovi `cargo_hit` 4 HP), po sud
  spúšťa hák dierou v palube. 3. fáza: beží na stožiar (nezraniteľný počas lezenia), keď Ricco lezie po rebríku, nestrieľa
  (`_hold_fire`), pažbou zhodí z plošiny. Smrť (`stage(&"dying")` → tower.gd `_mike_dies`): Winchester vypadne
  (pickup), Mike sa chytí povrazového rebríka, vzducholoď stúpa, v okne závoj, rebrík odrezaný, Mike padá, vzducholoď
  odletí → myšlienky, duch „MARGARET“ → `_leave_door(CHASE, 33, false)` (časť 10).
  **Winchester 1897** (`weapons/winchester/`, slot PRIMARY, 5 nábojov): `WeaponData` skupina Pump (`pump_texture`,
  `pump_body_texture`, `pump_px`, `pump_travel`, `shell_reload`) – Ricco po výstrele potiahne pumpu (druhá ruka ide s ňou,
  nábojnica vyletí), nabíja po jednom náboji (`_start_shell_reload`, výstrel nabíjanie preruší); v arzenáli slot 5.
  **Springfield 1903** (`weapons/springfield/`, PRIMARY, 5 nábojov .30-06, damage 3, dostrel 700): rovnaká skupina Pump
  + `bolt_action` – `pump_texture` = závorník s rúčkou (`springfield_bolt.png`), telo bez neho (`springfield_body.png`).
  Po výstrele druhá ruka chytí rúčku (`bolt_knob_px`), zdvihne (`bolt_lift`), dozadu (nábojnica `casing_3006.png`),
  dopredu, dole a späť na predok (`_bolt_open_steps` / `_bolt_close_steps` v ricco.gd). Nabíjanie po náboji
  (`round_3006.png`) zhora do otvoreného závorníka, na konci ho zavrie. Obrázky `_art_src/make_springfield_parts.py`
  (z pôvodného `springfield_src.png`; variant B – mosadzná guľka rúčky). `springfield.png` (celá) majú nepriatelia
  (odstreľovač z kapitoly III, `drops_weapon` false), zem a Arsenal (slot 9). Zvuk výstrelu zatiaľ `revolver_shot`.
  **Ďalej:** kapitola IV.
  **Časť 10 – `chase.gd`/`chase.tscn`** – naháňačka za vzducholoďou a koniec kapitoly III (checkpointy 33 taxík,
  34 = most po nehode, 35 = strecha nákladiaka, 36 = pred zábranami/boj; v Level3 `chase_arrived`, `chase_wave` = dosiahnutá
  vlna v taxíku, `murphy_phase`, `murphy_revealed`). Scénu píše `_art_src/make_chase_scene.py` (rozmery vozidiel číta
  z `chase_meta.json`), obrázky `make_ch3_chase_art.py` (`levels/level3/art/chase/` – autá bez kolies, kolesá samostatné
  sprity so 4 snímkami, skupina `spin_wheels`), Murphy `make_ch3_chase_people.py` (kind `chief` = prefarbený `cop`), zvuky
  `make_ch3_chase_sfx.py` (car_engine, moto_engine, tire_skid, traffic – SoundBits zo Sonniss GDC; siren a klaxon(_2/_3)
  generované) – v projekte `ricco-v2-kapitola3-nahanacka/` mimo repa. Ráno: `dark_area` vypnuté, gangstri `DAWN`.
  **1. Taxík** (vzor `train.gd`): taxík stojí (x 222–406, strecha −88, kufor −54, kapota −46), ubieha svet – Parallax2D
  autoscroll v skupine `street_scroll` (mesto, domy, nadzemka Second Ave El, cesta), kamera stojí (`CAM_TAXI` = obrazovka).
  Vlny (`_run_waves`, `_send`): `PoliceCar1` → nosníky pod nadzemkou (spodok −118, zhodia zo strechy – kapota/kufor/šmyk)
  a `Moto1`+`Moto2` → `MobCar1` (ľudia Margaret) → `PoliceCar2`+`Moto3` → most. Autá `levels/level3/chase_car.gd`
  (AnimatableBody2D, dobehnú zozadu, drgnú – `bumped`, strelci = Gangster deti na podlahe vrstvy 256, šofér `DriverHit`
  = `chase_hitbox.gd` – zásah auto vybúra), motorky `chase_moto.gd` (vedľajší pruh, predbehnú, strieľajú dozadu s červenou
  čiarou, 2 zásahy). Pád na cestu = 1 zásah a späť na strechu; čo padne na cestu (náboje), ubieha s ňou.
  **Nehoda:** uzol `Bridge` (celý most v konečných súradniciach, vypnutý) sa prisunie rýchlosťou cesty, taxikár nezabrzdí →
  `_crash()` (záblesk, taxík snímka 1, Ricco vyletí na nákladiak) → `_bridge_state()` (ulica zmizne, `BridgeFar` parallax,
  most zapnutý, kamera `BRIDGE_MAP`, klaksóny v zápche). **2. Most:** nákladiak s debnami, sedan, električka (rebrík vzadu,
  Tommy na streche), policajné auto, nákladiak so skriňou, korba so sudmi s benzínom (`ship_barrel.gd` – chase.gd po výbuchu
  zraní gangstrov v okruhu `BOMB_RADIUS`), sedany, policajné zábrany (kryt). Aréna 2990–3700: lávka −150 (3010–3270,
  rebríky na oboch koncoch – úkryt pred nájazdmi), barikády z vriec `levels/level3/sandbags.gd` (kryt, voz ich rozmetá),
  sud na ceste. **Boss Police Chief Murphy** `characters/murphy/murphy.gd` (`class_name ChiefMurphy extends Gangster`,
  kind `chief`, Thompson s bubnom, 30 HP v troch fázach po 10, signály ako Iron Mike). Voz `levels/level3/patrol_wagon.gd`
  (`class_name PatrolWagon`, AnimatableBody2D – telo, kolesá, reflektor a okno kabíny `WindowHit` si stavia sám,
  `drive_to`, `set_facing`, `ram` – zrazí Ricca na ceste, `open_doors`/`close_doors`, `wreck`). 1. fáza: na streche voza
  sa krčí za zábradlím (nezraniteľný), vystrčí sa, dávka; megafónom `stage(&"summon")` → chase.gd pustí policajta zo zadných
  dverí. 2. fáza: zoskočí, mieri, dávka 8, po 2 dávkach mení bubon (okno), kopanec. 3. fáza: zadnými dverami do voza, voz
  odíde za pravý okraj, otočí sa, reflektor + klaksón + túrovanie (výstraha), nájazd doľava po `ram_stop` 2990; Murphy
  vystúpi omámený (`dazed_time`), za jazdy cez okno polovičný damage. Smrť → `_murphy_dies()`: posledná replika, vzducholoď
  (Sky/Airship) preletí na východ, myšlienky, duch („YOU'RE A PENGUIN, KID“) → Ricco skočí z mosta (`_dive`) → END OF
  CHAPTER III / THE BIG APPLE → `Level3.reset()` + `Level4.reset()` → `levels/level4/pier.tscn`.
  **Akimbo (dve pištole naraz) odložené** – samostatný krok, zasahuje celú streľbu v ricco.gd.
  **Ľad:** dlaždica s vlastnými dátami `ice` (TileSet) alebo kolízia v skupine `ice` → `ricco.on_ice` (malé trenie, dlhý šmyk, `ground_friction()`).
  **Háky:** `world/coldstore/hook_rail.gd` – vozíky idú po koľajnici (vzor `pattern`: C = mäso, H = voľný hák, - = nič); Ricco vo vzduchu
  chytí voľný hák (stav HOOK = 6, animácia `hook` = jedna plutva hore, `sprites/hook.png` z `jump.png`; vezie sa, strieľa,
  skok/šmyk = pustí sa, pred koncom koľajnice sa pustí sám). Na koncoch koľajnica zatáča dozadu (`DEPTH`): vozík spomalí, zmenší sa, stmavne a zmizne. Mäso (`carcass.gd`, vrstva 32)
  zastaví pohľad aj guľky, postavy prejdú. **Vesta:** `Gangster.vest` – do trupu len `vest_factor` damage (iskry, cink), hlava a nohy naplno
  (`take_hit_at`). `Gangster.cold_breath` = para od úst; Riccovi ide para v mraziarňach (coldstore.gd).
- **Kapitola IV – The Widow** (rozrobená, nápady v projekte `ricco-navrhy/kapitola4_napady.md`; celkovo aspoň 8 kapitol,
  plot twist: nad Margaret stojí **consigliere Mancini** – v knihe pašerákov „C.M. TAKES HIS CUT FIRST. ALWAYS.“).
  Naháňačka autom z konca kapitoly III je odložená. V menu CHAPTERS: `CHAPTER IV / THE WIDOW` → `levels/level4/pier.tscn`
  (`Level4.reset()` v `_start`). Scény píšu skripty `_art_src/make_pier_scene.py`, `make_cave_scene.py`,
  `make_boathouse_scene.py` (spoločné `ch4_scene.py`), obrázky `make_ch4_pier_art.py`, `make_ch4_cave_art.py`,
  `make_ch4_boathouse_art.py` (`ch4_lib.py`, do `levels/level4/art/`), pašerák `make_ch4_people.py` – v projekte
  `ricco-v2-kapitola4-lodenica/` mimo repa. Každá časť = jeden veľký maľovaný obrázok pozadia (súradnice sveta = pixely
  obrázka, Sprite2D na (0,0), z −20), kolízie sú StaticBody obdĺžniky a one-way plošiny (skupina `platform`).
  Dvere a otvory sú na výšku mafiánov (≥ 96 px) – Ricco je nižší než ktorýkoľvek nepriateľ. Noc (`NIGHT`), `dark_area`.
  **Level4** (`levels/level4/level4.gd`, `class_name Level4`): statické `checkpoint` (0 mólo, 1–2 jaskyňa, 3–4 lodenica),
  `barks`, `arrived`, `cave_arrived`, `boathouse_arrived`, `ledger_read`, `tommy_ammo`, `carried`; `reset()`, `part_for(cp)`
  (pomocné funkcie ako Level3: `_leave_door`, `say`, `bark`, `_to_be_continued`…). Výbava Pistol + Winchester + Tommy.
  **Časť 1 – mólo** (`pier.tscn`, 1440×660): rozhegané mólo nad vodou (`WaterZone`, diery s rebríkmi), hnilá doska
  (`roof_plank.gd`), hojdajúci sa lampáš (`levels/level4/sway.gd` – kývanie + nárazy vetra) so svetlom, čajky
  (`pigeons.gd` s vlastnou `texture`), strážnik s baterkou, fajčiar (žeravá cigareta `Ember`), v búde BAIT & TACKLE
  mafián s luparou. Za sieťami tajné dvere (`SecretSpot` „MOVE NETS“) → jaskyňa (checkpoint 1).
  **Časť 2 – jaskyňa** (`cave.gd extends Level4`, `cave.tscn`, 2700×820): pašerácky prístav – vozíky, pás s fľašami
  (`conveyor.gd`), koľajnica s hákmi a debnami (`hook_rail.gd` s `carcass_texture`, debna = drevo), prielev s doskou,
  sudy rumu (`ship_barrel.gd`), kancelária s knihou platieb (`OfficeSpot` → ReadCard), reflektor s obsluhou
  (`club_spotlight.gd`), pes, žeriav so sieťou (`drop_weight.gd`), loď SEA WIDOW; checkpoint 2 v strede, tunel BOATS
  hore vpravo → lodenica (checkpoint 3).
  **Časť 3 – lodenica** (`boathouse.gd extends Level4`, `boathouse.tscn`, 2300×800): dva sklzy s vodou, suchý dok s VITO III,
  povaly, trámy, lešenia; plynové sudy, palivová nádrž (`FuelTank`, výbuch reťazí do benzínovej pumpy), čln LADY M.
  na kladkostroji nad mechanikmi (`drop_weight.gd`), kartári, spáč (`passive`); checkpoint 4. Vľavo šachta s výťahom
  (`Lift` AnimatableBody2D, `LiftSpot` „GO UP“) – kabína ide hore → pivnica vily (checkpoint 5).
  **Časť 4 – pivnica vily** (`cellar.gd extends Level4`, `cellar.tscn` píše `_art_src/make_cellar_scene.py`, obrázky
  `make_ch4_cellar_art.py`, návrh `ricco-navrhy/kapitola4/cast4_pivnica_prierez.png`, 2400×1000): štyri poschodia po 220 px –
  F0 910 zatopená stará pivnica (hladina 926, dno 982 – strážcovia sa brodia s baterkami), F1 690 vínna pivnica,
  F2 470 vinárstvo VITO & FIGLI, F3 250 prízemie vily (knižnica, vestibul, trofejová izba). **Schody** = pevné trojuholníky
  45° (`CollisionPolygon2D`) striedavo vpravo / vľavo / vpravo (S0 2060→2280, S1 520→300, S2 2060→2280), nad nimi v podlahe
  vyššieho poschodia železná mreža (one-way) – Ricco sa po schodoch nevracia (nemá zoskok z plošinky).
  F0: plávajúce sudy (`levels/level4/bob.gd` – one-way AnimatableBody2D), lampa na kábli nad vodou
  (`levels/level4/water_lamp.gd`: guľka/klobúk → spadne do vody, prúd zloží každého vo `WaterZone`, plávajúceho Ricca zraní,
  signál `shorted(kills)`), čerpadlo (`levels/level4/pump.gd`: kým beží, výstrely do 320 px od neho počuť len do 110 px –
  `Gangster._masked`, skupina `noise_masks` s metódou `mask(pos, radius)`; F „SWITCH OFF“ (`PumpSpot`) alebo guľka →
  ticho zalarmuje okolie a voda za 14 s odtečie až na dno – hýbe `WaterZone.rects[0]`, `WaterSurface`/`WaterDeep`,
  sudmi (`bob.gd`, skupina `floaters`, `set_base`) aj `WaterLamp.water_y`). F1: regály a sudy = kryt, obrí sud RISERVA DEL DON (`CaskSpot` „KNOCK“) =
  tajné dvere → stmievačka a Ricco sa objaví v šachte s rebríkom v stene (x 0–160, `ShaftIn`; späť `ShaftSpot`) →
  rebrík až do komôrky za otočnou policou (`ShelfDoor` – `ShelfSpot` „PUSH“ / z knižnice „PULL BOOK“) – tichá cesta obíde
  vinárstvo aj trofejovú izbu. F2: kaďa s kohútikom (`whisky_barrel.gd` s `stream_color` – rozliate víno šmýka),
  rebríky na kadiach, koše s hroznom na kladke (`hook_rail.gd`, `carcass_texture` = basket.png), stena sudov (one-way navrch),
  lis TORCHIO. F3: krb, lustre `Chandelier1/2` (`drop_weight.gd`), doberman, hájnik (kind `keeper` s Winchestrom 1897),
  vitrína so Springfieldom (`TrophyCase` 2 snímky, `CaseSpot` „OPEN“ → `weapon_pickup` s 15 nábojmi). Dvere GRAND HALL (`GrandHallSpot`) → zatiaľ TO BE CONTINUED.
  Checkpointy 5 výťah, 6 vínna pivnica, 7 vinárstvo.
  **Pašerák:** gangster `kind = "smuggler"` (`characters/gangster/smuggler/`, prefarbený z riveter – modrý sveter,
  červená čiapka; RIGS v gangster.gd). **Hájnik:** `kind = "keeper"` (`characters/gangster/keeper/` – tvídové sako,
  pumpky, placatá čiapka; tiež `make_ch4_people.py`). **Úpravy spoločných skriptov:** `pigeons.gd` `@export texture`, `hook_rail.gd`
  `@export carcass_texture` (+ `wood` na carcass – drevený zvuk a triesky).
  **Ďalej:** hlavná hala a poschodie vily (záhrady podľa potreby), boss Margaret + odhalenie Manciniho;
  vlastný zvuk výstrelu Springfieldu.
- **Plávanie:** v pivnici sú zatopené katakomby (kostnica ~113 dlaždíc: bazény, rošt nad vodou s hliadkou s baterkou – popod ňu sa dá preplávať,
  dlhý sifón, krypta so strážou chrbtom, dosky cez vodu). Hlboká voda je v MAZE znak `%`, build z nej spraví `WaterZone`
  (`world/water/water_zone.gd`). Ricco má stav SWIM: na hladine pláva, S = ponor, medzerník = hore / vyskočiť, k nízkemu okraju sa sám vyšvihne.
  Pod hladinou (`submerged`) ho gangstri nevidia. Dych nemá – je to tučniak.
- **Schody:** kolízia je neviditeľná 45° rampa, kresba sú jemné 4 px schodíky presne po rampe (dlaždice „nos“ v 4. riadku atlasov).
  Postavy majú `floor_snap_length = 16` (na hrane schodov nevyskočia) a na svahu sa obrázok posunie o 4 px nižšie (spodok kapsuly).
- **STORY** v hlavnom menu: CONTINUE (posledná rozohratá kapitola od začiatku – `Progress.chapter` v user://progress.cfg,
  zapíše ju `Progress.reach_chapter(n)` v _ready prvej scény kapitoly; bez uloženia sa neukáže), NEW STORY (kapitola I),
  CHAPTERS (veľké CHAPTER I, pod ním malým názov – `MenuPages.item_sub`, `MenuItem.subtitle`). Zoznam kapitol `CHAPTERS` v main_menu.gd.
- Menu: hlavné menu, pauza, nastavenia (kurzor, zameriavače, HUD štýly, retro filter), **AUDIO** (Master, Music, SFX, Ambience, UI; 0–10),
  **CONTROLS** (SNEAK HOLD / TOGGLE – `GameSettings.sneak_toggle` + stránka **KEYBOARD**: všetky akcie, Enter → „PRESS A KEY“ → nový
  hlavný kláves, RESET TO DEFAULTS). Klávesy sú v `settings/key_bindings.gd` (`KeyBindings.ACTIONS`, uložené v settings.cfg [keys],
  akcie mimo project.godot – holster, weapon_1–3, weapon_last – pridá za behu; nový kláves inej akcie sa vymení). Nápovedy v hre
  (`KeyBindings.short(&"takedown")`), zoznam vľavo dole aj nápisy kriedou (`{SNEAK}`, „F -“, „SHIFT -“) sa prepíšu podľa nich.
  `ui/pause_menu/key_capture.gd` zachytí kláves (beží aj počas pauzy).
- **Schovanie zbrane** (X, akcia `holster`): ruka ducha so zbraňou sa stiahne k Riccovi (`ricco.holstered`); streľba / R / výber zbrane
  ju vytiahne (prvé kliknutie nevystrelí, ľavé tlačidlo pri mafiánovi = zneškodnenie). Počas prebíjania sa schová až po dobití.
- **Streľba – pocit:** spätný ráz kamery (`_cam_kick` proti smeru streľby), záblesk na okamih osvetlí okolie (`PointLight2D` v ústí –
  funguje aj s tmou CanvasModulate), väčšia hviezda (`FLASH_SCALE`), dym ostane visieť (`effects/gun_smoke.gd`, `effects/art/smoke_puff.png`).
  Výstrel počuť do 520 px (`SHOT_NOISE`, `Gangster.gunshot`): kto má výhľad na ústie, vidí záblesk aj v tme (`_aggro`), ostatní sa idú pozrieť.
- **Zásah:** mafián krátko sčervenie (`Gangster._tint_flash(HIT_RED)` – vráti sa k pôvodnému `modulate`, napr. nočnému), Big Lou tiež.
  Ricco po zásahu sčervenie a počas `invulnerable_time` plynulo bledne (`HURT_TINT` v `_update_invulnerability`, bez blikania viditeľnosti).
  Krabičku nábojov po smrti nechá len mafián so strelnou zbraňou (`weapon` nie je null).
- **Nevinní:** hostia / smútiaci (`world/npc/guest.gd`) majú telo na vrstve 64 (`INNOCENT_LAYER`, `guest_body.gd`) – zasiahne ich len
  Riccova guľka (`bullet.gd hit_mask` 1|4|32|64): padne, krv, ostatní zvreskú (poplach), duch Ricca zvozí („OI! WE DON'T DO THAT…“, `bark`).
- **Podkopnutý mafián** leží `trip_time` 1,3 s, potom vstane (`Gangster._stand_up`: posadí sa s rukami za sebou → kľakne → postaví sa).
- **Čítanie dokumentov:** `world/fx/interact_spot.gd` (nápoveda „F - READ“, signál `used`) + `ui/dialog/read_card.gd`
  (`await ReadCard.open(self, tex).closed` – pauza, stmavnutie, obrázok v strede, F / ESC zavrie). Účtovná kniha Lou má text priamo
  v obrázku (`ledger_big.png` 300×184, generuje `c3/make_read_art.py` mimo repa).
- **Jedlo so sebou** (`props/food/food.gd` = `Food`): Ricco unesie 3 kusy (`Food.carried`, static – ostane medzi časťami levelu,
  `Level2.reset()` ho vyprázdni), zje prvé klávesom **V** (akcia `eat`) – len na zemi a keď nie je celý zdravý. Druhy sa striedajú
  (`Food.next_kind`): pizza +2, sardinky +2, cannoli +2, espresso +1 a 6 s rýchlejší beh, saláma +2, spumoni +2, sleď v pohári +3.
  Animácie sú tweeny v `characters/ricco/eating.gd` (`RiccoEating`, dieťa Visual – záklon hlavy otáča obrázok okolo nôh, `gulped` = vylieči).
  Počas jedenia nestrieľa a ide pomaly; skok, šmyk, zásah ho prerušia (jedlo ostane). Na zemi: `props/food/food_pickup.tscn`
  (`kind` "" = podľa poradia, "medkit" = lekárnička → hneď celé zdravie); plná zásoba + zranený = zje hneď. HUD: `ui/food_slots.gd`
  (3 políčka naľavo od nábojov). Rozmiestnenie: `const FOOD` v každom `tools/build_*.gd`. Obrázky `food.png` (16×16 políčka) a zvuky
  (chomp, gulp, can_peel, slurp, lid_pop, medkit) generujú `c4/make_food_art.py` a `c4/make_food_audio.py` mimo repa.
- **Krytie:** pri zakrádaní (C) tesne pri nízkej prekážke (vrch 12–32 px nad nohami, vrstva 1 alebo 32 – debny, náhrobky, pult) sa Ricco
  skrčí (`ricco.ducked`, nízka kapsula 22 px, `_update_cover`). Gangstri aj Lou potom mieria do výšky 10 px (`_player_target`) → pohľad aj
  guľky zastaví kryt, mafián ho stratí. Výstrel ho na 0,5 s vystrčí nad kryt (`COVER_POP_TIME`).
- **Prechody medzi scénami** idú cez `ui/loading/loading_screen.gd` (`LoadingScreen.go(get_tree(), path)`, preload, nie class_name):
  čierna clona úplne navrchu (layer 128), skrytý kurzor, scéna sa načíta na pozadí a clona sa zdvihne až po pár snímkach novej scény.
  Nové `change_scene_to_file` už nepoužívať – ísť cez LoadingScreen.
- **Strelnica** (menu SHOOTING RANGE, nahradila debug room `levels/test_room/`): `levels/range/range.tscn` generuje `tools/build_range.gd`
  (krytá strelnica klubu **Fontana Gun Club**: tehlová hala, drevený obklad, lampy so zeleným tienidlom, okná s mrežami, betónová podlaha
  `levels/range/tiles_club.tres`, drôt s kladkami a visiacimi terčmi, oceľový ochoz, bedne s nábojmi; svetlo strelnice zelená/červená;
  všetka grafika `levels/range/art/` z `c7/make_range_art.py` mimo repa – nič z kapitol). Logika `levels/range/shooting_range.gd`:
  zbrojnica (F vezme zbraň najbližšie k Riccovi, pri zbrani, ktorú už má, ju doplní – REFILL; náboje sú inak obmedzené ako v leveloch),
  páka MODE (F) prepína 5 režimov – plechovky a fľaše,
  pohyblivé terče (vozík na koľajnici, terče na kladkách), vyskakovacie terče na 30 s (najlepšie skóre), figuríny, ozajstní gangstri.
  Terče a gangstrov spawnuje skript podľa značiek `Spots/<Skupina>` (metadáta span/speed/rope… na Marker2D).
  Terč: `props/range/range_target.gd` (body podľa kruhu 50/25/10, diery od guliek); plechovka `props/target/target.gd` volá `add_score`.
- **Zvuky** (posledná práca):
  - `Sfx.play(name, pos, vol_db, pitch_var, bus)`, `Sfx.loop(...)`, `Sfx.shot(weapon, pos)`, `Sfx.set_slowmo(on)` – zbernice sa vytvoria za behu,
    pri spomalení je dolná priepusť a SFX pitch ×0.72.
  - Varianty: ak existuje `meno_2.wav`, `Sfx.stream()` z nich spraví AudioStreamRandomizer (bez opakovania tej istej).
    Mix: kompresor so sidechain = SFX na Music a Ambience (výstrel ich stíši), HardLimiter na Master.
  - Výstrely (pistol_a/b/c, revolver_shot, tommy_shot, lupara_shot + _2/_3) a mechanika (mag_in/out, slide_rack, dry_fire,
    shell_insert, cylinder_spin) generuje `c5/make_gun_audio.py` mimo repa z CC0 vzoriek (Warfork mg/riot, BB 2HTC snap/kick/click,
    Kenney RPG, metal_interactions). Nepriateľská pištoľ = pistol_b (`Sfx.ENEMY_SHOTS`).
  - **Hudba:** `Sfx.music(&"meno", fade)` – prehrávač v koreni stromu (prežije zmenu scény), rovnaká skladba hrá ďalej, `&""` = stíšiť.
    Skladby (CC0 slučky Ben Burnes 2HTC Vol 4, `c6/make_music.py` mimo repa – bezšvová slučka, −20 dBFS RMS): menu_jazz (menu),
    rainy_noir (mesto + pivnica), intensity (prestrelka s duchom, Lou), cemetery, night_cafe (prístav), desolation (mraziareň).
    Pri Donovi a pred bojom s Lou hudba stíchne.
  - Väčšina efektov sú CC0 nahrávky (Kenney Impact/RPG/Casino Audio, Organic Wooshes, Smol Mechanisms, Warfork ricochety, 40 CC0 water – dážď),
    zvyšok syntetizovaný (spomalenie, Riccov zásah/smrť, zásah do tela, výstrely, menu, dav, kuchyňa, tunely, neón, potkan, tlkot srdca).
  - Klobúk: `hat_throw` (hod) + `hat_return` (keď sa vracia, `hat_projectile.gd`).
  - **Prístav (`amb/docks.ogg`)** – november 2026: pôvodná syntetická slučka bola „hrozná“, nahradená 64 s bezšvovou slučkou
    zo Sonniss GDC (Soundopolis Water Ambiences 01: River Huron Lapping = šplechot pri koloch, Lake Huron Evening = vlny,
    RDG Squeaks and Creaks: vŕzganie dreva ×0,72), −26 LUFS ako predtým. Skript `c10`/`daud2` mimo repa.
  - **Hlasitosť v nastaveniach:** krivka (v/10)^1,5 (`Sfx.apply_volumes`), posuvníky v AUDIO (`MenuItem.steps`, myš aj podržaná šípka) – štýl „zárezy“ (10 políčok, ostatné návrhy fader/klin boli zrušené).
  - **Riccove zvuky** (október 2026, 2 kolá vypočúvania): nové sú iba kroky `step_1`/`step_2` (žabky na dreve o tón nižšie
    + mäkké dupnutie, 3 varianty), `ladder_rung` (ťuknutie pilníkom o železo, všetky 4 súbory rovnaké, rozdiel robí pitch_var)
    a `takedown` (344 Audio Cinematic Fight – úder do tela). `hurt`/`death` = pôvodné syntetické zvuky o kúsok hlbšie
    (hurt ×0,9 / ×0,86 / ×0,94, death ×0,92). Všetko ostatné (jump, wall_jump, land, ledge_grab, climb, belly_slide, slide_getup,
    klobúk, splash, hook_grab, pickup_ammo) je **pôvodné** – vrstvené náhrady aj iné nahrávky zo Sonniss GDC boli zamietnuté
    („úplne od veci“). Súbory `meno_2.wav`/`_3` pri pôvodných sú len ich kópie. Skripty: `_art_src/make_ricco_sfx.py` (kroky, rebrík),
    `kand.py` (takedown = kandidát A), `hlas2.py` (zásah/smrť) v projekte `ricco-v2-zvuky/` mimo repa.
    Hlasitosť (najsilnejších 50 ms) drží pri starých zvukoch. Jedlo (chomp, gulp, slurp, can_peel, lid_pop, medkit) ostalo staré.
  - **Mafiáni ani hostia nehovoria** – iba žltý „!“ nad hlavou + krátky tón `alert.wav`. Hlasy (TTS) som zamietol – znelo to hrozne.
  - Muzzle flash štýl A, väčší recoil, lupara odhodí Ricca dozadu.

## Pravidlá dizajnu hry
- **Zbrane len dobové** (20. a 30. roky, prohibícia) a skôr **rôzne druhy** než viac variantov toho istého typu.
- **Postup od slabých k silným:** Ricco začína so slabou zbraňou a lepšie odomyká postupne. Prvá zbraň je **Donov derringer**
  (Don ho mal schovaný). Plán bočných: derringer → revolver .38 → Colt 1911 → Mauser C96 Schnellfeuer.
  Hlavné: lupara → Winchester 1897 (pumpovačka), Thompson, Winchester 1894 (páková) → Springfield 1903, BAR M1918.
- **Nepriatelia sa postupne zlepšujú** – v ďalších leveloch silnejší protivníci so silnejšími zbraňami.
- **Výbava:** 1 bočná (kláves 1) + 2 hlavné (klávesy 2, 3). Zbraň zo zeme: voľné miesto → zoberie sám, plné → F vymení.
  HUD (`ui/ammo_panel.gd`): lístok má pevnú šírku (zbraň sa zmenší do 40×12), pod ním 3 ústrižky so slotmi 1–3 (vybraný svetlý,
  dlhší, podčiarknutý; MINIMAL štýl = malé tmavé políčka). Zálohu nábojov obmedzuje `WeaponData.reserve_max` (krabičky, zbrane zo zeme).
- **Režimy streľby** (kláves B, akcia `fire_mode`): `WeaponData.alt_mode` – Tommy FULL AUTO ↔ SEMI (Thompson mal naozaj len tieto
  dva, dávkový režim nie), lupara 1x ↔ 2x (obe hlavne naraz = 2× broky, väčší spätný ráz). Pamätá sa pre každú zbraň (`Ricco.alt_fire`),
  HUD ukazuje červenú pečiatku AUTO/SEMI, 1x/2x. Broky luparky sú menšie (`pellet_scale`).
- **Záblesk a dym:** každá časť záblesku (svetlo, snímky, žiara) má jeden tween, nový výstrel ho zruší (inak pri dávke svetlo zhaslo).
  Pri dávke sa hlaveň zahrieva (`_heat`) – dymu pribúda a po dávke z ústia chvíľu stúpa tenký dym (`GunSmoke.wisp`).
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
1. **Realistické výstrely** (prerobené vrstvením v úpravách 7, čaká na posluch) – predtým syntetické aj CC0 nahrávky zneli „tupo“. Holé nahrávky treba vrstviť
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
- Ovládanie: A/D pohyb, Space/W skok, S/Ctrl šmyk, C/Alt plíženie (pri debne kryt), V zjesť jedlo, X schovať zbraň, F zneškodnenie/klopanie, pravé tlačidlo/E klobúk, ľavé tlačidlo streľba,
  R prebíjanie, 1–3 / koliesko zbrane, Q posledná zbraň, B režim streľby, Shift spomalenie, Esc pauza.
- **Mierka prostredia je ľudská:** mafián s klobúkom má ~75 px, Ricco ~40 px. Dvere aspoň 94 px (+ nadsvetlík), okná 38×70,
  poschodie 128 px, zábradlie ~40 px, lampa ~150 px (`_art_src/city_bldg.py`, mierka A). Staršie časti (nadzemka – dvere vo vozňoch 50 px, klub, hotel)
  ešte majú pôvodnú, menšiu mierku dverí (~84 px).
- README je v angličtine s bannermi z `docs/media/h_*.png` (bez gifov). Pri nových zdrojoch (zvuky, hudba, fonty) doplniť sekciu Credits.
