## Version 0.42.0 — A tiny health bar, a quieter SKIP, wider dead, and arrows that count

What the developer asked for (2026-10-31).

- **The health bar (`UI/HealthBar`, `Controllers/HealthController`, `configs/Hud`, `Shared/HealthColor`).** A tiny bar (92 by 11 pixels) in the
  bottom-left corner of every player's screen in the Forgotten Lands: a black outline, a fill that goes green, yellow, orange, red (blended
  between the four) as health falls, and the percentage in 9 pixel letters inside it (rounded up, so a sliver never reads 0). Roblox's own
  health bar is switched off in both places: the arrival scene switches every Roblox gui back ON when it ends, and `CoreGuiChangedSignal` is
  not open to game scripts, so the controller looks once a second and switches it off again (seen: still off after the scene). Not drawn in the
  Hub (nothing there can hurt you). `HealthColor.spec` tests the colours and the rounding.
- **SKIP (`UI/IntroUI`).** A small plate only as big as its one word: the word SKIP in bold cream letters (17 to 25 px, larger than before), on golden
  brown, with a thin gold edge that shines now and then, and a gold fill that rises while held. It says nothing else (no "hold", no vote
  words): a party's votes are shown as small dots under the plate. For the first 2 seconds it is fully there, then it fades to 40% (so it does not
  trouble the scene), is full while held, and comes back for a moment when a friend has held theirs. The hold of 3 seconds and the vote table are
  unchanged. Seen in a playtest.
- **The dead are about 7% wider, not taller (`tools/WidenUndead.luau`).** All ten bodies in `ServerStorage.Assets.Undead` were thickened sideways
  (widths +6.8%, heights +0.04 studs): the parts moved out from the middle by 7% sideways only, thickened along their sideways faces, the joints'
  C0 written again from where the parts now are (rotations of all 107 parts of a shambler unchanged to 0.000 degrees; joint error 0.000), the
  welds that hold helmets and plates switched off and on again, the invisible hit box left alone. Their heads and everything else are as
  they were: the developer is happy with the look and the `Head2` swap was cancelled. The result lives in the place, so it needs a Save.
- **Arrows that pass between the limbs now count (`World/ProjectileService`).** The trace was a thread, and a body is limbs with air between: an arrow
  that went between an arm and a torso, or by a shoulder, was a "miss" nobody could see the reason for. When the thread has not struck a body, a
  sphere of 0.9 studs is run along the same stretch against the bodies of the other side only, and counts if it finds one before any wall.
  Measured with an archer shooting a player whose thread-hit width was 2.0 studs: 8 of 8 arrows count out to 2.8 studs off the middle, 0 of 8 at 3.4;
  and with a wall in front, 0 of 8 (cover still works).
- **A first simple set of weapons (`docs/systems/Realism.md`).** A sword, a shield and a brigandine chest piece were generated beside the bow
  (all readable), and the rules for a weapon's hit shape and the design of skins and rarities were written. Not wired in.
- **Found while doing it.** `StarterGui.CoreGuiChangedSignal` cannot be connected from a game script (it needs a capability): poll
  `GetCoreGuiEnabled`. A `CanvasGroup` fades a plate, its edge and its word with one number. `Weapons.luau` still says "ranged is not
  implemented": the enemy archers' `ProjectileService` exists; a player's bow does not.

## Version 0.41.0 — Crouching, rooms that are dark, and the Kitchens' cellar: the first step of the bigger run

What the developer asked for (2026-10-30): start on the areas; a camera that zooms out less; "ducking through low passages, a maze, a mine, fear".
The design is `docs/systems/BigRun.md`; this is its first built slice, tested in Studio end to end except by eye (the PC was locked, so Studio
could not draw a picture: everything below was measured with rays, terrain reads and a character that walked it).

- **The camera stops at 25 studs** (`configs/Camera.MaxZoomOut`, was 30, the engine's was 128).
- **Crouching (`configs/Crouch`, `Domain/Crouch`, `World/CrouchService`, `Controllers/CrouchController`).** Key C (a picture button on a phone,
  a small ducking figure, gold-edged while crouched: `Icons.crouch`, `IconButton.setActive`). The body shortens to a BodyHeightScale of 0.5 for
  every player (measured on the tallest avatar scale: 5.15 studs standing, 2.97 crouched, so a 3.4 passage fits everyone and stops a standing
  body), the walk is half speed (a CLAIM on WalkSpeed, so the Brass Stirrup and the King's frost are not trampled), and `Crouching` is published
  on the Player for the hunters to come. **The server decides when you stand:** five rays straight up from the head; under a ceiling you stay
  down and a line says "There is no room to stand." A first version on purpose: a shorter, slower body. A real crouch (bent knees) is an animation
  for the animation pass. `Crouch.spec` tests the claim, the key gap and the room.
- **Light zones (`configs/LightZones`, `Shared/LightZone`, `Controllers/LightZoneController`).** A real ceiling stops the sun but not Roblox's flat
  ambient light, so a built cellar would still glow. A tagged, invisible box (`TLK_LightZone`, attribute `Profile`) turns the ambient light, the sky
  reflection and the haze down while a player is inside and gives the place's own values back when they leave, over a fade. Measured: ambient from
  (40, 41, 50) to (6, 6, 8), sky reflection 0.6 to 0.05. The same for every player whatever picture quality they chose (the fairness rule), and a
  spec checks a zone may change nothing but those properties. `LightZone.spec` tests the geometry (also a turned box) and which of two zones wins.
- **The Kitchens' cellar (`tools/BuildCellar.luau`, `Trial/Cellar`, a Deed of area 3).** An open stone stair beside the kitchen hall down to a locked
  door; behind it a larder (shelves, casks, hams, a table, a chest); then a LOW passage (3.4 high, two bends: you must crouch); then a flooded
  vault under the Dairy with a hoard on a dais and three mounds of rubble where the dead dig up through the floor. 252 parts, cut out of the
  terrain. **The errand:** five of the yard's seven buildings get a thing to search (a sack, a crock, a bucket, a cask; hold the prompt), one of
  them holds the key (rolled each run; some of the rest hold a bandage), the door opens for any hand, the larder's chest is the ordinary reward,
  and lifting the hoard's lid wakes the **Crawlers**, which come up behind you as much as in front (three, scaled by party and depth); when the last
  falls the hoard's prize drops for everyone. Never needed for the gate. First place the Crawler is used.
  `Items.cellar_key`, `Loot.deed_kitchen_larder` and `deed_kitchen_hoard`, `Gather.BUILDERS` (the props, shared), `TrialService.devHandle`
  (a development seam). Tested live: the stair walks down, the closed door stops you, a standing body stops at the low opening and a crouched one
  walks A, B, C into the vault, standing under the low roof is refused and in the vault allowed, the key is found, the door swings, the chest opens,
  four crawlers rise (one player, x1.3) and the deed completes when they fall.
- **Found and fixed while building it.** Smooth terrain reaches half a cell (2 studs) beyond a full cell toward an empty one, and a box that covers
  only part of a cell only lowers its fill: cutting the stair in one-stud slices cut nothing, and a ceiling at y -3 had terrain at -5 hanging
  through it. Cuts are now rounded out to whole cells with a cell of margin, ceilings sit at -6.3 (under where the ground hangs), the trench's walls
  are three studs thick on the outside. `Humanoid:PlayEmote` and a ProximityPrompt both need a rendering client, so a script cannot press a prompt
  while the PC is locked: the deed has a `dev` table for tests.
- **The realism test (`docs/systems/Realism.md`).** Five models made with `generate_mesh` to see what it can give for the weapons and the dead
  (kept in `ServerStorage.Assets.RealismTests` of the Forgotten Lands, not in the game): a vague prompt gave a broken bow and a cartoon head, a precise one
  gave a clean strung longbow and a realistic undead head with burial wraps (smooth, with a face). Nothing is wired into the game yet.
- **Not built yet:** the entering scene for the big areas (a banner and a change of light as the party crosses in), the mark (ping) key, the forest,
  the catacombs, the other big areas. `docs/systems/BigRun.md` §10 has the order.

## Version 0.40.0 — A loading screen with a real bar, a camera that stops at 30, a longer and livelier arrival scene, skip by holding, and graphics that work in the Hub

What the developer asked for (2026-10-30), built; and the design for the bigger run written down (`docs/systems/BigRun.md`).

- **The loading screen (`ReplicatedFirst/TitleScreen`, `ReplicatedFirst/Loading`).** Black, a castle drawn in gold from UI pieces (a keep with its flag
  and battlements, two towers with red roofs, the wall, a gate with its portcullis; the flag waves and two windows flicker), THE LAST KINGDOM under it,
  and a bar. The old card (a question and a PLAY button, a blur of the world) is gone: nobody presses anything, the screen leaves by itself when the
  bar is full. The bar is the real work: the game loaded (10%), then every picture, mesh, sound and animation the world uses, found by looking
  through Workspace, Lighting, SoundService and ReplicatedStorage, listed once each and fetched 24 at a time, six requests at once (to 80%), then the
  player's body and the ground round it (`RequestStreamAroundAsync`, to 95%), then two drawn frames. Limits so a bad connection is never a locked
  one: 25 seconds for the assets, 12 for the body, 8 for the ground, 45 for the whole screen; and at least 3.5 seconds so the name can be read. The
  line under the bar says where it is in simple words ("Opening the gates...", "Raising the walls...", "Lighting the torches...").
- **The arrival scene waits for it.** `Loading` sets `ReplicatedFirst:TLKLoaded`; the new `Controllers/LoadingController` turns that into
  `ClientReady` (new in `Net`); `IntroService` begins only when every player in the server has said so (30 seconds at most, `WaitForLoadingSeconds`),
  so nobody's first seconds of the scene play behind a loading bar.
- **Hold to skip (`UI/IntroUI`, `Intro.SkipHoldSeconds = 3`).** A tap does nothing: the SKIP plate fills with gold while it is held and sends the vote
  when full; let go early and it empties. The votes needed are the developer's table (`Intro.SkipVotes`, tested by the new `Domain/SkipVote` and
  `SkipVote.spec`): 1 player 1, 2 players 2, 3 players 2, 4 players 3, 5 players 3, 6 players 4, 7 players 5, 8 players 5, 9 players 6, 10 players 7
  (past ten, 70% of the party). The plate shows how many have held so far ("HOLD TO SKIP 1 / 3", then "WAITING 1 / 3").
- **The arrival scene looks like a film (`UI/IntroCinema`, `Controllers/IntroController`, `Intro.Beats`).** Beats now have a SHOT: the long look from a
  mark to a mark (as before), OVER THE SHOULDER of the one who speaks (their head low in the frame, the castle behind it), or their FACE, three-quarters,
  on a long lens with everything behind it soft. The speaker's Roblox head is in the dialogue box beside their name. The camera is hand-held (Perlin
  sway, a breathing field of view), a depth-of-field lens focuses differently for each kind of shot (`Intro.Focus`), a slightly cooler grade is laid
  over the scene, ash and a few sparks drift across the frame, and a double flash of lightning lights the hill at the line "Something is still moving
  behind those walls". The title card settles from a little too large and draws its gold rule from the middle. All of it is made when the scene
  starts and removed when it ends (counted: three effects in, three out). The depth blur is a post effect like the others, so Low and Medium switch it off.
- **The camera stops at 30 studs (`configs/Camera`, `Controllers/CameraController`).** Roblox allowed 128. Zooming IN is untouched. A number to tune by playing.
- **Graphics in the Hub (`Controllers/DetailLodController`).** The picture quality changed little in the lobby: only the castle's lights and fires carry the
  `TLK_Lod` tag, and the Hub has none. In the Hub the controller now takes every light and fire that is not on a character, as it arrives, re-reading its
  position each time (the train moves) and remembering what it was doing when it was cut. Measured in a Hub playtest: Low switches 50 of the 111 lights off
  by distance (High 20, Ultra 13) and Ultra gives 16 near lights their shadows (High and Low 0).
- **The settings cog in the castle.** It was already there (both places run `HudController`); the arrival scene hides it and gives it back when it ends
  (seen in the playtest). If it is missing from the published game, that place has not been saved with the 0.39.0 scripts yet.
- **Found and fixed while testing.** A portrait sized by a `UIAspectRatioConstraint` with a zero width was 0 by 0 (it is squared to the box in code now).
  The depth-of-field tween (0.9 s) left the first second of a face shot blurred by the lens of the shot before it (0.3 s now). The first shoulder shot put
  the speaker's hair against the lens (further back and lower now; a player's hat or wings can be any size). Roblox's `Humanoid:PlayEmote("point")` did
  not play for the speaker in a Studio playtest, so the gesture was taken out rather than left as a feature that does nothing. Preloading the Hub's door
  sounds prints two warnings ("Asset type does not match requested type"): the sounds' ids are wrong in the Toolbox model, not our code.

## Version 0.39.0 — Danger, the Settings panel, the Inventory tab, names over heads, the roll of honour, and gold as a coin

What the developer asked for (2026-10-30), built.

- **Colours.** Every button that was a bright red or a lime green is now a DEEP BURGUNDY or a DEEP FOREST GREEN with cream lettering (white
  with a breath of yellow, not gold): `Theme.Color.Bordeaux/BordeauxLight` darkened, a new `GreenTop` for the top of a green button and `Green`
  for its foot; the `green` and `danger` button variants write in `Theme.Color.Cream`; the title screen's Play button uses the same green.
  Red and green TEXT on a dark panel (a warning, "Ready", "Hard") keeps its readable tones.
- **Danger (`Shared/Danger`, `configs/Difficulty.Danger`, `docs/systems/Danger.md`).** One figure from 0 to 100, "+34 of 100 harder", made of the
  mode (Hard = 25) and the party's average level, kept small by a shield for new players (the third-weakest player decides: three or more
  rookies keep 15% of the veterans' points, fading to the full average from level 20; fewer than three are never shielded). It reaches the
  waves, the trials, the King and the pay through `Scaling.setRunDanger`, set by the new `World/RunDifficultyService` when a run begins.
- **Normal / Hard on the train.** A party of five or more plays Hard and Normal is shut to it; a smaller party may choose Hard
  (`berth.wantsHard`, `RequestTrainBoard(size, hard)`). The panel has NORMAL / HARD buttons, a Danger meter that warms from green to red with
  a line saying where the points come from, and previews the figure from your own level before anyone boards; aboard, the party card shows the
  figure the server worked out for who is really there. The whole panel is drawn about 10% smaller. The mode was only a label before: it is real now.
