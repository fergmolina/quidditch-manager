# AI crests: prompts in batches of 4

Crests for the game's clubs and school houses, generated with ChatGPT (or Gemini) in batches of four per image. The batch list (which club goes in which position of each sheet) is in `batches.json` next to this file.

**Status (2026-10-17):** complete. All 238 crests are in the game: the 194 clubs and the 44 houses of the eleven schools. If clubs or houses are added, `python3 tools/add_ai_prompts.py` appends their batches here (prompt text) and to `batches.json`.

## How to use

1. Open a new chat and **attach a reference image in the game's style** (for example a sheet of crests already generated for the game).
2. Paste the batch prompt. Each image asks for 4 crests so the model sticks to the list.
3. Save the image with the batch name to the local work folder, outside the repository (default `../Quidditch Manager - work/sheets/crests/<batch>.png`). Source sheets are not published.
4. Import: `godot --headless --path . -s tools/import_crest_sheets.gd`. The importer crops each crest, removes the background and writes `assets/crests/ai/<id>.png`. Generated crests take priority over the code-drawn ones.
5. You can continue in the same chat with the next batch; if it stops following the style, attach the reference again.

If one crest comes out wrong, ask: "Redo only number N with …" and save the full image again.

Completed batches are removed from this file with `python3 tools/clean_prompts.py`.
