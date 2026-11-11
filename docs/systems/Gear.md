# Gear: the weapon bar, the bow, the back (armour or quiver), the lantern's belt (2026-11-10)

**Status:** BUILT (0.46.0). Numbers in `configs/Gear.luau` and `configs/Weapons.luau`. Reads with `Arsenal.md` (the
design of the weapons), `Animation.md` (the house rules of a move), `FirstPerson.md`.

## What the developer asked for

- The weapons a player has are shown along the bottom, on a bar of our own (not Roblox's), and the mouse wheel chooses.
- Animation for the sword, the spear and the bow.
- Armour that appears on **F**; on the back a player carries ONE thing, the armour or the arrows; with the arrows, a
  very small quiver.
- The lantern hung at the left hip from a small line shown while the mouse is free, so the hand is empty.

## The weapon bar

`UI/WeaponBar` (drawing) and `Controllers/CombatController` (keys). One black plate a weapon: its picture, its number,
the bow's arrows. The one in hand is lifted, larger, gold-edged, and its name is written above the bar for a moment.

| Key | Does |
|---|---|
| Mouse wheel | the next weapon, the one before (round and round) |
| 1 2 3 | that weapon in hand; the number of the one in hand puts it away |
| Left click | a blow (sword, spear). With the bow: HOLD to draw, let go to loose |

The server decides (`World/WeaponVisualService`: `RequestSelectWeapon`; it answers the owner with `WeaponBar`). Every
weapon carried is ON the body all the time: the sword at the right hip, the spear and the bow on the back; one joint
each, moved between its place and the hand. What a player carries is the weapon items in their inventory;
`Gear.Starter.Weapons` (sword, spear, bow) is handed out at the gate until the lobby's armoury decides it.

The models are put together when a body spawns (`Domain/GearModels`) from the sculpted pieces the dead already use
(`ServerStorage.Assets.UndeadKitField`): no upload. The sword is the developer's own (`Assets.Weapons.starter_sword`).

## The moves (`Shared/Anim/PlayerActionAnims`)

| Weapon | Hold | Attack |
|---|---|---|
| Sword (one hand) | the guard | cut A (upper right to lower left, 0.72 s) and cut B (0.76 s) in turn: an X. The developer's own cuts of August, kept number for number. |
| Spear (two hands) | at the chest, the body turned a quarter away, the point ahead and a little up | thrust A (straight, 0.78 s) and thrust B (from by the ear, down over the guard, 0.86 s) in turn. The right hand drives; the shaft slides through the left. |
| Bow | carried low in the left hand | the draw (0.8 s: the bow comes up, the hand finds the string, the string comes back under the chin), held with a breath in it, the loose (the string gone in a twentieth of a second, the hand flying back, then over the shoulder to the quiver), or let down |

Two ways of writing a move: **clips** (joint angles; the sword, the armour, the lantern) and **tracks** (where the WEAPON
is: the holding hand, where it points, how far along the other hand closes, how far the string is drawn). From a track
`Shared/Anim/WeaponPose` works out both arms so the hands are exactly on the weapon, in the same frame, whatever the
body under them is doing. The legs go on walking under every move. A weapon follows the eyes up and down.
`tools/PreviewPose` stands one moment of any move on a body in a booth, to be looked at from outside or from its eyes.

## The bow (`World/RangedCombatService`)

`hunting_bow`: 34 damage at a full draw (0.8 s), 45% of it at the least draw (0.3 s; sooner than that only lowers the
bow); the arrow flies at up to 185 studs a second through `ProjectileService` (a wall stops it), ready again 0.45 s
after. It needs the quiver on the back with an arrow in it; if not, a line at the top says why. The string and the
nocked arrow are the server's parts; each client moves them with the draw.

## The back (`World/GearService`, `Controllers/GearController`)

One thing: **armour** or **quiver** (`Back` on the player). The change is a line shown while the mouse is free
("Carry the quiver on your back"); armour being worn must come off first.

| | Carried | Used |
|---|---|---|
| Armour | a bundle of plate strapped on the back | **F** puts it on: chest, shoulders, arms, legs appear in turn over 1.5 s while the arms pull it on; F again takes it off (1 s). Worn: 25% of every ordinary blow turned aside, the stamina bar fills 10% slower (Arsenal 6, the Medium class). |
| Quiver | a small leather quiver, the flights of up to six arrows showing | 16 arrows to start, 24 at most; an empty quiver takes a bundle of 8 from the pack by itself |

## The lantern's belt (`World/LanternService`, `Controllers/LanternController`)

With the mouse free: "Hang the lantern on your belt" (it hangs at the left hip and burns the same) and "Take the
lantern in your hand". Taking a spear or a bow in hand hangs it up by itself (both hands are needed). In the hand, the
left arm holds it up and the hand is kept level so it hangs straight. The shutter is **G** now (F is the armour).

## Still to do

- The developer's choices: where the back may be changed (anywhere, now), what the armoury hands out.
- Axe and mace are in the data and use the sword's cuts (slower) until they have models and moves of their own.
- A shield, a heavy attack, a guard and a parry (Arsenal 3); hit-stop and sounds (Animation 6).
- See a thrust, a cut and a loose from OUTSIDE with a second player.
