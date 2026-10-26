# Brooms: prompts to redraw the images

These prompts redraw **all 27 brooms in the game's style** — pencil and watercolour, like the characters — so the game doesn't depend on third-party images. The batch list (which broom goes in which row of each sheet) is in `batches.json` next to this file.

**Status (2026-10-17):** complete. All 27 brooms are drawn in the game's style in `assets/brooms/`.

## How to use

1. New chat in ChatGPT. **Attach a reference image in the game's style** (for example one of the character portraits in `assets/portraits/`). **Don't attach existing broom images from other sources**: the model would copy their design.
2. Paste the prompt for one batch: **3 brooms per image**, one below the other, in list order.
3. Save the image with the batch name to the local work folder, outside the repository (default `../Quidditch Manager - work/sheets/brooms/<batch>.png`). Source sheets are not published.
4. Import: `godot --headless --path . -s tools/import_crest_sheets.gd -- brooms`. The importer splits the sheet into three horizontal strips, removes the grey background and replaces the files in `assets/brooms/`; they appear in the Encyclopedia, in Finances (buying brooms) and on the player profile.
5. You can continue in the same chat with the next batch; if it drifts from the style, attach the reference again.

If one comes out wrong: "Redo only the top / middle / bottom one with …" and save the full image again. Important: the three must lie **horizontally, handle tip to the left, well separated**; if they touch, the crop mixes them up.

Details given in the books go in square brackets in each batch; the rest of the look is invented [FILLER] so each brand has its own style (Nimbus: dark wood and gold; Comet: reddish birch and bronze or chrome; Cleansweep: oak with bronze bands).
