DialogKey = LibStub("AceAddon-3.0"):NewAddon("DialogKey", "AceConsole-3.0", "AceTimer-3.0", "AceEvent-3.0")

local defaults = {
	global = {
		keys = {
			"SPACE",
		},
		-- ignoreDisabledButtons = true,
		showGlow = true,

		-- additionalButtons = {},
		-- dialogBlacklist = {},
		numKeysForGossip = true,
		numKeysForQuestRewards = true,
		-- scrollQuests = false,
		-- dontClickSummons = false,
		-- dontClickDuels = false,
		-- dontClickRevives = false,
		-- dontClickReleases = false,
		-- soulstoneRez = true,
		-- keyCooldown = 0.5
	}
}

-- DialogKey.buttons = {							-- List of buttons to try and click
-- 	"StaticPopup1Button1",
-- 	"QuestFrameCompleteButton",
-- 	"QuestFrameCompleteQuestButton",
-- 	"QuestFrameAcceptButton",
-- 	"GossipTitleButton1",
-- 	"QuestTitleButton1"
-- }

-- DialogKey.scrollFrames = {						-- List of quest frames to try and scroll
-- QuestDetailScrollFrame,
-- QuestLogPopupDetailFrameScrollFrame,
-- QuestMapDetailsScrollFrame,
-- ClassicQuestLogDetailScrollFrame
-- }

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
	self.combatLockdown = false

	self.frame = CreateFrame("Frame", "DialogKeyFrame", UIParent)

	self.glowFrame = CreateFrame("Frame", "DialogKeyGlow", UIParent)
	self.glowFrame:SetPoint("CENTER", 0, 0)
	self.glowFrame:SetFrameStrata("TOOLTIP")
	self.glowFrame:SetSize(50,50)
	self.glowFrame:SetScript("OnUpdate", DialogKey.GlowFrameUpdate)
	self.glowFrame:Hide()
	self.glowFrame.tex = self.glowFrame:CreateTexture()
	self.glowFrame.tex:SetAllPoints()
	self.glowFrame.tex:SetColorTexture(1,1,0,0.5)

	self.frame:RegisterEvent("GOSSIP_SHOW")
	self.frame:RegisterEvent("QUEST_GREETING")
	self.frame:RegisterEvent("QUEST_PROGRESS")
	self.frame:RegisterEvent("GOSSIP_CLOSED")
	self.frame:RegisterEvent("QUEST_FINISHED")
	self.frame:RegisterEvent("QUEST_COMPLETE")
	self.frame:RegisterEvent("QUEST_DETAIL")
	self.frame:RegisterEvent("TAXIMAP_OPENED")
	self.frame:RegisterEvent("MERCHANT_CLOSED")
	self.frame:RegisterEvent("MERCHANT_SHOW")

	self.frame:RegisterEvent("PLAYER_REGEN_DISABLED")
	self.frame:RegisterEvent("PLAYER_REGEN_ENABLED")

	self.frame:SetScript("OnEvent", function(__, event, ...)
		-- DialogKey just breaks during combat lockdown, so let's unhook OnKeyDown and disable rehooking it until combat ends
		if (event == "PLAYER_REGEN_DISABLED") then
			self.frame:SetScript("OnKeyDown", nil)
			self.combatLockdown = true
		elseif (event == "PLAYER_REGEN_ENABLED") then
			self.combatLockdown = false
		end

		if self.combatLockdown then return end

		if (event == "GOSSIP_SHOW") then
			self.frame:SetScript("OnKeyDown", DialogKey.HandleKey)
		elseif (event == "QUEST_FINISHED" or event == "GOSSIP_CLOSED" or event == "MERCHANT_SHOW" or event == "MERCHANT_CLOSED" or event == "TAXIMAP_OPENED") then
			self.itemChoice = -1
			self.frame:SetPropagateKeyboardInput(true)
			self.frame:SetScript("OnKeyDown", nil)
		elseif (event == "QUEST_GREETING") then
			self.EnumerateGossips_Quest()
			self.frame:SetScript("OnKeyDown", DialogKey.DeprHandleKey)
		elseif (event == "QUEST_PROGRESS") then
			self.frame:SetScript("OnKeyDown", DialogKey.HandleKeyComplete)
		elseif (event == "QUEST_COMPLETE") then
			DialogKey.itemChoice = -1
			hooksecurefunc("QuestInfoItem_OnClick", DialogKey.SelectItemReward)
			self.frame:SetScript("OnKeyDown", DialogKey.HandleQuestReward)
		elseif (event == "QUEST_DETAIL") then
			self.frame:SetScript("OnKeyDown", DialogKey.HandleKeyAccept)
		end
	end);

	self.oldSetDataProvider = GossipFrame.GreetingPanel.ScrollBox.SetDataProvider
	GossipFrame.GreetingPanel.ScrollBox.SetDataProvider = function(frame, dataProvider)
		DialogKey:DataProviderInterceptor(frame, dataProvider)
	end
	
	self.frame:SetFrameStrata("TOOLTIP") -- Ensure we receive keyboard events first
	self.frame:EnableKeyboard(true)
	self.frame:SetPropagateKeyboardInput(true)
