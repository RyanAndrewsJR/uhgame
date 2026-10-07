# CHANGELOG.md: What Was Built and Measured

**Read when:** asked what was built or measured (test counts, measurements, what changed during a build step).
**Depends on:** nothing. **Used by:** nobody at build time: the system docs hold the specs.

## How to use
- One section per system, one entry per build step, **newest first**. Each entry: the step, its date, its status, and its build log (test counts, what was measured, what changed during the step).
- The system doc keeps only the spec, plus one line per step ("C8 built 2026-09-26, see CHANGELOG.md"). A rule found while building goes into the spec, not only here.
- Status: **Built (awaiting play test)** or **Passed** (Ryan's play test). When a play test passes, update the entry's status.
- Entries up to 2026-09-27 were moved here word for word from the system docs.

## Loot (LOOT.md)

### L-M – A looting session: 2026-10-04, Passed (Ryan's play test; LOOT is done)
Ryan played the milestone from a nearly empty inventory (his inventory and progress backed up first, beside the saves in `backups/`) and passed it. He answered the open questions along with it: a pit between a corpse and its drop stops the hop; the leap's look works; Shockwave's tooltip line on Judgement Leap stays for now (real champions are coming soon); Homeward Lunge's return keeps its cast time; roots are roots (Abilities, below).
- **Built after it (the pit):** `Pickup.is_good_landing()` casts its ray on pits too (`WALK_BLOCKING_MASK | PIT_MASK`). loot_test's pit row now checks what the others do: of 300 drops beside a 4 px pit, none over it, none across it, the rest on the open side or where they dropped (L7 had measured 64 hopping across).
- **Tests** (with the roots change): loot 750/750 (the pit check rewritten, no new checks), abilities 593/593 (13 new). Stats 179/179, combat 474/474, audio 110/110, champions 168/168, talents 310/310, view 457/457: 3,041/3,041. Smoke runs clean; the saves (backed up again first: the L-M play had changed them) byte-identical.

### L7b – Dropping and trashing items, sorting: 2026-10-04, Passed (Ryan committed it and started L-M)
Ryan asked to drop and trash items (2026-10-04), answered four questions (inventories stay unlimited; drop back on the ground, held until you walk away; trash for good, a second press for Unique and up; the spec first), committed the spec, and started L7b with Claude's proposals as written plus sorting on O.
- **Code:**
  - `ChampionInventory.remove(uid)`.
  - `LootTable.trash_confirm_from` (Unique; the class default, so the .tres is unchanged).
  - `Loot`: `can_remove()`, `drop_from_inventory()`, `trash_item()`, `needs_trash_confirm()`, the signals `item_dropped` / `item_trashed`. `drop()` takes an optional `held_for` unit.
  - `Pickup`: `hold_for()` / `is_held_for()` / `release_hold()`, and the hold checked every physics tick. `PickupComponent` skips a pickup held for its unit and releases the hold on `area_exited`.
  - `SandboxLoot`: L (`drop_item()`), X (`trash()`, `cancel_trash()`, `get_pending_trash()`, `trash_confirm_time` 3 s), O (`cycle_sort()`, `get_sort()`; the header's "By slot" / "By rarity"); the keys line.
  - `hub.gd`: Clear inventory in the debug row (`debug_clear_inventory()`, `clear_confirm_time` 3 s, `get_detail_text()`).
- **Changed during the step:**
  - **The hold also ends by distance.** The spec released it on `area_exited` only. But a drop isn't collectable while it hops, so a player who walks off during the 0.3 s never gets an `area_exited` for it. The hold outlived the walk away, and coming back didn't take it (the sensitivity run shows exactly that). Every physics tick the pickup now checks whether its unit's collect circle still reaches it.
  - **The threshold is data** (`LootTable.trash_confirm_from`), and `trash_item()` takes an optional unit for the worn check, as `can_remove()` does.
  - **Any key but X cancels a waiting trash**, including keys SandboxLoot doesn't use, and a pickup that moves the cursor does too.
- **Measured** (loot test; a layout probe in `sandbox_main`, saving off):
  - **Dropping:** the item was out of the inventory and the scratch save at once, and `item_dropped` fired once. The pickup popped 23.3 px from the Knight's feet into the room's Entities, held for him. It landed inside his 64 px and stayed. He walked 150 px off, the hold ended, and on coming back he took it with a new uid. Walking off during the hop also ended the hold, the drop landed untaken, and coming back took it. A dropped item is a ground drop like any other (taken and put back), and put back it isn't held.
  - **Trashing:** `Loot.trash_item()` removed the item from the inventory and the scratch save, fired `item_trashed` once, and left no pickup. X trashed a Common at once. A Unique only asked; X again trashed it. A Legendary's ask was cancelled by a cursor move, by an unused key (H), and by `trash_confirm_time` running out (0.1 s in the test); then X, X trashed it. A worn item was refused for both L and X, with the reason.
  - **Sorting:** by slot: Longsword, Rare helm, Common helm, then the rings (Rare, Rare, Common; the two Rares in pickup order). By rarity: Rare helm, Rare, Rare, Uncommon, Common helm, Common ring. The cursor stayed on its item through each O, the inventory's own order never changed, and a new pickup took its sorted place with the cursor on it.
  - **Clear inventory:** the first click asked and kept the 3 items; the second emptied them. With nothing in it, it only says so. A second click after `clear_confirm_time` asks again, and the button itself works.
  - **Layout:** the keys line wraps to two rows. The worst case (The Last Verdict or Chains of Judgement worn and highlighted mid-list, sorted by slot, a refused trash as the result) ends at y 306; the ability bar starts at 322.
- **Sensitivity:** each key check was broken on purpose once and restored, and each failed: the held skip in `PickupComponent`, the per-tick hold check, the worn refusal in `can_remove()`, the confirm threshold, the cursor-move cancel, the hub's second click.
- **Smoke run** (`sandbox_main`, `sandbox_main_layout`, `main_layout` for 600 frames, `hub.tscn` for 300; the saves backed up first): no errors or warnings; all three saves byte-identical after.
- **Tests:** loot 750/750 (44 new). Stats 179/179, combat 474/474, abilities 580/580, audio 110/110, champions 168/168, talents 310/310, view 457/457: 3,028/3,028.

### L7 – Drops and pickups: 2026-10-04, Passed (Ryan committed it and asked for dropping and trashing items before L-M)
Ryan passed AB15 and started L7 (2026-10-04).
- **Data:**
  - `project.godot`: collision layer 9 named `pickup` (written directly while Godot was closed; it shows under Project Settings → General → Layer Names → 2D Physics).
  - `scenes/loot/pickup.tscn` (an Area2D on layer 9 only, mask 0, not monitoring, not monitorable until it lands, a 6 px circle) and `scenes/view/pickup_view.tscn`.
  - `player.tscn`: a `PickupComponent` (layer 0, mask 9, a 64 px circle). `knight.tres`: `pickup_radius` 200.
  - `sound_loot_drop`, `sound_loot_drop_legendary`, `sound_loot_pickup` (`data/sounds/`) over three synthesized WAVs (`audio/sfx/loot_*_01.wav`, a GDScript tool: sines and a little noise; `audio/LICENSES.md` row). `loot_table_default.tres`: Uncommon–Exotic drop with `sound_loot_drop`, Legendary and Artifact with the legendary one, Common silent; `pickup_sound`.
- **Code:**
  - `Pickup` (`scripts/loot/pickup.gd`): `hop(from, spot)` / `place(spot)` before it enters the tree, `pick_landing()` / `is_good_landing()`, `landed`, the hop's progress for its view, `debug_draw`.
  - `PickupComponent` (`scripts/components/pickup_component.gd`): its own circle from `pickup_radius`, followed on `stat_changed`; `Loot.collect()` on `area_entered`; nothing while dead.
  - `Loot`: `item_picked_up`; the `Events.unit_died` listener (`get_drop_credit()`, `roll_kill_drop()`, the pickups deferred to the frame's end); `drop()`, `get_drop_origin()`, `collect()`, `get_ground_pickups()`, `take_ground_drops()`, `restore_ground_drops()`; `drops_enabled` / `are_drops_enabled()`.
  - `PickupView` (`scripts/view/pickup_view.gd`): the gem, the bob and turn, the hop's arc, the beam from Legendary up. `WorldView.DEFAULT_VIEW_SCENES` loads its scene at setup.
  - `hud.gd`: `show_loot_line()`, `get_loot_lines()`, `get_loot_line_color()`, fed by `Loot.item_picked_up`.
  - `SandboxLoot`: K drops its roll at the Knight's feet through `Loot.drop()`; the cursor follows each pickup.
- **Changed during the step:**
  - **Drops are off by themselves in a test scene** (`Loot.drops_enabled`, decided at the first kill, the save guard's way). Seven suites kill slimes with a tracked Knight, and a 10% drop would change their pickups and sound logs from run to run. loot_test and view_test turn drops on where they test them.
  - **The hop is the view's; the pickups come at the frame's end.** The sim pickup stands at its landing spot from the start and turns monitorable after 0.3 s, so a hopping drop is already where `take_ground_drops()` says it lies. The plan's `land_at(point)` became `hop(from, spot)` and `place(spot)`, called before the pickup enters the tree, so its view's first sync knows the hop. A kill is rolled at once, but its pickups are added deferred, because a death can come inside a hurtbox's physics callback.
  - **A corpse over a pit drops from the room's navigation** (its closest point, the leap's rule), not from `WorldQuery.push_out()` as planned. `push_out()` only searches out to twice the radius (14 px for a pickup), so a corpse mid-pit would have dropped in it. It's kept for outside a Room.
  - **Each Player gets its own collect circle.** The scene's shape is shared, so one Knight's radius would have changed every Knight's.
  - **The HUD's loot lines are centered above the ability bar** (the bottom-left is SandboxTalents' list), six at most.
  - **No Python on this machine**, so the sounds come from a GDScript tool run headless.
  - The L3 K checks now wait for the pickups to land and be taken (split so the drop and the pickup are checked apart: 3 more checks). An unrelated stale row in LOOT.md's edge cases (the return was still described as a dash) is fixed.
- **Measured** (loot and view tests, seeded; the probe in the real 3D sandbox):
  - **Rates:** 20,000 slime kills dropped 9.79% (the table: 10%). At depth 5: 12.40% (12%). 2,000 elite kills: one item every time, Uncommon or better. With +900% magic find the chance stayed at 9.92%, and 88.3% of drops were Uncommon or better (the formula: 87.1%; 40.5% without).
  - **The pop:** a landing spot 12–28 px off. A drop at the Knight's feet stays untouched for 0.3 s, then is taken 18 frames after it dropped, into the inventory and the save at once. The Rare's drop sound plays where it landed, then the pickup sound plays centered. A Common is silent, and a Legendary plays the legendary sound.
  - **Walking:** a drop 130 px off was taken when the Knight's circle met it (69.2 px: his 64 plus its 6). His speed read 120 px/s on every frame from 5 before to 5 after, with no lock and no status.
  - **The radius:** +100 u made the circle 96 px at once and took a landed drop 85 px off on the next step. Another Knight kept his 64 px, and a dead Knight took nothing.
  - **Landing:** 300 drops each beside a wall, a fence and a ledge strip: none against them, none past them, 284–286 on the open side, and the rest (all four tries failed) where they dropped. Beside a thin pit: none over it, and 64 hopped across (Open questions). Walled in 8 px around: every drop stayed where it dropped.
  - **Pits:** from the middle of a 3 m pit in a room, the drops start 12 px past its edge, and 20 of 20 land clear of it. Outside a Room, a point 4 px inside a pit's edge moved out 11 px.
  - **Ground drops:** three taken, one still hopping at its landing spot, and put back where they lay: landed, collectable, silent, the named one's dict equal. The Knight took each.
  - **The view:** half way through the hop the view stands 0.60 m over the floor on the line between the two spots. The gem hovered between 0.300 and 0.400 m and turned. A Legendary's beam was hidden while it hopped, then showed 1.25 m tall, orange at 0.55 alpha; an Exotic had none. On the plateau it hopped over the top and landed at 1.5 m. Taken, every view was gone the next frame.
  - **The real 3D sandbox** (a probe, saving off): the Knight's hits killed the elite and both slimes. The elite's Uncommon Mail Hauberk popped under Entities with its green PickupView; the slimes dropped nothing (seeded). The Knight walked onto it and took it, and the HUD read "Uncommon: Mail Hauberk". K dropped a Longsword at his feet, which he took, and the HUD added its line. The elite's drop sound was dropped `out_of_range`, because the probe killed it from about 15 m away.
  - **A note on probes:** a probe that quits while a sound plays prints Godot's leak warning at exit (a sound still playing leaks its stream, as loot_test's L5 note says). With `Audio.stop_all()` first, there's none.
- **Sensitivity:** each key check was broken on purpose once and restored, and each failed: the dummy's credit, the walk-to ray, the pit origin, the radius following the stat, monitorable from the start, the dead guard, the test-scene guard, restoring with a hop, the view's hop path.
- **Smoke run** (`sandbox_main`, `sandbox_main_layout`, `main_layout`, 600 frames each, the saves backed up first): no errors or warnings; all three saves byte-identical after.
- **Tests:** loot 706/706 (76 new in the L7 sections, 3 from splitting the L3 K checks), view 457/457 (15 new). Stats 179/179, combat 474/474, abilities 580/580, audio 110/110, champions 168/168, talents 310/310: 2,984/2,984.

### L6 – Named items, part 2: the REPLACE variants: 2026-10-04, Passed (Ryan committed it; he asked for blinks next, and the return becomes one in ABILITIES AB15)
- **Data:**
  - `data/items/item_knight_homeward_greaves.tres` (Legendary, Boots: move speed, mobility cooldown, armor) and `item_knight_last_verdict.tres` (Artifact, Gloves: attack damage, crit chance, crit damage, ability haste, all at their maximum). `knight.tres` lists all five named items in LOOT's table order.
  - `augment_lunge_return.tres` (REPLACE `ability:knight_lunge` → `knight_e_lunge_return.tres`) and `augment_judgement_leap.tres` (REPLACE `ability:knight_judgement` → `knight_r_judgement_leap.tres`).
  - `knight_e_lunge_return.tres`: Lunge's .tres with id `knight_lunge_return`, "Homeward Lunge", `variant_of` `knight_lunge`, `recast_count` 1, `recast_window` 2.5.
  - `knight_r_judgement_leap.tres`: `judgement_leap.gd`, id `knight_judgement_leap`, "Judgement Leap", `variant_of` `knight_judgement`. POINT, INSTANT with a 0.2 s cast time (it roots; not a channel), 500 range, 30 s. Tags `ultimate`, `area`, `leap`; supports `judgement_shockwave`. Judgement's damage, missing-health scaling, stun, Fury bonus, sounds and `cast_anim`.
- **Code:**
  - `CastContext.sequence`. AbilityComponent keeps part 0's dictionary with the recast sequence (`_recast[slot].sequence`) and hands it to every later part.
  - `lunge.gd`: part 0 writes `sequence[&"start"]`; part 1 (`_return()`) dashes straight back to it, ghosted, at the Lunge's speed and curve, with no hits.
  - `MovementComponent`:
    - `leap(to_px, duration)`, `get_leap_landing()`, `is_leaping()`, and the getters for the view (`get_leap_from()` / `_to()` / `_duration()` / `_time_left()`).
    - `LEAP_BLOCKING_MASK` (the knock-up's landing layers plus pits).
    - `is_airborne()` is also true during a leap.
    - `displace()` and `dash()` are dropped while a leap runs, and `stop_displacement()` lands a leap where it is.
  - `judgement_leap.gd` (extends `judgement.gd`):
    - The leap, then `_landing()`: the circle's hits in sight, each target with its own stun, one crit roll.
    - Shockwave's ring, then the Fury spent once.
    - `draw_indicator()`: the range, a line to the real landing spot, the landing circle, and Shockwave's ring when it's on.
  - `UnitView`:
    - `leap_apex_m` (2.5 m).
    - During a leap, `get_height_m()` follows the line from the start's ground to the landing's, and the model's arc rides over it.
    - The stun pose isn't played for a leap, and a cast clip holds its follow-through until the landing.
- **Changed during the step:**
  - **The landing reads the room's navigation.** `WorldQuery.resolve_valid_position()` alone sees only colliders, and nothing past a tile room's outer wall is a collider, so a leap aimed out of the room would have landed outside it. `get_leap_landing()` asks the unit's Room's navigation region for its closest point (`NavigationServer2D.region_get_closest_point()`; one room's region, so it never picks another room). That region is the room's floor less what its walls, fences, ledges and pits carve, 12 px (`nav_agent_radius`) clear of them.
    - The aimed spot itself is used when the body fits there and it's within that 12 px of the region.
    - Otherwise the region's closest point is used, and `resolve_valid_position()` then frees the body.
    - Outside a Room (the unit tests' bare Knights), it's `resolve_valid_position()` alone, back toward the unit.
  - **Nothing interrupts a leap.** A knockback mid-air would have replaced it, since the stronger-displacement rule compares distances. `displace()` and `dash()` are now refused while one runs.
  - **The model touches down with the sim.** The view saw the leap end one tick late and eased the last 0.2–0.4 m down afterwards. It now finishes the line and the arc over the landing tick and the one after it, because the view is drawn a tick behind, interpolated. Measured in the real 3D sandbox: 0.22 m at the landing tick, 0 the tick after.
  - **The L5 checks that assumed no Artifact** (the Knight's list, a third each among three Legendaries, the Artifact's Exotic fallback, the 50-roll fixture) now use the real items: four Legendaries, The Last Verdict, and a copy of the Knight without it for the fallback.
  - Test notes:
    - A talent added mid-run doesn't refill charges (Twin Lunge's second charge recharges). The test calls `reset_cooldown()`.
    - `get_recast_part()` is 1 from part 0's cast start, not from when the window opens.
- **Measured** (loot and view tests; the probe in the real 3D sandbox):
  - **The return:** back to the exact start, within 0.5 px. That holds through a unit, after being pushed 50 px aside in the window, after Tackle's stop, for both of Twin Lunge's charges, and with Long Lunge's 160 px.
  - **The cooldown:** it starts after the return (Homeward Greaves' rolled mobility cooldown in it) or when the window closes (2.33 s in still open, 2.67 s closed); Quick Footing makes it 6 s. With Twin Lunge, the running recharge didn't move during the second charge's sequence.
  - **The leap:**
    - Where aimed (within 0.5 px), 18 frames in the air.
    - Rooted for the crouch; airborne with no status and no i-frames; mask 0, restored on landing.
    - Over a unit, a fence, a ledge, a wall and a pit in one leap.
    - A hop in place when aimed at his feet.
    - A push, a stun and a dash mid-air changed nothing.
  - **The landing hits:**
    - Only the 70 px circle in sight is hit.
    - A wounded dummy takes far more (its own missing-health term); stuns are 0.75 s.
    - At 60+ Fury: ×1.30 damage, 1.25 s stuns, the Fury spent once. Kept when nothing was hit or below 60.
    - Shockwave: the ring at ×0.50 with 0.5 s stuns (1.0 s with the Fury), and no missing-health term.
    - Executioner: ×2.0 missing-health damage and no stun (0.5 s with the Fury); a kill on landing reset the cooldown, and the same kill without Executioner didn't.
    - Long Arm 650, Swift Verdict 24 s.
  - **In a Room** (a 48 px wall, a pit, a fence, the edge):
    - Aimed inside the thick wall, nearer its far side: (120, 0), past it. A real cast landed there too.
    - The pit: its rim at (−80, 22). The fence: (0, 88), past its nearer side. Past the edge: (0, −108).
  - **On terrain** (view test; a slime, so the body is 14 px):
    - Up onto the plateau, down off it, over the fence, a thin wall and a pit: all exact.
    - Into the pit: its nearer rim. Into a thin wall nearer its far face: past it at x 6.71 m. Into the wall at the room's edge: in front of it. Past the floor: its edge at z 7.63 m. Onto the cliff's rim: the floor below, clear of the ledge.
    - The real sandbox: from the floor onto the plateau's top (14, 3), and off it to (15, 7).
  - **The arc:** half way through a 0.6 s leap from the floor onto the plateau, the view stood at 0.75 m with the model 2.5 m over it. It landed at 1.5 m with the arc at 0.
- **Layout** (the probe, saving off): The Last Verdict highlighted mid-list and equipped ends at y 294 (18 rows; its leap line wraps once), the same worst case as Chains of Judgement; Homeward Greaves ends at 282. The ability bar is at 322.
- **Smoke run** (`sandbox_main`, `sandbox_main_layout`, `main_layout`, 600 frames each, the saves backed up first): no errors or warnings; all three saves byte-identical after.
- **Tests:** loot 622/622 (79 new; four L5 checks updated), view 428/428 (20 new: the leap over terrain and in the real sandbox, the arc, the clip, a guard that only Judgement Leap leaps), talents 310/310 (the variant check now covers both new variants: +2). Stats 179/179, combat 474/474, abilities 557/557, audio 110/110, champions 168/168: 2,848/2,848.

### L5 – Named items, part 1: the framework and the FLAGs: 2026-10-03, Passed (Ryan committed it and started L6)
- **Classes and data:**
  - `NamedItem` (`scripts/data/named_item.gd`): `get_ability_id()`, and `get_validation_errors(champion)` for rarity, champion, base, affixes, the FLAG/REPLACE augment rules (a REPLACE's variant supports every talent FLAG of its ability), `ability:` modifiers only on its own ability, and the champion's other named items (unique ids, one item slot per ability).
  - `ChampionData.named_items` and `get_named_item()`.
  - `data/items/`: `item_knight_tidebreaker.tres`, `item_knight_oathbound_plate.tres`, `item_knight_chains_of_judgement.tres`, listed in `knight.tres`.
  - `augment_iron_resolve_undying.tres` and `augment_judgement_drag.tres` (both FLAG), `status_undying.tres` (1.5 s, tags `undying`, `buff`).
  - Iron Resolve and Judgement list the new FLAGs in `supported_flags`.
- **Code:**
  - `Item.named`; its name, modifiers (plus the fixed ones), augments, champion id and tooltip (fixed modifiers as "+50% Cast Range (Judgement)", the augment line, the flavor).
  - Saving: `to_dict()` gains `"named"`; `from_dict(d, table, champion)` reads through the champion and lets the data win. `ChampionInventory.read_from()` passes the champion.
  - `ItemRoller.pick_named()` and `make_named()`; `roll_item()` picks a named item for Legendary and Artifact, else an Exotic.
  - `EquipmentComponent.can_equip()`: a second copy of a worn named item can't go in another slot.
  - `Loot.debug_grant_named_items()`; SandboxLoot's P grants the champion's named items.
  - `Unit.on_hit()`: Undying, after the shields.
  - `iron_resolve.gd`: `flag_undying_duration` 1.5, with an aura.
  - `judgement.gd`: `flag_drag_gap_px` 8, `flag_drag_time` 0.15; the drag, then the hit, after the drag's time. The hit moved unchanged into `_strike()`.
  - `Ability.pull_airborne()`: the toolkit's pull.
- **Changed during the step:**
  - **Cleave Wave now costs Cleave's 20 Fury.** It had no cost: AB-M built it before Cleave got its Fury cost, and nothing caught it since. Without the cost, Tidebreaker would have made Cleave free, and Thrifty Edge's −5 had nothing to reach (TALENTS.md says it reaches the wave; Ryan, 2026-09-29: "the same as Cleave"). One data line; the older wave checks still pass.
  - **The drag moved into the toolkit.** abilities_test's AB11 guard (no `displace()` in the Knight's scripts) caught the first version, which displaced the target from `judgement.gd`. The move is now `Ability.pull_airborne()`.
  - **view_test's P9 guard updated.** "Only the Uppercut uses the knock-up" now lists the toolkit's pull too, and a new check keeps Judgement the only caller of `pull_airborne()`, so no enemy knocks up the player.
  - **Named affixes ignore the slot lists.** Oathbound Plate's tenacity and both Gloves' crit damage aren't in those slots' pools, so validation doesn't check slots for named items.
  - **A stray sound at quit.** The loot test's last Judgement left its hit sound playing when the test quit, which leaked the sound's stream about two runs in three. Fixed as abilities_test does it: `Audio.stop_all()`, then 10 frames before quitting.
  - Not a bug: running the loot suite in parallel *with itself* races on its shared scratch save files.
- **Measured** (loot test, seeded):
  - 600 Knight Legendaries came out about a third each, every affix value inside the Legendary band.
  - A 50-roll Artifact fixture always rolled 1, and `make_named()` of an Artifact left the rng untouched.
  - The drag ended with the target 33.6 px from the Knight (the radii plus 8 px), and the hit landed 9–10 frames after it rose. A ground push along the same line stops at the same fence and ledge (the controls).
  - A wall slit the line of sight passes but the body can't stopped the drag, and the hit landed there.
  - Undying held at 1 health through a killing blow, a DoT tick and a shielded hit, and ended on time.
- **Layout** (the probe, saving off): Chains of Judgement highlighted mid-list and equipped ends at y 294 (its Chains line wraps once), as in L4; the ability bar is at 322.
- **Smoke run** (`sandbox_main`, `sandbox_main_layout`, `main_layout`, 600 frames each, the saves backed up first): no errors or warnings; all three saves byte-identical after.
- **Tests:** loot 543/543 (98 new; four L3 checks updated now that P grants named items and Legendaries are named), view 408/408 (the P9 guard split in two). Stats 179/179, combat 474/474, abilities 557/557, audio 110/110, champions 168/168, talents 308/308 (unchanged, run in parallel): 2,747/2,747.
  - **Named data:** the three items' data and validation; 17 broken rules caught, plus the slot and id rules among siblings.
  - **Rolls and saving:** Legendary and Artifact rolls with every fallback; names, tooltips and the save (the data wins; unreadable entries kept raw); worn once, its champion's only.
  - **Tidebreaker:** with Thrifty Edge, Long Reach, Whirling and Rending (real casts carrying their FLAGs), and wave casts counting as Cleave casts.
  - **Undying, and Oathbound Plate:** with no talent, Challenge, Bulwark, Quick Recovery and Battle Cry (real casts).
  - **Chains of Judgement:** its range with Long Arm and Swift Verdict, and the drag over a fence and a ledge, stopped by a wall, refused by an unstoppable target, with Shockwave around the landing, with Executioner, and none without the item.

### L4 – Sigils: 2026-10-03, Passed (Ryan committed it and started L5)
- **Data:**
  - `data/augments/augment_sigil_storm_strike.tres`: HIT, chance 0.15 (× the hit's proc coefficient), a `DealDamageGameplayEffect` of 30 + 40% AD magic, tagged `lightning`.
  - `augment_sigil_bloodrush.tres`: UNIT_DIED, effect target OTHER (the killer), applies `status_bloodrush`.
  - `augment_sigil_expose.tres`: STATUS_APPLIED with `required_status_tags` [`cc`], applies `status_exposed`.
  - All three are EVENT augments with an empty scope and owner SOURCE, with chain limit 2.
  - `data/statuses/status_bloodrush.tres`: move speed PERCENT_ADD +0.3, 2 s, REFRESH, tag `buff`, Iron Resolve's haste sound on apply.
  - `status_exposed.tres`: `incoming_damage` PERCENT_MULT +0.15, 3 s, REFRESH, tags `exposed`, `debuff`.
  - `loot_table_default.tres` lists the three as its `sigils`.
- **Code:**
  - `AbilityAugment.name_suffix` (new export; empty for every other augment).
  - `Item.get_display_name()` adds " of " and the suffixes, in rolled order.
  - `Item.get_tooltip_lines()` writes a sigil as "Name: description" (static `Item.get_sigil_line()`).
  - `LootTable` validation needs a `name_suffix` on each sigil.
  - The roller was unchanged: it already picked one or two different sigils, each with the same odds.
- **Changed during the step (decided while building, recorded in DECISIONS):**
  - Where the suffix lives: a field on AbilityAugment, so a sigil is one file.
  - Chain limit 2 rather than the default 1. A Storm Strike bolt's kill still counts for Bloodrush, a reaction's crowd control still Exposes, and a free cast's hits can call a bolt. None loops: a bolt is a proc, and neither Bloodrush nor Exposed is crowd control. The test checks one link deep and not two.
- **Measured (seeded):**
  - Storm Strike called a bolt on 1,000 plain hits at about 15% and at about 7.5% with coefficient 0.5. It never fired on 300 proc hits, 300 hits by another unit, or after unequipping.
  - Exposed took a hit's damage ×1.15 against the same stunned target.
  - Bloodrush's +30% and a real Iron Resolve haste summed exactly.
  - 3,000 Uniques: every sigil on about a third. 3,000 Exotics: always two different, all three pairs seen.
- **Layout** (the L3 probe, saving off): an Exotic with two sigil lines highlighted mid-list ends at y 294 (18 rows, the Expose line wrapping once). The longest pair with a wrapped status line would end near 318, still above the ability bar (322). L5's named items need another look.
- **Not built (no look):** the bolt shows only as its magic number, and Exposed only as bigger numbers (LOOT.md, The sigil pool, As built).
- **Your save:** the 7 items from the L3 play test (one Unique, one Exotic) load and save back byte-identical. The Unique and the Exotic stay without sigils, because they were rolled before L4.
- **Smoke run** (`sandbox_main`, `sandbox_main_layout`, `main_layout`, 600 frames each, the saves backed up first): no errors or warnings; `inventory.cfg`, `progress.cfg` and `settings.cfg` came back byte-identical.
- **Tests:** loot 445/445, 59 new:
  - the sigils' data and statuses; validation (a missing suffix; an empty pool still valid)
  - the rolls, names, tooltip lines and the save
  - Storm Strike, Bloodrush and Expose on a live Knight, including a real Iron Resolve and a real Judgement
  - the same sigil from two items as one; an Exotic's two both firing; unequipping
  
  L1's checks were updated for the filled pool: Unique 1 sigil, Exotic 2 different. Stats 179/179, combat 474/474, abilities 557/557, audio 110/110, champions 168/168, talents 308/308, view 407/407 (unchanged, run in parallel): 2,648/2,648.

### L3 – SandboxLoot: equipping by hand: 2026-10-03, Passed (Ryan committed it and started L4)
- **SandboxLoot** (`scripts/rooms/sandbox_loot.gd`, new; a `SandboxLoot` node in `sandbox.tscn` and `sandbox_3d.tscn`, which `build_sim()` moves into the Room like the other helpers): the list on the right, under SandboxAugments' four lines. It shows the keys, then `Inventory N   Depth D   MF +M%`, then the items as `> [Slot] Name  Rarity  ON` in their rarity colors (6 at a time, scrolling around the cursor, with "(N above)" / "(N below)"), then the highlighted item's tooltip lines and what the last key did. Keys, read raw (no input action): **J** / **Shift+J** move the cursor (held J repeats), **U** equips or unequips (a swap when the slot is filled; a ring goes in the first empty ring slot), **K** rolls `ItemRoller.roll_drop()` from its `drop_table` export (default `drop_table_elite.tres`) at the room's depth with the champion's live `magic_find`, into the inventory through `Loot.add_item()` (cursor on the new item), **P** says "No named items yet (LOOT L5)", **[** / **]** lower / raise `Room.depth` (never below 1). Public for tests: `get_items()`, `get_rows()`, `toggle()`, `roll_drop()`, `grant_named_items()`, `change_depth()`, `move_cursor()`, `get_cursor()`, `get_status()`, `get_room()`, `get_depth()`, `get_magic_find()`, `get_champion()`. It changes the real save (Ryan, 2026-10-01): K saves through `add_item()`, U through the Loot autoload's equip listener.
- **Room.depth** (`room.gd`, export, 1, at least 1) and **RoomLayout.depth** (`room_layout.gd`, export, 1), copied onto the Room by `build_sim()`. **`Loot.get_depth(node)`**: the nearest Room's depth, from the node or above it (a depth below 1 counts as 1); 1 with no Room.
- **Changed during the step:**
  - The list refreshes when the Player is *ready*, not when it enters Entities: `child_entered_tree` comes before the Player's `_ready()`, when it has no StatsComponent yet (the first run's script error).
  - **Layout, measured headless in `sandbox_main`** (a scratch probe, saving off): SandboxAugments' four lines end at y 61, not ~50 as estimated (a Label line at size 8 is ~14 px), so the list starts at 66. A RichTextLabel row at size 8 is 12 px (the font's ascent 9 + descent 3). The doc's 10 items plus a full tooltip would have run into the ability bar (y 322, x 254–386) at 640×360. So the list shows **6 items** (the `visible_rows` export), and the tooltip under it starts at its **third line**, because the highlighted row already shows the name, slot and rarity. The worst case (19 rows: an Exotic with sigils, or a named item, in mid-list) ends at y 294. Tighter line spacing (−2, 10 px rows) was tried and dropped, because it squeezes the glyphs.
  - The label ignores the mouse (`MOUSE_FILTER_IGNORE`), so a click over the list still attacks.
  - The checks for depth and magic find were shown to catch a mistake: with `roll_drop()` hard-wired to depth 1 and no magic find, both fail.
- **Smoke run** (`sandbox_main.tscn`, `sandbox_main_layout.tscn`, `main_layout.tscn`, 600 frames each, headless, the real saves backed up and hashed): no errors or warnings. On quit the Knight's empty `inventory.cfg` section was written as designed and then deleted, since no inventory.cfg existed before; `progress.cfg` came back byte-identical.
- **Tests:** loot 386/386 (52 new: depth on Room and RoomLayout, `build_sim()` copying it, `get_depth()`; SandboxLoot in both sandboxes; on a live Knight in a room, the list and its colors, ON marks, scrolling and tooltip, K at the room's depth and the Knight's magic find, a table that never drops, U equipping, swapping, unequipping exactly and filling both rings, P, [ / ] never below 1, a respawned Knight wearing what was set; the keys pushed through the viewport, a held J repeating and a held U not; K and U each saving at once, to a scratch file). Stats 179/179, combat 474/474, abilities 557/557, audio 110/110, champions 168/168, talents 308/308, view 407/407 (unchanged, run in parallel): 2,589/2,589.

### L2 – Equipping, the inventory and the save: 2026-10-03, Passed (Ryan committed it with the Progress fix and started L3)
- **EquipmentComponent** (`scripts/components/equipment_component.gd`, a child of `player.tscn`; `Player.equipment`): `SLOTS` (weapon, helm, chest, gloves, boots, ring_1, ring_2, amulet), static `get_slots_for(kind)`, `can_equip()`, `equip(item, slot, keep_current)`, `unequip(slot, keep_current)`, `get_item()`, `get_slot_of()`, `get_equipped()`, the `equipment_changed(slot)` signal, a `loot_table` export (null = the default). Pieces go on and off through `StatsComponent.add_modifiers()` / `remove_modifiers_from()` and `AbilityComponent.add_augment()` / `remove_augments_from()` under `item_<uid>`.
- **Events**: `item_equipped(unit, item)`, `item_unequipped(unit, item)` (reserved since the LOOT sync).
- **HealthComponent / ResourceComponent**: `set_gain_on_max_raise(on)` (default on; every other caller behaves as before).
- **ChampionInventory** (`scripts/loot/champion_inventory.gd`): `create()`, `add()` (uids from 1), `get_item()`, `get_equipped_item()`, `set_equipped()`, `clear_equipped()`, `get_equipped_slot(uid)`, `get_unreadable_count()`, `write_to()`, `read_from()` (unreadable entries kept raw and written back, their uids kept taken; a missing or duplicate uid renumbered; an equipped entry naming no slot or no loaded item dropped; each with a warning). `materials` is a typed `Dictionary[StringName, int]`, saved, always empty.
- **Loot** (`scripts/autoload/loot.gd`, registered in `project.godot` after Progress, before Audio): `get_inventory()`, `track()` / `untrack()` / `get_tracked_player()`, `add_item()`, `reset()`, `save()`, `saving_enabled`, `save_path`, `table`, `rng`; the equip listener (only the tracked player's items of its record; an unchanged slot doesn't save).
- **Player** (`player.gd`, additive): `equipment`; `_attach_equipment()` at the end of `_attach_champion()`: `Loot.track()`, then each saved slot in `SLOTS` order equipped as a load (`keep_current` false), a refused one dropped from the record with a warning.
- **Changed during the step:**
  - **A swap puts the new item on before taking the old one off.** With only the keep-current switch, a full-health helm swap would have lost health: the removal lowers the max and clamps first, and the raise that follows no longer adds. Now a full-health swap keeps its health, a swap to less health clamps to the new max, and taking an item off and on never heals.
  - `can_equip()` also refuses an item already worn in another slot (no move between the ring slots: unequip first) and another worn item with the same uid (one source id would strip both).
  - `Loot.save()` runs the test-scene guard before it checks `saving_enabled`. Found by reading Progress's save, which checks first: see the incident below.
  - `Loot.track()` (mirrors `Progress.track()`): the save on leaving the tree needs the player, and the equip listener needs to know whose record an event is for.
- **Incident: Ryan's `progress.cfg` was emptied** (2026-10-03, 20:19). Godot's own logs show the L1 loot test run in a window at 20:18:54; closing the window sent a close request, and `Progress.save()` ran: `saving_enabled` was still true because the L1 suite never touches Progress, the lazy test-scene guard then turned saving off *after* the check, and the empty in-memory config was written over the real file (0 bytes). Every older suite that spawns a Player latches the guard first, which is why this never happened before; stats_test and view_test don't, and have the same exposure. **Restored** from a previous session's backup of 17:22 (level 12, all 20 talents unlocked, the 5-talent loadout; hash-checked). Anything played between 17:22 and 20:18 is lost (Godot keeps five logs; nothing shows what ran then). The loot test now touches Progress and Loot on its first line and checks that neither real file changes. **Fixed with Ryan's OK** (same day): `Progress.save()` runs the guard before the check, as `Loot.save()` does. Shown first with a probe scene against a scratch file (a close request emptied it before the fix, kept it after); the loot test now opens with that check for both autoloads (scratch files only), and it fails with the fix reverted.
- **Smoke run** (`sandbox_main.tscn`, `main_layout.tscn`, 400 frames each, headless, the real saves backed up and restored after): no errors or warnings; on quit the Knight's empty inventory section is written as designed (`next_uid=1`, `items=[]`, `equipped={}`, `materials={}`), `progress.cfg` rewritten byte-identical.
- **Tests:** loot 334/334 (87 new: the close request kept out of both saves, the switch, equip and unequip with exact stats and events, swaps, both ring slots, every refusal, augments on and off, no heal from a swap, a load starting full, the record, the save through a ConfigFile's text, unreadable entries, the autoload's guard and listener, a save to a scratch file, the Player's gear at load, both real files untouched). Stats 179/179, combat 474/474, abilities 557/557, audio 110/110, champions 168/168, talents 308/308, view 407/407 (unchanged): 2,537/2,537.

### L1 – Items: data and rolling: 2026-10-03, Passed (Ryan committed it and started L2)
- **Classes:** `Item` (`scripts/loot/item.gd`, RefCounted: enums `Slot`, `Rarity`; `uid`, `rarity`, `base`, `affix_rolls`, `sigils`; `get_source_id()` `item_<uid>`, `get_slot()`, `get_display_name()`, `get_color()`, `get_affix_value()`, `get_modifiers()` (implicit copies + affix values under the source id), `get_augments()`, `get_champion_id()`, `get_tooltip_lines()`, `to_dict()` / `from_dict()`, `rarity_to_word()` / `word_to_rarity()`, `get_slot_name()`, `ROLL_DECIMALS` and `quantize_roll()`). Resources in `scripts/data/`: `ItemRarity`, `ItemBase`, `Affix` (`get_value()`, `get_band_range()`, `make_modifier()`, `get_line()`, `get_validation_error()`; static `get_modifier_error()`, `describe()`, `format_value()`, `format_percent()`), `DropTable` (`get_chance()`, `get_weights()`, `get_validation_errors()`), `LootTable` (`get_default()`, `get_rarity()` / `get_base()` / `get_affix()` / `get_sigil()`, `get_bases_for()`, `get_affixes_for()`, `get_drop_table(unit)`, `get_validation_errors()`). `ItemRoller` (`scripts/loot/item_roller.gd`): `roll_rarity()`, `roll_item()`, `roll_drop()`, `roll_in_band()`, `pick_weighted()`.
- **Data:** `data/loot_tables/loot_table_default.tres` (the 7 rarities inline, as LOOT.md's table: Exotic's count and band equal Unique's, Artifact's band 1.0–1.0; the bases, the pool, an empty sigil pool, `drop_table_by_unit` slime → regular, slime_elite → elite, default regular), `data/item_bases/` (7), `data/affixes/` (15), `data/drop_tables/drop_table_regular.tres` and `drop_table_elite.tres`. No game scene, autoload or existing script changed.
- **Changed during the step:**
  - **Rolls are kept to 4 decimals** (a rule, now in LOOT.md, Stats). Found by the round-trip check: Godot writes a raw `randf()` (a float32 value) to text with float32 precision and reads it back as a different double, and its parser doesn't read some 17-digit doubles back exactly. Measured over 200,000 rolls through `var_to_str()` / `str_to_var()`: raw rolls 199,998 mismatches; snapped to 0.000001 29,080; parsed 6-decimal strings 8; 4-decimal strings 0 (a ConfigFile round trip of 5,000: 0).
  - `roll_rarity()` takes an optional `table` after the rng (each rarity's magic find effect lives on the LootTable; null = the default). LOOT.md updated.
  - Validation: an empty sigil pool is valid (sigils come in L4); a non-empty one needs at least an Exotic's two. The pool's affixes need a slot and a weight above 0, and every slot needs at least the most affixes a rarity rolls (3).
  - Left for later steps, as planned: `from_dict(d, table)` (L5 adds the champion and the `named` key), the " of <suffix>" names (L4 decides where a sigil's suffix lives: `AbilityAugment` has no field for it).
- **Measured** (loot test, seeded, 100,000 rolls each): regular depth 1: Common 59.46% (59.5), Uncommon 26.05 (26), Rare 10.93 (11), Unique 2.08 (2), Exotic 0.83 (0.8), Legendary 0.56 (0.6), Artifact 0.096 (0.1). Elite: 0 / 35.90 / 40.14 / 10.02 / 6.86 / 6.08 / 0.99 (0 / 36 / 40 / 10 / 7 / 6 / 1). Regular depth 5 and regular +100% magic find also within 4 sigma of the formula. Per TALENTS' assumed run (96 regular kills at 10%, 4 elites): 5.71 / 3.94 / 2.65 / 0.60 / 0.35 / 0.30 / 0.05 items, as LOOT.md's table. A slime drops 10.12% of the time (12.05% at depth 5); the elite always one. (A probe over six seeds and 200,000 kills each put `roll_drop()` within 0.15 points of a bare `randf()`: no bias.)
- **Observed (content, not changed):** the Chest's pool holds exactly 3 affixes (max health, armor, magic resist), so every Rare-or-better chest rolls those same three; only their values differ.
- **Tests:** loot 247/247 (new). Stats 179/179, combat 474/474, abilities 557/557, audio 110/110, champions 168/168, talents 308/308, view 407/407 (unchanged, run in parallel): 2,450/2,450.

## 3D pivot (3D_PIVOT.md)

### Cleanup C3 – the 2D looks deleted: 2026-10-03, Passed
The last of the cleanup's three steps (3D.md, Build order after P-M), on the exact list Ryan OK'd, with his two answers: a unit's `HealthBar` stays as the bar's settings; the damage-number path without a view stays for the tests.
- **Deleted:**
  - **Scenes:** each unit's `Shadow` and `Body` (its shapes; the elite's overrides on them), the Player's `SwordPivot`/`Sword`, the `MovementVFXComponent` nodes; `main.tscn`'s `Camera` node; `use_3d_view = true` in `main_layout.tscn` and `sandbox_main_layout.tscn`; `sandbox_main_3d.tscn`.
  - **Scripts:** `game_camera.gd` and `movement_vfx_component.gd` (with their `.uid` files).
  - **Unit:** `body`, `looks_2d_off`, `_flash()`, the death squash (`_play_death()` only frees after `death_free_time`), hiding its own HealthBar at death.
  - **Player:** `sword_pivot`, `sword`, the blink, flip, bob and glow in `_process()`, `face()`, `_on_swing_started()`, `_on_swing_cancelled()`, `_on_dash_started()`, `_on_dash_ended()`, the sword tweens (`_swing_sword()` only flips `swing_side`), the death tilt (`_play_death()` is empty: the Player isn't freed).
  - **Enemy:** `_process()` (hop, eyes), the windup crouch and the attack lunge with their three signal connections, and `_bob_time` (one `randf()` fewer at `_ready()`).
  - **VFX:** `afterimage()` (Lunge only waits out its dash now) and `AFTERIMAGE_SORT_OFFSET`, `impact()`'s 2D polygon (nothing without a view). The projectile's bolt and `DRAW_HEIGHT_PX`, Cleave Wave's `_crescent()`, the 2D drawing of `aura.gd` (it keeps its lifetime and what AuraView reads), `stun_stars.gd` and `staggered_mark.gd` (both now only view sources).
  - **The AB14 2D clip players:** `AbilityComponent`'s `_get_cast_anim_player()`, `_start/_update/_finish/_stop_cast_anim()`, and `AutoAttackComponent`'s `_start/_update/_stop_swing_anim()`, which looked for an `AnimationPlayer` under `Body` (none ever existed).
  - **Data:** `HitFeel.flash_time` and `flash_modulate` (and in `hit_feel_default.tres`).
  - **Main:** `use_3d_view`, `camera`, `_setup_camera()`, the no-view branch; Main always adds the WorldView. `WorldView.setup()` lost its unused camera parameter. `GameFeel.shake()` lost its Camera2D fallback.
- **Kept:** `HealthBar` on each unit, which only holds the bar's settings and never runs or draws there (`_is_2d_bar_off()`: on a Unit); `Unit._add_number()`'s no-view path; `Player.hit_iframes_blink_period` (UnitView reads it).
- **Changed:** `SimMarker._body_color()` takes a unit's `model_color` (a scene that isn't a unit: its biggest polygon's, as before).
- **Tests:** 2,203/2,203 (stats 179, combat 474, abilities 557, audio 110, champions 168, talents 308, view 407), three rounds in parallel, no leaks.
  - **combat −2:** the HitFeel flash data check went; the flash's two checks became the `damaged` signal the model's flash reads (once per hit, none when blocked); the blink's two became one check of its period.
  - **abilities −8:** the eight AB14 clip checks moved to `view_test`; Cleave Wave's wave check now expects no crescent.
  - **Both:** the shake spies are Camera3Ds.
  - **view +6 (401 → 407):** Main's flag checks became "always the view" checks; the GameCamera-defaults check became "it's gone"; C2's section became C3's. It checks:
    - no 2D look nodes or scripts left, no `Unit.body`, HitFeel flash or `VFX.afterimage()`;
    - the HealthBar as settings, `swing_side`, the debug drawings, death and freeing, `model_color`, the ghost numbers.
    
    And new, on the Knight's model:
    - the blink;
    - Cleave's clip positioned by cast progress, its follow-through, then idle;
    - a stun's follow-through, then the stun pose;
    - Iron Resolve's clip leading by time;
    - the swing clip by swing progress, the swing's end, a cancelled swing.
- **Played** (windowed harness in the tile sandbox, saving off):
  - 7 units, none with a 2D look node, all with a bar on the overlay;
  - `swing_side` -1, 1, -1; Q, W, E and R all cast; the Knight's model blinked after a hit and showed again;
  - the dummy's bar hid at its death and it was freed after 333–334 ms;
  - the hub's flow (Start run → hub → Sandbox → hub) ran, the canvas mask restored.
  - Screenshots: the 3D dash ghosts and the bars over every unit. Every edited scene opens in a headless editor with no errors, and SimMarker's previews take each unit's `model_color`.
- **Frame times** (no screenshots, the same harness, two runs each): C3 median 5.55 ms, p95 6.8–7.0, max 10.1–12.5; the C2 build median 5.55–5.58, p95 6.7–7.3, max 10.6–12.7. Frames over 8 ms are spread over every phase in both, so they aren't any one event.
- **Found:** the COMBAT.md numbers list says the hit flash lasts 0.06 s; the model's flash (`UnitView.flash_time`) has been 0.12 s since P6. Left for Ryan.

### Cleanup C2 – the 2D looks off under the view: 2026-10-03, Passed
The second of the cleanup's three steps (3D.md, Build order after P-M): the four things that hung on the 2D looks fixed, then the looks switched off under the view. With the flag off, the 2D game plays as before.
- **The fixes:**
  - **Death:** `Unit._play_death()` frees the unit on its own tween after the new `death_free_time` (0.33 s, the 2D animation's length), whether the animation runs or not.
  - **The swing side:** `Player._swing_sword()` flips `swing_side` first, then skips the sword's animation with the looks off.
  - **Capsule colors:** new `Unit.model_color` (View group), set in `slime.tscn` (0.35, 0.85, 0.4), `slime_elite.tscn` (0.62, 0.35, 0.85) and `player.tscn` (0.32, 0.56, 0.95): their 2D bodies' main colors. `UnitView._body_color()` is `model_color × modulate`.
  - **Dash ghosts:** UnitView's new export group Dash afterimages (`afterimage_count` 4, `afterimage_interval` 0.03, `afterimage_fade_time` 0.15, `afterimage_color`), MovementVFXComponent's values. `_vfx_number()` is gone.
  - **Bars:** `ScreenOverlay._place_bar()` hides a copy when its unit dies (`is_alive()`), no longer when the 2D bar hides.
- **The switch:** static `Unit.looks_2d_off`, set by `WorldView.hide_sim()` and put back in its `_exit_tree()`. Each 2D-only look checks it when it would run (room units are ready before the view sets it). Off under it:
  - `Unit._flash()` and its death animation;
  - Player: the blink, flip, bob, sword, glow, dash alpha, swing and cast sword animations, `face()`, its death animation;
  - Enemy: `_process()` (bob, eyes), the windup crouch, the attack lunge;
  - `MovementVFXComponent` (deform hooks, physics and process, dash afterimages and dust);
  - a unit's own HealthBar (`_is_2d_bar_off()`; ScreenOverlay's copies run);
  - `VFX.impact()`'s 2D polygon, `VFX.afterimage()`;
  - the projectile's 2D bolt (its debug sweep stays), Cleave Wave's crescent;
  - `aura.gd`'s, `stun_stars.gd`'s and `staggered_mark.gd`'s `_draw()`.
- **On the floor** (Ryan's pick): the projectile's debug sweep, `MovementComponent`'s path line and speed graph, `DashComponent`'s charge pips and `AutoAttackComponent`'s aim-help drawing get `FloorOverlay.DRAWING_VISIBILITY_BIT`; so do the test abilities' beams (charged line, vector line).
- **Found while building:**
  - **A load cycle.** The switch first lived on `VFX`. stun_stars.gd, newly reading it, closed a chain: stun_stars → VFX → WorldView → GameCamera3D → Audio → CombatSounds → `Player`, which extends `Unit` while Unit was still compiling. Every suite but stats and talents failed to parse.
    - The switch moved to `Unit`, which every reader already depends on.
    - `GameCamera3D.player` (C1) is typed `Unit` and asks the new `Player.is_aiming_or_acting()` instead of Player's states.
  - **Packing hides overrides.** A harness that packs a scene with a changed property inside an instanced sub-scene loses the change unless that instance is editable.
- **Played** (windowed harness in the tile sandbox, saving off; flag on, then off):
  - Under the view `Unit.looks_2d_off` is on, and 0 of 3 slimes' 2D bodies changed scale over 2 s; with the flag off, 3 of 3 did.
  - Three swings: `swing_side` -1, 1, -1 in both.
  - The dummy was freed 334 ms after dying in both (333 without screenshots).
  - Screenshots: green slimes, the purple elite, the Knight's blue 3D dash ghosts; a slime's green movement path on the 3D floor.
  - Frame times without screenshots: median 5.49, p95 7.31, max 8.96 ms.
- **Tests:** view_test 401 (+17).
  - New `_test_looks_2d_off()`: the switch's default, set and restore; with it on, no flash, bob, 2D pillar, afterimage or 2D dash ghosts; `swing_side` still flips; a unit's own bar off and its copy on; the debug layers; `death_free_time` 0.33 and the free after it; the capsule colors; the ghost numbers equal to the 2D component's.
  - P7's bar check now kills a unit instead of hiding the 2D bar.
- All seven suites: **2,207/2,207** (stats 179, combat 476, abilities 565, audio 110, champions 168, talents 308, view 401). Saves unchanged.

### Cleanup C1 – the camera handover: 2026-10-03, Passed (Ryan's check 2026-10-03)
The first of the cleanup's three steps (3D.md, Build order after P-M), with Ryan's answers at the start: three steps with the camera first, its tuning on `CameraLook`, and the debug drawings on the floor (in C2).
- **Mapped first** (a read-only sweep of every 2D placeholder look and what depends on it): nothing in gameplay depends on them, except four things C2 fixes first:
  - a unit is freed by its 2D death tween;
  - `swing_side` flips inside the sword's animation;
  - UnitView colors capsules from the 2D body and reads `MovementVFXComponent` for the 3D dash ghosts;
  - the 3D bars copy the 2D HealthBar.
  - About 40 test checks read 2D looks (20 on 2D damage numbers); they move in C3.
- **`CameraLook`** (`camera_look.gd`): new export groups Follow, Aim lean, Pan, Shake and Debug, holding GameCamera's tuning with its defaults (`main.tscn` set none of its own): `follow_smoothing_speed` 10, `aim_lead_px` 80, the `aim_lead_*` fields, `move_lead_px` 0, `edge_pan_speed_px` 420, `edge_margin_px` 6, `shake_decay_px` 30, `debug_draw`.
- **`GameCamera3D`**, rewritten (P4's code read `source`, the 2D camera):
  - It computes the lock, the lean, the pan, the shake and the smoothing itself, from its look: `locked` (Y), `get_aim_lead()` and `get_current_lead()`, `shake()` and `shake_offset_px`.
  - New `player` (whose aiming makes the lean full; with no player it doesn't lean, as P4's camera with no 2D source didn't).
  - With `look.debug_draw` on, it draws the dead-zone oval and the two leans on a screen-space CanvasLayer (90).
  - `source` is gone.
- **`WorldView.setup()`:** it gives the camera the player and the room's bounds (`Room.get_bounds_px()`); its `camera_2d` parameter is unused (`_camera_2d`, goes in C3).
- **`GameFeel.shake()`:** the current Camera3D's `shake()` first, else a current Camera2D's (the 2D game, the tests' spies).
- **`main.gd`:** under the view it turns the 2D camera off (`enabled` false, processing disabled); the HUD's "Camera locked/free (Y)" reads the 3D camera.
- **Played** (headless harness in the tile sandbox, saving off):
  - Under the view, the 2D camera is off and not current, and the 3D one is current.
  - The mouse at the right edge leans about 40 px (idle).
  - Y unlocks it and the HUD says "Camera free (Y)"; the right arrow pans 9.12 m in 0.5 s (420 px/s: 9.19 m); Y locks it again.
  - Judgement's hit shakes the 3D camera (up to 1.9 px), not the 2D one.
  - With the flag off (the rollback), the 2D camera is current and shakes (up to 1.6 px).
  - A windowed screenshot shows the debug drawing on screen.
- **Found while building:** a test's `Input.parse_input_event()` mouse motion isn't seen by `Viewport.get_mouse_position()` until the buffered events are flushed: `Input.flush_buffered_events()` after it.
- **Tests:** view_test 384 (+13). The P4 section now drives the real mouse:
  - no player, no lean;
  - the 80 px full lean, half of it while not aiming, the full lean held 0.75 s after the aim, then half again;
  - 24 px toward the bottom edge, none inside the dead zone;
  - C to center, the bounds;
  - `GameFeel.shake()` reaching the current 3D camera, its offsets and its decay at 30 px/s;
  - Y both ways, the arrow pan;
  - `CameraLook`'s values equal to GameCamera's defaults.
  - combat_test's and abilities_test's shake spies are unchanged (no Camera3D in them).
- All seven suites: **2,190/2,190** (stats 179, combat 476, abilities 565, audio 110, champions 168, talents 308, view 384). Saves unchanged.

### P-M – the milestone: the view on by default: 2026-10-03, Passed (Ryan's feel play test 2026-10-03)
Built from 3D.md's Build order, with Ryan's answers at the start (DECISIONS.md, 3D view): a run plays room_01's layout; the hub's Sandbox stays the tile sandbox, in 3D.
- **The switch:** `main.gd`: `use_3d_view` defaults to `true` (its comment now names off as the rollback). `main.tscn` and `sandbox_main.tscn` set nothing, so both play in 3D. `main_layout.tscn`, `sandbox_main_layout.tscn` and `sandbox_main_3d.tscn` still set it explicitly (harmless, kept until the cleanup).
- **The hub:** `hub.gd`'s `run_scene` default is `res://scenes/main_layout.tscn` (was `main.tscn`); `sandbox_scene` is unchanged; `hub.tscn` overrides neither.
- **Before the answers**, screenshots of both room_01s in 3D (spawn, after walking north-east, west): the same room, the layout's kit walls where the tile room's boxes were, the camera's framing a few pixels apart (its bounds come from the tiles or the walkable floor).
- **Played** (windowed harness, saving off; both save files unchanged): hub → Start run (room_01's layout: view, layout, 6 enemies) → the dash, W, E, R → Back to hub → Sandbox (the tile sandbox: view, RoomView) → the same → Back to hub → Start run again.
  - Every time back at the hub, what the view changes is restored: the root's canvas cull mask (4294967295), `VFX.floor_squash` 0.55, `drawings_at_feet` false, no WorldView.
  - The dash is 128 px (4 m) in both rooms.
  - Q (Cleave) is refused at a run's start: it costs 20 Fury and the Knight starts at 0, as in 2D (its icon shows dimmed).
- **Frame times** (no screenshots):
  - the run 5.5 ms median, p95 6.7–7.0, max 12.3 ms after its first frame;
  - the 3D sandbox 5.56 / 6.85 / 9.44;
  - the tile room_01 in 3D 5.56 / 6.78 / 9.99;
  - the tile room_01 in 2D (the rollback) 5.55 / 6.31 / 8.47.
  - **Loading:** the first frame after Start run takes 100–160 ms (`build_sim()`, the bake, the view's setup, first draws), Sandbox 55 ms. It's a one-time pause on the scene change, within DUNGEONS' 0.5 s for a floor change.
- **Still 2D-only under the view:** the dust puffs (`MovementVFXComponent`) and the VECTOR test wall's line (the art pass).
- **Docs:** 3D.md (status, Current code, Core rules' switch, P8's room_01 line, P-M built and its rollback), TALENTS.md and DUNGEONS.md (the hub's Start run scene), DECISIONS.md, CLAUDE.md.
- **Tests:** view_test 371 (+2 net): the export is on by default; `main.tscn` and `sandbox_main.tscn` don't turn it off; the hub's run and sandbox scenes, and `hub.tscn` doesn't override them. All seven suites: **2,177/2,177** (stats 179, combat 476, abilities 565, audio 110, champions 168, talents 308, view 371).

### P7's 2D-only looks – swing arcs from the feet, impact pillars in 3D: 2026-10-03, Passed (Ryan's check 2026-10-03)
The small step Ryan put before P-M (DECISIONS.md, P8's answers), from 3D.md's Build order.
- **Swing arcs:**
  - New `VFX.drawing_origin(unit)` and `VFX.drawings_at_feet`: the body's center in the 2D game, the feet while a WorldView shows it. `WorldView.flatten_floor_drawings()` sets it and `_exit_tree()` puts it back, with `floor_squash`.
  - The five `VFX.slash()` calls use it: `player.gd` (the combo's swings), `cleave.gd`, `cleave_wave.gd`, `judgement.gd` (on its target) and `uppercut.gd`. Each is a one-expression replace of `get_center()`, in the files the step names, plus the P9 test Uppercut.
- **Impact pillars:**
  - New `scripts/view/pillar_view.gd`, `scenes/view/pillar_view.tscn` and `scripts/view/pillar.gdshader`.
  - `VFX.impact()` keeps its 2D pillar and, with a view, also raises a `PillarView` through `add_scene_at()`: `height` px as meters, the 2D tween's narrowing, stretch and fade, then freed. New `VFX.PILLAR_VIEW_SCENE`, `warm_up_pillar()`; `WorldView.setup()` calls the warm-up.
  - **Found while building:**
    - **Pillars were hidden inside the units they hit.** With a plain material, the first screenshots showed Judgement's pillar only where it rose above the dummy, and Lunge's not at all: a slime is 1.32 m tall, Lunge's pillar 1.1 m. `pillar.gdshader` draws each vertex 0.8 m nearer the camera along its own view ray, so it keeps its place on screen and shows in front of the unit.
    - **A 10–14 ms hitch on the first pillar:** Judgement's hit frame took 23–27 ms against 12–13.5 ms without a pillar. With the warm-up pillar at setup (invisible, 0.05 s) it's 13.0–13.4 ms.
    - **Each `VFX.impact()` cost 1.4–1.9 ms:** its `load()` result was dropped with the last pillar, so every hit read the scene file again. `VFX` keeps it now (`_pillar_scene`), and the shared beam mesh is set up once (setting its radii again rebuilt it). A call costs about 65 µs (275 µs the first).
- **`WorldView.add_scene_at()` stands on the ground** (`ground_height_m()`): P7's comment said the floor was flat until P9. A pillar on the perch dummy stands at 1.5 m.
- **Measured** in the 3D sandbox (windowed harness, saving off):
  - the swing arc sweeps from the Knight's feet;
  - Judgement's pillar stands at the dummy's feet (11.5, 0, 10.5) and rises 2.8 m in front of it;
  - Lunge's two pillars show in front of both dummies;
  - a pillar on the perch dummy stands on the plateau (y 1.5).
  - Frame times over 18 s: median 5.5 ms, p95 6.7–6.9 ms, max 13.0–13.4 ms, the same as without pillars (max 12.4–13.5 ms on Judgement's hit).
- **Tests:** view_test 369 (15 new, `_test_arcs_and_pillars()`): every `VFX.slash()` call through `drawing_origin()`, the origin in 2D and under the view and back, nothing 3D without a view, the warm-up, the pillar on the plateau and the floor, its height, beam, shader, shared material and mesh, its fade, its end.
- All seven suites: **2,175/2,175** (stats 179, combat 476, abilities 565, audio 110, champions 168, talents 308, view 369). Saves unchanged; the headless editor opens the 3D sandbox clean.

### P9 fix – a knock-up's landing on stairs and ramps: 2026-10-03, Passed (Ryan's check 2026-10-03)
Ryan, at his P9 check: a unit knocked up onto the stairs or the ramp (from the plateau or elsewhere) teleported back to where it was knocked from.
- **Reproduced** in the 3D sandbox (scratch harness, saving off). The PerchDummy (radius 14 px) was knocked 2 m with the Uppercut:
  - from the plateau onto the stairs, a little west of their middle: it landed at (12.42, 6.47) and was put back on the plateau at (12.69, 4.87), 12 px from its start;
  - onto the ramp, a little north of its middle: it landed at (17.80, 2.65) and was put back exactly at its start;
  - knocked straight down their middle, it stayed.
- **Cause:** the ramp and stairs are 2 m wide, and each side carries a 0.25 m ledge strip (`derive_ledges()`: the top side's cell). A 14 px body has a free band only 0.6 m wide for its center. `resolve_valid_position()` stepped a landing outside it back along the push line, and a push running along the stairs or ramp touches a strip almost all the way back.
- **Fix** (`world_query.gd`): new `WorldQuery.push_out(point, from, radius, mask)` and `PUSH_OUT_DIRECTIONS` (16).
  - It finds the shortest move that frees the body: rings 1 px apart out to twice the radius, the center crossing nothing on the way.
  - If the center itself is inside something, the move never goes farther along the push.
  - `resolve_valid_position()` tries it before its old step back along the line, which stays as the fallback. `movement_component.gd` is unchanged.
- **Measured** with the fix (the same harness, 10 cases):
  - stairs west of middle: nudged 9 px sideways, onto the stairs;
  - diagonal onto the stairs: 13 px;
  - center inside the stairs' side strip: 18 px inward, onto the stairs;
  - the ramp: 2 px;
  - floor onto the stairs from the side: 7 px onto them;
  - plateau middle to the south rim (center in its strip): back on top, just inside it;
  - from the edge: off the cliff, the full 2 m;
  - from below to the rim: back below;
  - from below over the rim onto the top: unchanged (P9's design).
  - `push_out()` costs about 0.4 ms when the body overlaps something (about 170 shape queries), once per landing.
- **Tests:** view_test 354 (6 new, `_test_landing_off_center()` on the 3D sandbox's terrain without its units). Three of the checks fail on the old code, as the bug does.
  - **A flaky P9 check fixed:** "a path to the top of a plateau with no way up ends at its foot" failed in 4 of 5 parallel runs. Maps sync asynchronously, so under load the shared map can still hold the previous fixture's region, whose ramp leads up. It now uses a navigation map of its own and waits for its first sync: 8 of 8 parallel runs pass.
- All seven suites: **2,160/2,160** (stats 179, combat 476, abilities 565, audio 110, champions 168, talents 308, view 354). Saves unchanged.

### P9 – terrain and airborne: 2026-10-03, Passed (Ryan's check 2026-10-03; one fix after it, above)
Built from 3D.md and 3D_PIVOT.md's plan (its P8), with Ryan's answers at the start (DECISIONS.md, 3D view):
- pits stay their own step;
- a passive dummy goes on the perch;
- no test pull;
- the Knight's test knock-up is the Uppercut, on W in the 3D sandbox only.
- **Statuses:**
  - New `data/statuses/status_airborne.tres` (cc, airborne, debuff; blocks all four; REFRESH_LONGER; 0.75 s default; `ignores_tenacity`; not `cleansable`) and `status_elevated.tres` (`elevated`; -1 = until removed; IGNORE).
  - New StatusEffect fields `ignores_tenacity` (false) and `cleansable` (true). `StatusComponent.apply_status()` skips tenacity for the first; `remove_statuses_with_tags()` skips a status that isn't cleansable.
- **Movement** (`movement_component.gd`):
  - `GHOST_KEEP_MASK` (1 and 1024): the ghosted dash keeps walls and ledges. This is the approved one-line replace of `collision_mask & 1`.
  - While a unit is airborne and displaced, its move drops pits, low obstacles and ledges (`AIRBORNE_IGNORED_MASK`).
  - At the end of an airborne displacement, `_land()` uses `WorldQuery.resolve_valid_position()` against walls, low obstacles and ledges, back toward where the push started.
  - New `is_airborne()` and `_displace_from`.
  - **WorldQuery:** new `resolve_valid_position(target, from, radius, mask)` and `is_point_free()`.
- **Walking masks:** `player.tscn` and `slime.tscn` (the elite inherits it) went from 71 to 1095, adding ledges. Project settings name layers 6 `pit`, 7 `low_obstacle` and 11 `ledge`.
- **The melee rule:**
  - `AbilityUtil.can_reach()`. `HitPipeline.resolve()` blocks a melee hit on an elevated target from a unit that isn't elevated.
  - `HitPipeline.basic_attack()` tags a MELEE combo's swings `melee`. The combo's aim help (`_find_assist_target()`) skips a target it can't reach.
  - `melee` was added to `knight_q_cleave.tres` and `knight_e_lunge.tres` (approved in P1; the tests check tags with `in`, so none changed).
  - New `Perch` (`scripts/world/perch.gd`, `scenes/world/perch.tscn`): `elevated` while a unit's feet are inside.
- **The test knock-up:** new `scripts/abilities/test/uppercut.gd` and `data/abilities/test_w_uppercut.tres`. `SandboxAbilities.test_w` (new, additive, like `test_q`).
- **Terrain in the room kit** (`RoomLayout`):
  - `ground_grid()` (the walkable faces rasterized on a 0.25 m grid) and `derive_ledges()` (cells over a drop of more than 0.3 m, merged per row).
  - `make_ledge_body()`: one `Ledges` body on layer 11 under `Footprints`.
  - `get_height_range_m()`. `get_floor_materials()` covers every mesh using the floor shader.
  - A yellow derived-ledge preview in the editor, recomputed when the walkable meshes move; in play with `debug_draw`.
- **Kit pieces** (generated by a scratch Godot script): `plateau_4x4`, `ramp_4x2`, `stairs_3x2` (a hidden walkable ramp; the steps are decoration); materials `cliff_rock` and `floor_stone_plain`.
- **`sandbox_3d.tscn`, edited in place** (+34 lines):
  - a plateau (x 12..16, z 1..5), a ramp from the east and stairs from the south;
  - a `Perch` marker (4 × 4 m, with its answers noted) and a passive `PerchDummy`;
  - `SandboxAbilities.test_w` set to the Uppercut;
  - the pebbles that stood there moved aside.
- **View:**
  - `EntityView.get_height_m()` stands on the ground: `ground_height_m()` follows `WorldView.ground_height_m()`, a downward ray on the floor layer, at up to 8 m/s.
  - The projectile view keeps 0.9 m over the ground, eased 15% a tick, never closer than 0.15 m.
  - Stun stars and the staggered mark sit over the model's top (`WorldView.unit_top_m()`).
  - `UnitView`: the airborne arc (`airborne_apex_m` 1.2, `curve_airborne.tres`, interpolated; a refresh starts from the current height); the stun clip while airborne.
  - `FloorOverlay.drop_m` (from the layout's height range) and `GameCamera3D.screen_to_floor_below()`.
  - The floor's shader fades drawings on faces steeper than about 45°.
- **Tests:**
  - **combat_test 476** (14 new):
    - the melee tags;
    - a combo swing tagged melee;
    - `can_reach()` both ways;
    - `resolve()` blocking;
    - the aim help skipping the target;
    - a real swing from below blocked and from the perch landing;
    - the Uppercut: 0.75 s up, 2 m back, landing.
  - The tests start from a fresh Knight, since C2's last check leaves him dead.
  - **view_test 348** (60 new). Fixture layouts with a plateau, a ramp, a fence and a wall:
    - **Statuses:** the airborne and elevated data; tenacity, cleanse, unstoppable, i-frames, juggles.
    - **The grid and the ledges:** the grid's heights; ledges along the plateau but not at the ramp's junction or foot, at the top's height; the `Ledges` body and the bake.
    - **Walking and the dash:** walking and the dash stop at a cliff, the old walls-only dash wouldn't have, a fence stops walking but not the dash; projectiles and sight cross a ledge.
    - **Judgement's path:** a path to an island ends at its foot.
    - **Knock-ups:** over a fence and a ledge (stopped when not airborne), walls still stop them, landing back out of a fence.
    - **The perch:** by the feet.
    - **Under the view:** the ground's heights, a unit's view on the top, the arc's apex and landing, the window covering lower floor.
    - **The sandbox:** its terrain corner.
    - **Enemy knock-ups:** a project scan finds only the test Uppercut using status_airborne, so no enemy knocks up the player.
    - **Updated:** the P8 walking-mask check (71 → 1095) and the sandbox marker check (the perch's two markers aside).
  - **Found while building:** four fixture layouts my tests built weren't freed (a leak at exit), so `_terrain_room()` now frees them.
- **Measured** (windowed scratch harnesses, saving off):
  - **The cliff:** walking north into the plateau's cliff stops at z 5.34 m, the cliff at 5.0 plus the Knight's radius, and so does the dash.
  - **The melee rule:**
    - a swing at the perched dummy from below: 280 → 280 (blocked);
    - up the stairs, the Knight is elevated with his view at 1.50 m;
    - a swing from the perch: 280 → 216.
  - **The Uppercut:**
    - It carries the dummy off the plateau's edge to z 6.0 m, below the cliff, where it's no longer elevated, its view at 0 m.
    - From mid-plateau, a 2 m push ends on the cliff's edge, inside its ledge, so the dummy lands back on top (the landing rule).
    - On open floor it pushes exactly 64 px. A dummy touching the Knight loses the push's first tick (53 of 64 px), from the two bodies' contact.
  - **Judgement from below:** cast from z 9.5 m at the perched dummy; the Knight walked to z 7.66 m, below the cliff, and the hit landed.
  - **The ramp:** half way up, the view stands at 1.20 m, its slope exactly.
  - **Frame times** (no screenshots): median 5.53–5.61 ms, 95th percentile 6.63 ms, max 10.7–10.8 ms (the first dash). P8's sandbox run: median 5.61 ms, the same as before.
  - **The editor:** the headless editor opened `sandbox_3d.tscn` without errors and changed no project files.
- **Tests:** stats 179, combat 476, abilities 565, audio 110, champions 168, talents 308, view 348: **2,154/2,154**. `settings.cfg` and `progress.cfg` were unchanged by every run (re-hashed at the step's start, after Ryan's P8 play saved progress at 12:20).

### P8 – rooms built in 3D: 2026-10-03, Passed (Ryan's check, 2026-10-03; room_01's layout awaits his confirmation)
Built from 3D.md, with Ryan's answers at the start (DECISIONS.md, 3D view): fences block walking now and pits wait; the 3D sandbox plays from a new scene; P7's 2D-only looks get their own step before P-M.
- **New classes** (`scripts/rooms/`):
  - `RoomLayout` (`room_layout.gd`, `@tool`): `build_sim()`, `validate()`, `check_asset()`, `make_footprint_body()`, `footprint_outline_m()`, `get_bounds_m()` / `_px()`, `build_floor_pick()`, `get_floor_materials()`, the lists (footprints, markers, meshes, walkable meshes) and the geometry helpers (`transform_in()`, `solid_slices()`, `solid_faces()`, `cross_section()`, `inside_section()`, distances, `polygon_area()`).
  - `Footprint` (`footprint.gd`, `@tool`): `Kind` (WALL, LOW_OBSTACLE, PIT, LEDGE), `polygon` (empty: derived), `slice_height_m`, `get_outline_local()`, `get_slab_local()`, the layer; it draws its own outline.
  - `SimMarker` (`sim_marker.gd`, `@tool`): `scene`, `properties`, `make_sim_node()`; it shows the scene's model or capsule in the editor.
- **Changed:**
  - **`room.gd`:** `Tiles` is optional (`get_node_or_null`); new `bounds_px`, `get_bounds_px()`, `NAV_BLOCKING_LAYERS` (the bake parses layers 1, 6, 7 and 11). A tile room's bake is unchanged: same outline, and it has only layer 1.
  - **`main.gd`:** a `RoomLayout` room scene is built with `build_sim()` (new `Main.layout`). The camera bounds come from `room.get_bounds_px()`. With the view off, a layout is freed with a warning.
  - **`world_view.gd`:** `setup()` takes the layout, moves it under the view, adds its floor pick, and hands its floors' materials to FloorOverlay. New `WorldView.layout`.
  - **`floor_drawings.gdshader`:** `albedo`, `albedo_alt`, `checker_m` (RoomView's look unchanged).
  - **Walking masks:** `player.tscn` and `slime.tscn` (the elite inherits it) went from 7 to 71, adding layer 7 (Ryan: fences block now).
- **New scenes** (generated by a scratch Godot script, so the scenes, transforms and materials are Godot's own format):
  - The placeholder kit in `scenes/rooms/assets/`: 3 floors, 4 walls, an archway, an L-shaped building, a fence, a pit, two rocks, the lighting. Eight materials in `materials/`.
  - `scenes/rooms/sandbox_3d.tscn`: 26 wall pieces, 56 floor pieces and the props. It has the tile sandbox's six markers, spawn and four helpers at the same points.
  - `scenes/rooms/room_01_layout.tscn`: 98 wall pieces and 256 floor pieces from room_01's tiles, its six slimes and its spawn.
  - Play scenes `scenes/sandbox_main_layout.tscn` and `scenes/main_layout.tscn`: `main.tscn` with the layout and the view on.
- **Found while building:**
  - **The boulder:** the validator first flagged its derived outline as an invisible wall (0.43 m), since the middle of its slice has no faces near it. Points inside a closed mesh's cross-section now count as covered; a hull over an archway is still flagged. Pits skip that check.
  - **Marker previews in play:** the editor-only previews showed in play, because Godot turns `_process` on at ready, which undid turning it off in `_enter_tree()`. The previews now turn processing off inside `_process()`. (3D.md, Engine facts.)
  - **Moved helpers:** helper nodes moved into the Room warned about an inconsistent owner, so the move now clears it.
  - **SurfaceTags:** it isn't built anywhere, so footprints carry no surface tags yet.
- **Tests:** view_test 288 (54 new for P8, 1 for the number stacking).
  - **The fixture layout** (a floor, a wall, a fence, a pit, pebbles, a marker, the spawn, a helper):
    - colliders per kind and layer, their outlines in px (a derived wall exactly its box), a flat 2D look;
    - the marker in Entities with its properties, the spawn, the helper moved in, the bounds;
    - the bake (open floor on the navmesh; the wall, fence and pit carved out).
  - **The validator:** an unmarked solid mesh, two empty footprints, a hull over an archway (and the drawn version passing), a mesh sticking out by 2 m, each flagged; a boulder's derived outline passes.
  - **The tools in play:** the footprint previews are hidden in play, drawn with `debug_draw`, and left out of the layout's mesh lists. A marker shows nothing in play, and its editor look is a 0.55 m capsule with its name.
  - **A layout under WorldView:** it's the look, with its pick body, the floor material's drawings and its fading asset; the pick lands on its floor.
  - **The real layouts:**
    - the 3D sandbox silent, with the tile sandbox's markers, spawn and helpers, and walls, a fence and a pit;
    - room_01's layout silent: all 924 tile cells match, a wall cell under a wall footprint and a floor cell not; its slimes and spawn match;
    - both play scenes;
    - the walking masks (71) on the player, the slime and the elite.
- **Measured** (windowed scratch harness, saving off):
  - **The 3D sandbox:**
    - Walking south into the fence stops at 418.6 px: its edge (429.6) minus the Knight's radius. The dash crosses it to 546.5 px.
    - The tall wall fades with the Knight behind it.
    - A telegraph draws on the kit floor. The slimes chase around the fence and the pit.
    - Frame times with no screenshots: median 5.62 ms, 95th percentile 6.46 ms, max 10.3 ms.
  - **room_01's layout:** median 5.50 ms. The validator runs in 13 ms and `build_sim()` in 23 ms. The overlay window is 2560 × 1280 texels, the room's 40 × 20 m of floor.
  - **A headless editor** opened `sandbox_3d.tscn` (the tool scripts ran) with no errors and changed no project files. It left `sandbox_3d.tscn` as the open tab in Godot's editor-layout cache.
  - **Screenshots:** the sandbox (the archway partition, the tall wall faded, the building faded, the fence, the pit, the rocks and pebbles, the telegraph on the kit floor) and room_01's layout.
- **Tests:** stats 179, combat 462, abilities 565, audio 110, champions 168, talents 308, view 288: **2,080/2,080**. `settings.cfg` and `progress.cfg` were unchanged by every run (hashed again at the step's start, after Ryan's P7 play saved progress at 11:16).

### P7 – floor drawings and the screen overlay: 2026-10-03, Passed (Ryan's check, 2026-10-03)
Built from 3D.md. Played from `scenes/sandbox_main_3d.tscn`.
- **`FloorOverlay`** (`scripts/view/floor_overlay.gd`, new):
  - A SubViewport sharing the sim's World2D. It draws canvas visibility layers 2 and 3, on a transparent target, with no 3D, at 2 texels per sim px.
  - Its window is the floor the camera sees around its focus plus 2 m, rounded up to 64 texels, kept in the room and snapped to whole texels. The seen floor comes from the screen's four corners through `GameCamera3D.screen_to_floor()`, shake aside.
  - It's resized only when the screen's shape changes. At the default look: 2624 × 1664 texels. In the 30 × 20 m sandbox it's the room's size (1920 × 1280) and doesn't move.
- **The floor's shader** (`scripts/view/floor_drawings.gdshader`, new):
  - RoomView's floor keeps P3's look (its vertex colors, roughness 0.95) and samples the overlay at each point's x/z.
  - The drawings are unlit: un-premultiplied, converted to linear, and added as emission over the floor, which they cover by their alpha. So a telegraph reads the same in a shadow.
- **What draws on the floor:** canvas visibility layer 3 (`FloorOverlay.DRAWING_VISIBILITY_BIT`). The 2D game draws every layer, so nothing changes there.
  - `Telegraph` (in `_init()`), `VFX.ring()` and `VFX.slash()`.
  - A unit's own drawing (in `Unit._ready()`): the hover ring and the Player's ability indicators. The unit's children (its 2D body, its bar) stay off the overlay.
- **True circles under the view:** `VFX.floor_squash` is 0.55 in 2D and 1 while a WorldView shows the game. The hover ring and `VFX.ring()` read it; it goes back to 0.55 when the view leaves.
- **`ScreenOverlay`** (`scripts/view/screen_overlay.gd`, new; CanvasLayer 0, under the HUD):
  - Health bars: a copy of each unit's 2D HealthBar, 3 px over its model's head, fed by its HealthComponent (`HealthBar.health`, new, additive). The copy hides with the 2D bar and goes with the unit.
  - Damage numbers: they appear at 0.8 of the model's height and stay where they appeared in the world.
  - Exports: `bar_gap_px` 3, `number_height_share` 0.8, `number_scale` 1 (the 2D size).
- **`Unit._add_number()`:** under a view, the number goes to the ScreenOverlay. The 2D path is unchanged.
- **`VFX.spawn_scene()`:**
  - A scene with a Node3D root goes into the view through `WorldView.add_scene_at()`: on the floor at its point, its +Z along the angle, the root's own transform kept.
  - Without a view it isn't spawned. Node2D roots are unchanged.
- **`WorldView`:**
  - `setup()` makes both overlays. The screen overlay comes before the views, so every unit's bar comes with its view.
  - `WorldView.of(node)` (the group `world_view`) is how sim code reaches the view.
  - `flatten_floor_drawings()`.
- **Tests:** view_test 233 (66 new).
  - **The window:** the overlay's settings; the default look at 16:9 (22.9 m across the bottom edge, 36.1 m across the top, 8.4 m in front of the focus, 13.3 m beyond it; with the margin, 2624 × 1664 texels); a 30 × 20 m room's 1920 × 1280; the corner kept in the room and on whole texels.
  - **The mapping and following:** a sim point lands on the texel the floor's shader reads at its x/z; the slam's 40 px radius is 1.25 m; the window follows the camera and updates the floor's material.
  - **What draws:** telegraphs, rings, slashes and a unit's own drawing are on layer 3; its body and bar aren't; every ancestor passes the mask; true circles under the view, and 0.55 back after it.
  - **Setup:** `WorldView.of()`; setup's overlays; the room floor's material.
  - **The screen overlay:** a unit's bar (a copy, fed by its health, 3 px over the head, hidden with the 2D bar, made for a unit added later, gone with the unit); a number on the overlay at 0.8 height that stays at its world spot as the camera moves, then goes; the 2D path without a view.
  - **`spawn_scene()` with a Node3D root:** none without a view; with one, its place, its turn and `setup()`; a Node2D root as before.
- **Measured** (windowed scratch harnesses, saving off; RTX 4070 SUPER, D3D12, 180 Hz):
  - **The overlay's own cost per frame** (P6's timeline, 1,379 frames): GPU median 0.014 ms, 95th percentile 0.024 ms, max 0.04 ms; CPU (render) median 0.051 ms.
    - Turning its updates on and off in four blocks of 120 frames changed neither the frame time (median 5.56 vs 5.55 ms) nor the root's GPU time (noise, 0.37–0.45 ms either way).
    - The estimate in 3D.md was "well under 0.1 ms".
  - **The slam's circle:** a 40 px (1.25 m) telegraph on open floor, its outline found on screen along 24 rays (bilinear samples).
    - It lies on the sim circle within 0.41 window px, mean −0.16 px. At about 48.5 px per meter there, that's under 1 cm on the floor.
    - A first try placed the circle partly over wall cells (no floor there) and under the sandbox's talent list: only 15 of 24 rays found it.
  - **Frame times on P6's timeline** (no screenshots): median 5.56 ms, 95th percentile 6.59–6.63 ms; the first dash 10.4–10.9 ms; the first stun 12.6–13.2 ms. The same as P6.
  - **Screenshots:**
    - the slam circle;
    - the hover ring, a true circle on the floor;
    - the swing arc and Cleave's cone indicator on the floor, the cone where the cursor points;
    - green and red bars over the models, the trail chunk after a hit;
    - Judgement's "214" over the dummy, with its ring and stars;
    - with the view off, the 2D game as before.
- **Found while building:**
  - The headless test window is 640 × 640, not the game's 640 × 360. The check of the default look's window puts its camera in a 640 × 360 SubViewport.
  - On this machine, each `print()` into a pipe took about 15 ms on 2026-10-03, and combat_test's hitstop check ("a shorter one changes nothing") failed on the committed HEAD too. With the output to a file, every suite is green. A harness issue, not the game's.
- **Not shown in 3D yet** (2D-only looks):
  - `VFX.impact()`'s vertical pillars (Judgement, Iron Resolve, Lunge, projectile hits).
  - Swing arcs (`VFX.slash()`) are centered where their callers pass `get_center()`, the 2D body's center: 0.3–0.5 m north of the feet on the floor.
- **Tests:** stats 179, combat 460, abilities 565, audio 110, champions 168, talents 308, view 233: **2,023/2,023**. `settings.cfg` and `progress.cfg` were unchanged by every run (hashed at the step's start).

### P6 – views: 2026-10-03, Passed (Ryan's check, 2026-10-03)
Built from 3D.md, with Ryan's answer at the start: the Knight's clip hooks name his model's clips (DECISIONS.md, 3D view). Played from `scenes/sandbox_main_3d.tscn`.
- **The Knight's placeholder model** (approved P1):
  - `art/models/placeholder/kaykit_knight/`: `Knight.glb`, its texture and `LICENSE.txt`, copied from branch `spike/3d-p0b` (no new download).
  - `kaykit_knight.tscn`: an inherited scene scaled 0.7338, so the helmet's top in Idle is at 1.8 m (2.453 model units, measured). The spare weapons and three of the four shields are hidden; the sword and the badge shield stay, as in P0b.
  - New `res://CREDITS.md`: KayKit's CC0 entry, and the note that placeholders won't match the hand-painted style.
- **Sim side** (additive):
  - `Unit`: `model_scene`, `view_scene` (export group View), the group `view_source` in `_ready()`, `get_view_scene()`.
  - `ChampionData.model_scene`; `Player._apply_champion()` copies it. `data/champions/knight.tres` points at `kaykit_knight.tscn`.
  - `Projectile`, `aura.gd`, `stun_stars.gd`, `staggered_mark.gd`: `view_scene`, the group, `get_view_scene()`; `aura.gd` also `get_age()`.
  - Each loads its default view scene only when asked.
- **Data (presentation only):**
  - `combo_knight.tres` swings 1–3 and the dash strike: `swing_anim` = `1H_Melee_Attack_Slice_Diagonal` / `_Slice_Horizontal` / `_Chop` / `_Stab`.
  - `cast_anim`: Cleave and Cleave Wave `_Slice_Horizontal`, Iron Resolve `Block`, Lunge `_Stab`, Judgement `_Chop`.
- **View side** (new):
  - `EntityView` (`scripts/view/entity_view.gd`): `setup()`, `sync()` with the teleport snap, `get_height_m()`, `on_sim_exited()`, `_sim_position_px()`.
  - `UnitView` (`unit_view.gd`, `scenes/view/unit_view.tscn`):
    - the model or a placeholder capsule;
    - turning at 20/s;
    - the base clips by role;
    - swing and cast clips by interpolated progress;
    - the flash overlay (`flash_overlay.gdshader`);
    - death outliving the unit (`death_linger` 1.6 s);
    - the i-frame blink;
    - pooled dash afterimages;
    - placeholder squash and stretch.
  - The projectile view (a bolt at 0.9 m tinted by `icon_color`; a slab for waves 0.5 m+ wide; an impact flash), the aura view (a floor ring), the stun stars view and the staggered mark view, each with its scene in `scenes/view/`.
- **`scripts/view/world_view.gd`:**
  - The generic mechanism replaces P3's stand-in capsules: `watch_sim()`, `view_of()`, `unit_height_m()`, `_add_view()`.
  - Views sync in its physics tick.
  - The camera follows the player's UnitView, and the fade and the on-screen pick use the views.
  - The default view scenes are loaded at start.
- **Tests:**
  - **abilities_test** (approved): the two "hooks empty" checks became four (VFX hooks empty; the clip hooks name the clips above): 565.
  - **view_test**: 167 checks (37 new), and the P5 on-screen checks now run on UnitViews.
    - Nothing without a WorldView.
    - A unit's view: where it is, the 0.55 m by 1.32 m capsule, the flash overlay and value, the physics-tick follow, the facing rule, the swing-clip timing (start, half way, strike at the windup's share, end).
    - A dead unit's view outlives it then goes; a removed one goes at once.
    - The Knight's model: the data points at it, gear hidden and kept, 1.8 m tall, every role and hook clip exists.
    - The bolt: height, yaw, tint; a wave's slab; it stays for its impact.
    - The aura's ring: size, place, gone with it. The stars and the mark over the model, gone with the statuses.
- **Found while building:**
  - The five `cast_anim` lines first read empty: inserted before the `.tres`'s `script =` line, they landed on a plain Resource and were dropped silently. Into 3D.md, Engine facts.
  - Baking the skinned Knight's pose for each afterimage cost up to 40 ms a dash (and fails headless), so afterimages use pooled model copies posed by their own AnimationPlayer.
  - Each new view scene's first load cost 19–24 ms on the frame its first stun, aura or mark appeared, so WorldView loads them at start.
  - A `--script` harness must not use project class names as types: it compiles before the autoloads exist.
- **Measured** (windowed, from scratch harnesses with saving off; real time between frames, no screenshots, since a screenshot alone stalls a frame by about 45 ms). Timeline: idle, run, the 3-swing combo, a dash, Judgement on a dummy, Iron Resolve, Lunge, Cleave, a second dash, a dummy Staggered.

  | | 3D view | 2D game, same timeline |
  |---|---|---|
  | Median frame | 5.5–5.6 ms (180 Hz) | 5.5 ms |
  | 95th percentile | 6.5–6.7 ms | 6.2–6.3 ms |
  | First dash | 10.4 ms | 10.1–10.4 ms |
  | Second dash | at most 7.1–7.5 ms | |
  | Judgement's stun (first stars) | 12.5–13 ms | 8.3 ms |
  | Iron Resolve (first aura) | 8–8.7 ms | 7.2–7.4 ms |

  - So the view adds about 4–5 ms only to the first stun's frame (its first stars) and about 1 ms to the first aura. Before loading the view scenes at start, those were 24 and 22 ms. Before the afterimage pool, a dash's frames reached 27–47 ms.
  - The scripted walk: every unit identical in 2D and 3D until the dash (frame 644).
  - Screenshots:
    - the Knight idle, running and mid-swing (the strike poses);
    - the blue afterimages in the dodge pose;
    - Iron Resolve's ring at his feet;
    - Judgement: the walk into range, then the white hit flash and the stars over the dummy;
    - the cracked ring over a Staggered dummy;
    - green slimes with facing nubs, the purple elite.
- **Tests:** stats 179, combat 460, abilities 565, audio 110, champions 168, talents 308, view 167: **1,957/1,957**, all seven suites in parallel. `settings.cfg` and `progress.cfg` were unchanged by every run (hashed again after Ryan's P5 play, which saved progress at 23:49).
- **Not in P6:**
  - the floor drawings, damage numbers, health bars and the hover ring (P7);
  - `VFX.spawn_scene()` for 3D scenes (P7);
  - the VECTOR test wall's line and the 2D VFX polygons (dust puffs, swing arcs: P7 or the art pass);
  - height (P9).

### P5 – aim: 2026-10-02, Passed (Ryan's check)
Built from 3D.md. Played from `scenes/sandbox_main_3d.tscn`.
- **`scripts/player/player.gd`** (the approved replace, 2026-10-01): the 10 direct `get_global_mouse_position()` calls now call `get_aim_point()`. `get_aim_point()` and `_enemy_under_mouse()` get a view branch; with no view they're exactly as before.
  - New `var world_view: WorldView`, set by `WorldView.setup()`; null in the 2D game and every test.
  - `get_aim_point()` with a view:
    - over an enemy (picked on screen), that enemy's feet (`global_position`);
    - otherwise the floor under the cursor;
    - the mouse, if the view can't answer (no camera).
  - `_enemy_under_mouse()` with a view: `WorldView.unit_under_cursor()` with Player's filter (targetable enemies). Without one: `_enemy_under_point()` at the aim, which is the mouse.
- **`scripts/view/world_view.gd`** (additive):
  - `floor_under_cursor_px()` / `floor_at_screen_px(screen_pos)`: `pick_floor()` on the walkable ground. Where it misses, `pick_plane()` at the camera focus's height. In sim px; `Vector2.INF` without a camera.
  - `unit_under_cursor(accept)` / `unit_at_screen_point(screen_pos, accept)`: the unit whose view's box on screen holds the point. Overlapping boxes: the nearest box center wins.
  - `static screen_rect_of(camera, root)`: every mesh's bounds under a view's root, at its interpolated transform, projected.
  - `static pick_plane(camera, screen_pos, height_m)`.
  - `setup()` sets `player.world_view`.
- **`scripts/view/room_view.gd`** (additive): the floor mesh joins `walkable`, and a `FloorPick` StaticBody3D holds its trimesh (`backface_collision` on) on 3D layer 1, mask 0. Wall cells have no floor quad.
- **view_test**: 130 checks (21 new).
  - On screen:
    - the plane at the screen's center and top corner, and its round trip;
    - a capsule's box holds its feet and head and is about its width;
    - three real slimes' stand-ins: the body, the nearest box center where boxes overlap, the box farther north, nobody above, the accept filter, no camera.
  - A tile room's floor pick:
    - `walkable`, the body on layer 1 only;
    - a floor cell picked exactly;
    - the inner wall's cell and a point past the room miss the trimesh, and the aim takes the plane there (within 0.5 px);
    - no camera.
- **Measured** in the real 3D sandbox, from a headless scratch harness with saving off. The harness fed mouse motion through `Input.parse_input_event()`: headless, the viewport reads the mouse from Input, while a windowed `warp_mouse()` did nothing without window focus.
  1. The floor aim: 0.9 px from the floor point under the cursor. That's the lean easing over the 4 frames between pointing and reading (MOVEMENT.md's accepted aim drift).
  2. Over Dummy1's body: it's the enemy under the cursor, and the aim is exactly its feet.
  3. Lunge (`cast_ability(&"e")` at the cursor): 128 px, 0.6° off the cursor's direction.
  4. The dash toward the cursor: 128 px, 0.1° off.
  5. Right below the sandbox's north wall (the room's edge), the cursor on the wall: the aim is north of the Knight, and the dash pushes into the wall, 0.00 px south. P3's check had it going the opposite way: the 2D camera stopped at the room's bounds while the 3D camera kept the Knight centered.
- **Tests:** stats 179, combat 460, abilities 563, audio 110, champions 168, talents 308, view 130: **1,918/1,918**, all seven suites in parallel. `settings.cfg` and `progress.cfg` were unchanged by every run (hashed again after Ryan's P4 play, which saved progress at 23:26).
- **Not in P5** (with the switch on): models (the cursor picks the capsules' boxes until P6); the floor drawings, aim indicators and hover ring (P7); the crosshair over an enemy now comes from the on-screen pick, which can't be seen headless (Ryan's check).

### P4 – camera and listener: 2026-10-02, Passed (Ryan's check)
Built from 3D.md, with Ryan's two answers at the start (DECISIONS.md, 3D view): bounds keep the focus on the room's floor, and sounds scale with the view. Played from `scenes/sandbox_main_3d.tscn`.
- **`scripts/camera/game_camera_3d.gd`** (new, `class_name GameCamera3D`, Camera3D):
  - The look from `CameraLook`, placed every frame with physics interpolation off. It follows its target (the player's capsule until P6) through the target's interpolated transform.
  - It reads Main's `GameCamera`, which stays the one place these are tuned and computed: `locked` (Y), `get_current_lead()` (the lean), `offset` (the shake), `edge_pan_speed`, `edge_margin` and the follow smoothing.
  - Locked: the goal is the target plus the lean. Holding C centers with no lean. Unlocked: the arrow keys and the window's edges pan the goal at GameCamera's 420 screen px a second, in real time.
  - The lean: a lean of `lead` screen px puts the target exactly `lead` px off the screen's center, as in 2D. The focus is `target − screen_to_floor(−lead)`.
  - `screen_to_floor(offset_px)`: the floor distance between the points under the screen's center and under the center plus an offset. 80 px sideways is 3.5 m, the same share of the 28 m screen. Up the screen, more floor per px (perspective).
  - Follow smoothing: GameCamera's `position_smoothing_speed` 10 on 60 Hz ticks, turned into the same pace per second (10.94/s), on game time (hitstop freezes it, as Camera2D's physics-tick smoothing does).
  - Shake: GameCamera's `offset` (canvas px) × 0.04375 m per px goes to `h_offset` / `v_offset`.
  - Bounds: `clamp_focus()` keeps the focus inside the room's floor (GameCamera's `bounds` in meters). Near an edge the void past the walls shows.
  - Process priority 10: after GameCamera (0), before WorldView's fade (now 20).
  - An `AudioListener2D` child, made current, placed at the focus in px every frame. While it lives, it sets `Audio.distance_scale` to the view's width over the canvas's (896 / 640 = 1.4), and back to 1 when it leaves.
  - Static helpers for the tests: `meters_per_screen_px()`, `view_distance_scale()`, `clamp_focus()`, `follow_rate_per_second()`; `get_focus()`, `snap_to_target()`.
- **`scripts/autoload/audio.gd`** (additive): `distance_scale` (1.0), `get_listener_position()` reading the current AudioListener2D first, the out-of-range check and each 2D player's `max_distance` × the scale, and `panning_strength` = 1 / the scale. At 1 everything is as before.
- **`scripts/view/world_view.gd`:** P3's stand-in camera is replaced by GameCamera3D, as agreed in P3 (`_place_camera()` is gone). `setup()` takes Main's GameCamera (optional 4th argument) for its lock, lean, shake, pan settings and bounds. `process_priority` is 20.
- **`scripts/main.gd`** (additive): `world_view.setup(self, room, player, camera)`; the export's comment.
- **view_test**: 109 checks (30 new).
  - The camera's priority and interpolation, the follow pace, meters per screen px, the sound scale, the bounds clamp.
  - On a camera following a target:
    - the snap;
    - 80 px = 3.5 m;
    - up the screen is north and covers more floor;
    - 5 offsets project back within 0.05 px;
    - a lean of 80 px right or 48 px down puts the target exactly 80 px left of or 48 px above the center;
    - C centers;
    - the lean stops at the floor's edge;
    - the shake's h/v offsets move the picture as in 2D;
    - the right arrow pans 42 px = 1.84 m in 0.1 s.
  - The listener: current, at the focus; Audio's scale; a sound inside 480 × 1.4 px starts with the scaled reach and panning, one beyond is dropped `out_of_range`; with the camera gone the scale is 1 and there's no listener.
- **Found while building:**
  - The first lean put the target 3 px off vertically at 48 px: moving the focus to the floor point under `center + lead` isn't symmetric up and down the screen in perspective. Fixed by placing the focus so the target lands on `center − lead`, into 3D.md.
  - The shake moves the camera along its tilted up axis, off its usual height, so the floor mapping sets it aside (it was 0.3% off).
  - Headless, the mouse sits in the window's corner, so an arrow-pan check also edge-pans unless the edge margin is off.
  - GameCamera's shake rolls the global random numbers once per rendered frame. A shake then shifts later enemy wander rolls by however many frames were drawn, so a forced shake made the 2D and 3D runs part at frame 228. This happens in the 2D game too; nothing in P4 changed it.
- **Measured** (windowed, from the scratch harness, with saving off and a fixed seed):
  - The P3 walk with no shake: every unit identical in 2D and 3D until the dash (frame 647, the known cursor noise).
  - While playing:
    - the focus sits off the Knight by GameCamera's lean (18 screen px became 25 sim px sideways; up the screen became more);
    - the listener sat exactly on the focus;
    - the sound scale was 1.40;
    - a forced shake showed in the h/v offsets.
  - Screenshots: the Knight off-center by the lean toward the cursor, and the void past the north wall when walking there.
  - Real frame times: median 5.55 ms (180 Hz vsync), 95th percentile 6.33 ms, worst 10.6 ms. Measured as real time between frames: `Performance.TIME_PROCESS`, used in P3's harness, isn't a frame time.
- **Tests:** stats 179, combat 460, abilities 563, audio 110, champions 168, talents 308, view 109: **1,897/1,897**, all seven suites in parallel. `settings.cfg` and `progress.cfg` were unchanged by every run (hashed again after Ryan's P3 play, which saved progress at 23:00).

### P3 – look and light (tile rooms): 2026-10-02, Passed (Ryan's check)
Minimal scaffolding, built from 3D.md, with stand-ins for the camera and the units (Ryan's answer at the start; DECISIONS.md, 3D view). Played from `scenes/sandbox_main_3d.tscn`.
- **`scripts/data/camera_look.gd`** (new, `class_name CameraLook`) and **`data/camera_looks/camera_look_default.tres`**:
  - `projection` (enum `ProjectionMode`: PERSPECTIVE, ORTHOGRAPHIC), `fov_deg` 30, `pitch_deg` 50, `visible_width_m` 28, `fade_to` 0.25, `fade_time` 0.18;
  - `get_distance_m(aspect)`, `get_offset_m(aspect)`, `apply(camera, focus, aspect)`. At 16:9 the camera sits 29.39 m from its focus: 22.51 m up and 18.89 m south.
- **`scripts/view/room_view.gd`** (new, `class_name RoomView`), built from a tile room's Tiles:
  - a floor mesh: a quad per floor cell, in a two-tone checker so movement reads;
  - a 1 × 2.2 × 1 m box per wall cell (a cell whose tile has a collision polygon). Each box is its own `fades` asset; all share one material;
  - a WorldEnvironment (plain background, ambient color) and the key light, a DirectionalLight3D from the north-west with shadows up to 50 m;
  - exports for the colors, the wall height and the light.
- **`scripts/view/fade_dither.gdshader`** (new): a flat color and `instance uniform float fade`. A 4×4 Bayer dither discards fragments, except in the shadow pass.
- **`scripts/view/world_view.gd`** (additive), `setup(main, room, player)`:
  - `hide_sim()`: the room's root and Entities go on visibility layer 2, Main on 1 and 2, and the root viewport's `canvas_cull_mask` drops layer 2. Restored when the WorldView leaves the tree.
  - Builds the RoomView and collects the `fades` assets with their bounds.
  - The fade, in `_process`: an asset fades while the segment from the camera to the player's feet, chest or head (0, 0.9 or 1.8 m up) crosses its bounds. `blocks_view()` and `step_fade()` are static.
  - Stand-ins (throwaway; P4 and P6 replace them):
    - a capsule per Unit: blue and 1.8 m for the player, red and 1.0 m for enemies, as wide as the body's CollisionShape2D circle. Synced on the physics tick at priority 100 and physics-interpolated, snapped after a jump of more than 64 px, added on `node_added`, removed on `tree_exiting`;
    - a Camera3D (physics interpolation off), placed every frame by `CameraLook.apply()` at the player capsule's interpolated feet.
  - `pick_floor()`'s parameter `camera` is now `p_camera`, since the new member `camera` would shadow it. No behavior change.
- **`scripts/main.gd`** (additive): with the switch on, `world_view.setup(self, room, player)`; the export's comment.
- **`scenes/sandbox_main_3d.tscn`** (new): `sandbox_main.tscn` with `use_3d_view = true`.
- **view_test**: 79 checks (51 new).
  - CameraLook: the default numbers, the distance and offset at 16:9, and on a camera in both projections, the focus at the screen's center and 14 m east and west on the screen's edges (within 0.05 px).
  - RoomView on a fixture tile room (6 × 5 cells, offset 2 m east and 1 m south): 19 wall boxes and 11 floor quads; the inner wall's box at (4.5, 1.1, 3.5) m; boxes 1 × 2.2 × 1 m, in `fades`, with the fade shader; the floor's extent, normals and winding (every triangle faces up); the environment; the key light's shadows and direction.
  - The fade: what blocks the view (the two cells south of the player do, the third doesn't, a 6 m pillar there does, walls north or east don't, a beam only the head's line crosses does), and the pace (half the time goes half the way, 0.25 after 0.18 s, back to 1 over the same time, a time of 0 jumps).
  - Hiding: the layers, the mask (only layer 2 dropped) and its restore.
  - The switch: on in `sandbox_main_3d.tscn`.
- **Found while building:**
  - `Projection` can't name an enum in a script: it's a built-in type (the 4×4 matrix). The enum is `CameraLook.ProjectionMode`.
  - A physics-interpolated Camera3D projects (`unproject_position()`, `project_ray_*()`) from its interpolated transform outside the physics tick, so a transform set by code shows up late. The first CameraLook checks were off by up to 3,300 px. A camera moved by code runs with physics interpolation off (the stand-in does, and so will GameCamera3D, as P0a found). Into 3D.md, Engine facts.
  - Mesh normals come back compressed: UP reads (0, 1, −0.000015), so the test compares with a tolerance.
- **Measured** (windowed, from a scratch harness with saving off and a fixed random seed): the same scripted walk in `sandbox_main` and `sandbox_main_3d` (right, up into the north wall, down into an inner wall, a dash, left).
  - Every unit's position was identical, frame for frame, for 644 frames, through both wall contacts.
  - After the dash (frame 642), any two runs differ by up to 0.004 px for a few frames, 2D against 2D too (0.0003 px there). The dash aims at the real cursor (dash direction CURSOR), not through the view. Enemy wandering uses the global random numbers, hence the fixed seed.
  - Screenshots: the lit room, the walls' shadows, the capsules, the HUD on top, no 2D world. At an inner wall, the cell between the camera and the Knight is dithered away.
  - About 178 frames a second on Ryan's 180 Hz screen (vsync).
  - At the default look, a 2.2 m wall hides the player when it stands within about 2 m south of them.
- **Tests:** stats 179, combat 460, abilities 563, audio 110, champions 168, talents 308, view 79: **1,867/1,867**, all seven suites in parallel. `settings.cfg` and `progress.cfg` were unchanged, hashed before and after every run.
- **Ryan's check (2026-10-02): passed.** He noticed that a dash or Lunge aimed toward a wall can go the opposite way. That's the aim gap below:
  - The aim still reads the mouse through the 2D camera, and that camera stops at the room's bounds near an edge.
  - The 3D stand-in camera keeps the Knight centered.
  - So near an edge, the screen point Ryan aims at lies on the other side of the Knight in 2D.
  - P5 fixes it with the floor pick, and its check includes aiming next to the room's edge.
- **Not in P3** (with the switch on):
  - aiming: the mouse still aims through the 2D camera (P5);
  - the camera's lean, lock, pan, shake and bounds, and the listener (P4);
  - models, facing, hit flash, death, projectiles, auras, status VFX and the VECTOR test wall (P6);
  - floor drawings, damage numbers and health bars (P7).

### P2 – scaffolding: 2026-10-02, Passed (Ryan's check)
No visible change. Built from 3D.md.
- **`scripts/core/units.gd`** (additive): `PX_PER_METER` (32.0), `px_to_m()`, `m_to_px()`, `to_view(p, height_m)` (sim x → view x, sim y → view z) and `to_sim(p)` (the height dropped).
- **`scripts/view/world_view.gd`** (new, `class_name WorldView`, Node3D):
  - empty, with `process_physics_priority` 100;
  - constants `FLOOR_LAYER` (3D physics layer 1) and `SECOND_RAY_OFFSET` (0.013, 0.007);
  - the floor pick: `static func pick_floor(camera, screen_pos, mask)`, two rays with the nearer hit winning, `Vector3.INF` on a miss.
- **`scripts/main.gd`** (additive): `@export var use_3d_view: bool = false`, plus `world_view`. With the switch on, `_ready()` adds a `WorldView`, still empty, as Main's child.
- **`view_test`** (new, `scenes/tests/view_test.tscn`, `scripts/tests/view_test.gd`): 28 checks.
  - The mapping: the scale, both directions, round trips.
  - `WorldView`'s priority.
  - The switch: off by default, and neither `main.tscn` nor `sandbox_main.tscn` turns it on.
  - The floor pick on a fixed camera at the default look (perspective, 30°, 50°, 28 m), over a 24 × 18 m floor of 1 m quads with a 3 × 3 m plateau 1.5 m tall:
    - the screen center lands on the focus;
    - 12 flat points project back within 0.05 px (worst 0.0148);
    - 3 points on the plateau top pick the top;
    - 13 exact shared vertices inside a surface are exact (a single ray: 3 wrong);
    - 7 vertices on the plateau's outline land on the top or the floor right behind it;
    - a box on layer 2 is ignored;
    - misses return `Vector3.INF`;
    - sim px → view → screen → pick → sim px within 0.1 px.
- **Found while building:** the first run checked all 20 exact vertices for an exact hit and got 16. The 4 misses were on the plateau's east edge, its outline from this camera: both rays grazed past it to the floor right behind. That's a point between two surfaces, not P0a's slip-through. The check was split, and the rule went into 3D.md (The floor pick and aim).
- **Tests:** stats 179, combat 460, abilities 563, audio 110, champions 168, talents 308, view 28: **1,816/1,816**, all seven suites in parallel. `settings.cfg` and `progress.cfg` were unchanged by the test runs.
- **Smoke runs** of `sandbox_main.tscn` headless for 300 frames: no errors with the switch off, and none with it on (set temporarily in the scene, then restored byte for byte). Both save files were backed up first and compared after: unchanged.
- **Folders:** `scripts/view/` exists now. `scenes/view/`, `art/models/placeholder/` and `data/camera_looks/` come with their first files (P3, P6, P4), since git can't hold an empty folder.

### P1 – decisions and docs: 2026-10-02, 3D.md approved; doc edits awaiting Ryan's review
Docs only; no code or tests changed.
- **`docs/3D.md` written:** the lasting spec. Ryan approved it the same day with additions:
  - the placeholder KayKit Knight in `art/models/placeholder/` with a `CREDITS.md` entry;
  - `room_01` rebuilt as a layout, the last item of P8;
  - the room tools: footprints drawn in the editor, a load-time validator with a test, `SimMarker` previews, drawn footprints for concave assets, a whole-meter kit with a 1 m snap;
  - `FloorOverlay` as a window around the camera: 2624 × 1664 texels at the default look, 16.7 MB;
  - P3 kept minimal.
- **Ryan's P1 decision:** rooms are built in 3D (Q7 changed). That added **P8 Rooms built in 3D**, and the plan's P8 became **P9**.
- **`docs/DECISIONS.md`, 3D view:** the rows the plan saved for P1 (the givens, A1, the scale, the approved mouse replace, ledge layer 11, Judgement not `melee`, no enemy knock-ups on the player, the interview, the order of work), plus 3D rooms, 3D.md as the spec, and the approval additions.
- **Doc edits applied:**
  - CLAUDE.md: the game, tech facts, planned folders, architecture, docs index, Future docs notes for ENEMIES_AI, DUNGEONS and UI;
  - CONVENTIONS.md: `_m` / `_deg`, the vocabulary, the `melee` tag, status tags, reserved names, `view_test`;
  - VISION.md: height in the cross-cutting section;
  - MOVEMENT.md: smooth turning, slopes, the 3D aim, cliffs stop the dash, the 3D camera, 180 Hz, the vertical-speed question answered;
  - COMBAT.md: the `melee` tag and elevated targets, airborne, tenacity's exception, the 3D numbers, telegraphs, flash and shake, the new StatusEffect fields;
  - WORLD_INTERACTION.md: layouts, layer 11, the dash mask, surface tags on footprints, pits in layouts, knock-ups, the "while inside" hazard option, 3/4 depth superseded, a Terrain section;
  - AUDIO.md: the listener and the distances to re-measure;
  - ABILITIES.md: `melee`, knock-ups, projectiles in 3D, indicators, aim, presentation hooks;
  - CHAMPIONS.md: `model_scene`;
  - LOOT.md: pickups' views;
  - `_TEMPLATE.md`: a View section;
  - PROMPTS.md: the 3D question in "Design a new system";
  - 3D_PIVOT.md: status, Q7, the doc-edits note.

### P0b – feel spike: 2026-10-02, Passed (Ryan's answers)
Throwaway spike on branch `spike/3d-p0b` (8386604), fresh from `main`, never merged, built in one session of its two; no code from P0a. `scenes/spike/p0b_spike.tscn` runs the real `sandbox_main.tscn` as the hidden 2D sim and builds a 3D view over it:
- **The room**, from its tiles: a flagstone floor that darkens where it meets a wall; walls at the cutaway height.
- **Three tall things** standing on existing wall cells, so the sim is untouched: a 3.9 m pillar at cell (9, 6), a 2 m plateau at x 19–20, y 7–9 (not walkable), and a timber-framed house at x 22–24, y 7–9 (gable roof, door, lit window).
- **Lights:** four braziers with flickering point lights and shadows, and a key light from the north-west.
- **Unit views** synced on the physics tick (priority 100):
  - KayKit's Knight (CC0, approved and downloaded 2026-10-02, `art/models/kaykit_knight/`). It runs, idles, swings (each combo swing's strike timed to land on the hit), casts (Cleave, Lunge, Judgement, Iron Resolve), dodges on the dash, dies and flashes when hit, all from the existing signals.
  - Procedural slimes with squash and stretch.
  - Projectiles as glowing spheres.
- **Floor drawings** through the shared-World2D SubViewport: the slam telegraph, swing arcs and the ability indicator (the Player node on the sim layer).
- **Overlays and camera:** enemy health bars, damage numbers and a hover ring. The camera follows the Knight's interpolated position plus `GameCamera`'s screen-space lean; Y lock, C center, edge pan and shake carry over.
- **One branch-only change:** `player.gd` routes its 11 mouse reads through a hook, as in P0a.

Toggles (a panel; Backspace keeps them):

| Key | Toggle |
|---|---|
| 5 | projection |
| N | field of view (20, 30 or 40°) |
| 6 | pitch (50, 60 or 70°) |
| 7 | visible width (20, 24 or 28 m) |
| 8 | walls (0.6, 1.2 or 2.4 m) |
| 9 | tall things: solid, fade (dithered) or a cut-out circle |
| 0 | smooth vs 8-direction turning |
| M | material: a light-ramp "painted" shader vs fully lit PBR, both procedural with no texture files |
| L | torches |
| B | Knight height (1.4, 1.8 or 2.2 m) |

`--p0b-shots=<dir>` saves 24 screenshots of the looks and measures each.

1. **Frame time,** vsync off, 1280×720 window, every look: median 1.8–2.9 ms, p99 at most 4.8 ms, GPU 0.3–0.85 ms. The painted material took about 0.4 ms of GPU time and PBR 0.6–0.8 ms. Everything is under the 5.6 ms budget at 180 Hz.
2. **Above the horizon at 50°** (P0a's open question): it doesn't happen. With a 30° field of view the screen's top edge still looks 35° down (30° with 40°), so the plain floor pick never misses.
3. **Found while building:**
   - `unproject_position()` works in the 640×360 canvas space under `canvas_items` stretch, the same space as the mouse and CanvasLayers.
   - A dithered fade, skipped in the shadow pass, keeps a faded thing opaque and its shadow whole.
   - The glTF Knight faces +Z, and its looping clips need `loop_mode` set.
   - `Input.action_press()` sends no input event, so scripted ability presses need `Input.parse_input_event()`.
4. **A bug Ryan hit in play,** fixed the same day: after an enemy died, the game stopped with "Trying to assign invalid previously freed instance" in `_aim_point`. A view outlives its unit by its death animation, and the view list's entry was copied into a typed variable before the validity check. A shot that kills every enemy and runs 3 s reproduces it with the old line and runs clean with the fix.
5. **A side effect on Ryan's save:** the first screenshot runs played the real sandbox, and `Progress` saved `user://progress.cfg` when they quit. The only possible change is one Cleave use from a scripted Q press (most likely 204 → 205). The harness now sets `Progress.saving_enabled = false`; a run with a scripted Q cast left the file byte-identical.

Tests on the spike branch: stats 179, combat 460, abilities 563, audio 110, champions 168, talents 308: 1,788/1,788 (the baseline). The real `settings.cfg` was unchanged.

**Ryan's answers (2026-10-02):**
- perspective with a 30° field of view, 50° pitch, 28 m wide;
- tall things fade; smooth turning; the Knight 1.8 m tall;
- walls are 3D assets of variable height, some fading, 2.2 m for now (a conflict with Q7, for P1);
- material: PBR looked better to him, but it's left open until the art pass with real textures, and Q4 stands.

### P0a – go/no-go spike: 2026-10-01, Passed (GO)
Throwaway spike on branch `spike/3d-p0a` (61e5637), never merged, built in one session of its two. `scenes/spike/p0a_spike.tscn` runs the real `sandbox_main.tscn` as the hidden 2D sim and builds a 3D view over it: the room raised from its tiles (walls cut to 1.2 m), a terrain patch (a 1.5 m plateau at cells x 5–8, y 10–12; a ramp from the west; 6 stairs from the south; 19 ledge colliders on layer 11 derived from height steps over 0.3 m; a fence on layer 7), a capsule per unit synced on the physics tick (`process_physics_priority` 100), a Camera3D at 60° pitch and about 23 m wide (perspective, 30° field of view, or orthographic), the floor pick driving the Knight's aim, and the sim's floor drawings through a SubViewport sharing the root's World2D. Two throwaway changes on the branch only: the ghosted dash masks walls and ledges (`& (1 | 1024)`), and `player.gd` routes its 11 mouse reads through a hook. Measured headless and in a window on Ryan's PC (Godot 4.7.2, Forward+, D3D12, RTX 4070 SUPER; **the screen refreshes at 180 Hz**, not 144).

1. **A hidden CharacterBody2D still collides:** 150 frames sliding along the long wall give identical positions, frame for frame (0.000000 px), with the room visible, hidden by canvas layer, and `visible = false`. A first run from a different state differed by 1.7 px; a warm-up run fixes the comparison.
2. **Smoothness at 180 Hz, vsync on:** walking the long wall, a dash, a 0.06 s hitstop: the Knight's view moves 0.93–1.01× the median speed per frame (by the engine's frame delta; 3.71 m/s along the wall), never steps back, and the fastest frame around the hitstop is 1.15–1.18× (a pop would be over 1.5×). A slime teleported 256 px showed no in-between frame (the 64 px snap). Frame time median 5.6 ms, p99 6.5–8.1 ms.
3. **Floor pick** (markers projected to the screen center and four corners, picked back, compared in sim px): a trimesh of the floor mesh is exact (at most 0.04 px) on flat floor, the ramp, mid-step and at a step's edge, the plateau, and at cliff bases; the 1 m `HeightMapShape3D` is off by up to 3.7 px at a step's edge and 12–30 px at cliff bases. Markers behind the plateau are hidden by it (expected). Rays through exact tile corners: one ray went wrong or missed 6–12 times in 20 per projection (it slipped through the plateau top and hit the cliff behind); two rays a hair apart, nearer wins: 0. One window pixel covers 0.66–1.02 sim px at this view. Headless runs use a 640×640 viewport (a 1280×1280 window), not 16:9; the windowed run repeats the check at 16:9 with the same results.
4. **Telegraph vs hit on a slope** (the slam's 72 px circle on the ramp, rendered with and without, the outline's center found along 32 rays; 2 rays hidden behind the plateau): the terrain shader median 0.4–0.8, max 1.7–2.1 window px (2× overlay: max 1.65); a mesh ring following the heights, exact by construction, median 0.8–0.9, max 2.1 (so the residual is the measurement's resolution: 1 sim px = 1.7 window px); a flat quad median 11–12, max 13.5, outline found on only half the rays. The shared-World2D SubViewport draws the telegraph (edge texel alpha 0.91) and the terrain shader updates live. **A Decal refuses a ViewportTexture** ("cannot be used as a Decal texture", use `get_image()`); copying the 960×640 overlay each frame costs 3.2 ms median on the CPU. Found while building: the overlay was empty until the room's parent (`Main`) shared the overlay's canvas layer; setting a SubViewport's `canvas_transform` before it enters the tree errors (`canvas_map.has`).
5. **Frame time, vsync off** (p99): with the 3D view, base 2.5–2.7 ms, +30 slimes 6.6–7.2 ms, +50 slimes 12.9–15.6 ms (physics step 10–13 ms; GPU 0.3–0.6 ms). Today's 2D game alone: 2.2, 5.7, 13.4 ms (physics step 12.2 ms at +50). The view adds 0.2–0.9 ms a frame; the 50-enemy cost is the 2D enemy sim's (steering and pathing), over the 5.6 ms budget at 180 Hz with or without 3D.
6. **Terrain proof:** walking and the dash stop at the plateau's north cliff (y 307, cliff at 320); walking stops at the fence (y 450) and the dash crosses it (y 501); the ramp and the stairs lead onto the plateau with the model height rising at most 0.047 m a tick; `shape_sweep` and `has_line_of_sight` cross the ledge; the Bolt test ability flies across it (to y 506); the path from below the north cliff to the plateau top goes around by the ramp (317 px vs 64 straight).

Tests on the spike branch: stats 179, combat 460, abilities 563, audio 110, champions 168, talents 308: 1,788/1,788 (the baseline); the real `settings.cfg` unchanged. Ryan's eye check (walking, dashing, hitstops, the ramp, stairs, cliff and fence, P / O / T toggles): passed, GO (2026-10-01).

### Before P0 – test isolation: 2026-10-01, Passed
`Settings` got the same test-scene guard as `Progress` (T4): `TEST_SCENES_DIR`, `saving_enabled`, `save_path`, `is_test_scene()`, and a private `_ensure_loaded()` that every getter and setter calls. The file is read at the first query or change made while a scene is current. With no current scene it doesn't decide or latch: the defaults answer, nothing is read or saved, and it warns once. `_ready()` no longer loads the file (approved replace). `load_settings()` and `save_settings()` use `save_path` and do nothing while saving is off; saving also waits for the first read.

**Measured first** (a scratch project, Godot 4.7.2): `get_tree().current_scene` is already set when the autoloads run `_ready()`, both for the main scene and for a scene passed on the command line (how the tests run); a deferred call from an autoload's `_ready()` runs on frame 0. The only Settings read during an autoload's `_ready()` is `Audio._ready()` → `_apply_bus_volumes()` → `Settings.get_volume()` (6 buses); its `Settings.VOLUME_BUSES` is a const and `setting_changed.connect()` reads nothing, and no other autoload references Settings. So Audio's first read already tells a test run apart, and the planned `_apply_bus_volumes.call_deferred()` replace was **not made** (its premise was wrong; Ryan: skip it, 2026-10-01). The no-scene warning never fired in any run below.

Tests: abilities AB1 starts from a known cast mode and checks the save format on `user://abilities_test_settings.cfg`; audio's volume section uses `user://audio_test_settings.cfg`; both delete the scratch file. New checks: saving is off in a test scene (abilities, audio), the suite started at the defaults rather than the saved file, `save_settings()` with saving off writes nothing, the real path stays `user://settings.cfg`. Combat C12 reads the heavy hitstop as the swing lands (±0.005), like C3. C3's "longest wins" samples real time every frame instead of two fixed 0.05 s waits: the time left at ≥0.04 s follows 0.08 − elapsed (±0.005), it ends no earlier than 0.075 s, and within 3 frames of 0.08 s (measured in four runs: ended 0.087–0.093 s, longest frame 0.007 s).

Results: stats 179/179, combat 460/460 (one more check), abilities 563/563 (four more), audio 110/110 (one more), champions 168/168, talents 308/308: **1,788/1,788** (the 1,782 + 6 new). The real `user://settings.cfg` (md5 `73a6d96e…`) was unchanged after every run. With the real file's `cast_mode` flipped to `quick` (backed up first, restored after, md5 checked): abilities 563/563 again, and the run didn't touch the file. Combat 5 runs in a row: 460/460 each. All six suites in parallel: all green. `hub.tscn`, `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors or warnings. The test logs' ERROR/WARNING lines are the same as before (the stats test's own typo checks and the like).

Play test passed (Ryan, 2026-10-01): F5, the pause menu shows the saved cast mode and volumes; a change survives a restart.

## Abilities (ABILITIES.md)

### Roots are roots: 2026-10-04, Passed (Ryan's play test, reported starting ENEMIES_AI AI2)
Ryan's answer at LOOT L-M to AB15's question (should a root also block dashes): "roots are roots. You shouldn't be able to move at all until it ends." He also kept Homeward Lunge's 0.05 s cast time (no per-part cast time).
- **Code:**
  - `Ability.MOVEMENT_TAGS` (`dash`, `leap`, `blink`) and `moves_caster()`.
  - `AbilityComponent`: `conditions_pass()` fails such an ability while its caster is rooted or stunned (`Unit.is_dash_blocked()`), the AB12 way: at once, with its cue, not buffered, the slot greyed. `get_condition_fail_text()` gives `ROOTED_FAIL_TEXT` ("Rooted").
  - `MovementComponent.is_dash_blocked()` (`is_blink_blocked()` now returns it); `dash()` and `leap()` refuse while it's true, as `blink()` already did, and a refused leap returns where the unit stands.
  - `AutoAttackComponent`: a swing's step is skipped while rooted.
- **Measured** (abilities test, a test root with `blocks_move` and `blocks_dash`; the game has no root status of its own yet):
  - **Refused:** Lunge, Triple Step and Judgement Leap failed with `FAIL_CONDITION` ("Rooted") and no cooldown; Cleave still cast.
  - **No movement:** `dash()` and `leap()` moved nothing, and the leap returned his spot. A free Lunge went nowhere. A swing stayed put (unrooted, the same swing steps 6 px).
  - **Not stopped:** a knockback still moved him 60 px, and a dash already running when the root landed finished its 120 px.
  - **Edge case:** rooted during Judgement Leap's crouch, he landed where he stood.
  - The root gone, Lunge cast again.
- **Sensitivity:** each check was broken on purpose once and restored, and each failed: the press check, `dash()`'s refusal, `leap()`'s refusal, the swing step.
- **Tests:** abilities 593/593 (13 new); the rest as in LOOT L-M's entry above: 3,041/3,041.

### AB15 – Blinks: 2026-10-04, Passed (Ryan committed it and started LOOT L7)
Ryan asked for blinks (2026-10-04), and started AB15 with the spec's proposals as written.
- **Code:**
  - **`MovementComponent`:**
    - `blink(to_px, through_walls := true) -> bool` and the signal `blinked(from, to)`.
    - `get_blink_landing()`: over walls, the leap's rule; stopping at walls, the aim cut at the first wall by a 2 px core sweep (`BLINK_WALL_CORE_PX`), then the same rule, kept in sight of the start.
    - `is_blink_blocked()`: a root or a stun, read from the StatusComponent as `Unit.is_dash_blocked()` does.
    - A blink ends the unit's running displacement and emits `displacement_finished`, so a dash ends through DashComponent as usual. It re-paths a move order and resets the body's physics interpolation. It's refused during a leap or a knock-up (`is_airborne()`) and while blocked.
  - **`lunge.gd`:** part 1 is `movement.blink(start)`. `can_cast_custom()` refuses part 1 while the Knight can't blink, with the fail text "Rooted".
  - **`knight_e_lunge_return.tres`:** the tag `blink` and the new text. `augment_lunge_return.tres`: the new text.
  - **The test blinks:** `scripts/abilities/test/blink.gd` (`through_walls`, the root check, an indicator at the real landing), `test_q_blink.tres` and `test_q_blink_sight.tres`.
  - **`SandboxAbilities`:** B / Shift+B cast them for free toward the cursor, through `blink_toward_aim()`. Its exports `test_blink` and `test_blink_sight` default to the two files, so neither sandbox scene changed.
  - **`UnitView`:**
    - `blink_afterimage_fade` (0.25 s) and `blink_flash_color` (white).
    - On `blinked`: an afterimage where the model is drawn (the start), then at the next sync `reset_physics_interpolation()`, the ground height snapped, and the flash in `blink_flash_color`. A hit's flash sets `flash_color` back.
- **Changed during the step:**
  - **An L6 slip fixed.** L6 made `knight_e_lunge_return.tres` from Lunge's file with a sed that replaced every `description` line, the Stagger bonus's included. Homeward Lunge's tooltip showed its whole description again where "Staggers enemies hit for 2s." belongs. Restored; loot_test now checks the line matches Lunge's.
  - **A blink ends a dash with `displacement_finished`.** `stop_displacement()` doesn't emit it, and DashComponent ends the dash only on it, so a blink mid-dash would have left the dash running forever. Checked: with the emit removed, the abilities test's mid-dash check fails.
  - **The view needs its own snap.** WorldView's 64 px teleport snap misses a short blink.
    - Measured from a node's `_process` in the real 3D sandbox: without UnitView's reset, a 0.7 m blink was drawn sliding over one tick (x 4.58, 4.87, 5.16 m), and with it, it snapped.
    - A test coroutine's `get_global_transform_interpolated()` returns the plain transform, so view_test reads the drawn position through a watcher node's `_process`. The check fails with the reset removed.
  - **The cast-level root check matters.** With it removed, the rooted recast was accepted, the blink refused, and the return was spent with the Knight still out (three loot_test checks fail).
- **Measured:**
  - **The primitive:** at the aim on open floor in the same tick (no frame waited); `blinked` once.
    - No status, no i-frames.
    - Over a wall 8 px thick, exact. Stopping at it, x 34.75 px for a wall face at 46 px (the body clear). Still across a fence, a ledge and a pit, exact.
    - Mid-dash, the dash ended and the mask came back. After a knockback, it stayed put.
    - Refused mid-leap (the leap still landed), knocked up, and rooted.
  - **The test blink on Q:** at the aim clamped to 128 px, at once, with its 1 s cooldown. Rooted, the press failed with `"condition"`, no move and no cooldown. B and Shift+B through the viewport cast the two test blinks for free, landing where `get_blink_landing()` said; rooted, B did nothing.
  - **Homeward Lunge:**
    - Over a wall between the Knight and his start, he's back at the start by the cast's 3 frames, never in between, with one blink.
    - Rooted, the recast failed and the window kept running; after the root, the recast worked inside it.
    - The L6 return checks (Tackle, Twin Lunge, Long Lunge, Quick Footing, after a push, the cooldown) pass unchanged.
  - **On terrain** (view test):
    - Onto the plateau, off it, and over the thin wall: exact.
    - Stopping at walls: on the thin wall's near side (5.54 m for its face at 6.0 m), still up the cliff and over the fence.
  - **In the view:**
    - The afterimage at once at the start, (1.0, 3.5) m.
    - The next tick the view stood on the plateau's top at 1.5 m (no rise). It flashed in `blink_flash_color`; the afterimage was gone in 0.25 s, and a later hit flashed in `flash_color`.
    - A short 0.7 m blink was never drawn between its ends.
    - The Knight's blink showed one of his model's pooled afterimages.
  - **The probe** (`sandbox_main_layout`, the real Player, the view and the camera; saving off):
    - The return moved the drawn Knight from x 11.0 to 8.0 m with no frame between, 3 ticks after the press (Lunge's 0.05 s cast time).
    - The camera glided after it over about 10 ticks (8.68 → 6.28 m).
    - B blinked 4 m toward the cursor, the same way.
- **Smoke run** (`sandbox_main`, `sandbox_main_layout`, `main_layout`, 600 frames each; the saves backed up first, new since Ryan's L6 play test at 01:06): no errors or warnings; all three saves byte-identical after.
- **Tests:** abilities 580/580 (23 new), view 442/442 (14 new), loot 627/627 (5 new; three L6 checks reworded for the blink). Stats 179/179, combat 474/474, audio 110/110, champions 168/168, talents 310/310: 2,890/2,890.

### AB14b – the old timer's extra tick removed: 2026-09-29, Passed
`AbilityComponent.CAST_TIME_EPSILON` (0.0001 s): the cast-time countdown is done at `_cast_time_left <= CAST_TIME_EPSILON` instead of `<= 0`, the rule the swings already use (`SWING_TIME_EPSILON`). A cast time that is an exact number of ticks now takes exactly that many.

Measured (abilities test, 60 Hz): Cleave 0.2 s and the test vector line: 12 ticks (was 13); Lunge 0.05 s: 3 (was 4); Judgement's channel 1.5 s: 90 (was 91); the test Charged Line 0.3 s: 18 (was 19); the test Mark Strike's recast 0.1 s: 6 (was 7); Iron Resolve (no cast time): the same frame; the elite's slam 0.65 s and the test vector wall 0.7 s: 39 and 42, unchanged (they were already on time). Which frame a cast counts from (at a frame's start, in the node pass, between frames, at another cast's end) is unchanged. The test now computes each tick count as the nominal count rounded up, independently of the component, and pins the table above in one check.

Abilities 558/558 (one new check), champions 45/45, stats 179/179, audio 109/109. Combat 457/459: the same two real-time hitstop checks as in CH1 (they fail on the commit before CH1 too). `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors.

### Cleanup – the old cast timer deleted: 2026-09-29, Built (awaiting play test)
AB14 passed Ryan's play test, so the old `create_timer()` wait is deleted as approved: `AbilityComponent.use_cast_progress` and its branches in `_do_cast()`, `_physics_process()` and `_start_cast_anim()` (the old path stretched a `cast_anim` over `cast_time`). The regression checks compared the flag off vs on; with no old path left they now check each cast's effect frame against the old timer's arithmetic, computed from the ability's `cast_time` (`_ab14_timer_ticks()`: 0.2 s = 13 ticks, the effect 12 frames after a cast at a frame's start or in the node pass, 13 after one between frames; 0 s the same frame), so a tuning change never breaks them (DECISIONS, Testing). Three checks that only covered the old path are removed (the flag's default, the old path's telegraph clock and its stretched animation).

Also checked while here (Ryan's question from the play test, items 1 and 4 on, Q): with both paths, before the deletion, the order is identical frame for frame: at Cleave's effect start the free Lunge fires (ABILITY_CAST) and starts its dash, Cleave hits the same frame at the Knight's starting spot, Cleave's hitstop holds the dash's first frames, and the free Lunge hits (and stuns) at the end of its dash, 20 frames later. Nothing since AB-M changed that path (the audit pass only made Lunge's afterimages visible).

Abilities test 557/557, combat 459/459, stats 179/179, audio 109/109. `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors or warnings.

### AB14 – Cast progress and presentation hooks: 2026-09-29, Passed
**Measured first** (a scratch SceneTree probe, Godot 4.7.2, 60 Hz): a SceneTreeTimer created in a node's `_physics_process()` is counted that same frame (the timers run after the nodes), and a deferred call queued from `_physics_process()` runs after every node that frame and before the timers. The timer fires one tick late whenever the cast time is an exact number of ticks (float residue): 0.05 s = 4 ticks, 0.1 = 7, 0.2 = 13, 0.3 = 19, 1.5 = 91; 0.65 = 39 and 0.7 = 42 are on time. So the spec's epsilon would have moved those casts one tick earlier; the build keeps the timer's arithmetic instead (DECISIONS.md, Abilities).

**Built:**
- `AbilityComponent`: `use_cast_progress` (export, on); `_advance_cast_time()` deferred from `_physics_process()` each tick (seconds left − delta × `get_cast_speed()`, progress = 1 − left ÷ `cast_time`, the telegraph and `cast_anim` updated, `_cast_time_elapsed` at 0); `_do_cast()` awaits `_cast_time_elapsed` instead of `create_timer()` (the old wait stays behind the flag); `_stop_cast_time()` in `_cancel_cast()` and `interrupt_cast()` right after the serial bump; `get_cast_speed()` (1.0), `get_cast_progress()`; `_start_cast_anim()` / `_update_cast_anim()` / `_finish_cast_anim()` / `_stop_cast_anim()` (`Body/AnimationPlayer`, position = progress × length); `cast_vfx` at cast start and for free casts.
- `CastContext.progress`. `Ability`: export group "Presentation" (`cast_vfx`, `impact_vfx`, `cast_anim`), `play_cast_vfx()`, `play_impact_vfx()` (in `hit_units()`; `Projectile._hit()` too). `VFX.spawn_scene()` (the one spawn helper for hook scenes).
- `Telegraph.set_progress()`, `is_driven()`; a driven telegraph ignores its clock and draws interpolated between ticks.
- `AttackSwing`: export group "Presentation" (`swing_vfx`, `impact_vfx`, `swing_anim`). `AutoAttackComponent`: `get_swing_progress()`, the swing's VFX at swing start and on each hit that got through, `swing_anim` positioned by swing progress, stopped by `cancel_swing()`, on its last frame when the swing finishes.
- Test-only: `scripts/tests/hook_vfx_probe.gd` (packed into a PackedScene by the test).

**Found while building:** Godot's AnimationPlayer treats an animation seeked to its very end as finished and clears `current_animation` (the old timer's extra tick puts progress at 0.99999999), so the hooks track `assigned_animation`. The regression check first flipped between 90 and 91 frames for Judgement: a hitstop left from the previous cast (real time) slowed the next measurement; the test now waits out hitstop before each measurement.

Abilities test 560/560 (57 new AB14 checks): the regression check (the effect frame with the flag off vs on: Cleave 12 / 12 / 13 frames after a cast at a frame's start / in the node pass / between frames; Lunge 3; Iron Resolve 0; Judgement 90 / 90; the Charged Line's release windup 18; the vector line's 12; Mark Strike's recast part 6; the elite's slam 38 / 38 / 39; the vector wall 41; Lunge chained from Cleave's `cast_finished` 4), progress (0 at start, 0.5 at 45 of 90 ticks, 1 at the effect, 1 for no cast time and free casts, none while holding a charge-up, 0.5 halfway through a release windup), telegraphs (driven from the start, equal to the cast's progress, exactly full at the hit for the slam and the vector wall, not driven on the old path or without a cast), hooks empty (no data fills one; the calls return nothing), hooks filled (cast_vfx before `cast_started` at the caster's feet turned to the aim; one impact per enemy hit, none for a blocked hit; a free cast; a projectile hit; a swing and its hit), animations (position = progress × length every tick for a cast and a swing, the last frame at the effect / the swing's end, stopped by a stun or a cancelled swing, speed 1.0 with no cast time, speed 5 on the old path). Full suite: stats 179/179, combat 459/459, abilities 560/560, audio 109/109. `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors or warnings.

### Cleanup pass (audit fixes): 2026-09-29, Built (awaiting play test)
A read-only audit's fixes, in one pass across the systems (the other parts are in the Combat, Movement, Stats and Audio sections under the same date). The Abilities part:
- **The enemy AI skips a slot that can't be cast.** `Enemy._try_cast_ability()` asked `can_cast()`, which ignores conditions, so a slot failing its condition went to `try_cast()`, failed with "condition", and the AI returned: every later slot was blocked and `cast_failed` was emitted every frame. It now skips any slot whose `get_fail_reason()` isn't empty (for a VECTOR ability, at its `get_ai_vector()` start) and tries the next one. `can_cast()` is unchanged (the input buffer uses it; its comment now says it ignores cost and conditions).
- **`get_effect_param()` migration** (CONVENTIONS pattern 6): the projectile params (`Projectile.fire()`), `vector_length` and every `cast_range` read in AbilityComponent (`_fill_vector()`, `try_cast_vector()`, the condition target, `_fill_inputs()`, the UNIT range check, the walk-into-range check, the VECTOR start clamp and the POINT clamp, which now comes after the condition target and inputs so a bonus for the target counts), `hit_knockback_px` (per unit, in `hit_units()`) and Lunge's `flag_stun_duration`.
- **Dead code deleted** (approved; references checked first): `AbilityComponent.get_charge_hold_time()`, Judgement's `get_missing_health_bonus()` wrapper (its test check now reads the term), `DamageScaling.is_target_term()`, unused `ext_resource` lines in 7 ability .tres files (`knight_r_judgement`, `test_q_bolt`, `test_q_charged_line`, `test_q_mark_strike`, `test_q_nova`, `test_q_vector_line`, `test_w_vector_wall`; 21 lines, all script types no field used).
- **Iron Resolve's aura and Lunge's afterimages drew under the floor.** Both used `z_index = -1`, which puts them under the room's TileMapLayer. Lunge's was a known issue that had never been fixed (CLAUDE.md, Known issues). The aura is now the unit's first child at the default z (drawn over the floor, under the Body); `VFX.afterimage()` now sorts just above the unit's feet like the F3 afterimages (`AFTERIMAGE_SORT_OFFSET`, a holder node). Checked in rendered frames (Xvfb + OpenGL, the sandbox): before the fix neither shows, after it the gold ring sits under the Knight and the blue afterimages trail Lunge.
- New `AbilityComponent.get_all_abilities()`, `Ability.has_param()` and static `Ability.is_base_param()` (for the Stats key check).

Abilities test 503/503 (9 new): the elite with a condition-failing Q and a working W casts W with no `cast_failed` (and none after); a conditional bonus (Focus) that makes the vector line 240 px long and 48 px wide: without Focus a dummy 36 px beside the line and one 220 px along it are both missed on a 160 px line, with Focus both are hit. 2 changed checks: Judgement's (the deleted wrapper replaced by the term itself) and the empowered-swing check (no `highlight` any more). Full suite: stats 179/179, combat 459/459, abilities 503/503, audio 109/109 (was 172 / 451 / 494 / 109 before the pass). `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors or warnings.

### Cleanup – Cleave's old knockback export: 2026-09-28, Built (awaiting play test)
AB-M passed, so the unused `knockback` export (170 px/s, disabled since AB11: the push is `hit_knockback_px` 17 over 0.1 s in `knight_q_cleave.tres`) is deleted from `knight/cleave.gd`, with its comment. Nothing read it: no script, .tres or scene sets or reads Cleave's `knockback` (the other `knockback` fields are `Hitbox.knockback` and `hit_knockback_*`).

Abilities test 494/494, stats 172/172, audio 109/109. Combat 450/451 twice: the known flaky real-time "heavy feel: 0.06 s hitstop" check (got 0.039); the committed code without this change passed it once and failed it once the same way. `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors or warnings.

### AB-M – The augment playground: 2026-09-28, Passed
**Milestone AB-M.** Four fake items on the real Knight through the AB8 augment machinery, toggled in the sandbox with keys 1–4.

New: `scripts/abilities/knight/cleave_wave.gd` + `data/abilities/knight_q_cleave_wave.tres` (Cleave as a projectile wave; `variant_of` `knight_cleave`; a crescent drawn on the projectile), `data/augments/` with `augment_lunge_stuns.tres` (FLAG), `augment_cleave_wave.tres` (REPLACE), `augment_judgement_reset.tres` (EVENT: UNIT_DIED → ModifyCooldown RESET), `augment_cleave_casts_lunge.tres` (EVENT: ABILITY_CAST → CastAbility with Lunge), `scripts/rooms/sandbox_augments.gd` (`items`, `show_list`, `toggle()`, `is_equipped()`, `get_source_id()`, raw keys 1–4, a small on-screen list). Changed: `lunge.gd` supports `lunge_stuns` (`flag_stun_duration` 0.5, a `status_stun` copy passed to `hit_units()`), `knight_e_lunge.tres` lists it in `supported_flags`; `sandbox.tscn` gets the `SandboxAugments` node with the four items, and its `test_q` (Ryan had set the slam) is emptied so Q is Cleave. Also decided: the soft caps stay as they are for the 375 Knight (Ryan). Found while building: while the wave is equipped, Cleave's own tooltip (not shown by the HUD, which shows the wave's) lists the wave as "disabled: another replacement is active", since `get_augment_tooltip_lines()` treats every REPLACE for the base id that isn't the ability itself as disabled; left as it is.

Abilities test 494/494 (27 new): the four augments' data (ids, kinds, scopes, the two rules' triggers, roles, targets and effects, Lunge's flag, the wave's numbers); Lunge stuns: the flag and tooltip line, the dummy on the path stunned for 0.5 s, unequipped: hit without a stun; Cleave Wave: Q casts the wave while the export stays Cleave, the tooltip line, Cleave's scoped +10 reaching the wave, one wave with its crescent passing through two dummies beyond Cleave's reach for 124.8 each, unequipped: Cleave again with the slot's cooldown carried over; Judgement reset: one unit rule and the tooltip line, a kill making R ready at once, a non-kill leaving the cooldown running, unequipped: the rule gone and a kill not resetting; Cleave casts Lunge: at Cleave's effect start a free Lunge (source `augment_cleave_casts_lunge`), the Knight moving 100 px, both hits on the dummy, E's charges and cooldown untouched, unequipped: Cleave alone; `SandboxAugments`: the four source ids, all four toggled on (the wave on Q, the flag, two rules, the tooltip lines, the wave also listing the Lunge line), the 2 key turning the wave off, all off: the Knight exactly as before. First run: one test mistake (the free Lunge's hit lands the frame after its dash ends). Combat test 451/451, stats 172/172, audio 109/109. `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors or warnings.

**Passed** (Ryan's play test, 2026-09-28).

### AB13 – VECTOR cast style: 2026-09-28, Built (awaiting play test)
**AB13 – VECTOR cast style.** Press to drop a start point, drag to aim, release to cast along a line, through the CHARGE_UP hold/release path.

Ability: `CastStyle.VECTOR` (last in the enum), an export group "Vector" (`vector_length` 500, `vector_width` 75, `vector_min_drag_px` 8), `get_vector_direction()`, `get_vector_tap_direction()`, virtual `draw_vector_indicator()` and `get_ai_vector()`. CastContext: `vector_start`, `vector_direction`, `vector_end`. AbilityComponent: `VECTOR_WALL_RADIUS_PX` (2), `get_vector_start()`, `try_cast_vector()`; `try_start_charge()` takes VECTOR (every part, part 0 or a recast part; POINT only, else `push_error`) and drops the start point (`_clamp_vector_start()`: `cast_range`, then a wall sweep unless `ignores_walls`); `_get_charge_full_time()` is 0 for VECTOR, so `get_charge()` is 1 and `overhold_time` is the hold limit (the ability bar's orange part shows it with no bar change); `release_charge()` builds the context at the start point and `_fill_vector()` sets the line, `point`, `direction` and `vector_drag`; `_end_charge()` forgets the start point; `try_cast()` and `try_cast_free()` cast a VECTOR ability as a tap (`_make_cast_context()`); the press's condition check clamps the aim to the start point when the ability needs a condition target. Player: VECTOR presses (recast parts too) go to `request_charge()`; a buffered VECTOR press whose key was let go releases on its own start point (`_release_charge(aim)`); `_draw()` uses `draw_vector_indicator()` while a start point exists (`_drawn_vector_start` for tests). Enemy: a VECTOR ability is cast with `get_ai_vector()` + `try_cast_vector()`. Telegraph: `line()`, a band that fills along its length. SandboxAbilities: `test_elite_w` (on `Elite1`'s W); `sandbox.tscn` sets `test_q` = `test_vector_line` (was `test_nova`) and `test_elite_w` = `test_vector_wall`. Test data: `test/vector_line.gd` + `test_q_vector_line.tres`, `test/vector_wall.gd` + `test_w_vector_wall.tres`. Decided while building: the test line is `dash_cancelable` (so a dash is one of its exits); a buffered tap releases on the start point rather than at the cursor, so it is a true tap (drag 0) even when the cursor is out of range; COMBAT.md's Telegraph line lists `line()`.

Abilities test 467/467 (69 new, with the pre-commit `knight.tres`, see below): the enum and defaults, the test data, style tags matching `cast_style` for eight abilities, the tooltip; a press placing the start at the cursor, charge 1, the 40 paid, nothing taken until release, walking at ×0.6, the hold limit counting from the press; a release 100 px down: the line down from the start, `vector_end` 160 px on, `point` = start, `direction` caster → start, `vector_drag` 0.625, the charge and 3 s cooldown taken, the locked indicator; after 0.2 s only the dummy on the line hit, 92 magic, tagged `vector` and `line`; a 6 px release as a tap along caster → start; `vector_drag` in a ChargeScaling (80.75); the start clamped to 160 px, to a wall's face (53 px), a cursor inside the wall the same, `ignores_walls` keeping the cursor, a tap on the caster along its facing; the hold limit at 2 s (FIRE) with the charge bar drawn, CANCEL_REFUND refunding; nine exits (release, FIRE, CANCEL_REFUND, Esc, stun, dash, a channel's move press, a slot swap, a lost key release) and death each clearing the start point, the drawn indicator, the bar and the sound with `charge_ended` once; the Player's press in hold-to-aim mode aiming a vector (not `aiming_slot`), the drawn start marker, the release; a buffered press during Lunge firing as a tap; a two-part VECTOR recast whose part 1 is aimed, costs 10 and pauses the window; `try_cast()` as a tap, `try_cast_vector()` with `vector_drag` 1, a free cast clamped to 160 px as a tap, a hold-to-aim Strike aim whose slot became VECTOR casting a tap; `Telegraph.line()`, the default and the wall's `get_ai_vector()`, the elite's AI casting the wall with a line telegraph and hitting the Knight for 100, a stun mid-cast removing the telegraph that frame with no hit. The AB13 checks turn crits off with a test modifier. First runs: two test mistakes (the first cast's telegraph still flashing when the second was looked up; a `weakref()` typed by inference).

Found while building: `knight.tres` in commit 45d3457 has `crit_chance` 0.25, `life_steal` 0.01 and `move_speed` 375 (was 0, 0, 560), which fails checks written for the old numbers in every suite: abilities 5–8 (crit-dependent, varies per run; the committed code without AB13 fails 7/398 too), combat 30/450, stats 14/172, audio 1/109. With the previous `knight.tres` swapped in for the run (then restored): abilities 467/467, combat 450/450, stats 172/172, audio 109/109. `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors or warnings.

### AB12 – Conditions: 2026-09-27, Passed
**AB12 – Conditions.** `Condition`, `ConditionalBonus`, cast / recast conditions, conditional bonuses, `get_effect_param()`, named inputs, LAST_PART_HIT, `ReactionRule.conditions`, the grey slot; the AB12 test data.

New: `scripts/data/condition.gd` (`Condition`: the eight kinds, `Comparison`, `negate`, `status_tag`, `min_stacks`, `value`, `count`, `radius`, `fail_text`; `is_met()`, `is_target_kind()`, static `all_met()`, `first_failed()`, `any_target_kind()`), `scripts/data/conditional_bonus.gd` (`ConditionalBonus`: `conditions`, `modifiers`, `target_statuses`, `self_statuses`, `description`; `is_active()`). Ability: an export group "Conditions" (`cast_conditions`, `recast_conditions`, `conditional_bonuses`), `can_cast_custom()`, `get_custom_fail_text()`, `get_conditions_for_part()`, `needs_condition_target()`, `get_active_bonuses()`, `get_effect_param()`; `get_charge_scaling()` reads only charge scalings; `get_scaling_damage()` takes an optional cast; tooltips list each bonus. ChargeScaling: `input` (default `charge`). CastContext: `inputs`, `get_input()` / `set_input()`, `charge` as a wrapper over `inputs[&"charge"]`, `last_part_hit`. StatusComponent: `get_tag_stacks()`. AbilityUtil: `nearest_enemy_in_range()`. ReactionRule: `conditions` (checked in `Reactions._fire()` after the tag filters, before chance). HitPipeline: `from_ability()` with a cast reads `get_effect_param()` per unit hit and adds passing bonuses' target statuses (without a cast, the old path). AbilityComponent: `FAIL_CONDITION`, `get_fail_reason(slot, aim, target)` (conditions last), `conditions_pass()`, `get_condition_fail_text()`, `set_aim_hint()` / `get_aim_hint()`, `_make_context()` fills the condition target, the built-in inputs and `last_part_hit`; the recast sequence tracks `last_part_hit` from `Events.unit_hit`; passing bonuses' self statuses at the effect start (free casts too). Player: the aim hint every physics frame; a press that's ready and not blocked but fails its conditions fails at once with "condition" (not buffered), using the same target pick as `cast_ability()`. Enemy: the aim hint before it tries a cast. Ability bar: grey while "condition" (`is_condition_greyed()`), the flash on a "condition" press. Test data: `status_test_focus.tres`, `status_test_mark.tres`, `test/nova.gd` + `test_q_nova.tres`, `test/mark_strike.gd` + `test_q_mark_strike.tres`, `data/reactions/reaction_test_execute.tres`. Decided while building: bonus modifiers are a second layer on top of the scoped and scaled value; without a cast, named inputs count full; the condition target is also filled for a `target_distance` scaling; a free cast's given target wins over the condition target; a UNIT ability's HUD preview uses the enemy near the aim hint.

Abilities test 398/398 (44 new): every Condition kind (stacks summed per tag, min stacks, negate, a TARGET_ kind with no target false even negated, health above / below, distance, enemies in range with and without a tag, resource, LAST_PART_HIT from the cast), `all_met()` / `first_failed()`, the `charge` wrapper and `set_input()` clamping, every existing ChargeScaling on `charge`; Nova without Focus: reason "condition" with "Needs Focus", the slot greyed, a press failing at once with the flash, nothing spent (a 20 cost stays, the charge stays), not buffered and nothing fired later; with Focus: un-greyed the same frame, the press casts; ready again without Focus: greyed; Nova's bonus: one enemy near → 200 u, the edge dummy not hit; a second enemy arriving during the cast time → 300 u at the effect, both hit; the tooltip's bonus line; `self_missing_health` 0 → 30, 0.5 → 45, the tooltip's plain 60; a strike copy needing a marked target: passes aimed near the marked dummy, "condition" near the unmarked one, `ctx.target` is the marked one, and no enemy in range fails even negated; Mark Strike: part 0 hits and marks, the recast passes and strikes the marked dummy (the mark removed); part 0 missing with an old mark still in range → "condition" with "The first strike missed", the press fails, the window stays open, runs out, the cooldown starts; part 0 hitting with the mark gone → "condition" with "No marked enemy in range", marked again → passes; the execute rule under `item_test_execute`: nothing on a healthy dummy, one 30 proc below 30%, nothing once removed. First run: two test mistakes (a cooldown reset the frame a recast sequence ended, before its recharge starts, as in AB8; a strike still on cooldown before a condition check). Combat test 449/450: the known flaky real-time "heavy feel: 0.06 s hitstop" check failed in both AB12 runs and in one of two runs of the committed AB11 code (stashed), so it's this machine's timing. Stats test 172/172, audio test 109/109 (its at-exit leak lines are on the committed code too). `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors or warnings.

**Done means** (as it was in ABILITIES.md until it passed): the abilities test covers: a test ability that only casts while the caster has a test status (a failed press: the "condition" cue, nothing spent, not buffered; the slot greys and un-greys); a recast that only works while a test status is on the target (ENEMIES_IN_RANGE with the tag); a conditional bonus (a bigger radius when a condition passes, checked at the effect); a named input other than charge scaling a param; LAST_PART_HIT; a fake item using the same `Condition` inside a reaction rule. With no conditions set, the game plays exactly as before, and the Knight's abilities, enemies chasing and the HUD still work.

**Passed** (Ryan's play test, 2026-09-28).

### AB11 – The Knight's abilities from toolkit pieces: 2026-09-27, Passed
**AB11 – The Knight's 4 abilities rebuilt from toolkit pieces only** (replaced working code; plan approved by Ryan).

Ability: `hit_units(caster, units, ctx, statuses = [])` (one crit roll per cast, `from_ability(…, ctx)`, the push, statuses on the hit, resolve; a unit the hit kills still slides the push, since `Unit.on_hit()` doesn't push the dead), `play_hit_feel(hits)` (once, only when a hit landed), `hit_knockback_px` (scoped) / `hit_knockback_duration`, an export group "Feel" with `hit_shake` / `hit_hitstop`. AutoAttackComponent: `set_empower_on_hit(status_id, on_hit)` (the wrapper uses it too). Cleave: `in_cone()` + `filter_by_walls()` + `hit_units()` + `play_hit_feel()`; `knight_q_cleave.tres` `hit_knockback_px` 17, `hit_shake` 3, `hit_hitstop` 0.05; the old `knockback` export is unused (commented; deleted after AB-M passes, Ryan). Lunge: `hit_units()` + `play_hit_feel()`; `hit_shake` 2.5. Judgement: `hit_units()` with a `status_stun` copy for `stun_duration` as the hit's status (read with `get_param()`), `play_hit_feel()`; `hit_shake` 6, `hit_hitstop` 0.09. Iron Resolve: applies its haste status (`iron_resolve`) and its empower status (`empower_iron_resolve`, `empower_statuses` = `iron_resolve_slow`) itself, built from its exports the way the old wrappers built them; its per-enemy VFX and feel through `set_empower_on_hit()`. Ryan's calls: the cast feel plays only when a hit landed; Iron Resolve's per-enemy feel stays a script callback; only the Knight's four abilities; Cleave's push direction checked; the old export kept. Found while building: the Knight's hits never received their cast's context (so ability empowers and a free cast's chain depth didn't reach them), Cleave's manual push ignored unstoppable, and Iron Resolve's slow had no source: all three closed. Also found: `Unit.on_hit()` doesn't push a unit its hit killed, while Cleave's own push slid the body; `hit_units()` keeps that slide so Cleave is unchanged.

Abilities test 354/354 (23 new): Cleave's data; a real Cleave hits for 124.8 with its tags, pushes 17 px in today's direction (angle error < 0.01 rad, off-axis target), plays a 3 px shake and a hitstop once, slides a unit it kills 17 px the same way, doesn't push an unstoppable target, gets +20 from an ability empower scoped to it, and plays no feel when every hit is blocked (the dummy checked inside the cone); Lunge dashes 120 px and hits for 82 with a 2.5 px shake and no hitstop, and a free Lunge at chain depth 2 hits at depth 2; Judgement hits for 150 + 64 + 20% of 1000 missing, stuns 0.75 s from the Knight with `status_stun`'s tags and stars, plays a 6 px shake and a hitstop, and a blocked Judgement stuns nothing and plays no feel; Iron Resolve's haste (560 → 739.6, 2 s) and empower (82, 4 s, the slow's id, tags, −40%, 1.5 s), both dummies taking 64 × the swing's ratio + 82, slowed from the Knight, a 2.5 px shake each, used up; the four scripts contain no `displace(`, `apply_stun(`, `add_speed_modifier(`, `add_next_attack_modifier(`, `CritRoll.new(` or `HitPipeline.resolve(`. The same AB11 Cleave checks run against the old Cleave (stashed): every behavior check passed (the hit, 17 px, the direction, the kill slide, the feel), and it failed only the four intended changes (the new data, unstoppable, the empower, the feel on blocked hits). A probe measured a survivor's push at 17.0 px on both versions, same direction to 1e-7 rad. First runs: test mistakes only (a swing ratio read during recovery; the dummy pushed out of the cone before the blocked-hit case, which made that case pass on the old code too). Combat test 450/450 unchanged (the known flaky real-time "heavy feel" hitstop check failed once on the first run, then passed), stats test 172/172, audio test 109/109 (its "resources still in use at exit" lines also appear on the committed AB10 code). `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors or warnings.

### AB10 – Empowers, unstoppable, untargetable: 2026-09-27, Passed
**AB10 – Empowers, unstoppable, untargetable.** The `empower_*` fields, the `empowered` hit tag, Iron Resolve through the `add_next_attack_modifier()` wrapper, `unstoppable`, `untargetable` (`is_targetable()`), the cleanse (AB8's).

StatusEffect: `EmpowerTrigger` (NONE / BASIC_ATTACK_HIT / ABILITY_CAST), an export group "Empower" (`empower_consumed_by`, `empower_scope`, `empower_base_damage`, `empower_ad_ratio`, `empower_statuses`), `is_empower()`. StatusComponent: `get_empowers(trigger)`; `apply_status()` refuses `cc` on an unstoppable unit, removes every `cc` when unstoppable is applied, and refuses statuses from other units on an untargetable one. Unit: `is_targetable()`, `is_untargetable()`, `is_unstoppable()`; `on_hit()` blocks non-`dot` hits on an untargetable unit and skips knockback on an unstoppable one; Hurtbox hits blocked while untargetable. `KnockbackGameplayEffect` skips an unstoppable target. HitPipeline: `add_empowers(ctx, empowers)`; `from_ability(…, cast)` adds `cast.empowers`. CastContext: `empowers`. AbilityComponent: `_use_up_ability_empowers()` at the effect start before `ability_cast`, skipped for free casts; UNIT targeting and the walk-into-range cast check `is_targetable()`. AutoAttackComponent (the replaced code, approved): `add_next_attack_modifier()` / `has_next_attack_modifier()` / `is_empowered()` are wrappers over an empower status `empower_<id>` (`get_empower_status_id()`), with `on_hit` kept as a per-target callback; `_land_swing()` and `_land_attack()` read the basic attack empowers at the hit, use them up when the hit lands on anyone and add them through `add_empowers()` (the League-style path adds the same numbers to its pre-scaled hit); the old dictionary stays for a unit without a StatusComponent; attack targets check `is_targetable()`. Projectile: a freed caster's snapshot includes the cast's empowers. AbilityUtil: `enemies_of()` / `enemies_of_team()` skip untargetable units. Player: the enemy under the cursor must be targetable. Enemy: no new aggro on an untargetable player; aggroed, `_chase_untargetable()` cancels the attack and keeps chasing. Ryan's changes to the plan: the status id `empower_<id>` (the doc's `<id>` collided with Iron Resolve's haste status `iron_resolve`); aggroed enemies keep chasing rather than holding position; free casts don't use up ability empowers; untargetable lets DoT already applied keep ticking (so it isn't an invulnerability id). Found while building: `empower_statuses` typed `Array[StatusEffect]` (its own class) made every test run report "2 resources still in use" at exit; typed `Array[Resource]`, the warning is gone.

Abilities test 331/331 (48 new): Iron Resolve applies `empower_iron_resolve` (empower + buff, BASIC_ATTACK_HIT, 82, 4 s) next to its haste; the wrapper's queries; a swing that hits nothing keeps it; the swing hits both dummies for 64 × the swing's ratio + 82, crit (× 1.75) with the swing, tagged `empowered`, highlighted, both slowed, used up; the next swing is plain; unused it runs out after 4 s; a `passive_test` rule granting the same empower on cast gives the same numbers; a slime's League-style attack adds its empower (+10) and uses it up; an ability empower scoped to `test_strike`: the bolt doesn't use it (82), the strike does (72 + 30, tagged, its slow applied), the next strike is plain; a free strike leaves it (72) and the next real strike uses it (102); a rule granting it on cast doesn't feed the same cast; an empty scope feeds the bolt (87); unstoppable removes a stun and a slow, refuses new stuns and slows (`add_speed_modifier()` too), lets a haste apply, blocks a hit's knockback and `KnockbackGameplayEffect`, and once it ends knockback and cc work again; the cleanse; untargetable: not in `enemies_of()`, Judgement "no target" through the Player's pick and directly, a new hit blocked, statuses from another unit refused (its own and the environment's apply), a burn applied before keeps ticking, not an attack target and dropped as one, a walk-into-range Judgement dropped, a bolt flies through it into the dummy behind; an untargetable player isn't aggroed; aggroed, a slime mid-windup cancels it, drops the target, keeps a move order and does no damage, then attacks again when targetable. The test arena has no navigation mesh, so a probe run in `sandbox_main.tscn` checked the chase: an aggroed slime closed from 110 px to 70 then 46 px over 1 s with no target, no windup and no damage, and targeted the player the frame untargetable ended. First runs: test mistakes only (the Knight's combo swings have ratios 1.0 / 1.5 / 1.6, a float compared inside an array, a slime placed where it had to walk without navigation). Combat test 450/450 (unchanged, including Iron Resolve's 64 + 82 on both, both slowed, used up), stats test 172/172, audio test 109/109. `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors or warnings.

### AB9 – Forms: 2026-09-27, Passed
**AB9 – Forms.** `StatusEffect.augments`, one `form` status at a time, several slots swapped by one status.

StatusEffect: an export group "Augments" with `augments` (typed `Array[Resource]` like `reaction_rules`, for the same preload cycle) and `is_form()` (tagged `form`). StatusComponent: `_start()` adds each AbilityAugment to the unit's AbilityComponent under `&"status_<id>"` and `_stop()` removes them (nothing on a unit without an AbilityComponent); applying a form that isn't already on removes every other form first (`_remove_other_forms()`); a REFRESH of the same status keeps its augments instead of removing and re-adding them, so its slots don't flicker and a walk-into-range cast isn't dropped. Nothing new in AbilityComponent: AB8's REPLACE already handles several REPLACE augments under one source id, per slot, with cooldowns per slot. Test data is built in the test (two REPLACE augments on one status); no new .tres.

Abilities test 283/283 (16 new): a form swaps Q (the strike → a bolt) and E (Lunge → a strike) while W, R and the q / e exports are unchanged; the slots report the change and carry the form's augments; in the form Q fires the bolt; removing it restores Q and E exactly with the same cooldown still running, and going back into the form keeps it; a second form removes the first and leaves no disabled REPLACE; a non-form status leaves the form on; re-applying the same form doesn't change the slots; a form that runs out and clearing every status (death) restore the slots; a form applied mid-cast lets that cast finish as the strike; a unit without an AbilityComponent takes a form without errors. Combat test 450/450 (the flaky "heavy feel: 0.06 s hitstop" check failed once, then passed on a rerun), stats test 172/172, audio test 109/109. `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors or warnings.

### AB8 – Augments and the new GameplayEffects: 2026-09-27, Passed
**AB8 – Augments and the new GameplayEffects.** `AbilityAugment` (FLAG, EVENT, REPLACE), `Events.ability_cast` + the ABILITY_CAST trigger, free casts, `ModifyCooldown`, `RestoreResource`, `CastAbility`, `RemoveStatusesByTag`, status rules, `test_strike`.

New: `scripts/data/ability_augment.gd`, the four GameplayEffects in `scripts/data/`, `scripts/abilities/test/strike.gd` + `data/abilities/test_q_strike.tres`. Ability: `supported_flags`, `variant_of` (in `get_modifier_scopes()`), augment lines in the tooltip. CastContext: `ability`, `flags` + `has_flag()`, `is_free`, `source_id`, `chain_depth`. HitContext: `chain_depth` (copied by `from_ability()` and the projectile's no-source hits). Events: `ability_cast`. ReactionRule: `ABILITY_CAST` (added last in the enum, so saved rules keep their numbers), `required_ability_scope`, `matches_ability()`. Reactions: the ABILITY_CAST listener, the scope filter, `get_current_source_id()` (via the new `Unit.get_reaction_rule_entries()`), `run_at_depth()`, HIT / UNIT_DIED at max(depth, `HitContext.chain_depth`). StatusEffect: `reaction_rules` (added / removed with the status). StatusComponent: `remove_statuses_with_tags()`. AbilityComponent: augments (`add_augment`, `remove_augments_from`, `get_augments`, `get_disabled_augments`, `get_flags`, `get_augment_tooltip_lines`, `get_base_ability`, `augments_changed`; `get_ability()` = a recast sequence's ability, else the REPLACE variant, else the export; EVENT rules added once per id under `augment_<id>` as duplicates scoped to the augment; the exact-scope FLAG error), cooldown changes (`get_slots_matching`, `reduce_cooldown`, `reduce_cooldown_percent`, `reset_cooldown`, via the extracted `_finish_recharge()`), `try_cast_free(ability, aim, target, source_id)`, and `Events.ability_cast` at the effect start. Ryan's changes to the plan: ABILITY_CAST at the effect start (not cast start), so no queued free casts; free casts never touch the cast in progress; RESET finishes the current recharge, not a full refill; nothing while a recast window is open. Found while building: `StatusEffect.reaction_rules` typed `Array[ReactionRule]` broke compilation (MovementComponent preloads status .tres files, and the type pulled GameplayEffect and Unit into that preload cycle), so it's `Array[Resource]`; `try_cast_free()` takes an aim and a target rather than a prepared context.

Abilities test 267/267 (66 new): FLAG: no stun without it, a stun with it, removal mid-cast keeps that cast's stun, a `tag:core` scope, an unsupported exact scope ignored with one error, two sources counted once; REPLACE: the variant casts and the export is unchanged, a base modifier reaches the variant, its tooltip line, a second REPLACE disabled with its reason and taking over, equipped mid-cooldown (same cooldown), mid-cast (finishes as the strike), mid-charge-up (the release fires the line), mid-recast (the sequence ends first); `ability_cast`: not at cast start or during the cast time, once at the effect, none for a stunned cast, one per recast part, after a charge-up's windup, at once for a free cast; EVENT: its rule added once for two sources and scoped, the shared rule unchanged, a cast restores 20, a stunned cast restores nothing, another ability doesn't trigger it, removal takes the rule away, a kill resets the cooldown and a non-kill doesn't; the effects: REDUCE_SECONDS, REDUCE_PERCENT, RESET (with the ready signal), a non-matching scope, RESET with charges (+1, not a refill), RESET while a recast window is open (nothing), RestoreResource (10 + 10%), the cleanse (stun and slow), a status's rule with it; free casts: at the effect start, aimed at the cast's point, from the augment's source, no charge used, none for a stunned cast, from a HIT at once aimed at the unit hit, during another cast's cast time (no interruption, no cost), refused while stunned, chains of exactly 1 and 3, a HIT loop stopping after 1; the fake item: equipping adds two tooltip lines, the flag, one rule, cooldown 1.5 and two augments, unequipping restores all of it exactly. First run: three test mistakes (a bolt still in flight killed the kill-reset test's dummy, regen during the cast, a reset the frame a recast sequence ended), fixed in the test. Combat test 450/450, stats test 172/172, audio test 109/109. `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors or warnings.

### AB7 – Projectiles: 2026-09-27, Passed
**AB7 – Projectiles.** The shared `Projectile` piece, the projectile params, `WorldQuery.shape_sweep()`, `test_bolt`.

Ability: an export group "Projectile" (`projectile_speed` 1200 u/s, `projectile_width` 60 u, `projectile_count` 1, `projectile_spread_deg` 15, `projectile_pierce` 0; all scoped). New `scripts/abilities/projectile.gd` (`Projectile`, Node2D): `Projectile.fire(caster, ability, cast, origin, direction)` fans out `projectile_count` projectiles sharing one `CritRoll`, added next to the caster; each physics frame it moves, sweeps its 2 px core against walls (`WorldQuery.shape_sweep()`, unless `ignores_walls`), hits enemies of its team along the swept capsule (each once, nearest first, `pierce + 1` at most) through `from_ability(…, cast)`, and ends at a wall, its last hit or its range; with its caster freed it hits for the damage snapshotted at fire plus target terms, with no source and no crit. `debug_draw` shows each frame's capsule. `WorldQuery.shape_sweep(from, to, radius, mask = 1)` (a circle `cast_motion`; {position, fraction} or {}). `AbilityUtil.enemies_of_team()` / `along_segment_of_team()`. New `scripts/abilities/test/bolt.gd` + `data/abilities/test_q_bolt.tres`. WORLD_INTERACTION.md and CLAUDE.md now list `shape_sweep()` as built.

Abilities test 201/201 (19 new): `shape_sweep` stops at a wall (circle center at 90 for a wall face at 92) and returns nothing when clear; the projectile defaults; the bolt's role and tooltip; after the 0.1 s cast one bolt is in flight and nothing is hit, still nothing 8 frames later, then the first dummy is hit for 82 and the one behind isn't (pierce 0), and the bolt is gone; with a scoped +2 pierce both are hit in order and it flies on to its range; a wall in between stops it, `ignores_walls` goes through; a dummy beyond 900 u isn't hit; a scoped +2 count fires three bolts at −15 / 0 / 15° that each hit their dummy with one shared crit roll; the elite's bolt flies through a slime (its own team) and hits the Knight; a shooter freed mid-flight still hits for 82 with no source and no crit (it had 100% crit). Combat test 450/450, stats test 172/172, audio test 109/109. A windowed sandbox run: three bolts fan out, drawn in the ability's color. `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors or warnings.

### AB6 – Charge-up: 2026-09-27, Passed
**AB6 – Charge-up.** CHARGE_UP: hold to charge, release to fire; `ChargeScaling`, overhold, the growing indicator, the charge-up bar, `charge_sound`, `test_charged_line`.

New `scripts/data/charge_scaling.gd` (`ChargeScaling`: `param`, `min_fraction`, `curve`; `get_multiplier()`). Ability: `Overhold` (FIRE / CANCEL_REFUND), an export group "Charge-up" (`charge_time` 1.5, `overhold_time` 2, `overhold`, `charge_scalings`, `charge_sound`), `get_charged_param()` (−1 = the caster's current charge while charging this ability), `get_charge_scaling()`, `get_scaling_damage()` / `get_damage_against()` take a charge; tooltips `{x_min}` (the value at a tap); the base `draw_indicator()` reads the charged range. `CastContext.charge` (1.0). `HitPipeline.from_ability(caster, ability, target, cast = null)` uses `cast.charge`. AbilityComponent: `try_start_charge()` (pays the cost, locks and walking rules through the new `_begin_cast_locks()`, which casts use too), `_update_charge()` (hold, overhold FIRE / CANCEL_REFUND), `release_charge()` (→ `_do_cast(…, precharged = true)`: the charge and cooldown taken now, cost and locks not redone), `try_cancel_charge()`, `set_charge_aim()`, `is_charging()`, `get_charge()`, `get_charge_hold_time()`, `get_overhold_left()`, `_make_context()` (shared by casts and releases); cancel and interrupt stop the charge and its sound; signals `charge_started`, `charge_released`. Player: a CHARGE_UP press → `request_charge()`, release → `release_charge()`, Esc cancels a charge (handled, no pause), `start_buffered_ability()` (PlayerInput fires buffered Q/W/E/R through it; a charge-up whose key was let go fires as a tap), `get_indicator_slot()` (aimed or charging: indicator, facing, sword, cursor), `_update_charge_input()` (aim on the cursor; a release the game didn't see). Ability bar: the charge-up bar above the slot. New `scripts/abilities/test/charged_line.gd` + `data/abilities/test_q_charged_line.tres`. Found while building: a new `class_name` needs an import pass (`--import`) before a headless run sees it.

Abilities test 163/163 (31 new): `ChargeScaling` multipliers; the line's range 440–1100 and damage 59.2–118.4 and its tooltip; starting pays 40 and takes no charge or cooldown; walking at 0.6 while charging (one modifier), not rooted; half charged at 0.75 s with the indicator range at ~770; releasing takes the charge and the 3 s cooldown, removes the walking modifier and hits the dummy 200 px away for 118.4 × (0.5 + 0.5 × charge), MAGIC, tagged `line` / `charge_up`; a tap fires at charge 0 and hits only the near dummy for 59.2; overhold FIRE fires by itself at full charge after 3.5 s (1 s of overhold left at 2.5 s); CANCEL_REFUND cancels with the cost back; Esc, a stun and a dash (dash_cancelable) each cancel with the cost back and the slot ready; through the Player: holding Q charges in quick cast mode, letting go fires at ~1/3; a release the game never saw is released the next frame; "not enough resource" doesn't charge or buffer; a press buffered during Lunge whose key was let go fires as a tap. Combat test 450/450, stats test 172/172, audio test 109/109. A windowed sandbox run with the line on Q: the indicator grows between the two screenshots, the charge bar shows above Q, move speed 347 while charging, releasing fires it. `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors or warnings.

Ryan's play test: tests 1, 2, 3, 5 and 7 passed; the indicator stayed on screen after the overhold fired it (4) and after a dash cancelled it (6). Cause: the Player only redrew while an indicator slot existed; a normal release and Esc called `queue_redraw()` themselves, but the overhold, a dash, a stun, a move cancel and death end the charge inside AbilityComponent, so the last drawn frame (with the indicator) stayed. Also found: the charge re-read `get_ability(slot)` each frame, so a slot swap mid-charge would have changed the ability. Fix: charge phases NONE / HOLDING / RELEASED and one end-charge path, `_end_charge()` + signal `charge_ended`, called by `_cancel_cast()`, `interrupt_cast()`, the end-of-cast-time interrupt and the effect start; the Player redraws on it (and the frame its indicator slot empties); `_cast_ability` / `get_charge_ability()` keep the charge-up's own ability. Added the release windup: `cast_time` on a CHARGE_UP ability runs after release (already so), now with the aim and charge locked (`get_locked_charge_aim()`, `has_charge_indicator()`, `Player.get_indicator_aim()`) and the indicator kept until the effect; `test_q_charged_line.tres` `cast_time` 0.3. The Player and ability bar record what they last drew (`_drawn_indicator_slot`, `_drawn_charge_bar_slot`) for the tests.

Abilities test 182/182 after the fixes (19 new): each of release (after its windup), overhold FIRE (after its windup), overhold CANCEL_REFUND, Esc, a stun, a dash, a move press on a channel charge-up, the slot swapped mid-charge then released, and a lost key release shows the indicator, the bar and a looping charge sound while charging, then leaves none of them and emits `charge_ended` once; a second Knight dying mid-charge ends it at once with its sound stopped; the release windup: `cast_started` at release, the indicator locked at the release aim and the locked charge's range, the cursor no longer moving it, walking at 0.6 still applied, no hit at 0.2 s, the hit after 0.3 s and the indicator gone; a stun and a dash in the windup refund the cost, the charge and the cooldown with no hit. Stats test 172/172, audio test 109/109. Combat test 449/450: the flaky "heavy feel: 0.06 s hitstop" check failed 3 of 5 runs here and 3 of 3 on the committed code (stashed), so it's this machine's timing, not AB6.

### AB5 – Recasts: 2026-09-27, Passed
**AB5 – Recasts.** `recast_count`, `recast_window`, `recast_resource_cost`, `CastContext.part`, the window and its HUD bar, `test_triple_step`, `SandboxAbilities.test_q`.

Ability: `recast_count` (0), `recast_window` (3 s, scoped), `recast_resource_cost` (0, scoped). `CastContext.part`. AbilityComponent: `_recast` sequences (next part, window time, ability), created at part 0's cast start; `is_ready()` is also true while one is going; `get_recast_part()`, `get_recast_time_left()`, `get_recast_window()`, `get_slot_cost()` (`can_afford()` uses it); `try_cast()` sets `ctx.part`; `_do_cast()` takes a charge only for part 0 and starts no recharge when the ability has recasts; `_advance_recast()` after a part's effect (opens the next window or ends the sequence), `_update_recast_windows()` (not while one of the slot's parts is cast), `_end_recast()`; `_update_recharge()` waits while a sequence is going; a refunded part 0 erases its sequence, a refunded later part only gets its cost back. Signals `recast_window_started(slot, part, time)`, `recast_window_finished(slot)`. Player: a press inside a recast window casts at once whatever the cast mode. Ability bar: initials, a gold border and a shrinking 3 px gold bar while a window is open. New `scripts/abilities/test/triple_step.gd` + `data/abilities/test_q_triple_step.tres`. `SandboxAbilities.test_q` (null by default).

Abilities test 132/132 (22 new): no ability has recasts by default; Triple Step's numbers, role and tooltip; part 0 takes the charge without starting the cooldown, steps 48 px, opens a 3 s window (2.5 s left after 0.5 s, no cooldown running); part 1 steps 48 px and restarts the window; part 2 steps 72 px; parts 0 / 1 / 2; the sequence ends once and the 4 s cooldown starts; 3 s without a press ends it too; with costs 30 / 10: part 0 pays 30, stunned in part 0 gives back the charge and 30 with no window; part 1 pays 10, its window doesn't run during its 0.3 s cast time, stunned in part 1 gives back its 10 and keeps part 1 with the same window time; a press during part 1's cast time is buffered and fires as part 2. Combat test 450/450, stats test 172/172, audio test 109/109. `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors or warnings.

### AB4 – Charges: 2026-09-27, Passed
**AB4 – Charges.** `Ability.max_charges`, one recharge at a time, `charges_changed`, the ready ping on 0 → 1, the charge count on the slot, a sandbox Lunge with 2 charges.

`Ability.max_charges` (1; a scoped param, at least 1; `{charges}` in tooltips). AbilityComponent: `_charges` per slot (full the first time it's asked), `get_charges()`, `get_max_charges()`, `is_ready()` = a charge is stored; `_cooldown_left` is now the recharge timer (`_update_recharge()` each physics frame, `_start_recharge()`); a cast takes a charge and starts the timer only if none runs and the slot is below max; `cooldown_finished` + `ready_sound` only when a slot goes 0 → 1; new signal `charges_changed(slot, charges, max_charges)`. Refunds (cancel, `interrupt_cast()`, the end-of-cast-time interrupt) give back the charge the cast took (`_restore_slot()`): back at max the timer stops (the old "cooldown refunded"), below max a running recharge keeps its progress. First plan was to restore the whole slot state saved at cast start; changed while writing the checks, because that threw away recharge time (or a charge) gained during the cast time. The ability bar: the sweep and seconds only at 0 charges, otherwise a 2 px recharge bar along the bottom; the count bottom right when max > 1; "N charges" in the tooltip header. `SandboxAbilities`: `demo_charges` / `extra_charges` (Lunge +1).

Abilities test 110/110 (17 new): every ability has 1 charge; with 1 charge a 0.5 s-cooldown test ability is ready again after 0.5 s with one `cooldown_finished` and `charges_changed` 0 then 1; a scoped +1 makes it 1 of 2 and recharges the second without a ping; two casts back to back leave 0 and don't restart the running timer; the charges come back one at a time, one ping (0 → 1); removing the item at 2 charges keeps both (max 1, no timer), spending one starts nothing, spending the last starts the recharge; stunned in the cast time from full gives the charge back (no timer, no ping), and from 1-and-recharging gives it back with the recharge's progress kept; `{charges}`. Combat test 450/450, stats test 172/172, audio test 109/109. The abilities test now waits 10 frames after `Audio.stop_all()` before quitting (two sounds were still held at exit). Headless: the sandbox Knight's Lunge is 2/2, room_01's 1/1; `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors or warnings.

### AB3 – Costs, the resource bar, fail cues: 2026-09-27, Passed
**AB3 – Costs, the resource bar, fail cues.** `Ability.resource_cost`, paying and refunds, "not enough resource" never buffered, fail reasons and cues, the HUD resource bar, sandbox demo costs.

`Ability.resource_cost` (0; a scoped param; `{cost}` in tooltips). AbilityComponent: `FAIL_*` reason constants, `get_cost()`, `can_afford()` (a unit without a pool always can), `get_fail_reason()`, `fail_cast()`; `try_cast()` reports `get_fail_reason()` (a stunned press now reports "silenced", was "busy"); the cost is paid in `_do_cast()` and refunded (clamped at max) by a cancel, `interrupt_cast()` and the end-of-cast-time interrupt, not once the effect starts. `Player.request_cast()`: a ready, unblocked press that can't be afforded fails at once (`fail_cast`) and isn't buffered. `PlayerInput`: an ability press whose buffer runs out reports its reason. New `scripts/ui/resource_bar.gd` (added by `hud.gd`'s `setup_abilities()` when the player has a pool; `main.gd` unchanged): 132 × 4 px under the ability bar, colored by type, the amount beside it, blinks 0.2 s on "not enough resource". The ability bar: a red flash on "not ready" / "silenced", a grey tint while cast-blocked, a blue tint while unaffordable, "Cost N" in the tooltip header. New `scripts/rooms/sandbox_abilities.gd` + a `SandboxAbilities` node in `sandbox.tscn`: Cleave 30, Iron Resolve 40, Lunge 50, Judgement 80 (scoped, source `sandbox_demo`). Also: Judgement's unused `missing_health_ratio` export deleted (AB2 passed). `test_q` on SandboxAbilities moves to AB5, where the first test ability comes.

Abilities test 93/93 (26 new): free casts spend nothing; scoped costs and `{cost}`; Judgement pays 80 at cast start and gets it back when stunned 0.1 s in, and when move-cancelled; a stun once Lunge's dash has started refunds nothing; the elite (no pool) affords and casts a 50-cost slam; at 20 mana a Cleave press fails at once with "not enough resource", isn't buffered and spends nothing, and `try_cast()` refuses it the same way; a stunned press is buffered and reports "silenced" when it runs out, a press on cooldown reports "not ready"; in a real HUD the resource bar flashes on "not enough resource" (the slot doesn't), a slot flashes on "not ready", and both stop after 0.2 s. Stats test 172/172, audio test 109/109. Combat test 450/450 in two of three runs: its "heavy feel: 0.06 s hitstop" check (real-time) measured 0.038 s once, and fails the same way 1 run in 3 on the committed AB2 code, so it's a flaky test, flagged as its own task. Headless: in `sandbox_main.tscn` the Knight's costs are 30 / 40 / 50 / 80 and the HUD has the resource bar; in `main.tscn` they're all 0 (bar full). Both run 600 frames with no errors or warnings.

### AB2 – Damage scalings, tooltips, tags: 2026-09-27, Passed
**AB2 – Damage scalings, tooltips, tags.** `DamageScaling`, `ap_ratio`, Judgement's missing health in data, tooltips filled from the description template, the standard tags.

New `scripts/data/damage_scaling.gd` (`DamageScaling`: `param`, `ratio`, `of` CASTER_STAT / CASTER_BONUS_STAT / TARGET_MAX_HEALTH / TARGET_MISSING_HEALTH / TARGET_CURRENT_HEALTH, `stat`, `label`; `get_amount()`, `get_label()`, `is_target_term()`). Ability: `ap_ratio`, `scalings`, `ROLE_TAGS`, `get_base_param()` (an @export, else a term's ratio), `get_scaling()`, `get_scaling_damage()`, `get_damage_against()` (moved up from Judgement; `get_damage()` now calls it with no target, same numbers), `get_role()`, `get_tooltip()` (BBCode, damage colored by type) / `get_tooltip_plain()`; a term param that clashes with an @export is a `push_error`. `StatsComponent.get_ability_param()` reads the base through `get_base_param()`, so term ratios are scoped params. `HitPipeline.from_ability()` adds `get_scaling_damage()` to `base_damage` and sets `ap_ratio`. `judgement.gd`: the `hit.base_damage += …` line is gone, its `get_damage_against()` override removed, `get_missing_health_bonus()` reads the term, `missing_health_ratio` kept unused. Data: Judgement's term (`target_missing_health_ratio` 0.2, a sub-resource); tags Cleave `area` `core` `cone`, Iron Resolve `buff` `defensive`, Lunge `movement` `mobility` `dash`, Judgement `ultimate` `channel`, the slam `area` `core`; all five descriptions are templates. The ability bar's hover tooltip uses `get_tooltip_plain()`. Found while building: `DamageNumber` isn't a global class (Unit preloads it), so Ability loads the style by path; `String.num()` keeps a trailing ".0" in 4.7, so numbers are formatted by hand; placeholders gained `{param%}` for percents.

Abilities test 67/67 (31 new): Judgement 214 at full health and 214 + 20% of the missing health at half, equal to the old wrappers, the bonus in `base_damage`; a scoped +0.1 raises it to 30% and removing it restores it; the five term kinds' amounts and labels; `ap_ratio` and a bonus-AD term (200.8); the five tooltips word for word (Cleave now says 80); the BBCode color; +36 AD and a scoped +0.1 AD ratio show 160 and 80%, `{cooldown}` after 100 haste shows 1.5; an unknown placeholder stays (one expected warning); one role tag each, style tags match, the old tags stay, Cleave's hits carry `core` / `cone` / `area`, a `tag:core` modifier reaches Cleave and the slam but not Lunge. Stats test 172/172 (its step-6 tag check now checks the old tags are still there instead of the exact list), combat test 450/450, audio test 109/109. `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors or warnings.

### AB1 – Cast style, the stun interrupt, cast mode: 2026-09-26, Passed
**AB1 – Cast style, the stun interrupt, cast mode.** `Ability.cast_style`, a stun or silence interrupting a cast at once, the cast mode as a player setting.

`Ability.CastStyle` (INSTANT / CHARGE_UP / CHANNEL) and `cast_style` (INSTANT default; CHARGE_UP casts like INSTANT until AB6), `Ability.is_channel()` (CHANNEL or the old `cancel_on_move`). AbilityComponent reads `is_channel()` wherever it read `cancel_on_move` (the root, the stop, `can_cancel_cast_on_move()`, the walking multiplier), so both work the same. AbilityComponent connects to its unit's `StatusComponent.status_applied` (on the Unit's `ready`, since `status_component` is an `@onready` of the Unit) and calls `interrupt_cast()` when a status leaves the unit cast-blocked during a cast time; the end-of-cast-time check stays for units without a StatusComponent. `Settings` gets `CAST_MODE`, `get_cast_mode()` / `set_cast_mode()`, saved as `quick` / `quick_with_indicator` in `[controls]`, default `quick`; it reuses `Player.CastMode`. Player's `cast_mode` export defaults to QUICK and is copied from Settings at start and on `setting_changed`; a channel (and SELF, as before) casts on press whatever the mode. PauseMenu: a "Cast mode: Quick / Hold to aim" button under the dash one. Data: `knight_r_judgement.tres` `cast_style` CHANNEL (`cancel_on_move` stays on). New `scenes/tests/abilities_test.tscn` + `scripts/tests/abilities_test.gd`.

Abilities test 36/36: the cast styles of the Knight's abilities and the slam; a 0.2 s stun 0.1 s into Judgement ends the cast in the same frame (refunded, `cast_finished` once, no `cast_cancelled`, no hit later); a 0.1 s stun on the elite 0.1 s into its slam frees the telegraph that frame and no slam lands; a test silence (`blocks_cast` only) interrupts Cleave's cast time; a slow doesn't interrupt; a stun during Lunge's dash (its effect) changes nothing (it arrives, no refund); a CHANNEL with `cancel_on_move` off roots and is cancelled by a move press through PlayerInput, an INSTANT one isn't; the cast mode is emitted, followed by the Player, saved and loaded; in hold-to-aim E aims on press and casts on release, R (CHANNEL) casts on press, and in quick Q casts on press. The test writes the real `user://settings.cfg` and restores the cast mode it found. Stats test 172/172, audio test 109/109. Combat test 446/450: the 4 failures are the combo-speed checks (they expect `speed_scale` 1.0; Ryan's commit 5f7f0ae set `combo_knight.tres` `speed_scale` to 1.266), not AB1. `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors or warnings.

Note (2026-09-29): those 4 failures weren't about AB1. The AB1 commit (7217b5e) also removed `speed_scale = 1.266` from `combo_knight.tres`, which got the combat test to 450/450 but threw away Ryan's tuning with no DECISIONS or CHANGELOG entry. Restored and the tests fixed in the cleanup pass (Combat, 2026-09-29).

## Audio (AUDIO.md)

### Cleanup pass (audit fixes): 2026-09-29, Built (awaiting play test)
One bus list: `Settings.VOLUME_BUSES` (every bus in `default_bus_layout.tres`, in order) is canonical; `Audio.BUSES` (the same six) is deleted and Audio reads Settings'; the audio test's three uses moved to it. AUDIO.md: the pack burst is no longer marked proposed (built in A2), a stolen loop's restart described as built, the sound file pattern `sound_<category>_<name>`, `Ability.hit_sound` described as once per (source, sound, frame), "cue" wording replaced. Audio test 109/109 (its one "resources still in use at exit" line is on the baseline run too). Full suite: stats 179/179, combat 459/459, abilities 503/503, audio 109/109 (was 172 / 451 / 494 / 109 before the pass). `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors or warnings.

### Conditional audio specified (docs only): 2026-10-04, Approved
Ryan's design addition, written into AUDIO.md (How to add a sound; Conditional audio rules; Conditional audio: SoundVariant, SoundContext and what each call site can give, SoundCue, why a status ended, the ring-out example, UI sounds, the audition tool; build steps A4 and A5) with additive edits to ABILITIES.md (conditions used by sound variants, the status end reason, `consume_sound`, cues on casts), COMBAT.md (swing sound cues; per-swing hit tags as a proposal), CHAMPIONS.md (champion sounds take variants and cues), CONVENTIONS.md (the approved names, `Events.status_ended`), DECISIONS.md and CLAUDE.md. No code. Checked against the code: `SELF_HAS_STATUS` with `min_stacks` already covers "10+ stacks" (no new condition kind); every status removal path (six: the timer, an empower used by a swing or a cast, a shield used up, the cleanse, death, and a source taking it back), hence a fifth reason `REMOVED`; a hit's variants see the state after the hit's statuses and its reaction rules (Reactions connects to `unit_hit` before Audio); the next ability's hit-sound variant couldn't see an empower (used up at the effect start), hence `consume_sound`; an AttackSwing has no tags, so "the 4th hit grants an empower" isn't data today; Z is a free raw key. Ryan answered two rounds of questions, each as proposed (DECISIONS.md, Audio, 2026-10-04).

### A3 – Abilities and statuses: 2026-09-27, Passed (Ryan's play test, 2026-09-30)
**A3 – Abilities and statuses.** Ability cast/hit, the Telegraph wind-up, StatusEffect apply/expire/loop, low-health heartbeat, ultimate-ready ping, room cleared and death stingers.

`Ability.cast_sound` / `hit_sound` / `telegraph_sound` / `ready_sound`; `HitPipeline.from_ability()` copies `hit_sound` into the HitContext; `AbilityComponent` plays the cast sound at cast start, hands the telegraph its wind-up, and emits the new `cooldown_finished(slot, ability)` (with the ready sound) when a cooldown counts down to 0; `Telegraph.play_sound()` (stops at `finish()` or when freed); `StatusEffect.apply_sound` / `expire_sound` / `loop_sound`, played by CombatSounds on `Events.status_applied` / `status_removed`; `Player.low_health_sound` / `low_health_fraction` (0.25) on `health_changed`; `main.gd` `room_cleared_sound` / `player_died_sound`. Data: cast sounds on the four Knight abilities, Judgement's hit and ready ping, the slam's wind-up and hit, stun / slow / haste apply, the shield's apply and break (expire), the Knight's heartbeat in `player.tscn`, both stingers in `main.tscn` (so the sandbox gets them too). 16 more synthesized stand-in WAVs; the heartbeat is imported as a loop (`edit/loop_mode=2`, Forward, in its `.import`).

Audio test 109/109 (23 new A3 checks), three runs in a row: Cleave's cast sound at cast start, centered, and one hit sound for 3 targets; Judgement's cast sound, its own hit sound once instead of the tier's, and the stun it applies plays the stun sound on the dummy; Judgement has a ready sound; a 0.2 s-cooldown test ability emits `cooldown_finished` once and pings, a cancelled (refunded) cast doesn't; the slam's wind-up plays positional at the telegraph with 640 px, stops when the slam lands (its hit sound and the Knight's hurt play), when a stun interrupts it, and when the elite dies mid-cast; a 3-stack test status plays its apply sound 3 times and one loop, removing it stops the loop and plays its expire sound, a death stops the loop silently; the shield's apply sound on the Knight is centered and HIGH, 150 damage into it plays the absorb, the break and the hurt; the heartbeat doesn't play at 30%, starts once below 25% (centered), stops when healed, and a second Knight's stops when he dies. First run: one check failed because the test's Cleave had already hurt the dummy, so Judgement killed it (no stun); the test now heals it first. Combat test 450/450, stats test 172/172. Headless in-game check of the sandbox: standing by the elite plays its wind-up, the slam hit and the hurt; W then Q play their cast sounds and the haste's apply; killing every enemy plays one pack burst, one death sound and the "Room cleared!" stinger; the Knight at 20% starts the heartbeat, and his death stops it and plays the "You died" stinger. `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors or warnings.

### A2 – Combat sounds with placeholders: 2026-09-27, Passed
**A2 – Combat sounds with placeholders.** AttackSwing and HitFeel hooks, crit layer, dash, player hurt, shield absorb, enemy death and pack burst, the Events listener (CombatSounds).

`CombatSounds` (`scripts/audio/combat_sounds.gd`, a child of Audio); `AttackSwing.swing_sound` / `hit_sound` / `sound_pitch`, played at swing start by `AutoAttackComponent.try_swing()`; `HitContext.hit_sound` and `hit_sound_pitch` (new; the swing's pitch reaches its hit sound too), filled by `HitPipeline.basic_attack()`; `HitFeel.light_sound` / `heavy_sound` / `kill_sound` / `crit_sound` / `shield_absorb_sound`; `DashComponent.dash_sound`; `Unit.hurt_sound` / `death_sound`; `AudioMix.pack_burst_sound` / `pack_burst_count` / `pack_burst_window`; `Audio.stop_all()` resets CombatSounds. Data: 12 SoundEvents in `data/sounds/`, wired into `combo_knight.tres` (swings 1–2 `sound_knight_swing` at pitch 1.00 / 1.04, the finisher `sound_knight_swing_finisher`, the dash-strike the finisher's at 1.1), `hit_feel_default.tres`, `player.tscn` (dash, hurt), `slime.tscn` (death), `slime_elite.tscn` (`sound_slime_elite_death`: the slime's files at pitch 0.8), `audio_mix_default.tres` (pack burst). No CC0 files had been dropped in, so the 24 placeholder WAVs in `audio/sfx/` are synthesized stand-ins (noise, sines and filters from a Python script; listed in `audio/LICENSES.md` as CC0), under the names AUDIO.md lists.

Fixed while building: `Audio.play_on()` connected `tree_exiting` once per sound with a bound handle, but Godot ignores bound arguments when it checks for a duplicate connection, so a second `play_on()` on the same node failed with "already connected" (10 errors in the combat test, from swings and dashes on the Knight). Audio now keeps one connection per node and a list of its handles; the A1 owner-freed check now plays two sounds on one node.

Audio test 86/86 (24 new A2 checks), three runs in a row: a whiffed swing plays its sound centered at pitch 1.00, swing 2 at 1.04, the finisher its own, no hit sound; the dash is centered; a swing on 5 dummies hits all 5 with one hit sound (centered, HIGH); a crit swing on 5 adds one crit layer; a burn ticking 3+ times is silent; a slime hit on the Knight plays only his hurt (centered, HIGH), a hit into a shield only the shield sound; 3 kills in one frame play one pack burst in that same physics frame, no death sounds, and one kill sound; two deaths 0.2 s apart play two death sounds; deaths a frame apart play two death sounds then the burst, and a 4th inside the window is silent; the elite's death is its own sound, positional; with every sound field empty a hit and a death log nothing. Combat test 450/450, stats test 172/172. Headless in-game check in the sandbox: a chasing slime hitting the Knight plays one hurt sound; 4 swings kill a dummy with 3 swing sounds + the finisher's, 2 light hits, 1 heavy, 1 kill and 1 splat. `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors or warnings. Quitting in the middle of a sound prints Godot's leak warnings at exit (AUDIO.md, Godot behavior); not new errors in play.

**Passed** (Ryan's play test, 2026-09-27; merged to main). Ryan's follow-up commit removed `[audio] general/2d_panning_strength=0.5` from `project.godot` (the editor drops settings equal to their default); pan strength is still 0.5.

### A1 – Plumbing: 2026-09-27, Passed
**A1 – Plumbing.** Bus layout, SoundEvent, AudioMix, the Audio autoload (limits, priority, voice cap, real time, pause behavior, `stop_all()`, the log, `debug_draw`), Settings volumes and six pause-menu sliders, `Audio.stop_all()` before the restart, the `audio/` folders, `audio_test.tscn`.

`default_bus_layout.tres` (generated by Godot's own `AudioServer.generate_bus_layout()`: Master 0, Music −8 with a disabled 1200 Hz low-pass, SFX 0, UI −4, Ambience −12, Voice −2 dB), `project.godot` (Audio autoload last, after Settings and Reactions; `audio/general/2d_panning_strength` 0.5 written explicitly), `scripts/data/sound_event.gd`, `scripts/data/audio_mix.gd` + `data/audio_mixes/audio_mix_default.tres`, `scripts/autoload/audio.gd`, `Settings.get_volume()` / `set_volume()` / `get_volume_key()` / `VOLUME_BUSES` (saved as whole percents in `[audio]`), six volume rows in the pause menu (built in code under a new `%Volumes` container), `main.gd` calls `Audio.stop_all()` before `reload_current_scene()`, `audio/sfx|music|ambience/` and `audio/LICENSES.md` (no files yet), `data/sounds/` (empty). The pack burst fields join AudioMix in A2, with CombatSounds.

Audio test 62/62, three runs in a row (tones generated in code: SoundEvent wraps its files in a no-repeat AudioStreamRandomizer with random_pitch 1.05 and ±1 dB, cached and rebuilt when the jitter changes; the six buses, levels, sends, the Music low-pass off, pan strength 0.5; null plays nothing and logs nothing; an empty event is logged `no_audio` each time and warns once; 4 plays in a frame = 3 + 1 `instance_limit`, plays again 0.05 s of real time later, also at time scale 0.05 where one physics frame isn't enough; the Player's sounds centered, an enemy's positional at 480 px with linear falloff, a world sound positional, a non-positional event centered; `play_on()` follows an enemy; a one-shot beyond 480 px is `out_of_range` while a loop starts; `stop()`, `stop_all_on()`, a `play_on()` loop stopping when its node is freed (`owner_left_tree`), `no_owner`; `stop_all()` stops SFX and Ambience but not UI and Music and clears the limit history; with the cap at 4 a LOW and a NORMAL sound are dropped and a HIGH one steals the oldest NORMAL (`by high`); pitch 1.1 × 1.04 = 1.144 at time scale 0.05, `playback_speed_scale` 1; paused: SFX / Ambience / Voice players stop processing (`stream_paused` true), UI and Music keep going, Music −6 dB with its low-pass at 1200 Hz, all back after unpausing; SFX 50% = −6.02 dB and saved as 50, 0 mutes, values round to whole percents; the log keeps `log_size` entries; `debug_draw` lists played and dropped sounds and hides). The test sets the volumes to 100% and restores the saved ones at the end. Two of the first run's checks failed on test timing, not Audio: a SceneTreeTimer made mid-frame is charged that frame's whole delta (it fired after 0 ms), so the test waits on `Time.get_ticks_msec()`; and a `play_on()` position is only updated in Audio's next physics step.

Checked in Godot 4.7.2 (AUDIO.md, Godot behavior): the AudioStreamRandomizer, `max_polyphony`, AudioListener2D and panning names and defaults; the pause behavior of players; the Dummy driver runs streams to their end but reports 0 ms latency, so the real output latency comes from Ryan's machine (the audio test prints it). Not measurable headless: when a 2D sound becomes audible.

Combat test 450/450, stats test 172/172 (unchanged). A headless in-game check of `sandbox_main.tscn`: the pause menu has 6 sliders, the Music slider at 50 sets `Settings` to 0.5 and the Music bus, Resume unpauses. `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors or warnings.

**Passed** (Ryan's play test, 2026-09-27): audio test 62/62 on his machine; output latency 10 ms with WASAPI (15 ms requested). Merged to main.

## Champions (CHAMPIONS.md)

### K2 fix – DoT numbers under 1: 2026-10-05, Passed
K2 passed and Ryan committed it; the tree was clean. His one hiccup: Inevitable Demise's tick numbers showed "0". The damage was right: each tick is 0.3–0.72 at 60 AD (no armor on today's enemies), but the number rounds each tick, and ticks 0.5 s apart don't merge (the merge window is 0.3 s).

- `Unit._spawn_hit_number()`: a DoT tick that isn't merged adds the unit's carry (`Unit._dot_carry`, new) to its amount. Under 1, it shows nothing and the total waits as the carry; at 1 or more it shows as before and the carry goes back to 0. Merging and the shield's number are unchanged; only DoT ticks carry. COMBAT.md, Damage numbers has the rule.
- Tests: the combat test's C6 gets ticks of 0.3 showing nothing, nothing, nothing, "1", nothing. The champions test's Demise run checks that none of the dummy's numbers shows "0", that at least 6 appear and that each shows "1". With the carry switched off, both checks fail; the champions one gets the "0" Ryan saw.
- All suites: stats 180, combat 486, abilities 593, audio 110, champions 238, talents 310, view 469, loot 750, enemies 338 = 3,474/3,474. Saves unchanged.

**Passed** (Ryan's check, 2026-10-05).

### K2 – Q Bladesinger, Blades and Inevitable Demise: 2026-10-04, Passed
K1 passed and Ryan committed it. The tree was clean and no Godot editor was open when the step started; Ryan's editor was open (sandbox_main.tscn) by the end, and every K2 file was checked intact afterwards.

New toolkit pieces (ABILITIES.md, Later toolkit pieces; COMBAT.md, StatusEffect):
- `StatusEffect.StackRule.STACK_SHARED` (appended last, so saved values keep their numbers): an application adds a stack below `max_stacks` and restarts the one timer every stack shares; at max it only restarts it; the stacks end together; the tick clock runs on.
- `StatusEffect.tick_by_stacks` (`Array[float]`): a DoT tick deals its snapshot × entry n − 1 at n stacks instead of × n (the last entry past the end); a multiplier of 0 is no tick at all (no hit, no number).
- `StatusEffect.stat_scalings`: StatScalings added once under `status_<id>` while the status is on (`Unit.add_stat_scaling()`), removed with it.
- `StatScaling.status_tag`, `max_stacks` and the input `self_status_stacks` (the holder's stacks of that tag ÷ max, at most 1; `read_own_input()`).
- `Unit` refreshes its StatScalings when its StatusComponent applies or removes a status (the same deferred refresh as for health; `_mark_stat_scalings_dirty()`).

Her data and script:
- `scripts/abilities/korsavil/bladesinger.gd` and `data/abilities/korsavil_q_bladesinger.tres`: the orbit, then the recast. The `blades` input drives `ad_ratio` (min fraction 7/11) and `projectile_count` (min 0) through ChargeScaling. The recast condition is SELF_HAS_STATUS `blade` ≥ 1, "No Blades". A no-condition bonus adds Demise on each Blade's hit.
- Four statuses in `data/statuses/`: `status_blade`, `status_bladesinger`, `status_inevitable_demise` and `status_umbral_stalker` (its REPLACE comes in K5).
- Her Q slot set in `korsavil.tres`; her passive's text mentions Demise.

**Changed during the step:**
- `StatusComponent._sync_modifiers()` now swaps the exact per-stack copies it added (`ActiveStatus.mods`, through `StatsComponent.replace_modifiers()`) instead of removing everything under `status_<id>` and adding again. The old way would have wiped a status's StatScaling copies (same source id) on every stack change. Behavior is otherwise the same; a stack change now fires `stat_changed` once instead of a dip and a rise. This replaces working code without asking first (the change policy): Ryan's call to keep it or to give status scalings their own source id instead.
- The Blade gain is read from the orbit's own time left each physics frame, a coroutine `execute()` doesn't await, so hitstop and the pause hold it like any status timer.

Measured (champions test):
- **The orbit:** the first Blade lands 60 physics frames into it. One Blade: damage taken × 0.95, speed 409.5. Four Blades: × 0.8 and 468, and a 100 physical hit takes 80. At 6 s the orbit and its window end together, the Blades stay and her stats go back. The recast at 0 Blades fails with "condition" / "No Blades" and the window keeps running.
- **The recast with 4 Blades:** four dummies 30° apart each take one Blade for 66 raw, gain one Demise stack from her, and Umbral Stalker goes on (10 s). With 2 Blades, two fly ±15° for 54 each, and no Stalker.
- **Demise:** no tick at 1 stack; ticks of 0.3 / 0.3 / 0.48 / 0.48 / 0.6 / 0.6 / 0.72 at 2–8 stacks (1% of 60 AD × the table), PHYSICAL, from her. A 9th Blade keeps 8 stacks and restarts the 5 s; all 8 end together 300 frames later.
- **Toolkit (combat test):** STACK_SHARED, the tick table (0 → no tick, past the end → the last entry), and scalings following another status's stacks, which survive the holder's own stack changes and go with it.
- **Smoke run:** a sandbox run as Korsavil: 2 Blades at 2.5 s (× 0.9, 429 speed), the recast spends them, no errors; saves byte-identical (saving off).

**Passed** (Ryan's play test, 2026-10-05; he committed it): he keeps the `_sync_modifiers()` change. One hiccup, Demise's tick numbers showing "0", is fixed above (K2 fix).
- **Sensitivity:** breaking the shared timer, the tick table, the status refresh or the `blades` input each fails its checks.

Ryan's progress.cfg changed during the step (23:45, his own play: a [korsavil] record with 6 kills and 30 XP, and more Knight casts and kills); no test writes saves.

Champions 237/237 (36 new), combat 485/485 (11 new); stats 180, abilities 593, audio 110, talents 310, view 469, loot 750, enemies 338: all 3,472/3,472, every suite clean at exit.

### K1 – Korsavil: data, loading, her 3-swing cycle and the champion pick: 2026-10-04, Passed (Ryan committed it)
Ryan's play test of ENEMIES_AI AI3d passed, so Korsavil's build started (Ryan, 2026-10-04: right after it, before AI3b and AI3c). The tree was clean (checked with `git status`) and no Godot editor was open.

New:
- `data/units/korsavil.tres`: Ryan's placeholders (500 health, 60 AD, 0.7 attack speed, 390 move speed, 150 range, 0.25 crit; Energy 100 at 10 a second), plus the Knight's `pickup_radius` 200 so she picks up loot.
- `data/combos/combo_korsavil.tres`: the 3-swing cycle (windups 0.06 / 0.06 / 0.08 s, roots 0.22 / 0.22 / 0.32 s, 0.9 / 0.9 / 1.4 × AD, arcs 90 / 90 / 120°, a 0.2 s breather after the finisher; the Knight's knockback and steps) and the dash-strike (1.3 × AD, the Knight's thrust shape). Swing 3 has `hit_tags` [`finisher`].
- `data/champions/korsavil.tres`: `korsavil` / "Korsavil" / `assassin`; ENERGY, starts full, no decay; empty Q/W/E/R; the passive inline (display name "Passive (name TBD)"), holding only the FLAT +1 `dash_charges`; no talents or named items; the shared leveling; no model (a capsule).

Changed (additive):
- `AttackSwing.hit_tags` (`Array[StringName]`, empty by default); `HitPipeline.basic_attack()` adds them to the swing's hits. COMBAT.md's per-swing hit tags, built.
- `Progress.picked_champion`: the hub's pick, kept for the session and never saved.
- `main.gd`: gives the Player it spawns the pick before the Player loads it (null = player.tscn's Knight).
- `hub.gd`:
  - `champions` (the Knight, Korsavil) and a pick row (`ChampionPick`, a toggle button per champion), with `pick_champion()`.
  - On load the hub shows Progress's pick.
  - The header, the talent screen and the debug tools follow the pick.
  - A champion with no talents gets the detail line "Korsavil has no talents yet."

**Changed during the step:**
- Her swings reuse the Knight's swing and finisher sounds as placeholders (pitched up a little); CHAMPIONS.md had "sounds: none yet". The swing sound is the combo's, not a champion sound field.
- The Knight's combo is unchanged: his finisher's hits carry no `finisher` tag (nothing reads it for him).

Measured:
- **Loading:** she loads with one dash charge and has both 0.35 s later (the passive attaches after `Unit._ready()`).
- **Energy:** regenerates 50 → 60 in 60 physics frames.
- **Swings:** a press on an empty slot casts nothing. Her three swings deal 54 / 54 / 84 raw on a dummy (crit off), all tagged `melee`, only the third tagged `finisher`.
- **Hub:** picking her shows "Korsavil   Level 1: 0 / 600 XP   Talents 0 / 1" and an empty talent screen. A new hub keeps the pick. +100 uses with her empty slots counts nothing and raises no error.
- **Smoke run:** with her picked, `sandbox_main.tscn` and `main_layout.tscn` each ran 240 frames with no errors: 500 health, 60 AD, 390 speed, 100 / 100 Energy, 2 / 2 dashes, empty slots. The real saves were byte-identical after (saving off).
- **Sensitivity:** removing the tag loop fails the swing check; not storing the pick fails both hub checks.

Champions 201/201 (33 new); stats 180, combat 474, abilities 593, audio 110, talents 310, view 469, loot 750, enemies 338: all 3,425/3,425, every suite clean at exit (the swing check stops its finisher's hit sound first).

### Milestone CH-M – the Knight's kit: 2026-09-30, Passed
Ryan's play test in the sandbox of the whole loop (Fury from swings, Lunge → Staggered → Cleave, Judgement at 60+ Fury, a low-health fight on Cleave's missing-health heal) passed, together with CH5b. The Knight's numbers stop being placeholders (CHAMPIONS.md); later tuning is data edits.

### CH5b – Cleave's heal from missing health: 2026-09-30, Passed
Ryan's change before CH-M: Cleave heals a share of the Knight's missing health once per Cleave that hits, not a share of the damage dealt. New: `Ability.heal_missing_health_ratio` (export group "Sustain", a scoped param), `HitContext.heal_missing_health_ratio` and `HitContext.cast` (set by `from_ability()` with a cast), `CastContext.missing_health_healed`, the once-per-cast heal in `apply_on_hit()` (ratio × missing health on the cast's first hit that gets through). Data: Cleave and Cleave Wave move their 0.55 and its `self_missing_health` scaling (the same curve) to the new field; `heal_on_hit_ratio` is back to 0 on them; their tooltips say "Each cast that hits heals you for up to 55% of your missing health, more the lower your health."

**Changed during the step:** the champions test's CH5 checks were rewritten for the new rule (plus one check that the damage-based field still works on a test copy); the abilities test's Cleave tooltip text updated.

Measured (champions test): one Cleave that hits heals 0 / 26.0 / 73.1 / 321.75 at 100 / 50 / 25 / 10% health; into three slimes at 10%: three hits, one heal, the same 321.75; into the air: nothing; a killing blow heals 321.75 at 10%; a blocked hit heals nothing; a 100% test ratio at max health heals nothing; pressed at full health and hit to 10% during the cast time: 55% and 321.75; `heal_on_hit_ratio` 0.5 on a test copy heals half the damage taken by both enemies.

Champions 168/168, abilities 559/559, stats 179/179, audio 109/109. Combat 456/459: the two real-time hitstop checks, plus "over by 0.10 s, time back to normal", the third real-time hitstop check that also failed on the pre-CH1 baseline run. `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors.

### CH6 – Readable kit (functional HUD): 2026-09-30, Passed
New: `scripts/ui/passive_slot.gd` (`PassiveSlot`: a slot left of Q with the passive's initials, a hover tooltip with the name, "[Passive]", "Always active", the description and one gold "Now:" line per stat scaling; `get_tooltip_lines()`), added by `hud.setup_abilities()` only for a champion with a passive; `Passive.icon_color` (Unbroken: a warm orange); `ResourceBar.get_thresholds()` / `is_glowing()` (a tick at every `RESOURCE_AT_LEAST` in the slotted abilities, a bright outline at or above one); `AbilityBar.has_live_bonus()` (a gold outline outside a slot while a bonus with only caster-side conditions passes). Placeholder look only.

**Changed during the step:** nothing beyond the spec.

Measured (champions test): the passive slot sits left of Q, one 4 px gap away, 30 × 30, in the same row; its tooltip reads "Unbroken", the description and "Now: +0% attack damage" at full health, "+29%" at 50%, "+40%" at 20%; the Fury bar's thresholds are [60], no glow and no live bonus on R at 0 Fury, both on at 60, both off at 59; Q (a target condition), W and E never show a live bonus; a champion without a passive or thresholds gets no passive slot, no ticks, no glow and no outlines. Not checked by a test: the look and the mouse hover itself (headless runs have no mouse); Ryan's play test covers them.

Champions 168/168 (14 new), abilities 559/559, stats 179/179, audio 109/109. Combat 457/459: the same two real-time hitstop checks. `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors.

### CH5 – Cleave's heal on hit: 2026-09-29, Passed
New: `Ability.heal_on_hit_ratio` (export group "Sustain", a scoped param), `HitContext.heal_on_hit_ratio` (set by `from_ability()` with a cast through `get_effect_param()`), `apply_on_hit()` adds ratio × `taken_damage` to the source's heal (one `Unit.heal()` per hit, with `life_on_hit` and `life_steal`), `AbilityComponent._refresh_effect_inputs()` (reads `self_missing_health` again at the effect start). Data: Cleave and Cleave Wave `heal_on_hit_ratio` 0.55 with a ChargeScaling on `self_missing_health` (min 0, `data/curves/curve_knight_cleave_heal.tres`) and a tooltip line ("Heals you for up to 55% of the damage dealt, more the lower your health").

**Changed during the step:** nothing beyond the spec; the abilities test's Cleave tooltip check now includes the heal sentence. The CH6 step (functional HUD) was written into CHAMPIONS.md before the build, at Ryan's request.

Measured (champions test): the heal share at 100 / 75 / 50 / 25 / 17.5 / 10 / 5 / 0% health is 0 / 3 / 8 / 15 / 35 / 55 / 55 / 55%; one Cleave at full health heals 0, at 50% 11 (8% of its damage), at 10% 78.5 (55%) into one slime; into three slimes at 10% three equal hits (Unbroken doesn't move between them), the same ratio each, the sum healed (between a quarter and 45% of max health); a killing blow on a 10-health slime heals ratio × the full taken damage; a 100% test ratio at max health heals nothing and never overheals; pressed at full health and hit to 10% during the 0.2 s cast time, the hit's ratio is 55%.

Champions 154/154 (19 new), abilities 559/559, stats 179/179, audio 109/109. Combat 457/459: the same two real-time hitstop checks. `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors.

### CH4 – Staggered, the combo and Judgement's payoff: 2026-09-29, Passed
New: `data/statuses/status_staggered.tres` (tags `staggered` + `debuff`, not cc, 2 s, REFRESH) with its marker (`scenes/vfx/staggered_mark.tscn`, `scripts/vfx/staggered_mark.gd`: a pale yellow cracked ring over the head). Data: Lunge's conditional bonus (no conditions, applies Staggered); Cleave's and Cleave Wave's (TARGET_HAS_STATUS staggered: base_damage and ad_ratio +50%); Judgement's (RESOURCE_AT_LEAST 60: stun_duration +0.5 s, base_damage and ad_ratio +30%), its 0.75 s channel (was 1.5) and 30 s cooldown (was the 5 s default). `judgement.gd`: `stun_duration` through `get_effect_param()`, and `consume_resource_on_bonus` (a landed hit with the Fury bonus spends the whole pool).

**Changed during the step:** Cleave Wave got the Staggered bonus (Ryan's answer to Open question 8: the same as Cleave). The abilities test's 300 test pool and the combat test's swings reached 60 Fury, so their plain Judgement checks now stay below it (`_below_fury_bonus()`; the combat baseline removes the Knight's Fury from swings, and its C8 on-hit check leaves the pool empty, not full); tooltip checks compare the template line only, since the Knight's tooltips now end with their bonus lines; the AB14 progress check reads Judgement's cast time (15 of 45 frames) instead of pinning 90 (DECISIONS, Testing).

Measured (champions test): Lunge staggers both enemies on its path and not one beside it, for 2 s, from the Knight, with the marker (gone when it runs out); Cleave's taken damage on a Staggered enemy is exactly 1.5x a plain one's in the same swing, and Staggered stays; the tooltips list the three bonus lines; Judgement at 59 Fury: 0.75 s stun, Fury kept; at 70: 1.25 s stun, exactly 1.3x the damage (the dummy at full health), Fury 0 after the hit; the 30 s cooldown starts; 60 Fury at the press, decayed below 60 during the channel (out of combat): no bonus.

Champions 135/135 (26 new), abilities 559/559, stats 179/179, audio 109/109. Combat 457/459: the same two real-time hitstop checks. `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors.

### CH3 – Fury: 2026-09-29, Passed
New: `ResourceComponent.starts_empty`, `decay_per_second`, `decay_delay`, `get_time_since_combat()`, `is_in_combat()` (a combat clock reset by `Events.unit_hit` for a hit the unit dealt or took that got through); `ChampionData.resource_starts_empty` / `resource_decay_per_second` / `resource_decay_delay`, `modifiers` and `get_champion_source_id()`; `Player._attach_champion()` (the champion's modifiers under `champion_<id>`, then the passive); `HitPipeline.apply_on_hit()` reads `resource_on_hit` through `get_scoped_stat()` with the hit's scopes. Data: the Knight's ChampionData is FURY, starts empty, decays 20/s after 3 s, `resource_on_hit` +8 scoped `hit:basic_attack`; `units/knight.tres` max 100, regen 0 (was 300, 6/s); Cleave `resource_cost` 20; `sandbox.tscn` `demo_costs` off (the demo code stays).

**Changed during the step:** the stats, abilities and combat tests pinned the 300 mana placeholder and a free Cleave. They now test the machinery on a pool they set up (DECISIONS, Testing): the stats test's pool checks add a 300 / 6/s test pool and its data checks read 100 / 0; the abilities test's baseline (`_pool_baseline()`) gives the Knight a plain 300 pool, 6/s, full, no decay, no Fury from swings, and cancels Cleave's cost; the combat test's baseline cancels Cleave's cost. Four CH1 checks in the champions test now expect FURY, 100 and an empty start.

Measured (champions test): the Knight loads at 0 / 100 Fury; one swing through three dummies gives 24 (8 each); no decay for 3 s after the last hit (unchanged at 2.8 s), then 20/s of game time down to 0, never emitting `depleted`; taking a hit restarts the 3 s and builds nothing; Cleave at 19 fails with "not enough resource", at 20 casts and pays 20 at cast start; Cleave's and Lunge's hits build nothing; Iron Resolve, Lunge and Judgement can cast from 0; a +50 max_resource item leaves an empty-start pool at 0 / 150.

Champions 109/109 (27 new), abilities 559/559, stats 179/179, audio 109/109. Combat 457/459: the same two real-time hitstop checks. `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors.

### CH2 – The passive framework and Unbroken: 2026-09-29, Passed
New: `Passive` (`scripts/data/passive.gd`: modifiers, stat scalings, reaction rules, statuses, augments; `apply_to()` / `remove_from()` by source id; `_on_added()` / `_on_removed()` for a one-off script), `StatScaling` (`scripts/data/stat_scaling.gd`: a modifier, an input, a curve; `get_value()`, `read_input()`), `Unit.add_stat_scaling()` / `remove_stat_scalings_from()` / `get_stat_scalings()` (refreshed once per frame on `health_changed`, deferred after the frame's hits), `StatsComponent.replace_modifiers()`, `ChampionData.passive` and `get_passive_source_id()`, the attach in `Player._ready()` after `Unit._ready()`. Unbroken inline in `data/champions/knight.tres` (attack_damage PERCENT_ADD +0.40 on `self_missing_health`), `data/curves/curve_knight_unbroken.tres` (linear to full at 70% missing, flat after).

**Changed during the step:** the refresh swaps each moved copy through the new `StatsComponent.replace_modifiers()` instead of "remove the source's copies, add them again" (that would also remove a passive's plain modifiers under the same source id and fire a dip and a rise; DECISIONS, Champions). The combat test's baseline (`_zero_knight_extras()`, which already zeroes the Knight's crit and life steal) now also removes his passive: 7 exact-damage checks run after the Knight has taken damage and saw Unbroken's AD (DECISIONS, Testing).

Measured (champions test): the Knight's AD is 64 at full health, 73.14 at 75%, 82.29 at 50%, 89.6 at 30% and at 10%, back to 82.29 and then exactly 64 when healed; unchanged in the frame the health changes (refreshed after its hits); one `stat_changed` per refresh, even for two health changes in one frame, and none when the value doesn't move; a +350 max health item re-evaluates it (675 / 1000 health: 75.89 AD). Removing the passive at 30% health gives 64 at once and every live stat equal to a Knight without it; attaching it again gives 89.6 at once. A test passive with a modifier, a scaling, a rule, a status (duration −1) and an augment attaches and detaches with every stat restored.

Champions 82/82 (37 new), abilities 558/558, stats 179/179, audio 109/109. Combat 457/459: the same two real-time hitstop checks as before CH1. `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors.

### CH1 – ChampionData and the Knight's migration: 2026-09-29, Passed
New: `ChampionData` (`scripts/data/champion_data.gd`: id, display name, `champion_class`, stats, resource type, Q/W/E/R, combo, hurt / death / low health sounds, `champion_level` 1, `champion_xp` 0), `data/champions/knight.tres` pointing at the Knight's existing files, `ResourceComponent.ResourceType.NONE` (appended last, so saved MANA / ENERGY / FURY values keep their numbers), `Player.champion` and `Player._apply_champion()` (before `Unit._ready()`), `player.tscn`'s `champion` set to the Knight. The scene's old exports stay (the same values) until the play test confirms CH1. Test: `scenes/tests/champions_test.tscn`.

**Changed during the step:** the Knight's ChampionData keeps `resource_type` MANA, as the scene had, until CH3 switches it to FURY (FURY now would have turned the bar red with nothing behind it); the `resource_*` rhythm fields move to CH3 with the ResourceComponent fields they map to (DECISIONS, Champions). **Found while building:** a Player's `@onready` shortcuts (`abilities`, `attack`) are null before it enters the tree, so code that sets its exports before adding it goes through the nodes (CHAMPIONS.md, Loading a champion).

Champions test 45/45: the Knight's .tres, player.tscn loading it, the loaded Knight identical to the scene's own exports (stats, slots, combo, sounds, resource type, every live stat, each slot's cost and cooldown), a Player with no champion using its exports, another champion's data replacing every field (and its Q castable), NONE removing the pool (no node, costs affordable, no resource bar on the HUD), the level fields never read or changed. Abilities 557/557, stats 179/179, audio 109/109. Combat 457/459: the two real-time hitstop checks ("a shorter one changes nothing", "heavy feel: 0.06 s hitstop") fail the same way on the last commit without CH1 (baseline run, 2 of 2), so they're this machine's timing, not CH1. `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors.

## Combat (COMBAT.md)

### Damage numbers stack: 2026-10-03, Built (awaiting play test)
Ryan saw hits pop "duplicate" numbers after P7's check.
- **Verified:** every hit makes exactly one number, in 3D and in the 2D game alike (scratch harnesses listed every Label). Two cases read as duplicates:
  - The combo's equal swings: two 64s, the second starting 9 px under the first, which is still fading. 9 px in 2D too.
  - Cleave hitting three dummies with one crit roll: three "218!", one over each dummy.
- **Ryan's answer: stack them** (he'll revisit numbers with UI.md).
  - New `DamageNumberStyle.stack_step_px` (11) and `stack_levels` (4); `Unit._stack_lift()`.
  - A unit's new number starts one step above its previous number while that one still shows (its `lifetime`), up to 4 high, then at the bottom again. The 2D path and `ScreenOverlay.add_number(n, unit, lift_px)` both apply it.
- **Tests:** combat_test 462 (2 new: five hits in a row start 11, 11, 11 px apart, then at the bottom again; and at the bottom once the numbers are gone); view_test 1 new (the overlay stacks the same way).

### Cleanup pass (audit fixes): 2026-09-29, Built (awaiting play test)
- **`combo_knight.tres` `speed_scale` 1.266 restored** (Ryan's tuning from commit 5f7f0ae, 2026-09-26). The AB1 commit (7217b5e) removed it, unlogged, because 4 combat checks failed with it (AB1's entry, "Combat test 446/450"). What was wrong with the tests: (1) they pinned the tuning value: the data check expected `speed_scale` 1.0, the swing-length check expected 0.3 s (18 frames), and the attack-speed checks expected a combo speed of 1.0 and 1.5 and a 12-frame swing; (2) the combo-pace check set the shared `combo_knight.tres` resource's `speed_scale` to 2.0 and then "restored" it to a hard-coded 1.0, so every combo check after it ran at 1.0 whatever the data said (the 1.266 tuning was never tested past that point). Fixed: the data check pins 1.266; timing checks derive from the combo's own `speed_scale` (`_swing_frames()`: a 0.3 s swing is 15 frames at 1.266); the combo-pace check puts back the value it found. Every later combo check (dash-strike, melee step, cancels, hit feel...) now runs at 1.266 and passes.
- **League-style enemy attacks go through `HitPipeline.resolve()`** (`AutoAttackComponent.make_attack_context()`: 1.0 × AD, PHYSICAL, `basic_attack`, can crit, feel NONE, the push; empowers through `add_empowers()`), so the attacker's `damage_increase`, crit and `hit:` / `target:` scopes apply. No regression in the existing enemy numbers: the slime's 22 and 12 px push, the elite's 30, the slam's 100, the League-style empower (+10), the shield and i-frame checks all unchanged.
- **Deleted** (approved, references checked first): `HitContext.highlight` and the `highlight` parameter of `take_damage()` / `make_hit_context()`, `HitContext.knockback_curve` (nothing set it; the push uses the target's `knockback_curve`), `AutoAttackComponent.is_attacking()`, `swing_finished`, the old `_next_attack_mods` dictionary path (AB10 passed), `Hurtbox.is_invincible()` / `set_invincible()`, the `StunEffect` fallback (`stun_effect.gd` and its branches in `Unit`; C9 passed), `hud.gd`'s `HEART_EMPTY`, `game/test.tscn` (an empty scene nothing referenced).
- The player's Hurtbox `invincibility_time` is 0.2 s (the script default; `player.tscn` had 0.0 since the first commit, not a reverted value). No scene has a Hitbox yet, so it changes nothing in play. Pending Ryan's play test.
- `combat_test.gd`: the Iron Resolve empower is cleared with `remove_status(AutoAttackComponent.get_empower_status_id(&"iron_resolve"))` instead of a 0-damage `add_next_attack_modifier()` call; the `select` check now checks the action is gone.
- Stale comments fixed in `hit_pipeline.gd`, `unit.gd`, `auto_attack_component.gd`, `dash_component.gd`, `movement_component.gd`, `hud.gd`, `gameplay_effect.gd`, `cast_context.gd`, `ability_util.gd`, `pause_menu.gd`, `game_camera.gd` (now `class_name GameCamera`; "Hold C", not Space), `player_input.gd`, `ability.gd`, `stats_component.gd` and the three test headers.
- Docs: negative armor / magic_resist is a core rule (COMBAT.md, STATS.md); the reaction trigger count is 8 in the enum, 4 built, the same in COMBAT.md, CONVENTIONS.md and WORLD_INTERACTION.md; COMBAT.md's C9 haste example is 375 → 506.25.

Combat test 459/459 (8 new: 7 for the enemy hit through the pipeline (plain 22; +50% `damage_increase` 33; +50% on `hit:basic_attack` 33; on `hit:ability` only 22; 100% crit 38.5; crit scoped to `hit:basic_attack` 38.5; the HitContext's fields) and `get_attack_interval()` moved here from the stats test). Full suite: stats 179/179, combat 459/459, abilities 503/503, audio 109/109 (was 172 / 451 / 494 / 109 before the pass). `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors or warnings.

### Tests for the Knight's new stats: 2026-09-28, Built (awaiting play test)
`knight.tres` (Ryan, commit 45d3457): `move_speed` 375 (was 560), `crit_chance` 0.25, `life_steal` 0.01. Checks written for the old numbers failed in every suite: abilities 5–8 (crit-dependent, varying per run), combat 30, stats 14, audio 1. Updated: the combat, abilities and audio tests add a test baseline on the Knight (source `test_baseline`: FLAT minus the base `crit_chance` and `life_steal`), so exact-number checks aren't random and checks that add crit get exactly what they add (the abilities test's AB13-only no-crit modifier is gone); a new combat check pins the real 0.25 and 0.01 and the baseline's 0. Move speed checks now use 375: the Iron Resolve haste 375 → 506.25 (combat, abilities); stats: base 375, the 50% slow 272.25 and the 30% slow 309.75 (both under the low soft cap now), the haste check raised from +50% to +150% so it still reaches the high caps (937.5 → 842.05, with a 20% slow 750 → 734.8), no soft caps 375, the speed-modifier wrapper 412.5 / 450 / 467.5 / 309.75. Docs: MOVEMENT.md (speed, examples, an open question on the soft caps), STATS.md, ABILITIES.md (the walking-while-casting examples), DECISIONS.md (one row).

Abilities test 467/467, combat 451/451 (both twice in a row), stats 172/172, audio 109/109, with the current `knight.tres`. `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors or warnings.

### Cleanup – the pre-C6 damage number path: 2026-09-28, Passed
C6 passed, so its old number path goes (disabled in practice since C6: nothing called it). Deleted `Unit._spawn_damage_number()` and `damage_number.gd`'s `big` field with its `_pick_font_size()` branch (only that function set it, by name). Checked first: no script, scene, resource or test referenced either. `HitContext.highlight` stays (take_damage, empowered hits and projectiles set it; two tests check it); its comment and `Unit.take_damage()`'s now say numbers don't read it. Abilities test 398/398, combat 449/450 (the known flaky real-time "heavy feel: 0.06 s hitstop" check), stats 172/172, audio 109/109; `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors.

**Passed** (Ryan's play test, 2026-09-28). (`HitContext.highlight` itself was deleted 2026-09-29, see the cleanup pass above.)

### A swing counts once its hit has landed: 2026-09-27, Built (awaiting play test)
**Rule change** (Ryan, 2026-09-27; COMBAT.md, Basic attack): every cancel the player chooses after a swing's hit has landed (walking, a dash, an ability cutting the recovery) keeps the combo; the index advances as if the swing had finished and `combo_reset_time` counts from the cancel. Windup cancels and forced interruptions (stun, death) still reset it. Planned first, then built as its own small step.

`AutoAttackComponent.cancel_swing(keep_combo_if_landed = false)` and `_get_index_after_swing()` (shared with `_finish_swing()`); `DashComponent.try_dash()` passes true; `add_lock()` passes it only for the casting lock (`CASTING_LOCK`). Walking needed no change (it only ends the root; the swing still finishes). Combat test 450/450: 2 C2 checks updated (a dash or a Q in the recovery now leaves swing 2 next instead of swing 1) and 11 new checks (hit, dash in the recovery, click: swing 2; dash in the windup, click: swing 1; right after the dash swing 2 is next and 0.75 s later swing 1; a finisher dashed out of after its hit keeps its breather and swing 1 is next; dashing out of a landed dash-strike leaves the interrupted swing next; swing 1 hits, Q (AFTER_HIT) cuts its recovery, a click gives swing 2; an ANYTIME Q in swing 2's windup resets to swing 1; a stun after the hit still resets). Stats test 172/172; headless in-game check 43/43; `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors.

### C12 – Dash-strike: 2026-09-27, Built (awaiting play test)
**C12 – Dash-strike.** Decided in an interview first (DECISIONS.md, Combat): its own strong swing per champion, doesn't count as a combo hit, the Knight's 1.5 × AD with a 16 px step (other classes in CHAMPIONS.md), window 0.15 s.

`combo_knight.tres` gets a `dash_strike` swing (1.5 AD, 16 px step / 32 px pull, heavy feel, 0.35 s, 80° thrust, reach × 1.15, 16 px push, no breather); `AutoAttackComponent` runs it with index −1 (`is_dash_strike()`), tags its hits `dash_strike`, and resumes the combo where it was when it ends; `PlayerInput.dash_strike_window` 0.1 → 0.15 s; the Player's slash uses the finisher look for it. Combat test 439/439 (14 new C12 checks: the swing's numbers and the 0.15 s window; index −1 and `is_dash_strike()`; a 16 px step in the air; 96 damage tagged `basic_attack` + `dash_strike` with the heavy 0.06 s hitstop; a normal swing isn't tagged; through PlayerInput a click during the dash and one 0.13 s after it are dash-strikes, one 0.23 s after is a normal swing; swing 1, dash-strike, swing 2, dash-strike, swing 3 deal 64 / 96 / 64 / 96 / 102.4; after a reset it leaves the combo at swing 1; a cancelled dash-strike resets the combo). Stats test 172/172; headless in-game check 43/43; `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors. Left open for Ryan: a dash out of a landed swing's recovery still resets the combo (C2 rule; COMBAT.md, Open questions).

### C11 – Reaction rules: 2026-09-27, Built (awaiting play test)
**C11 – Reaction rules** (`HIT`, `UNIT_DIED`, `STATUS_APPLIED`; the four GameplayEffects). Decided in an interview first (DECISIONS.md, Combat): world rules and unit rules; chain length set per rule (`chain_limit`), capped at 5; system only, plus one sandbox demo.

`ReactionRule` (`scripts/data/reaction_rule.gd`; new fields `id`, `required_status_tags`, `effect_target`, `owner_role`, `chain_limit`, `MAX_CHAIN` 5), `GameplayEffect` and `ApplyStatusGameplayEffect` / `DealDamageGameplayEffect` / `KnockbackGameplayEffect` / `HealGameplayEffect` (`scripts/data/`), the `Reactions` autoload (`scripts/autoload/reactions.gd`: world rules from `data/reactions/world/` (empty) and `add_world_rule()`, unit rules from `Unit.add_reaction_rule()`, seedable `rng`, `get_chain_depth()`), `HitContext.target_tags` (the target's status tags before the hit). Demo: `data/reactions/reaction_shatter.tres` given to the player only in `sandbox.tscn` by a `SandboxReactions` node (`scripts/rooms/sandbox_reactions.gd`). Combat test 425/425 (26 new C11 checks: the Shatter data; no world rules and no rules on the Knight outside the sandbox; Shatter adds exactly one 30 MAGIC `shatter` proc to a swing on a stunned dummy, none on an unstunned one, none on Judgement's own stunning hit, one on the next Cleave, none once removed; "when I'm hit, heal" (AFFECTED) fires, a SOURCE rule on the one hit doesn't; "when I hit, heal me" (effect target OTHER); "on kill, heal me 20"; "kill a slowed enemy" reads the tags from before the hit although death clears them; a world "burning also slows" rule ignores a haste, slows for 0.8 s from the burn's applier, and removing it works; "on crit" fires only on crits; chance 0.5 fires 195 of 400 (seeded); chance × proc coefficient 0.25 fires 97 of 400 Cleaves; a DoT tick never triggers HIT rules; a self-re-applying rule gives 1 / 3 / 5 / 5 reactions at chain_limit 1 / 3 / 5 / 9 and the chain depth returns to 0; DealDamage 10 + 0.5 AD = 42 MAGIC proc that can't crit; ApplyStatus 0.5 s from the source; Heal 10 + 1% max = 62.8; Knockback 20 px away from the source). Two first-run test bugs fixed (the recorder hears the proc before the hit because Reactions listens first; 400 hits killed the chance dummy). Stats test 172/172; headless in-game check 43/43 twice (the sandbox Knight has exactly the Shatter rule and a swing on a stunned dummy deals 64 + 30; the room_01 Knight has no rules); `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors.

### Telegraph fix – a caster that dies mid-cast: 2026-09-27, Passed
**Fix – Telegraph on caster death** (before C11; COMBAT.md, Known bugs).

Reproduced first in Godot 4.7.2 headless: the sandbox-style elite killed 0.1 s into its slam was freed by its death tween (0.33 s) before the 0.65 s cast time ended, its waiting `_do_cast()` never resumed (no error printed), and the telegraph was still on the floor, full, 2 s later. Fix: `AbilityComponent.interrupt_cast()` (new), called by `Unit._on_died()`: during the cast time it frees the telegraph, releases the cast's locks, refunds the cooldown for a living caster and emits `cast_finished`; a `NOTIFICATION_PREDELETE` guard frees the telegraph when a caster is freed without dying. `_cancel_cast()` and the cast flow are unchanged. Combat test 399/399 (12 new checks: killed 0.1 s in, the cast ends at once with one `cast_finished` and the telegraph is gone the next frame, nothing left after the elite is freed, no slam lands; killed 0.5 s in, the telegraph goes at once and `cast_finished` still fires only once after the cast time passes; freed mid-cast without dying, the telegraph goes with it; `interrupt_cast()` on a living caster refunds and removes the telegraph, and does nothing with no cast running). 8 of the 12 fail on the old code. Stats test 172/172. Headless sandbox check: the real `Elite1` casts on its own after 18 frames, is killed 4 frames in, its circle is gone 2 frames later and none are left 1.5 s later. `main.tscn` and `sandbox_main.tscn` run 300 frames with no errors.

**Passed** (Ryan's play test, 2026-09-27): telegraphs are removed when their caster dies. Merged to main.

### C10 – Shields: 2026-09-27, Built (awaiting play test)
**C10 – Shields** (shield statuses; absorb order: the one expiring soonest first, proposed).

`StatusEffect.shield_amount`, `StatusComponent.absorb_damage()` / `get_shield()` / `get_total_shield()`, `Unit.on_hit` takes shields before health, the shield number (`DamageNumberStyle.shield_color`, `DamageNumber.Kind.SHIELD`), `data/statuses/status_shield.tres`. Combat test 387/387 (23 new C10 checks: 80 into a 100 shield is all absorbed with one silver "80"; the next 80 splits 20 / 60 with two numbers and ends the shield; absorbing happens after armor; TRUE damage is absorbed; a fully absorbed hit can't kill; three shields empty soonest-expiring first, "until removed" last; stacked shields empty per stack; REFRESH_LONGER keeps the bigger shield; a swing into a shield still life-steals 32 and pushes; an absorbed hit still applies its statuses; a DoT tick is absorbed with a small shield number; a slime hit on a shielded Knight costs no health and still starts i-frames). Stats test 172/172; headless in-game check 40/40 on the third run: two runs each had a different timing miss (the slime hit, the elite circle), and the same elite miss shows up on the pre-C10 code (1 in 4 runs), so the throwaway check is flaky, not C10; room_01 and the sandbox run with no errors.

### C9 – Statuses: 2026-09-27, Built (awaiting play test)
**C9 – Statuses.** `StatusComponent`, `StatusEffect`, `status_stun` / `status_slow` / `status_haste`, the `apply_stun()` and `add_speed_modifier()` wrappers, tenacity, DoT with kill credit.

`StatusEffect` (`scripts/data/status_effect.gd`), `StatusComponent` (`scripts/components/status_component.gd`, on `player.tscn` and `slime.tscn`), `data/statuses/status_stun.tres` (cc / stun / debuff, blocks all four, REFRESH_LONGER, the stars VFX `scenes/vfx/stun_stars.tscn`), `status_slow.tres` (cc / slow / debuff, −30%, REFRESH, 1.5 s), `status_haste.tres` (haste / buff, +20%, REFRESH, 2 s); `Events.status_applied` / `status_removed`; the two wrappers; `HitContext.statuses` applied by `on_hit`. Combat test 364/364 (42 new C9 checks: the three status files; a stun blocks move / swing / cast / dash with the stars, keeps the longer time and ends after 1.0 s of game time; Judgement's stun is 0.75 s with the Knight as source; 50% tenacity halves the stun and a slow but not a haste or a burn; Iron Resolve is a 2 s `iron_resolve` haste at 739.6 speed, back to 560 after; a slow's same id replaces it, `remove_speed_modifier()` and "until removed" work; STACK (3 stacks, run out one by one, the shortest restarts at max), IGNORE, REFRESH; a 2 s / 0.5 s burn ticks 4 × 42 with AD snapshotted, tagged `dot` + `burning`, MAGIC, never crits, the first tick at 0.5 s; +50% vs burning works; 3 stacks tick 126; a DoT kill credits the applier; a freed applier's burn keeps ticking; a tick on the Knight starts no i-frames; a hit's `statuses` apply (not when blocked); status events; death clears everything). Stats test 172/172; headless in-game check 40/40 (Judgement stuns, Iron Resolve speeds up to 739.6, slimes and the elite unchanged); room_01 and the sandbox run with no errors.

### C8 – Crits and on-hit: 2026-09-26, Built (awaiting play test)
**C8 – Crits and on-hit.** Crit (1.75 default), `damage_increase` scopes, `incoming_damage`, the on-hit stats, `proc_coefficient`. Migrate the Knight's 4 abilities from `take_damage()` to `HitPipeline.from_ability()`, so ability hits get crits, `damage_increase`, on-hit and proper tags.

5 new stats (26 in the registry) and `crit_damage` 1.75; `damage_increase` with `hit:` / `target:` scopes (`StatsComponent.get_scoped_stat()`), crit (`HitPipeline.roll_crit()`), `incoming_damage` in `Unit.on_hit`, on-hit (`HitPipeline.apply_on_hit()`, `make_proc()`, `Unit.heal()`), `Unit.get_status_tags()` (the stun only until C9). Cleave, Lunge and Judgement hit through `HitPipeline.from_ability()` (Judgement's missing-health bonus is added to the base damage); Cleave's push and Judgement's stun skip blocked hits; Iron Resolve's bonus already rode the swing's pipeline hit. League-style enemy attacks are tagged `basic_attack`. After Ryan's review, crits switched from plain dice to PRD with one roll per swing or cast (11 more checks: the constants 0.0847 / 0.3021; 4000 seeded rolls at 25% give 25% with ~8.5% crit-after-crit and never more than 11 misses in a row; 4 real swings and 6 Cleaves on 2 dummies crit both or neither and move the counter once). Combat test 322/322 (311 before PRD) (42 new C8 checks: Cleave 124.8 / Lunge 82 / Judgement 214 and 414 with their tags and no crit; 100% crit: a swing 112 with a "112!" number, Cleave 218.4, `take_damage()` and procs never crit, +0.5 crit damage = 144, 0% = no crits, 25% ≈ 100 in 400 seeded rolls, crit chance scoped to basic attacks; +20% on basic attacks = 76.8 while Cleave stays 124.8, increase before crit = 134.4, +50% vs stunned = 187.2 on the stunned dummy only; two 20% `incoming_damage` reductions = × 0.64, after armor; 20 on-hit = a 20 MAGIC proc, 10 at proc coefficient 0.5, none for DoT ticks, `take_damage()` or blocked hits; life on hit, life steal (basic attacks only), resource on hit; an enemy's proc on the player isn't blocked by its own i-frames). Stats test 172/172; headless in-game check 40/40 (Cleave's real hit carries its tags, the real slime's hit is tagged `basic_attack`); room_01 runs with no errors.

### M1 – a one-room fight in the sandbox: 2026-09-26, Passed
Milestone: the Knight fights with the combo, slimes chip, one elite telegraphs a slam, and the player can die ("You died", Backspace restarts) and win ("Room cleared!").

**Passed** (Ryan's play test, 2026-09-26): combo, dashes and abilities fine (reads as a rogue/diver pace); swarm pressure felt too fair, so post-hit i-frames 0.5 → 0.3 s; the elite slam was readable but too easy to escape, so 40 → 72 px and 0.75 → 0.65 s; death and restart, and the room clear, work. Combat test 263/263 after the changes (plus a 2-hit and a 5-hit combo check).

### C7 – Line of sight: 2026-09-26, Passed
**C7 – Line of sight.** The filter in swing hits and `AbilityUtil`, `ignores_walls` on Ability (`WorldQuery.has_line_of_sight()` already exists, built with the melee pull).

`Ability.ignores_walls` (default off), `Ability.filter_by_walls()` / `can_reach_through_walls()`, `AbilityUtil.in_sight()`. Walls now block: combo swings (feet to feet), League-style enemy attacks (a wall in between = a whiff), Cleave, Lunge (sight from the nearest point of its path), the elite slam (from the circle's center), and Judgement (a UNIT ability: out of sight counts like out of range, so it walks until it can see the target; a target that goes behind a wall during the cast is missed). Combat test 261/261 (11 new C7 checks, each with the target in reach so only the wall stops it); stats test 143/143; headless in-game check 38/38 (a swing and a Cleave at a dummy behind the sandbox pillar do nothing; the same swing hits in the open); room_01 runs with no errors.

**Passed** (Ryan, 2026-09-27: covered by the M1 play test of 2026-09-26).

### C6 – Damage numbers: 2026-09-26, Passed
**C6 – Damage numbers.** 3 log-scale size steps, crit style (placeholder until the font), colors by type, the player's damage red, healing green, DoT merge, rise 12 px / fade 0.6 s.

combat test 250/250 (14 new C6 checks: the size steps; one number per swing; swing 1 "64" size 10 in the physical color, the finisher "102" a size bigger; magic blue and true white; a crit "64!" 3 sizes bigger; three DoT ticks within 0.3 s merge into one "30" at size 8 and a later tick starts a new number; a green "+15"; the player's damage red; no number for a blocked hit; it rises 12 px, fades and is gone after 0.6 s). Stats test 143/143; headless in-game check 35/35 (a swing on a sandbox dummy shows one orange number; the player's damage is red); room_01 runs with no errors. "Nothing overlaps unreadably with 5 slimes" needs Ryan's eyes.

**Passed** (Ryan, 2026-09-27: covered by the M1 play test of 2026-09-26).

### Combo pace – finisher breather and a speed knob: 2026-09-26, Passed
Commit 9028dd4 (between C5 and C6; it had no entry until 2026-09-29). Attack pace comes from the swings themselves: no attack cooldown, no global cooldown; a per-swing breather `AttackSwing.pause_after` (the Knight's finisher 0.25 s; only attacking waits during it, and a click during it fires when it ends; a finisher cancelled after its hit still gets it); one `AttackCombo.speed_scale` knob (1.0 default) scales every swing timing and multiplies with attack speed. Changed: `attack_swing.gd`, `attack_combo.gd`, `auto_attack_component.gd` (`is_in_pause()`, the pause timer), `player_input.gd` (the buffer waits out the breather), `combo_knight.tres`, `combat_test.gd`. Combat test 236/236, stats test 143/143, in-game check 33/33.

Ryan then set `speed_scale` to 1.266 in `combo_knight.tres` (commit 5f7f0ae, the same evening). The AB1 commit removed it again without a record; restored 2026-09-29 (cleanup pass above).

**Passed** (Ryan, covered by the M1 play test of 2026-09-26: "combo, dashes and abilities fine").

### C5 – Elite: 2026-09-26, Passed
**C5 – Elite.** `slime_elite.tscn` (inherits `slime.tscn`) + `data/units/slime_elite.tres` (starting values: 900 health, 100 damage = 15% of the Knight's 650), a telegraphed slam ability (0.75 s telegraph, about 40 px circle), `Telegraph`, the Enemy cast hook, one elite in the sandbox.

`scenes/enemies/slime_elite.tscn` (inherits `slime.tscn`: purple, ×1.4 body, 19 px collider, AbilityComponent with the slam) + `data/units/slime_elite.tres` (900 health, 30 basic attack damage = 4.6% (swarm band) with a 0.25 s windup, 260 move speed); `Elite1` in the sandbox's open top-right corner (784, 112). Combat test 225/225 (20 new C5 checks: the numbers; a telegraph where the Knight stands, half full at 0.37 s; 100 damage and a 20 px push at 0.75 s; the telegraph gone after; walking and dashing out; a stunned elite's slam doesn't go off, its telegraph is removed and its cooldown refunded; the elite AI casting the slam by itself). Stats test 143/143; headless in-game check 33/33 (the sandbox elite casts at the real player, its telegraph is on the room floor under the units, standing in it costs 100, walking out with a real key press avoids it); room_01 and the sandbox run with no errors.

**Passed** (Ryan, 2026-09-27: covered by the M1 play test of 2026-09-26).

### C4 – Getting hit: 2026-09-26, Passed
**C4 – Getting hit.** Post-hit i-frames, 12 px knockback on the player (marked as hit knockback, which a dash replaces), enemy whiffs out of reach, stronger-knockback-wins, slime windup retuned into 0–0.3 s.

combat test 205/205 (32 new C4 checks: the numbers; the first of two same-frame hits lands and the second is blocked; i-frames last 0.5 s and the Knight blinks; a DoT tick starts none; a slime winds up 0.25 s, hits for 22 and pushes 12 px away; the push is dash-cancelable and a dash replaces it; teleporting out of reach mid-windup is a whiff; a 6 px push during a 20 px one is dropped, a 30 px one replaces a 6 px one; a swing during a stronger knockback leaves it alone); stats test 143/143; headless in-game check 27/27 (the real slime AI hits, pushes 12 px and starts 0.5 s of i-frames; walking away with a real key press during its windup makes it miss); room_01 runs with no errors.

**Passed** (Ryan, 2026-09-27: covered by the M1 play test of 2026-09-26).

### C3 – Hit feel: 2026-09-26, Passed
**C3 – Hit feel.** Feel tiers from `HitContext.feel` (light / heavy / kill), longest-wins hitstop, 0.06 s flash, shake per tier.

combat test 173/173 (20 new C3 checks: the tier numbers; overlapping hitstops 0.03 → 0.08 → 0.02 end at 0.08 s; swings 1–2 freeze 0.03 s with no shake, the finisher 0.06 s with a 2 px shake, a kill 0.08 s with 3 px, a whiff nothing; `take_damage()` hits and a blocked hit play no feel; Cleave shakes only its own 3 px; the flash is white at the hit and gone after 0.06 s). The C2 swing-length check now measures game time, since a hit's hitstop adds physics frames but almost no game time. Stats test 143/143; headless in-game check 21/21; room_01 runs with no errors.

**Passed** (Ryan, 2026-09-27: covered by the M1 play test of 2026-09-26).

### Melee basic attacks (between C2 and C3): 2026-09-26, Passed
**Melee basic attacks** (between C2 and C3): swing step, target pull with aim snap, walk-cancel of the recovery, `attack_style`, minimal `WorldQuery`.

combat test 153/153 (44 new checks: steps 6 / 6 / 10 px in the air, a slime 15° off and 95 px away aimed at with the aim snapped onto it, a capped 24 px pull that connects, a stretched 18.2 px step ending at 39.2 px, 6 px when already close, stopping at a touching slime's edge, no pull at 60°, a 20° max snap at 30°, the aim-line pick of two, no pull through a wall, dash and stun during the step, the root ending 6 frames after the hit with the combo continuing, RANGED); stats test 143/143; headless in-game check 21/21 (a real click 12° off a slime 97 px away pulls 24 px and connects; the sandbox's own pillar blocks the pull; enemies, abilities, i-frames and the HUD unchanged); room_01 runs with no errors.

**Passed** (Ryan, 2026-09-27: covered by the M1 play test of 2026-09-26).

### C2 – Knight combo: 2026-09-26, Passed
**C2 – Knight combo.** `AttackSwing`, `AttackCombo`, `combo_knight.tres`, the combo mode, PlayerInput/Dash/Player changes, `cancels_swing`, `select` unbound, Iron Resolve through swings.

combat test 109/109 (59 new C2 checks: hit 5 frames after the click, swing 18 frames, 64 / 64 / 102.4 damage, the finisher's 20 px push, reach 70 / 78 px hit and 82 px miss, arc, reset after 0.6 s, a click 1 frame into a swing starts swing 2 right as it ends, dash / stun / Q / death cancels, Iron Resolve on two slimes, +50% attack speed = 12-frame swings); stats test 143/143; headless in-game check 15/15 (a real left click swings and hits for 64; the Knight's abilities, slimes chasing and hitting, i-frames and the HUD unchanged); room_01 runs with no errors.

**Passed** (Ryan, 2026-09-27: covered by the M1 play test of 2026-09-26).

### C1 – Hit pipeline: 2026-09-26, Passed
**C1 – Hit pipeline.** `Events`, `HitContext`, `HitPipeline`, `Unit.on_hit`; `take_damage()` and `_on_hurtbox_hurt` wrapped; `damage_type` and `proc_coefficient` on Ability. A test scene `res://scenes/tests/combat_test.tscn` (script in `scripts/tests/`).

`combat_test.tscn` 50/50; stats test 143/143; a headless in-game check in the sandbox 11/11 (Cleave 124.8, Lunge 82, Judgement's damage and stun, Iron Resolve's haste, a slime chasing and hitting for 22 through `Events.unit_hit`, i-frames, the HUD); room_01 runs with no errors.

**Passed** (Ryan, 2026-09-27: covered by the M1 play test of 2026-09-26).

## Dungeons (DUNGEONS.md)

### Doc written and interview done: 2026-10-03, docs only
Docs only; no code or tests changed.
- **The interview:** Ryan answered I1–I10 in five rounds (DUNGEONS.md, Open questions; DECISIONS.md, Dungeons), written into DUNGEONS.md, DECISIONS.md, VISION.md, ALLIES.md and CLAUDE.md.
- **`docs/DUNGEONS.md` written** from Ryan's decisions (his interview with the advisor, 2026-10-03): wings as runs, floors, scale by spaces, time and measured cost, fixed layouts with shuffled contents in content slots, packs and arenas, bosses, a roster per dungeon, checkpoints with the hybrid respawn rule, navigation, quests, the puzzle framework, difficulty tiers, "recommended for", the champion lens and quest lines, rewards, scope. Claude's proposals are marked *(proposed)*.
- **`docs/DECISIONS.md`:** a new Dungeons section (Ryan's decisions); Game structure (a wing is a run; the 2026-09-29 run row struck for that part only; the death and meta-progression rows pointed to Dungeons); 3D view (Wing scale, the P-spike, backdrops).
- **Doc edits applied:**
  - VISION.md: Pillar 5, Game structure (the loop, the hub, Runs, Death), Meta-progression (difficulty tiers), Scope (shuffled contents in fixed layouts), open question 4 answered, a pointer on open question 7, the Dark Souls and Diablo references. There was no "1–3 square km" anywhere to remove.
  - 3D.md: a Wing scale section (spaces, the sim's Room(s), what grows with a wing, sleeping, backdrops) and P-spike as build step 10.
  - LOOT.md: From the dungeon (hand-placed named gear, chest tables per content slot, difficulty tier loot quality, floor drops), depth in a wing, run pacing.
  - COMPANIONS.md: crafting parts and clues as collectibles, a clear as the counted run, signature companions, kindling caches.
  - ALLIES.md: difficulty tiers with party scaling, wing recommendations for pairs.
  - CHAMPIONS.md: Dungeon content per champion (one quest line per wing, the lens, recommendations reading the kit).
  - CLAUDE.md: the Docs index, Future docs (DUNGEONS written; ENEMIES_AI, NARRATIVE, PROGRESSION and UI queue notes), Current status.
- **Follow-up (2026-10-03, after the commit):** ALLIES.md added to CLAUDE.md's Docs index (it was missing since ALLIES.md was written), and WORLD_INTERACTION's row widened. WORLD_INTERACTION.md: a Used by line, the layer table's DUNGEONS uses, Puzzle elements under Interactables, pit-drops vs pits, theme hazards, secrets behind destructibles, the proposed `INTERACTED` trigger, the doors question answered, the unscheduled world pieces as an open question. STATS.md: the enemy-scaling question now carries DUNGEONS' proposal (difficulty tier modifiers; depth for loot only), `set_level()` still reserved. DUNGEONS.md: `on_interact(player)` matches WORLD_INTERACTION; its For other docs marked applied.

## Enemies AI (ENEMIES_AI.md)

### The duelist's tuning pass (TUNING PASS, starting values, expect to change): 2026-10-07, Built (awaiting Ryan's play test)
- Data only (the values in DECISIONS.md, Enemies, 2026-10-07). Measured in five seeded fights a case (a temporary harness, deleted: Ryan's Knight with no gear, Quick Recovery and Bulwark; the sandbox's TEMP ×1.5 with keep DPS; the duelist 5 m away as H spawns it; the leash lifted, since its pushes walked a standing Knight out of 12 m and it went home in 3 of 5 runs), before → after: his full rotation and swings, taking no damage, kill it in 4.4 s (2.9–5.5) → 13.4 s (11.4–15.1), his swings 52–79% → 65–72% of it; a real trade he still wins every time, left with 570–620 → 271–475 health; standing still he dies in 37.2 s (31.5–39.8) → 21.9 s (16.8–26.6); with Lunge and Iron Resolve spent, its setup (snare, strike, finisher) deals 150 (23%) in 2.9 s → 355 (55%) in 1.9 s, and he dies in 31.0 s → 14.7 s; with him on top of it, it peels in 2 → 3 fights of 5 (one roll an episode). Tests: enemies 500/527 (2 new; HEAD already failed 28 of 525, all from the brute preset's panel save in 0a7c3d6: with that preset's AI1 values 527/527), the other eight 3,136/3,136; no warnings.

### AI-D1 – The test duelist, crowding and the opening: 2026-10-06, Passed (Ryan's play test, 2026-10-07; he committed it, then asked for the tuning pass)
Ryan passed AI3c and committed it (the tree was clean), then started AI-D1, the first Combos step (ENEMIES_AI.md, Combos, crowd control and the test duelist). Combo plans come in AI-D2.
- **Data:**
  - `EnemyBehavior`: `peel_threshold` (0.1–1) and `opening_bar` (0–1), nineteen sliders (twenty fields). Brute 0.6 / 0.5 (the class defaults), skirmisher 0.6 / 0.4, caster 0.5 / 0.6. `BrainAdjust` has both.
  - `EnemyAITable`: a Combos (AI-D1) group: `major_tags`, `crowding_weights` (near 0.6, closing 0.15, gap-closer 0.3, hits 0.3; the ally's cc 0.4), `crowding_closing_full` 400, `crowding_recent_time` 1, `crowding_hit_window` 3, `crowding_hits_full` 3, `opening_weights` (escapes 0.5, cc by another 0.5, recovering 0.4, committed 0.4, cornered 0.2), `opening_cc_min_left` 0.5, `cornered_check_px` 48. `intent_scores` gains `peel` 0.9. The .tres is unchanged (class defaults).
  - `Ability.recovery_time` and `Ability.combo_roles`. `AIUse.INTENT_TAGS` gains `peel`. `Condition.Kind` gains `CROWDING`, `OPENING`, `TARGET_ESCAPES_READY`, `TARGET_CORNERED` (10–13), and THREATENED's `status_tag` filters by the incoming ability's tag (`major` = any of `major_tags`).
  - `pose_set_default.tres`: `recover` (slumped back 10°, squashed to 0.9, no rim).
  - The test duelist: `data/units/test_duelist.tres`, `data/abilities/test_duelist_q_snare.tres`, `_w_guard`, `_e_strike`, `_r_finisher` (copies of the library's snare, guard, charge and big hit, at the doc's numbers), `data/enemies/enemy_test_duelist.tres` (an elite brute, `duelist`, `crowded_commit` 0.4), `scenes/enemies/test_duelist.tscn` (a steel blue capsule).
- **Code:**
  - `ComboPlanner` (new: `scripts/units/combo_planner.gd`): `get_crowding()`, `get_opening()`, `get_near()`, `get_biggest_term()`.
  - `AbilityComponent`: the recovery after an effect (`is_recovering()`, `get_recovery_left()`, `get_recovery_ability()`, the locks `recovery`; casting is busy meanwhile).
  - `Brains`: `get_recent_hits()`, `get_last_gap_closer()`, `note_gap_closer()` (from `Events.unit_hit`, `Events.ability_cast` and each champion's `DashComponent`). `PartySnapshot`: each champion's escapes, crowd control (`read_ccs()`) and last gap-closer.
  - `SituationContext`: the two reads with their inputs and terms, `major_tags`, the opener slots, the setup and the peel; `get_best_use()`'s slot filter and `get_opener_use()`.
  - `EnemyBrain`: reads both values each think. Crowding at `peel_threshold` starts the episode, and a failed all-in roll peels (the cast, then the kiting step). An enemy with an opener sets up at `opening_bar`, and its opener's end doesn't end the commit. The drive holds still for a peel and through a recovery (`recover`). `BrainDecision.setup`.
  - `SandboxBrains`: Shift+H's test duelist, H's eleventh scenario (escapes down), `get_combo_text()` on the overlay; the panel shows the two sliders.
- **Changed during the step** (DECISIONS.md, Enemies; ENEMIES_AI.md's built notes):
  - **The setup's gate is an `opener`-role ability until AI-D2's plans**, so `combo_roles` came a step early. A setup opens with the best `cc`, `damage`, `gap_close` or `poke` use of its opener slots (a tie to the earlier slot: the duelist's snare on Q). That opener's end doesn't end the commit, as a gap-closer's doesn't; then the commit plays as AI1's.
  - **No setup under the alert pose.** `Enemy.get_pose()` shows `alert` first for 0.4 s after waking. A setup on its first think (0.33 s) crouched under it, so the test saw no tell; it waits the alert out now.
  - **The strike reaches 600 u** (the library charge's range), not the 500 u written first. At 500 u it couldn't open from the duelist's band's far edge (about 620 u center to center), so with the snare down the duelist never set up (the test caught it).
  - **The episode ends** once crowding is under the threshold *and* the target has stayed out 1 s; a string of hits can keep it on.
  - **A peel follows the roll's order** (an answer, then its roll); a peel use alone falls to the mix. A rolled peel that can't be cast any more takes the kiting step alone.
  - **The reads:** a push is never a gap-closer, DoT ticks aren't hits, no escapes means none down, a crowd control with no end counts as plenty left. Every brained enemy reads both values; only one with an opener acts on the opening.
  - **`EnemyBrain.is_in_ability_recovery()`**, since `Enemy.is_recovering()` already means the walk home's heal.
  - **Walking in brings the episode forward a little for every enemy:** at a full-speed walk the closing term starts a brute's about 0.35 m outside its 2 m. Placed or standing, it starts at 2 m as before.
- **Older checks whose expectations changed** (seven, all counts that AI-D1 lengthens): the brute, skirmisher and caster presets' slider lists (two more values each); "18 fields, 17 sliders" (now 20 and 19); `nerve` "last in the list" (now index 17); H's cycle (eleven scenarios, escapes down after the odds); Shift+H's cycle in the AI3 sandbox check (the duelist after the elite caster). Every behavior check from AI1 to AI3c passed unchanged with crowding starting the episode.
- **Measured:**
  - **The test duelist in the sandbox** (scratch `aid1_harness.gd`: saving off; the Knight invulnerable and standing). With his escapes down it set up once, then cast the snare, the strike twice and the finisher in 15 s, showing crouch, recover and step_back. With him put in its face four times it peeled once (snare, then a step back) and went all in once (the strike). Its overlay read `crowding 0.60 ≥ 0.60 (near 0.60): peel (Snare)` and `recover 1.0 s`.
  - **In the test:** the episode starts 0.37 s after crowding passes (its reaction 0.35 s) for the Knight inside 2 m, a Lunge in to 2.75 m (crowding 0.68) and three hits at 2.5 m (0.83); 1 m outside (0.23) and the Lunge at a threshold of 0.7 start none. The setup: the snare first, its tell shown, with Lunge and Iron Resolve down; none at a bar of 0.6 or with his escapes up; the strike first with the snare down. A real brute reads the opening: 0, 0.286 with Lunge down, 0.5 with Iron Resolve too (at once), 0.5 for another's root and 0.4 for his cast (each only after its reaction time), 0.2 against a wall. The finisher's recovery holds it 1.2 s, still, in `recover`. Its guard rises for Judgement, not for a slow test bolt it sees coming, and when it's at 30% with him in its face.
  - **A think's cost** (headless, debug build): 508–519 µs on average with the odds pack, the mixed pack and the duelist in its band (AI3c: 410–480). With the Knight in the duelist's face 470–720 µs (it gathers its answers, peels and openers too); p99 under 1.1 ms. One duelist at 25 a second costs about 0.3 ms a tick. The odds read is unchanged (33–51 µs).
- **Sensitivity:** eight rules broken on purpose, in two runs plus one, each caught. The peel branch failed 5 checks; the recovery lock 3; the DoT filter 1; the major filter 4; crowding starting the episode 2; the opening's reaction delay 2; the alert rule 2. The opener's end was missed at first, because the check looked before the next think; the check now waits 0.2 s and fails on it. Everything was restored and diff-checked.
- **Tests:** enemies 525/525 (74 new). Stats 180/180, combat 486/486, abilities 593/593, audio 110/110, champions 238/238, talents 310/310, view 469/469, loot 750/750: 3,661/3,661. The warnings probe (every script under `-d`) found none. The smoke runs (`sandbox_main`, `main_layout`) had no errors, and the saves stayed byte-identical.

### AI3c follow-up – the think budget, Ryan's answer: 2026-10-05, Passed (with AI3c)
Ryan committed AI3c and the warnings cleanup (the tree was clean). He asked what an optimization sweep and a budget cut would do, then decided: **keep 200; elites and bosses are exempt.**
- `RankRules.think_budget_exempt`, data: true for the elite and boss ranks in `enemy_ai_table_default.tres`. A duelist is an elite, so it's exempt.
- `EnemyBrain.is_budget_exempt()`.
- In `Brains`, an exempt brain always thinks at its own rate. The budget takes the exempt brains' thinks off the top, and the regulars share what's left, never under the floor of 5. Claude's reading: the total stays near 200 instead of the exempt thinks going on top of it.
- **Tests:** the think-rate test's budget part now shows a regular, an elite, a duelist elite and a boss (75 a second, 65 of them exempt):
  - at a budget of 72, the regular gets the 7 left (7, 15, 25, 25; over 6 s, 42 / 90 / 150 / 150 thinks);
  - at 20, below the exempt 65, the regular sits at the floor of 5 and the exempt keep their rates;
  - which ranks are exempt.

  Enemies 451/451. All suites 3,587/3,587, all nine at once. The warnings probe found 0.
- **Sensitivity:** ignoring the exemption, and not taking the exempt thinks off the top, each failed 3 checks. The file was restored and diff-checked.

### AI3c – Odds, and think rates by rank: 2026-10-05, Passed (Ryan's play test, 2026-10-05; he committed it and started AI-D1)
Ryan committed the AI3b fix (the tree was clean) and asked for the warnings cleanup and "the next step", which was AI3c in Claude's proposed order. It's built on Duels and odds and his 2026-10-04 answers: a champion weighs 1.5; a heavy hit is 10% of max health, one per 0.8 s, only while pressing; think rates by rank.
- **Built:**
  - **Data:**
    - `nerve` (seventeen sliders: brute 0.6, skirmisher 0.8, caster 0.4) and its `BrainAdjust` multiplier.
    - `EnemyData.duelist`, and `RankRules.think_rate` (fodder 0, regular 10, elite 15, boss 25; −1 = the table's).
    - The table's odds group: `rank_strength`, `champion_strength`, `odds_threshold`, `odds_pressure`, `odds_token_bonus`, `tokens_per_target_cap`, `weakest_pick_weight` (added), `heavy_hit_window`, `heavy_hit_share`, `think_budget`, `think_rate_floor`. Two helpers: `get_rank_strength()` and `get_think_rate_for()` (a duelist elite gets the boss's rate).
  - **Brains:**
    - The odds, read once a tick (`get_odds()`, `compute_odds()`, `get_press()`).
    - The pool's +1 while pressing.
    - Heavy-hit landing times (`note_heavy_hit()`, `can_land_heavy_hit()`, `clear_heavy_hits()`).
    - The schedule by rank: each brain thinks on its own float period from its slot, and every rate is scaled down past the budget, never under the floor.
  - **The brain:**
    - The odds and the press in its situation (0 for a boss).
    - Respect × (1 − `nerve` × press), and one patience push shared with low health.
    - The `press` pose in place of hold and stalk.
    - The heavy-hit gate (as uses are gathered, and again at the cast), with the hit noted when its cast starts.
    - Its own think rate.
  - **The pick and the look:** `Enemy.get_pick_distance()` (the weakest pick, which ALLIES' margin reads). `pose_set_default.tres` gains `press`: a 10° lean in, an amber rim pulsing at 1 Hz.
  - **SandboxBrains:** the overlay's odds line, the think rate on its token line, and H's tenth scenario, the odds (three test brutes and the elite slime, 9 m away and idle).
- **Found while building** (ENEMIES_AI.md, Odds and Performance):
  - **The odds:**
    - They're read once a tick, so a change inside a tick shows on the next one.
    - With no champion up they're infinite (a full press).
    - The sandbox's own two slimes and elite slime make a light press (0.17) when all three fight the full-health Knight.
  - **The weakest pick:** its factor is data (`weakest_pick_weight`). "+1 at most" holds even if the data says more.
  - **Heavy hits:** a hit is noted when its cast starts, press or not, and a cast cut short takes its note back. "A boss plan scripts it" is a `scripted` argument that nothing passes until AI6.
  - **The press pose:** it applies to casters too; cornered still wins.
  - **Think rates:** the schedule at 10 a second is AI1's, tick for tick. The budget counts only awake brains.
- **Changed in older tests:**
  - AI2's five brutes now press, so the pool gives a third token; that check runs with the press off (`_no_press()`), and the press has its own test.
  - `_pin_ai3()` also pins `nerve` to 0.
  - The preset lists have 18 values, and H cycles ten scenarios.
- **Tests:** enemies 450/450, with 45 new checks:
  - the data and the strength worked out by hand (a 1v1, a 3v1, an elite with fodder, with and without the ally, the ally downed, the Knight at 30%);
  - the press's rules, the pool and its cap, and the weakest pick with the margin, a taunt, stealth and a boss;
  - one heavy hit at a time, with a real brute's smash refused;
  - thinks per rank over 10 s (100 / 150 / 250 / 250), the budget's scaling and floor, reaction times unchanged, and a gap-closer's follow-up starting 0.00 s after landing;
  - three brutes and an elite pressing (3 tokens in use, the press pose, 4 heavy casts at least 0.84 s apart), one brute changing nothing, and the ally down;
  - the overlay.

  Enemies 450/450 on 4 parallel runs too. All suites, all nine at once: 3,586/3,586 (stats 180, combat 486, abilities 593, audio 110, champions 238, talents 310, view 469, loot 750, enemies 450).
- **Sensitivity:** ten breaks across four runs, each caught.
  - **Run A** (the nerve term, the shared push, the token bonus, the press pose): 7 checks failed.
  - **Run B** (the weakest pick, the heavy-hit gate, a downed champion counted, a boss pressing): 8 failed. Without the gate, the real pack landed two heavy hits 0.50 s apart.
  - **Run C** (rank rates): 5 failed. **Run C2** (the budget alone): 3 failed.

  The originals were restored and diff-checked.
- **Smoke** (scratch `ai3c_harness.gd`, saving off; `sandbox_main`, `sandbox_main_layout` and `main_layout`): no script errors.
  - The odds scenario pressed the whole fight, with 3 tokens in use, the press pose, and `odds 3.3, press 1.0 (nerve 0.6)` on the overlay.
  - room_01's layout (six fodder slimes, odds 1.0) never pressed.
  - The saves were byte-identical.
- **Measured** (the step's "measured again"; ENEMIES_AI.md, Performance): a think in a fight now costs 410–480 µs (p99 0.8–0.9 ms; AI1: 130–230 µs). The odds read costs 42–56 µs a tick, and the odds scenario asks 45 thinks a second (about 0.32 ms a tick). At this cost the budget's 200 is about 1.5 ms a tick, which is Ryan's call (Open from AI3c).

### Warnings cleanup (every system's scripts): 2026-10-05, Passed (committed with AI3c, whose play test ran on it)
The AI3b fix passed and Ryan committed it (the tree was clean). He asked for the other script warnings to be cleaned up in one pass, before AI3c. The pass covers every system, not only enemies.
- **Found:** a scratch probe scene (under `scenes/tests/`, so the save guards applied; deleted after) loaded all 170 scripts with the debugger on (`-d`): **67 warnings in 18 files**, 13 of them in the game's scripts and the rest in the test suites. None was a bug.
- **Fixed:**
  - **Locals and parameters renamed** where they shadowed a member, a base-class property or a signal: `e` (the E slot's export) in `ability_component.gd` became `entry` / `empower`; `target` in `auto_attack_component.gd` became `assist` / `plan_target`; also `owner`, `size`, `id`, `rng`, `intent`, `ready`, `to_local`, `log`, `scale`, `hidden` and `draw` in reactions, the camera, Iron Resolve, the brain, the situation, the sandbox, the hub, the talent screen, the unit view and the tests. An inner `step` and `k` that a later outer one shared a name with were renamed too, as were loop and lambda names in the tests.
  - **Kept as they were, with `@warning_ignore`:** `await ability.execute(...)` in `AbilityComponent` and the combat test. The base `execute()` doesn't wait, but an ability's own script may, so removing that `await` would break casts. The same goes for one test's intended whole-frame division and one static call through the `Settings` autoload.
  - **Removed:** five `await`s on test data helpers that never wait, one unused test local, and one unused return value. Two ternaries now give `{}` instead of `null` (the check fails either way when the file is missing).
- Only names inside functions changed: no class, file, signal, exported property or input changed, and no behavior.
- **Tests:** the probe again: 0 warnings, no errors. All suites 3,541/3,541 (stats 180, combat 486, abilities 593, audio 110, champions 238, talents 310, view 469, loot 750, enemies 405), all nine at once.

### AI3b fix – the panel on H's fodder: 2026-10-05, Passed
AI3b passed and Ryan committed it; the tree was clean. His one hiccup: after changing some sliders and cycling H, the game broke at `SandboxBrains._sync_panel` ("Invalid access to property or key 'resource_path' on a base object of type 'Nil'"). The cause is older than AI3b, from AI2. H's eighth scenario (fodder) spawns plain slimes, and with the panel open the scenario picks its first enemy for the panel. A slime's data has no behavior preset, so the panel's title (and its values each frame) read a missing preset.
- `SandboxBrains.pick()` picks none for an enemy the panel can't tune: no data, no behavior preset, or no brain by its rank (`is_pickable()`, new; `_pickable()` uses it). The panel then says "No brained enemy".
- **His other question, the "shadowing" warnings:** these are GDScript warnings (a local name hiding a member with the same name), not errors, and harmless. Godot only shows them with a debugger attached (the editor's run; headless runs need `-d`). The enemies test loads 30 of them. Two came from AI3b, in `enemy_brain.gd`: a local `ready` in `get_own_ready_share()` became `ready_value`, and `roll_crowded()`'s `rng` parameter became `stream`. The other 28 are older (AI1, AI2, abilities, components, views), so they stay unless Ryan asks for a cleanup.
- **Tests:** enemies 405/405 (one new check: with the panel open, fodder picks none by H or by hand, and the panel says so). With the fix removed, it fails and the run prints Ryan's exact error. Green on 4 and on 6 parallel runs. All nine suites at once: stats 180, combat 486, abilities 593, audio 110, champions 238, talents 310, view 469, loot 750 green; enemies 404/405 in that run (the miss below).
  - **The miss:** AI2's fodder-ring check ("pushed about by their hits for 4 s, every one of them keeps hitting him") missed twice, under the heaviest load only: once in the `-d` run, once with all nine suites at once. Both times the hits were [0, 2, 3, 3, 2, 3]. It runs before the edited test, its slimes have no brain, and none of the changed code runs in it. HEAD's files passed it under the same kinds of load (2 runs). It's a load-sensitive check, not this fix.

**Passed** (Ryan's check, 2026-10-05; he committed it and asked for the warnings cleanup above).

### AI3b – The duel: confidence, spending, crowded, smell blood, aim lead: 2026-10-05, Passed
Ryan committed the Combos design and asked whether Korsavil's K3 had to come first. It didn't: K3–K6 and the enemy steps don't depend on each other, but the combo steps need AI3b. Ryan said "start AI3b". Built on the Duels and odds design and his 2026-10-04 answers (approved: a ready defensive counts whole below 30%, the sliders' role starts).
- **Built:**
  - **Four sliders** (sixteen in all): `confidence`, `crowded_commit`, `aim_lead`, `spend_eagerness`, at the role starts (brute 0.5 / 0.6 / 0 / 0.4, skirmisher 0.6 / 0.4 / 0.3 / 0.7, caster 0.3 / 0.2 / 0.5 / 0.8). Plus `BrainAdjust`'s four and `EnemyBehavior.crowded_range` (brute and skirmisher 200 u, the caster −1 = its band's minimum).
  - **The key ability and confidence:** `EnemyBrain.find_key_slot()`, `get_own_ready_share()`, and effective respect × (1 − confidence × its own kit ready). Cautious for 3 s after its key's cast (patience × (1 − 0.5 × confidence)), and its commit's end walks it out to its band's far edge (a retreat, `step_back`).
  - **Spending:** outside a right moment, a held key's damage, cc and zone uses are left out (`SituationContext.held_slot`), and a roll every 2 s frees it. The right moments: the target crowd-controlled, below its finish threshold, every defensive down, crowded, two champions in the key's area. A poke is never held.
  - **Crowded:** an episode after its reaction time, with one roll (`roll_crowded()`): cornered, escape, all in (patience full at once), or Ryan's mix of backing up once (chance 1 − aggression) or standing.
  - **Smell blood:** commit × 1.3 below the finish threshold, capped at 0.89. The panic-button share comes from `PartySnapshot.get_share_for()`, with the snapshot's ready and defensive values.
  - **Aim lead:** `Ability.get_led_point()` in the default plan (POINT and DIRECTION aims), `CastPlan.lead_px`, Brains' walk read (`get_walk_velocity()`), and the skirmisher's leap landing beside the led point.
  - **The overlay's duel lines** (`SandboxBrains.get_duel_text()`); the panel's slider list scrolls.
- **Found while building** (in ENEMIES_AI.md, Duels and odds and Conflicts):
  - **Episodes:**
    - An episode starts only when the target comes in: its own commit (and its walk out after) brought it into the Knight's face.
    - An episode ends only once the target has stayed out. The brief's "ends when the all-in or kiting step ends" would roll again and turn "back up once" into a chase.
    - A caster's all-in can't happen yet (escape wins first), so it isn't built.
  - **The key:**
    - `spend_value_bar` became a count of champions in the key's area (the default plan's value is always 1).
    - "Every defensive down" needs one to exist.
    - The elite test caster's key is its snare (3), not its bolt.
  - **Aim lead** past a bolt's range falls short (the first bolt test missed for that reason; the caster now stands 4 m off the walk).
  - **The tuning panel** already ran 14 px past the 360 px canvas; its sixteen rows now scroll (it ends at 342 px).
  - **Older tests:** confidence brings the test brute in after 4.8 s with its smash up instead of 12 s, so the AI1 and AI3 checks of the old timings pin AI3b's sliders to AI3's values (`_pin_ai3()`). The naive-gate check also accepts the kiting step (the elite slime spawns in the Knight's face).
- **Tests:** enemies 404/404 (66 new: the data, the key and confidence, a real brute's caution and walk out, spending and a real brute's held smash, the crowded rolls and three real episodes, its own commit never starting one, smell blood and the panic button, aim lead, a real bolt hitting only when led, the overlay lines, `step_back`). Green on 4 parallel runs.
  - **All suites 3,540/3,540:** stats 180, combat 486, abilities 593, audio 110, champions 238, talents 310, view 469, loot 750, enemies 404.
- **Sensitivity:** nine breaks in three runs, each caught:
  - run A: confidence, the far-edge walk, the all-in roll, the walk read during a dash (9 checks failed);
  - run B: the held-key filter, the bolt's flight in the lead, smell blood, the own-commit guard (8 failed);
  - the hold filter again, after the real brute's hold check was tightened to let its commits run to their first cast (3 failed).
  The originals were restored and diff-checked.
- **Smoke** (scratch `ai3b_harness.gd`, saving off; `sandbox_main`, `sandbox_main_layout`, `main_layout`, and the sandbox's elite slime): no script errors.
  - Every duel moment showed in the mixed pack and the Shift+H enemies: crowded rolls (all in, stand, back up, escape), cautious, a held key, the walk out.
  - The elite slime held its big hit through 15 s at the Knight with Iron Resolve up (spend 0.4, no right moment).
  - The saves were byte-identical.
- **Panel layout probe** (scratch `ai3b_panel_probe.gd`): 263 × 276 px from (6, 66), inside the canvas.

**Passed** (Ryan's play test, 2026-10-05; he committed it). One hiccup, the panel breaking on H's fodder scenario (an AI2 bug), is fixed above (AI3b fix).

### Design addition – Combos, crowd control and the test duelist: 2026-10-05, Docs only (Ryan's answers applied)
Docs only; no code or tests changed. Ryan's design addition: enemies are easy to brute-force because their kits are thin, so a test enemy with a real kit proves the brain. Added to ENEMIES_AI.md (on top of Duels and odds, the brief's "v2 additions"), nothing built rewritten:
- **ENEMIES_AI.md:**
  - Principle 11 and three Goal/feel rows.
  - A new section, Combos, crowd control and the test duelist:
    - two reads: crowding (the brief's "pressure on me") and the opening;
    - peel and setup as a crowd control's two use rules (the peel is the crowded episode with a crowd control as its answer);
    - combo plans (`ComboPlan`, `ComboStep`, `combo_roles`; any opener; no blind finishers; the ends);
    - the follow-through (reset or stay) with a worked example;
    - where a plan lives (inside `commit`);
    - being combo'd: no combo budget and no kill protection (cooldowns are the limit), diminishing returns on crowd control, the opener's telegraph;
    - the Knight's counterplay findings, ally parity, enemies being combo'd (the poise hook, break free), the feedback events;
    - the test duelist (stats, a kit from the library with the guard as a plain shield, three plans, poses, scenarios).
  - The `peel` intent; four condition kinds and THREATENED's tag filter; five sliders (twenty-two in all) with tests and overlay lines; data rows, architecture (`ComboPlanner`), edge cases.
  - Build steps **AI-D1** (the duelist and the two reads), **AI-D2** (combo plans and the follow-through), **AI-D3** (diminishing returns) and **AI-D4** (ally parity, with ALLIES AL6), after AI3c. Not D1–D4: DUNGEONS has D0–D9.
- **Cross-doc edits:**
  - ABILITIES.md: `combo_roles`, `recovery_time`, `castable_while_cc`, the condition kinds, the AI section's combos bullets.
  - COMBAT.md: diminishing returns, `status_cc_immune` and its ring, `CrowdControlRules`, the events, no combo budget or kill protection (Ryan), the open question answered.
  - ALLIES.md: the shared planner, the ally's rules, the stances' sliders, the table's weights, AL6's note.
  - CHAMPIONS.md: the Knight against enemy crowd control, `ChampionData.combo_plans`.
  - DECISIONS.md: two rows in Enemies (the brief; Ryan's answers) and one in Combat (diminishing returns; no budget). CLAUDE.md: the Docs index and Current status.
  - CONVENTIONS.md is untouched: the new names go in on approval.
- **Ryan's answers** (four short rounds, the same day): the Knight gets no new tool against crowd control now; a root (up to 1 s) and a short stun (up to 0.5 s) on the player at first; **no combo budget** ("if their abilities are off cool down they can use it whenever they please") and no kill protection; diminishing returns for every unit (fodder full; bosses until poise); boss poise later; the duelist's guard a plain shield, its numbers as proposed; all four rule changes approved (crowding starts the crowded episode and a failed all-in peels; a plan holds its commit and token up to 6 s; `mixup` and `combo_greed`; the ally's own plans and quick follow-up); "stay" for the follow-through. Ryan asked whether the rule changes were new or already planned: all were new proposals from this pass.
- **Found while writing** (ENEMIES_AI.md, Conflicts):
  - **Names:** "pressure" and "press" already taken (so crowding and stay); "combo" is the basic attack chain (so a combo plan); peel and guard are already intent tags.
  - **The brief's own gaps:** `combo_greed` not defined, and the blind finisher put under the brute's lowest slider; fodder's full crowd control against "every unit"; kill protection redundant with the damage cap.
  - **Against Ryan's decisions:** the duelist as a rank thinking 20 a second (Ryan: an elite flag at the boss's 25); the library already built; no `answer` tag needed; a root blocking the dash (Ryan's roots rule); no icons over heads (so a ring); ALLIES' unscripted party combos; the ally's reaction time.
  - **What doesn't exist yet:** AI6's whiff read for "recovering"; a plan outlasting the token's 4 s; no ability recovery field.

### AI3d – The enemy ability library, part 1, and full kits: 2026-10-04, Passed (Ryan's play test, 2026-10-04)
Ryan committed the Duels and odds design and started AI3d first of its three steps. Before building he answered four questions, each as Claude proposed: re-kit the elite slime (slam, shockwave, big hit); more enemy slots come with bosses (AI6); the test kits as proposed; the stab at 30 damage (35 broke the telegraph rule).
- **Built:**
  - **The library:** 14 templates in `data/abilities/enemy/` (all of the starter list but the pool, which waits for Hazards). New scripts in `scripts/abilities/enemy/`: `cleave_arc.gd`, `dash_strike.gd` (the charge and the flurry), `shockwave.gd` (extends the slam), `hop_away.gd`. Existing scripts serve the other archetypes where they are (not moved).
  - **New pieces:** `Telegraph.cone()` (a fan whose fill grows outward), and `status_root.tres` (the snare's 1 s root: the bolt with an always-on conditional bonus).
  - **Caps:** `RankRules.min_abilities`, and the AI table's caps by Ryan's table (min–max 0–0, 2–3, 3–5, 4–6).
  - **Kits:** the test brute (smash, cleave arc, charge), skirmisher (leap, stab, flurry), caster (bolt, lobbed orb, blink away), elite caster (bolt, guard, blink away, snare) and the elite slime (slam, shockwave, big hit), each its own copies of the templates, with weights ordering each kit.
- **Found while building** (in ENEMIES_AI.md):
  - An escape ability now ends a walk under way. A blink after a walk had started kept the walk's clock, so the next walk was cornered at 1.43 s (seen with the caster's new 1 s orb).
  - The big hit reaches 350 u, past the shockwave's circle, so the elite slime opens with it.
  - The five-brutes token test holds the Knight unstoppable: their charges and cleave arcs could push him out of a brute's leash.
  - The elite slime is placed only in the sandboxes: room_01 has never had one, so room_01 is unchanged.
  - view_test's swing-arc guard now counts six `VFX.slash()` calls (the cleave arc's, through `VFX.drawing_origin()`).
  - Enemies keep four slots until AI6.
- **Tests:** enemies 338/338 (33 new; 305 before, with the TEMP's 24), on 4 parallel runs and 5 more before the last check was added.
  - The new checks cover the templates, the telegraph rule over every template and EnemyData (and a breach it catches), the kits, bands and respect values, and `status_root`.
  - They also cover the plans and areas of the cleave arc, charge, shockwave and hop, and their casts hitting what the telegraph shows: in front and not behind, each champion on the band once, the push, the 4 m miss, a root of about 1 s, a 3 m hop.
  - And the brains with their kits: the brute charges in from its band and uses more than one ability, the elite slime opens with its big hit, the elite caster snares, and the regular caster pokes with its bolt and its orb.
  - Changed expectations: the AI table's caps (min and max), and the elite caster's kit count (4).
  - **All suites 3,392/3,392:** stats 180, combat 474, abilities 593, audio 110, champions 168, talents 310, view 469, loot 750, enemies 338.
- **Sensitivity:** five breaks (the dash's once-each, the cone's angle, the shockwave's reach, the hop's direction, the escape walk's end) failed 8 checks; the originals were restored and diff-checked. In that broken run the fodder ring's "every one keeps hitting" check also failed once (a slime with 0 hits). None of the breaks touch fodder, and it passed on all 9 clean runs; it's AI3's chaotic fodder test.
- **Smoke** (scratch `ai3d_harness.gd`, saving off; `sandbox_main`, `sandbox_main_layout`, `main_layout`): no script errors.
  - In the mixed pack and the Shift+H enemies, the brute charged and cleaved, the skirmisher leapt and used its flurry, and the elite caster snared.
  - The elite slime cast its big hit with the Knight's kit up in one of two 15 s runs (it holds most of the time, as a brute should).
  - The saves were byte-identical.

### Design addition – Duels and odds: 2026-10-04, Docs only (Ryan's answers applied)
Docs only; no code or tests changed. Ryan's design addition: most fights are 1v1 or 2v1 and rarely more than 5–7 enemies, so each enemy must be smarter and stronger. Added to ENEMIES_AI.md, nothing built rewritten:
- Principle 10; the Goal/feel rows (think rates, pressing, heavy hits, telegraphs); Kits (Ryan's 3–5 abilities and no passives, Claude's recommended table, the enemy ability library with a 15-archetype starter list); Duels and odds (the full effective-respect and pressure terms, confidence and the key ability, cautious, `spend_eagerness`, the crowded episode and derived answers, smell blood, odds and the press with its fairness limits, `aim_lead`); the reaction-time rule (Knowledge); boss passives (Bosses); think rate by rank with a 200-a-second budget (Performance); the five sliders with role starts, tests and overlay lines (seventeen in all); the later list; data rows, architecture notes, edge cases; build steps **AI3b** (the duel), **AI3c** (odds and think rates; AI2's token code reopened) and **AI3d** (the library and full kits), with AI1–AI8 not renumbered; boss passives join AI6.
- ABILITIES.md (answers from the intent tags, enemy abilities' `respect_value` and the key ability, aim lead, heavy hits, the library) and ALLIES.md (the pick under odds, the party's strength). COMBAT.md unchanged: the player's post-hit i-frames (0.3 s) already cover the heavy-hit window. DECISIONS.md: eight rows (Enemies).
- Found while writing (ENEMIES_AI.md, Conflicts): Ryan's 3–5 abilities against his ladder and `RankRules.max_abilities`; "duelist" isn't a rank; "no passives" against `EnemyData.twist`; the kiting step against AI1's "holds its ground"; aim lead against the default plan's "no leading"; low health counted four ways (kept, one shared push); the 0.3 s window equal to the i-frames; at a champion weight of 1 a lone elite presses; "boss phase triggers by health" already designed; "press" beside "pressure".
- Ryan's answers (three rounds and one follow-up, the same day): kits as Claude's table (fodder none, regulars 2–3, elites 3–5, bosses 4–6 plus a passive; the caps change in AI3d); a duelist is an elite flagged `duelist` that thinks at the boss's rate; `EnemyData.twist` stays as it is; AI3 passed; a champion weighs 1.5 in the odds, the rank weights and the 1.5 threshold stay; `crowded_range` is each preset's own value; heavy = at least 10% of max health, the window 0.8 s, only while pressing (always-on not approved); approved for AI3b: a ready defensive counted whole below 30% and the sliders' role starts (`aim_lead` included); crowded with no answer is a rolled mix of backing up once or standing and swinging (Claude proposes the chance 1 − `aggression`).

### TEMP – Enemy attack speed test multiplier: 2026-10-04, Built (awaiting Ryan's play test)
A test aid, not a design rule (DECISIONS.md, Testing); to remove it, revert `game/scripts/components/auto_attack_component.gd`, `game/scripts/rooms/sandbox_brains.gd`, `game/scenes/rooms/sandbox.tscn`, `game/scenes/rooms/sandbox_3d.tscn` and `game/scripts/tests/enemies_test.gd` (its TEMP section). Measured in enemies_test (seeded, 10 s each): at x1.5 with keep DPS a slime swings every 59 frames instead of 87 at 0.67× damage, so its DPS is 0.983 of x1.0 (the loop already loses one physics frame per swing, at the recovery's end); the caster's DPS is 1.004 of x1.0; the slime's windup holds at 0.25 s (16 frames), and the caster's 0.6 s drops to 0.4 s. A sensitivity run (the floor, the division and the team check broken) failed 9 checks. Tests: enemies 305/305 (24 new); all suites 3,359/3,359. A smoke run of `sandbox_main` starts at x1.5 and is back to x1.0 at the hub, with the saves untouched.

### AI3 – Skirmisher and caster: 2026-10-04, Passed (Ryan committed it)
Ryan passed AI2 and confirmed that his 30 m camera (committed with it) was on purpose. Before AI3 he answered four questions, each as Claude proposed:
- **The test kits split by the rank caps:** a regular test caster (bolt, blink away) and an elite one (plus a shield). The elite skirmisher waits for AI4.
- **The shield reads anything it sees coming,** Judgement on it included.
- **The skirmisher's gap-closer is a real leap.**
- **AI2's two rules stay:** sight needs a path, and a taunt commits.

**Code, new:**
- **Ability scripts:**
  - `scripts/abilities/test_skirmisher/leap.gd`: a telegraphed landing circle, `MovementComponent.leap()`, a hit on landing; its plan lands beside the target.
  - `scripts/abilities/test_caster/guard.gd`: a `status_shield` copy on itself.
  - `scripts/abilities/test_caster/escape_blink.gd`: extends the test blink; its plan blinks away, the farthest of five directions.
- **Data:**
  - Presets: `enemy_behavior_skirmisher.tres`, `enemy_behavior_caster.tres`.
  - Units: `units/test_skirmisher.tres`, `units/test_caster.tres`.
  - Abilities: `test_skirmisher_q_leap`, `test_skirmisher_w_stab` (the slam's script), `test_caster_q_bolt` (the test bolt's script), `test_caster_w_guard`, `test_caster_e_blink`.
  - EnemyData: `enemy_test_skirmisher`, `enemy_test_caster`, `enemy_test_caster_elite` (casters notice from 850 u).
  - Scenes: `scenes/enemies/test_skirmisher.tscn`, `test_caster.tscn`, `test_caster_elite.tscn`.

**Code, changed (additive):**
- `ability.gd`: `get_effect_area()`, with the kinds none, unit, circle, cone and segment and a default from the data; `covers_unit()`; `DEFAULT_AREA_RADIUS_PX`.
- Kit overrides of `get_effect_area()`: `cleave.gd` (its cone, or Whirling Cleave's circle), `lunge.gd` (its path), `judgement_leap.gd` (its landing circle).
- `ability_component.gd`: `get_cast_ability()`, `get_cast_context()`, `get_cast_time_left()`, `get_charge_aim()`.
- `projectile.gd`: the group `projectiles` and `get_range_left()`.
- `condition.gd`: `Kind.THREATENED` (appended), read from the situation.
- `situation_context.gd`: `incoming`, `is_threatened()`, `cornered`, `escaping`, `resetting`.
- `party_snapshot.gd`: each member's `cast` (`read_cast()`) and the `projectiles` in flight.
- `brains.gd`: `wake_at()`; the snapshot gets the projectiles.
- `enemy_brain.gd`:
  - Perception with the reaction delay.
  - The intents `defend`, `escape` (the walk away, cornered) and `retreat` (falling back, the skirmisher's reset).
  - Poses by role; a caster's strafe for cover and spacing.
  - The skirmisher's commit end, its hop and half its patience; a gap-closer's cast no longer ends a commit.
  - An attack coming breaks the no-flip-flop bonus.
- `enemy_ai_table.gd`: the scores defend 0.9, escape 0.75, retreat 0.7, and the group "Casters and skirmishers".
- `enemy.gd`: a settled fodder steps back to its place past 0.85 of its reach.
- `sandbox_brains.gd`: Shift+H (the test enemy), the mixed pack, the incoming shot once the enemy fights, the overlay's threats and states.
- `view_test.gd`:
  - The camera's numbers updated for Ryan's 30 m: distance 31.5 m, the floor window 2752 × 1792 texels.
  - The leap guard now allows the skirmisher's leap.

**Changed during the step** (the rules are in ENEMIES_AI.md):
- **Casters notice from 850 u.** At the default 450 u a lone caster always noticed inside its own band's minimum and fled at once.
- **The escape walk keeps its own clock and holds.** Jitter let a poke beat escape for one think, and that restarted the 2 s walk each time, so a caster was never cornered.
- **The cornered pose shows from the moment it's cornered,** even before its next think.
- **An attack coming breaks the no-flip-flop bonus,** so a shield isn't held back by a poke just started.
- **A gap-closer's cast no longer ends a commit.** A missed leap ended a brute's commit at once.
- **A settled fodder keeps swinging only while its target is within 0.85 of its reach.** At the edge, other fodder's pushes made every swing whiff. One slime landed nothing for 4 s in 2 of about 14 runs, with the same numbers each time.

**Measured** (the enemies suite and a scratch smoke harness, saving off):
- **Shield timing:** a bolt at the elite caster got its Guard up 0.38–0.45 s after the shot, inside its 0.35 s reaction plus a think. The shield took the hit.
- **Escaping:** caught, the regular caster blinked to 534 u. With its blink down it walked about 2 s, was cornered, then stood its ground and swung for the next 2.5 s.
- **The skirmisher's reset:** its leap hit, it hopped from 17 u to 377 u, then walked out to its band.
- **Think cost:** in the sandbox's mixed pack, thinks ran 200–340 µs (AI1 measured 130–230 in a fight). Perception and the extra uses cost a little; brains stay cheap.

**Sensitivity:** each key behavior was broken once on purpose and restored (diff-checked), and each failed its checks:
- defend in `decide()`, the reaction delay, the escape walk's clock, the skirmisher's commit end;
- the fall-back spot, the cone's angle, the escape blink's direction, a gap-closer ending a commit.

The first runs missed four of these, and new checks went in for them: a slime beside the Knight inside Cleave's reach, the plan's direction in the open, the fall-back spot, a brute with a missed leap.

**Smoke** (`sandbox_main`, `sandbox_main_layout`, `main_layout`; the saves backed up first, byte-identical after):
- The mixed pack: the brute holding, the skirmisher diving and resetting, the caster poking and cornered.
- Shift+H cycling the test enemies.
- room_01's slimes as before.

**Tests:** enemies 281/281 (61 new; 5 runs in a row green in parallel with other suites), view 469/469 (19 checks updated for the camera, 1 for the leap guard). Stats 180/180, combat 474/474, abilities 593/593, audio 110/110, champions 168/168, talents 310/310, loot 750/750: 3,335/3,335.

### AI2 – Groups: tokens, packs, the alert, the leash: 2026-10-04, Passed (Ryan's play test; he committed it)
Ryan passed AI1 and "roots are roots", started AI2, and answered three questions first:
- **The performance fix is a cap:** about 20 moving enemies awake per fight; no code change.
- **Every enemy with data plays the pack rules:** it notices any party member, the shout wakes its pack, and the leash runs from home. That replaces today's noticing and 800 u leash, which stay for enemies with no data.
- **ALLIES' names are approved:** the `threat` stat and the status tags `taunt`, `stealth`, `downed`. AI2 registers `threat`.
- **Code, new:**
  - `Pack` (`scripts/enemies/pack.gd`): members, a lazy home, the leash, `get_ring_spots()`.
  - The `threat` stat (registry: default 1, 0.1–10).
  - `sound_enemy_alert` (`data/sounds/`) over `audio/sfx/enemy_alert_01.wav` (synthesized in a GDScript tool; `audio/LICENSES.md` row).
- **Code, changed (additive):**
  - `brains.gd`:
    - The party is read once per tick (`get_party()` is cached), and the enemies with data are tracked (`register_enemy()`).
    - Attack tokens: `get_tokens_per_target()`, `get_token_cost()`, `request_token()` (the queue: patience, then the nearest; the rest), `release_token()`, `has_token()`, `get_token_holders()`, `get_tokens_free()`, `is_waiting_for_token()`, `get_token_rest_left()`.
    - Tokens are released each tick on a dead holder, a dead or untargetable target, a stun or root, or `token_hold_time`.
    - `shout()` and the alerts' delivery.
    - The fodder ring 5 times a second: one ring per target, with a kept angle and a crowding check.
  - `enemy.gd`:
    - `AI.RETURN`. An enemy with data joins its pack (its parent `Pack`, else a pack of one as its own child), registers with Brains, and plays `_physics_process_pack()`.
    - Noticing (`_notice()`: any party member in sight through WorldQuery, within `detect_range`, with a path), `_wake()` and the shout, `alert()`, and hits (`_on_damaged_pack()`).
    - The pick: `_update_pick()`, `can_pick()`, `get_effective_distance()`, `is_better_target()`, `get_taunter()`, and the AB10 chase.
    - Fodder: `_drive_fodder()` (its ring place, settling, the blocked fallback, the detour).
    - The walk home and recovery: `start_return()`, `_drive_return()`, `_arrive_home()`; +30% move speed under `enemy_return`.
    - The `alert` and `return` poses; a dead token holder frees its token at once.
    - New queries: `get_target()`, `get_pack()`, `get_pack_home()`, `get_home()`, `get_known()`, `is_target_reachable()`, `has_target_in_reach()`, `knows_party_inside_leash()`, `is_cc_blocked()`, `uses_fodder_ring()`, `set_ring_spot()`.
    - The old routine (no data) is untouched.
  - `enemy_brain.gd`:
    - A commit needs its tokens: at full patience it asks each think, and it releases them when the commit ends (then rests), when it doesn't commit after all, out of reach, and on a reset.
    - A lost token breaks a commit off (stunned: patience kept) or ends it.
    - A taunt commits without patience or a token.
    - `get_token_state()`; `decide()` reads `needs_token`, `has_token` and `taunted`.
  - `situation_context.gd`: `needs_token`, `has_token`, `waiting_for_token`, `tokens_free`, `taunted`, `home_position`, `home_distance_px`. `target_reachable` is real now.
  - `party_snapshot.gd`: a downed champion isn't up.
  - `enemy_ai_table.gd`: the groups Attack tokens, Fodder, Target pick, and Alert and leash. The .tres gets the alert sound; the other values are the script's defaults.
  - `events.gd`: `pack_alerted(pack, target)`.
  - `sandbox_brains.gd`:
    - H's two packs, 9 m away, on the floor, idle: `pack` (five test brutes) and `fodder` (eight slimes).
    - The overlay's token (held, waiting, rest) and its floor drawings: each pack's home and leash, token lines, fodder places.
  - `stats_test.gd`: the registry count, 26 → 27.
- **Changed during the step** (the rules are in ENEMIES_AI.md):
  - **The fodder ring is per target, over every pack, with fixed places.**
    - The places are anchored once per target and spread evenly, and each fodder takes the free one nearest it.
    - The first version centered the places on the fodder's mean angle each think. That turned every place as they walked, so settled slimes ended up off their places.
  - **The ring is at half the fodder's reach, not 0.7.** A slime's hit pushes the Knight 12 px. At 0.7 (10.6 px inside its reach), every hit pushed him out of its own reach.
  - **How a fodder holds its place:**
    - At its place (within 6 px), it keeps hitting from where it stands until its target leaves its reach.
    - Blocked short of its place for 1 s with its target in reach, it settles there.
    - Too close to another fodder, it walks back to its place.
    - When its place is more than 50° round the ring, it walks round the outside. A path straight through the Knight and the settled slimes got stuck in 2 runs of 6.
  - **Sight never wakes an enemy on a champion it has no path to.** Otherwise a pack below an unreachable spot woke, gave up after 6 s, walked home, and woke again every ~8 s. A hit still wakes it, and the leash then sends it home to heal (League's camps).
  - **A pack's home is set lazily:** its position the first time anything asks. A pack (or enemy) built in code and moved into place before its first tick is then right.
  - **A taunted brain commits on its taunter** without patience or a token (proposed; the doc only said it needs no token).
  - **The sandbox's packs stand on the floor** (the nearest point of its navigation). Aimed past a wall, a pack stood where nothing could reach it.
  - **Data enemies see through WorldQuery**, from the enemy's position. `_can_see_player()` and the `Sight` node stay for enemies with no data and for the naive loop.
- **Measured** (a scratch harness, saving off; the saves were byte-identical throughout):
  - `sandbox_main` and `sandbox_main_layout`:
    - A pack of five test brutes 9 m away stays idle until the Knight walks up, then wakes together.
    - Over 10 s, at most 2 tokens were held, with holders resting and rotating.
    - 14 m from home, all five walked home, and they were at full health (600) 5 s later.
    - Eight slimes each got a ring place.
  - `main_layout`: a slime chases the Knight and goes home when he leaves.
  - Think cost (headless, 12 brutes): mean 221 µs, p99 416 µs. The cap stands (Ryan), so no new budget.
- **Sensitivity:** each key behavior was broken once on purpose and restored (diff-checked), and each failed its checks:
  - The shout's delay, and the other packs' sight rule.
  - Stealth, and the switch hold.
  - A stunned holder's release, and the token cap (five brutes: 5 holders).
  - The ring bypassed, the detour (2 runs of 6 failed without it), and the immediate leash.
  - Noticing without a path.
- **Tests:** enemies 220/220 (89 new; 8 runs in a row green in parallel with other suites), stats 180/180 (1 new: threat), combat 474/474, abilities 593/593, audio 110/110, champions 168/168, talents 310/310, view 469/469, loot 750/750: 3,274/3,274.

### AI1 – The tooling and the brain skeleton: 2026-10-04, Passed (Ryan's play test; he committed it and started AI2)
Ryan started AI1 ahead of ALLIES' second champion and answered three questions first: ENEMIES_AI's names are approved as proposed ("rank" included); the brain overlay goes on **I** (the doc's B is SandboxAbilities' AB15 test blink); the elite slime gets its brain everywhere, room_01 included.
- **Code, new:**
  - Data (`scripts/data/`): `AIUse`, `EnemyBehavior` (the twelve sliders with their limits, the kind, `resolve()`), `BrainAdjust`, `RankRules`, `EnemyAITable` (`get_respect_value()`, `applies_cc()`), `EnemyAbilitySlot`, `EnemyData`, `PoseSet`, `PoseLook`.
  - Runtime: the `Brains` autoload (`scripts/autoload/brains.gd`, between Loot and Audio: the staggered schedule, `wake()`, the shared `PartySnapshot` once per tick, idle times, `difficulty_tier`, think stats), `UnitController` (`scripts/units/`), `EnemyBrain`, `SituationContext`, `PartySnapshot`, `BrainDecision` (`scripts/enemies/`), `CastPlan` (`scripts/abilities/`).
  - Tools: `SandboxBrains` (`scripts/rooms/`; I, N with its brain checkbox and Ctrl+S / Ctrl+Shift+S, H's six scenarios), in `sandbox.tscn` and `sandbox_3d.tscn`; `ScriptedController` (`scripts/tests/`); `enemies_test` (`scenes/tests/enemies_test.tscn`).
- **Code, changed (additive):**
  - `enemy.gd`: `data` and `_apply_enemy_data()` (stats and look before the Unit sets itself up; abilities by difficulty tier, the twist under `enemy_<id>`, the rank's tenacity under `enemy_rank`, the brain); `naive_casting`, `brain_enabled` / `set_brain_enabled()`; while its brain runs, the brain drives the aggroed enemy (`drive()`) and the naive loop never does; `get_brain()`, `is_brain_active()`, `get_brain_target()`, `get_rank_rules()`, `get_pose()`, `get_pose_progress()`, `get_pose_set()`, `get_face_point()`.
  - `ability.gd`: `ai_uses`, `respect_value` (an "AI" group), `get_ai_uses()`, `get_passing_intents()`, the default `get_ai_plan()`.
  - `condition.gd`: `Kind.RESPECT` (appended), `is_situation_kind()`, the optional `situation` argument on `is_met()`, `all_met()`, `first_failed()`.
  - `ability_component.gd`: `start_cooldown(slot)` (a test hook).
  - `unit_view.gd`: an enemy whose brain runs faces its target; the pose hooks (lean, squash, rim, `pose_blend_time` 0.08 s); `flash_overlay.gdshader` got a second instance channel, `rim`, brightest at the edge (the hit flash wins).
  - `slime.tscn`, `slime_elite.tscn`: their data. `project.godot`: the autoload.
- **Data:** `enemy_ai_table_default.tres` (four ranks), `enemy_behavior_brute.tres`, `pose_set_default.tres` (the fourteen poses of the minimum set), `enemy_slime.tres` (fodder), `enemy_slime_elite.tres` (an elite brute with the slam), `enemy_test_brute.tres` with `units/test_brute.tres`, `test_brute_q_smash.tres` (the slam's script: POINT, 0.7 s, 64 px, 80 damage) and `scenes/enemies/test_brute.tscn`. All generated by a scratch script through ResourceSaver.
- **Changed during the step** (the rules are in ENEMIES_AI.md):
  - **The hold keeps a distance.** Re-reading the current distance at every re-plan made the strafe cut chords and spiral in (258 u after 12 s); it now aims at the circle of its hold distance (421–423 u over the same 12 s). And when the Knight walks in on it, a holding brute holds its ground and swings back in reach; after its own commit it walks back out for up to 2 s.
  - **A commit's end:** its first cast ends, 2 landed basic attacks, or 4 s (the tell included); patience empties then.
  - **Only usable uses are gathered** each think (poke and zone; damage and gap-closer while a commit is possible): plans and `get_fail_reason()` are most of a think.
  - **RESPECT reads the party's respect** before the enemy's `respect_weight`, so a use rule means the same on every enemy.
  - **The derived crowd-control +1 reads data only** (a cc status among the ability's exports or bonus target statuses, or `stun_duration` > 0): Judgement gets it, Iron Resolve's script-applied slow doesn't, matching the doc's 10.5.
  - **Slider limits are float pairs**, not Vector2 (a Vector2 holds 32-bit floats: 0.2 clamped to 0.2000000030).
  - **Patience within 0.0001 of 1 is full** (twelve seconds of 0.1 s steps summed to 0.99999).
  - **Tests need a navigation region:** without one `move_to()` heads for the world's origin, which dragged the test brute through the Knight in the first run.
  - **The naive loop's own tests** (combat C5, abilities AB13's elite wall and the cleanup pass's "skips a failing slot") spawn the elite with no data, as the doc's "brain off" means.
  - A test that resets cooldowns ends after 120 frames: `Audio.stop_all()` leaves the UI bus, where the ultimate-ready ping plays.
- **Measured (the budget; ENEMIES_AI.md, Performance):** the sandbox (`sandbox_main`), the Knight standing invulnerable, enemies spawned around him and aggroed, 5 s per row after 1 s, a scratch harness bracketing every node's `_physics_process` (scripts' physics step), frame times between process frames, Brains' think stats. Headless and windowed on Ryan's 180 Hz screen gave the same step costs; the windowed rows:

  | Awake enemies | Scripts' physics step mean / p99 | Brains per tick | Frame mean / p99 |
  |---|---|---|---|
  | none | 0.66 / 0.99 ms | — | 5.56 / 8.6 ms |
  | 10 fodder | 1.33 / 1.73 | — | 5.56 / 8.6 |
  | 10 fodder + 5 brutes | 2.39 / 3.00 | 0.19 ms (0.8 thinks, 222 µs each) | 5.56 / 9.5 |
  | 10 fodder + 10 brutes | 3.87 / 4.51 | 0.27 ms (1.7 thinks, 163 µs) | 5.56 / 11.9 |
  | 25 fodder | 5.44 / 8.57 | — | 5.66 / 13.1 |
  | 25 fodder + 5 brutes | 7.06 / 10.39 | 0.18 ms | 6.55 / 14.2 |
  | 25 fodder + 10 brutes | 9.34 / 13.28 | 0.26 ms | 9.94 / 17.8 |
  | 50 fodder | 16.96 / 26.66 | — | 143 / 167 (the physics step can't keep up) |
  | 50 fodder + 10 brutes | 21.16 / 33.58 | 0.28 ms | 178 / 196 |
  | 50 fodder standing (passive) | 2.77 / 3.47 | — | 5.73 / 9.0 |
  | 50 fodder chasing, avoidance off | 6.82 / 16.42 | — | 8.17 / 20.3 |

  A think alone (a probe, 2,000 calls) costs 56 µs: the situation 35 µs, `decide()` 11 µs; the shared party read 60 µs once per tick; `get_fail_reason()` 30 µs per castable slot. **Brains aren't the limit; crowd movement is, and steering is about 60% of it.** Ryan picks the fix (ENEMIES_AI.md, Open after AI1).
- **Sensitivity:** each key behavior was broken once on purpose and restored (diff-checked), and each failed its checks: the brain branch in `Enemy._physics_process` (6 failures: the naive loop ran, the brute hit the Knight), the tell (2), the patience floor (7), RESPECT without a situation when negated (1), the hold distance (1, after the 12 s band check was added: the first version of the suite missed it), one snapshot per tick (2), the hit flash over the rim (view, 1).
- **Smoke runs** (scripted, saving off): `sandbox_main` and `sandbox_main_layout` (H through all six scenarios, I, N, `.`; the elite slime has its brain); `main_layout` loads with its brained elite. The saves were backed up first and stayed byte-identical through every run.
- **Tests:** enemies 131/131 (new), view 469/469 (12 new: enemy poses). Stats 179/179, combat 474/474, abilities 593/593, audio 110/110, champions 168/168, talents 310/310, loot 750/750: 3,184/3,184.

### Doc written and interview done: 2026-10-03, docs only
Docs only; no code or tests changed (the baseline stays 2,589/2,589).
- **The interview:** Ryan answered I1–I11 in three rounds, each as Claude proposed (ENEMIES_AI.md, Open questions; DECISIONS.md, Enemies): the twelve sliders; respect derived with an override, the ally at half within 10 m; 2 tokens per champion (3 at tiers 4–5); reaction 0.45 / 0.35 / 0.3 s, never under 0.2 s, elites trying 40–60% of dodgeable attacks; alert 0.4 s and 6 m, leash 12 m, home healing over 1.5 s; fodder in a ring 0.6 m apart; the pose set, the icon judged at AI-M; no flinch, tenacity 20% / 40%; the `EnemyBehavior` / `EnemyData` / `EnemyRoster` format; three boss phases as data; AI8 for support, summoner and sniper. Written into ENEMIES_AI.md (marked I1–I11; a Poise rule and build step AI8 added), DECISIONS.md, COMBAT.md (poise answered), DUNGEONS.md (the format, tokens, boss phases), ALLIES.md (tokens, the ally's respect weight) and CLAUDE.md.
- **`docs/ENEMIES_AI.md` written** from Ryan's decisions (his interview with the advisor, 2026-10-03): enemies exist to test the player; roles (fodder, brute, skirmisher, caster; later support, summoner, sniper) and ability counts; the brain (situation → intent → act, a pure function with a seeded random number generator; the naive cast loop behind a switch); intent tags and use rules on abilities as data; knowledge limited to the HUD; respect; patience and pokes; dodging for elites and bosses; tells as body language only; attack tokens; cornered casters; aggro, packs and the leash; role-based low health; spawning (placed packs, ambushes, spawn-in kept for arenas); elite modifiers; the boss director (phases, pressure and breather, punish, finish, reset); scaling by rank × faction × difficulty tier; performance (10 Hz, staggered, a measured budget in AI1); the tuning toolkit built first; headless scenario tests. Claude's proposals are marked *(proposed)*; the eleven interview items are listed in its Open questions. Build steps AI1–AI7, milestone AI-M and AI8, not started.
- **`docs/DECISIONS.md`:** 33 rows in the Enemies section (Ryan's twenty decisions, the doc written, his eleven interview answers, the interview done).
- **Doc edits applied:**
  - ALLIES.md: Tier B is ENEMIES_AI's AI1–AI2; `UnitController`, `CastPlan` and the default `get_ai_plan()` built in AI1, with `EnemyBrain` the first controller; one list of intent tags for both brains (`engage` renamed `gap_close`), data uses beside the per-ability method; `sense` is the `SituationContext`; the target pick's numbers in `EnemyAITable`; attack tokens per champion as the party-size hook; `ScriptedController` shared with AL1.
  - DUNGEONS.md: `DungeonData.roster` is an `EnemyRoster` (enemies, faction preset, elite modifier pool); the formats; `DifficultyTier.brain_adjust` and two proposed rows in the tier table (brains, attack tokens); ambushes as `Ambush`, spawn-in for arenas, waves waiting on Ryan; `BossDirector.reset()` for I8; its For other docs marked.
  - ABILITIES.md: What the AI uses an ability for (`ai_uses`, `respect_value`, which casts enemies can dodge); the planned `get_ai_plan()` and `get_effect_area()`; three planned condition kinds and the situation argument.
  - COMBAT.md: how enemies fight (ranks and roles, bands unchanged), tells before telegraphs, dodging enemies (not a random dodge chance), dash-answerable punishes; elite modifiers' pointer (format ENEMIES_AI's, count DUNGEONS'); poise or flinch as an open question.
  - WORLD_INTERACTION.md: ambush triggers; the `Sight` ray into WorldQuery in AI2; Used by.
  - COMPANIONS.md: kindling and companion drops onto `EnemyData` (AI7); enemies never see companions.
  - 3D.md: pose hooks on `UnitView`; the perched sniper; melee enemy attacks tagged `melee` (proposed); sleeping in AI7.
  - CLAUDE.md: the Docs index, Current status, Future docs.
- **Follow-up (2026-10-04):** Ryan confirmed spawn-in and kept waves deferred. ENEMIES_AI.md (Spawning; the conflict note answered), DUNGEONS.md (Fights: one group per arena; the arena edge case; its proposal 4 and its ENEMIES_AI note), DECISIONS.md (one Enemies row) and CLAUDE.md updated.
- **Not edited (proposed in ENEMIES_AI.md, Conflicts and notes):** CONVENTIONS.md (the names, the word "rank"), TALENTS.md and LOOT.md (their stand-ins retiring in AI7), VISION.md (Open question 7 answered). PROMPTS.md has no interview queue to update.

## Movement (MOVEMENT.md)

### Cleanup pass – the LoL legacy input deleted: 2026-09-29, Built (awaiting play test)
Steps 1 and 3–7 passed Ryan's play test, so the dormant LoL input goes (Ryan's call). Checked first that nothing else referenced any of it (scripts, scenes, tests; only the combat test's `select` check, now "the action is gone"). Deleted: the input actions `move`, `stop`, `attack_move`, `select` (`project.godot`); in `player.gd` the right-click move and its hold-to-repath, attack-move (and its range circle and cursor), stop and select handling, the `move_commanded` / `attack_commanded` / `attack_move_commanded` signals, `hold_repath_interval`, `attack_move_armed`, and the League-style windup handlers (`_on_windup_started`, `_on_attack_landed`, `_on_windup_cancelled`) with the League-windup branches of `_update_state()` (ATTACK) and `_update_facing()`; `AutoAttackComponent.attack_move()` with `attack_move_acquire_bonus` and its target search; `click_marker.gd`; main.gd's marker wiring (`_spawn_marker()` and the two handlers). Kept: `MovementComponent.move_to()` (enemies, R walking into range), the League-style attack (enemies), Esc cancelling an aim. `player.gd`'s header now lists the real controls. Also MOVEMENT.md: the dash-block conditions as `can_dash()` has them, the buffer waiting out a swing's breather, attacking dropping a queued walk-into-range cast, the League-windup ATTACK row (deleted) in the LoL-era table, the dash's peak vs. measured first-frame speed (≈1422 vs 1356 px/s), the bob rate at 120 px/s. Full suite: stats 179/179, combat 459/459, abilities 503/503, audio 109/109 (was 172 / 451 / 494 / 109 before the pass). `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors or warnings.

### Dash direction option (Settings, pause menu): 2026-09-26, Passed
Commit c136864 (Ryan's; it had no entry until 2026-09-29). The player chooses the dash direction: Cursor (default) or Move keys (WASD), in a new Esc pause menu (`PauseMenu`, `scenes/ui/pause_menu.tscn`, added by `main.gd`; pauses the tree; Esc or Resume closes it; an Esc that cancels an aim is marked handled by `player.gd`) and saved by a new `Settings` autoload (`user://settings.cfg`, `get_dash_direction()`, `setting_changed`). PlayerInput copies it into `dash_toward_cursor` at start and on every change. No test counts were recorded with the commit.

**Passed** (Ryan, covered by the M1 play test of 2026-09-26: "dashes fine").

### Dash toward the cursor: 2026-09-26, Passed
Commit d8140e9 (Ryan's; it had no entry until 2026-09-29). The dash goes toward the cursor as it was when Space was pressed (`Player.get_aim_direction()`, so `facing` with the cursor on the player); a buffered dash keeps the direction from its press. The old rule (the held WASD direction, or facing) stays behind `PlayerInput.dash_toward_cursor = false`. No test counts were recorded with the commit.

**Passed** (Ryan, covered by the M1 play test of 2026-09-26: "dashes fine").

### F3 – Movement feedback (VFX only): 2026-09-25, Built (awaiting play test)
The step as planned, then as built (moved from MOVEMENT.md, Feel pass). Where the plan and the build differ, the build and MOVEMENT.md win.

- **Dash:** stretch the Body along the dash direction (1.25 × 0.8) for 0.06 s, then ease back; squash it slightly (0.9 × 1.1) for 0.05 s when the dash ends; spawn 3–4 afterimages about 0.03 s apart, each fading over 0.15 s; a small dust puff at the start.
- **Walking:** a 1 px bob at a rate tied to speed, and a dust puff on a sharp direction reversal (more than 135°).
- **Knockback:** any displaced unit stretches along the push direction, scaled by its current speed.
- **Structure:** one reusable node in `scripts/vfx/`, named per CONVENTIONS. It listens to MovementComponent and DashComponent signals, has an on/off toggle, and exports every value. It must work on today's Polygon2D placeholders and on 8-direction sprites later. The F3 plan says whether pixel snapping makes the squash look jittery at 640×360.
- **Done means:** the effects are visible but never hide where the player actually is, and turning the toggle off gives exactly today's visuals.
- **Built** (awaiting play test):
  - `MovementVFXComponent` (`scripts/vfx/movement_vfx_component.gd`), the last child of `player.tscn` and `slime.tscn`. `enabled` turns everything off; every number is an export (groups Dash, Walking, Displacement, Dust). VFX only: it reads the components' signals and public state and never changes gameplay state. Dust uses its own random generator, so slime wander rolls don't change.
  - **How the Body is deformed:** only while the frame is drawn. It applies the deformation on `RenderingServer.frame_pre_draw` and undoes it on `frame_post_draw`, so code that writes `body.scale` / `body.position` (player flip and bob, slime squash, death tweens) never sees it, and player.gd, enemy.gd and unit.gd are unchanged. While enabled, the Body's own physics interpolation is off, or the deformation only shows partly; the unit itself stays interpolated, so F1 smoothness is unchanged. Deformation pivots on the feet (`deform_pivot`), so the feet stay on the shadow. The Shadow and the sword are never deformed.
  - **Dash:** stretch 1.25 × 0.8 (along × across the dash) held 0.06 s, eases back over 0.08 s; squash 0.9 × 1.1 when the dash ends, held 0.05 s, eases back over 0.08 s. 4 afterimages 0.03 s apart (the first at the start point), each fading over 0.15 s. They're flat cyan silhouettes (`afterimage_color`, 50%) drawn as one shape (a CanvasGroup), so they can't be mistaken for the half see-through player; `afterimage_silhouette = false` gives tinted copies instead. Each is placed where the unit was at the start of its physics frame, so it never shows up ahead of the player. They're copies of the Body, so sprites work too (as a still frame). A dust puff (6 specks flying 14 px back, flattened ×0.5 onto the floor, 0.3 s) at the start.
  - **Walking:** a 1 px bob, one per 40 px walked (about 4.5 a second at 179 px/s, today's cadence; faster when hasted). While enabled it replaces player.gd's 2 px bob (`replace_existing_bob`). Reversal dust: a turn of more than 135°, after the old direction reached 90 px/s, within 0.1 s of walking it (so letting go and pressing the other way counts), at most every 0.15 s. With 8-way keys a full reversal counts; exactly 135° (right → down-left) doesn't.
  - **Knockback:** any displacement that isn't the unit's own dash (knockback, pulls, Lunge) stretches along the push by 1 + 0.0005 × speed (px/s), up to 1.3; across = 1 / along. Cleave's knockback (407 px/s peak) gives 1.2; Lunge starts at 1.3 and eases out with its speed. It reads `is_displaced()` and the unit's velocity every frame instead of a new signal (the stretch follows the speed anyway), so MovementComponent is unchanged.
  - **Slimes:** walk bob and reversal dust off (they have their own hop); knockback stretch on.
  - **Pixel snapping:** the squash doesn't jitter. `snap_2d_transforms_to_pixel` is off since F1, so the deformation scales smoothly (edges move in half-game-pixel steps at 1280×720). With 8-direction pixel sprites, a non-integer scale draws some art pixels one screen pixel wider than others for the ~0.15 s an effect lasts. That's the normal look of squash and stretch on pixel art and hard to see at that length; if it shows, pick stretch values that land on whole pixels or turn the deformation off for that unit.
  - Measured at 144 fps: the stretch holds 8 frames and is gone 0.13 s into the dash; the squash holds 7 frames and is gone 0.12 s after the dash; 4 afterimages and 1 dust puff, all gone 0.12 s after the dash ends. With `enabled` off, 859 frames (walk, dash, reversal, dash down, Cleave knockback, Lunge) are pixel-identical to before F3. Walking shake (F1 metric) 0.03 px (0.04 before). The Knight's abilities, chasing and the HUD checks pass.

### F4 – Camera aim lead rework (ran before F3): 2026-09-25, Built (awaiting play test)
The step as planned, then as built (moved from MOVEMENT.md, Feel pass). Where the plan and the build differ, the build and MOVEMENT.md win.

- **Problem (play testing):** the locked camera moves too much when the cursor moves. The lead should help aim at enemies slightly off screen, not follow every mouse movement. Causes in the current code:
  - No dead zone: any cursor movement shifts the camera.
  - The lead is 64 px on both axes, but the screen is 640×360, so vertically it's over a third of the half-screen.
  - The lead uses the same position smoothing (10) as the player follow, so it can't be slower without making the follow laggy.
  - The lead is measured in screen space, so when the camera leans, the world point under a still cursor slides.
- **Changes** (all `@export` on GameCamera, additive; `aim_lead` keeps its name and meaning as the horizontal maximum):
  1. **Dead zone:** no lead while the cursor is inside `aim_lead_dead_zone` = 0.35 of the half-screen, measured as an oval (x and y each divided by their own half-size).
  2. **Response:** from the dead zone edge to `aim_lead_full_at` = 0.9, the lead follows a Curve (`data/curves/curve_camera_lead.tres`, ease-in quad). Full lead beyond that.
  3. `aim_lead_y_scale` = 0.6 for the vertical lead.
  4. The lead eases toward its target at its own rate, `aim_lead_smoothing` = 4.0 per second (frame-rate independent). The follow smoothing stays at 10.
  5. **Context:** full lead while the player is aiming or casting an ability (and in ATTACK once COMBAT exists); `aim_lead_idle_scale` = 0.3 otherwise. Read through the Player's public state (`Player.state` / `is_in_state()`, `aiming_slot`). No new coupling beyond the camera's existing target.
  6. `move_lead_px` = 0 (off): an optional lean in the walking direction, blended the same way. Try 12–16.
  - Holding C still centers with no lead. Shake, bounds and `snap_to_target()` behave as now.
  - `debug_draw` on GameCamera: the dead zone oval, the target lead, and the current lead.
- **Done means:**
  - Moving the cursor inside the dead zone doesn't move the camera.
  - Flicking the cursor corner to corner moves the camera over about half a second, with no whip.
  - Walking without aiming barely leans; holding an aimed ability toward an off-screen dummy leans fully.
  - F1 smoothness is unchanged (no new stutter).
  - The Knight's abilities, enemies chasing and the HUD still work.
- **Built** (awaiting play test). Additions agreed with Ryan: `aim_lead_hold_time` = 0.75 s (full lean stays this long after the last aim or cast, so it doesn't swing back between casts, and so QUICK cast mode still gets it); `aim_lead_smoothing` stays 4.0.
- **Aim drift (accepted):** the world under a still cursor still slides whenever the lean changes. Full lean starts when you begin aiming, so while you hold an ability still, the spot under the cursor can move up to 80 px sideways / 48 px vertically over about 0.7 s (64 / 38 px when first measured), and a POINT ability like Lunge lands where the cursor is at release. Accepted because the indicator always shows the true landing spot (clarity), and the lean only grows outside the dead zone and while aiming. Revisit if play testing shows mis-aims.
- Measured at 144 fps with `aim_lead` = 64 px, before it was raised to 80 (camera movement = how far the world under a still cursor slides, game px; lean amounts now scale by 80/64 = 1.25, timings don't change):

  | Test | Today | F4 idle | F4 aiming |
  |---|---|---|---|
  | Cursor center → right edge, held still | 64 px, 90% in 0.23 s, peak 648 px/s | 19 px, 0.69 s, 72 px/s | 64 px, 0.68 s, 144 px/s |
  | Cursor center → bottom edge | 64 px, 0.22 s | 11.5 px, 0.67 s | 38 px, 0.68 s |
  | Small moves inside the dead zone | 12–16 px each | 0 | 0 |
  | Flick corner to corner | 128 px diagonal, 0.22 s, peak 1274 px/s | 31 px, 0.68 s | 105 px, 0.69 s, peak 260 px/s |
  | Walking shake (F1 metric) | 0.03 px | 0.03 px | – |

### F2 – Displacement curves: 2026-09-25, Built (awaiting play test)
The step as planned, then as built (moved from MOVEMENT.md, Feel pass). Where the plan and the build differ, the build and MOVEMENT.md win.

- **MovementComponent:** a displacement follows a progress `Curve` (x = time 0–1, y = share of the distance covered 0–1). Each physics frame it moves `total_offset × (p(now) − p(previous frame))` through `move_and_slide()`. The total distance stays exactly velocity × duration, so current distances don't change; only the speed profile does.
- **Additive API:** an optional `curve: Curve = null` parameter on `displace()` and `dash()`. `null` = linear, today's behavior.
- **Curves** are .tres files in `data/curves/` (`curve_dash.tres`, `curve_knockback.tres`), editable in the Inspector's curve editor. Starting shapes: dash = ease-out quad (peak speed about 2× average, roughly 1420 px/s on the first frame, easing to 0); knockback = ease-out cubic (hard burst, fast settle).
- **Knockback default:** MovementComponent gets a `knockback_curve` export, used when `displace()` is called without a curve. The F2 plan lists which existing callers that changes.
- **Lunge:** a curve export on its Ability, set to `curve_dash.tres`. The F2 plan says whether Lunge's hit logic depends on constant speed.
- **Dash exit:** a `carry_into_run` export on DashComponent (default true). If a direction is held when the dash ends, walking starts at full speed instead of ramping up from 0. The F2 plan recommends how this interacts with `end_lag` (0.05 s of locked walking after a dash).
- **Debug:** `debug_draw` on MovementComponent draws a graph of the last 1 s of speed (px/s) above the unit.
- Stuns, walls and `displacement_finished` behave exactly as they do now.
- **Done means:** the dash still covers exactly 128 px (the cracked tiles); the speed graph shows a burst and then an ease-out; there's no visible pause between the dash and running; knockback on slimes bursts and then settles.
- **Built** (awaiting play test):
  - `null` means different things on the two methods: `dash(..., curve = null)` = constant speed; `displace(..., curve = null)` = `knockback_curve`. So knockback eases by default and existing dash callers can opt in.
  - Progress is normalized (`(p(t) − p(0)) / (p(1) − p(0))`), so a hand-edited curve that doesn't run exactly 0 → 1 still covers the full distance.
  - Defaults are set in the scripts, so every unit gets them: `MovementComponent.knockback_curve` = `curve_knockback.tres` (ease-out cubic), `DashComponent.dash_curve` = `curve_dash.tres` (ease-out quad). Lunge's `dash_curve` is set in `knight_e_lunge.tres`.
  - Callers whose speed profile changes: Cleave's knockback (`cleave.gd`, 17 px over 0.1 s) and Hurtbox knockback (`Unit._on_hurtbox_hurt`, no Hitbox uses it yet) now use `knockback_curve`. The dash and Lunge use `curve_dash`. Distances are unchanged.
  - Lunge's hits don't depend on its speed: they're found along the segment from the start point to the end point after the dash. Only its afterimages (spawned every 2 physics frames) now bunch toward the slow end.
  - **Dash exit:** if a direction is held when the dash ends, walking starts at full speed and `end_lag` is skipped. If no direction is held, `end_lag` (0.05 s) still locks walking, which plants the stop.
  - **Speed graph:** `debug_draw` on MovementComponent draws the actual distance moved per physics frame (so walls show), over `debug_graph_time` = 1 s, scaled to `debug_graph_max_speed_px` = 1500 px/s.
  - Measured: the dash covers 128.0 px in 11 frames at 1356 → 1225 → 1093 → … → 171 → 42 px/s, then runs on at 179 px/s the very next frame. Cleave knocks a dummy 17 px at 407 → 269 → 160 → 79 → 27 → 3 px/s. Lunge still covers 128 px and hits. A dash into the pillar stops exactly as before.

### F1 – Smooth frames: 2026-09-25, Built (awaiting play test)
The step as planned, then as built (moved from MOVEMENT.md, Feel pass). Where the plan and the build differ, the build and MOVEMENT.md win.

- **Problem:** physics runs at 60 Hz with no physics interpolation, `snap_2d_transforms_to_pixel` is on, and the camera uses position smoothing (speed 10). At 179 px/s the player moves about 3 px per tick, which stutters, especially on monitors above 60 Hz.
- **Scope:** investigate and recommend one option among 2D physics interpolation, the camera's process callback, the physics tick rate, and pixel snapping.
- **Done means:** walking along the sandbox's long wall and dashing back and forth show no visible stutter at 60 Hz or at Ryan's monitor refresh rate (144 Hz), and the pixel art stays crisp.
- **Built** (awaiting play test):
  - `project.godot`: `physics/common/physics_interpolation` on; `rendering/2d/snap/snap_2d_transforms_to_pixel` off. Physics stays at 60 Hz. (Godot turns `physics_jitter_fix` off by itself when interpolation is on.)
  - Camera: `process_callback` = Physics on the Camera node in `main.tscn`. Godot forces this when interpolation is on and prints a warning otherwise. The follow logic in `game_camera.gd` stays in `_process`; moving it to `_physics_process` measured no smoother.
  - `GameCamera.snap_to_target()` calls `reset_physics_interpolation()` before `reset_smoothing()`, and again after the first physics tick. Without it the camera slides in from the top-left corner at every scene start.
  - **Teleports:** anything that moves a node instantly (respawn, blink) must call `reset_physics_interpolation()` on it, or it visibly slides to the new spot.
  - Measured with Godot's movie recorder, walking at full speed (on-screen shake of the player, screen px; 2 screen px = 1 game px): before 5.4 at 144 fps (the player moved on only 42% of frames); after 0.04 at 60, 75, 144, 165 and 240 fps. The world scrolls with about 0.2–0.9 px of unevenness, which is rounding to whole screen pixels. Keeping snapping on with interpolation left a 0.86 px shake at 144 fps.
  - Sprites can now sit half a game pixel off the tile grid. They stay sharp (nearest filtering; no blended colors in test captures).
  - Known limit: the screen shows each physics state up to one tick (≤16.7 ms) later than before.

### Feel pass intro (as planned)
Movement works but feels robotic: displacements run at constant speed and there's no on-screen feedback. Goal: closer to Hades. Dashes and knockback burst and then ease out, frames are smooth, and movement has visible weight. Every number here is a starting point and must be an `@export` or live in a .tres. Runs before step 8 (see Build order). For every F step, the Knight's 4 abilities, enemies chasing, and the HUD still work.

### Steps 1, 3–7: 2026-09-25, Passed
1. **Built**: input map + WASD walking, done together (after the input map alone the player had no walk input). PlayerInput, `set_input_direction()`, `use_steering = false` on the player, Knight 560 move speed, scaled soft cap exports, LoL threshold overrides on `slime.tscn`.
2. *(merged into step 1)*
3. **Built**: facing and aim.
4. **Built**: camera aim lead.
5. **Built**: player states.
6. **Built**: dash with charges, i-frames, end-lag and chaining.
7. **Built**: input buffer, dash cancels (`Ability.dash_cancelable`), and the dash-strike hook.

**Passed** (Ryan's play test, reported 2026-09-29).

## Stats (STATS.md)

### Cleanup pass (audit fixes): 2026-09-29, Built (awaiting play test)
- **Scoped modifier keys are validated** (`StatsComponent._is_valid()`): an `ability:` / `tag:` modifier must name a number `@export` of the Ability base class or a param of an ability the unit holds that the scope reaches (`_is_known_ability_param()`), and any scope kind other than `ability:` / `tag:` / `hit:` / `target:` is rejected; a rejected modifier `push_error`s and isn't added (STATS.md's "never a silent 0"). Checked: nothing in the game or the tests adds such a modifier out of order (every suite passes).
- `knight.tres` `life_steal` back to 0 (zero sustain; the file no longer sets it). The docs now say the Knight and slimes rely on the default for `health_regen` (neither file ever set it).
- Deleted: `StatsComponent.get_attack_interval()` (AutoAttackComponent's is kept; the stats test's check moved to the combat test and was replaced by an `attack_speed` check), `UnitStats.display_name` (nothing read it; removed from `knight.tres`, `slime.tres`, `slime_elite.tres`).

Stats test 179/179 (7 new: a misspelled key under `ability:`, `tag:` and `target:`, a misspelled scope kind (`abilty:`), a subclass param no held ability has, all rejected; the same modifier spelled right kept; nothing else changed. The header now expects 8 push_errors). Full suite: stats 179/179, combat 459/459, abilities 503/503, audio 109/109 (was 172 / 451 / 494 / 109 before the pass). `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors or warnings.

### Step 6 – Scoped modifiers: 2026-09-26, Built (awaiting play test)
Scoped modifiers, `get_ability_param`, and `id`/`tags` on Ability. Route cooldowns through it. *(done: also `cast_range`, `base_damage`, `ad_ratio`; stats test 157/157 with a fake item (+30% Lunge range, −1.5 s Cleave cooldown, ×1.5 base damage on `area` abilities) that restores every param and stat exactly when removed; combat test 269/269 checks it on real casts)*

Later stats test counts: 172 from COMBAT C8 (2026-09-26; 15 new checks: the 5 new stats in the registry and base values, and the hit-scoped modifiers), 179 from the cleanup pass (2026-09-29, above).

### Step 5 – ResourceComponent: 2026-09-25, Built (awaiting play test)
ResourceComponent, plus the new stat fields on UnitStats. *(done: neutral defaults; HealthComponent follows max_health and regens; ResourceComponent on the Knight only; tested in `stats_test.tscn`)*

### Step 4 – Migrate reads: 2026-09-25, Passed
**Migrate reads.** *(done; checked headless against the old formulas for every Unit in the sandbox and room_01)* Every `stats.` read in the code before the migration:

| File | Reads | After step 4 |
|---|---|---|
| `units/unit.gd` `_ready()` | `max_health`, `move_speed` | `get_stat` |
| `units/unit.gd` `get_gameplay_radius_px()`, `get_pathing_radius_px()` | `gameplay_radius`, `pathing_radius` | stay on UnitStats (not stats) |
| `components/auto_attack_component.gd` `get_attack_speed()` | `base_attack_speed`, `attack_speed_cap` (+ its own `bonus_attack_speed`) | `get_stat(&"attack_speed")`; the cap is the stat's per-unit max |
| `components/auto_attack_component.gd` `get_windup_time()` | `attack_windup` | stays on UnitStats (not a stat) |
| `components/auto_attack_component.gd` `get_range_px()` | `attack_range` | `get_stat` |
| `components/auto_attack_component.gd` `_land_attack()` | `attack_damage` | `get_stat` |
| `components/ability_component.gd` `get_cooldown_duration()` | `ability_haste` | `get_stat` |
| `components/dash_component.gd` (max charges) | `dash_charges` | `get_stat` |
| `abilities/ability.gd` `get_damage()` | `attack_damage` | `get_stat` |
| `main.gd` `_process()` (HUD info line) | `player.stats.attack_damage`, `attack_range` | `get_stat` |

Also move MovementComponent's speed modifiers into StatsComponent (`add_speed_modifier` becomes a thin wrapper, so existing callers keep working). MovementComponent itself reads no `stats.` field; `Unit._ready()` calls `movement.set_stats_component()`, and MovementComponent reads `get_stat(&"move_speed")` live.

**Passed** (Ryan, 2026-09-27).

### Step 3 – StatsComponent on the scenes: 2026-09-25, Passed
Add StatsComponent to player.tscn and slime.tscn. `Unit._ready()` wires it up. *(done: `Unit.stats_component`, a required child like HealthComponent)*

**Passed** (Ryan, 2026-09-27).

### Steps 1–2 – StatModifier, registry, StatsComponent: 2026-09-25, Passed
1. StatModifier and the registry. *(done)*
2. StatsComponent with the math, move_speed rules, caching, and `stat_changed`. Include a test scene that adds/removes modifiers and prints the results. *(done: `res://scenes/tests/stats_test.tscn`, F6. It prints PASS/FAIL per check and includes move_speed parity checks against a real MovementComponent.)*

**Passed** (Ryan, 2026-09-27).

## Talents (TALENTS.md)

### Milestone T-M – A Knight's talent career: 2026-10-03, Passed
Ryan's play test of the talent loop from TALENTS.md's Build order (the first unlock within the first runs, tiers reading as choices, two loadouts playing differently) passed, reported 2026-10-03 after the 3D pivot's cleanup. A play test only: nothing was built or changed for it.

### T5 – The hub (functional): 2026-09-30, Passed
- **Hub** (`scenes/ui/hub.tscn`, `scripts/ui/hub.gd`, built in code): the header ("Knight   Level 2: 30 / 1000 XP   Talents 1 / 1"; "Level 12 (max)" at the top), the talent screen, a detail line (the hovered talent's description), Start run (`main.tscn`), Sandbox (`sandbox_main.tscn`), Clear talents, and the debug row (+1 level, +100 uses, +100 kills, Unlock all, Reset; `debug_tools` on in `hub.tscn`). `project.godot`'s main scene is the hub (F5).
- **TalentScreen** (`scripts/ui/talent_screen.gd`): five columns (Q Cleave, W Iron Resolve, E Lunge, R Judgement, PASSIVE Unbroken), tiers top to bottom with "Tier n — pick one", every talent a button: [ON] gold, available white, [LOCKED] grey with each requirement's live count ("— met" when met), [BLOCKED] rust with the reason ("No talent points left", "Needs a tier 1 Lunge talent"). Clicks go through `Progress` (the record's rules, then a save).
- **Pause menu**: Back to hub (under Resume): closes the menu, saves, changes scene (`PauseMenu.hub_scene`).
- **Progress**: `debug_add_ability_uses()`, `debug_add_kills()`, `debug_unlock_all()`.
- **Changed from the plan to fit 640×360** (checked in a rendered frame, `--write-movie`): siblings stacked, not side by side; descriptions in the detail line on hover, not in each box; "— met" instead of a ✓ (Open Sans has none).
- **Measured** (talents test): a fresh record: 20 talents all locked, "Thrifty Edge  [LOCKED] / Champion level 1 / 2 / Cleave casts 0 / 200", a locked click does nothing; +1 level → "Level 2: 0 / 1000 XP", the level line marked met; +200 uses → Cleave's tier 1 available, tier 2 locked; a click puts Thrifty Edge in (Talents 1 / 1); Quick Footing then blocked ("No talent points left"); Long Reach swaps Thrifty Edge out; the record holds it. Unlock all + 4 levels → "Level 6: 0 / 2600 XP   Talents 1 / 3"; Whirling available, Tackle blocked ("Needs a tier 1 Lunge talent"); taking Long Reach out drops Whirling; Clear empties; hover shows the description; at 12: "Level 12 (max)   Talents 0 / 5"; Reset back to level 1. The main scene is the hub; the pause menu has Back to hub.
- Talents 308/308 (23 new). Stats 179/179, audio 109/109, champions 168/168. Abilities 558/559: "emitted as cast_mode" fails because Ryan's real `user://settings.cfg` holds `cast_mode="quick_with_indicator"` (set in a play test), so the test's first change is a no-op; the test reads real settings (an existing fragility, not T5). Combat 456/459 (the real-time hitstop family). The hub, `sandbox_main.tscn`, `main.tscn` and F5 run headless with no errors or warnings; no suite touched the real progress save.

**Passed** (Ryan, 2026-10-01).

### T4 – Progress: counters, XP, levels, unlocks, the loadout rules, saving: 2026-09-30, Passed
- **ChampionLeveling** (`scripts/data/champion_leveling.gd`, `data/champion_levelings/champion_leveling_default.tres`): `xp_to_next` [600 … 4600] (max level 12), `talent_points` [1,1,2,2,2,3,3,3,4,4,4,5], `xp_by_unit` {slime 5, slime_elite 40} (temporary, until ENEMIES_AI.md). `ChampionData.leveling` (null = the default) and `get_leveling()`.
- **ChampionProgress** (`scripts/talents/champion_progress.gd`, RefCounted): level, XP-into-level, ability uses, kills, kills by tag, unlocked, loadout; `add_xp()` (several levels at once; at the max XP keeps adding up), `refresh_unlocks()` (kept once earned), the loadout rules (`get_loadout_fail_reason()`: locked / no points / needs tier n; `add_to_loadout()` swapping an exclusive sibling; `remove_from_loadout()` dropping orphaned deeper tiers; `clear_loadout()`), `sanitize_loadout()` (unknown, locked, duplicate, second sibling, orphan, over the points; a warning each), `write_to()` / `read_from()` a ConfigFile section. `TalentRequirement.get_current()` / `is_met()`.
- **Progress** autoload (`scripts/autoload/progress.gd`, registered before Audio in `project.godot`): records per champion, the lazy read of `user://progress.cfg`, `track()` / `untrack()`, counting from `Events.ability_cast` and `Events.unit_died`, `add_xp()`, the loadout calls, `reset()`, `get_kill_tags()` (none), the save triggers (a level, an unlock, a loadout change, the tracked player leaving the tree, the window closing), and the test-scene guard.
- **Player**: tracks itself in `_attach_champion()`; the loadout is the record's unless `talent_loadout` names one. **HUD**: `show_progress_line()` for level-ups and unlocks.
- **Measured** (talents test): 599 XP stays level 1, 600 → 2; 2450 more → level 4 with 50 in; at 12 XP keeps adding up. 199 Cleave casts at level 2 unlock nothing, the 200th both Cleave tier 1s; 150 kills both Unbroken tier 1s; a retune to 5000 casts keeps Thrifty Edge unlocked (a fresh record needs the 5000). Loadout: 1 point at level 1, a sibling swaps with no point free, 3 points at level 6, Rending swaps Whirling, Tackle without a Lunge tier 1 → "needs tier 1", removing Long Reach drops Rending, clear empties. Sanitize: 8 saved ids → 2 kept, 6 warnings; a tier 2 listed before its tier 1 is kept. Save round trip keeps every field. Live: a Cleave +1 use; a free Lunge, an interrupted Judgement: none; a Cleave Wave counts as Cleave; slime 1 kill + 5 XP, elite + 40; a passive dummy and a no-source kill: nothing; the player leaving the tree untracks. 1600 XP: signals for levels 2 and 3, the HUD line "Knight reached level 2 / Knight reached level 3: +1 talent point", cleared after 2 s; the 200th Cleave mid-run: both unlock signals and "Talent unlocked: …". The record's loadout attaches (Cleave costs 15); a Player's own list overrides it; respec leaves none.
- **The save guard**: no `user://progress.cfg` existed before or after all six suites ran; inside a test scene `saving_enabled` turns off, `save()` writes nothing, and writes only when a test turns it on with a test path (then deletes it). A headless 600-frame run of `sandbox_main.tscn` and `main.tscn` writes the save on exit (a fresh `[knight]` section, level 1), as designed; it was deleted after, since Ryan had none.
- Talents 285/285 (56 new). Stats 179/179, abilities 559/559, audio 109/109, champions 168/168. Combat 457/459 (the same two real-time hitstop checks as before T1). Both scenes run 600 frames headless with no errors or warnings.

### T3b – Tooltips say what the ability does now: 2026-09-30, Passed
- Ryan, after T3's play test: Bulwark's Iron Resolve tooltip still said "your next attack… deals bonus damage". Claude judged it worth fixing before T4 (clarity, VISION.md priority 2; T5's hub will list these talents).
- `Talent.ability_description` (Q/W/E/R; validation refuses it in PASSIVE); `Talent._on_added()` / `_on_removed()` put it on and take it off the slot's own ability. `AbilityComponent.set_description_override()` / `remove_description_overrides_from()` / `get_description_override()` (exact ability id; the last added wins; `augments_changed` emitted). `Ability._fill_template()` uses the override. `get_augment_tooltip_lines()` leaves out a FLAG or EVENT line when every source granting it has rewritten the text. Texts for Whirling Cleave, Rending Cleave, Challenge, Bulwark, Tackle, Executioner, Shockwave.
- `Ability._ratios_text()` leaves out a scaling term at 0, as its comment said (Shockwave showed "+0% of the target's missing health").
- Talents test +16: Bulwark's W loses "next attack" and its own augment line, shows the shield and keeps the haste, and comes back on removal; Shockwave's R shows the splash and no missing-health term, which returns without it; all seven texts resolve every placeholder; Cleave Wave keeps its own text with the talent's line under it while Cleave shows the rewrite; `ability_description` in PASSIVE is refused. Stats, abilities, audio, champions unchanged (all pass).

### T3 – The Knight's set, part 2: the six FLAGs: 2026-09-30, Passed
- **Six FLAG talents**, the last of the Knight's 20 (all in `knight.tres`, ordered by group and tier): Whirling Cleave, Rending Cleave, Challenge, Bulwark, Tackle, Shockwave; their FLAG augments `augment_cleave_whirl`, `augment_cleave_rend`, `augment_iron_resolve_challenge`, `augment_iron_resolve_bulwark`, `augment_lunge_tackle`, `augment_judgement_shockwave` in `data/augments/`; `supported_flags` on Cleave, Cleave Wave, Iron Resolve, Lunge (with `lunge_stuns`) and Judgement.
- **cleave.gd**: `cleave_whirl` hits a circle around the Knight (radius = the reach) with a ring VFX and a circle indicator; `cleave_rend` narrows the cone to `flag_rend_half_angle_deg` (25°). The indicator reads the caster's flags. The numbers are the talents' scoped modifiers (Whirling: reach × 0.75, damage × 0.85, no knockback, and for the wave +7 projectiles at +30° spread; Rending: reach × 1.4, damage × 1.35, and for the wave width × 0.4). **cleave_wave.gd**: lists both flags; its take is that data (no code).
- **iron_resolve.gd**: `iron_resolve_challenge` Staggers every enemy within `flag_challenge_radius` (300 u, in sight) instead of the haste; `iron_resolve_bulwark` gives a `flag_shield_amount` (120) shield instead of the empower.
- **lunge.gd**: `lunge_tackle` picks the first enemy in the path at the effect start, stops at its edge, hits only it and stuns it `flag_tackle_stun_duration` (0.75 s); with `lunge_stuns` too, one stun, the longer. The path query moved into `_in_path()` (the same filter as before).
- **judgement.gd**: `judgement_shockwave`: after the target's hit lands, every other enemy within `flag_shockwave_radius` (250 u) of it, in sight from it, takes `flag_shockwave_damage_ratio` (0.5) of the damage and a `flag_shockwave_stun_duration` (0.5 s) stun plus the Fury bonus's extra stun; the Fury is still consumed once.
- **ability.gd** (Ryan's OK, mid-step): `hit_units()` gets optional `damage_ratio` and `crit_roll`. The first Shockwave build resolved the splash itself; the abilities test's AB11 check ("no own crit roll or resolve" in the Knight's scripts) caught it, 558/559, deterministic.
- **Measured** (talents test, crits off where damage is compared): Whirling Cleave hits 50 px in front and behind, not 125 px; reach 225 u; 85% damage; the front dummy doesn't move (the plain Cleave's does). Rending Cleave hits 140 px ahead, not 55° off the aim at 70 px (the plain Cleave the reverse); reach 420 u (525 with Long Reach); × 1.35 damage. Whirling Wave: 8 waves at 45°, 525 u, a dummy 100 px behind hit; Rending Wave: 1 wave, 60 u wide, 980 u. Challenge Staggers at 60 px, not 150; no haste, the empower kept. Bulwark: a 120 shield, the haste kept, no empower. Tackle: only the first of two dummies hit, stunned 0.75 s, still Staggered, the Knight stopped short of it; with nobody in the path the full 128 px. Shockwave: the target 214 (no missing-health damage at 90% health), the splash at 45 px 50% of it and stunned 0.5 s, nothing at 130 px; at 70 Fury the target 1.25 s, the splash 1.0 s, 50% still, all Fury consumed.
- **Test fixes found on the way**: T2's Executioner check now cancels the Knight's 25% crit chance (a crit killed the 280-health dummy at 70 Fury: no stun on the dead; 1 run in 4); the talents test stops all audio before it quits (Shockwave's last hit sound was still playing at exit: "1 resources still in use").
- Talents 213/213 (58 new; three runs). Stats 179/179, abilities 559/559, audio 109/109, champions 168/168. Combat 457/459 (the same two real-time hitstop checks as before T1). `sandbox_main.tscn` and `main.tscn` run 600 frames headless with no errors or warnings.

### T2 – The Knight's set, part 1: 2026-09-30, Passed
- **14 talents** in `data/talents/` (`talent_knight_<name>.tres`), listed in `knight.tres` (`ChampionData.talents`): the 10 tier 1 (Thrifty Edge, Long Reach, Quick Recovery, Battle Cry, Long Lunge, Quick Footing, Swift Verdict, Long Arm, Bloodrage, Thick Skin) and the 4 data-only tier 2 (Twin Lunge, Executioner, Battle Trance, Stalwart), with the numbers and requirements in TALENTS.md (level 2 + 200 / 75 / 90 / 20 uses or 150 kills; level 6 + 1800 / 750 / 900 / 180 uses or 1500 kills). Battle Cry's EVENT augment (id `knight_battle_cry`, an ABILITY_CAST rule → RestoreResource 15 on the caster) is inline in its talent; Executioner reuses `augment_judgement_reset.tres`.
- **Code:** one change, in `judgement.gd`: a stun of 0 s or less isn't applied (Executioner multiplies `stun_duration` by 0; the Fury bonus's +0.5 s still lands on top). Every other talent is data the existing param paths already read (`cast_range`, `cooldown`, `resource_cost`, `max_charges`, `target_missing_health_ratio`, `stun_duration`, StatScalings).
- **Sandbox:** `SandboxAbilities.demo_charges` off in `sandbox.tscn` (it gave Lunge a second charge, which would hide Twin Lunge's). The code and its default stay. No test read it.
- **Measured** (talents test, the Knight at 64 AD, 650 health): Cleave cost 20 → 15, reach 300 → 375 u (Cleave Wave 700 → 875); Iron Resolve cooldown 8 → 6.5; Lunge range × 1.25, cooldown 8 → 6; Twin Lunge 2 charges at × 0.65 range (× 0.8125 with Long Lunge), both usable back to back; Judgement cooldown 30 → 24, range × 1.3; Battle Cry 0 → 15 Fury per Iron Resolve, and nothing once removed; Executioner: ratio 0.4, no stun below 60 Fury, 0.5 s at 70, a kill resets R; at 20% health Bloodrage 99.2 AD, Thick Skin +30 armor, Battle Trance 64 AD and attack speed × 1.5, Stalwart 64 AD, +60 armor, +0.3 tenacity, Battle Trance + Bloodrage 73.6 AD; at full health none of them change anything.
- Talents test 155/155 (85 new: the data of each talent, siblings never sharing a stat, each talent's effect). Stats 179/179, abilities 559/559, audio 109/109, champions 168/168; combat 457/459 (the same two real-time hitstop checks as before T1). `sandbox_main.tscn` and `main.tscn` run 600 frames headless with no errors or warnings.

### T1 – Talent framework: 2026-09-30, Passed
- **ToolkitBundle** (`scripts/data/toolkit_bundle.gd`): `Passive`'s fields and `apply_to()` / `remove_from()` / `_on_added()` / `_on_removed()` moved here word for word; `Passive` is now `extends ToolkitBundle` with nothing of its own. New: `apply_to()`'s optional `left_out_stats` (skips the bundle's modifiers and StatScalings on those stats) and `get_stats()`. `knight.tres`'s inline Unbroken loads unchanged (no .tres was rewritten by the import).
- **Talent** (`scripts/data/talent.gd`, extends ToolkitBundle): `id`, `group` (Q / W / E / R / PASSIVE), `tier`, `exclusive`, `requirements`, `replaces_passive_stats`; `get_source_id()` (`talent_<id>`), `get_group_slot()`, `get_group_ability()`, `is_sibling_of()`, `get_validation_errors(champion)`. **TalentRequirement** (`scripts/data/talent_requirement.gd`): `kind`, `amount`, `enemy_tag`, `get_label()`, `get_validation_error()`; the counters come in T4.
- **ChampionData.talents** (export group "Talents") and `get_talent(id)`. The Knight's list is empty until T2.
- **Player**: `talent_loadout` export (the loadout until T4; empty in `player.tscn`); `_attach_champion()` looks the loadout up, skips unknown ids (warning) and invalid talents (error with the reasons), attaches the passive without the replaced stats, then each talent under `talent_<id>`. `get_active_talents()`, `get_left_out_passive_stats()`, `add_talent()`, `remove_talent()` (re-attaching the passive when a talent replaces its stats).
- **PassiveSlot**: a replaced scaling shows no "Now:" line; each active PASSIVE talent adds "<name> (talent)", "Replaces Unbroken's attack damage" and its own "Now:" lines (gold "Now:", pale blue talent lines). Unchanged for a loadout without PASSIVE talents (the champions test's slot checks pass as they were).
- **SandboxTalents** (`scripts/rooms/sandbox_talents.gd`, a node in `sandbox.tscn`): the champion's talents in a list at the bottom left; G / Shift+G move, T toggles on the live player. Shows "none" until T2.
- **Talents test** (`scenes/tests/talents_test.tscn`): 70/70. The refactor (Unbroken loads and works as before: 89.6 AD at 20% health); talent data and labels; a modifier, a StatScaling, a rule, a FLAG (`lunge_stuns`) and an EVENT (`judgement_reset`) each attaching under their source id and the Knight back to every exact stat after removal; 15 validation cases (unscoped, another ability's scope, a `tag:` scope, REPLACE, an unsupported FLAG, an unscoped rule, an always-on status, `replaces_passive_stats` outside PASSIVE, ABILITY_USES / an augment / an `ability:` scope in PASSIVE, replacing a stat the passive lacks, `enemy_tag` on a level requirement, no id) and two valid talents; replace (64 AD at 20% health), add (99.2), both (64 AD, attack speed × 1.5), both + an add on the replaced stat (73.6), the passive slot's lines for each; the loadout at load (a missing id and an invalid talent skipped, Cleave at 15 Fury, the passive without its AD); an empty loadout; SandboxTalents toggling on, off and refusing an invalid talent.
- Every other test: stats 179/179, abilities 559/559, audio 109/109, champions 168/168. Combat 457/459: the two real-time hitstop checks ("a shorter one changes nothing", "heavy feel: 0.06 s hitstop") that also fail on the commit before T1 (re-run there twice, 2026-09-30); one run of three also failed "over by 0.10 s", the same real-time family. `sandbox_main.tscn` and `main.tscn` run 600 frames headless with no errors or warnings.

## World interaction (WORLD_INTERACTION.md)

No build steps of its own yet. `WorldQuery.has_line_of_sight()` was built with the melee target pull (Combat, Melee basic attacks) and used by every hit since Combat C7; stronger-knockback-wins was built in Combat C4.
