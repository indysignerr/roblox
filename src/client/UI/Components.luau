--!nonstrict
-- Reusable UI builders for World Cup Brainrot. Every panel composes these so the
-- whole game shares one look. All functions return Instances you parent yourself
-- (except Toast, which parents + animates itself).
--
-- API:
--   create(class, props?, children?) -> Instance         generic builder
--   corner(r)/stroke(color,thick?)/padding(all)/listLayout(opts)/gridLayout(opts)
--   Panel(props)        -> Frame      styled surface (props: Size, Position, Parent, color)
--   Heading(text, props?)-> TextLabel
--   Label(text, props?) -> TextLabel  (props.dim = true for muted)
--   Button(opts)        -> TextButton (opts: text, onClick, variant, Size, Position, Parent)
--                            variant = "primary" | "secondary" | "danger" | "ghost"
--   ScrollList(props)   -> ScrollingFrame (vertical UIListLayout; props.padding, .gap)
--   Grid(props)         -> ScrollingFrame (UIGridLayout; props.cell, .gap)
--   CardTile(def, count?, opts?) -> Frame   (def = CardDef; colours by rarity; opts.onClick)
--   ProgressBar(props)  -> { root, set(alpha) }   props.color, Size, Position, Parent
--   Toast(parent, text, color?)                  transient bottom notification

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local C = {}

-- Generic Instance factory. Returns `any` (not `Instance`) so the typed helpers below
-- (corner/stroke/Panel/...) can annotate their concrete return class without a cast.
function C.create(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	if props then
		for k, v in props do
			inst[k] = v
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	return inst
end

function C.corner(radius: number?): UICorner
	return C.create("UICorner", { CornerRadius = UDim.new(0, radius or Theme.radius.md) })
end

function C.stroke(color: Color3?, thickness: number?): UIStroke
	return C.create("UIStroke", {
		Color = color or Theme.color.stroke,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function C.padding(all: number): UIPadding
	local p = UDim.new(0, all)
	return C.create(
		"UIPadding",
		{ PaddingTop = p, PaddingBottom = p, PaddingLeft = p, PaddingRight = p }
	)
end

function C.listLayout(optsArg: { [string]: any }?): UIListLayout
	local opts = optsArg or {}
	return C.create("UIListLayout", {
		FillDirection = opts.horizontal and Enum.FillDirection.Horizontal
			or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, opts.gap or Theme.pad.sm),
		HorizontalAlignment = opts.hAlign or Enum.HorizontalAlignment.Left,
		VerticalAlignment = opts.vAlign or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function C.gridLayout(cell: Vector2?, gap: number?): UIGridLayout
	return C.create("UIGridLayout", {
		CellSize = UDim2.fromOffset((cell and cell.X) or 120, (cell and cell.Y) or 160),
		CellPadding = UDim2.fromOffset(gap or Theme.pad.sm, gap or Theme.pad.sm),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function C.Panel(propsArg: { [string]: any }?): Frame
	local props = propsArg or {}
	local frame = C.create("Frame", {
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position,
		BackgroundColor3 = props.color or Theme.color.surface,
		BorderSizePixel = 0,
		Parent = props.Parent,
	}, { C.corner(props.radius or Theme.radius.lg), C.stroke() })
	return frame
end

function C.Heading(text: string, propsArg: { [string]: any }?): TextLabel
	local props = propsArg or {}
	return C.create("TextLabel", {
		Text = text,
		Font = Theme.font.display,
		TextSize = props.TextSize or Theme.text.lg,
		TextColor3 = props.TextColor3 or Theme.color.text,
		TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.new(1, 0, 0, (props.TextSize or Theme.text.lg) + 8),
		Position = props.Position,
		Parent = props.Parent,
	})
end

function C.Label(text: string, propsArg: { [string]: any }?): TextLabel
	local props = propsArg or {}
	return C.create("TextLabel", {
		Text = text,
		Font = props.Font or Theme.font.body,
		TextSize = props.TextSize or Theme.text.md,
		TextColor3 = props.TextColor3 or (props.dim and Theme.color.textDim or Theme.color.text),
		TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left,
		TextWrapped = props.TextWrapped or false,
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.new(1, 0, 0, (props.TextSize or Theme.text.md) + 6),
		Position = props.Position,
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	})
end

local VARIANT = {
	primary = { bg = Theme.color.accent, fg = Theme.color.bg },
	secondary = { bg = Theme.color.surfaceAlt, fg = Theme.color.text },
	danger = { bg = Theme.color.danger, fg = Theme.color.text },
	ghost = { bg = Theme.color.surface, fg = Theme.color.textDim },
}

function C.Button(opts: { [string]: any }): TextButton
	local variant = VARIANT[opts.variant or "primary"]
	local btn = C.create("TextButton", {
		Text = opts.text or "",
		Font = Theme.font.heading,
		TextSize = opts.TextSize or Theme.text.md,
		TextColor3 = variant.fg,
		AutoButtonColor = false,
		BackgroundColor3 = variant.bg,
		BorderSizePixel = 0,
		Size = opts.Size or UDim2.new(1, 0, 0, 44),
		Position = opts.Position,
		LayoutOrder = opts.LayoutOrder or 0,
		Parent = opts.Parent,
	}, { C.corner(opts.radius or Theme.radius.md) })

	local base = variant.bg
	local hover = base:Lerp(Color3.new(1, 1, 1), 0.12)
	local down = base:Lerp(Color3.new(0, 0, 0), 0.12)
	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = hover }):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = base }):Play()
	end)
	btn.MouseButton1Down:Connect(function()
		btn.BackgroundColor3 = down
	end)
	btn.MouseButton1Up:Connect(function()
		btn.BackgroundColor3 = hover
	end)
	if opts.onClick then
		btn.MouseButton1Click:Connect(opts.onClick)
	end
	return btn
end

function C.ScrollList(propsArg: { [string]: any }?): ScrollingFrame
	local props = propsArg or {}
	local sf = C.create("ScrollingFrame", {
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.color.stroke,
		Parent = props.Parent,
	}, {
		C.listLayout({ gap = props.gap }),
		C.padding(props.padding or Theme.pad.sm),
	})
	return sf
end

function C.Grid(propsArg: { [string]: any }?): ScrollingFrame
	local props = propsArg or {}
	local sf = C.create("ScrollingFrame", {
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.color.stroke,
		Parent = props.Parent,
	}, {
		C.gridLayout(props.cell, props.gap),
		C.padding(props.padding or Theme.pad.sm),
	})
	return sf
end

-- A card tile coloured by rarity. `def` is a CardDef ({name, nation, rarity, basePower}).
function C.CardTile(def: { [string]: any }, count: number?, optsArg: { [string]: any }?): Frame
	local opts = optsArg or {}
	local rc = Theme.rarityColor(def.rarity)
	local tile = C.create(opts.onClick and "TextButton" or "Frame", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.color.surfaceAlt,
		BorderSizePixel = 0,
		Size = opts.Size or UDim2.fromOffset(120, 160),
		LayoutOrder = opts.LayoutOrder or 0,
		Parent = opts.Parent,
	}, {
		C.corner(Theme.radius.md),
		C.stroke(rc, 2),
		C.create("Frame", { -- rarity banner
			Size = UDim2.new(1, 0, 0, 6),
			BackgroundColor3 = rc,
			BorderSizePixel = 0,
		}, { C.corner(Theme.radius.sm) }),
		C.Label(def.name or "?", {
			Position = UDim2.fromOffset(8, 14),
			Size = UDim2.new(1, -16, 0, 36),
			TextWrapped = true,
			Font = Theme.font.heading,
			TextSize = Theme.text.sm,
		}),
		C.Label((def.nation or "") .. "  ·  " .. (def.rarity or ""), {
			Position = UDim2.new(0, 8, 1, -44),
			Size = UDim2.new(1, -16, 0, 16),
			dim = true,
			TextSize = 12,
		}),
		C.Label("PWR " .. tostring(def.basePower or 0), {
			Position = UDim2.new(0, 8, 1, -26),
			Size = UDim2.new(1, -16, 0, 16),
			TextColor3 = rc,
			Font = Theme.font.bodyBold,
			TextSize = 13,
		}),
	})
	if count and count > 1 then
		C.create("TextLabel", {
			Text = "x" .. tostring(count),
			Font = Theme.font.display,
			TextSize = 14,
			TextColor3 = Theme.color.bg,
			BackgroundColor3 = Theme.color.accent,
			Size = UDim2.fromOffset(30, 22),
			Position = UDim2.new(1, -34, 0, 10),
			Parent = tile,
		}, { C.corner(Theme.radius.pill) })
	end
	if opts.onClick then
		(tile :: TextButton).MouseButton1Click:Connect(opts.onClick)
	end
	return tile
