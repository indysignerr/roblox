--!nonstrict
-- WorldService: builds the entire stadium map at runtime (the project has no Workspace
-- mapping, so all geometry is code-generated). Stylized "stadium at night" to match the
-- UI theme. Produces: striped pitch + markings, 4 tiered stands, 2 goals with nets, 2
-- coach benches, a locker-room tunnel with player spawn, a conveyor "tapis" that parades
-- brainrot-footballer cards from the tunnel onto the pitch, floodlights, and 8 physical
-- kiosks (bornes). Each kiosk carries a `WCBPanel` attribute + ProximityPrompt; the client
-- WorldController turns a triggered prompt into DockController:Open(panelId).
--
-- Server can't require the client Theme (different tree) so the palette is hardcoded here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Cards = require(ReplicatedStorage.Shared.Config.Cards)

local WorldService = Knit.CreateService({
	Name = "WorldService",
})

-- ── Palette (mirrors src/client/UI/Theme.luau) ───────────────────────────────
local C = {
	grassDark = Color3.fromRGB(34, 94, 50),
	grassLight = Color3.fromRGB(44, 116, 60),
	line = Color3.fromHex("F5F7FA"),
	surface = Color3.fromHex("1A1F29"),
	surfaceAlt = Color3.fromHex("232A36"),
	stroke = Color3.fromHex("313A49"),
	accent = Color3.fromHex("FFD23F"),
	accent2 = Color3.fromHex("2EE6A6"),
	text = Color3.fromHex("F5F7FA"),
	dark = Color3.fromHex("0E1116"),
	post = Color3.fromHex("F5F7FA"),
}

local RARITY = {
	Common = Color3.fromHex("9AA7B8"),
	Uncommon = Color3.fromHex("4CD964"),
	Rare = Color3.fromHex("3B9DFF"),
	Epic = Color3.fromHex("B36BFF"),
	Legendary = Color3.fromHex("FFB23F"),
	Mythic = Color3.fromHex("FF4D6D"),
}

local KIOSKS = {
	{ id = "collection", label = "Cartes", color = C.accent, pos = Vector3.new(-16, 0, 38) },
	{
		id = "steal",
		label = "Voler",
		color = Color3.fromHex("FF4D6D"),
		pos = Vector3.new(16, 0, 38),
	},
	{
		id = "fusion",
		label = "Fusion",
		color = Color3.fromHex("B36BFF"),
		pos = Vector3.new(-66, 0, 20),
	},
	{ id = "team", label = "Équipe", color = C.accent2, pos = Vector3.new(-66, 0, -20) },
	{
		id = "market",
		label = "Marché",
		color = Color3.fromHex("FFA63F"),
		pos = Vector3.new(66, 0, 20),
	},
	{
		id = "minigame",
		label = "Mini-jeux",
		color = Color3.fromHex("3B9DFF"),
		pos = Vector3.new(66, 0, -20),
	},
	{
		id = "social",
		label = "Social",
		color = Color3.fromHex("38E08B"),
		pos = Vector3.new(-18, 0, -46),
	},
	{
		id = "progression",
		label = "Progression",
		color = Color3.fromHex("FFB23F"),
		pos = Vector3.new(18, 0, -46),
	},
}

-- ── Instance helpers ─────────────────────────────────────────────────────────

local function mk(className, props, children)
	local inst = Instance.new(className)
	local parent = props.Parent
	props.Parent = nil
	for k, v in props do
		inst[k] = v
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function newPart(props, children)
	if props.Anchored == nil then
		props.Anchored = true
	end
	if props.Material == nil then
		props.Material = Enum.Material.SmoothPlastic
	end
	if props.TopSurface == nil then
		props.TopSurface = Enum.SurfaceType.Smooth
	end
	if props.BottomSurface == nil then
		props.BottomSurface = Enum.SurfaceType.Smooth
	end
	return mk("Part", props, children)
end

-- ── Pitch + markings ─────────────────────────────────────────────────────────

