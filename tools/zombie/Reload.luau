--[[
	Reload (2026-11-14): puts the newest sync bundle's zombie tools into ServerStorage.ZombieLab and FRESH copies of
	the game modules a tool needs into ZombieLab.Fresh (a fresh instance is a fresh `require`: Studio keeps the first copy
	of a module it ever required for the whole session).

	    local b = game:GetObjects("rbxasset://tlk_sync/<name>.rbxm")[1]
	    local lab = require(b.__Tools.zombie.Reload)(b)

	A tool, not game code.
]]

local ServerStorage = game:GetService("ServerStorage")

-- the game modules a tool may want, by where they live in the bundle
local FRESH = {
	{ "ServerScriptService.Server.Domain", "CrawlerBody" },
	{ "ReplicatedStorage.Shared", "Anim" },
	{ "ReplicatedStorage.Config", nil },
}

return function(bundle: Instance): Folder
	local lab = ServerStorage:FindFirstChild("ZombieLab") or Instance.new("Folder")
	lab.Name = "ZombieLab"
	lab.Parent = ServerStorage
	for _, m in (bundle :: any).__Tools.zombie:GetChildren() do
		local old = lab:FindFirstChild(m.Name)
		if old then
			old:Destroy()
		end
		m.Parent = lab
	end
	local fresh = lab:FindFirstChild("Fresh") or Instance.new("Folder")
	fresh.Name = "Fresh"
	fresh.Parent = lab
	fresh:ClearAllChildren()
	for _, f in FRESH do
		local home = bundle:FindFirstChild(f[1])
		if home then
			if f[2] then
				local m = home:FindFirstChild(f[2])
				if m then
					m.Parent = fresh
				end
			else
				local copy = home:Clone()
				copy.Name = "Config"
				copy.Parent = fresh
			end
		end
	end
	local work = lab:FindFirstChild("Work") or Instance.new("Folder")
	work.Name = "Work"
	work.Parent = lab
	return lab
end
