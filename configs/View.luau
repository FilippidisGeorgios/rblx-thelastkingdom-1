--!strict
--[[
	Config: View
	How a player SEES the game (docs/systems/FirstPerson.md). The developer's decision (2026-11-10): the whole game is
	played through the character's own eyes ("full screen", as the Roblox game DOORS does), in the lobby and in the castle
	alike. The mouse is always held in the middle and turns the head; ONE key lets it go.

	  FIRST PERSON   The camera sits at the eyes and cannot be pulled back. You see your own arms, legs and chest (not your
	                 head), so a sword, a bow or a lantern is in the picture because it is in your hands.
	  THE MOUSE      Held in the middle under a very small dot. `UnlockKey` (L) lets it go so you can press a button on
	                 the screen; L again takes it back. Any panel that opens (Settings, the pack, the forge...) lets it go
	                 by itself and takes it back when it closes.
	  THE HEAD       What your friends see: your head and chest follow where you look, up, down and into a turn.
	  THE STEP       The picture moves a little with each footfall and dips when you land (the HEAD BOB switch in Settings
	                 turns the stepping off for players it makes dizzy; the dip of a dash stays, small).
	  FIELD OF VIEW  How wide the picture is: ONE standard for every player (`Fov.Default`; the Settings choice was taken out
	                 on 2026-11-14, the developer's call). Running and dashing still widen it a little.

	Read via: Config.get("View")
]]

local View = {
	FirstPerson = true,

	-- The key that lets the mouse go and takes it back (an Enum.KeyCode name).
	UnlockKey = "L",

	-- Where the eyes are, from the place Roblox puts a first-person camera (the middle of the head): a little up and a
	-- little forward, so that looking down shows the chest and the legs and not the inside of the neck. It must stay
	-- INSIDE the head (the head is what stops at a wall): further forward and the camera would look through walls.
	Eye = Vector3.new(0, 0.2, -0.34),

	-- The field of view (degrees, top to bottom). A player chooses between Min and Max in Settings.
	Fov = { Default = 80, Min = 60, Max = 100, Step = 5 },
	RunFov = 4, -- added while running
	DashFov = 8, -- added at the start of a dash, gone by its end

	-- The step (HEAD BOB): studs the eyes move at each footfall, and degrees the picture leans.
	Bob = {
		WalkUp = 0.045,
		WalkSide = 0.028,
		RunUp = 0.085,
		RunSide = 0.045,
		Lean = 0.55, -- degrees of roll with the side-to-side
		StrafeLean = 1.4, -- degrees the picture leans into a sidestep (stays with HEAD BOB off: it is very small)
		Land = 0.32, -- studs the eyes dip on landing from a jump (scaled by how hard)
		Ease = 14, -- how quickly the eyes follow (bigger = tighter)
	},

	-- A dash (Q): the eyes go down and come up, the picture leans the way of the dash.
	Dash = { Dip = 0.85, Lean = 5 },

	-- The dot in the middle of the screen.
	Dot = { Size = 4, Color = Color3.fromRGB(245, 238, 222), Transparency = 0.12 },

	-- What friends see of where you look. Shares of the up-and-down look taken by the chest and by the head (the rest is
	-- the eyes), the most the head turns into a turn, and how often a look is sent.
	Look = {
		Waist = 0.34,
		Neck = 0.5,
		ArmShare = 0.5, -- with something in the hands, the arms follow the look by this much MORE than the chest does
		LeadSeconds = 0.14, -- the head runs this far ahead of a turning body
		LeadMax = 38, -- degrees
		SendHz = 12,
		SendStep = 1.5, -- degrees of change before a new look is sent
		Smooth = 12,
	},

	-- The small line that teaches the key: shown for this long after you get a body, and always while the mouse is free.
	Hint = { Seconds = 12, Locked = "Press  L  to unlock your mouse", Free = "Press  L  to lock your mouse" },

	-- Opening the eyes (the first time you get control in a place): seconds for the whole thing, and what the first
	-- breath looks like. Two slow blinks, the blur clearing, the picture settling from a narrow view to yours.
	Wake = {
		Enabled = true,
		Seconds = 4.2,
		Blur = 26,
		FromFov = 52,
	},
}

return table.freeze(View)
