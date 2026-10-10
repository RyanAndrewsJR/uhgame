class_name SoundSheet
extends Resource
## A champion's or enemy's sound triggers, all in one file (AUDIO.md, Sound
## triggers and the tuning panel; built in A6a): ChampionData.sound_sheet,
## EnemyData.sound_sheet. Files: res://data/sound_sheets/sound_sheet_<owner>.tres.
## Every matching trigger plays (no "first wins"), in list order.

@export var triggers: Array[SoundTrigger] = []
