# [SYSTEM].md: [One-line description]
<!-- HOW TO USE
     1. Copy to docs/[SYSTEM].md when you START building the system, not before.
     2. Fill in what you know. Put unknowns under "Open questions"; don't guess.
     3. Add a row to the Docs index in CLAUDE.md (paths are docs/...).
     4. When a decision changes, edit the doc right away. An outdated doc is worse than none.
     Tip: ask Claude "interview me to fill out docs/_TEMPLATE.md for [system]". -->

**Read when:** [kinds of tasks that need this doc]
**Depends on:** [other docs]
**Used by:** [systems that depend on this one]

## Current code
<!-- What already exists: res:// paths, class names, what works, what's LoL-era and needs replacing. -->
- 

## Goal / feel
<!-- NUMBERS, not adjectives. Bad: "snappy attacks". Good: "windup 0.08s, hit-stop 0.05s". Name a reference game. -->
- 

## Core rules
<!-- Rules that must always hold. -->
- 

## Data (Resources)
<!-- Which .tres hold this system's data (res://data/...), and their fields. Remember: stats are in LoL units. -->
- 

## Architecture / contracts
<!-- New/changed scripts with res:// paths, public methods, signals. -->
- 

## View
<!-- How this system looks in 3D (docs/3D.md): which sim nodes declare a view_scene, what the view shows (model, animation, floor drawing, screen overlay, sound), which signals or progress getters drive it, and its debug_draw. The view never changes gameplay state. "None" if it has no look. -->
- 

## Build order
<!-- One line per built step ("C8 built 2026-09-26, see CHANGELOG.md"). Test counts and measurements go in docs/CHANGELOG.md, rules in the sections above. -->
1. 

**Done means:** [how you'll know a step works in play mode]

## Open questions
- 
