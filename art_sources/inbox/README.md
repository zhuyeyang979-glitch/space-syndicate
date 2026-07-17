# Quaternius official-source inbox

This directory is intentionally empty in Git. Put only the five approved
official downloads here, then run the extraction and indexing tools from the
repository root.

Accepted downloads:

1. `Universal Base Characters[Standard].zip`
   - https://quaternius.itch.io/universal-base-characters/purchase
2. Ultimate Monsters official Google Drive folder download
   - https://drive.google.com/drive/folders/18m4KpzpEzhC9wl7jzr6dUc0N8Jozr79C?usp=sharing
3. Ultimate Space Kit official Google Drive folder download
   - https://drive.google.com/drive/folders/17F8HlI2zPTlo32aieW5YPPwOk78xo-2m?usp=sharing
4. `Sci-Fi Essentials Kit[Standard].zip`
   - https://quaternius.itch.io/sci-fi-essentials-kit/purchase
5. `Fish Pack Animated by Quaternius.zip`
   - https://quaternius.itch.io/lowpoly-animated-fish/purchase
   - Official Drive alternative:
     https://drive.google.com/drive/folders/1SvlOveJJjmhSn-FgCRyojc1T5QHjjGkF?usp=sharing

The itch.io downloads require the official dynamic purchase/download flow.
There is no stable archive URL in the public page HTML. Do not substitute
mirrors. Google Drive may generate a locale-dependent ZIP name; the extraction
tool identifies a pack from its manifest entry rather than trusting that name.

After download:

```powershell
python tools/art_pipeline/unpack_official_sources.py
python tools/art_pipeline/build_source_asset_index.py
```

The tools reject archives or folders not listed in
`tools/art_pipeline/source_pack_registry.json`.
