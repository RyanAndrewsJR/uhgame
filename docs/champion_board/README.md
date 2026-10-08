# Champion Kit Board

A one-page design tool for sketching a champion's kit: the passive and Q/W/E/R, each ability with a to-scale top-down shape on a 1 m grid, sliders, tags and a "Copy brief" button. It is not part of the game: Godot never scans this folder (it is outside `game/`, and `.gdignore` makes sure).

## Open it
- Double-click `champion_board.html`. Chrome or Edge work best. No server, no install, works offline.
- First time on a new PC or browser: click **Import (.json)** and pick `my_champions.json` (Ryan's champions as of 2026-10-04).

## Where your champions live
- In this browser only, on this PC. Another browser or PC starts empty, and clearing the browser's site data wipes them.
- **Back up with Export all regularly.** It downloads a `.json` file with every champion; Import loads it back.

## Share with friends
- Send them `champion_board.html`. They open it and build their own champions.
- Designs move between people as exported `.json` files. Import never overwrites a champion you already have: an identical one is skipped, and a clash comes in as a copy named "(imported)".

## Copy brief
"Copy brief" copies a plain-text summary of one champion, ready to paste to Claude or the builder.

## Scale
Shapes are drawn in meters, League style: 100 u = 1 m (CONVENTIONS.md, Units). The "% of screen width" readout uses a 28 m screen; the game's camera has been 30 m wide since 2026-10-04 (3D.md), so that percentage reads about 7% high.

The Knight example's numbers are approximate placeholders. The real numbers live in ABILITIES.md and CHAMPIONS.md.
