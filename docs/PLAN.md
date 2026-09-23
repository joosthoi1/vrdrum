# VR Drum Kit — Project Plan

## Context
You want a VR application for playing a drum kit. Your main headset is a PSVR2 on PC through the PC adapter, which runs through SteamVR, but the app should also work on other headsets. The repo (`joosthoi1/vrdrum`) is empty, so this plan starts from scratch.

Your decisions:
- **Engine:** Godot 4 with OpenXR.
- **Scope:** a free-play drum kit first; a rhythm-game mode comes later.
- **External music software:** none for now. The app is self-contained with built-in samples, so no MIDI in or out and no DAW connection.

## Progress
- **M0 (project setup):** done.
  - Godot 4.7.2 project with OpenXR enabled.
  - Generated action map with 8 controller profiles.
  - XR rig, plus a desktop fallback rig.
  - Headless tests and CI.
- **M1 (one snare):** implemented; needs tuning on the headset.
  - Swept hit detection with re-arm, 3 velocity layers with round-robin, haptics, and a debug overlay.
  - A calibrate button that moves the kit to your stick height.
  - Still to do on PSVR2: measure latency, then tune `min_hit_speed`, `max_hit_speed`, `velocity_exponent` and the stick grip angle.
- **M2 (full kit):** implemented; needs checking on the headset.
  - Pieces: kick, snare (head and rim), hi-hat (closed, half-open, open and pedal "chick"), 3 toms, crash (bow and edge), ride (bell, bow and edge).
  - Choke groups:
    - Closing the hi-hat pedal cuts the ringing open hat.
    - A hand (controller) at a cymbal's edge chokes that cymbal.
  - Pedals come from the VR triggers (right = kick, left = hi-hat, analog), the keyboard (`Space`/`V`) or a gamepad's triggers. `scripts/kit/pedal_input.gd` combines them.
  - Visuals are generated in code (`drum_body.gd`, `cymbal_body.gd`) and are also previewed in the editor. Cymbals wobble on a spring when hit.
  - Sounds: 15 articulations are synthesized on a worker thread at startup and cached as raw PCM in `user://synth_cache`. That takes about 3 s the first time and about 25 ms after. Playback pitch varies slightly with each hit, so repeats don't sound identical.
  - Still to do on PSVR2:
    - Check that the default layout is comfortable to reach.
    - Check that trigger pedals feel usable.
    - Tune the choke distance.

- **M3 (comfort and customization):** implemented; needs checking on the headset.
  - Settings (`Settings` autoload, saved to `user://settings.cfg`):
    - hit sensitivity and dynamics
    - stick length and angle
    - master and per-group volumes (Kick / Snare / Toms / HiHat / Cymbals buses)
    - spatial audio amount
    - hit highlights on or off
    - left-handed kit (the layout is mirrored and the pedal triggers are swapped)
    - hi-hat pedal inversion
  - Menu: one `SettingsMenu` control. In VR it's shown on a world-space panel (`UiPanel3D`): the sticks are laser pointers and the trigger clicks. On desktop it's an overlay.
  - Kit editor (`KitEditor`): in VR, touch a piece with a stick tip and hold the trigger to carry it. On desktop, drag pieces and scroll to raise or tilt them.
  - Layouts (`KitLayout`): stored right-handed, with default and compact presets and 3 save slots. The current layout is restored at startup.
  - Placement: B/Y height calibration, "kit higher / lower" buttons, and "recenter kit on me" (VR).
  - A practice room with walls, acoustic panels, a rug, a window and lamps.
- **Sound upgrade:** the synthesized placeholders were replaced by recorded samples from Karoryfer's CC0 Big Rusty Drums.
  - The samples are mixed to mono by `tools/build_sample_kit.py`.
  - The recorded velocity layers carry the dynamics.
  - Voices are positional.
  - The synth remains as a fallback.
- **Hit highlights:** the zone that was hit lights up: drum head or hoop, and the cymbal's bell, bow or edge ring (hi-hat included).