local function buildPitch(parent)
	local stripes = 10
	local stripeW = 140 / stripes
	for i = 0, stripes - 1 do
		newPart({
			Name = "Turf",
			Material = Enum.Material.Grass,
			Color = (i % 2 == 0) and C.grassDark or C.grassLight,
			Size = Vector3.new(stripeW, 1, 90),
			CFrame = CFrame.new(-70 + stripeW / 2 + i * stripeW, -0.5, 0),
			Parent = parent,
		})
	end

	local function lineBar(size, pos)
		newPart({
			Name = "Line",
			Material = Enum.Material.SmoothPlastic,
			Color = C.line,
			Size = size,
			CFrame = CFrame.new(pos),
			CanCollide = false,
			Parent = parent,
		})
	end

	-- boundary rectangle
	lineBar(Vector3.new(140, 0.1, 0.5), Vector3.new(0, 0.06, 44.5))
	lineBar(Vector3.new(140, 0.1, 0.5), Vector3.new(0, 0.06, -44.5))
	lineBar(Vector3.new(0.5, 0.1, 90), Vector3.new(69.5, 0.06, 0))
	lineBar(Vector3.new(0.5, 0.1, 90), Vector3.new(-69.5, 0.06, 0))
	-- halfway line
	lineBar(Vector3.new(0.5, 0.1, 90), Vector3.new(0, 0.06, 0))

	-- centre circle (white disc with grass disc on top -> ring)
	newPart({
		Name = "CircleOuter",
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.SmoothPlastic,
		Color = C.line,
		Size = Vector3.new(0.2, 20, 20),
		CFrame = CFrame.new(0, 0.06, 0) * CFrame.Angles(0, 0, math.rad(90)),
		CanCollide = false,
		Parent = parent,
	})
	newPart({
		Name = "CircleInner",
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Grass,
		Color = C.grassDark,
		Size = Vector3.new(0.22, 17, 17),
		CFrame = CFrame.new(0, 0.07, 0) * CFrame.Angles(0, 0, math.rad(90)),
		CanCollide = false,
		Parent = parent,
	})
	newPart({
		Name = "CentreSpot",
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.SmoothPlastic,
		Color = C.line,
		Size = Vector3.new(0.2, 1.4, 1.4),
		CFrame = CFrame.new(0, 0.08, 0) * CFrame.Angles(0, 0, math.rad(90)),
		CanCollide = false,
		Parent = parent,
	})

	-- penalty boxes (3 bars each; the goal line is the 4th side)
	for _, s in { 1, -1 } do
		lineBar(Vector3.new(0.5, 0.1, 44), Vector3.new(s * 51.5, 0.06, 0))
		lineBar(Vector3.new(18, 0.1, 0.5), Vector3.new(s * 60.5, 0.06, 22))
		lineBar(Vector3.new(18, 0.1, 0.5), Vector3.new(s * 60.5, 0.06, -22))
	end
end

-- ── Goals ────────────────────────────────────────────────────────────────────

local function buildGoal(parent, s)
	local model = mk("Model", { Name = "Goal" })
	local lineX = s * 69.5
	local function post(props)
		props.Material = Enum.Material.SmoothPlastic
		props.Color = C.post
		props.Parent = model
		newPart(props)
	end
	post({ Name = "PostL", Size = Vector3.new(1, 8, 1), CFrame = CFrame.new(lineX, 4, -12) })
	post({ Name = "PostR", Size = Vector3.new(1, 8, 1), CFrame = CFrame.new(lineX, 4, 12) })
	post({ Name = "Crossbar", Size = Vector3.new(1, 1, 25), CFrame = CFrame.new(lineX, 8, 0) })
	-- net (force-field panels read as a shimmering goal net)
	local function net(props)
		props.Material = Enum.Material.ForceField
		props.Color = C.line
		props.Transparency = 0.4
		props.CanCollide = false
		props.Parent = model
		newPart(props)
	end
	net({ Name = "NetBack", Size = Vector3.new(1, 8, 25), CFrame = CFrame.new(lineX + s * 6, 4, 0) })
	net({
		Name = "NetTop",
		Size = Vector3.new(6, 0.4, 25),
		CFrame = CFrame.new(lineX + s * 3, 8, 0),
	})
	net({
		Name = "NetSideL",
		Size = Vector3.new(6, 8, 1),
		CFrame = CFrame.new(lineX + s * 3, 4, -12),
	})
	net({
		Name = "NetSideR",
		Size = Vector3.new(6, 8, 1),
		CFrame = CFrame.new(lineX + s * 3, 4, 12),
	})
	model.Parent = parent
