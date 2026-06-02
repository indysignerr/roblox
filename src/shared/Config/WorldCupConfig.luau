--!strict
-- WorldCupConfig: the data shown on the in-stadium scoreboard jumbotron.
-- Pure data (no requires) -> Lune-testable, and easy for you to hand-edit.
--
-- ┌─────────────────────────────────────────────────────────────────────────┐
-- │ POUR METTRE À JOUR LES SCORES :                                           │
-- │  1. Modifie les lignes `matches` ci-dessous (scores, statut, équipes).    │
-- │  2. Sauvegarde ce fichier.                                                │
-- │  3. Dans Roblox Studio : Stop puis Play (les scripts ne se rechargent     │
-- │     pas en cours de partie — il faut relancer).                           │
-- │                                                                           │
-- │  status accepte : "FINISHED" (fini), "LIVE" (en direct), "UPCOMING"       │
-- │  (à venir). Les noms d'équipes sont de VRAIS pays — c'est autorisé.       │
-- └─────────────────────────────────────────────────────────────────────────┘

export type Match = {
	stage: string, -- ex: "Quart", "Demi", "Finale", "Groupe A"
	home: string, -- pays (vrai nom autorisé)
	homeScore: number?, -- nil si pas encore joué
	away: string,
	awayScore: number?,
	status: string, -- "FINISHED" | "LIVE" | "UPCOMING"
}

export type Config = {
	title: string,
	subtitle: string,
	matches: { Match },
}

local WorldCupConfig: Config = {
	title = "COUPE DU MONDE",
	subtitle = "BRAINROT CUP 2026",

	-- ▼▼▼ ÉDITE CETTE LISTE APRÈS CHAQUE MATCH ▼▼▼
	matches = {
		{
			stage = "Quart",
			home = "France",
			homeScore = 2,
			away = "Brésil",
			awayScore = 1,
			status = "FINISHED",
		},
		{
			stage = "Quart",
			home = "Argentine",
			homeScore = 3,
			away = "Espagne",
			awayScore = 0,
			status = "FINISHED",
		},
		{
			stage = "Demi",
			home = "Maroc",
			homeScore = 1,
			away = "Portugal",
			awayScore = 1,
			status = "LIVE",
		},
		{
			stage = "Demi",
			home = "Allemagne",
			homeScore = nil,
			away = "Sénégal",
			awayScore = nil,
			status = "UPCOMING",
		},
		{
			stage = "Finale",
			home = "?",
			homeScore = nil,
			away = "?",
			awayScore = nil,
			status = "UPCOMING",
		},
	},
	-- ▲▲▲ ÉDITE CETTE LISTE APRÈS CHAQUE MATCH ▲▲▲
}

return WorldCupConfig