- **Experience for helping, not only for killing (`Domain/RunXp`).** Beside the dead, the chambers, the deeds and the victory, a run now pays an
  assist (3, a blow on an enemy someone else finished within 12 seconds), a fallen friend raised (40), and the minutes on your feet (6 a minute,
  60 minutes at most). A player who took no part (under 100 of damage, assists and revives together) is paid the shared prizes at 30% and no time.
  Assists, revives and active seconds are counted by `RunStatsService` (`DeathService.onRaised` is new) and kept in the statistics; the Roll shows
  ASSISTS and FRIENDS RAISED.
- **The roll of honour (`Domain/Mvp`, `UI/EndingUi`).** On a victory the closing card ends with the company in order of what each did: a name, a quiet
  line ("42 slain · 6 assists · 2 raised"), a thin bar, a laurel on the first place when there are two or more. Nothing punishes: falling does not count.
- **Settings (`Shared/PlayerSettings`, `configs/Graphics`, `Services/SettingsService`, `Controllers/GraphicsController`, `UI/SettingsUI`).** Low,
  Medium, High, Ultra and a shadows switch, kept in `profile.settings` (schema v6) and drawn in both places. A quality changes what the picture
  costs and never what can be seen. Shadows OFF means SIMPLE shadows (the walls and roofs keep casting, the small things stop), because turning the
  world's shadows off would light the dark rooms. `docs/systems/Settings.md`.
- **The buttons.** PROFILE (a head and shoulders) and SETTINGS (a grey cog) beside the chat, INVENTORY (a larger backpack) on the left edge, all drawn from
  UI pieces (`UI/Icons`, `UI/IconButton`) with NO words on them, on a black plate with a dark-grey edge, with hover, press and a sliding open and close. The Roll now opens in the castle too
  (`Services/ProfileService`, moved from `Hub`).
- **Names over heads (`Services/NametagService`).** The Hub: each player's nickname in a small cream serif with a brass rule (nobody sees their own).
  The Forgotten Lands: no name at all. Roblox's own overhead name is off in both.
- **The Inventory and the prizes of the road (`Hub/HubInventoryService`, `Domain/Prizes`).** The Hub's inventory shows the purse, the stash with a
  picture of each thing, the charm, and a CLAIM button for each prize of the road that is waiting; claiming puts gold in the purse and items in the
  stash, marks the level taken (`profile.prizes`, schema v6) and saves at once. `Experience.LevelRewards` is still empty, so nothing waits yet.
- **Gold is a coin.** `Icons.coin` in the pack, the inventory, the forge's purse and prices and the statistics tiles.
- **The Crawler (`Domain/CrawlerBody`, `undead_crawler`, Bestiary 5.2).** A legless dead that drags itself along on its arms, made at spawn from
  a shambler body: everything joined to a leg is found by following the joints out from the thighs and removed, the torso is laid down by the Root
  joint's C1 (so the standing clips still read), the head lifted, the arms turned to reach, two thighbones broken off at the hips. 36 health, speed
  8.5, notices you from 70 studs; it shares the shambler's attack clip. Tested live (it chases, attacks, dies and sinks) and by `CrawlerBody.spec`.
  NOT placed in any wave or area: where it first appears is the developer's call.
- **Found and fixed while testing.** A weak-keyed table of Instances loses its entries (the Lua proxy of an instance nothing else refers to can be
  collected), so the first GraphicsController stopped no shadows; its tables are strong now and pruned every 30 seconds. The title screen's Play
  button put cream text on a gradient plate (dark green on black, the same trap `Components.button` documents); its word is a child label now.
  `EndingController` dropped the roll of honour from the payload; it forwards it now. The profile buttons overlapped Roblox's chat button: they start
  at `GuiService.TopbarInset`. The train panel overflowed a short screen: it measures itself and shrinks to fit.
- **Other.** `DetailLodController` takes the quality's light distance and Ultra's near-light shadows; `PlayerCard` carries `assists` and `revives`.
  `Experience.Spec`-style tests added: Danger, Mvp, AssistLedger, Prizes, PlayerSettings, CrawlerBody (all pass in both places).

## Version 0.38.0 — The profile grows up: the Company number, levels to 100, Renown, statistics, and the train knows who is aboard

What the developer asked for in the profile (2026-10-30), built: the profile shows the level and the nickname, a unique ID for the
admin panel to come, a level cap of 100 that is easy up to 30 and hard after, a prize at every 5th level and a milestone at every
10th, the player's overall rating, their statistics, and all of it on the train.

- **The Company number (`Domain/PlayerId`, schema v5).** `TLK-03YB-HWSR-T`: the Roblox user id in Crockford base 32 with one check
  character. Made, not counted (no global counter, no DataStore call, the same in both places), given ONCE and stored in
  `profile.account` (`ProfileSchema.stamp` on every load: `{ id, userId, name, displayName, since, lastSeen }`), so it never changes even if
  the scheme does. `PlayerId.decode` goes back to the user id for the admin panel; a typed number is forgiven its case, spaces and O/0
  and I/L/1, and any single wrong character is refused. The nickname is the Roblox display name; a custom nickname is not built.
- **Levels 1 to 100 (`configs/Experience`).** The table is built from five numbers: 60 XP for the first level, +12% a level to level 30
  (about 12,900 XP in all), then +4% a level to 100 (about 597,500 in all; level 99 alone costs 24,000). Ranks change every tenth level
  (`configs/Profile.Titles`: Recruit, Footman, Man-at-Arms, Sergeant, Standard-Bearer, Knight-Errant, Banneret, Castellan, Marshal,
  Lord Marshal, Warden of the Last Kingdom).
- **The road and its prizes (`Domain/LevelMilestones`).** A prize stop at every 5th level, a milestone at every 10th, twenty stops in all,
  drawn on the Roll (gold reached, the tens larger, the next outlined, "still being forged"). What the prizes ARE is not decided:
  `Experience.LevelRewards` is empty. `RewardService` already reports the prize levels a gain passes (`Applied.prizeLevels`, logged), which is
  where handing them over will go.
- **A run now pays experience (`Domain/RunXp`, `configs/Experience.Sources`).** Before this, only the old placeholder missions paid XP, so no
  one could level in the real game. At the end of a run each player is paid for the dead slain by tier (2, 8, 60), each chamber cleared
  (30 + 10 x n), each deed (60) and, on a victory, 300. A wiped run pays all but the victory bonus (progress persists). The ending card
  says "Experience: +530 (level 7, Recruit)".
- **Statistics (`World/RunStatsService`, `Domain/PlayerStats`).** The run counts, per player, the dead by tier, the damage dealt (health actually
  removed), the times fallen, the chambers cleared and the deeds; at settlement they are added to `profile.stats` (kills, elite and boss
  kills, damage, falls, chambers cleared and the deepest, time in the castle, the fastest victory, gold brought home, xp earned) beside the
  runs won and lost. A deed is written at once to every player as the achievement `deed_<id>` (`TrialService.onDeed`), so a wipe cannot lose it;
  the page's "deeds done" now counts those (before, nothing ever wrote one).
- **Renown (`Domain/Renown`, `configs/Profile.Renown`).** The whole player in one number out of 9,475: Rank, Might, Victories, Depth,
  Deeds, Lore, The Star, Slaying, each part CAPPED so that no one thing makes a name (a billion kills are worth 500). Six bands from
  Unknown to Legendary, a bar for every part on the Roll. It sets nothing about difficulty: that stays Might alone.
- **The Muster Roll (`UI/ProfileUI`)** now opens with the portrait, the nickname, `@account` and the Company number, the rank, `LEVEL n OF 100`,
  the xp bar, the xp earned in all; then the road, Renown, Might, Arms, the record, a statistics grid (the dead slain, elite/boss, damage,
  times fallen, chambers, deepest, time in the castle, fastest victory, gold brought home, best run), the collection and the charm.
- **The train (`TrainService`, `UI/DepartureUI`).** Every member aboard comes with `{ level, title, might, renown }` from
  `ProfileService.brief`; the panel shows the name and, under it in a smaller hand, `Lv 12 · Sergeant · Might 5`, and for two or more the
  party's Might (the average, `TeamPower.partyRating`). It is shown, not yet used: the difficulty still scales by head count.
- **Found and fixed while testing.** A require cycle (TrialService -> Trial/Exit -> RunSettlement -> RunStatsService -> TrialService) failed four
  modules at load; RunStatsService now requires TrialService when it starts. A dead enemy is gone from the combat registry before
  `DamageDealt` fires, so kills were not counted until the target is taken from the damage pipeline's seam just before the blow.
- **Tests.** 223 specs pass in both places (41 new: `PlayerId`, `LevelMilestones`, `RunXp`, `PlayerStats`, `Renown`, `Experience`, more of
  `PlayerCard` and `ProfileSchema`); both projects build.
- **Seen (2026-10-30, real playtests).** Forgotten Lands: a harness script in the running game killed 40 dead with real blows, cleared chambers,
  fell once and ended the run as a victory: +530 XP (level 1 to 7, the prize at level 5 logged), kills 40, damage 2,400, downs 1, chambers 2,
  deepest 5, fastest win 20 s, one deed written and counted once; the test profile was put back. Hub: the Roll with the real profile
  (ID, nickname, level 1 of 100) and with a synthetic level-37 card (the road, Renown 4,418 "Renowned", the statistics); the train panel
  with the name and `Lv 1 · Recruit · Might 1`.
- **Not seen.** The Roll and the train on a phone; the train with two or more people; the ending card's new XP line (sent to the client,
  not looked at); a real full run that earns its XP by fighting (the harness did the killing); deeds from live chambers other than the one tried.

## Version 0.37.0 — The Muster Roll: every player's own page in the Hub

The first step of the profile work. The Hub now has a page for each player (key `P`, or the `ROLL` button in the corner), built from
that player's own profile, and it shows the numbers the difficulty already works from, so the fairness rules can be seen.

