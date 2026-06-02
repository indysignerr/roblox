--!nonstrict
-- HudController: persistent top bar showing coins and shield status. Read-only — it
-- reflects DataService state (initial GetProfile + the Updated signal) and ticks the
-- shield countdown locally. Reactivating the shield lives in StealController, not here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Theme = require(script.Parent.Parent.UI.Theme)
local Components = require(script.Parent.Parent.UI.Components)

local HudController = Knit.CreateController({
	Name = "HudController",
	_data = nil, -- latest ProfileData snapshot
	_coinsLabel = nil,
	_shieldDot = nil,
	_shieldLabel = nil,
})

-- Build one rounded pill (coloured dot + text). Returns { dot, label }.
local function pill(parent: Instance, dotColor: Color3, order: number)
	local frame = Components.create("Frame", {
		BackgroundColor3 = Theme.color.surface,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, 36),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = order,
		Parent = parent,
	}, {
		Components.corner(Theme.radius.pill),
		Components.stroke(),
		Components.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, Theme.pad.sm),
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Components.create("UIPadding", {
			PaddingLeft = UDim.new(0, Theme.pad.md),
			PaddingRight = UDim.new(0, Theme.pad.md),
		}),
	})
	local dot = Components.create("Frame", {
		BackgroundColor3 = dotColor,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(12, 12),
		LayoutOrder = 1,
		Parent = frame,
	}, { Components.corner(Theme.radius.pill) })
	local label = Components.create("TextLabel", {
		Text = "",
		Font = Theme.font.bodyBold,
		TextSize = Theme.text.md,
		TextColor3 = Theme.color.text,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 20),
		LayoutOrder = 2,
		Parent = frame,
	})
	return { dot = dot, label = label }
end

local function formatRemaining(seconds: number): string
	if seconds <= 0 then
		return "Off"
	elseif seconds >= 3600 then
		return string.format("%dh", math.floor(seconds / 3600))
	elseif seconds >= 60 then
		return string.format("%dm", math.floor(seconds / 60))
	end
	return string.format("%ds", math.floor(seconds))
end

function HudController:_refreshCoins()
	if self._data then
		self._coinsLabel.Text = tostring(self._data.coins or 0)
	end
end

function HudController:_refreshShield()
	local shield = self._data and self._data.shield
	local remaining = 0
	if shield and shield.active and shield.expiresAt then
		remaining = shield.expiresAt - os.time()
	end
	if remaining > 0 then
		self._shieldDot.BackgroundColor3 = Theme.color.success
		self._shieldLabel.Text = "Shield " .. formatRemaining(remaining)
		self._shieldLabel.TextColor3 = Theme.color.text
	else
		self._shieldDot.BackgroundColor3 = Theme.color.stroke
		self._shieldLabel.Text = "No shield"
		self._shieldLabel.TextColor3 = Theme.color.textDim
	end
end

function HudController:KnitStart()
	local Dock = Knit.GetController("DockController")
	local gui = Dock:GetGui()

	local bar = Components.create("Frame", {
		Name = "Hud",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.fromOffset(0, 36),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = gui,
	}, {
		Components.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, Theme.pad.sm),
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local coins = pill(bar, Theme.color.accent, 1)
	self._coinsLabel = coins.label
	local shield = pill(bar, Theme.color.stroke, 2)
	self._shieldDot = shield.dot
	self._shieldLabel = shield.label

	local Data = Knit.GetService("DataService")
	Data.Updated:Connect(function(data)
		self._data = data
		self:_refreshCoins()
		self:_refreshShield()
	end)
	Data:GetProfile()
		:andThen(function(data)
			if data then
				self._data = data
				self:_refreshCoins()
				self:_refreshShield()
			end
		end)
		:catch(function() end)

	-- Tick the shield countdown once a second.
	task.spawn(function()
		while true do
			task.wait(1)
			self:_refreshShield()
		end
	end)
end

function HudController:KnitInit() end

return HudController
