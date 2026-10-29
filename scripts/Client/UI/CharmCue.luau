--!strict
--[[
	CharmCue
	The moment a worn charm does something you would otherwise not know about: a banner under the
	top of the screen with the charm's picture, what it did and one line, and a brief gold flash
	across the view. Today only the Mourner's Veil sends one ("THE VEIL HOLDS").

	It draws what it is told (a CharmEvent cue from Server/World/CharmService) and cleans up after
	itself. One at a time: a second replaces the first.

	Location: StarterPlayerScripts.Client.UI.CharmCue (a library).
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local ItemArt = require(script.Parent.ItemArt)

local CharmCue = {}

local HOLD_SECONDS = 3.4
local PICTURE = 72

export type Cue = { charm: string, title: string, line: string? }

local gui: ScreenGui? = nil
local current = 0

local function ensureGui(): ScreenGui
	local existing = gui
	if existing and existing.Parent then
		return existing
	end
	local created = Instance.new("ScreenGui")
	created.Name = "CharmCue"
	created.ResetOnSpawn = false
	created.IgnoreGuiInset = true
	created.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	created.DisplayOrder = 9
	created.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = created
	return created
end

function CharmCue.show(cue: Cue)
	local root = ensureGui()
	current += 1
	local mine = current
	for _, child in root:GetChildren() do
		child:Destroy()
	end

	-- the flash: a breath of gold over everything, then gone
	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Theme.Color.GoldBright
	flash.BackgroundTransparency = 0.78
	flash.BorderSizePixel = 0
	flash.Active = false
	flash.Parent = root
	TweenService:Create(flash, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()

	local banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0.16, -14)
	banner.Size = UDim2.new(0, 480, 0, PICTURE + 28)
	banner.BackgroundColor3 = Theme.Color.Ink
	banner.BackgroundTransparency = 1
	banner.Parent = root
	Theme.corner(banner)
	Theme.surface(banner, Theme.Color.Navy, Theme.Color.Void)
	local stroke = Theme.goldStroke(banner, 2)
	stroke.Transparency = 1
	Theme.padding(banner, 14)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(480, 400)
	limit.MinSize = Vector2.new(300, 0)
	limit.Parent = banner

	local picture = Instance.new("Frame")
	picture.Name = "Picture"
	picture.Size = UDim2.fromOffset(PICTURE, PICTURE)
	picture.BackgroundColor3 = Theme.Color.Void
	picture.BackgroundTransparency = 1
	picture.BorderSizePixel = 0
	picture.Parent = banner
	Theme.corner(picture, Theme.Size.CornerSmall)
	local art = ItemArt.mount(cue.charm, { Parent = picture, Size = UDim2.fromScale(1, 1), Zoom = 1.25 })
	art.ImageTransparency = 1

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Position = UDim2.fromOffset(PICTURE + 16, 4)
	title.Size = UDim2.new(1, -(PICTURE + 16), 0, 30)
	title.BackgroundTransparency = 1
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextSize = 26
	title.TextColor3 = Theme.Color.GoldBright
	title.TextTransparency = 1
	title.Text = cue.title
	title.Parent = banner
	Theme.applyFont(title, Theme.Role.Heading)

	local line = Instance.new("TextLabel")
	line.Name = "Line"
	line.Position = UDim2.fromOffset(PICTURE + 16, 38)
	line.Size = UDim2.new(1, -(PICTURE + 16), 1, -38)
	line.BackgroundTransparency = 1
	line.TextXAlignment = Enum.TextXAlignment.Left
	line.TextYAlignment = Enum.TextYAlignment.Top
	line.TextWrapped = true
	line.TextSize = 17
	line.TextColor3 = Theme.Color.Parchment
	line.TextTransparency = 1
	line.Text = cue.line or ""
	line.Parent = banner
	Theme.applyFont(line, Theme.Role.Body)

	-- in
	local into = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(banner, into, { BackgroundTransparency = 0.04, Position = UDim2.new(0.5, 0, 0.16, 0) }):Play()
	TweenService:Create(stroke, into, { Transparency = 0 }):Play()
	TweenService:Create(title, into, { TextTransparency = 0 }):Play()
	TweenService:Create(line, into, { TextTransparency = 0 }):Play()
	TweenService:Create(picture, into, { BackgroundTransparency = 0.2 }):Play()
	TweenService:Create(art, into, { ImageTransparency = 0 }):Play()

	-- out
	task.delay(HOLD_SECONDS, function()
		if current ~= mine or not banner.Parent then
			return
		end
		local out = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(banner, out, { BackgroundTransparency = 1, Position = UDim2.new(0.5, 0, 0.16, -10) }):Play()
		TweenService:Create(stroke, out, { Transparency = 1 }):Play()
		TweenService:Create(title, out, { TextTransparency = 1 }):Play()
		TweenService:Create(line, out, { TextTransparency = 1 }):Play()
		TweenService:Create(picture, out, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(art, out, { ImageTransparency = 1 }):Play()
		task.delay(0.65, function()
			if current == mine and banner.Parent then
				banner:Destroy()
			end
		end)
	end)
end

return CharmCue
