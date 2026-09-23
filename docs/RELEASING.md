# Releasing

1. Update `config/version` in `project.godot` (e.g. `0.5.0`).
2. Add a `## 0.5.0` section at the top of `CHANGELOG.md`. It becomes the release notes.
3. Commit, then tag and push:
   ```sh
   git tag v0.5.0
   git push origin v0.5.0
   ```
4. The **Release** workflow then:
   - runs the tests;
   - exports Windows and Linux;
   - checks that the Linux build starts and loads the drum samples;
   - publishes a GitHub Release with `VRDrums-<version>-windows.zip` and `-linux.zip`.

   If the tag doesn't match the project version, it stops.

You can also run the workflow by hand (Actions → Release → Run workflow). It then only builds the zips, as workflow artifacts.

## itch.io

To have releases uploaded to itch.io as well:

1. Create the game page on itch.io.
2. Get an API key at https://itch.io/user/settings/api-keys.
3. In the GitHub repository settings:
   - add a secret `BUTLER_API_KEY` with that key;
   - add a variable `ITCH_GAME` set to `yourname/your-game`.

Each release is then also pushed to the `windows` and `linux` channels.

## Exporting locally

In the Godot editor, choose Project → Export. The presets are in `export_presets.cfg`; install the export templates when the editor asks. The presets include `assets/kits/*/kit.json` (the sample list), which isn't a Godot resource, so it's easy to lose if you edit the presets. The release workflow checks that the build still loads the samples.
