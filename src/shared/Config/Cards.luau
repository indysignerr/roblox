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
	-- =========================================================
	-- COMMON  (~10 cards)  basePower 8-12
	-- =========================================================
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
	{
		id = "mx_taco_turbo",
		name = "Taco Turbo",
		nation = "Mexique",
		rarity = "Common",
		basePower = 8,
		imageId = "",
	},
	{
		id = "us_hotdog_hooligan",
		name = "Hotdog Hooligan",
		nation = "USA",
		rarity = "Common",
		basePower = 9,
		imageId = "",
	},
	{
		id = "ng_jollof_joker",
		name = "Jollof Joker",
		nation = "Nigéria",
		rarity = "Common",
		basePower = 10,
		imageId = "",
	},
	{
		id = "cm_ndolé_noodle",
		name = "Ndolé Noodle",
		nation = "Cameroun",
		rarity = "Common",
		basePower = 8,
		imageId = "",
	},
	{
		id = "be_waffle_wanderer",
		name = "Waffle Wanderer",
		nation = "Belgique",
		rarity = "Common",
		basePower = 11,
		imageId = "",
	},
	{
		id = "uy_mate_marmot",
		name = "Maté Marmot",
		nation = "Uruguay",
		rarity = "Common",
		basePower = 9,
		imageId = "",
	},
	{
		id = "gh_kenkey_goblin",
		name = "Kenkey Goblin",
		nation = "Ghana",
		rarity = "Common",
		basePower = 10,
		imageId = "",
	},

	-- =========================================================
	-- UNCOMMON  (~9 cards)  basePower 16-20
	-- =========================================================
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
	{
		id = "kr_kimchi_kicker",
		name = "Kimchi Kicker",
		nation = "Corée du Sud",
		rarity = "Uncommon",
		basePower = 16,
		imageId = "",
	},
	{
		id = "ma_couscous_crusader",
		name = "Couscous Crusader",
		nation = "Maroc",
		rarity = "Uncommon",
		basePower = 18,
		imageId = "",
	},
	{
		id = "hr_burek_bandit",
		name = "Burek Bandit",
		nation = "Croatie",
		rarity = "Uncommon",
		basePower = 17,
		imageId = "",
	},
	{
		id = "sn_thiebou_thunderbolt",
		name = "Thiebou Thunderbolt",
		nation = "Sénégal",
		rarity = "Uncommon",
		basePower = 20,
		imageId = "",
	},
	{
		id = "jp_ramen_ronin",
		name = "Ramen Ronin",
		nation = "Japon",
		rarity = "Uncommon",
		basePower = 16,
		imageId = "",
	},
	{
		id = "pt_pasteis_palhaço",
		name = "Pastéis Palhaço",
		nation = "Portugal",
		rarity = "Uncommon",
		basePower = 19,
		imageId = "",
	},

	-- =========================================================
	-- RARE  (~8 cards)  basePower 28-34
	-- =========================================================
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
	{
		id = "us_gridlock_striker",
		name = "Gridlock Striker",
		nation = "USA",
		rarity = "Rare",
		basePower = 28,
		imageId = "",
	},
	{
		id = "mx_piñata_predator",
		name = "Piñata Predator",
		nation = "Mexique",
		rarity = "Rare",
		basePower = 32,
		imageId = "",
	},
	{
		id = "de_schnitzel_sentinel",
		name = "Schnitzel Sentinel",
		nation = "Allemagne",
		rarity = "Rare",
		basePower = 34,
		imageId = "",
	},
	{
		id = "be_frites_phantom",
		name = "Frites Phantom",
		nation = "Belgique",
		rarity = "Rare",
		basePower = 30,
		imageId = "",
	},
	{
		id = "uy_asado_assassin",
		name = "Asado Assassin",
		nation = "Uruguay",
		rarity = "Rare",
		basePower = 33,
		imageId = "",
	},

	-- =========================================================
	-- EPIC  (~6 cards)  basePower 46-52
	-- =========================================================
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
	{
		id = "ar_gaucho_galaxia",
		name = "Gaucho Galaxia",
		nation = "Argentine",
		rarity = "Epic",
		basePower = 52,
		imageId = "",
	},
	{
		id = "kr_hanbok_havoc",
		name = "Hanbok Havoc",
		nation = "Corée du Sud",
		rarity = "Epic",
		basePower = 46,
		imageId = "",
	},
	{
		id = "it_colosseum_catapult",
		name = "Colosseum Catapult",
		nation = "Italie",
		rarity = "Epic",
		basePower = 49,
		imageId = "",
	},
	{
		id = "ng_afrobeat_avalanche",
		name = "Afrobeat Avalanche",
		nation = "Nigéria",
		rarity = "Epic",
		basePower = 51,
		imageId = "",
	},

	-- =========================================================
	-- LEGENDARY  (~4 cards)  basePower 72-80
	-- =========================================================
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
	{
		id = "es_matador_magnifico",
		name = "Matador Magnífico",
		nation = "Espagne",
		rarity = "Legendary",
		basePower = 72,
		imageId = "",
	},
	{
		id = "de_blitzkrieg_baron",
		name = "Blitzkrieg Baron",
		nation = "Allemagne",
		rarity = "Legendary",
		basePower = 80,
		imageId = "",
	},

	-- =========================================================
	-- MYTHIC  (~3 cards)  basePower 105-115
	-- =========================================================
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
	{
		id = "ar_dios_del_balon",
		name = "Dios del Balón",
		nation = "Argentine",
		rarity = "Mythic",
		basePower = 115,
		imageId = "",
	},
}

return Cards
