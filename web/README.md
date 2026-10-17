# CoinGarden

A pixel-art coin-dropping puzzle, built with Godot 4.7.2 and WebAssembly.

Drop coins into a piggy bank and connect matching denominations to exchange
them. Two 500-yen coins cash out, and cascades multiply your score.

## Controls

- Tap, click, or press Enter / Space at the blinking TAP TO START prompt.
- Tap inside the piggy bank to drop a coin; drag to aim and release to drop.
- Click inside the piggy bank to drop a coin.
- Arrow keys / A and D: aim. Space: drop.
- Escape / P: pause.
- Music-note button: toggle sound.

After loading, TAP TO START gently pulses over the game board. The first gesture
starts the music, whistle, and START animation together. Retries skip this prompt
and keep the music timeline. Desktop browsers or landscape orientation work best.
Best scores and sound preferences are saved in your browser.

This branch contains the deployable web build. The Godot project is on `main`.
GitHub Pages serves the root of `gh-pages`; `.nojekyll` preserves the exported
files unchanged.
