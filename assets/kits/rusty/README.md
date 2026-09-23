# Rusty kit

These samples are mixed down from [Big Rusty Drums](https://github.com/sfzinstruments/karoryfer.big-rusty-drums) by Karoryfer Samples. The source is released under CC0 1.0 (see `LICENSE`), and so are these files. Attribution isn't required, but it's appreciated.

`tools/build_sample_kit.py` generates everything in this folder, and running it again rebuilds the folder from a clone of the source repository. For each articulation it:

- mixes the close and overhead mics to mono, using the kit author's default balance;
- keeps a spread of velocity layers and round-robin takes;
- trims the leading silence and fades out long cymbal tails.

The game loads `kit.json`, which maps each articulation (e.g. `snare/rim`) to its velocity layers.
