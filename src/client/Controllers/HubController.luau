--!nonstrict
-- HubController: a central tile-hub main menu. A "MENU" launcher (top-centre) opens a
-- dimmed overlay of big category tiles; picking a tile opens the matching dock panel via
-- DockController:Open(id). Lives in its own ScreenGui (DisplayOrder 20) so it layers above
-- WCBMain (the dock/panels at DisplayOrder 10) without per-element ZIndex juggling. The
-- dock stays for quick access; this is the richer, friendlier way to navigate.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Theme = require(script.Parent.Parent.UI.Theme)
local Components = require(script.Parent.Parent.UI.Components)

-- icon is a single ASCII letter on purpose (string.sub on accented labels splits UTF-8).
local TILES = {
	{
		id = "collection",
		label = "Cartes",
		sub = "Ta collection",
		icon = "C",
		color = Theme.color.accent,
		order = 10,
	},
	{
		id = "steal",
		label = "Voler",
		sub = "Pille tes rivaux",
		icon = "V",
		color = Color3.fromHex("FF4D6D"),
		order = 20,
	},
	{
		id = "fusion",
		label = "Fusion",
		sub = "Fusionne tes cartes",
		icon = "F",
		color = Color3.fromHex("B36BFF"),
		order = 30,
	},
	{
		id = "team",
		label = "Équipe",
		sub = "Gère ton onze",
		icon = "E",
		color = Theme.color.accent2,
		order = 40,
	},
	{
		id = "market",
		label = "Marché",
		sub = "Achète & vends",
		icon = "M",
		color = Color3.fromHex("FFA63F"),
		order = 50,
	},
	{
		id = "minigame",
		label = "Mini-jeux",
		sub = "Penalty & boss",
		icon = "J",
		color = Color3.fromHex("3B9DFF"),
		order = 60,
	},
	{
		id = "social",
		label = "Social",
		sub = "Amis & streak",
		icon = "S",
		color = Color3.fromHex("38E08B"),
		order = 70,
	},
	{
		id = "progression",
		label = "Progression",
		sub = "Niveaux & quêtes",
		icon = "P",
		color = Color3.fromHex("FFB23F"),
		order = 80,
	},
}

local HubController = Knit.CreateController({
	Name = "HubController",
	_overlay = nil,
	_panel = nil,
	_baseSize = UDim2.fromScale(0.66, 0.76),
	_open = false,
})

local function shrink(size: UDim2): UDim2
	return UDim2.fromScale(size.X.Scale * 0.92, size.Y.Scale * 0.92)
end

-- Build one big category tile (a clickable card with icon disc, label, subtitle).
local function makeTile(parent: Instance, def, onPick)
	local tile = Components.create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.color.surfaceAlt,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(240, 128),
		LayoutOrder = def.order,
		Parent = parent,
	}, {
		Components.corner(Theme.radius.lg),
		Components.stroke(def.color, 2),
	})

	Components.create("Frame", {
		Name = "Accent",
		Size = UDim2.new(0, 6, 1, -24),
		Position = UDim2.fromOffset(0, 12),
		BackgroundColor3 = def.color,
		BorderSizePixel = 0,
		Parent = tile,
	}, { Components.corner(Theme.radius.pill) })

	Components.create("TextLabel", {
		Name = "Icon",
		Text = def.icon,
		Font = Theme.font.display,
		TextSize = Theme.text.xl,
		TextColor3 = Theme.color.bg,
		BackgroundColor3 = def.color,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(56, 56),
		Position = UDim2.fromOffset(20, 20),
		Parent = tile,
	}, { Components.corner(Theme.radius.md) })

	Components.Label(def.label, {
		Parent = tile,
		Position = UDim2.fromOffset(90, 24),
		Size = UDim2.new(1, -104, 0, 30),
		Font = Theme.font.display,
		TextSize = Theme.text.lg,
	})
	Components.Label(def.sub, {
		Parent = tile,
		Position = UDim2.fromOffset(90, 58),
		Size = UDim2.new(1, -104, 0, 20),
		dim = true,
		TextSize = Theme.text.sm,
	})

	local base = Theme.color.surfaceAlt
	local hover = base:Lerp(Color3.new(1, 1, 1), 0.08)
	tile.MouseEnter:Connect(function()
		TweenService:Create(tile, TweenInfo.new(0.12), { BackgroundColor3 = hover }):Play()
	end)
	tile.MouseLeave:Connect(function()
		TweenService:Create(tile, TweenInfo.new(0.12), { BackgroundColor3 = base }):Play()
	end)
	tile.MouseButton1Click:Connect(onPick)
