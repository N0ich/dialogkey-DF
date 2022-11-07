DialogKey = LibStub("AceAddon-3.0"):NewAddon("DialogKey", "AceConsole-3.0", "AceTimer-3.0", "AceEvent-3.0")

--[[
		Raimond Mildenhall
		
		? Free the Farmhands
		? Fetching Wrex
		! The Bee Team
		! Wendigo Away
		
		\AddOns\DialogKey\main.lua line 638: attempt to index local 'a' (a nil value)
		if a.top > b.top then return 1 end
]]


--[[
	GossipFrame with quests: nethergarde keep, 2 quests to free spirits and kill bonepickers, do spirit quest - makes second quest the one we want to hit first
	
	* fixed keybinding mode
	* added cooldown option
	* fixed issues with QuestFrames (some quest givers use QuestFrame, some use GossipFrame)
	<< requires a game restart >>
]]

local defaults = {								-- Default settings
	global = {
		keys = {
			"SPACE",
		},
		ignoreDisabledButtons = true,
		showGlow = true,
		shownBindWarning = false,
		additionalButtons = {},
		dialogBlacklist = {},
		numKeysForGossip = true,
		numKeysForQuestRewards = true,
		scrollQuests = false,
		dontClickSummons = false,
		dontClickDuels = false,
		dontClickRevives = false,
		dontClickReleases = false,
		soulstoneRez = true,
		keyCooldown = 0.5
	}
}

DialogKey.buttons = {							-- List of buttons to try and click
	"StaticPopup1Button1",
	"QuestFrameCompleteButton",
	"QuestFrameCompleteQuestButton",
	"QuestFrameAcceptButton",
	"GossipTitleButton1",
	"QuestTitleButton1"
}

-- DialogKey.scrollFrames = {						-- List of quest frames to try and scroll
-- QuestDetailScrollFrame,
-- QuestLogPopupDetailFrameScrollFrame,
-- QuestMapDetailsScrollFrame,
-- ClassicQuestLogDetailScrollFrame
-- }

DialogKey.builtinDialogBlacklist = {			-- If a confirmation dialog contains one of these strings, don't accept it
	"Are you sure you want to go back to Shal'Aran?", -- Seems to bug out and not work if an AddOn clicks the confirm button?
}

function DialogKey:OnInitialize()				-- Runs on addon initialization
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
	self.frame:SetScript("OnEvent", function(__, event)
		if (event == "GOSSIP_SHOW") then
			self.frame:SetScript("OnKeyDown", DialogKey.HandleKey)
		-- elseif (event == "GOSSIP_CLOSED" or event == "MERCHANT_SHOW" or event == "MERCHANT_CLOSED" or event == "TAXIMAP_OPENED") then
		-- 	self.frame:SetScript("OnKeyDown", function()
		-- 		DialogKey.itemChoice = -1
		-- 		DialogKey.frame:SetPropagateKeyboardInput(true)
		-- 	end)
		elseif (event == "QUEST_GREETING") then
			self.EnumerateGossips_Quest()
			self.frame:SetScript("OnKeyDown", DialogKey.DeprHandleKey)
		elseif (event == "QUEST_FINISHED") then
			self.frame:SetScript("OnKeyDown", function()
				DialogKey.itemChoice = -1
				DialogKey.frame:SetPropagateKeyboardInput(true)
			end)
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
	self.frame:EnableKeyboard(true)
	self.frame:SetPropagateKeyboardInput(true)
	self.frame:SetFrameStrata("TOOLTIP") -- Ensure we receive keyboard events first
end

function DialogKey:DataProviderInterceptor(frame, dataProvider)
	local newDataProvider = CreateDataProvider()
	local num = 1
	local newElementData = nil
	local newInfo = {}
	self.gossipChoices = {}
	for index, elementData in dataProvider:Enumerate() do
		if not elementData.info or num > 9 then
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
end

function DialogKey:Glow(frame)
	DialogKey.glowFrame:SetAllPoints(frame)
	DialogKey.glowFrame.tex:SetColorTexture(1,1,0,0.5)
	DialogKey.glowFrame:Show()
	DialogKey.glowFrame:SetAlpha(1)
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

-- Print contents of `tbl`, with indentation.
-- `indent` sets the initial level of indentation.
function DialogKey:tprint (tbl, indent)
	if not indent then indent = 0 end
	for k, v in pairs(tbl) do
	   formatting = string.rep("  ", indent) .. k .. ": "
	   if type(v) == "table" then
		  print(formatting)
		  DialogKey:tprint(v, indent+1)
	   elseif type(v) == 'boolean' then
		  print(formatting .. tostring(v))      
	   elseif type(v) == 'function' then
		  print(formatting .. 'function')      
	   elseif type(v) == 'userdata' then
		  print(formatting .. 'userdata')      
	   else
		  print(formatting .. v)
	   end
	end
 end
 