- **M4 (polish and release):** implemented; still needs testing on headsets.
  - Latency: `AudioStreamPlayer3D` starts sounds on the next physics tick, which cost about one frame per hit. Voices are now plain `AudioStreamPlayer`s, which start immediately. Each is routed to one of five pre-panned buses per group, chosen from the drum's position relative to the head.
  - Performance:
    - Sticks scan a static piece registry instead of a group lookup.
    - `tools/benchmark.gd` measures about 0.25 ms of game logic per frame while playing 24 hits per second, and CI fails if it goes over 1.5 ms.
    - Graphics settings: resolution (OpenXR render target multiplier in VR), MSAA and shadows.
  - Export:
    - `export_presets.cfg` has Windows and Linux presets. They include `kit.json`, embed the game data, and leave out tests and tools.
    - Both were exported locally, and the Linux build was run to confirm it loads the recorded kit.
    - The OpenXR startup alert is off, so a machine without a headset goes straight to desktop mode.
  - Release:
    - `.github/workflows/release.yml` runs on `v*` tags: tests, exports, a check that the build starts, zips with the player guide, a GitHub Release, and an optional itch.io upload.
    - Docs: `docs/PLAYING.md`, `docs/RELEASING.md`, `docs/TESTING.md` and `CHANGELOG.md`.
  - Still to do: go through `docs/TESTING.md` on PSVR2 and other headsets, set up the itch.io page, and tag the first release.

Changes from the original plan:
- Tests use a small built-in runner (`tests/run_tests.gd`) instead of the GUT addon, so the project has no third-party dependencies.
- Kit layouts are JSON files under `user://layouts/` rather than `.tres` resources.
- `kit.json` (the sample manifest) is a non-resource file, so the export presets include `assets/kits/*/kit.json` explicitly.
- Positional audio uses pre-panned buses rather than `AudioStreamPlayer3D`, to avoid a frame of latency.
- Sounds are synthesized at startup (`scripts/audio/drum_synth.gd`) as placeholders. A CC0 multi-sampled kit can replace them by filling a `DrumSampleBank` with the same articulation keys (`snare/head`, `snare/rim`, ...).

---

## 1. Platform strategy
- **Runtime:** OpenXR only, with no vendor SDKs. The headsets split into two groups:
  - Through SteamVR on PC: PSVR2 (PC adapter), Valve Index, Vive, and Quest or Pico over Link or Virtual Desktop.
  - Other runtimes: Windows Mixed Reality and Meta's Quest Link runtime.
- **PSVR2 on PC:** this is the main target.
  - The Sense controllers show up in SteamVR.
  - We ship bindings for these OpenXR controller profiles: Oculus Touch, Valve Index, HTC Vive, WMR, and Khronos Simple. SteamVR can map the Sense controllers onto one of them, and its binding UI lets you adjust the mapping.
  - Don't count on adaptive triggers, headset haptics, or eye tracking over the PC adapter. Only controller rumble is used.
- **Inside-out tracking:** PSVR2 and Quest track the controllers with headset cameras.
  - Tracking gets worse when the controllers are low or near the body.
  - The default kit layout keeps the pads in front of you at chest to waist height, and a calibration step can raise or lower the whole kit.
- **Renderer:**
  - Forward+ for PC VR.
  - Keep assets simple enough that the Mobile or Compatibility renderer could later power a native Quest (Android) build. That build is optional and comes last.
- **Target frame rate:** 90 or 120 Hz, matching the headset's refresh rate. Use a low-poly kit with baked lighting.

## 2. Core technical design (where the game feels good or doesn't)

### 2.1 Sticks
- **Tip tracking:**
  - Each stick is a kinematic `Node3D`, not a physics rigid body, under an `XRController3D`.
  - Its grip offset and angle can be adjusted, so the stick sits naturally in the Sense, Touch, or Index grip.
  - A `Marker3D` marks the stick tip.
  - Each frame, the code saves the tip's previous and current world positions and works out tip velocity from them, with light smoothing.
- **Tracking source:**
  - Use the `aim` or `grip` pose that XR updates in `_process`, which runs every rendered frame.
  - Don't do hit detection on the physics tick, because that would add latency and cause aliasing.

### 2.2 Hit detection: a swept test, not colliders
A stick tip can move about 10 m/s, which is roughly 11 cm per frame at 90 Hz. Physics colliders would miss hits or fire late at that speed, so hits are detected with a swept test:
- **Drum surfaces:** each hittable surface is a `DrumPiece`, stored as a plane (center plus normal) with a round shape (radius). Zones sit inside that shape, such as:
  - snare: center and rim
  - ride: bow, bell, and edge
  - crash: bow and edge
