# ItemArt — the picture of every item (Built, 0.35.0)

**What it is.** Every item the player can hold (materials, consumables, relics, the star shard, the pages) has a 3D
model, AI-generated with the Studio `generate_mesh` tool, and the UI shows it on a card: the name, the picture, how
many, and a small arrow that opens a box saying what the item is **for** and giving a **tip**.

**Where it lives.**

| What | Where |
|---|---|
| mesh id + texture id per item | `configs/ItemArt.luau` (asset ids only: a place needs no copy of the models) |
| "what is it for" / "tip" / flavour | `configs/Items.luau` (`Use`, `Tip`, `Flavour`) |
| the picture (a `ViewportFrame`, mesh fetched once and cloned) | `Client/UI/ItemArt` |
| the card (name, picture, count, arrow, box) | `Client/UI/ItemCard` |
| where cards are shown | the pack in a run (`BackpackHud`, key B) and the Chapel's Stash tab in the Hub |

An item with no entry in `ItemArt` is drawn from its `Look` (a block, a ball, a disc, a bar), so a new item never
shows a hole. Every `page_*` shares the `page` model.

**To add or redo one.** In Studio run `generate_mesh` (segmentation none, `maxTriangles` 3000, `[key]` at the start of the
prompt so the result can be found), read `MeshId` and `TextureID` off the `MeshPart` in the generated model, put the two
ids in `configs/ItemArt.luau`, delete the model from the workspace. No more than three at a time: a bigger batch fails
with "Unable to generate Model" for most of it. A prompt with "fire" in it failed moderation ("fire pot"); a "clay jar" passed.

## The prompts used (2026-10-25)

| key | prompt (after the `[key]`) |
|---|---|
| bone_dust | a small open leather pouch spilling pale grey bone dust, medieval |
| grave_cloth | a small roll of old grey-brown burial cloth bandage, medieval, worn linen strips |
| rusted_iron | three rusted iron bars bundled together, pitted dark orange-brown rust, medieval |
| wild_feather | a bundle of grey and brown goose fletching feathers tied with twine |
| tallow | a lump of yellowish-white tallow wax block with a short wick, medieval candle material |
| grave_silver | a tarnished silver ingot bar with an engraved cross, old mourner's silver |
| hollow_ember | a glowing orange ember crystal inside a cracked dark stone shell, magical |
| bandage | a clean rolled linen bandage tied with string, medieval first aid |
| arrow_bundle | a bundle of eight wooden arrows with grey feather fletching and iron heads tied together |
| oil_pot | a small round clay jar sealed with wax and tied with cloth cord, medieval pottery |
| hearty_dish | a steaming wooden bowl of hearty stew with a piece of dark bread, medieval |
| saints_medal | a worn bronze saint's medal pendant on a short leather cord, medieval religious medal |
| company_signet | a gold signet ring with a carnelian stone engraved with a falling star, medieval |
| brass_stirrup | an old tarnished brass horse stirrup with a short leather strap, medieval |
| mourners_veil | a folded black lace mourner's veil with fine patterns, medieval |
| hollow_lantern | an old black iron lantern glowing with a pale cold blue-white light, medieval |
| sextons_key | a large old iron key with an ornate bow, gravekeeper's key, medieval |
| kings_seal | a round royal seal of dark red wax with a crown impression and a ribbon, medieval |
| star_shard | a jagged shard of a fallen star, pale gold glowing crystal fragment |
| page | a rolled old parchment scroll tied with a faded red ribbon, medieval document |

**Weak ones, to redo when there is a reason:** `hollow_ember` came out a grey stone ball with no glow (the pictured
ember should glow orange); `page` looks like a wrapped parcel more than a scroll; `mourners_veil` reads as a lampshade.

## Not yet pictured

The quest items (plank, pickaxe, axe, keys, jars, the ingredients, the mangonel stone, the torch, broth), the weapons
and the Forge's rows (the Forge lists weapons, which have 3D models of their own in `ServerStorage.Assets.Weapons`),
the Camp bench's recipes (they could use the picture of what they make).