end

-- ── Stands (tiered, in local space: rows recede -Z and rise +Y) ───────────────

local function buildStand(parent, baseCFrame, length, rows)
	local model = mk("Model", { Name = "Stand" })
	for i = 1, rows do
		local y = 1.2 + (i - 1) * 2.2
		local z = -(i - 1) * 4
		newPart({
			Name = "Row",
			Material = Enum.Material.Concrete,
			Color = C.surfaceAlt,
			Size = Vector3.new(length, 2.4, 4),
			CFrame = baseCFrame * CFrame.new(0, y, z),
			Parent = model,
		})
		newPart({
			Name = "Seats",
			Material = Enum.Material.SmoothPlastic,
			Color = (i % 2 == 0) and C.accent or C.accent2,
			Size = Vector3.new(length, 0.5, 1.4),
			CFrame = baseCFrame * CFrame.new(0, y + 1.45, z + 1.2),
			Parent = model,
		})
	end
	local backH = 1.2 + (rows - 1) * 2.2 + 5
	newPart({
		Name = "Back",
		Material = Enum.Material.Concrete,
		Color = C.surface,
		Size = Vector3.new(length + 4, backH, 1),
		CFrame = baseCFrame * CFrame.new(0, backH / 2, -(rows - 1) * 4 - 3),
		Parent = model,
	})
	model.Parent = parent
end

-- ── Coach benches (dugouts) ──────────────────────────────────────────────────

local function buildBench(parent, x)
	local model = mk("Model", { Name = "Bench" })
	local baseZ = -49
	newPart({
		Name = "Floor",
		Material = Enum.Material.Concrete,
		Color = C.surface,
		Size = Vector3.new(16, 0.4, 5),
		CFrame = CFrame.new(x, 0.2, baseZ),
		Parent = model,
	})
	newPart({
		Name = "Seat",
		Material = Enum.Material.SmoothPlastic,
		Color = C.accent,
		Size = Vector3.new(15, 1, 1.4),
		CFrame = CFrame.new(x, 1.2, baseZ - 1.4),
		Parent = model,
	})
	newPart({
		Name = "Canopy",
		Material = Enum.Material.SmoothPlastic,
		Color = C.surfaceAlt,
		Transparency = 0.25,
		Size = Vector3.new(16, 0.4, 6),
		CFrame = CFrame.new(x, 4.4, baseZ - 0.5) * CFrame.Angles(math.rad(-12), 0, 0),
		Parent = model,
	})
	for _, sx in { -7.5, 7.5 } do
		newPart({
			Name = "Strut",
			Material = Enum.Material.Metal,
			Color = C.stroke,
			Size = Vector3.new(0.4, 4.4, 0.4),
			CFrame = CFrame.new(x + sx, 2.2, baseZ - 2.6),
			Parent = model,
		})
	end
	model.Parent = parent
end

-- ── Locker-room tunnel + spawn ───────────────────────────────────────────────

