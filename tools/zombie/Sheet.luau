--[[
	Sheet (2026-11-14): a contact sheet of one clip. N copies of a body stand side by side in the Booth, each frozen at
	one moment of the clip, so a whole motion is judged in one photograph (left to right = time).

	    local Sheet = require(lab.Sheet)
	    local cam, look = Sheet.show(master, prepare, ClipPlayer, clip, { 0, 0.15, 0.3, 0.45 }, { spacing = 4, side = true })
	    -- prepare(model) is run on each copy first (CrawlerBody.make, for instance); it may be nil

	`opts.side`: the copies face the camera's left (a profile); otherwise they face the camera.
	`opts.extra(model, pose)`: called after sampling, to change the pose (the second hand on a haft, for instance).
	A tool, not game code.
]]

local Workspace = game:GetService("Workspace")

local Sheet = {}

function Sheet.show(master: Model, prepare: ((Model) -> ())?, ClipPlayer: any, clip: any, times: { number }, opts: any?): ({ number }, { number })
	opts = opts or {}
	local Booth = require(script.Parent.Booth)
	local Pose = require(script.Parent.Pose)
	local folder = Booth.build()
	for _, c in folder:GetChildren() do
		if c:IsA("Model") then
			c:Destroy()
		end
	end
	local spacing = opts.spacing or 4
	local n = #times
	for i, t in times do
		local m = master:Clone()
		m.Name = "Frame" .. i
		if prepare then
			m.Parent = script.Parent:FindFirstChild("Work") or Workspace
			prepare(m)
		end
		m.Parent = Workspace
		Pose.rest(m)
		Booth.stand(m, if opts.side then 90 else 0)
		m:PivotTo(m:GetPivot() + Vector3.new(((n + 1) / 2 - i) * spacing, 0, 0))
		local pose = {}
		if clip then
			ClipPlayer.sample(clip, t, pose, 1)
		end
		if opts.extra then
			opts.extra(m, pose)
		end
		Pose.apply(m, pose)
	end
	local width = (n - 1) * spacing + 4
	local dist = width / 3.67 * 1.25
	local c = Booth.AT
	local look = c + Vector3.new(0, opts.height or 2.2, 0)
	local cam = look + Vector3.new(0, opts.lift or 1.2, -dist)
	return { cam.X, cam.Y, cam.Z }, { look.X, look.Y, look.Z }
end

return Sheet
