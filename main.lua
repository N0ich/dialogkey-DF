DialogKey = LibStub("AceAddon-3.0"):NewAddon("DialogKey")

builtinDialogBlacklist = { -- If a confirmation dialog contains one of these strings, don't accept it
	"Are you sure you want to go back to Shal'Aran?", -- Withered Training Scenario
	"Are you sure you want to return to your current timeline?", -- Leave Chromie Time
	"You will be removed from Timewalking Campaigns once you use this scroll.", -- "A New Adventure Awaits" Chromie Time scroll
	"Resurrection in", -- Prevents cancelling the resurrection
	"Are you sure you wish to spend", -- Upgrade item is a protected func
	TOO_MANY_LUA_ERRORS,
	END_BOUND_TRADEABLE,
	ADDON_ACTION_FORBIDDEN,
}

-- Thanks, [github]@mbattersby
-- Prefix list of GossipFrame(!!) options with 1., 2., 3. etc.
local function GossipDataProviderHook(frame)
	local dp = frame.GreetingPanel.ScrollBox:GetDataProvider()

	if DialogKey.db.global.numKeysForGossip then
		local n = 1
		for _, item in ipairs(dp.collection) do
			local tag
			if item.buttonType == GOSSIP_BUTTON_TYPE_OPTION then
				tag = "name"
			elseif item.buttonType == GOSSIP_BUTTON_TYPE_ACTIVE_QUEST or
				   item.buttonType == GOSSIP_BUTTON_TYPE_AVAILABLE_QUEST then
				tag = "title"
			end

			if tag then
				local dedup = item.info[tag]:match("^%d+%. (.+)") or item.info[tag]
				item.info[tag] = n%10 .. ". " .. dedup
				n = n + 1
			end
			if n > 10 then break end
		end
	end

	frame.GreetingPanel.ScrollBox:SetDataProvider(dp)
end

function DialogKey:OnInitialize()
	if C_AddOns.IsAddOnLoaded("Immersion") then
		self:print("Immersion AddOn detected.")
		self:print("The Immersion addon is known to conflict with DialogKey!")
		self:print("Please check your addon settings before reporting bugs.")
	end

	-- defaultOptions defined in `options.lua`
	self.db = LibStub("AceDB-3.0"):New("DialogKeyDFDB", defaultOptions, true)
	
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
	self.frame:RegisterEvent("QUEST_COMPLETE")
	self.frame:RegisterEvent("PLAYER_REGEN_DISABLED")
	self.frame:SetScript("OnEvent", function(__, event, ...)
		if event == "QUEST_COMPLETE" then
			DialogKey.itemChoice = (GetNumQuestChoices() > 1 and -1 or 1)
		elseif event == "PLAYER_REGEN_DISABLED" then
			-- Disable DialogKey fully upon entering combat
			-- Fixes Battle Rezzes breaking all inputs!
			self.frame:SetPropagateKeyboardInput(true)
		else
			self:EnumerateGossips( event == "GOSSIP_SHOW" )
		end
	end);

	hooksecurefunc("QuestInfoItem_OnClick", DialogKey.SelectItemReward)
	self.frame:SetScript("OnKeyDown", DialogKey.HandleKey)

	hooksecurefunc(GossipFrame, "Update", GossipDataProviderHook) -- Thanks, [github]@mbattersby

	self.frame:SetFrameStrata("TOOLTIP") -- Ensure we receive keyboard events first
	self.frame:EnableKeyboard(true)
	self.frame:SetPropagateKeyboardInput(true)

	-- interfaceOptions defined in `options.lua`
	LibStub("AceConfig-3.0"):RegisterOptionsTable("DialogKey", interfaceOptions)
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions("DialogKey")
end

-- Internal/Private Functions --