end

function C.ProgressBar(propsArg: { [string]: any }?)
	local props = propsArg or {}
	local root = C.create("Frame", {
		Size = props.Size or UDim2.new(1, 0, 0, 14),
		Position = props.Position,
		BackgroundColor3 = Theme.color.surfaceAlt,
		BorderSizePixel = 0,
		Parent = props.Parent,
	}, { C.corner(Theme.radius.pill) })
	local fill = C.create("Frame", {
		Size = UDim2.fromScale(props.alpha or 0, 1),
		BackgroundColor3 = props.color or Theme.color.accent2,
		BorderSizePixel = 0,
		Parent = root,
	}, { C.corner(Theme.radius.pill) })
	return {
		root = root,
		set = function(alpha: number)
			alpha = math.clamp(alpha, 0, 1)
			TweenService:Create(fill, TweenInfo.new(0.25), { Size = UDim2.fromScale(alpha, 1) })
				:Play()
		end,
	}
end

-- Transient notification that slides up from the bottom of `parent`, then fades.
function C.Toast(parent: Instance, text: string, color: Color3?)
	local toast = C.create("TextLabel", {
		Text = text,
		Font = Theme.font.heading,
		TextSize = Theme.text.md,
		TextColor3 = Theme.color.bg,
		BackgroundColor3 = color or Theme.color.accent,
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.new(0.5, 0, 1, 60),
		AnchorPoint = Vector2.new(0.5, 1),
		Parent = parent,
	}, { C.corner(Theme.radius.pill), C.padding(Theme.pad.md) })
	TweenService
		:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 1, -24),
		})
		:Play()
	task.delay(2.2, function()
		local t = TweenService:Create(toast, TweenInfo.new(0.3), {
			Position = UDim2.new(0.5, 0, 1, 60),
			TextTransparency = 1,
			BackgroundTransparency = 1,
		})
		t.Completed:Connect(function()
			toast:Destroy()
		end)
		t:Play()
	end)
end

return C
