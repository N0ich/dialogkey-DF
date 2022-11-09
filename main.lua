DialogKey = LibStub("AceAddon-3.0"):NewAddon("DialogKey")

local defaults = {
	global = {
		keys = {
			"SPACE",
		},
		ignoreDisabledButtons = true,
		showGlow = true,
		dialogBlacklist = {},
		numKeysForGossip = true,
		numKeysForQuestRewards = true,
		dontClickSummons = false,
		dontClickDuels = false,
		dontClickRevives = false,
		dontClickReleases = false,
		useSoulstoneRez = true,
		-- keyCooldown = 0.5
	}
}

DialogKey.builtinDialogBlacklist = { -- If a confirmation dialog contains one of these strings, don't accept it
	"Are you sure you want to go back to Shal'Aran?", -- Seems to bug out and not work if an AddOn clicks the confirm button?
}

function DialogKey:OnInitialize()
	-- TODO: re-enable AceDB once options panel is fixed
	-- self.db = LibStub("AceDB-3.0"):New("DialogKeyDB", defaults, true)
	self.db = defaults
	-- self.keybindMode = false -- TODO: reimplement keybinding w/ options update
	-- self.keybindIndex = 0
	-- self.recentlyPressed = false -- TODO: reimplement "recently pressed" keyboard propogation delay

	self.glowFrame = CreateFrame("Frame", "DialogKeyGlow", UIParent)
	self.glowFrame:SetPoint("CENTER", 0, 0)
	self.glowFrame:SetFrameStrata("TOOLTIP")
	self.glowFrame:SetSize(50,50)
	self.glowFrame:SetScript("OnUpdate", DialogKey.GlowFrameUpdate)
	self.glowFrame:Hide()
	self.glowFrame.tex = self.glowFrame:CreateTexture()
	self.glowFrame.tex:SetAllPoints()
	self.glowFrame.tex:SetColorTexture(1,1,0,0.5)

	self.frame = CreateFrame("Frame", "DialogKeyFrame", UIParent)
	self.frame:RegisterEvent("GOSSIP_SHOW")
	self.frame:RegisterEvent("QUEST_GREETING")
	self.frame:SetScript("OnEvent", function(__, event, ...)
		self:EnumerateGossips( event == "GOSSIP_SHOW" )
	end);

	hooksecurefunc("QuestInfoItem_OnClick", DialogKey.SelectItemReward)
	self.frame:SetScript("OnKeyDown", DialogKey.HandleKey)


	self.frame:SetFrameStrata("TOOLTIP") -- Ensure we receive keyboard events first
	self.frame:EnableKeyboard(true)
	self.frame:SetPropagateKeyboardInput(true)
end

-- Internal/Private Functions --

local function ignoreInput()
	DialogKey.frame:SetPropagateKeyboardInput(true)
	-- TODO: ignore input while setting keybinds

	-- Ignore input while typing, unless at the Send Mail confirmation while typing into it!
	local focus = GetCurrentKeyBoardFocus()
	if focus and not (StaticPopup1:IsVisible() and (focus:GetName() == "SendMailNameEditBox" or focus:GetName() == "SendMailSubjectEditBox")) then return true end 

	-- Ignore input if there's something for DialogKey to click
	if not GossipFrame:IsVisible() and not QuestFrame:IsVisible() and not StaticPopup1:IsVisible() then return true end

	return false
end

-- Primary functions --

