--[[
	WidenUndead — run in the FORGOTTEN LANDS place, in EDIT MODE.
	Makes the bodies of the dead a little WIDER (not taller): every part of every master in
	`ServerStorage.Assets.Undead` gets thicker by `WIDTH` (1.07 = 7%) so that the eyes, the helmet and the clothes read
	better at a distance (the developer asked for 5 to 10%, 2026-10-31).

	HOW. In the body's rest pose (the one `tools/BuildUndead` bakes into the joints):
	  - the body is stretched sideways and front to back about its own vertical axis: a part's centre moves out from
	    the middle by WIDTH in x and z, and not at all in y, so nothing gets taller and the feet stay on the ground;
	  - each part is thickened along the sides of it that point sideways. A limb hanging down is thickened across,
	    not along; a torso leaning forward a little less so. A BALL gets the same growth all round (about 5%);
	  - the joints are re-written: a Motor6D's C0 is worked out again from where the two parts now are, with C1 left
	    alone, so every pose and every clip turns about the same point on the limb as before;
	  - the welds that hold helmets, plates and weapons are switched off while this is done and on again after, so they
	    take up their new places and do not drag the parts about;
	  - HumanoidRootPart (the invisible 2 x 5 x 1 box the AI moves and the hits are taken from) is left as it is.

	A master that has been widened carries the attribute `BodyWidth`; running this again leaves it alone. To change
	the number, rebuild the bodies (`tools/BuildUndead.luau`) and run this again. It checks every joint before and after
	and skips a body whose joints do not agree with its parts.

	NOTE: a tool, not game code. Not synced by Rojo. The result lives in the place (ServerStorage.Assets.Undead).
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ServerStorage = game:GetService("ServerStorage")

local WIDTH = 1.07

local folder = ServerStorage.Assets:FindFirstChild("Undead")
assert(folder, "ServerStorage.Assets.Undead is not there")

local function jointError(model: Model): number
	local worst = 0
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and d.Part0 and d.Part1 then
			local want = d.Part0.CFrame * d.C0 * d.C1:Inverse()
			local off = (want.Position - d.Part1.Position).Magnitude
			worst = math.max(worst, off)
		end
	end
	return worst
end

local function widen(model: Model, k: number): (boolean, string)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return false, "no HumanoidRootPart"
	end
	local before = jointError(model)
	if before > 0.05 then
		return false, ("its joints do not agree with its parts (%.3f studs off): left alone"):format(before)
	end
	local centre = root.Position

	-- the welds off, so that moving a part does not move the things welded to it
	local welds: { WeldConstraint } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("WeldConstraint") then
			table.insert(welds, d)
			d.Enabled = false
		end
	end

	local count = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			local cf = d.CFrame
			local rot = cf - cf.Position
			local fx, fy, fz
			if d:IsA("Part") and d.Shape == Enum.PartType.Ball then
				local all = 1 + (k - 1) * 0.8
				fx, fy, fz = all, all, all
			else
				local function factor(axis: Vector3): number
					local dir = rot:VectorToWorldSpace(axis)
					local horizontal = math.sqrt(math.max(0, 1 - dir.Y * dir.Y))
					return 1 + (k - 1) * horizontal
				end
				fx, fy, fz = factor(Vector3.xAxis), factor(Vector3.yAxis), factor(Vector3.zAxis)
			end
			local at = cf.Position
			local newAt = Vector3.new(centre.X + k * (at.X - centre.X), at.Y, centre.Z + k * (at.Z - centre.Z))
			d.Size = Vector3.new(d.Size.X * fx, d.Size.Y * fy, d.Size.Z * fz)
			d.CFrame = CFrame.new(newAt) * rot
			for _, a in d:GetChildren() do
				if a:IsA("Attachment") then
					a.Position = Vector3.new(a.Position.X * fx, a.Position.Y * fy, a.Position.Z * fz)
				end
			end
			count += 1
		end
	end

	-- the joints, from where the parts now are
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and d.Part0 and d.Part1 then
			d.C0 = d.Part0.CFrame:Inverse() * d.Part1.CFrame * d.C1
		end
	end
	for _, w in welds do
		w.Enabled = true
	end
	model:SetAttribute("BodyWidth", k)
	return true, ("%d parts, joints off by %.3f studs"):format(count, jointError(model))
end

local recording = ChangeHistoryService:TryBeginRecording("WidenUndead")
local report = {}
for _, master in folder:GetChildren() do
	if master:IsA("Model") then
		if master:GetAttribute("BodyWidth") then
			table.insert(report, master.Name .. ": already widened to " .. tostring(master:GetAttribute("BodyWidth")))
		else
			local _, before = master:GetBoundingBox()
			local ok, why = widen(master, WIDTH)
			local _, after = master:GetBoundingBox()
			table.insert(report, ("%s: %s (%s); size %.2f x %.2f x %.2f -> %.2f x %.2f x %.2f"):format(master.Name, if ok then "widened" else "SKIPPED", why, before.X, before.Y, before.Z, after.X, after.Y, after.Z))
		end
	end
end
if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
print("[WidenUndead]\n" .. table.concat(report, "\n"))
return report
