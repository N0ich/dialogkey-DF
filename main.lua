-- Primary functions --
function DialogKey:HandleKey(key)
	if GossipFrame:IsVisible() == false then
		DialogKey.frame:SetPropagateKeyboardInput(true)
		return
	end
	local keynum = tonumber(key)
	local space = false
	if key == "SPACE" then
		keynum = 1
		space = true
	end
	DialogKey.frame:SetPropagateKeyboardInput(true)
	if keynum and keynum > 0 and keynum <= 9 then
		if keynum > C_GossipInfo.GetNumAvailableQuests() then
			keynum = keynum - C_GossipInfo.GetNumAvailableQuests()
		else
			C_GossipInfo.SelectAvailableQuest(C_GossipInfo.GetAvailableQuests()[keynum].questID)
			DialogKey.frame:SetPropagateKeyboardInput(false)
			return
		end
		if keynum > C_GossipInfo.GetNumActiveQuests() then
			keynum = keynum - C_GossipInfo.GetNumActiveQuests()
		else
			C_GossipInfo.SelectActiveQuest(C_GossipInfo.GetActiveQuests()[keynum].questID)
			DialogKey.frame:SetPropagateKeyboardInput(false)
			return
		end
		if keynum <= table.getn(C_GossipInfo.GetOptions()) then
			C_GossipInfo.SelectOption(C_GossipInfo.GetOptions()[keynum].gossipOptionID)
			DialogKey.frame:SetPropagateKeyboardInput(false)
		end
	end
end	-- -- local kids = {GossipFrame.GreetingPanel.ScrollBox.ScrollTarget:GetChildren()}
	-- -- local clickable = {}
	-- -- for _,v in pairs(kids) do
	-- -- 	if v and v.OnClick then
	-- -- 		table.insert(clickable, v)
	-- -- 	end
	-- -- end
	-- if keynum and keynum > 0 and keynum <= table.getn(DialogKey:gossipChoices) then
	-- 	DialogKey.frame:SetPropagateKeyboardInput(false)
	-- 	-- DialogKey:Glow(clickable[keynum])
	-- 	DialogKey:gossipChoices[keynum]:Click()
	-- end

function DialogKey:GlowFrameUpdate(delta)
	-- Use delta (time since last frame) so animation takes same amount of time regardless of framerate
	local alpha = self:GetAlpha() - delta*3
	if alpha < 0 then
		alpha = 0
	end
	self:SetAlpha(alpha)
	if self:GetAlpha() <= 0 then self:Hide() end
end

function DialogKey:DeprHandleKey(key)
	local keynum = tonumber(key)
	local space = false
	if key == "SPACE" then
		keynum = 1
		space = true
	end
	DialogKey.frame:SetPropagateKeyboardInput(true)
	while keynum and keynum > 0 and keynum <= table.getn(DialogKey.frames) do
		local title, is_complete = GetActiveTitle(keynum)
		if space == true and is_complete == false and DialogKey.frames[keynum].frame.isActive == 1 then
			keynum = keynum + 1
			if keynum > table.getn(DialogKey.frames) then
				space = false
				keynum = 1
			end
		else
			DialogKey:Glow(DialogKey.frames[keynum].frame)
			DialogKey.frames[keynum].frame:Click()
			DialogKey.frame:SetPropagateKeyboardInput(false)
			return
		end
	end
	-- if keynum and keynum > 0 and keynum <= count then
	-- 	DialogKey.frame:SetPropagateKeyboardInput(false)
	-- 	local title, is_complete = GetActiveTitle(keynum);
	-- 	SelectActiveQuest(keynum)
	-- 	SelectAvailableQuest(keynum)
	-- end
end

function DialogKey:HandleKeyComplete(key)
	DialogKey.frame:SetPropagateKeyboardInput(true)
	if key == "SPACE" then
		DialogKey.frame:SetPropagateKeyboardInput(false)
		CompleteQuest()
	end
end

function DialogKey:HandleKeyAccept(key)
	DialogKey.frame:SetPropagateKeyboardInput(true)
	if key == "SPACE" then
		DialogKey.frame:SetPropagateKeyboardInput(false)
		AcceptQuest()
	end
end

function DialogKey:HandleQuestReward(key)
	DialogKey.frame:SetPropagateKeyboardInput(true)
	local numkey = tonumber(key)
	if numkey and numkey > 0 and numkey <= GetNumQuestChoices() then
		if GetQuestItemInfo("choice", numkey) then
			DialogKey.itemChoice = numkey
			GetClickFrame("QuestInfoRewardsFrameQuestInfoItem"..numkey):Click()
			DialogKey.frame:SetPropagateKeyboardInput(false)
		end
	end
	if key == "SPACE" then
		DialogKey.frame:SetPropagateKeyboardInput(false)
		GetQuestReward(DialogKey.itemChoice)
	end
end

function DialogKey:SelectItemReward()
	for i=1,GetNumQuestChoices() do
		if GetClickFrame("QuestInfoRewardsFrameQuestInfoItem"..i):IsMouseOver() then
			self.itemChoice = i
		end
	end
end