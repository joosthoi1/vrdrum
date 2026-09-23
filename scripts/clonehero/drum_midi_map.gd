class_name DrumMidiMap
extends RefCounted
## Which MIDI note each kit articulation sends, for Clone Hero (or a DAW).
##
## Clone Hero's MIDI mapper binds each lane to the notes you hit while it
## listens, so the "Clone Hero" preset sends one note per pad: mapping a lane
## takes one hit. "General MIDI" gives each articulation its own note
## (rimshot, open hi-hat, ride bell, crash edge), as e-kits do for DAWs.

enum Preset { CLONE_HERO, GENERAL_MIDI }

const PRESET_NAMES: Array[String] = ["Clone Hero", "General MIDI"]

## General MIDI drum notes, one per pad.
const CLONE_HERO_NOTES := {
	&"kick/head": 36,
	&"snare/head": 38, &"snare/rim": 38,
	&"tom1/head": 48, &"tom2/head": 45, &"tom3/head": 43,
	&"hihat/closed": 42, &"hihat/half": 42, &"hihat/open": 42, &"hihat/pedal": 44,
	&"crash/bow": 49, &"crash/edge": 49,
	&"ride/bow": 51, &"ride/bell": 51, &"ride/edge": 51,
}

## Where General MIDI differs from the Clone Hero preset.
const GENERAL_MIDI_OVERRIDES := {
	&"snare/rim": 40,
	&"hihat/half": 46, &"hihat/open": 46,
	&"crash/edge": 55,
	&"ride/bell": 53,
}

## Clone Hero lane colours.
const RED := Color(0.92, 0.18, 0.16)
const YELLOW := Color(1.0, 0.82, 0.1)
const BLUE := Color(0.18, 0.5, 1.0)
const GREEN := Color(0.2, 0.82, 0.26)
const ORANGE := Color(1.0, 0.55, 0.1)

## Pro Drums lane of each kit piece.
const LANE_COLORS := {
	&"snare": RED, &"tom1": YELLOW, &"tom2": BLUE, &"tom3": GREEN,
	&"hihat": YELLOW, &"ride": BLUE, &"crash": GREEN, &"kick": ORANGE,
}

## Clone Hero lanes, for the "test lanes" buttons: [label, note, colour].
const LANES := [
	["Kick", 36, ORANGE],
	["Red", 38, RED],
	["Yellow tom", 48, YELLOW],
	["Blue tom", 45, BLUE],
	["Green tom", 43, GREEN],
	["Yellow cymbal", 42, YELLOW],
	["Blue cymbal", 51, BLUE],
	["Green cymbal", 49, GREEN],
]


## The note for an articulation, or -1 if it isn't sent (e.g. stick clicks).
static func note_for(articulation: StringName, preset: int = Preset.CLONE_HERO) -> int:
	if preset == Preset.GENERAL_MIDI and GENERAL_MIDI_OVERRIDES.has(articulation):
		return GENERAL_MIDI_OVERRIDES[articulation]
	return CLONE_HERO_NOTES.get(articulation, -1)


## MIDI velocity (1..127) for a hit intensity (0..1).
static func velocity_for(intensity: float) -> int:
	return clampi(1 + roundi(clampf(intensity, 0.0, 1.0) * 126.0), 1, 127)
