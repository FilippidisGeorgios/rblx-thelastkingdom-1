--!strict
--[[
	Config: Crouch
	Ducking down, to fit a low passage and to be quiet.

	WHAT IT DOES. The player presses Ctrl, or C (a button on a phone) and the body gets shorter, the walk gets slower, and the
	feet make no noise (`Crouching` is published on the Player for the hunters and the dead to read, when they do).
	Stand up again and everything comes back. You can only stand where there is room: under a low ceiling the
	server keeps you down.

	HOW (2026-11-15, the animation pass: a REAL crouch). The body keeps its size: the Humanoid lowers the hips
	(`HipHeight` down by `HipDrop`, tweened, so nothing pops) and the crouch clips (Shared/Anim/PlayerMoveAnims, THE
	CROUCH) fold the legs under them by IK, tip the pelvis and the chest forward and lift the head to look ahead; the
	eyes go down and forward with the head (`EyeShift`, Client/Controllers/ViewController). Until then the body was
	made half its size (`BodyHeightScale` 0.5).

	THE LOW PASSAGES are built to this: a ceiling 4.3 studs high clears a crouched body (4.0 at its highest) and stops
	a standing one (about 5.2). The cellar's crawl (tools/BuildCellar) was raised from 3.4 to 4.3 for the real crouch.

	Read via: Config.get("Crouch")
]]

local Crouch = {
	Enabled = true,

	-- How far the Humanoid lowers the hips, studs. MUST be PlayerMoveAnims.CROUCH_DROP (the clips are built for it;
	-- Tests/Crouch.spec checks). Every player has the same square body (Services/AvatarService), so one number fits all.
	HipDrop = 0.95,

	-- How high the crouched body is at its highest (the head's top over the floor, the walk's highest moment),
	-- measured with tools/Filmstrip; and the clear height of a low passage built for it.
	CrouchedHeight = 4.0,
	PassageHeight = 4.3,

	-- Where the eyes go when crouched, against where they are standing (the root is already lower by HipDrop): the
	-- head is lower on the bent body and over the knees, ahead (object space of the root: -Z is ahead).
	EyeShift = Vector3.new(0, -0.44, -0.85),

	-- Share of the walking speed kept while crouched.
	SpeedMult = 0.5,

	-- Seconds the body takes to go down or come up.
	TweenSeconds = 0.2,

	-- The least time between two presses, so a held or hammered key cannot make the body flutter.
	ToggleGap = 0.3,

	-- How tall a standing body is, in studs: used only when the server cannot measure the body itself.
	StandHeight = 5.2,

	-- The key that toggles (an Enum.KeyCode name). A phone has a button instead.
	Key = "LeftControl", -- (2026-11-10: Ctrl, the developer asked; C still works, see AltKey)
	AltKey = "C" :: string?,

	-- HOLD or TOGGLE is the player's own choice now (Settings, HOLD TO CROUCH): held, the body is down while Ctrl is
	-- pressed and up when it is let go; not held (the start), a press goes down and the next comes up.
}

return table.freeze(Crouch)
