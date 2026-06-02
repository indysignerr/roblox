--!strict
-- Original parody emote/taunt definitions for the Social system.
-- IDENTITY RULE: all emotes are original fictional actions -- never real players' names or likenesses.

type EmoteDef = {
	id: string,
	label: string,
}

local EmoteConfig: { EmoteDef } = {
	{ id = "mega_celebration", label = "Méga Célébration" },
	{ id = "robot_dance", label = "Danse Robotique" },
	{ id = "crown_flex", label = "Flex Couronne" },
	{ id = "taunt_wave", label = "Vague Provoc" },
	{ id = "cosmic_spin", label = "Spin Cosmique" },
	{ id = "victory_stomp", label = "Piétinement Victoire" },
	{ id = "brainrot_shuffle", label = "Brainrot Shuffle" },
	{ id = "card_flip_sneer", label = "Reniflement Carte" },
}

return EmoteConfig
