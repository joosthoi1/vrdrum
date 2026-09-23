# Playing Clone Hero with VR Drums

VR Drums can act as an electronic drum kit for [Clone Hero](https://clonehero.net):
- Every hit is sent as a MIDI note.
- Clone Hero's window is shown on a screen inside VR, while everyone else watches it on your TV or monitor.
- The VR kit keeps making its own sounds, like an e-kit's sound module. You can turn that off.

This needs Windows for the in-VR screen. MIDI output also works on Linux.

## 1. Create a virtual MIDI cable

Windows programs can't send MIDI straight to each other, so you need a virtual cable:

1. Install [loopMIDI](https://www.tobias-erichsen.de/software/loopmidi.html) (free) and start it.
2. Type `VR Drums` as the port name and click **+**.

Leave loopMIDI running while you play. It can start with Windows, if you like.

On Windows 11 with the new Windows MIDI Services, its built-in loopback ports also work instead of loopMIDI. On Linux, pick *Create virtual port "VR Drums"* in step 2 instead.

## 2. Turn on MIDI in VR Drums

1. Open the menu (A / X in VR, Esc on desktop) and go to **Clone Hero**.
2. Turn on **Send hits as MIDI**.
3. Pick **VR Drums** (your loopMIDI port) as the MIDI output port. A port whose name contains "VR Drums" or "loopMIDI" is picked automatically.
4. Leave **Note map** on **Clone Hero**.

The status line should read *Sending to "VR Drums"*, and the kit's hoops and cymbal edges now show their Clone Hero lane colours.

## 3. Set up Clone Hero

1. Start Clone Hero and put it on the TV or monitor your audience watches.
2. Go to **Settings → Controls**, select your profile, and set the instrument to **Drums**.
3. Under **MIDI Settings**, choose **VR Drums** as the input device.
4. Map each lane: select it in Clone Hero, then hit the matching pad in VR. You can also press that lane's button under **Test lanes** in the VR Drums menu.

   | Clone Hero lane | Pad |
   |---|---|
   | Red | Snare |
   | Yellow tom | Tom 1 |
   | Blue tom | Tom 2 |
   | Green tom | Floor tom |
   | Kick | Kick (right trigger, or Space) |
   | Yellow cymbal | Hi-hat |
   | Blue cymbal | Ride |
   | Green cymbal | Crash |

5. Play songs with **Pro Drums** on, so cymbals and toms count separately.

The **Clone Hero** note map sends one note per pad (every snare hit is note 38, every hi-hat hit 42, and so on), so each lane needs just one hit to map. Velocity follows how hard you hit, so Clone Hero's velocity thresholds work.

## 4. Show Clone Hero in VR

1. In the VR Drums menu, go to **Clone Hero** and turn on **Show the Clone Hero screen**.
2. **Window to show** defaults to "Clone Hero"; press **Refresh** to choose another open window.
3. The screen appears behind the toms. To move it, open **Kit → Edit layout**, touch the screen with a stick tip and hold the trigger. Change its width in the Clone Hero tab.

How it works: VR Drums copies what Clone Hero shows on your monitor. Keep in mind:
- Clone Hero has to be **visible on a monitor**. If something covers it, you'll see that instead.
- If Clone Hero is minimized, the VR screen says so.
- **Don't minimize the VR Drums window:** Godot stops rendering, VR included, while its window is minimized. Put it behind Clone Hero or on another monitor.
- Borderless or windowed fullscreen works best. Exclusive fullscreen can be switched to borderless in Clone Hero's video settings.

### Fallback: Desktop+

If the in-VR screen doesn't work on your PC, you can use Desktop+ instead. That can happen on laptops with two GPUs, where the monitor can't be captured. Desktop+ is a free, open-source SteamVR overlay on Steam:
1. Start it.
2. Add a window overlay for Clone Hero.
3. Place the overlay where you like.

It floats on top of VR Drums. Turn off our own screen in that case.

## 5. Calibrate

In Clone Hero, go to **Settings → Calibration**:

- **Audio calibration:** play along while wearing the headset.
- **Video calibration:** watch the **in-VR screen**, not the TV. The VR copy is a frame or two behind the monitor, and you're the one playing.

## Tips

- Clone Hero reads MIDI even when its window isn't focused. If it pauses when it loses focus, click its window once before putting the headset on.
- To hear only Clone Hero's audio, turn off **Kit sounds** in the Clone Hero tab.
- The **General MIDI** note map gives every articulation its own note (rimshot 40, open hi-hat 46, ride bell 53, crash edge 55). Use it for recording into a DAW. Stick clicks are never sent.