local function buildTunnel(parent)
	local model = mk("Model", { Name = "Tunnel" })
	-- side walls + roof form an open portal facing the pitch (-Z)
	newPart({
		Name = "WallL",
		Material = Enum.Material.Concrete,
		Color = C.surface,
		Size = Vector3.new(2, 10, 14),
		CFrame = CFrame.new(-8, 5, 56),
		Parent = model,
	})
	newPart({
		Name = "WallR",
		Material = Enum.Material.Concrete,
		Color = C.surface,
		Size = Vector3.new(2, 10, 14),
		CFrame = CFrame.new(8, 5, 56),
		Parent = model,
	})
	newPart({
		Name = "Roof",
		Material = Enum.Material.Concrete,
		Color = C.surfaceAlt,
		Size = Vector3.new(18, 2, 14),
		CFrame = CFrame.new(0, 11, 56),
		Parent = model,
	})
	newPart({
		Name = "BackWall",
		Material = Enum.Material.Concrete,
		Color = C.dark,
		Size = Vector3.new(18, 12, 2),
		CFrame = CFrame.new(0, 6, 62),
		Parent = model,
	})
	-- glowing header above the mouth
	newPart({
		Name = "Header",
		Material = Enum.Material.Neon,
		Color = C.accent,
		Size = Vector3.new(18, 0.8, 0.8),
		CFrame = CFrame.new(0, 10.2, 49),
		Parent = model,
	})
	mk("SpawnLocation", {
		Name = "TunnelSpawn",
		Material = Enum.Material.Neon,
		Color = C.accent,
		Transparency = 0.4,
		Size = Vector3.new(12, 1, 8),
		CFrame = CFrame.new(0, 0.5, 54),
		Neutral = true,
		Duration = 0,
		Parent = model,
	}, {
		mk("Decal", { Texture = "", Transparency = 1 }),
	})
	model.Parent = parent
end

-- ── Conveyor belt ("tapis") with a parading card showcase ─────────────────────

local function buildBelt(parent)
	local model = mk("Model", { Name = "Conveyor" })
	local startZ, endZ = 48, 10
	local midZ = (startZ + endZ) / 2
	local length = startZ - endZ
	newPart({
		Name = "Belt",
		Material = Enum.Material.SmoothPlastic,
		Color = C.dark,
		Size = Vector3.new(12, 0.6, length),
		CFrame = CFrame.new(0, 0.3, midZ),
		Parent = model,
	})
	for _, sx in { -6.4, 6.4 } do
		newPart({
			Name = "Rail",
			Material = Enum.Material.Neon,
			Color = C.accent,
			Size = Vector3.new(0.8, 1, length + 2),
			CFrame = CFrame.new(sx, 0.5, midZ),
			Parent = model,
		})
	end
	for _, rz in { startZ, endZ } do
		newPart({
			Name = "Roller",
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.Metal,
			Color = C.stroke,
			Size = Vector3.new(13, 2.4, 2.4),
			CFrame = CFrame.new(0, 0.6, rz) * CFrame.Angles(0, 0, math.rad(90)),
			Parent = model,
		})
	end
	model.Parent = parent

	-- showcase: highest-power cards parade from the tunnel onto the pitch
	local showcase = table.clone(Cards)
	table.sort(showcase, function(a, b)
		return a.basePower > b.basePower
	end)
	local count = math.min(6, #showcase)
	local travel = 8

	for i = 1, count do
		local card = showcase[i]
		local rarityColor = RARITY[card.rarity] or C.accent
		local plaque = newPart({
			Name = "CardPlaque",
			Material = Enum.Material.SmoothPlastic,
			Color = rarityColor,
			CanCollide = false,
			Size = Vector3.new(5, 7, 0.4),
			CFrame = CFrame.new(0, 4.5, startZ),
			Parent = model,
		}, {
			mk("UICorner", {}),
		})
		local label = mk("BillboardGui", {
			Name = "Name",
			Size = UDim2.fromOffset(220, 56),
			StudsOffset = Vector3.new(0, 4.6, 0),
			MaxDistance = 160,
			Parent = plaque,
		}, {
			mk("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = C.dark,
				BackgroundTransparency = 0.15,
				BorderSizePixel = 0,
				Text = card.name,
				TextColor3 = C.text,
				Font = Enum.Font.GothamBold,
				TextScaled = true,
			}, {
				mk("UICorner", { CornerRadius = UDim.new(0, 10) }),
				mk("UIStroke", { Color = rarityColor, Thickness = 2 }),
				mk("UIPadding", {
					PaddingLeft = UDim.new(0, 10),
					PaddingRight = UDim.new(0, 10),
					PaddingTop = UDim.new(0, 6),
					PaddingBottom = UDim.new(0, 6),
				}),
			}),
		})

		task.delay((i - 1) * (travel / count), function()
			while plaque.Parent do
				plaque.CFrame = CFrame.new(0, 4.5, startZ)
				plaque.Transparency = 1
				label.Enabled = false
				TweenService:Create(plaque, TweenInfo.new(0.5), { Transparency = 0 }):Play()
				label.Enabled = true
				local move = TweenService:Create(
					plaque,
					TweenInfo.new(travel, Enum.EasingStyle.Linear),
					{ CFrame = CFrame.new(0, 4.5, endZ) }
				)
				move:Play()
				move.Completed:Wait()
				label.Enabled = false
				TweenService:Create(plaque, TweenInfo.new(0.5), { Transparency = 1 }):Play()
				task.wait(0.6)
			end
		end)
	end
