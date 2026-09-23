# VR Drums

A drum kit to play in VR. It works with any OpenXR headset: PSVR2 on PC, Valve Index, Vive, Quest or Pico over Link, and Windows Mixed Reality.

## Getting started

### PSVR2 on PC

1. Connect the headset with the PlayStation VR2 PC adapter.
2. Install the PlayStation VR2 app and SteamVR.
3. Start SteamVR and check that the headset and both Sense controllers are tracked.
4. Make SteamVR your OpenXR runtime: SteamVR → Settings → OpenXR → "Set SteamVR as OpenXR runtime".
5. Run `VRDrums.exe`.

Other headsets: make sure your headset's software (SteamVR, Meta Quest Link, ...) is the active OpenXR runtime, then run the game.

If no headset is found, the game opens in a desktop window instead, which is handy for trying things out.

## Controls in VR

| Input | Action |
|---|---|
| Swing the sticks | Play (the harder you hit, the louder) |
| Right trigger | Kick drum |
| Left trigger (hold) | Close the hi-hat; half-pressed is half-open |
| Hand on a cymbal's edge | Stop the cymbal ringing |
| A / X or the menu button | Menu, or leave the kit editor |
| Point a stick at the menu, pull the trigger | Click |
| B / Y | Move the kit to just below where you hold your sticks |
| Thumbstick click | Debug overlay (frame rate, last hit) |

Left-handed mode (Menu → Play) mirrors the kit and swaps the kick and hi-hat triggers. Keyboard keys also work as pedals, so a USB foot switch set to Space (kick) or V (hi-hat) works too.

## First time setup

1. Stand or sit where you want to play. Open the menu → Kit → **Recenter kit on me**.
2. Hold both sticks where you'd like the snare to be and press **B / Y**.
3. Too far to reach? Menu → Kit → **Compact layout**, or **Edit layout**: touch a piece with a stick tip, hold the trigger and move it.
4. Menu → Sticks to adjust the stick length and angle so they feel natural in your hand.
5. Menu → Play → **Hit sensitivity** if you have to hit too hard (or too softly) for loud notes.

Your settings and layout are saved automatically.

## Desktop mode

Point at a drum or cymbal with the mouse. Left click (or J) plays the right stick and right click (or F) the left stick; hold Shift for a soft hit. Space is the kick and V (hold) closes the hi-hat. Esc opens the menu.

## Troubleshooting

- **It starts in a window instead of VR:** the headset software isn't running or isn't the active OpenXR runtime (see step 4 above).
- **Buttons do nothing on the Sense controllers:** open SteamVR → Settings → Controllers → Manage Controller Bindings, pick VR Drums, and choose the recommended bindings. The game's actions are named after Touch controller buttons (trigger, A/X, B/Y, menu).
- **Stuttering:** lower Menu → Graphics → Resolution (then restart) or turn off shadows. The game runs at your headset's highest refresh rate (PSVR2: 120 Hz).
- **Hits feel late:** make sure nothing else is using your audio device in exclusive mode, and try a wired audio output. Bluetooth headphones add a lot of delay.

## Credits

Drum samples: [Big Rusty Drums](https://github.com/sfzinstruments/karoryfer.big-rusty-drums) by Karoryfer Samples (CC0). Made with [Godot](https://godotengine.org).