local function ignoreInput()
	-- Blizz locked SetPropagateKeyBoardInput while in combat! :(
	-- TODO: figure out if there is a way to intentionally propagate a keyboard event without modifying the frame
	if InCombatLockdown() then return true end

	DialogKey.frame:SetPropagateKeyboardInput(true)
	-- Ignore input while typing, unless at the Send Mail confirmation while typing into it!
	local focus = GetCurrentKeyBoardFocus()
	if DialogKey.db.global.ignoreWithModifier and (IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown()) then return true end
	if focus and not (StaticPopup1:IsVisible() and (focus:GetName() == "SendMailNameEditBox" or focus:GetName() == "SendMailSubjectEditBox")) then return true end 

	-- Ignore input if there's something for DialogKey to click
	if not GossipFrame:IsVisible() and not QuestFrame:IsVisible() and not StaticPopup1:IsVisible()
		-- Ignore input if the Auction House sell frame is not open
	and (not AuctionHouseFrame or not AuctionHouseFrame:IsVisible()) then return true end

	return false
end

-- Primary functions --

-- Takes a global string like '%s has challenged you to a duel.' and converts it to a format suitable for string.find
local summon_match = CONFIRM_SUMMON:gsub("%%s", ".+"):gsub("%%d", ".+")
local duel_match = DUEL_REQUESTED:gsub("%%s",".+")
local resurrect_match = RESURRECT_REQUEST_NO_SICKNESS:gsub("%%s", ".+")
local groupinvite_match = INVITATION:gsub("%%s", ".+")

local function getPopupButton()
	-- Don't accept group invitations if the option is enabled
	if DialogKey.db.global.dontAcceptInvite and StaticPopup1Text:GetText():find(groupinvite_match) then return end

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
		text = text:gsub("%%s", ""):gsub("%W", "%%%0") -- Prepend non-alphabetical characters with '%' to escape them
		if dialog:find(text:lower()) then return end
	end

	for _, text in pairs(builtinDialogBlacklist) do
		text = text:gsub("%%s", ""):gsub("%W", "%%%0") -- Prepend non-alphabetical characters with '%' to escape them
		if dialog:find(text:lower()) then
			return nil, true
		end
	end

	return StaticPopup1Button1
end

function DialogKey:HandleKey(key)
	if ignoreInput() then return end

	local doAction = (key == DialogKey.db.global.keys[1] or key == DialogKey.db.global.keys[2])
	local keynum = doAction and 1 or tonumber(key)
	if key == "0" then
		keynum = 10
	end
	-- DialogKey pressed, interact with popups, accepts..
	if doAction then

		-- Click Popup
		-- TODO: StaticPopups 2-3 might have clickable buttons, enable them to be clicked?
		if StaticPopup1:IsVisible() then
			button, builtinBlacklist = getPopupButton()
			if button and (button:IsEnabled() or not DialogKey.db.global.ignoreDisabledButtons) then
				DialogKey.frame:SetPropagateKeyboardInput(false)
				DialogKey:Glow(button)
				button:Click()
				return
			elseif builtinBlacklist then -- if DialogKey isn't allowed to click a particular button
				if DialogKey.db.global.showErrorMessage then -- capture the input and display an error message
					DialogKey:print("|cffff3333This dialog cannot be clicked by DialogKey. Sorry!|r")
					DialogKey.frame:SetPropagateKeyboardInput(false)
				else -- or just do nothing :shrug:
					DialogKey.frame:SetPropagateKeyboardInput(true)
				end
				return
			end
		end

		-- Auction House
		if not DialogKey.db.global.dontPostAuctions and AuctionHouseFrame and AuctionHouseFrame:IsVisible() then
			if AuctionHouseFrame.displayMode == AuctionHouseFrameDisplayMode.CommoditiesSell then
				DialogKey.frame:SetPropagateKeyboardInput(false)
				DialogKey:Glow(AuctionHouseFrame.CommoditiesSellFrame.PostButton)
				AuctionHouseFrame.CommoditiesSellFrame:PostItem()
				return
			elseif AuctionHouseFrame.displayMode == AuctionHouseFrameDisplayMode.ItemSell then
				DialogKey.frame:SetPropagateKeyboardInput(false)
				DialogKey:Glow(AuctionHouseFrame.ItemSellFrame.PostButton)
				AuctionHouseFrame.ItemSellFrame:PostItem()
				return
			end
		end

		-- Complete Quest
		if QuestFrameProgressPanel:IsVisible() then
				DialogKey.frame:SetPropagateKeyboardInput(false)
			if not QuestFrameCompleteButton:IsEnabled() and DialogKey.db.global.ignoreDisabledButtons then
				-- click "Cencel" button when "Complete" is disabled on progress panel
				DialogKey:Glow(QuestFrameGoodbyeButton)
				CloseQuest()
			else
				DialogKey:Glow(QuestFrameCompleteButton)
				CompleteQuest()
			end
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
			if DialogKey.itemChoice == -1 and GetNumQuestChoices() > 1 then
				QuestChooseRewardError()
			else
				DialogKey:Glow(QuestFrameCompleteQuestButton)
				GetQuestReward(DialogKey.itemChoice)
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
	if (doAction or DialogKey.db.global.numKeysForGossip) and QuestFrameGreetingPanel:IsVisible() and DialogKey.frame then
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
	if DialogKey.db.global.numKeysForQuestRewards and keynum and keynum <= GetNumQuestChoices() and QuestFrameRewardPanel:IsVisible() then
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

-- Prefix list of QuestGreetingFrame(!!) options with 1., 2., 3. etc.
-- Also builds DialogKey.frames, used to click said options
function DialogKey:EnumerateGossips(isGossipFrame)
	if not ( QuestFrameGreetingPanel:IsVisible() or GossipFrame.GreetingPanel:IsVisible() ) then return end

	-- If anyone reading this comment is or knows someone on the WoW UI team, please send them this Addon and
	--   show them this function and then please ask them to (politely) slap whoever decided that:
	--   (1) ObjectPool's `activeObjects` *had* to be a dictionary
	--   (2) :GetChildren() should return an unpacked list of the sub-objects instead of, you know, a Table.
	--   :)
	-- FuriousProgrammer
