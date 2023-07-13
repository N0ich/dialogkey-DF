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
		dontPostAuctions = true,
		ignoreWithModifier = false,
		showErrorMessage = true,
		-- keyCooldown = 0.5
	}
}

-- Using #info here so that the option toggles/buttons/etc can be placed anywhere in the tree below and correctly update the option above via name matching.
local function optionSetter(info, val) DialogKey.db.global[info[#info]] = val end
local function optionGetter(info) return DialogKey.db.global[info[#info]] end

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
		subgroup1 = {
			order = 1,
			name = "General",
			desc = "Basic Options for personal preferences",
			type = "group",
			args = {
				showGlow = {
					order = 1,
					name = "|cffffd100Enable Glow|r",
					desc = "Show the glow effect when DialogKey clicks a button",
					descStyle = "inline", width = "full", type = "toggle", set = optionSetter, get = optionGetter, -- TODO figure out how to get these to inherit?
				};
				numKeysForGossip = {
					order = 2,
					name = "|cffffd100Numkeys for Gossip|r",
					desc = "Use the number keys (1 thru 0) to select Gossip options or Quests from an NPC dialog window",
					descStyle = "inline", width = "full", type = "toggle", set = optionSetter, get = optionGetter,
				};
				numKeysForQuestRewards = {
					order = 3,
					name = "|cffffd100Numkeys for Quest Rewards|r",
					desc = "Use the number keys (1 thru 0) to select Quest rewards when multiple are available",
					descStyle = "inline", width = "full", type = "toggle", set = optionSetter, get = optionGetter,
				};
				dontPostAuctions = {
					order = 4,
					name = "|cffffd100Don't Post Auctions|r",
					desc = "Don't allow DialogKey to Post Auctions",
					descStyle = "inline", width = "full", type = "toggle", set = optionSetter, get = optionGetter,
				};
				dontAcceptInvite = {
					order = 5,
					name = "|cffffd100Don't Accept Group Invites|r",
					desc = "Don't allow DialogKey to accept Raid/Party Invitations",
					descStyle = "inline", width = "full", type = "toggle", set = optionSetter, get = optionGetter,
				};
				dontClickSummons = {
					order = 6,
					name = "|cffffd100Don't Accept Summons|r",
					desc = "Don't allow DialogKey to accept Summon Requests",
					descStyle = "inline", width = "full", type = "toggle", set = optionSetter, get = optionGetter,
				};
				dontClickDuels = {
					order = 7,
					name = "|cffffd100Don't Accept Duels|r",
					desc = "Don't allow DialogKey to accept Duel Requests",
					descStyle = "inline", width = "full", type = "toggle", set = optionSetter, get = optionGetter,
				};
				dontClickRevives = {
					order = 8,
					name = "|cffffd100Don't Accept Revives|r",
					desc = "Don't allow DialogKey to accept Resurrections",
					descStyle = "inline", width = "full", type = "toggle", set = optionSetter, get = optionGetter,
				};
				dontClickReleases = {
					order = 9,
					name = "|cffffd100Don't Release Spirit|r",
					desc = "Don't allow DialogKey to Release Spirit",
					descStyle = "inline", width = "full", type = "toggle", set = optionSetter, get = optionGetter,
				};
				useSoulstoneRez = {
					order = 10,
					name = "|cffffd100Use Class-specific Revive|r",
					desc = "Use Soulstone/Ankh/etc. resurrection option when one is available and a normal/battle resurrection is not\n\nThis option |cffff0000ignores|r the |cffffd100Don't Accept Revives|r option!",
					descStyle = "inline", width = "full", type = "toggle", set = optionSetter, get = optionGetter,
				};
			}
		};
		subgroup2 = {
			order = 2,
			name = "Priority",
			desc = "Advanced Options to control DialogKey button priority",
			type = "group",
			args = {
				ignoreWithModifier = {
					order = 1,
					name = "|cffffd100Ignore DialogKey with Modifiers|r",
					desc = "Disable DialogKey while any modifier key is held (Shift, Alt, Ctrl)",
					descStyle = "inline", width = "full", type = "toggle", set = optionSetter, get = optionGetter,
				};
				ignoreDisabledButtons = {
					order = 2,
					name = "|cffffd100Ignore Disabled Buttons|r",
					desc = "Don't allow DialogKey to click on disabled (greyed out) buttons",
					descStyle = "inline", width = "full", type = "toggle", set = optionSetter, get = optionGetter,
				};
				showErrorMessage = {
					order = 3,
					name = "|cffffd100Capture Broken Inputs|r",
					desc = "When DialogKey attempts to click a button known to cause a Lua error when clicked by addons, capture this input as if the button was clicked and display an error message in the chat box",
					descStyle = "inline", width = "full", type = "toggle", set = optionSetter, get = optionGetter,
				};
				temp = {
					order = 4,
					name = "=== Advanced Priority Customization NYI ===",
					type = "description",
					fontSize = "medium",
				};
			}
		};
		subgroup3 = {
			order = 3,
			name = "Custom Watchlist",
			desc = "List of custom buttons for DialogKey to attempt to click",
			type = "group",
			args = {
				temp = {
					order = 1,
					name = "=== Custom Watchlist NYI ===",
					type = "description",
					fontSize = "medium",
				};
			}
		};
		subgroup4 = {
			order = 4,
			name = "Popup Blacklist",
			desc = "List of popup dialogs for DialogKey to completely ignore",
			type = "group",
			args = {
				temp = {
					order = 1,
					name = "=== Custom Popup Blacklist NYI ===",
					type = "description",
					fontSize = "medium",
				};
			}
		};
	}
}