end

function HubController:_openHub()
	self._open = true
	self._overlay.Visible = true
	self._overlay.BackgroundTransparency = 1
	TweenService:Create(self._overlay, TweenInfo.new(0.2), { BackgroundTransparency = 0.45 }):Play()
	self._panel.Size = shrink(self._baseSize)
	TweenService:Create(
		self._panel,
		TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = self._baseSize }
	):Play()
end

function HubController:_closeHub()
	self._open = false
	TweenService:Create(self._overlay, TweenInfo.new(0.16), { BackgroundTransparency = 1 }):Play()
	local collapse =
		TweenService:Create(self._panel, TweenInfo.new(0.16), { Size = shrink(self._baseSize) })
	collapse.Completed:Connect(function()
		if not self._open then
			self._overlay.Visible = false
		end
	end)
	collapse:Play()
end

function HubController:_toggle()
	if self._open then
		self:_closeHub()
	else
		self:_openHub()
	end
end

function HubController:KnitStart()
	local Dock = Knit.GetController("DockController")
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local gui = Components.create("ScreenGui", {
		Name = "WCBHub",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 20,
		Parent = playerGui,
	})

	-- Launcher (top-centre, clear of the Roblox menu button + HUD + dock).
	Components.Button({
		text = "MENU",
		variant = "primary",
		Size = UDim2.fromOffset(140, 42),
		Position = UDim2.new(0.5, 0, 0, 8),
		Parent = gui,
		onClick = function()
			self:_toggle()
		end,
	}).AnchorPoint =
		Vector2.new(0.5, 0)

	-- Dimmer (click outside the panel to close).
	local overlay = Components.create("TextButton", {
		Name = "Overlay",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.color.overlay,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = gui,
	})
	overlay.MouseButton1Click:Connect(function()
		self:_closeHub()
	end)
	self._overlay = overlay

	local panel = Components.Panel({ Size = self._baseSize, Parent = overlay })
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Active = true -- swallow clicks so the dimmer only fires outside the panel
	Components.create("UISizeConstraint", {
		MinSize = Vector2.new(360, 420),
		MaxSize = Vector2.new(840, 660),
		Parent = panel,
	})
	Components.padding(Theme.pad.lg).Parent = panel
	self._panel = panel

	Components.Heading("Menu principal", {
		Parent = panel,
		Size = UDim2.new(1, -48, 0, 38),
	})
	Components.Label("Choisis une activité", {
		Parent = panel,
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, -48, 0, 22),
		dim = true,
	})
	Components.Button({
		text = "X",
		variant = "ghost",
		Size = UDim2.fromOffset(36, 36),
		Position = UDim2.new(1, -36, 0, 0),
		Parent = panel,
		onClick = function()
			self:_closeHub()
		end,
	})

	local grid = Components.Grid({
		Parent = panel,
		Position = UDim2.fromOffset(0, 76),
		Size = UDim2.new(1, 0, 1, -76),
		cell = Vector2.new(240, 128),
		gap = Theme.pad.md,
	})

	for _, def in TILES do
		makeTile(grid, def, function()
			self:_closeHub()
			Dock:Open(def.id)
		end)
	end
end

function HubController:KnitInit() end

return HubController