end

-- Enumerates Gossip + Quest entries, and builds frames Table for glowing when selected via keys.
function DialogKey:DataProviderInterceptor(frame, dataProvider)
	local newDataProvider = CreateDataProvider()
	local num = 1
	local newElementData = nil
	local newInfo = {}
	self.gossipChoices = {}
	for index, elementData in dataProvider:Enumerate() do
		if not DialogKey.db.global.numKeysForGossip or not elementData.info or num > 9 then
			newElementData = elementData
		else
			newElementData = {}
			self.gossipChoices[num] = elementData
			for k,v in pairs(elementData) do
				if k ~= "info" then
					newElementData[k] = v
				else
					newInfo = {}
					for l,w in pairs(elementData.info) do
						if l == "name" or l == "title" then
							newInfo[l] = num .. ". " .. w
							num = num + 1
						else
							newInfo[l] = w
						end
					end
					newElementData[k] = newInfo
				end
			end
		end
		newDataProvider:Insert(newElementData)
	end
	
	self.oldSetDataProvider(frame, newDataProvider)

	self.frames = {}
	for _, v in pairs{ GossipFrame.GreetingPanel.ScrollBox.ScrollTarget:GetChildren() } do
		if v:GetObjectType() == "Button" then
			table.insert(self.frames, v)
		end
	end
	table.sort(self.frames, function(a, b) return a:GetTop() > b:GetTop() end)
end
 
function DialogKey:print(message,msgType)
	DEFAULT_CHAT_FRAME:AddMessage("|cffd2b48c[DialogKey]|r "..message.."|r")
end

-- Internal/Private Functions --

local function ignoreInput()
	DialogKey.frame:SetPropagateKeyboardInput(true)

	-- TODO: ignore input while setting keybinds
	if GetCurrentKeyBoardFocus() then return true end -- Ignore input while typing
	if not GossipFrame:IsVisible() and not QuestFrame:IsVisible() then return true end -- Ignore input if GossipFrame isn't visible

	return false
end

-- Primary functions --

-- OnKeyDown handler for GOSSIP_SHOW event
function DialogKey:HandleKey(key)
	if ignoreInput() then return end
	
	local doAction = (key == DialogKey.db.global.keys[1] or key == DialogKey.db.global.keys[2])
	local keynum = doAction and 1 or tonumber(key)
	local keynumRaw = keynum

	if keynum and keynum > 0 and keynum <= 9 and DialogKey.db.global.numKeysForGossip then
		if keynum > C_GossipInfo.GetNumAvailableQuests() then
			keynum = keynum - C_GossipInfo.GetNumAvailableQuests()
		else
			DialogKey:Glow(DialogKey.frames[keynumRaw], "click")
			C_GossipInfo.SelectAvailableQuest(C_GossipInfo.GetAvailableQuests()[keynum].questID)
			DialogKey.frame:SetPropagateKeyboardInput(false)
			return
		end

		if keynum > C_GossipInfo.GetNumActiveQuests() then
			keynum = keynum - C_GossipInfo.GetNumActiveQuests()
		else
			DialogKey:Glow(DialogKey.frames[keynumRaw], "click")
			C_GossipInfo.SelectActiveQuest(C_GossipInfo.GetActiveQuests()[keynum].questID)
			DialogKey.frame:SetPropagateKeyboardInput(false)
			return
		end

		if keynum <= #C_GossipInfo.GetOptions() then
			DialogKey:Glow(DialogKey.frames[keynumRaw], "click")
			C_GossipInfo.SelectOption(C_GossipInfo.GetOptions()[keynum].gossipOptionID)
			DialogKey.frame:SetPropagateKeyboardInput(false)
		end
	end
end

