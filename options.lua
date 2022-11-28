defaultOptions = {
	global = {
		keys = {
			"SPACE",
		},
		ignoreDisabledButtons = false,
		showGlow = true,
		dialogBlacklist = {},
		numKeysForGossip = true,
		numKeysForQuestRewards = true,
		dontClickSummons = false,
		dontClickDuels = false,
		dontClickRevives = false,
		dontClickReleases = false,
		useSoulstoneRez = true,
		dontAcceptInvite = false,
		-- keyCooldown = 0.5
	}
}

local function optionSetter(info, val) DialogKey.db.global[info[1]] = val end
local function optionGetter(info) return DialogKey.db.global[info[1]] end

-- BIG Todo: Localization options!!
interfaceOptions = {
	type = "group",
	args = {
		header1 = {
			order = 1,
			name = "Primary Keybinds",
			type = "header",
		};
		key1 = {
			order = 2,
			name = "",
			type = "keybinding",
			set = (function(info, val) DialogKey.db.global.keys[1] = val end),
			get = (function(info) return DialogKey.db.global.keys[1] end),
		};
		key2 = {
			order = 3,
			name = "",
			type = "keybinding",
			set = (function(info, val) DialogKey.db.global.keys[2] = val end),
			get = (function(info) return DialogKey.db.global.keys[2] end),
		};

		header2 = {
			order = 4,
			name = "Options",
			type = "header",
		};
		showGlow = {
			order = 5,
			name = "|cffffd100Enable Glow|r",
			desc = "Show the glow effect when DialogKey clicks a button",
			descStyle = "inline", width = "full", type = "toggle", set = optionSetter, get = optionGetter, -- TODO figure out how to get these to inherit?
		};
		ignoreDisabledButtons = {
			order = 6,
			name = "|cffffd100Ignore Disabled Buttons|r",
			desc = "Don't allow DialogKey to click on disabled (greyed out) buttons",
			descStyle = "inline", width = "full", type = "toggle", set = optionSetter, get = optionGetter,
		};
		numKeysForGossip = {
			order = 7,
			name = "|cffffd100Numkeys for Gossip|r",
			desc = "Use the number keys (1 thru 0) to select Gossip options or Quests from an NPC dialog window",
			descStyle = "inline", width = "full", type = "toggle", set = optionSetter, get = optionGetter,
		};
		numKeysForQuestRewards = {
			order = 8,
			name = "|cffffd100Numkeys for Quest Rewards|r",
			desc = "Use the number keys (1 thru 0) to select Quest rewards when multiple are available",
			descStyle = "inline", width = "full", type = "toggle", set = optionSetter, get = optionGetter,
		};
		dontAcceptInvite = {
			order = 9,
			name = "|cffffd100Don't Accept Group Invites|r",
			desc = "Don't allow DialogKey to accept Raid/Party Invitations",
			descStyle = "inline", width = "full", type = "toggle", set = optionSetter, get = optionGetter,
		};
		dontClickSummons = {
			order = 10,
			name = "|cffffd100Don't Accept Summons|r",
			desc = "Don't allow DialogKey to accept Summon Requests",
			descStyle = "inline", width = "full", type = "toggle", set = optionSetter, get = optionGetter,
		};
		dontClickDuels = {
			order = 11,
			name = "|cffffd100Don't Accept Duels|r",
			desc = "Don't allow DialogKey to accept Duel Requests",
			descStyle = "inline", width = "full", type = "toggle", set = optionSetter, get = optionGetter,
		};
		dontClickRevives = {
			order = 12,
			name = "|cffffd100Don't Accept Revives|r",
			desc = "Don't allow DialogKey to accept Resurrections",
			descStyle = "inline", width = "full", type = "toggle", set = optionSetter, get = optionGetter,
		};
		dontClickReleases = {
			order = 13,
			name = "|cffffd100Don't Release Spirit|r",
			desc = "Don't allow DialogKey to Release Spirit",
			descStyle = "inline", width = "full", type = "toggle", set = optionSetter, get = optionGetter,
		};
		useSoulstoneRez = {
			order = 14,
			name = "|cffffd100Use Class-specific Revive|r",
			desc = "Use Soulstone/Ankh/etc. resurrection option when available and a normal revive is not\nThis option |cffff0000ignores|r the Don't Accept Revives option!"
			descStyle = "inline", width = "full", type = "toggle", set = optionSetter, get = optionGetter,
		};
		

		header3 = {
			order = 15,
			name = "Priority Options",
			type = "header",
			desc = "NYI",
		};
		header4 = {
			order = 16,
			name = "Custom Button Watchlist",
			type = "header",
			desc = "NYI",
		};
		header5 = {
			order = 17,
			name = "Custom Popup Blacklist",
			type = "header",
			desc = "NYI",
		};
	}
}