-- Takes a global string like '%s has challenged you to a duel.' and converts it to a format suitable for string.find
local summon_match = CONFIRM_SUMMON:gsub("%%s", ".+"):gsub("%%d", ".+")
local duel_match = DUEL_REQUESTED:gsub("%%s",".+")
local resurrect_match = RESURRECT_REQUEST_NO_SICKNESS:gsub("%%s", ".+")
local function getPopupButton()
	-- Don't accept summons/duels/resurrects if the options are enabled
	if DialogKey.db.global.dontClickSummons and StaticPopup1Text:GetText():find(summon_match) then return end
	if DialogKey.db.global.dontClickDuels and StaticPopup1Text:GetText():find(duel_match) then return end

	-- If resurrect dialog has three buttons, and the option is enabled, use the middle one instead of the first one (soulstone, etc.)
	-- Located before resurrect/release checks/returns so it happens even if you have releases/revives disabled
	-- Also, Check if Button2 is visible instead of Button3 since Recap is always 3; 2 is hidden if you can't soulstone rez	
	
	-- the ordering here means that a revive will be taken before a battle rez before a release.
	-- if revives are disabled but soulstone battlerezzes *aren't*, nothing will happen if both are available!
	-- (originall DialogKey worked this way too, comment if you think this should be changed!)
	local canRelease = StaticPopup1Button1Text:GetText() == DEATH_RELEASE
	if DialogKey.db.global.useSoulstoneRez and canRelease and StaticPopup1Button2:IsVisible() then
		return StaticPopup1Button2
	end

	if DialogKey.db.global.dontClickRevives and (StaticPopup1Text:GetText() == RECOVER_CORPSE or StaticPopup1Text:GetText():find(resurrect_match)) then return end
	if DialogKey.db.global.dontClickReleases and canRelease then return end

	-- Ignore blacklisted popup dialogs!
	local dialog = StaticPopup1Text:GetText():lower()
	for _, text in pairs(DialogKey.db.global.dialogBlacklist) do
		if dialog:find(text:lower()) then return end
	end

	for _, text in pairs(DialogKey.builtinDialogBlacklist) do
		if dialog:find(text:lower()) then
			DialogKey:print("|cffff3333This dialog casts a spell and does not work with DialogKey. Sorry!|r")
			return
		end
	end

	return StaticPopup1Button1
end

function DialogKey:HandleKey(key)
	if ignoreInput() then return end

	local doAction = (key == DialogKey.db.global.keys[1] or key == DialogKey.db.global.keys[2])
	local keynum = doAction and 1 or tonumber(key)

	-- DialogKey pressed, interact with popups, accepts..
	if doAction then

		-- Click Popup
		-- TODO: StaticPopups 2-3 might have clickable buttons, enable them to be clicked?
		if StaticPopup1:IsVisible() then
			button = getPopupButton()
			if button and (button:IsEnabled() or not DialogKey.db.global.ignoreDisabledButtons) then
				DialogKey.frame:SetPropagateKeyboardInput(false)
				DialogKey:Glow(button)
				button:Click()
				return
			end
		end

		-- Complete Quest
		if QuestFrameProgressPanel:IsVisible() then
			if not QuestFrameCompleteButton:IsEnabled() and DialogKey.db.global.ignoreDisabledButtons then return end
			DialogKey.frame:SetPropagateKeyboardInput(false)
			DialogKey:Glow(QuestFrameCompleteButton)
			CompleteQuest()
			return

		-- Accept Quest
		elseif QuestFrameDetailPanel:IsVisible() then
			DialogKey.frame:SetPropagateKeyboardInput(false)
			DialogKey:Glow(QuestFrameAcceptButton)
			AcceptQuest()
			return

		-- Take Quest Reward
		elseif QuestFrameRewardPanel:IsVisible() then
			DialogKey.frame:SetPropagateKeyboardInput(false)
			if DialogKey.itemChoice == -1 and GetNumQuestChoices() > 0 then
				QuestChooseRewardError()
			else
				DialogKey:Glow(QuestFrameCompleteQuestButton)
				GetQuestReward(DialogKey.itemChoice)
				DialogKey.itemChoice = -1
			end
			return
		end
	end

	-- GossipFrame
	if (doAction or DialogKey.db.global.numKeysForGossip) and GossipFrame.GreetingPanel:IsVisible() then
		while keynum and keynum > 0 and keynum <= #DialogKey.frames do
			choice = DialogKey.frames[keynum].GetElementData()
			-- Skip grey quest (active but not completed) when pressing DialogKey
			if doAction and choice.info.questID and choice.activeQuestButton and not choice.info.isComplete and DialogKey.db.global.ignoreDisabledButtons then
				keynum = keynum + 1
			else
				DialogKey.frame:SetPropagateKeyboardInput(false)
				DialogKey:Glow(DialogKey.frames[keynum])
				DialogKey.frames[keynum]:Click()
				return
			end
		end
	end

	-- QuestFrame
	if (doAction or DialogKey.db.global.numKeysForGossip) and QuestFrameGreetingPanel:IsVisible()  then
		while keynum and keynum > 0 and keynum <= #DialogKey.frames do
			local title, is_complete = GetActiveTitle(keynum)
			if doAction and not is_complete and DialogKey.frames[keynum].isActive == 1 and DialogKey.db.global.ignoreDisabledButtons then
				keynum = keynum + 1
				if keynum > #DialogKey.frames then
					doAction = false
					keynum = 1
				end
			else
				DialogKey.frame:SetPropagateKeyboardInput(false)
				DialogKey:Glow(DialogKey.frames[keynum])
				DialogKey.frames[keynum]:Click()
				return
			end
		end	
	end

	-- QuestReward Frame (select item)
	if DialogKey.db.global.numKeysForQuestRewards and keynum and keynum <= GetNumQuestChoices() and QuestFrameCompleteQuestButton:IsVisible() then
		DialogKey.frame:SetPropagateKeyboardInput(false)
		DialogKey.itemChoice = keynum
		GetClickFrame("QuestInfoRewardsFrameQuestInfoItem" .. key):Click()
	end