-- OnKeyDown handler for QUEST_GREETING event
function DialogKey:DeprHandleKey(key)
	if ignoreInput() then return end

	local doAction = (key == DialogKey.db.global.keys[1] or key == DialogKey.db.global.keys[2])
	local keynum = doAction and 1 or tonumber(key)

	while keynum and keynum > 0 and keynum <= #DialogKey.frames do
		local title, is_complete = GetActiveTitle(keynum)
		if doAction and not is_complete and DialogKey.frames[keynum].frame.isActive == 1 then
			keynum = keynum + 1
			if keynum > #DialogKey.frames then
				doAction = false
				keynum = 1
			end
		else
			DialogKey:Glow(DialogKey.frames[keynum].frame, "click")
			DialogKey.frames[keynum].frame:Click()
			DialogKey.frame:SetPropagateKeyboardInput(false)
			return
		end
	end
end

-- OnKeyDown handler for QUEST_PROGRESS event
function DialogKey:HandleKeyComplete(key)
	if ignoreInput() then return end
	if not QuestFrameCompleteButton:IsEnabled() then return end -- don't click grayed out buttons!

	if key == DialogKey.db.global.keys[1] or key == DialogKey.db.global.keys[2] then
		DialogKey.frame:SetPropagateKeyboardInput(false)
		DialogKey:Glow(QuestFrameCompleteButton , "click")
		CompleteQuest()
	end
end

-- OnKeyDown handler for QUEST_DETAIL event
function DialogKey:HandleKeyAccept(key)
	if ignoreInput() then return end

	if key == DialogKey.db.global.keys[1] or key == DialogKey.db.global.keys[2] then
		DialogKey.frame:SetPropagateKeyboardInput(false)
		DialogKey:Glow(QuestFrameAcceptButton , "click")
		AcceptQuest()
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

-- Deprecated(?) Old Quest Panel Functions --

-- OnKeyDown handler for QUEST_COMPLETE event
function DialogKey:HandleQuestReward(key)
	if ignoreInput() then return end
	if not QuestFrameCompleteQuestButton:IsEnabled() then return end -- don't click grayed out buttons!

	local numkey = tonumber(key)
	if numkey and numkey > 0 and numkey <= GetNumQuestChoices() and DialogKey.db.global.numKeysForQuestRewards then
		if GetQuestItemInfo("choice", numkey) then
			DialogKey.itemChoice = numkey
			GetClickFrame("QuestInfoRewardsFrameQuestInfoItem"..key):Click()
			DialogKey.frame:SetPropagateKeyboardInput(false)
		end
	end
	if key == DialogKey.db.global.keys[1] or key == DialogKey.db.global.keys[2] then
		DialogKey.frame:SetPropagateKeyboardInput(false)
		if DialogKey.itemChoice == -1 and GetNumQuestChoices() > 0 then
			QuestChooseRewardError()
		else
			DialogKey:Glow(QuestFrameCompleteQuestButton , "click")
			GetQuestReward(DialogKey.itemChoice)
		end
	end
end

function DialogKey:GetQuestButtons()
	local frames = {}
	for f,unknown in QuestFrameGreetingPanel.titleButtonPool:EnumerateActive() do
		table.insert(frames,{
			top      = f:GetTop(),
			frame    = f,
			name     = f:GetText()
		})
	end
	
	table.sort(frames, function(a,b) return a.top > b.top end)
	return frames
end

function DialogKey:EnumerateGossips_Quest()		-- Prefixes 1., 2., etc. to NPC options
	if not DialogKey.db.global.numKeysForGossip then return end
	if not QuestFrameGreetingPanel:IsVisible() then return end

	DialogKey.frames = DialogKey:GetQuestButtons()
	local num = 1
	for i,f in pairs(DialogKey.frames) do
		local frame = f.frame
		if frame:IsVisible() and frame:GetText() then
			if not frame:GetText():find("^"..num.."\. ") then
				frame:SetText(num .. ". " .. frame:GetText())
			end
			num = num+1
		end
	end
end

-- Glow Functions --

-- Show the glow frame over a frame. Mode is "click", "add", or "remove"
function DialogKey:Glow(frame, mode)
	if mode == "click" then
		if DialogKey.db.global.showGlow then
			self.glowFrame:SetAllPoints(frame)
			self.glowFrame.tex:SetColorTexture(1,1,0,0.5)
			self.glowFrame:Show()
			self.glowFrame:SetAlpha(1)
		end
	elseif mode == "add" then
		self.glowFrame:SetAllPoints(frame)
		self.glowFrame.tex:SetColorTexture(0,1,0,0.5)
		self.glowFrame:Show()
		self.glowFrame:SetAlpha(1)
	elseif mode == "remove" then
		self.glowFrame:SetAllPoints(frame)
		self.glowFrame.tex:SetColorTexture(1,0,0,0.5)
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