- **The hit test, run every frame per stick for every piece:**
  1. Compute the signed distances `d0` and `d1` from the stick's previous and current tip positions to the plane.
  2. If `d0 > 0 >= d1`, the tip crossed the plane going down. Interpolate the crossing point.
  3. Check that the crossing point is inside the drum's radius, and find which zone it's in.
  4. Check that the tip's speed along the drum's normal is above `min_hit_speed`.
- **Re-arming:** after a hit, that stick-and-drum pair is locked out until the tip rises above `plane + rearm_height` (a few mm). This stops double triggers from jitter.
- **Velocity to loudness:**
  - Tip speed along the normal is mapped through a user-adjustable `Curve` resource to a value from 0 to 1.
  - That value picks the velocity layer and sets the gain.
- **Visuals:** the stick's model is clamped so it doesn't go through the drum head. Detection still uses the raw tracked position.
- **Optional later feature, look-ahead:** extrapolate the tip by half a frame and trigger early, to cut perceived latency. Put it behind a setting.
- **Code layout:** this logic is pure math with no scene dependencies (`hit_math.gd`), so it can be unit-tested without a headset.

### 2.3 Feet: kick drum and hi-hat pedal
The hands hold the sticks, so the pedals need another input source. Several are supported through Godot's InputMap:
- Controller triggers, which are free because the stick is held with the grip:
  - right trigger = kick
  - left trigger = hi-hat pedal, read as an analog value so it can also give the half-open state
- Keyboard keys. Cheap USB foot switches pretend to be keyboard keys, so they work with no extra code.
- Gamepad buttons.

Everything is rebindable, and left-handed kit layouts are supported.

### 2.4 Audio
- **Latency:**
  - The total target from a tracked hit to sound is under 30 ms.
  - Lower Godot's `audio/driver/output_latency` from its default of 15 ms, and measure the result.
  - A user latency offset setting is added in Milestone 5, when the rhythm mode needs it.
- **Samples:**
  - Uncompressed WAV at 48 kHz, preloaded when the kit loads.
  - Each hit type gets several velocity layers and 2–4 round-robin variations, so repeated hits don't sound identical.
- **Voices:**
  - A fixed pool of `AudioStreamPlayer` voices (about 32), or an `AudioStreamPolyphonic`.
  - When the pool is full, the oldest or quietest voice is dropped (voice stealing).
  - Choke groups let one sound cut another. For example, closing the hi-hat cuts the open hi-hat, and grabbing a cymbal cuts its ring.
- **Buses:** kick, snare, toms, and cymbals each have their own bus, feeding a master bus with a light compressor and room reverb.
- **Sample source:** start with a CC0 or public-domain multi-sampled acoustic kit, and check its license before committing it. The layout is `assets/kits/<kit>/<piece>/<articulation>_v<layer>_rr<n>.wav`.
- **Kit definition:** each kit has a `kit.tres` resource file that maps pieces and articulations to sample files, so more kits can be added without code changes.

### 2.5 Feedback
- Controller haptics are triggered with `XRController3D.trigger_haptic_pulse()`. Their strength and length follow hit velocity and drum type.
- Visuals:
  - drum heads flex slightly
  - cymbals wobble on a spring
  - pads can optionally flash, which helps with tracking and timing

