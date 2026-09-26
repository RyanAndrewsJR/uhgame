# PROMPTS.md: Ryan's Prompt Playbook
This file is for you, not for Claude. It's not in the CLAUDE.md docs index, so Claude won't read it unless you ask.

## How the two conversations work together
| | **Advisor** (like the planning chat) | **Builder** (your project session) |
|---|---|---|
| Job | plan, design systems, write and review docs, review the builder's plans, write prompts for you | reads and writes game code and docs, runs the build steps |
| Edits files? | No. Gives you prompts to paste instead. | Yes |

Only the builder edits files. That way two sessions never overwrite each other's work.

The loop: the builder plans and flags problems → if you're unsure, paste its output into the advisor → the advisor suggests decisions and a reply → you paste that into the builder.

---

## A. Starting a new advisor conversation
Connect the `uhgame` folder first (or attach CLAUDE.md and the docs folder). Then:

> You're my design and architecture advisor for my Godot game. A separate Claude session in my project does all the building. Your job is to help me plan systems, write and revise docs, review that session's plans and outputs, and write prompts I paste to it. **Don't edit any files. Give me prompts to paste instead.**
>
> Read uhgame/CLAUDE.md, then docs/VISION.md, docs/CONVENTIONS.md, docs/DECISIONS.md, and skim the rest of docs/. Then give me a short summary: what the game is, where the build is (Current status), the open questions, and any inconsistencies you notice between docs. Then wait for my question.

To relay builder output:
> Here's what my project session said. What should I reply? [paste]

---

## B. Starting every builder conversation
> Read CLAUDE.md. Today's task: ______. Read the docs it needs. **Plan first, no code yet:** list the files you'll create or change, anything that conflicts with the docs or code, and any questions. Wait for my OK.

For a simple continuation, the plan step can be skipped:
> Read CLAUDE.md. Do [system] step [N].

Ending every builder conversation:
> Update Current status in CLAUDE.md, add any decisions to docs/DECISIONS.md, and tell me what to test.

---

## C. Task templates (builder)
**Formula:** *what* (add / change / remove) + *which thing* + *behavior in numbers* + *how I'll test it*. One thing per prompt.

### Tune numbers (cooldowns, damage, speed, stats)
**Do it yourself.** Open the `.tres` in Godot and edit it in the Inspector. That's what "data lives in Resources" is for. No prompt needed.

### Continue a build step
> Do [movement/stats/...] step [N].

### Design a new system (doc first, then build in a later conversation)
> Read CLAUDE.md, docs/VISION.md, docs/CONVENTIONS.md. I want to design [system]. Interview me to fill out docs/_TEMPLATE.md as docs/[SYSTEM].md. Add it to the Docs index when done.

### Change how an existing system works
> Change [system]: [what should happen instead, with numbers]. Reason: [why]. Plan first. Update docs/[SYSTEM].md and docs/DECISIONS.md along with the code.

### Remove something
> I want to remove [thing]. **Don't delete anything yet.** List everything that depends on it, what would break, and your plan. Wait for my OK.

### New champion
> Add a new champion: [name].
> - Fantasy / role: [e.g. agile ranged skirmisher who swings on walls]
> - Resource: [mana / energy / fury / none]
> - Base stats compared to the Knight: [e.g. less health, faster, longer range]
> - Passive: [description]
> - Abilities: [one ability spec per slot, template below]
>
> Follow CONVENTIONS.md naming. Plan first: list the data files, scripts, and scenes you'll create.

### New or changed ability
Use the ability spec template (in WORLD_INTERACTION.md until ABILITIES.md exists):
> Add ability [name] to [champion] slot [q/w/e/r]:
> ```
> Targeting: DIRECTION / POINT / UNIT / SELF
> cooldown / cast_time / cast_range / roots_during_cast:
> base_damage / ratios:
> What it does, step by step:
> Ends when:
> Hits wall / hits enemy / stunned mid-cast:
> Feel: [hitstop, shake, VFX color]
> ```
> Plan first.

### New item *(works once LOOT.md and items exist)*
> Add item [name]: slot [ ], rarity [ ], champion-only: [yes: who / no].
> Stat modifiers: [e.g. +10% attack_speed]
> Ability modifiers: [e.g. Lunge cast_range +30%]
> Augment (behavior change): [e.g. Lunge stuns for 0.5s]

### New stat
> Add stat [key]: what it does, default, min/max, units, and which systems read it. Follow "To add a stat" in STATS.md.

### New world interaction
> Add an interaction: when [trigger, e.g. a knocked-back enemy hits a wall] and [tags, e.g. wall tagged wall_slam] → [effect, e.g. stun 1s]. Use a ReactionRule if possible. Tell me if it needs new code.

### Bug
> Bug: I expected [X] but got [Y]. Steps: [how to trigger it]. Error: [paste]. **Find the cause and explain it before fixing.**

---

## Habits that keep answers accurate
- Use numbers, not adjectives ("stops in 0.04s", not "snappy").
- Say "plan first" for anything that touches more than one file.
- Test in Godot before the next step. Back up or commit before each step.
- Start a new builder conversation every 2–3 steps or when you switch systems.
- When you change your mind, make sure the docs get updated too. Outdated docs mean outdated code.

To start a new advisor conversation, connect the uhgame folder and paste:

You're my design and architecture advisor for my Godot game. A separate Claude session in my project does all the building. Your job is to help me plan systems, write and revise docs, review that session's plans and outputs, and write prompts I paste to it. Don't edit any files. Give me prompts to paste instead.

Read uhgame/CLAUDE.md, then docs/VISION.md, docs/CONVENTIONS.md, docs/DECISIONS.md, and skim the rest of docs/. Then give me a short summary: what the game is, where the build is (Current status), the open questions, and any inconsistencies you notice between docs. Then wait for my question.

To start each builder conversation:

Read CLAUDE.md. Today's task: ______. Read the docs it needs. Plan first, no code yet: list the files you'll create or change, anything that conflicts with the docs or code, and any questions. Wait for my OK.

The playbook also has fill-in templates for:

changing an existing system
removing something (it lists what depends on it and deletes nothing until you approve)
a new champion, ability, item or stat
a new world interaction
bug reports
ending a session

One shortcut: for number tweaks like cooldowns, damage or speed, skip Claude and edit the .tres file in Godot's Inspector. That's quicker, and it's why the numbers are kept in data files.
