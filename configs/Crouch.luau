--!strict
--[[
	Config: Crouch
	Ducking down, to fit a low passage and to be quiet.

	WHAT IT DOES. The player holds C (a button on a phone) and the body gets shorter, the walk gets slower, and the
	feet make no noise (`Crouching` is published on the Player for the hunters and the dead to read, when they do).
	Stand up again and everything comes back. You can only stand where there is room: under a low ceiling the
	server keeps you down.

	HOW. Roblox's own R15 body scale (`BodyHeightScale` on the Humanoid), tweened, so nothing pops. This is a first
	version on purpose: a body that is shorter and slower. A real crouch (bent knees, a lowered back) is a
	hand-made animation, which the developer has said comes in the animation pass.

	THE LOW PASSAGES are built to this: a ceiling 3.4 studs high clears a crouched body (about 3.0) and stops a
	standing one (about 5.2).

	Read via: Config.get("Crouch")
]]

local Crouch = {
	Enabled = true,

	-- BodyHeightScale while crouched: the SAME for every player (an avatar's own height scale is 0.9 to 1.05), so a
	-- low passage fits everyone. Measured on an avatar at the tallest scale, 1.05: it is 5.15 studs high standing and
	-- 2.98 studs high at 0.5 (the head and hair do not shrink, so the height is about 1.0 + 3.95 x the scale):
	-- under a 3.4 ceiling with 0.4 of air above the head.
	CrouchScale = 0.5,

	-- Share of the walking speed kept while crouched.
	SpeedMult = 0.5,

	-- Seconds the body takes to go down or come up.
	TweenSeconds = 0.2,

	-- The least time between two presses, so a held or hammered key cannot make the body flutter.
	ToggleGap = 0.3,

	-- How tall a standing body is, in studs: used only when the server cannot measure the body itself.
	StandHeight = 5.2,

	-- The key that toggles (an Enum.KeyCode name). A phone has a button instead.
	Key = "C",

	-- The key that is HELD: down while it is pressed, up when it is let go (the developer asked for Shift, 2026-10-31).
	-- Letting go under a low ceiling does nothing: the server keeps the body down until there is room.
	HoldKey = "LeftShift",
}

return table.freeze(Crouch)
