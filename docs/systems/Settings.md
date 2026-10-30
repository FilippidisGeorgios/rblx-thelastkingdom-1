# Settings, names over heads, and the buttons at the edge of the screen (Built, 0.39.0)

## 1. The buttons

| Button | Where | What it opens |
|---|---|---|
| **PROFILE** (head and shoulders) | top left, beside the chat | the Muster Roll (`Controllers/ProfileController`); in the Hub also the key `P` |
| **SETTINGS** (a cog) | top left, beside PROFILE | the Settings panel (`UI/SettingsUI`) |
| **INVENTORY** (a backpack) | left edge, middle | in the Hub the inventory; in the castle the pack. The key `B` too. |

All three are `UI/IconButton`: a picture from `UI/Icons` (drawn from UI pieces, nothing to upload) and **no word at all** (the developer's rule
for these buttons: the picture says what it is), on a black plate with a dark-grey edge. The person keeps its parchment colour, the backpack
its leather, and the cog is grey. They lift on hover (the edge lightens), sink on press, and have a small gold number for a prize waiting. The panels open by
sliding and settling from their button and slide away when closed (`Theme.Motion.Enter` / `Exit`).

## 2. Settings (`Shared/PlayerSettings`, `configs/Graphics`, `Services/SettingsService`, `Controllers/GraphicsController`)

**Picture: Low, Medium, High, Ultra.** **Shadows: ON / OFF.** Changeable in the Hub and in the castle; the choice is kept in
`profile.settings` (schema v6) and reaches the client as the player attributes `GfxQuality` and `GfxShadows`, so what was chosen in the Hub is
already drawn when the player arrives. Nothing chosen = High on a computer, Medium on a phone, and the player's own Roblox quality is left alone.

**THE RULE: a quality changes what the picture COSTS, never what the player can SEE.** The brightness, the ambient light, the atmosphere
and its fog, the colour grading and every authored light's colour and reach are the same on all four. A quality only changes:

| | Low | Medium | High | Ultra |
|---|---|---|---|---|
| particles drawn (share of each emitter) | 35% | 65% | 100% | 100% |
| how far lights and fires stay lit | 60% | 85% | 100% | 150% |
| glow (bloom) | off | on | on | on |
| sun's rays, depth blur | off | off | on | on |
| terrain grass | off | off | on | on |
| lights near you cast shadows | no | no | no | **yes** |
| shadow sharpness | | | | sharper |
| shadows start at | OFF | ON | ON | ON |
| the engine's own quality level (asked for once a quality is chosen; **not verified**: a Studio playtest still read Level 21 after Low, and nothing depends on it) | 3 | 8 | 14 | 21 |

(`Domain` test `PlayerSettings.spec` checks that the table carries only these keys: a quality cannot be given a way to change visibility.)

**The shadows switch does not turn the world's shadows off.** That would let the sun through every roof and light the dark rooms, which
is an advantage and the end of the mood. OFF means **simple shadows**: walls, roofs and floors keep casting; the small things (parts under 5
studs: props, people, the dead) stop. The dark rooms are exactly as dark either way; the machine has far fewer shadows to draw.

## 3. Names over heads (`Services/NametagService`)

- **Kingdom Hub:** each player wears a small name of our own: their **nickname** (the Roblox display name, never the `@account`) in cream
  serif letters with a thin brass rule under it, readable at 70 studs. Nobody sees their own. Roblox's own overhead name is off.
- **Forgotten Lands:** **no name at all**, ours or Roblox's. In the castle you are looking at a person, and a label over each head would show
  where your friends are through a wall.
- A custom in-game nickname is still not built (it needs text filtering); the nickname is the display name, as it was.

## 4. The inventory (`Hub/HubInventoryService`, `UI/BackpackHud`)

The Hub's panel is the pack's panel, titled INVENTORY: the purse (with a coin), the stash the runs brought home (with a picture of each
thing), the charm to be worn, and **the prizes of the road**. A prize at every 5th level (`Domain/Prizes`) is **claimed** with a CLAIM
button: gold goes to the purse, items to the stash, the level is marked taken in `profile.prizes.claimed`, the profile is saved at once.
What the prizes ARE is not decided (`Experience.LevelRewards` is empty): the panel says "The prizes of the road are still being forged."
The whole path is tested with a fake reward table (`Prizes.spec`).

## 5. Gold is a coin

`UI/Icons.coin` (a gold coin with a raised rim and a diamond stamped on it) is now used wherever gold is counted: the pack, the inventory,
the forge's purse and prices, and the statistics tiles. `Icons.gem` is there for the day there is a second currency.