## 3. Project layout (Godot 4.7)
This layout is the target. The M0–M4 parts exist so far.
```
project.godot
openxr_action_map.tres        # stick pose, triggers (kick/hh), menu, grip; multi-profile bindings
addons/                       # godot-xr-tools later if needed (menus/pointer)
scenes/
  main.tscn                   # environment + XR rig + kit + UI
  xr_rig.tscn                 # XROrigin3D, XRCamera3D, 2x XRController3D + stick
  desktop_rig.tscn            # non-VR fallback: mouse/keyboard-driven sticks for dev & testing
  kit/drum_kit.tscn           # arranges DrumPiece instances from a KitLayout
  kit/pieces/{snare,tom,kick,hihat,crash,ride}.tscn
  ui/{main_menu,settings,kit_editor}.tscn   # world-space panels
scripts/
  xr/xr_bootstrap.gd          # init OpenXR, fall back to desktop rig if unavailable
  sticks/drum_stick.gd        # tip tracking, velocity, haptics
  kit/drum_piece.gd           # plane/zones, hit test, rearm state
  kit/hit_math.gd             # pure functions: segment-plane crossing, zone lookup, velocity curve
  kit/hihat.gd                # pedal openness state machine, choke
  audio/drum_audio.gd         # voice pool, round robin, choke groups (autoload)
  audio/kit_definition.gd     # Resource: piece -> articulation -> sample layers
  settings/settings.gd        # autoload; persisted to user://settings.cfg
  settings/kit_layout.gd      # Resource: piece transforms; saved to user://layouts/
assets/kits/, assets/models/, assets/env/
tests/                        # headless unit tests + tiny runner (run_tests.gd)
.github/workflows/ci.yml      # headless Godot: import + run tests + smoke-run main scene
docs/PLAN.md
```

## 4. Milestones
**M0 — Project setup**
- Godot project with OpenXR enabled.
- Action map with bindings for multiple controller types.
- XR rig, plus a desktop fallback rig for when no headset is found.
- Unit tests and CI.
- Goal: the app runs on PSVR2 through SteamVR, and your hands are tracked in an empty room.

**M1 — "One snare that feels great"** (the most important milestone)
- Sticks attached to the controllers, with adjustable grip.
- One snare with swept hit detection, velocity layers, and haptics.
- A debug overlay showing hit speed, the velocity value, and frame time.
- Measure latency, for example by filming the controller hitting a real table while recording the sound, then tune the thresholds.

**M2 — Full kit**
- Kick, snare (center and rim), hi-hat (closed, half-open, open, and pedal "chick"), 2–3 toms, crash, and ride (bow, bell, and edge).
- Choke groups and cymbal animation.
- Pedal input from the triggers, keyboard, or gamepad.

**M3 — Comfort and customization**
- Height and position calibration for seated or standing play.
- A kit editor where you grab pieces to move them, plus layout presets. Layouts are saved.
- Settings:
  - stick length and angle
  - sensitivity curve
  - volume per piece
  - left-handed mode
  - pad highlight
- A pleasant practice room environment.

**M4 — Polish and release**
- Profile performance and keep a steady 90/120 fps.
- Windows export.
- Test on PSVR2, then any other headsets you can borrow (Quest via Link, Index).
- Release on itch.io. An optional Linux export and native Quest APK can follow.

**M5 — Rhythm mode (later)**
- Load songs (an audio file plus a chart). Support Clone Hero/Rock Band style `.chart` and `.mid` drum charts.
- A note highway, or notes that light up the matching pads.
- Timing windows, scoring, and combo.
- A calibration screen for audio and visual offset.
- Song selection.
- The hit events from M1–M2 already carry timestamps and piece/zone IDs, so scoring can use them directly.

## 5. Key risks and how to handle them
| Risk | Mitigation |
|---|---|
| Missed or double hits from fast sticks | Swept test (2.2), re-arm threshold, unit tests with recorded motion data |
| Perceived latency | Hit detection on the render frame, a low audio buffer, WAV samples, optional look-ahead |
| PSVR2 controller tracking loss low or near the body | Kit placed in front of you, height calibration, smoothed velocity so one bad frame doesn't cause a phantom hit |
| Sense controller buttons mapped oddly in SteamVR | Bindings for several controller profiles, plus SteamVR's rebinding UI and in-game rebinding |
| Kick and hi-hat feel unnatural on triggers | Optional USB foot switches through keyboard mapping |

## 6. Verification
- **Unit tests** (run headless in CI):
  - `hit_math`: crossing detection, zone lookup, re-arm, and the velocity curve
  - kit definition loading
  - hi-hat state machine
- **Desktop rig:** test hits and sounds without a headset. The mouse drives a stick and keys act as pedals.
- **On headset** (PSVR2 through SteamVR):
  - Check the rest of M1 as a checklist: fast single strokes, drum rolls, soft ghost notes, rimshots.
  - Confirm there are no double triggers or missed hits.
  - Check that SteamVR's frame timing meets the refresh rate.
- **Latency:** measure the camera-plus-audio test described in M1, and aim for under 30 ms.
