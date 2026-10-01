class_name Passive
extends ToolkitBundle
## A champion's passive (CHAMPIONS.md, Passives): a bundle of toolkit pieces
## attached under one source id (passive_<champion id>) when the champion
## loads, and removed by it, exactly as an item or an augment source attaches
## its pieces. Inline in the champion's ChampionData.
##
## Its fields and apply_to() / remove_from() live on ToolkitBundle since
## TALENTS T1 (shared with Talent); the names are unchanged.
##
## For anything truly one-off, extend it and override _on_added() /
## _on_removed() (res://scripts/abilities/<champion>/<passive>.gd).
