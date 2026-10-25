--!strict
--[[
	EndingUi
	The screen that closes on the end of the run: the world goes dark over a couple of seconds, the title
	comes up in gold, then a few lines, one at a time, each held long enough to read and let go, and last of
	all a small line in a quiet colour ("To be continued"). Nothing to press: it is the end, and it is gone
	when the party is taken back to the Hub.

	Plain on purpose, the same restraint as the parchment page: black, serif, gold only for the name of the
	game. It is the one place in the run where the player should do nothing but read.

	Location: StarterPlayerScripts.Client.UI.EndingUi (a library).
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local EndingUi = {}

export type Payload = { title: string?, subtitle: string?, lines: { string }?, footer: string? }

function EndingUi.play(payload: Payload)
	local gui = Instance.new("ScreenGui")
	gui.Name = "EndingUi"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 100
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local veil = Instance.new("Frame")
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	veil.BackgroundTransparency = 1
	veil.BorderSizePixel = 0
	veil.Parent = gui
	TweenService:Create(veil, TweenInfo.new(2.6, Enum.EasingStyle.Sine), { BackgroundTransparency = 0 }):Play()

	local function label(text: string, size: number, color: Color3, role: string, y: number, height: number): TextLabel
		local l = Instance.new("TextLabel")
		l.AnchorPoint = Vector2.new(0.5, 0)
		l.Position = UDim2.new(0.5, 0, y, 0)
		l.Size = UDim2.new(0.8, 0, 0, height)
		l.BackgroundTransparency = 1
		l.Text = text
		l.TextSize = size
		l.TextColor3 = color
		l.TextTransparency = 1
		l.TextWrapped = true
		l.Parent = gui
		Theme.applyFont(l, role)
		return l
	end

	local function show(l: TextLabel, seconds: number)
		TweenService:Create(l, TweenInfo.new(seconds), { TextTransparency = 0 }):Play()
	end
	local function hide(l: TextLabel, seconds: number)
		TweenService:Create(l, TweenInfo.new(seconds), { TextTransparency = 1 }):Play()
	end

	task.spawn(function()
		task.wait(3)
		local title = label(payload.title or "The Last Kingdom", 58, Theme.Color.GoldBright, Theme.Role.Heading, 0.3, 80)
		show(title, 2.4)
		if payload.subtitle then
			task.wait(1.2)
			local sub = label(payload.subtitle, 28, Theme.Color.Gold, Theme.Role.Body, 0.3, 40)
			sub.Position = UDim2.new(0.5, 0, 0.3, 82)
			show(sub, 2)
		end
		task.wait(4)
		hide(title, 1.6)
		for _, child in gui:GetChildren() do
			if child:IsA("TextLabel") and child ~= title then
				hide(child, 1.6)
			end
		end
		task.wait(2)
		for _, text in payload.lines or {} do
			local l = label(text, 30, Color3.fromRGB(226, 214, 188), Theme.Role.Body, 0.42, 120)
			show(l, 1.6)
			task.wait(math.max(3.6, #text / 14))
			hide(l, 1.4)
			task.wait(1.6)
			l:Destroy()
		end
		if payload.footer then
			local f = label(payload.footer, 24, Color3.fromRGB(150, 138, 118), Theme.Role.Body, 0.5, 40)
			show(f, 2.6)
		end
	end)
end

return EndingUi
