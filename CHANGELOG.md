# Changelog

## 0.4.0

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
