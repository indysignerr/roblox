--!nonstrict
-- WorldService: builds the entire stadium map at runtime (the project has no Workspace
-- mapping, so all geometry is code-generated). Big, bright, daytime stadium to match the
-- UI theme. Produces: striped pitch + markings, 4 detailed & named tiered stands packed
-- with supporters, 2 goals with nets, 2 coach benches, a locker-room tunnel with player
-- spawn, a conveyor "tapis" that parades brainrot-footballer cards from the tunnel onto the
-- pitch, a World Cup scoreboard jumbotron (fed by Shared.Config.WorldCupConfig), pitch-side
-- sponsor LED boards, floodlights, and 8 physical kiosks (bornes). Each kiosk carries a
-- `WCBPanel` attribute + ProximityPrompt; the client WorldController turns a triggered
-- prompt into DockController:Open(panelId).
--
-- SCALE: every design coordinate below is authored at "1x"; newPart() multiplies all part
-- Sizes and CFrame positions by S (=2) so the whole stadium is twice as large. Rotations
-- are scale-invariant and preserved. Non-part distances (prompt range, billboard offsets,
-- the belt parade tweens) call sc()/scaleCF() explicitly since they bypass newPart.
--
-- Server can't require the client Theme (different tree) so the palette is hardcoded here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Cards = require(ReplicatedStorage.Shared.Config.Cards)
local WorldCupConfig = require(ReplicatedStorage.Shared.Config.WorldCupConfig)

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

-- ── Scale (everything is authored at 1x; the world is built at S=2) ───────────
local S = 2
local function sc(n: number): number
	return n * S
end
local function scaleV3(v: Vector3): Vector3
	return Vector3.new(v.X * S, v.Y * S, v.Z * S)
end
-- Scale a CFrame's *position* only; its rotation is left untouched (scale-invariant).
local function scaleCF(c: CFrame): CFrame
	return (c - c.Position) + scaleV3(c.Position)
end

