# assets/Materials

One folder per PBR material (colour, normal, roughness maps), fetched with `node tools/textures/polyhaven.js <id> --res 1k`.
Each folder has `SOURCE.txt` (url, author, licence, date). Only 1k (1024 px) maps are kept in git. Pipeline: `docs/Pipelines.md` (1).
An uploaded map gets a line in `assets/manifest.json` (`node tools/assets.js add ...`).
