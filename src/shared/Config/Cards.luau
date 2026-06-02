--!strict
-- Seed card catalogue. Pure data (no requires) -> Lune-testable.
-- IDENTITY RULE: `nation` uses real countries (allowed). `name` is an ORIGINAL
-- parody/brainrot character -- never a real player's name or likeness.
-- `imageId` is "" until generated art is uploaded to Roblox (rbxassetid://...).

type CardDef = {
	id: string,
	name: string,
	nation: string,
	rarity: string,
	basePower: number,
	imageId: string,
}

local Cards: { CardDef } = {
	-- Common
	{
		id = "fr_baguette_bombardino",
		name = "Baguette Bombardino",
		nation = "France",
		rarity = "Common",
		basePower = 10,
		imageId = "",
	},
	{
		id = "br_samba_crocodilo",
		name = "Samba Crocodilo",
		nation = "Brésil",
		rarity = "Common",
		basePower = 11,
		imageId = "",
	},
	{
		id = "it_pizzaiolo_tralala",
		name = "Pizzaïolo Tralala",
		nation = "Italie",
		rarity = "Common",
		basePower = 9,
		imageId = "",
	},

	-- Uncommon
	{
		id = "ar_mate_tornado",
		name = "Maté Tornado",
		nation = "Argentine",
		rarity = "Uncommon",
		basePower = 18,
		imageId = "",
	},
	{
		id = "de_bratwurst_blitz",
		name = "Bratwurst Blitz",
		nation = "Allemagne",
		rarity = "Uncommon",
		basePower = 19,
		imageId = "",
	},
	{
		id = "en_teatime_goblin",
		name = "Tea-Time Goblin",
		nation = "Angleterre",
		rarity = "Uncommon",
		basePower = 17,
		imageId = "",
	},

	-- Rare
	{
		id = "es_churro_matador",
		name = "Churro Matador",
		nation = "Espagne",
		rarity = "Rare",
		basePower = 30,
		imageId = "",
	},
	{
		id = "pt_bacalhau_phantom",
		name = "Bacalhau Phantom",
		nation = "Portugal",
		rarity = "Rare",
		basePower = 31,
		imageId = "",
	},
	{
		id = "nl_tulipe_cyclone",
		name = "Tulipe Cyclone",
		nation = "Pays-Bas",
		rarity = "Rare",
		basePower = 29,
		imageId = "",
	},

	-- Epic
	{
		id = "hr_damier_vortex",
		name = "Damier Vortex",
		nation = "Croatie",
		rarity = "Epic",
		basePower = 48,
		imageId = "",
	},
	{
		id = "ma_atlas_mirage",
		name = "Atlas Mirage",
		nation = "Maroc",
		rarity = "Epic",
		basePower = 50,
		imageId = "",
	},

	-- Legendary
	{
		id = "jp_sakura_kaiju",
		name = "Sakura Kaiju",
		nation = "Japon",
		rarity = "Legendary",
		basePower = 75,
		imageId = "",
	},
	{
		id = "sn_teranga_titan",
		name = "Téranga Titan",
		nation = "Sénégal",
		rarity = "Legendary",
		basePower = 78,
		imageId = "",
	},

	-- Mythic
	{
		id = "br_rei_do_caos",
		name = "Rei do Caos",
		nation = "Brésil",
		rarity = "Mythic",
		basePower = 110,
		imageId = "",
	},
	{
		id = "fr_coq_cosmique",
		name = "Le Coq Cosmique",
		nation = "France",
		rarity = "Mythic",
		basePower = 112,
		imageId = "",
	},
}

return Cards
