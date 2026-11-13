# Gear: the weapon bar, the bow, the back (armour or quiver), the lantern's belt (2026-11-10)

**Status:** BUILT (0.46.0); the body armour was TAKEN OUT in 0.46.1 (see the correction below). Numbers in
`configs/Gear.luau` and `configs/Weapons.luau`. Reads with `Arsenal.md` (the design of the weapons), `Animation.md` (the
house rules of a move), `FirstPerson.md`.

## CORRECTION, 2026-11-13: "armour" meant a SHIELD

The developer, after trying 0.46.0: "when I said armour I meant a shield, the thing held in the LEFT hand. I do not want
a full armour worn by the player. Take out any armour that goes on the head, arms or legs and do not put anything in its
place until I say." So 0.46.1 removed all of it: the F key, putting plate on and off piece by piece, the bundle on the
back, the swap between armour and quiver (`RequestArmour`, `RequestBack`, `GearController`), the plate clips
(`armour_don`, `armour_doff`), the armour icon, and the 25% turned aside / 10% slower breath. The back now carries the
spear, the bow and the quiver. **The shield is not built.** When it is: a weapon-like entry in `Weapons` with `Hand =
"Left"`, a model of its own (not made of parts), its own raise / block clip, and F or the right mouse button for it.
`MovementService.setRefillScale` is kept for it (a heavy shield may slow the breath).

## What the developer asked for

- The weapons a player has are shown along the bottom, on a bar of our own (not Roblox's), and the mouse wheel chooses.
- Animation for the sword, the spear and the bow.
- ~~Armour that appears on F; ONE thing on the back, the armour or the arrows~~ (see the correction above). What stays:
  a very small quiver on the back for the arrows.
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

## The back (`World/GearService`)

The spear and the bow lean across it (`Weapons.*.Sheath`), and a small **quiver** sits on the right: a small leather
quiver, the flights of up to six arrows showing. 16 arrows to start, 24 at most; an empty quiver takes a bundle of 8 from
the pack by itself. Published on the player: `Arrows`. (Before 0.46.1 the back held ONE thing, the quiver or a body
armour, with a swap line and F; see the correction at the top. A quiver is shown whether or not the player carries a bow:
to be decided with the armoury.)

## The lantern's belt (`World/LanternService`, `Controllers/LanternController`)

With the mouse free: "Hang the lantern on your belt" (it hangs at the left hip and burns the same) and "Take the
lantern in your hand". Taking a spear or a bow in hand hangs it up by itself (both hands are needed). In the hand, the
left arm holds it up and the hand is kept level so it hangs straight. The shutter is **G** (it was F until 0.46.0; F is kept free for the shield).

## Still to do

- The developer's choice: what the armoury hands out (and whether a player with no bow carries a quiver).
- **The shield** (left hand, a real model, a raise and a block clip) and the guard and parry that go with it (Arsenal 3).
- **Real 3D weapons** from Blender instead of the kit's sculpted cubes: see `docs/Tooling.md`.
- Axe and mace are in the data and use the sword's cuts (slower) until they have models and moves of their own.
- A heavy attack; hit-stop and sounds (Animation 6).
- See a thrust, a cut and a loose from OUTSIDE with a second player.
