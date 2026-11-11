--[[
	SyncFromBundle — run in a place in EDIT MODE, when the Rojo plugin is not connected.

	Makes the place's scripts the same as the files on disk, from ONE model file (a "bundle") that holds every script of
	the project. It is the same job Rojo does, for the times a script has to do it:

	  1. On the developer's machine:  node <scratchpad>/mksync.js world     (or: default, for the Kingdom Hub)
	     builds the bundle with Rojo itself (so the mapping is the project file's own) into Roblox Studio's content folder
	     and prints its name.
	  2. In Studio (command bar or the Studio tool):
	         local bundle = game:GetObjects("rbxasset://tlk_sync/<name>.rbxm")[1]
	         return loadstring(bundle.__Tools.SyncFromBundle.Source)()(bundle)

	WHAT IT DOES. The bundle is a Folder; each child is named by where it belongs ("ReplicatedStorage.Shared",
	"ServerScriptService.Server.World", ...). For every script in it: a script that is missing in the place is made, one
	whose text differs is given the new text, one whose text is the same is left alone. Every new text is checked first
	(`loadstring`): if any file does not compile NOTHING is written and the errors are returned.
	It NEVER deletes: a script in the place that is not on disk is only listed ("extra"), for a person to decide.
	The tools folder goes to `ServerStorage.TLK_Tools` (a folder no project file claims), so a tool can be run by name.

	WHY NOT THE DEV SERVER: since November 2026 a script run by the Studio assistant may only read a short list of web
	addresses, and 127.0.0.1 is not on it; a model file in Studio's own content folder needs no network at all.

	NOTE: a tool, not game code. Not synced by Rojo.
]]

return function(bundle: Instance): string
	local ServerStorage = game:GetService("ServerStorage")

	local function resolve(path: string, create: boolean): Instance?
		local at: Instance? = game
		for segment in string.gmatch(path, "[^.]+") do
			local parent = at :: Instance
			local nextOne = parent:FindFirstChild(segment)
			if not nextOne then
				if not create or parent == game then
					return nil
				end
				nextOne = Instance.new("Folder")
				nextOne.Name = segment
				nextOne.Parent = parent
			end
			at = nextOne
		end
		return at
	end

	-- 1. every text must compile before anything is touched
	local bad: { string } = {}
	local count = 0
	for _, d in bundle:GetDescendants() do
		if d:IsA("LuaSourceContainer") and not d:FindFirstAncestor("__Tools") then
			count += 1
			local chunk, err = loadstring((d :: any).Source, "=" .. d.Name)
			if not chunk then
				table.insert(bad, d:GetFullName() .. ": " .. tostring(err))
			end
		end
	end
	if #bad > 0 then
		return "NOT SYNCED, " .. #bad .. " file(s) do not compile:\n" .. table.concat(bad, "\n")
	end

	local created: { string } = {}
	local changed: { string } = {}
	local extra: { string } = {}
	local wrongClass: { string } = {}

	local function merge(from: Instance, into: Instance)
		for _, child in from:GetChildren() do
			local have = into:FindFirstChild(child.Name)
			if child:IsA("LuaSourceContainer") then
				if not have then
					local made = child:Clone()
					made.Parent = into
					table.insert(created, child.Name)
				elseif have.ClassName ~= child.ClassName then
					table.insert(wrongClass, have:GetFullName() .. " is a " .. have.ClassName .. ", the file is a " .. child.ClassName)
				elseif (have :: any).Source ~= (child :: any).Source then
					(have :: any).Source = (child :: any).Source
					table.insert(changed, child.Name)
				end
				if have and #child:GetChildren() > 0 then
					merge(child, have)
				end
			elseif child:IsA("Folder") then
				if not have then
					have = Instance.new("Folder")
					have.Name = child.Name
					have.Parent = into
				end
				merge(child, have :: Instance)
			end
		end
		for _, there in into:GetChildren() do
			if (there:IsA("LuaSourceContainer") or there:IsA("Folder")) and not from:FindFirstChild(there.Name) then
				table.insert(extra, there:GetFullName())
			end
		end
	end

	for _, root in bundle:GetChildren() do
		if root.Name == "__Tools" then
			local old = ServerStorage:FindFirstChild("TLK_Tools")
			if old then
				old:Destroy()
			end
			local tools = root:Clone()
			tools.Name = "TLK_Tools"
			tools.Parent = ServerStorage
		else
			local into = resolve(root.Name, true)
			if into then
				merge(root, into)
			else
				table.insert(wrongClass, "no place for " .. root.Name)
			end
		end
	end

	local lines = { ("%d scripts checked | created %d | changed %d"):format(count, #created, #changed) }
	if #created > 0 then
		table.insert(lines, "created: " .. table.concat(created, ", "))
	end
	if #changed > 0 then
		table.insert(lines, "changed: " .. table.concat(changed, ", "))
	end
	if #extra > 0 then
		table.insert(lines, "EXTRA in the place (not on disk, left alone): " .. table.concat(extra, ", "))
	end
	if #wrongClass > 0 then
		table.insert(lines, "PROBLEMS: " .. table.concat(wrongClass, "; "))
	end
	return table.concat(lines, "\n")
end
