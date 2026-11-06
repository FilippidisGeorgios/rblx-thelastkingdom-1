--!strict
--[[
	Config: Movement
	How every player moves (docs/systems/Movement.md): one walk for everybody, running on Shift with stamina, the roll on Q,
	and the mouse lock with its dot in the Settings. The developer's numbers (2026-11-05), modelled on the Roblox game
	"Command An Army":

	  STAMINA  is counted in SECONDS OF RUNNING. A full bar is 6 seconds of Shift held down while moving. A roll costs 1.5
	           of them, so a full bar is exactly four rolls. The bar starts to fill 1 second after the last run or roll,
	           and fills from empty to full in 15 seconds.
	  RUN      Shift, held. When the bar runs dry the run stops, and it needs a NEW press of Shift (a held key does not
	           start again by itself the moment a drop has come back: that would flutter).
	  ROLL     Q: a forward tumble (the head goes under) toward the keys held (W, A, S, D, as the camera sees them;
	           none held = straight ahead). About half a second, and it covers about twice the ground that walking does
	           in the same time.
	  MOUSE LOCK a switch in Settings (not Roblox's own Shift lock, which is switched off: Shift runs). On: the mouse stays in
	           the middle, a very small dot marks it, and the body turns with the camera.

	Read via: Config.get("Movement")
]]

local Movement = {
	-- Which of the three movement sets everybody walks with (Shared/Anim/PlayerMoveAnims: 1 the soldier, 2 the ranger,
	-- 3 the veteran). For a test in Studio, set the workspace attribute `TLK_MoveStyle` to 1, 2 or 3: everybody changes
	-- at once.
	Style = 1,

	Stamina = {
		Max = 6, -- seconds of running on a full bar
		RefillSeconds = 15, -- from empty to full
		RefillDelay = 1, -- seconds after the last run or roll before it starts to fill
		MovingSpeed = 3, -- studs a second: below this a held Shift is not running (standing still costs nothing)
	},

	Run = {
		Key = "LeftShift",
		SpeedMult = 1.5, -- of the walking speed (16 -> 24)
	},

	Roll = {
		Key = "Q",
		Cost = 1.5, -- seconds of the bar
		Seconds = 0.58, -- how long the tumble lasts; control comes back at the end
		Distance = 20, -- studs covered: 2.15 times what walking covers in the same time (9.3), more than running (13.9)
		Gap = 0.12, -- seconds after a roll ends before the next one may start
		Ease = 0.55, -- how the speed falls off: 0 = even, 1 = all at the start (a push that dies away)
	},

	MouseLock = {
		DotSize = 4, -- pixels across
		DotColor = Color3.fromRGB(245, 238, 222),
		DotTransparency = 0.12,
		ShoulderOffset = 1.6, -- studs the camera sits to the right of the head, as Roblox's own lock does
	},

	-- The stamina bar: right under the health bar (configs/Hud.HealthBar), as wide, thinner, blue.
	Bar = {
		Height = 7,
		Gap = 3,
		Color = Color3.fromRGB(70, 140, 226),
		ColorLow = Color3.fromRGB(50, 92, 170), -- below one roll's worth: a roll is not possible
	},
}

return table.freeze(Movement)