end

-- QuestInfoItem_OnClick secure handler
-- allows DialogKey to update the selected quest reward when clicked as opposed to using a keybind.
function DialogKey:SelectItemReward()
	for i = 1, GetNumQuestChoices() do
		if GetClickFrame("QuestInfoRewardsFrameQuestInfoItem" .. i):IsMouseOver() then
			DialogKey.itemChoice = i
			break
		end
	end
end

-- Prefix list of Gossip/Quest options with 1., 2., 3. etc.
-- Also builds DialogKey.frames, used to click said options
function DialogKey:EnumerateGossips( isGossipFrame )
	if not ( QuestFrameGreetingPanel:IsVisible() or GossipFrame.GreetingPanel:IsVisible() ) then return end

	-- If anyone reading this comment is or knows someone on the WoW UI team, please send them this Addon and
	--   show them this function and then please ask them to (politely) slap whoever decided that:
	--   (1) ObjectPool's `activeObjects` *had* to be a dictionary
	--   (2) :GetChildren() should return an unpacked list of the sub-objects instead of, you know, a Table.
	--   :)
	-- FuriousProgrammer
	local tab
	if isGossipFrame then
		tab = {}
		for _, v in pairs{ GossipFrame.GreetingPanel.ScrollBox.ScrollTarget:GetChildren() } do
			tab[v] = true
		end
	else
		tab = QuestFrameGreetingPanel.titleButtonPool.activeObjects
		-- _, tab = QuestFrameGreetingPanel.titleButtonPool:EnumerateActive()
	end

	DialogKey.frames = {}
	for v in next, tab do
		if v:GetObjectType() == "Button" and v:IsVisible() then
			table.insert(DialogKey.frames, v)
		end
	end

	table.sort(DialogKey.frames, function(a,b) return a:GetTop() > b:GetTop() end)

	if DialogKey.db.global.numKeysForGossip then
		for i, frame in ipairs(DialogKey.frames) do
			frame:SetText(i .. ". " .. frame:GetText())
		end
	end
end

-- Glow Functions --
function DialogKey:Glow(frame, mode)
	if DialogKey.db.global.showGlow then
		self.glowFrame:SetAllPoints(frame)
		self.glowFrame.tex:SetColorTexture(1,1,0,0.5)
		self.glowFrame:Show()
		self.glowFrame:SetAlpha(1)
	end
end

-- Fades out the glow frame
function DialogKey:GlowFrameUpdate(delta)
	local alpha = self:GetAlpha() - delta*3
	if alpha < 0 then
		alpha = 0
	end
	self:SetAlpha(alpha)
	if self:GetAlpha() <= 0 then self:Hide() end
end

function DialogKey:print(message)
	DEFAULT_CHAT_FRAME:AddMessage("|cffd2b48c[DialogKey]|r "..message.."|r")
	DialogKey:Glow(DEFAULT_CHAT_FRAME)
end

-- Recursively print a table
function DialogKey:print_r ( t )
    local print_r_cache={}
    local function sub_print_r(t,indent)
        if (print_r_cache[tostring(t)]) then
            print(indent.."*"..tostring(t))
        else
            print_r_cache[tostring(t)]=true
            if (type(t)=="table") then
                for pos,val in pairs(t) do
                    if (type(val)=="table") then
                        print(indent.."["..pos.."] => "..tostring(t).." {")
                        sub_print_r(val,indent..string.rep(" ",string.len(pos)+8))
                        print(indent..string.rep(" ",string.len(pos)+6).."}")
                    else
                        print(indent.."["..pos.."] => "..tostring(val))
                    end
                end
            else
                print(indent..tostring(t))
            end
        end
    end
    sub_print_r(t,"  ")
end