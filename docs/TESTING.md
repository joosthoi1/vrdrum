# Headset test checklist

Run through this on each headset before a release. Turn on the debug overlay (thumbstick click) to see the frame rate and each hit's speed and loudness.

## Start-up

- [ ] Starts in VR without errors; the debug overlay's frame rate matches the headset's refresh rate (PSVR2: 120).
- [ ] With the headset software closed, starts in a desktop window, with no error dialog.
- [ ] The kit is in front of you after Menu → Kit → Recenter kit on me.

## Playing

- [ ] Single strokes, soft to loud: each hit sounds once, and loudness follows force.
- [ ] Fast rolls on the snare: no missed or doubled hits.
- [ ] Ghost notes (very soft taps) still sound.
- [ ] Rimshots near the snare's edge sound different and light up the hoop.
- [ ] Ride bell, bow and edge each sound different and light up their ring.
- [ ] Hi-hat: closed, half-open and open follow the left trigger; closing it plays the "chick" and cuts the open hat.
- [ ] Kick on the right trigger: soft squeeze is quiet, fast squeeze is loud.
- [ ] Touching a cymbal's edge with your hand stops it ringing.
- [ ] Tapping the sticks together clicks once per tap, louder when harder. Crossing over for the hi-hat never clicks by accident.
- [ ] Hits feel on time. Film the controller hitting a table while recording the game's audio, and check the delay; aim for under 30 ms.
- [ ] Sounds come from where the drums are: turn your head and the ride moves in the stereo image.

## Clone Hero

- [ ] Clone Hero lists the loopMIDI port as a MIDI input, and the VR Drums menu shows *Sending to "…"*.
- [ ] Every lane maps with one hit (or its Test lanes button), and notes register in songs.
- [ ] Soft and hard hits reach Clone Hero with different velocities.
- [ ] The in-VR screen shows Clone Hero, about a frame behind the TV, with the right colours.
- [ ] A still menu stays on the screen. Minimizing Clone Hero shows a message instead.
- [ ] Moving and resizing the screen in the kit editor survives a restart.
- [ ] The frame rate stays at the headset's refresh rate with the screen on.
- [ ] Turning off kit sounds silences our kit, but MIDI still reaches Clone Hero.

## Comfort and settings

- [ ] B / Y sets the kit height where the sticks are.
- [ ] The menu opens with A / X, stick pointers hit the buttons, the trigger clicks, and sliders drag.
- [ ] Triggers don't play pedals while the menu is open.
- [ ] Kit editor: touch a piece, hold the trigger, move it; the change survives a restart.
- [ ] Left-handed mode mirrors the kit and swaps the pedals.
- [ ] Stick length and angle changes feel right in the hand.

## Performance

- [ ] SteamVR's frame timing graph stays under budget (8.3 ms at 120 Hz) while playing busy patterns.
- [ ] No hitches when many cymbals ring at once.

## Headsets

| Headset | Runtime | Tested | Notes |
|---|---|---|---|
| PSVR2 (PC adapter) | SteamVR | | |
| Quest 2/3 (Link / Air Link) | Meta or SteamVR | | |
| Valve Index | SteamVR | | |
| WMR / Vive | SteamVR / WMR | | |
