--!nonstrict
--[[
	zombie/Run — one call from the sync bundle to a photograph.

	  Run.stage(themeId, opts)   builds the showroom, makes the eight figures, dresses them in the theme, stands them in a row,
	                             points the Edit camera at them and returns { position, lookAt } for screen_capture.
	    opts.only        { "king", "doctor" }  only these categories (a close-up)
	    opts.closeness   < 1 comes closer
	    opts.lift        raises the camera
	  Run.clear()        takes the showroom away and puts the lighting back
]]

local Showroom = require(script.Parent.Showroom)
local Figures = require(script.Parent.Figures)
local Themes = require(script.Parent.Themes)

local Run = {}

function Run.stage(themeId: string, opts: { [string]: any }?)
	opts = opts or {}
	Showroom.build(1)
	local theme = Themes.get(themeId)
	if theme.mood then
		Showroom.mood(theme.mood)
	end
	local models = {}
	for _, c in Figures.CATEGORIES do
		local keep = true
		if opts.only then
			keep = table.find(opts.only, c.id) ~= nil
		end
		if keep then
			local m = Figures.make(c.id)
			Themes.apply(themeId, m, c.id)
			table.insert(models, m)
		end
	end
	Showroom.lineup(models, 0)
	local pos, look = Showroom.camera(0, #models, opts.closeness)
	pos += Vector3.new(0, opts.lift or 0, 0)
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = CFrame.lookAt(pos, look)
	return { position = pos, lookAt = look, count = #models }
end

function Run.clear()
	Showroom.clear()
end

return Run
