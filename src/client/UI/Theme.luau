--!strict
-- Shared visual language for the World Cup Brainrot UI.
-- Pure data + a couple of tiny pure helpers (no Instances created here) so it can be
-- required by every controller and even reasoned about in isolation.

export type RarityName = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic"

local Theme = {}

-- Core palette (dark "stadium at night" base + bold accents).
Theme.color = {
	bg = Color3.fromHex("0E1116"),
	surface = Color3.fromHex("1A1F29"),
	surfaceAlt = Color3.fromHex("232A36"),
	stroke = Color3.fromHex("313A49"),
	text = Color3.fromHex("F5F7FA"),
	textDim = Color3.fromHex("9AA7B8"),
	accent = Color3.fromHex("FFD23F"), -- primary CTA (gold)
	accent2 = Color3.fromHex("2EE6A6"), -- secondary (mint)
	danger = Color3.fromHex("FF4D6D"),
	success = Color3.fromHex("38E08B"),
	warning = Color3.fromHex("FFA63F"),
	overlay = Color3.fromHex("000000"),
}

-- Per-rarity accent colour (used by card tiles, glows, labels).
Theme.rarity = {
	Common = Color3.fromHex("9AA7B8"),
	Uncommon = Color3.fromHex("4CD964"),
	Rare = Color3.fromHex("3B9DFF"),
	Epic = Color3.fromHex("B36BFF"),
	Legendary = Color3.fromHex("FFB23F"),
	Mythic = Color3.fromHex("FF4D6D"),
}

Theme.font = {
	display = Enum.Font.GothamBlack,
	heading = Enum.Font.GothamBold,
	body = Enum.Font.Gotham,
	bodyBold = Enum.Font.GothamMedium,
}

-- Spacing / radius scale (pixels).
Theme.pad = { xs = 4, sm = 8, md = 12, lg = 16, xl = 24 }
Theme.radius = { sm = 6, md = 10, lg = 16, pill = 999 }
Theme.text = { sm = 14, md = 18, lg = 24, xl = 34 }

function Theme.rarityColor(rarity: string): Color3
	return (Theme.rarity :: { [string]: Color3 })[rarity] or Theme.color.textDim
end

return Theme
