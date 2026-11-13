--!strict
--[[
	Config: Gear
	What a player WEARS and CARRIES that can be seen (docs/systems/Gear.md): the weapons on the weapon bar and where each
	one hangs when it is put away, the one thing on the back (the armour OR the quiver), and how each model is made.

	THE WEAPON BAR (the developer, 2026-11-10). A player's weapons are shown along the bottom of the screen (our own bar,
	not Roblox's): the mouse wheel or the number keys take one in hand; the number of the one in hand puts it away.
	Every weapon a player carries is ON the body all the time: the sword at the hip, the spear and the bow on the back;
	the one in use is in the hand.

	THE BACK carries the spear and the bow (above) and a small leather QUIVER: without it a bow has no arrows.

	NO BODY ARMOUR (the developer, 2026-11-13): "when I said armour I meant a SHIELD held in the left hand". Plate worn
	on the head, arms and legs is not wanted anywhere, so nothing of it is kept here. The shield will be added with its own
	model and its own entry (Hand = "Left"), and the F key is free for it.

	THE MODELS. Nothing here is an uploaded asset. Each is put together when a character spawns from the sculpted pieces
	the dead already use (`ServerStorage.Assets.UndeadKitField`, made by tools/BuildUndeadKit: pieces sculpted from small
	cubes, which is exactly the look of a square body), or from `ServerStorage.Assets.Weapons.<id>` when the developer
	has put a model of their own there (the sword). In a place without the kit a plain stand-in is built instead.

	A piece's own frame (tools/BuildUndeadKit): a weapon runs along its +X from the grip.

	Schema, weapons:
	  Kind      "sword" | "axe" | "mace" | "spear" | "bow": which clips move it (Shared/Anim/PlayerActionAnims) and its
	            picture on the bar
	  Hand      "Right" | "Left": the hand that holds it (a bow is held in the left and drawn with the right)
	  TwoHanded the other hand is on it too: a lantern cannot be carried in that hand (it goes to the belt by itself)
	  Kit       the pieces, each `{ Piece, At }` in the weapon's own frame before scaling; `Scale` the whole
	  GripAt    studs from the weapon's origin, along it, where the hand closes (after scaling)
	  SupportAt (spear) where the second hand closes
	  Grip      how it sits in the hand: six numbers (x, y, z in studs, pitch, yaw, roll in degrees) from the hand's
	            grip point. The blade or shaft runs along the grip frame's +Y.
	  Sheath    where it hangs when put away: the body part and six numbers from that part's middle
]]

local function six(x: number, y: number, z: number, pitch: number, yaw: number, roll: number)
	return { x = x, y = y, z = z, pitch = pitch, yaw = yaw, roll = roll }
end

local Gear = {
	-- What every player has when a run begins, until the lobby's armoury decides it (docs/systems/Arsenal.md 7.2).
	Starter = {
		Weapons = { "starter_sword", "footman_spear", "hunting_bow" },
		Arrows = 16,
	},

	Weapons = {
		starter_sword = {
			Kind = "sword",
			Hand = "Right",
			TwoHanded = false,
			-- (the developer's own model is in ServerStorage.Assets.Weapons.starter_sword; these two sets of numbers are
			-- the ones they turned by hand in play, 2026-08: do not "tidy" them)
			Grip = six(0, -0.55, 0, -50, 90, 0),
			Sheath = { Part = "RightUpperLeg", At = six(0.65, 0.15, -1.54, 79, -87, -13) },
		},
		footman_spear = {
			Kind = "spear",
			Hand = "Right",
			TwoHanded = true,
			Kit = {
				{ Piece = "spear_shaft", At = CFrame.new(0, 0, 0) },
				{ Piece = "spear_head", At = CFrame.new(9.95, 0, 0) },
			},
			Scale = 0.72,
			GripAt = 2.1,
			SupportAt = 3.75,
			Grip = six(0, 0, 0, 0, 0, 0),
			-- up the back, leaning to the left shoulder, outside whatever else is carried there
			Sheath = { Part = "UpperTorso", At = six(0.25, -0.35, 0.98, 0, 0, 24) },
		},
		hunting_bow = {
			Kind = "bow",
			Hand = "Left",
			TwoHanded = true,
			Kit = {
				{ Piece = "bow_long", At = CFrame.new(0, 0, 0), Skip = { bone = true } }, -- its own string is replaced by ours
			},
			Scale = 1.12,
			GripAt = 0,
			Grip = six(0, 0, 0, 0, 0, 0),
			-- across the back the other way (leaning to the right shoulder), the stave against the back and the string behind it
			Sheath = { Part = "UpperTorso", At = six(-0.2, 0.1, 0.74, 0, 0, -28) },
			-- the string: studs from the grip to each tip along the stave, how far behind the grip it runs at rest, how far
			-- it is pulled at a full draw, and how thick it is drawn
			String = { Half = 2.72, Back = 0.3, Draw = 1.95, Width = 0.035, Color = Color3.fromRGB(214, 204, 178) },
			Arrow = { Piece = "arrow", Scale = 1.15 },
		},
	},

	-- What hangs on the back besides the weapons.
	Back = {
		Quiver = {
			-- on the right of the back, leaning, its mouth by the right shoulder
			Kit = { { Piece = "quiver", Part = "UpperTorso", At = CFrame.new(0.42, -0.12, 0.7) * CFrame.Angles(0, 0, math.rad(-14)), Scale = 1.15 } },
			-- the arrows standing in it: at most this many are drawn, the first at `At`, each next one `Step` on and turned
			Arrows = { Piece = "arrow", Scale = 0.72, Most = 6, Lift = 1.45 },
			Capacity = 24,
			BundleItem = "arrow_bundle", -- a bundle from the pack fills an empty quiver
			BundleArrows = 8,
		},
	},

	-- The lantern hung on the belt (the mouse unlocked: "Hang the lantern on your belt"): on the left hip, by the leg.
	LanternBelt = { Part = "LowerTorso", At = CFrame.new(-1.12, 0.22, 0.05) },
}

return table.freeze(Gear)
