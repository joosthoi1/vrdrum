# Changelog

## 0.5.0

- Play Clone Hero with the VR kit:
  - Hits are sent as MIDI notes (through loopMIDI). There's a Clone Hero note map with one note per pad, and a General MIDI one.
  - Test lanes buttons, and Clone Hero lane colours on the pads.
  - A toggle for our own kit sounds.
- Clone Hero's window is shown on a screen in the practice room (Windows, via desktop capture). You can move and resize it in the kit editor, and it's saved with the layout.
- New native GDExtension (`addons/vrdrum_native`) with prebuilt Windows and Linux libraries.
- See docs/CLONE_HERO.md.

## 0.4.0

- Tap the sticks together for a stick click, e.g. to count in. It's detected even for fast taps, gets louder the harder you tap, and vibrates and lights up both sticks. You can turn it off under Menu → Play.
- Hits start playing the moment they're detected. Positional audio used to add a frame of delay; hits are now panned through pre-panned mixer buses instead.
- Graphics settings: resolution (VR: after a restart), anti-aliasing and shadows.
- Windows and Linux builds, published by the release workflow.
- No OpenXR startup alert when no headset is found; the game just starts in desktop mode.
- Performance smoke test in CI: game logic costs about 0.25 ms per frame under heavy playing.

## 0.3.0

- Menu (A/X or the menu button in VR, Esc on desktop) with settings for hit feel, sticks, sound, left-handed play and highlights.
- Kit editor: grab and move pieces. Includes presets, save slots, height calibration and recentering.
- Practice room environment.
- Recorded drum kit (Karoryfer's CC0 Big Rusty Drums) replaces the synthesized placeholders.
- The part of a drum or cymbal you hit lights up.

## 0.2.0

- Full kit: kick, snare, hi-hat, three toms, crash and ride.
- Hi-hat pedal with closed, half-open and open sounds plus the foot "chick"; cymbal chokes.
- Pedals on the VR triggers, keyboard or gamepad.

## 0.1.0

- First playable version: one snare with swept hit detection, velocity, haptics and a desktop test mode.
