# Club characters: prompts for ChatGPT

Every club and every school house has an illustrated character: a full-body player in the club's robes, drawn in pencil and watercolour. These prompts generate them in batches; the batch list (which club goes left/right on each sheet) is in `batches.json` next to this file.

**Status (2026-10-17):** complete. All 238 characters are in the game: the 194 clubs and the 44 houses of the eleven schools, and the 13 British ones are clean, with no leftover lettering. If clubs or houses are added, `python3 tools/add_ai_prompts.py` appends their batches here and to `batches.json`.

## How to use

1. New chat in ChatGPT. **Attach one or two reference images in the game's style** (existing character portraits from `assets/portraits/` work well). If a reference contains stray lettering, the prompt asks the model not to copy it.
2. Paste the prompt for one batch: **2 characters per image**, one on the left and one on the right, in list order.
3. Save the image with the batch name to the local work folder, outside the repository (default `../Quidditch Manager - work/sheets/portraits/<batch>.png`). Source sheets are not published.
4. Import: `godot --headless --path . -s tools/import_crest_sheets.gd -- portraits`. The importer crops each figure and writes `assets/portraits/<id>.png`; they appear on the club page and when choosing a club in New Game.
5. You can continue in the same chat with the next batch. If it drifts from the style, attach the references again.

If one comes out wrong: "Redo only the one on the right with …" and save the full image again.

The descriptions vary on purpose (witch or wizard, age, build, position) so they don't all look the same; you can change any detail before pasting.