- **The page (`UI/ProfileUI`).** The portrait (the avatar's head), the name, a rank title from the level (`configs/Profile`: Recruit, Footman,
  Man-at-Arms ... Warden of the Last Kingdom), the level and an xp bar, the gold held. **Might** `n of 10` with its band (Raw, Blooded,
  Seasoned, Hardened, Veteran) and ten pips; what that means ("you strike 77% harder than a fresh blade, the dead grow only 39% for it,
  so you keep an edge of x1.28"); **Arms** (every weapon with its forging as pips, a locked one saying when it opens); **the record**
  (runs won and lost, the best run, deeds); **the collection** with pictures (pages copied, shards laid on the altar or the raised
  star, kinds stashed) and the **charm worn** with its picture.
- **Might is the rating that already existed.** `Domain/TeamPower.playerRating(levels, "Best")`: the best weapon forged, which owning more
  can never lower; the party is the average; the dead grow by half of the gain. The page only reads it (`Domain/PlayerCard.build`,
  pure, `PlayerCard.spec`). It was written and tested before and read by nothing; now a player can see it.
- **Server-authoritative and private.** `Hub/ProfileService` answers `RequestProfile` with `ProfileEvent` built from the profile of the
  asker. The request has no player id, so no one can ask for another's page; it is throttled and read-only.
- **Hub only.** `ProfileController` stands down in the Forgotten Lands (the same Client tree boots in both).
- **Docs.** `docs/systems/Profile.md` (what each number is built from, the four fairness rules, what is not built), the Progression and
  systems index pointers, the backlog (profiles and fairness: the developer's ideas still to be told).
- **Tests.** `PlayerCard.spec` (11 cases: new player, xp progress and the cap, Might as the best weapon, clamped levels from older
  builds, the half rule and the edge, a tier for every level, locked arms and a stable best arm, record and collection, the charm only
  while owned, the config). 182 specs pass in both places; both projects build.
- **Seen in the Hub (2026-10-30, a real playtest).** The panel with the test account (level 1) and with a synthetic card (level 6, +7
  sword, three pages, four shards, the veil): every section, the pictures, the X, `P` opening and closing, the corner button. Found and
  fixed on screen: "0% as hard" wording; tile captions cut; the best arm of a new player was a locked spear (it is the sword now);
  unlocked arms listed first.
- **Not built, waiting on the design talk.** Points as a separate score beyond Might; another player's roll; the party's rating on the
  train; a crest per rank; weapon pictures on the arms. Not seen: the Roll on a phone.

## Version 0.36.0 — The charms work: the Veil, the Stirrup and the Lantern

The Reliquary let a player wear a relic from the stash, and five of the six did nothing. Three of them now do what their words say.

- **Mourner's Veil.** The first blow of a run that would have killed the wearer leaves one breath instead (`Charms.lastBreath`, a damage
  modifier on the combat pipeline in `CharmService`). Once per player per run: spent until `DeathService.onRunBegin`; the spending is the
  Player attribute `VeilSpent`, so leaving and coming back does not mend it. The player sees a banner with the veil's picture,
  **THE VEIL HOLDS**, and a breath of gold across the view (`UI/CharmCue`, the `CharmEvent` remote).
- **Brass Stirrup.** Five quiet seconds (no blow given or taken) and the wearer walks 8% faster, until the next blow. The charm takes a
  *claim* on the Humanoid's `WalkSpeed` and gives it back (`Charms.calmSpeed`); it never writes over a speed somebody else set in between.
  The King's frost, which does set the speed, now marks the Humanoid `SpeedHeld` (the stirrup stands back) and starts from the
  `BaseWalkSpeed` the stirrup publishes while it holds a claim, so the two cannot fight or leave a player stuck fast or slow.
- **Hollow Lantern.** The dead notice the wearer from a fifth less distance (`notice` 0.8). `EnemyBrain` takes an optional `noticeScale`
  and uses it only for taking a target in (Idle and Return), never for the leash or the attack range, so a unit already on you
  behaves as ever. `EnemyAIService` weighs each hostile by distance / scale, so in a party the dead turn to the unlit player first.
- **Data.** `configs/Chapel.luau → Charms` now says, per charm, `Mods` (RunModService mods set at the gate by `RunKitService`) or `Pending`;
  `RunModService` gains `calmSpeed`, `notice`, `lastBreath`. The Signet (parry) and the Sexton's Key (locked caches) stay `Pending`,
  as before, because the parry and the caches do not exist.
- **Pictures.** The pack (`B`) opens with **Charm worn**: the charm's card (name, picture, rank) and its state, READY or SPENT for the
  veil, WORN for the others (`ItemCard` gained `Status`). The three item tips no longer say "not yet wrought".
- **Tests.** `Charms.spec` (the veil's rule, the stirrup's claim: taken, kept, given back, never over somebody else's; the config), and
  three `EnemyBrain.spec` cases for the lantern. 171 specs pass in both places; both projects build.
- **Seen in the Forgotten Lands (2026-10-30, a harness script in a real playtest, since removed).** Veil: a blow of 500 dealt 99 and left 1
  health, `VeilSpent` went true and the banner came up; the second blow killed. Stirrup: 16 became 17.28 half a second into a calm, went
  back to 16 on a hit and was 17.28 again five seconds later; with `SpeedHeld` set it stayed at the King's 16 and then 8; a speed of 10
  set by something else was taken as the base (10.8). Lantern: a shambler (radius 110) 100 studs away walked 20.4 studs in 4 s without
  the charm and 0.0 with it, and 17.4 at 80 studs. The pack's "Charm worn" card (READY) and the banner were seen on screen.
- **Not seen.** The handover from the Hub's Reliquary through `RunKitService` (it sets the same mods; read, not played end to end); the
  stirrup's 8% by feel; the lantern in a crowd with two players; a veil saving a real hit in a real chamber.

## Version 0.35.0 — The UI gets its colour: warm palette, red ways out, green ways forward, X windows, and a picture of every item

- **Palette (`UI/Theme`).** The blue-grey navy surfaces are now walnut and leather browns over warm black; gold is brighter, with a golden
  brown (`Bronze`) between it and the walnut; text is beige; the muted grey is a warm sand that reads on dark brown; the steel blue of the
  stat lines is tan. Buttons were being darkened twice (a dark background multiplied by a gradient); the background is now white so the
  gradient shows as written: every button is livelier. The old names are kept (`Navy` is the walnut), so every screen restyled at once.
- **Two colours with a meaning, never swapped.** Every way OUT is **bordeaux red** (`Variant = "exit"`: the Dialogue's LEAVE, the train's
  LEAVE, the new X); every way FORWARD is **green** (`Variant = "confirm"`: DEPART NOW, CREATE and JOIN PARTY, the Forge's buy buttons, the
  Chapel's TAKE, MAKE and LAY A SHARD). Gold-brown is the neutral action (WEAR, READ, CONTINUE). `Components.setVariant` repaints a built button.
- **The X.** The Forge, the Chapel and the pack have a small red square X in their top-right corner (`Components.closeButton`) and no
  "leave" button under the list; the Dialogue and the train keep their red button.
- **Panels fit the screen.** The Forge, the Chapel and the pack are as tall as the window allows (94%/78%) and their list scrolls inside:
  a panel taller than the window took no clicks in its list (found with a real mouse in the Hub).
- **A picture of every item (`UI/ItemArt`, `UI/ItemCard`, `configs/ItemArt`; `docs/systems/ItemArt.md`).** Twenty AI-generated meshes
  (Studio `generate_mesh`): the name, the picture (a ViewportFrame), how many, the rank, and a small arrow that opens a box with what the
  item is FOR, a TIP and its line of flavour (`Tip` is new in `configs/Items`, written for every banked item and the pages). Shown on the
  pack in a run (replacing the text rows) and on the Chapel's new **Stash** tab (two cards across), and as a thumbnail on the Tithe's shelf
  and the Reliquary's charms.
- **The Chapel has a fifth table, the Stash** (a storeroom: an iron-banded chest with its lid open, sacks, crates, a lantern; ring
  `chapel_stash`), and **has moved**: a column on the east side of the plaza facing the spawn, beside the path to the train (`BuildChapel`
  rotates the whole row, `FACING`). Nothing overlaps a building (checked with a part query).
- Seen in Studio: the Chapel's Tithe and Stash tabs after the restyle, the Forge, the Dialogue, the train's party screen, the
  pack in the Forgotten Lands (clipped by the short window), and a contact sheet of all twenty meshes. Not seen: the Reliquary, Altar and Journal tabs
  after the restyle, the Forge in a window tall enough to show all its rows after the resize, the pack's X.

## Version 0.34.0 — The Hub spends the stash: the Chapel (Tithe, Reliquary, Star Altar, Journal)

- **The Chapel (`Server/Hub/ChapelService`, pure rules in `Server/Domain/Chapel`, `configs/Chapel.luau`).** Four tables, one screen
  (`UI/ChapelUI`, four tabs, the forge's look), opened by four rings in the Hub (`configs/Interactions`: `chapel_tithe`,
  `chapel_reliquary`, `chapel_altar`, `chapel_journal`, models `Lobby.Chapel.<Name>`). Server-authoritative: the client sends
  `{action, id}` (`RequestChapel`) and is sent the whole state back (`ChapelEvent`); every change is saved at once, because the world
  loads the profile at the next boarding.
  - **The Tithe:** 60 bone dust for one of **today's shelf** of three (the same shelf for everyone all day, by UTC day number): hearty
    dish, oil pot, arrow bundle, bandage, tallow, grave silver. A pick that is a consumable goes to the **kit** (carried into the next run);
    grave silver stays in the stash for the Reliquary.
  - **The Reliquary:** the one **charm**, any relic of the six in the stash, worn run after run (`profile.loadout.charm`; Saint's Medal
    puts a bandage in the pack at the gate, the other five can be worn and do nothing yet, and the panel says so); and the **Blessed Edge**
    (1 Hollow Ember + 2 Grave Silver, one at a time): for the next run only, blows land 10% heavier (`RunModService` source).
  - **The Star Altar:** one star shard at a time, nine in all (`profile.altar.offered`); the ninth raises the Falling Star
    (`achievements.falling_star`, and a `FallingStar` attribute on the player in the Hub and the world, for the tabard later).
  - **The Journal:** the pages (`configs/Pages`, five of them, one for each Deed that is a place with a paper: the Sexton's Ledger, a
    Smith's Tally, the Clerk's Muster, the Marshal's Dispatch, the Chancery's Last Page), in the castle's order; a page not yet found
    shows only where it was written. They are new `page_*` items given by the deeds of chambers 4, 5, 7, 8 and 9 (`configs/Loot`,
    `configs/Items`), banked in the stash and never lost, even on a wiped run.
- **The gate hands it over (`Server/World/RunKitService`).** When a player's profile is in, in the Forgotten Lands: the kit goes into the
  pack, the charm's gift with it (a Saint's Medal: +1 bandage), the blessing becomes a run mod, and `kit` and `blessing` are cleared and
  saved on the spot (the charm stays on). Anything unused is banked back at the end of the run like everything else.
- **ProfileSchema v4:** `loadout = { kit, charm?, blessing? }` and `altar = { offered }`; v1 to v3 profiles migrate.
- **`tools/BuildChapel`** (run in the Hub place, Edit mode) builds the four tables: an alms table with a bowl of bone dust, today's three
  plates, candles and a hanging sign; a stone table with a glass casket and an ember, two candelabra and a cloth; the altar on three steps
  with a stele of nine niches, a shard hanging in light and two braziers; a lectern with an open book, quill, ink, a stool and a
  bookcase of rolls. The rings are drawn round whatever the models are, so the models can be dragged anywhere.
- `Chapel.spec` (12 specs: the daily shelf, the price, refusals that change nothing, charm, blessing, the ninth shard, the journal, what
  the next run is handed once, and a check that the config names only things that exist and every page is given by a deed). 157 specs pass.
- Verified in a Studio playtest of the Forgotten Lands with a copy of ChapelService booted there: every action through the real remotes
  (tithe, a pick not on the shelf, forge twice, three charms, nine shards and a tenth), the panel rendering the state, and then a fresh
  join receiving the kit (two arrow bundles and the medal's bandage), the blessing (x1.10 damage), the kit cleared and the charm kept.
  Not seen: the Hub itself (the models were built and looked at in the Forgotten Lands and removed; the Hub place has not been opened
  with this code), and the panel at full height (the Studio viewport was 394 px tall).

## Version 0.33.0 — Closing the run: the camp, the bank, the prisoner's due, the wipe

- **The run is settled (`Server/World/RunSettlement`, pure rules in `Server/Domain/Settlement`).** When the party leaves by the arch
  (`Trial/Exit`) or is wiped (`DeathService.onRunOver`), each player's pack is turned into their profile and emptied, the profile is
  saved, and a card shows what they carry home. **Won:** every banked thing goes home: gold becomes `profile.currency`, the rest the new
  `profile.stash` (ProfileSchema **v3**, a table of counts; v1 and v2 profiles migrate to an empty stash); the quest things (keys, the
  scribe's key) are never banked. **The prisoner**, if he is still alive at the end (`RunModService` flag `prisonerAlive`), pays every
  player +5% of their gold (`Loot.Rules.PrisonerGoldBonus`). **Wiped:** the castle keeps three quarters of the gold
  (`Loot.Rules.WipeKeepsGold` = 25% kept); the star shards and the pages come home all the same. The profile's stats count runs won,
  runs wiped and the best run's gold. It happens once per run; the party is sent to the Hub only after the card has finished (the server
  works out the card's length), and a Play Again cancels a way home still pending and re-arms the settlement.
- **The ending card** gets a ledger: "You carry home", a gold line and one line per kind of thing. The Won card says the prisoner's bonus
  in brackets; the Wiped card ("The Run Is Over", "The castle keeps what it keeps") says what was kept of what.
- **The camp (`Server/World/CampService`, `configs/Camp.luau`).** When a gate of chambers 1 to 8 goes up (`AreaService.onCleared`),
  3.6 s later a camp is lit in the passage mouth, against the wall toward the middle of the castle: a ring of stones with a fire (flame,
  light that comes up over a couple of seconds, smoke), a tripod and a steaming pot; a bench with a vice, hammer, saw, thread, cloth, iron
  bars and a lantern on a post; an iron-banded chest; a bedroll, a sack, a crate. **The fire heals** whoever stands within 13 studs, 3 a
  second. **The bench** (E; the panel `CampUi`, four rows with what each costs and what you have, a Make button): Bandage (3 grave cloth),
  Arrows (2 fletching + 1 rusted iron into an arrow bundle), Oil pot (2 tallow + 1 rusted iron), Torch (1 tallow + 1 grave cloth into a lit
  torch for 45 s). The server checks the distance to the bench, the needs and the room; the panel closes on E, Esc, a click outside, the
  walk away, or the ending. **The chest** gives one Sound find per player per camp (`Loot.camp_chest`). **The place is saved:** a fallen
  player wakes at the last camp lit (`DeathService.setRespawnPoint`), not at the castle's gate. A new run (Play Again) strikes the camps.
- Code: `BackpackService.reset`; `DeathService.onRunOver`/`onRunBegin`/`setRespawnPoint`; `AreaService.onCleared`; the net events
  `CampEvent` and `RequestCraft`; client `CampController` + `UI/CampUi`; `Settlement.spec` (6 specs: won banks all but the quest items,
  the prisoner's +5%, the wipe rule, whole gold, apply into the profile, v2 to v3). 145 specs pass.
- Verified in a Studio playtest: the bench makes bandage, torch and oil pot and refuses what it cannot (not enough of a thing, out of
  reach); the panel renders (and scrolls in a short window); a Won settlement banked 200 gold + 10 (the prisoner), the materials, and left
  the key; a Wiped one kept 25 of 100 and the star shard and lost the rest; a second settlement is refused; the fire healed 15 in 5 s; the
  profile survived a restart (DataStore backend). Not seen: the camp's look at full size (the Studio viewport was 394 px tall) and the
  respawn at the camp.

## Version 0.32.0 — Chamber 9, the Keep Steps: the King, the keep, the scribe, the way out (every chamber is now built)

- **The King (`Trial/King`).** One body, one health bar, a nameplate that says "The King" with two lines on its bar where he changes
  face; three faces, and they cannot be skipped (`KingFloor` on the model is a combat modifier that clamps every blow to the line, and
  he takes nothing while he changes face): **The Crowned** (shield on the arm, the sword; at 80% a horn and two spearmen out of the dark),
  **The Archer King** (the shield goes to his back, the bow into his hand; he leaps up to the landing at the head of the Steps and rains
  arrows on the court: a ring of pale frost shows where each one will land a second before it does, every second volley is an aimed
  shot that cover can stop; climb at him and he sidesteps across the landing), **The Hollow** (the seams of the plate open on a cold
  light, the shield is left, a great sword in two hands, faster; rings of frost grow over the court and slow whoever stands in them).
  He does not fall: at the bottom he kneels (the kneeling clip, held), and the prompt is a held **Release him** (5 s, banked, summed
  across players). The light goes out of his eyes, two points of the crown fall, and he pays the_king's table.
- **EnemyAIService can be taken over** for a while: `hold`, `tune` (speed, damage, windup, ranges, bow or sword) and `hooks` (what the
  windup and the strike DO while the brain keeps the telegraph, the facing and the animation); and the client takes an `AttackKind`
  attribute so one body plays three attack clips (bash, draw, sweep).
- **Bodies (`BuildUndead`).** `the_king` (blackened plate edged in gold, a crown on a bare gaunt head, bordeaux cloak with ermine, five
  sets of arms toggled by name: sword, shield on the arm, shield on the back, bow, great sword) and `undead_scribe` (an ink-stained
  robe, a cap, spectacles, a satchel of rolls, a quill).
- **The keep door (`Trial/Unseal`).** The bar is lifted out of its staples, tips and falls to the landing; the two oak-and-iron leaves swing
  in on their hinges one after the other (slow to start, a settle, dust at the foot); a line of pale chevrons comes up along the court
  and the Steps toward the door and pulses toward it. Done when somebody walks in.
- **The scribe (`Trial/Scribe`).** The only living thing in the keep. A conversation of nine lines over his head (the King, the well,
  the bells, the Company's names, the child's drawing, the way out), only while somebody is within 34 studs, never hurried, never twice;
  then the key (`keep_key`, carried). He gives another to whoever asks if the first is lost.
- **The way out (`Trial/Exit`).** The marshal's little door in the west of the hall: a held "Unlock" with the key; the leaf swings in; behind
  it three flights of nineteen steps, the wall-walk round the top of the keep, and an arch with a light in it. A held "Leave" in the
  light; the screen closes when every living player has it and stands there (`EndingEvent` → `EndingController`/`EndingUi`: a title in
  gold, four lines, "To be continued"), and ten seconds later the party is sent back to the Hub.
- **`tools/BuildKeepInterior`** builds all of the keep's inside: six pillars, the long table with chairs and candles, the hearth, banners,
  sconces and braziers, the scribe's desk and shelves, the stair tower and its partition and door, the wall-walk with railings and corbels,
  the arch, and the two leaves of the keep's own door. Checked with the pathfinder: hall to vestibule, vestibule to the head of the
  stair, the whole walk to the arch (each leg a route).
- **Deeds:** three papers (the Chancery's last writ, the Treasurer's reckoning, the words cut in the King's bench) pay a star shard
  and a brass stirrup.

**Checked in a playtest** (real prompts and keys): the fight through all three faces (the damage clamp at each line, the face changes, the
leap to the landing, the marked volleys and the aimed shots, the frost zones and the slow, the kneel), the banked "Release him" hold,
the keep door opening (leaf 104°, bar on the landing, eight chevrons), the scribe's whole dialogue and the key, the Unlock with the key
spent and the leaf opening (-102°), the Leave prompt, the ending card. **Not seen by eye after the first minutes**: Studio stopped
rendering during the playtest (the capture came back flat), so the Archer King's rings, the Hollow's seams and frost, the opening of the
doors, the hall and the stair tower with its lights, and the ending card have not been looked at; neither the sidestep nor the horn's
guard arriving, two players, the end of a real run.

## Version 0.31.0 — Chamber 8, the Inner Ward: the cut, the surges, the Hollow Knight, the mangonel

- **The cut (`Trial/Dig`).** The arch over the passage is down. Hold E at the face of the trench and the party swings a miner's pick
  (the chamber 5 pick; without it, bare hands at under half the speed): the stones in front of you are flung to either side, one by one;
  **let go and they roll back**, as far as the last timber frame set. Five lengths of twelve stones, a frame at the end of each of the first
  four (they drop in with a bounce and a cloud of dust), a roof of fallen masonry over it all. One length is packed hard (rolled; bigger,
  darker stones; half speed). A second pair of hands is worth half a first. A blow taken **staggers** the digger for 0.7 s. The sword is
  sheathed while you dig (WeaponVisualService) and drawn again after. The heap is the progress bar: nothing on screen.
- **Surges (`Trial/Surge`, a pressure kind).** One mass of the dead sent once, after a warning line and a delay, from named markers;
  heavy groups (`flat`) scale with the party only. The cut starts one on every frame set (the noise carries): shamblers and runners,
  spearmen and archers, a Hollow Knight with shamblers, two knights, a gravedigger and runners. `TrialService` passes `note` to pressures.
- **The Hollow Knight (`undead_knight`).** A new body (full plate over mail, a great helm with a crest and a visor slit that is not dark,
  the star on a torn surcoat, a great sword across the body), 300 health, `Armour = 0.4`, a one-second windup into a wide **sweep**
  (`ZombieAnims` "sweep": the body winds right behind the sword, then unwinds across the front). `ArmourService` is one modifier on the
  combat pipeline: damage x (1 - Armour x (1 - pierce)); the forge's **Weight** temper now carries `pierce = 0.6` (RunModService).
  Verified: 100 damage becomes 60 against plate, 84 with the Weight temper.
- **The mangonel (`Trial/Mangonel`, a deed).** The camp's counterweight trebuchet has lost its arm. Lift the arm into the axle, wind the
  windlass (ratchet clicks, the weight rising), bring a stone from the heap (one in the hands at a time), load the sling, pull the pin: the
  arm whips over, the stone leaves the sling at the top of the throw and comes down on the densest cluster of the dead 40 to 150 studs in
  front of the engine (190 damage at the centre, half at the rim, radius 15). The first throw pays a prize.
- **Three papers (`letters`, a deed).** The Marshal's order of the day, the surgeon's tally, the Marshal's unsent letter to the King.
- **`WorkPoseController` (client).** The body of a person at work: the server sets an attribute on the character (`WorkPose`, `WorkAt`,
  `WorkHit`); every client poses the arms, waist, hips and knees on the Motor6Ds after the engine's animation step (the pick goes up over
  the shoulder, comes down, the hips drop with it, a spit of grit at the face on every blow, a nudge to the camera, a flinch when hit), and the
  local player turns to face the work. The forge's hammer and the woodyard's axe will be more entries in the same table.
- **The north spawn of the Ward** moved behind the fallen tower (`Encounters.area_8`): the marker stood at the mouth of the trench.

**Checked in a playtest** (real prompts and keys): the trench dug end to end and the gate raised (4 frames, the packed length, slip-back
to the last frame, the surge notes), the plank-and-brace frames seen from inside, the knight walking, winding up and striking, the armour
numbers, the whole mangonel (arm lifted, wound, a stone taken, loaded, the pin pulled; five dummies in a row killed at the target).
**Not checked:** the pose of the digger from the front (the camera in a trench is cramped), the sweep from the front, two players in the
cut, a surge arriving mid-dig on a real run, the mangonel when two people use it at once, the third and fourth stones, phone performance.
No sounds yet (pick on stone, the windlass's click, the throw): there is no audio in the project to take them from.

## Version 0.30.0 — Chamber 7, the Rows: the prisoner, and three letters

- **The rescue (`Trial/Rescue`).** A villager is bound to the chair in the tavern (a living body, three coils of rope round
  him). Untie him with a held 20 seconds, **banked** across breaks and summed across players (two untie him twice as fast), the
  ropes falling away third by third, the prompt's ring always set to the time that remains. He is then a real unit
  (`prisoner_villager`: Players side, 90 health, does not fight) that follows the party; the task is done when he stands within 28
  studs of the passage out, alive. If he dies a second prisoner is found tied to the chair after 18 s, and a third; when those are
  spent the way opens and the bonus is lost. `RunModService` has **party flags** now: `prisonerAlive` is the +5% gold for the
  whole team at the end of the run (nothing settles the run yet, so the bonus is recorded, not paid).
- **The letters (`Trial/Letters`, a deed).** Three parchments in three houses (the clerk's last entry, a widow's letter to a man in
  the north, a child's drawing of the falling star), each opening as a page; all three read pays a Star Shard and a Mourner's Veil.
  `Read.place` is now the shared piece that lays a readable page on a table.
- **Followers cannot be lost (`EnemyAIService`).** A unit with `Follow` that is more than 80 studs from every player for 9 s, or that
  has wanted to walk and not moved for 6 s with nothing to fight, is put back beside the party. The test that found it: the freed
  prisoner stepped out of the tavern and stood on a stone corner block from which there was no route.
- **Indoors.** `EnemyService.spawn` and `spawnStatic` take an optional `floorY`: a ray dropped from above a room lands on its roof
  (the prisoner appeared eleven studs up in the first test).

**Checked in a playtest** (real prompts and keys): the chair with its ropes and the bound prisoner, the 20 s hold, his freeing,
the walk to the gate (after the fixes: he was put back beside the player when lost, and the trial completed with the flag
set); all three letters read and the prize in the pack. **Not checked:** the ropes falling away mid-hold by eye; the
death-and-second-prisoner branch; two players untying together; the dead going for him in a real fight; the new stuck rule
(only the far-away rule ran). The bound figure stands (there is no sitting clip yet) and shows the zombie idle.

## Version 0.29.0 — Chamber 6, the Great Hall: a pause, the doors, and the siege

- **The pause and the horn (`Trial/Siege`).** Walking into the hall no longer starts a wave. The trial gives 75 s (with a
  warning at thirty and at ten, in the world's terms: torches gathering, then moving), then a horn, then the chamber's
  encounter: three waves of spearmen, archers and the heavy ones (`configs/Encounters` `area_6`, rewritten for it).
  `ownsWaves` in the trial tells `AreaWaveService` not to start the old entry wave for this chamber.
- **Boarding (`Trial/Board`).** The hall's four `BoardPoint` doorways each take up to six planks, one per hold, built up
  from the sill; four seal a door. Planks are the ones carried from the woodyard (chamber 5); two racks of eight stand in
  the hall for a player who skipped it. Boarding is a deed (nothing waits on it); the gate rises when the siege is cleared.
- **A barricade is something the dead attack.** Each is a combat entity on the players' side with 150 health a plank (600
  sealed). The dead's rule is "go for the nearest thing that is not one of us", so they go for it: spearmen thrust, archers
  shoot, the heavy ones lean on it; when its health is gone it breaks (planks fly) and can be rebuilt. New in
  `EnemyAIService`: `approachPoint`: a model with `ApproachA` / `ApproachB` attributes is walked to by a standing place
  on one of its faces, not by its middle (a wall has no route to its middle), so the dead can besiege a door.

**Checked in a playtest** (real prompts, the keyboard tool): the racks and nail prompts, four planks sealing a door (600
health), all four doors sealed; at the horn 33 enemies came and the west door took 300 damage in about six seconds and broke
while the others held; the siege cleared in three waves (33, 31, 49 dead for one player) and the trial completed.
**Not checked:** the dead pouring through a broken door and the fight inside the hall by eye; arrows on boards; a second
player; whether 75 s is enough to fetch planks from the yard and nail four doors (probably not all four: that is the
intended pressure, and the racks make two possible); whether 113 dead for one player is too many.

## Version 0.28.0 — Chamber 5, the Smithy: the forge, the door that is burned, the woodyard, the mine

The third data-driven trial and the one the design calls the spike. Two jobs in any order, two deeds.

- **The forge (`Trial/Forge`).** Pump the bellows (hold E, again and again) to raise the hearth's heat; it bleeds away
  from full to cold in 55 s. Above the round's line (.70, .76, .82) the anvil takes a blow (hold 1 s); each blow costs
  38% heat. Three blows, then a **temper** at one of three stations, one per player: **Edge** +18% damage,
  **Point** +3 studs of reach, **Weight** +40% damage and a 35% slower swing. The coals brighten and the flame and
  light rise and fall with the heat, so the fire is the gauge (no number on screen).
- **`RunModService`** is new: per-player damage / reach / swing-time multipliers for the run, set by `set(player,
  source, mods)`, read by `MeleeCombatService` (the only edit to combat: three numbers around the weapon stats). The
  temper is its first source; relics and oaths will be others.
- **The door (`Trial/Burn`).** A timber door (16 planks, three iron straps, bracing) is built across the passage in
  front of the portcullis. Oil jars from the oil store (far west; two fit in your hands) are poured on it; an unlit torch
  from the rack is lit at the forge and burns 50 s (the carry to the far east is the clock, through the dead); held to the
  soaked door it catches, burns plank by plank and falls, and the gate rises.
- **Deeds.** `Trial/Chop`: the axe in the stump, six dead trees that fall over and give planks (the stack gives four more);
  12 planks pays a Sound-tier prize and the planks are carried to the Great Hall. `Trial/Mine`: eight veins in the
  adit, each rolled for whoever prises it (gold, iron, rarely silver); one hides the **pickaxe**, carried to the Inner Ward.
- New items (all carried, never banked): oil jar, unlit torch, axe, plank, pickaxe. `Torch.give` no longer empties
  your hands (a jar of oil stays when you take fire).

**Checked in a playtest** (real prompts, the keyboard tool): the forge through three rounds, the temper (Point: reach +3
confirmed in `RunModService`), oil jars, the torch from the rack, lighting it, soaking the door, the door catching and
falling, the axe, four trees and the planks deed with its prize, a vein opening and paying gold; the trial then completed.
Bugs found by playing, all fixed: (1) the forge's prompt text was rewritten every frame with the heat, which cancelled the
player's hold (a long hold needs a still prompt); (2) the anvil prompt was withdrawn the moment the heat crossed the line,
cancelling a blow already going down (now a 10% hysteresis); (3) the temper stations stood on top of the torch-lighting
prompt and the nearest prompt won; (4) the door's straps and braces did not fall with its planks.
**Not checked:** the pickaxe turning up (it is one of eight veins); a tree's fall seen by eye; the door burning seen
mid-burn (the capture came after); a second player; how the 55 s decay and the 50 s torch feel with real spearmen and
archers on you. Note: a ProximityPrompt's distance is measured from the player's camera in this engine build as well as
the character; keep MaxActivationDistance generous (>= 10) or a default camera will lose the prompt.

## Version 0.27.0 — Chamber 3, the Kitchens: the recipe, the pot, the five

The second data-driven trial, and the first that uses most of the verbs.

- **Read.** A parchment glows on the kitchen hall's table. Taking it up opens a page (`DocumentUi`, `DocumentController`,
  remote `DocumentEvent`): parchment on a dark veil, ink letters, the writer's name; it closes on Esc, E, a click, or
  the button. The recipe is rolled per run: four of seven ingredients (`Trial/Recipe`), so the same chamber is a
  different errand each time.
- **Gather.** Each ingredient is a small prop (sack, ham, herbs, bucket, crate, cask, crock) placed by looking, near the
  part of the kitchens it belongs to (`Trial/Place`, the winch's floor-and-clearance idea made shared). Carried as quest
  items: no pack place, never banked.
- **Cook.** Put them in the pot in the kitchen hall; it then simmers for 30 s **only while a player is within 22 studs**
  (steam sinks and the clock waits otherwise), and the smell draws the dead (`Trial/Tide`, started by the "simmer"
  signal, stopped when the phase ends). Then it gives five ladles of broth.
- **Feed.** A pen of stakes and rails is built at runtime on open ground (a gap faces the pot); five of the dead stand
  in it as brainless static bodies (`EnemyService.spawnStatic`: no combat entity, so they cannot be killed or chase).
  A ladle to each cures it: the body is swapped for a real `cured_villager` (or `_bow`) and it speaks.
- **The cured** look alive: `EnemyService.livingTint` turns the skin to a living tone and hides the curse's marks (eye
  glow, neck cords, veins, blotches). They are Players-faction, fight the dead, and **follow the party**: a new AI
  option `Follow` (`EnemyAIService`) makes a unit with nothing to fight walk to the nearest player and stop 9
  studs short (checked: two archers ran 150 studs to catch up and stood 9-12 studs away).
- **TrialService** learned: `ctx.shared` (a bag the tasks share), `ctx.hint` (a task's own top line), `ctx.signal`
  (starts pressure on an event), `untilPhase` (pressure that ends with a phase), `devDone` (a test hook).

**Checked in a playtest** (real prompts held with the keyboard tool; a temporary test script, removed): read → page
opens; gather four → phase advances; add to the pot → it simmers, enemies stream in; the pot waits while the player is
dead or away and resumes; five ladles; all five cured; the trial completes and the gate rises; followers catch up. No
console errors. A bug found by playing: one penned slot named `undead_shambler_scullion`, which is a body, not an enemy id,
so it had no body and swallowed a ladle: fixed, and a slot with no body now never spends one.
**Not checked:** the cooked broth's look, the pen in daylight, the cured at close range in the real fog, a second
player, how fast the cured die (the waves and the tide keep coming; they died in about half the runs).

## Version 0.26.0 — Spoils, the backpack, and the first data-driven trial (the Graveyard)

Design first (`docs/systems/Trials.md`, `docs/systems/Spoils.md`), then the first slice of each, checked in
a playtest.

**Spoils.**
- `configs/Items` now holds the catalog of what the dead leave: seven materials, four consumables, six
  relics, the star shard, the torch; each with a rank (Worn / Sound / Hallowed / Relic), a use line, a
  flavour line and a pickup look. `configs/Loot` holds the ranks, the rules and the drop tables (the
  dead by enemy id; containers; deed prizes).
- `Domain/LootTable` is the roll: gold scaled by depth and party, independent material chances, Sound and
  Hallowed rolls with **pity** (30 kills without a Sound-or-better drop forces one; 120 without a
  Hallowed upgrades the next Sound). Simulated 2000 kills: 3.2% Sound, 0.8% Hallowed, longest dry spell 30.
- `Domain/Backpack` + `BackpackService`: a pack of 16 places per player per run, gold as a counter,
  quest items carried in the hands (no place, never banked); `bankable()` says what survives a won or a
  wiped run (banking itself is not wired yet). New remote `BackpackEvent`.
- `LootService`: every kill is rolled for each player within 70 studs and the drops are **personal**: a
  part per drop with an `Owner`, hidden by `LootController` on every other client. They pop, lie, slide
  to the owner at 9 studs and are taken at 3; a full pack leaves them (and says so); they fade after 90 s.
- `BackpackHud`: the pickup log bottom right (rank-coloured, a Sound find also gets its flavour line),
  a gold line, and the pack panel (button, or `B`) where every row says what it is for.

**Trials.**
- `Domain/TrialRun` (pure, spec-tested): phases in order, tasks `all` / `any` / `count`, deeds that never
  gate. `configs/Trials` is the data; `TrialService` runs it (grace, tasks, pressure, the top line, the
  gate) and each verb is a module under `Server/World/Trial/`.
- **Chamber 4, the Graveyard, is the first trial.** Carry fire from the chapel altar to four braziers; a
  torch burns 25 s (its flame is the clock), lights one brazier and is spent, and a lit brazier is itself a
  source. Each section's graves keep giving up the dead (`Rising`: six graves a section, a pulse every 9 s,
  capped, scaled by party and depth, every fourth pulse a Gravedigger) until that section's brazier burns.
  The deed — toll the belfry bell — brings the hardest hour and pays Grave Silver and a Saint's Medal.
- Chambers 1 and 2 are untouched (their own services still call `AreaService.clear`).

**Checked in a playtest** (real server modules; a temporary test script, removed): 139 specs pass; a kill
rolls drops for the player, the magnet and the take work, the log, the gold line and the pack panel draw;
the real prompts gave a torch (hold E at the altar) and lit brazier 2 (hold E), then the other three; the
trial completed and the gate rose; the bell brought its answer and its prize fell. No errors in the
console. **Not checked:** the dead climbing out of graves was seen only in counts, not by eye; the
torch in the hand and the brazier flame were seen once (the flame was too tall: 13 → 9); phone frame rate
with a full chamber; the camera keeps losing the player in the dark chapel shot.

Notes: the pickups are server parts with per-client hiding; at 90 pickups the oldest goes. Roblox's
`Humanoid.Health = 0` does not kill a combat entity: damage it through `CombatService`.

## Version 0.25.0 — The dead are in the game: bodies, motion, and attacks you can read

Until now no zombie body and no zombie animation had ever been in the game (the unit was a red box).
Now:
- **Bodies.** `EnemyService` clones a sculpted body from `ServerStorage.Assets.Undead` when the unit's
  config names one (`Body` in `configs/Enemies`: the shambler picks a guard or a scullion, the others
  one each; the King wears the shieldman as a placeholder). Units with no `Body` (the cured villagers,
  the training dummy) keep the box. The body is tagged `TLK_Undead`, Atomic for streaming, and carries a
  gait `Variant` 1–3 for life.
- **Field kit.** The fine kit (80k–420k triangles a body) is too heavy for a wave, so the game uses the
  same shapes at twice the voxel size (`tools/BuildUndeadKit` `QUALITY = "field"`; 8k–70k triangles a
  body, 82–118 parts). The fine kit is not kept in the place; rebuild it with `QUALITY = "fine"` for
  close-ups (it takes several minutes, in batches).
- **Attacks are windup → strike → recover** (`EnemyAIService`, numbers in each enemy's `AI` block:
  `Windup`, `Strike`, `Recover`). The body stops and faces you, keeps turning for the first 65% of
  the windup, then locks; damage lands at the strike on whoever is still within reach and in front.
  Step out and it hits air. The first time it sees you it stops and cries out (0.9 s) before it chases.
  Shambler 0.8/0.15/0.6, runner 0.45/0.2/0.5, gravedigger 1.1/0.18/1.3 (stuck), pikeman 0.8/0.14/0.7,
  archer 0.9/0.1/0.5, King 0.9/0.2/0.8.
- **State on the model.** The AI writes `State` (Idle, Walk, Run, Aggro, Windup, Strike, Recover,
  Death), `Seq`, `Move`; `EnemyService` writes `HitCount` and `Fall`. Nothing is sent per frame.
- **Motion.** `Shared/Anim/ZombieAnims` authors the clips in code (idle, three walks, run, aggro, flinch,
  three deaths, six attacks built from the unit's own timings) in the same style and angle convention as
  the sword's; `Client/Controllers/ZombieAnimController` plays them on every tagged body, only within 170
  studs of the camera.
- **Death.** A killed body is not deleted: it falls one of three ways, lies 3.2 s and sinks. It leaves the
  combat registry at once, so nothing targets it.

Checked in a playtest (the real server modules, a harness script that was removed afterwards): spawn,
Idle → Aggro (0.9 s) → Walk, Windup → Strike → Recover cycles on every type, the player taking damage and
dying to four shamblers, kills producing the three falls with the body lying on the ground, the sculpted
spade, spear, bow and shield on the right bodies. Not checked: flinch seen with eyes, frame rate on a phone.

Notes: the dead notice you from further than I assumed (the wave starts from the east side of the
chamber, x = 157); `DetectionRadius` is unchanged. In the Studio MCP, `require` from `execute_luau` gives a
SEPARATE copy of every module (its AI never runs); drive the real game from a script placed in the
place, as the temporary harness did.

## Version 0.24.0 — The dead, the company's arsenal, and how they move: design, and a first line-up

**Design, before code** (the developer's order: look and animation first, mechanics after):
- `docs/systems/Bestiary.md` — *the dead keep their stations*: every enemy is a person of the fallen castle
  (cook, sentry, sexton, guard) doing their job wrongly. The curse has three tells (grave-wax skin, the
  Hollow Light in the eyes, frost breath) and the dead move out of rhythm. Asterfall's device is a falling
  star on bordeaux and gold. Roster: the five built types kept, five proposed (Shieldman, Sexton, Cinder,
  Hollow Knight, optional Hound), each asking the player a different question; chamber *dressings* so no
  two are alike; the King in three phases, ending in a release, not a kill (Story §8).
- `docs/systems/Arsenal.md` — movement (sprint, roll, kick, stamina), guard/parry/riposte, poise and
  finishers, damage *styles* (slash/pierce/crush against armour), nine more weapons and shields built
  around the four that exist, ranged, armour, and the run: forge tempers, spoils of the dead, Oaths,
  mastery, deeds, records. The sword stays the developer's two cuts and a guard.
- `docs/systems/Animation.md` — the sword work's rules promoted to house rules, the attribute protocol
  that drives the dead's clips, the clip catalogue, hit-feedback numbers, effects, sound list, budgets and
  the order of work with a "done when" for each step.

**Built:** `tools/BuildUndead.luau` builds seven undead masters (104–156 parts each) into
`ServerStorage.Assets.Undead` and stages a line-up outside the gate for a picture. v2 (the realism pass): round
limbs and ball joints, a real skull (cheeks, sockets, teeth, hanging jaw), fingers, exposed ribs, veins, decay,
torn strips for every hem, cloak and tabard, riveted and weathered metal, poses baked into the joints and the
body grounded on its lowest foot. A playtest proved that the developer's `SwordAnims` clip drives this rig
unchanged. **Nothing in the game uses these bodies yet:** `EnemyService` still spawns the red box, and no
zombie animation exists (the only animation in the game is the sword's).

**The fine kit (v3):** `tools/BuildUndeadKit.luau` sculpts 21 pieces from small cubes (0.02–0.03 studs;
~400k cubes in all) and fuses them by material into UnionOperations that keep every cube's colour: four heads,
three helmets and a coif, sword, spear, longbow, arrow, kite shield, spade, brigandine, hauberk, pauldrons,
vambraces, greaves, quiver. The bodies wear them. Heavy in triangles (80k–420k a body): a lighter field
version is the next step before the dead fight in waves (see `Bestiary.md` §10).

## Version 0.23.0 — Streaming and detail LOD: the nine chambers fit on a phone

The place was ~64k parts, ~495 lights and ~430 emitters with StreamingEnabled off: every client
downloaded and drew the whole castle. Measured in a playtest:
- **Streaming on** (`Workspace.StreamingEnabled`; a script can switch it on but cannot set the
  radii, so the defaults stand: 128 min / 1024 target, which a phone lowers by itself). A client at
  the hill held ~15k parts, at the gate ~34k, against 64k. Every building (each direct child Model of
  `Decorations.AreaN`) is **Atomic**, so a house arrives whole, never a floor without its wall; the
  Shell and the arrival pad are **Persistent**.
- **`tools/OptimiseCastle.luau`** sets all of that and tags lights and emitters `TLK_Lod`. Run it
  again after any build tool (it only sets properties and tags; MODE "undo" reverses it).
- **`Client/Controllers/DetailLodController`** switches tagged lights (120 studs) and emitters (150
  studs; x0.7 on a phone) off beyond that distance from the camera. At the gate the client held 262
  lights, 47 of them lit, and 239 emitters, 53 emitting. Mechanics that light or douse a fire set the
  attribute `LodWant` on it (see the controller's header). The red light in the last tower and the
  smoke seen from the hill are under `Surroundings` and are left alone.
- `IntroService`: when the party is put back at the gate, the body stays anchored until
  `Player:RequestStreamAroundAsync` says the ground there has reached that client (it was 800
  studs away a moment before); all players are placed at once.

Checked after the change: 111/111 stairs and ramps, 29/29 upper floors and decks, 27/27 spawns and
every chamber's way through still route (the server sees the whole world, streaming or not); the
playtest boots clean (14 client, 32 server modules), the intro runs, area 1 starts its first wave;
every script in Studio equals the file on disk (136 of 136).

## Version 0.22.0 — The Rows, the Inner Ward and the Keep Steps: all nine chambers built

**Chambers 7–9 rebuilt** by `tools/BuildWards.luau` (sections Area7–Area9). Every chamber of the
castle is now built by the one tool; see `docs/systems/ChamberThemes.md` for what stands in each.
- **7 The Rows**: two streets of seventeen houses, each written out by hand and none alike — eaves or
  gable to the street, one storey or two, jettied or not, thatch or shingles, washed in seven
  colours — with trade signs on iron brackets, water butts, dead flower boxes and bunting; the
  market square with its roofed cross, stalls and stocks; the market hall (stone arcade, guild room
  above) and the tavern, where the villager is tied to a chair; gardens, a privy, a hen house.
- **8 The Inner Ward**: the last line — palisade, gate, two breaches, a firing step you can climb,
  stakes, braziers; the field hospital, the command tent and its map, stands of spears, a broken
  mangonel, a burning cart; the marshal's house with a fighting deck; a pyre; and the tower that
  came down across the yard, its top the only high ground, reached by two slopes of rubble.
- **9 The Keep Steps**: the keep (68 × 56, parapet 72, turrets 84) with its door shut and barred at
  the head of a great flight of steps; kings in stone, a dry fountain, the guard's last ring, the
  royal carriage on its side; the treasury, the chancery, the guardroom, a knot garden gone brown.
- The places the area mechanics need are named: `PrisonerChair` (7), `PassageRubble` (8),
  `KeepDoor` (sealed) and `ScribeSpot` (9). The keep has no stair inside: nothing reaches the
  wall-walk until the ending opens it.
- Library: houses take a limewash colour (their gables follow it) and can hang their door on the
  right post (a door in an end wall must not lie across the stair foot); trade signs, bunting,
  flower boxes, the market cross, stocks, the prisoner's chair, tankards; palisades, stands of arms,
  a mangonel, cots, rubble slopes, a fallen tower; statues, a fountain, a knot garden, the keep and
  its great stair.

**Fixed while building**: a tavern table behind each door made a funnel the pathfinder would not
pass (the left half of the floor was cut off); a sack at a stair foot; a paving edge 0.12 proud of
the keep stair's head shut the landing off (the same kind of lip as the gallery's). A rolled drum of
the fallen tower may sit a little untrue: the walking surface is an invisible deck over it.

**Verified in Studio**, all nine chambers: 111/111 stairs, ramps and door steps and 29/29 upper
floors and decks route from the yard; 27/27 spawns reach their objective; every chamber's entry →
passage is open, and in chamber 9 the way up to the keep's landing. A playtest boots clean (32
server / 13 client modules). Place ~64k parts, ~490 lights.

## Version 0.21.0 — The Graveyard, the Smithy and the Great Hall; the dead get upstairs

**Chambers 4–6 rebuilt** by `tools/BuildWards.luau` (sections Area4–Area6), the same way as 1–3 —
see `docs/systems/ChamberThemes.md` for what stands in each:
- **4 Graveyard**: a stone chapel used as a mortuary, its churchyard (broken wall, lychgate, old
  graves, table tombs, a broken cross, a family vault), the new field of graves dug too close, some
  open, a pit dug into the terrain with the shrouded dead in it, a burning pyre, the sexton's house
  and his coffins, a charnel house, a timber belfry you can climb.
- **5 Smithy**: a stone forge open in six bays with two hearths and two stacks, the armoury with a
  loft, the smith's house, a mine cut into a rock hill in the terrain (adit on timber sets, rails,
  tubs, gold in the walls), the oil store, a rack of unlit torches, dead trees with an axe in a
  stump, a saw pit and sawn planks, a bloomery and a smoking charcoal clamp.
- **6 Great Hall**: a 120 × 46 stone hall with an open timber roof (arch-braced trusses, slates, a
  louvre over the hearth). The road runs through its screens passage, under a minstrels' gallery
  you can climb; dais, high table, cloth of estate, chandeliers, banners, tables thrown over and one
  still laid. Solar wing, buttery, the court of the last feast under pavilions, the lord's garden.
- **The places the area mechanics need are built and named** (not the mechanics): four unlit
  grave braziers, the forge with its bellows and anvil, the torches, the oil, the choppable trees,
  the planks, and a `BoardPoint` in each of the hall's four doorways (AreaPlan.md lists them).
- New in the building library: stone walls with double doors, pointed (lancet) heads, open bays,
  archways and any thickness; stone gables; several chimneys to a roof; buttresses, quoins,
  flagstones; graves in five states, headstones, coffins, shrouds, tombs, crosses, churchyard walls,
  a lychgate, a bell, dead trees; forge hearths, a grindstone, a weapon bench, mail on stands, sword
  and torch racks, oil jars, stumps, mine tubs, rails, timber sets, a bloomery, a charcoal clamp;
  trestle tables, benches, banners, chandeliers, sconces; terrain dug (a pit) and heaped (a hill).

**The dead can now reach every upper floor, not just the top of the stairs.** A new check stands
on each upper floor (`UpperProbe` / `DeckProbe`) instead of on the stair head, and it found that in
every cottage the flight ran into the end wall: whoever climbed it stood on the top step with
nowhere to go. Fixed in all six areas:
- house stairs are steeper (43°; the pathfinder climbs 45°, not 48°) and every one now arrives on a
  landing at least 2.6 wide; the narrow two-storey houses are 2 wider (18→20, stone 22→24), and
  the builder warns if a house is too short for its stair;
- door leaves swing right back against the wall (155–165°): a leaf standing square into a room cut
  a cottage in half; stone doors hang on the inside face;
- a 0.22 lip at the gallery's stair head, an anvil 1.6 inside a forge bay (the area-2 forge bay that
  never routed), a barrel rolled in front of a bay and a shelf in a doorway were all removed.
- Verified in Studio: 62/62 stairs, ramps and door steps and 15/15 upper floors and decks in
  chambers 1–6 route from the yard; 18/18 spawns reach their objective; entry → passage open in all
  six chambers. A playtest boots clean (32 server / 13 client modules). Place ~52k parts, 390 lights.

## Version 0.20.0 — A bigger castle, and the first three chambers built to be believed

**The castle is 25% bigger both ways** (300 × 1800 → 376 × 2250; chambers 200 → 250 deep).
- `configs/Castle.luau` (new) holds the numbers. `tools/BuildBattleground` (new MODE "resize"),
  `tools/BuildLand`, `tools/BuildSurroundings`, `AreaService` and `WinchService` all read them; no
  copy of the castle's size is kept anywhere else.
- Resize keeps everything: walls whose length changed are rebuilt (in runs of ≤1000 — a part longer
  than 2048 is silently clamped, which left holes the first time), every tower, passage, marker,
  building and light is moved whole. The moat, reeds, mist and the smoke moved out with it; the old
  moat inside the new walls is filled (`BuildLand` MODE "castle").
- The old chamber tools (`BuildChambers`, `LightCastle`, `CleanSlate`) refuse to run on the resized
  castle instead of building in the wrong place.

**Chambers 1–3 rebuilt** by `tools/BuildWards.luau` (new) — see `docs/systems/ChamberThemes.md`:
- A building library made the way buildings were made: stone plinths with quoins, timber frames
  (sill, posts, rail, braces, close studding upstairs), daub panels set back from the frame, jettied
  upper floors on joists and a bressumer, thatch 2.6 thick with a rolled eave, a sedge ridge and
  hazel liggers, plank doors on strap hinges, mullioned windows with shutters, rubble-stone walls
  with dressed jambs and oak lintels, chimneys, fighting decks, lean-tos, open sheds, ruins.
- Generated PBR materials (`TLK_Thatch2/3`, `TLK_Daub`, `TLK_OakBeam`, `TLK_OldPlanks`, `TLK_Rubble`,
  `TLK_Charred`, `TLK_Shingles`, `TLK_Hay`, `TLK_Burlap`, `TLK_YardMud`, `TLK_Cobbles`) and textured
  mesh props (barrel, cart, anvil, sacks, firewood, trough, crate, table, bed, cauldron, shelf, bread
  basket) in `ServerStorage.Assets.Props`. Mud and cobblestone terrain use the generated textures.
- New roads painted into the terrain, cobbles with mud verges, grass along the walls; torches on the
  walls again; braziers, hearths, glowing windows, smoke from chimneys and burnt buildings.
- Area 1 ~4.5k parts, areas 2 and 3 ~2.7k each. Place total ~39k parts.

**The dead can follow you up.** Every raised floor is reached by a flight whose walking surface is an
invisible ramp, every doorway has steps with a ramp under them, and:
- `EnemyAIService` now follows the floor (each step finds the surface under it: up 2.2, down 40), takes
  a route instead of a straight line when the target is on another level, gathers underneath when
  there is no route, routes with a 1.0 radius (at 2.4 or 1.6 the pathfinder judged every door and
  stair impassable), and turns at waypoints within 2 (at 4 bodies met stairs from the side).
- Verified: all 32 doors, stairs and decks in chambers 1–3 route from the yard; a playtest had four
  of the dead climb the watch platform and reach the player on it. Every route from the entry to the
  passage, and from every spawn to every objective, is open.

## Version 0.19.1 — Both places caught up, and published for testers

Both places were brought level with the repo and **published** (2026-10-18) so testers can play.

- **Kingdom Hub**: 20 shared scripts were behind the repo — 12 stale (Net, Scaling, Encounters, Enemies,
  Difficulty, Missions, Look, EnemyBrain, CombatController, MissionController, Mission.Types, the
  EnemyBrain spec) and 8 missing (Intro, IntroController, IntroUI, AreaController, AreaHud, ObjectiveHud,
  WeaponAnimController, Shared.Anim.SwordAnims). Now 120 of 120 match disk.
- **Hub bug fixed**: `StarterPlayerScripts.Client` held a second, older `Core`, `Controllers` and `UI`
  folder (left by an old sync), so two `Bootstrap`s ran and every client controller booted twice.
  The stale copies are gone; one Bootstrap runs.
- **Forgotten Lands**: `Interactions` and `DialogueUI` were older than disk (no voiced lines) and
  `Look` was missing. Now 134 of 134 match disk.
- The Studio edit camera was left `Scriptable` by the screenshot work in both places (only selecting
  worked); it is back to `Fixed`.
- Verified: `rojo build` clean for both projects; a playtest of each place boots with no script errors
  (Hub: 18 server / 13 client modules; Forgotten Lands: intro → area 1 → wave 1).

## Version 0.19.0 — A castle with people's things in it, and fire

The nine chambers were bare yards with no light in them at all — not one Light instance inside the
walls.

**The chambers are furnished again** (`tools/BuildChambers.luau`, `Battleground.Decorations`, ~4.2k parts):
the guardhouse and barracks of the Outer Ward, the stables and farrier's, the bakehouse and ovens, the
chapel and its graves, two forges and the smith's house, the Great Hall, seven houses in the Rows, the
fallen tower in the Inner Ward. The tool was reused, with four changes:
- the stone road is NOT drawn (`DRAW_PATH = false`; two parts roads were taken back in Aug 2026). The
  route is still computed, and every building keeps off it;
- the markers are READ from each chamber (spawns, objectives, Checkpoint, Storyteller) instead of the old
  assumed positions, plus the arrival pad, the winch, and the throne room;
- every footprint is tested against the towers and walls, so nothing is built through a tower;
- big buildings are placed as rectangles (`placeRect`) on a grid search: as circles the Great Hall, the
  fallen tower and three of the Rows never fitted beside the road. The hall is 64 x 44 now (was 64 x 90),
  the fallen tower 70 long, and the house plaster darker (it read as fresh whitewash).

**Light** (`tools/LightCastle.luau`, `Battleground.Lighting`, ~2k parts, 150+ lights, none with shadows):
- torches on the walls (cast at the stone, so each bracket sits on it), a torch either side of every
  passage so the way on is the brightest thing in a room, four braziers per chamber off the centre;
- ~22% of the towers' window openings glow ember (`MODE = "undo"` puts them back);
- a fire inside half the houses, a fire pit and two chandeliers in the Great Hall, candles on the altar;
- torn banners on the walls, ash falling through every room, and battle clutter — bones, blades,
  arrows, shields, helms, scorch marks — more of it the deeper you go;
- chamber 9 is the throne room: a dais against the back wall, an empty throne, a red carpet, two kings
  in stone, fires burning red and the back wall washed red.

Checked: nothing solid stands on any enemy spawn; a Studio playtest runs intro → skip → area 1 →
barricade → wave 1 (15 enemies) with no new errors. The place is now ~29k parts, 164 lights.

**Tooling**: tools are no longer pasted into Studio. A tiny local server (node, 127.0.0.1 only) serves
the repo's text files and the command bar loads them with `HttpService:GetAsync` + `loadstring`, with
`HttpEnabled` switched on only for that one call and straight back off.

## Version 0.18.0 — The Forgotten Lands get a horizon, and an arrival

The castle stood on a flat plate of earth that ended 900 studs out, under a red sky, ringed by a thin
turquoise ditch. It now sits in a land.

**Look** — new preset `ForgottenDusk` (`configs/Look.luau`): Look A an hour later. Cold blue-grey haze,
a heavy cloud deck, a moon, and only a bruise of red where the sky meets the hills. Water is black and
still. `ForgottenBaseline` is the exact old look, kept as the undo. `tools/ApplyLook.luau` now also sets
the terrain's water (`Water` section).

**Land** (`tools/BuildLand.luau`, terrain only, nothing inside the moat touched):
- The moat is rebuilt as one ring, 80 wide (was 44): mud bank, a shallow shelf, deep black water at y −6.
- Ground out to 4.8k × 6.3k studs. Flat by the moat, rolling hills from 100 out, mountains 1.3k–1.9k out
  all the way round, so the world ends in rock and haze. Rock and slate on the heights, dead grass, earth
  and mud patches below.
- A hill 800 studs in front of the gate, with a clear sight line to it, and a paved road down to the bridge.

**Surroundings** (`tools/BuildSurroundings.luau`, `Workspace.Gameplay.Surroundings`, ~5,000 parts, none
collide — it is all behind the castle wall):
- Moat: stone revetment with coping, buttresses and a green waterline; reeds; sharpened stakes on the far
  bank; a sunk cart, a half-sunk boat, a fallen tree, floating planks and barrels; mist lying on the water.
- Bridge: stone, two arches on cutwater piers, then the drawbridge left down, planks missing, chains
  running up into the gatehouse. Two braziers at its foot and two torches at the gate: the first warm
  light in the world.
- Outside: a burnt village (seven cottages, a well, two still smouldering), an old battlefield (rows of
  graves, weapons left standing in the earth, a trebuchet that never fired, torn banners), a gallows,
  ~240 dead trees in patches, rails ending at a broken buffer stop, and a wayside shrine whose candles
  are still lit.
- Smoke rising inside the walls, and one red light in the highest tower of the last chamber.

**The arrival scene** — new: `configs/Intro.luau`, `Server/World/IntroService`,
`Client/Controllers/IntroController`, `Client/UI/IntroUI`; remotes `IntroEvent`, `RequestIntroSkip`.
- On arrival the party stands on the hill and sees the castle: title card, letterbox, six shots from
  camera marks (`Surroundings.Intro.Cam1..6`, movable in Studio), and six lines. Each line is said by a
  player in the party, shown by their display name on a gold plate above the text; the order is shuffled
  per run, and alone the one player says them all.
- Skip is a vote (more than half; alone, one press). Sized for a thumb (48 px), text scales with the
  screen.
- Then black, everyone is on the arrival pad, and the run starts. Bodies are taken up the hill the moment
  they appear, so chamber 1's barricade and waves only arm once the scene is over. `ChapterService` now
  waits on `IntroService.whenFinished`.
- Verified in a Studio playtest (solo): scene starts, lines show under the player's display name, the
  camera changes shots, the scene ends on time, then area 1 → waves → chapter start, in that order.
- First look with screenshots (`assets/Images/Reference/forgotten-lands-exterior_2026-10-18.jpg`), and
  what it changed: the haze hid the castle from the hill entirely (density 0.44 → 0.3, haze 2.4 → 1.5);
  the cloud deck sat on the mountains like a lid (cover 0.74 → 0.6); the ground and moat went pure black
  (outdoor ambient and exposure lifted); the water now reflects the sky. The talking shots were turned
  round — from the front the castle is behind the camera — to over-the-shoulder shots, with a cold moon
  fill on the party. The braziers were too small to read: bigger, brighter, shadowless.

## Version 0.17.2 — The veteran speaks in short breaths

- The Storyteller's speech is now ten single sentences (`configs/Interactions.luau`), each replacing
  the last on screen, instead of four long paragraphs. Holds are shorter to match.
- `DialogueUI` reads any line that has no `Sound` aloud with Roblox's built-in text-to-speech
  (`Dialogue.Voice`: VoiceId, Pitch, Speed; `Enabled = false` turns it off). The text paces itself to the
  voice. A line with its own recording still wins. Verified in Studio that the voice loads
  (2.4 s for the first sentence); how it *sounds* is not verified.
- The built-in voices are a stand-in. The intended voice — an old British veteran — is now recorded:
  ten clips (`assets/Audio/Storyteller/veteran_01..10.mp3`, ElevenLabs voice "Veterans Voice, Rblx",
  model eleven_v4, one file per sentence, in the order of `Lines`). Uploaded through the Asset Manager
  (creator = the experience's group) and wired into each line's `Sound` in `configs/Interactions.luau`.
  All ten load in Studio with the expected lengths. How they sound in the scene is not verified yet.

## Version 0.17.1 — The camp is closed

Nothing stopped a player leaving the Hub. The chain-link fence is 9.6 studs tall (a jump and a
stack of crates clears it), and on the north side there was no fence at all, only the railway
and a plain a thousand studs wide. Nothing here touches gameplay code, and the fence itself is
untouched.

- **`tools/BuildBoundary.luau`**: an invisible wall, 50 studs high and 4 thick, in
  `Lobby.Invisible.Boundary`, on one closed outline read from what is already there: the fence's
  three sides on the fence's own lines; the gaps beside the train on the north, closed at the
  fence's ends; and a pocket round the train and the four wagons, 6 studs (about 1.7 m) outside
  them, so the rake stays in the playable area and a player can still walk round its ends. The
  walls stand outside the outline, so nothing sticks into the camp. 35 pieces, about 1,000 studs
  of wall. `preview`, `build`, `verify` and `remove`; move the fence or the train, run `build`
  again, and the outline follows.
- **The wall does not touch the camera.** It is `Transparency 1` and `CanQuery false`: Roblox's
  default camera only pulls in for opaque, collidable parts it can raycast to, so the player can
  zoom out past the wall. Only the character is stopped. The chain-link's own parts are opaque and
  collidable, so on the three fence sides the *fence* still pushes the camera in, as it always did
  (left as it is, on purpose).
- **Checked three ways.** `verify` samples 12,880 points along the outline: no gap, nothing
  protruding into the camp, every piece invisible, collidable, not queryable and anchored. In a
  real playtest a character was ordered to walk out through every side, the corners and both ends
  of the train pocket, and to keep jumping the whole way: all 13 stopped inside, and the two bare
  north shoulders (no fence there) show the barrier stops a body on its own.
- **A palisade was tried and rejected.** A wall of sharpened logs (1,781 parts) replaced the
  chain-link briefly. It was too tall and not wanted, so the chain-link was put back exactly (82
  segments, same positions, checked) and the tool was deleted.
- **Not verified:** the camera in a running client. The Studio window was not rendering during
  the playtest, so the camera never moved; only Roblox's rule for it was checked.

## Version 0.17.0 — The Hub gets a look

The game was playable and looked like a prototype: a pale sand "road" across a flat plain,
under a flat blue sky, in lamplight that did not exist in play. Nothing here touches gameplay.

- **`configs/Look.luau` + `tools/ApplyLook.luau`**: how a place looks — lighting, atmosphere,
  sky, clouds, post-processing, the colour of each terrain material — is now **data** with
  named presets, baked into a place at edit time. Zero cost while the game runs. `Baseline` is
  the Hub as it was; `DarkRealistic` is the locked base look; `StylizedDarkFantasy` is kept as
  a reference. `Lighting.Technology` cannot be touched by a script and is left alone.
- **Look A locked** after an A/B test on four fixed cameras. Overcast, cold, desaturated; warm
  light only from fire. The doubled Bloom is gone. The rules, palette and ground vocabulary are
  the Style Bible in `docs/systems/Presentation.md`.
- **`tools/PaintGround.luau`**: the terrain was a flat slab of `Ground` with the roads as one
  layer of `Sand`, whose rippled texture read as desert whatever colour it was given. Colour
  cannot fix a texture, so it changes the *material* of the top layer: paving on the roads
  (285 of their 308 voxels), mud at lane edges and shores, weeds along the fence, patches of
  grass and stone beyond it. Heights and the authored road shape are never touched. It has
  `preview`, `apply` and an **exact `restore`** (the road positions are recorded on the
  terrain).
- **`tools/PreviewRuntimeLights.luau`**: the lamps are hand-placed at stock strength
  (lantern posts 2.4, range 24) and `LightService` retunes them only when the game runs
  (0.8, range 40), so the Studio view overstates every lamp two to three times. The tool
  stamps the runtime values on for judging and restores the originals exactly on `off`.
- **Not done, on purpose:** the placeholders (train wagons, chain-link fence, flat horizon),
  set dressing, VFX, and the Forgotten Lands look. They are in `docs/Todo.md`.

## Version 0.16.0 — A sword you can see

- **`Server/World/WeaponVisualService`**: the player was punching. Combat has been
  numerically correct since the vertical slice and has never had a weapon on screen —
  you could not read your reach, tell whether a swing came out, or tell you were armed.
  The equipped weapon is now built from parts (hilt, binding, pommel, crossguard, fuller,
  twin edges, point) and welded to the right hand, with a `Trail` on the blade that is
  off except during the strike.
- **The swing is procedural.** Roblox animations need an uploaded asset id and this
  project has none, so the right shoulder's `Motor6D.C0` is driven through wind-up →
  strike → recover in ~0.47s. C0 rather than the Animator's `Transform` channel for two
  reasons: server C0 changes replicate and `Transform` does not, and because the joint
  is `Part0 * C0 * Transform * C1⁻¹` the offset composes **on top of** the idle/walk
  animation instead of fighting it. `GRIP` is the single constant to adjust if the
  sword sits wrong in the fist.
- **The winch is a HOLD, not a tap.** No more banked notches: hold E and the gate climbs
  at 1/14 per second, let go and it falls at **×1.5** from that same frame, with no
  grace. Fourteen unbroken seconds gets you through, so the room has to be cleared
  enough to give you fourteen — and every second spent swinging costs a second and a
  half of height. Each extra pair of hands adds half a pair's worth.
- **Highlights no longer draw through walls** (`DepthMode.Occluded`). Nine boxes lit up
  through the stables from the doorway is not searching, it is reading a map.
- **Enemies notice you from across the room.** Detection radii were 40–60 in chambers
  300×200 studs with spawn markers up to 150 away, so the dead stood where they spawned
  and were never seen. Shambler 45→110, runner 60→130, heavy 40→100, spearman 55→120,
  archer 85→145, King 120→200, with leashes at roughly twice that so they follow you
  through the arch instead of turning round in the doorway.

## Version 0.15.0 — The dead, in every room

Areas 1 and 2 both played correctly and both played wrong: you cut three ropes, found
a handle, wound a winch, and nothing ever came. Every line written into those mechanics
— progress is kept when you break off, the winch slips while you fight — assumes there
is something to break off *for*.

- **`Server/World/AreaWaveService`**: walk into a chamber, that chamber's encounter
  starts (after a 3s breath). The waves are **pressure, not the lock** — clearing them
  opens nothing, the room's own puzzle does, and you may leave the moment it is done.
  Entering chamber N stops chamber N−2's encounter and despawns its stragglers, so the
  thing chasing you through a doorway keeps chasing you and the thing three rooms back
  does not.
- **`configs/Encounters`** +`area_1` … `area_8`: 3–5 waves each, obeying
  `Difficulty.Areas[n].Unlocks` as the single source of truth for which enemies exist
  yet — shamblers alone in the Outer Ward, runners from the Stables, the heavy at the
  Graveyard turn, spearmen and archers at the Smithy spike. Counts are the BASE for one
  player; the curves do the ramp.
- **The depth curve is finally read.** `Scaling.forArea(index)` + `Scaling.combine`, and
  `WaveService.Context.areaIndex`. `Difficulty.Areas` has been sitting in the config
  written and unused since 0.8.0 — party size and depth now multiply, which is the whole
  reason they are two tables.
- Chamber 9 is deliberately absent: the King is not a wave table.

**Known**: `Difficulty.Areas[n].EnemyDamageMult` is still applied nowhere — count and
health scale with depth, damage does not. It needs `EnemyService.spawn` to carry a
damage multiplier the way it already carries a health one. **Also**: the Chapter 1
mission's `chapter_one_ambush` still fires in chamber 2 on top of `area_2`, so that room
currently gets both.

## Version 0.14.0 — Area 2's winch

- **`Server/World/WinchService`**: the portcullis out of the Stables is down and the
  winch has lost its handle. Nine search points — crates, barrels, bales, sacks,
  chests — are scattered around the stables **at runtime**: the service raycasts for a
  floor, rejects anything above ward level (a ray dropped over the stables lands on the
  roof), rejects anything overlapping existing geometry, and keeps 20 studs off the
  measured road. One holds the handle and which one changes every run.
- **The gate is the progress bar.** `AreaService.setOpenFraction(index, f)` (new) lets a
  mechanic drive the grille directly. Turning the winch raises the real portcullis a
  fraction at a time and letting go lowers it — no bar on screen, and the slip-back
  hurts in a way a number could not. GAIN 0.075 per hold, SLIP 0.022/sec, 0.7s grace.
- **Solo-first**: alone and unbothered it is ~20 seconds of work; a ten-second fight
  costs about three holds. A `ProximityPrompt` is held per player, so two people on the
  same winch produce two turns where one produced one — faster, never the difference
  between possible and not.
- **Plain words** everywhere on screen: "Look around", "Keep going", "Kill them all",
  "Cut the ropes — 2 left", "Find the winch handle", "Turn the winch". The prompt on the
  barricade says Rope, not Lashing.
- **`tools/SurveyArea2`** replaces `tools/BuildStables` (deleted). It measures rather
  than computes: the real road in ten z-slices, the real bounds of the user's own
  `Horse Stable`, and everything else standing in the chamber. The stable range I built
  from `BuildChambers`' constants landed on the road; every position in `WinchService`
  came from this survey instead.

## Version 0.13.0 — The HUD gets quiet, the world gets loud

Playtest feedback, applied. The screen was shouting and the props were greyboxes.

- **Bug**: `ArrivalService` asked `GameService.getPlaceRole()` in **Init**, and the Loader
  runs Init alphabetically — so it asked before GameService had answered, got `Unknown`,
  and did nothing. No log line, and the player kept spawning inside the gatehouse. The
  check is gone: `Server/World` only syncs into the Forgotten Lands, so the file existing
  IS the place check.
- **No more waypoint beams.** `Server/World/Beacon` is deleted. A pillar of light over
  the objective turns a castle into a checklist, and the gold read as neon. The area name
  says where you are, one line at the top says what to do, and the world has to carry the
  rest.
- **`AreaHud` v2** — bottom left, bare screen: white name, 2px black outline, nothing
  else. No panel, no status, no "locked". Two labels swap so a room's name can leave while
  the next arrives, with a hairline rule sweeping under it.
- **`Client/UI/ObjectiveHud`** (new) — one small white line at the top, typed a character
  at a time, no panel behind it. Sources push and clear by name and the newest live one
  shows, so an area mechanic can take the line and the mission's line comes back when it
  finishes. `Net` +`ObjectiveHint`; objective defs gain a short `hint`.
- **`AreaService.onEnter(index, fn)`** — the invisible barrier. An area's content starts
  when a player first walks into it, once per run. No trigger part: the position poll
  already knows, and it catches players who spawn past a line, are put down by a
  checkpoint, or clip a corner at speed.
- **The barricade is built like a barricade.** Rope is now turns of cord passing right
  around the beam — eight tangent segments per turn, jittered, nine turns per lashing,
  falling three at a time as it is cut — with frayed tails and an eight-segment iron ring.
  Boards get a facing plank, six nails each and a split end. The lashing's height is
  DERIVED from its board instead of hand-written; the first version had one wrapping thin
  air a stud above the plank it was holding. The highlight is a pale warm edge, not gold.

## Version 0.12.0 — Area 1's mechanic, and somewhere to land

- **`Server/World/ArrivalService`**: the place had **no SpawnLocation at all** — deleted
  by hand at some point, most likely, since it is invisible and non-colliding. Roblox's
  fallback is to drop the character near the world origin, and this map's origin is the
  middle of the gatehouse arch, so the player spawned standing on the gate every time
  with nothing in the log to say why. The spawn is now created at boot from the pad's own
  geometry, so it cannot be deleted again, and the service sweeps the landing box and
  names anything solid standing in it.
  (The previous guess — the fallen gatehouse doors — was wrong; `FixArrival` reported
  `z 8 -> 8`, i.e. it moved nothing. The doors are better placed now regardless.)
- **`Server/World/BarricadeService`** — Area 1 per `systems/AreaPlan.md`: heavy timber
  lashed across the portcullis, **three bindings, three cuts each**, `ProximityPrompt`
  hold-to-cut. Each completed cut is banked and a turn of rope falls away, so breaking
  off to fight costs at most the 1.6s in progress — never the binding. Solo-first: three
  bindings, one pair of hands; more players is faster, never *possible*. Cut all three
  and the timber comes down and `AreaService.clear(1)` raises the gate.
  Each binding wears a `Highlight` (AlwaysOnTop) so it is findable through the timber,
  and the barricade carries a beacon counting down the bindings left.
- **`AreaService`** exposes `passageOf(index)` / `gateModel(index)` so a mechanic can
  build onto the gate instead of keeping its own copy of the castle's dimensions.

## Version 0.11.1 — Wayfinding, and two things the first playtest found

The castle's first real playtest failed on one thing, and it was not combat: the
player did not know where to walk.

- **Bug (silent, and the cause of most of it)**: `MissionRuntimeService` assigned
  `objective.def.position` — which configs write as a marker NAME — straight to
  `Part.Position`, throwing `Vector3 expected, got string` on every objective and
  leaving Chapter 1 with no waypoint at all. It now goes through `Markers.resolve`,
  the same call `ObjectiveTrackers` already used.
- **`Server/World/Beacon`**: a reusable "go here" — a 70-stud neon shaft, two ground
  rings pulsing outward, rising motes, a point light, and a nameplate that draws
  THROUGH walls (`AlwaysOnTop`), so it survives a building being in the way. All
  parts are `CanQuery = false`: a waypoint must never eat an arrow or a sword swing.
  Objectives label it by kind (`GO HERE` / `SEARCH` / `HOLD HERE` / …).
- **`AreaService`** lights a `THE WAY ON` beacon in front of a passage the moment its
  chamber is cleared, and puts it out on `lock`. Deliberately dark while locked — the
  objective owns the player's eye until it is done.
- **Bug (arrival)**: the two gatehouse doors were placed 30 and 46 studs *past* the
  gate, flat across the arrival pad, so the player spawned standing on one. Moved
  into the archway where "off their hinges in the passage" actually means it.
  `tools/BuildBattleground` carries the new numbers; **`tools/FixArrival`** applies
  the same move to an existing place without a rebuild, then sweeps the spawn box
  and names anything else standing in it.

## Version 0.11.0 — Area gates & the corner HUD

The nine decorated chambers become a **run**: the way forward is shut until the room
is done, and the player can always see which room that is.

- **World**: `Server/World/AreaService` builds a real portcullis into each of the first
  eight passages — bars, spikes, ties, guide runners, a threshold sill, and chains that
  shorten into the masonry as the gate rises. The lift is a ~3s smoothstep with a
  decaying judder, not a tween of a part sideways. The visible grille is non-colliding;
  an invisible slab inside it does the stopping, because 2.5-stud bar gaps do not stop a
  Roblox character.
- **API**: `clear(index)` / `lock(index)` / `isCleared` / `areaOf(player)` / `resetAll()`.
  The service owns the gate and the HUD and deliberately **not** the win condition —
  each area's mechanic calls `clear` when its own puzzle is done.
- **Client**: `Client/UI/AreaHud` (bottom-left panel: chamber number, English name, one
  status line; gold rule open, bordeaux shut, a single gold flourish when the gate goes
  up) driven by `Client/Controllers/AreaController`, which stands down outside the
  Forgotten Lands.
- **Contract**: `Net` +`AreaEvent`.
- **Geometry**: `AreaService` duplicates `tools/BuildBattleground`'s numbers (gap width,
  springing height, span underside, passage inset, the east/west serpentine). Changing
  one now requires changing the other.

Nothing calls `clear()` yet — the per-area mechanics land next. `DEV_OPEN_ALL` in
`AreaService`, or `require(...AreaService).clear(n)` from a **server** command bar,
walks the castle in the meantime.

## Version 0.10.0 — Death System

Death = WHAT HAPPENS WHEN YOU FALL. A foundational death/revive loop wired into the mission
run. Placeholder feedback (prints), no UI/camera polish:

- **Contract**: `Shared/Death/Enums` (Choice: Lobby/Revive/Wait; Status); `Net` +`DeathEvent`
  / `RequestDeathChoice`.
- **Domain (pure, tested)**: `DeathGroup` — wipe / reviver-available / waiting-group rules
  (`DeathGroup.spec`).
- **World**: `DeathService` owns respawn (`CharacterAutoLoads` off in the World) + death status;
  detects death via `CombatService.EntityDied` (once per life); drives PARTY-AWARE choices
  (solo: Lobby + Revive; party: also Wait), the spectate window, free teammate proximity revive,
  self-revive (gold, anti-P2W: cost / cooldown / reduced HP), and run-over.
- **Integration**: `MissionRuntimeService` registers the run's players (`DeathService.beginRun`,
  guarded against re-entrant/stale fails via a run id) and fails the mission on a run-over. There
  is NO auto-restart — players respawn idle and a manual Play Again (`RequestPlayAgain`) restarts
  the chapter. Self-revive spends gold from the persistent profile.
- **Client**: minimal `DeathController` (prints choices, keys 1/2/3).
- **Content/config**: `Economy.Revive` + `Settings.Death`; dev starter gold
  (`Settings.Dev.StarterGold`) so solo self-revive is testable.

Resolves slice tech debt: player death now has real consequences and choices. Robux revive,
diegetic UI, and real Hub teleport are follow-ups.

## Version 0.9.0 — Progression & Rewards + Persistence

Progression = WHAT THE PLAYER EARNS. A real reward pipeline over durable saves; missions and
encounters now grant currency and XP. Placeholder values, no UI:

- **Domain (pure, tested)**: `Progression` (XP -> levels from the Experience curve, +
  `Progression.spec`); `ProfileSchema` v2 adds `xp`/`level` with a v1->v2 migration
  (`ProfileSchema.spec` extended); `DataStoreStore` — a real DataStoreService-backed `Store`
  (pcall + retry).
- **Service**: `RewardService` grants currency + XP (via Progression) into the persistent
  profile — server-authoritative, with level-ups.
- **Persistence**: `SaveService` injects `DataStoreStore` when enabled + available
  (`FeatureFlags.UseDataStore`), else keeps the in-memory mock (Studio without API access) —
  same `Store` interface, no other change. Load/save/autosave/close lifecycle already existed.
- **Content**: `configs/Experience` (XP curve, MaxLevel 10), `configs/Economy` (`gold`);
  Chapter 1's mission and its `Clear` objective carry real `reward` values.
- **Integration**: `MissionRuntimeService` applies a mission's `reward` on completion AND any
  objective's `reward` on objective complete (so encounters reward too); results stream to the
  `MissionEvent` feed and print via `MissionController`.

Resolves slice tech debt: rewards are real (currency + XP into the profile) and persistence is
a real DataStore backend, not a mock. Cross-place session locking remains tracked tech debt.

## Version 0.8.0 — Encounter / Wave System

A reusable, data-driven encounter framework: the Mission System decides WHEN an encounter
starts, the Wave System decides HOW it runs. Placeholder content, no UI/VFX:

- **Data**: `configs/Encounters.luau` (spawn points + waves + groups) and `Shared/Wave`
  (Enums, Types); `configs/Difficulty` (player-count scaling) and `configs/Waves` (global
  defaults) filled; `configs/Enemies` +elite (`undead_brute`) +boss (`fallen_champion`).
- **Domain (pure, tested)**: `EncounterRun` — sequential/parallel wave progression, wave
  clearing, completion/fail (+ `EncounterRun.spec`).
- **World runtime**: `WaveService.startEncounter(id, ctx)` spawns via `EnemyService`, tracks
  deaths via `CombatService.EntityDied`, advances waves (rest between), applies difficulty
  scaling (count + health + elite substitution), and cleans up. `Shared/Scaling` reads
  `configs/Difficulty`.
- **Integration**: new `Clear` objective (`encounterId`) -> `ObjectiveTrackers.Clear` ->
  WaveService; wave/kill progress streams to the `MissionEvent` feed. `EnemyService.spawn`
  gained a health-scaling argument.
- **Chapter 1** moved from a flat 3-dummy spawn to a real 2-wave encounter
  (`chapter_one_ambush`, with an elite in wave 2).

Clean seam for level design: drop encounters into `configs/Encounters.luau` and reference them
from missions — no new code. Resolves the "objective spawns call EnemyService directly" debt.

## Version 0.7.0 — Mission & Objective System

Data-driven missions, objectives, and chapters replace the hardcoded Chapter 1 slice — the
former slice is now content, not code. Placeholder text only, no UI/VFX/polish:

- **Data**: `configs/Missions.luau` (ordered objectives + narrative + symbolic reward) and
  `configs/Chapters.luau` (ordered mission ids); shared contract in `Shared/Mission` (Enums:
  Reach/Kill/Survive/Defend/Escort/Interact; Types).
- **Domain (pure, tested)**: `Objective` and `MissionRun` (sequential activation, completion,
  failure) + specs `Objective.spec`, `MissionRun.spec`.
- **World runtime**: `MissionRuntimeService` (mission -> live run, drives a `Match`, streams a
  `MissionEvent` feed), `ObjectiveTrackers` (Reach/Kill/Survive/Interact full; Defend/Escort
  foundational with a neutral NPC), `ChapterService` (auto-plays a chapter; flag `EnableCampaign`).
- **Integration / refactor**: `MissionService` loads + validates the configs (and chapters);
  `EnemyService.spawn(enemyId, position)` generalised from the hardcoded dummy; `Net`
  `SliceNarrative` -> `MissionEvent`; client `NarrativeController` -> `MissionController`.
- **Removed** the hardcoded slice: `ChapterOneSliceService`, `ChapterOneSliceFlow` (+ spec),
  `configs/ChapterOneSlice.luau`, `NarrativeController`. Chapter 1 plays identically, from data.

Resolves slice tech debt: objectives are data (not baked into an orchestrator) and the run
uses the `Match` lifecycle. Reward stays symbolic until the Progression milestone.

## Version 0.6.0 — Chapter 1 Vertical Slice (integration)

The first playable end-to-end loop, proving the foundations connect. DEV/TEST scaffolding
and placeholder text only — no new gameplay systems, no UI/VFX/animations:

- **ChapterOneSliceService** (`Server/World`, Forgotten Lands only): an ORCHESTRATOR over
  existing public APIs (never their internals). Per-player flow: Spawn -> Story Intro ->
  Exploration -> Lore -> Objective -> Undead Encounter -> Combat -> Reward -> End.
- **Pure state machine** extracted to `ChapterOneSliceFlow` (`Server/Domain`) — ordered
  states + legal single-step transitions, validated on every advance. Spec:
  `Tests.ChapterOneSliceFlow.spec`.
- **Exploration**: visible placeholder markers + server-side distance detection.
- **Encounter**: reaching the objective spawns scripted undead via the existing
  `EnemyService` (reuses the `training_dummy` block); the always-on test dummy is now off.
- **Completion**: encounter deaths tracked through `CombatService.EntityDied` -> symbolic
  reward -> end -> marker cleanup. The intro is start-once and survives respawn.
- **Networking / config**: one server->client remote `SliceNarrative` (client
  `NarrativeController` prints beats — no UI); `configs/ChapterOneSlice.luau` (placeholders)
  + `Settings` flag `EnableChapterOneSlice`.

No existing system was modified beyond additive hooks (a `Net` remote, `Settings` flags).
Slice hardening (real reward, multiplayer, Match/Mission integration) is tracked in `Todo`.

## Version 0.5.0 — Phase 5: Enemy AI Foundation

The enemy AI architecture (foundation only — no waves, spawning system, pathfinding, bosses,
abilities, or optimisation):

- **EnemyBrain** (`Server/Domain/AI`): a pure, testable state machine — Idle → Chase → Attack
  → Return → Dead — deciding state from perceived distances only. Easy to extend.
- **EnemyAIService** (`Server/World`): drives each enemy per `Heartbeat` — perceive (nearest
  player via `CombatService`) → decide (brain) → actuate. Movement is simple **kinematic**
  (`PivotTo` toward target/spawn, no pathfinding). Attacks go **through the existing
  `CombatService.applyDamage`** — no duplicate combat logic.
- **Config-driven**: detection / attack / leash / arrival radii, move speed, attack cooldown
  and damage come from a new `AI` block in `configs/Enemies` (placeholder tuning). Nothing is
  hard-coded.
- **EnemyService**: one additive `EnemyAIService.attach(...)` call on spawn (no-op for enemies
  without an `AI` block). The dummy rig is unchanged.
- **Tests**: `EnemyBrain` spec covering every transition.

`CombatService` is untouched; enemy damage reuses the same authoritative path as the player's
melee. The training dummy now detects, chases, and attacks the player (and is still killable).

## Version 0.4.0 — Phase 4: Inventory & Equipment Foundation

The item / inventory / equipment base, wired into the combat slice (no UI, loot, crafting,
shops, or balancing):

- **Items config**: `configs/Items.luau` — the item catalog (structure/metadata). Weapon
  items link to their combat stats in `Weapons.luau` via `WeaponId`.
- **Domain**: `Inventory` (item instances, uids, capacity) and `Equipment` (per-slot equipped
  instances) — pure classes in `Server/Domain/Inventory`.
- **Services** (`Server/Services`, shared): `InventoryService` (fleshed out from its skeleton
  — add/remove/get, item-id validation) and new `EquipmentService` (equip/unequip, plus
  `getEquippedWeaponId` for the combat layer). Per-player in-memory state; profile
  serialization is a deferred follow-up.
- **Shared contract**: `Shared/Inventory` `Enums` (ItemCategory, EquipmentSlot) and `Types`.
- **Combat connection**: `MeleeCombatService` now reads the attacker's **equipped** MainHand
  weapon (no hard-coded `starter_sword`); `PlayerCombatService` grants + equips a starter
  weapon on entering the World (dev flag). Weapon stats still come from `configs/Weapons`.
- **Tests**: `Inventory` and `Equipment` domain specs.

`CombatService` and the authoritative combat flow (validation, hit detection, `applyDamage`)
are unchanged — only the melee weapon *source* moved to equipment.

## Version 0.3.1 — Phase 3: Combat Vertical Slice

Wires the combat foundation to real gameplay end-to-end (player swing → server validation →
enemy damage → death). No inventory, AI, waves, VFX, animations, or balanced values:

- **Player → CombatEntity**: `PlayerCombatService` (World) registers each player's character
  as a CombatEntity on spawn; `HumanoidAdapter` mirrors the authoritative `Health` onto the
  character's `Humanoid` (Health stays source of truth).
- **Enemy → CombatEntity**: `EnemyService` (World, generic for undead/animals/bosses/NPCs)
  spawns and registers enemies; ships a TEST training dummy behind `EnableCombatTestDummies`.
- **Server-authoritative melee**: `MeleeCombatService` validates the swing (attacker alive,
  per-player cooldown), performs server-side range + arc hit detection, and applies damage
  via `CombatService`. The client sends only intent + aim — never targets or damage.
- **First remotes**: `Shared/Net` declares `RequestMeleeAttack` (client→server, validated)
  and `CombatEvent` (server→client feedback); `CombatController` (client) sends the intent.
- **Additive only**: `CombatService` gained one read accessor (`getAllEntities`); `Net` now
  waits for the Remotes folder on the client so lookups are replication-safe.
- **TEST placeholders**: `starter_sword` (Weapons), `training_dummy` (Enemies), and the
  `Combat` block/flags (Settings) — not balanced values.

`ZombieService` untouched (stays the future undead-content layer over the generic `EnemyService`).

## Version 0.3.0 — Phase 3: Combat Foundation

The server-authoritative combat core for the Forgotten Lands (no weapons, enemies, or
balancing values — foundation only):

- **CombatService** (`Server/World`, Forgotten Lands only): the single authoritative damage
  entry point. Owns an entity registry (id ↔ entity, model ↔ entity for hit lookup),
  validates every hit (alive / i-frames / faction), resolves through the pipeline, applies it,
  and emits `DamageDealt` / `EntityDied` signals.
- **Damage system**: `DamagePipeline` — a pure, ordered modifier chain (empty by default) so
  armor, resistances, crits, and abilities extend it later without touching the core.
- **Entity / target handling**: `CombatEntity` — a generic combatant (players, undead,
  animals, bosses, NPCs, traps all share it) with faction, stats, and i-frames; instance→entity
  resolution walks a hit part up to its registered model.
- **Health system**: `Health` — server-authoritative current/max with clamping, latched death,
  and `Changed` / `Died` signals; decoupled from Humanoids/replication.
- **Shared contract**: `Combat.Enums` (DamageType, Faction, CombatState) and `Combat.Types`;
  plus a minimal `Core/Signal` primitive.
- **Config structure** (schemas only, no values): new `Combat.luau`; enriched `Weapons.luau`
  and `Enemies.luau` schemas (generic — enemy *archetype* is data, not a faction).
- **Tests**: `Health`, `CombatEntity`, `DamagePipeline` specs via the existing runner.

No new remotes this phase — the client-facing bridge is added with the HUD/VFX feature. No
Phase 2 systems changed.

## Version 0.2.0 — Phase 2: Core Systems

The server/client backend framework is implemented (no gameplay content yet — see the
reserved skeletons at the end):

- **Boot framework**: a shared, two-phase (`Init` → `Start`) `Loader` that boots modules
  deterministically and isolates failures; a scoped `Logger`.
- **Server core**: a place-aware server `Bootstrap` that boots the shared Services plus the
  place-specific `Hub`/`World` folder, and a per-player client `Bootstrap`.
- **Player & persistence ("Save Architecture")**: `PlayerService` (join/leave lifecycle +
  runtime `PlayerSession`), `DataService` (in-memory profile cache), `SaveService` (autosave +
  save-on-close over a pluggable `Store` — an `InMemoryStore` mock, so **no real DataStore is
  touched yet**), and a versioned `ProfileSchema`.
- **Run frameworks**: `PartyService`/`Party`, `MatchService`/`Match` (validated lifecycle
  state machine), `MissionService`/`Mission` (empty registry by design), and `TeleportService`
  (safely no-ops while the places are unpublished). `GameService` detects Hub vs. Forgotten
  Lands at runtime.
- **Shared contracts**: `Net` remote registry (zero remotes declared by design), the typed
  `Config` accessor, `Constants`, and `Types`.
- **Reserved skeletons for later phases**: `InventoryService`, `QuestService`, `ZombieService`,
  and the `Input` / `Camera` / `UI` / `Audio` client controllers.

Both places build cleanly (`rojo build default.project.json` and `world.project.json`).

## Version 0.1.0 — Phase 1: Design & Structure

- Authored the Game Design Document and the Architecture document.
- Applied the dual-place Rojo structure: `default.project.json` (Kingdom Hub) and
  `world.project.json` (Forgotten Lands), sharing `scripts/Shared`, `scripts/Modules`, and
  `configs`.
- Added the `configs/` data-driven balancing scaffold (schema skeletons documented in their
  headers; no balance values yet).

## Version 0.0.1

Project initialized.