end

-- ── Floodlights ──────────────────────────────────────────────────────────────

local function buildFloodlight(parent, pos)
	local model = mk("Model", { Name = "Floodlight" })
	newPart({
		Name = "Pole",
		Material = Enum.Material.Metal,
		Color = C.stroke,
		Size = Vector3.new(2.5, 44, 2.5),
		CFrame = CFrame.new(pos + Vector3.new(0, 22, 0)),
		Parent = model,
	})
	newPart({
		Name = "Lamp",
		Material = Enum.Material.Neon,
		Color = Color3.fromHex("FFF4D6"),
		Size = Vector3.new(10, 4, 2),
		CFrame = CFrame.new(pos + Vector3.new(0, 44, 0)) * CFrame.Angles(math.rad(28), 0, 0),
		Parent = model,
	}, {
		mk("SpotLight", {
			Brightness = 4,
			Range = 140,
			Angle = 70,
			Color = Color3.fromHex("FFF4D6"),
			Face = Enum.NormalId.Bottom,
		}),
	})
	model.Parent = parent
end

-- ── Kiosks (bornes) ──────────────────────────────────────────────────────────

local function buildKiosk(parent, def)
	local model = mk("Model", { Name = "Kiosk_" .. def.id })
	local base = newPart({
		Name = "Base",
		Material = Enum.Material.Metal,
		Color = C.surface,
		Size = Vector3.new(5, 5, 5),
		CFrame = CFrame.new(def.pos + Vector3.new(0, 2.5, 0)),
		Parent = model,
	})
	base:SetAttribute("WCBPanel", def.id)
	newPart({
		Name = "Glow",
		Material = Enum.Material.Neon,
		Color = def.color,
		Size = Vector3.new(5.4, 0.6, 5.4),
		CFrame = CFrame.new(def.pos + Vector3.new(0, 5.1, 0)),
		Parent = model,
	})
	newPart({
		Name = "Screen",
		Material = Enum.Material.SmoothPlastic,
		Color = C.surfaceAlt,
		Size = Vector3.new(5, 3, 0.4),
		CFrame = CFrame.new(def.pos + Vector3.new(0, 7.5, 0)),
		Parent = model,
	}, {
		mk("UICorner", {}),
	})
	mk("ProximityPrompt", {
		ActionText = def.label,
		ObjectText = "Borne",
		KeyboardKeyCode = Enum.KeyCode.E,
		HoldDuration = 0,
		MaxActivationDistance = 12,
		RequiresLineOfSight = false,
		Parent = base,
	})
	mk("BillboardGui", {
		Name = "Label",
		Size = UDim2.fromOffset(220, 64),
		StudsOffset = Vector3.new(0, 4.4, 0),
		MaxDistance = 150,
		Parent = base,
	}, {
		mk("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = C.surface,
			BackgroundTransparency = 0.12,
			BorderSizePixel = 0,
			Text = def.label,
			TextColor3 = C.text,
			Font = Enum.Font.GothamBold,
			TextScaled = true,
		}, {
			mk("UICorner", { CornerRadius = UDim.new(0, 12) }),
			mk("UIStroke", { Color = def.color, Thickness = 2 }),
			mk("UIPadding", {
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
			}),
		}),
	})
	model.Parent = parent