local tab = {}
	DialogKey.frames = {}
	if isGossipFrame then
		for _, v in pairs{ GossipFrame.GreetingPanel.ScrollBox.ScrollTarget:GetChildren() } do
			tab[v] = true
		end
	else
		if QuestFrameGreetingPanel and QuestFrameGreetingPanel.titleButtonPool then
			for tab in QuestFrameGreetingPanel.titleButtonPool:EnumerateActive() do
				if tab:GetObjectType() == "Button" then
					table.insert(DialogKey.frames, tab)
				end
			end
		elseif QuestFrameGreetingPanel and not QuestFrameGreetingPanel.titleButtonPool then
			local children = { QuestGreetingScrollChildFrame:GetChildren() }
			for i, c in ipairs(children) do
				if c:GetObjectType() == "Button" and c:IsVisible() then
					table.insert(DialogKey.frames, c)
				end
			end
		else
			return
		end
	end

	for v in next, tab do
		if v:GetObjectType() == "Button" and v:IsVisible() then
			table.insert(DialogKey.frames, v)
		end
	end

	table.sort(DialogKey.frames, function(a,b) 
		if a.GetOrderIndex then
			return a:GetOrderIndex() < b:GetOrderIndex()
		else
			return a:GetTop() > b:GetTop()
		end
	end)

	if DialogKey.db.global.numKeysForGossip and not isGossipFrame then
		for i, frame in ipairs(DialogKey.frames) do
			if i > 10 then break end
			frame:SetText(i%10 .. ". " .. frame:GetText())

			-- Make the button taller if the text inside is wrapped to multiple lines
			frame:SetHeight(frame:GetFontString():GetHeight()+2)
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
end

-- Recursively print a table
function DialogKey:print_r (t)
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
