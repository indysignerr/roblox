--!nonstrict
-- DockController: owns the single root ScreenGui ("WCBMain"), the bottom launcher dock,
-- and a panel registry. Every feature panel registers itself here and is handed a
-- pre-styled, hidden content Frame to populate. One panel open at a time; clicking the
-- dimmed backdrop (or the panel's X) closes it.
--
-- ── Public API (call from another controller's KnitInit) ─────────────────────
--   DockController:Register({
--     id    = "collection",            -- unique key
--     label = "Cards",                 -- dock button text
--     order = 10,                      -- dock sort (lower = further left); optional
--     build = function(content) end,   -- ONCE, after Knit starts: populate `content`
--     onOpen = function() end,         -- optional: each time the panel opens (refresh)
--   })
--   DockController:Open(id) / :Close() / :Toggle(id)
--   DockController:GetGui() -> ScreenGui          (HUD / toasts parent here)
--   DockController:Toast(text, color?)            convenience over Components.Toast
--
-- Lifecycle contract: panels call :Register in their KnitInit (all KnitInits finish
-- before any KnitStart, so every registration is visible when we build in KnitStart;
-- building there means panel `build`/`onOpen` callbacks may safely Knit.GetService()).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Theme = require(script.Parent.Parent.UI.Theme)
local Components = require(script.Parent.Parent.UI.Components)

local DockController = Knit.CreateController({
	Name = "DockController",

	_gui = nil, -- ScreenGui
	_backdrop = nil, -- TextButton (click-outside-to-close)
	_panelHost = nil, -- Frame holding all panels
	_dock = nil, -- Frame holding launcher buttons
	_registered = {}, -- { config }  (insertion order; sorted by .order at build)
	_panels = {}, -- [id] = { content, panel, button, onOpen }
	_active = nil :: string?, -- currently open panel id
	_started = false,
})

-- ── GUI construction (idempotent; safe to call from any KnitInit) ─────────────

function DockController:_ensureGui()
	if self._gui then
		return
	end

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local gui = Components.create("ScreenGui", {
		Name = "WCBMain",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10,
		Parent = playerGui,
	})
	self._gui = gui

	-- Dimmed backdrop behind the active panel; clicking it closes (ZIndex 1, lowest).
	local backdrop = Components.create("TextButton", {
		Name = "Backdrop",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.color.overlay,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 1,
		Parent = gui,
	})
	backdrop.MouseButton1Click:Connect(function()
		self:Close()
	end)
	self._backdrop = backdrop

	-- Centred host that holds every panel (one visible at a time).
	local panelHost = Components.create("Frame", {
		Name = "PanelHost",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.47),
		Size = UDim2.fromScale(0.6, 0.72),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 2,
		Parent = gui,
	}, {
		Components.create("UISizeConstraint", {
			MinSize = Vector2.new(320, 360),
			MaxSize = Vector2.new(880, 620),
		}),
	})
	self._panelHost = panelHost
	-- Drives the open/close pop (scales about the host's centred anchor).
	self._hostScale = Components.create("UIScale", { Scale = 1, Parent = panelHost })

	-- Bottom dock of launcher buttons (ZIndex 3 → always above the panel host).
	local dock = Components.create("Frame", {
		Name = "Dock",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(0, 52),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.color.surface,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = gui,
	}, {
		Components.corner(Theme.radius.pill),
		Components.stroke(),
		Components.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, Theme.pad.sm),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Components.create("UIPadding", {
			PaddingLeft = UDim.new(0, Theme.pad.sm),
			PaddingRight = UDim.new(0, Theme.pad.sm),
			PaddingTop = UDim.new(0, Theme.pad.xs),
			PaddingBottom = UDim.new(0, Theme.pad.xs),
		}),
	})
	self._dock = dock
end

-- Build the styled panel shell (header + close + content area) for one registration.
-- Returns the content Frame the panel populates.
function DockController:_buildPanelShell(config): Frame
	local panel = Components.Panel({
		Size = UDim2.fromScale(1, 1),
		Parent = self._panelHost,
	})
	panel.Visible = false
	panel.Name = "Panel_" .. config.id
	Components.padding(Theme.pad.lg).Parent = panel

	Components.Heading(config.label or config.id, {
		Size = UDim2.new(1, -44, 0, 34),
		Parent = panel,
	})

	Components.Button({
		text = "X",
		variant = "ghost",
		Size = UDim2.fromOffset(34, 34),
		Position = UDim2.new(1, -34, 0, 0),
		Parent = panel,
		onClick = function()
			self:Close()
		end,
	})

	local content = Components.create("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 1, -44),
		BackgroundTransparency = 1,
		Parent = panel,
	})

	return panel, content