end

-- ── Environment ──────────────────────────────────────────────────────────────

local function buildGround(parent)
	newPart({
		Name = "Ground",
		Material = Enum.Material.Slate,
		Color = C.dark,
		Size = Vector3.new(420, 2, 320),
		CFrame = CFrame.new(0, -1.5, 0),
		Parent = parent,
	})
	-- low perimeter wall
	for _, w in
		{
			{ Vector3.new(420, 8, 2), Vector3.new(0, 4, 158) },
			{ Vector3.new(420, 8, 2), Vector3.new(0, 4, -158) },
			{ Vector3.new(2, 8, 320), Vector3.new(209, 4, 0) },
			{ Vector3.new(2, 8, 320), Vector3.new(-209, 4, 0) },
		}
	do
		newPart({
			Name = "Wall",
			Material = Enum.Material.Concrete,
			Color = C.stroke,
			Size = w[1],
			CFrame = CFrame.new(w[2]),
			Parent = parent,
		})
	end
end

local function setLighting()
	Lighting.ClockTime = 0
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(20, 24, 33)
	Lighting.OutdoorAmbient = Color3.fromRGB(32, 38, 50)
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true
	Lighting.FogColor = C.dark
	Lighting.FogStart = 280
	Lighting.FogEnd = 950

	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmo then
		atmo = mk("Atmosphere", { Parent = Lighting })
	end
	atmo.Density = 0.34
	atmo.Offset = 0.1
	atmo.Color = Color3.fromRGB(120, 130, 150)
	atmo.Decay = Color3.fromRGB(40, 46, 60)
	atmo.Glare = 0.2
	atmo.Haze = 1.4
end

-- ── Build ────────────────────────────────────────────────────────────────────

function WorldService:_build()
	-- Idempotent: clear any prior build + the default baseplate/spawn.
	local existing = Workspace:FindFirstChild("Stadium")
	if existing then
		existing:Destroy()
	end
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	for _, inst in Workspace:GetChildren() do
		if inst:IsA("SpawnLocation") then
			inst:Destroy()
		end
	end

	setLighting()

	local folder = mk("Folder", { Name = "Stadium", Parent = Workspace })

	buildGround(folder)
	buildPitch(folder)
	buildGoal(folder, 1)
	buildGoal(folder, -1)
	buildStand(folder, CFrame.new(0, 0, 57) * CFrame.Angles(0, math.rad(180), 0), 150, 9)
	buildStand(folder, CFrame.new(0, 0, -57), 150, 9)
	buildStand(folder, CFrame.new(82, 0, 0) * CFrame.Angles(0, math.rad(-90), 0), 110, 9)
	buildStand(folder, CFrame.new(-82, 0, 0) * CFrame.Angles(0, math.rad(90), 0), 110, 9)
	buildBench(folder, -22)
	buildBench(folder, 22)
	buildTunnel(folder)
	buildBelt(folder)
	for _, pos in
		{
			Vector3.new(100, 0, 72),
			Vector3.new(-100, 0, 72),
			Vector3.new(100, 0, -72),
			Vector3.new(-100, 0, -72),
		}
	do
		buildFloodlight(folder, pos)
	end
	for _, def in KIOSKS do
		buildKiosk(folder, def)
	end
end

function WorldService:KnitStart()
	self:_build()
end

function WorldService:KnitInit() end

return WorldService
