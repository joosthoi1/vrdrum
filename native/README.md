# vrdrum_native

This GDExtension gives the game two things Godot can't do on its own:

- **`MidiOut`** sends the kit's hits as MIDI notes, for Clone Hero or a DAW. It uses [RtMidi](https://github.com/thestk/rtmidi): WinMM on Windows, ALSA on Linux.
- **`WindowCapture`** captures another app's window (Clone Hero) to show on the in-game screen. It's Windows only and uses DXGI Desktop Duplication on the monitor showing the window.

The built libraries are committed in `addons/vrdrum_native/bin/`, so the project opens in the editor without building anything. Rebuild them only after changing `native/src/`.

## Building

You need Python 3 with SCons (`pip install scons`) and a C++17 compiler. godot-cpp is a git submodule (pinned to `10.0.0-stable`, Godot 4.7 API):

```sh
git submodule update --init
cd native
scons platform=linux target=template_debug          # needs libasound2-dev
scons platform=linux target=template_release
scons platform=windows use_mingw=yes target=template_debug    # MinGW-w64 cross compiler
scons platform=windows use_mingw=yes target=template_release
```

On Windows with Visual Studio, leave out `use_mingw=yes`.

CI builds all four and runs the tests against them.

## Licenses

- RtMidi (`thirdparty/rtmidi`): MIT-style, see its `LICENSE`.
- godot-cpp: MIT.

## Known issue

Godot 4.7.2 can crash when closing the first time after this extension is added to a project that was already imported. That affects the editor, or `--import`. This happens with any extension that registers classes. Starting it again works.