end

-- ── Registration ─────────────────────────────────────────────────────────────

function DockController:Register(config)
	assert(config and config.id, "DockController:Register needs a config with an id")
	self:_ensureGui()

	table.insert(self._registered, config)

	-- If Knit already started (late registration), build immediately so it still works.
	if self._started then
		self:_materialize(config)
		self:_rebuildDock()
	end
end

-- Create the panel shell + dock button for a single config and run its build() once.
function DockController:_materialize(config)
	if self._panels[config.id] then
		return
	end

	local panel, content = self:_buildPanelShell(config)

	local button = Components.Button({
		text = config.label or config.id,
		variant = "secondary",
		Size = UDim2.fromOffset(96, 40),
		LayoutOrder = config.order or 100,
		Parent = self._dock,
		onClick = function()
			self:Toggle(config.id)
		end,
	})

	self._panels[config.id] = {
		panel = panel,
		content = content,
		button = button,
		onOpen = config.onOpen,
	}

	local ok, err = pcall(config.build, content)
	if not ok then
		warn("[DockController] panel '" .. config.id .. "' build failed: " .. tostring(err))
	end
end

-- Re-sort dock buttons by their registered order.
function DockController:_rebuildDock()
	table.sort(self._registered, function(a, b)
		return (a.order or 100) < (b.order or 100)
	end)
	for index, config in self._registered do
		local entry = self._panels[config.id]
		if entry then
			entry.button.LayoutOrder = index
		end
	end
end

-- ── Open / close ─────────────────────────────────────────────────────────────

function DockController:Open(id: string)
	local entry = self._panels[id]
	if not entry then
		return
	end
	local wasOpen = self._panelHost.Visible
	-- Hide any currently-open panel + de-highlight its button.
	if self._active and self._panels[self._active] then
		self._panels[self._active].panel.Visible = false
		self._panels[self._active].button.BackgroundColor3 = Theme.color.surfaceAlt
	end

	self._active = id
	entry.panel.Visible = true
	entry.button.BackgroundColor3 = Theme.color.accent
	self._panelHost.Visible = true
	self._backdrop.Visible = true

	-- Fade the backdrop in only on a fresh open; pop the host on every open for feedback.
	if not wasOpen then
		self._backdrop.BackgroundTransparency = 1
		TweenService:Create(self._backdrop, TweenInfo.new(0.18), { BackgroundTransparency = 0.45 })
			:Play()
	end
	self._hostScale.Scale = 0.96
	TweenService:Create(
		self._hostScale,
		TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()

	if entry.onOpen then
		local ok, err = pcall(entry.onOpen)
		if not ok then
			warn("[DockController] panel '" .. id .. "' onOpen failed: " .. tostring(err))
		end
	end
end

function DockController:Close()
	if self._active and self._panels[self._active] then
		self._panels[self._active].panel.Visible = false
		self._panels[self._active].button.BackgroundColor3 = Theme.color.surfaceAlt
	end
	self._active = nil
	TweenService:Create(self._backdrop, TweenInfo.new(0.16), { BackgroundTransparency = 1 }):Play()
	local collapse = TweenService:Create(self._hostScale, TweenInfo.new(0.16), { Scale = 0.96 })
	collapse.Completed:Connect(function()
		-- Skip hiding if the player re-opened during the collapse.
		if not self._active then
			self._panelHost.Visible = false
			self._backdrop.Visible = false
		end
	end)
	collapse:Play()
end

function DockController:Toggle(id: string)
	if self._active == id then
		self:Close()
	else
		self:Open(id)
	end
end

-- ── Helpers for other controllers ────────────────────────────────────────────

function DockController:GetGui(): ScreenGui
	self:_ensureGui()
	return self._gui
end

function DockController:Toast(text: string, color: Color3?)
	self:_ensureGui()
	Components.Toast(self._gui, text, color)
end

-- ── Lifecycle ────────────────────────────────────────────────────────────────

function DockController:KnitInit()
	self:_ensureGui()
end

function DockController:KnitStart()
	-- All panels have registered (registrations happen in KnitInit). Build them now,
	-- after Knit has started, so panel callbacks can safely Knit.GetService().
	table.sort(self._registered, function(a, b)
		return (a.order or 100) < (b.order or 100)
	end)
	for _, config in self._registered do
		self:_materialize(config)
	end
	self:_rebuildDock()
	self._started = true
end

return DockController
