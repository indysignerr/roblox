--!strict
-- Canonical shared types. Required by Services via instance path.
-- (Pure logic + config modules avoid requiring this so they stay Lune-testable.)

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic"

-- Aura: 0 (none) .. 5 (max), see GameConfig / Rarities.auraMaxLevel
export type AuraLevel = number

export type CardDef = {
	id: string,
	name: string,
	nation: string,
	rarity: Rarity,
	basePower: number,
	imageId: string,
}

export type OwnedCard = {
	cardId: string,
	count: number,
	aura: AuraLevel,
}

export type ShieldState = {
	active: boolean,
	expiresAt: number,
}

export type StreakState = {
	current: number,
	lastClaimDay: number,
}

export type TeamRole = "Manager" | "Captain" | "Player"

export type ProfileData = {
	coins: number,
	cards: { [string]: OwnedCard },
	shield: ShieldState,
	streak: StreakState,
	teamId: string?,
	-- When the player last left a team (unix seconds); nil = never. Drives the leave cooldown.
	lastTeamLeaveAt: number?,
	unlockedZones: { [string]: boolean },
	lastDailyPackDay: number,
	-- Server-granted credits for the Robux-gated "spy" reveal (one credit = one reveal).
	spyCredits: number,
	stats: {
		steals: number,
		stolenFrom: number,
		fusions: number,
		wins: number,
	},
	createdAt: number,
}

return {}
