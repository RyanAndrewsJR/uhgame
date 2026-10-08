# Champion Kit Board

A one-page design tool for sketching champion and enemy kits: the passive and abilities, each with a to-scale top-down shape on a 1 m grid, sliders, tags and a "Copy brief" button. It is not part of the game: Godot never scans this folder (it is outside `game/`, and `.gdignore` makes sure).

## Open it
- Double-click `champion_board.html`. Chrome or Edge work best. No server, no install, works offline. The page makes no network requests: it uses the Barlow Condensed and IBM Plex fonts if they are installed on the PC, and plain system fonts otherwise.
- First time on a new PC or browser: click **Import (.json)** and pick `my_champions.json` (Ryan's champions as of 2026-10-04).

## Where your sheets live
- In this browser only, on this PC. Another browser or PC starts empty, and clearing the browser's site data wipes them.
- **Back up with Export all regularly.** It downloads a `.json` file with every sheet, the race list and the board settings; Import loads it back.
- The first time this version opens in a browser, it copies the sheets stored there to a backup (`champion-kit-board.backup-v1`) before changing anything. **Download the pre-update backup** in the left rail saves that copy as a file you can import again.

## Share with friends
- Send them `champion_board.html`. They open it and build their own sheets.
- Designs move between people as exported `.json` files. Import never overwrites a sheet you already have: an identical one is skipped, and a clash comes in once as a copy named "(imported)". Races from the file that you don't have are added; a race you already have keeps your version.

## Copy brief
"Copy brief" copies a plain-text summary of one sheet, ready to paste to Claude or the builder. An enemy's brief follows the style of ENEMIES_AI.md's data tables (EnemyData fields, the kit table, one AIUse list per ability, the combo plans).

## What the board covers
- **Kinds.** Every sheet is a champion or an enemy. Pick the kind with the Champion / Enemy switch above "+ New". The roster shows a badge and filters by kind, archetype and race.
- **Archetypes.** Assassin, Mage, Bruiser, Duelist, Skirmisher (and Basic, fodder's, for enemies). Tank, Marksman and Support still work under "Legacy" for sheets that use them. Each sheet has an archetype layer note (what the passive and one or two abilities add on top of the kit). A hint line per archetype is shared by the whole board and editable.
- **Races.** A board-wide list (30 to start, all editable) under **Races and board settings**: a name, a size class, a one-line silhouette, a one-line identity, and which side it suits. Races are look and identity only: no numbers, no stats. A sheet can also pick "Other" and name its own. Enemies have a free-text faction.
- **Compound casts.** An ability's graphic can be built from up to six effects ("+ add effect"). Each has its own cast type and sizes, and starts with the previous one, after it ends, when it hits, or on recast, plus a delay. The preview draws them all, numbered, in one grid. Play (or Step, if your system reduces motion) and the scrubber show them in order.
- **Weapons (champions).** One to three weapons, each with a name, type, attack chain (swings and notes), VFX and sound notes, and its own Q, W, E, R. The passive is shared and never changes with the weapon. Weapons carry no stats. "Mark changes against weapon 1" labels each card same, changed or new. The workload card is a rough guide: per weapon, one attack-chain set plus one unit per ability not reused from an earlier weapon.
- **Enemies.** Rank (fodder, regular, elite, boss), health note, poise max, behavior notes, an automatic basic attack, up to six abilities, and a passive only at rank boss. Each ability also has damage, telegraph, recovery, deflectable, AI uses and combo roles. The checks are advisory, never blocking: respect from the role tags, the 0.6 s telegraph floor, the damage bands (against the player health set in board settings, 650 by default), and the kit size by rank. There is a behavior sliders panel (the doc's role defaults, with per-enemy overrides) and combo plans. "+ Example enemy: test duelist" loads the worked example from ENEMIES_AI.md.
- **Paperdoll.** A front-view look and silhouette sheet for an art brief, not equipment. Every slot has a shape, a colour and a short description. The race sets the height, build and extra parts; a champion's hands follow the selected weapon tab. **Copy art prompt** writes one paragraph for a 3D artist or an image tool.
- **Export version 2.** `{format:"champion-kit-board", version:2, exported, champions, races, settings}`. Import reads version 1 and 2 files, and the older board can still import a version 2 file (it ignores what it doesn't know).

## Scale
Shapes are drawn in meters, League style: 100 u = 1 m (CONVENTIONS.md, Units). The "% of screen width" readout uses a 28 m screen; the game's camera has been 30 m wide since 2026-10-04 (3D.md), so that percentage reads about 7% high.

The Knight example's numbers are approximate placeholders. The real numbers live in ABILITIES.md and CHAMPIONS.md. The test duelist's come from ENEMIES_AI.md and its data files (the tuning pass of 2026-10-07); its shapes are approximate.