local function darken(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

-- Crowd: blocky supporters get a jersey (biased to the stand's theme) + a skin-tone head.
local JERSEYS = {
	Color3.fromHex("F5F7FA"),
	Color3.fromHex("E63946"),
	Color3.fromHex("2A9D8F"),
	Color3.fromHex("3B9DFF"),
	Color3.fromHex("FFD23F"),
	Color3.fromHex("B36BFF"),
	Color3.fromHex("FF7B29"),
	Color3.fromHex("38E08B"),
	Color3.fromHex("1A1F29"),
}
local SKINS = {
	Color3.fromHex("F1C9A5"),
	Color3.fromHex("E0AC85"),
	Color3.fromHex("C68642"),
	Color3.fromHex("8D5524"),
	Color3.fromHex("5C3A21"),
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
	-- Author at 1x, build at S x: scale every part's size + position uniformly.
	if typeof(props.Size) == "Vector3" then
		props.Size = scaleV3(props.Size)
	end
	if typeof(props.CFrame) == "CFrame" then
		props.CFrame = scaleCF(props.CFrame)
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

-- ── Supporters (blocky fans seated on the rows) ──────────────────────────────
-- Local space matches buildStand: rows recede -Z and rise +Y. Jerseys are biased to the
-- stand's theme colour so each tribune reads as "its" crowd; heads use varied skin tones.

local function buildSupporters(model, baseCFrame, length, rows, themeColor)
	local rng = Random.new()
	local spacing = 5.5
	local half = length / 2 - 4
	for i = 1, rows do
		local y = 1.2 + (i - 1) * 2.2
		local z = -(i - 1) * 4
		local seatTop = y + 1.7
		local x = -half
		while x <= half do
			if rng:NextNumber() > 0.22 then -- ~22% empty seats
				local jersey
				if rng:NextNumber() < 0.55 then
					jersey = themeColor:Lerp(JERSEYS[rng:NextInteger(1, #JERSEYS)], 0.25)
				else
					jersey = JERSEYS[rng:NextInteger(1, #JERSEYS)]
				end
				local jitter = (rng:NextNumber() - 0.5) * 1.2
				newPart({
					Name = "Fan",
					Color = jersey,
					CanCollide = false,
					Size = Vector3.new(1.3, 2, 1),
					CFrame = baseCFrame * CFrame.new(x + jitter, seatTop + 1, z + 0.7),
					Parent = model,
				})
				newPart({
					Name = "FanHead",
					Shape = Enum.PartType.Ball,
					Color = SKINS[rng:NextInteger(1, #SKINS)],
					CanCollide = false,
					Size = Vector3.new(1, 1, 1),
					CFrame = baseCFrame * CFrame.new(x + jitter, seatTop + 2.5, z + 0.7),
					Parent = model,
				})
			end
			x = x + spacing
		end
	end
end

-- ── Stands (tiered + named/themed: rows recede -Z and rise +Y) ────────────────

local function buildStand(parent, baseCFrame, length, rows, theme)
	local model = mk("Model", { Name = "Stand_" .. theme.name })
	local seatA = theme.color
	local seatB = darken(theme.color, 0.5)
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
			Color = (i % 2 == 0) and seatA or seatB,
			Size = Vector3.new(length, 0.5, 1.4),
			CFrame = baseCFrame * CFrame.new(0, y + 1.45, z + 1.2),
			Parent = model,
		})
	end

	local topY = 1.2 + (rows - 1) * 2.2
	local backZ = -(rows - 1) * 4 - 3
	local backH = topY + 5
	-- themed back wall + glowing fascia near its top
	newPart({
		Name = "Back",
		Material = Enum.Material.Concrete,
		Color = darken(theme.color, 0.74),
		Size = Vector3.new(length + 4, backH, 1),
		CFrame = baseCFrame * CFrame.new(0, backH / 2, backZ),
		Parent = model,
	})
	newPart({
		Name = "Fascia",
		Material = Enum.Material.Neon,
		Color = theme.color,
		Size = Vector3.new(length + 4, 2, 1.2),
		CFrame = baseCFrame * CFrame.new(0, backH - 2, backZ),
		Parent = model,
	})
	-- safety railing along the pitch-facing front edge
	newPart({
		Name = "Railing",
		Material = Enum.Material.Metal,
		Color = C.line,
		Size = Vector3.new(length, 1.2, 0.3),
		CFrame = baseCFrame * CFrame.new(0, 2.2, 2.2),
		Parent = model,
	})
	-- canopy roof on two pillars over the rear rows
	local canopyY = backH + 2
	for _, sx in { -(length / 2 - 4), length / 2 - 4 } do
		newPart({
			Name = "Pillar",
			Material = Enum.Material.Metal,
			Color = C.stroke,
			Size = Vector3.new(1.4, canopyY, 1.4),
			CFrame = baseCFrame * CFrame.new(sx, canopyY / 2, backZ + 1),
			Parent = model,
		})
	end
	newPart({
		Name = "Canopy",
		Color = C.surface,
		Transparency = 0.1,
		Size = Vector3.new(length + 6, 1, 16),
		CFrame = baseCFrame
			* CFrame.new(0, canopyY, backZ + 7)
			* CFrame.Angles(math.rad(-10), 0, 0),
		Parent = model,
	})
	-- name banner (always faces the player), mounted above the fascia
	local anchor = newPart({
		Name = "SignAnchor",
		Transparency = 1,
		CanCollide = false,
		Size = Vector3.new(1, 1, 1),
		CFrame = baseCFrame * CFrame.new(0, backH + 1, backZ + 2),
		Parent = model,
	})
	mk("BillboardGui", {
		Name = "Banner",
		Size = UDim2.fromOffset(440, 72),
		MaxDistance = sc(420),
		Parent = anchor,
	}, {
		mk("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = C.dark,
			BackgroundTransparency = 0.1,
			BorderSizePixel = 0,
			Text = theme.name,
			TextColor3 = C.text,
			Font = Enum.Font.GothamBlack,
			TextScaled = true,
		}, {
			mk("UICorner", { CornerRadius = UDim.new(0, 14) }),
			mk("UIStroke", { Color = theme.color, Thickness = 3 }),
			mk("UIPadding", {
				PaddingLeft = UDim.new(0, 16),
				PaddingRight = UDim.new(0, 16),
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
			}),
		}),
	})

	buildSupporters(model, baseCFrame, length, rows, theme.color)
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
		Size = scaleV3(Vector3.new(12, 1, 8)),
		CFrame = scaleCF(CFrame.new(0, 0.5, 54)),
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
			StudsOffset = scaleV3(Vector3.new(0, 4.6, 0)),
			MaxDistance = sc(160),
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

		local fromCF = scaleCF(CFrame.new(0, 4.5, startZ))
		local toCF = scaleCF(CFrame.new(0, 4.5, endZ))
		task.delay((i - 1) * (travel / count), function()
			while plaque.Parent do
				plaque.CFrame = fromCF
				plaque.Transparency = 1
				label.Enabled = false
				TweenService:Create(plaque, TweenInfo.new(0.5), { Transparency = 0 }):Play()
				label.Enabled = true
				local move = TweenService:Create(
					plaque,
					TweenInfo.new(travel, Enum.EasingStyle.Linear),
					{ CFrame = toCF }
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
			Brightness = 0.8,
			Range = sc(140),
			Angle = 70,
			Color = Color3.fromHex("FFF4D6"),
			Face = Enum.NormalId.Bottom,
			Shadows = false,
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
		MaxActivationDistance = sc(12),
		RequiresLineOfSight = false,
		Parent = base,
	})
	mk("BillboardGui", {
		Name = "Label",
		Size = UDim2.fromOffset(220, 64),
		StudsOffset = scaleV3(Vector3.new(0, 4.4, 0)),
		MaxDistance = sc(150),
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

-- ── Scoreboard jumbotron (fed by Shared.Config.WorldCupConfig) ───────────────
-- A big raised board behind the east tribune, facing the pitch (-X). Edit the config
-- file + Stop/Play in Studio to refresh the scores.

local SB_STATUS = {
	FINISHED = { txt = "FINI", color = Color3.fromHex("2EE6A6") },
	LIVE = { txt = "● LIVE", color = Color3.fromHex("FF4D6D") },
	UPCOMING = { txt = "À VENIR", color = Color3.fromHex("313A49") },
}

local function buildScoreboard(parent)
	local cfg = WorldCupConfig
	local model = mk("Model", { Name = "Scoreboard" })
	local cx, cy = 132, 52

	for _, sz in { -26, 26 } do
		newPart({
			Name = "Pole",
			Material = Enum.Material.Metal,
			Color = C.stroke,
			Size = Vector3.new(3, cy, 3),
			CFrame = CFrame.new(cx + 3, cy / 2, sz),
			Parent = model,
		})
	end
	newPart({
		Name = "Frame",
		Material = Enum.Material.Neon,
		Color = C.accent,
		Size = Vector3.new(66, 48, 1.2),
		CFrame = CFrame.new(cx + 0.6, cy, 0) * CFrame.Angles(0, math.rad(90), 0),
		Parent = model,
	})
	local board = newPart({
		Name = "Board",
		Color = C.dark,
		Size = Vector3.new(64, 46, 1.5),
		CFrame = CFrame.new(cx, cy, 0) * CFrame.Angles(0, math.rad(90), 0),
		Parent = model,
	})

	local gui = mk("SurfaceGui", {
		Name = "Display",
		Face = Enum.NormalId.Front,
		CanvasSize = Vector2.new(960, 690),
		LightInfluence = 0,
		Brightness = 1.4,
		Parent = board,
	})
	local root = mk("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.dark,
		BorderSizePixel = 0,
		Parent = gui,
	}, {
		mk("UIPadding", {
			PaddingLeft = UDim.new(0, 26),
			PaddingRight = UDim.new(0, 26),
			PaddingTop = UDim.new(0, 18),
			PaddingBottom = UDim.new(0, 18),
		}),
		mk("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
	})

	mk("TextLabel", {
		Size = UDim2.new(1, 0, 0, 70),
		BackgroundTransparency = 1,
		Text = cfg.title,
		TextColor3 = C.accent,
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		LayoutOrder = 0,
		Parent = root,
	})
	mk("TextLabel", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		Text = cfg.subtitle,
		TextColor3 = C.text,
		Font = Enum.Font.GothamMedium,
		TextScaled = true,
		LayoutOrder = 1,
		Parent = root,
	})

	for idx, m in cfg.matches do
		local meta = SB_STATUS[m.status] or SB_STATUS.UPCOMING
		local hs = m.homeScore and tostring(m.homeScore) or "-"
		local as = m.awayScore and tostring(m.awayScore) or "-"
		local row = mk("Frame", {
			Name = "Match",
			Size = UDim2.new(1, 0, 0, 58),
			BackgroundColor3 = C.surface,
			BorderSizePixel = 0,
			LayoutOrder = idx + 1,
			Parent = root,
		}, {
			mk("UICorner", { CornerRadius = UDim.new(0, 12) }),
			mk("UIStroke", { Color = meta.color, Thickness = 2 }),
			mk("UIPadding", {
				PaddingLeft = UDim.new(0, 16),
				PaddingRight = UDim.new(0, 16),
			}),
		})
		mk("TextLabel", {
			Name = "Stage",
			Size = UDim2.fromScale(0.2, 1),
			BackgroundTransparency = 1,
			Text = string.upper(m.stage),
			TextColor3 = C.accent,
			Font = Enum.Font.GothamBold,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		mk("TextLabel", {
			Name = "Score",
			Position = UDim2.fromScale(0.22, 0),
			Size = UDim2.fromScale(0.54, 1),
			BackgroundTransparency = 1,
			Text = string.format("%s   %s - %s   %s", m.home, hs, as, m.away),
			TextColor3 = C.text,
			Font = Enum.Font.GothamBlack,
			TextScaled = true,
			Parent = row,
		})
		mk("TextLabel", {
			Name = "Status",
			Position = UDim2.fromScale(0.78, 0.2),
			Size = UDim2.fromScale(0.22, 0.6),
			BackgroundColor3 = meta.color,
			Text = meta.txt,
			TextColor3 = C.dark,
			Font = Enum.Font.GothamBold,
			TextScaled = true,
			Parent = row,
		}, {
			mk("UICorner", { CornerRadius = UDim.new(0, 10) }),
			mk("UIPadding", {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 4),
			}),
		})
	end

	model.Parent = parent
end

-- ── Pitch-side sponsor LED boards (parody brands only) ────────────────────────

local SPONSORS =
	{ "RIZZ COLA", "BRAINROT ENERGY", "GYATT SPORT", "SIGMA FC", "SKIBIDI BANK", "NPC NOODLES" }

local function adBoard(parent, cframe, text, color)
	local b = newPart({
		Name = "AdBoard",
		Color = C.dark,
		Size = Vector3.new(22, 3.4, 0.6),
		CFrame = cframe,
		Parent = parent,
	})
	mk("SurfaceGui", {
		Face = Enum.NormalId.Front,
		CanvasSize = Vector2.new(460, 72),
		LightInfluence = 0,
		Brightness = 1.4,
		Parent = b,
	}, {
		mk("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = C.dark,
			BorderSizePixel = 0,
			Text = text,
			TextColor3 = color,
			Font = Enum.Font.GothamBlack,
			TextScaled = true,
		}, {
			mk("UIPadding", {
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
			}),
		}),
	})
end

local function buildAdBoards(parent)
	local model = mk("Model", { Name = "AdBoards" })
	local colors = {
		C.accent,
		Color3.fromHex("FF4D6D"),
		C.accent2,
		Color3.fromHex("3B9DFF"),
		Color3.fromHex("B36BFF"),
	}
	local xs = { -48, -24, 0, 24, 48 }
	for i, x in xs do
		-- North touchline: faces -Z (toward pitch) via the default Front face.
		adBoard(
			model,
			CFrame.new(x, 1.9, 46.5),
			SPONSORS[((i - 1) % #SPONSORS) + 1],
			colors[((i - 1) % #colors) + 1]
		)
		-- South touchline: yaw 180 so Front faces +Z (toward pitch), no mirrored text.
		adBoard(
			model,
			CFrame.new(x, 1.9, -46.5) * CFrame.Angles(0, math.rad(180), 0),
			SPONSORS[((i + 2) % #SPONSORS) + 1],
			colors[((i + 1) % #colors) + 1]
		)
	end
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
	-- Bright midday, never night, so the whole stadium reads clearly.
	Lighting.ClockTime = 14
	Lighting.GeographicLatitude = 12
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(120, 124, 132)
	Lighting.OutdoorAmbient = Color3.fromRGB(170, 178, 190)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true
	Lighting.FogColor = Color3.fromRGB(196, 214, 232)
	Lighting.FogStart = 900
	Lighting.FogEnd = 6000

	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmo then
		atmo = mk("Atmosphere", { Parent = Lighting })
	end
	atmo.Density = 0.28
	atmo.Offset = 0.2
	atmo.Color = Color3.fromRGB(199, 220, 240)
	atmo.Decay = Color3.fromRGB(150, 170, 200)
	atmo.Glare = 0.05
	atmo.Haze = 0.6

	-- A plain blue sky guarantees a daytime look regardless of the place defaults.
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if not sky then
		sky = mk("Sky", { Parent = Lighting })
	end
	sky.SunAngularSize = 16
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
	buildStand(folder, CFrame.new(0, 0, 57) * CFrame.Angles(0, math.rad(180), 0), 150, 9, {
		name = "TRIBUNE NORD",
		color = C.accent,
	})
	buildStand(folder, CFrame.new(0, 0, -57), 150, 9, { name = "TRIBUNE SUD", color = C.accent2 })
	buildStand(folder, CFrame.new(82, 0, 0) * CFrame.Angles(0, math.rad(-90), 0), 110, 9, {
		name = "TRIBUNE EST",
		color = Color3.fromHex("3B9DFF"),
	})
	buildStand(folder, CFrame.new(-82, 0, 0) * CFrame.Angles(0, math.rad(90), 0), 110, 9, {
		name = "TRIBUNE OUEST",
		color = Color3.fromHex("FF4D6D"),
	})
	buildBench(folder, -22)
	buildBench(folder, 22)
	buildTunnel(folder)
	buildBelt(folder)
	buildScoreboard(folder)
	buildAdBoards(folder)
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
